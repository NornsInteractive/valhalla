import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../infrastructure/acp/acp_workspace_files.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';

enum RemoteBrowserMode { directory, files }

enum RemoteBrowserViewMode { list, cards, grid }

class RemoteWorkspaceBrowserDialog extends ConsumerStatefulWidget {
  final String? initialPath;
  final RemoteBrowserMode mode;

  const RemoteWorkspaceBrowserDialog({
    super.key,
    this.initialPath,
    required this.mode,
  });

  static Future<Object?> show(
    BuildContext context, {
    String? initialPath,
    required RemoteBrowserMode mode,
  }) {
    return showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          RemoteWorkspaceBrowserDialog(initialPath: initialPath, mode: mode),
    );
  }

  @override
  ConsumerState<RemoteWorkspaceBrowserDialog> createState() =>
      _RemoteWorkspaceBrowserDialogState();
}

class _RemoteWorkspaceBrowserDialogState
    extends ConsumerState<RemoteWorkspaceBrowserDialog> {
  late final AiChatNotifier _chatNotifier;
  String _currentPath = '/';
  List<SftpFileItem> _items = [];
  final Set<String> _selectedFilePaths = {};
  bool _isLoading = false;
  String? _errorMessage;
  int _loadEpoch = 0;
  RemoteBrowserViewMode _viewMode = RemoteBrowserViewMode.list;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(aiChatProvider.notifier);
    _initPathAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatNotifier.cancelWorkspaceBrowse();
    super.dispose();
  }

  Future<void> _initPathAndLoad() async {
    setState(() => _isLoading = true);
    String targetPath = widget.initialPath?.trim() ?? '';
    if (targetPath.isEmpty) {
      try {
        targetPath = await _chatNotifier.resolveWorkspaceDirectory();
      } catch (_) {
        targetPath = '/';
      }
    }
    if (!mounted) return;
    await _loadDirectory(targetPath);
  }

  Future<void> _loadDirectory(String path) async {
    final connState = ref.read(serverConnectionProvider);
    final recoveryStatus = ref.read(aiChatProvider).recoveryStatus;
    if (!connState.isConnected ||
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing) {
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.stateOffline;
      });
      return;
    }
    final epoch = ++_loadEpoch;
    _chatNotifier.cancelWorkspaceBrowse();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPath = p.posix.normalize(path);
      _searchController.clear();
      _searchQuery = '';
    });

    try {
      final results = await _chatNotifier.listWorkspaceFiles(_currentPath);
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _items = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parent = p.posix.dirname(_currentPath);
    _loadDirectory(parent);
  }

  List<SftpFileItem> get _filteredItems {
    final filtered = _items.where((item) {
      if (item.name == '.' || item.name == '..') return false;
      if (widget.mode == RemoteBrowserMode.directory && !item.isDirectory) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return filtered;
  }

  bool _isFileSupported(SftpFileItem item, AiChatState chatState) {
    if (item.isDirectory) return true;
    final mime = AcpWorkspaceFiles.mimeType(item.name);
    if (mime == null) return false;
    if (mime.startsWith('image/')) {
      return chatState.supportsImages;
    }
    return chatState.supportsTextAttachments;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDirectoryMode = widget.mode == RemoteBrowserMode.directory;
    final connState = ref.watch(serverConnectionProvider);
    final recoveryStatus = ref.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final isAllowed =
        connState.isConnected &&
        recoveryStatus != SessionRecoveryStatus.reconnecting &&
        recoveryStatus != SessionRecoveryStatus.syncing;

    return Dialog(
      key: const Key('remote_workspace_browser_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Column(
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Icon(
                    isDirectoryMode
                        ? Icons.folder_open
                        : Icons.cloud_download_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDirectoryMode
                          ? context.l10n.chatSelectDirectory
                          : context.l10n.chatRemoteBrowserTitle,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // View mode toggles (only in files mode)
                  if (!isDirectoryMode) ...[
                    IconButton(
                      icon: const Icon(Icons.view_list, size: 20),
                      tooltip: context.l10n.chatViewModeList,
                      color: _viewMode == RemoteBrowserViewMode.list
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      onPressed: () => setState(
                        () => _viewMode = RemoteBrowserViewMode.list,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.grid_view, size: 20),
                      tooltip: context.l10n.chatViewModeCards,
                      color: _viewMode == RemoteBrowserViewMode.cards
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      onPressed: () => setState(
                        () => _viewMode = RemoteBrowserViewMode.cards,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image, size: 20),
                      tooltip: context.l10n.chatViewModeGrid,
                      color: _viewMode == RemoteBrowserViewMode.grid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      onPressed: () => setState(
                        () => _viewMode = RemoteBrowserViewMode.grid,
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () {
                      _chatNotifier.cancelWorkspaceBrowse();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Navigation bar: POSIX parent & Breadcrumbs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('chat_browser_parent_button'),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: context.l10n.chatParentDirectory,
                    onPressed: (_currentPath == '/' || !isAllowed)
                        ? null
                        : _navigateUp,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: _buildBreadcrumbs(isAllowed),
                    ),
                  ),
                ],
              ),
            ),

            // Search filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                key: const Key('chat_browser_search_input'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.chatSearchFilesHint,
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Content Area
            Expanded(child: _buildContent(theme, isAllowed)),
            const Divider(height: 1),

            // Action footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: monoTextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _chatNotifier.cancelWorkspaceBrowse();
                      Navigator.pop(context);
                    },
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  if (isDirectoryMode)
                    FilledButton(
                      key: const Key('chat_select_directory_confirm_button'),
                      onPressed:
                          (_isLoading || _errorMessage != null || !isAllowed)
                          ? null
                          : () {
                              _chatNotifier.cancelWorkspaceBrowse();
                              Navigator.pop(context, _currentPath);
                            },
                      child: Text(context.l10n.chatSelectThisDirectory),
                    )
                  else
                    FilledButton(
                      key: const Key(
                        'chat_attach_selected_files_confirm_button',
                      ),
                      onPressed: (_selectedFilePaths.isEmpty || !isAllowed)
                          ? null
                          : () {
                              _chatNotifier.cancelWorkspaceBrowse();
                              Navigator.pop(
                                context,
                                _selectedFilePaths.toList(),
                              );
                            },
                      child: Text(
                        context.l10n.chatAttachSelectedFiles(
                          _selectedFilePaths.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isAllowed) {
    final segments = _currentPath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    final List<Widget> children = [];

    children.add(
      InkWell(
        onTap: isAllowed ? () => _loadDirectory('/') : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            '/',
            style: monoTextStyle(
              fontSize: 12,
              fontWeight: _currentPath == '/'
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );

    String pathAcc = '';
    for (int i = 0; i < segments.length; i++) {
      pathAcc += '/${segments[i]}';
      final segPath = pathAcc;
      final isLast = i == segments.length - 1;
      children.add(
        const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
      );
      children.add(
        InkWell(
          onTap: (isLast || !isAllowed) ? null : () => _loadDirectory(segPath),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              segments[i],
              style: monoTextStyle(
                fontSize: 12,
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildContent(ThemeData theme, bool isAllowed) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.vDanger, size: 32),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: context.vDanger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isAllowed
                    ? () => _loadDirectory(_currentPath)
                    : null,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.stateRetry),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.chatNoFilesFound,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    final chatState = ref.watch(aiChatProvider);

    if (widget.mode == RemoteBrowserMode.directory ||
        _viewMode == RemoteBrowserViewMode.list) {
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final item = items[index];
          final isSelected = _selectedFilePaths.contains(item.path);
          final isSupported = _isFileSupported(item, chatState);
          final isItemEnabled =
              item.isDirectory ||
              (widget.mode == RemoteBrowserMode.files && isSupported);

          return ListTile(
            dense: true,
            enabled: isItemEnabled,
            leading: Icon(
              item.isDirectory ? Icons.folder : _getFileIcon(item.name),
              size: 20,
              color: isItemEnabled
                  ? (item.isDirectory
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline)
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoTextStyle(
                fontSize: 12,
                color: isItemEnabled ? null : theme.colorScheme.outline,
              ),
            ),
            subtitle: item.isDirectory
                ? null
                : (!isSupported
                      ? Text(
                          context.l10n.chatFileUnsupported,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.outline,
                          ),
                        )
                      : Text(
                          item.formattedSize,
                          style: const TextStyle(fontSize: 11),
                        )),
            trailing:
                widget.mode == RemoteBrowserMode.files && !item.isDirectory
                ? Checkbox(
                    value: isSelected,
                    onChanged: (isSupported && isAllowed)
                        ? (val) {
                            setState(() {
                              if (val == true) {
                                _selectedFilePaths.add(item.path);
                              } else {
                                _selectedFilePaths.remove(item.path);
                              }
                            });
                          }
                        : null,
                  )
                : (item.isDirectory
                      ? const Icon(Icons.chevron_right, size: 16)
                      : null),
            onTap: (isItemEnabled && isAllowed)
                ? () {
                    if (item.isDirectory) {
                      _loadDirectory(item.path);
                    } else if (widget.mode == RemoteBrowserMode.files) {
                      setState(() {
                        if (isSelected) {
                          _selectedFilePaths.remove(item.path);
                        } else {
                          _selectedFilePaths.add(item.path);
                        }
                      });
                    }
                  }
                : null,
          );
        },
      );
    }

    if (_viewMode == RemoteBrowserViewMode.cards) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, index) {
          final item = items[index];
          final isSelected = _selectedFilePaths.contains(item.path);
          final isSupported = _isFileSupported(item, chatState);
          final isItemEnabled =
              item.isDirectory ||
              (widget.mode == RemoteBrowserMode.files && isSupported);

          final cardContent = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.isDirectory ? Icons.folder : _getFileIcon(item.name),
                  size: 28,
                  color: isItemEnabled
                      ? (item.isDirectory
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoTextStyle(
                    fontSize: 11,
                    color: isItemEnabled ? null : theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!item.isDirectory) ...[
                  const SizedBox(height: 2),
                  Text(
                    isSupported
                        ? item.formattedSize
                        : context.l10n.chatFileUnsupported,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );

          return InkWell(
            onTap: (isItemEnabled && isAllowed)
                ? () {
                    if (item.isDirectory) {
                      _loadDirectory(item.path);
                    } else {
                      setState(() {
                        if (isSelected) {
                          _selectedFilePaths.remove(item.path);
                        } else {
                          _selectedFilePaths.add(item.path);
                        }
                      });
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(VRadius.card),
            child: isItemEnabled
                ? cardContent
                : Opacity(opacity: 0.45, child: cardContent),
          );
        },
      );
    }

    // Grid View (Image thumbnails)
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        final isSelected = _selectedFilePaths.contains(item.path);
        final isImage =
            AcpWorkspaceFiles.mimeType(item.name)?.startsWith('image/') == true;
        final isSupported = _isFileSupported(item, chatState);
        final isItemEnabled =
            item.isDirectory ||
            (widget.mode == RemoteBrowserMode.files && isSupported);

        if (item.isDirectory) {
          return InkWell(
            onTap: isAllowed ? () => _loadDirectory(item.path) : null,
            borderRadius: BorderRadius.circular(VRadius.card),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoTextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final gridItemContent = Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(VRadius.card),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isImage)
                FutureBuilder<Uint8List?>(
                  future: _chatNotifier.remoteImagePreview(item),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(VRadius.card),
                        child: Image(
                          image: ResizeImage(
                            MemoryImage(snapshot.data!),
                            width: 256,
                            height: 256,
                            policy: ResizeImagePolicy.fit,
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, _, _) => Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      );
                    }
                    return Icon(
                      Icons.image,
                      size: 32,
                      color: theme.colorScheme.outline,
                    );
                  },
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getFileIcon(item.name),
                      size: 28,
                      color: isItemEnabled
                          ? theme.colorScheme.outline
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoTextStyle(
                          fontSize: 10,
                          color: isItemEnabled
                              ? null
                              : theme.colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );

        return InkWell(
          onTap: (isItemEnabled && isAllowed)
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedFilePaths.remove(item.path);
                    } else {
                      _selectedFilePaths.add(item.path);
                    }
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(VRadius.card),
          child: isItemEnabled
              ? gridItemContent
              : Opacity(opacity: 0.45, child: gridItemContent),
        );
      },
    );
  }

  IconData _getFileIcon(String name) {
    final mime = AcpWorkspaceFiles.mimeType(name);
    if (mime != null && mime.startsWith('image/')) {
      return Icons.image_outlined;
    }
    if (mime == 'text/plain') {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
