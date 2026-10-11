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
  String setup = '',
}) {
  final terminal = Terminal();
  final written = <String>[];
  terminal.onOutput = written.add;
  if (setup.isNotEmpty) terminal.write(setup);
  // Drop anything the remote produced while entering the mode.
  written.clear();
  sendTerminalAccessoryKey(terminal, key, isCtrl: isCtrl, isAlt: isAlt);
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
        sendTerminalAccessoryKey(terminal, key, isCtrl: true, isAlt: true);
      }
      expect(events, hasLength(specialKeys.length));
      expect(events.every((e) => e.ctrl && e.alt), isTrue);
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
