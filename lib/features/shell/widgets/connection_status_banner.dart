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
import '../../../core/utils/reconnect_backoff.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/diagnostics_view.dart';

class ConnectionStatusBanner extends ConsumerStatefulWidget {
  const ConnectionStatusBanner({super.key});

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

    // 5. Session recovery states (syncing / incomplete / failed)
    final aiRecovery = ref.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final cliRecovery = ref.watch(
      cliChatProvider.select((s) => s.recoveryStatus),
    );

    final activeRecovery = (aiRecovery != SessionRecoveryStatus.idle)
        ? aiRecovery
        : cliRecovery;
    final isAiRecovery = (aiRecovery != SessionRecoveryStatus.idle);

    void handleRecoveryRetry() {
      if (isAiRecovery) {
        ref.read(aiChatProvider.notifier).recoverConnection();
      } else {
        ref.read(cliChatProvider.notifier).recoverConnection();
      }
    }

    if (activeRecovery == SessionRecoveryStatus.syncing) {
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
        message: l10n.sessionRecoverySyncing,
      );
    }

    if (activeRecovery == SessionRecoveryStatus.incomplete) {
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
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: context.vWarning,
          ),
          onPressed: handleRecoveryRetry,
          child: Text(
            l10n.sessionRecoveryRetry,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      );
    }

    if (activeRecovery == SessionRecoveryStatus.failed) {
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
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: context.vDanger,
          ),
          onPressed: handleRecoveryRetry,
          child: Text(
            l10n.sessionRecoveryRetry,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      );
    }

    // 6. ACP session restart / context loss detected
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

    // 7. Otherwise, do not display
    return const SizedBox.shrink();
  }

  void _showDetailsDialog(BuildContext context) {
    final server = ref.read(activeServerProvider);
    final serverConn = ref.read(serverConnectionProvider);
    final controller = ref.read(reconnectControllerProvider);

    final aiRecovery = ref.read(aiChatProvider).recoveryStatus;
    final cliRecovery = ref.read(cliChatProvider).recoveryStatus;
    final acpRestartDetected = ref
        .read(aiChatProvider)
        .acpSessionRestartDetected;

    final l10n = context.l10n;

    final isRecoveryActive =
        aiRecovery != SessionRecoveryStatus.idle ||
        cliRecovery != SessionRecoveryStatus.idle;
    final canRetry =
        aiRecovery == SessionRecoveryStatus.incomplete ||
        aiRecovery == SessionRecoveryStatus.failed ||
        cliRecovery == SessionRecoveryStatus.incomplete ||
        cliRecovery == SessionRecoveryStatus.failed ||
        (!serverConn.isConnected &&
            (controller == null || controller.state.retryable));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              serverConn.isConnected ? Icons.check_circle : Icons.cloud_off,
              color: serverConn.isConnected
                  ? context.vSuccess
                  : context.vWarning,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(server?.name ?? l10n.stateOffline),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (server != null) ...[
              Text(
                '${l10n.serverHost}: ${server.host}:${server.port}',
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '${serverConn.isConnected ? l10n.serverConnected : l10n.serverOffline}'
              '${controller != null && controller.state.status == ReconnectStatus.reconnecting ? " (${l10n.sshStatusReconnecting(controller.state.attempt)})" : ""}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: serverConn.isConnected
                    ? context.vSuccess
                    : context.vWarning,
              ),
            ),
            if (isRecoveryActive) ...[
              const SizedBox(height: 8),
              Text(
                aiRecovery != SessionRecoveryStatus.idle
                    ? 'ACP: ${_recoveryStatusText(aiRecovery, l10n)}'
                    : 'CLI: ${_recoveryStatusText(cliRecovery, l10n)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (acpRestartDetected) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('acpSessionRestartDetailsNotice'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.vWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VRadius.input),
                  border: Border.all(
                    color: context.vWarning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.vWarning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.acpSessionRestartNotice,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (acpRestartDetected)
            FilledButton(
              key: const Key('acknowledgeAcpSessionRestartButton'),
              onPressed: () {
                ref
                    .read(aiChatProvider.notifier)
                    .acknowledgeAcpSessionRestart();
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.confirm),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              DiagnosticsView.show(context);
            },
            child: Text(l10n.viewDiagnostics),
          ),
          if (canRetry)
            FilledButton(
              key: const Key('connectionDetailsRetryButton'),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (aiRecovery == SessionRecoveryStatus.incomplete ||
                    aiRecovery == SessionRecoveryStatus.failed) {
                  ref.read(aiChatProvider.notifier).recoverConnection();
                } else if (cliRecovery == SessionRecoveryStatus.incomplete ||
                    cliRecovery == SessionRecoveryStatus.failed) {
                  ref.read(cliChatProvider.notifier).recoverConnection();
                } else {
                  ref.read(serverConnectionProvider.notifier).connect();
                }
              },
              child: Text(l10n.sessionRecoveryRetry),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
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

  /// 细长状态横幅: 语义色 12% 染色底 + 1px 描边 + VRadius.input 圆角,
  /// 出现时做一次性 Entrance (fade + slide), 尊重"减少动态效果"。
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: Colors.transparent,
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
              child: Row(
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
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
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
