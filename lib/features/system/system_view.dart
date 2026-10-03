import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/server_provider.dart';
import '../../infrastructure/system/process_service.dart';
import '../../infrastructure/system/service_manager.dart';
import '../../widgets/danger_confirm_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/valhalla_card.dart';
import 'system_provider.dart';

class SystemView extends ConsumerStatefulWidget {
  const SystemView({super.key});

  @override
  ConsumerState<SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends ConsumerState<SystemView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _procSearchCtrl = TextEditingController();
  final TextEditingController _svcSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _procSearchCtrl.dispose();
    _svcSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTerminateProcess(
    ProcessInfo proc, {
    required bool force,
  }) async {
    if (proc.pid <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.processKillForbidden),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }

    final cmd = 'kill ${force ? '-9' : '-15'} ${proc.pid}';
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: cmd,
      title: force
          ? context.l10n.riskDangerTitle
          : context.l10n.riskWarningTitle,
    );

    if (!confirmed || !mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(systemProvider.notifier)
          .terminateProcess(proc.pid, force: force);
      if (!mounted) return;
      if (res.isSuccess) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.processTerminateSuccess(proc.pid)),
            backgroundColor: context.vSuccess,
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(res.stderr.trim().isEmpty ? 'Failed' : res.stderr),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: context.vDanger),
      );
    }
  }

  Future<void> _handleServiceAction(
    SystemdServiceInfo svc,
    String action,
  ) async {
    final cmd = 'systemctl $action ${svc.name}';
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: cmd,
      title: (action == 'stop' || action == 'disable')
          ? context.l10n.riskDangerTitle
          : context.l10n.riskWarningTitle,
    );

    if (!confirmed || !mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(systemProvider.notifier)
          .performServiceAction(svc.name, action);
      if (!mounted) return;
      if (res.isSuccess) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serviceActionSuccess(action, svc.name)),
            backgroundColor: context.vSuccess,
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              res.stderr.trim().isEmpty ? 'Action failed' : res.stderr,
            ),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: context.vDanger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    if (activeServer == null) {
      return Scaffold(
        body: EmptyStateView(
          icon: Icons.dns_outlined,
          title: context.l10n.noServerSelected,
          description: context.l10n.addServer,
        ),
      );
    }

    final sysState = ref.watch(systemProvider);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: context.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.memory, size: 20),
                        text: context.l10n.tabProcesses,
                      ),
                      Tab(
                        icon: const Icon(
                          Icons.miscellaneous_services,
                          size: 20,
                        ),
                        text: context.l10n.tabServices,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: context.l10n.sftpRefresh,
                  onPressed:
                      (!ref.watch(
                            serverConnectionProvider.select(
                              (s) => s.isConnected,
                            ),
                          ) ||
                          sysState.isProcessesLoading ||
                          sysState.isServicesLoading)
                      ? null
                      : () => ref.read(systemProvider.notifier).refreshAll(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProcessesTab(context, sysState),
                _buildServicesTab(context, sysState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessesTab(BuildContext context, SystemState sysState) {
    return Column(
      children: [
        Entrance(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _procSearchCtrl,
              decoration: InputDecoration(
                hintText: context.l10n.processSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _procSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _procSearchCtrl.clear();
                          ref
                              .read(systemProvider.notifier)
                              .setProcessSearch('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
              ),
              onChanged: (val) {
                ref.read(systemProvider.notifier).setProcessSearch(val);
                setState(() {});
              },
            ),
          ),
        ),
        Expanded(child: _buildProcessContent(context, sysState)),
      ],
    );
  }

  Widget _buildProcessContent(BuildContext context, SystemState sysState) {
    if (sysState.isProcessesLoading && sysState.processes.isEmpty) {
      return const LoadingStateView();
    }

    if (sysState.processError != null && sysState.processes.isEmpty) {
      return ErrorStateView(
        message: sysState.processError,
        onRetry: () => ref.read(systemProvider.notifier).refreshProcesses(),
      );
    }

    final list = sysState.filteredProcesses;
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.memory_outlined,
        title: context.l10n.stateEmpty,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(systemProvider.notifier).refreshProcesses(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          final proc = list[index];
          final isHighCpu = proc.cpuPercent > 40.0;
          final isHighMem = proc.memoryPercent > 40.0;

          return ValhallaCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    proc.pid.toString(),
                    style: monoTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proc.command,
                        style: monoTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CountUp(
                            value: proc.cpuPercent,
                            formatter: (v) => 'CPU: ${v.toStringAsFixed(1)}%',
                            style: monoTextStyle(
                              fontSize: 11,
                              color: isHighCpu
                                  ? context.vDanger
                                  : context.colorScheme.outline,
                              fontWeight: isHighCpu
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 12),
                          CountUp(
                            value: proc.memoryPercent,
                            formatter: (v) => 'MEM: ${v.toStringAsFixed(1)}%',
                            style: monoTextStyle(
                              fontSize: 11,
                              color: isHighMem
                                  ? context.vWarning
                                  : context.colorScheme.outline,
                              fontWeight: isHighMem
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'STAT: ${proc.state}',
                            style: monoTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedProgressBar(
                        value: (proc.cpuPercent / 100).clamp(0.0, 1.0),
                        color: isHighCpu
                            ? context.vDanger
                            : context.colorScheme.primary,
                        height: 4,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: ref.watch(
                    serverConnectionProvider.select((s) => s.isConnected),
                  ),
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'term') {
                      _handleTerminateProcess(proc, force: false);
                    } else if (action == 'kill') {
                      _handleTerminateProcess(proc, force: true);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'term',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: context.vWarning,
                          ),
                          const SizedBox(width: 8),
                          Text(context.l10n.processTerminate),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'kill',
                      child: Row(
                        children: [
                          Icon(
                            Icons.dangerous_outlined,
                            size: 18,
                            color: context.vDanger,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.processForceKill,
                            style: TextStyle(color: context.vDanger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesTab(BuildContext context, SystemState sysState) {
    return Column(
      children: [
        Entrance(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _svcSearchCtrl,
              decoration: InputDecoration(
                hintText: context.l10n.serviceSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _svcSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _svcSearchCtrl.clear();
                          ref
                              .read(systemProvider.notifier)
                              .setServiceSearch('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
              ),
              onChanged: (val) {
                ref.read(systemProvider.notifier).setServiceSearch(val);
                setState(() {});
              },
            ),
          ),
        ),
        Entrance(
          index: 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(context.l10n.dockerFilterAll),
                  selected: sysState.serviceFilterState == null,
                  onSelected: (_) =>
                      ref.read(systemProvider.notifier).setServiceFilter(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.dockerFilterRunning),
                  selected: sysState.serviceFilterState == 'running',
                  onSelected: (val) => ref
                      .read(systemProvider.notifier)
                      .setServiceFilter(val ? 'running' : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Failed'),
                  selected: sysState.serviceFilterState == 'failed',
                  onSelected: (val) => ref
                      .read(systemProvider.notifier)
                      .setServiceFilter(val ? 'failed' : null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildServiceContent(context, sysState)),
      ],
    );
  }

  Widget _buildServiceContent(BuildContext context, SystemState sysState) {
    if (sysState.isServicesLoading && sysState.services.isEmpty) {
      return const LoadingStateView();
    }

    if (sysState.serviceError != null && sysState.services.isEmpty) {
      return ErrorStateView(
        message: sysState.serviceError,
        onRetry: () => ref.read(systemProvider.notifier).refreshServices(),
      );
    }

    final list = sysState.filteredServices;
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.miscellaneous_services_outlined,
        title: context.l10n.serviceNoServices,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(systemProvider.notifier).refreshServices(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          final svc = list[index];
          final isConnected = ref.watch(
            serverConnectionProvider.select((s) => s.isConnected),
          );
          StatusType statusType;
          if (svc.isRunning) {
            statusType = StatusType.online;
          } else if (svc.isFailed) {
            statusType = StatusType.danger;
          } else {
            statusType = StatusType.offline;
          }

          return ValhallaCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        svc.name,
                        style: monoTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(
                      label: svc.state.toUpperCase(),
                      type: statusType,
                    ),
                  ],
                ),
                if (svc.description.isNotEmpty &&
                    svc.description != svc.name) ...[
                  const SizedBox(height: 4),
                  Text(
                    svc.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!svc.isRunning)
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: context.vSuccess,
                        ),
                        tooltip: context.l10n.serviceActionStart,
                        onPressed: isConnected
                            ? () => _handleServiceAction(svc, 'start')
                            : null,
                      )
                    else ...[
                      IconButton(
                        icon: Icon(
                          Icons.stop_rounded,
                          size: 20,
                          color: context.vWarning,
                        ),
                        tooltip: context.l10n.serviceActionStop,
                        onPressed: isConnected
                            ? () => _handleServiceAction(svc, 'stop')
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.replay_rounded,
                          size: 18,
                          color: context.vInfo,
                        ),
                        tooltip: context.l10n.serviceActionRestart,
                        onPressed: isConnected
                            ? () => _handleServiceAction(svc, 'restart')
                            : null,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: context.l10n.serviceActionReload,
                      onPressed: isConnected
                          ? () => _handleServiceAction(svc, 'reload')
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
