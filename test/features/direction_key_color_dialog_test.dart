import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/features/terminal/widgets/customize_pinned_keys_dialog.dart';
import 'package:valhalla/features/terminal/widgets/direction_key_color_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;
import '../support/fixed_terminal_settings.dart';

class _Box {
  DirectionKeyColorResult? value;
}

Future<_Box> _openDialog(
  WidgetTester tester, {
  int? initialColorValue,
  bool accessorySettings = false,
}) async {
  await loadRealTextFonts();
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final box = _Box();
  await tester.pumpWidget(
    ProviderScope(
      overrides: fixedTerminalSettingsOverrides(),
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(fontFamily: 'Inter', useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-direction-key-color'),
              onPressed: () async {
                if (accessorySettings) {
                  await CustomizePinnedKeysDialog.show(context);
                } else {
                  box.value = await DirectionKeyColorDialog.show(
                    context,
                    initialColorValue: initialColorValue,
                  );
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-direction-key-color')));
  await tester.pumpAndSettle();
  return box;
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('es'));

void main() {
  testWidgets(
    'A: 320dp 2x es dialog fits, SV drag updates HEX, confirm returns value',
    (tester) async {
      final box = await _openDialog(tester);
      final l10n = await _l10n();
      expect(tester.takeException(), isNull, reason: '320dp 2x es 不得溢出');
      expect(find.text(l10n.terminalDirectionKeyColor), findsOneWidget);

      final sv = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_DirectionSvPainter',
      );
      expect(sv, findsOneWidget);
      await tester.ensureVisible(sv);
      await tester.pumpAndSettle();
      await tester.drag(sv, const Offset(-30, -30));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '拖动 SV 色板不得溢出');

      final hexField = find.byType(TextField);
      await tester.ensureVisible(hexField);
      await tester.pumpAndSettle();
      final hexBefore = tester.widget<TextField>(hexField).controller!.text;
      expect(hexBefore, isNot('3B82F6'), reason: '拖动后 HEX 应更新');
      expect(RegExp(r'^[0-9A-F]{6}$').hasMatch(hexBefore), isTrue);

      await tester.enterText(hexField, '336699');
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, l10n.confirm);
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(box.value?.resetToTheme, isFalse);
      expect(box.value?.colorValue, 0xff336699);
    },
  );

  testWidgets('B: cancel after HEX edit returns null', (tester) async {
    final box = await _openDialog(tester);
    final l10n = await _l10n();
    final hexField = find.byType(TextField);
    await tester.ensureVisible(hexField);
    await tester.pumpAndSettle();
    await tester.enterText(hexField, 'AABBCC');
    await tester.pumpAndSettle();
    final cancel = find.widgetWithText(TextButton, l10n.cancel);
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byType(DirectionKeyColorDialog), findsNothing);
    expect(box.value, isNull);
  });

  testWidgets('C: reset with initial color returns resetToTheme true', (
    tester,
  ) async {
    final box = await _openDialog(tester, initialColorValue: 0xFF112233);
    final l10n = await _l10n();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '112233',
    );
    final reset = find.widgetWithText(
      TextButton,
      l10n.terminalDirectionKeyColorReset,
    );
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(box.value?.resetToTheme, isTrue);
    expect(box.value?.colorValue, isNull);
  });

  testWidgets(
    'D: 320dp 2x es default fixed accessory color row opens picker without overflow',
    (tester) async {
      await _openDialog(tester, accessorySettings: true);
      final l10n = await _l10n();
      expect(find.byType(CustomizePinnedKeysDialog), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '默认 fixed 配色行 320dp 2x es 不得溢出',
      );
      final colorButton = find.widgetWithText(
        OutlinedButton,
        l10n.terminalDirectionKeyColor,
      );
      await tester.ensureVisible(colorButton);
      await tester.pumpAndSettle();
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.byType(DirectionKeyColorDialog), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '进入配色弹窗不得溢出');
    },
  );
}
