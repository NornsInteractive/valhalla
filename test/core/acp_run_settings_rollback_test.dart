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
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// ACP `updateRunSettings` 的部分失败回滚与草稿持久化失败回归。
///
/// 复用 `test/core/independent_model_query_test.dart` 的同一套假 ACP 传输
/// 脚手架：全部通过内存传输对话，不建真实 SSH、不起真实进程、不碰远端账号。
const _agentId = 'builtin-codex';
const _remoteId = 'remote-codex-1';
const _legacyModel = 'legacy-model';
const _newModel = 'new-model';
const _storageFailure = 'STORAGE_WRITE_FAILED';

AgentProfile _profile() => AgentProfile(
  id: _agentId,
  serverId: 'srv-1',
  name: _agentId,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

class _ReadyRegistry extends AgentRegistryNotifier {
  _ReadyRegistry(this._profiles);

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

/// 与 `independent_model_query_test.dart` 相同的 SSH 管理器替身：
/// 继承真实管理器，只把 `getClient` 换成内存客户端。
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

/// 只让 `saveChatRunDefault` 失败的存储探针，其余读写全部走真实实现。
///
/// 从容器创建时就注入，绝不中途替换 storage provider。
class _FailingStorage extends LocalStorageService {
  _FailingStorage(super.prefs);

  int saveAttempts = 0;

  @override
  Future<void> saveChatRunDefault(
    String serverId,
    String agentId,
    ChatRunSettings settings,
  ) async {
    saveAttempts++;
    throw StateError(_storageFailure);
  }
}

Map<String, Object?> _modelSelect(List<String> values) => {
  'type': 'select',
  'id': 'model',
  'name': 'Model',
  'category': 'model',
  'currentValue': _legacyModel,
  'options': [
    for (final value in values) {'value': value, 'name': value},
  ],
};

Map<String, Object?> _levelSelect(List<String> values) => {
  'type': 'select',
  'id': 'thought_level',
  'name': 'Thought Level',
  'category': 'thought_level',
  'currentValue': 'low',
  'options': [
    for (final value in values) {'value': value, 'name': value},
  ],
};

AgentRuntimeCapabilities _catalog() => AgentRuntimeCapabilities(
  models: [
    for (final id in [_legacyModel, _newModel]) ChatSettingOption(id, id),
  ],
  reasoningLevels: [
    for (final id in ['low', 'high']) ChatSettingOption(id, id),
  ],
);

Future<void> _settle(ProviderContainer target) async {
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

void main() {
  test('草稿持久化失败：界面与本地默认保持原样，且不触碰远端', () async {
    final (container, notifier, storage) = await _container(
      configOptions: [
        _modelSelect([_legacyModel, _newModel]),
        _levelSelect(['low', 'high']),
      ],
      failStorageWrite: true,
    );
    await _settle(container);
    expect(
      container.read(aiChatProvider).activeSessionId,
      isNull,
      reason: '前提：还没有任何会话，只有草稿设置',
    );
    expect(_pairs, isEmpty, reason: '草稿写盘失败之前不该建立任何 ACP 传输');

    await expectLater(
      notifier.updateRunSettings(
        const ChatRunSettings(modelId: _newModel, reasoningId: 'high'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(_storageFailure),
        ),
      ),
    );
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(state.runSettings.modelId, _legacyModel, reason: '写盘失败的设置不得显示成生效状态');
    expect(state.runSettings.reasoningId, 'low');
    expect(state.isApplyingSettings, isFalse);
    expect(state.lastErrorCode, contains(_storageFailure));
    expect(
      storage.getChatRunDefault('srv-1', _agentId).modelId,
      _legacyModel,
      reason: '本地默认值必须保持旧版本',
    );
    expect(storage.getChatRunDefault('srv-1', _agentId).reasoningId, 'low');
    expect(
      (storage as _FailingStorage).saveAttempts,
      1,
      reason: '失败的草稿只该尝试一次，不反复重写',
    );
    expect(_pairs, isEmpty, reason: '草稿失败绝不能触发 ACP 传输，更别说把半成品下发到远端');
  });

  test('远端部分失败：已下发的模型被回滚，本地默认保持旧值', () async {
    final (container, notifier, storage) = await _ready(
      configOptions: [
        _modelSelect([_legacyModel, _newModel]),
        _levelSelect(['low', 'high']),
      ],
      configurePair: (pair) {
        // 模型接受，推理等级被拒绝：必须回滚模型，不能留着半套新设置。
        pair.failConfigOptionWhen = (configId, _) =>
            configId == 'thought_level';
        pair.setConfigOptionErrorCode = -32603;
      },
    );
    final pair = _pairs.single;

    await expectLater(
      notifier.updateRunSettings(
        const ChatRunSettings(modelId: _newModel, reasoningId: 'high'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ACP_SETTING_APPLY_FAILED'),
        ),
      ),
    );
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(state.runSettings.modelId, _legacyModel, reason: '失败后不得把新设置显示成生效状态');
    expect(state.runSettings.reasoningId, 'low');
    expect(state.settingsStale, isFalse, reason: '回滚成功就被协议确认过，不该标记陈旧');
    expect(state.isApplyingSettings, isFalse);
    expect(
      state.lastErrorCode,
      contains('ACP_SETTING_APPLY_FAILED'),
      reason: '失败原因必须如实上报',
    );
    expect(
      pair.setConfigOptionRequests
          .map((entry) => '${entry.configId}=${entry.value}')
          .toList(),
      ['model=$_newModel', 'thought_level=high', 'model=$_legacyModel'],
      reason: '已下发的模型必须被重新下发回旧值',
    );
    expect(
      storage.getChatRunDefault('srv-1', _agentId).modelId,
      _legacyModel,
      reason: '未被完整确认的设置绝不能落成本地默认值',
    );
    expect(storage.getChatRunDefault('srv-1', _agentId).reasoningId, 'low');
  });

  test('远端已更新但本地写盘失败：本地默认与远端一起回到旧值', () async {
    final (container, notifier, storage) = await _ready(
      configOptions: [
        _modelSelect([_legacyModel, _newModel]),
      ],
      failStorageWrite: true,
    );
    final pair = _pairs.single;

    await expectLater(
      notifier.updateRunSettings(const ChatRunSettings(modelId: _newModel)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(_storageFailure),
        ),
      ),
    );
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(
      state.runSettings.modelId,
      _legacyModel,
      reason: '本地持久化失败后不得把未落盘的设置留在界面',
    );
    expect(
      storage.getChatRunDefault('srv-1', _agentId).modelId,
      _legacyModel,
      reason: '失败的写盘绝不能留下新默认值',
    );
    expect(storage.getChatRunDefault('srv-1', _agentId).reasoningId, 'low');
    expect(
      pair.setConfigOptionRequests.map((entry) => entry.value).toList(),
      [_newModel, _legacyModel],
      reason: '远端已经被改过，必须被显式回滚',
    );
    expect(state.lastErrorCode, contains(_storageFailure));
    expect(state.isApplyingSettings, isFalse);
  });

  test('回滚失败：如实上报、标记陈旧并显示远端真实生效值', () async {
    final (container, notifier, storage) = await _ready(
      configOptions: [
        _modelSelect([_legacyModel, _newModel]),
        _levelSelect(['low', 'high']),
      ],
      configurePair: (pair) {
        // 推理被拒绝，且 agent 拒绝把模型改回 legacy-model。
        pair.failConfigOptionWhen = (configId, value) =>
            configId == 'thought_level' || value == _legacyModel;
        pair.setConfigOptionErrorCode = -32603;
      },
    );
    final pair = _pairs.single;

    await expectLater(
      notifier.updateRunSettings(
        const ChatRunSettings(modelId: _newModel, reasoningId: 'high'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ACP_SETTINGS_ROLLBACK_FAILED'),
        ),
      ),
    );
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(state.settingsStale, isTrue, reason: '回滚失败必须显式标记陈旧，不能假装已恢复');
    expect(state.lastErrorCode, contains('ACP_SETTINGS_ROLLBACK_FAILED'));
    expect(state.runSettings.modelId, _newModel, reason: '远端仍是新模型，界面必须显示真实生效值');
    expect(state.runSettings.reasoningId, 'low');
    expect(
      storage.getChatRunDefault('srv-1', _agentId).modelId,
      _legacyModel,
      reason: '未被协议确认的设置绝不能落成本地默认值',
    );
    expect(
      pair.setConfigOptionRequests
          .map((entry) => '${entry.configId}=${entry.value}')
          .toList(),
      ['model=$_newModel', 'thought_level=high', 'model=$_legacyModel'],
      reason: '回滚确实尝试过，只是被 agent 拒绝',
    );
  });

  test('成功路径：协议确认之后才持久化并更新界面', () async {
    final (container, notifier, storage) = await _ready(
      configOptions: [
        _modelSelect([_legacyModel, _newModel]),
        _levelSelect(['low', 'high']),
      ],
    );
    final pair = _pairs.single;

    await notifier.updateRunSettings(const ChatRunSettings(modelId: _newModel));
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(state.lastErrorCode, isNull);
    expect(state.settingsStale, isFalse);
    expect(state.isApplyingSettings, isFalse);
    expect(state.runSettings.modelId, _newModel, reason: '以 agent 回执为准，不做乐观确认');
    expect(state.runSettings.reasoningId, 'low');
    expect(pair.setConfigOptionRequests.map((entry) => entry.value).toList(), [
      _newModel,
    ]);
    expect(storage.getChatRunDefault('srv-1', _agentId).modelId, _newModel);
    expect(storage.getChatRunDefault('srv-1', _agentId).reasoningId, 'low');
  });
}

final List<FakeAcpPair> _pairs = [];

/// 建容器：存储替身只在创建时注入，运行中绝不替换 provider。
Future<(ProviderContainer, AiChatNotifier, LocalStorageService)> _container({
  required List<Map<String, Object?>> configOptions,
  ChatRunSettings seed = const ChatRunSettings(
    modelId: _legacyModel,
    reasoningId: 'low',
  ),
  void Function(FakeAcpPair pair)? configurePair,
  bool failStorageWrite = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final seeded = LocalStorageService(prefs);
  await seeded.saveChatRunDefault('srv-1', _agentId, seed);
  final storage = failStorageWrite ? _FailingStorage(prefs) : seeded;
  _pairs.clear();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      tempChatRepositoryOverride(),
      agentRegistryProvider.overrideWith(() => _ReadyRegistry([_profile()])),
      serverConnectionProvider.overrideWith(() => _StaticConnection(true)),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      agentModelQueryProvider.overrideWithValue(
        (profile, _) async => _catalog(),
      ),
      acpTransportFactoryProvider.overrideWithValue((_, _) async {
        final pair = FakeAcpPair(sessionId: _remoteId)
          ..configOptions = configOptions;
        configurePair?.call(pair);
        _pairs.add(pair);
        return pair.client;
      }),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() {
    for (final pair in _pairs) {
      pair.close();
    }
    _pairs.clear();
  });
  return (container, container.read(aiChatProvider.notifier), storage);
}

/// 建立一个已有远端会话的容器，并把目录刷新准备好。
Future<(ProviderContainer, AiChatNotifier, LocalStorageService)> _ready({
  required List<Map<String, Object?>> configOptions,
  void Function(FakeAcpPair pair)? configurePair,
  bool failStorageWrite = false,
}) async {
  final (container, notifier, storage) = await _container(
    configOptions: configOptions,
    configurePair: configurePair,
    failStorageWrite: failStorageWrite,
  );
  await notifier.sendMessage('first');
  await _settle(container);
  expect(await notifier.prepareRunSettings(), isTrue);
  await _settle(container);
  expect(
    _pairs.single.setConfigOptionRequests,
    isEmpty,
    reason: '前提：发送阶段没有改动过任何设置',
  );
  return (container, notifier, storage);
}
