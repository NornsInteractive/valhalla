import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/session_recovery_status.dart';

/// 统一展示 ACP / CLI 会话恢复状态的轻量占位。
///
/// 状态提示已收拢至 shell 顶部的全局 [ConnectionStatusBanner]，
/// 避免在会话中重复堆叠横幅。
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
    return const SizedBox.shrink();
  }
}
