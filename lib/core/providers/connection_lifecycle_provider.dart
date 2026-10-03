import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/server_profile.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import 'reconnect_provider.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'app_visibility_provider.dart';
import 'agent_registry_provider.dart';

/// 进程存活期间维持 SSH / ACP 连接的编排器。
///
/// 这个类只做「生命周期 → 连接层动作」的翻译，不自己实现重连策略
/// （那属于 [ReconnectController]），也不自己实现保活
/// （那属于 [KeepAliveCoordinator]）。分开的好处是这里的逻辑可以
/// 用假的协作者完整测试，而不必真的连一台服务器。
///
/// 三条规则，对应三个生命周期回调：
/// - `resumed`：复用近期健康连接，其余异步复验，合并重复回调。
/// - `paused`：保留连接与用户意图，暂停非必要轮询。
/// - `detached`：不等于用户断开；系统仍可能回收进程，FGS 不保证永久在线。
class ConnectionLifecycleCoordinator {
  ConnectionLifecycleCoordinator({
    required this.sshManager,
    required this.reconnectController,
    required this.keepAlive,
    required this.activeServer,
    this.onVisibilityChanged,
  });

  final SSHClientManager sshManager;

  /// null 表示自动重连未启用。
  final ReconnectController? reconnectController;

  final KeepAliveCoordinator keepAlive;

  /// 读取当前活跃服务器。
  final ServerProfile? Function() activeServer;
  final void Function(bool foreground)? onVisibilityChanged;

  /// 应用是否已经退到后台。
  ///
  /// 用于区分「用户切回来了」和「这些回调在测试里被孤立触发」。
  bool _inBackground = false;
  bool get inBackground => _inBackground;
  DateTime? _pausedAt;
  Future<bool>? _resuming;
  int _epoch = 0;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _epoch++;
    _resuming = null;
  }

  /// 进入前台：近期健康连接直接复用，其余异步复验。
  ///
  /// 返回复验结果，测试与调用方据此判断是否需要展示重连状态。
  Future<bool> onResumed() {
    if (_resuming != null) return _resuming!;
    late final Future<bool> future;
    future = _resume().whenComplete(() {
      if (identical(_resuming, future)) _resuming = null;
    });
    _resuming = future;
    return future;
  }

  Future<bool> _resume() async {
    if (_disposed) return false;
    final wasBackground = _inBackground;
    _inBackground = false;
    sshManager.setAppInBackground(false);
    onVisibilityChanged?.call(true);
    final epoch = ++_epoch;

    // 先复验现有连接，再解除后台重试暂停，避免启动多余的重连。
    final server = activeServer();
    if (server == null) {
      reconnectController?.setAppDetached(false);
      return true;
    }
    bool current() =>
        !_disposed &&
        epoch == _epoch &&
        server.connectionKey == activeServer()?.connectionKey;

    // 只有原本以为连着的时候才需要复验。已经不在 map 里时，
    // 若用户仍想保持连接，必须立刻重连，不能干等下一次心跳。
    if (!sshManager.isConnected(server.id)) {
      await _syncKeepAlive();
      if (!current()) return false;
      reconnectController?.setAppDetached(false);
      if (reconnectController?.userIntent == true) {
        reconnectController?.handleVerifyFailed();
      }
      return false;
    }

    final briefPause =
        _pausedAt == null ||
        DateTime.now().difference(_pausedAt!) < const Duration(seconds: 10);
    if ((!wasBackground || briefPause) &&
        sshManager.recentlyVerified(server.id)) {
      if (reconnectController?.userIntent == true &&
          reconnectController?.serverId == server.id) {
        reconnectController?.markConnected();
      }
      reconnectController?.setAppDetached(false);
      await _syncKeepAlive();
      return true;
    }
    final alive = await sshManager.verifyAlive(server.id);
    if (!current()) return false;
    if (alive &&
        reconnectController?.userIntent == true &&
        reconnectController?.serverId == server.id) {
      reconnectController?.markConnected();
    }
    reconnectController?.setAppDetached(false);
    if (!alive && reconnectController?.userIntent == true) {
      // 复验失败：verifyAlive 已经清掉了死掉的 client，
      // 这里只负责把状态翻成 reconnecting，让用户看到真实情况。
      reconnectController?.handleVerifyFailed();
    }
    await _syncKeepAlive();
    return alive;
  }

  /// 退到后台：同步前台服务登记；不承诺系统永不回收进程。
  Future<void> onPaused() async {
    if (_disposed || _inBackground) return;
    _inBackground = true;
    _pausedAt = DateTime.now();
    _epoch++;
    _resuming = null;
    sshManager.setAppInBackground(true);
    reconnectController?.setAppDetached(true);
    onVisibilityChanged?.call(false);
    await _syncKeepAlive();
  }

  /// Flutter 视图与 Activity 分离。
  ///
  /// 这不等于进程退出：Android 上划掉任务时 Activity 会 detached，
  /// 但 `stopWithTask=false` 的前台服务还托着进程。保留服务和用户意图，
  /// 后台暂停重试，回到前台后先复验连接再恢复重试。
  Future<void> onDetached() async {
    await onPaused();
  }

  /// 把「当前活跃服务器是否已连接」同步给前台服务。
  ///
  /// 前台服务本身不持有连接状态（SSH 客户端活在 Dart 侧），
  /// 它只需要知道「有几个会话要保」，通知文案才不会是错的。
  Future<void> _syncKeepAlive() async {
    final server = activeServer();
    if (server != null &&
        (sshManager.isConnected(server.id) ||
            (reconnectController?.userIntent == true &&
                reconnectController?.serverId == server.id))) {
      await keepAlive.addSession(server.id);
    } else if (server != null) {
      await keepAlive.removeSession(server.id);
    }
  }

  @visibleForTesting
  void debugSetInBackground(bool value) => _inBackground = value;
}

/// 生命周期协调器。
final connectionLifecycleProvider = Provider<ConnectionLifecycleCoordinator>((
  ref,
) {
  // Mount detection before a connection event, even if management was never
  // opened. Registry also handles mounting after an existing connection.
  ref.listen(agentRegistryProvider, (_, _) {});
  final coordinator = ConnectionLifecycleCoordinator(
    sshManager: ref.watch(sshClientManagerProvider),
    reconnectController: ref.watch(reconnectControllerProvider),
    keepAlive: ref.watch(keepAliveCoordinatorProvider),
    activeServer: () => ref.read(activeServerProvider),
    onVisibilityChanged: (foreground) =>
        ref.read(appVisibilityProvider.notifier).setForeground(foreground),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
