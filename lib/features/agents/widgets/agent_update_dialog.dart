import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/agent_update_provider.dart';
import '../../../data/models/agent_profile.dart';

/// Confirmation and execution dialog for updating agent components.
class AgentUpdateDialog extends ConsumerStatefulWidget {
  final AgentProfile profile;
  final AgentUpdatePlan? initialPlan;
  final Set<AgentUpdateComponent>? selectedComponents;

  const AgentUpdateDialog({
    super.key,
    required this.profile,
    this.initialPlan,
    this.selectedComponents,
  });

  static Future<void> show(
    BuildContext context, {
    required AgentProfile profile,
    AgentUpdatePlan? initialPlan,
    Set<AgentUpdateComponent>? selectedComponents,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      ProviderScope.containerOf(
        context,
      ).read(agentUpdatesProvider.notifier).dismissUpdateNotice();
    } catch (_) {}
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgentUpdateDialog(
        profile: profile,
        initialPlan: initialPlan,
        selectedComponents: selectedComponents,
      ),
    ).then((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  ConsumerState<AgentUpdateDialog> createState() => _AgentUpdateDialogState();
}

class _AgentUpdateDialogState extends ConsumerState<AgentUpdateDialog> {
  AgentUpdatePlan? _plan;
  bool _isPreparing = false;
  String? _prepareError;
  bool _isApplying = false;
  String? _applyError;
  bool _isSuccess = false;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPlan != null) {
      _plan = widget.initialPlan;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preparePlan();
      });
    }
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _preparePlan() async {
    if (!mounted) return;
    setState(() {
      _isPreparing = true;
      _prepareError = null;
      _applyError = null;
    });
    try {
      final plan = await ref
          .read(agentUpdatesProvider.notifier)
          .prepareUpdate(
            widget.profile.id,
            components: widget.selectedComponents,
          );
      if (mounted) {
        setState(() {
          _plan = plan;
          _isPreparing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _prepareError = _localizeError(e);
        });
      }
    }
  }

  String _localizeError(Object error) {
    final l10n = context.l10n;
    if (error is AgentUpdateException) {
      switch (error.code) {
        case 'SSH_DISCONNECTED':
          return l10n.serverDisconnected;
        case 'AGENT_UPDATE_BUSY':
          return l10n.agentUpdateBusy;
        case 'AGENT_UPDATE_IN_PROGRESS':
          return l10n.agentUpdateInProgress;
        case 'AGENT_UPDATE_TARGET_CHANGED':
          return l10n.agentUpdateFailed;
        default:
          return l10n.agentUpdateFailed;
      }
    }
    return l10n.agentUpdateFailed;
  }

  Future<void> _handleApply() async {
    final plan = _plan;
    if (plan == null || _isApplying) return;

    setState(() {
      _isApplying = true;
      _applyError = null;
    });

    try {
      await ref.read(agentUpdatesProvider.notifier).applyConfirmedUpdate(plan);
      if (mounted) {
        setState(() {
          _isApplying = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
          _plan = null;
          _applyError = _localizeError(e);
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final updateEntry = ref.watch(
      agentUpdatesProvider.select((s) => s.agents[widget.profile.id]),
    );
    final isEntryUpdating = updateEntry?.isUpdating ?? false;
    final isBusy = _isApplying || isEntryUpdating;
    final logText = updateEntry?.log ?? '';
    final isInterrupted = !isBusy && (updateEntry?.interrupted ?? false);

    if (isBusy && logText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final hasClaudeMigration =
        _plan?.components.any((c) => c.migratesClaudeAdapter) ?? false;
    final codexMigrationComp = _plan?.components.where(
      (c) =>
          c.reasonCode == 'AGENT_UPDATE_CODEX_ADAPTER_MIGRATION' ||
          c.replacementAcpCommand != null,
    ).firstOrNull;
    final isAgy =
        widget.profile.id == 'builtin-agy' ||
        widget.profile.cliCommand == 'agy';

    return PopScope(
      canPop: !isBusy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actionsOverflowButtonSpacing: 4,
        title: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              color: context.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.agentUpdateDialogTitle,
                style: context.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isPreparing) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.agentUpdateChecking,
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (_prepareError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.vDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(
                      color: context.vDanger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: context.vDanger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _prepareError!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.vDanger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _preparePlan,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.stateRetry),
                ),
              ] else if (_plan != null) ...[
                // Target info
                Text(
                  '${l10n.agentUpdateTargetServer}: ${_plan!.server.name} (${_plan!.server.host})',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.agentUpdateTargetEnvironment}: ${_plan!.resolvedContainerId ?? _plan!.profile.containerReference ?? l10n.agentExecutionHost}'
                  '${_plan!.profile.containerUser != null && _plan!.profile.containerUser!.isNotEmpty ? ' (${_plan!.profile.containerUser})' : ''}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.agentUpdateTargetIdentity}: ${_plan!.runtimeIdentity}',
                  style: monoTextStyle(
                    fontSize: 11,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                ),
                const Divider(height: 20),

                // Components diff
                for (final comp in _plan!.components) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    context.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  VRadius.input,
                                ),
                              ),
                              child: Text(
                                comp.component == AgentUpdateComponent.cli
                                    ? 'CLI'
                                    : 'ACP',
                                style: monoTextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${comp.installedVersion ?? l10n.agentUpdateVersionUnknown} → ${comp.latestVersion ?? l10n.agentUpdateVersionUnknown}',
                                style: monoTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.vSuccess,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        if (comp.source != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            comp.source!,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (hasClaudeMigration) ...[
                  const SizedBox(height: 12),
                  Container(
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
                          Icons.info_outline,
                          color: context.vWarning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.agentUpdateClaudeMigrationNotice,
                            style: context.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (codexMigrationComp != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('agent_update_codex_migration_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer.withValues(
                        alpha: 0.25,
                      ),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: context.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.agentUpdateCodexMigrationTitle,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.agentUpdateCodexMigrationNotice,
                          style: context.textTheme.bodySmall,
                        ),
                        if (codexMigrationComp.replacementAcpCommand != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.agentUpdateReplacementCommand,
                            style: context.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF07080B)
                                      : const Color(0xFF1A1E26),
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            child: SelectableText(
                              codexMigrationComp.replacementAcpCommand!,
                              style: monoTextStyle(
                                fontSize: 11,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (isAgy) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.agentUpdateAgyNotice,
                            style: context.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_plan!.commandPreview.isNotEmpty &&
                    !_isSuccess &&
                    !isBusy) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.agentUpdateCommandPreview,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF07080B)
                          : const Color(0xFF1A1E26),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _plan!.commandPreview,
                        style: monoTextStyle(
                          fontSize: 11,
                          color: context.vSuccess,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              if (logText.isNotEmpty ||
                  isBusy ||
                  _isSuccess ||
                  _applyError != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.agentUpdateLogs,
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('agent_update_copy_log_button'),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: l10n.agentUpdateCopyLog,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: logText.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: logText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.agentUpdateLogCopied),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF07080B)
                        : const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                  child: SingleChildScrollView(
                    controller: _logScrollController,
                    child: SelectableText(
                      logText.isEmpty && isBusy ? '...' : logText,
                      style: monoTextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ),
              ],

              if (isInterrupted) ...[
                const SizedBox(height: 12),
                Container(
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
                        color: context.vWarning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.agentUpdateInterrupted,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_applyError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.vDanger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(
                      color: context.vDanger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: context.vDanger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _applyError!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.vDanger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _preparePlan,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.stateRetry),
                ),
              ],

              if (_isSuccess) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.vSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(
                      color: context.vSuccess.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: context.vSuccess,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.agentUpdateSuccess,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.vSuccess,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            key: const Key('agent_update_dialog_cancel_button'),
            onPressed: isBusy
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(context);
                  },
            child: Text(
              _isSuccess
                  ? MaterialLocalizations.of(context).closeButtonTooltip
                  : l10n.agentUpdateCancelButton,
            ),
          ),
          if (!_isSuccess)
            FilledButton(
              key: const Key('agent_confirm_update_button'),
              onPressed: (isBusy || _plan == null || _prepareError != null)
                  ? null
                  : _handleApply,
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.agentUpdateConfirmButton),
            ),
        ],
      ),
    );
  }
}
