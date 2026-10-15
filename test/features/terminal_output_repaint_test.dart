import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
// The vendored renderer is the regression boundary for incoming SSH output.
// ignore: implementation_imports
import 'package:xterm/src/ui/render.dart';

void main() {
  testWidgets(
    'new terminal output repaints without focus or keyboard changes',
    (tester) async {
      final terminal = Terminal();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: false,
              requestKeyboardOnTap: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final render = tester.allRenderObjects.whereType<RenderTerminal>().single;
      expect(render.debugNeedsPaint, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      terminal.write('server prompt: ready');
      expect(
        render.debugNeedsPaint,
        isTrue,
        reason: 'same-size output must invalidate the repaint boundary',
      );
      await tester.pump();
      expect(render.debugNeedsPaint, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
