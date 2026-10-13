import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:xterm/xterm.dart';

/// Makes control characters readable in failure output.
String _readable(String data) => data
    .replaceAll('\x1b', '<ESC>')
    .replaceAll('\x7f', '<DEL>')
    .replaceAll('\t', '<TAB>')
    .replaceAll('\r', '<CR>');

/// DECCKM: applications switch cursor keys (not the keypad) with these.
const _appCursorKeysOn = '\x1b[?1h';
const _appCursorKeysOff = '\x1b[?1l';

/// Sends one accessory key and returns every chunk written to the pty.
///
/// [setup] is raw remote output the terminal has already processed, which is
/// how an application that switched cursor modes (vim/tmux/emacs) behaves.
List<String> _send(
  String key, {
  bool isCtrl = false,
  bool isAlt = false,
  bool isShift = false,
  String setup = '',
}) {
  final terminal = Terminal();
  final written = <String>[];
  terminal.onOutput = written.add;
  if (setup.isNotEmpty) terminal.write(setup);
  // Drop anything the remote produced while entering the mode.
  written.clear();
  sendTerminalAccessoryKey(
    terminal,
    key,
    isCtrl: isCtrl,
    isAlt: isAlt,
    isShift: isShift,
  );
  return written.map(_readable).toList();
}

/// Asserts a single escape sequence was written to the pty.
Matcher _sends(String data) => equals([_readable(data)]);

/// Typed [TerminalInputHandler] that records every event it is handed.
class _RecordingInputHandler implements TerminalInputHandler {
  final List<TerminalKeyboardEvent> events;
  _RecordingInputHandler(this.events);

  @override
  String? call(TerminalKeyboardEvent event) {
    events.add(event);
    return null;
  }
}

void main() {
  group('normal cursor mode', () {
    test('arrow keys send the CSI form the remote expects', () {
      expect(_send('↑'), _sends('\x1b[A'));
      expect(_send('↓'), _sends('\x1b[B'));
      expect(_send('→'), _sends('\x1b[C'));
      expect(_send('←'), _sends('\x1b[D'));
    });

    test('home, end and editing keys send their plain sequences', () {
      expect(_send('HOME'), _sends('\x1b[H'));
      expect(_send('END'), _sends('\x1b[F'));
      expect(_send('ENTER'), _sends('\r'));
      expect(_send('BACKSPACE'), _sends('\x7f'));
      expect(_send('DELETE'), _sends('\x1b[3~'));
      expect(_send('INSERT'), _sends('\x1b[2~'));
      expect(_send('PGUP'), _sends('\x1b[5~'));
      expect(_send('PGDN'), _sends('\x1b[6~'));
      expect(_send('TAB'), _sends('\t'));
      expect(_send('ESC'), _sends('\x1b'));
    });

    test('function keys and printable characters pass through', () {
      expect(_send('F1'), _sends('\x1bOP'));
      expect(_send('F5'), _sends('\x1b[15~'));
      expect(_send('F12'), _sends('\x1b[24~'));
      expect(_send('/'), _sends('/'));
    });
  });

  group('application cursor mode', () {
    test('arrow keys switch to the SS3 form', () {
      expect(_send('↑', setup: _appCursorKeysOn), _sends('\x1bOA'));
      expect(_send('↓', setup: _appCursorKeysOn), _sends('\x1bOB'));
      expect(_send('→', setup: _appCursorKeysOn), _sends('\x1bOC'));
      expect(_send('←', setup: _appCursorKeysOn), _sends('\x1bOD'));
    });

    test('home and end switch to the SS3 form', () {
      expect(_send('HOME', setup: _appCursorKeysOn), _sends('\x1bOH'));
      expect(_send('END', setup: _appCursorKeysOn), _sends('\x1bOF'));
    });

    test('leaving the mode restores the normal CSI form', () {
      final setup = '$_appCursorKeysOn$_appCursorKeysOff';
      expect(_send('↑', setup: setup), _sends('\x1b[A'));
      expect(_send('HOME', setup: setup), _sends('\x1b[H'));
    });

    test('mode only affects keys that have an SS3 variant', () {
      expect(_send('ENTER', setup: _appCursorKeysOn), _sends('\r'));
      expect(_send('BACKSPACE', setup: _appCursorKeysOn), _sends('\x7f'));
      expect(_send('DELETE', setup: _appCursorKeysOn), _sends('\x1b[3~'));
      expect(_send('TAB', setup: _appCursorKeysOn), _sends('\t'));
    });
  });

  group('ctrl modifier on printable keys', () {
    test('letters are folded into their control character', () {
      expect(_send('c', isCtrl: true), _sends('\x03'));
      expect(_send('a', isCtrl: true), _sends('\x01'));
      expect(_send('z', isCtrl: true), _sends('\x1a'));
      expect(_send('C', isCtrl: true), _sends('\x03'));
    });

    test('punctuation inside the control range is folded too', () {
      expect(_send('[', isCtrl: true), _sends('\x1b'));
      expect(_send(']', isCtrl: true), _sends('\x1d'));
    });

    test("ctrl+'?' backspaces out a word, matching DEL", () {
      expect(_send('?', isCtrl: true), _sends('\x7f'));
    });

    test('ctrl on a key outside the control range sends nothing', () {
      expect(_send('/', isCtrl: true), isEmpty);
      expect(_send('1', isCtrl: true), isEmpty);
    });
  });

  group('alt modifier on printable keys', () {
    test('alt prefixes the character with ESC', () {
      expect(_send('x', isAlt: true), _sends('\x1bx'));
      expect(_send('b', isAlt: true), _sends('\x1bb'));
    });

    test('ctrl and alt combine into one ESC-prefixed control character', () {
      expect(_send('X', isCtrl: true, isAlt: true), _sends('\x1b\x18'));
    });
  });

  group('shift modifier on printable keys', () {
    test('shift+tab sends the reverse-tab sequence', () {
      expect(_send('TAB', isShift: true), _sends('\x1b[Z'));
    });

    test('shift folds letters into their uppercase form', () {
      expect(_send('a', isShift: true), _sends('A'));
      expect(_send('q', isShift: true), _sends('Q'));
    });

    test('shift maps the ASCII/US digit and symbol row', () {
      expect(_send('1', isShift: true), _sends('!'));
      expect(_send('/', isShift: true), _sends('?'));
      expect(_send('-', isShift: true), _sends('_'));
    });

    test('ctrl+shift+letter keeps the normal control encoding', () {
      expect(_send('a', isCtrl: true, isShift: true), _sends('\x01'));
      expect(_send('c', isCtrl: true, isShift: true), _sends('\x03'));
    });

    test("ctrl+shift+'/' still folds to DEL after the shift map", () {
      expect(_send('/', isCtrl: true, isShift: true), _sends('\x7f'));
    });

    test('shift and alt combine into one ESC-prefixed shifted letter', () {
      expect(_send('x', isAlt: true, isShift: true), _sends('\x1bX'));
    });
  });

  group('arrow keys carry the true CSI modifier in both buffers', () {
    const buffers = <String, String>{'normal': '', 'alternate': '\x1b[?1049h'};
    const arrows = <String, String>{'↑': 'A', '↓': 'B', '→': 'C', '←': 'D'};

    /// Sends every arrow with the same modifiers in both buffers and asserts
    /// the exact sequence built from [sequence].
    void expectAllArrows(
      String label,
      String Function(String letter) sequence, {
      bool ctrl = false,
      bool shift = false,
      bool alt = false,
    }) {
      buffers.forEach((buffer, setup) {
        arrows.forEach((key, letter) {
          expect(
            _send(key, setup: setup, isCtrl: ctrl, isShift: shift, isAlt: alt),
            _sends(sequence(letter)),
            reason: '$label | $key | $buffer buffer',
          );
        });
      });
    }

    test('plain arrows are unchanged in both buffers', () {
      expectAllArrows('plain', (letter) => '\x1b[$letter');
    });

    test('ctrl arrows keep modifier 5 in both buffers', () {
      expectAllArrows('ctrl', (letter) => '\x1b[1;5$letter', ctrl: true);
    });

    test('shift arrows report modifier 2 in both buffers', () {
      expectAllArrows('shift', (letter) => '\x1b[1;2$letter', shift: true);
    });

    test('ctrl+shift arrows report modifier 6 in both buffers', () {
      expectAllArrows(
        'ctrl+shift',
        (letter) => '\x1b[1;6$letter',
        ctrl: true,
        shift: true,
      );
    });

    test('alt+shift arrows report modifier 4 in both buffers', () {
      expectAllArrows(
        'alt+shift',
        (letter) => '\x1b[1;4$letter',
        alt: true,
        shift: true,
      );
    });
  });

  group('terminalFnKey is a local mapping', () {
    test('digits map to F1..F10, minus/equals to F11/F12', () {
      expect(terminalFnKey('1'), 'F1');
      expect(terminalFnKey('2'), 'F2');
      expect(terminalFnKey('3'), 'F3');
      expect(terminalFnKey('4'), 'F4');
      expect(terminalFnKey('5'), 'F5');
      expect(terminalFnKey('6'), 'F6');
      expect(terminalFnKey('7'), 'F7');
      expect(terminalFnKey('8'), 'F8');
      expect(terminalFnKey('9'), 'F9');
      expect(terminalFnKey('0'), 'F10');
      expect(terminalFnKey('-'), 'F11');
      expect(terminalFnKey('='), 'F12');
    });

    test('arrows map to navigation keys and backspace to delete', () {
      expect(terminalFnKey('←'), 'HOME');
      expect(terminalFnKey('→'), 'END');
      expect(terminalFnKey('↑'), 'PGUP');
      expect(terminalFnKey('↓'), 'PGDN');
      expect(terminalFnKey('BACKSPACE'), 'DELETE');
    });

    test('unmapped keys pass through unchanged', () {
      expect(terminalFnKey('F5'), 'F5');
      expect(terminalFnKey('ENTER'), 'ENTER');
      expect(terminalFnKey('c'), 'c');
      expect(terminalFnKey('CTRL'), 'CTRL');
    });

    test('mapped keys reach the pty as their function/named key bytes', () {
      expect(_send(terminalFnKey('1')), _sends('\x1bOP'));
      expect(_send(terminalFnKey('5')), _sends('\x1b[15~'));
      expect(_send(terminalFnKey('0')), _sends('\x1b[21~'));
      expect(_send(terminalFnKey('=')), _sends('\x1b[24~'));
      expect(_send(terminalFnKey('↑')), _sends('\x1b[5~'));
      expect(_send(terminalFnKey('BACKSPACE')), _sends('\x1b[3~'));
    });
  });

  group('modifier forwarding on special keys', () {
    test('ctrl changes the sequence produced for editing keys', () {
      expect(_send('DELETE', isCtrl: true), _sends('\x1b[3;5~'));
      expect(_send('BACKSPACE', isCtrl: true), _sends('\x08'));
    });

    test('ctrl changes the sequence produced for function keys', () {
      expect(_send('F1', isCtrl: true), _sends('\x1bO5P'));
    });

    test('modifiers reach the encoder for every mapped key', () {
      final terminal = Terminal();
      final events = <TerminalKeyboardEvent>[];
      terminal.inputHandler = _RecordingInputHandler(events);
      const specialKeys = [
        'ESC',
        'TAB',
        'ENTER',
        'BACKSPACE',
        'DELETE',
        'INSERT',
        'HOME',
        'END',
        'PGUP',
        'PGDN',
        '↑',
        'F1',
      ];
      for (final key in specialKeys) {
        sendTerminalAccessoryKey(
          terminal,
          key,
          isCtrl: true,
          isAlt: true,
          isShift: true,
        );
      }
      expect(events, hasLength(specialKeys.length));
      expect(events.every((e) => e.ctrl && e.alt && e.shift), isTrue);
      expect(events.map((e) => e.key), contains(TerminalKey.arrowUp));
    });

    test('no modifiers by default', () {
      final terminal = Terminal();
      final events = <TerminalKeyboardEvent>[];
      terminal.inputHandler = _RecordingInputHandler(events);
      sendTerminalAccessoryKey(terminal, 'ENTER');
      expect(events, hasLength(1));
      expect(events.single.ctrl, isFalse);
      expect(events.single.alt, isFalse);
      expect(events.single.shift, isFalse);
    });
  });

  group('unmapped keys', () {
    test('multi-rune labels are dropped instead of typed verbatim', () {
      expect(_send('ctrl'), isEmpty);
      expect(_send('SHIFT'), isEmpty);
      expect(_send('←←'), isEmpty);
    });

    test('a single non-ascii rune is still typed verbatim', () {
      expect(_send('Ω'), _sends('Ω'));
      expect(_send('é'), _sends('é'));
    });
  });
}
