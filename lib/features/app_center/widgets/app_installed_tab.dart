import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import '../../../widgets/valhalla_card.dart';
import 'app_access_info_dialog.dart';
import 'app_cached_image.dart';
import 'app_center_error_resolver.dart';
import 'app_logs_dialog.dart';
import 'app_operation_wizard_dialog.dart';
import 'app_task_details_dialog.dart';
import 'app_uninstall_dialog.dart';

class AppInstalledTab extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateToTab;

  const AppInstalledTab({super.key, this.onNavigateToTab});

  @override
  ConsumerState<AppInstalledTab> createState() => _AppInstalledTabState();
}

class _AppInstalledTabState extends ConsumerState<AppInstalledTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _operatingDeploymentIds = {};
  Object? _lastServerKey;

  @override
  bool get wantKeepAlive => true;

  Future<void> _handlePowerAction(
    ApplicationDeployment deployment,
    ApplicationOperation op,
  ) async {
    if (_operatingDeploymentIds.contains(deployment.id)) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    setState(() => _operatingDeploymentIds.add(deployment.id));
    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final plan = await notifier.prepare(op, deployment: deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      await notifier.execute(plan);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
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
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() => _operatingDeploymentIds.remove(deployment.id));
      }
    }
  }

  Future<void> _handleStopWithConfirmation(
    ApplicationDeployment deployment,
  ) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final serverName =
        ref.read(activeServerProvider)?.name ?? deployment.serverId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.appCenterStopConfirmTitleLabel(deployment.name)),
        content: Text(
          ctx.appCenterStopConfirmMessageLabel(deployment.name, serverName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.vDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.appCenterStop),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        mounted &&
        ref.read(activeServerProvider)?.connectionKey == capturedKey) {
      await _handlePowerAction(deployment, ApplicationOperation.stop);
    }
  }

  Future<void> _handleRestartWithConfirmation(
    ApplicationDeployment deployment,
  ) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final serverName =
        ref.read(activeServerProvider)?.name ?? deployment.serverId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.appCenterRestartConfirmTitleLabel(deployment.name)),
        content: Text(
          ctx.appCenterRestartConfirmMessageLabel(deployment.name, serverName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.appCenterRestart),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        mounted &&
        ref.read(activeServerProvider)?.connectionKey == capturedKey) {
      await _handlePowerAction(deployment, ApplicationOperation.restart);
    }
  }

  Future<void> _handleOpenApp(ApplicationDeployment deployment) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final notifier = ref.read(applicationCenterProvider.notifier);
    try {
      await notifier.openApplication(deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
    } on ApplicationCenterException catch (e) {
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      if (e.code == 'APP_CENTER_HTTPS_DIRECT_REQUIRED') {
        _showDirectUrlDialog(deployment);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolveAppCenterErrorMessage(context, e.code, e.detail),
            ),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  Future<void> _showDirectUrlDialog(ApplicationDeployment deployment) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final serverHost = ref.read(activeServerProvider)?.host;
    final ep = deployment.endpoint;
    String initialUrl = 'http://';
    if (ep != null) {
      final host = (serverHost != null && serverHost.isNotEmpty)
          ? serverHost
          : ep.host;
      initialUrl = ep.replace(host: host).toString();
    } else if (serverHost != null && serverHost.isNotEmpty) {
      initialUrl = 'http://$serverHost';
    }

    final ctrl = TextEditingController(text: initialUrl);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.appCenterDirectUrlLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.appCenterErrorHttpsDirectRequired,
              style: ctx.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.appCenterDirectUrlLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        mounted &&
        ref.read(activeServerProvider)?.connectionKey == capturedKey) {
      final notifier = ref.read(applicationCenterProvider.notifier);
      try {
        await notifier.openApplication(deployment, directUrl: ctrl.text.trim());
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
      }
    }
  }

  Future<void> _handleConfigure(ApplicationDeployment deployment) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final config = await notifier.configuration(deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      final template = await notifier.installedTemplate(deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        AppOperationWizardDialog.show(
          context,
          operation: ApplicationOperation.configure,
          deployment: deployment,
          initialConfiguration: config,
          initialTemplate: template,
          onNavigateToTab: widget.onNavigateToTab,
        );
      }
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
    }
  }

  Future<void> _handleUpdate(ApplicationDeployment deployment) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final notifier = ref.read(applicationCenterProvider.notifier);
    final catalogEntry = notifier.catalogEntry(deployment);
    if (catalogEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorSourceRemoved),
          backgroundColor: context.vWarning,
        ),
      );
      return;
    }

    try {
      final config = await notifier.configuration(deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      final template = await notifier.loadTemplate(catalogEntry);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        AppOperationWizardDialog.show(
          context,
          operation: ApplicationOperation.update,
          catalogApp: catalogEntry,
          deployment: deployment,
          initialConfiguration: config,
          initialTemplate: template,
          onNavigateToTab: widget.onNavigateToTab,
        );
      }
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
    }
  }

  Future<void> _handleRestore(ApplicationDeployment deployment) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.appCenterRestoreConfirmTitle(deployment.name)),
        content: Text(ctx.l10n.appCenterRestoreConfirmMessage(deployment.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        ref.read(activeServerProvider)?.connectionKey == capturedKey) {
      await _handlePowerAction(deployment, ApplicationOperation.restore);
    }
  }

  Future<void> _handleUninstall(ApplicationDeployment deployment) async {
    if (_operatingDeploymentIds.contains(deployment.id)) return;
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    setState(() => _operatingDeploymentIds.add(deployment.id));
    try {
      final task = await AppUninstallDialog.show(
        context,
        deployment: deployment,
      );
      if (task != null &&
          mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey &&
          ref.read(serverConnectionProvider).isConnected) {
        await AppTaskDetailsDialog.show(
          context,
          taskId: task.id,
          initialTask: task,
          onNavigateToTab: widget.onNavigateToTab,
        );
      }
    } finally {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() => _operatingDeploymentIds.remove(deployment.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final deployments = state.deployments;
    final activeServer = ref.watch(activeServerProvider);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    // Reset spinner tracking if server connection changed
    final currentServerKey = activeServer?.connectionKey;
    if (_lastServerKey != currentServerKey) {
      _lastServerKey = currentServerKey;
      _operatingDeploymentIds.clear();
    }

    if (deployments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: context.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.appCenterNoInstalled,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < LayoutBreakpoints.compactMax;

        if (isCompact) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: deployments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) =>
                _buildCard(deployments[idx], state, isConnected),
          );
        }

        // Adaptive column layout without fixed height clipping
        final columns = (constraints.maxWidth / 380).floor().clamp(1, 4);
        if (columns == 1) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: deployments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) =>
                _buildCard(deployments[idx], state, isConnected),
          );
        }

        final columnLists = List.generate(
          columns,
          (_) => <ApplicationDeployment>[],
        );
        for (var i = 0; i < deployments.length; i++) {
          columnLists[i % columns].add(deployments[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      for (final deployment in columnLists[c]) ...[
                        _buildCard(deployment, state, isConnected),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    ApplicationDeployment deployment,
    ApplicationCenterState state,
    bool isConnected,
  ) {
    final l10n = context.l10n;
    final catalogApp = ref
        .read(applicationCenterProvider.notifier)
        .catalogEntry(deployment);
    final hasUpdate = ref
        .read(applicationCenterProvider.notifier)
        .hasUpdate(deployment);

    final hasActiveTask = state.tasks.any(
      (t) =>
          t.deploymentId == deployment.id &&
          (t.isBusy || t.stage == ApplicationTaskStage.needsInspection),
    );

    final isBusy =
        state.busy ||
        _operatingDeploymentIds.contains(deployment.id) ||
        hasActiveTask;

    final canOperate = isConnected && !isBusy;
    final isRunning = deployment.status == 'running';
    final statusColor = switch (deployment.status) {
      'running' => context.vSuccess,
      'stopped' => context.colorScheme.outline,
      'installing' => context.colorScheme.primary,
      _ => context.vWarning,
    };

    final sourceName =
        state.sources
            .where((s) => s.id == deployment.sourceId)
            .firstOrNull
            ?.name ??
        deployment.sourceId;

    final versionStr = deployment.version.isNotEmpty
        ? 'v${deployment.version}'
        : l10n.appCenterVersionLatest;

    final statusLabel = resolveDeploymentStatusLabel(
      context,
      deployment.status,
    );

    return ValhallaCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: catalogApp != null && catalogApp.iconUrl.isNotEmpty
                        ? AppCachedImage(
                            url: catalogApp.iconUrl,
                            revision: catalogApp.contentHash,
                            sourceId: catalogApp.sourceId,
                            fit: BoxFit.cover,
                            errorWidget: const Icon(Icons.apps, size: 28),
                          )
                        : const Icon(Icons.apps, size: 28),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              deployment.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$sourceName · $versionStr · $statusLabel',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasUpdate)
                  Tooltip(
                    message: l10n.appCenterUpdateAvailable,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
                      onPressed: !canOperate
                          ? null
                          : () => _handleUpdate(deployment),
                    ),
                  ),
                PopupMenuButton<String>(
                  enabled: canOperate,
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'accessInfo',
                      child: Text(context.appCenterAccessInfoLabel),
                    ),
                    PopupMenuItem(
                      value: 'directUrl',
                      child: Text(l10n.appCenterDirectUrlLabel),
                    ),
                    PopupMenuItem(
                      value: 'logs',
                      child: Text(l10n.appCenterLogs),
                    ),
                    PopupMenuItem(
                      value: 'config',
                      child: Text(l10n.appCenterConfig),
                    ),
                    PopupMenuItem(
                      value: 'restore',
                      child: Text(l10n.appCenterRestore),
                    ),
                    PopupMenuItem(
                      value: 'uninstall',
                      child: Text(
                        l10n.appCenterUninstall,
                        style: TextStyle(color: context.vDanger),
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'accessInfo') {
                      AppAccessInfoDialog.show(context, deployment: deployment);
                    } else if (val == 'directUrl') {
                      _showDirectUrlDialog(deployment);
                    } else if (val == 'logs') {
                      AppLogsDialog.show(context, deployment: deployment);
                    } else if (val == 'config') {
                      _handleConfigure(deployment);
                    } else if (val == 'restore') {
                      _handleRestore(deployment);
                    } else if (val == 'uninstall') {
                      _handleUninstall(deployment);
                    }
                  },
                ),
              ],
            ),
            if (deployment.services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final service in deployment.services)
                    _buildServiceBadge(context, service),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (deployment.endpoint != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.launch, size: 14),
                    label: Text(l10n.appCenterOpen),
                    onPressed: !canOperate
                        ? null
                        : () => _handleOpenApp(deployment),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  tooltip: isRunning ? l10n.appCenterStop : l10n.appCenterStart,
                  onPressed: !canOperate
                      ? null
                      : () => isRunning
                            ? _handleStopWithConfirmation(deployment)
                            : _handlePowerAction(
                                deployment,
                                ApplicationOperation.start,
                              ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: l10n.appCenterRestart,
                  onPressed: !canOperate
                      ? null
                      : () => _handleRestartWithConfirmation(deployment),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceBadge(
    BuildContext context,
    ApplicationServiceHealth service,
  ) {
    final theme = Theme.of(context);
    final hasHealth = service.health.isNotEmpty && service.health != 'none';

    final Color badgeColor;
    final IconData badgeIcon;
    final String statusLabel;

    if (hasHealth) {
      final localizedHealth = resolveServiceHealthLabel(
        context,
        service.health,
      );
      switch (service.health) {
        case 'healthy':
          badgeColor = context.vSuccess;
          badgeIcon = Icons.check_circle_outline;
          statusLabel = '${service.state} · $localizedHealth';
          break;
        case 'unhealthy':
          badgeColor = context.vDanger;
          badgeIcon = Icons.error_outline;
          statusLabel = '${service.state} · $localizedHealth';
          break;
        case 'starting':
          badgeColor = context.vWarning;
          badgeIcon = Icons.timelapse;
          statusLabel = '${service.state} · $localizedHealth';
          break;
        default:
          badgeColor = context.vWarning;
          badgeIcon = Icons.info_outline;
          statusLabel = '${service.state} · $localizedHealth';
          break;
      }
    } else {
      final isRunning = service.state == 'running';
      badgeColor = isRunning ? context.vSuccess : theme.colorScheme.outline;
      badgeIcon = isRunning ? Icons.circle : Icons.circle_outlined;
      statusLabel = service.state;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.pill),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 10, color: badgeColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${service.name}: $statusLabel',
              style: monoTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
