import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/terminal_provider.dart';
import '../../core/providers/terminal_settings_provider.dart';
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

class _SshTerminalViewState extends ConsumerState<SshTerminalView>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TerminalNotifier? _terminalNotifier;
  String? _lastInitializedTarget;
  bool _dismissedTmuxMissing = false;
  bool _showSessionRestored = false;
  TerminalConnectionState? _lastBridgeState;
  TerminalSessionBridge? _lastListenedBridge;
  Timer? _sessionRestoredTimer;
  final ScrollController _tabScrollController = ScrollController();
  final GlobalKey _tabBarScrollableKey = GlobalKey();
  final Map<String, GlobalKey> _tabKeys = {};
  bool _hadConnectedOnce = false;

  void _scheduleTabScroll(String? tabId) {
    if (tabId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tabScrollController.hasClients) return;
      final tabKey = _tabKeys[tabId];
      final tabContext = tabKey?.currentContext;
      final scrollableContext = _tabBarScrollableKey.currentContext;
      if (tabContext == null || scrollableContext == null) return;

      final tabBox = tabContext.findRenderObject() as RenderBox?;
      final scrollableBox = scrollableContext.findRenderObject() as RenderBox?;
      if (tabBox == null ||
          !tabBox.hasSize ||
          scrollableBox == null ||
          !scrollableBox.hasSize) {
        return;
      }

      final offset = tabBox.localToGlobal(Offset.zero, ancestor: scrollableBox);
      final tabLeft = offset.dx;
      final tabRight = tabLeft + tabBox.size.width;
      final viewportWidth = scrollableBox.size.width;

      final currentScrollOffset = _tabScrollController.offset;
      double? targetOffset;

      if (tabLeft < 0) {
        targetOffset = (currentScrollOffset + tabLeft).clamp(
          0.0,
          _tabScrollController.position.maxScrollExtent,
        );
      } else if (tabRight > viewportWidth) {
        targetOffset = (currentScrollOffset + (tabRight - viewportWidth)).clamp(
          0.0,
          _tabScrollController.position.maxScrollExtent,
        );
      }

      if (targetOffset != null &&
          (targetOffset - currentScrollOffset).abs() > 0.5) {
        _tabScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _terminalNotifier = ref.read(terminalProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) {
      _scheduleEnsureInitialized();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final activeTab = ref.read(terminalProvider).activeTab;
        if (activeTab != null) {
          _scheduleTabScroll(activeTab.id);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _terminalNotifier?.setHistoryVisible(false);
    } else if (widget.active &&
        (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      _terminalNotifier?.setHistoryVisible(true);
    }
  }

  @override
  void didUpdateWidget(SshTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _scheduleEnsureInitialized();
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        _terminalNotifier?.setHistoryVisible(true);
      }
    } else if (!widget.active && oldWidget.active) {
      _terminalNotifier?.setHistoryVisible(false);
    }
  }

  void _scheduleEnsureInitialized() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      final server = ref.read(activeServerProvider);
      final target = server == null
          ? null
          : TerminalHistoryRecord.targetFor(server);
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
    WidgetsBinding.instance.removeObserver(this);
    _terminalNotifier?.setHistoryVisible(false);
    _terminalNotifier = null;
    _tabScrollController.dispose();
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

  Widget _buildTmuxSessionRestoredBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: context.colorScheme.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(VRadius.input),
      child: Container(
        key: const Key('terminalTmuxSessionRestored'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.vSuccess.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(color: context.vSuccess.withValues(alpha: 0.35)),
        ),
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
      ),
    );
  }

  Widget _buildTmuxNotice(BuildContext context, TerminalSessionBridge? bridge) {
    if (bridge == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    // tmuxUnavailable mode: non-blocking warning notice with close button
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
      'TERMINAL_HISTORY_DELETE_FAILED' => l10n.terminalErrorHistoryDeleteFailed,
      'TERMINAL_HISTORY_TERMINATE_FAILED' ||
      'TERMINATE_FAILED' => l10n.terminalErrorHistoryTerminateFailed,
      'TERMINAL_HISTORY_TARGET_CHANGED' ||
      'TERMINAL_TARGET_CHANGED' => l10n.terminalErrorTargetChanged,
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
    return Material(
      color: context.colorScheme.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(VRadius.input),
      child: Container(
        key: const Key('terminalErrorBanner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.vDanger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(color: context.vDanger.withValues(alpha: 0.35)),
        ),
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
              onPressed: () =>
                  ref.read(terminalProvider.notifier).clearNotice(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBanner(BuildContext context, String code) {
    final message = _localizeNoticeCode(context, code);
    return Material(
      color: context.colorScheme.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(VRadius.input),
      child: Container(
        key: const Key('terminalNoticeBanner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.vWarning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(color: context.vWarning.withValues(alpha: 0.35)),
        ),
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
              onPressed: () =>
                  ref.read(terminalProvider.notifier).clearNotice(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SshTerminalState state) {
    if (state.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final isConnected = ref.watch(serverConnectionProvider).isConnected;
    final code =
        state.errorCode ??
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
      final prevTarget = prev == null
          ? null
          : TerminalHistoryRecord.targetFor(prev);
      final nextTarget = next == null
          ? null
          : TerminalHistoryRecord.targetFor(next);
      if (widget.active && nextTarget != prevTarget) {
        _scheduleEnsureInitialized();
      }
    });
    ref.listen(serverConnectionProvider, (prev, next) {
      if (widget.active && next.isConnected && prev?.isConnected != true) {
        _scheduleEnsureInitialized();
      }
    });
    ref.listen(terminalProvider.select((s) => s.activeTabIndex), (prev, next) {
      if (next != prev) {
        final tabs = ref.read(terminalProvider).tabs;
        if (next >= 0 && next < tabs.length) {
          _scheduleTabScroll(tabs[next].id);
        }
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
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        final isForeground =
            lifecycle == null || lifecycle == AppLifecycleState.resumed;
        _terminalNotifier?.setHistoryVisible(
          isOpened && widget.active && isForeground,
        );
        FocusManager.instance.primaryFocus?.unfocus();
      },
      body: Column(
        children: [
          _buildTabBar(terminalState),
          if (terminalState.tmuxInstallOffer == null) ...[
            _buildTmuxNotice(context, activeTab?.bridge),
            _buildMoshNotice(context, activeTab?.bridge),
          ],
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
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
                          onPaste: () => ref
                              .read(terminalProvider.notifier)
                              .pasteClipboard(),
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
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
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
                if (terminalState.errorCode != null)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildErrorBanner(
                          context,
                          terminalState.errorCode!,
                        ),
                      ),
                    ),
                  )
                else if (terminalState.noticeCode != null)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildNoticeBanner(
                          context,
                          terminalState.noticeCode!,
                        ),
                      ),
                    ),
                  )
                else if (terminalState.tmuxInstallOffer == null &&
                    activeTab?.bridge.mode == TerminalSessionMode.tmux &&
                    _showSessionRestored)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildTmuxSessionRestoredBanner(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(SshTerminalState state) {
    final notifier = ref.read(terminalProvider.notifier);
    final currentTabIds = state.tabs.map((t) => t.id).toSet();
    _tabKeys.removeWhere((id, _) => !currentTabIds.contains(id));

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
              key: _tabBarScrollableKey,
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(state.tabs.length, (index) {
                  final isSelected = state.activeTabIndex == index;
                  final tab = state.tabs[index];
                  final isTmux = tab.bridge.mode == TerminalSessionMode.tmux;
                  final String modeName;
                  if (isTmux) {
                    modeName = 'tmux';
                  } else if (tab.bridge is MoshBridgeAdapter) {
                    modeName = 'Mosh';
                  } else {
                    modeName = 'SSH';
                  }

                  return Padding(
                    key: _tabKeys.putIfAbsent(tab.id, GlobalKey.new),
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => _showTabOptions(context, index, tab),
                      onSecondaryTap: () =>
                          _showTabOptions(context, index, tab),
                      child: InputChip(
                        key: ValueKey('terminal_tab_${tab.id}'),
                        selected: isSelected,
                        avatar: ValueListenableBuilder<TerminalConnectionState>(
                          valueListenable: tab.bridge.stateListenable,
                          builder: (context, connState, _) {
                            final Color dotColor;
                            switch (connState) {
                              case TerminalConnectionState.connected:
                                dotColor = context.vSuccess;
                                break;
                              case TerminalConnectionState.connecting:
                                dotColor = context.colorScheme.primary;
                                break;
                              case TerminalConnectionState.disconnected:
                                dotColor = context.vWarning;
                                break;
                              case TerminalConnectionState.error:
                                dotColor = context.vDanger;
                                break;
                            }
                            return SizedBox(
                              width: 18,
                              height: 18,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    isTmux
                                        ? Icons.layers_outlined
                                        : Icons.terminal,
                                    size: 13,
                                    color: isSelected
                                        ? context.colorScheme.primary
                                        : context.colorScheme.outline,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      key: ValueKey(
                                        'terminal_tab_status_${tab.id}_${connState.name}',
                                      ),
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.colorScheme.surface,
                                          width: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        label: Tooltip(
                          triggerMode: TooltipTriggerMode.manual,
                          message: '${tab.title} ($modeName)',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () =>
                                _showTabOptions(context, index, tab),
                            onSecondaryTap: () =>
                                _showTabOptions(context, index, tab),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: Text(
                                tab.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            notifier.selectTab(index);
                            _scheduleTabScroll(tab.id);
                          }
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
          PopupMenuButton<String>(
            key: const Key('terminal_more_button'),
            icon: const Icon(Icons.more_vert, size: 18),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _handleClearScreen(state);
                case 'reconnect':
                  final activeTab = state.activeTab;
                  final server = ref.read(activeServerProvider);
                  if (activeTab != null && server != null) {
                    final targetKey = TerminalHistoryRecord.targetFor(server);
                    notifier.reconnectTab(
                      activeTab.id,
                      expectedTargetKey: targetKey,
                    );
                  }
                case 'tmux_mode':
                  FocusManager.instance.primaryFocus?.unfocus();
                  _showTerminalDefaultModeDialog(context);
                case 'new_mosh':
                  notifier.addMoshTab(context.l10n.moshSessionTag);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                key: const Key('terminal_reconnect_menu_item'),
                value: 'reconnect',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.terminalReconnectTab)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                key: const Key('terminal_clear_menu_item'),
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.cleaning_services, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.terminalClear)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                key: const Key('terminal_tmux_menu_item'),
                value: 'tmux_mode',
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.settingsTerminalUseTmux)),
                  ],
                ),
              ),
              if (state.moshAvailable)
                PopupMenuItem<String>(
                  key: const Key('terminal_new_mosh_menu_item'),
                  value: 'new_mosh',
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.l10n.moshNewSession)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTabOptions(BuildContext context, int index, TerminalTab tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    final activeServer = ref.read(activeServerProvider);
    final capturedTargetKey = activeServer == null
        ? null
        : TerminalHistoryRecord.targetFor(activeServer);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('terminal_tab_option_reconnect'),
              leading: const Icon(Icons.refresh),
              title: Text(context.l10n.terminalReconnectTab),
              onTap: () async {
                Navigator.pop(ctx);
                if (capturedTargetKey == null) return;
                try {
                  await ref
                      .read(terminalProvider.notifier)
                      .reconnectTab(
                        tab.id,
                        expectedTargetKey: capturedTargetKey,
                      );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.rename),
              onTap: () {
                Navigator.pop(ctx);
                showRenameTabDialog(context, ref, tab.id, tab.title);
              },
            ),
            if (ref.read(terminalProvider).tabs.length > 1)
              ListTile(
                key: const Key('terminal_tab_option_close'),
                leading: Icon(Icons.close, color: context.vDanger),
                title: Text(
                  context.l10n.terminalCloseTab,
                  style: TextStyle(color: context.vDanger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndCloseTab(context, tab, capturedTargetKey);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndCloseTab(
    BuildContext context,
    TerminalTab tab,
    String? capturedTargetKey,
  ) async {
    if (capturedTargetKey == null) return;
    final tabs = ref.read(terminalProvider).tabs;
    if (tabs.length <= 1) return;

    final isTmux = tab.bridge.mode == TerminalSessionMode.tmux;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(dialogCtx.l10n.terminalCloseTabConfirmTitle),
          content: Text(
            isTmux
                ? dialogCtx.l10n.terminalCloseTmuxConfirmMessage
                : dialogCtx.l10n.terminalClosePlainConfirmMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(dialogCtx.l10n.cancel),
            ),
            FilledButton(
              key: const Key('terminal_confirm_close_tab_button'),
              style: FilledButton.styleFrom(
                backgroundColor: isTmux
                    ? dialogCtx.colorScheme.primary
                    : dialogCtx.colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                isTmux
                    ? dialogCtx.l10n.terminalCloseActionDetach
                    : dialogCtx.l10n.terminalCloseActionTerminate,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      if (!context.mounted) return;
      final currentServer = ref.read(activeServerProvider);
      final currentTargetKey = currentServer == null
          ? null
          : TerminalHistoryRecord.targetFor(currentServer);
      if (currentTargetKey != capturedTargetKey) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.stateError)));
        return;
      }
      try {
        await ref
            .read(terminalProvider.notifier)
            .closeTabById(tab.id, expectedTargetKey: capturedTargetKey);
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  void _handleClearScreen(SshTerminalState state) {
    final terminal = state.activeTab?.terminal;
    if (terminal != null) {
      clearTerminalScrollState(terminal);
      terminal.write('\x1b[2J\x1b[3J\x1b[H');
    }
  }

  void _showTerminalDefaultModeDialog(BuildContext context) {
    final currentUseTmux = ref.read(terminalSettingsProvider).useTmux;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _TerminalDefaultModeDialog(
        initialUseTmux: currentUseTmux,
        onSelect: (value) async {
          await ref.read(terminalSettingsProvider.notifier).setUseTmux(value);
        },
      ),
    );
  }
}

class _TerminalDefaultModeDialog extends StatefulWidget {
  final bool initialUseTmux;
  final Future<void> Function(bool useTmux) onSelect;

  const _TerminalDefaultModeDialog({
    required this.initialUseTmux,
    required this.onSelect,
  });

  @override
  State<_TerminalDefaultModeDialog> createState() =>
      _TerminalDefaultModeDialogState();
}

class _TerminalDefaultModeDialogState
    extends State<_TerminalDefaultModeDialog> {
  late bool _selectedMode;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialUseTmux;
  }

  Future<void> _handleModeChanged(bool? value) async {
    if (value == null || _isSaving) return;
    setState(() {
      _selectedMode = value;
      _isSaving = true;
      _errorMessage = null;
    });

    final route = ModalRoute.of(context);
    try {
      await widget.onSelect(value);
      if (!mounted) return;
      if (route?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      if (route?.isCurrent ?? false) {
        setState(() {
          _selectedMode = widget.initialUseTmux;
          _isSaving = false;
          _errorMessage = context.l10n.terminalModeSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.settingsTerminalUseTmux),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsTerminalUseTmuxDescription,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<bool>(
            groupValue: _selectedMode,
            onChanged: _handleModeChanged,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  key: const Key('terminalModeStandardRadio'),
                  dense: true,
                  enabled: !_isSaving,
                  value: false,
                  title: Text(l10n.terminalModeStandard),
                ),
                RadioListTile<bool>(
                  key: const Key('terminalModeTmuxRadio'),
                  dense: true,
                  enabled: !_isSaving,
                  value: true,
                  title: Text(l10n.terminalModeTmux),
                ),
              ],
            ),
          ),
          if (_isSaving) ...[
            const SizedBox(height: 8),
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
