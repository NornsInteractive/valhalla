import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/settings_provider.dart';

/// Configuration dialog for pinning remote file toolbar actions.
class RemoteFileToolbarDialog extends ConsumerStatefulWidget {
  const RemoteFileToolbarDialog({super.key});

  static Future<void> show(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<void>(
      context: context,
      builder: (_) => const RemoteFileToolbarDialog(),
    ).then((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  ConsumerState<RemoteFileToolbarDialog> createState() =>
      _RemoteFileToolbarDialogState();
}

class _RemoteFileToolbarDialogState
    extends ConsumerState<RemoteFileToolbarDialog> {
  late Set<RemoteFileToolbarAction> _draft;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(settingsProvider).remoteFileToolbarActions.toSet();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(settingsProvider.notifier)
          .setRemoteFileToolbarActions(_draft);
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.sftpToolbarPreferenceSaveFailed),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  void _handleResetDefaults() {
    if (_isSaving) return;
    setState(() {
      _draft = defaultRemoteFileToolbarActions.toSet();
    });
  }

  String _actionLabel(BuildContext context, RemoteFileToolbarAction action) {
    final l10n = context.l10n;
    switch (action) {
      case RemoteFileToolbarAction.upload:
        return l10n.sftpUpload;
      case RemoteFileToolbarAction.create:
        return l10n.sftpNew;
      case RemoteFileToolbarAction.view:
        return l10n.sftpToolbarActionView;
      case RemoteFileToolbarAction.transfers:
        return l10n.transferList;
      case RemoteFileToolbarAction.hidden:
        return l10n.sftpShowHiddenFiles;
      case RemoteFileToolbarAction.sort:
        return l10n.sftpSort;
      case RemoteFileToolbarAction.selection:
        return l10n.sftpSelectMode;
      case RemoteFileToolbarAction.bookmarks:
        return l10n.sftpBookmarksTitle;
      case RemoteFileToolbarAction.refresh:
        return l10n.sftpRefresh;
    }
  }

  IconData _actionIcon(RemoteFileToolbarAction action) {
    switch (action) {
      case RemoteFileToolbarAction.upload:
        return Icons.upload_file;
      case RemoteFileToolbarAction.create:
        return Icons.add;
      case RemoteFileToolbarAction.view:
        return Icons.grid_view;
      case RemoteFileToolbarAction.transfers:
        return Icons.swap_vert;
      case RemoteFileToolbarAction.hidden:
        return Icons.visibility;
      case RemoteFileToolbarAction.sort:
        return Icons.sort;
      case RemoteFileToolbarAction.selection:
        return Icons.checklist;
      case RemoteFileToolbarAction.bookmarks:
        return Icons.bookmarks_outlined;
      case RemoteFileToolbarAction.refresh:
        return Icons.refresh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actionsOverflowButtonSpacing: 4,
        title: Text(l10n.sftpConfigureToolbar),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sftpConfigureToolbarDesc,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final action in RemoteFileToolbarAction.values)
                CheckboxListTile(
                  key: Key('toolbar_action_${action.name}'),
                  value: _draft.contains(action),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_actionIcon(action), size: 20),
                  title: Text(_actionLabel(context, action)),
                  onChanged: _isSaving
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked ?? false) {
                              _draft.add(action);
                            } else {
                              _draft.remove(action);
                            }
                          });
                        },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('toolbar_dialog_reset'),
            onPressed: _isSaving ? null : _handleResetDefaults,
            child: Text(l10n.settingsResetDefault),
          ),
          TextButton(
            key: const Key('toolbar_dialog_cancel'),
            onPressed: _isSaving
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).pop();
                  },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('toolbar_dialog_save'),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
