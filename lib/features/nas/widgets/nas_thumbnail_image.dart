import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_image_cache_service.dart';
import '../../../data/models/nas_media.dart';

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

class _NasThumbnailImageState extends ConsumerState<NasThumbnailImage> {
  Future<String?>? _thumbnailFuture;
  NasMediaItem? _currentItem;
  NasImageCacheService? _capturedService;

  @override
  void initState() {
    super.initState();
    final service = ref.read(nasImageCacheProvider);
    _capturedService = service;
    _loadThumbnail(widget.item, service);
  }

  void _loadThumbnail(NasMediaItem item, NasImageCacheService service) {
    _currentItem = item;
    // Skip huge images (>32MiB) in thumbnail tiles
    if (item.kind == NasMediaKind.image && item.sizeBytes > 32 * 1024 * 1024) {
      _thumbnailFuture = null;
      return;
    }
    _thumbnailFuture = service.thumbnail(item, owner: this);
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
      }
      final NasImageCacheService service = ref.read(nasImageCacheProvider);
      _capturedService = service;
      _loadThumbnail(widget.item, service);
    }
  }

  @override
  void dispose() {
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
    final currentService = ref.watch(nasImageCacheProvider);
    if (!identical(currentService, _capturedService)) {
      if (_currentItem != null && _capturedService != null) {
        _capturedService!.releaseThumbnail(_currentItem!, this);
      }
      _capturedService = currentService;
      _loadThumbnail(widget.item, currentService);
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
            return Image.file(
              File(path),
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
