import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Terminal selection handles tests', () {
    testWidgets('handles are hidden when no selection and appear when selection is set', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 50);
      terminal.write('Hello World! Testing selection handles.\r\n');

      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no selection -> no handles
      expect(find.byKey(const Key('terminal_selection_start_handle')), findsNothing);
      expect(find.byKey(const Key('terminal_selection_end_handle')), findsNothing);

      // Set selection on "Hello" (indices 0 to 5)
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      // Both handles should appear
      expect(find.byKey(const Key('terminal_selection_start_handle')), findsOneWidget);
      expect(find.byKey(const Key('terminal_selection_end_handle')), findsOneWidget);

      // Clearing selection removes handles
      controller.clearSelection();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal_selection_start_handle')), findsNothing);
      expect(find.byKey(const Key('terminal_selection_end_handle')), findsNothing);
    });

    testWidgets('dragging end handle expands selection range', (tester) async {
      final terminal = Terminal(maxLines: 50);
      terminal.write('abcdefghijklmnopqrstuvwxyz\r\n');

      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set initial selection on "abc" (0 to 3)
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(3, 0),
      );
      await tester.pumpAndSettle();

      expect(terminal.buffer.getText(controller.selection), equals('abc'));
      final initialEndX = controller.selection!.normalized.end.x;

      // Find the end handle
      final endHandle = find.byKey(const Key('terminal_selection_end_handle'));
      expect(endHandle, findsOneWidget);

      // Drag end handle to the right by ~60 pixels
      await tester.drag(endHandle, const Offset(60, 0));
      await tester.pumpAndSettle();

      // Selection range should have expanded to include more characters
      final newEndX = controller.selection!.normalized.end.x;
      expect(newEndX, greaterThan(initialEndX));
      expect(terminal.buffer.getText(controller.selection).length, greaterThan(3));
    });

    testWidgets('dragging start handle expands selection to the left', (tester) async {
      final terminal = Terminal(maxLines: 50);
      terminal.write('abcdefghijklmnopqrstuvwxyz\r\n');

      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set initial selection from 5 to 10 ("fghij")
      controller.setSelection(
        terminal.buffer.createAnchor(5, 0),
        terminal.buffer.createAnchor(10, 0),
      );
      await tester.pumpAndSettle();

      expect(terminal.buffer.getText(controller.selection), equals('fghij'));
      final initialBeginX = controller.selection!.normalized.begin.x;

      final startHandle = find.byKey(const Key('terminal_selection_start_handle'));
      expect(startHandle, findsOneWidget);

      // Drag start handle to the left by ~40 pixels
      await tester.drag(startHandle, const Offset(-40, 0));
      await tester.pumpAndSettle();

      // Start position should have moved to the left (smaller X index)
      final newBeginX = controller.selection!.normalized.begin.x;
      expect(newBeginX, lessThan(initialBeginX));
      expect(terminal.buffer.getText(controller.selection).length, greaterThan(5));
    });

    testWidgets('start handle cannot cross end handle when dragged past it', (tester) async {
      final terminal = Terminal(maxLines: 50);
      terminal.write('1234567890\r\n');

      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set initial selection at (2, 0) to (5, 0)
      controller.setSelection(
        terminal.buffer.createAnchor(2, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      final startHandle = find.byKey(const Key('terminal_selection_start_handle'));

      // Drag start handle aggressively far to the right (+300px)
      await tester.drag(startHandle, const Offset(300, 0));
      await tester.pumpAndSettle();

      // Selection must still be valid and begin must not exceed end
      final sel = controller.selection!.normalized;
      expect(sel.begin.x, lessThanOrEqualTo(sel.end.x));
      expect(controller.selection, isNotNull);
    });

    testWidgets('tap outside handles clears selection and removes handles', (tester) async {
      final terminal = Terminal(maxLines: 50);
      terminal.write('Some line with words to select\r\n');

      final controller = TerminalController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(5, 0),
        terminal.buffer.createAnchor(10, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal_selection_start_handle')), findsOneWidget);
      expect(controller.selection, isNotNull);

      // Tap on empty area at bottom of terminal (e.g. at y = 200, far from line 0)
      await tester.tapAt(const Offset(300, 200));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Selection cleared and handles dismissed
      expect(controller.selection, isNull);
      expect(find.byKey(const Key('terminal_selection_start_handle')), findsNothing);
      expect(find.byKey(const Key('terminal_selection_end_handle')), findsNothing);
    });
  });
}
