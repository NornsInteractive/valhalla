import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/terminal_accessory_layout.dart';

void main() {
  group('TerminalAccessoryLayout - pure model regression', () {
    test('fromLegacy Ctrl+Alt+C: key+C with CTRL+ALT modifiers', () {
      final a = TerminalAccessoryAction.fromLegacy('Ctrl+Alt+C');
      expect(a.type, 'key');
      expect(a.modifiers.contains('CTRL'), true);
      expect(a.modifiers.contains('ALT'), true);
      expect(a.key, 'C');
      expect(a.supported, true);
    });

    test('fromLegacy Meta returns unsupported and not supported', () {
      final a = TerminalAccessoryAction.fromLegacy('Meta');
      expect(a.type, 'unsupported');
      expect(a.supported, false);
    });

    test('AccessoryItem.copyWith only changes specified fields', () {
      final it = AccessoryItem(id: 'k1', l: 'A', s: 'A');
      final c = it.copyWith(l: 'B');
      expect(c.id, 'k1');
      expect(c.l, 'B');
      expect(c.s, it.s);
      expect(c.action.toJson(), it.action.toJson());
    });

    test(
      'default project(7) normal with arrows preserved; simple keys project(7,rows:1) valid and source unchanged',
      () {
        final d = TerminalAccessoryLayout.defaultLayout();
        d.validate();
        final p7 = d.project(7);
        expect(p7.columns, 7);
        expect(p7.rows, d.rows);
        expect(p7.items.any((e) => e.t == 'g'), true);
        p7.validate();

        // direction group 3x2 cannot fit in 1 row
        expect(() => d.project(7, rows: 1), throwsA(isA<FormatException>()));

        // simple layout projects to rows:1 and does not mutate source
        final src = TerminalAccessoryLayout(
          items: [
            AccessoryItem(id: 'a', l: 'A', c: 0, r: 0),
            AccessoryItem(id: 'b', l: 'B', c: 1, r: 0),
          ],
          rows: 2,
          pages: 1,
          columns: 8,
        );
        final before = src.toJson();
        final ps1 = src.project(7, rows: 1);
        expect(ps1.rows, 1);
        expect(ps1.columns, 7);
        expect(jsonEncode(before), jsonEncode(src.toJson()));
        ps1.validate();
      },
    );

    test('validate throws on duplicate ids', () {
      final items = [
        AccessoryItem(id: 'a', l: 'A', c: 0, r: 0),
        AccessoryItem(id: 'a', l: 'B', c: 1, r: 0),
      ];
      final lay = TerminalAccessoryLayout(
        items: items,
        rows: 2,
        pages: 1,
        columns: 8,
      );
      expect(() => lay.validate(), throwsA(isA<FormatException>()));
    });

    test('validate throws on collision in same page/cell', () {
      final items = [
        AccessoryItem(id: 'a', l: 'A', c: 0, r: 0, w: 1, h: 1),
        AccessoryItem(id: 'b', l: 'B', c: 0, r: 0, w: 1, h: 1),
      ];
      final lay = TerminalAccessoryLayout(
        items: items,
        rows: 2,
        pages: 1,
        columns: 8,
      );
      expect(() => lay.validate(), throwsA(isA<FormatException>()));
    });

    test(
      'canSwapAccessoryItems requires same id different items, same p/size and non-system',
      () {
        final a = AccessoryItem(id: 'a', l: 'A', c: 0, r: 0, w: 1, h: 1, p: 0);
        final b = AccessoryItem(id: 'b', l: 'B', c: 1, r: 0, w: 1, h: 1, p: 0);
        final items = [a, b];
        expect(canSwapAccessoryItems(items, a, b, 2, columns: 8), true);
        expect(canSwapAccessoryItems(items, a, a, 2, columns: 8), false);
        expect(
          canSwapAccessoryItems(
            [a, b.copyWith(p: 1)],
            a,
            b.copyWith(p: 1),
            2,
            columns: 8,
          ),
          false,
        );
      },
    );

    test('fromJson roundtrip minimal preserves core fields', () {
      final src = TerminalAccessoryLayout(
        items: [
          AccessoryItem(id: 'x', l: 'TAB', c: 0, r: 0),
          AccessoryItem(id: 'y', l: 'ESC', c: 1, r: 0),
        ],
        rows: 2,
        pages: 1,
        columns: 8,
      );
      final j = src.toJson();
      final rt = TerminalAccessoryLayout.fromJson(j);
      expect(rt.rows, src.rows);
      expect(rt.pages, src.pages);
      expect(rt.columns, src.columns);
      expect(rt.items.length, src.items.length);
      expect(rt.items.first.id, 'x');
      expect(rt.items.last.id, 'y');
    });

    test(
      'copyWith replaces items by new list (no shared mutable identity assumption)',
      () {
        final it = AccessoryItem(id: 'm', l: 'M');
        final lay = TerminalAccessoryLayout(
          items: [it],
          rows: 1,
          pages: 1,
          columns: 8,
        );
        final lay2 = lay.copyWith(items: [it.copyWith(l: 'MM')]);
        expect(lay2.items.first.l, 'MM');
        expect(lay.items.first.l, 'M');
      },
    );

    test('project enforces column/row bounds (throws on invalid)', () {
      final lay = TerminalAccessoryLayout(
        items: const [],
        rows: 2,
        pages: 1,
        columns: 8,
      );
      expect(() => lay.project(2), throwsA(isA<ArgumentError>()));
      expect(() => lay.project(9), throwsA(isA<ArgumentError>()));
      expect(() => lay.project(7, rows: 6), throwsA(isA<ArgumentError>()));
    });

    test('width mapping: 320->7 cols, 360->8 cols', () {
      expect(accessoryColumnsForWidth(320), 7);
      expect(accessoryColumnsForWidth(360), 8);
    });

    test('Shift+Tab and Del/Space aliases', () {
      final st = TerminalAccessoryAction.fromLegacy('Shift+Tab');
      expect(st.modifiers.contains('SHIFT'), true);
      expect(st.key, 'TAB');

      final del = TerminalAccessoryAction.fromLegacy('Del');
      expect(del.key, 'DELETE');

      final sp = TerminalAccessoryAction.fromLegacy('Space');
      expect(sp.key, ' ');
    });

    test('text appendEnter preserved; macro default appendEnter false', () {
      final tnl = TerminalAccessoryAction.fromLegacy('abc\n', kind: 'text');
      expect(tnl.type, 'text');
      expect(tnl.text, 'abc');
      expect(tnl.appendEnter, true);

      final trn = TerminalAccessoryAction.fromLegacy('def\r\n', kind: 'text');
      expect(trn.text, 'def');
      expect(trn.appendEnter, true);

      final tplain = TerminalAccessoryAction.fromLegacy('ghi', kind: 'text');
      expect(tplain.text, 'ghi');
      expect(tplain.appendEnter, false);

      final macro = TerminalAccessoryAction(type: 'text', text: 'x');
      expect(macro.appendEnter, false);
    });

    test('empty items layout is valid', () {
      final lay = TerminalAccessoryLayout(
        items: const [],
        rows: 2,
        pages: 1,
        columns: 8,
      );
      lay.validate();
      expect(lay.items.isEmpty, true);
    });

    test(
      '7/8 projection preserves IDs/actions, no source change, reserve slots/collision ok',
      () {
        final items = [
          AccessoryItem(id: 'k1', l: 'A', c: 0, r: 0, p: 0),
          AccessoryItem(id: 'k2', l: 'B', c: 1, r: 0, p: 0),
          AccessoryItem(id: 'k3', l: 'C', c: 2, r: 0, p: 0),
          AccessoryItem(id: 'k4', l: 'D', c: 3, r: 0, p: 0),
          AccessoryItem(id: 'k5', l: 'E', c: 0, r: 1, p: 0),
          AccessoryItem(id: 'sys', t: 'i', l: 'kbd', c: 7, r: 1, p: 0),
          AccessoryItem(id: 'more', t: 'more', l: 'more', c: 6, r: 0, p: 0),
        ];
        final src = TerminalAccessoryLayout(
          items: items,
          rows: 2,
          pages: 1,
          columns: 8,
        );
        src.validate();
        final before = src.toJson();
        final p7 = src.project(7);
        expect(p7.columns, 7);
        expect(
          p7.items.map((e) => e.id).toSet(),
          containsAll(['k1', 'k2', 'k3', 'k4', 'k5', 'sys', 'more']),
        );
        for (final id in ['k1', 'k2', 'k3', 'k4', 'k5']) {
          final sp = src.items.firstWhere((e) => e.id == id);
          final pp = p7.items.firstWhere((e) => e.id == id);
          expect(pp.action.toJson(), sp.action.toJson());
          expect(pp.l, sp.l);
        }
        expect(jsonEncode(before), jsonEncode(src.toJson()));
        p7.validate();

        final p8 = src.project(8);
        expect(p8.columns, 8);
        expect(p8.items.map((e) => e.id).length, src.items.length);
        for (final id in ['k1', 'k2', 'k3', 'k4', 'k5']) {
          final pp = p8.items.firstWhere((e) => e.id == id);
          final sp = src.items.firstWhere((e) => e.id == id);
          expect(pp.action.toJson(), sp.action.toJson());
        }
        expect(jsonEncode(before), jsonEncode(src.toJson()));
        p8.validate();
      },
    );

    test(
      'project(3) with direction group throws timely (no infinite loop)',
      () {
        final d = TerminalAccessoryLayout.defaultLayout();
        d.validate();
        expect(() => d.project(3), throwsA(isA<FormatException>()));
        expect(() => d.project(3, rows: 1), throwsA(isA<FormatException>()));
        expect(() => d.project(3, rows: 2), throwsA(isA<FormatException>()));
      },
    );
  });
}
