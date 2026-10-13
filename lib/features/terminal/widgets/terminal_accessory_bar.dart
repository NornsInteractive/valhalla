import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/terminal_settings_provider.dart';
import 'customize_pinned_keys_dialog.dart';

enum ModifierLockState { inactive, oneShot, locked }

/// Helper widget that repeats invoking [onPressed] while held down.
/// Cancels cleanly on pointer up, pointer cancel, or disposal.
class HoldRepeatKey extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const HoldRepeatKey({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  State<HoldRepeatKey> createState() => _HoldRepeatKeyState();
}

class _HoldRepeatKeyState extends State<HoldRepeatKey> {
  Timer? _initialTimer;
  Timer? _repeatTimer;

  void _start() {
    _cancel();
    widget.onPressed();
    _initialTimer = Timer(const Duration(milliseconds: 350), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        if (mounted) {
          widget.onPressed();
        }
      });
    });
  }

  void _cancel() {
    _initialTimer?.cancel();
    _initialTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: widget.child,
    );
  }
}

enum _ExpandedCategory { nav, edit, symbols, fn }

class TerminalAccessoryBar extends ConsumerStatefulWidget {
  final void Function(String key, {bool isCtrl, bool isAlt, bool isShift})
  onKey;
  final VoidCallback onToggleCtrl;
  final VoidCallback? onLockCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback? onLockAlt;
  final VoidCallback? onToggleShift;
  final VoidCallback? onLockShift;
  final VoidCallback? onToggleFn;
  final VoidCallback? onLockFn;
  final void Function(String modifier)? onModifierDown;
  final void Function(String modifier)? onModifierUp;
  final void Function(String modifier)? onModifierCancel;
  final VoidCallback onPaste;
  final VoidCallback? onToggleKeyboard;
  final ModifierLockState? ctrlState;
  final ModifierLockState? altState;
  final ModifierLockState? shiftState;
  final ModifierLockState? fnState;
  final bool isCtrlActive;
  final bool isAltActive;
  final bool isCtrlHeld;
  final bool isAltHeld;
  final bool isShiftHeld;
  final bool isFnHeld;
  final bool pinKeyboardButtonTrailing;

  const TerminalAccessoryBar({
    super.key,
    required this.onKey,
    required this.onToggleCtrl,
    this.onLockCtrl,
    required this.onToggleAlt,
    this.onLockAlt,
    this.onToggleShift,
    this.onLockShift,
    this.onToggleFn,
    this.onLockFn,
    this.onModifierDown,
    this.onModifierUp,
    this.onModifierCancel,
    required this.onPaste,
    this.onToggleKeyboard,
    this.ctrlState,
    this.altState,
    this.shiftState,
    this.fnState,
    this.isCtrlActive = false,
    this.isAltActive = false,
    this.isCtrlHeld = false,
    this.isAltHeld = false,
    this.isShiftHeld = false,
    this.isFnHeld = false,
    this.pinKeyboardButtonTrailing = false,
  });

  @override
  ConsumerState<TerminalAccessoryBar> createState() =>
      _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends ConsumerState<TerminalAccessoryBar> {
  bool _isExpanded = false;
  _ExpandedCategory _activeCategory = _ExpandedCategory.nav;

  ModifierLockState get _effectiveCtrlState =>
      widget.ctrlState ??
      (widget.isCtrlActive
          ? ModifierLockState.oneShot
          : ModifierLockState.inactive);

  ModifierLockState get _effectiveAltState =>
      widget.altState ??
      (widget.isAltActive
          ? ModifierLockState.oneShot
          : ModifierLockState.inactive);

  ModifierLockState get _effectiveShiftState =>
      widget.shiftState ?? ModifierLockState.inactive;

  ModifierLockState get _effectiveFnState =>
      widget.fnState ?? ModifierLockState.inactive;

  void _handleKey(String key) {
    if (key.startsWith('Ctrl+')) {
      final chord = key.substring(5);
      widget.onKey(chord, isCtrl: true);
    } else {
      widget.onKey(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinnedKeys = ref.watch(terminalSettingsProvider).pinnedKeys;
    final showFnHint =
        _effectiveFnState != ModifierLockState.inactive || widget.isFnHeld;

    return Container(
      color: context.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFnHint)
              Container(
                key: const Key('terminal_fn_hint_row'),
                color: context.colorScheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                child: Text(
                  '1..0,-,= → F1..F12  •  ←↑↓→ → Home/PgUp/PgDn/End  •  ⌫ → Del',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono',
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_isExpanded) _buildExpandedPanel(context),
            // Pinned accessory keys row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (!widget.pinKeyboardButtonTrailing &&
                              widget.onToggleKeyboard != null)
                            _buildKeyboardButton(context),
                          ...pinnedKeys.map(
                            (key) => _buildPinnedKey(context, key),
                          ),
                          _buildMoreButton(context),
                        ],
                      ),
                    ),
                  ),
                  if (widget.pinKeyboardButtonTrailing &&
                      widget.onToggleKeyboard != null) ...[
                    const SizedBox(width: 4),
                    _buildKeyboardButton(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardButton(BuildContext context) {
    final tooltipText = context.l10n.terminalToggleKeyboard;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: Tooltip(
          message: tooltipText,
          child: Semantics(
            button: true,
            label: tooltipText,
            child: FilledButton.tonal(
              key: const Key('terminal_accessory_keyboard_button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: widget.onToggleKeyboard,
              child: const Icon(Icons.keyboard, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: FilledButton.tonal(
          key: const Key('terminal_accessory_more_button'),
          style: FilledButton.styleFrom(
            backgroundColor: _isExpanded
                ? context.colorScheme.primaryContainer
                : null,
            foregroundColor: _isExpanded
                ? context.colorScheme.onPrimaryContainer
                : null,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          child: Icon(
            _isExpanded ? Icons.expand_more : Icons.more_horiz,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedKey(
    BuildContext context,
    String key, {
    bool isExpanded = false,
  }) {
    if (key == 'CTRL') {
      return _buildModifierKey(
        context,
        label: 'CTRL',
        state: _effectiveCtrlState,
        isHeld: widget.isCtrlHeld,
        onTap: widget.onToggleCtrl,
        onLongPress: widget.onLockCtrl ?? widget.onToggleCtrl,
        isExpanded: isExpanded,
        tooltip: _effectiveCtrlState == ModifierLockState.locked
            ? 'Ctrl (Locked)'
            : (widget.isCtrlHeld
                  ? 'Ctrl (Held)'
                  : (_effectiveCtrlState == ModifierLockState.oneShot
                        ? 'Ctrl (One-shot active)'
                        : 'Ctrl (Tap once, Long press to lock)')),
      );
    }
    if (key == 'ALT') {
      return _buildModifierKey(
        context,
        label: 'ALT',
        state: _effectiveAltState,
        isHeld: widget.isAltHeld,
        onTap: widget.onToggleAlt,
        onLongPress: widget.onLockAlt ?? widget.onToggleAlt,
        isExpanded: isExpanded,
        tooltip: _effectiveAltState == ModifierLockState.locked
            ? 'Alt (Locked)'
            : (widget.isAltHeld
                  ? 'Alt (Held)'
                  : (_effectiveAltState == ModifierLockState.oneShot
                        ? 'Alt (One-shot active)'
                        : 'Alt (Tap once, Long press to lock)')),
      );
    }
    if (key == 'SHIFT') {
      return _buildModifierKey(
        context,
        label: 'SHIFT',
        state: _effectiveShiftState,
        isHeld: widget.isShiftHeld,
        onTap: widget.onToggleShift ?? () {},
        onLongPress: widget.onLockShift ?? widget.onToggleShift ?? () {},
        isExpanded: isExpanded,
        tooltip: _effectiveShiftState == ModifierLockState.locked
            ? 'Shift (Locked)'
            : (widget.isShiftHeld
                  ? 'Shift (Held)'
                  : (_effectiveShiftState == ModifierLockState.oneShot
                        ? 'Shift (One-shot active)'
                        : 'Shift (Tap once, Long press to lock)')),
      );
    }
    if (key == 'FN') {
      const fnMapHint =
          '1..0,-,= → F1..F12 • ←↑↓→ → Home/PgUp/PgDn/End • ⌫ → Del';
      return _buildModifierKey(
        context,
        label: 'FN',
        state: _effectiveFnState,
        isHeld: widget.isFnHeld,
        onTap: widget.onToggleFn ?? () {},
        onLongPress: widget.onLockFn ?? widget.onToggleFn ?? () {},
        isExpanded: isExpanded,
        tooltip: _effectiveFnState == ModifierLockState.locked
            ? 'Fn (Locked)\n$fnMapHint'
            : (widget.isFnHeld
                  ? 'Fn (Held)\n$fnMapHint'
                  : (_effectiveFnState == ModifierLockState.oneShot
                        ? 'Fn (One-shot active)\n$fnMapHint'
                        : 'Fn (Tap once, Long press to lock)\n$fnMapHint')),
      );
    }
    if (key == 'PASTE') {
      return _buildKey(
        context,
        'PASTE',
        icon: Icons.content_paste,
        onPressed: widget.onPaste,
      );
    }
    return _buildKey(context, key, onPressed: () => _handleKey(key));
  }

  Widget _buildModifierKey(
    BuildContext context, {
    required String label,
    required ModifierLockState state,
    required bool isHeld,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required String tooltip,
    bool isExpanded = false,
  }) {
    final pinnedKeys = ref.watch(terminalSettingsProvider).pinnedKeys;
    final keyFinderKey = isExpanded && pinnedKeys.contains(label)
        ? Key('terminal_accessory_expanded_key_$label')
        : Key('terminal_accessory_key_$label');

    return _ModifierKeyButton(
      label: label,
      state: state,
      isHeld: isHeld,
      onTap: onTap,
      onLongPress: onLongPress,
      onModifierDown: widget.onModifierDown,
      onModifierUp: widget.onModifierUp,
      onModifierCancel: widget.onModifierCancel,
      tooltip: tooltip,
      buttonKey: keyFinderKey,
    );
  }

  Widget _buildKey(
    BuildContext context,
    String label, {
    IconData? icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final isArrow =
        label == '↑' || label == '↓' || label == '←' || label == '→';

    final btn = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: FilledButton.tonal(
          key: Key('terminal_accessory_key_$label'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: isArrow ? () {} : onPressed,
          child: icon != null
              ? Icon(icon, size: 16)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
        ),
      ),
    );

    final interactive = isArrow
        ? HoldRepeatKey(onPressed: onPressed, child: btn)
        : btn;

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: interactive);
    }
    return interactive;
  }

  Widget _buildExpandedPanel(BuildContext context) {
    final pinnedKeys = ref.watch(terminalSettingsProvider).pinnedKeys;
    final missingModifiers = const [
      'CTRL',
      'SHIFT',
      'ALT',
      'FN',
    ].where((mod) => !pinnedKeys.contains(mod)).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryTab(context, 'Nav', _ExpandedCategory.nav),
                      _buildCategoryTab(
                        context,
                        'Edit',
                        _ExpandedCategory.edit,
                      ),
                      _buildCategoryTab(
                        context,
                        'Sym',
                        _ExpandedCategory.symbols,
                      ),
                      _buildCategoryTab(context, 'Fn', _ExpandedCategory.fn),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune, size: 20),
                tooltip: context.l10n.settingsTerminalPinnedKeys,
                onPressed: () => CustomizePinnedKeysDialog.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          ),
          if (missingModifiers.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Expanded panel modifier row: shows ONLY modifiers absent from pinnedKeys.
            // Pinned and expanded duplicate controls share one held boolean which could cause
            // premature release/rearm under multi-touch; showing only missing modifiers avoids
            // duplicates while keeping all four modifiers accessible without an extra pointer counter.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: missingModifiers
                    .map(
                      (mod) => _buildPinnedKey(context, mod, isExpanded: true),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _buildCategoryKeys(context, _activeCategory)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(
    BuildContext context,
    String label,
    _ExpandedCategory category,
  ) {
    final isSelected = _activeCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        onSelected: (val) {
          if (val) {
            setState(() => _activeCategory = category);
          }
        },
      ),
    );
  }

  List<Widget> _buildCategoryKeys(
    BuildContext context,
    _ExpandedCategory category,
  ) {
    final keys = switch (category) {
      _ExpandedCategory.nav => const [
        '↑',
        '↓',
        '←',
        '→',
        'HOME',
        'END',
        'PGUP',
        'PGDN',
      ],
      _ExpandedCategory.edit => const [
        'INSERT',
        'DELETE',
        'BACKSPACE',
        'ENTER',
        'Ctrl+C',
        'Ctrl+D',
        'Ctrl+A',
        'Ctrl+E',
        'Ctrl+U',
        'Ctrl+K',
        'Ctrl+W',
        'Ctrl+R',
        'Ctrl+Z',
      ],
      _ExpandedCategory.symbols => const [
        '/',
        '-',
        '_',
        '|',
        '~',
        '.',
        ':',
        '=',
      ],
      _ExpandedCategory.fn => const [
        'F1',
        'F2',
        'F3',
        'F4',
        'F5',
        'F6',
        'F7',
        'F8',
        'F9',
        'F10',
        'F11',
        'F12',
      ],
    };

    return keys.map((key) {
      return _buildKey(context, key, onPressed: () => _handleKey(key));
    }).toList();
  }
}

class _ModifierKeyButton extends StatefulWidget {
  final String label;
  final ModifierLockState state;
  final bool isHeld;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String modifier)? onModifierDown;
  final void Function(String modifier)? onModifierUp;
  final void Function(String modifier)? onModifierCancel;
  final String tooltip;
  final Key? buttonKey;

  const _ModifierKeyButton({
    required this.label,
    required this.state,
    required this.isHeld,
    required this.onTap,
    required this.onLongPress,
    this.onModifierDown,
    this.onModifierUp,
    this.onModifierCancel,
    required this.tooltip,
    this.buttonKey,
  });

  @override
  State<_ModifierKeyButton> createState() => _ModifierKeyButtonState();
}

class _ModifierKeyButtonState extends State<_ModifierKeyButton> {
  int? _activePointerId;
  Offset? _downPosition;
  bool _pointerAborted = false;
  bool _pointerSequenceHandled = false;

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.state == ModifierLockState.locked;
    final isOneShot = widget.state == ModifierLockState.oneShot;
    final isActive = isLocked || isOneShot || widget.isHeld;

    final Color? bgColor = isLocked
        ? context.colorScheme.primary
        : (isActive ? context.colorScheme.primaryContainer : null);
    final Color? fgColor = isLocked
        ? context.colorScheme.onPrimary
        : (isActive ? context.colorScheme.onPrimaryContainer : null);

    final btn = FilledButton.tonal(
      key: widget.buttonKey,
      style: FilledButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () {
        if (_pointerSequenceHandled) {
          // Handled deterministically by pointer sequence; ignore duplicate gesture tap.
          return;
        }
        // Allows accessibility and keyboard/programmatic taps to trigger normally.
        widget.onTap();
      },
      onLongPress: widget.onModifierDown != null ? null : widget.onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          if (isLocked) ...[
            const SizedBox(width: 3),
            const Icon(Icons.lock, size: 12),
          ],
        ],
      ),
    );

    final interactive = widget.onModifierDown != null
        ? Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              if (_activePointerId == null) {
                _activePointerId = e.pointer;
                _downPosition = e.position;
                _pointerAborted = false;
                _pointerSequenceHandled = true;
                widget.onModifierDown!(widget.label);
              }
            },
            onPointerMove: (e) {
              if (e.pointer == _activePointerId &&
                  !_pointerAborted &&
                  _downPosition != null) {
                final distance = (e.position - _downPosition!).distance;
                if (distance > 18.0) {
                  _pointerAborted = true;
                  widget.onModifierCancel?.call(widget.label);
                }
              }
            },
            onPointerUp: (e) {
              if (e.pointer == _activePointerId) {
                _activePointerId = null;
                _pointerSequenceHandled = true;
                if (!_pointerAborted) {
                  widget.onModifierUp?.call(widget.label);
                }
                _pointerAborted = false;
                scheduleMicrotask(() {
                  if (mounted) {
                    _pointerSequenceHandled = false;
                  }
                });
              }
            },
            onPointerCancel: (e) {
              if (e.pointer == _activePointerId) {
                _activePointerId = null;
                _pointerAborted = false;
                widget.onModifierCancel?.call(widget.label);
                scheduleMicrotask(() {
                  if (mounted) {
                    _pointerSequenceHandled = false;
                  }
                });
              }
            },
            child: btn,
          )
        : btn;

    return Tooltip(
      message: widget.tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(height: 44, child: interactive),
      ),
    );
  }
}
