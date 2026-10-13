import 'package:uuid/uuid.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/models/remote_browser.dart';
import 'nas_http_client.dart';

/// Small, explicit bindings to the official Jellyfin and Emby REST APIs. Their
/// authentication, item-list and playlist-update routes intentionally differ.
class NasMediaServerAdapter extends NasSourceAdapter {
  @override
  final NasSource source;
  final NasHttpClient _http;
  final Uri _base;
  final Map<String, String> _headers;
  final String _directSessionSeed = const Uuid().v4();
  static const _directSessionPrefix = 'valhalla-direct-';
  static const _pageSize = 200;
  static const _fields = 'Path,DateCreated,MediaSources,MediaStreams,Genres';

  NasMediaServerAdapter(this.source, NasCredentials credentials)
    : _base = _baseUri(source),
      _headers = _authenticationHeaders(source, credentials.token),
      _http = NasHttpClient(
        _baseUri(source),
        headers: _authenticationHeaders(source, credentials.token),
      ) {
    if (!source.isMediaServer) throw ArgumentError('NAS_SOURCE_MISMATCH');
  }
  bool get _emby => source.type == NasSourceType.emby;
  String get _user => _id(source.userId ?? '');
  Uri _url(String path, [Map<String, String> query = const {}]) => _base
      .resolve(path)
      .replace(queryParameters: query.isEmpty ? null : query);
  static Uri _baseUri(NasSource source) {
    final uri = nasHttpEndpoint(source.endpoint);
    if (uri.hasQuery) throw const NasHttpException('NAS_INVALID_ENDPOINT');
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/$'), '')}/');
  }

  static Map<String, String> _authenticationHeaders(
    NasSource source,
    String token,
  ) {
    // Header values originate in user/server data, so reject quotes and controls.
    if ([
      source.id,
      token,
    ].any((v) => RegExp(r'["\r\n\x00-\x1f]').hasMatch(v))) {
      throw const NasHttpException('NAS_INVALID_CREDENTIALS');
    }
    final identity =
        'MediaBrowser Client="Valhalla", Device="Valhalla", '
        'DeviceId="${source.id}", Version="1.0.0"';
    if (source.type == NasSourceType.emby) {
      return {
        if (source.forwardedHost != null) 'Host': source.forwardedHost!,
        'X-Emby-Authorization': identity,
        if (token.isNotEmpty) 'X-Emby-Token': token,
      };
    }
    return {
      if (source.forwardedHost != null) 'Host': source.forwardedHost!,
      'Authorization': '$identity${token.isEmpty ? '' : ', Token="$token"'}',
    };
  }

  static String _id(String value) {
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(value)) {
      throw const NasHttpException('NAS_INVALID_ITEM_ID');
    }
    return Uri.encodeComponent(value);
  }

  static Future<({String userId, NasCredentials credentials})> authenticate(
    NasSource source,
    String password,
  ) async {
    final base = _baseUri(source);
    final http = NasHttpClient(
      base,
      headers: _authenticationHeaders(source, ''),
    );
    try {
      final data = await http.json(
        'POST',
        base.resolve('Users/AuthenticateByName'),
        body: {'Username': source.username, 'Pw': password},
      );
      final token = data['AccessToken'];
      final user = data['User'];
      if (token is! String ||
          token.isEmpty ||
          user is! Map ||
          user['Id'] is! String) {
        throw const NasHttpException('NAS_INVALID_LOGIN_RESPONSE');
      }
      return (
        userId: user['Id'] as String,
        credentials: NasCredentials(token: token),
      );
    } finally {
      http.close();
    }
  }

  @override
  Future<void> probe() async {
    final info = await _http.json('GET', _url('System/Info/Public'));
    if (info['Version'] is! String) {
      throw const NasHttpException('NAS_INVALID_SERVER');
    }
    final product = (info['ProductName'] as String? ?? '').toLowerCase();
    if (product.isNotEmpty && !product.contains(_emby ? 'emby' : 'jellyfin')) {
      throw const NasHttpException('NAS_SOURCE_MISMATCH');
    }
    await _http.json('GET', _url('Users/$_user'));
  }

  String get _itemsRoute => _emby ? 'Users/$_user/Items' : 'Items';
  Map<String, String> get _userQuery => {'UserId': source.userId ?? ''};

  Future<List<Map<String, dynamic>>> _libraries(
    NasCancellation cancellation,
  ) async {
    final data = await _http.json(
      'GET',
      _url('Users/$_user/Views', {'IncludeExternalContent': 'false'}),
      cancellation: cancellation,
    );
    final items = data['Items'];
    if (items is! List ||
        items.any(
          (item) =>
              item is! Map ||
              item['Id'] is! String ||
              (item['Id'] as String).isEmpty ||
              item['Name'] is! String,
        )) {
      throw const NasHttpException('NAS_INVALID_LIBRARY_RESPONSE');
    }
    return [for (final item in items) Map<String, dynamic>.from(item as Map)];
  }

  @override
  Stream<List<RemoteBrowserEntry>> browse(
    String path,
    NasCancellation cancellation,
  ) async* {
    cancellation.check();
    if (path != '/') throw const NasHttpException('NAS_INVALID_PATH');
    final libraries = await _libraries(cancellation);
    var page = <RemoteBrowserEntry>[];
    for (final library in libraries) {
      cancellation.check();
      final id = library['Id'] as String;
      _id(id);
      page.add(
        RemoteBrowserEntry(
          id: id,
          name: library['Name'] as String,
          isDirectory: true,
          canEnter: false,
        ),
      );
      if (page.length == _pageSize) {
        yield page;
        page = [];
      }
    }
    if (page.isNotEmpty) yield page;
  }

  Stream<List<Map<String, dynamic>>> _pages(
    String route,
    Map<String, String> query,
    NasCancellation cancellation, {
    int startIndex = 0,
  }) async* {
    if (startIndex < 0) throw RangeError('NAS_INVALID_POSITION');
    var offset = startIndex;
    while (true) {
      cancellation.check();
      final data = await _http.json(
        'GET',
        _url(route, {
          ..._userQuery,
          ...query,
          'StartIndex': '$offset',
          'Limit': '$_pageSize',
        }),
        cancellation: cancellation,
      );
      final raw = data['Items'];
      if (raw is! List || raw.length > _pageSize) {
        throw const NasHttpException('NAS_INVALID_PAGE');
      }
      if (raw.isEmpty) break;
      final items = raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      yield items;
      offset += items.length;
      final total = data['TotalRecordCount'];
      if ((total is num && offset >= total) ||
          (total == null && items.length < _pageSize)) {
        break;
      }
    }
  }

  NasMediaItem? _item(Map<String, dynamic> data) {
    final id = data['Id'];
    if (id is! String || id.isEmpty) return null;
    final kind = switch (data['MediaType'] ?? data['Type']) {
      'Audio' => NasMediaKind.audio,
      'Photo' => NasMediaKind.image,
      'Video' || 'Movie' || 'Episode' || 'MusicVideo' => NasMediaKind.video,
      _ => null,
    };
    if (kind == null) return null;
    final media = (data['MediaSources'] as List?)?.cast<Map>();
    final first = media == null || media.isEmpty
        ? <dynamic, dynamic>{}
        : media.first;
    final userData = data['UserData'] as Map? ?? const {};
    final streams =
        (data['MediaStreams'] as List?) ??
        first['MediaStreams'] as List? ??
        const [];
    final video = streams
        .whereType<Map>()
        .where((s) => s['Type'] == 'Video')
        .firstOrNull;
    final artists = (data['Artists'] as List?)?.whereType<String>().join(', ');
    final date = DateTime.tryParse(data['DateCreated'] as String? ?? '');
    return NasMediaItem(
      serverId: source.id,
      path: id,
      kind: kind,
      sourcePath: data['Path'] as String?,
      title: data['Name'] as String?,
      sizeBytes: (first['Size'] as num?)?.toInt() ?? 0,
      modifiedEpoch: date == null ? 0 : date.millisecondsSinceEpoch ~/ 1000,
      durationMillis: (data['RunTimeTicks'] as num?)?.toInt() == null
          ? null
          : (data['RunTimeTicks'] as num).toInt() ~/ 10000,
      artist: artists,
      album: data['Album'] as String?,
      albumId: data['AlbumId'] as String?,
      albumArtist:
          data['AlbumArtist'] as String? ??
          (data['AlbumArtists'] as List?)
              ?.whereType<Map>()
              .map((entry) => entry['Name'])
              .whereType<String>()
              .join(', '),
      discNumber: (data['ParentIndexNumber'] as num?)?.toInt(),
      trackNumber: (data['IndexNumber'] as num?)?.toInt(),
      width: (video?['Width'] as num?)?.toInt(),
      height: (video?['Height'] as num?)?.toInt(),
      isFavorite: userData['IsFavorite'] == true,
      playlistEntryId: data['PlaylistItemId'] as String?,
    );
  }

  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) async* {
    cancellation.check();
    final includes =
        (config.includePaths.isNotEmpty
                ? config.includePaths
                : [source.rootPath])
            .map((path) => path.isEmpty ? '/' : path)
            .toSet();
    if (config.excludePaths.contains('/')) return;
    final excludedPaths = config.excludePaths.where(_isPhysicalPath).toList();
    final excludedIds = config.excludePaths
        .where((path) => !_isPhysicalPath(path))
        .toSet();
    final excludedLibraries = <String>{};
    final parents = <String, List<String>?>{};
    final individualItems = <NasMediaItem>[];
    final metadata = <String, Map<String, dynamic>>{};
    Future<Map<String, dynamic>> selectionItem(String id) async {
      if (metadata[id] case final existing?) return existing;
      final item = await _http.json(
        'GET',
        _url('Users/$_user/Items/${_id(id)}'),
        cancellation: cancellation,
      );
      if (item['Id'] is! String ||
          (item['IsFolder'] is! bool && _item(item) == null)) {
        throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
      }
      return metadata[id] = item;
    }

    if (includes.length == 1 && includes.contains('/') && excludedIds.isEmpty) {
      // Unfiltered historical scans retain the existing paged request path.
      parents[''] = null;
    } else {
      final libraries = {
        for (final library in await _libraries(cancellation))
          library['Id'] as String: library,
      };
      for (final id in excludedIds) {
        if (libraries.containsKey(id)) {
          excludedLibraries.add(id);
        } else {
          final item = await selectionItem(id);
          if (item['IsFolder'] == true) {
            final path = item['Path'];
            if (path is! String || !_isPhysicalPath(path)) {
              throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
            }
            excludedPaths.add(path);
          }
        }
      }
      final allowed = libraries.keys.where(
        (id) => !excludedLibraries.contains(id),
      );
      for (final include in includes) {
        cancellation.check();
        if (include == '/') {
          for (final id in allowed) {
            parents[id] = null;
          }
        } else if (_isPhysicalPath(include)) {
          for (final id in allowed) {
            if (!parents.containsKey(id)) {
              parents[id] = [include];
            } else {
              parents[id]?.add(include);
            }
          }
        } else if (!excludedIds.contains(include)) {
          if (libraries.containsKey(include)) {
            parents[include] = null;
            continue;
          }
          final item = await selectionItem(include);
          if (excludedLibraries.isNotEmpty) {
            var current = include;
            final visited = <String>{};
            while (!libraries.containsKey(current)) {
              if (!visited.add(current) || visited.length > 128) {
                throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
              }
              final parent = (await selectionItem(current))['ParentId'];
              if (parent is! String || parent.isEmpty) {
                throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
              }
              current = parent;
            }
            if (excludedLibraries.contains(current)) continue;
          }
          if (item['IsFolder'] == true) {
            parents[include] = null;
          } else if (_item(item) case final media?) {
            individualItems.add(media);
          } else {
            throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
          }
        }
      }
    }
    bool selected(NasMediaItem item, List<String>? includedPaths) {
      if (excludedIds.contains(item.path)) return false;
      if (excludedPaths.isEmpty && includedPaths == null) return true;
      final path = item.sourcePath;
      if (path == null || !_isPhysicalPath(path)) {
        throw const NasHttpException('NAS_SCAN_FILTER_UNRESOLVED');
      }
      return !excludedPaths.any((root) => _insidePhysicalPath(path, root)) &&
          (includedPaths == null ||
              includedPaths.any((root) => _insidePhysicalPath(path, root)));
    }

    final selectedIndividuals = individualItems
        .where((item) => selected(item, null))
        .toList();
    if (selectedIndividuals.isNotEmpty) yield selectedIndividuals;
    for (final entry in parents.entries) {
      final parent = entry.key;
      await for (final page in _pages(_itemsRoute, {
        'Recursive': 'true',
        'IncludeItemTypes': 'Movie,Episode,Video,MusicVideo,Audio,Photo',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': _fields,
        'EnableUserData': 'true',
        'ImageTypeLimit': '1',
        if (parent.isNotEmpty) 'ParentId': parent,
      }, cancellation)) {
        final items = page
            .map(_item)
            .whereType<NasMediaItem>()
            .where((item) => selected(item, entry.value))
            .toList();
        if (items.isNotEmpty) yield items;
      }
    }
  }

  static bool _isPhysicalPath(String value) =>
      value.startsWith('/') ||
      value.startsWith(r'\\') ||
      RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(value);

  static bool _insidePhysicalPath(String path, String root) {
    if (root.startsWith(r'\\') || RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(root)) {
      path = path.replaceAll(r'\', '/').toLowerCase();
      root = root.replaceAll(r'\', '/').toLowerCase();
    }
    root = root.replaceFirst(RegExp(r'/+$'), '');
    return path == root || path.startsWith('$root/');
  }

  void _checkSource(NasMediaItem item) {
    if (item.serverId != source.id) {
      throw const NasHttpException('NAS_SOURCE_MISMATCH');
    }
  }

  @override
  Future<NasResource> resolveForDownload(NasMediaItem item) {
    _checkSource(item);
    final id = _id(item.path);
    final uri = switch (item.kind) {
      NasMediaKind.video => _url('Videos/$id/stream', {'Static': 'true'}),
      NasMediaKind.audio => _url('Audio/$id/stream', {'Static': 'true'}),
      NasMediaKind.image => _url('Items/$id/Download'),
    };
    return _http.downloadResource(
      uri,
      mimeType: item.mimeType ?? 'application/octet-stream',
    );
  }

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async {
    _checkSource(item);
    final id = _id(item.path);
    if (quality == NasPlaybackQuality.original ||
        item.kind == NasMediaKind.image) {
      final uri = switch (item.kind) {
        NasMediaKind.video => _url('Videos/$id/stream', {'Static': 'true'}),
        NasMediaKind.audio => _url('Audio/$id/stream', {'Static': 'true'}),
        NasMediaKind.image => _url('Items/$id/Download'),
      };
      return NasResource(
        read: (start, end, cancel) => _http.readRange(uri, start, end, cancel),
        sizeBytes: item.sizeBytes > 0 ? item.sizeBytes : null,
        mimeType: item.mimeType ?? 'application/octet-stream',
        playSessionId: _emby && item.kind != NasMediaKind.image
            ? '$_directSessionPrefix${const Uuid().v4()}'
            : null,
      );
    }
    final bitrate = switch (quality) {
      NasPlaybackQuality.mbps4 => 4000000,
      NasPlaybackQuality.mbps10 => 10000000,
      NasPlaybackQuality.mbps20 => 20000000,
      _ => 120000000,
    };
    final automatic = quality == NasPlaybackQuality.auto;
    final data = await _http.json(
      'POST',
      _url('Items/$id/PlaybackInfo'),
      body: {
        'UserId': source.userId,
        'EnableDirectPlay': automatic,
        'EnableDirectStream': automatic,
        'EnableTranscoding': true,
        'MaxStreamingBitrate': bitrate,
        'StartTimeTicks': 0,
        'DeviceProfile': {
          'Name': 'Valhalla media_kit',
          'MaxStreamingBitrate': bitrate,
          'DirectPlayProfiles': [
            {'Type': 'Video'},
            {'Type': 'Audio'},
          ],
          'TranscodingProfiles': [
            {
              'Type': 'Video',
              'Container': 'ts',
              'VideoCodec': 'h264',
              'AudioCodec': 'aac',
              'Protocol': 'hls',
              'Context': 'Streaming',
              'MaxAudioChannels': '2',
              'MinSegments': 1,
              'SegmentLength': 3,
            },
            {
              'Type': 'Audio',
              'Container': 'aac',
              'AudioCodec': 'aac',
              'Protocol': 'http',
              'Context': 'Streaming',
            },
          ],
        },
      },
    );
    if (data['ErrorCode'] != null) {
      throw const NasHttpException('NAS_PLAYBACK_UNAVAILABLE');
    }
    final mediaSources = data['MediaSources'] as List? ?? const [];
    if (mediaSources.isEmpty) {
      throw const NasHttpException('NAS_PLAYBACK_UNAVAILABLE');
    }
    final media = mediaSources.first as Map;
    if (automatic && media['SupportsDirectPlay'] == true) return resolve(item);
    final url = media['TranscodingUrl'];
    if (url is! String || url.isEmpty) {
      throw const NasHttpException('NAS_TRANSCODING_UNAVAILABLE');
    }
    var uri = _base.resolve(url);
    if (!nasSameOrigin(_base, uri) || uri.userInfo.isNotEmpty) {
      throw const NasHttpException('NAS_CROSS_ORIGIN');
    }
    // Auth belongs in headers, never in persisted player or download URLs.
    uri = uri.replace(
      queryParameters: {...uri.queryParameters}
        ..removeWhere(
          (key, _) => {'api_key', 'access_token'}.contains(key.toLowerCase()),
        ),
    );
    return NasResource(
      uri: uri,
      headers: _headers,
      mimeType: item.kind == NasMediaKind.video
          ? 'application/vnd.apple.mpegurl'
          : 'audio/aac',
      playSessionId: data['PlaySessionId'] as String?,
      seekable: true,
    );
  }

  @override
  Future<NasResource?> thumbnail(NasMediaItem item) async {
    _checkSource(item);
    final uri = _url('Items/${_id(item.path)}/Images/Primary', {
      'MaxWidth': '512',
      'MaxHeight': '512',
      'Quality': '85',
    });
    return NasResource(
      read: (start, end, cancel) => _http.readRange(uri, start, end, cancel),
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> setFavorite(NasMediaItem item, bool value) async {
    _checkSource(item);
    await _http.json(
      value ? 'POST' : 'DELETE',
      _url('Users/$_user/FavoriteItems/${_id(item.path)}'),
    );
  }

  @override
  Future<List<NasPlaylist>> playlists() async {
    final result = <NasPlaylist>[];
    await for (final page in _pages(_itemsRoute, {
      'IncludeItemTypes': 'Playlist',
      'Recursive': 'true',
      'Fields': 'DateCreated,ChildCount',
      'SortBy': 'SortName',
    }, NasCancellation())) {
      for (final data in page) {
        if (data['Id'] is! String) continue;
        result.add(
          NasPlaylist(
            id: data['Id'] as String,
            serverId: source.id,
            name: data['Name'] as String? ?? '',
            createdAt:
                DateTime.tryParse(data['DateCreated'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            itemCount: (data['ChildCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return result;
  }

  @override
  Stream<List<NasMediaItem>> playlistItems(
    String id,
    NasCancellation cancellation, {
    int startIndex = 0,
  }) async* {
    await for (final page in _pages(
      'Playlists/${_id(id)}/Items',
      {'Fields': _fields, 'EnableUserData': 'true'},
      cancellation,
      startIndex: startIndex,
    )) {
      final items = page.map(_item).whereType<NasMediaItem>().toList();
      if (items.isNotEmpty) yield items;
    }
  }

  static String _name(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 255 || name.contains('\u0000')) {
      throw ArgumentError('NAS_INVALID_PLAYLIST_NAME');
    }
    return name;
  }

  @override
  Future<String> createPlaylist(String name) async {
    final data = _emby
        ? await _http.json(
            'POST',
            _url('Playlists', {
              ..._userQuery,
              'Name': _name(name),
              'MediaType': 'Audio',
            }),
          )
        : await _http.json(
            'POST',
            _url('Playlists'),
            body: {
              'Name': _name(name),
              'UserId': source.userId,
              'MediaType': 'Audio',
              'IsPublic': false,
            },
          );
    if (data['Id'] is! String) {
      throw const NasHttpException('NAS_INVALID_RESPONSE');
    }
    return data['Id'] as String;
  }

  @override
  Future<void> renamePlaylist(String id, String name) async {
    if (_emby) {
      // Emby uses its metadata update API. Read the current record immediately;
      // never replay a cached playlist or send a replacement item list.
      final data = await _http.json(
        'GET',
        _url('Users/$_user/Items/${_id(id)}'),
      );
      if (data['Type'] != 'Playlist') {
        throw const NasHttpException('NAS_SOURCE_MISMATCH');
      }
      data['Name'] = _name(name);
      await _http.json('POST', _url('Items/${_id(id)}'), body: data);
    } else {
      await _http.json(
        'POST',
        _url('Playlists/${_id(id)}'),
        body: {'Name': _name(name)},
      );
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final data = await _http.json('GET', _url('Users/$_user/Items/${_id(id)}'));
    if (data['Type'] != 'Playlist') {
      throw const NasHttpException('NAS_SOURCE_MISMATCH');
    }
    await _http.json('DELETE', _url('Items/${_id(id)}'));
  }

  @override
  Future<void> addToPlaylist(String id, NasMediaItem item) async {
    _checkSource(item);
    await _http.json(
      'POST',
      _url('Playlists/${_id(id)}/Items', {..._userQuery, 'Ids': item.path}),
    );
  }

  @override
  Future<void> removeFromPlaylist(String id, String entryId) async {
    _id(entryId);
    await _requireUniqueEntry(id, entryId);
    await _http.json(
      'DELETE',
      _url('Playlists/${_id(id)}/Items', {'EntryIds': entryId}),
    );
  }

  @override
  Future<void> movePlaylistItem(String id, String entryId, int index) async {
    if (index < 0) throw RangeError('NAS_INVALID_POSITION');
    await _requireUniqueEntry(id, entryId);
    await _http.json(
      'POST',
      _url('Playlists/${_id(id)}/Items/${_id(entryId)}/Move/$index'),
    );
  }

  Future<void> _requireUniqueEntry(String id, String entryId) async {
    // Jellyfin 12.1 returns the media ID as PlaylistItemId, including duplicates.
    // Its remove/move routes then target every matching entry. Refuse ambiguity
    // instead of replacing a playlist snapshot and losing another client's edits.
    var matches = 0;
    await for (final page in playlistItems(id, NasCancellation())) {
      for (final item in page) {
        if (item.playlistEntryId == entryId && ++matches > 1) {
          throw const NasHttpException('NAS_PLAYLIST_AMBIGUOUS_ENTRY');
        }
      }
    }
    if (matches == 0) {
      throw const NasHttpException('NAS_PLAYLIST_ENTRY_NOT_FOUND');
    }
  }

  @override
  Future<Duration?> resumePosition(NasMediaItem item) async {
    _checkSource(item);
    final data = await _http.json(
      'GET',
      _url('Users/$_user/Items/${_id(item.path)}'),
    );
    final ticks = (data['UserData'] as Map?)?['PlaybackPositionTicks'] as num?;
    return ticks == null ? null : Duration(microseconds: ticks.toInt() ~/ 10);
  }

  @override
  Future<void> reportPlayback(
    NasMediaItem item,
    Duration position, {
    required String event,
    bool paused = false,
    String? playSessionId,
  }) async {
    _checkSource(item);
    final route = switch (event) {
      'start' => 'Sessions/Playing',
      'progress' => 'Sessions/Playing/Progress',
      'stop' => 'Sessions/Playing/Stopped',
      _ => throw ArgumentError('NAS_INVALID_PLAYBACK_EVENT'),
    };
    // Emby requires a session even for original files. Resource sessions keep
    // simultaneous local/cast playback separate; callers without a resource
    // retain a stable fallback scoped to this adapter and item.
    final session =
        playSessionId ??
        (_emby
            ? '$_directSessionPrefix$_directSessionSeed-${_id(item.path)}'
            : null);
    final transcoding =
        session != null && !session.startsWith(_directSessionPrefix);
    await _http.json(
      'POST',
      _url(route),
      body: {
        'ItemId': item.path,
        'PositionTicks': position.inMicroseconds * 10,
        'IsPaused': paused,
        'CanSeek': true,
        'PlayMethod': transcoding ? 'Transcode' : 'DirectPlay',
        'PlaySessionId': ?session,
      },
    );
  }

  @override
  Future<void> dispose() async => _http.close();
}
