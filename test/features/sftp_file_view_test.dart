import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_toolbar.dart';
import 'package:valhalla/widgets/remote_browser_view.dart';
import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;

/// 视图模式持久化用例要让真实的 `SftpNotifier.build()` 跑起来，它会向
/// `sshClientManagerProvider` 要客户端；这里给一个永远不连接的空壳。
class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

/// 视图模式写盘失败的存储替身：磁盘满 / 偏好后端异常时的稳定复现方式。
class _FailingViewModeStorage extends LocalStorageService {
  _FailingViewModeStorage(super.prefs);

  @override
  Future<void> setFileViewMode(String value) async {
    throw const StorageException('SFTP_VIEW_PREFERENCE_SAVE_FAILED');
  }
}

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

  /// 非空时 [readFileContent] 返回它，用来构造「恢复出来的草稿内容」。
  String? readResult;

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
    return readResult ?? 'hello world from $path';
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

  /// 远端基线（快照内容）。真实实现由 `_editorSnapshot` 提供，这里没有继承
  /// 私有的内部状态，所以显式暴露，让用例自己决定「草稿 vs 远端基线」。
  String? editorBaselineContent;

  /// 按调用顺序记录草稿相关的编排，用来断言「flush 必须先于 close」。
  final List<String> draftCallOrder = [];

  final List<int?> updateDraftTokens = [];
  final List<int> flushTokens = [];
  final List<int?> discardTokens = [];
  final List<int?> closedTokens = [];

  /// 非空时 flush 会 await 这个闸门，用来测「Keep 必须等 flush 完成才出栈」。
  Completer<void>? flushGate;

  /// 非空时 flush 抛出它，用来测草稿写盘失败。
  Object? flushThrows;

  /// 非空时 discard 抛出它，用来测草稿删除失败。
  Object? discardThrows;

  _TestSftpNotifier(this._initial, [_FakeOperations? ops])
    : _ops = ops ?? _FakeOperations.empty();

  @override
  String? get editorOriginalContent => editorBaselineContent;

  @override
  void updateEditorDraft(String content, {int? editorToken}) {
    updateDraftTokens.add(editorToken);
    draftCallOrder.add('updateEditorDraft');
  }

  @override
  Future<void> flushEditorDraft({required int editorToken}) async {
    flushTokens.add(editorToken);
    draftCallOrder.add('flush');
    if (flushThrows != null) throw flushThrows!;
    if (flushGate != null) await flushGate!.future;
  }

  @override
  Future<void> discardEditorDraft({String? draftKey, int? editorToken}) async {
    discardTokens.add(editorToken);
    draftCallOrder.add('discard');
    if (discardThrows != null) throw discardThrows!;
  }

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

  void emit(SftpState next) => state = next;

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
  void closeFileEditor({int? editorToken}) {
    closedTokens.add(editorToken);
    draftCallOrder.add('close');
    state = state.copyWith(clearEditor: true, clearError: true);
  }

  @override
  Future<void> saveFileContent(
    String path,
    String content, {
    required int editorToken,
  }) async {
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

  void emit(ServerProfile next) => state = next;
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
  LocalStorageService? storage,
  _ActiveServerWithProfile? server,
}) {
  final operations = ops ?? _FakeOperations();
  final notif = notifier ?? _TestSftpNotifier(state, operations);
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage ?? _storage),
      activeServerProvider.overrideWith(
        () => server ?? _ActiveServerWithProfile(_kFileViewServer),
      ),
      sftpOperationsProvider.overrideWithValue(operations),
      sftpProvider.overrideWith(() => notif),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
    ],
    child: MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.light,
        seedColor: Colors.green,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SftpFileView()),
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
  String modified = '2026-09-16 12:00',
}) {
  return SftpFileItem(
    name: name,
    path: path ?? '/var/www/$name',
    isDirectory: isDirectory,
    sizeBytes: size,
    formattedSize: '$size B',
    permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
    modified: modified,
  );
}

Finder _fileMoreMenu(String name) => find.descendant(
  of: find.ancestor(
    of: find.text(name),
    matching: find.byType(RemoteBrowserEntryTile),
  ),
  matching: find.byIcon(Icons.more_vert),
);

void main() {
  setUpAll(() async {
    await loadRealTextFonts();
    final mono = FontLoader('JetBrains Mono')
      ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-400.ttf'));
    await mono.load();
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.init();
  });

  group('SftpFileView', () {
    for (final mode in SftpViewMode.values) {
      testWidgets(
        '$mode retains refresh scroll and isolates directory scroll',
        (tester) async {
          final initial = SftpState(
            currentPath: '/var/www',
            viewMode: mode,
            files: List.generate(100, (i) => _makeItem('file_$i.txt')),
          );
          final notifier = _TestSftpNotifier(initial);
          await tester.pumpWidget(
            _buildTestApp(state: initial, notifier: notifier),
          );
          await tester.pumpAndSettle();
          Finder listing() => mode == SftpViewMode.list
              ? find.byType(ListView)
              : find.byType(GridView);
          ScrollPosition position() => tester
              .state<ScrollableState>(
                find.descendant(
                  of: listing(),
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          position().jumpTo(600);
          await tester.pump();
          notifier.emit(initial.copyWith(isLoading: true));
          await tester.pump();
          expect(position().pixels, closeTo(600, 1));
          notifier.emit(initial);
          await tester.pumpAndSettle();
          expect(position().pixels, closeTo(600, 1));

          notifier.emit(initial.copyWith(currentPath: '/another'));
          await tester.pumpAndSettle();
          expect(position().pixels, 0);
          position().jumpTo(300);
          await tester.pump();
          notifier.emit(initial);
          await tester.pumpAndSettle();
          expect(position().pixels, closeTo(600, 1));
        },
      );
    }

    testWidgets(
      'selection survives refresh but not directory or target change',
      (tester) async {
        final initial = SftpState(
          currentPath: '/var/www',
          viewMode: SftpViewMode.list,
          files: [_makeItem('notes.txt')],
        );
        final notifier = _TestSftpNotifier(initial);
        final server = _ActiveServerWithProfile(_kFileViewServer);
        await tester.pumpWidget(
          _buildTestApp(state: initial, notifier: notifier, server: server),
        );
        await tester.pumpAndSettle();
        await tester.longPress(find.text('notes.txt'));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        notifier.emit(initial.copyWith(isLoading: true));
        await tester.pump();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        notifier.emit(initial.copyWith(currentPath: '/another'));
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsNothing);
        await tester.longPress(find.text('notes.txt'));
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsOneWidget);
        server.emit(_kFileViewServer.copyWith(host: '10.0.0.2'));
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsNothing);
      },
    );

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
        final firstMoreBtn = _fileMoreMenu(zipItem.name);
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
        final moreBtn = _fileMoreMenu(txtItem.name);
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
        await tester.tap(_fileMoreMenu(txtItem.name));
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

        notifier.emit(state.copyWith(transfers: []));
        await tester.pump();
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('sftpUploadButton')))
              .onPressed,
          isNotNull,
        );
        notifier.emit(state);
        await tester.pump();
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('sftpUploadButton')))
              .onPressed,
          isNull,
          reason: 'Transfer-only state changes must update the upload guard',
        );
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

    testWidgets('pinned sort menu changes sort key and direction', (
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

      expect(find.byKey(const Key('sftpMoreButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sftpSortButton')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.sftpSortName), findsOneWidget);
      expect(find.text(l10n.sftpSortSize), findsOneWidget);
      expect(find.text(l10n.sftpSortDate), findsOneWidget);
      expect(find.text(l10n.sftpSortAscending), findsOneWidget);
      expect(find.text(l10n.sftpSortDescending), findsOneWidget);

      final nameItem = tester.widget<CheckedPopupMenuItem<String>>(
        find.widgetWithText(CheckedPopupMenuItem<String>, l10n.sftpSortName),
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
        find.widgetWithText(CheckedPopupMenuItem<String>, l10n.sftpSortSize),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(1));
      expect(notifier.setSortCalls.first.key, SftpSortKey.size);
      expect(notifier.setSortCalls.first.ascending, isTrue);

      await tester.tap(find.byKey(const Key('sftpSortButton')));
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

      await tester.tap(find.byKey(const Key('sftpSortButton')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, l10n.sftpSortName),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(3));
      expect(notifier.setSortCalls.last.key, SftpSortKey.name);
      expect(notifier.setSortCalls.last.ascending, isFalse);

      await tester.tap(find.byKey(const Key('sftpSortButton')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, l10n.sftpSortName),
      );
      await tester.pumpAndSettle();

      expect(notifier.setSortCalls, hasLength(4));
      expect(notifier.setSortCalls.last.key, SftpSortKey.name);
      expect(notifier.setSortCalls.last.ascending, isTrue);

      await tester.tap(find.byKey(const Key('sftpSortButton')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, l10n.sftpSortName),
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
        await tester.tap(_fileMoreMenu(txtItem.name));
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

        await tester.tap(_fileMoreMenu(txtItem.name));
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

        await tester.tap(_fileMoreMenu(txtItem.name));
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

        await tester.tap(_fileMoreMenu(txtItem.name));
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

    group('View mode (list / grid)', () {
      /// 移动端宽度（< [LayoutBreakpoints.compactMax]）：没有持久化偏好时
      /// 列表优先。
      void useMobileSurface(WidgetTester tester) {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
      }

      testWidgets('mobile defaults to list and toggles to grid and back', (
        tester,
      ) async {
        useMobileSurface(tester);

        final storage = LocalStorageService(
          await SharedPreferences.getInstance(),
        );
        final state = SftpState(
          currentPath: '/var/www',
          files: [_makeItem('notes.txt')],
        );

        await tester.pumpWidget(_buildTestApp(state: state, storage: storage));
        await tester.pumpAndSettle();

        Finder fileListGrid = find.descendant(
          of: find.byType(SftpFileView),
          matching: find.byType(GridView),
        );
        Finder fileList = find.descendant(
          of: find.byType(SftpFileView),
          matching: find.byType(ListView),
        );

        // 没有偏好时：窄屏 = 列表。
        expect(state.viewMode, isNull);
        expect(fileListGrid, findsNothing);
        expect(fileList, findsWidgets);

        await tester.tap(find.byKey(const Key('sftpToggleViewModeButton')));
        await tester.pumpAndSettle();

        expect(fileListGrid, findsOneWidget);
        expect(storage.getFileViewMode(), 'grid');

        await tester.tap(find.byKey(const Key('sftpToggleViewModeButton')));
        await tester.pumpAndSettle();

        expect(fileListGrid, findsNothing);
        expect(fileList, findsWidgets);
        expect(storage.getFileViewMode(), 'list');
      });

      testWidgets('toggle button tooltip reflects the next action', (
        tester,
      ) async {
        useMobileSurface(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final state = SftpState(
          currentPath: '/var/www',
          files: [_makeItem('notes.txt')],
          viewMode: SftpViewMode.list,
        );

        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();

        final toggle = find.byKey(const Key('sftpToggleViewModeButton'));
        // 当前是列表 → 按钮提示「切到网格」。
        expect(
          tester.widget<IconButton>(toggle).tooltip,
          l10n.sftpViewModeGrid,
        );
        expect(
          find.descendant(of: toggle, matching: find.byIcon(Icons.grid_view)),
          findsOneWidget,
        );

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(
          tester.widget<IconButton>(toggle).tooltip,
          l10n.sftpViewModeList,
        );
        expect(
          find.descendant(of: toggle, matching: find.byIcon(Icons.view_list)),
          findsOneWidget,
        );
      });
    });

    group('Hidden file de-emphasis', () {
      ListTile tileOf(WidgetTester tester, String name) =>
          tester.widget<ListTile>(
            find
                .ancestor(of: find.text(name), matching: find.byType(ListTile))
                .first,
          );
      Icon leadingIcon(WidgetTester tester, ListTile tile) =>
          tester.widget<Icon>(
            find.descendant(
              of: find.byWidget(tile.leading!),
              matching: find.byType(Icon),
            ),
          );

      testWidgets('hidden title and icon are subdued, menu icon stays normal', (
        tester,
      ) async {
        final state = SftpState(
          currentPath: '/var/www',
          showHiddenFiles: true,
          files: [_makeItem('.env'), _makeItem('notes.txt')],
          viewMode: SftpViewMode.list,
        );

        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();

        final scheme = Theme.of(
          tester.element(find.byType(SftpFileView)),
        ).colorScheme;

        final hiddenTile = tileOf(tester, '.env');
        final hiddenIconColor = leadingIcon(tester, hiddenTile).color;
        final normalTile = tileOf(tester, 'notes.txt');

        expect(
          tester.widget<Text>(find.text('.env')).style?.color,
          scheme.onSurface.withValues(alpha: 0.62),
        );
        final hiddenTitleColor = tester
            .widget<Text>(find.text('.env'))
            .style
            ?.color;
        expect(
          hiddenIconColor,
          scheme.onSurface.withValues(alpha: 0.55),
          reason: '隐藏文件的图标应当被压暗',
        );

        // 可见文件保持默认（不压暗）。
        final normalTitleColor = tester
            .widget<Text>(find.text('notes.txt'))
            .style
            ?.color;
        expect(normalTitleColor, isNotNull);
        expect(
          normalTitleColor!.a,
          greaterThan(hiddenTitleColor!.a),
          reason: '可见文件标题不应被压暗',
        );
        expect(normalTitleColor, isNot(hiddenTitleColor));
        // 可见文件图标不指定颜色（走主题默认），隐藏文件才显式压暗。
        expect(leadingIcon(tester, normalTile).color, isNull);
        expect(hiddenIconColor!.a, lessThan(1.0));

        // 溢出菜单不受隐藏态影响。
        final hiddenMenu = tester.widget<Icon>(
          find.descendant(
            of: find.ancestor(
              of: find.text('.env'),
              matching: find.byType(ListTile),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        final normalMenu = tester.widget<Icon>(
          find.descendant(
            of: find.ancestor(
              of: find.text('notes.txt'),
              matching: find.byType(ListTile),
            ),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        expect(hiddenMenu.color, normalMenu.color);
        expect(hiddenMenu.color, isNull);
        final hiddenSize = find.descendant(
          of: find.byKey(const ValueKey('sftp_file_/var/www/.env')),
          matching: find.text('100 B'),
        );
        expect(hiddenSize, findsOneWidget);
        expect(
          tester.widget<Text>(hiddenSize).style?.color,
          scheme.onSurfaceVariant.withValues(alpha: 0.62),
        );
      });

      testWidgets(
        'hidden directory icon uses subdued primary and checkbox styling matches visible rows',
        (tester) async {
          final state = SftpState(
            currentPath: '/var/www',
            showHiddenFiles: true,
            viewMode: SftpViewMode.list,
            files: [
              _makeItem('.git', isDirectory: true),
              _makeItem('html', isDirectory: true),
            ],
          );

          await tester.pumpWidget(_buildTestApp(state: state));
          await tester.pumpAndSettle();

          final scheme = Theme.of(
            tester.element(find.byType(SftpFileView)),
          ).colorScheme;

          expect(
            leadingIcon(tester, tileOf(tester, '.git')).color,
            scheme.primary.withValues(alpha: 0.6),
          );
          expect(
            leadingIcon(tester, tileOf(tester, 'html')).color,
            scheme.primary,
          );

          // 进入多选：勾选框是交互控件，不应该跟着隐藏态一起变灰。
          await tester.longPress(find.text('.git'));
          await tester.pumpAndSettle();

          final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
          expect(checkboxes, hasLength(2));
          expect(checkboxes.first.activeColor, checkboxes.last.activeColor);
          expect(checkboxes.first.checkColor, checkboxes.last.checkColor);
          expect(checkboxes.first.fillColor, checkboxes.last.fillColor);
          expect(checkboxes.first.side, checkboxes.last.side);
        },
      );
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('shared file grid has two compact cards at $width dp', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = SftpState(
          currentPath: '/var/www',
          viewMode: SftpViewMode.grid,
          files: [
            _makeItem('alpha.txt'),
            _makeItem('beta.txt'),
            _makeItem('gamma.txt'),
          ],
        );
        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();
        expect(find.byType(RemoteBrowserToolbar), findsOneWidget);
        expect(find.byType(RemoteBrowserBreadcrumb), findsOneWidget);
        expect(find.byType(RemoteBrowserEntriesView), findsOneWidget);
        final alpha = find.byKey(
          const ValueKey('sftp_file_/var/www/alpha.txt'),
        );
        final beta = find.byKey(const ValueKey('sftp_file_/var/www/beta.txt'));
        expect(tester.getTopLeft(alpha).dy, tester.getTopLeft(beta).dy);
        expect(
          tester.getTopLeft(beta).dx,
          greaterThan(tester.getTopLeft(alpha).dx),
        );
        final alphaTitle = find.descendant(
          of: alpha,
          matching: find.text('alpha.txt'),
        );
        final alphaIcon = find.descendant(
          of: alpha,
          matching: find.byType(Icon),
        );
        expect(alphaIcon, findsWidgets);
        expect(
          tester.getTopLeft(alphaTitle).dy,
          closeTo(tester.getTopLeft(alphaIcon.first).dy, 6),
          reason: 'icon and title must share a row in the compact grid',
        );
        expect(
          tester.getTopLeft(alphaTitle).dx,
          greaterThan(tester.getTopLeft(alphaIcon.first).dx),
        );
        expect(tester.getSize(alpha).height, lessThan(120));
        expect(tester.getSize(alpha).height, greaterThan(80));
        expect(
          tester.getTopLeft(find.byKey(const Key('sftp_search_field'))).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('sftpToggleViewModeButton')))
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shared grid is one vertical card at 320dp and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = SftpState(
        currentPath: '/data/compose/test',
        viewMode: SftpViewMode.grid,
        files: [_makeItem('alpha.txt'), _makeItem('beta.txt')],
      );
      await tester.pumpWidget(_buildTestApp(state: state));
      await tester.pumpAndSettle();
      final alpha = find.byKey(const ValueKey('sftp_file_/var/www/alpha.txt'));
      final beta = find.byKey(const ValueKey('sftp_file_/var/www/beta.txt'));
      expect(tester.getTopLeft(alpha).dx, tester.getTopLeft(beta).dx);
      expect(
        tester.getTopLeft(beta).dy,
        greaterThan(tester.getTopLeft(alpha).dy),
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final name in ['a.txt', '${'long_' * 12}file.txt']) {
          testWidgets(
            'list filename and size stay inline at $width dp $scale x $name',
            (tester) async {
              tester.view.physicalSize = Size(width, 850);
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.reset);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await tester.pumpWidget(
                _buildTestApp(
                  state: SftpState(
                    currentPath: '/var/www',
                    viewMode: SftpViewMode.list,
                    files: [_makeItem(name)],
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final tile = find.byKey(ValueKey('sftp_file_/var/www/$name'));
              final size = find.descendant(
                of: tile,
                matching: find.text('100 B'),
              );
              expect(
                size,
                findsOneWidget,
                reason: 'file size must not repeat in subtitle',
              );
              final filenameBounds = tester.getRect(find.text(name));
              final sizeBounds = tester.getRect(size);
              final tileBounds = tester.getRect(tile);
              expect(sizeBounds.left - filenameBounds.right, closeTo(12, 0.5));
              expect(
                sizeBounds.center.dy,
                closeTo(filenameBounds.center.dy, 0.5),
              );
              expect(
                filenameBounds.left - tileBounds.left,
                closeTo(56, 0.5),
                reason: 'title moves 8dp nearer the icon, not the whole row',
              );
              expect(
                tileBounds.inflate(0.5).contains(sizeBounds.bottomRight),
                isTrue,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    for (final mode in [SftpViewMode.list, SftpViewMode.grid]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '${mode.name} paints complete date and minutes at 320dp ${scale}x',
          (tester) async {
            tester.view.physicalSize = const Size(320, 850);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final state = SftpState(
              currentPath: '/var/www',
              viewMode: mode,
              files: [_makeItem('alpha.txt', modified: '2026-09-16 09:45')],
            );
            await tester.pumpWidget(_buildTestApp(state: state));
            await tester.pumpAndSettle();
            final label = find.text('2026-09-16 09:45');
            expect(label, findsOneWidget);
            final horizontal = find.ancestor(
              of: label,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is SingleChildScrollView &&
                    widget.scrollDirection == Axis.horizontal,
              ),
            );
            if (horizontal.evaluate().isNotEmpty) {
              expect(mode, SftpViewMode.list);
              expect(
                scale,
                2.0,
                reason: 'normal text must show complete time without scrolling',
              );
              await tester.drag(horizontal, const Offset(-600, 0));
              await tester.pumpAndSettle();
            }
            final rich = find.descendant(
              of: label,
              matching: find.byType(RichText),
            );
            final paragraph = tester.renderObject<RenderParagraph>(rich);
            expect(paragraph.didExceedMaxLines, isFalse);
            if (mode == SftpViewMode.list) {
              final full = paragraph.getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 16),
              );
              expect(
                full.map((box) => box.top).toSet(),
                hasLength(1),
                reason: 'date and time must remain on the original single line',
              );
            }
            final boxes = paragraph.getBoxesForSelection(
              const TextSelection(baseOffset: 14, extentOffset: 16),
            );
            expect(
              boxes,
              isNotEmpty,
              reason: 'the final minute digits must be painted',
            );
            final tile = tester
                .getRect(
                  find.byKey(const ValueKey('sftp_file_/var/www/alpha.txt')),
                )
                .inflate(0.5);
            for (final box in boxes) {
              final bounds = box.toRect().shift(
                paragraph.localToGlobal(Offset.zero),
              );
              expect(
                tile.contains(bounds.topLeft),
                isTrue,
                reason:
                    'minute glyph bounds $bounds must be inside file tile $tile',
              );
              expect(
                tile.contains(bounds.bottomRight),
                isTrue,
                reason:
                    'minute glyph bounds $bounds must be inside file tile $tile',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'view toggle keeps the visible entry, not old per-view offset',
      (tester) async {
        tester.view.physicalSize = const Size(390, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = SftpState(
          currentPath: '/var/www',
          viewMode: SftpViewMode.list,
          files: List.generate(
            100,
            (i) => _makeItem('file_${i.toString().padLeft(3, '0')}.txt'),
          ),
        );
        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .jumpTo(
              12 +
                  20 *
                      tester
                          .widget<ListView>(
                            find.descendant(
                              of: find.byType(RemoteBrowserEntriesView),
                              matching: find.byType(ListView),
                            ),
                          )
                          .itemExtent!,
            );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sftpToggleViewModeButton')));
        await tester.pumpAndSettle();
        final anchor = find.byKey(
          const ValueKey('sftp_file_/var/www/file_020.txt'),
        );
        final viewport = tester.getRect(find.byType(RemoteBrowserEntriesView));
        expect(viewport.overlaps(tester.getRect(anchor)), isTrue);
        await tester.tap(find.byKey(const Key('sftpToggleViewModeButton')));
        await tester.pumpAndSettle();
        expect(viewport.overlaps(tester.getRect(anchor)), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '320dp grid selection keeps checkbox and hidden title readable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = SftpState(
          currentPath: '/var/www',
          viewMode: SftpViewMode.grid,
          showHiddenFiles: true,
          files: [_makeItem('.env'), _makeItem('notes.txt')],
        );
        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();
        final hidden = tester.widget<Text>(find.text('.env'));
        final normal = tester.widget<Text>(find.text('notes.txt'));
        expect(hidden.style!.color!.a, lessThan(normal.style!.color!.a));
        await tester.longPress(find.text('.env'));
        await tester.pumpAndSettle();
        expect(find.byType(Checkbox), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    group('Grid metadata assertions', () {
      testWidgets(
        'grid directory shows permissions drwxr-xr-x not Directory label',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final dirItem = _makeItem(
            'html',
            isDirectory: true,
            path: '/var/www/html',
          );
          final state = SftpState(
            currentPath: '/var/www',
            viewMode: SftpViewMode.grid,
            files: [dirItem],
          );
          await tester.pumpWidget(_buildTestApp(state: state));
          await tester.pumpAndSettle();
          final card = find.byKey(const ValueKey('sftp_file_/var/www/html'));
          // Directory metadata should show permissions string, not "Directory"
          final permissionsText = find.descendant(
            of: card,
            matching: find.text('drwxr-xr-x'),
          );
          expect(permissionsText, findsOneWidget);
          final directoryLabel = find.descendant(
            of: card,
            matching: find.text('Directory'),
          );
          expect(directoryLabel, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('grid ordinary file retains size in metadata', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fileItem = _makeItem(
          'notes.txt',
          size: 2048,
          path: '/var/www/notes.txt',
        );
        final state = SftpState(
          currentPath: '/var/www',
          viewMode: SftpViewMode.grid,
          files: [fileItem],
        );
        await tester.pumpWidget(_buildTestApp(state: state));
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('sftp_file_/var/www/notes.txt'));
        // File metadata should show formatted size
        final sizeText = find.descendant(
          of: card,
          matching: find.text('2048 B'),
        );
        expect(sizeText, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'grid long filename and size stay within bounds at narrow width 2x text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final longName = 'a' * 60 + '.txt';
          final fileItem = _makeItem(
            longName,
            size: 1024,
            path: '/var/www/$longName',
          );
          final state = SftpState(
            currentPath: '/var/www',
            viewMode: SftpViewMode.grid,
            files: [fileItem],
          );
          await tester.pumpWidget(_buildTestApp(state: state));
          await tester.pumpAndSettle();
          final card = find.byKey(ValueKey('sftp_file_/var/www/$longName'));
          expect(tester.getRect(card).width, lessThanOrEqualTo(320));
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('View mode persistence', () {
      late SharedPreferences prefs;

      setUp(() async {
        // 每个用例一套全新的偏好存储：视图模式是全局偏好，共享 mock
        // 会让上一个用例写入的值漏进下一个用例。
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      ProviderContainer containerFor(
        LocalStorageService storage, {
        _FakeOperations? ops,
      }) => ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(
            () => _ActiveServerWithProfile(_kFileViewServer),
          ),
          serverConnectionProvider.overrideWith(
            _TestServerConnectionNotifier.new,
          ),
          sftpOperationsProvider.overrideWithValue(
            ops ?? _FakeOperations.empty(),
          ),
        ],
      );

      test('setViewMode writes the pref and updates state', () async {
        final storage = LocalStorageService(prefs);
        final container = containerFor(storage);
        addTearDown(container.dispose);

        expect(container.read(sftpProvider).viewMode, isNull);

        await container
            .read(sftpProvider.notifier)
            .setViewMode(SftpViewMode.grid);

        expect(storage.getFileViewMode(), 'grid');
        expect(container.read(sftpProvider).viewMode, SftpViewMode.grid);
      });

      test(
        'build restores the persisted mode when the notifier rebuilds',
        () async {
          // 先写一个 grid 偏好，模拟上一次退出时留下的选择。
          await prefs.setString('valhalla_file_view_mode_v1', 'grid');
          final storage = LocalStorageService(prefs);
          final container = containerFor(storage);
          addTearDown(container.dispose);

          expect(container.read(sftpProvider).viewMode, SftpViewMode.grid);

          // 重建（切服务器 / 断线重连）后仍然读回同一个值。
          container.invalidate(sftpProvider);

          expect(container.read(sftpProvider).viewMode, SftpViewMode.grid);
        },
      );

      test(
        'unknown persisted value falls back to null (layout decides)',
        () async {
          await prefs.setString('valhalla_file_view_mode_v1', 'table');
          final storage = LocalStorageService(prefs);
          final container = containerFor(storage);
          addTearDown(container.dispose);

          expect(storage.getFileViewMode(), isNull);
          expect(container.read(sftpProvider).viewMode, isNull);
        },
      );

      test(
        'failed write keeps the current mode and surfaces an error code',
        () async {
          final storage = _FailingViewModeStorage(prefs);
          final container = containerFor(storage);
          addTearDown(container.dispose);

          await container
              .read(sftpProvider.notifier)
              .setViewMode(SftpViewMode.grid);

          final state = container.read(sftpProvider);
          expect(state.viewMode, isNull, reason: '写失败不应该假装切换成功');
          expect(state.errorMessage, 'SFTP_VIEW_PREFERENCE_SAVE_FAILED');
        },
      );

      testWidgets(
        'failed write shows the localized snackbar and keeps the list',
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final state = SftpState(
            currentPath: '/var/www',
            files: [_makeItem('notes.txt')],
          );

          await tester.pumpWidget(
            _buildTestApp(
              state: state,
              storage: _FailingViewModeStorage(prefs),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('sftpToggleViewModeButton')));
          await tester.pumpAndSettle();

          expect(find.text(l10n.sftpViewPreferenceSaveFailed), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(SftpFileView),
              matching: find.byType(GridView),
            ),
            findsNothing,
          );
        },
      );
    });

    /// 编辑器退出确认（Save / Keep / Discard）的生产回归。
    ///
    /// 覆盖的合法需求：
    /// - 恢复出来的草稿与远端基线不同即视为未保存，退出必须给出三种选择；
    /// - Keep Draft 必须等队列里的加密写盘 flush 完成后才关闭并出栈；
    /// - flush / discard 失败时保留输入、给出错误与复制入口，不静默出栈、
    ///   也不 reopen 把没删掉的草稿重新读回来；
    /// - 连点退出只允许出现一个确认框（守卫在取消后释放）。
    group('Editor exit confirmation', () {
      const draftText = 'restored draft body';
      const baselineText = 'remote baseline body';

      Finder actionInExitDialog(String label) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(label),
      );

      /// 打开一个「恢复了草稿」的编辑器：编辑框里是草稿，远端基线是快照内容，
      /// 两者不同，所以初始即为 dirty。
      Future<_TestSftpNotifier> openRestoredDraftEditor(
        WidgetTester tester, {
        Object? flushThrows,
        Object? discardThrows,
        Completer<void>? flushGate,
      }) async {
        final item = _makeItem('draft.txt');
        final state = SftpState(currentPath: '/var/www', files: [item]);
        final notifier = _TestSftpNotifier(
          state,
          _FakeOperations()..readResult = draftText,
        )..editorBaselineContent = baselineText;
        notifier.flushThrows = flushThrows;
        notifier.flushGate = flushGate;
        notifier.discardThrows = discardThrows;

        await tester.pumpWidget(
          _buildTestApp(state: state, notifier: notifier),
        );
        await tester.pump();

        await tester.tap(find.text('draft.txt'));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsOneWidget);
        return notifier;
      }

      /// 推进帧与 microtask。
      ///
      /// 这里不能用 `pumpAndSettle`：busy 态下 AppBar 的保存按钮是不定进度条，
      /// 会持续排帧，settle 永远等不到稳定帧；flush 闸门没放开时也一样。
      Future<void> settleEditorFrames(WidgetTester tester) async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 50));
      }

      Future<void> requestEditorExit(WidgetTester tester) async {
        await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
        await settleEditorFrames(tester);
      }

      /// 剪贴板替身：返回捕获到的 setData 文本，验证失败路径仍能复制草稿。
      List<String?> stubClipboard() {
        final copied = <String?>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add((call.arguments as Map)['text'] as String?);
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        return copied;
      }

      String editorTextFieldText(WidgetTester tester) => tester
          .widget<TextField>(find.byKey(const Key('sftp_editor_text_field')))
          .controller!
          .text;

      testWidgets(
        'restored draft differing from the remote baseline asks Save / Keep / '
        'Discard on exit without side effects',
        (tester) async {
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final notifier = await openRestoredDraftEditor(tester);

          await requestEditorExit(tester);

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            actionInExitDialog(l10n.fileEditorUnsavedTitle),
            findsOneWidget,
          );
          expect(
            actionInExitDialog(l10n.fileEditorUnsavedMessage),
            findsOneWidget,
          );
          // 三个出口动作必须同时提供，缺一个就是合法需求被削弱。
          expect(actionInExitDialog(l10n.fileEditorSave), findsOneWidget);
          expect(actionInExitDialog(l10n.fileEditorKeepDraft), findsOneWidget);
          expect(actionInExitDialog(l10n.fileEditorDiscard), findsOneWidget);

          // 只是询问：此时不能关闭编辑器、不能 flush、不能删草稿。
          expect(notifier.draftCallOrder, isEmpty);
          expect(notifier.closedTokens, isEmpty);
        },
      );

      testWidgets(
        'Keep Draft awaits the queued flush before the editor route pops',
        (tester) async {
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final flushGate = Completer<void>();
          final notifier = await openRestoredDraftEditor(
            tester,
            flushGate: flushGate,
          );
          final capturedToken = notifier.editorToken;

          await requestEditorExit(tester);
          await tester.tap(actionInExitDialog(l10n.fileEditorKeepDraft));
          await settleEditorFrames(tester);

          // flush 还没完成：编辑器必须留在栈上，也不允许提前 closeFileEditor。
          expect(find.byType(Dialog), findsOneWidget);
          expect(notifier.draftCallOrder, ['updateEditorDraft', 'flush']);
          expect(notifier.updateDraftTokens, [capturedToken]);
          expect(notifier.flushTokens, [capturedToken]);
          expect(notifier.closedTokens, isEmpty);

          flushGate.complete();
          await settleEditorFrames(tester);

          // flush 落地后才关闭编辑器并出栈。
          expect(notifier.draftCallOrder, [
            'updateEditorDraft',
            'flush',
            'close',
          ]);
          expect(notifier.closedTokens, [capturedToken]);
          expect(find.byType(Dialog), findsNothing);
        },
      );

      testWidgets(
        'flush failure keeps the draft text and offers a copy action instead of '
        'popping the editor',
        (tester) async {
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final copied = stubClipboard();
          final notifier = await openRestoredDraftEditor(
            tester,
            flushThrows: const SFTPException('SFTP_DRAFT_SAVE_FAILED'),
          );

          await requestEditorExit(tester);
          await tester.tap(actionInExitDialog(l10n.fileEditorKeepDraft));
          await settleEditorFrames(tester);

          // 草稿写盘失败：输入保留、编辑器不关、错误可见。
          expect(find.byType(Dialog), findsOneWidget);
          expect(editorTextFieldText(tester), draftText);
          expect(notifier.closedTokens, isEmpty);
          expect(
            find.byKey(const Key('sftp_editor_error_banner')),
            findsOneWidget,
          );
          expect(find.text(l10n.sftpDraftSaveFailed), findsWidgets);

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.action, isNotNull);
          expect(snackBar.action!.label, l10n.fileEditorCopyDraft);

          // 行内错误横幅里也有一个同标签的 Copy Draft，所以必须点到
          // SnackBar 自己那个 action 上，否则 finder 会同时命中两处。
          await tester.tap(
            find.descendant(
              of: find.byType(SnackBarAction),
              matching: find.text(l10n.fileEditorCopyDraft),
            ),
          );
          await settleEditorFrames(tester);

          expect(copied, [draftText]);
          expect(find.text(l10n.fileEditorDraftCopied), findsOneWidget);
        },
      );

      testWidgets(
        'discard failure keeps the draft in the editor with copy/retry instead '
        'of reopening the undeleted draft',
        (tester) async {
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final copied = stubClipboard();
          final notifier = await openRestoredDraftEditor(
            tester,
            discardThrows: const SFTPException('SFTP_DRAFT_SAVE_FAILED'),
          );
          final capturedToken = notifier.editorToken;

          await requestEditorExit(tester);
          await tester.tap(actionInExitDialog(l10n.fileEditorDiscard));
          await settleEditorFrames(tester);

          // 草稿删除失败不能顺手出栈/reopen，否则会把没删掉的草稿又读回来。
          expect(notifier.discardTokens, [capturedToken]);
          expect(notifier.closedTokens, isEmpty);
          expect(find.byType(Dialog), findsOneWidget);
          expect(editorTextFieldText(tester), draftText);
          expect(
            find.byKey(const Key('sftp_editor_error_banner')),
            findsOneWidget,
          );
          expect(find.text(l10n.sftpDraftSaveFailed), findsWidgets);

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.action, isNotNull);
          expect(snackBar.action!.label, l10n.fileEditorCopyDraft);

          // 同 test 1：只点 SnackBar 里的 action，不要命中行内横幅的按钮。
          await tester.tap(
            find.descendant(
              of: find.byType(SnackBarAction),
              matching: find.text(l10n.fileEditorCopyDraft),
            ),
          );
          await settleEditorFrames(tester);

          expect(copied, [draftText]);
          expect(find.text(l10n.fileEditorDraftCopied), findsOneWidget);
        },
      );

      testWidgets(
        'repeated exits before the confirmation show exactly one dialog and '
        'release the guard on cancel',
        (tester) async {
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final notifier = await openRestoredDraftEditor(tester);

          final closeButton = find.widgetWithIcon(IconButton, Icons.close);
          final onExit = tester.widget<IconButton>(closeButton).onPressed!;

          // 在确认框出现之前连点两次退出：只允许一个确认框叠加上来。
          onExit();
          onExit();
          await settleEditorFrames(tester);

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            actionInExitDialog(l10n.fileEditorUnsavedTitle),
            findsOneWidget,
          );
          expect(notifier.draftCallOrder, isEmpty);

          // 取消（点遮罩）之后守卫必须释放，否则用户再也退不出编辑器。
          await tester.tapAt(const Offset(4, 4));
          await settleEditorFrames(tester);

          expect(find.byType(AlertDialog), findsNothing);
          expect(notifier.draftCallOrder, isEmpty);

          await requestEditorExit(tester);

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            actionInExitDialog(l10n.fileEditorUnsavedTitle),
            findsOneWidget,
          );
        },
      );
    });
  });
}
