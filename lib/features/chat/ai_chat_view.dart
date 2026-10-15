import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/motion.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/providers/agent_registry_provider.dart';
import '../../core/providers/ai_chat_provider.dart';
import '../../core/providers/security_settings_provider.dart';
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
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/chat_launch_preference.dart';
import '../../data/models/chat_run_settings.dart'
    show AgentRuntimeCapabilities, ChatRunSettings;
import '../../infrastructure/acp/acp_client_adapter.dart'
    show AcpRemoteSession, AcpSlashCommand;
import '../../infrastructure/acp/acp_oauth_request.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import 'widgets/chat_run_settings_dialog.dart';
import 'widgets/chat_run_settings_strip.dart';
import 'widgets/chat_commands_skills_dialog.dart';
import 'widgets/image_zoom_dialog.dart';
import 'widgets/remote_workspace_browser_dialog.dart';

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
  bool _pendingInitialHistory = false;
  bool _userNearBottom = true;
  bool _isSending = false;
  bool _isLoadingComposerCommands = false;
  AcpOAuthRequest? _lastAutoLaunchedAuthRequest;
  String? _authLaunchError;

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
    final initialChat = ref.read(aiChatProvider);
    final initialSessionId = initialChat.activeSessionId;
    final initialServerKey = ref.read(activeServerProvider)?.connectionKey;
    final initialAgentId = initialChat.activeAgentProfile?.id;
    _scrolledSessionId = initialSessionId;
    _pendingInitialHistory =
        initialChat.activeSession != null &&
        initialChat.activeSession!.messages.isEmpty;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final currentChat = ref.read(aiChatProvider);
      final currentServer = ref.read(activeServerProvider);
      if (currentChat.activeSessionId != initialSessionId ||
          currentChat.activeAgentProfile?.id != initialAgentId ||
          currentServer?.connectionKey != initialServerKey) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _followBottomIfNeeded() {
    if (!mounted || !_scrollController.hasClients || !_userNearBottom) return;
    final chatState = ref.read(aiChatProvider);
    final targetSessionId = chatState.activeSessionId;
    final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
    final targetAgentId = chatState.activeAgentProfile?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_userNearBottom) return;
      final currentChat = ref.read(aiChatProvider);
      final currentServer = ref.read(activeServerProvider);
      if (currentChat.activeSessionId != targetSessionId ||
          currentChat.activeAgentProfile?.id != targetAgentId ||
          currentServer?.connectionKey != targetServerKey) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
      MaterialPageRoute(
        builder: (_) => AgentManagementView(onNavigateToChat: () {}),
      ),
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
    final sendSessionId = sentSessionId;
    final sendAgentId = sentAgentId;
    final sendServerKey = ref.read(activeServerProvider)?.connectionKey;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      final currentChat = ref.read(aiChatProvider);
      final currentServer = ref.read(activeServerProvider);
      if (currentChat.activeSessionId != sendSessionId ||
          currentChat.activeAgentProfile?.id != sendAgentId ||
          currentServer?.connectionKey != sendServerKey) {
        return;
      }
      _scrollToBottom();
    });

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

  Widget _buildErrorBanner(String errorCode) {
    return Consumer(
      builder: (bannerCtx, bannerRef, _) {
        final retryMeta = bannerRef.watch(
          aiChatProvider.select((s) {
            final session = s.activeSession;
            return (
              activeSessionId: s.activeSessionId,
              targetAgentId: s.activeAgentProfile?.id,
              targetSessionId: session?.id,
              messageCount: session?.messages.length ?? 0,
              messageOffset: session?.messageOffset ?? 0,
              isBusy:
                  s.isGenerating ||
                  s.isLoadingSessions ||
                  s.isLoadingMessages ||
                  s.isAuthenticating ||
                  s.isLoadingSettings ||
                  s.isApplyingSettings,
            );
          }),
        );
        final targetServerKey = bannerRef.watch(
          activeServerProvider.select((s) => s?.connectionKey),
        );

        final bool canRetry;
        if (retryMeta.isBusy) {
          canRetry = false;
        } else if (errorCode.contains('CHAT_HISTORY_LOAD_FAILED')) {
          canRetry = true;
        } else if (errorCode.contains('CHAT_MESSAGES_LOAD_FAILED')) {
          final hasTarget =
              retryMeta.activeSessionId != null ||
              retryMeta.targetSessionId != null;
          canRetry =
              hasTarget &&
              (retryMeta.messageCount == 0 || retryMeta.messageOffset > 0);
        } else {
          canRetry = false;
        }

        final capturedServerKey = targetServerKey;
        final capturedAgentId = retryMeta.targetAgentId;
        final capturedSessionId =
            retryMeta.targetSessionId ?? retryMeta.activeSessionId;
        final capturedErrorCode = errorCode;

        final VoidCallback? onReload = canRetry
            ? () async {
                final currentChat = bannerRef.read(aiChatProvider);
                final currentServer = bannerRef.read(activeServerProvider);
                if (currentChat.lastErrorCode != capturedErrorCode) return;
                if (currentServer?.connectionKey != capturedServerKey) return;
                if (currentChat.activeAgentProfile?.id != capturedAgentId) {
                  return;
                }
                final isCurrentBusy =
                    currentChat.isGenerating ||
                    currentChat.isLoadingSessions ||
                    currentChat.isLoadingMessages ||
                    currentChat.isAuthenticating ||
                    currentChat.isLoadingSettings ||
                    currentChat.isApplyingSettings;
                if (isCurrentBusy) return;

                if (capturedErrorCode.contains('CHAT_HISTORY_LOAD_FAILED')) {
                  await bannerRef
                      .read(aiChatProvider.notifier)
                      .searchSessions(_sessionSearchController.text);
                } else if (capturedErrorCode.contains(
                  'CHAT_MESSAGES_LOAD_FAILED',
                )) {
                  if (capturedSessionId == null) return;
                  if (currentChat.activeSessionId != capturedSessionId) return;
                  final session = currentChat.activeSession;
                  if (session == null || session.messages.isEmpty) {
                    await bannerRef
                        .read(aiChatProvider.notifier)
                        .selectSession(capturedSessionId);
                  } else if (session.messageOffset > 0) {
                    await bannerRef
                        .read(aiChatProvider.notifier)
                        .loadOlderMessages();
                  }
                }
              }
            : null;

        return _ChatErrorBanner(
          errorCode: errorCode,
          onReloadHistory: onReload,
        );
      },
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
        _pendingInitialHistory = nextMessages.isEmpty;
        final targetSessionId = nextSessionId;
        final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
        final targetAgentId = next.activeAgentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final currentChat = ref.read(aiChatProvider);
          final currentServer = ref.read(activeServerProvider);
          if (currentChat.activeSessionId != targetSessionId ||
              currentChat.activeAgentProfile?.id != targetAgentId ||
              currentServer?.connectionKey != targetServerKey) {
            return;
          }
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
        return;
      }

      if (_pendingInitialHistory && nextMessages.isNotEmpty) {
        _pendingInitialHistory = false;
        _userNearBottom = true;
        final targetSessionId = nextSessionId;
        final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
        final targetAgentId = next.activeAgentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final currentChat = ref.read(aiChatProvider);
          final currentServer = ref.read(activeServerProvider);
          if (currentChat.activeSessionId != targetSessionId ||
              currentChat.activeAgentProfile?.id != targetAgentId ||
              currentServer?.connectionKey != targetServerKey) {
            return;
          }
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }

      final prevOffset = previous?.activeSession?.messageOffset;
      final nextOffset = next.activeSession?.messageOffset;
      final isPrepend =
          previous != null &&
          prevSessionId == nextSessionId &&
          nextSessionId != null &&
          prevOffset != null &&
          nextOffset != null &&
          nextOffset < prevOffset &&
          nextMessages.length > prevMessages.length;

      if (isPrepend && _scrollController.hasClients) {
        final targetSessionId = nextSessionId;
        final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
        final targetAgentId = next.activeAgentProfile?.id;
        final oldMaxScroll = _scrollController.position.maxScrollExtent;
        final oldPixels = _scrollController.position.pixels;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final currentChat = ref.read(aiChatProvider);
          final currentServer = ref.read(activeServerProvider);
          if (currentChat.activeSessionId != targetSessionId ||
              currentChat.activeAgentProfile?.id != targetAgentId ||
              currentServer?.connectionKey != targetServerKey) {
            return;
          }
          final newMaxScroll = _scrollController.position.maxScrollExtent;
          final delta = newMaxScroll - oldMaxScroll;
          if (delta > 0) {
            _scrollController.jumpTo(oldPixels + delta);
          }
        });
        return;
      }

      final newAuthRequest = next.authRequest;
      if (previous?.authRequest != next.authRequest) {
        if (_authLaunchError != null) {
          _authLaunchError = null;
        }
      }
      if (newAuthRequest != null &&
          next.isAuthenticating &&
          newAuthRequest != _lastAutoLaunchedAuthRequest) {
        _lastAutoLaunchedAuthRequest = newAuthRequest;
        final expectedServerId = next.activeAgentProfile?.serverId;
        final expectedAgentId = next.activeAgentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(aiChatProvider);
          final currentServer = ref.read(activeServerProvider);
          if (!current.isAuthenticating ||
              current.authError != null ||
              current.authRequest != newAuthRequest ||
              current.activeAgentProfile?.id != expectedAgentId ||
              currentServer?.id != expectedServerId) {
            return;
          }
          final claimed = ref
              .read(aiChatProvider.notifier)
              .claimAuthBrowserLaunch(newAuthRequest);
          if (!claimed) return;
          _launchAuthUrl(newAuthRequest.authorizationUrl);
        });
      }
      if (next.authRequest == null && _lastAutoLaunchedAuthRequest != null) {
        _lastAutoLaunchedAuthRequest = null;
      }

      if (previous != null &&
          previous.isAuthenticating &&
          !next.isAuthenticating &&
          previous.authChallenge != null &&
          next.authChallenge == null &&
          next.authenticationConfirmed &&
          next.authError == null &&
          next.activeAgentProfile != null &&
          usesAntigravityAcp(next.activeAgentProfile!) &&
          next.activeAgentProfile?.serverId ==
              ref.read(activeServerProvider)?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.agentAuthRetryHint)),
        );
      }

      final hasNewTokenOrMessage =
          next.isGenerating ||
          (prevMessages.length != nextMessages.length) ||
          (prevMessages.lastOrNull?.content !=
              nextMessages.lastOrNull?.content) ||
          (prevMessages.lastOrNull?.thinking !=
              nextMessages.lastOrNull?.thinking) ||
          (prevMessages.lastOrNull?.status !=
              nextMessages.lastOrNull?.status) ||
          (previous?.authChallenge != next.authChallenge) ||
          (previous?.authRequest != next.authRequest) ||
          (previous?.isAuthenticating != next.isAuthenticating);

      if (hasNewTokenOrMessage) {
        _followBottomIfNeeded();
      }
    });

    final isDesktop = context.isDesktop;

    return Scaffold(
      drawer: !isDesktop
          ? Drawer(child: _buildSessionsDrawer(isDesktop))
          : null,
      body: Row(
        children: [
          if (isDesktop) ...[
            SizedBox(width: 320, child: _buildSessionsDrawer(isDesktop)),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                Consumer(
                  builder: (ctx, ref, _) {
                    ref.watch(
                      aiChatProvider.select(
                        (s) => (
                          s.activeAgentProfile != null,
                          s.activeAgentProfile?.id,
                          s.activeAgentProfile?.name,
                          s.shareAgentSessions,
                          s.isGenerating,
                        ),
                      ),
                    );
                    return _buildHeaderBar(ref.read(aiChatProvider), isDesktop);
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (ctx, ref, _) {
                    final bannerCode = ref.watch(
                      aiChatProvider.select((s) {
                        final code = s.lastErrorCode;
                        if (code == null ||
                            code == AiChatNotifier.disconnectedCode ||
                            code == AiChatNotifier.authRequiredCode ||
                            s.authChallenge != null ||
                            s.authError != null) {
                          return null;
                        }
                        final hasMessageError =
                            s.activeSession?.messages.any(
                              (m) =>
                                  m.failureCode == code ||
                                  (m.role == MessageRole.assistant &&
                                      m.content.endsWith('**Error:** $code')),
                            ) ??
                            false;
                        if (hasMessageError) {
                          return null;
                        }
                        return code;
                      }),
                    );
                    if (bannerCode == null) return const SizedBox.shrink();
                    return _buildErrorBanner(bannerCode);
                  },
                ),
                Expanded(child: _buildMessageList()),
                Consumer(
                  builder: (ctx, ref, _) {
                    final pendingPermission = ref.watch(
                      aiChatProvider.select((s) => s.pendingPermission),
                    );
                    if (pendingPermission == null) {
                      return const SizedBox.shrink();
                    }
                    return _buildPermissionCard(pendingPermission, ref);
                  },
                ),
                Consumer(
                  builder: (ctx, ref, _) {
                    final showFallback = ref.watch(
                      aiChatProvider.select(
                        (s) =>
                            s.authChallenge != null &&
                            !_hasAuthChallengeRenderedInMessages(s),
                      ),
                    );
                    if (!showFallback) return const SizedBox.shrink();
                    final challenge = ref.read(aiChatProvider).authChallenge;
                    if (challenge == null) return const SizedBox.shrink();
                    return Flexible(
                      child: SingleChildScrollView(
                        child: _buildAuthChallengeCard(challenge, cardRef: ref),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (ctx, ref, _) {
                    ref.watch(
                      aiChatProvider.select(
                        (s) => _InputAreaProjection(
                          hasActiveAgent: s.activeAgentProfile != null,
                          activeAgentId: s.activeAgentProfile?.id,
                          activeSessionId: s.activeSessionId,
                          hasActiveSession: s.activeSession != null,
                          workingDirectory: s.activeSession?.workingDirectory,
                          draftWorkingDirectory: s.draftWorkingDirectory,
                          isGenerating: s.isGenerating,
                          isAuthenticating: s.isAuthenticating,
                          isLoadingSettings: s.isLoadingSettings,
                          isApplyingSettings: s.isApplyingSettings,
                          isLoadingSessions: s.isLoadingSessions,
                          isLoadingMessages: s.isLoadingMessages,
                          recoveryStatus: s.recoveryStatus,
                          runSettings: s.runSettings,
                          capabilities: s.capabilities,
                          supportsImages: s.supportsImages,
                          supportsTextAttachments: s.supportsTextAttachments,
                          attachmentCount: s.attachments.length,
                          hasAccountOrDiagnostics:
                              s.activeAgentProfile != null ||
                              s.usage != null ||
                              s.diagnostics.isNotEmpty ||
                              s.account != null,
                        ),
                      ),
                    );
                    return _buildInputArea(ref.read(aiChatProvider), ref);
                  },
                ),
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
          Expanded(
            child: Tooltip(
              message:
                  state.activeAgentProfile?.name ??
                  context.l10n.noAgentAvailable,
              child: InkWell(
                onTap: _showAgentSwitcherModal,
                borderRadius: BorderRadius.circular(VRadius.input),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
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
          ),
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

  Widget _buildSessionsDrawer(bool isDesktop) {
    return Consumer(
      builder: (drawerContext, drawerRef, _) {
        final projection = drawerRef.watch(
          aiChatProvider.select(
            (s) => _SessionsDrawerProjection(
              activeSessionId: s.activeSessionId,
              activeAgentId: s.activeAgentProfile?.id,
              activeAgentName: s.activeAgentProfile?.name,
              shareAgentSessions: s.shareAgentSessions,
              isGenerating: s.isGenerating,
              hasMoreSessions: s.hasMoreSessions,
              isLoadingSessions: s.isLoadingSessions,
              sessions: s.sessions
                  .map((e) => _SessionEntryMeta(e.id, e.title))
                  .toList(growable: false),
            ),
          ),
        );
        final notifier = drawerRef.read(aiChatProvider.notifier);
        final serverId = drawerRef.watch(
          activeServerProvider.select((s) => s?.id),
        );
        final defaultAgentId = drawerRef.watch(
          defaultAgentSettingsProvider.select((m) => m['acp']),
        );
        ChatLaunchPreference preference = const ChatLaunchPreference();
        if (serverId != null && projection.activeAgentId != null) {
          try {
            final storage = drawerRef.read(localStorageServiceProvider);
            preference = storage.getChatLaunchPreference(
              serverId,
              projection.activeAgentId!,
              cli: false,
            );
          } catch (_) {}
        }
        final isDefaultAgent =
            projection.activeAgentId != null &&
            projection.activeAgentId == defaultAgentId;

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
                              onPressed: () =>
                                  _showRemoteSessionsDialog(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (projection.activeAgentId != null) ...[
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
                              '${context.l10n.defaultAgentTitle}: ${projection.activeAgentName ?? ""}',
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
                                borderRadius: BorderRadius.circular(
                                  VRadius.pill,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () => notifier.setDefaultAgent(
                                projection.activeAgentId!,
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
                                  child: Text(
                                    context.l10n.chatLaunchRememberLast,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: ChatLaunchMode.fixed,
                                  child: Text(
                                    context.l10n.chatLaunchFixedSession,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: ChatLaunchMode.blankDraft,
                                  child: Text(
                                    context.l10n.chatLaunchBlankDraft,
                                  ),
                                ),
                              ],
                              onChanged: (mode) {
                                if (mode != null) {
                                  notifier.setLaunchPreference(
                                    ChatLaunchPreference(
                                      mode: mode,
                                      sessionId: mode == ChatLaunchMode.fixed
                                          ? (projection.activeSessionId ??
                                                projection
                                                    .sessions
                                                    .firstOrNull
                                                    ?.id)
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
                    value: projection.shareAgentSessions,
                    onChanged: projection.isGenerating
                        ? null
                        : (val) => notifier.setShareAgentSessions(val),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                        projection.sessions.length +
                        (projection.hasMoreSessions ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == projection.sessions.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Center(
                            child: projection.isLoadingSessions
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
                                    icon: const Icon(
                                      Icons.expand_more,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.l10n.chatLoadMoreSessions,
                                    ),
                                    onPressed: () =>
                                        notifier.loadMoreSessions(),
                                  ),
                          ),
                        );
                      }
                      final session = projection.sessions[index];
                      final isSelected =
                          session.id == projection.activeSessionId;
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
                          color: isSelected
                              ? context.colorScheme.primary
                              : null,
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
                                  key: Key(
                                    'default_session_badge_${session.id}',
                                  ),
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
                                    key: Key(
                                      'set_default_session_${session.id}',
                                    ),
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
                                      const Icon(
                                        Icons.download_outlined,
                                        size: 16,
                                      ),
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
      },
    );
  }

  String _resolveLoadOlderMessagesLabel(BuildContext context) {
    return context.l10n.chatLoadOlderMessages;
  }

  Widget _buildMessageList() {
    return Consumer(
      builder: (listContext, listRef, _) {
        final frame = listRef.watch(
          aiChatProvider.select((s) {
            final session = s.activeSession;
            return _MessageListFrameProjection(
              activeSessionId: s.activeSessionId,
              messageOffset: session?.messageOffset ?? 0,
              messageCount: session?.messages.length ?? 0,
              isGenerating: s.isGenerating,
              isLoadingMessages: s.isLoadingMessages,
              hasActiveAgent: s.activeAgentProfile != null,
              recoveryStatus: s.recoveryStatus,
            );
          }),
        );

        if (frame.messageCount == 0) {
          final registry = listRef.watch(agentRegistryProvider);
          final hasUnreadyAgents = registry.agents.any(
            (a) =>
                a.status.kind == AgentEnvironmentStatusKind.cliMissing ||
                a.status.kind == AgentEnvironmentStatusKind.acpMissing ||
                a.status.kind == AgentEnvironmentStatusKind.notLoggedIn,
          );
          final singleCandidate = _getSingleInstallableCandidate(registry);
          final isConnected = listRef.watch(
            serverConnectionProvider.select((c) => c.isConnected),
          );
          final isRecovering =
              frame.recoveryStatus == SessionRecoveryStatus.reconnecting ||
              frame.recoveryStatus == SessionRecoveryStatus.syncing;

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
                  if (!frame.hasActiveAgent) ...[
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
                                        : () =>
                                              _oneClickInstall(singleCandidate),
                                  ))
                          : FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 16,
                              ),
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

        final hasOlder = frame.messageOffset > 0;
        final topCount = hasOlder ? 1 : 0;
        final sessionId = frame.activeSessionId ?? '';
        final currentMessages =
            listRef.read(aiChatProvider).activeSession?.messages ?? const [];

        return ListView.builder(
          key: ValueKey('message_list_$sessionId'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          findChildIndexCallback: (Key key) {
            if (key is ValueKey<String>) {
              final val = key.value;
              if (hasOlder && val == 'acp_load_older_messages_header') {
                return 0;
              }
              if (val == 'acp_receiving_indicator') {
                return frame.isGenerating
                    ? topCount + frame.messageCount
                    : null;
              }
              String id = val;
              if (val.startsWith('user_msg_')) {
                id = val.substring('user_msg_'.length);
              } else if (val.startsWith('assistant_msg_')) {
                id = val.substring('assistant_msg_'.length);
              } else if (val.startsWith('system_msg_')) {
                id = val.substring('system_msg_'.length);
              }
              final idx = currentMessages.indexWhere((m) => m.id == id);
              return idx >= 0 && idx < frame.messageCount
                  ? idx + topCount
                  : null;
            }
            if (key == const Key('acp_receiving_indicator')) {
              return frame.isGenerating ? topCount + frame.messageCount : null;
            }
            return null;
          },
          itemCount:
              topCount + frame.messageCount + (frame.isGenerating ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasOlder && index == 0) {
              return Center(
                key: const ValueKey('acp_load_older_messages_header'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextButton.icon(
                    key: const Key('acp_load_older_messages_button'),
                    icon: frame.isLoadingMessages
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward, size: 16),
                    label: Text(
                      frame.isLoadingMessages
                          ? context.l10n.cliLoadingOlderMessages
                          : _resolveLoadOlderMessagesLabel(context),
                    ),
                    onPressed: frame.isLoadingMessages
                        ? null
                        : () => ref
                              .read(aiChatProvider.notifier)
                              .loadOlderMessages(),
                  ),
                ),
              );
            }

            final messageIndex = hasOlder ? index - 1 : index;

            if (messageIndex == frame.messageCount) {
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
            final msg = currentMessages.length > messageIndex
                ? currentMessages[messageIndex]
                : null;
            if (msg == null) return const SizedBox.shrink();

            if (msg.role == MessageRole.user) {
              return KeyedSubtree(
                key: ValueKey('user_msg_${msg.id}'),
                child: _AiChatMessageItem(
                  key: ValueKey('${sessionId}_user_msg_${msg.id}'),
                  viewState: this,
                  sessionId: sessionId,
                  messageId: msg.id,
                  role: msg.role,
                ),
              );
            } else if (msg.role == MessageRole.system) {
              return KeyedSubtree(
                key: ValueKey('system_msg_${msg.id}'),
                child: _AiChatMessageItem(
                  key: ValueKey('${sessionId}_system_msg_${msg.id}'),
                  viewState: this,
                  sessionId: sessionId,
                  messageId: msg.id,
                  role: msg.role,
                ),
              );
            }
            return KeyedSubtree(
              key: ValueKey('assistant_msg_${msg.id}'),
              child: _AiChatMessageItem(
                key: ValueKey('${sessionId}_assistant_msg_${msg.id}'),
                viewState: this,
                sessionId: sessionId,
                messageId: msg.id,
                role: msg.role,
              ),
            );
          },
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

  Widget _buildUserBubble(ChatMessage msg, [String? sessionId]) {
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
            ] else if (msg.status == ChatTurnStatus.awaitingAuthentication) ...[
              const SizedBox(height: 4),
              Consumer(
                builder: (context, ref, _) {
                  final isConfirmed = ref.watch(
                    aiChatProvider.select(
                      (s) =>
                          s.authenticationConfirmed && s.authChallenge == null,
                    ),
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConfirmed
                            ? Icons.check_circle_outline
                            : Icons.lock_outline,
                        size: 12,
                        color: isConfirmed
                            ? context.colorScheme.primary
                            : context.vWarning,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isConfirmed
                              ? context.l10n.agentAuthRetryHint
                              : _chatStatusAwaitingAuthLabel(context),
                          style: TextStyle(
                            color: isConfirmed
                                ? context.colorScheme.primary
                                : context.vWarning,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (msg.failureCode != null && msg.failureCode!.isNotEmpty)
              _MessageFailureCard(
                message: msg,
                sessionId: sessionId ?? '',
                onLogin: () => _handleMessageFailureLogin(sessionId ?? '', msg),
                onRunSettings: () =>
                    _handleMessageFailureRunSettings(sessionId ?? '', msg),
                onReconnect: () =>
                    _handleMessageFailureReconnect(sessionId ?? '', msg),
                onReloadHistory: () =>
                    _handleMessageFailureReloadHistory(sessionId ?? '', msg),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg, [String? sessionId]) {
    final toolsById = {for (final tool in msg.toolExecutions) tool.id: tool};

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

            // Content Blocks (Interleaved Text & Tool Execution Cards)
            for (final block in msg.orderedContentBlocks) ...[
              if (block.type == ChatContentBlockType.tool) ...[
                if (toolsById[block.toolId] != null)
                  _ToolExecutionCard(
                    key: ValueKey('tool_${block.toolId}'),
                    tool: toolsById[block.toolId]!,
                    messageId: msg.id,
                  ),
              ] else if (block.type == ChatContentBlockType.text) ...[
                _buildTextBlock(context, msg, block),
              ],
            ],

            if (msg.content.isNotEmpty)
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
            ] else if (msg.status == ChatTurnStatus.awaitingAuthentication) ...[
              const SizedBox(height: 6),
              Consumer(
                builder: (authContext, authRef, _) {
                  final isConfirmed = authRef.watch(
                    aiChatProvider.select(
                      (s) =>
                          s.authenticationConfirmed && s.authChallenge == null,
                    ),
                  );
                  final currentChallenge = authRef.watch(
                    aiChatProvider.select((s) => s.authChallenge),
                  );
                  final hasChallenge =
                      currentChallenge != null &&
                      _isAuthChallengeTargetMessage(
                        msg,
                        authRef.read(aiChatProvider),
                      );
                  final showDiscovery = authRef.watch(
                    aiChatProvider.select(
                      (s) =>
                          s.authChallenge == null &&
                          !s.authenticationConfirmed &&
                          _isLatestAwaitingAuthMessage(msg, s),
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const Key('chat_status_awaiting_auth_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? context.colorScheme.primaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : context.vWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(VRadius.card),
                          border: Border.all(
                            color: isConfirmed
                                ? context.colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  )
                                : context.vWarning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConfirmed
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              size: 16,
                              color: isConfirmed
                                  ? context.colorScheme.primary
                                  : context.vWarning,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isConfirmed
                                    ? context.l10n.agentAuthRetryHint
                                    : _chatStatusAwaitingAuthLabel(context),
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: isConfirmed
                                      ? context.colorScheme.primary
                                      : context.vWarning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasChallenge) ...[
                        const SizedBox(height: 10),
                        _buildAuthChallengeCard(
                          currentChallenge,
                          margin: EdgeInsets.zero,
                          cardRef: authRef,
                        ),
                      ] else if (showDiscovery) ...[
                        const SizedBox(height: 10),
                        _buildAwaitingAuthDiscoveryAction(
                          authRef.read(aiChatProvider),
                          authRef,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            if (msg.failureCode != null && msg.failureCode!.isNotEmpty)
              _MessageFailureCard(
                message: msg,
                sessionId: sessionId ?? '',
                onLogin: () => _handleMessageFailureLogin(sessionId ?? '', msg),
                onRunSettings: () =>
                    _handleMessageFailureRunSettings(sessionId ?? '', msg),
                onReconnect: () =>
                    _handleMessageFailureReconnect(sessionId ?? '', msg),
                onReloadHistory: () =>
                    _handleMessageFailureReloadHistory(sessionId ?? '', msg),
              ),
            if (msg.attachments.isNotEmpty)
              _buildMessageAttachments(msg.attachments),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBlock(
    BuildContext context,
    ChatMessage msg,
    ChatContentBlock block,
  ) {
    final text =
        (block.start >= 0 &&
            block.end <= msg.content.length &&
            block.start < block.end)
        ? msg.content.substring(block.start, block.end)
        : '';
    if (text.isEmpty) return const SizedBox.shrink();

    return ValhallaCard(
      key: ValueKey('msg_${msg.id}_block_${block.start}'),
      color: context.colorScheme.surface,
      padding: const EdgeInsets.all(VSpace.md),
      child: MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(code: monoTextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildPermissionCard(PermissionRequest req, WidgetRef cardRef) {
    final notifier = cardRef.read(aiChatProvider.notifier);
    final danger = context.vDanger;
    final isConnected = cardRef.watch(
      serverConnectionProvider.select((c) => c.isConnected),
    );
    final recoveryStatus = cardRef.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final canRespond =
        isConnected &&
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
        !usesAntigravityAcp(profile) &&
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

      final registry = ref.read(agentRegistryProvider.notifier);
      final loginToken = registry.beginInteractiveLogin(currentProfile.id);
      if (loginToken == null) {
        if (mounted) {
          final runtime =
              ref.read(agentRegistryProvider).findRuntime(currentProfile.id);
          final errorMsg = runtime?.errorMessage == 'AGENT_UPDATE_IN_PROGRESS'
              ? context.l10n.agentUpdateInProgress
              : (runtime?.errorMessage ?? context.l10n.agentAuthRetryHint);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        return;
      }

      bool? result;
      try {
        final sshClient = ref
            .read(sshClientManagerProvider)
            .getClient(currentServer!.id);
        result = await ref.read(interactiveLoginLauncherProvider)(
          context: context,
          agentName: currentProfile.name,
          command: currentProfile.loginCommand!,
          serverName: currentServer.name,
          sshClient: sshClient,
          remoteExecCommand: remoteExecCommand,
        );
      } finally {
        registry.endInteractiveLogin(currentProfile.id, loginToken);
      }
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

    if (profile == null || !usesAntigravityAcp(profile)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.agentAuthRetryHint)),
        );
      }
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
        state.isAuthenticating ||
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
              state.isAuthenticating ||
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
    final snapshot = ref.read(aiChatProvider);
    final recoveryStatus = snapshot.recoveryStatus;
    if (!connState.isConnected ||
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
    final serverKey = ref.read(activeServerProvider)?.connectionKey;
    Object? selectedDir;
    try {
      selectedDir = await RemoteWorkspaceBrowserDialog.show(
        context,
        mode: RemoteBrowserMode.directory,
        initialPath: rawWorkingDir,
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.chatRemoteReadFailed}: $error')),
      );
      return;
    }
    if (!mounted || !context.mounted) return;
    final current = ref.read(aiChatProvider);
    if (ref.read(activeServerProvider)?.connectionKey != serverKey ||
        !ref.read(serverConnectionProvider).isConnected ||
        current.activeAgentProfile != snapshot.activeAgentProfile ||
        current.activeSessionId != snapshot.activeSessionId ||
        current.draftWorkingDirectory != snapshot.draftWorkingDirectory) {
      return;
    }
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
    final snapshot = ref.read(aiChatProvider);
    final recoveryStatus = snapshot.recoveryStatus;
    if (!connState.isConnected ||
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stateOffline)));
      return;
    }
    final serverKey = ref.read(activeServerProvider)?.connectionKey;
    bool current() {
      if (!mounted || !context.mounted) return false;
      final state = ref.read(aiChatProvider);
      return ref.read(activeServerProvider)?.connectionKey == serverKey &&
          ref.read(serverConnectionProvider).isConnected &&
          state.activeAgentProfile == snapshot.activeAgentProfile &&
          state.activeSessionId == snapshot.activeSessionId &&
          state.draftWorkingDirectory == snapshot.draftWorkingDirectory &&
          !state.isGenerating;
    }

    Object? selected;
    try {
      selected = await RemoteWorkspaceBrowserDialog.show(
        context,
        mode: RemoteBrowserMode.files,
      );
    } catch (error) {
      if (!current() || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.chatRemoteReadFailed}: $error')),
      );
      return;
    }
    if (!current()) return;
    if (selected is List<String> && selected.isNotEmpty) {
      final notifier = ref.read(aiChatProvider.notifier);
      final errors = <String, Object>{};
      for (final path in selected) {
        if (!current()) return;
        try {
          await notifier.attachRemoteFile(path);
        } catch (e) {
          errors[path] = e;
        }
      }
      if (!current() || !context.mounted) return;
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

  String _chatStatusAwaitingAuthLabel(BuildContext context) {
    try {
      final dynamic l10n = context.l10n;
      final dynamic val = l10n.chatStatusAwaitingAuth;
      if (val is String && val.isNotEmpty) return val;
    } catch (_) {}
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return isZh ? '等待 ACP 认证' : 'Awaiting ACP Authentication';
  }

  bool _isAuthChallengeTargetMessage(ChatMessage msg, AiChatState state) {
    if (state.authChallenge == null) return false;
    final messages = state.activeSession?.messages ?? [];
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == MessageRole.assistant &&
          m.status == ChatTurnStatus.awaitingAuthentication) {
        return m.id == msg.id;
      }
    }
    return false;
  }

  bool _hasAuthChallengeRenderedInMessages(AiChatState state) {
    if (state.authChallenge == null) return false;
    final messages = state.activeSession?.messages ?? [];
    return messages.any(
      (m) =>
          m.role == MessageRole.assistant &&
          m.status == ChatTurnStatus.awaitingAuthentication,
    );
  }

  String _resolveAuthErrorMessage(BuildContext context, String errorCode) {
    if (errorCode == 'ACP_AUTH_METHOD_UNAVAILABLE') {
      return context.l10n.chatAuthMethodUnavailable;
    }
    if (errorCode == 'ACP_AUTH_CONNECTION_EXPIRED') {
      return context.l10n.chatAuthConnectionExpired;
    }
    if (errorCode == 'ACP_AUTH_CALLBACK_DELIVERY_FAILED') {
      return context.l10n.chatAuthCallbackDeliveryFailed;
    }
    if (errorCode == 'ACP_AUTH_CALLBACK_LISTENER_FAILED') {
      return context.l10n.chatAuthCallbackListenerFailed;
    }
    if (errorCode == AiChatNotifier.disconnectedCode) {
      return context.l10n.sshDisconnectedAgentWarning;
    }
    return _resolveErrorMessage(errorCode);
  }

  Future<void> _launchAuthUrl(Uri url) async {
    final cur = ref.read(aiChatProvider);
    if (!cur.isAuthenticating || cur.authError != null) {
      return;
    }
    if (mounted) {
      setState(() => _authLaunchError = null);
    }
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() {
          _authLaunchError = context.l10n.chatAuthBrowserLaunchFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _authLaunchError = context.l10n.chatAuthBrowserLaunchFailed;
        });
      }
    }
  }

  Future<void> _showManualCallbackDialog(BuildContext context) async {
    final chatState = ref.read(aiChatProvider);
    final capturedRequest = chatState.authRequest;
    final capturedServerId = ref.read(activeServerProvider)?.id;
    final capturedAgentId = chatState.activeAgentProfile?.id;

    if (capturedRequest == null || !chatState.isAuthenticating) return;

    final controller = TextEditingController();
    try {
      String? callbackError;
      bool isSubmitting = false;

      final route = DialogRoute<void>(
        context: context,
        useSafeArea: true,
        themes: InheritedTheme.capture(
          from: context,
          to: Navigator.of(context, rootNavigator: true).context,
        ),
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              Future<void> handleSubmit() async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                controller.clear();
                final current = ref.read(aiChatProvider);
                final currentServer = ref.read(activeServerProvider);
                if (!current.isAuthenticating ||
                    current.authRequest != capturedRequest ||
                    current.activeAgentProfile?.id != capturedAgentId ||
                    currentServer?.id != capturedServerId) {
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  return;
                }
                setDialogState(() {
                  isSubmitting = true;
                  callbackError = null;
                });
                try {
                  await ref
                      .read(aiChatProvider.notifier)
                      .submitAuthCallback(text);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                } catch (_) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                      callbackError =
                          dialogCtx.l10n.chatAuthCallbackInvalidError;
                    });
                  }
                }
              }

              return PopScope(
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) {
                    controller.clear();
                  }
                },
                child: AlertDialog(
                  key: const Key('chat_auth_manual_callback_dialog'),
                  title: Text(dialogCtx.l10n.chatAuthManualCallbackTitle),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogCtx.l10n.chatAuthManualCallbackDesc,
                          style: dialogCtx.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('chat_auth_callback_input'),
                          controller: controller,
                          obscureText: true,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText:
                                dialogCtx.l10n.chatAuthCallbackInputLabel,
                            hintText: dialogCtx.l10n.chatAuthCallbackInputHint,
                            errorText: callbackError,
                          ),
                          onSubmitted: isSubmitting
                              ? null
                              : (_) => handleSubmit(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              controller.clear();
                              Navigator.of(dialogCtx).pop();
                            },
                      child: Text(
                        MaterialLocalizations.of(dialogCtx).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      key: const Key('chat_auth_callback_submit_button'),
                      onPressed: isSubmitting ? null : handleSubmit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              MaterialLocalizations.of(dialogCtx).okButtonLabel,
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      Navigator.of(context, rootNavigator: true).push<void>(route);
      await route.completed;
    } finally {
      controller.clear();
      controller.dispose();
    }
  }

  bool _isLatestAwaitingAuthMessage(ChatMessage msg, AiChatState state) {
    final messages = state.activeSession?.messages ?? [];
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == MessageRole.assistant &&
          m.status == ChatTurnStatus.awaitingAuthentication) {
        return m.id == msg.id;
      }
    }
    return false;
  }

  Widget _buildAwaitingAuthDiscoveryAction(
    AiChatState state,
    WidgetRef actionRef,
  ) {
    final connState = actionRef.watch(serverConnectionProvider);
    final isConnected = connState.isConnected;
    final isLoadingSettings = actionRef.watch(
      aiChatProvider.select((s) => s.isLoadingSettings),
    );
    final isGenerating = actionRef.watch(
      aiChatProvider.select((s) => s.isGenerating),
    );
    final isAuthenticating = actionRef.watch(
      aiChatProvider.select((s) => s.isAuthenticating),
    );
    final authError = actionRef.watch(
      aiChatProvider.select((s) => s.authError),
    );
    final isBusy =
        !isConnected || isLoadingSettings || isGenerating || isAuthenticating;
    final warning = context.vWarning;

    return Container(
      key: const Key('chat_awaiting_auth_discovery_card'),
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(color: warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 18, color: warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.chatAuthDiscoveryPrompt,
                  style: context.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (authError != null) ...[
            const SizedBox(height: 8),
            Text(
              _resolveAuthErrorMessage(context, authError),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.vDanger,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('chat_retry_auth_discovery_button'),
              icon: isLoadingSettings
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(context.l10n.chatRequestAuthButton),
              style: FilledButton.styleFrom(
                backgroundColor: warning,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: isBusy
                  ? null
                  : () => actionRef
                        .read(aiChatProvider.notifier)
                        .requestAuthentication(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthChallengeCard(
    AuthChallenge challenge, {
    EdgeInsetsGeometry? margin,
    required WidgetRef cardRef,
  }) {
    final notifier = cardRef.read(aiChatProvider.notifier);
    final isConnected = cardRef.watch(
      serverConnectionProvider.select((c) => c.isConnected),
    );
    final recoveryStatus = cardRef.watch(
      aiChatProvider.select((s) => s.recoveryStatus),
    );
    final isRecovering =
        recoveryStatus == SessionRecoveryStatus.reconnecting ||
        recoveryStatus == SessionRecoveryStatus.syncing;
    final currentChallenge =
        cardRef.watch(aiChatProvider.select((s) => s.authChallenge)) ??
        challenge;
    final authInfo = cardRef.watch(
      aiChatProvider.select(
        (s) => (
          s.isAuthenticating,
          s.authRequest,
          s.activeAgentProfile,
          s.authError,
        ),
      ),
    );
    final isAuthenticating = authInfo.$1;
    final authRequest = authInfo.$2;
    final activeProfile = authInfo.$3;
    final authError = authInfo.$4;

    final registry = cardRef.watch(agentRegistryProvider);
    final profile =
        registry.findRuntime(currentChallenge.agentId)?.profile ??
        activeProfile;
    final agentName = profile?.name ?? currentChallenge.agentId;

    final String? defaultMethodId =
        currentChallenge.methods.any((m) => m.id == 'oauth-personal')
        ? 'oauth-personal'
        : (currentChallenge.methods.isNotEmpty
              ? currentChallenge.methods.first.id
              : null);
    final String? selectedMethodId =
        (_selectedAuthMethodId != null &&
            currentChallenge.methods.any((m) => m.id == _selectedAuthMethodId))
        ? _selectedAuthMethodId
        : defaultMethodId;
    final warning = context.vWarning;

    return Container(
      key: const Key('ai_chat_auth_challenge_card'),
      margin: margin ?? const EdgeInsets.all(VSpace.md),
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
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                  ),
                  child: Text(
                    agentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.colorScheme.outline,
                    ),
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
          if (profile != null && usesAntigravityAcp(profile)) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.agentAuthAgYNotice,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
          if (isAuthenticating) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(
              context.l10n.chatAuthWaitingForBrowser,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (authRequest != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  key: const Key('chat_auth_reopen_browser_button'),
                  icon: const Icon(Icons.open_in_browser, size: 16),
                  label: Text(context.l10n.chatAuthReopenBrowser),
                  onPressed: () {
                    final cur = cardRef.read(aiChatProvider);
                    if (cur.authRequest != authRequest ||
                        !cur.isAuthenticating ||
                        cur.authError != null) {
                      return;
                    }
                    _launchAuthUrl(authRequest.authorizationUrl);
                  },
                ),
                OutlinedButton.icon(
                  key: const Key('chat_auth_copy_link_button'),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(context.l10n.chatAuthCopyLink),
                  onPressed: () async {
                    final cur = cardRef.read(aiChatProvider);
                    if (cur.authRequest != authRequest ||
                        !cur.isAuthenticating) {
                      return;
                    }
                    final snackContext = context;
                    await Clipboard.setData(
                      ClipboardData(
                        text: authRequest.authorizationUrl.toString(),
                      ),
                    );
                    if (mounted && snackContext.mounted) {
                      ScaffoldMessenger.of(snackContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            snackContext.l10n.agentLoginTerminalUrlCopied,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  key: const Key('chat_auth_manual_callback_button'),
                  icon: const Icon(Icons.vpn_key_outlined, size: 16),
                  label: Text(context.l10n.chatAuthManualCallback),
                  onPressed: () {
                    final cur = cardRef.read(aiChatProvider);
                    if (cur.authRequest != authRequest ||
                        !cur.isAuthenticating) {
                      return;
                    }
                    _showManualCallbackDialog(context);
                  },
                ),
              ],
            ),
          ],
          if (_authLaunchError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: context.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _authLaunchError!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (authError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: context.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resolveAuthErrorMessage(context, authError),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (currentChallenge.methods.isEmpty) ...[
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
          ] else if (currentChallenge.methods.length == 1) ...[
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
                    currentChallenge.methods.first.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (currentChallenge.methods.first.description != null &&
                      currentChallenge
                          .methods
                          .first
                          .description!
                          .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      currentChallenge.methods.first.description!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  context.l10n.agentAuthMethodLabel,
                  style: context.textTheme.labelMedium,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(
                    context.l10n.agentAuthPickerTitle(agentName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: isAuthenticating
                      ? null
                      : () async {
                          final picked = await showAuthMethodPickerDialog(
                            context: context,
                            agentName: agentName,
                            methods: currentChallenge.methods,
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
                if (isAuthenticating) return;
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
                  children: currentChallenge.methods.map((method) {
                    final isSelected = (selectedMethodId == method.id);
                    return InkWell(
                      onTap: isAuthenticating
                          ? null
                          : () => setState(
                              () => _selectedAuthMethodId = method.id,
                            ),
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
                              enabled: !isAuthenticating,
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
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => notifier.respondAuth(null),
                child: Text(context.l10n.agentAuthCancelButton),
              ),
              Tooltip(
                message: !isConnected
                    ? context.l10n.sshDisconnectedAgentWarning
                    : '',
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.vWarning,
                  ),
                  onPressed: (!isConnected || isRecovering || isAuthenticating)
                      ? null
                      : () => _handleProceedAuth(
                          selectedMethodId,
                          currentChallenge,
                        ),
                  child: Text(context.l10n.agentAuthProceedButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AiChatState state, WidgetRef inputRef) {
    final hasActiveAgent = state.activeAgentProfile != null;
    final registry = inputRef.watch(agentRegistryProvider);
    final hasUnreadyAgents = registry.agents.any(
      (a) =>
          a.status.kind == AgentEnvironmentStatusKind.cliMissing ||
          a.status.kind == AgentEnvironmentStatusKind.acpMissing ||
          a.status.kind == AgentEnvironmentStatusKind.notLoggedIn,
    );
    final singleCandidate = _getSingleInstallableCandidate(registry);
    final isConnected = inputRef.watch(
      serverConnectionProvider.select((c) => c.isConnected),
    );
    final isRecovering =
        state.recoveryStatus == SessionRecoveryStatus.reconnecting ||
        state.recoveryStatus == SessionRecoveryStatus.syncing;

    final isBusy =
        !hasActiveAgent ||
        _isSending ||
        state.isGenerating ||
        state.isAuthenticating ||
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
                  state.isAuthenticating ||
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
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: InkWell(
                          key: const Key('chat_working_dir_button'),
                          onTap:
                              (isBusy ||
                                  !isDraft ||
                                  !isConnected ||
                                  isRecovering)
                              ? null
                              : () => _showDraftWorkingDirDialog(
                                  context,
                                  rawWorkingDir,
                                ),
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
                                color: context
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                  VRadius.pill,
                                ),
                                border: Border.all(
                                  color: context.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
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
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
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
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        key: const Key('chat_commands_menu_button'),
                        tooltip: context.l10n.chatCommandsTooltip,
                        icon: _isLoadingComposerCommands
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                          if (!state.supportsImages &&
                              !state.supportsTextAttachments)
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
                    ],
                  ),
                ),
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

  void _handleMessageFailureLogin(String sessionId, ChatMessage message) {
    final curChat = ref.read(aiChatProvider);
    final curServer = ref.read(activeServerProvider);
    if (curChat.activeSessionId != sessionId) return;
    final messageAgentId =
        message.agentId ??
        (curChat.shareAgentSessions ? null : curChat.activeSession?.agentId);
    if (messageAgentId == null ||
        messageAgentId != curChat.activeAgentProfile?.id) {
      return;
    }
    if (curChat.activeSession?.serverId != null &&
        curChat.activeSession?.serverId != curServer?.id) {
      return;
    }

    final isBusy =
        curChat.isGenerating ||
        curChat.isAuthenticating ||
        curChat.isLoadingSettings ||
        curChat.isApplyingSettings ||
        curChat.isLoadingSessions ||
        curChat.isLoadingMessages ||
        curChat.pendingPermission != null;
    if (isBusy) return;

    final profile = curChat.activeAgentProfile;
    if (profile != null && usesAntigravityAcp(profile)) {
      ref.read(aiChatProvider.notifier).requestAuthentication();
    } else {
      _showManageAgentsModal();
    }
  }

  void _handleMessageFailureRunSettings(String sessionId, ChatMessage message) {
    final curChat = ref.read(aiChatProvider);
    final curServer = ref.read(activeServerProvider);
    if (curChat.activeSessionId != sessionId) return;
    final messageAgentId =
        message.agentId ??
        (curChat.shareAgentSessions ? null : curChat.activeSession?.agentId);
    if (messageAgentId == null ||
        messageAgentId != curChat.activeAgentProfile?.id) {
      return;
    }
    if (curChat.activeSession?.serverId != null &&
        curChat.activeSession?.serverId != curServer?.id) {
      return;
    }

    final isBusy =
        curChat.isGenerating ||
        curChat.isAuthenticating ||
        curChat.isLoadingSettings ||
        curChat.isApplyingSettings ||
        curChat.isLoadingSessions ||
        curChat.isLoadingMessages ||
        curChat.pendingPermission != null;
    if (isBusy) return;

    _openRunSettings(refresh: true);
  }

  Future<void> _handleMessageFailureReconnect(
    String sessionId,
    ChatMessage message,
  ) async {
    final curChat = ref.read(aiChatProvider);
    final curServer = ref.read(activeServerProvider);
    if (curChat.activeSessionId != sessionId) return;
    final messageAgentId =
        message.agentId ??
        (curChat.shareAgentSessions ? null : curChat.activeSession?.agentId);
    if (messageAgentId == null ||
        messageAgentId != curChat.activeAgentProfile?.id) {
      return;
    }
    if (curChat.activeSession?.serverId != null &&
        curChat.activeSession?.serverId != curServer?.id) {
      return;
    }

    final isBusy =
        curChat.isGenerating ||
        curChat.isAuthenticating ||
        curChat.isLoadingSettings ||
        curChat.isApplyingSettings ||
        curChat.isLoadingSessions ||
        curChat.isLoadingMessages ||
        curChat.pendingPermission != null;
    if (isBusy) return;

    final targetServerKey = curServer?.connectionKey;
    final targetAgentId = curChat.activeAgentProfile?.id;
    final targetSessionId = sessionId;

    final curConn = ref.read(serverConnectionProvider);
    if (!curConn.isConnected) {
      final connected = await ref
          .read(serverConnectionProvider.notifier)
          .connect();
      if (!connected || !mounted) return;
      final afterChat = ref.read(aiChatProvider);
      final afterServer = ref.read(activeServerProvider);
      if (afterServer?.connectionKey != targetServerKey) return;
      if (afterChat.activeSessionId != targetSessionId) return;
      if (afterChat.activeAgentProfile?.id != targetAgentId) return;
      if (afterChat.activeSession?.serverId != null &&
          afterChat.activeSession?.serverId != afterServer?.id) {
        return;
      }
      if (!ref.read(serverConnectionProvider).isConnected) return;
    }

    await ref.read(aiChatProvider.notifier).reconnectCurrentAgent();
  }

  Future<void> _handleMessageFailureReloadHistory(
    String sessionId,
    ChatMessage message,
  ) async {
    final curChat = ref.read(aiChatProvider);
    final curServer = ref.read(activeServerProvider);
    if (curChat.activeSessionId != sessionId) return;
    final messageAgentId =
        message.agentId ??
        (curChat.shareAgentSessions ? null : curChat.activeSession?.agentId);
    if (messageAgentId == null ||
        messageAgentId != curChat.activeAgentProfile?.id) {
      return;
    }
    if (curChat.activeSession?.serverId != null &&
        curChat.activeSession?.serverId != curServer?.id) {
      return;
    }

    final isBusy =
        curChat.isGenerating ||
        curChat.isAuthenticating ||
        curChat.isLoadingSettings ||
        curChat.isApplyingSettings ||
        curChat.isLoadingSessions ||
        curChat.isLoadingMessages ||
        curChat.pendingPermission != null;
    if (isBusy) return;

    final failure = message.failureCode ?? '';
    if (failure.contains('CHAT_HISTORY_LOAD_FAILED')) {
      await ref
          .read(aiChatProvider.notifier)
          .searchSessions(_sessionSearchController.text);
    } else if (failure.contains('CHAT_MESSAGES_LOAD_FAILED')) {
      final session = curChat.activeSession;
      if (session == null) return;
      if (session.messages.isEmpty) {
        await ref.read(aiChatProvider.notifier).selectSession(sessionId);
      } else if (session.messageOffset > 0) {
        await ref.read(aiChatProvider.notifier).loadOlderMessages();
      }
    }
  }
}

class _SessionEntryMeta {
  final String id;
  final String title;

  const _SessionEntryMeta(this.id, this.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SessionEntryMeta &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title;

  @override
  int get hashCode => Object.hash(id, title);
}

class _SessionsDrawerProjection {
  final String? activeSessionId;
  final String? activeAgentId;
  final String? activeAgentName;
  final bool shareAgentSessions;
  final bool isGenerating;
  final bool hasMoreSessions;
  final bool isLoadingSessions;
  final List<_SessionEntryMeta> sessions;

  const _SessionsDrawerProjection({
    required this.activeSessionId,
    required this.activeAgentId,
    required this.activeAgentName,
    required this.shareAgentSessions,
    required this.isGenerating,
    required this.hasMoreSessions,
    required this.isLoadingSessions,
    required this.sessions,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _SessionsDrawerProjection ||
        runtimeType != other.runtimeType) {
      return false;
    }
    return activeSessionId == other.activeSessionId &&
        activeAgentId == other.activeAgentId &&
        activeAgentName == other.activeAgentName &&
        shareAgentSessions == other.shareAgentSessions &&
        isGenerating == other.isGenerating &&
        hasMoreSessions == other.hasMoreSessions &&
        isLoadingSessions == other.isLoadingSessions &&
        listEquals(sessions, other.sessions);
  }

  @override
  int get hashCode => Object.hash(
    activeSessionId,
    activeAgentId,
    activeAgentName,
    shareAgentSessions,
    isGenerating,
    hasMoreSessions,
    isLoadingSessions,
    Object.hashAll(sessions),
  );
}

class _MessageListFrameProjection {
  final String? activeSessionId;
  final int messageOffset;
  final int messageCount;
  final bool isGenerating;
  final bool isLoadingMessages;
  final bool hasActiveAgent;
  final SessionRecoveryStatus recoveryStatus;

  const _MessageListFrameProjection({
    required this.activeSessionId,
    required this.messageOffset,
    required this.messageCount,
    required this.isGenerating,
    required this.isLoadingMessages,
    required this.hasActiveAgent,
    required this.recoveryStatus,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MessageListFrameProjection &&
          runtimeType == other.runtimeType &&
          activeSessionId == other.activeSessionId &&
          messageOffset == other.messageOffset &&
          messageCount == other.messageCount &&
          isGenerating == other.isGenerating &&
          isLoadingMessages == other.isLoadingMessages &&
          hasActiveAgent == other.hasActiveAgent &&
          recoveryStatus == other.recoveryStatus;

  @override
  int get hashCode => Object.hash(
    activeSessionId,
    messageOffset,
    messageCount,
    isGenerating,
    isLoadingMessages,
    hasActiveAgent,
    recoveryStatus,
  );
}

class _InputAreaProjection {
  final bool hasActiveAgent;
  final String? activeAgentId;
  final String? activeSessionId;
  final bool hasActiveSession;
  final String? workingDirectory;
  final String? draftWorkingDirectory;
  final bool isGenerating;
  final bool isAuthenticating;
  final bool isLoadingSettings;
  final bool isApplyingSettings;
  final bool isLoadingSessions;
  final bool isLoadingMessages;
  final SessionRecoveryStatus recoveryStatus;
  final ChatRunSettings runSettings;
  final AgentRuntimeCapabilities capabilities;
  final bool supportsImages;
  final bool supportsTextAttachments;
  final int attachmentCount;
  final bool hasAccountOrDiagnostics;

  const _InputAreaProjection({
    required this.hasActiveAgent,
    required this.activeAgentId,
    required this.activeSessionId,
    required this.hasActiveSession,
    required this.workingDirectory,
    required this.draftWorkingDirectory,
    required this.isGenerating,
    required this.isAuthenticating,
    required this.isLoadingSettings,
    required this.isApplyingSettings,
    required this.isLoadingSessions,
    required this.isLoadingMessages,
    required this.recoveryStatus,
    required this.runSettings,
    required this.capabilities,
    required this.supportsImages,
    required this.supportsTextAttachments,
    required this.attachmentCount,
    required this.hasAccountOrDiagnostics,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _InputAreaProjection &&
          runtimeType == other.runtimeType &&
          hasActiveAgent == other.hasActiveAgent &&
          activeAgentId == other.activeAgentId &&
          activeSessionId == other.activeSessionId &&
          hasActiveSession == other.hasActiveSession &&
          workingDirectory == other.workingDirectory &&
          draftWorkingDirectory == other.draftWorkingDirectory &&
          isGenerating == other.isGenerating &&
          isAuthenticating == other.isAuthenticating &&
          isLoadingSettings == other.isLoadingSettings &&
          isApplyingSettings == other.isApplyingSettings &&
          isLoadingSessions == other.isLoadingSessions &&
          isLoadingMessages == other.isLoadingMessages &&
          recoveryStatus == other.recoveryStatus &&
          runSettings == other.runSettings &&
          capabilities == other.capabilities &&
          supportsImages == other.supportsImages &&
          supportsTextAttachments == other.supportsTextAttachments &&
          attachmentCount == other.attachmentCount &&
          hasAccountOrDiagnostics == other.hasAccountOrDiagnostics;

  @override
  int get hashCode => Object.hashAll([
    hasActiveAgent,
    activeAgentId,
    activeSessionId,
    hasActiveSession,
    workingDirectory,
    draftWorkingDirectory,
    isGenerating,
    isAuthenticating,
    isLoadingSettings,
    isApplyingSettings,
    isLoadingSessions,
    isLoadingMessages,
    recoveryStatus,
    runSettings,
    capabilities,
    supportsImages,
    supportsTextAttachments,
    attachmentCount,
    hasAccountOrDiagnostics,
  ]);
}

class _AiChatMessageItem extends ConsumerWidget {
  final _AiChatViewState viewState;
  final String sessionId;
  final String messageId;
  final MessageRole role;

  const _AiChatMessageItem({
    super.key,
    required this.viewState,
    required this.sessionId,
    required this.messageId,
    required this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      aiChatProvider.select((state) {
        final session = state.sessions
            .where((entry) => entry.id == sessionId)
            .firstOrNull;
        return session?.messages
            .where((entry) => entry.id == messageId)
            .firstOrNull;
      }),
    );

    if (message == null) return const SizedBox.shrink();

    if (role == MessageRole.user) {
      return viewState._buildUserBubble(message, sessionId);
    } else if (role == MessageRole.system) {
      return viewState._buildSystemBubble(message);
    }
    return viewState._buildAssistantBubble(message, sessionId);
  }
}

class _MessageFailureCard extends ConsumerStatefulWidget {
  final ChatMessage message;
  final String sessionId;
  final VoidCallback onLogin;
  final VoidCallback onRunSettings;
  final VoidCallback onReconnect;
  final VoidCallback onReloadHistory;

  const _MessageFailureCard({
    required this.message,
    required this.sessionId,
    required this.onLogin,
    required this.onRunSettings,
    required this.onReconnect,
    required this.onReloadHistory,
  });

  @override
  ConsumerState<_MessageFailureCard> createState() =>
      _MessageFailureCardState();
}

class _MessageFailureCardState extends ConsumerState<_MessageFailureCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final failureCode = widget.message.failureCode;
    final isAwaitingAuth =
        widget.message.status == ChatTurnStatus.awaitingAuthentication;
    final presentation = classifyChatFailure(
      failureCode,
      authenticationRequired: isAwaitingAuth,
    );

    if (presentation == null) return const SizedBox.shrink();

    final activeSessionId = ref.watch(
      aiChatProvider.select((s) => s.activeSessionId),
    );
    final activeAgentId = ref.watch(
      aiChatProvider.select((s) => s.activeAgentProfile?.id),
    );
    final activeSessionServerId = ref.watch(
      aiChatProvider.select((s) => s.activeSession?.serverId),
    );
    final activeServerId = ref.watch(activeServerProvider.select((s) => s?.id));
    final isBusy = ref.watch(
      aiChatProvider.select(
        (s) =>
            s.isGenerating ||
            s.isAuthenticating ||
            s.isLoadingSettings ||
            s.isApplyingSettings ||
            s.isLoadingSessions ||
            s.isLoadingMessages ||
            s.pendingPermission != null,
      ),
    );

    final shareAgentSessions = ref.watch(
      aiChatProvider.select((s) => s.shareAgentSessions),
    );
    final messageAgentId =
        widget.message.agentId ??
        (shareAgentSessions
            ? null
            : ref.watch(
                aiChatProvider.select((s) => s.activeSession?.agentId),
              ));

    final matchesSession =
        activeSessionId != null && activeSessionId == widget.sessionId;
    final matchesAgent =
        messageAgentId != null &&
        activeAgentId != null &&
        messageAgentId == activeAgentId;
    final matchesServer =
        activeSessionServerId == null ||
        (activeServerId != null && activeSessionServerId == activeServerId);
    final matchesTarget =
        matchesSession && matchesAgent && matchesServer && !isBusy;

    ChatFailureAction effectiveAction = presentation.suggestedAction;

    if (!matchesTarget) {
      effectiveAction = ChatFailureAction.details;
    } else if (effectiveAction == ChatFailureAction.reloadHistory) {
      final code = failureCode ?? '';
      if (code.contains('CHAT_HISTORY_LOAD_FAILED')) {
        // Can retry search
      } else if (code.contains('CHAT_MESSAGES_LOAD_FAILED')) {
        final (offset, count) = ref.watch(
          aiChatProvider.select(
            (s) => (
              s.activeSession?.messageOffset ?? 0,
              s.activeSession?.messages.length ?? 0,
            ),
          ),
        );
        if (count == 0) {
          // Can retry selectSession
        } else if (offset > 0) {
          // Can load older messages
        } else {
          // offset == 0 with existing messages: loadOlderMessages will early return!
          effectiveAction = ChatFailureAction.details;
        }
      } else {
        effectiveAction = ChatFailureAction.details;
      }
    }

    final l10n = context.l10n;
    final kindTitle = switch (presentation.kind) {
      ChatFailureKind.auth => l10n.chatFailureKindAuth,
      ChatFailureKind.modelUnavailable => l10n.chatFailureKindModelUnavailable,
      ChatFailureKind.connection => l10n.chatFailureKindConnection,
      ChatFailureKind.history => l10n.chatFailureKindHistory,
      ChatFailureKind.other => l10n.chatFailureKindOther,
    };

    final actionLabel = switch (effectiveAction) {
      ChatFailureAction.login => l10n.chatFailureActionLogin,
      ChatFailureAction.runSettings => l10n.chatFailureActionRunSettings,
      ChatFailureAction.reconnect => l10n.chatFailureActionReconnect,
      ChatFailureAction.reloadHistory => l10n.chatFailureActionReloadHistory,
      ChatFailureAction.details => l10n.chatFailureActionDetails,
    };

    final sanitizedError = LogSanitizer.sanitize(failureCode ?? '');
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isNarrow = MediaQuery.sizeOf(context).width < 360 || textScale > 1.3;

    final actionWidget = TextButton(
      key: Key('chat_failure_action_${widget.message.id}'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(44, 44),
      ),
      onPressed: () {
        switch (effectiveAction) {
          case ChatFailureAction.login:
            widget.onLogin();
            break;
          case ChatFailureAction.runSettings:
            widget.onRunSettings();
            break;
          case ChatFailureAction.reconnect:
            widget.onReconnect();
            break;
          case ChatFailureAction.reloadHistory:
            widget.onReloadHistory();
            break;
          case ChatFailureAction.details:
            break;
        }
      },
      child: Text(
        actionLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.primary,
        ),
      ),
    );

    final detailsToggleWidget = IconButton(
      key: Key('chat_failure_details_toggle_${widget.message.id}'),
      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16),
      tooltip: l10n.chatFailureActionDetails,
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
    );

    return Container(
      key: Key('chat_message_failure_card_${widget.message.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.vDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(color: context.vDanger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNarrow) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: context.vDanger,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kindTitle,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.vDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (effectiveAction != ChatFailureAction.details)
                    actionWidget,
                  detailsToggleWidget,
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: context.vDanger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kindTitle,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.vDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (effectiveAction != ChatFailureAction.details) actionWidget,
                detailsToggleWidget,
              ],
            ),
          ],
          if (_expanded && sanitizedError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      sanitizedError,
                      style: monoTextStyle(
                        fontSize: 11,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: Key('chat_failure_copy_${widget.message.id}'),
                    icon: const Icon(Icons.copy, size: 14),
                    tooltip: l10n.copy,
                    visualDensity: VisualDensity.standard,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sanitizedError));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.updateErrorCopied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatErrorBanner extends StatefulWidget {
  final String errorCode;
  final VoidCallback? onReloadHistory;

  const _ChatErrorBanner({required this.errorCode, this.onReloadHistory});

  @override
  State<_ChatErrorBanner> createState() => _ChatErrorBannerState();
}

class _ChatErrorBannerState extends State<_ChatErrorBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final presentation = classifyChatFailure(widget.errorCode);
    final l10n = context.l10n;

    final String kindTitle;
    if (widget.errorCode.startsWith('CHAT_SESSION_IDENTITY_MISMATCH')) {
      kindTitle = l10n.chatSessionIdentityMismatch;
    } else if (widget.errorCode == AiChatNotifier.notReadyCode ||
        widget.errorCode.startsWith('AGENT_NOT_READY')) {
      kindTitle = l10n.agentNotReadyError;
    } else if (presentation != null) {
      kindTitle = switch (presentation.kind) {
        ChatFailureKind.auth => l10n.chatFailureKindAuth,
        ChatFailureKind.modelUnavailable =>
          l10n.chatFailureKindModelUnavailable,
        ChatFailureKind.connection => l10n.chatFailureKindConnection,
        ChatFailureKind.history => l10n.chatFailureKindHistory,
        ChatFailureKind.other => l10n.chatFailureKindOther,
      };
    } else {
      kindTitle = l10n.chatFailureKindOther;
    }

    final sanitizedError = LogSanitizer.sanitize(widget.errorCode);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isNarrow = MediaQuery.sizeOf(context).width < 360 || textScale > 1.3;

    Widget? actionButton;
    if (widget.errorCode == AiChatNotifier.notReadyCode ||
        widget.errorCode.startsWith('AGENT_NOT_READY')) {
      actionButton = TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 44),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgentManagementView()),
          );
        },
        child: Text(
          l10n.manageAgents,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (presentation?.suggestedAction ==
            ChatFailureAction.reloadHistory &&
        widget.onReloadHistory != null) {
      actionButton = TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 44),
        ),
        onPressed: widget.onReloadHistory,
        child: Text(
          l10n.chatFailureActionReloadHistory,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final detailsButton = IconButton(
      icon: Icon(
        _expanded ? Icons.expand_less : Icons.expand_more,
        size: 16,
        color: context.colorScheme.onErrorContainer,
      ),
      tooltip: l10n.chatFailureActionDetails,
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: () => setState(() => _expanded = !_expanded),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colorScheme.errorContainer.withValues(alpha: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNarrow) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 18,
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kindTitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [?actionButton, detailsButton],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: context.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kindTitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?actionButton,
                detailsButton,
              ],
            ),
          ],
          if (_expanded && sanitizedError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      sanitizedError,
                      style: monoTextStyle(
                        fontSize: 11,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    tooltip: l10n.copy,
                    visualDensity: VisualDensity.standard,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sanitizedError));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.updateErrorCopied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
