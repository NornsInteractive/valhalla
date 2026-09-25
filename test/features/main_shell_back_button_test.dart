import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

/// 只关心路径的假 notifier：不碰 SFTP，`navigateUp()` 按真实算法算父目录。
class _FakeSftpNotifier extends SftpNotifier {
  _FakeSftpNotifier(this._initialPath);

  final String _initialPath;

  /// 记录 `navigateUp()` 被调用了几次，用于确认返回键真的触发了回上级。
  int navigateUpCalls = 0;

  @override
  SftpState build() => SftpState(currentPath: _initialPath, isLoading: false);

  @override
  Future<void> navigateUp() async {
    navigateUpCalls++;
    if (state.isAtRoot) return;
    final lastSlash = state.currentPath.lastIndexOf('/');
    final parent = lastSlash <= 0
        ? '/'
        : state.currentPath.substring(0, lastSlash);
    state = state.copyWith(currentPath: parent);
  }
}

class _NoActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required String sftpPath,
}) async {
  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  final notifier = _FakeSftpNotifier(sftpPath);
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      activeServerProvider.overrideWith(_NoActiveServerNotifier.new),
      sftpProvider.overrideWith(() => notifier),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// 切到文件 tab：桌面宽度下点导航栏里的「文件」目的地。
Future<void> _selectFilesTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.folder_outlined).first);
  await tester.pumpAndSettle();
}

/// `PopScope` 是泛型，`find.byType` 必须给到精确的类型实参，否则匹配不到
/// （`PopScope` / `PopScope<Object?>` 都会返回 0 个）。这里按 predicate 找，
/// 再用 dynamic 读 canPop，绕开类型实参。
Finder _popScopeFinder() => find.byWidgetPredicate((w) => w is PopScope);

bool _canPop(WidgetTester tester) {
  final widgets = _popScopeFinder().evaluate().toList();
  expect(widgets, hasLength(1), reason: 'MainShell 上应恰好有一个 PopScope');
  return (widgets.single.widget as dynamic).canPop as bool;
}

void main() {
  group('MainShell 系统返回键', () {
    testWidgets('文件 tab 且不在根目录：返回键回到上一级，不退出', (tester) async {
      final container = await _pumpShell(tester, sftpPath: '/etc/nginx');
      await _selectFilesTab(tester);

      // 非根目录时必须拦住根路由弹出。
      expect(_canPop(tester), isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(sftpProvider).currentPath,
        '/etc',
        reason: '返回键必须回退一级目录',
      );
    });

    testWidgets('文件 tab 已在根目录：返回键放行（退出 app）', (tester) async {
      final container = await _pumpShell(tester, sftpPath: '/');
      await _selectFilesTab(tester);

      // 根目录没有可回退的层级，必须放行让 app 正常退出。
      expect(_canPop(tester), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(sftpProvider).currentPath,
        '/',
        reason: '在根目录按返回不该改动路径',
      );
    });

    testWidgets('非文件 tab：返回键放行（退出 app），不碰 SFTP 路径', (tester) async {
      // 默认停在 index 0（Dashboard），不切到文件 tab。
      final container = await _pumpShell(tester, sftpPath: '/etc/nginx');

      expect(_canPop(tester), isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(sftpProvider).currentPath,
        '/etc/nginx',
        reason: '不在文件 tab 时返回键不应回退目录',
      );
    });
  });
}
