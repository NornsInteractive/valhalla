import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/terminal_grid_harness.dart';

String _readable(String data) => data
    .replaceAll('\x1b', '<ESC>')
    .replaceAll('\x01', '<SOH>')
    .replaceAll('\x02', '<STX>')
    .replaceAll('\x03', '<ETX>')
    .replaceAll('\t', '<TAB>');

Widget _canvas(Terminal terminal) => ProviderScope(
  overrides: fixedTerminalSettingsOverrides(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: SharedTerminalCanvas(
            terminal: terminal,
            onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
              sendTerminalAccessoryKey(
                terminal,
                key,
                isCtrl: isCtrl,
                isAlt: isAlt,
                isShift: isShift,
              );
            },
            requestKeyboardOnTap: false,
          ),
        ),
      ),
    ),
  ),
);

Widget _canvasWithInput(
  Terminal terminal, {
  required ValueListenable<bool> inputEnabled,
  required void Function(String key, {bool isCtrl, bool isAlt, bool isShift})
  onKey,
  ValueListenable<int>? inputEpoch,
  void Function(String text)? onPasteText,
  TerminalController? controller,
}) => ProviderScope(
  overrides: fixedTerminalSettingsOverrides(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: ValueListenableBuilder<bool>(
            valueListenable: inputEnabled,
            builder: (context, enabled, _) => ValueListenableBuilder<int>(
              valueListenable: inputEpoch ?? const _ZeroEpoch(),
              builder: (context, epoch, _) => SharedTerminalCanvas(
                terminal: terminal,
                inputEnabled: enabled,
                inputEpoch: epoch,
                onKey: onKey,
                onPasteText: onPasteText,
                controller: controller,
                requestKeyboardOnTap: false,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

bool Function(String) _inputHook(WidgetTester tester) =>
    tester.widget<TerminalView>(find.byType(TerminalView)).onTextInput!;

class _ZeroEpoch implements ValueListenable<int> {
  const _ZeroEpoch();

  @override
  int get value => 0;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Future<void> _commitIme(WidgetTester tester, String text) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

Future<void> _focusTerminal(WidgetTester tester) async {
  tester
      .state<SharedTerminalCanvasState>(find.byType(SharedTerminalCanvas))
      .requestKeyboard();
  await tester.pump();
  await tester.pump();
  expect(tester.testTextInput.hasAnyClients, isTrue);
}

/// 离线时终端是 readOnly，不应建立 IME 连接；但物理键与本地复制仍需要
/// 焦点。直接聚焦 FocusNode，避免把「离线」误设成「输入法已打开」。
Future<void> _focusTerminalWithoutIme(WidgetTester tester) async {
  final focusNode = tester
      .widget<TerminalView>(find.byType(TerminalView))
      .focusNode;
  expect(focusNode, isNotNull);
  focusNode!.requestFocus();
  await tester.pump();
  await tester.pump();
  expect(
    tester.testTextInput.hasAnyClients,
    isFalse,
    reason: 'offline terminal must stay readOnly and not attach the IME',
  );
}

TerminalViewState _terminalState(WidgetTester tester) =>
    tester.state<TerminalViewState>(find.byType(TerminalView));

Finder _key(String name) => find.byKey(Key('terminal_accessory_key_$name'));

Finder _arrowSlot() =>
    find.ancestor(of: _key('↑'), matching: find.byType(HoldRepeatKey)).first;

// Grid keys are wrapped in a KeyedSubtree whose nearest render object is the
// zero-offset RenderTransform of the drag/settle wrapper. A RenderTransform
// never adds itself to the hit-test path, so Finder.hitTestable() reports zero
// matches even though the key is on screen and tappable. Assert the key is
// laid out inside the canvas instead, then drive the real gesture.
Future<void> _tapKey(WidgetTester tester, String name) async {
  final finder = _key(name);
  expect(finder, findsOneWidget);
  expect(
    tester.getRect(finder),
    isNot(equals(Rect.zero)),
    reason: 'accessory key $name must be laid out before it is tapped',
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _longPressKey(WidgetTester tester, String name) async {
  final finder = _key(name);
  expect(finder, findsOneWidget);
  expect(
    tester.getRect(finder),
    isNot(equals(Rect.zero)),
    reason: 'accessory key $name must be laid out before it is long-pressed',
  );
  await tester.longPress(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required bool reduced,
  required int seed,
}) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final layout = TerminalAccessoryLayout.defaultLayout().copyWith(
    directionSeedColor: seed,
  );
  SharedPreferences.setMockInitialValues({
    'valhalla_terminal_grid_v2': jsonEncode(layout.toJson()),
  });
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        ...fixedTerminalSettingsOverrides(),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.buildTheme(
          brightness: Brightness.light,
          seedColor: const Color(0xff10b981),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 760),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                TerminalAccessoryBar(
                  onKey:
                      (_, {isCtrl = false, isAlt = false, isShift = false}) {},
                  onToggleCtrl: () {},
                  onToggleAlt: () {},
                  onPaste: () {},
                  onToggleKeyboard: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _arrowColor(WidgetTester tester) {
  final face = tester.widget<Container>(_key('↑'));
  return (face.decoration! as BoxDecoration).color!;
}

void main() {
  setUpAll(loadTerminalGridFonts);

  group('accessory modifiers arm and lock through real gestures', () {
    testWidgets('tap arms Ctrl for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'CTRL');
      expect(hook('a'), isTrue);
      expect(_readable(written.join()), '<SOH>');
      expect(hook('b'), isFalse);

      written.clear();
      await _longPressKey(tester, 'CTRL');
      expect(hook('a'), isTrue);
      expect(hook('b'), isTrue);
      expect(_readable(written.join()), '<SOH><STX>');

      await _tapKey(tester, 'CTRL');
      written.clear();
      expect(hook('c'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Alt for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'ALT');
      expect(hook('a'), isTrue);
      expect(_readable(written.join()), '<ESC>a');
      expect(hook('b'), isFalse);

      written.clear();
      await _longPressKey(tester, 'ALT');
      expect(hook('b'), isTrue);
      expect(hook('c'), isTrue);
      expect(_readable(written.join()), '<ESC>b<ESC>c');

      await _tapKey(tester, 'ALT');
      written.clear();
      expect(hook('d'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Shift for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'SHIFT');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z<TAB>');

      written.clear();
      await _longPressKey(tester, 'SHIFT');
      await _tapKey(tester, 'TAB');
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<ESC>[Z<ESC>[Z');

      await _tapKey(tester, 'SHIFT');
      written.clear();
      await _tapKey(tester, 'TAB');
      expect(_readable(written.join()), '<TAB>');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap arms Fn for one key and long-press locks it', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();
      final hook = _inputHook(tester);

      await _tapKey(tester, 'FN');
      expect(hook('1'), isTrue);
      expect(_readable(written.join()), '<ESC>OP');
      expect(hook('1'), isFalse);

      written.clear();
      await _longPressKey(tester, 'FN');
      expect(hook('1'), isTrue);
      expect(hook('2'), isTrue);
      expect(_readable(written.join()), '<ESC>OP<ESC>OQ');

      await _tapKey(tester, 'FN');
      written.clear();
      expect(hook('3'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'more-panel clear-all resets every modifier without sending bytes',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'CTRL');
      await _tapKey(tester, 'ALT');
      await _tapKey(tester, 'SHIFT');
      await _tapKey(tester, 'FN');

      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.oneShot);
      expect(bar.altState, ModifierLockState.oneShot);
      expect(bar.shiftState, ModifierLockState.oneShot);
      expect(bar.fnState, ModifierLockState.oneShot);
      expect(written, isEmpty);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      final clear = find.byKey(const Key('terminal_clear_modifiers_button'));
      expect(clear, findsOneWidget);
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      expect(clear.hitTestable(), findsOneWidget);

      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(
        written,
        isEmpty,
        reason: 'clear-all must not emit terminal bytes',
      );
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.inactive);
      expect(bar.altState, ModifierLockState.inactive);
      expect(bar.shiftState, ModifierLockState.inactive);
      expect(bar.fnState, ModifierLockState.inactive);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      expect(_inputHook(tester)('a'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismissing modifier help never summons the IME',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      final help = find.byKey(const Key('terminal_accessory_help_button'));
      expect(help, findsOneWidget);
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      expect(help.hitTestable(), findsOneWidget);

      await tester.longPress(help);
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.terminalModifierHelp), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text(l10n.terminalModifierHelp), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'reduced motion keeps the grid height and seeded direction color',
    (tester) async {
      const seed = 0xff6750a4;
      await _pumpGrid(tester, reduced: true, seed: seed);

      final theme = Theme.of(tester.element(_key('↑')));
      final expected = ColorScheme.fromSeed(
        seedColor: const Color(seed),
        brightness: theme.brightness,
      ).secondaryContainer;

      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
      expect(_arrowColor(tester), expected);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('terminal_direction_pad'))).height,
        88,
      );
      expect(_arrowColor(tester), expected);

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TerminalAccessoryBar)).height, 98);
      expect(_arrowColor(tester), expected);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing search before its post-frame callback never requests the IME',
    (tester) async {
      final terminal = Terminal(maxLines: 100)..write('content');
      final written = <String>[];
      terminal.onOutput = written.add;
      await tester.pumpWidget(_canvas(terminal));
      await tester.pumpAndSettle();

      final state = tester.state<SharedTerminalCanvasState>(
        find.byType(SharedTerminalCanvas),
      );
      state.openSearch();
      state.closeSearch();
      await tester.pump();
      await tester.pump();

      expect(state.isSearchOpen, isFalse);
      expect(find.byKey(const Key('terminal_search_input')), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'disabling input stops a held arrow repeat and re-enabling never rearms',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final sent = <String>[];
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              sent.add(key),
        ),
      );
      await tester.pumpAndSettle();

      final slot = _arrowSlot();
      final gesture = await tester.startGesture(tester.getCenter(slot));
      await tester.pump(const Duration(milliseconds: 450));
      expect(sent.length, greaterThan(1));
      expect(sent.every((key) => key == '↑'), isTrue);

      enabled.value = false;
      await tester.pump();
      final stoppedAt = sent.length;
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        sent.length,
        stoppedAt,
        reason: 'a disabled canvas must cancel the in-flight hold repeat',
      );

      enabled.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        sent.length,
        stoppedAt,
        reason: 're-enabling input must not revive a cancelled hold',
      );

      await gesture.up();
      await tester.pump();
      expect(sent.length, stoppedAt);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabling input clears an armed modifier and re-enabling never rearms it',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
            sendTerminalAccessoryKey(
              terminal,
              key,
              isCtrl: isCtrl,
              isAlt: isAlt,
              isShift: isShift,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tapKey(tester, 'CTRL');
      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.oneShot);

      enabled.value = false;
      await tester.pumpAndSettle();
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(
        bar.ctrlState,
        ModifierLockState.inactive,
        reason: 'disabling input must drop an armed one-shot modifier',
      );

      enabled.value = true;
      await tester.pumpAndSettle();
      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(
        bar.ctrlState,
        ModifierLockState.inactive,
        reason: 're-enabling input must not re-arm a cleared modifier',
      );

      expect(_inputHook(tester)('a'), isFalse);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing inputEpoch clears an armed modifier while input stays enabled',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(true);
      final epoch = ValueNotifier(0);
      addTearDown(enabled.dispose);
      addTearDown(epoch.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          inputEpoch: epoch,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();

      await _tapKey(tester, 'CTRL');
      var bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(bar.ctrlState, ModifierLockState.oneShot);

      // 同一个连接窗口内的代际变化（例如重连事件）也必须丢弃武装状态，
      // 不能因为 inputEnabled 一直为 true 就保留下来。
      epoch.value = 1;
      await tester.pumpAndSettle();

      bar = tester.widget<TerminalAccessoryBar>(
        find.byType(TerminalAccessoryBar),
      );
      expect(
        bar.ctrlState,
        ModifierLockState.inactive,
        reason: 'inputEpoch 变化必须清掉已武装的修饰键',
      );
      expect(_inputHook(tester)('a'), isFalse, reason: '代际变化后的下一个字母必须是普通输入');
      expect(keys, isEmpty);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline buffer search still works with input disabled and never touches the PTY',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle offline $i\r\n');
      }
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<SharedTerminalCanvasState>(
        find.byType(SharedTerminalCanvas),
      );
      state.openSearch();
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('terminal_search_input')),
        'needle',
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<TerminalView>(find.byType(TerminalView))
          .controller!;
      expect(state.isSearchOpen, isTrue);
      expect(find.byKey(const Key('terminal_search_input')), findsOneWidget);
      expect(controller.highlights, isNotEmpty);
      expect(keys, isEmpty);
      expect(written, isEmpty, reason: 'search must never touch the PTY');
      expect(_terminalState(tester).hasInputConnection, isFalse);

      state.closeSearch();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('terminal_search_input')), findsNothing);
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  group('input disabled emits zero terminal bytes', () {
    testWidgets('ordinary IME ASCII, CJK, enter and delete are consumed', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();
      await _focusTerminalWithoutIme(tester);

      final hook = _inputHook(tester);
      for (final text in ['a', '中文', '\r', '\n', '\b']) {
        expect(
          hook(text),
          isTrue,
          reason:
              'disabled input must consume IME text "$text" instead of '
              'letting TerminalView fall back to textInput/keyInput',
        );
      }
      await _commitIme(tester, 'a');
      await _commitIme(tester, '中文');
      await _commitIme(tester, 'x\r');

      expect(
        written,
        isEmpty,
        reason: 'disabled canvas must not write PTY bytes',
      );
      expect(keys, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('physical enter, delete, arrows and backspace are consumed', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();
      await _focusTerminalWithoutIme(tester);

      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.tab,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      expect(written, isEmpty, reason: 'physical keys must not reach the PTY');
      expect(keys, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending paste is abandoned when inputEpoch changes', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final pasted = <String>[];
      terminal.onOutput = written.add;
      var clipboardReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              clipboardReads++;
              return {'text': 'first\nsecond'};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final enabled = ValueNotifier(true);
      final epoch = ValueNotifier(0);
      addTearDown(enabled.dispose);
      addTearDown(epoch.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          inputEpoch: epoch,
          onKey: (_, {isCtrl = false, isAlt = false, isShift = false}) {},
          onPasteText: pasted.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('terminal_confirm_paste_button')),
        findsOneWidget,
      );
      expect(clipboardReads, 1);

      epoch.value = 1;
      await tester.pump();
      await tester.tap(find.byKey(const Key('terminal_confirm_paste_button')));
      await tester.pumpAndSettle();

      expect(
        pasted,
        isEmpty,
        reason: 'a new input epoch must abort the pending paste',
      );
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending paste is abandoned across disable and re-enable', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final pasted = <String>[];
      terminal.onOutput = written.add;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': 'first\nsecond'};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (_, {isCtrl = false, isAlt = false, isShift = false}) {},
          onPasteText: pasted.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('terminal_confirm_paste_button')),
        findsOneWidget,
      );

      enabled.value = false;
      await tester.pumpAndSettle();
      enabled.value = true;
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_confirm_paste_button')));
      await tester.pumpAndSettle();

      expect(
        pasted,
        isEmpty,
        reason: 're-enabling must not revive a stale paste',
      );
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('local copy shortcut still works while input is disabled', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100)..write('Hello World');
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final controller = TerminalController();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await _focusTerminalWithoutIme(tester);

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(copied, 'Hello', reason: 'local copy must survive disabled input');
      expect(written, isEmpty, reason: 'copy must never write to the PTY');
      expect(keys, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'CJK preedit is not replayed and the IME stays closed across reconnect',
      (tester) async {
        final terminal = Terminal(maxLines: 100);
        final written = <String>[];
        terminal.onOutput = written.add;
        final enabled = ValueNotifier(true);
        final epoch = ValueNotifier(0);
        addTearDown(enabled.dispose);
        addTearDown(epoch.dispose);
        await tester.pumpWidget(
          _canvasWithInput(
            terminal,
            inputEnabled: enabled,
            inputEpoch: epoch,
            onKey: (_, {isCtrl = false, isAlt = false, isShift = false}) {},
          ),
        );
        await tester.pumpAndSettle();
        await _focusTerminal(tester);

        // 组合中的拼音只是 preedit，绝不能写进 PTY。
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'zhong',
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 0, end: 5),
          ),
        );
        await tester.pump();
        expect(written, isEmpty, reason: 'preedit must not reach the PTY');

        // 连接断开：输入必须关闭，旧 preedit 不能留在输入法里。
        enabled.value = false;
        await tester.pumpAndSettle();
        expect(
          _terminalState(tester).hasInputConnection,
          isFalse,
          reason: 'disabling input must close the IME input connection',
        );
        expect(tester.testTextInput.hasAnyClients, isFalse);

        // 重连：不能自动弹键盘，也不能把旧 preedit 重放成文本。
        epoch.value = 1;
        enabled.value = true;
        await tester.pumpAndSettle();
        expect(
          tester.testTextInput.hasAnyClients,
          isFalse,
          reason: 'reconnect must not auto-open the IME',
        );
        expect(_terminalState(tester).hasInputConnection, isFalse);
        expect(
          written,
          isEmpty,
          reason: 'old composing text must not be replayed',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('offline keyboard button does not open the IME', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 100);
      final written = <String>[];
      final keys = <String>[];
      terminal.onOutput = written.add;
      final enabled = ValueNotifier(false);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        _canvasWithInput(
          terminal,
          inputEnabled: enabled,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(
        const Key('terminal_accessory_keyboard_button'),
      );
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        tester.testTextInput.hasAnyClients,
        isFalse,
        reason: 'offline keyboard button must not open the IME',
      );
      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(written, isEmpty);
      expect(keys, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
