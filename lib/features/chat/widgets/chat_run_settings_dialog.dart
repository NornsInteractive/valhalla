import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/chat_run_settings.dart';

class ChatRunSettingsMetadata {
  final DateTime? settingsFetchedAt;
  final String? agentVersion;
  final bool settingsStale;
  final String? modelCatalogError;

  const ChatRunSettingsMetadata({
    this.settingsFetchedAt,
    this.agentVersion,
    this.settingsStale = false,
    this.modelCatalogError,
  });
}

typedef ChatRunSettingsSaveCallback = FutureOr<void> Function(ChatRunSettings);
typedef ChatRunSettingsRefreshCallback =
    Future<AgentRuntimeCapabilities?> Function();
typedef ChatRunSettingsMetadataCallback = ChatRunSettingsMetadata Function();
typedef ChatRunSettingsAuthorizeCallback = Future<void> Function();

class ChatRunSettingsDialog extends StatefulWidget {
  final ChatRunSettings initialSettings;
  final AgentRuntimeCapabilities capabilities;
  final bool isStructuredSend;
  final ChatRunSettingsSaveCallback onSave;
  final ChatRunSettingsRefreshCallback? onRefresh;
  final ChatRunSettingsMetadataCallback? onFetchMetadata;
  final DateTime? settingsFetchedAt;
  final String? agentVersion;
  final bool settingsStale;
  final String? modelCatalogError;
  final String? serverName;
  final String? containerName;
  final String? agentUserName;
  final ChatRunSettingsAuthorizeCallback? onAuthorize;
  final VoidCallback? onCancelAuthorize;

  const ChatRunSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.capabilities,
    this.isStructuredSend = true,
    required this.onSave,
    this.onRefresh,
    this.onFetchMetadata,
    this.settingsFetchedAt,
    this.agentVersion,
    this.settingsStale = false,
    this.modelCatalogError,
    this.serverName,
    this.containerName,
    this.agentUserName,
    this.onAuthorize,
    this.onCancelAuthorize,
  });

  static Future<void> show(
    BuildContext context, {
    required ChatRunSettings initialSettings,
    required AgentRuntimeCapabilities capabilities,
    bool isStructuredSend = true,
    required ChatRunSettingsSaveCallback onSave,
    ChatRunSettingsRefreshCallback? onRefresh,
    ChatRunSettingsMetadataCallback? onFetchMetadata,
    DateTime? settingsFetchedAt,
    String? agentVersion,
    bool settingsStale = false,
    String? modelCatalogError,
    String? serverName,
    String? containerName,
    String? agentUserName,
    ChatRunSettingsAuthorizeCallback? onAuthorize,
    VoidCallback? onCancelAuthorize,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ChatRunSettingsDialog(
        initialSettings: initialSettings,
        capabilities: capabilities,
        isStructuredSend: isStructuredSend,
        onSave: onSave,
        onRefresh: onRefresh,
        onFetchMetadata: onFetchMetadata,
        settingsFetchedAt: settingsFetchedAt,
        agentVersion: agentVersion,
        settingsStale: settingsStale,
        modelCatalogError: modelCatalogError,
        serverName: serverName,
        containerName: containerName,
        agentUserName: agentUserName,
        onAuthorize: onAuthorize,
        onCancelAuthorize: onCancelAuthorize,
      ),
    );
  }

  @override
  State<ChatRunSettingsDialog> createState() => _ChatRunSettingsDialogState();
}

class _ChatRunSettingsDialogState extends State<ChatRunSettingsDialog> {
  late AgentRuntimeCapabilities _capabilities;
  late DateTime? _settingsFetchedAt;
  late String? _agentVersion;
  late bool _settingsStale;
  late String? _selectedModelId;
  late bool _isCustomModel;
  late final TextEditingController _customModelController;
  String? _customModelError;
  late String? _selectedReasoningId;
  late String? _selectedModeId;
  late final Map<String, Object> _selectedConfigValues;
  late OperationPermissionPolicy _selectedPolicy;
  bool _isSaving = false;
  bool _isRefreshing = false;
  bool _isAuthorizing = false;
  String? _modelCatalogError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _capabilities = widget.capabilities;
    _settingsFetchedAt = widget.settingsFetchedAt;
    _agentVersion = widget.agentVersion;
    _settingsStale = widget.settingsStale;
    _modelCatalogError = widget.modelCatalogError;
    final caps = _capabilities;
    final initial = widget.initialSettings;

    _isCustomModel = initial.customModel;
    _customModelController = TextEditingController(
      text: _isCustomModel ? (initial.modelId ?? '') : '',
    );
    if (_isCustomModel) {
      _selectedModelId = null;
    } else {
      _selectedModelId = initial.modelId;
    }
    _selectedReasoningId = initial.reasoningId ?? caps.currentReasoningId;
    _selectedModeId = initial.modeId ?? caps.currentModeId;
    _selectedPolicy = initial.permissionPolicy;

    _selectedConfigValues = Map<String, Object>.from(initial.configValues);
    for (final extra in caps.extraSettings) {
      _selectedConfigValues[extra.id] ??= extra.currentValue;
    }

    if (widget.isStructuredSend) {
      if (!_isCustomModel) {
        // Selected model must be null/default OR an actual caps.models id.
        // NEVER use absent caps.currentModelId as fallback.
        if (caps.models.isNotEmpty) {
          final exists = caps.models.any((m) => m.id == _selectedModelId);
          if (!exists) {
            _selectedModelId = null;
          }
        } else {
          _selectedModelId = null;
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

  @override
  void dispose() {
    _customModelController.dispose();
    if (_isAuthorizing) {
      widget.onCancelAuthorize?.call();
    }
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || _isSaving || widget.onRefresh == null) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final updatedCaps = await widget.onRefresh!();
      if (!mounted) return;
      if (updatedCaps != null) {
        setState(() {
          _capabilities = updatedCaps;
          if (widget.isStructuredSend) {
            if (!_isCustomModel) {
              if (_capabilities.models.isNotEmpty) {
                final exists = _capabilities.models.any(
                  (m) => m.id == _selectedModelId,
                );
                if (!exists) {
                  _selectedModelId = null;
                }
              } else {
                _selectedModelId = null;
              }
            }
            if (_capabilities.reasoningLevels.isNotEmpty) {
              final exists = _capabilities.reasoningLevels.any(
                (r) => r.id == _selectedReasoningId,
              );
              if (!exists) {
                _selectedReasoningId =
                    _capabilities.currentReasoningId ??
                    (_capabilities.currentReasoningId != null
                        ? _capabilities.reasoningLevels.first.id
                        : null);
              }
            }
            if (_capabilities.modes.isNotEmpty) {
              final exists = _capabilities.modes.any(
                (m) => m.id == _selectedModeId,
              );
              if (!exists) {
                _selectedModeId =
                    _capabilities.currentModeId ?? _capabilities.modes.first.id;
              }
            }
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (widget.onFetchMetadata != null) {
            final meta = widget.onFetchMetadata!();
            _settingsFetchedAt = meta.settingsFetchedAt;
            _agentVersion = meta.agentVersion;
            _settingsStale = meta.settingsStale;
            _modelCatalogError = meta.modelCatalogError;
          }
        });
      }
    }
  }

  Future<void> _confirmAndAuthorize() async {
    final theme = Theme.of(context);
    final server = widget.serverName ?? '';
    final container = widget.containerName;
    final user = widget.agentUserName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatModelAuthorizeConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.chatModelAuthorizeConfirmMessage),
            const SizedBox(height: 12),
            if (server.isNotEmpty)
              Text(
                '${context.l10n.targetServerLabel}: $server',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (container != null && container.isNotEmpty)
              Text(
                '${context.l10n.agentContainerReference}: $container',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (user != null && user.isNotEmpty)
              Text(
                '${context.l10n.serverUsername}: $user',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('chat_model_authorize_confirm_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isAuthorizing = true;
      _errorMessage = null;
    });
    try {
      await widget.onAuthorize!();
      if (!mounted) return;
      await _handleRefresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthorizing = false;
        });
      }
    }
  }

  void _cancelAuthorization() {
    widget.onCancelAuthorize?.call();
    if (mounted) {
      setState(() {
        _isAuthorizing = false;
      });
    }
  }

  String _resolveModelCatalogErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('access_denied') ||
        lower.contains('agent_model_auth')) {
      return context.l10n.chatModelCatalogError403;
    }
    return context.l10n.chatModelCatalogErrorGeneric(error);
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

    String? finalModelId;
    bool isCustom = false;

    if (widget.isStructuredSend) {
      if (_isCustomModel) {
        final rawText = _customModelController.text.trim();
        if (rawText.isEmpty) {
          setState(() {
            _isSaving = false;
            _customModelError =
                context.l10n.chatRunSettingsCustomModelEmptyError;
          });
          return;
        }
        final hasWhitespaceOrControl = RegExp(
          r'[\s\x00-\x1F\x7F]',
        ).hasMatch(rawText);
        if (rawText.length > 256 || hasWhitespaceOrControl) {
          setState(() {
            _isSaving = false;
            _customModelError =
                context.l10n.chatRunSettingsCustomModelInvalidError;
          });
          return;
        }
        finalModelId = rawText;
        isCustom = true;
      } else {
        finalModelId = _selectedModelId;
        isCustom = false;
      }
    }

    final settings = ChatRunSettings(
      modelId: finalModelId,
      customModel: isCustom,
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
    final caps = _capabilities;
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
                  if (widget.onRefresh != null) ...[
                    IconButton(
                      key: const Key('chat_run_settings_refresh_button'),
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 20),
                      tooltip: context.l10n.cliRefreshSessions,
                      onPressed: (_isSaving || _isRefreshing)
                          ? null
                          : _handleRefresh,
                    ),
                  ],
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
                    // Metadata row: version, fetched time, stale status
                    if (_agentVersion != null ||
                        _settingsFetchedAt != null ||
                        _settingsStale) ...[
                      Container(
                        key: const Key('chat_run_settings_metadata_row'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (_agentVersion != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.smart_toy_outlined,
                                            size: 14,
                                            color: theme.colorScheme.outline,
                                          ),
                                          const SizedBox(width: 4),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  (constraints.maxWidth * 0.5)
                                                      .clamp(90.0, 220.0),
                                            ),
                                            child: Text(
                                              'v$_agentVersion',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_settingsFetchedAt != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 14,
                                            color: theme.colorScheme.outline,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_settingsFetchedAt!.hour.toString().padLeft(2, '0')}:${_settingsFetchedAt!.minute.toString().padLeft(2, '0')}:${_settingsFetchedAt!.second.toString().padLeft(2, '0')}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.outline,
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                if (_settingsStale)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.vWarning.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: context.vWarning.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n.chatSettingsStale,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: context.vWarning),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],

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
                    else ...[
                      Entrance(
                        index: 0,
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            key: const Key(
                              'chat_run_settings_model_source_segmented',
                            ),
                            segments: [
                              ButtonSegment<bool>(
                                value: false,
                                label: Text(
                                  context
                                      .l10n
                                      .chatRunSettingsModelSourceCatalog,
                                  key: const Key(
                                    'chat_run_settings_model_source_catalog',
                                  ),
                                ),
                                icon: const Icon(Icons.list, size: 16),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                label: Text(
                                  context.l10n.chatRunSettingsModelSourceCustom,
                                  key: const Key(
                                    'chat_run_settings_model_source_custom',
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                              ),
                            ],
                            selected: {_isCustomModel},
                            onSelectionChanged: (selected) {
                              setState(() {
                                _isCustomModel = selected.first;
                                _customModelError = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_isCustomModel) ...[
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
                            items: caps.models.isEmpty
                                ? null
                                : [
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
                            onChanged: caps.models.isEmpty
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedModelId = val;
                                    });
                                  },
                          ),
                        ),
                        if (caps.models.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            context
                                .l10n
                                .chatSettingsIndependentModelUnavailable,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.chatSettingsModelCatalogNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ] else ...[
                        Entrance(
                          index: 0,
                          child: TextField(
                            key: const Key(
                              'chat_run_settings_custom_model_input',
                            ),
                            controller: _customModelController,
                            decoration: InputDecoration(
                              hintText:
                                  context.l10n.chatRunSettingsCustomModelHint,
                              errorText: _customModelError,
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
                            onChanged: (val) {
                              if (_customModelError != null) {
                                setState(() {
                                  _customModelError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.chatRunSettingsCustomModelNotice,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                    if (_modelCatalogError != null &&
                        _modelCatalogError!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key(
                          'chat_run_settings_model_catalog_warning',
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.vWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          border: Border.all(
                            color: context.vWarning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: context.vWarning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resolveModelCatalogErrorMessage(
                                  _modelCatalogError!,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.vWarning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.onAuthorize != null) ...[
                      const SizedBox(height: 10),
                      if (_isAuthorizing)
                        Container(
                          key: const Key('chat_run_settings_authorizing_card'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(VRadius.input),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.chatModelAuthorizing,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              TextButton(
                                key: const Key(
                                  'chat_run_settings_cancel_auth_button',
                                ),
                                onPressed: _cancelAuthorization,
                                child: Text(
                                  context.l10n.chatModelAuthorizeCancel,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key(
                              'chat_run_settings_authorize_button',
                            ),
                            icon: const Icon(Icons.vpn_key_outlined, size: 16),
                            label: Text(context.l10n.chatModelAuthorizeButton),
                            onPressed: (_isSaving || _isRefreshing)
                                ? null
                                : _confirmAndAuthorize,
                          ),
                        ),
                    ],
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
                          selectedItemBuilder: (_) => caps.modes
                              .map(
                                (mode) => Text(
                                  mode.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                              .toList(),
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
              child: SizedBox(
                width: double.infinity,
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      key: const Key('chat_run_settings_cancel_button'),
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
