import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_buffer_search.dart';
import 'package:xterm/core.dart';

Terminal _terminal({int maxLines = 1000}) => Terminal(maxLines: maxLines);

Future<List<TerminalBufferMatch>> _search(
  Terminal terminal,
  String query, {
  bool Function()? isCancelled,
  int maxMatches = 1000,
}) => searchTerminalBuffer(
  terminal.buffer,
  query,
  isCancelled: isCancelled,
  maxMatches: maxMatches,
);

String _textOf(Terminal terminal, TerminalBufferMatch match) {
  final range = match.range;
  expect(range, isNotNull, reason: 'matched anchors must stay attached');
  return terminal.buffer.getText(range);
}

int _anchorCount(Terminal terminal) {
  var count = 0;
  for (final line in terminal.buffer.lines.toList()) {
    count += line.anchors.length;
  }
  return count;
}

void main() {
  test('matches ASCII, CJK and emoji with exact buffer text', () async {
    final terminal = _terminal();
    terminal.write('alpha needle omega\r\n');
    terminal.write('中文 测试 关键词 结束\r\n');
    terminal.write('emoji 😀🚀 needle 🚀 end\r\n');

    final ascii = await _search(terminal, 'needle');
    expect(ascii, hasLength(2));
    for (final match in ascii) {
      expect(_textOf(terminal, match), 'needle');
    }

    final cjk = await _search(terminal, '关键词');
    expect(cjk, hasLength(1));
    expect(_textOf(terminal, cjk.single), '关键词');

    final emoji = await _search(terminal, '😀🚀');
    expect(emoji, hasLength(1));
    expect(_textOf(terminal, emoji.single), '😀🚀');
    for (final match in [...ascii, ...cjk, ...emoji]) {
      match.dispose();
    }
  });

  test('astral characters map to the correct cell anchors', () async {
    final terminal = _terminal();
    terminal.write('😀target🚀');

    final matches = await _search(terminal, 'target');
    expect(matches, hasLength(1));
    final match = matches.single;
    expect(_textOf(terminal, match), 'target');
    // The leading emoji occupies two terminal cells.
    expect(match.start.x, 2);
    expect(match.end.x, 8);
    match.dispose();
  });

  test('soft-wrapped matches read back exactly through getText', () async {
    final terminal = _terminal();
    // 78 columns of padding, then the query straddles the 80-column wrap.
    terminal.write('${'A' * 78}needle');

    final matches = await _search(terminal, 'needle');
    expect(matches, hasLength(1));
    expect(_textOf(terminal, matches.single), 'needle');
    matches.single.dispose();
  });

  test(
    'scrollback trimming detaches anchors and invalidates the match',
    () async {
      final terminal = _terminal(maxLines: 30);
      terminal.write('line 0 keeps a searchable token\r\n');
      final matches = await _search(terminal, 'searchable');
      expect(matches, hasLength(1));
      final match = matches.single;
      expect(match.start.attached, isTrue);
      expect(match.isCurrent(terminal.buffer, 'searchable'), isTrue);

      for (var i = 1; i < 120; i++) {
        terminal.write('line $i filler\r\n');
      }

      expect(match.start.attached, isFalse);
      expect(match.end.attached, isFalse);
      expect(match.range, isNull);
      expect(match.isCurrent(terminal.buffer, 'searchable'), isFalse);
      match.dispose();
    },
  );

  test('mutating the buffer invalidates a previously matched anchor', () async {
    final terminal = _terminal();
    terminal.write('needle');
    final matches = await _search(terminal, 'needle');
    expect(matches, hasLength(1));
    final match = matches.single;
    expect(match.isCurrent(terminal.buffer, 'needle'), isTrue);

    terminal.write('\rXXXXXX');

    expect(match.isCurrent(terminal.buffer, 'needle'), isFalse);
    match.dispose();
  });

  test(
    'anchors do not validate against identical text in another buffer',
    () async {
      const content = 'shared needle token';
      final terminal = _terminal();
      terminal.write(content);
      final matches = await _search(terminal, 'needle');
      expect(matches, hasLength(1));
      final match = matches.single;
      expect(match.start.x, 7);
      expect(match.isCurrent(terminal.buffer, 'needle'), isTrue);

      // A different Terminal with the same text and cell coordinates.
      final other = _terminal();
      other.write(content);
      expect(other.buffer.getText(), terminal.buffer.getText());
      expect(
        other.buffer.getText(
          BufferRangeLine(const CellOffset(7, 0), const CellOffset(13, 0)),
        ),
        'needle',
      );
      expect(match.isCurrent(other.buffer, 'needle'), isFalse);

      // The same Terminal's alternate buffer also reuses those coordinates.
      terminal.useAltBuffer();
      terminal.write(content);
      expect(match.isCurrent(terminal.buffer, 'needle'), isFalse);
      expect(match.isCurrent(terminal.mainBuffer, 'needle'), isTrue);

      match.dispose();
    },
  );

  test('cancellation returns no results and disposes every anchor', () async {
    final terminal = _terminal();
    for (var i = 0; i < 10; i++) {
      terminal.write('hit $i\r\n');
    }

    var checks = 0;
    final matches = await _search(
      terminal,
      'hit',
      isCancelled: () {
        checks++;
        return checks >= 6;
      },
    );

    expect(matches, isEmpty);
    expect(checks, greaterThanOrEqualTo(6));
    expect(
      _anchorCount(terminal),
      0,
      reason: 'partial anchors must be disposed',
    );
  });

  test('caps matches at the 1000 default maximum', () async {
    final terminal = _terminal(maxLines: 2000);
    for (var i = 0; i < 1200; i++) {
      terminal.write('hit $i\r\n');
    }

    final matches = await _search(terminal, 'hit');
    expect(matches, hasLength(1000));
    for (final match in matches) {
      match.dispose();
    }
  });

  test('empty queries and no-match queries return no results', () async {
    final terminal = _terminal();
    terminal.write('only content here\r\n');

    expect(await _search(terminal, ''), isEmpty);
    expect(await _search(terminal, 'absent-token'), isEmpty);
  });

  test('rejects an over-long query and out-of-range caps', () async {
    final terminal = _terminal();
    terminal.write('content');

    await expectLater(
      _search(terminal, 'a' * 513),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'TERMINAL_SEARCH_INVALID_QUERY',
        ),
      ),
    );
    await expectLater(
      _search(terminal, 'content', maxMatches: 0),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      _search(terminal, 'content', maxMatches: 1001),
      throwsA(isA<ArgumentError>()),
    );
  });
}
