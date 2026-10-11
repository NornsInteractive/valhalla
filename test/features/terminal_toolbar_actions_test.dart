import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';

class _Bridge extends TerminalSessionBridge {
  _Bridge() : super(terminal: Terminal(), serverName: 'test');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Notifier extends TerminalNotifier {
  _Notifier(this.initial);

  final SshTerminalState initial;

  @override
  SshTerminalState build() => initial;
}

TerminalTab _tab(String id) {
  final bridge = _Bridge();
  return TerminalTab(
    id: id,
    title: id,
    terminal: bridge.terminal,
    bridge: bridge,
  );
}

Future<void> _pump(WidgetTester tester, _Notifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        terminalProvider.overrideWith(() => notifier),
        terminalSettingsProvider.overrideWith(
          FixedTerminalSettingsNotifier.new,
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SshTerminalView()),
      ),
    ),
  );
  await tester.pump();
}

/// 与 [_pump] 相同的宿主，但把表面压到窄屏 + 大字号。
///
/// 按键栏的可达性回归必须在 320dp / textScale 2 下看：这是键位会溢出并触发
/// 横向滚动的最小现实宽度，键盘按钮若被放回滚动区就会被裁掉。
Future<void> _pumpNarrow(
  WidgetTester tester,
  _Notifier notifier, {
  required Size size,
  required double textScale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        terminalProvider.overrideWith(() => notifier),
        terminalSettingsProvider.overrideWith(
          FixedTerminalSettingsNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: SshTerminalView()),
        ),
      ),
    ),
  );
  await tester.pump();
}

TerminalViewState _terminalState(WidgetTester tester) =>
    tester.state<TerminalViewState>(find.byType(TerminalView));

void main() {
  testWidgets(
    'clicking close on the selected tab removes its session',
    (tester) async {
      final first = _tab('first');
      final second = _tab('second');
      final notifier = _Notifier(
        SshTerminalState(tabs: [first, second], activeTabIndex: 1),
      );
      await _pump(tester, notifier);

      final close = find.descendant(
        of: find.ancestor(
          of: find.text('second'),
          matching: find.byType(InputChip),
        ),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(close);
      await tester.pump();

      expect(notifier.state.tabs, [first]);
      expect(notifier.state.activeTab, same(first));
      expect((second.bridge as _Bridge).disposed, isTrue);
      expect((first.bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      first.bridge.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'closing a tab before the active tab preserves the same session',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, activeTabIndex: 1),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_first')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[1], tabs[2]]);
      expect(notifier.state.activeTab, same(tabs[1]));
      expect(notifier.state.activeTabIndex, 0);
      expect((tabs[0].bridge as _Bridge).disposed, isTrue);
      expect((tabs[1].bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'closing the active middle tab selects the next and removes stale tmux offer',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      final notifier = _Notifier(
        SshTerminalState(
          tabs: tabs,
          activeTabIndex: 1,
          tmuxInstallOffer: const TmuxInstallOffer(
            installCommand: 'install-tmux-for-second',
          ),
        ),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_second')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[0], tabs[2]]);
      expect(notifier.state.activeTab, same(tabs[2]));
      expect(notifier.state.tmuxInstallOffer, isNull);
      expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'closing a later inactive tab keeps the active session and tmux offer',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      const offer = TmuxInstallOffer(installCommand: 'install-tmux-for-first');
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, tmuxInstallOffer: offer),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_third')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[0], tabs[1]]);
      expect(notifier.state.activeTab, same(tabs[0]));
      expect(notifier.state.tmuxInstallOffer, same(offer));
      expect((tabs[2].bridge as _Bridge).disposed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'the last tab stays open and invalid close indices are ignored',
    (tester) async {
      final first = _tab('first');
      final second = _tab('second');
      final notifier = _Notifier(SshTerminalState(tabs: [first, second]));
      await _pump(tester, notifier);
      notifier.closeTab(-1);
      notifier.closeTab(2);
      expect(notifier.state.tabs, [first, second]);
      notifier.closeTab(1);
      await tester.pump();

      final chip = tester.widget<InputChip>(find.byType(InputChip));
      expect(chip.onDeleted, isNull);
      notifier.closeTab(0);
      expect(notifier.state.tabs, [first]);
      expect((first.bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      first.bridge.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'clear repaints immediately and clears scrollback only for the active tab',
    (tester) async {
      final tabs = [_tab('first'), _tab('second')];
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, activeTabIndex: 1),
      );
      await _pump(tester, notifier);
      tabs[0].terminal.write('keep first session output');
      final terminal = tabs[1].terminal;
      terminal.write(
        List.generate(100, (index) => 'old output $index\r\n').join(),
      );
      await tester.pump();
      expect(terminal.buffer.scrollBack, greaterThan(0));
      final sent = <String>[];
      terminal.onOutput = sent.add;
      var repaints = 0;
      void onChanged() => repaints++;
      terminal.addListener(onChanged);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();

      expect(repaints, 1);
      expect(terminal.buffer.getText().trim(), isEmpty);
      expect(terminal.buffer.scrollBack, 0);
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
      expect(
        tabs[0].terminal.buffer.getText(),
        contains('keep first session output'),
      );
      expect((tabs[1].bridge as _Bridge).disposed, isFalse);
      expect(notifier.state.activeTab, same(tabs[1]));
      expect(sent, isEmpty);
      terminal.write('output after clear');
      await tester.pump();
      expect(terminal.buffer.getText(), contains('output after clear'));
      expect(tester.takeException(), isNull);
      terminal.removeListener(onChanged);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'Android tabs expose independent, accessible close callbacks',
    (tester) async {
      final tabs = [_tab('first'), _tab('second')];
      final notifier = _Notifier(SshTerminalState(tabs: tabs));
      await _pump(tester, notifier);

      // Mobile reuses the same chip layout as Windows, so the close affordance
      // stays a real, labelled and per-index callback instead of a nested tap
      // target buried inside the label.
      final chips = tester.widgetList<InputChip>(find.byType(InputChip));
      expect(chips.length, 2);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final chip in chips) {
        expect(chip.onDeleted, isNotNull);
        expect(chip.deleteButtonTooltipMessage, l10n.terminalCloseTab);
      }
      // Closing one tab must not close the other.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(notifier.state.tabs, [tabs[1]]);

      final lastChip = tester.widget<InputChip>(find.byType(InputChip));
      expect(lastChip.onDeleted, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  // SSH 终端「显式键盘」需求回归：产出区点击不得弹输入法、不得产生任何
  // 远端字节；只有右下角固定键盘按钮才显式打开；显式关闭后点击也不再弹。
  // 焦点（硬件输入路径）与终端缓冲区断言都保留，未做任何弱化。
  testWidgets(
    'mobile SSH tap never shows the IME; the fixed keyboard button does and '
    'explicit close keeps it closed',
    (tester) async {
      final tab = _tab('ssh');
      final notifier = _Notifier(SshTerminalState(tabs: [tab]));
      tab.terminal.write('remote banner\r\n');
      await _pump(tester, notifier);

      final output = <String>[];
      tab.terminal.onOutput = output.add;
      await tester.pump();

      await tester.tap(find.byType(TerminalView));
      await tester.pump();
      await tester.pump();

      expect(
        _terminalState(tester).hasInputConnection,
        isFalse,
        reason: 'SSH 点击终端输出不得附加输入连接，否则移动端软键盘会弹出',
      );
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: '点击终端输出不得请求显示 IME',
      );
      expect(output, isEmpty, reason: '仅点击终端输出不得向远端 shell 发送任何字节');
      expect(
        FocusManager.instance.primaryFocus?.hasFocus,
        isTrue,
        reason: '点击仍应把焦点放到终端，硬件键盘路径必须保留',
      );
      expect(
        tab.terminal.buffer.getText(),
        contains('remote banner'),
        reason: '真实 SshTerminalView 仍在渲染同一个终端缓冲',
      );

      // 显式入口：右下角固定键盘按钮。
      final keyboardButton = find.byKey(
        const Key('terminal_accessory_keyboard_button'),
      );
      await tester.tap(keyboardButton);
      await tester.pump();
      await tester.pump();

      expect(
        _terminalState(tester).hasInputConnection,
        isTrue,
        reason: '固定的键盘按钮必须真正打开输入连接',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(output, isEmpty, reason: '打开键盘本身不得发送字节');

      // 显式关闭后，再次点击终端输出也必须保持关闭。
      _terminalState(tester).closeKeyboard();
      await tester.pump();
      await tester.pump();

      expect(_terminalState(tester).hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(find.byType(TerminalView));
      await tester.pump();
      await tester.pump();

      expect(
        _terminalState(tester).hasInputConnection,
        isFalse,
        reason: '关闭键盘后的被动点击不得重新弹出 IME',
      );
      expect(tester.testTextInput.isVisible, isFalse);
      expect(output, isEmpty);
      expect(
        FocusManager.instance.primaryFocus?.hasFocus,
        isTrue,
        reason: '关闭 IME 不得连带丢掉终端焦点',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tab.bridge.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  // 320dp / textScale 2：按键栏横向溢出时，键盘按钮必须留在滚动区之外、
  // 右下角、>=44dp，并且在拖动固定键后仍然可点（不被裁掉）。
  testWidgets(
    '320dp + textScale 2 keeps one keyboard button outside the pinned key '
    'scroll and reachable after a drag',
    (tester) async {
      const size = Size(320, 640);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tab = _tab('ssh');
      final notifier = _Notifier(SshTerminalState(tabs: [tab]));
      tab.terminal.write('remote banner\r\n');
      await _pumpNarrow(tester, notifier, size: size, textScale: 2);

      final keyboardButton = find.byKey(
        const Key('terminal_accessory_keyboard_button'),
      );

      expect(keyboardButton, findsOneWidget, reason: 'SSH 只能有一个键盘按钮，不得出现重复浮窗');
      expect(
        find.ancestor(
          of: keyboardButton,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
        reason: '键盘按钮必须在横向滚动区之外，否则窄屏下会被裁掉',
      );

      void expectPinnedAtLowerRight(Rect rect, String stage) {
        expect(
          rect.width,
          greaterThanOrEqualTo(44),
          reason: '$stage：键盘按钮命中目标必须 >=44dp',
        );
        expect(
          rect.height,
          greaterThanOrEqualTo(44),
          reason: '$stage：键盘按钮命中目标必须 >=44dp',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(size.width),
          reason: '$stage：按钮必须完整落在屏幕内（右侧）',
        );
        expect(
          rect.center.dx,
          greaterThan(size.width * 0.7),
          reason: '$stage：按钮应位于右下角',
        );
        expect(
          rect.bottom,
          greaterThan(size.height * 0.7),
          reason: '$stage：按钮应位于屏幕下方',
        );
      }

      expectPinnedAtLowerRight(tester.getRect(keyboardButton), '初始');

      final pinnedKey = find.byKey(const Key('terminal_accessory_key_ESC'));
      expect(pinnedKey, findsOneWidget);
      final pinnedScroller = find.ancestor(
        of: pinnedKey,
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        pinnedScroller,
        findsOneWidget,
        reason: '固定键必须位于唯一的横向滚动区内，拖动目标才能唯一确定',
      );
      final beforeLeft = tester.getRect(pinnedKey).left;
      await tester.drag(pinnedScroller, const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(pinnedKey).left,
        lessThan(beforeLeft - 50),
        reason: '前置条件：固定键行必须真的发生了横向滚动',
      );
      expect(
        find.ancestor(
          of: keyboardButton,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
        reason: '横向滚动不得把键盘按钮卷入滚动区',
      );
      expectPinnedAtLowerRight(tester.getRect(keyboardButton), '拖动后');

      // 拖动后按钮仍可点：点击必须真实打开输入连接（被遮挡则该断言失败）。
      await tester.tap(keyboardButton);
      await tester.pump();
      await tester.pump();

      expect(
        _terminalState(tester).hasInputConnection,
        isTrue,
        reason: '横向滚动后固定键盘按钮必须仍然可以点开输入连接',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tab.bridge.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  // 桌面 Windows：SSH 只退出了「点击即弹 IME」，聚焦与普通文本 / CJK /
  // 物理按键输入必须原样工作，且不得出现双重编码。
  testWidgets(
    'Windows SSH opt-out still focuses and accepts ordinary, CJK and physical '
    'input exactly once',
    (tester) async {
      final tab = _tab('ssh');
      final notifier = _Notifier(SshTerminalState(tabs: [tab]));
      tab.terminal.write('remote banner\r\n');
      await _pump(tester, notifier);

      final output = <String>[];
      tab.terminal.onOutput = output.add;
      await tester.pump();

      await tester.tap(find.byType(TerminalView));
      await tester.pump();
      await tester.pump();

      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull, reason: '点击必须让终端取得焦点');
      expect(focus!.hasFocus, isTrue, reason: '桌面端 SSH 点击仍应聚焦终端');
      expect(
        _terminalState(tester).hasInputConnection,
        isTrue,
        reason: '桌面端聚焦即附加输入连接，IME 语义与移动端不同',
      );

      tester.testTextInput.enterText('abc');
      await tester.pump();
      expect(output.join(), 'abc');

      output.clear();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'zhong',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      expect(output, isEmpty, reason: '组合中的拼音不得泄漏到终端');

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中文',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(output.join(), '中文');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(output.join(), '中文\r', reason: '物理按键必须照常发送，且不得与 IME 输入重复编码');

      // 点击终端后 xterm 的 doubleTapTimeout(300ms) 定时器仍在挂起：
      // 释放前先推进 400ms 让它自然触发，避免测试收尾报 pending timer。
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tab.bridge.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
