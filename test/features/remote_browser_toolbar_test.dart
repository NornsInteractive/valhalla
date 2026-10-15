import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/remote_file_toolbar_action.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_toolbar.dart';

Widget _host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: textScale == 1
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
  home: Scaffold(
    body: Directionality(textDirection: direction, child: child),
  ),
);

RemoteBrowserToolbar _managementToolbar({
  required TextEditingController search,
  VoidCallback? onUpload,
  VoidCallback? onNewFile,
  VoidCallback? onNewFolder,
  VoidCallback? onSelectMode,
  VoidCallback? onBookmarks,
  VoidCallback? onRefresh,
  Widget? transferAction,
}) => RemoteBrowserToolbar(
  searchController: search,
  onSearchChanged: (_) {},
  showHidden: false,
  onToggleHidden: () {},
  sortField: 'name',
  sortAscending: true,
  onSort: (_, _) {},
  isGrid: false,
  onToggleView: () {},
  onUpload: onUpload,
  onNewFile: onNewFile,
  onNewFolder: onNewFolder,
  onSelectMode: onSelectMode,
  onBookmarks: onBookmarks,
  onRefresh: onRefresh,
  transferAction: transferAction,
);

const _transfer = SizedBox(key: Key('remote_browser_transfer'), width: 48);

RemoteBrowserToolbar _configuredToolbar(
  TextEditingController search,
  List<String> calls, {
  Iterable<RemoteFileToolbarAction> pinned = defaultRemoteFileToolbarActions,
  bool enabled = true,
  bool isPicker = false,
}) => RemoteBrowserToolbar(
  searchController: search,
  onSearchChanged: (_) {},
  showHidden: false,
  onToggleHidden: enabled ? () => calls.add('hidden') : null,
  sortField: 'name',
  sortAscending: true,
  onSort: (field, ascending) => calls.add('sort:$field:$ascending'),
  isGrid: false,
  onToggleView: enabled ? () => calls.add('view') : null,
  onUpload: enabled ? () => calls.add('upload') : null,
  onNewFile: enabled ? () => calls.add('file') : null,
  onNewFolder: enabled ? () => calls.add('folder') : null,
  onSelectMode: enabled ? () => calls.add('select_mode') : null,
  onBookmarks: enabled ? () => calls.add('bookmarks') : null,
  onRefresh: enabled ? () => calls.add('refresh') : null,
  onTransfers: enabled ? () => calls.add('transfers') : null,
  onConfigureToolbar: () => calls.add('configure_toolbar'),
  pinnedActions: pinned,
  isPicker: isPicker,
);

Finder _menuValue(String value) => find.byWidgetPredicate(
  (widget) => widget is PopupMenuItem<String> && widget.value == value,
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('configurable management toolbar', () {
    testWidgets(
      'closing More never restores mobile search keyboard',
      (tester) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        await tester.pumpWidget(
          _host(_configuredToolbar(search, [], pinned: const [])),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('remote_browser_search'));
        await tester.tap(field);
        await tester.pumpAndSettle();
        final focus = tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .focusNode;
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.byKey(const Key('remote_browser_more')));
        await tester.pumpAndSettle();
        final popup = tester.element(_menuValue('upload'));
        Navigator.of(popup).pop();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    for (final pinned in [
      <RemoteFileToolbarAction>[],
      defaultRemoteFileToolbarActions,
      RemoteFileToolbarAction.values,
    ]) {
      for (final locale in [const Locale('de'), const Locale('ar')]) {
        testWidgets(
          '${pinned.length} pinned at 320dp 2x $locale keeps More reachable',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final search = TextEditingController();
            addTearDown(search.dispose);
            final calls = <String>[];
            await tester.pumpWidget(
              _host(
                _configuredToolbar(search, calls, pinned: pinned),
                locale: locale,
                textScale: 2,
                direction: locale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            );
            await tester.pumpAndSettle();
            final more = find.byKey(const Key('remote_browser_more'));
            expect(more.hitTestable(), findsOneWidget);
            if (pinned.isEmpty) {
              expect(
                find.byKey(const Key('remote_browser_upload')),
                findsNothing,
              );
            }
            await tester.tap(more);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (pinned.length == 9) {
              expect(find.byType(PopupMenuItem<String>), findsOneWidget);
            }
            await _tapVisible(tester, _menuValue('configure_toolbar'));
            expect(calls, ['configure_toolbar']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    const actionKeys = {
      'upload': 'upload',
      'folder': 'new',
      'file': 'new',
      'view': 'view',
      'transfers': 'transfers',
      'hidden': 'hidden',
      'size': 'sort',
      'desc': 'sort',
      'select_mode': 'select',
      'bookmarks': 'bookmarks',
      'refresh': 'refresh',
    };
    for (final pinned in [false, true]) {
      for (final entry in actionKeys.entries) {
        testWidgets('${entry.key} uses same callback when pinned=$pinned', (
          tester,
        ) async {
          final search = TextEditingController();
          addTearDown(search.dispose);
          final calls = <String>[];
          await tester.pumpWidget(
            _host(
              _configuredToolbar(
                search,
                calls,
                pinned: pinned ? RemoteFileToolbarAction.values : const [],
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (pinned) {
            await _tapVisible(
              tester,
              find.byKey(Key('remote_browser_${entry.value}')),
            );
            if (entry.value == 'new' || entry.value == 'sort') {
              await _tapVisible(tester, _menuValue(entry.key));
            }
          } else {
            await tester.tap(find.byKey(const Key('remote_browser_more')));
            await tester.pumpAndSettle();
            await _tapVisible(tester, _menuValue(entry.key));
          }
          final expected = switch (entry.key) {
            'size' => 'sort:size:true',
            'desc' => 'sort:name:false',
            _ => entry.key,
          };
          expect(calls, [expected]);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('unavailable actions remain disabled pinned=$pinned', (
        tester,
      ) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        final calls = <String>[];
        await tester.pumpWidget(
          _host(
            _configuredToolbar(
              search,
              calls,
              enabled: false,
              pinned: pinned ? RemoteFileToolbarAction.values : const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!pinned) {
          await tester.tap(find.byKey(const Key('remote_browser_more')));
          await tester.pumpAndSettle();
        }
        for (final key in [
          'upload',
          'new',
          'view',
          'transfers',
          'hidden',
          'select',
          'bookmarks',
          'refresh',
        ]) {
          final widget = tester.widget(find.byKey(Key('remote_browser_$key')));
          if (widget is IconButton) {
            expect(widget.onPressed, isNull, reason: key);
          } else if (widget is PopupMenuButton<String>) {
            expect(widget.enabled, isFalse, reason: key);
          } else {
            expect(
              (widget as PopupMenuItem<String>).enabled,
              isFalse,
              reason: key,
            );
          }
        }
        expect(calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
      testWidgets('picker ignores management pinning pinned=$pinned', (
        tester,
      ) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        await tester.pumpWidget(
          _host(
            _configuredToolbar(
              search,
              [],
              isPicker: true,
              pinned: pinned ? RemoteFileToolbarAction.values : const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'upload',
          'new',
          'transfers',
          'select',
          'bookmarks',
          'refresh',
          'more',
          'configure_toolbar',
        ]) {
          expect(find.byKey(Key('remote_browser_$key')), findsNothing);
        }
        expect(find.byKey(const Key('remote_browser_hidden')), findsOneWidget);
        expect(find.byKey(const Key('remote_browser_view')), findsOneWidget);
        expect(find.byIcon(Icons.sort), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
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
        _managementToolbar(
          search: search,
          onUpload: () {},
          onNewFile: () {},
          onNewFolder: () {},
          transferAction: _transfer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final actions = tester.getRect(
      find.byKey(const Key('remote_browser_upload')),
    );
    final field = tester.getRect(
      find.byKey(const Key('remote_browser_search')),
    );
    expect(actions.left, lessThanOrEqualTo(12));
    expect(actions.top, greaterThanOrEqualTo(field.bottom));
    await tester.tap(find.byKey(const Key('remote_browser_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote_browser_hidden')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management mode keeps upload new view transfer more in order', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      _host(
        _managementToolbar(
          search: search,
          onUpload: () {},
          onNewFile: () {},
          onNewFolder: () {},
          onSelectMode: () {},
          onBookmarks: () {},
          onRefresh: () {},
          transferAction: _transfer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final upload = find.byKey(const Key('remote_browser_upload'));
    final create = find.byKey(const Key('remote_browser_new'));
    final view = find.byKey(const Key('remote_browser_view'));
    final transfer = find.byKey(const Key('remote_browser_transfer'));
    final more = find.byKey(const Key('remote_browser_more'));
    expect(upload, findsOneWidget);
    expect(create, findsOneWidget);
    expect(view, findsOneWidget);
    expect(transfer, findsOneWidget);
    expect(more, findsOneWidget);
    final uploadLeft = tester.getRect(upload).left;
    final newLeft = tester.getRect(create).left;
    final viewLeft = tester.getRect(view).left;
    final transferLeft = tester.getRect(transfer).left;
    final moreLeft = tester.getRect(more).left;
    expect(uploadLeft, lessThan(newLeft));
    expect(newLeft, lessThan(viewLeft));
    expect(viewLeft, lessThan(transferLeft));
    expect(transferLeft, lessThan(moreLeft));
    expect(tester.takeException(), isNull);
  });

  testWidgets('null callbacks keep upload and new visible but disabled', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(
      _host(
        _managementToolbar(
          search: search,
          onUpload: null,
          onNewFile: null,
          onNewFolder: null,
          transferAction: _transfer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final uploadFinder = find.byKey(const Key('remote_browser_upload'));
    final newFinder = find.byKey(const Key('remote_browser_new'));
    expect(uploadFinder, findsOneWidget);
    expect(newFinder, findsOneWidget);
    final upload = tester.widget<IconButton>(uploadFinder);
    expect(upload.onPressed, isNull);
    final create = tester.widget<PopupMenuButton<String>>(newFinder);
    expect(create.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector mode does not expose management actions', (
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
          isPicker: true,
          onUpload: () {},
          onNewFile: () {},
          onNewFolder: () {},
          transferAction: _transfer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remote_browser_upload')), findsNothing);
    expect(find.byKey(const Key('remote_browser_new')), findsNothing);
    expect(find.byKey(const Key('remote_browser_more')), findsNothing);
    expect(find.byKey(const Key('remote_browser_transfer')), findsNothing);
    expect(find.byKey(const Key('remote_browser_hidden')), findsOneWidget);
    expect(find.byKey(const Key('remote_browser_view')), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow long path collapses middle and parent selection restores path',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? navigated;
      await tester.pumpWidget(
        _host(
          RemoteBrowserBreadcrumb(
            path: '/first/second/third/fourth/fifth/last',
            onNavigate: (path) => navigated = path,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final collapsed = find.byKey(
        const Key('remote_browser_breadcrumb_collapsed'),
      );
      expect(collapsed, findsOneWidget);
      expect(
        find.byKey(const Key('remote_browser_breadcrumb_seg_0')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('remote_browser_breadcrumb_seg_5')),
        findsOneWidget,
      );
      await tester.tap(collapsed);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('remote_browser_breadcrumb_seg_2')),
      );
      await tester.pumpAndSettle();
      expect(navigated, '/first/second/third');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320dp with 2x German text has no overflow in more and path menus',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = TextEditingController();
      addTearDown(search.dispose);
      await tester.pumpWidget(
        _host(
          _managementToolbar(
            search: search,
            onUpload: () {},
            onNewFile: () {},
            onNewFolder: () {},
            onSelectMode: () {},
            onBookmarks: () {},
            onRefresh: () {},
            transferAction: _transfer,
          ),
          locale: const Locale('de'),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remote_browser_more')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(
          RemoteBrowserBreadcrumb(
            path: '/erster/zweiter/dritter/vierter/fuenfster/letzter',
            onNavigate: (_) {},
          ),
          locale: const Locale('de'),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('remote_browser_breadcrumb_collapsed')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
