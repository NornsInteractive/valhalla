import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    if (ref.read(systemProvider).cachedAt != null ||
        !ref.read(serverConnectionProvider).isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }

    final server = ref.read(activeServerProvider);
    if (server == null) return;
    final connectionKey = server.connectionKey;
    final expectedStartedAt = proc.startedAt;

    final cmd = 'kill ${force ? '-9' : '-15'} ${proc.pid}';
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: cmd,
      title: force
          ? context.l10n.riskDangerTitle
          : context.l10n.riskWarningTitle,
    );

    if (!confirmed || !mounted) return;
    if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(systemProvider.notifier)
          .terminateProcess(
            proc.pid,
            force: force,
            expectedStartedAt: expectedStartedAt,
            expectedConnectionKey: connectionKey,
          );
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
        return;
      }
      if (res.isSuccess) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.processTerminateSuccess(proc.pid)),
            backgroundColor: context.vSuccess,
          ),
        );
      } else {
        final err = res.stderr.trim();
        final mapped = _mapSystemError(context, err);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              mapped.isNotEmpty && mapped != err
                  ? mapped
                  : (err.isEmpty ? context.l10n.cmdExecutionFailed : err),
            ),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(_mapSystemError(context, e)),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  Future<void> _handleServiceAction(
    SystemdServiceInfo svc,
    String action,
  ) async {
    if (ref.read(systemProvider).cachedAt != null ||
        !ref.read(serverConnectionProvider).isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }

    final server = ref.read(activeServerProvider);
    if (server == null) return;
    final connectionKey = server.connectionKey;

    final cmd = 'systemctl $action ${svc.name}';
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: cmd,
      title: (action == 'stop' || action == 'disable')
          ? context.l10n.riskDangerTitle
          : context.l10n.riskWarningTitle,
    );

    if (!confirmed || !mounted) return;
    if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    try {
      final res = await ref
          .read(systemProvider.notifier)
          .performServiceAction(
            svc.name,
            action,
            expectedConnectionKey: connectionKey,
          );
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
        return;
      }
      if (res.isSuccess) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.serviceActionSuccess(action, svc.name)),
            backgroundColor: context.vSuccess,
          ),
        );
      } else {
        final err = res.stderr.trim();
        final mapped = _mapSystemError(context, err);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              mapped.isNotEmpty && mapped != err
                  ? mapped
                  : (err.isEmpty ? context.l10n.cmdExecutionFailed : err),
            ),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connectionKey) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(_mapSystemError(context, e)),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  Widget _buildCachedBanner(BuildContext context, DateTime cachedAt) {
    final timeStr =
        '${cachedAt.hour.toString().padLeft(2, '0')}:${cachedAt.minute.toString().padLeft(2, '0')}:${cachedAt.second.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      color: context.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.cachedDataNotice(timeStr),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
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
          if (sysState.cachedAt != null)
            _buildCachedBanner(context, sysState.cachedAt!),
          Container(
            color: context.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: !context.isDesktop,
                    tabAlignment: !context.isDesktop
                        ? TabAlignment.start
                        : TabAlignment.fill,
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
                  enabled:
                      ref.watch(
                        serverConnectionProvider.select((s) => s.isConnected),
                      ) &&
                      sysState.cachedAt == null,
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
          final isPending = sysState.pendingActions.containsKey(svc.name);
          final pendingAction = sysState.pendingActions[svc.name];
          final canMutate =
              isConnected && !isPending && sysState.cachedAt == null;
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final badgeGroup = Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (svc.startup.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  context.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: context.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              svc.startup.toUpperCase(),
                              style: monoTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        StatusBadge(
                          label: svc.state.toUpperCase(),
                          type: statusType,
                        ),
                      ],
                    );

                    return SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Text(
                              svc.name,
                              style: monoTextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          badgeGroup,
                        ],
                      ),
                    );
                  },
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
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (isPending) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pendingAction?.toUpperCase() ?? '',
                            style: monoTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.article_outlined, size: 18),
                      tooltip: context.l10n.serviceLogsTitle,
                      onPressed:
                          isConnected && !isPending && sysState.cachedAt == null
                          ? () => _showServiceLogsDialog(context, svc)
                          : null,
                    ),
                    if (!svc.isRunning)
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: context.vSuccess,
                        ),
                        tooltip: context.l10n.serviceActionStart,
                        onPressed: canMutate
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
                        onPressed: canMutate
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
                        onPressed: canMutate
                            ? () => _handleServiceAction(svc, 'restart')
                            : null,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: context.l10n.serviceActionReload,
                      onPressed: canMutate
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

  void _showServiceLogsDialog(BuildContext context, SystemdServiceInfo svc) {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceLogsDialog(service: svc),
    );
  }
}

class _ServiceLogsDialog extends ConsumerStatefulWidget {
  final SystemdServiceInfo service;

  const _ServiceLogsDialog({required this.service});

  @override
  ConsumerState<_ServiceLogsDialog> createState() => _ServiceLogsDialogState();
}

class _ServiceLogsDialogState extends ConsumerState<_ServiceLogsDialog> {
  Object? _capturedConnectionKey;
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlderLogs = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _capturedConnectionKey = ref.read(activeServerProvider)?.connectionKey;
    _fetchLogs(refresh: true);
  }

  Future<void> _fetchLogs({bool refresh = false}) async {
    if (_isLoading || _isLoadingOlder) return;
    if (!refresh && (!_hasMoreOlderLogs || _logs.length >= 1000)) return;
    final connKey = _capturedConnectionKey;
    if (connKey == null) return;
    if (ref.read(activeServerProvider)?.connectionKey != connKey) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      if (refresh) {
        _isLoading = true;
        _errorMessage = null;
        _hasMoreOlderLogs = true;
      } else {
        _isLoadingOlder = true;
        _errorMessage = null;
      }
    });

    try {
      final beforeCursor = refresh
          ? null
          : (_logs.isNotEmpty ? _logs.last['__CURSOR'] as String? : null);
      final newRecords = await ref
          .read(systemProvider.notifier)
          .serviceLogs(
            widget.service.name,
            beforeCursor: beforeCursor,
            expectedConnectionKey: connKey,
          );

      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connKey) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _isLoading = false;
        _isLoadingOlder = false;
        if (newRecords.length < 200) {
          _hasMoreOlderLogs = false;
        }
        if (refresh) {
          _logs.clear();
          _logs.addAll(newRecords);
        } else {
          _logs.addAll(newRecords);
        }
        if (_logs.length >= 1000) {
          if (_logs.length > 1000) {
            _logs.removeRange(1000, _logs.length);
          }
          _hasMoreOlderLogs = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != connKey) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingOlder = false;
        _errorMessage = _mapSystemError(context, e);
      });
    }
  }

  void _copyLogs() {
    if (_logs.isEmpty) return;
    final text = _logs
        .map((row) {
          final ts = _formatTimestamp(row);
          final prio = row['PRIORITY']?.toString() ?? '';
          final msg = row['MESSAGE']?.toString() ?? '';
          return '$ts [$prio] $msg';
        })
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.serviceLogsCopied)));
  }

  String _formatTimestamp(Map<String, dynamic> row) {
    final raw =
        row['__REALTIME_TIMESTAMP'] ?? row['_SOURCE_REALTIME_TIMESTAMP'];
    if (raw != null) {
      final micros = int.tryParse(raw.toString());
      if (micros != null) {
        final dt = DateTime.fromMicrosecondsSinceEpoch(micros);
        return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} '
            '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}';
      }
    }
    return '';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.service.name} ${context.l10n.serviceLogsTitle}',
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: context.l10n.serviceLogsCopied,
            onPressed: _logs.isEmpty ? null : _copyLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: context.l10n.sftpRefresh,
            onPressed: (_isLoading || _isLoadingOlder)
                ? null
                : () => _fetchLogs(refresh: true),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildContent(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _fetchLogs(refresh: true),
              child: Text(context.l10n.sftpRefresh),
            ),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(child: Text(context.l10n.serviceLogsEmpty));
    }

    Widget? errorBanner;
    if (_errorMessage != null && _logs.isNotEmpty) {
      errorBanner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: (_isLoading || _isLoadingOlder)
                  ? null
                  : () => _fetchLogs(refresh: true),
              child: Text(context.l10n.sftpRefresh),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      );
    }

    final listView = ListView.builder(
      itemCount: _logs.length + 1,
      itemBuilder: (ctx, index) {
        if (index == _logs.length) {
          if (_logs.length >= 1000) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  context.l10n.serviceLogsCapReached,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            );
          }
          if (!_hasMoreOlderLogs) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _isLoadingOlder
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: Text(context.l10n.serviceLogsLoadOlder),
                      onPressed: () => _fetchLogs(refresh: false),
                    ),
            ),
          );
        }

        final row = _logs[index];
        final ts = _formatTimestamp(row);
        final prio = row['PRIORITY']?.toString();
        final msg = row['MESSAGE']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (ts.isNotEmpty)
                    Text(
                      ts,
                      style: monoTextStyle(
                        fontSize: 11,
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                    ),
                  if (prio != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        prio,
                        style: monoTextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              SelectableText(msg, style: monoTextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );

    if (errorBanner != null || (_isLoading && _logs.isNotEmpty)) {
      return Column(
        children: [
          if (_isLoading && _logs.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          ?errorBanner,
          Expanded(child: listView),
        ],
      );
    }

    return listView;
  }
}

String _mapSystemError(BuildContext context, Object e) {
  final str = e.toString();
  if (str.contains('SERVICE_PERMISSION_DENIED')) {
    return context.l10n.servicePermissionDenied;
  }
  if (str.contains('SERVICE_UNSUPPORTED')) {
    return context.l10n.serviceUnsupported;
  }
  if (str.contains('SERVICE_QUERY_FAILED')) {
    return context.l10n.serviceQueryFailed;
  }
  if (str.contains('SERVICE_TARGET_CHANGED')) {
    return context.l10n.serviceTargetChanged;
  }
  if (str.contains('SERVICE_ACTION_IN_PROGRESS')) {
    return context.l10n.serviceActionInProgress;
  }
  if (str.contains('PROCESS_IDENTITY_CHANGED')) {
    return context.l10n.processIdentityChanged;
  }
  if (str.contains('PROCESS_IDENTITY_UNAVAILABLE')) {
    return context.l10n.processIdentityUnavailable;
  }
  return str;
}
