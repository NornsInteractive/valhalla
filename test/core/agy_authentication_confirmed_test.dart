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

/// `authenticationConfirmed` is live runtime evidence only: it is set by a
/// matching ACP authentication success and reset by auth-required, failure and
/// cancellation. It must never read as a persistent login assumption.
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

  /// Raises an auth challenge the same way the product does: a prompt that the
  /// agent rejects with `authRequired`.
  Future<void> raiseChallenge(
    ProviderContainer c,
    AiChatNotifier notifier,
  ) async {
    await notifier.sendMessage('hi');
    await pumpEventQueue();
    expect(
      c.read(aiChatProvider).authChallenge,
      isNotNull,
      reason: 'a challenge must be standing before authentication can confirm',
    );
    expect(c.read(aiChatProvider).authenticationConfirmed, isFalse);
  }

  tearDown(() {
    configurePair = null;
  });

  test(
    'a matching authentication success confirms and clears the card',
    () async {
      configurePair = (p) {
        p.authMethods = methods;
        p.failPrompt = true;
      };
      final c = await container();
      addTearDown(c.dispose);
      final notifier = await ready(c);
      await raiseChallenge(c, notifier);

      await notifier.respondAuth('oauth');
      await pumpEventQueue();

      final state = c.read(aiChatProvider);
      expect(state.authenticationConfirmed, isTrue);
      expect(state.authChallenge, isNull);
      expect(state.authError, isNull);
      expect(state.isAuthenticating, isFalse);
      expect(
        state.lastErrorCode,
        isNot(AiChatNotifier.authRequiredCode),
        reason: 'a confirmed sign-in must not keep the turn in auth-required',
      );
    },
  );

  test('a later auth-required resets the confirmation back to false', () async {
    configurePair = (p) {
      p.authMethods = methods;
      p.failPrompt = true;
    };
    final c = await container();
    addTearDown(c.dispose);
    final notifier = await ready(c);
    await raiseChallenge(c, notifier);
    await notifier.respondAuth('oauth');
    await pumpEventQueue();
    expect(c.read(aiChatProvider).authenticationConfirmed, isTrue);

    // The agent demands authentication again on the next turn.
    await notifier.sendMessage('again');
    await pumpEventQueue();

    final state = c.read(aiChatProvider);
    expect(state.authenticationConfirmed, isFalse);
    expect(state.authChallenge, isNotNull);
    expect(state.lastErrorCode, AiChatNotifier.authRequiredCode);
  });

  test('a rejected authenticate never sets the confirmation', () async {
    configurePair = (p) {
      p.authMethods = methods;
      p.failPrompt = true;
      p.failAuthenticate = true;
    };
    final c = await container();
    addTearDown(c.dispose);
    final notifier = await ready(c);
    await raiseChallenge(c, notifier);

    await notifier.respondAuth('oauth');
    await pumpEventQueue();

    final state = c.read(aiChatProvider);
    expect(state.authenticationConfirmed, isFalse);
    expect(state.authChallenge, isNotNull, reason: 'the card must stay up');
    expect(state.authError, isNotNull);
  });

  test(
    'cancelling the attempt clears the card without confirming a login',
    () async {
      configurePair = (p) {
        p.authMethods = methods;
        p.failPrompt = true;
      };
      final c = await container();
      addTearDown(c.dispose);
      final notifier = await ready(c);
      await raiseChallenge(c, notifier);

      await notifier.respondAuth(null);
      await pumpEventQueue();

      final state = c.read(aiChatProvider);
      expect(state.authChallenge, isNull);
      expect(state.authenticationConfirmed, isFalse);
      expect(state.isAuthenticating, isFalse);
      expect(state.isGenerating, isFalse);
    },
  );
}
