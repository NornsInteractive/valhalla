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
import '../../infrastructure/acp/acp_attachment_store.dart';
import '../../infrastructure/acp/acp_workspace_files.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../../infrastructure/cli/codex_native_client.dart';
import '../../infrastructure/cli/codex_account_models.dart';
import '../../infrastructure/cli/codex_model_authorization.dart';
import '../utils/shell_quote.dart';
import '../logging/sanitizer.dart';
import 'agent_registry_provider.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'app_visibility_provider.dart';

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
    final session = await sshClient.execute(agentAcpLaunchCommand(profile));
    return AcpSshTransport(session);
  };
});

final acpAttachmentStoreProvider = Provider((ref) => AcpAttachmentStore());

/// Independent CLI API discovery; never infer a catalog from session config.
/// Null means this agent has no independently supported query implementation.
typedef AgentModelQuery =
    Future<AgentRuntimeCapabilities?> Function(
      AgentProfile profile,
      SSHClient sshClient,
    );

final agentModelQueryProvider = Provider<AgentModelQuery>((ref) {
  return (profile, ssh) async {
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

class AiChatState {
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
    if (!ref.mounted || key != _draftKey) return;
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
      _currentAdapter != null || _isPreparingPrompt ? 1 : 0;
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
      if (!ref.mounted || epoch != _requestEpoch) return;
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
    if (profile == null || client == null) return false;
    final epoch = _requestEpoch;
    try {
      final adapter = await _adapterFor(profile, client);
      _acpSub ??= adapter.eventStream.listen(
        (event) => _handleControlEvent(event, adapter),
      );
      await adapter.initializeOnly();
      if (!ref.mounted || epoch != _requestEpoch) return false;
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
      if (!ref.mounted || epoch != _requestEpoch) return false;
      _composerSkills = commands;
      state = state.copyWith(
        commands: _combinedCommands(adapter.composerCommands),
        clearError:
            state.lastErrorCode?.startsWith('AGENT_COMPOSER_QUERY_FAILED:') ==
            true,
      );
      return true;
    } catch (error) {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode:
              'AGENT_COMPOSER_QUERY_FAILED: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
      return false;
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
  Future<ACPClientAdapter>? _openingAdapter;
  String? _openingAdapterKey;
  int _requestEpoch = 0;
  Future<void>? _recovering;
  Future<void>? _checkpointing;
  bool _isPreparingPrompt = false;
  Timer? _streamTimer;
  Timer? _checkpointTimer;
  void Function()? _flushStream;
  String? _draftWorkingDirectory;
  final List<ACPPermissionRequestEvent> _permissionQueue = [];
  bool _retryAfterAuth = false;
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

  void _rememberDraft() {
    _drafts[_draftKey] = (
      text: state.draftText,
      attachments: state.attachments,
      directory: _draftWorkingDirectory,
    );
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
    if (state.isGenerating) return;
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

  /// 构造一个 ACP adapter，并接上会话 id 的读取与持久化。
  Future<ACPClientAdapter> _createAdapter(
    AgentProfile profile,
    SSHClient sshClient,
  ) async {
    final localSession = state.activeSession;
    final serverId = _activeServerId;
    final epoch = _requestEpoch;
    final launchKey = _launchKey(profile);
    final transport = await ref.read(acpTransportFactoryProvider)(
      profile,
      sshClient,
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
    final storedSessionId = localSession
        ?.contextFor(profile.id)
        .remoteSessionId;

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
      if (current == null) return;
      final context = current.contextFor(profile.id);
      final updated = current.copyWith(
        workingDirectory: workingDirectory,
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

  Future<ACPClientAdapter> _adapterFor(AgentProfile profile, SSHClient client) {
    final key =
        '$_requestEpoch|$_activeServerId|${state.activeSessionId}|${profile.id}|${_launchKey(profile)}';
    if (_openingAdapterKey == key && _openingAdapter != null) {
      return _openingAdapter!;
    }
    final operation = _openAdapterFor(profile, client);
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
  ) async {
    final serverId = _activeServerId;
    final sessionId = state.activeSessionId;
    final key = _launchKey(profile);
    if (_currentAdapter != null &&
        !_currentAdapter!.isDisposed &&
        _currentAdapterAgentId == profile.id &&
        _currentAdapterSessionId == sessionId &&
        _currentAdapterServerId == serverId &&
        _currentAdapterLaunchKey == key) {
      return _currentAdapter!;
    }
    _currentAdapter?.dispose();
    _currentAdapter = null;
    final epoch = _requestEpoch;
    final adapter = await _createAdapter(profile, client);
    if (!ref.mounted ||
        epoch != _requestEpoch ||
        _activeServerId != serverId ||
        state.activeSessionId != sessionId ||
        state.activeAgentProfile?.id != profile.id) {
      adapter.dispose();
      throw StateError('ACP_TARGET_CHANGED');
    }
    _currentAdapter = adapter;
    _currentAdapterAgentId = profile.id;
    _currentAdapterSessionId = sessionId;
    _currentAdapterServerId = serverId;
    _currentAdapterLaunchKey = key;
    return adapter;
  }

  void _handleControlEvent(ACPEvent event, ACPClientAdapter adapter) {
    if (!ref.mounted || !identical(adapter, _currentAdapter)) return;
    if (event is ACPSettingsChangedEvent) {
      state = state.copyWith(
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
        runSettings: _confirmedSettings(adapter, state.runSettings),
      );
    } else if (event is ACPAccountEvent) {
      state = state.copyWith(account: event.account);
    } else if (event is ACPCommandsChangedEvent) {
      state = state.copyWith(commands: _combinedCommands(event.commands));
    } else if (event is ACPUsageEvent) {
      state = state.copyWith(usage: event.usage);
    } else if (event is ACPAuthRequiredEvent) {
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
      );
    }
  }

  Future<bool> prepareRunSettings({bool refresh = false}) async {
    if (state.isGenerating ||
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
    final epoch = _requestEpoch;
    state = state.copyWith(
      isLoadingSettings: true,
      settingsStale: true,
      clearError: true,
    );
    try {
      final adapter = await _adapterFor(profile, client);
      await _acpSub?.cancel();
      _acpSub = adapter.eventStream.listen(
        (event) => _handleControlEvent(event, adapter),
      );
      final method =
          state.selectedAuthMethods['${profile.serverId}::${profile.id}'];
      if (method != null) await adapter.authenticate(method);
      // Discovery does not restore a thread or recreate the ACP transport.
      // Session setup is deferred to an explicit settings change or first send.
      await adapter.initializeOnly();
      if (!ref.mounted || epoch != _requestEpoch) return false;
      AgentRuntimeCapabilities? catalog;
      String? catalogError;
      try {
        catalog = await ref.read(agentModelQueryProvider)(profile, client);
        if (catalog == null) catalogError = 'AGENT_MODEL_QUERY_UNSUPPORTED';
      } catch (error) {
        catalogError = LogSanitizer.sanitize(error.toString());
        if (ref.mounted &&
            epoch == _requestEpoch &&
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
      if (!ref.mounted || epoch != _requestEpoch) return false;
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
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          settingsStale: true,
          lastErrorCode: state.authChallenge != null
              ? authRequiredCode
              : error.toString(),
        );
      }
      return false;
    } finally {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingSettings: false);
      }
    }
  }

  @override
  AiChatState build() {
    ref.onDispose(() {
      cancelModelAuthorization();
      cancelWorkspaceBrowse();
      _requestEpoch++;
      _streamTimer?.cancel();
      _checkpointTimer?.cancel();
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
        unawaited(recoverConnection());
      }
    });
    ref.listen(appVisibilityProvider, (_, foreground) {
      _currentAdapter?.setInBackground(!foreground);
      if (foreground && state.recoveryStatus != SessionRecoveryStatus.idle) {
        unawaited(recoverConnection());
      }
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

  Future<void> selectSession(String sessionId) async {
    if (state.isGenerating) return;
    if (!state.sessions.any((s) => s.id == sessionId)) return;
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
  }

  /// 按稳定 agentId 切换 Agent；目标不存在或未就绪时拒绝切换。
  void switchAgent(String agentId) {
    if (state.isGenerating) return;
    final target = state.readyAgents.where((a) => a.id == agentId).firstOrNull;
    if (target == null) {
      state = state.copyWith(lastErrorCode: notReadyCode);
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
    _refreshVisibleSessions();
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
      if (ref.mounted &&
          epoch == _historyEpoch &&
          (state.recoveryStatus != SessionRecoveryStatus.idle ||
              state.activeSession?.messages.any(
                    (m) => m.status == ChatTurnStatus.interrupted,
                  ) ==
                  true)) {
        unawaited(recoverConnection());
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
    if (!state.hasMoreSessions || state.isLoadingSessions) return;
    await _refreshVisibleSessions(append: true);
  }

  Future<AcpRemoteSessionPage> listRemoteSessions({String? cursor}) async {
    final profile = state.activeAgentProfile;
    final serverId = _activeServerId;
    final client = serverId == null
        ? null
        : ref.read(sshClientManagerProvider).getClient(serverId);
    if (profile == null || client == null) throw StateError(disconnectedCode);
    final key = _launchKey(profile);
    final transport = await ref.read(acpTransportFactoryProvider)(
      profile,
      client,
    );
    final adapter = ACPClientAdapter(
      profile: profile,
      transport: transport,
      workingDirectory: '/',
    );
    try {
      final page = await adapter.listRemoteSessions(
        ListSessionsRequest(cursor: cursor),
      );
      if (!ref.mounted ||
          serverId != _activeServerId ||
          profile.id != state.activeAgentProfile?.id ||
          key != _launchKey(state.activeAgentProfile!)) {
        throw StateError('ACP_TARGET_CHANGED');
      }
      return AcpRemoteSessionPage(
        page.sessions
            .map(
              (s) => AcpRemoteSession(
                id: s.sessionId,
                title: s.title ?? s.sessionId,
                workingDirectory: s.cwd,
                serverId: serverId!,
                agentId: profile.id,
                launchKey: key,
              ),
            )
            .toList(),
        page.nextCursor,
      );
    } finally {
      adapter.dispose();
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
      if (!ref.mounted || epoch != _requestEpoch) return;
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
        var plan = <PlanStep>[];
        String? messageId;
        var resourceBlocks = <ContentBlock>[];
        var batchResources = <String, List<ContentBlock>>{};
        void writeBatch() {
          if (batch.isEmpty) return;
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
                if (!ref.mounted || epoch != _requestEpoch) return;
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
          if (role == null) return;
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
              planSteps: plan,
              createdAt: now,
            ),
          );
          sequence++;
          text = StringBuffer();
          thinking = StringBuffer();
          tools = [];
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
            text.write(event.chunk);
          } else if (event is ACPContentChunkEvent) {
            useRole(MessageRole.assistant, event.messageId);
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
        if (!ref.mounted || epoch != _requestEpoch) return;
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
        if (!ref.mounted || epoch != _requestEpoch) return;
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
      if (!ref.mounted || epoch != _requestEpoch || local == null) return;
      if (recoverExisting) {
        final visible = state.activeSession;
        if (visible == null || visible.id != local.id) return;
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
      if (!recoverExisting && ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: 'ACP_HISTORY_IMPORT_FAILED: $error',
        );
      }
      rethrow;
    } finally {
      await subscription?.cancel();
      adapter?.dispose();
      if (!recoverExisting && ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingMessages: false);
      }
    }
  }

  Future<void> _loadSelectedMessages({bool older = false}) async {
    final active = state.activeSession;
    if (active == null || state.isLoadingMessages || state.isGenerating) return;
    if (!older && active.messages.isNotEmpty) return;
    if (older && active.messageOffset == 0) return;
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
        return;
      }
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
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isLoadingMessages: false);
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
    if (title.trim().isEmpty || !state.sessions.any((s) => s.id == id)) return;
    final epoch = _requestEpoch;
    await ref.read(chatRepositoryProvider).renameSession(id, title.trim());
    if (!ref.mounted || epoch != _requestEpoch) return;
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
    if (settings.customModel && !_validCustomModel(settings.modelId)) {
      throw StateError('ACP_CUSTOM_MODEL_INVALID');
    }
    if (state.isGenerating ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return;
    }
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
    if (serverId == null || agentId == null) return;
    final epoch = _requestEpoch;
    state = state.copyWith(isApplyingSettings: true, clearError: true);
    try {
      final adapter = _currentAdapter;
      if (state.activeSession == null) {
        // Draft preferences are applied only after session/new at first send.
        state = state.copyWith(runSettings: settings);
        await ref
            .read(localStorageServiceProvider)
            .saveChatRunDefault(serverId, agentId, settings);
        return;
      }
      if (adapter == null) {
        throw StateError('ACP_SETTINGS_NOT_READY');
      }
      // Restoring a session is necessary only to apply the user's change,
      // never to discover the list offered in the model selector.
      await adapter.prepareSession();
      if (!ref.mounted || epoch != _requestEpoch) return;
      await _applyAcpSettings(adapter, settings);
      if (!ref.mounted || epoch != _requestEpoch) return;
      settings = _confirmedSettings(adapter, settings);
      await ref
          .read(localStorageServiceProvider)
          .saveChatRunDefault(serverId, agentId, settings);
      if (!ref.mounted || epoch != _requestEpoch) return;
      final session = state.activeSession;
      if (session != null) {
        final updated = session.copyWith(
          agentRunSettings: {...session.agentRunSettings, agentId: settings},
        );
        _updateSessionInState(updated);
        await ref.read(chatRepositoryProvider).saveSession(updated);
      }
      if (!ref.mounted || epoch != _requestEpoch) return;
      state = state.copyWith(runSettings: settings);
    } catch (error) {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(
          lastErrorCode: LogSanitizer.sanitize(error.toString()),
          diagnostics: _currentAdapter?.diagnostics,
        );
      }
      rethrow;
    } finally {
      if (ref.mounted && epoch == _requestEpoch) {
        state = state.copyWith(isApplyingSettings: false);
      }
    }
  }

  Future<void> setShareAgentSessions(bool enabled) async {
    final serverId = _activeServerId;
    if (serverId == null || state.isGenerating) return;
    await ref
        .read(localStorageServiceProvider)
        .setShareAgentSessions(serverId, enabled);
    if (!ref.mounted || _activeServerId != serverId) return;
    state = state.copyWith(shareAgentSessions: enabled);
    await _refreshVisibleSessions();
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

  Future<void> stopGeneration() => _stopGeneration();

  Future<void> _stopGeneration({bool cancelRemote = true}) async {
    _flushStream?.call();
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
    var current = state.activeSession;
    if (current != null) {
      current = current.copyWith(
        messages: current.messages
            .map(
              (message) => message.status == ChatTurnStatus.streaming
                  ? message.copyWith(status: ChatTurnStatus.interrupted)
                  : message,
            )
            .toList(),
      );
      _updateSessionInState(current);
    }
    final repo = ref.read(chatRepositoryProvider);
    state = state.copyWith(
      isGenerating: false,
      isLoadingSettings: false,
      isApplyingSettings: false,
      clearPermission: true,
      clearAuthChallenge: true,
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
    _flushStream?.call();
    _rememberDraft();
    final current = state.activeSession;
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
      await storage.saveChatDraft(key, {
        'text': text,
        'directory': directory,
        'attachments': saved.map((a) => a.toJson()).toList(),
      });
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(lastErrorCode: 'CHAT_SAVE_FAILED: $error');
      }
    }
  }

  Future<void> _connectionLost() async {
    _recovering = null;
    cancelWorkspaceBrowse();
    state = state.copyWith(
      recoveryStatus: SessionRecoveryStatus.reconnecting,
      settingsStale: true,
    );
    try {
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

  Future<void> _recoverConnection() async {
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
    final remoteId = session.contextFor(profile.id).remoteSessionId;
    if (remoteId == null) {
      state = state.copyWith(recoveryStatus: SessionRecoveryStatus.idle);
      return;
    }
    if (state.recoveryStatus == SessionRecoveryStatus.idle &&
        !session.messages.any((m) => m.status == ChatTurnStatus.interrupted)) {
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
    state = state.copyWith(recoveryStatus: SessionRecoveryStatus.syncing);
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
      if (!current()) return;
      final client = ref.read(sshClientManagerProvider).getClient(serverId!);
      if (client == null) throw StateError(disconnectedCode);
      final adapter = await _adapterFor(profile, client);
      if (!current()) return;
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
      if (!current()) return;
      final latest = state.activeSession!;
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
        if (!current()) return;
      }
      state = state.copyWith(
        acpSessionRestored: adapter.restoredExistingSession,
        recoveryStatus: incomplete
            ? SessionRecoveryStatus.incomplete
            : SessionRecoveryStatus.idle,
      );
    } catch (error) {
      if (current()) {
        state = state.copyWith(
          recoveryStatus: SessionRecoveryStatus.failed,
          diagnostics: LogSanitizer.sanitize(error.toString()),
        );
      }
    }
  }

  Future<void> createNewSession([String? title]) async {
    if (state.isGenerating) return;
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

  void _resetAdapter() {
    cancelModelAuthorization();
    _modelCatalog = null;
    _modelAccountKey = null;
    _composerSkills = const [];
    _composerQuery = null;
    _openingAdapter = null;
    _openingAdapterKey = null;
    cancelWorkspaceBrowse();
    _cancelPermissions();
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
    _draftWorkingDirectory = null;
    state = state.copyWith(
      recoveryStatus: SessionRecoveryStatus.idle,
      capabilities: const AgentRuntimeCapabilities(),
      clearAccount: true,
      clearSettingsMetadata: true,
      clearModelCatalogError: true,
      settingsStale: true,
      isLoadingSettings: false,
      isApplyingSettings: false,
      clearAuthChallenge: true,
      clearPermission: true,
      clearDraftWorkingDirectory: true,
      commands: const [],
      clearUsage: true,
      diagnostics: '',
      supportsImages: false,
      supportsTextAttachments: false,
      isLoadingMessages: false,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    if (!state.sessions.any((s) => s.id == sessionId)) {
      throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
    }
    if (state.isGenerating && state.activeSessionId == sessionId) return;
    final serverId = _activeServerId;
    final agentId = state.activeAgentProfile?.id;
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
    if (state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing) {
      return;
    }
    if ((text.trim().isEmpty && state.attachments.isEmpty) ||
        state.isLoadingMessages ||
        state.isLoadingSessions ||
        state.isGenerating ||
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
        if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
    if (!ref.mounted || requestEpoch != _requestEpoch) return;
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: displayText,
      attachments: savedAttachments,
      createdAt: DateTime.now(),
    );

    var assistantMsg = retryPending
        ? session.messages.last
        : ChatMessage(
            status: ChatTurnStatus.streaming,
            agentId: profile.id,
            id: _uuid.v4(),
            role: MessageRole.assistant,
            content: '',
            createdAt: DateTime.now(),
          );

    var currentMessages = retryPending
        ? session.messages
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
    state = state.copyWith(isGenerating: true, clearError: true);

    // 复用已有 adapter 与远端 agent 进程。原先每条消息都重建 transport，
    // 等于每次都重开一个远端进程、丢掉 ACP 会话上下文，这正是
    // 「重连/发第二条消息后内容没了」的根因。
    ACPClientAdapter? adapter;
    // 记录这是不是重建出来的 adapter：只有重建才可能发生「上下文丢失」，
    // 复用同一个 adapter 是正常连续对话，不该弹重启告警。
    var adapterWasRebuilt = false;
    try {
      await ref.read(chatRepositoryProvider).saveSession(updatedSession);
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
      final thinking = StringBuffer(assistantMsg.thinking ?? '');
      final resourceWrites = <Future<void>>[];
      final store = ref.read(acpAttachmentStoreProvider);
      void flush() {
        _streamTimer?.cancel();
        _streamTimer = null;
        if (!ref.mounted || requestEpoch != _requestEpoch) return;
        assistantMsg = assistantMsg.copyWith(
          content: content.toString(),
          thinking: thinking.toString(),
        );
        _updateAssistantMessage(updatedSession, assistantMsg);
      }

      _flushStream = flush;
      void beginAssistantMessage(String? id) {
        if (id == null) return;
        final previousId = assistantMsg.remoteMessageId;
        if (previousId != null && previousId != id) {
          assistantMsg = assistantMsg.copyWith(
            status: ChatTurnStatus.completed,
          );
          flush();
          final latest = state.activeSession;
          if (latest == null) return;
          assistantMsg = ChatMessage(
            id: _uuid.v4(),
            agentId: profile.id,
            role: MessageRole.assistant,
            content: '',
            remoteMessageId: id,
            status: ChatTurnStatus.streaming,
            createdAt: DateTime.now(),
          );
          content.clear();
          thinking.clear();
          _updateSessionInState(
            latest.copyWith(messages: [...latest.messages, assistantMsg]),
          );
        } else {
          assistantMsg = assistantMsg.copyWith(remoteMessageId: id);
        }
      }

      _checkpointTimer?.cancel();
      _checkpointTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!ref.mounted || requestEpoch != _requestEpoch) return;
        flush();
        final snapshot = state.activeSession;
        if (snapshot == null || snapshot.messages.isEmpty) return;
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
        _handleControlEvent(event, adapter!);
        if (event is ACPThinkingChunkEvent) {
          beginAssistantMessage(event.messageId);
          thinking.write(event.chunk);
          scheduleFlush();
        } else if (event is ACPContentChunkEvent) {
          beginAssistantMessage(event.messageId);
          content.write(event.chunk);
          scheduleFlush();
        } else if (event is ACPAttachmentEvent &&
            event.role == MessageRole.assistant) {
          beginAssistantMessage(event.messageId);
          final targetMessageId = assistantMsg.id;
          // Attach a rejection handler immediately; asynchronous decode failures
          // must not escape while the protocol is still streaming.
          resourceWrites.add(
            store
                .fromBlock(event.content)
                .then<void>((attachment) {
                  if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
                  if (!ref.mounted || requestEpoch != _requestEpoch) return;
                  state = state.copyWith(
                    lastErrorCode: 'ACP_ATTACHMENT_SAVE_FAILED: $error',
                  );
                }),
          );
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
            status: ChatTurnStatus.interrupted,
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
          state = state.copyWith(isGenerating: false, clearPermission: true);
        } else if (event is ACPErrorEvent) {
          _cancelPermissions();
          assistantMsg = assistantMsg.copyWith(status: ChatTurnStatus.failed);
          content.write('\n\n**Error:** ${event.error}');
          flush();
          state = state.copyWith(
            isGenerating: false,
            clearPermission: true,
            lastErrorCode: event.error,
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
        if (!ref.mounted || requestEpoch != _requestEpoch) return;
        _modelCatalog = catalog;
      }
      await adapter.prepareSession();
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
      if (isNewRemoteSession && !adapter.restoredExistingSession) {
        final supported = _supportedSettings(adapter, requestedSettings);
        if (requestedSettings.modelId != null && supported.modelId == null) {
          throw StateError('ACP_SETTING_UNAVAILABLE: model');
        }
        await _applyAcpSettings(adapter, supported, ignoreUnavailable: true);
      }
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
      await adapter.sendPrompt(
        pendingHistory.isEmpty || text.trimLeft().startsWith('/')
            ? text
            : '[Prior conversation context; text only, do not re-execute previous actions]\n$pendingHistory\n[End prior context]\n\n$text',
        attachments: attachments,
      );
      await Future.wait(resourceWrites);
      flush();
      _flushStream = null;
      _checkpointTimer?.cancel();
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
              syncedMessageCount:
                  pendingHistory.isNotEmpty && text.trimLeft().startsWith('/')
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
      if (!ref.mounted || requestEpoch != _requestEpoch) return;
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
        if (option.currentValue == value) return;
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
        if (option.currentValue == value) return;
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
        if (ignoreUnavailable) return;
        throw StateError('ACP_SETTING_UNAVAILABLE: $id');
      }
    }

    Future<void> setCategory(String category, String? value) async {
      if (value == null) return;
      final option = _category(adapter, category);
      if (option == null) {
        if (category == 'model' && settings.customModel) {
          throw StateError('ACP_SETTING_UNAVAILABLE: model');
        }
        if (ignoreUnavailable) return;
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
        if (ignoreUnavailable) return;
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
    if (latest == null) return;
    final msgs = latest.messages
        .map((entry) => entry.id == msg.id ? msg : entry)
        .toList();
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
    if (id != null && !options.any((option) => option.id == id)) return;
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

  /// 回传用户选定的认证方式。
  ///
  /// [methodId] 为 null 表示用户放弃，仅清除引导状态，不触发认证。
  /// 选择结果记入 [AiChatState.selectedAuthMethods]，下一次发送消息时注入
  /// 新建的 adapter，在建会话前完成 `authenticate`。
  Future<void> respondAuth(String? methodId) async {
    if (methodId == null) _retryAfterAuth = false;
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
