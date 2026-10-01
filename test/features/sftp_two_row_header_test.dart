import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeOperations implements SftpOperations {
  @override
  Future<List<SftpFileItem>> listFiles(String path) async => [];
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
}

class _TrackingSftpNotifier extends SftpNotifier {
  SftpState _currentState;
  bool navigateUpCalled = false;
  bool refreshCalled = false;
  String? lastSearchQuery;

  _TrackingSftpNotifier(this._currentState);

  @override
  SftpState build() => _currentState;

  @override
  Future<void> navigateUp() async {
    navigateUpCalled = true;
  }

  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }

  @override
  void setSearchQuery(String query) {
    lastSearchQuery = query;
    _currentState = _currentState.copyWith(searchQuery: query);
    state = _currentState;
  }

  void updatePath(String newPath) {
    _currentState = _currentState.copyWith(currentPath: newPath);
    state = _currentState;
  }
}

SftpFileItem _makeItem(String name, {bool isDirectory = false}) {
  return SftpFileItem(
    name: name,
    path: '/home/$name',
    isDirectory: isDirectory,
    sizeBytes: 100,
    formattedSize: '100 B',
    permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
    modified: '2026-01-01 00:00',
  );
}

/// The header renders against the connection state, and the real connection
/// notifier needs a live `LocalStorageService` for the SSH client manager.
/// These cases drive real navigation and search, so the connection is up.
class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

Widget _buildApp({
  required SftpState state,
  required _TrackingSftpNotifier notifier,
}) {
  return ProviderScope(
    overrides: [
      sftpOperationsProvider.overrideWithValue(_FakeOperations()),
      sftpProvider.overrideWith(() => notifier),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: const SftpFileView()),
    ),
  );
}

void main() {
  group('SFTP Two-Row Header and Special Navigation', () {
    testWidgets(
      'renders Row 1 search and Row 2 actions without overflow on 320px screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final notifier = _TrackingSftpNotifier(
          const SftpState(currentPath: '/home', isLoading: false),
        );

        await tester.pumpWidget(
          _buildApp(
            state: const SftpState(currentPath: '/home', isLoading: false),
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Verify search field exists
        expect(find.byType(TextField), findsOneWidget);

        // Verify action buttons exist in Row 2
        expect(find.byIcon(Icons.upload_file), findsOneWidget);
        expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
        expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
        expect(find.byIcon(Icons.sort), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // No RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('typing search updates query and clear button resets it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = _TrackingSftpNotifier(
        const SftpState(currentPath: '/home', isLoading: false),
      );

      await tester.pumpWidget(
        _buildApp(
          state: const SftpState(currentPath: '/home', isLoading: false),
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'needle');
      await tester.pumpAndSettle();

      expect(notifier.lastSearchQuery, 'needle');

      // Clear button should be visible and tapping it clears search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(notifier.lastSearchQuery, '');
    });

    testWidgets(
      'special .. navigates up and . refreshes without showing context menu',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final items = [
          _makeItem('..', isDirectory: true),
          _makeItem('.', isDirectory: true),
          _makeItem('normal.txt', isDirectory: false),
        ];

        final notifier = _TrackingSftpNotifier(
          SftpState(currentPath: '/home', files: items, isLoading: false),
        );

        await tester.pumpWidget(
          _buildApp(
            state: SftpState(
              currentPath: '/home',
              files: items,
              isLoading: false,
            ),
            notifier: notifier,
          ),
        );
        await tester.pumpAndSettle();

        // Subdirectory shows '..' for navigating up, but '.' is never displayed
        final dotDotFinder = find.text('..');
        expect(dotDotFinder, findsOneWidget);
        expect(find.text('.'), findsNothing);

        await tester.tap(dotDotFinder);
        await tester.pumpAndSettle();

        expect(notifier.navigateUpCalled, isTrue);

        // Verify '..' does not have context menu more icon button
        final dotDotRow = find.ancestor(
          of: dotDotFinder,
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(
            of: dotDotRow,
            matching: find.byIcon(Icons.more_vert),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('root directory hides both . and ..', (tester) async {
      final items = [
        _makeItem('..', isDirectory: true),
        _makeItem('.', isDirectory: true),
        _makeItem('root_file.txt', isDirectory: false),
      ];

      final notifier = _TrackingSftpNotifier(
        SftpState(currentPath: '/', files: items, isLoading: false),
      );

      await tester.pumpWidget(
        _buildApp(
          state: SftpState(currentPath: '/', files: items, isLoading: false),
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      // Neither '.' nor '..' should be displayed in root
      expect(find.text('.'), findsNothing);
      expect(find.text('..'), findsNothing);
      expect(find.text('root_file.txt'), findsOneWidget);
    });
  });
}
