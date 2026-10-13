import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_toolbar.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Directionality(textDirection: direction, child: child),
      ),
    );

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('short path stays adjacent to root under $direction', (
      tester,
    ) async {
      String? navigated;
      await tester.pumpWidget(
        _host(
          RemoteBrowserBreadcrumb(
            path: '/home/valhalla',
            onNavigate: (path) => navigated = path,
          ),
          direction: direction,
        ),
      );
      await tester.pumpAndSettle();
      final root = find.byKey(const Key('remote_browser_breadcrumb_root'));
      final home = find.byKey(const Key('remote_browser_breadcrumb_seg_0'));
      final rootRect = tester.getRect(root);
      final homeRect = tester.getRect(home);
      expect(homeRect.left - rootRect.right, inInclusiveRange(0, 15));
      expect(rootRect.height, greaterThanOrEqualTo(44));
      expect(homeRect.height, greaterThanOrEqualTo(44));
      await tester.tap(root);
      expect(navigated, '/');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long paths reveal their tail initially and after navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final path = ValueNotifier('/first/second/third/fourth/fifth/last');
    addTearDown(path.dispose);
    await tester.pumpWidget(
      _host(
        ValueListenableBuilder(
          valueListenable: path,
          builder: (context, value, child) =>
              RemoteBrowserBreadcrumb(path: value, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('last').hitTestable(), findsOneWidget);
    final root = find.byKey(const Key('remote_browser_breadcrumb_root'));
    final originalRootLeft = tester.getRect(root).left;
    path.value = '${path.value}/another/folder/newest';
    await tester.pumpAndSettle();
    expect(find.text('newest').hitTestable(), findsOneWidget);
    expect(tester.getRect(root).left, originalRootLeft);
    expect(root.hitTestable(), findsOneWidget);
    path.value = '/home/valhalla';
    await tester.pumpAndSettle();
    final home = find.byKey(const Key('remote_browser_breadcrumb_seg_0'));
    expect(
      tester.getRect(home).left - tester.getRect(root).right,
      inInclusiveRange(0, 15),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'external controller is retained and is not disposed by breadcrumb',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          RemoteBrowserBreadcrumb(
            path: '/home/valhalla',
            scrollController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.hasClients, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => controller.addListener(() {}), returnsNormally);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact toolbar action row stays start aligned below search', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      _host(
        RemoteBrowserToolbar(
          searchController: search,
          onSearchChanged: (_) {},
          showHidden: false,
          onToggleHidden: () {},
          sortField: 'name',
          sortAscending: true,
          onSort: (_, _) {},
          isGrid: false,
          onToggleView: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final actions = tester.getRect(
      find.byKey(const Key('remote_browser_hidden')),
    );
    final field = tester.getRect(
      find.byKey(const Key('remote_browser_search')),
    );
    expect(actions.left, lessThanOrEqualTo(12));
    expect(actions.top, greaterThanOrEqualTo(field.bottom));
    expect(tester.takeException(), isNull);
  });
}
