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
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// provider 层本轮契约：草稿只 initialize、账号推送 gating、
/// `/status` 显式查询的历史留存、远端历史重新导入为副本、
/// 以及恢复偏好。
/// A stubbed independent catalog lookup for one agent profile.
typedef _CatalogQuery =
    Future<AgentRuntimeCapabilities?> Function(AgentProfile profile);

/// Stands in for a successful independent catalog query.
Future<AgentRuntimeCapabilities?> _defaultCatalog(_, _) async =>
    const AgentRuntimeCapabilities(
      models: [ChatSettingOption('fake-model', 'Fake Model')],
    );

void main() {
  const agentId = 'builtin-codex';
  const remoteId = 'remote-codex-1';

  late List<FakeAcpPair> pairs;
  late LocalStorageService storage;

  AgentProfile profile() => AgentProfile(
    id: agentId,
    serverId: 'srv-1',
    name: agentId,
    description: 'test agent',
    cliCommand: 'cli',
    acpCommand: 'acp --stdio',
  );

  FakeAcpPair newPair({
    String sessionId = remoteId,
    Map<String, Object?> capabilities = const {},
  }) {
    final pair = FakeAcpPair(sessionId: sessionId)
      ..agentCapabilities = capabilities;
    pairs.add(pair);
    return pair;
  }

  Future<ProviderContainer> makeContainer({
    List<AgentProfile>? profiles,
    Map<String, Object?> capabilities = const {},
    List<Map<String, Object?>> remoteSessions = const [],
    void Function(FakeAcpPair pair)? configurePair,
    Map<String, Object> prefs = const {},
    // 模型目录只来自独立查询接口；这里显式注入，避免依赖 Agent 的 CLI 类型。
    _CatalogQuery? modelQuery,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    storage = LocalStorageService(await SharedPreferences.getInstance());
    pairs = [];
    final created = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(
          () => _ReadyRegistry(profiles ?? [profile()]),
        ),
        serverConnectionProvider.overrideWith(() => _StaticConnection(true)),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        agentModelQueryProvider.overrideWithValue(
          modelQuery == null
              ? _defaultCatalog
              : (profile, _) => modelQuery(profile),
        ),
        acpTransportFactoryProvider.overrideWithValue((_, _) async {
          final pair = newPair(capabilities: capabilities);
          pair.remoteSessions = remoteSessions;
          configurePair?.call(pair);
          return pair.client;
        }),
      ],
    );
    addTearDown(created.dispose);
    return created;
  }

  Future<void> settle(ProviderContainer target) async {
    await pumpEventQueue();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (target.read(aiChatProvider).isLoadingSessions ||
        target.read(aiChatProvider).isLoadingMessages) {
      if (DateTime.now().isAfter(deadline)) {
        fail('history loading never settled');
      }
      await pumpEventQueue();
    }
  }

  Future<List<ChatSession>> stored(ProviderContainer target) async {
    final encoded = await target.read(chatRepositoryProvider).exportAll();
    return (jsonDecode(encoded) as List)
        .map(
          (entry) =>
              ChatSession.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  void deliverAccount(FakeAcpPair pair, {String label = 'API Key'}) {
    pair.deliverToClient(
      jsonEncode({
        'jsonrpc': '2.0',
        'method': '_auth/status_update',
        'params': {
          'authStatus': {
            'kind': 'api_key',
            'label': label,
            'account': {'email': 'a@b.test', 'plan': 'pro'},
          },
        },
      }),
    );
  }

  tearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });

  group('草稿设置：只 initialize，不建会话', () {
    test('prepareRunSettings 在草稿上不触发 session/new', () async {
      final container = await makeContainer(
        capabilities: const {
          'promptCapabilities': {'image': true, 'embeddedContext': true},
        },
      );
      final notifier = container.read(aiChatProvider.notifier);

      final ok = await notifier.prepareRunSettings();
      await settle(container);

      expect(ok, isTrue);
      expect(pairs, hasLength(1));
      expect(pairs.first.newSessionCount, 0, reason: '草稿不得建立远端会话');
      expect(pairs.first.loadRequests, isEmpty);
      expect(pairs.first.sentToAgent.join(), isNot(contains('session/prompt')));
      expect(container.read(aiChatProvider).activeSessionId, isNull);
      expect(container.read(aiChatProvider).isGenerating, isFalse);
      expect(await stored(container), isEmpty, reason: '草稿不得落盘本地会话');
    });

    test('草稿也能拿到能力与账号推送', () async {
      final container = await makeContainer(
        capabilities: const {
          '_meta': {'authStatus': {}},
          'promptCapabilities': {'image': true, 'embeddedContext': true},
        },
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.prepareRunSettings();
      await pumpEventQueue();
      deliverAccount(pairs.first);
      await pumpEventQueue();

      final state = container.read(aiChatProvider);
      expect(state.supportsImages, isTrue);
      expect(state.supportsTextAttachments, isTrue);
      expect(state.account?.email, 'a@b.test');
      expect(pairs.first.newSessionCount, 0);
    });

    test('草稿刷新后写入获取时间并清除过期标记', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);

      expect(
        container.read(aiChatProvider).settingsStale,
        isTrue,
        reason: '尚未刷新时必须是过期状态',
      );

      await notifier.prepareRunSettings();
      await pumpEventQueue();

      final state = container.read(aiChatProvider);
      expect(
        state.settingsFetchedAt,
        isNotNull,
        reason: '草稿刷新成功必须记录获取时间，供设置页展示',
      );
      expect(state.settingsStale, isFalse);
      expect(pairs.first.newSessionCount, 0);
    });

    test('切换 Agent 清空账号与额度，隔离不同目标的推送', () async {
      final container = await makeContainer(
        capabilities: const {
          '_meta': {'authStatus': {}},
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await pumpEventQueue();
      deliverAccount(pairs.first);
      await pumpEventQueue();
      expect(container.read(aiChatProvider).account, isNotNull);

      final second = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-1',
        name: 'agy',
        description: 'agy',
        cliCommand: 'cli',
        acpCommand: 'acp --stdio',
      );
      (container.read(agentRegistryProvider.notifier) as _ReadyRegistry)
          .setProfiles([profile(), second]);
      notifier.switchAgent('builtin-agy');
      await settle(container);

      expect(container.read(aiChatProvider).account, isNull);
      expect(container.read(aiChatProvider).accountStatusText, isEmpty);
      deliverAccount(pairs.first, label: 'Stale');
      await pumpEventQueue();
      expect(
        container.read(aiChatProvider).account,
        isNull,
        reason: '旧 adapter 的推送不得污染当前目标',
      );
    });

    test('未连接时不建会话，返回明确的错误码', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      pairs = [];
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            LocalStorageService(prefs),
          ),
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(() => _ReadyRegistry([profile()])),
          serverConnectionProvider.overrideWith(() => _StaticConnection(false)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue(
            (_, _) async => newPair().client,
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(aiChatProvider.notifier)
          .prepareRunSettings();

      expect(ok, isFalse);
      expect(container.read(aiChatProvider).lastErrorCode, 'SSH_DISCONNECTED');
      expect(pairs, isEmpty);
    });
  });

  group('queryAccountStatus 显式查询', () {
    test('没有已建立会话时抛错，且绝不偷偷建会话', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);

      await expectLater(
        notifier.queryAccountStatus(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_STATUS_QUERY_UNAVAILABLE',
          ),
        ),
      );
      await settle(container);
      expect(pairs, isEmpty, reason: '失败路径不得创建 adapter');
      expect(container.read(aiChatProvider).activeSessionId, isNull);
    });

    test('agent 未声明 status 命令时抛错', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('hello');
      await settle(container);
      expect(container.read(aiChatProvider).commands, isEmpty);

      await expectLater(
        notifier.queryAccountStatus(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_STATUS_QUERY_UNAVAILABLE',
          ),
        ),
      );
      expect(
        (await stored(container)).single.messages.length,
        2,
        reason: '失败的查询不得插入用户消息',
      );
    });

    test('已声明 status 时发送 /status 并记录原文与获取时间', () async {
      final container = await makeContainer(
        configurePair: (pair) {
          pair.promptUpdates = [
            {
              'sessionUpdate': 'available_commands_update',
              'availableCommands': [
                {'name': 'status', 'description': 'quota'},
              ],
            },
            {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'status-1',
              'content': {'type': 'text', 'text': 'quota: 90% left'},
            },
          ];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('hello');
      await settle(container);
      expect(
        container.read(aiChatProvider).commands.map((c) => c.name),
        contains('status'),
      );

      notifier.updateDraftText('kept draft');
      await notifier.queryAccountStatus();
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.accountStatusText, 'quota: 90% left');
      expect(state.accountStatusFetchedAt, isNotNull);
      expect(state.draftText, 'kept draft', reason: '查询不得清空用户草稿');
      final session = (await stored(container)).single;
      expect(
        session.messages.where((m) => m.content == '/status'),
        hasLength(1),
        reason: '会话记录必须保留 /status 这条用户消息',
      );
      expect(session.messages.last.content, 'quota: 90% left');
    });
  });

  group('远端历史重新导入为副本', () {
    const launchKey = 'host|name|null|null|acp --stdio|cli';

    AcpRemoteSession remote(String id) => AcpRemoteSession(
      id: id,
      title: 'remote $id',
      workingDirectory: '/root',
      serverId: 'srv-1',
      agentId: agentId,
      launchKey: launchKey,
    );

    test('首次导入建立本地记录，reimport 产生新副本且不覆盖原记录', () async {
      final container = await makeContainer(
        capabilities: const {
          'loadSession': true,
          'sessionCapabilities': {'list': true},
        },
        remoteSessions: [
          {
            'sessionId': remoteId,
            'title': 'first remote',
            'cwd': '/root',
            'updatedAt': '2026-09-30T00:00:00Z',
          },
        ],
        configurePair: (pair) {
          pair.loadReplayUpdates = [
            {
              'sessionUpdate': 'user_message_chunk',
              'messageId': 'u1',
              'content': {'type': 'text', 'text': 'old question'},
            },
            {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'a1',
              'content': {'type': 'text', 'text': 'old answer'},
            },
          ];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await settle(container);

      await notifier.openRemoteSession(remote(remoteId));
      await settle(container);

      final afterFirst = await stored(container);
      expect(afterFirst, hasLength(1));
      final original = afterFirst.single;
      expect(original.remoteSessionId, remoteId);
      expect(original.historyImportIncomplete, isFalse);
      expect(original.totalMessageCount, 2);
      expect(
        (await container.read(chatRepositoryProvider).loadSession(original.id))!
            .messages
            .map((m) => m.content),
        ['old question', 'old answer'],
      );

      await notifier.openRemoteSession(remote(remoteId), reimport: true);
      await settle(container);

      final afterReimport = await stored(container);
      expect(afterReimport, hasLength(2), reason: '重新导入必须是副本');
      final copy = afterReimport.firstWhere((s) => s.id != original.id);
      expect(copy.remoteSessionId, remoteId);
      expect(copy.id, isNot(original.id));
      final reloaded = await container
          .read(chatRepositoryProvider)
          .loadSession(original.id);
      expect(reloaded!.messages.map((m) => m.content), [
        'old question',
        'old answer',
      ], reason: '原记录不得被副本覆盖');
      expect(container.read(aiChatProvider).activeSessionId, copy.id);
    });

    test('没有新副本时重复导入复用同一条本地记录', () async {
      final container = await makeContainer(
        capabilities: const {
          'loadSession': true,
          'sessionCapabilities': {'list': true},
        },
        configurePair: (pair) {
          pair.loadReplayUpdates = [
            {
              'sessionUpdate': 'user_message_chunk',
              'messageId': 'u1',
              'content': {'type': 'text', 'text': 'q'},
            },
          ];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await settle(container);

      await notifier.openRemoteSession(remote(remoteId));
      await settle(container);
      await notifier.openRemoteSession(remote(remoteId));
      await settle(container);

      expect(await stored(container), hasLength(1));
    });

    test('导入失败时保持旧记录，并给出可映射的错误码', () async {
      final container = await makeContainer(
        capabilities: const {'loadSession': true},
        configurePair: (pair) {
          pair.failSessionLoad = true;
          pair.failSessionResume = true;
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await settle(container);

      await expectLater(
        notifier.openRemoteSession(remote(remoteId)),
        throwsA(isA<StateError>()),
      );
      await settle(container);

      expect(
        container.read(aiChatProvider).lastErrorCode,
        startsWith('ACP_HISTORY_IMPORT_FAILED'),
      );
      final sessions = await stored(container);
      expect(
        sessions.single.historyImportIncomplete,
        isTrue,
        reason: '失败的导入必须留下不完整标记，禁止继续发送',
      );
    });

    test('serverId / agentId / launchKey 不匹配时直接拒绝', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await settle(container);

      await expectLater(
        notifier.openRemoteSession(
          AcpRemoteSession(
            id: remoteId,
            title: 'other server',
            workingDirectory: '/root',
            serverId: 'srv-9',
            agentId: agentId,
            launchKey: launchKey,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_TARGET_CHANGED',
          ),
        ),
      );
      await expectLater(
        notifier.openRemoteSession(
          AcpRemoteSession(
            id: remoteId,
            title: 'bad cwd',
            workingDirectory: 'relative',
            serverId: 'srv-1',
            agentId: agentId,
            launchKey: launchKey,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_WORKING_DIRECTORY_INVALID',
          ),
        ),
      );
      expect(pairs, isEmpty);
    });
  });

  group('恢复偏好', () {
    test('已有远端 id 的会话重连时走 load，不新建', () async {
      final second = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-1',
        name: 'agy',
        description: 'agy',
        cliCommand: 'cli',
        acpCommand: 'acp --stdio',
      );
      final container = await makeContainer(
        capabilities: const {'loadSession': true},
        profiles: [profile(), second],
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      final sessionId = container.read(aiChatProvider).activeSessionId!;

      // 切走再切回会重建 adapter，从而走恢复路径。
      notifier.switchAgent('builtin-agy');
      await settle(container);
      notifier.switchAgent('builtin-codex');
      await settle(container);
      await notifier.sendMessage('second');
      await settle(container);

      final loadPairs = pairs.where((pair) => pair.loadRequests.isNotEmpty);
      expect(loadPairs, isNotEmpty, reason: '重连必须优先恢复远端会话');
      expect(loadPairs.first.loadRequests, [remoteId]);
      final session = await container
          .read(chatRepositoryProvider)
          .loadSession(sessionId);
      expect(session!.contextFor(agentId).remoteSessionId, remoteId);
    });

    test('远端会话 id 也写入偏好存储，切换服务器不串号', () async {
      final container = await makeContainer();
      await container.read(aiChatProvider.notifier).sendMessage('hello');
      await settle(container);

      expect(storage.getAcpSessionId('srv-1', agentId), remoteId);
      expect(storage.getAcpSessionId('srv-2', agentId), isNull);
    });
  });
}

class _ReadyRegistry extends AgentRegistryNotifier {
  _ReadyRegistry(this._profiles);

  final List<AgentProfile> _profiles;

  void setProfiles(List<AgentProfile> profiles) {
    _profiles
      ..clear()
      ..addAll(profiles);
    // ignore: invalid_use_of_protected_member
    ref.invalidateSelf();
  }

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      for (final entry in _profiles)
        AgentRuntimeState(
          profile: entry,
          status: AgentEnvironmentStatus(
            kind: AgentEnvironmentStatusKind.ready,
            checkedAt: DateTime.utc(2026),
          ),
        ),
    ],
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

class _StaticConnection extends ServerConnectionNotifier {
  _StaticConnection(this.connected);

  final bool connected;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: connected ? 'srv-1' : null,
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
