import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/terminal_provider.dart';
import '../../infrastructure/mosh/mosh_bridge_adapter.dart';
import '../../infrastructure/mosh/mosh_session_service.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/shared_terminal_canvas.dart';
import 'widgets/terminal_history_drawer.dart';

class SshTerminalView extends ConsumerStatefulWidget {
  final bool active;

  const SshTerminalView({super.key, this.active = true});

  @override
  ConsumerState<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends ConsumerState<SshTerminalView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _lastInitializedTarget;
  bool _dismissedTmuxMissing = false;
  bool _showSessionRestored = false;
  TerminalConnectionState? _lastBridgeState;
  TerminalSessionBridge? _lastListenedBridge;
  Timer? _sessionRestoredTimer;
  bool _hadConnectedOnce = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _scheduleEnsureInitialized();
    }
  }

  @override
  void didUpdateWidget(SshTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _scheduleEnsureInitialized();
    }
  }

  void _scheduleEnsureInitialized() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      final server = ref.read(activeServerProvider);
      final target =
          server == null ? null : TerminalHistoryRecord.targetFor(server);
      if (target != null && target != _lastInitializedTarget) {
        _lastInitializedTarget = target;
        ref.read(terminalProvider.notifier).ensureInitialized();
      } else if (target != null && ref.read(terminalProvider).tabs.isEmpty) {
        ref.read(terminalProvider.notifier).ensureInitialized();
      }
    });
  }

  @override
  void dispose() {
    _sessionRestoredTimer?.cancel();
    _lastListenedBridge?.stateListenable.removeListener(_onBridgeStateChanged);
    super.dispose();
  }

  void _syncBridgeListener(TerminalSessionBridge? bridge) {
    if (identical(_lastListenedBridge, bridge)) return;

    _sessionRestoredTimer?.cancel();
    _showSessionRestored = false;
    _lastListenedBridge?.stateListenable.removeListener(_onBridgeStateChanged);
    _lastListenedBridge = bridge;
    _lastBridgeState = bridge?.stateListenable.value;
    _hadConnectedOnce =
        bridge?.stateListenable.value == TerminalConnectionState.connected;
    bridge?.stateListenable.addListener(_onBridgeStateChanged);
  }

  void _onBridgeStateChanged() {
    final bridge = _lastListenedBridge;
    if (bridge == null) return;
    final newState = bridge.stateListenable.value;
    final isRestoredOrReconnect =
        bridge.sessionIntent == TerminalSessionIntent.restoreExisting ||
        _hadConnectedOnce;
    if (bridge.mode == TerminalSessionMode.tmux &&
        isRestoredOrReconnect &&
        _lastBridgeState != null &&
        _lastBridgeState != TerminalConnectionState.connected &&
        newState == TerminalConnectionState.connected) {
      _sessionRestoredTimer?.cancel();
      _showSessionRestored = true;
      _sessionRestoredTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSessionRestored = false);
        }
      });
    }
    if (newState == TerminalConnectionState.connected) {
      _hadConnectedOnce = true;
    }
    _lastBridgeState = newState;
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildTmuxNotice(BuildContext context, TerminalSessionBridge? bridge) {
    if (bridge == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    // 1. tmux mode & reconnected: transient 2s notice
    if (bridge.mode == TerminalSessionMode.tmux && _showSessionRestored) {
      return Container(
        key: const Key('terminalTmuxSessionRestored'),
        color: context.vSuccess.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: context.vSuccess, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.terminalTmuxSessionRestored,
                style: TextStyle(
                  color: context.vSuccess,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. tmuxUnavailable mode: non-blocking warning notice with close button
    // Only displayed when not awaiting user decision on an install offer
    if (bridge.mode == TerminalSessionMode.tmuxUnavailable &&
        !_dismissedTmuxMissing &&
        !bridge.awaitingTmuxDecision) {
      return Container(
        key: const Key('terminalTmuxMissingNotice'),
        color: context.vWarning.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: context.vWarning,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.terminalTmuxMissingNotice,
                style: TextStyle(
                  color: context.vWarning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: context.vWarning),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => setState(() => _dismissedTmuxMissing = true),
            ),
          ],
        ),
      );
    }

    // 3. plain or others: display nothing
    return const SizedBox.shrink();
  }

  Widget _buildTmuxInstallOfferDialog(
    BuildContext context,
    TmuxInstallOffer offer,
    TerminalSessionBridge? bridge,
  ) {
    final l10n = context.l10n;
    final installCommand =
        offer.installCommand ?? bridge?.proposedInstallCommand;

    String? errorText;
    if (offer.errorCode == 'TMUX_INSTALL_UNSUPPORTED') {
      errorText = l10n.terminalTmuxInstallUnsupported;
    } else if (offer.errorCode == 'TMUX_INSTALL_FAILED') {
      errorText = l10n.terminalTmuxInstallFailed;
    } else if (offer.errorCode == 'SSH_DISCONNECTED') {
      errorText = l10n.terminalTmuxInstallDisconnected;
    } else if (offer.errorCode != null) {
      errorText = offer.errorCode;
    }

    return Card(
      key: const Key('tmuxInstallOfferDialog'),
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.card),
        side: BorderSide(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal_outlined,
                  size: 22,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.terminalTmuxInstallDialogTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.terminalTmuxInstallDialogMessage,
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (installCommand != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.terminalTmuxInstallCommandLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: context.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SelectableText(
                  installCommand,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                  ),
                ),
              ),
            ] else if (offer.errorCode == null) ...[
              const SizedBox(height: 10),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
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
                        errorText,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (offer.isInstalling) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.terminalTmuxInstallInstalling,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: offer.isInstalling
                        ? null
                        : () => ref
                              .read(terminalProvider.notifier)
                              .skipTmuxInstall(),
                    child: Text(l10n.terminalTmuxInstallSkip),
                  ),
                  FilledButton(
                    onPressed: (offer.isInstalling || installCommand == null)
                        ? null
                        : () => ref
                              .read(terminalProvider.notifier)
                              .confirmTmuxInstall(),
                    child: Text(l10n.terminalTmuxInstallConfirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mosh 会话的 bootstrap 失败提示条：按错误分类给出针对性文案
  /// (notInstalled → 安装引导 / timeout → UDP 排查 / 其他 → 失败详情)。
  /// 仅当激活标签页是处于 error 状态的 Mosh 会话时显示。
  Widget _buildMoshNotice(BuildContext context, TerminalSessionBridge? bridge) {
    if (bridge is! MoshBridgeAdapter) return const SizedBox.shrink();
    if (bridge.state != TerminalConnectionState.error) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final mosh = bridge.moshBridge;
    final error = mosh.bootstrapError;
    final String message;
    switch (error) {
      case MoshBootstrapError.notInstalled:
        message = l10n.moshNotInstalled;
      case MoshBootstrapError.timeout:
        message = l10n.moshUdpTimeout;
      case MoshBootstrapError.startFailed:
      case MoshBootstrapError.sshFailed:
      case null:
        message = l10n.moshBootstrapFailed(
          mosh.bootstrapErrorDetail ?? error?.name ?? 'unknown',
        );
    }

    return Container(
      key: const Key('terminalMoshErrorNotice'),
      color: context.vDanger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.vDanger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.vDanger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localizeErrorCode(BuildContext context, String code) {
    final l10n = context.l10n;
    return switch (code) {
      'TERMINAL_HISTORY_LOAD_FAILED' => l10n.terminalErrorHistoryLoadFailed,
      'TERMINAL_HISTORY_SAVE_FAILED' => l10n.terminalErrorHistorySaveFailed,
      'TERMINAL_HISTORY_REFRESH_FAILED' =>
        l10n.terminalErrorHistoryRefreshFailed,
      'TERMINAL_START_FAILED' => l10n.terminalErrorStartFailed,
      'TERMINAL_RESTORE_FAILED' => l10n.terminalErrorRestoreFailed,
      'TERMINAL_DEFAULT_SAVE_FAILED' => l10n.terminalErrorDefaultSaveFailed,
      'TERMINAL_COMMAND_FAILED' => l10n.terminalErrorCommandFailed,
      'TERMINAL_TITLE_INVALID' => l10n.terminalErrorTitleInvalid,
      'SSH_DISCONNECTED' => l10n.terminalErrorSshDisconnected,
      _ => code,
    };
  }

  String _localizeNoticeCode(BuildContext context, String code) {
    final l10n = context.l10n;
    return switch (code) {
      'TERMINAL_DEFAULT_MISSING' => l10n.terminalNoticeDefaultMissing,
      'TERMINAL_SESSION_MISSING' => l10n.terminalNoticeSessionMissing,
      'TERMINAL_PLAIN_INTERRUPTED' => l10n.terminalNoticePlainInterrupted,
      _ => code,
    };
  }

  Widget _buildErrorBanner(BuildContext context, String code) {
    final message = _localizeErrorCode(context, code);
    return Container(
      key: const Key('terminalErrorBanner'),
      color: context.vDanger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.vDanger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.vDanger,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: context.vDanger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => ref.read(terminalProvider.notifier).clearNotice(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(BuildContext context, String code) {
    final message = _localizeNoticeCode(context, code);
    return Container(
      key: const Key('terminalNoticeBanner'),
      color: context.vWarning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.vWarning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: context.vWarning,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: context.vWarning),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => ref.read(terminalProvider.notifier).clearNotice(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SshTerminalState state) {
    if (state.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final isConnected = ref.watch(serverConnectionProvider).isConnected;
    final code = state.errorCode ??
        (!isConnected ? 'SSH_DISCONNECTED' : 'TERMINAL_START_FAILED');
    final message = _localizeErrorCode(context, code);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !isConnected ? Icons.cloud_off : Icons.error_outline,
              size: 48,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () =>
                  ref.read(terminalProvider.notifier).ensureInitialized(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.stateRetry),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeServerProvider, (prev, next) {
      final prevTarget =
          prev == null ? null : TerminalHistoryRecord.targetFor(prev);
      final nextTarget =
          next == null ? null : TerminalHistoryRecord.targetFor(next);
      if (widget.active && nextTarget != prevTarget) {
        _scheduleEnsureInitialized();
      }
    });
    ref.listen(serverConnectionProvider, (prev, next) {
      if (widget.active && next.isConnected && prev?.isConnected != true) {
        _scheduleEnsureInitialized();
      }
    });

    final terminalState = ref.watch(terminalProvider);
    final activeTab = terminalState.activeTab;
    final originatingTab = activeTab;
    _syncBridgeListener(activeTab?.bridge);

    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: false,
      backgroundColor: Colors.transparent,
      drawer: const TerminalHistoryDrawer(),
      onDrawerChanged: (isOpened) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      body: Column(
        children: [
          _buildTabBar(terminalState),
          if (terminalState.errorCode != null)
            _buildErrorBanner(context, terminalState.errorCode!),
          if (terminalState.noticeCode != null)
            _buildNoticeBanner(context, terminalState.noticeCode!),
          if (terminalState.tmuxInstallOffer == null) ...[
            _buildTmuxNotice(context, activeTab?.bridge),
            _buildMoshNotice(context, activeTab?.bridge),
          ],
          Expanded(
            child: originatingTab != null
                ? SharedTerminalCanvas(
                    terminal: originatingTab.terminal,
                    requestKeyboardOnTap: false,
                    pinKeyboardButtonTrailing: true,
                    onKey:
                        (
                          key, {
                          bool isCtrl = false,
                          bool isAlt = false,
                          bool isShift = false,
                        }) {
                          ref
                              .read(terminalProvider.notifier)
                              .sendKey(
                                key,
                                isCtrl: isCtrl,
                                isAlt: isAlt,
                                isShift: isShift,
                              );
                        },
                    onPaste: () =>
                        ref.read(terminalProvider.notifier).pasteClipboard(),
                    onPasteText: (text) {
                      final currentTabs = ref.read(terminalProvider).tabs;
                      if (currentTabs.contains(originatingTab)) {
                        originatingTab.bridge.pasteText(text);
                      }
                    },
                    overlay: terminalState.tmuxInstallOffer != null
                        ? Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 520),
                                child: _buildTmuxInstallOfferDialog(
                                  context,
                                  terminalState.tmuxInstallOffer!,
                                  originatingTab.bridge,
                                ),
                              ),
                            ),
                          )
                        : null,
                  )
                : _buildEmptyState(context, terminalState),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(SshTerminalState state) {
    final notifier = ref.read(terminalProvider.notifier);

    return Container(
      color: context.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('terminal_history_button'),
            icon: const Icon(Icons.history, size: 18),
            tooltip: context.l10n.terminalHistoryButton,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(state.tabs.length, (index) {
                  final isSelected = state.activeTabIndex == index;
                  final tab = state.tabs[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onLongPress: () => showRenameTabDialog(
                        context,
                        ref,
                        tab.id,
                        tab.title,
                      ),
                      onSecondaryTap: () => showRenameTabDialog(
                        context,
                        ref,
                        tab.id,
                        tab.title,
                      ),
                      child: InputChip(
                        key: ValueKey('terminal_tab_${tab.id}'),
                        selected: isSelected,
                        label: Tooltip(
                          message: tab.title,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              tab.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        deleteButtonTooltipMessage:
                            context.l10n.terminalCloseTab,
                        onDeleted: state.tabs.length > 1
                            ? () => notifier.closeTab(index)
                            : null,
                        onSelected: (selected) {
                          if (selected) notifier.selectTab(index);
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: context.l10n.terminalNewTab,
            onPressed: () => notifier.addNewTab(),
          ),
          if (state.moshAvailable)
            IconButton(
              key: const Key('terminal_new_mosh_tab'),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              tooltip: context.l10n.moshNewSession,
              onPressed: () => notifier.addMoshTab(context.l10n.moshSessionTag),
            ),
          IconButton(
            key: const Key('terminal_clear_button'),
            icon: const Icon(Icons.cleaning_services, size: 18),
            tooltip: context.l10n.terminalClear,
            onPressed: () {
              final terminal = state.activeTab?.terminal;
              if (terminal != null) {
                clearTerminalScrollState(terminal);
                // Parse locally so xterm clears screen/history and repaints.
                // This is display data, not a command sent to the SSH shell.
                terminal.write('\x1b[2J\x1b[3J\x1b[H');
              }
            },
          ),
        ],
      ),
    );
  }
}
