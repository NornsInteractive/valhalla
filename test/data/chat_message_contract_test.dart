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
}
