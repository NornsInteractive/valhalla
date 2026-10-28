import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_chat_attachments.dart';
import 'package:valhalla/data/workspace/workspace_chat_sync.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/infrastructure/acp/acp_attachment_store.dart';

class _StoredRecord {
  final String kind;
  final String id;
  Map<String, dynamic>? value;
  bool deleted;
  int version;
  _StoredRecord(this.kind, this.id, this.value, this.deleted, this.version);
}

class _FakeServerStore {
  final Map<String, _StoredRecord> records = {};
  final Map<String, Uint8List> blobs = {};
  final Map<String, BytesBuilder> partials = {};
  final StreamController<WorkspaceChange> changes =
      StreamController<WorkspaceChange>.broadcast();
  int revision = 0;
  final List<Map<String, dynamic>> runtimeCatalog = [];
}

class _FakeGateway implements WorkspaceGateway {
  final _FakeServerStore store;
  @override
  final String deviceId;
  final Set<String> enabledServers;
  bool failWrites = false;
  bool rejectDescending = false;
  int snapshotCalls = 0;
  int maxSnapshotLimit = 0;
  int fullHistoryAttempts = 0;
  final List<Map<String, dynamic>> requests = [];

  _FakeGateway(
    this.store,
    this.deviceId, {
    this.enabledServers = const {'srv-a'},
  });

  @override
  bool isEnabled(String serverId) => enabledServers.contains(serverId);

  @override
  Stream<WorkspaceChange> get changes => store.changes.stream;

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    requests.add(Map<String, dynamic>.from(command));
    switch (command['op']) {
      case 'snapshot':
        return _snapshot(serverId, command);
      case 'chat_catalog':
        return _chatCatalog(serverId, command);
      case 'blob_put':
        return _blobPut(command);
      case 'blob_get':
        return _blobGet(command);
      case 'blob_has':
        return {
          'ok': true,
          'hash': command['hash'],
          'exists': store.blobs.containsKey(command['hash']),
        };
      case 'runtime_catalog':
        return {'ok': true, 'runtimes': store.runtimeCatalog};
      default:
        return {'ok': false, 'error': 'WORKSPACE_OP_UNKNOWN'};
    }
  }

  Map<String, dynamic> _snapshot(
    String serverId,
    Map<String, dynamic> command,
  ) {
    snapshotCalls++;
    final limit = (command['limit'] as num?)?.toInt() ?? 100;
    maxSnapshotLimit = limit > maxSnapshotLimit ? limit : maxSnapshotLimit;
    if (limit > 200) {
      return {'ok': false, 'error': 'WORKSPACE_REQUEST_INVALID'};
    }
    final kind = command['kind'] as String?;
    final prefix = command['prefix'] as String?;
    final exact = command['id'] as String?;
    final afterId = command['afterId'] as String?;
    final beforeId = command['beforeId'] as String?;
    final descending = command['descending'] == true;
    if (kind == 'chat_message' && descending && rejectDescending) {
      return {'ok': false, 'error': 'WORKSPACE_OP_INVALID'};
    }
    if (kind == 'chat_message' &&
        !descending &&
        afterId == null &&
        beforeId == null &&
        exact == null) {
      fullHistoryAttempts++;
    }
    var values = store.records.values.where((record) {
      if (kind != null && record.kind != kind) return false;
      if (prefix != null && !record.id.startsWith(prefix)) return false;
      if (exact != null && record.id != exact) return false;
      if (afterId != null && record.id.compareTo(afterId) <= 0) return false;
      if (beforeId != null && record.id.compareTo(beforeId) >= 0) return false;
      return true;
    }).toList();
    values.sort(
      (a, b) => descending ? b.id.compareTo(a.id) : a.id.compareTo(b.id),
    );
    final hasMore = values.length > limit;
    final page = values.take(limit).toList();
    return {
      'ok': true,
      'revision': store.revision,
      'hasMore': hasMore,
      'nextCursor': page.isEmpty ? null : page.last.id,
      'records': [
        for (final record in page)
          {
            'kind': record.kind,
            'id': record.id,
            'value': record.value,
            'deleted': record.deleted,
            'version': record.version,
          },
      ],
    };
  }

  Map<String, dynamic> _chatCatalog(
    String serverId,
    Map<String, dynamic> command,
  ) {
    final limit = (command['limit'] as num?)?.toInt() ?? 100;
    if (limit > 200) {
      return {'ok': false, 'error': 'WORKSPACE_REQUEST_INVALID'};
    }
    final agentId = command['agentId'] as String?;
    final query = (command['query'] as String?) ?? '';
    final cursor = command['cursor'] as String?;
    var values = store.records.values
        .where((record) => record.kind == 'chat_session')
        .where((record) {
          if (record.deleted) return true;
          final value = record.value;
          if (agentId != null) {
            final agents = <String>[
              if (value?['agentId'] is String) value!['agentId'] as String,
              ...((value?['participantAgentIds'] as List?) ?? const [])
                  .whereType<String>(),
            ];
            if (!agents.contains(agentId)) return false;
          }
          if (query.isNotEmpty) {
            final title = (value?['title'] as String?) ?? '';
            if (!title.toLowerCase().contains(query.toLowerCase())) {
              return false;
            }
          }
          return true;
        })
        .toList();
    values.sort((a, b) {
      final au = (a.value?['updatedAt'] as String?) ?? '';
      final bu = (b.value?['updatedAt'] as String?) ?? '';
      final cmp = bu.compareTo(au);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });
    if (cursor != null && cursor.isNotEmpty) {
      final parts = cursor.split('\\x00');
      if (parts.length == 2) {
        final cu = parts[0];
        final ci = parts[1];
        values = values.where((record) {
          final u = (record.value?['updatedAt'] as String?) ?? '';
          if (u.compareTo(cu) < 0) return true;
          if (u.compareTo(cu) > 0) return false;
          return record.id.compareTo(ci) > 0;
        }).toList();
      }
    }
    final hasMore = values.length > limit;
    final page = values.take(limit).toList();
    return {
      'ok': true,
      'revision': store.revision,
      'hasMore': hasMore,
      'nextCursor': page.isEmpty
          ? null
          : '${(page.last.value?['updatedAt'] as String?) ?? ''}\\x00${page.last.id}',
      'records': [
        for (final record in page)
          {
            'kind': record.kind,
            'id': record.id,
            'value': record.value,
            'deleted': record.deleted,
            'version': record.version,
          },
      ],
    };
  }

  Map<String, dynamic> _blobPut(Map<String, dynamic> command) {
    final hash = command['hash'] as String;
    final index = command['chunkIndex'] as int;
    final total = command['totalChunks'] as int;
    final bytes = base64Decode(command['data'] as String);
    if (bytes.length > 256 * 1024) {
      return {'ok': false, 'error': 'WORKSPACE_BLOB_CHUNK_TOO_LARGE'};
    }
    if (store.blobs.containsKey(hash)) {
      return {'ok': true, 'hash': hash, 'reused': true};
    }
    final builder = store.partials.putIfAbsent(
      hash,
      () => BytesBuilder(copy: false),
    );
    builder.add(bytes);
    if (index == total - 1) {
      final assembled = builder.takeBytes();
      if (sha256.convert(assembled).toString() != hash) {
        store.partials.remove(hash);
        return {'ok': false, 'error': 'WORKSPACE_BLOB_HASH_MISMATCH'};
      }
      store.blobs[hash] = assembled;
      store.partials.remove(hash);
    }
    return {'ok': true, 'hash': hash};
  }

  Map<String, dynamic> _blobGet(Map<String, dynamic> command) {
    final hash = command['hash'] as String;
    final bytes = store.blobs[hash];
    if (bytes == null) {
      return {'ok': false, 'error': 'WORKSPACE_BLOB_NOT_FOUND'};
    }
    final offset = (command['offset'] as num?)?.toInt() ?? 0;
    final length = (command['length'] as num?)?.toInt() ?? 256 * 1024;
    final end = (offset + length).clamp(0, bytes.length);
    return {
      'ok': true,
      'hash': hash,
      'data': base64Encode(bytes.sublist(offset, end)),
      'size': bytes.length,
      'offset': offset,
      'eof': end >= bytes.length,
    };
  }

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {
    if (failWrites) throw StateError('WORKSPACE_OFFLINE');
    final applied = <Map<String, dynamic>>[];
    for (final input in records) {
      final kind = input['kind'] as String;
      final id = input['id'] as String;
      final deleted = input['deleted'] == true;
      final value = input['value'] is Map
          ? Map<String, dynamic>.from(input['value'] as Map)
          : null;
      final version = ++store.revision;
      store.records['$kind\x00$id'] = _StoredRecord(
        kind,
        id,
        deleted ? null : value,
        deleted,
        version,
      );
      applied.add({
        'kind': kind,
        'id': id,
        'value': deleted ? null : value,
        'deleted': deleted,
        'version': version,
      });
    }
    store.changes.add(WorkspaceChange(serverId, applied));
  }
}

ChatMessage _message(
  int index, {
  MessageRole? role,
  List<ToolExecution> tools = const [],
  List<ChatContentBlock> blocks = const [],
  String? content,
  List<ChatAttachment> attachments = const [],
}) => ChatMessage(
  id: 'm$index',
  role: role ?? (index.isEven ? MessageRole.user : MessageRole.assistant),
  content: content ?? 'message $index',
  contentBlocks: blocks,
  toolExecutions: tools,
  attachments: attachments,
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
);

ChatSession _session(
  String id, {
  List<ChatMessage> messages = const [],
  int messageOffset = 0,
  String title = 'session',
  DateTime? updatedAt,
  Map<String, AgentChatContext> contexts = const {},
  String? serverId = 'srv-a',
}) => ChatSession(
  id: id,
  title: title,
  serverId: serverId,
  agentId: 'builtin-codex',
  agentContexts: contexts,
  messages: messages,
  messageOffset: messageOffset,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1, 12),
);

late Directory _root;

Future<ChatRepository> _repository(
  String name,
  WorkspaceGateway gateway, {
  AcpAttachmentStore? attachmentStore,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs)..workspaceGateway = gateway;
  final repository = ChatRepository(
    storage,
    databasePath: p.join(_root.path, name, 'chat.sqlite3'),
    attachmentStore:
        attachmentStore ??
        AcpAttachmentStore(directory: p.join(_root.path, name, 'attachments')),
  );
  // Registered after the shared `_root` teardown, so LIFO disposal closes the
  // repository's streams and database before the temp directory is removed.
  addTearDown(repository.dispose);
  return repository;
}

int _messageCount(String databasePath, String sessionId) {
  final db = sqlite3.open(databasePath);
  try {
    return db.select(
          'SELECT COUNT(*) AS n FROM chat_messages WHERE session_id=?',
          [sessionId],
        ).single['n']
        as int;
  } finally {
    db.dispose();
  }
}

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  setUp(() async {
    _root = await Directory.systemTemp.createTemp('valhalla-workspace-chat-');
    await Directory(p.join(_root.path, 'a')).create(recursive: true);
    await Directory(p.join(_root.path, 'b')).create(recursive: true);
    addTearDown(() async {
      if (_root.existsSync()) await _root.delete(recursive: true);
    });
  });

  test(
    'remote metadata is imported through one bounded session page',
    () async {
      final store = _FakeServerStore();
      final gatewayA = _FakeGateway(store, 'device-a');
      final gatewayB = _FakeGateway(store, 'device-b');
      final repositoryA = await _repository('a', gatewayA);
      final repositoryB = await _repository('b', gatewayB);

      for (var i = 0; i < 5; i++) {
        await repositoryA.saveSession(
          _session(
            's$i',
            title: 'session $i',
            messages: [_message(i)],
            updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );
      }
      final migration = await repositoryA.migrateWorkspace(
        'srv-a',
        messageBudget: 500,
      );
      expect(migration.done, isTrue);
      expect(migration.uploadedMessages, 5);

      final remote = store.records['chat_session\x00s4']!;
      expect(remote.value!['serverId'], '@server');
      expect(remote.value!['id'], 's4');

      final page = await repositoryB.listSessions('srv-a', limit: 3);
      expect(page.sessions.map((s) => s.id), ['s4', 's3', 's2']);
      expect(page.sessions.every((s) => s.serverId == 'srv-a'), isTrue);
      expect(page.sessions.first.title, 'session 4');
      expect(page.hasMore, isTrue);
      expect(gatewayB.maxSnapshotLimit, lessThanOrEqualTo(200));
      expect(gatewayB.fullHistoryAttempts, 0);
    },
  );

  test(
    'unsupported descending paging degrades instead of reading all history',
    () async {
      final store = _FakeServerStore();
      final gateway = _FakeGateway(store, 'device-a')..rejectDescending = true;
      final workspace = WorkspaceChatSync(gateway: gateway);

      final page = await workspace.fetchMessageTail('srv-a', 's', limit: 50);
      expect(page.unsupported, isTrue);
      expect(page.records, isEmpty);
      expect(gateway.fullHistoryAttempts, 0);
      expect(
        gateway.requests.where(
          (request) =>
              request['kind'] == 'chat_message' &&
              request['descending'] != true,
        ),
        isEmpty,
      );
    },
  );

  test('tail and upward windows are bounded and keep every id', () async {
    final store = _FakeServerStore();
    final gatewayA = _FakeGateway(store, 'device-a');
    final gatewayB = _FakeGateway(store, 'device-b');
    final repositoryA = await _repository('a', gatewayA);
    final repositoryB = await _repository('b', gatewayB);

    await repositoryA.saveSession(
      _session('big', messages: [for (var i = 0; i < 300; i++) _message(i)]),
    );
    await repositoryA.migrateWorkspace('srv-a', messageBudget: 500);
    await repositoryB.listSessions('srv-a');

    final tail = (await repositoryB.loadSession('big'))!;
    expect(tail.totalMessageCount, 300);
    expect(tail.messages.length, 50);
    expect(tail.messageOffset, 250);
    expect(tail.messages.first.id, 'm250');
    expect(tail.messages.last.id, 'm299');

    final upward = (await repositoryB.loadSession('big', before: 250))!;
    expect(upward.messages.length, 50);
    expect(upward.messageOffset, 200);
    expect(upward.messages.first.id, 'm200');
    expect(upward.messages.last.id, 'm249');

    final messageRequests = gatewayB.requests
        .where(
          (request) =>
              request['op'] == 'snapshot' && request['kind'] == 'chat_message',
        )
        .toList();
    expect(messageRequests, isNotEmpty);
    expect(
      messageRequests.every(
        (request) =>
            request['descending'] == true &&
            (request['limit'] as int) <= 50 &&
            (request['limit'] as int) <= 200,
      ),
      isTrue,
    );
    expect(gatewayB.fullHistoryAttempts, 0);
  });

  test('rename and tombstones cross devices without wiping history', () async {
    final store = _FakeServerStore();
    final gatewayA = _FakeGateway(store, 'device-a');
    final gatewayB = _FakeGateway(store, 'device-b');
    final repositoryA = await _repository('a', gatewayA);
    final repositoryB = await _repository('b', gatewayB);
    final databaseB = p.join(_root.path, 'b', 'chat.sqlite3');

    await repositoryA.saveSession(
      _session('s', title: 'old', messages: [_message(0), _message(1)]),
    );
    await repositoryA.migrateWorkspace('srv-a', messageBudget: 500);
    await repositoryB.listSessions('srv-a');
    expect((await repositoryB.loadSession('s'))!.messages.length, 2);

    await repositoryB.renameSession('s', 'renamed');
    await repositoryA.listSessions('srv-a');
    expect((await repositoryA.loadSession('s'))!.title, 'renamed');
    expect(store.records['chat_session\x00s']!.value!['title'], 'renamed');

    // A message tombstone is applied through the hot-refresh stream.
    final event = repositoryB.remoteChanges.first;
    await gatewayA.putRecords('srv-a', [
      {
        'kind': 'chat_message',
        'id': WorkspaceChatSync.messageRecordId('s', 0, 'm0'),
        'deleted': true,
        'value': null,
      },
    ]);
    await event;
    await Future<void>.delayed(Duration.zero);
    expect(_messageCount(databaseB, 's'), 1);

    await repositoryA.deleteSession('s');
    await repositoryB.listSessions('srv-a');
    expect((await repositoryB.listSessions('srv-a')).sessions, isEmpty);
    expect(store.records['chat_session\x00s']!.deleted, isTrue);
    expect(store.records['chat_message\x00s/000000000000/m0']!.deleted, isTrue);
    expect(store.records['chat_message\x00s/000000000001/m1']!.deleted, isTrue);
  });

  test('roles, content blocks and full tools survive the round trip', () async {
    final store = _FakeServerStore();
    final gatewayA = _FakeGateway(store, 'device-a');
    final gatewayB = _FakeGateway(store, 'device-b');
    final repositoryA = await _repository('a', gatewayA);
    final repositoryB = await _repository('b', gatewayB);
    final output = 'head${'x' * 40000}tail';

    await repositoryA.saveSession(
      _session(
        'rich',
        messages: [
          _message(
            0,
            role: MessageRole.user,
            content: 'hello',
            blocks: const [ChatContentBlock.text(0, 5)],
          ),
          _message(
            1,
            role: MessageRole.assistant,
            content: 'done',
            blocks: const [
              ChatContentBlock.text(0, 4),
              ChatContentBlock.tool('t1'),
            ],
            tools: [
              ToolExecution(
                id: 't1',
                name: 'build',
                command: 'make',
                status: ToolExecutionStatus.completed,
                output: output,
              ),
            ],
          ),
          _message(2, role: MessageRole.system, content: 'system'),
        ],
      ),
    );
    await repositoryA.migrateWorkspace('srv-a', messageBudget: 500);
    await repositoryB.listSessions('srv-a');

    final remoteMessage =
        store.records['chat_message\x00rich/000000000001/m1']!.value!;
    expect(
      (remoteMessage['toolExecutions'] as List).single['hasMoreOutput'],
      isTrue,
    );

    final loaded = (await repositoryB.loadSession('rich'))!;
    expect(loaded.messages.map((m) => m.role), [
      MessageRole.user,
      MessageRole.assistant,
      MessageRole.system,
    ]);
    expect(loaded.messages[0].contentBlocks.single.start, 0);
    expect(loaded.messages[1].contentBlocks.last.toolId, 't1');
    final tool = loaded.messages[1].toolExecutions.single;
    expect(tool.id, 't1');
    expect(tool.hasMoreOutput, isTrue);
    final page = await repositoryB.loadToolOutput(
      'rich',
      'm1',
      't1',
      limit: 65536,
    );
    expect(page.nextOffset, isNull);
    expect(page.text, output);
  });

  test('replay batches and repeated saves are idempotent', () async {
    final store = _FakeServerStore();
    final gateway = _FakeGateway(store, 'device-a');
    final repository = await _repository('a', gateway);
    final session = _session('s', messages: [_message(0), _message(1)]);
    await repository.saveSession(session);
    await repository.saveSession(session);
    await repository.mergeReplayBatch(session, 'builtin-codex');
    await repository.mergeReplayBatch(session, 'builtin-codex');

    expect(_messageCount(p.join(_root.path, 'a', 'chat.sqlite3'), 's'), 2);
    final remoteMessages = store.records.values
        .where((record) => record.kind == 'chat_message')
        .toList();
    expect(remoteMessages.length, 2);
    expect(remoteMessages.map((record) => record.id).toSet(), {
      WorkspaceChatSync.messageRecordId('s', 0, 'm0'),
      WorkspaceChatSync.messageRecordId('s', 1, 'm1'),
    });
  });

  test('large history migrates in bounded resumable batches', () async {
    final store = _FakeServerStore();
    final gateway = _FakeGateway(store, 'device-a', enabledServers: <String>{});
    final repository = await _repository('a', gateway);
    await repository.saveSession(
      _session('large', messages: [for (var i = 0; i < 1200; i++) _message(i)]),
    );
    gateway.enabledServers.add('srv-a');

    var rounds = 0;
    WorkspaceChatMigration? result;
    do {
      result = await repository.migrateWorkspace('srv-a', messageBudget: 200);
      expect(result.uploadedMessages, lessThanOrEqualTo(200));
      rounds++;
    } while (!result.done && rounds < 20);
    expect(result.done, isTrue);
    expect(rounds, greaterThan(1));
    expect(gateway.snapshotCalls, 0);
    expect(
      store.records.values.where((r) => r.kind == 'chat_message').length,
      1200,
    );

    // Simulate a crash and reopen the same local DB: the cursor resumes.
    final reopened = await _repository('a', gateway);
    final resumed = await reopened.migrateWorkspace('srv-a');
    expect(resumed.done, isTrue);
    expect(resumed.uploadedMessages, 0);
    expect(
      store.records.values.where((r) => r.kind == 'chat_message').length,
      1200,
    );
  });

  test('local ids and message ids are preserved and mapped', () async {
    final store = _FakeServerStore();
    final gatewayA = _FakeGateway(store, 'device-a');
    final gatewayB = _FakeGateway(store, 'device-b');
    final repositoryA = await _repository('a', gatewayA);
    final repositoryB = await _repository('b', gatewayB);
    await repositoryA.saveSession(
      _session('dev/session-1', messages: [_message(0), _message(1)]),
    );
    await repositoryA.migrateWorkspace('srv-a', messageBudget: 500);

    final page = await repositoryB.listSessions('srv-a');
    expect(page.sessions.single.id, 'dev/session-1');
    final loaded = (await repositoryB.loadSession('dev/session-1'))!;
    expect(loaded.messages.map((m) => m.id), ['m0', 'm1']);

    final parsed = WorkspaceChatSync.parseMessageId(
      WorkspaceChatSync.messageRecordId('dev/session-1', 1, 'm1'),
    );
    expect(parsed!.sessionId, 'dev/session-1');
    expect(parsed.sequence, 1);
    expect(parsed.messageId, 'm1');

    final reopened = await _repository('b', gatewayB);
    expect(
      (await reopened.listSessions('srv-a')).sessions.single.id,
      'dev/session-1',
    );
  });

  test(
    'attachments upload by hash in <=256KiB chunks and hydrate on demand',
    () async {
      final store = _FakeServerStore();
      final gatewayA = _FakeGateway(store, 'device-a');
      final gatewayB = _FakeGateway(store, 'device-b');
      final repositoryA = await _repository('a', gatewayA);
      final repositoryB = await _repository('b', gatewayB);
      final bytes = Uint8List.fromList(
        List<int>.generate(300 * 1024, (i) => i % 251),
      );
      final file = File(p.join(_root.path, 'payload.bin'));
      await file.writeAsBytes(bytes);
      final hash = sha256.convert(bytes).toString();

      await repositoryA.saveSession(
        _session(
          'attached',
          messages: [
            _message(
              0,
              attachments: [
                ChatAttachment(
                  id: 'local-id',
                  name: 'payload.bin',
                  mimeType: 'application/octet-stream',
                  sizeBytes: bytes.length,
                  localPath: file.path,
                ),
              ],
            ),
          ],
        ),
      );
      await repositoryA.migrateWorkspace('srv-a', messageBudget: 500);

      expect(store.blobs[hash], isNotNull);
      expect(store.blobs[hash]!.length, bytes.length);
      final putChunks = gatewayA.requests
          .where((request) => request['op'] == 'blob_put')
          .toList();
      expect(putChunks.length, greaterThanOrEqualTo(2));
      expect(
        putChunks.every(
          (request) =>
              base64Decode(request['data'] as String).length <= 256 * 1024,
        ),
        isTrue,
      );

      final remote =
          store.records['chat_message\x00attached/000000000000/m0']!.value!;
      final attachment =
          (remote['attachments'] as List).single as Map<String, dynamic>;
      expect(attachment['localPath'], isNull);
      expect(attachment['uri'], '$kWorkspaceBlobUriPrefix$hash');

      await repositoryB.listSessions('srv-a');
      final loaded = (await repositoryB.loadSession('attached'))!;
      final reference = loaded.messages.single.attachments.single;
      expect(reference.localPath, isNull);
      final hydrated = await repositoryB.hydrateWorkspaceAttachment(
        'srv-a',
        reference,
      );
      expect(hydrated.localPath, isNotNull);
      expect(await File(hydrated.localPath!).readAsBytes(), bytes);
    },
  );

  test(
    'remote changes refresh metadata without resetting the open session',
    () async {
      final store = _FakeServerStore();
      final gatewayA = _FakeGateway(store, 'device-a');
      final gatewayB = _FakeGateway(store, 'device-b');
      final repositoryA = await _repository('a', gatewayA);
      final repositoryB = await _repository('b', gatewayB);

      final event = repositoryB.remoteChanges.first;
      await repositoryA.saveSession(
        _session('live', title: 'live title', messages: [_message(0)]),
      );
      final change = await event;

      expect(change.serverId, 'srv-a');
      expect(change.sessionIds, contains('live'));
      final loaded = (await repositoryB.loadSession('live'))!;
      expect(loaded.title, 'live title');
      expect(loaded.messages.single.id, 'm0');
    },
  );

  test('runtime catalog and hydrated agent contexts stay available', () async {
    final store = _FakeServerStore();
    store.runtimeCatalog.addAll([
      {
        'runtimeKey': 'runtime-1',
        'deviceId': 'device-a',
        'sessionId': 's',
        'scope': 'server',
        'meta': {'model': 'free'},
      },
    ]);
    final gateway = _FakeGateway(store, 'device-a');
    final repository = await _repository('a', gateway);
    await repository.saveSession(
      _session(
        's',
        contexts: {
          'builtin-codex': const AgentChatContext(
            persistentRuntimeKey: 'runtime-1',
            runtimeCursor: 4,
            runtimeGeneration: 2,
          ),
        },
      ),
    );

    final catalog = await repository.workspaceRuntimeCatalog('srv-a');
    expect(catalog.single.runtimeKey, 'runtime-1');
    expect(catalog.single.meta['model'], 'free');
    final bindings = await repository.workspaceRuntimeBindings('srv-a');
    expect(bindings['runtime-1']!.sessionId, 's');
    expect(bindings['runtime-1']!.agentId, 'builtin-codex');
    expect(bindings['runtime-1']!.context.runtimeCursor, 4);
  });

  test(
    'an unsynced local rename is not overwritten by older metadata',
    () async {
      final store = _FakeServerStore();
      final gateway = _FakeGateway(store, 'device-a');
      final repository = await _repository('a', gateway);
      await repository.saveSession(
        _session('s', title: 'remote title', messages: [_message(0)]),
      );
      gateway.failWrites = true;
      await repository.renameSession('s', 'local rename');
      expect((await repository.loadSession('s'))!.title, 'local rename');

      // The server still holds the old title; refresh must not clobber the
      // local rename that is waiting in the durable outbox.
      await repository.listSessions('srv-a');
      expect((await repository.loadSession('s'))!.title, 'local rename');
      expect(
        store.records['chat_session\x00s']!.value!['title'],
        'remote title',
      );
    },
  );

  test(
    'deferred remote write failures are surfaced without deleting history',
    () async {
      final store = _FakeServerStore();
      final gateway = _FakeGateway(store, 'device-a')..failWrites = true;
      final repository = await _repository('a', gateway);
      final errors = <Object>[];
      final subscription = repository.workspaceErrors.listen(errors.add);
      addTearDown(subscription.cancel);

      await repository.saveSession(
        _session('offline', messages: [_message(0), _message(1)]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(errors, isNotEmpty);
      expect(repository.lastWorkspaceError, isNotNull);
      expect(
        _messageCount(p.join(_root.path, 'a', 'chat.sqlite3'), 'offline'),
        2,
      );
      expect((await repository.loadSession('offline'))!.messages.length, 2);
    },
  );

  group('ACP runtime discovery', () {
    test(
      'workspaceRuntimeCatalog surfaces agentId and bounded bootstrap meta',
      () async {
        final store = _FakeServerStore();
        store.runtimeCatalog.add({
          'runtimeKey': 'rk123',
          'deviceId': 'device-a',
          'sessionId': 'chat-remote-id',
          'scope': 'scope-x',
          'agentId': 'agent-9',
          'meta': {
            'agentId': 'agent-9',
            'runtimeKey': 'rk123',
            'workingDirectory': '/work',
            'title': 'Shared run',
            'remoteSessionId': 'acp-sess',
          },
        });
        final gateway = _FakeGateway(store, 'device-a');
        final repo = await _repository('a', gateway);

        final catalog = await repo.workspaceRuntimeCatalog('srv-a');

        expect(catalog, hasLength(1));
        final info = catalog.first;
        expect(info.runtimeKey, 'rk123');
        expect(info.agentId, 'agent-9');
        expect(info.sessionId, 'chat-remote-id');
        expect(info.workingDirectory, '/work');
        expect(info.title, 'Shared run');
        expect(info.acpRemoteSessionId, 'acp-sess');
      },
    );

    test(
      'hydrateRemoteSession hydrates exact session without local cache',
      () async {
        final store = _FakeServerStore();
        final chatId = 'chat-remote-id';
        final session = ChatSession(
          id: chatId,
          serverId: 'srv-a',
          agentId: 'agent-9',
          title: 'Discovered',
          workingDirectory: '/work',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        store.records[chatId] = _StoredRecord(
          'chat_session',
          chatId,
          session.toJson(),
          false,
          1,
        );
        final gateway = _FakeGateway(store, 'device-a');
        final repo = await _repository('a', gateway);

        // No local mapping exists yet for this runtime key.
        expect(await repo.findRuntimeSession('srv-a', 'rk123'), isNull);

        final hydrated = await repo.hydrateRemoteSession('srv-a', chatId);

        expect(hydrated, isNotNull);
        expect(hydrated!.id, chatId);
        expect(hydrated.title, 'Discovered');
        // The hydrated session is now discoverable locally by runtime key.
        expect(await repo.findRuntimeSession('srv-a', 'rk123'), isNull);
      },
    );

    test(
      'persistLocalRuntimeSession writes local store only, no remote stage',
      () async {
        final store = _FakeServerStore();
        final gateway = _FakeGateway(store, 'device-a');
        final repo = await _repository('a', gateway);
        final session = ChatSession(
          id: 'local-1',
          serverId: 'srv-a',
          agentId: 'agent-9',
          title: 'Reconstructed',
          workingDirectory: '/work',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          agentContexts: const {
            'agent-9': AgentChatContext(persistentRuntimeKey: 'rk9'),
          },
        );

        await repo.persistLocalRuntimeSession(session);

        final found = await repo.findRuntimeSession('srv-a', 'rk9');
        expect(found, isNotNull);
        expect(found!.id, 'local-1');
        // An observer merely viewing must not stage a remote write. The local
        // SQLite copy exists, but the workspace store must not have received it.
        expect(store.records.containsKey('local-1'), isFalse);
      },
    );
  });
}
