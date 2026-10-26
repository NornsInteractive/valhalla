import 'package:xterm/core.dart';

class TerminalBufferMatch {
  final CellAnchor start, end;
  const TerminalBufferMatch(this.start, this.end);
  BufferRange? get range => start.attached && end.attached
      ? BufferRangeLine(start.offset, end.offset)
      : null;
  bool isCurrent(Buffer buffer, String query) {
    final value = range;
    return value != null &&
        start.y >= 0 &&
        end.y >= 0 &&
        start.y < buffer.height &&
        end.y < buffer.height &&
        identical(buffer.lines[start.y], start.line) &&
        identical(buffer.lines[end.y], end.line) &&
        RegExp(
          '^${RegExp.escape(query)}\$',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(buffer.getText(value));
  }

  void dispose() {
    start.dispose();
    end.dispose();
  }
}

/// Search only local scrollback, yielding between bounded groups of rows.
Future<List<TerminalBufferMatch>> searchTerminalBuffer(
  Buffer buffer,
  String query, {
  bool Function()? isCancelled,
  int maxMatches = 1000,
}) async {
  if (query.isEmpty) return [];
  if (query.length > 512 || maxMatches < 1 || maxMatches > 1000) {
    throw ArgumentError('TERMINAL_SEARCH_INVALID_QUERY');
  }
  final pattern = RegExp(
    RegExp.escape(query),
    caseSensitive: false,
    unicode: true,
  );
  final lines = buffer.lines.toList();
  final matches = <TerminalBufferMatch>[];
  final group = <(BufferLine, String, int)>[];
  var content = StringBuffer();
  var length = 0;
  final budget = Stopwatch()..start();
  CellAnchor anchorAt(int offset, {required bool end}) {
    var index = group.length - 1;
    for (var i = 0; i < group.length; i++) {
      if (offset < group[i].$3 + group[i].$2.length ||
          (end && offset == group[i].$3 + group[i].$2.length)) {
        index = i;
        break;
      }
    }
    final line = group[index].$1;
    final target = offset - group[index].$3;
    var units = 0;
    var column = 0;
    while (column < line.length) {
      if (units >= target) break;
      final point = line.getCodePoint(column);
      final width = line.getWidth(column);
      if (point != 0) units += point > 0xffff ? 2 : 1;
      column++;
      // Wide characters occupy continuation cells without a code point.
      if (units >= target) {
        if (width > 1) {
          column = (column + width - 1).clamp(0, line.length).toInt();
        }
        break;
      }
    }
    return line.createAnchor(column);
  }

  void flush() {
    if (group.isEmpty) return;
    // A stream may overwrite rows while the search yields.
    if (group.every((row) => row.$1.attached && row.$1.getText() == row.$2)) {
      for (final found in pattern.allMatches(content.toString())) {
        if (matches.length >= maxMatches) break;
        matches.add(
          TerminalBufferMatch(
            anchorAt(found.start, end: false),
            anchorAt(found.end, end: true),
          ),
        );
      }
    }
    group.clear();
    content = StringBuffer();
    length = 0;
  }

  for (var i = 0; i < lines.length && matches.length < maxMatches; i++) {
    if (isCancelled?.call() == true) {
      for (final match in matches) {
        match.dispose();
      }
      return [];
    }
    final line = lines[i];
    if (!line.isWrapped) flush();
    final text = line.getText();
    group.add((line, text, length));
    content.write(text);
    length += text.length;
    if (budget.elapsedMilliseconds >= 4) {
      await Future<void>.delayed(Duration.zero);
      budget.reset();
    }
  }
  flush();
  if (isCancelled?.call() == true) {
    for (final match in matches) {
      match.dispose();
    }
    return [];
  }
  return matches;
}
