import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/data/workspace/workspace_nas_sync.dart';

/// Programmable workspace gateway used to exercise [WorkspaceNasSync] without a
/// real SSH server. Records what was uploaded and answers canned `request`s.
class FakeGateway implements WorkspaceGateway {
  final Set<String> _enabled;
  final List<Map<String, dynamic>> puts = [];
  final Map<String, dynamic> Function(String, Map<String, dynamic>) requestFn;

  FakeGateway({required this.requestFn, Set<String> enabled = const {}})
    : _enabled = {...enabled};

  @override
  String get deviceId => 'test-device';

  @override
  bool isEnabled(String serverId) => _enabled.contains(serverId);

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) => Future.value(requestFn(serverId, command));

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {
    puts.addAll(records);
  }

  @override
  Stream<WorkspaceChange> get changes => const Stream.empty();
}

/// [FakeGateway] whose [putRecords] always fails, to exercise outbox/error
/// propagation in the migration loop.
class ThrowingGateway implements WorkspaceGateway {
  final Set<String> _enabled;
  ThrowingGateway({Set<String> enabled = const {}}) : _enabled = {...enabled};

  @override
  String get deviceId => 'test-device';

  @override
  bool isEnabled(String serverId) => _enabled.contains(serverId);

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) => Future.value({'ok': true});

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) => throw StateError('NAS_OUTBOX_ENQUEUE_FAILED');

  @override
  Stream<WorkspaceChange> get changes => const Stream.empty();
}

/// Builds a [WorkspaceNasSync] bound to [repo] and [gw]; [sourceToServer] maps a
/// media source id to the SSH server profile id it is bound to.
WorkspaceNasSync buildSync(
  NasIndexRepository repo,
  WorkspaceGateway gw,
  Map<String, String> sourceToServer, {
  String? Function(String)? ownerFor,
}) => WorkspaceNasSync(
  gateway: () => gw,
  sourceFor: (id) {
    final server = sourceToServer[id];
    if (server == null) return null;
    return NasSource(
      id: id,
      name: id,
      type: NasSourceType.sftp,
      sshServerId: server,
    );
  },
  ownerFor: ownerFor,
  repository: repo,
);

Map<String, dynamic> _change(
  String id,
  Map<String, dynamic>? value, {
  bool deleted = false,
}) => {
  'kind': kWorkspaceNasRecordKind,
  'id': id,
  'value': value,
  'deleted': deleted,
};

Map<String, dynamic> _mediaChange(String s, NasMediaItem it) => _change(
  WorkspaceNasSync.mediaRecordId(s, it.path),
  WorkspaceNasSync.mediaValue(s, it),
);

Map<String, dynamic> _mediaDelete(String s, String path) => _change(
  WorkspaceNasSync.mediaRecordId(s, path),
  {'type': 'media', 'sourceId': s, 'path': path},
  deleted: true,
);

Map<String, dynamic> _playlistChange(String s, String id, String name) =>
    _change(
      WorkspaceNasSync.playlistRecordId(s, id),
      WorkspaceNasSync.playlistValue(
        s,
        NasPlaylist(id: id, serverId: s, name: name, createdAt: DateTime(2026)),
      ),
    );

Map<String, dynamic> _playlistItemChange(
  String s,
  String pid,
  String path,
  int pos,
) => _change(
  WorkspaceNasSync.playlistItemRecordId(s, pid, path),
  WorkspaceNasSync.playlistItemValue(s, pid, path, pos),
);

Map<String, dynamic> _playlistItemDelete(String s, String pid, String path) =>
    _change(
      WorkspaceNasSync.playlistItemRecordId(s, pid, path),
      WorkspaceNasSync.playlistItemValue(s, pid, path, 0),
      deleted: true,
    );

NasMediaItem _item(
  String sourceId,
  String path, {
  NasMediaKind kind = NasMediaKind.image,
}) => NasMediaItem(
  serverId: sourceId,
  path: path,
  kind: kind,
  sizeBytes: 10,
  modifiedEpoch: 1,
);

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  /// (1) Two sources on the same server deliver interleaved change pages; only
  /// the requested source is imported, and the durable cursor survives a
  /// helper/repository reopen.
  test(
    'applies only own source from interleaved pages and persists cursor',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      final gw = FakeGateway(
        enabled: {'S'},
        requestFn: (serverId, cmd) {
          if (cmd['op'] == 'changes') {
            return {
              'records': [
                _mediaChange('A', _item('A', '/a/1.jpg')),
                _mediaChange('B', _item('B', '/b/1.jpg')),
                _mediaChange('A', _item('A', '/a/2.jpg')),
                _mediaChange('B', _item('B', '/b/2.jpg')),
              ],
              'revision': 10,
              'hasMore': false,
            };
          }
          return {'ok': true};
        },
      );
      final sync = buildSync(repo, gw, {'A': 'S', 'B': 'S'});

      final caughtUp = await sync.pullChanges('A');
      expect(caughtUp, isTrue);

      // Only A's rows are cached; B's were skipped without import.
      final aRows = await repo.query('A');
      expect(aRows.map((m) => m.path).toSet(), {'/a/1.jpg', '/a/2.jpg'});
      expect(await repo.query('B'), isEmpty);

      // Cursor persisted under (source A, workspace S).
      expect(await repo.changesCursor('A', workspaceId: 'S'), 10);

      // Survives a full helper/repository reopen on the same database file.
      final repo2 = NasIndexRepository(path);
      await repo2.initialize();
      expect(await repo2.changesCursor('A', workspaceId: 'S'), 10);
      final sync2 = buildSync(repo2, gw, {'A': 'S', 'B': 'S'});
      final caughtUp2 = await sync2.pullChanges('A');
      expect(caughtUp2, isTrue);
      expect(await repo2.changesCursor('A', workspaceId: 'S'), 10);
    },
  );

  /// (2) Encoded/special-character media and playlist_item tombstones actually
  /// remove cache rows, leave an unrelated source untouched, and survive an
  /// reopen plus a re-pull of the same tombstones.
  test(
    'encoded-path deletes and playlist_item tombstones remove cache',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      const encodedPath = '/My Photos/西/IMG 01.jpg';
      final aItem = _item('A', encodedPath);
      final bItem = _item('B', encodedPath); // same path, different source

      var call = 0;
      final gw = FakeGateway(
        enabled: {'S'},
        requestFn: (serverId, cmd) {
          if (cmd['op'] == 'changes') {
            call++;
            if (call <= 2) {
              // Insert page: each source pulls only its own records.
              return {
                'records': [
                  _mediaChange('A', aItem),
                  _playlistChange('A', 'p1', 'Playlist'),
                  _playlistItemChange('A', 'p1', encodedPath, 0),
                  _mediaChange('B', bItem),
                ],
                'revision': 1,
                'hasMore': false,
              };
            }
            // Delete page: tombstones for A's encoded-path media and playlist item.
            return {
              'records': [
                _mediaDelete('A', encodedPath),
                _playlistItemDelete('A', 'p1', encodedPath),
              ],
              'revision': 2,
              'hasMore': false,
            };
          }
          return {'ok': true};
        },
      );
      final sync = buildSync(repo, gw, {'A': 'S', 'B': 'S'});

      // Seed both sources from the interleaved insert page.
      await sync.pullChanges('A');
      await sync.pullChanges('B');
      expect((await repo.query('A')).any((m) => m.path == encodedPath), isTrue);
      expect(
        (await repo.playlistItems('A', 'p1')).contains(encodedPath),
        isTrue,
      );
      // B's copy of the same path is independent.
      expect((await repo.query('B')).any((m) => m.path == encodedPath), isTrue);

      // Apply A's tombstones.
      await sync.pullChanges('A');
      expect(
        (await repo.query('A')).any((m) => m.path == encodedPath),
        isFalse,
      );
      expect(
        (await repo.playlistItems('A', 'p1')).contains(encodedPath),
        isFalse,
      );
      // B remains untouched after A's deletion.
      expect((await repo.query('B')).any((m) => m.path == encodedPath), isTrue);

      // Survives reopen and a re-pull of the identical tombstones (idempotent).
      final repo2 = NasIndexRepository(path);
      await repo2.initialize();
      final sync2 = buildSync(repo2, gw, {'A': 'S', 'B': 'S'});
      await sync2.pullChanges('A');
      expect(
        (await repo2.query('A')).any((m) => m.path == encodedPath),
        isFalse,
      );
      expect(
        (await repo2.query('B')).any((m) => m.path == encodedPath),
        isTrue,
      );
    },
  );

  /// (3) A change whose id source disagrees with its value source is rejected;
  /// the pull aborts and the cursor is not advanced.
  test('bad id/value source is rejected and cursor stays at zero', () async {
    final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/index.sqlite3';
    final repo = NasIndexRepository(path);
    await repo.initialize();

    // id embeds source B, value claims source A while we pull source A.
    final bad = _change(WorkspaceNasSync.mediaRecordId('B', '/x.jpg'), {
      'type': 'media',
      'sourceId': 'A',
      'path': '/x.jpg',
    });
    final gw = FakeGateway(
      enabled: {'S'},
      requestFn: (serverId, cmd) {
        if (cmd['op'] == 'changes') {
          return {
            'records': [bad],
            'revision': 7,
            'hasMore': false,
          };
        }
        return {'ok': true};
      },
    );
    final sync = buildSync(repo, gw, {'A': 'S'});

    expect(() => sync.pullChanges('A'), throwsA(isA<FormatException>()));
    expect(await repo.changesCursor('A', workspaceId: 'S'), 0);
    expect(await repo.query('A'), isEmpty);
  });

  /// (3b) pullChanges reports "not caught up" when the remote still has more
  /// pages, even though the page it applied was valid and the cursor advanced.
  test(
    'pullChanges reports not caught up when remote has more pages',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      var call = 0;
      final gw = FakeGateway(
        enabled: {'S'},
        requestFn: (serverId, cmd) {
          if (cmd['op'] == 'changes') {
            call++;
            return {
              'records': [_mediaChange('A', _item('A', '/a/$call.jpg'))],
              'revision': call,
              'hasMore': true,
            };
          }
          return {'ok': true};
        },
      );
      final sync = buildSync(repo, gw, {'A': 'S'});

      final caughtUp = await sync.pullChanges('A', maxPages: 1);
      expect(caughtUp, isFalse);
      // The applied page is still cached.
      expect((await repo.query('A')).isNotEmpty, isTrue);
      // The cursor advanced despite not being caught up.
      expect(await repo.changesCursor('A', workspaceId: 'S'), 1);
    },
  );

  /// (4) A legacy local index larger than one page migrates one stage per call,
  /// resumes after a repository reopen, flattens playlists (headers + items),
  /// and finishes favorites, playlists and playback exactly once with no
  /// requeue after completion.
  test(
    'legacy index migrates in batches, resumes, and does not requeue',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      // 450 legacy media rows (more than one 200-row migration page).
      final items = [
        for (var i = 0; i < 450; i++)
          _item(
            'A',
            '/m/i$i.jpg',
            kind: i.isEven ? NasMediaKind.image : NasMediaKind.video,
          ),
      ];
      await repo.replaceServerItems('A', items);
      for (var i = 0; i < 5; i++) {
        await repo.setFavorite('A', '/m/i$i.jpg', true);
      }
      await repo.createPlaylist(
        NasPlaylist(
          id: 'p1',
          serverId: 'A',
          name: 'P',
          createdAt: DateTime(2026),
        ),
      );
      await repo.addToPlaylist(
        serverId: 'A',
        playlistId: 'p1',
        path: '/m/i0.jpg',
      );
      await repo.savePlayback(
        NasPlaybackState(
          serverId: 'A',
          path: '/m/i1.jpg',
          position: Duration(seconds: 5),
          updatedAt: DateTime(2026),
        ),
      );

      final gw = FakeGateway(enabled: {'S'}, requestFn: (_, _) => {'ok': true});

      // Phase 1: one batch only, then reopen and continue (resume).
      final sync1 = buildSync(repo, gw, {'A': 'S'});
      await sync1.migrateSource('A');

      final repo2 = NasIndexRepository(path);
      await repo2.initialize();
      final sync2 = buildSync(repo2, gw, {'A': 'S'});
      var done = false;
      for (var i = 0; i < 20 && !done; i++) {
        done = await sync2.migrateSource('A');
      }
      expect(done, isTrue);

      final media = gw.puts
          .where((r) => (r['id'] as String).startsWith('media/A/'))
          .toList();
      expect(media.length, 450);
      expect(media.map((r) => r['id']).toSet().length, 450);
      expect(
        gw.puts
            .where((r) => (r['id'] as String).startsWith('favorite/A/'))
            .length,
        5,
      );
      expect(
        gw.puts
            .where((r) => (r['id'] as String).startsWith('playlist/A/'))
            .isNotEmpty,
        isTrue,
      );
      // Playlist headers AND membership rows are flattened into the upload.
      expect(
        gw.puts
            .where((r) => (r['id'] as String).startsWith('playlist_item/A/'))
            .any((r) => (r['value'] as Map)['path'] == '/m/i0.jpg'),
        isTrue,
      );
      expect(
        gw.puts
            .where((r) => (r['id'] as String).startsWith('playback/A/'))
            .isNotEmpty,
        isTrue,
      );

      // Once done, a further migration must not requeue anything.
      final before = gw.puts.length;
      await sync2.migrateSource('A');
      expect(gw.puts.length, before);
    },
  );

  /// (4b) If the durable outbox rejects a page, the migration cursor is not
  /// advanced, so the same page is retried and no local rows are lost.
  test(
    'migration retries after outbox enqueue failure without losing pages',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      await repo.replaceServerItems('A', [
        for (final i in [0, 1, 2, 3, 4]) _item('A', '/m/$i.jpg'),
      ]);

      final throwing = ThrowingGateway(enabled: {'S'});
      final syncThrowing = buildSync(repo, throwing, {'A': 'S'});

      // _put propagates the enqueue failure; the cursor must not advance.
      expect(() => syncThrowing.migrateSource('A'), throwsA(isA<StateError>()));
      final cursorAfterFailure = await repo.migrationCursor(
        'A',
        workspaceId: 'S',
      );
      expect(cursorAfterFailure.lastRowId, 0);
      expect(cursorAfterFailure.done, isFalse);

      // Retry with a working gateway: the boundary is kept, the page is re-sent.
      final gw = FakeGateway(enabled: {'S'}, requestFn: (_, _) => {'ok': true});
      final sync = buildSync(repo, gw, {'A': 'S'});
      var done = false;
      for (var i = 0; i < 10 && !done; i++) {
        done = await sync.migrateSource('A');
      }
      expect(done, isTrue);
      expect(
        gw.puts.where((r) => (r['id'] as String).startsWith('media/A/')).length,
        5,
      );
    },
  );

  /// (5) An initially empty local index freezes the migration boundary at 0, so
  /// remote rows imported afterwards are never re-exported as legacy.
  test('empty index freezes boundary 0 and skips imported remote rows', () async {
    final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/index.sqlite3';
    final repo = NasIndexRepository(path);
    await repo.initialize();

    final gw = FakeGateway(enabled: {'S'}, requestFn: (_, _) => {'ok': true});
    final sync = buildSync(repo, gw, {'A': 'S'});

    // First call completes only the (trivial) media stage and returns false
    // until the playlist/playback stages also finish.
    final first = await sync.migrateSource('A');
    expect(first, isFalse);
    // Empty boundary is frozen at 0, not left as the -1 uninitialized sentinel.
    expect(
      (await repo.migrationCursor('A', workspaceId: 'S')).boundaryRowId,
      0,
    );

    // Finish the remaining stages.
    var done = false;
    for (var i = 0; i < 10 && !done; i++) {
      done = await sync.migrateSource('A');
    }
    expect(done, isTrue);

    // A remote row is imported into the cache (rowid > 0).
    await repo.applyRemoteMedia('A', [_item('A', '/remote/imported.jpg')]);

    // The bounded migration page excludes everything beyond the frozen boundary.
    final page = await repo.migrationPage(
      'A',
      afterRowId: 0,
      limit: 200,
      workspaceId: 'S',
    );
    expect(page.items, isEmpty);

    // Re-migrating must not re-export the imported row as legacy.
    final before = gw.puts.length;
    final done2 = await sync.migrateSource('A');
    expect(done2, isTrue);
    expect(gw.puts.length, before);
    expect(
      gw.puts.any((r) => (r['id'] as String?)?.contains('imported') ?? false),
      isFalse,
    );
  });

  /// (6) An unbound direct media source becomes available via the optional
  /// ownerFor callback, routing puts to the chosen workspace server; without it
  /// such a source stays unavailable.
  test(
    'ownerFor routes an unbound media source to a workspace server',
    () async {
      final directory = await Directory.systemTemp.createTemp('valhalla-nas-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/index.sqlite3';
      final repo = NasIndexRepository(path);
      await repo.initialize();

      final gw = FakeGateway(enabled: {'S'}, requestFn: (_, _) => {'ok': true});
      final mediaSource = NasSource(
        id: 'M',
        name: 'M',
        type: NasSourceType.jellyfin,
      );

      final sync = WorkspaceNasSync(
        gateway: () => gw,
        sourceFor: (_) => mediaSource,
        ownerFor: (id) => 'S',
        repository: repo,
      );
      expect(sync.isAvailable('M'), isTrue);
      await sync.mediaChanged('M', [_item('M', '/m/x.jpg')]);
      expect(gw.puts.isNotEmpty, isTrue);

      // Without ownerFor, an unbound media server is unavailable.
      final syncNoOwner = WorkspaceNasSync(
        gateway: () => gw,
        sourceFor: (_) => mediaSource,
        repository: repo,
      );
      expect(syncNoOwner.isAvailable('M'), isFalse);
    },
  );
}
