import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/chat_run_settings.dart';

class ChatRunSettingsDialog extends StatefulWidget {
  final ChatRunSettings initialSettings;
  final AgentRuntimeCapabilities capabilities;
  final bool isStructuredSend;
  final ValueChanged<ChatRunSettings> onSave;

  const ChatRunSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.capabilities,
    this.isStructuredSend = true,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required ChatRunSettings initialSettings,
    required AgentRuntimeCapabilities capabilities,
    bool isStructuredSend = true,
    required ValueChanged<ChatRunSettings> onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ChatRunSettingsDialog(
        initialSettings: initialSettings,
        capabilities: capabilities,
        isStructuredSend: isStructuredSend,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ChatRunSettingsDialog> createState() => _ChatRunSettingsDialogState();
}

class _ChatRunSettingsDialogState extends State<ChatRunSettingsDialog> {
  late String? _selectedModelId;
  late String? _selectedReasoningId;
  late OperationPermissionPolicy _selectedPolicy;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.initialSettings.modelId;
    _selectedReasoningId = widget.initialSettings.reasoningId;
    _selectedPolicy = widget.initialSettings.permissionPolicy;

    // Validate initial model if capabilities exist
    if (widget.isStructuredSend && widget.capabilities.models.isNotEmpty) {
      final exists = widget.capabilities.models.any(
        (m) => m.id == _selectedModelId,
      );
      if (!exists && _selectedModelId != null) {
        _selectedModelId = null;
      }
    }
    if (widget.isStructuredSend &&
        widget.capabilities.reasoningLevels.isNotEmpty) {
      final exists = widget.capabilities.reasoningLevels.any(
        (r) => r.id == _selectedReasoningId,
      );
      if (!exists && _selectedReasoningId != null) {
        _selectedReasoningId = null;
      }
    }
  }

  Future<void> _handlePermissionChange(OperationPermissionPolicy? value) async {
    if (value == null) return;
    if (value == OperationPermissionPolicy.autoAllowAll) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.chatPermissionAutoAllowAllConfirmTitle),
          content: Text(context.l10n.chatPermissionAutoAllowAllConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('chat_permission_auto_allow_all_confirm_button'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _selectedPolicy = value;
    });
  }

  void _save() {
    final settings = ChatRunSettings(
      modelId: widget.isStructuredSend ? _selectedModelId : null,
      reasoningId: widget.isStructuredSend ? _selectedReasoningId : null,
      permissionPolicy: _selectedPolicy,
    );
    widget.onSave(settings);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      key: const Key('chat_run_settings_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.chatRunSettingsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Model Selection
                    Text(
                      context.l10n.chatRunSettingsModel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!widget.isStructuredSend)
                      InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabled: false,
                        ),
                        child: Text(
                          context.l10n.chatRunSettingsInteractiveCli,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        key: const Key('chat_run_settings_model_dropdown'),
                        isExpanded: true,
                        initialValue: _selectedModelId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(context.l10n.chatRunSettingsDefault),
                          ),
                          ...widget.capabilities.models.map(
                            (model) => DropdownMenuItem<String?>(
                              value: model.id,
                              child: Text(
                                model.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedModelId = val;
                          });
                        },
                      ),
                    const SizedBox(height: 20),

                    // Reasoning Level Selection
                    Text(
                      context.l10n.chatRunSettingsReasoning,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!widget.isStructuredSend)
                      InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabled: false,
                        ),
                        child: Text(
                          context.l10n.chatRunSettingsInteractiveCli,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        key: const Key('chat_run_settings_reasoning_dropdown'),
                        isExpanded: true,
                        initialValue: _selectedReasoningId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(context.l10n.chatRunSettingsDefault),
                          ),
                          ...widget.capabilities.reasoningLevels.map(
                            (reasoning) => DropdownMenuItem<String?>(
                              value: reasoning.id,
                              child: Text(
                                reasoning.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedReasoningId = val;
                          });
                        },
                      ),
                    const SizedBox(height: 20),

                    // Operation Permissions Policy
                    Text(
                      context.l10n.chatRunSettingsPermissions,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: RadioGroup<OperationPermissionPolicy>(
                        groupValue: _selectedPolicy,
                        onChanged: _handlePermissionChange,
                        child: Column(
                          children: [
                            RadioListTile<OperationPermissionPolicy>(
                              key: const Key('chat_permission_ask_every_time'),
                              title: Text(
                                context.l10n.chatPermissionAskEveryTime,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: OperationPermissionPolicy.askEveryTime,
                            ),
                            const Divider(height: 1),
                            RadioListTile<OperationPermissionPolicy>(
                              key: const Key('chat_permission_auto_allow_safe'),
                              title: Text(
                                context.l10n.chatPermissionAutoAllowSafe,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: OperationPermissionPolicy.autoAllowSafe,
                            ),
                            const Divider(height: 1),
                            RadioListTile<OperationPermissionPolicy>(
                              key: const Key('chat_permission_auto_allow_all'),
                              title: Text(
                                context.l10n.chatPermissionAutoAllowAll,
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: OperationPermissionPolicy.autoAllowAll,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('chat_run_settings_cancel_button'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('chat_run_settings_save_button'),
                    onPressed: _save,
                    child: Text(context.l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
