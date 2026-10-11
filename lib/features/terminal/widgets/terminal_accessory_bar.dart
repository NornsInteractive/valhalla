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
  final void Function(String key, {bool isCtrl, bool isAlt}) onKey;
  final VoidCallback onToggleCtrl;
  final VoidCallback? onLockCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback? onLockAlt;
  final VoidCallback onPaste;
  final VoidCallback? onToggleKeyboard;
  final ModifierLockState? ctrlState;
  final ModifierLockState? altState;
  final bool isCtrlActive;
  final bool isAltActive;
  final bool pinKeyboardButtonTrailing;

  const TerminalAccessoryBar({
    super.key,
    required this.onKey,
    required this.onToggleCtrl,
    this.onLockCtrl,
    required this.onToggleAlt,
    this.onLockAlt,
    required this.onPaste,
    this.onToggleKeyboard,
    this.ctrlState,
    this.altState,
    this.isCtrlActive = false,
    this.isAltActive = false,
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

    return Container(
      color: context.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

  Widget _buildPinnedKey(BuildContext context, String key) {
    if (key == 'CTRL') {
      return _buildModifierKey(
        context,
        label: 'CTRL',
        state: _effectiveCtrlState,
        onTap: widget.onToggleCtrl,
        onLongPress: widget.onLockCtrl ?? widget.onToggleCtrl,
        tooltip: _effectiveCtrlState == ModifierLockState.locked
            ? 'Ctrl (Locked)'
            : (_effectiveCtrlState == ModifierLockState.oneShot
                  ? 'Ctrl (One-shot active)'
                  : 'Ctrl (Tap once, Long press to lock)'),
      );
    }
    if (key == 'ALT') {
      return _buildModifierKey(
        context,
        label: 'ALT',
        state: _effectiveAltState,
        onTap: widget.onToggleAlt,
        onLongPress: widget.onLockAlt ?? widget.onToggleAlt,
        tooltip: _effectiveAltState == ModifierLockState.locked
            ? 'Alt (Locked)'
            : (_effectiveAltState == ModifierLockState.oneShot
                  ? 'Alt (One-shot active)'
                  : 'Alt (Tap once, Long press to lock)'),
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
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required String tooltip,
  }) {
    final isLocked = state == ModifierLockState.locked;
    final isOneShot = state == ModifierLockState.oneShot;

    final Color? bgColor = isLocked
        ? context.colorScheme.primary
        : (isOneShot ? context.colorScheme.primaryContainer : null);
    final Color? fgColor = isLocked
        ? context.colorScheme.onPrimary
        : (isOneShot ? context.colorScheme.onPrimaryContainer : null);

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 44,
          child: FilledButton.tonal(
            key: Key('terminal_accessory_key_$label'),
            style: FilledButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: onTap,
            onLongPress: onLongPress,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
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
          ),
        ),
      ),
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
