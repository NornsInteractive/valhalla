import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/security/agent_command_validator.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/acp_account_info.dart';
import 'acp_ssh_transport.dart';

/// Agent 声明的一种认证方式，供 UI 呈现给用户选择。
///
/// 与 [ToolExecution]、[PlanStep] 同级的稳定契约，避免 UI 依赖 acpd 的
/// [AuthMethod] 密封类型。
class AcpAuthMethod {
  final String id;
  final String name;
  final String? description;

  const AcpAuthMethod({required this.id, required this.name, this.description});
}

/// 由 ACP Agent 事件流驱动的本地事件模型。
///
/// 这些类型是基础设施层与 provider 层之间的稳定契约，与 acpd 的 wire 类型
/// 解耦，避免 UI 状态直接依赖协议 schema。
sealed class ACPEvent {}

class ACPThinkingChunkEvent extends ACPEvent {
  final String chunk;
  final String? messageId;
  ACPThinkingChunkEvent(this.chunk, {this.messageId});
}

class ACPContentChunkEvent extends ACPEvent {
  final String chunk;
  final String? messageId;
  ACPContentChunkEvent(this.chunk, {this.messageId});
}

class ACPUserContentChunkEvent extends ACPEvent {
  final String chunk;
  final String? messageId;
  ACPUserContentChunkEvent(this.chunk, {this.messageId});
}

class ACPAttachmentEvent extends ACPEvent {
  final MessageRole role;
  final String? messageId;
  final ContentBlock content;
  ACPAttachmentEvent(this.role, this.messageId, this.content);
}

class ACPAccountEvent extends ACPEvent {
  final AcpAccountInfo account;
  ACPAccountEvent(this.account);
}

class AcpRemoteSession {
  final String id, title, workingDirectory, serverId, agentId, launchKey;
  const AcpRemoteSession({
    required this.id,
    required this.title,
    required this.workingDirectory,
    required this.serverId,
    required this.agentId,
    required this.launchKey,
  });
}

class AcpRemoteSessionPage {
  final List<AcpRemoteSession> sessions;
  final String? nextCursor;
  const AcpRemoteSessionPage(this.sessions, this.nextCursor);
}

class ACPPlanUpdateEvent extends ACPEvent {
  final List<PlanStep> planSteps;
  ACPPlanUpdateEvent(this.planSteps);
}

class ACPToolExecutionEvent extends ACPEvent {
  final ToolExecution toolExecution;
  ACPToolExecutionEvent(this.toolExecution);
}

class ACPPermissionRequestEvent extends ACPEvent {
  final PermissionRequest request;
  final Completer<String?> responseCompleter;
  ACPPermissionRequestEvent({
    required this.request,
    required this.responseCompleter,
  });
}

class ACPCompleteEvent extends ACPEvent {}

class ACPSettingsChangedEvent extends ACPEvent {}

class AcpPromptAttachment {
  static const maxTextBytes = 1024 * 1024;
  static const maxImageBytes = 20 * 1024 * 1024;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? uri;
  final String? localPath;
  bool get isImage => mimeType.startsWith('image/');
  const AcpPromptAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.uri,
    this.localPath,
  });
}

class AcpSlashCommand {
  final String name;
  final String description;
  final String? hint;
  final bool isDraftPreview;
  const AcpSlashCommand(
    this.name,
    this.description,
    this.hint, {
    this.isDraftPreview = false,
  });
  bool get isSkill => name.startsWith(r'$');
  String get insertion =>
      isSkill ? '$name ' : '/${name.replaceFirst(RegExp(r'^/'), '')} ';
}

class ACPCommandsChangedEvent extends ACPEvent {
  final List<AcpSlashCommand> commands;
  ACPCommandsChangedEvent(this.commands);
}

class AcpUsage {
  final int? used;
  final int? size;
  final double? cost;
  final String? currency;
  const AcpUsage({this.used, this.size, this.cost, this.currency});
}

class ACPUsageEvent extends ACPEvent {
  final AcpUsage usage;
  ACPUsageEvent(this.usage);
}

/// Agent 要求认证（`RpcError(-32000)`）。
///
/// [methods] 为空表示 agent 声明需要认证但未提供任何可选方式，此时只能由
/// 用户到 Agent 管理页自行处理登录。
class ACPAuthRequiredEvent extends ACPEvent {
  final List<AcpAuthMethod> methods;
  ACPAuthRequiredEvent(this.methods);
}

class ACPErrorEvent extends ACPEvent {
  final String error;
  ACPErrorEvent(this.error);
}

/// 基于 [AgentProfile.acpCommand] 启动远端 stdio ACP 会话的适配器。
///
/// 帧协议、请求关联与 schema 编解码全部交给 acpd；本类只负责：
/// 1. 用 profile 命令建立会话（initialize → session/new → session/prompt）；
/// 2. 把 `session/update` 通知映射为本地 [ACPEvent]；
/// 3. 把 `session/request_permission` 交给上层审批后回写 outcome。
///
/// 缺少有效 [AgentProfile.acpCommand] 时返回结构化错误码，绝不回退到任何
/// 内置的 SSH 运维模拟流程。
class ACPClientAdapter {
  ACPClientAdapter({
    required this.profile,
    required this.transport,
    this.workingDirectory = '/root',
    this.requestTimeout = const Duration(minutes: 5),
    this.onSessionUpdate,
    this.resumeSessionId,
    this.captureReplay = false,
  });

  final AgentProfile profile;
  final Transport transport;
  final String workingDirectory;
  final Duration requestTimeout;
  final bool captureReplay;

  /// 可选的独立订阅回调（在映射为本地事件之后调用）。
  final void Function(SessionUpdate update)? onSessionUpdate;

  /// 上次会话的 id；非 null 时优先尝试恢复而不是新建。
  ///
  /// 这是「断线不丢上下文」的关键：ACP 的会话状态在 agent 进程里，
  /// 只要用同一个 sessionId 走 `session/load` / `session/resume`，
  /// 之前的对话就还在。
  final String? resumeSessionId;

  /// 会话建立完成后的回调，用于把 sessionId 持久化下来。
  ///
  /// 在 `session/new` 之后也会调用：新会话的 id 同样需要记住，
  /// 否则下一次掉线又只能新建。
  void Function(String sessionId)? onSessionEstablished;

  static const missingAcpCommandCode = 'ACP_MISSING_ACP_COMMAND';
  static const invalidAcpCommandCode = 'ACP_INVALID_ACP_COMMAND';
  static const disconnectedCode = 'ACP_DISCONNECTED';
  static const transportFailureCode = 'ACP_TRANSPORT_FAILURE';

  /// Agent 明确要求认证；由 UI 引导用户选择认证方式后重试。
  static const authRequiredCode = 'ACP_AUTH_REQUIRED';

  final StreamController<ACPEvent> _eventController =
      StreamController<ACPEvent>.broadcast(sync: true);
  Stream<ACPEvent> get eventStream => _eventController.stream;

  ClientConnection? _connection;
  String? _sessionId;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  Timer? _idleTimer;
  bool _inBackground = false;

  /// OS suspension is not an idle Agent. Give foreground reception a fresh
  /// budget; do not cancel a remote prompt merely because the screen locked.
  void setInBackground(bool value) {
    if (_inBackground == value) return;
    _inBackground = value;
    _resetIdleTimer();
  }

  Completer<PromptResponse>? _idleFailure;
  int _waitingPermissions = 0;
  final Completer<void> _disposedSignal = Completer<void>();
  bool _completed = false;
  bool _acceptContent = false;
  Future<void>? _preparing;
  bool _initialized = false;
  String? _lastFailedOperation;
  String? _sessionOperation;
  List<SessionConfigOption> _configOptions = const [];
  SessionModeState? _modes;
  final Map<String, ToolExecution> _tools = {};
  AgentCapabilities agentCapabilities = const AgentCapabilities();
  Implementation? agentInfo;
  Future<void>? _initializing;
  List<AcpSlashCommand> commands = const [];
  bool _commandsReceived = false;

  /// ACP has no standard sessionless slash-command inventory. This baseline is
  /// verified against codex-acp 2.0.0, not a fabricated live notification.
  /// Unknown versions/agents stay empty; real notifications always win, even []
  /// and the first selected command is sent through normal lazy session setup.
  List<AcpSlashCommand> get composerCommands {
    if (_commandsReceived || _sessionId != null) return commands;
    if (agentInfo?.name != '@agentclientprotocol/codex-acp' ||
        agentInfo?.version != '2.0.0') {
      return commands;
    }
    // ponytail: version-pinned preview; verify a new adapter version before
    // extending this baseline, or replace it with sessionless discovery upstream.
    return const [
      AcpSlashCommand('plan', 'Turn plan mode on.', null, isDraftPreview: true),
      AcpSlashCommand(
        'mcp',
        'List configured MCP tools.',
        null,
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'skills',
        'List available skills.',
        null,
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'status',
        'Display session configuration and token usage.',
        null,
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'review',
        'Review changes or use custom instructions.',
        'optional review instructions',
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'review-branch',
        'Review changes relative to a base branch.',
        'branch name',
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'review-commit',
        'Review a specific commit.',
        'commit sha',
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'compact',
        'Summarize conversation context.',
        null,
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'goal',
        'Set or manage a long-running goal.',
        '[objective|clear|pause|resume]',
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'rename',
        'Rename the current session.',
        'new name',
        isDraftPreview: true,
      ),
      AcpSlashCommand(
        'logout',
        'Sign out of Codex.',
        null,
        isDraftPreview: true,
      ),
    ];
  }

  AcpUsage? usage;
  AcpAccountInfo? account;
  final List<Object?> _earlyAccountUpdates = [];
  void _receiveAccount(Object? params) {
    if (_disposed) return;
    if (!_initialized) {
      if (_earlyAccountUpdates.length < 4) _earlyAccountUpdates.add(params);
      return;
    }
    if (!agentCapabilities.meta.containsKey('authStatus')) return;
    final value = AcpAccountInfo.fromNotification(params);
    if (value == null) return;
    account = value;
    _eventController.add(ACPAccountEvent(value));
  }

  /// Capability discovery for drafts must never create a session.
  Future<void> initializeOnly() => _ensureConnection();
  String get diagnostics => LogSanitizer.sanitize(
    [
      'target: ${profile.executionTarget} ${profile.containerReference ?? ""}',
      'server: ${profile.serverId}',
      'command: ${profile.acpCommand ?? ""}',
      'user: ${profile.containerUser ?? "default"}',
      'cwd: $workingDirectory',
      if (_lastFailedOperation != null)
        'failed operation: $_lastFailedOperation',
      'agent: ${agentInfo?.name ?? "unknown"} ${agentInfo?.version ?? ""}',
      'capabilities: ${agentCapabilities.toJson()}',
      if (transport is AcpSshTransport)
        'exit: ${(transport as AcpSshTransport).exitCode ?? "running/unknown"}\n${(transport as AcpSshTransport).diagnosticTail}',
    ].join('\n'),
  );

  /// 由 agent 在 `initialize` 响应中声明的认证方式。
  List<AcpAuthMethod> _authMethods = const [];

  /// 用户已选择、待在下一次建会话前执行的认证方式。
  String? _pendingAuthMethodId;

  /// 本轮连接是否已成功完成 `authenticate`。
  bool _authenticated = false;

  /// 当前会话 id；建立成功后即有值。
  String? get sessionId => _sessionId;

  /// Establishes the remote session without sending a prompt.
  /// Used immediately before the first prompt to apply advertised settings.
  Future<void> prepareSession() async {
    try {
      await _ensureSession();
    } catch (error) {
      if (_isAuthRequired(error)) _emitAuthRequired();
      _lastFailedOperation = _sessionOperation ?? 'session/prepare';
      if (error is RpcError && error.code == -32603) {
        throw StateError(
          'ACP_SESSION_PREPARE_FAILED: $_lastFailedOperation: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
      rethrow;
    }
  }

  /// 本次 `_ensureSession` 是否复用了已有会话（而非新建）。
  ///
  /// 上层据此决定是否提示「上下文可能已丢失」。
  bool get restoredExistingSession => _restoredExistingSession;
  bool _restoredExistingSession = false;

  /// 建立 ACP 连接并完成 initialize + session/new（或 session/load/resume）。
  Future<void> _ensureSession() {
    if (_disposed) return Future.error(StateError(disconnectedCode));
    return _preparing ??= _prepareSession().whenComplete(
      () => _preparing = null,
    );
  }

  Future<void> _prepareSession() async {
    if (_sessionId != null &&
        (_pendingAuthMethodId == null || _authenticated)) {
      return;
    }

    await _ensureConnection();
    final connection = _connection!;
    if (captureReplay && !agentCapabilities.loadSession) {
      throw StateError('ACP_HISTORY_REPLAY_UNSUPPORTED');
    }
    final pending = _pendingAuthMethodId;
    if (pending != null && !_authenticated) {
      await connection.client.authenticate(
        AuthenticateRequest(methodId: pending),
        timeout: requestTimeout,
      );
      _authenticated = true;
    }
    if (_sessionId != null) return;
    final result = await _establishSession(connection);
    if (_disposed) throw StateError(disconnectedCode);
    _sessionId = result.$1;
    _configOptions = result.$2;
    _modes = result.$3;
    onSessionEstablished?.call(_sessionId!);
    _eventController.add(ACPSettingsChangedEvent());
  }

  Future<void> _ensureConnection() {
    if (_disposed) return Future.error(StateError(disconnectedCode));
    return _initializing ??= _initializeConnection().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initializeConnection() async {
    if (_initialized) return;

    final role = ClientRole()
      ..onSessionUpdate((_, notification) {
        final expected = _sessionId ?? resumeSessionId;
        if (expected == null || notification.sessionId == expected) {
          _handleUpdate(notification.update);
        }
      })
      ..onRequestPermission(_handlePermission);

    final connection = _connection ?? role.connect(transport);
    _connection = connection;
    connection.connection.onNotification(
      '_auth/status_update',
      _receiveAccount,
    );

    if (!_initialized) {
      final init = await connection.client.initialize(
        const InitializeRequest(
          protocolVersion: ProtocolVersion.v1,
          clientInfo: Implementation(name: 'Valhalla', version: '1.0.0'),
          clientCapabilities: ClientCapabilities(
            session: ClientSessionCapabilities(
              configOptions: SessionConfigOptionsCapabilities(
                boolean: BooleanConfigOptionCapabilities(),
              ),
            ),
          ),
        ),
        timeout: requestTimeout,
      );

      // agent 在此声明它支持的认证方式；原先被丢弃，导致认证要求无从满足。
      _authMethods = init.authMethods
          .map(_toAuthMethod)
          .toList(growable: false);
      agentCapabilities = init.agentCapabilities ?? const AgentCapabilities();
      agentInfo = init.agentInfo;
      _initialized = true;
      for (final pending in _earlyAccountUpdates) {
        _receiveAccount(pending);
      }
      _earlyAccountUpdates.clear();
    }
  }

  /// 有远端 ID 时只恢复：load 不支持才尝试 resume，均不支持则要求用户处理。
  /// 不静默用新会话替换已有上下文；只有无远端 ID 的草稿才 new。
  Future<(String, List<SessionConfigOption>, SessionModeState?)>
  _establishSession(ClientConnection connection) async {
    final existingId = resumeSessionId;

    if (existingId != null && existingId.isNotEmpty) {
      var resumeUnavailable = false;
      if (!captureReplay &&
          agentCapabilities.sessionCapabilities?.resume != null) {
        try {
          _sessionOperation = 'session/resume';
          final session = await connection.client.resumeSession(
            ResumeSessionRequest(sessionId: existingId, cwd: workingDirectory),
            timeout: requestTimeout,
          );
          _restoredExistingSession = true;
          return (existingId, session.configOptions, session.modes);
        } catch (error) {
          if (error is! RpcError || error.code != -32601) rethrow;
          resumeUnavailable = true;
        }
      }
      // session/load：agent 回放完整历史。
      try {
        _sessionOperation = 'session/load';
        final session = await connection.client.loadSession(
          LoadSessionRequest(sessionId: existingId, cwd: workingDirectory),
          timeout: requestTimeout,
        );
        _restoredExistingSession = true;
        return (existingId, session.configOptions, session.modes);
      } catch (error) {
        if (error is! RpcError || error.code != -32601) rethrow;
      }

      // session/resume：轻量恢复，不回放历史。
      if (resumeUnavailable) throw StateError('ACP_SESSION_RESTART_REQUIRED');
      try {
        _sessionOperation = 'session/resume';
        final session = await connection.client.resumeSession(
          ResumeSessionRequest(sessionId: existingId, cwd: workingDirectory),
          timeout: requestTimeout,
        );
        _restoredExistingSession = true;
        return (existingId, session.configOptions, session.modes);
      } catch (error) {
        if (error is! RpcError || error.code != -32601) rethrow;
        throw StateError('ACP_SESSION_RESTART_REQUIRED');
      }
    }

    _restoredExistingSession = false;
    _sessionOperation = 'session/new';
    final session = await connection.client.newSession(
      NewSessionRequest(cwd: workingDirectory),
      timeout: requestTimeout,
    );
    return (session.sessionId, session.configOptions, session.modes);
  }

  /// 发送 Prompt 并通过 [eventStream] 流式返回结果。
  Future<void> sendPrompt(
    String prompt, {
    List<AcpPromptAttachment> attachments = const [],
  }) async {
    if (_disposed) return;
    _completed = false;
    _tools.clear();

    final validation = _validateCommand(profile.acpCommand);
    if (validation != null) {
      _emitError(validation);
      _complete();
      return;
    }

    var stage = 'session/prepare';
    try {
      if (attachments
                  .where((a) => a.isImage)
                  .fold<int>(0, (n, a) => n + a.bytes.length) >
              AcpPromptAttachment.maxImageBytes ||
          attachments
                  .where((a) => !a.isImage)
                  .fold<int>(0, (n, a) => n + a.bytes.length) >
              AcpPromptAttachment.maxTextBytes) {
        throw StateError('ACP_ATTACHMENT_TOO_LARGE');
      }
      await _ensureSession();
      if ((attachments.any((a) => a.isImage) &&
              agentCapabilities.promptCapabilities?.image != true) ||
          (attachments.any((a) => !a.isImage) &&
              agentCapabilities.promptCapabilities?.embeddedContext != true)) {
        throw StateError('ACP_ATTACHMENT_UNSUPPORTED');
      }
      final blocks = attachments.isEmpty
          ? <ContentBlock>[TextContentBlock(text: prompt)]
          : await Isolate.run(
              () => <ContentBlock>[
                TextContentBlock(text: prompt),
                for (final attachment in attachments)
                  if (attachment.isImage)
                    ImageContent(
                      data: base64Encode(attachment.bytes),
                      mimeType: attachment.mimeType,
                    )
                  else
                    EmbeddedResource(
                      resource: TextResourceContents(
                        uri:
                            attachment.uri ??
                            Uri(
                              scheme: 'file',
                              path: '/attachments/${attachment.name}',
                            ).toString(),
                        text: utf8.decode(attachment.bytes),
                        mimeType: attachment.mimeType,
                      ),
                    ),
              ],
            );
      _acceptContent = true;
      stage = 'session/prompt';
      _idleFailure = Completer<PromptResponse>();
      _resetIdleTimer();
      final result = await Future.any<PromptResponse>([
        _connection!.client.prompt(
          PromptRequest(sessionId: _sessionId!, prompt: blocks),
        ),
        _idleFailure!.future,
      ]);
      await Future<void>.delayed(Duration.zero);
      _handleStopReason(result.stopReason);
      _complete();
    } catch (e) {
      if (_isAuthRequired(e)) {
        // 认证要求是可恢复的协议态，交由 UI 引导用户选择方式，而非报错终止。
        _emitAuthRequired();
      } else if (e is TimeoutException) {
        _emitError('ACP_IDLE_TIMEOUT ($stage)');
        cancelPrompt();
        _complete();
        dispose();
      } else if (e is RpcError) {
        final detail = e.data == null ? '' : ' — ${e.data}';
        _emitError('ACP_REMOTE_ERROR ($stage): $e$detail');
      } else {
        _emitError('$transportFailureCode: $e');
      }
      _complete();
    } finally {
      _acceptContent = false;
      _idleTimer?.cancel();
      _idleFailure = null;
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_acceptContent ||
        _waitingPermissions > 0 ||
        _disposed ||
        _inBackground) {
      return;
    }
    _idleTimer = Timer(requestTimeout, () {
      final pending = _idleFailure;
      if (!_inBackground && pending != null && !pending.isCompleted) {
        pending.completeError(TimeoutException('ACP_IDLE_TIMEOUT'));
      }
    });
  }

  void cancelPrompt() {
    if (!_disposed && _sessionId != null) {
      _connection?.client.cancel(_sessionId!);
    }
  }

  Future<ListSessionsResponse> listRemoteSessions(
    ListSessionsRequest request,
  ) async {
    await _ensureConnection();
    if (agentCapabilities.sessionCapabilities?.list == null) {
      throw StateError('ACP_REMOTE_HISTORY_UNSUPPORTED');
    }
    return _connection!.client.listSessions(request, timeout: requestTimeout);
  }

  List<SessionConfigOption> get configOptions =>
      List.unmodifiable(_configOptions);
  SessionModeState? get modes => _modes;

  Future<List<SessionConfigOption>> setConfigOption(
    SetSessionConfigOptionRequest request,
  ) async {
    await _ensureSession();
    if (request.sessionId != _sessionId) {
      throw StateError('ACP_SESSION_IDENTITY_MISMATCH');
    }
    final SetSessionConfigOptionResponse result;
    try {
      result = await _connection!.client.setSessionConfigOption(
        request,
        timeout: requestTimeout,
      );
    } catch (error) {
      _lastFailedOperation = 'session/set_config_option ${request.configId}';
      if (error is RpcError && error.code == -32603) {
        throw StateError(
          'ACP_SETTING_APPLY_FAILED: ${request.configId}: ${LogSanitizer.sanitize(error.toString())}',
        );
      }
      rethrow;
    }
    _configOptions = result.configOptions;
    if (!_disposed) _eventController.add(ACPSettingsChangedEvent());
    return _configOptions;
  }

  Future<void> setMode(String modeId) async {
    await _ensureSession();
    await _connection!.client.setSessionMode(
      SetSessionModeRequest(sessionId: _sessionId!, modeId: modeId),
      timeout: requestTimeout,
    );
    _modes = SessionModeState(
      currentModeId: modeId,
      availableModes: _modes?.availableModes ?? const [],
    );
    if (!_disposed) _eventController.add(ACPSettingsChangedEvent());
  }

  /// 记录认证方式；下一次准备时完成认证并保留已经建立的会话。
  ///
  /// 下一次 [sendPrompt] 会在 `initialize` 之后、建会话之前执行
  /// `authenticate`，避免复用半认证的连接。
  Future<void> authenticate(String methodId) async {
    if (_pendingAuthMethodId == methodId && _authenticated) return;
    _pendingAuthMethodId = methodId;
    _authenticated = false;
  }

  /// 判定异常是否为 agent 的认证要求（`RpcError(-32000)`）。
  bool _isAuthRequired(Object error) {
    if (error is RpcError) {
      return error.code == ErrorCode.authRequired.code;
    }
    // 兜底：异常被上游包装成普通 Exception 时，仍按协议错误码识别。
    return error.toString().contains(
      'RpcError(${ErrorCode.authRequired.code})',
    );
  }

  /// 返回 null 表示命令可用；否则返回稳定错误码。
  ///
  /// 命令为 null 表示该 Agent 无 ACP 模式，与空命令同样按缺失处理。
  String? _validateCommand(String? command) {
    try {
      AgentCommandValidator.validate(command ?? '');
      return null;
    } on ValidationException catch (e) {
      return e.details == 'CMD_EMPTY'
          ? missingAcpCommandCode
          : '$invalidAcpCommandCode: ${e.details}';
    }
  }

  Future<RequestPermissionResponse> _handlePermission(
    ClientContext context,
    RequestPermissionRequest params,
    RequestCancellation cancellation,
  ) async {
    if (_disposed ||
        (!_acceptContent && !captureReplay) ||
        params.sessionId != (_sessionId ?? resumeSessionId)) {
      return const _PermissionWireResponse(outcome: PermissionCancelled());
    }
    final completer = Completer<String?>();
    _waitingPermissions++;
    _idleTimer?.cancel();
    _eventController.add(
      ACPPermissionRequestEvent(
        request: PermissionRequest(
          id: params.toolCall.toolCallId,
          toolName: params.toolCall.title ?? 'tool',
          command: _toolCommand(params.toolCall),
          description: params.toolCall.title ?? '',
          options: params.options
              .map(
                (option) => ChatPermissionOption(
                  id: option.optionId,
                  name: option.name,
                  kind: option.kind.toJson(),
                ),
              )
              .toList(growable: false),
          isDangerous:
              params.toolCall.kind != ToolKind.read &&
              params.toolCall.kind != ToolKind.search,
        ),
        responseCompleter: completer,
      ),
    );

    final selectedId = await Future.any<String?>([
      completer.future,
      cancellation.whenCancelled.then((_) => null),
      _disposedSignal.future.then((_) => null),
    ]);
    _waitingPermissions--;
    _resetIdleTimer();
    if (selectedId == null) {
      return const _PermissionWireResponse(outcome: PermissionCancelled());
    }
    final option = params.options
        .where((option) => option.optionId == selectedId)
        .firstOrNull;
    if (option == null) {
      return const _PermissionWireResponse(outcome: PermissionCancelled());
    }
    return _PermissionWireResponse(
      outcome: PermissionSelected(optionId: option.optionId),
    );
  }

  void _handleUpdate(SessionUpdate update) {
    if (_disposed) return;
    _resetIdleTimer();
    if (update is AvailableCommandsSessionUpdate) {
      _commandsReceived = true;
      commands = update.update.availableCommands
          .map(
            (command) => AcpSlashCommand(
              command.name,
              command.description,
              command.input?.hint,
            ),
          )
          .toList();
      _eventController.add(ACPCommandsChangedEvent(commands));
    } else if (update is UsageSessionUpdate) {
      usage = AcpUsage(
        used: update.used ?? usage?.used,
        size: update.size ?? usage?.size,
        cost: update.cost?.amount ?? usage?.cost,
        currency: update.cost?.currency ?? usage?.currency,
      );
      _eventController.add(ACPUsageEvent(usage!));
    }
    if (update is ConfigOptionSessionUpdate) {
      _configOptions = update.configOptions;
      _eventController.add(ACPSettingsChangedEvent());
    } else if (update is CurrentModeSessionUpdate) {
      _modes = SessionModeState(
        currentModeId: update.currentModeId,
        availableModes: _modes?.availableModes ?? const [],
      );
      _eventController.add(ACPSettingsChangedEvent());
    }
    onSessionUpdate?.call(update);
    // session/load replays history; local history already owns those messages.
    if (!_acceptContent && !captureReplay) return;
    switch (update) {
      case UserMessageChunk(:final chunk):
        if (captureReplay) {
          _tools.clear();
          final text = _textOf(chunk);
          if (text.isNotEmpty || chunk.content is TextContentBlock) {
            _eventController.add(
              ACPUserContentChunkEvent(text, messageId: chunk.messageId),
            );
          } else {
            _eventController.add(
              ACPAttachmentEvent(
                MessageRole.user,
                chunk.messageId,
                chunk.content,
              ),
            );
          }
        }
      case AgentMessageChunk(:final chunk):
        final text = _textOf(chunk);
        if (text.isNotEmpty || chunk.content is TextContentBlock) {
          _eventController.add(
            ACPContentChunkEvent(text, messageId: chunk.messageId),
          );
        } else {
          _eventController.add(
            ACPAttachmentEvent(
              MessageRole.assistant,
              chunk.messageId,
              chunk.content,
            ),
          );
        }
      case AgentThoughtChunk(:final chunk):
        final text = _textOf(chunk);
        if (text.isNotEmpty) {
          _eventController.add(
            ACPThinkingChunkEvent(text, messageId: chunk.messageId),
          );
        }
      case PlanUpdate(:final plan):
        _eventController.add(
          ACPPlanUpdateEvent(plan.entries.map(_toPlanStep).toList()),
        );
      case ToolCallUpdateSession(:final toolCall):
        final tool = ToolExecution(
          id: toolCall.toolCallId,
          locations: toolCall.locations
              .map((location) => location.path)
              .toList(),
          name: toolCall.title,
          command: _rawOutput(toolCall.rawInput) ?? toolCall.title,
          status: _toToolStatus(toolCall.status),
          output:
              _rawOutput(toolCall.rawOutput) ?? _contentText(toolCall.content),
        );
        _tools[tool.id] = tool;
        _eventController.add(ACPToolExecutionEvent(tool));
      case ToolCallStatusUpdate(:final update):
        final previous = _tools[update.toolCallId];
        final tool = ToolExecution(
          id: update.toolCallId,
          locations:
              update.locations?.map((location) => location.path).toList() ??
              previous?.locations ??
              const [],
          name: update.title ?? previous?.name ?? update.toolCallId,
          command:
              _rawOutput(update.rawInput) ??
              previous?.command ??
              update.title ??
              '',
          status: update.status == null
              ? previous?.status ?? ToolExecutionStatus.pending
              : _toToolStatus(update.status),
          output:
              _rawOutput(update.rawOutput) ??
              (update.content == null
                  ? previous?.output
                  : _contentText(update.content)),
        );
        _tools[tool.id] = tool;
        _eventController.add(ACPToolExecutionEvent(tool));
      default:
        break;
    }
  }

  void _handleStopReason(StopReason reason) {
    if (reason != StopReason.endTurn) {
      _emitError('ACP_TURN_${reason.toJson().toUpperCase()}');
    }
  }

  void _emitError(String message) {
    if (_disposed || _eventController.isClosed) return;
    _eventController.add(ACPErrorEvent(LogSanitizer.sanitize(message)));
  }

  void _emitAuthRequired() {
    if (_disposed || _eventController.isClosed) return;
    _authenticated = false;
    _eventController.add(ACPAuthRequiredEvent(_authMethods));
  }

  void _complete() {
    if (_disposed || _eventController.isClosed) return;
    if (_completed) return;
    _completed = true;
    _eventController.add(ACPCompleteEvent());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _idleTimer?.cancel();
    _disposedSignal.complete();
    // Give cancelled permission handlers a chance to serialize their replies
    // before tearing down the RPC transport (microtasks precede this event).
    unawaited(
      Future<void>(() async {
        await _connection?.close();
      }),
    );
    _authMethods = const [];
    _pendingAuthMethodId = null;
    _authenticated = false;
    _eventController.close();
  }
}

/// 把 acpd 的 [AuthMethod] 映射为基础设施层契约。
///
/// 目前协议只定义 `agent` 一种变体；对未知变体退化为「仅保留 id」，
/// 保证 UI 永远不会拿到空名称。
AcpAuthMethod _toAuthMethod(AuthMethod method) {
  if (method is AgentAuthMethod) {
    return AcpAuthMethod(
      id: method.agent.id,
      name: method.agent.name,
      description: method.agent.description,
    );
  }
  return AcpAuthMethod(id: method.id, name: method.id);
}

String _textOf(ContentChunk chunk) {
  final content = chunk.content;
  return content is TextContentBlock ? content.text : '';
}

/// 从 tool call 的原始输入中提取可展示的命令文本。
String? _rawOutput(Object? raw) {
  if (raw == null) return null;
  if (raw is String) return raw;
  return raw.toString();
}

String _toolCommand(ToolCallUpdate update) {
  final raw = update.rawInput;
  if (raw is String) return raw;
  if (raw is Map) {
    final command = raw['command'] ?? raw['cmd'];
    if (command != null) return command.toString();
  }
  return _contentText(update.content) ?? update.title ?? update.toolCallId;
}

/// Concatenates the text of any embedded content blocks in a tool-call update.
String? _contentText(List<ToolCallContent>? contents) {
  if (contents == null || contents.isEmpty) return null;
  final buffer = StringBuffer();
  for (final entry in contents) {
    if (entry is ToolCallContentBlock) {
      final block = entry.content;
      if (block is TextContentBlock) buffer.write(block.text);
    } else if (entry is ToolCallDiff) {
      buffer.write('--- ${entry.path}\n+++ ${entry.path}\n');
      for (final line in (entry.oldText ?? '').split('\n')) {
        buffer.writeln('-$line');
      }
      for (final line in entry.newText.split('\n')) {
        buffer.writeln('+$line');
      }
    } else if (entry is ToolCallTerminal) {
      buffer.writeln('terminal: ${entry.terminalId}');
    }
  }
  final text = buffer.toString();
  return text.isEmpty ? null : text;
}

final class _PermissionWireResponse extends RequestPermissionResponse {
  const _PermissionWireResponse({required super.outcome});
  @override
  Map<String, Object?> toJson() => {'outcome': outcome.toJson()};
}

PlanStepStatus _toPlanStepStatus(PlanEntryStatus status) => switch (status) {
  PlanEntryStatus.pending => PlanStepStatus.pending,
  PlanEntryStatus.inProgress => PlanStepStatus.inProgress,
  PlanEntryStatus.completed => PlanStepStatus.completed,
};

ToolExecutionStatus _toToolStatus(ToolCallStatus? status) => switch (status) {
  ToolCallStatus.pending => ToolExecutionStatus.pending,
  ToolCallStatus.inProgress => ToolExecutionStatus.running,
  ToolCallStatus.completed => ToolExecutionStatus.completed,
  ToolCallStatus.failed => ToolExecutionStatus.failed,
  null => ToolExecutionStatus.pending,
};

PlanStep _toPlanStep(PlanEntry entry) => PlanStep(
  id: entry.content,
  title: entry.content,
  status: _toPlanStepStatus(entry.status),
);
