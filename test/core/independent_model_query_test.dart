import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';
import 'package:valhalla/infrastructure/cli/codex_account_models.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// A stubbed independent catalog lookup for one agent profile.
typedef _CatalogQuery =
    Future<AgentRuntimeCapabilities?> Function(AgentProfile profile);

/// provider 层契约：模型目录只来自独立查询接口。
///
/// 覆盖：草稿/已存在会话刷新都不建会话、已建立的 ACP 传输不被重建、
/// 目录优先于过时的 session config 推送、不支持时显式报错、
/// 失败保留旧列表并标记 stale、切换目标后的迟到结果被丢弃，
/// 以及首次发送前对显式保存模型的独立校验。
void main() {
  const codexId = 'builtin-codex';
  const remoteId = 'remote-codex-1';

  late List<FakeAcpPair> pairs;
  late List<Map<String, Object?>> queries;
  late LocalStorageService storage;

  AgentProfile codex({String? cliCommand = 'codex'}) => AgentProfile(
    id: codexId,
    serverId: 'srv-1',
    name: codexId,
    description: 'codex',
    cliCommand: cliCommand ?? 'codex',
    acpCommand: 'acp --stdio',
  );

  AgentProfile other({String id = 'builtin-agy'}) => AgentProfile(
    id: id,
    serverId: 'srv-1',
    name: id,
    description: id,
    cliCommand: 'agy',
    acpCommand: 'agy-acp --stdio',
  );

  AgentProfile dockerCodex() => AgentProfile(
    id: codexId,
    serverId: 'srv-1',
    name: codexId,
    description: 'codex',
    cliCommand: 'codex',
    acpCommand: 'acp --stdio',
    executionTarget: 'docker',
    containerBinding: 'name',
    containerReference: 'codex-box',
    containerUser: '1000:1000',
  );

  AgentRuntimeCapabilities catalog(
    List<String> models, {
    List<String> reasoning = const [],
  }) => AgentRuntimeCapabilities(
    models: [for (final id in models) ChatSettingOption(id, id.toUpperCase())],
    reasoningLevels: [for (final id in reasoning) ChatSettingOption(id, id)],
  );

  Future<ProviderContainer> makeContainer({
    List<AgentProfile>? profiles,
    _CatalogQuery? query,
    ChatRunSettings runSettings = const ChatRunSettings(),
    List<Map<String, Object?>> configOptions = const [],
    Map<String, Object?> capabilities = const {},
    void Function(FakeAcpPair pair)? configurePair,
    Map<String, Object> prefs = const {},
    AgentComposerQuery? composerQuery,

    /// Re-opens over an existing storage instance, as a real app restart would.
    /// The persisted draft is *not* re-seeded, so it must survive on its own.
    LocalStorageService? reuseStorage,
  }) async {
    if (reuseStorage == null) {
      SharedPreferences.setMockInitialValues(prefs);
      storage = LocalStorageService(await SharedPreferences.getInstance());
      await storage.saveChatRunDefault('srv-1', codexId, runSettings);
    } else {
      storage = reuseStorage;
    }
    pairs = [];
    queries = [];
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(
          () => _ReadyRegistry(profiles ?? [codex()]),
        ),
        serverConnectionProvider.overrideWith(() => _StaticConnection(true)),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        agentModelQueryProvider.overrideWithValue((profile, _) async {
          queries.add({'agentId': profile.id, 'cli': profile.cliCommand});
          return query?.call(profile) ?? catalog(['gpt-5-codex']);
        }),
        agentComposerQueryProvider.overrideWithValue(
          composerQuery ?? (profile, ssh, cwd) async => const [],
        ),
        acpTransportFactoryProvider.overrideWithValue((_, _) async {
          final pair = FakeAcpPair(sessionId: remoteId)
            ..agentCapabilities = capabilities
            ..configOptions = configOptions;
          pairs.add(pair);
          configurePair?.call(pair);
          return pair.client;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
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

  /// Every request method the client sent to the agent, in order.
  List<String> sentMethods(FakeAcpPair pair) => pair.sentToAgent
      .map((line) => (jsonDecode(line) as Map<String, Object?>)['method'])
      .whereType<String>()
      .toList();

  String? frameMethod(String line) =>
      (jsonDecode(line) as Map<String, Object?>)['method'] as String?;

  Map<String, Object?>? frameParams(String line) =>
      (jsonDecode(line) as Map<String, Object?>)['params']
          as Map<String, Object?>?;

  /// Concatenated text of every `session/prompt` the client sent, in order.
  List<String> promptTexts(FakeAcpPair pair) => [
    for (final line in pair.sentToAgent)
      if (frameMethod(line) == 'session/prompt')
        [
          for (final block
              in ((frameParams(line)?['prompt'] ?? const []) as List)
                  .whereType<Map<String, Object?>>())
            if (block['text'] is String) block['text'] as String,
        ].join(),
  ];

  tearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });

  group('独立目录：不支持时显式失败且不回退会话', () {
    test('目录查询返回 null 时模型列表为空并给出可映射错误码', () async {
      final container = await makeContainer(query: (_) async => null);
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.capabilities.models, isEmpty);
      expect(state.settingsStale, isTrue);
      // 目录失败是独立字段，不能占用阻断设置/权限控件的错误位。
      expect(state.modelCatalogError, 'AGENT_MODEL_QUERY_UNSUPPORTED');
      expect(state.lastErrorCode, isNull);
      expect(
        sentMethods(pairs.single),
        isNot(contains('session/list')),
        reason: '不支持独立查询时不得回退到会话列举',
      );
      expect(pairs.single.newSessionCount, 0);
      expect(pairs.single.loadRequests, isEmpty);
      expect(pairs.single.resumeRequests, isEmpty);
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
    });

    test('不支持时仍可用默认设置发送，不阻断对话', () async {
      final container = await makeContainer(query: (_) async => null);
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await settle(container);

      await notifier.sendMessage('hello');
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.isGenerating, isFalse);
      expect(state.lastErrorCode, isNull);
      expect(
        sentMethods(pairs.single),
        contains('session/prompt'),
        reason: '目录不支持不能阻断对话',
      );
      expect(
        state.capabilities.models,
        isEmpty,
        reason: '失败目录不得回退到会话 config 的模型',
      );
    });
  });

  group('草稿刷新：只 initialize，不建会话', () {
    test('独立目录填满模型列表，且不触碰任何会话方法', () async {
      final container = await makeContainer(
        query: (_) async => catalog(['gpt-5-codex', 'gpt-5-codex-mini']),
      );
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.capabilities.models.map((option) => option.id), [
        'gpt-5-codex',
        'gpt-5-codex-mini',
      ]);
      expect(state.settingsStale, isFalse);
      expect(state.lastErrorCode, isNull);
      expect(state.activeSessionId, isNull);
      expect(pairs.single.newSessionCount, 0);
      expect(pairs.single.loadRequests, isEmpty);
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
    });

    test('刷新不会为已有会话补建远端会话', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(pairs.single.newSessionCount, 1);

      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      expect(pairs.single.newSessionCount, 1, reason: '刷新只重查目录，绝不新建远端会话');
      expect(pairs.single.loadRequests, isEmpty);
      expect(container.read(aiChatProvider).settingsStale, isFalse);
    });
  });

  group('目录优先于过时的 session config 推送', () {
    test('config 推送不得覆盖独立目录', () async {
      final container = await makeContainer(
        query: (_) async => catalog(['gpt-5-codex']),
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await settle(container);

      pairs.single.deliverConfigOptions([
        {
          'type': 'select',
          'id': 'model',
          'name': 'Model',
          'category': 'model',
          'currentValue': 'legacy-model',
          'options': [
            {'value': 'legacy-model', 'name': 'Legacy'},
          ],
        },
      ]);
      await pumpEventQueue();

      final state = container.read(aiChatProvider);
      expect(
        state.capabilities.models.map((option) => option.id),
        ['gpt-5-codex'],
        reason: 'session config 只能用于应用用户改动，不能用于发现',
      );
      expect(state.capabilities.currentModelId, 'legacy-model');
    });

    test('ACP 已公布的模型可以经 model config 应用给 agent', () async {
      final container = await makeContainer(
        // ACP 自己也公布了该模型，独立目录只负责发现。
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
              {'value': 'gpt-5-codex', 'name': 'GPT-5 Codex'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      // 用户显式改动才允许准备已有会话；刷新本身绝不建会话。
      await notifier.sendMessage('first');
      await settle(container);
      expect(pairs.single.setConfigOptionRequests, isEmpty);
      await notifier.prepareRunSettings();
      await settle(container);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'gpt-5-codex'),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.value),
        ['gpt-5-codex'],
        reason: 'ACP 已公布的模型必须可经 model config 应用',
      );
      expect(
        container.read(aiChatProvider).runSettings.modelId,
        'gpt-5-codex',
        reason: '以 agent 回执为准，不做乐观确认',
      );
    });

    test('ACP 未公布的模型不得发 set_config_option，显式报不支持', () async {
      final container = await makeContainer(
        // 目录里有 gpt-5-codex，但 ACP 只公布 legacy-model。
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      await notifier.prepareRunSettings();
      await settle(container);
      expect(pairs.single.setConfigOptionRequests, isEmpty);

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: 'gpt-5-codex'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER',
          ),
        ),
      );
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(
        pairs.single.setConfigOptionRequests,
        isEmpty,
        reason: 'adapter 未公布的模型绝不能下发 set_config_option',
      );
      expect(
        state.lastErrorCode,
        contains('ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER'),
      );
      expect(
        state.runSettings.modelId,
        'legacy-model',
        reason: '不支持时保持协议实际生效值，不做乐观确认',
      );
    });

    test('agent 拒绝该模型时不乐观确认', () async {
      final container = await makeContainer(
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
              {'value': 'gpt-5-codex', 'name': 'GPT-5 Codex'},
            ],
          },
        ],
        configurePair: (pair) => pair.rejectedConfigValues.add('gpt-5-codex'),
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      await notifier.prepareRunSettings();
      await settle(container);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'gpt-5-codex'),
      );
      await settle(container);

      expect(
        container.read(aiChatProvider).runSettings.modelId,
        'legacy-model',
        reason: 'agent 未接受时必须回落到实际生效值',
      );
    });
  });

  group('失败与 stale', () {
    test('查询失败时保留上一次的列表并标记过期', () async {
      var failNext = false;
      final container = await makeContainer(
        query: (_) async {
          if (failNext) throw StateError('model list unavailable');
          return catalog(['gpt-5-codex']);
        },
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.prepareRunSettings();
      await settle(container);
      expect(container.read(aiChatProvider).capabilities.models, hasLength(1));

      failNext = true;
      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(
        state.capabilities.models.map((option) => option.id),
        ['gpt-5-codex'],
        reason: '查询失败必须保留旧列表，而不是清空',
      );
      expect(state.settingsFetchedAt, isNotNull, reason: '失败时保留上一次 fetchedAt');
      expect(state.settingsStale, isTrue);
      // 目录失败单独记账，不占用阻断对话的 lastErrorCode。
      expect(state.modelCatalogError, contains('model list unavailable'));
      expect(state.lastErrorCode, isNull);
      expect(
        sentMethods(pairs.single),
        isNot(contains('session/prompt')),
        reason: '目录查询失败不得触发会话操作',
      );

      failNext = false;
      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      final recovered = container.read(aiChatProvider);
      expect(recovered.modelCatalogError, isNull, reason: '刷新成功后错误被清除');
      expect(recovered.settingsStale, isFalse);
      expect(recovered.settingsFetchedAt, isNotNull);
    });
  });

  group('目录缓存按账号键隔离', () {
    final keyA = 'a' * 64;
    final keyB = 'b' * 64;

    AgentRuntimeCapabilities keyed(List<String> models, String key) =>
        AgentRuntimeCapabilities(
          catalogAccountKey: key,
          models: [for (final id in models) ChatSettingOption(id, id)],
          supportsStructuredSettings: true,
        );

    test('成功查询写入不透明账号键并填充目录', () async {
      final container = await makeContainer(
        query: (_) async => keyed(['gpt-5-codex'], keyA),
      );
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.capabilities.models.single.id, 'gpt-5-codex');
      expect(state.settingsFetchedAt, isNotNull);
      expect(state.settingsStale, isFalse);
      expect(state.modelCatalogError, isNull);
      expect(pairs.single.newSessionCount, 0);
    });

    test('同账号的普通失败保留缓存与 fetchedAt 并标记 stale', () async {
      var failNext = false;
      final container = await makeContainer(
        query: (_) async {
          if (failNext) throw StateError('model list unavailable');
          return keyed(['gpt-5-codex'], keyA);
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await settle(container);
      expect(container.read(aiChatProvider).settingsFetchedAt, isNotNull);

      failNext = true;
      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.capabilities.models.single.id, 'gpt-5-codex');
      expect(state.settingsFetchedAt, isNotNull, reason: '同账号失败必须保留缓存时间戳');
      expect(state.settingsStale, isTrue);
      expect(state.modelCatalogError, contains('model list unavailable'));
    });

    test('换账号键的失败清空旧目录与 fetchedAt', () async {
      var switchAccount = false;
      final container = await makeContainer(
        query: (_) async {
          if (switchAccount) {
            throw ModelCatalogQueryException(
              'AGENT_MODEL_ACCOUNT_CATALOG_UNAVAILABLE',
              keyB,
            );
          }
          return keyed(['gpt-5-codex'], keyA);
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await settle(container);
      expect(container.read(aiChatProvider).capabilities.models, hasLength(1));

      switchAccount = true;
      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(state.capabilities.models, isEmpty, reason: '账号变了，旧目录必须作废');
      expect(state.settingsFetchedAt, isNull, reason: '账号变了，旧 fetchedAt 必须作废');
      expect(state.settingsStale, isTrue);
      expect(
        state.modelCatalogError,
        'AGENT_MODEL_ACCOUNT_CATALOG_UNAVAILABLE',
        reason: '只允许固定码，不得泄漏响应体',
      );
      expect(sentMethods(pairs.single), isNot(contains('session/new')));
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
    });

    test('账号不匹配与认证不可用同样清空旧目录', () async {
      for (final code in const [
        'AGENT_MODEL_ACCOUNT_MISMATCH',
        'AGENT_MODEL_AUTH_UNAVAILABLE',
      ]) {
        var failNext = false;
        final container = await makeContainer(
          query: (_) async {
            if (failNext) {
              throw ModelCatalogQueryException(code, keyA);
            }
            return keyed(['gpt-5-codex'], keyA);
          },
        );
        final notifier = container.read(aiChatProvider.notifier);
        await notifier.prepareRunSettings();
        await settle(container);
        expect(
          container.read(aiChatProvider).capabilities.models,
          hasLength(1),
          reason: code,
        );

        failNext = true;
        expect(await notifier.prepareRunSettings(refresh: true), isTrue);
        await settle(container);

        final state = container.read(aiChatProvider);
        expect(state.capabilities.models, isEmpty, reason: code);
        expect(state.settingsFetchedAt, isNull, reason: code);
        expect(state.settingsStale, isTrue);
        expect(state.modelCatalogError, code);

        for (final pair in pairs) {
          pair.close();
        }
        pairs = [];
      }
    });
  });

  group('迟到结果被丢弃', () {
    test('切换 Agent 之后返回的目录不写入状态', () async {
      final pending = Completer<AgentRuntimeCapabilities?>();
      final container = await makeContainer(
        profiles: [codex(), other()],
        query: (profile) async =>
            profile.id == codexId ? pending.future : catalog(['agy-model']),
      );
      final notifier = container.read(aiChatProvider.notifier);

      final preparing = notifier.prepareRunSettings();
      await pumpEventQueue();
      expect(queries, hasLength(1));

      notifier.switchAgent('builtin-agy');
      await settle(container);
      pending.complete(catalog(['gpt-5-codex']));
      expect(await preparing, isFalse);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(
        state.activeAgentProfile!.id,
        'builtin-agy',
        reason: '等待结果期间切换目标，界面必须停在新目标',
      );
      expect(state.capabilities.models, isEmpty, reason: '旧目标的目录结果必须被丢弃');
    });

    test('cliCommand 变化后同一 Agent 的旧目录不再复用', () async {
      final registry = _ReadyRegistry([codex()]);
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      pairs = [];
      queries = [];
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(() => registry),
          serverConnectionProvider.overrideWith(() => _StaticConnection(true)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          agentModelQueryProvider.overrideWithValue((profile, _) async {
            queries.add({'cli': profile.cliCommand});
            return catalog(['gpt-5-codex']);
          }),
          acpTransportFactoryProvider.overrideWithValue((_, _) async {
            final pair = FakeAcpPair(sessionId: remoteId);
            pairs.add(pair);
            return pair.client;
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.prepareRunSettings();
      await settle(container);
      expect(queries.single['cli'], 'codex');

      registry.setProfiles([codex(cliCommand: 'codex-next')]);
      await settle(container);
      await notifier.prepareRunSettings(refresh: true);
      await settle(container);

      expect(queries.last['cli'], 'codex-next', reason: '执行命令变化后必须按新目标重新查询');
    });
  });

  group('首次发送前的显式保存模型', () {
    test('发送前先用独立目录校验 ACP 公布的显式模型', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'gpt-5-codex'),
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
              {'value': 'gpt-5-codex', 'name': 'GPT-5 Codex'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.sendMessage('first');
      await settle(container);

      expect(queries, hasLength(1), reason: '显式保存模型必须在首次发送前独立校验');
      expect(pairs.single.setConfigOptionRequests.map((entry) => entry.value), [
        'gpt-5-codex',
      ]);
      expect(container.read(aiChatProvider).runSettings.modelId, 'gpt-5-codex');
      expect(container.read(aiChatProvider).modelCatalogError, isNull);
    });

    test('目录里有但 ACP 未公布的显式模型不发 RPC，显式报不支持', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'gpt-5-codex'),
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.sendMessage('first');
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(queries, hasLength(1), reason: '发送前仍先独立校验目录');
      expect(
        pairs.single.setConfigOptionRequests,
        isEmpty,
        reason: 'adapter 未公布的模型绝不能下发 set_config_option',
      );
      expect(
        state.lastErrorCode,
        contains('ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER'),
        reason: '必须显式报 adapter 不支持，而不是静默换模型',
      );
      expect(state.isGenerating, isFalse);
      expect(
        state.runSettings.modelId,
        isNot('gpt-5-codex'),
        reason: '未被协议确认的模型不得乐观写入 runSettings',
      );
    });

    test('独立 HTTP 失败时首次发送仍可用 ACP 公布的保存设置', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'legacy-model'),
        query: (_) async => throw StateError('model list unavailable'),
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'other-model',
            'options': [
              {'value': 'other-model', 'name': 'Other'},
              {'value': 'legacy-model', 'name': 'Legacy'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.sendMessage('first');
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(queries, hasLength(1));
      expect(
        state.modelCatalogError,
        contains('model list unavailable'),
        reason: 'HTTP 失败单独记账',
      );
      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.value),
        ['legacy-model'],
        reason: '目录不可用时仍可使用 ACP 自己公布的保存设置',
      );
      expect(
        state.runSettings.modelId,
        'legacy-model',
        reason: '不得凭空发明或静默降级模型',
      );
      expect(sentMethods(pairs.single), contains('session/prompt'));
    });

    test('目录里没有的显式模型被拒绝，不静默换模型', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'retired-model'),
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.sendMessage('first');
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(
        state.lastErrorCode,
        contains('ACP_SETTING_UNAVAILABLE'),
        reason: '显式模型不被支持时必须报错，不能悄悄用默认',
      );
      expect(state.isGenerating, isFalse);
    });

    test('已建立的 ACP 传输在刷新中被保留', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      final pair = pairs.single;

      expect(await notifier.prepareRunSettings(refresh: true), isTrue);
      await settle(container);

      expect(pairs, hasLength(1), reason: '刷新不得重建已建立的 ACP 连接');
      expect(pair.loadRequests, isEmpty, reason: '刷新不得 load 远端会话');
      expect(pair.newSessionCount, 1, reason: '刷新不得新建远端会话');
    });
  });

  group('真实应用仍以协议为准', () {
    test('agent 未接受模型时 runSettings 保持旧值', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'gpt-5-codex'),
        configurePair: (pair) => pair.ignoreSetConfigOption = true,
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'agent-current',
            'options': [
              {'value': 'agent-current', 'name': 'Agent current'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.sendMessage('first');
      await settle(container);

      expect(
        container.read(aiChatProvider).runSettings.modelId,
        'agent-current',
        reason: '独立目录列出不代表 adapter 支持或账号有权限',
      );
    });

    test('推理等级缺失时目录里的等级仍然可用', () async {
      final container = await makeContainer(
        query: (_) async =>
            catalog(['gpt-5-codex'], reasoning: ['low', 'high']),
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.prepareRunSettings();
      await settle(container);

      expect(
        container
            .read(aiChatProvider)
            .capabilities
            .reasoningLevels
            .map((option) => option.id),
        ['low', 'high'],
      );
    });
  });

  group('composer 目录：草稿只读发现', () {
    List<String> commandNames(ProviderContainer container) => container
        .read(aiChatProvider)
        .commands
        .map((command) => command.name)
        .toList();

    test('草稿发现带上 Docker 目标与 cwd，且不建会话不发 prompt', () async {
      final seen = <Map<String, Object?>>[];
      final container = await makeContainer(
        profiles: [dockerCodex()],
        composerQuery: (profile, ssh, cwd) async {
          seen.add({
            'agentId': profile.id,
            'cli': profile.cliCommand,
            'target': profile.executionTarget,
            'binding': profile.containerBinding,
            'reference': profile.containerReference,
            'user': profile.containerUser,
            'cwd': cwd,
          });
          return [const AcpSlashCommand(r'$deploy', 'Deploy', null)];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      notifier.setDraftWorkingDirectory('/workspace/app');
      await settle(container);

      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);

      expect(seen, hasLength(1));
      expect(seen.single, {
        'agentId': codexId,
        'cli': 'codex',
        'target': 'docker',
        'binding': 'name',
        'reference': 'codex-box',
        'user': '1000:1000',
        'cwd': '/workspace/app',
      });
      expect(commandNames(container), [r'$deploy']);
      expect(sentMethods(pairs.single), ['initialize']);
      expect(pairs.single.newSessionCount, 0);
      expect(pairs.single.loadRequests, isEmpty);
      expect(pairs.single.resumeRequests, isEmpty);
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
    });

    test(r'$skills 与协议命令合并，后续命令通知不得覆盖 $skills', () async {
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async => [
          const AcpSlashCommand(r'$deploy', 'Deploy', null),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);
      expect(commandNames(container), [r'$deploy']);

      pairs.single.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': remoteId,
            'update': {
              'sessionUpdate': 'available_commands_update',
              'availableCommands': [
                {'name': 'new_plan', 'description': 'Create a plan'},
              ],
            },
          },
        }),
      );
      await pumpEventQueue();

      final names = commandNames(container);
      expect(names, contains(r'$deploy'), reason: '后续通知不得丢掉 \$skills');
      expect(names, contains('new_plan'), reason: '协议命令同样保留');
      expect(
        names.indexOf(r'$deploy'),
        lessThan(names.indexOf('new_plan')),
        reason: r'$skills 永远排在协议命令之前',
      );
    });

    test('skills 查询失败不阻断普通发送', () async {
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async =>
            throw StateError('skills unavailable'),
      );
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareComposerCatalog(), isFalse);
      await settle(container);
      expect(
        container.read(aiChatProvider).lastErrorCode,
        contains('AGENT_COMPOSER_QUERY_FAILED'),
      );

      await notifier.sendMessage('hello');
      await settle(container);

      expect(sentMethods(pairs.single), contains('session/prompt'));
      expect(container.read(aiChatProvider).isGenerating, isFalse);
      expect(commandNames(container), isEmpty);
    });

    test('composer 与设置准备重叠时共用一条传输', () async {
      final gate = Completer<void>();
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async {
          await gate.future;
          return [const AcpSlashCommand(r'$deploy', 'Deploy', null)];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);

      final composer = notifier.prepareComposerCatalog();
      final settings = notifier.prepareRunSettings();
      await pumpEventQueue();
      expect(
        pairs,
        hasLength(1),
        reason: 'provider 层 _adapterFor 必须合并重叠的准备，而不是各开一条传输',
      );

      gate.complete();
      expect(await composer, isTrue);
      expect(await settings, isTrue);
      await settle(container);

      expect(pairs, hasLength(1));
      expect(sentMethods(pairs.single), ['initialize']);
      expect(commandNames(container), [r'$deploy']);
    });

    test('切换目标后迟到的 composer 结果不写入状态', () async {
      final pending = Completer<List<AcpSlashCommand>>();
      final container = await makeContainer(
        profiles: [codex(), other()],
        composerQuery: (profile, ssh, cwd) async => profile.id == codexId
            ? pending.future
            : [const AcpSlashCommand('/agy', 'Agent', null)],
      );
      final notifier = container.read(aiChatProvider.notifier);

      final preparing = notifier.prepareComposerCatalog();
      await pumpEventQueue();
      notifier.switchAgent('builtin-agy');
      await settle(container);

      pending.complete([const AcpSlashCommand(r'$stale', 'Stale', null)]);
      expect(await preparing, isFalse);
      await settle(container);

      expect(
        commandNames(container),
        isNot(contains(r'$stale')),
        reason: '等待期间切换目标，旧目标的 skills 必须被丢弃',
      );
      expect(
        container.read(aiChatProvider).activeAgentProfile!.id,
        'builtin-agy',
      );
    });
  });

  group('草稿命令预览：基线、菜单只读与首次斜杠命令', () {
    const codexAcp200 = <String, Object?>{
      'name': '@agentclientprotocol/codex-acp',
      'version': '2.0.0',
    };

    test('skills 查询失败保留 2.0.0 预览基线，成功后只清目录错误', () async {
      var failSkills = true;
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async {
          if (failSkills) throw StateError('skills unavailable');
          return [const AcpSlashCommand(r'$deploy', 'Deploy', null)];
        },
        configurePair: (pair) => pair.agentInfo = codexAcp200,
      );
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareComposerCatalog(), isFalse);
      await settle(container);
      var state = container.read(aiChatProvider);
      expect(state.lastErrorCode, contains('AGENT_COMPOSER_QUERY_FAILED'));
      final baseline = state.commands.map((command) => command.name).toList();
      expect(baseline, isNotEmpty, reason: '独立 skills 失败不得清掉预览基线');
      expect(
        state.commands.map((command) => command.isDraftPreview),
        everyElement(isTrue),
      );
      expect(sentMethods(pairs.single), ['initialize']);
      expect(pairs.single.newSessionCount, 0);

      failSkills = false;
      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);
      state = container.read(aiChatProvider);
      expect(
        state.lastErrorCode,
        isNull,
        reason: '成功重试只清掉自己那条 AGENT_COMPOSER_QUERY_FAILED',
      );
      expect(state.commands.map((command) => command.name), [
        r'$deploy',
        ...baseline,
      ]);
      expect(sentMethods(pairs.single), ['initialize']);
    });

    test('成功的目录发现不吞掉其他来源的错误', () async {
      final container = await makeContainer(
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'legacy-model'},
            ],
          },
        ],
        configurePair: (pair) => pair.ignoreSetConfigOption = true,
        composerQuery: (profile, ssh, cwd) async => [
          const AcpSlashCommand(r'$deploy', 'Deploy', null),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: 'my-manual-2026', customModel: true),
        ),
        throwsA(isA<StateError>()),
      );
      await settle(container);
      final unrelated = container.read(aiChatProvider).lastErrorCode;
      expect(unrelated, contains('ACP_CUSTOM_MODEL_NOT_CONFIRMED'));

      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);

      expect(
        container.read(aiChatProvider).lastErrorCode,
        unrelated,
        reason: '目录发现只能清自己那条 AGENT_COMPOSER_QUERY_FAILED',
      );
      expect(
        container.read(aiChatProvider).commands.map((command) => command.name),
        contains(r'$deploy'),
      );
    });

    test('菜单打开与刷新只发 initialize，不建会话也不读本地历史', () async {
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async => [
          const AcpSlashCommand(r'$deploy', 'Deploy', null),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);
      // 打开菜单之后再点一次刷新。
      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);

      final state = container.read(aiChatProvider);
      expect(sentMethods(pairs.single), ['initialize']);
      expect(pairs.single.newSessionCount, 0);
      expect(pairs.single.loadRequests, isEmpty);
      expect(pairs.single.resumeRequests, isEmpty);
      expect(pairs.single.listRequestCount, 0);
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
      expect(state.activeSessionId, isNull);
      expect(state.activeSession, isNull);
      expect(state.sessions, isEmpty, reason: '打开菜单不得写本地会话');
      expect(state.isLoadingSessions, isFalse);
      expect(state.isLoadingMessages, isFalse);
      expect(state.commands.map((command) => command.name), [r'$deploy']);
    });

    test('首次发送 /status 直接作为唯一 prompt，没有多余的普通轮次', () async {
      final container = await makeContainer(
        composerQuery: (profile, ssh, cwd) async => [
          const AcpSlashCommand(r'$deploy', 'Deploy', null),
        ],
        configurePair: (pair) => pair.agentInfo = codexAcp200,
      );
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);
      expect(
        container.read(aiChatProvider).commands.map((command) => command.name),
        contains('status'),
      );

      await notifier.sendMessage('/status ');
      await settle(container);

      expect(sentMethods(pairs.single), [
        'initialize',
        'session/new',
        'session/prompt',
      ]);
      expect(promptTexts(pairs.single), ['/status ']);
      final state = container.read(aiChatProvider);
      expect(state.lastErrorCode, isNull);
      expect(state.isGenerating, isFalse);
      expect(
        state.activeSession!.messages
            .where((message) => message.role.name == 'user')
            .map((message) => message.content),
        ['/status '],
        reason: '本地历史只有一条命令消息，没有先行的普通消息',
      );
    });

    test(r'首次发送 $deploy 技能同样直接执行', () async {
      final container = await makeContainer();
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareComposerCatalog(), isTrue);
      await settle(container);

      await notifier.sendMessage(r'$deploy ');
      await settle(container);

      expect(sentMethods(pairs.single), [
        'initialize',
        'session/new',
        'session/prompt',
      ]);
      expect(promptTexts(pairs.single), [r'$deploy ']);
      expect(container.read(aiChatProvider).lastErrorCode, isNull);
    });
  });

  group('默认 ACP 工厂使用 agentAcpLaunchCommand', () {
    AgentProfile launchProfile({String target = 'host'}) => AgentProfile(
      id: codexId,
      serverId: 'srv-1',
      name: codexId,
      description: 'codex',
      cliCommand: 'codex',
      acpCommand: 'codex-acp --stdio',
      executionTarget: target,
      containerBinding: 'name',
      containerReference: 'codex-box',
      containerUser: '1000:1000',
    );

    test('host profile 的启动命令与 helper 输出完全一致', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = _RecordingSession();
      final client = _RecordingSshClient(session);

      final transport = await container.read(acpTransportFactoryProvider)(
        launchProfile(),
        client,
      );
      final incoming = transport.incoming.listen((_) {});
      addTearDown(() async {
        await transport.close();
        await incoming.cancel();
      });

      expect(client.commands, [agentAcpLaunchCommand(launchProfile())]);
      expect(client.commands.single, startsWith('bash -l -c '));
      expect(client.commands.single, contains('type -P'));
      expect(client.commands.single, contains('exec codex-acp --stdio'));
      expect(transport, isA<AcpSshTransport>());
    });

    test('docker profile 的启动命令带容器与 user 路由', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = _RecordingSession();
      final client = _RecordingSshClient(session);

      final transport = await container.read(acpTransportFactoryProvider)(
        launchProfile(target: 'docker'),
        client,
      );
      final incoming = transport.incoming.listen((_) {});
      addTearDown(() async {
        await transport.close();
        await incoming.cancel();
      });

      expect(
        client.commands.single,
        agentAcpLaunchCommand(launchProfile(target: 'docker')),
      );
      expect(
        client.commands.single,
        startsWith(
          "docker exec -i --user '1000:1000' 'codex-box' /bin/sh -lc ",
        ),
      );
      expect(client.commands.single, isNot(contains('bash -l -c ')));
    });

    test('close 不等未订阅的 incoming：无监听也能关闭并保持幂等', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = _RecordingSession();
      final client = _RecordingSshClient(session);

      final transport = await container.read(acpTransportFactoryProvider)(
        launchProfile(),
        client,
      );
      expect(transport, isA<AcpSshTransport>());
      expect(client.commands, [agentAcpLaunchCommand(launchProfile())]);

      // _createAdapter can fail cwd/runtime preparation before initialize ever
      // subscribes to `incoming`; that close must not wait for a listener.
      await transport.close().timeout(const Duration(seconds: 5));
      expect(session.closed, isTrue, reason: '底层 SSH session 必须被关闭');

      await transport.close().timeout(const Duration(seconds: 5));
      expect(session.closed, isTrue, reason: '重复 close 必须幂等');
    });

    test('缺少 acpCommand 的默认工厂显式失败', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = _RecordingSshClient(_RecordingSession());

      await expectLater(
        container.read(acpTransportFactoryProvider)(
          AgentProfile(
            id: codexId,
            serverId: 'srv-1',
            name: codexId,
            description: 'codex',
            cliCommand: 'codex',
            executionTarget: 'host',
            containerBinding: 'id',
          ),
          client,
        ),
        throwsA(isA<StateError>()),
      );
      expect(client.commands, isEmpty);
    });
  });

  group('草稿更新设置只保存，不产生会话或 RPC', () {
    test('无活动会话时 updateRunSettings 不建会话也不发 set_config_option', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'legacy-model'),
        configOptions: [
          {
            'type': 'select',
            'id': 'model',
            'name': 'Model',
            'category': 'model',
            'currentValue': 'legacy-model',
            'options': [
              {'value': 'legacy-model', 'name': 'Legacy'},
              {'value': 'gpt-5-codex', 'name': 'GPT-5 Codex'},
            ],
          },
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);
      expect(container.read(aiChatProvider).activeSessionId, isNull);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'gpt-5-codex'),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests,
        isEmpty,
        reason: '草稿偏好只在首次发送时生效，绝不提前下发 RPC',
      );
      expect(sentMethods(pairs.single), isNot(contains('session/new')));
      expect(sentMethods(pairs.single), isNot(contains('session/prompt')));
      expect(pairs.single.newSessionCount, 0);
      expect(
        container.read(aiChatProvider).runSettings.modelId,
        'gpt-5-codex',
        reason: '草稿设置必须保存下来',
      );
    });
  });

  group('手动模型：只走声明的 model config RPC，不放宽其他校验', () {
    const manualId = 'my-manual-model-2026';

    Map<String, Object?> modelSelect(List<String> values) => {
      'type': 'select',
      'id': 'model',
      'name': 'Model',
      'category': 'model',
      'currentValue': 'legacy-model',
      'options': [
        for (final value in values) {'value': value, 'name': value},
      ],
    };

    Map<String, Object?> levelSelect(List<String> values) => {
      'type': 'select',
      'id': 'thought_level',
      'name': 'Thought Level',
      'category': 'thought_level',
      'currentValue': 'low',
      'options': [
        for (final value in values) {'value': value, 'name': value},
      ],
    };

    /// 建立一个已有远端会话的容器，并把目录刷新准备好。
    Future<(ProviderContainer, AiChatNotifier)> ready({
      required List<Map<String, Object?>> configOptions,
      void Function(FakeAcpPair pair)? configurePair,
    }) async {
      final container = await makeContainer(
        configOptions: configOptions,
        configurePair: configurePair,
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);
      expect(pairs.single.setConfigOptionRequests, isEmpty);
      return (container, notifier);
    }

    test('非法手动 ID显式拒绝，且不改写已保存的草稿', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(modelId: 'legacy-model'),
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      final invalid = <String>[
        '',
        ' ',
        'has space',
        'tab\there',
        'ctrl\x01model',
        'nbsp\u00a0model',
        'del\x7fmodel',
        'x' * 257,
      ];

      for (final id in invalid) {
        await expectLater(
          notifier.updateRunSettings(
            ChatRunSettings(modelId: id, customModel: true),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'ACP_CUSTOM_MODEL_INVALID',
            ),
          ),
          reason: '非法手动 ID 必须被拒绝：$id',
        );
      }

      final state = container.read(aiChatProvider);
      expect(state.runSettings.modelId, 'legacy-model');
      expect(state.runSettings.customModel, isFalse);
      expect(pairs.single.setConfigOptionRequests, isEmpty);
      expect(
        storage.getChatRunDefault('srv-1', codexId).modelId,
        'legacy-model',
        reason: '被拒绝的输入不得写入存储',
      );

      // 普通列表选择不走这条校验。
      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'legacy-model'),
      );
      await settle(container);
      expect(
        container.read(aiChatProvider).runSettings.modelId,
        'legacy-model',
      );
    });

    test('草稿手动模型只保存不发 RPC，重开容器后仍生效且不伪造目录', () async {
      final container = await makeContainer(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);
      final draftPair = pairs.single;
      addTearDown(draftPair.close);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'manual-draft', customModel: true),
      );
      await settle(container);

      expect(
        draftPair.setConfigOptionRequests,
        isEmpty,
        reason: '草稿绝不提前下发 RPC',
      );
      expect(sentMethods(draftPair), isNot(contains('session/new')));
      expect(sentMethods(draftPair), isNot(contains('session/prompt')));

      final persisted = storage.getChatRunDefault('srv-1', codexId);
      expect(persisted.modelId, 'manual-draft');
      expect(persisted.customModel, isTrue, reason: '手动态必须随草稿一起持久化');

      // 重开：全新容器只共享同一份存储，不重新播种。
      final reopened = await makeContainer(
        reuseStorage: storage,
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );
      final restored = reopened.read(aiChatProvider);
      expect(restored.runSettings.modelId, 'manual-draft');
      expect(
        restored.runSettings.customModel,
        isTrue,
        reason: '重开后手动态与手动 ID 都必须还在',
      );

      final second = reopened.read(aiChatProvider.notifier);
      await second.sendMessage('hello');
      await settle(reopened);

      final state = reopened.read(aiChatProvider);
      expect(
        state.capabilities.models.map((option) => option.id),
        isNot(contains('manual-draft')),
        reason: '绝不把手动 ID 伪造成目录条目',
      );
      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.value),
        ['manual-draft'],
        reason: '未列出的手动 ID 首次发送仍经声明的 model config RPC 下发',
      );
      expect(state.runSettings.modelId, 'manual-draft');
      expect(state.runSettings.customModel, isTrue);
    });

    test('未列出的显式模型只发这一条 model config RPC 并要求精确回执', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: manualId, customModel: true),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests,
        [(configId: 'model', value: manualId)],
        reason: '只允许声明的 model config 选项，且只发这一条',
      );
      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.configId),
        ['model'],
        reason: '手动态只放宽 model 这一类',
      );

      final confirmed = container.read(aiChatProvider).runSettings;
      expect(confirmed.modelId, manualId, reason: '以 agent 精确回执为准');
      expect(confirmed.customModel, isTrue);
      expect(
        storage.getChatRunDefault('srv-1', codexId).modelId,
        manualId,
        reason: '确认后同样持久化',
      );
    });

    test('agent 不回显精确值时报未确认，绝不乐观写入', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
        configurePair: (pair) => pair.ignoreSetConfigOption = true,
      );

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: manualId, customModel: true),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_CUSTOM_MODEL_NOT_CONFIRMED',
          ),
        ),
      );
      await settle(container);

      expect(pairs.single.setConfigOptionRequests, hasLength(1));
      final state = container.read(aiChatProvider);
      expect(
        state.runSettings.modelId,
        isNot(manualId),
        reason: '未被精确确认的手动 ID 不得写入 runSettings',
      );
      expect(state.lastErrorCode, contains('ACP_CUSTOM_MODEL_NOT_CONFIRMED'));
    });

    test('agent 拒绝该手动值时同样报未确认', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
        configurePair: (pair) => pair.rejectedConfigValues.add(manualId),
      );

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: manualId, customModel: true),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_CUSTOM_MODEL_NOT_CONFIRMED',
          ),
        ),
      );
      await settle(container);

      expect(pairs.single.setConfigOptionRequests, hasLength(1));
      expect(
        container.read(aiChatProvider).runSettings.modelId,
        isNot(manualId),
      );
    });

    test('RPC 本身失败时按配置失败上报，不吞掉错误', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
        configurePair: (pair) {
          pair.failSetConfigOption = true;
          pair.setConfigOptionErrorCode = -32603;
        },
      );

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: manualId, customModel: true),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            startsWith('ACP_SETTING_APPLY_FAILED: model'),
          ),
        ),
      );
      await settle(container);

      expect(pairs.single.setConfigOptionRequests, hasLength(1));
      final state = container.read(aiChatProvider);
      expect(state.runSettings.modelId, isNot(manualId));
      expect(state.lastErrorCode, contains('ACP_SETTING_APPLY_FAILED'));
    });

    test('没有 model 设置 API 时显式报不可用', () async {
      final (container, notifier) = await ready(configOptions: const []);

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: manualId, customModel: true),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_SETTING_UNAVAILABLE: model',
          ),
        ),
      );
      await settle(container);

      expect(pairs.single.setConfigOptionRequests, isEmpty);
      expect(
        container.read(aiChatProvider).runSettings.modelId,
        isNot(manualId),
      );
    });

    test('手动模型不放宽推理选择校验', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
          levelSelect(['low']),
        ],
      );

      // 模型变更时，非法推理值绝不能被捎带下发。
      await notifier.updateRunSettings(
        const ChatRunSettings(
          modelId: manualId,
          customModel: true,
          reasoningId: 'not-a-level',
        ),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.configId),
        ['model'],
        reason: '非法推理值绝不下发 thought_level RPC，手动态不能绕过选择校验',
      );
      var confirmed = container.read(aiChatProvider).runSettings;
      expect(confirmed.modelId, manualId);
      expect(
        confirmed.reasoningId,
        isNot('not-a-level'),
        reason: '协议未确认的推理值不得被手动态保留',
      );
      expect(confirmed.reasoningId, 'low', reason: '回落到协议实际生效值');

      // 模型不变时，非法推理值必须照常被拒绝。
      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(
            modelId: manualId,
            customModel: true,
            reasoningId: 'not-a-level',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_SETTING_UNAVAILABLE: thought_level',
          ),
        ),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests.where(
          (entry) => entry.configId == 'thought_level',
        ),
        isEmpty,
      );
      confirmed = container.read(aiChatProvider).runSettings;
      expect(confirmed.modelId, manualId);
      expect(confirmed.reasoningId, 'low');
    });

    test('手动模型不改变权限策略', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(
          permissionPolicy: OperationPermissionPolicy.autoAllowAll,
        ),
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      await notifier.updateRunSettings(
        const ChatRunSettings(
          modelId: manualId,
          customModel: true,
          permissionPolicy: OperationPermissionPolicy.askEveryTime,
        ),
      );
      await settle(container);

      final confirmed = container.read(aiChatProvider).runSettings;
      expect(confirmed.modelId, manualId);
      expect(
        confirmed.permissionPolicy,
        OperationPermissionPolicy.askEveryTime,
        reason: '手动态不得把权限策略升级成 autoAllowAll',
      );
      expect(
        storage.getChatRunDefault('srv-1', codexId).permissionPolicy,
        OperationPermissionPolicy.askEveryTime,
      );
    });

    test('普通列表选择的过时模型仍然被拒，且不发 RPC', () async {
      final (container, notifier) = await ready(
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );

      await expectLater(
        notifier.updateRunSettings(
          const ChatRunSettings(modelId: 'retired-model'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER',
          ),
        ),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests,
        isEmpty,
        reason: '普通列表选择的过时模型绝不能下发 set_config_option',
      );
      final state = container.read(aiChatProvider);
      expect(state.runSettings.modelId, isNot('retired-model'));
      expect(
        state.lastErrorCode,
        contains('ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER'),
      );
    });

    test('首次发送：session/new 的初始 config 通知不得抹掉已确认的手动模型', () async {
      final container = await makeContainer(
        runSettings: const ChatRunSettings(
          modelId: manualId,
          customModel: true,
        ),
        configOptions: [
          modelSelect(['legacy-model']),
        ],
      );
      final notifier = container.read(aiChatProvider.notifier);

      // 只有首次发送才会建会话，并按保存的草稿下发声明的 model config RPC。
      final send = notifier.sendMessage('first');
      await pumpEventQueue();
      // 初始 config 通知可能在发送过程中就到达。
      if (pairs.isNotEmpty) {
        pairs.single.deliverConfigOptions([
          modelSelect(['legacy-model', manualId]),
        ]);
      }
      await send;
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests,
        [(configId: 'model', value: manualId)],
        reason: '草稿手动态必须经声明的 model config RPC 首发',
      );
      var state = container.read(aiChatProvider);
      expect(state.runSettings.modelId, manualId);
      expect(state.runSettings.customModel, isTrue);

      // 精确回执之后，agent 再推送它自己的当前状态。
      pairs.single.deliverConfigOptions([
        {
          ...modelSelect(['legacy-model', manualId]),
          'currentValue': manualId,
        },
      ]);
      await pumpEventQueue();

      state = container.read(aiChatProvider);
      expect(state.runSettings.modelId, manualId);
      expect(
        state.runSettings.customModel,
        isTrue,
        reason: 'session/new 的初始 config 通知不得抹掉已确认的手动模型意图',
      );
      expect(
        state.capabilities.models.map((option) => option.id),
        isNot(contains(manualId)),
        reason: '绝不把手动 ID 伪造成目录条目',
      );
      expect(
        storage.getChatRunDefault('srv-1', codexId).customModel,
        isTrue,
        reason: '手动态必须随草稿持久化',
      );
      expect(sentMethods(pairs.single), contains('session/prompt'));
      expect(sentMethods(pairs.single), isNot(contains('session/list')));
    });
  });

  group('先模型后推理，并按更新后的选项过滤', () {
    Map<String, Object?> select(
      String id,
      String category,
      String current,
      List<String> values,
    ) => {
      'type': 'select',
      'id': id,
      'name': id,
      'category': category,
      'currentValue': current,
      'options': [
        for (final value in values) {'value': value, 'name': value},
      ],
    };

    /// 只有 model 变更才允许重建模型选项；推理变更必须保留当前生效的模型。
    Map<String, Object?> modelAfter(
      String id,
      Object? value,
      List<Map<String, Object?>> current,
      List<String> values,
    ) => select(
      'model',
      'model',
      id == 'model'
          ? value as String
          : current
                .firstWhere((option) => option['id'] == 'model')['currentValue']
                .toString(),
      values,
    );

    test('模型与推理按顺序下发，推理在模型之后', () async {
      final container = await makeContainer(
        configOptions: [
          select('model', 'model', 'model-a', ['model-a', 'model-b']),
          select('thought_level', 'thought_level', 'low', ['low', 'high']),
        ],
        configurePair: (pair) {
          pair.configOptionsAfterChange = (id, value, current) => [
            modelAfter(id, value, current, ['model-a', 'model-b']),
            select('thought_level', 'thought_level', 'low', ['low', 'high']),
          ];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'model-b', reasoningId: 'high'),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.configId),
        ['model', 'thought_level'],
        reason: '模型必须先被协议确认，再下发推理',
      );
      final confirmed = container.read(aiChatProvider).runSettings;
      expect(confirmed.modelId, 'model-b', reason: '以 agent 回执为准');
      expect(confirmed.reasoningId, 'high', reason: '推理在模型之后确认');
    });

    test('模型换掉推理选项后，过期的推理值不再下发', () async {
      final container = await makeContainer(
        configOptions: [
          select('model', 'model', 'model-a', ['model-a', 'model-b']),
          select('thought_level', 'thought_level', 'low', ['low', 'high']),
        ],
        configurePair: (pair) {
          // model-b 只支持 low：模型变更必须让 client 重新过滤推理选择。
          pair.configOptionsAfterChange = (id, value, current) => [
            modelAfter(id, value, current, ['model-a', 'model-b']),
            select('thought_level', 'thought_level', 'low', ['low']),
          ];
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      await notifier.sendMessage('first');
      await settle(container);
      expect(await notifier.prepareRunSettings(), isTrue);
      await settle(container);

      await notifier.updateRunSettings(
        const ChatRunSettings(modelId: 'model-b', reasoningId: 'high'),
      );
      await settle(container);

      expect(
        pairs.single.setConfigOptionRequests.map((entry) => entry.configId),
        ['model'],
        reason: '更新后的选项里没有 high，绝不能把过期推理发下去',
      );
      expect(
        container.read(aiChatProvider).runSettings.reasoningId,
        'low',
        reason: '回落到协议实际生效的推理等级',
      );
    });
  });

  group('目录之外的持久化与隔离', () {
    test('不同 Agent 的查询分别使用各自的执行命令', () async {
      final container = await makeContainer(
        profiles: [codex(), other()],
        query: (profile) async => catalog(['${profile.cliCommand}-model']),
      );
      final notifier = container.read(aiChatProvider.notifier);

      await notifier.prepareRunSettings();
      await settle(container);
      expect(
        container.read(aiChatProvider).capabilities.models.single.id,
        'codex-model',
      );

      notifier.switchAgent('builtin-agy');
      await settle(container);
      await notifier.prepareRunSettings();
      await settle(container);

      expect(
        container.read(aiChatProvider).capabilities.models.single.id,
        'agy-model',
      );
      expect(queries.map((entry) => entry['cli']), ['codex', 'agy']);
    });

    test('默认实现只对 Codex 走独立查询，其他返回 null', () async {
      // 未覆盖 agentModelQueryProvider 的真实默认值。
      SharedPreferences.setMockInitialValues({});
      final defaults = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(defaults),
          tempChatRepositoryOverride(),
          agentRegistryProvider.overrideWith(
            () => _ReadyRegistry([codex(), other()]),
          ),
          serverConnectionProvider.overrideWith(() => _StaticConnection(true)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(defaults)),
        ],
      );
      addTearDown(container.dispose);

      final query = container.read(agentModelQueryProvider);
      // 只验证分类判定，不触碰真实 SSH：非 Codex 必须在触碰网络前返回 null。
      expect(await query(other(), _FakeSshClient()), isNull);
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

/// SSH session stub with inert streams, enough for [AcpSshTransport] to attach
/// without touching a real connection.
class _RecordingSession implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = StreamController<Uint8List>.broadcast();

  bool closed = false;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  int? get exitCode => null;

  @override
  Future<void> get done => Future<void>.value();

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_stdin.isClosed) _stdin.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// SSH client stub that records every command it was asked to execute.
class _RecordingSshClient implements SSHClient {
  _RecordingSshClient(this.session);

  final SSHSession session;
  final List<String> commands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    return Future<SSHSession>.value(session);
  }

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
