enum NasMediaKind {
  image,
  video,
  audio;

  static NasMediaKind? fromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final extension = path.substring(dot + 1).toLowerCase();
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
      'avif',
    }.contains(extension)) {
      return image;
    }
    if (const {
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      'm4v',
      'ts',
      'flv',
    }.contains(extension)) {
      return video;
    }
    if (const {
      'mp3',
      'flac',
      'wav',
      'm4a',
      'aac',
      'ogg',
      'opus',
      'wma',
    }.contains(extension)) {
      return audio;
    }
    return null;
  }
}

enum NasLibrarySection {
  home,
  images,
  videos,
  music,
  folders,
  favorites,
  playlists,
}

enum NasOpenPolicy { inApp, external, askEveryTime }

enum NasSortKey { modified, name, size }

enum NasScanStage { idle, connecting, scanning, finalizing, completed, cancelled, failed }

enum NasBatchOperation {
  favorite,
  unfavorite,
  addToPlaylist,
  removeFromPlaylist,
}

class NasBatchItemResult {
  final NasMediaItem item;
  final String? errorCode;
  const NasBatchItemResult(this.item, {this.errorCode});
  bool get succeeded => errorCode == null;
}

class NasBatchResult {
  final String sourceId;
  final NasBatchOperation operation;
  final String? playlistId;
  final List<NasBatchItemResult> results;
  const NasBatchResult({
    required this.sourceId,
    required this.operation,
    this.playlistId,
    required this.results,
  });
  int get successCount => results.where((result) => result.succeeded).length;
  List<NasMediaItem> get failedItems => [
    for (final result in results)
      if (!result.succeeded) result.item,
  ];
}

class NasPlaybackState {
  final String serverId;
  final String path;
  final Duration position;
  final Duration? duration;
  final DateTime updatedAt;

  const NasPlaybackState({
    required this.serverId,
    required this.path,
    required this.position,
    this.duration,
    required this.updatedAt,
  });
}

class NasPlaylist {
  final String id;
  final String serverId;
  final String name;
  final DateTime createdAt;
  final int itemCount;

  const NasPlaylist({
    required this.id,
    required this.serverId,
    required this.name,
    required this.createdAt,
    this.itemCount = 0,
  });
}

class NasScanConfig {
  final List<String> includePaths;
  final List<String> excludePaths;

  const NasScanConfig({
    this.includePaths = const [],
    this.excludePaths = const [],
  });

  Map<String, dynamic> toJson() => {
    'includePaths': includePaths,
    'excludePaths': excludePaths,
  };

  factory NasScanConfig.fromJson(Map<String, dynamic> json) => NasScanConfig(
    includePaths: (json['includePaths'] as List? ?? const []).cast<String>(),
    excludePaths: (json['excludePaths'] as List? ?? const []).cast<String>(),
  );
}

class NasMediaItem {
  final String serverId;
  final String path;
  final NasMediaKind kind;
  final int sizeBytes;
  final int modifiedEpoch;
  final String? mimeType;
  final int? durationMillis;
  final int? width;
  final int? height;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumId;
  final String? albumArtist;
  final int? discNumber;
  final int? trackNumber;
  final bool isFavorite;

  /// Server playlist membership identity, distinct from the media item id.
  final String? playlistEntryId;
  final String? sourcePath;

  const NasMediaItem({
    required this.serverId,
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.modifiedEpoch,
    this.mimeType,
    this.durationMillis,
    this.width,
    this.height,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.albumArtist,
    this.discNumber,
    this.trackNumber,
    this.isFavorite = false,
    this.playlistEntryId,
    this.sourcePath,
  });

  String get sourceId => serverId;

  Map<String, dynamic> toJson() => {
    'serverId': serverId,
    'path': path,
    'kind': kind.name,
    'sizeBytes': sizeBytes,
    'modifiedEpoch': modifiedEpoch,
    'mimeType': mimeType,
    'durationMillis': durationMillis,
    'width': width,
    'height': height,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'albumArtist': albumArtist,
    'discNumber': discNumber,
    'trackNumber': trackNumber,
    'isFavorite': isFavorite,
    'sourcePath': sourcePath,
  };

  factory NasMediaItem.fromJson(Map<String, dynamic> json) => NasMediaItem(
    serverId: json['serverId'] as String,
    path: json['path'] as String,
    kind: NasMediaKind.values.byName(json['kind'] as String),
    sizeBytes: json['sizeBytes'] as int,
    modifiedEpoch: json['modifiedEpoch'] as int,
    mimeType: json['mimeType'] as String?,
    durationMillis: json['durationMillis'] as int?,
    width: json['width'] as int?,
    height: json['height'] as int?,
    title: json['title'] as String?,
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    albumId: json['albumId'] as String?,
    albumArtist: json['albumArtist'] as String?,
    discNumber: json['discNumber'] as int?,
    trackNumber: json['trackNumber'] as int?,
    isFavorite: json['isFavorite'] == true,
    sourcePath: json['sourcePath'] as String?,
  );
  String get itemId => path;

  /// Stable within this source, never a display label or a cross-source id.
  String get albumKey {
    if (albumId?.trim().isNotEmpty == true) {
      return 'id:${Uri.encodeComponent(albumId!.trim())}';
    }
    final title = album?.trim() ?? '';
    final author = (albumArtist?.trim().isNotEmpty == true ? albumArtist : artist)?.trim() ?? '';
    if (title.isEmpty || author.isEmpty) {
      return 'folder:${Uri.encodeComponent(folder)}';
    }
    return 'tags:${Uri.encodeComponent(author)}:${Uri.encodeComponent(title)}';
  }
  String get name {
    final value = sourcePath ?? path;
    return value.substring(value.lastIndexOf('/') + 1);
  }

  String get folder => (sourcePath ?? path).lastIndexOf('/') <= 0
      ? '/'
      : (sourcePath ?? path).substring(
          0,
          (sourcePath ?? path).lastIndexOf('/'),
        );

  Duration? get duration =>
      durationMillis == null ? null : Duration(milliseconds: durationMillis!);

  NasMediaItem copyWith({
    String? mimeType,
    int? durationMillis,
    int? width,
    int? height,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    String? albumArtist,
    int? discNumber,
    int? trackNumber,
    bool? isFavorite,
    String? playlistEntryId,
    String? sourcePath,
  }) => NasMediaItem(
    serverId: serverId,
    path: path,
    kind: kind,
    sizeBytes: sizeBytes,
    modifiedEpoch: modifiedEpoch,
    mimeType: mimeType ?? this.mimeType,
    durationMillis: durationMillis ?? this.durationMillis,
    width: width ?? this.width,
    height: height ?? this.height,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumId: albumId ?? this.albumId,
    albumArtist: albumArtist ?? this.albumArtist,
    discNumber: discNumber ?? this.discNumber,
    trackNumber: trackNumber ?? this.trackNumber,
    isFavorite: isFavorite ?? this.isFavorite,
    playlistEntryId: playlistEntryId ?? this.playlistEntryId,
    sourcePath: sourcePath ?? this.sourcePath,
  );
}
