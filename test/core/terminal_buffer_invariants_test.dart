import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_buffer_search.dart';
import 'package:xterm/core.dart';

Terminal _terminal({int maxLines = 100}) => Terminal(maxLines: maxLines);

List<String> _rowTexts(Terminal terminal) =>
    terminal.buffer.lines.toList().map((line) => line.getText()).toList();

List<int> _rowIndices(Terminal terminal) =>
    terminal.buffer.lines.toList().map((line) => line.index).toList();

String _lines(int from, int to, {String Function(int)? render}) =>
    [for (var i = from; i < to; i++) render?.call(i) ?? 'line $i'].join('\r\n');

void main() {
  test('full ring replacement preserves row order and row index', () {
    final terminal = _terminal();
    terminal.write(_lines(0, 200));

    final beforeText = _rowTexts(terminal);
    final beforeIndices = _rowIndices(terminal);
    expect(beforeText, hasLength(100));
    expect(beforeIndices, List.generate(100, (i) => i));

    // A width change reflows the main buffer through replaceWith.
    terminal.resize(90, terminal.viewHeight);

    expect(_rowTexts(terminal), beforeText);
    expect(_rowIndices(terminal), beforeIndices);
  });

  test(
    'clearScrollback detaches removed rows and keeps retained indices 0-based',
    () {
      final terminal = _terminal();
      terminal.write(_lines(0, 100));

      final before = terminal.buffer.lines.toList();
      final removedCount = terminal.buffer.scrollBack;
      expect(removedCount, greaterThan(0));
      expect(before, hasLength(100));

      terminal.buffer.clearScrollback();

      for (var i = 0; i < removedCount; i++) {
        expect(before[i].attached, isFalse, reason: 'row $i must be detached');
      }

      final retained = terminal.buffer.lines.toList();
      expect(retained, hasLength(100 - removedCount));
      expect(_rowIndices(terminal), List.generate(retained.length, (i) => i));
      for (var i = 0; i < retained.length; i++) {
        expect(identical(retained[i], before[removedCount + i]), isTrue);
        expect(retained[i].attached, isTrue);
      }
    },
  );

  test(
    'full ring resize to 90 columns keeps every search hit current',
    () async {
      final terminal = _terminal();
      terminal.write(_lines(0, 200, render: (i) => 'needle $i'));

      terminal.resize(90, terminal.viewHeight);
      expect(terminal.buffer.lines.length, 100);

      final matches = await searchTerminalBuffer(terminal.buffer, 'needle');
      expect(matches, hasLength(100));
      for (final match in matches) {
        expect(match.isCurrent(terminal.buffer, 'needle'), isTrue);
      }
      for (final match in matches) {
        match.dispose();
      }
    },
  );

  test('trimStart rejects negative input and clamps over-length trims', () {
    final terminal = _terminal();
    terminal.write(_lines(0, 50));

    final before = terminal.buffer.lines.toList();
    final beforeText = _rowTexts(terminal);
    final beforeIndices = _rowIndices(terminal);

    expect(() => terminal.buffer.lines.trimStart(-1), throwsRangeError);
    expect(_rowTexts(terminal), beforeText);
    expect(_rowIndices(terminal), beforeIndices);
    for (var i = 0; i < before.length; i++) {
      expect(before[i].attached, isTrue);
      expect(before[i].index, i);
    }

    terminal.buffer.lines.trimStart(1000);

    expect(terminal.buffer.lines.length, 0);
    for (var i = 0; i < before.length; i++) {
      expect(before[i].attached, isFalse, reason: 'row $i must be detached');
    }
  });
}
