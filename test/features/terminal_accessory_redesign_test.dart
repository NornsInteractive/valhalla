import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/terminal_grid_harness.dart';

Color _arrowColor(WidgetTester tester) {
  final face = tester.widget<Container>(terminalGridKey('↑'));
  return (face.decoration! as BoxDecoration).color!;
}

void main() {
  setUpAll(loadTerminalGridFonts);

  testWidgets(
    'landscape editor remains bounded without changing base geometry',
    (tester) async {
      await pumpTerminalGrid(tester, width: 760, height: 360);
      await enterTerminalGridEditor(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
    },
  );

  for (final locale in [
    const Locale('de'),
    const Locale('ru'),
    const Locale('ar'),
  ]) {
    testWidgets('localized editor remains operable at 320dp and 2x: $locale', (
      tester,
    ) async {
      await pumpTerminalGrid(
        tester,
        width: 320,
        textScale: 2,
        locale: locale,
        direction: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      await enterTerminalGridEditor(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TerminalAccessoryBar)),
      );
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal_grid_save_button')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single-row wide key survives narrow large-font projection', (
    tester,
  ) async {
    await pumpTerminalGrid(
      tester,
      width: 320,
      textScale: 2,
      layout: TerminalAccessoryLayout(
        rows: 1,
        pages: 1,
        items: [
          AccessoryItem(id: 'wide', l: 'Tab', s: 'TAB', w: 3),
          AccessoryItem(id: 'delete', l: 'DELETE', s: 'DELETE', c: 3),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(terminalGridKey('TAB'), findsOneWidget);
    expect(
      find.byKey(const Key('terminal_accessory_keyboard_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'responsive grid retains 44dp slots, 2dp face inset and compact base',
    (tester) async {
      for (final width in [320.0, 360.0, 390.0]) {
        await tester.pumpWidget(const SizedBox());
        await pumpTerminalGrid(tester, width: width);
        final columns = accessoryColumnsForWidth(width);
        final cell = (width - 8) / columns;
        expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
        expect(
          tester.getSize(find.byKey(const Key('terminal_direction_pad'))),
          Size(cell * 3, 88),
        );
        for (final key in ['↑', '←', '↓', '→']) {
          final slot = tester.getRect(terminalGridArrowSlot(key));
          final face = tester.getRect(terminalGridKey(key));
          expect(slot.width, closeTo(cell, 0.01));
          expect(slot.height, 44);
          expect(face.topLeft - slot.topLeft, const Offset(2, 2));
          expect(face.width, closeTo(cell - 4, 0.001));
          expect(face.height, 40);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'direction group belongs to its page; system controls survive swipes',
    (tester) async {
      await pumpTerminalGrid(tester);
      final more = find.byKey(const Key('terminal_accessory_more_button'));
      final keyboard = find.byKey(
        const Key('terminal_accessory_keyboard_button'),
      );
      final before = tester.getRect(keyboard);
      final group = find.byKey(const Key('terminal_direction_pad'));
      await tester.drag(group, const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(group, findsNothing);
      expect(more, findsOneWidget);
      expect(tester.getRect(keyboard), before);
      await tester.drag(
        find.byType(TerminalAccessoryBar),
        const Offset(140, 0),
      );
      await tester.pumpAndSettle();
      expect(group, findsOneWidget);
    },
  );

  testWidgets('explicit layout without a direction group remains usable', (
    tester,
  ) async {
    await pumpTerminalGrid(
      tester,
      layout: TerminalAccessoryLayout(
        pages: 1,
        items: [AccessoryItem(id: 'escape', l: 'ESC', s: 'ESC')],
      ),
    );
    expect(find.byKey(const Key('terminal_direction_pad')), findsNothing);
    expect(terminalGridKey('ESC'), findsOneWidget);
    await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Layout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp common actions remain visible in the projected grid', (
    tester,
  ) async {
    await pumpTerminalGrid(tester, width: 320);
    final bar = tester.getRect(find.byType(TerminalAccessoryBar));
    for (final key in ['ESC', 'TAB', 'CTRL', 'SHIFT', 'ALT', 'PASTE']) {
      final rect = tester.getRect(terminalGridKey(key));
      expect(rect.left, greaterThanOrEqualTo(bar.left));
      expect(rect.right, lessThanOrEqualTo(bar.right));
      expect(rect.top, greaterThanOrEqualTo(bar.top));
      expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
    }
  });

  testWidgets(
    'theme and independent direction seed drive idle/held colors; cancel stops repeat',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final seed in <int?>[null, 0xff6750a4]) {
          await tester.pumpWidget(const SizedBox());
          final sent = <String>[];
          await pumpTerminalGrid(
            tester,
            layout: TerminalAccessoryLayout.defaultLayout().copyWith(
              directionSeedColor: seed,
            ),
            theme: AppTheme.buildTheme(
              brightness: brightness,
              seedColor: const Color(0xff10b981),
            ),
            sent: sent,
          );
          final theme = Theme.of(tester.element(terminalGridKey('↑')));
          final scheme = seed == null
              ? theme.colorScheme
              : ColorScheme.fromSeed(
                  seedColor: Color(seed),
                  brightness: brightness,
                );
          final idle = seed == null
              ? scheme.surfaceContainerHigh
              : scheme.secondaryContainer;
          expect(_arrowColor(tester), idle);
          final gesture = await tester.startGesture(
            tester.getCenter(terminalGridArrowSlot('↑')),
          );
          await tester.pump();
          expect(
            sent,
            isEmpty,
            reason: 'down must leave room to distinguish page swipes',
          );
          expect(_arrowColor(tester), scheme.primary);
          await tester.pump(const Duration(milliseconds: 450));
          expect(sent.length, greaterThan(1));
          expect(sent.every((key) => key == '↑'), isTrue);
          await gesture.cancel();
          await tester.pump();
          expect(_arrowColor(tester), idle);
          final count = sent.length;
          await tester.pump(const Duration(milliseconds: 450));
          expect(sent.length, count);
        }
      }
    },
  );

  testWidgets(
    'inactive/resumed cancels immediately without reviving timer or held color',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final sent = <String>[];
      await pumpTerminalGrid(tester, sent: sent);
      final idle = _arrowColor(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(terminalGridArrowSlot('↑')),
      );
      await tester.pump(const Duration(milliseconds: 450));
      final count = sent.length;
      expect(count, greaterThan(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(_arrowColor(tester), idle);
      await tester.pump(const Duration(milliseconds: 450));
      expect(sent.length, count);
      await gesture.up();
      expect(sent.length, count);
    },
  );

  testWidgets(
    'TickerMode preserves State but cancels held repeat across hide/show',
    (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      final sent = <String>[];
      await pumpTerminalGrid(tester, sent: sent, tickers: enabled);
      final slot = terminalGridArrowSlot('↑');
      final state = tester.state<State>(slot);
      final element = tester.element(slot);
      final idle = _arrowColor(tester);
      final gesture = await tester.startGesture(tester.getCenter(slot));
      await tester.pump(const Duration(milliseconds: 450));
      final count = sent.length;
      expect(count, greaterThan(1));
      enabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(identical(state, tester.state<State>(slot)), isTrue);
      expect(identical(element, tester.element(slot)), isTrue);
      expect(sent.length, count);
      expect(_arrowColor(tester), idle);
      enabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(identical(state, tester.state<State>(slot)), isTrue);
      expect(sent.length, count);
      await gesture.up();
      expect(sent.length, count);
    },
  );

  testWidgets('second finger release cannot cancel first finger repeat', (
    tester,
  ) async {
    final sent = <String>[];
    await pumpTerminalGrid(tester, sent: sent);
    final center = tester.getCenter(terminalGridArrowSlot('↑'));
    final first = await tester.startGesture(center);
    final second = await tester.startGesture(center);
    await second.up();
    await tester.pump(const Duration(milliseconds: 450));
    expect(sent.length, greaterThan(1));
    expect(sent.every((key) => key == '↑'), isTrue);
    await first.up();
    final count = sent.length;
    await tester.pump(const Duration(milliseconds: 450));
    expect(sent.length, count);
  });

  for (final brightness in Brightness.values) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'More and editor work at 320dp, 2x, $brightness, $direction',
        (tester) async {
          await pumpTerminalGrid(
            tester,
            width: 320,
            textScale: 2,
            direction: direction,
            theme: AppTheme.buildTheme(
              brightness: brightness,
              seedColor: const Color(0xff10b981),
            ),
          );
          await enterTerminalGridEditor(tester);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('terminal_grid_save_button')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
