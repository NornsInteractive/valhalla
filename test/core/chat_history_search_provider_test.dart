import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_launch_preference.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';

const _server = ServerProfile(
  id: 'srv-1',
  name: 'test server',
  host: 'example.test',
  username: 'root',
);

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
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

class _MismatchedProfileNotifier extends AiChatNotifier {
  @override
  AiChatState build() => AiChatState(
    activeAgentProfile: AgentProfile(
      id: 'builtin-codex',
      serverId: 'srv-2',
      name: 'builtin-codex',
      description: 'test agent',
      cliCommand: 'cli',
      acpCommand: 'acp --stdio',
    ),
  );
}

class _SpyRepository extends ChatRepository {
  _SpyRepository(super.storage, {super.databasePath});

  int searchCalls = 0;
  int windowCalls = 0;
  String? lastServerId;
  String? lastSessionId;
  String? lastAgentId;
  String? lastQuery;
  String? lastCursor;
  ChatSearchPage page = const ChatSearchPage([], null);
  ChatSession? window;

  @override
  Future<ChatSearchPage> searchMessages(
    String serverId, {
    String? sessionId,
    String? agentId,
    required String query,
    String? cursor,
    int limit = 30,
  }) async {
    searchCalls++;
    lastServerId = serverId;
    lastSessionId = sessionId;
    lastAgentId = agentId;
    lastQuery = query;
    lastCursor = cursor;
    return page;
  }

  @override
  Future<ChatSession?> loadMessageWindow(
    String sessionId,
    String messageId, {
    int radius = 15,
  }) async {
    windowCalls++;
    return window;
  }
}

ChatMessage _message(String id, String content) => ChatMessage(
  id: id,
  role: MessageRole.user,
  content: content,
  createdAt: DateTime.utc(2026, 1, 1),
);

ChatSession _session(
  String id, {
  String agentId = 'builtin-codex',
  String serverId = 'srv-1',
  List<String> participants = const [],
}) => ChatSession(
  id: id,
  title: id,
  serverId: serverId,
  agentId: agentId,
  participantAgentIds: participants,
  messages: [_message('m0', 'needle in $id')],
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Future<_SpyRepository> _seededRepository(
  LocalStorageService storage,
  List<ChatSession> sessions,
) async {
  final directory = Directory.systemTemp.createTempSync(
    'valhalla_chat_search_provider_',
  );
  addTearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });
  final path = '${directory.path}/chat.sqlite3';
  final seeder = ChatRepository(storage, databasePath: path);
  for (final session in sessions) {
    await seeder.saveSession(session);
  }
  return _SpyRepository(storage, databasePath: path);
}

Future<ProviderContainer> _container(
  LocalStorageService storage,
  ChatRepository repository,
) async => ProviderContainer(
  overrides: [
    localStorageServiceProvider.overrideWithValue(storage),
    chatRepositoryProvider.overrideWithValue(repository),
    activeServerProvider.overrideWith(() => _StubActiveServer()),
    agentRegistryProvider.overrideWith(
      () => _AllReadyRegistry([_profile('builtin-codex')]),
    ),
    serverConnectionProvider.overrideWith(() => _StaticConnection()),
    acpTransportFactoryProvider.overrideWithValue((
      _,
      _, {
      String? initialModelId,
    }) {
      throw StateError('search must not start ACP transport');
    }),
  ],
);

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

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStorageService(await SharedPreferences.getInstance());
}

ChatSearchHit _hit(String sessionId, {String source = 'message'}) =>
    ChatSearchHit(
      sessionId: sessionId,
      messageId: 'm0',
      title: sessionId,
      role: MessageRole.user,
      sequence: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      matchOffset: 0,
      source: source,
      excerpt: 'needle',
      toolId: source == 'tool' ? 't1' : null,
    );

void main() {
  test(
    'current-only draft search returns empty without touching the repository',
    () async {
      final storage = await _storage();
      await storage.saveChatLaunchPreference(
        'srv-1',
        'builtin-codex',
        const ChatLaunchPreference(mode: ChatLaunchMode.blankDraft),
        cli: false,
      );
      final repository = await _seededRepository(storage, [_session('sess')]);
      final container = await _container(storage, repository);
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      await _settle(container);

      expect(container.read(aiChatProvider).activeSessionId, isNull);
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-codex',
      );

      final page = await notifier.searchMessages(
        'needle',
        expectedTarget: notifier.workspaceSelectionKey,
      );

      expect(page.hits, isEmpty);
      expect(page.nextCursor, isNull);
      expect(repository.searchCalls, 0);
    },
  );

  test(
    'shared search omits the agent filter and keeps the current session',
    () async {
      final storage = await _storage();
      await storage.setShareAgentSessions('srv-1', true);
      final repository = await _seededRepository(storage, [_session('sess')]);
      repository.page = ChatSearchPage([_hit('sess')], null);
      final container = await _container(storage, repository);
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      await _settle(container);

      expect(container.read(aiChatProvider).shareAgentSessions, isTrue);
      expect(container.read(aiChatProvider).activeSessionId, 'sess');

      final page = await notifier.searchMessages(
        'needle',
        expectedTarget: notifier.workspaceSelectionKey,
      );

      expect(page.hits.single.sessionId, 'sess');
      expect(repository.searchCalls, 1);
      expect(repository.lastServerId, 'srv-1');
      expect(repository.lastSessionId, 'sess');
      expect(repository.lastAgentId, isNull);
      expect(repository.lastQuery, 'needle');
      expect(repository.lastCursor, isNull);

      await notifier.searchMessages(
        'needle',
        allSessions: true,
        expectedTarget: notifier.workspaceSelectionKey,
      );
      expect(repository.searchCalls, 2);
      expect(repository.lastSessionId, isNull);
      expect(repository.lastAgentId, isNull);
    },
  );

  test('non-shared search filters by the active agent', () async {
    final storage = await _storage();
    final repository = await _seededRepository(storage, [_session('sess')]);
    final container = await _container(storage, repository);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await _settle(container);

    await notifier.searchMessages(
      'needle',
      expectedTarget: notifier.workspaceSelectionKey,
    );

    expect(repository.lastSessionId, 'sess');
    expect(repository.lastAgentId, 'builtin-codex');
  });

  test('stale expectedTarget is rejected before any repository call', () async {
    final storage = await _storage();
    final repository = await _seededRepository(storage, [_session('sess')]);
    final container = await _container(storage, repository);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await _settle(container);

    final stale = throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'ACP_TARGET_CHANGED',
      ),
    );

    await expectLater(
      notifier.searchMessages('needle', expectedTarget: 'stale-target'),
      stale,
    );
    await expectLater(
      notifier.loadSearchWindow(_hit('sess'), expectedTarget: 'stale-target'),
      stale,
    );
    await expectLater(
      notifier.loadSearchToolOutput(
        _hit('sess', source: 'tool'),
        expectedTarget: 'stale-target',
      ),
      stale,
    );

    expect(repository.searchCalls, 0);
    expect(repository.windowCalls, 0);
  });

  test(
    'mismatched profile server is rejected before any repository call',
    () async {
      final storage = await _storage();
      final repository = await _seededRepository(storage, [_session('sess')]);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          chatRepositoryProvider.overrideWithValue(repository),
          activeServerProvider.overrideWith(() => _StubActiveServer()),
          aiChatProvider.overrideWith(() => _MismatchedProfileNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      expect(
        container.read(aiChatProvider).activeAgentProfile?.serverId,
        'srv-2',
      );

      final target = notifier.workspaceSelectionKey;
      final page = await notifier.searchMessages(
        'needle',
        expectedTarget: target,
      );
      expect(page.hits, isEmpty);
      expect(page.nextCursor, isNull);
      expect(
        await notifier.loadSearchWindow(_hit('sess'), expectedTarget: target),
        isNull,
      );
      expect(repository.searchCalls, 0);
      expect(repository.windowCalls, 0);
    },
  );

  test('window results outside the current agent are rejected', () async {
    final storage = await _storage();
    final repository = await _seededRepository(storage, [
      _session('other', agentId: 'builtin-claude-code'),
    ]);
    repository.window = _session('other', agentId: 'builtin-claude-code');
    final container = await _container(storage, repository);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    await _settle(container);

    final target = notifier.workspaceSelectionKey;
    expect(
      await notifier.loadSearchWindow(_hit('other'), expectedTarget: target),
      isNull,
    );
    expect(repository.windowCalls, 1);

    repository.window = _session('sess');
    expect(
      await notifier.loadSearchWindow(_hit('sess'), expectedTarget: target),
      isNotNull,
    );
    expect(repository.windowCalls, 2);
  });
}
