import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/app_visibility_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// 前后台恢复期间「内容树不被替换」的回归测试。
///
/// 全部通过内存里的假 ACP 传输驱动：不连真实 SSH、不启动真实进程。
const _agentId = 'builtin-codex';
const _remoteId = 'remote-codex-1';

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

/// 连接状态可在测试里来回翻转，模拟真实的掉线与重连。
class _ToggleConnection extends ServerConnectionNotifier {
  bool connected = true;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: connected ? 'srv-1' : null,
  );

  void setConnected(bool value) {
    connected = value;
    state = ServerConnectionState(
      status: value
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
      activeServerId: value ? 'srv-1' : null,
    );
  }
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

/// 就绪状态可在测试里改变，模拟安装完成 / 掉线后重新探测。
class _MutableRegistry extends AgentRegistryNotifier {
  _MutableRegistry(this._profiles);

  final List<AgentProfile> _profiles;
  final Set<String> _readyIds = {_agentId};

  void markReady(String agentId) {
    _readyIds.add(agentId);
    ref.invalidateSelf();
  }

  void markNotReady(String agentId) {
    _readyIds.remove(agentId);
    ref.invalidateSelf();
  }

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      for (final profile in _profiles)
        AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: _readyIds.contains(profile.id)
                ? AgentEnvironmentStatusKind.ready
                : AgentEnvironmentStatusKind.cliMissing,
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

void main() {
  late List<FakeAcpPair> pairs;
  late _ToggleConnection connection;
  late _MutableRegistry registry;

  /// 这些开关只影响**之后**由传输工厂新建的对：恢复走的是新连接，
  /// 去改已经断开、已经 dispose 的旧对不会有任何效果。
  bool futurePairsFailSession = false;
  bool futurePairsWithoutReplay = false;

  // 与 provider 的 _launchKey 一致：
  // executionTarget|binding|reference|user|acpCommand|cliCommand
  const launchKey = 'host|name|null|null|acp --stdio|cli';

  /// 恢复时的正常适配器用 session/resume，不回放历史；
  /// 回放适配器（captureReplay）一定走 session/load。
  const capabilities = {
    'loadSession': true,
    'sessionCapabilities': {'list': true, 'resume': <String, Object?>{}},
  };

  AcpRemoteSession remote(String id) => AcpRemoteSession(
    id: id,
    title: 'remote $id',
    workingDirectory: '/root',
    serverId: 'srv-1',
    agentId: _agentId,
    launchKey: launchKey,
  );

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
        .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  int loadRequestCount() =>
      pairs.fold(0, (total, pair) => total + pair.loadRequests.length);

  int resumeRequestCount() =>
      pairs.fold(0, (total, pair) => total + pair.resumeRequests.length);

  int newSessionCount() =>
      pairs.fold(0, (total, pair) => total + pair.newSessionCount);

  int promptCount() => pairs.fold(
    0,
    (total, pair) =>
        total +
        pair.sentToAgent
            .where((line) => line.contains('session/prompt'))
            .length,
  );

  /// 等到某一对真的收到了 `session/prompt` 为止（连接与适配器都是异步建的）。
  Future<FakeAcpPair> awaitPromptPair() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      for (final pair in pairs) {
        if (pair.sentToAgent.any((line) => line.contains('session/prompt'))) {
          return pair;
        }
      }
      await pumpEventQueue();
    }
    fail('本轮必须真的把 prompt 发到了远端');
  }

  /// 真实的传输丢失：一轮正在 streaming 的 turn 被断线打断。
  ///
  /// `sendMessage` 在它第一个 `await` 之前就把 streaming 消息写进了 state，
  /// 所以这里不必等远端回话就能断线。断线让 `_requestEpoch` 前进，
  /// `sendMessage` 随后在保存处提前返回，不会为这轮建起第二条传输。
  Future<void> loseTurn(ProviderContainer container) async {
    final sending = container
        .read(aiChatProvider.notifier)
        .sendMessage('in flight');
    connection.setConnected(false);
    await sending;
    await settle(container);
    expect(
      container.read(aiChatProvider).activeSession!.messages.last.status,
      ChatTurnStatus.unknown,
      reason: '传输丢失必须记成 unknown，而不是用户取消的 interrupted',
    );
    expect(
      container.read(aiChatProvider).recoveryStatus,
      SessionRecoveryStatus.reconnecting,
      reason: '有 unknown turn 就必须进入重连，等待恢复',
    );
  }

  /// 用户主动取消一轮 turn：只有 cancel 才允许把 streaming 记成 interrupted。
  Future<void> cancelTurn(ProviderContainer container) async {
    final sending = container
        .read(aiChatProvider.notifier)
        .sendMessage('cancelled turn');
    await container.read(aiChatProvider.notifier).stopGeneration();
    await sending;
    await settle(container);
    expect(
      container.read(aiChatProvider).activeSession!.messages.last.status,
      ChatTurnStatus.interrupted,
      reason: '用户取消是 interrupted，不是传输丢失的 unknown',
    );
  }

  /// 等恢复走到终态：idle / incomplete / failed 都不是 syncing 或 reconnecting。
  /// 只等 loading 是不够的 —— 同步历史是另一条异步链路。
  Future<SessionRecoveryStatus> awaitRecoverySettled(
    ProviderContainer target,
  ) async {
    final notifier = target.read(aiChatProvider.notifier);
    await notifier.recoverConnection();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final status = target.read(aiChatProvider).recoveryStatus;
      if (status != SessionRecoveryStatus.syncing &&
          status != SessionRecoveryStatus.reconnecting) {
        return status;
      }
      await pumpEventQueue();
    }
    fail(
      '恢复没有落到终态，仍是 '
      '${target.read(aiChatProvider).recoveryStatus}',
    );
  }

  /// 建立一个已经导入过远端历史的容器：这是「回来先显示原内容」的真实起点。
  Future<ProviderContainer> importedContainer({
    List<Map<String, Object?>> replay = const [
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
    ],
    bool holdPrompt = false,
    bool importHistory = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    pairs = [];
    connection = _ToggleConnection();
    futurePairsFailSession = false;
    futurePairsWithoutReplay = false;
    registry = _MutableRegistry([
      _profile(_agentId),
      _profile('builtin-claude-code'),
    ]);
    final created = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(() => registry),
        serverConnectionProvider.overrideWith(() => connection),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        acpTransportFactoryProvider.overrideWithValue((_, _) async {
          final pair = FakeAcpPair(sessionId: _remoteId)
            ..agentCapabilities = futurePairsWithoutReplay
                ? const {
                    'sessionCapabilities': {'list': true},
                  }
                : capabilities
            ..loadReplayUpdates = replay
            ..holdPrompt = holdPrompt
            ..failSessionLoad = futurePairsFailSession
            ..failSessionResume = futurePairsFailSession
            ..failSessionNew = futurePairsFailSession;
          pairs.add(pair);
          return pair.client;
        }),
      ],
    );
    addTearDown(created.dispose);
    addTearDown(() {
      for (final pair in pairs) {
        pair.close();
      }
    });
    if (importHistory) {
      await settle(created);
      await created
          .read(aiChatProvider.notifier)
          .openRemoteSession(remote(_remoteId));
      await settle(created);
    }
    return created;
  }

  group('掉线不清空对话内容', () {
    test('connected → disconnected 之后历史、选择与草稿原样保留', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      final before = container.read(aiChatProvider);
      final beforeMessages = before.activeSession!.messages
          .map((m) => m.content)
          .toList();
      final beforeId = before.activeSessionId;
      notifier.updateDraftText('half typed');

      connection.setConnected(false);
      await settle(container);
      final after = container.read(aiChatProvider);

      expect(
        after.recoveryStatus,
        SessionRecoveryStatus.idle,
        reason: '健康已完成的会话断线后没有待恢复的 turn，不该自愈回放',
      );
      expect(after.activeSessionId, beforeId, reason: '同一台服务器掉线不得清掉当前会话');
      expect(
        after.activeSession!.messages.map((m) => m.content).toList(),
        beforeMessages,
        reason: '顶部状态变化不得替换消息列表',
      );
      expect(after.draftText, 'half typed', reason: '草稿不得被清空');
      expect(after.activeAgentProfile?.id, _agentId);
      expect(after.readyAgents.map((a) => a.id), contains(_agentId));
      expect(after.sessions.map((s) => s.id), contains(beforeId));
    });

    test('重连失败时不得替换会话 id，也不得丢掉已存的消息', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      final beforeId = container.read(aiChatProvider).activeSessionId;

      // 真实的传输丢失：留下一条无法被历史回放证明完成的 turn。
      await loseTurn(container);
      // 恢复会走新的传输连接：必须让**之后**新建的对失败。
      futurePairsFailSession = true;

      connection.setConnected(true);
      await settle(container);
      await notifier.recoverConnection();
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(after.activeSessionId, beforeId);
      expect(
        after.recoveryStatus,
        SessionRecoveryStatus.failed,
        reason: '恢复失败必须诚实暴露，并允许重试',
      );
      final sessions = await stored(container);
      expect(sessions, hasLength(1), reason: '失败不得复制出一条新会话');
      expect(
        (await container.read(chatRepositoryProvider).loadSession(beforeId!))!
            .messages
            .map((m) => m.content),
        ['old question', 'old answer', 'in flight', ''],
        reason: '失败不得抹掉本地已经记下的丢失 turn',
      );
      expect(promptCount(), 0, reason: '恢复失败也不得自动发起 prompt');
    });

    test('重连中禁止发送，但不影响本地阅读与草稿', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);

      await loseTurn(container);
      expect(
        container.read(aiChatProvider).recoveryStatus,
        SessionRecoveryStatus.reconnecting,
      );

      await notifier.sendMessage('should not be sent');
      notifier.updateDraftText('still editable');
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(after.isGenerating, isFalse, reason: '断线时不得假装在生成');
      expect(after.activeSession!.messages.map((m) => m.content), [
        'old question',
        'old answer',
        'in flight',
        '',
      ]);
      expect(after.draftText, 'still editable');
    });
  });

  group('恢复过程本身', () {
    test('健康已完成的会话断线重连不触发任何远端回放', () async {
      final container = await importedContainer();
      final beforeId = container.read(aiChatProvider).activeSessionId;
      final baselineLoads = loadRequestCount();
      final baselineResumes = resumeRequestCount();
      final baselineNews = newSessionCount();

      connection.setConnected(false);
      await settle(container);
      expect(
        container.read(aiChatProvider).recoveryStatus,
        SessionRecoveryStatus.idle,
        reason: '没有未完成的 turn 就没有待恢复的东西',
      );
      connection.setConnected(true);
      await settle(container);
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(after.recoveryStatus, SessionRecoveryStatus.idle);
      expect(after.activeSessionId, beforeId);
      expect(loadRequestCount() - baselineLoads, 0, reason: '健康线程不得回放远端历史');
      expect(
        resumeRequestCount() - baselineResumes,
        0,
        reason: '健康线程不得 resume',
      );
      expect(newSessionCount() - baselineNews, 0, reason: '健康线程不得新建替代会话');
      expect(promptCount(), 0, reason: '健康线程不得自动发起 prompt');
      expect(
        after.activeSession!.messages.map((m) => m.content),
        ['old question', 'old answer'],
        reason: '断线重连不得改动已完成的内容',
      );
    });

    test('前台回到前台不会重放被用户取消的 turn，显式恢复才同步', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      final beforeId = container.read(aiChatProvider).activeSessionId;
      await cancelTurn(container);
      final baselineLoads = loadRequestCount();

      // 连接抖一下再回来：前台事件本身不许重放被取消的 turn。
      connection.setConnected(false);
      await settle(container);
      connection.setConnected(true);
      container.read(appVisibilityProvider.notifier).setForeground(false);
      container.read(appVisibilityProvider.notifier).setForeground(true);
      await settle(container);
      await settle(container);

      expect(
        container.read(aiChatProvider).recoveryStatus,
        SessionRecoveryStatus.idle,
        reason: '被取消的 turn 不是待恢复状态',
      );
      expect(loadRequestCount(), baselineLoads, reason: '前台事件不得重放被取消的 turn');
      expect(promptCount(), 0, reason: '被取消的 turn 不得被自动重发');

      // 用户显式要求恢复时，才允许同步一次历史。
      await notifier.recoverConnection();
      await settle(container);
      expect(
        loadRequestCount() - baselineLoads,
        1,
        reason: '显式恢复是有意的远端操作，允许一次回放',
      );
      expect(container.read(aiChatProvider).activeSessionId, beforeId);
      expect(promptCount(), 0, reason: '显式恢复也不得发起 prompt');
    });

    test('recoverConnection 是单飞的：连接回来只同步一次', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await loseTurn(container);
      // 丢失本身不新建传输，但基线仍要取在它之后，计数才只反映恢复。
      final baseline = loadRequestCount();

      // 并发调用复用同一个 future。
      final first = notifier.recoverConnection();
      final second = notifier.recoverConnection();
      expect(identical(first, second), isTrue, reason: '同一次恢复只该跑一遍');
      // 断线期间恢复是有意 no-op：不得打扰远端。
      await first;
      expect(loadRequestCount(), baseline, reason: '还没连上就不该同步远端历史');

      // 连接回来：监听器已经发起一次恢复，这里再显式调用也必须被合并。
      connection.setConnected(true);
      await notifier.recoverConnection();
      await settle(container);

      expect(loadRequestCount() - baseline, 1, reason: '远端历史只允许被拉取一次');
      expect(
        container.read(aiChatProvider).recoveryStatus,
        SessionRecoveryStatus.incomplete,
        reason: '本地还留着一条无法被回放证明完成的 unknown turn，必须诚实标成 incomplete',
      );
    });

    test('后台时不恢复，回前台才继续', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      await loseTurn(container);
      final baseline = loadRequestCount();

      // 先在后台把连接恢复好：此时不得发起任何远端同步。
      container.read(appVisibilityProvider.notifier).setForeground(false);
      connection.setConnected(true);
      await notifier.recoverConnection();
      await settle(container);
      expect(
        container.read(aiChatProvider).recoveryStatus,
        SessionRecoveryStatus.reconnecting,
        reason: '后台不主动发起远端操作',
      );
      expect(loadRequestCount(), baseline, reason: '后台不得回放远端历史');

      container.read(appVisibilityProvider.notifier).setForeground(true);
      await settle(container);
      await settle(container);

      expect(loadRequestCount() - baseline, 1, reason: '回前台后补一次同步');
      expect(
        container.read(aiChatProvider).recoveryStatus,
        isNot(SessionRecoveryStatus.reconnecting),
      );
    });

    test('真实断线恢复后仍是原会话 id，消息不重复', () async {
      final container = await importedContainer();
      final beforeId = container.read(aiChatProvider).activeSessionId;
      // 真实的传输丢失：留下一条本地记着、远端回放里没有的 turn。
      await loseTurn(container);
      // 丢失本身不新建传输，基线取在它之后，计数才只反映恢复。
      final baselineLoads = loadRequestCount();
      final baselineResumes = resumeRequestCount();
      final baselineNews = newSessionCount();

      connection.setConnected(true);
      // 恢复已经被连接监听器发起；这里 await 的是同一个 future。
      final status = await awaitRecoverySettled(container);
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(
        status,
        SessionRecoveryStatus.incomplete,
        reason: '回放证明不了那条丢失的 turn 跑完了，不得谎称完整恢复',
      );
      expect(after.activeSessionId, beforeId, reason: '恢复的是同一个会话');
      expect(
        after.activeSession!.messages.map((m) => m.content),
        ['old question', 'old answer', 'in flight', ''],
        reason: '重放同一段历史不得产生重复消息，也不得抹掉本地丢失的 turn',
      );
      final sessions = await stored(container);
      expect(sessions, hasLength(1), reason: '不得因为恢复多出一条本地会话');
      expect(sessions.single.id, beforeId);
      expect(sessions.single.historyImportIncomplete, isFalse);
      expect(
        loadRequestCount() - baselineLoads,
        1,
        reason: '回放适配器只允许 session/load 一次',
      );
      expect(
        resumeRequestCount() - baselineResumes,
        0,
        reason: '回放之后复用同一个已加载的适配器：不再 resume，也不再回放',
      );
      expect(newSessionCount() - baselineNews, 0, reason: '恢复不得新建替代会话');
      expect(promptCount(), 0, reason: '恢复不得自动发起 prompt');
      expect(after.acpSessionRestored, isTrue, reason: '必须复用原远端会话，而不是新建一个');
    });

    test('没有回放能力时诚实降级为「部分无法恢复」', () async {
      final container = await importedContainer();
      final beforeId = container.read(aiChatProvider).activeSessionId;
      expect(
        container.read(aiChatProvider).activeSession!.messages,
        isNotEmpty,
        reason: '前提：本地已经有内容，恢复不能把它弄丢',
      );

      await loseTurn(container);
      // 之后的适配器都不支持 loadSession：只能诚实地降级。
      futurePairsWithoutReplay = true;

      // 丢失本身不新建传输，基线取在它之后，计数才只反映恢复。
      final baselineLoads = loadRequestCount();
      final baselineResumes = resumeRequestCount();
      final baselineNews = newSessionCount();

      connection.setConnected(true);
      final status = await awaitRecoverySettled(container);
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(
        status,
        SessionRecoveryStatus.incomplete,
        reason: '不能回放时不得声称已完整恢复',
      );
      expect(after.activeSessionId, beforeId);
      expect(
        after.activeSession!.messages.map((m) => m.content),
        ['old question', 'old answer', 'in flight', ''],
        reason: '无法恢复的部分不影响已经显示的内容',
      );
      expect(
        loadRequestCount() - baselineLoads,
        1,
        reason: '回放通道不通时，降级走同一个已初始化的适配器补一次同步',
      );
      expect(
        resumeRequestCount() - baselineResumes,
        0,
        reason: '没有 resume 能力就不得硬试 resume',
      );
      expect(newSessionCount() - baselineNews, 0, reason: '不得用新会话顶替');
      expect(promptCount(), 0, reason: '不得自动发起 prompt');
    });
  });

  group('checkpoint 与 registry 就绪更新', () {
    test('checkpoint 只保存，不取消远端 prompt', () async {
      // 让之后新建的每一个对都挂住 prompt：远端已收到请求但没回话。
      final container = await importedContainer(holdPrompt: true);
      final notifier = container.read(aiChatProvider.notifier);
      await settle(container);

      // prompt 被挂住时 sendMessage 本来就不会返回：把它留着，由下面的清理收尾。
      final sending = notifier.sendMessage('long running turn');
      final turnPair = await awaitPromptPair();
      await turnPair.promptReceived.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('远端没有收到 prompt'),
      );
      await settle(container);
      expect(container.read(aiChatProvider).isGenerating, isTrue);

      final wireBefore = turnPair.sentToAgent.length;
      notifier.updateDraftText('draft while background');
      await notifier.checkpoint();
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(after.isGenerating, isTrue, reason: '后台只保存，不取消 prompt');
      expect(
        turnPair.sentToAgent.skip(wireBefore).join(),
        isNot(contains('session/cancel')),
        reason: '绝不能向远端发取消请求',
      );
      final sessions = await stored(container);
      expect(sessions, hasLength(1));
      expect(
        sessions.single.messages.map((m) => m.content),
        contains('long running turn'),
        reason: 'checkpoint 必须先把会话落盘',
      );

      // 显式收尾，避免把一个悬空的远端 turn 留给后续测试。
      turnPair.finishHeldPrompt();
      await sending.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('prompt 收尾后 sendMessage 仍未返回'),
      );
      await settle(container);
      expect(container.read(aiChatProvider).isGenerating, isFalse);
    });

    test('registry 就绪状态变化不清空选择、消息与草稿', () async {
      final container = await importedContainer();
      final notifier = container.read(aiChatProvider.notifier);
      final beforeId = container.read(aiChatProvider).activeSessionId;
      notifier.updateDraftText('kept draft');

      registry.markReady('builtin-claude-code');
      await settle(container);

      final after = container.read(aiChatProvider);
      expect(
        after.readyAgents.map((a) => a.id),
        containsAll([_agentId, 'builtin-claude-code']),
      );
      expect(after.activeAgentProfile?.id, _agentId, reason: '当前 agent 不该被换掉');
      expect(after.activeSessionId, beforeId);
      expect(after.activeSession!.messages.map((m) => m.content), [
        'old question',
        'old answer',
      ]);
      expect(after.draftText, 'kept draft');
      expect(after.recoveryStatus, SessionRecoveryStatus.idle);
    });
  });
}
