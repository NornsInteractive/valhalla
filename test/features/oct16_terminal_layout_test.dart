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
        'compact terminal keyboard has physical inverted-T directions and usable touch targets $width $direction',
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
          final up = tester.getRect(key('↑')), down = tester.getRect(key('↓'));
          final left = tester.getRect(key('←')),
              right = tester.getRect(key('→'));
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
          final keyboard = tester.getCenter(
            find.byKey(const Key('terminal_accessory_keyboard_button')),
          );
          expect(keyboard.dx, greaterThan(right.center.dx));
          expect(keyboard.dy, closeTo(right.center.dy, 2));
          expect(
            find.byKey(const Key('terminal_accessory_key_FN')),
            findsNothing,
          );
          expect(find.byType(TerminalAccessoryBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
