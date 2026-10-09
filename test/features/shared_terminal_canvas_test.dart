import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('SharedTerminalCanvas Gestures and Controls', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(maxLines: 100);
    });

    Widget buildCanvas({
      void Function(String key, {bool isCtrl, bool isAlt})? onKey,
      Future<void> Function()? onPaste,
      Widget? footer,
      TerminalController? controller,
    }) {
      // 画布 watch terminalSettingsProvider；用固定字号 notifier 免注入存储。
      return ProviderScope(
        overrides: [
          terminalSettingsProvider.overrideWith(
            () => _FixedFontSizeNotifier(13),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SharedTerminalCanvas(
                terminal: terminal,
                onKey: onKey ?? (_, {isCtrl = false, isAlt = false}) {},
                onPaste: onPaste ?? () async {},
                footer: footer,
                controller: controller,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Windows text client has a view ID and supports text and IME',
      (tester) async {
        final output = <String>[];
        terminal.onOutput = output.add;
        await tester.pumpWidget(buildCanvas());
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        final call = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        final config = (call.arguments as List)[1] as Map;
        expect(config['viewId'], tester.view.viewId);
        tester.testTextInput.enterText('abc123');
        await tester.pump();
        expect(output.join(), 'abc123');
        output.clear();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'zhong',
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 0, end: 5),
          ),
        );
        await tester.pump();
        expect(output, isEmpty);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '中文',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        expect(output.join(), '中文');
        output.clear();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(output.join(), contains('\r'));
        expect(output.join(), contains('\x7f'));
        expect(output.join(), contains('\x1b[A'));
        expect(output.join(), contains('\x03'));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                return {'text': 'paste-中文'};
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(output.join(), contains('paste-中文'));
        expect(tester.takeException(), isNull);
        // A new client must attach correctly after another control takes focus.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        tester.testTextInput.enterText('again');
        expect(output.join(), contains('again'));
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );

    testWidgets(
      'non-Windows text input preserves its existing configuration',
      (tester) async {
        await tester.pumpWidget(buildCanvas());
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        final call = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        expect(((call.arguments as List)[1] as Map)['viewId'], isNull);
        await tester.pump(const Duration(milliseconds: 400));
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    testWidgets('renders terminal and accessory bar with action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildCanvas());
      await tester.pumpAndSettle();

      expect(find.byType(SharedTerminalCanvas), findsOneWidget);
      // Verify accessory bar keys exist
      expect(find.text('ESC'), findsOneWidget);
      expect(find.text('TAB'), findsOneWidget);
      expect(find.text('CTRL'), findsOneWidget);
    });

    testWidgets(
      'renders TerminalView directly without gesture listener interception',
      (tester) async {
        final List<String> sentKeys = [];

        await tester.pumpWidget(
          buildCanvas(
            onKey: (key, {isCtrl = false, isAlt = false}) => sentKeys.add(key),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TerminalView), findsOneWidget);

        // Long press drag should not emit synthetic directional arrows
        final canvasCenter = tester.getCenter(
          find.byType(SharedTerminalCanvas),
        );
        final gesture = await tester.startGesture(canvasCenter);
        await tester.pump(const Duration(milliseconds: 700));
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(sentKeys, isEmpty);
      },
    );

    testWidgets('accessory bar paste button triggers onPaste', (tester) async {
      var pasteCalled = false;

      await tester.pumpWidget(
        buildCanvas(onPaste: () async => pasteCalled = true),
      );
      await tester.pumpAndSettle();

      final pasteFinder = find.byIcon(Icons.content_paste);
      expect(pasteFinder, findsOneWidget);

      await tester.tap(pasteFinder);
      await tester.pumpAndSettle();

      expect(pasteCalled, isTrue);
    });

    testWidgets('renders footer widget when provided', (tester) async {
      await tester.pumpWidget(
        buildCanvas(footer: const Text('Custom Terminal Footer')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Terminal Footer'), findsOneWidget);
    });

    testWidgets(
      'displays copy button when selection is active and copies text on tap',
      (tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        terminal.write('Hello World');
        final controller = TerminalController();

        await tester.pumpWidget(buildCanvas(controller: controller));
        await tester.pumpAndSettle();

        // Initially no selection -> copy button hidden
        expect(
          find.byKey(const Key('terminal_copy_selection_button')),
          findsNothing,
        );

        // Set selection
        controller.setSelection(
          terminal.buffer.createAnchor(0, 0),
          terminal.buffer.createAnchor(5, 0),
        );
        await tester.pumpAndSettle();

        // Copy button now appears
        final copyBtn = find.byKey(const Key('terminal_copy_selection_button'));
        expect(copyBtn, findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);

        // Tap copy button
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        // Clipboard received text
        expect(copiedText, 'Hello');

        // Selection should be cleared and button dismissed
        expect(controller.selection, isNull);
        expect(
          find.byKey(const Key('terminal_copy_selection_button')),
          findsNothing,
        );
      },
    );

    testWidgets('clear button dismisses selection and copy button', (
      tester,
    ) async {
      terminal.write('Sample Terminal Text');
      final controller = TerminalController();

      await tester.pumpWidget(buildCanvas(controller: controller));
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(6, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('terminal_clear_selection_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('terminal_clear_selection_button')),
      );
      await tester.pumpAndSettle();

      expect(controller.selection, isNull);
      expect(
        find.byKey(const Key('terminal_copy_selection_button')),
        findsNothing,
      );
    });
  });

  group('SharedTerminalCanvas terminal font size', () {
    late Terminal terminal;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      terminal = Terminal(maxLines: 100);
    });

    Future<LocalStorageService> freshStorage() async =>
        LocalStorageService(await SharedPreferences.getInstance());

    double pumpedViewFontSize(WidgetTester tester) => tester
        .widget<TerminalView>(find.byType(TerminalView))
        .textStyle
        .fontSize;

    testWidgets('defaults to fontSize 13 from terminalSettingsProvider', (
      tester,
    ) async {
      // 走真实 provider + 缺键存储，验证默认字号路径。
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(await freshStorage()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _canvasApp(terminal),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 13);
    });

    testWidgets(
      'uses overridden provider fontSize (20) for the TerminalView style',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              terminalSettingsProvider.overrideWith(
                () => _FixedFontSizeNotifier(20),
              ),
            ],
            child: _canvasApp(terminal),
          ),
        );
        await tester.pumpAndSettle();

        expect(pumpedViewFontSize(tester), 20);
      },
    );

    testWidgets('explicit textStyle parameter wins over provider fontSize', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            terminalSettingsProvider.overrideWith(
              () => _FixedFontSizeNotifier(20),
            ),
          ],
          child: _canvasApp(
            terminal,
            textStyle: const TerminalStyle(fontSize: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 7);
    });

    testWidgets('changing the provider value live-updates the canvas', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(await freshStorage()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _canvasApp(terminal),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 13);

      await container.read(terminalSettingsProvider.notifier).setFontSize(20);
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 20);
    });
  });
}

/// 画布最小宿主：与手势用例相同的布局，供字号用例按需包 ProviderScope。
Widget _canvasApp(Terminal terminal, {TerminalStyle? textStyle}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 600,
        child: SharedTerminalCanvas(
          terminal: terminal,
          onKey: (_, {isCtrl = false, isAlt = false}) {},
          onPaste: () async {},
          textStyle: textStyle,
        ),
      ),
    ),
  );
}

/// 直接以固定字号构建 notifier，免注入存储。
class _FixedFontSizeNotifier extends TerminalSettingsNotifier {
  final int size;

  _FixedFontSizeNotifier(this.size);

  @override
  TerminalSettings build() => TerminalSettings(useTmux: false, fontSize: size);
}
