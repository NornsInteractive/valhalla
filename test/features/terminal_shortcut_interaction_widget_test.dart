import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/terminal_grid_harness.dart';

String _readable(String data) => data
    .replaceAll('\x1b', '<ESC>')
    .replaceAll('\x01', '<SOH>')
    .replaceAll('\x02', '<STX>')
    .replaceAll('\x03', '<ETX>')
    .replaceAll('\t', '<TAB>');

Widget _canvas(Terminal terminal) => ProviderScope(
  overrides: fixedTerminalSettingsOverrides(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: SharedTerminalCanvas(
            terminal: terminal,
            onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
              sendTerminalAccessoryKey(
                terminal,
                key,
                isCtrl: isCtrl,
                isAlt: isAlt,
                isShift: isShift,
              );
            },
            requestKeyboardOnTap: false,
          ),
        ),
      ),
    ),
  ),
);

Widget _canvasWithInput(
  Terminal terminal, {
  required ValueListenable<bool> inputEnabled,
  required void Function(String key, {bool isCtrl, bool isAlt, bool isShift})
  onKey,
}) => ProviderScope(
  overrides: fixedTerminalSettingsOverrides(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ValueListenableBuilder<bool>(
            valueListenable: inputEnabled,
            builder: (context, enabled, _) => SharedTerminalCanvas(
              terminal: terminal,
              inputEnabled: enabled,
              onKey: onKey,
              requestKeyboardOnTap: false,
            ),
          ),
        ),
      ),
    ),
  ),
);

bool Function(String) _inputHook(WidgetTester tester) =>
    tester.widget<TerminalView>(find.byType(TerminalView)).onTextInput!;

TerminalViewState _terminalState(WidgetTester tester) =>
    tester.state<TerminalViewState>(find.byType(TerminalView));

Finder _key(String name) => find.byKey(Key('terminal_accessory_key_$name'));

Finder _arrowSlot() =>
    find.ancestor(of: _key('↑'), matching: find.byType(HoldRepeatKey)).first;

// Grid keys are wrapped in a KeyedSubtree whose nearest render object is the
// zero-offset RenderTransform of the drag/settle wrapper. A RenderTransform
// never adds itself to the hit-test path, so Finder.hitTestable() reports zero
// matches even though the key is on screen and tappable. Assert the key is
// laid out inside the canvas instead, then drive the real gesture.
Future<void> _tapKey(WidgetTester tester, String name) async {
  final finder = _key(name);
  expect(finder, findsOneWidget);
  expect(
    tester.getRect(finder),
    isNot(equals(Rect.zero)),
    reason: 'accessory key $name must be laid out before it is tapped',
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _longPressKey(WidgetTester tester, String name) async {
  final finder = _key(name);
  expect(finder, findsOneWidget);
  expect(
    tester.getRect(finder),
    isNot(equals(Rect.zero)),
    reason: 'accessory key $name must be laid out before it is long-pressed',
  );
  await tester.longPress(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required bool reduced,
  required int seed,
}) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final layout = TerminalAccessoryLayout.defaultLayout().copyWith(
    directionSeedColor: seed,
  );
  SharedPreferences.setMockInitialValues({
    'valhalla_terminal_grid_v2': jsonEncode(layout.toJson()),
  });
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        ...fixedTerminalSettingsOverrides(),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.buildTheme(
          brightness: Brightness.light,
          seedColor: const Color(0xff10b981),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 760),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                TerminalAccessoryBar(
                  onKey:
                      (_, {isCtrl = false, isAlt = false, isShift = false}) {},
                  onToggleCtrl: () {},
                  onToggleAlt: () {},
                  onPaste: () {},
                  onToggleKeyboard: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _arrowColor(WidgetTester tester) {
  final face = tester.widget<Container>(_key('↑'));
  return (face.decoration! as BoxDecoration).color!;
}

void main() {
  setUpAll(loadTerminalGridFonts);

  group('accessory modifiers arm and lock through real gestures', () {
    testWidgets('tap arms Ctrl for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'CTRL');
      expect(hook('a'), isTrue);
      expect(_readable(written.join()), '<SOH>');
      expect(hook('b'), isFalse);

      written.clear();
      await _longPressKey(tester, 'CTRL');
      expect(hook('a'), isTrue);
      expect(hook('b'), isTrue);
      expect(_readable(written.join()), '<SOH><STX>');

      await _tapKey(tester, 'CTRL');
      written.clear();
      expect(hook('c'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Alt for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'ALT');
      expect(hook('a'), isTrue);
      expect(_readable(written.join()), '<ESC>a');
      expect(hook('b'), isFalse);

      written.clear();
      await _longPressKey(tester, 'ALT');
      expect(hook('b'), isTrue);
      expect(hook('c'), isTrue);
      expect(_readable(written.join()), '<ESC>b<ESC>c');

      await _tapKey(tester, 'ALT');
      written.clear();
      expect(hook('d'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Shift for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'SHIFT');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z<TAB>');

      written.clear();
      await _longPressKey(tester, 'SHIFT');
      await _tapKey(tester, 'TAB');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z<ESC>[Z');

      await _tapKey(tester, 'SHIFT');
      written.clear();
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<TAB>');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Fn for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'FN');
      expect(hook('1'), isTrue);
      expect(_readable(written.join()), '<ESC>OP');
      expect(hook('1'), isFalse);

      written.clear();
      await _longPressKey(tester, 'FN');
      expect(hook('1'), isTrue);
      expect(hook('2'), isTrue);
      expect(_readable(written.join()), '<ESC>OP<ESC>OQ');

      await _tapKey(tester, 'FN');
      written.clear();
      expect(hook('3'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'more-panel clear-all resets every modifier without sending bytes',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'CTRL');
      await _tapKey(tester, 'ALT');
      await _tapKey(tester, 'SHIFT');
      await _tapKey(tester, 'FN');

      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.oneShot);
      expect(bar.altState, ModifierLockState.oneShot);
      expect(bar.shiftState, ModifierLockState.oneShot);
      expect(bar.fnState, ModifierLockState.oneShot);
      expect(written, isEmpty);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      final clear = find.byKey(const Key('terminal_clear_modifiers_button'));
      expect(clear, findsOneWidget);
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      expect(clear.hitTestable(), findsOneWidget);

      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(
        written,
        isEmpty,
        reason: 'clear-all must not emit terminal bytes',
      );
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.inactive);
      expect(bar.altState, ModifierLockState.inactive);
      expect(bar.shiftState, ModifierLockState.inactive);
      expect(bar.fnState, ModifierLockState.inactive);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      expect(_inputHook(tester)('a'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissing modifier help never summons the IME',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      final help = find.byKey(const Key('terminal_accessory_help_button'));
      expect(help, findsOneWidget);
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      expect(help.hitTestable(), findsOneWidget);

      await tester.longPress(help);
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.terminalModifierHelp), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text(l10n.terminalModifierHelp), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'reduced motion keeps the grid height and seeded direction color',
    (tester) async {
      const seed = 0xff6750a4;
      await _pumpGrid(tester, reduced: true, seed: seed);

      final theme = Theme.of(tester.element(_key('↑')));
      final expected = ColorScheme.fromSeed(
        seedColor: const Color(seed),
        brightness: theme.brightness,
      ).secondaryContainer;

      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
      expect(_arrowColor(tester), expected);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('terminal_direction_pad'))).height,
        88,
      );
      expect(_arrowColor(tester), expected);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
      expect(_arrowColor(tester), expected);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing search before its post-frame callback never requests the IME',
    (tester) async {
      final terminal = Terminal(maxLines: 100)..write('content');
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      final state = tester.state<SharedTerminalCanvasState>(
        find.byType(SharedTerminalCanvas),
      );
      state.openSearch();
      state.closeSearch();
      await tester.pump();
      await tester.pump();

      expect(state.isSearchOpen, isFalse);
      expect(find.byKey(const Key('terminal_search_input')), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'disabling input stops a held arrow repeat and re-enabling never rearms',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final sent = <String>[];
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              sent.add(key),
        ),
      );
      await tester.pumpAndSettle();

      final slot = _arrowSlot();
      final gesture = await tester.startGesture(tester.getCenter(slot));
      await tester.pump(const Duration(milliseconds: 450));
      expect(sent.length, greaterThan(1));
      expect(sent.every((key) => key == '↑'), isTrue);

      enabled.value = false;
      await tester.pump();
      final stoppedAt = sent.length;
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        sent.length,
        stoppedAt,
        reason: 'a disabled canvas must cancel the in-flight hold repeat',
      );

      enabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        sent.length,
        stoppedAt,
        reason: 're-enabling input must not revive a cancelled hold',
      );

      await gesture.up();
      await tester.pump();
      expect(sent.length, stoppedAt);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabling input clears an armed modifier and re-enabling never rearms it',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
            sendTerminalAccessoryKey(
              terminal,
              key,
              isCtrl: isCtrl,
              isAlt: isAlt,
              isShift: isShift,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tapKey(tester, 'CTRL');
      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.oneShot);

      enabled.value = false;
      await tester.pumpAndSettle();
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(
        bar.ctrlState,
        ModifierLockState.inactive,
        reason: 'disabling input must drop an armed one-shot modifier',
      );

      enabled.value = true;
      await tester.pumpAndSettle();
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(
        bar.ctrlState,
        ModifierLockState.inactive,
        reason: 're-enabling input must not re-arm a cleared modifier',
      );

      expect(_inputHook(tester)('a'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline buffer search still works with input disabled and never touches the PTY',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle offline $i\r\n');
      }
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<SharedTerminalCanvasState>(
        find.byType(SharedTerminalCanvas),
      );
      state.openSearch();
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('terminal_search_input')),
        'needle',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<TerminalView>(find.byType(TerminalView))
          .controller!;
      expect(state.isSearchOpen, isTrue);
      expect(find.byKey(const Key('terminal_search_input')), findsOneWidget);
      expect(controller.highlights, isNotEmpty);
      expect(keys, isEmpty);
      expect(written, isEmpty, reason: 'search must never touch the PTY');
      expect(_terminalState(tester).hasInputConnection, isFalse);

      state.closeSearch();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal_search_input')), findsNothing);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
