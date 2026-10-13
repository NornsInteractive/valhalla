import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import '../../../widgets/valhalla_card.dart';
import 'app_center_error_resolver.dart';
import 'app_task_details_dialog.dart';

class AppTasksTab extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateToTab;

  const AppTasksTab({super.key, this.onNavigateToTab});

  @override
  ConsumerState<AppTasksTab> createState() => _AppTasksTabState();
}

class _AppTasksTabState extends ConsumerState<AppTasksTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _cancellingTaskIds = {};
  bool _isRechecking = false;
  Object? _lastServerKey;

  @override
  bool get wantKeepAlive => true;

  Future<void> _handleCancelTask(ApplicationTask task) async {
    if (_cancellingTaskIds.contains(task.id) || !task.canCancel) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorNotConnected),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }

    setState(() => _cancellingTaskIds.add(task.id));
    try {
      await ref.read(applicationCenterProvider.notifier).cancelTask(task);
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cancellingTaskIds.remove(task.id));
      }
    }
  }

  Future<void> _handleRecheckTask() async {
    if (_isRechecking) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorNotConnected),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }

    setState(() => _isRechecking = true);
    try {
      await ref.read(applicationCenterProvider.notifier).refreshServer();
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRechecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final tasks = state.tasks;
    final activeServer = ref.watch(activeServerProvider);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    final currentServerKey = activeServer?.connectionKey;
    if (_lastServerKey != currentServerKey) {
      _lastServerKey = currentServerKey;
      _cancellingTaskIds.clear();
      _isRechecking = false;
    }

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 48,
                color: context.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.appCenterNoTasks,
                style: TextStyle(color: context.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: Text(context.appCenterBrowseStoreLabel),
                onPressed: () => widget.onNavigateToTab?.call(0),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final task = tasks[idx];
        final isBusy = task.isBusy;
        final isNeedsInspection =
            task.stage == ApplicationTaskStage.needsInspection;
        final stageColor = switch (task.stage) {
          ApplicationTaskStage.succeeded => context.vSuccess,
          ApplicationTaskStage.failed => context.vDanger,
          ApplicationTaskStage.cancelled => context.colorScheme.outline,
          ApplicationTaskStage.needsInspection => context.vWarning,
          _ => context.colorScheme.primary,
        };

        final opLabel = resolveApplicationOperationLabel(
          context,
          task.operation,
        );
        final stageLabel = resolveApplicationTaskStageLabel(
          context,
          task.stage,
        );
        final isCancellingThis = _cancellingTaskIds.contains(task.id);
        final isPartialUninstall =
            task.operation == ApplicationOperation.uninstall &&
            task.uninstallCompleted &&
            (task.stage == ApplicationTaskStage.failed ||
                task.cleanupResults.any(
                  (r) =>
                      r.outcome == ApplicationCleanupOutcome.failed ||
                      r.outcome == ApplicationCleanupOutcome.retained,
                ));

        return ValhallaCard(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(VRadius.card),
            onTap: () => AppTaskDetailsDialog.show(
              context,
              taskId: task.id,
              initialTask: task,
              onNavigateToTab: widget.onNavigateToTab,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isBusy)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: stageColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$opLabel: ${task.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                        child: Text(
                          stageLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: stageColor,
                          ),
                        ),
                      ),
                      if (task.canCancel) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: isCancellingThis
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined, size: 18),
                          tooltip: l10n.appCenterCancelTask,
                          onPressed: (!isConnected || isCancellingThis)
                              ? null
                              : () => _handleCancelTask(task),
                        ),
                      ],
                      if (isNeedsInspection) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: _isRechecking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          tooltip: context.appCenterRecheckLabel,
                          onPressed: (!isConnected || _isRechecking)
                              ? null
                              : _handleRecheckTask,
                        ),
                      ],
                    ],
                  ),
                  if (task.exitCode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.appCenterTaskExitCodeLabel(task.exitCode!),
                      style: TextStyle(
                        fontSize: 11,
                        color: task.exitCode == 0
                            ? context.vSuccess
                            : context.vDanger,
                      ),
                    ),
                  ],
                  if (isPartialUninstall) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.appCenterCleanupPartialSummary,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.vWarning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (isNeedsInspection) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.appCenterTaskNeedsInspectionMessageLabel,
                      style: TextStyle(fontSize: 11, color: context.vWarning),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.logTail.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(VRadius.card),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              task.logTail,
                              style: monoTextStyle(
                                fontSize: 10,
                                color: const Color(0xFFE2E8F0),
                              ),
                              maxLines: 4,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.white70,
                            ),
                            tooltip: l10n.appCenterCopyLog,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: task.logTail),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.appCenterLogsCopied),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
