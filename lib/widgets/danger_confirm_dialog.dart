import 'package:flutter/material.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/security/command_safety.dart';

class DangerConfirmDialog extends StatelessWidget {
  final String command;
  final CommandRisk risk;
  final String? customTitle;
  final String? customDescription;
  final Widget? extraContent;
  final Key? confirmButtonKey;

  const DangerConfirmDialog({
    super.key,
    required this.command,
    required this.risk,
    this.customTitle,
    this.customDescription,
    this.extraContent,
    this.confirmButtonKey,
  });

  static Future<bool> show(
    BuildContext context, {
    required String command,
    String? title,
    String? description,
    Widget? extraContent,
    Key? confirmButtonKey,
    bool forceShow = false,
  }) async {
    final risk = CommandSafety.classify(command);
    if (!risk.requiresConfirmation && !forceShow) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DangerConfirmDialog(
        command: command,
        risk: risk,
        customTitle: title,
        customDescription: description,
        extraContent: extraContent,
        confirmButtonKey: confirmButtonKey,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = risk.level == CommandRiskLevel.danger;
    final primaryColor = isDanger
        ? const Color(0xFFEF4444) // Crimson Red
        : const Color(0xFFF59E0B); // Amber

    final title =
        customTitle ??
        (isDanger
            ? context.l10n.riskDangerTitle
            : context.l10n.riskWarningTitle);

    final warningText =
        customDescription ??
        (isDanger
            ? context.l10n.riskIrreversibleWarning
            : context.l10n.riskWarningDescription);

    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDanger ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          color: primaryColor,
          size: 32,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warningText,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              if (risk.matchedPattern != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    context.l10n.riskPatternMatched(risk.matchedPattern!),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                context.l10n.riskCommandPreview,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F141C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: SelectableText(
                  command,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
              if (extraContent != null) ...[
                const SizedBox(height: 12),
                extraContent!,
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button is first and focused to prevent accidental submission
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.riskCancelButton),
        ),
        FilledButton(
          key: confirmButtonKey,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.riskConfirmButton),
        ),
      ],
    );
  }
}
