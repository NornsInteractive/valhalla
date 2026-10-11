import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/design/motion_widgets.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

/// Bounded reproduction of the reported bug:
/// "SSH terminal scroll often jumps to top when switching pages and back".
///
/// These tests intentionally run against the CURRENT baseline (no fixes).
/// They pin down which transitions lose the scroll position:
///   1. AnimatedIndexedStack offstage page switching (incl. output while hidden)
///   2. Swapping the `terminal` instance of one shared SharedTerminalCanvas
///      element (multiple terminal tabs) and coming back
///   3. Viewport height change (keyboard show/hide) and restore
///   4. Bottom-follow vs intentional scrollback semantics
///
/// All assertions read the live `ScrollableState.position` that the xterm
/// `TerminalView` owns internally, so the numbers are the real pixels the
/// user sees.

/// 固定字号 notifier：与 test/features/shared_terminal_canvas_test.dart 中
/// `_FixedFontSizeNotifier` 相同的替身，避免 SharedTerminalCanvas 读存储。
class _FixedFontSizeNotifier extends TerminalSettingsNotifier {
  final int size;

  _FixedFontSizeNotifier(this.size);

  @override
  TerminalSettings build() => TerminalSettings(useTmux: false, fontSize: size);
}

Terminal _terminalWithLines(int lineCount) {
  final terminal = Terminal(maxLines: 1500);
  final buffer = StringBuffer();
  for (var i = 0; i < lineCount; i++) {
    buffer.writeln(
      'history line $i ..................................................',
    );
  }
  terminal.write(buffer.toString());
  return terminal;
}

class _TerminalHost extends StatefulWidget {
  const _TerminalHost({required this.initialTerminal});

  final Terminal initialTerminal;

  @override
  State<_TerminalHost> createState() => _TerminalHostState();
}

class _TerminalHostState extends State<_TerminalHost> {
  late Terminal terminal = widget.initialTerminal;

  /// AnimatedIndexedStack 的当前页。0 = 终端页，1 = 其他页（模拟"切走再切回"）。
  int page = 0;

  /// 终端可视区高度。600→400→600 模拟软键盘顶起与收起导致的视口变化。
  double viewportHeight = 600;

  void swapTerminal(Terminal next) {
    setState(() => terminal = next);
  }

  void showPage(int index) {
    setState(() => page = index);
  }

  void resizeViewport(double height) {
    setState(() => viewportHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        terminalSettingsProvider.overrideWith(() => _FixedFontSizeNotifier(13)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              height: viewportHeight,
              child: AnimatedIndexedStack(
                index: page,
                children: [
                  // 关键：不给 SharedTerminalCanvas key，切 terminal 实例时
                  // 复用同一个 Element / TerminalViewState（与 SSH 终端多标签
                  // 页共用画布的现状一致）。
                  SharedTerminalCanvas(
                    terminal: terminal,
                    onKey: (_, {isCtrl = false, isAlt = false}) {},
                    onPaste: () async {},
                  ),
                  const ColoredBox(
                    color: Colors.blueGrey,
                    child: Center(child: Text('other page')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// xterm TerminalView 内部的 ScrollableState——用户看到的滚动像素就在这里。
ScrollableState _scrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(TerminalView, skipOffstage: false),
      matching: find.byType(Scrollable, skipOffstage: false),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) => _scrollable(tester).position;

bool _atBottom(ScrollPosition position) =>
    (position.pixels - position.maxScrollExtent).abs() < 0.5;

void main() {
  group('SSH terminal scroll retention — baseline reproduction', () {
    testWidgets(
      'bottom follow survives AnimatedIndexedStack page changes, including output while hidden',
      (tester) async {
        final terminal = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminal));
        await tester.pumpAndSettle();

        // 新终端默认贴底，输出到达时跟随（_stickToBottom 初始为 true）。
        expect(_atBottom(_position(tester)), isTrue);

        terminal.write('more output on the visible page\r\n');
        await tester.pump();
        expect(_atBottom(_position(tester)), isTrue);

        final host = tester.state<_TerminalHostState>(
          find.byType(_TerminalHost),
        );

        // 切到其他页（终端页进入 Offstage，但 Element 保留）。
        host.showPage(1);
        await tester.pumpAndSettle();
        // 页面隐藏期间继续有输出（后台 PTY 输出）。Offstage 页仍保留 Element，
        // 所以必须用 skipOffstage: false 才能找到隐藏中的 TerminalView。
        expect(find.byType(TerminalView, skipOffstage: false), findsOneWidget);

        // 页面隐藏期间继续有输出（后台 PTY 输出）。
        terminal.write('output while page is offstage\r\n');
        for (var i = 0; i < 30; i++) {
          terminal.write('buffered offstage line $i\r\n');
        }
        await tester.pump();

        // 切回终端页。
        host.showPage(0);
        await tester.pumpAndSettle();

        // 期望：仍然贴底跟随。
        expect(
          _atBottom(_position(tester)),
          isTrue,
          reason: '切页回来后应当继续贴底，而不是跳到顶部或脱离底部',
        );
      },
    );

    testWidgets(
      'intentional history position survives AnimatedIndexedStack page changes',
      (tester) async {
        final terminal = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminal));
        await tester.pumpAndSettle();

        final position = _position(tester);
        expect(position.maxScrollExtent, greaterThan(0));

        // 用户主动往上翻看历史：通过真实的 ScrollPosition 跳到一个中间位置，
        // 这条路径与手势拖动一样会触发 RenderTerminal._onScroll → 清空
        // _stickToBottom（退出"跟随底部"模式）。
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pump();
        final historyPixels = position.pixels;
        expect(historyPixels, lessThan(position.maxScrollExtent));

        final host = tester.state<_TerminalHostState>(
          find.byType(_TerminalHost),
        );
        host.showPage(1);
        await tester.pumpAndSettle();

        // 隐藏期间的新输出不得惊动历史阅读位置。
        for (var i = 0; i < 20; i++) {
          terminal.write('offstage output $i\r\n');
        }
        await tester.pump();

        host.showPage(0);
        await tester.pumpAndSettle();

        expect(
          position.pixels,
          equals(historyPixels),
          reason: '回退到指定历史位置不得被重置为 0（顶部）或最大伸展（底部）',
        );
      },
    );

    testWidgets(
      'swapping populated Terminal A -> short Terminal B -> A on the same canvas element loses A position',
      (tester) async {
        final terminalA = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminalA));
        await tester.pumpAndSettle();

        final position = _position(tester);
        final maxA = position.maxScrollExtent;
        expect(maxA, greaterThan(0));

        // 在 A 中读到历史中段（模拟用户在多标签页间来回切换前的阅读位置）。
        position.jumpTo(maxA / 2);
        await tester.pump();
        final historyA = position.pixels;
        expect(historyA, lessThan(maxA));

        final host = tester.state<_TerminalHostState>(
          find.byType(_TerminalHost),
        );

        // 切到内容很少的标签页 B（新终端/新会话，缓冲区远短于一屏）。
        final terminalB = _terminalWithLines(2);
        host.swapTerminal(terminalB);
        await tester.pump();
        final pixelsOnB = position.pixels;
        final maxOnB = position.maxScrollExtent;

        // 切回 A。
        host.swapTerminal(terminalA);
        await tester.pump();

        // 期望：A 的历史位置（historyA）被保留。
        expect(
          position.pixels,
          equals(historyA),
          reason:
              '从 A 切到 B 再切回 A，A 的滚动位置必须保留；'
              '实际 B 上 pixels=$pixelsOnB max=$maxOnB，'
              '回到 A 后 pixels=${position.pixels}（historyA=$historyA, maxA=$maxA）',
        );
      },
    );

    testWidgets(
      'swapping A -> B -> A at the bottom restores bottom follow, not top',
      (tester) async {
        final terminalA = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminalA));
        await tester.pumpAndSettle();

        expect(_atBottom(_position(tester)), isTrue);

        final host = tester.state<_TerminalHostState>(
          find.byType(_TerminalHost),
        );

        host.swapTerminal(_terminalWithLines(2));
        await tester.pump();
        host.swapTerminal(terminalA);
        await tester.pump();

        expect(
          _atBottom(_position(tester)),
          isTrue,
          reason: '原本贴底的标签页切回来必须仍然贴底跟随新输出',
        );
      },
    );

    testWidgets(
      'viewport height change (keyboard) keeps history position and bottom follow',
      (tester) async {
        final terminal = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminal));
        await tester.pumpAndSettle();

        final host = tester.state<_TerminalHostState>(
          find.byType(_TerminalHost),
        );
        final position = _position(tester);
        final viewHeightTall = terminal.viewHeight;

        // 读到历史中段。
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pump();
        final historyPixels = position.pixels;

        // 软键盘顶起：可视区变矮。
        host.resizeViewport(400);
        await tester.pump();
        final viewHeightShort = terminal.viewHeight;
        // 渲染层必须把新的视口高度（行数）通知给 Terminal，否则 PTY 尺寸漂移。
        expect(viewHeightShort, lessThan(viewHeightTall));

        // 键盘收起。
        host.resizeViewport(600);
        await tester.pump();
        expect(terminal.viewHeight, viewHeightTall);

        expect(
          position.pixels,
          equals(historyPixels),
          reason: '键盘顶起再收起，历史阅读位置必须原样恢复',
        );

        // 贴底场景：键盘顶起期间新输出仍应跟随底部。
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        host.resizeViewport(400);
        await tester.pump();
        terminal.write('output while keyboard is up\r\n');
        await tester.pump();
        expect(_atBottom(position), isTrue);
        host.resizeViewport(600);
        await tester.pump();
        expect(_atBottom(position), isTrue);
      },
    );

    testWidgets(
      'render layout dimensions report the viewport the terminal resized to',
      (tester) async {
        final terminal = _terminalWithLines(120);
        await tester.pumpWidget(_TerminalHost(initialTerminal: terminal));
        await tester.pumpAndSettle();

        // autoResize 打开时，RenderTerminal 会把像素视口换算成单元格数并
        // terminal.resize()，viewWidth/viewHeight 必须与外部 SizedBox 一致地
        // 为正数，否则 maxScrollExtent 的计算基准都是错的。
        expect(terminal.viewWidth, greaterThan(0));
        expect(terminal.viewHeight, greaterThan(0));
        // 120 行历史 vs 一屏 ~十余行：必须存在滚动空间。
        expect(_position(tester).maxScrollExtent, greaterThan(0));
      },
    );
  });
}
