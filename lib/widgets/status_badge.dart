import 'package:flutter/material.dart';

enum StatusType { online, offline, running, warning, danger }

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

  Color _getColor() {
    switch (type) {
      case StatusType.online:
        return const Color(0xFF10B981); // Emerald Green
      case StatusType.offline:
        return const Color(0xFF6B7280); // Cool Grey
      case StatusType.running:
        return const Color(0xFF0EA5E9); // Sky Blue
      case StatusType.warning:
        return const Color(0xFFF59E0B); // Amber
      case StatusType.danger:
        return const Color(0xFFEF4444); // Crimson Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
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
