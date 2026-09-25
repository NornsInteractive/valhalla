import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../../../core/extensions/context_extensions.dart';
import 'terminal_accessory_bar.dart';

/// 共享终端渲染画布与快捷按键栏。
///
/// 供 SSH 终端、CLI 交互终端与 Agent 交互式登录终端复用：
/// 1. 包含标准的 xterm [TerminalView] 渲染与 [TerminalAccessoryBar] 按键栏；
/// 2. 保留 xterm 原生手势与长按选择行为；
/// 3. 长按或拖动选区后在画布提供复制操作；
/// 4. 支持可选的覆盖层（如 tmux 安装引导卡片或登录链接浮层）。
class SharedTerminalCanvas extends StatefulWidget {
  final Terminal terminal;
  final void Function(String key, {bool isCtrl, bool isAlt}) onKey;
  final Future<void> Function() onPaste;
  final bool? isCtrlActive;
  final bool? isAltActive;
  final VoidCallback? onToggleCtrl;
  final VoidCallback? onToggleAlt;
  final Widget? overlay;
  final Widget? footer;
  final bool showAccessoryBar;
  final Color? backgroundColor;
  final TerminalStyle? textStyle;
  final EdgeInsets? padding;
  final TerminalController? controller;

  const SharedTerminalCanvas({
    super.key,
    required this.terminal,
    required this.onKey,
    required this.onPaste,
    this.isCtrlActive,
    this.isAltActive,
    this.onToggleCtrl,
    this.onToggleAlt,
    this.overlay,
    this.footer,
    this.showAccessoryBar = true,
    this.backgroundColor,
    this.textStyle,
    this.padding,
    this.controller,
  });

  @override
  State<SharedTerminalCanvas> createState() => _SharedTerminalCanvasState();
}

class _SharedTerminalCanvasState extends State<SharedTerminalCanvas> {
  bool _localCtrl = false;
  bool _localAlt = false;
  late TerminalController _controller;
  bool _ownsController = false;
  bool _hasSelection = false;

  bool get _effectiveCtrl => widget.isCtrlActive ?? _localCtrl;
  bool get _effectiveAlt => widget.isAltActive ?? _localAlt;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = TerminalController();
      _ownsController = true;
    }
    _controller.addListener(_onControllerChanged);
    _hasSelection = _controller.selection != null;
  }

  @override
  void didUpdateWidget(SharedTerminalCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    final hasSel = _controller.selection != null;
    if (hasSel != _hasSelection) {
      setState(() {
        _hasSelection = hasSel;
      });
    }
  }

  Future<void> _copySelection() async {
    final selection = _controller.selection;
    if (selection == null) return;
    final text = widget.terminal.buffer.getText(selection);
    _controller.clearSelection();
    if (text.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.terminalSelectionCopied),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                color: widget.backgroundColor ?? Colors.black,
                child: TerminalView(
                  widget.terminal,
                  controller: _controller,
                  textStyle:
                      widget.textStyle ??
                      const TerminalStyle(
                        fontSize: 13,
                        fontFamily: 'JetBrains Mono',
                      ),
                  padding: widget.padding ?? const EdgeInsets.all(8),
                ),
              ),
              if (_hasSelection)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            key: const Key('terminal_copy_selection_button'),
                            onPressed: _copySelection,
                            icon: const Icon(Icons.copy, size: 14),
                            label: Text(
                              context.l10n.terminalCopySelection,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('terminal_clear_selection_button'),
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () => _controller.clearSelection(),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.overlay != null) widget.overlay!,
            ],
          ),
        ),
        if (widget.footer != null) widget.footer!,
        if (widget.showAccessoryBar)
          TerminalAccessoryBar(
            onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
              widget.onKey(
                key,
                isCtrl: isCtrl || _effectiveCtrl,
                isAlt: isAlt || _effectiveAlt,
              );
            },
            onToggleCtrl:
                widget.onToggleCtrl ??
                () {
                  setState(() => _localCtrl = !_localCtrl);
                },
            onToggleAlt:
                widget.onToggleAlt ??
                () {
                  setState(() => _localAlt = !_localAlt);
                },
            onPaste: () => widget.onPaste(),
            isCtrlActive: _effectiveCtrl,
            isAltActive: _effectiveAlt,
          ),
      ],
    );
  }
}
