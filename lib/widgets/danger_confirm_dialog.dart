import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/security/command_safety.dart';

/// 高危命令二次确认弹窗。
///
/// 红色语义锁: danger 级恒定红, warning 级恒定琥珀; 不随种子色漂移。
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
    final primaryColor = context.vDanger;
    final warningColor = context.vWarning;
    final tone = isDanger ? primaryColor : warningColor;
    final dark = Theme.of(context).brightness == Brightness.dark;

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VRadius.card),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Icon(
          isDanger ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
          color: tone,
          size: 28,
        ),
      ),
      title: Text(
        title,
        style: context.textTheme.titleMedium?.copyWith(color: tone),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warningText, style: context.textTheme.bodyMedium),
              if (risk.matchedPattern != null) ...[
                const SizedBox(height: VSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(color: tone.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    context.l10n.riskPatternMatched(risk.matchedPattern!),
                    style: monoTextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tone),
                  ),
                ),
              ],
              const SizedBox(height: VSpace.lg),
              Text(
                context.l10n.riskCommandPreview,
                style: context.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: VSpace.sm),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF07080B) : const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(VRadius.input),
                  border: Border.all(color: tone.withValues(alpha: 0.35), width: 1),
                ),
                child: SelectableText(
                  command,
                  style: monoTextStyle(
                    fontSize: 12,
                    color: const Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (extraContent != null) ...[
                const SizedBox(height: VSpace.lg),
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
            backgroundColor: tone,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.riskConfirmButton),
        ),
      ],
    );
  }
}
