import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      return MaterialApp(
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
      );
    }

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
}
