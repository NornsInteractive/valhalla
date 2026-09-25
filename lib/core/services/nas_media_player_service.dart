import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/repositories/nas_index_repository.dart';
import '../../infrastructure/nas/nas_hls_relay_service.dart';
import '../../infrastructure/nas/nas_media_proxy_service.dart';

enum NasRepeat { off, all, one }

/// Reuse media_kit_video's device detection; no separate device-info plugin.
Future<VideoControllerConfiguration> nasVideoConfiguration() async {
  const defaults = VideoControllerConfiguration();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return defaults;
  }
  try {
    final emulator = await const MethodChannel(
      'com.alexmercerind/media_kit_video',
    ).invokeMethod<bool>('Utils.IsEmulator');
    if (emulator == true) {
      // Bundled mpv 0.36 rejects the emulator's EGL 1.4 context attributes.
      // Native MediaCodec surface output bypasses EGL; physical devices keep
      // media_kit's default GPU path and its broader software codec fallback.
      return const VideoControllerConfiguration(
        vo: 'mediacodec_embed',
        hwdec: 'mediacodec',
      );
    }
  } on PlatformException {
    return defaults;
  } on MissingPluginException {
    return defaults;
  }
  return defaults;
}

class NasPlayerSnapshot {
  final NasMediaItem? current;
  final List<NasMediaItem> queue;
  final int index;
  final bool playing, buffering, shuffle;
  final Duration position, duration;
  final double rate;
  final NasRepeat repeat;
  final NasPlaybackQuality quality;
  final String? error;
  const NasPlayerSnapshot({
    this.current,
    this.queue = const [],
    this.index = -1,
    this.playing = false,
    this.buffering = false,
    this.shuffle = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.rate = 1,
    this.repeat = NasRepeat.off,
    this.quality = NasPlaybackQuality.original,
    this.error,
  });
}

/// One native player, one serialized native command path, source-bound progress.
class NasMediaPlayerService {
  final NasMediaProxyService _proxy;
  final NasIndexRepository _repository;
  final Future<NasSourceAdapter> Function(String)? adapterFor;
  final Player player;
  final NasHlsRelayService _hls = NasHlsRelayService();
  Timer? _heartbeat;
  final _changes = StreamController<NasPlayerSnapshot>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<NasMediaItem> _queue = [];
  int _index = -1, _epoch = 0;
  int? _metadataReadEpoch, _metadataBusyEpoch;
  bool _opening = false, _disposed = false, _shuffle = false;
  NasRepeat _repeat = NasRepeat.off;
  NasPlaybackQuality _quality = NasPlaybackQuality.original;
  String? _error, _sessionId;
  Uri? _relay;
  NasSourceAdapter? _adapter;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _operations = Future.value(), _nativeOperations = Future.value();
  final _pendingSync = <(_Progress, String)>[];
  bool _syncing = false;
  Future<void>? _nextOperation;
  Future<VideoController>? _videoController;
  Future<List<NasMediaItem>> Function()? _loadMore;
  Future<List<NasMediaItem>> Function()? _restartQueue;
  bool _queueExhausted = false;
  final _shuffleVisited = <(String, String, String?)>{};
  _QueueLease? _queueLease;

  NasMediaPlayerService(
    this._proxy,
    this._repository, {
    this.adapterFor,
    Player? player,
  }) : player = player ?? Player() {
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) {
      final relay = _relay;
      if (relay != null) {
        _proxy.retain(relay);
        _hls.retain(relay);
      }
    });
    _subscriptions.addAll([
      this.player.stream.position.listen((_) {
        _emit();
        _savePeriodically();
      }),
      this.player.stream.duration.listen((_) {
        _emit();
        _readMetadata();
      }),
      this.player.stream.playing.listen((_) => _emit()),
      this.player.stream.buffering.listen((_) => _emit()),
      this.player.stream.rate.listen((_) => _emit()),
      this.player.stream.error.listen((_) {
        _error = 'NAS_PLAYBACK_FAILED';
        _emit();
      }),
      // media_kit's error stream omits fatal/VO failures. Surface them instead
      // of leaving an apparently playing video with a permanently black frame.
      this.player.stream.log.listen((event) {
        if (event.level == 'fatal' ||
            (event.level == 'error' && event.prefix.startsWith('vo'))) {
          reportPlatformError('NAS_PLAYBACK_FAILED');
        }
      }),
      this.player.stream.completed.listen((done) {
        if (done && !_opening && current != null) {
          unawaited(next(completed: true).catchError(_recordError));
        }
      }),
    ]);
  }

  NasMediaItem? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  Stream<NasPlayerSnapshot> get changes => _changes.stream;
  NasPlayerSnapshot get state => NasPlayerSnapshot(
    current: current,
    queue: List.unmodifiable(_queue),
    index: _index,
    playing: player.state.playing,
    buffering: _opening || player.state.buffering,
    position: player.state.position,
    duration: player.state.duration,
    rate: player.state.rate,
    shuffle: _shuffle,
    repeat: _repeat,
    quality: _quality,
    error: _error,
  );

  void _emit() {
    if (!_disposed) _changes.add(state);
  }

  void _recordError(Object error) {
    _error = 'NAS_PLAYBACK_OR_SYNC_FAILED';
    _emit();
  }

  void reportPlatformError(String code) {
    _error = code;
    _emit();
  }

  /// One video output for this player's lifetime, including reopened dialogs.
  /// media_kit releases the platform output through Player.dispose().
  Future<VideoController> get videoController =>
      _videoController ??= _createVideoController();

  Future<VideoController> _createVideoController() async {
    try {
      final configuration = await nasVideoConfiguration();
      if (_disposed) throw const NasCancelled();
      final controller = VideoController(player, configuration: configuration);
      await controller.platform.future;
      if (_disposed) throw const NasCancelled();
      return controller;
    } catch (_) {
      if (!_disposed) reportPlatformError('NAS_PLAYBACK_FAILED');
      rethrow;
    }
  }

  bool _valid(int epoch) => !_disposed && epoch == _epoch;

  Future<void> _native(Future<void> Function() command) {
    final next = _nativeOperations.then((_) => command());
    // A failed command must not poison subsequent stop/open requests.
    _nativeOperations = next.catchError((Object _) {});
    return next;
  }

  Future<void> open(
    NasMediaItem item, {
    List<NasMediaItem>? queue,
    Future<List<NasMediaItem>> Function()? loadMore,
    Future<List<NasMediaItem>> Function()? restartQueue,
    NasPlaybackQuality? quality,
    void Function()? disposeQueue,
  }) => _requestOpen(
    item,
    queue: queue,
    loadMore: loadMore,
    restartQueue: restartQueue,
    quality: quality,
    disposeQueue: disposeQueue,
  );

  Future<void> _requestOpen(
    NasMediaItem item, {
    List<NasMediaItem>? queue,
    Future<List<NasMediaItem>> Function()? loadMore,
    Future<List<NasMediaItem>> Function()? restartQueue,
    NasPlaybackQuality? quality,
    void Function()? disposeQueue,
    Duration? position,
    bool keepQueueState = false,
  }) async {
    if (_disposed) throw StateError('NAS_PLAYER_CLOSED');
    final entries = List<NasMediaItem>.of(
      queue == null || queue.isEmpty ? [item] : queue,
    );
    final index = entries.indexWhere((e) => _queueKey(e) == _queueKey(item));
    if (index < 0) throw ArgumentError('NAS_QUEUE_ITEM_MISSING');
    if (entries.length > 600) throw ArgumentError('NAS_QUEUE_PAGE_TOO_LARGE');
    final lease = identical(_queueLease?.dispose, disposeQueue)
        ? _queueLease
        : _QueueLease(disposeQueue);
    final epoch = ++_epoch;
    if (!keepQueueState) _nextOperation = null;
    final previous = _operations;
    _operations = () async {
      try {
        await previous;
      } catch (_) {}
      if (!_valid(epoch)) {
        if (!identical(lease, _queueLease)) _closeLease(lease);
        return;
      }
      await _save(event: 'stop');
      if (!_valid(epoch)) {
        if (!identical(lease, _queueLease)) _closeLease(lease);
        return;
      }
      if (!identical(_queueLease, lease)) _releaseQueue();
      _queueLease = lease;
      _queue = entries;
      _index = index;
      _loadMore = loadMore;
      _restartQueue = restartQueue;
      if (!keepQueueState) {
        _queueExhausted = false;
        _shuffleVisited.clear();
      }
      if (_shuffle) _shuffleVisited.add(_queueKey(item));
      if (quality != null) _quality = quality;
      await _openCurrent(epoch, position: position);
    }();
    return _operations;
  }

  Future<void> _openCurrent(int epoch, {Duration? position}) async {
    final item = current;
    if (item == null || !_valid(epoch)) return;
    _opening = true;
    _error = null;
    _emit();
    Uri? newRelay;
    try {
      final adapter = await adapterFor?.call(item.serverId);
      final resource = await adapter?.resolve(item, quality: _quality);
      if (!_valid(epoch)) return;
      final Uri url;
      final Map<String, String> headers;
      if (resource?.uri != null &&
          (resource!.mimeType.toLowerCase().contains('mpegurl') ||
              resource.uri!.path.toLowerCase().endsWith('.m3u8'))) {
        url = await _hls.expose(resource);
        newRelay = url;
        headers = const {};
      } else if (resource != null &&
          resource.uri != null &&
          resource.read == null &&
          resource.headers.isEmpty &&
          resource.uri!.query.isEmpty) {
        url = resource.uri!;
        headers = resource.headers;
      } else {
        url = resource == null
            ? await _proxy.expose(item)
            : await _proxy.exposeResource(item, resource);
        newRelay = url;
        headers = const {};
      }
      if (!_valid(epoch)) return;
      Duration? resume = position;
      if (resume == null && adapter?.source.isMediaServer == true) {
        try {
          resume = await adapter!.resumePosition(item);
        } catch (_) {
          reportPlatformError('NAS_PLAYBACK_SYNC_FAILED');
        }
      }
      final saved = await _repository.playbackFor(item.serverId, item.path);
      if (!_valid(epoch)) return;
      final duration = item.duration ?? saved?.duration;
      var target = resume ?? saved?.position ?? Duration.zero;
      if (target < Duration.zero ||
          (duration != null &&
              duration > Duration.zero &&
              target >= duration - const Duration(seconds: 3))) {
        target = Duration.zero;
      }
      await _native(() async {
        if (!_valid(epoch)) return;
        final oldRelay = _relay;
        await player.open(
          // media_kit applies start in mpv's on_load hook. open() itself only
          // submits load commands, so an immediate seek can precede loading.
          Media(url.toString(), httpHeaders: headers, start: target),
          play: false,
        );
        if (!_valid(epoch)) return;
        _relay = newRelay;
        newRelay = null;
        if (oldRelay != null) _revoke(oldRelay);
        _adapter = adapter;
        _sessionId = resource?.playSessionId;
        if (!_valid(epoch)) return;
        await player.play();
        if (!_valid(epoch)) return;
        _enqueueSync(
          _Progress(
            item,
            target,
            duration ?? Duration.zero,
            adapter,
            resource?.playSessionId,
            false,
          ),
          'start',
        );
      });
    } catch (error) {
      if (_valid(epoch)) {
        _recordError(error);
        rethrow;
      }
    } finally {
      if (newRelay != null) _revoke(newRelay!);
      if (_valid(epoch)) {
        _opening = false;
        _emit();
        _readMetadata();
      }
    }
  }

  /// libmpv reads container tags; unplayed files remain explicitly untagged.
  void _readMetadata() {
    final epoch = _epoch, item = current;
    if (item == null ||
        _opening ||
        _disposed ||
        _adapter?.source.isMediaServer == true ||
        _metadataReadEpoch == epoch ||
        _metadataBusyEpoch == epoch) {
      return;
    }
    final native = player.platform;
    if (native is! NativePlayer) return;
    _metadataBusyEpoch = epoch;
    unawaited(() async {
      NasMediaItem? enriched;
      try {
        await _native(() async {
          if (!_valid(epoch)) return;
          final tags = <String, String>{};
          final count =
              int.tryParse(await native.getProperty('metadata/list/count')) ??
              0;
          for (var i = 0; i < min(count, 64); i++) {
            final key = (await native.getProperty(
              'metadata/list/$i/key',
            )).toUpperCase();
            if (!{
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
          final title = tags['TITLE'],
              artist = tags['ARTIST'],
              album = tags['ALBUM'];
          final track = tags['TRACK'] ?? tags['TRACKNUMBER'];
          if (!_valid(epoch)) return;
          final duration = player.state.duration;
          if (title == null &&
              artist == null &&
              album == null &&
              track == null &&
              duration <= Duration.zero) {
            return;
          }
          enriched = item.copyWith(
            title: title,
            artist: artist,
            album: album,
            trackNumber: int.tryParse(track?.split('/').first ?? ''),
            durationMillis: duration > Duration.zero
                ? duration.inMilliseconds
                : null,
          );
          _metadataReadEpoch = epoch;
        });
        if (enriched == null || !_valid(epoch)) return;
        await _repository.updateMetadata(enriched!);
        if (!_valid(epoch)) return;
        _queue[_index] = enriched!;
        _emit();
      } catch (_) {
        // Missing/unsupported tags are normal and must not interrupt playback.
      } finally {
        if (_metadataBusyEpoch == epoch) _metadataBusyEpoch = null;
      }
    }());
  }

  Future<void> play() {
    final epoch = _epoch;
    return _native(() async {
      if (_valid(epoch) && current != null) await player.play();
    });
  }

  Future<void> pause() async {
    final epoch = _epoch;
    await _native(() async {
      if (_valid(epoch)) await player.pause();
    });
    if (_valid(epoch)) await _save();
  }

  Future<void> playOrPause() => player.state.playing ? pause() : play();
  Future<void> seek(Duration position) async {
    final epoch = _epoch;
    await _native(() async {
      if (_valid(epoch) && current != null) await player.seek(position);
    });
    if (_valid(epoch)) await _save();
  }

  Future<void> setRate(double value) {
    final epoch = _epoch;
    return _native(() async {
      if (_valid(epoch)) await player.setRate(value.clamp(0.25, 4));
    });
  }

  Future<void> setAudioTrack(AudioTrack track) {
    final epoch = _epoch;
    return _native(() async {
      if (_valid(epoch)) await player.setAudioTrack(track);
    });
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) {
    final epoch = _epoch;
    return _native(() async {
      if (_valid(epoch)) await player.setSubtitleTrack(track);
    });
  }

  void setShuffle(bool value) {
    _shuffle = value;
    _shuffleVisited.clear();
    if (value && current != null) _shuffleVisited.add(_queueKey(current!));
    _emit();
  }

  void setRepeat(NasRepeat value) {
    _repeat = value;
    _emit();
  }

  /// Reflect an acknowledged library change without reopening playback.
  void applyFavorite(String sourceId, String path, bool value) {
    if (_disposed) return;
    var changed = false;
    for (var i = 0; i < _queue.length; i++) {
      final item = _queue[i];
      if (item.serverId == sourceId &&
          item.path == path &&
          item.isFavorite != value) {
        _queue[i] = item.copyWith(isFavorite: value);
        changed = true;
      }
    }
    if (changed) _emit();
  }

  Future<void> setQuality(NasPlaybackQuality quality) async {
    final item = current;
    if (item == null || quality == _quality) return;
    await _requestOpen(
      item,
      queue: _queue,
      loadMore: _loadMore,
      restartQueue: _restartQueue,
      disposeQueue: _queueLease?.dispose,
      quality: quality,
      position: player.state.position,
      keepQueueState: true,
    );
  }

  Future<void> next({bool completed = false}) {
    if (_nextOperation != null) return _nextOperation!;
    late final Future<void> operation;
    operation = _next(completed: completed).whenComplete(() {
      if (identical(_nextOperation, operation)) _nextOperation = null;
    });
    _nextOperation = operation;
    return operation;
  }

  Future<void> _next({required bool completed}) async {
    if (current == null) return;
    final epoch = _epoch;
    if (completed && _repeat == NasRepeat.one) {
      await seek(Duration.zero);
      if (_valid(epoch)) await play();
      return;
    }
    final loader = _loadMore;
    var target = _nextIndex();
    if (target < 0 && loader != null && !_queueExhausted) {
      final more = await loader();
      if (!_valid(epoch)) return;
      if (more.isEmpty) {
        _queueExhausted = true;
      } else if (_shuffle) {
        // Shuffle one bounded page at a time; every page is reachable without
        // retaining or randomly sorting an entire remote music library.
        _queue = [current!, ...more.take(200)];
        _index = 0;
        _shuffleVisited.retainAll(_queue.map(_queueKey));
      } else {
        final removed = max(0, _index - 99);
        _queue = [..._queue.skip(removed), ...more.take(200)];
        _index -= removed;
      }
      target = _nextIndex();
    }
    if (!_valid(epoch)) return;
    if (target < 0) {
      if (_repeat == NasRepeat.all) {
        final restart = _restartQueue;
        final entries = restart == null ? _queue : await restart();
        if (!_valid(epoch)) return;
        if (entries.isEmpty) {
          await pause();
          return;
        }
        final firstPage = restart == null
            ? entries
            : entries.take(200).toList();
        _shuffleVisited.clear();
        if (restart != null) _queueExhausted = false;
        await _requestOpen(
          firstPage[_shuffle ? Random().nextInt(firstPage.length) : 0],
          queue: firstPage,
          loadMore: _loadMore,
          restartQueue: restart,
          disposeQueue: _queueLease?.dispose,
          keepQueueState: true,
        );
        return;
      } else {
        await pause();
        return;
      }
    }
    await jumpTo(target);
  }

  (String, String, String?) _queueKey(NasMediaItem item) =>
      (item.serverId, item.path, item.playlistEntryId);

  int _nextIndex() {
    if (!_shuffle) return _index + 1 < _queue.length ? _index + 1 : -1;
    final available = [
      for (var i = 0; i < _queue.length; i++)
        if (!_shuffleVisited.contains(_queueKey(_queue[i]))) i,
    ];
    return available.isEmpty
        ? -1
        : available[Random().nextInt(available.length)];
  }

  Future<void> previous() async {
    if (player.state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_index > 0) await jumpTo(_index - 1);
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _requestOpen(
      _queue[index],
      queue: _queue,
      loadMore: _loadMore,
      restartQueue: _restartQueue,
      disposeQueue: _queueLease?.dispose,
      keepQueueState: true,
    );
  }

  _Progress? _capture() {
    final item = current;
    if (item == null || _opening) return null;
    return _Progress(
      item,
      player.state.position,
      player.state.duration,
      _adapter,
      _sessionId,
      !player.state.playing,
    );
  }

  void _savePeriodically() {
    final now = DateTime.now();
    if (_opening || now.difference(_lastSave) < const Duration(seconds: 5)) {
      return;
    }
    _lastSave = now;
    unawaited(_save());
  }

  Future<void> _save({String event = 'progress'}) =>
      _saveCaptured(_capture(), event);
  Future<void> _saveCaptured(_Progress? progress, String event) async {
    if (progress == null) return;
    _enqueueSync(progress, event);
    try {
      await _repository.savePlayback(
        NasPlaybackState(
          serverId: progress.item.serverId,
          path: progress.item.path,
          position: progress.position,
          duration: progress.duration,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      reportPlatformError('NAS_PLAYBACK_SAVE_FAILED');
    }
  }

  void _enqueueSync(_Progress progress, String event) {
    if (progress.adapter?.source.isMediaServer != true) return;
    // Keep fresh progress during a slow server request rather than accumulate
    // a replay backlog. Lifecycle requests remain ordered within a fixed bound.
    if (event == 'progress') {
      _pendingSync.removeWhere(
        (entry) =>
            entry.$2 == 'progress' &&
            entry.$1.item.serverId == progress.item.serverId &&
            entry.$1.item.path == progress.item.path,
      );
    }
    if (_pendingSync.length >= 16) {
      reportPlatformError('NAS_PLAYBACK_SYNC_BACKLOG');
      return;
    }
    _pendingSync.add((progress, event));
    if (_syncing) return;
    _syncing = true;
    unawaited(() async {
      try {
        while (_pendingSync.isNotEmpty) {
          final (captured, kind) = _pendingSync.removeAt(0);
          try {
            await captured.adapter!.reportPlayback(
              captured.item,
              captured.position,
              event: kind,
              paused: captured.paused,
              playSessionId: captured.sessionId,
            );
          } catch (_) {
            reportPlatformError('NAS_PLAYBACK_SYNC_FAILED');
          }
        }
      } finally {
        _syncing = false;
      }
    }());
  }

  void _revoke(Uri uri) {
    _proxy.revoke(uri);
    _hls.revoke(uri);
  }

  void _closeLease(_QueueLease? lease) {
    try {
      lease?.close();
    } catch (_) {
      reportPlatformError('NAS_QUEUE_CLOSE_FAILED');
    }
  }

  void _releaseQueue() {
    final lease = _queueLease;
    _queueLease = null;
    _loadMore = null;
    _restartQueue = null;
    _shuffleVisited.clear();
    _queueExhausted = false;
    _closeLease(lease);
  }

  Future<void> stop() async {
    final saved = _capture();
    ++_epoch;
    _nextOperation = null;
    _opening = false;
    final relay = _relay;
    _relay = null;
    _queue = [];
    _index = -1;
    _adapter = null;
    _sessionId = null;
    _releaseQueue();
    _emit();
    try {
      await _native(() => player.stop());
    } finally {
      if (relay != null) _revoke(relay);
      await _saveCaptured(saved, 'stop');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _heartbeat?.cancel();
    try {
      await stop();
    } catch (_) {}
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _native(() => player.dispose());
    await _hls.dispose();
    await _changes.close();
  }
}

class _QueueLease {
  final void Function()? dispose;
  bool closed = false;
  _QueueLease(this.dispose);
  void close() {
    if (!closed) {
      closed = true;
      dispose?.call();
    }
  }
}

class _Progress {
  final NasMediaItem item;
  final Duration position, duration;
  final NasSourceAdapter? adapter;
  final String? sessionId;
  final bool paused;
  const _Progress(
    this.item,
    this.position,
    this.duration,
    this.adapter,
    this.sessionId,
    this.paused,
  );
}
