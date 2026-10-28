import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/nas_media.dart';
import '../models/nas_source.dart';
import '../repositories/nas_index_repository.dart';
import 'workspace_gateway.dart';

/// Backend page cap for NAS queries.
const int kWorkspaceNasPageLimit = 200;

/// Largest number of records accepted by one durable commit.
const int kWorkspaceNasCommitLimit = 500;

/// Record `kind` shared by every NAS entity.
///
/// The workspace backend deliberately accepts only opaque ids for this kind,
/// so the entity type travels inside the typed JSON value instead of the kind.
const String kWorkspaceNasRecordKind = 'nas_media';

/// Server-backed NAS index.
///
/// The remote workspace is the source of truth for a shared library. Queries
/// are bounded and indexed server-side; the local SQLite database is only a
/// cache used when the workspace is disabled or offline. Media bytes,
/// thumbnails, downloads and credentials never leave the device.
class WorkspaceNasSync implements NasRemoteSink, NasRemoteIndex {
  final WorkspaceGateway? Function() gateway;
  final NasSource? Function(String sourceId) sourceFor;
  final String? Function(String sourceId)? ownerFor;
  final NasIndexRepository repository;

  /// Servers whose backend did not understand a NAS op. Avoids paying a
  /// round-trip for every tile until the app restarts or the backend updates.
  final Set<String> _unsupported = {};

  WorkspaceNasSync({
    required this.gateway,
    required this.sourceFor,
    this.ownerFor,
    required this.repository,
  });

  WorkspaceGateway? get _gateway => gateway();

  /// The workspace gateway is keyed by the SSH server profile id, while the
  /// repository is keyed by the media source id. Direct media sources use the
  /// workspace ownership chosen during migration; their credentials stay local.
  String? serverIdFor(String sourceId) {
    final source = sourceFor(sourceId);
    if (source == null) return null;
    final ssh = source.sshServerId ?? ownerFor?.call(sourceId);
    if (ssh == null || ssh.isEmpty) return null;
    final gateway = _gateway;
    if (gateway == null || !gateway.isEnabled(ssh)) return null;
    if (_unsupported.contains(ssh)) return null;
    return ssh;
  }

  @override
  bool isAvailable(String sourceId) => serverIdFor(sourceId) != null;

  Future<Map<String, dynamic>?> _request(
    String sourceId,
    Map<String, dynamic> command,
  ) async {
    final serverId = serverIdFor(sourceId);
    if (serverId == null) return null;
    try {
      final response = await _gateway!.request(serverId, {
        ...command,
        'sourceId': sourceId,
      });
      if (response['ok'] == false) {
        if (_unsupportedCode(response['error'])) {
          _unsupported.add(serverId);
        }
        return null;
      }
      return response;
    } catch (error) {
      final code = error.toString();
      if (_unsupportedCode(code)) _unsupported.add(serverId);
      return null;
    }
  }

  static bool _unsupportedCode(Object? value) {
    final code = value?.toString() ?? '';
    return code.contains('WORKSPACE_OP_UNKNOWN') ||
        code.contains('WORKSPACE_OP_INVALID') ||
        code.contains('WORKSPACE_REQUEST_INVALID');
  }

  // ---------------------------------------------------------------------
  // Records
  // ---------------------------------------------------------------------

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static String mediaRecordId(String sourceId, String path) =>
      'media/$sourceId/${_digest(path)}';

  static String favoriteRecordId(String sourceId, String path) =>
      'favorite/$sourceId/${_digest(path)}';

  static String playbackRecordId(String sourceId, String path) =>
      'playback/$sourceId/${_digest(path)}';

  static String playlistRecordId(String sourceId, String playlistId) =>
      'playlist/$sourceId/${_digest(playlistId)}';

  static String playlistItemRecordId(
    String sourceId,
    String playlistId,
    String path,
  ) => 'playlist_item/$sourceId/${_digest(playlistId)}/${_digest(path)}';

  static Map<String, dynamic> _record(
    String id,
    Map<String, dynamic>? value, {
    bool deleted = false,
  }) => {
    'kind': kWorkspaceNasRecordKind,
    'id': id,
    'value': value,
    'deleted': deleted,
  };

  static Map<String, dynamic> mediaValue(String sourceId, NasMediaItem item) =>
      {
        'type': 'media',
        'sourceId': sourceId,
        'path': item.path,
        'kind': item.kind.name,
        'sizeBytes': item.sizeBytes,
        'modifiedEpoch': item.modifiedEpoch,
        'mimeType': item.mimeType,
        'durationMillis': item.durationMillis,
        'width': item.width,
        'height': item.height,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'albumId': item.albumId,
        'albumArtist': item.albumArtist,
        'discNumber': item.discNumber,
        'trackNumber': item.trackNumber,
        'sourcePath': item.sourcePath,
        // Derived fields are written by the device that owns the scan so every
        // reader computes identical grouping and name ordering.
        'folder': item.folder,
        'sortName': (item.title?.isNotEmpty == true ? item.title! : item.name)
            .toLowerCase(),
        'albumKey': item.albumKey,
        'discOrder': item.discNumber != null && item.discNumber! > 0
            ? item.discNumber
            : 2147483647,
        'trackOrder': item.trackNumber != null && item.trackNumber! > 0
            ? item.trackNumber
            : 2147483647,
      };

  static Map<String, dynamic> favoriteValue(
    String sourceId,
    String path,
    bool value,
    int updatedEpoch,
  ) => {
    'type': 'favorite',
    'sourceId': sourceId,
    'path': path,
    'value': value,
    'updatedEpoch': updatedEpoch,
  };

  static Map<String, dynamic> playbackValue(
    String sourceId,
    NasPlaybackState playback,
  ) => {
    'type': 'playback',
    'sourceId': sourceId,
    'path': playback.path,
    'positionMillis': playback.position.inMilliseconds,
    'durationMillis': playback.duration?.inMilliseconds,
    'updatedEpoch': playback.updatedAt.millisecondsSinceEpoch ~/ 1000,
  };

  static Map<String, dynamic> playlistValue(
    String sourceId,
    NasPlaylist playlist,
  ) => {
    'type': 'playlist',
    'sourceId': sourceId,
    'playlistId': playlist.id,
    'name': playlist.name,
    'createdEpoch': playlist.createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  static Map<String, dynamic> playlistItemValue(
    String sourceId,
    String playlistId,
    String path,
    int position,
  ) => {
    'type': 'playlist_item',
    'sourceId': sourceId,
    'playlistId': playlistId,
    'path': path,
    'position': position,
  };

  Future<void> _put(String sourceId, List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;
    final serverId = serverIdFor(sourceId);
    if (serverId == null) return;
    for (
      var start = 0;
      start < records.length;
      start += kWorkspaceNasCommitLimit
    ) {
      final end = (start + kWorkspaceNasCommitLimit).clamp(0, records.length);
      // A migration cursor advances only after the outbox accepts this page.
      await _gateway!.putRecords(serverId, records.sublist(start, end));
    }
  }

  @override
  Future<void> mediaChanged(String sourceId, List<NasMediaItem> items) =>
      _put(sourceId, [
        for (final item in items)
          _record(
            mediaRecordId(sourceId, item.path),
            mediaValue(sourceId, item),
          ),
      ]);

  @override
  Future<void> mediaDeleted(String sourceId, List<String> paths) =>
      _put(sourceId, [
        for (final path in paths)
          _record(mediaRecordId(sourceId, path), {
            'type': 'media',
            'sourceId': sourceId,
            'path': path,
          }, deleted: true),
      ]);

  @override
  Future<void> favoriteChanged(
    String sourceId,
    String path,
    bool value,
    int updatedEpoch,
  ) => _put(sourceId, [
    _record(
      favoriteRecordId(sourceId, path),
      favoriteValue(sourceId, path, value, updatedEpoch),
    ),
  ]);

  @override
  Future<void> playbackChanged(NasPlaybackState playback) =>
      _put(playback.serverId, [
        _record(
          playbackRecordId(playback.serverId, playback.path),
          playbackValue(playback.serverId, playback),
        ),
      ]);

  @override
  Future<void> playlistChanged(String sourceId, NasPlaylist playlist) =>
      _put(sourceId, [
        _record(
          playlistRecordId(sourceId, playlist.id),
          playlistValue(sourceId, playlist),
        ),
      ]);

  @override
  Future<void> playlistDeleted(String sourceId, String playlistId) =>
      _put(sourceId, [
        _record(playlistRecordId(sourceId, playlistId), {
          'type': 'playlist',
          'sourceId': sourceId,
          'playlistId': playlistId,
        }, deleted: true),
      ]);

  @override
  Future<void> playlistItemChanged(
    String sourceId,
    String playlistId,
    String path,
    int position,
  ) => _put(sourceId, [
    _record(
      playlistItemRecordId(sourceId, playlistId, path),
      playlistItemValue(sourceId, playlistId, path, position),
    ),
  ]);

  @override
  Future<void> playlistItemDeleted(
    String sourceId,
    String playlistId,
    String path,
  ) => _put(sourceId, [
    _record(playlistItemRecordId(sourceId, playlistId, path), {
      'type': 'playlist_item',
      'sourceId': sourceId,
      'playlistId': playlistId,
      'path': path,
    }, deleted: true),
  ]);

  // ---------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------

  static Map<String, dynamic>? _cursorJson(NasIndexCursor? cursor) =>
      cursor == null
      ? null
      : {
          'sortValue': cursor.sortValue,
          'path': cursor.path,
          'modifiedEpoch': cursor.modifiedEpoch,
          'discOrder': cursor.discOrder,
          'trackOrder': cursor.trackOrder,
        };

  static NasIndexCursor? _parseCursor(
    Object? raw, {
    required NasSortKey sortKey,
    required bool ascending,
    String? albumKey,
  }) {
    if (raw is! Map) return null;
    final path = raw['path'];
    if (path is! String) return null;
    return NasIndexCursor(
      (raw['modifiedEpoch'] as num?)?.toInt() ?? 0,
      path,
      sortKey: sortKey,
      ascending: ascending,
      sortValue: raw['sortValue'],
      albumKey: albumKey,
      discOrder: (raw['discOrder'] as num?)?.toInt(),
      trackOrder: (raw['trackOrder'] as num?)?.toInt(),
    );
  }

  static NasMediaItem _item(String sourceId, Map raw) => NasMediaItem(
    serverId: sourceId,
    path: raw['path'] as String,
    kind: NasMediaKind.values.byName(raw['kind'] as String),
    sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
    modifiedEpoch: (raw['modifiedEpoch'] as num?)?.toInt() ?? 0,
    mimeType: raw['mimeType'] as String?,
    durationMillis: (raw['durationMillis'] as num?)?.toInt(),
    width: (raw['width'] as num?)?.toInt(),
    height: (raw['height'] as num?)?.toInt(),
    title: raw['title'] as String?,
    artist: raw['artist'] as String?,
    album: raw['album'] as String?,
    albumId: raw['albumId'] as String?,
    albumArtist: raw['albumArtist'] as String?,
    discNumber: (raw['discNumber'] as num?)?.toInt(),
    trackNumber: (raw['trackNumber'] as num?)?.toInt(),
    isFavorite: raw['favorite'] == true,
    sourcePath: raw['sourcePath'] as String?,
  );

  Future<List<NasMediaItem>> _cacheItems(
    String sourceId,
    List<Map> records,
  ) async {
    final items = <NasMediaItem>[];
    final favorites = <(String, bool, int)>[];
    for (final raw in records) {
      try {
        final item = _item(sourceId, raw);
        items.add(item);
        final favorite = raw['favorite'];
        final epoch = (raw['favoriteEpoch'] as num?)?.toInt();
        if (favorite is bool && epoch != null) {
          favorites.add((item.path, favorite, epoch));
        }
      } on Object {
        // A malformed remote record must not break the whole page.
      }
    }
    if (items.isNotEmpty) {
      try {
        await repository.applyRemoteMedia(sourceId, items);
        for (final (path, value, epoch) in favorites) {
          await repository.applyRemoteFavorite(sourceId, path, value, epoch);
        }
      } catch (_) {
        // Caching is best effort; the remote page is still returned.
      }
    }
    return items;
  }

  @override
  Future<NasIndexPage?> queryPage(
    String sourceId, {
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
  }) async {
    if (!isAvailable(sourceId)) return null;
    final bounded = limit.clamp(1, kWorkspaceNasPageLimit);
    final response = await _request(sourceId, {
      'op': 'nas_query',
      'kind': kind?.name,
      'search': search,
      'favoritesOnly': favoritesOnly,
      'folder': folder,
      'artist': artist,
      'album': album,
      'albumKey': albumKey,
      'modifiedFromEpoch': modifiedFromEpoch,
      'modifiedBeforeEpoch': modifiedBeforeEpoch,
      'cursor': _cursorJson(cursor),
      'before': before,
      'inclusive': inclusive,
      'sortKey': sortKey.name,
      'ascending': sortAscending,
      'limit': bounded,
    });
    if (response == null) return null;
    final raw = response['records'];
    final records = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    final items = await _cacheItems(sourceId, records);
    return NasIndexPage(
      items,
      _parseCursor(
        response['nextCursor'],
        sortKey: sortKey,
        ascending: sortAscending,
        albumKey: albumKey,
      ),
      response['hasMore'] == true,
    );
  }

  @override
  Future<List<NasMediaItem>?> query(
    String sourceId, {
    NasMediaKind? kind,
    String search = '',
    int limit = 200,
    int offset = 0,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_query',
      'kind': kind?.name,
      'search': search,
      'offset': offset,
      'limit': limit.clamp(1, kWorkspaceNasPageLimit),
    });
    if (response == null) return null;
    final raw = response['records'];
    return _cacheItems(
      sourceId,
      raw is List ? raw.whereType<Map>().toList() : const <Map>[],
    );
  }

  static Map<String, dynamic> _filterCommand({
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
  }) => {
    'kind': kind?.name,
    'search': search,
    'favoritesOnly': favoritesOnly,
    'folder': folder,
    'artist': artist,
    'album': album,
    'albumKey': albumKey,
    'modifiedFromEpoch': modifiedFromEpoch,
    'modifiedBeforeEpoch': modifiedBeforeEpoch,
  };

  @override
  Future<int?> count(
    String sourceId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_count',
      ..._filterCommand(
        kind: kind,
        search: search,
        favoritesOnly: favoritesOnly,
        folder: folder,
        artist: artist,
        album: album,
        albumKey: albumKey,
        modifiedFromEpoch: modifiedFromEpoch,
        modifiedBeforeEpoch: modifiedBeforeEpoch,
      ),
    });
    final value = response?['count'];
    return value is num ? value.toInt() : null;
  }

  @override
  Future<NasIndexTotals?> totals(String sourceId) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {'op': 'nas_totals'});
    if (response == null) return null;
    final value = response['totals'];
    if (value is! Map) return null;
    int read(String key) => (value[key] as num?)?.toInt() ?? 0;
    return NasIndexTotals(
      total: read('total'),
      images: read('images'),
      videos: read('videos'),
      audio: read('audio'),
      favorites: read('favorites'),
    );
  }

  @override
  Future<List<NasIndexGroupCount>?> groups(
    String sourceId,
    NasIndexGroup group, {
    String? after,
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
    int limit = 200,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_groups',
      'group': switch (group) {
        NasIndexGroup.byFolder => 'folder',
        NasIndexGroup.byArtist => 'artist',
        NasIndexGroup.byAlbum => 'album',
        NasIndexGroup.byDate => 'date',
      },
      'after': after,
      'limit': limit.clamp(1, kWorkspaceNasPageLimit),
      ..._filterCommand(
        kind: kind,
        search: search,
        favoritesOnly: favoritesOnly,
        folder: folder,
        artist: artist,
        albumKey: albumKey,
        modifiedFromEpoch: modifiedFromEpoch,
        modifiedBeforeEpoch: modifiedBeforeEpoch,
      ),
    });
    if (response == null) return null;
    final raw = response['groups'];
    if (raw is! List) return null;
    return [
      for (final value in raw.whereType<Map>())
        NasIndexGroupCount(
          value['name'] as String? ?? value['key'] as String? ?? '',
          (value['count'] as num?)?.toInt() ?? 0,
          key: value['key'] as String?,
          representative: value['representative'] is Map
              ? _item(sourceId, value['representative'] as Map)
              : null,
          totalDurationMillis: (value['totalDurationMillis'] as num?)?.toInt(),
          modifiedFromEpoch: (value['modifiedFromEpoch'] as num?)?.toInt(),
          modifiedBeforeEpoch: (value['modifiedBeforeEpoch'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<List<NasPlaylist>?> playlistsFor(
    String sourceId, {
    int limit = 1000,
    int offset = 0,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_playlists',
      'limit': limit.clamp(1, 1000),
      'offset': offset,
    });
    if (response == null) return null;
    final raw = response['playlists'];
    if (raw is! List) return null;
    final playlists = <NasPlaylist>[];
    for (final value in raw.whereType<Map>()) {
      try {
        final playlist = NasPlaylist(
          id: value['id'] as String,
          serverId: sourceId,
          name: value['name'] as String? ?? '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            ((value['createdEpoch'] as num?)?.toInt() ?? 0) * 1000,
          ),
          itemCount: (value['itemCount'] as num?)?.toInt() ?? 0,
        );
        playlists.add(playlist);
        await repository.applyRemotePlaylist(playlist);
      } on Object {
        // Skip one malformed playlist.
      }
    }
    return playlists;
  }

  @override
  Future<NasPlaylistPage?> playlistMediaPage(
    String sourceId,
    String playlistId, {
    int? afterPosition,
    int limit = 200,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_playlist_items',
      'playlistId': playlistId,
      'afterPosition': afterPosition,
      'limit': limit.clamp(1, kWorkspaceNasPageLimit),
    });
    if (response == null) return null;
    final raw = response['records'];
    final records = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    final items = await _cacheItems(sourceId, records);
    return NasPlaylistPage(
      items,
      (response['nextPosition'] as num?)?.toInt(),
      response['hasMore'] == true,
    );
  }

  @override
  Future<Map<String, NasPlaybackState>?> playbackForItems(
    String sourceId,
    Iterable<String> paths,
  ) async {
    if (!isAvailable(sourceId)) return null;
    final values = paths.toSet().toList();
    if (values.isEmpty) return const {};
    if (values.length > 600) {
      throw ArgumentError('NAS_PLAYBACK_BATCH_TOO_LARGE');
    }
    final response = await _request(sourceId, {
      'op': 'nas_playback',
      'paths': values,
    });
    if (response == null) return null;
    final raw = response['playback'];
    if (raw is! Map) return const {};
    final result = <String, NasPlaybackState>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final value = entry.value as Map;
      final state = NasPlaybackState(
        serverId: sourceId,
        path: entry.key as String,
        position: Duration(
          milliseconds: (value['positionMillis'] as num?)?.toInt() ?? 0,
        ),
        duration: value['durationMillis'] == null
            ? null
            : Duration(milliseconds: (value['durationMillis'] as num).toInt()),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          ((value['updatedEpoch'] as num?)?.toInt() ?? 0) * 1000,
        ),
      );
      result[state.path] = state;
      await repository.applyRemotePlayback(state);
    }
    return result;
  }

  @override
  Future<NasPlaybackState?> playbackFor(String sourceId, String path) async {
    final values = await playbackForItems(sourceId, [path]);
    return values?[path];
  }

  @override
  Future<List<NasMediaItem>?> recentPlayback(
    String sourceId, {
    int limit = 8,
    NasMediaKind kind = NasMediaKind.video,
  }) async {
    if (!isAvailable(sourceId)) return null;
    final response = await _request(sourceId, {
      'op': 'nas_recent',
      'kind': kind.name,
      'limit': limit.clamp(1, kWorkspaceNasPageLimit),
    });
    if (response == null) return null;
    final raw = response['records'];
    return _cacheItems(
      sourceId,
      raw is List ? raw.whereType<Map>().toList() : const <Map>[],
    );
  }

  // ---------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------

  /// Applies remote changes to the local cache in bounded pages.
  ///
  /// This keeps offline fallback and local deletions consistent without ever
  /// fetching a whole library at startup. Returns `true` when caught up.
  Future<bool> pullChanges(String sourceId, {int maxPages = 4}) async {
    if (!isAvailable(sourceId)) return false;
    final workspaceId = serverIdFor(sourceId) ?? '';
    var cursor = await repository.changesCursor(
      sourceId,
      workspaceId: workspaceId,
    );
    var caughtUp = false;
    for (var page = 0; page < maxPages; page++) {
      final response = await _request(sourceId, {
        'op': 'changes',
        'after': cursor,
        'limit': 100,
        'kinds': [kWorkspaceNasRecordKind],
      });
      if (response == null) return false;
      final raw = response['records'];
      final records = raw is List ? raw.whereType<Map>() : const <Map>[];
      for (final record in records) {
        await _applyChange(sourceId, Map<String, dynamic>.from(record));
      }
      final revision = (response['revision'] as num?)?.toInt();
      if (revision != null && revision > cursor) cursor = revision;
      await repository.saveChangesCursor(
        sourceId,
        workspaceId: workspaceId,
        cursor: cursor,
      );
      caughtUp = response['hasMore'] != true;
      if (caughtUp) break;
    }
    return caughtUp;
  }

  Future<void> _applyChange(
    String sourceId,
    Map<String, dynamic> record,
  ) async {
    final id = record['id'];
    if (id is! String) throw FormatException('NAS change missing id');
    final deleted = record['deleted'] == true;
    final rawValue = record['value'];
    final value = rawValue is Map ? Map<String, dynamic>.from(rawValue) : null;

    String? type = value?['type'] as String?;
    type ??= {
      'media': 'media',
      'favorite': 'favorite',
      'playback': 'playback',
      'playlist': 'playlist',
      'playlist_item': 'playlist_item',
    }[id.split('/').first];

    String? rowSource = value?['sourceId'] as String?;
    final idParts = id.split('/');
    rowSource ??= idParts.length > 1 ? idParts[1] : null;

    if (rowSource == null) throw FormatException('NAS change missing sourceId');
    if (rowSource != sourceId) {
      return; // Advance unrelated sources without importing them.
    }
    if (idParts.length < 3 || idParts[1] != sourceId) {
      throw FormatException('NAS change source/id mismatch');
    }

    if (type == null || !id.startsWith('$type/')) {
      throw FormatException('NAS change id/type mismatch');
    }
    if (value != null &&
        value['sourceId'] != null &&
        value['sourceId'] != sourceId) {
      throw FormatException('NAS change source mismatch');
    }
    if (deleted && value == null) {
      throw FormatException('NAS tombstone missing metadata');
    }

    switch (type) {
      case 'media':
        final path = value?['path'];
        if (path is! String) {
          throw FormatException('NAS media change missing path');
        }
        if (deleted) {
          await repository.applyRemoteMediaDeleted(sourceId, [path]);
        } else {
          await repository.applyRemoteMedia(sourceId, [
            _item(sourceId, value!),
          ]);
        }
      case 'favorite':
        final path = value?['path'];
        if (path is! String) {
          throw FormatException('NAS favorite change missing path');
        }
        if (deleted) return;
        await repository.applyRemoteFavorite(
          sourceId,
          path,
          value!['value'] == true,
          (value['updatedEpoch'] as num?)?.toInt() ?? 0,
        );
      case 'playback':
        final path = value?['path'];
        if (path is! String || deleted) {
          if (deleted && path is String) {
            // playback tombstones are not generated today; ignore safely.
          }
          if (deleted) return;
        }
        if (path is! String) {
          throw FormatException('NAS playback change missing path');
        }
        if (deleted) return;
        await repository.applyRemotePlayback(
          NasPlaybackState(
            serverId: sourceId,
            path: path,
            position: Duration(
              milliseconds: (value!['positionMillis'] as num?)?.toInt() ?? 0,
            ),
            duration: value['durationMillis'] == null
                ? null
                : Duration(
                    milliseconds: (value['durationMillis'] as num).toInt(),
                  ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              ((value['updatedEpoch'] as num?)?.toInt() ?? 0) * 1000,
            ),
          ),
        );
      case 'playlist':
        final playlistId = value?['playlistId'];
        if (playlistId is! String) {
          throw FormatException('NAS playlist change missing id');
        }
        await repository.applyRemotePlaylist(
          NasPlaylist(
            id: playlistId,
            serverId: sourceId,
            name: value?['name'] as String? ?? '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              ((value?['createdEpoch'] as num?)?.toInt() ?? 0) * 1000,
            ),
          ),
          deleted: deleted,
        );
      case 'playlist_item':
        final playlistId = value?['playlistId'];
        final path = value?['path'];
        if (playlistId is! String || path is! String) {
          throw FormatException('NAS playlist item change missing fields');
        }
        await repository.applyRemotePlaylistItem(
          sourceId: sourceId,
          playlistId: playlistId,
          path: path,
          position: (value?['position'] as num?)?.toInt() ?? 0,
          deleted: deleted,
        );
      default:
        throw FormatException('NAS change unknown type');
    }
  }

  // ---------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------

  /// Uploads the existing local index in bounded batches.
  ///
  /// Returns `true` when the source is fully migrated. Callers run a few
  /// batches per activation instead of blocking startup on a whole library.
  Future<bool> migrateSource(String sourceId, {int maxBatches = 1}) async {
    if (!isAvailable(sourceId)) return true;
    final workspaceId = serverIdFor(sourceId) ?? '';
    var cursor = await repository.migrationCursor(
      sourceId,
      workspaceId: workspaceId,
    );
    if (cursor.boundaryRowId < 0 && !cursor.done) {
      final boundary = await repository.migrationBoundary(
        sourceId,
        workspaceId: workspaceId,
      );
      cursor = (
        lastRowId: cursor.lastRowId,
        boundaryRowId: boundary,
        done: cursor.done,
        playlistOffset: cursor.playlistOffset,
        playlistsDone: cursor.playlistsDone,
        playbackOffset: cursor.playbackOffset,
        playbackDone: cursor.playbackDone,
      );
      await repository.saveMigrationCursor(
        sourceId,
        workspaceId: workspaceId,
        lastRowId: cursor.lastRowId,
        boundaryRowId: cursor.boundaryRowId,
        done: cursor.done,
        playlistOffset: cursor.playlistOffset,
        playlistsDone: cursor.playlistsDone,
        playbackOffset: cursor.playbackOffset,
        playbackDone: cursor.playbackDone,
      );
    }
    if (cursor.done && cursor.playlistsDone && cursor.playbackDone) return true;
    var batches = 0;
    while (batches < maxBatches &&
        !(cursor.done && cursor.playlistsDone && cursor.playbackDone)) {
      // Media stage first.
      if (!cursor.done) {
        final page = await repository.migrationPage(
          sourceId,
          afterRowId: cursor.lastRowId,
          limit: 200,
          workspaceId: workspaceId,
        );
        if (page.items.isNotEmpty) {
          final records = <Map<String, dynamic>>[
            for (final item in page.items)
              _record(
                mediaRecordId(sourceId, item.path),
                mediaValue(sourceId, item),
              ),
            for (final entry in page.favoriteEpochs.entries)
              _record(
                favoriteRecordId(sourceId, entry.key),
                favoriteValue(sourceId, entry.key, true, entry.value),
              ),
          ];
          await _put(sourceId, records);
        }
        cursor = (
          lastRowId: page.nextRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: page.done,
          playlistOffset: cursor.playlistOffset,
          playlistsDone: cursor.playlistsDone,
          playbackOffset: cursor.playbackOffset,
          playbackDone: cursor.playbackDone,
        );
        await repository.saveMigrationCursor(
          sourceId,
          workspaceId: workspaceId,
          lastRowId: cursor.lastRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: cursor.done,
          playlistOffset: cursor.playlistOffset,
          playlistsDone: cursor.playlistsDone,
          playbackOffset: cursor.playbackOffset,
          playbackDone: cursor.playbackDone,
        );
        batches++;
        continue;
      }

      if (cursor.done && !cursor.playlistsDone) {
        final playlists = await repository.playlistMigrationPage(
          sourceId,
          limit: 200,
          offset: cursor.playlistOffset,
        );
        await _put(sourceId, [
          for (final row in playlists)
            if (row['path'] case final String path)
              _record(
                playlistItemRecordId(
                  sourceId,
                  row['playlist_id'] as String,
                  path,
                ),
                playlistItemValue(
                  sourceId,
                  row['playlist_id'] as String,
                  path,
                  row['position'] as int,
                ),
              )
            else
              _record(
                playlistRecordId(sourceId, row['playlist_id'] as String),
                {
                  'type': 'playlist',
                  'sourceId': sourceId,
                  'playlistId': row['playlist_id'],
                  'name': row['name'],
                  'createdEpoch': row['created_epoch'],
                },
              ),
        ]);
        final nextOffset = cursor.playlistOffset + playlists.length;
        final done = playlists.length < 200;
        cursor = (
          lastRowId: cursor.lastRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: cursor.done,
          playlistOffset: nextOffset,
          playlistsDone: done,
          playbackOffset: cursor.playbackOffset,
          playbackDone: cursor.playbackDone,
        );
        await repository.saveMigrationCursor(
          sourceId,
          workspaceId: workspaceId,
          lastRowId: cursor.lastRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: cursor.done,
          playlistOffset: cursor.playlistOffset,
          playlistsDone: cursor.playlistsDone,
          playbackOffset: cursor.playbackOffset,
          playbackDone: cursor.playbackDone,
        );
        batches++;
        continue;
      }

      if (cursor.done && cursor.playlistsDone && !cursor.playbackDone) {
        final playbacks = await repository.playbackForMigration(
          sourceId,
          limit: 200,
          offset: cursor.playbackOffset,
        );
        for (final playback in playbacks) {
          await playbackChanged(playback);
        }
        final nextOffset = cursor.playbackOffset + playbacks.length;
        final done = playbacks.length < 200;
        cursor = (
          lastRowId: cursor.lastRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: cursor.done,
          playlistOffset: cursor.playlistOffset,
          playlistsDone: cursor.playlistsDone,
          playbackOffset: nextOffset,
          playbackDone: done,
        );
        await repository.saveMigrationCursor(
          sourceId,
          workspaceId: workspaceId,
          lastRowId: cursor.lastRowId,
          boundaryRowId: cursor.boundaryRowId,
          done: cursor.done,
          playlistOffset: cursor.playlistOffset,
          playlistsDone: cursor.playlistsDone,
          playbackOffset: cursor.playbackOffset,
          playbackDone: cursor.playbackDone,
        );
        batches++;
        continue;
      }
    }
    return cursor.done && cursor.playlistsDone && cursor.playbackDone;
  }
}
