import 'package:flutter/material.dart';
import '../core/design/motion_widgets.dart';
import '../core/design/tokens.dart';

enum StatusType { online, offline, running, warning, danger }

/// 语义状态徽标: 胶囊底 + 呼吸状态点。
///
/// 点只表达真实状态语义 (在线 / 运行中 / 告警), 颜色锁定语义色不随种子色漂移。
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final bool showDot;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.showDot = true,
    this.fontSize = 11.0,
  });

  Color _color(Brightness brightness) => switch (type) {
    StatusType.online => VColors.success(brightness),
    StatusType.offline => VColors.info(brightness),
    StatusType.running => VColors.info(brightness),
    StatusType.warning => VColors.warning(brightness),
    StatusType.danger => VColors.danger(brightness),
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).brightness);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showDot ? 9 : 10,
        vertical: 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            PulseDot(
              color: color,
              size: 6,
              // 只有在线 / 运行中呼吸, 静态状态不闪。
              pulse: type == StatusType.online || type == StatusType.running,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
