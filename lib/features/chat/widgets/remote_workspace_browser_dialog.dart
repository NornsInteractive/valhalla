import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/remote_browser_service.dart';
import '../../../data/models/remote_browser.dart'
    show RemoteBrowserEntry, RemoteBrowserSource;
import '../../../infrastructure/acp/acp_client_adapter.dart';
import '../../../infrastructure/acp/acp_workspace_files.dart';
import '../../../widgets/remote_browser_dialog.dart' as rbd;

enum RemoteBrowserMode { directory, files }

abstract final class RemoteWorkspaceBrowserDialog {
  static Future<Object?> show(
    BuildContext context, {
    String? initialPath,
    required RemoteBrowserMode mode,
  }) async {
    final container = ProviderScope.containerOf(context);
    final snapshot = container.read(aiChatProvider);
    final profile = snapshot.activeAgentProfile;
    final serverKey = container.read(activeServerProvider)?.connectionKey;
    if (profile == null || serverKey == null) return null;
    bool current() {
      if (!context.mounted) return false;
      final state = container.read(aiChatProvider);
      return container.read(activeServerProvider)?.connectionKey == serverKey &&
          container.read(serverConnectionProvider).isConnected &&
          state.activeAgentProfile == profile &&
          state.activeSessionId == snapshot.activeSessionId &&
          state.draftWorkingDirectory == snapshot.draftWorkingDirectory &&
          state.recoveryStatus != SessionRecoveryStatus.reconnecting &&
          state.recoveryStatus != SessionRecoveryStatus.syncing;
    }

    if (!current()) return null;
    final path = initialPath?.trim();
    RemoteBrowserSource? source;
    try {
      source = await container
          .read(remoteBrowserFactoryProvider)
          .agent(
            profile: profile,
            initialPath: path != null && path.isNotEmpty
                ? path
                : snapshot.activeSession?.workingDirectory ??
                      snapshot.draftWorkingDirectory,
            isCurrent: current,
          );
      if (!context.mounted || !source.isCurrent) return null;
      if (mode == RemoteBrowserMode.directory) {
        final result = await rbd.RemoteBrowserDialog.pickDirectory(
          context,
          source,
        );
        return source.isCurrent ? result : null;
      }

      bool canSelect(RemoteBrowserEntry entry) {
        if (!current() || entry.isDirectory || !entry.selectable) return false;
        final mime = AcpWorkspaceFiles.mimeType(entry.name);
        if (mime == null) return false;
        final state = container.read(aiChatProvider);
        final image = mime.startsWith('image/');
        if (image ? !state.supportsImages : !state.supportsTextAttachments) {
          return false;
        }
        final remaining =
            (image
                ? AcpPromptAttachment.maxImageBytes
                : AcpPromptAttachment.maxTextBytes) -
            state.attachments
                .where((attachment) => attachment.isImage == image)
                .fold<int>(
                  0,
                  (bytes, attachment) => bytes + attachment.bytes.length,
                );
        return remaining >= 0 && (entry.sizeBytes ?? 0) <= remaining;
      }

      final files = await rbd.RemoteBrowserDialog.pickFiles(
        context,
        source,
        multiSelect: true,
        canSelectEntry: canSelect,
      );
      if (!source.isCurrent || files == null || !files.every(canSelect)) {
        return null;
      }
      return files.map((entry) => entry.id).toList();
    } catch (_) {
      if (!current()) return null;
      rethrow;
    } finally {
      await source?.dispose();
    }
  }
}
