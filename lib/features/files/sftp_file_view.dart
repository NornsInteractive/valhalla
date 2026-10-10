import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/file_bookmarks_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/sftp_provider.dart';
import '../../infrastructure/sftp/remote_file_actions.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/valhalla_card.dart';
import 'widgets/batch_confirm_dialog.dart';
import 'widgets/file_bookmarks_dialog.dart';
import 'widgets/remote_file_batch_results_dialog.dart';
import 'widgets/sftp_directory_picker_dialog.dart';

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
  final ScrollController _breadcrumbScrollController = ScrollController();
  final GlobalKey _transferIconKey = GlobalKey();
  final List<AnimationController> _activeAnimControllers = [];
  final List<OverlayEntry> _activeOverlayEntries = [];
  Timer? _highlightTimer;
  bool _highlightTransferButton = false;
  bool _isTogglingHiddenFiles = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  bool _isBatchRunning = false;
  int? _batchCompleted;
  int? _batchTotal;
  bool _isTogglingBookmark = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _breadcrumbScrollController.hasClients) {
        _breadcrumbScrollController.jumpTo(
          _breadcrumbScrollController.position.maxScrollExtent,
        );
      }
    });
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
    _breadcrumbScrollController.dispose();
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
    if (!ref.read(serverConnectionProvider).isConnected) return;
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
    if (!ref.read(serverConnectionProvider).isConnected) return;
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
    if (!ref.read(serverConnectionProvider).isConnected) return;
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
    if (!ref.read(serverConnectionProvider).isConnected) return;
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
            style: FilledButton.styleFrom(backgroundColor: ctx.vDanger),
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
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
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
            if (isSaving || !ref.read(serverConnectionProvider).isConnected) {
              return;
            }
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
                    Text(item.name, style: theme.textTheme.titleMedium),
                    Text(
                      item.path,
                      style: monoTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                actions: [
                  FilledButton.icon(
                    key: const Key('sftp_editor_save_button'),
                    icon: isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(
                      isSaving ? ctx.l10n.sftpSaving : ctx.l10n.fileEditorSave,
                    ),
                    onPressed:
                        (isSaving ||
                            !ref.read(serverConnectionProvider).isConnected)
                        ? null
                        : handleSave,
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
                        style: monoTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
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
    if (!ref.read(serverConnectionProvider).isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
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
    if (!ref.read(serverConnectionProvider).isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return null;
    }
    if (item.linkTargetErrorCode != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapErrorMessage(item.linkTargetErrorCode!))),
      );
      return null;
    }
    final taskId = await ref.read(sftpProvider.notifier).downloadFile(item);
    if (taskId != null) {
      _animateFlyToTransfer(startOffset);
    }
    return taskId;
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPaths.clear();
      }
    });
  }

  void _toggleSelect(SftpFileItem item) {
    if (item.name == '..') return;
    setState(() {
      if (_selectedPaths.contains(item.path)) {
        _selectedPaths.remove(item.path);
      } else {
        _selectedPaths.add(item.path);
      }
    });
  }

  void _selectAll() {
    final files = ref.read(sftpProvider).filteredFiles;
    setState(() {
      _selectedPaths.clear();
      for (final f in files) {
        if (f.name != '..') {
          _selectedPaths.add(f.path);
        }
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  void _showBookmarksDialog() {
    final currentPath = ref.read(sftpProvider).currentPath;
    FileBookmarksDialog.show(
      context,
      currentPath: currentPath,
      onSelectPath: (path) {
        ref.read(sftpProvider.notifier).navigateTo(path);
      },
    );
  }

  Future<void> _handleBatchAction(RemoteFileAction action) async {
    if (_isBatchRunning) return;
    final expectedServer = ref.read(activeServerProvider);
    if (expectedServer == null) return;

    final files = ref.read(sftpProvider).filteredFiles;
    final selectedItems = files
        .where((f) => _selectedPaths.contains(f.path))
        .toList();
    if (selectedItems.isEmpty) return;

    String? targetDirectory;
    if (action == RemoteFileAction.copy || action == RemoteFileAction.move) {
      final selectedPathsSet = selectedItems.map((e) => e.path).toSet();
      final chosenDir = await SftpDirectoryPickerDialog.show(
        context,
        initialPath: ref.read(sftpProvider).currentPath,
        title: action == RemoteFileAction.copy
            ? context.l10n.sftpBatchCopy
            : context.l10n.sftpBatchMove,
        restrictedPaths: selectedPathsSet,
      );
      if (chosenDir == null || !mounted) return;
      if (!(ref
              .read(activeServerProvider)
              ?.hasSameConnectionSettings(expectedServer) ??
          false)) {
        return;
      }
      targetDirectory = chosenDir;
    }

    final confirmed = await BatchConfirmDialog.show(
      context,
      action: action,
      items: selectedItems,
      targetDirectory: targetDirectory,
    );
    if (!confirmed || !mounted) return;
    if (!(ref
            .read(activeServerProvider)
            ?.hasSameConnectionSettings(expectedServer) ??
        false)) {
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);

    setState(() {
      _isBatchRunning = true;
      _batchCompleted = 0;
      _batchTotal = selectedItems.length;
    });

    try {
      final results = await ref
          .read(sftpProvider.notifier)
          .runBatch(
            action,
            selectedItems,
            targetDirectory: targetDirectory,
            expectedServer: expectedServer,
            onProgress: (completed, total) {
              if (mounted) {
                setState(() {
                  _batchCompleted = completed;
                  _batchTotal = total;
                });
              }
            },
          );

      if (!mounted) return;
      if (!(ref
              .read(activeServerProvider)
              ?.hasSameConnectionSettings(expectedServer) ??
          false)) {
        return;
      }

      setState(() {
        _isSelectionMode = false;
        _selectedPaths.clear();
      });

      final hasFailures = results.any(
        (r) =>
            r.outcome == RemoteFileOutcome.failed ||
            r.outcome == RemoteFileOutcome.skipped,
      );

      if (hasFailures) {
        if (mounted) {
          await RemoteFileBatchResultsDialog.show(context, results: results);
        }
      } else {
        final queuedCount = results
            .where((r) => r.outcome == RemoteFileOutcome.queued)
            .length;
        final successMsg = queuedCount > 0
            ? '${context.l10n.transferStatusQueued} ($queuedCount)'
            : context.l10n.sftpBatchOperationSuccess(results.length);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: context.vSuccess,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: context.vDanger),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBatchRunning = false;
          _batchCompleted = null;
          _batchTotal = null;
        });
      }
    }
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
    if (code == SftpFileItem.linkTargetUnavailableCode ||
        code == 'SFTP_LINK_TARGET_UNAVAILABLE') {
      return context.l10n.sftpLinkTargetUnavailable;
    }
    if (code == SftpFileItem.linkTargetPermissionDeniedCode ||
        code == 'SFTP_LINK_TARGET_PERMISSION_DENIED') {
      return context.l10n.sftpLinkTargetPermissionDenied;
    }
    if (code == SftpNotifier.hiddenPreferenceSaveFailedCode ||
        code == 'SFTP_HIDDEN_PREFERENCE_SAVE_FAILED') {
      return context.l10n.sftpHiddenPreferenceSaveFailed;
    }
    if (code == 'SSH_DISCONNECTED' || code == 'SFTP_DOWNLOAD_DISCONNECTED') {
      return context.l10n.sftpDownloadDisconnected;
    }
    if (code == 'SFTP_DOWNLOAD_PERMISSION_DENIED') {
      return context.l10n.sftpDownloadPermissionDenied;
    }
    if (code == 'SFTP_DOWNLOAD_NOT_FOUND') {
      return context.l10n.sftpDownloadNotFound;
    }
    if (code == 'SFTP_DOWNLOAD_TIMEOUT') {
      return context.l10n.sftpDownloadTimeout;
    }
    if (code == 'SFTP_DOWNLOAD_LOCAL_SPACE') {
      return context.l10n.sftpDownloadLocalSpace;
    }
    if (code == 'SFTP_DOWNLOAD_LOCAL_IO') {
      return context.l10n.sftpDownloadLocalIo;
    }
    if (code == 'SFTP_DOWNLOAD_INCOMPLETE') {
      return context.l10n.sftpDownloadIncomplete;
    }
    if (code == 'SFTP_DOWNLOAD_FAILED' ||
        code == SftpNotifier.downloadFailedCode) {
      return context.l10n.sftpDownloadFailed;
    }
    if (code == SftpNotifier.uploadFailedCode) {
      return context.l10n.sftpUploadFailed;
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
    if (errorCode == 'SSH_DISCONNECTED') {
      return const SizedBox.shrink();
    }
    final message = _mapErrorMessage(errorCode);
    final isOffline =
        errorCode == 'SSH_DISCONNECTED' ||
        errorCode == 'SFTP_DOWNLOAD_DISCONNECTED';
    return Container(
      key: const Key('sftpErrorBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOffline
          ? context.colorScheme.surfaceContainerHighest
          : context.colorScheme.errorContainer.withValues(alpha: 0.8),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.link_off : Icons.error_outline,
            size: 18,
            color: isOffline
                ? context.colorScheme.onSurfaceVariant
                : context.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isOffline
                    ? context.colorScheme.onSurfaceVariant
                    : context.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: isOffline
                  ? context.colorScheme.onSurfaceVariant
                  : context.colorScheme.onErrorContainer,
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
                  style: monoTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (progress != null)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: monoTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (progress != null)
            AnimatedProgressBar(
              value: progress,
              height: 3,
              color: context.colorScheme.primary,
            )
          else
            const LinearProgressIndicator(minHeight: 3),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _breadcrumbScrollController.hasClients) {
            final target = _breadcrumbScrollController.position.maxScrollExtent;
            if (MediaQuery.disableAnimationsOf(context)) {
              _breadcrumbScrollController.jumpTo(target);
            } else {
              _breadcrumbScrollController.animateTo(
                target,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });
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
          child: (sftpState.isLoading && sftpState.files.isEmpty)
              ? Shimmer(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
                    itemCount: 8,
                    itemBuilder: (_, _) => const SkeletonListTile(),
                  ),
                )
              : _buildFileList(sftpState),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbBar(SftpState state) {
    final notifier = ref.read(sftpProvider.notifier);
    final segments = state.pathSegments;
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    return Entrance(
      index: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: context.colorScheme.surface,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              IconButton(
                key: const Key('sftp_breadcrumb_up'),
                icon: const Icon(Icons.arrow_upward, size: 18),
                tooltip: context.l10n.sftpUpDirectory,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: (state.isAtRoot || !isConnected)
                    ? null
                    : () => notifier.navigateUp(),
              ),
              _buildBreadcrumbSegment(
                key: const Key('sftp_breadcrumb_root'),
                label: '/',
                tooltip: '/',
                isCurrent: state.isAtRoot,
                onTap: isConnected ? () => notifier.navigateTo('/') : null,
                maxWidth: 44,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SingleChildScrollView(
                  controller: _breadcrumbScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(segments.length, (index) {
                      final seg = segments[index];
                      final pathUpTo = '/${segments.take(index + 1).join('/')}';
                      final isLast = index == segments.length - 1;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_right,
                            size: 10,
                            color: context.colorScheme.outline,
                          ),
                          _buildBreadcrumbSegment(
                            key: Key('sftp_breadcrumb_seg_$index'),
                            label: seg,
                            tooltip: pathUpTo,
                            isCurrent: isLast,
                            onTap: isConnected
                                ? () => notifier.navigateTo(pathUpTo)
                                : null,
                            maxWidth: 120,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                key: const Key('sftp_current_path_bookmark_button'),
                icon: Icon(
                  ref.watch(fileBookmarksProvider).contains(state.currentPath)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 18,
                  color:
                      ref
                          .watch(fileBookmarksProvider)
                          .contains(state.currentPath)
                      ? context.colorScheme.primary
                      : null,
                ),
                tooltip:
                    ref.watch(fileBookmarksProvider).contains(state.currentPath)
                    ? context.l10n.sftpRemoveBookmark
                    : context.l10n.sftpAddBookmark,
                onPressed: (isConnected && !_isTogglingBookmark)
                    ? () async {
                        if (_isTogglingBookmark) return;
                        setState(() => _isTogglingBookmark = true);
                        try {
                          await ref
                              .read(fileBookmarksProvider.notifier)
                              .toggle(state.currentPath);
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
                            setState(() => _isTogglingBookmark = false);
                          }
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbSegment({
    Key? key,
    required String label,
    required String tooltip,
    required bool isCurrent,
    required VoidCallback? onTap,
    double maxWidth = 120,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(VRadius.button),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 44,
            minWidth: 24,
            maxWidth: maxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoTextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isCurrent
                    ? context.colorScheme.onSurface
                    : (onTap != null
                          ? context.colorScheme.primary
                          : context.colorScheme.outline),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(SftpState state) {
    if (_isSelectionMode) {
      return _buildSelectionActionBar(state);
    }
    final notifier = ref.read(sftpProvider.notifier);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    return Entrance(
      index: 1,
      child: Container(
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
                    hintStyle: context.textTheme.bodySmall,
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
                      borderRadius: BorderRadius.circular(VRadius.input),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: context.colorScheme.surfaceContainerHighest,
                  ),
                  style: context.textTheme.bodyMedium,
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
                    onPressed: (state.activeTransfer != null || !isConnected)
                        ? null
                        : _handleUpload,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                    tooltip: context.l10n.sftpNewFolder,
                    onPressed: isConnected ? _showNewFolderDialog : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined, size: 20),
                    tooltip: context.l10n.sftpNewFile,
                    onPressed: isConnected ? _showNewFileDialog : null,
                  ),
                  IconButton(
                    key: const Key('sftpToggleHiddenButton'),
                    isSelected: state.showHiddenFiles,
                    icon: const Icon(Icons.visibility_off, size: 20),
                    selectedIcon: const Icon(Icons.visibility, size: 20),
                    tooltip: state.showHiddenFiles
                        ? context.l10n.sftpHideHiddenFiles
                        : context.l10n.sftpShowHiddenFiles,
                    style: state.showHiddenFiles
                        ? IconButton.styleFrom(
                            foregroundColor: context.colorScheme.primary,
                          )
                        : null,
                    onPressed: _isTogglingHiddenFiles
                        ? null
                        : () async {
                            if (_isTogglingHiddenFiles) return;
                            setState(() {
                              _isTogglingHiddenFiles = true;
                            });
                            try {
                              await notifier.setShowHiddenFiles(
                                !state.showHiddenFiles,
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isTogglingHiddenFiles = false;
                                });
                              }
                            }
                          },
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
                    onPressed: isConnected ? () => notifier.refresh() : null,
                  ),
                  IconButton(
                    key: const Key('sftpBookmarksListButton'),
                    icon: const Icon(Icons.bookmarks_outlined, size: 20),
                    tooltip: context.l10n.sftpBookmarksTitle,
                    onPressed: isConnected ? _showBookmarksDialog : null,
                  ),
                  IconButton(
                    key: const Key('sftpSelectModeButton'),
                    icon: const Icon(Icons.checklist, size: 20),
                    tooltip: context.l10n.sftpSelectMode,
                    onPressed: _toggleSelectionMode,
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
      ),
    );
  }

  Widget _buildSelectionActionBar(SftpState state) {
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final count = _selectedPaths.length;

    return Entrance(
      index: 1,
      child: Container(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: context.l10n.cancel,
                onPressed: _toggleSelectionMode,
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.sftpSelectedCount(count),
                style: context.textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('sftpSelectAllButton'),
                onPressed: _selectAll,
                child: Text(context.l10n.sftpSelectAll),
              ),
              TextButton(
                key: const Key('sftpDeselectAllButton'),
                onPressed: _selectedPaths.isEmpty ? null : _deselectAll,
                child: Text(context.l10n.sftpDeselectAll),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('sftpBatchDownloadButton'),
                icon: const Icon(Icons.download, size: 20),
                tooltip: context.l10n.sftpDownload,
                onPressed: (count == 0 || _isBatchRunning || !isConnected)
                    ? null
                    : () => _handleBatchAction(RemoteFileAction.download),
              ),
              IconButton(
                key: const Key('sftpBatchCopyButton'),
                icon: const Icon(Icons.copy, size: 20),
                tooltip: context.l10n.sftpBatchCopy,
                onPressed: (count == 0 || _isBatchRunning || !isConnected)
                    ? null
                    : () => _handleBatchAction(RemoteFileAction.copy),
              ),
              IconButton(
                key: const Key('sftpBatchMoveButton'),
                icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                tooltip: context.l10n.sftpBatchMove,
                onPressed: (count == 0 || _isBatchRunning || !isConnected)
                    ? null
                    : () => _handleBatchAction(RemoteFileAction.move),
              ),
              IconButton(
                key: const Key('sftpBatchDeleteButton'),
                icon: Icon(Icons.delete, size: 20, color: context.vDanger),
                tooltip: context.l10n.delete,
                onPressed: (count == 0 || _isBatchRunning || !isConnected)
                    ? null
                    : () => _handleBatchAction(RemoteFileAction.delete),
              ),
              if (_isBatchRunning) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                if (_batchTotal != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$_batchCompleted/$_batchTotal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList(SftpState state) {
    final files = state.filteredFiles;
    final notifier = ref.read(sftpProvider.notifier);

    if (files.isEmpty) {
      return EmptyStateView(
        icon: Icons.folder_open,
        title: context.l10n.sftpEmpty,
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
            return ValhallaCard(
              margin: EdgeInsets.zero,
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
    final isSelected = _selectedPaths.contains(item.path);

    final Widget fileIconWidget;
    if (item.isSymbolicLink) {
      final isBroken = item.linkTargetErrorCode != null;
      fileIconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            item.isDirectory ? Icons.folder : _getFileIcon(item.name),
            color: isBroken
                ? context.colorScheme.outline
                : (item.isDirectory ? context.colorScheme.primary : null),
            size: 22,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Semantics(
              label: context.l10n.sftpSymlink,
              child: Tooltip(
                key: const Key('sftp_symlink_badge'),
                message: context.l10n.sftpSymlink,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBroken ? Icons.link_off : Icons.shortcut,
                    size: 11,
                    color: isBroken
                        ? context.colorScheme.error
                        : context.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      fileIconWidget = Icon(
        item.isDirectory ? Icons.folder : _getFileIcon(item.name),
        color: item.isDirectory ? context.colorScheme.primary : null,
        size: 22,
      );
    }

    final Widget leadingWidget;
    if (_isSelectionMode && !isSpecialNav) {
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSelect(item),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          fileIconWidget,
        ],
      );
    } else {
      leadingWidget = fileIconWidget;
    }

    return ListTile(
      selected: _isSelectionMode && isSelected,
      leading: leadingWidget,
      title: Text(
        item.name,
        style: item.isDirectory
            ? context.textTheme.titleSmall
            : context.textTheme.bodyMedium,
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
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.formattedSize,
                  style: monoTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.modified,
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      trailing: (isSpecialNav || _isSelectionMode)
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) {
                if (!ref.read(serverConnectionProvider).isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.stateOffline)),
                  );
                  return;
                }
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
                if (!item.isDirectory && item.linkTargetErrorCode == null)
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
                      Icon(Icons.delete, color: context.vDanger, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.delete,
                        style: TextStyle(color: context.vDanger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      onLongPress: (!isSpecialNav && !_isSelectionMode)
          ? () {
              setState(() {
                _isSelectionMode = true;
                _selectedPaths.add(item.path);
              });
            }
          : null,
      onTap: () {
        if (!ref.read(serverConnectionProvider).isConnected) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
          return;
        }
        if (_isSelectionMode) {
          if (!isSpecialNav) {
            _toggleSelect(item);
            return;
          }
        }
        if (isDotDot) {
          notifier.navigateUp();
        } else if (item.linkTargetErrorCode != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_mapErrorMessage(item.linkTargetErrorCode!)),
            ),
          );
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
            Entrance(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      context.l10n.transferList,
                      style: context.textTheme.titleMedium,
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
                      child: EmptyStateView(
                        icon: Icons.swap_vert,
                        title: context.l10n.transferEmpty,
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
    if (code == null) return context.l10n.transferStatusFailed;
    if (code == 'SSH_DISCONNECTED' || code == 'SFTP_DOWNLOAD_DISCONNECTED') {
      return context.l10n.sftpDownloadDisconnected;
    }
    if (code == 'SFTP_DOWNLOAD_PERMISSION_DENIED') {
      return context.l10n.sftpDownloadPermissionDenied;
    }
    if (code == 'SFTP_DOWNLOAD_NOT_FOUND') {
      return context.l10n.sftpDownloadNotFound;
    }
    if (code == 'SFTP_DOWNLOAD_TIMEOUT') {
      return context.l10n.sftpDownloadTimeout;
    }
    if (code == 'SFTP_DOWNLOAD_LOCAL_SPACE') {
      return context.l10n.sftpDownloadLocalSpace;
    }
    if (code == 'SFTP_DOWNLOAD_LOCAL_IO') {
      return context.l10n.sftpDownloadLocalIo;
    }
    if (code == 'SFTP_DOWNLOAD_INCOMPLETE') {
      return context.l10n.sftpDownloadIncomplete;
    }
    if (code == 'SFTP_DOWNLOAD_FAILED' ||
        code == SftpNotifier.downloadFailedCode) {
      return context.l10n.sftpDownloadFailed;
    }
    if (code == SftpNotifier.uploadFailedCode) {
      return context.l10n.transferFailedUpload;
    }
    return context.l10n.transferStatusFailed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sftpProvider.notifier);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final isUpload = transfer.kind == SftpTransferKind.upload;
    final kindText = isUpload
        ? context.l10n.transferUpload
        : context.l10n.transferDownload;

    final statusText = switch (transfer.status) {
      SftpTransferStatus.queued => context.l10n.transferStatusQueued,
      SftpTransferStatus.running => context.l10n.transferStatusRunning,
      SftpTransferStatus.paused =>
        (transfer.errorMessage == 'SSH_DISCONNECTED' ||
                transfer.errorMessage == 'SFTP_DOWNLOAD_DISCONNECTED')
            ? context.l10n.transferStatusWaitingConnection
            : context.l10n.transferStatusPaused,
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
                    style: context.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isCompletedDownload)
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                  IconButton(
                    key: Key('transfer_reveal_${transfer.id}'),
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    tooltip: context.l10n.downloadReveal,
                    onPressed: () async {
                      try {
                        await notifier.revealCompletedTransfer(transfer.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.downloadRevealFailed),
                            ),
                          );
                        }
                      }
                    },
                  ),
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
                  onPressed: isConnected
                      ? () => notifier.resumeTransfer(transfer.id)
                      : null,
                ),
              if (transfer.status == SftpTransferStatus.failed)
                IconButton(
                  key: Key('transfer_retry_${transfer.id}'),
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: context.l10n.stateRetry,
                  onPressed: isConnected
                      ? () async {
                          try {
                            await notifier.retryTransfer(transfer.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: context.vDanger,
                                ),
                              );
                            }
                          }
                        }
                      : null,
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
              if (transfer.status == SftpTransferStatus.running) ...[
                PulseDot(color: context.vInfo, size: 6),
                const SizedBox(width: 6),
              ],
              Text(
                '[$kindText] $statusText',
                style: context.textTheme.bodySmall?.copyWith(
                  color: hasError
                      ? context.colorScheme.error
                      : context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                sizeText,
                style: monoTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
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
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (progressValue != null)
            AnimatedProgressBar(
              value: progressValue,
              height: 3,
              color: hasError
                  ? context.colorScheme.error
                  : (transfer.status == SftpTransferStatus.canceled
                        ? context.colorScheme.outline
                        : null),
            )
          else
            // 未知的传输总量: 保持不确定态动画。
            const LinearProgressIndicator(minHeight: 3),
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
