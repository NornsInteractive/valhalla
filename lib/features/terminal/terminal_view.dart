import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/terminal_provider.dart';
import '../../infrastructure/mosh/mosh_bridge_adapter.dart';
import '../../infrastructure/mosh/mosh_session_service.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/shared_terminal_canvas.dart';

class SshTerminalView extends ConsumerStatefulWidget {
  const SshTerminalView({super.key});

  @override
  ConsumerState<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends ConsumerState<SshTerminalView> {
  bool _dismissedTmuxMissing = false;
  bool _showSessionRestored = false;
  TerminalConnectionState? _lastBridgeState;
  TerminalSessionBridge? _lastListenedBridge;
  Timer? _sessionRestoredTimer;

  @override
  void dispose() {
    _sessionRestoredTimer?.cancel();
    _lastListenedBridge?.stateListenable.removeListener(_onBridgeStateChanged);
    super.dispose();
  }

  void _syncBridgeListener(TerminalSessionBridge? bridge) {
    if (identical(_lastListenedBridge, bridge)) return;

    _lastListenedBridge?.stateListenable.removeListener(_onBridgeStateChanged);
    _lastListenedBridge = bridge;
    _lastBridgeState = bridge?.stateListenable.value;
    bridge?.stateListenable.addListener(_onBridgeStateChanged);
  }

  void _onBridgeStateChanged() {
    final bridge = _lastListenedBridge;
    if (bridge == null) return;
    final newState = bridge.stateListenable.value;
    if (bridge.mode == TerminalSessionMode.tmux &&
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

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final activeTab = terminalState.activeTab;
    final originatingTab = activeTab;
    _syncBridgeListener(activeTab?.bridge);

    return Column(
      children: [
        _buildTabBar(terminalState),
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
                  onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
                    ref
                        .read(terminalProvider.notifier)
                        .sendKey(key, isCtrl: isCtrl, isAlt: isAlt);
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
                              constraints: const BoxConstraints(maxWidth: 520),
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
              : const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildTabBar(SshTerminalState state) {
    final notifier = ref.read(terminalProvider.notifier);

    return Container(
      color: context.colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(state.tabs.length, (index) {
                  final isSelected = state.activeTabIndex == index;
                  final tab = state.tabs[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      key: ValueKey('terminal_tab_${tab.id}'),
                      selected: isSelected,
                      label: Text(
                        tab.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      deleteButtonTooltipMessage: context.l10n.terminalCloseTab,
                      onDeleted: state.tabs.length > 1
                          ? () => notifier.closeTab(index)
                          : null,
                      onSelected: (selected) {
                        if (selected) notifier.selectTab(index);
                      },
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
