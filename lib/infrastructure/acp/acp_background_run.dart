import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/logging/sanitizer.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/chat_run_settings.dart';
import '../../data/models/chat_session.dart';
import 'acp_attachment_store.dart';
import 'acp_client_adapter.dart';

/// Owns a running turn after its transcript is no longer the selected view.
class AcpBackgroundRun {
  final String serverTargetKey;
  final AgentProfile profile;
  final OperationPermissionPolicy policy;
  final AcpAttachmentStore attachments;
  final Future<void> Function(ChatSession) save;
  final void Function() onChanged;
  final String turnId;
  ACPClientAdapter adapter;
  ChatSession session;
  String state = 'running';
  String? error;
  final List<ACPPermissionRequestEvent> permissions;
  final List<ACPEvent> _events = [];
  final Set<Future<void>> _attachments = {};
  StreamSubscription<ACPEvent>? _subscription;
  Timer? _batch;
  Timer? _checkpoint;
  Future<void> _writes = Future.value();
  bool _closed = false;

  AcpBackgroundRun({
    required this.serverTargetKey,
    required this.profile,
    required this.adapter,
    required this.session,
    required this.policy,
    required this.attachments,
    required this.save,
    required this.onChanged,
    required this.turnId,
    List<ACPPermissionRequestEvent> permissions = const [],
  }) : permissions = List.of(permissions);

  bool get isBusy => const {
    'running',
    'waiting_permission',
    'reconnecting',
    'awaiting_authentication',
  }.contains(state);

  bool get isAttached => !_closed && !adapter.isDisposed;
  ACPPermissionRequestEvent? get pendingPermission => permissions
      .where((event) => !event.responseCompleter.isCompleted)
      .firstOrNull;

  void listen() {
    _closed = false;
    _subscription = adapter.eventStream.listen(
      _accept,
      onError: (Object failure) {
        state = 'reconnecting';
        error = LogSanitizer.sanitize(failure.toString());
        onChanged();
      },
      onDone: () {
        if (!_closed && isBusy) {
          state = 'reconnecting';
          onChanged();
        }
      },
    );
    _checkpoint = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(
        checkpoint().catchError((Object failure) {
          error = LogSanitizer.sanitize(failure.toString());
          onChanged();
        }),
      );
    });
  }

  void _accept(ACPEvent event) {
    if (_closed ||
        (event.runtimeTurnId != null && event.runtimeTurnId != turnId)) {
      return;
    }
    // A fresh broker's session/load replay has no turn ID; it is not new output.
    if (adapter.isPersistent &&
        event.runtimeTurnId == null &&
        (event is ACPContentChunkEvent ||
            event is ACPThinkingChunkEvent ||
            event is ACPToolExecutionEvent ||
            event is ACPPlanUpdateEvent ||
            event is ACPAttachmentEvent)) {
      return;
    }
    if (event is ACPPermissionRequestEvent) {
      final allow =
          policy == OperationPermissionPolicy.autoAllowAll ||
          (policy == OperationPermissionPolicy.autoAllowSafe &&
              !event.request.isDangerous);
      final once = event.request.options
          .where((option) => option.kind == 'allow_once')
          .firstOrNull;
      if (allow && once != null) {
        event.responseCompleter.complete(once.id);
      } else if (!permissions.any(
        (pending) =>
            identical(pending.responseCompleter, event.responseCompleter),
      )) {
        permissions.add(event);
        state = 'waiting_permission';
      }
      onChanged();
      return;
    }
    _events.add(event);
    _batch ??= Timer(const Duration(milliseconds: 50), flush);
  }

  void flush() {
    _batch?.cancel();
    _batch = null;
    if (_events.isEmpty) {
      return;
    }
    final events = List<ACPEvent>.of(_events);
    _events.clear();
    final messages = List<ChatMessage>.of(session.messages);
    final content = <String, StringBuffer>{};
    final thinking = <String, StringBuffer>{};
    for (final event in events) {
      if (event is ACPPersistentStatusEvent && !event.settled) continue;
      var index = messages.lastIndexWhere(
        (message) =>
            message.role == MessageRole.assistant &&
            (message.runtimeTurnId == turnId || message.id == turnId),
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
        final found = messages.indexWhere(
          (item) =>
              item.runtimeTurnId == turnId && item.remoteMessageId == remoteId,
        );
        if (found >= 0) {
          index = found;
          message = messages[index];
        } else if (message.remoteMessageId != null &&
            message.remoteMessageId != remoteId) {
          messages[index] = message.copyWith(status: ChatTurnStatus.completed);
          message = ChatMessage(
            id: const Uuid().v4(),
            role: MessageRole.assistant,
            content: '',
            runtimeTurnId: turnId,
            remoteMessageId: remoteId,
            agentId: profile.id,
            status: ChatTurnStatus.streaming,
            createdAt: DateTime.now(),
          );
          messages.add(message);
          index = messages.length - 1;
        } else {
          message = message.copyWith(remoteMessageId: remoteId);
        }
      }
      if (event is ACPPersistentStatusEvent &&
          event.caughtUp &&
          event.runtimeTurnId == null) {
        if (const [
          ChatTurnStatus.streaming,
          ChatTurnStatus.unknown,
        ].contains(message.status)) {
          message = message.copyWith(
            status: ChatTurnStatus.interrupted,
            failureCode: 'ACP_RUNTIME_PROMPT_NOT_ACCEPTED',
          );
        }
        state = 'completed';
      } else if (event is ACPContentChunkEvent) {
        final buffer = content.putIfAbsent(
          message.id,
          () => StringBuffer(message.content),
        );
        final start = buffer.length;
        buffer.write(event.chunk);
        message = message.copyWith(
          status: ChatTurnStatus.streaming,
          contentBlocks: ChatContentBlock.appendText(
            message.contentBlocks,
            start,
            buffer.length,
          ),
        );
        state = 'running';
      } else if (event is ACPThinkingChunkEvent) {
        thinking
            .putIfAbsent(message.id, () => StringBuffer(message.thinking ?? ''))
            .write(event.chunk);
      } else if (event is ACPToolExecutionEvent) {
        final owner = messages.indexWhere(
          (item) =>
              item.runtimeTurnId == turnId &&
              item.toolExecutions.any(
                (tool) => tool.id == event.toolExecution.id,
              ),
        );
        if (owner >= 0) {
          index = owner;
          message = messages[index];
        }
        message = message.copyWith(
          toolExecutions: [
            ...message.toolExecutions.where(
              (tool) => tool.id != event.toolExecution.id,
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
      } else if (event is ACPAttachmentEvent &&
          event.role == MessageRole.assistant) {
        final messageId = message.id;
        late final Future<void> write;
        write = attachments
            .fromBlock(event.content)
            .then<void>((attachment) {
              final items = session.messages
                  .map(
                    (item) => item.id == messageId
                        ? item.copyWith(
                            attachments: [...item.attachments, attachment],
                          )
                        : item,
                  )
                  .toList();
              session = session.copyWith(messages: items);
              onChanged();
            })
            .catchError((Object failure) {
              error = LogSanitizer.sanitize(failure.toString());
              onChanged();
            })
            .whenComplete(() => _attachments.remove(write));
        _attachments.add(write);
      } else if (event is ACPCompleteEvent ||
          (event is ACPPersistentStatusEvent && event.status == 'completed')) {
        message = message.copyWith(
          status: ChatTurnStatus.completed,
          clearFailure: true,
        );
        state = 'completed';
      } else if (event is ACPErrorEvent ||
          (event is ACPPersistentStatusEvent &&
              const ['failed', 'exited'].contains(event.status))) {
        error = LogSanitizer.sanitize(
          event is ACPErrorEvent ? event.error : 'ACP_RUNTIME_AGENT_EXITED',
        );
        message = message.copyWith(
          status: ChatTurnStatus.failed,
          failureCode: error,
        );
        state = 'failed';
      } else if (event is ACPPersistentStatusEvent &&
          event.status == 'cancelled') {
        message = message.copyWith(
          status: ChatTurnStatus.interrupted,
          clearFailure: true,
        );
        state = 'cancelled';
      } else if (event is ACPAuthRequiredEvent) {
        message = message.copyWith(
          status: ChatTurnStatus.awaitingAuthentication,
          failureCode: ACPClientAdapter.authRequiredCode,
        );
        state = 'awaiting_authentication';
      } else if (event is ACPPersistentStatusEvent &&
          const ['running', 'waiting_permission'].contains(event.status)) {
        state = event.status;
      }
      messages[index] = message;
    }
    final count = session.messageOffset + messages.length;
    session = session.copyWith(
      updatedAt: DateTime.now(),
      totalMessageCount: count > session.totalMessageCount
          ? count
          : session.totalMessageCount,
      messages: [
        for (final message in messages)
          message.copyWith(
            content: content[message.id]?.toString(),
            thinking: thinking[message.id]?.toString(),
          ),
      ],
    );
    if (!isBusy) {
      for (final permission in permissions) {
        if (!permission.responseCompleter.isCompleted) {
          permission.responseCompleter.complete(null);
        }
      }
      permissions.clear();
      _checkpoint?.cancel();
      unawaited(
        checkpoint().catchError((Object failure) {
          error = LogSanitizer.sanitize(failure.toString());
          onChanged();
        }),
      );
    }
    if (isBusy && pendingPermission != null) state = 'waiting_permission';
    onChanged();
  }

  Future<void> checkpoint() async {
    flush();
    while (_attachments.isNotEmpty) {
      await Future.wait(_attachments.toList());
      flush();
    }
    final context = session.contextFor(profile.id);
    session = session.copyWith(
      agentContexts: {
        ...session.agentContexts,
        profile.id: context.copyWith(
          remoteSessionId: adapter.sessionId,
          persistentRuntimeKey: adapter.persistentRuntimeKey,
          runtimeCursor: adapter.runtimeCursor,
          syncedMessageCount: !isBusy && state == 'completed'
              ? session.messageOffset + session.messages.length
              : context.syncedMessageCount,
        ),
      },
    );
    final snapshot = session;
    final pending = _writes
        .catchError((Object _) {})
        .then((_) => save(snapshot));
    _writes = pending;
    await pending;
    onChanged();
  }

  void respondPermission(String? selection) {
    final pending = pendingPermission;
    if (pending == null) {
      return;
    }
    if (selection != null &&
        !pending.request.options.any((option) => option.id == selection)) {
      return;
    }
    pending.responseCompleter.complete(selection);
    permissions.remove(pending);
    state = pendingPermission == null ? 'running' : 'waiting_permission';
    onChanged();
  }

  Future<void> detach({
    bool cancelRemote = false,
    bool disposeAdapter = true,
  }) async {
    if (cancelRemote) {
      adapter.cancelPrompt();
      state = 'cancelled';
      session = session.copyWith(
        messages: session.messages
            .map(
              (message) =>
                  message.runtimeTurnId == turnId &&
                      const [
                        ChatTurnStatus.streaming,
                        ChatTurnStatus.unknown,
                      ].contains(message.status)
                  ? message.copyWith(status: ChatTurnStatus.interrupted)
                  : message,
            )
            .toList(),
      );
    }
    _closed = true;
    _checkpoint?.cancel();
    _batch?.cancel();
    await _subscription?.cancel();
    if (disposeAdapter) {
      adapter.dispose();
      // New attachments replay fresh permission handlers; old completers cannot approve them.
      permissions.clear();
    }
    await checkpoint();
  }

  Future<void> reattach(ACPClientAdapter replacement) async {
    await detach();
    adapter = replacement;
    state = 'reconnecting';
    listen();
    await adapter.prepareSession();
    flush();
    await checkpoint();
  }
}
