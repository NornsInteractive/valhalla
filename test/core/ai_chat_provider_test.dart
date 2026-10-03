import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// A stubbed independent catalog lookup for one agent profile.
typedef _CatalogQuery =
    Future<AgentRuntimeCapabilities?> Function(AgentProfile profile);

/// Stands in for an agent with no independently queryable catalog.
Future<AgentRuntimeCapabilities?> _emptyCatalog(_, _) async =>
    const AgentRuntimeCapabilities();

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
      tempChatRepositoryOverride(),
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

/// 等历史加载真正结束；不能用固定 pumpEventQueue 假定磁盘已完成。
Future<void> _awaitHistoryLoad(ProviderContainer container) async {
  // 先触发一次读（invalidate 后的重建、以及 build 排的刷新 microtask 都挂在这），
  // 否则 isLoadingSessions 还是 false 就直接返回，断言仍然踩在加载中。
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

/// 通过 `repo.exportAll` 读取已持久化的全部会话。
///
/// 旧 preferences 只保留为迁移源，历史断言一律走 repo。
Future<List<ChatSession>> _storedSessions(ProviderContainer container) async {
  final encoded = await container.read(chatRepositoryProvider).exportAll();
  return (jsonDecode(encoded) as List)
      .map(
        (entry) =>
            ChatSession.fromJson(Map<String, dynamic>.from(entry as Map)),
      )
      .toList();
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
          tempChatRepositoryOverride(),
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
      await _awaitHistoryLoad(container);
      expect(await _storedSessions(container), hasLength(1));
      await notifier.setShareAgentSessions(true);
      expect(storage.getShareAgentSessions('srv-1'), isTrue);
      expect(storage.getShareAgentSessions('srv-2'), isFalse);
      await _awaitHistoryLoad(container);
      await _sendAndSettle(container, 'second');
      expect(container.read(aiChatProvider).activeSessionId, localId);
      expect(pairs[1].sentToAgent.join(), contains('user: first'));
      final session = await container
          .read(chatRepositoryProvider)
          .loadSession(localId!);
      expect(session, isNotNull);
      expect(session!.contextFor('builtin-codex').remoteSessionId, 'remote-0');
      expect(
        session.contextFor('builtin-claude-code').remoteSessionId,
        'remote-1',
      );
      notifier.switchAgent('builtin-codex');
      await _awaitHistoryLoad(container);
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
          tempChatRepositoryOverride(),
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
      await _awaitHistoryLoad(container);
      expect(container.read(aiChatProvider).activeSession!.messages, isEmpty);
      final stored = await _storedSessions(container);
      expect(stored.single.serverId, 'srv-1');
      expect(
        prefs.getString('valhalla_chat_sessions_v1_before_owner_v2'),
        originalSessions,
      );
      expect(storage.legacyOwnershipServerId, 'srv-1');
      final repo = container.read(chatRepositoryProvider);
      final page = await repo.listSessions('srv-2');
      expect(page.sessions, isEmpty);
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
          tempChatRepositoryOverride(),
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
      await _awaitHistoryLoad(container);
      await _sendAndSettle(container, 'second');
      final sessions = container.read(aiChatProvider).sessions;
      expect(pairs, hasLength(2));
      expect(sessions.first.remoteSessionId, 'remote-1');
      expect(
        sessions.firstWhere((entry) => entry.id == firstId).remoteSessionId,
        'remote-0',
      );
      // 新建会话默认目录改为 '.'：真实 SSH 传输会用 pwd 探测绝对路径，
      // 测试用的 fake 传输不是 AcpSshTransport，因此保持 '.'。
      expect(pairs.last.newSessionCwds, ['.']);
      expect(
        (await _storedSessions(
          container,
        )).map((entry) => entry.remoteSessionId).toSet(),
        {'remote-0', 'remote-1'},
      );
    },
  );

  test(
    'first send transport failure keeps the draft and no empty history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tempChatRepositoryOverride(),
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
      final notifier = container.read(aiChatProvider.notifier);
      notifier.updateDraftText('hello');
      await _sendAndSettle(container, 'hello');
      final state = container.read(aiChatProvider);
      expect(state.isGenerating, isFalse);
      expect(state.lastErrorCode, contains('transport unavailable'));
      // 失败发生在建会话之前：草稿保留，用户可直接重试。
      expect(state.draftText, 'hello');
      expect(state.sessions, isEmpty);
      // 不留下空的历史会话。
      expect(await _storedSessions(container), isEmpty);
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
          tempChatRepositoryOverride(),
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
        tempChatRepositoryOverride(),
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
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(() => registry),
          // The selection is only kept while the agent still belongs to the
          // active server, so this case needs the same server the profiles use.
          activeServerProvider.overrideWith(_StubActiveServer.new),
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
          tempChatRepositoryOverride(),
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

    test('revoked auth 失去确认：authRequired 之后的 complete 事件不能收起卡片', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');

      // adapter 在 authRequired 里把 _authenticated 复位，随后同一段 catch
      // 还会补发 ACPCompleteEvent。若确认没被复位，那条 complete 会把卡片
      // 清掉——所以这里断言卡片仍然在，就是在断言「吊销 = 失去确认」。
      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNotNull);
      expect(state.lastErrorCode, AiChatNotifier.authRequiredCode);
      expect(state.isGenerating, isFalse);
    });

    test('应用外登录后重发同一条消息：卡片与报错都清掉，且不重复写入这一轮', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');

      final challenged = container.read(aiChatProvider);
      expect(challenged.authChallenge, isNotNull);
      expect(challenged.lastErrorCode, AiChatNotifier.authRequiredCode);
      final afterChallenge = challenged.activeSession!.messages;
      expect(afterChallenge, hasLength(2));
      expect(afterChallenge.last.content, isEmpty);

      // 用户在应用外完成登录（不经过 respondAuth），再点一次发送。
      configurePair = (p) => p.failPrompt = false;
      pair.failPrompt = false;
      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNull, reason: '会话成功建立后必须自动收起卡片');
      expect(
        state.lastErrorCode,
        isNot(AiChatNotifier.authRequiredCode),
        reason: '卡片收起时同步清掉 ACP_AUTH_REQUIRED',
      );

      final messages = state.activeSession!.messages;
      expect(
        messages.where((m) => m.role == MessageRole.user && m.content == 'hi'),
        hasLength(1),
        reason: '重试是补发同一轮，不能写第二条用户消息',
      );
      expect(messages, hasLength(2), reason: '气泡数与登录前一致');
    });

    test('只有 initialize 成功时不能算已认证，卡片必须保留', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failSessionNew = true;
        p.sessionNewErrorCode = -32000;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');

      // fake 的 initialize 永远成功，但远端会话没建立——这不构成认证。
      final kept = container.read(aiChatProvider);
      expect(kept.authChallenge, isNotNull);
      expect(kept.lastErrorCode, AiChatNotifier.authRequiredCode);

      // 只有真正把会话建起来，确认才成立，卡片才允许被收起。
      configurePair = (p) => p.failSessionNew = false;
      pair.failSessionNew = false;
      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNull);
      expect(state.lastErrorCode, isNot(AiChatNotifier.authRequiredCode));
    });

    test('卡片在屏时，与认证无关的远端报错不得把它清掉', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');
      expect(container.read(aiChatProvider).authChallenge, isNotNull);

      // 换成一个非 -32000 的普通远端错误：它只该改写报错，不该顺手收卡片。
      configurePair = (p) {
        p.failPrompt = true;
        p.promptErrorCode = -32603;
      };
      pair.failPrompt = true;
      pair.promptErrorCode = -32603;
      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNotNull, reason: '无关错误不能收起认证卡片');
    });

    test('-32000 只标 awaitingAuthentication，绝不标成 interrupted', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      final messages = state.activeSession!.messages;
      expect(messages, hasLength(2), reason: '认证失败不得自动重发或补写消息');
      expect(messages.first.role, MessageRole.user);
      expect(messages.first.content, 'hi');

      final assistant = messages.last;
      expect(assistant.role, MessageRole.assistant);
      expect(
        assistant.status,
        ChatTurnStatus.awaitingAuthentication,
        reason: '-32000 是等待 ACP 认证，不是用户停止',
      );
      expect(
        assistant.status,
        isNot(ChatTurnStatus.interrupted),
        reason: 'host 侧曾静默显示「已中断」，这里就是它的回归点',
      );
      expect(state.lastErrorCode, AiChatNotifier.authRequiredCode);
      expect(state.authChallenge, isNotNull);
    });

    test('显式重试复用占位并最终 completed：恰好一条用户 + 一条助手', () async {
      configurePair = (p) {
        p.authMethods = [
          {'id': 'chat-gpt', 'name': 'ChatGPT'},
        ];
        p.failPrompt = true;
      };
      final container = await authContainer(connected: true);
      addTearDown(container.dispose);

      await _sendAndSettle(container, 'hi');
      final challenged = container.read(aiChatProvider);
      expect(challenged.authChallenge, isNotNull);
      expect(
        challenged.activeSession!.messages.last.status,
        ChatTurnStatus.awaitingAuthentication,
      );

      // 用户在应用外完成登录后，显式重发同一条消息。
      // 复用同一个 adapter（不会新建 pair），所以两处都要改。
      const retryChunk = [
        {
          'sessionUpdate': 'agent_message_chunk',
          'messageId': 'a1',
          'content': {'type': 'text', 'text': 'host is up'},
        },
      ];
      configurePair = (p) {
        p.failPrompt = false;
        p.promptUpdates = retryChunk;
      };
      pair.failPrompt = false;
      pair.promptUpdates = retryChunk;
      await _sendAndSettle(container, 'hi');

      final state = container.read(aiChatProvider);
      expect(state.authChallenge, isNull, reason: '重试成功必须清掉旧卡片');
      expect(
        state.lastErrorCode,
        isNot(AiChatNotifier.authRequiredCode),
        reason: '卡片收起时同步清掉 ACP_AUTH_REQUIRED',
      );

      final messages = state.activeSession!.messages;
      expect(messages, hasLength(2), reason: '不自动补发，仍是 1 用户 + 1 助手');
      expect(
        messages.where((m) => m.role == MessageRole.user && m.content == 'hi'),
        hasLength(1),
        reason: '同一条用户消息只允许有一条',
      );

      final assistant = messages.last;
      expect(assistant.role, MessageRole.assistant);
      expect(
        assistant.status,
        ChatTurnStatus.completed,
        reason: '成功重试后是 completed，不保留认证/中断标签',
      );
      expect(assistant.content, contains('host is up'));
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
          tempChatRepositoryOverride(),
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
          tempChatRepositoryOverride(),
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
      await _awaitHistoryLoad(container);

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
      await _awaitHistoryLoad(container);
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
          tempChatRepositoryOverride(),
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

      await _awaitHistoryLoad(container);
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
          tempChatRepositoryOverride(),
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
          tempChatRepositoryOverride(),
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
          tempChatRepositoryOverride(),
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

  group('ACP 第一阶段：审批选项、运行设置与工具增量', () {
    late FakeAcpPair pair;
    final createdPairs = <FakeAcpPair>[];

    const permissionOptions = [
      {'optionId': 'allow-once', 'name': 'Allow once', 'kind': 'allow_once'},
      {
        'optionId': 'allow-always',
        'name': 'Allow always',
        'kind': 'allow_always',
      },
      {'optionId': 'reject-once', 'name': 'Reject once', 'kind': 'reject_once'},
    ];

    Future<ProviderContainer> acpContainer({
      ChatRunSettings runSettings = const ChatRunSettings(),
      List<Map<String, Object?>> configOptions = const [],
      bool holdPrompt = false,
      void Function(FakeAcpPair pair)? configurePair,
      // 模型目录只来自独立查询接口，与 session config 无关；显式注入以免
      // 这层测试隐式依赖 Agent 的 CLI 类型判定。
      _CatalogQuery? modelQuery,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.saveChatRunDefault('srv-1', 'builtin-codex', runSettings);
      createdPairs.clear();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(
            () => _FakeRegistry([_profile('builtin-codex')]),
          ),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          agentModelQueryProvider.overrideWithValue(
            modelQuery == null
                ? _emptyCatalog
                : (profile, _) => modelQuery(profile),
          ),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            final next = FakeAcpPair(sessionId: 'stable-session');
            next.configOptions = configOptions;
            // 审批用例需要在 prompt 未结束时插入 session/request_permission。
            next.holdPrompt = holdPrompt;
            configurePair?.call(next);
            createdPairs.add(next);
            pair = next;
            return next.client;
          }),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Agent 侧发起 `session/request_permission`。
    void deliverPermission(FakeAcpPair target, {String id = 'perm-1'}) {
      target.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': 'session/request_permission',
          'params': {
            'sessionId': 'stable-session',
            'toolCall': {
              'toolCallId': 'tool-1',
              'title': 'bash',
              'kind': 'execute',
              'status': 'pending',
            },
            'options': permissionOptions,
          },
        }),
      );
    }

    Map<String, Object?> permissionResult(FakeAcpPair target, String id) {
      final frame = target.sentToAgent
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .firstWhere((frame) => frame['id'] == id);
      return Map<String, Object?>.from(frame['result']! as Map);
    }

    /// 本轮被 held 的生成，结束时必须 await，否则会漏报异常。
    Future<void> heldTurn = Future<void>.value();

    /// 开启一次被 held 的生成，让权限请求可以中途送达。
    Future<void> startHeldTurn(ProviderContainer container) async {
      heldTurn = container
          .read(aiChatProvider.notifier)
          .sendMessage('run the risky command');
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (createdPairs.isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('ACP transport was never created');
        }
        await pumpEventQueue();
      }
      await pair.promptReceived.timeout(const Duration(seconds: 5));
    }

    test('审批透出远端 options 并回传原始 optionId', () async {
      final container = await acpContainer(holdPrompt: true);
      final notifier = container.read(aiChatProvider.notifier);
      await startHeldTurn(container);
      deliverPermission(pair);
      await pumpEventQueue();

      final pending = container.read(aiChatProvider).pendingPermission;
      expect(pending, isNotNull);
      expect(pending!.options.map((option) => option.id), [
        'allow-once',
        'allow-always',
        'reject-once',
      ]);
      expect(pending.options.map((option) => option.kind), [
        'allow_once',
        'allow_always',
        'reject_once',
      ]);
      expect(pending.options.map((option) => option.name), [
        'Allow once',
        'Allow always',
        'Reject once',
      ]);

      notifier.respondPermission('allow-always');
      await pumpEventQueue();

      expect(permissionResult(pair, 'perm-1'), {
        'outcome': {'outcome': 'selected', 'optionId': 'allow-always'},
      });
      expect(container.read(aiChatProvider).pendingPermission, isNull);

      pair.finishHeldPrompt();
      await heldTurn;
    });

    test('旧 bool 入口只匹配 once，绝不升级为 always', () async {
      final container = await acpContainer(holdPrompt: true);
      final notifier = container.read(aiChatProvider.notifier);
      await startHeldTurn(container);

      deliverPermission(pair);
      await pumpEventQueue();
      notifier.respondPermission(true);
      await pumpEventQueue();
      expect(permissionResult(pair, 'perm-1'), {
        'outcome': {'outcome': 'selected', 'optionId': 'allow-once'},
      });

      deliverPermission(pair, id: 'perm-2');
      await pumpEventQueue();
      notifier.respondPermission(false);
      await pumpEventQueue();
      expect(permissionResult(pair, 'perm-2'), {
        'outcome': {'outcome': 'selected', 'optionId': 'reject-once'},
      });

      pair.finishHeldPrompt();
      await heldTurn;
    });

    test('审批传 null 表示取消并清掉待审批状态', () async {
      final container = await acpContainer(holdPrompt: true);
      final notifier = container.read(aiChatProvider.notifier);
      await startHeldTurn(container);

      deliverPermission(pair);
      await pumpEventQueue();
      expect(container.read(aiChatProvider).pendingPermission, isNotNull);

      notifier.respondPermission(null);
      await pumpEventQueue();

      expect(permissionResult(pair, 'perm-1'), {
        'outcome': {'outcome': 'cancelled'},
      });
      expect(container.read(aiChatProvider).pendingPermission, isNull);

      pair.finishHeldPrompt();
      await heldTurn;
    });

    test('不在远端 options 里的选择被忽略，不回写协议', () async {
      final container = await acpContainer(holdPrompt: true);
      final notifier = container.read(aiChatProvider.notifier);
      await startHeldTurn(container);

      deliverPermission(pair);
      await pumpEventQueue();
      notifier.respondPermission('invented-id');
      await pumpEventQueue();

      expect(
        container.read(aiChatProvider).pendingPermission,
        isNotNull,
        reason: '无效选择不能清掉待审批请求',
      );
      expect(
        pair.sentToAgent.where((line) => line.contains('"id":"perm-1"')),
        isEmpty,
        reason: '无效选择不能产生权限响应帧',
      );

      notifier.respondPermission('reject-once');
      await pumpEventQueue();
      expect(permissionResult(pair, 'perm-1'), {
        'outcome': {'outcome': 'selected', 'optionId': 'reject-once'},
      });

      pair.finishHeldPrompt();
      await heldTurn;
    });

    test('自动放行策略也只选 allow_once，不自动选 allow_always', () async {
      final container = await acpContainer(
        holdPrompt: true,
        runSettings: const ChatRunSettings(
          permissionPolicy: OperationPermissionPolicy.autoAllowAll,
        ),
      );
      await startHeldTurn(container);
      deliverPermission(pair);
      await pumpEventQueue();

      expect(container.read(aiChatProvider).pendingPermission, isNull);
      expect(permissionResult(pair, 'perm-1'), {
        'outcome': {'outcome': 'selected', 'optionId': 'allow-once'},
      });

      pair.finishHeldPrompt();
      await heldTurn;
    });

    test('prepareRunSettings 无论是否刷新都复用已建立的连接', () async {
      final container = await acpContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await _sendAndSettle(container, 'first');
      expect(createdPairs, hasLength(1));

      expect(await notifier.prepareRunSettings(), isTrue);
      expect(createdPairs, hasLength(1), reason: '普通打开运行设置必须复用当前连接');
      expect(
        createdPairs.single.newSessionCwds,
        hasLength(1),
        reason: '复用连接时不得重建远端会话',
      );

      // 刷新只重新查询独立目录，绝不重建正在工作的 ACP 传输或远端会话。
      final promptsBefore = createdPairs.single.sentToAgent
          .where((line) => line.contains('session/prompt'))
          .length;
      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      expect(createdPairs, hasLength(1), reason: '刷新不得重建已建立的 ACP 连接');
      expect(
        createdPairs.single.newSessionCwds,
        hasLength(1),
        reason: '刷新不得为刷新补建远端会话',
      );
      expect(
        createdPairs.single.loadRequests,
        isEmpty,
        reason: '刷新不得 load 远端会话',
      );
      expect(
        createdPairs.single.sentToAgent.where(
          (line) => line.contains('session/prompt'),
        ),
        hasLength(promptsBefore),
        reason: '刷新不得触发对话',
      );
    });

    test('model_config 不作为 thought_level 推理兜底', () async {
      final container = await acpContainer(
        // 目录由独立接口提供，且与 session config 的模型列表刻意不同。
        modelQuery: (_) async => const AgentRuntimeCapabilities(
          models: [ChatSettingOption('gpt-5-codex', 'GPT-5 Codex')],
        ),
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'currentValue': 'gpt-5',
            'category': 'model',
            'options': [
              {'value': 'gpt-5', 'name': 'GPT-5'},
              {'value': 'gpt-4.1', 'name': 'GPT-4.1'},
            ],
          },
          {
            'type': 'select',
            'id': 'model-config',
            'name': 'Model config',
            'currentValue': 'balanced',
            'category': 'model_config',
            'options': [
              {'value': 'balanced', 'name': 'Balanced'},
              {'value': 'precise', 'name': 'Precise'},
            ],
          },
        ],
      );

      await _sendAndSettle(container, 'hello');
      // 目录只在准备运行设置或首次发送校验时查询，这里显式触发一次。
      expect(
        await container.read(aiChatProvider.notifier).prepareRunSettings(),
        isTrue,
      );
      await _sendAndSettle(container, 'again');

      final caps = container.read(aiChatProvider).capabilities;
      expect(
        caps.models.map((option) => option.id),
        ['gpt-5-codex'],
        reason: '模型列表只来自独立查询接口，不采信 session config',
      );
      expect(caps.reasoningLevels, isEmpty, reason: 'model_config 不得冒充推理等级');
      expect(caps.currentReasoningId, isNull);
      expect(
        caps.extraSettings.map((setting) => setting.id),
        contains('model-config'),
        reason: 'model_config 只能作为普通附加设置暴露',
      );
    });

    test('存在 thought_level 时推理等级只取 thought_level', () async {
      final container = await acpContainer(
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'currentValue': 'gpt-5',
            'category': 'model',
            'options': [
              {'value': 'gpt-5', 'name': 'GPT-5'},
            ],
          },
          {
            'type': 'select',
            'id': 'thought-level',
            'name': 'Reasoning',
            'currentValue': 'high',
            'category': 'thought_level',
            'options': [
              {'value': 'low', 'name': 'Low'},
              {'value': 'high', 'name': 'High'},
            ],
          },
          {
            'type': 'select',
            'id': 'model-config',
            'name': 'Model config',
            'currentValue': 'balanced',
            'category': 'model_config',
            'options': [
              {'value': 'balanced', 'name': 'Balanced'},
            ],
          },
        ],
      );

      await _sendAndSettle(container, 'hello');

      final caps = container.read(aiChatProvider).capabilities;
      expect(caps.currentReasoningId, 'high');
      expect(caps.reasoningLevels.map((option) => option.id), ['low', 'high']);
      expect(caps.extraSettings.map((setting) => setting.id), ['model-config']);
    });

    test('工具部分更新在会话里保留被省略的字段', () async {
      final container = await acpContainer(
        configurePair: (target) {
          target.promptUpdates = [
            {
              'sessionUpdate': 'tool_call',
              'toolCallId': 'tool-7',
              'title': 'free -m',
              'kind': 'execute',
              'status': 'in_progress',
              'rawInput': 'free -m',
              'content': [
                {
                  'type': 'content',
                  'content': {'type': 'text', 'text': 'Mem: 7912'},
                },
              ],
            },
            {
              'sessionUpdate': 'tool_call_update',
              'toolCallId': 'tool-7',
              'status': 'completed',
            },
          ];
        },
      );

      await _sendAndSettle(container, 'check memory');

      final session = container.read(aiChatProvider).activeSession!;
      final tools = [
        for (final message in session.messages) ...message.toolExecutions,
      ];
      expect(tools, hasLength(1));
      expect(tools.single.id, 'tool-7');
      expect(tools.single.name, 'free -m', reason: '部分更新不能清掉标题');
      expect(tools.single.command, 'free -m', reason: '部分更新不能清掉命令');
      expect(tools.single.output, 'Mem: 7912', reason: '部分更新不能清掉输出');
      expect(tools.single.status, ToolExecutionStatus.completed);
    });

    test('流式文本与工具交错时 contentBlocks 保持到达顺序', () async {
      final container = await acpContainer(
        configurePair: (target) {
          target.promptUpdates = [
            {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'a1',
              'content': {'type': 'text', 'text': 'step one'},
            },
            {
              'sessionUpdate': 'tool_call',
              'toolCallId': 't1',
              'title': 'ls',
              'kind': 'execute',
              'status': 'in_progress',
              'rawInput': 'ls',
            },
            {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'a1',
              'content': {'type': 'text', 'text': ' then '},
            },
            {
              'sessionUpdate': 'tool_call',
              'toolCallId': 't2',
              'title': 'df',
              'kind': 'execute',
              'status': 'completed',
              'rawInput': 'df',
            },
            {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'a1',
              'content': {'type': 'text', 'text': 'done'},
            },
          ];
        },
      );

      await _sendAndSettle(container, 'interleave');

      final session = container.read(aiChatProvider).activeSession!;
      final assistant = session.messages.last;
      expect(assistant.role, MessageRole.assistant);
      expect(assistant.content, 'step one then done');
      expect(assistant.toolExecutions.map((t) => t.id), ['t1', 't2']);
      List<String> shapes(Iterable<ChatContentBlock> blocks) => [
        for (final block in blocks)
          block.type == ChatContentBlockType.text
              ? 'text:${block.start}-${block.end}'
              : 'tool:${block.toolId}',
      ];
      expect(shapes(assistant.orderedContentBlocks), [
        'text:0-8',
        'tool:t1',
        'text:8-14',
        'tool:t2',
        'text:14-18',
      ], reason: '块必须按远端到达顺序渲染，工具不得被挪到末尾');

      final rendered = [
        for (final block in assistant.orderedContentBlocks)
          if (block.type == ChatContentBlockType.text)
            assistant.content.substring(block.start, block.end),
      ];
      expect(
        rendered.join(),
        'step one then done',
        reason: 'range 指向 content 本身',
      );

      final stored = (await _storedSessions(
        container,
      )).singleWhere((s) => s.id == session.id).messages.last;
      expect(
        shapes(stored.orderedContentBlocks),
        shapes(assistant.orderedContentBlocks),
        reason: '落盘后必须仍按同一顺序渲染',
      );
    });
  });

  group('requestAuthenticationForAgent', () {
    Future<ProviderContainer> authContainer({
      required AiChatNotifier notifier,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            LocalStorageService(prefs),
          ),
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(
            () => _AllReadyRegistry([
              _profile('builtin-codex'),
              _profile('agy-alt'),
            ]),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(
            () => _StaticConnection(connected: true),
          ),
          // 认证只发现方法：任何一次真正拉起 transport 都直接失败。
          acpTransportFactoryProvider.overrideWithValue((_, _) {
            throw StateError('transport must not be created in this test');
          }),
          aiChatProvider.overrideWith(() => notifier),
        ],
      );
    }

    test('切换到目标 Agent 并保持零错误，且不建会话不碰传输', () async {
      final notifier = _AuthSpyNotifier();
      final container = await authContainer(notifier: notifier);
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      await pumpEventQueue();

      await notifier.requestAuthenticationForAgent('srv-1', 'agy-alt');
      await pumpEventQueue();

      final state = container.read(aiChatProvider);
      expect(state.activeAgentProfile?.id, 'agy-alt');
      expect(notifier.switchRequests, ['agy-alt']);
      expect(state.authError, isNull, reason: '没有拉起 transport');
      expect(state.sessions, isEmpty, reason: '只发现方法，不建会话');
      expect(state.activeSessionId, isNull);
    });

    test('服务器不匹配时立刻返回，不切 Agent 也不排任何工作', () async {
      final notifier = _AuthSpyNotifier();
      final container = await authContainer(notifier: notifier);
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      await pumpEventQueue();

      await notifier.requestAuthenticationForAgent('srv-OTHER', 'agy-alt');
      await pumpEventQueue();

      expect(notifier.switchRequests, isEmpty);
      expect(container.read(aiChatProvider).authError, isNull);
    });

    test('正在认证时不重复发起，也不切走当前 Agent', () async {
      final notifier = _AuthSpyNotifier();
      final container = await authContainer(notifier: notifier);
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      await pumpEventQueue();

      notifier.debugMarkAuthenticating();
      await notifier.requestAuthenticationForAgent('srv-1', 'agy-alt');
      await pumpEventQueue();

      expect(notifier.switchRequests, isEmpty);
    });

    test('管理路由被销毁后仍安全返回：不写状态也不抛异常', () async {
      final gate = Completer<void>();
      final notifier = _AuthSpyNotifier(gate: gate);
      final container = await authContainer(notifier: notifier);
      container.read(aiChatProvider);
      await pumpEventQueue();

      final pending = notifier.requestAuthenticationForAgent(
        'srv-1',
        'agy-alt',
      );
      await pumpEventQueue();
      expect(notifier.switchRequests, ['agy-alt'], reason: '已经进入切换');

      // 用户从管理页返回：provider 随路由一起被销毁，切换还没结束。
      container.dispose();
      gate.complete();

      // 必须正常结束——既不能把异常抛给调用方，也不能在 ref 已销毁后写 state。
      await pending;
      await pumpEventQueue();
    });
  });
}

/// 拦下 `switchAgent`，让测试能把「管理路由已经销毁」的窗口撑开。
class _AuthSpyNotifier extends AiChatNotifier {
  _AuthSpyNotifier({this.gate});

  /// 非空时切换会停在闸门上，直到测试主动放行。
  final Completer<void>? gate;
  final List<String> switchRequests = [];

  @override
  Future<void> switchAgent(String agentId) async {
    switchRequests.add(agentId);
    final pending = gate;
    if (pending != null && !pending.isCompleted) await pending.future;
    await super.switchAgent(agentId);
  }

  /// 只给测试用：把 provider 置于「正在认证」，用来检查重复发起的闸门。
  void debugMarkAuthenticating() =>
      state = state.copyWith(isAuthenticating: true);
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
