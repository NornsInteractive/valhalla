import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interactive_login_dialog.dart';

/// 弹出「交互式登录终端」的能力，抽成 provider 以便测试注入替身。
///
/// 定义在 `features/` 而非 `core/`：`core/` 不依赖 `features/`，保持分层方向。
typedef InteractiveLoginLauncher =
    Future<bool?> Function({
      required BuildContext context,
      required String agentName,
      required String command,
      required String serverName,
      required dynamic sshClient,
      String? remoteExecCommand,
    });

final interactiveLoginLauncherProvider = Provider<InteractiveLoginLauncher>(
  (ref) => showInteractiveLoginDialog,
);
