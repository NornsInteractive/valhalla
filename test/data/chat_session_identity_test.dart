import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/chat_session.dart';

void main() {
  test('session identity survives JSON and message updates', () {
    final session = ChatSession(
      id: 'local',
      title: 'chat',
      agentId: 'agent',
      serverId: 'server',
      workingDirectory: '/srv/project',
      remoteSessionId: 'remote',
      participantAgentIds: const ['agent', 'second'],
      agentContexts: const {
        'agent': AgentChatContext(
          remoteSessionId: 'remote',
          syncedMessageCount: 2,
        ),
        'second': AgentChatContext(
          remoteSessionId: 'other',
          syncedMessageCount: 4,
        ),
      },
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final restored = ChatSession.fromJson(
      session.copyWith(title: 'updated').toJson(),
    );
    expect(restored.serverId, 'server');
    expect(restored.workingDirectory, '/srv/project');
    expect(restored.remoteSessionId, 'remote');
    expect(restored.includesAgent('second'), isTrue);
    expect(restored.contextFor('agent').remoteSessionId, 'remote');
    expect(restored.contextFor('second').remoteSessionId, 'other');
    expect(restored.contextFor('second').syncedMessageCount, 4);
    expect(restored.contextFor('unrelated').remoteSessionId, isNull);
  });
}
