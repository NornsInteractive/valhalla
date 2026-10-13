import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _remote = NasSource(
  id: 'a',
  name: 'Remote',
  type: NasSourceType.jellyfin,
);
const _local = NasSource(id: 'a', name: 'Local', type: NasSourceType.sftp);
const _other = NasSource(id: 'b', name: 'Other', type: NasSourceType.sftp);

NasMediaItem _item(int number, {String source = 'a', bool favorite = false}) =>
    NasMediaItem(
      serverId: source,
      path: '/album/song${number.toString().padLeft(4, '0')}.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: number % 5,
      modifiedEpoch: number % 7,
      isFavorite: favorite,
    );

class _Sources extends NasSourcesNotifier {
  _Sources(this.initial);
  final List<NasSource> initial;
  @override
  NasSourcesState build() =>
      NasSourcesState(sources: initial, selectedId: initial.first.id);
  @override
  Future<void> select(String id) async =>
      state = NasSourcesState(sources: state.sources, selectedId: id);
  void replace(NasSource replacement) => state = NasSourcesState(
    sources: [
      for (final value in state.sources)
        value.id == replacement.id ? replacement : value,
    ],
    selectedId: state.selectedId,
  );
}

class _Repository extends NasIndexRepository {
  _Repository(super.databasePath);
  int pageReads = 0;
  @override
  Future<NasIndexPage> queryPage(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
    NasIndexCursor? cursor,
    bool before = false,
    bool inclusive = false,
    NasSortKey sortKey = NasSortKey.modified,
    bool sortAscending = false,
    int limit = 200,
  }) {
    pageReads++;
    return super.queryPage(
      serverId,
      kind: kind,
      search: search,
      favoritesOnly: favoritesOnly,
      folder: folder,
      artist: artist,
      album: album,
      albumKey: albumKey,
      modifiedFromEpoch: modifiedFromEpoch,
      modifiedBeforeEpoch: modifiedBeforeEpoch,
      cursor: cursor,
      before: before,
      inclusive: inclusive,
      sortKey: sortKey,
      sortAscending: sortAscending,
      limit: limit,
    );
  }
}

class _Adapter extends NasSourceAdapter {
  _Adapter(this.source);
  @override
  final NasSource source;
  final calls = <String>[];
  final failures = <String>{};
  final members = <NasMediaItem>[];
  final began = Completer<void>();
  Completer<void>? gate;
  int active = 0, maximumActive = 0, playlistsRead = 0;
  Object? playlistError;
  Completer<void>? playlistGate;
  Future<void> _run(String operation, String path) async {
    calls.add('$operation:$path');
    active++;
    maximumActive = max(maximumActive, active);
    if (active == 3 && !began.isCompleted) began.complete();
    try {
      await gate?.future;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (failures.remove(path)) throw StateError('FIXTURE_FAILURE');
    } finally {
      active--;
    }
  }

  @override
  Future<void> setFavorite(NasMediaItem item, bool value) =>
      _run('favorite', item.path);
  @override
  Future<void> addToPlaylist(String id, NasMediaItem item) async {
    await _run('add', item.path);
    members.add(item.copyWith(playlistEntryId: 'entry-${item.path}'));
  }

  @override
  Future<void> removeFromPlaylist(String id, String entryId) async {
    await _run('remove', entryId);
    members.removeWhere((item) => item.playlistEntryId == entryId);
  }

  @override
  Future<List<NasPlaylist>> playlists() async {
    playlistsRead++;
    await playlistGate?.future;
    if (playlistError != null) throw playlistError!;
    return [
      NasPlaylist(
        id: 'p',
        serverId: source.id,
        name: 'Playlist',
        createdAt: DateTime(2026),
        itemCount: members.length,
      ),
    ];
  }

  @override
  Stream<List<NasMediaItem>> playlistItems(
    String id,
    NasCancellation cancellation, {
    int startIndex = 0,
  }) async* {
    if (startIndex < members.length) {
      yield members.skip(startIndex).take(200).toList();
    }
  }

  @override
  Future<void> probe() async {}
  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) => const Stream.empty();
  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async =>
      NasResource(uri: Uri.parse('http://fixture.invalid/never-requested'));
}

class _Player implements NasMediaPlayerService {
  int favoriteUpdates = 0;
  @override
  void applyFavorite(String sourceId, String path, bool value) =>
      favoriteUpdates++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _until(
  ProviderContainer container,
  bool Function(NasState) predicate,
) async {
  if (predicate(container.read(nasProvider))) return;
  final done = Completer<void>();
  final subscription = container.listen(nasProvider, (_, value) {
    if (!done.isCompleted && predicate(value)) done.complete();
  });
  try {
    await done.future.timeout(const Duration(seconds: 10));
  } finally {
    subscription.close();
  }
}

Future<
  ({
    ProviderContainer container,
    _Sources sources,
    _Repository repository,
    Map<String, _Adapter> adapters,
    _Player player,
  })
>
_fixture(
  List<NasSource> sources,
  List<NasMediaItem> items, {
  Object? playlistError,
  Completer<void>? playlistGate,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  final directory = await Directory.systemTemp.createTemp(
    'valhalla-nas-organization-',
  );
  final repository = _Repository('${directory.path}/index.sqlite3');
  await repository.initialize();
  for (final source in sources) {
    final generation = await repository.beginScan(source.id);
    await repository.upsertBatch(
      source.id,
      items.where((item) => item.serverId == source.id).toList(),
      generation,
      syncFavorites: true,
    );
    await repository.finishScan(source.id, generation);
  }
  final notifier = _Sources(sources);
  final adapters = {for (final source in sources) source.id: _Adapter(source)};
  for (final adapter in adapters.values) {
    adapter.playlistError = playlistError;
    adapter.playlistGate = playlistGate;
  }
  final player = _Player();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      nasSourcesProvider.overrideWith(() => notifier),
      nasIndexRepositoryProvider.overrideWith((ref) async => repository),
      nasMediaPlayerProvider.overrideWith((ref) async => player),
      nasSourceAdapterProvider.overrideWith((ref, id) async => adapters[id]!),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await directory.delete(recursive: true);
  });
  await _until(
    container,
    (state) =>
        !state.isLoading &&
        ((playlistError != null && state.errorCode != null) ||
            state.matchingCount ==
                items
                    .where((item) => item.serverId == sources.first.id)
                    .length),
  );
  return (
    container: container,
    sources: notifier,
    repository: repository,
    adapters: adapters,
    player: player,
  );
}

String _name(NasMediaItem item) =>
    (item.title?.isNotEmpty == true ? item.title! : item.name).toLowerCase();
int _compare(NasMediaItem a, NasMediaItem b, NasSortKey key, bool ascending) {
  final value = switch (key) {
    NasSortKey.modified => a.modifiedEpoch.compareTo(b.modifiedEpoch),
    NasSortKey.name => _name(a).compareTo(_name(b)),
    NasSortKey.size => a.sizeBytes.compareTo(b.sizeBytes),
  };
  if (value != 0) return ascending ? value : -value;
  final path = a.path.compareTo(b.path);
  return (key == NasSortKey.modified ? !ascending : ascending) ? path : -path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  test(
    'cached media index remains visible when remote playlists are unavailable at startup',
    () async {
      final f = await _fixture(
        [_remote],
        List.generate(3, _item),
        playlistError: const SocketException(
          'fixture media endpoint unavailable',
        ),
      );
      expect((await f.repository.totals('a')).total, 3);
      expect((await f.repository.queryPage('a')).items, hasLength(3));
      final state = f.container.read(nasProvider);
      expect(
        state.items,
        hasLength(3),
        reason:
            'An optional remote playlist lookup must not block cached local items. Actual error: ${state.errorCode}',
      );
      await _until(
        f.container,
        (state) => state.errorCode == 'NAS_PLAYLIST_LOAD_FAILED',
      );
      expect(f.container.read(nasProvider).items, hasLength(3));
    },
  );

  test('slow remote playlists do not delay local refresh completion', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final f = await _fixture(
      [_remote],
      List.generate(3, _item),
      playlistGate: gate,
    );
    await f.container
        .read(nasProvider.notifier)
        .refresh()
        .timeout(const Duration(seconds: 5));
    expect(gate.isCompleted, isFalse);
    expect(f.container.read(nasProvider).isLoading, isFalse);
    expect(f.container.read(nasProvider).items, hasLength(3));
    gate.complete();
    await _until(f.container, (state) => state.playlists.isNotEmpty);
    expect(f.container.read(nasProvider).errorCode, isNull);
  });

  test(
    'remote playlist failure retains known lists and explicit refresh recovers',
    () async {
      final f = await _fixture([_remote], List.generate(3, _item));
      await _until(f.container, (state) => state.playlists.isNotEmpty);
      final known = f.container.read(nasProvider).playlists;
      final adapter = f.adapters['a']!;
      adapter.playlistError = const SocketException('fixture offline');
      await f.container.read(nasProvider.notifier).refresh();
      await _until(
        f.container,
        (state) => state.errorCode == 'NAS_PLAYLIST_LOAD_FAILED',
      );
      expect(f.container.read(nasProvider).playlists, same(known));
      expect(f.container.read(nasProvider).items, hasLength(3));
      adapter.playlistError = null;
      await f.container.read(nasProvider.notifier).refresh();
      await _until(f.container, (state) => !identical(state.playlists, known));
      expect(f.container.read(nasProvider).errorCode, isNull);
      expect(f.container.read(nasProvider).items, hasLength(3));
    },
  );

  test(
    'late remote playlist failure cannot mark the next source as failed',
    () async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final f = await _fixture(
        [_remote, _other],
        [_item(1), _item(2, source: 'b')],
        playlistGate: gate,
      );
      await f.sources.select('b');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'b' && !state.isLoading && state.items.isNotEmpty,
      );
      f.adapters['a']!.playlistError = const SocketException(
        'stale offline response',
      );
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(f.container.read(nasProvider).serverId, 'b');
      expect(f.container.read(nasProvider).items.single.serverId, 'b');
      expect(f.container.read(nasProvider).errorCode, isNull);
    },
  );

  for (final key in NasSortKey.values) {
    for (final ascending in [true, false]) {
      test(
        '${key.name} $ascending uses stable keyset ties and bounds each page',
        () async {
          final items = List.generate(
            31,
            (index) => _item(index).copyWith(
              title: index.isEven ? 'ALPHA' : 'beta',
              sourcePath: '/real/${index.isEven ? '乙' : '甲'}.mp3',
            ),
          );
          final fixture = await _fixture([_local], items);
          final expected = [...items]
            ..sort((a, b) => _compare(a, b, key, ascending));
          final actual = <NasMediaItem>[];
          NasIndexCursor? cursor;
          var more = true;
          for (var page = 0; more && page < 20; page++) {
            final value = await fixture.repository.queryPage(
              'a',
              sortKey: key,
              sortAscending: ascending,
              cursor: cursor,
              limit: 3,
            );
            expect(value.items.length, lessThanOrEqualTo(3));
            actual.addAll(value.items);
            cursor = value.nextCursor;
            more = value.hasMore;
          }
          expect(more, false);
          expect(
            actual.map((item) => item.path),
            expected.map((item) => item.path),
          );
          expect(actual.map((item) => item.path).toSet().length, items.length);
          await expectLater(
            fixture.repository.queryPage(
              'a',
              sortKey: key,
              sortAscending: !ascending,
              cursor: cursor,
            ),
            throwsArgumentError,
          );
        },
      );
    }
  }

  test(
    'gallery window load more and previous trim correctly with 850 items',
    () async {
      final items = List.generate(
        850,
        (index) => NasMediaItem(
          serverId: 'a',
          path: '/photo/desc${index.toString().padLeft(4, '0')}.jpg',
          kind: NasMediaKind.image,
          sizeBytes: index % 100,
          modifiedEpoch: index % 50,
          width: 800,
          height: 600,
          mimeType: 'image/jpeg',
        ),
      );
      final fixture = await _fixture([_local], items);
      final notifier = fixture.container.read(nasProvider.notifier);
      await notifier.selectCategory('photos', filter: NasMediaKind.image);
      await notifier.setSort(NasSortKey.name, ascending: true);
      await notifier.enableGalleryWindow(true);
      // Initial load: 200 items (galleryLength = _pageSize = 200 when retainGallery=false)
      expect(notifier.state.items.length, 200);
      final initialPaths = notifier.state.items.map((i) => i.path).toList();
      expect(initialPaths.length, 200);
      expect(initialPaths, equals(items.sublist(0, 200).map((i) => i.path)));
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.hasPrevious, isFalse);
      // First loadMore: adds next batch, total 400
      await notifier.loadGalleryNext();
      expect(notifier.state.items.length, 400);
      final secondPaths = notifier.state.items.map((i) => i.path).toList();
      expect(secondPaths.length, 400);
      expect(secondPaths, equals(items.sublist(0, 400).map((i) => i.path)));
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.hasPrevious, isFalse);
      // Second loadMore: adds next batch, total 600
      await notifier.loadGalleryNext();
      expect(notifier.state.items.length, 600);
      final thirdPaths = notifier.state.items.map((i) => i.path).toList();
      expect(thirdPaths.length, 600);
      expect(thirdPaths, equals(items.sublist(0, 600).map((i) => i.path)));
      // Third loadMore: exceeds 600, trimmed to 600 with trimBefore=200, items from 200-799
      await notifier.loadGalleryNext();
      expect(notifier.state.items.length, 600);
      final fourthPaths = notifier.state.items.map((i) => i.path).toList();
      expect(fourthPaths.length, 600);
      expect(fourthPaths, equals(items.sublist(200, 800).map((i) => i.path)));
      await notifier.loadGalleryNext();
      expect(notifier.state.items.length, 600);
      final fourthPaths2 = notifier.state.items.map((i) => i.path).toList();
      expect(fourthPaths2.length, 600);
      expect(fourthPaths2, equals(items.sublist(250, 850).map((i) => i.path)));
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.hasPrevious, isTrue);
      expect(notifier.state.hasPrevious, isTrue);
      // loadPrevious: trimmedAfter=200, items from 50-649
      await notifier.loadGalleryPrevious();
      expect(notifier.state.items.length, 600);
      final fifthPaths = notifier.state.items.map((i) => i.path).toList();
      expect(fifthPaths.length, 600);
      expect(fifthPaths, equals(items.sublist(50, 650).map((i) => i.path)));
      // loadPrevious again: trimmedAfter=50, items from 0-599
      await notifier.loadGalleryPrevious();
      expect(notifier.state.items.length, 600);
      final sixthPaths = notifier.state.items.map((i) => i.path).toList();
      expect(sixthPaths.length, 600);
      expect(sixthPaths, equals(items.sublist(0, 600).map((i) => i.path)));

      expect(notifier.state.hasPrevious, isFalse);
      expect(notifier.state.hasMore, isTrue);
    },
  );

  test(
    'default legacy cursor and metadata refresh preserve compatible order',
    () async {
      final fixture = await _fixture([_local], [_item(0), _item(1), _item(2)]);
      final first = await fixture.repository.queryPage('a', limit: 1);
      final legacy = NasIndexCursor(
        first.items.single.modifiedEpoch,
        first.items.single.path,
      );
      expect(
        (await fixture.repository.queryPage(
          'a',
          cursor: legacy,
        )).items.map((item) => item.path),
        [_item(1).path, _item(0).path],
      );
      await fixture.repository.updateMetadata(_item(0).copyWith(title: 'AAA'));
      await fixture.repository.completeMetadataProbe(
        _item(1),
        metadata: _item(1).copyWith(title: 'ZZZ'),
      );
      final named = await fixture.repository.queryPage(
        'a',
        sortKey: NasSortKey.name,
        sortAscending: true,
      );
      expect(named.items.first.path, _item(0).path);
      expect(named.items.last.path, _item(1).path);
    },
  );

  test(
    'favorite batches use at most three workers, refresh once, retry failures only',
    () async {
      final items = List.generate(7, _item);
      final f = await _fixture([_remote], items);
      final adapter = f.adapters['a']!;
      adapter.gate = Completer<void>();
      adapter.failures.addAll([items[1].path, items[5].path]);
      final notifier = f.container.read(nasProvider.notifier);
      final reads = f.repository.pageReads;
      final operation = notifier.runBatch(
        items,
        operation: NasBatchOperation.favorite,
      );
      await adapter.began.future.timeout(const Duration(seconds: 5));
      final active = adapter.active;
      adapter.gate!.complete();
      final result = await operation;
      expect(active, 3);
      expect(adapter.maximumActive, 3);
      expect(result.successCount, 5);
      expect(result.failedItems.map((item) => item.path), [
        items[1].path,
        items[5].path,
      ]);
      expect(f.repository.pageReads - reads, 1);
      final retry = await notifier.retryBatch(result);
      expect(retry.failedItems, isEmpty);
      expect(retry.successCount, 2);
      expect(adapter.calls.length, 9);
      for (final item in items) {
        expect(
          adapter.calls.where((call) => call == 'favorite:${item.path}').length,
          item == items[1] || item == items[5] ? 2 : 1,
        );
      }
      expect((await f.repository.totals('a')).favorites, 7);
      expect(f.repository.pageReads - reads, 2);
    },
  );

  test(
    'remote playlist add/remove is ordered and uses membership identity',
    () async {
      final items = List.generate(5, _item);
      final f = await _fixture([_remote], items);
      final notifier = f.container.read(nasProvider.notifier);
      final adapter = f.adapters['a']!;
      final added = await notifier.runBatch(
        items,
        operation: NasBatchOperation.addToPlaylist,
        playlistId: 'p',
      );
      expect(added.successCount, 5);
      expect(adapter.maximumActive, 1);
      expect(
        adapter.members.map((item) => item.path),
        items.map((item) => item.path),
      );
      final selected = adapter.members.take(2).toList();
      final removed = await notifier.runBatch(
        selected,
        operation: NasBatchOperation.removeFromPlaylist,
        playlistId: 'p',
      );
      expect(removed.successCount, 2);
      expect(
        adapter.calls.skip(5),
        selected.map((item) => 'remove:${item.playlistEntryId}'),
      );
      expect(adapter.members.length, 3);
    },
  );

  test(
    'local missing or wrong-owner playlists fail; insertion position is honored',
    () async {
      final items = [_item(0), _item(1), _item(2)];
      final f = await _fixture([_local, _other], items);
      final notifier = f.container.read(nasProvider.notifier);
      await f.repository.createPlaylist(
        NasPlaylist(
          id: 'foreign',
          serverId: 'b',
          name: 'Other',
          createdAt: DateTime(2026),
        ),
      );
      for (final id in ['missing', 'foreign']) {
        for (final operation in [
          NasBatchOperation.addToPlaylist,
          NasBatchOperation.removeFromPlaylist,
        ]) {
          final result = await notifier.runBatch(
            items,
            operation: operation,
            playlistId: id,
          );
          expect(result.successCount, 0);
          expect(result.failedItems.length, 3);
        }
      }
      await f.repository.createPlaylist(
        NasPlaylist(
          id: 'p',
          serverId: 'a',
          name: 'Mine',
          createdAt: DateTime(2026),
        ),
      );
      await notifier.addToPlaylist(playlistId: 'p', item: items[0]);
      await notifier.addToPlaylist(playlistId: 'p', item: items[1]);
      await notifier.addToPlaylist(
        playlistId: 'p',
        item: items[2],
        position: 1,
      );
      expect(await f.repository.playlistItems('a', 'p'), [
        items[0].path,
        items[2].path,
        items[1].path,
      ]);
      await expectLater(
        notifier.runBatch([
          items[0],
          _item(0, source: 'b'),
        ], operation: NasBatchOperation.favorite),
        throwsArgumentError,
      );
      expect(f.adapters['a']!.calls, isEmpty);
    },
  );

  test(
    'changing selected source does not reroute an active batch or replace visible data',
    () async {
      final items = List.generate(6, _item);
      final f = await _fixture(
        [_remote, _other],
        [...items, _item(90, source: 'b')],
      );
      final adapter = f.adapters['a']!..gate = Completer<void>();
      final operation = f.container
          .read(nasProvider.notifier)
          .runBatch(items, operation: NasBatchOperation.favorite);
      await adapter.began.future.timeout(const Duration(seconds: 5));
      await f.sources.select('b');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'b' && !state.isLoading && state.items.isNotEmpty,
      );
      adapter.gate!.complete();
      expect((await operation).successCount, 6);
      expect((await f.repository.totals('b')).favorites, 0);
      expect(
        f.container.read(nasProvider).items.single.path,
        _item(90, source: 'b').path,
      );
      expect(f.adapters['b']!.calls, isEmpty);
    },
  );

  test(
    'same-ID reauthentication after remote success cannot update local index or player',
    () async {
      final items = List.generate(6, _item);
      final f = await _fixture([_remote], items);
      await f.container.read(nasMediaPlayerProvider.future);
      final adapter = f.adapters['a']!..gate = Completer<void>();
      final operation = f.container
          .read(nasProvider.notifier)
          .runBatch(items, operation: NasBatchOperation.favorite);
      await adapter.began.future.timeout(const Duration(seconds: 5));
      f.sources.replace(NasSource.fromJson(_remote.toJson()));
      await f.container.pump();
      adapter.gate!.complete();
      final result = await operation;
      expect(
        result.successCount,
        3,
        reason: 'The three acknowledged remote mutations must not be retried.',
      );
      expect(
        result.results
            .where((result) => !result.succeeded)
            .map((result) => result.errorCode),
        everyElement('NAS_BATCH_SOURCE_CHANGED'),
      );
      expect(adapter.calls.length, 3);
      expect((await f.repository.totals('a')).favorites, 0);
      expect(f.player.favoriteUpdates, 0);
      await expectLater(
        f.container.read(nasProvider.notifier).retryBatch(result),
        throwsStateError,
      );
      expect(
        adapter.calls.length,
        3,
        reason:
            'A retry must not send old-account items to the replacement source.',
      );
      await _until(f.container, (state) => !state.isLoading);
    },
  );

  test(
    'unchanged selected source permits failed-only retry after a source round trip',
    () async {
      final items = [_item(0), _item(1)];
      final f = await _fixture(
        [_remote, _other],
        [...items, _item(2, source: 'b')],
      );
      final adapter = f.adapters['a']!..failures.add(items[1].path);
      final notifier = f.container.read(nasProvider.notifier);
      final result = await notifier.runBatch(
        items,
        operation: NasBatchOperation.favorite,
      );
      await f.sources.select('b');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'b' && !state.isLoading && state.items.isNotEmpty,
      );
      await f.sources.select('a');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'a' && !state.isLoading && state.items.isNotEmpty,
      );
      expect((await notifier.retryBatch(result)).successCount, 1);
      expect(adapter.calls.length, 3);
    },
  );

  test(
    'category and source round trips retain search/sort/page; reauthentication invalidates it',
    () async {
      final f = await _fixture(
        [_local, _other],
        [for (var i = 0; i < 450; i++) _item(i), _item(99, source: 'b')],
      );
      final notifier = f.container.read(nasProvider.notifier);
      await notifier.selectCategory('music', filter: NasMediaKind.audio);
      await notifier.setSearch('album');
      await notifier.setSort(NasSortKey.name, ascending: true);
      await notifier.loadMore();
      final page = f.container
          .read(nasProvider)
          .items
          .map((item) => item.path)
          .toList();
      await notifier.refresh();
      expect(
        f.container.read(nasProvider).items.map((item) => item.path),
        page,
      );
      await notifier.selectCategory('favorites', favoritesOnly: true);
      expect(f.container.read(nasProvider).search, '');
      await notifier.selectCategory('music', filter: NasMediaKind.audio);
      expect(
        f.container.read(nasProvider).items.map((item) => item.path),
        page,
      );
      expect(f.container.read(nasProvider).search, 'album');
      await f.sources.select('b');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'b' && !state.isLoading && state.items.isNotEmpty,
      );
      await f.sources.select('a');
      await _until(
        f.container,
        (state) =>
            state.serverId == 'a' && !state.isLoading && state.items.isNotEmpty,
      );
      expect(f.container.read(nasProvider).browseCategory, 'music');
      expect(f.container.read(nasProvider).sortKey, NasSortKey.name);
      expect(
        f.container.read(nasProvider).items.map((item) => item.path),
        page,
      );
      f.sources.replace(NasSource.fromJson(_local.toJson()));
      await f.container.pump();
      await _until(
        f.container,
        (state) => !state.isLoading && state.browseCategory == 'home',
      );
      expect(f.container.read(nasProvider).search, '');
      await notifier.selectCategory('music', filter: NasMediaKind.audio);
      expect(f.container.read(nasProvider).search, '');
      expect(f.container.read(nasProvider).sortKey, NasSortKey.modified);
      expect(f.container.read(nasProvider).hasPrevious, false);
    },
  );

  test(
    'removing the final favorites page returns a nonempty first page',
    () async {
      final f = await _fixture([
        _local,
      ], List.generate(401, (index) => _item(index, favorite: true)));
      final notifier = f.container.read(nasProvider.notifier);
      await notifier.setFavoritesOnly(true);
      await notifier.loadMore();
      await notifier.loadMore();
      final last = f.container.read(nasProvider).items;
      expect(last.length, 1);
      final result = await notifier.runBatch(
        last,
        operation: NasBatchOperation.unfavorite,
      );
      expect(result.successCount, 1);
      expect(f.container.read(nasProvider).items.length, 200);
      expect(f.container.read(nasProvider).hasPrevious, false);
    },
  );

  test(
    '100000-row legacy index migrates additively and all indexed sorts remain bounded',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-nas-sort-perf-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/legacy.sqlite3';
      final db = sqlite3.open(databasePath);
      db.execute(
        '''CREATE TABLE nas_media(server_id TEXT NOT NULL, path TEXT NOT NULL,
      kind TEXT NOT NULL, size_bytes INTEGER NOT NULL, modified_epoch INTEGER NOT NULL,
      title TEXT, source_path TEXT, is_favorite INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(server_id,path)) STRICT;
      CREATE TABLE nas_playlists(id TEXT PRIMARY KEY, server_id TEXT NOT NULL, name TEXT NOT NULL, created_epoch INTEGER NOT NULL) STRICT;
      CREATE TABLE nas_playlist_items(playlist_id TEXT NOT NULL, path TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(playlist_id,path)) STRICT;
      CREATE TABLE nas_playback(server_id TEXT NOT NULL,path TEXT NOT NULL,position_millis INTEGER NOT NULL,duration_millis INTEGER,updated_epoch INTEGER NOT NULL,PRIMARY KEY(server_id,path)) STRICT;
      CREATE TABLE nas_download_tasks(id TEXT PRIMARY KEY NOT NULL,data TEXT NOT NULL) STRICT;''',
      );
      final insert = db.prepare(
        'INSERT INTO nas_media VALUES(?,?,?,?,?,?,?,?)',
      );
      final seed = Stopwatch()..start();
      db.execute('BEGIN');
      for (var i = 0; i < 100000; i++) {
        insert.execute([
          'a',
          '/$i.mp3',
          'audio',
          i % 200,
          i % 77,
          i.isEven ? '专辑 ${(i % 123).toString().padLeft(3, '0')}' : null,
          '/Audio/歌曲${i.toString().padLeft(6, '0')}.mp3',
          i == 0 ? 1 : 0,
        ]);
      }
      insert.dispose();
      db.execute("INSERT INTO nas_playlists VALUES('p','a','Legacy',123);");
      db.execute("INSERT INTO nas_playlist_items VALUES('p','/0.mp3',0);");
      db.execute("INSERT INTO nas_playback VALUES('a','/0.mp3',321,1000,123);");
      db.execute(
        "INSERT INTO nas_download_tasks VALUES('offline','retained-download-state');",
      );
      db.execute('COMMIT');
      seed.stop();
      db.dispose();
      final repository = NasIndexRepository(databasePath);
      final rss = ProcessInfo.currentRss;
      final migration = Stopwatch()..start();
      await repository.initialize();
      migration.stop();
      expect(await repository.count('a'), 100000);
      expect((await repository.totals('a')).favorites, 1);
      expect(await repository.playlistItems('a', 'p'), ['/0.mp3']);
      expect(
        (await repository.playbackFor('a', '/0.mp3'))!.position.inMilliseconds,
        321,
      );
      final migrated = sqlite3.open(databasePath);
      expect(
        migrated.select('SELECT data FROM nas_download_tasks').single['data'],
        'retained-download-state',
      );
      expect(
        migrated
            .select("SELECT sort_name FROM nas_media WHERE path='/1.mp3'")
            .single['sort_name'],
        '歌曲000001.mp3',
      );
      final timings = <int>[];
      for (final key in NasSortKey.values) {
        final column = switch (key) {
          NasSortKey.modified => 'sort_epoch',
          NasSortKey.name => 'sort_name',
          NasSortKey.size => 'size_bytes',
        };
        final plan = migrated.select(
          'EXPLAIN QUERY PLAN SELECT * FROM nas_media WHERE server_id = ? ORDER BY $column, path LIMIT 200',
          ['a'],
        );
        expect(
          plan.map((row) => row['detail'].toString()).join(' '),
          isNot(contains('USE TEMP B-TREE')),
        );
        for (final ascending in [true, false]) {
          NasIndexCursor? cursor;
          NasMediaItem? previous;
          final seen = <String>{};
          for (var index = 0; index < 10; index++) {
            final watch = Stopwatch()..start();
            final page = await repository.queryPage(
              'a',
              sortKey: key,
              sortAscending: ascending,
              cursor: cursor,
            );
            watch.stop();
            timings.add(watch.elapsedMicroseconds);
            expect(page.items.length, 200);
            expect(page.hasMore, true);
            for (final item in page.items) {
              if (previous != null) {
                expect(_compare(previous, item, key, ascending), lessThan(0));
              }
              expect(seen.add(item.path), true);
              previous = item;
            }
            cursor = page.nextCursor;
          }
        }
      }
      migrated.dispose();
      await repository.initialize();
      expect(await repository.count('a'), 100000);
      timings.sort();
      // ignore: avoid_print
      print(
        'NAS 100k: seed=${seed.elapsedMilliseconds}ms migration=${migration.elapsedMilliseconds}ms '
        'page p50=${timings[timings.length ~/ 2]}us p95=${timings[(timings.length * .95).floor()]}us '
        'RSS delta=${ProcessInfo.currentRss - rss} bytes; 200 items/page; preserved legacy data.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
