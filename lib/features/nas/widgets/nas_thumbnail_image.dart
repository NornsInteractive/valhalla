import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/nas_preview_provider.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_image_cache_service.dart';
import '../../../data/models/nas_media.dart';
import 'nas_viewport_observer.dart';

class NasThumbnailImage extends ConsumerStatefulWidget {
  final NasMediaItem item;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData? fallbackIcon;

  const NasThumbnailImage({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon,
  });

  @override
  ConsumerState<NasThumbnailImage> createState() => _NasThumbnailImageState();
}

class _NasThumbnailImageState extends ConsumerState<NasThumbnailImage>
    implements NasViewportTile {
  Future<String?>? _thumbnailFuture;
  NasMediaItem? _currentItem;
  NasImageCacheService? _capturedService;
  bool _isPrefetch = false;
  bool _tickerEnabled = true;

  @override
  NasMediaItem get item => widget.item;

  @override
  bool get tickerEnabled => _tickerEnabled;

  @override
  void initState() {
    super.initState();
    // Do not load thumbnail in initState. Viewport observer and preview requests
    // provider determine when this tile is eligible for fetching.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.of(context);
    final scrollable = Scrollable.maybeOf(context);
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      try {
        container = ref.container;
      } catch (_) {}
    }
    try {
      _capturedService = ref.read(nasImageCacheProvider);
    } catch (_) {}

    if (container != null) {
      NasViewportCoordinator.instance.register(
        this,
        scrollable: scrollable,
        container: container,
        tickerEnabled: _tickerEnabled,
      );
    }
  }

  void _loadThumbnail(
    NasMediaItem item,
    NasImageCacheService service, {
    required bool prefetch,
  }) {
    _currentItem = item;
    _isPrefetch = prefetch;
    _thumbnailFuture = service.thumbnail(item, owner: this, prefetch: prefetch);
  }

  @override
  void didUpdateWidget(NasThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemChanged =
        oldWidget.item.path != widget.item.path ||
        oldWidget.item.serverId != widget.item.serverId ||
        oldWidget.item.modifiedEpoch != widget.item.modifiedEpoch ||
        oldWidget.item.sizeBytes != widget.item.sizeBytes;
    if (itemChanged) {
      if (_currentItem != null && _capturedService != null) {
        _capturedService!.releaseThumbnail(_currentItem!, this);
        _currentItem = null;
        _thumbnailFuture = null;
      }
      NasViewportCoordinator.instance.updateTile(this);
    }
  }

  @override
  void dispose() {
    NasViewportCoordinator.instance.unregister(this);
    if (_currentItem != null && _capturedService != null) {
      _capturedService!.releaseThumbnail(_currentItem!, this);
      _capturedService = null;
      _currentItem = null;
    }
    super.dispose();
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!;
    final icon =
        widget.fallbackIcon ??
        (widget.item.kind == NasMediaKind.video
            ? Icons.movie_outlined
            : (widget.item.kind == NasMediaKind.audio
                  ? Icons.music_note_outlined
                  : Icons.image_outlined));
    return Center(
      child: Icon(
        icon,
        size: widget.width != null
            ? (widget.width! * 0.35).clamp(20.0, 48.0)
            : 32.0,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = nasPreviewKey(widget.item);

    // Listen to changes for this preview key so releaseThumbnail occurs immediately
    // without waiting for a new frame (e.g. when app lifecycle changes to paused).
    ref.listen<NasPreviewRequest?>(
      nasPreviewRequestsProvider.select((m) => m[key]),
      (prev, next) {
        if (next == null) {
          if (_currentItem != null && _capturedService != null) {
            _capturedService!.releaseThumbnail(_currentItem!, this);
            _currentItem = null;
            _thumbnailFuture = null;
            _isPrefetch = false;
            if (mounted) setState(() {});
          }
        } else {
          final isPrefetch = !next.visible;
          final shouldFetch =
              _currentItem == null ||
              _currentItem!.path != widget.item.path ||
              _currentItem!.modifiedEpoch != widget.item.modifiedEpoch ||
              _currentItem!.sizeBytes != widget.item.sizeBytes ||
              (_isPrefetch && !isPrefetch) ||
              _thumbnailFuture == null;
          if (shouldFetch) {
            final NasImageCacheService service =
                _capturedService ?? ref.read<NasImageCacheService>(nasImageCacheProvider);
            _loadThumbnail(widget.item, service, prefetch: isPrefetch);
            if (mounted) setState(() {});
          }
        }
      },
    );

    final request = ref.watch(
      nasPreviewRequestsProvider.select((m) => m[key]),
    );

    final currentService = ref.watch(nasImageCacheProvider);
    if (!identical(currentService, _capturedService)) {
      if (_currentItem != null && _capturedService != null) {
        _capturedService!.releaseThumbnail(_currentItem!, this);
      }
      _capturedService = currentService;
      _currentItem = null;
      _thumbnailFuture = null;
    }

    if (request != null) {
      final isPrefetch = !request.visible;
      final shouldFetch =
          _currentItem == null ||
          _currentItem!.path != widget.item.path ||
          _currentItem!.modifiedEpoch != widget.item.modifiedEpoch ||
          _currentItem!.sizeBytes != widget.item.sizeBytes ||
          (_isPrefetch && !isPrefetch) ||
          _thumbnailFuture == null;

      if (shouldFetch) {
        _loadThumbnail(widget.item, currentService, prefetch: isPrefetch);
      }
    } else {
      if (_currentItem != null && _capturedService != null) {
        _capturedService!.releaseThumbnail(_currentItem!, this);
        _currentItem = null;
        _thumbnailFuture = null;
        _isPrefetch = false;
      }
    }

    Widget content;
    final future = _thumbnailFuture;
    if (future == null) {
      content = _buildPlaceholder(context);
    } else {
      content = FutureBuilder<String?>(
        future: future,
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && path.isNotEmpty) {
            final mediaQuery = MediaQuery.maybeOf(context);
            final pixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
            int? cacheWidth;
            int? cacheHeight;
            if (widget.width != null &&
                widget.width!.isFinite &&
                widget.width! > 0) {
              cacheWidth =
                  (widget.width! * pixelRatio).round().clamp(1, 512);
            }
            if (widget.height != null &&
                widget.height!.isFinite &&
                widget.height! > 0) {
              cacheHeight =
                  (widget.height! * pixelRatio).round().clamp(1, 512);
            }

            return Image.file(
              File(path),
              width: widget.width,
              height: widget.height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              fit: widget.fit,
              errorBuilder: (context, error, stackTrace) =>
                  _buildPlaceholder(context),
            );
          }
          return _buildPlaceholder(context);
        },
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    return content;
  }
}
