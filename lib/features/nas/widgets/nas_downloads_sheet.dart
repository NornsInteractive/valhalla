import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_download_service.dart';
import '../../../data/models/nas_media.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import 'nas_image_viewer_dialog.dart';
import 'nas_localizations.dart';

class NasDownloadsSheet extends ConsumerWidget {
  final bool isModal;
  final String? sourceId;

  const NasDownloadsSheet({super.key, this.isModal = false, this.sourceId});

  static Future<void> show(BuildContext context, {String? sourceId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => NasDownloadsSheet(isModal: true, sourceId: sourceId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadsAsync = ref.watch(nasDownloadsProvider);
    final service = ref.watch(nasDownloadServiceProvider);
    final tasks = (downloadsAsync.asData?.value ?? service.tasks)
        .where((task) => sourceId == null || task.item.sourceId == sourceId)
        .toList(growable: false);
    final recordedBytes = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.received > 0 ? task.received : 0),
    );

    Widget body;
    if (downloadsAsync.isLoading && tasks.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.nasTabDownloads,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    } else if (downloadsAsync.hasError && tasks.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                context.nasSanitizedError(downloadsAsync.error),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.nasRetryDownload),
                onPressed: () {
                  ref.invalidate(nasDownloadServiceProvider);
                  ref.invalidate(nasDownloadsProvider);
                },
              ),
            ],
          ),
        ),
      );
    } else if (tasks.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      );
    } else {
      final list = ListView.separated(
        key: const Key('nas_downloads_list'),
        padding: isModal ? null : const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, index) => _buildTaskTile(ctx, ref, tasks[index]),
      );

      final listWithWarning = downloadsAsync.hasError
          ? Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.nasSanitizedError(downloadsAsync.error),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(nasDownloadServiceProvider);
                          ref.invalidate(nasDownloadsProvider);
                        },
                        child: Text(context.nasRetryDownload),
                      ),
                    ],
                  ),
                ),
                Expanded(child: list),
              ],
            )
          : list;

      body = listWithWarning;
    }

    final content = Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isModal) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.download_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.nasTabDownloads,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.nasOfflineRecordedBytes(
                  (downloadsAsync.isLoading || downloadsAsync.hasError) &&
                          tasks.isEmpty
                      ? context.l10n.agentStatusUnknown
                      : recordedBytes == 0
                      ? '0 B'
                      : SftpFileItem.formatBytes(recordedBytes),
                ),
                key: const Key('nas_download_recorded_bytes'),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.nasOfflineRecordedHint,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );

    return isModal
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .85,
                child: content,
              ),
            ),
          )
        : content;
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
      case NasDownloadStatus.paused:
        final receivedStr = SftpFileItem.formatBytes(task.received);
        statusText = '${context.nasDownloadPaused} ($receivedStr)';
        statusColor = context.vWarning;
        break;
      case NasDownloadStatus.completed:
        if (task.error != null) {
          statusText = context.nasSanitizedError(task.error);
          statusColor = context.vWarning;
        } else {
          statusText = context.nasDownloadCompleted;
          statusColor = context.vSuccess;
        }
        break;
      case NasDownloadStatus.cancelled:
        statusText = context.nasDownloadCancelled;
        statusColor = theme.colorScheme.outline;
        break;
      case NasDownloadStatus.failed:
        statusText = task.error != null
            ? context.nasSanitizedError(task.error)
            : context.nasDownloadFailed;
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
            progress != null
                ? AnimatedProgressBar(value: progress, height: 4)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: monoTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active task actions: Pause & Cancel
          if (task.status == NasDownloadStatus.downloading ||
              task.status == NasDownloadStatus.queued) ...[
            IconButton(
              key: Key('nas_pause_download_${task.id}'),
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              tooltip: context.nasDownloadPaused,
              onPressed: () async {
                try {
                  await downloadService.pause(task.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.nasSanitizedError(e)),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              key: Key('nas_cancel_download_${task.id}'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              tooltip: context.nasCancelDownload,
              onPressed: () => downloadService.cancel(task.id),
            ),
          ],

          // Paused task actions: Resume, Restart (with confirmation), Remove
          if (task.status == NasDownloadStatus.paused) ...[
            IconButton(
              key: Key('nas_resume_download_${task.id}'),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              tooltip: context.nasDownloadResume,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                try {
                  await downloadService.resume(task.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.nasSanitizedError(e)),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              key: Key('nas_restart_download_${task.id}'),
              icon: const Icon(Icons.replay, size: 18),
              tooltip: context.nasDownloadRestartFromScratch,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () =>
                  _confirmAndRestart(context, downloadService, task),
            ),
            IconButton(
              key: Key('nas_remove_download_${task.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: context.nasDownloadDeleteConfirmButton,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () =>
                  _confirmAndRemove(context, downloadService, task),
            ),
          ],

          // Failed task actions:
          // If SOURCE_CHANGED -> explicit restart-from-zero confirmation dialog, or remove
          // If other failure -> resume with validated partial, or restart with confirmation, or remove
          if (task.status == NasDownloadStatus.failed) ...[
            if (task.error == 'NAS_DOWNLOAD_SOURCE_CHANGED') ...[
              IconButton(
                key: Key('nas_retry_download_${task.id}'),
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: context.nasDownloadRestartFromScratch,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () =>
                    _showSourceChangedDialog(context, downloadService, task),
              ),
              IconButton(
                key: Key('nas_remove_download_${task.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: context.nasDownloadDeleteConfirmButton,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () =>
                    _confirmAndRemove(context, downloadService, task),
              ),
            ] else ...[
              IconButton(
                key: Key('nas_resume_download_${task.id}'),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                tooltip: context.nasDownloadResume,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () async {
                  try {
                    await downloadService.resume(task.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.nasSanitizedError(e)),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
              IconButton(
                key: Key('nas_restart_download_${task.id}'),
                icon: const Icon(Icons.replay, size: 18),
                tooltip: context.nasDownloadRestartFromScratch,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () =>
                    _confirmAndRestart(context, downloadService, task),
              ),
              IconButton(
                key: Key('nas_remove_download_${task.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: context.nasDownloadDeleteConfirmButton,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () =>
                    _confirmAndRemove(context, downloadService, task),
              ),
            ],
          ],

          // Cancelled task actions: restart from scratch or remove
          if (task.status == NasDownloadStatus.cancelled) ...[
            IconButton(
              key: Key('nas_retry_download_${task.id}'),
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: context.nasRetryDownload,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                try {
                  await downloadService.restart(task.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.nasSanitizedError(e)),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              key: Key('nas_remove_download_${task.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: context.nasDownloadDeleteConfirmButton,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () =>
                  _confirmAndRemove(context, downloadService, task),
            ),
          ],

          // Completed actions: In-App Open (primary), and system open, reveal, delete offline copy
          if (task.status == NasDownloadStatus.completed) ...[
            IconButton(
              key: Key('nas_open_in_app_${task.id}'),
              icon: const Icon(Icons.play_circle_fill, size: 18),
              tooltip: context.nasOpenInApp,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                await _handleInAppOpen(context, ref, downloadService, task);
              },
            ),
            if (MediaQuery.sizeOf(context).width < 380)
              PopupMenuButton<String>(
                key: Key('nas_task_overflow_${task.id}'),
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: context.l10n.navMore,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onSelected: (val) async {
                  if (val == 'open') {
                    try {
                      await downloadService.open(task.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.nasSanitizedError(e)),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  } else if (val == 'reveal') {
                    try {
                      await downloadService.reveal(task.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.downloadRevealFailed),
                          ),
                        );
                      }
                    }
                  } else if (val == 'delete') {
                    _confirmAndRemove(context, downloadService, task);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    key: Key('nas_open_download_${task.id}'),
                    value: 'open',
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.nasOpenSystem),
                      ],
                    ),
                  ),
                  if (!kIsWeb &&
                      (defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.macOS ||
                          defaultTargetPlatform == TargetPlatform.linux))
                    PopupMenuItem(
                      key: Key('nas_reveal_download_${task.id}'),
                      value: 'reveal',
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(ctx.l10n.downloadReveal),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    key: Key('nas_delete_download_${task.id}'),
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.nasDownloadDeleteConfirmButton),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              IconButton(
                key: Key('nas_open_download_${task.id}'),
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: context.nasOpenSystem,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () async {
                  try {
                    await downloadService.open(task.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.nasSanitizedError(e)),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
              if (!kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.windows ||
                      defaultTargetPlatform == TargetPlatform.macOS ||
                      defaultTargetPlatform == TargetPlatform.linux))
                IconButton(
                  key: Key('nas_reveal_download_${task.id}'),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  tooltip: context.l10n.downloadReveal,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () async {
                    try {
                      await downloadService.reveal(task.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.downloadRevealFailed),
                          ),
                        );
                      }
                    }
                  },
                ),
              IconButton(
                key: Key('nas_delete_download_${task.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: context.nasDownloadDeleteConfirmButton,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () =>
                    _confirmAndRemove(context, downloadService, task),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _handleInAppOpen(
    BuildContext context,
    WidgetRef ref,
    NasDownloadService downloadService,
    NasDownloadTask task,
  ) async {
    if (task.item.kind == NasMediaKind.image) {
      try {
        final path = await downloadService.localFile(task.id);
        if (!context.mounted) return;
        NasImageViewerDialog.show(
          context,
          item: task.item,
          localFilePath: path,
          onOpenExternal: () async {
            try {
              await downloadService.open(task.id);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.nasSanitizedError(e)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.nasSanitizedError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
      return;
    }

    // Audio or Video: core automatically resolves localPathFor before remote adapter
    try {
      await ref.read(nasProvider.notifier).openInApp(task.item);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.nasSanitizedError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndRemove(
    BuildContext context,
    NasDownloadService downloadService,
    NasDownloadTask task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.nasDownloadDeleteConfirmTitle),
        content: Text(ctx.nasDownloadDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.theme.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.nasDownloadDeleteConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await downloadService.remove(task.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.nasSanitizedError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSourceChangedDialog(
    BuildContext context,
    NasDownloadService downloadService,
    NasDownloadTask task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.nasDownloadErrorSourceChanged),
        content: Text(ctx.nasDownloadSourceChangedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.nasDownloadRestartFromScratch),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await downloadService.restart(task.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.nasSanitizedError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmAndRestart(
    BuildContext context,
    NasDownloadService downloadService,
    NasDownloadTask task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.nasDownloadRestartFromScratch),
        content: Text(ctx.nasDownloadSourceChangedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.nasDownloadRestartFromScratch),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await downloadService.restart(task.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.nasSanitizedError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
