import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_file_drafts.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

const _alpha = ServerProfile(
  id: 'srv-1',
  name: 'alpha',
  host: '10.0.0.1',
  username: 'root',
);
const _beta = ServerProfile(
  id: 'srv-2',
  name: 'beta',
  host: '10.0.0.2',
  username: 'root',
);
const _path = '/srv/a.txt';

String _sha(String value) => sha256.convert(utf8.encode(value)).toString();

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage() : super(storage: const FlutterSecureStorage());
  final drafts = <String, Map<String, dynamic>?>{};

  @override
  Future<Map<String, dynamic>?> getFileEditorDraft(String key) async =>
      drafts[key];

  @override
  Future<void> saveFileEditorDraft(
    String key,
    Map<String, dynamic> value,
  ) async => drafts[key] = value;

  @override
  Future<void> deleteFileEditorDraft(String key) async => drafts.remove(key);
}

class _FakeEditorService implements SftpOperations, SftpEditorOperations {
  String content = 'body of $_path';
  final saves = <(String, String)>[];

  @override
  Future<SftpTextSnapshot> readTextSnapshot(String path) async =>
      SftpTextSnapshot(
        path: path,
        targetPath: path,
        content: content,
        digest: _sha(content),
        attributes: SftpFileAttrs(size: content.length),
      );

  @override
  Future<void> saveTextSnapshot(SftpTextSnapshot original, String next) async {
    saves.add((original.path, next));
    content = next;
  }

  @override
  Future<String> readFileContent(String path) async => content;

  @override
  Future<List<SftpFileItem>> listFiles(String path) async => const [];

  @override
  Future<void> writeFileContent(String path, String content) async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> deleteDirectory(String path) async {}

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) => throw StateError('not used');

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) => throw StateError('not used');

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => 0;

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => 0;
}

class _FakeGateway implements WorkspaceGateway {
  _FakeGateway({Set<String>? enabled})
    : enabled = enabled ?? {'srv-1', 'srv-2'};

  final Set<String> enabled;
  final blobs = <String, Uint8List>{};
  final records = <String, Map<String, dynamic>>{};
  final requests = <(String, Map<String, dynamic>)>[];
  final puts = <(String, List<Map<String, dynamic>>)>[];
  final _partial = <String, BytesBuilder>{};
  final _changes = StreamController<WorkspaceChange>.broadcast();

  @override
  String get deviceId => 'dev-1';

  @override
  bool isEnabled(String serverId) => enabled.contains(serverId);

  @override
  Stream<WorkspaceChange> get changes => _changes.stream;

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    requests.add((serverId, command));
    final op = command['op'];
    if (op == 'blob_put') {
      final hash = command['hash'] as String;
      final index = command['chunkIndex'] as int;
      final total = command['totalChunks'] as int;
      final builder = _partial.putIfAbsent(hash, BytesBuilder.new);
      if (index == 0) builder.clear();
      builder.add(base64Decode(command['data'] as String));
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
      final end = (offset + command['length'] as int).clamp(0, bytes.length);
      return {
        'ok': true,
        'data': base64Encode(bytes.sublist(offset, end)),
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

  Future<void> dispose() => _changes.close();
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _alpha;
  void switchServer() => state = _beta;
}

class _Connected extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));
  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

Future<(ProviderContainer, LocalStorageService, _MemorySecureStorage)>
_container(_FakeGateway gateway, _FakeEditorService service) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  storage.workspaceGateway = gateway;
  final secure = _MemorySecureStorage();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(secure),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(_Connected.new),
      sftpOperationsProvider.overrideWithValue(service),
    ],
  );
  return (container, storage, secure);
}

SftpFileItem _item() => const SftpFileItem(
  name: 'a.txt',
  path: _path,
  isDirectory: false,
  sizeBytes: 12,
  formattedSize: '12 B',
  permissions: '-rw-r--r--',
  modified: '2026-10-27',
);

Future<void> _awaitPut(_FakeGateway gateway, {bool deleted = false}) async {
  for (var i = 0; i < 100; i++) {
    final found = gateway.puts.any(
      (entry) =>
          entry.$2.isNotEmpty && (entry.$2.first['deleted'] == true) == deleted,
    );
    if (found) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('no remote draft write (deleted=$deleted) was observed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an edit staged on A is never sent to B after a server switch',
    () async {
      final gateway = _FakeGateway();
      final service = _FakeEditorService();
      final (container, _, secure) = await _container(gateway, service);
      addTearDown(container.dispose);
      addTearDown(gateway.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(_item());
      notifier.updateEditorDraft(
        'edited on alpha',
        editorToken: notifier.editorToken,
      );
      // Switch before the 500 ms debounce fires. The origin captured at edit
      // time must still route the draft to srv-1.
      (container.read(activeServerProvider.notifier) as _StubActiveServer)
          .switchServer();
      container.read(sftpProvider);
      await _awaitPut(gateway);

      expect(gateway.puts, isNotEmpty);
      expect(gateway.puts.every((entry) => entry.$1 == 'srv-1'), isTrue);
      expect(gateway.puts.any((entry) => entry.$1 == 'srv-2'), isFalse);
      expect(
        secure.drafts[WorkspaceFileDrafts.localDraftKey(
          _alpha,
          _path,
        )]?['content'],
        'edited on alpha',
      );
    },
  );

  test('saving the file clears the local and remote draft', () async {
    final gateway = _FakeGateway();
    final service = _FakeEditorService();
    final (container, _, secure) = await _container(gateway, service);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    final notifier = container.read(sftpProvider.notifier);
    await pumpEventQueue();

    await notifier.openFileForEditing(_item());
    final token = notifier.editorToken;
    notifier.updateEditorDraft('edited', editorToken: token);
    await notifier.flushEditorDraft(editorToken: token);
    await _awaitPut(gateway);
    expect(service.saves, isEmpty);

    await notifier.saveFileContent(_path, 'saved body', editorToken: token);
    await _awaitPut(gateway, deleted: true);

    expect(service.saves.single, (_path, 'saved body'));
    final localKey = WorkspaceFileDrafts.localDraftKey(_alpha, _path);
    expect(secure.drafts[localKey], isNull);
    expect(
      gateway.puts.last.$2.single['deleted'],
      isTrue,
      reason: 'the draft tombstone must follow the save',
    );
    expect(gateway.puts.last.$1, 'srv-1');
  });

  test('discarding the editor stages a remote delete', () async {
    final gateway = _FakeGateway();
    final service = _FakeEditorService();
    final (container, _, secure) = await _container(gateway, service);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    final notifier = container.read(sftpProvider.notifier);
    await pumpEventQueue();

    await notifier.openFileForEditing(_item());
    final token = notifier.editorToken;
    notifier.updateEditorDraft('discard me', editorToken: token);
    await notifier.flushEditorDraft(editorToken: token);
    await _awaitPut(gateway);

    await notifier.discardEditorDraft(editorToken: token);
    await _awaitPut(gateway, deleted: true);

    final localKey = WorkspaceFileDrafts.localDraftKey(_alpha, _path);
    expect(secure.drafts[localKey], isNull);
    expect(gateway.puts.last.$2.single['deleted'], isTrue);
  });

  test('a local-only workspace never contacts the gateway', () async {
    final gateway = _FakeGateway(enabled: {});
    final service = _FakeEditorService();
    final (container, _, secure) = await _container(gateway, service);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    final notifier = container.read(sftpProvider.notifier);
    await pumpEventQueue();

    await notifier.openFileForEditing(_item());
    final token = notifier.editorToken;
    notifier.updateEditorDraft('local only', editorToken: token);
    await notifier.flushEditorDraft(editorToken: token);

    expect(
      secure.drafts[WorkspaceFileDrafts.localDraftKey(
        _alpha,
        _path,
      )]?['content'],
      'local only',
    );
    expect(gateway.requests, isEmpty);
    expect(gateway.puts, isEmpty);
  });

  test('opening the editor lazily hydrates only this device draft', () async {
    final gateway = _FakeGateway();
    const restored = 'restored on another run';
    final bytes = utf8.encode(restored);
    final hash = _sha(restored);
    gateway.blobs[hash] = Uint8List.fromList(bytes);
    final ownId = WorkspaceFileDrafts.remoteDraftId('dev-1', _path);
    gateway.records[ownId] = {
      'kind': 'draft',
      'id': ownId,
      'deleted': false,
      'value': {
        'type': 'file',
        'deviceId': 'dev-1',
        'path': _path,
        'digest': _sha('old revision'),
        'blob': {'hash': hash, 'size': bytes.length},
      },
    };
    final foreignId = WorkspaceFileDrafts.remoteDraftId('dev-2', _path);
    gateway.records[foreignId] = {
      'kind': 'draft',
      'id': foreignId,
      'deleted': false,
      'value': {
        'type': 'file',
        'deviceId': 'dev-2',
        'path': _path,
        'digest': _sha('old revision'),
        'blob': {'hash': hash, 'size': bytes.length},
      },
    };
    final service = _FakeEditorService();
    final (container, _, secure) = await _container(gateway, service);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    final notifier = container.read(sftpProvider.notifier);
    await pumpEventQueue();

    await notifier.openFileForEditing(_item());

    final state = container.read(sftpProvider);
    expect(state.editingFileContent, restored);
    expect(state.errorMessage, 'SFTP_EDIT_DRAFT_CONFLICT');
    expect(
      secure.drafts[WorkspaceFileDrafts.localDraftKey(
        _alpha,
        _path,
      )]?['content'],
      restored,
    );
    // Hydration only reads the blob; it never writes a remote user file.
    expect(gateway.puts, isEmpty);
  });
}
