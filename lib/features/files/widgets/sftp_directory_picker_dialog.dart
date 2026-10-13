import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/remote_browser_service.dart';
import '../../../data/models/remote_browser.dart';
import '../../../widgets/remote_browser_dialog.dart';

abstract final class SftpDirectoryPickerDialog {
  static Future<String?> show(
    BuildContext context, {
    required String initialPath,
    required String title,
    Set<String> restrictedPaths = const {},
  }) async {
    final container = ProviderScope.containerOf(context);
    final capturedKey = container.read(activeServerProvider)?.connectionKey;
    bool current() =>
        context.mounted &&
        capturedKey != null &&
        container.read(activeServerProvider)?.connectionKey == capturedKey &&
        container.read(serverConnectionProvider).isConnected;
    if (!current()) return null;
    final restricted = restrictedPaths.map(p.posix.normalize).toSet();
    bool isRestricted(String path) {
      final normalized = p.posix.normalize(path);
      return restricted.any(
        (root) => normalized == root || p.posix.isWithin(root, normalized),
      );
    }

    RemoteBrowserSource? source;
    try {
      source = container
          .read(remoteBrowserFactoryProvider)
          .host(initialPath: initialPath, isCurrent: current);
      final picked = await RemoteBrowserDialog.pickDirectory(
        context,
        source,
        title: title,
        initialPath: initialPath,
        isPathRestricted: isRestricted,
      );
      return source.isCurrent && picked != null && !isRestricted(picked)
          ? picked
          : null;
    } catch (_) {
      if (context.mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.stateError)));
      }
      return null;
    } finally {
      await source?.dispose();
    }
  }
}
