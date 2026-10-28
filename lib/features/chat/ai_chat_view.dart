import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
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
import '../../core/providers/remote_workspace_provider.dart';
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
import '../../infrastructure/acp/acp_runtime_service.dart'
    show AcpRuntimeStatus;
import '../../infrastructure/cli/agent_execution_target.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/chat_link_target.dart';
import '../../data/models/chat_workspace.dart';
import '../../infrastructure/acp/acp_workspace_files.dart'
    show AcpTextSnapshot, AcpWorkspaceFiles;
import '../../infrastructure/sftp/sftp_client_service.dart' show SftpFileItem;
import 'widgets/chat_run_settings_dialog.dart';
import 'widgets/chat_run_settings_strip.dart';
import 'widgets/chat_commands_skills_dialog.dart';
import 'widgets/chat_history_search_dialog.dart';
import 'widgets/image_zoom_dialog.dart';
import 'widgets/persistent_runtime_consent_dialog.dart';
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
  ScrollController _scrollController = ScrollController(
    initialScrollOffset: 1000000.0,
    keepScrollOffset: false,
  );
  bool _hasClampedToBottom = false;
  String? _selectedAuthMethodId;
  String? _scrolledSessionId;
  bool _pendingInitialHistory = false;
  bool _userNearBottom = true;
  int _unreadMessageCount = 0;
  int _lastSeenEndIndex = 0;
  String? _lastSeenTailMessageId;
  bool _isSending = false;
  bool _isLoadingComposerCommands = false;
  AcpOAuthRequest? _lastAutoLaunchedAuthRequest;
  String? _authLaunchError;
  bool _isShowingPersistentRuntimeConsentDialog = false;
  bool _showWorkbench = false;
  final Map<String, bool> _codeBlockExpandedState = <String, bool>{};
  final Set<String> _expandedToolIds = <String>{};
  String? _dismissedErrorCode;

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
    final initialSession = initialChat.activeSession;
    final initialSessionId = initialChat.activeSessionId;
    final initialServerKey = ref.read(activeServerProvider)?.connectionKey;
    final initialAgentId = initialChat.activeAgentProfile?.id;
    _scrolledSessionId = initialSessionId;
    _pendingInitialHistory =
        initialSession == null || initialSession.messages.isEmpty;
    if (initialSession != null) {
      _lastSeenEndIndex =
          initialSession.messageOffset + initialSession.messages.length;
      _lastSeenTailMessageId = initialSession.messages.lastOrNull?.id;
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clampToBottom(
        expectedSessionId: initialSessionId,
        expectedAgentId: initialAgentId,
        expectedServerKey: initialServerKey,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(aiChatProvider).persistentRuntimeSetupRequired &&
          !_isShowingPersistentRuntimeConsentDialog) {
        _isShowingPersistentRuntimeConsentDialog = true;
        PersistentRuntimeConsentDialog.show(context).whenComplete(() {
          if (mounted) _isShowingPersistentRuntimeConsentDialog = false;
        });
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final nearBottom = (max - current) <= 80;
    if (_userNearBottom != nearBottom) {
      setState(() {
        _userNearBottom = nearBottom;
        if (nearBottom) {
          _unreadMessageCount = 0;
          final session = ref.read(aiChatProvider).activeSession;
          if (session != null) {
            _lastSeenEndIndex = session.messageOffset + session.messages.length;
            _lastSeenTailMessageId = session.messages.lastOrNull?.id;
          }
        }
      });
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

  void _resetScrollControllerForNewSession() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollController = ScrollController(
      initialScrollOffset: 1000000.0,
      keepScrollOffset: false,
    );
    _scrollController.addListener(_onScroll);
    _hasClampedToBottom = false;
  }

  void _clampToBottom({
    String? expectedSessionId,
    String? expectedAgentId,
    Object? expectedServerKey,
    int maxPasses = 5,
  }) {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      if (maxPasses > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clampToBottom(
            expectedSessionId: expectedSessionId,
            expectedAgentId: expectedAgentId,
            expectedServerKey: expectedServerKey,
            maxPasses: maxPasses - 1,
          );
        });
      } else if (!_hasClampedToBottom) {
        setState(() {
          _hasClampedToBottom = true;
        });
      }
      return;
    }

    final currentChat = ref.read(aiChatProvider);
    final currentServer = ref.read(activeServerProvider);
    if (expectedSessionId != null &&
        currentChat.activeSessionId != expectedSessionId) {
      return;
    }
    if (expectedAgentId != null &&
        currentChat.activeAgentProfile?.id != expectedAgentId) {
      return;
    }
    if (expectedServerKey != null &&
        currentServer?.connectionKey != expectedServerKey) {
      return;
    }

    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) {
      if (maxPasses > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clampToBottom(
            expectedSessionId: expectedSessionId,
            expectedAgentId: expectedAgentId,
            expectedServerKey: expectedServerKey,
            maxPasses: maxPasses - 1,
          );
        });
      } else if (!_hasClampedToBottom) {
        setState(() {
          _hasClampedToBottom = true;
        });
      }
      return;
    }

    _userNearBottom = true;
    final maxScroll = pos.maxScrollExtent;
    if ((pos.pixels - maxScroll).abs() > 1.0) {
      _scrollController.jumpTo(maxScroll);
    }
    if (!_hasClampedToBottom) {
      setState(() {
        _hasClampedToBottom = true;
      });
    }

    if (maxPasses > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final nextPos = _scrollController.position;
        if (!nextPos.hasContentDimensions) return;
        if ((nextPos.pixels - nextPos.maxScrollExtent).abs() > 1.0) {
          _clampToBottom(
            expectedSessionId: expectedSessionId,
            expectedAgentId: expectedAgentId,
            expectedServerKey: expectedServerKey,
            maxPasses: maxPasses - 1,
          );
        }
      });
    }
  }

  void _scrollToBottom({bool settle = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    final chatState = ref.read(aiChatProvider);
    final targetSessionId = chatState.activeSessionId;
    final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
    final targetAgentId = chatState.activeAgentProfile?.id;

    final future = _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );

    if (settle) {
      future
          .then((_) {
            if (!mounted || !_scrollController.hasClients || !_userNearBottom) {
              return;
            }
            final currentChat = ref.read(aiChatProvider);
            final currentServer = ref.read(activeServerProvider);
            if (currentChat.activeSessionId != targetSessionId ||
                currentChat.activeAgentProfile?.id != targetAgentId ||
                currentServer?.connectionKey != targetServerKey) {
              return;
            }
            _clampToBottom(
              expectedSessionId: targetSessionId,
              expectedAgentId: targetAgentId,
              expectedServerKey: targetServerKey,
            );
          })
          .catchError((_) {});
    }
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

    final workspaceState = ref.read(remoteWorkspaceProvider);
    if (workspaceState.enabled &&
        chatState.activeSession != null &&
        !chatState.workspaceHasControl) {
      return;
    }

    final text = _promptController.text.trim();
    if ((text.isEmpty && chatState.attachments.isEmpty) ||
        _isSending ||
        chatState.isGenerating ||
        (chatState.isServerBusy && !chatState.isViewingRun) ||
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

    String? caughtError;
    try {
      await ref.read(aiChatProvider.notifier).sendMessage(text);
    } catch (e) {
      caughtError = e.toString();
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

    final errorCode = afterState.lastErrorCode ?? caughtError ?? '';
    final isBusyOrPreparing =
        errorCode.contains('ACP_RUNTIME_SERVER_BUSY') ||
        errorCode.contains('PREPARING') ||
        errorCode.contains('BUSY');

    final shouldRestoreDraft =
        targetMatches &&
        _promptController.text.isEmpty &&
        (isBusyOrPreparing ||
            (!afterState.isGenerating &&
                (afterState.lastErrorCode != null ||
                    afterState.authChallenge != null)));

    if (shouldRestoreDraft) {
      _promptController.text = text;
      _promptController.selection = TextSelection.collapsed(
        offset: text.length,
      );
      ref.read(aiChatProvider.notifier).updateDraftText(text);
    }
  }

  Future<void> _confirmAndDeleteSession(
    BuildContext context,
    String sessionId,
    String title,
  ) async {
    final activeServer = ref.read(activeServerProvider);
    final targetServerKey = activeServer?.connectionKey.toString();
    final session = ref
        .read(aiChatProvider)
        .sessions
        .where((s) => s.id == sessionId)
        .firstOrNull;
    final managedKeys =
        session?.agentContexts.values
            .map((c) => c.persistentRuntimeKey)
            .whereType<String>()
            .toSet() ??
        const <String>{};
    final bool hasManagedRuntimes = managedKeys.isNotEmpty;

    bool stopAndClearRemote = false;
    bool isDeleting = false;
    bool isLoadingRuntimes = hasManagedRuntimes;
    bool didStartInspect = false;
    List<AcpRuntimeStatus>? runtimeStatuses;
    String? inspectError;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (hasManagedRuntimes && !didStartInspect) {
            didStartInspect = true;
            ref
                .read(aiChatProvider.notifier)
                .inspectSessionRuntimes(sessionId)
                .then((statuses) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      isLoadingRuntimes = false;
                      runtimeStatuses = statuses;
                    });
                  }
                })
                .catchError((e) {
                  if (ctx.mounted) {
                    setDialogState(() {
                      isLoadingRuntimes = false;
                      inspectError = e.toString();
                    });
                  }
                });
          }

          return PopScope(
            canPop: !isDeleting,
            child: AlertDialog(
              title: Text(ctx.l10n.deleteSessionTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctx.l10n.deleteSessionConfirmMessage(title)),
                    const SizedBox(height: 12),
                    if (isLoadingRuntimes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ctx.l10n.deleteSessionInspectingRuntimes,
                                style: ctx.textTheme.bodySmall?.copyWith(
                                  color: ctx.colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (runtimeStatuses != null && runtimeStatuses!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ctx.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          border: Border.all(
                            color: ctx.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.l10n.deleteSessionAffectedRuntimes,
                              style: ctx.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...runtimeStatuses!.map(
                              (status) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      status.alive
                                          ? Icons.check_circle_outline
                                          : Icons.pause_circle_outline,
                                      size: 14,
                                      color: status.isBusy
                                          ? ctx.colorScheme.primary
                                          : ctx.colorScheme.outline,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${status.runtimeKey} (${status.state})',
                                        style: ctx.textTheme.bodySmall
                                            ?.copyWith(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
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
                      ),
                    if (inspectError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          ctx.l10n.deleteSessionOfflineNotice,
                          style: ctx.textTheme.bodySmall?.copyWith(
                            color: ctx.colorScheme.outline,
                          ),
                        ),
                      ),
                    RadioGroup<bool>(
                      groupValue: stopAndClearRemote,
                      onChanged: (val) {
                        if (isDeleting || val == null) return;
                        if (val && !hasManagedRuntimes) return;
                        setDialogState(() {
                          stopAndClearRemote = val;
                          errorMessage = null;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<bool>(
                            key: const Key('delete_session_mode_local_only'),
                            value: false,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              ctx.l10n.deleteSessionLocalOnlyOption,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              ctx.l10n.deleteSessionLocalOnlyNotice,
                              style: ctx.textTheme.bodySmall?.copyWith(
                                color: ctx.colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          RadioListTile<bool>(
                            key: const Key('delete_session_mode_purge_remote'),
                            value: true,
                            enabled: !isDeleting && hasManagedRuntimes,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              ctx.l10n.deleteSessionStopAndPurgeOption,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasManagedRuntimes
                                    ? null
                                    : ctx.colorScheme.outline,
                              ),
                            ),
                            subtitle: Text(
                              hasManagedRuntimes
                                  ? ctx.l10n.deleteSessionPurgeRemoteWarning
                                  : ctx.l10n.deleteSessionNoManagedRuntimes,
                              style: ctx.textTheme.bodySmall?.copyWith(
                                color: hasManagedRuntimes
                                    ? ctx.colorScheme.error
                                    : ctx.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ctx.colorScheme.errorContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          border: Border.all(
                            color: ctx.colorScheme.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: ctx.colorScheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: ctx.textTheme.bodySmall?.copyWith(
                                  color: ctx.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(
                  key: const Key('confirmDeleteSessionButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ctx.colorScheme.error,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                            errorMessage = null;
                          });
                          try {
                            await ref
                                .read(aiChatProvider.notifier)
                                .deleteSession(
                                  sessionId,
                                  stopAndClearRemote: stopAndClearRemote,
                                  expectedServerKey: targetServerKey,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                                errorMessage = e.toString();
                              });
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(ctx.l10n.deleteSessionConfirmAction),
                ),
              ],
            ),
          );
        },
      ),
    );
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
    } else if (errorCode == 'WORKSPACE_RUNTIME_UPGRADE_REQUIRED') {
      return context.l10n.serverWorkspaceErrorRuntimeUpgradeRequired;
    } else if (errorCode == 'WORKSPACE_CONTROL_REQUIRED' ||
        errorCode == 'WORKSPACE_CONTROL_HELD') {
      return context.l10n.serverWorkspaceErrorControlHeld;
    } else {
      return errorCode;
    }
  }

  Widget _buildErrorBanner(String errorCode, {VoidCallback? onDismiss}) {
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
          onDismiss: onDismiss,
        );
      },
    );
  }

  Widget _buildServerRunningBanner(
    BuildContext context,
    AcpActiveRun serverRun, {
    bool isSshConnected = true,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 2,
      child: Container(
        key: const Key('acp_server_running_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh,
          border: Border(
            bottom: BorderSide(
              color: isSshConnected
                  ? context.colorScheme.primary.withValues(alpha: 0.2)
                  : context.vWarning.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: isSshConnected
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.primary,
                    )
                  : Icon(
                      Icons.cloud_off_outlined,
                      size: 14,
                      color: context.vWarning,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSshConnected
                    ? context.l10n.acpRunningSessionIndicator(
                        serverRun.agentName,
                      )
                    : context.l10n.acpAgentOfflineTaskRunning,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: const Key('acp_return_to_running_session_button'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
              ),
              onPressed: () {
                ref.read(aiChatProvider.notifier).returnToRunningSession();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.acpReturnToRunningSession,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeServerProvider.select((s) => s?.id), (prev, next) {
      if (prev != next) {
        _dismissedErrorCode = null;
      }
    });
    ref.listen<AiChatState>(aiChatProvider, (previous, next) {
      final previousUnread = _unreadMessageCount;
      final prevSessionId = previous?.activeSession?.id;
      final nextSessionId = next.activeSession?.id;
      final prevMessages = previous?.activeSession?.messages ?? const [];
      final nextMessages = next.activeSession?.messages ?? const [];

      final prevAgentId = previous?.activeAgentProfile?.id;
      final nextAgentId = next.activeAgentProfile?.id;
      final prevServerId = previous?.activeAgentProfile?.serverId;
      final nextServerId = next.activeAgentProfile?.serverId;

      if (next.lastErrorCode == null ||
          nextSessionId != prevSessionId ||
          nextAgentId != prevAgentId ||
          nextServerId != prevServerId) {
        _dismissedErrorCode = null;
      }
      if (nextSessionId != prevSessionId ||
          nextAgentId != prevAgentId ||
          nextServerId != prevServerId) {
        _isShowingPersistentRuntimeConsentDialog = false;
        if (_promptController.text != next.draftText) {
          _promptController.text = next.draftText;
          _promptController.selection = TextSelection.collapsed(
            offset: next.draftText.length,
          );
        }
      }

      final sessionOrAgentChanged =
          (nextSessionId != null && nextSessionId != _scrolledSessionId) ||
          (nextAgentId != null && nextAgentId != prevAgentId) ||
          (nextServerId != null && nextServerId != prevServerId);

      if (sessionOrAgentChanged && nextSessionId != null) {
        _scrolledSessionId = nextSessionId;
        _userNearBottom = true;
        _unreadMessageCount = 0;
        final nextEndIndex =
            (next.activeSession?.messageOffset ?? 0) + nextMessages.length;
        _lastSeenEndIndex = nextEndIndex;
        _lastSeenTailMessageId = nextMessages.lastOrNull?.id;
        _pendingInitialHistory = nextMessages.isEmpty;
        _resetScrollControllerForNewSession();
        final targetSessionId = nextSessionId;
        final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
        final targetAgentId = next.activeAgentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clampToBottom(
            expectedSessionId: targetSessionId,
            expectedAgentId: targetAgentId,
            expectedServerKey: targetServerKey,
          );
        });
        if (_unreadMessageCount != previousUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        return;
      }

      final hasLoadedInitialMessages =
          (_pendingInitialHistory || prevMessages.isEmpty) &&
          nextMessages.isNotEmpty;

      if (hasLoadedInitialMessages) {
        _pendingInitialHistory = false;
        _userNearBottom = true;
        final nextEndIndex =
            (next.activeSession?.messageOffset ?? 0) + nextMessages.length;
        _lastSeenEndIndex = nextEndIndex;
        _lastSeenTailMessageId = nextMessages.lastOrNull?.id;
        final targetSessionId = nextSessionId;
        final targetServerKey = ref.read(activeServerProvider)?.connectionKey;
        final targetAgentId = next.activeAgentProfile?.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clampToBottom(
            expectedSessionId: targetSessionId,
            expectedAgentId: targetAgentId,
            expectedServerKey: targetServerKey,
          );
        });
      }

      if (!sessionOrAgentChanged &&
          prevSessionId == nextSessionId &&
          nextSessionId != null) {
        final currentEndIndex =
            (next.activeSession?.messageOffset ?? 0) + nextMessages.length;
        final currentTailId = nextMessages.lastOrNull?.id;
        if (!_userNearBottom) {
          // Prepending older history decreases messageOffset, but currentEndIndex
          // (messageOffset + length) and tail message ID remain unchanged.
          // Only increment unread counter for new messages appended at the tail.
          if (currentEndIndex > _lastSeenEndIndex &&
              currentTailId != _lastSeenTailMessageId) {
            final delta = currentEndIndex - _lastSeenEndIndex;
            _unreadMessageCount += delta;
            _lastSeenEndIndex = currentEndIndex;
            _lastSeenTailMessageId = currentTailId;
          }
        } else {
          _lastSeenEndIndex = currentEndIndex;
          _lastSeenTailMessageId = currentTailId;
          _unreadMessageCount = 0;
        }
      }

      if (_unreadMessageCount != previousUnread) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
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

      if (!next.persistentRuntimeSetupRequired) {
        _isShowingPersistentRuntimeConsentDialog = false;
      } else if (!_isShowingPersistentRuntimeConsentDialog) {
        _isShowingPersistentRuntimeConsentDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          PersistentRuntimeConsentDialog.show(context).whenComplete(() {
            if (mounted) {
              _isShowingPersistentRuntimeConsentDialog = false;
            }
          });
        });
      }
    });

    final isDesktop = context.isDesktop;

    final scaffold = Scaffold(
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
                          s.workspaceHasControl,
                          s.workspaceControlBusy,
                          s.workspaceControlOwnerDeviceId,
                          s.activeSession != null,
                        ),
                      ),
                    );
                    ref.watch(remoteWorkspaceProvider.select((w) => w.enabled));
                    return _buildHeaderBar(ref.read(aiChatProvider), isDesktop);
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(child: _buildMessageList()),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Consumer(
                              builder: (ctx, ref, _) {
                                final bannerCode = ref.watch(
                                  aiChatProvider.select((s) {
                                    final code = s.lastErrorCode;
                                    if (code == null ||
                                        code ==
                                            AiChatNotifier.disconnectedCode ||
                                        code ==
                                            AiChatNotifier.authRequiredCode ||
                                        s.authChallenge != null ||
                                        s.authError != null) {
                                      return null;
                                    }
                                    final hasMessageError =
                                        s.activeSession?.messages.any(
                                          (m) =>
                                              m.failureCode == code ||
                                              (m.role ==
                                                      MessageRole.assistant &&
                                                  m.content.endsWith(
                                                    '**Error:** $code',
                                                  )),
                                        ) ??
                                        false;
                                    if (hasMessageError) {
                                      return null;
                                    }
                                    return code;
                                  }),
                                );
                                if (bannerCode == null ||
                                    _dismissedErrorCode == bannerCode) {
                                  return const SizedBox.shrink();
                                }
                                return _buildErrorBanner(
                                  bannerCode,
                                  onDismiss: () => setState(
                                    () => _dismissedErrorCode = bannerCode,
                                  ),
                                );
                              },
                            ),
                            Consumer(
                              builder: (ctx, ref, _) {
                                final serverRun = ref.watch(
                                  aiChatProvider.select((s) => s.serverRun),
                                );
                                final isViewingRun = ref.watch(
                                  aiChatProvider.select((s) => s.isViewingRun),
                                );
                                final isSshConnected = ref.watch(
                                  serverConnectionProvider.select(
                                    (s) => s.isConnected,
                                  ),
                                );
                                if (serverRun != null &&
                                    !isViewingRun &&
                                    serverRun.isBusy) {
                                  return _buildServerRunningBanner(
                                    ctx,
                                    serverRun,
                                    isSshConnected: isSshConnected,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!_userNearBottom)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            key: const Key('chat_scroll_to_latest_button'),
                            heroTag: 'chat_scroll_to_latest_button',
                            tooltip: context.l10n.chatScrollToLatest,
                            onPressed: () {
                              _scrollToBottom(settle: true);
                              setState(() {
                                _userNearBottom = true;
                                _unreadMessageCount = 0;
                                final session = ref
                                    .read(aiChatProvider)
                                    .activeSession;
                                if (session != null) {
                                  _lastSeenEndIndex =
                                      session.messageOffset +
                                      session.messages.length;
                                  _lastSeenTailMessageId =
                                      session.messages.lastOrNull?.id;
                                }
                              });
                            },
                            child: _unreadMessageCount > 0
                                ? Badge.count(
                                    count: _unreadMessageCount,
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                    ),
                                  )
                                : const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                    ],
                  ),
                ),
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
          if (isDesktop && _showWorkbench) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 320,
              child: _WorkbenchPanel(
                isDesktop: true,
                onClose: () => setState(() => _showWorkbench = false),
                onOpenFile: (ctx, path, {expectedTarget, line}) =>
                    _openRemoteFilePreview(
                      ctx,
                      path,
                      expectedTarget: expectedTarget,
                      line: line,
                    ),
              ),
            ),
          ],
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          ChatHistorySearchDialog.show(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          ChatHistorySearchDialog.show(context);
        },
      },
      child: Focus(autofocus: false, child: scaffold),
    );
  }

  Widget _buildWorkspaceControlBadge(AiChatState state) {
    final workspaceState = ref.watch(remoteWorkspaceProvider);
    final isWorkspaceActive =
        workspaceState.enabled && state.activeSession != null;
    if (!isWorkspaceActive) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isCompact = screenWidth < 500 || textScale > 1.15;

    final hasControl = state.workspaceHasControl;
    final isBusy = state.workspaceControlBusy;
    final ownerId = state.workspaceControlOwnerDeviceId;

    if (hasControl) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Tooltip(
          message: context.l10n.chatWorkspaceControlActiveTooltip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: context.vSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VRadius.pill),
              border: Border.all(
                color: context.vSuccess.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 13,
                  color: context.vSuccess,
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.chatWorkspaceControlActive,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.vSuccess,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Read-only / control held by another device
    final shortOwner = (ownerId != null && ownerId.trim().isNotEmpty)
        ? (ownerId.trim().length > 8
            ? ownerId.trim().substring(0, 8)
            : ownerId.trim())
        : null;

    final readOnlyLabel = shortOwner != null
        ? context.l10n.chatWorkspaceReadOnlyDevice(shortOwner)
        : context.l10n.chatWorkspaceReadOnly;

    final actionLabel = ownerId != null
        ? context.l10n.chatWorkspaceTakeover
        : context.l10n.chatWorkspaceAcquireControl;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: readOnlyLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: context.vWarning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(VRadius.pill),
            border: Border.all(
              color: context.vWarning.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 13,
                color: context.vWarning,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 4),
                Text(
                  readOnlyLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.vWarning,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              if (isBusy)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                InkWell(
                  key: const Key('chat_workspace_control_action_button'),
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  onTap: () => _handleAcquireWorkspaceControl(
                    takeover: ownerId != null,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAcquireWorkspaceControl({required bool takeover}) async {
    final initialServer = ref.read(activeServerProvider)?.connectionKey;
    final initialSessionId = ref.read(aiChatProvider).activeSessionId;

    if (takeover) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.dialog),
          ),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: ctx.vWarning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ctx.l10n.chatWorkspaceTakeoverDialogTitle),
              ),
            ],
          ),
          content: Text(ctx.l10n.chatWorkspaceTakeoverDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.vWarning),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(ctx.l10n.chatWorkspaceTakeoverConfirm),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    // Origin check after dialog await
    final currentServer = ref.read(activeServerProvider)?.connectionKey;
    final currentSessionId = ref.read(aiChatProvider).activeSessionId;
    if (currentServer != initialServer ||
        currentSessionId != initialSessionId) {
      return;
    }

    final ok = await ref
        .read(aiChatProvider.notifier)
        .acquireWorkspaceControl(takeover: takeover);

    if (!mounted) return;

    if (!ok) {
      final error = ref.read(aiChatProvider).lastErrorCode;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_resolveWorkspaceControlError(context, error)),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  String _resolveWorkspaceControlError(BuildContext context, String? code) {
    final l10n = context.l10n;
    if (code == null) return l10n.chatWorkspaceControlFailed;
    switch (code) {
      case 'WORKSPACE_CONTROL_REQUIRED':
      case 'WORKSPACE_CONTROL_HELD':
        return l10n.serverWorkspaceErrorControlHeld;
      case 'WORKSPACE_RUNTIME_UPGRADE_REQUIRED':
        return l10n.serverWorkspaceErrorRuntimeUpgradeRequired;
      case 'WORKSPACE_SETUP_FAILED':
        return l10n.serverWorkspaceErrorSetupFailed;
      case 'WORKSPACE_PYTHON_REQUIRED':
        return l10n.serverWorkspaceErrorPythonRequired;
      case 'WORKSPACE_PATH_UNSAFE':
        return l10n.serverWorkspaceErrorPathUnsafe;
      default:
        return l10n.serverWorkspaceErrorGeneric(code);
    }
  }

  Widget _buildHeaderBar(AiChatState state, bool isDesktop) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isCompact = screenWidth < 500 || textScale > 1.15;
    final btnConstraints = isCompact
        ? const BoxConstraints(minWidth: 32, minHeight: 32)
        : const BoxConstraints(minWidth: 40, minHeight: 40);
    final btnPadding = isCompact
        ? const EdgeInsets.all(4)
        : const EdgeInsets.all(8);
    final headerPadding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 4)
        : const EdgeInsets.symmetric(horizontal: 16);

    return Container(
      height: 48,
      padding: headerPadding,
      color: context.colorScheme.surface,
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) => IconButton(
                key: const Key('ai_mobile_session_drawer_button'),
                icon: const Icon(Icons.view_sidebar_outlined, size: 20),
                tooltip: context.l10n.chatSessionsTooltip,
                padding: btnPadding,
                constraints: btnConstraints,
                visualDensity: VisualDensity.compact,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 2 : 6,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showArrow = constraints.maxWidth >= 60;
                      return Row(
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
                          const SizedBox(width: 4),
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
                          if (showArrow)
                            const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          _buildWorkspaceControlBadge(state),
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
            padding: btnPadding,
            constraints: btnConstraints,
            visualDensity: VisualDensity.compact,
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
            padding: btnPadding,
            constraints: btnConstraints,
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.chatAccountAndQuotaTitle,
            onPressed: () => _showAccountAndQuotaDialog(context),
          ),
          IconButton(
            key: const Key('chat_workbench_toggle_button'),
            icon: Icon(
              _showWorkbench
                  ? Icons.vertical_split
                  : Icons.vertical_split_outlined,
              size: 18,
              color: _showWorkbench ? context.colorScheme.primary : null,
            ),
            padding: btnPadding,
            constraints: btnConstraints,
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.chatWorkbench,
            onPressed: () {
              if (isDesktop) {
                setState(() => _showWorkbench = !_showWorkbench);
              } else {
                _showWorkbenchBottomSheet(context);
              }
            },
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
              fullSessions: s.sessions,
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
                            label: Text(
                              context.l10n.newSession,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          message: context.l10n.chatSearchTitle,
                          child: SizedBox(
                            height: 40,
                            width: 40,
                            child: IconButton.outlined(
                              key: const Key('chat_history_search_button'),
                              icon: const Icon(Icons.search, size: 18),
                              onPressed: () {
                                if (!isDesktop) {
                                  Navigator.pop(context);
                                }
                                ChatHistorySearchDialog.show(context);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: context.l10n.chatRemoteSessions,
                          child: SizedBox(
                            height: 40,
                            width: 40,
                            child: IconButton.outlined(
                              key: const Key('chat_remote_sessions_button'),
                              icon: const Icon(Icons.cloud_outlined, size: 18),
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
                  child: _sessionSearchController.text.isNotEmpty
                      ? ListView.builder(
                          itemCount:
                              projection.sessions.length +
                              (projection.hasMoreSessions ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == projection.sessions.length) {
                              return _buildLoadMoreSessionsTile(
                                projection,
                                notifier,
                              );
                            }
                            final session = projection.sessions[index];
                            return _buildSessionTile(
                              sessionId: session.id,
                              sessionTitle: session.title,
                              projection: projection,
                              preference: preference,
                              notifier: notifier,
                              isDesktop: isDesktop,
                            );
                          },
                        )
                      : Builder(
                          builder: (context) {
                            final allSessions = projection.fullSessions;
                            final workspaces = ChatWorkspace.group(allSessions);
                            final groupedIds = workspaces
                                .expand((w) => w.sessions.map((s) => s.id))
                                .toSet();
                            final ungroupedSessions = allSessions
                                .where((s) => !groupedIds.contains(s.id))
                                .toList();
                            final storage = drawerRef.read(
                              localStorageServiceProvider,
                            );

                            final sortedWorkspaces =
                                List<ChatWorkspace>.from(workspaces)
                                  ..sort((a, b) {
                                    final prefA = storage
                                        .getChatWorkspacePreference(a.key);
                                    final prefB = storage
                                        .getChatWorkspacePreference(b.key);
                                    final favA =
                                        (prefA['favorite'] as bool?) ?? false;
                                    final favB =
                                        (prefB['favorite'] as bool?) ?? false;
                                    if (favA != favB) return favA ? -1 : 1;
                                    final nameA =
                                        (prefA['alias'] as String?)?.trim() ??
                                        a.directory;
                                    final nameB =
                                        (prefB['alias'] as String?)?.trim() ??
                                        b.directory;
                                    return nameA.toLowerCase().compareTo(
                                      nameB.toLowerCase(),
                                    );
                                  });

                            return ListView(
                              children: [
                                for (final workspace in sortedWorkspaces) ...[
                                  Builder(
                                    builder: (ctx) {
                                      final pref = storage
                                          .getChatWorkspacePreference(
                                            workspace.key,
                                          );
                                      final alias = (pref['alias'] as String?)
                                          ?.trim();
                                      final isFavorite =
                                          (pref['favorite'] as bool?) ?? false;
                                      final execLabel =
                                          _formatWorkspaceExecution(
                                            workspace.executionKey,
                                          );
                                      final dirName =
                                          (workspace.directory == '.' ||
                                              workspace.directory.isEmpty)
                                          ? context.l10n.chatWorkspaceProjects
                                          : p.posix.basename(
                                              workspace.directory,
                                            );
                                      final displayName =
                                          (alias != null && alias.isNotEmpty)
                                          ? alias
                                          : '$dirName ($execLabel)';
                                      final containsActive = workspace.sessions
                                          .any(
                                            (s) =>
                                                s.id ==
                                                projection.activeSessionId,
                                          );

                                      return ExpansionTile(
                                        key: PageStorageKey<String>(
                                          'workspace_${workspace.key}',
                                        ),
                                        initiallyExpanded:
                                            containsActive ||
                                            workspaces.length == 1,
                                        leading: Icon(
                                          Icons.folder_outlined,
                                          size: 18,
                                          color: containsActive
                                              ? context.colorScheme.primary
                                              : null,
                                        ),
                                        title: Text(
                                          displayName,
                                          style: context.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: containsActive
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${workspace.directory} • $execLabel',
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    context.colorScheme.outline,
                                                fontSize: 10,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                isFavorite
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                size: 18,
                                                color: isFavorite
                                                    ? Colors.amber
                                                    : context
                                                          .colorScheme
                                                          .outline,
                                              ),
                                              tooltip: isFavorite
                                                  ? context
                                                        .l10n
                                                        .chatWorkspaceUnfavorite
                                                  : context
                                                        .l10n
                                                        .chatWorkspaceFavorite,
                                              onPressed: () async {
                                                await storage
                                                    .setChatWorkspacePreference(
                                                      workspace.key,
                                                      alias: alias,
                                                      favorite: !isFavorite,
                                                    );
                                                setState(() {});
                                              },
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                size: 16,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 24,
                                                minHeight: 24,
                                              ),
                                              onSelected: (val) {
                                                if (val == 'edit_alias') {
                                                  _showEditWorkspaceAliasDialog(
                                                    context,
                                                    workspace.key,
                                                    alias,
                                                  );
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                  value: 'edit_alias',
                                                  child: Text(
                                                    context
                                                        .l10n
                                                        .chatWorkspaceEditAlias,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        children: workspace.sessions.map((
                                          session,
                                        ) {
                                          return _buildSessionTile(
                                            sessionId: session.id,
                                            sessionTitle: session.title,
                                            projection: projection,
                                            preference: preference,
                                            notifier: notifier,
                                            isDesktop: isDesktop,
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                                if (ungroupedSessions.isNotEmpty) ...[
                                  ExpansionTile(
                                    initiallyExpanded: true,
                                    leading: const Icon(
                                      Icons.folder_open,
                                      size: 18,
                                    ),
                                    title: Text(
                                      context.l10n.chatWorkspaceProjects,
                                    ),
                                    children: ungroupedSessions.map((session) {
                                      return _buildSessionTile(
                                        sessionId: session.id,
                                        sessionTitle: session.title,
                                        projection: projection,
                                        preference: preference,
                                        notifier: notifier,
                                        isDesktop: isDesktop,
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (projection.hasMoreSessions)
                                  _buildLoadMoreSessionsTile(
                                    projection,
                                    notifier,
                                  ),
                              ],
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

  String _formatWorkspaceExecution(String executionKey) {
    if (executionKey.startsWith('legacy:')) {
      final legacyAgent = executionKey.substring(7);
      return legacyAgent.isNotEmpty && legacyAgent != 'unknown'
          ? 'Legacy ($legacyAgent)'
          : 'Legacy';
    }
    try {
      final decoded = jsonDecode(executionKey);
      if (decoded is List && decoded.isNotEmpty) {
        final target = decoded[0].toString();
        if (target == 'docker') {
          final ref = decoded.length > 2 ? decoded[2]?.toString() : null;
          final user = decoded.length > 3 ? decoded[3]?.toString() : null;
          final parts = [
            'Docker',
            if (ref != null && ref.isNotEmpty) ref,
            if (user != null && user.isNotEmpty) user,
          ];
          return parts.join(' : ');
        } else if (target == 'host') {
          return 'Host';
        }
        return target;
      }
    } catch (_) {}
    return executionKey;
  }

  Widget _buildLoadMoreSessionsTile(
    _SessionsDrawerProjection projection,
    AiChatNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: projection.isLoadingSessions
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                key: const Key('chat_load_more_sessions_button'),
                icon: const Icon(Icons.expand_more, size: 16),
                label: Text(context.l10n.chatLoadMoreSessions),
                onPressed: () => notifier.loadMoreSessions(),
              ),
      ),
    );
  }

  Widget _buildSessionTile({
    required String sessionId,
    required String sessionTitle,
    required _SessionsDrawerProjection projection,
    required ChatLaunchPreference preference,
    required AiChatNotifier notifier,
    required bool isDesktop,
  }) {
    final isSelected = sessionId == projection.activeSessionId;
    final isFixedDefault =
        preference.mode == ChatLaunchMode.fixed &&
        preference.sessionId == sessionId;

    return ListTile(
      selected: isSelected,
      selectedTileColor: context.colorScheme.primaryContainer.withValues(
        alpha: 0.2,
      ),
      leading: Icon(
        Icons.chat_bubble_outline,
        size: 18,
        color: isSelected ? context.colorScheme.primary : null,
      ),
      title: Text(
        sessionTitle,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                key: Key('default_session_badge_$sessionId'),
                size: 16,
                color: context.colorScheme.primary,
              ),
            ),
          PopupMenuButton<String>(
            key: Key('session_more_menu_$sessionId'),
            icon: const Icon(Icons.more_vert, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onSelected: (val) {
              switch (val) {
                case 'set_default':
                  notifier.setLaunchPreference(
                    ChatLaunchPreference(
                      mode: ChatLaunchMode.fixed,
                      sessionId: sessionId,
                    ),
                  );
                  break;
                case 'rename':
                  _showRenameSessionDialog(context, sessionId, sessionTitle);
                  break;
                case 'export':
                  _exportSession(context, sessionId, sessionTitle);
                  break;
                case 'delete':
                  _confirmAndDeleteSession(context, sessionId, sessionTitle);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (preference.mode == ChatLaunchMode.fixed)
                PopupMenuItem<String>(
                  key: Key('set_default_session_$sessionId'),
                  value: 'set_default',
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(context.l10n.setAsDefaultSession),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                key: Key('rename_session_$sessionId'),
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
                key: Key('export_session_$sessionId'),
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
                key: Key('delete_session_$sessionId'),
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: ctx.vDanger),
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
        notifier.selectSession(sessionId);
        if (!isDesktop) {
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _showEditWorkspaceAliasDialog(
    BuildContext context,
    String workspaceKey,
    String? currentAlias,
  ) async {
    final controller = TextEditingController(text: currentAlias ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.chatWorkspaceEditAlias),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.chatWorkspaceAliasLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final storage = ref.read(localStorageServiceProvider);
      final pref = storage.getChatWorkspacePreference(workspaceKey);
      final isFavorite = (pref['favorite'] as bool?) ?? false;
      await storage.setChatWorkspacePreference(
        workspaceKey,
        alias: controller.text.trim().isEmpty ? null : controller.text.trim(),
        favorite: isFavorite,
      );
      setState(() {});
    }
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
          if (frame.isLoadingMessages) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.cliLoadingOlderMessages,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          final chatErrorState = listRef.watch(
            aiChatProvider.select(
              (s) => (
                lastErrorCode: s.lastErrorCode,
                persistentError: s.persistentRuntimeSetupError,
                hasAuth:
                    s.lastErrorCode == AiChatNotifier.disconnectedCode ||
                    s.lastErrorCode == AiChatNotifier.authRequiredCode ||
                    s.authChallenge != null ||
                    s.authError != null,
              ),
            ),
          );
          final hasError =
              frame.recoveryStatus == SessionRecoveryStatus.failed ||
              chatErrorState.lastErrorCode != null ||
              chatErrorState.persistentError != null;
          if (hasError) {
            final rawError =
                chatErrorState.lastErrorCode ??
                chatErrorState.persistentError ??
                '';
            final isExecChanged = rawError.contains(
              'CHAT_SESSION_EXECUTION_CHANGED',
            );
            final hasBanner =
                chatErrorState.lastErrorCode != null &&
                !chatErrorState.hasAuth &&
                _dismissedErrorCode != chatErrorState.lastErrorCode;

            final String displayText;
            if (isExecChanged) {
              displayText = context.l10n.chatExecutionChangedPrompt;
            } else if (hasBanner) {
              displayText = context.l10n.chatStatusFailed;
            } else {
              final lastCode = chatErrorState.lastErrorCode;
              final persistent = chatErrorState.persistentError;
              if (lastCode != null && lastCode.isNotEmpty) {
                final resolved = _resolveErrorMessage(lastCode);
                if (resolved != lastCode) {
                  displayText = resolved;
                } else if (lastCode.startsWith('CHAT_SESSION_IDENTITY_MISMATCH')) {
                  displayText = context.l10n.chatSessionIdentityMismatch;
                } else {
                  final sanitized = LogSanitizer.sanitize(lastCode);
                  displayText = sanitized.isNotEmpty
                      ? sanitized
                      : context.l10n.chatStatusFailed;
                }
              } else if (persistent != null && persistent.isNotEmpty) {
                final sanitized = LogSanitizer.sanitize(persistent);
                displayText = sanitized.isNotEmpty
                    ? sanitized
                    : context.l10n.chatStatusFailed;
              } else {
                displayText = context.l10n.chatStatusFailed;
              }
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExecChanged ? Icons.info_outline : Icons.error_outline,
                      size: 48,
                      color: isExecChanged
                          ? context.colorScheme.primary
                          : context.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayText,
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: isExecChanged
                            ? context.colorScheme.onSurface
                            : context.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isExecChanged)
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(context.l10n.newSession),
                        onPressed: () {
                          listRef
                              .read(aiChatProvider.notifier)
                              .createNewSession();
                        },
                      )
                    else
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(context.l10n.stateRetry),
                        onPressed: () {
                          listRef.read(aiChatProvider.notifier).retryHistory();
                        },
                      ),
                  ],
                ),
              ),
            );
          }

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

        final listView = ListView.builder(
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

        if (!_hasClampedToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasClampedToBottom) {
              setState(() {
                _hasClampedToBottom = true;
              });
            }
          });
        }

        return listView;
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
            MarkdownBody(
              data: msg.content,
              selectable: true,
              onTapLink: (linkText, href, title) {
                if (href != null && href.isNotEmpty) {
                  _handleChatLink(context, href);
                }
              },
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: TextStyle(
                      color: context.colorScheme.onPrimaryContainer,
                      fontSize: 14,
                    ),
                    code: monoTextStyle(fontSize: 12),
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
                  Builder(
                    builder: (context) {
                      final toolKey =
                          '${sessionId ?? ''}:${msg.id}:${block.toolId}';
                      return _ToolExecutionCard(
                        key: ValueKey('tool_${block.toolId}'),
                        tool: toolsById[block.toolId]!,
                        messageId: msg.id,
                        isExpanded: _expandedToolIds.contains(toolKey),
                        onToggleExpand: () => setState(() {
                          if (!_expandedToolIds.add(toolKey)) {
                            _expandedToolIds.remove(toolKey);
                          }
                        }),
                      );
                    },
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

    final isLiveStreaming = msg.status == ChatTurnStatus.streaming;
    final sessionId =
        ref.watch(aiChatProvider.select((s) => s.activeSessionId)) ?? '';

    return _CachedMarkdownTextBlock(
      key: ValueKey('msg_${msg.id}_block_${block.start}'),
      text: text,
      sessionId: sessionId,
      messageId: msg.id,
      blockStart: block.start,
      isLiveStreaming: isLiveStreaming,
      codeBlockExpandedState: _codeBlockExpandedState,
      onCodeBlockExpansionChanged: (codeKey, expanded) {
        _codeBlockExpandedState[codeKey] = expanded;
      },
      onTapLink: (href) => _handleChatLink(context, href),
    );
  }

  Future<void> _handleChatLink(BuildContext context, String rawUrl) async {
    final chatState = ref.read(aiChatProvider);
    final workingDir =
        chatState.activeSession?.workingDirectory ??
        chatState.draftWorkingDirectory ??
        '/';
    final target = ChatLinkTarget.parse(rawUrl, workingDirectory: workingDir);

    switch (target.kind) {
      case ChatLinkKind.web:
        final uri = target.uri;
        if (uri == null) return;
        if (target.isRemoteLoopback) {
          final capturedTarget = ref
              .read(aiChatProvider.notifier)
              .workspaceSelectionKey;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(context.l10n.chatLoopbackConfirmTitle),
              content: Text(
                '${context.l10n.chatLoopbackConfirmMessage}\n\n$rawUrl',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.confirm),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          try {
            final localUri = await ref
                .read(aiChatProvider.notifier)
                .openWorkspaceWebPreview(uri, expectedTarget: capturedTarget);
            final launched = await launchUrl(
              localUri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              await Clipboard.setData(ClipboardData(text: rawUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${context.l10n.chatFailedToOpenLink}: $rawUrl',
                  ),
                ),
              );
            }
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('ACP_TARGET_CHANGED')) return;
            final isExecChanged = msg.contains(
              'CHAT_SESSION_EXECUTION_CHANGED',
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isExecChanged
                      ? context.l10n.chatExecutionChangedPrompt
                      : '$e',
                ),
                backgroundColor: context.colorScheme.error,
              ),
            );
          }
        } else {
          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              await Clipboard.setData(ClipboardData(text: rawUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${context.l10n.chatFailedToOpenLink}: $rawUrl',
                  ),
                ),
              );
            }
          } catch (_) {
            await Clipboard.setData(ClipboardData(text: rawUrl));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.l10n.chatFailedToOpenLink}: $rawUrl'),
              ),
            );
          }
        }
        break;

      case ChatLinkKind.mail:
        final uri = target.uri;
        if (uri == null) return;
        try {
          final launched = await launchUrl(uri);
          if (!launched) {
            await Clipboard.setData(ClipboardData(text: rawUrl));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.l10n.chatFailedToOpenLink}: $rawUrl'),
              ),
            );
          }
        } catch (_) {
          await Clipboard.setData(ClipboardData(text: rawUrl));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.l10n.chatFailedToOpenLink}: $rawUrl'),
            ),
          );
        }
        break;

      case ChatLinkKind.remoteFile:
        final filePath = target.path;
        if (filePath == null) return;
        final capturedTarget = ref
            .read(aiChatProvider.notifier)
            .workspaceSelectionKey;
        if (target.outsideWorkspace) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(context.l10n.confirm),
              content: Text(
                '${context.l10n.chatFileOutsideWorkspace}\n\n$filePath',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.confirm),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
        }
        final mime = AcpWorkspaceFiles.mimeType(filePath);
        if (mime?.startsWith('image/') ?? false) {
          try {
            final bytes = await ref
                .read(aiChatProvider.notifier)
                .readWorkspaceImage(filePath, expectedTarget: capturedTarget);
            if (!context.mounted) return;
            ImageZoomDialog.show(
              context,
              title: p.basename(filePath),
              bytes: bytes,
            );
          } catch (e) {
            final msg = e.toString();
            if (msg.contains('ACP_TARGET_CHANGED')) return;
            final isExecChanged = msg.contains(
              'CHAT_SESSION_EXECUTION_CHANGED',
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isExecChanged ? context.l10n.chatExecutionChangedPrompt : msg,
                ),
                backgroundColor: context.colorScheme.error,
              ),
            );
          }
          return;
        }
        if (!context.mounted) return;
        _openRemoteFilePreview(
          context,
          filePath,
          expectedTarget: capturedTarget,
          line: target.line,
        );
        break;

      case ChatLinkKind.anchor:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anchor: ${target.path ?? rawUrl}'),
            duration: const Duration(seconds: 1),
          ),
        );
        break;

      case ChatLinkKind.unsupported:
        await Clipboard.setData(ClipboardData(text: rawUrl));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatLinkCopied),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        break;
    }
  }

  Future<void> _openRemoteFilePreview(
    BuildContext context,
    String path, {
    String? expectedTarget,
    int? line,
    bool outsideWorkspace = false,
  }) async {
    final capturedTarget =
        expectedTarget ??
        ref.read(aiChatProvider.notifier).workspaceSelectionKey;
    if (outsideWorkspace) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.confirm),
          content: Text('${context.l10n.chatFileOutsideWorkspace}\n\n$path'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingCtx = dialogContext;
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(context.l10n.chatLoadingFile),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final snapshot = await ref
          .read(aiChatProvider.notifier)
          .readWorkspaceText(path, expectedTarget: capturedTarget);
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.of(loadingCtx!).pop();
      }
      if (!context.mounted) return;
      _showAcpFileEditor(
        context,
        snapshot,
        line: line,
        workspaceTarget: capturedTarget,
      );
    } catch (e) {
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.of(loadingCtx!).pop();
      }
      if (!context.mounted) return;
      final msg = e.toString();
      if (msg.contains('ACP_TARGET_CHANGED')) return;

      final isExecChanged = msg.contains('CHAT_SESSION_EXECUTION_CHANGED');
      final isBinaryOrTooLarge = msg.contains('ACP_FILE_NOT_EDITABLE');
      final isNoEditor = msg.contains('ACP_FILE_EDITOR_UNAVAILABLE');
      final desc = isExecChanged
          ? context.l10n.chatExecutionChangedPrompt
          : (isBinaryOrTooLarge
                ? context.l10n.chatFileNotEditable
                : (isNoEditor ? context.l10n.chatEditorUnavailable : msg));
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.chatStatusFailed),
          content: Text(desc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
    }
  }

  void _showAcpFileEditor(
    BuildContext context,
    AcpTextSnapshot snapshot, {
    int? line,
    bool isReadOnly = false,
    String? workspaceTarget,
  }) {
    final target =
        workspaceTarget ??
        ref.read(aiChatProvider.notifier).workspaceSelectionKey;
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => _AcpFileEditorDialog(
        snapshot: snapshot,
        initialLine: line,
        isReadOnly: isReadOnly || !snapshot.canSave,
        workspaceTarget: target,
      ),
    );
  }

  void _showWorkbenchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, sheetScrollController) {
            return _WorkbenchPanel(
              isDesktop: false,
              scrollController: sheetScrollController,
              onClose: () => Navigator.pop(sheetCtx),
              onOpenFile: (fileCtx, path, {expectedTarget, line}) =>
                  _openRemoteFilePreview(
                    fileCtx,
                    path,
                    expectedTarget: expectedTarget,
                    line: line,
                  ),
            );
          },
        );
      },
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
    final expectedCompleter = cardRef.watch(
      aiChatProvider.select((s) => s.permissionCompleter),
    );
    final activeServer = cardRef.watch(activeServerProvider);
    final expectedServerKey = activeServer?.connectionKey.toString() ?? '';
    final isReadOnlyWorkspace =
        cardRef.watch(remoteWorkspaceProvider.select((w) => w.enabled)) &&
        cardRef.watch(
          aiChatProvider.select(
            (s) => s.activeSession != null && !s.workspaceHasControl,
          ),
        );

    final canRespond =
        isConnected &&
        expectedCompleter != null &&
        !expectedCompleter.isCompleted &&
        recoveryStatus != SessionRecoveryStatus.reconnecting &&
        recoveryStatus != SessionRecoveryStatus.syncing &&
        !isReadOnlyWorkspace;

    final summaryText = req.description.trim().isNotEmpty
        ? req.description.trim()
        : (req.command.trim().isNotEmpty
              ? req.command.trim()
              : (req.toolName.trim().isNotEmpty
                    ? req.toolName.trim()
                    : context.l10n.permissionRequired));

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
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.permissionRequired,
                  style: context.textTheme.titleSmall?.copyWith(color: danger),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summaryText,
            style: context.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                TextButton.icon(
                  key: const Key('chat_permission_details_button'),
                  icon: const Icon(Icons.open_in_full, size: 14),
                  label: Text(context.l10n.permissionViewDetails),
                  onPressed: () => _showPermissionDetailsModal(
                    context,
                    req,
                    cardRef,
                    canRespond,
                    expectedCompleter: expectedCompleter,
                    expectedServerKey: expectedServerKey,
                  ),
                ),
                TextButton(
                  key: const Key('chat_permission_cancel'),
                  onPressed: canRespond
                      ? () => notifier.respondToPermission(
                          null,
                          expectedCompleter: expectedCompleter,
                          expectedServerKey: expectedServerKey,
                        )
                      : null,
                  child: Text(context.l10n.cancel),
                ),
                if (req.options.isNotEmpty) ...[
                  Builder(
                    builder: (ctx) {
                      final primaryOption = req.options.firstWhere(
                        (o) => o.kind.toLowerCase().contains('allow'),
                        orElse: () => req.options.first,
                      );
                      final isAllow = primaryOption.kind.toLowerCase().contains(
                        'allow',
                      );
                      return isAllow
                          ? FilledButton(
                              key: Key(
                                'chat_permission_option_${primaryOption.id}',
                              ),
                              style: req.isDangerous
                                  ? FilledButton.styleFrom(
                                      backgroundColor:
                                          context.colorScheme.error,
                                    )
                                  : null,
                              onPressed: canRespond
                                  ? () => notifier.respondToPermission(
                                      primaryOption.id,
                                      expectedCompleter: expectedCompleter,
                                      expectedServerKey: expectedServerKey,
                                    )
                                  : null,
                              child: Text(
                                primaryOption.name.isNotEmpty
                                    ? primaryOption.name
                                    : primaryOption.id,
                              ),
                            )
                          : OutlinedButton(
                              key: Key(
                                'chat_permission_option_${primaryOption.id}',
                              ),
                              onPressed: canRespond
                                  ? () => notifier.respondToPermission(
                                      primaryOption.id,
                                      expectedCompleter: expectedCompleter,
                                      expectedServerKey: expectedServerKey,
                                    )
                                  : null,
                              child: Text(
                                primaryOption.name.isNotEmpty
                                    ? primaryOption.name
                                    : primaryOption.id,
                              ),
                            );
                    },
                  ),
                ] else ...[
                  OutlinedButton(
                    key: const Key('chat_permission_reject'),
                    onPressed: canRespond
                        ? () => notifier.respondToPermission(
                            null,
                            expectedCompleter: expectedCompleter,
                            expectedServerKey: expectedServerKey,
                          )
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

  void _showPermissionDetailsModal(
    BuildContext context,
    PermissionRequest req,
    WidgetRef cardRef,
    bool canRespond, {
    required Completer<String?>? expectedCompleter,
    required String expectedServerKey,
  }) {
    final notifier = cardRef.read(aiChatProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final isActionEnabled = canRespond && expectedCompleter != null;

    Widget buildModalContent(BuildContext modalCtx) {
      final mq = MediaQuery.of(modalCtx);
      final availableHeight =
          mq.size.height - mq.padding.vertical - mq.viewInsets.vertical;
      final maxModalHeight = availableHeight > 0
          ? (availableHeight * 0.8).clamp(0.0, availableHeight)
          : 0.0;

      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxModalHeight, maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: req.isDangerous
                          ? modalCtx.colorScheme.error
                          : modalCtx.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        modalCtx.l10n.permissionDetailsTitle,
                        style: modalCtx.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (req.toolName.isNotEmpty) ...[
                        Text(
                          modalCtx.l10n.permissionToolLabel,
                          style: modalCtx.textTheme.labelMedium?.copyWith(
                            color: modalCtx.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req.toolName,
                          style: modalCtx.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              modalCtx.l10n.permissionCommandLabel,
                              style: modalCtx.textTheme.labelMedium?.copyWith(
                                color: modalCtx.colorScheme.outline,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.copy, size: 14),
                              label: Text(modalCtx.l10n.permissionCopyCommand),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: req.command),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      modalCtx.l10n.permissionCommandCopied,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: SelectableText(
                          req.command,
                          style: monoTextStyle(
                            fontSize: 12,
                            color: modalCtx.vWarning,
                          ),
                        ),
                      ),
                      if (req.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          modalCtx.l10n.permissionDescription,
                          style: modalCtx.textTheme.labelMedium?.copyWith(
                            color: modalCtx.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req.description,
                          style: modalCtx.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: isActionEnabled
                          ? () {
                              Navigator.pop(modalCtx);
                              notifier.respondToPermission(
                                null,
                                expectedCompleter: expectedCompleter,
                                expectedServerKey: expectedServerKey,
                              );
                            }
                          : null,
                      child: Text(modalCtx.l10n.cancel),
                    ),
                    if (req.options.isNotEmpty)
                      ...req.options.map((option) {
                        final isAllow = option.kind.toLowerCase().contains(
                          'allow',
                        );
                        return isAllow
                            ? FilledButton(
                                key: Key(
                                  'chat_permission_option_detail_${option.id}',
                                ),
                                style: req.isDangerous
                                    ? FilledButton.styleFrom(
                                        backgroundColor:
                                            modalCtx.colorScheme.error,
                                      )
                                    : null,
                                onPressed: isActionEnabled
                                    ? () {
                                        Navigator.pop(modalCtx);
                                        notifier.respondToPermission(
                                          option.id,
                                          expectedCompleter: expectedCompleter,
                                          expectedServerKey: expectedServerKey,
                                        );
                                      }
                                    : null,
                                child: Text(
                                  option.name.isNotEmpty
                                      ? option.name
                                      : option.id,
                                ),
                              )
                            : OutlinedButton(
                                key: Key(
                                  'chat_permission_option_detail_${option.id}',
                                ),
                                onPressed: isActionEnabled
                                    ? () {
                                        Navigator.pop(modalCtx);
                                        notifier.respondToPermission(
                                          option.id,
                                          expectedCompleter: expectedCompleter,
                                          expectedServerKey: expectedServerKey,
                                        );
                                      }
                                    : null,
                                child: Text(
                                  option.name.isNotEmpty
                                      ? option.name
                                      : option.id,
                                ),
                              );
                      })
                    else
                      OutlinedButton(
                        onPressed: isActionEnabled
                            ? () {
                                Navigator.pop(modalCtx);
                                notifier.respondToPermission(
                                  null,
                                  expectedCompleter: expectedCompleter,
                                  expectedServerKey: expectedServerKey,
                                );
                              }
                            : null,
                        child: Text(modalCtx.l10n.permissionReject),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      showDialog<void>(
        context: context,
        builder: (ctx) =>
            Dialog(clipBehavior: Clip.antiAlias, child: buildModalContent(ctx)),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SafeArea(child: buildModalContent(ctx)),
      );
    }
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
          final runtime = ref
              .read(agentRegistryProvider)
              .findRuntime(currentProfile.id);
          final errorMsg = runtime?.errorMessage == 'AGENT_UPDATE_IN_PROGRESS'
              ? context.l10n.agentUpdateInProgress
              : (runtime?.errorMessage ?? context.l10n.agentAuthRetryHint);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
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
    final currentWorkspaceKey = ref
        .read(aiChatProvider.notifier)
        .workspaceSelectionKey;
    final currentServerId = ref.read(activeServerProvider)?.id;
    final currentAgentId = state.activeAgentProfile?.id;
    const effectiveRefresh = true;

    final ok = await ref
        .read(aiChatProvider.notifier)
        .prepareRunSettings(refresh: effectiveRefresh);
    if (!mounted) return;

    final freshWorkspaceKey = ref
        .read(aiChatProvider.notifier)
        .workspaceSelectionKey;
    final freshServerId = ref.read(activeServerProvider)?.id;
    final freshAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
    if (freshWorkspaceKey != currentWorkspaceKey ||
        freshServerId != currentServerId ||
        freshAgentId != currentAgentId) {
      return;
    }

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
    final dialogWorkspaceKey = currentWorkspaceKey;
    final dialogServerId = currentServerId;
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
        final curWorkspaceKey = ref
            .read(aiChatProvider.notifier)
            .workspaceSelectionKey;
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curWorkspaceKey != dialogWorkspaceKey ||
            curServerId != dialogServerId ||
            curAgentId != dialogAgentId) {
          return null;
        }
        final refreshOk = await ref
            .read(aiChatProvider.notifier)
            .prepareRunSettings(refresh: true);
        if (!refreshOk || !mounted) return null;
        if (ref.read(aiChatProvider.notifier).workspaceSelectionKey !=
                dialogWorkspaceKey ||
            ref.read(activeServerProvider)?.id != dialogServerId ||
            ref.read(aiChatProvider).activeAgentProfile?.id != dialogAgentId) {
          return null;
        }
        return ref.read(aiChatProvider).capabilities;
      },
      onFetchMetadata: () {
        if (!mounted) {
          return const ChatRunSettingsMetadata(settingsStale: true);
        }
        final curWorkspaceKey = ref
            .read(aiChatProvider.notifier)
            .workspaceSelectionKey;
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curWorkspaceKey != dialogWorkspaceKey ||
            curServerId != dialogServerId ||
            curAgentId != dialogAgentId) {
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
        final curWorkspaceKey = ref
            .read(aiChatProvider.notifier)
            .workspaceSelectionKey;
        final curServerId = ref.read(activeServerProvider)?.id;
        final curAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
        if (curWorkspaceKey != dialogWorkspaceKey ||
            curServerId != dialogServerId ||
            curAgentId != dialogAgentId) {
          return;
        }
        await ref.read(aiChatProvider.notifier).updateRunSettings(settings);
      },
    );
  }

  Future<void> _openCommandsAndSkills(BuildContext context) async {
    final notifier = ref.read(aiChatProvider.notifier);
    final dialogServerId = ref.read(activeServerProvider)?.id;
    final dialogAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
    final dialogScopeKey = notifier.commandPreferenceKey;
    final dialogWorkspaceKey = notifier.workspaceSelectionKey;

    if (_isLoadingComposerCommands) return;
    setState(() => _isLoadingComposerCommands = true);
    try {
      await notifier.prepareComposerCatalog();
    } catch (_) {
      // Catalog error handled in state/empty view
    } finally {
      if (mounted) setState(() => _isLoadingComposerCommands = false);
    }
    if (!mounted || !context.mounted) return;

    // mounted/server/agent checks
    final currentServerId = ref.read(activeServerProvider)?.id;
    final currentState = ref.read(aiChatProvider);
    final currentScopeKey = notifier.commandPreferenceKey;
    final currentWorkspaceKey = notifier.workspaceSelectionKey;
    if (dialogServerId != currentServerId ||
        dialogAgentId != currentState.activeAgentProfile?.id ||
        dialogScopeKey != currentScopeKey ||
        dialogWorkspaceKey != currentWorkspaceKey) {
      return;
    }

    var closeScheduled = false;
    final cmd = await showDialog<AcpSlashCommand?>(
      context: context,
      builder: (ctx) {
        final originalRoute = ModalRoute.of(ctx);
        return Consumer(
          builder: (ctx, ref, _) {
            final server = ref.watch(activeServerProvider);
            final chatState = ref.watch(aiChatProvider);
            final currentNotifier = ref.read(aiChatProvider.notifier);
            final activeScopeKey = currentNotifier.commandPreferenceKey;
            final activeWorkspaceKey = currentNotifier.workspaceSelectionKey;

            if (server?.id != dialogServerId ||
                chatState.activeAgentProfile?.id != dialogAgentId ||
                activeScopeKey != dialogScopeKey ||
                activeWorkspaceKey != dialogWorkspaceKey) {
              if (!closeScheduled) {
                closeScheduled = true;
                final nav = Navigator.of(ctx);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (ctx.mounted && originalRoute?.isActive == true) {
                    if (originalRoute!.isCurrent) {
                      nav.pop();
                    } else {
                      nav.removeRoute(originalRoute);
                    }
                  }
                });
              }
              return const SizedBox.shrink();
            }

            final isDraft = chatState.activeSession == null;
            final rawWorkingDir = chatState.draftWorkingDirectory;
            final prefs = currentNotifier.commandPreferences;

            return ChatCommandsSkillsDialog(
              commands: chatState.commands,
              favorites: prefs.favorites,
              recent: prefs.recent,
              onToggleFavorite: (id, favorite) async {
                if (dialogScopeKey == null) return;
                await currentNotifier.setCommandFavorite(
                  id,
                  favorite,
                  expectedScopeKey: dialogScopeKey,
                );
              },
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
                      if (ref.read(activeServerProvider)?.id ==
                              dialogServerId &&
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
        );
      },
    );
    if (cmd != null && mounted) {
      final afterServerId = ref.read(activeServerProvider)?.id;
      final afterAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
      final afterScopeKey = notifier.commandPreferenceKey;
      final afterWorkspaceKey = notifier.workspaceSelectionKey;
      if (afterServerId != dialogServerId ||
          afterAgentId != dialogAgentId ||
          afterScopeKey != dialogScopeKey ||
          afterWorkspaceKey != dialogWorkspaceKey) {
        return;
      }

      final id = cmd.isSkill ? 'skill:${cmd.name}' : 'command:${cmd.name}';
      if (dialogScopeKey != null) {
        try {
          await notifier.recordCommandUse(id, expectedScopeKey: dialogScopeKey);
        } on StateError {
          return;
        } catch (_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.chatCommandPreferencesSaveFailed),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      final postAwaitServerId = ref.read(activeServerProvider)?.id;
      final postAwaitAgentId = ref.read(aiChatProvider).activeAgentProfile?.id;
      final postAwaitScopeKey = notifier.commandPreferenceKey;
      final postAwaitWorkspaceKey = notifier.workspaceSelectionKey;
      if (postAwaitServerId != dialogServerId ||
          postAwaitAgentId != dialogAgentId ||
          postAwaitScopeKey != dialogScopeKey ||
          postAwaitWorkspaceKey != dialogWorkspaceKey) {
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

  void _removeSkillToken(String token) {
    final current = _promptController.text;
    final pattern = RegExp(r'(?<!\S)' + RegExp.escape(token) + r'(?!\S)');
    final match = pattern.firstMatch(current);
    if (match == null) return;

    var delStart = match.start;
    var delEnd = match.end;

    if (delEnd < current.length &&
        (current[delEnd] == ' ' || current[delEnd] == '\t')) {
      delEnd++;
    }

    final delLength = delEnd - delStart;
    final newText = current.replaceRange(delStart, delEnd, '');

    int adjustOffset(int offset) {
      if (offset < 0) return offset;
      if (offset <= delStart) return offset;
      if (offset <= delEnd) return delStart;
      return offset - delLength;
    }

    final selection = _promptController.selection;
    final newSelection = selection.isValid
        ? TextSelection(
            baseOffset: adjustOffset(
              selection.baseOffset,
            ).clamp(0, newText.length),
            extentOffset: adjustOffset(
              selection.extentOffset,
            ).clamp(0, newText.length),
            affinity: selection.affinity,
            isDirectional: selection.isDirectional,
          )
        : TextSelection.collapsed(offset: newText.length);

    TextRange newComposing = TextRange.empty;
    final composing = _promptController.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      if (composing.end <= delStart) {
        newComposing = composing;
      } else if (composing.start >= delEnd) {
        newComposing = TextRange(
          start: composing.start - delLength,
          end: composing.end - delLength,
        );
      }
    }

    _promptController.value = TextEditingValue(
      text: newText,
      selection: newSelection,
      composing: newComposing,
    );
    ref.read(aiChatProvider.notifier).updateDraftText(newText);
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
    return context.l10n.chatStatusAwaitingAuth;
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

    final isServerBusyWithOtherSession =
        state.isServerBusy && !state.isViewingRun;

    final isReadOnlyWorkspace =
        inputRef.watch(remoteWorkspaceProvider.select((w) => w.enabled)) &&
        state.activeSession != null &&
        !state.workspaceHasControl;

    final canSend =
        hasActiveAgent &&
        !isBusy &&
        isConnected &&
        !isRecovering &&
        !isServerBusyWithOtherSession &&
        !isReadOnlyWorkspace;

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
                  state.isApplyingSettings ||
                  isReadOnlyWorkspace,
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
                      if (isDraft && state.draftWorkingDirectory != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('chat_clear_draft_working_dir_button'),
                          tooltip: context.l10n.chatResetDraftWorkingDir,
                          icon: const Icon(Icons.close, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: (isBusy || !isConnected || isRecovering)
                              ? null
                              : () => ref
                                    .read(aiChatProvider.notifier)
                                    .clearDraftWorkingDirectory(),
                        ),
                      ],
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
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _promptController,
              builder: (ctx, value, _) {
                final tokens = value.text
                    .split(RegExp(r'\s+'))
                    .where((t) => t.isNotEmpty)
                    .toSet();
                final referencedSkills = state.commands
                    .where((c) => c.isSkill && tokens.contains(c.name))
                    .toList();
                if (referencedSkills.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final skill in referencedSkills)
                          Container(
                            key: Key('chat_skill_chip_${skill.name}'),
                            padding: const EdgeInsets.only(
                              left: 8,
                              top: 2,
                              bottom: 2,
                              right: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(VRadius.pill),
                              border: Border.all(
                                color: context.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 12,
                                  color: context.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: skill.description.isNotEmpty
                                      ? '${skill.name}: ${skill.description}'
                                      : skill.name,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 160,
                                    ),
                                    child: Text(
                                      skill.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: context
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  key: Key('chat_remove_skill_${skill.name}'),
                                  onTap: isBusy
                                      ? null
                                      : () => _removeSkillToken(skill.name),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: context
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
                      onPressed: isReadOnlyWorkspace
                          ? null
                          : () {
                              final serverKey = ref
                                  .read(activeServerProvider)
                                  ?.connectionKey
                                  .toString();
                              final sessionId = ref
                                  .read(aiChatProvider)
                                  .activeSessionId;
                              if (serverKey != null && sessionId != null) {
                                ref
                                    .read(aiChatProvider.notifier)
                                    .stopViewingRun(
                                      expectedServerKey: serverKey,
                                      expectedSessionId: sessionId,
                                    );
                              } else {
                                ref
                                    .read(aiChatProvider.notifier)
                                    .stopGeneration();
                              }
                            },
                    ),
                  )
                else
                  PressableScale(
                    child: IconButton.filled(
                      key: const Key('sendMessageButton'),
                      icon: const Icon(Icons.send, size: 18),
                      tooltip: isReadOnlyWorkspace
                          ? context.l10n.chatWorkspaceReadOnly
                          : (isServerBusyWithOtherSession
                              ? context.l10n.acpServerBusySendDisabled
                              : null),
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
  final List<ChatSession> fullSessions;

  const _SessionsDrawerProjection({
    required this.activeSessionId,
    required this.activeAgentId,
    required this.activeAgentName,
    required this.shareAgentSessions,
    required this.isGenerating,
    required this.hasMoreSessions,
    required this.isLoadingSessions,
    required this.sessions,
    this.fullSessions = const [],
  });

  static bool _fullSessionsEqual(List<ChatSession> a, List<ChatSession> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final sA = a[i];
      final sB = b[i];
      if (sA.id != sB.id ||
          sA.title != sB.title ||
          sA.serverId != sB.serverId ||
          sA.executionKey != sB.executionKey ||
          sA.workingDirectory != sB.workingDirectory) {
        return false;
      }
    }
    return true;
  }

  static int _fullSessionsHash(List<ChatSession> list) {
    var hash = 1;
    for (final s in list) {
      hash = Object.hash(
        hash,
        s.id,
        s.title,
        s.serverId,
        s.executionKey,
        s.workingDirectory,
      );
    }
    return hash;
  }

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
        listEquals(sessions, other.sessions) &&
        _fullSessionsEqual(fullSessions, other.fullSessions);
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
    _fullSessionsHash(fullSessions),
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
  final VoidCallback? onDismiss;

  const _ChatErrorBanner({
    required this.errorCode,
    this.onReloadHistory,
    this.onDismiss,
  });

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
    } else if (widget.errorCode.contains('CHAT_SESSION_EXECUTION_CHANGED')) {
      kindTitle = l10n.chatExecutionChangedPrompt;
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
    if (widget.errorCode.contains('CHAT_SESSION_EXECUTION_CHANGED')) {
      actionButton = Consumer(
        builder: (ctx, ref, _) => TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(44, 44),
          ),
          onPressed: () {
            ref.read(aiChatProvider.notifier).createNewSession();
          },
          child: Text(
            l10n.newSession,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (widget.errorCode == AiChatNotifier.notReadyCode ||
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

    final dismissButton = widget.onDismiss != null
        ? IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: context.colorScheme.onErrorContainer,
            ),
            tooltip: context.l10n.chatCloseBanner,
            visualDensity: VisualDensity.standard,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: widget.onDismiss,
          )
        : null;

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
                children: [?actionButton, detailsButton, ?dismissButton],
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
                ?dismissButton,
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

class _FenceMatch {
  final String char;
  final int length;
  final int indent;
  const _FenceMatch(this.char, this.length, this.indent);
}

_FenceMatch? _matchOpeningFence(String line) {
  final stripped = line.trimLeft();
  final indent = line.length - stripped.length;
  if (indent >= 4 || stripped.length < 3) return null;
  final c = stripped[0];
  if (c != '`' && c != '~') return null;
  int count = 0;
  while (count < stripped.length && stripped[count] == c) {
    count++;
  }
  if (count < 3) return null;
  if (c == '`' && stripped.substring(count).contains('`')) {
    return null;
  }
  return _FenceMatch(c, count, indent);
}

bool _isClosingFence(String line, _FenceMatch open) {
  final stripped = line.trimLeft();
  final indent = line.length - stripped.length;
  if (indent >= 4 || stripped.length < open.length) return false;
  if (stripped[0] != open.char) return false;
  int count = 0;
  while (count < stripped.length && stripped[count] == open.char) {
    count++;
  }
  if (count < open.length) return false;
  final rest = stripped.substring(count).trim();
  return rest.isEmpty;
}

bool _hasComplexMarkdown(String text) {
  if (text.isEmpty) return false;

  // Reference link definitions: [id]: url
  if (RegExp(
    r'^\s{0,3}\[[^\]\n]+\]:[ \t]*\S+',
    multiLine: true,
  ).hasMatch(text)) {
    return true;
  }
  // Reference link usage: [text][id] or [text][]
  if (RegExp(r'\[[^\]\n]+\][ \t\n]*\[[^\]\n]*\]').hasMatch(text)) {
    return true;
  }
  // Blockquotes: > quote
  if (RegExp(r'^\s{0,3}>', multiLine: true).hasMatch(text)) {
    return true;
  }
  // Lists: loose lists, nested lists, ordered or unordered lists
  if (RegExp(
    r'^\s{0,3}(?:[*+-]|\d+[.)])(?:\s+|$)',
    multiLine: true,
  ).hasMatch(text)) {
    return true;
  }
  // HTML blocks or comments: e.g. <div>, <!--
  if (RegExp(r'^\s{0,3}<[a-zA-Z!/]', multiLine: true).hasMatch(text)) {
    return true;
  }
  // Tables: lines starting with pipe or table delimiter rows
  if (RegExp(r'^\s{0,3}\|', multiLine: true).hasMatch(text) ||
      RegExp(r'^\s{0,3}\|?\s*[-:]+[-| :]*\|', multiLine: true).hasMatch(text)) {
    return true;
  }
  // Thematic breaks (horizontal rules)
  if (RegExp(
    r'^\s{0,3}(?:(?:-[ \t]*){3,}|(?:_[ \t]*){3,}|(?:\*[ \t]*){3,})$',
    multiLine: true,
  ).hasMatch(text)) {
    return true;
  }

  // Indented code blocks: 4+ spaces outside fences on non-empty line
  final lines = text.split('\n');
  _FenceMatch? openFence;
  for (final line in lines) {
    final stripped = line.trimLeft();
    final indent = line.length - stripped.length;
    if (openFence == null) {
      final f = _matchOpeningFence(line);
      if (f != null) {
        openFence = f;
      } else if (indent >= 4 && stripped.isNotEmpty) {
        return true;
      }
    } else {
      if (_isClosingFence(line, openFence)) {
        openFence = null;
      }
    }
  }

  return false;
}

List<String> _splitMarkdownSubBlocks(String text) {
  if (text.isEmpty) return const [];
  // For complex forms conservatively keep original whole Markdown rendering
  if (_hasComplexMarkdown(text)) {
    return [text];
  }

  final lines = text.split('\n');
  final subBlocks = <String>[];
  final currentLines = <String>[];
  _FenceMatch? openFence;

  void flushParagraph() {
    if (currentLines.any((l) => l.trim().isNotEmpty)) {
      final block = currentLines.join('\n').trim();
      if (block.isNotEmpty) {
        subBlocks.add(block);
      }
    }
    currentLines.clear();
  }

  for (final line in lines) {
    final stripped = line.trimLeft();
    if (openFence == null) {
      final f = _matchOpeningFence(line);
      if (f != null) {
        flushParagraph();
        openFence = f;
        currentLines.add(line);
      } else if (stripped.isEmpty) {
        flushParagraph();
      } else {
        currentLines.add(line);
      }
    } else {
      currentLines.add(line);
      if (_isClosingFence(line, openFence)) {
        final block = currentLines.join('\n').trim();
        if (block.isNotEmpty) {
          subBlocks.add(block);
        }
        currentLines.clear();
        openFence = null;
      }
    }
  }

  if (currentLines.any((l) => l.trim().isNotEmpty)) {
    final block = currentLines.join('\n').trim();
    if (block.isNotEmpty) {
      subBlocks.add(block);
    }
  }

  return subBlocks.isEmpty && text.trim().isNotEmpty ? [text] : subBlocks;
}

class _CachedMarkdownTextBlock extends StatelessWidget {
  final String text;
  final String sessionId;
  final String messageId;
  final int blockStart;
  final bool isLiveStreaming;
  final Map<String, bool> codeBlockExpandedState;
  final void Function(String codeKey, bool expanded)
  onCodeBlockExpansionChanged;
  final void Function(String href) onTapLink;

  const _CachedMarkdownTextBlock({
    super.key,
    required this.text,
    required this.sessionId,
    required this.messageId,
    required this.blockStart,
    required this.isLiveStreaming,
    required this.codeBlockExpandedState,
    required this.onCodeBlockExpansionChanged,
    required this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    final subBlocks = _splitMarkdownSubBlocks(text);
    if (subBlocks.isEmpty) return const SizedBox.shrink();

    return ValhallaCard(
      color: context.colorScheme.surface,
      padding: const EdgeInsets.all(VSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < subBlocks.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i < subBlocks.length - 1 ? 8.0 : 0.0,
              ),
              child: _CachedMarkdownSubBlock(
                key: ValueKey('sub_${messageId}_${blockStart}_$i'),
                text: subBlocks[i],
                sessionId: sessionId,
                messageId: messageId,
                blockStart: blockStart,
                subIndex: i,
                isLiveStreaming: isLiveStreaming && (i == subBlocks.length - 1),
                codeBlockExpandedState: codeBlockExpandedState,
                onCodeBlockExpansionChanged: onCodeBlockExpansionChanged,
                onTapLink: onTapLink,
              ),
            ),
        ],
      ),
    );
  }
}

class _CachedMarkdownSubBlock extends StatelessWidget {
  final String text;
  final String sessionId;
  final String messageId;
  final int blockStart;
  final int subIndex;
  final bool isLiveStreaming;
  final Map<String, bool> codeBlockExpandedState;
  final void Function(String codeKey, bool expanded)
  onCodeBlockExpansionChanged;
  final void Function(String href) onTapLink;

  const _CachedMarkdownSubBlock({
    super.key,
    required this.text,
    required this.sessionId,
    required this.messageId,
    required this.blockStart,
    required this.subIndex,
    required this.isLiveStreaming,
    required this.codeBlockExpandedState,
    required this.onCodeBlockExpansionChanged,
    required this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (linkText, href, title) {
        if (href != null && href.isNotEmpty) {
          onTapLink(href);
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context),
      ).copyWith(code: monoTextStyle(fontSize: 12)),
      builders: {
        'pre': _PreCodeBlockElementBuilder(
          sessionId: sessionId,
          messageId: messageId,
          blockStart: blockStart,
          subIndex: subIndex,
          isLiveStreaming: isLiveStreaming,
          codeBlockExpandedState: codeBlockExpandedState,
          onCodeBlockExpansionChanged: onCodeBlockExpansionChanged,
        ),
      },
    );
  }
}

class _PreCodeBlockElementBuilder extends MarkdownElementBuilder {
  final String sessionId;
  final String messageId;
  final int blockStart;
  final int subIndex;
  final bool isLiveStreaming;
  final Map<String, bool> codeBlockExpandedState;
  final void Function(String codeKey, bool expanded)
  onCodeBlockExpansionChanged;

  int _codeIndex = 0;

  _PreCodeBlockElementBuilder({
    required this.sessionId,
    required this.messageId,
    required this.blockStart,
    required this.subIndex,
    required this.isLiveStreaming,
    required this.codeBlockExpandedState,
    required this.onCodeBlockExpansionChanged,
  });

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element.tag != 'pre') return null;
    final code = element.textContent;
    final index = _codeIndex++;
    final codeKey = '$sessionId:$messageId:$blockStart:$subIndex:code_$index';

    String? language;
    if (element.children != null && element.children!.isNotEmpty) {
      final child = element.children!.first;
      if (child is md.Element && child.attributes['class'] != null) {
        final cls = child.attributes['class']!;
        language = cls.startsWith('language-')
            ? cls.substring('language-'.length)
            : cls;
      }
    }

    return _HistoricalCodeBlockWidget(
      key: ValueKey(codeKey),
      code: code,
      language: language,
      codeKey: codeKey,
      isLiveStreaming: isLiveStreaming,
      canonicalExpanded: codeBlockExpandedState[codeKey],
      onExpansionChanged: (expanded) =>
          onCodeBlockExpansionChanged(codeKey, expanded),
    );
  }
}

int _logicalCodeLineCount(String code) {
  if (code.isEmpty) return 0;
  final rawLines = code.split('\n');
  return (rawLines.isNotEmpty && rawLines.last.isEmpty)
      ? rawLines.length - 1
      : rawLines.length;
}

class _HistoricalCodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;
  final String codeKey;
  final bool isLiveStreaming;
  final bool? canonicalExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const _HistoricalCodeBlockWidget({
    super.key,
    required this.code,
    this.language,
    required this.codeKey,
    required this.isLiveStreaming,
    required this.canonicalExpanded,
    this.onExpansionChanged,
  });

  @override
  State<_HistoricalCodeBlockWidget> createState() =>
      _HistoricalCodeBlockWidgetState();
}

class _HistoricalCodeBlockWidgetState
    extends State<_HistoricalCodeBlockWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    final totalLines = _logicalCodeLineCount(widget.code);
    if (widget.canonicalExpanded != null) {
      _isExpanded = widget.canonicalExpanded!;
    } else {
      _isExpanded = widget.isLiveStreaming || totalLines <= 30;
      widget.onExpansionChanged?.call(_isExpanded);
    }
  }

  @override
  void didUpdateWidget(covariant _HistoricalCodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canonicalExpanded != null &&
        widget.canonicalExpanded != oldWidget.canonicalExpanded &&
        widget.canonicalExpanded != _isExpanded) {
      _isExpanded = widget.canonicalExpanded!;
    }
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.split('\n');
    final totalLines = _logicalCodeLineCount(widget.code);
    final isLong = totalLines > 30;
    final bool shouldFold = isLong && !_isExpanded;

    final displayCode = shouldFold ? lines.take(12).join('\n') : widget.code;
    final langLabel = (widget.language != null && widget.language!.isNotEmpty)
        ? widget.language!.toLowerCase()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(VRadius.input),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF202024),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(VRadius.input),
              ),
              border: Border(
                bottom: BorderSide(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                if (langLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      langLabel,
                      style: monoTextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  )
                else
                  Text(
                    'Code',
                    style: monoTextStyle(
                      fontSize: 10,
                      color: context.colorScheme.outline,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen_outlined, size: 14),
                  tooltip: context.l10n.chatCodeReaderTitle,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => _CodeReaderDialog(
                        code: widget.code,
                        language: langLabel,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  tooltip: context.l10n.copy,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.chatCodeCopied),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              displayCode,
              style: monoTextStyle(
                fontSize: 12,
                color: const Color(0xFFE6E6E6),
              ),
            ),
          ),
          // Expand / Collapse Footer
          if (isLong)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1F),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(VRadius.input),
                ),
                border: Border(
                  top: BorderSide(
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: Icon(
                      shouldFold ? Icons.expand_more : Icons.expand_less,
                      size: 14,
                    ),
                    label: Text(
                      shouldFold
                          ? context.l10n.chatExpandCode('$totalLines')
                          : context.l10n.chatCollapseCode,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: _toggle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CodeReaderDialog extends StatelessWidget {
  final String code;
  final String? language;

  const _CodeReaderDialog({required this.code, this.language});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: media.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 18,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    language != null
                        ? '${context.l10n.chatCodeReaderTitle} ($language)'
                        : context.l10n.chatCodeReaderTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_logicalCodeLineCount(code)} lines',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: context.l10n.copy,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.chatCodeCopied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: context.l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Code View
            Expanded(
              child: Container(
                color: const Color(0xFF141416),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      code,
                      style: monoTextStyle(
                        fontSize: 12,
                        color: const Color(0xFFECECEC),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
  final bool? isExpanded;
  final VoidCallback? onToggleExpand;

  const _ToolExecutionCard({
    super.key,
    required this.tool,
    required this.messageId,
    this.isExpanded,
    this.onToggleExpand,
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

  bool get _effectiveExpanded => widget.isExpanded ?? _expanded;

  void _handleToggleExpand() {
    if (widget.onToggleExpand != null) {
      widget.onToggleExpand!();
    } else {
      setState(() => _expanded = !_expanded);
    }
  }

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
            onTap: _handleToggleExpand,
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
                  turns: _effectiveExpanded ? 0.5 : 0,
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
          if (_effectiveExpanded) ...[
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

class _AcpFileEditorDialog extends ConsumerStatefulWidget {
  final AcpTextSnapshot snapshot;
  final int? initialLine;
  final bool isReadOnly;
  final String workspaceTarget;

  const _AcpFileEditorDialog({
    required this.snapshot,
    this.initialLine,
    this.isReadOnly = false,
    required this.workspaceTarget,
  });

  @override
  ConsumerState<_AcpFileEditorDialog> createState() =>
      _AcpFileEditorDialogState();
}

class _AcpFileEditorDialogState extends ConsumerState<_AcpFileEditorDialog> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late AcpTextSnapshot _snapshot;
  bool _isSaving = false;
  String? _errorMessage;
  bool _showDiff = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
    _controller = TextEditingController(text: _snapshot.content);
    _scrollController = ScrollController();
    if (widget.initialLine != null && widget.initialLine! > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final lineOffset = (widget.initialLine! - 1) * 20.0;
          if (lineOffset < _scrollController.position.maxScrollExtent) {
            _scrollController.jumpTo(lineOffset);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newContent = _controller.text;
    if (newContent == _snapshot.content) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chatNoChangesToSave)));
      return;
    }

    if (!_showDiff) {
      setState(() => _showDiff = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final String targetInfo = (_snapshot.targetPath != _snapshot.path)
        ? '${_snapshot.path} -> ${_snapshot.targetPath}'
        : _snapshot.path;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.sizeOf(ctx);
        final diffWidth = math.max(220.0, math.min(media.width - 128.0, 560.0));
        final diffHeight = math.max(
          140.0,
          math.min(media.height * 0.35, 280.0),
        );
        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.chatConfirmSaveFile),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.chatConfirmSaveFileMessage),
              const SizedBox(height: 6),
              Text(
                targetInfo,
                style: monoTextStyle(
                  fontSize: 12,
                ).copyWith(color: context.colorScheme.outline),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: diffWidth,
                height: diffHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: context.colorScheme.surfaceContainerLowest,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildDiffView(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(aiChatProvider.notifier)
          .saveWorkspaceText(_snapshot, newContent);
      final updated = await ref
          .read(aiChatProvider.notifier)
          .readWorkspaceText(
            _snapshot.path,
            expectedTarget: widget.workspaceTarget,
          );
      if (!mounted) return;
      setState(() {
        _snapshot = updated;
        _isSaving = false;
        _errorMessage = null;
        _showDiff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chatFileSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isExecChanged = msg.contains('CHAT_SESSION_EXECUTION_CHANGED');
      setState(() {
        _isSaving = false;
        _errorMessage = isExecChanged
            ? context.l10n.chatExecutionChangedPrompt
            : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(_snapshot.path);
    final hasModifications = _controller.text != _snapshot.content;
    final isEffectiveReadOnly = widget.isReadOnly || !_snapshot.canSave;

    return PopScope(
      canPop: !hasModifications,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.chatUnsavedChangesTitle),
            content: Text(context.l10n.chatUnsavedChangesMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.chatDiscard),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _snapshot.path,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (isEffectiveReadOnly)
                Chip(
                  label: Text(context.l10n.chatFileReadOnly),
                  visualDensity: VisualDensity.compact,
                )
              else ...[
                if (hasModifications)
                  TextButton.icon(
                    icon: Icon(
                      _showDiff ? Icons.edit : Icons.difference_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _showDiff
                          ? context.l10n.chatFileEditorEdit
                          : context.l10n.chatFileEditorDiff,
                    ),
                    onPressed: () => setState(() => _showDiff = !_showDiff),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(context.l10n.save),
                    onPressed: (_isSaving || !hasModifications)
                        ? null
                        : _handleSave,
                  ),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: context.colorScheme.errorContainer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: context.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: context.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _showDiff
                    ? _buildDiffView()
                    : Container(
                        color: context.colorScheme.surfaceContainerLowest,
                        child: TextField(
                          controller: _controller,
                          scrollController: _scrollController,
                          readOnly: isEffectiveReadOnly,
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          style: monoTextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffView({ScrollController? controller}) {
    final origLines = _snapshot.content.isEmpty
        ? const <String>[]
        : _snapshot.content.split('\n');
    final newLines = _controller.text.isEmpty
        ? const <String>[]
        : _controller.text.split('\n');
    final maxLen = origLines.length > newLines.length
        ? origLines.length
        : newLines.length;

    Widget buildRow({
      required String lineNum,
      required String sign,
      required String line,
      Color? bgColor,
      Color? textColor,
    }) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                lineNum,
                style: TextStyle(
                  color: context.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(
              width: 14,
              child: Text(
                sign,
                style: monoTextStyle(fontSize: 12).copyWith(
                  color: textColor ?? context.colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                line,
                style: monoTextStyle(fontSize: 12).copyWith(color: textColor),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      primary: false,
      padding: const EdgeInsets.all(12),
      itemCount: maxLen,
      itemBuilder: (context, idx) {
        final orig = idx < origLines.length ? origLines[idx] : null;
        final repl = idx < newLines.length ? newLines[idx] : null;
        final lineNum = '${idx + 1}';

        if (orig == repl) {
          return buildRow(lineNum: lineNum, sign: ' ', line: orig ?? '');
        }

        final List<Widget> children = [];
        if (orig != null) {
          children.add(
            buildRow(
              lineNum: lineNum,
              sign: '-',
              line: orig,
              bgColor: Colors.red.withValues(alpha: 0.12),
              textColor: Colors.red[800],
            ),
          );
        }
        if (repl != null) {
          children.add(
            buildRow(
              lineNum: lineNum,
              sign: '+',
              line: repl,
              bgColor: Colors.green.withValues(alpha: 0.12),
              textColor: Colors.green[800],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

class _WorkbenchPanel extends ConsumerStatefulWidget {
  final bool isDesktop;
  final ScrollController? scrollController;
  final VoidCallback? onClose;
  final Future<void> Function(
    BuildContext context,
    String path, {
    String? expectedTarget,
    int? line,
  })
  onOpenFile;

  const _WorkbenchPanel({
    required this.isDesktop,
    this.scrollController,
    this.onClose,
    required this.onOpenFile,
  });

  @override
  ConsumerState<_WorkbenchPanel> createState() => _WorkbenchPanelState();
}

class _WorkbenchPanelState extends ConsumerState<_WorkbenchPanel> {
  int _tabIndex = 0;
  String? _trackedActiveTarget;
  String? _cachedWorkspaceKey;
  String? _currentBrowsePath;
  List<SftpFileItem>? _cachedFiles;
  bool _isLoadingFiles = false;
  String? _filesError;
  int _filesRequestVersion = 0;

  Future<void> _refreshFiles({bool forceResolve = false}) async {
    final capturedTarget = ref
        .read(aiChatProvider.notifier)
        .workspaceSelectionKey;
    final currentVersion = ++_filesRequestVersion;

    setState(() {
      _isLoadingFiles = true;
      _filesError = null;
    });

    try {
      String targetPath;
      if (_currentBrowsePath == null ||
          _currentBrowsePath == '.' ||
          forceResolve ||
          _cachedWorkspaceKey != capturedTarget) {
        targetPath = await ref
            .read(aiChatProvider.notifier)
            .resolveWorkspaceDirectory();
      } else {
        targetPath = _currentBrowsePath!;
      }

      final items = await ref
          .read(aiChatProvider.notifier)
          .listWorkspaceFiles(targetPath);

      if (!mounted || _filesRequestVersion != currentVersion) return;
      final latestTarget = ref
          .read(aiChatProvider.notifier)
          .workspaceSelectionKey;
      if (latestTarget != capturedTarget) return;

      setState(() {
        _cachedWorkspaceKey = capturedTarget;
        _cachedFiles = items;
        _currentBrowsePath = targetPath;
        _isLoadingFiles = false;
      });
    } catch (e) {
      if (!mounted || _filesRequestVersion != currentVersion) return;
      final latestTarget = ref
          .read(aiChatProvider.notifier)
          .workspaceSelectionKey;
      if (latestTarget != capturedTarget) return;

      final msg = e.toString();
      final isExecChanged = msg.contains('CHAT_SESSION_EXECUTION_CHANGED');
      setState(() {
        _isLoadingFiles = false;
        _filesError = isExecChanged
            ? context.l10n.chatExecutionChangedPrompt
            : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(serverConnectionProvider.select((c) => c.isConnected), (
      prev,
      next,
    ) {
      if (prev == false && next == true && mounted) {
        _refreshFiles(forceResolve: false);
      }
    });
    ref.watch(activeServerProvider.select((s) => s?.connectionKey));
    ref.watch(
      aiChatProvider.select((s) {
        final profile = s.activeAgentProfile;
        return (
          sessionId: s.activeSessionId,
          agentId: profile?.id,
          executionKey: profile != null ? chatExecutionKey(profile) : null,
          cliCommand: profile?.cliCommand,
          acpCommand: profile?.acpCommand,
          directory:
              s.activeSession?.workingDirectory ?? s.draftWorkingDirectory,
        );
      }),
    );
    final currentTarget = ref
        .read(aiChatProvider.notifier)
        .workspaceSelectionKey;

    if (_trackedActiveTarget != null && _trackedActiveTarget != currentTarget) {
      _filesRequestVersion++;
      _trackedActiveTarget = currentTarget;
      _cachedWorkspaceKey = null;
      _cachedFiles = null;
      _currentBrowsePath = null;
      _filesError = null;
      _isLoadingFiles = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshFiles(forceResolve: true);
      });
    } else if (_trackedActiveTarget == null) {
      _trackedActiveTarget = currentTarget;
      if (_cachedFiles == null && !_isLoadingFiles && _filesError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshFiles(forceResolve: true);
        });
      }
    }

    return Material(
      color: context.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.view_quilt_outlined,
                    size: 18,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.chatWorkbench,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_tabIndex == 0)
                    IconButton(
                      icon: _isLoadingFiles
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      tooltip: context.l10n.refresh,
                      onPressed: _isLoadingFiles
                          ? null
                          : () => _refreshFiles(forceResolve: false),
                    ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    icon: const Icon(Icons.folder_outlined, size: 14),
                    label: Text(
                      context.l10n.chatWorkbenchFiles,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: const Icon(Icons.task_alt_outlined, size: 14),
                    label: Text(
                      context.l10n.chatWorkbenchTasks,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  ButtonSegment<int>(
                    value: 2,
                    icon: const Icon(Icons.info_outline, size: 14),
                    label: Text(
                      context.l10n.chatWorkbenchContext,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (val) {
                  setState(() => _tabIndex = val.first);
                  if (val.first == 0 &&
                      _cachedFiles == null &&
                      !_isLoadingFiles) {
                    _refreshFiles(forceResolve: true);
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_tabIndex) {
                0 => _buildFilesTab(widget.scrollController),
                1 => _buildTasksTab(widget.scrollController),
                2 => _buildContextTab(widget.scrollController),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesTab(ScrollController? controller) {
    final currentPath = _currentBrowsePath ?? '/';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          child: Row(
            children: [
              if (_currentBrowsePath != null && _currentBrowsePath != '/')
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    final parent = p.posix.dirname(currentPath);
                    setState(() => _currentBrowsePath = parent);
                    _refreshFiles();
                  },
                ),
              Expanded(
                child: Text(
                  currentPath,
                  style: monoTextStyle(
                    fontSize: 11,
                    color: context.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser, size: 16),
                tooltip: 'Browse',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () async {
                  final captured = ref
                      .read(aiChatProvider.notifier)
                      .workspaceSelectionKey;
                  final picked = await RemoteWorkspaceBrowserDialog.show(
                    context,
                    initialPath: currentPath,
                    mode: RemoteBrowserMode.directory,
                  );
                  if (picked is String && mounted) {
                    final latest = ref
                        .read(aiChatProvider.notifier)
                        .workspaceSelectionKey;
                    if (latest != captured) return;
                    setState(() => _currentBrowsePath = picked);
                    _refreshFiles();
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_isLoadingFiles && _cachedFiles != null)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: (_cachedFiles == null && _isLoadingFiles)
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_filesError != null &&
                    (_cachedFiles == null || _cachedFiles!.isEmpty))
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _filesError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _refreshFiles(forceResolve: true),
                          child: Text(context.l10n.stateRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : (_cachedFiles == null || _cachedFiles!.isEmpty)
              ? Center(
                  child: Text(
                    context.l10n.chatNoFilesInDirectory,
                    style: TextStyle(
                      color: context.colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_filesError != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        color: context.colorScheme.errorContainer,
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              size: 14,
                              color: context.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _filesError!,
                                style: TextStyle(
                                  color: context.colorScheme.onErrorContainer,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: _cachedFiles!.length,
                        itemBuilder: (ctx, index) {
                          final item = _cachedFiles![index];
                          final isDir = item.isDirectory;
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Icon(
                              isDir
                                  ? Icons.folder
                                  : Icons.insert_drive_file_outlined,
                              size: 18,
                              color: isDir ? Colors.amber[700] : null,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isDir) ...[
                                  Text(
                                    _formatFileBytes(item.sizeBytes),
                                    style: TextStyle(
                                      color: context.colorScheme.outline,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.attachment,
                                      size: 14,
                                    ),
                                    tooltip: context.l10n.chatAttachTooltip,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    onPressed: () async {
                                      final currentTarget = ref
                                          .read(aiChatProvider.notifier)
                                          .workspaceSelectionKey;
                                      if (_cachedWorkspaceKey == null ||
                                          _cachedWorkspaceKey !=
                                              currentTarget) {
                                        return;
                                      }
                                      try {
                                        await ref
                                            .read(aiChatProvider.notifier)
                                            .attachRemoteFile(item.path);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${context.l10n.chatAttachTooltip}: ${item.name}',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        final msg = e.toString();
                                        if (msg.contains(
                                          'ACP_TARGET_CHANGED',
                                        )) {
                                          return;
                                        }
                                        final isUnsupported = msg.contains(
                                          'ACP_ATTACHMENT_UNSUPPORTED',
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isUnsupported
                                                  ? context
                                                        .l10n
                                                        .chatAttachFailed
                                                  : msg,
                                            ),
                                            backgroundColor:
                                                context.colorScheme.error,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ] else
                                  const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                            onTap: () async {
                              final currentTarget = ref
                                  .read(aiChatProvider.notifier)
                                  .workspaceSelectionKey;
                              if (_cachedWorkspaceKey == null ||
                                  _cachedWorkspaceKey != currentTarget) {
                                return;
                              }
                              final rowTarget = _cachedWorkspaceKey!;
                              if (isDir) {
                                setState(() {
                                  _currentBrowsePath = item.path;
                                });
                                _refreshFiles();
                              } else {
                                final mime = AcpWorkspaceFiles.mimeType(
                                  item.name,
                                );
                                if (mime?.startsWith('image/') ?? false) {
                                  try {
                                    final bytes = await ref
                                        .read(aiChatProvider.notifier)
                                        .readWorkspaceImage(
                                          item.path,
                                          expectedTarget: rowTarget,
                                        );
                                    if (mounted) {
                                      ImageZoomDialog.show(
                                        context,
                                        title: item.name,
                                        bytes: bytes,
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    final msg = e.toString();
                                    if (msg.contains('ACP_TARGET_CHANGED')) {
                                      return;
                                    }
                                    final isExecChanged = msg.contains(
                                      'CHAT_SESSION_EXECUTION_CHANGED',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isExecChanged
                                              ? context
                                                    .l10n
                                                    .chatExecutionChangedPrompt
                                              : msg,
                                        ),
                                        backgroundColor:
                                            context.colorScheme.error,
                                      ),
                                    );
                                  }
                                  return;
                                }
                                widget.onOpenFile(
                                  context,
                                  item.path,
                                  expectedTarget: rowTarget,
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTasksTab(ScrollController? controller) {
    return Consumer(
      builder: (ctx, tasksRef, _) {
        final serverRun = tasksRef.watch(
          aiChatProvider.select((s) => s.serverRun),
        );
        final isViewingRun = tasksRef.watch(
          aiChatProvider.select((s) => s.isViewingRun),
        );
        final isSshConnected = tasksRef.watch(
          serverConnectionProvider.select((s) => s.isConnected),
        );
        final messages = tasksRef.watch(
          aiChatProvider.select((s) => s.activeSession?.messages ?? const []),
        );
        ChatMessage? lastAssistant;
        for (int i = messages.length - 1; i >= 0; i--) {
          if (messages[i].role == MessageRole.assistant) {
            lastAssistant = messages[i];
            break;
          }
        }

        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            if (serverRun != null) ...[
              ValhallaCard(
                color: context.colorScheme.surface,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          serverRun.isBusy
                              ? (isSshConnected
                                    ? Icons.autorenew
                                    : Icons.cloud_off_outlined)
                              : Icons.check_circle_outline,
                          size: 16,
                          color: serverRun.isBusy
                              ? (isSshConnected
                                    ? context.colorScheme.primary
                                    : context.vWarning)
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          serverRun.isBusy
                              ? (isSshConnected
                                    ? context.l10n.acpRunningSessionIndicator(
                                        serverRun.agentName,
                                      )
                                    : context.l10n.acpAgentOfflineRunning)
                              : context.l10n.agentStatusReady,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Agent: ${serverRun.agentId}',
                      style: TextStyle(
                        color: context.colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Session: ${serverRun.sessionId}',
                      style: TextStyle(
                        color: context.colorScheme.outline,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (serverRun.isBusy && !isViewingRun) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.visibility, size: 14),
                        label: Text(
                          context.l10n.chatViewCurrentRun,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => tasksRef
                            .read(aiChatProvider.notifier)
                            .returnToRunningSession(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (lastAssistant != null &&
                lastAssistant.planSteps.isNotEmpty) ...[
              Text('Plan Steps', style: context.textTheme.labelMedium),
              const SizedBox(height: 6),
              ValhallaCard(
                color: context.colorScheme.surface,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in lastAssistant.planSteps)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              step.status == PlanStepStatus.completed
                                  ? Icons.check_box
                                  : (step.status == PlanStepStatus.inProgress
                                        ? Icons.pending_outlined
                                        : Icons.check_box_outline_blank),
                              size: 16,
                              color: step.status == PlanStepStatus.completed
                                  ? Colors.green
                                  : (step.status == PlanStepStatus.inProgress
                                        ? context.colorScheme.primary
                                        : context.colorScheme.outline),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  decoration:
                                      step.status == PlanStepStatus.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (lastAssistant != null &&
                lastAssistant.toolExecutions.isNotEmpty) ...[
              Text('Tool Executions', style: context.textTheme.labelMedium),
              const SizedBox(height: 6),
              for (final tool in lastAssistant.toolExecutions) ...[
                ValhallaCard(
                  color: context.colorScheme.surface,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build_outlined,
                            size: 14,
                            color: context.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tool.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            tool.status.name,
                            style: TextStyle(
                              color: context.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (tool.command.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tool.command,
                          style: monoTextStyle(fontSize: 11),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
            if (serverRun == null &&
                (lastAssistant == null ||
                    (lastAssistant.planSteps.isEmpty &&
                        lastAssistant.toolExecutions.isEmpty)))
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.chatNoActiveTasks,
                    style: TextStyle(
                      color: context.colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContextTab(ScrollController? controller) {
    return Consumer(
      builder: (ctx, contextRef, _) {
        final profile = contextRef.watch(
          aiChatProvider.select((s) => s.activeAgentProfile),
        );
        final workingDir = contextRef.watch(
          aiChatProvider.select(
            (s) =>
                s.activeSession?.workingDirectory ??
                s.draftWorkingDirectory ??
                'Default',
          ),
        );
        final model = contextRef.watch(
          aiChatProvider.select((s) => s.runSettings.modelId),
        );
        final supportsImages = contextRef.watch(
          aiChatProvider.select((s) => s.supportsImages),
        );
        final supportsFiles = contextRef.watch(
          aiChatProvider.select((s) => s.supportsTextAttachments),
        );
        final server = contextRef.watch(activeServerProvider);
        final isConnected = contextRef.watch(
          serverConnectionProvider.select((c) => c.isConnected),
        );

        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(12),
          children: [
            ValhallaCard(
              color: context.colorScheme.surface,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 16,
                        color: isConnected
                            ? Colors.green
                            : context.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        server?.name ?? 'Server',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? Colors.green.withValues(alpha: 0.15)
                              : context.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            fontSize: 10,
                            color: isConnected
                                ? Colors.green[800]
                                : context.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (server != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Host: ${server.host}:${server.port}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'User: ${server.username}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            ValhallaCard(
              color: context.colorScheme.surface,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        profile?.executionTarget == 'docker'
                            ? Icons.directions_boat_outlined
                            : Icons.terminal_outlined,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        profile?.executionTarget == 'docker'
                            ? 'Docker Container'
                            : 'Host Environment',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (profile?.executionTarget == 'docker') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Container: ${profile?.containerReference ?? profile?.containerBinding ?? "unspecified"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (profile?.containerUser != null)
                      Text(
                        'Container User: ${profile!.containerUser}',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Working Directory: $workingDir',
                    style: monoTextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (profile != null)
              ValhallaCard(
                color: context.colorScheme.surface,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 16,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CLI: ${profile.cliCommand}',
                      style: monoTextStyle(fontSize: 11),
                    ),
                    if (model != null && model.isNotEmpty)
                      Text(
                        'Model: $model',
                        style: const TextStyle(fontSize: 11),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (supportsImages)
                          Chip(
                            label: const Text(
                              'Images',
                              style: TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        if (supportsFiles)
                          Chip(
                            label: const Text(
                              'Files',
                              style: TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

String _formatFileBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
