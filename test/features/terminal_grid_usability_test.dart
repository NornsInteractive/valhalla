import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _KeySpy {
  final calls = <Map<String, Object?>>[];
  void call(
    String key, {
    bool isCtrl = false,
    bool isAlt = false,
    bool isShift = false,
  }) => calls.add({
    'key': key,
    'isCtrl': isCtrl,
    'isAlt': isAlt,
    'isShift': isShift,
  });
}

class _TextSpy {
  final calls = <Map<String, Object?>>[];
  void call(String text, {bool appendEnter = false}) =>
      calls.add({'text': text, 'appendEnter': appendEnter});
}

class _ListSpy {
  final calls = <String>[];
  void call([String value = '']) => calls.add(value);
}

class _ModifierSpy {
  final down = <String>[];
  final up = <String>[];
}

void _viewSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpBar(
  WidgetTester tester,
  TerminalAccessoryLayout layout, {
  required _KeySpy onKey,
  required _TextSpy onText,
  _ListSpy? toggleCtrl,
  _ListSpy? toggleAlt,
  _ListSpy? toggleShift,
  _ListSpy? toggleFn,
  _ListSpy? paste,
  _ListSpy? toggleKeyboard,
  _ModifierSpy? modifiers,
}) async {
  SharedPreferences.setMockInitialValues({
    'valhalla_terminal_grid_v2': jsonEncode(layout.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final mod = modifiers ?? _ModifierSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              TerminalAccessoryBar(
                onKey: onKey.call,
                onText: onText.call,
                onToggleCtrl: toggleCtrl?.call ?? () {},
                onToggleAlt: toggleAlt?.call ?? () {},
                onToggleShift: toggleShift?.call ?? () {},
                onToggleFn: toggleFn?.call ?? () {},
                onPaste: paste?.call ?? () {},
                onToggleKeyboard: toggleKeyboard?.call ?? () {},
                onModifierDown: mod.down.add,
                onModifierUp: mod.up.add,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _upArrowCenter(WidgetTester tester) {
  final g = tester.getRect(
    find.byKey(const Key('terminal_accessory_key_ARROWS')),
  );
  return Offset(g.left + g.width * 0.5, g.top + g.height * 0.25);
}

void main() {
  setUpAll(() async {
    final mono = FontLoader('JetBrains Mono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-400.ttf'))
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-600.ttf'));
    await mono.load();
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-400.ttf'));
    await inter.load();
  });

  testWidgets('default keyboard geometry at 320 and 360', (tester) async {
    for (final (width, columns) in [(320.0, 7), (360.0, 8)]) {
      _viewSize(tester, width);
      final onKey = _KeySpy();
      final onText = _TextSpy();
      await _pumpBar(
        tester,
        TerminalAccessoryLayout.defaultLayout(),
        onKey: onKey,
        onText: onText,
      );
      final rect = tester.getRect(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
      );
      expect(rect.width, closeTo((width - 8) / columns, 0.01));
      expect(rect.height, 44);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('keyboard button accepts tap 0.5px from left edge', (
    tester,
  ) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    final keyboard = _ListSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout.defaultLayout(),
      onKey: onKey,
      onText: onText,
      toggleKeyboard: keyboard,
    );
    final rect = tester.getRect(
      find.byKey(const Key('terminal_accessory_keyboard_button')),
    );
    await tester.tapAt(rect.topLeft + Offset(0.5, rect.height / 2));
    await tester.pump();
    expect(keyboard.calls, hasLength(1));
  });

  testWidgets('two Tab items sharing a label do not throw duplicate keys', (
    tester,
  ) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout(
        items: [
          AccessoryItem(id: 'tab-a', l: 'Tab', c: 0, r: 0),
          AccessoryItem(id: 'tab-b', l: 'Tab', c: 1, r: 0),
        ],
        pages: 1,
      ),
      onKey: onKey,
      onText: onText,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Tab'), findsNWidgets(2));
  });

  testWidgets('renamed Ctrl item still reports modifier CTRL', (tester) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    final modifiers = _ModifierSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout(
        items: [
          AccessoryItem(id: 'mod-ctrl', l: 'MyCtrl', s: 'Ctrl', c: 0, r: 0),
        ],
        pages: 1,
      ),
      onKey: onKey,
      onText: onText,
      modifiers: modifiers,
    );
    await tester.tap(find.text('MyCtrl'));
    await tester.pump();
    expect(modifiers.down, contains('CTRL'));
    expect(modifiers.up, contains('CTRL'));
    expect(onKey.calls, isEmpty);
  });

  testWidgets('Shift+Tab sends TAB with isShift', (tester) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout(
        items: [
          AccessoryItem(
            id: 'shift-tab',
            l: 'S-Tab',
            s: 'Shift+Tab',
            c: 0,
            r: 0,
          ),
        ],
        pages: 1,
      ),
      onKey: onKey,
      onText: onText,
    );
    await tester.tap(find.text('S-Tab'));
    await tester.pump();
    expect(onKey.calls, hasLength(1));
    expect(onKey.calls.single['key'], 'TAB');
    expect(onKey.calls.single['isShift'], true);
  });

  testWidgets('macro item routes only through onText', (tester) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout(
        items: [
          AccessoryItem(
            id: 'macro-ls',
            l: 'LS',
            s: 'ls -la\r\n',
            kind: 'text',
            c: 0,
            r: 0,
          ),
        ],
        pages: 1,
      ),
      onKey: onKey,
      onText: onText,
    );
    await tester.tap(find.text('LS'));
    await tester.pump();
    expect(onText.calls, hasLength(1));
    expect(onText.calls.single['text'], 'ls -la');
    expect(onText.calls.single['appendEnter'], true);
    expect(onKey.calls, isEmpty);
  });

  testWidgets('fast horizontal drag on default up arrow does not send', (
    tester,
  ) async {
    _viewSize(tester, 360);
    final onKey = _KeySpy();
    final onText = _TextSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout.defaultLayout(),
      onKey: onKey,
      onText: onText,
    );
    final gesture = await tester.startGesture(_upArrowCenter(tester));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(onKey.calls, isEmpty);
  });

  testWidgets('long press up sends, then stops after inactive/resumed', (
    tester,
  ) async {
    _viewSize(tester, 360);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    final onKey = _KeySpy();
    final onText = _TextSpy();
    await _pumpBar(
      tester,
      TerminalAccessoryLayout.defaultLayout(),
      onKey: onKey,
      onText: onText,
    );
    final target = _upArrowCenter(tester);
    final first = await tester.startGesture(target);
    await tester.pump(const Duration(milliseconds: 300));
    final countAfterPress = onKey.calls.length;
    expect(countAfterPress, greaterThan(0));
    expect(onKey.calls.first['key'], '↑');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(onKey.calls.length, countAfterPress);
    await first.up();
    await tester.pumpAndSettle();
    expect(onKey.calls.length, countAfterPress);
    final second = await tester.startGesture(target);
    await tester.pump(const Duration(milliseconds: 300));
    await second.up();
    await tester.pumpAndSettle();
    expect(onKey.calls.length, greaterThan(countAfterPress));
  });
}
