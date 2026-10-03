import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// AgY explicit sign-in contract: picking a method authenticates immediately,
/// method discovery never opens a chat session, and an unknown method never
/// reaches the agent.
AgentProfile _agy() => AgentProfile(
  id: 'builtin-agy',
  serverId: 'srv-1',
  name: 'Antigravity AGY',
  description: 'desc',
  cliCommand: 'agy',
  acpCommand: 'agy_acp_server.par',
  loginCommand: 'agy',
  loginCheckCommand: 'probe',
);

class _AllReadyRegistry extends AgentRegistryNotifier {
  _AllReadyRegistry(this.profile);

  final AgentProfile profile;

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
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

class _StaticConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAcpPair pair;
  void Function(FakeAcpPair)? configurePair;

  const methods = [
    {'id': 'oauth', 'name': 'OAuth'},
  ];

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    return ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(() => _AllReadyRegistry(_agy())),
        serverConnectionProvider.overrideWith(() => _StaticConnection()),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        acpTransportFactoryProvider.overrideWithValue((_, _) async {
          pair = FakeAcpPair();
          configurePair?.call(pair);
          return pair.client;
        }),
      ],
    );
  }

  Future<AiChatNotifier> ready(ProviderContainer c) async {
    final notifier = c.read(aiChatProvider.notifier);
    c.read(aiChatProvider);
    await pumpEventQueue();
    expect(c.read(aiChatProvider).activeAgentProfile?.id, 'builtin-agy');
    // `sendMessage` returns silently while history is still loading, so wait
    // for the real disk load instead of assuming a fixed number of microtasks.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (c.read(aiChatProvider).isLoadingSessions ||
        c.read(aiChatProvider).isLoadingMessages) {
      if (DateTime.now().isAfter(deadline)) {
        fail('history loading never settled');
      }
      await pumpEventQueue();
    }
    return notifier;
  }

  tearDown(() {
    configurePair = null;
  });

  test('method discovery never opens a chat session', () async {
    configurePair = (p) => p.authMethods = methods;
    final c = await container();
    addTearDown(c.dispose);
    final notifier = await ready(c);

    await notifier.requestAuthentication();
    await pumpEventQueue();

    final state = c.read(aiChatProvider);
    expect(state.authChallenge?.methods.single.id, 'oauth');
    expect(state.authRequest, isNull);
    expect(state.isAuthenticating, isFalse);
    expect(state.isGenerating, isFalse);
    expect(pair.newSessionCount, 0);
    expect(pair.loadRequests, isEmpty);
    expect(pair.authenticateCallCount, 0);
    expect(pair.sentToAgent.join(), isNot(contains('session/prompt')));
  });

  test(
    'picking a method authenticates immediately without re-prompting',
    () async {
      configurePair = (p) {
        p.authMethods = methods;
        p.failPrompt = true;
      };
      final c = await container();
      addTearDown(c.dispose);
      final notifier = await ready(c);

      await notifier.sendMessage('hi');
      await pumpEventQueue();
      final after = c.read(aiChatProvider);
      expect(
        after.authChallenge,
        isNotNull,
        reason:
            'lastErrorCode=${after.lastErrorCode} '
            'authError=${after.authError} generating=${after.isGenerating} '
            'loading=${after.isLoadingSettings} applying=${after.isApplyingSettings}',
      );
      final promptsBefore = pair.sentToAgent
          .where((l) => l.contains('session/prompt'))
          .length;

      await notifier.respondAuth('oauth');
      await pumpEventQueue();

      final state = c.read(aiChatProvider);
      expect(pair.authenticateCallCount, 1);
      expect(pair.lastAuthenticateMethodId, 'oauth');
      expect(state.authChallenge, isNull);
      expect(state.authError, isNull);
      expect(state.isAuthenticating, isFalse);
      expect(
        pair.sentToAgent.where((l) => l.contains('session/prompt')).length,
        promptsBefore,
        reason: 'sign-in must not replay the prompt',
      );
      expect(state.selectedAuthMethods['srv-1::builtin-agy'], 'oauth');
    },
  );

  test('an unknown method never reaches the agent', () async {
    configurePair = (p) {
      p.authMethods = methods;
      p.failPrompt = true;
    };
    final c = await container();
    addTearDown(c.dispose);
    final notifier = await ready(c);

    await notifier.sendMessage('hi');
    await pumpEventQueue();
    expect(c.read(aiChatProvider).authChallenge, isNotNull);

    await notifier.respondAuth('not-advertised');
    await pumpEventQueue();

    final state = c.read(aiChatProvider);
    expect(state.authError, 'ACP_AUTH_METHOD_UNAVAILABLE');
    expect(pair.authenticateCallCount, 0);
    expect(state.authChallenge, isNotNull);
  });
}
