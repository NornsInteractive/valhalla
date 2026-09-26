import 'package:flutter/material.dart';
import '../core/design/motion_widgets.dart';
import '../core/design/tokens.dart';

/// 统一卡片容器: 16 圆角 + 1px 冷描边 + 可选按压反馈。
///
/// [onTap] 非空时自动获得 [PressableScale] 按压反馈与 hover 底色;
/// [highlight] 会给描边着强调色, 用于选中态。
class ValhallaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  /// 描边与角标使用强调色 (选中态)。
  final bool highlight;

  /// 是否启用按压缩放反馈 (默认 onTap 非空时启用)。
  final bool? pressable;

  const ValhallaCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius = VRadius.card,
    this.highlight = false,
    this.pressable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final effectiveBorder =
        borderColor ??
        (highlight ? scheme.primary.withValues(alpha: 0.7) : scheme.outlineVariant);

    Widget content = child;
    if (padding != null) content = Padding(padding: padding!, child: content);

    final card = Card(
      margin: margin ?? EdgeInsets.zero,
      color: color ?? theme.cardTheme.color ?? scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: effectiveBorder, width: highlight ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      child: onTap != null
          ? Ink(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius)),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: scheme.primary.withValues(alpha: dark ? 0.08 : 0.06),
                highlightColor: scheme.primary.withValues(alpha: dark ? 0.04 : 0.03),
                child: content,
              ),
            )
          : content,
    );

    final wantPress = pressable ?? onTap != null;
    if (!wantPress) return card;
    return PressableScale(child: card);
  }
}
