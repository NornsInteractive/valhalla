import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants/layout_breakpoints.dart';
import '../core/extensions/context_extensions.dart';
import '../core/services/remote_browser_service.dart';
import '../core/utils/file_preview.dart';
import '../data/models/nas_media.dart';
import '../data/models/remote_browser.dart';
import 'valhalla_card.dart';
import 'remote_browser_toolbar.dart';

enum RemoteBrowserMode {
  directory,
  file,
  multipleFiles,
  mediaLibrary,
  multipleLibraries,
}

enum RemoteBrowserViewMode { list, grid, gallery }

enum RemoteBrowserSortField { name, size, date }

/// Shared virtualized presentation; data, actions and connections stay with callers.
class RemoteBrowserEntriesView extends StatefulWidget {
  final List<RemoteBrowserEntry> entries;
  final RemoteBrowserViewMode viewMode;
  final Widget Function(BuildContext, RemoteBrowserEntry) itemBuilder;
  final ScrollController? controller;
  final String? locationKey;
  final bool detailedMetadata;

  const RemoteBrowserEntriesView({
    super.key,
    required this.entries,
    required this.viewMode,
    required this.itemBuilder,
    this.controller,
    this.locationKey,
    this.detailedMetadata = false,
  });

  @override
  State<RemoteBrowserEntriesView> createState() =>
      _RemoteBrowserEntriesViewState();
}

class _RemoteBrowserEntriesViewState extends State<RemoteBrowserEntriesView> {
  final _ownedController = ScrollController(keepScrollOffset: false);
  final _locations = <String?, double>{};
  int _columns = 1;
  double _rowExtent = 72;
  double? _restoreOffset;
  String? _anchorId;
  double _anchorFraction = 0;
  int _layoutGeneration = 0;

  ScrollController get _controller => widget.controller ?? _ownedController;

  void _captureAnchor(List<RemoteBrowserEntry> entries, double pad) {
    if (!_controller.hasClients || entries.isEmpty) return;
    final rows = math.max(0.0, _controller.offset - pad) / _rowExtent;
    final index = (rows.ceil() * _columns).clamp(0, entries.length - 1);
    _anchorId = entries[index].id;
    _anchorFraction = rows - rows.ceil();
  }

  @override
  void didUpdateWidget(covariant RemoteBrowserEntriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationKey != widget.locationKey) {
      if (_controller.hasClients) {
        _locations[oldWidget.locationKey] = _controller.offset;
      }
      _anchorId = null;
      _restoreOffset = _locations[widget.locationKey] ?? 0;
    } else if (oldWidget.viewMode != widget.viewMode) {
      final oldList = oldWidget.viewMode == RemoteBrowserViewMode.list;
      _captureAnchor(oldWidget.entries, oldList ? 12.0 : 8.0);
    }
  }

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final large = scale >= 1.35;
      final list = widget.viewMode == RemoteBrowserViewMode.list;
      final gallery = widget.viewMode == RemoteBrowserViewMode.gallery;
      final pad = list ? 12.0 : 8.0;
      final columns = list
          ? 1
          : constraints.maxWidth < LayoutBreakpoints.compactMax
          ? (large ? 1 : 2)
          : math.max(
              large ? 1 : 2,
              ((constraints.maxWidth - 24) / (large ? 420 : 240)).floor(),
            );
      final rowExtent = list
          ? math.max(72.0, 40.0 + 32.0 * scale)
          : (gallery
                ? 192.0 + math.max(0, scale - 1) * 64 + 8
                : 92.0 + math.max(0, scale - 1) * 84 + 8);
      if ((_columns != columns || _rowExtent != rowExtent) &&
          _anchorId == null &&
          _restoreOffset == null) {
        _captureAnchor(widget.entries, pad);
      }
      _columns = columns;
      _rowExtent = rowExtent;
      if (_anchorId != null || _restoreOffset != null) {
        final index = widget.entries.indexWhere(
          (entry) => entry.id == _anchorId,
        );
        final target =
            _restoreOffset ??
            (index < 0
                ? 0.0
                : pad + (index ~/ columns + _anchorFraction) * rowExtent);
        _anchorId = null;
        _restoreOffset = null;
        final generation = ++_layoutGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              generation != _layoutGeneration ||
              !_controller.hasClients) {
            return;
          }
          _controller.jumpTo(
            target.clamp(0.0, _controller.position.maxScrollExtent),
          );
        });
      }
      final key = PageStorageKey(widget.locationKey);
      if (list) {
        return ListView.builder(
          key: key,
          controller: _controller,
          padding: EdgeInsets.all(pad),
          itemExtent: rowExtent,
          itemCount: widget.entries.length,
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, widget.entries[index]),
        );
      }
      return GridView.builder(
        key: key,
        controller: _controller,
        padding: EdgeInsets.all(pad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: rowExtent - 8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.entries.length,
        itemBuilder: (context, index) =>
            widget.itemBuilder(context, widget.entries[index]),
      );
    },
  );
}

class RemoteBrowserEntryTile extends StatelessWidget {
  final RemoteBrowserEntry entry;
  final RemoteBrowserViewMode viewMode;
  final bool selected;
  final bool flat;
  final Uint8List? previewBytes;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final Widget? metadata;
  final String? date;
  final bool isThreeLine;
  final double trailingGap;
  final double leadingGap;
  final Widget? titleSuffix;

  const RemoteBrowserEntryTile({
    super.key,
    required this.entry,
    required this.viewMode,
    this.selected = false,
    this.flat = false,
    this.previewBytes,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.leading,
    this.trailing,
    this.metadata,
    this.date,
    this.isThreeLine = false,
    this.trailingGap = 16.0,
    this.leadingGap = 16.0,
    this.titleSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final hidden = entry.isHidden && entry.name != '..';
    final titleColor = hidden
        ? colors.onSurface.withValues(alpha: 0.62)
        : colors.onSurface;
    final icon = flat
        ? Icons.video_library
        : entry.isDirectory
        ? Icons.folder
        : entry.mimeType?.startsWith('image/') == true
        ? Icons.image_outlined
        : entry.mimeType?.startsWith('audio/') == true
        ? Icons.audiotrack
        : entry.mimeType?.startsWith('video/') == true
        ? Icons.movie
        : Icons.insert_drive_file;
    final iconSize = (viewMode == RemoteBrowserViewMode.grid && !flat)
        ? 22.0
        : 28.0;
    final visual =
        leading ??
        Icon(
          icon,
          size: iconSize,
          color: (entry.selectable ? colors.primary : colors.outline)
              .withValues(alpha: hidden ? 0.62 : 1),
        );
    final meta =
        metadata ??
        Text(
          flat
              ? l10n.nasTabLibrary
              : entry.isDirectory
              ? l10n.appCenterTaskDirectory
              : entry.sizeBytes == null
              ? ''
              : _formatBytes(entry.sizeBytes!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: hidden ? 0.62 : 1),
          ),
        );
    final list = viewMode == RemoteBrowserViewMode.list;
    final grid = viewMode == RemoteBrowserViewMode.grid;
    final Widget? fallbackEnd;
    if (selected) {
      final icon = Icon(Icons.check_circle, size: 20, color: colors.primary);
      fallbackEnd = grid
          ? Padding(padding: const EdgeInsets.all(6), child: icon)
          : icon;
    } else if (entry.isSymbolicLink) {
      final icon = Icon(Icons.link, size: 16, color: colors.outline);
      fallbackEnd = grid
          ? Padding(padding: const EdgeInsets.all(6), child: icon)
          : icon;
    } else {
      fallbackEnd = null;
    }
    final end = trailing ?? fallbackEnd;

    Widget content;
    if (list) {
      final leadingCompensation = (leadingGap - trailingGap).clamp(0.0, 16.0);
      final minLeadingWidth = 40.0 + leadingCompensation;
      final effectiveLeading = leadingCompensation > 0
          ? Padding(
              padding: EdgeInsetsDirectional.only(end: leadingCompensation),
              child: visual,
            )
          : visual;

      content = GestureDetector(
        onDoubleTap: onDoubleTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          dense: true,
          horizontalTitleGap: trailingGap,
          minLeadingWidth: minLeadingWidth,
          isThreeLine: isThreeLine,
          leading: effectiveLeading,
          title: titleSuffix == null
              ? Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: titleColor),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: titleColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    titleSuffix!,
                  ],
                ),
          subtitle: meta,
          trailing: end,
          selected: selected,
          selectedTileColor: colors.primaryContainer.withValues(alpha: 0.25),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      );
    } else {
      final gallery = viewMode == RemoteBrowserViewMode.gallery;
      final image = previewBytes == null
          ? visual
          : Image.memory(
              previewBytes!,
              fit: BoxFit.cover,
              cacheWidth: gallery ? 512 : 128,
              cacheHeight: gallery ? 512 : 128,
              errorBuilder: (_, _, _) => visual,
            );
      final dateStr =
          date ??
          (entry.modifiedEpoch != null && entry.modifiedEpoch! > 0
              ? _formatEpoch(entry.modifiedEpoch!)
              : null);

      content = ValhallaCard(
        margin: EdgeInsets.zero,
        highlight: selected,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          child: gallery
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: image,
                              ),
                            ),
                            if (end != null)
                              Positioned(top: 0, right: 0, child: end),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      meta,
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: 22–24dp icon + filename SAME ROW
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: end != null ? 38 : 24,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: visual,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Semantics(
                                    label: entry.name,
                                    child: Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                    ),
                                  ),
                                ),
                                if (end != null) const SizedBox(width: 44),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Compact metadata (directory / size)
                          meta,
                          // Full modification date/time on its own line
                          if (dateStr != null && dateStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: colors.outline.withValues(
                                  alpha: hidden ? 0.62 : 1,
                                ),
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (end != null)
                      PositionedDirectional(top: 0, end: 0, child: end),
                  ],
                ),
        ),
      );
    }
    return content;
  }

  static String _formatEpoch(int epoch) {
    if (epoch <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epoch > 100000000000 ? epoch : epoch * 1000,
    );
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class RemoteBrowserView extends StatefulWidget {
  final RemoteBrowserSource source;
  final RemoteBrowserMode mode;
  final String? initialPath;
  final Set<String> initialSelectedIds;
  final ValueChanged<String>? onPathChanged;
  final ValueChanged<List<RemoteBrowserEntry>>? onSelectionChanged;
  final void Function(RemoteBrowserEntry entry)? onEntryDoubleTap;
  final bool showHeader;
  final Widget? trailingActions;
  final bool Function(RemoteBrowserEntry entry)? canSelectEntry;
  final bool Function(String path)? isPathRestricted;
  final int? maxSelectCount;
  final ValueChanged<bool>? onStatusChanged;
  final Set<String> allowedExtensions;

  const RemoteBrowserView({
    super.key,
    required this.source,
    this.mode = RemoteBrowserMode.directory,
    this.initialPath,
    this.initialSelectedIds = const {},
    this.onPathChanged,
    this.onSelectionChanged,
    this.onEntryDoubleTap,
    this.showHeader = true,
    this.trailingActions,
    this.canSelectEntry,
    this.isPathRestricted,
    this.maxSelectCount,
    this.onStatusChanged,
    this.allowedExtensions = const {},
  });

  @override
  State<RemoteBrowserView> createState() => RemoteBrowserViewState();
}

class RemoteBrowserViewState extends State<RemoteBrowserView> {
  late String _currentPath;
  List<RemoteBrowserEntry> _entries = [];
  final Map<String, RemoteBrowserEntry> _selectedEntries = {};
  late Set<String> _pendingInitialIds;
  final Set<String> _deselectedIds = {};
  bool _isLoading = false;
  String? _errorMessage;
  int _epoch = 0;
  StreamSubscription<List<RemoteBrowserEntry>>? _streamSub;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showHidden = false;
  RemoteBrowserSortField _sortField = RemoteBrowserSortField.name;
  bool _sortAscending = true;
  RemoteBrowserViewMode _viewMode = RemoteBrowserViewMode.list;
  String _fileFormat = 'all';

  final Map<String, Uint8List> _previewCache = {};
  int _previewBytes = 0;
  final Set<String> _loadingPreviews = {};
  final Set<String> _failedPreviews = {};
  final List<RemoteBrowserEntry> _previewQueue = [];
  int _activePreviewCount = 0;
  int _previewSourceGeneration = 0;

  final ScrollController _scrollController = ScrollController();

  String get currentPath => _currentPath;
  bool get isReady =>
      !_isLoading && _errorMessage == null && widget.source.isCurrent;
  List<RemoteBrowserEntry> get selectedEntries =>
      _selectedEntries.values.toList();
  bool canSelectEntry(RemoteBrowserEntry entry) => _canSelectEntry(entry);

  @override
  void initState() {
    super.initState();
    _pendingInitialIds = Set.of(widget.initialSelectedIds);
    _currentPath = widget.initialPath != null && widget.initialPath!.isNotEmpty
        ? widget.initialPath!
        : widget.source.initialPath;
    _loadDirectory(_currentPath, isInitial: true);
  }

  @override
  void didUpdateWidget(covariant RemoteBrowserView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _previewSourceGeneration++;
      _epoch++;
      final oldSub = _streamSub;
      _streamSub = null;
      oldSub?.cancel();
      _previewCache.clear();
      _previewBytes = 0;
      _loadingPreviews.clear();
      _failedPreviews.clear();
      _previewQueue.clear();
      _activePreviewCount = 0;
      _entries = [];
      _isLoading = true;
      _errorMessage = null;
      _currentPath = widget.initialPath ?? widget.source.initialPath;
      _selectedEntries.clear();
      _pendingInitialIds = Set.of(widget.initialSelectedIds);
      _deselectedIds.clear();
      _loadDirectory(_currentPath, isInitial: true);
      final source = widget.source;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && source == widget.source) {
          widget.onSelectionChanged?.call(const []);
        }
      });
    }
  }

  @override
  void dispose() {
    _epoch++;
    final oldSub = _streamSub;
    _streamSub = null;
    oldSub?.cancel();
    _previewQueue.clear();
    _loadingPreviews.clear();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    await _loadDirectory(_currentPath, isInitial: false);
  }

  Future<void> _loadDirectory(String path, {bool isInitial = false}) async {
    final requestEpoch = ++_epoch;
    final requestSource = widget.source;
    final oldSub = _streamSub;
    _streamSub = null;
    await oldSub?.cancel();
    if (!mounted || requestEpoch != _epoch || requestSource != widget.source) {
      return;
    }
    if (!requestSource.isCurrent) {
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.remoteBrowserTargetChanged;
      });
      widget.onStatusChanged?.call(false);
      return;
    }

    _previewQueue.clear();
    _loadingPreviews.clear();
    _failedPreviews.clear();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _entries = [];
    });
    widget.onStatusChanged?.call(false);

    try {
      requestSource.ensureCurrent();
      final normalized = requestSource.normalizeLocation(path);
      _currentPath = normalized;
      widget.onPathChanged?.call(normalized);

      final stream = requestSource.list(normalized);
      _streamSub = stream.listen(
        (batch) {
          if (!mounted ||
              requestEpoch != _epoch ||
              requestSource != widget.source) {
            return;
          }
          setState(() {
            _entries.addAll(batch);
            if (_pendingInitialIds.isNotEmpty) {
              bool selectionChanged = false;
              for (final entry in batch) {
                if (_pendingInitialIds.contains(entry.id) &&
                    !_deselectedIds.contains(entry.id)) {
                  if (_canSelectEntry(entry)) {
                    _selectedEntries[entry.id] = entry;
                    _pendingInitialIds.remove(entry.id);
                    selectionChanged = true;
                  }
                }
              }
              if (selectionChanged) {
                widget.onSelectionChanged?.call(
                  _selectedEntries.values.toList(),
                );
              }
            }
          });
        },
        onError: (err) {
          if (!mounted ||
              requestEpoch != _epoch ||
              requestSource != widget.source) {
            return;
          }
          if (requestSource.isCurrent &&
              isInitial &&
              remoteBrowserDirectoryMissing(err)) {
            final parent = requestSource.parentOf(path);
            if (parent != null && parent != path) {
              _loadDirectory(parent, isInitial: true);
              return;
            }
          }
          setState(() {
            _isLoading = false;
            _errorMessage = _resolveErrorMessage(context, err);
          });
          widget.onStatusChanged?.call(false);
        },
        onDone: () {
          if (!mounted ||
              requestEpoch != _epoch ||
              requestSource != widget.source) {
            return;
          }
          setState(() {
            _isLoading = false;
            if (!requestSource.isCurrent) {
              _errorMessage = context.l10n.remoteBrowserTargetChanged;
            }
          });
          widget.onStatusChanged?.call(_errorMessage == null);
        },
        cancelOnError: true,
      );
    } catch (err) {
      if (!mounted ||
          requestEpoch != _epoch ||
          requestSource != widget.source) {
        return;
      }
      if (requestSource.isCurrent &&
          isInitial &&
          remoteBrowserDirectoryMissing(err)) {
        final parent = requestSource.parentOf(path);
        if (parent != null && parent != path) {
          _loadDirectory(parent, isInitial: true);
          return;
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _resolveErrorMessage(context, err);
      });
      widget.onStatusChanged?.call(false);
    }
  }

  void _navigateTo(String targetPath) {
    if (!widget.source.isCurrent) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _searchCtrl.clear();
    _searchQuery = '';
    setState(() => _isLoading = true);
    widget.onStatusChanged?.call(false);
    _loadDirectory(targetPath, isInitial: false);
  }

  void _navigateUp() {
    if (widget.source.flat) return;
    final parent = widget.source.parentOf(_currentPath);
    if (parent != null) {
      _navigateTo(parent);
    }
  }

  bool _canSelectEntry(RemoteBrowserEntry entry) {
    if (!entry.selectable) return false;
    if (!entry.isDirectory && !_matchesFileFormat(entry)) return false;
    if (widget.canSelectEntry != null && !widget.canSelectEntry!(entry)) {
      return false;
    }
    if (widget.isPathRestricted != null && widget.isPathRestricted!(entry.id)) {
      return false;
    }
    switch (widget.mode) {
      case RemoteBrowserMode.directory:
        return entry.isDirectory;
      case RemoteBrowserMode.file:
      case RemoteBrowserMode.multipleFiles:
        return !entry.isDirectory;
      case RemoteBrowserMode.mediaLibrary:
      case RemoteBrowserMode.multipleLibraries:
        return true;
    }
  }

  void _handleEntryTap(RemoteBrowserEntry entry) {
    if (entry.canEnter && !widget.source.flat) {
      _navigateTo(entry.id);
      return;
    }

    if (!_canSelectEntry(entry)) return;

    setState(() {
      switch (widget.mode) {
        case RemoteBrowserMode.directory:
          if (!entry.isDirectory) return;
          if (_selectedEntries.containsKey(entry.id)) {
            _selectedEntries.remove(entry.id);
            _deselectedIds.add(entry.id);
          } else {
            _selectedEntries.clear();
            _selectedEntries[entry.id] = entry;
            _deselectedIds.remove(entry.id);
          }
          break;
        case RemoteBrowserMode.file:
          if (entry.isDirectory) return;
          if (_selectedEntries.containsKey(entry.id)) {
            _selectedEntries.remove(entry.id);
            _deselectedIds.add(entry.id);
          } else {
            _selectedEntries.clear();
            _selectedEntries[entry.id] = entry;
            _deselectedIds.remove(entry.id);
          }
          break;
        case RemoteBrowserMode.multipleFiles:
          if (entry.isDirectory) return;
          if (_selectedEntries.containsKey(entry.id)) {
            _selectedEntries.remove(entry.id);
            _deselectedIds.add(entry.id);
          } else {
            if (widget.maxSelectCount != null &&
                _selectedEntries.length >= widget.maxSelectCount!) {
              return;
            }
            _selectedEntries[entry.id] = entry;
            _deselectedIds.remove(entry.id);
          }
          break;
        case RemoteBrowserMode.mediaLibrary:
          if (_selectedEntries.containsKey(entry.id)) {
            _selectedEntries.remove(entry.id);
            _deselectedIds.add(entry.id);
          } else {
            _selectedEntries.clear();
            _selectedEntries[entry.id] = entry;
            _deselectedIds.remove(entry.id);
          }
          break;
        case RemoteBrowserMode.multipleLibraries:
          if (entry.id == '/') {
            _selectedEntries.clear();
            _selectedEntries['/'] = entry;
            _deselectedIds.clear();
          } else {
            _selectedEntries.remove('/');
            if (_selectedEntries.containsKey(entry.id)) {
              _selectedEntries.remove(entry.id);
              _deselectedIds.add(entry.id);
            } else {
              _selectedEntries[entry.id] = entry;
              _deselectedIds.remove(entry.id);
            }
          }
          break;
      }
      widget.onSelectionChanged?.call(_selectedEntries.values.toList());
    });
  }

  String _previewKey(RemoteBrowserEntry entry) =>
      '${widget.source.targetKey}:${entry.id}';

  void _fetchPreview(RemoteBrowserEntry entry) {
    if (!widget.source.isCurrent || !widget.source.supportsPreview) return;
    final key = _previewKey(entry);
    if (_previewCache.containsKey(key) ||
        _loadingPreviews.contains(key) ||
        _failedPreviews.contains(key)) {
      return;
    }
    if (!entry.selectable ||
        entry.isDirectory ||
        !(entry.mimeType?.startsWith('image/') ?? false)) {
      return;
    }

    if (_activePreviewCount >= 2) {
      if (!_previewQueue.any((e) => e.id == entry.id)) {
        _previewQueue.add(entry);
      }
      return;
    }

    _activePreviewCount++;
    _loadingPreviews.add(key);
    final requestEpoch = _epoch;
    final requestSource = widget.source;
    final previewSourceGeneration = _previewSourceGeneration;

    requestSource
        .preview(entry, maxBytes: 2 * 1024 * 1024)
        .then((bytes) {
          if (!mounted) return;
          if (requestSource != widget.source ||
              previewSourceGeneration != _previewSourceGeneration) {
            return;
          }
          _activePreviewCount--;
          if (requestEpoch != _epoch) {
            _processNextPreview();
            return;
          }
          _loadingPreviews.remove(key);

          if (bytes != null && bytes.isNotEmpty) {
            _previewBytes += bytes.length;
            _previewCache[key] = bytes;

            while (_previewCache.length > 24 ||
                _previewBytes > 8 * 1024 * 1024) {
              final oldestKey = _previewCache.keys.first;
              final oldestBytes = _previewCache.remove(oldestKey);
              if (oldestBytes != null) {
                _previewBytes -= oldestBytes.length;
              }
            }
            setState(() {});
          } else {
            _failedPreviews.add(key);
          }
          _processNextPreview();
        })
        .catchError((_) {
          if (!mounted) return;
          if (requestSource != widget.source ||
              previewSourceGeneration != _previewSourceGeneration) {
            return;
          }
          _activePreviewCount--;
          if (requestEpoch != _epoch) {
            _processNextPreview();
            return;
          }
          _loadingPreviews.remove(key);
          _failedPreviews.add(key);
          _processNextPreview();
        });
  }

  void _processNextPreview() {
    if (!mounted) return;
    while (_previewQueue.isNotEmpty && _activePreviewCount < 2) {
      final next = _previewQueue.removeAt(0);
      _fetchPreview(next);
    }
  }

  List<RemoteBrowserEntry> _getFilteredAndSortedEntries() {
    var items = _entries.where((e) {
      if (widget.mode == RemoteBrowserMode.directory && !e.isDirectory) {
        return false;
      }
      if (_isFileMode && !e.isDirectory && !_canSelectEntry(e)) return false;
      if (!_showHidden && e.isHidden) return false;
      if (_searchQuery.isNotEmpty &&
          !e.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    items.sort((a, b) {
      if (!widget.source.flat && a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      int cmp = 0;
      switch (_sortField) {
        case RemoteBrowserSortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case RemoteBrowserSortField.size:
          cmp = (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
          break;
        case RemoteBrowserSortField.date:
          cmp = (a.modifiedEpoch ?? 0).compareTo(b.modifiedEpoch ?? 0);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return items;
  }

  String _resolveErrorMessage(BuildContext context, Object error) {
    final msg = error.toString();
    if (msg.contains('REMOTE_BROWSER_DISCONNECTED')) {
      return context.l10n.remoteBrowserDisconnected;
    }
    if (msg.contains('REMOTE_BROWSER_TARGET_CHANGED') ||
        msg.contains('NAS_SOURCE_CHANGED')) {
      return context.l10n.remoteBrowserTargetChanged;
    }
    if (msg.contains('REMOTE_BROWSER_PATH_INVALID')) {
      return context.l10n.remoteBrowserPathInvalid;
    }
    if (msg.contains('REMOTE_BROWSER_PATH_OUTSIDE_ROOT')) {
      return context.l10n.remoteBrowserPathOutsideRoot;
    }
    if (msg.contains('NAS_BROWSE_UNAVAILABLE')) {
      return context.l10n.nasBrowseUnavailable;
    }
    if (msg.contains('NAS_INVALID_DIRECTORY_ENTRY')) {
      return context.l10n.nasInvalidDirectoryEntry;
    }
    if (msg.contains('NAS_INVALID_LIBRARY_RESPONSE')) {
      return context.l10n.nasInvalidLibraryResponse;
    }
    if (msg.contains('NAS_SCAN_FILTER_UNRESOLVED')) {
      return context.l10n.nasScanFilterUnresolved;
    }
    if (msg.contains('NAS_SOURCE_SAVE_INCOMPLETE')) {
      return context.l10n.nasSourceSaveIncomplete;
    }
    if (msg.contains('REMOTE_BROWSER_ENTRY_UNAVAILABLE')) {
      return context.l10n.remoteBrowserEntryUnavailable;
    }
    return context.l10n.stateError;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final displayedEntries = _getFilteredAndSortedEntries();

    return Column(
      children: [
        if (widget.showHeader) ...[
          _buildNavigationHeader(theme, l10n),
          _buildSearchAndToolbar(theme, l10n),
        ],
        if (_errorMessage != null && _entries.isNotEmpty)
          Material(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(_errorMessage!),
              trailing: TextButton(
                onPressed: reload,
                child: Text(l10n.stateRetry),
              ),
            ),
          ),
        if (_isLoading && _entries.isNotEmpty) const LinearProgressIndicator(),
        Expanded(
          child: _isLoading && _entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(l10n.stateRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : displayedEntries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? l10n.remoteBrowserNoEntries
                              : l10n.remoteBrowserEmptyDirectory,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              : RemoteBrowserEntriesView(
                  entries: displayedEntries,
                  viewMode: _viewMode,
                  controller: _scrollController,
                  locationKey:
                      '${widget.source.targetKey}:$_currentPath:$_searchQuery:$_sortField:$_sortAscending:$_showHidden:$_fileFormat',
                  itemBuilder: (context, entry) {
                    if (_viewMode == RemoteBrowserViewMode.gallery) {
                      _fetchPreview(entry);
                    }
                    return RemoteBrowserEntryTile(
                      key: ValueKey(entry.id),
                      entry: entry,
                      viewMode: _viewMode,
                      flat: widget.source.flat,
                      selected: _selectedEntries.containsKey(entry.id),
                      previewBytes: _previewCache[_previewKey(entry)],
                      onTap: () => _handleEntryTap(entry),
                      onDoubleTap:
                          entry.isDirectory ||
                              !_canSelectEntry(entry) ||
                              widget.onEntryDoubleTap == null
                          ? null
                          : () {
                              if (!_selectedEntries.containsKey(entry.id)) {
                                _handleEntryTap(entry);
                              }
                              widget.onEntryDoubleTap!(entry);
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNavigationHeader(ThemeData theme, dynamic l10n) {
    if (widget.source.flat) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.source.label,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.stateRetry,
              onPressed: reload,
            ),
          ],
        ),
      );
    }
    return RemoteBrowserBreadcrumb(
      path: _currentPath,
      rootPath: widget.source.rootPath,
      onNavigate: _navigateTo,
      onUp: widget.source.parentOf(_currentPath) == null ? null : _navigateUp,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: context.l10n.stateRetry,
            onPressed: reload,
          ),
          if (widget.trailingActions != null) widget.trailingActions!,
        ],
      ),
    );
  }

  Widget _buildSearchAndToolbar(ThemeData theme, dynamic l10n) =>
      RemoteBrowserToolbar(
        searchController: _searchCtrl,
        searchHint: context.l10n.remoteBrowserSearchHint,
        isPicker: true,
        onSearchChanged: (value) =>
            setState(() => _searchQuery = value.trim().toLowerCase()),
        showHidden: _showHidden,
        onToggleHidden: () => setState(() => _showHidden = !_showHidden),
        sortField: _sortField.name,
        sortAscending: _sortAscending,
        onSort: (field, ascending) => setState(() {
          _sortField = RemoteBrowserSortField.values.byName(field);
          _sortAscending = ascending;
        }),
        isGrid: _viewMode != RemoteBrowserViewMode.list,
        onToggleView: () => setState(() {
          _viewMode = _viewMode == RemoteBrowserViewMode.list
              ? RemoteBrowserViewMode.grid
              : RemoteBrowserViewMode.list;
        }),
        trailingActions: [
          if (_isFileMode) _buildFileFormatFilter(),
          IconButton(
            key: const Key('remote_browser_gallery'),
            icon: const Icon(Icons.image),
            tooltip: context.l10n.chatViewModeGrid,
            isSelected: _viewMode == RemoteBrowserViewMode.gallery,
            onPressed: () =>
                setState(() => _viewMode = RemoteBrowserViewMode.gallery),
          ),
        ],
      );

  bool get _isFileMode =>
      widget.mode == RemoteBrowserMode.file ||
      widget.mode == RemoteBrowserMode.multipleFiles;

  String _fileCategory(RemoteBrowserEntry entry) {
    final mime = entry.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('text/') || FilePreview.isTextPreviewable(entry.name)) {
      return 'document';
    }
    return switch (NasMediaKind.fromPath(entry.name)) {
      NasMediaKind.image => 'image',
      NasMediaKind.video => 'video',
      NasMediaKind.audio => 'audio',
      null =>
        const {
              'pdf',
              'doc',
              'docx',
              'xls',
              'xlsx',
              'ppt',
              'pptx',
              'odt',
              'ods',
              'rtf',
            }.contains(entry.name.toLowerCase().split('.').last)
            ? 'document'
            : 'all',
    };
  }

  bool _matchesFileFormat(RemoteBrowserEntry entry) {
    final name = entry.name.toLowerCase();
    if (widget.allowedExtensions.isNotEmpty &&
        !widget.allowedExtensions.any(
          (extension) => name.endsWith(
            '.${extension.toLowerCase().replaceFirst(RegExp(r'^\*?\.'), '')}',
          ),
        )) {
      return false;
    }
    return _fileFormat == 'all' ||
        (_fileFormat.startsWith('extension:')
            ? name.endsWith('.${_fileFormat.substring(10)}')
            : _fileCategory(entry) == _fileFormat);
  }

  Widget _buildFileFormatFilter() {
    final l10n = context.l10n;
    final labels = <String, String>{
      'all': l10n.remoteBrowserAllFileTypes,
      'image': l10n.nasFilterImages,
      'video': l10n.nasFilterVideos,
      'audio': l10n.nasStatMusic,
      'document': l10n.remoteBrowserDocuments,
    };
    final extensions = <String>{};
    for (final entry in _entries) {
      if (entry.isDirectory || !(widget.canSelectEntry?.call(entry) ?? true)) {
        continue;
      }
      final dot = entry.name.lastIndexOf('.');
      if (dot <= 0) continue;
      final extension = entry.name.substring(dot + 1).toLowerCase();
      if (RegExp(r'^[a-z0-9]{1,12}$').hasMatch(extension)) {
        extensions.add(extension);
      }
    }
    for (final extension in (extensions.toList()..sort()).take(32)) {
      labels['extension:$extension'] = '.$extension';
    }
    return PopupMenuButton<String>(
      key: const Key('remote_browser_file_format'),
      tooltip:
          '${l10n.remoteBrowserFileFormat}: ${labels[_fileFormat] ?? _fileFormat}',
      initialValue: _fileFormat,
      icon: Icon(
        Icons.filter_list,
        color: _fileFormat == 'all'
            ? null
            : Theme.of(context).colorScheme.primary,
      ),
      onSelected: (value) {
        setState(() {
          _fileFormat = value;
          _selectedEntries.clear();
          _pendingInitialIds.clear();
        });
        widget.onSelectionChanged?.call(const []);
      },
      itemBuilder: (_) => [
        for (final item in labels.entries)
          CheckedPopupMenuItem(
            value: item.key,
            checked: item.key == _fileFormat,
            child: Text(item.value),
          ),
      ],
    );
  }
}
