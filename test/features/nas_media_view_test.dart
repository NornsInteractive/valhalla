import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/nas_metadata_provider.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';
import 'package:valhalla/core/services/nas_metadata_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/nas/nas_media_view.dart';
import 'package:valhalla/features/nas/widgets/nas_downloads_sheet.dart';
import 'package:valhalla/features/nas/widgets/nas_full_player_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_image_viewer_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_library_settings_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_localizations.dart';
import 'package:valhalla/features/nas/widgets/nas_scan_config_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_source_dialog.dart';
import 'package:valhalla/features/shell/main_shell.dart';
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
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int)? onProgress,
  }) async => _FakeTransferHandle();
  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int)? onProgress,
  }) async => _FakeTransferHandle();
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

class _FakeNasNotifier extends NasNotifier {
  final NasState _initialState;
  NasScanConfig? savedConfig;
  NasMediaKind? updatedFilter;
  String? updatedSearch;
  bool? updatedFavoritesOnly;
  String? scopedFolder;
  String? scopedArtist;
  String? scopedAlbum;
  String? scopedPlaylistId;
  bool scanCalled = false;
  bool cancelScanCalled = false;
  NasMediaItem? openedItem;
  NasMediaItem? inAppOpenedItem;
  NasMediaItem? externalOpenedItem;
  NasMediaItem? downloadedItem;
  NasMediaItem? favoritedItem;
  bool? favoritedValue;
  bool loadMoreCalled = false;
  bool loadPreviousCalled = false;
  String? createdPlaylistName;
  String? deletedPlaylistId;
  String? renamedPlaylistId;
  String? renamedPlaylistName;
  NasMediaItem? removedFromPlaylistItem;
  String? removedFromPlaylistId;
  NasMediaItem? movedPlaylistItem;
  int? movedPlaylistIndex;
  Uri? releasedUri;
  final Uri lastImageUrl = Uri.parse('http://127.0.0.1:8080/relay/sample.jpg');

  _FakeNasNotifier(this._initialState);

  @override
  NasState build() => _initialState;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveConfig(NasScanConfig config) async {
    savedConfig = config;
    state = state.copyWith(config: config);
  }

  @override
  Future<void> setFilter(NasMediaKind? value) async {
    updatedFilter = value;
    state = state.copyWith(filter: value, clearFilter: value == null);
  }

  @override
  Future<void> setSearch(String value) async {
    updatedSearch = value;
    state = state.copyWith(search: value);
  }

  @override
  Future<void> setFavoritesOnly(bool value) async {
    updatedFavoritesOnly = value;
    state = state.copyWith(favoritesOnly: value);
  }

  Map<String, List<NasMediaItem>>? itemsForScope;

  @override
  Future<void> setScope({
    String? folder,
    String? artist,
    String? album,
    String? playlistId,
  }) async {
    scopedFolder = folder;
    scopedArtist = artist;
    scopedAlbum = album;
    scopedPlaylistId = playlistId;
    final scopedKey = folder ?? artist ?? album ?? playlistId;
    final scopedItems = itemsForScope != null
        ? (scopedKey != null
              ? itemsForScope![scopedKey]
              : itemsForScope!['__root__'])
        : null;
    state = state
        .copyWith(clearScope: true)
        .copyWith(
          folder: folder,
          artist: artist,
          album: album,
          playlistId: playlistId,
          items: scopedItems ?? state.items,
        );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalled = true;
  }

  @override
  Future<void> loadPrevious() async {
    loadPreviousCalled = true;
  }

  List<NasIndexGroupCount>? customGroups;
  String? lastGroupsAfter;
  int groupsCalledCount = 0;

  @override
  Future<List<NasIndexGroupCount>> groups(
    NasIndexGroup group, {
    String? after,
  }) async {
    groupsCalledCount++;
    lastGroupsAfter = after;
    if (customGroups != null) return customGroups!;
    return const [
      NasIndexGroupCount('Rock', 12),
      NasIndexGroupCount('Jazz', 8),
    ];
  }

  @override
  Future<void> scan() async {
    scanCalled = true;
    state = state.copyWith(isScanning: true);
  }

  @override
  void cancelScan() {
    cancelScanCalled = true;
    state = state.copyWith(isScanning: false, errorCode: 'NAS_SCAN_CANCELLED');
  }

  @override
  Future<void> openMedia(NasMediaItem item) async {
    openedItem = item;
    final policy = ref
        .read(localStorageServiceProvider)
        .getNasOpenPolicy(item.kind);
    if (policy == NasOpenPolicy.askEveryTime) {
      throw StateError('NAS_OPEN_CHOICE_REQUIRED');
    }
    if (policy == NasOpenPolicy.external) {
      openExternal(item);
    } else {
      await openInApp(item);
    }
  }

  @override
  Future<void> openInApp(NasMediaItem item) async {
    inAppOpenedItem = item;
    openedItem = item;
  }

  @override
  String openExternal(NasMediaItem item) {
    externalOpenedItem = item;
    openedItem = item;
    return 'task-ext-${item.name}';
  }

  @override
  String download(NasMediaItem item) {
    downloadedItem = item;
    return 'task-dl-${item.name}';
  }

  int setFavoriteCallCount = 0;
  bool shouldFailFavorite = false;

  @override
  Future<void> setFavorite(NasMediaItem item, bool value) async {
    setFavoriteCallCount++;
    if (shouldFailFavorite) {
      throw Exception('REMOTE_SOURCE_UNREACHABLE');
    }
    favoritedItem = item;
    favoritedValue = value;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          e.path == item.path ? e.copyWith(isFavorite: value) : e,
      ],
    );
  }

  @override
  Future<String?> thumbnailPath(NasMediaItem item) async => null;

  @override
  Future<Uri> imageUrl(NasMediaItem item) async => lastImageUrl;

  @override
  void releaseImageUrl(Uri uri) {
    releasedUri = uri;
  }

  @override
  Future<void> createPlaylist(String name) async {
    createdPlaylistName = name;
  }

  @override
  Future<void> renamePlaylist(String playlistId, String name) async {
    renamedPlaylistId = playlistId;
    renamedPlaylistName = name;
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    deletedPlaylistId = playlistId;
  }

  @override
  Future<void> addToPlaylist({
    required String playlistId,
    required NasMediaItem item,
    int? position,
  }) async {}

  @override
  Future<void> removeFromPlaylist(String playlistId, NasMediaItem item) async {
    removedFromPlaylistId = playlistId;
    removedFromPlaylistItem = item;
  }

  @override
  Future<void> movePlaylistItem(
    String playlistId,
    NasMediaItem item,
    int index,
  ) async {
    removedFromPlaylistId = playlistId;
    movedPlaylistItem = item;
    movedPlaylistIndex = index;
  }
}

class _TestNasSourcesNotifier extends NasSourcesNotifier {
  final NasSourcesState _initial;
  NasSource? probedSource;
  NasCredentials? probedCredentials;
  bool? probedKeepEmptySecrets;
  bool probeCalled = false;

  _TestNasSourcesNotifier([NasSourcesState? initial])
    : _initial =
          initial ??
          const NasSourcesState(
            sources: [
              NasSource(
                id: 'src-nas',
                name: 'Home NAS',
                type: NasSourceType.sftp,
                endpoint: '192.168.1.50',
              ),
            ],
            selectedId: 'src-nas',
          );

  @override
  NasSourcesState build() => _initial;

  @override
  Future<void> select(String id) async {
    state = NasSourcesState(sources: state.sources, selectedId: id);
  }

  @override
  Future<void> probe(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
  }) async {
    probeCalled = true;
    probedSource = source;
    probedCredentials = credentials;
    probedKeepEmptySecrets = keepEmptySecrets;
  }

  NasSource? savedSource;
  NasCredentials? savedCredentials;
  bool? savedProbe;
  bool? savedKeepEmptySecrets;

  @override
  Future<void> save(
    NasSource source,
    NasCredentials credentials, {
    bool probe = true,
    bool keepEmptySecrets = false,
  }) async {
    savedSource = source;
    savedCredentials = credentials;
    savedProbe = probe;
    savedKeepEmptySecrets = keepEmptySecrets;
  }
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier(this._server);

  @override
  ServerProfile? build() => _server;
}

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier([this._servers = const []]);

  @override
  List<ServerProfile> build() => _servers;
}

class _FakeDownloadService extends NasDownloadService {
  String? openedTaskId;
  String? retriedTaskId;
  String? cancelledTaskId;

  _FakeDownloadService() : super((_) => Completer<NasSourceAdapter>().future);

  @override
  Future<void> open(String id) async {
    openedTaskId = id;
  }

  @override
  Future<void> retry(String id) async {
    retriedTaskId = id;
  }

  @override
  void cancel(String id) {
    cancelledTaskId = id;
  }
}

void main() {
  final testServer = ServerProfile(
    id: 'srv-nas',
    name: 'Home NAS Server',
    host: '192.168.1.50',
    port: 22,
    username: 'nasuser',
    authType: AuthType.password,
  );

  late LocalStorageService defaultStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    defaultStorage = LocalStorageService(prefs);
  });

  Widget createNasApp({
    required _FakeNasNotifier notifier,
    _TestNasSourcesNotifier? sourcesNotifier,
    Locale locale = const Locale('zh'),
    LocalStorageService? storage,
    NasPlayerSnapshot? playbackSnapshot,
    List<NasDownloadTask>? downloads,
    NasDownloadService? downloadService,
    NasMetadataProgress? metadataProgress,
    List<ServerProfile>? servers,
    Widget? home,
  }) {
    final effectiveStorage = storage ?? defaultStorage;
    final effectiveDownloadService = downloadService ?? _FakeDownloadService();
    return ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(
          () => _TestActiveServerNotifier(testServer),
        ),
        serverListProvider.overrideWith(
          () => _TestServerListNotifier(servers ?? [testServer]),
        ),
        sftpOperationsProvider.overrideWithValue(_FakeOperations()),
        localStorageServiceProvider.overrideWithValue(effectiveStorage),
        nasSourcesProvider.overrideWith(
          () => sourcesNotifier ?? _TestNasSourcesNotifier(),
        ),
        nasProvider.overrideWith(() => notifier),
        nasPlaybackProvider.overrideWith(
          (ref) => Stream.value(playbackSnapshot ?? const NasPlayerSnapshot()),
        ),
        nasDownloadsProvider.overrideWith(
          (ref) => Stream.value(downloads ?? const []),
        ),
        nasDownloadServiceProvider.overrideWithValue(effectiveDownloadService),
        if (metadataProgress != null)
          nasMetadataProgressProvider.overrideWith(
            (ref) => Stream.value(metadataProgress),
          ),
        nasVideoControllerProvider.overrideWith(
          (ref) => Future.error('TEST_NO_VIDEO_CONTROLLER'),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home ?? const Scaffold(body: NasMediaView()),
      ),
    );
  }

  group('NasMediaView Empty & Config States', () {
    testWidgets('shows empty sources state when no sources are configured', (
      tester,
    ) async {
      final notifier = _FakeNasNotifier(const NasState());
      final emptySources = _TestNasSourcesNotifier(
        const NasSourcesState(sources: [], selectedId: null),
      );

      await tester.pumpWidget(
        createNasApp(notifier: notifier, sourcesNotifier: emptySources),
      );
      await tester.pumpAndSettle();

      expect(find.text('未配置媒体源'), findsOneWidget);
      expect(
        find.byKey(const Key('nas_empty_sources_add_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('nas_empty_sources_add_button')));
      await tester.pumpAndSettle();

      expect(find.byType(NasSourceDialog), findsOneWidget);
    });

    testWidgets(
      'shows empty configuration guidance and opens scan config dialog',
      (tester) async {
        final notifier = _FakeNasNotifier(
          const NasState(
            serverId: 'src-nas',
            config: NasScanConfig(includePaths: []),
          ),
        );

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Empty config guidance title and button
        expect(find.text('未配置扫描目录'), findsOneWidget);
        final configBtn = find.byKey(const Key('nas_empty_config_button'));
        expect(configBtn, findsOneWidget);

        // Tap configure button
        await tester.tap(configBtn);
        await tester.pumpAndSettle();

        expect(find.byType(NasScanConfigDialog), findsOneWidget);
        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);
      },
    );

    testWidgets(
      'config dialog displays scope badge, excluded badge, and deletes path',
      (tester) async {
        final notifier = _FakeNasNotifier(
          const NasState(
            serverId: 'src-nas',
            config: NasScanConfig(
              includePaths: ['/mnt/media'],
              excludePaths: ['/mnt/media/cache'],
            ),
          ),
        );

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Tap top bar config button
        await tester.tap(find.byKey(const Key('nas_config_button')));
        await tester.pumpAndSettle();

        expect(find.byType(NasScanConfigDialog), findsOneWidget);

        // Identifiers: Scan Scope and Excluded badges
        expect(find.text('扫描范围'), findsOneWidget);
        expect(find.text('已排除'), findsOneWidget);
        expect(find.text('/mnt/media'), findsOneWidget);
        expect(find.text('/mnt/media/cache'), findsOneWidget);

        // Delete exclude path
        final deleteExc = find.byKey(
          const Key('delete_exclude_path_/mnt/media/cache'),
        );
        expect(deleteExc, findsOneWidget);
        await tester.tap(deleteExc);
        await tester.pumpAndSettle();

        expect(find.text('/mnt/media/cache'), findsNothing);

        // Save
        await tester.tap(find.byKey(const Key('nas_config_save_button')));
        await tester.pumpAndSettle();

        expect(notifier.savedConfig, isNotNull);
        expect(notifier.savedConfig!.includePaths, ['/mnt/media']);
        expect(notifier.savedConfig!.excludePaths, isEmpty);
      },
    );
  });

  group('NasMediaView Category Filters & Media Rendering', () {
    final sampleImage = const NasMediaItem(
      serverId: 'src-nas',
      path: '/mnt/media/photos/sample.jpg',
      kind: NasMediaKind.image,
      sizeBytes: 1024 * 1024,
      modifiedEpoch: 1700000000,
    );

    final sampleVideo = const NasMediaItem(
      serverId: 'src-nas',
      path: '/mnt/media/videos/movie.mp4',
      kind: NasMediaKind.video,
      sizeBytes: 50 * 1024 * 1024,
      modifiedEpoch: 1700000000,
    );

    testWidgets('switches media category filters and renders grid / list', (
      tester,
    ) async {
      final notifier = _FakeNasNotifier(
        NasState(
          serverId: 'src-nas',
          config: const NasScanConfig(includePaths: ['/mnt/media']),
          items: [sampleImage, sampleVideo],
          filter: null, // All
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Home view shows sample.jpg and movie.mp4
      expect(find.text('sample.jpg'), findsOneWidget);
      expect(find.text('movie.mp4'), findsOneWidget);

      // Switch to Photos Tab
      await tester.tap(
        find.byKey(const Key('nas_tab_photos')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(notifier.updatedFilter, NasMediaKind.image);

      notifier.state = notifier.state.copyWith(
        filter: NasMediaKind.image,
        items: [sampleImage],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nas_image_grid')), findsOneWidget);
      expect(find.text('sample.jpg'), findsOneWidget);
      expect(find.text('movie.mp4'), findsNothing);

      // Switch to Videos Tab
      await tester.tap(
        find.byKey(const Key('nas_tab_videos')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(notifier.updatedFilter, NasMediaKind.video);

      notifier.state = notifier.state.copyWith(
        filter: NasMediaKind.video,
        items: [sampleVideo],
      );
      await tester.pumpAndSettle();

      expect(find.text('movie.mp4'), findsOneWidget);
    });

    testWidgets('tapping media item calls openMedia', (tester) async {
      final notifier = _FakeNasNotifier(
        NasState(
          serverId: 'src-nas',
          config: const NasScanConfig(includePaths: ['/mnt/media']),
          items: [sampleVideo],
          filter: NasMediaKind.video,
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('nas_item_movie.mp4'));
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(notifier.openedItem, isNotNull);
      expect(notifier.openedItem!.name, 'movie.mp4');
    });
  });

  group('NasMediaView Scanning & Empty Index States', () {
    testWidgets('shows progress indicator and allows cancelling ongoing scan', (
      tester,
    ) async {
      final notifier = _FakeNasNotifier(
        const NasState(
          serverId: 'src-nas',
          config: NasScanConfig(includePaths: ['/mnt/media']),
          isScanning: true,
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('nas_scanning_indicator')), findsOneWidget);
      final cancelBtn = find.byKey(const Key('nas_cancel_scan_button'));
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.cancelScanCalled, isTrue);
    });

    testWidgets('shows empty index prompt and allows scanning', (tester) async {
      final notifier = _FakeNasNotifier(
        const NasState(
          serverId: 'src-nas',
          config: NasScanConfig(includePaths: ['/mnt/media']),
          items: [],
          isScanning: false,
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('媒体库暂无索引'), findsOneWidget);
      final scanBtn = find.byKey(const Key('nas_empty_scan_button'));
      expect(scanBtn, findsOneWidget);

      await tester.tap(scanBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.scanCalled, isTrue);
    });
  });

  group('NasMediaView Item Operations & AskEveryTime Policy Tests', () {
    const sampleVideo = NasMediaItem(
      serverId: 'src-nas',
      path: '/mnt/media/videos/movie.mp4',
      kind: NasMediaKind.video,
      sizeBytes: 50 * 1024 * 1024,
      modifiedEpoch: 1700000000,
    );

    const samplePhoto = NasMediaItem(
      serverId: 'src-nas',
      path: '/mnt/media/photos/sample.jpg',
      kind: NasMediaKind.image,
      sizeBytes: 2 * 1024 * 1024,
      modifiedEpoch: 1700000000,
    );

    testWidgets('tapping favorite button calls setFavorite on notifier', (
      tester,
    ) async {
      final notifier = _FakeNasNotifier(
        NasState(
          serverId: 'src-nas',
          config: const NasScanConfig(includePaths: ['/mnt/media']),
          items: const [sampleVideo],
          filter: NasMediaKind.video,
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();

      final favBtn = find.descendant(
        of: find.byKey(const Key('nas_item_movie.mp4')),
        matching: find.byIcon(Icons.favorite_border),
      );
      expect(favBtn, findsOneWidget);

      await tester.tap(favBtn);
      await tester.pump();

      expect(notifier.favoritedItem, isNotNull);
      expect(notifier.favoritedItem!.name, 'movie.mp4');
      expect(notifier.favoritedValue, isTrue);
    });

    testWidgets(
      'tapping media item when policy is askEveryTime shows sheet and in-app proceeds',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        await storage.saveNasOpenPolicy(
          NasMediaKind.video,
          NasOpenPolicy.askEveryTime,
        );

        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [sampleVideo],
            filter: NasMediaKind.video,
          ),
        );

        await tester.pumpWidget(
          createNasApp(notifier: notifier, storage: storage),
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const Key('nas_item_movie.mp4'));
        await tester.tap(tile);
        await tester.pumpAndSettle();

        // Choice sheet is presented
        expect(find.byKey(const Key('nas_ask_sheet_in_app')), findsOneWidget);
        expect(find.byKey(const Key('nas_ask_sheet_external')), findsOneWidget);

        // Tap in-app choice
        await tester.tap(find.byKey(const Key('nas_ask_sheet_in_app')));
        await tester.pumpAndSettle();

        // In-app opening triggered
        expect(notifier.inAppOpenedItem, isNotNull);
        expect(notifier.inAppOpenedItem!.name, 'movie.mp4');
      },
    );

    testWidgets(
      'image viewer dialog loads original relay image and releases URL on exit',
      (tester) async {
        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [samplePhoto],
            filter: NasMediaKind.image,
          ),
        );

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Switch to Photos tab
        await tester.tap(
          find.byKey(const Key('nas_tab_photos')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const Key('nas_item_sample.jpg'));
        expect(tile, findsOneWidget);

        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(find.byType(NasImageViewerDialog), findsOneWidget);

        // Close image viewer
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(NasImageViewerDialog), findsNothing);
        expect(notifier.releasedUri, isNotNull);
      },
    );

    testWidgets('pagination controls trigger loadMore and loadPrevious', (
      tester,
    ) async {
      final notifier = _FakeNasNotifier(
        NasState(
          serverId: 'src-nas',
          config: const NasScanConfig(includePaths: ['/mnt/media']),
          items: [sampleVideo],
          hasMore: true,
          hasPrevious: true,
          matchingCount: 400,
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('nas_tab_videos')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final nextBtn = find.byKey(const Key('nas_next_page_button'));
      final prevBtn = find.byKey(const Key('nas_previous_page_button'));

      expect(nextBtn, findsOneWidget);
      expect(prevBtn, findsOneWidget);

      await tester.tap(nextBtn);
      await tester.pump();
      expect(notifier.loadMoreCalled, isTrue);

      await tester.tap(prevBtn);
      await tester.pump();
      expect(notifier.loadPreviousCalled, isTrue);
    });

    testWidgets('playlist detail surface renders and allows removing items', (
      tester,
    ) async {
      final playlist = NasPlaylist(
        id: 'pl-1',
        serverId: 'src-nas',
        name: 'My Playlist',
        itemCount: 1,
        createdAt: DateTime.now(),
      );

      final notifier = _FakeNasNotifier(
        NasState(
          serverId: 'src-nas',
          config: const NasScanConfig(includePaths: ['/mnt/media']),
          playlists: [playlist],
          playlistId: 'pl-1',
          items: [sampleVideo],
        ),
      );

      await tester.pumpWidget(createNasApp(notifier: notifier));
      await tester.pumpAndSettle();

      // Playlist Detail Surface is active
      expect(
        find.byKey(const Key('nas_playlist_detail_surface')),
        findsOneWidget,
      );
      expect(find.text('My Playlist'), findsWidgets);

      // Remove item button
      final removeBtn = find.byKey(
        const Key('nas_playlist_remove_item_movie.mp4'),
      );
      expect(removeBtn, findsOneWidget);

      await tester.tap(removeBtn);
      await tester.pump();

      expect(notifier.removedFromPlaylistId, 'pl-1');
      expect(notifier.removedFromPlaylistItem?.name, 'movie.mp4');
    });

    testWidgets(
      'NasSourceDialog shows SSH tunnel option for WebDAV/Jellyfin and performs read-only probe',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sourcesNotifier = _TestNasSourcesNotifier();
        final notifier = _FakeNasNotifier(const NasState());

        final sampleSource = NasSource(
          id: 'src-webdav',
          name: 'My WebDAV',
          type: NasSourceType.webdav,
          endpoint: 'http://127.0.0.1:8080',
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            sourcesNotifier: sourcesNotifier,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () =>
                      NasSourceDialog.show(ctx, source: sampleSource),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(NasSourceDialog), findsOneWidget);

        // SSH Tunnel switch should be visible for WebDAV
        final tunnelSwitch = find.byKey(
          const Key('nas_source_ssh_tunnel_switch'),
        );
        expect(tunnelSwitch, findsOneWidget);

        // Turn on SSH tunnel
        await tester.tap(tunnelSwitch);
        await tester.pumpAndSettle();

        // SSH server selector dropdown appears
        expect(
          find.byKey(const Key('nas_source_ssh_server_field')),
          findsOneWidget,
        );

        // Test/Probe button
        final testBtn = find.byKey(const Key('nas_source_probe_button'));
        expect(testBtn, findsOneWidget);

        await tester.tap(testBtn);
        await tester.pumpAndSettle();

        // Verify probe was called directly and read-only (keepEmptySecrets: true)
        expect(sourcesNotifier.probeCalled, isTrue);
        expect(sourcesNotifier.probedKeepEmptySecrets, isTrue);
        expect(sourcesNotifier.probedSource?.name, 'My WebDAV');
      },
    );

    testWidgets(
      'NasSourceDialog initializes default SSH server on new SFTP source matching activeServer and submits non-empty sshServerId, while existing source identity is preserved',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final serverA = const ServerProfile(
          id: 'srv-a',
          name: 'Server Alpha',
          host: '192.168.1.10',
          port: 22,
          username: 'userA',
        );
        final serverB = const ServerProfile(
          id: 'srv-b',
          name: 'Server Beta',
          host: '192.168.1.20',
          port: 22,
          username: 'userB',
        );

        final sourcesNotifier = _TestNasSourcesNotifier();
        final notifier = _FakeNasNotifier(const NasState());

        // 1. Test New SFTP Source:
        // Set activeServer to serverB (different from first server in list serverA)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(serverB),
              ),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([serverA, serverB]),
              ),
              nasSourcesProvider.overrideWith(() => sourcesNotifier),
              nasProvider.overrideWith(() => notifier),
              localStorageServiceProvider.overrideWithValue(defaultStorage),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => NasSourceDialog.show(ctx, source: null),
                    child: const Text('Open New Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open New Dialog'));
        await tester.pumpAndSettle();

        expect(find.byType(NasSourceDialog), findsOneWidget);

        // Verify dropdown displays serverB (activeServer prioritized over first in list)
        final dropdownFinder = find.byKey(
          const Key('nas_source_ssh_server_field'),
        );
        expect(dropdownFinder, findsOneWidget);
        expect(
          tester.state<FormFieldState<String>>(dropdownFinder).value,
          equals('srv-b'),
        );
        expect(
          find.text('Server Beta (userB@192.168.1.20:22)'),
          findsOneWidget,
        );

        // Enter source name
        await tester.enterText(
          find.byKey(const Key('nas_source_name_field')),
          'My New SFTP',
        );
        await tester.pump();

        // Tap Save (without manually touching the dropdown)
        final saveBtn = find.byKey(const Key('nas_source_save_button'));
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Verify savedSource has sshServerId == 'srv-b' and is NOT null!
        expect(sourcesNotifier.savedSource, isNotNull);
        expect(sourcesNotifier.savedSource!.name, equals('My New SFTP'));
        expect(sourcesNotifier.savedSource!.type, equals(NasSourceType.sftp));
        expect(sourcesNotifier.savedSource!.sshServerId, equals('srv-b'));

        // 2. Test Editing existing source:
        // Source has its own sshServerId 'srv-a', while activeServer is serverB.
        // It must NOT fallback to serverB.
        final existingSource = const NasSource(
          id: 'src-existing',
          name: 'Existing SFTP',
          type: NasSourceType.sftp,
          sshServerId: 'srv-a',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(serverB),
              ),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([serverA, serverB]),
              ),
              nasSourcesProvider.overrideWith(() => sourcesNotifier),
              nasProvider.overrideWith(() => notifier),
              localStorageServiceProvider.overrideWithValue(defaultStorage),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        NasSourceDialog.show(ctx, source: existingSource),
                    child: const Text('Open Edit Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Edit Dialog'));
        await tester.pumpAndSettle();

        final editDropdownFinder = find.byKey(
          const Key('nas_source_ssh_server_field'),
        );
        expect(
          tester.state<FormFieldState<String>>(editDropdownFinder).value,
          equals('srv-a'),
        );
        expect(
          find.text('Server Alpha (userA@192.168.1.10:22)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'NasDownloadsSheet handles completed download with NAS_EXTERNAL_OPEN_FAILED and allows retry open',
      (tester) async {
        final notifier = _FakeNasNotifier(const NasState());
        final downloadService = _FakeDownloadService();

        final failedTask = NasDownloadTask(
          id: 'dl-task-1',
          item: sampleVideo,
          status: NasDownloadStatus.completed,
          error: 'NAS_EXTERNAL_OPEN_FAILED',
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            downloads: [failedTask],
            downloadService: downloadService,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NasDownloadsSheet.show(ctx),
                  child: const Text('Open Downloads'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Downloads'));
        await tester.pumpAndSettle();

        // Verify retry open button exists
        final retryBtn = find.byKey(const Key('nas_open_download_dl-task-1'));
        expect(retryBtn, findsOneWidget);

        await tester.tap(retryBtn);
        await tester.pump();

        expect(downloadService.openedTaskId, 'dl-task-1');
      },
    );

    testWidgets(
      'NasImageViewerDialog cross-page navigation invokes loadMore when next tapped on last image',
      (tester) async {
        const image1 = NasMediaItem(
          serverId: 'src-nas',
          path: '/media/photo1.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 1024,
          modifiedEpoch: 1700000000,
        );
        const image2 = NasMediaItem(
          serverId: 'src-nas',
          path: '/media/photo2.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 1024,
          modifiedEpoch: 1700000000,
        );

        final notifier = _FakeNasNotifier(
          NasState(serverId: 'src-nas', hasMore: true, items: [image1, image2]),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NasImageViewerDialog.show(
                    ctx,
                    item: image2,
                    items: [image1, image2],
                    initialIndex: 1,
                    thumbnailFuture: Future.value(null),
                    isFavorite: false,
                    onToggleFavorite: () {},
                    onOpenExternal: () {},
                  ),
                  child: const Text('Open Viewer'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Viewer'));
        await tester.pumpAndSettle();

        expect(find.byType(NasImageViewerDialog), findsOneWidget);

        // Next button is visible because hasMore is true
        final nextBtn = find.byKey(const Key('nas_image_next_button'));
        expect(nextBtn, findsOneWidget);

        await tester.tap(nextBtn);
        await tester.pump();

        expect(notifier.loadMoreCalled, isTrue);
      },
    );

    testWidgets(
      'nas_localizations maps blocker, step, and guidance codes and sanitizes errors',
      (tester) async {
        late BuildContext capturedCtx;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) {
                capturedCtx = ctx;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_DOCKER_REQUIRED'),
          capturedCtx.nasInstallBlockerDocker,
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_CANCELLED'),
          contains('部署已由用户取消'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_INSPECT_FAILED'),
          contains('核验远程容器失败'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_DEADLINE_EXCEEDED'),
          contains('部署步骤超时'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_COMMAND_TIMEOUT'),
          contains('部署步骤超时'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_INTERRUPTED'),
          contains('部署已中断'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_HEALTH_TIMEOUT'),
          contains('HTTP 健康检查超时'),
        );
        expect(
          capturedCtx.nasInstallBlockerText(
            'NAS_INSTALL_RECONCILIATION_FAILED',
          ),
          contains('状态对账失败'),
        );
        expect(
          capturedCtx.nasInstallBlockerText(
            'NAS_INSTALL_REMOTE_INSPECTION_REQUIRED',
          ),
          contains('远程容器状态不明确'),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_BUSY'),
          allOf(contains('已有安装任务正在运行'), contains('当前任务')),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_STATE_SAVE_FAILED'),
          allOf(contains('保存部署状态失败'), contains('存储空间')),
        );
        expect(
          capturedCtx.nasInstallBlockerText(
            'NAS_INSTALL_COMMAND_RESULT_UNKNOWN',
          ),
          allOf(contains('远端执行结果未知'), contains('只读核验')),
        );
        expect(
          capturedCtx.nasInstallBlockerText('NAS_INSTALL_PREFLIGHT_FAILED'),
          allOf(contains('部署前环境预检失败'), contains('阻断项')),
        );
        expect(
          capturedCtx.nasSanitizedError('NAS_INSTALL_COMMAND_RESULT_UNKNOWN'),
          contains('只读核验'),
        );
        expect(
          capturedCtx.nasInstallStepText(
            'NAS_INSTALL_CREATE_PRIVATE_DIRECTORY',
          ),
          capturedCtx.nasInstallStepCreateDir,
        );
        expect(
          capturedCtx.nasInstallGuidanceText('NAS_INSTALL_SSH_TUNNEL_REQUIRED'),
          capturedCtx.nasInstallGuidanceTunnel,
        );
        expect(
          capturedCtx.nasSanitizedError(
            'Exception: http://admin:secret123@192.168.1.100/data',
          ),
          isNot(contains('secret123')),
        );
      },
    );

    testWidgets(
      'Music tab renders metadata enriching banner when background enrichment is running',
      (tester) async {
        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [
              const NasMediaItem(
                serverId: 'src-nas',
                path: '/music/song.mp3',
                kind: NasMediaKind.audio,
                sizeBytes: 2048,
                modifiedEpoch: 1700000000,
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            metadataProgress: const NasMetadataProgress(
              running: true,
              processed: 15,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Music tab
        await tester.tap(find.byKey(const Key('nas_tab_music')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Enriching banner should be displayed
        expect(
          find.byKey(const Key('nas_metadata_enriching_bar')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('nas_metadata_enriching_bar')),
            matching: find.textContaining('15'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'MainShell renders independent NAS source selector on top bar and suppresses SSH connect button when on NAS tab',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final notifier = _FakeNasNotifier(const NasState());
        final sourcesNotifier = _TestNasSourcesNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([testServer]),
              ),
              sftpOperationsProvider.overrideWithValue(_FakeOperations()),
              localStorageServiceProvider.overrideWithValue(defaultStorage),
              nasSourcesProvider.overrideWith(() => sourcesNotifier),
              nasProvider.overrideWith(() => notifier),
              nasPlaybackProvider.overrideWith(
                (ref) => Stream.value(const NasPlayerSnapshot()),
              ),
              nasDownloadsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Drawer and navigate to NAS
        final ScaffoldState state = tester.firstState(find.byType(Scaffold));
        state.openDrawer();
        await tester.pumpAndSettle();

        final nasTile = find.byKey(const Key('drawer_nas_tile'));
        expect(nasTile, findsOneWidget);
        await tester.tap(nasTile);
        await tester.pumpAndSettle();

        // Shell should now show independent NAS source selector
        expect(
          find.byKey(const Key('main_shell_nas_source_selector')),
          findsOneWidget,
        );
        expect(find.text('Home NAS'), findsWidgets);

        // SSH Connect / Reconnect button should NOT be present on NAS top bar
        expect(find.text('立即连接'), findsNothing);
        expect(find.text('重新连接'), findsNothing);
      },
    );

    testWidgets(
      'media row renders without overflow on 360 logical width with overflow menu and useful text width',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const testAudio = NasMediaItem(
          serverId: 'src-nas',
          path:
              '/mnt/media/music/A Very Long Audio Track Name That Should Ellipsize.flac',
          kind: NasMediaKind.audio,
          sizeBytes: 35 * 1024 * 1024,
          modifiedEpoch: 1700000000,
        );

        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [testAudio],
          ),
        );

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Must find media item card
        final cardFinder = find.byKey(Key('nas_item_${testAudio.name}'));
        expect(cardFinder, findsOneWidget);

        // Height must be compact (definitely not the 936px tall card reported in 04-library.png)
        final cardSize = tester.getSize(cardFinder);
        expect(cardSize.height, lessThan(120));

        // On 360 logical width (< 480), single overflow menu button exists
        final overflowBtnFinder = find.byKey(
          Key('nas_item_overflow_${testAudio.name}'),
        );
        expect(overflowBtnFinder, findsOneWidget);

        // Inline download/cast buttons should NOT be present directly in row
        expect(
          find.descendant(
            of: cardFinder,
            matching: find.byIcon(Icons.download_outlined),
          ),
          findsNothing,
        );

        // Title text width must be useful (> 150px)
        final titleFinder = find.text(testAudio.name);
        expect(titleFinder, findsOneWidget);
        final titleSize = tester.getSize(titleFinder);
        expect(titleSize.width, greaterThan(150));

        // Tapping overflow button opens menu with all secondary actions
        await tester.tap(overflowBtnFinder);
        await tester.pumpAndSettle();

        expect(find.byType(PopupMenuItem<String>), findsNWidgets(5));
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.byIcon(Icons.download_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.byIcon(Icons.cast),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.byIcon(Icons.open_in_new),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'full player renders without overflow on 360 logical width and executes favorite command once',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const testVideo = NasMediaItem(
          serverId: 'src-nas',
          path:
              '/mnt/media/videos/A Very Long Video Title That Fits On Screen.mkv',
          kind: NasMediaKind.video,
          sizeBytes: 500 * 1024 * 1024,
          modifiedEpoch: 1700000000,
        );

        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [testVideo],
          ),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NasFullPlayerDialog.show(
                    ctx,
                    item: testVideo,
                    isPlaying: false,
                    progress: 0.2,
                    onPlayPause: (_) {},
                    onSeek: (_) {},
                    onOpenExternal: () {},
                    isFavorite: false,
                    onToggleFavorite: () {},
                  ),
                  child: const Text('Open Full Player'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Full Player'));
        await tester.pumpAndSettle();

        // Verify full player is rendered without layout overflow
        expect(find.byKey(const Key('nas_full_player')), findsOneWidget);
        expect(
          find.byKey(const Key('nas_full_player_minimize')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('nas_full_player_favorite_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('nas_full_player_download_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('nas_full_player_cast_button')),
          findsOneWidget,
        );

        // Tap favorite button
        await tester.tap(
          find.byKey(const Key('nas_full_player_favorite_button')),
        );
        await tester.pumpAndSettle();

        // Must execute setFavorite exactly once (no duplicate execution)
        expect(notifier.setFavoriteCallCount, equals(1));
        expect(notifier.favoritedItem?.name, equals(testVideo.name));
        expect(notifier.favoritedValue, isTrue);
      },
    );

    testWidgets(
      'gallery image viewer guards loadOriginal with generation and updates favorite immutably',
      (tester) async {
        const testImage1 = NasMediaItem(
          serverId: 'src-nas',
          path: '/mnt/media/photos/photo_1.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 1024 * 1024,
          modifiedEpoch: 1700000000,
        );
        const testImage2 = NasMediaItem(
          serverId: 'src-nas',
          path: '/mnt/media/photos/photo_2.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 2048 * 1024,
          modifiedEpoch: 1700000000,
        );

        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            config: const NasScanConfig(includePaths: ['/mnt/media']),
            items: [testImage1, testImage2],
          ),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NasImageViewerDialog.show(
                    ctx,
                    item: testImage1,
                    items: [testImage1, testImage2],
                    initialIndex: 0,
                    thumbnailFuture: Future.value(null),
                    isFavorite: false,
                    onToggleFavorite: () {},
                    onOpenExternal: () {},
                  ),
                  child: const Text('Open Viewer'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Viewer'));
        await tester.pumpAndSettle();

        // Favorite photo_1
        final favBtn = find.byKey(
          const Key('nas_image_viewer_favorite_button'),
        );
        expect(favBtn, findsOneWidget);
        await tester.tap(favBtn);
        await tester.pumpAndSettle();

        // Verifies setFavorite called exactly once
        expect(notifier.setFavoriteCallCount, equals(1));
        expect(notifier.favoritedItem?.name, equals('photo_1.jpg'));
        expect(notifier.favoritedValue, isTrue);

        // Next image
        final nextBtn = find.byKey(const Key('nas_image_next_button'));
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Stale relay URI was released
        expect(notifier.releasedUri, equals(notifier.lastImageUrl));
      },
    );

    testWidgets(
      'folder groups pagination replaces bounded 200 groups with cursor pages and resets scroll',
      (tester) async {
        final page1 = List.generate(
          200,
          (i) =>
              NasIndexGroupCount('Folder_${i.toString().padLeft(3, '0')}', 5),
        );
        final page2 = List.generate(
          50,
          (i) => NasIndexGroupCount(
            'Folder_${(i + 200).toString().padLeft(3, '0')}',
            3,
          ),
        );

        final notifier = _FakeNasNotifier(
          const NasState(
            serverId: 'src-nas',
            config: NasScanConfig(includePaths: ['/mnt/media']),
          ),
        );
        notifier.customGroups = page1;

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Switch to Folders tab
        await tester.tap(
          find.byKey(const Key('nas_tab_folders')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        // Page 1 is loaded
        expect(notifier.groupsCalledCount, equals(1));
        expect(notifier.lastGroupsAfter, isNull);
        expect(find.text('Folder_000'), findsOneWidget);

        // Next page button should be enabled
        final nextBtn = find.byKey(const Key('nas_folders_next_page_button'));
        expect(nextBtn, findsOneWidget);

        // Prepare page 2
        notifier.customGroups = page2;
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Groups called with cursor of last item in page 1
        expect(notifier.groupsCalledCount, equals(2));
        expect(notifier.lastGroupsAfter, equals('Folder_199'));

        // Page is REPLACED, not accumulated
        expect(find.text('Folder_200'), findsOneWidget);
        expect(find.text('Folder_000'), findsNothing);

        // Previous button is enabled
        final prevBtn = find.byKey(
          const Key('nas_folders_previous_page_button'),
        );
        expect(prevBtn, findsOneWidget);

        // Go back to Page 1
        notifier.customGroups = page1;
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();

        expect(notifier.groupsCalledCount, equals(3));
        expect(notifier.lastGroupsAfter, isNull);
        expect(find.text('Folder_000'), findsOneWidget);
        expect(find.text('Folder_200'), findsNothing);
      },
    );

    testWidgets(
      'favorite failure retains original favorite state and surfaces error snackbar',
      (tester) async {
        const testImage = NasMediaItem(
          serverId: 'src-nas',
          path: '/mnt/media/photos/photo_fav_fail.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 1024 * 1024,
          modifiedEpoch: 1700000000,
          isFavorite: false,
        );

        final notifier = _FakeNasNotifier(
          const NasState(
            serverId: 'src-nas',
            config: NasScanConfig(includePaths: ['/mnt/media']),
            items: [testImage],
          ),
        );
        notifier.shouldFailFavorite = true;

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NasImageViewerDialog.show(
                    ctx,
                    item: testImage,
                    items: [testImage],
                    initialIndex: 0,
                    thumbnailFuture: Future.value(null),
                    isFavorite: false,
                    onToggleFavorite: () {},
                    onOpenExternal: () {},
                  ),
                  child: const Text('Open Viewer'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Viewer'));
        await tester.pumpAndSettle();

        // Favorite button should initially show favorite_border (not favorite)
        final favBtn = find.byKey(
          const Key('nas_image_viewer_favorite_button'),
        );
        expect(favBtn, findsOneWidget);
        expect(
          find.descendant(
            of: favBtn,
            matching: find.byIcon(Icons.favorite_border),
          ),
          findsOneWidget,
        );

        // Tap favorite
        await tester.tap(favBtn);
        await tester.pumpAndSettle();

        // Verifies setFavorite was attempted
        expect(notifier.setFavoriteCallCount, equals(1));

        // Error snackbar must be displayed
        expect(find.byType(SnackBar), findsOneWidget);

        // State remains original (favorite_border), NO fake success
        expect(
          find.descendant(
            of: favBtn,
            matching: find.byIcon(Icons.favorite_border),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: favBtn, matching: find.byIcon(Icons.favorite)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping folder or music group renders scoped items with pagination and allows navigating back to groups',
      (tester) async {
        const folderItem1 = NasMediaItem(
          serverId: 'src-nas',
          path: '/mnt/media/movies/SciFi/interstellar.mp4',
          kind: NasMediaKind.video,
          sizeBytes: 1024 * 1024 * 500,
          modifiedEpoch: 1700000000,
        );
        const allItems = [
          NasMediaItem(
            serverId: 'src-nas',
            path: '/mnt/media/music/song_root.mp3',
            kind: NasMediaKind.audio,
            sizeBytes: 1024 * 1024,
            modifiedEpoch: 1700000000,
          ),
        ];

        final notifier = _FakeNasNotifier(
          const NasState(
            serverId: 'src-nas',
            config: NasScanConfig(includePaths: ['/mnt/media']),
            items: allItems,
          ),
        );
        notifier.customGroups = [
          const NasIndexGroupCount('SciFi', 1),
          const NasIndexGroupCount('Comedy', 2),
        ];
        notifier.itemsForScope = {
          'SciFi': [folderItem1],
          '__root__': allItems,
        };

        await tester.pumpWidget(createNasApp(notifier: notifier));
        await tester.pumpAndSettle();

        // Navigate to Folders tab
        await tester.tap(find.byKey(const Key('nas_tab_folders')));
        await tester.pumpAndSettle();

        // Initially shows folder groups
        expect(find.text('SciFi'), findsOneWidget);
        expect(find.text('Comedy'), findsOneWidget);
        expect(find.text('interstellar.mp4'), findsNothing);

        // Tap 'SciFi' group
        await tester.tap(find.text('SciFi'));
        await tester.pumpAndSettle();

        // Now scoped into folder: groups are gone, scoped item is displayed!
        expect(find.byKey(const Key('nas_folder_back_button')), findsOneWidget);
        expect(find.text('interstellar.mp4'), findsOneWidget);
        expect(find.text('Comedy'), findsNothing);

        // Tap back button
        await tester.tap(find.byKey(const Key('nas_folder_back_button')));
        await tester.pumpAndSettle();

        // Restored to folder groups list
        expect(find.text('SciFi'), findsOneWidget);
        expect(find.text('Comedy'), findsOneWidget);
        expect(find.text('interstellar.mp4'), findsNothing);
      },
    );

    testWidgets(
      'scan config dialog operates without SSH, adds manual path/library ID, and guards against source mismatch',
      (tester) async {
        const initialConfig = NasScanConfig(
          includePaths: ['/media/initial'],
          excludePaths: [],
        );
        NasScanConfig? savedConfig;

        final notifier = _FakeNasNotifier(
          const NasState(serverId: 'src-nas', config: initialConfig),
        );

        final sourcesNotifier = _TestNasSourcesNotifier(
          const NasSourcesState(
            sources: [
              NasSource(
                id: 'src-nas',
                name: 'Home NAS',
                type: NasSourceType.webdav,
                endpoint: 'http://192.168.1.50/webdav',
                rootPath: '/webdav',
              ),
              NasSource(
                id: 'src-other',
                name: 'Other NAS',
                type: NasSourceType.sftp,
                endpoint: '192.168.1.60',
              ),
            ],
            selectedId: 'src-nas',
          ),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            sourcesNotifier: sourcesNotifier,
            servers: [], // NO SSH server configured!
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    final currentSource = ref.read(nasSourcesProvider).selected;
                    NasScanConfigDialog.show(
                      ctx,
                      source: currentSource,
                      sourceId: currentSource?.id,
                      initialConfig: initialConfig,
                      onSave: (cfg) => savedConfig = cfg,
                    );
                  },
                  child: const Text('Open Scan Config'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open config dialog without active SSH
        await tester.tap(find.text('Open Scan Config'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);
        expect(find.text('/media/initial'), findsOneWidget);

        // Tap Add Include Path
        await tester.tap(find.byKey(const Key('nas_add_include_path_button')));
        await tester.pumpAndSettle();

        // Manual text input dialog appears (no SFTP / RemoteDirectoryPicker!)
        expect(find.byKey(const Key('nas_include_path_input')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('nas_include_path_input')),
          'media/photos',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nas_confirm_include_path')));
        await tester.pumpAndSettle();

        // Verify the newly entered path appears in the list
        expect(find.text('media/photos'), findsOneWidget);

        // Test source mismatch guard: simulate source switching while dialog is open
        await sourcesNotifier.select('src-other');

        // Tap Save
        await tester.tap(find.byKey(const Key('nas_config_save_button')));
        await tester.pumpAndSettle();

        // Save was refused because sourceId changed
        expect(savedConfig, isNull);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'playlist detail displays global ordinal >200, moves with global indices, and provides pagination controls',
      (tester) async {
        const testItem = NasMediaItem(
          serverId: 'src-nas',
          path: '/mnt/media/music/track_200.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: 1024 * 1024 * 5,
          modifiedEpoch: 1700000000,
        );

        final notifier = _FakeNasNotifier(
          NasState(
            serverId: 'src-nas',
            playlistId: 'pl-1',
            playlistOffset: 200, // Page 2 starts at global ordinal 200
            playlists: [
              NasPlaylist(
                id: 'pl-1',
                serverId: 'src-nas',
                name: 'Big Playlist',
                createdAt: DateTime(2026, 1, 1),
                itemCount: 250,
              ),
            ],
            items: [testItem],
            hasMore: true,
            hasPrevious: true,
          ),
        );

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            home: const Scaffold(body: NasMediaView()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Playlists tab
        await tester.tap(find.byKey(const Key('nas_tab_playlists')));
        await tester.pumpAndSettle();

        // Detail surface for pl-1 is rendered
        expect(
          find.byKey(const Key('nas_playlist_detail_surface')),
          findsOneWidget,
        );

        // Global row numbering: offset (200) + localIndex (0) + 1 = 201
        expect(find.text('201'), findsOneWidget);

        // Move up: globalIndex (200) - 1 = 199
        final moveUpBtn = find.byKey(
          Key('nas_playlist_move_up_${testItem.name}'),
        );
        expect(moveUpBtn, findsOneWidget);
        await tester.tap(moveUpBtn);
        await tester.pumpAndSettle();
        expect(notifier.movedPlaylistIndex, equals(199));

        // Move down: globalIndex (200) + 1 = 201
        final moveDownBtn = find.byKey(
          Key('nas_playlist_move_down_${testItem.name}'),
        );
        expect(moveDownBtn, findsOneWidget);
        await tester.tap(moveDownBtn);
        await tester.pumpAndSettle();
        expect(notifier.movedPlaylistIndex, equals(201));

        // Pagination controls are present and functional
        final prevBtn = find.byKey(const Key('nas_previous_page_button'));
        expect(prevBtn, findsOneWidget);
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();
        expect(notifier.loadPreviousCalled, isTrue);

        final nextBtn = find.byKey(const Key('nas_next_page_button'));
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
        expect(notifier.loadMoreCalled, isTrue);
      },
    );

    testWidgets(
      'library settings dialog passes source context to scan config dialog and guards against source mismatch',
      (tester) async {
        final notifier = _FakeNasNotifier(const NasState(serverId: 'src-a'));
        final sourcesNotifier = _TestNasSourcesNotifier(
          const NasSourcesState(
            sources: [
              NasSource(
                id: 'src-a',
                name: 'Server A',
                type: NasSourceType.sftp,
                endpoint: 'sftp://example.com',
              ),
              NasSource(
                id: 'src-b',
                name: 'Server B',
                type: NasSourceType.sftp,
                endpoint: 'sftp://other.com',
              ),
            ],
            selectedId: 'src-a',
          ),
        );

        NasScanConfig? savedConfig;

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            sourcesNotifier: sourcesNotifier,
            servers: [],
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    final currentSource = ref.read(nasSourcesProvider).selected;
                    NasLibrarySettingsDialog.show(
                      ctx,
                      source: currentSource,
                      sourceId: currentSource?.id,
                      currentPolicy: NasOpenPolicy.inApp,
                      onPolicyChanged: (_) {},
                      scanConfig: const NasScanConfig(includePaths: ['/data']),
                      onSaveScanConfig: (cfg) async {
                        savedConfig = cfg;
                      },
                      isScanning: false,
                      onScan: () {},
                      onCancelScan: () {},
                    );
                  },
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('nas_library_settings_dialog')),
          findsOneWidget,
        );

        // Tap Configure Scan Directories to open NasScanConfigDialog
        await tester.tap(
          find.byKey(const Key('nas_settings_open_scan_config_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);
        expect(find.text('/data'), findsOneWidget);

        // Switch source to src-b while dialog is open
        await sourcesNotifier.select('src-b');

        // Tap Save
        await tester.tap(find.byKey(const Key('nas_config_save_button')));
        await tester.pumpAndSettle();

        // Save was refused because source changed from src-a to src-b
        expect(savedConfig, isNull);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'scan config dialog awaits onSave, keeps dialog open and shows sanitized error on persistence failure',
      (tester) async {
        final notifier = _FakeNasNotifier(const NasState(serverId: 'src-fail'));
        final sourcesNotifier = _TestNasSourcesNotifier(
          const NasSourcesState(
            sources: [
              NasSource(
                id: 'src-fail',
                name: 'Server Fail',
                type: NasSourceType.jellyfin,
                endpoint: 'http://jf.local',
              ),
            ],
            selectedId: 'src-fail',
          ),
        );

        bool saveAttempted = false;

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            sourcesNotifier: sourcesNotifier,
            servers: [],
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    final currentSource = ref.read(nasSourcesProvider).selected;
                    NasScanConfigDialog.show(
                      ctx,
                      source: currentSource,
                      sourceId: currentSource?.id,
                      initialConfig: const NasScanConfig(includePaths: ['/']),
                      onSave: (cfg) async {
                        saveAttempted = true;
                        throw const FormatException('NAS_INVALID_LIBRARY_ID');
                      },
                    );
                  },
                  child: const Text('Open Scan Config'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Scan Config'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);

        await tester.tap(find.byKey(const Key('nas_config_save_button')));
        await tester.pumpAndSettle();

        expect(saveAttempted, isTrue);
        // Dialog remains open
        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);
        // Sanitized error snackbar is displayed
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'media server scan config normalizes literal all to / and never persists literal all',
      (tester) async {
        final notifier = _FakeNasNotifier(const NasState(serverId: 'src-jf'));
        final sourcesNotifier = _TestNasSourcesNotifier(
          const NasSourcesState(
            sources: [
              NasSource(
                id: 'src-jf',
                name: 'Jellyfin Server',
                type: NasSourceType.jellyfin,
                endpoint: 'http://jf.local:8096',
              ),
            ],
            selectedId: 'src-jf',
          ),
        );

        NasScanConfig? savedConfig;

        await tester.pumpWidget(
          createNasApp(
            notifier: notifier,
            sourcesNotifier: sourcesNotifier,
            servers: [],
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    final currentSource = ref.read(nasSourcesProvider).selected;
                    NasScanConfigDialog.show(
                      ctx,
                      source: currentSource,
                      sourceId: currentSource?.id,
                      // Initial config contains 'all' - should normalize to '/'
                      initialConfig: const NasScanConfig(
                        includePaths: ['all'],
                        excludePaths: ['all'],
                      ),
                      onSave: (cfg) async {
                        savedConfig = cfg;
                      },
                    );
                  },
                  child: const Text('Open JF Config'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open JF Config'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nas_scan_config_dialog')), findsOneWidget);

        // Verify initial 'all' was normalized to '/'
        expect(find.text('/'), findsWidgets);
        expect(find.text('all'), findsNothing);

        // Add a new include path where user types 'ALL'
        await tester.tap(find.byKey(const Key('nas_add_include_path_button')));
        await tester.pumpAndSettle();

        // Default initial is '/'
        expect(find.text('/'), findsWidgets);

        await tester.enterText(
          find.byKey(const Key('nas_include_path_input')),
          'ALL',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nas_confirm_include_path')));
        await tester.pumpAndSettle();

        // 'ALL' normalized to '/' (already present, not duplicated as 'ALL')
        expect(find.text('ALL'), findsNothing);

        // Save
        await tester.tap(find.byKey(const Key('nas_config_save_button')));
        await tester.pumpAndSettle();

        expect(savedConfig, isNotNull);
        expect(savedConfig!.includePaths, contains('/'));
        expect(savedConfig!.includePaths.contains('all'), isFalse);
        expect(savedConfig!.includePaths.contains('ALL'), isFalse);
        expect(savedConfig!.excludePaths, contains('/'));
        expect(savedConfig!.excludePaths.contains('all'), isFalse);
      },
    );
  });
}
