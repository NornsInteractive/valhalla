import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/reconnect_provider.dart';
import '../../../core/utils/reconnect_backoff.dart';
import '../../../l10n/app_localizations.dart';

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

    if (controller == null) {
      return const SizedBox.shrink();
    }

    final state = controller.state;
    _updateStatusTransition(state);

    final l10n = AppLocalizations.of(context);

    // 1. Reconnecting
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

    // 2. Just recovered to connected (transient, ~2 seconds)
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

    // 3. Not retryable (Host key changed)
    if (!state.retryable) {
      return _banner(
        context,
        key: const Key('hostKeyChangedBanner'),
        color: context.vDanger,
        leading: Icon(Icons.gpp_bad_outlined, size: 18, color: context.vDanger),
        message: l10n.sshStatusHostKeyChanged,
      );
    }

    // 4. User intent is false (User disconnected)
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

    // 5. Otherwise, do not display
    return const SizedBox.shrink();
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
  }) {
    return Entrance(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
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
