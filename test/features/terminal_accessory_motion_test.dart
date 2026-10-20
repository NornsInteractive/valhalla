import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/terminal_grid_harness.dart';

const _moreKey = Key('terminal_accessory_more_button');
const _keyboardKey = Key('terminal_accessory_keyboard_button');

Future<LocalStorageService> _pumpMotion(
  WidgetTester tester, {
  List<String>? sent,
  TerminalAccessoryLayout? layout,
  ValueNotifier<bool>? reduceMotion,
  ValueNotifier<bool>? tickers,
  ValueNotifier<ModifierLockState>? modifier,
  VoidCallback? onKeyboard,
  VoidCallback? onCtrl,
  Terminal? terminal,
}) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'valhalla_terminal_grid_v2': jsonEncode(
      (layout ?? TerminalAccessoryLayout.defaultLayout()).toJson(),
    ),
  });
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final reduced = reduceMotion ?? ValueNotifier(false);
  final enabled = tickers ?? ValueNotifier(true);
  final state = modifier ?? ValueNotifier(ModifierLockState.inactive);
  if (reduceMotion == null) addTearDown(reduced.dispose);
  if (tickers == null) addTearDown(enabled.dispose);
  if (modifier == null) addTearDown(state.dispose);
  void key(
    String value, {
    bool isCtrl = false,
    bool isAlt = false,
    bool isShift = false,
  }) => sent?.add(value);
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
        home: AnimatedBuilder(
          animation: Listenable.merge([reduced, enabled, state]),
          builder: (context, _) => MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 760),
              disableAnimations: reduced.value,
            ),
            child: TickerMode(
              enabled: enabled.value,
              child: Scaffold(
                body: terminal == null
                    ? Column(
                        children: [
                          const Spacer(),
                          TerminalAccessoryBar(
                            onKey: key,
                            onToggleCtrl: onCtrl ?? () {},
                            onToggleAlt: () {},
                            onPaste: () {},
                            onToggleKeyboard: onKeyboard ?? () {},
                            ctrlState: state.value,
                          ),
                        ],
                      )
                    : SharedTerminalCanvas(
                        terminal: terminal,
                        onKey: key,
                        requestKeyboardOnTap: false,
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

Finder _keyScale(Finder key) {
  final inside = find.descendant(of: key, matching: find.byType(AnimatedScale));
  return inside.evaluate().isNotEmpty
      ? inside.first
      : find.ancestor(of: key, matching: find.byType(AnimatedScale)).first;
}

double _paintedScale(WidgetTester tester, Finder key) {
  final transform = find
      .descendant(of: _keyScale(key), matching: find.byType(Transform))
      .first;
  return tester.widget<Transform>(transform).transform.entry(0, 0);
}

BoxDecoration _face(WidgetTester tester, Finder key) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: key,
        matching: find.byType(DecoratedBox),
        matchRoot: true,
      ),
    )
    .map((widget) => widget.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.color != null);

void main() {
  setUpAll(loadTerminalGridFonts);

  testWidgets(
    'ordinary key animates locally and sends without waiting for release animation',
    (tester) async {
      final sent = <String>[];
      await _pumpMotion(tester, sent: sent);
      final key = terminalGridKey('ESC');
      var barBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (element.widget is TerminalAccessoryBar) barBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final down = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_paintedScale(tester, key), inExclusiveRange(0.9, 1.0));
      expect(sent, isEmpty);
      await down.up();
      expect(sent, ['ESC']);
      await tester.pumpAndSettle();
      expect(_paintedScale(tester, key), 1);
      expect(
        barBuilds,
        0,
        reason: 'key animation must not rebuild the full grid',
      );
    },
  );

  testWidgets('pointer cancel resets ordinary key feedback without sending', (
    tester,
  ) async {
    final sent = <String>[];
    await _pumpMotion(tester, sent: sent);
    final key = terminalGridKey('ESC');
    final down = await tester.startGesture(tester.getCenter(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await down.cancel();
    await tester.pumpAndSettle();
    expect(_paintedScale(tester, key), 1);
    expect(sent, isEmpty);
  });

  testWidgets(
    'pressed background interpolates locally rather than changing instantly',
    (tester) async {
      await _pumpMotion(tester);
      final key = terminalGridKey('ESC');
      final idle = _face(tester, key).color;
      final down = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final middle = _face(tester, key).color;
      await tester.pump(const Duration(milliseconds: 120));
      final pressed = _face(tester, key).color;
      expect(middle, isNot(idle));
      expect(middle, isNot(pressed));
      await down.up();
      await tester.pumpAndSettle();
      expect(_face(tester, key).color, idle);
    },
  );

  testWidgets('ordinary shortcut retains its accessibility tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final sent = <String>[];
      await _pumpMotion(tester, sent: sent);
      tester.semantics.tap(find.semantics.byLabel('ESC'));
      expect(sent, ['ESC']);
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'cancelled physical press does not disable later accessibility activation',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final sent = <String>[];
        await _pumpMotion(tester, sent: sent);
        final down = await tester.startGesture(
          tester.getCenter(terminalGridKey('ESC')),
        );
        await tester.pump();
        await down.cancel();
        await tester.pumpAndSettle();
        expect(sent, isEmpty);
        tester.semantics.tap(find.semantics.byLabel('ESC'));
        expect(sent, ['ESC']);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'accessibility activation after background is independent of the cancelled pointer',
    (tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      try {
        final sent = <String>[];
        await _pumpMotion(tester, sent: sent);
        final down = await tester.startGesture(
          tester.getCenter(terminalGridKey('ESC')),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        tester.semantics.tap(find.semantics.byLabel('ESC'));
        expect(sent, ['ESC']);
        await down.up();
        expect(sent, [
          'ESC',
        ], reason: 'the cancelled physical pointer must remain invalid');
        await tester.pumpAndSettle();
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'disposing a pressed ordinary key does not setState or send a late tap',
    (tester) async {
      final sent = <String>[];
      await _pumpMotion(tester, sent: sent);
      final down = await tester.startGesture(
        tester.getCenter(terminalGridKey('ESC')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await down.up();
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final label in ['↑', '←', '↓', '→']) {
    testWidgets(
      'direction $label has local animated feedback and immediate repeat cancellation',
      (tester) async {
        final sent = <String>[];
        await _pumpMotion(tester, sent: sent);
        final key = terminalGridKey(label);
        var barBuilds = 0;
        final previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previous?.call(element, builtOnce);
          if (element.widget is TerminalAccessoryBar) barBuilds++;
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previous);
        final down = await tester.startGesture(tester.getCenter(key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(_paintedScale(tester, key), lessThan(1));
        await tester.pump(const Duration(milliseconds: 250));
        expect(sent.length, greaterThan(1));
        expect(sent.every((value) => value == label), isTrue);
        await down.cancel();
        final count = sent.length;
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        expect(sent.length, count);
        expect(_paintedScale(tester, key), 1);
        expect(barBuilds, 0);
      },
    );
  }

  testWidgets(
    'system keyboard key retains its full 44dp edge hit area during feedback',
    (tester) async {
      var requests = 0;
      await _pumpMotion(tester, onKeyboard: () => requests++);
      final key = find.byKey(_keyboardKey);
      final rect = tester.getRect(key);
      final down = await tester.startGesture(
        rect.topLeft + Offset(0.5, rect.height / 2),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_paintedScale(tester, key), lessThan(1));
      expect(tester.getRect(key), rect);
      await down.up();
      expect(requests, 1);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'one-shot and locked modifiers are visibly distinct, including a lock marker',
    (tester) async {
      final state = ValueNotifier(ModifierLockState.inactive);
      addTearDown(state.dispose);
      await _pumpMotion(tester, modifier: state);
      final key = terminalGridKey('CTRL');
      final idle = _face(tester, key);
      state.value = ModifierLockState.oneShot;
      await tester.pumpAndSettle();
      final once = _face(tester, key);
      expect(once.color, isNot(idle.color));
      expect(once.border, isNotNull);
      expect(
        find.descendant(of: key, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );
      state.value = ModifierLockState.locked;
      await tester.pumpAndSettle();
      final locked = _face(tester, key);
      expect(locked.color, isNot(once.color));
      expect(locked.border, isNotNull);
      expect(
        find.descendant(of: key, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reduced motion keeps pressed feedback but introduces no animation frames',
    (tester) async {
      final reduced = ValueNotifier(true);
      addTearDown(reduced.dispose);
      final sent = <String>[];
      await _pumpMotion(tester, sent: sent, reduceMotion: reduced);
      final key = terminalGridKey('ESC');
      final idle = _face(tester, key);
      final down = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(_keyScale(key)).duration,
        Duration.zero,
      );
      expect(_face(tester, key), isNot(idle));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await down.up();
      expect(sent, ['ESC']);
      await tester.pumpAndSettle();
      expect(_paintedScale(tester, key), 1);
    },
  );

  testWidgets('hidden and resumed grid does not revive a held key', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    final sent = <String>[];
    await _pumpMotion(tester, sent: sent, tickers: enabled);
    final key = terminalGridKey('ESC');
    final down = await tester.startGesture(tester.getCenter(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    enabled.value = false;
    await tester.pump();
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(_paintedScale(tester, key), 1);
    await down.up();
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'background and foreground clear ordinary press without replaying its tap',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final sent = <String>[];
      await _pumpMotion(tester, sent: sent);
      final key = terminalGridKey('ESC');
      final down = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_paintedScale(tester, key), 1);
      await down.up();
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
    },
  );

  for (final hide in [false, true]) {
    testWidgets(
      'modifier fallback cancels ${hide ? "hidden" : "background"} press without arming on return',
      (tester) async {
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        var armed = 0;
        await _pumpMotion(tester, tickers: enabled, onCtrl: () => armed++);
        final key = terminalGridKey('CTRL');
        final down = await tester.startGesture(tester.getCenter(key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        if (hide) {
          enabled.value = false;
          await tester.pump();
          enabled.value = true;
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(_paintedScale(tester, key), 1);
        await down.up();
        await tester.pumpAndSettle();
        expect(armed, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'hiding a real shared-canvas modifier does not setState an ancestor during build',
    (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await _pumpMotion(tester, tickers: enabled, terminal: Terminal());
      final key = terminalGridKey('CTRL');
      final down = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      enabled.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
      enabled.value = true;
      await tester.pumpAndSettle();
      expect(_paintedScale(tester, key), 1);
      await down.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TerminalAccessoryBar>(find.byType(TerminalAccessoryBar))
            .ctrlState,
        ModifierLockState.inactive,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing page cancels an already repeating outgoing arrow', (
    tester,
  ) async {
    final sent = <String>[];
    await _pumpMotion(tester, sent: sent);
    final down = await tester.startGesture(
      tester.getCenter(terminalGridKey('↑')),
      pointer: 41,
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(sent.length, greaterThan(1));
    await tester.tap(find.byKey(_moreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    final count = sent.length;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sent.length, count);
    await down.up();
    await tester.pumpAndSettle();
    expect(sent.length, count);
  });

  testWidgets(
    'panel transitions preserve terminal size and do not show the IME',
    (tester) async {
      final terminal = Terminal();
      await _pumpMotion(tester, terminal: terminal);
      final view = find.byType(TerminalView);
      final before = tester.getRect(view);
      final rows = terminal.viewHeight;
      final columns = terminal.viewWidth;
      final more = find.byKey(_moreKey);
      for (var cycle = 0; cycle < 2; cycle++) {
        await tester.tap(more);
        for (final step in [0, 45, 45, 90]) {
          await tester.pump(Duration(milliseconds: step));
          expect(tester.getRect(view), before);
          expect(terminal.viewHeight, rows);
          expect(terminal.viewWidth, columns);
          expect(tester.testTextInput.isVisible, isFalse);
        }
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('closing the panel cancels its held Fn key, reduced=$reduced', (
      tester,
    ) async {
      final reduceMotion = ValueNotifier(reduced);
      addTearDown(reduceMotion.dispose);
      await _pumpMotion(
        tester,
        terminal: Terminal(),
        reduceMotion: reduceMotion,
      );
      final more = find.byKey(_moreKey);
      await tester.tap(more);
      await tester.pumpAndSettle();
      final fn = find.descendant(
        of: find.byKey(const ValueKey<String>('panel_more')),
        matching: terminalGridKey('FN'),
      );
      final down = await tester.startGesture(tester.getCenter(fn), pointer: 41);
      await tester.pump();
      expect(
        tester
            .widget<TerminalAccessoryBar>(find.byType(TerminalAccessoryBar))
            .isFnHeld,
        isTrue,
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.isFnHeld, isFalse);
      expect(bar.fnState, ModifierLockState.inactive);
      await down.up();
      await tester.pumpAndSettle();
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.isFnHeld, isFalse);
      expect(bar.fnState, ModifierLockState.inactive);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locked in [false, true]) {
    testWidgets(
      'closing the panel preserves deliberately ${locked ? "locked" : "one-shot"} Fn',
      (tester) async {
        await _pumpMotion(tester, terminal: Terminal());
        final more = find.byKey(_moreKey);
        await tester.tap(more);
        await tester.pumpAndSettle();
        final fn = find.descendant(
          of: find.byKey(const ValueKey<String>('panel_more')),
          matching: terminalGridKey('FN'),
        );
        if (locked) {
          await tester.longPress(fn);
        } else {
          await tester.tap(fn);
        }
        await tester.pumpAndSettle();
        final expected = locked
            ? ModifierLockState.locked
            : ModifierLockState.oneShot;
        expect(
          tester
              .widget<TerminalAccessoryBar>(find.byType(TerminalAccessoryBar))
              .fnState,
          expected,
        );
        await tester.tap(more);
        await tester.pumpAndSettle();
        final bar = tester.widget<TerminalAccessoryBar>(
          find.byType(TerminalAccessoryBar),
        );
        expect(bar.fnState, expected);
        expect(bar.isFnHeld, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('more panel visibly slides in without changing the base grid', (
    tester,
  ) async {
    await _pumpMotion(tester);
    final keyboard = tester.getRect(find.byKey(_keyboardKey));
    await tester.tap(find.byKey(_moreKey));
    await tester.pump();
    final edit = find.widgetWithIcon(OutlinedButton, Icons.tune);
    final start = tester.getTopLeft(edit).dy;
    await tester.pump(const Duration(milliseconds: 90));
    final middle = tester.getTopLeft(edit).dy;
    await tester.pumpAndSettle();
    final end = tester.getTopLeft(edit).dy;
    expect(start, greaterThan(end));
    expect(middle, inInclusiveRange(end, start));
    expect(middle, lessThan(start));
    expect(tester.getRect(find.byKey(_keyboardKey)), keyboard);
  });

  testWidgets('closing panel cannot invoke an outgoing quick key', (
    tester,
  ) async {
    final sent = <String>[];
    await _pumpMotion(tester, sent: sent);
    final more = find.byKey(_moreKey);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigation'));
    await tester.pumpAndSettle();
    final home = terminalGridKey('HOME');
    expect(home, findsOneWidget);
    final position = tester.getCenter(home);
    await tester.tap(more);
    await tester.pump();
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(home, findsNothing);
  });

  for (final blocked in [false, true]) {
    testWidgets(
      'editor ${blocked ? "invalid drop returns" : "valid drop settles"} with visible local motion and no input',
      (tester) async {
        final sent = <String>[];
        final storage = await _pumpMotion(
          tester,
          sent: sent,
          layout: TerminalAccessoryLayout(
            pages: 1,
            items: [
              AccessoryItem(id: 'first', l: 'First', s: 'TAB'),
              if (blocked)
                AccessoryItem(id: 'blocker', l: 'Block', s: 'ESC', c: 1, w: 2),
            ],
          ),
        );
        final original = storage.getTerminalGridConfig();
        await enterTerminalGridEditor(tester);
        final key = find.byKey(
          const Key('terminal_accessory_positioned_first'),
        );
        final label = find
            .descendant(of: key, matching: find.text('First'))
            .first;
        final originalX = tester.getCenter(label).dx;
        final gesture = await tester.startGesture(tester.getCenter(key));
        // Cross Flutter's pan recognition slop before measuring drag deltas.
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(55, 0));
        await tester.pump();
        final draggingX = tester.getCenter(label).dx;
        expect(draggingX, greaterThan(originalX + 20));
        await gesture.up();
        await tester.pump();
        final start = tester.getCenter(label).dx;
        await tester.pump(const Duration(milliseconds: 60));
        final middle = tester.getCenter(label).dx;
        await tester.pumpAndSettle();
        final end = tester.getCenter(label).dx;
        if (blocked) {
          expect(end, closeTo(originalX, 0.01));
        } else {
          expect(end, greaterThan(originalX + 20));
        }
        expect(
          (start - end).abs(),
          greaterThan(1),
          reason: 'drop must not snap instantly',
        );
        expect((middle - end).abs(), lessThan((start - end).abs()));
        expect(sent, isEmpty);
        expect(storage.getTerminalGridConfig(), original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saving immediately after drop does not replay or reinitialize a stale settle',
    (tester) async {
      final sent = <String>[];
      final storage = await _pumpMotion(
        tester,
        sent: sent,
        layout: TerminalAccessoryLayout(
          pages: 1,
          items: [AccessoryItem(id: 'first', l: 'First', s: 'TAB')],
        ),
      );
      await enterTerminalGridEditor(tester);
      final key = find.byKey(const Key('terminal_accessory_positioned_first'));
      final gesture = await tester.startGesture(tester.getCenter(key));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(55, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('terminal_grid_save_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('terminal_grid_save_button')), findsNothing);
      final saved = TerminalAccessoryLayout.fromJson(
        jsonDecode(storage.getTerminalGridConfig()!) as Map<String, dynamic>,
      );
      expect(saved.items.single.c, 1);
      expect(sent, isEmpty);
    },
  );

  testWidgets(
    'swipe does not send keys or persist projection and keeps system controls fixed',
    (tester) async {
      final sent = <String>[];
      final storage = await _pumpMotion(tester, sent: sent);
      final original = storage.getTerminalGridConfig();
      final more = tester.getRect(find.byKey(_moreKey));
      final keyboard = tester.getRect(find.byKey(_keyboardKey));
      await tester.drag(
        find.byType(TerminalAccessoryBar),
        const Offset(-140, 0),
      );
      for (final step in [0, 40, 40, 80]) {
        await tester.pump(Duration(milliseconds: step));
        expect(tester.getRect(find.byKey(_moreKey)), more);
        expect(tester.getRect(find.byKey(_keyboardKey)), keyboard);
        expect(sent, isEmpty);
      }
      await tester.pumpAndSettle();
      expect(storage.getTerminalGridConfig(), original);
      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
    },
  );

  testWidgets('custom page visibly slides in while system buttons stay fixed', (
    tester,
  ) async {
    final sent = <String>[];
    await _pumpMotion(
      tester,
      sent: sent,
      layout: TerminalAccessoryLayout(
        pages: 2,
        items: [
          AccessoryItem(id: 'alpha', l: 'Alpha', s: 'a'),
          AccessoryItem(id: 'beta', l: 'Beta', s: 'b', p: 1, c: 1),
        ],
      ),
    );
    final keyboard = tester.getRect(find.byKey(_keyboardKey));
    await tester.drag(find.byType(TerminalAccessoryBar), const Offset(-140, 0));
    await tester.pump();
    final label = find
        .descendant(of: terminalGridKey('Beta'), matching: find.text('Beta'))
        .first;
    final start = tester.getCenter(label).dx;
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getCenter(label).dx;
    expect(tester.getRect(find.byKey(_keyboardKey)), keyboard);
    await tester.pumpAndSettle();
    final end = tester.getCenter(label).dx;
    expect(start, greaterThan(end));
    expect(middle, inInclusiveRange(end, start));
    expect(middle, lessThan(start));
    expect(sent, isEmpty);

    await tester.drag(find.byType(TerminalAccessoryBar), const Offset(140, 0));
    await tester.pump();
    final previousLabel = find
        .descendant(of: terminalGridKey('Alpha'), matching: find.text('Alpha'))
        .first;
    final backStart = tester.getCenter(previousLabel).dx;
    await tester.pump(const Duration(milliseconds: 80));
    final backMiddle = tester.getCenter(previousLabel).dx;
    await tester.pumpAndSettle();
    final backEnd = tester.getCenter(previousLabel).dx;
    expect(
      backStart,
      lessThan(backEnd),
      reason: 'previous page must enter from the left',
    );
    expect(backMiddle, inInclusiveRange(backStart, backEnd));
    expect(backMiddle, greaterThan(backStart));
    expect(tester.getRect(find.byKey(_keyboardKey)), keyboard);
    expect(sent, isEmpty);
  });
}
