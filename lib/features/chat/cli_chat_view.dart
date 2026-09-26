import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../terminal/widgets/shared_terminal_canvas.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/cli_chat_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/sftp_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../data/models/agent_profile.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../agents/agent_management_view.dart';
import '../../widgets/remote_directory_picker_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/valhalla_card.dart';
import '../../core/providers/commands_provider.dart';
import '../../data/models/chat_launch_preference.dart';
import 'widgets/chat_run_settings_dialog.dart';
import 'widgets/chat_run_settings_strip.dart';

class CliChatView extends ConsumerStatefulWidget {
  const CliChatView({super.key});

  @override
  ConsumerState<CliChatView> createState() => _CliChatViewState();
}

class _CliChatViewState extends ConsumerState<CliChatView> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _cwdController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  String? _lastReportedError;
  String? _lastReportedErrorDetail;
  String? _scrolledSessionId;

  @override
  void initState() {
    super.initState();
    _messagesScrollController.addListener(_onMessagesScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(cliChatProvider);
      if (state.activeSession != null && state.messages.isNotEmpty) {
        _scrolledSessionId = state.activeSession!.id;
        if (_messagesScrollController.hasClients) {
          _messagesScrollController.jumpTo(
            _messagesScrollController.position.maxScrollExtent,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _messagesScrollController.removeListener(_onMessagesScroll);
    _promptController.dispose();
    _cwdController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _onMessagesScroll() {
    if (!_messagesScrollController.hasClients) return;
    if (_messagesScrollController.position.pixels <= 20) {
      final state = ref.read(cliChatProvider);
      if (state.hasOlderMessages &&
          !state.isLoadingOlderMessages &&
          !state.isSending) {
        ref.read(cliChatProvider.notifier).loadOlderMessages();
      }
    }
  }

  void _handleChatStateChange(CliChatState? previous, CliChatState next) {
    final previousSessionId = previous?.activeSession?.id;
    final nextSessionId = next.activeSession?.id;

    if (nextSessionId == null) {
      _scrolledSessionId = null;
    } else if (nextSessionId != _scrolledSessionId &&
        next.messages.isNotEmpty) {
      _scrolledSessionId = nextSessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScrollController.hasClients) return;
        _messagesScrollController.jumpTo(
          _messagesScrollController.position.maxScrollExtent,
        );
      });
      return;
    }

    final isPrepend =
        previous != null &&
        previousSessionId == nextSessionId &&
        nextSessionId != null &&
        previous.messages.isNotEmpty &&
        next.messages.length > previous.messages.length &&
        next.messages.last.id == previous.messages.last.id &&
        next.messages.first.id != previous.messages.first.id;

    if (isPrepend && _messagesScrollController.hasClients) {
      final oldMaxScroll = _messagesScrollController.position.maxScrollExtent;
      final oldPixels = _messagesScrollController.position.pixels;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScrollController.hasClients) return;
        final newMaxScroll = _messagesScrollController.position.maxScrollExtent;
        final delta = newMaxScroll - oldMaxScroll;
        if (delta > 0) {
          _messagesScrollController.jumpTo(oldPixels + delta);
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_messagesScrollController.hasClients) {
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _getLocalizedError(
    BuildContext context,
    String code, {
    String? detail,
  }) {
    switch (code) {
      case 'CLI_HISTORY_SDK_MISSING':
        return context.l10n.cliHistorySdkMissing;
      case 'CLI_HISTORY_RUNTIME_MISSING':
        return context.l10n.cliHistoryRuntimeMissing;
      case 'CLI_LOGIN_REQUIRED':
        return context.l10n.cliLoginRequired;
      case 'CLI_NOT_INSTALLED':
        return context.l10n.cliNotInstalled;
      case 'CLI_VERSION_UNSUPPORTED':
        return context.l10n.cliVersionUnsupported;
      case 'CLI_BUSY':
        return context.l10n.cliBusy;
      case 'CLI_DISCONNECTED':
        return context.l10n.cliDisconnected;
      case 'CLI_SERVER_CHANGED':
        return context.l10n.cliServerChanged;
      case 'CLI_TURN_FAILED':
        return context.l10n.cliTurnFailed;
      case 'CLI_MODEL_AT_CAPACITY':
        return context.l10n.cliOperationFailedWithDetail(
          LogSanitizer.sanitize(
            detail?.trim().isNotEmpty == true
                ? detail!.trim()
                : 'Selected model is at capacity. Please try a different model.',
          ),
        );
      case 'CLI_USE_TERMINAL':
        return context.l10n.cliUseTerminal;
      case 'CLI_DELETE_FAILED':
        final trimmed = detail?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          return context.l10n.cliDeleteFailedWithDetail(
            LogSanitizer.sanitize(trimmed),
          );
        }
        return context.l10n.cliDeleteFailed;
      case 'CLI_DELETE_UNSUPPORTED':
        return context.l10n.cliDeleteUnsupported;
      case 'CLI_OPERATION_FAILED':
      default:
        final trimmed = detail?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          return context.l10n.cliOperationFailedWithDetail(
            LogSanitizer.sanitize(trimmed),
          );
        }
        return context.l10n.cliOperationFailed;
    }
  }

  void _listenError(BuildContext context, CliChatState state) {
    if (state.errorCode != null &&
        (state.errorCode != _lastReportedError ||
            state.errorDetail != _lastReportedErrorDetail)) {
      _lastReportedError = state.errorCode;
      _lastReportedErrorDetail = state.errorDetail;
      final code = state.errorCode!;
      final message = _getLocalizedError(
        context,
        code,
        detail: state.errorDetail,
      );
      final isAgentSetupError =
          code == 'CLI_LOGIN_REQUIRED' ||
          code == 'CLI_NOT_INSTALLED' ||
          code == 'CLI_VERSION_UNSUPPORTED';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              action: isAgentSetupError
                  ? SnackBarAction(
                      label: context.l10n.manageAgents,
                      textColor: Colors.white,
                      onPressed: () => _openAgentManagement(context),
                    )
                  : null,
            ),
          );
        }
      });
    } else if (state.errorCode == null) {
      _lastReportedError = null;
      _lastReportedErrorDetail = null;
    }
  }

  Future<void> _handleSend() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(cliChatProvider.notifier);
    _promptController.clear();
    try {
      await notifier.sendMessage(text);
      if (mounted) {
        final state = ref.read(cliChatProvider);
        if (state.errorCode != null && !state.isSending) {
          if (_promptController.text.isEmpty) {
            _promptController.text = text;
          }
        }
      }
    } catch (_) {
      if (mounted && _promptController.text.isEmpty) {
        _promptController.text = text;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _confirmDeleteSession(
    BuildContext context,
    NativeCliSession session,
  ) async {
    final currentState = ref.read(cliChatProvider);
    final capturedServerId = currentState.serverId;
    final capturedAgentId = currentState.activeAgent?.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.cliDeleteSessionTitle),
        content: Text(context.l10n.cliDeleteSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('cli_confirm_delete_button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.cliDeleteConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nowState = ref.read(cliChatProvider);
      if (nowState.serverId != capturedServerId ||
          nowState.activeAgent?.id != capturedAgentId) {
        return;
      }
      await ref
          .read(cliChatProvider.notifier)
          .deleteSession(session.id, confirmed: true);
    }
  }

  Future<void> _confirmInstallSdk(BuildContext context) async {
    final currentState = ref.read(cliChatProvider);
    final capturedServerId = currentState.serverId;
    final capturedAgentId = currentState.activeAgent?.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.cliInstallSdkTitle),
        content: Text(context.l10n.cliInstallSdkMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('cli_confirm_install_sdk_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.cliInstallSdkAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nowState = ref.read(cliChatProvider);
      if (nowState.serverId != capturedServerId ||
          nowState.activeAgent?.id != capturedAgentId) {
        return;
      }
      await ref
          .read(cliChatProvider.notifier)
          .installHistorySdk(confirmed: true);
    }
  }

  void _openAgentManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentManagementView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CliChatState>(cliChatProvider, (previous, next) {
      _handleChatStateChange(previous, next);
    });

    final cliState = ref.watch(cliChatProvider);
    final connState = ref.watch(serverConnectionProvider);
    _listenError(context, cliState);

    if (!connState.isConnected) {
      return Scaffold(
        body: Center(
          child: OfflineStateView(
            onConnect: () =>
                ref.read(serverConnectionProvider.notifier).connect(),
          ),
        ),
      );
    }

    if (cliState.agents.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 64,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.cliNoAgentsConfigured,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openAgentManagement(context),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(context.l10n.cliManageAgentsGuide),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide =
        MediaQuery.sizeOf(context).width >= LayoutBreakpoints.compactMax;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 320,
              // Material 底色面板: 与 AI 会话侧栏一致, ListTile ink 落点正确。
              child: Material(
                color: context.colorScheme.surfaceContainerLowest,
                child: _buildSidebar(context, cliState),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildMainContent(context, cliState)),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Material(
            color: context.colorScheme.surfaceContainerLowest,
            child: _buildSidebar(context, cliState, isDrawer: true),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: context.colorScheme.surface,
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    key: const Key('cli_mobile_session_drawer_button'),
                    icon: const Icon(Icons.view_sidebar_outlined),
                    tooltip: context.l10n.chatSessionsTooltip,
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                if (cliState.activeAgent != null)
                  Expanded(
                    child: Text(
                      cliState.activeAgent!.name,
                      style: context.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                if (cliState.activeAgent != null && cliState.terminal == null)
                  IconButton(
                    icon: const Icon(Icons.terminal, size: 20),
                    tooltip: context.l10n.cliOpenTerminal,
                    onPressed: () =>
                        ref.read(cliChatProvider.notifier).openTerminal(),
                  ),
                IconButton(
                  key: const Key('cli_mobile_appbar_settings_button'),
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: context.l10n.manageAgents,
                  onPressed: () => _openAgentManagement(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildMainContent(context, cliState)),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    CliChatState state, {
    bool isDrawer = false,
  }) {
    final notifier = ref.read(cliChatProvider.notifier);
    final registry = ref.watch(agentRegistryProvider);
    final serverId = state.serverId;
    final agentId = state.activeAgent?.id;
    ChatLaunchPreference preference = const ChatLaunchPreference();
    if (serverId != null && agentId != null) {
      try {
        preference = ref
            .watch(localStorageServiceProvider)
            .getChatLaunchPreference(serverId, agentId, cli: true);
      } catch (_) {}
    }

    return Column(
      children: [
        // Top section: Agent Dropdown
        Entrance(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.cliSelectAgent,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    IconButton(
                      key: const Key('cli_sidebar_settings_button'),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      tooltip: context.l10n.manageAgents,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openAgentManagement(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('cli_agent_dropdown'),
                        isExpanded: true,
                        initialValue: state.activeAgent?.id,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VRadius.input),
                          ),
                        ),
                        items: state.agents.map((agent) {
                          final serverId = state.serverId;
                          String? defaultAgentId;
                          try {
                            defaultAgentId = serverId != null
                                ? ref
                                      .read(localStorageServiceProvider)
                                      .getDefaultAgentId(serverId, cli: true)
                                : null;
                          } catch (_) {}
                          final isDefault = agent.id == defaultAgentId;
                          return DropdownMenuItem<String>(
                            value: agent.id,
                            child: Text(
                              isDefault
                                  ? '${agent.name} (${agent.cliCommand}) · ${context.l10n.defaultBadge}'
                                  : '${agent.name} (${agent.cliCommand})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            notifier.selectAgent(id);
                          }
                        },
                      ),
                    ),
                    if (state.activeAgent != null) ...[
                      const SizedBox(width: 6),
                      Builder(
                        builder: (ctx) {
                          final serverId = state.serverId;
                          String? defaultAgentId;
                          try {
                            defaultAgentId = serverId != null
                                ? ref
                                      .read(localStorageServiceProvider)
                                      .getDefaultAgentId(serverId, cli: true)
                                : null;
                          } catch (_) {}
                          final isDefault =
                              state.activeAgent?.id == defaultAgentId;
                          return IconButton(
                            key: const Key('cli_set_default_agent_button'),
                            icon: Icon(
                              isDefault
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isDefault
                                  ? context.colorScheme.primary
                                  : context.colorScheme.outline,
                            ),
                            tooltip: isDefault
                                ? context.l10n.isDefaultAgent
                                : context.l10n.setAsDefaultAgent,
                            onPressed: () async {
                              final currentId = state.activeAgent?.id;
                              if (currentId == null) return;
                              await notifier.setDefaultAgent(
                                currentId == defaultAgentId ? null : currentId,
                              );
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        // Environment status & Guide Banner
        if (state.activeAgent != null)
          Entrance(
            index: 1,
            child: _buildAgentEnvironmentGuide(
              context,
              state.activeAgent!,
              registry,
            ),
          ),

        // Session list controls (Only if hasHistory == true)
        if (state.hasHistory) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const Key('cli_new_draft_button'),
                    onPressed: state.isSending || state.terminal != null
                        ? null
                        : () {
                            notifier.createDraft();
                            if (isDrawer) Navigator.of(context).maybePop();
                          },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.cliNewDraft),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('cli_refresh_sessions_button'),
                  tooltip: context.l10n.cliRefreshSessions,
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: state.isLoading
                      ? null
                      : () => notifier.refreshSessions(cwd: state.cwd),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  context.l10n.sessionLaunchMode,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<ChatLaunchMode>(
                    key: const Key('cli_chat_launch_mode_selector'),
                    value: preference.mode,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurface,
                    ),
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: ChatLaunchMode.rememberLast,
                        child: Text(context.l10n.chatLaunchRememberLast),
                      ),
                      DropdownMenuItem(
                        value: ChatLaunchMode.fixed,
                        child: Text(context.l10n.chatLaunchFixedSession),
                      ),
                      DropdownMenuItem(
                        value: ChatLaunchMode.blankDraft,
                        child: Text(context.l10n.chatLaunchBlankDraft),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        notifier.setLaunchPreference(
                          ChatLaunchPreference(
                            mode: mode,
                            sessionId: mode == ChatLaunchMode.fixed
                                ? (state.activeSession?.id ??
                                      state.sessions.firstOrNull?.id)
                                : null,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // CWD Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('cli_cwd_filter_field'),
                    controller: _cwdController,
                    decoration: InputDecoration(
                      hintText: context.l10n.cliFilterCwdHint,
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.input),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (val) {
                      notifier.refreshSessions(cwd: val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('cli_apply_cwd_button'),
                  tooltip: context.l10n.cliFilterCwdAction,
                  icon: const Icon(Icons.filter_list, size: 18),
                  onPressed: () {
                    notifier.refreshSessions(cwd: _cwdController.text.trim());
                  },
                ),
                IconButton(
                  key: const Key('cli_clear_cwd_button'),
                  tooltip: context.l10n.cliClearCwdAction,
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _cwdController.clear();
                    notifier.refreshSessions(cwd: '');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Sessions List Header
          Entrance(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text(
                    context.l10n.cliSessionsHeader,
                    style: context.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (state.isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),

          // Sessions List View
          Expanded(
            child: _buildSessionListView(
              context,
              state,
              notifier,
              isDrawer: isDrawer,
              preference: preference,
            ),
          ),
        ] else ...[
          const Spacer(),
        ],
      ],
    );
  }

  Widget _buildAgentEnvironmentGuide(
    BuildContext context,
    AgentProfile agent,
    AgentRegistryState registry,
  ) {
    final runtime = registry.agents
        .where((a) => a.profile.id == agent.id)
        .firstOrNull;
    final isUnready =
        runtime != null &&
        (runtime.status.kind == AgentEnvironmentStatusKind.cliMissing ||
            runtime.status.kind == AgentEnvironmentStatusKind.notLoggedIn);

    if (!isUnready) return const SizedBox.shrink();

    final warning = context.vWarning;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VRadius.input),
        border: Border.all(color: warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warning, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.cliAgentNeedsSetup,
                  style: context.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _openAgentManagement(context),
              child: Text(
                context.l10n.cliManageAgentsGuide,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionListView(
    BuildContext context,
    CliChatState state,
    CliChatNotifier notifier, {
    bool isDrawer = false,
    required ChatLaunchPreference preference,
  }) {
    if (state.sessions.isEmpty && !state.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.cliNoSessions,
            style: TextStyle(color: context.colorScheme.outline, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 首次加载: 按会话行形状铺骨架, 替代转圈。
    if (state.sessions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: VSpace.sm),
        children: const [
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      );
    }

    final isBusy = state.isSending || state.isLoading || state.terminal != null;

    return ListView.builder(
      itemCount: state.sessions.length + (state.cursor != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.sessions.length) {
          // Load more item
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: TextButton.icon(
                key: const Key('cli_load_more_button'),
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(context.l10n.cliLoadMoreSessions),
                onPressed: state.isLoading
                    ? null
                    : () => notifier.refreshSessions(
                        loadMore: true,
                        cwd: state.cwd,
                      ),
              ),
            ),
          );
        }

        final session = state.sessions[index];
        final isSelected = state.activeSession?.id == session.id;
        final isFixedDefault =
            preference.mode == ChatLaunchMode.fixed &&
            preference.sessionId == session.id;

        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: context.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          title: Text(
            session.title.isEmpty ? session.id : session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: session.cwd != null && session.cwd!.isNotEmpty
              ? Text(
                  session.cwd!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: context.colorScheme.outline,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFixedDefault)
                Tooltip(
                  message: context.l10n.isDefaultSession,
                  child: Icon(
                    Icons.push_pin,
                    key: Key('cli_default_session_badge_${session.id}'),
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                )
              else if (preference.mode == ChatLaunchMode.fixed)
                IconButton(
                  key: Key('cli_set_default_session_${session.id}'),
                  icon: const Icon(Icons.push_pin_outlined, size: 16),
                  tooltip: context.l10n.setAsDefaultSession,
                  onPressed: () => notifier.setLaunchPreference(
                    ChatLaunchPreference(
                      mode: ChatLaunchMode.fixed,
                      sessionId: session.id,
                    ),
                  ),
                ),
              IconButton(
                key: Key('cli_delete_session_${session.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: !state.canDelete
                    ? context.l10n.cliCannotDeleteTooltip
                    : context.l10n.cliDeleteConfirmButton,
                onPressed: (!state.canDelete || isBusy)
                    ? null
                    : () => _confirmDeleteSession(context, session),
              ),
            ],
          ),
          onTap: isBusy
              ? null
              : () {
                  notifier.selectSession(session.id);
                  if (isDrawer) Navigator.of(context).maybePop();
                },
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, CliChatState state) {
    // 1. Terminal is active -> Render xterm TerminalView
    if (state.terminal != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.cliTerminalRunning,
                    style: context.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('cli_close_terminal_button'),
                  onPressed: () =>
                      ref.read(cliChatProvider.notifier).closeTerminal(),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(context.l10n.cliCloseTerminal),
                ),
              ],
            ),
          ),
          Expanded(
            child: SharedTerminalCanvas(
              terminal: state.terminal!,
              backgroundColor: const Color(0xFF1E1E1E),
              onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
                ref
                    .read(cliChatProvider.notifier)
                    .sendTerminalKey(key, isCtrl: isCtrl, isAlt: isAlt);
              },
              onPaste: () =>
                  ref.read(cliChatProvider.notifier).pasteTerminalClipboard(),
            ),
          ),
        ],
      );
    }

    // 2. Active agent is null
    if (state.activeAgent == null) {
      return Center(
        child: Text(
          context.l10n.cliSelectAgent,
          style: TextStyle(color: context.colorScheme.outline),
        ),
      );
    }

    // 3. Mode C: agy / custom (hasHistory == false)
    if (!state.hasHistory) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.terminal_outlined,
                size: 56,
                color: context.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  context.l10n.cliAgyTerminalOnlyNotice,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('cli_open_terminal_button'),
                icon: const Icon(Icons.terminal, size: 18),
                label: Text(context.l10n.cliOpenTerminal),
                onPressed: state.isSending
                    ? null
                    : () => ref.read(cliChatProvider.notifier).openTerminal(),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Mode B: Claude (kind == NativeCliKind.claude)
    if (state.kind == NativeCliKind.claude) {
      return Column(
        children: [
          // Read-only + Terminal guidance banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: context.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.cliClaudeReadOnlyNotice,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('cli_continue_in_terminal_button'),
                  icon: const Icon(Icons.terminal, size: 16),
                  label: Text(context.l10n.cliContinueInTerminal),
                  onPressed: () =>
                      ref.read(cliChatProvider.notifier).openTerminal(),
                ),
              ],
            ),
          ),

          // If SDK is missing, show prompt button
          if (state.errorCode == 'CLI_HISTORY_SDK_MISSING')
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(color: context.vWarning.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: context.vWarning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.cliHistorySdkMissing,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  FilledButton(
                    key: const Key('cli_install_sdk_button'),
                    onPressed: state.isLoading
                        ? null
                        : () => _confirmInstallSdk(context),
                    child: Text(context.l10n.cliInstallSdkAction),
                  ),
                ],
              ),
            ),

          Expanded(child: _buildMessagesList(context, state)),
          ChatRunSettingsStrip(
            settings: state.runSettings,
            capabilities: state.capabilities,
            isStructuredSend: state.structuredSend,
            isBusy: state.isSending,
            tuneButtonKey: const Key('cli_run_settings_button'),
            onOpenSettings: () => _openRunSettings(context, state),
          ),
        ],
      );
    }

    // 5. Mode A: Codex / OpenCode (structuredSend == true)
    return Column(
      children: [
        // Pending approvals section
        if (state.approvals.isNotEmpty) _buildApprovalsSection(context, state),

        // Messages list
        Expanded(child: _buildMessagesList(context, state)),

        // Input & Stop Controls
        _buildStructuredInputArea(context, state),
      ],
    );
  }

  Widget _buildApprovalsSection(BuildContext context, CliChatState state) {
    final notifier = ref.read(cliChatProvider.notifier);
    final warning = context.vWarning;

    return Container(
      color: warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseDot(color: warning, size: 7),
              const SizedBox(width: 8),
              Icon(Icons.admin_panel_settings, color: warning, size: 20),
              const SizedBox(width: 4),
              Text(
                context.l10n.cliApprovalsTitle,
                style: context.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.approvals.map((approval) {
            String detailsPretty;
            try {
              detailsPretty = const JsonEncoder.withIndent(
                '  ',
              ).convert(approval.details);
            } catch (_) {
              detailsPretty = approval.details.toString();
            }

            return ValhallaCard(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(VSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.method,
                    style: monoTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: Text(
                      detailsPretty,
                      style: monoTextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        key: Key('cli_approval_decline_${approval.id}'),
                        onPressed: () =>
                            notifier.respondApproval(approval.id, false),
                        child: Text(context.l10n.cliApprovalDecline),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: Key('cli_approval_allow_${approval.id}'),
                        onPressed: () =>
                            notifier.respondApproval(approval.id, true),
                        child: Text(context.l10n.cliApprovalAllow),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, CliChatState state) {
    if (state.messages.isEmpty) {
      if (state.activeSession == null && state.structuredSend) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 40,
                    color: context.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.cliNewDraftTooltip,
                    style: TextStyle(
                      color: context.colorScheme.outline,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildDraftWorkingDirCard(context, state),
                ],
              ),
            ),
          ),
        );
      }

      return Center(
        child: Text(
          state.activeSession == null
              ? context.l10n.cliNewDraftTooltip
              : context.l10n.cliNoSessions,
          style: TextStyle(color: context.colorScheme.outline, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      key: const Key('cli_messages_list_view'),
      controller: _messagesScrollController,
      padding: const EdgeInsets.all(16),
      findChildIndexCallback: (Key key) {
        if (key is ValueKey<String>) {
          final offset = state.isLoadingOlderMessages ? 1 : 0;
          final id = key.value;
          final idx = state.messages.indexWhere((m) => m.id == id);
          return idx >= 0 ? idx + offset : null;
        }
        return null;
      },
      itemCount:
          (state.isLoadingOlderMessages ? 1 : 0) +
          state.messages.length +
          (state.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingOlderMessages && index == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                key: const Key('cli_older_messages_loading_indicator'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: context.l10n.cliLoadingOlderMessages,
                ),
              ),
            ),
          );
        }

        final messageIndex = state.isLoadingOlderMessages ? index - 1 : index;

        if (messageIndex == state.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('...', style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        final msg = state.messages[messageIndex];
        final isUser = msg.role == 'user';

        return Align(
          key: ValueKey(msg.id),
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? context.colorScheme.primary
                  : context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              msg.text,
              style: TextStyle(
                color: isUser
                    ? context.colorScheme.onPrimary
                    : context.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStructuredInputArea(BuildContext context, CliChatState state) {
    final notifier = ref.read(cliChatProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatRunSettingsStrip(
          settings: state.runSettings,
          capabilities: state.capabilities,
          isStructuredSend: state.structuredSend,
          isBusy: state.isSending,
          tuneButtonKey: const Key('cli_run_settings_button'),
          onOpenSettings: () => _openRunSettings(context, state),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              top: BorderSide(color: context.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _buildComposerActionsMenu(context, state),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('cli_chat_input_field'),
                    controller: _promptController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.l10n.cliInputHint,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.input),
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                if (state.isSending)
                  PressableScale(
                    child: FilledButton.icon(
                      key: const Key('cli_stop_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colorScheme.error,
                        foregroundColor: context.colorScheme.onError,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: () => notifier.stop(),
                      icon: const Icon(Icons.stop, size: 20),
                      label: const SizedBox.shrink(),
                    ),
                  )
                else
                  PressableScale(
                    child: IconButton.filled(
                      key: const Key('cli_send_button'),
                      onPressed: _handleSend,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _insertIntoDraft(String text) {
    final current = _promptController.text;
    final selection = _promptController.selection;
    if (selection.isValid && selection.start >= 0) {
      final before = current.substring(0, selection.start);
      final after = current.substring(selection.end);
      _promptController.text = '$before$text$after';
      _promptController.selection = TextSelection.collapsed(
        offset: selection.start + text.length,
      );
    } else {
      _promptController.text = current.isEmpty ? text : '$current $text';
      _promptController.selection = TextSelection.collapsed(
        offset: _promptController.text.length,
      );
    }
  }

  Widget _buildComposerActionsMenu(BuildContext context, CliChatState state) {
    final hasSkills = state.composerCatalog.skills.isNotEmpty;

    return PopupMenuButton<String>(
      key: const Key('cli_composer_actions_menu_button'),
      icon: const Icon(Icons.add_circle_outline, size: 22),
      tooltip: context.l10n.cliComposerInsertAction,
      enabled: !state.isSending,
      onOpened: () {
        ref.read(cliChatProvider.notifier).refreshComposerCatalog();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('cli_composer_action_commands'),
          value: 'commands',
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.cliActionInsertCommand,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('cli_composer_action_files'),
          value: 'files',
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.cliActionInsertFile,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('cli_composer_action_workdir'),
          value: 'workdir',
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.cliActionInsertWorkdir,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          key: const Key('cli_composer_action_skills'),
          value: 'skills',
          enabled: hasSkills,
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: hasSkills ? null : context.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.insertSkills,
                  style: TextStyle(
                    color: hasSkills ? null : context.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'workdir':
            final dir = state.activeSession?.cwd ?? state.draftCwd ?? '/';
            _insertIntoDraft(dir);
            break;
          case 'commands':
            _showInsertCommandDialog(context);
            break;
          case 'files':
            _showInsertFileDialog(context, state);
            break;
          case 'skills':
            _showInsertSkillDialog(context, state);
            break;
        }
      },
    );
  }

  void _showInsertSkillDialog(BuildContext context, CliChatState state) {
    final skills = state.composerCatalog.skills;
    if (skills.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateEmpty)));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        key: const Key('cli_insert_skills_dialog'),
        title: Text(context.l10n.insertSkills),
        children: skills.map((skill) {
          return SimpleDialogOption(
            key: Key('cli_insert_skill_${skill.id}'),
            onPressed: () {
              Navigator.pop(ctx);
              _insertIntoDraft(skill.insertion);
            },
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.label,
                        style: ctx.textTheme.titleSmall,
                      ),
                      if (skill.description != null &&
                          skill.description!.trim().isNotEmpty)
                        Text(
                          skill.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: ctx.colorScheme.outline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInsertCommandDialog(BuildContext context) {
    final commands = ref.read(commandsProvider).allCommands;
    if (commands.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateEmpty)));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.cliSelectCommandTitle),
        children: commands.map((cmd) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _insertIntoDraft(cmd.command);
            },
            child: Row(
              children: [
                const Icon(Icons.play_arrow, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cmd.title,
                        style: ctx.textTheme.titleSmall,
                      ),
                      Text(
                        cmd.command,
                        style: monoTextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: ctx.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInsertFileDialog(BuildContext context, CliChatState state) {
    final defaultDir = state.activeSession?.cwd ?? state.draftCwd ?? '/';
    final pathController = TextEditingController(text: defaultDir);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.cliActionInsertFile),
        content: TextField(
          controller: pathController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.cliActionInsertFile,
            hintText: '/path/to/file.txt',
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.pop(ctx);
              _insertIntoDraft(val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (pathController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _insertIntoDraft(pathController.text.trim());
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftWorkingDirCard(BuildContext context, CliChatState state) {
    final hasDraft = state.draftCwd != null && state.draftCwd!.isNotEmpty;
    final isSending = state.isSending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.cliDraftWorkingDirLabel,
                style: context.textTheme.titleSmall,
              ),
              const Spacer(),
              if (hasDraft)
                IconButton(
                  key: const Key('cli_draft_cwd_clear_button'),
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: context.l10n.cliClearWorkingDir,
                  visualDensity: VisualDensity.compact,
                  onPressed: isSending
                      ? null
                      : () => ref
                            .read(cliChatProvider.notifier)
                            .setDraftWorkingDirectory(null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(color: context.colorScheme.outlineVariant),
            ),
            child: Text(
              hasDraft ? state.draftCwd! : context.l10n.cliDefaultWorkingDir,
              style: monoTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: hasDraft
                    ? context.colorScheme.onSurface
                    : context.colorScheme.outline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('cli_draft_cwd_browse_button'),
              icon: const Icon(Icons.folder_open, size: 16),
              label: Text(context.l10n.cliBrowseWorkingDir),
              onPressed: isSending
                  ? null
                  : () => _openRemoteDirectoryPicker(
                      context,
                      state.draftCwd ?? '/',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRunSettings(BuildContext context, CliChatState state) {
    ChatRunSettingsDialog.show(
      context,
      initialSettings: state.runSettings,
      capabilities: state.capabilities,
      isStructuredSend: state.structuredSend,
      onSave: (settings) =>
          ref.read(cliChatProvider.notifier).updateRunSettings(settings),
    );
  }

  Future<void> _openRemoteDirectoryPicker(
    BuildContext context,
    String initialPath,
  ) async {
    final initialServerId = ref.read(activeServerProvider)?.id;
    final sftpOps = ref.read(sftpOperationsProvider);
    final notifier = ref.read(cliChatProvider.notifier);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return RemoteDirectoryPickerDialog(
          initialPath: initialPath,
          sftpOperations: sftpOps,
          onSelect: (selectedPath) {
            final currentServerId = ref.read(activeServerProvider)?.id;
            final isConnected = ref.read(serverConnectionProvider).isConnected;
            if (initialServerId == null ||
                currentServerId != initialServerId ||
                !isConnected) {
              return;
            }
            notifier.setDraftWorkingDirectory(selectedPath);
          },
        );
      },
    );
  }
}
