import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/server_profile.dart';
import '../../core/providers/storage_providers.dart';
import '../../core/providers/agent_update_lock_provider.dart';
import '../../core/providers/agent_update_provider.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../chat/ai_chat_view.dart';
import 'agent_command_confirm_dialog.dart';
import 'agent_form_dialog.dart';
import 'interactive_login_provider.dart';
import 'widgets/agent_update_dialog.dart';

class AgentManagementView extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToChat;

  const AgentManagementView({super.key, this.onNavigateToChat});

  @override
  ConsumerState<AgentManagementView> createState() =>
      _AgentManagementViewState();
}

class _AgentManagementViewState extends ConsumerState<AgentManagementView> {
  bool _isLoggingIn = false;
  final Set<String> _expandedAgentIds = {};
  final Map<String, Set<AgentUpdateComponent>> _selectedUpdateComponents = {};
  final Map<String, DateTime?> _lastReportInitializedAt = {};

  String _componentStatusLabel(
    BuildContext context,
    AgentComponentUpdate comp,
  ) {
    switch (comp.status) {
      case AgentUpdateStatus.available:
        return context.l10n.agentUpdateAvailable;
      case AgentUpdateStatus.current:
        return context.l10n.agentUpdateUpToDate;
      case AgentUpdateStatus.missing:
        return context.l10n.agentStatusCliMissing;
      case AgentUpdateStatus.unsupported:
        return context.l10n.serviceUnsupported;
      case AgentUpdateStatus.error:
        return context.l10n.agentUpdateFailed;
    }
  }

  String _localizeEntryError(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'AGENT_UPDATE_BUSY':
        return l10n.agentUpdateBusy;
      case 'AGENT_UPDATE_IN_PROGRESS':
        return l10n.agentUpdateInProgress;
      case 'AGENT_UPDATE_INTERRUPTED':
        return l10n.agentUpdateInterrupted;
      case 'SSH_DISCONNECTED':
        return l10n.serverDisconnected;
      default:
        return l10n.agentUpdateFailed;
    }
  }

  String? _mapStatusDetail(BuildContext context, String? detail) {
    if (detail == null) return null;
    if (detail == 'AGY_AUTH_CHECK_UNAVAILABLE') {
      return context.l10n.agentAgyAuthCheckUnavailable;
    }
    if (detail == 'AGY_AUTH_CHECK_INVALID') {
      return context.l10n.agentAgyAuthCheckInvalid;
    }
    if (detail == 'AGY_ACP_SIGN_IN_REQUIRED') {
      return context.l10n.agentAgyAcpSignInRequired;
    }
    if (detail == 'AGY_ACP_CREDENTIALS_NOT_VALIDATED') {
      return context.l10n.agentAgyAcpCredentialsSaved;
    }
    return detail;
  }

  Future<void> _handleAcpLogin(
    BuildContext context,
    AgentProfile profile,
    ServerProfile server,
  ) async {
    if (_isLoggingIn) return;
    final activeServer = ref.read(activeServerProvider);
    if (activeServer?.id != server.id) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.agentTargetChangedNotice),
            backgroundColor: context.vDanger,
          ),
        );
      }
      return;
    }

    final chatState = ref.read(aiChatProvider);
    if (chatState.isAuthenticating ||
        chatState.isLoadingSettings ||
        chatState.isGenerating) {
      return;
    }

    _isLoggingIn = true;
    final chatNotifier = ref.read(aiChatProvider.notifier);

    // Let the provider own switch + identity verification + authentication request.
    // This Future survives route disposal and catches errors safely without touching ref after unmount.
    unawaited(
      chatNotifier
          .requestAuthenticationForAgent(server.id, profile.id)
          .catchError((_) {})
          .whenComplete(() {
            if (mounted) {
              setState(() => _isLoggingIn = false);
            }
          }),
    );

    // Navigate immediately to chat without waiting for remote initialization
    if (widget.onNavigateToChat != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onNavigateToChat?.call();
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AiChatView()));
    }
  }

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
        final registry = ref.read(agentRegistryProvider.notifier);
        final token = registry.beginInteractiveLogin(profile.id);
        if (token == null) {
          if (mounted) {
            final runtime = ref
                .read(agentRegistryProvider)
                .findRuntime(profile.id);
            final errorMsg = runtime?.errorMessage == 'AGENT_UPDATE_IN_PROGRESS'
                ? context.l10n.agentUpdateInProgress
                : (runtime?.errorMessage == 'AGENT_UPDATE_BUSY'
                      ? context.l10n.agentUpdateBusy
                      : (runtime?.errorMessage ??
                            context.l10n.agentAuthRetryHint));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(errorMsg)));
          }
          return;
        }

        try {
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
            await registry.loginAgent(profile.id);
          }
        } finally {
          registry.endInteractiveLogin(profile.id, token);
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
    final updatesState = ref.watch(agentUpdatesProvider);
    final isServerUpdateLocked =
        activeServer != null &&
        ref
            .watch(agentUpdateLockProvider)
            .contains('server:${activeServer.id}');

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isNarrow =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax ||
        textScale > 1.3;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.agentManagementTitle,
              style: context.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (activeServer != null)
              Text(
                '${activeServer.name} (${activeServer.host}:${activeServer.port})',
                style: monoTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (activeServer != null) ...[
            IconButton(
              key: const Key('agentCheckAllUpdatesButton'),
              icon: updatesState.isChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt, size: 20),
              tooltip: context.l10n.agentUpdateCheckAll,
              onPressed:
                  (!isConnected ||
                      updatesState.isChecking ||
                      isServerUpdateLocked)
                  ? null
                  : () => ref
                        .read(agentUpdatesProvider.notifier)
                        .checkAll(force: true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: context.l10n.agentActionRefresh,
              onPressed:
                  (!isConnected || registry.isLoading || isServerUpdateLocked)
                  ? null
                  : () => registryNotifier.refresh(),
            ),
            if (isNarrow)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: context.l10n.addAgentButton,
                onPressed: isServerUpdateLocked
                    ? null
                    : () => _openAddAgentDialog(context, activeServer.id),
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.addAgentButton),
                onPressed: isServerUpdateLocked
                    ? null
                    : () => _openAddAgentDialog(context, activeServer.id),
              ),
            const SizedBox(width: 8),
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

    final mappedDetail = _mapStatusDetail(context, status.detail);
    final errorDisplay =
        agentState.errorMessage == AgentRegistryNotifier.disconnectedCode
        ? context.l10n.sshDisconnectedError
        : (agentState.errorMessage ?? mappedDetail);
    final isSavedUnverified =
        status.detail == 'AGY_ACP_CREDENTIALS_NOT_VALIDATED';
    final isDetailWarning = status.detail == 'AGY_ACP_SIGN_IN_REQUIRED';
    final detailColor = isSavedUnverified
        ? context.vInfo
        : (isDetailWarning ? context.vWarning : context.vDanger);

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
    final isExpanded = _expandedAgentIds.contains(profile.id);
    final isServerLocked = ref
        .watch(agentUpdateLockProvider)
        .contains('server:${profile.serverId}');
    final updateEntry = ref.watch(
      agentUpdatesProvider.select((s) => s.agents[profile.id]),
    );
    final isLocked = isServerLocked || (updateEntry?.isUpdating ?? false);
    final availableComponents =
        updateEntry?.report?.components
            .where((c) => c.status == AgentUpdateStatus.available)
            .map((c) => c.component)
            .toSet() ??
        <AgentUpdateComponent>{};
    final reportCheckedAt = updateEntry?.report?.checkedAt;
    if (_lastReportInitializedAt[profile.id] != reportCheckedAt) {
      _lastReportInitializedAt[profile.id] = reportCheckedAt;
      _selectedUpdateComponents[profile.id] = Set.from(availableComponents);
    }
    final selectedComps = _selectedUpdateComponents[profile.id] ??= Set.from(
      availableComponents,
    );
    selectedComps.removeWhere((c) => !availableComponents.contains(c));
    final hasAvailableUpdates = availableComponents.isNotEmpty;
    final String targetSummary;
    if (profile.executionTarget == 'docker') {
      final refOrBinding =
          (profile.containerReference != null &&
              profile.containerReference!.isNotEmpty)
          ? profile.containerReference!
          : profile.containerBinding;
      targetSummary = refOrBinding.isNotEmpty
          ? 'Docker: $refOrBinding'
          : 'Docker';
    } else {
      targetSummary = context.l10n.agentExecutionHost;
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const animDuration = Duration(milliseconds: 200);

    final detailsChild = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildCommandChip(icon: Icons.tag, label: 'ID: ${profile.id}'),
        const SizedBox(height: 6),
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
              color: detailColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(color: detailColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              errorDisplay,
              style: monoTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: detailColor,
              ),
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

        // Updates Section
        const Divider(height: 20),
        Row(
          children: [
            Icon(
              Icons.system_update_alt,
              size: 14,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.l10n.agentUpdateDialogTitle,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: Key('agent_check_update_button_${profile.id}'),
              icon: (updateEntry?.isChecking ?? false)
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.refresh, size: 16),
              tooltip: (updateEntry?.isChecking ?? false)
                  ? context.l10n.agentUpdateChecking
                  : context.l10n.agentUpdateCheck,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed:
                  (!isConnected ||
                      isLocked ||
                      (updateEntry?.isChecking ?? false))
                  ? null
                  : () => ref
                        .read(agentUpdatesProvider.notifier)
                        .checkAgent(profile.id, force: true),
            ),
            if (hasAvailableUpdates) ...[
              const SizedBox(width: 4),
              FilledButton.icon(
                key: Key('agent_update_button_${profile.id}'),
                icon: const Icon(Icons.upgrade, size: 14),
                label: Text(context.l10n.agentUpdateDialogTitle),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed:
                    (!isConnected ||
                        isLocked ||
                        (updateEntry?.isChecking ?? false) ||
                        selectedComps.isEmpty)
                    ? null
                    : () {
                        ref
                            .read(agentUpdatesProvider.notifier)
                            .dismissUpdateNotice();
                        AgentUpdateDialog.show(
                          context,
                          profile: profile,
                          selectedComponents: selectedComps,
                        );
                      },
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (updateEntry?.report != null) ...[
          for (final comp in updateEntry!.report!.components)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (comp.status == AgentUpdateStatus.available)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: Key(
                              'agent_select_update_${profile.id}_${comp.component.name}',
                            ),
                            value: selectedComps.contains(comp.component),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedComps.add(comp.component);
                                } else {
                                  selectedComps.remove(comp.component);
                                }
                              });
                            },
                          ),
                        )
                      else
                        const SizedBox(width: 24),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: Text(
                          comp.component == AgentUpdateComponent.cli
                              ? 'CLI'
                              : 'ACP',
                          style: monoTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          comp.latestVersion != null &&
                                  comp.installedVersion != comp.latestVersion
                              ? '${comp.installedVersion ?? context.l10n.agentUpdateVersionUnknown} → ${comp.latestVersion}'
                              : (comp.installedVersion ??
                                    context.l10n.agentUpdateVersionUnknown),
                          style: monoTextStyle(
                            fontSize: 11,
                            color: comp.status == AgentUpdateStatus.available
                                ? context.vSuccess
                                : context.colorScheme.onSurfaceVariant,
                            fontWeight:
                                comp.status == AgentUpdateStatus.available
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusChip(
                        icon: comp.status == AgentUpdateStatus.available
                            ? Icons.arrow_upward
                            : (comp.status == AgentUpdateStatus.current
                                  ? Icons.check
                                  : (comp.status == AgentUpdateStatus.error
                                        ? Icons.error_outline
                                        : Icons.help_outline)),
                        label: _componentStatusLabel(context, comp),
                        color: comp.status == AgentUpdateStatus.available
                            ? context.vSuccess
                            : (comp.status == AgentUpdateStatus.current
                                  ? context.colorScheme.outline
                                  : (comp.status == AgentUpdateStatus.error
                                        ? context.vDanger
                                        : context.colorScheme.outline)),
                      ),
                    ],
                  ),
                  if (comp.source != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 2),
                      child: Text(
                        comp.source!,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.outline,
                          fontSize: 10,
                        ),
                        softWrap: true,
                      ),
                    ),
                ],
              ),
            ),
        ] else ...[
          Text(
            context.l10n.agentUpdateNeverChecked,
            style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
          ),
        ],
        if (updateEntry?.lastSuccessfulCheckAt != null) ...[
          const SizedBox(height: 4),
          Text(
            '${context.l10n.agentUpdateLastChecked}: ${updateEntry!.lastSuccessfulCheckAt!.toLocal().toString().split('.').first}',
            style: TextStyle(fontSize: 10, color: context.colorScheme.outline),
          ),
        ],
        if (updateEntry?.errorCode != null) ...[
          const SizedBox(height: 6),
          Tooltip(
            message: updateEntry!.errorCode!,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.vDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.vDanger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _localizeEntryError(context, updateEntry.errorCode!),
                style: monoTextStyle(fontSize: 10, color: context.vDanger),
              ),
            ),
          ),
        ],
        if (updateEntry?.interrupted == true &&
            !(updateEntry?.isUpdating ?? false)) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.vWarning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: context.vWarning.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              context.l10n.agentUpdateInterrupted,
              style: TextStyle(fontSize: 10, color: context.vWarning),
            ),
          ),
        ],
        if ((updateEntry?.isUpdating ?? false) ||
            (updateEntry?.log.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.agentUpdateLogs,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: Key('agent_update_copy_log_button_${profile.id}'),
                icon: const Icon(Icons.copy_rounded, size: 14),
                tooltip: context.l10n.agentUpdateCopyLog,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: (updateEntry?.log.isEmpty ?? true)
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: updateEntry!.log),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.agentUpdateLogCopied),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 100,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF07080B)
                  : const Color(0xFF1A1E26),
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                updateEntry!.log.isEmpty && updateEntry.isUpdating
                    ? '...'
                    : updateEntry.log,
                style: monoTextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
        ],
      ],
    );

    final cardContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon, Name, ID, Target Badge, Status Badge
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
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: profile.executionTarget == 'docker'
                              ? context.vInfo.withValues(alpha: 0.15)
                              : context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              profile.executionTarget == 'docker'
                                  ? Icons.layers_outlined
                                  : Icons.computer,
                              size: 11,
                              color: profile.executionTarget == 'docker'
                                  ? context.vInfo
                                  : context.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                targetSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: profile.executionTarget == 'docker'
                                      ? context.vInfo
                                      : context.colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
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
          if (reduceMotion)
            if (isExpanded) detailsChild else const SizedBox.shrink()
          else
            AnimatedCrossFade(
              duration: animDuration,
              reverseDuration: animDuration,
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: detailsChild,
            ),

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
                                  onPressed: (!isConnected || isLocked)
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
              !usesAntigravityAcp(profile) &&
              (status.kind == AgentEnvironmentStatusKind.notLoggedIn ||
                  status.authentication ==
                      AgentAuthenticationStatus.unauthenticated)) ...[
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 280;
                  final content = Row(
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
                    ],
                  );
                  final button = Tooltip(
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
                      onPressed: (!isConnected || _isLaunchingLogin || isLocked)
                          ? null
                          : () => _confirmAndLogin(context, profile, server),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [content, const SizedBox(height: 8), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: 8),
                      button,
                    ],
                  );
                },
              ),
            ),
          ],

          // Proactive ACP Sign-In Callout (AgY)
          if (usesAntigravityAcp(profile) &&
              status.authentication ==
                  AgentAuthenticationStatus.unauthenticated) ...[
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 280;
                  final content = Row(
                    children: [
                      Icon(
                        Icons.vpn_key_outlined,
                        size: 20,
                        color: context.vInfo,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.agentAgyAcpSignInRequired,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                  final button = Tooltip(
                    message: !isConnected
                        ? context.l10n.sshDisconnectedAgentWarning
                        : '',
                    child: FilledButton.icon(
                      key: Key('agent_acp_callout_login_${profile.id}'),
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(context.l10n.agentActionAcpLogin),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: (!isConnected || isLocked)
                          ? null
                          : () => _handleAcpLogin(context, profile, server),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [content, const SizedBox(height: 8), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: 8),
                      button,
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Bottom row: Last checked time & Action buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                context.l10n.agentLastChecked(_formatTime(status.checkedAt)),
                style: monoTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: context.colorScheme.outline,
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
              else
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasLoginCommand)
                      IconButton(
                        key: Key('agent_bottom_login_${profile.id}'),
                        icon: const Icon(Icons.login, size: 18),
                        tooltip: isAgy
                            ? context.l10n.agentActionCliLogin
                            : context.l10n.agentActionExecuteLogin,
                        onPressed:
                            (!isConnected || _isLaunchingLogin || isLocked)
                            ? null
                            : () => _confirmAndLogin(context, profile, server),
                      ),
                    if (usesAntigravityAcp(profile))
                      IconButton(
                        key: Key('agent_acp_login_${profile.id}'),
                        icon: const Icon(Icons.vpn_key_outlined, size: 18),
                        tooltip: context.l10n.agentActionAcpLogin,
                        onPressed: (!isConnected || isLocked)
                            ? null
                            : () => _handleAcpLogin(context, profile, server),
                      ),
                    IconButton(
                      key: Key('agent_edit_button_${profile.id}'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: context.l10n.editAgent,
                      onPressed:
                          (agentState.isInstalling ||
                              agentState.isLoggingIn ||
                              isLocked)
                          ? null
                          : () => _openEditAgentDialog(
                              context,
                              server.id,
                              profile,
                            ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: context.l10n.agentActionRefresh,
                      onPressed:
                          (!isConnected || agentState.isInstalling || isLocked)
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
                      onPressed: (agentState.isInstalling || isLocked)
                          ? null
                          : () => _confirmAndDelete(context, profile),
                    ),
                    IconButton(
                      key: Key('agent_toggle_details_${profile.id}'),
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      tooltip: isExpanded
                          ? context.l10n.agentCollapseDetails
                          : context.l10n.agentExpandDetails,
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedAgentIds.remove(profile.id);
                          } else {
                            _expandedAgentIds.add(profile.id);
                          }
                        });
                      },
                    ),
                  ],
                ),
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
