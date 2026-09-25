import 'dart:io';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  test(
    'replaces one server index and filters without crossing servers',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = NasIndexRepository('${directory.path}/index.sqlite3');
      await repository.initialize();
      await repository.replaceServerItems('one', const [
        NasMediaItem(
          serverId: 'one',
          path: '/media/photo.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 12,
          modifiedEpoch: 2,
        ),
        NasMediaItem(
          serverId: 'one',
          path: '/media/song.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: 30,
          modifiedEpoch: 1,
        ),
      ]);
      await repository.replaceServerItems('two', const [
        NasMediaItem(
          serverId: 'two',
          path: '/else/video.mp4',
          kind: NasMediaKind.video,
          sizeBytes: 99,
          modifiedEpoch: 3,
        ),
      ]);

      expect((await repository.query('one')).length, 2);
      expect(
        (await repository.query('one', kind: NasMediaKind.image)).single.path,
        '/media/photo.jpg',
      );
      expect(
        (await repository.query('one', search: 'song')).single.kind,
        NasMediaKind.audio,
      );

      await repository.replaceServerItems('one', const []);
      expect(await repository.query('one'), isEmpty);
      expect((await repository.query('two')).single.path, '/else/video.mp4');
    },
  );

  test('serializes repositories that share the media index', () async {
    final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final first = NasIndexRepository(databasePath);
    final second = NasIndexRepository(databasePath);

    await Future.wait([first.initialize(), second.initialize()]);
    await Future.wait([
      first.replaceServerItems('one', const []),
      second.savePlayback(
        NasPlaybackState(
          serverId: 'one',
          path: '/media/song.mp3',
          position: Duration.zero,
          updatedAt: DateTime(2026),
        ),
      ),
    ]);

    expect(await first.playbackFor('one', '/media/song.mp3'), isNotNull);
  });

  test(
    'streamed generations preserve local metadata and never purge on cancellation',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = NasIndexRepository('${directory.path}/index.sqlite3');
      await repository.initialize();
      const original = NasMediaItem(
        serverId: 'one',
        path: 'opaque-id',
        kind: NasMediaKind.audio,
        sizeBytes: 12,
        modifiedEpoch: 1,
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        durationMillis: 12000,
        sourcePath: '/Music/Album/song.mp3',
      );
      await repository.replaceServerItems('one', [original]);
      await repository.setFavorite('one', original.path, true);
      final canceled = await repository.beginScan('one');
      await repository.upsertBatch('one', const [
        NasMediaItem(
          serverId: 'one',
          path: '/new.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 1,
          modifiedEpoch: 2,
        ),
      ], canceled);
      expect((await repository.totals('one')).total, 2);
      final current = await repository.beginScan('one');
      await expectLater(
        repository.finishScan('one', canceled),
        throwsStateError,
      );
      await repository.upsertBatch('one', const [
        NasMediaItem(
          serverId: 'one',
          path: 'opaque-id',
          kind: NasMediaKind.audio,
          sizeBytes: 99,
          modifiedEpoch: 3,
          sourcePath: '/Music/Album/song.mp3',
        ),
      ], current);
      await repository.finishScan('one', current);
      final saved = (await repository.query('one')).single;
      expect(saved.isFavorite, true);
      expect(saved.title, 'Song');
      expect(saved.durationMillis, 12000);
      expect(saved.sizeBytes, 99);
      expect(saved.sourcePath, '/Music/Album/song.mp3');
      expect(
        (await repository.groups('one', NasIndexGroup.byFolder)).single.name,
        '/Music/Album',
      );
      await repository.upsertBatch(
        'one',
        [original],
        current,
        syncFavorites: true,
      );
      expect((await repository.query('one')).single.isFavorite, false);
      await repository.setFavorite('one', original.path, true);
      await repository.updateMetadata(
        original.copyWith(artist: 'Discovered artist'),
      );
      expect(
        (await repository.query('one')).single.artist,
        'Discovered artist',
      );
      expect((await repository.query('one')).single.isFavorite, true);
      final stopped = await repository.beginScan('one');
      final cancellation = NasCancellation();
      final finish = repository.finishScan(
        'one',
        stopped,
        cancellation: cancellation,
      );
      cancellation.cancel();
      await expectLater(finish, throwsA(isA<NasCancelled>()));
      expect(await repository.count('one'), 1);
      await expectLater(
        repository.upsertBatch('two', [
          original,
        ], await repository.beginScan('two')),
        throwsArgumentError,
      );
      expect(await repository.count('two'), 0);
    },
  );

  test(
    'keyset pages, indexed search, database totals and playlist edits use the entire library',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = NasIndexRepository('${directory.path}/index.sqlite3');
      await repository.initialize();
      final items = List.generate(
        513,
        (index) => NasMediaItem(
          serverId: 'one',
          path: '/Music/song${index.toString().padLeft(4, '0')}.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: index,
          modifiedEpoch: index ~/ 10,
          artist: index.isEven ? 'A' : 'B',
          album: 'Road',
          isFavorite: index.isEven,
        ),
      );
      await repository.replaceServerItems('one', items);
      final seen = <String>[];
      NasIndexCursor? cursor;
      while (true) {
        final page = await repository.queryPage(
          'one',
          cursor: cursor,
          limit: 37,
        );
        seen.addAll(page.items.map((item) => item.path));
        if (!page.hasMore) break;
        cursor = page.nextCursor;
      }
      expect(seen.length, 513);
      expect(seen.toSet().length, 513);
      expect((await repository.totals('one')).audio, 513);
      expect(
        await repository.count('one', favoritesOnly: true, album: 'Road'),
        257,
      );
      expect(
        (await repository.queryPage(
          'one',
          artist: 'B',
          limit: 17,
        )).items.length,
        17,
      );
      expect(
        (await repository.queryPage('one', search: 'song051')).items.length,
        3,
      );
      expect(
        (await repository.groups('one', NasIndexGroup.byArtist)).first.count,
        257,
      );
      expect(
        (await repository.queryPage('one', search: '" OR song051*')).items,
        isEmpty,
      );
      final playlist = NasPlaylist(
        id: 'p',
        serverId: 'one',
        name: 'Old',
        createdAt: DateTime(2026),
      );
      await repository.createPlaylist(playlist);
      for (final item in items.take(3)) {
        await repository.addToPlaylist(
          serverId: 'one',
          playlistId: 'p',
          path: item.path,
        );
      }
      await repository.addToPlaylist(
        serverId: 'one',
        playlistId: 'p',
        path: items.first.path,
      );
      await repository.renamePlaylist('one', 'p', 'New');
      await repository.movePlaylistItem('one', 'p', items[2].path, 0);
      final first = await repository.playlistMediaPage('one', 'p', limit: 2);
      expect(first.items.map((i) => i.path), [items[2].path, items[0].path]);
      expect(first.hasMore, true);
      expect(
        (await repository.playlistMediaPage(
          'one',
          'p',
          afterPosition: first.nextPosition,
        )).items.single.path,
        items[1].path,
      );
      await repository.removeFromPlaylist('two', 'p', items.first.path);
      expect((await repository.playlistsFor('one')).single.itemCount, 3);
      await repository.removeFromPlaylist('one', 'p', items.first.path);
      expect(await repository.playlistItems('one', 'p'), [
        items[2].path,
        items[1].path,
      ]);
      expect((await repository.playlistsFor('one')).single.name, 'New');
    },
  );

  test(
    'migrates legacy records, favorites and duplicate playlist positions',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/index.sqlite3';
      final db = sqlite3.open(databasePath);
      db.execute(
        '''CREATE TABLE nas_media(server_id TEXT NOT NULL,path TEXT NOT NULL,kind TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,modified_epoch INTEGER NOT NULL,is_favorite INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(server_id,path)) STRICT;
      INSERT INTO nas_media VALUES ('one','/照片/节日.jpg','image',12,50,1);
      CREATE TABLE nas_playlist_items(playlist_id TEXT NOT NULL,path TEXT NOT NULL,position INTEGER NOT NULL,PRIMARY KEY(playlist_id,path)) STRICT;
      INSERT INTO nas_playlist_items VALUES ('p','/照片/节日.jpg',0),('p','/b.jpg',0);
    ''',
      );
      db.dispose();
      final repository = NasIndexRepository(databasePath);
      await repository.initialize();
      await repository.createPlaylist(
        NasPlaylist(
          id: 'p',
          serverId: 'one',
          name: 'Preserved',
          createdAt: DateTime(2026),
        ),
      );
      final item = (await repository.queryPage('one')).items.single;
      expect(item.path, '/照片/节日.jpg');
      expect(item.isFavorite, true);
      expect(
        (await repository.groups('one', NasIndexGroup.byFolder)).single.name,
        '/照片',
      );
      expect(await repository.count('one', search: '节日'), 1);
      await repository.initialize();
      expect(await repository.count('one'), 1);
      final migrated = sqlite3.open(databasePath);
      expect(
        migrated
            .select('SELECT position FROM nas_playlist_items ORDER BY position')
            .map((r) => r['position']),
        [0, 1],
      );
      migrated.dispose();
    },
  );

  test('persists playlists without crossing server boundaries', () async {
    final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = NasIndexRepository('${directory.path}/index.sqlite3');
    await repository.initialize();
    final playlist = NasPlaylist(
      id: 'playlist-one',
      serverId: 'one',
      name: 'Road trip',
      createdAt: DateTime(2026),
    );
    await repository.createPlaylist(playlist);
    await repository.addToPlaylist(
      serverId: 'one',
      playlistId: playlist.id,
      path: '/music/song.mp3',
      position: 0,
    );

    expect((await repository.playlistsFor('one')).single.name, 'Road trip');
    expect(await repository.playlistItems('one', playlist.id), [
      '/music/song.mp3',
    ]);
    expect(await repository.playlistsFor('two'), isEmpty);
    await repository.deletePlaylist('two', playlist.id);
    expect((await repository.playlistsFor('one')).single.id, playlist.id);
    await repository.deletePlaylist('one', playlist.id);
    expect(await repository.playlistsFor('one'), isEmpty);
  });
}
