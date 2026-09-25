import 'dart:async';

import 'nas_media.dart';

enum NasSourceType { sftp, webdav, smb, jellyfin, emby }

enum NasPlaybackQuality { original, auto, mbps4, mbps10, mbps20 }

class NasSource {
  final String id;
  final String name;
  final NasSourceType type;
  final String endpoint;
  final String? sshServerId;
  final String username;
  final String? userId;
  final String rootPath;

  /// Ephemeral HTTP Host header for a loopback SSH tunnel, never persisted.
  final String? forwardedHost;

  const NasSource({
    required this.id,
    required this.name,
    required this.type,
    this.endpoint = '',
    this.sshServerId,
    this.username = '',
    this.userId,
    this.rootPath = '/',
    this.forwardedHost,
  });

  bool get isMediaServer =>
      type == NasSourceType.jellyfin || type == NasSourceType.emby;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'endpoint': endpoint,
    'sshServerId': sshServerId,
    'username': username,
    'userId': userId,
    'rootPath': rootPath,
  };

  factory NasSource.fromJson(Map<String, dynamic> json) => NasSource(
    id: json['id'] as String,
    name: json['name'] as String,
    type: NasSourceType.values.byName(json['type'] as String),
    endpoint: json['endpoint'] as String? ?? '',
    sshServerId: json['sshServerId'] as String?,
    username: json['username'] as String? ?? '',
    userId: json['userId'] as String?,
    rootPath: json['rootPath'] as String? ?? '/',
  );
}

/// Secrets are stored separately from source metadata and never put in URLs.
class NasCredentials {
  final String password;
  final String token;
  final String domain;
  const NasCredentials({this.password = '', this.token = '', this.domain = ''});
  Map<String, dynamic> toJson() => {
    'password': password,
    'token': token,
    'domain': domain,
  };
  factory NasCredentials.fromJson(Map<String, dynamic> json) => NasCredentials(
    password: json['password'] as String? ?? '',
    token: json['token'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
  );
}

class NasCancelled implements Exception {
  const NasCancelled();
  @override
  String toString() => 'NAS_CANCELLED';
}

class NasCancellation {
  final _done = Completer<void>();
  final Set<void Function()> _listeners = {};
  bool get isCancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (isCancelled) return;
    _done.complete();
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void Function() onCancel(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void check() {
    if (isCancelled) throw const NasCancelled();
  }
}

/// [end] is exclusive. Readers must stop and release handles on cancellation.
typedef NasByteReader =
    Stream<List<int>> Function(
      int start,
      int? end,
      NasCancellation cancellation,
    );

class NasResource {
  final Uri? uri;
  final Map<String, String> headers;
  final NasByteReader? read;
  final int? sizeBytes;
  final String mimeType;
  final String? playSessionId;
  final bool seekable;
  const NasResource({
    this.uri,
    this.headers = const {},
    this.read,
    this.sizeBytes,
    this.mimeType = 'application/octet-stream',
    this.playSessionId,
    this.seekable = true,
  }) : assert(uri != null || read != null);
}

/// Every implementation captures its source; global SSH selection is irrelevant.
abstract class NasSourceAdapter {
  NasSource get source;
  Future<void> probe();
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  );
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  });
  Future<NasResource?> thumbnail(NasMediaItem item) async => null;
  Future<void> setFavorite(NasMediaItem item, bool value) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<List<NasPlaylist>> playlists() async => const [];
  Stream<List<NasMediaItem>> playlistItems(
    String id,
    NasCancellation cancellation, {
    int startIndex = 0,
  }) => const Stream.empty();
  Future<String> createPlaylist(String name) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<void> renamePlaylist(String id, String name) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<void> deletePlaylist(String id) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<void> addToPlaylist(String id, NasMediaItem item) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<void> removeFromPlaylist(String id, String entryId) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<void> movePlaylistItem(String id, String entryId, int index) async =>
      throw UnsupportedError('NAS_LOCAL_STATE');
  Future<Duration?> resumePosition(NasMediaItem item) async => null;
  Future<void> reportPlayback(
    NasMediaItem item,
    Duration position, {
    required String event,
    bool paused = false,
    String? playSessionId,
  }) async {}
  Future<void> dispose() async {}
}
