import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../infrastructure/nas/nas_http_client.dart';

class NasImageCacheService {
  final Future<NasSourceAdapter> Function(String) adapterFor;
  final int Function() budget;
  final _pending = <String, _ThumbnailWork>{};
  final _queue = <_ThumbnailWork>[];
  bool _running = false;
  bool _disposed = false;
  bool _clearing = false;
  _ThumbnailWork? _activeWork;
  Future<void>? _pumpFuture;
  int _writes = 0;
  NasImageCacheService(this.adapterFor, this.budget);

  String _key(NasMediaItem item) => sha256
      .convert(
        utf8.encode(
          '${item.serverId}\u0000${item.path}\u0000${item.modifiedEpoch}\u0000${item.sizeBytes}',
        ),
      )
      .toString();

  Future<String?> thumbnail(
    NasMediaItem item, {
    Object? owner,
    bool prefetch = false,
  }) {
    if (_disposed || _clearing) return Future.value(null);
    final key = _key(item);
    final existing = _pending[key];
    if (existing != null) {
      existing.owners.add(owner);
      if (!prefetch) existing.prefetch = false;
      if (_queue.remove(existing)) _queue.add(existing);
      return existing.result.future;
    }
    // New visible work takes priority over tiles that have scrolled away.
    if (_pending.length >= 64 && _queue.isNotEmpty) _cancel(_queue.first);
    final work = _ThumbnailWork(item, key, owner)..prefetch = prefetch;
    _pending[key] = work;
    _queue.add(work);
    _pumpFuture ??= _pump().whenComplete(() => _pumpFuture = null);
    return work.result.future;
  }

  void releaseThumbnail(NasMediaItem item, Object owner) {
    final work = _pending[_key(item)];
    if (work == null) return;
    work.owners.remove(owner);
    if (work.owners.isEmpty) _cancel(work);
  }

  void _cancel(_ThumbnailWork work) {
    work.timeout?.cancel();
    work.cancellation.cancel();
    _queue.remove(work);
    if (identical(_pending[work.key], work)) _pending.remove(work.key);
    if (!work.result.isCompleted) work.result.complete(null);
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && !_disposed && !_clearing) {
        final visibleIndex = _queue.lastIndexWhere((work) => !work.prefetch);
        final work = _queue.removeAt(
          visibleIndex < 0 ? _queue.length - 1 : visibleIndex,
        );
        _activeWork = work;
        work.timeout = Timer(
          Duration(seconds: work.item.kind == NasMediaKind.image ? 15 : 5),
          work.cancellation.cancel,
        );
        try {
          final path = await _load(work.item, work.key, work.cancellation);
          if (!work.result.isCompleted) work.result.complete(path);
        } catch (error, stack) {
          if (!work.result.isCompleted) {
            work.result.completeError(error, stack);
          }
        } finally {
          work.timeout?.cancel();
          if (identical(_pending[work.key], work)) _pending.remove(work.key);
          _activeWork = null;
          if (!work.finished.isCompleted) work.finished.complete();
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<String?> _load(
    NasMediaItem item,
    String key,
    NasCancellation cancellation,
  ) async {
    cancellation.check();
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/nas-thumbnails-v2',
    );
    await root.create(recursive: true);
    final target = File('${root.path}/$key.png');
    if (await target.exists()) {
      await target.setLastModified(DateTime.now());
      await _recordOwner(target, item.sourceId);
      return target.path;
    }
    if (budget() <= 0) return null;
    final adapter = await adapterFor(item.serverId);
    final preview = await adapter.thumbnail(item);
    if (preview == null && item.kind != NasMediaKind.image) return null;
    final resource = preview ?? await adapter.resolve(item);
    // The thumbnail working file is bounded separately from the persistent cache.
    const maxInput = 16 * 1024 * 1024;
    if ((resource.sizeBytes ?? 0) > maxInput) return null;
    final temporary = File('${root.path}/$key.part');
    final sink = temporary.openWrite();
    try {
      var size = 0;
      await for (final chunk in readNasResource(
        resource,
        0,
        resource.sizeBytes,
        cancellation,
      )) {
        size += chunk.length;
        if (size > maxInput) throw StateError('NAS_IMAGE_TOO_LARGE');
        sink.add(chunk);
      }
      await sink.close();
      cancellation.check();
      final buffer = await ui.ImmutableBuffer.fromFilePath(temporary.path);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width * descriptor.height > 80 * 1000 * 1000) {
          throw StateError('NAS_IMAGE_TOO_LARGE');
        }
        final scale = min(1.0, 512 / max(descriptor.width, descriptor.height));
        codec = await descriptor.instantiateCodec(
          targetWidth: max(1, (descriptor.width * scale).round()),
          targetHeight: max(1, (descriptor.height * scale).round()),
        );
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null || data.lengthInBytes > budget()) return null;
          cancellation.check();
          await target.writeAsBytes(data.buffer.asUint8List());
          // Commit ownership even if cancellation arrives during the write, so
          // a source-scoped clear can still identify this completed cache file.
          await _recordOwner(target, item.sourceId);
          cancellation.check();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
      if (++_writes % 16 == 1) await _prune(root);
      return await target.exists() ? target.path : null;
    } finally {
      await sink.close();
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _prune(Directory root) async {
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.png')) continue;
      final stat = await entity.stat();
      total += stat.size;
      files.add((entity, stat));
    }
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var count = files.length;
    for (final file in files) {
      if (total <= budget() && count <= 2000) break;
      await file.$1.delete();
      await _removeOwner(file.$1);
      total -= file.$2.size;
      count--;
    }
  }

  File _ownerFile(File thumbnail) => File('${thumbnail.path}.owner.json');

  Future<void> _recordOwner(File thumbnail, String sourceId) async {
    final file = _ownerFile(thumbnail);
    if (await file.exists()) return;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({'sourceId': sourceId}));
    await temporary.rename(file.path);
  }

  Future<String> _owner(File thumbnail) async {
    final file = _ownerFile(thumbnail);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return '';
    }
    if (await file.length() > 4096) return '';
    try {
      final value = jsonDecode(await file.readAsString());
      final source = value is Map ? value['sourceId'] : null;
      return source is String && source.isNotEmpty ? source : '';
    } on FormatException {
      return '';
    }
  }

  Future<void> _removeOwner(File thumbnail) async {
    final file = _ownerFile(thumbnail);
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file) {
      await file.delete();
    }
  }

  /// The empty key represents pre-existing cache with unknown ownership.
  Future<Map<String, Map<String, int>>> cacheUsageBySource() async {
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/nas-thumbnails-v2',
    );
    final usage = <String, Map<String, int>>{};
    if (await root.exists()) {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.png')) {
          try {
            final owner = await _owner(entity);
            final size = await entity.length();
            final entry = usage.putIfAbsent(
              owner,
              () => {'bytes': 0, 'count': 0},
            );
            entry['bytes'] = entry['bytes']! + size;
            entry['count'] = entry['count']! + 1;
          } on FileSystemException catch (error) {
            if (error.osError?.errorCode != 2) rethrow;
          }
        }
      }
    }
    return usage;
  }

  Future<Map<String, int>> cacheUsage({
    String? sourceId,
    bool legacyOnly = false,
  }) async {
    final usage = await cacheUsageBySource();
    if (legacyOnly) return usage[''] ?? {'bytes': 0, 'count': 0};
    if (sourceId != null) return usage[sourceId] ?? {'bytes': 0, 'count': 0};
    var bytes = 0, count = 0;
    for (final entry in usage.values) {
      bytes += entry['bytes']!;
      count += entry['count']!;
    }
    return {'bytes': bytes, 'count': count};
  }

  Future<void> trimCache() async {
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/nas-thumbnails-v2',
    );
    if (await root.exists()) await _prune(root);
  }

  Future<void> clearCache({String? sourceId, bool legacyOnly = false}) async {
    if (_clearing) throw StateError('NAS_CACHE_BUSY');
    _clearing = true;
    try {
      final active = _activeWork;
      bool matches(_ThumbnailWork work) =>
          !legacyOnly && (sourceId == null || work.item.sourceId == sourceId);
      for (final work in _pending.values.toList()) {
        if (matches(work)) _cancel(work);
      }
      // An active write must finish its ownership sidecar before legacy cleanup.
      if (active != null) await active.finished.future;
      final root = Directory(
        '${(await getApplicationSupportDirectory()).path}/nas-thumbnails-v2',
      );
      if (await root.exists()) {
        await for (final entity in root.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.png')) continue;
          try {
            final owner = await _owner(entity);
            if (legacyOnly
                ? owner.isNotEmpty
                : sourceId != null && owner != sourceId) {
              continue;
            }
            await entity.delete();
            await _removeOwner(entity);
          } on FileSystemException catch (error) {
            if (error.osError?.errorCode != 2) rethrow;
          }
        }
      }
    } finally {
      await _pumpFuture;
      _clearing = false;
      if (_queue.isNotEmpty && !_disposed) {
        _pumpFuture ??= _pump().whenComplete(() => _pumpFuture = null);
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final work in _pending.values.toList()) {
      _cancel(work);
    }
  }
}

class _ThumbnailWork {
  final NasMediaItem item;
  final String key;
  final owners = <Object?>{};
  final result = Completer<String?>();
  final finished = Completer<void>();
  final cancellation = NasCancellation();
  Timer? timeout;
  bool prefetch = false;
  _ThumbnailWork(this.item, this.key, Object? owner) {
    owners.add(owner);
  }
}
