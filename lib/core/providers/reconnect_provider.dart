import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/server_profile.dart';
import '../services/keep_alive_service.dart';
import '../utils/reconnect_backoff.dart';
import 'storage_providers.dart';

/// 建立一次连接的结果。
///
/// 不直接复用 `ServerConnectionNotifier.connect`：重连需要能区分
/// 「值得重试的失败」和「不该重试的失败」，而失败原因必须原样带上来。
typedef ConnectAttempt = Future<void> Function(ServerProfile server);

/// 一次性重试调度器，抽成接缝让测试不必等待真实时间。
typedef RetryScheduler = Timer Function(Duration delay, void Function() action);

Timer _defaultScheduler(Duration delay, void Function() action) =>
    Timer(delay, action);

/// 自动重连编排器。
///
/// 职责边界：本类只决定「何时重连、重连几次、失败后怎么办」；
/// 真正怎么建立连接由 [connectAttempt] 注入。这样规则可以纯逻辑测试，
/// 而传输细节仍归 `SSHClientManager`。
class ReconnectController {
  final ConnectAttempt connectAttempt;
  final RetryScheduler scheduler;
  final ReconnectBackoff backoff;

  /// 状态变化回调。
  ///
  /// 保留单槽 setter 以兼容既有构造用法，但内部用订阅表实现，
  /// 允许多个消费者各自监听。用单槽字段时，一个 widget 覆盖了
  /// 回调就会把另一个消费者的通知吞掉，而且它 dispose 后还可能把
  /// 已经被覆盖的值写回去。订阅制没有这个问题。
  void Function(ReconnectState state)? onStateChanged;

  final List<void Function(ReconnectState state)> _listeners = [];

  /// 注册一个状态变化监听，返回取消函数。
  ///
  /// 消费者应当在 dispose 时调用返回的函数，避免在已卸载的 widget 上
  /// 触发 setState。
  void Function() addStateListener(void Function(ReconnectState state) fn) {
    _listeners.add(fn);
    return () => _listeners.remove(fn);
  }

  /// 只给测试用：在不改变内部状态机的前提下广播一次状态。
  ///
  /// 供假控制器驱动界面的状态迁移，避免测试为了触发一次重绘而
  /// 去跑真实的退避与连接流程。
  @visibleForTesting
  void debugEmit(ReconnectState state) => _emit(state);

  /// 当前订阅者数量，用于断言订阅是否被正确释放。
  @visibleForTesting
  int get listenerCount => _listeners.length;

  /// 每次「连上」后调用，用于让依赖连接的资源重新挂载。
  ///
  /// 区分首次连接与重连不值得：两者的后续动作完全一样（重新绑定
  /// 终端、重启指标采样），而漏掉首次反而会造成状态不一致。
  Future<void> Function(ServerProfile server)? onReconnected;

  ReconnectController({
    required this.connectAttempt,
    RetryScheduler? scheduler,
    this.backoff = const ReconnectBackoff(),
    this.onStateChanged,
    this.onReconnected,
  }) : scheduler = scheduler ?? _defaultScheduler;

  ReconnectState _state = const ReconnectState();
  ReconnectState get state => _state;

  Timer? _timer;
  int _epoch = 0;
  bool _disposed = false;
  ServerProfile? _server;

  /// 当前维持连接的服务器 id；未维持任何连接时为 null。
  String? get serverId => _server?.id;

  /// 用户是否有「保持连接」的意图。
  ///
  /// 用户主动断开后必须置 false，否则会把用户明确要求的断开
  /// 当成掉线又连回去 —— 这是最容易被忽略、也最招人烦的 bug。
  bool _userIntent = false;
  bool get userIntent => _userIntent;

  /// 是否曾经开始过维持连接。
  ///
  /// 用来区分两种 `userIntent == false`：从未连过（冷启动）与用户主动断开。
  /// 两者状态都是 idle，只看 getUserIntent 无法区分，界面就会在冷启动时
  /// 错误地显示「已断开」。UI 只应在 [hasEverStarted] 为 true 时提示断开。
  bool _hasEverStarted = false;
  bool get hasEverStarted => _hasEverStarted;

  /// App 是否已退到 detached（进程即将结束）。
  bool _appDetached = false;

  bool get isPending => _timer != null;

  /// 开始维持某个服务器的连接。
  void start(ServerProfile server) {
    if (_disposed) return;
    _epoch++;
    _server = server;
    _userIntent = true;
    _hasEverStarted = true;
    _appDetached = false;
    _cancelTimer();
    _emit(
      _state.copyWith(
        status: ReconnectStatus.connecting,
        attempt: 0,
        clearDelay: true,
        clearError: true,
        retryable: true,
      ),
    );
  }

  /// 首次连接成功，进入稳定态并清零退避计数。
  void markConnected() {
    _cancelTimer();
    _emit(const ReconnectState(status: ReconnectStatus.connected));
  }

  /// 传输层掉线，安排一次重连。
  ///
  /// 正常路径由 `SSHClientManager.transportDied` 触发。
  void handleTransportDied() {
    if (!_shouldRetry) return;
    _scheduleRetry();
  }

  /// 探测到连接已经死了（例如回前台复验失败）。
  ///
  /// 与 [handleTransportDied] 分开是因为调用方语境不同：这里通常是
  /// 「UI 以为连着但其实早断了」，需要先把状态翻回 reconnecting，
  /// 让用户至少看到真实的连接状态。
  void handleVerifyFailed() {
    if (!_shouldRetry) return;
    _scheduleRetry();
  }

  /// 用户主动断开：停止一切重连企图。
  void userDisconnect() {
    _epoch++;
    _userIntent = false;
    _cancelTimer();
    _emit(const ReconnectState(status: ReconnectStatus.idle));
  }

  /// App 进入后台/即将退出：暂停重连但不改变用户意图。
  ///
  /// 用 paused 而不是 userDisconnect：用户回到前台时应当继续维持连接，
  /// 所以意图要留着，只停掉定时器。
  void setAppDetached(bool detached) {
    if (detached) _epoch++;
    _appDetached = detached;
    if (detached) {
      _cancelTimer();
      if (_state.isReconnecting) {
        _emit(_state.copyWith(status: ReconnectStatus.idle, clearDelay: true));
      }
    } else if (_userIntent && !_state.isConnected) {
      // 回到前台且用户仍想连着 → 立刻再试一次，不等剩余退避。
      _scheduleRetry(immediate: true);
    }
  }

  bool get _shouldRetry =>
      _userIntent && !_appDetached && _server != null && _state.retryable;

  void _scheduleRetry({bool immediate = false}) {
    // 已经排好期就不要再排一次：回前台时 `setAppDetached(false)` 与
    // `handleVerifyFailed()` 会先后触发，重复排期会让 attempt 一次跳两级，
    // 退避直接从 1s 变成 2s，用户会看到「刚回来就要等更久」。
    if (_timer != null) return;

    if (!_shouldRetry) return;

    final attempt = _state.attempt + 1;
    final delay = immediate ? Duration.zero : backoff.delayFor(attempt);

    _emit(
      _state.copyWith(
        status: ReconnectStatus.reconnecting,
        attempt: attempt,
        nextDelay: delay,
        clearError: true,
      ),
    );

    _timer = scheduler(delay, () {
      _timer = null;
      unawaited(_runAttempt());
    });
  }

  Future<void> _runAttempt() async {
    final server = _server;
    if (server == null || !_shouldRetry) return;
    final epoch = _epoch;
    bool isCurrent() =>
        !_disposed &&
        epoch == _epoch &&
        _userIntent &&
        !_appDetached &&
        identical(server, _server);

    try {
      await connectAttempt(server);
      if (!isCurrent()) return;
      markConnected();
      // 连上之后才重挂依赖资源的消费者（终端、指标采样）。
      // 放在状态变更之后：即使重挂失败，用户也已经能看到「已连接」，
      // 而不是卡在 reconnecting 上。
      await onReconnected?.call(server);
    } catch (error) {
      if (!isCurrent()) return;

      if (!isRetryableConnectFailure(error)) {
        // 主机密钥变更之类：必须停下来让用户看到，而不是疯狂重试。
        _cancelTimer();
        _emit(
          ReconnectState(
            status: ReconnectStatus.failed,
            attempt: _state.attempt,
            errorMessage: error.toString(),
            retryable: false,
          ),
        );
        return;
      }

      // 无限重试：用户要求「App 没退出就一直保持连接」，
      // 因此这里没有最大次数，只有逐渐收敛到 30s 的间隔。
      _scheduleRetry();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit(ReconnectState next) {
    _state = next;
    onStateChanged?.call(next);
    // 复制一份再遍历：监听者可能在回调里取消订阅（例如 widget 卸载）。
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }

  /// 释放定时器。
  void dispose() {
    _disposed = true;
    _epoch++;
    _userIntent = false;
    _cancelTimer();
    onStateChanged = null;
    _listeners.clear();
  }
}

/// 连接保活协调器：把「有几个活跃连接」翻译成前台服务的启停。
///
/// 与 [ReconnectController] 分开是因为职责不同：重连控制器关心「怎么把
/// 连接找回来」，本类只关心「让进程活着」。分开后前台服务在无连接时
/// 能正确退出，不会变成一个永远挂着通知的僵尸。
class KeepAliveCoordinator {
  final KeepAliveService service;

  KeepAliveCoordinator(this.service);

  final Set<String> _activeSessions = {};

  int get activeCount => _activeSessions.length;
  bool get hasActiveSessions => _activeSessions.isNotEmpty;

  /// 记录一个已建立的连接，必要时启动前台服务。
  Future<void> addSession(String serverId) async {
    _activeSessions.add(serverId);
    await _sync();
  }

  /// 移除一个连接，全部移除后停止前台服务。
  Future<void> removeSession(String serverId) async {
    _activeSessions.remove(serverId);
    await _sync();
  }

  /// 清空所有连接并停止服务。
  Future<void> clear() async {
    _activeSessions.clear();
    await service.stop();
  }

  Future<void> _sync() async {
    if (_activeSessions.isEmpty) {
      await service.stop();
      return;
    }
    // 每次同步都尝试 start：服务可能已被系统回收，
    // 而 updateSessionCount 在未运行时会被原生侧忽略。
    await service.start(_activeSessions.length);
    await service.updateSessionCount(_activeSessions.length);
  }
}

final keepAliveCoordinatorProvider = Provider<KeepAliveCoordinator>((ref) {
  return KeepAliveCoordinator(ref.watch(keepAliveServiceProvider));
});

/// 自动重连开关。
///
/// 由 `main.dart` 在启动时覆盖为真实实现（注入连接函数与调度器）；
/// 默认关闭，避免测试或未初始化环境下意外发起连接。
final reconnectEnabledProvider = Provider<bool>((ref) => false);

/// 当前活跃服务器的自动重连控制器。
///
/// 返回 null 表示自动重连未启用。
final reconnectControllerProvider = Provider<ReconnectController?>((ref) {
  if (!ref.watch(reconnectEnabledProvider)) return null;

  final sshManager = ref.watch(sshClientManagerProvider);

  final controller = ReconnectController(
    connectAttempt: (server) async {
      final repo = ref.read(serverRepositoryProvider);
      // 每次重试都重新读取凭据：密码可能已被用户改过，
      // 缓存住就一定会在改密后永远重连失败。
      final password = await repo.getPassword(server.id);
      final privateKey = await repo.getPrivateKey(server.id);
      await sshManager.reconnectClient(
        server,
        password: password,
        privateKey: privateKey,
      );
    },
  );

  // 传输层掉线是重连的主要触发源。
  final subscription = sshManager.transportDied.listen((serverId) {
    if (serverId == controller.serverId) {
      controller.handleTransportDied();
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.dispose();
  });

  return controller;
});

/// 把「已经连上 / 用户主动断开」翻译成重连意图 + 前台服务登记。
///
/// 抽成纯函数是为了让 [ServerConnectionNotifier] 和测试走同一条路径，
/// 避免 connect 成功却忘了武装重连。
void armConnectionSession({
  required ReconnectController? reconnect,
  required KeepAliveCoordinator keepAlive,
  required ServerProfile server,
}) {
  reconnect?.start(server);
  reconnect?.markConnected();
  unawaited(keepAlive.addSession(server.id));
}

/// 用户主动断开：停重连、撤前台服务。不广播传输层死亡。
void disarmConnectionSession({
  required ReconnectController? reconnect,
  required KeepAliveCoordinator keepAlive,
  required String serverId,
}) {
  reconnect?.userDisconnect();
  unawaited(keepAlive.removeSession(serverId));
}
