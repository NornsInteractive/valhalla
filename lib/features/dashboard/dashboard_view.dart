import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/providers/cli_chat_provider.dart';
import '../../core/providers/server_power_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/sftp_provider.dart';
import '../../core/providers/terminal_provider.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/system/system_hardware_service.dart';
import '../../infrastructure/system/system_metrics_sampler.dart';
import '../../widgets/danger_confirm_dialog.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/valhalla_card.dart';
import '../../widgets/state_views.dart';
import '../shell/main_shell.dart'
    show appSectionIcon, appSectionToViewIndex, localizedAppSectionName;
import 'dashboard_provider.dart';
import 'widgets/metric_trend_dialog.dart';
import 'widgets/network_details_modal.dart';
import 'widgets/neofetch_sheet.dart';

class DashboardView extends ConsumerWidget {
  final void Function(int targetTab)? onNavigate;
  final VoidCallback? onConnect;

  const DashboardView({super.key, this.onNavigate, this.onConnect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(activeServerProvider);
    final connState = ref.watch(serverConnectionProvider);
    final powerState = ref.watch(serverPowerProvider);
    final quickSections = () {
      try {
        return ref.watch(settingsProvider).visibleDashboardQuickSections;
      } catch (_) {
        return defaultDashboardQuickSections;
      }
    }();
    final metricsAsync = ref.watch(systemMetricsStreamProvider);
    final snapshot =
        metricsAsync.asData?.value ??
        ref.watch(systemMetricsHistoryProvider).lastOrNull;

    if (activeServer == null) {
      return Scaffold(
        body: EmptyStateView(
          icon: Icons.dns_outlined,
          title: context.l10n.noServerSelected,
          description: context.l10n.addServer,
        ),
      );
    }

    final history = ref.watch(systemMetricsHistoryProvider);
    final lastSnapshot = snapshot;
    final isReconnecting = connState.isConnecting;
    final hasExistingData = lastSnapshot != null || history.isNotEmpty;

    if (!connState.isConnected && !isReconnecting && !hasExistingData) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildServerHeaderCard(
                  context,
                  ref,
                  activeServer,
                  connState,
                  powerState,
                  snapshot,
                ),
                const SizedBox(height: 24),
                if (powerState.serverId == activeServer.id) ...[
                  if (powerState.action == ServerPowerAction.shutdown) ...[
                    if (powerState.phase == ServerPowerPhase.accepted) ...[
                      _buildPowerStatusBanner(
                        context,
                        ref,
                        message: context.l10n.serverShutdownAccepted,
                        isWarning: false,
                        showReconnect: false,
                      ),
                      const SizedBox(height: 16),
                    ] else if (powerState.phase ==
                        ServerPowerPhase.unknown) ...[
                      _buildPowerStatusBanner(
                        context,
                        ref,
                        message: context.l10n.serverShutdownUnknown,
                        isWarning: true,
                        showReconnect: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ] else ...[
                    if (powerState.phase == ServerPowerPhase.accepted) ...[
                      _buildPowerStatusBanner(
                        context,
                        ref,
                        message: context.l10n.serverRebootAccepted,
                        isWarning: false,
                        showReconnect: true,
                      ),
                      const SizedBox(height: 16),
                    ] else if (powerState.phase ==
                        ServerPowerPhase.unknown) ...[
                      _buildPowerStatusBanner(
                        context,
                        ref,
                        message: context.l10n.serverRebootUnknown,
                        isWarning: true,
                        showReconnect: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
                OfflineStateView(onConnect: () => _doReconnect(ref)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(systemMetricsStreamProvider);
          ref.invalidate(systemHardwareProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServerHeaderCard(
                context,
                ref,
                activeServer,
                connState,
                powerState,
                snapshot,
              ),
              if (powerState.serverId == activeServer.id) ...[
                if (powerState.action == ServerPowerAction.shutdown) ...[
                  if (powerState.phase == ServerPowerPhase.accepted) ...[
                    const SizedBox(height: 12),
                    _buildPowerStatusBanner(
                      context,
                      ref,
                      message: context.l10n.serverShutdownAccepted,
                      isWarning: false,
                      showReconnect: false,
                    ),
                  ] else if (powerState.phase == ServerPowerPhase.unknown) ...[
                    const SizedBox(height: 12),
                    _buildPowerStatusBanner(
                      context,
                      ref,
                      message: context.l10n.serverShutdownUnknown,
                      isWarning: true,
                      showReconnect: false,
                    ),
                  ],
                ] else ...[
                  if (powerState.phase == ServerPowerPhase.accepted) ...[
                    const SizedBox(height: 12),
                    _buildPowerStatusBanner(
                      context,
                      ref,
                      message: context.l10n.serverRebootAccepted,
                      isWarning: false,
                      showReconnect: true,
                    ),
                  ] else if (powerState.phase == ServerPowerPhase.unknown) ...[
                    const SizedBox(height: 12),
                    _buildPowerStatusBanner(
                      context,
                      ref,
                      message: context.l10n.serverRebootUnknown,
                      isWarning: true,
                      showReconnect: true,
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 16),
              Entrance(
                index: 1,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.dashboardTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    if (!connState.isConnected && hasExistingData) ...[
                      Container(
                        key: const Key('dashboardStaleDataIndicator'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                          border: Border.all(
                            color: context.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pause_circle_outline,
                              size: 13,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.dashboardUpdatesPaused,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Entrance(
                index: 2,
                child: metricsAsync.when(
                  data: (snap) => _buildMetricsGrid(context, snap),
                  loading: () => snapshot != null
                      ? _buildMetricsGrid(context, snapshot)
                      : const SkeletonMetricGrid(columns: 2, rows: 2),
                  error: (err, _) => snapshot != null
                      ? _buildMetricsGrid(context, snapshot)
                      : ValhallaCard(
                          padding: const EdgeInsets.all(16),
                          child: ErrorStateView(
                            message: err.toString(),
                            onRetry: () =>
                                ref.invalidate(systemMetricsStreamProvider),
                          ),
                        ),
                ),
              ),
              if (quickSections.isNotEmpty) ...[
                const SizedBox(height: 20),
                Entrance(
                  index: 3,
                  child: Text(
                    context.l10n.quickActions,
                    style: context.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                Entrance(
                  index: 4,
                  child: _buildQuickShortcuts(context, quickSections),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerHeaderCard(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
    ServerConnectionState connState,
    ServerPowerState powerState,
    SystemMetricsSnapshot? snapshot,
  ) {
    StatusType badgeType;
    String badgeLabel;
    if (connState.isConnected) {
      badgeType = StatusType.online;
      badgeLabel = context.l10n.serverConnected;
    } else if (connState.isConnecting) {
      badgeType = StatusType.running;
      badgeLabel = context.l10n.serverConnecting;
    } else if (connState.status == ConnectionStateEnum.error) {
      badgeType = StatusType.danger;
      badgeLabel = context.l10n.stateError;
    } else {
      badgeType = StatusType.offline;
      badgeLabel = context.l10n.serverDisconnected;
    }

    final isPowerBusy =
        powerState.phase == ServerPowerPhase.submitting ||
        powerState.phase == ServerPowerPhase.accepted ||
        powerState.phase == ServerPowerPhase.unknown;

    return Entrance(
      index: 0,
      child: ValhallaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final serverInfo = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(VRadius.input),
                        border: Border.all(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.dns_rounded,
                        color: context.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  server.name,
                                  style: context.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      context.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: context.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  server.authType.name.toUpperCase(),
                                  style: monoTextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${server.username}@${server.host}:${server.port}',
                                  style: monoTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(label: badgeLabel, type: badgeType),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (connState.isConnected) ...[
                      OutlinedButton.icon(
                        key: const Key('dashboard_reboot_button'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon:
                            powerState.phase == ServerPowerPhase.submitting &&
                                powerState.action == ServerPowerAction.reboot
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restart_alt_rounded, size: 13),
                        label: Text(
                          context.l10n.serverReboot,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: isPowerBusy
                            ? null
                            : () => _handleReboot(context, ref, server),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dashboard_shutdown_button'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon:
                            powerState.phase == ServerPowerPhase.submitting &&
                                powerState.action == ServerPowerAction.shutdown
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.power_settings_new, size: 13),
                        label: Text(
                          context.l10n.serverShutdown,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: isPowerBusy
                            ? null
                            : () => _handleShutdown(context, ref, server),
                      ),
                      OutlinedButton.icon(
                        key: const Key('dashboard_disconnect_button'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 13),
                        label: Text(
                          context.l10n.disconnect,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          ref
                              .read(serverConnectionProvider.notifier)
                              .disconnect();
                        },
                      ),
                    ] else if (connState.isConnecting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.link, size: 13),
                        label: Text(
                          context.l10n.connectNow,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _doReconnect(ref),
                      ),
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    serverInfo,
                    const SizedBox(height: 10),
                    actionButtons,
                  ],
                );
              },
            ),

            // Uptime chip placed directly under action buttons without divider
            if (connState.isConnected) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('dashboard_server_uptime'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${context.l10n.metricsUptime}: ${snapshot != null && snapshot.uptimeSeconds > 0 ? MetricsFormatters.formatUptime(snapshot.uptimeSeconds) : '--'}',
                      style: monoTextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (connState.isConnected || connState.isConnecting) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _ServerHardwareSpecsSection(serverId: server.id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, SystemMetricsSnapshot snap) {
    final cpuRatio = snap.cpuUsedRatio.clamp(0.0, 1.0);
    final memRatio = snap.memoryUsedRatio.clamp(0.0, 1.0);
    final diskPct = snap.rootDiskUsedPercent.clamp(0.0, 100.0);

    final primaryIface = snap.primaryNetworkInterface;
    final primaryRate = primaryIface != null
        ? snap.networkRates[primaryIface]
        : null;
    final hasInterfaces = snap.networkCounters.isNotEmpty;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GridView(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: LayoutBreakpoints.gridMetricsMaxExtent,
            mainAxisExtent: 105,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              context,
              key: const Key('dashboard_metric_cpu'),
              entranceIndex: 0,
              title: context.l10n.metricsCpu,
              valueRatio: cpuRatio,
              progress: cpuRatio,
              icon: Icons.speed_rounded,
              progressColor: _getRatioColor(context, cpuRatio),
              subtext: 'Load: ${snap.load1.toStringAsFixed(2)}',
              onTap: () => showMetricTrendModal(context, MetricTrendType.cpu),
            ),
            _buildMetricCard(
              context,
              key: const Key('dashboard_metric_memory'),
              entranceIndex: 1,
              title: context.l10n.metricsMemory,
              valueRatio: memRatio,
              progress: memRatio,
              icon: Icons.memory_rounded,
              progressColor: _getRatioColor(context, memRatio),
              subtext: 'Load5: ${snap.load5.toStringAsFixed(2)}',
              onTap: () =>
                  showMetricTrendModal(context, MetricTrendType.memory),
            ),
            _buildMetricCard(
              context,
              key: const Key('dashboard_metric_disk'),
              entranceIndex: 2,
              title: context.l10n.metricsRootDisk,
              valueRatio: diskPct / 100.0,
              progress: diskPct / 100.0,
              icon: Icons.storage_rounded,
              progressColor: _getRatioColor(context, diskPct / 100.0),
              subtext: 'Path: /',
              onTap: () => showMetricTrendModal(context, MetricTrendType.disk),
            ),
            // Fourth card: Network Rate
            Entrance(
              index: 3,
              child: _buildNetworkCard(
                context,
                primaryRate: primaryRate,
                primaryInterface: primaryIface,
                hasInterfaces: hasInterfaces,
                onTap: () => showNetworkDetailsModal(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    Key? key,
    required int entranceIndex,
    required String title,
    required double valueRatio,
    required double progress,
    required IconData icon,
    required Color progressColor,
    required String subtext,
    VoidCallback? onTap,
  }) {
    final ratio = valueRatio.clamp(0.0, 1.0);
    return Entrance(
      index: entranceIndex,
      child: ValhallaCard(
        key: key,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: progressColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: context.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            CountUp(
              value: ratio * 100,
              formatter: (v) => MetricsFormatters.formatPercentage(v / 100),
              style: monoTextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedProgressBar(
                  value: progress.clamp(0.0, 1.0),
                  color: progressColor,
                  height: 5,
                ),
                const SizedBox(height: 5),
                Text(
                  subtext,
                  style: monoTextStyle(
                    fontSize: 10,
                    color: context.colorScheme.outline,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard(
    BuildContext context, {
    required NetworkRate? primaryRate,
    required String? primaryInterface,
    required bool hasInterfaces,
    required VoidCallback onTap,
  }) {
    final Widget rateWidget;
    if (!hasInterfaces || primaryInterface == null) {
      rateWidget = Text(
        context.l10n.networkUnavailable,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.outline,
        ),
      );
    } else if (primaryRate == null) {
      rateWidget = Text(
        context.l10n.networkWaitingSecondSample,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: context.colorScheme.outline,
        ),
      );
    } else {
      rateWidget = Row(
        children: [
          Icon(Icons.arrow_downward_rounded, size: 14, color: context.vSuccess),
          Text(
            formatNetworkRate(primaryRate.rxBytesPerSecond),
            style: monoTextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_upward_rounded, size: 14, color: context.vInfo),
          Text(
            formatNetworkRate(primaryRate.txBytesPerSecond),
            style: monoTextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final String ifaceLabel = primaryInterface != null
        ? context.l10n.networkInterface(primaryInterface)
        : context.l10n.networkNoDefaultInterface;

    return ValhallaCard(
      key: const Key('dashboard_metric_network'),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.metricsNetwork,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: context.colorScheme.outline,
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: rateWidget,
          ),
          Text(
            ifaceLabel,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: context.colorScheme.outline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getRatioColor(BuildContext context, double ratio) {
    if (ratio > 0.85) return context.vDanger;
    if (ratio > 0.70) return context.vWarning;
    return context.vSuccess;
  }

  Widget _buildQuickShortcuts(BuildContext context, List<AppSection> sections) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: sections.map((section) {
        return ActionChip(
          avatar: Icon(
            appSectionIcon(section),
            size: 16,
            color: context.colorScheme.primary,
          ),
          label: Text(
            localizedAppSectionName(context, section),
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () {
            if (onNavigate != null) {
              onNavigate!(appSectionToViewIndex(section));
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildPowerStatusBanner(
    BuildContext context,
    WidgetRef ref, {
    required String message,
    required bool isWarning,
    required bool showReconnect,
  }) {
    final color = isWarning ? context.vWarning : context.vSuccess;
    final icon = isWarning
        ? Icons.help_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (showReconnect) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(
                context.l10n.serverRebootReconnect,
                style: const TextStyle(fontSize: 11),
              ),
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _doReconnect(ref),
            ),
          ],
        ],
      ),
    );
  }

  void _doReconnect(WidgetRef ref) {
    if (onConnect != null) {
      onConnect!();
    } else {
      ref.read(serverConnectionProvider.notifier).connect();
    }
  }

  Widget _buildDangerExtraContent(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) {
    final terminalCount = ref.read(terminalProvider).activeConnectionCount;
    final agentCount =
        ref.read(aiChatProvider.notifier).activeConnectionCount +
        ref.read(cliChatProvider.notifier).activeConnectionCount;
    final transferCount = ref.read(sftpProvider).pendingTransferCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.serverRebootTarget(
              '${server.username}@${server.host}:${server.port}',
              server.name,
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.serverRebootRunningTerminals(terminalCount)),
          const SizedBox(height: 4),
          Text(context.l10n.serverRebootRunningAgents(agentCount)),
          const SizedBox(height: 4),
          Text(context.l10n.serverRebootRunningTransfers(transferCount)),
        ],
      ),
    );
  }

  Future<void> _handleReboot(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) async {
    final targetServerId = server.id;
    final extraDetails = _buildDangerExtraContent(context, ref, server);

    final confirmed = await DangerConfirmDialog.show(
      context,
      command: 'sudo reboot',
      title: context.l10n.serverRebootDialogTitle,
      description: context.l10n.serverRebootDialogMessage,
      extraContent: extraDetails,
      confirmButtonKey: const Key('reboot_confirm_button'),
      forceShow: true,
    );

    if (confirmed != true || !context.mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(content: Text(context.l10n.serverRebootSubmitting)),
    );

    await ref
        .read(serverPowerProvider.notifier)
        .reboot(expectedServerId: targetServerId);

    if (!context.mounted) return;
    var currentPowerState = ref.read(serverPowerProvider);

    if (currentPowerState.phase == ServerPowerPhase.passwordRequired) {
      final password = await _showPasswordDialog(
        context,
        action: ServerPowerAction.reboot,
      );
      if (password == null || password.isEmpty || !context.mounted) return;

      await ref
          .read(serverPowerProvider.notifier)
          .reboot(expectedServerId: targetServerId, sudoPassword: password);

      if (!context.mounted) return;
      currentPowerState = ref.read(serverPowerProvider);
    }

    _showRebootFeedback(context, ref, currentPowerState, targetServerId);
  }

  Future<void> _handleShutdown(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
  ) async {
    final targetServerId = server.id;
    final extraDetails = _buildDangerExtraContent(context, ref, server);

    final confirmed = await DangerConfirmDialog.show(
      context,
      command: 'sudo poweroff',
      title: context.l10n.serverShutdownDialogTitle,
      description: context.l10n.serverShutdownDialogMessage,
      extraContent: extraDetails,
      confirmButtonKey: const Key('shutdown_confirm_button'),
      forceShow: true,
    );

    if (confirmed != true || !context.mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(content: Text(context.l10n.serverShutdownSubmitting)),
    );

    await ref
        .read(serverPowerProvider.notifier)
        .shutdown(expectedServerId: targetServerId);

    if (!context.mounted) return;
    var currentPowerState = ref.read(serverPowerProvider);

    if (currentPowerState.phase == ServerPowerPhase.passwordRequired) {
      final password = await _showPasswordDialog(
        context,
        action: ServerPowerAction.shutdown,
      );
      if (password == null || password.isEmpty || !context.mounted) return;

      await ref
          .read(serverPowerProvider.notifier)
          .shutdown(expectedServerId: targetServerId, sudoPassword: password);

      if (!context.mounted) return;
      currentPowerState = ref.read(serverPowerProvider);
    }

    _showShutdownFeedback(context, ref, currentPowerState, targetServerId);
  }

  Future<String?> _showPasswordDialog(
    BuildContext context, {
    ServerPowerAction action = ServerPowerAction.reboot,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _PowerPasswordDialog(action: action),
    );
  }

  void _showRebootFeedback(
    BuildContext context,
    WidgetRef ref,
    ServerPowerState powerState,
    String capturedServerId,
  ) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    if (powerState.serverId != null &&
        powerState.serverId != capturedServerId) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(context.l10n.serverRebootServerChanged),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    switch (powerState.phase) {
      case ServerPowerPhase.accepted:
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverRebootAccepted),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: context.l10n.serverRebootReconnect,
              textColor: Colors.white,
              onPressed: () => _doReconnect(ref),
            ),
          ),
        );
        break;

      case ServerPowerPhase.unknown:
        // IMPORTANT: Result is unknown! Must NOT report success or auto-retry!
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverRebootUnknown),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: context.l10n.serverRebootReconnect,
              textColor: Colors.white,
              onPressed: () => _doReconnect(ref),
            ),
          ),
        );
        break;

      case ServerPowerPhase.failed:
        final errorText = powerState.errorCode == 'REBOOT_SERVER_CHANGED'
            ? context.l10n.serverRebootServerChanged
            : context.l10n.cliOperationFailed;
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverRebootFailed(errorText)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        break;

      case ServerPowerPhase.verified:
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverRebootVerified),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        break;

      default:
        break;
    }
  }

  void _showShutdownFeedback(
    BuildContext context,
    WidgetRef ref,
    ServerPowerState powerState,
    String capturedServerId,
  ) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    if (powerState.serverId != null &&
        powerState.serverId != capturedServerId) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(context.l10n.serverShutdownServerChanged),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    switch (powerState.phase) {
      case ServerPowerPhase.accepted:
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverShutdownAccepted),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 8),
          ),
        );
        break;

      case ServerPowerPhase.unknown:
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverShutdownUnknown),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 10),
          ),
        );
        break;

      case ServerPowerPhase.failed:
        final errorText = powerState.errorCode == 'SHUTDOWN_SERVER_CHANGED'
            ? context.l10n.serverShutdownServerChanged
            : context.l10n.cliOperationFailed;
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serverShutdownFailed(errorText)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        break;

      default:
        break;
    }
  }
}

class _PowerPasswordDialog extends StatefulWidget {
  final ServerPowerAction action;

  const _PowerPasswordDialog({this.action = ServerPowerAction.reboot});

  @override
  State<_PowerPasswordDialog> createState() => _PowerPasswordDialogState();
}

class _PowerPasswordDialogState extends State<_PowerPasswordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isShutdown = widget.action == ServerPowerAction.shutdown;
    final title = isShutdown
        ? context.l10n.serverShutdownPasswordTitle
        : context.l10n.serverRebootPasswordTitle;
    final message = isShutdown
        ? context.l10n.serverShutdownPasswordMessage
        : context.l10n.serverRebootPasswordMessage;
    final hint = isShutdown
        ? context.l10n.serverShutdownPasswordHint
        : context.l10n.serverRebootPasswordHint;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: Key(
              isShutdown
                  ? 'shutdown_sudo_password_input'
                  : 'reboot_sudo_password_input',
            ),
            child: KeyedSubtree(
              key: isShutdown
                  ? const Key('reboot_password_field')
                  : const ValueKey('_unused_reboot_field'),
              child: TextField(
                key: Key(
                  isShutdown
                      ? 'shutdown_password_field'
                      : 'reboot_password_field',
                ),
                controller: _controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: hint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key_outlined),
                ),
                onSubmitted: (val) => Navigator.of(context).pop(val),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(context.l10n.cancel),
        ),
        KeyedSubtree(
          key: Key(
            isShutdown
                ? 'shutdown_sudo_password_confirm_button'
                : 'reboot_sudo_password_confirm_button',
          ),
          child: KeyedSubtree(
            key: isShutdown
                ? const Key('reboot_password_confirm_button')
                : const ValueKey('_unused_reboot_button'),
            child: FilledButton(
              key: Key(
                isShutdown
                    ? 'shutdown_password_confirm_button'
                    : 'reboot_password_confirm_button',
              ),
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: Text(context.l10n.confirm),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerHardwareSpecsSection extends ConsumerStatefulWidget {
  final String serverId;

  const _ServerHardwareSpecsSection({required this.serverId});

  @override
  ConsumerState<_ServerHardwareSpecsSection> createState() =>
      _ServerHardwareSpecsSectionState();
}

class _ServerHardwareSpecsSectionState
    extends ConsumerState<_ServerHardwareSpecsSection> {
  // connectionKey-scoped widget cache identity to preserve same-target specs
  // across reconnects while preventing cross-server data leak across dependency changes.
  Object? _cachedConnectionKey;
  SystemHardwareInfo? _cachedHardware;

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final targetConnectionKey = activeServer?.connectionKey;
    final connState = ref.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;
    final isReconnecting = connState.isConnecting;

    if (activeServer?.id != widget.serverId || targetConnectionKey == null) {
      return const SizedBox.shrink();
    }

    final hardwareAsync = ref.watch(systemHardwareProvider);

    // Accept fresh AsyncData only
    if (hardwareAsync is AsyncData<SystemHardwareInfo>) {
      _cachedConnectionKey = targetConnectionKey;
      _cachedHardware = hardwareAsync.value;
    }

    // Cached same-target value during loading/error/reconnecting
    final hasSameTargetCache =
        _cachedConnectionKey == targetConnectionKey && _cachedHardware != null;

    if (!isConnected && !isReconnecting && !hasSameTargetCache) {
      return const SizedBox.shrink();
    }

    if (hasSameTargetCache &&
        (hardwareAsync.isLoading ||
            hardwareAsync.hasError ||
            !isConnected ||
            isReconnecting)) {
      return _buildSpecs(context, _cachedHardware!);
    }

    return hardwareAsync.when(
      data: (info) => _buildSpecs(context, info),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          key: const Key('dashboard_hardware_loading'),
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.hardwareLoading,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          key: const Key('dashboard_hardware_error'),
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.hardwareUnavailable,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecs(BuildContext context, SystemHardwareInfo info) {
    String cpuText;
    if (info.cpuModel != null && info.cpuCores != null) {
      cpuText =
          '${info.cpuModel} (${context.l10n.hardwareCpuCores(info.cpuCores!)})';
    } else if (info.cpuModel != null) {
      cpuText = info.cpuModel!;
    } else if (info.cpuCores != null) {
      cpuText = context.l10n.hardwareCpuCores(info.cpuCores!);
    } else {
      cpuText = context.l10n.hardwareUnknown;
    }

    final memText = info.memoryTotalKiB != null
        ? formatKiB(info.memoryTotalKiB!)
        : context.l10n.hardwareUnknown;

    final diskText = info.rootDiskTotalKiB != null
        ? formatKiB(info.rootDiskTotalKiB!)
        : context.l10n.hardwareUnknown;

    final osText = info.distribution ?? context.l10n.hardwareUnknown;
    final kernelText = info.kernel ?? context.l10n.hardwareUnknown;

    return Column(
      key: const Key('dashboard_hardware_specs_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.memory_rounded,
              size: 14,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.hardwareSpecsTitle,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSpecItem(
          context,
          key: const Key('dashboard_hardware_cpu'),
          icon: Icons.developer_board,
          label: context.l10n.hardwareCpu,
          value: cpuText,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSpecItem(
                context,
                key: const Key('dashboard_hardware_memory'),
                icon: Icons.memory,
                label: context.l10n.hardwareMemory,
                value: memText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecItem(
                context,
                key: const Key('dashboard_hardware_disk'),
                icon: Icons.storage_rounded,
                label: context.l10n.hardwareDisk,
                value: diskText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSpecItem(
                context,
                key: const Key('dashboard_hardware_distribution'),
                icon: Icons.desktop_windows_outlined,
                label: context.l10n.hardwareDistribution,
                value: osText,
                tapKey: const Key('dashboard_hardware_os_tappable'),
                tooltip: context.l10n.systemInfoTapHint,
                trailing: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  final server = ref.read(activeServerProvider);
                  showNeofetchSheet(
                    context,
                    hardware: info,
                    serverName: server?.name ?? '',
                    userHost: server == null
                        ? ''
                        : '${server.username}@${server.host}',
                    metrics:
                        ref.read(systemMetricsStreamProvider).asData?.value ??
                        ref.read(systemMetricsHistoryProvider).lastOrNull,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecItem(
                context,
                key: const Key('dashboard_hardware_kernel'),
                icon: Icons.terminal_rounded,
                label: context.l10n.hardwareKernel,
                value: kernelText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecItem(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    Key? tapKey,
    VoidCallback? onTap,
    String? tooltip,
    Widget? trailing,
  }) {
    final content = Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: context.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (trailing != null) ...[const Spacer(), trailing],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: monoTextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
    if (onTap == null) return content;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(VRadius.input),
        child: content,
      ),
    );
  }
}
