import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../data/models/server_profile.dart';

enum AgentCommandActionType { install, login }

Future<bool> showAgentCommandConfirmDialog({
  required BuildContext context,
  required AgentCommandActionType actionType,
  required String agentName,
  required String command,
  required ServerProfile server,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final title = actionType == AgentCommandActionType.install
          ? ctx.l10n.confirmInstallAgentTitle
          : ctx.l10n.confirmLoginAgentTitle;

      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ctx.vWarning, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: ctx.textTheme.titleMedium)),
          ],
        ),
        content: Entrance(
          index: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.50,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Server info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ctx.l10n.targetServerLabel}:',
                        style: ctx.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${server.name} (${server.host}:${server.port})',
                        style: monoTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: ctx.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Risk warning
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ctx.vWarning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: ctx.vWarning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: ctx.vWarning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.l10n.agentCommandRiskWarning,
                            style: ctx.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Command preview header with copy action
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ctx.l10n.commandPreviewLabel,
                          style: ctx.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('agent_command_copy_button'),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: ctx.l10n.copy,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: command));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(ctx.l10n.chatMessageCopied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? const Color(0xFF07080B)
                          : const Color(0xFF1A1E26),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          command,
                          style: monoTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: ctx.vSuccess,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsOverflowButtonSpacing: 8,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.vWarning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.executeButton),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
