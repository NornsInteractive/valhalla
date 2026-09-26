import 'dart:async' show Timer;
import 'dart:io' show Platform;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';

/// 是否应禁用动效 (系统"减少动态效果")。
bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// widget 测试环境下禁用无限循环动画: 否则 `pumpAndSettle` 永不结束。
/// (kIsWeb 下不读 Platform, 保持可编译。)
final bool _loopingAnimationsSuspended =
    kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

///==========================================================================
/// [Entrance] — 一次性入场动画 (fade + slide + 微缩放)。
///
/// 用于区块标题、卡片、列表项的首屏编排。列表项传 `index` 自动交错,
/// 超过 12 档后不再增加延迟, 长列表不会在尾部干等。
/// 尊重系统"减少动态效果": 禁用时直接静态渲染。
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 16),
    this.duration = VTiming.slow,
    this.curve = VCurves.decelerate,
    this.enabled = true,
  });

  /// 交错序号 (0 起)。
  final int index;

  final Widget child;
  final Offset offset;
  final Duration duration;
  final Curve curve;

  /// false 时跳过动画 (用于条件性关闭, 如数据频繁刷新的行)。
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  Timer? _delayTimer;
  bool _reduce = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reducedMotion(context);
    if (_started) return;
    _started = true;
    if (_reduce || !widget.enabled) {
      _controller.value = 1;
    } else {
      final delay = vStaggerDelay(widget.index);
      if (delay == Duration.zero) {
        _controller.forward();
      } else {
        // 自有 Timer 而不是 Future.delayed: dispose 时必须能取消,
        // 否则 widget 测试会因未决 Timer 判失败。
        _delayTimer = Timer(delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Entrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 从禁用切回启用时兜底显示, 避免卡在透明态。
    if (!oldWidget.enabled && widget.enabled && _controller.value == 0) {
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              lerpDouble(widget.offset.dx, 0, t)!,
              lerpDouble(widget.offset.dy, 0, t)!,
            ),
            child: Transform.scale(scale: lerpDouble(0.985, 1, t)!, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

///==========================================================================
/// [AnimatedIndexedStack] — 保活的动画页面栈。
///
/// 与 [IndexedStack] 一样保持全部子页状态 (Offstage + TickerMode),
/// 但切页时对进入/退出页做 fade + slide + scale 转场。
/// 尊重系统"减少动态效果"。
class AnimatedIndexedStack extends StatefulWidget {
  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = VTiming.slow,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 常驻转场链: 每一页永远经历 Offstage > TickerMode > Fade > Slide > Scale
  // > ExcludeSemantics 同一串 widget 类型, 切页只改属性值。
  // 绝不在"裸子页"与"包装后的子页"之间切换 widget 类型 —— 否则 Flutter
  // 会把页面 Element 拆掉重建, 页面状态丢失并重放入场动画 (闪烁)。
  static final Animation<double> _opaque = AlwaysStoppedAnimation<double>(1);
  static final Animation<Offset> _noSlide =
      AlwaysStoppedAnimation<Offset>(Offset.zero);

  late Animation<double> _inFade = _opaque;
  late Animation<Offset> _inSlide = _noSlide;
  late Animation<double> _outFade = _opaque;
  late Animation<Offset> _outSlide = _noSlide;

  int _incoming = 0;
  int? _outgoing;
  double _direction = 1;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _incoming = widget.index;
    _controller.addStatusListener(_onDone);
  }

  void _onDone(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reducedMotion(context);
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;

    // 上一帧正在显示的页 (无论是否处于上一次转场中) 现在退场。
    final leaving = _incoming;
    _incoming = widget.index;
    _direction = widget.index > leaving ? 1.0 : -1.0;

    if (_reduce) {
      setState(() => _outgoing = null);
      return;
    }

    // 若上一次转场还在半途, 从当前透明度开始淡出, 避免闪白。
    final double outFrom =
        _outgoing != null && _controller.isAnimating ? _inFade.value : 1.0;
    final dir = _direction;

    setState(() {
      _outgoing = leaving;
      _inFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: VCurves.decelerate),
      );
      _inSlide = Tween<Offset>(
        begin: Offset(20 * dir, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: VCurves.decelerate));
      _outFade = Tween<double>(begin: outFrom, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: VCurves.accelerate),
      );
      _outSlide = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-16 * dir, 0),
      ).animate(CurvedAnimation(parent: _controller, curve: VCurves.accelerate));
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animating = _outgoing != null;
    final active = _incoming;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: animating
                ? (i != active && i != _outgoing)
                : (i != widget.index),
            child: TickerMode(
              enabled: animating
                  ? (i == active || i == _outgoing)
                  : i == widget.index,
              child: FadeTransition(
                opacity: animating
                    ? (i == active
                          ? _inFade
                          : (i == _outgoing ? _outFade : _opaque))
                    : _opaque,
                child: SlideTransition(
                  position: animating
                      ? (i == active
                            ? _inSlide
                            : (i == _outgoing ? _outSlide : _noSlide))
                      : _noSlide,
                  child: ScaleTransition(
                    scale: animating
                        ? (i == active
                              ? AlwaysStoppedAnimation<double>(1)
                              : _opaque)
                        : _opaque,
                    child: ExcludeSemantics(
                      excluding: animating ? i == _outgoing : i != widget.index,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

///==========================================================================
/// [PressableScale] — 物理按压反馈。
///
/// 按下缩到 0.97, 松手弹回。纯装饰包装, 不拦截手势, 可安全包住
/// InkWell / Button / ListTile。尊重系统"减少动态效果"。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double pressedScale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reducedMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: _pressed ? VTiming.fast : VTiming.base,
        curve: _pressed ? VCurves.accelerate : VCurves.springish,
        child: widget.child,
      ),
    );
  }
}

///==========================================================================
/// [PulseDot] — 语义状态点 (在线/连接中/错误)。
///
/// 实心点 + 呼吸扩散环, 仅用于真实状态语义, 严禁当装饰。
/// 尊重系统"减少动态效果"。
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    required this.color,
    this.size = 8,
    this.pulse = true,
  });

  final Color color;
  final double size;

  /// false 时只渲染静态点。
  final bool pulse;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reducedMotion(context);
    if (widget.pulse && !_reduce && !_loopingAnimationsSuspended) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_reduce && !_loopingAnimationsSuspended) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return SizedBox(
      width: d * 2.4,
      height: d * 2.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Container(
                width: d + (d * 1.6) * t,
                height: d + (d * 1.6) * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: (1 - t) * 0.55),
                    width: 1.4,
                  ),
                ),
              );
            },
          ),
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: d * 0.8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

///==========================================================================
/// [CountUp] — 数值滚动动画。
///
/// 指标 (CPU %、MB/s、容器数) 变化时从旧值滚到新值, 强化"这是实时数据"。
/// 尊重系统"减少动态效果": 直接显示最终值。
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = VTiming.slow,
    this.style,
  });

  final double value;
  final String Function(double value) formatter;
  final Duration duration;
  final TextStyle? style;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _from = widget.value;
    _to = widget.value;
  }

  @override
  void didUpdateWidget(covariant CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _from = _current();
    _to = widget.value;
    if (reducedMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  double _current() => lerpDouble(_from, _to, _controller.value) ?? _to;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return Text(widget.formatter(_to), style: widget.style);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Text(widget.formatter(_current()), style: widget.style),
    );
  }
}

///==========================================================================
/// [AnimatedProgressBar] — 圆头进度条, 数值变化平滑追赶。
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.trackColor,
    this.borderRadius,
  });

  /// 0.0 ~ 1.0。
  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: reducedMotion(context) ? Duration.zero : VTiming.slow,
      curve: VCurves.emphasized,
      builder: (context, v, _) {
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius ?? height / 2),
            child: LinearProgressIndicator(
              value: v,
              minHeight: height,
              color: color ?? scheme.primary,
              backgroundColor: trackColor ?? scheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }
}

///==========================================================================
/// [AnimatedRingProgress] — 环形指标环 (CPU / 内存 / 磁盘)。
///
/// 数值变化平滑追赶; 中心可放 [CountUp] 或图标。
class AnimatedRingProgress extends StatelessWidget {
  const AnimatedRingProgress({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
    this.strokeWidth = 5,
    this.trackColor,
    this.child,
  });

  /// 0.0 ~ 1.0。
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: reducedMotion(context) ? Duration.zero : VTiming.slow,
      curve: VCurves.emphasized,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  progress: v,
                  color: color,
                  trackColor:
                      trackColor ?? scheme.surfaceContainerHighest,
                  strokeWidth: strokeWidth,
                ),
              ),
              ?child,
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        2 * 3.14159 * progress,
        false,
        valuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

///==========================================================================
/// [Shimmer] + [SkeletonBox] — 骨架屏加载。
///
/// 数据未到时按最终布局形状渲染灰色骨架 + 流光, 替代转圈。
/// 尊重系统"减少动态效果": 静态灰块。
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reducedMotion(context) && !_loopingAnimationsSuspended) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bright = Theme.of(context).brightness;
    final base = bright == Brightness.dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final highlight = bright == Brightness.dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.03);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 - 2 + 2 * t, 0),
            end: Alignment(1 + 2 * t, 0),
            colors: [base, highlight, base],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final bright = Theme.of(context).brightness;
    final color = bright == Brightness.dark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final r = circle ? height / 2 : (radius ?? VRadius.input);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

/// 组合骨架: 列表行骨架 (头像 + 双行文本), 用于列表加载态。
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.lg, vertical: VSpace.md),
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, circle: true),
          const SizedBox(width: VSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 13),
                const SizedBox(height: VSpace.sm),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(height: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
