import 'dart:async';

import 'package:acpd/acpd.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/security/agent_command_validator.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/chat_session.dart';

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
  ACPThinkingChunkEvent(this.chunk);
}

class ACPContentChunkEvent extends ACPEvent {
  final String chunk;
  ACPContentChunkEvent(this.chunk);
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
  final Completer<bool> responseCompleter;
  ACPPermissionRequestEvent({
    required this.request,
    required this.responseCompleter,
  });
}

class ACPCompleteEvent extends ACPEvent {}

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
  });

  final AgentProfile profile;
  final Transport transport;
  final String workingDirectory;
  final Duration requestTimeout;

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
      StreamController<ACPEvent>.broadcast();
  Stream<ACPEvent> get eventStream => _eventController.stream;

  ClientConnection? _connection;
  Session? _session;
  bool _disposed = false;
  final Completer<void> _disposedSignal = Completer<void>();
  bool _completed = false;

  /// 由 agent 在 `initialize` 响应中声明的认证方式。
  List<AcpAuthMethod> _authMethods = const [];

  /// 用户已选择、待在下一次建会话前执行的认证方式。
  String? _pendingAuthMethodId;

  /// 本轮连接是否已成功完成 `authenticate`。
  bool _authenticated = false;

  /// 当前会话 id；建立成功后即有值。
  String? get sessionId => _session?.sessionId;

  /// Establishes the remote session without sending a prompt.
  /// Used immediately before the first prompt to apply advertised settings.
  Future<void> prepareSession() => _ensureSession();

  /// 本次 `_ensureSession` 是否复用了已有会话（而非新建）。
  ///
  /// 上层据此决定是否提示「上下文可能已丢失」。
  bool get restoredExistingSession => _restoredExistingSession;
  bool _restoredExistingSession = false;

  /// 建立 ACP 连接并完成 initialize + session/new（或 session/load/resume）。
  Future<void> _ensureSession() async {
    if (_session != null) return;

    final role = ClientRole()
      ..onSessionUpdate((_, notification) => _handleUpdate(notification.update))
      ..onRequestPermission(_handlePermission);

    final connection = role.connect(transport);
    _connection = connection;

    final init = await connection.client.initialize(
      const InitializeRequest(
        protocolVersion: ProtocolVersion.v1,
        clientInfo: Implementation(name: 'Valhalla', version: '1.0.0'),
      ),
      timeout: requestTimeout,
    );

    // agent 在此声明它支持的认证方式；原先被丢弃，导致认证要求无从满足。
    _authMethods = init.authMethods.map(_toAuthMethod).toList(growable: false);

    // 用户已选过认证方式时，在建会话前先完成 authenticate。
    final pending = _pendingAuthMethodId;
    if (pending != null && !_authenticated) {
      await connection.client.authenticate(
        AuthenticateRequest(methodId: pending),
        timeout: requestTimeout,
      );
      _authenticated = true;
    }

    _session = await _establishSession(connection);
    final id = _session!.sessionId;
    onSessionEstablished?.call(id);
  }

  /// 按 load → resume → create 的顺序建立会话。
  ///
  /// 优先恢复已有会话，因为只有这样才能保住上下文；两者都失败时
  /// 才新建。降级顺序不能颠倒：先 create 会白白丢掉历史，
  /// 而这正是用户抱怨的「重连后内容没了」。
  Future<Session> _establishSession(ClientConnection connection) async {
    final existingId = resumeSessionId;

    if (existingId != null && existingId.isNotEmpty) {
      // session/load：agent 回放完整历史。
      try {
        final session = await Session.load(
          connection,
          LoadSessionRequest(sessionId: existingId, cwd: workingDirectory),
          timeout: requestTimeout,
        );
        _restoredExistingSession = true;
        return session;
      } catch (error) {
        if (error is! RpcError || error.code != -32601) rethrow;
      }

      // session/resume：轻量恢复，不回放历史。
      try {
        final session = await Session.resume(
          connection,
          ResumeSessionRequest(sessionId: existingId, cwd: workingDirectory),
          timeout: requestTimeout,
        );
        _restoredExistingSession = true;
        return session;
      } catch (error) {
        if (error is! RpcError || error.code != -32601) rethrow;
        throw StateError('ACP_SESSION_RESTART_REQUIRED');
      }
    }

    _restoredExistingSession = false;
    return Session.create(
      connection,
      NewSessionRequest(cwd: workingDirectory),
      timeout: requestTimeout,
    );
  }

  /// 发送 Prompt 并通过 [eventStream] 流式返回结果。
  Future<void> sendPrompt(String prompt) async {
    if (_disposed) return;
    _completed = false;

    final validation = _validateCommand(profile.acpCommand);
    if (validation != null) {
      _emitError(validation);
      _complete();
      return;
    }

    try {
      await _ensureSession();
      final session = _session!;
      final result = await session.sendPrompt([
        TextContentBlock(text: prompt),
      ], timeout: requestTimeout);
      _handleStopReason(result.stopReason);
      _complete();
    } catch (e) {
      if (_isAuthRequired(e)) {
        // 认证要求是可恢复的协议态，交由 UI 引导用户选择方式，而非报错终止。
        _emitAuthRequired();
      } else {
        _emitError('$transportFailureCode: $e');
      }
      _complete();
    }
  }

  void cancelPrompt() {
    if (!_disposed) _session?.cancel();
  }

  Future<ListSessionsResponse> listRemoteSessions(
    ListSessionsRequest request,
  ) async {
    await _ensureSession();
    return _connection!.client.listSessions(request, timeout: requestTimeout);
  }

  List<SessionConfigOption> get configOptions => List.unmodifiable(
    _session?.configOptions ?? const <SessionConfigOption>[],
  );

  Future<List<SessionConfigOption>> setConfigOption(
    SetSessionConfigOptionRequest request,
  ) async {
    await _ensureSession();
    return _session!.setConfigOption(request, timeout: requestTimeout);
  }

  Future<void> setMode(String modeId) async {
    await _ensureSession();
    await _session!.setMode(modeId, timeout: requestTimeout);
  }

  /// 记录用户选定的认证方式，并丢弃当前会话。
  ///
  /// 下一次 [sendPrompt] 会在 `initialize` 之后、建会话之前执行
  /// `authenticate`，避免复用半认证的连接。
  Future<void> authenticate(String methodId) async {
    _pendingAuthMethodId = methodId;
    _authenticated = false;
    _session?.dispose();
    _session = null;
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
    final completer = Completer<bool>();
    _eventController.add(
      ACPPermissionRequestEvent(
        request: PermissionRequest(
          id: params.toolCall.toolCallId,
          toolName: params.toolCall.title ?? 'tool',
          command: _toolCommand(params.toolCall),
          description: params.toolCall.title ?? '',
          isDangerous: _isDangerous(params.options),
        ),
        responseCompleter: completer,
      ),
    );

    final approved = await Future.any<bool?>([
      completer.future,
      cancellation.whenCancelled.then((_) => null),
      _disposedSignal.future.then((_) => null),
    ]);
    if (approved == null) {
      return const _PermissionWireResponse(outcome: PermissionCancelled());
    }
    final option = _selectOption(params.options, approved);
    if (option == null) {
      return const _PermissionWireResponse(outcome: PermissionCancelled());
    }
    return _PermissionWireResponse(
      outcome: PermissionSelected(optionId: option.optionId),
    );
  }

  void _handleUpdate(SessionUpdate update) {
    onSessionUpdate?.call(update);
    switch (update) {
      case AgentMessageChunk(:final chunk):
        final text = _textOf(chunk);
        if (text.isNotEmpty) {
          _eventController.add(ACPContentChunkEvent(text));
        }
      case AgentThoughtChunk(:final chunk):
        final text = _textOf(chunk);
        if (text.isNotEmpty) {
          _eventController.add(ACPThinkingChunkEvent(text));
        }
      case PlanUpdate(:final plan):
        _eventController.add(
          ACPPlanUpdateEvent(plan.entries.map(_toPlanStep).toList()),
        );
      case ToolCallUpdateSession(:final toolCall):
        _eventController.add(
          ACPToolExecutionEvent(
            ToolExecution(
              id: toolCall.toolCallId,
              name: toolCall.title,
              command:
                  _rawOutput(toolCall.rawInput) ??
                  _contentText(toolCall.content) ??
                  toolCall.title,
              status: _toToolStatus(toolCall.status),
              output:
                  _rawOutput(toolCall.rawOutput) ??
                  _contentText(toolCall.content),
            ),
          ),
        );
      case ToolCallStatusUpdate(:final update):
        _eventController.add(
          ACPToolExecutionEvent(
            ToolExecution(
              id: update.toolCallId,
              name: update.title ?? update.toolCallId,
              command:
                  _rawOutput(update.rawInput) ??
                  _contentText(update.content) ??
                  update.title ??
                  '',
              status: _toToolStatus(update.status),
              output:
                  _rawOutput(update.rawOutput) ?? _contentText(update.content),
            ),
          ),
        );
      default:
        break;
    }
  }

  void _handleStopReason(StopReason reason) {
    if (reason == StopReason.cancelled) {
      _eventController.add(ACPErrorEvent('ACP_TURN_CANCELLED'));
    }
  }

  void _emitError(String message) {
    if (_disposed || _eventController.isClosed) return;
    _eventController.add(ACPErrorEvent(message));
  }

  void _emitAuthRequired() {
    if (_disposed || _eventController.isClosed) return;
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
    _disposedSignal.complete();
    _session?.dispose();
    _connection?.close();
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
    }
  }
  final text = buffer.toString();
  return text.isEmpty ? null : text;
}

final class _PermissionWireResponse extends RequestPermissionResponse {
  const _PermissionWireResponse({required super.outcome});
  @override
  Map<String, Object?> toJson() => outcome.toJson();
}

bool _isDangerous(List<PermissionOption> options) {
  for (final option in options) {
    if (option.kind == PermissionOptionKind.allowOnce ||
        option.kind == PermissionOptionKind.allowAlways) {
      return true;
    }
  }
  return false;
}

PermissionOption? _selectOption(List<PermissionOption> options, bool approved) {
  PermissionOption? fallback;
  for (final option in options) {
    final isAllow =
        option.kind == PermissionOptionKind.allowOnce ||
        option.kind == PermissionOptionKind.allowAlways;
    if (isAllow == approved) {
      if (option.kind == PermissionOptionKind.allowOnce && approved) {
        return option;
      }
      if (option.kind == PermissionOptionKind.rejectOnce && !approved) {
        return option;
      }
      fallback ??= option;
    }
  }
  return fallback;
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
