import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/remote_workspace.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_file_drafts.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';

const _server = ServerProfile(
  id: 'alpha',
  name: 'alpha',
  host: '10.0.0.1',
  username: 'root',
);
const _path = '/srv/app/config.yml';

String _sha(String value) => sha256.convert(utf8.encode(value)).toString();

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage() : super(storage: const FlutterSecureStorage());

  final drafts = <String, Map<String, dynamic>?>{};
  final saves = <String>[];
  final deletes = <String>[];

  @override
  Future<Map<String, dynamic>?> getFileEditorDraft(String key) async =>
      drafts[key];

  @override
  Future<void> saveFileEditorDraft(
    String key,
    Map<String, dynamic> value,
  ) async {
    saves.add(key);
    drafts[key] = value;
  }

  @override
  Future<void> deleteFileEditorDraft(String key) async {
    deletes.add(key);
    drafts.remove(key);
  }
}

/// In-memory gateway that also implements the blob chunk protocol.
///
/// No socket, SSH or filesystem access happens here.
class _FakeGateway implements WorkspaceGateway {
  _FakeGateway({Set<String>? enabled}) : enabled = enabled ?? {'alpha', 'beta'};

  final Set<String> enabled;
  String _deviceId = 'dev-1';

  @override
  String get deviceId => _deviceId;

  void deviceIdOverride(String value) => _deviceId = value;

  bool online = true;
  final blobs = <String, Uint8List>{};
  final _partial = <String, BytesBuilder>{};
  final records = <String, Map<String, dynamic>>{};
  final requests = <(String, Map<String, dynamic>)>[];
  final puts = <(String, List<Map<String, dynamic>>)>[];
  final _changes = StreamController<WorkspaceChange>.broadcast();

  /// Optional gate used to hold the first blob upload in flight.
  Completer<void>? blobGate;
  Completer<void>? blobStarted;

  @override
  bool isEnabled(String serverId) => enabled.contains(serverId);

  @override
  Stream<WorkspaceChange> get changes => _changes.stream;

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    if (!online) throw StateError('WORKSPACE_OFFLINE');
    requests.add((serverId, command));
    final op = command['op'];
    if (op == 'blob_put') {
      final gate = blobGate;
      if (gate != null) {
        final started = blobStarted;
        if (started != null && !started.isCompleted) started.complete();
        await gate.future;
      }
      final hash = command['hash'] as String;
      final index = command['chunkIndex'] as int;
      final total = command['totalChunks'] as int;
      final data = base64Decode(command['data'] as String);
      final builder = _partial.putIfAbsent(hash, BytesBuilder.new);
      if (index == 0) builder.clear();
      builder.add(data);
      if (index == total - 1) {
        blobs[hash] = builder.takeBytes();
        _partial.remove(hash);
      }
      return {'ok': true};
    }
    if (op == 'blob_get') {
      final hash = command['hash'] as String;
      final bytes = blobs[hash];
      if (bytes == null) {
        return {'ok': false, 'error': 'WORKSPACE_BLOB_NOT_FOUND'};
      }
      final offset = command['offset'] as int;
      final length = command['length'] as int;
      final end = (offset + length).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      return {
        'ok': true,
        'data': base64Encode(chunk),
        'eof': end >= bytes.length,
        'size': bytes.length,
      };
    }
    if (op == 'snapshot') {
      final id = command['id'];
      final record = id is String ? records[id] : null;
      return {
        'ok': true,
        'records': record == null ? [] : [record],
      };
    }
    return {'ok': false, 'error': 'WORKSPACE_OP_UNKNOWN'};
  }

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> value,
  ) async {
    if (!online) throw StateError('WORKSPACE_OFFLINE');
    puts.add((serverId, value));
    for (final record in value) {
      final id = record['id'] as String;
      if (record['deleted'] == true) {
        records.remove(id);
      } else {
        records[id] = record;
      }
    }
  }

  void tick(String serverId) =>
      _changes.add(WorkspaceChange(serverId, const []));

  Future<void> dispose() => _changes.close();
}

WorkspaceFileDrafts _helper(
  _FakeGateway gateway,
  _MemorySecureStorage secure, {
  FileDraftIntentStore? intents,
}) => WorkspaceFileDrafts(
  gateway: gateway,
  secureStorage: secure,
  intents: intents,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves a typed per-device draft with a content blob', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    const content = 'edited body';
    final digest = _sha('original revision');
    // The editor saves encrypted locally before the workspace helper runs.
    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': content, 'digest': digest},
    );
    await helper.saveDraft(
      server: _server,
      path: _path,
      content: content,
      digest: digest,
    );

    final contentHash = _sha(content);
    expect(gateway.blobs[contentHash], utf8.encode(content));
    final (serverId, records) = gateway.puts.single;
    expect(serverId, 'alpha');
    final record = records.single;
    expect(record['kind'], 'draft');
    expect(record['deleted'], false);
    expect(record['id'], WorkspaceFileDrafts.remoteDraftId('dev-1', _path));
    final value = Map<String, dynamic>.from(record['value'] as Map);
    expect(value, {
      'type': 'file',
      'deviceId': 'dev-1',
      'path': _path,
      'digest': digest,
      'blob': {'hash': contentHash, 'size': utf8.encode(content).length},
    });
    expect(value.keys, isNot(contains('password')));
    expect(value.keys, isNot(contains('privateKey')));
    expect(await helper.intents.pending('alpha'), isEmpty);
  });

  test(
    'offline save keeps a durable intent and retries after restart',
    () async {
      final offline = _FakeGateway()..online = false;
      final secure = _MemorySecureStorage();
      final first = _helper(offline, secure);
      addTearDown(first.dispose);
      addTearDown(offline.dispose);

      const content = 'offline edit';
      final digest = _sha('original');
      // The local encrypted save is what the editor performs first.
      final localKey = WorkspaceFileDrafts.localDraftKey(_server, _path);
      await secure.saveFileEditorDraft(localKey, {
        'content': content,
        'digest': digest,
      });

      await first.saveDraft(
        server: _server,
        path: _path,
        content: content,
        digest: digest,
      );
      expect(offline.puts, isEmpty);
      expect(await first.intents.pending('alpha'), hasLength(1));

      // Simulated app restart: a new helper reads the same durable bookkeeping
      // and the same encrypted local draft.
      final online = _FakeGateway();
      final second = _helper(online, secure);
      addTearDown(second.dispose);
      addTearDown(online.dispose);
      expect(await second.flushPending("alpha"), isTrue);

      expect(online.puts.single.$1, 'alpha');
      final value = Map<String, dynamic>.from(
        online.puts.single.$2.single['value'] as Map,
      );
      expect(value['blob'], {'hash': _sha(content), 'size': content.length});
      expect(await second.intents.pending('alpha'), isEmpty);
    },
  );

  test('delete intent is durable and drains in order', () async {
    final gateway = _FakeGateway()..online = false;
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    await helper.deleteDraft(server: _server, path: _path);
    expect(await helper.intents.pending('alpha'), hasLength(1));
    expect(gateway.puts, isEmpty);

    gateway.online = true;
    expect(await helper.flushPending("alpha"), isTrue);
    final record = gateway.puts.single.$2.single;
    expect(record['kind'], 'draft');
    expect(record['deleted'], true);
    expect(record['id'], WorkspaceFileDrafts.remoteDraftId('dev-1', _path));
    expect(await helper.intents.pending('alpha'), isEmpty);
  });

  test('a later delete supersedes a queued save for the same path', () async {
    final gateway = _FakeGateway()..online = false;
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': 'edited', 'digest': _sha('a')},
    );
    await helper.stageSave(
      server: _server,
      path: _path,
      content: 'edited',
      digest: _sha('a'),
    );
    await helper.stageDelete(server: _server, path: _path);
    final pending = await helper.intents.pending('alpha');
    expect(pending, hasLength(1));
    expect(pending.single['deleted'], isTrue);

    gateway.online = true;
    expect(await helper.flushPending('alpha'), isTrue);
    expect(gateway.puts, hasLength(1));
    expect(gateway.puts.single.$2.single['deleted'], isTrue);
    expect(await helper.intents.pending('alpha'), isEmpty);
  });

  test('two devices sharing one workspace keep separate drafts', () async {
    final gatewayA = _FakeGateway();
    final gatewayB = _FakeGateway()..deviceIdOverride('dev-2');
    final secure = _MemorySecureStorage();
    final helperA = _helper(gatewayA, secure);
    final helperB = _helper(gatewayB, secure);
    addTearDown(helperA.dispose);
    addTearDown(helperB.dispose);
    addTearDown(gatewayA.dispose);
    addTearDown(gatewayB.dispose);

    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': 'device A text', 'digest': _sha('a')},
    );
    await helperA.saveDraft(
      server: _server,
      path: _path,
      content: 'device A text',
      digest: _sha('a'),
    );
    await helperB.saveDraft(
      server: _server,
      path: _path,
      content: 'device B text',
      digest: _sha('b'),
    );

    final idA = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
    final idB = WorkspaceFileDrafts.remoteDraftId('dev-2', _path);
    expect(idA, isNot(idB));
    expect(gatewayA.puts.single.$2.single['id'], idA);
    expect(gatewayB.puts.single.$2.single['id'], idB);
    expect(
      (gatewayA.puts.single.$2.single['value'] as Map)['deviceId'],
      'dev-1',
    );
    expect(
      (gatewayB.puts.single.$2.single['value'] as Map)['deviceId'],
      'dev-2',
    );
  });

  test('gateway tick retries staged uploads', () async {
    final gateway = _FakeGateway()..online = false;
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    const content = 'retry me';
    final digest = _sha('original');
    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': content, 'digest': digest},
    );
    await helper.stageSave(
      server: _server,
      path: _path,
      content: content,
      digest: digest,
    );

    gateway.online = true;
    gateway.tick('alpha');
    for (var i = 0; i < 50 && gateway.puts.isEmpty; i++) {
      await pumpEventQueue();
    }
    expect(gateway.puts, hasLength(1));
    expect(await helper.intents.pending('alpha'), isEmpty);
  });

  test('restore hydrates the blob and preserves the current draft', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    const content = 'restored body';
    final bytes = utf8.encode(content);
    final hash = _sha(content);
    gateway.blobs[hash] = Uint8List.fromList(bytes);
    final draftId = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
    final draft = WorkspaceDraft(
      id: draftId,
      deviceId: 'dev-1',
      title: _path,
      value: {
        'type': 'file',
        'deviceId': 'dev-1',
        'path': _path,
        'digest': _sha('revision'),
        'blob': {'hash': hash, 'size': bytes.length},
      },
    );
    final localKey = WorkspaceFileDrafts.localDraftKey(_server, _path);
    await secure.saveFileEditorDraft(localKey, {
      'content': 'current local edit',
      'digest': _sha('current revision'),
    });

    final result = await helper.restore(_server, draft);

    expect(result.content, content);
    expect(result.digest, _sha('revision'));
    expect(secure.drafts[localKey]!['content'], content);
    expect(secure.drafts[localKey]!['digest'], _sha('revision'));
    final backup = secure.drafts[result.backupLocalKey]!;
    expect(backup['content'], 'current local edit');
    expect(backup['digest'], _sha('current revision'));
    // Restore only reads the blob; it never writes a remote user file.
    expect(gateway.puts, isEmpty);
  });

  test('restore rejects a content hash mismatch', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    const claimed = 'claimed body';
    final claimedHash = _sha(claimed);
    final tampered = Uint8List.fromList(utf8.encode('tampered body'));
    gateway.blobs[claimedHash] = tampered;
    final draft = WorkspaceDraft(
      id: WorkspaceFileDrafts.remoteDraftId('dev-1', _path),
      deviceId: 'dev-1',
      title: _path,
      value: {
        'type': 'file',
        'deviceId': 'dev-1',
        'path': _path,
        'digest': _sha('revision'),
        'blob': {'hash': claimedHash, 'size': claimed.length},
      },
    );

    await expectLater(
      helper.restore(_server, draft),
      throwsA(isA<StateError>()),
    );
    expect(
      secure.drafts[WorkspaceFileDrafts.localDraftKey(_server, _path)],
      isNull,
    );
  });

  test('restore rejects an id that does not match the path', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    final draft = WorkspaceDraft(
      id: WorkspaceFileDrafts.remoteDraftId('dev-1', '/srv/other.yml'),
      deviceId: 'dev-1',
      title: _path,
      value: {
        'type': 'file',
        'deviceId': 'dev-1',
        'path': _path,
        'digest': _sha('revision'),
        'blob': {'hash': _sha('x'), 'size': 1},
      },
    );

    await expectLater(
      helper.restore(_server, draft),
      throwsA(
        isA<WorkspaceFileDraftException>().having(
          (e) => e.code,
          'code',
          'WORKSPACE_FILE_DRAFT_ID',
        ),
      ),
    );
  });

  test('findOwnDraft ignores another device draft', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    final foreignId = WorkspaceFileDrafts.remoteDraftId('dev-2', _path);
    gateway.records[foreignId] = {
      'kind': 'draft',
      'id': foreignId,
      'deleted': false,
      'value': {
        'type': 'file',
        'deviceId': 'dev-2',
        'path': _path,
        'digest': _sha('revision'),
        'blob': {'hash': _sha('body'), 'size': 4},
      },
    };

    expect(await helper.findOwnDraft(_server, _path), isNull);

    final ownId = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
    gateway.records[ownId] = {
      'kind': 'draft',
      'id': ownId,
      'deleted': false,
      'value': {
        'type': 'file',
        'deviceId': 'dev-1',
        'path': _path,
        'digest': _sha('revision'),
        'blob': {'hash': _sha('body'), 'size': 4},
      },
    };
    final own = await helper.findOwnDraft(_server, _path);
    expect(own, isNotNull);
    expect(own!.id, ownId);
    expect(own.deviceId, 'dev-1');
  });

  test('a disabled workspace leaves local editor behavior untouched', () async {
    final gateway = _FakeGateway(enabled: {});
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    await helper.saveDraft(
      server: _server,
      path: _path,
      content: 'local only',
      digest: _sha('original'),
    );
    expect(gateway.requests, isEmpty);
    expect(gateway.puts, isEmpty);
    expect(await helper.intents.pending('alpha'), isEmpty);
    expect(await helper.findOwnDraft(_server, _path), isNull);
  });

  test('staged intents stay on their own server', () async {
    final gateway = _FakeGateway()..online = false;
    final secure = _MemorySecureStorage();
    final helper = _helper(gateway, secure);
    addTearDown(helper.dispose);
    addTearDown(gateway.dispose);

    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': 'alpha edit', 'digest': _sha('a')},
    );
    await helper.stageSave(
      server: _server,
      path: _path,
      content: 'alpha edit',
      digest: _sha('a'),
    );
    expect(await helper.intents.pending('beta'), isEmpty);

    gateway.online = true;
    // Nothing was staged for beta: the queue is vacuously drained and must
    // never touch alpha's record.
    expect(await helper.flushPending('beta'), isTrue);
    expect(gateway.puts, isEmpty);
    expect(await helper.flushPending('alpha'), isTrue);
    expect(gateway.puts.single.$1, 'alpha');
  });

  test(
    'a stale flush cannot drop a newer draft staged by another helper',
    () async {
      final gateway = _FakeGateway();
      final secure = _MemorySecureStorage();
      final first = _helper(gateway, secure);
      final second = _helper(gateway, secure);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(gateway.dispose);

      final localKey = WorkspaceFileDrafts.localDraftKey(_server, _path);
      await secure.saveFileEditorDraft(localKey, {
        'content': 'first edit',
        'digest': _sha('a'),
      });
      await first.stageSave(
        server: _server,
        path: _path,
        content: 'first edit',
        digest: _sha('a'),
      );

      gateway.blobGate = Completer<void>();
      gateway.blobStarted = Completer<void>();
      final stale = first.flushPending('alpha');
      await gateway.blobStarted!.future.timeout(const Duration(seconds: 5));

      // The second helper stages a newer draft while the first upload is
      // blocked. Its intent replaces the first one on disk.
      await secure.saveFileEditorDraft(localKey, {
        'content': 'second edit',
        'digest': _sha('b'),
      });
      await second.stageSave(
        server: _server,
        path: _path,
        content: 'second edit',
        digest: _sha('b'),
      );
      expect(await first.intents.pending('alpha'), hasLength(1));

      final gate = gateway.blobGate!;
      gateway.blobGate = null;
      gate.complete();
      await stale.timeout(const Duration(seconds: 5));

      // The stale acknowledgement may only remove its own token.
      final surviving = await first.intents.pending('alpha');
      expect(surviving, hasLength(1));
      expect(surviving.single['deleted'], isFalse);
      expect(surviving.single['digest'], _sha('b'));

      expect(await second.flushPending('alpha'), isTrue);
      final id = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
      final value = Map<String, dynamic>.from(
        gateway.records[id]!['value'] as Map,
      );
      expect(value['digest'], _sha('b'));
      expect(value['blob'], {
        'hash': _sha('second edit'),
        'size': utf8.encode('second edit').length,
      });
      expect(gateway.puts.last.$2.single['id'], id);
      expect(await first.intents.pending('alpha'), isEmpty);
    },
  );

  test('a stale flush cannot drop a delete staged by another helper', () async {
    final gateway = _FakeGateway();
    final secure = _MemorySecureStorage();
    final first = _helper(gateway, secure);
    final second = _helper(gateway, secure);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(gateway.dispose);

    await secure.saveFileEditorDraft(
      WorkspaceFileDrafts.localDraftKey(_server, _path),
      {'content': 'first edit', 'digest': _sha('a')},
    );
    await first.stageSave(
      server: _server,
      path: _path,
      content: 'first edit',
      digest: _sha('a'),
    );

    gateway.blobGate = Completer<void>();
    gateway.blobStarted = Completer<void>();
    final stale = first.flushPending('alpha');
    await gateway.blobStarted!.future.timeout(const Duration(seconds: 5));

    await second.stageDelete(server: _server, path: _path);
    expect(await first.intents.pending('alpha'), hasLength(1));

    final gate = gateway.blobGate!;
    gateway.blobGate = null;
    gate.complete();
    await stale.timeout(const Duration(seconds: 5));

    final surviving = await first.intents.pending('alpha');
    expect(surviving, hasLength(1));
    expect(surviving.single['deleted'], isTrue);

    expect(await second.flushPending('alpha'), isTrue);
    final id = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
    expect(gateway.records.containsKey(id), isFalse);
    expect(gateway.puts.last.$2.single['deleted'], isTrue);
    expect(await first.intents.pending('alpha'), isEmpty);
  });
}
