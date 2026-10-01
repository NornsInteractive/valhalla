import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _sessionsKey = 'valhalla_chat_sessions_v1';

late Directory _directory;
String get _databasePath => '${_directory.path}/chat.sqlite3';

ChatMessage _message(
  int index, {
  ChatTurnStatus status = ChatTurnStatus.completed,
  MessageRole? role,
  List<ToolExecution> toolExecutions = const [],
}) => ChatMessage(
  id: 'm$index',
  role: role ?? (index.isEven ? MessageRole.user : MessageRole.assistant),
  content: 'message $index',
  status: status,
  toolExecutions: toolExecutions,
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
);

List<ChatMessage> _messages(int count) => [
  for (var i = 0; i < count; i++) _message(i),
];

ChatSession _session(
  String id, {
  String? serverId = 'srv-a',
  String? agentId = 'builtin-codex',
  List<String> participantAgentIds = const [],
  List<ChatMessage> messages = const [],
  int messageOffset = 0,
  DateTime? updatedAt,
  String? title,
}) => ChatSession(
  id: id,
  title: title ?? 'session $id',
  serverId: serverId,
  agentId: agentId,
  participantAgentIds: participantAgentIds,
  messages: messages,
  messageOffset: messageOffset,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1, 12),
);

String _raw(List<ChatSession> sessions) =>
    jsonEncode(sessions.map((session) => session.toJson()).toList());

Future<LocalStorageService> _storage({String? rawSessions}) async {
  SharedPreferences.setMockInitialValues(
    rawSessions == null
        ? const <String, Object>{}
        : <String, Object>{_sessionsKey: rawSessions},
  );
  return LocalStorageService(await SharedPreferences.getInstance());
}

ChatRepository _repository(LocalStorageService storage) =>
    ChatRepository(storage, databasePath: _databasePath);

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

List<Map<String, Object?>> _query(
  String sql, [
  List<Object?> parameters = const [],
]) {
  final db = sqlite3.open(_databasePath);
  try {
    db.execute('PRAGMA busy_timeout = 5000');
    return db.select(sql, parameters);
  } finally {
    db.dispose();
  }
}

String _largeToolOutput() => 'head😀🙂${'x' * 30000}🚀end';

Future<ChatRepository> _repositoryWithLargeToolOutput() async {
  final repository = _repository(await _storage());
  await repository.saveSession(
    _session(
      'a',
      messages: [
        _message(
          0,
          toolExecutions: [
            ToolExecution(
              id: 't1',
              name: 'build',
              command: 'make test',
              status: ToolExecutionStatus.completed,
              output: _largeToolOutput(),
            ),
          ],
        ),
      ],
    ),
  );
  return repository;
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
    _directory = await Directory.systemTemp.createTemp(
      'valhalla-chat-repository-',
    );
    addTearDown(() async {
      if (_directory.existsSync()) await _directory.delete(recursive: true);
    });
  });

  test(
    'legacy JSON migration is idempotent and never rewrites rawChatSessions',
    () async {
      final sessions = [
        _session('a', messages: _messages(3)),
        _session(
          'b',
          serverId: null,
          agentId: null,
          updatedAt: DateTime.utc(2026, 1, 1, 11),
        ),
      ];
      final original = _raw(sessions);
      final storage = await _storage(rawSessions: original);
      final repository = _repository(storage);

      final first = await repository.listSessions('srv-a');
      expect(first.sessions.map((s) => s.id), ['a', 'b']);
      expect(first.warning, isNull);
      expect((await _prefs()).getString(_sessionsKey), original);
      expect(
        _query(
          "SELECT value FROM chat_meta WHERE key='legacy_imported'",
        ).single['value'],
        '1',
      );
      expect(_query('SELECT COUNT(*) AS n FROM chat_sessions').single['n'], 2);
      expect(_query('SELECT COUNT(*) AS n FROM chat_messages').single['n'], 3);

      final extended = _raw([
        ...sessions,
        _session('c', messages: _messages(2)),
      ]);
      await (await _prefs()).setString(_sessionsKey, extended);

      final reopened = _repository(storage);
      final second = await reopened.listSessions('srv-a');
      expect(second.sessions.map((s) => s.id), ['a', 'b']);
      expect((await _prefs()).getString(_sessionsKey), extended);
      expect(_query('SELECT COUNT(*) AS n FROM chat_sessions').single['n'], 2);
      expect(_query('SELECT COUNT(*) AS n FROM chat_messages').single['n'], 3);
      expect(
        _query('SELECT COUNT(*) AS n FROM chat_messages WHERE session_id=?', [
          'a',
        ]).single['n'],
        3,
      );
    },
  );

  test(
    'migration keeps message ids and counts while loadSession pages backwards',
    () async {
      final original = _messages(120);
      final storage = await _storage(
        rawSessions: _raw([_session('chat', messages: original)]),
      );
      final repository = _repository(storage);
      await repository.listSessions('srv-a');

      final latest = await repository.loadSession('chat');
      expect(latest, isNotNull);
      expect(latest!.totalMessageCount, 120);
      expect(latest.messages.length, 50);
      expect(latest.messageOffset, 70);
      expect(latest.messages.map((m) => m.id), [
        for (var i = 70; i < 120; i++) 'm$i',
      ]);
      expect(latest.messages.map((m) => m.content), [
        for (var i = 70; i < 120; i++) 'message $i',
      ]);

      final previous = await repository.loadSession(
        'chat',
        before: latest.messageOffset,
      );
      expect(previous!.totalMessageCount, 120);
      expect(previous.messages.length, 50);
      expect(previous.messageOffset, 20);
      expect(previous.messages.map((m) => m.id), [
        for (var i = 20; i < 70; i++) 'm$i',
      ]);

      final firstPage = await repository.loadSession(
        'chat',
        before: previous.messageOffset,
      );
      expect(firstPage!.messages.length, 20);
      expect(firstPage.messageOffset, 0);
      expect(firstPage.messages.map((m) => m.id), [
        for (var i = 0; i < 20; i++) 'm$i',
      ]);

      final stored = _query(
        'SELECT id FROM chat_messages WHERE session_id=? ORDER BY seq',
        ['chat'],
      );
      expect(stored.map((row) => row['id']), [
        for (var i = 0; i < 120; i++) 'm$i',
      ]);
      expect(await repository.loadSession('missing'), isNull);
    },
  );

  test('listSessions isolates records by server and agent', () async {
    final storage = await _storage(
      rawSessions: _raw([
        _session(
          'a',
          agentId: 'builtin-codex',
          updatedAt: DateTime.utc(2026, 1, 5),
        ),
        _session(
          'b',
          agentId: 'builtin-opencode',
          updatedAt: DateTime.utc(2026, 1, 4),
        ),
        _session(
          'c',
          agentId: 'builtin-opencode',
          participantAgentIds: const ['builtin-codex'],
          updatedAt: DateTime.utc(2026, 1, 3),
        ),
        _session('d', serverId: 'srv-b', updatedAt: DateTime.utc(2026, 1, 2)),
        _session(
          'legacy',
          serverId: null,
          agentId: null,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]),
    );
    final repository = _repository(storage);

    final srvA = await repository.listSessions('srv-a');
    expect(srvA.sessions.map((s) => s.id), ['a', 'b', 'c', 'legacy']);
    expect(
      await repository
          .listSessions('srv-b')
          .then((page) => page.sessions.map((s) => s.id)),
      ['d'],
    );

    final codex = await repository.listSessions(
      'srv-a',
      agentId: 'builtin-codex',
    );
    expect(codex.sessions.map((s) => s.id), ['a', 'c']);
    final openCode = await repository.listSessions(
      'srv-a',
      agentId: 'builtin-opencode',
    );
    expect(openCode.sessions.map((s) => s.id), ['b', 'c']);
    expect(
      await repository
          .listSessions('srv-b', agentId: 'builtin-codex')
          .then((p) => p.sessions.map((s) => s.id)),
      ['d'],
    );

    expect(
      await repository
          .listSessions('srv-a', query: 'session b')
          .then((p) => p.sessions.map((s) => s.id)),
      ['b'],
    );

    await repository.saveSession(
      _session(
        'e',
        serverId: 'srv-b',
        agentId: 'builtin-opencode',
        updatedAt: DateTime.utc(2026, 1, 6),
      ),
    );
    expect(
      await repository
          .listSessions('srv-b')
          .then((p) => p.sessions.map((s) => s.id)),
      ['e', 'd'],
    );
    expect(
      await repository
          .listSessions('srv-a')
          .then((p) => p.sessions.map((s) => s.id)),
      ['a', 'b', 'c', 'legacy'],
    );
  });

  test('listSessions returns a 30-row summary page with hasMore', () async {
    final storage = await _storage(
      rawSessions: _raw([
        for (var i = 0; i < 31; i++)
          _session(
            's$i',
            messages: _messages(2),
            updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          ),
      ]),
    );
    final repository = _repository(storage);

    final page = await repository.listSessions('srv-a');
    expect(page.warning, isNull);
    expect(page.sessions.length, 30);
    expect(page.hasMore, isTrue);
    expect(page.sessions.first.id, 's30');
    expect(page.sessions.last.id, 's1');
    expect(page.sessions.every((s) => s.messages.isEmpty), isTrue);
    expect(page.sessions.every((s) => s.totalMessageCount == 2), isTrue);
    expect(page.sessions.every((s) => s.messageOffset == 2), isTrue);

    final tail = await repository.listSessions('srv-a', offset: 30);
    expect(tail.sessions.map((s) => s.id), ['s0']);
    expect(tail.hasMore, isFalse);

    final small = await repository.listSessions('srv-a', limit: 5);
    expect(small.sessions.length, 5);
    expect(small.hasMore, isTrue);
  });

  test('saving the last page keeps every earlier message', () async {
    final storage = await _storage(
      rawSessions: _raw([_session('chat', messages: _messages(120))]),
    );
    final repository = _repository(storage);
    await repository.listSessions('srv-a');

    final page = await repository.loadSession('chat');
    expect(page!.messageOffset, 70);
    expect(page.messages.length, 50);

    await repository.saveSession(
      page.copyWith(
        messages: [...page.messages, _message(120)],
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    );

    final reloaded = await repository.loadSession('chat');
    expect(reloaded!.totalMessageCount, 121);
    expect(reloaded.messageOffset, 71);
    expect(reloaded.messages.length, 50);
    expect(reloaded.messages.last.id, 'm120');

    final pages = <List<String>>[];
    ChatSession? cursor = reloaded;
    var guard = 0;
    while (cursor != null && cursor.messageOffset > 0 && guard++ < 20) {
      pages.add(cursor.messages.map((m) => m.id).toList());
      cursor = await repository.loadSession(
        'chat',
        before: cursor.messageOffset,
      );
    }
    expect(cursor, isNotNull, reason: 'pagination must reach the first page');
    pages.add(cursor!.messages.map((m) => m.id).toList());
    expect(pages.reversed.expand((page) => page), [
      for (var i = 0; i < 121; i++) 'm$i',
    ]);

    expect(
      _query('SELECT COUNT(*) AS n FROM chat_messages WHERE session_id=?', [
        'chat',
      ]).single['n'],
      121,
    );
    expect(
      _query(
        'SELECT id FROM chat_messages WHERE session_id=? AND seq<70 ORDER BY seq',
        ['chat'],
      ).map((row) => row['id']),
      [for (var i = 0; i < 70; i++) 'm$i'],
    );
  });

  test('corrupt legacy JSON never reads as an empty database', () async {
    final storage = await _storage(rawSessions: '[{"id": "broken"');
    final repository = _repository(storage);

    await expectLater(
      repository.listSessions('srv-a'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repository.loadSession('broken'),
      throwsA(isA<FormatException>()),
    );
    expect((await _prefs()).getString(_sessionsKey), '[{"id": "broken"');
    expect(
      _query("SELECT value FROM chat_meta WHERE key='legacy_imported'"),
      isEmpty,
    );
  });

  test('an unreadable database falls back to raw session records', () async {
    final storage = await _storage(
      rawSessions: _raw([
        _session(
          'a',
          messages: _messages(60),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
        _session(
          'b',
          serverId: 'srv-a',
          messages: _messages(3),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        _session('other', serverId: 'srv-b', messages: _messages(1)),
      ]),
    );
    await File(_databasePath).writeAsBytes(List<int>.filled(512, 0x58));
    final repository = _repository(storage);

    final page = await repository.listSessions('srv-a');
    expect(page.warning, startsWith('CHAT_MIGRATION_FAILED:'));
    expect(page.sessions.map((s) => s.id), ['a', 'b']);
    expect(page.sessions.every((s) => s.messages.isEmpty), isTrue);
    expect(page.sessions.first.totalMessageCount, 60);
    expect(page.sessions.first.messageOffset, 60);
    expect(page.sessions.last.totalMessageCount, 3);

    final loaded = await repository.loadSession('a');
    expect(loaded, isNotNull);
    expect(loaded!.totalMessageCount, 60);
    expect(loaded.messages.length, 50);
    expect(loaded.messageOffset, 10);
    expect(loaded.messages.map((m) => m.id), [
      for (var i = 10; i < 60; i++) 'm$i',
    ]);
    expect(await repository.loadSession('other'), isNotNull);

    expect(
      (await _prefs()).getString(_sessionsKey),
      _raw([
        _session(
          'a',
          messages: _messages(60),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
        _session(
          'b',
          serverId: 'srv-a',
          messages: _messages(3),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        _session('other', serverId: 'srv-b', messages: _messages(1)),
      ]),
    );
  });

  test('reopening the database marks streaming messages interrupted', () async {
    final storage = await _storage(
      rawSessions: _raw([
        _session(
          'a',
          messages: [
            _message(0, status: ChatTurnStatus.streaming),
            _message(1, status: ChatTurnStatus.completed),
            _message(2, status: ChatTurnStatus.failed),
          ],
        ),
      ]),
    );
    final first = _repository(storage);
    await first.listSessions('srv-a');
    expect((await first.loadSession('a'))!.messages.map((m) => m.status), [
      ChatTurnStatus.streaming,
      ChatTurnStatus.completed,
      ChatTurnStatus.failed,
    ]);

    final restarted = _repository(storage);
    expect((await restarted.loadSession('a'))!.messages.map((m) => m.status), [
      ChatTurnStatus.interrupted,
      ChatTurnStatus.completed,
      ChatTurnStatus.failed,
    ]);

    final third = _repository(storage);
    expect(
      (await third.loadSession('a'))!.messages.first.status,
      ChatTurnStatus.interrupted,
    );
    expect(
      _query(
        "SELECT value FROM chat_meta WHERE key='legacy_imported'",
      ).single['value'],
      '1',
    );
  });

  test('deleteSession removes only the targeted session', () async {
    final storage = await _storage(
      rawSessions: _raw([
        _session(
          'a',
          messages: _messages(5),
          updatedAt: DateTime.utc(2026, 1, 3),
        ),
        _session(
          'b',
          messages: _messages(3),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
        _session(
          'c',
          messages: _messages(2),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]),
    );
    final repository = _repository(storage);
    await repository.listSessions('srv-a');

    await repository.deleteSession('b');
    expect(await repository.loadSession('b'), isNull);
    expect((await repository.listSessions('srv-a')).sessions.map((s) => s.id), [
      'a',
      'c',
    ]);
    expect((await repository.loadSession('a'))!.messages.length, 5);
    expect((await repository.loadSession('c'))!.messages.length, 2);
    expect(
      _query('SELECT COUNT(*) AS n FROM chat_messages WHERE session_id=?', [
        'b',
      ]).single['n'],
      0,
    );
    expect(_query('SELECT COUNT(*) AS n FROM chat_messages').single['n'], 7);

    await repository.deleteSession('missing');
    expect((await repository.listSessions('srv-a')).sessions.map((s) => s.id), [
      'a',
      'c',
    ]);
  });

  test('rename and exports reflect the stored history', () async {
    final storage = await _storage(
      rawSessions: _raw([
        _session(
          'a',
          messages: [
            _message(0),
            _message(
              1,
              toolExecutions: const [
                ToolExecution(
                  id: 't1',
                  name: 'build',
                  command: 'make test',
                  status: ToolExecutionStatus.completed,
                  output: 'ok',
                ),
              ],
            ),
            _message(2),
          ],
        ),
      ]),
    );
    final repository = _repository(storage);
    await repository.listSessions('srv-a');

    await repository.renameSession('a', 'renamed');
    expect(
      (await repository.listSessions('srv-a')).sessions.single.title,
      'renamed',
    );
    await repository.renameSession('missing', 'ignored');

    final exported = await repository.exportSession('a');
    expect(exported, startsWith('# renamed\n'));
    expect(exported, contains('## user\n\nmessage 0'));
    expect(exported, contains('## assistant\n\nmessage 1'));
    expect(exported, contains('## user\n\nmessage 2'));
    expect(exported, contains('### build\n\nmake test\n\nok'));
    expect('\n## '.allMatches(exported).length, 3);
    await expectLater(
      repository.exportSession('missing'),
      throwsA(isA<StateError>()),
    );

    final all = jsonDecode(await repository.exportAll()) as List<dynamic>;
    expect(all.length, 1);
    final entry = Map<String, dynamic>.from(all.single as Map);
    expect(entry['id'], 'a');
    expect(entry['title'], 'renamed');
    expect(entry['messageOffset'], 0);
    expect((entry['messages'] as List<dynamic>).length, 3);
    expect(
      (entry['messages'] as List<dynamic>).map(
        (m) => (m as Map<String, dynamic>)['id'],
      ),
      ['m0', 'm1', 'm2'],
    );
  });

  test(
    'saveSession never moves an existing session to another server or agent',
    () async {
      final storage = await _storage(
        rawSessions: _raw([_session('a', messages: _messages(3))]),
      );
      final repository = _repository(storage);
      await repository.listSessions('srv-a');
      final original = (await repository.loadSession('a'))!;

      final mismatch = throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'CHAT_SESSION_IDENTITY_MISMATCH',
        ),
      );
      await expectLater(
        repository.saveSession(original.copyWith(serverId: 'srv-b')),
        mismatch,
      );
      await expectLater(
        repository.saveSession(original.copyWith(agentId: 'builtin-opencode')),
        mismatch,
      );
      await expectLater(
        repository.saveSession(
          ChatSession(
            id: 'a',
            title: 'session a',
            serverId: null,
            agentId: null,
            createdAt: original.createdAt,
            updatedAt: original.updatedAt,
            messages: original.messages,
          ),
        ),
        mismatch,
      );

      expect(
        _query(
          'SELECT server_id,agent_id,title FROM chat_sessions WHERE id=?',
          ['a'],
        ).single,
        {
          'server_id': 'srv-a',
          'agent_id': 'builtin-codex',
          'title': 'session a',
        },
      );
      final after = await repository.loadSession('a');
      expect(after!.serverId, 'srv-a');
      expect(after.agentId, 'builtin-codex');
      expect(after.messages.map((m) => m.id), ['m0', 'm1', 'm2']);
      expect(
        await repository.listSessions('srv-b').then((page) => page.sessions),
        isEmpty,
      );

      await repository.saveSession(
        original.copyWith(
          messages: [...original.messages, _message(3)],
          updatedAt: DateTime.utc(2026, 3, 1),
        ),
      );
      expect((await repository.loadSession('a'))!.totalMessageCount, 4);
      expect(
        _query('SELECT server_id FROM chat_sessions WHERE id=?', [
          'a',
        ]).single['server_id'],
        'srv-a',
      );
    },
  );

  test(
    'saveSession rolls back instead of overwriting an occupied seq',
    () async {
      final storage = await _storage(
        rawSessions: _raw([
          _session(
            'a',
            messages: _messages(5),
            updatedAt: DateTime.utc(2026, 1, 1, 5),
          ),
        ]),
      );
      final repository = _repository(storage);
      await repository.listSessions('srv-a');
      final original = (await repository.loadSession('a'))!;

      await expectLater(
        repository.saveSession(
          original.copyWith(
            updatedAt: DateTime.utc(2026, 5, 5),
            messageOffset: 0,
            messages: [
              original.messages.first.copyWith(content: 'patched'),
              _message(7),
            ],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CHAT_MESSAGE_SEQUENCE_CONFLICT',
          ),
        ),
      );

      final after = await repository.loadSession('a');
      expect(after, isNotNull);
      expect(after!.totalMessageCount, 5);
      expect(after.messages.map((m) => m.id), ['m0', 'm1', 'm2', 'm3', 'm4']);
      expect(after.messages.map((m) => m.content), [
        'message 0',
        'message 1',
        'message 2',
        'message 3',
        'message 4',
      ]);
      expect(
        _query('SELECT data FROM chat_messages WHERE session_id=? AND seq=0', [
          'a',
        ]).single['data'],
        contains('"message 0"'),
      );
      expect(
        _query('SELECT updated,title FROM chat_sessions WHERE id=?', [
          'a',
        ]).single,
        {
          'updated': DateTime.utc(2026, 1, 1, 5).toIso8601String(),
          'title': 'session a',
        },
      );

      await repository.saveSession(
        original.copyWith(
          messages: [...original.messages, _message(5)],
          updatedAt: DateTime.utc(2026, 5, 6),
        ),
      );
      expect((await repository.loadSession('a'))!.totalMessageCount, 6);
    },
  );

  test(
    'a stale snapshot queued behind renameSession cannot restore the title',
    () async {
      final storage = await _storage(
        rawSessions: _raw([_session('a', messages: _messages(4))]),
      );
      final repository = _repository(storage);
      await repository.listSessions('srv-a');

      final snapshot = (await repository.loadSession('a'))!;
      expect(snapshot.title, 'session a');

      final rename = repository.renameSession('a', 'renamed');
      final staleSave = repository.saveSession(snapshot);
      await Future.wait([rename, staleSave]);

      expect(
        (await repository.listSessions('srv-a')).sessions.single.title,
        'renamed',
      );
      expect((await repository.loadSession('a'))!.title, 'renamed');
      expect(
        _query('SELECT title FROM chat_sessions WHERE id=?', [
          'a',
        ]).single['title'],
        'renamed',
      );
      final stored =
          jsonDecode(
                _query('SELECT data FROM chat_sessions WHERE id=?', [
                      'a',
                    ]).single['data']
                    as String,
              )
              as Map<String, dynamic>;
      expect(stored['title'], 'renamed');
      expect((await repository.loadSession('a'))!.messages.map((m) => m.id), [
        'm0',
        'm1',
        'm2',
        'm3',
      ]);
    },
  );

  test(
    'large tool output pages behind a 4096 preview and reassembles exactly',
    () async {
      final repository = await _repositoryWithLargeToolOutput();
      final full = _largeToolOutput();

      final loaded = await repository.loadSession('a');
      final tool = loaded!.messages.single.toolExecutions.single;
      expect(tool.hasMoreOutput, isTrue);
      expect(tool.outputLength, full.length);
      expect(tool.output!.length, 4096);
      expect(tool.output, full.substring(full.length - 4096));
      expect(tool.output, isNot(contains('head')));

      final first = await repository.loadToolOutput('a', 'm0', 't1');
      expect(first.nextOffset, 16384);
      expect(first.text, startsWith('head'));

      final assembled = StringBuffer();
      int? offset = 0;
      var pages = 0;
      while (offset != null) {
        final page = await repository.loadToolOutput(
          'a',
          'm0',
          't1',
          offset: offset,
          limit: 4096,
        );
        assembled.write(page.text);
        pages++;
        offset = page.nextOffset;
      }
      expect(pages, greaterThan(1));
      expect(assembled.toString(), full);
      expect(assembled.toString(), contains('😀'));
    },
  );

  test(
    're-saving the preview keeps the stored full output and both exports carry it',
    () async {
      final repository = await _repositoryWithLargeToolOutput();
      final full = _largeToolOutput();

      final checkpoint = (await repository.loadSession('a'))!;
      await repository.saveSession(
        checkpoint.copyWith(updatedAt: DateTime.utc(2026, 6, 1)),
      );

      final after = await repository.loadSession('a');
      final tool = after!.messages.single.toolExecutions.single;
      expect(tool.output!.length, 4096);
      expect(tool.hasMoreOutput, isTrue);

      final reread = await repository.loadToolOutput(
        'a',
        'm0',
        't1',
        limit: 65536,
      );
      expect(reread.nextOffset, isNull);
      expect(reread.text, full);

      expect(await repository.exportSession('a'), contains(full));

      final all = jsonDecode(await repository.exportAll()) as List<dynamic>;
      final message =
          ((all.single as Map)['messages'] as List).first
              as Map<String, dynamic>;
      final exportedTool =
          (message['toolExecutions'] as List).single as Map<String, dynamic>;
      expect(exportedTool['output'], full);
      expect(exportedTool['outputLength'], isNull);
    },
  );

  test('deleting a session cascades to chat_tools rows', () async {
    final repository = await _repositoryWithLargeToolOutput();
    expect(_query('SELECT COUNT(*) AS n FROM chat_tools').single['n'], 1);
    expect(_query('SELECT message_id,tool_id FROM chat_tools').single, {
      'message_id': 'm0',
      'tool_id': 't1',
    });

    await repository.deleteSession('a');

    expect(_query('SELECT COUNT(*) AS n FROM chat_tools').single['n'], 0);
    expect(_query('SELECT COUNT(*) AS n FROM chat_messages').single['n'], 0);
    expect(await repository.loadSession('a'), isNull);
  });

  test('loadToolOutput rejects invalid page parameters', () async {
    final repository = _repository(await _storage());
    final invalid = throwsA(
      isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        'CHAT_OUTPUT_PAGE_INVALID',
      ),
    );

    await expectLater(
      repository.loadToolOutput('a', 'm0', 't1', offset: -1),
      invalid,
    );
    await expectLater(
      repository.loadToolOutput('a', 'm0', 't1', limit: 0),
      invalid,
    );
    await expectLater(
      repository.loadToolOutput('a', 'm0', 't1', limit: 65537),
      invalid,
    );
    await expectLater(
      repository.loadToolOutput('a', 'm0', 't1'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'CHAT_TOOL_OUTPUT_NOT_FOUND',
        ),
      ),
    );
  });

  test(
    '10000-message session and 500-session listing record their timings',
    () async {
      final storage = await _storage(
        rawSessions: _raw([
          for (var i = 0; i < 500; i++)
            _session(
              'bulk$i',
              messages: const [],
              updatedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
            ),
        ]),
      );
      final repository = _repository(storage);

      final migration = Stopwatch()..start();
      final firstPage = await repository.listSessions('srv-a');
      migration.stop();
      expect(firstPage.sessions.length, 30);
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.sessions.first.id, 'bulk499');
      expect(firstPage.sessions.first.totalMessageCount, 0);

      final save = Stopwatch()..start();
      await repository.saveSession(
        _session('heavy', messages: _messages(10000)),
      );
      save.stop();

      final list = Stopwatch()..start();
      final page = await repository.listSessions('srv-a');
      list.stop();
      expect(page.sessions.length, 30);
      expect(page.hasMore, isTrue);
      expect(page.sessions.first.id, 'heavy');
      expect(page.sessions.first.totalMessageCount, 10000);
      expect(page.sessions.first.messages, isEmpty);

      final tailWatch = Stopwatch()..start();
      final tail = await repository.listSessions('srv-a', offset: 470);
      tailWatch.stop();
      expect(tail.sessions.length, 30);
      expect(tail.hasMore, isTrue);
      expect(tail.sessions.first.id, 'bulk30');
      expect(tail.sessions.last.id, 'bulk1');

      final load = Stopwatch()..start();
      final loaded = await repository.loadSession('heavy');
      load.stop();
      expect(loaded, isNotNull);
      expect(loaded!.messages.length, 50);
      expect(loaded.totalMessageCount, 10000);
      expect(loaded.messageOffset, 9950);
      expect(loaded.messages.first.id, 'm9950');
      expect(loaded.messages.last.id, 'm9999');

      // ignore: avoid_print
      print(
        'chat_repository timings(ms): migrate500Sessions=${migration.elapsedMilliseconds}, '
        'save10000Messages=${save.elapsedMilliseconds}, list30=${list.elapsedMilliseconds}, '
        'listOffset470=${tailWatch.elapsedMilliseconds}, '
        'loadLatest50of10000=${load.elapsedMilliseconds}',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
