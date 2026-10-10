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

class _FakeTransferHandle implements SftpTransferHandle {
  @override
  final int totalBytes = 100;
  @override
  int get transferredBytes => 100;
  @override
  Future<void> get done => Future.value();
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> abort() async {}
}

class _FakeOperations implements SftpOperations {
  List<SftpFileItem> files = const [];
  final List<String> readPaths = [];
  final List<(String, String)> writtenFiles = [];
  final List<(String, String)> downloads = [];
  final List<(String, String)> uploads = [];

  /// 非空时 [readFileContent] 抛出它，用来测「读失败不要弹空编辑器」。
  Object? readThrows;

  /// 非空时 [writeFileContent] 抛出它，用来测保存失败行为。
  Object? writeThrows;

  _FakeOperations();
  _FakeOperations.empty();

  @override
  Future<List<SftpFileItem>> listFiles(String path) async => files;

  @override
  Future<String> readFileContent(String path) async {
    readPaths.add(path);
    if (readThrows != null) throw readThrows!;
    return 'hello world from $path';
  }

  @override
  Future<void> writeFileContent(String path, String content) async {
    if (writeThrows != null) throw writeThrows!;
    writtenFiles.add((path, content));
  }

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
    void Function(int bytesRead)? onProgress,
  }) async {
    downloads.add((remotePath, localPath));
    return _FakeTransferHandle();
  }

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    uploads.add((localPath, remotePath));
    return _FakeTransferHandle();
  }

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    downloads.add((remotePath, localPath));
    return 100;
  }

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    uploads.add((localPath, remotePath));
    return 100;
  }
}

class _TestSftpNotifier extends SftpNotifier {
  final SftpState _initial;
  final _FakeOperations _ops;
  final List<({SftpSortKey key, bool ascending})> setSortCalls = [];

  _TestSftpNotifier(this._initial, [_FakeOperations? ops])
    : _ops = ops ?? _FakeOperations.empty();

  @override
  Future<void> setSort({
    required SftpSortKey key,
    required bool ascending,
  }) async {
    setSortCalls.add((key: key, ascending: ascending));
    state = state.copyWith(sortKey: key, sortAscending: ascending);
  }

  @override
  SftpState build() => _initial;

  @override
  Future<void> openFileForEditing(SftpFileItem item) async {
    if (item.sizeBytes > SftpClientService.maxPreviewBytes) {
      state = state.copyWith(errorMessage: SftpNotifier.previewTooLargeCode);
      return;
    }
    if (!canPreview(item)) {
      state = state.copyWith(errorMessage: SftpNotifier.previewUnsupportedCode);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final content = await _ops.readFileContent(item.path);
      state = state.copyWith(
        isLoading: false,
        editingFilePath: item.path,
        editingFileContent: content,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: SftpNotifier.readFailedCode,
      );
    }
  }

  @override
  void closeFileEditor() {
    state = state.copyWith(clearEditor: true, clearError: true);
  }

  @override
  Future<void> saveFileContent(String path, String content) async {
    await _ops.writeFileContent(path, content);
    closeFileEditor();
  }

  @override
  Future<void> downloadTo(SftpFileItem item, String localPath) async {
    await _ops.downloadFile(item.path, localPath);
  }

  @override
  Future<void> uploadFrom(String localPath, {String? remoteName}) async {
    final name = remoteName ?? localPath.split('/').last;
    final remotePath = state.currentPath == '/'
        ? '/$name'
        : '${state.currentPath}/$name';
    await _ops.uploadFile(localPath, remotePath);
  }

  final List<SftpFileItem> downloadCalls = [];
  final List<String> openCompletedCalls = [];
  bool returnNullTaskId = false;

  @override
  Future<String?> downloadFile(SftpFileItem item) async {
    downloadCalls.add(item);
    if (returnNullTaskId) return null;
    return 'task-${downloadCalls.length}';
  }

  @override
  Future<void> openCompletedTransfer(String id) async {
    openCompletedCalls.add(id);
  }

  @override
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// The SFTP surface reads the connection state, and the real connection
/// notifier builds the SSH client manager, which needs a live
/// `LocalStorageService`. These tests fake the file operations only, so the
/// connection is supplied here as well - connected, because every case in this
/// file drives real file actions.
class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

/// The SFTP surface reads `fileBookmarksProvider`, which resolves the active
/// server and the initialized `LocalStorageService`. Pin the same connected
/// srv-1 metadata the shell would supply; no real SSH is started.
class _ActiveServerWithProfile extends ActiveServerNotifier {
  final ServerProfile _server;
  _ActiveServerWithProfile(this._server);

  @override
  ServerProfile? build() => _server;
}

const _kFileViewServer = ServerProfile(
  id: 'srv-1',
  name: 'Test Server',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
  authType: AuthType.password,
);

/// Initialized once per file; `_buildTestApp` is synchronous and reuses this.
late final LocalStorageService _storage;

Widget _buildTestApp({
  required SftpState state,
  _FakeOperations? ops,
  _TestSftpNotifier? notifier,
}) {
  final operations = ops ?? _FakeOperations();
  final notif = notifier ?? _TestSftpNotifier(state, operations);
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      activeServerProvider.overrideWith(
        () => _ActiveServerWithProfile(_kFileViewServer),
      ),
      sftpOperationsProvider.overrideWithValue(operations),
      sftpProvider.overrideWith(() => notif),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SftpFileView()),
    ),
  );
}

/// 读失败用的假异常。
class SftpReadFailure implements Exception {
  final String message;
  const SftpReadFailure(this.message);

  @override
  String toString() => 'SftpReadFailure: $message';
}

SftpFileItem _makeItem(
  String name, {
  bool isDirectory = false,
  int size = 100,
  String? path,
}) {
  return SftpFileItem(
    name: name,
    path: path ?? '/var/www/$name',
    isDirectory: isDirectory,
    sizeBytes: size,
    formattedSize: '$size B',
    permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
    modified: '2026-09-16 12:00',
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.init();
  });

  group('SftpFileView', () {
    testWidgets(
      'unsupported files (.zip, .png) hide open menu item and do not read file or open editor on tap',
      (tester) async {
        final fakeOps = _FakeOperations();
        final zipItem = _makeItem('archive.zip');
        final pngItem = _makeItem('image.png');
        final state = SftpState(
          currentPath: '/var/www',
          files: [zipItem, pngItem],
        );

        await tester.pumpWidget(_buildTestApp(state: state, ops: fakeOps));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // 1. PopupMenuButton on archive.zip should NOT contain "Open"
        final firstMoreBtn = find.byIcon(Icons.more_vert).first;
        await tester.tap(firstMoreBtn);
        await tester.pumpAndSettle();

        expect(find.text(l10n.sftpOpen), findsNothing);
        expect(find.text(l10n.sftpDownload), findsOneWidget);

        // Dismiss menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 2. Tapping row directly should show unsupported SnackBar and NOT call readFileContent or show editor
        await tester.tap(find.text('archive.zip'));
        await tester.pump();

        expect(fakeOps.readPaths, isEmpty);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text(l10n.sftpOpenUnsupported), findsOneWidget);
      },
    );

    testWidgets(
      'supported file (.txt) shows Open in menu and opens editor on tap/open and can save',
      (tester) async {
        final fakeOps = _FakeOperations();
        final txtItem = _makeItem('notes.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        await tester.pumpWidget(_buildTestApp(state: state, ops: fakeOps));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // 1. Popup menu has Open and Download
        final moreBtn = find.byIcon(Icons.more_vert);
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        expect(find.text(l10n.sftpOpen), findsOneWidget);
        expect(find.text(l10n.sftpDownload), findsOneWidget);

        // Tap Open
        await tester.tap(find.text(l10n.sftpOpen));
        await tester.pumpAndSettle();

        // Editor should be open
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(l10n.fileEditorSave), findsOneWidget);
        expect(fakeOps.readPaths, contains(txtItem.path));

        // Save
        await tester.tap(find.text(l10n.fileEditorSave));
        await tester.pumpAndSettle();

        expect(fakeOps.writtenFiles.any((w) => w.$1 == txtItem.path), isTrue);
      },
    );

    testWidgets(
      'read failure does not open an empty editor and surfaces the error',
      (tester) async {
        final fakeOps = _FakeOperations()
          ..readThrows = const SftpReadFailure('permission denied');
        final txtItem = _makeItem('notes.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        await tester.pumpWidget(_buildTestApp(state: state, ops: fakeOps));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.text('notes.txt'));
        await tester.pumpAndSettle();

        // 读失败时编辑器的进入条件是 editingFilePath == item.path；
        // 不满足就必须**完全不开**编辑器——否则用户会看到一个空白的
        // 全屏编辑器，还以为是文件本来就是空的。
        expect(fakeOps.readPaths, contains(txtItem.path));
        expect(
          find.byType(Dialog),
          findsNothing,
          reason: '读失败不能弹空编辑器，这正是本轮要修的 bug',
        );
        // 文案会同时出现在错误横幅与 SnackBar 两处，这里只断言至少可见。
        expect(find.text(l10n.sftpReadFailed), findsWidgets);
      },
    );

    testWidgets(
      'file larger than 1MB surfaces localized preview too large message with download instruction and does not open editor',
      (tester) async {
        final fakeOps = _FakeOperations();
        final largeItem = _makeItem(
          'big_log.txt',
          size: 2 * 1024 * 1024, // 2MB > 1MB preview threshold
        );
        final state = SftpState(currentPath: '/var/log', files: [largeItem]);

        await tester.pumpWidget(_buildTestApp(state: state, ops: fakeOps));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.text('big_log.txt'));
        await tester.pumpAndSettle();

        // Must not open editor
        expect(find.byType(Dialog), findsNothing);
        // Error banner and snackbar show localized preview too large message
        expect(find.text(l10n.sftpPreviewTooLarge), findsWidgets);
        expect(fakeOps.readPaths, isEmpty);
      },
    );

    testWidgets(
      'editor save failure catches error locally, shows error banner, does not dismiss dialog, and preserves unsaved content',
      (tester) async {
        final fakeOps = _FakeOperations()
          ..writeThrows = Exception('Disk quota exceeded');
        final txtItem = _makeItem('document.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        await tester.pumpWidget(_buildTestApp(state: state, ops: fakeOps));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Open editor
        await tester.tap(find.text('document.txt'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        final textField = find.byKey(const Key('sftp_editor_text_field'));
        expect(textField, findsOneWidget);

        // Edit text
        await tester.enterText(textField, 'new modified content');
        await tester.pump();

        // Attempt save - should fail
        final saveBtn = find.byKey(const Key('sftp_editor_save_button'));
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Dialog remains open
        expect(find.byType(Dialog), findsOneWidget);
        // Error banner is displayed
        expect(
          find.byKey(const Key('sftp_editor_error_banner')),
          findsOneWidget,
        );
        expect(find.text(l10n.sftpSaveFailed), findsWidgets);

        // Content is preserved
        expect(find.text('new modified content'), findsOneWidget);

        // Now clear the error condition and retry save
        fakeOps.writeThrows = null;
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Dialog dismissed on success
        expect(find.byType(Dialog), findsNothing);
        expect(
          fakeOps.writtenFiles.any(
            (w) => w.$1 == txtItem.path && w.$2 == 'new modified content',
          ),
          isTrue,
        );
      },
    );

    testWidgets('displays localized error banner for read failed', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final readFailState = const SftpState(
        currentPath: '/var/www',
        errorMessage: SftpNotifier.readFailedCode,
      );
      await tester.pumpWidget(_buildTestApp(state: readFailState));
      await tester.pump();

      expect(find.byKey(const Key('sftpErrorBanner')), findsOneWidget);
      expect(find.text(l10n.sftpReadFailed), findsOneWidget);
      expect(find.text(SftpNotifier.readFailedCode), findsNothing);
    });

    testWidgets('displays localized error banner for upload failed', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final uploadFailState = const SftpState(
        currentPath: '/var/www',
        errorMessage: SftpNotifier.uploadFailedCode,
      );
      await tester.pumpWidget(_buildTestApp(state: uploadFailState));
      await tester.pump();

      expect(find.byKey(const Key('sftpErrorBanner')), findsOneWidget);
      expect(find.text(l10n.sftpUploadFailed), findsOneWidget);
      expect(find.text(SftpNotifier.uploadFailedCode), findsNothing);
    });

    testWidgets('displays localized error banner for download failed', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final downloadFailState = const SftpState(
        currentPath: '/var/www',
        errorMessage: SftpNotifier.downloadFailedCode,
      );
      await tester.pumpWidget(_buildTestApp(state: downloadFailState));
      await tester.pump();

      expect(find.byKey(const Key('sftpErrorBanner')), findsOneWidget);
      expect(find.text(l10n.sftpDownloadFailed), findsOneWidget);
      expect(find.text(SftpNotifier.downloadFailedCode), findsNothing);
    });

    testWidgets(
      'disables upload while keeping download action enabled for continuous queueing when transfer != null',
      (tester) async {
        final txtItem = _makeItem('document.txt');
        final activeTransfer = const SftpTransfer(
          id: 'test-upload',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/document.txt',
          localPath: '/tmp/document.txt',
          transferredBytes: 50,
          totalBytes: 100,
          status: SftpTransferStatus.running,
        );

        final state = SftpState(
          currentPath: '/var/www',
          files: [txtItem],
          transfers: [activeTransfer],
        );

        final notifier = _TestSftpNotifier(state, _FakeOperations());
        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // 1. Transfer banner is visible with progress
        expect(find.byKey(const Key('sftpTransferBanner')), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);

        // 2. Upload button is disabled
        final uploadBtn = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.upload_file),
        );
        expect(uploadBtn.onPressed, isNull);

        // 3. Download menu item is enabled for continuous queuing
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        final downloadFinder = find.widgetWithText(
          PopupMenuItem<String>,
          l10n.sftpDownload,
        );
        expect(downloadFinder, findsOneWidget);
        final downloadItem = tester.widget<PopupMenuItem<String>>(
          downloadFinder,
        );
        expect(downloadItem.enabled, isTrue);

        // Tap download -> invokes downloadFile without premature success snackbar
        await tester.tap(downloadFinder);
        await tester.pumpAndSettle();

        expect(notifier.downloadCalls, hasLength(1));
        expect(notifier.downloadCalls.first.name, equals('document.txt'));
        expect(find.text(l10n.sftpDownloadSuccess), findsNothing);
      },
    );

    testWidgets(
      'tapping completed download or open button calls openCompletedTransfer',
      (tester) async {
        final completedTransfer = const SftpTransfer(
          id: 'transfer-done-1',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/report.pdf',
          localPath: '/downloads/report.pdf',
          transferredBytes: 200,
          totalBytes: 200,
          status: SftpTransferStatus.completed,
        );

        final state = SftpState(
          currentPath: '/var/www',
          files: [],
          transfers: [completedTransfer],
        );

        final notifier = _TestSftpNotifier(state, _FakeOperations());
        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pump();

        // Open transfer list sheet
        await tester.tap(find.byKey(const Key('sftpTransferListButton')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('transfer_open_transfer-done-1')),
          findsOneWidget,
        );

        // Tap open button
        await tester.tap(
          find.byKey(const Key('transfer_open_transfer-done-1')),
        );
        await tester.pumpAndSettle();

        expect(notifier.openCompletedCalls, contains('transfer-done-1'));

        // Also tapping the item row itself invokes openCompletedTransfer
        await tester.tap(
          find.byKey(const Key('transfer_item_transfer-done-1')),
        );
        await tester.pumpAndSettle();

        expect(notifier.openCompletedCalls.length, equals(2));

        // Also tapping the item filename invokes openCompletedTransfer
        await tester.tap(
          find.byKey(const Key('transfer_name_transfer-done-1')),
        );
        await tester.pumpAndSettle();

        expect(notifier.openCompletedCalls.length, equals(3));
      },
    );

    testWidgets(
      'shows non-blocking banner when downloadNotificationsUnavailable is true',
      (tester) async {
        final state = const SftpState(
          currentPath: '/var/www',
          downloadNotificationsUnavailable: true,
        );

        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pump();

        expect(
          find.byKey(const Key('downloadNotificationsUnavailableBanner')),
          findsOneWidget,
        );
      },
    );

    testWidgets('up arrow button is disabled at root', (tester) async {
      final rootState = const SftpState(currentPath: '/');
      await tester.pumpWidget(_buildTestApp(state: rootState));
      await tester.pump();

      final rootUpBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(rootUpBtn.onPressed, isNull);
    });

    testWidgets('up arrow button is enabled in subfolder', (tester) async {
      final subState = const SftpState(currentPath: '/var/www');
      await tester.pumpWidget(_buildTestApp(state: subState));
      await tester.pump();

      final subUpBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(subUpBtn.onPressed, isNotNull);
    });

    testWidgets('shows sort button and changes sort key and direction', (
      tester,
    ) async {
      final notifier = _TestSftpNotifier(
        const SftpState(
          currentPath: '/var/www',
          sortKey: SftpSortKey.name,
          sortAscending: true,
        ),
      );
      await tester.pumpWidget(
        _buildTestApp(state: notifier._initial, notifier: notifier),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        find.widgetWithIcon(PopupMenuButton<Object>, Icons.sort),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text(l10n.sftpSortName), findsOneWidget);
      expect(find.text(l10n.sftpSortSize), findsOneWidget);
      expect(find.text(l10n.sftpSortDate), findsOneWidget);
      expect(find.text(l10n.sftpSortAscending), findsOneWidget);
      expect(find.text(l10n.sftpSortDescending), findsOneWidget);

      final nameItem = tester.widget<CheckedPopupMenuItem<SftpSortKey>>(
        find.widgetWithText(
          CheckedPopupMenuItem<SftpSortKey>,
          l10n.sftpSortName,
        ),
      );
      expect(nameItem.checked, isTrue);

      final ascItem = tester.widget<CheckedPopupMenuItem<String>>(
        find.widgetWithText(
          CheckedPopupMenuItem<String>,
          l10n.sftpSortAscending,
        ),
      );
      expect(ascItem.checked, isTrue);

      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<SftpSortKey>,
          l10n.sftpSortSize,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(1));
      expect(notifier.setSortCalls.first.key, SftpSortKey.size);
      expect(notifier.setSortCalls.first.ascending, isTrue);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<String>,
          l10n.sftpSortDescending,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(2));
      expect(notifier.setSortCalls.last.key, SftpSortKey.size);
      expect(notifier.setSortCalls.last.ascending, isFalse);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<SftpSortKey>,
          l10n.sftpSortName,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(3));
      expect(notifier.setSortCalls.last.key, SftpSortKey.name);
      expect(notifier.setSortCalls.last.ascending, isFalse);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<SftpSortKey>,
          l10n.sftpSortName,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(4));
      expect(notifier.setSortCalls.last.key, SftpSortKey.name);
      expect(notifier.setSortCalls.last.ascending, isTrue);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<SftpSortKey>,
          l10n.sftpSortName,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(5));
      expect(notifier.setSortCalls.last.key, SftpSortKey.name);
      expect(notifier.setSortCalls.last.ascending, isFalse);
    });

    testWidgets(
      'runs 300ms fly-in animation to transfer icon and respects reduced motion',
      (tester) async {
        final txtItem = _makeItem('animate.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        final notifier = _TestSftpNotifier(state, _FakeOperations());
        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Tap more -> tap download
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, l10n.sftpDownload),
        );
        // Pump halfway through the 300ms animation
        await tester.pump(const Duration(milliseconds: 150));

        // Flying file icon is present in the tree
        expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);

        // Advance until animation completes (300ms total)
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Flying icon is dismissed after animation completes
        expect(find.byIcon(Icons.insert_drive_file), findsNothing);
      },
    );

    testWidgets(
      'skips fly-in animation when reduced motion (disableAnimations) is enabled',
      (tester) async {
        final txtItem = _makeItem('reduced_motion.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        final notifier = _TestSftpNotifier(state, _FakeOperations());
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: _buildTestApp(state: state, notifier: notifier),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, l10n.sftpDownload),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // When disableAnimations is true, no fly-in icon is inserted
        expect(find.byIcon(Icons.insert_drive_file), findsNothing);
        final transferBtn = tester.widget<IconButton>(
          find.byKey(const Key('sftpTransferListButton')),
        );
        expect(transferBtn.style, isNotNull);

        await tester.pumpAndSettle();
        expect(notifier.downloadCalls, hasLength(1));
      },
    );

    testWidgets(
      'does not trigger fly-in animation when downloadFile returns null',
      (tester) async {
        final txtItem = _makeItem('failed_queue.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        final notifier = _TestSftpNotifier(state, _FakeOperations())
          ..returnNullTaskId = true;
        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, l10n.sftpDownload),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Animation should not trigger if taskId is null
        expect(find.byIcon(Icons.insert_drive_file), findsNothing);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'disposes in-flight animation and removes overlay entry cleanly',
      (tester) async {
        final txtItem = _makeItem('in_flight.txt');
        final state = SftpState(currentPath: '/var/www', files: [txtItem]);

        final notifier = _TestSftpNotifier(state, _FakeOperations());
        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, l10n.sftpDownload),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Icon is flying
        expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);

        // Replace widget with empty container to trigger dispose
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        // Overlay entry should be removed on dispose
        expect(find.byIcon(Icons.insert_drive_file), findsNothing);
      },
    );

    group('Special dot navigation clean-up', () {
      testWidgets('root directory hides both . and ..', (tester) async {
        final dotItem = _makeItem('.', isDirectory: true, path: '/.');
        final dotDotItem = _makeItem('..', isDirectory: true, path: '/..');
        final folder = _makeItem('etc', isDirectory: true, path: '/etc');
        final file = _makeItem(
          'config.txt',
          isDirectory: false,
          path: '/config.txt',
        );

        final state = SftpState(
          currentPath: '/',
          files: [dotItem, dotDotItem, folder, file],
        );

        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();

        // . and .. must not be visible in root directory
        expect(find.text('.'), findsNothing);
        expect(find.text('..'), findsNothing);
        // Regular folder and file must be visible
        expect(find.text('etc'), findsOneWidget);
        expect(find.text('config.txt'), findsOneWidget);
      });

      testWidgets('subdirectory hides . but shows .. for navigating up', (
        tester,
      ) async {
        final dotItem = _makeItem('.', isDirectory: true, path: '/var/www/.');
        final dotDotItem = _makeItem(
          '..',
          isDirectory: true,
          path: '/var/www/..',
        );
        final folder = _makeItem(
          'html',
          isDirectory: true,
          path: '/var/www/html',
        );
        final file = _makeItem(
          'index.html',
          isDirectory: false,
          path: '/var/www/index.html',
        );

        final state = SftpState(
          currentPath: '/var/www',
          files: [dotItem, dotDotItem, folder, file],
        );

        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();

        // . must be hidden, .. must be shown
        expect(find.text('.'), findsNothing);
        expect(find.text('..'), findsOneWidget);
        expect(find.text('html'), findsOneWidget);
        expect(find.text('index.html'), findsOneWidget);
      });
    });
  });
}
