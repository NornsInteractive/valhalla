import 'dart:async';
import 'package:acpd/acpd.dart' hide Terminal;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/session_recovery_status.dart';
import '../../data/models/native_cli_session.dart';
import '../../data/models/chat_run_settings.dart';
import '../../data/models/chat_launch_preference.dart';
import '../../data/models/agent_composer_item.dart';
import '../../infrastructure/cli/claude_native_history.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../../infrastructure/cli/codex_native_client.dart';
import '../../infrastructure/cli/opencode_native_client.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import '../logging/sanitizer.dart';
import '../security/agent_command_validator.dart';
import '../utils/shell_quote.dart';
import 'agent_registry_provider.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'settings_provider.dart';
import 'storage_providers.dart';
import 'security_settings_provider.dart';
import 'app_visibility_provider.dart';
export '../../data/models/native_cli_session.dart';
export '../../data/models/session_recovery_status.dart';

class CliChatState {
  final SessionRecoveryStatus recoveryStatus;
  final ChatRunSettings runSettings;
  final AgentRuntimeCapabilities capabilities;
  final String? serverId;
  final List<AgentProfile> agents;
  final AgentProfile? activeAgent;
  final List<NativeCliSession> sessions;
  final NativeCliSession? activeSession;
  final List<NativeCliMessage> messages;
  final List<NativeCliApproval> approvals;
  final bool hasOlderMessages;
  final bool isLoadingOlderMessages;
  final Terminal? terminal;
  final bool isLoading;
  final bool isSending;
  final bool canDelete;
  final String? errorCode;
  final String? errorDetail;
  final String? cursor;
  final String? cwd;
  final String? draftCwd;
  final AgentComposerCatalog composerCatalog;
  const CliChatState({
    this.recoveryStatus = SessionRecoveryStatus.idle,
    this.runSettings = const ChatRunSettings(),
    this.capabilities = const AgentRuntimeCapabilities(),
    this.serverId,
    this.agents = const [],
    this.activeAgent,
    this.sessions = const [],
    this.activeSession,
    this.messages = const [],
    this.approvals = const [],
    this.hasOlderMessages = false,
    this.isLoadingOlderMessages = false,
    this.terminal,
    this.isLoading = false,
    this.isSending = false,
    this.canDelete = false,
    this.errorCode,
    this.errorDetail,
    this.cursor,
    this.cwd,
    this.draftCwd,
    this.composerCatalog = const AgentComposerCatalog(),
  });
  NativeCliKind get kind => nativeCliKind(activeAgent?.cliCommand ?? '');
  bool get structuredSend =>
      kind == NativeCliKind.codex || kind == NativeCliKind.openCode;
  bool get hasHistory => kind != NativeCliKind.terminal && activeAgent != null;
  CliChatState copyWith({
    SessionRecoveryStatus? recoveryStatus,
    ChatRunSettings? runSettings,
    AgentRuntimeCapabilities? capabilities,
    List<AgentProfile>? agents,
    AgentProfile? activeAgent,
    List<NativeCliSession>? sessions,
    NativeCliSession? activeSession,
    bool clearSession = false,
    List<NativeCliMessage>? messages,
    List<NativeCliApproval>? approvals,
    bool? hasOlderMessages,
    bool? isLoadingOlderMessages,
    Terminal? terminal,
    bool clearTerminal = false,
    bool? isLoading,
    bool? isSending,
    bool? canDelete,
    String? errorCode,
    String? errorDetail,
    String? cursor,
    bool clearCursor = false,
    String? cwd,
    String? draftCwd,
    bool clearDraftCwd = false,
    AgentComposerCatalog? composerCatalog,
  }) => CliChatState(
    recoveryStatus: recoveryStatus ?? this.recoveryStatus,
    runSettings: runSettings ?? this.runSettings,
    capabilities: capabilities ?? this.capabilities,
    serverId: serverId,
    agents: agents ?? this.agents,
    activeAgent: activeAgent ?? this.activeAgent,
    sessions: sessions ?? this.sessions,
    activeSession: clearSession ? null : activeSession ?? this.activeSession,
    messages: messages ?? this.messages,
    approvals: approvals ?? this.approvals,
    hasOlderMessages: hasOlderMessages ?? this.hasOlderMessages,
    isLoadingOlderMessages:
        isLoadingOlderMessages ?? this.isLoadingOlderMessages,
    terminal: clearTerminal ? null : terminal ?? this.terminal,
    isLoading: isLoading ?? this.isLoading,
    isSending: isSending ?? this.isSending,
    canDelete: canDelete ?? this.canDelete,
    errorCode: errorCode,
    errorDetail: errorDetail,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    cwd: cwd ?? this.cwd,
    draftCwd: clearDraftCwd ? null : draftCwd ?? this.draftCwd,
    composerCatalog: composerCatalog ?? this.composerCatalog,
  );
}

final cliChatProvider = NotifierProvider<CliChatNotifier, CliChatState>(
  CliChatNotifier.new,
);

class CliChatNotifier extends Notifier<CliChatState> {
  int get activeConnectionCount =>
      (_codex?.connection.isClosed == false ? 1 : 0) +
      (_openCode?.isClosed == false ? 1 : 0) +
      (_bridge?.state == TerminalConnectionState.connected ? 1 : 0);
  int _epoch = 0;
  CodexNativeClient? _codex;
  OpenCodeNativeClient? _openCode;
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<ConnectionFailure>? _errors;
  TerminalSessionBridge? _bridge;
  final Map<String, Completer<Object?>> _replies = {};
  int _approvalSequence = 0;
  final Map<String, CliChatState> _agentStates = {};
  String? _turnId;
  Future<void>? _connecting;
  Future<void>? _recovering;
  bool _selectingAgent = false;
  Timer? _readTimer;
  Timer? _codexDeltaTimer;
  final Map<String, StringBuffer> _codexDeltaBuffer = {};
  List<NativeCliMessage> _historyMessages = const [];
  String? _historySessionId;
  String? _olderHistoryCursor;
  int _historyGeneration = 0;
  int _historyReadSequence = 0;
  @override
  CliChatState build() {
    ref.listen(
      settingsProvider.select(
        (settings) => settings.isSectionEnabled(AppSection.cliChat),
      ),
      (_, enabled) {
        if (enabled) unawaited(_selectPreferredAgent());
      },
    );
    final server = ref.watch(
      activeServerProvider.select((s) => (s?.id, s?.connectionKey)),
    );
    ref.listen(serverConnectionProvider, (previous, next) {
      if (previous?.isConnected == true && !next.isConnected) {
        _flushCodexDeltas();
        _epoch++;
        _recovering = null;
        unawaited(_close());
        state = state.copyWith(
          recoveryStatus: SessionRecoveryStatus.reconnecting,
          isSending: false,
          isLoading: false,
          isLoadingOlderMessages: false,
          approvals: const [],
        );
      } else if (next.isConnected && previous?.isConnected == false) {
        unawaited(recoverConnection());
      }
    });
    ref.listen(appVisibilityProvider, (_, foreground) {
      if (foreground && state.recoveryStatus != SessionRecoveryStatus.idle) {
        unawaited(recoverConnection());
      }
    });
    final agents = ref
        .read(agentRegistryProvider)
        .agents
        .map((a) => a.profile)
        .toList();
    ref.listen(agentRegistryProvider, (_, next) {
      final profiles = next.agents
          .map((a) => a.profile)
          .where((a) => a.serverId == server.$1)
          .toList();
      final selected = profiles
          .where((a) => a.id == state.activeAgent?.id)
          .firstOrNull;
      if (state.activeAgent != null &&
          (selected == null ||
              selected.cliCommand != state.activeAgent!.cliCommand ||
              selected.executionTarget != state.activeAgent!.executionTarget ||
              selected.containerBinding !=
                  state.activeAgent!.containerBinding ||
              selected.containerReference !=
                  state.activeAgent!.containerReference ||
              selected.containerUser != state.activeAgent!.containerUser)) {
        _epoch++;
        unawaited(_close());
        _agentStates.clear();
        state = CliChatState(serverId: server.$1, agents: profiles);
        unawaited(_selectPreferredAgent());
      } else {
        state = state.copyWith(agents: profiles, activeAgent: selected);
        if (selected == null) unawaited(_selectPreferredAgent());
      }
    });
    ref.onDispose(() {
      _epoch++;
      unawaited(_close());
    });
    _epoch++;
    unawaited(_close());
    _agentStates.clear();
    _clearHistoryWindow();
    final result = CliChatState(
      serverId: server.$1,
      agents: agents.where((a) => a.serverId == server.$1).toList(),
    );
    Future.microtask(_selectPreferredAgent);
    return result;
  }

  Future<void> _selectPreferredAgent() async {
    if (!ref.mounted ||
        !ref.read(settingsProvider).isSectionEnabled(AppSection.cliChat) ||
        _selectingAgent ||
        !ref.read(serverConnectionProvider).isConnected ||
        state.activeAgent != null ||
        state.agents.isEmpty) {
      return;
    }
    final serverId = state.serverId;
    if (serverId == null) return;
    final preferredId = ref
        .read(localStorageServiceProvider)
        .getDefaultAgentId(serverId, cli: true);
    final preferred = state.agents
        .where((agent) => agent.id == preferredId)
        .firstOrNull;
    await selectAgent((preferred ?? state.agents.first).id);
  }

  Future<void> setDefaultAgent(String? agentId) async {
    final serverId = state.serverId;
    if (serverId == null) return;
    if (agentId != null && !state.agents.any((a) => a.id == agentId)) {
      throw ArgumentError.value(agentId, 'agentId', 'Agent is unavailable');
    }
    await ref
        .read(localStorageServiceProvider)
        .setDefaultAgentId(serverId, agentId, cli: true);
    if (ref.mounted) ref.invalidate(defaultAgentSettingsProvider);
  }

  bool _current(int epoch) => ref.mounted && _epoch == epoch;

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
        state.isSending) {
      return;
    }
    if (state.activeAgent == null) {
      await _selectPreferredAgent();
      return;
    }
    if (state.recoveryStatus == SessionRecoveryStatus.idle) return;
    final epoch = _epoch;
    final sessionId = state.activeSession?.id;
    bool current() => _current(epoch) && state.activeSession?.id == sessionId;
    state = state.copyWith(recoveryStatus: SessionRecoveryStatus.syncing);
    try {
      await _connect();
      if (!current()) return;
      if (state.activeSession != null) {
        await _readActive(epoch, recovering: true);
      }
      if (current() && state.recoveryStatus == SessionRecoveryStatus.syncing) {
        state = state.copyWith(recoveryStatus: SessionRecoveryStatus.idle);
      }
    } catch (error) {
      if (current()) {
        _fail(epoch, error, recoveryStatus: SessionRecoveryStatus.failed);
      }
    }
  }

  void _fail(int epoch, Object error, {SessionRecoveryStatus? recoveryStatus}) {
    if (_current(epoch)) {
      final raw = error is ConnectionFailure
          ? error.error.toString()
          : error.toString();
      final text = raw.replaceFirst(RegExp(r'^Bad state: '), '');
      final code =
          text.toLowerCase().contains('model is at capacity') ||
              text.toLowerCase().contains('model at capacity')
          ? 'CLI_MODEL_AT_CAPACITY'
          : [
              'CLI_HISTORY_SDK_MISSING',
              'CLI_HISTORY_RUNTIME_MISSING',
              'CLI_LOGIN_REQUIRED',
              'CLI_NOT_INSTALLED',
              'CLI_VERSION_UNSUPPORTED',
              'CLI_DELETE_FAILED',
              'CLI_DELETE_UNSUPPORTED',
              'CLI_BUSY',
              'CLI_DISCONNECTED',
              'CLI_SERVER_CHANGED',
              'CLI_ENVIRONMENT_FAILED',
              'CLI_MODEL_AT_CAPACITY',
            ].firstWhere(text.contains, orElse: () => 'CLI_OPERATION_FAILED');
      final detail = LogSanitizer.sanitize(
        text
            .split('CLI_DELETE_FAILED:')
            .last
            .trim()
            .replaceAll(RegExp(r'[\r\n]+'), ' '),
      );
      state = state.copyWith(
        recoveryStatus: recoveryStatus,
        isLoading: false,
        isSending: false,
        errorCode: code,
        errorDetail:
            code == 'CLI_DELETE_FAILED' ||
                code == 'CLI_OPERATION_FAILED' ||
                code == 'CLI_MODEL_AT_CAPACITY'
            ? detail.substring(0, detail.length.clamp(0, 240))
            : null,
      );
    }
  }

  Future<void> _close() async {
    _readTimer?.cancel();
    _readTimer = null;
    _codexDeltaTimer?.cancel();
    _codexDeltaTimer = null;
    _codexDeltaBuffer.clear();
    final codex = _codex;
    final openCode = _openCode;
    final events = _events;
    final errors = _errors;
    final bridge = _bridge;
    _codex = null;
    _openCode = null;
    _events = null;
    _errors = null;
    _bridge = null;
    _turnId = null;
    _connecting = null;
    for (final reply in _replies.values) {
      if (!reply.isCompleted) reply.complete({'decision': 'cancel'});
    }
    _replies.clear();
    bridge?.dispose();
    final epoch = _epoch;
    try {
      await codex?.close();
      await openCode?.close();
    } catch (error) {
      _fail(epoch, error);
    } finally {
      await events?.cancel();
      await errors?.cancel();
    }
  }

  Future<void> selectAgent(String id) async {
    if (state.activeAgent?.id == id) return;
    final profile = state.agents.where((a) => a.id == id).firstOrNull;
    if (profile == null) return;
    if (state.isSending ||
        state.approvals.isNotEmpty ||
        state.terminal != null) {
      state = state.copyWith(errorCode: 'CLI_BUSY');
      return;
    }
    _selectingAgent = true;
    try {
      final previous = state.activeAgent;
      if (previous != null) _agentStates[previous.id] = state;
      final epoch = ++_epoch;
      await _close();
      if (!_current(epoch)) return;
      _clearHistoryWindow();
      final saved = _agentStates[id];
      state = CliChatState(
        serverId: state.serverId,
        agents: state.agents,
        activeAgent: profile,
        sessions: saved?.sessions ?? const [],
        activeSession: saved?.activeSession,
        messages: const [],
        cwd: saved?.cwd,
        draftCwd: saved?.draftCwd,
        runSettings: ref
            .read(localStorageServiceProvider)
            .getCliRunSettings(
              state.serverId!,
              profile.id,
              saved?.activeSession?.id,
            ),
        capabilities: saved?.capabilities ?? const AgentRuntimeCapabilities(),
      );
      if (state.hasHistory) {
        if (state.sessions.isEmpty) await refreshSessions();
        if (state.activeSession != null) await _readActive(epoch);
      }
    } finally {
      _selectingAgent = false;
    }
  }

  Future<void> _connect() {
    if (_connecting != null) return _connecting!;
    final epoch = _epoch;
    final future = _connectOnce().whenComplete(() {
      if (_epoch == epoch) _connecting = null;
    });
    _connecting = future;
    return future;
  }

  Future<void> _connectOnce() async {
    final epoch = _epoch;
    final executor = ref.read(sshCommandExecutorProvider);
    final serverId = state.serverId;
    if (serverId == null ||
        state.activeAgent == null ||
        !executor.isConnected(serverId)) {
      throw StateError('CLI_DISCONNECTED');
    }
    final ssh = executor.getClient(serverId);
    if (state.kind == NativeCliKind.claude) return;
    if (ssh == null) throw StateError('CLI_DISCONNECTED');
    if (_codex == null && _openCode == null) {
      final status = await AgentEnvironmentService(
        executor,
      ).inspect(state.activeAgent!, serverId, requireAcp: false);
      if (!_current(epoch)) throw StateError('CLI_SERVER_CHANGED');
      if (status.kind == AgentEnvironmentStatusKind.cliMissing) {
        throw StateError('CLI_NOT_INSTALLED');
      }
      if (status.kind == AgentEnvironmentStatusKind.notLoggedIn) {
        throw StateError('CLI_LOGIN_REQUIRED');
      }
      if (status.kind == AgentEnvironmentStatusKind.error) {
        throw StateError('CLI_ENVIRONMENT_FAILED');
      }
    }
    if (state.kind == NativeCliKind.codex && _codex == null) {
      final profile = state.activeAgent!;
      final script = 'exec ${cliShellQuote(profile.cliCommand)} app-server';
      final process = await ssh.execute(
        agentTargetCommand(
          profile,
          profile.executionTarget == 'docker'
              ? script
              : 'bash -l -c ${cliShellQuote(script)}',
        ),
      );
      final client = CodexNativeClient(Connection(CodexSshTransport(process)));
      try {
        await client.initialize();
      } catch (_) {
        await client.close();
        rethrow;
      }
      if (!_current(epoch)) {
        await client.close();
        throw StateError('CLI_SERVER_CHANGED');
      }
      _codex = client;
      AgentRuntimeCapabilities capabilities;
      try {
        capabilities = await client.capabilities();
      } catch (_) {
        capabilities = const AgentRuntimeCapabilities(
          supportsStructuredSettings: true,
        );
      }
      if (_current(epoch)) {
        state = state.copyWith(capabilities: capabilities);
      }
      _errors = client.connection.errors.listen(
        (failure) => _fail(epoch, failure),
      );
      client.connection.onClose.listen(
        (_) => _fail(epoch, StateError('CLI_DISCONNECTED')),
      );
      client.connection.onAnyNotification(
        (method, params) => _codexEvent(epoch, method, params),
      );
      for (final method in [
        'item/commandExecution/requestApproval',
        'item/fileChange/requestApproval',
      ]) {
        client.connection.onRequest(
          method,
          (params) =>
              _ask(epoch, method, Map<String, dynamic>.from(params as Map)),
        );
      }
      // Unsupported interactive tools fail closed; users can continue in the CLI.
      client.connection.onRequest(
        'item/permissions/requestApproval',
        (_) => {'permissions': {}, 'scope': 'turn'},
      );
      client.connection.onRequest('item/tool/requestUserInput', (_) {
        if (_current(epoch)) {
          state = state.copyWith(errorCode: 'CLI_USE_TERMINAL');
        }
        return {'answers': {}};
      });
      final deletion = await executor.executeWithLoginShell(
        serverId,
        agentTargetCommand(
          state.activeAgent!,
          '${cliShellQuote(state.activeAgent!.cliCommand)} delete --help',
        ),
      );
      if (_current(epoch)) {
        final help = '${deletion.stdout}\n${deletion.stderr}';
        state = state.copyWith(
          canDelete:
              deletion.isSuccess &&
              help.contains('delete') &&
              help.contains('SESSION') &&
              help.contains('--force'),
        );
      }
    } else if (state.kind == NativeCliKind.openCode && _openCode == null) {
      final client = await OpenCodeNativeClient.connect(
        ssh,
        command: state.activeAgent!.cliCommand,
        profile: state.activeAgent!,
        executor: executor,
        serverId: serverId,
      );
      if (!_current(epoch)) {
        await client.close();
        throw StateError('CLI_SERVER_CHANGED');
      }
      _openCode = client;
      AgentRuntimeCapabilities capabilities;
      try {
        capabilities = await client.capabilities();
      } catch (_) {
        capabilities = const AgentRuntimeCapabilities(
          supportsStructuredSettings: true,
        );
      }
      if (!_current(epoch)) {
        await client.close();
        return;
      }
      state = state.copyWith(capabilities: capabilities);
      _events = client.events().listen(
        (event) => _openCodeEvent(epoch, event),
        onError: (Object error) => _fail(epoch, error),
        onDone: () => _fail(epoch, StateError('CLI_DISCONNECTED')),
      );
      state = state.copyWith(canDelete: true);
    }
  }

  Future<Object?> _ask(int epoch, String method, Map<String, dynamic> params) {
    if (!_current(epoch) || params['threadId'] != state.activeSession?.id) {
      return Future.value({'decision': 'cancel'});
    }
    final id = '${params['itemId']}:${++_approvalSequence}';
    final policy = state.runSettings.permissionPolicy;
    if (policy == OperationPermissionPolicy.autoAllowAll ||
        (policy == OperationPermissionPolicy.autoAllowSafe &&
            !_approvalIsDangerous(method, params))) {
      return Future.value({'decision': 'accept'});
    }
    final completer = Completer<Object?>();
    _replies[id] = completer;
    state = state.copyWith(
      approvals: [
        ...state.approvals,
        NativeCliApproval(id: id, method: method, details: params),
      ],
    );
    return completer.future;
  }

  void _codexEvent(int epoch, String method, Object? raw) {
    if (!_current(epoch) || raw is! Map) return;
    if (raw['threadId'] != state.activeSession?.id) return;
    if (method == 'turn/started') {
      _turnId = raw['turn']?['id'] as String?;
      state = state.copyWith(isSending: true);
    } else if (method == 'item/agentMessage/delta') {
      final id = raw['itemId'].toString();
      (_codexDeltaBuffer[id] ??= StringBuffer()).write(raw['delta'] ?? '');
      _codexDeltaTimer ??= Timer(const Duration(milliseconds: 50), () {
        _codexDeltaTimer = null;
        if (_current(epoch)) _flushCodexDeltas();
      });
    } else if (method == 'turn/completed') {
      _flushCodexDeltas();
      _turnId = null;
      for (final reply in _replies.values) {
        if (!reply.isCompleted) reply.complete({'decision': 'cancel'});
      }
      _replies.clear();
      state = state.copyWith(
        isSending: false,
        approvals: [],
        errorCode: raw['turn']?['status'] == 'failed'
            ? 'CLI_TURN_FAILED'
            : null,
      );
      unawaited(refreshSessions());
      unawaited(_readActive(epoch));
    }
  }

  void _flushCodexDeltas() {
    if (_codexDeltaBuffer.isEmpty || !ref.mounted) return;
    final messages = [...state.messages];
    for (final entry in _codexDeltaBuffer.entries) {
      final index = messages.indexWhere((message) => message.id == entry.key);
      if (index < 0) {
        messages.add(
          NativeCliMessage(
            id: entry.key,
            role: 'assistant',
            text: entry.value.toString(),
          ),
        );
      } else {
        final current = messages[index];
        messages[index] = NativeCliMessage(
          id: current.id,
          role: current.role,
          text: '${current.text}${entry.value}',
        );
      }
    }
    _codexDeltaBuffer.clear();
    state = state.copyWith(messages: messages);
  }

  void _openCodeEvent(int epoch, Map<String, dynamic> event) {
    if (!_current(epoch)) return;
    final props = Map<String, dynamic>.from(event['properties'] as Map? ?? {});
    final part = props['part'];
    final id =
        props['sessionID'] ??
        (part is Map ? part['sessionID'] : null) ??
        props['info']?['sessionID'];
    if (id != state.activeSession?.id) return;
    final type = event['type'];
    if (type == 'permission.asked' || type == 'permission.updated') {
      final approval = NativeCliApproval(
        id: props['id'] as String,
        method: type.toString(),
        details: props,
      );
      state = state.copyWith(
        approvals: [
          ...state.approvals.where((a) => a.id != approval.id),
          approval,
        ],
      );
      final policy = state.runSettings.permissionPolicy;
      if (policy == OperationPermissionPolicy.autoAllowAll ||
          (policy == OperationPermissionPolicy.autoAllowSafe &&
              !_approvalIsDangerous(type.toString(), props))) {
        unawaited(respondApproval(approval.id, true));
      }
    } else if (type == 'permission.replied') {
      state = state.copyWith(
        approvals: state.approvals
            .where((a) => a.id != props['requestID'])
            .toList(),
      );
    } else if (type == 'question.asked') {
      state = state.copyWith(errorCode: 'CLI_USE_TERMINAL');
    } else if (type == 'session.idle' ||
        type == 'session.error' ||
        (type == 'session.status' && props['status']?['type'] == 'idle')) {
      state = state.copyWith(
        isSending: false,
        errorCode: type == 'session.error' ? 'CLI_TURN_FAILED' : null,
        approvals: [],
      );
      unawaited(_readActive(epoch));
      unawaited(refreshSessions());
    } else if (type == 'message.part.updated' || type == 'message.part.delta') {
      _readTimer ??= Timer(const Duration(milliseconds: 150), () {
        _readTimer = null;
        if (_current(epoch)) unawaited(_readActive(epoch));
      });
    }
  }

  bool _approvalIsDangerous(String method, Map<String, dynamic> details) {
    if (method.contains('fileChange')) return true;
    final permission = (details['permission'] ?? details['type'])
        ?.toString()
        .toLowerCase();
    if (permission != null &&
        const {'read', 'list', 'search', 'glob', 'grep'}.contains(permission)) {
      return false;
    }
    final raw = details['command'] ?? details['cmd'];
    final command = raw is List ? raw.join(' ') : raw?.toString() ?? '';
    return !RegExp(
      r'^\s*(pwd|ls|cat|head|tail|rg|grep|find|stat|git\s+(status|diff|log))(?:\s|$)',
    ).hasMatch(command);
  }

  Future<void> refreshSessions({bool loadMore = false, String? cwd}) async {
    if (state.activeAgent == null || !state.hasHistory) return;
    final epoch = _epoch;
    state = state.copyWith(isLoading: true, cwd: cwd);
    try {
      await _connect();
      if (!_current(epoch)) return;
      final page = switch (state.kind) {
        NativeCliKind.codex => await _codex!.list(
          cursor: loadMore ? state.cursor : null,
          cwd: state.cwd,
        ),
        NativeCliKind.openCode => await _openCode!.list(
          cwd: state.cwd,
          cursor: loadMore ? state.cursor : null,
        ),
        NativeCliKind.claude => await ClaudeNativeHistory(
          ref.read(sshCommandExecutorProvider),
          state.serverId!,
          profile: state.activeAgent,
        ).list(cwd: state.cwd),
        NativeCliKind.terminal => const NativeCliPage([]),
      };
      if (!_current(epoch)) return;
      final sessions = loadMore
          ? [
              ...state.sessions,
              ...page.sessions.where(
                (s) => !state.sessions.any((old) => old.id == s.id),
              ),
            ]
          : page.sessions;
      final selected = _preferredSession(
        sessions,
        current: state.activeSession,
      );
      state = state.copyWith(
        sessions: sessions,
        activeSession: selected,
        clearSession: selected == null,
        cursor: page.cursor,
        clearCursor: page.cursor == null,
        isLoading: false,
      );
    } catch (error) {
      _fail(epoch, error);
    }
  }

  NativeCliSession? _preferredSession(
    List<NativeCliSession> sessions, {
    NativeCliSession? current,
  }) {
    final serverId = state.serverId;
    final agentId = state.activeAgent?.id;
    if (serverId == null || agentId == null) return null;
    final storage = ref.read(localStorageServiceProvider);
    final preference = storage.getChatLaunchPreference(
      serverId,
      agentId,
      cli: true,
    );
    final desired = switch (preference.mode) {
      ChatLaunchMode.fixed => preference.sessionId,
      ChatLaunchMode.rememberLast =>
        storage.getLastChatSessionId(serverId, agentId, cli: true) ??
            current?.id,
      ChatLaunchMode.blankDraft => null,
    };
    if (desired != null) {
      final listed = sessions.where((entry) => entry.id == desired).firstOrNull;
      if (listed != null) return listed;
      if (preference.mode == ChatLaunchMode.rememberLast &&
          current?.id == desired) {
        return current;
      }
    }
    if (preference.mode == ChatLaunchMode.blankDraft) return null;
    return null;
  }

  Future<void> setLaunchPreference(ChatLaunchPreference preference) async {
    final serverId = state.serverId;
    final agentId = state.activeAgent?.id;
    if (serverId == null || agentId == null) return;
    await ref
        .read(localStorageServiceProvider)
        .saveChatLaunchPreference(serverId, agentId, preference, cli: true);
    final previousId = state.activeSession?.id;
    final selected = _preferredSession(
      state.sessions,
      current: state.activeSession,
    );
    state = state.copyWith(
      activeSession: selected,
      clearSession: selected == null,
      messages: selected?.id == state.activeSession?.id ? state.messages : [],
    );
    if (selected != null && selected.id != previousId) {
      await selectSession(selected.id);
    }
  }

  void createDraft() {
    if (state.isSending || state.terminal != null) {
      state = state.copyWith(errorCode: 'CLI_BUSY');
      return;
    }
    _clearHistoryWindow();
    state = state.copyWith(
      clearSession: true,
      recoveryStatus: SessionRecoveryStatus.idle,
      clearDraftCwd: true,
      messages: [],
      approvals: [],
      hasOlderMessages: false,
      isLoadingOlderMessages: false,
      runSettings: state.serverId == null || state.activeAgent == null
          ? const ChatRunSettings()
          : ref
                .read(localStorageServiceProvider)
                .getCliRunSettings(
                  state.serverId!,
                  state.activeAgent!.id,
                  null,
                ),
    );
  }

  Future<void> updateRunSettings(ChatRunSettings settings) async {
    if (state.isSending ||
        state.activeAgent == null ||
        state.serverId == null) {
      return;
    }
    await ref
        .read(localStorageServiceProvider)
        .saveCliRunSettings(
          state.serverId!,
          state.activeAgent!.id,
          state.activeSession?.id,
          settings,
        );
    if (ref.mounted) state = state.copyWith(runSettings: settings);
  }

  Future<void> refreshComposerCatalog() async {
    if (state.kind != NativeCliKind.codex || state.activeAgent == null) return;
    final epoch = _epoch;
    try {
      await _connect();
      final catalog = await _codex!.composerCatalog(
        cwd: state.activeSession?.cwd ?? state.draftCwd ?? state.cwd,
      );
      if (_current(epoch)) state = state.copyWith(composerCatalog: catalog);
    } catch (_) {
      // Composer enhancements never block the normal messaging path.
    }
  }

  void setDraftWorkingDirectory(String? path) {
    if (state.activeSession != null || state.isSending) return;
    if (path == null || path.isEmpty) {
      state = state.copyWith(clearDraftCwd: true);
      return;
    }
    if (!path.startsWith('/') || path.contains('\u0000')) {
      throw ArgumentError.value(path, 'path', 'Absolute path required');
    }
    state = state.copyWith(draftCwd: path);
  }

  Future<void> selectSession(String id) async {
    if (state.isSending || state.terminal != null) {
      state = state.copyWith(errorCode: 'CLI_BUSY');
      return;
    }
    final session = state.sessions.where((s) => s.id == id).firstOrNull;
    if (session == null) return;
    await ref
        .read(localStorageServiceProvider)
        .saveLastChatSessionId(
          state.serverId!,
          state.activeAgent!.id,
          session.id,
          cli: true,
        );
    _clearHistoryWindow();
    state = state.copyWith(
      activeSession: session,
      recoveryStatus: SessionRecoveryStatus.idle,
      messages: [],
      isLoading: true,
      hasOlderMessages: false,
      isLoadingOlderMessages: false,
      runSettings: ref
          .read(localStorageServiceProvider)
          .getCliRunSettings(
            state.serverId!,
            state.activeAgent!.id,
            session.id,
          ),
    );
    await _readActive(_epoch);
  }

  Future<void> _readActive(int epoch, {bool recovering = false}) async {
    final session = state.activeSession;
    if (session == null) return;
    final generation = _historyGeneration;
    final sequence = ++_historyReadSequence;
    try {
      await _connect();
      if (!_current(epoch) || generation != _historyGeneration) return;
      var page = await _readHistoryPage(session);
      final previous = recovering ? state.messages : _historyMessages;
      if (recovering && previous.isNotEmpty) {
        final known = previous.map((m) => m.id).toSet();
        var reads = 1;
        // Bound automatic catch-up; old content remains visible even if a very
        // large offline gap needs a later explicit retry.
        while (!page.messages.any((m) => known.contains(m.id)) &&
            page.olderCursor != null &&
            reads++ < 20) {
          final older = await _readHistoryPage(
            session,
            cursor: page.olderCursor,
          );
          if (!_current(epoch) || generation != _historyGeneration) return;
          final ids = page.messages.map((m) => m.id).toSet();
          page = NativeCliMessagePage([
            ...older.messages.where((m) => !ids.contains(m.id)),
            ...page.messages,
          ], olderCursor: older.olderCursor);
        }
      }
      if (_current(epoch) &&
          generation == _historyGeneration &&
          sequence == _historyReadSequence &&
          state.activeSession?.id == session.id) {
        final pageIds = page.messages.map((m) => m.id).toSet();
        final overlap = previous.indexWhere((m) => pageIds.contains(m.id));
        if (recovering) {
          final updates = {for (final m in page.messages) m.id: m};
          for (final previousMessage in previous) {
            final update = updates[previousMessage.id];
            if (update != null &&
                (update.role != previousMessage.role ||
                    update.text.length < previousMessage.text.length)) {
              updates.remove(previousMessage.id);
              state = state.copyWith(
                recoveryStatus: SessionRecoveryStatus.incomplete,
              );
            }
          }
          final existingIds = previous.map((m) => m.id).toSet();
          final tail = overlap < 0
              ? page.messages
              : page.messages.skipWhile((m) => m.id != previous[overlap].id);
          final pending = previous
              .where((m) => m.id.startsWith('local-'))
              .toList();
          final aliases = <String, String>{};
          for (final local in pending) {
            final matches = tail
                .where(
                  (m) =>
                      m.role == local.role &&
                      m.text == local.text &&
                      !existingIds.contains(m.id),
                )
                .toList();
            if (matches.length == 1 &&
                pending
                        .where(
                          (m) => m.role == local.role && m.text == local.text,
                        )
                        .length ==
                    1) {
              aliases[matches.single.id] = local.id;
            }
          }
          _historyMessages = [
            for (final m in previous) updates[m.id] ?? m,
            ...tail.where(
              (m) => !existingIds.contains(m.id) && !aliases.containsKey(m.id),
            ),
          ];
          if (previous.isNotEmpty && overlap < 0) {
            state = state.copyWith(
              recoveryStatus: SessionRecoveryStatus.incomplete,
            );
          }
        } else {
          _historyMessages = overlap < 0
              ? page.messages
              : [...previous.take(overlap), ...page.messages];
        }
        _historySessionId = session.id;
        if (overlap < 0 && !recovering) _olderHistoryCursor = page.olderCursor;
        _publishHistoryWindow();
      }
    } catch (error) {
      if (generation == _historyGeneration &&
          sequence == _historyReadSequence &&
          state.activeSession?.id == session.id) {
        _fail(
          epoch,
          error,
          recoveryStatus: recovering ? SessionRecoveryStatus.failed : null,
        );
      }
    }
  }

  int get _historyPageSize => ref.read(settingsProvider).cliHistoryPageSize;

  Future<NativeCliMessagePage> _readHistoryPage(
    NativeCliSession session, {
    String? cursor,
  }) => switch (state.kind) {
    NativeCliKind.codex => _codex!.readPage(
      session.id,
      cursor: cursor,
      limit: _historyPageSize,
    ),
    NativeCliKind.openCode => _openCode!.readPage(
      session.id,
      cwd: session.cwd,
      cursor: cursor,
      limit: _historyPageSize,
    ),
    NativeCliKind.claude => ClaudeNativeHistory(
      ref.read(sshCommandExecutorProvider),
      state.serverId!,
      profile: state.activeAgent,
    ).readPage(session.id, cursor: cursor, limit: _historyPageSize),
    NativeCliKind.terminal => Future.value(const NativeCliMessagePage([])),
  };

  void _clearHistoryWindow() {
    _historyGeneration++;
    _historyMessages = const [];
    _historySessionId = null;
    _olderHistoryCursor = null;
  }

  void _publishHistoryWindow({bool isLoading = false}) {
    state = state.copyWith(
      messages: _historyMessages,
      hasOlderMessages: _olderHistoryCursor != null,
      isLoading: isLoading,
      isLoadingOlderMessages: false,
    );
  }

  Future<void> loadOlderMessages() async {
    if (state.isSending ||
        state.isLoadingOlderMessages ||
        !state.hasOlderMessages ||
        _historySessionId != state.activeSession?.id) {
      return;
    }
    final epoch = _epoch;
    final session = state.activeSession;
    final generation = _historyGeneration;
    final cursor = _olderHistoryCursor;
    state = state.copyWith(isLoadingOlderMessages: true);
    try {
      final page = await _readHistoryPage(session!, cursor: cursor);
      if (!_current(epoch) ||
          generation != _historyGeneration ||
          session.id != state.activeSession?.id ||
          cursor != _olderHistoryCursor) {
        return;
      }
      final known = _historyMessages.map((m) => m.id).toSet();
      _historyMessages = [
        ...page.messages.where((m) => !known.contains(m.id)),
        ..._historyMessages,
      ];
      _olderHistoryCursor = page.olderCursor == cursor
          ? null
          : page.olderCursor;
      _publishHistoryWindow();
    } catch (error) {
      if (generation == _historyGeneration &&
          session?.id == state.activeSession?.id) {
        state = state.copyWith(isLoadingOlderMessages: false);
        _fail(epoch, error);
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty ||
        !ref.read(serverConnectionProvider).isConnected ||
        state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing ||
        state.isSending ||
        state.activeAgent == null ||
        !state.structuredSend) {
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(isSending: true);
    var dispatched = false;
    try {
      await _connect();
      if (!_current(epoch)) return;
      var session = state.activeSession;
      if (session == null) {
        session = state.kind == NativeCliKind.codex
            ? await _codex!.start(cwd: state.draftCwd)
            : await _openCode!.start(cwd: state.draftCwd);
        if (!_current(epoch)) return;
        state = state.copyWith(
          activeSession: session,
          sessions: [session, ...state.sessions],
        );
        await ref
            .read(localStorageServiceProvider)
            .saveLastChatSessionId(
              state.serverId!,
              state.activeAgent!.id,
              session.id,
              cli: true,
            );
        await ref
            .read(localStorageServiceProvider)
            .saveCliRunSettings(
              state.serverId!,
              state.activeAgent!.id,
              session.id,
              state.runSettings,
            );
      } else if (state.kind == NativeCliKind.codex) {
        await _codex!.resume(session.id);
      }
      if (!_current(epoch)) return;
      state = state.copyWith(
        messages: [
          ...state.messages,
          NativeCliMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            role: 'user',
            text: text,
          ),
        ],
      );
      if (state.kind == NativeCliKind.codex) {
        dispatched = true;
        final turnId = await _codex!.send(
          session.id,
          text,
          settings: state.runSettings,
        );
        if (_current(epoch) && state.isSending) _turnId = turnId;
      } else {
        dispatched = true;
        await _openCode!.send(
          session.id,
          text,
          cwd: session.cwd,
          settings: state.runSettings,
        );
      }
    } catch (error) {
      _fail(epoch, error);
      if (_current(epoch) && (!dispatched || error is RpcError)) {
        final detail = state.errorDetail;
        state = state.copyWith(
          isSending: false,
          errorCode:
              dispatched &&
                  error is RpcError &&
                  state.errorCode != 'CLI_MODEL_AT_CAPACITY'
              ? 'CLI_TURN_FAILED'
              : state.errorCode,
          errorDetail: detail,
        );
      }
    }
  }

  Future<void> respondApproval(String id, bool allow) async {
    final approval = state.approvals.where((a) => a.id == id).firstOrNull;
    if (approval == null) return;
    final epoch = _epoch;
    try {
      if (state.kind == NativeCliKind.codex) {
        final choices = approval.details['availableDecisions'];
        if (choices is List &&
            !choices.contains(allow ? 'accept' : 'decline')) {
          state = state.copyWith(errorCode: 'CLI_USE_TERMINAL');
          return;
        }
        _replies.remove(id)?.complete({
          'decision': allow ? 'accept' : 'decline',
        });
      } else {
        await _openCode!.approve(
          approval,
          allow,
          cwd: state.activeSession?.cwd,
        );
      }
      if (_current(epoch)) {
        state = state.copyWith(
          approvals: state.approvals.where((a) => a.id != id).toList(),
        );
      }
    } catch (error) {
      _fail(epoch, error);
    }
  }

  Future<void> stop() async {
    final epoch = _epoch;
    final session = state.activeSession;
    try {
      if (session != null && state.isSending) {
        if (_codex != null && _turnId == null) {
          state = state.copyWith(errorCode: 'CLI_BUSY');
          return;
        }
        if (_codex != null && _turnId != null) {
          await _codex!.interrupt(session.id, _turnId!);
        } else if (_openCode != null) {
          await _openCode!.interrupt(session.id, cwd: session.cwd);
        }
      }
      if (_current(epoch)) state = state.copyWith(isSending: false);
    } catch (error) {
      _fail(epoch, error);
    }
  }

  Future<void> deleteSession(String id, {required bool confirmed}) async {
    if (!confirmed ||
        !state.canDelete ||
        state.isSending ||
        state.terminal != null ||
        state.isLoading) {
      return;
    }
    final session = state.sessions.where((s) => s.id == id).firstOrNull;
    if (session == null) return;
    final epoch = _epoch;
    state = state.copyWith(isLoading: true);
    try {
      if (_codex != null) {
        final summary = await _codex!.request('thread/read', {'threadId': id});
        if (summary['thread']?['status']?['type'] == 'active') {
          throw StateError('CLI_BUSY');
        }
        if (!_current(epoch)) return;
        final result = await ref
            .read(sshCommandExecutorProvider)
            .executeWithLoginShell(
              state.serverId!,
              agentTargetCommand(
                state.activeAgent!,
                '${cliShellQuote(state.activeAgent!.cliCommand)} delete --force ${cliShellQuote(session.resumeId)}',
              ),
            );
        if (!result.isSuccess) {
          throw StateError(
            'CLI_DELETE_FAILED:${result.stderr.trim().isEmpty ? result.stdout.trim() : result.stderr.trim()}',
          );
        }
      } else if (_openCode != null) {
        await _openCode!.delete(id, cwd: session.cwd);
      } else {
        throw StateError('CLI_DELETE_UNSUPPORTED');
      }
      if (!_current(epoch)) return;
      final wasActive = state.activeSession?.id == id;
      state = state.copyWith(
        sessions: state.sessions.where((s) => s.id != id).toList(),
        clearSession: wasActive,
        messages: wasActive ? [] : state.messages,
        hasOlderMessages: wasActive ? false : state.hasOlderMessages,
        isLoadingOlderMessages: false,
        isLoading: false,
      );
      if (wasActive) _clearHistoryWindow();
    } catch (error) {
      _fail(epoch, error);
    }
  }

  Future<void> installHistorySdk({required bool confirmed}) async {
    if (!confirmed ||
        state.kind != NativeCliKind.claude ||
        state.serverId == null ||
        state.isLoading) {
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(isLoading: true);
    try {
      await ClaudeNativeHistory(
        ref.read(sshCommandExecutorProvider),
        state.serverId!,
        profile: state.activeAgent,
      ).install();
      if (_current(epoch)) await refreshSessions();
    } catch (error) {
      _fail(epoch, error);
    }
  }

  Future<void> openTerminal() async {
    if (state.activeAgent == null ||
        state.terminal != null ||
        state.isSending) {
      return;
    }
    final epoch = _epoch;
    try {
      final profile = state.activeAgent!;
      AgentCommandValidator.validate(profile.cliCommand);
      final executor = ref.read(sshCommandExecutorProvider);
      final ssh = executor.getClient(state.serverId!);
      if (ssh == null || !executor.isConnected(state.serverId!)) {
        throw StateError('CLI_DISCONNECTED');
      }
      final session = state.activeSession;
      final cwd = session?.cwd ?? state.draftCwd;
      if (!RegExp(r'^[A-Za-z0-9_./+-]+$').hasMatch(profile.cliCommand)) {
        throw StateError('CLI_INVALID_EXECUTABLE');
      }
      var command = cliShellQuote(profile.cliCommand);
      if (session != null) {
        command += switch (state.kind) {
          NativeCliKind.codex => ' resume ${cliShellQuote(session.resumeId)}',
          NativeCliKind.openCode =>
            ' --session ${cliShellQuote(session.resumeId)}',
          NativeCliKind.claude =>
            ' --resume ${cliShellQuote(session.resumeId)}',
          NativeCliKind.terminal => '',
        };
      }
      final launch =
          '${cwd == null || cwd.isEmpty ? '' : 'cd ${cliShellQuote(cwd)} && '}exec $command';
      final terminal = Terminal(maxLines: 1500);
      final bridge = TerminalSessionBridge(
        terminal: terminal,
        sshClient: ssh,
        serverName: ref.read(activeServerProvider)!.name,
        serverId: state.serverId!,
        terminalId: 'cli-${profile.id}',
        remoteExecCommand: profile.executionTarget == 'docker'
            ? agentTargetCommand(profile, launch, interactive: true)
            : null,
        launchCommand: profile.executionTarget == 'host' ? launch : null,
      );
      _bridge = bridge;
      state = state.copyWith(terminal: terminal);
      await bridge.start();
      if (!_current(epoch)) bridge.dispose();
    } catch (error) {
      _fail(epoch, error);
    }
  }

  void closeTerminal() {
    _bridge?.dispose();
    _bridge = null;
    state = state.copyWith(clearTerminal: true);
  }

  void sendTerminalKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    if (state.terminal == null) return;
    _bridge?.sendKey(key, isCtrl: isCtrl, isAlt: isAlt);
  }

  Future<void> pasteTerminalClipboard() async {
    if (state.terminal == null) return;
    await _bridge?.pasteClipboard();
  }

  void pasteTerminalText(String text) => _bridge?.pasteText(text);
}
