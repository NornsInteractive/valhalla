import 'dart:async';
import 'dart:math';

import 'package:media_kit/media_kit.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/repositories/nas_index_repository.dart';
import '../../infrastructure/nas/nas_http_client.dart';
import '../../infrastructure/nas/nas_media_proxy_service.dart';

class NasMetadataProgress {
  final String? sourceId, errorCode;
  final bool running;
  final int processed, failed;
  const NasMetadataProgress({
    this.sourceId,
    this.running = false,
    this.processed = 0,
    this.failed = 0,
    this.errorCode,
  });
}

/// Foreground-only, one muted decoder and one bounded database page at a time.
/// The caller cancels on background/source changes and starts after scan batches.
class NasMetadataService {
  final NasIndexRepository _repository;
  final NasMediaProxyService _proxy;
  final Future<NasSourceAdapter> Function(String) _adapterFor;
  final Player Function() _playerFactory;
  final _changes = StreamController<NasMetadataProgress>.broadcast();
  NasMetadataProgress _state = const NasMetadataProgress();
  NasCancellation? _cancellation;
  Future<void>? _worker;
  Uri? _relay;
  bool _disposed = false, _again = false;
  int _generation = 0;

  NasMetadataService(
    this._repository,
    this._proxy,
    this._adapterFor, {
    Player Function()? playerFactory,
  }) : _playerFactory =
           playerFactory ??
           (() => Player(
             configuration: const PlayerConfiguration(
               muted: true,
               bufferSize: 512 * 1024,
               protocolWhitelist: ['http', 'tcp'],
             ),
           ));

  NasMetadataProgress get state => _state;
  Stream<NasMetadataProgress> get changes => _changes.stream;

  Future<void> start(String sourceId) async {
    if (_disposed) throw StateError('NAS_METADATA_DISPOSED');
    if (_worker != null &&
        _state.sourceId == sourceId &&
        _cancellation?.isCancelled == false) {
      _again = true;
      return _worker;
    }
    final generation = ++_generation;
    await _stop();
    if (_disposed || generation != _generation) return;
    final cancellation = NasCancellation();
    _cancellation = cancellation;
    _again = false;
    _state = NasMetadataProgress(sourceId: sourceId, running: true);
    _emit();
    final worker = _run(sourceId, cancellation, generation);
    _worker = worker;
    await worker;
    if (identical(_worker, worker)) _worker = null;
    if (_again &&
        !_disposed &&
        generation == _generation &&
        !cancellation.isCancelled) {
      _again = false;
      await start(sourceId);
    }
  }

  Future<void> _run(
    String sourceId,
    NasCancellation cancellation,
    int generation,
  ) async {
    Player? player;
    String? error;
    var processed = 0, failed = 0;
    try {
      final adapter = await _adapterFor(sourceId);
      cancellation.check();
      if (adapter.source.id != sourceId) {
        throw StateError('NAS_SOURCE_MISMATCH');
      }
      if (adapter.source.isMediaServer) return;
      var items = await _repository.pendingMetadata(sourceId);
      cancellation.check();
      if (items.isEmpty) return;
      await _probeSource(adapter, cancellation);
      player = _playerFactory();
      final native = player.platform;
      if (native is! NativePlayer) {
        throw StateError('NAS_METADATA_NATIVE_REQUIRED');
      }
      await _configure(native).timeout(const Duration(seconds: 10));
      while (items.isNotEmpty) {
        for (final item in items) {
          cancellation.check();
          try {
            final metadata = await _probe(
              player,
              native,
              adapter,
              item,
              cancellation,
            );
            cancellation.check();
            await _repository.completeMetadataProbe(item, metadata: metadata);
          } catch (exception) {
            cancellation.check();
            if (exception is NasCancelled) rethrow;
            // A broken connection must not mark the remaining library as bad.
            await _probeSource(adapter, cancellation);
            await _repository.completeMetadataProbe(item, failed: true);
            failed++;
          }
          processed++;
          _state = NasMetadataProgress(
            sourceId: sourceId,
            running: true,
            processed: processed,
            failed: failed,
          );
          _emit();
        }
        items = await _repository.pendingMetadata(sourceId);
      }
    } on NasCancelled {
      // Cancellation leaves the current file pending, preserving completed tags.
    } catch (_) {
      error = 'NAS_METADATA_UNAVAILABLE';
    } finally {
      _revoke();
      try {
        await player?.dispose();
      } catch (_) {
        error ??= 'NAS_METADATA_UNAVAILABLE';
      }
      if (generation == _generation) {
        _state = NasMetadataProgress(
          sourceId: sourceId,
          processed: processed,
          failed: failed,
          errorCode: error,
        );
        _emit();
      }
    }
  }

  static Future<void> _probeSource(
    NasSourceAdapter adapter,
    NasCancellation cancellation,
  ) async {
    cancellation.check();
    final interrupted = Completer<void>();
    final remove = cancellation.onCancel(interrupted.complete);
    try {
      await Future.any<void>([
        adapter.probe().timeout(const Duration(seconds: 10)),
        interrupted.future.then((_) => throw const NasCancelled()),
      ]);
      cancellation.check();
    } finally {
      remove();
    }
  }

  static Future<void> _configure(NativePlayer native) async {
    for (final property in const {
      'ao': 'null',
      'vid': 'no',
      'audio-display': 'no',
      'cache': 'no',
      'demuxer-max-bytes': '524288',
      'demuxer-max-back-bytes': '0',
      'demuxer-readahead-secs': '0',
      'demuxer-lavf-probesize': '1048576',
      'demuxer-lavf-analyzeduration': '0.5',
      'access-references': 'no',
      'autoload-files': 'no',
      'ytdl': 'no',
    }.entries) {
      await native.setProperty(property.key, property.value);
    }
  }

  Future<NasMediaItem> _probe(
    Player player,
    NativePlayer native,
    NasSourceAdapter adapter,
    NasMediaItem item,
    NasCancellation runCancellation,
  ) async {
    final cancellation = NasCancellation();
    final remove = runCancellation.onCancel(cancellation.cancel);
    try {
      return await (() async {
        final resource = await adapter.resolve(item);
        cancellation.check();
        final bounded = NasMetadataReadBudget(
          resource,
          cancellation,
          fallbackSize: item.sizeBytes,
        );
        final relay = await _proxy.exposeResource(item, bounded.resource);
        if (cancellation.isCancelled) {
          _proxy.revoke(relay);
          cancellation.check();
        }
        _relay = relay;
        // Force an audio container demuxer so disguised playlists cannot make
        // the native decoder open referenced URLs outside the bounded relay.
        const formats = {
          'mp3': 'mp3',
          'flac': 'flac',
          'wav': 'wav',
          'm4a': 'mov',
          'aac': 'aac',
          'ogg': 'ogg',
          'opus': 'ogg',
          'wma': 'asf',
        };
        final format = formats[item.name.split('.').last.toLowerCase()];
        if (format == null) throw StateError('NAS_METADATA_FORMAT_UNSUPPORTED');
        await native.setProperty('demuxer', 'lavf');
        await native.setProperty('demuxer-lavf-format', format);
        cancellation.check();
        await player.open(Media(relay.toString()), play: false);
        cancellation.check();
        // open() sends loadfile; demuxer readiness arrives afterwards.
        while ((int.tryParse(await native.getProperty('track-list/count')) ??
                0) ==
            0) {
          cancellation.check();
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        cancellation.check();
        final tags = <String, String>{};
        final count =
            (int.tryParse(await native.getProperty('metadata/list/count')) ?? 0)
                .clamp(0, 64);
        // ponytail: inspect 64 tags per file; raise only for libraries with
        // useful tags beyond that bound. Existing list keys avoid missing-key
        // allocations in NativePlayer.getProperty from media_kit 1.2.6.
        for (var i = 0; i < count; i++) {
          cancellation.check();
          final key = (await native.getProperty(
            'metadata/list/$i/key',
          )).toUpperCase();
          if (!const {
            'TITLE',
            'ARTIST',
            'ALBUM',
            'TRACK',
            'TRACKNUMBER',
          }.contains(key)) {
            continue;
          }
          final value = (await native.getProperty(
            'metadata/list/$i/value',
          )).trim();
          if (value.isNotEmpty) {
            tags[key] = value.substring(0, min(value.length, 4096));
          }
        }
        cancellation.check();
        final track = int.tryParse(
          (tags['TRACK'] ?? tags['TRACKNUMBER'] ?? '').split('/').first,
        );
        final duration = player.state.duration;
        return NasMediaItem(
          serverId: item.serverId,
          path: item.path,
          kind: item.kind,
          sizeBytes: item.sizeBytes,
          modifiedEpoch: item.modifiedEpoch,
          title: tags['TITLE'],
          artist: tags['ARTIST'],
          album: tags['ALBUM'],
          trackNumber: track != null && track > 0 ? track : null,
          durationMillis: duration > Duration.zero
              ? duration.inMilliseconds
              : null,
        );
      })().timeout(const Duration(seconds: 10));
    } finally {
      cancellation.cancel();
      remove();
      _revoke();
      await player.stop().timeout(const Duration(seconds: 5));
    }
  }

  void _emit() {
    if (!_disposed) _changes.add(_state);
  }

  void _revoke() {
    final relay = _relay;
    _relay = null;
    if (relay != null) _proxy.revoke(relay);
  }

  Future<void> _stop() async {
    _cancellation?.cancel();
    _revoke();
    await _worker;
  }

  Future<void> cancel() async {
    ++_generation;
    _again = false;
    await _stop();
    _state = NasMetadataProgress(
      sourceId: _state.sourceId,
      processed: _state.processed,
      failed: _state.failed,
    );
    _emit();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _changes.close();
  }
}

/// Reserves each upstream range before reading it, including concurrent mpv
/// head/tail requests. Even read-ahead within an adapter cannot exceed 3 MiB.
/// Small files can fit entirely within that ceiling; nothing is cached on disk.
class NasMetadataReadBudget {
  static const maxBytes = 3 * 1024 * 1024;
  final NasResource _original;
  final NasCancellation _cancellation;
  final int _size;
  int _reserved = 0;
  NasMetadataReadBudget(
    this._original,
    this._cancellation, {
    required int fallbackSize,
  }) : _size = _original.sizeBytes ?? fallbackSize;

  int get reservedBytes => _reserved;
  NasResource get resource => NasResource(
    read: _read,
    sizeBytes: _size,
    mimeType: _original.mimeType,
    seekable: _original.seekable,
  );

  Stream<List<int>> _read(
    int start,
    int? end,
    NasCancellation requestCancellation,
  ) async* {
    final cancellation = NasCancellation();
    final removeRun = _cancellation.onCancel(cancellation.cancel);
    final removeRequest = requestCancellation.onCancel(cancellation.cancel);
    try {
      var offset = start;
      final last = min(end ?? _size, _size);
      if (start < 0 || last < start) throw RangeError('NAS_INVALID_RANGE');
      while (offset < last) {
        cancellation.check();
        final amount = min(min(64 * 1024, last - offset), maxBytes - _reserved);
        if (amount <= 0) throw StateError('NAS_METADATA_READ_LIMIT');
        _reserved += amount;
        var received = 0;
        await for (final bytes in readNasResource(
          _original,
          offset,
          offset + amount,
          cancellation,
        )) {
          cancellation.check();
          received += bytes.length;
          if (received > amount) throw StateError('NAS_METADATA_INVALID_RANGE');
          yield bytes;
        }
        if (received != amount) throw StateError('NAS_METADATA_TRUNCATED');
        offset += received;
      }
    } finally {
      removeRun();
      removeRequest();
      cancellation.cancel();
    }
  }
}
