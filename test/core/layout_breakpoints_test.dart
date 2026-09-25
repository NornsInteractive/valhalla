import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/constants/layout_breakpoints.dart';
import 'package:valhalla/core/extensions/context_extensions.dart';
import 'package:valhalla/l10n/app_localizations.dart';

Widget _buildContextTestApp({
  required Size size,
  required Widget Function(BuildContext context) builder,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(builder: builder),
    ),
  );
}

void main() {
  group('LayoutBreakpoints 常量与语义阶梯定义', () {
    test('常量值符合 Material 3 与 Valhalla 响应式规范', () {
      expect(LayoutBreakpoints.compactMax, 600.0);
      expect(LayoutBreakpoints.expandedMin, 1024.0);
      expect(LayoutBreakpoints.topBarHostInfo, 900.0);
      expect(LayoutBreakpoints.dashboardMetricsGrid, 700.0);
      expect(LayoutBreakpoints.settingsThemeCardWide, 500.0);
    });

    test('断点严格递增无逻辑重叠', () {
      expect(
        LayoutBreakpoints.settingsThemeCardWide,
        lessThan(LayoutBreakpoints.compactMax),
      );
      expect(
        LayoutBreakpoints.compactMax,
        lessThan(LayoutBreakpoints.dashboardMetricsGrid),
      );
      expect(
        LayoutBreakpoints.dashboardMetricsGrid,
        lessThan(LayoutBreakpoints.topBarHostInfo),
      );
      expect(
        LayoutBreakpoints.topBarHostInfo,
        lessThan(LayoutBreakpoints.expandedMin),
      );
    });
  });

  group('ContextExtensions 响应式属性跨边界测试', () {
    testWidgets('isDesktop 在 1024 边界两侧断言', (tester) async {
      late bool at1024;
      late bool above1024;

      await tester.pumpWidget(
        _buildContextTestApp(
          size: const Size(1024.0, 800),
          builder: (ctx) {
            at1024 = ctx.isDesktop;
            return const SizedBox();
          },
        ),
      );
      expect(at1024, isFalse, reason: '1024px 应为中屏上限，不是桌面');

      await tester.pumpWidget(
        _buildContextTestApp(
          size: const Size(1025.0, 800),
          builder: (ctx) {
            above1024 = ctx.isDesktop;
            return const SizedBox();
          },
        ),
      );
      expect(above1024, isTrue, reason: '1025px 应为扩展桌面模式');
    });

    testWidgets('950px 冲突区间修掉后判定为非桌面但为中屏', (tester) async {
      late bool isDesktop;
      late bool isMediumOrWider;
      late bool isCompact;

      await tester.pumpWidget(
        _buildContextTestApp(
          size: const Size(950.0, 800),
          builder: (ctx) {
            isDesktop = ctx.isDesktop;
            isMediumOrWider = ctx.isMediumOrWider;
            isCompact = ctx.isCompact;
            return const SizedBox();
          },
        ),
      );

      // 旧逻辑下 >= 900 会误判为 isDesktop=true，现在与 shell 扩展桌面统一
      expect(isDesktop, isFalse);
      expect(isMediumOrWider, isTrue);
      expect(isCompact, isFalse);
    });

    testWidgets('600 紧凑边界两侧判定', (tester) async {
      late bool at599Compact;
      late bool at600Medium;

      await tester.pumpWidget(
        _buildContextTestApp(
          size: const Size(599.0, 800),
          builder: (ctx) {
            at599Compact = ctx.isCompact;
            return const SizedBox();
          },
        ),
      );
      expect(at599Compact, isTrue);

      await tester.pumpWidget(
        _buildContextTestApp(
          size: const Size(600.0, 800),
          builder: (ctx) {
            at600Medium = ctx.isMediumOrWider;
            return const SizedBox();
          },
        ),
      );
      expect(at600Medium, isTrue);
    });
  });
}
