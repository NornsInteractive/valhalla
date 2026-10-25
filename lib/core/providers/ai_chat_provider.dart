import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/session_recovery_status.dart';
export '../../data/models/session_recovery_status.dart';
import '../../data/models/acp_account_info.dart';
import '../../data/models/chat_run_settings.dart';
import '../../data/models/chat_launch_preference.dart';
import '../../data/models/native_cli_session.dart';
import '../../data/repositories/chat_repository.dart';
import '../../infrastructure/acp/acp_client_adapter.dart';
import '../../infrastructure/acp/acp_ssh_transport.dart';
import '../../infrastructure/acp/acp_runtime_service.dart';
import '../../infrastructure/acp/acp_background_run.dart';
import '../../infrastructure/acp/acp_oauth_request.dart';
import '../../infrastructure/acp/acp_attachment_store.dart';
import '../../infrastructure/acp/acp_workspace_files.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../../infrastructure/cli/agy_model_catalog.dart';
import '../../infrastructure/cli/codex_native_client.dart';
import '../../infrastructure/cli/codex_account_models.dart';
import '../../infrastructure/cli/codex_model_authorization.dart';
import '../utils/shell_quote.dart';
import '../utils/chat_failure_presentation.dart';
export '../utils/chat_failure_presentation.dart';
import '../logging/sanitizer.dart';
import '../services/app_diagnostics.dart';
import 'agent_registry_provider.dart';
import 'agent_update_lock_provider.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'security_settings_provider.dart';
import 'app_visibility_provider.dart';

/// 构造 ACP 传输：在生产环境中通过 SSH exec 通道启动 profile 的 `acpCommand`。
///
/// 抽成 provider 是为了让 provider 层测试可以注入替身，而不触碰真实 SSH。
typedef AcpTransportFactory =
    Future<Transport> Function(
      AgentProfile profile,
      SSHClient sshClient, {
      String? initialModelId,
    });

/// Production enables durable execution; isolated provider tests stay offline.
final persistentAcpRuntimeEnabledProvider = Provider<bool>((ref) => false);
final persistentAcpRuntimeOpenerProvider = Provider(
  (ref) => AcpRuntimeService.open,
);
final persistentAcpRuntimeInstallerProvider = Provider(
  (ref) => AcpRuntimeService.install,
);
final acpRuntimeInspectorProvider = Provider(
  (ref) => AcpRuntimeService.inspect,
);
final acpRuntimeManagerProvider = Provider((ref) => AcpRuntimeService.manage);
final acpServerRunsProvider = Provider(
  (ref) => AcpRuntimeService.activeForServer,
);

final acpTransportFactoryProvider = Provider<AcpTransportFactory>((ref) {
  return (profile, sshClient, {initialModelId}) async {
    if (isAgentUpdateLocked(ref, profile)) {
      throw StateError('AGENT_UPDATE_IN_PROGRESS');
    }
    final acpCommand = profile.acpCommand;
    if (acpCommand == null || acpCommand.trim().isEmpty) {
      throw StateError('Agent ${profile.id} has no ACP command');
    }
    final session = await sshClient.execute(
      agentAcpLaunchCommand(profile, initialModelId: initialModelId),
    );
    return AcpSshTransport(session);
  };
});

final acpAttachmentStoreProvider = Provider((ref) => AcpAttachmentStore());

final acpOAuthPageRendererProvider =
    Provider<String Function({required bool success})?>((ref) => null);

/// Independent CLI API discovery; never infer a catalog from session config.
/// Null means this agent has no independently supported query implementation.
typedef AgentModelQuery =
    Future<AgentRuntimeCapabilities?> Function(
      AgentProfile profile,
      SSHClient sshClient,
    );

final agentModelQueryProvider = Provider<AgentModelQuery>((ref) {
  return (profile, ssh) async {
    if (usesAntigravityAcp(profile)) return AgyModelCatalog.query(ssh, profile);
    if (nativeCliKind(profile.cliCommand) != NativeCliKind.codex) return null;
    // ponytail: CLI catalogs may be cached; refresh queries a new process,
    // not a cloud entitlement check or a separate authorization flow.
    return CodexNativeClient.queryCapabilities(ssh, profile);
  };
});

typedef AgentComposerQuery =
    Future<List<AcpSlashCommand>> Function(
      AgentProfile profile,
      SSHClient sshClient,
      String? cwd,
    );

final agentComposerQueryProvider = Provider<AgentComposerQuery>((ref) {
  return (profile, ssh, cwd) async {
    if (nativeCliKind(profile.cliCommand) != NativeCliKind.codex) {
      return const [];
    }
    final catalog = await CodexNativeClient.queryComposerCatalog(
      ssh,
      profile,
      cwd: cwd,
    );
    return [
      for (final skill in catalog.skills)
        AcpSlashCommand(
          r'$' + skill.id,
          skill.description ?? skill.label,
          null,
        ),
    ];
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

class AcpActiveRun {
  final String serverTargetKey, serverId, sessionId, agentId, agentName, state;
  final String? runtimeKey, turnId;
  const AcpActiveRun({
    required this.serverTargetKey,
    required this.serverId,
    required this.sessionId,
    required this.agentId,
    required this.agentName,
    this.runtimeKey,
    this.turnId,
    this.state = 'running',
  });
  bool get isBusy => const {
    'running',
    'waiting_permission',
    'reconnecting',
    'awaiting_authentication',
  }.contains(state);
  @override
  bool operator ==(Object other) =>
      other is AcpActiveRun &&
      other.serverTargetKey == serverTargetKey &&
      other.sessionId == sessionId &&
      other.agentId == agentId &&
      other.state == state &&
      other.runtimeKey == runtimeKey &&
      other.turnId == turnId &&
      other.agentName == agentName;
  @override
  int get hashCode => Object.hash(
    serverTargetKey,
    sessionId,
    agentId,
    state,
    runtimeKey,
    turnId,
    agentName,
  );
}

class AiChatState {
  final bool persistentRuntimeSetupRequired;
  final String? persistentRuntimeSetupError;
  final bool isSettingUpPersistentRuntime;
  final bool recoveryNoticeDismissed;
  final SessionRecoveryStatus recoveryStatus;
  final AcpAccountInfo? account;
  final String? agentVersion;
  final DateTime? settingsFetchedAt, accountStatusFetchedAt;
  final bool settingsStale;
  final String? modelCatalogError;
  final String accountStatusText;
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
  final AcpActiveRun? serverRun;
  bool get isServerBusy => isGenerating || serverRun?.isBusy == true;
  bool get isViewingRun =>
      serverRun != null &&
      serverRun!.sessionId == activeSessionId &&
      serverRun!.agentId == activeAgentProfile?.id;
  final bool isLoadingSettings;
  final bool isApplyingSettings;
  final String? draftWorkingDirectory;
  final bool isLoadingSessions;
  final bool isLoadingMessages;
  final bool hasMoreSessions;
  final List<AcpSlashCommand> commands;
  final AcpUsage? usage;
  final String diagnostics;
  final List<AcpPromptAttachment> attachments;
  final bool supportsImages;
  final bool supportsTextAttachments;
  final String draftText;
  final PermissionRequest? pendingPermission;
  final Completer<String?>? permissionCompleter;

  /// 非 null 表示 agent 要求认证，等待用户选择认证方式。
  final AuthChallenge? authChallenge;
  final AcpOAuthRequest? authRequest;
  final bool isAuthenticating;
  final bool authenticationConfirmed;
  final String? authError;

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
    this.persistentRuntimeSetupRequired = false,
    this.persistentRuntimeSetupError,
    this.isSettingUpPersistentRuntime = false,
    this.recoveryNoticeDismissed = false,
    this.recoveryStatus = SessionRecoveryStatus.idle,
    this.account,
    this.agentVersion,
    this.settingsFetchedAt,
    this.accountStatusFetchedAt,
    this.settingsStale = true,
    this.modelCatalogError,
    this.accountStatusText = '',
    this.runSettings = const ChatRunSettings(),
    this.capabilities = const AgentRuntimeCapabilities(),
    this.shareAgentSessions = false,
    this.sessions = const [],
    this.activeSessionId,
    this.readyAgents = const [],
    this.activeAgentProfile,
    this.isGenerating = false,
    this.serverRun,
    this.isLoadingSettings = false,
    this.isApplyingSettings = false,
    this.draftWorkingDirectory,
    this.isLoadingSessions = false,
    this.isLoadingMessages = false,
    this.hasMoreSessions = false,
    this.commands = const [],
    this.usage,
    this.diagnostics = '',
    this.attachments = const [],
    this.supportsImages = false,
    this.supportsTextAttachments = false,
    this.draftText = '',
    this.pendingPermission,
    this.permissionCompleter,
    this.authChallenge,
    this.authRequest,
    this.isAuthenticating = false,
    this.authenticationConfirmed = false,
    this.authError,
    this.authCompleter,
    this.selectedAuthMethods = const {},
    this.lastErrorCode,
    this.acpSessionRestored,
    this.acpSessionRestartDetected = false,
  });

  ChatSession? get activeSession {
    if (sessions.isEmpty) return null;
    if (activeSessionId == null) return null;
    return sessions.where((s) => s.id == activeSessionId).firstOrNull;
  }

  ChatFailurePresentation? get failure => classifyChatFailure(lastErrorCode);

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
    bool? persistentRuntimeSetupRequired,
    String? persistentRuntimeSetupError,
    bool clearPersistentRuntimeSetupError = false,
    bool? isSettingUpPersistentRuntime,
    bool? recoveryNoticeDismissed,
    SessionRecoveryStatus? recoveryStatus,
    AcpAccountInfo? account,
    String? agentVersion,
    DateTime? settingsFetchedAt,
    accountStatusFetchedAt,
    bool? settingsStale,
    String? modelCatalogError,
    bool clearModelCatalogError = false,
    String? accountStatusText,
    bool clearAccount = false,
    bool clearSettingsMetadata = false,
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
    AcpActiveRun? serverRun,
    bool clearServerRun = false,
    bool? isLoadingSettings,
    bool? isApplyingSettings,
    String? draftWorkingDirectory,
    bool clearDraftWorkingDirectory = false,
    bool? isLoadingSessions,
    bool? isLoadingMessages,
    bool? hasMoreSessions,
    List<AcpSlashCommand>? commands,
    AcpUsage? usage,
    bool clearUsage = false,
    String? diagnostics,
    List<AcpPromptAttachment>? attachments,
    bool? supportsImages,
    bool? supportsTextAttachments,
    String? draftText,
    PermissionRequest? pendingPermission,
    Completer<String?>? permissionCompleter,
    AuthChallenge? authChallenge,
    AcpOAuthRequest? authRequest,
    bool? isAuthenticating,
    bool? authenticationConfirmed,
    String? authError,
    bool clearAuthRequest = false,
    bool clearAuthError = false,
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
      persistentRuntimeSetupRequired:
          persistentRuntimeSetupRequired ?? this.persistentRuntimeSetupRequired,
      persistentRuntimeSetupError: clearPersistentRuntimeSetupError
          ? null
          : persistentRuntimeSetupError ?? this.persistentRuntimeSetupError,
      isSettingUpPersistentRuntime:
          isSettingUpPersistentRuntime ?? this.isSettingUpPersistentRuntime,
      recoveryNoticeDismissed:
          recoveryNoticeDismissed ?? this.recoveryNoticeDismissed,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      account: clearAccount ? null : account ?? this.account,
      agentVersion: clearSettingsMetadata
          ? null
          : agentVersion ?? this.agentVersion,
      settingsFetchedAt: clearSettingsMetadata
          ? null
          : settingsFetchedAt ?? this.settingsFetchedAt,
      settingsStale: settingsStale ?? this.settingsStale,
      modelCatalogError: clearModelCatalogError
          ? null
          : modelCatalogError ?? this.modelCatalogError,
      accountStatusText: clearAccount
          ? ''
          : accountStatusText ?? this.accountStatusText,
      accountStatusFetchedAt: clearAccount
          ? null
          : accountStatusFetchedAt ?? this.accountStatusFetchedAt,
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
      serverRun: clearServerRun ? null : serverRun ?? this.serverRun,
      isLoadingSettings: isLoadingSettings ?? this.isLoadingSettings,
      isApplyingSettings: isApplyingSettings ?? this.isApplyingSettings,
      isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      hasMoreSessions: hasMoreSessions ?? this.hasMoreSessions,
      commands: commands ?? this.commands,
      usage: clearUsage ? null : usage ?? this.usage,
      diagnostics: diagnostics ?? this.diagnostics,
      attachments: attachments ?? this.attachments,
      supportsImages: supportsImages ?? this.supportsImages,
      supportsTextAttachments:
          supportsTextAttachments ?? this.supportsTextAttachments,
      draftText: draftText ?? this.draftText,
      draftWorkingDirectory: clearDraftWorkingDirectory
          ? null
          : draftWorkingDirectory ?? this.draftWorkingDirectory,
      pendingPermission: clearPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      permissionCompleter: clearPermission
          ? null
          : (permissionCompleter ?? this.permissionCompleter),
      authChallenge: clearAuthChallenge
          ? null
          : (authChallenge ?? this.authChallenge),
      authRequest: clearAuthChallenge || clearAuthRequest
          ? null
          : authRequest ?? this.authRequest,
      isAuthenticating: clearAuthChallenge
          ? false
          : isAuthenticating ?? this.isAuthenticating,
      authenticationConfirmed:
          authenticationConfirmed ?? this.authenticationConfirmed,
      authError: clearAuthChallenge || clearAuthError
          ? null
          : authError ?? this.authError,
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
  final Map<String, AcpBackgroundRun> _backgroundRuns = {};
  Future<void>? _parking;
  Future<void>? _adopting;
  Future<void>? _discoveringRun;
  String? _discoveringTarget;
  String? get _serverTargetKey =>
      ref.read(activeServerProvider)?.connectionKey.toString();

  AcpActiveRun _runSummary(AcpBackgroundRun run) => AcpActiveRun(
    serverTargetKey: run.serverTargetKey,
    serverId: run.profile.serverId,
    sessionId: run.session.id,
    agentId: run.profile.id,
    agentName: run.profile.name,
    runtimeKey: run.adapter.persistentRuntimeKey,
    turnId: run.turnId,
    state: run.state,
  );

  void _backgroundChanged(AcpBackgroundRun run) {
    if (!ref.mounted ||
        !identical(_backgroundRuns[run.serverTargetKey], run) ||
        _serverTargetKey != run.serverTargetKey) {
      return;
    }
    final viewing =
        state.activeSessionId == run.session.id &&
        state.activeAgentProfile?.id == run.profile.id;
    final pending = viewing ? run.pendingPermission : null;
    var snapshot = run.session;
    final visible = state.activeSession;
    if (viewing &&
        visible != null &&
        visible.messageOffset < snapshot.messageOffset) {
      final prefix = snapshot.messageOffset - visible.messageOffset;
      snapshot = snapshot.copyWith(
        messageOffset: visible.messageOffset,
        messages: [...visible.messages.take(prefix), ...snapshot.messages],
      );
    }
    state = state.copyWith(
      sessions: state.sessions
          .map((session) => session.id == run.session.id ? snapshot : session)
          .toList(),
      serverRun: run.isBusy ? _runSummary(run) : null,
      clearServerRun: !run.isBusy,
      isGenerating: viewing && run.isBusy && run.state != 'reconnecting',
      recoveryStatus: viewing
          ? (run.state == 'reconnecting'
                ? SessionRecoveryStatus.reconnecting
                : SessionRecoveryStatus.idle)
          : state.recoveryStatus,
      diagnostics: viewing && run.error != null ? run.error : state.diagnostics,
      pendingPermission: pending?.request,
      permissionCompleter: pending?.responseCompleter,
      clearPermission: pending == null,
    );
  }

  Future<void> _parkRunningView() =>
      _parking ??= _parkRunningViewOnce().whenComplete(() => _parking = null);

  Future<void> _parkRunningViewOnce() async {
    final target = _serverTargetKey;
    final existing = _backgroundRuns[target];
    if (existing != null || !state.isGenerating) {
      return;
    }
    final adapter = _currentAdapter;
    final profile = state.activeAgentProfile;
    if (target == null ||
        adapter == null ||
        profile == null ||
        adapter.sessionId == null ||
        _isPreparingPrompt) {
      throw StateError('ACP_RUN_PREPARING');
    }
    final snapshot = await _captureRuntimeSnapshot();
    if (!ref.mounted ||
        _serverTargetKey != target ||
        snapshot == null ||
        !identical(adapter, _currentAdapter) ||
        profile.id != state.activeAgentProfile?.id) {
      return;
    }
    final pending = <ACPPermissionRequestEvent>[
      if (state.pendingPermission != null &&
          state.permissionCompleter != null &&
          !state.permissionCompleter!.isCompleted)
        ACPPermissionRequestEvent(
          request: state.pendingPermission!,
          responseCompleter: state.permissionCompleter!,
        ),
      ..._permissionQueue,
    ];
    _permissionQueue.clear();
    _requestEpoch++;
    _streamTimer?.cancel();
    _checkpointTimer?.cancel();
    _flushStream = null;
    final previous = _acpSub;
    _acpSub = null;
    _currentAdapter = null;
    _currentAdapterLaunchKey = null;
    final repo = ref.read(chatRepositoryProvider);
    late final AcpBackgroundRun run;
    run = AcpBackgroundRun(
      serverTargetKey: target,
      profile: profile,
      adapter: adapter,
      session: snapshot,
      policy: state.runSettings.permissionPolicy,
      turnId:
          adapter.persistentTurnId ??
          snapshot.messages.last.runtimeTurnId ??
          snapshot.messages.last.id,
      attachments: ref.read(acpAttachmentStoreProvider),
      save: repo.saveSession,
      permissions: pending,
      onChanged: () => _backgroundChanged(run),
    );
    _backgroundRuns[target] = run;
    if (pending.isNotEmpty) run.state = 'waiting_permission';
    run.listen();
    unawaited(previous?.cancel());
    _backgroundChanged(run);
    await run.checkpoint();
  }

  Future<void> returnToRunningSession() async {
    final run = _backgroundRuns[_serverTargetKey];
    if (run == null) {
      return;
    }
    if (state.activeAgentProfile?.id != run.profile.id) {
      await switchAgent(run.profile.id);
    }
    if (!ref.mounted ||
        _serverTargetKey != run.serverTargetKey ||
        state.activeAgentProfile?.id != run.profile.id) {
      return;
    }
    if (!state.sessions.any((session) => session.id == run.session.id)) {
      state = state.copyWith(sessions: [...state.sessions, run.session]);
    }
    await selectSession(run.session.id);
    _backgroundChanged(run);
  }

  Future<void> _adoptFinishedRun() => _adopting ??= _adoptFinishedRunOnce()
      .whenComplete(() => _adopting = null);

  Future<void> _adoptFinishedRunOnce() async {
    final key = _serverTargetKey;
    final run = _backgroundRuns[key];
    if (run == null || run.isBusy) {
      return;
    }
    final adopting =
        state.activeSessionId == run.session.id &&
        state.activeAgentProfile?.id == run.profile.id &&
        !run.session.contextFor(run.profile.id).runtimeRestartPending;
    await run.detach(disposeAdapter: !adopting);
    if (!identical(_backgroundRuns[key], run)) {
      return;
    }
    _backgroundRuns.remove(key);
    if (!ref.mounted ||
        _serverTargetKey != key ||
        state.activeSessionId != run.session.id ||
        !adopting) {
      if (adopting) run.adapter.dispose();
      if (ref.mounted && _serverTargetKey == key) {
        state = state.copyWith(clearServerRun: true);
      }
      return;
    }
    _currentAdapter?.dispose();
    _currentAdapter = run.adapter;
    _currentAdapterAgentId = run.profile.id;
    _currentAdapterSessionId = run.session.id;
    _currentAdapterServerId = run.profile.serverId;
    _currentAdapterLaunchKey = _launchKey(run.profile);
    _currentAdapterInitialModelId = _initialModelFor(run.profile);
    state = state.copyWith(clearServerRun: true, isGenerating: false);
  }

  Future<void> _reconnectBackground(
    AcpBackgroundRun run,
    SSHClient client,
  ) async {
    if (!run.isBusy) {
      _backgroundChanged(run);
      return;
    }
    if (run.isAttached && run.state != 'reconnecting') {
      _backgroundChanged(run);
      return;
    }
    final context = run.session.contextFor(run.profile.id);
    final key = context.persistentRuntimeKey;
    if (key == null) {
      run.state = 'failed';
      run.error = 'ACP_HISTORY_REPLAY_UNSUPPORTED';
      _backgroundChanged(run);
      return;
    }
    try {
      final transport = await ref.read(persistentAcpRuntimeOpenerProvider)(
        client,
        run.profile,
        runtimeKey: key,
        afterSequence: context.runtimeCursor,
        remoteSessionId: context.remoteSessionId,
      );
      if (!ref.mounted ||
          !identical(_backgroundRuns[run.serverTargetKey], run)) {
        await transport.close();
        return;
      }
      final adapter = ACPClientAdapter(
        profile: run.profile,
        transport: transport,
        workingDirectory: run.session.workingDirectory,
        resumeSessionId: context.remoteSessionId,
      );
      adapter.onSessionEstablished = (id) {
        run.session = run.session.copyWith(
          agentContexts: {
            ...run.session.agentContexts,
            run.profile.id: run.session
                .contextFor(run.profile.id)
                .copyWith(remoteSessionId: id),
          },
        );
      };
      final auth = state
          .selectedAuthMethods['${run.profile.serverId}::${run.profile.id}'];
      if (auth != null) await adapter.authenticate(auth);
      await run.reattach(adapter);
      _backgroundChanged(run);
    } catch (error) {
      run.error = LogSanitizer.sanitize(error.toString());
      run.state = 'reconnecting';
      _backgroundChanged(run);
    }
  }

  Future<void> _discoverRunningTask(SSHClient client, String serverId) {
    final target = _serverTargetKey;
    if (_discoveringTarget == target && _discoveringRun != null) {
      return _discoveringRun!;
    }
    _discoveringTarget = target;
    late final Future<void> future;
    future = _discoverRunningTaskOnce(client, serverId).whenComplete(() {
      if (identical(_discoveringRun, future)) {
        _discoveringRun = null;
        _discoveringTarget = null;
      }
    });
    _discoveringRun = future;
    return future;
  }

  Future<void> _discoverRunningTaskOnce(
    SSHClient client,
    String serverId,
  ) async {
    if (_backgroundRuns[_serverTargetKey]?.isBusy == true ||
        state.isGenerating ||
        _currentAdapter != null ||
        !ref.read(persistentAcpRuntimeEnabledProvider)) {
      return;
    }
    final target = _serverTargetKey;
    final runs = await ref.read(acpServerRunsProvider)(client, serverId);
    if (!ref.mounted || target != _serverTargetKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    for (final remote in runs.where((run) => run.isBusy)) {
      final session = await ref
          .read(chatRepositoryProvider)
          .findRuntimeSession(serverId, remote.runtimeKey);
      if (!ref.mounted || target != _serverTargetKey) {
        throw StateError('ACP_TARGET_CHANGED');
      }
      final agentId = session?.agentContexts.entries
          .where(
            (entry) => entry.value.persistentRuntimeKey == remote.runtimeKey,
          )
          .firstOrNull
          ?.key;
      final profile = state.readyAgents
          .where((profile) => profile.id == agentId)
          .firstOrNull;
      if (session == null || profile == null || target == null) {
        throw StateError('ACP_RUNTIME_SERVER_BUSY');
      }
      final transport = await ref.read(persistentAcpRuntimeOpenerProvider)(
        client,
        profile,
        runtimeKey: remote.runtimeKey,
        afterSequence: session.contextFor(profile.id).runtimeCursor,
        remoteSessionId: session.contextFor(profile.id).remoteSessionId,
      );
      if (!ref.mounted || target != _serverTargetKey) {
        await transport.close();
        throw StateError('ACP_TARGET_CHANGED');
      }
      final adapter = ACPClientAdapter(
        profile: profile,
        transport: transport,
        workingDirectory: session.workingDirectory,
        resumeSessionId: session.contextFor(profile.id).remoteSessionId,
      );
      late final AcpBackgroundRun run;
      run = AcpBackgroundRun(
        serverTargetKey: target,
        profile: profile,
        adapter: adapter,
        session: session,
        policy:
            session.agentRunSettings[profile.id]?.permissionPolicy ??
            OperationPermissionPolicy.askEveryTime,
        attachments: ref.read(acpAttachmentStoreProvider),
        save: ref.read(chatRepositoryProvider).saveSession,
        turnId:
            remote.turnId ??
            session.messages.lastOrNull?.runtimeTurnId ??
            session.messages.lastOrNull?.id ??
            remote.runtimeKey,
        onChanged: () => _backgroundChanged(run),
      );
      _backgroundRuns[target] = run;
      run.listen();
      _backgroundChanged(run);
      await adapter.prepareSession();
      await run.checkpoint();
      return;
    }
  }

  final List<ACPEvent> _recoveredRuntimeEvents = [];
  final Set<Future<void>> _runtimeWrites = {};
  Timer? _recoveredRuntimeTimer;
  Future<void>? _runtimeSaving;
  int _runtimeSetupEpoch = 0;

  Future<void> _trackRuntimeWrite(Future<void> write) {
    _runtimeWrites.add(write);
    unawaited(
      write
          .whenComplete(() => _runtimeWrites.remove(write))
          .catchError((Object _) {}),
    );
    return write;
  }

  Future<void> _savePersistentCheckpoint() => _runtimeSaving ??= (() async {
    final snapshot = await _captureRuntimeSnapshot();
    if (!ref.mounted) {
      return;
    }
    if (snapshot == null || _currentAdapter?.isPersistent != true) {
      return;
    }
    await ref.read(chatRepositoryProvider).saveSession(snapshot);
  })().whenComplete(() => _runtimeSaving = null);

  Future<ChatSession?> _captureRuntimeSnapshot() async {
    while (ref.mounted) {
      _flushStream?.call();
      _flushRecoveredRuntimeEvents();
      if (_runtimeWrites.isEmpty) {
        final current = state.activeSession;
        return current == null ? null : _runtimeSnapshot(current);
      }
      await Future.wait(_runtimeWrites.toList());
    }
    return null;
  }

  void _handleRecoveredRuntimeEvent(ACPEvent event, ACPClientAdapter adapter) {
    if (!ref.mounted || !identical(adapter, _currentAdapter)) {
      return;
    }
    if (event is ACPPermissionRequestEvent) {
      if (state.pendingPermission?.id == event.request.id) {
        return;
      }
      if (state.permissionCompleter != null &&
          !state.permissionCompleter!.isCompleted) {
        _permissionQueue.add(event);
      } else {
        state = state.copyWith(
          pendingPermission: event.request,
          permissionCompleter: event.responseCompleter,
        );
      }
      return;
    }
    _recoveredRuntimeEvents.add(event);
    _recoveredRuntimeTimer ??= Timer(
      const Duration(milliseconds: 50),
      _flushRecoveredRuntimeEvents,
    );
  }

  void _flushRecoveredRuntimeEvents() {
    _recoveredRuntimeTimer?.cancel();
    _recoveredRuntimeTimer = null;
    if (!ref.mounted || _recoveredRuntimeEvents.isEmpty) {
      return;
    }
    final events = List<ACPEvent>.of(_recoveredRuntimeEvents);
    _recoveredRuntimeEvents.clear();
    final session = state.activeSession;
    final profile = state.activeAgentProfile;
    if (session == null || profile == null) {
      return;
    }
    final messages = List<ChatMessage>.of(session.messages);
    final text = <String, StringBuffer>{};
    final thinking = <String, StringBuffer>{};
    var generating = state.isGenerating;
    var recovered = state.recoveryStatus;
    var clearPermission = false;
    int? syncedThrough;
    for (final event in events) {
      final turnId = event.runtimeTurnId;
      if (event is ACPPersistentStatusEvent && !event.settled) {
        continue;
      }
      if (event is ACPPersistentStatusEvent && event.caughtUp) {
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].role == MessageRole.assistant &&
              messages[i].runtimeTurnId != turnId &&
              const [
                ChatTurnStatus.streaming,
                ChatTurnStatus.unknown,
              ].contains(messages[i].status)) {
            messages[i] = messages[i].copyWith(
              status: ChatTurnStatus.interrupted,
              failureCode: 'ACP_RUNTIME_PROMPT_NOT_ACCEPTED',
            );
          }
        }
        if (turnId == null) {
          generating = false;
          recovered = SessionRecoveryStatus.idle;
          continue;
        }
      }
      if (turnId == null) continue;
      final previousGenerating = generating;
      final previousRecovered = recovered;
      final previousClearPermission = clearPermission;
      var index = messages.lastIndexWhere(
        (m) =>
            m.role == MessageRole.assistant &&
            (m.id == turnId || m.runtimeTurnId == turnId),
      );
      if (index < 0) continue;
      var message = messages[index];
      final remoteId = switch (event) {
        ACPContentChunkEvent(:final messageId) => messageId,
        ACPThinkingChunkEvent(:final messageId) => messageId,
        ACPAttachmentEvent(:final messageId) => messageId,
        _ => null,
      };
      if (remoteId != null) {
        final match = messages.indexWhere(
          (m) =>
              m.remoteMessageId == remoteId &&
              (m.id == turnId || m.runtimeTurnId == turnId),
        );
        if (match >= 0) {
          index = match;
          message = messages[index];
        } else if (message.remoteMessageId != null &&
            message.remoteMessageId != remoteId) {
          messages[index] = message.copyWith(status: ChatTurnStatus.completed);
          message = ChatMessage(
            id: _uuid.v4(),
            runtimeTurnId: turnId,
            remoteMessageId: remoteId,
            agentId: profile.id,
            role: MessageRole.assistant,
            content: '',
            status: ChatTurnStatus.streaming,
            createdAt: DateTime.now(),
          );
          messages.add(message);
          index = messages.length - 1;
        } else {
          message = message.copyWith(remoteMessageId: remoteId);
        }
      }
      if (event is ACPContentChunkEvent) {
        final buffer = text.putIfAbsent(
          message.id,
          () => StringBuffer(message.content),
        );
        final start = buffer.length;
        buffer.write(event.chunk);
        message = message.copyWith(
          contentBlocks: ChatContentBlock.appendText(
            message.contentBlocks,
            start,
            buffer.length,
          ),
          status: ChatTurnStatus.streaming,
        );
        generating = true;
      } else if (event is ACPThinkingChunkEvent) {
        thinking
            .putIfAbsent(message.id, () => StringBuffer(message.thinking ?? ''))
            .write(event.chunk);
      } else if (event is ACPToolExecutionEvent) {
        final owner = messages.indexWhere(
          (m) =>
              (m.id == turnId || m.runtimeTurnId == turnId) &&
              m.toolExecutions.any((t) => t.id == event.toolExecution.id),
        );
        if (owner >= 0) {
          index = owner;
          message = messages[index];
        }
        message = message.copyWith(
          toolExecutions: [
            ...message.toolExecutions.where(
              (t) => t.id != event.toolExecution.id,
            ),
            event.toolExecution,
          ],
          contentBlocks: ChatContentBlock.appendTool(
            message.contentBlocks,
            event.toolExecution.id,
          ),
        );
      } else if (event is ACPPlanUpdateEvent) {
        message = message.copyWith(planSteps: event.planSteps);
      } else if (event is ACPAttachmentEvent) {
        final messageId = message.id;
        final sessionId = session.id;
        final epoch = _requestEpoch;
        final write = ref
            .read(acpAttachmentStoreProvider)
            .fromBlock(event.content)
            .then<void>((attachment) {
              if (!ref.mounted ||
                  epoch != _requestEpoch ||
                  state.activeSessionId != sessionId) {
                return;
              }
              final current = state.activeSession!;
              final target = current.messages
                  .where((m) => m.id == messageId)
                  .firstOrNull;
              if (target != null) {
                _updateAssistantMessage(
                  current,
                  target.copyWith(
                    attachments: [...target.attachments, attachment],
                  ),
                );
              }
            })
            .catchError((Object error) {
              if (ref.mounted) {
                state = state.copyWith(
                  lastErrorCode: 'ACP_ATTACHMENT_SAVE_FAILED: $error',
                );
              }
            });
        _trackRuntimeWrite(write);
      } else if (event is ACPCompleteEvent ||
          (event is ACPPersistentStatusEvent && event.status == 'completed')) {
        message = message.copyWith(
          status: ChatTurnStatus.completed,
          clearFailure: true,
        );
        generating = false;
        recovered = SessionRecoveryStatus.idle;
        clearPermission = true;
        syncedThrough = session.messageOffset + index + 1;
      } else if (event is ACPErrorEvent ||
          (event is ACPPersistentStatusEvent &&
              const ['exited', 'failed'].contains(event.status))) {
        message = message.copyWith(
          status: ChatTurnStatus.failed,
          failureCode: event is ACPErrorEvent
              ? event.error
              : 'ACP_RUNTIME_AGENT_EXITED',
        );
        generating = false;
        recovered = SessionRecoveryStatus.failed;
      } else if (event is ACPPersistentStatusEvent &&
          event.status == 'cancelled') {
        message = message.copyWith(
          status: ChatTurnStatus.interrupted,
          clearFailure: true,
        );
        generating = false;
        recovered = SessionRecoveryStatus.idle;
        clearPermission = true;
      } else if (event is ACPPersistentStatusEvent &&
          const ['running', 'waiting_permission'].contains(event.status)) {
        generating = true;
        recovered = SessionRecoveryStatus.idle;
        message = message.copyWith(status: ChatTurnStatus.streaming);
      }
      messages[index] = message;
      if (turnId != _currentAdapter?.persistentTurnId) {
        generating = previousGenerating;
        recovered = previousRecovered;
        clearPermission = previousClearPermission;
      }
    }
    _updateSessionInState(
      session.copyWith(
        agentContexts: syncedThrough == null
            ? null
            : {
                ...session.agentContexts,
                profile.id: session
                    .contextFor(profile.id)
                    .copyWith(syncedMessageCount: syncedThrough),
              },
        messages: [
          for (final message in messages)
            message.copyWith(
              content: text[message.id]?.toString(),
              thinking: thinking[message.id]?.toString(),
            ),
        ],
      ),
    );
    state = state.copyWith(
      isGenerating: generating,
      clearServerRun:
          !generating && _backgroundRuns[_serverTargetKey]?.isBusy != true,
      serverRun: generating
          ? AcpActiveRun(
              serverTargetKey: _serverTargetKey!,
              serverId: profile.serverId,
              sessionId: session.id,
              agentId: profile.id,
              agentName: profile.name,
              runtimeKey: _currentAdapter?.persistentRuntimeKey,
              turnId: _currentAdapter?.persistentTurnId,
            )
          : null,
      recoveryStatus: recovered,
      recoveryNoticeDismissed:
          recovered == SessionRecoveryStatus.failed &&
              state.recoveryStatus != SessionRecoveryStatus.failed
          ? false
          : null,
      clearPermission: clearPermission,
    );
  }

  Future<void> _recoverPersistentRuntime(
    ChatSession session,
    AgentProfile profile,
  ) async {
    final epoch = _requestEpoch;
    final serverId = _activeServerId;
    state = state.copyWith(recoveryStatus: SessionRecoveryStatus.syncing);
    try {
      final client = serverId == null
          ? null
          : ref.read(sshClientManagerProvider).getClient(serverId);
      if (client == null) throw StateError(disconnectedCode);
      final adapter = await _adapterFor(profile, client);
      if (!ref.mounted ||
          epoch != _requestEpoch ||
          state.activeSessionId != session.id) {
        return;
      }
      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen((event) {
        if (!ref.mounted ||
            epoch != _requestEpoch ||
            state.activeSessionId != session.id) {
          return;
        }
        _handleControlEvent(event, adapter);
        _handleRecoveredRuntimeEvent(event, adapter);
      });
      final auth =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (auth != null) await adapter.authenticate(auth);
      await adapter.prepareSession();
      if (!ref.mounted ||
          epoch != _requestEpoch ||
          state.activeSessionId != session.id) {
        return;
      }
      _flushRecoveredRuntimeEvents();
      state = state.copyWith(
        recoveryStatus: state.recoveryStatus == SessionRecoveryStatus.failed
            ? SessionRecoveryStatus.failed
            : adapter.transport is AcpSshTransport &&
                  !(adapter.transport as AcpSshTransport).backlogCaughtUp
            ? SessionRecoveryStatus.syncing
            : SessionRecoveryStatus.idle,
      );
      _checkpointTimer?.cancel();
      _checkpointTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (ref.mounted && epoch == _requestEpoch) {
          unawaited(
            _savePersistentCheckpoint().catchError((Object error) {
              if (ref.mounted) {
                state = state.copyWith(
                  lastErrorCode: 'CHAT_SAVE_FAILED: $error',
                );
              }
            }),
          );
          if (!state.isGenerating &&
              state.recoveryStatus != SessionRecoveryStatus.syncing) {
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
      await _savePersistentCheckpoint();
    } catch (error) {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          recoveryStatus: SessionRecoveryStatus.failed,
          recoveryNoticeDismissed: false,
          diagnostics: LogSanitizer.sanitize(error.toString()),
        );
      }
    }
  }

  String? get _persistentConsentIdentity {
    final server = ref.read(activeServerProvider);
    return server == null
        ? null
        : AcpRuntimeService.identity(server.connectionKey.toString());
  }

  Future<bool> approvePersistentRuntime() async {
    if (state.isSettingUpPersistentRuntime || state.isGenerating) {
      return false;
    }
    final server = ref.read(activeServerProvider);
    final identity = _persistentConsentIdentity;
    final client = server == null
        ? null
        : ref.read(sshClientManagerProvider).getClient(server.id);
    if (identity == null || client == null) {
      return false;
    }
    final setupEpoch = ++_runtimeSetupEpoch;
    state = state.copyWith(
      isSettingUpPersistentRuntime: true,
      clearPersistentRuntimeSetupError: true,
    );
    try {
      await ref.read(persistentAcpRuntimeInstallerProvider)(client);
      if (!ref.mounted || identity != _persistentConsentIdentity) {
        return false;
      }
      await ref
          .read(localStorageServiceProvider)
          .setPersistentAcpConsent(identity);
      if (!ref.mounted || identity != _persistentConsentIdentity) {
        return false;
      }
      _resetAdapter(preserveDraftWorkingDirectory: true);
      state = state.copyWith(
        persistentRuntimeSetupRequired: false,
        isSettingUpPersistentRuntime: false,
        clearPersistentRuntimeSetupError: true,
      );
      return true;
    } catch (error) {
      if (ref.mounted && identity == _persistentConsentIdentity) {
        state = state.copyWith(
          persistentRuntimeSetupError: LogSanitizer.sanitize(error.toString()),
        );
      }
      return false;
    } finally {
      if (ref.mounted && setupEpoch == _runtimeSetupEpoch) {
        state = state.copyWith(isSettingUpPersistentRuntime: false);
      }
    }
  }

  void dismissPersistentRuntimeSetup() =>
      state = state.copyWith(persistentRuntimeSetupRequired: false);
  void dismissRecoveryNotice() =>
      state = state.copyWith(recoveryNoticeDismissed: true);

  ChatSession _runtimeSnapshot(ChatSession session) {
    final adapter = _currentAdapter;
    final profile = state.activeAgentProfile;
    if (adapter == null ||
        !adapter.isPersistent ||
        profile == null ||
        session.id != _currentAdapterSessionId) {
      return session;
    }
    final updated = session.copyWith(
      agentContexts: {
        ...session.agentContexts,
        profile.id: session
            .contextFor(profile.id)
            .copyWith(
              persistentRuntimeKey: adapter.persistentRuntimeKey,
              runtimeCursor: adapter.runtimeCursor,
            ),
      },
    );
    _updateSessionInState(updated);
    return updated;
  }

  void _handleIdleRuntimeEvent(ACPEvent event, ACPClientAdapter adapter) {
    _handleControlEvent(event, adapter);
    if (adapter.isPersistent) _handleRecoveredRuntimeEvent(event, adapter);
  }

  AcpWorkspaceFiles? _workspaceFiles;
  String? _workspaceTarget;
  final Map<String, Uint8List> _previewCache = {};
  Future<void> _previewTail = Future.value();
  int _browseEpoch = 0;

  AcpWorkspaceFiles _files() {
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client = serverId == null
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) throw StateError(disconnectedCode);
    final target = '$serverId::${profile.id}::${_launchKey(profile)}';
    if (_workspaceTarget != target || _workspaceFiles == null) {
      cancelWorkspaceBrowse();
      _workspaceTarget = target;
      _workspaceFiles = AcpWorkspaceFiles(client, profile);
    }
    return _workspaceFiles!;
  }

  void cancelWorkspaceBrowse() {
    _browseEpoch++;
    _workspaceFiles?.close();
    _workspaceFiles = null;
    _workspaceTarget = null;
    _previewCache.clear();
  }

  Future<String> resolveWorkspaceDirectory() async {
    final files = _files();
    final key = _draftKey;
    final explicit =
        state.activeSession?.workingDirectory ?? state.draftWorkingDirectory;
    final path = explicit != null && explicit.startsWith('/')
        ? AcpWorkspaceFiles.normalize(explicit)
        : await files.defaultDirectory();
    if (!ref.mounted ||
        key != _draftKey ||
        !identical(files, _workspaceFiles)) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    return path;
  }

  Future<List<SftpFileItem>> listWorkspaceFiles(String path) async {
    final files = _files();
    final key = _draftKey;
    final result = await files.list(path);
    if (!ref.mounted ||
        key != _draftKey ||
        !identical(files, _workspaceFiles)) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    return result;
  }

  Future<Uint8List?> remoteImagePreview(SftpFileItem item) async {
    if (item.isDirectory ||
        !(AcpWorkspaceFiles.mimeType(item.name)?.startsWith('image/') ??
            false) ||
        item.sizeBytes > 2 * 1024 * 1024) {
      return null;
    }
    final files = _files();
    final epoch = _browseEpoch;
    final key =
        '$_workspaceTarget::${item.path}::${item.sizeBytes}::${item.modifiedEpoch}';
    if (_previewCache.containsKey(key)) return _previewCache[key];
    final future = _previewTail.then<Uint8List?>((_) async {
      if (epoch != _browseEpoch || !ref.mounted) return null;
      final cached = _previewCache[key];
      if (cached != null) return cached;
      final Uint8List bytes;
      try {
        bytes = await files.read(item.path, 2 * 1024 * 1024);
      } catch (_) {
        if (epoch != _browseEpoch || !ref.mounted) return null;
        rethrow;
      }
      if (epoch != _browseEpoch || !ref.mounted) return null;
      while (_previewCache.isNotEmpty &&
          (_previewCache.length >= 24 ||
              _previewCache.values.fold<int>(0, (n, b) => n + b.length) +
                      bytes.length >
                  8 * 1024 * 1024)) {
        _previewCache.remove(_previewCache.keys.first);
      }
      _previewCache[key] = bytes;
      return bytes;
    });
    _previewTail = future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }

  Future<void> queryAccountStatus() async {
    if (state.activeSession == null ||
        state.isAuthenticating ||
        state.isGenerating ||
        _isPreparingPrompt ||
        state.isLoadingSettings ||
        state.isApplyingSettings ||
        state.isLoadingMessages ||
        state.isLoadingSessions ||
        state.attachments.isNotEmpty ||
        !state.commands.any((c) => c.name == 'status')) {
      throw StateError('ACP_STATUS_QUERY_UNAVAILABLE');
    }
    final key = _draftKey;
    final text = state.draftText;
    final previousMessageId = state.activeSession?.messages.lastOrNull?.id;
    await sendMessage('/status');
    if (!ref.mounted || key != _draftKey) {
      return;
    }
    final message = state.activeSession?.messages.lastOrNull;
    if (state.lastErrorCode == null &&
        message?.id != previousMessageId &&
        message?.role == MessageRole.assistant &&
        message?.status == ChatTurnStatus.completed) {
      state = state.copyWith(
        accountStatusText: message!.content,
        accountStatusFetchedAt: DateTime.now(),
      );
    }
    updateDraftText(text);
  }

  int get activeConnectionCount =>
      (_currentAdapter != null || _isPreparingPrompt ? 1 : 0) +
      _backgroundRuns.values.where((run) => run.isAttached).length;

  /// Remote work may start before a visible loading flag changes.
  bool get isRuntimeBusy =>
      (_discoveringRun != null && _discoveringTarget == _serverTargetKey) ||
      _backgroundRuns[_serverTargetKey]?.isBusy == true ||
      _isPreparingPrompt ||
      state.isGenerating ||
      state.isAuthenticating ||
      state.authChallenge != null ||
      state.authRequest != null ||
      (state.authCompleter != null && !state.authCompleter!.isCompleted) ||
      _authCallbackInFlight ||
      _authorizationCancelled != null ||
      state.pendingPermission != null ||
      (state.permissionCompleter != null &&
          !state.permissionCompleter!.isCompleted) ||
      _permissionQueue.isNotEmpty ||
      state.isLoadingSettings ||
      state.isApplyingSettings ||
      state.isLoadingSessions ||
      state.isLoadingMessages ||
      state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
      state.recoveryStatus == SessionRecoveryStatus.syncing ||
      _recovering != null ||
      _connectionLoss != null ||
      _checkpointing != null ||
      _runtimeSaving != null ||
      _runtimeWrites.isNotEmpty ||
      _openingAdapter != null ||
      _composerQuery != null ||
      _pendingAdapterOpens > 0 ||
      _pendingComposerQueries > 0 ||
      _remoteCatalogQueries > 0;
  static const _uuid = Uuid();

  static const notReadyCode = 'AGENT_NOT_READY';
  static const disconnectedCode = 'SSH_DISCONNECTED';

  /// Agent 要求认证；UI 据此展示引导卡片，而非通用错误。
  static const authRequiredCode = 'ACP_AUTH_REQUIRED';

  StreamSubscription<ACPEvent>? _acpSub;
  ACPClientAdapter? _currentAdapter;
  AgentRuntimeCapabilities? _modelCatalog;
  String? _modelAccountKey;
  List<AcpSlashCommand> _composerSkills = const [];
  Future<bool>? _composerQuery;
  int _draftRuntimeEpoch = 0;
  int _pendingComposerQueries = 0;
  int _pendingAdapterOpens = 0;
  int _remoteCatalogQueries = 0;
  Completer<void>? _authorizationCancelled;

  /// UI must confirm before calling this. No login or installation is automatic.
  Future<void> authorizeModelCatalog({
    required Future<void> Function(Uri) openBrowser,
  }) async {
    if (_authorizationCancelled != null) {
      throw StateError('AGENT_MODEL_AUTH_BUSY');
    }
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client =
        serverId == null || !ref.read(serverConnectionProvider).isConnected
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) throw StateError(disconnectedCode);
    if (nativeCliKind(profile.cliCommand) != NativeCliKind.codex) {
      throw StateError('AGENT_MODEL_QUERY_UNSUPPORTED');
    }
    if (isAgentUpdateLocked(ref, profile)) {
      throw StateError('AGENT_UPDATE_IN_PROGRESS');
    }
    final epoch = _requestEpoch;
    final cancelled = Completer<void>();
    _authorizationCancelled = cancelled;
    try {
      await CodexModelAuthorization.authorize(
        client,
        profile,
        openBrowser: openBrowser,
        cancelled: cancelled.future,
      );
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      _modelCatalog = null;
      state = state.copyWith(
        capabilities: const AgentRuntimeCapabilities(),
        settingsStale: true,
        clearSettingsMetadata: true,
        clearModelCatalogError: true,
      );
      await prepareRunSettings(refresh: true);
    } finally {
      if (identical(_authorizationCancelled, cancelled)) {
        _authorizationCancelled = null;
      }
    }
  }

  void cancelModelAuthorization() {
    final cancelled = _authorizationCancelled;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }

  List<AcpSlashCommand> _combinedCommands(List<AcpSlashCommand> commands) {
    final entries = <String, AcpSlashCommand>{
      for (final command in _composerSkills) command.name: command,
      for (final command in commands) command.name: command,
    };
    return entries.values.toList();
  }

  /// Draft discovery is read-only: no ACP session/new, load, resume or prompt.
  Future<bool> prepareComposerCatalog() {
    final pending = _composerQuery;
    if (pending != null) return pending;
    final operation = _prepareComposerCatalog();
    _composerQuery = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_composerQuery, operation)) _composerQuery = null;
      }),
    );
    return operation;
  }

  Future<bool> _prepareComposerCatalog() async {
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client =
        serverId == null || !ref.read(serverConnectionProvider).isConnected
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) {
      return false;
    }
    final epoch = _requestEpoch;
    final draftRuntimeEpoch = _draftRuntimeEpoch;
    final connectionKey = ref.read(activeServerProvider)?.connectionKey;
    final launchKey = _launchKey(profile);
    bool current() =>
        ref.mounted &&
        epoch == _requestEpoch &&
        draftRuntimeEpoch == _draftRuntimeEpoch &&
        ref.read(activeServerProvider)?.connectionKey == connectionKey &&
        state.activeAgentProfile?.id == profile.id &&
        _launchKey(state.activeAgentProfile!) == launchKey &&
        ref.read(serverConnectionProvider).isConnected &&
        identical(
          ref.read(sshClientManagerProvider).getClient(serverId!),
          client,
        ) &&
        !isAgentUpdateLocked(ref, profile);
    _pendingComposerQueries++;
    try {
      final adapter = await _adapterFor(profile, client);
      if (!current()) {
        return false;
      }
      _acpSub ??= adapter.eventStream.listen(
        (event) => _handleIdleRuntimeEvent(event, adapter),
      );
      await adapter.initializeOnly();
      if (!current()) {
        return false;
      }
      // Session-scoped command notifications cannot arrive in an empty draft.
      // Publish the verified adapter baseline even if independent skills fail.
      state = state.copyWith(
        commands: _combinedCommands(adapter.composerCommands),
      );
      final commands = await ref.read(agentComposerQueryProvider)(
        profile,
        client,
        adapter.workingDirectory,
      );
      if (!current()) {
        return false;
      }
      _composerSkills = commands;
      state = state.copyWith(
        commands: _combinedCommands(adapter.composerCommands),
        clearError:
            state.lastErrorCode?.startsWith('AGENT_COMPOSER_QUERY_FAILED:') ==
            true,
      );
      return true;
    } catch (error) {
      if (current()) {
        state = state.copyWith(
          lastErrorCode:
              'AGENT_COMPOSER_QUERY_FAILED: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
      return false;
    } finally {
      _pendingComposerQueries--;
    }
  }

  /// [_currentAdapter] 对应的 agent id。
  ///
  /// 切换 Agent 时必须重建 adapter，否则会把上一个 Agent 的会话
  /// 当成当前的。
  String? _currentAdapterAgentId;
  String? _currentAdapterSessionId;
  String? _currentAdapterServerId;
  String? _currentAdapterLaunchKey;
  String? _currentAdapterInitialModelId;
  Future<ACPClientAdapter>? _openingAdapter;
  String? _openingAdapterKey;
  int _requestEpoch = 0;
  Future<void>? _recovering;
  Future<void>? _connectionLoss;
  Future<void>? _checkpointing;
  bool _isPreparingPrompt = false;
  Timer? _streamTimer;
  Timer? _checkpointTimer;
  Timer? _draftSaveTimer;
  String? _pendingDraftKey;
  Future<void> Function()? _pendingDraftSave;
  Future<void> _draftSaveChain = Future<void>.value();
  void Function()? _flushStream;
  String? _draftWorkingDirectory;
  final List<ACPPermissionRequestEvent> _permissionQueue = [];
  bool _retryAfterAuth = false;
  AcpOAuthLoopback? _authLoopback;
  bool _authCallbackInFlight = false;
  int _authRequestEpoch = 0;
  AcpOAuthRequest? _autoOpenedAuthRequest;

  /// Shared claim: retained shell and modal chat views must not open two tabs.
  bool claimAuthBrowserLaunch(AcpOAuthRequest request) {
    if (!state.isAuthenticating ||
        !identical(state.authRequest, request) ||
        identical(_autoOpenedAuthRequest, request)) {
      return false;
    }
    _autoOpenedAuthRequest = request;
    return true;
  }

  void _closeAuthLoopback() {
    _authRequestEpoch++;
    _autoOpenedAuthRequest = null;
    final loopback = _authLoopback;
    _authLoopback = null;
    if (loopback != null) unawaited(loopback.close());
  }

  final Map<String, String?> _lastSelectedSessions = {};
  int _historyEpoch = 0;
  String _historyQuery = '';
  bool _blankDraftRequested = false;
  int _sessionListOffset = 0;
  final Map<
    String,
    ({String text, List<AcpPromptAttachment> attachments, String? directory})
  >
  _drafts = {};
  String get _draftKey =>
      '$_activeServerId::${state.activeAgentProfile?.id}::${state.activeSessionId ?? "draft"}';

  void updateDraftText(String text) {
    state = state.copyWith(draftText: text);
    _rememberDraft();
  }

  void _rememberDraft({bool persist = true}) {
    _drafts[_draftKey] = (
      text: state.draftText,
      attachments: state.attachments,
      directory: _draftWorkingDirectory,
    );
    if (!persist) {
      return;
    }
    final key = _draftKey;
    if (_pendingDraftKey != null && _pendingDraftKey != key) {
      final pending = _pendingDraftSave;
      if (pending != null) unawaited(pending());
    }
    _draftSaveTimer?.cancel();
    final text = state.draftText;
    final directory = _draftWorkingDirectory;
    final attachments = state.attachments;
    final storage = ref.read(localStorageServiceProvider);
    final store = ref.read(acpAttachmentStoreProvider);
    _pendingDraftKey = key;
    _pendingDraftSave = () {
      return _draftSaveChain = _draftSaveChain.then((_) async {
        try {
          final saved = <ChatAttachment>[];
          for (final item in attachments) {
            saved.add(
              await store.save(
                item.name,
                item.mimeType,
                item.bytes,
                uri: item.uri,
              ),
            );
          }
          await storage.saveChatDraft(key, {
            'text': text,
            'directory': directory,
            'attachments': saved.map((a) => a.toJson()).toList(),
          });
        } catch (error, stack) {
          unawaited(AppDiagnostics.instance.record('acp.draft', error, stack));
          if (ref.mounted && key == _draftKey) {
            state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED');
          }
        }
      });
    };
    _draftSaveTimer = Timer(const Duration(milliseconds: 400), () {
      final pending = _pendingDraftSave;
      _pendingDraftSave = null;
      _pendingDraftKey = null;
      if (pending != null) unawaited(pending());
    });
  }

  void _restoreDraft() {
    final key = _draftKey;
    final draft = _drafts[key];
    Map<String, dynamic>? saved;
    if (draft == null) {
      try {
        saved = ref.read(localStorageServiceProvider).getChatDraft(key);
      } catch (error) {
        state = state.copyWith(
          lastErrorCode:
              'CHAT_DRAFT_RESTORE_FAILED: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
    }
    _draftWorkingDirectory = draft?.directory ?? saved?['directory'] as String?;
    state = state.copyWith(
      draftText: draft?.text ?? saved?['text'] as String? ?? '',
      attachments: draft?.attachments ?? const [],
      draftWorkingDirectory: _draftWorkingDirectory,
      clearDraftWorkingDirectory: _draftWorkingDirectory == null,
    );
    if (saved != null) unawaited(_restoreSavedAttachments(key, saved));
  }

  Future<void> _restoreSavedAttachments(
    String key,
    Map<String, dynamic> saved,
  ) async {
    final initial = state.attachments;
    final restored = <AcpPromptAttachment>[];
    try {
      for (final raw in saved['attachments'] as List? ?? const []) {
        final item = ChatAttachment.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        if (item.localPath == null) continue;
        final file = File(item.localPath!);
        final limit = item.mimeType.startsWith('image/')
            ? AcpPromptAttachment.maxImageBytes
            : AcpPromptAttachment.maxTextBytes;
        if (await file.length() > limit) {
          throw StateError('ACP_ATTACHMENT_TOO_LARGE');
        }
        restored.add(
          AcpPromptAttachment(
            name: item.name,
            mimeType: item.mimeType,
            bytes: await file.readAsBytes(),
            uri: item.uri,
            localPath: item.localPath,
          ),
        );
      }
      if (!ref.mounted ||
          key != _draftKey ||
          !identical(state.attachments, initial)) {
        return;
      }
      state = state.copyWith(attachments: restored);
      _rememberDraft();
    } catch (error) {
      if (ref.mounted && key == _draftKey) {
        state = state.copyWith(
          lastErrorCode: 'CHAT_DRAFT_RESTORE_FAILED: $error',
        );
      }
    }
  }

  void addAttachment(AcpPromptAttachment attachment) {
    if (state.isGenerating) {
      return;
    }
    if (attachment.isImage
        ? !state.supportsImages
        : !state.supportsTextAttachments) {
      throw StateError('ACP_ATTACHMENT_UNSUPPORTED');
    }
    final bytes = state.attachments
        .where((a) => a.isImage == attachment.isImage)
        .fold<int>(attachment.bytes.length, (n, a) => n + a.bytes.length);
    if (bytes >
        (attachment.isImage
            ? AcpPromptAttachment.maxImageBytes
            : AcpPromptAttachment.maxTextBytes)) {
      throw StateError('ACP_ATTACHMENT_TOO_LARGE');
    }
    if (!attachment.isImage) utf8.decode(attachment.bytes);
    state = state.copyWith(attachments: [...state.attachments, attachment]);
    _rememberDraft();
  }

  void removeAttachment(int index) {
    if (state.isGenerating || index < 0 || index >= state.attachments.length) {
      return;
    }
    state = state.copyWith(
      attachments: [...state.attachments]..removeAt(index),
    );
    _rememberDraft();
  }

  Future<void> attachLocalFile(
    String path,
    String name,
    String mimeType,
  ) async {
    final key = _draftKey;
    final image = mimeType.startsWith('image/');
    if (image ? !state.supportsImages : !state.supportsTextAttachments) {
      throw StateError('ACP_ATTACHMENT_UNSUPPORTED');
    }
    final file = File(path);
    final limit = image
        ? AcpPromptAttachment.maxImageBytes
        : AcpPromptAttachment.maxTextBytes;
    if (await file.length() > limit) {
      throw StateError('ACP_ATTACHMENT_TOO_LARGE');
    }
    final bytes = await file
        .openRead(0, limit + 1)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (buffer, chunk) => buffer..add(chunk),
        );
    if (!ref.mounted || key != _draftKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    addAttachment(
      AcpPromptAttachment(
        name: name,
        mimeType: mimeType,
        bytes: bytes.takeBytes(),
        localPath: path,
      ),
    );
  }

  Future<void> attachRemoteTextFile(String path) => attachRemoteFile(path);

  Future<void> attachRemoteFile(String path) async {
    final mime = AcpWorkspaceFiles.mimeType(path);
    if (mime == null) throw StateError('ACP_ATTACHMENT_UNSUPPORTED');
    if (mime.startsWith('image/')
        ? !state.supportsImages
        : !state.supportsTextAttachments) {
      throw StateError('ACP_ATTACHMENT_UNSUPPORTED');
    }
    final files = _files();
    final key = _draftKey;
    final bytes = await files.read(
      path,
      mime.startsWith('image/')
          ? AcpPromptAttachment.maxImageBytes
          : AcpPromptAttachment.maxTextBytes,
    );
    if (!ref.mounted ||
        key != _draftKey ||
        !identical(files, _workspaceFiles)) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    addAttachment(
      AcpPromptAttachment(
        name: path.split('/').last,
        mimeType: mime,
        bytes: bytes,
        uri: Uri(scheme: 'file', path: path).toString(),
      ),
    );
  }

  /// 当前活跃的 SSH 服务器 id，用于按服务器隔离会话 id。
  String? get _activeServerId => ref.read(activeServerProvider)?.id;

  Future<Transport> _openDurableTransport(
    SSHClient client,
    AgentProfile profile,
    ChatSession session,
    String identity,
    String? initialModelId,
  ) async {
    final target = _serverTargetKey;
    final epoch = _requestEpoch;
    var context = session.contextFor(profile.id);
    var resumeId = context.remoteSessionId;
    var key =
        context.persistentRuntimeKey ??
        AcpRuntimeService.sessionKey(
          identity,
          profile,
          session.id,
          generation: context.runtimeGeneration,
        );
    bool current() =>
        ref.mounted &&
        target == _serverTargetKey &&
        epoch == _requestEpoch &&
        state.activeSessionId == session.id &&
        state.activeAgentProfile?.id == profile.id;
    Future<void> rotate() async {
      if (resumeId == null) throw StateError('ACP_SESSION_RESTART_REQUIRED');
      await ref.read(acpRuntimeManagerProvider)(
        client,
        runtimeKey: key,
        action: 'retire',
      );
      if (!current()) throw StateError('ACP_TARGET_CHANGED');
      final latest = state.activeSession!;
      context = latest
          .contextFor(profile.id)
          .copyWith(
            remoteSessionId: resumeId,
            runtimeGeneration: context.runtimeGeneration + 1,
            runtimeRestartPending: false,
            clearPersistentRuntime: true,
          );
      key = AcpRuntimeService.sessionKey(
        identity,
        profile,
        session.id,
        generation: context.runtimeGeneration,
      );
      context = context.copyWith(persistentRuntimeKey: key);
      final changed = latest.copyWith(
        agentContexts: {...latest.agentContexts, profile.id: context},
      );
      await ref.read(chatRepositoryProvider).saveSession(changed);
      if (!current()) throw StateError('ACP_TARGET_CHANGED');
      _updateSessionInState(changed);
    }

    if (context.runtimeRestartPending) {
      final status = await ref.read(acpRuntimeInspectorProvider)(
        client,
        runtimeKey: key,
      );
      if (!current()) throw StateError('ACP_TARGET_CHANGED');
      if (status.isBusy) throw StateError('ACP_RUNTIME_TURN_IN_PROGRESS');
      resumeId ??= status.remoteSessionId;
      await rotate();
    }
    Future<Transport> open() => ref.read(persistentAcpRuntimeOpenerProvider)(
      client,
      profile,
      runtimeKey: key,
      afterSequence: context.runtimeCursor,
      remoteSessionId: context.remoteSessionId,
      initialModelId: initialModelId,
    );
    try {
      return await open();
    } on AcpRuntimeUnavailableException catch (error) {
      if (!error.status.canRecover || !current()) rethrow;
      resumeId ??= error.status.remoteSessionId;
      await rotate();
      return open();
    }
  }

  /// 构造一个 ACP adapter，并接上会话 id 的读取与持久化。
  Future<ACPClientAdapter> _createAdapter(
    AgentProfile profile,
    SSHClient sshClient, {
    String? initialModelId,
  }) async {
    final localSession = state.activeSession;
    final serverId = _activeServerId;
    final epoch = _requestEpoch;
    final launchKey = _launchKey(profile);
    final identity = _persistentConsentIdentity;
    final durable =
        ref.read(persistentAcpRuntimeEnabledProvider) &&
        localSession != null &&
        identity != null;
    if (durable &&
        !ref
            .read(localStorageServiceProvider)
            .getPersistentAcpConsent(identity)) {
      throw StateError('ACP_RUNTIME_CONSENT_REQUIRED');
    }
    final transport = durable
        ? await _openDurableTransport(
            sshClient,
            profile,
            localSession,
            identity,
            initialModelId,
          )
        : await ref.read(acpTransportFactoryProvider)(
            profile,
            sshClient,
            initialModelId: initialModelId,
          );
    var workingDirectory =
        localSession?.workingDirectory ?? _draftWorkingDirectory ?? '.';
    if (transport is AcpSshTransport) {
      try {
        final probe = workingDirectory == '.'
            ? 'pwd -P'
            : 'cd -- ${cliShellQuote(workingDirectory)} && pwd -P';
        final output = await sshClient
            .runWithResult(agentTargetCommand(profile, probe))
            .timeout(const Duration(seconds: 15));
        final path = utf8.decode(output.stdout).trim();
        if (output.exitCode != 0 ||
            !path.startsWith('/') ||
            path.contains('\n')) {
          throw StateError('ACP_WORKING_DIRECTORY_UNAVAILABLE');
        }
        workingDirectory = path;
      } catch (_) {
        await transport.close();
        rethrow;
      }
    }
    if (!ref.mounted ||
        epoch != _requestEpoch ||
        _activeServerId != serverId ||
        state.activeSessionId != localSession?.id ||
        state.activeAgentProfile?.id != profile.id ||
        _launchKey(state.activeAgentProfile!) != launchKey) {
      await transport.close();
      throw StateError('ACP_TARGET_CHANGED');
    }
    if (localSession == null) {
      _draftWorkingDirectory = workingDirectory;
      if (ref.mounted &&
          _activeServerId == serverId &&
          state.activeAgentProfile?.id == profile.id) {
        state = state.copyWith(draftWorkingDirectory: workingDirectory);
      }
    }

    final storage = ref.read(localStorageServiceProvider);

    // 有历史会话 id 就带上，让 adapter 优先 load/resume 而不是新建。
    final storedSessionId =
        state.activeSession?.contextFor(profile.id).remoteSessionId ??
        localSession?.contextFor(profile.id).remoteSessionId;

    final adapter = ACPClientAdapter(
      profile: profile,
      transport: transport,
      workingDirectory: workingDirectory,
      resumeSessionId: storedSessionId,
    );
    adapter.setInBackground(!ref.read(appVisibilityProvider));

    // 新建会话也要记住新 id，否则下次掉线又只能新建。
    adapter.onSessionEstablished = (sessionId) {
      if (!ref.mounted ||
          !identical(adapter, _currentAdapter) ||
          serverId == null ||
          _activeServerId != serverId ||
          state.activeAgentProfile?.id != profile.id) {
        return;
      }
      final current = state.sessions
          .where((entry) => entry.id == _currentAdapterSessionId)
          .firstOrNull;
      if (current == null) {
        return;
      }
      final context = current.contextFor(profile.id);
      final updated = current.copyWith(
        workingDirectory: workingDirectory,
        remoteSessionId: current.agentId == profile.id
            ? sessionId
            : current.remoteSessionId,
        agentContexts: {
          ...current.agentContexts,
          profile.id: context.copyWith(
            remoteSessionId: sessionId,
            syncedMessageCount: context.syncedMessageCount,
            persistentRuntimeKey: adapter.persistentRuntimeKey,
          ),
        },
      );
      _updateSessionInState(updated);
      unawaited(
        ref.read(chatRepositoryProvider).saveSession(updated).catchError((
          Object error,
        ) {
          if (ref.mounted &&
              _activeServerId == serverId &&
              state.activeSessionId == updated.id) {
            state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED: $error');
          }
        }),
      );
      unawaited(storage.saveAcpSessionId(serverId, profile.id, sessionId));
    };

    return adapter;
  }

  String _launchKey(AgentProfile profile) =>
      '${profile.executionTarget}|${profile.containerBinding}|'
      '${profile.containerReference}|${profile.containerUser}|${profile.acpCommand}|${profile.cliCommand}';

  String? _initialModelFor(AgentProfile profile) {
    if (!usesStandardCodexAcp(profile) ||
        state.activeSession?.contextFor(profile.id).remoteSessionId != null ||
        (_currentAdapterAgentId == profile.id &&
            _currentAdapterServerId == _activeServerId &&
            _currentAdapterSessionId == state.activeSessionId &&
            _currentAdapter?.sessionId != null)) {
      return null;
    }
    final model = state.runSettings.modelId;
    return _validCustomModel(model) ? model : null;
  }

  Future<ACPClientAdapter> _adapterFor(AgentProfile profile, SSHClient client) {
    if (isAgentUpdateLocked(ref, profile)) {
      return Future.error(StateError('AGENT_UPDATE_IN_PROGRESS'));
    }
    final initialModelId = _initialModelFor(profile);
    final key =
        '$_requestEpoch|$_draftRuntimeEpoch|$_activeServerId|${state.activeSessionId}|${profile.id}|${_launchKey(profile)}|$initialModelId';
    if (_openingAdapterKey == key && _openingAdapter != null) {
      return _openingAdapter!;
    }
    final operation = _openAdapterFor(profile, client, initialModelId);
    _openingAdapterKey = key;
    _openingAdapter = operation;
    unawaited(
      operation.then(
        (_) {
          if (identical(_openingAdapter, operation)) _openingAdapter = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_openingAdapter, operation)) _openingAdapter = null;
        },
      ),
    );
    return operation;
  }

  Future<ACPClientAdapter> _openAdapterFor(
    AgentProfile profile,
    SSHClient client,
    String? initialModelId,
  ) async {
    final serverId = _activeServerId;
    final sessionId = state.activeSessionId;
    final key = _launchKey(profile);
    if (_currentAdapter != null &&
        !_currentAdapter!.isDisposed &&
        _currentAdapterAgentId == profile.id &&
        _currentAdapterSessionId == sessionId &&
        _currentAdapterServerId == serverId &&
        _currentAdapterLaunchKey == key &&
        (_currentAdapter!.sessionId != null ||
            _currentAdapterInitialModelId == initialModelId)) {
      return _currentAdapter!;
    }
    _currentAdapter?.dispose();
    _currentAdapter = null;
    state = state.copyWith(authenticationConfirmed: false);
    final epoch = _requestEpoch;
    final draftRuntimeEpoch = _draftRuntimeEpoch;
    final ACPClientAdapter adapter;
    _pendingAdapterOpens++;
    try {
      adapter = await _createAdapter(
        profile,
        client,
        initialModelId: initialModelId,
      );
    } finally {
      _pendingAdapterOpens--;
    }
    if (!ref.mounted ||
        epoch != _requestEpoch ||
        draftRuntimeEpoch != _draftRuntimeEpoch ||
        _activeServerId != serverId ||
        state.activeSessionId != sessionId ||
        state.activeAgentProfile?.id != profile.id ||
        _initialModelFor(profile) != initialModelId ||
        isAgentUpdateLocked(ref, profile)) {
      adapter.dispose();
      throw StateError('ACP_TARGET_CHANGED');
    }
    _currentAdapter = adapter;
    _currentAdapterAgentId = profile.id;
    _currentAdapterSessionId = sessionId;
    _currentAdapterServerId = serverId;
    _currentAdapterLaunchKey = key;
    _currentAdapterInitialModelId = initialModelId;
    return adapter;
  }

  void _handleControlEvent(ACPEvent event, ACPClientAdapter adapter) {
    if (!ref.mounted || !identical(adapter, _currentAdapter)) {
      return;
    }
    if (event is ACPAuthorizationRequestEvent) {
      if (state.activeAgentProfile case final profile?
          when usesAntigravityAcp(profile)) {
        unawaited(_showAuthorizationRequest(event.request, adapter));
      }
      return;
    }
    if (event is ACPSettingsChangedEvent || event is ACPCompleteEvent) {
      final challenge = state.authChallenge;
      final authConfirmed =
          challenge != null &&
          adapter.authenticationConfirmed &&
          challenge.agentId == state.activeAgentProfile?.id &&
          challenge.serverId == _activeServerId;
      if (authConfirmed) {
        _modelCatalog = null;
        _modelAccountKey = null;
        final profile = state.activeAgentProfile;
        if (profile != null) {
          unawaited(
            ref
                .read(agentRegistryProvider.notifier)
                .confirmAuthentication(profile),
          );
        }
        final pending = state.authCompleter;
        if (pending != null && !pending.isCompleted) pending.complete(null);
        _closeAuthLoopback();
        state = state.copyWith(
          clearAuthChallenge: true,
          authenticationConfirmed: true,
          settingsStale: true,
          clearError: state.lastErrorCode == authRequiredCode,
        );
      }
    }
    if (event is ACPSettingsChangedEvent) {
      state = state.copyWith(
        authenticationConfirmed: adapter.authenticationConfirmed,
        agentVersion:
            '${adapter.agentInfo?.name ?? ""} ${adapter.agentInfo?.version ?? ""}'
                .trim(),
        account: adapter.account,
        commands: _combinedCommands(adapter.composerCommands),
        usage: adapter.usage,
        diagnostics: adapter.diagnostics,
        supportsImages:
            adapter.agentCapabilities.promptCapabilities?.image == true,
        supportsTextAttachments:
            adapter.agentCapabilities.promptCapabilities?.embeddedContext ==
            true,
        capabilities: _acpCapabilities(adapter),
        runSettings: state.isApplyingSettings
            ? state.runSettings
            : _confirmedSettings(adapter, state.runSettings),
      );
    } else if (event is ACPAccountEvent) {
      state = state.copyWith(account: event.account);
    } else if (event is ACPCommandsChangedEvent) {
      state = state.copyWith(commands: _combinedCommands(event.commands));
    } else if (event is ACPUsageEvent) {
      state = state.copyWith(usage: event.usage);
    } else if (event is ACPAuthRequiredEvent) {
      _closeAuthLoopback();
      _retryAfterAuth = true;
      final previous = state.authCompleter;
      if (previous != null && !previous.isCompleted) previous.complete(null);
      state = state.copyWith(
        authChallenge: AuthChallenge(
          serverId: _activeServerId,
          agentId: state.activeAgentProfile!.id,
          methods: event.methods,
        ),
        authCompleter: Completer<String?>(),
        isGenerating: false,
        lastErrorCode: authRequiredCode,
        isAuthenticating: false,
        authenticationConfirmed: false,
        clearAuthRequest: true,
      );
    } else if (event is ACPErrorEvent && state.isAuthenticating) {
      _closeAuthLoopback();
      state = state.copyWith(
        isAuthenticating: false,
        clearAuthRequest: true,
        authError: event.error,
      );
    }
  }

  Future<void> _showAuthorizationRequest(
    AcpOAuthRequest request,
    ACPClientAdapter adapter,
  ) async {
    _closeAuthLoopback();
    final authEpoch = _authRequestEpoch;
    final epoch = _requestEpoch;
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    if (profile == null || serverId == null) {
      return;
    }
    bool current() =>
        ref.mounted &&
        authEpoch == _authRequestEpoch &&
        epoch == _requestEpoch &&
        identical(adapter, _currentAdapter) &&
        _activeServerId == serverId &&
        state.activeAgentProfile?.id == profile.id;
    state = state.copyWith(
      authChallenge:
          state.authChallenge ??
          AuthChallenge(
            serverId: serverId,
            agentId: profile.id,
            methods: adapter.authMethods,
          ),
      isAuthenticating: true,
      clearAuthError: true,
    );
    AcpOAuthLoopback? loopback;
    try {
      loopback = await AcpOAuthLoopback.bind(request, (callback) async {
        if (!current() || !identical(state.authRequest, request)) {
          throw StateError('ACP_TARGET_CHANGED');
        }
        await submitAuthCallback(callback);
        // Delivery and official authentication completion are separate events.
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!adapter.authenticationConfirmed) {
          if (adapter.isDisposed ||
              DateTime.now().isAfter(deadline) ||
              !ref.mounted ||
              !identical(adapter, _currentAdapter)) {
            throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }, renderPage: ref.read(acpOAuthPageRendererProvider));
    } on SocketException {
      if (current()) {
        state = state.copyWith(
          isAuthenticating: false,
          clearAuthRequest: true,
          authError: 'ACP_AUTH_CALLBACK_LISTENER_FAILED',
        );
      }
      return;
    }
    if (!current() || !state.isAuthenticating) {
      await loopback.close();
      return;
    }
    _authLoopback = loopback;
    state = state.copyWith(authRequest: request);
  }

  /// Accept only this attempt's loopback URI/state, in its original target.
  Future<void> submitAuthCallback(String callback) async {
    final request = state.authRequest;
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    if (request == null ||
        profile == null ||
        serverId == null ||
        !state.isAuthenticating ||
        _authCallbackInFlight) {
      throw StateError('ACP_AUTH_NOT_PENDING');
    }
    final client = ref.read(sshClientManagerProvider).getClient(serverId);
    if (client == null || !ref.read(serverConnectionProvider).isConnected) {
      throw StateError(disconnectedCode);
    }
    _authCallbackInFlight = true;
    try {
      await deliverAcpOAuthCallback(client, profile, request, callback);
    } catch (_) {
      if (ref.mounted && identical(state.authRequest, request)) {
        state = state.copyWith(authError: 'ACP_AUTH_CALLBACK_DELIVERY_FAILED');
      }
      // Never propagate a URL or code from lower-level errors into UI/logs.
      throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
    } finally {
      _authCallbackInFlight = false;
    }
  }

  /// Explicit user action: replace the ACP transport and initialize only.
  /// Does not create/load a session, send a prompt, or clear message failures.
  /// False means busy, unavailable, superseded, or initialization failed.
  Future<bool> reconnectCurrentAgent() async {
    final run = _backgroundRuns[_serverTargetKey];
    if (run != null &&
        ref.read(appVisibilityProvider) &&
        ref.read(serverConnectionProvider).isConnected) {
      await recoverConnection();
      return ref.mounted &&
          _serverTargetKey == run.serverTargetKey &&
          run.state != 'reconnecting';
    }
    if (isRuntimeBusy || !ref.read(appVisibilityProvider)) {
      return false;
    }
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final connectionKey = ref.read(activeServerProvider)?.connectionKey;
    if (profile == null ||
        serverId == null ||
        !ref.read(serverConnectionProvider).isConnected ||
        ref.read(sshClientManagerProvider).getClient(serverId) == null) {
      return false;
    }
    final sessionId = state.activeSessionId;
    final launchKey = _launchKey(profile);
    final draftDirectory = _draftWorkingDirectory;
    final visibleDraftDirectory = state.draftWorkingDirectory;
    final recoveryStatus = state.recoveryStatus;
    final retryAfterAuth = _retryAfterAuth;
    _resetAdapter(preserveDraftWorkingDirectory: true);
    _retryAfterAuth = retryAfterAuth;
    final epoch = _requestEpoch;
    bool current() =>
        ref.mounted &&
        epoch == _requestEpoch &&
        serverId == _activeServerId &&
        connectionKey == ref.read(activeServerProvider)?.connectionKey &&
        sessionId == state.activeSessionId &&
        profile.id == state.activeAgentProfile?.id &&
        launchKey == _launchKey(state.activeAgentProfile!);
    if (!current()) {
      return false;
    }
    // Reinitializing a transport does not resolve an incomplete history replay.
    state = state.copyWith(recoveryStatus: recoveryStatus);
    try {
      final initialized = await prepareRunSettings(refresh: true);
      return current() &&
          ref.read(serverConnectionProvider).isConnected &&
          initialized;
    } finally {
      if (current()) {
        // Adapter discovery may canonicalize a blank draft's working directory.
        // Reconnect must not change the user's draft selection.
        _draftWorkingDirectory = draftDirectory;
        if (state.draftWorkingDirectory != visibleDraftDirectory) {
          state = state.copyWith(
            draftWorkingDirectory: visibleDraftDirectory,
            clearDraftWorkingDirectory: visibleDraftDirectory == null,
          );
        }
      }
    }
  }

  Future<bool> prepareRunSettings({bool refresh = false}) async {
    await _adoptFinishedRun();
    if (state.isGenerating ||
        state.isAuthenticating ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return false;
    }
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client =
        serverId == null || !ref.read(serverConnectionProvider).isConnected
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) {
      state = state.copyWith(
        lastErrorCode: profile == null ? notReadyCode : disconnectedCode,
      );
      return false;
    }
    if (isAgentUpdateLocked(ref, profile)) {
      state = state.copyWith(lastErrorCode: 'AGENT_UPDATE_IN_PROGRESS');
      return false;
    }
    final epoch = _requestEpoch;
    final connectionKey = ref.read(activeServerProvider)?.connectionKey;
    final launchKey = _launchKey(profile);
    bool sameTarget() =>
        ref.mounted &&
        epoch == _requestEpoch &&
        ref.read(activeServerProvider)?.connectionKey == connectionKey &&
        state.activeAgentProfile?.id == profile.id &&
        _launchKey(state.activeAgentProfile!) == launchKey &&
        identical(
          ref.read(sshClientManagerProvider).getClient(serverId!),
          client,
        );
    bool current() =>
        sameTarget() &&
        ref.read(serverConnectionProvider).isConnected &&
        !isAgentUpdateLocked(ref, profile);
    state = state.copyWith(
      isLoadingSettings: true,
      settingsStale: true,
      clearError: true,
    );
    try {
      final adapter = await _adapterFor(profile, client);
      if (!current()) {
        return false;
      }
      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen(
        (event) => _handleIdleRuntimeEvent(event, adapter),
      );
      final method =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (method != null) await adapter.authenticate(method);
      // Discovery does not restore a thread or recreate the ACP transport.
      // Session setup is deferred to an explicit settings change or first send.
      await adapter.initializeOnly();
      if (!current()) {
        return false;
      }
      AgentRuntimeCapabilities? catalog;
      String? catalogError;
      try {
        catalog = await ref.read(agentModelQueryProvider)(profile, client);
        if (catalog == null) {
          catalogError = 'AGENT_MODEL_QUERY_UNSUPPORTED';
        }
      } catch (error) {
        catalogError = LogSanitizer.sanitize(error.toString());
        if (current() &&
            error is ModelCatalogQueryException &&
            ((error.accountKey != null &&
                    _modelAccountKey != null &&
                    error.accountKey != _modelAccountKey) ||
                error.code == 'AGENT_MODEL_ACCOUNT_MISMATCH' ||
                error.code == 'AGENT_MODEL_AUTH_UNAVAILABLE')) {
          _modelCatalog = null;
          _modelAccountKey = error.accountKey;
          state = state.copyWith(clearSettingsMetadata: true);
        }
      }
      if (!current()) {
        return false;
      }
      if (catalog != null) {
        _modelCatalog = catalog;
        _modelAccountKey = catalog.catalogAccountKey;
      }
      state = state.copyWith(
        account: adapter.account,
        clearAccount: adapter.account == null,
        settingsFetchedAt: catalog != null ? DateTime.now() : null,
        settingsStale: catalogError != null,
        modelCatalogError: catalogError,
        clearModelCatalogError: catalogError == null,
        agentVersion:
            '${adapter.agentInfo?.name ?? ""} ${adapter.agentInfo?.version ?? ""}'
                .trim(),
        supportsImages:
            adapter.agentCapabilities.promptCapabilities?.image == true,
        supportsTextAttachments:
            adapter.agentCapabilities.promptCapabilities?.embeddedContext ==
            true,
        capabilities: _acpCapabilities(adapter),
      );
      return true;
    } catch (error) {
      if (current()) {
        state = state.copyWith(
          settingsStale: true,
          lastErrorCode: state.authChallenge != null
              ? authRequiredCode
              : error.toString(),
          diagnostics: _currentAdapter?.diagnostics,
        );
      }
      return false;
    } finally {
      if (sameTarget()) {
        state = state.copyWith(isLoadingSettings: false);
      }
    }
  }

  /// Aliased profiles can share an install; refresh the current server's idle runtime.
  Future<void> refreshRuntimeAfterUpdate(
    AgentProfile profile, {
    bool refresh = true,
  }) async {
    final registry = ref.read(agentRegistryProvider);
    final aliases = <String>{
      profile.id,
      ...registry.agents
          .map((entry) => entry.profile)
          .where(
            (entry) =>
                entry.serverId == profile.serverId &&
                entry.executionTarget == profile.executionTarget &&
                entry.containerBinding == profile.containerBinding &&
                entry.containerReference == profile.containerReference &&
                entry.containerUser == profile.containerUser &&
                (entry.cliCommand == profile.cliCommand ||
                    entry.acpCommand == profile.acpCommand),
          )
          .map((entry) => entry.id),
    };
    ChatSession mark(ChatSession session) => session.copyWith(
      agentContexts: {
        for (final entry in session.agentContexts.entries)
          entry.key:
              aliases.contains(entry.key) &&
                  entry.value.persistentRuntimeKey != null
              ? entry.value.copyWith(runtimeRestartPending: true)
              : entry.value,
      },
    );
    for (final run in _backgroundRuns.values.where(
      (run) =>
          run.profile.serverId == profile.serverId &&
          aliases.contains(run.profile.id),
    )) {
      run.session = mark(run.session);
      await run.checkpoint();
    }
    await ref
        .read(chatRepositoryProvider)
        .markRuntimesForRestart(profile.serverId, aliases);
    if (!ref.mounted) {
      return;
    }
    if (_activeServerId == profile.serverId) {
      state = state.copyWith(
        sessions: state.sessions.map(mark).toList(),
        settingsStale: true,
      );
    }
    final current = state.activeAgentProfile;
    if (current == null ||
        current.serverId != profile.serverId ||
        _activeServerId != profile.serverId ||
        isRuntimeBusy ||
        (refresh && isAgentUpdateLocked(ref, current))) {
      return;
    }
    _requestEpoch++;
    _currentAdapter?.dispose();
    _currentAdapter = null;
    _currentAdapterInitialModelId = null;
    _openingAdapter = null;
    _openingAdapterKey = null;
    unawaited(_acpSub?.cancel());
    _acpSub = null;
    _modelCatalog = null;
    _modelAccountKey = null;
    _composerSkills = const [];
    _composerQuery = null;
    state = state.copyWith(settingsStale: true);
    if (refresh && ref.read(serverConnectionProvider).isConnected) {
      await prepareRunSettings(refresh: true);
    }
  }

  @override
  AiChatState build() {
    ref.onDispose(() {
      for (final run in _backgroundRuns.values) {
        if (run.isBusy) run.state = 'reconnecting';
        unawaited(
          run.detach().catchError((Object error, StackTrace stack) {
            return AppDiagnostics.instance.record(
              'acp.background.detach',
              error,
              stack,
            );
          }),
        );
      }
      _closeAuthLoopback();
      cancelModelAuthorization();
      cancelWorkspaceBrowse();
      _requestEpoch++;
      _streamTimer?.cancel();
      _recoveredRuntimeTimer?.cancel();
      _checkpointTimer?.cancel();
      _draftSaveTimer?.cancel();
      final pendingDraft = _pendingDraftSave;
      _pendingDraftSave = null;
      if (pendingDraft != null) unawaited(pendingDraft());
      _flushStream = null;
      unawaited(_acpSub?.cancel());
      _currentAdapter?.dispose();
      _currentAdapter = null;
      _acpSub = null;
    });
    ref.listen(serverConnectionProvider, (prev, next) {
      if (prev?.isConnected == true && !next.isConnected) {
        unawaited(_connectionLost());
      } else if (next.isConnected && prev?.isConnected == false) {
        _autoRecoverConnection();
      }
    });
    ref.listen(appVisibilityProvider, (_, foreground) {
      _currentAdapter?.setInBackground(!foreground);
      for (final run in _backgroundRuns.values) {
        run.adapter.setInBackground(!foreground);
      }
      if (foreground) _autoRecoverConnection();
    });

    ref.watch(chatRepositoryProvider);
    final registry = ref.read(agentRegistryProvider);
    ref.listen(agentRegistryProvider, (_, next) {
      final previous = state.activeAgentProfile;
      final selected = next.agents
          .where(
            (a) =>
                a.profile.id == previous?.id &&
                a.profile.serverId == _activeServerId,
          )
          .firstOrNull
          ?.profile;
      final changed =
          previous != null &&
          (selected == null ||
              _launchKey(previous) != _launchKey(selected) ||
              previous.cliCommand != selected.cliCommand);
      if (changed) {
        _rememberDraft();
        _resetAdapter();
      }
      state = state.copyWith(
        readyAgents: next.readyAgents,
        activeAgentProfile: selected,
        clearActiveAgent: previous != null && selected == null,
        isGenerating: changed ? false : null,
        clearPermission: changed,
        clearAuthChallenge: changed,
      );
      if (state.activeAgentProfile == null && next.readyAgents.isNotEmpty) {
        final activeServerId = _activeServerId;
        final preferred = activeServerId == null
            ? null
            : ref
                  .read(localStorageServiceProvider)
                  .getDefaultAgentId(activeServerId, cli: false);
        switchAgent(
          next.readyAgents.where((a) => a.id == preferred).firstOrNull?.id ??
              next.readyAgents.first.id,
        );
      }
    });
    final serverId = ref
        .watch(activeServerProvider.select((s) => s?.connectionKey))
        ?.$1;
    final share =
        serverId != null &&
        ref.read(localStorageServiceProvider).getShareAgentSessions(serverId);
    final allSessions =
        stateOrNull?.sessions
            .where((session) => session.serverId == serverId)
            .toList() ??
        <ChatSession>[];
    Future.microtask(() {
      if (ref.mounted && !state.isGenerating) {
        unawaited(_refreshVisibleSessions());
      }
    });
    final readyAgents = registry.readyAgents;

    // 保留仍然可用的显式选择；否则自动激活首个就绪 Agent。
    // 安装完成使 Agent 变为 ready 时，registry 变化会触发 build 重跑，
    // 从而自动选中它，无需 UI 监听第二个 provider。
    final previous = stateOrNull?.activeAgentProfile;
    final keepPrevious =
        previous != null &&
        (serverId == null || previous.serverId == serverId) &&
        registry.agents.any((a) => a.profile.id == previous.id);

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
        ? registry.agents
              .firstWhere((entry) => entry.profile.id == previous.id)
              .profile
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
      if (!keepPrevious) _draftWorkingDirectory = null;
      return existingState.copyWith(
        clearServerRun:
            existingState.serverRun?.serverTargetKey != _serverTargetKey,
        draftText: keepPrevious ? existingState.draftText : '',
        attachments: keepPrevious ? existingState.attachments : const [],
        clearDraftWorkingDirectory: !keepPrevious,
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
    if (serverId == null || agentId == null) {
      return;
    }
    await ref
        .read(localStorageServiceProvider)
        .saveChatLaunchPreference(serverId, agentId, preference, cli: false);
    _refreshVisibleSessions();
  }

  Future<void> setDefaultAgent(String? agentId) async {
    final serverId = ref.read(activeServerProvider)?.id;
    if (serverId == null) {
      return;
    }
    if (agentId != null &&
        !state.readyAgents.any((agent) => agent.id == agentId)) {
      throw ArgumentError.value(agentId, 'agentId', 'Agent is not ready');
    }
    await ref
        .read(localStorageServiceProvider)
        .setDefaultAgentId(serverId, agentId, cli: false);
    if (ref.mounted) ref.invalidate(defaultAgentSettingsProvider);
  }

  Future<void> selectSession(String sessionId) async {
    if (_isPreparingPrompt ||
        (state.isGenerating &&
            _currentAdapter?.sessionId == null &&
            _backgroundRuns[_serverTargetKey] == null)) {
      return;
    }
    if (!state.sessions.any((s) => s.id == sessionId)) {
      return;
    }
    final expectedTarget = _serverTargetKey;
    if (state.activeSessionId != sessionId) await _parkRunningView();
    if (!ref.mounted ||
        expectedTarget != _serverTargetKey ||
        !state.sessions.any((s) => s.id == sessionId)) {
      return;
    }
    _rememberDraft();
    if (state.activeSessionId != sessionId) _resetAdapter();
    _blankDraftRequested = false;
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
      clearError: state.activeSessionId != sessionId,
      activeSessionId: sessionId,
      runSettings: selectedAgentId == null || serverId == null
          ? const ChatRunSettings()
          : session.agentRunSettings[selectedAgentId] ??
                ref
                    .read(localStorageServiceProvider)
                    .getChatRunDefault(serverId, selectedAgentId),
    );
    _restoreDraft();
    await _loadSelectedMessages();
    final run = _backgroundRuns[_serverTargetKey];
    if (run != null) _backgroundChanged(run);
  }

  /// 按稳定 agentId 切换 Agent；目标不存在或未就绪时拒绝切换。
  Future<void> switchAgent(String agentId) async {
    if (_isPreparingPrompt ||
        (state.isGenerating &&
            _currentAdapter?.sessionId == null &&
            _backgroundRuns[_serverTargetKey] == null)) {
      return;
    }
    final running = _backgroundRuns[_serverTargetKey];
    final target =
        state.readyAgents.where((a) => a.id == agentId).firstOrNull ??
        (running?.profile.id == agentId ? running?.profile : null);
    if (target == null) {
      state = state.copyWith(lastErrorCode: notReadyCode);
      return;
    }
    final expectedTarget = _serverTargetKey;
    if (state.activeAgentProfile?.id != agentId) await _parkRunningView();
    if (!ref.mounted || expectedTarget != _serverTargetKey) {
      return;
    }
    _rememberDraft();
    if (state.activeAgentProfile?.id != agentId) _resetAdapter();
    _blankDraftRequested = false;
    _lastSelectedSessions['$_activeServerId::${state.activeAgentProfile?.id}'] =
        state.activeSessionId;
    state = state.copyWith(
      activeAgentProfile: target,
      clearError: true,
      sessions: state.sessions
          .where((s) => state.shareAgentSessions || s.includesAgent(target.id))
          .toList(),
      clearActiveSession: !state.shareAgentSessions,
    );
    _restoreDraft();
    await _refreshVisibleSessions();
    final run = _backgroundRuns[_serverTargetKey];
    if (run != null) _backgroundChanged(run);
  }

  Future<void> _refreshVisibleSessions({bool append = false}) async {
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId == null ||
        agentId == null ||
        state.isGenerating ||
        _isPreparingPrompt) {
      return;
    }
    final epoch = ++_historyEpoch;
    state = state.copyWith(isLoadingSessions: true);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .listSessions(
            serverId,
            agentId: state.shareAgentSessions ? null : agentId,
            query: _historyQuery,
            offset: append ? _sessionListOffset : 0,
          );
      if (!ref.mounted ||
          epoch != _historyEpoch ||
          serverId != _activeServerId ||
          agentId != state.activeAgentProfile?.id) {
        return;
      }
      final active = state.activeSession;
      if (state.isGenerating || _isPreparingPrompt) {
        state = state.copyWith(isLoadingSessions: false);
        return;
      }
      final sessions = [
        if (append) ...state.sessions,
        ...page.sessions.where(
          (s) => !append || !state.sessions.any((old) => old.id == s.id),
        ),
      ].map((s) => active?.id == s.id ? active! : s).toList();
      var selected = _blankDraftRequested
          ? null
          : _preferredSessionId(
              serverId,
              agentId,
              sessions,
              state.activeSessionId ??
                  _lastSelectedSessions['$serverId::$agentId'],
            );
      // A fixed/remembered session may lie beyond the first list page.
      if (!append && !_blankDraftRequested && _historyQuery.isEmpty) {
        final storage = ref.read(localStorageServiceProvider);
        final preference = storage.getChatLaunchPreference(
          serverId,
          agentId,
          cli: false,
        );
        final wanted = preference.mode == ChatLaunchMode.fixed
            ? preference.sessionId
            : preference.mode == ChatLaunchMode.rememberLast
            ? storage.getLastChatSessionId(serverId, agentId, cli: false)
            : null;
        if (wanted != null && !sessions.any((s) => s.id == wanted)) {
          final extra = await ref
              .read(chatRepositoryProvider)
              .loadSession(wanted);
          if (!ref.mounted ||
              epoch != _historyEpoch ||
              serverId != _activeServerId ||
              agentId != state.activeAgentProfile?.id) {
            return;
          }
          if (extra != null &&
              extra.serverId == serverId &&
              (state.shareAgentSessions || extra.includesAgent(agentId))) {
            sessions.add(extra);
            selected = wanted;
          }
        }
      }
      state = state.copyWith(
        sessions: sessions,
        activeSessionId: selected,
        clearActiveSession: selected == null,
        hasMoreSessions: page.hasMore,
        lastErrorCode: page.warning,
        isLoadingSessions: false,
      );
      _sessionListOffset =
          (append ? _sessionListOffset : 0) + page.sessions.length;
      _restoreDraft();
      if (selected != null) await _loadSelectedMessages();
      if (ref.mounted && epoch == _historyEpoch) {
        unawaited(_refreshRunningTask());
      }
      if (ref.mounted &&
          epoch == _historyEpoch &&
          (state.recoveryStatus != SessionRecoveryStatus.idle ||
              (state.activeSession?.contextFor(agentId).persistentRuntimeKey !=
                      null &&
                  _currentAdapter == null) ||
              state.activeSession?.messages.any(
                    (m) =>
                        m.status == ChatTurnStatus.interrupted ||
                        m.status == ChatTurnStatus.unknown ||
                        m.status == ChatTurnStatus.streaming,
                  ) ==
                  true)) {
        _autoRecoverConnection();
      }
    } catch (error) {
      if (ref.mounted && epoch == _historyEpoch) {
        state = state.copyWith(
          isLoadingSessions: false,
          lastErrorCode: 'CHAT_HISTORY_LOAD_FAILED: $error',
        );
      }
    }
  }

  Future<void> searchSessions(String query) async {
    _historyQuery = query.trim();
    await _refreshVisibleSessions();
  }

  Future<void> loadMoreSessions() async {
    if (!state.hasMoreSessions || state.isLoadingSessions) {
      return;
    }
    await _refreshVisibleSessions(append: true);
  }

  Future<AcpRemoteSessionPage> listRemoteSessions({String? cursor}) async {
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client = serverId == null
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) throw StateError(disconnectedCode);
    if (isAgentUpdateLocked(ref, profile)) {
      throw StateError('AGENT_UPDATE_IN_PROGRESS');
    }
    final key = _launchKey(profile);
    final epoch = _requestEpoch;
    final connectionKey = ref.read(activeServerProvider)?.connectionKey;
    ACPClientAdapter? adapter;
    _remoteCatalogQueries++;
    try {
      final transport = await ref.read(acpTransportFactoryProvider)(
        profile,
        client,
      );
      adapter = ACPClientAdapter(
        profile: profile,
        transport: transport,
        workingDirectory: '/',
      );
      final page = await adapter.listRemoteSessions(
        ListSessionsRequest(cursor: cursor),
      );
      if (!ref.mounted ||
          epoch != _requestEpoch ||
          ref.read(activeServerProvider)?.connectionKey != connectionKey ||
          serverId != _activeServerId ||
          profile.id != state.activeAgentProfile?.id ||
          key != _launchKey(state.activeAgentProfile!) ||
          !identical(
            ref.read(sshClientManagerProvider).getClient(serverId!),
            client,
          ) ||
          isAgentUpdateLocked(ref, profile)) {
        throw StateError('ACP_TARGET_CHANGED');
      }
      return AcpRemoteSessionPage(
        page.sessions
            .map(
              (s) => AcpRemoteSession(
                id: s.sessionId,
                title: s.title ?? s.sessionId,
                workingDirectory: s.cwd,
                serverId: serverId,
                agentId: profile.id,
                launchKey: key,
              ),
            )
            .toList(),
        page.nextCursor,
      );
    } finally {
      adapter?.dispose();
      _remoteCatalogQueries--;
    }
  }

  Future<void> openRemoteSession(
    AcpRemoteSession remote, {
    bool reimport = false,
    bool recoverExisting = false,
  }) async {
    if (state.isGenerating ||
        state.isLoadingMessages ||
        state.isLoadingSessions) {
      return;
    }
    final profile = state.activeAgentProfile;
    if (profile == null ||
        remote.serverId != _activeServerId ||
        remote.agentId != profile.id ||
        remote.launchKey != _launchKey(profile)) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    if (!remote.workingDirectory.startsWith('/') ||
        remote.workingDirectory.contains('\u0000')) {
      throw StateError('ACP_WORKING_DIRECTORY_INVALID');
    }
    final client = ref
        .read(sshClientManagerProvider)
        .getClient(remote.serverId);
    if (client == null) throw StateError(disconnectedCode);
    _rememberDraft();
    if (!recoverExisting) _resetAdapter();
    final epoch = _requestEpoch;
    final repo = ref.read(chatRepositoryProvider);
    if (!recoverExisting) {
      state = state.copyWith(isLoadingMessages: true, clearError: true);
    }
    ACPClientAdapter? adapter;
    StreamSubscription<ACPEvent>? subscription;
    var retainedAdapter = false;
    void retainReplayAdapter() {
      final candidate = adapter;
      if (candidate == null ||
          candidate.isDisposed ||
          !ref.mounted ||
          epoch != _requestEpoch) {
        return;
      }
      candidate.finishReplayCapture();
      _currentAdapter?.dispose();
      _currentAdapter = candidate;
      _currentAdapterAgentId = profile.id;
      _currentAdapterSessionId = state.activeSessionId;
      _currentAdapterServerId = remote.serverId;
      _currentAdapterLaunchKey = remote.launchKey;
      candidate.setInBackground(!ref.read(appVisibilityProvider));
      retainedAdapter = true;
    }

    var pendingWrites = 0;
    var writeTail = Future<void>.value();
    Object? writeError;
    try {
      var local = recoverExisting
          ? state.activeSession
          : await repo.findRemoteSession(
              remote.serverId,
              profile.id,
              remote.id,
            );
      if (reimport) local = null;
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      if (local == null || recoverExisting) {
        final now = DateTime.now();
        local ??= ChatSession(
          id: _uuid.v4(),
          title: remote.title,
          serverId: remote.serverId,
          agentId: profile.id,
          workingDirectory: remote.workingDirectory,
          historyImportIncomplete: true,
          createdAt: now,
          updatedAt: now,
        );
        final imported = local;
        if (!recoverExisting) await repo.saveSession(imported);
        final transport = await ref.read(acpTransportFactoryProvider)(
          profile,
          client,
        );
        adapter = ACPClientAdapter(
          profile: profile,
          transport: transport,
          workingDirectory: remote.workingDirectory,
          resumeSessionId: remote.id,
          captureReplay: true,
        );
        var sequence = 0;
        var batch = <ChatMessage>[];
        MessageRole? role;
        var text = StringBuffer();
        var thinking = StringBuffer();
        var tools = <ToolExecution>[];
        var blocks = <ChatContentBlock>[];
        var plan = <PlanStep>[];
        String? messageId;
        var resourceBlocks = <ContentBlock>[];
        var batchResources = <String, List<ContentBlock>>{};
        void writeBatch() {
          if (batch.isEmpty) {
            return;
          }
          final snapshot = imported.copyWith(
            messages: batch,
            messageOffset: sequence - batch.length,
          );
          batch = [];
          final resources = batchResources;
          batchResources = {};
          pendingWrites++;
          if (pendingWrites >= 2 && transport is AcpSshTransport) {
            transport.pauseIncoming();
          }
          writeTail = writeTail
              .then((_) async {
                if (writeError != null ||
                    !ref.mounted ||
                    epoch != _requestEpoch) {
                  return;
                }
                final store = ref.read(acpAttachmentStoreProvider);
                final messages = <ChatMessage>[];
                for (final message in snapshot.messages) {
                  final attachments = <ChatAttachment>[];
                  for (final block
                      in resources[message.id] ?? const <ContentBlock>[]) {
                    try {
                      attachments.add(await store.fromBlock(block));
                    } catch (error) {
                      if (error is! StateError ||
                          !const [
                            'ACP_ATTACHMENT_CORRUPT',
                            'ACP_ATTACHMENT_TOO_LARGE',
                          ].contains(error.message)) {
                        rethrow;
                      }
                      // Preserve the message even if one remote attachment is unusable.
                      attachments.add(
                        ChatAttachment(
                          id: '${message.id}:${attachments.length}',
                          name: block is ImageContent ? 'image' : 'resource',
                          mimeType: block is ImageContent
                              ? block.mimeType
                              : 'application/octet-stream',
                          sizeBytes: 0,
                        ),
                      );
                    }
                  }
                  messages.add(message.copyWith(attachments: attachments));
                }
                if (!ref.mounted || epoch != _requestEpoch) {
                  return;
                }
                if (recoverExisting) {
                  await repo.mergeReplayBatch(
                    snapshot.copyWith(messages: messages),
                    profile.id,
                  );
                } else {
                  await repo.saveSession(snapshot.copyWith(messages: messages));
                }
              })
              .catchError((Object error) {
                writeError = error;
                adapter?.dispose();
              })
              .whenComplete(() {
                pendingWrites--;
                if (pendingWrites < 2 && transport is AcpSshTransport) {
                  transport.resumeIncoming();
                }
              });
        }

        void finishMessage() {
          if (role == null) {
            return;
          }
          final id = _uuid.v4();
          if (resourceBlocks.isNotEmpty) batchResources[id] = resourceBlocks;
          batch.add(
            ChatMessage(
              id: id,
              remoteMessageId: messageId,
              agentId: profile.id,
              role: role!,
              content: text.toString(),
              thinking: thinking.isEmpty ? null : thinking.toString(),
              toolExecutions: tools,
              contentBlocks: blocks,
              planSteps: plan,
              createdAt: now,
            ),
          );
          sequence++;
          text = StringBuffer();
          thinking = StringBuffer();
          tools = [];
          blocks = [];
          plan = [];
          resourceBlocks = [];
          messageId = null;
          role = null;
          if (batch.length >= 50) writeBatch();
        }

        void useRole(MessageRole next, [String? nextId]) {
          if (role != null &&
              (role != next ||
                  (messageId != null &&
                      nextId != null &&
                      messageId != nextId))) {
            finishMessage();
          }
          role = next;
          messageId = nextId ?? messageId;
        }

        subscription = adapter.eventStream.listen((event) {
          if (!ref.mounted || epoch != _requestEpoch) {
            adapter?.dispose();
            return;
          }
          if (event is ACPUserContentChunkEvent) {
            useRole(MessageRole.user, event.messageId);
            blocks = ChatContentBlock.appendText(
              blocks,
              text.length,
              text.length + event.chunk.length,
            );
            text.write(event.chunk);
          } else if (event is ACPContentChunkEvent) {
            useRole(MessageRole.assistant, event.messageId);
            blocks = ChatContentBlock.appendText(
              blocks,
              text.length,
              text.length + event.chunk.length,
            );
            text.write(event.chunk);
          } else if (event is ACPThinkingChunkEvent) {
            useRole(MessageRole.assistant, event.messageId);
            thinking.write(event.chunk);
          } else if (event is ACPAttachmentEvent) {
            useRole(event.role, event.messageId);
            resourceBlocks.add(event.content);
          } else if (event is ACPToolExecutionEvent) {
            useRole(MessageRole.assistant);
            final index = tools.indexWhere(
              (t) => t.id == event.toolExecution.id,
            );
            if (index < 0) {
              tools.add(event.toolExecution);
              blocks = ChatContentBlock.appendTool(
                blocks,
                event.toolExecution.id,
              );
            } else {
              tools[index] = event.toolExecution;
            }
          } else if (event is ACPPlanUpdateEvent) {
            useRole(MessageRole.assistant);
            plan = event.planSteps;
          } else if (event is ACPPermissionRequestEvent) {
            event.responseCompleter.complete(null);
          }
          _handleControlEvent(event, adapter!);
        });
        final authMethod =
            state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
        if (authMethod != null) await adapter.authenticate(authMethod);
        await adapter.prepareSession();
        finishMessage();
        writeBatch();
        await writeTail;
        if (writeError != null) throw writeError!;
        if (!ref.mounted || epoch != _requestEpoch) {
          return;
        }
        if (!recoverExisting) {
          await repo.saveSession(
            imported.copyWith(
              messageOffset: sequence,
              totalMessageCount: sequence,
              remoteSessionId: remote.id,
              historyImportIncomplete: false,
              agentContexts: {
                profile.id: AgentChatContext(
                  remoteSessionId: remote.id,
                  syncedMessageCount: sequence,
                ),
              },
            ),
          );
        }
        local = await repo.loadSession(
          imported.id,
          before: recoverExisting
              ? imported.messageOffset + imported.messages.length + 500
              : null,
          limit: recoverExisting
              ? 500 + imported.messages.length.clamp(0, 500)
              : 50,
        );
        if (!ref.mounted || epoch != _requestEpoch) {
          return;
        }
        if (recoverExisting &&
            local != null &&
            (sequence == 0 ||
                (local.agentContexts.keys.every((id) => id == profile.id) &&
                    local.participantAgentIds.every((id) => id == profile.id) &&
                    sequence < local.totalMessageCount))) {
          state = state.copyWith(
            recoveryStatus: SessionRecoveryStatus.incomplete,
          );
        }
      }
      if (!ref.mounted || epoch != _requestEpoch || local == null) {
        return;
      }
      if (recoverExisting) {
        final visible = state.activeSession;
        if (visible == null || visible.id != local.id) {
          return;
        }
        final refreshed = {
          for (final message in local.messages) message.id: message,
        };
        final ids = visible.messages.map((m) => m.id).toSet();
        _updateSessionInState(
          visible.copyWith(
            messages: [
              for (final message in visible.messages)
                refreshed[message.id] ?? message,
              ...local.messages.where((m) => !ids.contains(m.id)),
            ],
            totalMessageCount: local.totalMessageCount,
          ),
        );
        if (local.messageOffset + local.messages.length <
            local.totalMessageCount) {
          state = state.copyWith(
            recoveryStatus: SessionRecoveryStatus.incomplete,
          );
        }
        retainReplayAdapter();
        return;
      }
      state = state.copyWith(
        sessions: [local, ...state.sessions.where((s) => s.id != local!.id)],
        activeSessionId: local.id,
        isLoadingMessages: false,
      );
      _blankDraftRequested = false;
      _restoreDraft();
      await ref
          .read(localStorageServiceProvider)
          .saveLastChatSessionId(
            remote.serverId,
            profile.id,
            local.id,
            cli: false,
          );
    } catch (error) {
      await writeTail;
      if (recoverExisting &&
          error is StateError &&
          error.message == 'ACP_HISTORY_REPLAY_UNSUPPORTED') {
        // initialize succeeded but load is absent: resume on this SAME transport.
        retainReplayAdapter();
      }
      if (!recoverExisting && ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: 'ACP_HISTORY_IMPORT_FAILED: $error',
        );
      }
      rethrow;
    } finally {
      await subscription?.cancel();
      if (!retainedAdapter) adapter?.dispose();
      if (!recoverExisting && ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingMessages: false);
      }
    }
  }

  Future<void> _loadSelectedMessages({bool older = false}) async {
    final active = state.activeSession;
    if (active == null || state.isLoadingMessages || state.isGenerating) {
      return;
    }
    if (!older && active.messages.isNotEmpty) {
      return;
    }
    if (older && active.messageOffset == 0) {
      return;
    }
    final elapsed = Stopwatch()..start();
    var outcome = 'failed';
    int? count;
    final serverId = _activeServerId;
    final epoch = _requestEpoch;
    state = state.copyWith(isLoadingMessages: true);
    try {
      final loaded = await ref
          .read(chatRepositoryProvider)
          .loadSession(active.id, before: older ? active.messageOffset : null);
      if (!ref.mounted ||
          epoch != _requestEpoch ||
          state.activeSessionId != active.id ||
          _activeServerId != serverId) {
        outcome = 'superseded';
        return;
      }
      count = loaded?.messages.length ?? 0;
      outcome = 'completed';
      if (loaded != null) {
        _updateSessionInState(
          older
              ? loaded.copyWith(
                  messages: [...loaded.messages, ...active.messages],
                )
              : loaded,
        );
      }
    } catch (error) {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: 'CHAT_MESSAGES_LOAD_FAILED: $error',
        );
      }
    } finally {
      unawaited(
        AppDiagnostics.instance.recordTiming(
          'acp.history',
          elapsed,
          outcome: outcome,
          count: count,
        ),
      );
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingMessages: false);
        if (!older &&
            state.activeSession
                    ?.contextFor(state.activeAgentProfile?.id ?? '')
                    .persistentRuntimeKey !=
                null) {
          _autoRecoverConnection();
        }
      }
    }
  }

  Future<void> loadOlderMessages() => _loadSelectedMessages(older: true);

  Future<ChatToolOutputPage> loadToolOutput(
    String messageId,
    String toolId, {
    int offset = 0,
  }) async {
    final session = state.activeSession;
    final message = session?.messages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (session == null ||
        message == null ||
        !message.toolExecutions.any((t) => t.id == toolId && t.hasMoreOutput)) {
      throw StateError('CHAT_TOOL_OUTPUT_NOT_FOUND');
    }
    final epoch = _requestEpoch;
    final page = await ref
        .read(chatRepositoryProvider)
        .loadToolOutput(session.id, messageId, toolId, offset: offset);
    if (!ref.mounted ||
        epoch != _requestEpoch ||
        state.activeSessionId != session.id) {
      throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
    }
    return page;
  }

  Future<void> renameSession(String id, String title) async {
    if (title.trim().isEmpty || !state.sessions.any((s) => s.id == id)) {
      return;
    }
    final epoch = _requestEpoch;
    await ref.read(chatRepositoryProvider).renameSession(id, title.trim());
    if (!ref.mounted || epoch != _requestEpoch) {
      return;
    }
    state = state.copyWith(
      sessions: state.sessions
          .map((s) => s.id == id ? s.copyWith(title: title.trim()) : s)
          .toList(),
    );
  }

  Future<String> exportSession(String id) {
    if (!state.sessions.any((s) => s.id == id)) {
      throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
    }
    return ref.read(chatRepositoryProvider).exportSession(id);
  }

  Future<void> updateRunSettings(ChatRunSettings settings) async {
    if (state.isServerBusy && !state.isViewingRun) {
      throw StateError('ACP_RUNTIME_SERVER_BUSY');
    }
    await _adoptFinishedRun();
    if (settings.customModel && !_validCustomModel(settings.modelId)) {
      throw StateError('ACP_CUSTOM_MODEL_INVALID');
    }
    if (_isPreparingPrompt ||
        state.isGenerating ||
        state.recoveryStatus == SessionRecoveryStatus.syncing ||
        state.isAuthenticating ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return;
    }
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId == null || agentId == null) {
      return;
    }
    if (isAgentUpdateLocked(ref, state.activeAgentProfile!)) {
      throw StateError('AGENT_UPDATE_IN_PROGRESS');
    }
    final epoch = _requestEpoch;
    final previousSettings = state.runSettings;
    final storage = ref.read(localStorageServiceProvider);
    final previousDefault = storage.getChatRunDefault(serverId, agentId);
    final previousSession = state.activeSession;
    var defaultSaved = false;
    var sessionSaveAttempted = false;
    ACPClientAdapter? applyingAdapter;
    ChatRunSettings? rollbackSettings;
    state = state.copyWith(isApplyingSettings: true, clearError: true);
    try {
      final adapter = _currentAdapter;
      final unstarted = state.activeSession;
      if (unstarted == null ||
          (usesStandardCodexAcp(state.activeAgentProfile!) &&
              unstarted.contextFor(agentId).remoteSessionId == null &&
              adapter?.sessionId == null)) {
        // New standard Codex processes receive the chosen model before session/new.
        await ref
            .read(localStorageServiceProvider)
            .saveChatRunDefault(serverId, agentId, settings);
        defaultSaved = true;
        if (!ref.mounted || epoch != _requestEpoch) {
          return;
        }
        if (unstarted != null) {
          final updated = unstarted.copyWith(
            agentRunSettings: {
              ...unstarted.agentRunSettings,
              agentId: settings,
            },
          );
          sessionSaveAttempted = true;
          await ref.read(chatRepositoryProvider).saveSession(updated);
          if (!ref.mounted || epoch != _requestEpoch) {
            return;
          }
          _updateSessionInState(updated);
        }
        state = state.copyWith(runSettings: settings);
        if (usesStandardCodexAcp(state.activeAgentProfile!) &&
            _currentAdapter?.sessionId == null &&
            previousSettings.modelId != settings.modelId) {
          _draftRuntimeEpoch++;
          _composerQuery = null;
          _openingAdapter = null;
          _openingAdapterKey = null;
          _currentAdapter?.dispose();
          _currentAdapter = null;
          _currentAdapterInitialModelId = null;
          unawaited(_acpSub?.cancel());
          _acpSub = null;
        }
        return;
      }
      if (adapter == null) {
        throw StateError('ACP_SETTINGS_NOT_READY');
      }
      // Restoring a session is necessary only to apply the user's change,
      // never to discover the list offered in the model selector.
      await adapter.prepareSession();
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      applyingAdapter = adapter;
      rollbackSettings = _confirmedSettings(adapter, previousSettings);
      await _applyAcpSettings(adapter, settings);
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      settings = _confirmedSettings(adapter, settings);
      await ref
          .read(localStorageServiceProvider)
          .saveChatRunDefault(serverId, agentId, settings);
      defaultSaved = true;
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      final session = state.activeSession;
      if (session != null) {
        final updated = session.copyWith(
          agentRunSettings: {...session.agentRunSettings, agentId: settings},
        );
        sessionSaveAttempted = true;
        await ref.read(chatRepositoryProvider).saveSession(updated);
        if (!ref.mounted || epoch != _requestEpoch) {
          return;
        }
        _updateSessionInState(updated);
      }
      if (!ref.mounted || epoch != _requestEpoch) {
        return;
      }
      state = state.copyWith(runSettings: settings);
    } catch (error) {
      Object reportedError = error;
      if (ref.mounted && epoch == _requestEpoch && defaultSaved) {
        try {
          await storage.saveChatRunDefault(serverId, agentId, previousDefault);
          if (sessionSaveAttempted && previousSession != null) {
            await ref.read(chatRepositoryProvider).saveSession(previousSession);
          }
        } catch (rollbackError) {
          reportedError = StateError(
            'ACP_SETTINGS_STORAGE_ROLLBACK_FAILED: $error; $rollbackError',
          );
        }
      }
      if (ref.mounted &&
          epoch == _requestEpoch &&
          applyingAdapter != null &&
          rollbackSettings != null) {
        try {
          await _applyAcpSettings(applyingAdapter, rollbackSettings);
          if (ref.mounted && epoch == _requestEpoch) {
            state = state.copyWith(runSettings: previousSettings);
          }
        } catch (rollbackError) {
          reportedError = StateError(
            'ACP_SETTINGS_ROLLBACK_FAILED: $reportedError; $rollbackError',
          );
          if (ref.mounted && epoch == _requestEpoch) {
            state = state.copyWith(
              runSettings: _confirmedSettings(
                applyingAdapter,
                previousSettings,
              ),
              settingsStale: true,
            );
          }
        }
      }
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: LogSanitizer.sanitize(reportedError.toString()),
          diagnostics: _currentAdapter?.diagnostics,
        );
      }
      if (identical(reportedError, error)) rethrow;
      throw reportedError;
    } finally {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isApplyingSettings: false);
      }
    }
  }

  Future<void> setShareAgentSessions(bool enabled) async {
    final serverId = _activeServerId;
    if (serverId == null || state.isGenerating) {
      return;
    }
    await ref
        .read(localStorageServiceProvider)
        .setShareAgentSessions(serverId, enabled);
    if (!ref.mounted || _activeServerId != serverId) {
      return;
    }
    state = state.copyWith(shareAgentSessions: enabled);
    await _refreshVisibleSessions();
  }

  Future<void> bindActiveSessionToCurrentServer({
    String? expectedSessionId,
    String? expectedServerId,
  }) async {
    final current = state.activeSession;
    final serverId = _activeServerId;
    if (state.isGenerating) {
      return;
    }
    if ((expectedSessionId != null && current?.id != expectedSessionId) ||
        (expectedServerId != null && serverId != expectedServerId)) {
      state = state.copyWith(lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH');
      return;
    }
    if (current == null || serverId == null || current.serverId != null) {
      return;
    }
    final updated = current.copyWith(serverId: serverId);
    await ref.read(chatRepositoryProvider).saveSession(updated);
    _updateSessionInState(updated);
    state = state.copyWith(clearError: true);
  }

  Future<void> stopGeneration() => _stopGeneration();

  Future<void> stopViewingRun({
    required String expectedServerKey,
    required String expectedSessionId,
  }) async {
    if (_serverTargetKey != expectedServerKey ||
        state.activeSessionId != expectedSessionId) {
      return;
    }
    await _stopGeneration();
  }

  Future<void> _stopGeneration({bool cancelRemote = true}) async {
    final key = _serverTargetKey;
    final background = _backgroundRuns[key];
    if (background != null &&
        background.session.id == state.activeSessionId &&
        background.profile.id == state.activeAgentProfile?.id) {
      await background.detach(cancelRemote: cancelRemote);
      if (cancelRemote) _backgroundRuns.remove(key);
      if (ref.mounted && key == _serverTargetKey) {
        state = state.copyWith(
          isGenerating: false,
          clearPermission: true,
          clearServerRun: cancelRemote,
          serverRun: cancelRemote ? null : _runSummary(background),
        );
      }
      return;
    }
    _closeAuthLoopback();
    final epoch = _requestEpoch;
    var current = await _captureRuntimeSnapshot();
    if (!ref.mounted || epoch != _requestEpoch) {
      return;
    }
    _streamTimer?.cancel();
    _checkpointTimer?.cancel();
    _flushStream = null;
    _requestEpoch++;
    final permission = state.permissionCompleter;
    if (permission != null && !permission.isCompleted) {
      permission.complete(null);
    }
    for (final pending in _permissionQueue) {
      if (!pending.responseCompleter.isCompleted) {
        pending.responseCompleter.complete(null);
      }
    }
    _permissionQueue.clear();
    final auth = state.authCompleter;
    if (auth != null && !auth.isCompleted) auth.complete(null);
    final subscription = _acpSub;
    _acpSub = null;
    if (cancelRemote) _currentAdapter?.cancelPrompt();
    _currentAdapter?.dispose();
    _currentAdapter = null;
    _currentAdapterLaunchKey = null;
    if (current != null) {
      current = current.copyWith(
        messages: current.messages
            .map(
              (message) => message.status == ChatTurnStatus.streaming
                  ? message.copyWith(
                      status: cancelRemote
                          ? ChatTurnStatus.interrupted
                          : ChatTurnStatus.unknown,
                    )
                  : message,
            )
            .toList(),
      );
      _updateSessionInState(current);
    }
    final repo = ref.read(chatRepositoryProvider);
    state = state.copyWith(
      isGenerating: false,
      clearServerRun: _backgroundRuns[_serverTargetKey] == null,
      // The epoch also cancels history loads; their stale finally cannot clear it.
      isLoadingMessages: false,
      isLoadingSettings: false,
      isApplyingSettings: false,
      clearPermission: true,
      clearAuthChallenge: true,
      authenticationConfirmed: false,
    );
    await subscription?.cancel();
    if (current != null) {
      await repo.saveSession(current);
    }
  }

  Future<void> checkpoint() {
    return _checkpointing ??= _checkpoint().whenComplete(
      () => _checkpointing = null,
    );
  }

  Future<void> _checkpoint() async {
    final current = await _captureRuntimeSnapshot();
    if (!ref.mounted) {
      return;
    }
    _rememberDraft(persist: false);
    final key = _draftKey;
    final text = state.draftText;
    final directory = _draftWorkingDirectory;
    final pending = state.attachments;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final store = ref.read(acpAttachmentStoreProvider);
      final storage = ref.read(localStorageServiceProvider);
      // Persist the stream before potentially slower image writes.
      if (current != null) await repo.saveSession(current);
      final saved = <ChatAttachment>[];
      for (final item in pending) {
        saved.add(
          await store.save(item.name, item.mimeType, item.bytes, uri: item.uri),
        );
      }
      if (!ref.mounted ||
          key != _draftKey ||
          text != state.draftText ||
          directory != _draftWorkingDirectory ||
          !identical(pending, state.attachments)) {
        return;
      }
      final save = _draftSaveChain.then((_) async {
        if (!ref.mounted ||
            key != _draftKey ||
            text != state.draftText ||
            directory != _draftWorkingDirectory ||
            !identical(pending, state.attachments)) {
          return;
        }
        await storage.saveChatDraft(key, {
          'text': text,
          'directory': directory,
          'attachments': saved.map((a) => a.toJson()).toList(),
        });
      });
      // A failed checkpoint must not poison every later debounced draft save.
      _draftSaveChain = save.catchError((Object _) {});
      await save;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED: $error');
      }
    }
  }

  Future<void> _connectionLost() {
    return _connectionLoss ??= _handleConnectionLost().whenComplete(
      () => _connectionLoss = null,
    );
  }

  Future<void> _handleConnectionLost() async {
    _recovering = null;
    cancelWorkspaceBrowse();
    final needsReplay =
        state.isGenerating ||
        state.activeSession?.messages.any(
              (m) =>
                  m.status == ChatTurnStatus.streaming ||
                  m.status == ChatTurnStatus.unknown,
            ) ==
            true;
    state = state.copyWith(
      recoveryStatus: needsReplay
          ? SessionRecoveryStatus.reconnecting
          : SessionRecoveryStatus.idle,
      recoveryNoticeDismissed: false,
      settingsStale: true,
    );
    try {
      final background = _backgroundRuns[_serverTargetKey];
      if (background != null) {
        if (background.isBusy) background.state = 'reconnecting';
        await background.detach();
        _backgroundChanged(background);
        return;
      }
      await _stopGeneration(cancelRemote: false);
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED: $error');
      }
    }
  }

  Future<void> recoverConnection() {
    if (_recovering != null) return _recovering!;
    late final Future<void> future;
    future = _recoverConnection().whenComplete(() {
      if (identical(_recovering, future)) _recovering = null;
    });
    _recovering = future;
    return future;
  }

  void _autoRecoverConnection() async {
    await _refreshRunningTask();
    if (!ref.mounted) {
      return;
    }
    if (_backgroundRuns[_serverTargetKey] != null) {
      unawaited(recoverConnection());
      return;
    }
    if (state.isAuthenticating) {
      return;
    }
    // An incomplete/failed attempt is explicit-retry territory. Foreground
    // notifications must not repeatedly reload the same history or restart ACP.
    if (state.recoveryStatus == SessionRecoveryStatus.incomplete ||
        state.recoveryStatus == SessionRecoveryStatus.failed) {
      return;
    }
    // A cancelled turn is not pending recovery. Old interrupted history can
    // still be explicitly retried, but foreground alone must not reload it.
    if (state.recoveryStatus == SessionRecoveryStatus.idle &&
        !(state.activeSession
                    ?.contextFor(state.activeAgentProfile?.id ?? '')
                    .persistentRuntimeKey !=
                null &&
            _currentAdapter == null) &&
        state.activeSession?.messages.any(
              (message) =>
                  message.status == ChatTurnStatus.unknown ||
                  message.status == ChatTurnStatus.streaming,
            ) !=
            true) {
      return;
    }
    unawaited(recoverConnection());
  }

  Future<void> _refreshRunningTask() async {
    final serverId = _activeServerId;
    final consent = _persistentConsentIdentity;
    if (!ref.read(persistentAcpRuntimeEnabledProvider) ||
        consent == null ||
        !ref
            .read(localStorageServiceProvider)
            .getPersistentAcpConsent(consent)) {
      return;
    }
    if (serverId == null ||
        !ref.read(appVisibilityProvider) ||
        ref.read(agentUpdateLockProvider).contains('server:$serverId') ||
        !ref.read(serverConnectionProvider).isConnected ||
        _isPreparingPrompt ||
        state.isGenerating ||
        _currentAdapter != null ||
        _backgroundRuns[_serverTargetKey] != null) {
      return;
    }
    final client = ref.read(sshClientManagerProvider).getClient(serverId);
    if (client == null) {
      return;
    }
    final target = _serverTargetKey;
    await _discoverRunningTask(client, serverId).catchError((
      Object error,
      StackTrace stack,
    ) {
      if (!ref.mounted || _serverTargetKey != target) {
        return;
      }
      if (error.toString().contains('ACP_RUNTIME_SERVER_BUSY')) {
        state = state.copyWith(lastErrorCode: 'ACP_RUNTIME_SERVER_BUSY');
      } else {
        unawaited(
          AppDiagnostics.instance.record(
            'acp.background.discover',
            error,
            stack,
          ),
        );
      }
    });
  }

  Future<void> _recoverConnection() async {
    await _connectionLoss;
    if (!ref.mounted) {
      return;
    }
    final background = _backgroundRuns[_serverTargetKey];
    if (background != null &&
        ref.read(appVisibilityProvider) &&
        ref.read(serverConnectionProvider).isConnected) {
      final client = ref
          .read(sshClientManagerProvider)
          .getClient(background.profile.serverId);
      if (client != null) await _reconnectBackground(background, client);
      if (ref.mounted &&
          state.activeSessionId == background.session.id &&
          background.state != 'reconnecting') {
        state = state.copyWith(recoveryStatus: SessionRecoveryStatus.idle);
      }
      return;
    }
    if (!ref.read(appVisibilityProvider) ||
        !ref.read(serverConnectionProvider).isConnected ||
        state.isGenerating ||
        state.isLoadingSessions ||
        state.isLoadingMessages) {
      return;
    }
    final session = state.activeSession;
    final profile = state.activeAgentProfile;
    if (session == null || profile == null) {
      state = state.copyWith(recoveryStatus: SessionRecoveryStatus.idle);
      return;
    }
    if (isAgentUpdateLocked(ref, profile)) {
      return;
    }
    final remoteId = session.contextFor(profile.id).remoteSessionId;
    if (session.contextFor(profile.id).persistentRuntimeKey != null) {
      await _recoverPersistentRuntime(session, profile);
      return;
    }
    if (remoteId == null) {
      state = state.copyWith(recoveryStatus: SessionRecoveryStatus.idle);
      return;
    }
    if (state.recoveryStatus == SessionRecoveryStatus.idle &&
        !session.messages.any(
          (m) =>
              m.status == ChatTurnStatus.interrupted ||
              m.status == ChatTurnStatus.unknown ||
              m.status == ChatTurnStatus.streaming,
        )) {
      return;
    }
    final epoch = _requestEpoch;
    final serverId = _activeServerId;
    bool current() =>
        ref.mounted &&
        epoch == _requestEpoch &&
        _activeServerId == serverId &&
        state.activeSessionId == session.id &&
        state.activeAgentProfile?.id == profile.id;
    state = state.copyWith(
      recoveryStatus: SessionRecoveryStatus.syncing,
      recoveryNoticeDismissed: false,
    );
    final elapsed = Stopwatch()..start();
    var outcome = 'superseded';
    var incomplete = false;
    try {
      try {
        await openRemoteSession(
          AcpRemoteSession(
            id: remoteId,
            title: session.title,
            workingDirectory: session.workingDirectory,
            serverId: serverId!,
            agentId: profile.id,
            launchKey: _launchKey(profile),
          ),
          recoverExisting: true,
        );
        incomplete = state.recoveryStatus == SessionRecoveryStatus.incomplete;
      } on StateError catch (error) {
        if (!const [
          'ACP_HISTORY_REPLAY_UNSUPPORTED',
          'ACP_HISTORY_REPLAY_AMBIGUOUS',
        ].contains(error.message)) {
          rethrow;
        }
        incomplete = true;
      }
      if (!current()) {
        return;
      }
      final client = ref.read(sshClientManagerProvider).getClient(serverId!);
      if (client == null) throw StateError(disconnectedCode);
      final adapter = await _adapterFor(profile, client);
      if (!current()) {
        return;
      }
      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen((event) {
        if (event is ACPPermissionRequestEvent) {
          // Recovery must never replay approval decisions or execute a prompt.
          event.responseCompleter.complete(null);
        }
        _handleControlEvent(event, adapter);
      });
      final auth =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (auth != null) await adapter.authenticate(auth);
      await adapter.prepareSession();
      if (!current()) {
        return;
      }
      _handleControlEvent(ACPSettingsChangedEvent(), adapter);
      final latest = state.activeSession!;
      incomplete =
          incomplete ||
          latest.messages.any(
            (message) =>
                message.status == ChatTurnStatus.unknown ||
                message.status == ChatTurnStatus.streaming,
          );
      if (!incomplete &&
          latest.agentId == profile.id &&
          latest.participantAgentIds.every((id) => id == profile.id) &&
          latest.agentContexts.keys.every((id) => id == profile.id)) {
        final synced = latest.copyWith(
          agentContexts: {
            ...latest.agentContexts,
            profile.id: AgentChatContext(
              remoteSessionId: remoteId,
              syncedMessageCount: latest.totalMessageCount,
            ),
          },
        );
        _updateSessionInState(synced);
        await ref
            .read(chatRepositoryProvider)
            .saveSession(synced.copyWith(messages: const []));
        if (!current()) {
          return;
        }
      }
      state = state.copyWith(
        acpSessionRestored: adapter.restoredExistingSession,
        recoveryStatus: incomplete
            ? SessionRecoveryStatus.incomplete
            : SessionRecoveryStatus.idle,
      );
      outcome = incomplete ? 'incomplete' : 'completed';
    } catch (error) {
      outcome = 'failed';
      if (current()) {
        state = state.copyWith(
          recoveryStatus: SessionRecoveryStatus.failed,
          diagnostics: LogSanitizer.sanitize(error.toString()),
        );
      }
    } finally {
      unawaited(
        AppDiagnostics.instance.recordTiming(
          'acp.recovery',
          elapsed,
          outcome: outcome,
        ),
      );
    }
  }

  Future<void> createNewSession([String? title]) async {
    if (_isPreparingPrompt ||
        (state.isGenerating &&
            _currentAdapter?.sessionId == null &&
            _backgroundRuns[_serverTargetKey] == null)) {
      return;
    }
    final expectedTarget = _serverTargetKey;
    await _parkRunningView();
    if (!ref.mounted || expectedTarget != _serverTargetKey) {
      return;
    }
    _rememberDraft();
    _resetAdapter();
    _blankDraftRequested = true;
    state = state.copyWith(
      clearActiveSession: true,
      clearError: true,
      clearAcpSessionRestored: true,
      acpSessionRestartDetected: false,
    );
    _restoreDraft();
  }

  void setDraftWorkingDirectory(String path) {
    if (state.isGenerating ||
        state.isAuthenticating ||
        state.isLoadingSettings ||
        state.isApplyingSettings ||
        state.activeSession != null) {
      return;
    }
    if (!path.startsWith('/') ||
        path.contains('\n') ||
        path.contains('\u0000')) {
      throw ArgumentError('ACP_WORKING_DIRECTORY_INVALID');
    }
    _resetAdapter();
    _draftWorkingDirectory = path;
    state = state.copyWith(draftWorkingDirectory: path);
    _rememberDraft();
  }

  Future<List<String>> listWorkspaceDirectories(String path) async {
    return (await listWorkspaceFiles(
      path,
    )).where((f) => f.isDirectory).map((f) => f.path).toList();
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
      workingDirectory: _draftWorkingDirectory ?? '.',
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
    if (_currentAdapter != null &&
        _currentAdapterSessionId == null &&
        _currentAdapterAgentId == newSession.agentId &&
        _currentAdapterServerId == newSession.serverId) {
      _currentAdapterSessionId = newSession.id;
      final remoteId = _currentAdapter!.sessionId;
      if (remoteId != null) {
        _currentAdapter!.onSessionEstablished?.call(remoteId);
      }
    }
  }

  void _resetAdapter({bool preserveDraftWorkingDirectory = false}) {
    _recoveredRuntimeTimer?.cancel();
    _recoveredRuntimeTimer = null;
    _recoveredRuntimeEvents.clear();
    _closeAuthLoopback();
    cancelModelAuthorization();
    _modelCatalog = null;
    _modelAccountKey = null;
    _composerSkills = const [];
    _composerQuery = null;
    _openingAdapter = null;
    _openingAdapterKey = null;
    cancelWorkspaceBrowse();
    final background = _backgroundRuns[_serverTargetKey];
    if (background == null ||
        background.session.id != state.activeSessionId ||
        background.profile.id != state.activeAgentProfile?.id) {
      _cancelPermissions();
    }
    _requestEpoch++;
    _recovering = null;
    _retryAfterAuth = false;
    _streamTimer?.cancel();
    _checkpointTimer?.cancel();
    _flushStream = null;
    unawaited(_acpSub?.cancel());
    _acpSub = null;
    _currentAdapter?.dispose();
    _currentAdapter = null;
    if (!preserveDraftWorkingDirectory) _draftWorkingDirectory = null;
    state = state.copyWith(
      recoveryStatus: SessionRecoveryStatus.idle,
      recoveryNoticeDismissed: false,
      capabilities: const AgentRuntimeCapabilities(),
      clearAccount: true,
      clearSettingsMetadata: true,
      clearModelCatalogError: true,
      settingsStale: true,
      isLoadingSettings: false,
      isApplyingSettings: false,
      isGenerating: false,
      clearAuthChallenge: true,
      authenticationConfirmed: false,
      clearPermission: true,
      clearDraftWorkingDirectory: !preserveDraftWorkingDirectory,
      commands: const [],
      clearUsage: true,
      diagnostics: '',
      supportsImages: false,
      supportsTextAttachments: false,
      isLoadingMessages: false,
    );
  }

  Future<List<AcpRuntimeStatus>> inspectSessionRuntimes(
    String sessionId,
  ) async {
    final session = state.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (session == null) throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
    final keys = session.agentContexts.values
        .map((context) => context.persistentRuntimeKey)
        .whereType<String>()
        .toSet();
    if (keys.isEmpty) return [];
    final client = _activeServerId == null
        ? null
        : ref.read(sshClientManagerProvider).getClient(_activeServerId!);
    if (client == null) throw StateError(disconnectedCode);
    final target = _serverTargetKey;
    final result = <AcpRuntimeStatus>[];
    for (final key in keys) {
      result.add(
        await ref.read(acpRuntimeInspectorProvider)(client, runtimeKey: key),
      );
      if (!ref.mounted || target != _serverTargetKey) {
        throw StateError('ACP_TARGET_CHANGED');
      }
    }
    return result;
  }

  Future<void> deleteSession(
    String sessionId, {
    bool stopAndClearRemote = false,
    String? expectedServerKey,
  }) async {
    final originalTarget = _serverTargetKey;
    if (expectedServerKey != null && expectedServerKey != _serverTargetKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    if (!state.sessions.any((s) => s.id == sessionId)) {
      throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
    }
    if (state.isGenerating && state.activeSessionId == sessionId) {
      await _parkRunningView();
    }
    if (!ref.mounted || originalTarget != _serverTargetKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    final target = _serverTargetKey;
    final session = state.sessions.firstWhere((item) => item.id == sessionId);
    if (stopAndClearRemote) {
      final keys = session.agentContexts.values
          .map((context) => context.persistentRuntimeKey)
          .whereType<String>()
          .toSet();
      if (keys.isEmpty) throw StateError('ACP_RUNTIME_NOT_MANAGED');
      final client = serverId == null
          ? null
          : ref.read(sshClientManagerProvider).getClient(serverId);
      if (client == null) throw StateError(disconnectedCode);
      for (final key in keys) {
        if (!ref.mounted || target != _serverTargetKey) {
          throw StateError('ACP_TARGET_CHANGED');
        }
        await ref.read(acpRuntimeManagerProvider)(
          client,
          runtimeKey: key,
          action: 'purge',
          stopRunning: true,
        );
      }
    }
    if (!ref.mounted || target != _serverTargetKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    final background = _backgroundRuns[target];
    if (background != null && background.session.id == sessionId) {
      await background.detach();
      _backgroundRuns.remove(target);
    }
    await _runtimeSaving;
    _rememberDraft();
    if (state.activeSessionId == sessionId) _resetAdapter();
    final repo = ref.read(chatRepositoryProvider);
    await repo.deleteSession(sessionId);
    if (!ref.mounted ||
        _activeServerId != serverId ||
        state.activeAgentProfile?.id != agentId) {
      return;
    }
    final updated = state.sessions.where((s) => s.id != sessionId).toList();
    state = state.copyWith(
      sessions: updated,
      clearServerRun: background?.session.id == sessionId,
      clearActiveSession: state.activeSessionId == sessionId && updated.isEmpty,
      activeSessionId: state.activeSessionId == sessionId
          ? updated.firstOrNull?.id
          : state.activeSessionId,
    );
    _drafts.remove('$serverId::$agentId::$sessionId');
    _restoreDraft();
    await _loadSelectedMessages();
  }

  Future<void> sendMessage(String text) async {
    final originTarget = _serverTargetKey;
    final originAgent = state.activeAgentProfile?.id;
    final originSession = state.activeSessionId;
    final originEpoch = _requestEpoch;
    bool sameOrigin() =>
        ref.mounted &&
        originTarget == _serverTargetKey &&
        originAgent == state.activeAgentProfile?.id &&
        originSession == state.activeSessionId &&
        originEpoch == _requestEpoch;
    final background = _backgroundRuns[_serverTargetKey];
    if (background?.isBusy == true) {
      state = state.copyWith(lastErrorCode: 'ACP_RUNTIME_SERVER_BUSY');
      return;
    }
    try {
      await _adoptFinishedRun();
    } catch (error) {
      if (sameOrigin()) {
        state = state.copyWith(
          lastErrorCode:
              'CHAT_SAVE_FAILED: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
      return;
    }
    if (!sameOrigin()) {
      return;
    }
    if (state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing) {
      return;
    }
    final target = state.activeAgentProfile;
    if (target != null && isAgentUpdateLocked(ref, target)) {
      state = state.copyWith(lastErrorCode: 'AGENT_UPDATE_IN_PROGRESS');
      return;
    }
    if ((text.trim().isEmpty && state.attachments.isEmpty) ||
        state.isLoadingMessages ||
        state.isLoadingSessions ||
        state.isGenerating ||
        state.isAuthenticating ||
        _isPreparingPrompt ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return;
    }
    final attachments = state.attachments;
    final sourceDraftKey = _draftKey;
    final displayText = text;
    final requestedSettings = state.runSettings;
    final requestEpoch = ++_requestEpoch;

    // 就绪守卫：没有可用 Agent 时阻止发送，绝不平移到另一个 Agent。
    final profile = state.activeAgentProfile;
    if (profile == null) {
      state = state.copyWith(lastErrorCode: notReadyCode);
      return;
    }

    final consentIdentity = _persistentConsentIdentity;
    if (ref.read(persistentAcpRuntimeEnabledProvider) &&
        consentIdentity != null &&
        !ref
            .read(localStorageServiceProvider)
            .getPersistentAcpConsent(consentIdentity)) {
      state = state.copyWith(
        persistentRuntimeSetupRequired: true,
        clearPersistentRuntimeSetupError: true,
      );
      return;
    }

    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);
    final sshManager = ref.read(sshClientManagerProvider);
    final sshClient = (activeServer != null && connState.isConnected)
        ? sshManager.getClient(activeServer.id)
        : null;

    if (sshClient == null || activeServer == null) {
      state = state.copyWith(lastErrorCode: disconnectedCode);
      return;
    }

    _isPreparingPrompt = true;
    try {
      await _discoverRunningTask(sshClient, activeServer.id);
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      if (_backgroundRuns[_serverTargetKey]?.isBusy == true) {
        state = state.copyWith(lastErrorCode: 'ACP_RUNTIME_SERVER_BUSY');
        return;
      }
    } catch (error) {
      if (ref.mounted && requestEpoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: LogSanitizer.sanitize(error.toString()),
        );
      }
      return;
    } finally {
      _isPreparingPrompt = false;
    }

    var session = state.activeSession;
    if (session?.historyImportIncomplete == true) {
      state = state.copyWith(lastErrorCode: 'ACP_HISTORY_IMPORT_INCOMPLETE');
      return;
    }
    if (session == null) {
      _isPreparingPrompt = true;
      try {
        // Resolve cwd in the selected execution target before persisting the
        // first local session. This does not issue session/new or a prompt.
        await _adapterFor(profile, sshClient);
        if (!ref.mounted || requestEpoch != _requestEpoch) {
          return;
        }
        await _persistNewSession(
          displayText.trim().isEmpty && attachments.isNotEmpty
              ? attachments.first.name
              : displayText.length > 20
              ? '${displayText.substring(0, 20)}...'
              : displayText,
        );
      } catch (error) {
        if (ref.mounted && requestEpoch == _requestEpoch) {
          state = state.copyWith(lastErrorCode: error.toString());
        }
        return;
      } finally {
        _isPreparingPrompt = false;
      }
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      session = state.activeSession;
      if (session == null || state.activeAgentProfile?.id != profile.id) {
        return;
      }
    }
    if (session.serverId == null) {
      state = state.copyWith(lastErrorCode: 'CHAT_SERVER_BINDING_REQUIRED');
      return;
    }
    if (session.serverId != activeServer.id ||
        (!state.shareAgentSessions && !session.includesAgent(profile.id))) {
      state = state.copyWith(lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH');
      return;
    }

    // Authentication failed before the turn started: retry the pending message
    // without inserting a second copy into local history.
    final retryPending =
        _retryAfterAuth &&
        session.messages.length >= 2 &&
        session.messages.last.role == MessageRole.assistant &&
        session.messages.last.content.isEmpty &&
        session.messages[session.messages.length - 2].content == displayText;
    _retryAfterAuth = false;
    final savedAttachments = <ChatAttachment>[];
    _isPreparingPrompt = true;
    try {
      final store = ref.read(acpAttachmentStoreProvider);
      for (final attachment in attachments) {
        savedAttachments.add(
          await store.save(
            attachment.name,
            attachment.mimeType,
            attachment.bytes,
            uri: attachment.uri,
          ),
        );
      }
    } catch (error) {
      if (ref.mounted && requestEpoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: 'ACP_ATTACHMENT_SAVE_FAILED: $error',
        );
      }
      return;
    } finally {
      _isPreparingPrompt = false;
    }
    if (!ref.mounted || requestEpoch != _requestEpoch) {
      return;
    }
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: displayText,
      attachments: savedAttachments,
      createdAt: DateTime.now(),
    );

    var assistantMsg = retryPending
        ? session.messages.last.copyWith(
            status: ChatTurnStatus.streaming,
            clearFailure: true,
          )
        : ChatMessage(
            status: ChatTurnStatus.streaming,
            agentId: profile.id,
            id: _uuid.v4(),
            role: MessageRole.assistant,
            content: '',
            createdAt: DateTime.now(),
          );

    final runtimeTurnId = assistantMsg.runtimeTurnId ?? assistantMsg.id;
    assistantMsg = assistantMsg.copyWith(runtimeTurnId: runtimeTurnId);

    var currentMessages = retryPending
        ? [...session.messages.take(session.messages.length - 1), assistantMsg]
        : [...session.messages, userMsg, assistantMsg];
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
    state = state.copyWith(
      isGenerating: true,
      clearError: true,
      serverRun: AcpActiveRun(
        serverTargetKey: _serverTargetKey!,
        serverId: activeServer.id,
        sessionId: updatedSession.id,
        agentId: profile.id,
        agentName: profile.name,
        turnId: runtimeTurnId,
      ),
    );

    // 复用已有 adapter 与远端 agent 进程。原先每条消息都重建 transport，
    // 等于每次都重开一个远端进程、丢掉 ACP 会话上下文，这正是
    // 「重连/发第二条消息后内容没了」的根因。
    ACPClientAdapter? adapter;
    // 记录这是不是重建出来的 adapter：只有重建才可能发生「上下文丢失」，
    // 复用同一个 adapter 是正常连续对话，不该弹重启告警。
    var adapterWasRebuilt = false;
    try {
      await ref.read(chatRepositoryProvider).saveSession(updatedSession);
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      final previousAdapter = _currentAdapter;
      adapter = await _adapterFor(profile, sshClient);
      adapterWasRebuilt = !identical(previousAdapter, adapter);

      // 用户此前选定的认证方式必须重新注入：新 adapter 需要它。
      final chosenAuthMethod =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (chosenAuthMethod != null) {
        await adapter.authenticate(chosenAuthMethod);
      }

      await _acpSub?.cancel();
      final content = StringBuffer(assistantMsg.content);
      var blocks = assistantMsg.contentBlocks;
      final thinking = StringBuffer(assistantMsg.thinking ?? '');
      final resourceWrites = <Future<void>>[];
      final store = ref.read(acpAttachmentStoreProvider);
      void flush() {
        if (!ref.mounted || requestEpoch != _requestEpoch) {
          return;
        }
        _streamTimer?.cancel();
        _streamTimer = null;
        if (content.length != assistantMsg.content.length ||
            thinking.length != (assistantMsg.thinking?.length ?? 0) ||
            !identical(blocks, assistantMsg.contentBlocks)) {
          assistantMsg = assistantMsg.copyWith(
            content: content.toString(),
            contentBlocks: blocks,
            thinking: thinking.toString(),
          );
        }
        _updateAssistantMessage(updatedSession, assistantMsg);
      }

      _flushStream = flush;
      void beginAssistantMessage(String? id) {
        if (id == null) {
          return;
        }
        final previousId = assistantMsg.remoteMessageId;
        if (previousId != null && previousId != id) {
          assistantMsg = assistantMsg.copyWith(
            status: ChatTurnStatus.completed,
          );
          flush();
          final latest = state.activeSession;
          if (latest == null) {
            return;
          }
          assistantMsg = ChatMessage(
            id: _uuid.v4(),
            runtimeTurnId: runtimeTurnId,
            agentId: profile.id,
            role: MessageRole.assistant,
            content: '',
            remoteMessageId: id,
            status: ChatTurnStatus.streaming,
            createdAt: DateTime.now(),
          );
          content.clear();
          blocks = [];
          thinking.clear();
          _updateSessionInState(
            latest.copyWith(messages: [...latest.messages, assistantMsg]),
          );
        } else if (previousId != id) {
          assistantMsg = assistantMsg.copyWith(remoteMessageId: id);
        }
      }

      _checkpointTimer?.cancel();
      _checkpointTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!ref.mounted || requestEpoch != _requestEpoch) {
          return;
        }
        if (adapter?.isPersistent == true) {
          unawaited(
            _savePersistentCheckpoint().catchError((Object error) {
              if (ref.mounted) {
                state = state.copyWith(
                  lastErrorCode: 'CHAT_SAVE_FAILED: $error',
                );
              }
            }),
          );
          return;
        }
        flush();
        final visible = state.activeSession;
        final snapshot = visible == null ? null : _runtimeSnapshot(visible);
        if (snapshot == null || snapshot.messages.isEmpty) {
          return;
        }
        final tail = snapshot.copyWith(
          messages: [snapshot.messages.last],
          messageOffset: snapshot.messageOffset + snapshot.messages.length - 1,
        );
        unawaited(
          ref.read(chatRepositoryProvider).saveSession(tail).catchError((
            Object error,
          ) {
            if (ref.mounted && requestEpoch == _requestEpoch) {
              state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED: $error');
            }
          }),
        );
      });
      void scheduleFlush() =>
          _streamTimer ??= Timer(const Duration(milliseconds: 50), flush);
      _acpSub = adapter.eventStream.listen((event) {
        if (!ref.mounted ||
            requestEpoch != _requestEpoch ||
            state.activeSessionId != session!.id ||
            _activeServerId != activeServer.id) {
          return;
        }
        if (event.runtimeTurnId != null &&
            event.runtimeTurnId != runtimeTurnId) {
          _handleControlEvent(event, adapter!);
          _handleRecoveredRuntimeEvent(event, adapter);
          return;
        }
        _handleControlEvent(event, adapter!);
        if (event is ACPThinkingChunkEvent) {
          beginAssistantMessage(event.messageId);
          thinking.write(event.chunk);
          scheduleFlush();
        } else if (event is ACPContentChunkEvent) {
          beginAssistantMessage(event.messageId);
          blocks = ChatContentBlock.appendText(
            blocks,
            content.length,
            content.length + event.chunk.length,
          );
          content.write(event.chunk);
          scheduleFlush();
        } else if (event is ACPAttachmentEvent &&
            event.role == MessageRole.assistant) {
          beginAssistantMessage(event.messageId);
          final targetMessageId = assistantMsg.id;
          // Attach a rejection handler immediately; asynchronous decode failures
          // must not escape while the protocol is still streaming.
          resourceWrites.add(
            _trackRuntimeWrite(
              store
                  .fromBlock(event.content)
                  .then<void>((attachment) {
                    if (!ref.mounted || requestEpoch != _requestEpoch) {
                      return;
                    }
                    if (assistantMsg.id == targetMessageId) {
                      assistantMsg = assistantMsg.copyWith(
                        attachments: [...assistantMsg.attachments, attachment],
                      );
                      flush();
                    } else {
                      final target = state.activeSession?.messages
                          .where((m) => m.id == targetMessageId)
                          .firstOrNull;
                      if (target != null) {
                        _updateAssistantMessage(
                          updatedSession,
                          target.copyWith(
                            attachments: [...target.attachments, attachment],
                          ),
                        );
                      }
                    }
                  })
                  .catchError((Object error) {
                    if (!ref.mounted || requestEpoch != _requestEpoch) {
                      return;
                    }
                    state = state.copyWith(
                      lastErrorCode: 'ACP_ATTACHMENT_SAVE_FAILED: $error',
                    );
                  }),
            ),
          );
        } else if (event is ACPPlanUpdateEvent) {
          assistantMsg = assistantMsg.copyWith(planSteps: event.planSteps);
          _updateAssistantMessage(updatedSession, assistantMsg);
        } else if (event is ACPToolExecutionEvent) {
          final owner = state.activeSession?.messages
              .where(
                (message) =>
                    message.id != assistantMsg.id &&
                    message.agentId == profile.id &&
                    message.toolExecutions.any(
                      (tool) => tool.id == event.toolExecution.id,
                    ),
              )
              .lastOrNull;
          if (owner != null &&
              !assistantMsg.toolExecutions.any(
                (tool) => tool.id == event.toolExecution.id,
              )) {
            flush();
            _updateAssistantMessage(
              updatedSession,
              owner.copyWith(
                toolExecutions: owner.toolExecutions
                    .map(
                      (tool) => tool.id == event.toolExecution.id
                          ? event.toolExecution
                          : tool,
                    )
                    .toList(),
              ),
            );
            return;
          }
          final tools = assistantMsg.toolExecutions.toList();
          final idx = tools.indexWhere((t) => t.id == event.toolExecution.id);
          if (idx >= 0) {
            tools[idx] = event.toolExecution;
          } else {
            tools.add(event.toolExecution);
            blocks = ChatContentBlock.appendTool(
              blocks,
              event.toolExecution.id,
            );
          }
          assistantMsg = assistantMsg.copyWith(toolExecutions: tools);
          flush();
        } else if (event is ACPPermissionRequestEvent) {
          final policy = state.runSettings.permissionPolicy;
          final autoAllow =
              policy == OperationPermissionPolicy.autoAllowAll ||
              (policy == OperationPermissionPolicy.autoAllowSafe &&
                  !event.request.isDangerous);
          final once = event.request.options
              .where((option) => option.kind == 'allow_once')
              .firstOrNull;
          if (autoAllow && once != null) {
            event.responseCompleter.complete(once.id);
          } else if (state.permissionCompleter != null &&
              !state.permissionCompleter!.isCompleted) {
            _permissionQueue.add(event);
          } else {
            state = state.copyWith(
              pendingPermission: event.request,
              permissionCompleter: event.responseCompleter,
            );
          }
        } else if (event is ACPAuthRequiredEvent) {
          assistantMsg = assistantMsg.copyWith(
            status: ChatTurnStatus.awaitingAuthentication,
            failureCode: authRequiredCode,
          );
          flush();
        } else if (event is ACPCompleteEvent) {
          _cancelPermissions();
          if (assistantMsg.status == ChatTurnStatus.streaming) {
            assistantMsg = assistantMsg.copyWith(
              status: ChatTurnStatus.completed,
            );
          }
          flush();
          state = state.copyWith(
            isGenerating: false,
            clearPermission: true,
            clearServerRun: true,
          );
        } else if (event is ACPErrorEvent) {
          _cancelPermissions();
          final failureCode = LogSanitizer.sanitize(event.error);
          assistantMsg = assistantMsg.copyWith(
            status: ChatTurnStatus.failed,
            failureCode: failureCode,
          );
          flush();
          state = state.copyWith(
            isGenerating: false,
            clearServerRun: true,
            clearPermission: true,
            lastErrorCode: failureCode,
          );
        }
      });

      final isNewRemoteSession = adapter.sessionId == null;
      if (_modelCatalog == null && requestedSettings.modelId != null) {
        AgentRuntimeCapabilities? catalog;
        try {
          catalog = await ref.read(agentModelQueryProvider)(profile, sshClient);
        } catch (error) {
          if (ref.mounted && requestEpoch == _requestEpoch) {
            state = state.copyWith(
              modelCatalogError: LogSanitizer.sanitize(error.toString()),
              settingsStale: true,
            );
          }
        }
        if (!ref.mounted || requestEpoch != _requestEpoch) {
          return;
        }
        _modelCatalog = catalog;
      }
      await adapter.prepareSession();
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      if (isNewRemoteSession && !adapter.restoredExistingSession) {
        final supported = _supportedSettings(adapter, requestedSettings);
        if (requestedSettings.modelId != null && supported.modelId == null) {
          throw StateError('ACP_SETTING_UNAVAILABLE: model');
        }
        await _applyAcpSettings(adapter, supported, ignoreUnavailable: true);
      }
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      state = state.copyWith(
        capabilities: _acpCapabilities(adapter),
        // Session setup notifications can temporarily replace draft settings.
        // Preserve the explicit manual-model intent captured for this send.
        runSettings: _confirmedSettings(adapter, requestedSettings),
      );

      final context = session.contextFor(profile.id);
      final pendingHistory = _boundedPendingHistory(
        currentMessages
            .take(currentMessages.length - 2)
            .skip(
              (context.syncedMessageCount - session.messageOffset).clamp(
                0,
                currentMessages.length - 2,
              ),
            )
            .where(
              (m) =>
                  m.content.isNotEmpty &&
                  (m.role == MessageRole.user ||
                      m.role == MessageRole.assistant),
            )
            .map((m) => '${m.role.name}: ${m.content}')
            .toList(),
      );
      if (adapter.isPersistent) {
        // Persist the broker binding before it can accept a remote command.
        await _savePersistentCheckpoint();
        if (!ref.mounted || requestEpoch != _requestEpoch) {
          return;
        }
      }
      adapter.setPersistentTurn(runtimeTurnId);
      await adapter.sendPrompt(
        pendingHistory.isEmpty || text.trimLeft().startsWith('/')
            ? text
            : '[Prior conversation context; text only, do not re-execute previous actions]\n$pendingHistory\n[End prior context]\n\n$text',
        attachments: attachments,
      );
      await Future.wait(resourceWrites);
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      flush();
      _flushStream = null;
      _checkpointTimer?.cancel();
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      final latest = state.activeSession;
      if (latest != null &&
          latest.id == session.id &&
          state.lastErrorCode == null &&
          state.authChallenge == null) {
        final updated = latest.copyWith(
          agentContexts: {
            ...latest.agentContexts,
            profile.id: latest
                .contextFor(profile.id)
                .copyWith(
                  remoteSessionId: adapter.sessionId,
                  persistentRuntimeKey: adapter.persistentRuntimeKey,
                  runtimeCursor: adapter.runtimeCursor,
                  syncedMessageCount:
                      pendingHistory.isNotEmpty &&
                          text.trimLeft().startsWith('/')
                      ? context.syncedMessageCount
                      : latest.messageOffset + latest.messages.length,
                ),
          },
        );
        _updateSessionInState(updated);
        await ref.read(chatRepositoryProvider).saveSession(updated);
        state = state.copyWith(attachments: const [], draftText: '');
        _drafts.remove(sourceDraftKey);
        unawaited(
          ref.read(localStorageServiceProvider).clearChatDraft(sourceDraftKey),
        );
        _rememberDraft();
      } else if (latest != null) {
        await ref.read(chatRepositoryProvider).saveSession(latest);
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
      if (!ref.mounted || requestEpoch != _requestEpoch) {
        return;
      }
      _flushStream?.call();
      _streamTimer?.cancel();
      _checkpointTimer?.cancel();
      _flushStream = null;
      if (state.authChallenge != null) {
        state = state.copyWith(
          isGenerating: false,
          lastErrorCode: authRequiredCode,
        );
        final pending = state.activeSession;
        if (pending != null) {
          await ref.read(chatRepositoryProvider).saveSession(pending);
        }
        return;
      }
      final failureCode = LogSanitizer.sanitize(error.toString());
      _updateAssistantMessage(
        updatedSession,
        assistantMsg.copyWith(
          status: ChatTurnStatus.failed,
          failureCode: failureCode,
        ),
      );
      state = state.copyWith(
        lastErrorCode: failureCode,
        diagnostics: adapter?.diagnostics,
      );
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

  SessionConfigSelectOptionValue? _category(
    ACPClientAdapter adapter,
    String category,
  ) => adapter.configOptions
      .whereType<SessionConfigSelectOptionValue>()
      .where((entry) => entry.category?.toJson() == category)
      .firstOrNull;

  List<ChatSettingOption> _choices(SessionConfigSelectOptionValue? option) {
    if (option == null) return const [];
    return [
      for (final entry in option.options.toJson())
        if (entry is Map && entry['value'] is String)
          ChatSettingOption(
            entry['value'] as String,
            entry['name']?.toString() ?? entry['value'].toString(),
          )
        else if (entry is Map && entry['options'] is List)
          for (final child in entry['options'] as List)
            if (child is Map && child['value'] is String)
              ChatSettingOption(
                child['value'] as String,
                child['name']?.toString() ?? child['value'].toString(),
              ),
    ];
  }

  AgentRuntimeCapabilities _acpCapabilities(ACPClientAdapter adapter) {
    final model = _category(adapter, 'model');
    final reasoning = _category(adapter, 'thought_level');
    final mode = _category(adapter, 'mode');
    final dedicated = {model?.id, reasoning?.id, mode?.id};
    return AgentRuntimeCapabilities(
      // Independent CLI catalogs populate the selector. ACP configuration is
      // used to validate an actual change, never to create a discovery session.
      models: _modelCatalog?.models ?? const [],
      reasoningLevels: reasoning == null
          ? _modelCatalog?.reasoningLevels ?? const []
          : _choices(reasoning),
      modes: mode != null
          ? _choices(mode)
          : [
              for (final mode
                  in adapter.modes?.availableModes ?? <SessionMode>[])
                ChatSettingOption(
                  mode.id,
                  mode.name,
                  description: mode.description,
                ),
            ],
      currentModelId: model?.currentValue,
      currentReasoningId: reasoning?.currentValue,
      currentModeId: mode?.currentValue ?? adapter.modes?.currentModeId,
      extraSettings: [
        for (final option in adapter.configOptions)
          if (!dedicated.contains(option.id))
            if (option is SessionConfigSelectOptionValue)
              ChatRuntimeSetting(
                id: option.id,
                label: option.name,
                currentValue: option.currentValue,
                options: _choices(option),
              )
            else if (option is SessionConfigBooleanOption)
              ChatRuntimeSetting(
                id: option.id,
                label: option.name,
                currentValue: option.currentValue,
                isBoolean: true,
              ),
      ],
      supportsStructuredSettings: true,
    );
  }

  ChatRunSettings _confirmedSettings(
    ACPClientAdapter adapter,
    ChatRunSettings requested,
  ) {
    final caps = _acpCapabilities(adapter);
    return ChatRunSettings(
      modelId: caps.currentModelId,
      customModel:
          requested.customModel && caps.currentModelId == requested.modelId,
      reasoningId: caps.currentReasoningId,
      modeId: caps.currentModeId,
      permissionPolicy: requested.permissionPolicy,
      configValues: {
        for (final option in caps.extraSettings) option.id: option.currentValue,
      },
    );
  }

  // Saved preferences may outlive an agent upgrade or a changed model list.
  // Filter optional preferences; send validates an explicit stale model first.
  static bool _validCustomModel(String? id) =>
      id != null &&
      id.isNotEmpty &&
      id.length <= 256 &&
      !RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(id);

  ChatRunSettings _supportedSettings(
    ACPClientAdapter adapter,
    ChatRunSettings saved,
  ) {
    final caps = _acpCapabilities(adapter);
    bool has(List<ChatSettingOption> options, String? id) =>
        id != null && options.any((option) => option.id == id);
    return ChatRunSettings(
      // Session options may validate a saved value, but never populate the
      // model selector. An independent catalog takes precedence when present.
      modelId:
          (saved.customModel && _validCustomModel(saved.modelId)) ||
              has(
                _modelCatalog?.models ?? _choices(_category(adapter, 'model')),
                saved.modelId,
              )
          ? saved.modelId
          : null,
      customModel: saved.customModel,
      reasoningId: has(caps.reasoningLevels, saved.reasoningId)
          ? saved.reasoningId
          : null,
      modeId: has(caps.modes, saved.modeId) ? saved.modeId : null,
      permissionPolicy: saved.permissionPolicy,
      configValues: {
        for (final entry in saved.configValues.entries)
          if (caps.extraSettings.any(
            (setting) =>
                setting.id == entry.key &&
                (setting.isBoolean
                    ? entry.value is bool
                    : entry.value is String &&
                          has(setting.options, entry.value as String)),
          ))
            entry.key: entry.value,
      },
    );
  }

  Future<void> _applyAcpSettings(
    ACPClientAdapter adapter,
    ChatRunSettings settings, {
    bool ignoreUnavailable = false,
  }) async {
    Future<void> setValue(
      String id,
      Object value, {
      bool allowCustomModel = false,
    }) async {
      final option = adapter.configOptions
          .where((entry) => entry.id == id)
          .firstOrNull;
      if (option is SessionConfigSelectOptionValue &&
          value is String &&
          (_choices(option).any((entry) => entry.id == value) ||
              (allowCustomModel &&
                  option.category?.toJson() == 'model' &&
                  _validCustomModel(value)))) {
        if (option.currentValue == value) {
          return;
        }
        await adapter.setConfigOption(
          SetValueIdConfigOption(
            sessionId: adapter.sessionId!,
            configId: id,
            value: value,
          ),
        );
        if (allowCustomModel &&
            _category(adapter, 'model')?.currentValue != value) {
          throw StateError('ACP_CUSTOM_MODEL_NOT_CONFIRMED');
        }
      } else if (option is SessionConfigBooleanOption && value is bool) {
        if (option.currentValue == value) {
          return;
        }
        await adapter.setConfigOption(
          SetBooleanConfigOption(
            sessionId: adapter.sessionId!,
            configId: id,
            value: value,
          ),
        );
      } else {
        if (option is SessionConfigSelectOptionValue &&
            option.category?.toJson() == 'model') {
          throw StateError('ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER');
        }
        if (ignoreUnavailable) {
          return;
        }
        throw StateError('ACP_SETTING_UNAVAILABLE: $id');
      }
    }

    Future<void> setCategory(String category, String? value) async {
      if (value == null) {
        return;
      }
      final option = _category(adapter, category);
      if (option == null) {
        if (category == 'model' && settings.customModel) {
          throw StateError('ACP_SETTING_UNAVAILABLE: model');
        }
        if (ignoreUnavailable) {
          return;
        }
        throw StateError('ACP_SETTING_UNAVAILABLE: $category');
      }
      await setValue(
        option.id,
        value,
        allowCustomModel: category == 'model' && settings.customModel,
      );
    }

    final changingModel =
        settings.modelId != null &&
        settings.modelId != _category(adapter, 'model')?.currentValue;
    await setCategory('model', settings.modelId);
    // A model change can replace the reasoning options. Keep the newly
    // confirmed value rather than sending a stale selector value.
    if (!changingModel ||
        _choices(
          _category(adapter, 'thought_level'),
        ).any((option) => option.id == settings.reasoningId)) {
      await setCategory('thought_level', settings.reasoningId);
    }
    if (settings.modeId != null) {
      if (_category(adapter, 'mode') != null) {
        await setCategory('mode', settings.modeId);
      } else if (adapter.modes?.availableModes.any(
            (m) => m.id == settings.modeId,
          ) ==
          true) {
        if (adapter.modes!.currentModeId != settings.modeId) {
          await adapter.setMode(settings.modeId!);
        }
      } else {
        if (ignoreUnavailable) {
          return;
        }
        throw StateError('ACP_SETTING_UNAVAILABLE: mode');
      }
    }
    for (final entry in settings.configValues.entries) {
      if (changingModel) {
        final fresh = _supportedSettings(adapter, settings).configValues;
        if (!fresh.containsKey(entry.key)) continue;
      }
      await setValue(entry.key, entry.value);
    }
  }

  void _updateAssistantMessage(ChatSession session, ChatMessage msg) {
    final latest = state.sessions
        .where((entry) => entry.id == session.id)
        .firstOrNull;
    if (latest == null) {
      return;
    }
    final index = latest.messages.indexWhere((entry) => entry.id == msg.id);
    if (index < 0 || identical(latest.messages[index], msg)) {
      return;
    }
    final msgs = latest.messages.toList();
    msgs[index] = msg;
    final updated = latest.copyWith(messages: msgs, updatedAt: DateTime.now());
    _updateSessionInState(updated);
  }

  void _updateSessionInState(ChatSession updated) {
    final count = updated.messageOffset + updated.messages.length;
    if (count > updated.totalMessageCount) {
      updated = updated.copyWith(totalMessageCount: count);
    }
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

  void respondPermission(Object? selection) {
    final options =
        state.pendingPermission?.options ?? const <ChatPermissionOption>[];
    final String? id = selection is bool
        ? options
              .where(
                (option) =>
                    option.kind == (selection ? 'allow_once' : 'reject_once'),
              )
              .firstOrNull
              ?.id
        : selection is String
        ? selection
        : null;
    if (id != null && !options.any((option) => option.id == id)) {
      return;
    }
    final run = _backgroundRuns[_serverTargetKey];
    if (run != null &&
        run.session.id == state.activeSessionId &&
        run.profile.id == state.activeAgentProfile?.id) {
      run.respondPermission(id);
      return;
    }
    if (state.permissionCompleter != null &&
        !state.permissionCompleter!.isCompleted) {
      state.permissionCompleter!.complete(id);
    }
    if (_permissionQueue.isEmpty) {
      state = state.copyWith(clearPermission: true);
    } else {
      final next = _permissionQueue.removeAt(0);
      state = state.copyWith(
        pendingPermission: next.request,
        permissionCompleter: next.responseCompleter,
      );
    }
  }

  bool respondToPermission(
    Object? selection, {
    required Completer<String?> expectedCompleter,
    required String expectedServerKey,
  }) {
    if (_serverTargetKey != expectedServerKey ||
        !identical(state.permissionCompleter, expectedCompleter) ||
        expectedCompleter.isCompleted) {
      return false;
    }
    respondPermission(selection);
    return true;
  }

  void _cancelPermissions() {
    final permission = state.permissionCompleter;
    if (permission != null && !permission.isCompleted) {
      permission.complete(null);
    }
    for (final queued in _permissionQueue) {
      if (!queued.responseCompleter.isCompleted) {
        queued.responseCompleter.complete(null);
      }
    }
    _permissionQueue.clear();
  }

  /// Discover advertised methods only; never create/load a session or send text.
  Future<void> requestAuthenticationForAgent(
    String serverId,
    String agentId,
  ) async {
    if (_activeServerId != serverId ||
        state.isGenerating ||
        state.isAuthenticating) {
      return;
    }
    try {
      await switchAgent(agentId);
      if (!ref.mounted ||
          _activeServerId != serverId ||
          state.activeAgentProfile?.id != agentId) {
        return;
      }
      await requestAuthentication();
    } catch (error) {
      if (ref.mounted &&
          _activeServerId == serverId &&
          state.activeAgentProfile?.id == agentId) {
        state = state.copyWith(
          authError: LogSanitizer.sanitize(error.toString()),
        );
      }
    }
  }

  Future<void> requestAuthentication() async {
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    if (profile == null ||
        serverId == null ||
        !usesAntigravityAcp(profile) ||
        state.isGenerating ||
        state.isAuthenticating ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return;
    }
    final client = ref.read(sshClientManagerProvider).getClient(serverId);
    if (client == null || !ref.read(serverConnectionProvider).isConnected) {
      state = state.copyWith(authError: disconnectedCode);
      return;
    }
    final epoch = _requestEpoch;
    _closeAuthLoopback();
    state = state.copyWith(isLoadingSettings: true, clearAuthError: true);
    try {
      final adapter = await _adapterFor(profile, client);
      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen(
        (event) => _handleIdleRuntimeEvent(event, adapter),
      );
      await adapter.initializeOnly();
      if (!ref.mounted ||
          epoch != _requestEpoch ||
          !identical(adapter, _currentAdapter)) {
        return;
      }
      state = state.copyWith(
        authChallenge: AuthChallenge(
          serverId: serverId,
          agentId: profile.id,
          methods: adapter.authMethods,
        ),
        isAuthenticating: false,
        clearAuthRequest: true,
      );
    } catch (error) {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          authError: LogSanitizer.sanitize(error.toString()),
        );
      }
    } finally {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingSettings: false);
      }
    }
  }

  /// Official AgY authenticates immediately on explicit selection; other agents
  /// retain their established deferred flow. Null cancels without sending text.
  Future<void> respondAuth(String? methodId) async {
    final profile = state.activeAgentProfile;
    if (methodId != null &&
        profile != null &&
        isAgentUpdateLocked(ref, profile)) {
      state = state.copyWith(authError: 'AGENT_UPDATE_IN_PROGRESS');
      return;
    }
    final challenge = state.authChallenge;
    if (profile != null && usesAntigravityAcp(profile) && challenge != null) {
      if (challenge.serverId != _activeServerId ||
          challenge.agentId != profile.id) {
        return;
      }
      if (methodId == null) {
        if (state.isAuthenticating) {
          await _stopGeneration(cancelRemote: false);
        } else {
          _closeAuthLoopback();
          state = state.copyWith(clearAuthChallenge: true);
        }
        _retryAfterAuth = false;
        return;
      }
      if (state.isAuthenticating) {
        return;
      }
      if (!challenge.methods.any((method) => method.id == methodId)) {
        state = state.copyWith(authError: 'ACP_AUTH_METHOD_UNAVAILABLE');
        return;
      }
      final client = ref
          .read(sshClientManagerProvider)
          .getClient(profile.serverId);
      if (client == null || !ref.read(serverConnectionProvider).isConnected) {
        state = state.copyWith(authError: disconnectedCode);
        return;
      }
      final epoch = _requestEpoch;
      final adapter = _currentAdapter;
      if (adapter == null) {
        state = state.copyWith(authError: 'ACP_AUTH_CONNECTION_EXPIRED');
        return;
      }
      bool current() =>
          ref.mounted &&
          epoch == _requestEpoch &&
          identical(adapter, _currentAdapter) &&
          challenge.serverId == _activeServerId &&
          state.activeAgentProfile?.id == profile.id;
      state = state.copyWith(
        isAuthenticating: true,
        authenticationConfirmed: false,
        clearAuthError: true,
        clearAuthRequest: true,
        selectedAuthMethods: {
          ...state.selectedAuthMethods,
          '${profile.serverId}::${profile.id}': methodId,
        },
      );
      try {
        await adapter.authenticateNow(methodId);
        if (current()) {
          _closeAuthLoopback();
          state = state.copyWith(
            clearAuthChallenge: true,
            authenticationConfirmed: true,
            clearError: state.lastErrorCode == authRequiredCode,
          );
        }
      } catch (error) {
        if (current()) {
          _closeAuthLoopback();
          state = state.copyWith(
            isAuthenticating: false,
            clearAuthRequest: true,
            authError: LogSanitizer.sanitize(error.toString()),
          );
        }
      }
      return;
    }
    if (methodId == null) _retryAfterAuth = false;
    final completer = state.authCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(methodId);
    }

    final agentId = challenge?.agentId;
    final selections = Map<String, String>.from(state.selectedAuthMethods);
    if (methodId != null && agentId != null) {
      selections['${challenge?.serverId ?? _activeServerId}::$agentId'] =
          methodId;
    }

    state = state.copyWith(
      clearAuthChallenge: true,
      selectedAuthMethods: selections,
      clearError: false,
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
