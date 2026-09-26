import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../widgets/state_views.dart';
import '../dashboard_provider.dart';

enum MetricTrendType { cpu, memory, disk }

String formatKiB(int kib) {
  if (kib >= 1024 * 1024 * 1024) {
    return '${(kib / (1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
  }
  if (kib >= 1024 * 1024) {
    return '${(kib / (1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (kib >= 1024) {
    return '${(kib / 1024).toStringAsFixed(1)} MB';
  }
  return '$kib KB';
}

void showMetricTrendModal(BuildContext context, MetricTrendType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(
      maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => MetricTrendSheet(type: type),
  );
}

class MetricTrendSheet extends ConsumerWidget {
  final MetricTrendType type;

  const MetricTrendSheet({super.key, required this.type});

  String _getMetricTitle(BuildContext context) {
    return switch (type) {
      MetricTrendType.cpu => context.l10n.metricsCpu,
      MetricTrendType.memory => context.l10n.metricsMemory,
      MetricTrendType.disk => context.l10n.metricsRootDisk,
    };
  }

  IconData _getMetricIcon() {
    return switch (type) {
      MetricTrendType.cpu => Icons.speed_rounded,
      MetricTrendType.memory => Icons.memory_rounded,
      MetricTrendType.disk => Icons.storage_rounded,
    };
  }

  Color _getValueColor(BuildContext context, double pct) {
    if (pct >= 85) return context.vDanger;
    if (pct >= 70) return context.vWarning;
    return context.vSuccess;
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;

    final title = _getMetricTitle(context);
    final icon = _getMetricIcon();
    final modalHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: Container(
        height: modalHeight,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, size: 22, color: context.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.resourceUsageTitle(title),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (type == MetricTrendType.disk)
                  IconButton(
                    key: const Key('disk_refresh_button'),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: context.l10n.sftpRefresh,
                    onPressed: () => ref.invalidate(rootDiskUsageProvider),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Disconnected warning banner
            if (!isConnected) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.vDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: context.vDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.metricsTrendStopped,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.vDanger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Content
            if (type == MetricTrendType.disk)
              _buildDiskContent(context, ref, isConnected)
            else
              _buildProcessContent(context, ref, isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildDiskContent(
    BuildContext context,
    WidgetRef ref,
    bool isConnected,
  ) {
    final diskAsync = ref.watch(rootDiskUsageProvider);

    return diskAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                context.l10n.resourceDiskScanning,
                style: TextStyle(
                  color: context.colorScheme.outline,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ErrorStateView(
          message: err.toString(),
          onRetry: () => ref.invalidate(rootDiskUsageProvider),
        ),
      ),
      data: (usage) {
        final total = usage.totalKiB;
        final used = usage.usedKiB;
        final avail = usage.availableKiB;
        final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
        final pct = ratio * 100;

        final sortedDirs = [...usage.directories]
          ..sort((a, b) => b.usedKiB.compareTo(a.usedKiB));

        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(
                          context,
                          context.l10n.resourceUsed,
                          formatKiB(used),
                          _getValueColor(context, pct),
                        ),
                        _buildStatColumn(
                          context,
                          context.l10n.resourceAvailable,
                          formatKiB(avail),
                          context.colorScheme.primary,
                        ),
                        _buildStatColumn(
                          context,
                          context.l10n.resourceTotal,
                          formatKiB(total),
                          context.colorScheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor:
                            context.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getValueColor(context, pct),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (usage.partial) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('disk_partial_banner'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.vWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: context.vWarning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.resourceDiskScanPartial,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Text(
                context.l10n.resourceDiskDirectories,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: sortedDirs.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.stateEmpty,
                          style: TextStyle(color: context.colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        key: const Key('disk_directories_list'),
                        itemCount: sortedDirs.length,
                        itemBuilder: (ctx, index) {
                          final dir = sortedDirs[index];
                          final dirRatio = total > 0
                              ? (dir.usedKiB / total).clamp(0.0, 1.0)
                              : 0.0;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: const Icon(
                              Icons.folder_outlined,
                              size: 20,
                            ),
                            title: Text(
                              dir.path,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: LinearProgressIndicator(
                              value: dirRatio,
                              minHeight: 3,
                              backgroundColor:
                                  context.colorScheme.surfaceContainerHighest,
                            ),
                            trailing: Text(
                              formatKiB(dir.usedKiB),
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessContent(
    BuildContext context,
    WidgetRef ref,
    bool isConnected,
  ) {
    final processesAsync = ref.watch(resourceProcessesProvider);
    final metricsAsync = ref.watch(systemMetricsStreamProvider);

    final isCpu = type == MetricTrendType.cpu;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overview metric card from snapshot
          metricsAsync.maybeWhen(
            data: (snap) {
              if (isCpu) {
                final ratio = snap.cpuUsedRatio.clamp(0.0, 1.0);
                final pct = ratio * 100;
                final idlePct = (1.0 - ratio) * 100;
                return Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn(
                            context,
                            context.l10n.resourceUsed,
                            '${pct.toStringAsFixed(1)}%',
                            _getValueColor(context, pct),
                          ),
                          _buildStatColumn(
                            context,
                            'Idle',
                            '${idlePct.toStringAsFixed(1)}%',
                            context.vSuccess,
                          ),
                          _buildStatColumn(
                            context,
                            'Load 1 / 5',
                            '${snap.load1.toStringAsFixed(2)} / ${snap.load5.toStringAsFixed(2)}',
                            context.colorScheme.onSurface,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor:
                              context.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getValueColor(context, pct),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                final ratio = snap.memoryUsedRatio.clamp(0.0, 1.0);
                final pct = ratio * 100;
                final availPct = (1.0 - ratio) * 100;
                return Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn(
                            context,
                            context.l10n.resourceUsed,
                            '${pct.toStringAsFixed(1)}%',
                            _getValueColor(context, pct),
                          ),
                          _buildStatColumn(
                            context,
                            context.l10n.resourceAvailable,
                            '${availPct.toStringAsFixed(1)}%',
                            context.vSuccess,
                          ),
                          _buildStatColumn(
                            context,
                            context.l10n.resourceTotal,
                            '100%',
                            context.colorScheme.onSurface,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor:
                              context.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getValueColor(context, pct),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Process list header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.resourceProcessList,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isCpu
                    ? context.l10n.resourceSortCpu
                    : context.l10n.resourceSortMemory,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Expanded(
            child: processesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.invalidate(resourceProcessesProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.stateEmpty,
                      style: TextStyle(color: context.colorScheme.outline),
                    ),
                  );
                }

                final sorted = [...list];
                if (isCpu) {
                  sorted.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));
                } else {
                  sorted.sort((a, b) {
                    final rssCmp = b.rssKiB.compareTo(a.rssKiB);
                    if (rssCmp != 0) return rssCmp;
                    return b.memoryPercent.compareTo(a.memoryPercent);
                  });
                }

                return ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (ctx, index) {
                    final proc = sorted[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      title: Row(
                        children: [
                          Text(
                            'PID ${proc.pid}',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: context.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              proc.command,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'STAT: ${proc.state}',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colorScheme.outline,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isCpu) ...[
                            Text(
                              'CPU ${proc.cpuPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getValueColor(context, proc.cpuPercent),
                              ),
                            ),
                            Text(
                              'MEM ${proc.memoryPercent.toStringAsFixed(1)}% · RSS ${formatKiB(proc.rssKiB)}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'RSS ${formatKiB(proc.rssKiB)}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getValueColor(context, proc.memoryPercent),
                              ),
                            ),
                            Text(
                              'MEM ${proc.memoryPercent.toStringAsFixed(1)}% · CPU ${proc.cpuPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
