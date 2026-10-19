import 'dart:convert';
import 'dart:math' as math;

const int kAccessoryCols = 8;
const double kAccessoryCellHeight = 44;
const List<String> kModifierNames = [
  'Ctrl',
  'Alt',
  'Shift',
  'Fn',
  'Meta',
  'CTRL',
  'ALT',
  'SHIFT',
  'FN',
  'META',
];
const List<List<dynamic>> kArrowOffsets = [
  ['↑', 1, 0],
  ['←', 0, 1],
  ['↓', 1, 1],
  ['→', 2, 1],
];

/// Sending is independent of the user-visible label and of the grid position.
class TerminalAccessoryAction {
  final String type;
  final String key;
  final List<String> modifiers;
  final String text;
  final bool appendEnter;

  const TerminalAccessoryAction({
    required this.type,
    this.key = '',
    this.modifiers = const [],
    this.text = '',
    this.appendEnter = false,
  });

  bool get supported => switch (type) {
    'unsupported' => false,
    'key' =>
      key.runes.length == 1 ||
          const {
            'ESC',
            'TAB',
            'ENTER',
            'BACKSPACE',
            'DELETE',
            'INSERT',
            'HOME',
            'END',
            'PGUP',
            'PGDN',
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
          }.contains(key),
    _ => true,
  };

  static String normalizeKey(String key) {
    if (key == ' ') return key;
    final upper = key.toUpperCase();
    return switch (upper) {
      'DEL' => 'DELETE',
      'INS' => 'INSERT',
      'PAGEUP' => 'PGUP',
      'PAGEDOWN' => 'PGDN',
      'SPACE' => ' ',
      'UP' => '↑',
      'DOWN' => '↓',
      'LEFT' => '←',
      'RIGHT' => '→',
      'ESC' ||
      'TAB' ||
      'ENTER' ||
      'BACKSPACE' ||
      'DELETE' ||
      'INSERT' ||
      'HOME' ||
      'END' ||
      'PGUP' ||
      'PGDN' => upper,
      _ => RegExp(r'^F(?:[1-9]|1[0-2])$').hasMatch(upper) ? upper : key,
    };
  }

  factory TerminalAccessoryAction.fromLegacy(
    String send, {
    String type = 'k',
    String kind = 'key',
    bool modifier = false,
  }) {
    if (type == 'i') return const TerminalAccessoryAction(type: 'keyboard');
    if (type == 'more') return const TerminalAccessoryAction(type: 'more');
    if (type == 'g') return const TerminalAccessoryAction(type: 'key');
    if (kind == 'text') {
      final suffix = send.endsWith('\r\n')
          ? 2
          : (send.endsWith('\n') || send.endsWith('\r') ? 1 : 0);
      return TerminalAccessoryAction(
        type: 'text',
        text: suffix == 0 ? send : send.substring(0, send.length - suffix),
        appendEnter: suffix != 0,
      );
    }
    final upper = send.toUpperCase();
    if (upper == 'PASTE') return const TerminalAccessoryAction(type: 'paste');
    if (upper == 'META') {
      return TerminalAccessoryAction(type: 'unsupported', key: send);
    }
    if (const ['CTRL', 'ALT', 'SHIFT', 'FN'].contains(upper)) {
      return TerminalAccessoryAction(type: 'modifier', key: upper);
    }
    var rest = send;
    final mods = <String>[];
    while (true) {
      final prefix = RegExp(
        r'^(Ctrl|Alt|Shift|Meta|Fn)\+',
        caseSensitive: false,
      ).firstMatch(rest);
      if (prefix == null) break;
      final mod = prefix[1]!.toUpperCase();
      if (!mods.contains(mod)) mods.add(mod);
      rest = rest.substring(prefix.end);
    }
    if (mods.contains('META') || mods.contains('FN')) {
      return TerminalAccessoryAction(type: 'unsupported', key: send);
    }
    return TerminalAccessoryAction(
      type: 'key',
      key: normalizeKey(rest),
      modifiers: List.unmodifiable(mods),
    );
  }

  factory TerminalAccessoryAction.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final key = json['key'] ?? '';
    final text = json['text'] ?? '';
    final enter = json['appendEnter'] ?? false;
    final mods = json['modifiers'] ?? const <String>[];
    if (!const [
          'key',
          'modifier',
          'paste',
          'keyboard',
          'more',
          'text',
          'unsupported',
        ].contains(type) ||
        key is! String ||
        text is! String ||
        enter is! bool ||
        mods is! List ||
        mods.any((m) => !const ['CTRL', 'ALT', 'SHIFT'].contains(m))) {
      throw const FormatException('TERMINAL_GRID_ACTION_INVALID');
    }
    if (type == 'modifier' &&
        !const ['CTRL', 'ALT', 'SHIFT', 'FN'].contains(key)) {
      throw const FormatException('TERMINAL_GRID_ACTION_INVALID');
    }
    return TerminalAccessoryAction(
      type: type as String,
      key: key,
      modifiers: List<String>.unmodifiable(mods.cast<String>().toSet()),
      text: text,
      appendEnter: enter,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'key': key,
    'modifiers': modifiers,
    'text': text,
    'appendEnter': appendEnter,
  };
}

class AccessoryItem {
  String id;
  String t;
  String l;
  String s;
  int w;
  int h;
  int c;
  int r;
  int p;
  String kind;
  bool m;
  int arrow;
  final TerminalAccessoryAction action;

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
    TerminalAccessoryAction? action,
  }) : s = s ?? l,
       action =
           action ??
           TerminalAccessoryAction.fromLegacy(
             s ?? l,
             type: t,
             kind: kind,
             modifier: m,
           );

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
    TerminalAccessoryAction? action,
  }) => AccessoryItem(
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
    action: action ?? this.action,
  );

  factory AccessoryItem.fromJson(Map<String, dynamic> json) {
    int integer(String key, int fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! num || !value.isFinite || value.toInt() != value) {
        throw const FormatException('TERMINAL_GRID_INVALID');
      }
      return value.toInt();
    }

    if (json['id'] is! String ||
        json['l'] is! String ||
        (json['s'] != null && json['s'] is! String) ||
        (json['t'] != null && json['t'] is! String) ||
        (json['kind'] != null && json['kind'] is! String) ||
        (json['m'] != null && json['m'] is! bool)) {
      throw const FormatException('TERMINAL_GRID_INVALID');
    }
    if (json['action'] != null && json['action'] is! Map) {
      throw const FormatException('TERMINAL_GRID_ACTION_INVALID');
    }
    return AccessoryItem(
      id: json['id'] as String,
      t: json['t'] as String? ?? 'k',
      l: json['l'] as String,
      s: json['s'] as String?,
      w: integer('w', 1),
      h: integer('h', 1),
      c: integer('c', 0),
      r: integer('r', 0),
      p: integer('p', 0),
      kind: json['kind'] as String? ?? 'key',
      m: json['m'] as bool? ?? false,
      arrow: integer('arrow', 0),
      action: json['action'] == null
          ? null
          : TerminalAccessoryAction.fromJson(
              Map<String, dynamic>.from(json['action'] as Map),
            ),
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
    'action': action.toJson(),
  };
}

int accessoryColumnsForWidth(double width, {double minCellWidth = 44}) {
  if (!width.isFinite ||
      width <= 8 ||
      !minCellWidth.isFinite ||
      minCellWidth < 44) {
    throw ArgumentError('Invalid accessory width');
  }
  return ((width - 8) / minCellWidth).floor().clamp(4, kAccessoryCols);
}

AccessoryItem getEffectivePos(
  AccessoryItem item,
  int rows, {
  int columns = kAccessoryCols,
}) {
  if (item.t == 'i') {
    return item.copyWith(c: columns - 1, r: rows - 1, w: 1, h: 1);
  }
  if (item.t == 'more') {
    return item.copyWith(
      c: rows == 1 ? columns - 2 : columns - 1,
      r: rows == 1 ? 0 : rows - 2,
      w: 1,
      h: 1,
    );
  }
  return item;
}

bool _reserved(int c, int r, int w, int h, int rows, int columns) {
  bool covers(int x, int y) => c <= x && x < c + w && r <= y && y < r + h;
  return covers(columns - 1, rows - 1) ||
      covers(rows == 1 ? columns - 2 : columns - 1, rows == 1 ? 0 : rows - 2);
}

bool isItemVisible(AccessoryItem item, int page) =>
    item.t == 'i' || item.t == 'more' || item.p == page;

bool checkCollision(
  List<AccessoryItem> items,
  AccessoryItem? ignoreItem,
  int c,
  int r,
  int w,
  int h,
  int page,
  int rows, {
  int columns = kAccessoryCols,
}) {
  if (c < 0 ||
      r < 0 ||
      c + w > columns ||
      r + h > rows ||
      _reserved(c, r, w, h, rows, columns)) {
    return true;
  }
  return items.any((item) {
    if (identical(item, ignoreItem) ||
        item.id == ignoreItem?.id ||
        item.t == 'i' ||
        item.t == 'more' ||
        item.p != page) {
      return false;
    }
    return c < item.c + item.w &&
        c + w > item.c &&
        r < item.r + item.h &&
        r + h > item.r;
  });
}

List<int>? findFreeSpot(
  List<AccessoryItem> items,
  int w,
  int h,
  int page,
  int rows, {
  int columns = kAccessoryCols,
}) {
  for (var r = 0; r <= rows - h; r++) {
    for (var c = 0; c <= columns - w; c++) {
      if (!checkCollision(
        items,
        null,
        c,
        r,
        w,
        h,
        page,
        rows,
        columns: columns,
      )) {
        return [c, r];
      }
    }
  }
  return null;
}

List<AccessoryItem> createDefaultAccessoryItems() {
  final keys = <AccessoryItem>[];
  for (final (index, label) in [
    'ESC',
    'TAB',
    'CTRL',
    'PASTE',
    'ALT',
    'SHIFT',
    'FN',
    '/',
  ].indexed) {
    keys.add(
      AccessoryItem(
        id: 'default-$index',
        l: label,
        c: index % 4,
        r: index ~/ 4,
      ),
    );
  }
  keys.add(
    AccessoryItem(id: 'arrows', t: 'g', l: 'arrows', c: 4, r: 0, w: 3, h: 2),
  );
  const more = [
    'HOME',
    'END',
    'PGUP',
    'PGDN',
    'INSERT',
    'DELETE',
    'Ctrl+C',
    'Ctrl+D',
    'Ctrl+Z',
    'Ctrl+L',
    'Ctrl+R',
    'Ctrl+A',
    'Ctrl+E',
    'Ctrl+U',
    'Ctrl+W',
  ];
  for (final (index, label) in more.indexed) {
    keys.add(
      AccessoryItem(
        id: 'extra-$index',
        l: label,
        p: 1,
        c: index % 7,
        r: index ~/ 7,
        kind: label.contains('+') ? 'combo' : 'key',
      ),
    );
  }
  // Fourteen slots are available on a two-row page; spill the final extra key.
  keys.last.p = 2;
  keys.last.c = 0;
  keys.last.r = 0;
  return keys;
}

class TerminalAccessoryLayout {
  final List<AccessoryItem> items;
  final int rows;
  final int pages;
  final int columns;
  final int? directionSeedColor;

  TerminalAccessoryLayout({
    required this.items,
    this.rows = 2,
    this.pages = 2,
    this.columns = 8,
    this.directionSeedColor,
  });

  factory TerminalAccessoryLayout.defaultLayout() =>
      TerminalAccessoryLayout(items: createDefaultAccessoryItems(), pages: 3);

  factory TerminalAccessoryLayout.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] ?? 1;
    if (version != 1 && version != 2) {
      throw const FormatException('TERMINAL_GRID_VERSION_UNSUPPORTED');
    }
    int integer(String key, int fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! num || !value.isFinite || value.toInt() != value) {
        throw const FormatException('TERMINAL_GRID_INVALID');
      }
      return value.toInt();
    }

    final rawItems = json['items'];
    if (rawItems is! List ||
        rawItems.length > 1024 ||
        rawItems.any((entry) => entry is! Map)) {
      throw const FormatException('TERMINAL_GRID_INVALID');
    }
    final color = json['directionSeedColor'];
    if (color != null && color is! int) {
      throw const FormatException('TERMINAL_GRID_INVALID');
    }
    final result = TerminalAccessoryLayout(
      items: rawItems
          .map(
            (entry) =>
                AccessoryItem.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
      rows: integer('rows', 2),
      pages: integer('np', 2),
      columns: integer('columns', 8),
      directionSeedColor: color as int?,
    );
    result.validate();
    return result;
  }

  void validate({bool enforceSystemSlots = false}) {
    if (rows < 1 ||
        rows > 5 ||
        columns < 3 ||
        columns > 8 ||
        pages < 1 ||
        pages > 1024 ||
        items.length > 1024 ||
        (directionSeedColor != null &&
            (directionSeedColor! < 0xff000000 ||
                directionSeedColor! > 0xffffffff))) {
      throw const FormatException('TERMINAL_GRID_INVALID');
    }
    final ids = <String>{};
    final occupied = <String>{};
    for (final item in items) {
      if (item.id.isEmpty ||
          !ids.add(item.id) ||
          !const ['k', 'g', 'i', 'more'].contains(item.t) ||
          !const ['key', 'combo', 'text'].contains(item.kind)) {
        throw const FormatException('TERMINAL_GRID_INVALID');
      }
      TerminalAccessoryAction.fromJson(item.action.toJson());
      if (item.t == 'i' || item.t == 'more') continue;
      if (item.w < 1 ||
          item.w > 3 ||
          item.h < 1 ||
          item.h > 2 ||
          item.c < 0 ||
          item.r < 0 ||
          item.p < 0 ||
          item.c + item.w > columns ||
          item.r + item.h > rows ||
          item.p >= pages ||
          (item.t == 'g' && (item.w != 3 || item.h != 2)) ||
          (enforceSystemSlots &&
              _reserved(item.c, item.r, item.w, item.h, rows, columns))) {
        throw const FormatException('TERMINAL_GRID_INVALID');
      }
      for (var r = item.r; r < item.r + item.h; r++) {
        for (var c = item.c; c < item.c + item.w; c++) {
          if (!occupied.add('${item.p}:$r:$c')) {
            throw const FormatException('TERMINAL_GRID_COLLISION');
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'rows': rows,
    'np': pages,
    'columns': columns,
    'directionSeedColor': directionSeedColor,
    'items': items.map((item) => item.toJson()).toList(),
  };

  TerminalAccessoryLayout copy() => TerminalAccessoryLayout.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );

  TerminalAccessoryLayout copyWith({
    List<AccessoryItem>? items,
    int? rows,
    int? pages,
    int? columns,
    int? directionSeedColor,
    bool clearDirectionSeedColor = false,
  }) => TerminalAccessoryLayout(
    items: items ?? this.items.map((item) => item.copyWith()).toList(),
    rows: rows ?? this.rows,
    pages: pages ?? this.pages,
    columns: columns ?? this.columns,
    directionSeedColor: clearDirectionSeedColor
        ? null
        : directionSeedColor ?? this.directionSeedColor,
  );

  bool hasSameContent(TerminalAccessoryLayout other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  /// A view-only projection: neither the source items nor the persisted layout change.
  TerminalAccessoryLayout project(int columns, {int? rows}) {
    validate();
    rows ??= this.rows;
    if (rows < 1 || rows > 5) throw ArgumentError('Invalid accessory rows');
    if (columns < 3 || columns > 8) {
      throw ArgumentError('Invalid accessory columns');
    }
    final result = <AccessoryItem>[];
    var destinationPage = 0;
    for (var sourcePage = 0; sourcePage < pages; sourcePage++) {
      final sourceItems =
          items
              .where(
                (item) =>
                    item.t != 'i' && item.t != 'more' && item.p == sourcePage,
              )
              .toList()
            ..sort((a, b) {
              final area = (b.w * b.h).compareTo(a.w * a.h);
              if (area != 0) return area;
              final row = a.r.compareTo(b.r);
              if (row != 0) return row;
              final col = a.c.compareTo(b.c);
              return col != 0 ? col : a.id.compareTo(b.id);
            });
      final firstPage = destinationPage;
      for (final item in sourceItems) {
        if (findFreeSpot(const [], item.w, item.h, 0, rows, columns: columns) ==
            null) {
          throw const FormatException('TERMINAL_GRID_ITEM_TOO_LARGE');
        }
        var page = firstPage;
        List<int>? spot;
        while (spot == null) {
          final candidates = <List<int>>[];
          for (var r = 0; r <= rows - item.h; r++) {
            for (var c = 0; c <= columns - item.w; c++) {
              if (!checkCollision(
                result,
                null,
                c,
                r,
                item.w,
                item.h,
                page,
                rows,
                columns: columns,
              )) {
                candidates.add([c, r]);
              }
            }
          }
          candidates.sort((a, b) {
            final da = (a[0] - item.c).abs() + (a[1] - item.r).abs();
            final db = (b[0] - item.c).abs() + (b[1] - item.r).abs();
            if (da != db) return da.compareTo(db);
            final row = a[1].compareTo(b[1]);
            return row != 0 ? row : a[0].compareTo(b[0]);
          });
          spot = candidates.firstOrNull;
          if (spot == null) page++;
        }
        destinationPage = math.max(destinationPage, page);
        result.add(item.copyWith(c: spot[0], r: spot[1], p: page));
      }
      destinationPage++;
    }
    for (final system in items.where(
      (item) => item.t == 'i' || item.t == 'more',
    )) {
      result.add(
        getEffectivePos(system, rows, columns: columns).copyWith(p: 0),
      );
    }
    return TerminalAccessoryLayout(
      items: result,
      rows: rows,
      pages: destinationPage,
      columns: columns,
      directionSeedColor: directionSeedColor,
    );
  }
}

bool canSwapAccessoryItems(
  List<AccessoryItem> items,
  AccessoryItem first,
  AccessoryItem second,
  int rows, {
  int columns = kAccessoryCols,
}) {
  if (first.id == second.id ||
      first.p != second.p ||
      first.w != second.w ||
      first.h != second.h ||
      first.t == 'i' ||
      first.t == 'more' ||
      second.t == 'i' ||
      second.t == 'more') {
    return false;
  }
  final others = items
      .where((item) => item.id != first.id && item.id != second.id)
      .toList();
  return !checkCollision(
        others,
        null,
        second.c,
        second.r,
        first.w,
        first.h,
        first.p,
        rows,
        columns: columns,
      ) &&
      !checkCollision(
        others,
        null,
        first.c,
        first.r,
        second.w,
        second.h,
        second.p,
        rows,
        columns: columns,
      );
}
