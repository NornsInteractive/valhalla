import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import 'agent_command_confirm_dialog.dart';
import 'agent_form_dialog.dart';
import 'interactive_login_provider.dart';

class AgentManagementView extends ConsumerStatefulWidget {
  const AgentManagementView({super.key});

  @override
  ConsumerState<AgentManagementView> createState() =>
      _AgentManagementViewState();
}

class _AgentManagementViewState extends ConsumerState<AgentManagementView> {
  String _formatTime(DateTime time) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}:${pad(time.second)}';
  }

  void _openAddAgentDialog(BuildContext context, String serverId) {
    showDialog<bool>(
      context: context,
      builder: (_) => AgentFormDialog(serverId: serverId),
    );
  }

  void _openEditAgentDialog(
    BuildContext context,
    String serverId,
    AgentProfile profile,
  ) {
    showDialog<bool>(
      context: context,
      builder: (_) =>
          AgentFormDialog(serverId: serverId, initialProfile: profile),
    );
  }

  void _showDiagnosticLogDialog(
    BuildContext context,
    String agentName,
    String diagnosticLog,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 20,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.agentDiagnosticLogTitle(agentName),
                  style: context.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141C),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: SelectableText(
                    diagnosticLog,
                    key: const Key('agent_diagnostic_log_content'),
                    style: monoTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFE2E8F0),
                    ).copyWith(height: 1.5),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              key: const Key('agent_diagnostic_log_copy_button'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(context.l10n.agentDiagnosticLogCopy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: diagnosticLog));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.agentDiagnosticLogCopied),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            TextButton(
              key: const Key('agent_diagnostic_log_close_button'),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.agentDiagnosticLogClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    AgentProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteAgentTitle),
        content: Text(ctx.l10n.deleteAgentMessage(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.vDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.deleteAgentConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(agentRegistryProvider.notifier).deleteAgent(profile.id);
    }
  }

  Future<void> _confirmAndInstall(
    BuildContext context,
    AgentProfile profile,
    ServerProfile server,
    String command,
  ) async {
    if (command.trim().isEmpty) return;

    final confirmed = await showAgentCommandConfirmDialog(
      context: context,
      actionType: AgentCommandActionType.install,
      agentName: profile.name,
      command: command,
      server: server,
    );

    if (confirmed && mounted) {
      await ref
          .read(agentRegistryProvider.notifier)
          .installForCurrentStatus(profile.id);
    }
  }

  bool _isLaunchingLogin = false;

  Future<void> _confirmAndLogin(
    BuildContext context,
    AgentProfile profile,
    ServerProfile server,
  ) async {
    if (_isLaunchingLogin) return;
    final isAgy = profile.id == 'builtin-agy' || profile.cliCommand == 'agy';
    final command =
        (profile.loginCommand != null && profile.loginCommand!.isNotEmpty)
        ? profile.loginCommand!
        : (isAgy ? 'agy' : null);
    if (command == null || command.isEmpty) return;

    setState(() => _isLaunchingLogin = true);
    try {
      final confirmed = await showAgentCommandConfirmDialog(
        context: context,
        actionType: AgentCommandActionType.login,
        agentName: profile.name,
        command: command,
        server: server,
      );

      if (confirmed && context.mounted) {
        final sshClient = ref
            .read(sshClientManagerProvider)
            .getClient(server.id);
        final remoteExecCommand = profile.executionTarget == 'docker'
            ? agentTargetCommand(profile, command, interactive: true)
            : null;
        final result = await ref.read(interactiveLoginLauncherProvider)(
          context: context,
          agentName: profile.name,
          command: command,
          serverName: server.name,
          sshClient: sshClient,
          remoteExecCommand: remoteExecCommand,
        );
        if (result == true && mounted) {
          await ref.read(agentRegistryProvider.notifier).loginAgent(profile.id);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingLogin = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final connState = ref.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;
    final registry = ref.watch(agentRegistryProvider);
    final registryNotifier = ref.read(agentRegistryProvider.notifier);
    final installLog = ref.watch(installLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.agentManagementTitle,
              style: context.textTheme.titleMedium,
            ),
            if (activeServer != null)
              Text(
                '${activeServer.name} (${activeServer.host}:${activeServer.port})',
                style: monoTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.outline,
                ),
              ),
          ],
        ),
        actions: [
          if (activeServer != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: context.l10n.agentActionRefresh,
              onPressed: (!isConnected || registry.isLoading)
                  ? null
                  : () => registryNotifier.refresh(),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.l10n.addAgentButton),
              onPressed: () => _openAddAgentDialog(context, activeServer.id),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: activeServer == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Entrance(
                  index: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 48,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.noServerSelectedForAgents,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                if (!isConnected)
                  Entrance(
                    index: 0,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: context.vWarning.withValues(alpha: 0.12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_off,
                            size: 18,
                            color: context.vWarning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.sshDisconnectedAgentWarning,
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (registry.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: registry.isLoading && registry.agents.isEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 6,
                          itemBuilder: (context, index) =>
                              const SkeletonListTile(),
                        )
                      : registry.agents.isEmpty
                      ? Entrance(
                          index: 0,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.smart_toy_outlined,
                                    size: 56,
                                    color: context.colorScheme.outline,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    context.l10n.noAgentsConfiguredTitle,
                                    style: context.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.l10n.noAgentsConfiguredDesc,
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          color: context.colorScheme.outline,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(context.l10n.addAgentButton),
                                    onPressed: () => _openAddAgentDialog(
                                      context,
                                      activeServer.id,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth <
                                LayoutBreakpoints.compactMax) {
                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: registry.agents.length,
                                itemBuilder: (context, index) {
                                  final agentState = registry.agents[index];
                                  return _buildAgentCard(
                                    context: context,
                                    agentState: agentState,
                                    server: activeServer,
                                    isConnected: isConnected,
                                    installLog: installLog,
                                  );
                                },
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: LayoutBreakpoints
                                        .gridAgentCardMaxExtent,
                                    mainAxisExtent: 360,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: registry.agents.length,
                              itemBuilder: (context, index) {
                                final agentState = registry.agents[index];
                                return _buildAgentCard(
                                  context: context,
                                  agentState: agentState,
                                  server: activeServer,
                                  isConnected: isConnected,
                                  installLog: installLog,
                                  isGrid: true,
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

  Widget _buildAgentCard({
    required BuildContext context,
    required AgentRuntimeState agentState,
    required ServerProfile server,
    required bool isConnected,
    required InstallLog installLog,
    bool isGrid = false,
  }) {
    final profile = agentState.profile;
    final status = agentState.status;
    final hasAcp =
        profile.acpCommand != null && profile.acpCommand!.trim().isNotEmpty;

    final (statusText, statusColor) = switch (status.kind) {
      AgentEnvironmentStatusKind.ready => (
        context.l10n.agentStatusReady,
        context.vSuccess,
      ),
      AgentEnvironmentStatusKind.checking => (
        context.l10n.agentStatusChecking,
        context.vWarning,
      ),
      AgentEnvironmentStatusKind.cliMissing => (
        context.l10n.agentStatusCliMissing,
        context.vWarning,
      ),
      AgentEnvironmentStatusKind.acpMissing =>
        !hasAcp
            ? (context.l10n.agentStatusReady, context.vSuccess)
            : (context.l10n.agentStatusAcpMissing, context.vWarning),
      AgentEnvironmentStatusKind.notLoggedIn => (
        context.l10n.agentStatusNotLoggedIn,
        context.vInfo,
      ),
      AgentEnvironmentStatusKind.error => (
        context.l10n.agentStatusError,
        context.vDanger,
      ),
      AgentEnvironmentStatusKind.unknown => (
        context.l10n.agentStatusUnknown,
        context.colorScheme.outline,
      ),
    };

    final errorDisplay =
        agentState.errorMessage == AgentRegistryNotifier.disconnectedCode
        ? context.l10n.sshDisconnectedError
        : (agentState.errorMessage ?? status.detail);

    // CLI Status
    final (cliStatusText, cliStatusColor) = switch (status.kind) {
      AgentEnvironmentStatusKind.cliMissing => (
        context.l10n.agentCliStatusMissing,
        context.vWarning,
      ),
      AgentEnvironmentStatusKind.checking => (
        context.l10n.agentCliStatusChecking,
        context.vWarning,
      ),
      AgentEnvironmentStatusKind.unknown => (
        context.l10n.agentCliStatusUnknown,
        context.colorScheme.outline,
      ),
      AgentEnvironmentStatusKind.error => (
        context.l10n.agentCliStatusError,
        context.vDanger,
      ),
      _ => (context.l10n.agentCliStatusInstalled, context.vSuccess),
    };

    // ACP Status
    final (acpStatusText, acpStatusColor) = !hasAcp
        ? (context.l10n.agentAcpStatusNa, context.colorScheme.outline)
        : switch (status.kind) {
            AgentEnvironmentStatusKind.cliMissing => (
              context.l10n.agentAcpStatusPendingCli,
              context.colorScheme.outline,
            ),
            AgentEnvironmentStatusKind.acpMissing => (
              context.l10n.agentAcpStatusMissing,
              context.vWarning,
            ),
            AgentEnvironmentStatusKind.checking => (
              context.l10n.agentAcpStatusChecking,
              context.vWarning,
            ),
            AgentEnvironmentStatusKind.unknown => (
              context.l10n.agentAcpStatusUnknown,
              context.colorScheme.outline,
            ),
            AgentEnvironmentStatusKind.error => (
              context.l10n.agentAcpStatusError,
              context.vDanger,
            ),
            _ => (context.l10n.agentAcpStatusReady, context.vSuccess),
          };

    // Auth Status (status.authentication)
    // NOTE: unknown 不能显示已登录!
    final (authStatusText, authStatusColor) = switch (status.authentication) {
      AgentAuthenticationStatus.authenticated => (
        context.l10n.agentAuthStatusAuthenticated,
        context.vSuccess,
      ),
      AgentAuthenticationStatus.unauthenticated => (
        context.l10n.agentAuthStatusUnauthenticated,
        context.vInfo,
      ),
      AgentAuthenticationStatus.unknown => (
        context.l10n.agentAuthStatusUnknown,
        context.colorScheme.outline,
      ),
    };

    final isInstallStatus =
        status.kind == AgentEnvironmentStatusKind.cliMissing ||
        (hasAcp && status.kind == AgentEnvironmentStatusKind.acpMissing);

    final resolvedInstallCommand =
        status.kind == AgentEnvironmentStatusKind.cliMissing
        ? profile.installCommand
        : (profile.acpInstallCommand ?? profile.installCommand);

    final hasInstallCommand =
        resolvedInstallCommand != null &&
        resolvedInstallCommand.trim().isNotEmpty;

    final installPrompt =
        (hasAcp && status.kind == AgentEnvironmentStatusKind.acpMissing)
        ? context.l10n.agentAcpInstallPrompt
        : context.l10n.agentInstallPrompt;

    final isAgy = profile.id == 'builtin-agy' || profile.cliCommand == 'agy';
    final hasLoginCommand =
        (profile.loginCommand != null && profile.loginCommand!.isNotEmpty) ||
        isAgy;

    final cardContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon, Name, ID, Status Badge
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: agentState.isReady
                    ? context.vSuccess
                    : context.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: context.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: Text(
                          profile.id,
                          style: monoTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status.kind ==
                          AgentEnvironmentStatusKind.checking) ...[
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else if (agentState.isReady) ...[
                        PulseDot(color: statusColor, size: 6),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (profile.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              profile.description,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Status Chips: CLI, ACP, Auth
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildStatusChip(
                key: Key('agent_cli_status_${profile.id}'),
                icon: Icons.terminal,
                label: cliStatusText,
                color: cliStatusColor,
              ),
              _buildStatusChip(
                key: Key('agent_acp_status_${profile.id}'),
                icon: Icons.cable,
                label: acpStatusText,
                color: acpStatusColor,
              ),
              _buildStatusChip(
                key: Key('agent_auth_status_${profile.id}'),
                icon: Icons.verified_user_outlined,
                label: authStatusText,
                color: authStatusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Command Chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildCommandChip(
                icon: Icons.terminal,
                label: 'CLI: ${profile.cliCommand}',
              ),
              if (hasAcp)
                _buildCommandChip(
                  icon: Icons.cable,
                  label: 'ACP: ${profile.acpCommand}',
                )
              else
                _buildCommandChip(
                  icon: Icons.cable,
                  label: 'ACP: N/A',
                  iconColor: context.colorScheme.outline,
                  textColor: context.colorScheme.outline,
                ),
              if (profile.executionTarget == 'docker')
                _buildCommandChip(
                  icon: Icons.layers_outlined,
                  label:
                      'Docker: ${profile.containerReference != null && profile.containerReference!.isNotEmpty ? profile.containerReference : profile.containerBinding}',
                  iconColor: context.vInfo,
                  textColor: context.vInfo,
                ),
            ],
          ),

          // Probe Version summary
          if (status.version != null && status.version!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Probe: ${status.version}',
              style: monoTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.colorScheme.outline,
              ),
            ),
          ],

          // Missing login check note
          if (profile.loginCheckCommand == null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    context.l10n.agentNoLoginCheckProvided,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Error or detail
          if (errorDisplay != null && errorDisplay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.vDanger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.vDanger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                errorDisplay,
                style: monoTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: context.vDanger,
                ),
              ),
            ),
          ],

          // Proactive Install Callout (CLI Missing or ACP Missing, or Currently Installing)
          if (isInstallStatus || agentState.isInstalling) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: agentState.isInstalling
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.vWarning,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.agentStatusInstalling,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (installLog.agentId == profile.id) ...[
                          const SizedBox(height: 10),
                          _AgentInstallLogPanel(log: installLog),
                        ],
                      ],
                    )
                  : (hasInstallCommand
                        ? Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: context.vWarning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  installPrompt,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: !isConnected
                                    ? context.l10n.sshDisconnectedAgentWarning
                                    : '',
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.download, size: 16),
                                  label: Text(
                                    context.l10n.agentActionAutoInstall,
                                  ),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: !isConnected
                                      ? null
                                      : () => _confirmAndInstall(
                                          context,
                                          profile,
                                          server,
                                          resolvedInstallCommand,
                                        ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: context.vWarning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      installPrompt,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.l10n.agentNoInstallCommand,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )),
            ),
          ],

          // Proactive Login Callout
          if (hasLoginCommand &&
              (status.kind == AgentEnvironmentStatusKind.notLoggedIn ||
                  status.authentication ==
                      AgentAuthenticationStatus.unauthenticated ||
                  isAgy)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.vInfo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.vInfo.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.login_rounded, size: 20, color: context.vInfo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.agentLoginPrompt,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: !isConnected
                        ? context.l10n.sshDisconnectedAgentWarning
                        : '',
                    child: FilledButton.icon(
                      key: Key('agent_login_button_${profile.id}'),
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(context.l10n.agentActionExecuteLogin),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: (!isConnected || _isLaunchingLogin)
                          ? null
                          : () => _confirmAndLogin(context, profile, server),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: Key('agent_diagnostic_log_button_${profile.id}'),
                icon: const Icon(Icons.article_outlined, size: 14),
                label: Text(
                  context.l10n.agentViewDiagnosticLog,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: status.diagnosticLog.trim().isNotEmpty
                    ? () => _showDiagnosticLogDialog(
                        context,
                        profile.name,
                        status.diagnosticLog,
                      )
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Bottom row: Last checked time & Action buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.agentLastChecked(_formatTime(status.checkedAt)),
                  style: monoTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
              if (agentState.isInstalling && !isInstallStatus)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.agentStatusInstalling,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              else ...[
                if (hasLoginCommand)
                  IconButton(
                    key: Key('agent_bottom_login_${profile.id}'),
                    icon: const Icon(Icons.login, size: 18),
                    tooltip: context.l10n.agentActionExecuteLogin,
                    onPressed: (!isConnected || _isLaunchingLogin)
                        ? null
                        : () => _confirmAndLogin(context, profile, server),
                  ),
                IconButton(
                  key: Key('agent_edit_button_${profile.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: context.l10n.editAgent,
                  onPressed: (agentState.isInstalling || agentState.isLoggingIn)
                      ? null
                      : () => _openEditAgentDialog(context, server.id, profile),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: context.l10n.agentActionRefresh,
                  onPressed: (!isConnected || agentState.isInstalling)
                      ? null
                      : () => ref
                            .read(agentRegistryProvider.notifier)
                            .refreshAgent(profile.id),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: context.vDanger,
                  ),
                  tooltip: context.l10n.delete,
                  onPressed: agentState.isInstalling
                      ? null
                      : () => _confirmAndDelete(context, profile),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Card(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.card),
        side: BorderSide(
          color: agentState.isReady
              ? context.vSuccess.withValues(alpha: 0.4)
              : context.colorScheme.outlineVariant,
        ),
      ),
      child: isGrid ? SingleChildScrollView(child: cardContent) : cardContent,
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandChip({
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(VRadius.input),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? context.colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: monoTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: textColor ?? context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentInstallLogPanel extends StatefulWidget {
  final InstallLog log;

  const _AgentInstallLogPanel({required this.log});

  @override
  State<_AgentInstallLogPanel> createState() => _AgentInstallLogPanelState();
}

class _AgentInstallLogPanelState extends State<_AgentInstallLogPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.log.lines.isNotEmpty) {
      _scrollToBottom();
    }
  }

  @override
  void didUpdateWidget(covariant _AgentInstallLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log.lines.length != oldWidget.log.lines.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(VRadius.input),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal,
                size: 14,
                color: context.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.agentInstallLogTitle,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.log.truncated) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: context.vWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.agentInstallLogTruncated,
                      style: TextStyle(fontSize: 10, color: context.vWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.log.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.agentInstallLogEmpty,
                style: monoTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.outline,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: widget.log.lines.length,
                  itemBuilder: (context, index) {
                    return Text(
                      widget.log.lines[index],
                      style: monoTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFD4D4D4),
                      ).copyWith(height: 1.35),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
