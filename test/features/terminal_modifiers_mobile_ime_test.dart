import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';

Future<void> _mobile(
  WidgetTester tester,
  Future<void> Function(List<String>) run,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  final output = <String>[];
  final terminal = Terminal()..onOutput = output.add;
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fixedTerminalSettingsOverrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SharedTerminalCanvas(
              terminal: terminal,
              requestKeyboardOnTap: false,
              pinKeyboardButtonTrailing: true,
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await run(output);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  } finally {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _keyboard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('terminal_accessory_keyboard_button')));
  await tester.pumpAndSettle();
  expect(tester.testTextInput.hasAnyClients, isTrue);
}

Future<void> _modifier(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(Key('terminal_accessory_key_$name')));
  await tester.pumpAndSettle();
}

Future<void> _commit(WidgetTester tester, String text) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

void main() {
  for (final entry in {'CTRL': '\x03', 'SHIFT': 'C', 'ALT': '\x1bc'}.entries) {
    testWidgets('mobile IME: tap ${entry.key} then committed c', (tester) {
      return _mobile(tester, (output) async {
        await _keyboard(tester);
        await _modifier(tester, entry.key);
        await _commit(tester, 'c');
        expect(output.join(), entry.value);
        await _commit(tester, 'c');
        expect(output.join(), '${entry.value}c');
      });
    });
  }

  testWidgets('mobile IME: arm Ctrl before opening keyboard', (tester) {
    return _mobile(tester, (output) async {
      await _modifier(tester, 'CTRL');
      await _keyboard(tester);
      await _commit(tester, 'c');
      expect(output.join(), '\x03');
    });
  });

  testWidgets('mobile IME: locked Ctrl applies to consecutive commits', (
    tester,
  ) {
    return _mobile(tester, (output) async {
      await _keyboard(tester);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('terminal_accessory_key_CTRL'))),
      );
      await tester.pump(const Duration(milliseconds: 750));
      await hold.up();
      await tester.pumpAndSettle();
      await _commit(tester, 'c');
      await _commit(tester, 'c');
      expect(output.join(), '\x03\x03');
    });
  });

  for (final entry in {'CTRL': '\x03', 'SHIFT': 'C', 'ALT': '\x1bc'}.entries) {
    testWidgets('Gboard preedit immediately applies ${entry.key}', (tester) {
      return _mobile(tester, (output) async {
        await _keyboard(tester);
        await _modifier(tester, entry.key);
        const preedit = TextEditingValue(
          text: 'c',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        );
        tester.testTextInput.updateEditingValue(preedit);
        await tester.pump();
        expect(output.join(), entry.value);
        final editor = tester.state<CustomTextEditState>(
          find.byType(CustomTextEdit),
        );
        expect(editor.currentTextEditingValue?.text, isEmpty);
        expect(editor.currentTextEditingValue?.composing.isCollapsed, isTrue);

        // After the platform editing state is reset, the next ordinary preedit
        // must remain composition, then emit exactly once at commit.
        tester.testTextInput.updateEditingValue(preedit);
        await tester.pump();
        expect(output.join(), entry.value);
        await _commit(tester, 'c');
        expect(output.join(), '${entry.value}c');
      });
    });
  }

  for (final text in ['中', 'zhong', 'cc']) {
    testWidgets('modifier does not consume multi-character/CJK preedit $text', (
      tester,
    ) {
      return _mobile(tester, (output) async {
        await _keyboard(tester);
        await _modifier(tester, 'CTRL');
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(start: 0, end: text.length),
          ),
        );
        await tester.pump();
        expect(output, isEmpty);
        await _commit(tester, text);
        expect(output.join(), text);
        await _commit(tester, 'c');
        expect(output.join(), '$text\x03');
      });
    });
  }
}
