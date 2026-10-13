import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as paths;

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/models/remote_browser.dart';
import '../sftp/sftp_client_service.dart' show SftpFileItem;
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
  Stream<List<RemoteBrowserEntry>> browse(
    String path,
    NasCancellation cancellation,
  ) async* {
    cancellation.check();
    if (!path.startsWith('/') || path.contains('\x00')) {
      throw ArgumentError('NAS_INVALID_PATH');
    }
    final directory = paths.posix.normalize(path);
    final sftp = await _client().sftp();
    final unregister = cancellation.onCancel(() {
      unawaited(sftp.close().catchError((Object _) {}));
    });
    try {
      await for (final names in sftp.readdir(directory)) {
        final entries = <RemoteBrowserEntry>[];
        for (final entry in names) {
          cancellation.check();
          final name = entry.filename;
          if (name == '.' || name == '..') continue;
          if (name.isEmpty || name.contains('/') || name.contains('\x00')) {
            throw StateError('NAS_INVALID_DIRECTORY_ENTRY');
          }
          final id = paths.posix.join(directory, name);
          var attributes = entry.attr;
          String? linkError;
          if (entry.attr.isSymbolicLink) {
            try {
              attributes = await sftp.stat(id);
              if (attributes.isSymbolicLink ||
                  attributes.mode == null ||
                  attributes.type == SftpFileType.unknown) {
                linkError = SftpFileItem.linkTargetUnavailableCode;
              }
            } on SftpStatusError catch (error) {
              if (error.code != SftpStatusCode.noSuchFile &&
                  error.code != SftpStatusCode.permissionDenied) {
                rethrow;
              }
              linkError = error.code == SftpStatusCode.permissionDenied
                  ? SftpFileItem.linkTargetPermissionDeniedCode
                  : SftpFileItem.linkTargetUnavailableCode;
            }
          }
          entries.add(
            RemoteBrowserEntry(
              id: id,
              name: name,
              isDirectory: linkError == null && attributes.isDirectory,
              sizeBytes: attributes.size,
              modifiedEpoch: attributes.modifyTime,
              isSymbolicLink: entry.attr.isSymbolicLink,
              linkTargetErrorCode: linkError,
            ),
          );
        }
        cancellation.check();
        if (entries.isNotEmpty) yield entries;
      }
    } catch (_) {
      cancellation.check();
      rethrow;
    } finally {
      unregister();
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
    final int? size;
    final int? modified;
    try {
      final attrs = await sftp.stat(item.path);
      size = attrs.size;
      modified = attrs.modifyTime;
    } finally {
      await sftp.close();
    }
    return NasResource(
      sizeBytes: size,
      version: size == null || modified == null ? null : 'sftp:$size:$modified',
      mimeType: item.mimeType ?? nasMimeType(item),
      read: (start, end, cancellation) async* {
        cancellation.check();
        final subsystem = await client.sftp();
        final unregister = cancellation.onCancel(() {
          unawaited(subsystem.close().catchError((Object _) {}));
        });
        try {
          final file = await subsystem.open(
            item.path,
            mode: SftpFileOpenMode.read,
          );
          try {
            final attrs = await file.stat();
            if ((size != null && attrs.size != size) ||
                (modified != null && attrs.modifyTime != modified)) {
              throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
            }
            final limit = end ?? size;
            if (limit == null) {
              // dartssh2's null length requires stat.size; use bounded reads
              // until EOF when the server does not provide that metadata.
              var offset = start;
              const chunkSize = 256 * 1024;
              while (true) {
                cancellation.check();
                var count = 0;
                await for (final chunk in file.read(
                  offset: offset,
                  length: chunkSize,
                  chunkSize: chunkSize,
                  maxPendingRequests: 1,
                )) {
                  cancellation.check();
                  count += chunk.length;
                  yield chunk;
                }
                offset += count;
                if (count < chunkSize) break;
              }
              return;
            }
            yield* file.read(
              offset: start,
              length: limit - start,
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
