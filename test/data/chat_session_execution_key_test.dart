import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/chat_workspace.dart';

AgentProfile _profile(String id, String container) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
  executionTarget: 'docker',
  containerBinding: 'name',
  containerReference: container,
  containerUser: 'root',
);

void main() {
  test('AgentChatContext executionKey round-trips and copyWith', () {
    const context = AgentChatContext(
      executionKey: 'docker-key',
      remoteSessionId: 'remote-1',
      syncedMessageCount: 3,
    );
    final restored = AgentChatContext.fromJson(context.toJson());
    expect(restored.executionKey, 'docker-key');
    expect(restored.remoteSessionId, 'remote-1');
    expect(restored.syncedMessageCount, 3);

    final older = AgentChatContext.fromJson(const <String, dynamic>{
      'remoteSessionId': 'remote-2',
      'syncedMessageCount': 1,
    });
    expect(older.executionKey, isNull);

    final copied = older.copyWith(executionKey: 'copied-key');
    expect(copied.executionKey, 'copied-key');
    expect(copied.remoteSessionId, 'remote-2');
  });

  test(
    'ChatSession contextFor falls back to session executionKey for owner',
    () {
      final profile = _profile('agent-a', 'docker-a');
      final session = ChatSession(
        id: 'session-1',
        title: 'shared',
        serverId: 'srv-1',
        agentId: 'agent-a',
        executionKey: chatExecutionKey(profile),
        participantAgentIds: const ['agent-a', 'agent-b'],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(
        session.contextFor('agent-a').executionKey,
        chatExecutionKey(profile),
      );
      expect(session.contextFor('agent-b').executionKey, isNull);
    },
  );

  test('ChatSession executionKey round-trips through JSON', () {
    final profile = _profile('agent-a', 'docker-a');
    final session = ChatSession(
      id: 'session-1',
      title: 'shared',
      serverId: 'srv-1',
      agentId: 'agent-a',
      executionKey: chatExecutionKey(profile),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final restored = ChatSession.fromJson(session.toJson());
    expect(restored.executionKey, chatExecutionKey(profile));
  });
}
