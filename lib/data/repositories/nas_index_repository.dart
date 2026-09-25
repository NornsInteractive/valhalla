import 'dart:isolate';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';

import '../models/nas_media.dart';
import '../models/nas_source.dart';

class NasIndexCursor {
  final int modifiedEpoch;
  final String path;
  const NasIndexCursor(this.modifiedEpoch, this.path);
}

class NasIndexPage {
  final List<NasMediaItem> items;
  final NasIndexCursor? nextCursor;
  final bool hasMore;
  const NasIndexPage(this.items, this.nextCursor, this.hasMore);
}

class NasIndexTotals {
  final int total, images, videos, audio, favorites;
  const NasIndexTotals({
    this.total = 0,
    this.images = 0,
    this.videos = 0,
    this.audio = 0,
    this.favorites = 0,
  });
}

enum NasIndexGroup { byFolder, byArtist, byAlbum }

class NasIndexGroupCount {
  final String name;
  final int count;
  const NasIndexGroupCount(this.name, this.count);
}

class NasPlaylistPage {
  final List<NasMediaItem> items;
  final int? nextPosition;
  final bool hasMore;
  const NasPlaylistPage(this.items, this.nextPosition, this.hasMore);
}

class NasIndexRepository {
  final String databasePath;
  const NasIndexRepository(this.databasePath);

  // ponytail: global lock, per-database queues only if concurrent libraries
  // become a measured throughput problem. The player and index share one file.
  static Future<void> _writeQueue = Future.value();

  Future<T> _write<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>((_) {}, onError: (error, stackTrace) {});
    return result;
  }

  Future<void> initialize() => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        db.execute('PRAGMA journal_mode = WAL');
        db.execute('BEGIN IMMEDIATE');
        db.execute('''
        CREATE TABLE IF NOT EXISTS nas_media (
          server_id TEXT NOT NULL,
          path TEXT NOT NULL,
          kind TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          modified_epoch INTEGER NOT NULL,
          PRIMARY KEY (server_id, path)
        ) STRICT;
        CREATE INDEX IF NOT EXISTS nas_media_filter
          ON nas_media(server_id, kind, modified_epoch DESC);
      ''');
        _addColumn(db, 'nas_media', 'mime_type TEXT');
        _addColumn(db, 'nas_media', 'duration_millis INTEGER');
        _addColumn(db, 'nas_media', 'width INTEGER');
        _addColumn(db, 'nas_media', 'height INTEGER');
        _addColumn(db, 'nas_media', 'title TEXT');
        _addColumn(db, 'nas_media', 'artist TEXT');
        _addColumn(db, 'nas_media', 'album TEXT');
        _addColumn(db, 'nas_media', 'track_number INTEGER');
        _addColumn(db, 'nas_media', 'is_favorite INTEGER NOT NULL DEFAULT 0');
        _addColumn(db, 'nas_media', 'source_path TEXT');
        _addColumn(
          db,
          'nas_media',
          'metadata_probed INTEGER NOT NULL DEFAULT 0',
        );
        final needsIndexMigration = !db
            .select('PRAGMA table_info(nas_media)')
            .any((row) => row['name'] == 'scan_generation');
        _addColumn(
          db,
          'nas_media',
          'scan_generation INTEGER NOT NULL DEFAULT 0',
        );
        _addColumn(db, 'nas_media', 'sort_epoch INTEGER NOT NULL DEFAULT 0');
        _addColumn(db, 'nas_media', "folder TEXT NOT NULL DEFAULT '/'");
        if (needsIndexMigration) {
          db.execute('UPDATE nas_media SET sort_epoch = -modified_epoch');
          // Existing databases are migrated a bounded page at a time, including
          // non-ASCII paths, without loading the entire library into Dart.
          var lastRow = 0;
          while (true) {
            final rows = db.select(
              'SELECT rowid, path FROM nas_media WHERE rowid > ? ORDER BY rowid LIMIT 1000',
              [lastRow],
            );
            if (rows.isEmpty) break;
            final update = db.prepare(
              'UPDATE nas_media SET folder = ? WHERE rowid = ?',
            );
            try {
              for (final row in rows) {
                update.execute([_folder(row['path'] as String), row['rowid']]);
              }
            } finally {
              update.dispose();
            }
            lastRow = rows.last['rowid'] as int;
          }
        }
        db.execute('''
        CREATE TABLE IF NOT EXISTS nas_scans (
          server_id TEXT PRIMARY KEY,
          generation INTEGER NOT NULL
        ) STRICT;
        CREATE TABLE IF NOT EXISTS nas_playback (
          server_id TEXT NOT NULL,
          path TEXT NOT NULL,
          position_millis INTEGER NOT NULL,
          duration_millis INTEGER,
          updated_epoch INTEGER NOT NULL,
          PRIMARY KEY (server_id, path)
        ) STRICT;
        CREATE TABLE IF NOT EXISTS nas_playlists (
          id TEXT PRIMARY KEY,
          server_id TEXT NOT NULL,
          name TEXT NOT NULL,
          created_epoch INTEGER NOT NULL
        ) STRICT;
        CREATE TABLE IF NOT EXISTS nas_playlist_items (
          playlist_id TEXT NOT NULL,
          path TEXT NOT NULL,
          position INTEGER NOT NULL,
          PRIMARY KEY (playlist_id, path)
        ) STRICT;
        CREATE INDEX IF NOT EXISTS nas_media_favorite
          ON nas_media(server_id, is_favorite, modified_epoch DESC);
        CREATE INDEX IF NOT EXISTS nas_media_album
          ON nas_media(server_id, kind, album, artist);
        CREATE INDEX IF NOT EXISTS nas_media_page ON nas_media(server_id, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_kind_page ON nas_media(server_id, kind, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_favorite_page ON nas_media(server_id, is_favorite, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_folder_page ON nas_media(server_id, folder, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_artist_page ON nas_media(server_id, artist, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_album_page ON nas_media(server_id, album, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_media_metadata_queue ON nas_media(server_id, kind, metadata_probed, sort_epoch, path);
        CREATE INDEX IF NOT EXISTS nas_playlist_order ON nas_playlist_items(playlist_id, position, path);
      ''');
        if (needsIndexMigration) {
          db.execute(
            '''WITH ranks AS (SELECT rowid AS rid,
            ROW_NUMBER() OVER (PARTITION BY playlist_id ORDER BY position, path) - 1 AS rank
            FROM nas_playlist_items)
            UPDATE nas_playlist_items SET position = (SELECT rank FROM ranks WHERE rid = nas_playlist_items.rowid)''',
          );
        }
        final hasSearch = db
            .select(
              "SELECT 1 FROM sqlite_master WHERE name = 'nas_media_search'",
            )
            .isNotEmpty;
        db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS nas_media_search USING fts5(
          path, title, artist, album, content='nas_media', content_rowid='rowid',
          tokenize='unicode61', prefix='2 3 4'
        );
        CREATE TRIGGER IF NOT EXISTS nas_media_search_insert AFTER INSERT ON nas_media BEGIN
          INSERT INTO nas_media_search(rowid, path, title, artist, album)
          VALUES (new.rowid, new.path, new.title, new.artist, new.album);
        END;
        CREATE TRIGGER IF NOT EXISTS nas_media_search_delete AFTER DELETE ON nas_media BEGIN
          INSERT INTO nas_media_search(nas_media_search, rowid, path, title, artist, album)
          VALUES ('delete', old.rowid, old.path, old.title, old.artist, old.album);
        END;
        CREATE TRIGGER IF NOT EXISTS nas_media_search_update AFTER UPDATE OF path, title, artist, album ON nas_media
        WHEN old.path IS NOT new.path OR old.title IS NOT new.title OR old.artist IS NOT new.artist OR old.album IS NOT new.album BEGIN
          INSERT INTO nas_media_search(nas_media_search, rowid, path, title, artist, album)
          VALUES ('delete', old.rowid, old.path, old.title, old.artist, old.album);
          INSERT INTO nas_media_search(rowid, path, title, artist, album)
          VALUES (new.rowid, new.path, new.title, new.artist, new.album);
        END;
        ''');
        if (!hasSearch) {
          db.execute(
            "INSERT INTO nas_media_search(nas_media_search) VALUES ('rebuild')",
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        if (!db.autocommit) db.execute('ROLLBACK');
        rethrow;
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> replaceServerItems(
    String serverId,
    List<NasMediaItem> items,
  ) async {
    final generation = await beginScan(serverId);
    for (var start = 0; start < items.length; start += 1000) {
      final end = start + 1000 < items.length ? start + 1000 : items.length;
      await upsertBatch(serverId, items.sublist(start, end), generation);
    }
    await finishScan(serverId, generation);
  }

  Future<int> beginScan(String serverId) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        return db
                .select(
                  '''INSERT INTO nas_scans(server_id, generation) VALUES (?, 1)
        ON CONFLICT(server_id) DO UPDATE SET generation = generation + 1
        RETURNING generation''',
                  [serverId],
                )
                .single['generation']
            as int;
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> upsertBatch(
    String serverId,
    List<NasMediaItem> items,
    int generation, {
    bool syncFavorites = false,
  }) => _write(
    () => Isolate.run(() {
      if (items.length > 10000) throw ArgumentError('NAS_BATCH_TOO_LARGE');
      final db = _open(databasePath);
      try {
        _transaction(db, () {
          _checkGeneration(db, serverId, generation);
          final insert = db.prepare(
            '''INSERT INTO nas_media
          (server_id,path,kind,size_bytes,modified_epoch,mime_type,duration_millis,
           width,height,title,artist,album,track_number,is_favorite,scan_generation,sort_epoch,folder,source_path)
          VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
          ON CONFLICT(server_id,path) DO UPDATE SET
            metadata_probed=CASE WHEN nas_media.size_bytes <> excluded.size_bytes
              OR nas_media.modified_epoch <> excluded.modified_epoch
              OR (nas_media.metadata_probed = 2 AND nas_media.scan_generation <> excluded.scan_generation)
              THEN 0 ELSE nas_media.metadata_probed END,
            kind=excluded.kind,size_bytes=excluded.size_bytes,modified_epoch=excluded.modified_epoch,
            mime_type=COALESCE(excluded.mime_type,nas_media.mime_type),
            duration_millis=COALESCE(excluded.duration_millis,nas_media.duration_millis),
            width=COALESCE(excluded.width,nas_media.width),height=COALESCE(excluded.height,nas_media.height),
            title=COALESCE(excluded.title,nas_media.title),artist=COALESCE(excluded.artist,nas_media.artist),
            album=COALESCE(excluded.album,nas_media.album),track_number=COALESCE(excluded.track_number,nas_media.track_number),
            is_favorite=CASE WHEN ? THEN excluded.is_favorite ELSE nas_media.is_favorite END,
            scan_generation=excluded.scan_generation,sort_epoch=excluded.sort_epoch,
            folder=CASE WHEN excluded.source_path IS NULL AND nas_media.source_path IS NOT NULL THEN nas_media.folder ELSE excluded.folder END,
            source_path=COALESCE(excluded.source_path,nas_media.source_path)''',
          );
          try {
            for (final item in items) {
              if (item.serverId != serverId) {
                throw ArgumentError('NAS_SOURCE_MISMATCH');
              }
              insert.execute([
                serverId,
                item.path,
                item.kind.name,
                item.sizeBytes,
                item.modifiedEpoch,
                item.mimeType,
                item.durationMillis,
                item.width,
                item.height,
                item.title,
                item.artist,
                item.album,
                item.trackNumber,
                item.isFavorite ? 1 : 0,
                generation,
                -item.modifiedEpoch,
                _folder(item.sourcePath ?? item.path),
                item.sourcePath,
                syncFavorites ? 1 : 0,
              ]);
            }
          } finally {
            insert.dispose();
          }
        });
      } finally {
        db.dispose();
      }
    }),
  );

  /// Call only after the remote scan succeeds. Interrupted scans keep old rows.
  Future<void> finishScan(
    String serverId,
    int generation, {
    NasCancellation? cancellation,
  }) => _write(() {
    cancellation?.check();
    return _finishScan(databasePath, serverId, generation);
  });

  static Future<void> _finishScan(
    String databasePath,
    String serverId,
    int generation,
  ) => Isolate.run(() {
    final db = _open(databasePath);
    try {
      _transaction(db, () {
        _checkGeneration(db, serverId, generation);
        db.execute(
          'DELETE FROM nas_media WHERE server_id = ? AND scan_generation <> ?',
          [serverId, generation],
        );
      });
    } finally {
      db.dispose();
    }
  });

  Future<void> updateMetadata(NasMediaItem item) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        db.execute(
          '''UPDATE nas_media SET title = COALESCE(?, title),
        artist = COALESCE(?, artist), album = COALESCE(?, album),
        track_number = COALESCE(?, track_number), duration_millis = COALESCE(?, duration_millis),
        mime_type = COALESCE(?, mime_type), width = COALESCE(?, width), height = COALESCE(?, height)
        WHERE server_id = ? AND path = ?''',
          [
            item.title,
            item.artist,
            item.album,
            item.trackNumber,
            item.durationMillis,
            item.mimeType,
            item.width,
            item.height,
            item.serverId,
            item.path,
          ],
        );
      } finally {
        db.dispose();
      }
    }),
  );

  /// 0 = pending, 1 = inspected, 2 = failed until the next explicit rescan.
  Future<List<NasMediaItem>> pendingMetadata(
    String sourceId, {
    int limit = 32,
  }) => Isolate.run(() {
    if (limit < 1 || limit > 32) throw ArgumentError.value(limit, 'limit');
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      return db
          .select(
            '''SELECT * FROM nas_media WHERE server_id = ?
        AND kind = 'audio' AND metadata_probed = 0 ORDER BY sort_epoch, path LIMIT ?''',
            [sourceId, limit],
          )
          .map(_item)
          .toList();
    } finally {
      db.dispose();
    }
  });

  /// A probe of an older file version must not label a newly scanned file.
  Future<void> completeMetadataProbe(
    NasMediaItem original, {
    NasMediaItem? metadata,
    bool failed = false,
  }) => _write(
    () => Isolate.run(() {
      if (metadata != null &&
          (metadata.serverId != original.serverId ||
              metadata.path != original.path)) {
        throw ArgumentError('NAS_SOURCE_MISMATCH');
      }
      final db = _open(databasePath);
      try {
        if (failed || metadata == null) {
          db.execute(
            '''UPDATE nas_media SET metadata_probed = ? WHERE server_id = ? AND path = ?
          AND size_bytes = ? AND modified_epoch = ?''',
            [
              failed ? 2 : 1,
              original.serverId,
              original.path,
              original.sizeBytes,
              original.modifiedEpoch,
            ],
          );
        } else {
          db.execute(
            '''UPDATE nas_media SET metadata_probed = 1, title = ?, artist = ?,
          album = ?, track_number = ?, duration_millis = ?
          WHERE server_id = ? AND path = ? AND size_bytes = ? AND modified_epoch = ?''',
            [
              metadata.title,
              metadata.artist,
              metadata.album,
              metadata.trackNumber,
              metadata.durationMillis,
              original.serverId,
              original.path,
              original.sizeBytes,
              original.modifiedEpoch,
            ],
          );
        }
      } finally {
        db.dispose();
      }
    }),
  );

  Future<List<NasMediaItem>> query(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    int limit = 200,
    int offset = 0,
  }) => Isolate.run(() {
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      _checkLimit(limit);
      if (offset < 0) throw ArgumentError.value(offset, 'offset');
      final (where, values) = _where(serverId, kind: kind, search: search);
      return db
          .select(
            'SELECT * FROM nas_media WHERE $where ORDER BY sort_epoch, path LIMIT ? OFFSET ?',
            [...values, limit, offset],
          )
          .map(_item)
          .toList();
    } finally {
      db.dispose();
    }
  });

  Future<NasIndexPage> queryPage(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    NasIndexCursor? cursor,
    int limit = 200,
  }) => Isolate.run(() {
    _checkLimit(limit);
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final (where, values) = _where(
        serverId,
        kind: kind,
        search: search,
        favoritesOnly: favoritesOnly,
        folder: folder,
        artist: artist,
        album: album,
        cursor: cursor,
      );
      final rows = db.select(
        'SELECT * FROM nas_media WHERE $where ORDER BY sort_epoch, path LIMIT ?',
        [...values, limit + 1],
      );
      final more = rows.length > limit;
      final items = rows.take(limit).map(_item).toList();
      final last = items.lastOrNull;
      return NasIndexPage(
        items,
        last == null ? null : NasIndexCursor(last.modifiedEpoch, last.path),
        more,
      );
    } finally {
      db.dispose();
    }
  });

  Future<int> count(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
  }) => Isolate.run(() {
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final (where, values) = _where(
        serverId,
        kind: kind,
        search: search,
        favoritesOnly: favoritesOnly,
        folder: folder,
        artist: artist,
        album: album,
      );
      return db
              .select(
                'SELECT COUNT(*) AS n FROM nas_media WHERE $where',
                values,
              )
              .single['n']
          as int;
    } finally {
      db.dispose();
    }
  });

  Future<NasIndexTotals> totals(String serverId) => Isolate.run(() {
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final kinds = {
        for (final row in db.select(
          'SELECT kind, COUNT(*) AS n FROM nas_media WHERE server_id = ? GROUP BY kind',
          [serverId],
        ))
          row['kind'] as String: row['n'] as int,
      };
      final favorites =
          db.select(
                'SELECT COUNT(*) AS n FROM nas_media WHERE server_id = ? AND is_favorite = 1',
                [serverId],
              ).single['n']
              as int;
      return NasIndexTotals(
        total: kinds.values.fold(0, (a, b) => a + b),
        images: kinds['image'] ?? 0,
        videos: kinds['video'] ?? 0,
        audio: kinds['audio'] ?? 0,
        favorites: favorites,
      );
    } finally {
      db.dispose();
    }
  });

  Future<List<NasIndexGroupCount>> groups(
    String serverId,
    NasIndexGroup group, {
    String? after,
    int limit = 200,
  }) => Isolate.run(() {
    _checkLimit(limit);
    final column = switch (group) {
      NasIndexGroup.byFolder => 'folder',
      NasIndexGroup.byArtist => 'artist',
      NasIndexGroup.byAlbum => 'album',
    };
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      return db
          .select(
            'SELECT $column AS name, COUNT(*) AS n FROM nas_media WHERE server_id = ? AND $column > ? GROUP BY $column ORDER BY $column LIMIT ?',
            [serverId, after ?? '', limit],
          )
          .map(
            (row) => NasIndexGroupCount(row['name'] as String, row['n'] as int),
          )
          .toList();
    } finally {
      db.dispose();
    }
  });

  static (String, List<Object?>) _where(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    NasIndexCursor? cursor,
  }) {
    final clauses = ['server_id = ?'];
    final values = <Object?>[serverId];
    if (kind != null) {
      clauses.add('kind = ?');
      values.add(kind.name);
    }
    if (favoritesOnly) clauses.add('is_favorite = 1');
    for (final entry in {
      'folder': folder,
      'artist': artist,
      'album': album,
    }.entries) {
      if (entry.value != null) {
        clauses.add('${entry.key} = ?');
        values.add(entry.value);
      }
    }
    if (search.trim().isNotEmpty) {
      // Quote user terms as FTS literals: operators, quotes and punctuation
      // never become executable MATCH syntax. Search is token-prefix based.
      final terms = search
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => '"${s.replaceAll('"', '""')}"*')
          .join(' AND ');
      clauses.add(
        'rowid IN (SELECT rowid FROM nas_media_search WHERE nas_media_search MATCH ?)',
      );
      values.add(terms);
    }
    if (cursor != null) {
      clauses.add('(sort_epoch, path) > (?, ?)');
      values.addAll([-cursor.modifiedEpoch, cursor.path]);
    }
    return (clauses.join(' AND '), values);
  }

  static NasMediaItem _item(Row row) => NasMediaItem(
    serverId: row['server_id'] as String,
    path: row['path'] as String,
    kind: NasMediaKind.values.byName(row['kind'] as String),
    sizeBytes: row['size_bytes'] as int,
    modifiedEpoch: row['modified_epoch'] as int,
    mimeType: row['mime_type'] as String?,
    durationMillis: row['duration_millis'] as int?,
    width: row['width'] as int?,
    height: row['height'] as int?,
    title: row['title'] as String?,
    artist: row['artist'] as String?,
    album: row['album'] as String?,
    trackNumber: row['track_number'] as int?,
    isFavorite: row['is_favorite'] == 1,
    sourcePath: row['source_path'] as String?,
  );

  Future<void> setFavorite(
    String serverId,
    String remotePath,
    bool value,
  ) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        db.execute(
          'UPDATE nas_media SET is_favorite = ? WHERE server_id = ? AND path = ?',
          [value ? 1 : 0, serverId, remotePath],
        );
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> savePlayback(NasPlaybackState playback) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        db.execute(
          '''
            INSERT INTO nas_playback
              (server_id, path, position_millis, duration_millis, updated_epoch)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(server_id, path) DO UPDATE SET
              position_millis = excluded.position_millis,
              duration_millis = excluded.duration_millis,
              updated_epoch = excluded.updated_epoch
          ''',
          [
            playback.serverId,
            playback.path,
            playback.position.inMilliseconds,
            playback.duration?.inMilliseconds,
            playback.updatedAt.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      } finally {
        db.dispose();
      }
    }),
  );

  Future<List<NasPlaylist>> playlistsFor(
    String serverId, {
    int limit = 1000,
    int offset = 0,
  }) => Isolate.run(() {
    _checkLimit(limit);
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        '''SELECT p.id, p.server_id, p.name, p.created_epoch,
                  COUNT(i.path) AS item_count
           FROM nas_playlists p
           LEFT JOIN nas_playlist_items i ON i.playlist_id = p.id
           WHERE p.server_id = ?
           GROUP BY p.id, p.server_id, p.name, p.created_epoch
           ORDER BY p.created_epoch, p.name COLLATE NOCASE LIMIT ? OFFSET ?''',
        [serverId, limit, offset],
      );
      return [
        for (final row in rows)
          NasPlaylist(
            id: row['id'] as String,
            serverId: row['server_id'] as String,
            name: row['name'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (row['created_epoch'] as int) * 1000,
            ),
            itemCount: row['item_count'] as int,
          ),
      ];
    } finally {
      db.dispose();
    }
  });

  Future<void> createPlaylist(NasPlaylist playlist) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        db.execute(
          'INSERT INTO nas_playlists (id, server_id, name, created_epoch) VALUES (?, ?, ?, ?)',
          [
            playlist.id,
            playlist.serverId,
            playlist.name,
            playlist.createdAt.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> deletePlaylist(String serverId, String playlistId) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      var inTransaction = false;
      try {
        db.execute('BEGIN IMMEDIATE');
        inTransaction = true;
        db.execute(
          'DELETE FROM nas_playlist_items WHERE playlist_id IN (SELECT id FROM nas_playlists WHERE id = ? AND server_id = ?)',
          [playlistId, serverId],
        );
        db.execute('DELETE FROM nas_playlists WHERE id = ? AND server_id = ?', [
          playlistId,
          serverId,
        ]);
        db.execute('COMMIT');
        inTransaction = false;
      } catch (_) {
        if (inTransaction) db.execute('ROLLBACK');
        rethrow;
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> addToPlaylist({
    required String serverId,
    required String playlistId,
    required String path,
    int? position,
  }) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        _transaction(db, () {
          if (!_ownsPlaylist(db, serverId, playlistId)) return;
          final exists = db.select(
            'SELECT 1 FROM nas_playlist_items WHERE playlist_id = ? AND path = ?',
            [playlistId, path],
          ).isNotEmpty;
          if (exists) return;
          final count =
              db.select(
                    'SELECT COUNT(*) AS n FROM nas_playlist_items WHERE playlist_id = ?',
                    [playlistId],
                  ).single['n']
                  as int;
          final target = (position ?? count).clamp(0, count);
          db.execute(
            'UPDATE nas_playlist_items SET position = position + 1 WHERE playlist_id = ? AND position >= ?',
            [playlistId, target],
          );
          db.execute(
            'INSERT INTO nas_playlist_items(playlist_id, path, position) VALUES (?, ?, ?)',
            [playlistId, path, target],
          );
        });
      } finally {
        db.dispose();
      }
    }),
  );

  Future<List<String>> playlistItems(
    String serverId,
    String playlistId, {
    int limit = 1000,
    int offset = 0,
  }) => Isolate.run(() {
    _checkLimit(limit);
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        '''SELECT i.path FROM nas_playlist_items i
               JOIN nas_playlists p ON p.id = i.playlist_id
               WHERE i.playlist_id = ? AND p.server_id = ?
               ORDER BY i.position, i.path COLLATE NOCASE LIMIT ? OFFSET ?''',
        [playlistId, serverId, limit, offset],
      );
      return [for (final row in rows) row['path'] as String];
    } finally {
      db.dispose();
    }
  });

  Future<void> renamePlaylist(
    String serverId,
    String playlistId,
    String name,
  ) => _write(
    () => Isolate.run(() {
      if (name.trim().isEmpty) {
        throw ArgumentError('NAS_PLAYLIST_NAME_REQUIRED');
      }
      final db = _open(databasePath);
      try {
        db.execute(
          'UPDATE nas_playlists SET name = ? WHERE server_id = ? AND id = ?',
          [name.trim(), serverId, playlistId],
        );
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> removeFromPlaylist(
    String serverId,
    String playlistId,
    String path,
  ) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        _transaction(db, () {
          if (!_ownsPlaylist(db, serverId, playlistId)) return;
          final row = db.select(
            'SELECT position FROM nas_playlist_items WHERE playlist_id = ? AND path = ?',
            [playlistId, path],
          ).firstOrNull;
          if (row == null) return;
          db.execute(
            'DELETE FROM nas_playlist_items WHERE playlist_id = ? AND path = ?',
            [playlistId, path],
          );
          db.execute(
            'UPDATE nas_playlist_items SET position = position - 1 WHERE playlist_id = ? AND position > ?',
            [playlistId, row['position']],
          );
        });
      } finally {
        db.dispose();
      }
    }),
  );

  Future<void> movePlaylistItem(
    String serverId,
    String playlistId,
    String path,
    int index,
  ) => _write(
    () => Isolate.run(() {
      final db = _open(databasePath);
      try {
        _transaction(db, () {
          if (!_ownsPlaylist(db, serverId, playlistId)) return;
          final row = db.select(
            'SELECT position FROM nas_playlist_items WHERE playlist_id = ? AND path = ?',
            [playlistId, path],
          ).firstOrNull;
          if (row == null) return;
          final previous = row['position'] as int;
          final count =
              db.select(
                    'SELECT COUNT(*) AS n FROM nas_playlist_items WHERE playlist_id = ?',
                    [playlistId],
                  ).single['n']
                  as int;
          final target = index.clamp(0, count - 1);
          if (previous < target) {
            db.execute(
              'UPDATE nas_playlist_items SET position = position - 1 WHERE playlist_id = ? AND position > ? AND position <= ?',
              [playlistId, previous, target],
            );
          } else if (previous > target) {
            db.execute(
              'UPDATE nas_playlist_items SET position = position + 1 WHERE playlist_id = ? AND position >= ? AND position < ?',
              [playlistId, target, previous],
            );
          }
          db.execute(
            'UPDATE nas_playlist_items SET position = ? WHERE playlist_id = ? AND path = ?',
            [target, playlistId, path],
          );
        });
      } finally {
        db.dispose();
      }
    }),
  );

  Future<NasPlaylistPage> playlistMediaPage(
    String serverId,
    String playlistId, {
    int? afterPosition,
    int limit = 200,
  }) => Isolate.run(() {
    _checkLimit(limit);
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        '''SELECT m.*, i.position AS playlist_position FROM nas_playlist_items i
        JOIN nas_playlists p ON p.id = i.playlist_id
        JOIN nas_media m ON m.server_id = p.server_id AND m.path = i.path
        WHERE p.server_id = ? AND p.id = ? AND i.position > ?
        ORDER BY i.position, i.path LIMIT ?''',
        [serverId, playlistId, afterPosition ?? -1, limit + 1],
      );
      final page = rows.take(limit).toList();
      return NasPlaylistPage(
        page.map(_item).toList(),
        page.lastOrNull?['playlist_position'] as int?,
        rows.length > limit,
      );
    } finally {
      db.dispose();
    }
  });

  Future<NasPlaybackState?> playbackFor(
    String serverId,
    String remotePath,
  ) => Isolate.run(() {
    final db = _open(databasePath, mode: OpenMode.readOnly);
    try {
      final row = db.select(
        'SELECT position_millis, duration_millis, updated_epoch FROM nas_playback WHERE server_id = ? AND path = ?',
        [serverId, remotePath],
      ).firstOrNull;
      if (row == null) return null;
      return NasPlaybackState(
        serverId: serverId,
        path: remotePath,
        position: Duration(milliseconds: row['position_millis'] as int),
        duration: row['duration_millis'] == null
            ? null
            : Duration(milliseconds: row['duration_millis'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['updated_epoch'] as int) * 1000,
        ),
      );
    } finally {
      db.dispose();
    }
  });

  static void _addColumn(Database db, String table, String column) {
    final name = column.split(' ').first;
    final existing = db
        .select('PRAGMA table_info($table)')
        .any((row) => row['name'] == name);
    if (!existing) db.execute('ALTER TABLE $table ADD COLUMN $column');
  }

  static void _checkLimit(int limit) {
    if (limit < 1 || limit > 10000) {
      throw ArgumentError.value(limit, 'limit', 'Must be 1..10000');
    }
  }

  static String _folder(String path) {
    final end = path.lastIndexOf('/');
    return end <= 0 ? '/' : path.substring(0, end);
  }

  static bool _ownsPlaylist(Database db, String sourceId, String playlistId) =>
      db.select('SELECT 1 FROM nas_playlists WHERE server_id = ? AND id = ?', [
        sourceId,
        playlistId,
      ]).isNotEmpty;

  static void _checkGeneration(Database db, String sourceId, int generation) {
    final row = db.select(
      'SELECT generation FROM nas_scans WHERE server_id = ?',
      [sourceId],
    ).firstOrNull;
    if (row == null || row['generation'] != generation) {
      throw StateError('NAS_STALE_SCAN');
    }
  }

  static T _transaction<T>(Database db, T Function() operation) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static Database _open(
    String path, {
    OpenMode mode = OpenMode.readWriteCreate,
  }) {
    try {
      final db = sqlite3.open(path, mode: mode);
      db.execute('PRAGMA busy_timeout = 5000');
      return db;
    } on ArgumentError {
      if (!Platform.isLinux) rethrow;
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
      final db = sqlite3.open(path, mode: mode);
      db.execute('PRAGMA busy_timeout = 5000');
      return db;
    }
  }
}
