import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';

/// 控制字符在失败输出里可读。
String _readable(String data) => data
    .replaceAll('\x1b', '<ESC>')
    .replaceAll('\x01', '<SOH>')
    .replaceAll('\x02', '<STX>')
    .replaceAll('\x03', '<ETX>')
    .replaceAll('\t', '<TAB>');

void main() {
  group('terminal modifiers: toolbar taps through the real encoder', () {
    late Terminal terminal;
    late List<String> written;

    setUp(() {
      terminal = Terminal(maxLines: 100);
      written = <String>[];
      terminal.onOutput = written.add;
    });

    /// 宿主与既有画布用例同构：800x600 保证工具栏键全部可见。
    Widget canvas(Terminal target) => ProviderScope(
      overrides: fixedTerminalSettingsOverrides(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            textScaler: TextScaler.linear(1.0),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: SharedTerminalCanvas(
                terminal: target,
                onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
                  sendTerminalAccessoryKey(
                    target,
                    key,
                    isCtrl: isCtrl,
                    isAlt: isAlt,
                    isShift: isShift,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    /// 画布交给 TerminalView 的文本输入钩子（单次修饰键消费的唯一入口）。
    bool Function(String) inputHook(WidgetTester tester) =>
        tester.widget<TerminalView>(find.byType(TerminalView)).onTextInput!;

    String bytes() => written.map(_readable).join();

    testWidgets('Shift tap + TAB emits reverse-tab once, then plain TAB', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_accessory_key_SHIFT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal_accessory_key_TAB')));
      await tester.pumpAndSettle();

      expect(bytes(), '<ESC>[Z', reason: 'Shift+Tab 必须编码成反向制表 ESC[Z');

      await tester.tap(find.byKey(const Key('terminal_accessory_key_TAB')));
      await tester.pumpAndSettle();

      expect(
        bytes(),
        '<ESC>[Z<TAB>',
        reason: 'one-shot Shift 消费后，第二个 TAB 必须退回普通制表',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Ctrl tap + input hook: first a is SOH, next a passes through',
      (tester) async {
        await tester.pumpWidget(canvas(terminal));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
        await tester.pumpAndSettle();

        final onTextInput = inputHook(tester);
        expect(
          onTextInput('a'),
          isTrue,
          reason: 'one-shot Ctrl 必须消费这次输入并发出 SOH',
        );
        expect(bytes(), '<SOH>');

        expect(
          onTextInput('a'),
          isFalse,
          reason: 'one-shot 只消费一次，第二次必须放行给终端默认路径',
        );
        expect(
          bytes(),
          '<SOH>',
          reason: '放行的 a 不得再走修饰键编码，TerminalView 回落路径负责直写',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'held Ctrl: chord before 500ms, hold past 600ms, release must not lock',
      (tester) async {
        await tester.pumpWidget(canvas(terminal));
        await tester.pumpAndSettle();

        final onTextInput = inputHook(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const Key('terminal_accessory_key_CTRL')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(onTextInput('a'), isTrue, reason: 'pointer-down 立即让按住的 Ctrl 生效');
        expect(bytes(), '<SOH>');

        await tester.pump(const Duration(milliseconds: 600));
        expect(onTextInput('b'), isTrue, reason: '超过长按阈值后仍在按住，键必须继续带 Ctrl');
        expect(bytes(), '<SOH><STX>');

        await gesture.up();
        await tester.pump();

        expect(onTextInput('c'), isFalse, reason: '用过和弦的按住释放不得留下锁定状态');
        expect(bytes(), '<SOH><STX>', reason: '释放后不得再补发任何键');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'terminal replacement while pointer held leaves the new target clean',
      (tester) async {
        await tester.pumpWidget(canvas(terminal));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const Key('terminal_accessory_key_CTRL')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final other = Terminal(maxLines: 100);
        final otherWritten = <String>[];
        other.onOutput = otherWritten.add;
        await tester.pumpWidget(canvas(other));
        await tester.pumpAndSettle();

        await gesture.up();
        await tester.pump();

        expect(inputHook(tester)('a'), isFalse, reason: '目标切换后旧指针的释放不得给新终端上闩');
        expect(otherWritten, isEmpty, reason: '新终端此前不得收到任何键');
        expect(written, isEmpty, reason: '替换前不得向旧终端发键');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('long-press Ctrl without a chord locks, tap unlocks again', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      final onTextInput = inputHook(tester);
      await tester.longPress(
        find.byKey(const Key('terminal_accessory_key_CTRL')),
      );
      await tester.pumpAndSettle();

      expect(onTextInput('a'), isTrue, reason: '无和弦的长按释放必须锁定 Ctrl');
      expect(onTextInput('b'), isTrue, reason: '锁定态必须对第二个键继续生效');
      expect(bytes(), '<SOH><STX>');

      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();

      expect(onTextInput('c'), isFalse, reason: '再次点按必须解锁，不得把锁定态翻成 one-shot');
      expect(bytes(), '<SOH><STX>', reason: '解锁后不得再补发任何键');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ctrl+Shift+Alt tap then a emits ESC SOH once, next a passes', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      final onTextInput = inputHook(tester);
      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal_accessory_key_SHIFT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal_accessory_key_ALT')));
      await tester.pumpAndSettle();

      expect(onTextInput('a'), isTrue, reason: '三个 one-shot 修饰键必须同时作用于这一次输入');
      expect(bytes(), '<ESC><SOH>', reason: 'Alt+Ctrl+Shift+a = ESC SOH');
      expect(onTextInput('a'), isFalse, reason: '组合发出后所有 one-shot 都必须被消费');
      expect(bytes(), '<ESC><SOH>');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fn tap maps IME 1 to F1 and software backspace to Delete', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      final onTextInput = inputHook(tester);

      await tester.tap(find.byKey(const Key('terminal_accessory_key_FN')));
      await tester.pumpAndSettle();
      expect(onTextInput('1'), isTrue, reason: 'Fn+1 必须交给本地 Fn 映射');
      expect(bytes(), '<ESC>OP', reason: 'Fn+1 -> F1 -> ESC OP');

      await tester.tap(find.byKey(const Key('terminal_accessory_key_FN')));
      await tester.pumpAndSettle();
      expect(
        onTextInput('\b'),
        isTrue,
        reason: '软件退格钩子在 Fn 激活时必须被归一化成 BACKSPACE',
      );
      expect(bytes(), '<ESC>OP<ESC>[3~', reason: 'Fn+退格 -> Delete -> ESC[3~');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ctrl latch keeps a single CJK commit literal and armed', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      final onTextInput = inputHook(tester);
      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();

      expect(
        onTextInput('中'),
        isFalse,
        reason: '单个非 ASCII 汉字必须原样放行，不得被 Ctrl 折叠',
      );
      expect(written, isEmpty, reason: '放行的汉字不在此钩子里发送');

      expect(
        onTextInput('a'),
        isTrue,
        reason: 'CJK 放行不得消耗 one-shot，下一个 a 仍须是 Ctrl 组合',
      );
      expect(bytes(), '<SOH>');
      expect(tester.takeException(), isNull);
    });

    testWidgets('latched Ctrl routes a physical letter key to SOH', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();

      expect(bytes(), '<SOH>', reason: '工具栏 Ctrl + 物理 a 必须发出 SOH');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'local Alt makes physical Ctrl+C emit ESC ETX and keeps Ctrl+V paste + latch',
      (tester) async {
        await tester.pumpWidget(canvas(terminal));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TerminalView));
        await tester.pumpAndSettle();

        // 本地 Alt 激活时，物理 Ctrl+C 是远端中断，不是本地复制。
        await tester.tap(find.byKey(const Key('terminal_accessory_key_ALT')));
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(
          bytes(),
          '<ESC><ETX>',
          reason: '本地 Alt + 物理 Ctrl+C 必须编码成 ESC ETX，不得走本地复制',
        );

        written.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                return {'text': 'hello'};
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        // 本地 Alt 仍然武装时，物理 Ctrl+V 是本地粘贴快捷键，不得消耗闩锁。
        await tester.tap(find.byKey(const Key('terminal_accessory_key_ALT')));
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(bytes(), 'hello', reason: '物理 Ctrl+V 必须仍然粘贴单行剪贴板内容');
        expect(inputHook(tester)('a'), isTrue, reason: '本地粘贴快捷键不得消耗 Alt 闩锁');
        expect(bytes(), 'hello<ESC>a', reason: '闩锁保留时下一个 a 必须是 ESC a');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('pointer drag beyond slop or cancel must not arm Ctrl', (
      tester,
    ) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      final onTextInput = inputHook(tester);
      final center = tester.getCenter(
        find.byKey(const Key('terminal_accessory_key_CTRL')),
      );

      final drag = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      await drag.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await drag.up();
      await tester.pumpAndSettle();

      expect(onTextInput('a'), isFalse, reason: '超过滑动阈值的拖动必须中止，不得在释放时上闩');
      expect(written, isEmpty, reason: '拖动中止后不得发出任何字节');

      final cancel = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('terminal_accessory_key_CTRL'))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await cancel.cancel();
      await tester.pumpAndSettle();

      expect(
        onTextInput('a'),
        isFalse,
        reason: 'pointer cancel 必须清掉按住状态，不得留下闩锁',
      );
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('losing input focus clears a latched Ctrl', (tester) async {
      await tester.pumpWidget(canvas(terminal));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminal_accessory_key_CTRL')));
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(
        inputHook(tester)('a'),
        isFalse,
        reason: '输入焦点丢失后必须清掉闩锁，不得污染之后的输入',
      );
      expect(written, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
