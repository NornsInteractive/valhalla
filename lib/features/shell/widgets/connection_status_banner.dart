import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/cli_chat_provider.dart';
import '../../../core/providers/reconnect_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/sftp_provider.dart';
import '../../../core/utils/reconnect_backoff.dart';
import '../../../core/utils/session_recovery_summary.dart';
import '../../../l10n/app_localizations.dart';
import '../../agents/agent_management_view.dart';
import '../../docker/docker_provider.dart';
import '../../settings/widgets/diagnostics_view.dart';
import '../../system/system_provider.dart';
import '../../../core/providers/agent_update_provider.dart';

enum ManualConnectionNoticeType { success, failure }

class ManualConnectionNotice {
  final String message;
  final ManualConnectionNoticeType type;
  final Key? key;

  const ManualConnectionNotice({
    required this.message,
    this.type = ManualConnectionNoticeType.success,
    this.key,
  });

  bool get isSuccess => type == ManualConnectionNoticeType.success;
}

class ConnectionStatusBanner extends ConsumerStatefulWidget {
  final SessionRecoveryMode? mode;
  final ManualConnectionNotice? manualNotice;
  final VoidCallback? onDismissManualNotice;

  const ConnectionStatusBanner({
    super.key,
    this.mode,
    this.manualNotice,
    this.onDismissManualNotice,
  });

  @override
  ConsumerState<ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState
    extends ConsumerState<ConnectionStatusBanner> {
  Timer? _pollTimer;
  Timer? _reconnectedTimer;
  bool _showReconnected = false;
  ReconnectStatus? _lastStatus;
  ReconnectController? _hookedController;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    // 1 秒轮询是兜底：倒计时需要每秒刷新，而控制器本身不会为
    // 「还剩几秒」发通知。
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _pollControllerState();
      }
    });
  }

  void _pollControllerState() {
    final controller = ref.read(reconnectControllerProvider);
    if (controller == null) return;
    _updateStatusTransition(controller.state);
    setState(() {});
  }

  void _hookController(ReconnectController? controller) {
    if (identical(_hookedController, controller)) return;

    _unsubscribe?.call();
    _unsubscribe = null;
    _hookedController = controller;

    if (controller != null) {
      // 订阅而不是覆盖 onStateChanged：覆盖会把其他消费者（或未来
      // 加入的消费者）的通知吞掉，且卸载时容易把旧值写回去。
      _unsubscribe = controller.addStateListener((nextState) {
        if (!mounted) return;
        _updateStatusTransition(nextState);
        setState(() {});
      });
    }
  }

  void _updateStatusTransition(ReconnectState state) {
    if (_lastStatus == ReconnectStatus.reconnecting &&
        state.status == ReconnectStatus.connected) {
      _showReconnected = true;
      _reconnectedTimer?.cancel();
      _reconnectedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showReconnected = false;
          });
        }
      });
    }
    _lastStatus = state.status;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _reconnectedTimer?.cancel();
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(reconnectControllerProvider);

    // 必须在 null 提前返回之前先解除旧订阅：否则控制器从「有」变「无」时
    // 旧订阅会一直挂在那个已经不该被界面读取的控制器上。
    _hookController(controller);

    final l10n = AppLocalizations.of(context);

    // 1. Controller-dependent connection states
    if (controller != null) {
      final state = controller.state;
      _updateStatusTransition(state);

      // 1.1 Reconnecting
      if (state.status == ReconnectStatus.reconnecting) {
        return _banner(
          context,
          key: const Key('reconnectingBanner'),
          color: context.vWarning,
          leading: Icon(Icons.sync, size: 18, color: context.vWarning),
          message: l10n.sshStatusReconnecting(state.attempt),
          trailing: state.nextDelay != null
              ? _BannerCountdown(
                  key: ValueKey(
                    'countdown_${state.attempt}_${state.nextDelay!.inSeconds}',
                  ),
                  initialDelay: state.nextDelay!,
                )
              : null,
        );
      }

      // 1.2 Just recovered to connected (transient, ~2 seconds)
      if (_showReconnected) {
        return _banner(
          context,
          key: const Key('reconnectedBanner'),
          color: context.vSuccess,
          leading: Icon(
            Icons.check_circle_outline,
            size: 18,
            color: context.vSuccess,
          ),
          message: l10n.sshStatusReconnected,
        );
      }

      // 1.3 Not retryable (Host key changed)
      if (!state.retryable) {
        return _banner(
          context,
          key: const Key('hostKeyChangedBanner'),
          color: context.vDanger,
          leading: Icon(
            Icons.gpp_bad_outlined,
            size: 18,
            color: context.vDanger,
          ),
          message: l10n.sshStatusHostKeyChanged,
        );
      }

      // 1.4 User intent is false (User disconnected)
      //
      // 必须用 hasEverStarted 而不是只看 userIntent：未 start 过的控制器同样是
      // userIntent == false 且 status == idle，但那表示「还没连过」，不是
      // 「用户主动断开」。少了这个判断，冷启动第一帧就会挂一条「已断开」，
      // 用户什么都没做却被告知断开。
      if (!controller.userIntent && controller.hasEverStarted) {
        return _banner(
          context,
          key: const Key('disconnectedManualBanner'),
          color: context.colorScheme.outline,
          leading: Icon(
            Icons.link_off,
            size: 18,
            color: context.colorScheme.outline,
          ),
          message: l10n.sshStatusDisconnectedManual,
        );
      }
    }

    // 5. Session recovery states (reconnecting / syncing / incomplete / failed)
    final aiRecovery = ref.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final cliRecovery = ref.watch(
      cliChatProvider.select((s) => s.recoveryStatus),
    );

    final recoveryEntries = sessionRecoveryEntries(
      acp: aiRecovery,
      cli: cliRecovery,
      preferredMode: widget.mode,
    );

    if (recoveryEntries.isNotEmpty) {
      final primary = recoveryEntries.first;
      final isAi = primary.mode == SessionRecoveryMode.acp;
      void handlePrimaryRetry() {
        if (isAi) {
          ref.read(aiChatProvider.notifier).recoverConnection();
        } else {
          ref.read(cliChatProvider.notifier).recoverConnection();
        }
      }

      if (primary.status == SessionRecoveryStatus.syncing ||
          primary.status == SessionRecoveryStatus.reconnecting) {
        return _banner(
          context,
          key: const Key('sessionRecoverySyncingBanner'),
          color: context.colorScheme.primary,
          leading: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colorScheme.primary,
              ),
            ),
          ),
          message: primary.status == SessionRecoveryStatus.reconnecting
              ? l10n.sessionRecoveryReconnecting
              : l10n.sessionRecoverySyncing,
        );
      }

      if (primary.status == SessionRecoveryStatus.incomplete) {
        return _banner(
          context,
          key: const Key('sessionRecoveryIncompleteBanner'),
          color: context.vWarning,
          leading: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: context.vWarning,
          ),
          message: l10n.sessionRecoveryIncomplete,
          trailing: TextButton(
            key: const Key('sessionRecoveryRetryButton'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.vWarning,
            ),
            onPressed: handlePrimaryRetry,
            child: Text(
              l10n.sessionRecoveryRetry,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        );
      }

      if (primary.status == SessionRecoveryStatus.failed) {
        return _banner(
          context,
          key: const Key('sessionRecoveryFailedBanner'),
          color: context.vDanger,
          leading: Icon(Icons.error_outline, size: 16, color: context.vDanger),
          message: l10n.sessionRecoveryFailed,
          trailing: TextButton(
            key: const Key('sessionRecoveryRetryButton'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.vDanger,
            ),
            onPressed: handlePrimaryRetry,
            child: Text(
              l10n.sessionRecoveryRetry,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        );
      }
    }

    // 6. Transient manual connection notice (success / failure / catch)
    if (widget.manualNotice != null) {
      return _buildManualNoticeBanner(context, widget.manualNotice!);
    }

    // 7. ACP session restart / context loss detected
    final acpRestartDetected = ref.watch(
      aiChatProvider.select((s) => s.acpSessionRestartDetected),
    );
    if (acpRestartDetected) {
      return _banner(
        context,
        key: const Key('acpSessionRestartNotice'),
        color: context.vWarning,
        leading: Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: context.vWarning,
        ),
        message: l10n.acpSessionRestartNotice,
        trailing: IconButton(
          key: const Key('acknowledgeAcpSessionRestartBannerButton'),
          icon: Icon(Icons.close, size: 18, color: context.vWarning),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () =>
              ref.read(aiChatProvider.notifier).acknowledgeAcpSessionRestart(),
        ),
      );
    }

    // 7. Agent update notice banner (when no reconnecting/recovery banner is active)
    final noticeCount = ref.watch(
      agentUpdatesProvider.select((s) => s.noticeCount),
    );
    if (noticeCount > 0) {
      return _buildAgentUpdateNoticeBanner(context, noticeCount);
    }

    // 8. Otherwise, do not display
    return const SizedBox.shrink();
  }

  Widget _buildAgentUpdateNoticeBanner(BuildContext context, int noticeCount) {
    final l10n = AppLocalizations.of(context);
    return _banner(
      context,
      key: const Key('agentUpdateNoticeBanner'),
      color: context.colorScheme.primary,
      onTap: () {
        ref.read(agentUpdatesProvider.notifier).dismissUpdateNotice();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AgentManagementView()));
      },
      leading: Icon(
        Icons.system_update_alt_outlined,
        size: 18,
        color: context.colorScheme.primary,
      ),
      message: l10n.agentUpdateNotice(noticeCount),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const Key('viewAgentUpdateNoticeButton'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.colorScheme.primary,
            ),
            onPressed: () {
              ref.read(agentUpdatesProvider.notifier).dismissUpdateNotice();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgentManagementView()),
              );
            },
            child: Text(
              l10n.agentUpdateViewAction,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          IconButton(
            key: const Key('dismissAgentUpdateNoticeButton'),
            icon: Icon(
              Icons.close,
              size: 18,
              color: context.colorScheme.primary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () =>
                ref.read(agentUpdatesProvider.notifier).dismissUpdateNotice(),
          ),
        ],
      ),
    );
  }

  Widget _buildManualNoticeBanner(
    BuildContext context,
    ManualConnectionNotice notice,
  ) {
    final color = notice.isSuccess ? context.vSuccess : context.vDanger;
    return _banner(
      context,
      key:
          notice.key ??
          (notice.isSuccess
              ? const Key('manualConnectedBanner')
              : const Key('manualConnectionFailedBanner')),
      color: color,
      leading: Icon(
        notice.isSuccess ? Icons.check_circle_outline : Icons.error_outline,
        size: 18,
        color: color,
      ),
      message: notice.message,
      trailing: widget.onDismissManualNotice != null
          ? IconButton(
              key: const Key('dismissManualNoticeButton'),
              icon: Icon(Icons.close, size: 18, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: widget.onDismissManualNotice,
            )
          : null,
      onTap: notice.isSuccess
          ? widget.onDismissManualNotice
          : () => _showDetailsDialog(context),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    final l10n = context.l10n;

    showDialog<void>(
      context: context,
      builder: (ctx) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            FocusManager.instance.primaryFocus?.unfocus(
              disposition: UnfocusDisposition.scope,
            );
          }
        },
        child: Consumer(
          builder: (dialogCtx, ref, _) {
            final server = ref.watch(activeServerProvider);
            final serverConn = ref.watch(serverConnectionProvider);
            final controller = ref.watch(reconnectControllerProvider);

            final aiChat = ref.watch(aiChatProvider);
            final cliChat = ref.watch(cliChatProvider);
            final sftpCachedAt = ref.watch(
              sftpProvider.select((s) => s.cachedAt),
            );
            final dockerCachedAt = ref.watch(
              dockerProvider.select((s) => s.cachedAt),
            );
            final systemCachedAt = ref.watch(
              systemProvider.select((s) => s.cachedAt),
            );

            final aiRecovery = aiChat.recoveryStatus;
            final cliRecovery = cliChat.recoveryStatus;
            final acpRestartDetected = aiChat.acpSessionRestartDetected;

            final recoveryEntries = sessionRecoveryEntries(
              acp: aiRecovery,
              cli: cliRecovery,
              preferredMode: widget.mode,
            );

            final canRetryConnection =
                !serverConn.isConnected &&
                (controller == null || controller.state.retryable);

            final targetServerKey = server?.connectionKey;
            final targetAcpServerId = aiChat.activeAgentProfile?.serverId;
            final targetAcpAgentId = aiChat.activeAgentProfile?.id;
            final targetAcpSessionId = aiChat.activeSessionId;

            final targetCliServerId = cliChat.serverId;
            final targetCliAgentId = cliChat.activeAgent?.id;
            final targetCliSessionId = cliChat.activeSession?.id;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    serverConn.isConnected
                        ? Icons.check_circle
                        : Icons.cloud_off,
                    color: serverConn.isConnected
                        ? dialogCtx.vSuccess
                        : dialogCtx.vWarning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      server?.name ?? l10n.stateOffline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (server != null) ...[
                        Text(
                          '${l10n.serverHost}: ${server.host}:${server.port}',
                          style: dialogCtx.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        '${serverConn.isConnected ? l10n.serverConnected : l10n.serverOffline}'
                        '${controller != null && controller.state.status == ReconnectStatus.reconnecting ? " (${l10n.sshStatusReconnecting(controller.state.attempt)})" : ""}',
                        style: dialogCtx.textTheme.bodyMedium?.copyWith(
                          color: serverConn.isConnected
                              ? dialogCtx.vSuccess
                              : dialogCtx.vWarning,
                        ),
                      ),
                      if (recoveryEntries.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...recoveryEntries.map((entry) {
                          final isAcp = entry.mode == SessionRecoveryMode.acp;
                          final String title;
                          if (isAcp) {
                            title =
                                'ACP: ${aiChat.activeSession?.title ?? aiChat.activeAgentProfile?.name ?? "ACP"}';
                          } else {
                            title =
                                'CLI: ${cliChat.activeSession?.title ?? cliChat.activeAgent?.name ?? "CLI"}';
                          }
                          final canRetryEntry =
                              entry.status ==
                                  SessionRecoveryStatus.incomplete ||
                              entry.status == SessionRecoveryStatus.failed;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '$title (${_recoveryStatusText(entry.status, l10n)})',
                                  style: dialogCtx.textTheme.bodySmall
                                      ?.copyWith(
                                        color: dialogCtx
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                if (canRetryEntry)
                                  TextButton(
                                    key: Key(
                                      isAcp
                                          ? 'acpRecoveryRetryButton'
                                          : 'cliRecoveryRetryButton',
                                    ),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(44, 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () {
                                      final curServer = ref.read(
                                        activeServerProvider,
                                      );
                                      if (curServer?.connectionKey !=
                                          targetServerKey) {
                                        Navigator.of(dialogCtx).pop();
                                        return;
                                      }
                                      if (isAcp) {
                                        final curAcp = ref.read(aiChatProvider);
                                        if (curAcp
                                                    .activeAgentProfile
                                                    ?.serverId !=
                                                targetAcpServerId ||
                                            curAcp.activeAgentProfile?.id !=
                                                targetAcpAgentId ||
                                            curAcp.activeSessionId !=
                                                targetAcpSessionId) {
                                          Navigator.of(dialogCtx).pop();
                                          return;
                                        }
                                        ref
                                            .read(aiChatProvider.notifier)
                                            .recoverConnection();
                                      } else {
                                        final curCli = ref.read(
                                          cliChatProvider,
                                        );
                                        if (curCli.serverId !=
                                                targetCliServerId ||
                                            curCli.activeAgent?.id !=
                                                targetCliAgentId ||
                                            curCli.activeSession?.id !=
                                                targetCliSessionId) {
                                          Navigator.of(dialogCtx).pop();
                                          return;
                                        }
                                        ref
                                            .read(cliChatProvider.notifier)
                                            .recoverConnection();
                                      }
                                      Navigator.of(dialogCtx).pop();
                                    },
                                    child: Text(
                                      l10n.sessionRecoveryRetry,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (acpRestartDetected) ...[
                        const SizedBox(height: 10),
                        Container(
                          key: const Key('acpSessionRestartDetailsNotice'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: dialogCtx.vWarning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(VRadius.input),
                            border: Border.all(
                              color: dialogCtx.vWarning.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: dialogCtx.vWarning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.acpSessionRestartNotice,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dialogCtx.vWarning,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (sftpCachedAt != null ||
                          dockerCachedAt != null ||
                          systemCachedAt != null) ...[
                        const SizedBox(height: 8),
                        if (sftpCachedAt != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'SFTP: ${l10n.cachedDataNotice(_formatTime(sftpCachedAt))}',
                              style: dialogCtx.textTheme.bodySmall?.copyWith(
                                color: dialogCtx.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (dockerCachedAt != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Docker: ${l10n.cachedDataNotice(_formatTime(dockerCachedAt))}',
                              style: dialogCtx.textTheme.bodySmall?.copyWith(
                                color: dialogCtx.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (systemCachedAt != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'System: ${l10n.cachedDataNotice(_formatTime(systemCachedAt))}',
                              style: dialogCtx.textTheme.bodySmall?.copyWith(
                                color: dialogCtx.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (acpRestartDetected)
                  FilledButton(
                    key: const Key('acknowledgeAcpSessionRestartButton'),
                    onPressed: () {
                      final curAcp = ref.read(aiChatProvider);
                      if (curAcp.acpSessionRestartDetected) {
                        ref
                            .read(aiChatProvider.notifier)
                            .acknowledgeAcpSessionRestart();
                      }
                      Navigator.of(dialogCtx).pop();
                    },
                    child: Text(l10n.confirm),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    DiagnosticsView.show(context);
                  },
                  child: Text(l10n.viewDiagnostics),
                ),
                if (canRetryConnection)
                  FilledButton(
                    key: const Key('connectionDetailsRetryButton'),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      final curServer = ref.read(activeServerProvider);
                      final curConn = ref.read(serverConnectionProvider);
                      final curCtrl = ref.read(reconnectControllerProvider);
                      if (curServer?.connectionKey == targetServerKey &&
                          !curConn.isConnected &&
                          (curCtrl == null || curCtrl.state.retryable)) {
                        ref.read(serverConnectionProvider.notifier).connect();
                      }
                    },
                    child: Text(l10n.sessionRecoveryRetry),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        ),
      ),
    ).then((_) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    });
  }

  String _recoveryStatusText(
    SessionRecoveryStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case SessionRecoveryStatus.reconnecting:
        return l10n.sessionRecoveryReconnecting;
      case SessionRecoveryStatus.syncing:
        return l10n.sessionRecoverySyncing;
      case SessionRecoveryStatus.incomplete:
        return l10n.sessionRecoveryIncomplete;
      case SessionRecoveryStatus.failed:
        return l10n.sessionRecoveryFailed;
      case SessionRecoveryStatus.idle:
        return '';
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  /// 细长状态横幅: 语义色 12% 染色底 + 1px 描边 + VRadius.input 圆角,
  /// 浮层不透明 surface + elevation 3, 出现时做一次性 Entrance (fade + slide), 尊重"减少动态效果"。
  Widget _banner(
    BuildContext context, {
    required Key key,
    required Color color,
    required Widget leading,
    required String message,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Entrance(
      child: Material(
        color: context.colorScheme.surface,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(VRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(VRadius.input),
          onTap: onTap ?? () => _showDetailsDialog(context),
          child: Container(
            key: key,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final isNarrowOrLargeText =
                    constraints.maxWidth < 360 || textScale > 1.3;
                if (trailing != null && isNarrowOrLargeText) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          leading,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: trailing,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Flexible(fit: FlexFit.loose, child: trailing),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCountdown extends StatefulWidget {
  final Duration initialDelay;

  const _BannerCountdown({super.key, required this.initialDelay});

  @override
  State<_BannerCountdown> createState() => _BannerCountdownState();
}

class _BannerCountdownState extends State<_BannerCountdown> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialDelay.inSeconds;
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant _BannerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDelay != oldWidget.initialDelay) {
      _remainingSeconds = widget.initialDelay.inSeconds;
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    if (_remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          t.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();
    return Text(
      '(${_remainingSeconds}s)',
      style: monoTextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.vWarning,
      ),
    );
  }
}
