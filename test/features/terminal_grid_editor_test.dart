import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';

import '../support/terminal_grid_harness.dart';

class _GridStorage extends LocalStorageService {
  _GridStorage(super.prefs);

  int saves = 0;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> setTerminalGridConfig(String json) async {
    saves++;
    await gate?.future;
    if (fail) throw StateError('simulated storage failure');
    await super.setTerminalGridConfig(json);
  }
}

void main() {
  setUpAll(loadTerminalGridFonts);
  late _GridStorage storage;
  late List<String> sent;

  Future<void> editTab(WidgetTester tester) async {
    sent = [];
    await pumpTerminalGrid(
      tester,
      sent: sent,
      layout: TerminalAccessoryLayout(
        pages: 1,
        items: [AccessoryItem(id: 'tab', l: 'Tab', s: 'TAB')],
      ),
      storageFactory: (prefs) => storage = _GridStorage(prefs),
    );
    await enterTerminalGridEditor(tester);
    await tester.tap(terminalGridKey('TAB'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  }

  final save = find.byKey(const Key('terminal_grid_save_button'));

  testWidgets('ordinary long press does not enter layout editing', (
    tester,
  ) async {
    await pumpTerminalGrid(
      tester,
      layout: TerminalAccessoryLayout(
        pages: 1,
        items: [AccessoryItem(id: 'escape', l: 'ESC', s: 'ESC')],
      ),
      storageFactory: (prefs) => storage = _GridStorage(prefs),
    );
    await tester.longPress(terminalGridKey('ESC'));
    await tester.pumpAndSettle();
    expect(save, findsNothing);
    expect(storage.saves, 0);
  });

  testWidgets(
    'direction group can move to another page without splitting or sending',
    (tester) async {
      sent = [];
      await pumpTerminalGrid(
        tester,
        sent: sent,
        layout: TerminalAccessoryLayout(
          pages: 2,
          items: [AccessoryItem(id: 'arrows', t: 'g', l: 'arrows', w: 3, h: 2)],
        ),
        storageFactory: (prefs) => storage = _GridStorage(prefs),
      );
      await enterTerminalGridEditor(tester);
      final group = find.byKey(const Key('terminal_direction_pad'));
      await tester.tapAt(tester.getTopLeft(group) + const Offset(10, 10));
      await tester.pumpAndSettle();
      // The first chevron selects the preview page; the property chevron moves
      // the selected group. Persisted p below proves this isn't mere navigation.
      final next = find.text('›').last;
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(group, findsOneWidget);
      expect(storage.saves, 0);
      expect(sent, isEmpty);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = TerminalAccessoryLayout.fromJson(
        jsonDecode(storage.getTerminalGridConfig()!) as Map<String, dynamic>,
      );
      final arrows = saved.items.single;
      expect(arrows.p, 1);
      expect(arrows.t, 'g');
      expect(arrows.w, 3);
      expect(arrows.h, 2);
      saved.validate(enforceSystemSlots: true);
    },
  );

  testWidgets('cancel dirty draft keeps saved bytes and emits no input', (
    tester,
  ) async {
    await editTab(tester);
    final original = storage.getTerminalGridConfig();
    await tester.enterText(find.byType(TextField).first, 'My Tab');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(save, findsNothing);
    expect(storage.saves, 0);
    expect(storage.getTerminalGridConfig(), original);
    expect(sent, isEmpty);
  });

  testWidgets(
    'undo restores selected key and property controller, without input',
    (tester) async {
      await editTab(tester);
      await tester.enterText(find.byType(TextField).first, 'My Tab');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Tab',
      );
      expect(find.text('My Tab'), findsNothing);
      expect(sent, isEmpty);
      expect(storage.saves, 0);
    },
  );

  testWidgets('failed save preserves draft and persisted configuration', (
    tester,
  ) async {
    await editTab(tester);
    final original = storage.getTerminalGridConfig();
    storage.fail = true;
    await tester.enterText(find.byType(TextField).first, 'My Tab');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(save, findsOneWidget);
    expect(find.text('Failed to save accessory bar layout'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'My Tab',
    );
    expect(storage.getTerminalGridConfig(), original);
    expect(storage.saves, 1);
    expect(sent, isEmpty);
  });

  testWidgets('busy save is single-flight, commits snapshot and exits once', (
    tester,
  ) async {
    await editTab(tester);
    final original = storage.getTerminalGridConfig();
    storage.gate = Completer<void>();
    await tester.enterText(find.byType(TextField).first, 'My Tab');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(storage.saves, 1);
    expect(storage.getTerminalGridConfig(), original);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(save, findsNothing);
    expect(storage.saves, 1);
    final saved = TerminalAccessoryLayout.fromJson(
      // Decoding through the public model also validates the persisted action.
      jsonDecode(storage.getTerminalGridConfig()!) as Map<String, dynamic>,
    );
    expect(saved.items.single.l, 'My Tab');
    expect(saved.items.single.action.key, 'TAB');
    expect(sent, isEmpty);
  });

  testWidgets('drag swaps same-size keys and persists only on explicit save', (
    tester,
  ) async {
    sent = [];
    await pumpTerminalGrid(
      tester,
      sent: sent,
      layout: TerminalAccessoryLayout(
        pages: 1,
        items: [
          AccessoryItem(id: 'escape', l: 'ESC', s: 'ESC'),
          AccessoryItem(id: 'tab', l: 'Tab', s: 'TAB', c: 1),
        ],
      ),
      storageFactory: (prefs) => storage = _GridStorage(prefs),
    );
    await enterTerminalGridEditor(tester);
    final escape = terminalGridKey('ESC');
    final tab = terminalGridKey('TAB');
    final beforeEscape = tester.getCenter(escape);
    final beforeTab = tester.getCenter(tab);
    final gesture = await tester.startGesture(beforeEscape);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(beforeTab - beforeEscape);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(escape), beforeTab);
    expect(tester.getCenter(tab), beforeEscape);
    expect(storage.saves, 0);
    expect(sent, isEmpty);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = TerminalAccessoryLayout.fromJson(
      jsonDecode(storage.getTerminalGridConfig()!) as Map<String, dynamic>,
    );
    expect(saved.items.firstWhere((item) => item.id == 'escape').c, 1);
    expect(saved.items.firstWhere((item) => item.id == 'tab').c, 0);
    expect(storage.saves, 1);
  });
}
