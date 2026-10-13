import 'package:xterm/xterm.dart';

/// Route accessory keys through the same encoder as hardware keyboard input.
void sendTerminalAccessoryKey(
  Terminal terminal,
  String key, {
  bool isCtrl = false,
  bool isAlt = false,
  bool isShift = false,
}) {
  const keys = <String, TerminalKey>{
    'ESC': TerminalKey.escape,
    'TAB': TerminalKey.tab,
    'ENTER': TerminalKey.enter,
    'BACKSPACE': TerminalKey.backspace,
    'DELETE': TerminalKey.delete,
    'INSERT': TerminalKey.insert,
    'HOME': TerminalKey.home,
    'END': TerminalKey.end,
    'PGUP': TerminalKey.pageUp,
    'PGDN': TerminalKey.pageDown,
    '↑': TerminalKey.arrowUp,
    '↓': TerminalKey.arrowDown,
    '←': TerminalKey.arrowLeft,
    '→': TerminalKey.arrowRight,
    'F1': TerminalKey.f1,
    'F2': TerminalKey.f2,
    'F3': TerminalKey.f3,
    'F4': TerminalKey.f4,
    'F5': TerminalKey.f5,
    'F6': TerminalKey.f6,
    'F7': TerminalKey.f7,
    'F8': TerminalKey.f8,
    'F9': TerminalKey.f9,
    'F10': TerminalKey.f10,
    'F11': TerminalKey.f11,
    'F12': TerminalKey.f12,
  };
  final special = keys[key];
  if (special != null) {
    terminal.keyInput(special, ctrl: isCtrl, alt: isAlt, shift: isShift);
    return;
  }
  if (key.runes.length != 1) return;
  // Printable keys are not all represented in TerminalKey (for example '/').
  var text = key;
  if (isShift) {
    const shiftedKeys = <String, String>{
      '`': '~',
      '1': '!',
      '2': '@',
      '3': '#',
      '4': r'$',
      '5': '%',
      '6': '^',
      '7': '&',
      '8': '*',
      '9': '(',
      '0': ')',
      '-': '_',
      '=': '+',
      '[': '{',
      ']': '}',
      '\\': '|',
      ';': ':',
      "'": '"',
      ',': '<',
      '.': '>',
      '/': '?',
    };
    final code = text.codeUnitAt(0);
    text =
        shiftedKeys[text] ??
        (code >= 97 && code <= 122 ? text.toUpperCase() : text);
  }
  if (isCtrl) {
    final code = text.toUpperCase().codeUnitAt(0);
    if (code >= 64 && code <= 95) {
      text = String.fromCharCode(code & 31);
    } else if (text == '?') {
      text = '\x7f';
    } else {
      return;
    }
  }
  terminal.textInput('${isAlt ? '\x1b' : ''}$text');
}

/// Fn is a local key layer; terminals receive the mapped key, not an Fn flag.
String terminalFnKey(String key) => switch (key) {
  '1' => 'F1',
  '2' => 'F2',
  '3' => 'F3',
  '4' => 'F4',
  '5' => 'F5',
  '6' => 'F6',
  '7' => 'F7',
  '8' => 'F8',
  '9' => 'F9',
  '0' => 'F10',
  '-' => 'F11',
  '=' => 'F12',
  '←' => 'HOME',
  '→' => 'END',
  '↑' => 'PGUP',
  '↓' => 'PGDN',
  'BACKSPACE' => 'DELETE',
  _ => key,
};
