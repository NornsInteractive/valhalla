import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import 'nas_cast_sheet.dart';
import 'nas_localizations.dart';

class NasImageViewerDialog extends ConsumerStatefulWidget {
  final NasMediaItem item;
  final List<NasMediaItem> items;
  final int initialIndex;
  final Future<String?> thumbnailFuture;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenExternal;

  const NasImageViewerDialog({
    super.key,
    required this.item,
    this.items = const [],
    this.initialIndex = 0,
    required this.thumbnailFuture,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenExternal,
  });

  static Future<void> show(
    BuildContext context, {
    required NasMediaItem item,
    List<NasMediaItem> items = const [],
    int initialIndex = 0,
    required Future<String?> thumbnailFuture,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
    required VoidCallback onOpenExternal,
  }) {
    return showDialog<void>(
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
  late NasNotifier _nasNotifier;
  int _loadGeneration = 0;
  bool _favoriteInProgress = false;

  NasMediaItem get _currentItem =>
      _currentIndex >= 0 && _currentIndex < _items.length
      ? _items[_currentIndex]
      : widget.item;

  @override
  void initState() {
    super.initState();
    _items = widget.items.isEmpty ? [widget.item] : widget.items;
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _nasNotifier = ref.read(nasProvider.notifier);
    _loadOriginal();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _slideshowTimer?.cancel();
    _releaseCurrentUri();
    super.dispose();
  }

  void _releaseCurrentUri() {
    if (_currentRelayUri != null) {
      try {
        _nasNotifier.releaseImageUrl(_currentRelayUri!);
      } catch (_) {}
      _currentRelayUri = null;
    }
  }

  Future<void> _loadOriginal() async {
    final gen = ++_loadGeneration;
    _releaseCurrentUri();
    setState(() {
      _loadingOriginal = true;
      _originalError = null;
    });

    try {
      final uri = await _nasNotifier.imageUrl(_currentItem);
      if (!mounted || gen != _loadGeneration) {
        _nasNotifier.releaseImageUrl(uri);
        return;
      }
      setState(() {
        _currentRelayUri = uri;
        _loadingOriginal = false;
      });
    } catch (e) {
      if (mounted && gen == _loadGeneration) {
        setState(() {
          _loadingOriginal = false;
          _originalError = e.toString();
        });
      }
    }
  }

  bool _loadingMore = false;

  void _goTo(int index) {
    if (index < 0 || index >= _items.length || index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _loadOriginal();
  }

  Future<void> _next() async {
    if (_currentIndex + 1 < _items.length) {
      _goTo(_currentIndex + 1);
      return;
    }

    final nasState = ref.read(nasProvider);
    if (nasState.hasMore && !_loadingMore) {
      _loadingMore = true;
      try {
        await ref.read(nasProvider.notifier).loadMore();
        if (!mounted) return;
        final newImages = ref
            .read(nasProvider)
            .items
            .where((i) => i.kind == NasMediaKind.image)
            .toList();
        if (newImages.isNotEmpty) {
          setState(() {
            _items = newImages;
            _currentIndex = 0;
          });
          _loadOriginal();
          return;
        }
      } catch (_) {
      } finally {
        if (mounted) {
          _loadingMore = false;
        }
      }
    }

    if (_isSlideshow) {
      _goTo(0);
    }
  }

  Future<void> _previous() async {
    if (_currentIndex > 0) {
      _goTo(_currentIndex - 1);
      return;
    }

    final nasState = ref.read(nasProvider);
    if (nasState.hasPrevious && !_loadingMore) {
      _loadingMore = true;
      try {
        await ref.read(nasProvider.notifier).loadPrevious();
        if (!mounted) return;
        final prevImages = ref
            .read(nasProvider)
            .items
            .where((i) => i.kind == NasMediaKind.image)
            .toList();
        if (prevImages.isNotEmpty) {
          setState(() {
            _items = prevImages;
            _currentIndex = prevImages.length - 1;
          });
          _loadOriginal();
        }
      } catch (_) {
      } finally {
        if (mounted) {
          _loadingMore = false;
        }
      }
    }
  }

  void _toggleSlideshow() {
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
    if (_favoriteInProgress) return;
    final target = _currentItem;
    final targetPath = target.path;
    final targetServerId = target.serverId;
    final newFav = !target.isFavorite;

    setState(() => _favoriteInProgress = true);
    try {
      await ref.read(nasProvider.notifier).setFavorite(target, newFav);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final it in _items)
            (it.serverId == targetServerId && it.path == targetPath)
                ? it.copyWith(isFavorite: newFav)
                : it,
        ];
      });
    } catch (e) {
      if (!mounted) return;
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
    final item = _currentItem;
    final isFav = item.isFavorite;

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
                    onPressed: () => Navigator.pop(context),
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
                          '${_currentIndex + 1} / ${_items.length} · ${item.path}',
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
                    onPressed: _toggleSlideshow,
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
                    onPressed: _favoriteInProgress ? null : _toggleFavorite,
                  ),
                  IconButton(
                    key: const Key('nas_image_viewer_download_button'),
                    icon: const Icon(
                      Icons.download_outlined,
                      color: Colors.white,
                    ),
                    tooltip: context.nasTabDownloads,
                    onPressed: () {
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
                    onPressed: () => NasCastSheet.show(context, item: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    tooltip: context.l10n.nasOpenPolicyExternal,
                    onPressed: widget.onOpenExternal,
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
                    child: _currentRelayUri != null
                        ? InteractiveViewer(
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
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stack) {
                                return _buildThumbnailFallback(item);
                              },
                            ),
                          )
                        : (_loadingOriginal
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : _buildThumbnailFallback(item, _originalError)),
                  ),

                  // Left Navigation Arrow
                  if (_currentIndex > 0 || ref.watch(nasProvider).hasPrevious)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          key: const Key('nas_image_prev_button'),
                          icon: const Icon(Icons.chevron_left, size: 28),
                          onPressed: _previous,
                        ),
                      ),
                    ),

                  // Right Navigation Arrow
                  if (_currentIndex + 1 < _items.length ||
                      ref.watch(nasProvider).hasMore)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          key: const Key('nas_image_next_button'),
                          icon: const Icon(Icons.chevron_right, size: 28),
                          onPressed: _next,
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

  Widget _buildThumbnailFallback(NasMediaItem item, [String? error]) {
    return FutureBuilder<String?>(
      future: ref.read(nasProvider.notifier).thumbnailPath(item),
      builder: (context, snapshot) {
        final localPath = snapshot.data;
        if (localPath != null && File(localPath).existsSync()) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(File(localPath), fit: BoxFit.contain),
          );
        }
        return Column(
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
                error,
                style: TextStyle(
                  color: VColors.danger(Brightness.dark),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
