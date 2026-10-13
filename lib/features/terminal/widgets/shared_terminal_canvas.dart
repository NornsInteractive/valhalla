import 'dart:async';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/terminal_settings_provider.dart';
import '../../../core/utils/terminal_keys.dart';
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
/// 7. 拥有并管理单次生效 (one-shot)、按住 (held) 与长按锁定 (locked) 的
///    Ctrl/Alt/Shift/Fn 修饰键状态，通过 [TerminalView.onTextInput] 与
///    [TerminalView.onKeyEvent] 统一经 [_handleKey] 编码发出并消耗单次修饰键。
class SharedTerminalCanvas extends ConsumerStatefulWidget {
  final Terminal terminal;
  final void Function(String key, {bool isCtrl, bool isAlt, bool isShift})
  onKey;
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

class _SharedTerminalCanvasState extends ConsumerState<SharedTerminalCanvas>
    with WidgetsBindingObserver {
  static final Map<LogicalKeyboardKey, String> _specialKeys = {
    LogicalKeyboardKey.escape: 'ESC',
    LogicalKeyboardKey.tab: 'TAB',
    LogicalKeyboardKey.enter: 'ENTER',
    LogicalKeyboardKey.numpadEnter: 'ENTER',
    LogicalKeyboardKey.backspace: 'BACKSPACE',
    LogicalKeyboardKey.delete: 'DELETE',
    LogicalKeyboardKey.insert: 'INSERT',
    LogicalKeyboardKey.home: 'HOME',
    LogicalKeyboardKey.end: 'END',
    LogicalKeyboardKey.pageUp: 'PGUP',
    LogicalKeyboardKey.pageDown: 'PGDN',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };

  static final Map<LogicalKeyboardKey, String> _fnDigitKeys = {
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad9: '9',
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.minus: '-',
    LogicalKeyboardKey.numpadSubtract: '-',
    LogicalKeyboardKey.equal: '=',
    LogicalKeyboardKey.numpadAdd: '=',
  };

  final GlobalKey<TerminalViewState> _terminalViewKey =
      GlobalKey<TerminalViewState>();

  final Map<String, ModifierLockState> _modifierStates = {
    'CTRL': ModifierLockState.inactive,
    'ALT': ModifierLockState.inactive,
    'SHIFT': ModifierLockState.inactive,
    'FN': ModifierLockState.inactive,
  };

  final Map<String, bool> _modifierHeld = {
    'CTRL': false,
    'ALT': false,
    'SHIFT': false,
    'FN': false,
  };

  final Map<String, bool> _modifierChordUsed = {
    'CTRL': false,
    'ALT': false,
    'SHIFT': false,
    'FN': false,
  };

  final Map<String, bool> _modifierExceededLongPress = {
    'CTRL': false,
    'ALT': false,
    'SHIFT': false,
    'FN': false,
  };

  final Map<String, Timer?> _modifierTimers = {
    'CTRL': null,
    'ALT': null,
    'SHIFT': null,
    'FN': null,
  };

  int _terminalEpoch = 0;
  final Map<String, int> _modifierDownEpoch = {
    'CTRL': 0,
    'ALT': 0,
    'SHIFT': 0,
    'FN': 0,
  };

  late TerminalController _controller;
  bool _ownsController = false;
  bool _hasSelection = false;
  FocusNode? _ownedFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  bool get _hasActiveModifier => _modifierStates.keys.any(
    (mod) =>
        _modifierHeld[mod]! ||
        _modifierStates[mod] != ModifierLockState.inactive,
  );

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

  void _resetModifiers() {
    _terminalEpoch++;
    for (final timer in _modifierTimers.values) {
      timer?.cancel();
    }
    for (final mod in _modifierStates.keys) {
      _modifierStates[mod] = ModifierLockState.inactive;
      _modifierHeld[mod] = false;
      _modifierChordUsed[mod] = false;
      _modifierExceededLongPress[mod] = false;
      _modifierTimers[mod] = null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveFocusNode.addListener(_onFocusChanged);
    if (widget.isCtrlActive == true) {
      _modifierStates['CTRL'] = ModifierLockState.oneShot;
    }
    if (widget.isAltActive == true) {
      _modifierStates['ALT'] = ModifierLockState.oneShot;
    }
    _initController();
  }

  void _onFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _resetModifiers();
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _resetModifiers();
      setState(() {});
    }
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
      _resetModifiers();
      setState(() {});
    }
    if (oldWidget.focusNode != widget.focusNode) {
      final oldEffective = oldWidget.focusNode ?? _ownedFocusNode;
      oldEffective?.removeListener(_onFocusChanged);
      if (widget.focusNode != null && _ownedFocusNode != null) {
        _ownedFocusNode!.dispose();
        _ownedFocusNode = null;
      }
      _effectiveFocusNode.addListener(_onFocusChanged);
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
    _effectiveFocusNode.removeListener(_onFocusChanged);
    _ownedFocusNode?.dispose();
    _ownedFocusNode = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _modifierTimers.values) {
      timer?.cancel();
    }
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

  void _handleModifierDown(String modifier) {
    _modifierTimers[modifier]?.cancel();
    _modifierHeld[modifier] = true;
    _modifierChordUsed[modifier] = false;
    _modifierExceededLongPress[modifier] = false;
    _modifierDownEpoch[modifier] = _terminalEpoch;
    _modifierTimers[modifier] = Timer(const Duration(milliseconds: 500), () {
      _modifierExceededLongPress[modifier] = true;
    });
    setState(() {});
  }

  void _handleModifierUp(String modifier) {
    _modifierTimers[modifier]?.cancel();
    _modifierHeld[modifier] = false;
    if (_modifierDownEpoch[modifier] != _terminalEpoch) {
      setState(() {});
      return;
    }
    if (_modifierChordUsed[modifier] == true) {
      // Releasing after chord clears held state without re-arming or locking
    } else if (_modifierExceededLongPress[modifier] == true) {
      HapticFeedback.heavyImpact();
      _modifierStates[modifier] = ModifierLockState.locked;
    } else {
      _modifierStates[modifier] =
          _modifierStates[modifier] == ModifierLockState.inactive
          ? ModifierLockState.oneShot
          : ModifierLockState.inactive;
    }
    setState(() {});
  }

  void _handleModifierCancel(String modifier) {
    _modifierTimers[modifier]?.cancel();
    _modifierHeld[modifier] = false;
    _modifierChordUsed[modifier] = false;
    _modifierExceededLongPress[modifier] = false;
    setState(() {});
  }

  void _toggleModifier(String modifier) {
    _modifierTimers[modifier]?.cancel();
    setState(() {
      _modifierStates[modifier] =
          _modifierStates[modifier] == ModifierLockState.inactive
          ? ModifierLockState.oneShot
          : ModifierLockState.inactive;
    });
  }

  void _lockModifier(String modifier) {
    _modifierTimers[modifier]?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _modifierStates[modifier] = ModifierLockState.locked;
    });
  }

  void _handleKey(
    String key, {
    bool isCtrl = false,
    bool isAlt = false,
    bool isShift = false,
  }) {
    final effectiveFn =
        _modifierHeld['FN']! ||
        _modifierStates['FN']! != ModifierLockState.inactive;
    final mappedKey = effectiveFn ? terminalFnKey(key) : key;

    final effectiveCtrl =
        isCtrl ||
        _modifierHeld['CTRL']! ||
        _modifierStates['CTRL']! != ModifierLockState.inactive;
    final effectiveAlt =
        isAlt ||
        _modifierHeld['ALT']! ||
        _modifierStates['ALT']! != ModifierLockState.inactive;
    final effectiveShift =
        isShift ||
        _modifierHeld['SHIFT']! ||
        _modifierStates['SHIFT']! != ModifierLockState.inactive;

    for (final mod in _modifierHeld.keys) {
      if (_modifierHeld[mod]!) {
        _modifierChordUsed[mod] = true;
        _modifierTimers[mod]?.cancel();
      }
    }

    widget.onKey(
      mappedKey,
      isCtrl: effectiveCtrl,
      isAlt: effectiveAlt,
      isShift: effectiveShift,
    );

    var changed = false;
    for (final mod in _modifierStates.keys) {
      if (_modifierStates[mod] == ModifierLockState.oneShot) {
        _modifierStates[mod] = ModifierLockState.inactive;
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
    }
  }

  bool _handleTextInput(String text) {
    if (!_hasActiveModifier) {
      return false;
    }

    if (text == '\b') {
      _handleKey('BACKSPACE');
      return true;
    }

    if (text == '\r' || text == '\n') {
      _handleKey('ENTER');
      return true;
    }

    if (text == '\t') {
      _handleKey('TAB');
      return true;
    }

    if (text.length == 1) {
      final code = text.codeUnitAt(0);
      if (code >= 32 && code <= 126) {
        _handleKey(text);
        return true;
      }
    }

    return false;
  }

  KeyEventResult _handlePhysicalKeyEvent(FocusNode focusNode, KeyEvent event) {
    if (!_hasActiveModifier) {
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final logicalKey = event.logicalKey;
    if (logicalKey == LogicalKeyboardKey.controlLeft ||
        logicalKey == LogicalKeyboardKey.controlRight ||
        logicalKey == LogicalKeyboardKey.shiftLeft ||
        logicalKey == LogicalKeyboardKey.shiftRight ||
        logicalKey == LogicalKeyboardKey.altLeft ||
        logicalKey == LogicalKeyboardKey.altRight ||
        logicalKey == LogicalKeyboardKey.metaLeft ||
        logicalKey == LogicalKeyboardKey.metaRight) {
      return KeyEventResult.ignored;
    }

    if (HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final physCtrl = HardwareKeyboard.instance.isControlPressed;
    final physAlt = HardwareKeyboard.instance.isAltPressed;
    final physShift = HardwareKeyboard.instance.isShiftPressed;

    final isApple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isApple) {
      // Preserve local copy shortcut: non-Apple physical Ctrl+Shift+C without Alt
      if (logicalKey == LogicalKeyboardKey.keyC &&
          physCtrl &&
          physShift &&
          !physAlt) {
        return KeyEventResult.ignored;
      }
      // Preserve local paste shortcut: non-Apple physical Ctrl+V without Shift/Alt
      if (logicalKey == LogicalKeyboardKey.keyV &&
          physCtrl &&
          !physShift &&
          !physAlt) {
        return KeyEventResult.ignored;
      }
    }

    String? keyName = _specialKeys[logicalKey];

    final hasLocalFn =
        _modifierHeld['FN']! ||
        _modifierStates['FN']! != ModifierLockState.inactive;
    if (hasLocalFn && keyName == null) {
      keyName = _fnDigitKeys[logicalKey];
    }

    if (keyName == null) {
      final char = event.character;
      if (char != null && char.length == 1) {
        final code = char.codeUnitAt(0);
        if (code >= 32 && code <= 126) {
          keyName = char;
        }
      }
    }

    if (keyName == null) {
      final char = event.character;
      final isNonAscii =
          char != null && char.isNotEmpty && char.codeUnits.any((c) => c > 127);
      if (!isNonAscii) {
        final label = event.logicalKey.keyLabel;
        if (label.length == 1) {
          final labelCode = label.codeUnitAt(0);
          if (labelCode >= 32 && labelCode <= 126) {
            keyName = (labelCode >= 65 && labelCode <= 90 && !physShift)
                ? label.toLowerCase()
                : label;
          }
        }
      }
    }

    if (keyName == null) {
      return KeyEventResult.ignored;
    }

    _handleKey(keyName, isCtrl: physCtrl, isAlt: physAlt, isShift: physShift);
    return KeyEventResult.handled;
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
                  focusNode: _effectiveFocusNode,
                  autofocus: widget.autofocus,
                  requestKeyboardOnTap: widget.requestKeyboardOnTap,
                  onPasteText: _handlePasteText,
                  onTextInput: _handleTextInput,
                  onKeyEvent: _handlePhysicalKeyEvent,
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
              onToggleCtrl: () => _toggleModifier('CTRL'),
              onLockCtrl: () => _lockModifier('CTRL'),
              onToggleAlt: () => _toggleModifier('ALT'),
              onLockAlt: () => _lockModifier('ALT'),
              onToggleShift: () => _toggleModifier('SHIFT'),
              onLockShift: () => _lockModifier('SHIFT'),
              onToggleFn: () => _toggleModifier('FN'),
              onLockFn: () => _lockModifier('FN'),
              onModifierDown: _handleModifierDown,
              onModifierUp: _handleModifierUp,
              onModifierCancel: _handleModifierCancel,
              onPaste: () => _handlePasteText(),
              onToggleKeyboard: _toggleKeyboard,
              ctrlState: _modifierStates['CTRL'],
              altState: _modifierStates['ALT'],
              shiftState: _modifierStates['SHIFT'],
              fnState: _modifierStates['FN'],
              isCtrlHeld: _modifierHeld['CTRL']!,
              isAltHeld: _modifierHeld['ALT']!,
              isShiftHeld: _modifierHeld['SHIFT']!,
              isFnHeld: _modifierHeld['FN']!,
              pinKeyboardButtonTrailing: widget.pinKeyboardButtonTrailing,
            ),
          ),
      ],
    );
  }
}
