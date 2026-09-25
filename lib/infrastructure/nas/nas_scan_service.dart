import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;

import '../../core/utils/shell_quote.dart';
import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../ssh/ssh_client_manager.dart';

class NasScanService {
  final SshCommandExecutor executor;
  const NasScanService(this.executor);

  NasScanConfig normalize(NasScanConfig config) {
    String clean(String value) {
      if (!value.startsWith('/') ||
          value.contains('\u0000') ||
          value.contains('\n')) {
        throw ArgumentError.value(value, 'path', 'Absolute path required');
      }
      return path.posix.normalize(value);
    }

    final includes = config.includePaths.map(clean).toSet().toList()..sort();
    final collapsed = <String>[];
    for (final candidate in includes) {
      if (!collapsed.any(
        (root) => candidate == root || path.posix.isWithin(root, candidate),
      )) {
        collapsed.add(candidate);
      }
    }
    final excludes =
        config.excludePaths
            .map(clean)
            .where(
              (candidate) => collapsed.any(
                (root) =>
                    candidate == root || path.posix.isWithin(root, candidate),
              ),
            )
            .toSet()
            .toList()
          ..sort();
    return NasScanConfig(includePaths: collapsed, excludePaths: excludes);
  }

  String _findPrefix(NasScanConfig raw) {
    final config = normalize(raw);
    if (config.includePaths.isEmpty) {
      throw StateError('NAS_SCAN_PATH_REQUIRED');
    }
    final extensions = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
      'avif',
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      'm4v',
      'ts',
      'flv',
      'mp3',
      'flac',
      'wav',
      'm4a',
      'aac',
      'ogg',
      'opus',
      'wma',
    ];
    final prune = config.excludePaths.isEmpty
        ? ''
        : '\\( ${config.excludePaths.map((entry) {
            final quoted = cliShellQuote(entry);
            final descendants = cliShellQuote(entry == '/' ? '/*' : '$entry/*');
            return "-path $quoted -o -path $descendants";
          }).join(' -o ')} \\) -prune -o ';
    final types =
        '\\( ${extensions.map((ext) => "-iname ${cliShellQuote('*.$ext')}").join(' -o ')} \\)';
    return 'find -P ${config.includePaths.map(cliShellQuote).join(' ')} '
        '$prune-type f $types';
  }

  /// Kept for older callers; indexing uses [scanBatches] to bound memory.
  Future<List<NasMediaItem>> scan(String serverId, NasScanConfig raw) async {
    final findPrefix = _findPrefix(raw);
    final command = '$findPrefix -printf ${cliShellQuote('%p\\0%s\\0%T@\\0')}';
    var result = await executor.executeWithLoginShell(
      serverId,
      command,
      timeout: const Duration(minutes: 30),
    );
    if (!result.isSuccess && _unsupportedPrintf(result.stderr)) {
      result = await executor.executeWithLoginShell(
        serverId,
        _portableFind(findPrefix),
        timeout: const Duration(minutes: 30),
      );
    }
    if (!result.isSuccess) {
      throw StateError(
        '${_unsupportedPrintf(result.stderr) ? 'NAS_SCAN_UNSUPPORTED_FIND_FORMAT' : 'NAS_SCAN_FAILED'}:${result.stderr.trim()}',
      );
    }
    final items = <NasMediaItem>[];
    await for (final batch in decodeRecords(
      serverId,
      Stream.value(utf8.encode(result.stdout)),
      NasCancellation(),
    )) {
      items.addAll(batch);
    }
    return items;
  }

  Stream<List<NasMediaItem>> scanBatches(
    String serverId,
    NasScanConfig raw,
    NasCancellation cancellation, {
    int batchSize = 256,
  }) async* {
    cancellation.check();
    final prefix = _findPrefix(raw);
    final client = executor.getClient(serverId);
    if (client == null || client.isClosed) {
      throw StateError('NAS_SSH_NOT_CONNECTED');
    }
    // Probe before emitting any rows, so format fallback cannot duplicate rows.
    final command =
        "if find / -maxdepth 0 -printf '' >/dev/null 2>&1; then "
        '$prefix -printf ${cliShellQuote('%p\\0%s\\0%T@\\0')}; else ${_portableFind(prefix)}; fi';
    final session = await client.execute(command);
    final unregister = cancellation.onCancel(session.close);
    final errors = StringBuffer();
    final stderr = session.stderr
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          (text) {
            if (errors.length < 8192) {
              errors.write(
                text.substring(0, (8192 - errors.length).clamp(0, text.length)),
              );
            }
          },
          onError: (Object error) {
            if (errors.length < 8192) errors.write(error.runtimeType);
          },
        );
    try {
      cancellation.check();
      yield* decodeRecords(
        serverId,
        session.stdout,
        cancellation,
        batchSize: batchSize,
      );
      await session.done;
      cancellation.check();
      if (session.exitCode != 0) {
        throw StateError('NAS_SCAN_FAILED:${errors.toString().trim()}');
      }
    } finally {
      unregister();
      session.close();
      await stderr.cancel();
    }
  }

  /// UTF-8 decoding keeps multibyte filenames intact across SSH packets.
  static Stream<List<NasMediaItem>> decodeRecords(
    String serverId,
    Stream<List<int>> bytes,
    NasCancellation cancellation, {
    int batchSize = 256,
  }) async* {
    if (batchSize < 1 || batchSize > 10000) {
      throw ArgumentError.value(batchSize, 'batchSize');
    }
    var pending = '';
    final fields = <String>[];
    var batch = <NasMediaItem>[];
    await for (final text in bytes.cast<List<int>>().transform(utf8.decoder)) {
      cancellation.check();
      pending += text;
      var start = 0;
      while (true) {
        final end = pending.indexOf('\u0000', start);
        if (end < 0) break;
        fields.add(pending.substring(start, end));
        start = end + 1;
        if (fields.length != 3) continue;
        final size = int.tryParse(fields[1]);
        final modified = double.tryParse(fields[2]);
        if (!fields[0].startsWith('/') ||
            size == null ||
            size < 0 ||
            modified == null ||
            !modified.isFinite) {
          throw const FormatException('NAS_SCAN_INVALID_RECORD');
        }
        final kind = NasMediaKind.fromPath(fields[0]);
        if (kind != null) {
          batch.add(
            NasMediaItem(
              serverId: serverId,
              path: fields[0],
              kind: kind,
              sizeBytes: size,
              modifiedEpoch: modified.floor(),
            ),
          );
          if (batch.length == batchSize) {
            yield batch;
            cancellation.check();
            batch = <NasMediaItem>[];
          }
        }
        fields.clear();
      }
      pending = pending.substring(start);
      if (pending.length > 1024 * 1024) {
        throw const FormatException('NAS_SCAN_INVALID_RECORD');
      }
    }
    cancellation.check();
    if (pending.isNotEmpty || fields.isNotEmpty) {
      throw const FormatException('NAS_SCAN_TRUNCATED');
    }
    if (batch.isNotEmpty) yield batch;
  }

  static String _portableFind(String prefix) {
    // stat formats do not portably decode \\0. Shell printf supplies real NUL
    // bytes, and only numeric metadata goes through word splitting.
    const script =
        r'''for file do metadata=$(stat -c '%s %Y' "$file" 2>/dev/null || stat -f '%z %m' "$file") || exit 1; set -- $metadata; [ "$#" -eq 2 ] || exit 1; printf '%s\0%s\0%s\0' "$file" "$1" "$2"; done''';
    return '$prefix -exec sh -c ${cliShellQuote(script)} sh {} +';
  }

  static bool _unsupportedPrintf(String stderr) {
    final value = stderr.toLowerCase();
    return value.contains('printf') &&
        (value.contains('unknown') ||
            value.contains('illegal') ||
            value.contains('unrecognized') ||
            value.contains('primary'));
  }
}
