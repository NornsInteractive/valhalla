import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/terminal_provider.dart';
import '../../../infrastructure/mosh/mosh_bridge_adapter.dart';
import '../../../infrastructure/terminal/terminal_session_bridge.dart'
    show TerminalConnectionState, TerminalSessionMode;

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

String _terminalL10n(BuildContext context, String key, String fallback) {
  try {
    final dynamic l10n = context.l10n;
    final val =
        switch (key) {
              'terminalHistoryDeleteDialogTitle' =>
                l10n.terminalHistoryDeleteDialogTitle,
              'terminalHistoryTerminateRemote' =>
                l10n.terminalHistoryTerminateRemote,
              'terminalHistoryTerminateConfirmTitle' =>
                l10n.terminalHistoryTerminateConfirmTitle,
              'terminalHistoryTerminateConfirmMessage' =>
                l10n.terminalHistoryTerminateConfirmMessage,
              'terminalErrorHistoryDeleteFailed' =>
                l10n.terminalErrorHistoryDeleteFailed,
              'terminalErrorHistoryTerminateFailed' =>
                l10n.terminalErrorHistoryTerminateFailed,
              'terminalErrorTargetChanged' => l10n.terminalErrorTargetChanged,
              _ => null,
            }
            as String?;
    if (val != null && val.isNotEmpty) return val;
  } catch (_) {}
  return fallback;
}

class _TerminalDeleteDialog extends StatefulWidget {
  final TerminalHistoryRecord record;
  final String serverLabel;
  final bool canTerminateRemote;
  final Future<void> Function(bool terminateRemote) onConfirm;

  const _TerminalDeleteDialog({
    required this.record,
    required this.serverLabel,
    required this.canTerminateRemote,
    required this.onConfirm,
  });

  @override
  State<_TerminalDeleteDialog> createState() => _TerminalDeleteDialogState();
}

class _TerminalDeleteDialogState extends State<_TerminalDeleteDialog> {
  bool _terminateRemote = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_terminateRemote) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            _terminalL10n(
              ctx,
              'terminalHistoryTerminateConfirmTitle',
              'Terminate Remote Session?',
            ),
          ),
          content: Text(
            _terminalL10n(
              ctx,
              'terminalHistoryTerminateConfirmMessage',
              'This will terminate the remote tmux session and end all processes running inside it.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.vDanger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    final route = ModalRoute.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_terminateRemote);
      if (!mounted) return;
      if (route?.isCurrent ?? false) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      if (route?.isCurrent ?? false) {
        final err = e.toString();
        final msg = err.contains('TERMINAL_HISTORY_TARGET_CHANGED')
            ? _terminalL10n(
                context,
                'terminalErrorTargetChanged',
                context.l10n.remoteBrowserTargetChanged,
              )
            : err.contains('TERMINAL_HISTORY_TERMINATE_FAILED')
            ? _terminalL10n(
                context,
                'terminalErrorHistoryTerminateFailed',
                'Failed to terminate remote session',
              )
            : _terminalL10n(
                context,
                'terminalErrorHistoryDeleteFailed',
                'Failed to delete terminal history',
              );
        setState(() {
          _isSubmitting = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        _terminalL10n(
          context,
          'terminalHistoryDeleteDialogTitle',
          'Delete Session History',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.record.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.serverLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.serverLabel,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _terminalL10n(
                context,
                'terminalHistoryTerminateRemote',
                'Also terminate remote server session',
              ),
              style: TextStyle(
                fontSize: 13,
                color: widget.canTerminateRemote
                    ? null
                    : theme.colorScheme.outline,
              ),
            ),
            subtitle: !widget.canTerminateRemote
                ? Text(
                    l10n.terminalStatusOffline,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  )
                : null,
            value: _terminateRemote,
            onChanged: widget.canTerminateRemote && !_isSubmitting
                ? (val) => setState(() => _terminateRemote = val ?? false)
                : null,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.vDanger),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.delete),
        ),
      ],
    );
  }
}

Future<void> showDeleteHistoryDialog(
  BuildContext context,
  WidgetRef ref,
  TerminalHistoryRecord record,
) async {
  final activeServer = ref.read(activeServerProvider);
  final isConnected = ref.read(serverConnectionProvider).isConnected;
  final currentTarget = activeServer == null
      ? null
      : TerminalHistoryRecord.targetFor(activeServer);

  final terminalState = ref.read(terminalProvider);
  final status =
      terminalState.historyStatuses[record.id] ?? TerminalHistoryStatus.unknown;

  final canTerminateRemote =
      isConnected &&
      currentTarget == record.targetKey &&
      status != TerminalHistoryStatus.ended &&
      status != TerminalHistoryStatus.unknown;

  final serverLabel = activeServer?.name.isNotEmpty == true
      ? activeServer!.name
      : (activeServer?.host ?? '');

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _TerminalDeleteDialog(
      record: record,
      serverLabel: serverLabel,
      canTerminateRemote: canTerminateRemote,
      onConfirm: (terminateRemote) async {
        await ref
            .read(terminalProvider.notifier)
            .deleteHistory(
              record.id,
              terminateRemote: terminateRemote,
              expectedTargetKey: record.targetKey,
            );
      },
    ),
  );
  if (result == true && context.mounted) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
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

class _TerminalGroupItem {
  final String title;
  final int count;
  final Color color;
  const _TerminalGroupItem(this.title, this.count, this.color);
}

class TerminalHistoryDrawer extends ConsumerStatefulWidget {
  const TerminalHistoryDrawer({super.key});

  @override
  ConsumerState<TerminalHistoryDrawer> createState() =>
      _TerminalHistoryDrawerState();
}

class _TerminalHistoryDrawerState extends ConsumerState<TerminalHistoryDrawer> {
  String _searchQuery = '';
  late final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildGroupHeader(
    BuildContext context,
    String title,
    int count,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: context.colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n.terminalHistorySearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VRadius.input),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: () {
                final allRecords = terminalState.history;
                final filteredHistory = _searchQuery.isEmpty
                    ? allRecords
                    : allRecords
                        .where(
                          (r) => r.title.toLowerCase().contains(_searchQuery),
                        )
                        .toList();

                final matchingTabs = _searchQuery.isEmpty
                    ? terminalState.tabs
                    : terminalState.tabs
                        .where(
                          (t) => t.title.toLowerCase().contains(_searchQuery),
                        )
                        .toList();

                if (matchingTabs.isEmpty && filteredHistory.isEmpty) {
                  return Center(
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
                            terminalState.tabs.isEmpty && allRecords.isEmpty
                                ? l10n.terminalHistoryEmpty
                                : l10n.stateEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final openTabIds = terminalState.tabs.map((t) => t.id).toSet();

                final recoverableRecords =
                    filteredHistory.where((r) {
                        if (openTabIds.contains(r.id)) return false;
                        final s =
                            terminalState.historyStatuses[r.id] ??
                            TerminalHistoryStatus.unknown;
                        return s == TerminalHistoryStatus.available ||
                            s == TerminalHistoryStatus.unknown ||
                            s == TerminalHistoryStatus.open;
                      }).toList()
                      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

                final endedRecords =
                    filteredHistory.where((r) {
                        if (openTabIds.contains(r.id)) return false;
                        final s =
                            terminalState.historyStatuses[r.id] ??
                            TerminalHistoryStatus.unknown;
                        return s == TerminalHistoryStatus.ended;
                      }).toList()
                      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

                final sortedItems = <dynamic>[
                  if (matchingTabs.isNotEmpty) ...[
                    _TerminalGroupItem(
                      l10n.terminalStatusOpen,
                      matchingTabs.length,
                      context.vSuccess,
                    ),
                    ...matchingTabs,
                  ],
                  if (recoverableRecords.isNotEmpty) ...[
                    _TerminalGroupItem(
                      l10n.terminalRestoreSession,
                      recoverableRecords.length,
                      context.colorScheme.primary,
                    ),
                    ...recoverableRecords,
                  ],
                  if (endedRecords.isNotEmpty) ...[
                    _TerminalGroupItem(
                      l10n.terminalStatusEnded,
                      endedRecords.length,
                      context.colorScheme.outline,
                    ),
                    ...endedRecords,
                  ],
                ];

                return ListView.separated(
                  itemCount: sortedItems.length,
                  separatorBuilder: (_, index) {
                    if (index + 1 < sortedItems.length &&
                        sortedItems[index + 1] is _TerminalGroupItem) {
                      return const SizedBox.shrink();
                    }
                    return const Divider(height: 1);
                  },
                  itemBuilder: (context, index) {
                    final item = sortedItems[index];
                    if (item is _TerminalGroupItem) {
                      return _buildGroupHeader(
                        context,
                        item.title,
                        item.count,
                        item.color,
                      );
                    }
                    if (item is TerminalTab) {
                      return _buildCurrentTabTile(
                        context,
                        item,
                        terminalState,
                        targetKey,
                      );
                    }
                    final record = item as TerminalHistoryRecord;
                    final status =
                        terminalState.historyStatuses[record.id] ??
                        TerminalHistoryStatus.unknown;
                    final isDefault =
                        terminalState.defaultHistoryId == record.id;
                    final matchingTab = terminalState.tabs
                        .where((t) => t.id == record.id)
                        .firstOrNull;

                    final Color statusColor;
                    final String statusLabel;
                    if (matchingTab != null) {
                      switch (matchingTab.bridge.state) {
                        case TerminalConnectionState.connected:
                          statusColor = context.vSuccess;
                          statusLabel = l10n.terminalStatusOpen;
                        case TerminalConnectionState.connecting:
                          statusColor = context.colorScheme.primary;
                          statusLabel = l10n.serverConnecting;
                        case TerminalConnectionState.disconnected:
                        case TerminalConnectionState.error:
                          statusColor = context.vWarning;
                          statusLabel = l10n.terminalStatusOffline;
                      }
                    } else {
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
                    }

                    final isEnded =
                        matchingTab == null &&
                        status == TerminalHistoryStatus.ended;

                    return ListTile(
                      dense: true,
                      enabled: !isEnded,
                      title: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'JetBrains Mono',
                          color: isEnded ? context.colorScheme.outline : null,
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
                                  color: context.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.terminalDefaultBadge,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        context.colorScheme.onPrimaryContainer,
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
                      onTap: isEnded
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.of(context).pop();
                              if (matchingTab != null) {
                                final tabIndex =
                                    terminalState.tabs.indexOf(matchingTab);
                                if (tabIndex >= 0) {
                                  ref
                                      .read(terminalProvider.notifier)
                                      .selectTab(tabIndex);
                                  return;
                                }
                              }
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
                          final currentServer = ref.read(activeServerProvider);
                          final currentTarget = currentServer == null
                              ? ''
                              : TerminalHistoryRecord.targetFor(currentServer);
                          if (currentTarget != targetKey) return;

                          switch (value) {
                            case 'close_tab':
                              if (matchingTab != null) {
                                final tabIndex =
                                    terminalState.tabs.indexOf(matchingTab);
                                if (tabIndex >= 0) {
                                  ref
                                      .read(terminalProvider.notifier)
                                      .closeTab(tabIndex);
                                }
                              }
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
                            case 'delete':
                              await showDeleteHistoryDialog(
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
                              enabled: status != TerminalHistoryStatus.ended,
                              child: Row(
                                children: [
                                  const Icon(Icons.bookmark_border, size: 16),
                                  const SizedBox(width: 8),
                                  Text(l10n.terminalSetDefault),
                                ],
                              ),
                            ),
                          if (matchingTab != null &&
                              terminalState.tabs.length > 1)
                            PopupMenuItem(
                              value: 'close_tab',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.close,
                                    size: 16,
                                    color: context.vDanger,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.terminalCloseTab,
                                    style: TextStyle(color: context.vDanger),
                                  ),
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
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: context.vDanger,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.delete,
                                  style: TextStyle(color: context.vDanger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabTile(
    BuildContext context,
    TerminalTab tab,
    SshTerminalState terminalState,
    String targetKey,
  ) {
    final l10n = context.l10n;
    final isSelected = terminalState.activeTabIndex >= 0 &&
        terminalState.activeTabIndex < terminalState.tabs.length &&
        terminalState.tabs[terminalState.activeTabIndex].id == tab.id;

    final Color statusColor;
    final String statusLabel;
    switch (tab.bridge.state) {
      case TerminalConnectionState.connected:
        statusColor = context.vSuccess;
        statusLabel = l10n.terminalStatusOpen;
      case TerminalConnectionState.connecting:
        statusColor = context.colorScheme.primary;
        statusLabel = l10n.serverConnecting;
      case TerminalConnectionState.disconnected:
      case TerminalConnectionState.error:
        statusColor = context.vWarning;
        statusLabel = l10n.terminalStatusOffline;
    }

    final String modeLabel;
    if (tab.bridge.mode == TerminalSessionMode.tmux) {
      modeLabel = 'tmux';
    } else if (tab.bridge is MoshBridgeAdapter) {
      modeLabel = 'Mosh';
    } else {
      modeLabel = 'SSH';
    }

    return ListTile(
      dense: true,
      selected: isSelected,
      leading: Icon(
        tab.bridge.mode == TerminalSessionMode.tmux
            ? Icons.layers_outlined
            : (tab.bridge is MoshBridgeAdapter
                ? Icons.bolt_rounded
                : Icons.terminal),
        size: 18,
        color: isSelected
            ? context.colorScheme.primary
            : context.colorScheme.outline,
      ),
      title: Text(
        tab.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'JetBrains Mono',
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                modeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
          ],
        ),
      ),
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
        final tabIndex = terminalState.tabs.indexOf(tab);
        if (tabIndex >= 0) {
          ref.read(terminalProvider.notifier).selectTab(tabIndex);
        }
      },
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        onSelected: (value) async {
          final currentServer = ref.read(activeServerProvider);
          final currentTarget = currentServer == null
              ? ''
              : TerminalHistoryRecord.targetFor(currentServer);
          if (currentTarget != targetKey) return;

          switch (value) {
            case 'rename':
              await showRenameTabDialog(context, ref, tab.id, tab.title);
            case 'close_tab':
              final tabIndex = terminalState.tabs.indexOf(tab);
              if (tabIndex >= 0) {
                ref.read(terminalProvider.notifier).closeTab(tabIndex);
              }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 16),
                const SizedBox(width: 8),
                Text(l10n.rename),
              ],
            ),
          ),
          if (terminalState.tabs.length > 1)
            PopupMenuItem(
              value: 'close_tab',
              child: Row(
                children: [
                  Icon(Icons.close, size: 16, color: context.vDanger),
                  const SizedBox(width: 8),
                  Text(
                    l10n.terminalCloseTab,
                    style: TextStyle(color: context.vDanger),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
