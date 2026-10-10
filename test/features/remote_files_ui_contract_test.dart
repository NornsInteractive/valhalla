import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeSftpOperations implements SftpOperations {
  List<SftpFileItem> files = const [];

  @override
  Future<List<SftpFileItem>> listFiles(String path) async => files;
  @override
  Future<String> readFileContent(String path) async => '';
  @override
  Future<void> writeFileContent(String path, String content) async {}
  @override
  Future<void> createDirectory(String path) async {}
  @override
  Future<void> deleteDirectory(String path) async {}
  @override
  Future<void> deleteFile(String path) async {}
  @override
  Future<void> rename(String oldPath, String newPath) async {}
  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int)? onProgress,
  }) async => throw UnimplementedError();
  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int)? onProgress,
  }) async => throw UnimplementedError();
  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int)? onProgress,
  }) async => 0;
  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int)? onProgress,
  }) async => 0;
}

class _UiTestSftpNotifier extends SftpNotifier {
  _UiTestSftpNotifier(this._initial);

  final SftpState _initial;
  final setHiddenCalls = <bool>[];
  final navigatedTo = <String>[];
  final upNavigations = <String>[];
  int refreshCount = 0;
  Completer<void>? hideToggleGate;

  @override
  SftpState build() => _initial;

  @override
  Future<void> navigateTo(String path) async {
    navigatedTo.add(path);
    state = state.copyWith(currentPath: path);
  }

  @override
  Future<void> setShowHiddenFiles(bool value) async {
    setHiddenCalls.add(value);
    final gate = hideToggleGate;
    if (gate != null) await gate.future;
    state = state.copyWith(showHiddenFiles: value);
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = state.copyWith(files: [...state.files]);
  }

  @override
  Future<void> navigateUp() async {
    upNavigations.add(state.currentPath);
    final lastSlash = state.currentPath.lastIndexOf('/');
    final parent = lastSlash <= 0
        ? '/'
        : state.currentPath.substring(0, lastSlash);
    state = state.copyWith(currentPath: parent);
  }

  void updatePath(String path) {
    state = state.copyWith(currentPath: path);
  }

  void bumpFiles() {
    state = state.copyWith(files: [...state.files]);
  }
}

class _ConnectedUiNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _DisconnectedUiNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.disconnected);
}

/// These cases render only the SFTP surface, which reads
/// `fileBookmarksProvider` → `activeServerProvider` + `localStorageServiceProvider`.
/// Pin the same connected srv-1 metadata the shell passes, so the bookmark
/// provider resolves instead of hitting the uninitialized storage provider.
class _ActiveServerWithProfile extends ActiveServerNotifier {
  final ServerProfile _server;
  _ActiveServerWithProfile(this._server);

  @override
  ServerProfile? build() => _server;
}

const _kUiServer = ServerProfile(
  id: 'srv-1',
  name: 'Test Server',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
  authType: AuthType.password,
);

/// Initialized once per file; `_app` is synchronous and reuses this instance.
late final LocalStorageService _storage;

Widget _app({
  required SftpState state,
  _UiTestSftpNotifier? notifier,
  bool connected = true,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  final notif = notifier ?? _UiTestSftpNotifier(state);
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      activeServerProvider.overrideWith(
        () => _ActiveServerWithProfile(_kUiServer),
      ),
      sftpOperationsProvider.overrideWithValue(_FakeSftpOperations()),
      sftpProvider.overrideWith(() => notif),
      serverConnectionProvider.overrideWith(
        connected ? _ConnectedUiNotifier.new : _DisconnectedUiNotifier.new,
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: SftpFileView()),
    ),
  );
}

SftpFileItem _uiItem(
  String name, {
  bool isDirectory = false,
  bool isSymbolicLink = false,
  String? linkTargetErrorCode,
  String? path,
}) => SftpFileItem(
  name: name,
  path: path ?? '/var/www/my-project/$name',
  isDirectory: isDirectory,
  isSymbolicLink: isSymbolicLink,
  linkTargetErrorCode: linkTargetErrorCode,
  sizeBytes: 8,
  formattedSize: '8 B',
  permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
  modified: '2026-10-05',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.init();
  });

  void setSurface(WidgetTester tester, Size size, double dpr) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('320dp 与 2x 文字不溢出', (tester) async {
    setSurface(tester, const Size(960, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(
        currentPath: '/var/www/very-long-segment-name/my-project',
        files: [
          _uiItem('alpha'),
          _uiItem('beta', isDirectory: true),
          _uiItem('.hidden-w'),
        ],
      ),
    );
    await tester.pumpWidget(
      _app(state: notifier.build(), notifier: notifier, textScale: 2.0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('360dp 面包屑一屏可见超过两个段', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/var/www/my-project', files: [_uiItem('alpha')]),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();
    final segs = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith(
            'sftp_breadcrumb_seg_',
          ),
    );
    expect(segs.evaluate().length, 3);
    final visible = segs.evaluate().where((e) {
      final rect = e.renderObject is RenderBox
          ? (e.renderObject as RenderBox).localToGlobal(Offset.zero) &
                (e.renderObject as RenderBox).size
          : null;
      return rect != null && rect.left >= -1 && rect.right <= 361;
    }).length;
    expect(visible, greaterThanOrEqualTo(2));
  });

  testWidgets('导航后末尾段可见', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(
        currentPath: '/avery/bvery/cvery/dvery/every/fverylongsegment',
        files: [_uiItem('alpha')],
      ),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();
    notifier.updatePath(
      '/avery/bvery/cvery/dvery/every/fverylongsegment/gmore',
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('gmore')).right, lessThanOrEqualTo(360));
  });

  testWidgets('refresh 不强制滚回末尾', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(
        currentPath: '/avery/bvery/cvery/dvery/every/deep',
        files: [_uiItem('alpha')],
      ),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();
    final scroll = find.ancestor(
      of: find.byKey(const Key('sftp_breadcrumb_seg_0')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scroll, const Offset(200, 0));
    await tester.pumpAndSettle();
    // 末尾段被推出视口，之后 refresh 不应再强滚回去。
    notifier.bumpFiles();
    await tester.pumpAndSettle();
    final deep = tester.getRect(find.text('deep'));
    expect(deep.left, greaterThan(360));
  });

  testWidgets('RTL 下路径保持 LTR', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/var/www', files: [_uiItem('alpha')]),
    );
    await tester.pumpWidget(
      _app(
        state: notifier.build(),
        notifier: notifier,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    final directionality = find.ancestor(
      of: find.text('/').first,
      matching: find.byType(Directionality),
    );
    expect(
      tester.widget<Directionality>(directionality.first).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('hidden 开关离线可用且 pending 时不可重复提交', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/var', files: [_uiItem('.secret')]),
    );
    notifier.hideToggleGate = Completer<void>();
    await tester.pumpWidget(
      _app(state: notifier.build(), notifier: notifier, connected: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sftpToggleHiddenButton')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sftpToggleHiddenButton')));
    await tester.pump();
    expect(notifier.setHiddenCalls.length, 1, reason: 'pending 中第二次点击必须被忽略');
    notifier.hideToggleGate!.complete();
    await tester.pumpAndSettle();
    expect(notifier.setHiddenCalls, [true]);
  });

  testWidgets('捕获的 onPressed 先调两次再重建帧不重复提交', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/var', files: [_uiItem('.secret')]),
    );
    notifier.hideToggleGate = Completer<void>();
    await tester.pumpWidget(
      _app(state: notifier.build(), notifier: notifier, connected: false),
    );
    await tester.pumpAndSettle();
    final captured = tester
        .widget<IconButton>(find.byKey(const Key('sftpToggleHiddenButton')))
        .onPressed!;
    // 同一个闭包在 rebuild 之前被调用两次：必须只触发一次保存。
    captured();
    captured();
    await tester.pumpAndSettle();
    expect(notifier.setHiddenCalls.length, 1);
    notifier.hideToggleGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('搜索行与操作行保持两行布局', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/var', files: [_uiItem('alpha')]),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sftp_search_field')), findsOneWidget);
    expect(find.byKey(const Key('sftpToggleHiddenButton')), findsOneWidget);
  });

  testWidgets('compact breadcrumbs stay tight yet touchable and exact', (
    tester,
  ) async {
    setSurface(tester, const Size(1080, 2400), 3);
    const segments = ['a', 'b', 'c'];
    final notifier = _UiTestSftpNotifier(
      SftpState(currentPath: '/a/b/c', files: [_uiItem('alpha')]),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();

    // Short segments must keep a 44dp touch height.
    for (var index = 0; index < segments.length; index++) {
      final segment = tester.getRect(
        find.byKey(Key('sftp_breadcrumb_seg_$index')),
      );
      expect(segment.height, greaterThanOrEqualTo(44));
    }

    // The old 44dp minimum width inflated every short segment into a wide
    // slot, so adjacent labels drifted far apart. The gap between two
    // consecutive labels is chevron (14) + horizontal padding (6 + 6).
    var maxGap = 0.0;
    for (var index = 0; index < segments.length - 1; index++) {
      final current = tester.getRect(
        find.descendant(
          of: find.byKey(
            Key('sftp_breadcrumb_seg_$index'),
            skipOffstage: false,
          ),
          matching: find.text(segments[index]),
        ),
      );
      final next = tester.getRect(
        find.descendant(
          of: find.byKey(
            Key('sftp_breadcrumb_seg_${index + 1}'),
            skipOffstage: false,
          ),
          matching: find.text(segments[index + 1]),
        ),
      );
      maxGap = math.max(maxGap, next.left - current.right);
    }
    expect(maxGap, lessThanOrEqualTo(30));

    // Exact navigation targets survive the compaction. Segments are tapped
    // from the deepest one so every recorded path stays unambiguous.
    await tester.tap(find.byKey(const Key('sftp_breadcrumb_seg_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sftp_breadcrumb_seg_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sftp_breadcrumb_seg_0')));
    await tester.pumpAndSettle();
    expect(notifier.navigatedTo, ['/a/b/c', '/a/b', '/a']);

    // Up still works while a parent directory exists.
    await tester.tap(find.byKey(const Key('sftp_breadcrumb_up')));
    await tester.pumpAndSettle();
    expect(notifier.upNavigations, ['/a']);
    expect(notifier.state.currentPath, '/');

    // At the root the up button stays disabled.
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('sftp_breadcrumb_up')))
          .onPressed,
      isNull,
    );

    // The root segment still navigates to '/'.
    await tester.tap(find.byKey(const Key('sftp_breadcrumb_root')));
    await tester.pumpAndSettle();
    expect(notifier.navigatedTo, ['/a/b/c', '/a/b', '/a', '/']);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('sftp_breadcrumb_up')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('目录链接按别名导航；坏链弹错误且无预览/下载选项', (tester) async {
    setSurface(tester, const Size(1080, 2400), 3);
    final notifier = _UiTestSftpNotifier(
      SftpState(
        currentPath: '/var',
        files: [
          _uiItem(
            'linkdir',
            isDirectory: true,
            isSymbolicLink: true,
            path: '/var/linkdir',
          ),
          _uiItem(
            'broken.txt',
            isSymbolicLink: true,
            linkTargetErrorCode: SftpFileItem.linkTargetUnavailableCode,
            path: '/var/broken.txt',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_app(state: notifier.build(), notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('linkdir'));
    await tester.pumpAndSettle();
    expect(notifier.navigatedTo, ['/var/linkdir']);

    await tester.tap(find.text('broken.txt'));
    await tester.pumpAndSettle();
    expect(notifier.navigatedTo.length, 1, reason: '坏链不得导航');
    expect(
      find.text('Symlink target is broken or unavailable'),
      findsOneWidget,
    );

    final more = find.descendant(
      of: find.ancestor(
        of: find.text('broken.txt'),
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.more_vert),
    );
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.download), findsNothing);
    expect(find.byIcon(Icons.edit_note), findsNothing);
  });
}
