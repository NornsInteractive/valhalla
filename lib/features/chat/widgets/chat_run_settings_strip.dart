import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/chat_run_settings.dart';

class ChatRunSettingsStrip extends StatelessWidget {
  final ChatRunSettings settings;
  final AgentRuntimeCapabilities capabilities;
  final bool isStructuredSend;
  final bool isBusy;
  final bool isLoadingSettings;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRefreshSettings;
  final Key? tuneButtonKey;
  final Widget? leading;
  final Widget? trailing;

  const ChatRunSettingsStrip({
    super.key,
    required this.settings,
    required this.capabilities,
    this.isStructuredSend = true,
    required this.isBusy,
    this.isLoadingSettings = false,
    required this.onOpenSettings,
    this.onRefreshSettings,
    this.tuneButtonKey,
    this.leading,
    this.trailing,
  });

  String _getModelLabel(BuildContext context) {
    if (!isStructuredSend) {
      return context.l10n.chatRunSettingsInteractiveCli;
    }
    final targetId = settings.modelId ?? capabilities.currentModelId;
    if (targetId == null) {
      return context.l10n.chatRunSettingsDefault;
    }
    final model = capabilities.models
        .where((m) => m.id == targetId)
        .firstOrNull;
    return model?.label ?? targetId;
  }

  String _getReasoningLabel(BuildContext context) {
    if (!isStructuredSend) {
      return context.l10n.chatRunSettingsInteractiveCli;
    }
    final targetId = settings.reasoningId ?? capabilities.currentReasoningId;
    if (targetId == null) {
      return context.l10n.chatRunSettingsDefault;
    }
    final level = capabilities.reasoningLevels
        .where((r) => r.id == targetId)
        .firstOrNull;
    return level?.label ?? targetId;
  }

  String? _getModeLabel(BuildContext context) {
    if (!isStructuredSend) return null;
    final targetId = settings.modeId ?? capabilities.currentModeId;
    if (targetId == null) return null;
    final mode = capabilities.modes.where((m) => m.id == targetId).firstOrNull;
    return mode?.label ?? targetId;
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

  Widget _buildTextItem({
    required BuildContext context,
    required Key key,
    required String text,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(VRadius.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isBusy
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
              icon: const Icon(Icons.tune, size: 18),
              tooltip: context.l10n.chatRunSettingsTitle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: isBusy ? null : onOpenSettings,
            ),
            if (onRefreshSettings != null) ...[
              const SizedBox(width: 2),
              IconButton(
                key: const Key('chat_run_settings_strip_refresh_button'),
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: context.l10n.cliRefreshSessions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: isBusy ? null : onRefreshSettings,
              ),
            ],
            if (isLoadingSettings) ...[
              const SizedBox(width: 4),
              SizedBox(
                key: const Key('chat_run_settings_loading_indicator'),
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (leading != null) ...[
              const SizedBox(width: 6),
              leading!,
              const SizedBox(width: 6),
              SizedBox(
                height: 16,
                child: VerticalDivider(
                  width: 8,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
            const SizedBox(width: 4),
            _buildTextItem(
              context: context,
              key: const Key('chat_strip_model_chip'),
              text: isStructuredSend
                  ? _getModelLabel(context)
                  : '${context.l10n.chatRunSettingsModel}: ${_getModelLabel(context)}',
              tooltip:
                  '${context.l10n.chatRunSettingsModel}: ${_getModelLabel(context)}',
              onTap: onOpenSettings,
            ),
            _buildSeparator(context),
            _buildTextItem(
              context: context,
              key: const Key('chat_strip_reasoning_chip'),
              text: isStructuredSend
                  ? _getReasoningLabel(context)
                  : '${context.l10n.chatRunSettingsReasoning}: ${_getReasoningLabel(context)}',
              tooltip:
                  '${context.l10n.chatRunSettingsReasoning}: ${_getReasoningLabel(context)}',
              onTap: onOpenSettings,
            ),
            if (_getModeLabel(context) != null) ...[
              _buildSeparator(context),
              _buildTextItem(
                context: context,
                key: const Key('chat_strip_mode_chip'),
                text: _getModeLabel(context)!,
                tooltip:
                    '${context.l10n.chatRunSettingsAgentMode}: ${_getModeLabel(context)}',
                onTap: onOpenSettings,
              ),
            ],
            _buildSeparator(context),
            _buildTextItem(
              context: context,
              key: const Key('chat_strip_permission_chip'),
              text: _getPermissionLabel(context),
              tooltip:
                  '${context.l10n.chatRunSettingsPermissions}: ${_getPermissionLabel(context)}',
              onTap: onOpenSettings,
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
