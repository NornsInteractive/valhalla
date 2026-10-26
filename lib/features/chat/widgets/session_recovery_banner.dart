import 'package:flutter/material.dart';

import '../../../data/models/session_recovery_status.dart';

/// 旧的会话恢复横幅入口（已收拢到顶栏，本组件保留为兼容占位）。
class SessionRecoveryBanner extends StatelessWidget {
  const SessionRecoveryBanner({
    super.key,
    required this.status,
    required this.onRetry,
  });

  final SessionRecoveryStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
