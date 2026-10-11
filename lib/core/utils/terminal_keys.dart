import 'package:xterm/xterm.dart';

/// Route accessory keys through the same encoder as hardware keyboard input.
void sendTerminalAccessoryKey(
  Terminal terminal,
  String key, {
  bool isCtrl = false,
  bool isAlt = false,
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
    terminal.keyInput(special, ctrl: isCtrl, alt: isAlt);
    return;
  }
  if (key.runes.length != 1) return;
  // Printable keys are not all represented in TerminalKey (for example '/').
  var text = key;
  if (isCtrl) {
    final code = key.toUpperCase().codeUnitAt(0);
    if (code >= 64 && code <= 95) {
      text = String.fromCharCode(code & 31);
    } else if (key == '?') {
      text = '\x7f';
    } else {
      return;
    }
  }
  terminal.textInput('${isAlt ? '\x1b' : ''}$text');
}
