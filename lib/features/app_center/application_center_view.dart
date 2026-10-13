import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/application_center_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../data/models/application_center.dart';
import 'widgets/app_center_error_resolver.dart';
import 'widgets/app_installed_tab.dart';
import 'widgets/app_operation_wizard_dialog.dart';
import 'widgets/app_sources_dialog.dart';
import 'widgets/app_store_tab.dart';
import 'widgets/app_tasks_tab.dart';

class ApplicationCenterView extends ConsumerStatefulWidget {
  const ApplicationCenterView({super.key});

  @override
  ConsumerState<ApplicationCenterView> createState() =>
      _ApplicationCenterViewState();
}

class _ApplicationCenterViewState extends ConsumerState<ApplicationCenterView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (!mounted) return;
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final notifier = ref.read(applicationCenterProvider.notifier);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );

    final busyTasksCount = state.tasks.where((t) => t.isBusy).length;

    return Scaffold(
      body: Column(
        children: [
          // Sub-header with TabBar and action buttons
          Container(
            color: context.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: l10n.appCenterTabStore),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.appCenterTabInstalled),
                            if (state.deployments.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Badge.count(
                                count: state.deployments.length,
                                backgroundColor:
                                    context.colorScheme.primaryContainer,
                                textColor:
                                    context.colorScheme.onPrimaryContainer,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.appCenterTabTasks),
                            if (busyTasksCount > 0) ...[
                              const SizedBox(width: 6),
                              Badge.count(
                                count: busyTasksCount,
                                backgroundColor: context.vWarning,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.source_outlined, size: 20),
                  tooltip: l10n.appCenterManageSources,
                  onPressed: () => AppSourcesDialog.show(context),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: l10n.appCenterRefresh,
                  onPressed: (state.refreshing || state.loadingCatalog)
                      ? null
                      : () {
                          notifier.refreshCatalog();
                          if (isConnected) notifier.refreshServer();
                        },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (state.loadingCatalog || state.refreshing)
            const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            Container(
              width: double.maxFinite,
              color: context.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: context.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      resolveAppCenterErrorMessage(context, state.error!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: notifier.clearError,
                  ),
                ],
              ),
            ),
          if (!isConnected)
            Container(
              width: double.maxFinite,
              color: context.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appCenterErrorNotConnected,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildEnvironmentStrip(context, state),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AppStoreTab(onNavigateToTab: _navigateToTab),
                AppInstalledTab(onNavigateToTab: _navigateToTab),
                AppTasksTab(onNavigateToTab: _navigateToTab),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentStrip(
    BuildContext context,
    ApplicationCenterState state,
  ) {
    final l10n = context.l10n;
    final env = state.environment;

    if (env == null) {
      if (state.refreshing) {
        return Container(
          width: double.maxFinite,
          color: context.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.appCenterEnvInspectingLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (env.ready) {
      return Container(
        width: double.maxFinite,
        color: context.colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: context.vSuccess),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${context.appCenterEnvReadyLabel} · ${env.os} ${env.osVersion} (${env.architecture})',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.maxFinite,
      color: context.vWarning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: context.vWarning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              env.blockers.isNotEmpty
                  ? resolveAppCenterBlockerMessage(context, env.blockers.first)
                  : '${context.appCenterEnvNotReadyLabel} (${env.architecture})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.vWarning,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (env.canBootstrap)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                AppOperationWizardDialog.show(
                  context,
                  operation: ApplicationOperation.bootstrap,
                  onNavigateToTab: _navigateToTab,
                );
              },
              child: Text(
                l10n.appCenterBootstrapButton,
                style: const TextStyle(fontSize: 11),
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: (state.refreshing || state.busy)
                  ? null
                  : () {
                      ref
                          .read(applicationCenterProvider.notifier)
                          .refreshServer();
                    },
              child: Text(
                context.appCenterRecheckLabel,
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
