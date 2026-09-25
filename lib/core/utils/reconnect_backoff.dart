import 'dart:math';

import '../errors/app_exceptions.dart';

/// 重连退避策略（纯逻辑，无计时器、无 IO）。
///
/// 单独抽出来的理由：退避/抖动/上限这些规则是重连里最容易写错、也最值得
/// 精确断言的部分。把它做成无副作用的函数后，测试无需等待真实时间即可
/// 覆盖全部边界；真正的调度交给 `reconnect_provider.dart`。
class ReconnectBackoff {
  /// 首次重试的等待时间。
  final Duration initialDelay;

  /// 等待时间的上限。
  final Duration maxDelay;

  /// 每次重试的倍数。
  final double multiplier;

  /// 抖动比例（0.2 表示 ±20%）。
  ///
  /// 抖动的意义是避免多台服务器/多个会话在同一时刻齐步重连，
  /// 把服务端和本机都打出一波尖峰。
  final double jitterRatio;

  const ReconnectBackoff({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitterRatio = 0.2,
    this.random,
  });

  /// 随机源；为 null 时用 `Random()`。
  ///
  /// 不能直接给字段默认 `Random()`：那会破坏 const 构造，测试也无法
  /// 注入确定性的种子来断言抖动区间。
  final Random? random;

  /// 第 [attempt] 次重试（从 1 开始）的等待时间。
  ///
  /// 已含抖动，且结果永不超过 [maxDelay]。返回值至少为 0。
  Duration delayFor(int attempt) {
    assert(attempt >= 1, 'attempt 从 1 开始');
    final baseMs = initialDelay.inMilliseconds * pow(multiplier, attempt - 1);
    final cappedMs = min(baseMs, maxDelay.inMilliseconds.toDouble());

    if (jitterRatio <= 0) {
      return Duration(milliseconds: cappedMs.round());
    }

    // 抖动在 ±jitterRatio 之间均匀取值。
    final source = random ?? _sharedRandom;
    final factor = 1 + (source.nextDouble() * 2 - 1) * jitterRatio;
    final jittered = cappedMs * factor;
    final clamped = jittered.clamp(0, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: clamped.round());
  }
}

/// 未注入随机源时的默认随机源。
final Random _sharedRandom = Random();

/// 连接稳定性的用户可见状态。
enum ReconnectStatus {
  /// 没有活跃连接需求（用户没连，或已主动断开）。
  idle,

  /// 正在建立连接。
  connecting,

  /// 连接正常。
  connected,

  /// 传输层掉了，正在自动重连。
  reconnecting,

  /// 放弃自动重连，需要用户介入（例如主机密钥变更）。
  failed,
}

/// 重连状态。
class ReconnectState {
  final ReconnectStatus status;

  /// 当前已尝试的重连次数（`reconnecting` 时有意义）。
  final int attempt;

  /// 下一次重连的时间（仅用于 UI 展示）。
  final Duration? nextDelay;

  /// 失败原因；`failed` 时有意义。
  final String? errorMessage;

  /// 该失败是否值得继续自动重试。
  ///
  /// 主机密钥变更这类问题重试一万次也不会好，只会掩盖安全事件，
  /// 因此必须显式标记为不可重试。
  final bool retryable;

  const ReconnectState({
    this.status = ReconnectStatus.idle,
    this.attempt = 0,
    this.nextDelay,
    this.errorMessage,
    this.retryable = true,
  });

  bool get isConnected => status == ReconnectStatus.connected;
  bool get isReconnecting => status == ReconnectStatus.reconnecting;
  bool get isBusy =>
      status == ReconnectStatus.connecting ||
      status == ReconnectStatus.reconnecting;

  ReconnectState copyWith({
    ReconnectStatus? status,
    int? attempt,
    Duration? nextDelay,
    String? errorMessage,
    bool? retryable,
    bool clearDelay = false,
    bool clearError = false,
  }) {
    return ReconnectState(
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      nextDelay: clearDelay ? null : (nextDelay ?? this.nextDelay),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      retryable: retryable ?? this.retryable,
    );
  }
}

/// 判断一个连接失败是否值得继续自动重试。
///
/// 目前只有主机密钥变更是明确的「不可重试」：它意味着远端身份变了，
/// 继续重连既有安全风险也会刷屏。其余错误（网络抖动、超时、认证暂时失败）
/// 都值得重试。
bool isRetryableConnectFailure(Object error) =>
    error is! HostKeyMismatchException;

/// 是否是主机密钥不匹配错误。
///
/// 之所以单独抽成函数：重连循环里要在两个地方用同一个判断，
/// 且测试会直接断言这个分类结果。
bool isHostKeyMismatch(Object error) => error is HostKeyMismatchException;
