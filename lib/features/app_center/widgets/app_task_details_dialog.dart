import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import 'app_center_error_resolver.dart';
import 'app_uninstall_dialog.dart';

class AppTaskDetailsDialog extends ConsumerStatefulWidget {
  final String taskId;
  final ApplicationTask? initialTask;
  final void Function(int index)? onNavigateToTab;

  const AppTaskDetailsDialog({
    super.key,
    required this.taskId,
    this.initialTask,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required String taskId,
    ApplicationTask? initialTask,
    void Function(int index)? onNavigateToTab,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppTaskDetailsDialog(
            taskId: taskId,
            initialTask: initialTask,
            onNavigateToTab: onNavigateToTab,
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => AppTaskDetailsDialog(
        taskId: taskId,
        initialTask: initialTask,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  ConsumerState<AppTaskDetailsDialog> createState() =>
      _AppTaskDetailsDialogState();
}

class _AppTaskDetailsDialogState extends ConsumerState<AppTaskDetailsDialog> {
  late final ApplicationCenterNotifier _appCenterNotifier;
  Object? _capturedServerKey;
  bool _isCancelling = false;
  bool _isRechecking = false;
  bool _isRetrying = false;
  Timer? _tickTimer;
  DateTime? _terminalElapsedAt;
  bool _initialLogScrolled = false;
  final ScrollController _logScrollController = ScrollController();
  bool _followLatest = true;

  @override
  void initState() {
    super.initState();
    _capturedServerKey = ref.read(activeServerProvider)?.connectionKey;
    _appCenterNotifier = ref.read(applicationCenterProvider.notifier);
    _appCenterNotifier.setObservedTask(widget.taskId);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _logScrollController.addListener(() {
      if (!_logScrollController.hasClients) return;
      final max = _logScrollController.position.maxScrollExtent;
      final current = _logScrollController.position.pixels;
      if (max - current > 40) {
        if (_followLatest) setState(() => _followLatest = false);
      } else {
        if (!_followLatest) setState(() => _followLatest = true);
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _logScrollController.dispose();
    _appCenterNotifier.clearObservedTask(widget.taskId);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';
    final s = d.inSeconds;
    if (s < 60) return '${s}s';
    final m = d.inMinutes;
    final remS = s % 60;
    if (m < 60) return '${m}m ${remS}s';
    final h = d.inHours;
    final remM = m % 60;
    return '${h}h ${remM}m';
  }

  Future<void> _handleCancel(ApplicationTask task) async {
    if (_isCancelling || !task.canCancel) return;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(applicationCenterProvider.notifier).cancelTask(task);
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == _capturedServerKey) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.vDanger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _handleRecheck() async {
    if (_isRechecking) return;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) return;

    setState(() => _isRechecking = true);
    try {
      await ref.read(applicationCenterProvider.notifier).refreshServer();
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == _capturedServerKey) {
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

  bool _canRetryCleanup(ApplicationTask task) {
    if (task.operation != ApplicationOperation.uninstall) return false;
    if (task.stage != ApplicationTaskStage.failed) return false;
    if (!task.uninstallCompleted) return false;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return false;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) return false;
    return task.cleanupResults.any(
      (r) =>
          r.outcome != ApplicationCleanupOutcome.removed &&
          r.outcome != ApplicationCleanupOutcome.alreadyAbsent,
    );
  }

  Future<void> _handleRetryCleanup(ApplicationTask task) async {
    if (_isRetrying || !_canRetryCleanup(task)) return;
    setState(() => _isRetrying = true);
    try {
      final newTask = await AppUninstallDialog.showRetry(context, task: task);
      if (!mounted) return;
      final currentKey = ref.read(activeServerProvider)?.connectionKey;
      final isConnected = ref.read(serverConnectionProvider).isConnected;
      if (currentKey != _capturedServerKey || !isConnected) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;

      if (newTask != null) {
        if (!mounted) return;
        await AppTaskDetailsDialog.show(
          context,
          taskId: newTask.id,
          initialTask: newTask,
          onNavigateToTab: widget.onNavigateToTab,
        );
      }
    } finally {
      if (mounted) {
        final currentKey = ref.read(activeServerProvider)?.connectionKey;
        final isConnected = ref.read(serverConnectionProvider).isConnected;
        if (currentKey == _capturedServerKey &&
            ModalRoute.of(context)?.isCurrent == true &&
            isConnected) {
          _appCenterNotifier.setObservedTask(widget.taskId);
        }
        setState(() => _isRetrying = false);
      }
    }
  }

  Widget _buildOutcomeBadge(
    BuildContext context,
    ApplicationCleanupOutcome outcome,
  ) {
    final l10n = context.l10n;
    final (label, color) = switch (outcome) {
      ApplicationCleanupOutcome.pending => (
        l10n.appCenterCleanupPending,
        context.colorScheme.outline,
      ),
      ApplicationCleanupOutcome.removed => (
        l10n.appCenterCleanupRemoved,
        context.vSuccess,
      ),
      ApplicationCleanupOutcome.alreadyAbsent => (
        l10n.appCenterCleanupAlreadyAbsent,
        context.colorScheme.outline,
      ),
      ApplicationCleanupOutcome.retained => (
        l10n.appCenterCleanupRetained,
        context.vWarning,
      ),
      ApplicationCleanupOutcome.failed => (
        l10n.appCenterTaskStageFailed,
        context.vDanger,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _copyLogs(String logs) {
    if (logs.isEmpty) return;
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.appCenterLogsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final activeServer = ref.watch(activeServerProvider);
    final targetChanged = activeServer?.connectionKey != _capturedServerKey;
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    if (targetChanged) {
      return isCompact
          ? Scaffold(
              appBar: AppBar(title: Text(context.appCenterTaskDetailsLabel)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: context.vWarning,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.appCenterErrorTargetChanged,
                        style: TextStyle(color: context.colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : AlertDialog(
              title: Text(context.appCenterTaskDetailsLabel),
              content: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: context.vWarning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.appCenterErrorTargetChanged)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.confirm),
                ),
              ],
            );
    }

    final task =
        state.tasks.where((t) => t.id == widget.taskId).firstOrNull ??
        widget.initialTask;

    ref.listen(
      applicationCenterProvider.select(
        (s) => s.tasks.where((t) => t.id == widget.taskId).firstOrNull?.logTail,
      ),
      (prev, next) {
        if (_followLatest && next != null && next != prev) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _followLatest && _logScrollController.hasClients) {
              _logScrollController.jumpTo(
                _logScrollController.position.maxScrollExtent,
              );
            }
          });
        }
      },
    );

    if (!_initialLogScrolled && task?.logTail.isNotEmpty == true) {
      _initialLogScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _followLatest && _logScrollController.hasClients) {
          _logScrollController.jumpTo(
            _logScrollController.position.maxScrollExtent,
          );
        }
      });
    }

    final isTerminal = task?.stage == ApplicationTaskStage.succeeded ||
        task?.stage == ApplicationTaskStage.failed ||
        task?.stage == ApplicationTaskStage.cancelled;

    if (isTerminal) {
      if (_tickTimer != null) {
        _tickTimer?.cancel();
        _tickTimer = null;
      }
      _terminalElapsedAt ??= task?.lastSyncedAt ?? DateTime.now();
    } else {
      _terminalElapsedAt = null;
      if (task != null && task.isBusy && _tickTimer == null) {
        _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    }

    if (task == null) {
      return isCompact
          ? Scaffold(
              appBar: AppBar(title: Text(context.appCenterTaskDetailsLabel)),
              body: Center(child: Text(l10n.appCenterNoTasks)),
            )
          : AlertDialog(
              title: Text(context.appCenterTaskDetailsLabel),
              content: Text(l10n.appCenterNoTasks),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.confirm),
                ),
              ],
            );
    }

    final isBusy = task.isBusy;
    final stageColor = switch (task.stage) {
      ApplicationTaskStage.succeeded => context.vSuccess,
      ApplicationTaskStage.failed => context.vDanger,
      ApplicationTaskStage.cancelled => context.colorScheme.outline,
      ApplicationTaskStage.needsInspection => context.vWarning,
      _ => context.colorScheme.primary,
    };

    final opLabel = resolveApplicationOperationLabel(context, task.operation);
    final stageLabel = resolveApplicationTaskStageLabel(context, task.stage);
    final isSucceeded = task.stage == ApplicationTaskStage.succeeded;
    final isNeedsInspection =
        task.stage == ApplicationTaskStage.needsInspection;
    final isPartialUninstall =
        task.operation == ApplicationOperation.uninstall &&
        task.uninstallCompleted &&
        (task.stage == ApplicationTaskStage.failed ||
            task.cleanupResults.any(
              (r) =>
                  r.outcome == ApplicationCleanupOutcome.failed ||
                  r.outcome == ApplicationCleanupOutcome.retained,
            ));
    final hasCleanupResults =
        task.operation == ApplicationOperation.uninstall &&
        task.cleanupResults.isNotEmpty;
    final anyCleanupFailed = task.cleanupResults.any(
      (r) => r.outcome == ApplicationCleanupOutcome.failed,
    );

    final now = DateTime.now();
    final elapsed = _terminalElapsedAt != null
        ? _terminalElapsedAt!.difference(task.createdAt)
        : now.difference(task.createdAt);

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Operation and Stage Row
          Row(
            children: [
              if (isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: stageColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$opLabel: ${task.name}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  border: Border.all(
                    color: stageColor.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  stageLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: stageColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metadata Table
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Column(
              children: [
                _buildMetaRow(
                  context,
                  context.appCenterTaskTargetLabel,
                  task.targetIdentity.isNotEmpty
                    ? task.targetIdentity
                    : task.serverId,
                ),
                const SizedBox(height: 6),
                _buildMetaRow(
                  context,
                  context.appCenterTaskDirectoryLabel,
                  task.directory,
                ),
                const SizedBox(height: 6),
                _buildMetaRow(
                  context,
                  context.appCenterTaskCreatedAtLabel,
                  task.createdAt.toLocal().toString().split('.').first,
                ),
                const SizedBox(height: 6),
                _buildMetaRow(
                  context,
                  context.appCenterElapsedLabel,
                  _formatDuration(elapsed),
                ),
                if (task.isBusy && task.lastOutputAt != null) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(
                    context,
                    context.appCenterLastOutputLabel,
                    _formatDuration(now.difference(task.lastOutputAt!)),
                  ),
                ],
                if (task.exitCode != null) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(
                    context,
                    l10n.appCenterOperation,
                    context.appCenterTaskExitCodeLabel(task.exitCode!),
                    valueColor: task.exitCode == 0
                        ? context.vSuccess
                        : context.vDanger,
                  ),
                ],
              ],
            ),
          ),

          // Separate Sync Unavailable Banner (preserving stage)
          if (task.syncError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: context.vWarning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.appCenterSyncUnavailableLabel}: ${task.syncError}',
                      style: TextStyle(fontSize: 11, color: context.vWarning),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Partial uninstall warning banner
          if (isPartialUninstall) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.vWarning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appCenterCleanupPartialSummary,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.vWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Cleanup Results Section
          if (hasCleanupResults) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appCenterCleanupResultsTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (anyCleanupFailed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.vDanger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VRadius.card),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: context.vDanger,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.appCenterCleanupDeleteFailed,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.vDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  for (final r in task.cleanupResults) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            r.source,
                            style: monoTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildOutcomeBadge(context, r.outcome),
                          if (r.reasonCode != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              resolveAppCenterErrorMessage(
                                context,
                                r.reasonCode!,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (r != task.cleanupResults.last)
                      Divider(
                        height: 8,
                        color: context.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],

          // Current Command Focus Container (Selectable & Copyable)
          if (task.currentCommand.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 14,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.appCenterCurrentCommandLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: l10n.appCenterCopyLog,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: task.currentCommand));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.appCenterLogsCopied),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    task.currentCommand,
                    style: monoTextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Needs inspection warning and read-only recheck
          if (isNeedsInspection) ...[
            const SizedBox(height: 12),
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: context.vWarning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.appCenterTaskNeedsInspectionTitleLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.appCenterTaskNeedsInspectionMessageLabel,
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    icon: _isRechecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(context.appCenterRecheckTaskLabel),
                    onPressed: (_isRechecking || !isConnected || targetChanged)
                        ? null
                        : _handleRecheck,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Logs Section Header
          Row(
            children: [
              Text(
                l10n.appCenterLogs,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_followLatest && isBusy) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.arrow_downward, size: 14),
                  label: Text(
                    context.appCenterFollowLatestLogsLabel,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    setState(() => _followLatest = true);
                    if (_logScrollController.hasClients) {
                      _logScrollController.animateTo(
                        _logScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              if (task.logTail.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: l10n.appCenterCopyLog,
                  onPressed: () => _copyLogs(task.logTail),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Log Box
          Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: SingleChildScrollView(
              controller: _logScrollController,
              child: SelectableText(
                task.logTail.isNotEmpty
                    ? task.logTail
                    : l10n.appCenterWaitingForLogs,
                style: monoTextStyle(
                  fontSize: 10,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final actions = <Widget>[
      if (task.canCancel)
        OutlinedButton.icon(
          icon: _isCancelling
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined, size: 16),
          label: Text(l10n.appCenterCancelTask),
          onPressed: (_isCancelling || !isConnected || targetChanged)
              ? null
              : () => _handleCancel(task),
        ),
      if (_canRetryCleanup(task))
        FilledButton.tonalIcon(
          icon: _isRetrying
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 16),
          label: Text(l10n.appCenterCleanupRetryAction),
          onPressed: (_isRetrying || !isConnected || targetChanged)
              ? null
              : () => _handleRetryCleanup(task),
        ),
      if (isSucceeded)
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text(context.appCenterViewInstalledLabel),
          onPressed: () {
            Navigator.pop(context);
            widget.onNavigateToTab?.call(1);
          },
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.confirm),
      ),
    ];

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.appCenterTaskDetailsLabel),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: actions,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(context.appCenterTaskDetailsLabel),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 560,
        ),
        child: SizedBox(width: double.maxFinite, child: content),
      ),
      actions: actions,
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: monoTextStyle(
              fontSize: 11,
              color: valueColor ?? context.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
