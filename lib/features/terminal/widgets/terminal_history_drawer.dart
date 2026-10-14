import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/terminal_provider.dart';

String _formatLastUsed(DateTime dt) {
  final local = dt.toLocal();
  final year = local.year;
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String getStartupSessionLabel(BuildContext context, SshTerminalState state) {
  final l10n = context.l10n;
  final defaultId = state.defaultHistoryId;
  if (defaultId == null) {
    return l10n.terminalStartupSessionFresh;
  }
  final record = state.history.where((r) => r.id == defaultId).firstOrNull;
  if (record != null) {
    return record.title;
  }
  return l10n.terminalStartupSessionFresh;
}

class _TerminalRenameDialog extends StatefulWidget {
  final String initialTitle;
  final Future<void> Function(String validTitle) onConfirm;

  const _TerminalRenameDialog({
    required this.initialTitle,
    required this.onConfirm,
  });

  @override
  State<_TerminalRenameDialog> createState() => _TerminalRenameDialogState();
}

class _TerminalRenameDialogState extends State<_TerminalRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final String validTitle;
    try {
      validTitle = TerminalHistoryRecord.validateTitle(_controller.text);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = context.l10n.terminalTitleInvalid);
      }
      return;
    }

    final route = ModalRoute.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(validTitle);
      if (mounted && (route?.isCurrent ?? false)) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted && (route?.isCurrent ?? false)) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.l10n.terminalErrorHistorySaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.terminalRenameDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 64,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.terminalRenameInputLabel,
              errorText: _errorMessage,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}

Future<void> showRenameHistoryDialog(
  BuildContext context,
  WidgetRef ref,
  TerminalHistoryRecord record,
) async {
  final activeServer = ref.read(activeServerProvider);
  final expectedTarget = activeServer == null
      ? null
      : TerminalHistoryRecord.targetFor(activeServer);

  await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _TerminalRenameDialog(
      initialTitle: record.title,
      onConfirm: (validTitle) async {
        final currentServer = ref.read(activeServerProvider);
        final currentTarget = currentServer == null
            ? null
            : TerminalHistoryRecord.targetFor(currentServer);
        if (currentTarget != expectedTarget) {
          throw StateError('TARGET_CHANGED');
        }
        await ref
            .read(terminalProvider.notifier)
            .renameHistory(record.id, validTitle);
      },
    ),
  );
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> showRenameTabDialog(
  BuildContext context,
  WidgetRef ref,
  String tabId,
  String currentTitle,
) async {
  final activeServer = ref.read(activeServerProvider);
  final expectedTarget = activeServer == null
      ? null
      : TerminalHistoryRecord.targetFor(activeServer);

  await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _TerminalRenameDialog(
      initialTitle: currentTitle,
      onConfirm: (validTitle) async {
        final currentServer = ref.read(activeServerProvider);
        final currentTarget = currentServer == null
            ? null
            : TerminalHistoryRecord.targetFor(currentServer);
        if (currentTarget != expectedTarget) {
          throw StateError('TARGET_CHANGED');
        }
        await ref.read(terminalProvider.notifier).renameTab(tabId, validTitle);
      },
    ),
  );
  FocusManager.instance.primaryFocus?.unfocus();
}

class _StartupSessionDialog extends ConsumerStatefulWidget {
  final String expectedTarget;
  final String? initialDefaultId;
  final List<TerminalHistoryRecord> candidateRecords;

  const _StartupSessionDialog({
    required this.expectedTarget,
    required this.initialDefaultId,
    required this.candidateRecords,
  });

  @override
  ConsumerState<_StartupSessionDialog> createState() =>
      _StartupSessionDialogState();
}

class _StartupSessionDialogState extends ConsumerState<_StartupSessionDialog> {
  late String? _selectedId = widget.initialDefaultId;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _selectSession(String? newId) async {
    if (_isSubmitting) return;

    final currentServer = ref.read(activeServerProvider);
    final currentTarget = currentServer == null
        ? null
        : TerminalHistoryRecord.targetFor(currentServer);
    if (currentTarget != widget.expectedTarget) {
      if (mounted) {
        setState(() => _errorMessage = context.l10n.remoteBrowserTargetChanged);
      }
      return;
    }

    final route = ModalRoute.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _selectedId = newId;
    });

    try {
      await ref.read(terminalProvider.notifier).setDefaultHistory(newId);
      if (mounted && (route?.isCurrent ?? false)) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted && (route?.isCurrent ?? false)) {
        setState(() {
          _isSubmitting = false;
          _selectedId = widget.initialDefaultId;
          _errorMessage = context.l10n.terminalErrorDefaultSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.terminalStartupSession),
      contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
      content: SizedBox(
        width: math.min(360.0, MediaQuery.sizeOf(context).width * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.vDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 12, color: context.vDanger),
                    ),
                  ),
                ),
              RadioGroup<String?>(
                groupValue: _selectedId,
                onChanged: _selectSession,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String?>(
                      key: const Key('terminal_startup_session_fresh_option'),
                      value: null,
                      title: Text(
                        l10n.terminalStartupSessionFresh,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.candidateRecords.isNotEmpty)
                      const Divider(height: 1),
                    for (final record in widget.candidateRecords)
                      RadioListTile<String?>(
                        key: ValueKey('terminal_startup_session_${record.id}'),
                        value: record.id,
                        title: Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatLastUsed(record.lastUsedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

Future<void> showStartupSessionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final activeServer = ref.read(activeServerProvider);
  if (activeServer == null) return;
  final expectedTarget = TerminalHistoryRecord.targetFor(activeServer);

  final terminalState = ref.read(terminalProvider);
  final currentDefaultId = terminalState.defaultHistoryId;

  // Filter recoverable sessions: exclude ended sessions and unverified legacy sessions.
  final candidateRecords = terminalState.history.where((record) {
    if (record.isLegacy) {
      return terminalState.historyStatuses[record.id] ==
          TerminalHistoryStatus.available;
    }
    return terminalState.historyStatuses[record.id] !=
        TerminalHistoryStatus.ended;
  }).toList();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _StartupSessionDialog(
      expectedTarget: expectedTarget,
      initialDefaultId: currentDefaultId,
      candidateRecords: candidateRecords,
    ),
  );
  FocusManager.instance.primaryFocus?.unfocus();
}

class TerminalHistoryDrawer extends ConsumerWidget {
  const TerminalHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalState = ref.watch(terminalProvider);
    final width = math.min(360.0, MediaQuery.sizeOf(context).width * 0.85);
    final l10n = context.l10n;
    final activeServer = ref.watch(activeServerProvider);
    final targetKey = activeServer == null
        ? ''
        : TerminalHistoryRecord.targetFor(activeServer);

    return Drawer(
      width: width,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 22,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.terminalHistoryTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (terminalState.isHistoryLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: l10n.terminalHistoryRefresh,
                    onPressed: terminalState.isHistoryLoading
                        ? null
                        : () => ref
                              .read(terminalProvider.notifier)
                              .refreshHistory(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('terminal_history_startup_session_tile'),
              dense: true,
              leading: const Icon(Icons.play_circle_outline, size: 22),
              title: Text(
                l10n.terminalStartupSession,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                getStartupSessionLabel(context, terminalState),
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 16),
              onTap: () => showStartupSessionDialog(context, ref),
            ),
            const Divider(height: 1),
            Expanded(
              child: terminalState.history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 40,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.terminalHistoryEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: terminalState.history.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = terminalState.history[index];
                        final status =
                            terminalState.historyStatuses[record.id] ??
                            TerminalHistoryStatus.unknown;
                        final isDefault =
                            terminalState.defaultHistoryId == record.id;

                        final Color statusColor;
                        final String statusLabel;
                        switch (status) {
                          case TerminalHistoryStatus.open:
                            statusColor = context.vSuccess;
                            statusLabel = l10n.terminalStatusOpen;
                          case TerminalHistoryStatus.available:
                            statusColor = context.colorScheme.primary;
                            statusLabel = l10n.terminalStatusAvailable;
                          case TerminalHistoryStatus.ended:
                            statusColor = context.colorScheme.outline;
                            statusLabel = l10n.terminalStatusEnded;
                          case TerminalHistoryStatus.unknown:
                            statusColor = context.vWarning;
                            statusLabel = l10n.terminalStatusOffline;
                        }

                        return ListTile(
                          dense: true,
                          enabled: status != TerminalHistoryStatus.ended,
                          title: Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'JetBrains Mono',
                              color: status == TerminalHistoryStatus.ended
                                  ? context.colorScheme.outline
                                  : null,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  _formatLastUsed(record.lastUsedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colorScheme.outline,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                if (isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          context.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l10n.terminalDefaultBadge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: context
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                if (record.isLegacy)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l10n.terminalLegacyBadge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: context.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          onTap: status == TerminalHistoryStatus.ended
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.of(context).pop();
                                  ref
                                      .read(terminalProvider.notifier)
                                      .restoreHistory(record.id);
                                },
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).showMenuTooltip,
                            onSelected: (value) async {
                              final currentServer = ref.read(
                                activeServerProvider,
                              );
                              final currentTarget = currentServer == null
                                  ? ''
                                  : TerminalHistoryRecord.targetFor(
                                      currentServer,
                                    );
                              if (currentTarget != targetKey) return;

                              switch (value) {
                                case 'restore':
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.of(context).pop();
                                  await ref
                                      .read(terminalProvider.notifier)
                                      .restoreHistory(record.id);
                                case 'set_default':
                                  try {
                                    await ref
                                        .read(terminalProvider.notifier)
                                        .setDefaultHistory(record.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.terminalErrorDefaultSaveFailed,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                case 'clear_default':
                                  try {
                                    await ref
                                        .read(terminalProvider.notifier)
                                        .setDefaultHistory(null);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.terminalErrorDefaultSaveFailed,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                case 'rename':
                                  await showRenameHistoryDialog(
                                    context,
                                    ref,
                                    record,
                                  );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'restore',
                                enabled: status != TerminalHistoryStatus.ended,
                                child: Row(
                                  children: [
                                    const Icon(Icons.launch, size: 16),
                                    const SizedBox(width: 8),
                                    Text(l10n.terminalRestoreSession),
                                  ],
                                ),
                              ),
                              if (isDefault)
                                PopupMenuItem(
                                  value: 'clear_default',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bookmark_remove_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(l10n.terminalClearDefault),
                                    ],
                                  ),
                                )
                              else
                                PopupMenuItem(
                                  value: 'set_default',
                                  enabled:
                                      status != TerminalHistoryStatus.ended,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bookmark_border,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(l10n.terminalSetDefault),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.drive_file_rename_outline,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.terminalRename),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
