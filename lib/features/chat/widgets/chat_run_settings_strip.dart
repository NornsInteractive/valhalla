import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/chat_run_settings.dart';

class ChatRunSettingsStrip extends StatelessWidget {
  final ChatRunSettings settings;
  final AgentRuntimeCapabilities capabilities;
  final bool isStructuredSend;
  final bool isBusy;
  final VoidCallback onOpenSettings;
  final Key? tuneButtonKey;

  const ChatRunSettingsStrip({
    super.key,
    required this.settings,
    required this.capabilities,
    this.isStructuredSend = true,
    required this.isBusy,
    required this.onOpenSettings,
    this.tuneButtonKey,
  });

  String _getModelLabel(BuildContext context) {
    if (!isStructuredSend) {
      return context.l10n.chatRunSettingsInteractiveCli;
    }
    if (settings.modelId == null) {
      return context.l10n.chatRunSettingsDefault;
    }
    final model = capabilities.models
        .where((m) => m.id == settings.modelId)
        .firstOrNull;
    return model?.label ??
        settings.modelId ??
        context.l10n.chatRunSettingsDefault;
  }

  String _getReasoningLabel(BuildContext context) {
    if (!isStructuredSend) {
      return context.l10n.chatRunSettingsInteractiveCli;
    }
    if (settings.reasoningId == null) {
      return context.l10n.chatRunSettingsDefault;
    }
    final level = capabilities.reasoningLevels
        .where((r) => r.id == settings.reasoningId)
        .firstOrNull;
    return level?.label ??
        settings.reasoningId ??
        context.l10n.chatRunSettingsDefault;
  }

  String _getPermissionLabel(BuildContext context) {
    return switch (settings.permissionPolicy) {
      OperationPermissionPolicy.askEveryTime =>
        context.l10n.chatPermissionAskEveryTime,
      OperationPermissionPolicy.autoAllowSafe =>
        context.l10n.chatPermissionAutoAllowSafe,
      OperationPermissionPolicy.autoAllowAll =>
        context.l10n.chatPermissionAutoAllowAll,
    };
  }

  Widget _buildChip({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      key: key,
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isBusy ? theme.colorScheme.outline : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('chat_run_settings_strip'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: tuneButtonKey ?? const Key('chat_run_settings_button'),
              icon: const Icon(Icons.tune, size: 16),
              tooltip: context.l10n.chatRunSettingsTitle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: isBusy ? null : onOpenSettings,
            ),
            const SizedBox(width: 6),
            _buildChip(
              context: context,
              key: const Key('chat_strip_model_chip'),
              icon: Icons.psychology_outlined,
              label:
                  '${context.l10n.chatRunSettingsModel}: ${_getModelLabel(context)}',
              onTap: onOpenSettings,
            ),
            const SizedBox(width: 6),
            _buildChip(
              context: context,
              key: const Key('chat_strip_reasoning_chip'),
              icon: Icons.lightbulb_outline,
              label:
                  '${context.l10n.chatRunSettingsReasoning}: ${_getReasoningLabel(context)}',
              onTap: onOpenSettings,
            ),
            const SizedBox(width: 6),
            _buildChip(
              context: context,
              key: const Key('chat_strip_permission_chip'),
              icon: Icons.shield_outlined,
              label:
                  '${context.l10n.chatRunSettingsPermissions}: ${_getPermissionLabel(context)}',
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
