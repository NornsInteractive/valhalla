import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';
import '../core/providers/ai_chat_provider.dart';
import '../core/providers/server_provider.dart';
import '../data/models/server_profile.dart';
import '../features/dashboard/dashboard_provider.dart';
import '../features/docker/docker_provider.dart';
import 'status_badge.dart';
import 'valhalla_card.dart';

class ContextInspector extends ConsumerWidget {
  final int activeTabIndex;
  final VoidCallback onClose;

  const ContextInspector({
    super.key,
    required this.activeTabIndex,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(activeServerProvider);
    final connState = ref.watch(serverConnectionProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          left: BorderSide(color: context.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.inspectorTitle,
                  style: context.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: context.l10n.inspectorClose,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildInspectorContent(
                context,
                ref,
                activeServer,
                connState,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorContent(
    BuildContext context,
    WidgetRef ref,
    ServerProfile? server,
    ServerConnectionState connState,
  ) {
    if (server == null) {
      return Text(
        context.l10n.noServerSelected,
        style: TextStyle(color: context.colorScheme.outline),
      );
    }

    switch (activeTabIndex) {
      case 0: // Dashboard
        return _buildDashboardInspector(context, ref, server, connState);
      case 1: // AI Ops
        return _buildAiOpsInspector(context, ref, server, connState);
      case 4: // Docker
        return _buildDockerInspector(context, ref);
      default:
        return _buildGenericServerInspector(context, server, connState);
    }
  }

  Widget _buildDashboardInspector(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
    ServerConnectionState connState,
  ) {
    final metrics = ref.watch(systemMetricsStreamProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, context.l10n.serverSpecs),
        const SizedBox(height: 8),
        _buildInfoTile(context, 'Server Name', server.name),
        _buildInfoTile(context, 'Host IP', server.host),
        _buildInfoTile(context, 'Port', server.port.toString()),
        _buildInfoTile(context, 'User', server.username),
        _buildInfoTile(context, 'Auth', server.authType.name.toUpperCase()),
        const SizedBox(height: 16),
        _buildSectionTitle(context, 'Real-time Telemetry'),
        const SizedBox(height: 8),
        if (metrics != null) ...[
          _buildInfoTile(
            context,
            'CPU Ratio',
            '${(metrics.cpuUsedRatio * 100).toStringAsFixed(1)}%',
          ),
          _buildInfoTile(
            context,
            'Memory Ratio',
            '${(metrics.memoryUsedRatio * 100).toStringAsFixed(1)}%',
          ),
          _buildInfoTile(
            context,
            'Load Avg',
            '${metrics.load1.toStringAsFixed(2)}, ${metrics.load5.toStringAsFixed(2)}, ${metrics.load15.toStringAsFixed(2)}',
          ),
          _buildInfoTile(
            context,
            'Uptime',
            MetricsFormatters.formatUptime(metrics.uptimeSeconds),
          ),
          _buildInfoTile(
            context,
            'Root Disk',
            '${metrics.rootDiskUsedPercent.toStringAsFixed(1)}%',
          ),
        ] else ...[
          Text(
            connState.isConnected ? 'Waiting for samples...' : 'Server offline',
            style: TextStyle(fontSize: 12, color: context.colorScheme.outline),
          ),
        ],
      ],
    );
  }

  Widget _buildAiOpsInspector(
    BuildContext context,
    WidgetRef ref,
    ServerProfile server,
    ServerConnectionState connState,
  ) {
    final chatState = ref.watch(aiChatProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Agent Configuration'),
        const SizedBox(height: 8),
        _buildInfoTile(
          context,
          'Active Agent',
          chatState.activeAgentProfile?.name ?? 'None',
        ),
        _buildInfoTile(context, 'Protocol', 'ACP 1.0 (SSH JSON-RPC)'),
        _buildInfoTile(context, 'Transport', 'SSH Session stdio'),
        _buildInfoTile(
          context,
          'Target Server',
          '${server.username}@${server.host}:${server.port}',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle(context, 'Session Stats'),
        const SizedBox(height: 8),
        _buildInfoTile(
          context,
          'Session ID',
          chatState.activeSessionId ?? 'None',
        ),
        _buildInfoTile(
          context,
          'Messages',
          chatState.activeSession?.messages.length.toString() ?? '0',
        ),
        _buildInfoTile(
          context,
          'Status',
          chatState.isGenerating ? 'Streaming...' : 'Idle',
        ),
      ],
    );
  }

  Widget _buildDockerInspector(BuildContext context, WidgetRef ref) {
    final dockerState = ref.watch(dockerProvider);
    final selected = dockerState.selectedContainer;

    if (selected == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Select a container in the list to view detailed inspector metadata.',
            style: TextStyle(fontSize: 12, color: context.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final inspect = dockerState.inspectData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Container: ${selected.name}'),
        const SizedBox(height: 8),
        _buildInfoTile(context, 'ID', selected.id),
        _buildInfoTile(context, 'Image', selected.image),
        _buildInfoTile(context, 'State', selected.state.name.toUpperCase()),
        _buildInfoTile(context, 'Status', selected.status),
        _buildInfoTile(
          context,
          'Ports',
          selected.ports.isEmpty ? 'None' : selected.ports,
        ),
        if (selected.createdAt != null)
          _buildInfoTile(context, 'Created', selected.createdAt.toString()),
        if (inspect != null && inspect.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle(context, 'Inspect Metadata'),
          const SizedBox(height: 8),
          ValhallaCard(
            padding: const EdgeInsets.all(8),
            color: context.colorScheme.surfaceContainerLow,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(inspect),
              style: monoTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenericServerInspector(
    BuildContext context,
    ServerProfile server,
    ServerConnectionState connState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, context.l10n.serverSpecs),
        const SizedBox(height: 8),
        _buildInfoTile(context, 'Name', server.name),
        _buildInfoTile(context, 'Endpoint', '${server.host}:${server.port}'),
        _buildInfoTile(context, 'Username', server.username),
        _buildInfoTile(
          context,
          'Auth Method',
          server.authType.name.toUpperCase(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Link Status: ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            StatusBadge(
              label: connState.isConnected
                  ? context.l10n.serverConnected
                  : context.l10n.serverDisconnected,
              type: connState.isConnected
                  ? StatusType.online
                  : StatusType.offline,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.textTheme.titleSmall?.copyWith(
        color: context.colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: monoTextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
