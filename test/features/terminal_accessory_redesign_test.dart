import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';

/// 足够长的自定义固定键列表，保证 320dp 宽下也必须横滚。
const _longPinned = <String>[
  'ARROWS',
  'ESC',
  'TAB',
  'CTRL',
  'SHIFT',
  'ALT',
  'PASTE',
  'F1',
  'F2',
  'F3',
  'F4',
  'F5',
  'F6',
  'F7',
  'F8',
  'F9',
  'F10',
  'F11',
  'F12',
  'HOME',
  'END',
  'PGUP',
  'PGDN',
  'INSERT',
  'DELETE',
  'BACKSPACE',
  'ENTER',
  'FN',
];

/// 直接指定 TerminalSettings 的本地替身：几何用例不碰存储，也不依赖 SSH。
class _FixedSettingsNotifier extends TerminalSettingsNotifier {
  _FixedSettingsNotifier(this.initial);

  final TerminalSettings initial;

  @override
  TerminalSettings build() => initial;
}

TerminalSettings _settings({
  List<String> pinnedKeys = TerminalSettings.defaultPinnedKeys,
  TerminalDirectionPadMode mode = TerminalDirectionPadMode.fixed,
  int? color,
}) => TerminalSettings(
  fontSize: 13,
  pinnedKeys: pinnedKeys,
  directionPadMode: mode,
  directionKeySeedColorValue: color,
);

Future<void> _pumpBar(
  WidgetTester tester, {
  required TerminalSettings settings,
  double width = 360,
  double textScale = 1.0,
  TextDirection textDirection = TextDirection.ltr,
  ThemeData? theme,
  List<String>? sentKeys,
  bool enableTickers = true,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        terminalSettingsProvider.overrideWith(
          () => _FixedSettingsNotifier(settings),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 640),
            textScaler: TextScaler.linear(textScale),
          ),
          child: TickerMode(
            enabled: enableTickers,
            child: Directionality(
              textDirection: textDirection,
              child: Scaffold(
                body: Column(
                  children: [
                    const Spacer(),
                    TerminalAccessoryBar(
                      onKey:
                          (
                            keyLabel, {
                            isCtrl = false,
                            isAlt = false,
                            isShift = false,
                          }) {
                            sentKeys?.add(keyLabel);
                          },
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String label) => find.byKey(Key('terminal_accessory_key_$label'));

/// 从触控槽往下找第一个 40×40 的盒子，即槽内 2dp 内缩的键面。
Rect? _findFace(WidgetTester tester, Finder slot) {
  final slotBox = tester.renderObject(slot) as RenderBox;
  Rect? face;
  void walk(Element element) {
    if (face != null) return;
    final renderObject = element.renderObject;
    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      final rect =
          renderObject.localToGlobal(Offset.zero, ancestor: slotBox) &
          renderObject.size;
      if (rect.size == const Size(40, 40)) face = rect;
    }
    element.visitChildren(walk);
  }

  walk(tester.element(slot));
  return face;
}

/// 读箭头触控槽内唯一带色 Material 的键面色（生产用它表达常态/按下）。
Color _arrowFaceColor(WidgetTester tester, String label) {
  final colored = tester
      .widgetList<Material>(
        find.descendant(of: _key(label), matching: find.byType(Material)),
      )
      .where((m) => m.color != null)
      .toList();
  expect(colored, hasLength(1), reason: '$label 键面必须有且只有一个带色 Material');
  return colored.single.color!;
}

Color _expectedArrowBg(ThemeData theme, {int? seed}) {
  if (seed != null) {
    return ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: theme.brightness,
    ).secondaryContainer;
  }
  return theme.colorScheme.secondaryContainer.withValues(alpha: 0.7);
}

Color _expectedArrowActiveBg(ThemeData theme, {int? seed}) {
  if (seed != null) {
    return ColorScheme.fromSeed(
      seedColor: Color(seed),
      brightness: theme.brightness,
    ).primary;
  }
  return theme.colorScheme.primary;
}

void main() {
  setUpAll(() async {
    // Ahem 假字体把每个字符画成等宽方块，会把 SHIFT 撑出 44dp 列宽。
    // 布局回归必须在生产 JetBrains Mono 下断言，而不是压小 UI。
    final mono = FontLoader('JetBrains Mono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-700.ttf'));
    await mono.load();
  });

  group('底栏高度与方向区尺寸', () {
    testWidgets('320/360/390dp 正常字号：底栏 88，方向区 132×88', (tester) async {
      for (final width in [320.0, 360.0, 390.0]) {
        await _pumpBar(tester, settings: _settings(), width: width);

        expect(tester.takeException(), isNull, reason: '${width}px 不得有布局异常');
        expect(find.byType(TerminalAccessoryBar), findsOneWidget);
        expect(
          tester.getSize(find.byType(TerminalAccessoryBar)).height,
          88,
          reason: '${width}px 底栏必须 88dp',
        );
        final pad = find.byKey(const Key('terminal_direction_pad'));
        expect(pad, findsOneWidget, reason: '${width}px 必须渲染方向区');
        expect(
          tester.getSize(pad),
          const Size(132, 88),
          reason: '${width}px 方向区必须 132×88',
        );
      }
    });

    testWidgets('44dp 独立箭头槽构成倒T，相邻触控中心距 44', (tester) async {
      await _pumpBar(tester, settings: _settings());

      final padFinder = find.byKey(const Key('terminal_direction_pad'));
      final groupFinder = find.byKey(
        const Key('terminal_accessory_key_ARROWS'),
      );
      expect(groupFinder, findsOneWidget, reason: '组合键组缺失');
      expect(
        find.ancestor(of: padFinder, matching: groupFinder),
        findsOneWidget,
        reason: '方向区必须挂在 ARROWS 组合键组内',
      );

      final pad = tester.getRect(padFinder);
      const cells = <String, Offset>{
        '↑': Offset(44, 0),
        '←': Offset(0, 44),
        '↓': Offset(44, 44),
        '→': Offset(88, 44),
      };
      final centers = <String, Offset>{};
      for (final cell in cells.entries) {
        final slot = _key(cell.key);
        expect(slot, findsOneWidget, reason: '${cell.key} 触控槽缺失');
        expect(
          tester.getSize(slot),
          const Size(44, 44),
          reason: '${cell.key} 必须是 44dp 触控槽',
        );
        expect(
          tester.getTopLeft(slot),
          pad.topLeft + cell.value,
          reason: '${cell.key} 必须落在倒T对应格内',
        );
        centers[cell.key] = tester.getCenter(slot);
      }

      expect(
        (centers['↑']! - centers['↓']!).distance,
        closeTo(44, 0.01),
        reason: '上下相邻触控中心距 44',
      );
      expect(
        (centers['←']! - centers['↓']!).distance,
        closeTo(44, 0.01),
        reason: '左中相邻触控中心距 44',
      );
      expect(
        (centers['↓']! - centers['→']!).distance,
        closeTo(44, 0.01),
        reason: '中右相邻触控中心距 44',
      );
    });

    testWidgets('44dp 触控槽内是 40dp 键面，槽内 2dp 内缩', (tester) async {
      await _pumpBar(tester, settings: _settings());

      final slot = _key('↑');
      expect(slot, findsOneWidget);
      expect(tester.getSize(slot), const Size(44, 44));

      final face = _findFace(tester, slot);
      expect(face, isNotNull, reason: '44dp 触控槽内必须有 40dp 键面');
      expect(face!.topLeft, const Offset(2, 2), reason: '键面必须在槽内 2dp 内缩');
    });
  });

  group('方向区三态布局', () {
    testWidgets('fixed：长列表横滚后方向区坐标不变且最右，更多/键盘列在其左', (tester) async {
      await _pumpBar(
        tester,
        settings: _settings(pinnedKeys: _longPinned),
        width: 360,
      );

      final pad = find.byKey(const Key('terminal_direction_pad'));
      final scroll = find.byType(SingleChildScrollView);
      final more = find.byKey(const Key('terminal_accessory_more_button'));
      final keyboard = find.byKey(
        const Key('terminal_accessory_keyboard_button'),
      );
      final esc = find.byKey(const Key('terminal_accessory_key_ESC'));
      expect(pad, findsOneWidget);
      expect(scroll, findsOneWidget);
      expect(more, findsOneWidget);
      expect(keyboard, findsOneWidget);
      expect(esc, findsOneWidget);

      final padBefore = tester.getRect(pad);
      final moreBefore = tester.getRect(more);
      final keyboardBefore = tester.getRect(keyboard);
      final escBefore = tester.getRect(esc);

      await tester.drag(scroll, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '横滚不得抛布局异常');
      expect(
        tester.getRect(esc).left,
        lessThan(escBefore.left),
        reason: '常用键必须真的滚出去，否则坐标不变是空断言',
      );
      expect(tester.getRect(pad), padBefore, reason: '固定模式下横滚时方向区坐标必须不变');
      expect(tester.getRect(more), moreBefore, reason: '更多按钮必须固定');
      expect(tester.getRect(keyboard), keyboardBefore, reason: '键盘按钮必须固定');

      final bar = tester.getRect(find.byType(TerminalAccessoryBar));
      final padRect = tester.getRect(pad);
      final scrollRect = tester.getRect(scroll);
      final moreRect = tester.getRect(more);
      final keyboardRect = tester.getRect(keyboard);

      expect(
        bar.right - padRect.right,
        lessThanOrEqualTo(8),
        reason: '方向区必须贴在底栏最右端 | pad=$padRect bar=$bar',
      );
      expect(
        moreRect.right,
        lessThanOrEqualTo(padRect.left),
        reason: '更多列在方向区左侧',
      );
      expect(
        keyboardRect.right,
        lessThanOrEqualTo(padRect.left),
        reason: '键盘列在方向区左侧',
      );
      expect(
        moreRect.center.dx,
        closeTo(keyboardRect.center.dx, 0.01),
        reason: '更多/键盘必须同一列',
      );
      expect(
        scrollRect.right,
        lessThanOrEqualTo(padRect.left),
        reason: '滚动区不得盖到方向区',
      );
    });

    testWidgets('flow：随常用键一起滚动，不固定', (tester) async {
      await _pumpBar(
        tester,
        settings: _settings(
          pinnedKeys: _longPinned,
          mode: TerminalDirectionPadMode.flow,
        ),
        width: 360,
      );

      final pad = find.byKey(const Key('terminal_direction_pad'));
      final scroll = find.byType(SingleChildScrollView);
      expect(pad, findsOneWidget, reason: 'flow 仍要渲染方向区');
      expect(
        find.ancestor(of: pad, matching: scroll),
        findsOneWidget,
        reason: 'flow 必须在滚动区内（按原 ARROWS 位置）',
      );

      final before = tester.getRect(pad);
      await tester.drag(scroll, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(pad).left,
        lessThan(before.left),
        reason: 'flow 必须跟着滚动，不得固定',
      );
    });

    testWidgets('hidden：不渲染驻留组合区，更多/Nav 与键盘仍可用', (tester) async {
      await _pumpBar(
        tester,
        settings: _settings(
          pinnedKeys: _longPinned,
          mode: TerminalDirectionPadMode.hidden,
        ),
        width: 360,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('terminal_direction_pad')),
        findsNothing,
        reason: 'hidden 不得渲染驻留方向区',
      );
      expect(
        find.byKey(const Key('terminal_accessory_key_ARROWS')),
        findsNothing,
        reason: 'hidden 不得渲染 ARROWS 组合键',
      );
      expect(
        find.byKey(const Key('terminal_accessory_key_ESC')),
        findsOneWidget,
        reason: 'hidden 只藏方向区，常用键照常显示',
      );
      expect(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
        findsOneWidget,
      );

      final more = find.byKey(const Key('terminal_accessory_more_button'));
      expect(more, findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(ChoiceChip, 'Nav'),
        findsOneWidget,
        reason: 'hidden 下仍要能从更多面板进入 Nav',
      );
    });
  });

  group('大字号与 RTL', () {
    testWidgets('2x 字号不溢出，方向区与更多/键盘列齐全', (tester) async {
      await _pumpBar(tester, settings: _settings(), textScale: 2.0);

      expect(tester.takeException(), isNull, reason: '2x 字号不得溢出');
      expect(find.byKey(const Key('terminal_direction_pad')), findsOneWidget);
      expect(_key('↑'), findsOneWidget);
      expect(
        find.byKey(const Key('terminal_accessory_more_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
        findsOneWidget,
      );
    });

    testWidgets('RTL 不溢出，方向区与更多/键盘列齐全', (tester) async {
      await _pumpBar(
        tester,
        settings: _settings(pinnedKeys: _longPinned),
        textDirection: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull, reason: 'RTL 不得溢出');
      expect(find.byKey(const Key('terminal_direction_pad')), findsOneWidget);
      expect(_key('↑'), findsOneWidget);
      expect(
        find.byKey(const Key('terminal_accessory_more_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
        findsOneWidget,
      );
    });
  });

  group('精确回归：常用键视口 / 方向键颜色与连发 / 生命周期 / TickerMode', () {
    testWidgets('320dp 正常字号：6 常用键都真正在 scroll viewport 内，ESC/CTRL/ALT 中心距 44', (
      tester,
    ) async {
      await _pumpBar(tester, settings: _settings(), width: 320);

      expect(tester.takeException(), isNull, reason: '320dp 不得有布局异常');
      final scroll = find.byType(SingleChildScrollView);
      expect(scroll, findsOneWidget);
      final scrollBox = tester.renderObject(scroll) as RenderBox;
      final viewport = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;

      const common = <String>['ESC', 'TAB', 'CTRL', 'SHIFT', 'ALT', 'PASTE'];
      for (final label in common) {
        final finder = _key(label);
        expect(finder, findsOneWidget, reason: '$label 必须渲染');
        final box = tester.renderObject(finder) as RenderBox;
        expect(
          box.attached && box.hasSize,
          isTrue,
          reason: '$label 需有真实 RenderBox',
        );
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(
          viewport.contains(rect.topLeft) &&
              viewport.contains(rect.topRight) &&
              viewport.contains(rect.bottomLeft) &&
              viewport.contains(rect.bottomRight),
          isTrue,
          reason:
              '$label 必须完整落在 scroll viewport 内 rect=$rect viewport=$viewport',
        );
      }

      final esc = tester.getCenter(_key('ESC'));
      final ctrl = tester.getCenter(_key('CTRL'));
      final alt = tester.getCenter(_key('ALT'));
      expect(
        (esc - ctrl).distance,
        closeTo(44, 0.05),
        reason: 'ESC/CTRL 中心距必须 44（真实 RenderBox）',
      );
      expect(
        (ctrl - alt).distance,
        closeTo(44, 0.05),
        reason: 'CTRL/ALT 中心距必须 44（真实 RenderBox）',
      );
      expect(esc.dy, closeTo(ctrl.dy, 0.05), reason: 'ESC/CTRL 同行');
      expect(ctrl.dy, closeTo(alt.dy, 0.05), reason: 'CTRL/ALT 同行');
    });

    testWidgets('浅/深色与自定义 seed：常态/按下/连发/取消颜色正确，初始一次+长按重复，取消后不再发', (
      tester,
    ) async {
      const seed = 0xFF6750A4;

      Future<void> pumpCase({
        required Brightness brightness,
        required int? seedColor,
      }) async {
        final sentKeys = <String>[];
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await _pumpBar(
          tester,
          settings: _settings(color: seedColor),
          theme: ThemeData(brightness: brightness),
          sentKeys: sentKeys,
        );
        expect(tester.takeException(), isNull);

        final theme = Theme.of(tester.element(_key('↑')));
        final expectedIdle = _expectedArrowBg(theme, seed: seedColor);
        final expectedActive = _expectedArrowActiveBg(theme, seed: seedColor);

        expect(
          _arrowFaceColor(tester, '↑'),
          expectedIdle,
          reason: '常态键面色（$brightness seed=$seedColor）',
        );

        final center = tester.getCenter(_key('↑'));
        final gesture = await tester.startGesture(center);
        expect(sentKeys, <String>['↑'], reason: 'pointer down 只发一次初始');
        await tester.pump();
        expect(_arrowFaceColor(tester, '↑'), expectedActive, reason: '按下键面色');

        await tester.pump(const Duration(milliseconds: 450));
        expect(sentKeys.length, greaterThan(1), reason: '长按必须连发');
        expect(sentKeys.every((k) => k == '↑'), isTrue);
        expect(
          _arrowFaceColor(tester, '↑'),
          expectedActive,
          reason: '连发期间保持按下色',
        );

        await gesture.cancel();
        await tester.pump();
        expect(_arrowFaceColor(tester, '↑'), expectedIdle, reason: '取消后颜色复原');
        final cancelledCount = sentKeys.length;
        await tester.pump(const Duration(milliseconds: 450));
        expect(sentKeys.length, cancelledCount, reason: '取消后不得再发');
      }

      await pumpCase(brightness: Brightness.light, seedColor: null);
      await pumpCase(brightness: Brightness.dark, seedColor: null);
      await pumpCase(brightness: Brightness.light, seedColor: seed);
      await pumpCase(brightness: Brightness.dark, seedColor: seed);
    });

    testWidgets('按住↑后 inactive 立刻 resumed：不推进计时器，pump450 不能续发且颜色复原', (
      tester,
    ) async {
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      final sentKeys = <String>[];
      await _pumpBar(tester, settings: _settings(), sentKeys: sentKeys);

      final theme = Theme.of(tester.element(_key('↑')));
      final expectedIdle = _expectedArrowBg(theme);
      final expectedActive = _expectedArrowActiveBg(theme);

      final gesture = await tester.startGesture(tester.getCenter(_key('↑')));
      await tester.pump();
      expect(sentKeys, <String>['↑']);
      expect(_arrowFaceColor(tester, '↑'), expectedActive);

      await tester.pump(const Duration(milliseconds: 450));
      final heldCount = sentKeys.length;
      expect(heldCount, greaterThan(1), reason: '连发应已发生');
      expect(_arrowFaceColor(tester, '↑'), expectedActive);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump();
      expect(sentKeys.length, heldCount, reason: 'inactive 立刻取消，不得再发');
      expect(
        _arrowFaceColor(tester, '↑'),
        expectedIdle,
        reason: 'inactive 后颜色复原',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(sentKeys.length, heldCount, reason: 'resumed 后不能沿用已取消的连发计时器续发');
      expect(_arrowFaceColor(tester, '↑'), expectedIdle);

      await gesture.up();
      await tester.pump();
      expect(sentKeys.length, heldCount);
    });

    testWidgets('TickerMode 隐藏再恢复：同一 HoldRepeatKey State 不卸载，停止且不续发', (
      tester,
    ) async {
      final sentKeys = <String>[];
      await _pumpBar(
        tester,
        settings: _settings(),
        sentKeys: sentKeys,
        enableTickers: true,
      );

      final holdFinder = find.descendant(
        of: _key('↑'),
        matching: find.byType(HoldRepeatKey),
      );
      expect(holdFinder, findsOneWidget);
      final stateBefore = tester.state<State>(holdFinder);
      final elementBefore = tester.element(holdFinder);

      final gesture = await tester.startGesture(tester.getCenter(_key('↑')));
      await tester.pump(const Duration(milliseconds: 450));
      final heldCount = sentKeys.length;
      expect(heldCount, greaterThan(1), reason: '先确认连发在跑');

      // 关闭 Ticker：不卸载，只在 build 里 cancel。
      await _pumpBar(
        tester,
        settings: _settings(),
        sentKeys: sentKeys,
        enableTickers: false,
      );
      expect(tester.takeException(), isNull);
      expect(holdFinder, findsOneWidget, reason: '不得卸载 HoldRepeatKey');
      final stateAfterHide = tester.state<State>(holdFinder);
      expect(
        identical(stateBefore, stateAfterHide),
        isTrue,
        reason: 'TickerMode 隐藏不得重建 State',
      );
      expect(
        identical(elementBefore, tester.element(holdFinder)),
        isTrue,
        reason: '同一 Element',
      );

      final hiddenCount = sentKeys.length;
      expect(hiddenCount, heldCount, reason: '隐藏即刻停止发送');
      await tester.pump(const Duration(milliseconds: 450));
      expect(sentKeys.length, hiddenCount, reason: '隐藏期间不得续发');

      // 恢复后仍是同一 State，也不会续上旧计时器。
      await _pumpBar(
        tester,
        settings: _settings(),
        sentKeys: sentKeys,
        enableTickers: true,
      );
      expect(
        identical(stateBefore, tester.state<State>(holdFinder)),
        isTrue,
        reason: '恢复后仍是同一 HoldRepeatKey State',
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(sentKeys.length, hiddenCount, reason: '恢复后不得续发旧连发');

      await gesture.up();
      await tester.pump();
      expect(sentKeys.length, hiddenCount);
    });

    testWidgets('第二指在同一箭头上松开不打断第一指', (tester) async {
      final sentKeys = <String>[];
      await _pumpBar(tester, settings: _settings(), sentKeys: sentKeys);

      final center = tester.getCenter(_key('↑'));
      final first = await tester.startGesture(center);
      await tester.pump();
      expect(sentKeys, <String>['↑']);

      final second = await tester.startGesture(center);
      await tester.pump();
      await second.up();
      await tester.pump(const Duration(milliseconds: 450));
      expect(sentKeys.length, greaterThan(1), reason: '第二指松开不得打断第一指的连发');
      expect(sentKeys.every((k) => k == '↑'), isTrue);

      await first.up();
      await tester.pump();
      final finalCount = sentKeys.length;
      await tester.pump(const Duration(milliseconds: 450));
      expect(sentKeys.length, finalCount, reason: '第一指松开后才停止');
    });
  });
}
