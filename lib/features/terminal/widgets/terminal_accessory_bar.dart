import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/storage_providers.dart';

enum ModifierLockState { inactive, oneShot, locked }

/// Helper widget that repeats invoking [onPressed] while held down.
/// Cancels cleanly on pointer up, pointer cancel, or disposal.
class HoldRepeatKey extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool Function()? canRepeat;
  final ValueChanged<bool>? onHoldChanged;

  const HoldRepeatKey({
    super.key,
    required this.onPressed,
    required this.child,
    this.canRepeat,
    this.onHoldChanged,
  });

  @override
  State<HoldRepeatKey> createState() => _HoldRepeatKeyState();
}

class _HoldRepeatKeyState extends State<HoldRepeatKey>
    with WidgetsBindingObserver {
  Timer? _initialTimer;
  Timer? _repeatTimer;
  int? _activePointerId;
  bool _isHeld = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancel();
    }
  }

  void _notifyHold(bool held) {
    if (_isHeld == held) return;
    _isHeld = held;
    final callback = widget.onHoldChanged;
    if (callback == null || _isDisposed) return;
    scheduleMicrotask(() {
      if (mounted && !_isDisposed) {
        callback(held);
      }
    });
  }

  void _start(int pointerId) {
    if (_activePointerId != null) {
      _cancel();
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    if (widget.canRepeat != null && !widget.canRepeat!()) {
      return;
    }
    _activePointerId = pointerId;
    _notifyHold(true);
    widget.onPressed();
    _initialTimer = Timer(const Duration(milliseconds: 350), () {
      final currentLifecycle = WidgetsBinding.instance.lifecycleState;
      if (!mounted ||
          (currentLifecycle != null &&
              currentLifecycle != AppLifecycleState.resumed) ||
          (widget.canRepeat != null && !widget.canRepeat!())) {
        _cancel();
        return;
      }
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        final tickLifecycle = WidgetsBinding.instance.lifecycleState;
        if (!mounted ||
            (tickLifecycle != null &&
                tickLifecycle != AppLifecycleState.resumed) ||
            (widget.canRepeat != null && !widget.canRepeat!())) {
          _cancel();
          return;
        }
        widget.onPressed();
      });
    });
  }

  void _cancel() {
    _activePointerId = null;
    _initialTimer?.cancel();
    _initialTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _notifyHold(false);
  }

  @override
  void deactivate() {
    _cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
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
      onPointerDown: (e) {
        if (_activePointerId == null) {
          _start(e.pointer);
        }
      },
      onPointerUp: (e) {
        if (e.pointer == _activePointerId) {
          _cancel();
        }
      },
      onPointerCancel: (e) {
        if (e.pointer == _activePointerId) {
          _cancel();
        }
      },
      child: widget.child,
    );
  }
}

class _ModifierKeyButton extends StatefulWidget {
  final String label;
  final ModifierLockState? state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String modifier)? onModifierDown;
  final void Function(String modifier)? onModifierUp;
  final void Function(String modifier)? onModifierCancel;
  final bool isHeld;
  final bool isActive;
  final Widget child;

  const _ModifierKeyButton({
    required this.label,
    this.state,
    this.onTap,
    this.onLongPress,
    this.onModifierDown,
    this.onModifierUp,
    this.onModifierCancel,
    this.isHeld = false,
    this.isActive = false,
    required this.child,
  });

  @override
  State<_ModifierKeyButton> createState() => _ModifierKeyButtonState();
}

class _ModifierKeyButtonState extends State<_ModifierKeyButton> {
  int? _activePointerId;
  Offset? _downPosition;
  bool _isDragSlopExceeded = false;
  static const double _kTouchSlop = 18.0;

  @override
  Widget build(BuildContext context) {
    final upper = widget.label.toUpperCase();
    if (widget.onModifierDown != null) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_activePointerId != null) return;
          _activePointerId = event.pointer;
          _downPosition = event.position;
          _isDragSlopExceeded = false;
          widget.onModifierDown!(upper);
        },
        onPointerMove: (event) {
          if (event.pointer != _activePointerId) return;
          if (_downPosition != null) {
            final delta = event.position - _downPosition!;
            if (delta.distance > _kTouchSlop) {
              _isDragSlopExceeded = true;
            }
          }
        },
        onPointerUp: (event) {
          if (event.pointer != _activePointerId) return;
          _activePointerId = null;
          if (_isDragSlopExceeded) {
            widget.onModifierCancel?.call(upper);
          } else {
            if (widget.onModifierUp != null) {
              widget.onModifierUp!(upper);
            } else {
              widget.onTap?.call();
            }
          }
        },
        onPointerCancel: (event) {
          if (event.pointer != _activePointerId) return;
          _activePointerId = null;
          widget.onModifierCancel?.call(upper);
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {},
            child: widget.child,
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: widget.child,
    );
  }
}

// =============================================================================
// Accessory Item Data Model & Grid Engine
// Matching project prototype: SSH 快捷键栏原型.html
// =============================================================================

const int kAccessoryCols = 8;
const double kAccessoryCellHeight = 42.0;
const List<String> kModifierNames = ['Ctrl', 'Alt', 'Shift', 'Meta', 'Fn', 'CTRL', 'ALT', 'SHIFT', 'META', 'FN'];
const List<List<dynamic>> kArrowOffsets = [
  ['↑', 1, 0],
  ['←', 0, 1],
  ['↓', 1, 1],
  ['→', 2, 1],
];

class AccessoryItem {
  String id;
  String t; // 'k' (key), 'g' (group/arrows), 'i' (ime/keyboard)
  String l; // label
  String s; // send string / text macro
  int w; // width in grid units (1..3)
  int h; // height in grid units (1..2)
  int c; // column (0..7)
  int r; // row (0..rows-1)
  int p; // page index (0..np-1)
  String kind; // 'key', 'combo', 'text'
  bool m; // modifier (Ctrl, Alt, Shift, Meta)
  int arrow; // 1 if split from arrow group

  AccessoryItem({
    required this.id,
    this.t = 'k',
    required this.l,
    String? s,
    this.w = 1,
    this.h = 1,
    this.c = 0,
    this.r = 0,
    this.p = 0,
    this.kind = 'key',
    this.m = false,
    this.arrow = 0,
  }) : s = s ?? l;

  AccessoryItem copyWith({
    String? id,
    String? t,
    String? l,
    String? s,
    int? w,
    int? h,
    int? c,
    int? r,
    int? p,
    String? kind,
    bool? m,
    int? arrow,
  }) {
    return AccessoryItem(
      id: id ?? this.id,
      t: t ?? this.t,
      l: l ?? this.l,
      s: s ?? this.s,
      w: w ?? this.w,
      h: h ?? this.h,
      c: c ?? this.c,
      r: r ?? this.r,
      p: p ?? this.p,
      kind: kind ?? this.kind,
      m: m ?? this.m,
      arrow: arrow ?? this.arrow,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    't': t,
    'l': l,
    's': s,
    'w': w,
    'h': h,
    'c': c,
    'r': r,
    'p': p,
    'kind': kind,
    'm': m,
    'arrow': arrow,
  };

  factory AccessoryItem.fromJson(Map<String, dynamic> json) {
    return AccessoryItem(
      id: json['id'] as String? ?? 'k_${Random().nextInt(99999)}',
      t: json['t'] as String? ?? 'k',
      l: json['l'] as String? ?? '',
      s: json['s'] as String?,
      w: (json['w'] as num?)?.toInt() ?? 1,
      h: (json['h'] as num?)?.toInt() ?? 1,
      c: (json['c'] as num?)?.toInt() ?? 0,
      r: (json['r'] as num?)?.toInt() ?? 0,
      p: (json['p'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? 'key',
      m: json['m'] as bool? ?? false,
      arrow: (json['arrow'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Creates default items as specified in the prototype `def()`.
List<AccessoryItem> createDefaultAccessoryItems() {
  int n = 0;
  final it = <AccessoryItem>[];

  // Page 0:
  // (0,0): ESC, (1,0): TAB, (2,0): CTRL, (3,0): ALT
  // (0,1): SHIFT, (1,1): PASTE, (2,1): /, (3,1): ~
  // (4..6, 0..1): arrows group
  // (7,0): -, (7,1): ime (⌨)
  final page0Keys = [
    'ESC', 'TAB', 'CTRL', 'ALT',
    'SHIFT', 'PASTE', '/', '~', '-',
  ];

  for (int i = 0; i < page0Keys.length; i++) {
    final l = page0Keys[i];
    final isMod = kModifierNames.contains(l);
    final o = AccessoryItem(
      id: 'd${n++}',
      l: l,
      s: l,
      p: 0,
      m: isMod,
    );
    if (i < 8) {
      o.c = i % 4;
      o.r = i >> 2;
    } else {
      o.c = 7;
      o.r = 0;
    }
    it.add(o);
  }

  // Inverted-T arrows group at (4, 0)
  it.add(AccessoryItem(
    id: 'arrows',
    t: 'g',
    l: 'arrows',
    c: 4,
    r: 0,
    w: 3,
    h: 2,
    p: 0,
  ));

  // Page 1:
  final page1Keys = [
    'Home', 'End', 'PgUp', 'PgDn', 'Ins', 'Del', 'Ctrl+C', 'Ctrl+D',
    'Ctrl+Z', 'Ctrl+L', 'Ctrl+R', 'Ctrl+A', 'Ctrl+E', 'Ctrl+U', 'Ctrl+W',
  ];

  for (int i = 0; i < page1Keys.length; i++) {
    final l = page1Keys[i];
    it.add(AccessoryItem(
      id: 'd${n++}',
      l: l,
      s: l,
      p: 1,
      kind: l.contains('+') ? 'combo' : 'key',
      c: i % 8,
      r: i >> 3,
    ));
  }

  // Keyboard button (⌨), fixed on right-bottom of all pages
  it.add(AccessoryItem(
    id: 'ime',
    t: 'i',
    l: '⌨',
    w: 1,
    h: 1,
    p: 0,
  ));

  return it;
}

/// Helper functions matching prototype rules
AccessoryItem getEffectivePos(AccessoryItem o, int rows) {
  if (o.t == 'i') {
    return o.copyWith(c: kAccessoryCols - 1, r: rows - 1, w: 1, h: 1);
  }
  return o;
}

bool isItemVisible(AccessoryItem o, int page) {
  return o.t == 'i' || o.p == page;
}

bool checkCollision(
  List<AccessoryItem> items,
  AccessoryItem? ignoreItem,
  int c,
  int r,
  int w,
  int h,
  int page,
  int rows,
) {
  return items.any((p) {
    if (p == ignoreItem || !(p.t == 'i' || p.p == page)) return false;
    final q = getEffectivePos(p, rows);
    return c < q.c + q.w && c + w > q.c && r < q.r + q.h && r + h > q.r;
  });
}

List<int>? findFreeSpot(
  List<AccessoryItem> items,
  int w,
  int h,
  int page,
  int rows,
) {
  for (int r = 0; r <= rows - h; r++) {
    for (int c = 0; c <= kAccessoryCols - w; c++) {
      if (!checkCollision(items, null, c, r, w, h, page, rows)) {
        return [c, r];
      }
    }
  }
  return null;
}

String formatKeyLabel(String l) {
  return l
      .replaceAll('Ctrl+', '^')
      .replaceAll('Alt+', '⌥')
      .replaceAll('Shift+', '⇧')
      .replaceAll('Meta+', '⌘');
}

double fontSizeForLabel(String text) {
  if (text.length > 4) return 10.0;
  if (text.length > 2) return 12.0;
  return 13.0;
}

// Preset categories from prototype SETS
final Map<String, List<String>> kPresetSets = {
  '常用': [
    'Esc', 'Tab', 'Enter', 'Backspace', 'Space', 'Del', 'Ins',
    'Ctrl+C', 'Ctrl+D', 'Ctrl+Z', 'Ctrl+L', 'Ctrl+R', 'Ctrl+A', 'Ctrl+E', 'Ctrl+U', 'Ctrl+W', 'Ctrl+K'
  ],
  'Ctrl+': [
    ...List.generate(26, (i) => 'Ctrl+${String.fromCharCode(65 + i)}'),
    'Ctrl+[', 'Ctrl+]', 'Ctrl+\\', 'Ctrl+Space',
  ],
  'Alt+': [
    ...List.generate(26, (i) => 'Alt+${String.fromCharCode(65 + i)}'),
    'Alt+.', 'Alt+Backspace', 'Alt+Enter',
  ],
  'F键': List.generate(12, (i) => 'F${i + 1}'),
  '导航': ['↑', '↓', '←', '→', 'Home', 'End', 'PgUp', 'PgDn', 'Ins', 'Del'],
  '符号': '| / \\ ~ - _ . , : ; * & ! @ # \$ % ^ = + ? \' " ` ( ) [ ] { } < >'.split(' '),
  '修饰': ['Ctrl', 'Alt', 'Shift', 'Meta'],
  '自定义': [],
};

// =============================================================================
// TerminalAccessoryBar Component
// =============================================================================

class TerminalAccessoryBar extends ConsumerStatefulWidget {
  final void Function(String key, {bool isCtrl, bool isAlt, bool isShift}) onKey;
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
  final bool? isKeyboardActive;
  final ValueChanged<double>? onHeightChanged;

  static double calculateBaseHeight(int rows) {
    return 28.0 + rows * kAccessoryCellHeight;
  }

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
    this.isKeyboardActive,
    this.onHeightChanged,
  });

  @override
  ConsumerState<TerminalAccessoryBar> createState() =>
      _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends ConsumerState<TerminalAccessoryBar>
    with WidgetsBindingObserver {
  List<AccessoryItem> _items = [];
  int _np = 2;
  int _rows = 2;
  int _page = 0;
  bool _edit = false;
  final Set<String> _mods = {};
  String? _sel;
  String _st = 'add'; // 'add', 'key', 'set'
  String _cat = '常用';
  bool _isExpanded = false;
  String _expandedCategory = 'Fn';

  // Dragging state
  String? _draggingId;
  Offset? _dragOffset;
  bool _isDragMoving = false;

  // Text editing controllers for Tab 'key' & Tab 'add' (custom)
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _customKeyCtrl = TextEditingController();
  final TextEditingController _customLabelCtrl = TextEditingController();
  final TextEditingController _macroLabelCtrl = TextEditingController();
  final TextEditingController _macroTextCtrl = TextEditingController();
  final Map<String, bool> _customModCheckboxes = {
    'Ctrl': false,
    'Alt': false,
    'Shift': false,
    'Meta': false,
  };
  bool _macroEnterCheckbox = true;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onHeightChanged?.call(TerminalAccessoryBar.calculateBaseHeight(_rows));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _labelCtrl.dispose();
    _customKeyCtrl.dispose();
    _customLabelCtrl.dispose();
    _macroLabelCtrl.dispose();
    _macroTextCtrl.dispose();
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

  void _loadConfig() {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final raw = storage.getTerminalGridConfig();
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final rawItems = data['items'] as List<dynamic>?;
        if (rawItems != null && rawItems.isNotEmpty) {
          _items = rawItems
              .map((e) => AccessoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _np = (data['np'] as num?)?.toInt() ?? 2;
          _rows = (data['rows'] as num?)?.toInt() ?? 2;
          return;
        }
      }
    } catch (_) {}
    _items = createDefaultAccessoryItems();
    _np = 2;
    _rows = 2;
  }

  Future<void> _saveConfig() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final data = {
        'items': _items.map((e) => e.toJson()).toList(),
        'np': _np,
        'rows': _rows,
      };
      await storage.setTerminalGridConfig(jsonEncode(data));
    } catch (_) {}
  }

  void _press(AccessoryItem o) {
    if (o.m) {
      final upper = o.l.toUpperCase();
      if (upper == 'CTRL') {
        widget.onToggleCtrl();
        return;
      }
      if (upper == 'ALT') {
        widget.onToggleAlt();
        return;
      }
      if (upper == 'SHIFT') {
        widget.onToggleShift?.call();
        return;
      }
      if (upper == 'FN' || upper == 'META') {
        widget.onToggleFn?.call();
        return;
      }
      setState(() {
        if (_mods.contains(o.l)) {
          _mods.remove(o.l);
        } else {
          _mods.add(o.l);
        }
      });
      return;
    }

    if (o.t == 'i') {
      widget.onToggleKeyboard?.call();
      return;
    }

    if (o.l.toUpperCase() == 'PASTE') {
      widget.onPaste();
      return;
    }

    final isCtrl = widget.isCtrlActive ||
        widget.ctrlState == ModifierLockState.oneShot ||
        widget.ctrlState == ModifierLockState.locked ||
        widget.isCtrlHeld ||
        _mods.any((m) => m.toUpperCase() == 'CTRL');
    final isAlt = widget.isAltActive ||
        widget.altState == ModifierLockState.oneShot ||
        widget.altState == ModifierLockState.locked ||
        widget.isAltHeld ||
        _mods.any((m) => m.toUpperCase() == 'ALT');
    final isShift = widget.shiftState == ModifierLockState.oneShot ||
        widget.shiftState == ModifierLockState.locked ||
        widget.isShiftHeld ||
        _mods.any((m) => m.toUpperCase() == 'SHIFT');

    if (o.kind == 'text') {
      // Text macro
      widget.onKey(o.s);
    } else {
      if (o.s.startsWith('Ctrl+')) {
        widget.onKey(o.s.substring(5).toUpperCase(), isCtrl: true, isAlt: isAlt, isShift: isShift);
      } else if (o.s.startsWith('Alt+')) {
        widget.onKey(o.s.substring(4).toUpperCase(), isCtrl: isCtrl, isAlt: true, isShift: isShift);
      } else {
        widget.onKey(o.s, isCtrl: isCtrl, isAlt: isAlt, isShift: isShift);
      }
    }

    if (_mods.isNotEmpty) {
      setState(() {
        _mods.clear();
      });
    }
  }

  void _placeItem(AccessoryItem o) {
    final s = findFreeSpot(_items, 1, 1, _page, _rows);
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前页没有空位，请先新增页、增加行数或删除按键'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    o.id = 'n${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    o.p = _page;
    o.c = s[0];
    o.r = s[1];
    setState(() {
      _items.add(o);
      _sel = o.id;
      _st = 'key';
      _labelCtrl.text = o.l;
    });
    _saveConfig();
  }

  void _setRows(int n) {
    n = n.clamp(1, 5);
    if (n == _rows) return;

    if (_items.any((i) => i.t == 'g') && n < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('倒T方向键需要至少 2 行，请先在「设置」里拆开方向键'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final snap = jsonEncode(_items.map((e) => e.toJson()).toList());
    final old = _rows;
    _rows = n;

    final bad = _items.where((i) =>
        i.t != 'i' &&
        (i.r + i.h > _rows ||
            (i.c + i.w > kAccessoryCols - 1 && i.r + i.h > _rows - 1))).toList();

    for (final o in bad) {
      o.c = -99;
      final s = findFreeSpot(_items, o.w, o.h, o.p, _rows);
      if (s == null) {
        _items = (jsonDecode(snap) as List)
            .map((e) => AccessoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _rows = old;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('第 ${o.p + 1} 页空间不足，请先删除或移动一些按键'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
        return;
      }
      o.c = s[0];
      o.r = s[1];
    }

    _saveConfig();
    setState(() {});
  }

  void _toggleArrows() {
    final g = _items.where((i) => i.t == 'g').firstOrNull;
    if (g != null) {
      setState(() {
        _items.remove(g);
        for (final arr in kArrowOffsets) {
          final l = arr[0] as String;
          final x = arr[1] as int;
          final y = arr[2] as int;
          _items.add(AccessoryItem(
            id: 'a$l',
            l: l,
            s: l,
            arrow: 1,
            p: g.p,
            c: g.c + x,
            r: g.r + y,
          ));
        }
        _sel = null;
      });
    } else {
      if (_rows < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先把行数增加到 2 行以上'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final old = _items.where((i) => i.arrow == 1).toList();
      _items.removeWhere((i) => i.arrow == 1);
      final s = findFreeSpot(_items, 3, 2, _page, _rows);
      if (s == null) {
        _items.addAll(old);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前页需要 3×2 的空位'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
        return;
      }
      setState(() {
        _items.add(AccessoryItem(
          id: 'arrows',
          t: 'g',
          l: 'arrows',
          c: s[0],
          r: s[1],
          w: 3,
          h: 2,
          p: _page,
        ));
        _sel = 'arrows';
        _st = 'key';
      });
    }
    _saveConfig();
  }

  void _resetToDefault() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置布局'),
        content: const Text('确定要重置为默认快捷键布局吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true && mounted) {
        setState(() {
          _items = createDefaultAccessoryItems();
          _np = 2;
          _rows = 2;
          _page = 0;
          _sel = null;
        });
        _saveConfig();
      }
    });
  }

  void _deleteCurrentPage() {
    if (_np < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('至少保留一页'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除页面'),
        content: Text('删除第 ${_page + 1} 页及其所有按键？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF7B80)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true && mounted) {
        setState(() {
          _items.removeWhere((o) => o.t != 'i' && o.p == _page);
          for (final o in _items) {
            if (o.t != 'i' && o.p > _page) {
              o.p--;
            }
          }
          _np--;
          _page = _page.clamp(0, _np - 1);
          _sel = null;
        });
        _saveConfig();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1D23),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_edit) FocusScope(child: _buildEditSheet(context)),
            if (_isExpanded && !_edit)
              ExcludeFocus(
                excluding: true,
                child: _buildExpandedPanel(context),
              ),
            ExcludeFocus(
              excluding: true,
              child: _buildBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom Bar & Grid Board
  // ===========================================================================

  Widget _buildBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        border: _edit
            ? null
            : const Border(
                top: BorderSide(color: Color(0xFF2A2E37), width: 1),
              ),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardWidth = constraints.maxWidth - 8; // 4px margin on each side
          final cw = boardWidth / kAccessoryCols;
          final boardHeight = _rows * kAccessoryCellHeight;

          return SizedBox(
            height: boardHeight + 10,
            child: Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 0,
                  width: boardWidth,
                  height: boardHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      if (_edit) return;
                      final v = details.primaryVelocity ?? 0;
                      if (v < -200) {
                        if (_page < _np - 1) {
                          setState(() => _page++);
                        }
                      } else if (v > 200) {
                        if (_page > 0) {
                          setState(() => _page--);
                        }
                      }
                    },
                    child: Container(
                      decoration: _edit
                          ? BoxDecoration(
                              border: Border.all(color: const Color(0x1AFFFFFF)),
                            )
                          : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ..._items
                              .where((o) => isItemVisible(o, _page))
                              .map((o) => _buildItemWidget(o, cw)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Pagination dots & More button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 12,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_np > 1)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_np, (i) {
                              final isOn = i == _page;
                              return Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOn
                                      ? const Color(0xFF8FB4FF)
                                      : const Color(0xFF3A4150),
                                ),
                              );
                            }),
                          ),
                        Positioned(
                          right: 4,
                          top: -6,
                          child: Semantics(
                            button: true,
                            label: 'More',
                            child: GestureDetector(
                              key: const Key('terminal_accessory_more_button'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _isExpanded = !_isExpanded;
                                });
                              },
                              child: const SizedBox(
                                width: 28,
                                height: 24,
                                child: Center(
                                  child: Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: Color(0xFF5B6475),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemWidget(AccessoryItem o, double cw) {
    final q = getEffectivePos(o, _rows);
    final isSelected = _edit && _sel == o.id;
    final isDragging = _edit && _draggingId == o.id;

    double left = q.c * cw;
    double top = q.r * kAccessoryCellHeight;
    if (isDragging && _dragOffset != null) {
      left += _dragOffset!.dx;
      top += _dragOffset!.dy;
    }

    final width = q.w * cw;
    final height = q.h * kAccessoryCellHeight;

    if (o.t == 'g') {
      return Positioned(
        key: const Key('terminal_accessory_key_ARROWS'),
        left: left,
        top: top,
        width: width,
        height: height,
        child: Opacity(
          opacity: isDragging ? 0.85 : 1.0,
          child: _buildArrowGroup(o, cw, isSelected),
        ),
      );
    }

    final upper = o.l.toUpperCase();
    final isModifier = o.m || kModifierNames.contains(upper);

    final isLocked = (upper == 'CTRL' && widget.ctrlState == ModifierLockState.locked) ||
        (upper == 'ALT' && widget.altState == ModifierLockState.locked) ||
        (upper == 'SHIFT' && widget.shiftState == ModifierLockState.locked) ||
        (upper == 'FN' && widget.fnState == ModifierLockState.locked);

    final isOneShot = (upper == 'CTRL' && widget.ctrlState == ModifierLockState.oneShot) ||
        (upper == 'ALT' && widget.altState == ModifierLockState.oneShot) ||
        (upper == 'SHIFT' && widget.shiftState == ModifierLockState.oneShot) ||
        (upper == 'FN' && widget.fnState == ModifierLockState.oneShot);

    final isHeld = (upper == 'CTRL' && widget.isCtrlHeld) ||
        (upper == 'ALT' && widget.isAltHeld) ||
        (upper == 'SHIFT' && widget.isShiftHeld) ||
        (upper == 'FN' && widget.isFnHeld);

    final isKeyboardActive = widget.isKeyboardActive ?? false;
    final isAct = _mods.contains(o.l) ||
        isLocked ||
        isOneShot ||
        isHeld ||
        (o.t == 'i' && isKeyboardActive) ||
        (upper == 'CTRL' && widget.isCtrlActive) ||
        (upper == 'ALT' && widget.isAltActive);

    final displayLabel = formatKeyLabel(o.l);
    final isPaste = upper == 'PASTE';

    final keyName = (isModifier || const ['ESC', 'TAB', 'CTRL', 'ALT', 'SHIFT', 'PASTE', 'FN'].contains(upper))
        ? upper
        : o.l;

    final keyContainer = Container(
      decoration: BoxDecoration(
        color: isAct ? const Color(0xFF2F6FED) : const Color(0xFF2E333D),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ],
        border: _edit
            ? (isSelected
                ? Border.all(color: const Color(0xFF4C8DFF), width: 2)
                : Border.all(color: const Color(0xFF5B6475), style: BorderStyle.solid, width: 1))
            : null,
      ),
      alignment: Alignment.center,
      child: isPaste
          ? const Icon(Icons.content_paste, size: 16, color: Color(0xFFE6E9EF))
          : Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: fontSizeForLabel(displayLabel),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE6E9EF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isLocked)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(Icons.lock, size: 9, color: Color(0xFFE6E9EF)),
                  ),
              ],
            ),
    );

    Widget itemInteractive;
    if (_edit) {
      itemInteractive = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _sel = o.id;
            _st = 'key';
            _labelCtrl.text = o.l;
          });
        },
        onPanStart: o.t == 'i'
            ? null
            : (d) {
                setState(() {
                  _draggingId = o.id;
                  _dragOffset = Offset.zero;
                  _isDragMoving = false;
                  _sel = o.id;
                  _st = 'key';
                  _labelCtrl.text = o.l;
                });
              },
        onPanUpdate: o.t == 'i'
            ? null
            : (d) {
                setState(() {
                  _dragOffset = (_dragOffset ?? Offset.zero) + d.delta;
                  if (_dragOffset!.distance >= 6) {
                    _isDragMoving = true;
                  }
                });
              },
        onPanEnd: o.t == 'i'
            ? null
            : (d) {
                if (_isDragMoving && _dragOffset != null) {
                  final ol = o.c * cw;
                  final ot = o.r * kAccessoryCellHeight;
                  final newL = ol + _dragOffset!.dx;
                  final newT = ot + _dragOffset!.dy;
                  final targetC = ((newL / cw).round()).clamp(0, kAccessoryCols - o.w);
                  final targetR = ((newT / kAccessoryCellHeight).round()).clamp(0, _rows - o.h);

                  if (!checkCollision(_items, o, targetC, targetR, o.w, o.h, _page, _rows)) {
                    o.c = targetC;
                    o.r = targetR;
                  } else {
                    // Swap with colliding 1x1 key
                    final p = _items.where((item) =>
                        item != o &&
                        item.t != 'i' &&
                        item.p == _page &&
                        targetC < item.c + item.w &&
                        targetC + o.w > item.c &&
                        targetR < item.r + item.h &&
                        targetR + o.h > item.r).firstOrNull;
                    if (p != null &&
                        p.t == 'k' &&
                        o.t == 'k' &&
                        p.w == o.w &&
                        !checkCollision(_items, p, o.c, o.r, p.w, p.h, _page, _rows)) {
                      final oldC = o.c, oldR = o.r;
                      o.c = p.c;
                      o.r = p.r;
                      p.c = oldC;
                      p.r = oldR;
                    }
                  }
                  _saveConfig();
                }
                setState(() {
                  _draggingId = null;
                  _dragOffset = null;
                  _isDragMoving = false;
                });
              },
        child: keyContainer,
      );
    } else if (isModifier) {
      itemInteractive = _ModifierKeyButton(
        label: o.l,
        state: upper == 'CTRL'
            ? widget.ctrlState
            : (upper == 'ALT'
                ? widget.altState
                : (upper == 'SHIFT'
                    ? widget.shiftState
                    : (upper == 'FN' ? widget.fnState : null))),
        onTap: () => _press(o),
        onLongPress: () {
          setState(() {
            _edit = true;
            _sel = o.id;
            _st = 'key';
            _labelCtrl.text = o.l;
          });
        },
        onModifierDown: widget.onModifierDown,
        onModifierUp: widget.onModifierUp,
        onModifierCancel: widget.onModifierCancel,
        isHeld: isHeld,
        isActive: isAct,
        child: keyContainer,
      );
    } else {
      itemInteractive = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (o.t == 'i') {
            widget.onToggleKeyboard?.call();
            return;
          }
          _press(o);
        },
        onLongPress: o.t == 'i'
            ? null
            : () {
                setState(() {
                  _edit = true;
                  _sel = o.id;
                  _st = 'key';
                  _labelCtrl.text = o.l;
                });
              },
        child: keyContainer,
      );
    }

    return Positioned(
      key: o.t == 'i'
          ? const Key('terminal_accessory_keyboard_button')
          : Key('terminal_accessory_key_$keyName'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: Opacity(
        opacity: isDragging ? 0.85 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: itemInteractive,
        ),
      ),
    );
  }

  Widget _buildArrowGroup(AccessoryItem o, double cw, bool isSelected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_edit) {
          setState(() {
            _sel = 'arrows';
            _st = 'key';
          });
        }
      },
      onLongPress: _edit
          ? null
          : () {
              setState(() {
                _edit = true;
                _sel = 'arrows';
                _st = 'key';
              });
            },
      onPanStart: !_edit
          ? null
          : (d) {
              setState(() {
                _draggingId = 'arrows';
                _dragOffset = Offset.zero;
                _isDragMoving = false;
                _sel = 'arrows';
                _st = 'key';
              });
            },
      onPanUpdate: !_edit
          ? null
          : (d) {
              setState(() {
                _dragOffset = (_dragOffset ?? Offset.zero) + d.delta;
                if (_dragOffset!.distance >= 6) {
                  _isDragMoving = true;
                }
              });
            },
      onPanEnd: !_edit
          ? null
          : (d) {
              if (_isDragMoving && _dragOffset != null) {
                final ol = o.c * cw;
                final ot = o.r * kAccessoryCellHeight;
                final newL = ol + _dragOffset!.dx;
                final newT = ot + _dragOffset!.dy;
                final targetC = ((newL / cw).round()).clamp(0, kAccessoryCols - 3);
                final targetR = ((newT / kAccessoryCellHeight).round()).clamp(0, _rows - 2);

                if (!checkCollision(_items, o, targetC, targetR, 3, 2, _page, _rows)) {
                  o.c = targetC;
                  o.r = targetR;
                  _saveConfig();
                }
              }
              setState(() {
                _draggingId = null;
                _dragOffset = null;
                _isDragMoving = false;
              });
            },
      child: Container(
        key: const Key('terminal_direction_pad'),
        decoration: _edit
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: const Color(0xFF4C8DFF), width: 2)
                    : Border.all(color: const Color(0xFF5B6475), width: 1),
              )
            : null,
        child: Stack(
          children: kArrowOffsets.map((arr) {
            final label = arr[0] as String;
            final x = arr[1] as int;
            final y = arr[2] as int;

            return Positioned(
              left: x * cw,
              top: y * kAccessoryCellHeight,
              width: cw,
              height: kAccessoryCellHeight,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: HoldRepeatKey(
                  onPressed: () {
                    if (!_edit) {
                      _press(AccessoryItem(id: 'temp', l: label, s: label));
                    }
                  },
                  canRepeat: _canRepeat,
                  child: Container(
                    key: Key('terminal_accessory_key_$label'),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A4150),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE6E9EF),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // Quick More / Expanded Categories
  // ===========================================================================

  Widget _buildExpandedPanel(BuildContext context) {
    const categories = ['Nav', 'Edit', 'Sym', 'Fn'];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF232730),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2E37), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    children: categories.map((cat) {
                      final isSelected = _expandedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _expandedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0x332F6FED) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2F6FED) : const Color(0xFF3A4150),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF8FB4FF) : const Color(0xFFAAB2C3),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _edit = true;
                    _st = 'add';
                    _isExpanded = false;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.tune, size: 16, color: Color(0xFFAAB2C3)),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.close, size: 16, color: Color(0xFFAAB2C3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildExpandedCategoryKeys(context, _expandedCategory),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandedCategoryKeys(BuildContext context, String cat) {
    if (cat == 'Nav') {
      return ['HOME', 'END', 'PGUP', 'PGDN'].map((k) {
        return _buildQuickKey(k, () => _handleKey(k));
      }).toList();
    }
    if (cat == 'Edit') {
      return ['Ctrl+C', 'Ctrl+D', 'Ctrl+A', 'Ctrl+E', 'Ctrl+U', 'Ctrl+W', 'Ctrl+Z', 'INSERT', 'DELETE', 'BACKSPACE', 'ENTER'].map((k) {
        return _buildQuickKey(k, () => _handleKey(k));
      }).toList();
    }
    if (cat == 'Sym') {
      return ['/', '-', '_', '|', '~', '.', ':', '='].map((k) {
        return _buildQuickKey(k, () => _handleKey(k));
      }).toList();
    }
    if (cat == 'Fn') {
      return [
        _buildQuickModifierKey('FN'),
        ...List.generate(12, (i) => 'F${i + 1}').map((k) => _buildQuickKey(k, () => _handleKey(k))),
      ];
    }
    return [];
  }

  Widget _buildQuickKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: Key('terminal_accessory_key_$label'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2E333D),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A4150)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.bold,
              color: Color(0xFFE6E9EF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickModifierKey(String modifier) {
    final upper = modifier.toUpperCase();
    final state = upper == 'FN' ? widget.fnState : null;
    final isLocked = state == ModifierLockState.locked;
    final isOneShot = state == ModifierLockState.oneShot;
    final isHeld = upper == 'FN' ? widget.isFnHeld : false;
    final isAct = isLocked || isOneShot || isHeld || _mods.contains(modifier);

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: _ModifierKeyButton(
        label: modifier,
        state: state,
        onTap: () {
          if (upper == 'FN') widget.onToggleFn?.call();
        },
        onModifierDown: widget.onModifierDown,
        onModifierUp: widget.onModifierUp,
        onModifierCancel: widget.onModifierCancel,
        isHeld: isHeld,
        isActive: isAct,
        child: Container(
          key: Key('terminal_accessory_key_$upper'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isAct ? const Color(0xFF2F6FED) : const Color(0xFF2E333D),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A4150)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                modifier,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6E9EF),
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 3),
                const Icon(Icons.lock, size: 10, color: Color(0xFFE6E9EF)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleKey(String key) {
    if (key.startsWith('Ctrl+')) {
      widget.onKey(key.substring(5).toUpperCase(), isCtrl: true);
    } else if (key.startsWith('Alt+')) {
      widget.onKey(key.substring(4).toUpperCase(), isAlt: true);
    } else {
      widget.onKey(key);
    }
  }

  void _onEditDone() {
    FocusScope.of(context).unfocus();
    setState(() {
      _edit = false;
      _sel = null;
    });
    widget.onHeightChanged?.call(TerminalAccessoryBar.calculateBaseHeight(_rows));
  }

  // ===========================================================================
  // Edit Sheet (Matching .sheet in prototype)
  // ===========================================================================

  Widget _buildEditSheet(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenHeight = mediaQuery?.size.height ?? 800.0;
    final viewInsetsBottom = mediaQuery?.viewInsets.bottom ?? 0.0;
    final safeHeight = (screenHeight - viewInsetsBottom - 140).clamp(180.0, 300.0);

    return Container(
      constraints: BoxConstraints(maxHeight: safeHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF161A20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2E37), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Segmented Control & Done Button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF232730),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        _buildSegmentButton('add', '添加'),
                        _buildSegmentButton('key', '按键'),
                        _buildSegmentButton('set', '设置'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6FED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  ),
                  onPressed: _onEditDone,
                  child: const Text(
                    '完成',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Pager Row
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF22262E), width: 1)),
            ),
            child: Row(
              children: [
                const Text(
                  '当前页',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B93A3)),
                ),
                const SizedBox(width: 8),
                _buildSmallButton('‹', () {
                  if (_page > 0) {
                    setState(() => _page--);
                  }
                }),
                Container(
                  constraints: const BoxConstraints(minWidth: 36),
                  alignment: Alignment.center,
                  child: Text(
                    '${_page + 1} / $_np',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE6E9EF),
                    ),
                  ),
                ),
                _buildSmallButton('›', () {
                  if (_page < _np - 1) {
                    setState(() => _page++);
                  }
                }),
                const Spacer(),
                _buildSmallButton('＋ 新增页', () {
                  setState(() {
                    _np++;
                    _page = _np - 1;
                  });
                  _saveConfig();
                }),
                const SizedBox(width: 6),
                _buildSmallButton('删除页', _deleteCurrentPage, isDanger: true),
              ],
            ),
          ),
          // Body of Sheet
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildSheetBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String key, String text) {
    final isOn = _st == key;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _st = key;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isOn ? const Color(0xFF3A4150) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
              color: isOn ? Colors.white : const Color(0xFF9AA3B5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(String text, VoidCallback onPressed, {bool isDanger = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2E37),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDanger ? const Color(0xFFFF7B80) : const Color(0xFFD8DEE9),
            fontWeight: isDanger ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSheetBody(BuildContext context) {
    switch (_st) {
      case 'add':
        return _buildTabAdd(context);
      case 'key':
        return _buildTabKey(context);
      case 'set':
        return _buildTabSet(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 1: 添加 (Add Keys)
  // ---------------------------------------------------------------------------

  Widget _buildTabAdd(BuildContext context) {
    final categories = kPresetSets.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((k) {
              final isOn = _cat == k;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _cat = k),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOn ? const Color(0x222F6FED) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOn ? const Color(0xFF2F6FED) : const Color(0xFF2F3541),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                    child: Text(
                      k,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOn ? const Color(0xFF8FB4FF) : const Color(0xFFAAB2C3),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        if (_cat != '自定义') ...[
          _buildPresetGrid(kPresetSets[_cat] ?? []),
        ] else ...[
          _buildCustomSection(context),
        ],
      ],
    );
  }

  Widget _buildPresetGrid(List<String> list) {
    const perPage = 12;
    final pageCount = (list.length / perPage).ceil();

    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          final start = pageIndex * perPage;
          final subList = list.sublist(start, min(start + perPage, list.length));

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.1,
            ),
            itemCount: subList.length,
            itemBuilder: (context, index) {
              final label = subList[index];
              return GestureDetector(
                onTap: () {
                  final isMod = kModifierNames.contains(label);
                  _placeItem(AccessoryItem(
                    id: 'temp',
                    l: label,
                    s: label,
                    m: isMod,
                    kind: (label.length > 1 && label.contains('+')) ? 'combo' : 'key',
                  ));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2E37),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: Color(0xFFD8DEE9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '自定义组合键：勾选修饰键 + 输入按键',
          style: TextStyle(fontSize: 12, color: Color(0xFF8B93A3)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: ['Ctrl', 'Alt', 'Shift', 'Meta'].map((m) {
            final checked = _customModCheckboxes[m] ?? false;
            return GestureDetector(
              onTap: () => setState(() => _customModCheckboxes[m] = !checked),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: checked,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setState(() => _customModCheckboxes[m] = v ?? false),
                  ),
                  Text(m, style: const TextStyle(fontSize: 12, color: Color(0xFFD8DEE9))),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customKeyCtrl,
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFFE6E9EF)),
                decoration: InputDecoration(
                  hintText: '按键，如 C / F5 / Tab',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF8B93A3)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  filled: true,
                  fillColor: const Color(0xFF232730),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A4150)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _customLabelCtrl,
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFFE6E9EF)),
                decoration: InputDecoration(
                  hintText: '显示名(可选)',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF8B93A3)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  filled: true,
                  fillColor: const Color(0xFF232730),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A4150)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F6FED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              ),
              onPressed: () {
                var k = _customKeyCtrl.text.trim();
                if (k.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入按键')),
                  );
                  return;
                }
                k = k.length == 1 ? k.toUpperCase() : k[0].toUpperCase() + k.substring(1);
                final ms = _customModCheckboxes.entries
                    .where((e) => e.value)
                    .map((e) => e.key)
                    .toList();
                final s = [...ms, k].join('+');
                final l = _customLabelCtrl.text.trim().isNotEmpty
                    ? _customLabelCtrl.text.trim()
                    : s;
                _placeItem(AccessoryItem(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  l: l,
                  s: s,
                  kind: ms.isNotEmpty ? 'combo' : 'key',
                ));
              },
              child: const Text('添加', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Text Macro section
        const Text(
          '文本宏：点一下发送整段文本',
          style: TextStyle(fontSize: 12, color: Color(0xFF8B93A3)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextField(
                controller: _macroLabelCtrl,
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFFE6E9EF)),
                decoration: InputDecoration(
                  hintText: '显示名',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF8B93A3)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  filled: true,
                  fillColor: const Color(0xFF232730),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A4150)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _macroTextCtrl,
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFFE6E9EF)),
                decoration: InputDecoration(
                  hintText: '如 ls -la',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF8B93A3)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  filled: true,
                  fillColor: const Color(0xFF232730),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A4150)),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _macroEnterCheckbox,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => setState(() => _macroEnterCheckbox = v ?? true),
                ),
                const Text('回车', style: TextStyle(fontSize: 12, color: Color(0xFFD8DEE9))),
              ],
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2F6FED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              ),
              onPressed: () {
                final t = _macroTextCtrl.text;
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入文本')),
                  );
                  return;
                }
                final l = _macroLabelCtrl.text.trim().isNotEmpty
                    ? _macroLabelCtrl.text.trim()
                    : (t.length > 4 ? t.substring(0, 4) : t);
                _placeItem(AccessoryItem(
                  id: 'macro_${DateTime.now().millisecondsSinceEpoch}',
                  l: l,
                  s: t + (_macroEnterCheckbox ? '\n' : ''),
                  kind: 'text',
                ));
              },
              child: const Text('添加', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: 按键 (Key Properties)
  // ---------------------------------------------------------------------------

  Widget _buildTabKey(BuildContext context) {
    final o = _items.where((i) => i.id == _sel).firstOrNull;

    if (o == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '点击键盘上的按键进行选择\n按住拖动可调整位置',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8B93A3), height: 1.6),
          ),
        ),
      );
    }

    if (o.t == 'g') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPropertyRow(
            title: '方向键组',
            subtitle: '倒T形状固定，只能整体拖动',
            trailing: _buildSmallButton('拆成独立按键', _toggleArrows),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2A2E37),
              foregroundColor: const Color(0xFFFF7B80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            onPressed: () {
              setState(() {
                _items.remove(o);
                _sel = null;
              });
              _saveConfig();
            },
            child: const Text('删除方向键组', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    final kindMap = {'key': '单键', 'combo': '组合键', 'text': '文本宏'};
    final kd = kindMap[o.kind] ?? '单键';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label TextField
        _buildPropertyRow(
          title: '显示名',
          trailing: SizedBox(
            width: 140,
            child: TextField(
              controller: _labelCtrl,
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Color(0xFFE6E9EF)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                filled: true,
                fillColor: const Color(0xFF232730),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3A4150)),
                ),
              ),
              onChanged: (val) {
                o.l = val.isNotEmpty ? val : ' ';
                _saveConfig();
                setState(() {});
              },
            ),
          ),
        ),
        // Send string
        _buildPropertyRow(
          title: '发送 · $kd',
          trailing: Text(
            o.s.replaceAll('\n', '⏎'),
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: Color(0xFF8B93A3),
            ),
          ),
        ),
        // Width stepper
        _buildPropertyRow(
          title: '宽度（格）',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton('−', () {
                if (o.w > 1) {
                  setState(() => o.w--);
                  _saveConfig();
                }
              }),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '${o.w}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE6E9EF)),
                ),
              ),
              _buildStepperButton('＋', () {
                if (o.w < 3 && o.c + o.w + 1 <= kAccessoryCols) {
                  if (!checkCollision(_items, o, o.c, o.r, o.w + 1, o.h, o.p, _rows)) {
                    setState(() => o.w++);
                    _saveConfig();
                  }
                }
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2A2E37),
            foregroundColor: const Color(0xFFFF7B80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 9),
          ),
          onPressed: () {
            setState(() {
              _items.remove(o);
              _sel = null;
            });
            _saveConfig();
          },
          child: const Text('删除这个按键', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: 设置 (Settings)
  // ---------------------------------------------------------------------------

  Widget _buildTabSet(BuildContext context) {
    final hasArrowGroup = _items.any((i) => i.t == 'g');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rows Stepper
        _buildPropertyRow(
          title: '键盘显示行数',
          subtitle: '1–5 行，默认 2 行',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton('−', () => _setRows(_rows - 1)),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '$_rows',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE6E9EF)),
                ),
              ),
              _buildStepperButton('＋', () => _setRows(_rows + 1)),
            ],
          ),
        ),
        // Toggle Arrows Switch
        _buildPropertyRow(
          title: '方向键倒T固定',
          subtitle: '关闭后拆成 4 个独立按键',
          trailing: Switch(
            value: hasArrowGroup,
            activeTrackColor: const Color(0xFF2F6FED),
            onChanged: (val) => _toggleArrows(),
          ),
        ),
        // Reset button
        _buildPropertyRow(
          title: '恢复默认布局',
          trailing: _buildSmallButton('重置', _resetToDefault, isDanger: true),
        ),
      ],
    );
  }

  Widget _buildPropertyRow({
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF22262E), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE6E9EF), fontWeight: FontWeight.w500),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8B93A3)),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildStepperButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2E37),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, color: Color(0xFFD8DEE9), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
