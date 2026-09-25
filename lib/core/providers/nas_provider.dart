import 'dart:async';

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
  );
  ref.onDispose(service.dispose);
  return service;
});
final nasDownloadsProvider = StreamProvider<List<NasDownloadTask>>((
  ref,
) async* {
  final service = ref.watch(nasDownloadServiceProvider);
  yield service.tasks;
  yield* service.changes;
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
  final DateTime? lastScan;
  final bool isLoading, isScanning, hasMore, hasPrevious, favoritesOnly;
  final String? errorCode, folder, artist, album, playlistId;
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
    totals: totals ?? this.totals,
    scannedCount: scannedCount ?? this.scannedCount,
    matchingCount: matchingCount ?? this.matchingCount,
    playlistOffset: clearScope ? 0 : playlistOffset ?? this.playlistOffset,
  );
}

final nasProvider = NotifierProvider<NasNotifier, NasState>(NasNotifier.new);

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
  Future<NasIndexRepository> get _repository =>
      ref.read(nasIndexRepositoryProvider.future);

  @override
  NasState build() {
    final source = ref.watch(nasSourcesProvider.select((s) => s.selected));
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
    return NasState(
      serverId: source?.id,
      config: config,
      lastScan: source == null ? null : storage.getNasLastScan(source.id),
    );
  }

  Future<NasIndexPage> _page(String id, NasIndexCursor? cursor) async =>
      (await _repository).queryPage(
        id,
        kind: state.filter,
        search: state.search,
        favoritesOnly: state.favoritesOnly,
        folder: state.folder,
        artist: state.artist,
        album: state.album,
        cursor: cursor,
        limit: _pageSize,
      );

  Future<void> refresh() async {
    final id = state.serverId;
    if (id == null) return;
    final epoch = ++_epoch;
    _anchors.clear();
    _playlistAnchors.clear();
    _nextCursor = null;
    _playlistPosition = null;
    _remotePlaylistOffset = 0;
    _playlistCancellation?.cancel();
    final previousPlaylist = _remotePlaylist;
    _remotePlaylist = null;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      playlistOffset: 0,
      hasPrevious: false,
    );
    await previousPlaylist?.cancel();
    if (!ref.mounted || epoch != _epoch) return;
    try {
      final repository = await _repository;
      final source = ref.read(nasSourcesProvider).selected;
      final playlists = source?.isMediaServer == true
          ? await (await ref.read(
              nasSourceAdapterProvider(id).future,
            )).playlists()
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
      );
      if (!ref.mounted || epoch != _epoch) return;
      state = state.copyWith(
        playlists: playlists,
        totals: totals,
        matchingCount: matching,
      );
      if (state.playlistId != null) {
        await _loadPlaylistPage(epoch, reset: true);
      } else {
        final page = await _page(id, null);
        if (!ref.mounted || epoch != _epoch) return;
        _nextCursor = page.nextCursor;
        _anchors.add(null);
        state = state.copyWith(
          items: page.items,
          hasMore: page.hasMore,
          hasPrevious: false,
          isLoading: false,
        );
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

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.serverId == null) return;
    final epoch = _epoch;
    state = state.copyWith(isLoading: true);
    try {
      if (state.playlistId != null) {
        await _loadPlaylistPage(epoch);
        return;
      }
      final cursor = _nextCursor;
      final page = await _page(state.serverId!, cursor);
      if (!ref.mounted || epoch != _epoch) return;
      _anchors.add(cursor);
      if (_anchors.length > 256) _anchors.removeAt(0);
      _nextCursor = page.nextCursor;
      state = state.copyWith(
        items: page.items,
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
    if (state.isLoading || !state.hasPrevious || state.serverId == null) {
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(isLoading: true);
    try {
      if (state.playlistId != null) {
        await _loadPlaylistPage(epoch, previous: true);
        return;
      }
      final page = await _page(state.serverId!, _anchors[_anchors.length - 2]);
      if (!ref.mounted || epoch != _epoch) return;
      _anchors.removeLast();
      _nextCursor = page.nextCursor;
      state = state.copyWith(
        items: page.items,
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

  Future<void> setFilter(NasMediaKind? value) async {
    state = state.copyWith(
      filter: value,
      clearFilter: value == null,
      clearScope: true,
      favoritesOnly: false,
      items: [],
    );
    await refresh();
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value.trim(), items: []);
    await refresh();
  }

  Future<void> setFavoritesOnly(bool value) async {
    state = state.copyWith(favoritesOnly: value, clearScope: true, items: []);
    await refresh();
  }

  Future<void> setScope({
    String? folder,
    String? artist,
    String? album,
    String? playlistId,
  }) async {
    state = state
        .copyWith(clearScope: true)
        .copyWith(
          folder: folder,
          artist: artist,
          album: album,
          playlistId: playlistId,
          items: [],
        );
    await refresh();
  }

  Future<List<NasIndexGroupCount>> groups(
    NasIndexGroup group, {
    String? after,
  }) async {
    final id = state.serverId;
    return id == null
        ? []
        : (await _repository).groups(id, group, after: after, limit: 200);
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
    final cancellation = NasCancellation();
    _scanCancellation = cancellation;
    final config = state.config;
    state = state.copyWith(isScanning: true, scannedCount: 0, clearError: true);
    try {
      final adapter = await ref.read(nasSourceAdapterProvider(id).future);
      final repository = await _repository;
      cancellation.check();
      final generation = await repository.beginScan(id);
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
        if (!ref.mounted || state.serverId != id) {
          cancellation.cancel();
          break;
        }
        state = state.copyWith(scannedCount: count);
        if (DateTime.now().difference(lastRefresh).inSeconds >= 2 &&
            !state.isLoading &&
            _anchors.length <= 1) {
          lastRefresh = DateTime.now();
          await refresh();
        }
      }
      cancellation.check();
      await repository.finishScan(id, generation, cancellation: cancellation);
      final now = DateTime.now();
      await ref.read(localStorageServiceProvider).saveNasLastScan(id, now);
      if (ref.mounted && state.serverId == id) {
        state = state.copyWith(lastScan: now);
        await refresh();
      }
    } catch (_) {
      if (ref.mounted && state.serverId == id) {
        state = state.copyWith(
          errorCode: cancellation.isCancelled
              ? 'NAS_SCAN_CANCELLED'
              : 'NAS_SCAN_FAILED',
        );
      }
    } finally {
      if (ref.mounted && _scanCancellation == cancellation) {
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
    final folder = state.folder, artist = state.artist, album = state.album;
    var hasMore = sameSource && state.hasMore;
    final playlistId = sameSource ? state.playlistId : null;
    var playlistPosition = _playlistPosition;
    var playlistOffset = _remotePlaylistOffset;
    final cancellation = NasCancellation();
    StreamIterator<List<NasMediaItem>>? playlist;
    final adapter = await ref.read(nasSourceAdapterProvider(sourceId).future);
    final repository = await _repository;
    Future<List<NasMediaItem>> loadPage() async {
      while (hasMore) {
        cancellation.check();
        if (playlistId != null) {
          if (adapter.source.isMediaServer) {
            playlist ??= StreamIterator(
              adapter.playlistItems(
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
          cursor: cursor,
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

  String openExternal(NasMediaItem item) =>
      ref.read(nasDownloadServiceProvider).download(item, openWhenDone: true);
  String download(NasMediaItem item) =>
      ref.read(nasDownloadServiceProvider).download(item);
  Future<void> setOpenPolicy(NasMediaKind kind, NasOpenPolicy policy) =>
      ref.read(localStorageServiceProvider).saveNasOpenPolicy(kind, policy);
  Future<String?> thumbnailPath(NasMediaItem item) =>
      ref.read(nasImageCacheProvider).thumbnail(item);
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
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    if (adapter.source.isMediaServer) await adapter.setFavorite(item, value);
    final repository = await _repository;
    await repository.setFavorite(item.serverId, item.path, value);
    if (ref.mounted && ref.exists(nasMediaPlayerProvider)) {
      ref
          .read(nasMediaPlayerProvider)
          .asData
          ?.value
          .applyFavorite(item.serverId, item.path, value);
    }
    final totals = await repository.totals(item.serverId);
    if (!ref.mounted || state.serverId != item.serverId) return;
    state = state.copyWith(
      items: [
        for (final e in state.items)
          if (!state.favoritesOnly || e.path != item.path || value)
            e.path == item.path ? e.copyWith(isFavorite: value) : e,
      ],
      totals: totals,
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
    await refresh();
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
    await refresh();
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
    if (state.playlistId == playlistId) {
      state = state.copyWith(clearScope: true);
    }
    await refresh();
  }

  Future<void> addToPlaylist({
    required String playlistId,
    required NasMediaItem item,
    int? position,
  }) async {
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    if (adapter.source.isMediaServer) {
      await adapter.addToPlaylist(playlistId, item);
    } else {
      await (await _repository).addToPlaylist(
        serverId: item.serverId,
        playlistId: playlistId,
        path: item.path,
      );
    }
    await refresh();
  }

  Future<void> removeFromPlaylist(String playlistId, NasMediaItem item) async {
    final adapter = await ref.read(
      nasSourceAdapterProvider(item.serverId).future,
    );
    if (adapter.source.isMediaServer) {
      if (item.playlistEntryId == null) {
        throw StateError('NAS_PLAYLIST_ENTRY_REQUIRED');
      }
      await adapter.removeFromPlaylist(playlistId, item.playlistEntryId!);
    } else {
      await (await _repository).removeFromPlaylist(
        item.serverId,
        playlistId,
        item.path,
      );
    }
    await refresh();
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
    await refresh();
  }

  Future<void> _loadPlaylistPage(
    int epoch, {
    bool reset = false,
    bool previous = false,
  }) async {
    final id = state.serverId!, playlistId = state.playlistId!;
    final anchor = reset
        ? (position: null, offset: 0)
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
    if (!reset && !previous && items.isEmpty) {
      state = state.copyWith(hasMore: false, isLoading: false);
      return;
    }
    _playlistPosition = nextPosition;
    _remotePlaylistOffset = anchor.offset + items.length;
    if (previous) {
      _playlistAnchors.removeLast();
    } else {
      if (reset) _playlistAnchors.clear();
      _playlistAnchors.add(anchor);
      if (_playlistAnchors.length > 256) _playlistAnchors.removeAt(0);
    }
    state = state.copyWith(
      items: items,
      hasMore: more,
      hasPrevious: _playlistAnchors.length > 1,
      playlistOffset: anchor.offset,
      isLoading: false,
    );
  }
}
