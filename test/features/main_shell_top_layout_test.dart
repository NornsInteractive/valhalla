import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/servers/server_form_dialog.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/core/design/motion_widgets.dart';

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier([this._server]);

  @override
  ServerProfile? build() => _server;
}

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier([this._servers = const []]);

  @override
  List<ServerProfile> build() => _servers;
}

class _TestSettingsNotifier extends SettingsNotifier {
  final List<AppThemeMode> setThemeModeCalls = [];
  final List<AppAccentColor> setAccentColorCalls = [];
  final List<AppSection>? _bottomSections;

  _TestSettingsNotifier({List<AppSection>? bottomSections})
    : _bottomSections = bottomSections;

  @override
  SettingsState build() {
    final s = super.build();
    if (_bottomSections != null) {
      return s.copyWith(bottomNavigationSections: _bottomSections);
    }
    return s;
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    setThemeModeCalls.add(mode);
    return super.setThemeMode(mode);
  }

  @override
  Future<void> setAccentColor(AppAccentColor color) async {
    setAccentColorCalls.add(color);
    return super.setAccentColor(color);
  }

  final List<({AppThemeMode mode, Color color})> setThemeAccentColorCalls = [];

  @override
  Future<void> setThemeAccentColor(AppThemeMode mode, Color color) async {
    setThemeAccentColorCalls.add((mode: mode, color: color));
    return super.setThemeAccentColor(mode, color);
  }
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(500, 900),
  List<ServerProfile> servers = const [],
  ServerProfile? activeServer,
  _TestSettingsNotifier? settingsNotifier,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      serverListProvider.overrideWith(() => _TestServerListNotifier(servers)),
      activeServerProvider.overrideWith(
        () => _TestActiveServerNotifier(activeServer),
      ),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
      if (settingsNotifier != null)
        settingsProvider.overrideWith(() => settingsNotifier),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Group 1: 移除右上角添加服务器按钮', () {
    testWidgets('紧凑模式 AppBar 右上角不再有添加按钮', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final addIconInAppBar = find.descendant(
        of: appBarFinder,
        matching: find.byIcon(Icons.add),
      );
      expect(addIconInAppBar, findsNothing);
    });

    testWidgets('宽屏模式 TopBar 右上角不再有添加按钮', (tester) async {
      await _pumpShell(tester, size: const Size(1200, 800));

      // 宽屏下没有 AppBar，顶部为 _buildTopBar
      expect(find.byType(AppBar), findsNothing);

      final addIconButton = find.byWidgetPredicate(
        (w) => w is IconButton && (w.icon as Icon?)?.icon == Icons.add,
      );
      expect(addIconButton, findsNothing);
    });
  });

  group('Group 2: 左上角菜单按钮与抽屉内容', () {
    testWidgets('紧凑模式左上角菜单按钮点击后展开抽屉，内含 4 个功能入口与添加服务器', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      // 抽屉未展开
      expect(find.byType(Drawer), findsNothing);

      // 点击左上角菜单按钮
      final menuBtn = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.menu),
      );
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // 抽屉展开
      final drawerFinder = find.byType(Drawer);
      expect(drawerFinder, findsOneWidget);

      // 验证 4 个功能入口图标存在于抽屉中
      expect(
        find.descendant(
          of: drawerFinder,
          matching: find.byIcon(Icons.folder_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawerFinder,
          matching: find.byIcon(Icons.memory_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawerFinder,
          matching: find.byIcon(Icons.bolt_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawerFinder,
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
      );

      // 验证抽屉底部的添加服务器入口
      expect(
        find.descendant(
          of: drawerFinder,
          matching: find.byIcon(Icons.add_circle_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('宽屏模式 TopBar 左侧菜单按钮点击同样能展开抽屉', (tester) async {
      await _pumpShell(tester, size: const Size(1200, 800));

      final menuBtn = find.byIcon(Icons.menu);
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsOneWidget);
    });
  });

  group('Group 3: 抽屉 4 个功能入口跳转', () {
    Future<void> openDrawer(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
    }

    testWidgets('从抽屉点击文件入口切换到 index 3 且关闭抽屉', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      await openDrawer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.folder_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack),
      );
      expect(stack.index, 3);
    });

    testWidgets('从抽屉点击系统入口切换到 index 5 且关闭抽屉', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      await openDrawer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.memory_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack),
      );
      expect(stack.index, 5);
    });

    testWidgets('从抽屉点击快捷指令入口切换到 index 6 且关闭抽屉', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      await openDrawer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.bolt_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack),
      );
      expect(stack.index, 6);
    });

    testWidgets('从抽屉点击设置入口切换到 index 7 且关闭抽屉', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      await openDrawer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Drawer), findsNothing);
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack).first,
      );
      expect(stack.index, 7);
    });
  });

  group('Group 4: 底部 NavigationBar 目的地与索引边界防护', () {
    testWidgets('底栏恰好 4 个目的地且不包含 more_horiz', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      final navBar = tester.widget<MainBottomNavigationBar>(
        find.byType(MainBottomNavigationBar),
      );
      expect(navBar.sections, hasLength(4));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('切到抽屉子页面 3/5/6/7 时 pump 不抛 RangeError 且底栏索引回落合法', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(580, 1000),
        settingsNotifier: _TestSettingsNotifier(
          bottomSections: const [
            AppSection.dashboard,
            AppSection.aiChat,
            AppSection.terminal,
            AppSection.docker,
          ],
        ),
      );

      // 先切换底栏到 Terminal (index 2)
      await tester.tap(find.byIcon(Icons.terminal_outlined));
      await tester.pumpAndSettle();

      var navBar = tester.widget<MainBottomNavigationBar>(
        find.byType(MainBottomNavigationBar),
      );
      expect(navBar.currentIndex, 2);

      final indicesToTest = [
        (Icons.folder_outlined, 3),
        (Icons.memory_outlined, 5),
        (Icons.bolt_outlined, 6),
        (Icons.settings_outlined, 7),
      ];

      for (final (icon, expectedStackIndex) in indicesToTest) {
        // 打开抽屉并切换
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(of: find.byType(Drawer), matching: find.byIcon(icon)),
        );
        await tester.pumpAndSettle();

        // 绝不抛异常
        expect(tester.takeException(), isNull);

        // IndexedStack 对应子页面
        final stack = tester.widget<AnimatedIndexedStack>(
          find.byType(AnimatedIndexedStack).first,
        );
        expect(stack.index, expectedStackIndex);

        navBar = tester.widget<MainBottomNavigationBar>(
          find.byType(MainBottomNavigationBar),
        );
        expect(navBar.currentIndex, expectedStackIndex);
      }
    });
  });

  group('Group 5: 添加服务器入口双入口可达', () {
    testWidgets('切换服务器弹窗头部添加按钮能唤起添加服务器对话框', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      // 点击紧凑 AppBar 里的服务器选择器 InkWell
      final selectorInkWell = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_drop_down),
      );
      expect(selectorInkWell, findsOneWidget);
      await tester.tap(selectorInkWell);
      await tester.pumpAndSettle();

      // 弹窗展开后，头部包含 Icons.add_circle_outline
      final headerAddBtn = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            (w.icon as Icon?)?.icon == Icons.add_circle_outline,
      );
      expect(headerAddBtn, findsOneWidget);

      await tester.tap(headerAddBtn);
      await tester.pumpAndSettle();

      // 验证弹出 ServerFormDialog
      expect(find.byType(ServerFormDialog), findsOneWidget);
    });

    testWidgets('抽屉内添加服务器入口能唤起添加服务器对话框', (tester) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      // 打开抽屉
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();

      // 点击抽屉底部的添加服务器入口
      final drawerAddTile = find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.add_circle_outline),
      );
      expect(drawerAddTile, findsOneWidget);

      await tester.tap(drawerAddTile);
      await tester.pumpAndSettle();

      // 抽屉关闭并弹出 ServerFormDialog
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(ServerFormDialog), findsOneWidget);
    });
  });

  group('Group 6: 顶栏不再提供主题快捷切换', () {
    Future<void> expectNoTopThemeShortcut(
      WidgetTester tester, {
      required Size size,
    }) async {
      await _pumpShell(tester, size: size);

      // AppBar 内（紧凑布局）不得出现主题快捷按钮
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.palette_outlined),
        ),
        findsNothing,
      );
      // 全局顶栏（含中屏/宽屏 _buildTopBar）同样不得出现主题快捷按钮
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
    }

    testWidgets('紧凑模式 AppBar 不含主题快捷按钮', (tester) async {
      await expectNoTopThemeShortcut(tester, size: const Size(580, 1000));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('中屏模式顶栏不含主题快捷按钮', (tester) async {
      await expectNoTopThemeShortcut(tester, size: const Size(800, 600));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('宽屏模式顶栏不含主题快捷按钮', (tester) async {
      await expectNoTopThemeShortcut(tester, size: const Size(1200, 800));
      expect(find.byType(AppBar), findsNothing);
    });
  });
}
