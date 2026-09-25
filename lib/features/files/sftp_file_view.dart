import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/sftp_provider.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';

class SftpFileView extends ConsumerStatefulWidget {
  const SftpFileView({super.key, this.openTransfersRequest});

  /// 由 shell 递增的「请打开传输列表」信号，见 `main_shell.dart` 里
  /// `_openTransfersRequest` 的说明。
  ///
  /// 语义是**单调递增的计数器**，不是布尔值：同一个页面可能被要求打开多次
  /// （用户点了通知 A，回到文件页手动关掉面板，又点了通知 B），用计数器
  /// 才能区分出第二次请求。监听方必须缓存上一次见到的值，只在**变化时**
  /// 动作，否则页面每次重建都会重新弹一次面板。
  ///
  /// 允许为 null（测试与其它调用方直接 `const SftpFileView()`），
  /// 此时不会有任何自动打开行为。
  final ValueListenable<int>? openTransfersRequest;

  @override
  ConsumerState<SftpFileView> createState() => _SftpFileViewState();
}

class _SftpFileViewState extends ConsumerState<SftpFileView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _transferIconKey = GlobalKey();
  final List<AnimationController> _activeAnimControllers = [];
  final List<OverlayEntry> _activeOverlayEntries = [];
  Timer? _highlightTimer;
  bool _highlightTransferButton = false;

  /// 已经响应过的 `openTransfersRequest` 值，0 表示还没响应过任何一次。
  int _handledOpenTransfersRequest = 0;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(sftpProvider).searchQuery;
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
    widget.openTransfersRequest?.addListener(_handleOpenTransfersRequest);
  }

  @override
  void didUpdateWidget(SftpFileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openTransfersRequest != widget.openTransfersRequest) {
      oldWidget.openTransfersRequest?.removeListener(
        _handleOpenTransfersRequest,
      );
      widget.openTransfersRequest?.addListener(_handleOpenTransfersRequest);
    }
  }

  /// 响应 shell 发来的「打开传输列表」请求，同一个值只处理一次。
  ///
  /// 面板弹出的前提是页面在树上（`IndexedStack` 的子项始终会在树上），
  /// 所以冷启动时 shell 先切 tab、再递增计数，这里能立刻接住。
  void _handleOpenTransfersRequest() {
    final request = widget.openTransfersRequest?.value ?? 0;
    if (request == _handledOpenTransfersRequest) return;
    _handledOpenTransfersRequest = request;
    _showTransferListModal(context);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    for (final entry in _activeOverlayEntries) {
      if (entry.mounted) {
        entry.remove();
      }
    }
    _activeOverlayEntries.clear();
    for (final c in _activeAnimControllers) {
      c.dispose();
    }
    _activeAnimControllers.clear();
    widget.openTransfersRequest?.removeListener(_handleOpenTransfersRequest);
    _searchController.dispose();
    super.dispose();
  }

  void _triggerTransferButtonHighlight() {
    if (!mounted) return;
    setState(() {
      _highlightTransferButton = true;
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _highlightTransferButton = false;
        });
      }
    });
  }

  void _animateFlyToTransfer(Offset? startOffset) {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _triggerTransferButtonHighlight();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final start =
        startOffset ?? Offset(screenSize.width / 2, screenSize.height / 2);

    Offset end = Offset(screenSize.width - 40, mediaQuery.padding.top + 40);
    final iconBox =
        _transferIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (iconBox != null && iconBox.hasSize) {
      end = iconBox.localToGlobal(
        Offset(iconBox.size.width / 2, iconBox.size.height / 2),
      );
    }

    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _activeAnimControllers.add(controller);

    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return AnimatedBuilder(
          animation: curved,
          builder: (ctx, child) {
            final t = curved.value;
            final currentPos = Offset.lerp(start, end, t)!;
            final scale = 1.0 - (0.4 * t);
            final opacity = (1.0 - (0.3 * t)).clamp(0.0, 1.0);

            return Positioned(
              left: currentPos.dx - 12,
              top: currentPos.dy - 12,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.insert_drive_file,
                          size: 16,
                          color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _activeOverlayEntries.add(entry);
    overlay.insert(entry);

    controller
        .forward()
        .then((_) {
          if (entry.mounted) {
            entry.remove();
          }
          _activeOverlayEntries.remove(entry);
          controller.dispose();
          _activeAnimControllers.remove(controller);
        })
        .catchError((_) {
          if (entry.mounted) {
            entry.remove();
          }
          _activeOverlayEntries.remove(entry);
          controller.dispose();
          _activeAnimControllers.remove(controller);
        });
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.sftpNewFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. logs'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(sftpProvider.notifier).createDirectory(name);
                Navigator.pop(ctx);
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showNewFileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.sftpNewFile),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. config.json'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(sftpProvider.notifier).createFile(name, '');
                Navigator.pop(ctx);
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(SftpFileItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Item'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.name) {
                ref.read(sftpProvider.notifier).renameItem(item, newName);
                Navigator.pop(ctx);
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(SftpFileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${context.l10n.delete} ${item.name}?'),
        content: Text(
          'Are you sure you want to permanently delete "${item.path}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(sftpProvider.notifier).deleteItem(item);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _openFileEditor(SftpFileItem item) async {
    final notifier = ref.read(sftpProvider.notifier);
    if (!notifier.canPreview(item)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.sftpOpenUnsupported)));
      return;
    }

    await notifier.openFileForEditing(item);
    if (!mounted) return;

    final sftpState = ref.read(sftpProvider);
    if (sftpState.editingFilePath != item.path) {
      if (sftpState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapErrorMessage(sftpState.errorMessage!))),
        );
      }
      return;
    }

    final content = sftpState.editingFileContent ?? '';
    final editorController = TextEditingController(text: content);
    var isSaving = false;
    String? saveError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);

          Future<void> handleSave() async {
            if (isSaving) return;
            setDialogState(() {
              isSaving = true;
              saveError = null;
            });

            try {
              await notifier.saveFileContent(item.path, editorController.text);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(ctx.l10n.fileSavedSuccess)),
                );
                Navigator.pop(ctx);
              }
            } catch (e) {
              if (ctx.mounted) {
                setDialogState(() {
                  isSaving = false;
                  saveError = ctx.l10n.sftpSaveFailed;
                });
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(ctx.l10n.sftpSaveFailed),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          }

          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    notifier.closeFileEditor();
                    Navigator.pop(ctx);
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.path,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
                actions: [
                  FilledButton.icon(
                    key: const Key('sftp_editor_save_button'),
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                      isSaving ? ctx.l10n.sftpSaving : ctx.l10n.fileEditorSave,
                    ),
                    onPressed: isSaving ? null : handleSave,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: Column(
                children: [
                  if (saveError != null)
                    Container(
                      key: const Key('sftp_editor_error_banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: theme.colorScheme.errorContainer,
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              saveError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        key: const Key('sftp_editor_text_field'),
                        controller: editorController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        notifier.closeFileEditor();
      }
    });
  }

  Future<void> _handleUpload() async {
    if (ref.read(sftpProvider).activeTransfer != null) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;
    await ref.read(sftpProvider.notifier).uploadFrom(path);
  }

  Future<String?> _handleDownload(
    SftpFileItem item, [
    Offset? startOffset,
  ]) async {
    final taskId = await ref.read(sftpProvider.notifier).downloadFile(item);
    if (taskId != null) {
      _animateFlyToTransfer(startOffset);
    }
    return taskId;
  }

  void _showTransferListModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(
        maxWidth: LayoutBreakpoints.modalSheetWideMaxWidth,
      ),
      builder: (ctx) => const SftpTransferListSheet(),
    );
  }

  String _mapErrorMessage(String code) {
    if (code == SftpNotifier.uploadFailedCode) {
      return context.l10n.sftpUploadFailed;
    }
    if (code == SftpNotifier.downloadFailedCode) {
      return context.l10n.sftpDownloadFailed;
    }
    if (code == SftpNotifier.previewUnsupportedCode) {
      return context.l10n.sftpOpenUnsupported;
    }
    if (code == 'SFTP_PREVIEW_TOO_LARGE' ||
        code == SftpClientService.previewTooLargeCode) {
      return context.l10n.sftpPreviewTooLarge;
    }
    if (code == SftpNotifier.readFailedCode) {
      return context.l10n.sftpReadFailed;
    }
    if (code == 'DOWNLOAD_OPEN_FAILED') {
      return context.l10n.downloadOpenFailed;
    }
    return context.l10n.sftpTransferFailed;
  }

  Widget _buildNotificationUnavailableNotice() {
    return Container(
      key: const Key('downloadNotificationsUnavailableBanner'),
      color: context.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 16,
            color: context.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.downloadNotificationsUnavailable,
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String errorCode) {
    final message = _mapErrorMessage(errorCode);
    return Container(
      key: const Key('sftpErrorBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colorScheme.errorContainer.withValues(alpha: 0.8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: context.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: context.colorScheme.onErrorContainer,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => ref.read(sftpProvider.notifier).clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferBanner(SftpTransfer transfer) {
    final isUpload = transfer.kind == SftpTransferKind.upload;
    final title = isUpload
        ? context.l10n.sftpUploading
        : context.l10n.sftpDownloading;
    final progress = transfer.progress;

    return Container(
      key: const Key('sftpTransferBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpload ? Icons.upload : Icons.download,
                size: 16,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title ${transfer.remotePath.split('/').last}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (progress != null)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress, minHeight: 3),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sftpState = ref.watch(sftpProvider);

    ref.listen<String>(sftpProvider.select((s) => s.currentPath), (
      previous,
      next,
    ) {
      if (previous != null && previous != next) {
        _searchController.clear();
      }
    });

    ref.listen<String>(sftpProvider.select((s) => s.searchQuery), (
      previous,
      next,
    ) {
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    return Column(
      children: [
        _buildBreadcrumbBar(sftpState),
        const Divider(height: 1),
        _buildActionBar(sftpState),
        const Divider(height: 1),
        if (sftpState.activeTransfer != null) ...[
          _buildTransferBanner(sftpState.activeTransfer!),
          const Divider(height: 1),
        ],
        if (sftpState.errorMessage != null)
          _buildErrorBanner(sftpState.errorMessage!),
        if (sftpState.downloadNotificationsUnavailable)
          _buildNotificationUnavailableNotice(),
        Expanded(
          child: sftpState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildFileList(sftpState),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbBar(SftpState state) {
    final notifier = ref.read(sftpProvider.notifier);
    final segments = state.pathSegments;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: context.colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            tooltip: 'Up to parent directory',
            onPressed: state.isAtRoot ? null : () => notifier.navigateUp(),
          ),
          ActionChip(
            label: const Text(
              '/',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => notifier.navigateTo('/'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(segments.length, (index) {
                  final seg = segments[index];
                  final pathUpTo = '/${segments.take(index + 1).join('/')}';
                  final isLast = index == segments.length - 1;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.grey,
                      ),
                      ActionChip(
                        avatar: isLast
                            ? const Icon(Icons.folder_open, size: 14)
                            : null,
                        label: Text(
                          seg,
                          style: TextStyle(
                            fontWeight: isLast
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onPressed: () => notifier.navigateTo(pathUpTo),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(SftpState state) {
    final notifier = ref.read(sftpProvider.notifier);

    return Container(
      color: context.colorScheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Dedicated Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: SizedBox(
              height: 36,
              child: TextField(
                key: const Key('sftp_search_field'),
                controller: _searchController,
                onChanged: (val) => notifier.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: context.l10n.sftpSearchHint,
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainerHighest,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          // Row 2: Action buttons (Responsive horizontal scroll, never wrap or overflow)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.upload_file, size: 20),
                  tooltip: context.l10n.sftpUpload,
                  onPressed: state.activeTransfer != null
                      ? null
                      : _handleUpload,
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  tooltip: context.l10n.sftpNewFolder,
                  onPressed: _showNewFolderDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, size: 20),
                  tooltip: context.l10n.sftpNewFile,
                  onPressed: _showNewFileDialog,
                ),
                PopupMenuButton<Object>(
                  icon: const Icon(Icons.sort, size: 20),
                  tooltip: context.l10n.sftpSort,
                  onSelected: (value) {
                    if (value is SftpSortKey) {
                      final isSameKey = state.sortKey == value;
                      notifier.setSort(
                        key: value,
                        ascending: isSameKey
                            ? !state.sortAscending
                            : state.sortAscending,
                      );
                    } else if (value == 'asc') {
                      notifier.setSort(key: state.sortKey, ascending: true);
                    } else if (value == 'desc') {
                      notifier.setSort(key: state.sortKey, ascending: false);
                    }
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<SftpSortKey>(
                      value: SftpSortKey.name,
                      checked: state.sortKey == SftpSortKey.name,
                      child: Text(context.l10n.sftpSortName),
                    ),
                    CheckedPopupMenuItem<SftpSortKey>(
                      value: SftpSortKey.size,
                      checked: state.sortKey == SftpSortKey.size,
                      child: Text(context.l10n.sftpSortSize),
                    ),
                    CheckedPopupMenuItem<SftpSortKey>(
                      value: SftpSortKey.date,
                      checked: state.sortKey == SftpSortKey.date,
                      child: Text(context.l10n.sftpSortDate),
                    ),
                    const PopupMenuDivider(),
                    CheckedPopupMenuItem<String>(
                      value: 'asc',
                      checked: state.sortAscending,
                      child: Text(context.l10n.sftpSortAscending),
                    ),
                    CheckedPopupMenuItem<String>(
                      value: 'desc',
                      checked: !state.sortAscending,
                      child: Text(context.l10n.sftpSortDescending),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: context.l10n.sftpRefresh,
                  onPressed: () => notifier.refresh(),
                ),
                IconButton(
                  key: const Key('sftpTransferListButton'),
                  style: _highlightTransferButton
                      ? IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                  icon: KeyedSubtree(
                    key: _transferIconKey,
                    child: Badge(
                      isLabelVisible: state.pendingTransferCount > 0,
                      label: Text('${state.pendingTransferCount}'),
                      child: const Icon(Icons.swap_vert, size: 20),
                    ),
                  ),
                  tooltip: context.l10n.transferList,
                  onPressed: () => _showTransferListModal(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(SftpState state) {
    final files = state.filteredFiles;
    final notifier = ref.read(sftpProvider.notifier);

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              context.l10n.sftpEmpty,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < LayoutBreakpoints.compactMax;
        if (isCompact) {
          return ListView.separated(
            itemCount: files.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = files[index];
              return _buildFileListItem(context, item, state, notifier);
            },
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: LayoutBreakpoints.gridFileListMaxExtent,
            mainAxisExtent: 72,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final item = files[index];
            return Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: _buildFileListItem(context, item, state, notifier),
            );
          },
        );
      },
    );
  }

  Widget _buildFileListItem(
    BuildContext context,
    SftpFileItem item,
    SftpState state,
    SftpNotifier notifier,
  ) {
    final isDotDot = item.name == '..';
    final isSpecialNav = isDotDot;

    return ListTile(
      leading: Icon(
        item.isDirectory ? Icons.folder : _getFileIcon(item.name),
        color: item.isDirectory ? context.colorScheme.primary : null,
        size: 22,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: item.isDirectory ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: isSpecialNav
          ? null
          : Row(
              children: [
                Flexible(
                  child: Text(
                    item.permissions,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(item.formattedSize, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.modified,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      trailing: isSpecialNav
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) {
                if (action == 'rename') {
                  _showRenameDialog(item);
                } else if (action == 'delete') {
                  _showDeleteConfirmDialog(item);
                } else if (action == 'open') {
                  _openFileEditor(item);
                } else if (action == 'download') {
                  final ro = context.findRenderObject();
                  final box = ro is RenderBox ? ro : null;
                  final offset = box != null && box.hasSize
                      ? box.localToGlobal(
                          Offset(box.size.width / 2, box.size.height / 2),
                        )
                      : null;
                  _handleDownload(item, offset);
                }
              },
              itemBuilder: (context) => [
                // 仅纯文本 / 代码可预览编辑（目录与二进制不出现 Open）
                if (notifier.canPreview(item))
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, size: 18),
                        const SizedBox(width: 8),
                        Text(context.l10n.sftpOpen),
                      ],
                    ),
                  ),
                if (!item.isDirectory)
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 8),
                        Text(context.l10n.sftpDownload),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_rename_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.delete,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      onTap: () {
        if (isDotDot) {
          notifier.navigateUp();
        } else if (item.isDirectory) {
          notifier.navigateTo(item.path);
        } else {
          _openFileEditor(item);
        }
      },
    );
  }

  IconData _getFileIcon(String filename) {
    if (filename.endsWith('.json') ||
        filename.endsWith('.yml') ||
        filename.endsWith('.yaml')) {
      return Icons.data_object;
    }
    if (filename.endsWith('.conf') ||
        filename.endsWith('.env') ||
        filename.startsWith('.')) {
      return Icons.settings_applications;
    }
    if (filename.endsWith('.md') || filename.endsWith('.txt')) {
      return Icons.description;
    }
    if (filename.endsWith('.sh') || filename.endsWith('.bash')) {
      return Icons.terminal;
    }
    return Icons.insert_drive_file;
  }
}

class SftpTransferListSheet extends ConsumerWidget {
  const SftpTransferListSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sftpState = ref.watch(sftpProvider);
    final notifier = ref.read(sftpProvider.notifier);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.transferList,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('transferClearFinishedButton'),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text(context.l10n.transferClearFinished),
                    onPressed: sftpState.hasFinishedTransfers
                        ? () => notifier.clearFinishedTransfers()
                        : null,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('transferSheetCloseButton'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (sftpState.downloadNotificationsUnavailable) ...[
              Container(
                key: const Key('downloadNotificationsUnavailableSheetBanner'),
                color: context.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 16,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.downloadNotificationsUnavailable,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: sftpState.transfers.isEmpty
                  ? Center(
                      key: const Key('transferEmptyView'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swap_vert,
                            size: 48,
                            color: context.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.transferEmpty,
                            style: TextStyle(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      key: const Key('transferListView'),
                      itemCount: sftpState.transfers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final transfer = sftpState.transfers[index];
                        return SftpTransferListItem(transfer: transfer);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SftpTransferListItem extends ConsumerWidget {
  final SftpTransfer transfer;

  const SftpTransferListItem({super.key, required this.transfer});

  String _mapTransferError(BuildContext context, String? code) {
    if (code == SftpNotifier.uploadFailedCode) {
      return context.l10n.transferFailedUpload;
    }
    if (code == SftpNotifier.downloadFailedCode) {
      return context.l10n.transferFailedDownload;
    }
    return context.l10n.transferStatusFailed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sftpProvider.notifier);
    final isUpload = transfer.kind == SftpTransferKind.upload;
    final kindText = isUpload
        ? context.l10n.transferUpload
        : context.l10n.transferDownload;

    final statusText = switch (transfer.status) {
      SftpTransferStatus.queued => context.l10n.transferStatusQueued,
      SftpTransferStatus.running => context.l10n.transferStatusRunning,
      SftpTransferStatus.paused => context.l10n.transferStatusPaused,
      SftpTransferStatus.completed => context.l10n.transferStatusCompleted,
      SftpTransferStatus.failed => context.l10n.transferStatusFailed,
      SftpTransferStatus.canceled => context.l10n.transferStatusCanceled,
    };

    final String sizeText;
    if (transfer.progress != null) {
      final percent = (transfer.progress! * 100).toStringAsFixed(0);
      final transferred = SftpFileItem.formatBytes(transfer.transferredBytes);
      final total = SftpFileItem.formatBytes(transfer.totalBytes);
      sizeText = '$transferred / $total ($percent%)';
    } else {
      if (transfer.transferredBytes > 0) {
        final transferred = SftpFileItem.formatBytes(transfer.transferredBytes);
        sizeText = '$transferred / ${context.l10n.transferSizeUnknown}';
      } else {
        sizeText = context.l10n.transferSizeUnknown;
      }
    }

    final double? progressValue;
    if (transfer.status == SftpTransferStatus.running) {
      progressValue = transfer.progress;
    } else if (transfer.status == SftpTransferStatus.completed) {
      progressValue = 1.0;
    } else if (transfer.status == SftpTransferStatus.queued) {
      progressValue = 0.0;
    } else {
      progressValue = transfer.progress ?? 0.0;
    }

    final canPause =
        transfer.status == SftpTransferStatus.queued ||
        transfer.status == SftpTransferStatus.running;
    final canResume = transfer.status == SftpTransferStatus.paused;
    final canCancel =
        transfer.status == SftpTransferStatus.queued ||
        transfer.status == SftpTransferStatus.running ||
        transfer.status == SftpTransferStatus.paused;
    final canRemove = transfer.status != SftpTransferStatus.running;
    final isCompletedDownload =
        transfer.kind == SftpTransferKind.download &&
        transfer.status == SftpTransferStatus.completed;

    final hasError = transfer.status == SftpTransferStatus.failed;
    final errorText = hasError && transfer.errorMessage != null
        ? _mapTransferError(context, transfer.errorMessage)
        : null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpload ? Icons.upload : Icons.download,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: Key('transfer_name_${transfer.id}'),
                  onTap: isCompletedDownload
                      ? () => notifier.openCompletedTransfer(transfer.id)
                      : null,
                  child: Text(
                    transfer.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isCompletedDownload)
                IconButton(
                  key: Key('transfer_open_${transfer.id}'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: context.l10n.sftpOpen,
                  onPressed: () => notifier.openCompletedTransfer(transfer.id),
                ),
              if (canPause)
                IconButton(
                  key: Key('transfer_pause_${transfer.id}'),
                  icon: const Icon(Icons.pause, size: 18),
                  tooltip: context.l10n.transferPause,
                  onPressed: () => notifier.pauseTransfer(transfer.id),
                ),
              if (canResume)
                IconButton(
                  key: Key('transfer_resume_${transfer.id}'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  tooltip: context.l10n.transferResume,
                  onPressed: () => notifier.resumeTransfer(transfer.id),
                ),
              if (canCancel)
                IconButton(
                  key: Key('transfer_cancel_${transfer.id}'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: context.l10n.transferCancel,
                  onPressed: () => notifier.cancelTransfer(transfer.id),
                ),
              if (canRemove)
                IconButton(
                  key: Key('transfer_remove_${transfer.id}'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: context.l10n.transferRemove,
                  onPressed: () => notifier.removeTransfer(transfer.id),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '[$kindText] $statusText',
                style: TextStyle(
                  fontSize: 12,
                  color: hasError
                      ? context.colorScheme.error
                      : context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                sizeText,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 2),
            Text(
              errorText,
              key: Key('transfer_error_${transfer.id}'),
              style: TextStyle(fontSize: 12, color: context.colorScheme.error),
            ),
          ],
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 3,
            color: hasError
                ? context.colorScheme.error
                : (transfer.status == SftpTransferStatus.canceled
                      ? context.colorScheme.outline
                      : null),
          ),
        ],
      ),
    );

    return InkWell(
      key: Key('transfer_item_${transfer.id}'),
      onTap: isCompletedDownload
          ? () => notifier.openCompletedTransfer(transfer.id)
          : null,
      child: content,
    );
  }
}
