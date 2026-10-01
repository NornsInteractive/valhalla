import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';

class ImageZoomDialog extends StatelessWidget {
  final String title;
  final Uint8List? bytes;
  final String? localPath;

  const ImageZoomDialog({
    super.key,
    required this.title,
    this.bytes,
    this.localPath,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    Uint8List? bytes,
    String? localPath,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          ImageZoomDialog(title: title, bytes: bytes, localPath: localPath),
    );
  }

  Widget _buildMissingWidget(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          size: 64,
          color: Colors.white54,
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.chatAttachmentMissing,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (bytes != null) {
      imageWidget = Image(
        image: ResizeImage(
          MemoryImage(bytes!),
          width: 2048,
          height: 2048,
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.contain,
        errorBuilder: (ctx, _, _) => _buildMissingWidget(context),
      );
    } else if (localPath != null && localPath!.isNotEmpty) {
      imageWidget = Image(
        image: ResizeImage(
          FileImage(File(localPath!)),
          width: 2048,
          height: 2048,
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.contain,
        errorBuilder: (ctx, _, _) => _buildMissingWidget(context),
      );
    } else {
      imageWidget = _buildMissingWidget(context);
    }

    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: monoTextStyle(fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: ClipRect(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Center(child: imageWidget),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
