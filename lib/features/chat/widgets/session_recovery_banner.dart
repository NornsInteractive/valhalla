import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/session_recovery_status.dart';

/// 统一展示 ACP / CLI 会话恢复状态的轻量横幅。
///
/// 遵循 handoff 约定：
/// - idle 时不展示。
/// - reconnecting 时若既有 connection banner 已经在提示重连 (server is connecting)，则不重复堆叠；
///   若服务器处于 disconnected 状态（例如用户主动断开），则展示离线状态且不作重连承诺。
/// - syncing 展示同步输出与动画指示器。
/// - incomplete 提示部分输出无法恢复（如触发 ACP 500 条或 CLI 20 页边界），并提供「重试」动作。
/// - failed 提示恢复失败并提供「重试」动作。
class SessionRecoveryBanner extends ConsumerWidget {
  const SessionRecoveryBanner({
    super.key,
    required this.status,
    required this.onRetry,
  });

  final SessionRecoveryStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status == SessionRecoveryStatus.idle) {
      return const SizedBox.shrink();
    }

    final serverConn = ref.watch(serverConnectionProvider);
    final l10n = context.l10n;

    if (status == SessionRecoveryStatus.reconnecting) {
      // 1. 若全局连接正在重连中，既有 connection banner 已在展示倒计时/重连状态，抑制重复提示
      if (serverConn.isConnecting) {
        return const SizedBox.shrink();
      }

      // 2. 若用户主动断开或处于已断开状态，不再无限转圈承诺重连，而是展示离线状态
      if (serverConn.status == ConnectionStateEnum.disconnected) {
        return _buildBanner(
          context,
          key: const Key('sessionRecoveryOfflineBanner'),
          color: context.colorScheme.outline,
          leading: Icon(
            Icons.link_off,
            size: 16,
            color: context.colorScheme.outline,
          ),
          message: l10n.stateOffline,
        );
      }
    }

    switch (status) {
      case SessionRecoveryStatus.reconnecting:
        return _buildBanner(
          context,
          key: const Key('sessionRecoveryReconnectingBanner'),
          color: context.vWarning,
          leading: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(context.vWarning),
            ),
          ),
          message: l10n.sessionRecoveryReconnecting,
        );

      case SessionRecoveryStatus.syncing:
        return _buildBanner(
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

      case SessionRecoveryStatus.incomplete:
        return _buildBanner(
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
            onPressed: onRetry,
            child: Text(
              l10n.sessionRecoveryRetry,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        );

      case SessionRecoveryStatus.failed:
        return _buildBanner(
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
            onPressed: onRetry,
            child: Text(
              l10n.sessionRecoveryRetry,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        );

      case SessionRecoveryStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBanner(
    BuildContext context, {
    required Key key,
    required Color color,
    required Widget leading,
    required String message,
    Widget? trailing,
  }) {
    return Entrance(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.input),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
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
    );
  }
}
