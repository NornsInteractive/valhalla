import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';
import '../../../infrastructure/nas/nas_media_proxy_service.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import 'nas_cast_sheet.dart';
import 'nas_localizations.dart';
import 'nas_thumbnail_image.dart';

class NasImageViewerDialog extends ConsumerStatefulWidget {
  final NasMediaItem item;
  final List<NasMediaItem> items;
  final int initialIndex;
  final Future<String?>? thumbnailFuture;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onOpenExternal;
  final String? localFilePath;
  final ValueChanged<NasMediaItem>? onCurrentItemChanged;

  const NasImageViewerDialog({
    super.key,
    required this.item,
    this.items = const [],
    this.initialIndex = 0,
    this.thumbnailFuture,
    this.isFavorite = false,
    this.onToggleFavorite,
    required this.onOpenExternal,
    this.localFilePath,
    this.onCurrentItemChanged,
  });

  static Future<NasMediaItem?> show(
    BuildContext context, {
    required NasMediaItem item,
    List<NasMediaItem> items = const [],
    int initialIndex = 0,
    Future<String?>? thumbnailFuture,
    bool isFavorite = false,
    VoidCallback? onToggleFavorite,
    required VoidCallback onOpenExternal,
    String? localFilePath,
    ValueChanged<NasMediaItem>? onCurrentItemChanged,
  }) {
    return showDialog<NasMediaItem?>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => NasImageViewerDialog(
        item: item,
        items: items.isEmpty ? [item] : items,
        initialIndex: items.isEmpty ? 0 : initialIndex,
        thumbnailFuture: thumbnailFuture,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
        onOpenExternal: onOpenExternal,
        localFilePath: localFilePath,
        onCurrentItemChanged: onCurrentItemChanged,
      ),
    );
  }

  @override
  ConsumerState<NasImageViewerDialog> createState() =>
      _NasImageViewerDialogState();
}

class _NasImageViewerDialogState extends ConsumerState<NasImageViewerDialog> {
  late int _currentIndex;
  late List<NasMediaItem> _items;
  Uri? _currentRelayUri;
  bool _loadingOriginal = false;
  String? _originalError;
  bool _isSlideshow = false;
  Timer? _slideshowTimer;
  NasMediaProxyService? _capturedProxyService;
  int _loadGeneration = 0;
  bool _favoriteInProgress = false;
  bool _loadingMore = false;
  String? _pagingError;

  bool _sessionInvalidated = false;
  NasSource? _capturedSource;
  String? _capturedServerId;
  String? _capturedCategory;
  NasMediaKind? _capturedFilter;
  bool _capturedFavoritesOnly = false;
  String? _capturedSearch;
  NasSortKey _capturedSortKey = NasSortKey.modified;
  bool _capturedSortAscending = false;
  String? _capturedFolder;
  String? _capturedArtist;
  String? _capturedAlbum;
  String? _capturedAlbumKey;
  String? _capturedPlaylistId;
  int? _capturedModifiedFrom;
  int? _capturedModifiedBefore;
  bool _capturedGallery = false;

  NasMediaItem get _currentItem =>
      _currentIndex >= 0 && _currentIndex < _items.length
      ? _items[_currentIndex]
      : widget.item;

  @override
  void initState() {
    super.initState();
    _items = widget.items.isEmpty ? [widget.item] : widget.items;
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);

    if (widget.localFilePath == null) {
      _capturedSource = ref.read(nasSourcesProvider).selected;
      final nasState = ref.read(nasProvider);
      _capturedServerId = nasState.serverId;
      _capturedCategory = nasState.browseCategory;
      _capturedFilter = nasState.filter;
      _capturedFavoritesOnly = nasState.favoritesOnly;
      _capturedSearch = nasState.search;
      _capturedSortKey = nasState.sortKey;
      _capturedSortAscending = nasState.sortAscending;
      _capturedFolder = nasState.folder;
      _capturedArtist = nasState.artist;
      _capturedAlbum = nasState.album;
      _capturedAlbumKey = nasState.albumKey;
      _capturedPlaylistId = nasState.playlistId;
      _capturedModifiedFrom = nasState.modifiedFromEpoch;
      _capturedModifiedBefore = nasState.modifiedBeforeEpoch;
      _capturedGallery = nasState.galleryWindowEnabled;
    }

    _loadOriginal();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _slideshowTimer?.cancel();
    _releaseCurrentUri();
    _capturedProxyService = null;
    super.dispose();
  }

  void _invalidateSession() {
    if (_sessionInvalidated) return;
    _sessionInvalidated = true;
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    if (mounted) {
      setState(() {
        _isSlideshow = false;
      });
    }
  }

  bool _isIdentityMatches(NasState s) {
    return s.serverId == _capturedServerId &&
        s.browseCategory == _capturedCategory &&
        s.filter == _capturedFilter &&
        s.favoritesOnly == _capturedFavoritesOnly &&
        s.search == _capturedSearch &&
        s.sortKey == _capturedSortKey &&
        s.sortAscending == _capturedSortAscending &&
        s.folder == _capturedFolder &&
        s.artist == _capturedArtist &&
        s.album == _capturedAlbum &&
        s.albumKey == _capturedAlbumKey &&
        s.playlistId == _capturedPlaylistId &&
        s.modifiedFromEpoch == _capturedModifiedFrom &&
        s.modifiedBeforeEpoch == _capturedModifiedBefore &&
        s.galleryWindowEnabled == _capturedGallery;
  }

  bool _isSessionValid() {
    if (_sessionInvalidated) return false;
    if (widget.localFilePath != null) return true;
    final currentSource = ref.read(nasSourcesProvider).selected;
    if (currentSource != _capturedSource) {
      _invalidateSession();
      return false;
    }
    final s = ref.read(nasProvider);
    if (!_isIdentityMatches(s)) {
      _invalidateSession();
      return false;
    }
    return true;
  }

  void _releaseCurrentUri() {
    if (_currentRelayUri != null) {
      try {
        _capturedProxyService?.revoke(_currentRelayUri!);
      } catch (_) {}
      _currentRelayUri = null;
    }
  }

  Future<void> _loadOriginal() async {
    final gen = ++_loadGeneration;
    _releaseCurrentUri();
    if (widget.localFilePath != null) {
      final exists = File(widget.localFilePath!).existsSync();
      setState(() {
        _loadingOriginal = false;
        _originalError = exists ? null : 'NAS_OFFLINE_FILE_INVALID';
      });
      return;
    }

    if (!_isSessionValid()) return;

    setState(() {
      _loadingOriginal = true;
      _originalError = null;
    });

    try {
      if (!mounted || !_isSessionValid()) return;
      final notifier = ref.read(nasProvider.notifier);
      final proxyService = ref.read(nasMediaProxyServiceProvider);
      _capturedProxyService = proxyService;
      final uri = await notifier.imageUrl(_currentItem);
      if (!mounted || gen != _loadGeneration || !_isSessionValid()) {
        proxyService.revoke(uri);
        return;
      }
      setState(() {
        _currentRelayUri = uri;
        _loadingOriginal = false;
      });
    } catch (e) {
      if (mounted && gen == _loadGeneration && _isSessionValid()) {
        setState(() {
          _loadingOriginal = false;
          _originalError = e.toString();
        });
      }
    }
  }

  void _goTo(int index) {
    if (widget.localFilePath != null) return;
    if (index < 0 || index >= _items.length || index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _pagingError = null;
    });
    widget.onCurrentItemChanged?.call(_currentItem);
    _loadOriginal();
  }

  Future<void> _next() async {
    if (widget.localFilePath != null) return;
    if (!_isSessionValid()) return;

    if (_currentIndex + 1 < _items.length) {
      _goTo(_currentIndex + 1);
      return;
    }

    final nasState = ref.read(nasProvider);
    final isGallery = nasState.galleryWindowEnabled;
    if (_items.isEmpty) return;
    final oldItem = _items[_currentIndex];
    final oldServerId = oldItem.serverId;
    final oldPath = oldItem.path;

    if (nasState.hasMore && !_loadingMore) {
      _loadingMore = true;
      try {
        await ref.read(nasProvider.notifier).loadMore();
        if (!mounted || !_isSessionValid()) {
          return;
        }
        final postState = ref.read(nasProvider);
        if (postState.errorCode != null) {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
            _pagingError = 'next';
          });
          return;
        }

        final newImages = postState.items
            .where((i) => i.kind == NasMediaKind.image)
            .toList();
        if (newImages.isNotEmpty) {
          if (isGallery) {
            final foundIndex = newImages.indexWhere(
              (i) => i.serverId == oldServerId && i.path == oldPath,
            );
            if (foundIndex >= 0) {
              if (foundIndex + 1 < newImages.length) {
                setState(() {
                  _items = newImages;
                  _currentIndex = foundIndex + 1;
                  _pagingError = null;
                });
                widget.onCurrentItemChanged?.call(_currentItem);
                _loadOriginal();
                return;
              } else {
                setState(() {
                  _items = newImages;
                  _currentIndex = foundIndex;
                  _pagingError = null;
                });
                return;
              }
            } else {
              _slideshowTimer?.cancel();
              _slideshowTimer = null;
              setState(() {
                _isSlideshow = false;
              });
              return;
            }
          } else {
            final foundIndex = newImages.indexWhere(
              (i) => i.serverId == oldServerId && i.path == oldPath,
            );
            final nextIndex = foundIndex >= 0
                ? (foundIndex + 1 < newImages.length
                      ? foundIndex + 1
                      : foundIndex)
                : 0;
            setState(() {
              _items = newImages;
              _currentIndex = nextIndex;
              _pagingError = null;
            });
            widget.onCurrentItemChanged?.call(_currentItem);
            _loadOriginal();
            return;
          }
        } else {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
          });
          return;
        }
      } catch (_) {
        if (mounted && _isSessionValid()) {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
            _pagingError = 'next';
          });
        }
      } finally {
        if (mounted) {
          _loadingMore = false;
        }
      }
    }

    if (_isSlideshow) {
      if (!isGallery) {
        _goTo(0);
      } else {
        _slideshowTimer?.cancel();
        _slideshowTimer = null;
        setState(() {
          _isSlideshow = false;
        });
      }
    }
  }

  Future<void> _previous() async {
    if (widget.localFilePath != null) return;
    if (!_isSessionValid()) return;

    if (_currentIndex > 0) {
      _goTo(_currentIndex - 1);
      return;
    }

    final nasState = ref.read(nasProvider);
    final isGallery = nasState.galleryWindowEnabled;
    if (_items.isEmpty) return;
    final oldItem = _items[_currentIndex];
    final oldServerId = oldItem.serverId;
    final oldPath = oldItem.path;

    if (nasState.hasPrevious && !_loadingMore) {
      _loadingMore = true;
      try {
        await ref.read(nasProvider.notifier).loadPrevious();
        if (!mounted || !_isSessionValid()) {
          return;
        }
        final postState = ref.read(nasProvider);
        if (postState.errorCode != null) {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
            _pagingError = 'prev';
          });
          return;
        }

        final prevImages = postState.items
            .where((i) => i.kind == NasMediaKind.image)
            .toList();
        if (prevImages.isNotEmpty) {
          if (isGallery) {
            final foundIndex = prevImages.indexWhere(
              (i) => i.serverId == oldServerId && i.path == oldPath,
            );
            if (foundIndex >= 0) {
              if (foundIndex - 1 >= 0) {
                setState(() {
                  _items = prevImages;
                  _currentIndex = foundIndex - 1;
                  _pagingError = null;
                });
                widget.onCurrentItemChanged?.call(_currentItem);
                _loadOriginal();
                return;
              } else {
                setState(() {
                  _items = prevImages;
                  _currentIndex = foundIndex;
                  _pagingError = null;
                });
                return;
              }
            } else {
              _slideshowTimer?.cancel();
              _slideshowTimer = null;
              setState(() {
                _isSlideshow = false;
              });
              return;
            }
          } else {
            final foundIndex = prevImages.indexWhere(
              (i) => i.serverId == oldServerId && i.path == oldPath,
            );
            final prevIndex = foundIndex >= 0
                ? (foundIndex - 1 >= 0 ? foundIndex - 1 : 0)
                : (prevImages.length - 1);
            setState(() {
              _items = prevImages;
              _currentIndex = prevIndex;
              _pagingError = null;
            });
            widget.onCurrentItemChanged?.call(_currentItem);
            _loadOriginal();
            return;
          }
        } else {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
          });
          return;
        }
      } catch (_) {
        if (mounted && _isSessionValid()) {
          _slideshowTimer?.cancel();
          _slideshowTimer = null;
          setState(() {
            _isSlideshow = false;
            _pagingError = 'prev';
          });
        }
      } finally {
        if (mounted) {
          _loadingMore = false;
        }
      }
    }
  }

  void _toggleSlideshow() {
    if (widget.localFilePath != null) return;
    if (!_isSessionValid()) return;
    setState(() {
      _isSlideshow = !_isSlideshow;
    });
    if (_isSlideshow) {
      _slideshowTimer = Timer.periodic(
        const Duration(milliseconds: 3500),
        (_) => _next(),
      );
    } else {
      _slideshowTimer?.cancel();
      _slideshowTimer = null;
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.localFilePath != null) return;
    if (_favoriteInProgress) return;
    if (!_isSessionValid()) return;
    final target = _currentItem;
    final targetPath = target.path;
    final targetServerId = target.serverId;
    final newFav = !target.isFavorite;

    setState(() => _favoriteInProgress = true);
    try {
      await ref.read(nasProvider.notifier).setFavorite(target, newFav);
      if (!mounted || !_isSessionValid()) return;
      setState(() {
        _items = [
          for (final it in _items)
            (it.serverId == targetServerId && it.path == targetPath)
                ? it.copyWith(isFavorite: newFav)
                : it,
        ];
      });
      widget.onToggleFavorite?.call();
    } catch (e) {
      if (!mounted || !_isSessionValid()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _favoriteInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.localFilePath == null) {
      ref.listen<NasSource?>(nasSourcesProvider.select((s) => s.selected), (
        prev,
        next,
      ) {
        if (next != _capturedSource) {
          _invalidateSession();
        }
      });
      ref.listen<NasState>(nasProvider, (prev, next) {
        if (!_isIdentityMatches(next)) {
          _invalidateSession();
        }
      });
    }

    final item = _currentItem;
    final isFav = item.isFavorite;
    final isLocalMode = widget.localFilePath != null;

    return Dialog.fullscreen(
      key: const Key('nas_image_viewer'),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.black54,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: context.l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(_currentItem),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: context.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isLocalMode
                              ? (widget.localFilePath ?? '')
                              : '${_currentIndex + 1} / ${_items.length} · ${item.path}',
                          style: monoTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isLocalMode) ...[
                    IconButton(
                      key: const Key('nas_image_viewer_slideshow_button'),
                      icon: Icon(
                        _isSlideshow
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_outline,
                        // Fullscreen viewer is always dark: use the dark
                        // semantic variants for contrast on black.
                        color: _isSlideshow
                            ? VColors.warning(Brightness.dark)
                            : Colors.white,
                      ),
                      tooltip: context.nasSlideshow,
                      onPressed: _sessionInvalidated ? null : _toggleSlideshow,
                    ),
                    IconButton(
                      key: const Key('nas_image_viewer_favorite_button'),
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav
                            ? VColors.danger(Brightness.dark)
                            : Colors.white,
                      ),
                      tooltip: context.l10n.nasTabFavorites,
                      onPressed: (_favoriteInProgress || _sessionInvalidated)
                          ? null
                          : _toggleFavorite,
                    ),
                    IconButton(
                      key: const Key('nas_image_viewer_download_button'),
                      icon: const Icon(
                        Icons.download_outlined,
                        color: Colors.white,
                      ),
                      tooltip: context.nasTabDownloads,
                      onPressed: () {
                        if (!_isSessionValid()) return;
                        ref.read(nasProvider.notifier).download(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.nasDownloading(item.name)),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      key: const Key('nas_image_viewer_cast_button'),
                      icon: const Icon(Icons.cast, color: Colors.white),
                      tooltip: context.nasCast,
                      onPressed: () {
                        if (!_isSessionValid()) return;
                        NasCastSheet.show(context, item: item);
                      },
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    tooltip: context.l10n.nasOpenPolicyExternal,
                    onPressed: () {
                      if (widget.localFilePath == null && !_isSessionValid()) {
                        return;
                      }
                      widget.onOpenExternal();
                    },
                  ),
                ],
              ),
            ),

            if (_pagingError != null)
              Container(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.nasOperationFailed,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingMore
                          ? null
                          : () {
                              final retryDir = _pagingError;
                              setState(() => _pagingError = null);
                              if (retryDir == 'next') {
                                _next();
                              } else if (retryDir == 'prev') {
                                _previous();
                              }
                            },
                      child: Text(context.l10n.stateRetry),
                    ),
                  ],
                ),
              ),

            // Main Image Viewer Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: isLocalMode
                        ? _buildLocalImageViewer(context)
                        : _buildOnlineImageViewer(context, item),
                  ),

                  // Left Navigation Arrow
                  if (!isLocalMode &&
                      (_currentIndex > 0 || ref.watch(nasProvider).hasPrevious))
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          key: const Key('nas_image_prev_button'),
                          icon: const Icon(Icons.chevron_left, size: 28),
                          onPressed: _loadingMore ? null : _previous,
                        ),
                      ),
                    ),

                  // Right Navigation Arrow
                  if (!isLocalMode &&
                      (_currentIndex + 1 < _items.length ||
                          ref.watch(nasProvider).hasMore))
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          key: const Key('nas_image_next_button'),
                          icon: const Icon(Icons.chevron_right, size: 28),
                          onPressed: _loadingMore ? null : _next,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Metadata footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    SftpFileItem.formatBytes(item.sizeBytes),
                    style: monoTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  if (item.width != null && item.height != null)
                    Text(
                      '${item.width} × ${item.height}',
                      style: monoTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  Text(
                    item.modifiedEpoch > 0
                        ? DateTime.fromMillisecondsSinceEpoch(
                            item.modifiedEpoch * 1000,
                          ).toLocal().toString().substring(0, 16)
                        : '-',
                    style: monoTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildLocalImageViewer(BuildContext context) {
    final localPath = widget.localFilePath;
    if (localPath == null || !File(localPath).existsSync()) {
      return _buildOfflineError(context);
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildOfflineError(context);
        },
      ),
    );
  }

  Widget _buildOfflineError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.nasDownloadErrorOfflineFileInvalid,
              style: TextStyle(
                color: VColors.danger(Brightness.dark),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineImageViewer(BuildContext context, NasMediaItem item) {
    if (_currentRelayUri != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Image(
          image: ResizeImage(
            NetworkImage(_currentRelayUri.toString()),
            width: 4096,
            height: 4096,
            policy: ResizeImagePolicy.fit,
          ),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stack) {
            return _buildThumbnailFallback(item);
          },
        ),
      );
    }

    if (_loadingOriginal) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return _buildThumbnailFallback(item, _originalError);
  }

  Widget _buildThumbnailFallback(NasMediaItem item, [String? error]) {
    return NasThumbnailImage(
      item: item,
      fit: BoxFit.contain,
      placeholder: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.nasOperationFailed,
              style: TextStyle(
                color: VColors.danger(Brightness.dark),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadOriginal,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(context.l10n.stateRetry),
            ),
          ],
        ],
      ),
    );
  }
}
