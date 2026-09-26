import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/terminal_url_provider.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import '../terminal/widgets/shared_terminal_canvas.dart';

Future<bool?> showInteractiveLoginDialog({
  required BuildContext context,
  required String agentName,
  required String command,
  required String serverName,
  required dynamic sshClient,
  String? remoteExecCommand,
}) {
  return showDialog<bool?>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog.fullscreen(
      child: InteractiveLoginDialog(
        agentName: agentName,
        command: command,
        serverName: serverName,
        sshClient: sshClient is SSHClient ? sshClient : null,
        remoteExecCommand: remoteExecCommand,
      ),
    ),
  );
}

class InteractiveLoginDialog extends ConsumerStatefulWidget {
  final String agentName;
  final String command;
  final String serverName;
  final SSHClient? sshClient;
  final String? remoteExecCommand;

  const InteractiveLoginDialog({
    super.key,
    required this.agentName,
    required this.command,
    required this.serverName,
    required this.sshClient,
    this.remoteExecCommand,
  });

  @override
  ConsumerState<InteractiveLoginDialog> createState() =>
      _InteractiveLoginDialogState();
}

class _InteractiveLoginDialogState
    extends ConsumerState<InteractiveLoginDialog> {
  late final Terminal _terminal;
  late TerminalSessionBridge _bridge;

  bool _isBooting = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 1500);
    _bridge = TerminalSessionBridge(
      terminal: _terminal,
      sshClient: widget.sshClient,
      serverName: widget.serverName,
      // 登录是一次性交互会话：不需要 tmux 保活，也绝不该被 tmux 探测/安装
      // 询问拖住。显式关掉，保证命令一定能在 PTY 就绪后发出去。
      preferTmux: false,
      remoteExecCommand: widget.remoteExecCommand,
    );
    _bridge.stateListenable.addListener(_onBridgeStateChanged);

    unawaited(_bootLoginSession());
  }

  void _onBridgeStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootLoginSession() async {
    if (!mounted) return;
    setState(() => _isBooting = true);

    try {
      await _bridge.start();

      if (_bridge.state != TerminalConnectionState.connected &&
          widget.sshClient != null &&
          !widget.sshClient!.isClosed) {
        final completer = Completer<void>();
        void listener() {
          if (_bridge.state == TerminalConnectionState.connected &&
              !completer.isCompleted) {
            completer.complete();
          } else if ((_bridge.state == TerminalConnectionState.disconnected ||
                  _bridge.state == TerminalConnectionState.error) &&
              !completer.isCompleted) {
            completer.complete();
          }
        }

        _bridge.stateListenable.addListener(listener);
        try {
          await completer.future.timeout(const Duration(seconds: 5));
        } catch (_) {
          // Timeout occurred; proceed to state check.
        } finally {
          _bridge.stateListenable.removeListener(listener);
        }
      }

      if (_bridge.state == TerminalConnectionState.connected) {
        if (widget.remoteExecCommand == null) {
          _bridge.sendCommand(widget.command);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isBooting = false);
      }
    }
  }

  Future<void> _reconnect() async {
    _bridge.stateListenable.removeListener(_onBridgeStateChanged);
    _bridge.dispose();

    _bridge = TerminalSessionBridge(
      terminal: _terminal,
      sshClient: widget.sshClient,
      serverName: widget.serverName,
      // 登录是一次性交互会话：不需要 tmux 保活，也绝不该被 tmux 探测/安装
      // 询问拖住。显式关掉，保证命令一定能在 PTY 就绪后发出去。
      preferTmux: false,
      remoteExecCommand: widget.remoteExecCommand,
    );
    _bridge.stateListenable.addListener(_onBridgeStateChanged);
    setState(() {});
    await _bootLoginSession();
  }

  @override
  void dispose() {
    _bridge.stateListenable.removeListener(_onBridgeStateChanged);
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisconnected =
        _bridge.state == TerminalConnectionState.disconnected ||
        _bridge.state == TerminalConnectionState.error;
    final isRunning =
        _isBooting || _bridge.state == TerminalConnectionState.connected;
    final urlState = ref.watch(terminalUrlProvider(_terminal));
    final bestUrl = urlState.best;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${context.l10n.agentLoginTerminalTitle} - ${widget.agentName}',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.agentLoginTerminalSubtitle,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('copyAllButton'),
            icon: const Icon(Icons.copy_all),
            tooltip: context.l10n.agentLoginTerminalCopyAll,
            onPressed: () async {
              final text = _bridge.readBufferText();
              final count = await _bridge.copyText(text);
              if (count > 0 && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.agentLoginTerminalCopiedAll),
                  ),
                );
              }
            },
          ),
          if (isRunning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.agentLoginTerminalRunning,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Disconnected yellow warning banner
          if (isDisconnected)
            Entrance(
              index: 0,
              child: Container(
                color: context.vWarning.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.vWarning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.agentLoginTerminalDisconnected,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.vWarning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _reconnect,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(context.l10n.agentLoginTerminalRetry),
                    ),
                  ],
                ),
              ),
            ),

          // Real Terminal View & Accessory Bar
          Expanded(
            child: SharedTerminalCanvas(
              terminal: _terminal,
              onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
                _bridge.sendKey(key, isCtrl: isCtrl, isAlt: isAlt);
              },
              onPaste: () => _bridge.pasteClipboard(),
              footer: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Detected login URL chip (shown only if bestUrl != null)
                  if (bestUrl != null)
                    Container(
                      key: const Key('loginUrlChip'),
                      color: context.colorScheme.surfaceContainerLowest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Tooltip(
                            message: context.l10n.agentLoginTerminalUrlLabel,
                            child: Icon(
                              Icons.link,
                              size: 16,
                              color: context.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: bestUrl.url,
                              child: Text(
                                bestUrl.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: monoTextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: context.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('loginUrlCopyButton'),
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: context.l10n.agentLoginTerminalUrlCopy,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () async {
                              final count = await _bridge.copyText(bestUrl.url);
                              if (count > 0 && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.agentLoginTerminalUrlCopied,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                  // No TTY / Paste hint
                  Container(
                    color: context.colorScheme.surfaceContainerLowest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.agentLoginTerminalNoTtyHint,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            color: context.colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(context.l10n.agentLoginTerminalClose),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.l10n.agentLoginTerminalFinish),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
