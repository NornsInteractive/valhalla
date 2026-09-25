import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_download_service.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import 'nas_localizations.dart';

class NasDownloadsSheet extends ConsumerWidget {
  const NasDownloadsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => const NasDownloadsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadsAsync = ref.watch(nasDownloadsProvider);
    final tasks =
        downloadsAsync.asData?.value ??
        ref.watch(nasDownloadServiceProvider).tasks;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.download_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.nasTabDownloads,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.nasNoDownloads,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.separated(
                  key: const Key('nas_downloads_list'),
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskTile(context, ref, task);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    NasDownloadTask task,
  ) {
    final theme = Theme.of(context);
    final downloadService = ref.read(nasDownloadServiceProvider);

    String statusText;
    Color statusColor;
    switch (task.status) {
      case NasDownloadStatus.queued:
        statusText = context.nasDownloadQueued;
        statusColor = theme.colorScheme.outline;
        break;
      case NasDownloadStatus.downloading:
        final receivedStr = SftpFileItem.formatBytes(task.received);
        final totalStr = task.total != null && task.total! > 0
            ? SftpFileItem.formatBytes(task.total!)
            : '...';
        statusText = '$receivedStr / $totalStr';
        statusColor = theme.colorScheme.primary;
        break;
      case NasDownloadStatus.completed:
        if (task.error != null) {
          statusText = context.nasDownloadCompletedWithOpenError;
          statusColor = Colors.orangeAccent;
        } else {
          statusText = context.nasDownloadCompleted;
          statusColor = const Color(0xFF10B981);
        }
        break;
      case NasDownloadStatus.cancelled:
        statusText = context.nasDownloadCancelled;
        statusColor = theme.colorScheme.outline;
        break;
      case NasDownloadStatus.failed:
        statusText = context.nasDownloadFailed;
        statusColor = theme.colorScheme.error;
        break;
    }

    final double? progress =
        (task.status == NasDownloadStatus.downloading &&
            task.total != null &&
            task.total! > 0)
        ? (task.received / task.total!).clamp(0.0, 1.0)
        : (task.status == NasDownloadStatus.downloading
              ? null
              : (task.status == NasDownloadStatus.completed ? 1.0 : 0.0));

    return ListTile(
      key: Key('nas_download_task_${task.id}'),
      dense: true,
      title: Text(
        task.item.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (task.status == NasDownloadStatus.downloading)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(fontSize: 11, color: statusColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == NasDownloadStatus.downloading ||
              task.status == NasDownloadStatus.queued)
            IconButton(
              key: Key('nas_cancel_download_${task.id}'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              tooltip: context.nasCancelDownload,
              onPressed: () => downloadService.cancel(task.id),
            ),
          if (task.status == NasDownloadStatus.failed ||
              task.status == NasDownloadStatus.cancelled)
            IconButton(
              key: Key('nas_retry_download_${task.id}'),
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: context.nasRetryDownload,
              onPressed: () => downloadService.retry(task.id),
            ),
          if (task.status == NasDownloadStatus.completed)
            IconButton(
              key: Key('nas_open_download_${task.id}'),
              icon: Icon(
                task.error != null ? Icons.refresh : Icons.open_in_new,
                size: 18,
                color: task.error != null ? Colors.orangeAccent : null,
              ),
              tooltip: task.error != null
                  ? context.nasRetryOpen
                  : context.nasOpenDownloadedFile,
              onPressed: () async {
                try {
                  await downloadService.open(task.id);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.nasExternalOpenFailed)),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}
