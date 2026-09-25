import 'package:valhalla_smb/valhalla_smb.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import 'nas_sftp_adapter.dart' show nasMimeType;

class NasSmbAdapter extends NasSourceAdapter {
  @override
  final NasSource source;
  final SmbClient _client;
  final String _basePath;
  final Set<NasCancellation> _operations = {};
  bool _disposed = false;

  NasSmbAdapter({required this.source, required NasCredentials credentials})
    : _client = SmbClient(_connection(source, credentials)),
      _basePath = _base(source);

  static Uri _endpoint(NasSource source) {
    final uri = Uri.parse(source.endpoint);
    if (uri.scheme != 'smb' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.pathSegments.where((value) => value.isNotEmpty).isEmpty) {
      throw const FormatException('NAS_INVALID_SMB_ENDPOINT');
    }
    return uri;
  }

  static SmbConnection _connection(
    NasSource source,
    NasCredentials credentials,
  ) {
    final uri = _endpoint(source);
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return SmbConnection(
      host: uri.hasPort ? '$host:${uri.port}' : host,
      share: uri.pathSegments.firstWhere((value) => value.isNotEmpty),
      username: source.username,
      password: credentials.password,
      domain: credentials.domain,
    );
  }

  static String _base(NasSource source) => SmbClient.normalizePath(
    _endpoint(
      source,
    ).pathSegments.where((value) => value.isNotEmpty).skip(1).join('/'),
  );

  String _path(String relative) =>
      SmbClient.normalizePath('$_basePath/$relative');
  void _check() {
    if (_disposed) throw const NasCancelled();
  }

  @override
  Future<void> probe() async {
    _check();
    final cancellation = NasCancellation();
    _operations.add(cancellation);
    try {
      await _client.probe(cancelled: cancellation.whenCancelled);
    } finally {
      _operations.remove(cancellation);
    }
  }

  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) async* {
    _check();
    cancellation.check();
    _operations.add(cancellation);
    try {
      final roots = config.includePaths.isEmpty
          ? [source.rootPath]
          : config.includePaths;
      await for (final page in _client.walk(
        roots: roots.map(_path).toList(),
        excludes: config.excludePaths.map(_path).toList(),
        cancelled: cancellation.whenCancelled,
      )) {
        cancellation.check();
        final items = <NasMediaItem>[];
        for (final entry in page) {
          if (entry.isDirectory) continue;
          final kind = NasMediaKind.fromPath(entry.path);
          if (kind == null) continue;
          final relative = _basePath.isEmpty
              ? entry.path
              : entry.path.substring(_basePath.length + 1);
          items.add(
            NasMediaItem(
              serverId: source.id,
              path: '/$relative',
              kind: kind,
              sizeBytes: entry.size,
              modifiedEpoch: entry.modifiedSeconds,
            ),
          );
        }
        if (items.isNotEmpty) yield items;
      }
    } on SmbException {
      cancellation.check();
      rethrow;
    } finally {
      _operations.remove(cancellation);
    }
  }

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async {
    _check();
    if (item.serverId != source.id) throw StateError('NAS_SOURCE_MISMATCH');
    final path = _path(item.path);
    return NasResource(
      sizeBytes: item.sizeBytes,
      mimeType: item.mimeType ?? nasMimeType(item),
      read: (start, end, cancellation) async* {
        _check();
        cancellation.check();
        _operations.add(cancellation);
        try {
          yield* _client.read(
            path,
            start: start,
            end: end,
            cancelled: cancellation.whenCancelled,
          );
        } on SmbException {
          cancellation.check();
          rethrow;
        } finally {
          _operations.remove(cancellation);
        }
      },
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final operation in _operations.toList()) {
      operation.cancel();
    }
  }
}
