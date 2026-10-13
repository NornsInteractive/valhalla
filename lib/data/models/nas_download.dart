import 'nas_media.dart';

enum NasDownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  cancelled,
  failed,
}

class NasDownloadTask {
  final String id;
  final NasMediaItem item;
  final NasDownloadStatus status;
  final int received;
  final int? total;
  final String? localPath, error, sourceIdentity, resourceVersion, sha256;
  const NasDownloadTask({
    required this.id,
    required this.item,
    this.status = NasDownloadStatus.queued,
    this.received = 0,
    this.total,
    this.localPath,
    this.error,
    this.sourceIdentity,
    this.resourceVersion,
    this.sha256,
  });

  NasDownloadTask copyWith({
    NasDownloadStatus? status,
    int? received,
    int? total,
    String? localPath,
    String? error,
    bool clearError = false,
    String? sourceIdentity,
    String? resourceVersion,
    String? sha256,
  }) => NasDownloadTask(
    id: id,
    item: item,
    status: status ?? this.status,
    received: received ?? this.received,
    total: total ?? this.total,
    localPath: localPath ?? this.localPath,
    error: clearError ? null : error ?? this.error,
    sourceIdentity: sourceIdentity ?? this.sourceIdentity,
    resourceVersion: resourceVersion ?? this.resourceVersion,
    sha256: sha256 ?? this.sha256,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item': item.toJson(),
    'status': status.name,
    'received': received,
    'total': total,
    'localPath': localPath,
    'error': error,
    'sourceIdentity': sourceIdentity,
    'resourceVersion': resourceVersion,
    'sha256': sha256,
  };

  factory NasDownloadTask.fromJson(Map<String, dynamic> json) =>
      NasDownloadTask(
        id: json['id'] as String,
        item: NasMediaItem.fromJson(
          Map<String, dynamic>.from(json['item'] as Map),
        ),
        status: NasDownloadStatus.values.byName(json['status'] as String),
        received: json['received'] as int? ?? 0,
        total: json['total'] as int?,
        localPath: json['localPath'] as String?,
        error: json['error'] as String?,
        sourceIdentity: json['sourceIdentity'] as String?,
        resourceVersion: json['resourceVersion'] as String?,
        sha256: json['sha256'] as String?,
      );
}
