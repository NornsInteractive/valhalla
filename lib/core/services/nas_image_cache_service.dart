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
  final _pending = <String, Future<String?>>{};
  Future<void> _work = Future.value();
  int _writes = 0;
  final _cancellation = NasCancellation();
  NasImageCacheService(this.adapterFor, this.budget);

  Future<String?> thumbnail(NasMediaItem item) {
    final key = sha256
        .convert(
          utf8.encode(
            '${item.serverId}\u0000${item.path}\u0000${item.modifiedEpoch}\u0000${item.sizeBytes}',
          ),
        )
        .toString();
    if (_pending.containsKey(key)) return _pending[key]!;
    // Serialize native decode and cap pending work to the visible viewport.
    if (_pending.length >= 64) return Future.value(null);
    final future = _work.then((_) => _load(item, key));
    _pending[key] = future;
    _work = future.then<void>((_) {}, onError: (Object _) {});
    return future.whenComplete(() => _pending.remove(key));
  }

  Future<String?> _load(NasMediaItem item, String key) async {
    _cancellation.check();
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/nas-thumbnails-v2',
    );
    await root.create(recursive: true);
    final target = File('${root.path}/$key.png');
    if (await target.exists()) {
      await target.setLastModified(DateTime.now());
      return target.path;
    }
    if (budget() <= 0) return null;
    final adapter = await adapterFor(item.serverId);
    final preview = await adapter.thumbnail(item);
    if (preview == null && item.kind != NasMediaKind.image) return null;
    final resource = preview ?? await adapter.resolve(item);
    // The thumbnail working file is bounded separately from the persistent cache.
    const maxInput = 256 * 1024 * 1024;
    if ((resource.sizeBytes ?? 0) > maxInput) return null;
    final temporary = File('${root.path}/$key.part');
    final sink = temporary.openWrite();
    try {
      var size = 0;
      await for (final chunk in readNasResource(
        resource,
        0,
        resource.sizeBytes,
        _cancellation,
      )) {
        size += chunk.length;
        if (size > maxInput) throw StateError('NAS_IMAGE_TOO_LARGE');
        sink.add(chunk);
        await sink.flush();
      }
      await sink.close();
      final buffer = await ui.ImmutableBuffer.fromFilePath(temporary.path);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
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
          await target.writeAsBytes(data.buffer.asUint8List());
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
    await for (final entity in root.list()) {
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
      total -= file.$2.size;
      count--;
    }
  }

  void dispose() => _cancellation.cancel();
}
