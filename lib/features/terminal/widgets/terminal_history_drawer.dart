import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

String _formatSocketBadge(TmuxSocketSource socket) {
  switch (socket.kind) {
    case TmuxSocketKind.app:
      return 'app:valhalla';
    case TmuxSocketKind.standard:
      return 'default';
    case TmuxSocketKind.named:
      return '-L ${socket.value}';
    case TmuxSocketKind.path:
      return '-S ${socket.value}';
  }
}

String getStartupSessionLabel(BuildContext context, SshTerminalState state) {
  final l10n = context.l10n;
  final defaultId = state.defaultHistoryId;
  if (defaultId == null) {
    return l10n.terminalStartupSessionFresh;
  }
  if (state.hiddenRecordIds.contains(defaultId)) {
    return l10n.terminalStartupSessionFresh;
  }
  final record = state.history.where((r) => r.id == defaultId).firstOrNull;
  if (record != null) {
    final status =
        state.historyStatuses[record.id] ?? TerminalHistoryStatus.unknown;
    if (status == TerminalHistoryStatus.ended ||
        status == TerminalHistoryStatus.unavailable) {
      return l10n.terminalStartupSessionFresh;
    }
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

class _TerminalTerminateDialog extends StatefulWidget {
  final TerminalHistoryRecord record;
  final String serverLabel;
  final Future<void> Function() onConfirm;

  const _TerminalTerminateDialog({
    required this.record,
    required this.serverLabel,
    required this.onConfirm,
  });

  @override
  State<_TerminalTerminateDialog> createState() =>
      _TerminalTerminateDialogState();
}

class _TerminalTerminateDialogState extends State<_TerminalTerminateDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final route = ModalRoute.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm();
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
            ? context.l10n.terminalErrorTargetChanged
            : context.l10n.terminalErrorHistoryTerminateFailed;
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
    final record = widget.record;

    return AlertDialog(
      title: Text(l10n.terminalHistoryTerminateConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.terminalHistoryTerminateConfirmMessage,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    context,
                    l10n.terminalServerLabel,
                    widget.serverLabel,
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(context, 'Session', record.remoteSessionName),
                  if (record.title != record.remoteSessionName) ...[
                    const SizedBox(height: 6),
                    _buildDetailRow(context, 'Title', record.title),
                  ],
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    context,
                    l10n.terminalSocketLabel,
                    _formatSocketBadge(record.socket),
                  ),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    context,
                    'Clients',
                    '${record.attachedClients}',
                  ),
                ],
              ),
            ),
            if (record.attachedClients > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.vDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.vDanger.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.vDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.terminalTerminateClientsWarning(
                          record.attachedClients,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.vDanger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
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
              : Text(l10n.terminalTerminateSession),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

Future<void> showTerminateSessionDialog(
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

  if (activeServer == null ||
      !isConnected ||
      currentTarget != record.targetKey ||
      status == TerminalHistoryStatus.ended ||
      status == TerminalHistoryStatus.unavailable ||
      status == TerminalHistoryStatus.unknown) {
    return;
  }

  final serverLabel = activeServer.name.isNotEmpty
      ? '${activeServer.name} (${activeServer.host})'
      : '${activeServer.username}@${activeServer.host}:${activeServer.port}';

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _TerminalTerminateDialog(
      record: record,
      serverLabel: serverLabel,
      onConfirm: () async {
        await ref
            .read(terminalProvider.notifier)
            .deleteHistory(
              record.id,
              terminateRemote: true,
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
                          '${_formatLastUsed(record.lastUsedAt)} • ${_formatSocketBadge(record.socket)}',
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

  final candidateRecords = terminalState.history.where((record) {
    if (terminalState.hiddenRecordIds.contains(record.id)) return false;
    final status =
        terminalState.historyStatuses[record.id] ??
        TerminalHistoryStatus.unknown;
    if (status == TerminalHistoryStatus.ended ||
        status == TerminalHistoryStatus.unavailable) {
      return false;
    }
    if (record.isLegacy) {
      return status == TerminalHistoryStatus.available;
    }
    return true;
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

class _TmuxSourcesDialog extends ConsumerStatefulWidget {
  final String expectedTarget;

  const _TmuxSourcesDialog({required this.expectedTarget});

  @override
  ConsumerState<_TmuxSourcesDialog> createState() => _TmuxSourcesDialogState();
}

class _TmuxSourcesDialogState extends ConsumerState<_TmuxSourcesDialog> {
  final TextEditingController _inputController = TextEditingController();
  TmuxSocketKind _selectedKind = TmuxSocketKind.named;
  bool _isAdding = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final rawText = _inputController.text.trim();
    if (rawText.isEmpty) return;

    TmuxSocketSource source;
    try {
      if (_selectedKind == TmuxSocketKind.named) {
        source = TmuxSocketSource.named(rawText);
      } else {
        source = TmuxSocketSource.path(rawText);
      }
    } catch (_) {
      setState(() {
        _errorMessage = context.l10n.terminalSocketInvalid;
      });
      return;
    }

    final terminalState = ref.read(terminalProvider);
    if (source.isBuiltin ||
        terminalState.socketSources.any((s) => s.id == source.id)) {
      setState(() {
        _errorMessage = context.l10n.terminalSocketExists;
      });
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(terminalProvider.notifier)
          .addSocketSource(source, expectedTargetKey: widget.expectedTarget);
      if (mounted) {
        _inputController.clear();
        setState(() => _isAdding = false);
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        final msg = err.contains('TERMINAL_HISTORY_TARGET_CHANGED')
            ? context.l10n.terminalErrorTargetChanged
            : e.toString();
        setState(() {
          _isAdding = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final allSources = [
      (TmuxSocketSource.app, true),
      (TmuxSocketSource.standard, true),
      ...terminalState.socketSources.map((s) => (s, false)),
    ];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune_outlined, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.terminalSocketSources,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: math.min(400.0, MediaQuery.sizeOf(context).width * 0.9),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tmux -L (named) / -S (path) socket discovery sources.',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allSources.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final (source, isBuiltin) = allSources[idx];
                  final error = terminalState.socketErrors[source.id];

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isBuiltin
                          ? Icons.check_circle_outline
                          : (source.kind == TmuxSocketKind.named
                                ? Icons.tag
                                : Icons.folder_open),
                      size: 18,
                      color: isBuiltin
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _formatSocketBadge(source),
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    terminalState.socketErrorDetails[source
                                            .id] ??
                                        error,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.vDanger,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 12),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  tooltip: l10n.chatCopyError,
                                  onPressed: () {
                                    final text =
                                        terminalState.socketErrorDetails[source
                                            .id] ??
                                        error;
                                    Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.updateErrorCopied),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        : Text(
                            isBuiltin
                                ? l10n.terminalSourceBuiltin
                                : l10n.terminalSourceCustom,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                    trailing: isBuiltin
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: context.vDanger,
                            ),
                            tooltip: l10n.delete,
                            onPressed: () async {
                              try {
                                await ref
                                    .read(terminalProvider.notifier)
                                    .removeSocketSource(
                                      source.id,
                                      expectedTargetKey: widget.expectedTarget,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  final err = e.toString();
                                  final msg =
                                      err.contains(
                                        'TERMINAL_HISTORY_TARGET_CHANGED',
                                      )
                                      ? context.l10n.terminalErrorTargetChanged
                                      : e.toString();
                                  setState(() => _errorMessage = msg);
                                }
                              }
                            },
                          ),
                  );
                },
              ),
              const Divider(height: 24),
              Text(
                l10n.terminalAddSocketSource,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TmuxSocketKind>(
                segments: [
                  ButtonSegment(
                    value: TmuxSocketKind.named,
                    label: Text(
                      l10n.terminalSocketKindNamed,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  ButtonSegment(
                    value: TmuxSocketKind.path,
                    label: Text(
                      l10n.terminalSocketKindPath,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
                selected: {_selectedKind},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedKind = set.first;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'JetBrains Mono',
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedKind == TmuxSocketKind.named
                            ? 'name (e.g. work)'
                            : '/path/to/socket',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                      ),
                      onSubmitted: (_) => _addSource(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isAdding ? null : _addSource,
                    child: _isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

class _HiddenSessionsDialog extends ConsumerWidget {
  final String expectedTarget;

  const _HiddenSessionsDialog({required this.expectedTarget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalState = ref.watch(terminalProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final hiddenRecords =
        terminalState.history
            .where((r) => terminalState.hiddenRecordIds.contains(r.id))
            .toList()
          ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.terminalHiddenSessionsTitle,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: math.min(400.0, MediaQuery.sizeOf(context).width * 0.9),
        child: hiddenRecords.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 36,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.terminalNoHiddenSessions,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: math.min(320.0, hiddenRecords.length * 56.0),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: hiddenRecords.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final record = hiddenRecords[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      subtitle: Text(
                        '${_formatLastUsed(record.lastUsedAt)} • ${_formatSocketBadge(record.socket)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.restore, size: 16),
                        label: Text(
                          l10n.terminalUnhideSession,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          try {
                            await ref
                                .read(terminalProvider.notifier)
                                .unhideHistory(
                                  record.id,
                                  expectedTargetKey: expectedTarget,
                                );
                          } catch (_) {}
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
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
    final isConnected = ref.watch(serverConnectionProvider).isConnected;
    final targetKey = activeServer == null
        ? ''
        : TerminalHistoryRecord.targetFor(activeServer);

    final allVisibleRecords = terminalState.history
        .where((r) => !terminalState.hiddenRecordIds.contains(r.id))
        .toList();

    final q = _searchQuery.toLowerCase();
    final filteredHistory = q.isEmpty
        ? allVisibleRecords
        : allVisibleRecords.where((r) {
            return r.title.toLowerCase().contains(q) ||
                r.remoteSessionName.toLowerCase().contains(q) ||
                r.socket.value.toLowerCase().contains(q) ||
                r.socket.kind.name.toLowerCase().contains(q);
          }).toList();

    final matchingTabs = q.isEmpty
        ? terminalState.tabs
        : terminalState.tabs
              .where((t) => t.title.toLowerCase().contains(q))
              .toList();

    final openTabIds = terminalState.tabs.map((t) => t.id).toSet();

    final recoverableRecords = filteredHistory.where((r) {
      if (openTabIds.contains(r.id)) return false;
      final s =
          terminalState.historyStatuses[r.id] ?? TerminalHistoryStatus.unknown;
      return s == TerminalHistoryStatus.available ||
          s == TerminalHistoryStatus.open;
    }).toList()..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    final unconfirmedRecords = filteredHistory.where((r) {
      if (openTabIds.contains(r.id)) return false;
      final s =
          terminalState.historyStatuses[r.id] ?? TerminalHistoryStatus.unknown;
      return s == TerminalHistoryStatus.unknown;
    }).toList()..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    final unavailableRecords = filteredHistory.where((r) {
      if (openTabIds.contains(r.id)) return false;
      final s =
          terminalState.historyStatuses[r.id] ?? TerminalHistoryStatus.unknown;
      return s == TerminalHistoryStatus.unavailable;
    }).toList()..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    final endedRecords = filteredHistory.where((r) {
      if (openTabIds.contains(r.id)) return false;
      final s =
          terminalState.historyStatuses[r.id] ?? TerminalHistoryStatus.unknown;
      return s == TerminalHistoryStatus.ended;
    }).toList()..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

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
      if (unconfirmedRecords.isNotEmpty) ...[
        _TerminalGroupItem(
          l10n.terminalGroupUnconfirmed,
          unconfirmedRecords.length,
          context.vWarning,
        ),
        ...unconfirmedRecords,
      ],
      if (unavailableRecords.isNotEmpty) ...[
        _TerminalGroupItem(
          l10n.terminalGroupUnavailable,
          unavailableRecords.length,
          context.colorScheme.outline,
        ),
        ...unavailableRecords,
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

    return Drawer(
      width: width,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          icon: Badge(
                            isLabelVisible:
                                terminalState.socketErrors.isNotEmpty,
                            label: Text('${terminalState.socketErrors.length}'),
                            child: const Icon(Icons.tune_outlined, size: 20),
                          ),
                          tooltip: l10n.terminalSocketSources,
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _TmuxSourcesDialog(expectedTarget: targetKey),
                          ),
                        ),
                        IconButton(
                          icon: Badge(
                            isLabelVisible:
                                terminalState.hiddenRecordIds.isNotEmpty,
                            label: Text(
                              '${terminalState.hiddenRecordIds.length}',
                            ),
                            child: const Icon(
                              Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                          tooltip: l10n.terminalHiddenSessionsTitle,
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => _HiddenSessionsDialog(
                              expectedTarget: targetKey,
                            ),
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
                  if (terminalState.socketErrors.isNotEmpty)
                    InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _TmuxSourcesDialog(expectedTarget: targetKey),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.vWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: context.vWarning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: context.vWarning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.terminalSocketErrorsBanner(
                                  terminalState.socketErrors.length,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.vWarning,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: context.vWarning,
                            ),
                          ],
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                      ),
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
                ],
              ),
            ),
            if (matchingTabs.isEmpty && filteredHistory.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                          terminalState.tabs.isEmpty &&
                                  allVisibleRecords.isEmpty
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
                ),
              )
            else
              SliverList.separated(
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
                  final isDefault = terminalState.defaultHistoryId == record.id;
                  final matchingTab = terminalState.tabs
                      .where((t) => t.id == record.id)
                      .firstOrNull;

                  final isEnded = status == TerminalHistoryStatus.ended;
                  final isUnavailable =
                      status == TerminalHistoryStatus.unavailable;
                  final isUnknown = status == TerminalHistoryStatus.unknown;

                  final Color statusColor;
                  final String statusLabel;
                  if (isEnded) {
                    statusColor = context.colorScheme.outline;
                    statusLabel = l10n.terminalStatusEndedUnrecoverable;
                  } else if (isUnavailable) {
                    statusColor = context.vWarning;
                    statusLabel = l10n.terminalStatusUnavailable;
                  } else if (matchingTab != null) {
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
                        statusLabel = l10n.terminalStatusEndedUnrecoverable;
                      case TerminalHistoryStatus.unavailable:
                        statusColor = context.vWarning;
                        statusLabel = l10n.terminalStatusUnavailable;
                      case TerminalHistoryStatus.unknown:
                        statusColor = context.vWarning;
                        statusLabel = l10n.terminalStatusOffline;
                    }
                  }

                  final canTerminateRemote =
                      isConnected &&
                      targetKey == record.targetKey &&
                      !isEnded &&
                      !isUnavailable &&
                      !isUnknown;

                  return ListTile(
                    dense: true,
                    enabled: !isEnded && !isUnavailable,
                    title: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'JetBrains Mono',
                        color: (isEnded || isUnavailable)
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  context.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatSocketBadge(record.socket),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: context.colorScheme.onSurfaceVariant,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                          if (record.isExternal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    context.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: context.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                l10n.terminalExternalBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ),
                          if (record.attachedClients > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: context.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.devices,
                                    size: 10,
                                    color: context.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${record.attachedClients}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: context.colorScheme.primary,
                                    ),
                                  ),
                                ],
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
                                  color: context.colorScheme.onPrimaryContainer,
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
                                color:
                                    context.colorScheme.surfaceContainerHighest,
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
                    onTap: (isEnded || isUnavailable)
                        ? null
                        : () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                            if (matchingTab != null) {
                              final tabIndex = terminalState.tabs.indexOf(
                                matchingTab,
                              );
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
                              final tabIndex = terminalState.tabs.indexOf(
                                matchingTab,
                              );
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
                            await showRenameHistoryDialog(context, ref, record);
                          case 'hide':
                            try {
                              await ref
                                  .read(terminalProvider.notifier)
                                  .deleteHistory(
                                    record.id,
                                    terminateRemote: false,
                                    expectedTargetKey: targetKey,
                                  );
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context
                                          .l10n
                                          .terminalErrorHistoryDeleteFailed,
                                    ),
                                  ),
                                );
                              }
                            }
                          case 'terminate':
                            await showTerminateSessionDialog(
                              context,
                              ref,
                              record,
                            );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'restore',
                          enabled: !isEnded && !isUnavailable,
                          child: Row(
                            children: [
                              const Icon(Icons.launch, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.terminalRestoreSession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
                                Expanded(
                                  child: Text(
                                    l10n.terminalClearDefault,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          PopupMenuItem(
                            value: 'set_default',
                            enabled: !isEnded && !isUnavailable && !isUnknown,
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark_border, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.terminalSetDefault,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                                Expanded(
                                  child: Text(
                                    l10n.terminalCloseTab,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: context.vDanger),
                                  ),
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
                              Expanded(
                                child: Text(
                                  l10n.terminalRename,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'hide',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.terminalHideSession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'terminate',
                          enabled: canTerminateRemote,
                          child: Row(
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                size: 16,
                                color: canTerminateRemote
                                    ? context.vDanger
                                    : context.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.terminalTerminateSession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: canTerminateRemote
                                        ? context.vDanger
                                        : context.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
    final isSelected =
        terminalState.activeTabIndex >= 0 &&
        terminalState.activeTabIndex < terminalState.tabs.length &&
        terminalState.tabs[terminalState.activeTabIndex].id == tab.id;

    final historyRecord = terminalState.history
        .where((r) => r.id == tab.id)
        .firstOrNull;
    final historyStatus = historyRecord != null
        ? (terminalState.historyStatuses[historyRecord.id] ??
              TerminalHistoryStatus.unknown)
        : null;

    final isEnded = historyStatus == TerminalHistoryStatus.ended;
    final isUnavailable = historyStatus == TerminalHistoryStatus.unavailable;
    final isUnknown = historyStatus == TerminalHistoryStatus.unknown;
    final isDefault =
        historyRecord != null &&
        terminalState.defaultHistoryId == historyRecord.id;

    final Color statusColor;
    final String statusLabel;
    if (isEnded) {
      statusColor = context.colorScheme.outline;
      statusLabel = l10n.terminalStatusEndedUnrecoverable;
    } else if (isUnavailable) {
      statusColor = context.vWarning;
      statusLabel = l10n.terminalStatusUnavailable;
    } else {
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
          color: (isEnded || isUnavailable)
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
            if (historyRecord != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatSocketBadge(historyRecord.socket),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
              if (historyRecord.isExternal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    l10n.terminalExternalBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
              if (historyRecord.attachedClients > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.devices,
                        size: 10,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${historyRecord.attachedClients}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
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
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
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
            case 'restore':
              if (historyRecord != null) {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
                await ref
                    .read(terminalProvider.notifier)
                    .restoreHistory(historyRecord.id);
              }
            case 'rename':
              await showRenameTabDialog(context, ref, tab.id, tab.title);
            case 'close_tab':
              final tabIndex = terminalState.tabs.indexOf(tab);
              if (tabIndex >= 0) {
                ref.read(terminalProvider.notifier).closeTab(tabIndex);
              }
            case 'set_default':
              if (historyRecord != null) {
                try {
                  await ref
                      .read(terminalProvider.notifier)
                      .setDefaultHistory(historyRecord.id);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(l10n.terminalErrorDefaultSaveFailed),
                      ),
                    );
                  }
                }
              }
            case 'clear_default':
              try {
                await ref
                    .read(terminalProvider.notifier)
                    .setDefaultHistory(null);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(l10n.terminalErrorDefaultSaveFailed),
                    ),
                  );
                }
              }
            case 'hide':
              if (historyRecord != null) {
                try {
                  await ref
                      .read(terminalProvider.notifier)
                      .deleteHistory(
                        historyRecord.id,
                        terminateRemote: false,
                        expectedTargetKey: targetKey,
                      );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.terminalErrorHistoryDeleteFailed,
                        ),
                      ),
                    );
                  }
                }
              }
            case 'terminate':
              if (historyRecord != null) {
                await showTerminateSessionDialog(context, ref, historyRecord);
              }
          }
        },
        itemBuilder: (context) {
          final isConnected = ref.read(serverConnectionProvider).isConnected;
          final canTerminateRemote =
              historyRecord != null &&
              isConnected &&
              targetKey == historyRecord.targetKey &&
              !isEnded &&
              !isUnavailable &&
              !isUnknown;

          final isDisconnected =
              tab.bridge.state != TerminalConnectionState.connected;

          return [
            if (historyRecord != null && isDisconnected)
              PopupMenuItem(
                value: 'restore',
                enabled: !isEnded && !isUnavailable,
                child: Row(
                  children: [
                    const Icon(Icons.launch, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.terminalRestoreSession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.rename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (historyRecord != null) ...[
              if (isDefault)
                PopupMenuItem(
                  value: 'clear_default',
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_remove_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.terminalClearDefault,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'set_default',
                  enabled: !isEnded && !isUnavailable && !isUnknown,
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_border, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.terminalSetDefault,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'hide',
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.terminalHideSession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'terminate',
                enabled: canTerminateRemote,
                child: Row(
                  children: [
                    Icon(
                      Icons.stop_circle_outlined,
                      size: 16,
                      color: canTerminateRemote
                          ? context.vDanger
                          : context.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.terminalTerminateSession,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: canTerminateRemote
                              ? context.vDanger
                              : context.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (terminalState.tabs.length > 1)
              PopupMenuItem(
                value: 'close_tab',
                child: Row(
                  children: [
                    Icon(Icons.close, size: 16, color: context.vDanger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.terminalCloseTab,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.vDanger),
                      ),
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    );
  }
}
