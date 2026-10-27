import 'dart:async';
import 'dart:io';

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
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';

/// `updateRunSettings` 在收养已完成的 background run 时，必须先固化发起
/// 目标；detach/checkpoint 期间切换 server/agent/session 后，旧的设置
/// 绝不能再落到新目标上。
///
/// 全部走内存 ACP 传输与临时 SQLite：不建真实 SSH、不起真实进程、
/// 不读写任何远端账号。
const _agentA = 'builtin-codex';
const _agentB = 'builtin-agy';
const _agentSrv2 = 'builtin-codex-s2';
const _remoteId = 'remote-codex-1';
const _legacyModel = 'legacy-model';
const _newModel = 'new-model';
const _saveFailure = 'CHECKPOINT_SAVE_FAILED';

const _capabilities = {
  'loadSession': true,
  'sessionCapabilities': {'list': true, 'resume': <String, Object?>{}},
};

AgentProfile _profile(String id, {String serverId = 'srv-1'}) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
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
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

const _serverOne = ServerProfile(
  id: 'srv-1',
  name: 'first server',
  host: 'a.example.test',
  username: 'root',
);

const _serverTwo = ServerProfile(
  id: 'srv-2',
  name: 'second server',
  host: 'b.example.test',
  username: 'root',
);

class _SwitchableActiveServer extends ActiveServerNotifier {
  ServerProfile? _server = _serverOne;

  @override
  ServerProfile? build() => _server;

  void switchTo(ServerProfile server) {
    _server = server;
    state = server;
  }
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

/// 记录每一次草稿默认值写入，其余读写全部走真实实现。
class _RecordingStorage extends LocalStorageService {
  _RecordingStorage(super.prefs);

  final List<({String serverId, String agentId, ChatRunSettings settings})>
  defaultWrites = [];

  @override
  Future<void> saveChatRunDefault(
    String serverId,
    String agentId,
    ChatRunSettings settings,
  ) {
    defaultWrites.add((
      serverId: serverId,
      agentId: agentId,
      settings: settings,
    ));
    return super.saveChatRunDefault(serverId, agentId, settings);
  }
}

/// 可以把某一次 `saveSession` 挂住（或挂住后失败）的临时库。
///
/// 用来把 background run 的 detach/checkpoint 拉长，从而在 await 内部
/// 切换目标；其余读写仍走真实 SQLite 实现。
class _GatedRepository extends ChatRepository {
  _GatedRepository(super.storage, {required super.databasePath});

  bool holdNextSave = false;
  bool failAfterGate = false;
  Completer<void>? gate;
  final Completer<void> saveEntered = Completer<void>();

  @override
  Future<void> saveSession(ChatSession session) async {
    if (holdNextSave) {
      holdNextSave = false;
      if (!saveEntered.isCompleted) saveEntered.complete();
      await gate!.future;
      if (failAfterGate) {
        throw StateError(_saveFailure);
      }
    }
    return super.saveSession(session);
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

AgentRuntimeCapabilities _catalog() => AgentRuntimeCapabilities(
  models: [
    for (final id in [_legacyModel, _newModel]) ChatSettingOption(id, id),
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

Future<FakeAcpPair> _awaitNextPromptedPair(
  List<FakeAcpPair> pairs,
  int previousCount,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (pairs.length <= previousCount) {
    if (DateTime.now().isAfter(deadline)) {
      fail('adapter never created the next transport');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final pair = pairs[previousCount];
  await pair.promptReceived.timeout(const Duration(seconds: 5));
  return pair;
}

/// 一个已经停在 background、并且已完成的 run，当前视图已切回它。
class _FinishedRunScenario {
  _FinishedRunScenario({
    required this.container,
    required this.notifier,
    required this.storage,
    required this.repository,
    required this.pair,
    required this.sessionId,
    required this.catalogQueries,
  });

  final ProviderContainer container;
  final AiChatNotifier notifier;
  final _RecordingStorage storage;
  final _GatedRepository repository;
  final FakeAcpPair pair;
  final String sessionId;

  /// 每次模型目录查询的目标 Agent，用来证明陈旧调用没有落到新目标。
  final List<String> catalogQueries;
}

Future<_FinishedRunScenario> _finishedBackgroundRun() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = _RecordingStorage(prefs);
  await storage.saveChatRunDefault(
    'srv-1',
    _agentA,
    const ChatRunSettings(modelId: _legacyModel),
  );

  final dir = Directory.systemTemp.createTempSync('valhalla_chat_test_');
  addTearDown(() async {
    if (!dir.existsSync()) return;
    for (var attempt = 0; ; attempt++) {
      try {
        await dir.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 39 || attempt >= 4) rethrow;
      }
    }
  });
  final repository = _GatedRepository(
    storage,
    databasePath: '${dir.path}/chat.sqlite3',
  );

  final pairs = <FakeAcpPair>[];
  final catalogQueries = <String>[];
  final activeServer = _SwitchableActiveServer();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      chatRepositoryProvider.overrideWithValue(repository),
      agentRegistryProvider.overrideWith(
        () => _ReadyRegistry([
          _profile(_agentA),
          _profile(_agentB),
          // 让切到 srv-2 后仍有一个就绪 Agent，否则“不写新 server”会因为
          // 没有 agent 而天然成立，测不出守卫。
          _profile(_agentSrv2, serverId: 'srv-2'),
        ]),
      ),
      serverConnectionProvider.overrideWith(_StaticConnection.new),
      activeServerProvider.overrideWith(() => activeServer),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      agentModelQueryProvider.overrideWithValue((profile, _) async {
        catalogQueries.add(profile.id);
        return _catalog();
      }),
      acpTransportFactoryProvider.overrideWithValue((
        _,
        _, {
        String? initialModelId,
      }) async {
        final pair = FakeAcpPair(sessionId: _remoteId)
          ..agentCapabilities = _capabilities
          ..configOptions = [
            _modelSelect([_legacyModel, _newModel]),
          ]
          ..holdPrompt = true;
        pairs.add(pair);
        return pair.client;
      }),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });

  final notifier = container.read(aiChatProvider.notifier);
  await _settle(container);

  final previousCount = pairs.length;
  final turn = notifier.sendMessage('first');
  final pair = await _awaitNextPromptedPair(pairs, previousCount);
  final sessionId = container.read(aiChatProvider).activeSessionId!;

  // 把正在跑的 turn 停到 background。
  await notifier.switchAgent(_agentB);
  await _settle(container);
  expect(
    container.read(aiChatProvider).serverRun?.isBusy,
    isTrue,
    reason: '前提：background run 仍在进行中',
  );

  // 结束它，但先不收养。
  pair.finishHeldPrompt();
  await turn.timeout(const Duration(seconds: 5));
  await pumpEventQueue();
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // 回到原目标并选中这个会话，使 run 满足“可收养”条件。
  await notifier.switchAgent(_agentA);
  await _settle(container);
  await notifier.selectSession(sessionId);
  await _settle(container);

  final state = container.read(aiChatProvider);
  expect(state.activeSessionId, sessionId);
  expect(state.activeAgentProfile?.id, _agentA);
  expect(
    state.serverRun?.isBusy,
    isNot(true),
    reason: '前提：run 已完成，才能进入 _adoptFinishedRun 的 detach',
  );

  // 只观察本轮 updateRunSettings 的写入。
  storage.defaultWrites.clear();
  repository.saveEntered.future.ignore();

  return _FinishedRunScenario(
    container: container,
    notifier: notifier,
    storage: storage,
    repository: repository,
    pair: pair,
    sessionId: sessionId,
    catalogQueries: catalogQueries,
  );
}

void _armCheckpointGate(_FinishedRunScenario scenario, {bool fail = false}) {
  scenario.repository.gate = Completer<void>();
  scenario.repository.failAfterGate = fail;
  scenario.repository.holdNextSave = true;
}

void _expectNothingWrittenFor(
  _FinishedRunScenario scenario,
  String serverId,
  String agentId,
) {
  expect(
    scenario.storage.defaultWrites.where(
      (write) => write.serverId == serverId && write.agentId == agentId,
    ),
    isEmpty,
    reason: '陈旧的成功/失败都不能把设置写到新目标 $serverId/$agentId',
  );
}

void main() {
  test('checkpoint 等待期间切换 Agent：陈旧成功被丢弃，不写新目标', () async {
    final scenario = await _finishedBackgroundRun();
    _armCheckpointGate(scenario);

    final applying = scenario.notifier.updateRunSettings(
      const ChatRunSettings(modelId: _newModel),
    );
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );

    // detach/checkpoint 还挂起时，用户切到另一个 Agent。
    await scenario.notifier.switchAgent(_agentB);
    await _settle(scenario.container);

    scenario.repository.gate!.complete();
    await applying.timeout(const Duration(seconds: 5));
    await _settle(scenario.container);

    expect(scenario.storage.defaultWrites, isEmpty);
    expect(
      scenario.container.read(aiChatProvider).runSettings.modelId,
      _legacyModel,
      reason: '旧目标发起的新设置不得显示到新目标',
    );
    expect(scenario.container.read(aiChatProvider).isApplyingSettings, isFalse);
    expect(scenario.container.read(aiChatProvider).lastErrorCode, isNull);
  });

  test('checkpoint 等待期间切换 server：陈旧成功被丢弃，不写新 server', () async {
    final scenario = await _finishedBackgroundRun();
    _armCheckpointGate(scenario);

    final applying = scenario.notifier.updateRunSettings(
      const ChatRunSettings(modelId: _newModel),
    );
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );

    (scenario.container.read(activeServerProvider.notifier)
            as _SwitchableActiveServer)
        .switchTo(_serverTwo);
    await _settle(scenario.container);

    scenario.repository.gate!.complete();
    await applying.timeout(const Duration(seconds: 5));
    await _settle(scenario.container);

    _expectNothingWrittenFor(scenario, _serverTwo.id, _agentSrv2);
    expect(scenario.storage.defaultWrites, isEmpty);
    expect(scenario.container.read(aiChatProvider).lastErrorCode, isNull);
  });

  test('checkpoint 等待期间切换 session：陈旧成功被丢弃，不写新草稿', () async {
    final scenario = await _finishedBackgroundRun();
    _armCheckpointGate(scenario);

    final applying = scenario.notifier.updateRunSettings(
      const ChatRunSettings(modelId: _newModel),
    );
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );

    await scenario.notifier.createNewSession();
    await _settle(scenario.container);
    expect(scenario.container.read(aiChatProvider).activeSessionId, isNull);

    scenario.repository.gate!.complete();
    await applying.timeout(const Duration(seconds: 5));
    await _settle(scenario.container);

    expect(scenario.storage.defaultWrites, isEmpty);
    expect(scenario.container.read(aiChatProvider).lastErrorCode, isNull);
  });

  test('checkpoint 失败且目标已切换：陈旧错误被吞掉，不污染新目标', () async {
    final scenario = await _finishedBackgroundRun();
    _armCheckpointGate(scenario, fail: true);

    final applying = scenario.notifier.updateRunSettings(
      const ChatRunSettings(modelId: _newModel),
    );
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );

    await scenario.notifier.switchAgent(_agentB);
    await _settle(scenario.container);

    scenario.repository.gate!.complete();
    await applying.timeout(const Duration(seconds: 5));
    await _settle(scenario.container);

    expect(scenario.storage.defaultWrites, isEmpty);
    final state = scenario.container.read(aiChatProvider);
    expect(state.lastErrorCode, isNull, reason: '旧目标的 checkpoint 失败不能显示到新目标');
    expect(state.isApplyingSettings, isFalse);
  });

  test(
    'prepareRunSettings 等待 checkpoint 时切换 server：返回 false 且不查询新目录',
    () async {
      final scenario = await _finishedBackgroundRun();
      final catalogBefore = List<String>.of(scenario.catalogQueries);
      _armCheckpointGate(scenario);

      final preparing = scenario.notifier.prepareRunSettings();
      await scenario.repository.saveEntered.future.timeout(
        const Duration(seconds: 5),
      );

      (scenario.container.read(activeServerProvider.notifier)
              as _SwitchableActiveServer)
          .switchTo(_serverTwo);
      await _settle(scenario.container);

      scenario.repository.gate!.complete();
      expect(await preparing.timeout(const Duration(seconds: 5)), isFalse);
      await _settle(scenario.container);

      final state = scenario.container.read(aiChatProvider);
      expect(scenario.storage.defaultWrites, isEmpty);
      expect(state.lastErrorCode, isNull);
      expect(state.isLoadingSettings, isFalse);
      expect(
        scenario.catalogQueries,
        catalogBefore,
        reason: '旧目标的初始化不得为新 server 触发模型目录查询',
      );
    },
  );

  test(
    'prepareRunSettings 等待 checkpoint 时切换 session：返回 false 且不查询新目录',
    () async {
      final scenario = await _finishedBackgroundRun();
      final catalogBefore = List<String>.of(scenario.catalogQueries);
      _armCheckpointGate(scenario);

      final preparing = scenario.notifier.prepareRunSettings();
      await scenario.repository.saveEntered.future.timeout(
        const Duration(seconds: 5),
      );

      await scenario.notifier.createNewSession();
      await _settle(scenario.container);
      expect(scenario.container.read(aiChatProvider).activeSessionId, isNull);

      scenario.repository.gate!.complete();
      expect(await preparing.timeout(const Duration(seconds: 5)), isFalse);
      await _settle(scenario.container);

      final state = scenario.container.read(aiChatProvider);
      expect(scenario.storage.defaultWrites, isEmpty);
      expect(state.lastErrorCode, isNull);
      expect(state.isLoadingSettings, isFalse);
      expect(
        scenario.catalogQueries,
        catalogBefore,
        reason: '旧目标的初始化不得为新会话触发模型目录查询',
      );
    },
  );

  test('prepareRunSettings 的 checkpoint 失败且目标已切换：返回 false 不泄漏', () async {
    final scenario = await _finishedBackgroundRun();
    final catalogBefore = List<String>.of(scenario.catalogQueries);
    _armCheckpointGate(scenario, fail: true);

    final preparing = scenario.notifier.prepareRunSettings();
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );

    await scenario.notifier.switchAgent(_agentB);
    await _settle(scenario.container);

    scenario.repository.gate!.complete();
    expect(await preparing.timeout(const Duration(seconds: 5)), isFalse);
    await _settle(scenario.container);

    final state = scenario.container.read(aiChatProvider);
    expect(scenario.storage.defaultWrites, isEmpty);
    expect(state.lastErrorCode, isNull, reason: '旧目标的 checkpoint 失败不能泄漏到新目标');
    expect(state.isLoadingSettings, isFalse);
    expect(scenario.catalogQueries, catalogBefore);
  });

  test(
    'prepareRunSettings 的 checkpoint 保存失败且目标未变：返回 false 并落 CHAT_SAVE_FAILED',
    () async {
      final scenario = await _finishedBackgroundRun();
      _armCheckpointGate(scenario, fail: true);

      final preparing = scenario.notifier.prepareRunSettings();
      await scenario.repository.saveEntered.future.timeout(
        const Duration(seconds: 5),
      );

      // 目标没有任何变化，失败属于当前目标，必须由 prepareRunSettings 自己
      // 收敛成 false + 稳定错误码，而不是把异常抛给调用方。
      scenario.repository.gate!.complete();
      expect(await preparing.timeout(const Duration(seconds: 5)), isFalse);
      await _settle(scenario.container);

      final state = scenario.container.read(aiChatProvider);
      expect(
        state.lastErrorCode,
        startsWith('CHAT_SAVE_FAILED'),
        reason: '当前目标的 checkpoint 保存失败必须落到稳定错误码',
      );
      expect(state.settingsStale, isTrue);
      expect(state.isLoadingSettings, isFalse);
      expect(state.isApplyingSettings, isFalse);
      expect(scenario.storage.defaultWrites, isEmpty);
    },
  );

  test('目标未变时正常收养并持久化，证明守卫不是无条件放弃', () async {
    final scenario = await _finishedBackgroundRun();
    _armCheckpointGate(scenario);

    final applying = scenario.notifier.updateRunSettings(
      const ChatRunSettings(modelId: _newModel),
    );
    await scenario.repository.saveEntered.future.timeout(
      const Duration(seconds: 5),
    );
    scenario.repository.gate!.complete();
    await applying.timeout(const Duration(seconds: 5));
    await _settle(scenario.container);

    expect(
      scenario.storage.defaultWrites.where(
        (write) =>
            write.serverId == 'srv-1' &&
            write.agentId == _agentA &&
            write.settings.modelId == _newModel,
      ),
      hasLength(1),
      reason: '目标没变时，设置必须照常落盘',
    );
    expect(
      scenario.container.read(aiChatProvider).runSettings.modelId,
      _newModel,
    );
    expect(scenario.container.read(aiChatProvider).lastErrorCode, isNull);
  });
}
