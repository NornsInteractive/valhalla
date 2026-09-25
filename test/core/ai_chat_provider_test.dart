import 'package:dartssh2/dartssh2.dart';
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
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'desc',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

/// Registry override that reports the given ready agent ids without touching SSH.
class _FakeRegistry extends AgentRegistryNotifier {
  _FakeRegistry(this._profiles);

  final List<AgentProfile> _profiles;
  static const serverId = 'srv-1';

  @override
  AgentRegistryState build() {
    return AgentRegistryState(
      serverId: serverId,
      agents: [
        for (final profile in _profiles)
          AgentRuntimeState(
            profile: profile,
            status: AgentEnvironmentStatus(
              kind: _readyIds.contains(profile.id)
                  ? AgentEnvironmentStatusKind.ready
                  : AgentEnvironmentStatusKind.cliMissing,
              checkedAt: DateTime.now(),
            ),
          ),
      ],
    );
  }

  static const _readyIds = {'builtin-codex'};
}

class _AllReadyRegistry extends _FakeRegistry {
  _AllReadyRegistry(super.profiles);
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

Future<ProviderContainer> _container({
  List<AgentProfile> profiles = const [],
  bool connected = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(LocalStorageService(prefs)),
      agentRegistryProvider.overrideWith(() => _FakeRegistry(profiles)),
      serverConnectionProvider.overrideWith(
        () => _StaticConnection(connected: connected),
      ),
      acpTransportFactoryProvider.overrideWithValue((_, _) {
        throw StateError('transport must not be created in this test');
      }),
    ],
  );
}

/// Sends a message and lets the broadcast event stream flush into the provider.
///
/// `sendMessage` awaits the adapter, but events travel over a broadcast stream
/// delivered on a microtask, so the listener may not have run by the time the
/// returned future completes.
Future<void> _sendAndSettle(ProviderContainer container, String text) async {
  await container.read(aiChatProvider.notifier).sendMessage(text);
  await pumpEventQueue();
}

void main() {
  test(
    'sharing is server scoped and carries text without sharing remote IDs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final pairs = <FakeAcpPair>[];
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _AllReadyRegistry([
              _profile('builtin-codex'),
              _profile('builtin-claude-code'),
            ]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            final pair = FakeAcpPair(sessionId: 'remote-${pairs.length}');
            pairs.add(pair);
            return pair.client;
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(aiChatProvider.notifier);
      await _sendAndSettle(container, 'first');
      final localId = container.read(aiChatProvider).activeSessionId;
      notifier.switchAgent('builtin-claude-code');
      expect(container.read(aiChatProvider).sessions, isEmpty);
      expect(storage.getChatSessions(), hasLength(1));
      await notifier.setShareAgentSessions(true);
      expect(storage.getShareAgentSessions('srv-1'), isTrue);
      expect(storage.getShareAgentSessions('srv-2'), isFalse);
      await _sendAndSettle(container, 'second');
      expect(container.read(aiChatProvider).activeSessionId, localId);
      expect(pairs[1].sentToAgent.join(), contains('user: first'));
      final session = storage.getChatSessions().single;
      expect(session.contextFor('builtin-codex').remoteSessionId, 'remote-0');
      expect(
        session.contextFor('builtin-claude-code').remoteSessionId,
        'remote-1',
      );
      notifier.switchAgent('builtin-codex');
      await _sendAndSettle(container, 'third');
      expect(pairs[2].loadRequests, ['remote-0']);
      expect(pairs[2].sentToAgent.join(), contains('user: second'));
      expect(pairs[2].sentToAgent.join(), isNot(contains('user: first')));
      await notifier.setShareAgentSessions(false);
      expect(container.read(aiChatProvider).sessions, hasLength(1));
    },
  );
  test(
    'legacy sessions migrate once to the selected server without binding UI',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final now = DateTime.now();
      await storage.saveChatSessions([
        ChatSession(
          id: 'legacy',
          title: 'old',
          agentId: 'builtin-codex',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final originalSessions = prefs.getString('valhalla_chat_sessions_v1');
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            throw StateError('unbound sessions must not start ACP');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      expect(container.read(aiChatProvider).activeSession!.messages, isEmpty);
      expect(storage.getChatSessions().single.serverId, 'srv-1');
      expect(
        prefs.getString('valhalla_chat_sessions_v1_before_owner_v2'),
        originalSessions,
      );
      expect(storage.legacyOwnershipServerId, 'srv-1');
      expect(
        container.read(chatRepositoryProvider).getSessionsForServer('srv-2'),
        isEmpty,
      );
    },
  );

  test(
    'two local sessions with one agent keep separate remote identities',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final pairs = <FakeAcpPair>[];
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            final pair = FakeAcpPair(sessionId: 'remote-${pairs.length}');
            pairs.add(pair);
            return pair.client;
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(aiChatProvider.notifier);
      await _sendAndSettle(container, 'first');
      final firstId = container.read(aiChatProvider).activeSessionId!;
      await notifier.createNewSession();
      await _sendAndSettle(container, 'second');
      final sessions = container.read(aiChatProvider).sessions;
      expect(pairs, hasLength(2));
      expect(sessions.first.remoteSessionId, 'remote-1');
      expect(
        sessions.firstWhere((entry) => entry.id == firstId).remoteSessionId,
        'remote-0',
      );
      expect(pairs.last.newSessionCwds, ['/root']);
      expect(
        storage.getChatSessions().map((entry) => entry.remoteSessionId).toSet(),
        {'remote-0', 'remote-1'},
      );
    },
  );

  test(
    'transport creation failure stops generation and persists the request',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            throw StateError('transport unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);
      await _sendAndSettle(container, 'hello');
      final state = container.read(aiChatProvider);
      expect(state.isGenerating, isFalse);
      expect(state.lastErrorCode, contains('transport unavailable'));
      expect(storage.getChatSessions().single.messages.first.content, 'hello');
    },
  );

  test('activeAgentProfile resolves from the ready registry list', () async {
    final container = await _container(
      profiles: [_profile('builtin-codex'), _profile('builtin-claude-code')],
    );
    addTearDown(container.dispose);

    final state = container.read(aiChatProvider);
    expect(state.readyAgents.map((a) => a.id), ['builtin-codex']);
    expect(state.activeAgentProfile?.id, 'builtin-codex');
  });

  test(
    'server ACP default selects a ready agent but manual switch wins',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      await storage.setDefaultAgentId(
        'srv-1',
        'builtin-claude-code',
        cli: false,
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          agentRegistryProvider.overrideWith(
            () => _AllReadyRegistry([
              _profile('builtin-codex'),
              _profile('builtin-claude-code'),
            ]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-claude-code',
      );
      container.read(aiChatProvider.notifier).switchAgent('builtin-codex');
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-codex',
      );
      expect(
        storage.getDefaultAgentId('srv-1', cli: false),
        'builtin-claude-code',
      );
    },
  );

  test('switchAgent selects a ready agent by stable id', () async {
    final container = await _container(profiles: [_profile('builtin-codex')]);
    addTearDown(container.dispose);

    container.read(aiChatProvider.notifier).switchAgent('builtin-codex');
    expect(
      container.read(aiChatProvider).activeAgentProfile?.id,
      'builtin-codex',
    );
  });

  test('switching to a non-ready agent is refused', () async {
    final container = await _container(
      profiles: [_profile('builtin-codex'), _profile('builtin-claude-code')],
    );
    addTearDown(container.dispose);

    container.read(aiChatProvider.notifier).switchAgent('builtin-claude-code');
    // Still codex: the un-ready agent must not become active.
    expect(
      container.read(aiChatProvider).activeAgentProfile?.id,
      'builtin-codex',
    );
  });

  test('sendMessage is blocked when no agent is ready', () async {
    final container = await _container(
      profiles: [_profile('builtin-claude-code')],
    );
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await notifier.sendMessage('diagnose the host');

    final state = container.read(aiChatProvider);
    expect(state.isGenerating, isFalse);
    expect(state.lastErrorCode, 'AGENT_NOT_READY');
    expect(state.sessions, isEmpty);
  });

  test('deprecated activeAgent bridges to the resolved profile', () async {
    final container = await _container(profiles: [_profile('builtin-codex')]);
    addTearDown(container.dispose);

    // ignore: deprecated_member_use_from_same_package
    expect(container.read(aiChatProvider).activeAgent, AgentType.codex);
  });

  test('new session button only starts an unsaved blank draft', () async {
    final container = await _container(profiles: [_profile('builtin-codex')]);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await notifier.createNewSession('title');

    expect(container.read(aiChatProvider).sessions, isEmpty);
    expect(container.read(aiChatProvider).activeSession, isNull);
  });

  test('auto-activates the first ready agent once install completes', () async {
    final registry = _MutableRegistry([_profile('builtin-codex')]);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          LocalStorageService(prefs),
        ),
        agentRegistryProvider.overrideWith(() => registry),
        serverConnectionProvider.overrideWith(
          () => _StaticConnection(connected: false),
        ),
        acpTransportFactoryProvider.overrideWithValue((_, _) {
          throw StateError('transport must not be created in this test');
        }),
      ],
    );
    addTearDown(container.dispose);

    // Nothing ready yet: no active agent, chat unusable.
    expect(container.read(aiChatProvider).activeAgentProfile, isNull);

    // Simulate a successful install marking the agent ready.
    registry.markReady('builtin-codex');

    expect(
      container.read(aiChatProvider).activeAgentProfile?.id,
      'builtin-codex',
    );
  });

  test(
    'keeps an explicitly selected ready agent across registry updates',
    () async {
      final registry = _MutableRegistry([
        _profile('builtin-codex'),
        _profile('builtin-claude-code'),
      ]);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            LocalStorageService(prefs),
          ),
          agentRegistryProvider.overrideWith(() => registry),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: false),
          ),
          acpTransportFactoryProvider.overrideWithValue((_, _) {
            throw StateError('transport must not be created in this test');
          }),
        ],
      );
      addTearDown(container.dispose);

      // Initialize providers, then mark both agents ready.
      container.read(aiChatProvider);
      registry.markReady('builtin-codex');
      registry.markReady('builtin-claude-code');

      container
          .read(aiChatProvider.notifier)
          .switchAgent('builtin-claude-code');
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-claude-code',
      );

      // An unrelated registry change must not steal the selection.
      registry.touch();
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-claude-code',
      );
    },
  );

  group('ACP auth challenge', () {
    late FakeAcpPair pair;

    /// Configures every pair the factory will hand out.
    ///
    /// Applied at creation so the *first* send already sees the agent's
    /// behaviour; mutating [pair] directly only affects the newest adapter.
    void Function(FakeAcpPair pair)? configurePair;

    /// Container whose ACP transport is a fresh fake pair per send, so a real
    /// turn can run.
    ///
    /// `sendMessage` disposes the previous adapter before building a new one,
    /// which closes its transport. Production opens a fresh SSH exec channel
    /// per send, so the factory hands out a new pair each time and [pair]
    /// always points at the most recent one.
    Future<ProviderContainer> authContainer({required bool connected}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      return ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: connected),
          ),
          // sendMessage requires an active server AND a connected state before
          // it will look up an SSH client.
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            pair = FakeAcpPair();
            configurePair?.call(pair);
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
    }

    test('an auth requirement raises a challenge instead of an error', () async {
      configurePair = (p) {
        p.authMethods = [
          {
            'id': 'chat-gpt',
            'name': 'ChatGPT',
            'description': 'Browser sign-in',
          },
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'diagnose the host');

      final state = container.read(aiChatProvider);
      final challenge = state.authChallenge;
      expect(challenge, isNotNull);
      expect(challenge!.agentId, 'builtin-codex');
      expect(challenge.methods.single.id, 'chat-gpt');
      expect(challenge.methods.single.description, 'Browser sign-in');
      // Auth is recoverable: it must not be filed as a generic transport error.
      expect(state.lastErrorCode, isNot(contains('ACP_TRANSPORT_FAILURE')));
    });

    test('an empty method list still raises a challenge', () async {
      configurePair = (p) => p.failPrompt = true;
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');

      final challenge = container.read(aiChatProvider).authChallenge;
      expect(challenge, isNotNull);
      expect(challenge!.methods, isEmpty);
    });

    test('respondAuth records the choice and clears the challenge', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
          {'id': 'api-key', 'name': 'API Key'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');
      await container.read(aiChatProvider.notifier).respondAuth('api-key');

      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNull);
      expect(state.selectedAuthMethods['srv-1::builtin-codex'], 'api-key');
    });

    test(
      'respondAuth(null) clears the challenge without a selection',
      () async {
        configurePair = (p) => p.failPrompt = true;
        final container = await authContainer(connected: true);
        addTearDown(container.dispose);

        final notifier = container.read(aiChatProvider.notifier);
        await _sendAndSettle(container, 'hi');
        await notifier.respondAuth(null);

        final state = container.read(aiChatProvider);
        expect(state.authChallenge, isNull);
        expect(state.selectedAuthMethods, isEmpty);
        expect(state.lastErrorCode, AiChatNotifier.authRequiredCode);
      },
    );

    test('the chosen method is replayed on the next send', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');
      await container.read(aiChatProvider.notifier).respondAuth('chat-gpt');

      expect(container.read(aiChatProvider).selectedAuthMethods, {
        'srv-1::builtin-codex': 'chat-gpt',
      });

      // The agent now accepts the turn. `respondAuth` decided the session on the
      // live adapter, so the next send must re-run authenticate before building
      // a new session — even though the adapter/transport itself is reused.
      configurePair = (p) => p.failPrompt = false;
      pair.failPrompt = false;
      await _sendAndSettle(container, 'hi again');

      expect(pair.authenticateCallCount, 1, reason: '复用 adapter 后认证仍必须在建会话前重放');
      expect(pair.lastAuthenticateMethodId, 'chat-gpt');
    });

    test('同一 Agent 的连续两次发送复用同一个 transport（不再每个进程重启）', () async {
      // 这是「发第二条消息就丢上下文」的回归测试：旧实现每次 sendMessage
      // 都重建 transport，等于每次重开一个远端 agent 进程。
      var transportCreations = 0;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      late FakeAcpPair pair;

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            transportCreations++;
            pair = FakeAcpPair(sessionId: 'stable-session');
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'first');
      pair.resetPromptReceived();
      await _sendAndSettle(container, 'second');

      expect(transportCreations, 1, reason: '连续两次发送必须复用同一个远端 agent 进程');
      expect(
        pair.newSessionCwds,
        hasLength(1),
        reason: '复用 transport 时不应重新建会话，否则上下文会丢',
      );
    });

    test('切换 Agent 会重建 transport', () async {
      var transportCreations = 0;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final registry = _MutableRegistry([
        _profile('builtin-codex'),
        _profile('builtin-claude-code'),
      ]);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(() => registry),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            transportCreations++;
            return FakeAcpPair().client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      // 默认激活的 Agent 必须先 ready；registry 需先被读取（初始化）才能改。
      container.read(aiChatProvider);
      registry.markReady('builtin-codex');
      await pumpEventQueue();

      final notifier = container.read(aiChatProvider.notifier);
      await _sendAndSettle(container, 'first');
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-codex',
        reason: '第一轮应使用默认激活的 Agent',
      );
      expect(transportCreations, 1);

      // 目标 Agent 必须先 ready 才允许切换。
      registry.markReady('builtin-claude-code');
      await pumpEventQueue();

      notifier.switchAgent('builtin-claude-code');
      await pumpEventQueue();
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-claude-code',
      );

      await _sendAndSettle(container, 'second');

      expect(
        transportCreations,
        2,
        reason: '换 Agent 必须换进程，否则会把上一个 Agent 的会话当成当前的',
      );
    });

    test('复用历史会话时上报 acpSessionRestored=true 且不报上下文丢失', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      late FakeAcpPair pair;

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            pair = FakeAcpPair(sessionId: 'restored-session');
            // 模拟远端接受 session/load，即会话被复用。
            pair.failSessionLoad = false;
            pair.failSessionResume = false;
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      // 先持久化一个历史会话 id，adapter 才会尝试 load/resume。
      await storage.saveAcpSessionId(
        'srv-1',
        'builtin-codex',
        'restored-session',
      );
      final now = DateTime.now();
      final localSession = ChatSession(
        id: 'restored-local',
        title: 'restored',
        agentId: 'builtin-codex',
        serverId: 'srv-1',
        createdAt: now,
        updatedAt: now,
      );
      await container
          .read(chatRepositoryProvider)
          .saveSession(
            localSession.copyWith(remoteSessionId: 'restored-session'),
          );
      container.invalidate(aiChatProvider);

      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.acpSessionRestored, isTrue);
      expect(
        state.acpSessionRestartDetected,
        isFalse,
        reason: '会话被复用时不能报「上下文已丢失」',
      );
    });

    test('旧全局远端 ID 不污染新本地会话或误报上下文丢失', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      late FakeAcpPair pair;

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            pair = FakeAcpPair(sessionId: 'brand-new');
            pair.failSessionLoad = true;
            pair.failSessionResume = true;
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      await storage.saveAcpSessionId('srv-1', 'builtin-codex', 'old-session');

      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.acpSessionRestored, isFalse);
      expect(
        state.acpSessionRestartDetected,
        isFalse,
        reason: '新本地会话没有历史上下文，不能误报丢失',
      );
    });

    test('复用 adapter 的连续对话不会误报上下文丢失', () async {
      // 这条很关键：第二次发送复用同一个 adapter（没有重建），
      // 此时 restoredExistingSession 为 false 只是因为没走 load 路径，
      // 绝不是「上下文丢了」。少了 adapterWasRebuilt 限定，用户每发
      // 第二条消息就会看到一次假的「上下文已丢失」告警。
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            // 没有历史会话 id，首次建会话即新建，restoredExistingSession=false。
            final pair = FakeAcpPair(sessionId: 'fresh');
            pair.failSessionLoad = true;
            pair.failSessionResume = true;
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'first');
      // 第二次发送复用 adapter，不该再报丢失。
      await _sendAndSettle(container, 'second');

      final state = container.read(aiChatProvider);
      expect(
        state.acpSessionRestartDetected,
        isFalse,
        reason: '复用 adapter 的连续对话不是上下文丢失',
      );
    });

    test('用户确认后清除重启告警，但不影响会话事实', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            final pair = FakeAcpPair(sessionId: 'brand-new');
            pair.failSessionLoad = true;
            pair.failSessionResume = true;
            return pair.client;
          }),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        ],
      );
      addTearDown(container.dispose);

      await storage.saveAcpSessionId('srv-1', 'builtin-codex', 'old-session');
      await _sendAndSettle(container, 'hi');

      final notifier = container.read(aiChatProvider.notifier);
      expect(container.read(aiChatProvider).acpSessionRestartDetected, isFalse);

      notifier.acknowledgeAcpSessionRestart();

      final state = container.read(aiChatProvider);
      expect(state.acpSessionRestartDetected, isFalse);
      expect(
        state.acpSessionRestored,
        isFalse,
        reason: '确认告警不应篡改「会话是否来自历史」这个事实',
      );
    });
  });
}

/// SSH manager stub: `getClient` returns a non-null client so `sendMessage`
/// proceeds past its connectivity guard. The client itself is never used
/// because the ACP transport is overridden with the in-memory fake pair.
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

class _StaticConnection extends ServerConnectionNotifier {
  _StaticConnection({required this.connected});

  final bool connected;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: connected ? 'srv-1' : null,
  );
}

/// Pins the active server so `sendMessage` gets past its connectivity guard.
class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

/// Registry whose readiness can change at runtime, to simulate install results.
class _MutableRegistry extends AgentRegistryNotifier {
  _MutableRegistry(this._profiles);

  final List<AgentProfile> _profiles;
  final Set<String> _readyIds = {};

  void markReady(String agentId) {
    _readyIds.add(agentId);
    ref.invalidateSelf();
  }

  void touch() => ref.invalidateSelf();

  @override
  AgentRegistryState build() {
    return AgentRegistryState(
      serverId: _FakeRegistry.serverId,
      agents: [
        for (final profile in _profiles)
          AgentRuntimeState(
            profile: profile,
            status: AgentEnvironmentStatus(
              kind: _readyIds.contains(profile.id)
                  ? AgentEnvironmentStatusKind.ready
                  : AgentEnvironmentStatusKind.cliMissing,
              checkedAt: DateTime.now(),
            ),
          ),
      ],
    );
  }
}
