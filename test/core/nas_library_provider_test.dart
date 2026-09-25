import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

class _Adapter extends NasSourceAdapter {
  @override
  final NasSource source;
  _Adapter(this.source);
  @override
  Future<void> probe() async {}
  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) async* {
    yield [_item(source.id, '/new.mp3')];
    await cancellation.whenCancelled;
    cancellation.check();
  }

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async => NasResource(uri: Uri.parse('http://unused.invalid/item'));
}

class _PlaylistAdapter extends _Adapter {
  final List<NasMediaItem> members;
  final starts = <int>[];
  final int pageSize;
  _PlaylistAdapter(super.source, this.members, {this.pageSize = 200});

  @override
  Future<List<NasPlaylist>> playlists() async => [
    NasPlaylist(
      id: 'playlist',
      serverId: source.id,
      name: 'Remote playlist',
      createdAt: DateTime(2026),
      itemCount: members.length,
    ),
  ];

  @override
  Stream<List<NasMediaItem>> playlistItems(
    String id,
    NasCancellation cancellation, {
    int startIndex = 0,
  }) async* {
    starts.add(startIndex);
    for (var offset = startIndex; offset < members.length; offset += pageSize) {
      cancellation.check();
      yield members.skip(offset).take(pageSize).toList();
    }
  }

  @override
  Future<void> movePlaylistItem(String id, String entryId, int index) async {
    final previous = members.indexWhere((e) => e.playlistEntryId == entryId);
    members.insert(index, members.removeAt(previous));
  }
}

NasMediaItem _item(String id, String path) => NasMediaItem(
  serverId: id,
  path: path,
  kind: NasMediaKind.audio,
  sizeBytes: 10,
  modifiedEpoch: 1,
);

Future<void> _until(
  ProviderContainer container,
  bool Function(NasState) predicate,
) async {
  if (predicate(container.read(nasProvider))) return;
  final done = Completer<void>();
  final subscription = container.listen(nasProvider, (_, state) {
    if (!done.isCompleted && predicate(state)) done.complete();
  });
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'independent sources preserve their index and cancel never prunes existing items',
    () async {
      const sources = [
        NasSource(
          id: 'a',
          name: 'A',
          type: NasSourceType.sftp,
          sshServerId: 'ssh-a',
        ),
        NasSource(
          id: 'b',
          name: 'B',
          type: NasSourceType.sftp,
          sshServerId: 'ssh-b',
        ),
      ];
      SharedPreferences.setMockInitialValues({
        'valhalla_nas_sources_v1': jsonEncode(
          sources.map((s) => s.toJson()).toList(),
        ),
      });
      final storage = await LocalStorageService.init();
      final directory = await Directory.systemTemp.createTemp('nas-provider');
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      await repository.replaceServerItems('a', [_item('a', '/old.mp3')]);
      await repository.replaceServerItems('b', [_item('b', '/other.mp3')]);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          nasIndexRepositoryProvider.overrideWith((ref) async => repository),
          for (final source in sources)
            nasSourceAdapterProvider(
              source.id,
            ).overrideWith((ref) async => _Adapter(source)),
        ],
      );
      try {
        await _until(
          container,
          (state) => state.items.isNotEmpty && !state.isLoading,
        );
        expect(container.read(nasProvider).items.single.path, '/old.mp3');
        final notifier = container.read(nasProvider.notifier);
        final scan = notifier.scan();
        await _until(container, (state) => state.scannedCount == 1);
        notifier.cancelScan();
        await scan;
        expect(
          (await repository.query('a')).map((item) => item.path),
          containsAll(['/old.mp3', '/new.mp3']),
        );
        await container.read(nasSourcesProvider.notifier).select('b');
        await _until(
          container,
          (state) =>
              state.serverId == 'b' &&
              state.items.isNotEmpty &&
              !state.isLoading,
        );
        expect(container.read(nasProvider).items.single.path, '/other.mp3');
        expect(storage.getNasSelectedSourceId(), 'b');
        expect((await repository.query('a')).length, 2);
      } finally {
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'deep browsing replaces bounded pages and previous page restores cursor',
    () async {
      const source = NasSource(
        id: 'large',
        name: 'Large',
        type: NasSourceType.sftp,
      );
      SharedPreferences.setMockInitialValues({
        'valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
      });
      final storage = await LocalStorageService.init();
      final directory = await Directory.systemTemp.createTemp('nas-pages');
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      await repository.replaceServerItems(
        'large',
        List.generate(
          650,
          (i) => _item('large', '/${i.toString().padLeft(4, '0')}.mp3'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          nasIndexRepositoryProvider.overrideWith((ref) async => repository),
          nasSourceAdapterProvider(
            source.id,
          ).overrideWith((ref) async => _Adapter(source)),
        ],
      );
      try {
        await _until(
          container,
          (state) => state.items.isNotEmpty && !state.isLoading,
        );
        final notifier = container.read(nasProvider.notifier);
        expect(container.read(nasProvider).totals.audio, 650);
        await notifier.loadMore();
        expect(container.read(nasProvider).items.length, 200);
        expect(container.read(nasProvider).items.first.path, '/0200.mp3');
        await notifier.loadPrevious();
        expect(container.read(nasProvider).items.first.path, '/0000.mp3');
        expect(container.read(nasProvider).hasPrevious, false);

        await repository.createPlaylist(
          NasPlaylist(
            id: 'playlist',
            serverId: source.id,
            name: 'Large playlist',
            createdAt: DateTime(2026),
          ),
        );
        for (var i = 0; i < 450; i++) {
          await repository.addToPlaylist(
            serverId: source.id,
            playlistId: 'playlist',
            path: '/${i.toString().padLeft(4, '0')}.mp3',
          );
        }
        await notifier.setScope(playlistId: 'playlist');
        expect(container.read(nasProvider).playlistOffset, 0);
        await notifier.loadMore();
        expect(container.read(nasProvider).playlistOffset, 200);
        expect(container.read(nasProvider).hasPrevious, true);
        expect(container.read(nasProvider).items.first.path, '/0200.mp3');
        await notifier.loadMore();
        expect(container.read(nasProvider).playlistOffset, 400);
        expect(container.read(nasProvider).items.length, 50);
        expect(container.read(nasProvider).hasMore, false);
        await notifier.loadPrevious();
        var page = container.read(nasProvider);
        expect(page.playlistOffset, 200);
        expect(page.items.first.path, '/0200.mp3');
        await notifier.movePlaylistItem(
          'playlist',
          page.items[1],
          page.playlistOffset,
        );
        expect(container.read(nasProvider).playlistOffset, 0);
        await notifier.loadMore();
        page = container.read(nasProvider);
        expect(page.playlistOffset, 200);
        expect(page.items.first.path, '/0201.mp3');
        expect(page.items[1].path, '/0200.mp3');
        await notifier.loadPrevious();
        expect(container.read(nasProvider).items.first.path, '/0000.mp3');
        expect(container.read(nasProvider).hasPrevious, false);
        await notifier.loadMore();
        await notifier.setScope();
        expect(container.read(nasProvider).playlistOffset, 0);
      } finally {
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'remote playlist pages restart at global offsets and history is bounded',
    () async {
      const source = NasSource(
        id: 'remote',
        name: 'Remote',
        type: NasSourceType.emby,
      );
      SharedPreferences.setMockInitialValues({
        'valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
      });
      final storage = await LocalStorageService.init();
      final directory = await Directory.systemTemp.createTemp(
        'nas-remote-pages',
      );
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final members = List.generate(
        450,
        (i) => _item(source.id, '/$i.mp3').copyWith(playlistEntryId: '$i'),
      );
      var adapter = _PlaylistAdapter(source, members);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          nasIndexRepositoryProvider.overrideWith((ref) async => repository),
          nasSourceAdapterProvider(
            source.id,
          ).overrideWith((ref) async => adapter),
        ],
      );
      try {
        await _until(
          container,
          (state) => state.playlists.isNotEmpty && !state.isLoading,
        );
        final notifier = container.read(nasProvider.notifier);
        await notifier.setScope(playlistId: 'playlist');
        await notifier.loadMore();
        await notifier.loadMore();
        expect(container.read(nasProvider).playlistOffset, 400);
        expect(container.read(nasProvider).items.length, 50);
        await notifier.loadMore();
        expect(container.read(nasProvider).playlistOffset, 400);
        expect(container.read(nasProvider).items.first.path, '/400.mp3');
        expect(container.read(nasProvider).hasMore, false);
        await notifier.loadPrevious();
        expect(container.read(nasProvider).playlistOffset, 200);
        expect(container.read(nasProvider).items.first.path, '/200.mp3');
        await notifier.loadPrevious();
        expect(container.read(nasProvider).playlistOffset, 0);
        expect(container.read(nasProvider).hasPrevious, false);
        expect(adapter.starts, [0, 200, 400, 450, 200, 0]);
        await notifier.loadMore();
        final page = container.read(nasProvider);
        await notifier.movePlaylistItem(
          'playlist',
          page.items[1],
          page.playlistOffset,
        );
        expect(members[200].playlistEntryId, '201');
        expect(container.read(nasProvider).playlistOffset, 0);

        adapter = _PlaylistAdapter(source, members, pageSize: 1);
        container.invalidate(nasSourceAdapterProvider(source.id));
        await notifier.refresh();
        for (var i = 0; i < 257; i++) {
          await notifier.loadMore();
        }
        expect(container.read(nasProvider).playlistOffset, 257);
        for (var i = 0; i < 255; i++) {
          await notifier.loadPrevious();
        }
        expect(container.read(nasProvider).playlistOffset, 2);
        expect(container.read(nasProvider).hasPrevious, false);
        await notifier.loadPrevious();
        expect(container.read(nasProvider).playlistOffset, 2);
        await notifier.refresh();
        expect(container.read(nasProvider).playlistOffset, 0);
        expect(container.read(nasProvider).hasPrevious, false);
      } finally {
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
