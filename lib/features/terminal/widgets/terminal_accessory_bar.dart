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
  final bool Function()? canRepeat;

  const HoldRepeatKey({
    super.key,
    required this.onPressed,
    required this.child,
    this.canRepeat,
  });

  @override
  State<HoldRepeatKey> createState() => _HoldRepeatKeyState();
}

class _HoldRepeatKeyState extends State<HoldRepeatKey> {
  Timer? _initialTimer;
  Timer? _repeatTimer;

  void _start() {
    _cancel();
    if (widget.canRepeat != null && !widget.canRepeat!()) {
      return;
    }
    widget.onPressed();
    _initialTimer = Timer(const Duration(milliseconds: 350), () {
      if (widget.canRepeat != null && !widget.canRepeat!()) {
        _cancel();
        return;
      }
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        if (!mounted || (widget.canRepeat != null && !widget.canRepeat!())) {
          _cancel();
          return;
        }
        widget.onPressed();
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
  void deactivate() {
    _cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.of(context)) {
      _cancel();
    }
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

class _TerminalAccessoryBarState extends ConsumerState<TerminalAccessoryBar>
    with WidgetsBindingObserver {
  bool _isExpanded = false;
  _ExpandedCategory _activeCategory = _ExpandedCategory.nav;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

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

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  bool _canRepeat() {
    return mounted &&
        _appLifecycleState == AppLifecycleState.resumed &&
        TickerMode.of(context);
  }

  Widget _buildArrowsKeyGroup(BuildContext context, {bool isExpanded = false}) {
    const colWidth = 44.0;
    const rowHeight = 44.0;

    final groupKey = isExpanded
        ? const Key('terminal_accessory_expanded_key_ARROWS')
        : const Key('terminal_accessory_key_ARROWS');

    final tBgColor = context.colorScheme.surfaceContainerHigh.withValues(
      alpha: 0.5,
    );

    return Semantics(
      key: groupKey,
      container: true,
      label: context.l10n.terminalDirectionPad,
      child: SizedBox(
        key: const Key('terminal_direction_pad'),
        width: colWidth * 3,
        height: rowHeight * 2,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              // Inverted-T background: connected top-center 44x44 and bottom 132x44
              Positioned(
                left: 44,
                top: 0,
                width: 44,
                height: 44,
                child: Material(
                  color: tBgColor,
                  elevation: 0,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 0,
                top: 44,
                width: 132,
                height: 44,
                child: Material(
                  color: tBgColor,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox.expand(),
                ),
              ),
              // Four 44x44 touch areas
              Positioned(
                left: 44,
                top: 0,
                width: 44,
                height: 44,
                child: _buildPadArrowKey(context, '↑', () => _handleKey('↑')),
              ),
              Positioned(
                left: 0,
                top: 44,
                width: 44,
                height: 44,
                child: _buildPadArrowKey(context, '←', () => _handleKey('←')),
              ),
              Positioned(
                left: 44,
                top: 44,
                width: 44,
                height: 44,
                child: _buildPadArrowKey(context, '↓', () => _handleKey('↓')),
              ),
              Positioned(
                left: 88,
                top: 44,
                width: 44,
                height: 44,
                child: _buildPadArrowKey(context, '→', () => _handleKey('→')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPadArrowKey(
    BuildContext context,
    String label,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      key: Key('terminal_accessory_key_$label'),
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: HoldRepeatKey(
          onPressed: onPressed,
          canRepeat: _canRepeat,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrains Mono',
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResidentArea(BuildContext context, List<String> pinnedKeys) {
    if (pinnedKeys.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    var i = 0;
    while (i < pinnedKeys.length) {
      final key = pinnedKeys[i];
      if (key == 'ARROWS') {
        children.add(_buildArrowsKeyGroup(context));
        i++;
      } else {
        final topKey = key;
        String? bottomKey;
        if (i + 1 < pinnedKeys.length && pinnedKeys[i + 1] != 'ARROWS') {
          bottomKey = pinnedKeys[i + 1];
          i += 2;
        } else {
          i += 1;
        }

        children.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPinnedKey(context, topKey),
              if (bottomKey != null)
                _buildPinnedKey(context, bottomKey)
              else
                const SizedBox(width: 44, height: 44),
            ],
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

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
            // Two-row compact accessory keyboard (~88dp total height without SafeArea)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              child: SizedBox(
                height: 88,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildResidentArea(context, pinnedKeys),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildFixedRightCluster(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedRightCluster(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_buildMoreButton(context), _buildKeyboardButton(context)],
      ),
    );
  }

  Widget _buildKeyboardButton(BuildContext context) {
    final tooltipText = context.l10n.terminalToggleKeyboard;

    final btn = Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: widget.onToggleKeyboard,
          child: const Icon(Icons.keyboard, size: 16),
        ),
      ),
    );

    return SizedBox(
      key: const Key('terminal_accessory_keyboard_button'),
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltipText,
        child: Semantics(
          button: true,
          label: tooltipText,
          excludeSemantics: true,
          onTap: widget.onToggleKeyboard,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleKeyboard,
            child: btn,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    final btn = Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: FilledButton.tonal(
          key: const Key('terminal_accessory_more_button'),
          style: FilledButton.styleFrom(
            backgroundColor: _isExpanded
                ? context.colorScheme.primaryContainer
                : null,
            foregroundColor: _isExpanded
                ? context.colorScheme.onPrimaryContainer
                : null,
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () {
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Icon(
            _isExpanded ? Icons.expand_more : Icons.more_horiz,
            size: 16,
          ),
        ),
      ),
    );

    return SizedBox(
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
        },
        child: btn,
      ),
    );
  }

  Widget _buildPinnedKey(
    BuildContext context,
    String key, {
    bool isExpanded = false,
  }) {
    if (key == 'ARROWS') {
      return _buildArrowsKeyGroup(context, isExpanded: isExpanded);
    }
    if (key == '↑' || key == '↓' || key == '←' || key == '→') {
      final btnKey = isExpanded
          ? Key('terminal_accessory_expanded_key_$key')
          : Key('terminal_accessory_pinned_key_$key');
      return _buildKey(
        context,
        key,
        buttonKey: btnKey,
        onPressed: () => _handleKey(key),
      );
    }
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
    Key? buttonKey,
    IconData? icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final isArrow =
        label == '↑' || label == '↓' || label == '←' || label == '→';

    final btnKey = buttonKey ?? Key('terminal_accessory_key_$label');

    final btn = Center(
      child: SizedBox(
        height: 32,
        child: FilledButton.tonal(
          key: btnKey,
          style: FilledButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: isArrow ? () {} : onPressed,
          child: icon != null
              ? Icon(icon, size: 16)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
        ),
      ),
    );

    final interactive = isArrow
        ? SizedBox(
            width: 44,
            height: 44,
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: onPressed,
              child: HoldRepeatKey(
                onPressed: onPressed,
                canRepeat: _canRepeat,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: btn,
                ),
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: SizedBox(
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: btn,
                ),
              ),
            ),
          );

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
    if (category == _ExpandedCategory.nav) {
      final pinnedKeys = ref.watch(terminalSettingsProvider).pinnedKeys;
      return [
        if (!pinnedKeys.contains('ARROWS'))
          _buildPinnedKey(context, 'ARROWS', isExpanded: true),
        ...const ['HOME', 'END', 'PGUP', 'PGDN'].map(
          (key) => _buildKey(context, key, onPressed: () => _handleKey(key)),
        ),
      ];
    }

    final keys = switch (category) {
      _ExpandedCategory.nav => const <String>[],
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

    final btn = Center(
      child: SizedBox(
        height: 32,
        child: FilledButton.tonal(
          key: widget.buttonKey,
          style: FilledButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () {
            if (_pointerSequenceHandled) {
              // Handled deterministically by pointer sequence; ignore duplicate gesture tap.
              return;
            }
            // Allows accessibility and keyboard/programmatic taps to trigger normally.
            widget.onTap();
          },
          onLongPress: widget.onModifierDown != null
              ? null
              : widget.onLongPress,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 2),
                const Icon(Icons.lock, size: 11),
              ],
            ],
          ),
        ),
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
            child: Center(child: btn),
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Center(child: btn),
          );

    return Tooltip(
      message: widget.tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: SizedBox(height: 44, child: interactive),
        ),
      ),
    );
  }
}
