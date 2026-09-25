import 'dart:async';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/chat_run_settings.dart';
import '../../data/models/chat_launch_preference.dart';
import '../../infrastructure/acp/acp_client_adapter.dart';
import '../../infrastructure/acp/acp_ssh_transport.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../utils/shell_quote.dart';
import 'agent_registry_provider.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

/// 构造 ACP 传输：在生产环境中通过 SSH exec 通道启动 profile 的 `acpCommand`。
///
/// 抽成 provider 是为了让 provider 层测试可以注入替身，而不触碰真实 SSH。
typedef AcpTransportFactory =
    Future<Transport> Function(AgentProfile profile, SSHClient sshClient);

final acpTransportFactoryProvider = Provider<AcpTransportFactory>((ref) {
  return (profile, sshClient) async {
    final acpCommand = profile.acpCommand;
    if (acpCommand == null || acpCommand.trim().isEmpty) {
      throw StateError('Agent ${profile.id} has no ACP command');
    }
    final session = await sshClient.execute(
      agentTargetCommand(
        profile,
        profile.executionTarget == 'docker'
            ? acpCommand
            : 'bash -l -c ${cliShellQuote(acpCommand)}',
      ),
    );
    return AcpSshTransport(session);
  };
});

/// Agent 在处理请求时提出的认证要求，供 UI 引导用户选择认证方式。
///
/// 与 [AgentEnvironmentStatusKind.notLoggedIn] 不同：后者来自 CLI 登录检查命令
/// 的启发式退出码（环境态），本类型来自 ACP 协议握手（协议态）。
class AuthChallenge {
  final String? serverId;
  final String agentId;
  final List<AcpAuthMethod> methods;

  const AuthChallenge({
    this.serverId,
    required this.agentId,
    required this.methods,
  });
}

class AiChatState {
  final ChatRunSettings runSettings;
  final AgentRuntimeCapabilities capabilities;
  final bool shareAgentSessions;
  final List<ChatSession> sessions;
  final String? activeSessionId;

  /// 当前服务器上已就绪、可供切换的 Agent（来自 [agentRegistryProvider]）。
  final List<AgentProfile> readyAgents;

  /// 当前选中的 Agent；未选择或不可用时为 null。
  final AgentProfile? activeAgentProfile;

  final bool isGenerating;
  final PermissionRequest? pendingPermission;
  final Completer<bool>? permissionCompleter;

  /// 非 null 表示 agent 要求认证，等待用户选择认证方式。
  final AuthChallenge? authChallenge;

  /// 用户选择认证方式后回传 methodId 的通道。
  final Completer<String?>? authCompleter;

  /// 用户已选定的认证方式（按 agentId 记录）。
  ///
  /// 每次发送消息都会重建 adapter，因此选择必须保存在 provider 层，
  /// 并在新建 adapter 时重新注入，否则用户的选择会随旧 adapter 一起丢失。
  final Map<String, String> selectedAuthMethods;

  /// 稳定错误码（非本地化文案），由 UI 映射 ARB。
  final String? lastErrorCode;

  /// 当前 ACP 会话是否复用了远端已有会话（上下文仍在）。
  ///
  /// 由 adapter 的 `restoredExistingSession` 上报。null 表示尚未建立会话，
  /// 此时界面不应做任何提示 —— 把「还没开始」当成「上下文丢了」会误报。
  final bool? acpSessionRestored;

  /// 是否发生过「上下文已丢失」的会话重启（远端进程是新建的）。
  ///
  /// 与 [acpSessionRestored] 分开是因为两者的生命周期不同：
  /// 前者是每次建会话都会刷新的瞬时事实，后者是需要用户确认后才该消除的告警。
  final bool acpSessionRestartDetected;

  const AiChatState({
    this.runSettings = const ChatRunSettings(),
    this.capabilities = const AgentRuntimeCapabilities(),
    this.shareAgentSessions = false,
    this.sessions = const [],
    this.activeSessionId,
    this.readyAgents = const [],
    this.activeAgentProfile,
    this.isGenerating = false,
    this.pendingPermission,
    this.permissionCompleter,
    this.authChallenge,
    this.authCompleter,
    this.selectedAuthMethods = const {},
    this.lastErrorCode,
    this.acpSessionRestored,
    this.acpSessionRestartDetected = false,
  });

  ChatSession? get activeSession {
    if (sessions.isEmpty) return null;
    if (activeSessionId == null) return null;
    return sessions.firstWhere(
      (s) => s.id == activeSessionId,
      orElse: () => sessions.first,
    );
  }

  /// 兼容桥：旧的 `AgentType` 视图。新代码应使用 [activeAgentProfile]。
  @Deprecated('Use activeAgentProfile.agentId instead')
  AgentType get activeAgent {
    final agentId = activeAgentProfile?.id;
    for (final entry in AgentType.values) {
      if (kLegacyAgentTypeToId[entry.name.toLowerCase()] == agentId) {
        return entry;
      }
    }
    return AgentType.claudeCode;
  }

  AiChatState copyWith({
    ChatRunSettings? runSettings,
    AgentRuntimeCapabilities? capabilities,
    bool? shareAgentSessions,
    bool clearActiveSession = false,
    List<ChatSession>? sessions,
    String? activeSessionId,
    List<AgentProfile>? readyAgents,
    AgentProfile? activeAgentProfile,
    bool clearActiveAgent = false,
    bool? isGenerating,
    PermissionRequest? pendingPermission,
    Completer<bool>? permissionCompleter,
    AuthChallenge? authChallenge,
    Completer<String?>? authCompleter,
    Map<String, String>? selectedAuthMethods,
    String? lastErrorCode,
    bool clearError = false,
    bool clearPermission = false,
    bool clearAuthChallenge = false,
    bool? acpSessionRestored,
    bool clearAcpSessionRestored = false,
    bool? acpSessionRestartDetected,
  }) {
    return AiChatState(
      runSettings: runSettings ?? this.runSettings,
      capabilities: capabilities ?? this.capabilities,
      shareAgentSessions: shareAgentSessions ?? this.shareAgentSessions,
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      readyAgents: readyAgents ?? this.readyAgents,
      activeAgentProfile: clearActiveAgent
          ? null
          : (activeAgentProfile ?? this.activeAgentProfile),
      isGenerating: isGenerating ?? this.isGenerating,
      pendingPermission: clearPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      permissionCompleter: clearPermission
          ? null
          : (permissionCompleter ?? this.permissionCompleter),
      authChallenge: clearAuthChallenge
          ? null
          : (authChallenge ?? this.authChallenge),
      authCompleter: clearAuthChallenge
          ? null
          : (authCompleter ?? this.authCompleter),
      selectedAuthMethods: selectedAuthMethods ?? this.selectedAuthMethods,
      lastErrorCode: clearError ? null : (lastErrorCode ?? this.lastErrorCode),
      acpSessionRestored: clearAcpSessionRestored
          ? null
          : (acpSessionRestored ?? this.acpSessionRestored),
      acpSessionRestartDetected:
          acpSessionRestartDetected ?? this.acpSessionRestartDetected,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  int get activeConnectionCount =>
      _currentAdapter != null || _isPreparingPrompt ? 1 : 0;
  static const _uuid = Uuid();

  static const notReadyCode = 'AGENT_NOT_READY';
  static const disconnectedCode = 'SSH_DISCONNECTED';

  /// Agent 要求认证；UI 据此展示引导卡片，而非通用错误。
  static const authRequiredCode = 'ACP_AUTH_REQUIRED';

  StreamSubscription<ACPEvent>? _acpSub;
  ACPClientAdapter? _currentAdapter;

  /// [_currentAdapter] 对应的 agent id。
  ///
  /// 切换 Agent 时必须重建 adapter，否则会把上一个 Agent 的会话
  /// 当成当前的。
  String? _currentAdapterAgentId;
  String? _currentAdapterSessionId;
  String? _currentAdapterServerId;
  String? _currentAdapterLaunchKey;
  int _requestEpoch = 0;
  bool _isPreparingPrompt = false;
  final Map<String, String?> _lastSelectedSessions = {};

  /// 当前活跃的 SSH 服务器 id，用于按服务器隔离会话 id。
  String? get _activeServerId => ref.read(activeServerProvider)?.id;

  /// 构造一个 ACP adapter，并接上会话 id 的读取与持久化。
  Future<ACPClientAdapter> _createAdapter(
    AgentProfile profile,
    SSHClient sshClient,
  ) async {
    final localSession = state.activeSession!;
    final serverId = _activeServerId;
    final transport = await ref.read(acpTransportFactoryProvider)(
      profile,
      sshClient,
    );

    final storage = ref.read(localStorageServiceProvider);

    // 有历史会话 id 就带上，让 adapter 优先 load/resume 而不是新建。
    final storedSessionId = localSession.contextFor(profile.id).remoteSessionId;

    final adapter = ACPClientAdapter(
      profile: profile,
      transport: transport,
      workingDirectory: localSession.workingDirectory,
      resumeSessionId: storedSessionId,
    );

    // 新建会话也要记住新 id，否则下次掉线又只能新建。
    adapter.onSessionEstablished = (sessionId) {
      if (serverId == null) return;
      final current = state.sessions
          .where((entry) => entry.id == localSession.id)
          .firstOrNull;
      if (current == null) return;
      final context = current.contextFor(profile.id);
      final updated = current.copyWith(
        remoteSessionId: current.agentId == profile.id
            ? sessionId
            : current.remoteSessionId,
        agentContexts: {
          ...current.agentContexts,
          profile.id: AgentChatContext(
            remoteSessionId: sessionId,
            syncedMessageCount: context.syncedMessageCount,
          ),
        },
      );
      _updateSessionInState(updated);
      unawaited(ref.read(chatRepositoryProvider).saveSession(updated));
      unawaited(storage.saveAcpSessionId(serverId, profile.id, sessionId));
    };

    return adapter;
  }

  @override
  AiChatState build() {
    ref.onDispose(() {
      _requestEpoch++;
      unawaited(_acpSub?.cancel());
      _currentAdapter?.dispose();
      _currentAdapter = null;
      _acpSub = null;
    });
    ref.listen(serverConnectionProvider, (prev, next) {
      if (prev?.isConnected == true && !next.isConnected) {
        unawaited(stopGeneration());
      }
    });

    final repo = ref.watch(chatRepositoryProvider);
    final registry = ref.watch(agentRegistryProvider);
    final serverId = ref.watch(activeServerProvider)?.id;
    final share =
        serverId != null &&
        ref.read(localStorageServiceProvider).getShareAgentSessions(serverId);
    final allSessions = serverId == null
        ? <ChatSession>[]
        : repo.getSessionsForServer(serverId);
    final readyAgents = registry.readyAgents;

    // 保留仍然可用的显式选择；否则自动激活首个就绪 Agent。
    // 安装完成使 Agent 变为 ready 时，registry 变化会触发 build 重跑，
    // 从而自动选中它，无需 UI 监听第二个 provider。
    final previous = stateOrNull?.activeAgentProfile;
    final keepPrevious =
        previous != null &&
        (serverId == null || previous.serverId == serverId) &&
        readyAgents.any((a) => a.id == previous.id);

    final preferredId = serverId == null
        ? null
        : ref
              .read(localStorageServiceProvider)
              .getDefaultAgentId(serverId, cli: false);
    final preferredAgent = readyAgents
        .where((agent) => agent.id == preferredId)
        .firstOrNull;

    final existingState = stateOrNull;
    final selectedAgent = keepPrevious
        ? readyAgents.firstWhere((entry) => entry.id == previous.id)
        : (preferredAgent ?? readyAgents.firstOrNull);
    final sessions = allSessions
        .where(
          (s) =>
              share ||
              (selectedAgent != null && s.includesAgent(selectedAgent.id)),
        )
        .toList();
    final selectedSession = sessions
        .where((entry) => entry.id == existingState?.activeSessionId)
        .firstOrNull;
    final runSettings = selectedAgent == null || serverId == null
        ? const ChatRunSettings()
        : selectedSession?.agentRunSettings[selectedAgent.id] ??
              ref
                  .read(localStorageServiceProvider)
                  .getChatRunDefault(serverId, selectedAgent.id);
    if (existingState != null) {
      return existingState.copyWith(
        runSettings: runSettings,
        sessions: sessions,
        shareAgentSessions: share,
        activeSessionId: _preferredSessionId(
          serverId,
          selectedAgent?.id,
          sessions,
          existingState.activeSessionId,
        ),
        clearActiveSession:
            _preferredSessionId(
              serverId,
              selectedAgent?.id,
              sessions,
              existingState.activeSessionId,
            ) ==
            null,
        isGenerating: existingState.isGenerating && _currentAdapter != null,
        clearPermission: _currentAdapter == null,
        clearAuthChallenge: _currentAdapter == null,
        readyAgents: readyAgents,
        activeAgentProfile: selectedAgent,
        clearActiveAgent: selectedAgent == null,
      );
    }
    return AiChatState(
      runSettings: runSettings,
      shareAgentSessions: share,
      sessions: sessions,
      activeSessionId: _preferredSessionId(
        serverId,
        selectedAgent?.id,
        sessions,
        null,
      ),
      readyAgents: readyAgents,
      activeAgentProfile: selectedAgent,
    );
  }

  String? _preferredSessionId(
    String? serverId,
    String? agentId,
    List<ChatSession> sessions,
    String? current,
  ) {
    if (serverId == null || agentId == null) return null;
    final storage = ref.read(localStorageServiceProvider);
    final preference = storage.getChatLaunchPreference(
      serverId,
      agentId,
      cli: false,
    );
    final candidate = switch (preference.mode) {
      ChatLaunchMode.fixed => preference.sessionId,
      ChatLaunchMode.rememberLast => storage.getLastChatSessionId(
        serverId,
        agentId,
        cli: false,
      ),
      ChatLaunchMode.blankDraft => null,
    };
    if (candidate != null && sessions.any((entry) => entry.id == candidate)) {
      return candidate;
    }
    if (preference.mode == ChatLaunchMode.blankDraft) return null;
    return sessions.any((entry) => entry.id == current)
        ? current
        : sessions.firstOrNull?.id;
  }

  Future<void> setLaunchPreference(ChatLaunchPreference preference) async {
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId == null || agentId == null) return;
    await ref
        .read(localStorageServiceProvider)
        .saveChatLaunchPreference(serverId, agentId, preference, cli: false);
    _refreshVisibleSessions();
  }

  Future<void> setDefaultAgent(String? agentId) async {
    final serverId = ref.read(activeServerProvider)?.id;
    if (serverId == null) return;
    if (agentId != null &&
        !state.readyAgents.any((agent) => agent.id == agentId)) {
      throw ArgumentError.value(agentId, 'agentId', 'Agent is not ready');
    }
    await ref
        .read(localStorageServiceProvider)
        .setDefaultAgentId(serverId, agentId, cli: false);
  }

  void selectSession(String sessionId) {
    if (state.isGenerating) return;
    if (!state.sessions.any((s) => s.id == sessionId)) return;
    _lastSelectedSessions['$_activeServerId::${state.activeAgentProfile?.id}'] =
        sessionId;
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId != null && agentId != null) {
      unawaited(
        ref
            .read(localStorageServiceProvider)
            .saveLastChatSessionId(serverId, agentId, sessionId, cli: false),
      );
    }
    final session = state.sessions.firstWhere((s) => s.id == sessionId);
    final selectedAgentId = state.activeAgentProfile?.id;
    state = state.copyWith(
      activeSessionId: sessionId,
      runSettings: selectedAgentId == null
          ? const ChatRunSettings()
          : session.agentRunSettings[selectedAgentId] ??
                ref
                    .read(localStorageServiceProvider)
                    .getChatRunDefault(_activeServerId!, selectedAgentId),
    );
  }

  /// 按稳定 agentId 切换 Agent；目标不存在或未就绪时拒绝切换。
  void switchAgent(String agentId) {
    if (state.isGenerating) return;
    final target = state.readyAgents.where((a) => a.id == agentId).firstOrNull;
    if (target == null) {
      state = state.copyWith(lastErrorCode: notReadyCode);
      return;
    }
    _lastSelectedSessions['$_activeServerId::${state.activeAgentProfile?.id}'] =
        state.activeSessionId;
    state = state.copyWith(activeAgentProfile: target, clearError: true);
    _refreshVisibleSessions();
  }

  void _refreshVisibleSessions() {
    final serverId = _activeServerId;
    final sessions = serverId == null
        ? <ChatSession>[]
        : ref
              .read(chatRepositoryProvider)
              .getSessionsForServer(serverId)
              .where(
                (s) =>
                    state.shareAgentSessions ||
                    s.includesAgent(state.activeAgentProfile?.id ?? ''),
              )
              .toList();
    final selected = _preferredSessionId(
      serverId,
      state.activeAgentProfile?.id,
      sessions,
      state.activeSessionId ??
          _lastSelectedSessions['$serverId::${state.activeAgentProfile?.id}'],
    );
    state = state.copyWith(
      sessions: sessions,
      activeSessionId: selected,
      clearActiveSession: selected == null,
      runSettings: state.activeAgentProfile == null || serverId == null
          ? const ChatRunSettings()
          : sessions
                    .where((entry) => entry.id == selected)
                    .firstOrNull
                    ?.agentRunSettings[state.activeAgentProfile!.id] ??
                ref
                    .read(localStorageServiceProvider)
                    .getChatRunDefault(serverId, state.activeAgentProfile!.id),
      capabilities: const AgentRuntimeCapabilities(),
    );
  }

  Future<void> updateRunSettings(ChatRunSettings settings) async {
    if (state.isGenerating) return;
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId == null || agentId == null) return;
    await ref
        .read(localStorageServiceProvider)
        .saveChatRunDefault(serverId, agentId, settings);
    final session = state.activeSession;
    if (session != null) {
      final updated = session.copyWith(
        agentRunSettings: {...session.agentRunSettings, agentId: settings},
      );
      _updateSessionInState(updated);
      await ref.read(chatRepositoryProvider).saveSession(updated);
    }
    state = state.copyWith(runSettings: settings);
  }

  Future<void> setShareAgentSessions(bool enabled) async {
    final serverId = _activeServerId;
    if (serverId == null || state.isGenerating) return;
    await ref
        .read(localStorageServiceProvider)
        .setShareAgentSessions(serverId, enabled);
    if (!ref.mounted || _activeServerId != serverId) return;
    state = state.copyWith(shareAgentSessions: enabled);
    _refreshVisibleSessions();
  }

  Future<void> bindActiveSessionToCurrentServer({
    String? expectedSessionId,
    String? expectedServerId,
  }) async {
    final current = state.activeSession;
    final serverId = _activeServerId;
    if (state.isGenerating) return;
    if ((expectedSessionId != null && current?.id != expectedSessionId) ||
        (expectedServerId != null && serverId != expectedServerId)) {
      state = state.copyWith(lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH');
      return;
    }
    if (current == null || serverId == null || current.serverId != null) return;
    final updated = current.copyWith(serverId: serverId);
    await ref.read(chatRepositoryProvider).saveSession(updated);
    _updateSessionInState(updated);
    state = state.copyWith(clearError: true);
  }

  Future<void> stopGeneration() async {
    _requestEpoch++;
    final permission = state.permissionCompleter;
    if (permission != null && !permission.isCompleted) {
      permission.complete(false);
    }
    final auth = state.authCompleter;
    if (auth != null && !auth.isCompleted) auth.complete(null);
    await _acpSub?.cancel();
    _acpSub = null;
    _currentAdapter?.cancelPrompt();
    _currentAdapter?.dispose();
    _currentAdapter = null;
    _currentAdapterLaunchKey = null;
    final current = state.activeSession;
    state = state.copyWith(
      isGenerating: false,
      clearPermission: true,
      clearAuthChallenge: true,
    );
    if (current != null) {
      await ref.read(chatRepositoryProvider).saveSession(current);
    }
  }

  Future<void> createNewSession([String? title]) async {
    if (state.isGenerating) return;
    state = state.copyWith(
      clearActiveSession: true,
      clearError: true,
      clearAcpSessionRestored: true,
      acpSessionRestartDetected: false,
    );
  }

  Future<void> _persistNewSession(String title) async {
    final repo = ref.read(chatRepositoryProvider);
    final now = DateTime.now();
    final newSession = ChatSession(
      id: _uuid.v4(),
      title: title,
      agentId: state.activeAgentProfile?.id,
      serverId: _activeServerId,
      createdAt: now,
      updatedAt: now,
      messages: [],
      agentRunSettings: state.activeAgentProfile == null
          ? const {}
          : {state.activeAgentProfile!.id: state.runSettings},
    );
    await repo.saveSession(newSession);
    if (!ref.mounted ||
        _activeServerId != newSession.serverId ||
        state.activeAgentProfile?.id != newSession.agentId) {
      return;
    }
    state = state.copyWith(
      sessions: [newSession, ...state.sessions],
      activeSessionId: newSession.id,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    if (state.isGenerating && state.activeSessionId == sessionId) return;
    final serverId = _activeServerId;
    final repo = ref.read(chatRepositoryProvider);
    await repo.deleteSession(sessionId);
    if (!ref.mounted || _activeServerId != serverId) return;
    final updated = state.sessions.where((s) => s.id != sessionId).toList();
    state = state.copyWith(
      sessions: updated,
      clearActiveSession: state.activeSessionId == sessionId && updated.isEmpty,
      activeSessionId: state.activeSessionId == sessionId
          ? updated.firstOrNull?.id
          : state.activeSessionId,
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isGenerating || _isPreparingPrompt) return;
    final requestEpoch = ++_requestEpoch;

    // 就绪守卫：没有可用 Agent 时阻止发送，绝不平移到另一个 Agent。
    final profile = state.activeAgentProfile;
    if (profile == null) {
      state = state.copyWith(lastErrorCode: notReadyCode);
      return;
    }

    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);
    final sshManager = ref.read(sshClientManagerProvider);
    final sshClient = (activeServer != null && connState.isConnected)
        ? sshManager.getClient(activeServer.id)
        : null;

    if (sshClient == null) {
      state = state.copyWith(lastErrorCode: disconnectedCode);
      return;
    }

    var session = state.activeSession;
    if (session == null) {
      _isPreparingPrompt = true;
      try {
        await _persistNewSession(
          text.length > 20 ? '${text.substring(0, 20)}...' : text,
        );
      } finally {
        _isPreparingPrompt = false;
      }
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
      session = state.activeSession;
      if (session == null || state.activeAgentProfile?.id != profile.id) return;
    }
    if (session.serverId == null) {
      state = state.copyWith(lastErrorCode: 'CHAT_SERVER_BINDING_REQUIRED');
      return;
    }
    if (session.serverId != activeServer!.id ||
        (!state.shareAgentSessions && !session.includesAgent(profile.id))) {
      state = state.copyWith(lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH');
      return;
    }

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );

    var assistantMsg = ChatMessage(
      agentId: profile.id,
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    var currentMessages = [...session.messages, userMsg, assistantMsg];
    var updatedSession = session.copyWith(
      participantAgentIds: {
        ...session.participantAgentIds,
        if (session.agentId != null) session.agentId!,
        profile.id,
      }.toList(),
      messages: currentMessages,
      updatedAt: DateTime.now(),
    );
    _updateSessionInState(updatedSession);
    state = state.copyWith(isGenerating: true, clearError: true);

    // 复用已有 adapter 与远端 agent 进程。原先每条消息都重建 transport，
    // 等于每次都重开一个远端进程、丢掉 ACP 会话上下文，这正是
    // 「重连/发第二条消息后内容没了」的根因。
    var adapter = _currentAdapter;
    // 记录这是不是重建出来的 adapter：只有重建才可能发生「上下文丢失」，
    // 复用同一个 adapter 是正常连续对话，不该弹重启告警。
    var adapterWasRebuilt = false;
    final launchKey =
        '${profile.executionTarget}|${profile.containerBinding}|'
        '${profile.containerReference}|${profile.acpCommand}';
    try {
      if (adapter == null ||
          _currentAdapterAgentId != profile.id ||
          _currentAdapterSessionId != session.id ||
          _currentAdapterServerId != activeServer.id ||
          _currentAdapterLaunchKey != launchKey) {
        adapter?.dispose();
        adapter = await _createAdapter(profile, sshClient);
        if (requestEpoch != _requestEpoch) {
          adapter.dispose();
          return;
        }
        _currentAdapter = adapter;
        _currentAdapterAgentId = profile.id;
        _currentAdapterSessionId = session.id;
        _currentAdapterServerId = activeServer.id;
        _currentAdapterLaunchKey = launchKey;
        adapterWasRebuilt = true;
      }

      // 用户此前选定的认证方式必须重新注入：新 adapter 需要它。
      final chosenAuthMethod =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (chosenAuthMethod != null) {
        await adapter.authenticate(chosenAuthMethod);
      }

      await adapter.prepareSession();
      if (requestEpoch != _requestEpoch) return;
      final options = adapter.configOptions;
      state = state.copyWith(capabilities: _acpCapabilities(options));
      await _applyAcpSettings(adapter, options, state.runSettings);

      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen((event) {
        if (requestEpoch != _requestEpoch ||
            state.activeSessionId != session!.id ||
            _activeServerId != activeServer.id) {
          return;
        }
        if (event is ACPThinkingChunkEvent) {
          final current = assistantMsg.thinking ?? '';
          assistantMsg = assistantMsg.copyWith(thinking: current + event.chunk);
          _updateAssistantMessage(updatedSession, assistantMsg);
        } else if (event is ACPContentChunkEvent) {
          assistantMsg = assistantMsg.copyWith(
            content: assistantMsg.content + event.chunk,
          );
          _updateAssistantMessage(updatedSession, assistantMsg);
        } else if (event is ACPPlanUpdateEvent) {
          assistantMsg = assistantMsg.copyWith(planSteps: event.planSteps);
          _updateAssistantMessage(updatedSession, assistantMsg);
        } else if (event is ACPToolExecutionEvent) {
          final tools = assistantMsg.toolExecutions.toList();
          final idx = tools.indexWhere((t) => t.id == event.toolExecution.id);
          if (idx >= 0) {
            tools[idx] = event.toolExecution;
          } else {
            tools.add(event.toolExecution);
          }
          assistantMsg = assistantMsg.copyWith(toolExecutions: tools);
          _updateAssistantMessage(updatedSession, assistantMsg);
        } else if (event is ACPPermissionRequestEvent) {
          final policy = state.runSettings.permissionPolicy;
          final autoAllow =
              policy == OperationPermissionPolicy.autoAllowAll ||
              (policy == OperationPermissionPolicy.autoAllowSafe &&
                  !event.request.isDangerous);
          if (autoAllow) {
            event.responseCompleter.complete(true);
          } else {
            state = state.copyWith(
              pendingPermission: event.request,
              permissionCompleter: event.responseCompleter,
            );
          }
        } else if (event is ACPAuthRequiredEvent) {
          // 覆盖而非叠加：先了结上一个挂起的 completer，避免永久等待。
          final previous = state.authCompleter;
          if (previous != null && !previous.isCompleted) {
            previous.complete(null);
          }
          state = state.copyWith(
            authChallenge: AuthChallenge(
              serverId: activeServer.id,
              agentId: profile.id,
              methods: event.methods,
            ),
            authCompleter: Completer<String?>(),
            isGenerating: false,
          );
        } else if (event is ACPCompleteEvent) {
          state = state.copyWith(isGenerating: false, clearPermission: true);
          final latest = state.sessions
              .where((entry) => entry.id == updatedSession.id)
              .firstOrNull;
          if (latest != null) {
            ref.read(chatRepositoryProvider).saveSession(latest);
          }
        } else if (event is ACPErrorEvent) {
          assistantMsg = assistantMsg.copyWith(
            content: '${assistantMsg.content}\n\n**Error:** ${event.error}',
          );
          _updateAssistantMessage(updatedSession, assistantMsg);
          state = state.copyWith(
            isGenerating: false,
            clearPermission: true,
            lastErrorCode: event.error,
          );
        }
      });

      final context = session.contextFor(profile.id);
      final pendingHistory = _boundedPendingHistory(
        session.messages
            .skip(context.syncedMessageCount.clamp(0, session.messages.length))
            .where(
              (m) =>
                  m.content.isNotEmpty &&
                  (m.role == MessageRole.user ||
                      m.role == MessageRole.assistant),
            )
            .map((m) => '${m.role.name}: ${m.content}')
            .toList(),
      );
      await adapter.sendPrompt(
        pendingHistory.isEmpty
            ? text
            : '[Prior conversation context; text only, do not re-execute previous actions]\n$pendingHistory\n[End prior context]\n\n$text',
      );
      if (requestEpoch != _requestEpoch) return;
      final latest = state.activeSession;
      if (latest != null &&
          latest.id == session.id &&
          state.lastErrorCode == null &&
          state.authChallenge == null) {
        final updated = latest.copyWith(
          agentContexts: {
            ...latest.agentContexts,
            profile.id: AgentChatContext(
              remoteSessionId: adapter.sessionId,
              syncedMessageCount: latest.messages.length,
            ),
          },
        );
        _updateSessionInState(updated);
        await ref.read(chatRepositoryProvider).saveSession(updated);
      }

      // 会话此时已经建立，adapter 才知道自己到底是复用了历史会话还是新建的。
      // 在这里上报给界面：复用了就提示「已恢复」，没复用又确实是重建的，
      // 就提示「上下文已丢失」——绝不能静默，否则用户会以为上下文还在。
      final restored = adapter.restoredExistingSession;
      state = state.copyWith(
        acpSessionRestored: restored,
        acpSessionRestartDetected:
            adapterWasRebuilt && session.remoteSessionId != null && !restored,
      );
    } catch (error) {
      if (requestEpoch != _requestEpoch) return;
      state = state.copyWith(lastErrorCode: error.toString());
      await stopGeneration();
    }
  }

  String _boundedPendingHistory(List<String> messages) {
    const maxMessages = 20;
    const maxCharacters = 24000;
    final selected = <String>[];
    var characters = 0;
    for (final message in messages.reversed) {
      if (selected.length >= maxMessages ||
          characters + message.length > maxCharacters) {
        break;
      }
      selected.insert(0, message);
      characters += message.length;
    }
    return selected.join('\n\n');
  }

  AgentRuntimeCapabilities _acpCapabilities(List<SessionConfigOption> options) {
    List<ChatSettingOption> valuesFor(SessionConfigOptionCategory category) {
      final option = options
          .where(
            (entry) =>
                entry.category?.toJson() == category.toJson() &&
                entry is SessionConfigSelectOptionValue,
          )
          .cast<SessionConfigSelectOptionValue>()
          .firstOrNull;
      if (option == null) return const [];
      final raw = option.options.toJson();
      return [
        for (final entry in raw)
          if (entry is Map && entry.containsKey('value'))
            ChatSettingOption(
              entry['value'].toString(),
              entry['name']?.toString() ?? entry['value'].toString(),
              description: entry['description']?.toString(),
            )
          else if (entry is Map && entry['options'] is List)
            for (final child in entry['options'] as List)
              if (child is Map)
                ChatSettingOption(
                  child['value'].toString(),
                  child['name']?.toString() ?? child['value'].toString(),
                  description: child['description']?.toString(),
                ),
      ];
    }

    final reasoning = [
      ...valuesFor(SessionConfigOptionCategory.thoughtLevel),
      ...valuesFor(SessionConfigOptionCategory.modelConfig),
    ];
    return AgentRuntimeCapabilities(
      models: valuesFor(SessionConfigOptionCategory.model),
      reasoningLevels: reasoning,
      supportsStructuredSettings: true,
    );
  }

  Future<void> _applyAcpSettings(
    ACPClientAdapter adapter,
    List<SessionConfigOption> options,
    ChatRunSettings settings,
  ) async {
    Future<void> setCategory(
      SessionConfigOptionCategory category,
      String? value,
    ) async {
      if (value == null) return;
      final option = options
          .where(
            (entry) =>
                entry.category?.toJson() == category.toJson() &&
                entry is SessionConfigSelectOptionValue,
          )
          .cast<SessionConfigSelectOptionValue>()
          .firstOrNull;
      final availableValues = option?.options.toJson().expand<String>((
        entry,
      ) sync* {
        if (entry is Map && entry['value'] != null) {
          yield entry['value'].toString();
        } else if (entry is Map && entry['options'] is List) {
          for (final child in entry['options'] as List) {
            if (child is Map && child['value'] != null) {
              yield child['value'].toString();
            }
          }
        }
      }).toSet();
      if (option == null || !availableValues!.contains(value)) {
        return;
      }
      await adapter.setConfigOption(
        SetValueIdConfigOption(
          sessionId: adapter.sessionId!,
          configId: option.id,
          value: value,
        ),
      );
    }

    await setCategory(SessionConfigOptionCategory.model, settings.modelId);
    final reasoningCategory =
        options.any(
          (entry) =>
              entry.category?.toJson() ==
              SessionConfigOptionCategory.thoughtLevel.toJson(),
        )
        ? SessionConfigOptionCategory.thoughtLevel
        : SessionConfigOptionCategory.modelConfig;
    await setCategory(reasoningCategory, settings.reasoningId);
  }

  void _updateAssistantMessage(ChatSession session, ChatMessage msg) {
    final latest = state.sessions
        .where((entry) => entry.id == session.id)
        .firstOrNull;
    if (latest == null) return;
    final msgs = latest.messages
        .map((entry) => entry.id == msg.id ? msg : entry)
        .toList();
    final updated = latest.copyWith(messages: msgs, updatedAt: DateTime.now());
    _updateSessionInState(updated);
  }

  void _updateSessionInState(ChatSession updated) {
    final list = state.sessions
        .map((s) => s.id == updated.id ? updated : s)
        .toList();
    state = state.copyWith(sessions: list);
  }

  /// 用户确认了「上下文已丢失」的提示。
  ///
  /// 只清告警，不改 [AiChatState.acpSessionRestored]：后者描述的是
  /// 当前会话本身是否来自远端历史，与用户是否看过提示无关。
  void acknowledgeAcpSessionRestart() {
    state = state.copyWith(acpSessionRestartDetected: false);
  }

  void respondPermission(bool allow) {
    if (state.permissionCompleter != null &&
        !state.permissionCompleter!.isCompleted) {
      state.permissionCompleter!.complete(allow);
    }
    state = state.copyWith(clearPermission: true);
  }

  /// 回传用户选定的认证方式。
  ///
  /// [methodId] 为 null 表示用户放弃，仅清除引导状态，不触发认证。
  /// 选择结果记入 [AiChatState.selectedAuthMethods]，下一次发送消息时注入
  /// 新建的 adapter，在建会话前完成 `authenticate`。
  Future<void> respondAuth(String? methodId) async {
    final completer = state.authCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(methodId);
    }

    final challenge = state.authChallenge;
    final agentId = challenge?.agentId;
    final selections = Map<String, String>.from(state.selectedAuthMethods);
    if (methodId != null && agentId != null) {
      selections['${challenge?.serverId ?? _activeServerId}::$agentId'] =
          methodId;
    }

    state = state.copyWith(
      clearAuthChallenge: true,
      selectedAuthMethods: selections,
      clearError: methodId != null,
      lastErrorCode: methodId == null ? authRequiredCode : null,
    );

    if (methodId != null && challenge?.serverId == _activeServerId) {
      await _currentAdapter?.authenticate(methodId);
    }
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(() {
  return AiChatNotifier();
});
