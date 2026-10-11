import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/customize_pinned_keys_dialog.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('SharedTerminalCanvas Gestures and Controls', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(maxLines: 100);
    });

    Widget buildCanvas({
      void Function(String key, {bool isCtrl, bool isAlt})? onKey,
      Future<void> Function()? onPaste,
      void Function(String text)? onPasteText,
      Widget? footer,
      TerminalController? controller,
      Terminal? canvasTerminal,
      double width = 800,
      double height = 600,
      double textScale = 1.0,
    }) => _canvas(
      canvasTerminal ?? terminal,
      onKey: onKey,
      onPaste: onPaste,
      onPasteText: onPasteText,
      footer: footer,
      controller: controller,
      width: width,
      height: height,
      textScale: textScale,
    );

    testWidgets(
      'Windows text client has a view ID and supports text and IME',
      (tester) async {
        final output = <String>[];
        terminal.onOutput = output.add;
        await tester.pumpWidget(buildCanvas());
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        final call = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        final config = (call.arguments as List)[1] as Map;
        expect(config['viewId'], tester.view.viewId);
        tester.testTextInput.enterText('abc123');
        await tester.pump();
        expect(output.join(), 'abc123');
        output.clear();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'zhong',
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 0, end: 5),
          ),
        );
        await tester.pump();
        expect(output, isEmpty);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '中文',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        expect(output.join(), '中文');
        output.clear();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(output.join(), contains('\r'));
        expect(output.join(), contains('\x7f'));
        expect(output.join(), contains('\x1b[A'));
        expect(output.join(), contains('\x03'));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                return {'text': 'paste-中文'};
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(output.join(), contains('paste-中文'));
        expect(tester.takeException(), isNull);
        // A new client must attach correctly after another control takes focus.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        tester.testTextInput.enterText('again');
        expect(output.join(), contains('again'));
      },
      variant: TargetPlatformVariant({TargetPlatform.windows}),
    );

    testWidgets(
      'non-Windows text input preserves its existing configuration',
      (tester) async {
        await tester.pumpWidget(buildCanvas());
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();
        final call = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        expect(((call.arguments as List)[1] as Map)['viewId'], isNull);
        await tester.pump(const Duration(milliseconds: 400));
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    testWidgets('renders terminal and accessory bar with action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildCanvas());
      await tester.pumpAndSettle();

      expect(find.byType(SharedTerminalCanvas), findsOneWidget);
      // Verify accessory bar keys exist
      expect(find.text('ESC'), findsOneWidget);
      expect(find.text('TAB'), findsOneWidget);
      expect(find.text('CTRL'), findsOneWidget);
    });

    testWidgets(
      'renders TerminalView directly without gesture listener interception',
      (tester) async {
        final List<String> sentKeys = [];

        await tester.pumpWidget(
          buildCanvas(
            onKey: (key, {isCtrl = false, isAlt = false}) => sentKeys.add(key),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TerminalView), findsOneWidget);

        // Long press drag should not emit synthetic directional arrows
        final canvasCenter = tester.getCenter(
          find.byType(SharedTerminalCanvas),
        );
        final gesture = await tester.startGesture(canvasCenter);
        await tester.pump(const Duration(milliseconds: 700));
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(sentKeys, isEmpty);
      },
    );

    // 画布现在自己接管 PASTE（见 SharedTerminalCanvas 的类注释：统一接管多行
    // 粘贴确认），legacy onPaste 不再被调用；此处断言新契约。
    testWidgets('accessory bar paste button delivers the clipboard text', (
      tester,
    ) async {
      final pasted = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': 'single line'};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        buildCanvas(onPaste: () async {}, onPasteText: pasted.add),
      );
      await tester.pumpAndSettle();

      final pasteFinder = find.byIcon(Icons.content_paste);
      expect(pasteFinder, findsOneWidget);

      await tester.tap(pasteFinder);
      await tester.pumpAndSettle();

      expect(pasted, ['single line'], reason: '单行粘贴不需要确认，直接发送');
    });

    testWidgets('renders footer widget when provided', (tester) async {
      await tester.pumpWidget(
        buildCanvas(footer: const Text('Custom Terminal Footer')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Terminal Footer'), findsOneWidget);
    });

    testWidgets(
      'displays copy button when selection is active and copies text on tap',
      (tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        terminal.write('Hello World');
        final controller = TerminalController();

        await tester.pumpWidget(buildCanvas(controller: controller));
        await tester.pumpAndSettle();

        // Initially no selection -> copy button hidden
        expect(
          find.byKey(const Key('terminal_copy_selection_button')),
          findsNothing,
        );

        // Set selection
        controller.setSelection(
          terminal.buffer.createAnchor(0, 0),
          terminal.buffer.createAnchor(5, 0),
        );
        await tester.pumpAndSettle();

        // Copy button now appears
        final copyBtn = find.byKey(const Key('terminal_copy_selection_button'));
        expect(copyBtn, findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);

        // Tap copy button
        await tester.tap(copyBtn);
        await tester.pumpAndSettle();

        // Clipboard received text
        expect(copiedText, 'Hello');

        // Selection should be cleared and button dismissed
        expect(controller.selection, isNull);
        expect(
          find.byKey(const Key('terminal_copy_selection_button')),
          findsNothing,
        );
      },
    );

    testWidgets('clear button dismisses selection and copy button', (
      tester,
    ) async {
      terminal.write('Sample Terminal Text');
      final controller = TerminalController();

      await tester.pumpWidget(buildCanvas(controller: controller));
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(6, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('terminal_clear_selection_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('terminal_clear_selection_button')),
      );
      await tester.pumpAndSettle();

      expect(controller.selection, isNull);
      expect(
        find.byKey(const Key('terminal_copy_selection_button')),
        findsNothing,
      );
    });
  });

  group('SharedTerminalCanvas terminal font size', () {
    late Terminal terminal;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      terminal = Terminal(maxLines: 100);
    });

    Future<LocalStorageService> freshStorage() async =>
        LocalStorageService(await SharedPreferences.getInstance());

    double pumpedViewFontSize(WidgetTester tester) => tester
        .widget<TerminalView>(find.byType(TerminalView))
        .textStyle
        .fontSize;

    testWidgets('defaults to fontSize 13 from terminalSettingsProvider', (
      tester,
    ) async {
      // 走真实 provider + 缺键存储，验证默认字号路径。
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(await freshStorage()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _canvasApp(terminal),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 13);
    });

    testWidgets(
      'uses overridden provider fontSize (20) for the TerminalView style',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              terminalSettingsProvider.overrideWith(
                () => _FixedFontSizeNotifier(20),
              ),
            ],
            child: _canvasApp(terminal),
          ),
        );
        await tester.pumpAndSettle();

        expect(pumpedViewFontSize(tester), 20);
      },
    );

    testWidgets('explicit textStyle parameter wins over provider fontSize', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            terminalSettingsProvider.overrideWith(
              () => _FixedFontSizeNotifier(20),
            ),
          ],
          child: _canvasApp(
            terminal,
            textStyle: const TerminalStyle(fontSize: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 7);
    });

    testWidgets('changing the provider value live-updates the canvas', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(await freshStorage()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _canvasApp(terminal),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 13);

      await container.read(terminalSettingsProvider.notifier).setFontSize(20);
      await tester.pumpAndSettle();

      expect(pumpedViewFontSize(tester), 20);
    });
  });

  group('SharedTerminalCanvas 粘贴确认的 TOCTOU 保护', () {
    late Terminal terminal;
    late Terminal otherTerminal;
    var clipboardReads = 0;
    final pasted = <String>[];
    final otherPasted = <String>[];
    var legacyPasteCalls = 0;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      terminal = Terminal(maxLines: 100);
      otherTerminal = Terminal(maxLines: 100);
      clipboardReads = 0;
      pasted.clear();
      otherPasted.clear();
      legacyPasteCalls = 0;
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
    });

    testWidgets('确认后剪贴板只读取一次，且不再回调 legacy onPaste', (tester) async {
      await tester.pumpWidget(
        _canvas(
          terminal,
          onPasteText: pasted.add,
          onPaste: () async => legacyPasteCalls++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();
      expect(clipboardReads, 1, reason: 'PASTE 只应在进入流程时读一次剪贴板');

      await tester.tap(find.byKey(const Key('terminal_confirm_paste_button')));
      await tester.pumpAndSettle();

      expect(pasted, ['first\nsecond']);
      expect(clipboardReads, 1, reason: '确认后必须发送已固化的文本，不得二次读取剪贴板');
      expect(legacyPasteCalls, 0, reason: 'legacy onPaste 会重读剪贴板，必须不触发');
      expect(otherTerminal.paste, isNotNull);
    });

    testWidgets('取消确认不发送任何文本', (tester) async {
      await tester.pumpWidget(_canvas(terminal, onPasteText: pasted.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(pasted, isEmpty);
      expect(clipboardReads, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('确认对话框期间切换终端，绝不发送到新终端', (tester) async {
      await tester.pumpWidget(
        _canvas(terminal, onPasteText: (text) => pasted.add('old:$text')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();

      // 对话框悬空期间宿主切到另一个终端（回调也随之重建）。
      await tester.pumpWidget(
        _canvas(otherTerminal, onPasteText: (text) => otherPasted.add(text)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_confirm_paste_button')));
      await tester.pumpAndSettle();

      expect(pasted, isEmpty, reason: '发起时的终端已不是当前终端');
      expect(otherPasted, isEmpty, reason: '绝不能把文本发给新终端');
      expect(tester.takeException(), isNull);
    });

    testWidgets('CLI 发起终端守卫：切换后回调自身也拒绝发送', (tester) async {
      // 复刻 cli_chat_view.dart 的守卫形态：闭包捕获 originatingTerminal，
      // 仅当“当前”终端仍是它时才发送。
      var currentTerminal = terminal;
      void cliGuarded(String text) {
        if (identical(currentTerminal, terminal)) {
          pasted.add(text);
        }
      }

      final before = cliGuarded;
      await tester.pumpWidget(_canvas(terminal, onPasteText: cliGuarded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();

      currentTerminal = otherTerminal;
      await tester.tap(find.byKey(const Key('terminal_confirm_paste_button')));
      await tester.pumpAndSettle();

      expect(pasted, isEmpty);
      expect(
        () => before('probe'),
        returnsNormally,
        reason: '守卫回调在切换后调用必须安全拒绝而不是崩溃',
      );
      expect(pasted, isEmpty, reason: '守卫在 current != originating 时必须拒绝');
    });
  });

  group('SharedTerminalCanvas 移动端修饰键 + IME', () {
    late Terminal terminal;
    late List<String> keys;
    late List<(String, bool, bool)> modifiers;
    late String output;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      terminal = Terminal(maxLines: 100);
      output = '';
      terminal.onOutput = (data) => output += data;
      keys = <String>[];
      modifiers = <(String, bool, bool)>[];
    });

    Widget imeCanvas() => _canvas(
      terminal,
      onKey: (key, {isCtrl = false, isAlt = false}) {
        keys.add(key);
        modifiers.add((key, isCtrl, isAlt));
      },
    );

    /// 通过按键栏的键盘按钮打开 IME，再喂入一次插入。
    Future<void> openIme(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
      );
      await tester.pump();
      await tester.pump();
    }

    void typeText(WidgetTester tester, String text) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    testWidgets('oneShot Ctrl：首个 c 变 Ctrl-C，随后 c 恢复普通输入', (tester) async {
      await tester.pumpWidget(imeCanvas());
      await tester.pumpAndSettle();
      await openIme(tester);

      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();

      typeText(tester, 'c');
      await tester.pump();
      expect(modifiers, [('c', true, false)]);
      expect(output, isEmpty, reason: '组合键走 onKey，不应直写终端');

      typeText(tester, 'c');
      await tester.pump();
      expect(modifiers, hasLength(1), reason: 'one-shot 只消费一次');
      expect(output, 'c', reason: '修饰键失效后 c 应作为普通文本送达');
    });

    testWidgets('锁定 Ctrl：连续输入都保持 Ctrl 组合', (tester) async {
      await tester.pumpWidget(imeCanvas());
      await tester.pumpAndSettle();
      await openIme(tester);

      await tester.longPress(
        find.byKey(const Key('terminal_accessory_key_CTRL')),
      );
      await tester.pumpAndSettle();

      typeText(tester, 'c');
      await tester.pump();
      typeText(tester, 'd');
      await tester.pump();

      expect(modifiers, [('c', true, false), ('d', true, false)]);
      expect(output, isEmpty);
    });

    testWidgets('Alt：one-shot 组合一次后恢复', (tester) async {
      await tester.pumpWidget(imeCanvas());
      await tester.pumpAndSettle();
      await openIme(tester);

      await tester.tap(find.byKey(const Key('terminal_accessory_key_ALT')));
      await tester.pumpAndSettle();

      typeText(tester, 'x');
      await tester.pump();
      expect(modifiers, [('x', false, true)]);

      typeText(tester, 'x');
      await tester.pump();
      expect(modifiers, hasLength(1));
      expect(output, 'x');
    });

    testWidgets('切换终端后修饰键被重置', (tester) async {
      await tester.pumpWidget(imeCanvas());
      await tester.pumpAndSettle();
      await openIme(tester);

      await tester.longPress(
        find.byKey(const Key('terminal_accessory_key_CTRL')),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _canvas(
          Terminal(maxLines: 100),
          onKey: (key, {isCtrl = false, isAlt = false}) {
            keys.add(key);
            modifiers.add((key, isCtrl, isAlt));
          },
        ),
      );
      await tester.pumpAndSettle();

      typeText(tester, 'c');
      await tester.pump();
      expect(modifiers, isEmpty, reason: '残留的锁定 Ctrl 不得污染新会话');
    });

    testWidgets('未激活修饰键时 CJK 组合态不受影响', (tester) async {
      await tester.pumpWidget(imeCanvas());
      await tester.pumpAndSettle();
      await openIme(tester);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'zhong',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      expect(modifiers, isEmpty);
      expect(output, isEmpty, reason: '组合中的拼音不得泄漏到终端');

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中文',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(modifiers, isEmpty, reason: 'CJK 提交走默认路径，不经修饰键');
      expect(output, '中文');
    });
  });

  group('HoldRepeatKey 按住重复', () {
    testWidgets('pointer cancel 后停止重复', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: HoldRepeatKey(
              onPressed: () => presses++,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldRepeatKey)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(presses, greaterThan(1), reason: '长按应进入重复');

      final seen = presses;
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 400));
      expect(presses, seen, reason: 'pointer cancel 必须立刻停止重复');
    });

    testWidgets('dispose 后定时器不再回调', (tester) async {
      var presses = 0;
      Widget build(bool show) => MaterialApp(
        home: Center(
          child: show
              ? HoldRepeatKey(
                  onPressed: () => presses++,
                  child: const SizedBox(width: 40, height: 40),
                )
              : const SizedBox.shrink(),
        ),
      );

      await tester.pumpWidget(build(true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldRepeatKey)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(presses, greaterThan(1));

      await tester.pumpWidget(build(false));
      final seen = presses;
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.cancel();
      expect(presses, seen, reason: 'widget 移除后不得继续触发 onPressed');
    });
  });

  group('CustomizePinnedKeysDialog', () {
    testWidgets('保存后按新顺序落库', (tester) async {
      final notifier = _RecordingPinnedNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [terminalSettingsProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Center(child: CustomizePinnedKeysDialog())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 追加一个未固定的键。
      await tester.tap(find.widgetWithText(ActionChip, '↑'));
      await tester.pumpAndSettle();
      expect(notifier.saved, isEmpty, reason: '未点保存前不得落库');

      // 把 ESC 拖到列表末尾。
      // 列表是 buildDefaultDragHandles: false，只有每行 leading 的 44dp
      // ReorderableDragStartListener 会启动重排，所以必须从真实把手开始，
      // 并按真实行几何斜移到真实末行。
      final dragHandle = find.descendant(
        of: find.byKey(const ValueKey('pinned_ESC')),
        matching: find.byType(ReorderableDragStartListener),
      );
      expect(dragHandle, findsOneWidget, reason: 'ESC 行必须暴露拖拽把手');
      final lastRow = find.byKey(const ValueKey('pinned_↑'));
      expect(lastRow, findsOneWidget, reason: '追加的 ↑ 应是当前末行');
      final lastRowBottom = tester.getRect(lastRow).bottom;
      final lastRowHeight = tester.getRect(lastRow).height;
      final midRowTAB = tester
          .getCenter(find.byKey(const ValueKey('pinned_TAB')))
          .dy;
      final midRowCTRL = tester
          .getCenter(find.byKey(const ValueKey('pinned_CTRL')))
          .dy;
      final handleCenter = tester.getCenter(dragHandle);
      // +4 越过末行严格边界：SDK 条件是 itemEnd < proxyItemStart，
      // 目标取末行下方 4px 才能让代理 start(332) > 末行 end(328)，
      // 否则恰好压在边界上不满足严格小于。
      final targetPoint = Offset(
        handleCenter.dx,
        lastRowBottom + lastRowHeight / 2 + 4,
      );

      final gesture = await tester.startGesture(handleCenter);
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveTo(Offset(handleCenter.dx, midRowTAB));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveTo(Offset(handleCenter.dx, midRowCTRL));
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveTo(targetPoint);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(lastRowBottom, greaterThan(handleCenter.dy));

      await tester.tap(
        find.byKey(const Key('terminal_save_pinned_keys_button')),
      );
      await tester.pumpAndSettle();

      expect(
        notifier.saved,
        hasLength(1),
        reason: 'FULL saved=${notifier.saved}',
      );
      final saved = notifier.saved.single;
      expect(saved, hasLength(4), reason: 'FULL saved=$saved');
      expect(
        saved.last,
        'ESC',
        reason:
            'ESC 应被拖到末尾 | FULL saved=$saved | '
            'handleCenter=$handleCenter targetPoint=$targetPoint '
            'lastRowBottom=$lastRowBottom lastRowHeight=$lastRowHeight '
            'midRowTAB=$midRowTAB midRowCTRL=$midRowCTRL',
      );
      expect(saved.toSet(), {
        'ESC',
        'TAB',
        'CTRL',
        '↑',
      }, reason: 'FULL saved=$saved');
    });

    testWidgets('保存失败必须可见地提示且对话框不关闭', (tester) async {
      final notifier = _RecordingPinnedNotifier(failing: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [terminalSettingsProvider.overrideWith(() => notifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Center(child: CustomizePinnedKeysDialog())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('terminal_save_pinned_keys_button')),
      );
      await tester.pumpAndSettle();

      expect(notifier.saved, hasLength(1));
      expect(find.byType(CustomizePinnedKeysDialog), findsOneWidget);
      expect(find.textContaining('Failed to save pinned keys'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SharedTerminalCanvas 窄屏与大字号', () {
    late Terminal terminal;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      terminal = Terminal(maxLines: 100);
    });

    testWidgets('360px 宽 + textScaler 2 无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _canvas(terminal, width: 360, height: 640, textScale: 2.0),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SharedTerminalCanvas), findsOneWidget);
    });

    testWidgets('360px 下的固定键对话框 + textScaler 2 无溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            terminalSettingsProvider.overrideWith(
              () => _RecordingPinnedNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const Scaffold(
                body: Center(child: CustomizePinnedKeysDialog()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('SharedTerminalCanvas 长按选择保留', () {
    testWidgets('长按选词后出现复制按钮并可复制', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final terminal = Terminal(maxLines: 100);
      terminal.write('hello world');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            terminalSettingsProvider.overrideWith(
              () => _FixedFontSizeNotifier(13),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: SharedTerminalCanvas(
                  terminal: terminal,
                  onKey: (_, {isCtrl = false, isAlt = false}) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

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

      final topLeft = tester.getTopLeft(find.byType(TerminalView));
      final gesture = await tester.startGesture(topLeft + const Offset(14, 16));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('terminal_copy_selection_button')),
        findsOneWidget,
        reason: '长按选词后必须给出复制入口',
      );

      await tester.tap(find.byKey(const Key('terminal_copy_selection_button')));
      await tester.pumpAndSettle();

      expect(copied, 'hello');
    });
  });
}

/// 画布宿主：固定字号 notifier 免注入存储，可指定尺寸与字号缩放。
Widget _canvas(
  Terminal terminal, {
  void Function(String key, {bool isCtrl, bool isAlt})? onKey,
  Future<void> Function()? onPaste,
  void Function(String text)? onPasteText,
  Widget? footer,
  TerminalController? controller,
  double width = 800,
  double height = 600,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      terminalSettingsProvider.overrideWith(() => _FixedFontSizeNotifier(13)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: SharedTerminalCanvas(
              terminal: terminal,
              onKey: onKey ?? (_, {isCtrl = false, isAlt = false}) {},
              onPaste: onPaste ?? () async {},
              onPasteText: onPasteText,
              footer: footer,
              controller: controller,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 记录 setPinnedKeys 调用的 notifier，可选模拟落盘失败。
class _RecordingPinnedNotifier extends TerminalSettingsNotifier {
  _RecordingPinnedNotifier({this.failing = false});

  final bool failing;
  final List<List<String>> saved = [];

  @override
  TerminalSettings build() => TerminalSettings(
    useTmux: false,
    fontSize: 13,
    pinnedKeys: const ['ESC', 'TAB', 'CTRL'],
  );

  @override
  Future<void> setPinnedKeys(List<String> keys) async {
    saved.add(List.of(keys));
    if (failing) {
      throw StateError('storage offline');
    }
    state = state.copyWith(pinnedKeys: List.unmodifiable(keys));
  }
}

/// 画布最小宿主：与手势用例相同的布局，供字号用例按需包 ProviderScope。
Widget _canvasApp(Terminal terminal, {TerminalStyle? textStyle}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 600,
        child: SharedTerminalCanvas(
          terminal: terminal,
          onKey: (_, {isCtrl = false, isAlt = false}) {},
          onPaste: () async {},
          textStyle: textStyle,
        ),
      ),
    ),
  );
}

/// 直接以固定字号构建 notifier，免注入存储。
class _FixedFontSizeNotifier extends TerminalSettingsNotifier {
  final int size;

  _FixedFontSizeNotifier(this.size);

  @override
  TerminalSettings build() => TerminalSettings(useTmux: false, fontSize: size);
}
