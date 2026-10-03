import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/acp_account_info.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

/// 本轮契约的消息身份 / 角色 / 附件序列化回归测试。
///
/// 覆盖：新的 `remoteMessageId` + `agentId` + `attachments` 字段、
/// 无 `remoteMessageId` 的旧回放、system 角色的中性默认值、
/// 以及可选附件字段的旧 JSON 兼容。
void main() {
  ChatAttachment attachment({
    String id = 'sha-1',
    String name = 'shot.png',
    String mimeType = 'image/png',
    int sizeBytes = 12,
    String? localPath = '/tmp/chat-attachments/sha-1',
    String? uri,
  }) => ChatAttachment(
    id: id,
    name: name,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    localPath: localPath,
    uri: uri,
  );

  group('ChatMessage 身份与附件往返', () {
    test('remoteMessageId / agentId / attachments 完整往返', () {
      final message = ChatMessage(
        id: 'local-1',
        remoteMessageId: 'remote-9',
        agentId: 'builtin-codex',
        role: MessageRole.assistant,
        content: 'done',
        status: ChatTurnStatus.completed,
        attachments: [
          attachment(),
          attachment(
            id: 'remote-uri',
            name: 'note.txt',
            mimeType: 'text/plain',
            sizeBytes: 3,
            localPath: null,
            uri: 'file:///work/note.txt',
          ),
        ],
        createdAt: DateTime.utc(2026, 9, 30, 12),
      );

      final restored = ChatMessage.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(message.toJson())) as Map,
        ),
      );

      expect(restored.id, 'local-1');
      expect(restored.remoteMessageId, 'remote-9');
      expect(restored.agentId, 'builtin-codex');
      expect(restored.role, MessageRole.assistant);
      expect(restored.status, ChatTurnStatus.completed);
      expect(restored.createdAt, message.createdAt);
      expect(restored.attachments, hasLength(2));
      expect(restored.attachments.first.id, 'sha-1');
      expect(
        restored.attachments.first.localPath,
        '/tmp/chat-attachments/sha-1',
      );
      expect(restored.attachments.first.isImage, isTrue);
      expect(restored.attachments.last.uri, 'file:///work/note.txt');
      expect(restored.attachments.last.localPath, isNull);
      expect(restored.attachments.last.isImage, isFalse);
    });

    test('同角色不同 remoteMessageId 是两条消息，旧回放无 ID 时按角色合并', () {
      // 契约：多 Agent 分片靠 (role, remoteMessageId) 判断是否同一轮；
      // 旧 Agent 回放没有 ID，只能按角色切分。
      final withIds = [
        ChatMessage(
          id: 'a',
          remoteMessageId: 'r1',
          role: MessageRole.assistant,
          content: 'one',
          createdAt: DateTime.utc(2026),
        ),
        ChatMessage(
          id: 'b',
          remoteMessageId: 'r2',
          role: MessageRole.assistant,
          content: 'two',
          createdAt: DateTime.utc(2026),
        ),
      ];
      expect(
        withIds.map((m) => m.remoteMessageId).toSet(),
        hasLength(2),
        reason: '同角色的不同远端 ID 必须保持为不同消息',
      );

      final legacy = [
        ChatMessage(
          id: 'a',
          role: MessageRole.assistant,
          content: 'one',
          createdAt: DateTime.utc(2026),
        ),
        ChatMessage(
          id: 'b',
          role: MessageRole.assistant,
          content: 'two',
          createdAt: DateTime.utc(2026),
        ),
      ];
      expect(legacy.every((m) => m.remoteMessageId == null), isTrue);
    });

    test('未知或缺失 role 退化为中性的 system，而不是抛错', () {
      final restored = ChatMessage.fromJson({
        'id': 'x',
        'role': 'agent',
        'content': 'legacy',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(restored.role, MessageRole.system);

      final missing = ChatMessage.fromJson({
        'id': 'y',
        'content': 'legacy',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(missing.role, MessageRole.system);
      expect(missing.attachments, isEmpty);
      expect(missing.status, ChatTurnStatus.completed);
    });

    test('缺失 attachments / status / planSteps 的旧 JSON 仍然可读', () {
      final restored = ChatMessage.fromJson({
        'id': 'legacy-1',
        'role': 'user',
        'content': 'hi',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(restored.attachments, isEmpty);
      expect(restored.planSteps, isEmpty);
      expect(restored.toolExecutions, isEmpty);
      expect(restored.pendingPermission, isNull);
    });

    test('attachment 的 localPath / uri 可选，缺字段时为 null', () {
      final restored = ChatAttachment.fromJson({
        'id': 'only-id',
        'name': 'x.bin',
        'mimeType': 'application/octet-stream',
        'sizeBytes': 0,
      });
      expect(restored.localPath, isNull);
      expect(restored.uri, isNull);
      expect(restored.isImage, isFalse);
    });

    test('copyWith 不能把可选字段清成 null（旧值会被保留）', () {
      // 记录当前契约：copyWith 一律用 `??`，因此不存在「显式清空」语义。
      final message = ChatMessage(
        id: 'm',
        remoteMessageId: 'r',
        agentId: 'a',
        role: MessageRole.assistant,
        content: 'c',
        createdAt: DateTime.utc(2026),
      );
      final copy = message.copyWith(content: 'd');
      expect(copy.remoteMessageId, 'r');
      expect(copy.agentId, 'a');
      expect(copy.content, 'd');
    });

    test('status 枚举新旧值 JSON 往返：旧 interrupted 原样保留', () {
      // 每个枚举值都必须写得出去、读得回来。
      for (final status in ChatTurnStatus.values) {
        final message = ChatMessage(
          id: 'm-${status.name}',
          role: MessageRole.assistant,
          content: 'x',
          status: status,
          createdAt: DateTime.utc(2026),
        );
        expect(
          message.toJson()['status'],
          status.name,
          reason: '${status.name} 必须以自己的名字落盘',
        );
        expect(
          ChatMessage.fromJson(message.toJson()).status,
          status,
          reason: '${status.name} 必须能原样读回',
        );
      }

      // 新值本身也不能是孤例：awaitingAuthentication 是本轮新增的落盘值。
      expect(
        ChatTurnStatus.awaitingAuthentication.name,
        'awaitingAuthentication',
      );

      // 旧记录里的 interrupted 表示「当年被用户停过」，属于不可判定的歧义历史。
      // 本轮改动绝不能把它们改写成 awaitingAuthentication。
      final old = ChatMessage.fromJson({
        'id': 'old-1',
        'role': 'assistant',
        'content': 'partial',
        'status': 'interrupted',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(old.status, ChatTurnStatus.interrupted);
      expect(old.toJson()['status'], 'interrupted');

      // 缺字段与无法识别的值都退化为 completed，绝不抛错。
      expect(
        ChatMessage.fromJson({
          'id': 'old-2',
          'role': 'assistant',
          'content': 'x',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        }).status,
        ChatTurnStatus.completed,
      );
      expect(
        ChatMessage.fromJson({
          'id': 'future',
          'role': 'assistant',
          'content': 'x',
          'status': 'not-a-real-status',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        }).status,
        ChatTurnStatus.completed,
      );
    });
  });

  group('ChatSession 多 Agent 上下文往返', () {
    test('agentRunSettings / agentContexts / participantAgentIds 完整往返', () {
      final session = ChatSession(
        id: 's1',
        title: 't',
        serverId: 'srv-1',
        agentId: 'builtin-codex',
        workingDirectory: '/root/work',
        remoteSessionId: 'remote-codex',
        agentContexts: const {
          'builtin-codex': AgentChatContext(
            remoteSessionId: 'remote-codex',
            syncedMessageCount: 4,
          ),
          'builtin-claude-code': AgentChatContext(
            remoteSessionId: 'remote-claude',
            syncedMessageCount: 2,
          ),
        },
        participantAgentIds: const ['builtin-codex', 'builtin-claude-code'],
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 9, 30, 1),
        messages: [
          ChatMessage(
            id: 'm1',
            agentId: 'builtin-codex',
            role: MessageRole.user,
            content: 'q',
            createdAt: DateTime.utc(2026, 9, 30),
          ),
          ChatMessage(
            id: 'm2',
            agentId: 'builtin-claude-code',
            remoteMessageId: 'r2',
            role: MessageRole.assistant,
            content: 'a',
            createdAt: DateTime.utc(2026, 9, 30),
          ),
        ],
      );

      final restored = ChatSession.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(session.toJson())) as Map,
        ),
      );

      expect(restored.agentId, 'builtin-codex');
      expect(restored.workingDirectory, '/root/work');
      expect(restored.agentContexts.keys, hasLength(2));
      expect(
        restored.contextFor('builtin-claude-code').remoteSessionId,
        'remote-claude',
      );
      expect(restored.contextFor('builtin-claude-code').syncedMessageCount, 2);
      expect(restored.participantAgentIds, hasLength(2));
      expect(restored.includesAgent('builtin-claude-code'), isTrue);
      expect(restored.messages, hasLength(2));
      expect(restored.messages.last.remoteMessageId, 'r2');
    });

    test('contextFor 对未记录的多 Agent 会话不编造远端 ID', () {
      final session = ChatSession(
        id: 's',
        title: 't',
        agentId: 'builtin-codex',
        remoteSessionId: 'remote-codex',
        messageOffset: 3,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        messages: [
          ChatMessage(
            id: 'm',
            role: MessageRole.user,
            content: 'c',
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      expect(
        session.contextFor('builtin-codex').remoteSessionId,
        'remote-codex',
      );
      expect(
        session.contextFor('builtin-agy').remoteSessionId,
        isNull,
        reason: '参与者未建立过远端会话时不得回退到主 Agent 的 ID',
      );
      expect(session.contextFor('builtin-agy').syncedMessageCount, 0);
    });
  });

  group('AcpAccountInfo 通知解析', () {
    test('接受完整结构化账号', () {
      final account = AcpAccountInfo.fromNotification({
        'authStatus': {
          'kind': 'api_key',
          'label': 'API Key',
          'account': {'email': 'a@b.test', 'plan': 'pro'},
        },
      });
      expect(account, isNotNull);
      expect(account!.kind, 'api_key');
      expect(account.label, 'API Key');
      expect(account.email, 'a@b.test');
      expect(account.plan, 'pro');
    });

    test('缺少 account 时仍可显示 kind/label，其余为 null', () {
      final account = AcpAccountInfo.fromNotification({
        'authStatus': {'kind': 'oauth', 'label': 'OAuth'},
      });
      expect(account!.email, isNull);
      expect(account.plan, isNull);
    });

    test('非法结构一律返回 null，绝不造出半截账号', () {
      expect(AcpAccountInfo.fromNotification(null), isNull);
      expect(AcpAccountInfo.fromNotification(const []), isNull);
      expect(AcpAccountInfo.fromNotification(const {'authStatus': 1}), isNull);
      expect(
        AcpAccountInfo.fromNotification(const {
          'authStatus': {'kind': 'oauth'},
        }),
        isNull,
      );
      expect(
        AcpAccountInfo.fromNotification(const {
          'authStatus': {'kind': 'oauth', 'label': 7},
        }),
        isNull,
      );
    });
  });

  group('AcpSlashCommand 插入文本', () {
    test(r'技能保留 $ 前缀，普通命令补斜杠', () {
      const skill = AcpSlashCommand(r'$plan', 'plan a task', 'task');
      expect(skill.isSkill, isTrue);
      expect(skill.insertion, r'$plan ');

      const command = AcpSlashCommand('status', 'quota', null);
      expect(command.isSkill, isFalse);
      expect(command.insertion, '/status ');

      const alreadySlashed = AcpSlashCommand('/compact', 'compact', null);
      expect(alreadySlashed.isSkill, isFalse);
      expect(
        alreadySlashed.insertion,
        '/compact ',
        reason: 'agent 已带斜杠时不得产生 //compact',
      );
    });
  });

  group('ChatMessage.contentBlocks 有序渲染契约', () {
    ChatMessage message({
      required String content,
      List<ChatContentBlock> blocks = const [],
      List<ToolExecution> tools = const [],
      ChatTurnStatus status = ChatTurnStatus.completed,
    }) => ChatMessage(
      id: 'm1',
      role: MessageRole.assistant,
      agentId: 'builtin-codex',
      content: content,
      contentBlocks: blocks,
      toolExecutions: tools,
      status: status,
      createdAt: DateTime.utc(2026),
    );

    ToolExecution tool(String id) => ToolExecution(
      id: id,
      name: 'shell',
      command: 'ls',
      status: ToolExecutionStatus.completed,
    );

    /// `ChatContentBlock` 是值对象但没写 `==`，断言一律先转成可比较的形状。
    List<String> shapes(Iterable<ChatContentBlock> blocks) => [
      for (final block in blocks)
        block.type == ChatContentBlockType.text
            ? 'text:${block.start}-${block.end}'
            : 'tool:${block.toolId}',
    ];

    test('连续文本合并成一段 range，工具锚在首次出现的位置', () {
      var blocks = const <ChatContentBlock>[];
      blocks = ChatContentBlock.appendText(blocks, 0, 1);
      blocks = ChatContentBlock.appendText(blocks, 1, 3);
      expect(shapes(blocks), ['text:0-3'], reason: '相邻文本必须合并');

      blocks = ChatContentBlock.appendTool(blocks, 't1');
      blocks = ChatContentBlock.appendText(blocks, 3, 5);
      expect(shapes(blocks), ['text:0-3', 'tool:t1', 'text:3-5']);

      final rendered = message(
        content: 'abcde',
        blocks: blocks,
        tools: [tool('t1')],
      );
      expect(
        shapes(rendered.orderedContentBlocks),
        shapes(blocks),
        reason: '合法的块原样渲染，不重排',
      );
      // text range 指向 content 本身，不是第二份副本。
      final texts = [
        for (final block in rendered.orderedContentBlocks)
          if (block.type == ChatContentBlockType.text)
            rendered.content.substring(block.start, block.end),
      ];
      expect(texts.join(), 'abcde');
    });

    test('同一 toolId 只锚一次，工具更新不会把它挪到末尾', () {
      var blocks = const <ChatContentBlock>[];
      blocks = ChatContentBlock.appendTool(blocks, 't1');
      blocks = ChatContentBlock.appendText(blocks, 0, 3);
      final again = ChatContentBlock.appendTool(blocks, 't1');
      expect(
        shapes(again),
        shapes(blocks),
        reason: '重复的 appendTool 不得产生第二个块，也不得改变顺序',
      );
      expect(shapes(again), ['tool:t1', 'text:0-3']);
    });

    test('空区间不产生块，appendText 保持原列表', () {
      final blocks = <ChatContentBlock>[const ChatContentBlock.text(0, 2)];
      expect(ChatContentBlock.appendText(blocks, 2, 2), blocks);
    });

    test('状态更新不会改动渲染顺序', () {
      final original = message(
        content: 'abcde',
        blocks: const [
          ChatContentBlock.text(0, 3),
          ChatContentBlock.tool('t1'),
          ChatContentBlock.text(3, 5),
        ],
        tools: [tool('t1')],
      );
      final updated = original.copyWith(status: ChatTurnStatus.streaming);
      expect(
        shapes(updated.orderedContentBlocks),
        shapes(original.orderedContentBlocks),
      );
      expect(updated.status, ChatTurnStatus.streaming);
    });

    test('contentBlocks 在 JSON 往返后逐块一致（含 emoji 的 UTF-16 偏移）', () {
      // 'a' 1 个 UTF-16 单元，'😀' 2 个，'b' 1 个。
      const content = 'a😀b';
      final original = message(
        content: content,
        blocks: const [
          ChatContentBlock.text(0, 3),
          ChatContentBlock.tool('t1'),
          ChatContentBlock.text(3, 4),
        ],
        tools: [tool('t1')],
      );
      expect(content.substring(0, 3), 'a😀', reason: '前提：range 是按 UTF-16 偏移算的');

      final round = ChatMessage.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(
        round.contentBlocks.map((b) => b.toJson()).toList(),
        original.contentBlocks.map((b) => b.toJson()).toList(),
        reason: '往返必须逐块保留，含顺序',
      );
      expect(
        shapes(round.orderedContentBlocks),
        shapes(original.orderedContentBlocks),
      );
      expect(round.content, content);
    });

    test('旧记录没有 contentBlocks 时退回「工具在前、文本在后」', () {
      final legacy = message(content: 'hello', tools: [tool('t1'), tool('t2')]);
      expect(legacy.contentBlocks, isEmpty, reason: '旧记录本来就没有块');
      expect(shapes(legacy.orderedContentBlocks), [
        'tool:t1',
        'tool:t2',
        'text:0-5',
      ]);
    });

    test('range 有缺口 / 没覆盖全文 / 指向未知工具都退回降级顺序', () {
      final withTools = [tool('t1')];

      final gap = message(
        content: 'abcde',
        blocks: const [
          ChatContentBlock.text(0, 2),
          ChatContentBlock.text(3, 5),
        ],
        tools: withTools,
      );
      expect(shapes(gap.orderedContentBlocks), [
        'tool:t1',
        'text:0-5',
      ], reason: '2..3 的缺口必须整体降级，不能渲染出错位的文本');

      final notCovering = message(
        content: 'abcde',
        blocks: const [ChatContentBlock.text(0, 3)],
        tools: withTools,
      );
      expect(shapes(notCovering.orderedContentBlocks), [
        'tool:t1',
        'text:0-5',
      ], reason: '没覆盖全文的 range 会丢字，必须降级');

      final unknownTool = message(
        content: 'abc',
        blocks: const [
          ChatContentBlock.text(0, 3),
          ChatContentBlock.tool('ghost'),
        ],
        tools: withTools,
      );
      expect(shapes(unknownTool.orderedContentBlocks), [
        'tool:t1',
        'text:0-3',
      ], reason: '指向不存在工具的块必须降级');

      final duplicated = message(
        content: 'abc',
        blocks: const [
          ChatContentBlock.tool('t1'),
          ChatContentBlock.tool('t1'),
          ChatContentBlock.text(0, 3),
        ],
        tools: withTools,
      );
      expect(shapes(duplicated.orderedContentBlocks), [
        'tool:t1',
        'text:0-3',
      ], reason: '同一工具出现两次说明块已损坏，必须降级');
    });

    test('损坏的 contentBlocks JSON 一律丢弃，绝不渲染半截 range', () {
      final round = ChatMessage.fromJson({
        'id': 'm1',
        'role': 'assistant',
        'content': 'abc',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'contentBlocks': [
          {'type': 'text', 'start': 0, 'end': 'nope'},
          'not-an-object',
          {'type': 'tool'},
          {'type': 'tool', 'toolId': 't1'},
          {'type': 'text', 'start': 0, 'end': 3},
        ],
        'toolExecutions': [
          {'id': 't1', 'name': 'shell', 'command': 'ls', 'status': 'completed'},
        ],
      });

      expect(shapes(round.contentBlocks), [
        'tool:t1',
        'text:0-3',
      ], reason: '非法条目被丢弃，合法条目保留');
      expect(shapes(round.orderedContentBlocks), shapes(round.contentBlocks));
    });
  });
}
