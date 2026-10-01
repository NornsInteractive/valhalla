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

const _agentId = 'builtin-codex';

late Directory _directory;
String get _databasePath => '${_directory.path}/chat.sqlite3';

DateTime _at(int minute) =>
    DateTime.utc(2026, 1, 1).add(Duration(minutes: minute));

ChatMessage _message(
  int index, {
  MessageRole? role,
  String? content,
  String? remoteMessageId,
  String? agentId = _agentId,
  DateTime? createdAt,
  ChatTurnStatus status = ChatTurnStatus.completed,
}) => ChatMessage(
  id: 'm$index',
  role: role ?? (index.isEven ? MessageRole.user : MessageRole.assistant),
  content: content ?? 'message $index',
  remoteMessageId: remoteMessageId,
  agentId: agentId,
  status: status,
  createdAt: createdAt ?? _at(index),
);

ChatSession _session(
  String id, {
  String? serverId = 'srv-a',
  String? agentId = _agentId,
  List<String> participantAgentIds = const [],
  Map<String, AgentChatContext> agentContexts = const {},
  List<ChatMessage> messages = const [],
  int messageOffset = 0,
  DateTime? updatedAt,
}) => ChatSession(
  id: id,
  title: 'session $id',
  serverId: serverId,
  agentId: agentId,
  participantAgentIds: participantAgentIds,
  agentContexts: agentContexts,
  messages: messages,
  messageOffset: messageOffset,
  createdAt: DateTime.utc(2026),
  updatedAt: updatedAt ?? _at(60),
);

ChatRepository _repository(LocalStorageService storage) =>
    ChatRepository(storage, databasePath: _databasePath);

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return LocalStorageService(await SharedPreferences.getInstance());
}

/// 按 seq 读回消息，用来断言「用户看到的顺序与本地 id」。
List<Map<String, Object?>> _rows(String sessionId) {
  final db = sqlite3.open(_databasePath);
  try {
    db.execute('PRAGMA busy_timeout = 5000');
    return db.select(
      'SELECT seq,id,data FROM chat_messages WHERE session_id=? ORDER BY seq',
      [sessionId],
    );
  } finally {
    db.dispose();
  }
}

List<ChatMessage> _storedMessages(String sessionId) => [
  for (final row in _rows(sessionId))
    ChatMessage.fromJson(
      jsonDecode(row['data'] as String) as Map<String, dynamic>,
    ),
];

Matcher _code(String code) => throwsA(
  isA<StateError>().having((e) => e.message, 'message', contains(code)),
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
    _directory = await Directory.systemTemp.createTemp(
      'valhalla-replay-merge-',
    );
    addTearDown(() async {
      if (_directory.existsSync()) await _directory.delete(recursive: true);
    });
  });

  group('历史重放合并去重', () {
    test('重复重放同一批历史不会产生重复行，也不会换掉本地 id', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's1',
          messages: [
            _message(0, content: 'hello'),
            _message(1, content: 'hi'),
          ],
        ),
      );

      final replay = _session(
        's1',
        messages: [
          _message(90, content: 'hello', createdAt: _at(900)),
          _message(91, content: 'hi', createdAt: _at(901)),
          _message(92, content: 'and more', createdAt: _at(902)),
        ],
      );
      await repository.mergeReplayBatch(replay, _agentId);
      final afterFirst = _storedMessages('s1');

      expect(afterFirst.map((m) => m.content), ['hello', 'hi', 'and more']);
      expect(afterFirst.take(2).map((m) => m.id), [
        'm0',
        'm1',
      ], reason: '已知消息必须保住本地 id，否则滚动锚点会跳');
      expect(afterFirst.first.createdAt, _at(0), reason: '创建时间也不能被重放改写');

      // 同一批再放一次：这是恢复过程中最容易发生的重复来源。
      await repository.mergeReplayBatch(replay, _agentId);
      final afterSecond = _storedMessages('s1');

      expect(afterSecond, hasLength(3), reason: '重放必须是幂等的');
      expect(afterSecond.map((m) => m.id), [
        'm0',
        'm1',
        'm92',
      ], reason: '第二次重放不得换 id，也不得再加一行');
      expect(afterSecond.map((m) => m.content), ['hello', 'hi', 'and more']);
    });

    test('按远端 id 命中的消息原地补齐，保留本地 id 与时间', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's2',
          messages: [
            _message(0, content: 'question', remoteMessageId: 'r0'),
            _message(1, content: 'partial', remoteMessageId: 'r1'),
          ],
        ),
      );

      await repository.mergeReplayBatch(
        _session(
          's2',
          messages: [
            _message(50, content: 'question', remoteMessageId: 'r0'),
            _message(
              51,
              content: 'partial and complete',
              remoteMessageId: 'r1',
              createdAt: _at(999),
            ),
          ],
          messageOffset: 7,
        ),
        _agentId,
      );

      final stored = _storedMessages('s2');
      expect(stored, hasLength(2));
      expect(stored[1].content, 'partial and complete');
      expect(stored[1].id, 'm1', reason: '远端 id 命中也要保住本地 id');
      expect(stored[1].createdAt, _at(1));
      expect(stored[1].remoteMessageId, 'r1');
    });

    test('更短的快照不得抹掉已经收到的更长输出', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's3',
          messages: [_message(0, content: 'full answer with everything')],
        ),
      );

      await expectLater(
        repository.mergeReplayBatch(
          _session('s3', messages: [_message(10, content: 'full answer')]),
          _agentId,
        ),
        _code('ACP_HISTORY_REPLAY_AMBIGUOUS'),
      );
      expect(
        _storedMessages('s3').single.content,
        'full answer with everything',
        reason: '失败必须整体回滚，本地内容一个字都不能少',
      );
    });

    test('角色对不上的重放被拒绝，且不留下半截写入', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's4',
          messages: [
            _message(0, content: 'hello'),
            _message(1, content: 'hi'),
          ],
        ),
      );

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            's4',
            messages: [
              _message(20, content: 'hello'),
              // 第二条被换成了用户消息：顺序对不上，必须整体拒绝。
              _message(21, role: MessageRole.user, content: 'hi'),
            ],
          ),
          _agentId,
        ),
        _code('ACP_HISTORY_REPLAY_AMBIGUOUS'),
      );

      final rows = _rows('s4');
      expect(rows, hasLength(2), reason: '同一批里前一条也不该被提交');
      expect(rows.first['id'], 'm0');
    });

    test('共享会话里没有远端 id 的重放被拒绝，而不是按序号覆盖', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's5',
          participantAgentIds: const [_agentId, 'builtin-claude-code'],
          messages: [_message(0, content: 'hello')],
        ),
      );

      await expectLater(
        repository.mergeReplayBatch(
          _session('s5', messages: [_message(30, content: 'hello')]),
          _agentId,
        ),
        _code('ACP_HISTORY_REPLAY_AMBIGUOUS'),
      );
      expect(_storedMessages('s5').single.content, 'hello');
    });

    test('共享会话可以按远端 id 补齐已有消息', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's6',
          participantAgentIds: const [_agentId, 'builtin-claude-code'],
          messages: [_message(0, content: 'hello', remoteMessageId: 'r0')],
        ),
      );

      await repository.mergeReplayBatch(
        _session(
          's6',
          messages: [
            _message(
              0,
              content: 'hello and more',
              remoteMessageId: 'r0',
              createdAt: _at(999),
            ),
          ],
        ),
        _agentId,
      );

      final stored = _storedMessages('s6');
      expect(stored.map((m) => m.content), ['hello and more']);
      expect(stored.single.id, 'm0', reason: '远端 id 命中必须保住本地 id');
    });

    test('共享会话里出现全新消息时整体拒绝，交给上层降级为部分不可恢复', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's6b',
          participantAgentIds: const [_agentId, 'builtin-claude-code'],
          messages: [_message(0, content: 'hello', remoteMessageId: 'r0')],
        ),
      );

      // 共享会话里无法用序号判断新消息属于谁，追加必须失败而不是猜。
      await expectLater(
        repository.mergeReplayBatch(
          _session(
            's6b',
            messages: [
              _message(0, content: 'hello', remoteMessageId: 'r0'),
              _message(1, content: 'brand new', remoteMessageId: 'r1'),
            ],
          ),
          _agentId,
        ),
        _code('ACP_HISTORY_REPLAY_AMBIGUOUS'),
      );
      expect(_storedMessages('s6b').map((m) => m.content), ['hello']);
    });
  });

  group('重放的身份与边界', () {
    test('会话不存在时明确报错，而不是静默新建', () async {
      final repository = _repository(await _storage());

      await expectLater(
        repository.mergeReplayBatch(
          _session('missing', messages: [_message(0)]),
          _agentId,
        ),
        _code('CHAT_SESSION_NOT_FOUND'),
      );
    });

    test('服务器不一致的重放被拒绝', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(_session('s7', messages: [_message(0)]));

      await expectLater(
        repository.mergeReplayBatch(
          _session('s7', serverId: 'srv-other', messages: [_message(1)]),
          _agentId,
        ),
        _code('CHAT_SESSION_IDENTITY_MISMATCH'),
      );
    });

    test('该会话不属于这个 agent 时被拒绝', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(_session('s8', messages: [_message(0)]));

      await expectLater(
        repository.mergeReplayBatch(
          _session('s8', messages: [_message(1)]),
          'builtin-claude-code',
        ),
        _code('CHAT_SESSION_IDENTITY_MISMATCH'),
      );
    });

    test('从中间序号开始的批次不会覆盖前面的历史', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's9',
          messages: [
            _message(0, content: 'a'),
            _message(1, content: 'b'),
            _message(2, content: 'c'),
          ],
        ),
      );

      // 远端只回放了尾部两条，且带了远端 id。
      await repository.mergeReplayBatch(
        _session(
          's9',
          messageOffset: 1,
          messages: [
            _message(1, content: 'b', remoteMessageId: 'r1'),
            _message(2, content: 'c', remoteMessageId: 'r2'),
          ],
        ),
        _agentId,
      );

      final stored = _storedMessages('s9');
      expect(stored.map((m) => m.content), ['a', 'b', 'c']);
      expect(stored.map((m) => m.id), ['m0', 'm1', 'm2']);
    });

    test('带中断状态的本地消息在重放后被补齐为完成态', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(
        _session(
          's10',
          messages: [
            _message(0, content: 'question'),
            _message(
              1,
              content: 'cut off',
              remoteMessageId: 'r1',
              status: ChatTurnStatus.interrupted,
            ),
          ],
        ),
      );

      await repository.mergeReplayBatch(
        _session(
          's10',
          messages: [
            _message(
              1,
              content: 'cut off but finished',
              remoteMessageId: 'r1',
              createdAt: _at(999),
            ),
          ],
        ),
        _agentId,
      );

      final stored = _storedMessages('s10');
      expect(stored, hasLength(2));
      expect(stored[1].content, 'cut off but finished');
      expect(stored[1].id, 'm1');
      expect(stored[1].createdAt, _at(1));
    });

    test('空批次是安全的空操作', () async {
      final repository = _repository(await _storage());
      await repository.saveSession(_session('s11', messages: [_message(0)]));

      await repository.mergeReplayBatch(_session('s11'), _agentId);

      expect(_storedMessages('s11'), hasLength(1));
    });
  });
}
