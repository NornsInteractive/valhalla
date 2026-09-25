import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';

class TerminalAccessoryBar extends StatelessWidget {
  final void Function(String key, {bool isCtrl, bool isAlt}) onKey;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onPaste;
  final bool isCtrlActive;
  final bool isAltActive;

  const TerminalAccessoryBar({
    super.key,
    required this.onKey,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onPaste,
    required this.isCtrlActive,
    required this.isAltActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildKey(context, 'ESC', onPressed: () => onKey('ESC')),
              _buildKey(context, 'TAB', onPressed: () => onKey('TAB')),
              _buildKey(
                context,
                'CTRL',
                isActive: isCtrlActive,
                onPressed: onToggleCtrl,
              ),
              _buildKey(
                context,
                'ALT',
                isActive: isAltActive,
                onPressed: onToggleAlt,
              ),
              _buildKey(
                context,
                'Ctrl+C',
                onPressed: () => onKey('C', isCtrl: true),
              ),
              _buildKey(
                context,
                'Ctrl+D',
                onPressed: () => onKey('D', isCtrl: true),
              ),
              const SizedBox(width: 4),
              _buildKey(context, '↑', onPressed: () => onKey('↑')),
              _buildKey(context, '↓', onPressed: () => onKey('↓')),
              _buildKey(context, '←', onPressed: () => onKey('←')),
              _buildKey(context, '→', onPressed: () => onKey('→')),
              const SizedBox(width: 4),
              _buildKey(
                context,
                'PASTE',
                icon: Icons.content_paste,
                onPressed: onPaste,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(
    BuildContext context,
    String label, {
    IconData? icon,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 34,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: isActive ? context.colorScheme.primary : null,
            foregroundColor: isActive ? context.colorScheme.onPrimary : null,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onPressed,
          child: icon != null
              ? Icon(icon, size: 15)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
        ),
      ),
    );
  }
}
