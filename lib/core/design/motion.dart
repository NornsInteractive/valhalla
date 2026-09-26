import 'package:flutter/animation.dart';

/// Valhalla 动效系统 — 时间、曲线、弹簧预设。
///
/// 原则 (动效必须传达信息, 不为动而动):
///  * 入场用 [VCurves.decelerate] (先快后稳, 像放下的钢铁);
///  * 退场用 [VCurves.accelerate] (快速让位);
///  * 状态切换用 [VCurves.emphasized];
///  * 弹簧只用于物理感场景: 导航指示器、按压缩放、抽屉。
///  * 所有超过 3 强度的动效必须尊重系统的"减少动态效果"设置
///    (`MediaQuery.disableAnimationsOf(context)`), 见 `Entrance` 等实现。
abstract final class VTiming {
  /// 微反馈: 按压、ripple 收尾。
  static const Duration fast = Duration(milliseconds: 140);

  /// 常规状态切换: 悬停、选中态、进度。
  static const Duration base = Duration(milliseconds: 220);

  /// 入场、页面转场、大组件。
  static const Duration slow = Duration(milliseconds: 360);

  /// 首屏 / 全页编排。
  static const Duration slower = Duration(milliseconds: 520);

  /// 列表交错步长。
  static const Duration staggerStep = Duration(milliseconds: 42);
}

abstract final class VCurves {
  /// M3 标准强调曲线, 状态切换默认。
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// 入场: 快出缓停。
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// 退场: 慢起快走。
  static const Curve accelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// 弹性收尾, 用于"落位"感。
  static const Curve springish = Cubic(0.34, 1.3, 0.5, 1);
}

/// 物理弹簧参数 (供 `AnimationController.animateWith` /
/// `SpringSimulation` 使用)。
abstract final class VSpring {
  /// 干脆利落: 导航指示器、分页。
  static const SpringDescription snappy = SpringDescription(
    mass: 0.9,
    stiffness: 420,
    damping: 34,
  );

  /// 柔和: 卡片悬浮、大面板。
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 260,
    damping: 30,
  );

  /// 微弹: 点按、小徽标。
  static const SpringDescription bouncy = SpringDescription(
    mass: 0.8,
    stiffness: 380,
    damping: 22,
  );
}

/// 交错入场延迟: `index` 从 0 开始, 上限 12 档防长列表尾部等待。
Duration vStaggerDelay(int index) =>
    Duration(milliseconds: (index.clamp(0, 12)) * 42);
