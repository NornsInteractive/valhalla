import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:file_picker/file_picker.dart';
import '../../data/models/chat_launch_preference.dart';
import '../../infrastructure/acp/acp_client_adapter.dart'
    show AcpRemoteSession, AcpSlashCommand;
import '../../infrastructure/cli/agent_execution_target.dart';
import 'widgets/chat_run_settings_dialog.dart';
import 'widgets/chat_run_settings_strip.dart';
import 'widgets/chat_commands_skills_dialog.dart';
import 'widgets/image_zoom_dialog.dart';
import 'widgets/remote_workspace_browser_dialog.dart';
import 'widgets/session_recovery_banner.dart';

class AiChatView extends ConsumerStatefulWidget {
  const AiChatView({super.key});

  @override
  ConsumerState<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<AiChatView> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _sessionSearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedAuthMethodId;
  String? _scrolledSessionId;
  bool _userNearBottom = true;
  bool _isSending = false;
  bool _isLoadingComposerCommands = false;

  @override
  void initState() {
    super.initState();
    final initialDraft = ref.read(aiChatProvider).draftText;
    if (initialDraft.isNotEmpty) {
      _promptController.text = initialDraft;
      _promptController.selection = TextSelection.collapsed(
        offset: initialDraft.length,
      );
    }
    _scrolledSessionId = ref.read(aiChatProvider).activeSessionId;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
    _sessionSearchController.dispose();
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
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    final isRecovering =
        chatState.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        chatState.recoveryStatus == SessionRecoveryStatus.syncing;
    if (!isConnected || isRecovering) return;

    final text = _promptController.text.trim();
    if ((text.isEmpty && chatState.attachments.isEmpty) ||
        _isSending ||
        chatState.isGenerating ||
        chatState.isLoadingSettings ||
        chatState.isApplyingSettings ||
        chatState.isLoadingSessions ||
        chatState.isLoadingMessages) {
      return;
    }

    final sentServerId = ref.read(activeServerProvider)?.id;
    final sentProfile = chatState.activeAgentProfile;
    final sentAgentId = sentProfile?.id;
    final sentSessionId = chatState.activeSessionId;
    final sentLaunchKey = sentProfile == null
        ? null
        : '${sentProfile.executionTarget}|${sentProfile.containerBinding}|'
              '${sentProfile.containerReference}|${sentProfile.containerUser}|${sentProfile.acpCommand}';

    setState(() {
      _isSending = true;
    });
    _promptController.clear();
    ref.read(aiChatProvider.notifier).updateDraftText('');
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
    final currentServerId = ref.read(activeServerProvider)?.id;
    final afterState = ref.read(aiChatProvider);
    final currentProfile = afterState.activeAgentProfile;
    final currentAgentId = currentProfile?.id;
    final currentSessionId = afterState.activeSessionId;
    final currentLaunchKey = currentProfile == null
        ? null
        : '${currentProfile.executionTarget}|${currentProfile.containerBinding}|'
              '${currentProfile.containerReference}|${currentProfile.containerUser}|${currentProfile.acpCommand}';

    final targetMatches =
        currentServerId == sentServerId &&
        currentAgentId == sentAgentId &&
        currentSessionId == sentSessionId &&
        currentLaunchKey == sentLaunchKey;

    if (!afterState.isGenerating &&
        (afterState.lastErrorCode != null ||
            afterState.authChallenge != null)) {
      if (targetMatches && _promptController.text.isEmpty) {
        _promptController.text = text;
        _promptController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        ref.read(aiChatProvider.notifier).updateDraftText(text);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.deleteSessionConfirmMessage(title)),
            const SizedBox(height: 8),
            Text(
              ctx.l10n.deleteSessionLocalOnlyNotice,
              style: ctx.textTheme.bodySmall?.copyWith(
                color: ctx.colorScheme.outline,
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

  Future<void> _showRenameSessionDialog(
    BuildContext context,
    String sessionId,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('chat_rename_session_dialog'),
        title: Text(context.l10n.rename),
        content: TextField(
          key: const Key('chat_rename_session_input'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.sessionTitle),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('chat_rename_session_confirm_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final newTitle = controller.text.trim();
      if (newTitle.isNotEmpty && newTitle != currentTitle) {
        try {
          await ref
              .read(aiChatProvider.notifier)
              .renameSession(sessionId, newTitle);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.l10n.stateError}: $e'),
                backgroundColor: context.vDanger,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _exportSession(
    BuildContext context,
    String sessionId,
    String title,
  ) async {
    try {
      final markdown = await ref
          .read(aiChatProvider.notifier)
          .exportSession(sessionId);
      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = safeName.endsWith('.md') ? safeName : '$safeName.md';
      final bytes = Uint8List.fromList(utf8.encode(markdown));
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['md'],
        mimeType: 'text/markdown',
      );
      if (uri != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.chatExportSuccess)));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.chatExportFailed}: $e'),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  Future<void> _showRemoteSessionsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _RemoteSessionsDialog(),
    );
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

  bool _isErrorInlinedInLastAssistantMessage(AiChatState state) {
    final lastMessage = state.activeSession?.messages.lastOrNull;
    if (lastMessage == null || lastMessage.role != MessageRole.assistant) {
      return false;
    }
    final code = state.lastErrorCode;
    if (code == null || code.isEmpty) {
      return false;
    }
    return lastMessage.content.endsWith('**Error:** $code');
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
      final prevSessionId = previous?.activeSession?.id;
      final nextSessionId = next.activeSession?.id;
      final prevMessages = previous?.activeSession?.messages ?? const [];
      final nextMessages = next.activeSession?.messages ?? const [];

      final prevAgentId = previous?.activeAgentProfile?.id;
      final nextAgentId = next.activeAgentProfile?.id;
      final prevServerId = previous?.activeAgentProfile?.serverId;
      final nextServerId = next.activeAgentProfile?.serverId;
      if (nextSessionId != prevSessionId ||
          nextAgentId != prevAgentId ||
          nextServerId != prevServerId) {
        if (_promptController.text != next.draftText) {
          _promptController.text = next.draftText;
          _promptController.selection = TextSelection.collapsed(
            offset: next.draftText.length,
          );
        }
      }

      if (nextSessionId != null && nextSessionId != _scrolledSessionId) {
        _scrolledSessionId = nextSessionId;
        _userNearBottom = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
        return;
      }

      final isPrepend =
          previous != null &&
          prevSessionId == nextSessionId &&
          nextSessionId != null &&
          prevMessages.isNotEmpty &&
          nextMessages.length > prevMessages.length &&
          nextMessages.any((m) => m.id == prevMessages.first.id) &&
          nextMessages.first.id != prevMessages.first.id;

      if (isPrepend && _scrollController.hasClients) {
        final oldMaxScroll = _scrollController.position.maxScrollExtent;
        final oldPixels = _scrollController.position.pixels;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final newMaxScroll = _scrollController.position.maxScrollExtent;
          final delta = newMaxScroll - oldMaxScroll;
          if (delta > 0) {
            _scrollController.jumpTo(oldPixels + delta);
          }
        });
        return;
      }

      final hasNewTokenOrMessage =
          next.isGenerating ||
          (prevMessages.length != nextMessages.length) ||
          (prevMessages.lastOrNull?.content !=
              nextMessages.lastOrNull?.content) ||
          (prevMessages.lastOrNull?.thinking !=
              nextMessages.lastOrNull?.thinking);

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
                if (chatState.lastErrorCode != null &&
                    !_isErrorInlinedInLastAssistantMessage(chatState))
                  _buildErrorBanner(chatState.lastErrorCode!),
                _AcpSessionNoticeBar(
                  acpSessionRestored: chatState.acpSessionRestored,
                  acpSessionRestartDetected:
                      chatState.acpSessionRestartDetected,
                  onAcknowledgeRestart: () => ref
                      .read(aiChatProvider.notifier)
                      .acknowledgeAcpSessionRestart(),
                ),
                SessionRecoveryBanner(
                  key: const Key('aiChatSessionRecoveryBanner'),
                  status: chatState.recoveryStatus,
                  onRetry: () =>
                      ref.read(aiChatProvider.notifier).recoverConnection(),
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
          IconButton(
            key: const Key('chat_usage_diagnostics_button'),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            tooltip: context.l10n.chatAccountAndQuotaTitle,
            onPressed: () => _showAccountAndQuotaDialog(context),
          ),
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
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    Tooltip(
                      message: context.l10n.chatRemoteSessions,
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          key: const Key('chat_remote_sessions_button'),
                          icon: const Icon(Icons.cloud_outlined, size: 16),
                          label: Text(context.l10n.chatRemoteSessions),
                          onPressed: () => _showRemoteSessionsDialog(context),
                        ),
                      ),
                    ),
                  ],
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                key: const Key('chat_session_search_input'),
                controller: _sessionSearchController,
                decoration: InputDecoration(
                  hintText: context.l10n.chatSearchSessionsHint,
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _sessionSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _sessionSearchController.clear();
                            notifier.searchSessions('');
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                ),
                onChanged: (val) {
                  notifier.searchSessions(val);
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount:
                    state.sessions.length + (state.hasMoreSessions ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.sessions.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Center(
                        child: state.isLoadingSessions
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton.icon(
                                key: const Key(
                                  'chat_load_more_sessions_button',
                                ),
                                icon: const Icon(Icons.expand_more, size: 16),
                                label: Text(context.l10n.chatLoadMoreSessions),
                                onPressed: () => notifier.loadMoreSessions(),
                              ),
                      ),
                    );
                  }
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
                          ),
                        PopupMenuButton<String>(
                          key: Key('session_more_menu_${session.id}'),
                          icon: const Icon(Icons.more_vert, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          onSelected: (val) {
                            switch (val) {
                              case 'set_default':
                                notifier.setLaunchPreference(
                                  ChatLaunchPreference(
                                    mode: ChatLaunchMode.fixed,
                                    sessionId: session.id,
                                  ),
                                );
                                break;
                              case 'rename':
                                _showRenameSessionDialog(
                                  context,
                                  session.id,
                                  session.title,
                                );
                                break;
                              case 'export':
                                _exportSession(
                                  context,
                                  session.id,
                                  session.title,
                                );
                                break;
                              case 'delete':
                                _confirmAndDeleteSession(
                                  context,
                                  session.id,
                                  session.title,
                                );
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (preference.mode == ChatLaunchMode.fixed)
                              PopupMenuItem<String>(
                                key: Key('set_default_session_${session.id}'),
                                value: 'set_default',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.push_pin_outlined,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(context.l10n.setAsDefaultSession),
                                  ],
                                ),
                              ),
                            PopupMenuItem<String>(
                              key: Key('rename_session_${session.id}'),
                              value: 'rename',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_outlined, size: 16),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.rename),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              key: Key('export_session_${session.id}'),
                              value: 'export',
                              child: Row(
                                children: [
                                  const Icon(Icons.download_outlined, size: 16),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.chatExportSession),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              key: Key('delete_session_${session.id}'),
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: ctx.vDanger,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.delete,
                                    style: TextStyle(color: ctx.vDanger),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  String _resolveLoadOlderMessagesLabel(BuildContext context) {
    return context.l10n.chatLoadOlderMessages;
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
      final isRecovering =
          state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
          state.recoveryStatus == SessionRecoveryStatus.syncing;

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
                                onPressed: (!isConnected || isRecovering)
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

    final hasOlder = (session?.messageOffset ?? 0) > 0;
    final topCount = hasOlder ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: topCount + messages.length + (state.isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasOlder && index == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                key: const Key('acp_load_older_messages_button'),
                icon: state.isLoadingMessages
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward, size: 16),
                label: Text(
                  state.isLoadingMessages
                      ? context.l10n.cliLoadingOlderMessages
                      : _resolveLoadOlderMessagesLabel(context),
                ),
                onPressed: state.isLoadingMessages
                    ? null
                    : () =>
                          ref.read(aiChatProvider.notifier).loadOlderMessages(),
              ),
            ),
          );
        }

        final messageIndex = hasOlder ? index - 1 : index;

        if (messageIndex == messages.length) {
          return Padding(
            key: const Key('acp_receiving_indicator'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: context.l10n.acpStreaming,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    context.l10n.acpStreaming,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
        final msg = messages[messageIndex];
        if (msg.role == MessageRole.user) {
          return KeyedSubtree(
            key: ValueKey('user_msg_${msg.id}'),
            child: _buildUserBubble(msg),
          );
        } else if (msg.role == MessageRole.system) {
          return KeyedSubtree(
            key: ValueKey('system_msg_${msg.id}'),
            child: _buildSystemBubble(msg),
          );
        }
        return KeyedSubtree(
          key: ValueKey('assistant_msg_${msg.id}'),
          child: _buildAssistantBubble(msg),
        );
      },
    );
  }

  Widget _buildSystemBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: SelectableText(
                    msg.content,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (msg.attachments.isNotEmpty)
              _buildMessageAttachments(msg.attachments),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildMessageAttachments(List<ChatAttachment> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: attachments.map((att) {
          if (att.isImage) {
            if (att.localPath == null || att.localPath!.isEmpty) {
              return _buildMissingAttachmentCard(att);
            }
            return GestureDetector(
              onTap: () => ImageZoomDialog.show(
                context,
                title: att.name,
                localPath: att.localPath,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 180,
                  ),
                  color: context.colorScheme.surfaceContainerHighest,
                  child: Image(
                    image: ResizeImage(
                      FileImage(File(att.localPath!)),
                      width: 480,
                      height: 480,
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _buildMissingAttachmentCard(att),
                  ),
                ),
              ),
            );
          }
          return _buildFileAttachmentCard(att);
        }).toList(),
      ),
    );
  }

  Widget _buildMissingAttachmentCard(ChatAttachment att) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: context.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  att.name,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  context.l10n.chatAttachmentMissing,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachmentCard(ChatAttachment att) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  att.name,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${att.mimeType.isNotEmpty ? att.mimeType : "file"} • ${_formatBytes(att.sizeBytes)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              msg.content,
              style: TextStyle(
                color: context.colorScheme.onPrimaryContainer,
                fontSize: 14,
              ),
            ),
            if (msg.attachments.isNotEmpty)
              _buildMessageAttachments(msg.attachments),
            if (msg.status == ChatTurnStatus.interrupted) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 12,
                    color: context.vWarning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.chatStatusInterrupted,
                    style: TextStyle(
                      color: context.vWarning,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else if (msg.status == ChatTurnStatus.failed) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 12, color: context.vDanger),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.chatStatusFailed,
                    style: TextStyle(
                      color: context.vDanger,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
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
                return _ToolExecutionCard(
                  key: ValueKey('tool_${tool.id}'),
                  tool: tool,
                  messageId: msg.id,
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

            // Turn status indicator for interrupted or failed
            if (msg.status == ChatTurnStatus.interrupted) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.vWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(
                    color: context.vWarning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 16,
                      color: context.vWarning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.chatStatusInterrupted,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.vWarning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (msg.status == ChatTurnStatus.failed) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.vDanger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(
                    color: context.vDanger.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 16, color: context.vDanger),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.chatStatusFailed,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.vDanger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (msg.attachments.isNotEmpty)
              _buildMessageAttachments(msg.attachments),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(PermissionRequest req) {
    final notifier = ref.read(aiChatProvider.notifier);
    final danger = context.vDanger;
    final connState = ref.watch(serverConnectionProvider);
    final recoveryStatus = ref.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final canRespond =
        connState.isConnected &&
        recoveryStatus != SessionRecoveryStatus.reconnecting &&
        recoveryStatus != SessionRecoveryStatus.syncing;

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
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  key: const Key('chat_permission_cancel'),
                  onPressed: canRespond
                      ? () => notifier.respondPermission(null)
                      : null,
                  child: Text(context.l10n.cancel),
                ),
                if (req.options.isNotEmpty)
                  ...req.options.map((option) {
                    final isAllow = option.kind.toLowerCase().contains('allow');
                    if (isAllow) {
                      return FilledButton(
                        key: Key('chat_permission_option_${option.id}'),
                        style: req.isDangerous
                            ? FilledButton.styleFrom(
                                backgroundColor: context.colorScheme.error,
                              )
                            : null,
                        onPressed: canRespond
                            ? () => notifier.respondPermission(option.id)
                            : null,
                        child: Text(
                          option.name.isNotEmpty ? option.name : option.id,
                        ),
                      );
                    }
                    return OutlinedButton(
                      key: Key('chat_permission_option_${option.id}'),
                      onPressed: canRespond
                          ? () => notifier.respondPermission(option.id)
                          : null,
                      child: Text(
                        option.name.isNotEmpty ? option.name : option.id,
                      ),
                    );
                  })
                else ...[
                  OutlinedButton(
                    key: const Key('chat_permission_reject'),
                    onPressed: canRespond
                        ? () => notifier.respondPermission(null)
                        : null,
                    child: Text(context.l10n.permissionReject),
                  ),
                ],
              ],
            ),
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
      final initialServerId = activeServer.id;
      final initialAgentId = profile.id;

      final confirmed = await showAgentCommandConfirmDialog(
        context: context,
        actionType: AgentCommandActionType.login,
        agentName: profile.name,
        command: profile.loginCommand!,
        server: activeServer,
      );
      if (!mounted || !confirmed) return;

      final currentServer = ref.read(activeServerProvider);
      final currentRegistry = ref.read(agentRegistryProvider);
      final currentProfile =
          currentRegistry.findRuntime(challenge.agentId)?.profile ??
          ref.read(aiChatProvider).activeAgentProfile;
      if (currentServer?.id != initialServerId ||
          currentProfile?.id != initialAgentId) {
        return;
      }

      String? remoteExecCommand;
      if (currentProfile!.executionTarget == 'docker') {
        try {
          remoteExecCommand = agentTargetCommand(
            currentProfile,
            currentProfile.loginCommand!,
            interactive: true,
          );
        } catch (_) {
          return;
        }
      }

      final sshClient = ref
          .read(sshClientManagerProvider)
          .getClient(currentServer!.id);
      final result = await ref.read(interactiveLoginLauncherProvider)(
        context: context,
        agentName: currentProfile.name,
        command: currentProfile.loginCommand!,
        serverName: currentServer.name,
        sshClient: sshClient,
        remoteExecCommand: remoteExecCommand,
      );
      if (!mounted || result != true) return;

      final postServer = ref.read(activeServerProvider);
      final postRegistry = ref.read(agentRegistryProvider);
      final postProfile =
          postRegistry.findRuntime(challenge.agentId)?.profile ??
          ref.read(aiChatProvider).activeAgentProfile;
      if (postServer?.id == initialServerId &&
          postProfile?.id == initialAgentId) {
        await ref
            .read(agentRegistryProvider.notifier)
            .loginAgent(currentProfile.id);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.agentAuthRetryHint)));
    }
  }

  Future<void> _openRunSettings({bool refresh = true}) async {
    final connState = ref.read(serverConnectionProvider);
    final state = ref.read(aiChatProvider);
    final isRecovering =
        state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing;
    if (!connState.isConnected ||
        isRecovering ||
        state.isGenerating ||
        state.isLoadingSettings ||
        state.isApplyingSettings) {
      return;
    }
    final currentServerId = ref.read(activeServerProvider)?.id;
    final currentAgentId = state.activeAgentProfile?.id;
    const effectiveRefresh = true;

    final ok = await ref
        .read(aiChatProvider.notifier)
        .prepareRunSettings(refresh: effectiveRefresh);
    if (!mounted) return;
    if (!ok) {
      final freshState = ref.read(aiChatProvider);
      final code = freshState.lastErrorCode ?? AiChatNotifier.notReadyCode;
      final message = _resolveErrorMessage(code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: context.vDanger),
      );
      return;
    }

    final freshState = ref.read(aiChatProvider);
    final freshServerId = ref.read(activeServerProvider)?.id;
    if (freshServerId != currentServerId ||
        freshState.activeAgentProfile?.id != currentAgentId) {
      return;
    }

    final dialogServerId = freshServerId;
    final dialogAgentId = currentAgentId;
    final profile = freshState.activeAgentProfile;
    final activeServer = ref.read(activeServerProvider);
    final isDocker = profile?.executionTarget == 'docker';
    final containerName = isDocker ? profile?.containerReference : null;
    final agentUserName = isDocker
        ? (profile?.containerUser ?? '')
        : (activeServer?.username ?? '');

    await ChatRunSettingsDialog.show(
      context,
      initialSettings: freshState.runSettings,
      capabilities: freshState.capabilities,
      isStructuredSend: true,
      settingsFetchedAt: freshState.settingsFetchedAt,
      agentVersion: freshState.agentVersion,
      settingsStale: freshState.settingsStale,
      modelCatalogError: freshState.modelCatalogError,
      serverName: activeServer?.name ?? '',
      containerName: containerName,
      agentUserName: agentUserName,
      onRefresh: () async {
        if (!mounted) return null;
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curServerId != dialogServerId || curAgentId != dialogAgentId) {
          return null;
        }
        final refreshOk = await ref
            .read(aiChatProvider.notifier)
            .prepareRunSettings(refresh: true);
        if (!refreshOk || !mounted) return null;
        if (ref.read(activeServerProvider)?.id != dialogServerId ||
            ref.read(aiChatProvider).activeAgentProfile?.id != dialogAgentId) {
          return null;
        }
        return ref.read(aiChatProvider).capabilities;
      },
      onFetchMetadata: () {
        if (!mounted) {
          return const ChatRunSettingsMetadata(settingsStale: true);
        }
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curServerId != dialogServerId || curAgentId != dialogAgentId) {
          return const ChatRunSettingsMetadata(settingsStale: true);
        }
        final state = ref.read(aiChatProvider);
        return ChatRunSettingsMetadata(
          settingsFetchedAt: state.settingsFetchedAt,
          agentVersion: state.agentVersion,
          settingsStale: state.settingsStale,
          modelCatalogError: state.modelCatalogError,
        );
      },
      onSave: (settings) async {
        if (!mounted) return;
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curServerId != dialogServerId || curAgentId != dialogAgentId) {
          return;
        }
        await ref.read(aiChatProvider.notifier).updateRunSettings(settings);
      },
    );
  }

  Future<void> _openCommandsAndSkills(BuildContext context) async {
    final dialogServerId = ref.read(activeServerProvider)?.id;
    final dialogAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
    if (_isLoadingComposerCommands) return;
    setState(() => _isLoadingComposerCommands = true);
    try {
      await ref.read(aiChatProvider.notifier).prepareComposerCatalog();
    } catch (_) {
      // Catalog error handled in state/empty view
    } finally {
      if (mounted) setState(() => _isLoadingComposerCommands = false);
    }
    if (!mounted || !context.mounted) return;

    // mounted/server/agent checks
    final currentServerId = ref.read(activeServerProvider)?.id;
    final currentState = ref.read(aiChatProvider);
    if (dialogServerId != currentServerId ||
        dialogAgentId != currentState.activeAgentProfile?.id) {
      return;
    }

    final cmd = await showDialog<AcpSlashCommand?>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final server = ref.watch(activeServerProvider);
          final chatState = ref.watch(aiChatProvider);
          if (server?.id != dialogServerId ||
              chatState.activeAgentProfile?.id != dialogAgentId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.of(ctx).pop();
            });
            return const SizedBox.shrink();
          }

          final isDraft = chatState.activeSession == null;
          final rawWorkingDir = chatState.draftWorkingDirectory;

          return ChatCommandsSkillsDialog(
            commands: chatState.commands,
            errorMessage:
                chatState.lastErrorCode != null &&
                    chatState.lastErrorCode!.startsWith(
                      'AGENT_COMPOSER_QUERY_FAILED',
                    )
                ? chatState.lastErrorCode
                : null,
            onOpenSettings: () {
              if (!mounted) return;
              if (ref.read(activeServerProvider)?.id == dialogServerId &&
                  ref.read(aiChatProvider).activeAgentProfile?.id ==
                      dialogAgentId) {
                _openRunSettings(refresh: true);
              }
            },
            onPickWorkingDirectory: isDraft
                ? () {
                    if (!mounted) return;
                    if (ref.read(activeServerProvider)?.id == dialogServerId &&
                        ref.read(aiChatProvider).activeAgentProfile?.id ==
                            dialogAgentId) {
                      _showDraftWorkingDirDialog(context, rawWorkingDir);
                    }
                  }
                : null,
            onRetry: () async {
              if (!mounted || !ctx.mounted) return null;
              if (ref.read(activeServerProvider)?.id != dialogServerId ||
                  ref.read(aiChatProvider).activeAgentProfile?.id !=
                      dialogAgentId) {
                return null;
              }
              final ok = await ref
                  .read(aiChatProvider.notifier)
                  .prepareComposerCatalog();
              if (!mounted || !ctx.mounted) return null;
              if (ref.read(activeServerProvider)?.id != dialogServerId ||
                  ref.read(aiChatProvider).activeAgentProfile?.id !=
                      dialogAgentId) {
                return null;
              }
              if (!ok) return null;
              return ref.read(aiChatProvider).commands;
            },
          );
        },
      ),
    );
    if (cmd != null && mounted) {
      final afterServerId = ref.read(activeServerProvider)?.id;
      final afterAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
      if (afterServerId != dialogServerId || afterAgentId != dialogAgentId) {
        return;
      }
      final text = _promptController.text;
      final selection = _promptController.selection;
      final insertion = cmd.insertion;
      String newText;
      int newOffset;
      if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
        newText = text.replaceRange(selection.start, selection.end, insertion);
        newOffset = selection.start + insertion.length;
      } else {
        newText = '$text$insertion';
        newOffset = newText.length;
      }
      _promptController.text = newText;
      _promptController.selection = TextSelection.collapsed(offset: newOffset);
      ref.read(aiChatProvider.notifier).updateDraftText(newText);
    }
  }

  void _showAccountAndQuotaDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final state = ref.watch(aiChatProvider);
          final notifier = ref.read(aiChatProvider.notifier);
          final account = state.account;
          final hasStatus = state.accountStatusText.isNotEmpty;
          final hasStatusCommand = state.commands.any(
            (c) => c.name == 'status',
          );
          final isBusy =
              state.isGenerating ||
              state.isLoadingSettings ||
              state.isApplyingSettings ||
              state.isLoadingMessages ||
              state.isLoadingSessions;
          final canQueryStatus =
              state.activeSession != null &&
              hasStatusCommand &&
              !isBusy &&
              state.attachments.isEmpty;

          return AlertDialog(
            key: const Key('chat_usage_diagnostics_dialog'),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.chatAccountAndQuotaTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.chatAccountSectionTitle,
                      style: ctx.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (account != null) ...[
                      _buildInfoRow(context.l10n.chatAccountKind, account.kind),
                      _buildInfoRow(
                        context.l10n.chatAccountLabel,
                        account.label,
                      ),
                      if (account.email != null)
                        _buildInfoRow(
                          context.l10n.chatAccountEmail,
                          account.email!,
                        ),
                      if (account.plan != null)
                        _buildInfoRow(
                          context.l10n.chatAccountPlan,
                          account.plan!,
                        ),
                      _buildInfoRow(
                        context.l10n.chatAccountUpdatedAt,
                        account.updatedAt.toLocal().toString().split('.').first,
                      ),
                    ] else
                      Text(
                        context.l10n.chatAccountNotProvided,
                        style: ctx.textTheme.bodySmall?.copyWith(
                          color: ctx.colorScheme.outline,
                        ),
                      ),
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            context.l10n.chatQuotaSectionTitle,
                            style: ctx.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (canQueryStatus)
                            OutlinedButton.icon(
                              key: const Key('chat_query_status_button'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              icon: const Icon(Icons.sync, size: 14),
                              label: Text(
                                context.l10n.chatQueryStatusAction,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                try {
                                  await notifier.queryAccountStatus();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                        backgroundColor: ctx.vDanger,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasStatus) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: ctx.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.accountStatusFetchedAt != null
                                  ? '${context.l10n.chatStatusSourceNote} (${state.accountStatusFetchedAt!.toLocal().toString().split('.').first})'
                                  : context.l10n.chatStatusSourceNote,
                              style: TextStyle(
                                fontSize: 11,
                                color: ctx.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ctx.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: SelectableText(
                          state.accountStatusText,
                          style: monoTextStyle(fontSize: 11),
                        ),
                      ),
                    ] else ...[
                      Text(
                        state.activeSession == null
                            ? context.l10n.chatQueryStatusUnavailable
                            : (!hasStatusCommand
                                  ? context.l10n.chatStatusNotProvided
                                  : context.l10n.chatStatusNotQueried),
                        style: ctx.textTheme.bodySmall?.copyWith(
                          color: ctx.colorScheme.outline,
                        ),
                      ),
                    ],
                    if (state.usage != null) ...[
                      const Divider(height: 24),
                      Text(
                        context.l10n.chatUsageTitle,
                        style: ctx.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (state.usage!.used != null)
                        Text(
                          '${context.l10n.chatUsageUsed}: ${state.usage!.used}',
                        ),
                      if (state.usage!.size != null)
                        Text(
                          '${context.l10n.chatUsageSize}: ${state.usage!.size}',
                        ),
                      if (state.usage!.cost != null)
                        Text(
                          state.usage!.currency != null &&
                                  state.usage!.currency!.isNotEmpty
                              ? '${context.l10n.chatUsageCost}: ${state.usage!.cost} ${state.usage!.currency}'
                              : '${context.l10n.chatUsageCost}: ${state.usage!.cost}',
                        ),
                    ],
                    const Divider(height: 24),
                    Theme(
                      data: Theme.of(
                        ctx,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          context.l10n.chatDiagnosticsTitle,
                          style: ctx.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ctx.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                VRadius.input,
                              ),
                            ),
                            child: SelectableText(
                              state.diagnostics.isNotEmpty
                                  ? state.diagnostics
                                  : context.l10n.chatNoDiagnostics,
                              style: monoTextStyle(fontSize: 11),
                            ),
                          ),
                          if (state.diagnostics.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: const Key('chat_copy_diagnostics_button'),
                                icon: const Icon(Icons.copy, size: 14),
                                label: Text(
                                  context.l10n.agentDiagnosticLogCopy,
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: state.diagnostics),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.agentDiagnosticLogCopied,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.agentDiagnosticLogClose),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDraftWorkingDirDialog(
    BuildContext context,
    String? rawWorkingDir,
  ) async {
    final connState = ref.read(serverConnectionProvider);
    final recoveryStatus = ref.read(aiChatProvider).recoveryStatus;
    if (!connState.isConnected ||
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
    final selectedDir = await RemoteWorkspaceBrowserDialog.show(
      context,
      mode: RemoteBrowserMode.directory,
      initialPath: rawWorkingDir,
    );
    if (!mounted || !context.mounted) return;
    if (selectedDir is String && selectedDir.isNotEmpty) {
      ref.read(aiChatProvider.notifier).setDraftWorkingDirectory(selectedDir);
    }
  }

  Future<void> _pickLocalImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.first;
      final path = file.path;
      if (path == null) return;
      final ext = file.name.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      await ref
          .read(aiChatProvider.notifier)
          .attachLocalFile(path, file.name, mime);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('ACP_ATTACHMENT_TOO_LARGE')
          ? context.l10n.chatAttachTooLarge
          : '${context.l10n.chatAttachFailed}: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: context.vDanger),
      );
    }
  }

  Future<void> _pickLocalTextFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'md',
          'json',
          'yaml',
          'yml',
          'dart',
          'py',
          'js',
          'ts',
          'sh',
          'c',
          'cpp',
          'h',
        ],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final path = file.path;
      if (path == null) return;
      await ref
          .read(aiChatProvider.notifier)
          .attachLocalFile(path, file.name, 'text/plain');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('ACP_ATTACHMENT_TOO_LARGE')
          ? context.l10n.chatAttachTooLarge
          : '${context.l10n.chatAttachFailed}: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: context.vDanger),
      );
    }
  }

  Future<void> _promptRemoteTextFile(BuildContext context) async {
    final connState = ref.read(serverConnectionProvider);
    final recoveryStatus = ref.read(aiChatProvider).recoveryStatus;
    if (!connState.isConnected ||
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
    final selected = await RemoteWorkspaceBrowserDialog.show(
      context,
      mode: RemoteBrowserMode.files,
    );
    if (!mounted || !context.mounted) return;
    if (selected is List<String> && selected.isNotEmpty) {
      final targetServerId = ref.read(activeServerProvider)?.id;
      final targetAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
      final targetSessionId = ref.read(aiChatProvider).activeSessionId;
      final notifier = ref.read(aiChatProvider.notifier);
      final errors = <String, Object>{};
      for (final path in selected) {
        if (!mounted || !context.mounted) return;
        final currentServerId = ref.read(activeServerProvider)?.id;
        final currentState = ref.read(aiChatProvider);
        if (currentServerId != targetServerId ||
            currentState.activeAgentProfile?.id != targetAgentId ||
            currentState.activeSessionId != targetSessionId) {
          break;
        }
        try {
          await notifier.attachRemoteFile(path);
        } catch (e) {
          errors[path] = e;
        }
      }
      if (!mounted || !context.mounted) return;
      if (errors.isNotEmpty) {
        final details = errors.entries
            .map((e) => '${e.key.split("/").last}: ${e.value}')
            .join('; ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.chatRemoteReadFailed} (${errors.length}/${selected.length}): $details',
            ),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  Widget _buildAuthChallengeCard(AuthChallenge challenge) {
    final notifier = ref.read(aiChatProvider.notifier);
    final connState = ref.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;
    final recoveryStatus = ref.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final isRecovering =
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing;
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
                  onPressed: (!isConnected || isRecovering)
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
    final isRecovering =
        state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing;

    final isBusy =
        !hasActiveAgent ||
        _isSending ||
        state.isGenerating ||
        state.isLoadingSettings ||
        state.isApplyingSettings ||
        state.isLoadingSessions ||
        state.isLoadingMessages;

    final canSend = hasActiveAgent && !isBusy && isConnected && !isRecovering;

    final isDraft = state.activeSession == null;
    final rawWorkingDir =
        state.activeSession?.workingDirectory ?? state.draftWorkingDirectory;
    final currentWorkingDir =
        rawWorkingDir ?? context.l10n.cliDefaultWorkingDir;

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
                  !isConnected ||
                  isRecovering ||
                  state.isGenerating ||
                  state.isLoadingSettings ||
                  state.isApplyingSettings,
              isLoadingSettings: state.isLoadingSettings,
              tuneButtonKey: const Key('chat_run_settings_button'),
              onOpenSettings: () => _openRunSettings(refresh: true),
              onRefreshSettings: () => _openRunSettings(refresh: true),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                InkWell(
                  key: const Key('chat_working_dir_button'),
                  onTap: (isBusy || !isDraft || !isConnected || isRecovering)
                      ? null
                      : () =>
                            _showDraftWorkingDirDialog(context, rawWorkingDir),
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  child: Tooltip(
                    message: isDraft
                        ? context.l10n.chatWorkingDirTooltip
                        : '${state.activeSession!.workingDirectory} (${context.l10n.sessionTitle})',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        border: Border.all(
                          color: context.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 13,
                            color: isDraft
                                ? context.colorScheme.primary
                                : context.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              currentWorkingDir,
                              style: monoTextStyle(
                                fontSize: 11,
                                color: isDraft
                                    ? context.colorScheme.onSurface
                                    : context.colorScheme.outline,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isDraft) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: context.colorScheme.outline,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('chat_commands_menu_button'),
                  tooltip: context.l10n.chatCommandsTooltip,
                  icon: _isLoadingComposerCommands
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.code, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: (isBusy || _isLoadingComposerCommands)
                      ? null
                      : () => _openCommandsAndSkills(context),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  key: const Key('chat_attachments_button'),
                  tooltip: context.l10n.chatAttachTooltip,
                  icon: const Icon(Icons.attach_file, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  enabled: !isBusy,
                  onSelected: (val) {
                    switch (val) {
                      case 'image':
                        _pickLocalImage();
                        break;
                      case 'text':
                        _pickLocalTextFile();
                        break;
                      case 'remote':
                        _promptRemoteTextFile(context);
                        break;
                      case 'probe':
                        ref
                            .read(aiChatProvider.notifier)
                            .prepareRunSettings(refresh: false);
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'image',
                      enabled: state.supportsImages,
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: state.supportsImages
                                ? null
                                : ctx.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(context.l10n.chatAttachImage),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'text',
                      enabled: state.supportsTextAttachments,
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: state.supportsTextAttachments
                                ? null
                                : ctx.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(context.l10n.chatAttachLocalText),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'remote',
                      enabled:
                          state.supportsTextAttachments &&
                          isConnected &&
                          !isRecovering,
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 16,
                            color: state.supportsTextAttachments
                                ? null
                                : ctx.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Text(context.l10n.chatAttachRemoteText),
                        ],
                      ),
                    ),
                    if (!state.supportsImages && !state.supportsTextAttachments)
                      PopupMenuItem<String>(
                        value: 'probe',
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, size: 16),
                            const SizedBox(width: 8),
                            Text(context.l10n.refresh),
                          ],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (state.activeAgentProfile != null ||
                    state.usage != null ||
                    state.diagnostics.isNotEmpty ||
                    state.account != null)
                  IconButton(
                    key: const Key('chat_usage_diagnostics_action_button'),
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    tooltip: context.l10n.chatAccountAndQuotaTitle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showAccountAndQuotaDialog(context),
                  ),
              ],
            ),
            if (state.attachments.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < state.attachments.length; i++) ...[
                    Builder(
                      builder: (ctx) {
                        final att = state.attachments[i];
                        if (att.isImage) {
                          final hasBytes = att.bytes.isNotEmpty;
                          final hasPath =
                              att.localPath != null &&
                              att.localPath!.isNotEmpty;
                          return Container(
                            key: Key('chat_attachment_chip_$i'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.colorScheme.outlineVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: () => ImageZoomDialog.show(
                                    context,
                                    title: att.name,
                                    bytes: hasBytes ? att.bytes : null,
                                    localPath: hasBytes ? null : att.localPath,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: context
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: hasBytes
                                          ? Image(
                                              image: ResizeImage(
                                                MemoryImage(att.bytes),
                                                width: 128,
                                                height: 128,
                                                policy: ResizeImagePolicy.fit,
                                              ),
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 20,
                                                    ),
                                                  ),
                                            )
                                          : (hasPath
                                                ? Image(
                                                    image: ResizeImage(
                                                      FileImage(
                                                        File(att.localPath!),
                                                      ),
                                                      width: 128,
                                                      height: 128,
                                                      policy:
                                                          ResizeImagePolicy.fit,
                                                    ),
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, _, _) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            size: 20,
                                                          ),
                                                        ),
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 20,
                                                    ),
                                                  )),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: isBusy
                                        ? null
                                        : () => ref
                                              .read(aiChatProvider.notifier)
                                              .removeAttachment(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Container(
                          key: Key('chat_attachment_chip_$i'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colorScheme.outlineVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: 16,
                                color: context.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      att.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatBytes(att.bytes.length),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: context.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: isBusy
                                    ? null
                                    : () => ref
                                          .read(aiChatProvider.notifier)
                                          .removeAttachment(i),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chatPromptInput'),
                    controller: _promptController,
                    enabled: hasActiveAgent && !isBusy,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: hasActiveAgent
                          ? context.l10n.inputPromptHint
                          : (hasUnreadyAgents
                                ? context.l10n.agentNeedsInstallOrReadyHint
                                : context.l10n.noAgentAvailableHint),
                      hintStyle: const TextStyle(fontSize: 14),
                      hintMaxLines: 1,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.input),
                      ),
                    ),
                    onChanged: (text) =>
                        ref.read(aiChatProvider.notifier).updateDraftText(text),
                    onSubmitted: canSend ? (_) => _handleSend() : null,
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
                      onPressed: canSend ? _handleSend : null,
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

class _ToolExecutionCard extends ConsumerStatefulWidget {
  final ToolExecution tool;
  final String messageId;

  const _ToolExecutionCard({
    super.key,
    required this.tool,
    required this.messageId,
  });

  @override
  ConsumerState<_ToolExecutionCard> createState() => _ToolExecutionCardState();
}

class _ToolExecutionCardState extends ConsumerState<_ToolExecutionCard> {
  bool _expanded = false;
  bool _showFull = false;
  bool _isLoadingMore = false;
  String? _loadedOutput;
  int? _nextOffset;

  @override
  void didUpdateWidget(covariant _ToolExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool.id != widget.tool.id ||
        oldWidget.messageId != widget.messageId) {
      _loadedOutput = null;
      _nextOffset = null;
      _showFull = false;
    }
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (widget.tool.status) {
      case ToolExecutionStatus.completed:
        return Icon(
          Icons.check_circle_outline,
          size: 14,
          color: context.vSuccess,
        );
      case ToolExecutionStatus.running:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.vWarning,
          ),
        );
      case ToolExecutionStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: context.vDanger);
      case ToolExecutionStatus.pending:
        return Icon(
          Icons.schedule,
          size: 14,
          color: context.colorScheme.outline,
        );
    }
  }

  Future<void> _loadToolOutputInitial() async {
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(aiChatProvider.notifier)
          .loadToolOutput(widget.messageId, widget.tool.id, offset: 0);
      if (!mounted) return;
      setState(() {
        _loadedOutput = page.text;
        _nextOffset = page.nextOffset;
        _showFull = true;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: context.vDanger),
      );
    }
  }

  Future<void> _loadToolOutputNext() async {
    if (_nextOffset == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref
          .read(aiChatProvider.notifier)
          .loadToolOutput(
            widget.messageId,
            widget.tool.id,
            offset: _nextOffset!,
          );
      if (!mounted) return;
      setState(() {
        _loadedOutput = (_loadedOutput ?? '') + page.text;
        _nextOffset = page.nextOffset;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: context.vDanger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.tool.command.isNotEmpty
        ? widget.tool.command
        : widget.tool.name;
    final rawOutput = widget.tool.output ?? '';
    final hasOutput = rawOutput.isNotEmpty || widget.tool.hasMoreOutput;
    final outputToCopy = _loadedOutput ?? rawOutput;

    return ValhallaCard(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.black,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(VRadius.input),
            child: Row(
              children: [
                _buildStatusIcon(context),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: monoTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.tool.status == ToolExecutionStatus.failed
                          ? context.vDanger
                          : context.vSuccess,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.tool.executionTimeMs != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${widget.tool.executionTimeMs} ms',
                    style: monoTextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
                if (outputToCopy.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    tooltip: context.l10n.copy,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: outputToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.chatMessageCopied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: VTiming.base,
                  curve: VCurves.emphasized,
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // Locations
          if (widget.tool.locations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 12,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${context.l10n.chatToolLocations}: ${widget.tool.locations.join(', ')}',
                    style: monoTextStyle(
                      fontSize: 10,
                      color: context.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],

          // Collapsible Output
          if (_expanded) ...[
            const SizedBox(height: 8),
            if (!hasOutput)
              Text(
                '(No output)',
                style: monoTextStyle(
                  fontSize: 11,
                  color: context.colorScheme.outline,
                ),
              )
            else ...[
              _buildOutputContent(context, rawOutput),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOutputContent(BuildContext context, String rawOutput) {
    final isLong = rawOutput.length > 2000 || widget.tool.hasMoreOutput;
    final String displayText;

    if (_showFull) {
      displayText = _loadedOutput ?? rawOutput;
    } else {
      displayText = rawOutput.length > 2000
          ? '... [truncated] ...\n${rawOutput.substring(rawOutput.length - 2000)}'
          : rawOutput;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(VRadius.input),
          ),
          child: SelectableText(
            displayText,
            style: monoTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (!_showFull)
                TextButton(
                  key: Key('chat_tool_show_full_${widget.tool.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _isLoadingMore
                      ? null
                      : () {
                          if (widget.tool.hasMoreOutput &&
                              _loadedOutput == null) {
                            _loadToolOutputInitial();
                          } else {
                            setState(() => _showFull = true);
                          }
                        },
                  child: _isLoadingMore
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.chatShowFullOutput),
                )
              else ...[
                if (_nextOffset != null) ...[
                  TextButton.icon(
                    key: Key('chat_tool_load_next_${widget.tool.id}'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: _isLoadingMore
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_downward, size: 12),
                    label: Text(context.l10n.chatLoadMoreSessions),
                    onPressed: _isLoadingMore ? null : _loadToolOutputNext,
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => setState(() => _showFull = false),
                  child: Text(context.l10n.chatShowLessOutput),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _RemoteSessionsDialog extends ConsumerStatefulWidget {
  const _RemoteSessionsDialog();

  @override
  ConsumerState<_RemoteSessionsDialog> createState() =>
      _RemoteSessionsDialogState();
}

class _RemoteSessionsDialogState extends ConsumerState<_RemoteSessionsDialog> {
  List<AcpRemoteSession> _sessions = [];
  String? _nextCursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _importingSessionId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await ref.read(aiChatProvider.notifier).listRemoteSessions();
      if (!mounted) return;
      setState(() {
        _sessions = page.sessions;
        _nextCursor = page.nextCursor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final page = await ref
          .read(aiChatProvider.notifier)
          .listRemoteSessions(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _sessions.addAll(page.sessions);
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.chatRemoteImportFailed}: $e'),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  Future<void> _selectSession(
    AcpRemoteSession session, {
    bool reimport = false,
  }) async {
    if (_importingSessionId != null) return;
    setState(() {
      _importingSessionId = session.id;
    });
    try {
      await ref
          .read(aiChatProvider.notifier)
          .openRemoteSession(session, reimport: reimport);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importingSessionId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.chatRemoteImportFailed}: $e'),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatRemoteSessionsTitle),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chatRemoteSessionsDesc,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importingSessionId != null
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.vDanger, size: 32),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: context.vDanger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _fetchInitial,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.stateRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Text(
          context.l10n.chatRemoteSessionsEmpty,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _sessions.length + (_nextCursor != null ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        if (index == _sessions.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      key: const Key('chat_remote_sessions_load_more'),
                      onPressed: _importingSessionId != null ? null : _loadMore,
                      child: Text(context.l10n.chatLoadMoreSessions),
                    ),
            ),
          );
        }
        final s = _sessions[index];
        final isImporting = _importingSessionId == s.id;
        return ListTile(
          key: Key('remote_session_${s.id}'),
          leading: const Icon(Icons.history, size: 20),
          title: Text(
            s.title.isNotEmpty ? s.title : s.id,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Text(
            s.workingDirectory,
            style: monoTextStyle(
              fontSize: 11,
              color: context.colorScheme.outline,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          trailing: isImporting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.chatRemoteImporting,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('reimport_copy_${s.id}'),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      tooltip: context.l10n.chatReimportAsCopy,
                      onPressed: _importingSessionId != null
                          ? null
                          : () => _selectSession(s, reimport: true),
                    ),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
          enabled: _importingSessionId == null,
          onTap: () => _selectSession(s),
        );
      },
    );
  }
}
