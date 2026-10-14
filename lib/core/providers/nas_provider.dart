import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/repositories/nas_index_repository.dart';
import '../services/nas_download_service.dart';
import '../services/nas_audio_handler.dart';
import '../services/nas_image_cache_service.dart';
import '../services/nas_media_player_service.dart';
import 'infrastructure_providers.dart';
import 'nas_sources_provider.dart';
import 'storage_providers.dart';
import 'server_provider.dart';

final nasIndexRepositoryProvider = FutureProvider<NasIndexRepository>((
  ref,
) async {
  final directory = await getApplicationSupportDirectory();
  final repository = NasIndexRepository(
    path.join(directory.path, 'valhalla_nas.sqlite3'),
  );
  await repository.initialize();
  return repository;
});

final nasMediaPlayerProvider = FutureProvider<NasMediaPlayerService>((
  ref,
) async {
  final repository = await ref.watch(nasIndexRepositoryProvider.future);
  final player = NasMediaPlayerService(
    ref.watch(nasMediaProxyServiceProvider),
    repository,
    adapterFor: (id) => ref.read(nasSourceAdapterProvider(id).future),
    localPathFor: (item) =>
        ref.read(nasDownloadServiceProvider).localPathFor(item),
    onPlaybackSaved: () {
      if (ref.mounted) {
        ref.invalidate(nasHomeProvider);
        unawaited(ref.read(nasProvider.notifier).refreshPlayback());
      }
    },
  );
  NasAudioHandler? handler;
  ref.onDispose(() async {
    await handler?.detach(player);
    await player.dispose();
  });
  handler = await NasAudioHandler.attach(
    player,
    onError: player.reportPlatformError,
  );
  if (!ref.mounted) {
    await handler.detach(player);
    await player.dispose();
  }
  return player;
});

final nasVideoControllerProvider = FutureProvider<VideoController>((ref) async {
  final service = await ref.watch(nasMediaPlayerProvider.future);
  return service.videoController;
});

final nasPlaybackProvider = StreamProvider<NasPlayerSnapshot>((ref) async* {
  final service = await ref.watch(nasMediaPlayerProvider.future);
  yield service.state;
  yield* service.changes;
});

final nasDownloadServiceProvider = Provider<NasDownloadService>((ref) {
  final service = NasDownloadService(
    (id) => ref.read(nasSourceAdapterProvider(id).future),
    repository: () => ref.read(nasIndexRepositoryProvider.future),
    sourceIdentityFor: (id) {
      final source = ref
          .read(nasSourcesProvider)
          .sources
          .firstWhere((s) => s.id == id);
      final server = ref
          .read(serverListProvider)
          .where((s) => s.id == source.sshServerId)
          .firstOrNull;
      final identity = source.toJson()..remove('name');
      if (server != null) {
        identity['sshConnection'] = server.connectionKey.toString();
      }
      return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
    },
  );
  ref.onDispose(service.dispose);
  return service;
});
final nasDownloadsProvider = StreamProvider<List<NasDownloadTask>>((
  ref,
) async* {
  final service = ref.watch(nasDownloadServiceProvider);
  await service.ready;
  yield service.tasks;
  yield* service.changes;
});

class NasHomeSections {
  final List<NasMediaItem> continueWatching, continueListening, photos, videos, music, favorites;
  final Map<String, NasPlaybackState> playbackByPath;
  const NasHomeSections({
    this.continueWatching = const [],
    this.continueListening = const [],
    this.photos = const [],
    this.videos = const [],
    this.music = const [],
    this.favorites = const [],
    this.playbackByPath = const {},
  });
}

final nasHomeProvider = FutureProvider<NasHomeSections>((ref) async {
  final id = ref.watch(nasSourcesProvider.select((s) => s.selected))?.id;
  ref.watch(nasProvider.select((s) => (s.lastScan, s.isScanning)));
  if (id == null) return const NasHomeSections();
  final repository = await ref.watch(nasIndexRepositoryProvider.future);
  final sections = await Future.wait([
    repository.recentPlayback(id),
    repository.query(id, kind: NasMediaKind.image, limit: 12),
    repository.query(id, kind: NasMediaKind.video, limit: 8),
    repository.query(id, kind: NasMediaKind.audio, limit: 8),
    repository.recentPlayback(id, kind: NasMediaKind.audio),
    repository.queryPage(id, favoritesOnly: true, limit: 12).then((page) => page.items),
  ]);
  return NasHomeSections(
    continueWatching: sections[0],
    photos: sections[1],
    videos: sections[2],
    music: sections[3],
    continueListening: sections[4],
    favorites: sections[5],
    playbackByPath: await repository.playbackForItems(id, [...sections[0], ...sections[2], ...sections[4]].map((item) => item.path)),
  );
});

final nasImageCacheProvider = Provider<NasImageCacheService>((ref) {
  final service = NasImageCacheService(
    (id) => ref.read(nasSourceAdapterProvider(id).future),
    ref.read(localStorageServiceProvider).getNasThumbnailCacheBytes,
  );
  ref.onDispose(service.dispose);
  return service;
});

class NasState {
  final String? serverId;
  final NasScanConfig config;
  final List<NasMediaItem> items;
  final List<NasPlaylist> playlists;
  final NasMediaKind? filter;
  final String search;
  final String browseCategory;
  final NasSortKey sortKey;
  final bool sortAscending;
  final DateTime? lastScan;
  final bool isLoading, isScanning, hasMore, hasPrevious, favoritesOnly;
  final String? errorCode, folder, artist, album, playlistId;
  final String? albumKey;
  final int? modifiedFromEpoch, modifiedBeforeEpoch;
  final Map<String, NasPlaybackState> playbackByPath;
  final NasScanStage scanStage;
  final String? scanErrorCode;
  final DateTime? scanUpdatedAt;
  final bool galleryWindowEnabled;
  final int galleryTrimmedBefore, galleryTrimmedAfter;
  final NasIndexTotals totals;
  final int scannedCount, matchingCount;

  /// Zero-based ordinal of the first item on the current playlist page.
  final int playlistOffset;

  const NasState({
    this.serverId,
    this.config = const NasScanConfig(),
    this.items = const [],
    this.playlists = const [],
    this.filter,
    this.search = '',
    this.browseCategory = 'home',
    this.sortKey = NasSortKey.modified,
    this.sortAscending = false,
    this.lastScan,
    this.isLoading = false,
    this.isScanning = false,
    this.hasMore = false,
    this.hasPrevious = false,
    this.favoritesOnly = false,
    this.errorCode,
    this.folder,
    this.artist,
    this.album,
    this.playlistId,
    this.albumKey,
    this.modifiedFromEpoch,
    this.modifiedBeforeEpoch,
    this.playbackByPath = const {},
    this.scanStage = NasScanStage.idle,
    this.scanErrorCode,
    this.scanUpdatedAt,
    this.galleryWindowEnabled = false,
    this.galleryTrimmedBefore = 0,
    this.galleryTrimmedAfter = 0,
    this.totals = const NasIndexTotals(),
    this.scannedCount = 0,
    this.matchingCount = 0,
    this.playlistOffset = 0,
  });

  NasState copyWith({
    NasScanConfig? config,
    List<NasMediaItem>? items,
    List<NasPlaylist>? playlists,
    NasMediaKind? filter,
    bool clearFilter = false,
    String? search,
    String? browseCategory,
    NasSortKey? sortKey,
    bool? sortAscending,
    DateTime? lastScan,
    bool? isLoading,
    bool? isScanning,
    bool? hasMore,
    bool? hasPrevious,
    bool? favoritesOnly,
    String? errorCode,
    bool clearError = false,
    String? folder,
    String? artist,
    String? album,
    String? playlistId,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
    Map<String, NasPlaybackState>? playbackByPath,
    NasScanStage? scanStage,
    String? scanErrorCode,
    bool clearScanError = false,
    DateTime? scanUpdatedAt,
    bool? galleryWindowEnabled,
    int? galleryTrimmedBefore,
    int? galleryTrimmedAfter,
    bool clearScope = false,
    NasIndexTotals? totals,
    int? scannedCount,
    int? matchingCount,
    int? playlistOffset,
  }) => NasState(
    serverId: serverId,
    config: config ?? this.config,
    items: items ?? this.items,
    playlists: playlists ?? this.playlists,
    filter: clearFilter ? null : filter ?? this.filter,
    search: search ?? this.search,
    browseCategory: browseCategory ?? this.browseCategory,
    sortKey: sortKey ?? this.sortKey,
    sortAscending: sortAscending ?? this.sortAscending,
    lastScan: lastScan ?? this.lastScan,
    isLoading: isLoading ?? this.isLoading,
    isScanning: isScanning ?? this.isScanning,
    hasMore: hasMore ?? this.hasMore,
    hasPrevious: hasPrevious ?? this.hasPrevious,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    folder: clearScope ? null : folder ?? this.folder,
    artist: clearScope ? null : artist ?? this.artist,
    album: clearScope ? null : album ?? this.album,
    playlistId: clearScope ? null : playlistId ?? this.playlistId,
    albumKey: clearScope ? null : albumKey ?? this.albumKey,
    modifiedFromEpoch: clearScope ? null : modifiedFromEpoch ?? this.modifiedFromEpoch,
    modifiedBeforeEpoch: clearScope ? null : modifiedBeforeEpoch ?? this.modifiedBeforeEpoch,
    playbackByPath: playbackByPath ?? this.playbackByPath,
    scanStage: scanStage ?? this.scanStage,
    scanErrorCode: clearScanError ? null : scanErrorCode ?? this.scanErrorCode,
    scanUpdatedAt: scanUpdatedAt ?? this.scanUpdatedAt,
    galleryWindowEnabled: galleryWindowEnabled ?? this.galleryWindowEnabled,
    galleryTrimmedBefore: galleryTrimmedBefore ?? this.galleryTrimmedBefore,
    galleryTrimmedAfter: galleryTrimmedAfter ?? this.galleryTrimmedAfter,
    totals: totals ?? this.totals,
    scannedCount: scannedCount ?? this.scannedCount,
    matchingCount: matchingCount ?? this.matchingCount,
    playlistOffset: clearScope ? 0 : playlistOffset ?? this.playlistOffset,
  );
}

final nasProvider = NotifierProvider<NasNotifier, NasState>(NasNotifier.new);

class _NasBrowseSnapshot {
  final NasState state;
  final List<NasIndexCursor?> anchors;
  final NasIndexCursor? nextCursor;
  final List<({int? position, int offset})> playlistAnchors;
  final int? playlistPosition;
  final int remotePlaylistOffset;
  const _NasBrowseSnapshot(
    this.state,
    this.anchors,
    this.nextCursor,
    this.playlistAnchors,
    this.playlistPosition,
    this.remotePlaylistOffset,
  );
}

class NasNotifier extends Notifier<NasState> {
  static const _pageSize = 200;
  int _epoch = 0;
  NasCancellation? _scanCancellation, _playlistCancellation;
  NasIndexCursor? _nextCursor;
  final List<NasIndexCursor?> _anchors = [];
  final List<({int? position, int offset})> _playlistAnchors = [];
  int? _playlistPosition;
  int _remotePlaylistOffset = 0;
  StreamIterator<List<NasMediaItem>>? _remotePlaylist;
  NasState? _visibleState;
  final Map<(String, String), _NasBrowseSnapshot> _browseMemory = {};
  final Map<String, String> _sourceCategories = {};
  final Map<String, NasSource> _browseSources = {};
  final Set<String> _batchSources = {};
  final Expando<NasSource> _batchOrigins = Expando<NasSource>();
  Future<NasIndexRepository> get _repository =>
      ref.read(nasIndexRepositoryProvider.future);

  @override
  NasState build() {
    final source = ref.watch(nasSourcesProvider.select((s) => s.selected));
    _rememberBrowse();
    _browseMemory.removeWhere((key, _) => !_sameSource(_browseSources[key.$1]));
    _sourceCategories.removeWhere((id, _) => !_sameSource(_browseSources[id]));
    _browseSources.removeWhere((_, source) => !_sameSource(source));
    if (source != null) _browseSources[source.id] = source;
    ++_epoch;
    _scanCancellation?.cancel();
    _playlistCancellation?.cancel();
    _remotePlaylist?.cancel();
    _remotePlaylist = null;
    _anchors.clear();
    _playlistAnchors.clear();
    _playlistPosition = null;
    _remotePlaylistOffset = 0;
    _nextCursor = null;
    final stopListening = listenSelf((previous, next) => _visibleState = next);
    ref.onDispose(stopListening);
    ref.onDispose(() {
      ++_epoch;
      _scanCancellation?.cancel();
      _playlistCancellation?.cancel();
      _remotePlaylist?.cancel();
    });
    final storage = ref.read(localStorageServiceProvider);
    Future.microtask(() {
      if (ref.mounted) refresh();
    });
    var config = source == null
        ? const NasScanConfig()
        : storage.getNasScanConfig(source.id);
    if (source != null &&
        source.type != NasSourceType.sftp &&
        config.includePaths.isEmpty) {
      config = NasScanConfig(
        includePaths: [
          source.type == NasSourceType.webdav ? '/' : source.rootPath,
        ],
        excludePaths: config.excludePaths,
      );
    }
    final initial = NasState(
      serverId: source?.id,
      config: config,
      lastScan: source == null ? null : storage.getNasLastScan(source.id),
    );
    final remembered =
        _browseMemory[(source?.id, _sourceCategories[source?.id])];
    if (remembered == null) return initial;
    _restoreBrowse(remembered);
    return remembered.state.copyWith(
      config: config,
      lastScan: initial.lastScan,
      isLoading: false,
      isScanning: false,
      scanStage: remembered.state.scanStage == NasScanStage.scanning ||
          remembered.state.scanStage == NasScanStage.connecting ||
          remembered.state.scanStage == NasScanStage.finalizing
          ? NasScanStage.cancelled : remembered.state.scanStage,
      clearError: true,
    );
  }

  void _rememberBrowse() {
    final visible = _visibleState;
    final id = visible?.serverId;
    if (visible == null || id == null || !_sameSource(_browseSources[id])) return;
    final key = (id, visible.browseCategory);
    _sourceCategories[id] = visible.browseCategory;
    _browseMemory.remove(key);
    _browseMemory[key] = _NasBrowseSnapshot(
      visible.copyWith(isLoading: false, isScanning: false),
      List.of(_anchors),
      _nextCursor,
      List.of(_playlistAnchors),
      _playlistPosition,
      _remotePlaylistOffset,
    );
    // Keep one bounded page per recently visited source/category, not whole libraries.
    while (_browseMemory.length > 32) {
      _browseMemory.remove(_browseMemory.keys.first);
    }
  }

  void _restoreBrowse(_NasBrowseSnapshot snapshot) {
    _anchors
      ..clear()
      ..addAll(snapshot.anchors);
    _nextCursor = snapshot.nextCursor;
    _playlistAnchors
      ..clear()
      ..addAll(snapshot.playlistAnchors);
    _playlistPosition = snapshot.playlistPosition;
    _remotePlaylistOffset = snapshot.remotePlaylistOffset;
  }

  Future<void> selectCategory(
    String category, {
    NasMediaKind? filter,
    bool favoritesOnly = false,
  }) async {
    if (state.browseCategory == category) return;
    _rememberBrowse();
    final remembered = _browseMemory[(state.serverId, category)];
    final current = state;
    if (remembered != null) {
      _restoreBrowse(remembered);
      state = remembered.state.copyWith(
        config: current.config,
        lastScan: current.lastScan,
        isScanning: current.isScanning,
        scanStage: current.scanStage,
        scanErrorCode: current.scanErrorCode,
        clearScanError: current.scanErrorCode == null,
        scanUpdatedAt: current.scanUpdatedAt,
        scannedCount: current.scannedCount,
        totals: current.totals,
        playlists: current.playlists,
      );
    } else {
      state = state.copyWith(
        browseCategory: category,
        filter: filter,
        clearFilter: filter == null,
        favoritesOnly: favoritesOnly,
        clearScope: true,
        search: '',
        items: [],
        sortKey: NasSortKey.modified,
        sortAscending: false,
        galleryWindowEnabled: false,
        galleryTrimmedBefore: 0,
        galleryTrimmedAfter: 0,
      );
    }
    await refresh(preservePosition: remembered != null);
  }

  Future<NasIndexPage> _page(String id, NasIndexCursor? cursor, {
    bool before = false, bool inclusive = false,
    int limit = _pageSize,
  }) async {
    final query = state;
    return (await _repository).queryPage(
        id,
        kind: query.filter,
        search: query.search,
        favoritesOnly: query.favoritesOnly,
        folder: query.folder,
        artist: query.artist,
        album: query.album,
        albumKey: query.albumKey,
        modifiedFromEpoch: query.modifiedFromEpoch,
        modifiedBeforeEpoch: query.modifiedBeforeEpoch,
        cursor: cursor,
        before: before,
        inclusive: inclusive,
        sortKey: query.sortKey,
        sortAscending: query.sortAscending,
        limit: limit,
      );
  }

  NasIndexCursor _cursor(NasMediaItem item) => NasIndexCursor.fromItem(item,
    sortKey: state.sortKey, ascending: state.sortAscending, albumKey: state.albumKey);

  Future<Map<String, NasPlaybackState>> _playbackForVisible(String id, List<NasMediaItem> items) async =>
      (await _repository).playbackForItems(id,
        items.where((item) => item.kind != NasMediaKind.image).map((item) => item.path));

  Future<void> refreshPlayback() async {
    final id = state.serverId;
    if (id == null) return;
    final epoch = _epoch, visible = state.items;
    try {
      final progress = await _playbackForVisible(id, visible);
      if (ref.mounted && epoch == _epoch && identical(visible, state.items)) {
        state = state.copyWith(playbackByPath: progress);
      }
    } catch (_) { /* Playback must not fail because an optional library lookup failed. */ }
  }

  Future<void> refresh({bool preservePosition = true}) async {
    final id = state.serverId;
    if (id == null) return;
    final epoch = ++_epoch;
    final retainedGallery = preservePosition && state.galleryWindowEnabled && state.items.isNotEmpty;
    final galleryFirst = retainedGallery ? _cursor(state.items.first) : null;
    final galleryLength = retainedGallery ? state.items.length : _pageSize;
    if (!preservePosition) {
      _anchors.clear();
      _playlistAnchors.clear();
      _nextCursor = null;
      _playlistPosition = null;
      _remotePlaylistOffset = 0;
    }
    _playlistCancellation?.cancel();
    final previousPlaylist = _remotePlaylist;
    _remotePlaylist = null;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      playlistOffset: preservePosition ? state.playlistOffset : 0,
      hasPrevious: preservePosition && state.hasPrevious,
    );
    await previousPlaylist?.cancel();
    if (!ref.mounted || epoch != _epoch) return;
    try {
      final repository = await _repository;
      final source = ref.read(nasSourcesProvider).selected;
      final playlists = source?.isMediaServer == true
          ? state.playlists
          : await repository.playlistsFor(id);
      final totals = await repository.totals(id);
      final matching = await repository.count(
        id,
        kind: state.filter,
        search: state.search,
        favoritesOnly: state.favoritesOnly,
        folder: state.folder,
        artist: state.artist,
        album: state.album,
        albumKey: state.albumKey,
        modifiedFromEpoch: state.modifiedFromEpoch,
        modifiedBeforeEpoch: state.modifiedBeforeEpoch,
      );
      if (!ref.mounted || epoch != _epoch) return;
      state = state.copyWith(
        playlists: playlists,
        totals: totals,
        matchingCount: matching,
      );
      if (state.playlistId != null) {
        await _loadPlaylistPage(
          epoch,
          reset: !preservePosition || _playlistAnchors.isEmpty,
          reload: preservePosition,
        );
      } else {
        var page = await _page(id, retainedGallery ? galleryFirst : _anchors.lastOrNull,
          inclusive: retainedGallery);
        if (!ref.mounted || epoch != _epoch) return;
        if (page.items.isEmpty && (_anchors.lastOrNull != null || retainedGallery)) {
          page = await _page(id, null);
          if (!ref.mounted || epoch != _epoch) return;
          _anchors.clear();
        }
        final items = List<NasMediaItem>.of(page.items);
        while (state.galleryWindowEnabled && page.hasMore && items.length < galleryLength && items.length < 600) {
          page = await _page(id, page.nextCursor);
          if (!ref.mounted || epoch != _epoch) return;
          items.addAll(page.items);
        }
        final progress = await _playbackForVisible(id, items);
        if (!ref.mounted || epoch != _epoch) return;
        var galleryHasPrevious = false;
        if (state.galleryWindowEnabled && items.isNotEmpty) {
          // An incremental scan can insert files ahead of the retained anchor.
          // Recheck the edge rather than inheriting a stale "first page" flag.
          final preceding = await _page(id, _cursor(items.first), before: true, limit: 1);
          if (!ref.mounted || epoch != _epoch) return;
          galleryHasPrevious = preceding.items.isNotEmpty;
        }
        _nextCursor = page.nextCursor;
        if (_anchors.isEmpty) _anchors.add(null);
        state = state.copyWith(
          items: items,
          playbackByPath: progress,
          hasMore: page.hasMore,
          hasPrevious: state.galleryWindowEnabled ? galleryHasPrevious : _anchors.length > 1,
          galleryTrimmedBefore: 0,
          galleryTrimmedAfter: 0,
          isLoading: false,
        );
      }
      if (source?.isMediaServer == true && ref.mounted && epoch == _epoch) {
        unawaited(_refreshRemotePlaylists(source!, epoch));
      }
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          isLoading: false,
          errorCode: 'NAS_LIBRARY_LOAD_FAILED',
        );
      }
    }
  }

  Future<void> _refreshRemotePlaylists(NasSource source, int epoch) async {
    bool current() =>
        ref.mounted &&
        epoch == _epoch &&
        state.serverId == source.id &&
        identical(ref.read(nasSourcesProvider).selected, source);
    try {
      final adapter = await ref.read(nasSourceAdapterProvider(source.id).future);
      if (!current()) return;
      final playlists = await adapter.playlists();
      if (current()) state = state.copyWith(playlists: playlists);
    } catch (_) {
      if (current() && state.errorCode == null) {
        state = state.copyWith(errorCode: 'NAS_PLAYLIST_LOAD_FAILED');
      }
    }
  }

  Future<void> loadMore() async {
    if (state.galleryWindowEnabled) return loadGalleryNext();
    if (!state.hasMore || state.isLoading || state.serverId == null) return;
    final epoch = _epoch;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.playlistId != null) {
        await _loadPlaylistPage(epoch);
        return;
      }
      final cursor = _nextCursor;
      final page = await _page(state.serverId!, cursor);
      if (!ref.mounted || epoch != _epoch) return;
      final progress = await _playbackForVisible(state.serverId!, page.items);
      if (!ref.mounted || epoch != _epoch) return;
      _anchors.add(cursor);
      if (_anchors.length > 256) _anchors.removeAt(0);
      _nextCursor = page.nextCursor;
      state = state.copyWith(
        items: page.items,
        playbackByPath: progress,
        hasMore: page.hasMore,
        hasPrevious: _anchors.length > 1,
        isLoading: false,
      );
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          isLoading: false,
          errorCode: 'NAS_LIBRARY_LOAD_FAILED',
        );
      }
    }
  }

  Future<void> loadPrevious() async {
    if (state.galleryWindowEnabled) return loadGalleryPrevious();
    if (state.isLoading || !state.hasPrevious || state.serverId == null) {
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.playlistId != null) {
        await _loadPlaylistPage(epoch, previous: true);
        return;
      }
      final page = await _page(state.serverId!, _anchors[_anchors.length - 2]);
      if (!ref.mounted || epoch != _epoch) return;
      final progress = await _playbackForVisible(state.serverId!, page.items);
      if (!ref.mounted || epoch != _epoch) return;
      _anchors.removeLast();
      _nextCursor = page.nextCursor;
      state = state.copyWith(
        items: page.items,
        playbackByPath: progress,
        hasMore: page.hasMore,
        hasPrevious: _anchors.length > 1,
        isLoading: false,
      );
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          isLoading: false,
          errorCode: 'NAS_LIBRARY_LOAD_FAILED',
        );
      }
    }
  }

  /// The UI owns pixel anchors. Items stay bounded and each result reports
  /// eviction counts; keep a visible source/path anchor before awaiting a load.
  Future<void> enableGalleryWindow(bool enabled) async {
    if (state.galleryWindowEnabled == enabled) return;
    if (enabled && (state.filter != NasMediaKind.image || state.playlistId != null)) return;
    state = state.copyWith(galleryWindowEnabled: enabled,
      galleryTrimmedBefore: 0, galleryTrimmedAfter: 0);
    if (!enabled) await refresh(preservePosition: false);
  }

  Future<void> loadGalleryNext() => _loadGallery(previous: false);
  Future<void> loadGalleryPrevious() => _loadGallery(previous: true);

  Future<void> _loadGallery({required bool previous}) async {
    if (!state.galleryWindowEnabled || state.isLoading || state.serverId == null ||
        state.items.isEmpty || !(previous ? state.hasPrevious : state.hasMore)) {
      return;
    }
    final id = state.serverId!, epoch = _epoch;
    final oldItems = state.items;
    final boundary = _cursor(previous ? oldItems.first : oldItems.last);
    state = state.copyWith(isLoading: true, clearError: true,
      galleryTrimmedBefore: 0, galleryTrimmedAfter: 0);
    try {
      final page = await _page(id, boundary, before: previous);
      if (!ref.mounted || epoch != _epoch) return;
      final seen = <String>{};
      final combined = (previous ? [...page.items, ...oldItems] : [...oldItems, ...page.items])
          .where((item) => seen.add(item.path)).toList();
      final evicted = combined.length > 600 ? combined.length - 600 : 0;
      final items = previous ? combined.take(600).toList() : combined.skip(evicted).toList();
      _nextCursor = items.isEmpty ? null : _cursor(items.last);
      state = state.copyWith(items: items, isLoading: false,
        hasPrevious: previous ? page.hasMore : state.hasPrevious || evicted > 0,
        hasMore: previous ? state.hasMore || evicted > 0 : page.hasMore,
        galleryTrimmedBefore: previous ? 0 : evicted,
        galleryTrimmedAfter: previous ? evicted : 0,
      );
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(isLoading: false, errorCode: 'NAS_LIBRARY_LOAD_FAILED');
      }
    }
  }

  Future<void> setFilter(
    NasMediaKind? value, {
    bool favoritesOnly = false,
  }) async {
    state = state.copyWith(
      filter: value,
      clearFilter: value == null,
      clearScope: true,
      favoritesOnly: favoritesOnly,
      items: [],
      galleryWindowEnabled: value == NasMediaKind.image && state.galleryWindowEnabled,
    );
    await refresh(preservePosition: false);
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value.trim(), items: []);
    await refresh(preservePosition: false);
  }

  Future<void> setSort(NasSortKey key, {required bool ascending}) async {
    state = state.copyWith(sortKey: key, sortAscending: ascending);
    await refresh(preservePosition: false);
  }

  Future<void> setFavoritesOnly(bool value) async {
    state = state.copyWith(favoritesOnly: value, clearScope: true, items: []);
    await refresh(preservePosition: false);
  }

  Future<void> setScope({
    String? folder,
    String? artist,
    String? album,
    String? playlistId,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
  }) async {
    state = state
        .copyWith(clearScope: true)
        .copyWith(
          folder: folder,
          artist: artist,
          album: album,
          playlistId: playlistId,
          albumKey: albumKey,
          modifiedFromEpoch: modifiedFromEpoch,
          modifiedBeforeEpoch: modifiedBeforeEpoch,
          galleryWindowEnabled: playlistId == null && state.galleryWindowEnabled,
          items: [],
        );
    await refresh(preservePosition: false);
  }

  Future<List<NasIndexGroupCount>> groups(
    NasIndexGroup group, {
    String? after,
    NasMediaKind? kind,
    String? folder,
    String? artist,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
  }) async {
    final query = state;
    final id = query.serverId;
    return id == null
        ? []
        : (await _repository).groups(id, group, after: after, limit: 200,
          kind: kind ?? query.filter ?? switch (group) {
            NasIndexGroup.byArtist || NasIndexGroup.byAlbum => NasMediaKind.audio,
            NasIndexGroup.byDate => NasMediaKind.image,
            NasIndexGroup.byFolder => null,
          },
          search: query.search, favoritesOnly: query.favoritesOnly,
          folder: folder ?? query.folder, artist: artist ?? query.artist,
          albumKey: albumKey ?? query.albumKey,
          modifiedFromEpoch: modifiedFromEpoch ?? query.modifiedFromEpoch,
          modifiedBeforeEpoch: modifiedBeforeEpoch ?? query.modifiedBeforeEpoch,
        );
  }

  Future<void> saveConfig(NasScanConfig config) async {
    final id = state.serverId;
    if (id == null || state.isScanning) return;
    final source = ref.read(nasSourcesProvider).selected;
    final NasScanConfig normalized;
    if (source?.isMediaServer == true) {
      final values = [...config.includePaths, ...config.excludePaths];
      if (values.any((v) => RegExp(r'[\x00\r\n]').hasMatch(v))) {
        throw const FormatException('NAS_INVALID_LIBRARY_ID');
      }
      normalized = NasScanConfig(
        includePaths: config.includePaths
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(),
        excludePaths: config.excludePaths
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(),
      );
    } else {
      normalized = ref.read(nasScanServiceProvider).normalize(config);
    }
    await ref
        .read(localStorageServiceProvider)
        .saveNasScanConfig(id, normalized);
    if (ref.mounted && state.serverId == id) {
      state = state.copyWith(config: normalized, clearError: true);
    }
  }

  Future<void> scan() async {
    final id = state.serverId;
    if (id == null || state.isScanning) return;
    final source = _source(id);
    final cancellation = NasCancellation();
    _scanCancellation = cancellation;
    final config = state.config;
    bool current() => ref.mounted && state.serverId == id && _sameSource(source) && _scanCancellation == cancellation;
    state = state.copyWith(isScanning: true, scannedCount: 0, clearError: true,
      scanStage: NasScanStage.connecting, clearScanError: true, scanUpdatedAt: DateTime.now());
    try {
      final adapter = await ref.read(nasSourceAdapterProvider(id).future);
      final repository = await _repository;
      cancellation.check();
      final generation = await repository.beginScan(id);
      cancellation.check();
      if (!current()) { cancellation.cancel(); cancellation.check(); }
      state = state.copyWith(scanStage: NasScanStage.scanning, scanUpdatedAt: DateTime.now());
      var count = 0;
      var lastRefresh = DateTime.now();
      await for (final batch in adapter.scan(config, cancellation)) {
        cancellation.check();
        await repository.upsertBatch(
          id,
          batch,
          generation,
          syncFavorites: adapter.source.isMediaServer,
        );
        count += batch.length;
        if (!current()) {
          cancellation.cancel();
          break;
        }
        state = state.copyWith(scannedCount: count, scanUpdatedAt: DateTime.now());
        if (DateTime.now().difference(lastRefresh).inSeconds >= 2 &&
            !state.isLoading &&
            _anchors.length <= 1) {
          lastRefresh = DateTime.now();
          await refresh();
        }
      }
      cancellation.check();
      if (!current()) { cancellation.cancel(); cancellation.check(); }
      state = state.copyWith(scanStage: NasScanStage.finalizing, scanUpdatedAt: DateTime.now());
      await repository.finishScan(id, generation, cancellation: cancellation);
      cancellation.check();
      if (!current()) return;
      final now = DateTime.now();
      await ref.read(localStorageServiceProvider).saveNasLastScan(id, now);
      if (current()) {
        state = state.copyWith(lastScan: now, scanStage: NasScanStage.completed,
          clearScanError: true, scanUpdatedAt: now);
        await refresh();
      }
    } catch (error) {
      if (current()) {
        final code = cancellation.isCancelled ? 'NAS_SCAN_CANCELLED'
            : error is StateError && RegExp(r'^NAS_[A-Z0-9_]+$').hasMatch(error.message)
                ? error.message : 'NAS_SCAN_FAILED';
        state = state.copyWith(
          errorCode: code,
          scanErrorCode: code,
          scanStage: cancellation.isCancelled ? NasScanStage.cancelled : NasScanStage.failed,
          scanUpdatedAt: DateTime.now(),
        );
      }
    } finally {
      if (current()) {
        state = state.copyWith(isScanning: false);
      }
    }
  }

  void cancelScan() => _scanCancellation?.cancel();

  /// Explicit UI choices use openInApp/openExternal, independent of saved policy.
  Future<void> openMedia(NasMediaItem item) async {
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

  Future<void> openInApp(NasMediaItem item) async {
    final sourceId = item.serverId;
    final sameSource = state.serverId == sourceId;
    final visible = state.items
        .where((e) => e.kind == item.kind && e.serverId == sourceId)
        .toList();
    final queue =
        sameSource &&
            visible.any(
              (e) =>
                  e.path == item.path &&
                  e.playlistEntryId == item.playlistEntryId,
            )
        ? visible
        : [item];
    // Playback captures query and cursor, so subsequent UI navigation cannot reroute it.
    var cursor = _nextCursor;
    final filter = state.filter,
        search = state.search,
        favorites = state.favoritesOnly;
    final sortKey = state.sortKey, sortAscending = state.sortAscending;
    final folder = state.folder, artist = state.artist, album = state.album;
    final albumKey = state.albumKey, modifiedFrom = state.modifiedFromEpoch,
        modifiedBefore = state.modifiedBeforeEpoch;
    var hasMore = sameSource && state.hasMore;
    final playlistId = sameSource ? state.playlistId : null;
    var playlistPosition = _playlistPosition;
    var playlistOffset = _remotePlaylistOffset;
    final cancellation = NasCancellation();
    StreamIterator<List<NasMediaItem>>? playlist;
    final source = ref
        .read(nasSourcesProvider)
        .sources
        .where((source) => source.id == sourceId)
        .firstOrNull;
    NasSourceAdapter? queueAdapter;
    final repository = await _repository;
    Future<List<NasMediaItem>> loadPage() async {
      while (hasMore) {
        cancellation.check();
        if (playlistId != null) {
          if (source?.isMediaServer == true) {
            // Offline opening needs no connection; fetch remote pages only on demand.
            if (!ref.mounted ||
                ref
                        .read(nasSourcesProvider)
                        .sources
                        .where((value) => value.id == sourceId)
                        .firstOrNull !=
                    source) {
              throw const NasCancelled();
            }
            queueAdapter ??= await ref.read(
              nasSourceAdapterProvider(sourceId).future,
            );
            cancellation.check();
            if (!ref.mounted ||
                ref
                        .read(nasSourcesProvider)
                        .sources
                        .where((value) => value.id == sourceId)
                        .firstOrNull !=
                    source) {
              throw const NasCancelled();
            }
            playlist ??= StreamIterator(
              queueAdapter!.playlistItems(
                playlistId,
                cancellation,
                startIndex: playlistOffset,
              ),
            );
            hasMore = await playlist!.moveNext();
            final items = hasMore
                ? playlist!.current.where((e) => e.kind == item.kind).toList()
                : <NasMediaItem>[];
            if (items.isNotEmpty) return items;
            continue;
          }
          final page = await repository.playlistMediaPage(
            sourceId,
            playlistId,
            afterPosition: playlistPosition,
            limit: 200,
          );
          playlistPosition = page.nextPosition;
          hasMore = page.hasMore;
          final items = page.items.where((e) => e.kind == item.kind).toList();
          if (items.isNotEmpty) return items;
          continue;
        }
        final page = await repository.queryPage(
          sourceId,
          kind: filter ?? item.kind,
          search: search,
          favoritesOnly: favorites,
          folder: folder,
          artist: artist,
          album: album,
          albumKey: albumKey,
          modifiedFromEpoch: modifiedFrom,
          modifiedBeforeEpoch: modifiedBefore,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          limit: 200,
        );
        cursor = page.nextCursor;
        hasMore = page.hasMore;
        final items = page.items.where((e) => e.kind == item.kind).toList();
        if (items.isNotEmpty) return items;
      }
      return [];
    }

    await (await ref.read(nasMediaPlayerProvider.future)).open(
      item,
      queue: queue,
      loadMore: loadPage,
      disposeQueue: () {
        cancellation.cancel();
        playlist?.cancel();
      },
      restartQueue: sameSource
          ? () async {
              cancellation.check();
              await playlist?.cancel();
              playlist = null;
              playlistOffset = 0;
              playlistPosition = null;
              cursor = null;
              hasMore = true;
              return loadPage();
            }
          : null,
    );
  }

  Future<void> addToQueue(NasMediaItem item) async {
    final source = ref.read(nasSourcesProvider).sources
        .where((source) => source.id == item.serverId).firstOrNull;
    if (source == null) throw StateError('NAS_SOURCE_NOT_FOUND');
    final player = await ref.read(nasMediaPlayerProvider.future);
    if (!ref.mounted ||
        !ref.read(nasSourcesProvider).sources.contains(source)) {
      throw StateError('NAS_SOURCE_CHANGED');
    }
    await player.addToQueue(item);
  }

  String openExternal(NasMediaItem item) =>
      ref.read(nasDownloadServiceProvider).download(item, openWhenDone: true);
  String download(NasMediaItem item) =>
      ref.read(nasDownloadServiceProvider).download(item);
  Future<void> setOpenPolicy(NasMediaKind kind, NasOpenPolicy policy) =>
      ref.read(localStorageServiceProvider).saveNasOpenPolicy(kind, policy);
  Future<String?> thumbnailPath(NasMediaItem item, {Object? owner}) =>
      ref.read(nasImageCacheProvider).thumbnail(item, owner: owner);
  void releaseThumbnail(NasMediaItem item, Object owner) =>
      ref.read(nasImageCacheProvider).releaseThumbnail(item, owner);
  Future<Map<String, int>> thumbnailCacheUsage({String? sourceId, bool legacyOnly = false}) =>
      ref.read(nasImageCacheProvider).cacheUsage(sourceId: sourceId, legacyOnly: legacyOnly);
  Future<Map<String, Map<String, int>>> thumbnailCacheUsageBySource() =>
      ref.read(nasImageCacheProvider).cacheUsageBySource();
  Future<void> clearThumbnailCache({String? sourceId, bool legacyOnly = false}) =>
      ref.read(nasImageCacheProvider).clearCache(sourceId: sourceId, legacyOnly: legacyOnly);
  int get thumbnailCacheBudget =>
      ref.read(localStorageServiceProvider).getNasThumbnailCacheBytes();
  Future<void> setThumbnailCacheBudget(int bytes) async {
    await ref
        .read(localStorageServiceProvider)
        .saveNasThumbnailCacheBytes(bytes);
    await ref.read(nasImageCacheProvider).trimCache();
  }

  Future<Uri> imageUrl(NasMediaItem item) async {
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    return ref
        .read(nasMediaProxyServiceProvider)
        .exposeResource(item, await adapter.resolve(item));
  }

  void releaseImageUrl(Uri uri) =>
      ref.read(nasMediaProxyServiceProvider).revoke(uri);

  Future<void> setFavorite(NasMediaItem item, bool value) async {
    final source = _source(item.serverId);
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    final repository = await _repository;
    await _applyItemOperation(
      adapter,
      repository,
      item,
      value ? NasBatchOperation.favorite : NasBatchOperation.unfavorite,
      source: source,
    );
    if (!_sameSource(source)) return;
    final totals = await repository.totals(item.serverId);
    if (!_sameSource(source) || state.serverId != item.serverId) return;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          if (!state.favoritesOnly || e.path != item.path || value)
            e.path == item.path ? e.copyWith(isFavorite: value) : e,
      ],
      totals: totals,
    );
    ref.invalidate(nasHomeProvider);
  }

  NasSource? _source(String id) => ref.read(nasSourcesProvider).sources
      .where((source) => source.id == id).firstOrNull;

  bool _sameSource(NasSource? source) =>
      ref.mounted && source != null && _source(source.id) == source;

  Future<void> _applyItemOperation(
    NasSourceAdapter adapter,
    NasIndexRepository repository,
    NasMediaItem item,
    NasBatchOperation operation, {
    required NasSource? source,
    String? playlistId,
    int? position,
  }) async {
    if (!_sameSource(source)) throw StateError('NAS_BATCH_SOURCE_CHANGED');
    if (operation == NasBatchOperation.addToPlaylist) {
      if (adapter.source.isMediaServer) {
        await adapter.addToPlaylist(playlistId!, item);
      } else {
        await repository.addToPlaylist(
          serverId: item.serverId,
          playlistId: playlistId!,
          path: item.path,
          position: position,
          requireOwnership: true,
        );
      }
      return;
    }
    if (operation == NasBatchOperation.removeFromPlaylist) {
      if (adapter.source.isMediaServer) {
        final entryId = item.playlistEntryId;
        if (entryId == null) throw StateError('NAS_PLAYLIST_ENTRY_REQUIRED');
        await adapter.removeFromPlaylist(playlistId!, entryId);
      } else {
        await repository.removeFromPlaylist(
          item.serverId,
          playlistId!,
          item.path,
          requireOwnership: true,
        );
      }
      return;
    }
    final value = operation == NasBatchOperation.favorite;
    if (adapter.source.isMediaServer) await adapter.setFavorite(item, value);
    // A completed remote change stays successful, but must not update a replacement source.
    if (!_sameSource(source)) return;
    await repository.setFavorite(item.serverId, item.path, value);
    if (_sameSource(source) && ref.exists(nasMediaPlayerProvider)) {
      ref
          .read(nasMediaPlayerProvider)
          .asData
          ?.value
          .applyFavorite(item.serverId, item.path, value);
    }
  }

  Future<NasBatchResult> runBatch(
    List<NasMediaItem> items, {
    required NasBatchOperation operation,
    String? playlistId,
  }) async {
    if (items.isEmpty || items.length > 1000) {
      throw ArgumentError('NAS_BATCH_SIZE_INVALID');
    }
    final id = items.first.serverId;
    if (items.any((item) => item.serverId != id)) {
      throw ArgumentError('NAS_SOURCE_MISMATCH');
    }
    final playlistOperation =
        operation == NasBatchOperation.addToPlaylist ||
        operation == NasBatchOperation.removeFromPlaylist;
    if (playlistOperation &&
        (playlistId == null || playlistId.trim().isEmpty)) {
      throw ArgumentError('NAS_PLAYLIST_ENTRY_REQUIRED');
    }
    if (!_batchSources.add(id)) throw StateError('NAS_BATCH_IN_PROGRESS');
    final source = _source(id);
    final unique = <(String, String?), NasMediaItem>{};
    for (final item in items) {
      unique[(
            item.path,
            operation == NasBatchOperation.removeFromPlaylist
                ? item.playlistEntryId
                : null,
          )] =
          item;
    }
    final targets = unique.values.toList();
    final results = List<NasBatchItemResult?>.filled(targets.length, null);
    var next = 0;
    try {
      final adapter = await ref.read(nasSourceAdapterProvider(id).future);
      final repository = await _repository;
      Future<void> worker() async {
        while (next < targets.length) {
          final index = next++;
          final item = targets[index];
          if (!_sameSource(source)) {
            results[index] = NasBatchItemResult(
              item,
              errorCode: 'NAS_BATCH_SOURCE_CHANGED',
            );
            continue;
          }
          try {
            await _applyItemOperation(
              adapter,
              repository,
              item,
              operation,
              source: source,
              playlistId: playlistId,
            );
            results[index] = NasBatchItemResult(item);
          } catch (error) {
            results[index] = NasBatchItemResult(
              item,
              errorCode: error is StateError && error.message == 'NAS_BATCH_SOURCE_CHANGED'
                  ? 'NAS_BATCH_SOURCE_CHANGED' : 'NAS_BATCH_ITEM_FAILED',
            );
          }
        }
      }

      // Playlist APIs append by arrival order; preserve the user's selected order.
      await Future.wait(
        List.generate(playlistOperation ? 1 : 3, (_) => worker()),
      );
    } catch (_) {
      for (var i = 0; i < targets.length; i++) {
        results[i] ??= NasBatchItemResult(
          targets[i],
          errorCode: 'NAS_BATCH_ITEM_FAILED',
        );
      }
    } finally {
      _batchSources.remove(id);
    }
    final result = NasBatchResult(
      sourceId: id,
      operation: operation,
      playlistId: playlistId,
      results: List.unmodifiable(results.cast<NasBatchItemResult>()),
    );
    if (source != null) _batchOrigins[result] = source;
    if (ref.mounted &&
        state.serverId == id &&
        ref.read(nasSourcesProvider).selected == source &&
        result.successCount > 0) {
      await refresh();
      if (ref.mounted) ref.invalidate(nasHomeProvider);
    }
    return result;
  }

  Future<NasBatchResult> retryBatch(NasBatchResult result) {
    if (result.failedItems.isEmpty) return Future.value(result);
    if (!_sameSource(_batchOrigins[result])) {
      return Future.error(StateError('NAS_BATCH_SOURCE_CHANGED'));
    }
    return runBatch(
      result.failedItems,
      operation: result.operation,
      playlistId: result.playlistId,
    );
  }

  Future<void> createPlaylist(String name) async {
    final id = state.serverId, trimmed = name.trim();
    if (id == null || trimmed.isEmpty) return;
    final adapter = await ref.read(nasSourceAdapterProvider(id).future);
    if (adapter.source.isMediaServer) {
      await adapter.createPlaylist(trimmed);
    } else {
      final now = DateTime.now();
      await (await _repository).createPlaylist(
        NasPlaylist(
          id: '$id-${now.microsecondsSinceEpoch}',
          serverId: id,
          name: trimmed,
          createdAt: now,
        ),
      );
    }
    if (ref.mounted && state.serverId == id) await refresh();
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final id = state.serverId;
    if (id == null || name.trim().isEmpty) return;
    final adapter = await ref.read(nasSourceAdapterProvider(id).future);
    if (adapter.source.isMediaServer) {
      await adapter.renamePlaylist(playlistId, name.trim());
    } else {
      await (await _repository).renamePlaylist(id, playlistId, name.trim());
    }
    if (ref.mounted && state.serverId == id) await refresh();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final id = state.serverId;
    if (id == null) return;
    final adapter = await ref.read(nasSourceAdapterProvider(id).future);
    if (adapter.source.isMediaServer) {
      await adapter.deletePlaylist(playlistId);
    } else {
      await (await _repository).deletePlaylist(id, playlistId);
    }
    if (!ref.mounted || state.serverId != id) return;
    if (state.playlistId == playlistId) {
      state = state.copyWith(clearScope: true);
    }
    if (ref.mounted && state.serverId == id) {
      await refresh(preservePosition: false);
    }
  }

  Future<void> addToPlaylist({
    required String playlistId,
    required NasMediaItem item,
    int? position,
  }) async {
    final source = _source(item.serverId);
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    await _applyItemOperation(
      adapter,
      await _repository,
      item,
      NasBatchOperation.addToPlaylist,
      source: source,
      playlistId: playlistId,
      position: position,
    );
    if (_sameSource(source) && state.serverId == item.serverId) await refresh();
  }

  Future<void> removeFromPlaylist(String playlistId, NasMediaItem item) async {
    final source = _source(item.serverId);
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    await _applyItemOperation(
      adapter,
      await _repository,
      item,
      NasBatchOperation.removeFromPlaylist,
      source: source,
      playlistId: playlistId,
    );
    if (_sameSource(source) && state.serverId == item.serverId) await refresh();
  }

  /// Moves to a zero-based global playlist ordinal, not a page-relative index.
  Future<void> movePlaylistItem(
    String playlistId,
    NasMediaItem item,
    int index,
  ) async {
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    if (adapter.source.isMediaServer) {
      if (item.playlistEntryId == null) {
        throw StateError('NAS_PLAYLIST_ENTRY_REQUIRED');
      }
      await adapter.movePlaylistItem(playlistId, item.playlistEntryId!, index);
    } else {
      await (await _repository).movePlaylistItem(
        item.serverId,
        playlistId,
        item.path,
        index,
      );
    }
    if (ref.mounted && state.serverId == item.serverId) {
      await refresh(preservePosition: false);
    }
  }

  Future<void> _loadPlaylistPage(
    int epoch, {
    bool reset = false,
    bool previous = false,
    bool reload = false,
  }) async {
    final id = state.serverId!, playlistId = state.playlistId!;
    final anchor = reset
        ? (position: null, offset: 0)
        : reload
        ? _playlistAnchors.last
        : previous
        ? _playlistAnchors[_playlistAnchors.length - 2]
        : (
            position: _playlistPosition,
            offset: state.playlistOffset + state.items.length,
          );
    final adapter = await ref.read(nasSourceAdapterProvider(id).future);
    if (!ref.mounted || epoch != _epoch) return;
    final List<NasMediaItem> items;
    final bool more;
    int? nextPosition;
    if (adapter.source.isMediaServer) {
      _playlistCancellation?.cancel();
      final old = _remotePlaylist;
      _remotePlaylist = null;
      await old?.cancel();
      if (!ref.mounted || epoch != _epoch) return;
      _playlistCancellation = NasCancellation();
      final iterator = _remotePlaylist = StreamIterator(
        adapter.playlistItems(
          playlistId,
          _playlistCancellation!,
          startIndex: anchor.offset,
        ),
      );
      more = await iterator.moveNext();
      items = more ? iterator.current : [];
    } else {
      final page = await (await _repository).playlistMediaPage(
        id,
        playlistId,
        afterPosition: anchor.position,
        limit: _pageSize,
      );
      items = page.items;
      more = page.hasMore;
      nextPosition = page.nextPosition;
    }
    if (!ref.mounted || epoch != _epoch) return;
    // A remote iterator reports exhaustion on the request after its last page.
    // Keep that last page visible instead of adding an empty history entry.
    if (reload && items.isEmpty && anchor.offset > 0) {
      await _loadPlaylistPage(epoch, reset: true);
      return;
    }
    if (!reset && !previous && !reload && items.isEmpty) {
      state = state.copyWith(hasMore: false, isLoading: false);
      return;
    }
    final progress = await _playbackForVisible(id, items);
    if (!ref.mounted || epoch != _epoch) return;
    _playlistPosition = nextPosition;
    _remotePlaylistOffset = anchor.offset + items.length;
    if (previous) {
      _playlistAnchors.removeLast();
    } else if (!reload || reset) {
      if (reset) _playlistAnchors.clear();
      _playlistAnchors.add(anchor);
      if (_playlistAnchors.length > 256) _playlistAnchors.removeAt(0);
    }
    state = state.copyWith(
      items: items,
      playbackByPath: progress,
      hasMore: more,
      hasPrevious: _playlistAnchors.length > 1,
      playlistOffset: anchor.offset,
      isLoading: false,
    );
  }
}
