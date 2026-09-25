import 'package:dartssh2/dartssh2.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../ssh/ssh_client_manager.dart';
import 'nas_scan_service.dart';

class NasSftpAdapter extends NasSourceAdapter {
  @override
  final NasSource source;
  final SshCommandExecutor ssh;
  NasSftpAdapter(this.source, this.ssh);

  SSHClient _client() {
    final client = ssh.getClient(source.sshServerId ?? source.id);
    if (client == null || client.isClosed) {
      throw StateError('NAS_SOURCE_DISCONNECTED');
    }
    return client;
  }

  @override
  Future<void> probe() async {
    final sftp = await _client().sftp();
    try {
      await sftp.stat(source.rootPath);
    } finally {
      await sftp.close();
    }
  }

  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) async* {
    final effective = config.includePaths.isEmpty
        ? NasScanConfig(
            includePaths: [source.rootPath],
            excludePaths: config.excludePaths,
          )
        : config;
    await for (final batch in NasScanService(
      ssh,
    ).scanBatches(source.sshServerId ?? source.id, effective, cancellation)) {
      yield [
        for (final item in batch)
          NasMediaItem(
            serverId: source.id,
            path: item.path,
            kind: item.kind,
            sizeBytes: item.sizeBytes,
            modifiedEpoch: item.modifiedEpoch,
            mimeType: item.mimeType,
          ),
      ];
    }
  }

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async {
    if (item.serverId != source.id) throw ArgumentError('NAS_SOURCE_MISMATCH');
    final client = _client();
    final sftp = await client.sftp();
    final int size;
    try {
      size = (await sftp.stat(item.path)).size ?? item.sizeBytes;
    } finally {
      await sftp.close();
    }
    return NasResource(
      sizeBytes: size,
      mimeType: item.mimeType ?? nasMimeType(item),
      read: (start, end, cancellation) async* {
        cancellation.check();
        final subsystem = await client.sftp();
        final unregister = cancellation.onCancel(() {
          subsystem.close();
        });
        try {
          final file = await subsystem.open(
            item.path,
            mode: SftpFileOpenMode.read,
          );
          try {
            yield* file.read(
              offset: start,
              length: (end ?? size) - start,
              chunkSize: 256 * 1024,
              maxPendingRequests: 8,
            );
          } finally {
            if (!cancellation.isCancelled) await file.close();
          }
        } finally {
          unregister();
          await subsystem.close();
        }
      },
    );
  }
}

String nasMimeType(NasMediaItem item) {
  const types = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'avif': 'image/avif',
    'bmp': 'image/bmp',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mkv': 'video/x-matroska',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
    'ts': 'video/mp2t',
    'mp3': 'audio/mpeg',
    'flac': 'audio/flac',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'opus': 'audio/opus',
  };
  return types[item.name.split('.').last.toLowerCase()] ??
      switch (item.kind) {
        NasMediaKind.image => 'image/jpeg',
        NasMediaKind.video => 'video/mp4',
        NasMediaKind.audio => 'audio/mpeg',
      };
}
