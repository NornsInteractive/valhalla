import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/constants/layout_breakpoints.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/features/docker/docker_view.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/servers/server_form_dialog.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/delete_server_dialog.dart';

class _FakeOperations implements SftpOperations {
  @override
  Future<List<SftpFileItem>> listFiles(String path) async => const [];
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
    String r,
    String l, {
    void Function(int)? onProgress,
  }) async => throw UnimplementedError();
  @override
  Future<SftpTransferHandle> startUpload(
    String l,
    String r, {
    void Function(int)? onProgress,
  }) async => throw UnimplementedError();
  @override
  Future<int> downloadFile(
    String r,
    String l, {
    void Function(int)? onProgress,
  }) async => 0;
  @override
  Future<int> uploadFile(
    String l,
    String r, {
    void Function(int)? onProgress,
  }) async => 0;
}

class _TestDockerNotifier extends DockerNotifier {
  final DockerState _state;
  _TestDockerNotifier(this._state);
  @override
  DockerState build() => _state;
  @override
  Future<Map<String, dynamic>> inspectContainer(String id) async => {
    'Id': id,
    'Name': '/test-container',
    'State': {'Status': 'running'},
  };
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier(this._servers);
  @override
  List<ServerProfile> build() => _servers;
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _state;
  _TestServerConnectionNotifier(this._state);
  @override
  ServerConnectionState build() => _state;
}

class _TestSftpNotifier extends SftpNotifier {
  final SftpState _state;
  _TestSftpNotifier(this._state);
  @override
  SftpState build() => _state;
}

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

Widget _wrapWithApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late LocalStorageService localStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localStorage = await LocalStorageService.init();
  });

  final testServer = ServerProfile(
    id: 'srv-1',
    name: 'Production Server',
    host: '10.0.0.1',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
  );

  const connectedState = ServerConnectionState(
    status: ConnectionStateEnum.connected,
  );

  group('Adaptive Dialogs (Task C1 & C2)', () {
    testWidgets(
      'ServerFormDialog: mobile fullscreen on narrow 360px screen without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
            ],
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ServerFormDialog(),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);

        final formBox = tester.getRect(find.byType(Form));
        expect(
          formBox.width,
          lessThanOrEqualTo(360.0),
          reason: 'Form width must shrink to fit inside narrow 360px screen',
        );
      },
    );

    testWidgets(
      'ServerFormDialog: widened with maxHeight constraint on wide screen (1200px)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
            ],
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ServerFormDialog(),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final formBox = tester.getRect(find.byType(Form));
        expect(
          formBox.width,
          lessThanOrEqualTo(560.0),
          reason: 'Form width on wide screen must be capped at 560px',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is ConstrainedBox &&
                w.constraints.maxWidth == 560.0 &&
                w.constraints.maxHeight == 720.0,
          ),
          findsOneWidget,
          reason:
              'Dialog ConstrainedBox must enforce maxWidth 560 and maxHeight 720',
        );
      },
    );

    testWidgets(
      'DeleteServerDialog: capped at maxWidth: 400 on wide screen (1200px)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
            ],
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showDeleteServerConfirmDialog(context, testServer),
                child: const Text('Open Delete Dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Delete Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        final msgFinder = find.textContaining(
          "Are you sure you want to delete server 'Production Server'?",
        );
        final msgBox = tester.getRect(msgFinder);
        expect(
          msgBox.width,
          lessThanOrEqualTo(400.0),
          reason: 'Delete dialog content must be capped at 400px maxWidth',
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 400.0,
          ),
          findsOneWidget,
          reason: 'Delete dialog ConstrainedBox must enforce maxWidth 400',
        );
      },
    );
  });

  group('Adaptive Bottom Sheets (Task C3)', () {
    testWidgets(
      'MainShell narrow (360px): no top theme shortcut icon and no quick switch sheet',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([testServer]),
              ),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              sftpProvider.overrideWith(_FakeSftpNotifier.new),
            ],
            child: const MainShell(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.palette_outlined),
          findsNothing,
          reason: 'Top theme quick switch button was removed from top bar',
        );
        expect(
          find.byType(BottomSheet),
          findsNothing,
          reason: 'Theme quick switch sheet must not be reachable',
        );
      },
    );

    testWidgets(
      'MainShell wide (1200px): no top theme shortcut icon and no quick switch sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([testServer]),
              ),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              sftpProvider.overrideWith(_FakeSftpNotifier.new),
            ],
            child: const MainShell(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.palette_outlined),
          findsNothing,
          reason: 'Top theme quick switch button was removed from top bar',
        );
        expect(
          find.byType(BottomSheet),
          findsNothing,
          reason: 'Theme quick switch sheet must not be reachable',
        );
      },
    );

    testWidgets(
      'Server selector sheet: centered and constrained to modalSheetMaxWidth (560) on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([testServer]),
              ),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              sftpProvider.overrideWith(_FakeSftpNotifier.new),
            ],
            child: const MainShell(),
          ),
        );
        await tester.pumpAndSettle();

        final serverSelectorChip = find.text('Production Server');
        expect(serverSelectorChip, findsWidgets);
        await tester.tap(serverSelectorChip.first);
        await tester.pumpAndSettle();

        final sheetMaterialFinder = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first;
        expect(sheetMaterialFinder, findsOneWidget);
        final sheetRect = tester.getRect(sheetMaterialFinder);
        expect(
          sheetRect.width,
          equals(LayoutBreakpoints.modalSheetMaxWidth),
          reason:
              'Server selector sheet width must be capped at 560px on wide screen',
        );
        expect(
          sheetRect.left,
          equals((1200 - LayoutBreakpoints.modalSheetMaxWidth) / 2),
          reason:
              'Server selector sheet must be horizontally centered on wide screen',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is ConstrainedBox &&
                w.constraints.maxWidth == LayoutBreakpoints.modalSheetMaxWidth,
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'Docker inspect sheet: constrained to modalSheetWideMaxWidth (640) on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = DockerContainer(
          id: 'c123456789012',
          name: 'web-prod',
          image: 'nginx:latest',
          state: DockerContainerState.running,
          status: 'Up 5 hours',
          ports: '80/tcp',
        );
        final dockerState = DockerState(containers: [container]);

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                () => _TestServerConnectionNotifier(connectedState),
              ),
              dockerProvider.overrideWith(
                () => _TestDockerNotifier(dockerState),
              ),
            ],
            child: const DockerView(),
          ),
        );
        await tester.pumpAndSettle();

        final inspectBtn = find.byIcon(Icons.info_outline);
        expect(inspectBtn, findsOneWidget);
        await tester.tap(inspectBtn);
        await tester.pumpAndSettle();

        final sheetMaterialFinder = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first;
        expect(sheetMaterialFinder, findsOneWidget);
        final sheetRect = tester.getRect(sheetMaterialFinder);
        expect(
          sheetRect.width,
          equals(LayoutBreakpoints.modalSheetWideMaxWidth),
          reason: 'Docker inspect sheet must be capped at 640px on wide screen',
        );
        expect(
          sheetRect.left,
          equals((1200 - LayoutBreakpoints.modalSheetWideMaxWidth) / 2),
          reason:
              'Docker inspect sheet must be horizontally centered on wide screen',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is ConstrainedBox &&
                w.constraints.maxWidth ==
                    LayoutBreakpoints.modalSheetWideMaxWidth,
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'SFTP transfer list sheet: constrained to modalSheetWideMaxWidth (640) on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const sftpState = SftpState(
          currentPath: '/home/user',
          isLoading: false,
          files: [],
        );

        await tester.pumpWidget(
          _wrapWithApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
              sftpOperationsProvider.overrideWithValue(_FakeOperations()),
              sftpProvider.overrideWith(() => _TestSftpNotifier(sftpState)),
            ],
            child: const SftpFileView(),
          ),
        );
        await tester.pumpAndSettle();

        final transferBtn = find.byKey(const Key('sftpTransferListButton'));
        expect(transferBtn, findsOneWidget);
        await tester.tap(transferBtn);
        await tester.pumpAndSettle();

        final sheetMaterialFinder = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first;
        expect(sheetMaterialFinder, findsOneWidget);
        final sheetRect = tester.getRect(sheetMaterialFinder);
        expect(
          sheetRect.width,
          equals(LayoutBreakpoints.modalSheetWideMaxWidth),
          reason: 'SFTP transfer sheet must be capped at 640px on wide screen',
        );
        expect(
          sheetRect.left,
          equals((1200 - LayoutBreakpoints.modalSheetWideMaxWidth) / 2),
          reason:
              'SFTP transfer sheet must be horizontally centered on wide screen',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is ConstrainedBox &&
                w.constraints.maxWidth ==
                    LayoutBreakpoints.modalSheetWideMaxWidth,
          ),
          findsWidgets,
        );
      },
    );
  });
}
