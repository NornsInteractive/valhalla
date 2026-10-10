import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/sftp_provider.dart';
import '../../../data/models/server_profile.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import '../../../widgets/state_views.dart';

class SftpDirectoryPickerDialog extends ConsumerStatefulWidget {
  final String initialPath;
  final String title;
  final Set<String> restrictedPaths;

  const SftpDirectoryPickerDialog({
    super.key,
    required this.initialPath,
    required this.title,
    this.restrictedPaths = const {},
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialPath,
    required String title,
    Set<String> restrictedPaths = const {},
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => SftpDirectoryPickerDialog(
        initialPath: initialPath,
        title: title,
        restrictedPaths: restrictedPaths,
      ),
    );
  }

  @override
  ConsumerState<SftpDirectoryPickerDialog> createState() =>
      _SftpDirectoryPickerDialogState();
}

class _SftpDirectoryPickerDialogState
    extends ConsumerState<SftpDirectoryPickerDialog> {
  late String _currentPath;
  ServerProfile? _capturedServer;
  bool _isLoading = false;
  String? _errorMessage;
  List<SftpFileItem> _subdirectories = [];

  bool _isSameServer(ServerProfile? current) {
    if (current == null || _capturedServer == null) return false;
    return current.hasSameConnectionSettings(_capturedServer!);
  }

  @override
  void initState() {
    super.initState();
    _currentPath = p.posix.normalize(widget.initialPath);
    if (!_currentPath.startsWith('/')) _currentPath = '/';
    _capturedServer = ref.read(activeServerProvider);
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String targetPath) async {
    final activeServer = ref.read(activeServerProvider);
    if (!_isSameServer(activeServer) ||
        !ref.read(serverConnectionProvider).isConnected) {
      if (mounted) Navigator.of(context).pop(null);
      return;
    }

    final normalized = p.posix.normalize(targetPath);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sftpOps = ref.read(sftpOperationsProvider);
      final items = await sftpOps.listFiles(normalized);

      if (!mounted) return;
      if (!_isSameServer(ref.read(activeServerProvider))) {
        Navigator.of(context).pop(null);
        return;
      }

      final dirs =
          items
              .where(
                (item) =>
                    item.isDirectory && item.name != '.' && item.name != '..',
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      setState(() {
        _currentPath = normalized;
        _subdirectories = dirs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_isSameServer(ref.read(activeServerProvider))) {
        Navigator.of(context).pop(null);
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  bool _isPathRestricted(String targetDir) {
    final normTarget = p.posix.normalize(targetDir);
    for (final restricted in widget.restrictedPaths) {
      final normRestricted = p.posix.normalize(restricted);
      if (normTarget == normRestricted ||
          p.posix.isWithin(normRestricted, normTarget)) {
        return true;
      }
    }
    return false;
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parent = p.posix.dirname(_currentPath);
    _loadDirectory(parent);
  }

  @override
  Widget build(BuildContext context) {
    final isAtRoot = _currentPath == '/';
    final isTargetRestricted = _isPathRestricted(_currentPath);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.folder_open_rounded, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Path header and up button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: context.l10n.sftpUpDirectory,
                      onPressed: (isAtRoot || _isLoading) ? null : _navigateUp,
                    ),
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
                      onPressed: _isLoading
                          ? null
                          : () => _loadDirectory(_currentPath),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (isTargetRestricted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.sftpBatchTargetRestricted,
                    style: TextStyle(fontSize: 11, color: context.vWarning),
                  ),
                ),
              // Subdirectories list
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: LoadingStateView(),
                      )
                    : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: ErrorStateView(
                          message: _errorMessage!,
                          onRetry: () => _loadDirectory(_currentPath),
                        ),
                      )
                    : _subdirectories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            context.l10n.chatNoSubdirectories,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _subdirectories.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _subdirectories[index];
                          final isRestricted = _isPathRestricted(item.path);

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.folder,
                              size: 20,
                              color: isRestricted
                                  ? context.colorScheme.outline
                                  : context.colorScheme.primary,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isRestricted
                                    ? context.colorScheme.outline
                                    : null,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 16),
                            onTap: () => _loadDirectory(item.path),
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
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: (isTargetRestricted || _isLoading)
              ? null
              : () {
                  if (!_isSameServer(ref.read(activeServerProvider))) {
                    Navigator.of(context).pop(null);
                  } else {
                    Navigator.of(context).pop(_currentPath);
                  }
                },
          child: Text(context.l10n.sftpSelectCurrentDir),
        ),
      ],
    );
  }
}
