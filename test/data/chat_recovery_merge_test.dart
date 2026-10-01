import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

/// Replay merge regression coverage for background recovery.
///
/// `ChatRepository.mergeReplayBatch` is the only path allowed to fold remote ACP
/// replay into an existing local session. It must be idempotent, must never
/// change local message ids (they are scroll anchors), must never let a short or
/// ambiguous replay erase output the user already has, and must fail closed for
/// any session/agent it does not own.

const _agent = 'builtin-codex';
const _otherAgent = 'builtin-agy';
const _server = 'srv-a';

const _ambiguous = 'ACP_HISTORY_REPLAY_AMBIGUOUS';
const _identityMismatch = 'CHAT_SESSION_IDENTITY_MISMATCH';
const _notFound = 'CHAT_SESSION_NOT_FOUND';

late Directory _directory;
String get _databasePath => '${_directory.path}/chat.sqlite3';

final DateTime _epoch = DateTime.utc(2026, 3, 1, 8);

ChatMessage _message(
  String id, {
  String content = '',
  MessageRole role = MessageRole.assistant,
  String? remoteMessageId,
  String? agentId = _agent,
  List<ToolExecution> toolExecutions = const [],
  List<ChatAttachment> attachments = const [],
  String? thinking,
  int minutes = 0,
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  remoteMessageId: remoteMessageId,
  agentId: agentId,
  toolExecutions: toolExecutions,
  attachments: attachments,
  thinking: thinking,
  createdAt: _epoch.add(Duration(minutes: minutes)),
);

ToolExecution _tool(String id, {String output = 'ok'}) => ToolExecution(
  id: id,
  name: 'shell',
  command: 'ls',
  status: ToolExecutionStatus.completed,
  output: output,
);

ChatAttachment _attachment(String id) => ChatAttachment(
  id: id,
  name: '$id.png',
  mimeType: 'image/png',
  sizeBytes: 4,
);

ChatSession _session(
  String id, {
  String? serverId = _server,
  String? agentId = _agent,
  List<String> participantAgentIds = const [],
  Map<String, AgentChatContext> agentContexts = const {},
  List<ChatMessage> messages = const [],
  int messageOffset = 0,
  String? remoteSessionId,
}) => ChatSession(
  id: id,
  title: 'session $id',
  serverId: serverId,
  agentId: agentId,
  participantAgentIds: participantAgentIds,
  agentContexts: agentContexts,
  remoteSessionId: remoteSessionId,
  messages: messages,
  messageOffset: messageOffset,
  createdAt: _epoch,
  updatedAt: _epoch.add(const Duration(hours: 1)),
);

Future<ChatRepository> _repository() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return ChatRepository(storage, databasePath: _databasePath);
}

/// Raw persisted rows, so assertions see the database and not just the API.
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

int _count(String sessionId) => _rows(sessionId).length;

Future<ChatSession> _stored(ChatRepository repository, String id) async {
  final loaded = await repository.loadSession(id, limit: 500);
  expect(loaded, isNotNull, reason: 'session $id must still be loadable');
  return loaded!;
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
      'valhalla-replay-merge-',
    );
    addTearDown(() async {
      if (_directory.existsSync()) await _directory.delete(recursive: true);
    });
  });

  group('mergeReplayBatch idempotence', () {
    test('replaying the identical batch twice changes nothing', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message('m0', role: MessageRole.user, content: 'hi', minutes: 0),
            _message(
              'm1',
              content: 'Hel',
              remoteMessageId: 'r-1',
              thinking: 'thinking',
              minutes: 1,
            ),
          ],
        ),
      );
      final batch = _session(
        'a',
        messageOffset: 1,
        messages: [
          _message(
            'incoming-1',
            content: 'Hello world',
            remoteMessageId: 'r-1',
            minutes: 99,
          ),
        ],
      );

      await repository.mergeReplayBatch(batch, _agent);
      final afterFirst = _rows('a');
      final stored = await _stored(repository, 'a');
      expect(stored.messages.map((m) => m.content), ['hi', 'Hello world']);
      expect(stored.messages.last.id, 'm1');
      expect(stored.messages.last.thinking, 'thinking');
      expect(stored.messages.last.remoteMessageId, 'r-1');

      await repository.mergeReplayBatch(batch, _agent);

      expect(_rows('a'), afterFirst, reason: 'second merge must be a no-op');
      final again = await _stored(repository, 'a');
      expect(again.messages.map((m) => m.content), ['hi', 'Hello world']);
      expect(again.messages.map((m) => m.id), ['m0', 'm1']);
      expect(again.totalMessageCount, 2);
    });

    test('a batch replayed after an extension still keeps one row', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [_message('m0', role: MessageRole.user, content: 'hi')],
        ),
      );
      await repository.mergeReplayBatch(
        _session(
          'a',
          messageOffset: 1,
          messages: [
            _message('incoming-0', content: 'one', remoteMessageId: 'r-1'),
          ],
        ),
        _agent,
      );
      await repository.mergeReplayBatch(
        _session(
          'a',
          messageOffset: 1,
          messages: [
            _message('incoming-0', content: 'one', remoteMessageId: 'r-1'),
          ],
        ),
        _agent,
      );
      expect(_count('a'), 2);
      final stored = await _stored(repository, 'a');
      expect(stored.messages.map((m) => m.content), ['hi', 'one']);
      expect(stored.messages.last.id, 'incoming-0');
    });
  });

  group('local id stability', () {
    test(
      'extends partial assistant text without moving the local anchor',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', role: MessageRole.user, content: 'hi', minutes: 0),
              _message(
                'm1',
                content: 'Hel',
                remoteMessageId: 'r-1',
                minutes: 1,
              ),
            ],
          ),
        );
        final before = await _stored(repository, 'a');

        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 1,
            messages: [
              _message('incoming-1', content: 'Hello', remoteMessageId: 'r-1'),
            ],
          ),
          _agent,
        );

        final after = await _stored(repository, 'a');
        expect(after.messages.map((m) => m.id), ['m0', 'm1']);
        expect(after.messages[1].content, 'Hello');
        expect(
          after.messages[1].createdAt,
          before.messages[1].createdAt,
          reason: 'createdAt anchors must survive replay',
        );
        expect(after.totalMessageCount, 2);
      },
    );

    test(
      'ordinal fallback merges into the existing row, never a new one',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', role: MessageRole.user, content: 'hi'),
              _message('m1', content: 'answer so far'),
            ],
          ),
        );

        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 1,
            messages: [
              _message('incoming-1', content: 'answer so far, continued'),
            ],
          ),
          _agent,
        );

        final stored = await _stored(repository, 'a');
        expect(_count('a'), 2);
        expect(stored.messages.map((m) => m.id), ['m0', 'm1']);
        expect(stored.messages[1].content, 'answer so far, continued');
      },
    );
  });

  group('tool and attachment preservation', () {
    test('replay without tools keeps local tools and attachments', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message(
              'm0',
              content: 'Hel',
              remoteMessageId: 'r-1',
              toolExecutions: [_tool('t1', output: 'local tool output')],
              attachments: [_attachment('a1')],
            ),
          ],
        ),
      );

      await repository.mergeReplayBatch(
        _session(
          'a',
          messageOffset: 0,
          messages: [
            _message('incoming-0', content: 'Hello', remoteMessageId: 'r-1'),
          ],
        ),
        _agent,
      );

      final message = (await _stored(repository, 'a')).messages.single;
      expect(message.content, 'Hello');
      expect(message.id, 'm0');
      expect(
        message.toolExecutions.map((t) => t.id),
        ['t1'],
        reason: 'replay without tools must not drop local tool calls',
      );
      expect(message.toolExecutions.single.output, 'local tool output');
      expect(
        message.attachments.map((a) => a.id),
        ['a1'],
        reason: 'replay without attachments must not drop local attachments',
      );
    });

    test(
      'replay unions its tools and attachments with the local ones',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message(
                'm0',
                content: 'Hel',
                remoteMessageId: 'r-1',
                toolExecutions: [_tool('t1', output: 'kept')],
                attachments: [_attachment('a1')],
              ),
            ],
          ),
        );
        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message('incoming-0', content: 'Hello', remoteMessageId: 'r-1'),
            ],
          ),
          _agent,
        );

        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message(
                'incoming-0',
                content: 'Hello again',
                remoteMessageId: 'r-1',
                toolExecutions: [
                  _tool('t1', output: 'superseded'),
                  _tool('t2', output: 'remote tool output'),
                ],
                attachments: [_attachment('a2')],
              ),
            ],
          ),
          _agent,
        );

        final message = (await _stored(repository, 'a')).messages.single;
        expect(message.content, 'Hello again');
        expect(message.id, 'm0');
        expect(message.toolExecutions.map((t) => t.id), ['t1', 't2']);
        expect(
          message.toolExecutions.first.output,
          'superseded',
          reason: 'replay wins for the same tool id',
        );
        expect(message.attachments.map((a) => a.id), ['a1', 'a2']);
      },
    );
  });

  group('replay can never erase or rewrite local content', () {
    test('a shorter replay is rejected and local text survives', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message('m0', content: 'Hello world', remoteMessageId: 'r-1'),
          ],
        ),
      );
      final before = _rows('a');

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message('incoming-0', content: 'Hello', remoteMessageId: 'r-1'),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', _ambiguous),
        ),
      );

      expect(_rows('a'), before, reason: 'a refused replay must not write');
      expect(
        (await _stored(repository, 'a')).messages.single.content,
        'Hello world',
      );
    });

    test(
      'a divergent ordinal replay is rejected and local text survives',
      () async {
        // No remote id: the merge can only fall back to the ordinal position, and
        // text which is not an extension of the local row is ambiguous.
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', role: MessageRole.user, content: 'hi'),
              _message('m1', content: 'Hello world'),
            ],
          ),
        );
        final before = _rows('a');

        await expectLater(
          repository.mergeReplayBatch(
            _session(
              'a',
              messageOffset: 1,
              messages: [
                _message('incoming-1', content: 'Totally different answer'),
              ],
            ),
            _agent,
          ),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', _ambiguous),
          ),
        );

        expect(_rows('a'), before);
        expect(
          (await _stored(repository, 'a')).messages.last.content,
          'Hello world',
        );
      },
    );

    test(
      'a replay may not straddle a local attachment with empty text',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', content: '', attachments: [_attachment('a1')]),
            ],
          ),
        );
        final before = _rows('a');

        await expectLater(
          repository.mergeReplayBatch(
            _session(
              'a',
              messageOffset: 0,
              messages: [_message('incoming-0', content: 'now with text')],
            ),
            _agent,
          ),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', _ambiguous),
          ),
        );

        expect(_rows('a'), before);
        final message = (await _stored(repository, 'a')).messages.single;
        expect(message.content, '');
        expect(message.attachments.map((a) => a.id), ['a1']);
      },
    );

    test(
      'a longer replay under the same remote id corrects the text',
      () async {
        // The remote id is the identity of the message, so the agent stays
        // authoritative for its own text; only shrinking is forbidden.
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', content: 'Hello', remoteMessageId: 'r-1'),
            ],
          ),
        );

        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message(
                'incoming-0',
                content: 'Hello world, corrected remotely',
                remoteMessageId: 'r-1',
              ),
            ],
          ),
          _agent,
        );

        final message = (await _stored(repository, 'a')).messages.single;
        expect(_count('a'), 1);
        expect(message.id, 'm0');
        expect(message.content, 'Hello world, corrected remotely');
      },
    );

    test('a shorter replay is refused even when the text diverges', () async {
      // The remote id matches, so identity checks pass; the shorter length is
      // the only thing left that can protect the local text.
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message(
              'm0',
              content: 'A much longer local answer',
              remoteMessageId: 'r-1',
            ),
          ],
        ),
      );
      final before = _rows('a');

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message('incoming-0', content: 'zzz', remoteMessageId: 'r-1'),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', _ambiguous),
        ),
      );

      expect(_rows('a'), before, reason: 'a shorter replay must not write');
      expect(
        (await _stored(repository, 'a')).messages.single.content,
        'A much longer local answer',
      );
    });

    test('a replay carrying a foreign agent id is refused', () async {
      // The batch would otherwise append cleanly at the next ordinal, so the
      // refusal can only come from the incoming message's own agent.
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [_message('m0', role: MessageRole.user, content: 'hi')],
        ),
      );
      final before = _rows('a');

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 1,
            messages: [
              _message(
                'incoming-0',
                content: 'answer from the wrong agent',
                agentId: _otherAgent,
                remoteMessageId: 'r-1',
              ),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            _identityMismatch,
          ),
        ),
      );

      expect(_rows('a'), before);
      expect(_count('a'), 1);
    });

    test('a replay that flips the role is rejected', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message('m0', content: 'Hello world', remoteMessageId: 'r-1'),
          ],
        ),
      );

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 0,
            messages: [
              _message(
                'incoming-0',
                role: MessageRole.user,
                content: 'Hello world!',
                remoteMessageId: 'r-1',
              ),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', _ambiguous),
        ),
      );
      expect(
        (await _stored(repository, 'a')).messages.single.role,
        MessageRole.assistant,
      );
    });

    test(
      'a batch contradicting itself rolls back every earlier write',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [
              _message('m0', role: MessageRole.user, content: 'hi'),
              _message('m1', content: 'Hello world', remoteMessageId: 'r-1'),
            ],
          ),
        );
        final before = _rows('a');

        await expectLater(
          repository.mergeReplayBatch(
            _session(
              'a',
              messageOffset: 0,
              messages: [
                _message(
                  'incoming-0',
                  content: 'Hello world!',
                  remoteMessageId: 'r-1',
                ),
                _message('incoming-1', content: 'Hello'),
              ],
            ),
            _agent,
          ),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', _ambiguous),
          ),
        );

        expect(_rows('a'), before, reason: 'a failed batch must be atomic');
        final stored = await _stored(repository, 'a');
        expect(stored.messages.map((m) => m.content), ['hi', 'Hello world']);
      },
    );
  });

  group('duplicate text is never collapsed', () {
    test('same text under two remote ids stays two messages', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [
            _message(
              'm0',
              role: MessageRole.user,
              content: 'ok',
              remoteMessageId: 'ru-1',
            ),
            _message('m1', content: 'ok', remoteMessageId: 'ra-1'),
          ],
        ),
      );

      await repository.mergeReplayBatch(
        _session(
          'a',
          messageOffset: 0,
          messages: [
            _message(
              'incoming-0',
              role: MessageRole.user,
              content: 'ok',
              remoteMessageId: 'ru-1',
            ),
            _message('incoming-1', content: 'ok', remoteMessageId: 'ra-1'),
          ],
        ),
        _agent,
      );

      final stored = await _stored(repository, 'a');
      expect(_count('a'), 2, reason: 'identical text must not deduplicate');
      expect(stored.messages.map((m) => m.id), ['m0', 'm1']);
      expect(
        stored.messages.map((m) => m.remoteMessageId),
        ['ru-1', 'ra-1'],
        reason: 'each remote id keeps its own message',
      );
    });

    test(
      'new duplicate-text messages with distinct ids are both appended',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          _session(
            'a',
            messages: [_message('m0', role: MessageRole.user, content: 'hi')],
          ),
        );

        await repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 1,
            messages: [
              _message('incoming-0', content: 'ok', remoteMessageId: 'r-9'),
              _message('incoming-1', content: 'ok', remoteMessageId: 'r-10'),
            ],
          ),
          _agent,
        );

        final stored = await _stored(repository, 'a');
        expect(_count('a'), 3);
        expect(stored.messages.map((m) => m.id), [
          'm0',
          'incoming-0',
          'incoming-1',
        ]);
        expect(stored.messages.map((m) => m.content), ['hi', 'ok', 'ok']);
        expect(stored.messages.map((m) => m.remoteMessageId), [
          null,
          'r-9',
          'r-10',
        ]);
      },
    );
  });

  group('identity is enforced', () {
    test('a replay for another server is refused', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [_message('m0', role: MessageRole.user, content: 'hi')],
        ),
      );
      final before = _rows('a');

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            serverId: 'srv-b',
            messageOffset: 1,
            messages: [
              _message(
                'incoming-0',
                content: 'from another server',
                remoteMessageId: 'r-1',
              ),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            _identityMismatch,
          ),
        ),
      );

      expect(_rows('a'), before);
      expect(_count('a'), 1);
    });

    test('a replay for an agent outside the session is refused', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [_message('m0', role: MessageRole.user, content: 'hi')],
        ),
      );
      final before = _rows('a');

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'a',
            messageOffset: 1,
            messages: [
              _message(
                'incoming-0',
                content: 'from another agent',
                agentId: _otherAgent,
                remoteMessageId: 'r-1',
              ),
            ],
          ),
          _otherAgent,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            _identityMismatch,
          ),
        ),
      );

      expect(_rows('a'), before);
    });

    test('a replay for an unknown session is refused', () async {
      final repository = await _repository();
      await repository.saveSession(
        _session(
          'a',
          messages: [_message('m0', role: MessageRole.user, content: 'hi')],
        ),
      );

      await expectLater(
        repository.mergeReplayBatch(
          _session(
            'missing',
            messageOffset: 0,
            messages: [
              _message('incoming-0', content: 'orphan', remoteMessageId: 'r-1'),
            ],
          ),
          _agent,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', _notFound),
        ),
      );
      expect(_count('missing'), 0);
    });
  });

  group('shared agent sessions cannot cross-merge', () {
    /// A session where two agents interleave, exactly the shape that makes the
    /// ordinal fallback unsafe.
    ChatSession shared(
      List<ChatMessage> messages, {
      String id = 'shared',
      int messageOffset = 0,
      Map<String, AgentChatContext> contexts = const {},
    }) => _session(
      id,
      participantAgentIds: [_agent, _otherAgent],
      agentContexts: contexts,
      messages: messages,
      messageOffset: messageOffset,
    );

    test(
      'identical text from another agent never merges into this one',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          shared([
            _message(
              'm0',
              role: MessageRole.user,
              content: 'hi',
              agentId: null,
            ),
            _message(
              'm1',
              content: 'shared answer',
              remoteMessageId: 'r-codex-1',
            ),
            _message(
              'm2',
              content: 'agy',
              agentId: _otherAgent,
              remoteMessageId: 'r-agy-1',
            ),
          ]),
        );
        final before = _rows('shared');

        await expectLater(
          repository.mergeReplayBatch(
            shared([
              _message(
                'incoming-0',
                content: 'shared answer',
                agentId: _otherAgent,
              ),
            ], messageOffset: 2),
            _otherAgent,
          ),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', _ambiguous),
          ),
        );

        expect(_rows('shared'), before);
        final stored = await _stored(repository, 'shared');
        expect(stored.messages.map((m) => m.content), [
          'hi',
          'shared answer',
          'agy',
        ]);
      },
    );

    test(
      "a remote id owned by another agent never rewrites that agent's row",
      () async {
        final repository = await _repository();
        await repository.saveSession(
          shared([
            _message(
              'm0',
              role: MessageRole.user,
              content: 'hi',
              agentId: null,
            ),
            _message(
              'm1',
              content: 'codex answer',
              remoteMessageId: 'r-codex-1',
            ),
          ]),
        );
        final before = _rows('shared');

        await expectLater(
          repository.mergeReplayBatch(
            shared([
              _message(
                'incoming-0',
                content: 'hijacked',
                agentId: _otherAgent,
                remoteMessageId: 'r-codex-1',
              ),
            ], messageOffset: 1),
            _otherAgent,
          ),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', _ambiguous),
          ),
        );

        expect(_rows('shared'), before);
        expect(
          (await _stored(repository, 'shared')).messages.last.content,
          'codex answer',
        );
      },
    );

    test(
      'a shared session refuses a batch carrying another agent message',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          shared([
            _message(
              'm0',
              role: MessageRole.user,
              content: 'hi',
              agentId: null,
            ),
            _message(
              'm1',
              content: 'codex answer',
              remoteMessageId: 'r-codex-1',
            ),
            _message(
              'm2',
              content: 'agy',
              agentId: _otherAgent,
              remoteMessageId: 'r-agy-1',
            ),
          ]),
        );
        final before = _rows('shared');

        // Merging for agy, but the batch carries codex's own remote id.
        await expectLater(
          repository.mergeReplayBatch(
            shared([
              _message(
                'incoming-0',
                content: 'cross merged',
                remoteMessageId: 'r-codex-1',
              ),
            ], messageOffset: 2),
            _otherAgent,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              _identityMismatch,
            ),
          ),
        );

        expect(_rows('shared'), before);
        final stored = await _stored(repository, 'shared');
        expect(
          stored.messages.map((m) => m.content),
          ['hi', 'codex answer', 'agy'],
          reason: 'neither agent may write into the other agent history',
        );
      },
    );

    test(
      'a shared session still merges each agent into its own message',
      () async {
        final repository = await _repository();
        await repository.saveSession(
          shared(
            [
              _message(
                'm0',
                role: MessageRole.user,
                content: 'hi',
                agentId: null,
              ),
              _message(
                'm1',
                content: 'codex answer',
                remoteMessageId: 'r-codex-1',
              ),
              _message(
                'm2',
                content: 'agy',
                agentId: _otherAgent,
                remoteMessageId: 'r-agy-1',
              ),
            ],
            contexts: const {
              _otherAgent: AgentChatContext(remoteSessionId: 'remote-agy'),
            },
          ),
        );

        await repository.mergeReplayBatch(
          shared([
            _message(
              'incoming-1',
              content: 'agy answer extended',
              agentId: _otherAgent,
              remoteMessageId: 'r-agy-1',
            ),
          ], messageOffset: 2),
          _otherAgent,
        );
        await repository.mergeReplayBatch(
          shared([
            _message(
              'incoming-0',
              content: 'codex answer extended',
              remoteMessageId: 'r-codex-1',
            ),
          ], messageOffset: 1),
          _agent,
        );

        final stored = await _stored(repository, 'shared');
        expect(
          _count('shared'),
          3,
          reason: 'a shared session must not grow rows',
        );
        expect(stored.messages.map((m) => m.id), ['m0', 'm1', 'm2']);
        expect(
          stored.messages.map((m) => m.content),
          ['hi', 'codex answer extended', 'agy answer extended'],
          reason: 'each agent updates only its own message',
        );
      },
    );
  });
}
