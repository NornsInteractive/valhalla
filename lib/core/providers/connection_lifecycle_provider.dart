import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/server_profile.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import 'reconnect_provider.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

/// 进程存活期间维持 SSH / ACP 连接的编排器。
///
/// 这个类只做「生命周期 → 连接层动作」的翻译，不自己实现重连策略
/// （那属于 [ReconnectController]），也不自己实现保活
/// （那属于 [KeepAliveCoordinator]）。分开的好处是这里的逻辑可以
/// 用假的协作者完整测试，而不必真的连一台服务器。
///
/// 三条规则，对应三个生命周期回调：
/// - `resumed`：立刻复验连接。不能等心跳定时器 —— 用户切回来的瞬间
///   看到的就是「界面显示已连接，但实际早就断了」。复验失败就触发重连。
/// - `paused`：确保前台服务在跑。进程被系统冻结后 Dart 侧的心跳会停，
///   只有前台服务能让进程活下来。
/// - `detached`：停止重连并停掉前台服务。此时进程即将结束，再重连毫无意义。
class ConnectionLifecycleCoordinator {
  ConnectionLifecycleCoordinator({
    required this.sshManager,
    required this.reconnectController,
    required this.keepAlive,
    required this.activeServer,
  });

  final SSHClientManager sshManager;

  /// null 表示自动重连未启用。
  final ReconnectController? reconnectController;

  final KeepAliveCoordinator keepAlive;

  /// 读取当前活跃服务器。
  final ServerProfile? Function() activeServer;

  /// 应用是否已经退到后台。
  ///
  /// 用于区分「用户切回来了」和「这些回调在测试里被孤立触发」。
  bool _inBackground = false;
  bool get inBackground => _inBackground;

  /// 进入前台：立即复验，而不是等待下一次心跳。
  ///
  /// 返回复验结果，测试与调用方据此判断是否需要展示重连状态。
  Future<bool> onResumed() async {
    _inBackground = false;

    // 回到前台时把 detached 标志清掉：即使此前收到过 detached，
    // 只要进程还活着且用户回来了，就应该继续维持连接。
    reconnectController?.setAppDetached(false);

    final server = activeServer();
    if (server == null) return true;

    // 只有原本以为连着的时候才需要复验。已经不在 map 里时，
    // 若用户仍想保持连接，必须立刻重连，不能干等下一次心跳。
    if (!sshManager.isConnected(server.id)) {
      _syncKeepAlive();
      if (reconnectController?.userIntent == true) {
        reconnectController?.handleVerifyFailed();
      }
      return false;
    }

    final alive = await sshManager.verifyAlive(server.id);
    if (!alive) {
      // 复验失败：verifyAlive 已经清掉了死掉的 client，
      // 这里只负责把状态翻成 reconnecting，让用户看到真实情况。
      reconnectController?.handleVerifyFailed();
    }
    _syncKeepAlive();
    return alive;
  }

  /// 退到后台：保证前台服务在跑，这样进程不会被系统回收。
  Future<void> onPaused() async {
    _inBackground = true;
    _syncKeepAlive();
  }

  /// Flutter 视图与 Activity 分离。
  ///
  /// 这不等于进程退出：Android 上划掉任务时 Activity 会 detached，
  /// 但 `stopWithTask=false` 的前台服务还托着进程。此时停 FGS 或暂停
  /// 重连，等于把保活白做了。用户意图保持不变，服务继续跑。
  Future<void> onDetached() async {
    _inBackground = true;
  }

  /// 把「当前活跃服务器是否已连接」同步给前台服务。
  ///
  /// 前台服务本身不持有连接状态（SSH 客户端活在 Dart 侧），
  /// 它只需要知道「有几个会话要保」，通知文案才不会是错的。
  void _syncKeepAlive() {
    final server = activeServer();
    if (server != null && sshManager.isConnected(server.id)) {
      unawaited(keepAlive.addSession(server.id));
    } else if (server != null) {
      unawaited(keepAlive.removeSession(server.id));
    }
  }

  @visibleForTesting
  void debugSetInBackground(bool value) => _inBackground = value;
}

/// 生命周期协调器。
final connectionLifecycleProvider = Provider<ConnectionLifecycleCoordinator>((
  ref,
) {
  return ConnectionLifecycleCoordinator(
    sshManager: ref.watch(sshClientManagerProvider),
    reconnectController: ref.watch(reconnectControllerProvider),
    keepAlive: ref.watch(keepAliveCoordinatorProvider),
    activeServer: () => ref.read(activeServerProvider),
  );
});
