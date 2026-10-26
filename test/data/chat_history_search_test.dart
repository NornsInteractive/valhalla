import 'dart:async';
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
  String id,
  String content, {
  DateTime? createdAt,
  MessageRole role = MessageRole.user,
  List<ToolExecution> toolExecutions = const [],
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  toolExecutions: toolExecutions,
);

List<ChatMessage> _messages(
  int count, {
  String Function(int index)? content,
  DateTime? createdAt,
}) => [
  for (var i = 0; i < count; i++)
    _message(
      'm$i',
      content?.call(i) ?? 'message $i',
      createdAt:
          createdAt ?? DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
    ),
];

ChatSession _session(
  String id, {
  String? serverId = 'srv-a',
  String? agentId = 'builtin-codex',
  List<String> participantAgentIds = const [],
  List<ChatMessage> messages = const [],
  DateTime? updatedAt,
  String title = 'session',
}) => ChatSession(
  id: id,
  title: title,
  serverId: serverId,
  agentId: agentId,
  participantAgentIds: participantAgentIds,
  messages: messages,
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

List<Map<String, Object?>> _snapshot() => [
  ..._query('SELECT * FROM chat_sessions ORDER BY id'),
  ..._query('SELECT * FROM chat_messages ORDER BY session_id,seq'),
  ..._query('SELECT * FROM chat_tools ORDER BY session_id,message_id,tool_id'),
];

Matcher _argument(String code) => throwsA(
  isA<ArgumentError>().having((error) => error.message, 'message', code),
);

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
    _directory = await Directory.systemTemp.createTemp('valhalla-chat-search-');
    addTearDown(() async {
      if (_directory.existsSync()) await _directory.delete(recursive: true);
    });
  });

  test('searches literal %, _, quotes, Chinese, case and code', () async {
    final repository = _repository(await _storage());
    await repository.saveSession(
      _session(
        's',
        messages: [
          _message('m0', 'progress 100% done'),
          _message('m1', 'snake_case only'),
          _message('m2', "it's a quote"),
          _message('m3', '你好世界 Hello CODE'),
          _message('m4', 'plain text without operators'),
        ],
      ),
    );

    Future<List<String>> ids(String query) async =>
        (await repository.searchMessages(
          'srv-a',
          query: query,
        )).hits.map((hit) => hit.messageId).toList();

    expect(await ids('100%'), ['m0']);
    expect(await ids('%'), ['m0']);
    expect(await ids('_'), ['m1']);
    expect(await ids("'s"), ['m2']);
    expect(await ids('你好'), ['m3']);
    expect(await ids('code'), ['m3']);
    expect(await ids('HELLO'), ['m3']);

    final hit = (await repository.searchMessages(
      'srv-a',
      query: '你好',
    )).hits.single;
    expect(hit.matchOffset, 0);
    expect(hit.role, MessageRole.user);
    expect(hit.source, 'message');
    expect(hit.toolId, isNull);
    expect(hit.excerpt, contains('你好'));
    expect(hit.createdAt, DateTime.utc(2026, 1, 1));
  });

  test(
    'isolates servers and honours agent sharing plus legacy ownership',
    () async {
      final storage = await _storage(
        rawSessions: _raw([
          _session('a', messages: [_message('m0', 'sharedneedle in a')]),
          _session(
            'b',
            agentId: 'builtin-claude-code',
            messages: [_message('m0', 'sharedneedle in b')],
          ),
          _session(
            'c',
            agentId: 'builtin-claude-code',
            participantAgentIds: const ['builtin-codex'],
            messages: [_message('m0', 'sharedneedle in c')],
          ),
          _session(
            'd',
            serverId: 'srv-b',
            messages: [_message('m0', 'sharedneedle in d')],
          ),
          _session(
            'legacy',
            serverId: null,
            agentId: null,
            messages: [_message('m0', 'legacyneedle only')],
          ),
        ]),
      );
      final repository = _repository(storage);

      // Initialize without claiming legacy ownership.
      expect(await repository.loadSession('missing'), isNull);
      expect(storage.legacyOwnershipServerId, isNull);

      Future<List<String>> ids({
        String serverId = 'srv-a',
        String? agentId,
        required String query,
      }) async => (await repository.searchMessages(
        serverId,
        agentId: agentId,
        query: query,
      )).hits.map((hit) => hit.sessionId).toList();

      expect(await ids(agentId: 'builtin-codex', query: 'sharedneedle'), [
        'a',
        'c',
      ]);
      expect(await ids(query: 'sharedneedle'), ['a', 'b', 'c']);
      expect(await ids(serverId: 'srv-b', query: 'sharedneedle'), ['d']);
      expect(await ids(query: 'legacyneedle'), isEmpty);
      expect(await ids(serverId: 'srv-b', query: 'legacyneedle'), isEmpty);

      storage.claimLegacyOwnership('srv-a');
      expect(await ids(query: 'legacyneedle'), ['legacy']);
      expect(await ids(serverId: 'srv-b', query: 'legacyneedle'), isEmpty);
    },
  );

  test('keyset paging over equal timestamps never repeats a hit', () async {
    final repository = _repository(await _storage());
    final stamp = DateTime.utc(2026, 2, 2, 2, 2, 2);
    await repository.saveSession(
      _session(
        'a',
        messages: [
          for (var i = 0; i < 3; i++)
            _message('a$i', 'dup a$i', createdAt: stamp),
        ],
      ),
    );
    await repository.saveSession(
      _session(
        'b',
        messages: [
          for (var i = 0; i < 3; i++)
            _message('b$i', 'dup b$i', createdAt: stamp),
        ],
      ),
    );

    final seen = <String>[];
    final pages = <List<String>>[];
    String? cursor;
    var guard = 0;
    do {
      final page = await repository.searchMessages(
        'srv-a',
        query: 'dup',
        limit: 2,
        cursor: cursor,
      );
      pages.add(page.hits.map((hit) => hit.messageId).toList());
      seen.addAll(page.hits.map((hit) => hit.messageId));
      cursor = page.nextCursor;
      guard++;
    } while (cursor != null && guard < 20);

    expect(guard, 3);
    expect(pages.first, ['a2', 'a1']);
    expect(seen, hasLength(6));
    expect(seen.toSet(), {'a0', 'a1', 'a2', 'b0', 'b1', 'b2'});
    expect(seen.toSet(), hasLength(seen.length), reason: 'no repeats');
  });

  test(
    'tool full output beyond the saved preview matches by astral offset',
    () async {
      final output = 'head-${'😀' * 100}NEEDLE-IN-FULL${'x' * 30000}';
      final runeOffset = 'head-'.runes.length + 100;
      expect(runeOffset, 105);
      expect(output.indexOf('NEEDLE-IN-FULL'), 205);

      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's',
          messages: [
            _message(
              'm0',
              'tool turn',
              toolExecutions: [
                ToolExecution(
                  id: 't1',
                  name: 'build',
                  command: 'make',
                  status: ToolExecutionStatus.completed,
                  output: output,
                ),
              ],
            ),
          ],
        ),
      );

      final hit = (await repository.searchMessages(
        'srv-a',
        query: 'needle-in-full',
      )).hits.single;
      expect(hit.source, 'tool');
      expect(hit.toolId, 't1');
      expect(hit.messageId, 'm0');
      expect(hit.matchOffset, runeOffset);
      expect(hit.excerpt, contains('NEEDLE-IN-FULL'));

      final saved = (await repository.loadSession(
        's',
      ))!.messages.single.toolExecutions.single;
      expect(saved.hasMoreOutput, isTrue);
      expect(saved.output, isNot(contains('NEEDLE-IN-FULL')));
      expect(saved.output!.length, 4096);

      final page = await repository.loadToolOutput(
        's',
        'm0',
        't1',
        offset: hit.matchOffset,
        limit: 16,
      );
      expect(page.text, startsWith('NEEDLE-IN-FULL'));
      expect(page.nextOffset, isNotNull);
    },
  );

  test('loadMessageWindow reads around the target without writing', () async {
    final repository = _repository(await _storage());
    await repository.saveSession(
      _session('w', messages: _messages(40, content: (i) => 'window $i')),
    );
    final before = _snapshot();

    final window = await repository.loadMessageWindow('w', 'm20', radius: 2);
    expect(window, isNotNull);
    expect(window!.messages.map((message) => message.id), [
      'm18',
      'm19',
      'm20',
      'm21',
      'm22',
    ]);
    expect(window.messageOffset, 18);
    expect(window.totalMessageCount, 40);

    final exact = await repository.loadMessageWindow('w', 'm20', radius: 0);
    expect(exact!.messages.map((message) => message.id), ['m20']);

    final tail = await repository.loadMessageWindow('w', 'm39', radius: 2);
    expect(tail, isNotNull);
    expect(tail!.messages.map((message) => message.id), ['m37', 'm38', 'm39']);
    expect(tail.messageOffset, 37);

    final head = await repository.loadMessageWindow('w', 'm0', radius: 2);
    expect(head, isNotNull);
    expect(head!.messages.map((message) => message.id), ['m0', 'm1', 'm2']);
    expect(head.messageOffset, 0);

    expect(_snapshot(), before, reason: 'window reads must not persist drafts');
    expect(await repository.loadMessageWindow('w', 'missing'), isNull);
  });

  test('validates query, cursor and window radius', () async {
    final repository = _repository(await _storage());
    await repository.saveSession(_session('s', messages: _messages(3)));

    await expectLater(
      repository.searchMessages('srv-a', query: 'x', limit: 0),
      _argument('CHAT_SEARCH_INVALID_QUERY'),
    );
    await expectLater(
      repository.searchMessages('srv-a', query: 'x', limit: 101),
      _argument('CHAT_SEARCH_INVALID_QUERY'),
    );
    await expectLater(
      repository.searchMessages('srv-a', query: 'a' * 513),
      _argument('CHAT_SEARCH_INVALID_QUERY'),
    );

    for (final query in ['', '   ']) {
      final page = await repository.searchMessages('srv-a', query: query);
      expect(page.hits, isEmpty);
      expect(page.nextCursor, isNull);
    }

    for (final cursor in [
      'not-json',
      '[]',
      '["x",1,2,3,4]',
      '[0,1,2,3,4]',
      '[0,"s",2,3]',
      '[0,"s",2,3,4,5]',
      'a' * 3000,
    ]) {
      await expectLater(
        repository.searchMessages('srv-a', query: 'x', cursor: cursor),
        _argument('CHAT_SEARCH_INVALID_CURSOR'),
      );
    }

    for (final radius in [-1, 51]) {
      await expectLater(
        repository.loadMessageWindow('s', 'm0', radius: radius),
        _argument('CHAT_SEARCH_INVALID_WINDOW'),
      );
    }
    expect(
      (await repository.loadMessageWindow('s', 'm0', radius: 50))!.messages,
      hasLength(3),
    );
  });

  test(
    '10,000 saved messages stay scoped, bounded and event-loop responsive',
    () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          'bulk',
          messages: _messages(
            10000,
            content: (i) => i % 100 == 0 ? 'needle $i' : 'filler $i',
          ),
        ),
      );
      await repository.saveSession(
        _session('other', messages: [_message('m0', 'needle other')]),
      );

      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      final watch = Stopwatch()..start();
      final page = await repository.searchMessages(
        'srv-a',
        sessionId: 'bulk',
        query: 'needle',
        limit: 30,
      );
      watch.stop();
      timer.cancel();

      expect(page.hits, hasLength(30));
      expect(page.nextCursor, isNotNull);
      expect(page.hits.every((hit) => hit.sessionId == 'bulk'), isTrue);
      expect(page.hits.every((hit) => hit.source == 'message'), isTrue);
      expect(
        ticks,
        greaterThan(0),
        reason: 'search must yield to the event loop',
      );

      // ignore: avoid_print
      print(
        'chat_search timings: elapsed=${watch.elapsedMilliseconds}ms '
        'ticks=$ticks hits=${page.hits.length}',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
