import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeKeepAliveService implements KeepAliveService {
  final bool openTransfers;
  _FakeKeepAliveService({this.openTransfers = false});

  @override
  Future<bool> consumeOpenTransfersAction() async => openTransfers;

  @override
  Future<bool> start(int sessionCount) async => true;

  @override
  Future<void> updateSessionCount(int sessionCount) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {}
}

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

/// Standalone SFTP surface 直接 watch [fileBookmarksProvider]，后者依赖已选中的
/// 服务器与已初始化的 `LocalStorageService`。固定成一台已连接的服务器，
/// 保证测试环境与真实 connected srv-1 状态一致（不发起真实 SSH）。
const _kConnectedServer = ServerProfile(
  id: 'srv-1',
  name: 'Test Server',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
  authType: AuthType.password,
);

/// The shell and the SFTP surface read the connection state; the real
/// connection notifier builds the SSH client manager, which needs a live
/// `LocalStorageService`. These cases exercise the real transfer panel, so the
/// connection is up.
class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _TestServerListNotifier extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [];
}

class _TestValueNotifier extends ValueNotifier<int> {
  _TestValueNotifier(super.value);

  void forceNotify() => notifyListeners();
}

/// SharedPreferences 只初始化一次；后续 `_buildSftpApp` 同步复用该实例。
late final LocalStorageService _storage;

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  bool openTransfers = false,
  Size size = const Size(500, 900),
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
      serverListProvider.overrideWith(() => _TestServerListNotifier()),
      activeServerProvider.overrideWith(() => _TestActiveServerNotifier()),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
      keepAliveServiceProvider.overrideWithValue(
        _FakeKeepAliveService(openTransfers: openTransfers),
      ),
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

Widget _buildSftpApp({ValueListenable<int>? openTransfersRequest}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      activeServerProvider.overrideWith(
        () => _TestActiveServerNotifier(_kConnectedServer),
      ),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SftpFileView(openTransfersRequest: openTransfersRequest),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.init();
  });

  group('openTransfersRequest 链路测试', () {
    testWidgets('1. openTransfers: true 时通过 MainShell 自动切到文件页并弹出传输列表', (
      tester,
    ) async {
      await _pumpShell(tester, openTransfers: true);

      // 验证传输面板已弹出（空队列显示 transferEmptyView）
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);

      // 验证关闭按钮可正常关闭面板
      await tester.tap(find.byKey(const Key('transferSheetCloseButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);
    });

    testWidgets('2. openTransfers: false 时通过 MainShell 不弹出传输面板（对照组）', (
      tester,
    ) async {
      await _pumpShell(tester, openTransfers: false);

      expect(find.byKey(const Key('transferEmptyView')), findsNothing);
      expect(find.byKey(const Key('transferListView')), findsNothing);
    });

    testWidgets('3. 同一个值不会被重复响应（防重复弹出与页面重建重弹）', (tester) async {
      final requestNotifier = _TestValueNotifier(0);
      await tester.pumpWidget(
        _buildSftpApp(openTransfersRequest: requestNotifier),
      );
      await tester.pumpAndSettle();

      // 初始值 0，面板未弹
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);

      // 对初始值 0 再次通知，仍不弹
      requestNotifier.forceNotify();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);

      // 递增至 1：第一次弹出
      requestNotifier.value = 1;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);

      // 在已打开状态下再次通知相同值 1，不会叠加弹出第二个面板
      requestNotifier.forceNotify();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);

      // 手动关闭面板
      await tester.tap(find.byKey(const Key('transferSheetCloseButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);

      // 值未发生变化时（仍为 1）再次通知，不得重复弹出
      requestNotifier.forceNotify();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);

      // 递增至 2：第二次有效请求正常弹出
      requestNotifier.value = 2;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);
    });

    testWidgets('4. openTransfersRequest 为 null 时直接渲染不崩且生命周期清理正常', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSftpApp(openTransfersRequest: null));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('transferEmptyView')), findsNothing);
      expect(find.byKey(const Key('transferListView')), findsNothing);

      // 卸载组件触发 dispose，验证 ?.removeListener 的空安全路径正常执行
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('5. didUpdateWidget 换绑 openTransfersRequest 时正确解绑旧通知器并监听新通知器', (
      tester,
    ) async {
      final notifier1 = _TestValueNotifier(0);
      final notifier2 = _TestValueNotifier(0);

      await tester.pumpWidget(_buildSftpApp(openTransfersRequest: notifier1));
      await tester.pumpAndSettle();

      // 换绑为 notifier2
      await tester.pumpWidget(_buildSftpApp(openTransfersRequest: notifier2));
      await tester.pumpAndSettle();

      // 递增旧 notifier1，已被解绑，不应弹出面板
      notifier1.value = 1;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsNothing);

      // 递增新 notifier2，已正确监听，正常弹出面板
      notifier2.value = 1;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);
    });
  });
}
