import 'package:flutter/services.dart';

/// 前台服务保活能力的 Dart 侧接缝。
///
/// 抽象成接口是为了让 provider/controller 层可以在测试里注入替身：
/// `MethodChannel` 在单元测试里没有真实的 Android 侧，直接调用会抛异常
/// 或永远挂起。
abstract interface class KeepAliveService {
  /// 启动保活前台服务，[sessionCount] 用于通知文案。
  ///
  /// 返回是否真的启动成功。系统可能在后台启动限制下拒绝，
  /// 这属于可预期情况，调用方应降级而不是崩溃。
  Future<bool> start(int sessionCount);

  /// 更新通知里的活跃会话数。
  Future<void> updateSessionCount(int sessionCount);

  /// 停止保活服务。
  Future<void> stop();

  /// 查询服务是否在运行。
  Future<bool> isRunning();

  /// 发一条「传输完成」通知。
  ///
  /// 与保活通知走同一个 MethodChannel，但落在另一个通知渠道上：
  /// 保活是常驻的低优先级指示器，这个是用户要的一次性结果提醒，
  /// 用户可以单独关掉其中一个。
  Future<void> notifyTransferCompleted(int completedCount);

  /// 读取「本次启动/恢复是由通知点击触发的吗」，并**消费掉**它。
  ///
  /// 返回 `true` 表示应该打开传输列表。原生侧是读后即清：
  /// 第二次调用会返回 `false`，否则每次从后台切回来都会重开列表。
  ///
  /// 拿不到原生实现（非 Android / 通道未注册）时返回 `false` 而不是抛异常——
  /// 这只是个锦上添花的跳转，不值得让启动路径失败。
  Future<bool> consumeOpenTransfersAction();
}

/// 基于 `MethodChannel('valhalla/keepalive')` 的实现。
class MethodChannelKeepAliveService implements KeepAliveService {
  static const _channel = MethodChannel('valhalla/keepalive');

  const MethodChannelKeepAliveService();

  @override
  Future<bool> start(int sessionCount) async {
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'sessionCount': sessionCount,
      });
      return result ?? false;
    } on PlatformException {
      // 后台启动被系统拒绝（ForegroundServiceStartNotAllowedException）。
      // 这是预期内的情况：App 仍能前台运行，只是失去后台保护。
      return false;
    } on MissingPluginException {
      // 非 Android 平台（或未注册通道）。静默降级。
      return false;
    }
  }

  @override
  Future<void> updateSessionCount(int sessionCount) async {
    try {
      await _channel.invokeMethod<void>('updateSessionCount', {
        'sessionCount': sessionCount,
      });
    } on PlatformException {
      // 通知更新失败不影响连接本身，忽略。
    } on MissingPluginException {
      // 同上。
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // 停止失败无需上报：进程结束时会自然清理。
    } on MissingPluginException {
      // 非 Android 平台。
    }
  }

  @override
  Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {
    try {
      await _channel.invokeMethod<void>('notifyTransferCompleted', {
        'count': completedCount,
      });
    } on PlatformException {
      // 通知被系统拒绝（例如用户在设置里关掉了通知权限）。
      // 传输本身已经成功，这里不值得把失败抛给上层。
    } on MissingPluginException {
      // 非 Android 平台。
    }
  }

  @override
  Future<bool> consumeOpenTransfersAction() async {
    try {
      final result = await _channel.invokeMethod<String>('getLaunchAction');
      return result == 'openTransfers';
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// 桌面平台保活安全降级实现（空实现 + 明确文档说明）。
///
/// ### 设计背景与取舍：
/// 桌面操作系统（Linux / macOS / Windows）没有移动端（如 Android）通过常驻通知
/// 运行的「前台服务」（Foreground Service）机制。桌面应用的进程生命周期与后台
/// 调度由操作系统普通进程管理器接管；在系统进入睡眠（Sleep）、休眠（Hibernate）
/// 或息屏挂起状态时，网络适配器由 OS 节能策略决定挂起与否。
///
/// ### 降级行为（No-op / Safe Fallback）：
/// - [start]：安全返回 `false`（表明当前桌面系统未启动任何前台服务）。
/// - [updateSessionCount]：静默 no-op（无需更新桌面通知计数）。
/// - [stop]：静默 no-op。
/// - [isRunning]：返回 `false`。
/// - [notifyTransferCompleted]：静默 no-op。
/// - [consumeOpenTransfersAction]：返回 `false`（桌面端不依赖通知点击跳转）。
///
/// ### SSH 断线风险说明：
/// 桌面平台上的 SSH 断线风险【仍然存在】（在主机断网、息屏挂起或休眠唤醒后可能掉线）。
/// 应用层通过 [ReconnectCoordinator] 的指数退避重连以及底层 SSH Client 的
/// TCP Keepalive 机制来实现异常掉线后的自动恢复，而非依赖前台服务。
class DesktopKeepAliveService implements KeepAliveService {
  const DesktopKeepAliveService();

  @override
  Future<bool> start(int sessionCount) async => false;

  @override
  Future<void> updateSessionCount(int sessionCount) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {}

  @override
  Future<bool> consumeOpenTransfersAction() async => false;
}
