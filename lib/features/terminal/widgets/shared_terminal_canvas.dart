import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/terminal_settings_provider.dart';
import 'terminal_accessory_bar.dart';

/// 共享终端渲染画布与快捷按键栏。
///
/// 供 SSH 终端、CLI 交互终端与 Agent 交互式登录终端复用：
/// 1. 包含标准的 xterm [TerminalView] 渲染与 [TerminalAccessoryBar] 按键栏；
/// 2. 保留 xterm 原生手势与长按选择行为；
/// 3. 长按或拖动选区后在画布提供复制操作；
/// 4. 支持可选的覆盖层（如 tmux 安装引导卡片或登录链接浮层）；
/// 5. 未显式传 [textStyle] 时，字号跟随 `terminalSettingsProvider` 实时生效；
/// 6. 统一接管物理 Ctrl+V 与按键栏 PASTE 的多行粘贴确认及 TOCTOU 保护，
///    在任何 await 前捕获目标终端与回调，切换终端或卸载时果断放弃；
/// 7. 拥有并管理单次生效 (one-shot) 与长按锁定 (locked) 的 Ctrl/Alt 修饰键状态，
///    移动端虚拟键盘输入字符通过 [TerminalView.onTextInput] 统一经 [_handleKey]
///    编码发出并消耗单次修饰键，未激活修饰键时不影响普通输入与 CJK 组合。
class SharedTerminalCanvas extends ConsumerStatefulWidget {
  final Terminal terminal;
  final void Function(String key, {bool isCtrl, bool isAlt}) onKey;
  final Future<void> Function()? onPaste;
  final void Function(String text)? onPasteText;
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
  final FocusNode? focusNode;
  final bool autofocus;
  final bool requestKeyboardOnTap;
  final bool pinKeyboardButtonTrailing;

  const SharedTerminalCanvas({
    super.key,
    required this.terminal,
    required this.onKey,
    this.onPaste,
    this.onPasteText,
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
    this.focusNode,
    this.autofocus = false,
    this.requestKeyboardOnTap = true,
    this.pinKeyboardButtonTrailing = false,
  });

  @override
  ConsumerState<SharedTerminalCanvas> createState() =>
      _SharedTerminalCanvasState();
}

class _SharedTerminalCanvasState extends ConsumerState<SharedTerminalCanvas> {
  final GlobalKey<TerminalViewState> _terminalViewKey =
      GlobalKey<TerminalViewState>();
  ModifierLockState _ctrlState = ModifierLockState.inactive;
  ModifierLockState _altState = ModifierLockState.inactive;
  late TerminalController _controller;
  bool _ownsController = false;
  bool _hasSelection = false;

  void requestKeyboard() {
    _terminalViewKey.currentState?.requestKeyboard();
  }

  void closeKeyboard() {
    _terminalViewKey.currentState?.closeKeyboard();
  }

  void _toggleKeyboard() {
    final currentState = _terminalViewKey.currentState;
    if (currentState != null) {
      if (currentState.hasInputConnection) {
        currentState.closeKeyboard();
      } else {
        currentState.requestKeyboard();
      }
    }
  }

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
    if (oldWidget.terminal != widget.terminal) {
      if (_hasSelection) {
        _controller.clearSelection();
        _hasSelection = false;
      }
      // 终端实例切换时立即重置本地修饰键状态，防止修饰键残留污染新的会话。
      if (_ctrlState != ModifierLockState.inactive ||
          _altState != ModifierLockState.inactive) {
        setState(() {
          _ctrlState = ModifierLockState.inactive;
          _altState = ModifierLockState.inactive;
        });
      }
    }
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

  void _toggleCtrl() {
    setState(() {
      if (_ctrlState == ModifierLockState.inactive) {
        _ctrlState = ModifierLockState.oneShot;
      } else {
        _ctrlState = ModifierLockState.inactive;
      }
    });
  }

  void _lockCtrl() {
    HapticFeedback.heavyImpact();
    setState(() {
      _ctrlState = ModifierLockState.locked;
    });
  }

  void _toggleAlt() {
    setState(() {
      if (_altState == ModifierLockState.inactive) {
        _altState = ModifierLockState.oneShot;
      } else {
        _altState = ModifierLockState.inactive;
      }
    });
  }

  void _lockAlt() {
    HapticFeedback.heavyImpact();
    setState(() {
      _altState = ModifierLockState.locked;
    });
  }

  void _handleKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    final effectiveCtrl = isCtrl || _ctrlState != ModifierLockState.inactive;
    final effectiveAlt = isAlt || _altState != ModifierLockState.inactive;

    widget.onKey(key, isCtrl: effectiveCtrl, isAlt: effectiveAlt);

    var changed = false;
    if (_ctrlState == ModifierLockState.oneShot) {
      _ctrlState = ModifierLockState.inactive;
      changed = true;
    }
    if (_altState == ModifierLockState.oneShot) {
      _altState = ModifierLockState.inactive;
      changed = true;
    }
    if (changed) {
      setState(() {});
    }
  }

  /// 移动端虚拟键盘 / IME 文本输入钩子。
  ///
  /// 当激活了本地 Ctrl 或 Alt 修饰键时，将单字符输入转交给 [_handleKey] 处理，
  /// 发射对应的修饰组合序列并消耗单次 (one-shot) 状态；
  /// 当未激活修饰键时返回 false，完全保留终端默认行为与 CJK 组合态。
  bool _handleTextInput(String text) {
    final hasActiveModifier =
        _ctrlState != ModifierLockState.inactive ||
        _altState != ModifierLockState.inactive;

    if (!hasActiveModifier) {
      return false;
    }

    if (text.runes.length == 1) {
      _handleKey(text);
      return true;
    }

    return false;
  }

  Future<void> _handlePasteText([String? incomingText]) async {
    // 在任何异步等待前固化原始目标终端与回调
    final targetTerminal = widget.terminal;
    final targetOnPasteText = widget.onPasteText;

    final text =
        incomingText ?? (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) return;
    if (!mounted || widget.terminal != targetTerminal) return;

    final isMultiLine = text.contains('\n') || text.contains('\r');
    if (isMultiLine) {
      final confirmed = await _showConfirmPasteDialog(text);
      if (confirmed != true || !mounted || widget.terminal != targetTerminal) {
        return;
      }
    }

    // 确认后只发送确切确认的文本，严禁重新通过 legacy onPaste 读取剪贴板
    if (targetOnPasteText != null) {
      targetOnPasteText(text);
    } else {
      targetTerminal.paste(text);
    }
  }

  Future<bool?> _showConfirmPasteDialog(String text) {
    final lineCount = '\n'.allMatches(text).length + 1;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.terminalConfirmPasteTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.terminalConfirmPasteMessage(lineCount)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: monoTextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('terminal_confirm_paste_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.terminalPaste),
          ),
        ],
      ),
    );
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
    // 叶子节点 watch 字号：设置里拖动滑块时画布直接重渲染，不惊动
    // Terminal 状态与桥接层；PTY 尺寸由 TerminalView 的 onResize 自动跟进。
    final fontSize = ref.watch(terminalSettingsProvider).fontSize;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                color: widget.backgroundColor ?? Colors.black,
                child: TerminalView(
                  key: _terminalViewKey,
                  widget.terminal,
                  controller: _controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  requestKeyboardOnTap: widget.requestKeyboardOnTap,
                  onPasteText: _handlePasteText,
                  onTextInput: _handleTextInput,
                  textStyle:
                      widget.textStyle ??
                      TerminalStyle(
                        fontSize: fontSize.toDouble(),
                        fontFamily: 'JetBrains Mono',
                      ),
                  padding: widget.padding ?? const EdgeInsets.all(8),
                ),
              ),
              if (_hasSelection)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ExcludeFocus(
                    excluding: true,
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
                ),
              if (widget.overlay != null) widget.overlay!,
            ],
          ),
        ),
        if (widget.footer != null) widget.footer!,
        if (widget.showAccessoryBar)
          ExcludeFocus(
            excluding: true,
            child: TerminalAccessoryBar(
              onKey: _handleKey,
              onToggleCtrl: _toggleCtrl,
              onLockCtrl: _lockCtrl,
              onToggleAlt: _toggleAlt,
              onLockAlt: _lockAlt,
              onPaste: () => _handlePasteText(),
              onToggleKeyboard: _toggleKeyboard,
              ctrlState: _ctrlState,
              altState: _altState,
              pinKeyboardButtonTrailing: widget.pinKeyboardButtonTrailing,
            ),
          ),
      ],
    );
  }
}
