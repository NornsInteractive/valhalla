import 'package:flutter/material.dart';

class ValhallaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  const ValhallaCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide = borderColor != null
        ? BorderSide(color: borderColor!, width: 1)
        : (theme.cardTheme.shape is RoundedRectangleBorder
              ? (theme.cardTheme.shape as RoundedRectangleBorder).side
              : BorderSide(color: theme.colorScheme.outlineVariant, width: 1));

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: borderSide,
    );

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: color ?? theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: content,
            )
          : content,
    );
  }
}
