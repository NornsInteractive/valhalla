import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/file_bookmarks_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/server_profile.dart';

class FileBookmarksDialog extends ConsumerStatefulWidget {
  final String currentPath;
  final ValueChanged<String> onSelectPath;

  const FileBookmarksDialog({
    super.key,
    required this.currentPath,
    required this.onSelectPath,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentPath,
    required ValueChanged<String> onSelectPath,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FileBookmarksDialog(
        currentPath: currentPath,
        onSelectPath: onSelectPath,
      ),
    );
  }

  @override
  ConsumerState<FileBookmarksDialog> createState() =>
      _FileBookmarksDialogState();
}

class _FileBookmarksDialogState extends ConsumerState<FileBookmarksDialog> {
  ServerProfile? _capturedServer;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _capturedServer = ref.read(activeServerProvider);
  }

  bool _isSameServer() {
    final current = ref.read(activeServerProvider);
    if (current == null || _capturedServer == null) return false;
    return current.hasSameConnectionSettings(_capturedServer!);
  }

  Future<void> _handleToggle(String path) async {
    if (_isToggling) return;
    if (!_isSameServer()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isToggling = true);
    try {
      await ref.read(fileBookmarksProvider.notifier).toggle(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServerProfile?>(activeServerProvider, (prev, next) {
      if (next == null ||
          _capturedServer == null ||
          !next.hasSameConnectionSettings(_capturedServer!)) {
        if (mounted) Navigator.of(context).pop();
      }
    });

    final bookmarks = ref.watch(fileBookmarksProvider);
    final isCurrentBookmarked = bookmarks.contains(widget.currentPath);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bookmarks_rounded, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.sftpBookmarksTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current path bookmark toggle tile
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    final actionButton = TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        isCurrentBookmarked ? Icons.remove : Icons.add,
                        size: 16,
                      ),
                      label: Text(
                        isCurrentBookmarked
                            ? context.l10n.sftpRemoveBookmark
                            : context.l10n.sftpAddBookmark,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _isToggling
                          ? null
                          : () => _handleToggle(widget.currentPath),
                    );

                    if (isNarrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCurrentBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 20,
                                color: isCurrentBookmarked
                                    ? context.colorScheme.primary
                                    : context.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.sftpCurrentDirectory,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      widget.currentPath,
                                      style: monoTextStyle(
                                        fontSize: 11,
                                        color: context.colorScheme.outline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actionButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Icon(
                          isCurrentBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: isCurrentBookmarked
                              ? context.colorScheme.primary
                              : context.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.sftpCurrentDirectory,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                widget.currentPath,
                                style: monoTextStyle(
                                  fontSize: 11,
                                  color: context.colorScheme.outline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        actionButton,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: bookmarks.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            context.l10n.sftpNoBookmarks,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: bookmarks.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final path = bookmarks[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.folder_special_rounded,
                              size: 20,
                              color: context.colorScheme.primary,
                            ),
                            title: Text(
                              path,
                              style: monoTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: context.l10n.sftpRemoveBookmark,
                              onPressed: _isToggling
                                  ? null
                                  : () => _handleToggle(path),
                            ),
                            onTap: () {
                              if (!_isSameServer()) {
                                Navigator.of(context).pop();
                                return;
                              }
                              Navigator.of(context).pop();
                              widget.onSelectPath(path);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }
}
