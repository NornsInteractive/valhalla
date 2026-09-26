import 'package:flutter/material.dart';
import '../core/design/motion_widgets.dart';
import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';
import '../infrastructure/sftp/sftp_client_service.dart';
import 'state_views.dart';

class RemoteDirectoryPickerDialog extends StatefulWidget {
  final String initialPath;
  final SftpOperations sftpOperations;
  final ValueChanged<String> onSelect;
  final String? title;

  const RemoteDirectoryPickerDialog({
    super.key,
    required this.initialPath,
    required this.sftpOperations,
    required this.onSelect,
    this.title,
  });

  @override
  State<RemoteDirectoryPickerDialog> createState() =>
      _RemoteDirectoryPickerDialogState();
}

class _RemoteDirectoryPickerDialogState
    extends State<RemoteDirectoryPickerDialog> {
  late String _currentPath;
  bool _isLoading = true;
  String? _errorMessage;
  List<SftpFileItem> _subdirectories = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath.startsWith('/')
        ? widget.initialPath
        : '/';
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.sftpOperations.listFiles(path);
      if (!mounted) return;
      final dirs =
          items
              .where((i) => i.isDirectory && i.name != '.' && i.name != '..')
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      setState(() {
        _currentPath = path;
        _subdirectories = dirs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final trimmed = _currentPath.endsWith('/') && _currentPath.length > 1
        ? _currentPath.substring(0, _currentPath.length - 1)
        : _currentPath;
    final lastSlash = trimmed.lastIndexOf('/');
    final parent = lastSlash <= 0 ? '/' : trimmed.substring(0, lastSlash);
    _loadDirectory(parent);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        child: Column(
          children: [
            Entrance(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title ?? context.l10n.cliPickWorkingDirTitle,
                        style: context.textTheme.titleMedium,
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
            ),
            Entrance(
              index: 1,
              child: Container(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: context.l10n.cliNavigateUp,
                      visualDensity: VisualDensity.compact,
                      onPressed: _currentPath == '/' ? null : _navigateUp,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath,
                        style: monoTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: context.l10n.sftpRefresh,
                      visualDensity: VisualDensity.compact,
                      onPressed: _isLoading
                          ? null
                          : () => _loadDirectory(_currentPath),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return Shimmer(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
                        itemCount: 8,
                        itemBuilder: (_, _) => const SkeletonListTile(),
                      ),
                    );
                  }
                  if (_errorMessage != null) {
                    return ErrorStateView(
                      message: _errorMessage,
                      onRetry: () => _loadDirectory(_currentPath),
                    );
                  }
                  if (_subdirectories.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.folder_off_outlined,
                      title: context.l10n.sftpEmpty,
                    );
                  }
                  return ListView.builder(
                    itemCount: _subdirectories.length,
                    itemBuilder: (ctx, index) {
                      final dir = _subdirectories[index];
                      return ListTile(
                        leading: Icon(
                          Icons.folder,
                          color: context.colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(
                          dir.name,
                          style: context.textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _loadDirectory(dir.path),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('cli_dialog_select_dir_button'),
                    onPressed: (_isLoading || _errorMessage != null)
                        ? null
                        : () {
                            widget.onSelect(_currentPath);
                            Navigator.pop(context);
                          },
                    child: Text(context.l10n.cliSelectCurrentDir),
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
