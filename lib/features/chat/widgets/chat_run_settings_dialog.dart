import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/chat_run_settings.dart';

typedef ChatRunSettingsSaveCallback = FutureOr<void> Function(ChatRunSettings);

class ChatRunSettingsDialog extends StatefulWidget {
  final ChatRunSettings initialSettings;
  final AgentRuntimeCapabilities capabilities;
  final bool isStructuredSend;
  final ChatRunSettingsSaveCallback onSave;

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
    required ChatRunSettingsSaveCallback onSave,
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
  late String? _selectedModeId;
  late final Map<String, Object> _selectedConfigValues;
  late OperationPermissionPolicy _selectedPolicy;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final caps = widget.capabilities;
    final initial = widget.initialSettings;

    _selectedModelId = initial.modelId ?? caps.currentModelId;
    _selectedReasoningId = initial.reasoningId ?? caps.currentReasoningId;
    _selectedModeId = initial.modeId ?? caps.currentModeId;
    _selectedPolicy = initial.permissionPolicy;

    _selectedConfigValues = Map<String, Object>.from(initial.configValues);
    for (final extra in caps.extraSettings) {
      _selectedConfigValues[extra.id] ??= extra.currentValue;
    }

    if (widget.isStructuredSend) {
      // Validate model against capabilities
      if (caps.models.isNotEmpty) {
        final exists = caps.models.any((m) => m.id == _selectedModelId);
        if (!exists) {
          _selectedModelId = caps.currentModelId ?? caps.models.first.id;
        }
      }
      // Validate reasoning against capabilities
      if (caps.reasoningLevels.isNotEmpty) {
        final exists = caps.reasoningLevels.any(
          (r) => r.id == _selectedReasoningId,
        );
        if (!exists) {
          _selectedReasoningId =
              caps.currentReasoningId ??
              (caps.currentReasoningId != null
                  ? caps.reasoningLevels.first.id
                  : null);
        }
      }
      // Validate mode against capabilities
      if (caps.modes.isNotEmpty) {
        final exists = caps.modes.any((m) => m.id == _selectedModeId);
        if (!exists) {
          _selectedModeId = caps.currentModeId ?? caps.modes.first.id;
        }
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

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final settings = ChatRunSettings(
      modelId: widget.isStructuredSend ? _selectedModelId : null,
      reasoningId: widget.isStructuredSend ? _selectedReasoningId : null,
      modeId: widget.isStructuredSend ? _selectedModeId : null,
      configValues: Map<String, Object>.from(_selectedConfigValues),
      permissionPolicy: _selectedPolicy,
    );

    try {
      await widget.onSave(settings);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = widget.capabilities;
    final hasRemoteModel = caps.currentModelId != null;
    final hasRemoteReasoning = caps.currentReasoningId != null;

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
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                    // Error Banner if save failed
                    if (_errorMessage != null) ...[
                      Container(
                        key: const Key('chat_run_settings_error_banner'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: context.vDanger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          border: Border.all(
                            color: context.vDanger.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: context.vDanger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.l10n.chatRunSettingsSaveFailed(
                                  _errorMessage!,
                                ),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.vDanger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Model Selection
                    Entrance(
                      index: 0,
                      child: Text(
                        context.l10n.chatRunSettingsModel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!widget.isStructuredSend)
                      Entrance(
                        index: 0,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabled: false,
                          ),
                          child: Text(
                            context.l10n.chatRunSettingsInteractiveCli,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    else
                      Entrance(
                        index: 0,
                        child: DropdownButtonFormField<String?>(
                          key: const Key('chat_run_settings_model_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedModelId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            if (!hasRemoteModel)
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  context.l10n.chatRunSettingsDefault,
                                ),
                              ),
                            ...caps.models.map(
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
                      ),
                    const SizedBox(height: 20),

                    // Reasoning Level Selection
                    Entrance(
                      index: 1,
                      child: Text(
                        context.l10n.chatRunSettingsReasoning,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!widget.isStructuredSend)
                      Entrance(
                        index: 1,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabled: false,
                          ),
                          child: Text(
                            context.l10n.chatRunSettingsInteractiveCli,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    else
                      Entrance(
                        index: 1,
                        child: DropdownButtonFormField<String?>(
                          key: const Key(
                            'chat_run_settings_reasoning_dropdown',
                          ),
                          isExpanded: true,
                          initialValue: _selectedReasoningId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            if (!hasRemoteReasoning)
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  context.l10n.chatRunSettingsDefault,
                                ),
                              ),
                            ...caps.reasoningLevels.map(
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
                      ),
                    const SizedBox(height: 20),

                    // Agent Mode Selection (Remote Advertised Modes)
                    if (widget.isStructuredSend && caps.modes.isNotEmpty) ...[
                      Entrance(
                        index: 2,
                        child: Text(
                          context.l10n.chatRunSettingsAgentMode,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Entrance(
                        index: 2,
                        child: DropdownButtonFormField<String>(
                          key: const Key('chat_run_settings_mode_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedModeId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: caps.modes
                              .map(
                                (mode) => DropdownMenuItem<String>(
                                  value: mode.id,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        mode.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (mode.description != null &&
                                          mode.description!.isNotEmpty)
                                        Text(
                                          mode.description!,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.outline,
                                                fontSize: 11,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedModeId = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Extra Settings (Remote Toggles & Dropdowns)
                    if (widget.isStructuredSend &&
                        caps.extraSettings.isNotEmpty) ...[
                      Entrance(
                        index: 3,
                        child: Text(
                          context.l10n.chatRunSettingsExtraSettings,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...caps.extraSettings.map((extra) {
                        if (extra.isBoolean) {
                          final boolVal =
                              _selectedConfigValues[extra.id] as bool? ??
                              (extra.currentValue as bool? ?? false);
                          return SwitchListTile(
                            key: Key('chat_extra_setting_${extra.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              extra.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                            value: boolVal,
                            onChanged: (val) {
                              setState(() {
                                _selectedConfigValues[extra.id] = val;
                              });
                            },
                          );
                        } else {
                          final currentVal =
                              _selectedConfigValues[extra.id]?.toString() ??
                              extra.currentValue.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              key: Key('chat_extra_setting_${extra.id}'),
                              isExpanded: true,
                              initialValue:
                                  extra.options.any((o) => o.id == currentVal)
                                  ? currentVal
                                  : (extra.options.firstOrNull?.id ??
                                        currentVal),
                              decoration: InputDecoration(
                                labelText: extra.label,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    VRadius.input,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: extra.options.map((opt) {
                                return DropdownMenuItem<String>(
                                  value: opt.id,
                                  child: Text(
                                    opt.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedConfigValues[extra.id] = val;
                                  });
                                }
                              },
                            ),
                          );
                        }
                      }),
                      const SizedBox(height: 20),
                    ],

                    // Local Operation Permissions Policy
                    Entrance(
                      index: 4,
                      child: Text(
                        context.l10n.chatRunSettingsApprovalPolicy,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Entrance(
                      index: 4,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VRadius.card),
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
                                key: const Key(
                                  'chat_permission_ask_every_time',
                                ),
                                title: Text(
                                  context.l10n.chatPermissionAskEveryTime,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                value: OperationPermissionPolicy.askEveryTime,
                              ),
                              const Divider(height: 1),
                              RadioListTile<OperationPermissionPolicy>(
                                key: const Key(
                                  'chat_permission_auto_allow_safe',
                                ),
                                title: Text(
                                  context.l10n.chatPermissionAutoAllowSafe,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  context.l10n.chatPermissionAutoAllowSafeDesc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                value: OperationPermissionPolicy.autoAllowSafe,
                              ),
                              const Divider(height: 1),
                              RadioListTile<OperationPermissionPolicy>(
                                key: const Key(
                                  'chat_permission_auto_allow_all',
                                ),
                                title: Text(
                                  context.l10n.chatPermissionAutoAllowAll,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                value: OperationPermissionPolicy.autoAllowAll,
                              ),
                            ],
                          ),
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
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('chat_run_settings_save_button'),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.l10n.save),
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
