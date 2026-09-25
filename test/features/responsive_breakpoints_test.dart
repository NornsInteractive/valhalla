import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

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

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required Size size,
  ServerProfile? activeServer,
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
      serverListProvider.overrideWith(
        () => _TestServerListNotifier(
          activeServer != null ? [activeServer] : const [],
        ),
      ),
      activeServerProvider.overrideWith(
        () => _TestActiveServerNotifier(activeServer),
      ),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
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
  const testServer = ServerProfile(
    id: 'test-server-1',
    name: 'ProductionAlpha',
    host: '192.168.1.100',
    username: 'root',
    port: 22,
  );

  group('MainShell 响应式断点跨边界测试', () {
    testWidgets('599px 与 600px 边界：移动端底栏 vs 中屏 Rail', (tester) async {
      // 599px: 紧凑移动端，显示 MainBottomNavigationBar
      await _pumpShell(tester, size: const Size(599, 900));
      expect(find.byType(MainBottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('600px: 中屏 Rail 模式生效，底栏消失', (tester) async {
      await _pumpShell(tester, size: const Size(600, 900));
      expect(find.byType(MainBottomNavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      // 中屏下不展示桌面专用的 Inspector 切换按钮
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('1024px 与 1025px 边界：中屏 Rail vs 扩展桌面（Inspector 开关）', (
      tester,
    ) async {
      // 1024px: 中屏上限，仍无 Inspector
      await _pumpShell(tester, size: const Size(1024, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });

    testWidgets('1025px: 扩展桌面模式激活，Inspector 开关可见', (tester) async {
      await _pumpShell(tester, size: const Size(1025, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('900px 与 901px 边界：顶栏 host:port 详情芯片', (tester) async {
      // 900px: 顶栏不展示 host:port 芯片（'host:port (status)' 格式）
      await _pumpShell(
        tester,
        size: const Size(900, 900),
        activeServer: testServer,
      );
      expect(find.textContaining('192.168.1.100:22 ('), findsNothing);
    });

    testWidgets('901px: 顶栏展示 host:port 详情芯片', (tester) async {
      await _pumpShell(
        tester,
        size: const Size(901, 900),
        activeServer: testServer,
      );
      expect(find.textContaining('192.168.1.100:22 ('), findsOneWidget);
    });
  });

  group('950px 冲突区间解决验证：AiChatView 侧栏与 Shell 表现统一', () {
    testWidgets('950px 宽度下 AiChatView 判定为非桌面，侧栏收进抽屉而非占用 320px', (tester) async {
      await _pumpShell(tester, size: const Size(950, 900));

      // 切换至 Chat tab (index 1)
      final railDestinations = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.smart_toy_outlined),
      );
      expect(railDestinations, findsOneWidget);
      await tester.tap(railDestinations);
      await tester.pumpAndSettle();

      // 在 950px 下，AiChatView 中的 isDesktop 为 false
      // 检查 AiChatView 内部的会话侧栏宽度 320px SizedBox 不存在于树上
      final chatSidebar = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 320,
      );
      expect(chatSidebar, findsNothing);

      // 内部 Scaffold 的抽屉可用
      final chatViewFinder = find.byType(AiChatView);
      expect(chatViewFinder, findsOneWidget);
      final chatScaffold = tester.widget<Scaffold>(
        find.descendant(of: chatViewFinder, matching: find.byType(Scaffold)),
      );
      expect(chatScaffold.drawer, isNotNull);
    });

    testWidgets('1200px 桌面大屏下 AiChatView 展示常驻 320px 会话侧栏', (tester) async {
      await _pumpShell(tester, size: const Size(1200, 900));

      // 切换至 Chat tab (index 1)
      final railDestinations = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.smart_toy_outlined),
      );
      expect(railDestinations, findsOneWidget);
      await tester.tap(railDestinations);
      await tester.pumpAndSettle();

      // 桌面宽度下，320px 常驻侧栏出现
      final chatSidebar = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 320,
      );
      expect(chatSidebar, findsOneWidget);

      final chatViewFinder = find.byType(AiChatView);
      final chatScaffold = tester.widget<Scaffold>(
        find.descendant(of: chatViewFinder, matching: find.byType(Scaffold)),
      );
      expect(chatScaffold.drawer, isNull);
    });
  });
}
