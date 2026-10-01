import 'dart:convert';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/acp_account_info.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// adapter 层本轮契约：initializeOnly 不建会话、账号推送 gating、
/// session/load 回放按 (role, messageId) 分片、命令/技能前缀。
void main() {
  late List<FakeAcpPair> pairs;
  late FakeAcpPair pair;

  ACPClientAdapter buildAdapter({
    String? resumeSessionId,
    bool captureReplay = false,
    String cwd = '/root/work',
  }) => ACPClientAdapter(
    profile: testAgentProfile(),
    transport: pair.client,
    workingDirectory: cwd,
    resumeSessionId: resumeSessionId,
    captureReplay: captureReplay,
  );

  setUp(() {
    pairs = [];
    pair = FakeAcpPair(sessionId: 'remote-1');
    pairs.add(pair);
  });

  tearDown(() {
    for (final created in pairs) {
      created.close();
    }
  });

  FakeAcpPair newPair({
    String sessionId = 'remote-1',
    Map<String, Object?> capabilities = const {},
  }) {
    final created = FakeAcpPair(sessionId: sessionId)
      ..agentCapabilities = capabilities;
    pairs.add(created);
    return created;
  }

  group('initializeOnly', () {
    test('只发 initialize，不发 session/new、session/load、session/prompt', () async {
      final target = newPair();
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await pumpEventQueue();

      expect(target.sentToAgent, hasLength(1));
      expect(target.sentToAgent.single, contains('"initialize"'));
      expect(target.newSessionCount, 0);
      expect(target.loadRequests, isEmpty);
      expect(target.resumeRequests, isEmpty);
      expect(adapter.sessionId, isNull, reason: '草稿不得建立远端会话');
      expect(target.sentToAgent.join(), isNot(contains('session/prompt')));
    });

    test('并发调用共享同一次 initialize', () async {
      final target = newPair();
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await Future.wait([adapter.initializeOnly(), adapter.initializeOnly()]);
      await pumpEventQueue();

      expect(
        target.sentToAgent.where((line) => line.contains('"initialize"')),
        hasLength(1),
      );
    });

    test('能力与版本被解析，供草稿设置面板使用', () async {
      final target = newPair(
        capabilities: const {
          'promptCapabilities': {'image': true, 'embeddedContext': true},
          'loadSession': true,
        },
      );
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await pumpEventQueue();

      expect(adapter.agentCapabilities.promptCapabilities?.image, isTrue);
      expect(
        adapter.agentCapabilities.promptCapabilities?.embeddedContext,
        isTrue,
      );
      expect(adapter.agentCapabilities.loadSession, isTrue);
      expect(target.newSessionCount, 0);
    });

    test('dispose 之后 initializeOnly 以 ACP_DISCONNECTED 失败', () async {
      final adapter = buildAdapter()..dispose();
      await expectLater(
        adapter.initializeOnly(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_DISCONNECTED',
          ),
        ),
      );
    });
  });

  group('_auth/status_update 推送的 gating', () {
    void deliverStatus(
      FakeAcpPair target, {
      String kind = 'api_key',
      String label = 'API Key',
      Map<String, String>? account,
    }) => target.deliverToClient(
      jsonEncode({
        'jsonrpc': '2.0',
        'method': '_auth/status_update',
        'params': {
          'authStatus': {'kind': kind, 'label': label, 'account': ?account},
        },
      }),
    );

    test('agent 声明 authStatus meta 时推送被采纳', () async {
      final target = newPair(
        capabilities: const {
          '_meta': {
            'authStatus': {'methods': []},
          },
        },
      );
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);
      final accounts = <AcpAccountInfo>[];
      adapter.eventStream.listen((event) {
        if (event is ACPAccountEvent) accounts.add(event.account);
      });

      await adapter.initializeOnly();
      await pumpEventQueue();
      deliverStatus(target, account: {'email': 'a@b.test', 'plan': 'pro'});
      await pumpEventQueue();

      expect(accounts, hasLength(1));
      expect(adapter.account!.kind, 'api_key');
      expect(adapter.account!.email, 'a@b.test');
      expect(adapter.account!.plan, 'pro');
      expect(adapter.account!.label, 'API Key');
    });

    test('未声明 authStatus meta 的 agent 推送被忽略', () async {
      final target = newPair();
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);
      final accounts = <AcpAccountInfo>[];
      adapter.eventStream.listen((event) {
        if (event is ACPAccountEvent) accounts.add(event.account);
      });

      await adapter.initializeOnly();
      await pumpEventQueue();
      deliverStatus(target);
      await pumpEventQueue();

      expect(accounts, isEmpty, reason: '未声明扩展能力时不得展示结构化账号');
      expect(adapter.account, isNull);
    });

    test('结构不合法的推送被丢弃', () async {
      final target = newPair(
        capabilities: const {
          '_meta': {'authStatus': {}},
        },
      );
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await pumpEventQueue();
      for (final params in [
        {
          'authStatus': {'kind': 'only-kind'},
        },
        {
          'authStatus': {'kind': 7, 'label': 'API Key'},
        },
        {'authStatus': 'not-a-map'},
        {'other': 'notification'},
      ]) {
        target.deliverToClient(
          jsonEncode({
            'jsonrpc': '2.0',
            'method': '_auth/status_update',
            'params': params,
          }),
        );
      }
      await pumpEventQueue();

      expect(adapter.account, isNull);
    });

    test('dispose 之后推送不再产生事件', () async {
      final target = newPair(
        capabilities: const {
          '_meta': {'authStatus': {}},
        },
      );
      pair = target;
      final adapter = buildAdapter();
      final accounts = <AcpAccountInfo>[];
      adapter.eventStream.listen((event) {
        if (event is ACPAccountEvent) accounts.add(event.account);
      });
      await adapter.initializeOnly();
      await pumpEventQueue();

      adapter.dispose();
      deliverStatus(target);
      await pumpEventQueue();

      expect(accounts, isEmpty);
    });
  });

  group('session/load 回放', () {
    Map<String, Object?> chunk(
      String kind,
      String text, {
      String? messageId,
      Map<String, Object?>? content,
    }) => {
      'sessionUpdate': kind,
      'messageId': ?messageId,
      'content': content ?? {'type': 'text', 'text': text},
    };

    test('未声明 loadSession 的 agent 直接拒绝回放', () async {
      final target = newPair();
      pair = target;
      final adapter = buildAdapter(
        resumeSessionId: 'remote-1',
        captureReplay: true,
      );
      addTearDown(adapter.dispose);

      await expectLater(
        adapter.prepareSession(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_HISTORY_REPLAY_UNSUPPORTED',
          ),
        ),
      );
    });

    test('同角色不同 messageId 分成两条消息，相同 ID 合并', () async {
      final target = newPair(capabilities: const {'loadSession': true});
      pair = target;
      target.loadReplayUpdates = [
        chunk('user_message_chunk', 'hi', messageId: 'u1'),
        chunk('agent_message_chunk', 'a', messageId: 'a1'),
        chunk('agent_message_chunk', ' b', messageId: 'a1'),
        chunk('agent_message_chunk', 'second', messageId: 'a2'),
        chunk('user_message_chunk', 'again', messageId: 'u2'),
      ];
      final adapter = buildAdapter(
        resumeSessionId: 'remote-1',
        captureReplay: true,
      );
      addTearDown(adapter.dispose);
      final events = <ACPEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.prepareSession();
      await pumpEventQueue();

      final user = events.whereType<ACPUserContentChunkEvent>();
      final agent = events.whereType<ACPContentChunkEvent>();
      expect(user.map((e) => e.messageId).toList(), ['u1', 'u2']);
      expect(user.map((e) => e.chunk).toList(), ['hi', 'again']);
      expect(
        agent.map((e) => (e.messageId, e.chunk)).toList(),
        [('a1', 'a'), ('a1', ' b'), ('a2', 'second')],
        reason: '相同 messageId 的分片属于同一条消息，不同 ID 必须分开',
      );
      expect(target.loadRequests, ['remote-1']);
    });

    test('旧 agent 没有 messageId 时按角色顺序切分', () async {
      final target = newPair(capabilities: const {'loadSession': true});
      pair = target;
      target.loadReplayUpdates = [
        chunk('user_message_chunk', 'q1'),
        chunk('agent_message_chunk', 'a1'),
        chunk('agent_message_chunk', 'a1 more'),
        chunk('user_message_chunk', 'q2'),
        chunk('agent_message_chunk', 'a2'),
      ];
      final adapter = buildAdapter(
        resumeSessionId: 'remote-1',
        captureReplay: true,
      );
      addTearDown(adapter.dispose);
      final events = <ACPEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.prepareSession();
      await pumpEventQueue();

      final sequence = events
          .whereType<ACPContentChunkEvent>()
          .map((e) => e.chunk)
          .toList();
      expect(sequence, ['a1', 'a1 more', 'a2']);
      expect(events.whereType<ACPUserContentChunkEvent>().map((e) => e.chunk), [
        'q1',
        'q2',
      ]);
      expect(
        events.whereType<ACPUserContentChunkEvent>().every(
          (e) => e.messageId == null,
        ),
        isTrue,
      );
    });

    test('非文本块回放为带角色的附件事件', () async {
      final target = newPair(capabilities: const {'loadSession': true});
      pair = target;
      target.loadReplayUpdates = [
        chunk(
          'user_message_chunk',
          '',
          messageId: 'u1',
          content: {'type': 'image', 'data': 'AAAA', 'mimeType': 'image/png'},
        ),
        chunk(
          'agent_message_chunk',
          '',
          messageId: 'a1',
          content: {'type': 'image', 'data': 'BBBB', 'mimeType': 'image/png'},
        ),
      ];
      final adapter = buildAdapter(
        resumeSessionId: 'remote-1',
        captureReplay: true,
      );
      addTearDown(adapter.dispose);
      final attachments = <ACPAttachmentEvent>[];
      adapter.eventStream.listen((event) {
        if (event is ACPAttachmentEvent) attachments.add(event);
      });

      await adapter.prepareSession();
      await pumpEventQueue();

      expect(attachments, hasLength(2));
      expect(attachments.first.role, MessageRole.user);
      expect(attachments.last.role, MessageRole.assistant);
      expect(attachments.first.messageId, 'u1');
      expect(attachments.last.messageId, 'a1');
      expect((attachments.first.content as ImageContent).mimeType, 'image/png');
    });

    test('非回放模式忽略 load 出来的正文，避免污染本地历史', () async {
      final target = newPair(capabilities: const {'loadSession': true});
      pair = target;
      target.loadReplayUpdates = [
        chunk('user_message_chunk', 'old-q', messageId: 'u1'),
        chunk('agent_message_chunk', 'old-a', messageId: 'a1'),
      ];
      final adapter = buildAdapter(resumeSessionId: 'remote-1');
      addTearDown(adapter.dispose);
      final content = <ACPEvent>[];
      adapter.eventStream.listen(content.add);

      await adapter.prepareSession();
      await pumpEventQueue();

      expect(content.whereType<ACPContentChunkEvent>(), isEmpty);
      expect(content.whereType<ACPUserContentChunkEvent>(), isEmpty);
      expect(adapter.sessionId, 'remote-1');
      expect(adapter.restoredExistingSession, isTrue);
    });
  });

  group('命令与技能更新', () {
    test(r'available_commands_update 保留 $ 前缀并给出插入文本', () async {
      final target = newPair();
      pair = target;
      target.promptUpdates = [
        {
          'sessionUpdate': 'available_commands_update',
          'availableCommands': [
            {
              'name': 'status',
              'description': 'account and quota',
              'input': {'hint': 'optional'},
            },
            {'name': r'$plan', 'description': 'plan a task'},
          ],
        },
      ];
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);
      await adapter.initializeOnly();
      await adapter.prepareSession();
      await adapter.sendPrompt('hello');
      await pumpEventQueue();

      expect(adapter.commands.map((c) => c.name), ['status', r'$plan']);
      expect(adapter.commands.first.hint, 'optional');
      expect(adapter.commands.first.isSkill, isFalse);
      expect(adapter.commands.first.insertion, '/status ');
      expect(adapter.commands.last.isSkill, isTrue);
      expect(adapter.commands.last.insertion, r'$plan ');
    });
  });

  group('版本锁定的草稿命令预览', () {
    const codexAcp200 = <String, Object?>{
      'name': '@agentclientprotocol/codex-acp',
      'version': '2.0.0',
    };
    const previewNames = [
      'plan',
      'mcp',
      'skills',
      'status',
      'review',
      'review-branch',
      'review-commit',
      'compact',
      'goal',
      'rename',
      'logout',
    ];

    test('initialize 后只给 2.0.0 版本锁定的预览，且不建会话', () async {
      final target = newPair()..agentInfo = codexAcp200;
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await pumpEventQueue();

      expect(adapter.composerCommands.map((c) => c.name), previewNames);
      expect(
        adapter.composerCommands.map((c) => c.isDraftPreview),
        everyElement(isTrue),
      );
      expect(adapter.commands, isEmpty, reason: '预览不写进真实命令列表');
      expect(adapter.sessionId, isNull);
      expect(target.newSessionCount, 0);
      expect(target.loadRequests, isEmpty);
      expect(target.resumeRequests, isEmpty);
      expect(target.sentToAgent, hasLength(1));
      expect(target.sentToAgent.single, contains('"initialize"'));
    });

    for (final identity in <String, Map<String, Object?>?>{
      'agent 名称不是 codex-acp': const {
        'name': 'com.example.other-acp',
        'version': '2.0.0',
      },
      '版本不是 2.0.0': const {
        'name': '@agentclientprotocol/codex-acp',
        'version': '2.0.1',
      },
      '缺少 agentInfo': null,
    }.entries) {
      test('${identity.key}时草稿不给任何预览命令', () async {
        final target = newPair()..agentInfo = identity.value;
        pair = target;
        final adapter = buildAdapter();
        addTearDown(adapter.dispose);

        await adapter.initializeOnly();
        await pumpEventQueue();

        expect(adapter.composerCommands, isEmpty);
        expect(target.newSessionCount, 0);
      });
    }

    test('建立会话后预览不再出现，等待真实命令列表', () async {
      final target = newPair()..agentInfo = codexAcp200;
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await adapter.prepareSession();
      await pumpEventQueue();

      expect(target.newSessionCount, 1);
      expect(adapter.composerCommands, isEmpty);
      expect(adapter.commands, isEmpty);
    });

    test('真实的 available_commands_update 空列表覆盖预览', () async {
      final target = newPair()..agentInfo = codexAcp200;
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);

      await adapter.initializeOnly();
      await pumpEventQueue();
      expect(adapter.composerCommands, isNotEmpty);

      target.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': 'remote-1',
            'update': {
              'sessionUpdate': 'available_commands_update',
              'availableCommands': <Object>[],
            },
          },
        }),
      );
      await pumpEventQueue();

      expect(adapter.composerCommands, isEmpty, reason: '空列表同样是权威结果');
      expect(adapter.commands, isEmpty);

      target.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': 'remote-1',
            'update': {
              'sessionUpdate': 'available_commands_update',
              'availableCommands': [
                {'name': 'runtime_cmd', 'description': 'from runtime'},
              ],
            },
          },
        }),
      );
      await pumpEventQueue();

      expect(adapter.composerCommands.map((c) => c.name), ['runtime_cmd']);
      expect(adapter.composerCommands.single.isDraftPreview, isFalse);
    });
  });

  group('附件限额与能力校验', () {
    test('图片能力未声明时拒绝图片附件', () async {
      final target = newPair();
      pair = target;
      final adapter = buildAdapter();
      addTearDown(adapter.dispose);
      final errors = <String>[];
      adapter.eventStream.listen((event) {
        if (event is ACPErrorEvent) errors.add(event.error);
      });

      await adapter.initializeOnly();
      await adapter.sendPrompt(
        'look',
        attachments: [
          AcpPromptAttachment(
            name: 'a.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      await pumpEventQueue();

      expect(errors.join(), contains('ACP_ATTACHMENT_UNSUPPORTED'));
      expect(
        target.newSessionCount,
        1,
        // 已知行为：大小限额已在建会话前校验（见 acp_client_adapter.dart:468-475），
        // 但能力校验仍在 _ensureSession() 之后，见缺陷报告 P3-5。
        reason: '修复 P3-5（能力校验前移）后此处应改为 0',
      );
    });
  });
}
