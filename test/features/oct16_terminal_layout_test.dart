import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';
import '../support/fixed_terminal_settings.dart';

void main() {
  for (final width in [320.0, 360.0, 430.0]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'free-grid inverted-T preserves physical layout and full touch targets $width $direction',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 760));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: fixedTerminalSettingsOverrides(),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Directionality(
                  textDirection: direction,
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 760),
                      textScaler: const TextScaler.linear(2),
                    ),
                    child: Scaffold(
                      body: SharedTerminalCanvas(
                        terminal: Terminal(),
                        onKey:
                            (
                              key, {
                              isCtrl = false,
                              isAlt = false,
                              isShift = false,
                            }) {},
                        pinKeyboardButtonTrailing: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Finder key(String label) =>
              find.byKey(Key('terminal_accessory_key_$label'));

          // ARROWS group is resident by default: no tap-to-open, no dismiss,
          // no overlay — the pad lives inline inside the accessory bar.
          expect(
            find.byKey(const Key('terminal_accessory_key_ARROWS')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('terminal_direction_pad')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(TerminalAccessoryBar),
              matching: find.byKey(const Key('terminal_direction_pad')),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('terminal_direction_pad_dismiss')),
            findsNothing,
          );
          for (final label in ['↑', '↓', '←', '→']) {
            expect(key(label), findsOneWidget);
          }

          final barRect = tester.getRect(find.byType(TerminalAccessoryBar));
          expect(barRect.height, 98);

          await tester.ensureVisible(
            find.byKey(const Key('terminal_accessory_key_ARROWS')),
          );
          await tester.pumpAndSettle();

          final up = tester.getRect(key('↑')), down = tester.getRect(key('↓'));
          final left = tester.getRect(key('←')),
              right = tester.getRect(key('→'));
          // Physical inverted-T: never mirrored, even in RTL.
          expect(up.center.dx, closeTo(down.center.dx, 1));
          expect(up.center.dy, lessThan(down.center.dy));
          expect(left.center.dx, lessThan(down.center.dx));
          expect(right.center.dx, greaterThan(down.center.dx));
          expect(left.center.dy, closeTo(right.center.dy, 1));
          for (final label in ['↑', '↓', '←', '→']) {
            final rect = tester.getRect(
              find
                  .ancestor(
                    of: key(label),
                    matching: find.byType(HoldRepeatKey),
                  )
                  .first,
            );
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }

          // Only system controls reserve the last column; the direction group
          // remains a freely placed grid item and does not own the right edge.
          final moreRect = tester.getRect(
            find.byKey(const Key('terminal_accessory_more_button')),
          );
          final keyboardRect = tester.getRect(
            find.byKey(const Key('terminal_accessory_keyboard_button')),
          );
          final padRect = tester.getRect(
            find.byKey(const Key('terminal_direction_pad')),
          );
          final barNow = tester.getRect(find.byType(TerminalAccessoryBar));
          expect(keyboardRect.right, lessThanOrEqualTo(width));
          expect(moreRect.right, lessThanOrEqualTo(width));
          expect(padRect.right, lessThanOrEqualTo(width));
          expect(
            barNow.right - keyboardRect.right,
            lessThanOrEqualTo(8),
            reason: '系统按键保留在最后一列',
          );
          expect(
            keyboardRect.left,
            greaterThanOrEqualTo(padRect.right),
            reason: '方向组不能覆盖系统列',
          );
          expect(
            moreRect.left,
            greaterThanOrEqualTo(padRect.right),
            reason: '方向组不能覆盖更多按键',
          );
          expect(
            moreRect.center.dx,
            closeTo(keyboardRect.center.dx, 1),
            reason: '更多/键盘必须同一列',
          );
          expect(keyboardRect.center.dy, greaterThan(moreRect.center.dy));
          expect(keyboardRect.top, greaterThanOrEqualTo(moreRect.bottom - 1));

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('arrow key long-repeat stops on lifecycle inactive', (
    tester,
  ) async {
    final sentKeys = <String>[];
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: fixedTerminalSettingsOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TerminalAccessoryBar(
                onKey:
                    (key, {isCtrl = false, isAlt = false, isShift = false}) =>
                        sentKeys.add(key),
                onToggleCtrl: () {},
                onToggleAlt: () {},
                onPaste: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('terminal_accessory_key_↑')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('terminal_accessory_key_↑')));
    await tester.pump();
    expect(sentKeys.length, 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('terminal_accessory_key_↑'))),
    );
    await tester.pump(const Duration(milliseconds: 450));
    final countAfterRepeat = sentKeys.length;
    expect(countAfterRepeat, greaterThan(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 200));
    expect(sentKeys.length, countAfterRepeat);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 200));
    expect(sentKeys.length, countAfterRepeat);
    await gesture.up();
    await tester.pump();
    expect(sentKeys.length, countAfterRepeat);
  });

  testWidgets('inline arrows repeat stops on inactive', (tester) async {
    final sent = <String>[];
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: fixedTerminalSettingsOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TerminalAccessoryBar(
                onKey:
                    (
                      String key, {
                      bool isCtrl = false,
                      bool isAlt = false,
                      bool isShift = false,
                    }) {
                      sent.add(key);
                    },
                onToggleCtrl: () {},
                onToggleAlt: () {},
                onPaste: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final up = find.byKey(const Key('terminal_accessory_key_↑'));
    await tester.ensureVisible(up);
    await tester.pumpAndSettle();
    await tester.tap(up);
    expect(sent, ['↑']);
    sent.clear();
    final gesture = await tester.startGesture(tester.getCenter(up));
    await tester.pump(const Duration(milliseconds: 450));
    expect(sent.length, greaterThan(1));
    final count = sent.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent.length, count);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent.length, count);
    expect(tester.takeException(), isNull);
  });
}
