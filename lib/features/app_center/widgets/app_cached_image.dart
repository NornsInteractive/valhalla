import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/providers/application_center_provider.dart';

class AppCachedImage extends ConsumerStatefulWidget {
  final String url;
  final String revision;
  final String? sourceId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppCachedImage({
    super.key,
    required this.url,
    this.revision = '',
    this.sourceId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  ConsumerState<AppCachedImage> createState() => _AppCachedImageState();
}

class _AppCachedImageState extends ConsumerState<AppCachedImage> {
  File? _file;
  bool _isLoading = true;
  bool _hasError = false;
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(AppCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.revision != widget.revision ||
        oldWidget.sourceId != widget.sourceId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.url.trim();
    if (url.isEmpty || !url.startsWith('https://')) {
      _loadedKey = null;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _file = null;
      });
      return;
    }

    final key = '$url|${widget.revision}|${widget.sourceId ?? ''}';
    _loadedKey = key;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = await ref
          .read(applicationCatalogServiceProvider)
          .image(
            url,
            revision: widget.revision,
            sourceId: widget.sourceId,
          );
      if (!mounted || _loadedKey != key) return;
      setState(() {
        _file = file;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || _loadedKey != key) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _file = null;
      });
    }
  }

  bool _isSvg(String url, File file) {
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.svg')) return true;
    try {
      final pathLower = file.path.toLowerCase();
      if (pathLower.endsWith('.svg')) return true;
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    final defaultError = SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 24)),
    );

    if (_isLoading) {
      return widget.placeholder ?? defaultPlaceholder;
    }

    if (_hasError || _file == null) {
      return widget.errorWidget ?? defaultError;
    }

    final isSvgImage = _isSvg(widget.url, _file!);

    if (isSvgImage) {
      return SvgPicture.file(
        _file!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholderBuilder: (_) => widget.placeholder ?? defaultPlaceholder,
      );
    }

    return Image.file(
      _file!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: (context, error, stackTrace) =>
          widget.errorWidget ?? defaultError,
    );
  }
}
