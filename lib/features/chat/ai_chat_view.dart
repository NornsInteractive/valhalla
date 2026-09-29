import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/motion.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../data/models/chat_session.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../../widgets/valhalla_card.dart';
import '../agents/agent_command_confirm_dialog.dart';
import '../agents/agent_management_view.dart';
import '../agents/auth_method_picker_dialog.dart';
import '../agents/interactive_login_provider.dart';
import '../../data/models/chat_launch_preference.dart';
import 'widgets/chat_run_settings_dialog.dart';
import 'widgets/chat_run_settings_strip.dart';

class AiChatView extends ConsumerStatefulWidget {
  const AiChatView({super.key});

  @override
  ConsumerState<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<AiChatView> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedAuthMethodId;
  bool _userNearBottom = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final nearBottom = (max - current) <= 80;
    if (_userNearBottom != nearBottom) {
      _userNearBottom = nearBottom;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _followBottomIfNeeded() {
    if (!_scrollController.hasClients || !_userNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _userNearBottom) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  AgentRuntimeState? _getSingleInstallableCandidate(
    AgentRegistryState registry,
  ) {
    final candidates = registry.agents.where((a) {
      if (a.status.kind != AgentEnvironmentStatusKind.cliMissing &&
          a.status.kind != AgentEnvironmentStatusKind.acpMissing) {
        return false;
      }
      final cmd = a.status.kind == AgentEnvironmentStatusKind.cliMissing
          ? a.profile.installCommand
          : (a.profile.acpInstallCommand ?? a.profile.installCommand);
      return cmd != null && cmd.trim().isNotEmpty;
    }).toList();

    if (candidates.length == 1) {
      return candidates.first;
    }
    return null;
  }

  Future<void> _oneClickInstall(AgentRuntimeState candidate) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) return;

    final command =
        candidate.status.kind == AgentEnvironmentStatusKind.cliMissing
        ? candidate.profile.installCommand
        : (candidate.profile.acpInstallCommand ??
              candidate.profile.installCommand);
    if (command == null || command.trim().isEmpty) return;

    final confirmed = await showAgentCommandConfirmDialog(
      context: context,
      actionType: AgentCommandActionType.install,
      agentName: candidate.profile.name,
      command: command,
      server: activeServer,
    );

    if (confirmed && mounted) {
      await ref
          .read(agentRegistryProvider.notifier)
          .installForCurrentStatus(candidate.profile.id);
    }
  }

  void _showAgentSwitcherModal() {
    final chatState = ref.read(aiChatProvider);
    final notifier = ref.read(aiChatProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final serverId = ref.read(activeServerProvider)?.id;
            String? defaultAgentId;
            try {
              defaultAgentId = serverId != null
                  ? ref
                        .read(localStorageServiceProvider)
                        .getDefaultAgentId(serverId, cli: false)
                  : null;
            } catch (_) {}

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.switchAgent,
                          style: context.textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (chatState.readyAgents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smart_toy_outlined,
                                size: 44,
                                color: context.colorScheme.outline,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.l10n.noReadyAgentsTitle,
                                style: context.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.noReadyAgentsDesc,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.outline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 16,
                                ),
                                label: Text(context.l10n.manageAgents),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showManageAgentsModal();
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...chatState.readyAgents.map((profile) {
                        final isSelected =
                            chatState.activeAgentProfile?.id == profile.id;
                        final isDefault = profile.id == defaultAgentId;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected
                              ? context.colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VRadius.card),
                            side: BorderSide(
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.smart_toy,
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  profile.name,
                                  style: context.textTheme.titleSmall,
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          context.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        VRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n.defaultBadge,
                                      style: context.textTheme.labelSmall
                                          ?.copyWith(
                                            color: context
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              profile.description.isNotEmpty
                                  ? profile.description
                                  : profile.cliCommand,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: Key(
                                    'ai_set_default_agent_${profile.id}',
                                  ),
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
                                    await notifier.setDefaultAgent(
                                      isDefault ? null : profile.id,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: context.colorScheme.primary,
                                  ),
                              ],
                            ),
                            onTap: () {
                              notifier.switchAgent(profile.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: Text(context.l10n.manageAgents),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showManageAgentsModal();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showManageAgentsModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentManagementView()),
    );
  }

  Future<void> _handleSend() async {
    final chatState = ref.read(aiChatProvider);
    if (chatState.activeAgentProfile == null) {
      _showManageAgentsModal();
      return;
    }
    final text = _promptController.text.trim();
    if (text.isEmpty ||
        _isSending ||
        chatState.isGenerating ||
        chatState.isLoadingSettings ||
        chatState.isApplyingSettings) {
      return;
    }

    setState(() {
      _isSending = true;
    });
    _promptController.clear();
    _userNearBottom = true;
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      await ref.read(aiChatProvider.notifier).sendMessage(text);
    } catch (_) {
      // Error handled by provider/state
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }

    if (!mounted) return;
    final afterState = ref.read(aiChatProvider);
    if (!afterState.isGenerating &&
        (afterState.lastErrorCode != null ||
            afterState.authChallenge != null)) {
      if (_promptController.text.isEmpty) {
        _promptController.text = text;
        _promptController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    }
  }

  Future<void> _confirmAndDeleteSession(
    BuildContext context,
    String sessionId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteSessionTitle),
        content: Text(ctx.l10n.deleteSessionConfirmMessage(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteSessionButton'),
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.deleteSessionConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(aiChatProvider.notifier).deleteSession(sessionId);
    }
  }

  String _resolveErrorMessage(String errorCode) {
    if (errorCode == AiChatNotifier.notReadyCode) {
      return context.l10n.agentNotReadyError;
    } else if (errorCode == AiChatNotifier.disconnectedCode) {
      return context.l10n.sshDisconnectedError;
    } else if (errorCode == AiChatNotifier.authRequiredCode) {
      return context.l10n.agentAuthRequiredError;
    } else if (errorCode == 'CHAT_SESSION_IDENTITY_MISMATCH') {
      return context.l10n.chatSessionIdentityMismatch;
    } else {
      return errorCode;
    }
  }

  Widget _buildErrorBanner(String errorCode) {
    final message = _resolveErrorMessage(errorCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colorScheme.errorContainer.withValues(alpha: 0.8),
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
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (errorCode == AiChatNotifier.notReadyCode)
            TextButton(
              onPressed: _showManageAgentsModal,
              child: Text(
                context.l10n.manageAgents,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onErrorContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      final prevMessages = previous?.activeSession?.messages;
      final nextMessages = next.activeSession?.messages;
      final hasNewTokenOrMessage =
          next.isGenerating ||
          (prevMessages?.length != nextMessages?.length) ||
          (prevMessages?.lastOrNull?.content !=
              nextMessages?.lastOrNull?.content) ||
          (prevMessages?.lastOrNull?.thinking !=
              nextMessages?.lastOrNull?.thinking);

      if (hasNewTokenOrMessage) {
        _followBottomIfNeeded();
      }
    });

    final isDesktop = context.isDesktop;
    final chatState = ref.watch(aiChatProvider);

    return Scaffold(
      drawer: !isDesktop
          ? Drawer(child: _buildSessionsDrawer(chatState, isDesktop))
          : null,
      body: Row(
        children: [
          if (isDesktop) ...[
            SizedBox(
              width: 320,
              child: _buildSessionsDrawer(chatState, isDesktop),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                _buildHeaderBar(chatState, isDesktop),
                const Divider(height: 1),
                if (chatState.lastErrorCode != null)
                  _buildErrorBanner(chatState.lastErrorCode!),
                _AcpSessionNoticeBar(
                  acpSessionRestored: chatState.acpSessionRestored,
                  acpSessionRestartDetected:
                      chatState.acpSessionRestartDetected,
                  onAcknowledgeRestart: () => ref
                      .read(aiChatProvider.notifier)
                      .acknowledgeAcpSessionRestart(),
                ),
                Expanded(child: _buildMessageList(chatState)),
                if (chatState.pendingPermission != null)
                  _buildPermissionCard(chatState.pendingPermission!),
                if (chatState.authChallenge != null)
                  _buildAuthChallengeCard(chatState.authChallenge!),
                const Divider(height: 1),
                _buildInputArea(chatState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(AiChatState state, bool isDesktop) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.colorScheme.surface,
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) => IconButton(
                key: const Key('ai_mobile_session_drawer_button'),
                icon: const Icon(Icons.view_sidebar_outlined, size: 20),
                tooltip: context.l10n.chatSessionsTooltip,
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Flexible(
            child: InkWell(
              onTap: _showAgentSwitcherModal,
              borderRadius: BorderRadius.circular(VRadius.input),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.activeAgentProfile != null
                          ? Icons.psychology
                          : Icons.smart_toy_outlined,
                      size: 18,
                      color: state.activeAgentProfile != null
                          ? context.colorScheme.primary
                          : context.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        state.activeAgentProfile?.name ??
                            context.l10n.noAgentAvailable,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: state.activeAgentProfile != null
                              ? null
                              : context.colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            key: const Key('shareSessionsHeaderButton'),
            icon: Icon(
              state.shareAgentSessions
                  ? Icons.folder_shared
                  : Icons.folder_shared_outlined,
              size: 18,
              color: state.shareAgentSessions
                  ? context.colorScheme.primary
                  : context.colorScheme.outline,
            ),
            tooltip: state.shareAgentSessions
                ? context.l10n.shareAgentSessionsEnabled
                : context.l10n.shareAgentSessionsDisabled,
            onPressed: state.isGenerating
                ? null
                : () => ref
                      .read(aiChatProvider.notifier)
                      .setShareAgentSessions(!state.shareAgentSessions),
          ),
          if (state.isGenerating) ...[
            PulseDot(color: context.colorScheme.primary, size: 7),
            const SizedBox(width: 8),
            Text(
              context.l10n.acpStreaming,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsDrawer(AiChatState state, bool isDesktop) {
    final notifier = ref.read(aiChatProvider.notifier);
    final serverId = ref.watch(activeServerProvider)?.id;
    final agentId = state.activeAgentProfile?.id;
    ChatLaunchPreference preference = const ChatLaunchPreference();
    String? defaultAgentId;
    if (serverId != null) {
      try {
        final storage = ref.watch(localStorageServiceProvider);
        defaultAgentId = storage.getDefaultAgentId(serverId, cli: false);
        if (agentId != null) {
          preference = storage.getChatLaunchPreference(
            serverId,
            agentId,
            cli: false,
          );
        }
      } catch (_) {}
    }
    final isDefaultAgent =
        state.activeAgentProfile != null &&
        state.activeAgentProfile!.id == defaultAgentId;

    // Material 而非 Container: ListTile/SwitchListTile 的 ink 必须落在
    // 直接的 Material 上, 否则 debug 断言判定 ink 被不透明装饰遮挡。
    return Material(
      color: context.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Entrance(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.newSession),
                  onPressed: () {
                    notifier.createNewSession();
                    if (!isDesktop) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            if (state.activeAgentProfile != null) ...[
              Entrance(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDefaultAgent ? Icons.star : Icons.star_border,
                        size: 16,
                        color: isDefaultAgent
                            ? context.colorScheme.primary
                            : context.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${context.l10n.defaultAgentTitle}: ${state.activeAgentProfile!.name}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurface,
                            fontWeight: isDefaultAgent
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefaultAgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(VRadius.pill),
                          ),
                          child: Text(
                            context.l10n.defaultBadge,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )
                      else
                        TextButton(
                          key: const Key('ai_set_default_agent_button'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => notifier.setDefaultAgent(
                            state.activeAgentProfile!.id,
                          ),
                          child: Text(
                            context.l10n.setDefaultAgent,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Entrance(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
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
                          key: const Key('ai_chat_launch_mode_selector'),
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
                                      ? (state.activeSessionId ??
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
              ),
              const Divider(height: 1),
            ],
            Entrance(
              index: 3,
              child: SwitchListTile.adaptive(
                key: const Key('shareAgentSessionsSwitch'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                dense: true,
                title: Text(
                  context.l10n.shareAgentSessionsTitle,
                  style: context.textTheme.titleSmall,
                ),
                subtitle: Text(
                  context.l10n.shareAgentSessionsSubtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                value: state.shareAgentSessions,
                onChanged: state.isGenerating
                    ? null
                    : (val) => notifier.setShareAgentSessions(val),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: state.sessions.length,
                itemBuilder: (context, index) {
                  final session = state.sessions[index];
                  final isSelected = session.id == state.activeSessionId;
                  final isFixedDefault =
                      preference.mode == ChatLaunchMode.fixed &&
                      preference.sessionId == session.id;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: context.colorScheme.primaryContainer
                        .withValues(alpha: 0.2),
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: isSelected ? context.colorScheme.primary : null,
                    ),
                    title: Text(
                      session.title,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFixedDefault)
                          Tooltip(
                            message: context.l10n.isDefaultSession,
                            child: Icon(
                              Icons.push_pin,
                              key: Key('default_session_badge_${session.id}'),
                              size: 16,
                              color: context.colorScheme.primary,
                            ),
                          )
                        else if (preference.mode == ChatLaunchMode.fixed)
                          IconButton(
                            key: Key('set_default_session_${session.id}'),
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
                          key: Key('delete_session_${session.id}'),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => _confirmAndDeleteSession(
                            context,
                            session.id,
                            session.title,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      notifier.selectSession(session.id);
                      if (!isDesktop) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(AiChatState state) {
    final session = state.activeSession;
    final messages = session?.messages ?? [];

    if (messages.isEmpty) {
      final registry = ref.watch(agentRegistryProvider);
      final hasUnreadyAgents = registry.agents.any(
        (a) =>
            a.status.kind == AgentEnvironmentStatusKind.cliMissing ||
            a.status.kind == AgentEnvironmentStatusKind.acpMissing ||
            a.status.kind == AgentEnvironmentStatusKind.notLoggedIn,
      );
      final singleCandidate = _getSingleInstallableCandidate(registry);
      final isConnected = ref.watch(serverConnectionProvider).isConnected;

      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Entrance(
                index: 0,
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 54,
                  color: context.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                index: 1,
                child: Text(
                  context.l10n.aiOpsAgentTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.aiOpsEmptySubtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              if (state.activeAgentProfile == null) ...[
                const SizedBox(height: 16),
                if (hasUnreadyAgents) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      context.l10n.agentNeedsInstallOrReadyPrompt,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Entrance(
                  index: 2,
                  child: singleCandidate != null
                      ? (singleCandidate.isInstalling
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.agentStatusInstalling,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              )
                            : FilledButton.icon(
                                icon: const Icon(Icons.download, size: 16),
                                label: Text(
                                  context.l10n.agentActionAutoInstall,
                                ),
                                onPressed: !isConnected
                                    ? null
                                    : () => _oneClickInstall(singleCandidate),
                              ))
                      : FilledButton.tonalIcon(
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: Text(context.l10n.manageAgents),
                          onPressed: _showManageAgentsModal,
                        ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.role == MessageRole.user) {
          return KeyedSubtree(
            key: ValueKey('user_msg_${msg.id}'),
            child: _buildUserBubble(msg),
          );
        }
        return KeyedSubtree(
          key: ValueKey('assistant_msg_${msg.id}'),
          child: _buildAssistantBubble(msg),
        );
      },
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          msg.content,
          style: TextStyle(
            color: context.colorScheme.onPrimaryContainer,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thinking Accordion
            if (msg.thinking != null && msg.thinking!.isNotEmpty) ...[
              _ThinkingBlock(text: msg.thinking!),
            ],

            // Plan Execution Steps
            if (msg.planSteps.isNotEmpty) ...[
              ValhallaCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(VSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 16,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.executionPlan,
                          style: context.textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...msg.planSteps.map((step) {
                      Widget leading;
                      switch (step.status) {
                        case PlanStepStatus.completed:
                          leading = Icon(
                            Icons.check_circle,
                            size: 14,
                            color: context.vSuccess,
                          );
                          break;
                        case PlanStepStatus.inProgress:
                          // 运行中步骤: 语义呼吸点。
                          leading = PulseDot(color: context.vWarning, size: 6);
                          break;
                        case PlanStepStatus.failed:
                          leading = Icon(
                            Icons.cancel,
                            size: 14,
                            color: context.vDanger,
                          );
                          break;
                        case PlanStepStatus.pending:
                          leading = Icon(
                            Icons.radio_button_unchecked,
                            size: 14,
                            color: context.colorScheme.outline,
                          );
                          break;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            leading,
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step.title,
                                style: context.textTheme.bodySmall?.copyWith(
                                  decoration:
                                      step.status == PlanStepStatus.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Tool Execution Cards
            if (msg.toolExecutions.isNotEmpty) ...[
              ...msg.toolExecutions.map((tool) {
                return ValhallaCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.black,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 14,
                            color: context.vSuccess,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tool.command,
                              style: monoTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.vSuccess,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tool.executionTimeMs != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${tool.executionTimeMs} ms',
                              style: monoTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (tool.output != null && tool.output!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(VRadius.input),
                          ),
                          child: Text(
                            tool.output!,
                            style: monoTextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],

            // Markdown Message Content
            if (msg.content.isNotEmpty)
              ValhallaCard(
                color: context.colorScheme.surface,
                padding: const EdgeInsets.all(VSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(code: monoTextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        tooltip: context.l10n.copy,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: msg.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.chatMessageCopied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(PermissionRequest req) {
    final notifier = ref.read(aiChatProvider.notifier);
    final danger = context.vDanger;

    return Container(
      margin: const EdgeInsets.all(VSpace.md),
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(color: danger.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseDot(color: danger, size: 7),
              const SizedBox(width: 8),
              Icon(Icons.warning, color: danger, size: 20),
              const SizedBox(width: 4),
              Text(
                context.l10n.permissionRequired,
                style: context.textTheme.titleSmall?.copyWith(color: danger),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(req.description, style: context.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
            child: Text(
              req.command,
              style: monoTextStyle(fontSize: 12, color: context.vWarning),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => notifier.respondPermission(false),
                child: Text(context.l10n.permissionReject),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colorScheme.error,
                ),
                onPressed: () => notifier.respondPermission(true),
                child: Text(context.l10n.permissionAllowOnce),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleProceedAuth(
    String? methodId,
    AuthChallenge challenge,
  ) async {
    final activeServer = ref.read(activeServerProvider);
    final registry = ref.read(agentRegistryProvider);
    final profile =
        registry.findRuntime(challenge.agentId)?.profile ??
        ref.read(aiChatProvider).activeAgentProfile;

    if (challenge.methods.isEmpty) {
      await ref.read(aiChatProvider.notifier).respondAuth(null);
      if (mounted) {
        _showManageAgentsModal();
      }
      return;
    }

    await ref.read(aiChatProvider.notifier).respondAuth(methodId);

    if (profile != null &&
        profile.loginCommand != null &&
        profile.loginCommand!.isNotEmpty &&
        activeServer != null &&
        mounted) {
      final confirmed = await showAgentCommandConfirmDialog(
        context: context,
        actionType: AgentCommandActionType.login,
        agentName: profile.name,
        command: profile.loginCommand!,
        server: activeServer,
      );
      if (confirmed && mounted) {
        final sshClient = ref
            .read(sshClientManagerProvider)
            .getClient(activeServer.id);
        final result = await ref.read(interactiveLoginLauncherProvider)(
          context: context,
          agentName: profile.name,
          command: profile.loginCommand!,
          serverName: activeServer.name,
          sshClient: sshClient,
        );
        if (result == true && mounted) {
          await ref.read(agentRegistryProvider.notifier).loginAgent(profile.id);
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.agentAuthRetryHint)));
    }
  }

  Widget _buildAuthChallengeCard(AuthChallenge challenge) {
    final notifier = ref.read(aiChatProvider.notifier);
    final connState = ref.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;
    final registry = ref.watch(agentRegistryProvider);
    final profile =
        registry.findRuntime(challenge.agentId)?.profile ??
        ref.watch(aiChatProvider).activeAgentProfile;
    final agentName = profile?.name ?? challenge.agentId;

    final String? selectedMethodId =
        (_selectedAuthMethodId != null &&
            challenge.methods.any((m) => m.id == _selectedAuthMethodId))
        ? _selectedAuthMethodId
        : (challenge.methods.isNotEmpty ? challenge.methods.first.id : null);
    final warning = context.vWarning;

    return Container(
      margin: const EdgeInsets.all(VSpace.md),
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(color: warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.agentAuthRequiredTitle,
                  style: context.textTheme.titleSmall?.copyWith(color: warning),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
                child: Text(
                  agentName,
                  style: monoTextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.agentAuthRequiredDesc,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          if (challenge.methods.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.agentAuthNoMethodsNotice,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (challenge.methods.length == 1) ...[
            Text(
              context.l10n.agentAuthMethodLabel,
              style: context.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(color: context.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.methods.first.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (challenge.methods.first.description != null &&
                      challenge.methods.first.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      challenge.methods.first.description!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Text(
                  context.l10n.agentAuthMethodLabel,
                  style: context.textTheme.labelMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(
                    context.l10n.agentAuthPickerTitle(agentName),
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final picked = await showAuthMethodPickerDialog(
                      context: context,
                      agentName: agentName,
                      methods: challenge.methods,
                    );
                    if (picked != null && mounted) {
                      setState(() => _selectedAuthMethodId = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: selectedMethodId,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedAuthMethodId = val);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.input),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: challenge.methods.map((method) {
                    final isSelected = (selectedMethodId == method.id);
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedAuthMethodId = method.id),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: method.id,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    method.name,
                                    style: context.textTheme.bodyMedium
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                  ),
                                  if (method.description != null &&
                                      method.description!.isNotEmpty)
                                    Text(
                                      method.description!,
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.colorScheme.outline,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => notifier.respondAuth(null),
                child: Text(context.l10n.agentAuthCancelButton),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: !isConnected
                    ? context.l10n.sshDisconnectedAgentWarning
                    : '',
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.vWarning,
                  ),
                  onPressed: !isConnected
                      ? null
                      : () => _handleProceedAuth(selectedMethodId, challenge),
                  child: Text(context.l10n.agentAuthProceedButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AiChatState state) {
    final hasActiveAgent = state.activeAgentProfile != null;
    final registry = ref.watch(agentRegistryProvider);
    final hasUnreadyAgents = registry.agents.any(
      (a) =>
          a.status.kind == AgentEnvironmentStatusKind.cliMissing ||
          a.status.kind == AgentEnvironmentStatusKind.acpMissing ||
          a.status.kind == AgentEnvironmentStatusKind.notLoggedIn,
    );
    final singleCandidate = _getSingleInstallableCandidate(registry);
    final isConnected = ref.watch(serverConnectionProvider).isConnected;

    return Container(
      padding: const EdgeInsets.all(12),
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasActiveAgent) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.input),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasUnreadyAgents
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      size: 18,
                      color: hasUnreadyAgents
                          ? context.vWarning
                          : context.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasUnreadyAgents
                            ? context.l10n.agentNeedsInstallOrReadyPrompt
                            : context.l10n.noAgentAvailablePrompt,
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (singleCandidate != null) ...[
                      if (singleCandidate.isInstalling)
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
                        FilledButton.icon(
                          icon: const Icon(Icons.download, size: 14),
                          label: Text(context.l10n.agentActionAutoInstall),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: !isConnected
                              ? null
                              : () => _oneClickInstall(singleCandidate),
                        ),
                    ] else ...[
                      TextButton.icon(
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(context.l10n.manageAgents),
                        onPressed: _showManageAgentsModal,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ChatRunSettingsStrip(
              settings: state.runSettings,
              capabilities: state.capabilities,
              isStructuredSend: true,
              isBusy:
                  state.isGenerating ||
                  state.isLoadingSettings ||
                  state.isApplyingSettings,
              isLoadingSettings: state.isLoadingSettings,
              tuneButtonKey: const Key('chat_run_settings_button'),
              onOpenSettings: () async {
                if (state.isGenerating ||
                    state.isLoadingSettings ||
                    state.isApplyingSettings) {
                  return;
                }
                final currentServerId = ref.read(activeServerProvider)?.id;
                final currentAgentId = state.activeAgentProfile?.id;

                final ok = await ref
                    .read(aiChatProvider.notifier)
                    .prepareRunSettings();
                if (!mounted) return;
                if (!ok) {
                  final freshState = ref.read(aiChatProvider);
                  final code =
                      freshState.lastErrorCode ?? AiChatNotifier.notReadyCode;
                  final message = _resolveErrorMessage(code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: context.vDanger,
                    ),
                  );
                  return;
                }

                final freshState = ref.read(aiChatProvider);
                final freshServerId = ref.read(activeServerProvider)?.id;
                if (freshServerId != currentServerId ||
                    freshState.activeAgentProfile?.id != currentAgentId) {
                  return;
                }

                await ChatRunSettingsDialog.show(
                  context,
                  initialSettings: freshState.runSettings,
                  capabilities: freshState.capabilities,
                  isStructuredSend: true,
                  onSave: (settings) => ref
                      .read(aiChatProvider.notifier)
                      .updateRunSettings(settings),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chatPromptInput'),
                    controller: _promptController,
                    enabled:
                        hasActiveAgent &&
                        !_isSending &&
                        !state.isGenerating &&
                        !state.isLoadingSettings &&
                        !state.isApplyingSettings,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: hasActiveAgent
                          ? context.l10n.inputPromptHint
                          : (hasUnreadyAgents
                                ? context.l10n.agentNeedsInstallOrReadyHint
                                : context.l10n.noAgentAvailableHint),
                      hintStyle: const TextStyle(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.input),
                      ),
                    ),
                    onSubmitted:
                        (hasActiveAgent &&
                            !_isSending &&
                            !state.isGenerating &&
                            !state.isLoadingSettings &&
                            !state.isApplyingSettings)
                        ? (_) => _handleSend()
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (state.isGenerating)
                  PressableScale(
                    child: IconButton.filled(
                      key: const Key('stopGenerationButton'),
                      icon: const Icon(Icons.stop, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: context.colorScheme.error,
                        foregroundColor: context.colorScheme.onError,
                      ),
                      tooltip: context.l10n.stopGeneration,
                      onPressed: () =>
                          ref.read(aiChatProvider.notifier).stopGeneration(),
                    ),
                  )
                else
                  PressableScale(
                    child: IconButton.filled(
                      key: const Key('sendMessageButton'),
                      icon: const Icon(Icons.send, size: 18),
                      onPressed:
                          (!hasActiveAgent ||
                              _isSending ||
                              state.isLoadingSettings ||
                              state.isApplyingSettings)
                          ? null
                          : _handleSend,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcpSessionNoticeBar extends StatefulWidget {
  final bool? acpSessionRestored;
  final bool acpSessionRestartDetected;
  final VoidCallback onAcknowledgeRestart;

  const _AcpSessionNoticeBar({
    required this.acpSessionRestored,
    required this.acpSessionRestartDetected,
    required this.onAcknowledgeRestart,
  });

  @override
  State<_AcpSessionNoticeBar> createState() => _AcpSessionNoticeBarState();
}

class _AcpSessionNoticeBarState extends State<_AcpSessionNoticeBar> {
  Timer? _restoredTimer;
  bool _showRestored = false;

  @override
  void initState() {
    super.initState();
    if (!widget.acpSessionRestartDetected &&
        widget.acpSessionRestored == true) {
      _showRestored = true;
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _AcpSessionNoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.acpSessionRestartDetected) {
      _restoredTimer?.cancel();
      if (_showRestored) {
        setState(() => _showRestored = false);
      }
    } else if (widget.acpSessionRestored == true) {
      if (oldWidget.acpSessionRestored != true ||
          oldWidget.acpSessionRestartDetected) {
        _startTimer();
        _showRestored = true;
      }
    } else {
      _restoredTimer?.cancel();
      if (_showRestored) {
        setState(() => _showRestored = false);
      }
    }
  }

  void _startTimer() {
    _restoredTimer?.cancel();
    _restoredTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showRestored = false);
      }
    });
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // 1. Context lost restart detected: sticky error/warning banner requiring explicit dismiss
    if (widget.acpSessionRestartDetected) {
      return Container(
        key: const Key('acpSessionRestartNotice'),
        width: double.infinity,
        color: context.colorScheme.errorContainer.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: context.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.acpSessionRestartNotice,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: context.colorScheme.onErrorContainer,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: widget.onAcknowledgeRestart,
            ),
          ],
        ),
      );
    }

    // 2. Session restored: transient 2s success notice
    if (!widget.acpSessionRestartDetected &&
        widget.acpSessionRestored == true &&
        _showRestored) {
      return Container(
        key: const Key('acpSessionRestoredNotice'),
        width: double.infinity,
        color: context.vSuccess.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.restore, size: 18, color: context.vSuccess),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.acpSessionRestored,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.vSuccess,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: context.vSuccess),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () {
                _restoredTimer?.cancel();
                setState(() => _showRestored = false);
              },
            ),
          ],
        ),
      );
    }

    // 3. acpSessionRestored == null, or false without restart detected: display nothing
    return const SizedBox.shrink();
  }
}

/// 折叠的思考过程块: 手风琴头部 + [AnimatedRotation] 箭头 +
/// [AnimatedCrossFade] 展开/收起 (VTiming.base / VCurves.emphasized)。
class _ThinkingBlock extends StatefulWidget {
  final String text;

  const _ThinkingBlock({required this.text});

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(VRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VSpace.md,
                vertical: VSpace.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.thinking,
                      style: context.textTheme.labelMedium,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: VTiming.base,
                    curve: VCurves.emphasized,
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: VTiming.base,
            firstCurve: VCurves.emphasized,
            secondCurve: VCurves.emphasized,
            sizeCurve: VCurves.emphasized,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                VSpace.md,
                0,
                VSpace.md,
                VSpace.md,
              ),
              child: SelectableText(
                widget.text,
                style: monoTextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
