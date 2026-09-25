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
    this.trackNumber,
    this.isFavorite = false,
    this.playlistEntryId,
    this.sourcePath,
  });

  String get sourceId => serverId;
  String get itemId => path;
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
    trackNumber: trackNumber ?? this.trackNumber,
    isFavorite: isFavorite ?? this.isFavorite,
    playlistEntryId: playlistEntryId ?? this.playlistEntryId,
    sourcePath: sourcePath ?? this.sourcePath,
  );
}
