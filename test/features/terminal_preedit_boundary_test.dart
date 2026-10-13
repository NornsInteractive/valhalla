import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';

Future<void> _withEditor(
  WidgetTester tester, {
  bool deleteDetection = false,
  bool Function(String)? onComposingInput,
  required Future<void> Function(
    CustomTextEditState state,
    List<String> inserted,
    List<String?> composing,
  )
  check,
}) async {
  final focusNode = FocusNode();
  final editKey = GlobalKey<CustomTextEditState>();
  final inserted = <String>[];
  final composing = <String?>[];
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomTextEdit(
          key: editKey,
          focusNode: focusNode,
          deleteDetection: deleteDetection,
          onInsert: inserted.add,
          onDelete: () {},
          onComposing: composing.add,
          onComposingInput: onComposingInput,
          onAction: (_) {},
          onKeyEvent: (_, _) => KeyEventResult.ignored,
          child: const SizedBox(width: 320, height: 200),
        ),
      ),
    );
    editKey.currentState!.requestKeyboard();
    await tester.pump();
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
    await check(editKey.currentState!, inserted, composing);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    focusNode.dispose();
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('consumed ASCII preedit preserves delete-detection sentinel', (
    tester,
  ) async {
    final offered = <String>[];
    await _withEditor(
      tester,
      deleteDetection: true,
      onComposingInput: (text) {
        offered.add(text);
        return true;
      },
      check: (state, inserted, composing) async {
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '  c',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 2, end: 3),
          ),
        );
        await tester.pump();

        const initial = TextEditingValue(
          text: '  ',
          selection: TextSelection.collapsed(offset: 2),
        );
        expect(offered, ['c']);
        expect(inserted, isEmpty);
        expect(composing, [null]);
        expect(state.currentTextEditingValue, initial);
        expect(tester.testTextInput.editingState, initial.toJSON());
      },
    );
  });

  testWidgets('only a whole fresh printable ASCII preedit reaches the hook', (
    tester,
  ) async {
    final offered = <String>[];
    await _withEditor(
      tester,
      deleteDetection: true,
      onComposingInput: (text) {
        offered.add(text);
        return true;
      },
      check: (state, inserted, composing) async {
        for (final (name, text, range) in [
          ('invalid sentinel prefix', 'xxc', const TextRange(start: 2, end: 3)),
          ('committed prefix', '  xc', const TextRange(start: 3, end: 4)),
          ('nonwhole preedit', '  c', const TextRange(start: 1, end: 3)),
          ('control character', '  \n', const TextRange(start: 2, end: 3)),
        ]) {
          final value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: range,
          );
          tester.testTextInput.updateEditingValue(value);
          await tester.pump();

          expect(offered, isEmpty, reason: name);
          expect(inserted, isEmpty, reason: name);
          expect(composing.last, range.textInside(text), reason: name);
          expect(state.currentTextEditingValue, value, reason: name);
        }
      },
    );
  });

  testWidgets(
    'declined ASCII, CJK and multicharacter composition stay pending',
    (tester) async {
      final offered = <String>[];
      await _withEditor(
        tester,
        onComposingInput: (text) {
          offered.add(text);
          return false;
        },
        check: (state, inserted, composing) async {
          for (final text in ['c', '中', 'zhong']) {
            final value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange(start: 0, end: text.length),
            );
            tester.testTextInput.updateEditingValue(value);
            await tester.pump();

            expect(inserted, isEmpty);
            expect(composing.last, text);
            expect(state.currentTextEditingValue, value);
          }
          expect(offered, ['c']);
        },
      );
    },
  );

  testWidgets('without the optional hook composition still waits for commit', (
    tester,
  ) async {
    await _withEditor(
      tester,
      check: (state, inserted, composing) async {
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'c',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        );
        await tester.pump();
        expect(inserted, isEmpty);
        expect(composing, ['c']);
        expect(state.currentTextEditingValue!.composing.isCollapsed, isFalse);

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'c',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        expect(inserted, ['c']);
        expect(composing, ['c', null]);
      },
    );
  });
}
