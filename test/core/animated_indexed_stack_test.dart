import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/design/motion_widgets.dart';

/// 回归: 切页时子页 Element 不得重建 —— 重建会导致页面状态丢失,
/// 且页面内 Entrance/骨架屏重放, 表现为切标签"闪烁一下"。
class _CounterPage extends StatefulWidget {
  const _CounterPage({super.key, required this.label});

  final String label;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    _builds++;
    return Center(child: Text('${widget.label}:$_builds'));
  }
}

void main() {
  testWidgets('AnimatedIndexedStack preserves page state across switches', (
    tester,
  ) async {
    late StateSetter setOuter;
    int index = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return MaterialApp(
            home: Scaffold(
              body: AnimatedIndexedStack(
                index: index,
                children: const [
                  _CounterPage(key: ValueKey('a'), label: 'A'),
                  _CounterPage(key: ValueKey('b'), label: 'B'),
                  _CounterPage(key: ValueKey('c'), label: 'C'),
                ],
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // 子页实例在 State 里完全不变, 常驻链下永远不会重挂载,
    // 因此 build 计数应恒为 1 (旧实现切一次就重置为 1 次新挂载)。
    expect(_buildsOf(tester, 'A'), 1);
    expect(_buildsOf(tester, 'C'), 1);

    setOuter(() => index = 1);
    await tester.pumpAndSettle();
    setOuter(() => index = 2);
    await tester.pumpAndSettle();
    setOuter(() => index = 0);
    await tester.pumpAndSettle();

    expect(_buildsOf(tester, 'A'), 1, reason: 'A 回来时不得重新挂载');
    expect(_buildsOf(tester, 'B'), 1, reason: 'B 在后台保持挂载');
    expect(_buildsOf(tester, 'C'), 1, reason: 'C 在后台保持挂载');
  });

  testWidgets('transition keeps both pages mounted mid-flight', (
    tester,
  ) async {
    late StateSetter setOuter;
    int index = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return MaterialApp(
            home: Scaffold(
              body: AnimatedIndexedStack(
                index: index,
                children: const [
                  _CounterPage(key: ValueKey('a'), label: 'A'),
                  _CounterPage(key: ValueKey('b'), label: 'B'),
                ],
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    setOuter(() => index = 1);
    // 转场中途: A、B 都在树中 (交叉淡入淡出)。
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('A:'), findsOneWidget);
    expect(find.textContaining('B:'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('A:'), findsNothing);
  });
}

int _buildsOf(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.textContaining('$label:', skipOffstage: false),
  );
  final parts = (text.data ?? '').split(':');
  return int.parse(parts.last);
}
