import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/models/chat_workspace.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';

const _server = ServerProfile(
  id: 'srv-1',
  name: 'test server',
  host: 'example.test',
  username: 'root',
);

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

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
}

class _StaticConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _AllReadyRegistry extends AgentRegistryNotifier {
  _AllReadyRegistry(this._profiles);
  final List<AgentProfile> _profiles;

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      for (final profile in _profiles)
        AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: AgentEnvironmentStatusKind.ready,
            checkedAt: DateTime.utc(2026),
          ),
        ),
    ],
  );
}

Future<ChatRepository> _seededRepository(
  LocalStorageService storage,
  ChatSession session,
) async {
  final directory = Directory.systemTemp.createTempSync(
    'valhalla_execution_key_',
  );
  addTearDown(() async {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  final path = '${directory.path}/chat.sqlite3';
  final seeder = ChatRepository(storage, databasePath: path);
  await seeder.saveSession(session);
  return ChatRepository(storage, databasePath: path);
}

Future<void> _settle(ProviderContainer container) async {
  container.read(aiChatProvider);
  await pumpEventQueue();
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (container.read(aiChatProvider).isLoadingSessions ||
      container.read(aiChatProvider).isLoadingMessages) {
    if (DateTime.now().isAfter(deadline)) {
      fail('history loading never settled');
    }
    await pumpEventQueue();
  }
}

void main() {
  test('sendMessage rejects execution mismatch before transport', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final profileA = _profile('builtin-codex', 'dockerA');
    final profileB = _profile('builtin-claude-code', 'dockerB');
    final sharedKey = chatExecutionKey(profileA);
    final session = ChatSession(
      id: 'shared-session',
      title: 'shared',
      serverId: 'srv-1',
      agentId: 'builtin-codex',
      participantAgentIds: const ['builtin-codex', 'builtin-claude-code'],
      agentContexts: {
        'builtin-codex': AgentChatContext(
          executionKey: sharedKey,
          remoteSessionId: 'remote-a',
        ),
        'builtin-claude-code': AgentChatContext(
          executionKey: sharedKey,
          remoteSessionId: 'remote-b',
        ),
      },
      messages: [
        ChatMessage(
          id: 'm1',
          agentId: 'builtin-codex',
          role: MessageRole.user,
          content: 'hello',
          createdAt: DateTime.utc(2026),
        ),
      ],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final repository = await _seededRepository(storage, session);

    var transportCalled = false;
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        chatRepositoryProvider.overrideWithValue(repository),
        activeServerProvider.overrideWith(() => _StubActiveServer()),
        agentRegistryProvider.overrideWith(
          () => _AllReadyRegistry([profileA, profileB]),
        ),
        serverConnectionProvider.overrideWith(() => _StaticConnection()),
        acpTransportFactoryProvider.overrideWithValue((
          _,
          _, {
          String? initialModelId,
        }) async {
          transportCalled = true;
          throw StateError('transport must not be created');
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await _settle(container);
    await notifier.switchAgent('builtin-claude-code');
    await _settle(container);

    final beforeSessionId = container.read(aiChatProvider).activeSessionId;
    final beforeMessages = container
        .read(aiChatProvider)
        .activeSession!
        .messages
        .map((m) => m.content)
        .toList();
    notifier.updateDraftText('kept draft');

    await notifier.sendMessage('should be rejected');

    final after = container.read(aiChatProvider);
    expect(after.lastErrorCode, 'CHAT_SESSION_EXECUTION_CHANGED');
    expect(after.isGenerating, isFalse);
    expect(transportCalled, isFalse);
    expect(after.activeSessionId, beforeSessionId);
    expect(
      after.activeSession!.messages.map((m) => m.content).toList(),
      beforeMessages,
    );
    expect(after.draftText, 'kept draft');

    final stored = await repository.loadSession(beforeSessionId!);
    expect(stored!.messages.map((m) => m.content).toList(), ['hello']);
  });
}
