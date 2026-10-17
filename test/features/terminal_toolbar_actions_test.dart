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
import '../support/seeded_terminal_notifier.dart';

class _Bridge extends TerminalSessionBridge {
  _Bridge() : super(terminal: Terminal(), serverName: 'test');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Notifier extends SeededTerminalNotifier {
  _Notifier(super.initial);

  void emit(SshTerminalState next) => state = next;
}

class _GeometryBridge extends _Bridge {
  TerminalSessionMode simulatedMode = TerminalSessionMode.tmux;

  @override
  TerminalSessionMode get mode => simulatedMode;

  @override
  TerminalConnectionState get state => stateListenable.value;
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
        ...terminalWorkspaceOverrides(),
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
        ...terminalWorkspaceOverrides(),
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

Future<void> _menuAction(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(const Key('terminal_more_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('terminal_${action}_menu_item')));
  await tester.pumpAndSettle();
}

Future<void> _closeTab(WidgetTester tester, String id) async {
  final tab = find.byKey(ValueKey('terminal_tab_$id'));
  await tester.ensureVisible(tab);
  await tester.longPress(tab);
  await tester.pumpAndSettle();
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.widgetWithText(ListTile, l10n.terminalCloseTab));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '360dp tabs show two short titles and reveal selected variable-width tab',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tabs = [
        _tab('a'),
        _tab('b'),
        ...List.generate(14, (i) => _tab('Long terminal $i')),
      ];
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, isInitialized: true),
      );
      await _pump(tester, notifier);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('terminal_tab_a')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('terminal_tab_b')).hitTestable(),
        findsOneWidget,
      );
      notifier.emit(notifier.state.copyWith(activeTabIndex: 11));
      await tester.pumpAndSettle();
      final selected = find.byKey(ValueKey('terminal_tab_${tabs[11].id}'));
      expect(selected.hitTestable(), findsOneWidget);
      final rect = tester.getRect(selected);
      expect(rect.left, greaterThanOrEqualTo(44));
      expect(rect.right, lessThanOrEqualTo(360 - 88));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'terminal recovery notices preserve canvas, PTY rows/columns, and scrollback',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _GeometryBridge();
      bridge.stateListenable.value = TerminalConnectionState.connected;
      final tab = TerminalTab(
        id: 'geometry',
        title: 'geometry',
        terminal: bridge.terminal,
        bridge: bridge,
      );
      final notifier = _Notifier(
        SshTerminalState(tabs: [tab], isInitialized: true),
      );
      await _pump(tester, notifier);
      tab.terminal.write(
        List.generate(250, (index) => 'history $index\r\n').join(),
      );
      await tester.pumpAndSettle();
      final terminalView = find.byType(TerminalView);
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(
              of: terminalView,
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(500));
      scroll.jumpTo(scroll.maxScrollExtent / 2);
      await tester.pump();
      final rect = tester.getRect(terminalView);
      final rows = tab.terminal.viewHeight;
      final columns = tab.terminal.viewWidth;
      final offset = scroll.pixels;
      final contents = tab.terminal.buffer.getText();

      void expectUnchanged(String phase) {
        expect(tester.getRect(terminalView), rect, reason: '$phase canvas');
        expect(tab.terminal.viewHeight, rows, reason: '$phase PTY rows');
        expect(tab.terminal.viewWidth, columns, reason: '$phase PTY columns');
        expect(scroll.pixels, offset, reason: '$phase scrollback');
        expect(
          tab.terminal.buffer.getText(),
          contents,
          reason: '$phase buffer',
        );
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull, reason: phase);
      }

      for (final phase in [
        TerminalConnectionState.disconnected,
        TerminalConnectionState.connecting,
        TerminalConnectionState.connected,
      ]) {
        bridge.stateListenable.value = phase;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expectUnchanged(phase.name);
      }
      expect(
        find.byKey(const Key('terminalTmuxSessionRestored')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byKey(const Key('terminalTmuxSessionRestored')),
        findsNothing,
      );
      expectUnchanged('restored notice dismissed');

      notifier.emit(
        notifier.state.copyWith(errorCode: 'TERMINAL_RESTORE_FAILED'),
      );
      await tester.pump();
      expect(find.byKey(const Key('terminalErrorBanner')), findsOneWidget);
      expectUnchanged('TERMINAL_RESTORE_FAILED');
      bridge.simulatedMode = TerminalSessionMode.plain;
      notifier.emit(
        notifier.state.copyWith(
          clearError: true,
          noticeCode: 'TERMINAL_PLAIN_INTERRUPTED',
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('terminalNoticeBanner')), findsOneWidget);
      expectUnchanged('TERMINAL_PLAIN_INTERRUPTED');
      notifier.emit(notifier.state.copyWith(clearNotice: true));
      await tester.pump();
      expectUnchanged('recovery notices cleared');
      await tester.pumpWidget(const SizedBox.shrink());
      bridge.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'terminal mode dialog preserves active output and does not reopen IME',
    (tester) async {
      final tab = _tab('active');
      final notifier = _Notifier(SshTerminalState(tabs: [tab]));
      await _pump(tester, notifier);
      tab.terminal.write('preserved-output');
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _menuAction(tester, 'tmux');
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await _menuAction(tester, 'tmux');
      await tester.tap(find.byKey(const Key('terminalModeTmuxRadio')));
      await tester.pumpAndSettle();
      expect(notifier.state.activeTab, same(tab));
      expect(tab.terminal.buffer.getText(), contains('preserved-output'));
      expect((tab.bridge as _Bridge).disposed, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tab.bridge.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'long-press close on the selected tab removes its session',
    (tester) async {
      final first = _tab('first');
      final second = _tab('second');
      final notifier = _Notifier(
        SshTerminalState(tabs: [first, second], activeTabIndex: 1),
      );
      await _pump(tester, notifier);

      await _closeTab(tester, 'second');

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
      await _closeTab(tester, 'first');

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
      await _closeTab(tester, 'second');

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
      await _closeTab(tester, 'third');

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

      await _menuAction(tester, 'clear');

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
    'Android compact tabs omit inline close and retain long-press close',
    (tester) async {
      final tabs = [_tab('first'), _tab('second')];
      final notifier = _Notifier(SshTerminalState(tabs: tabs));
      await _pump(tester, notifier);

      final chips = tester.widgetList<InputChip>(find.byType(InputChip));
      expect(chips.length, 2);
      for (final chip in chips) {
        expect(chip.onDeleted, isNull);
      }
      // Closing one tab must not close the other.
      await _closeTab(tester, 'first');
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
  // 贴在方向区左侧的固定列里、>=44dp，并且在拖动固定键后仍然可点（不被裁掉）。
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

      // 布局：固定键滚动区 | 更多/键盘同列 | 方向区贴屏幕右内边距。
      // 键盘按钮的锚点是方向区，而不是屏幕右侧 70% 处。
      void expectAccessoryColumnGeometry(Rect rect, String stage) {
        final directionPad = tester.getRect(
          find.byKey(const Key('terminal_direction_pad')),
        );
        final moreRect = tester.getRect(
          find.byKey(const Key('terminal_accessory_more_button')),
        );
        final scrollerRect = tester.getRect(pinnedScroller);

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
          rect.left,
          greaterThanOrEqualTo(0),
          reason: '$stage：按钮必须完整落在屏幕内（左侧）',
        );
        expect(
          rect.bottom,
          greaterThan(size.height * 0.7),
          reason: '$stage：按钮应位于屏幕下方',
        );
        expect(
          directionPad.right,
          lessThanOrEqualTo(size.width),
          reason: '$stage：方向区必须完整落在屏幕内',
        );
        expect(
          directionPad.right,
          greaterThanOrEqualTo(size.width - 16),
          reason: '$stage：方向区 right 必须贴近屏幕右内边距',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(directionPad.left + 0.5),
          reason: '$stage：键盘列必须位于方向区左侧',
        );
        expect(
          rect.right,
          greaterThanOrEqualTo(directionPad.left - 4),
          reason: '$stage：键盘 right 必须紧邻方向区 left（间隙 <= 4dp）',
        );
        expect(
          rect.left,
          greaterThanOrEqualTo(scrollerRect.right - 0.5),
          reason: '$stage：键盘列不得盖到固定键滚动区',
        );
        expect(
          moreRect.left,
          greaterThanOrEqualTo(scrollerRect.right - 0.5),
          reason: '$stage：更多键不得盖到固定键滚动区',
        );
        expect(
          moreRect.center.dx,
          closeTo(rect.center.dx, 0.5),
          reason: '$stage：更多与键盘必须同列',
        );
        expect(
          moreRect.left,
          greaterThanOrEqualTo(rect.left - 0.5),
          reason: '$stage：更多键必须落在键盘列内',
        );
        expect(
          moreRect.right,
          lessThanOrEqualTo(rect.right + 0.5),
          reason: '$stage：更多键必须落在键盘列内',
        );
        expect(
          moreRect.bottom,
          lessThanOrEqualTo(rect.top + 0.5),
          reason: '$stage：更多键必须在键盘键正上方',
        );
      }

      final initialKeyboardRect = tester.getRect(keyboardButton);
      expectAccessoryColumnGeometry(initialKeyboardRect, '初始');

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
      expectAccessoryColumnGeometry(tester.getRect(keyboardButton), '拖动后');
      expect(
        tester.getRect(keyboardButton),
        initialKeyboardRect,
        reason: '横向滚动不得移动滚动区之外的键盘列',
      );

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
