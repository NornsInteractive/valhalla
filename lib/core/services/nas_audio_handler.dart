import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart' as windows;
// Version pinned to 1.1.0: the public facade omits the native seek event.
// The generated API exposes it and returns WinRT failures as Dart errors.
// ignore: implementation_imports
import 'package:smtc_windows/src/rust/api/api.dart' as smtc;

import '../../data/models/nas_media.dart';
import 'nas_linux_media_controls.dart';
import 'nas_media_player_service.dart';

/// System controls mirror and command the existing NAS player; no second audio
/// decoder or independently advancing queue is created here.
class NasAudioHandler extends BaseAudioHandler {
  static NasAudioHandler? _shared;
  static Future<void>? _initialization;
  NasMediaPlayerService? _player;
  StreamSubscription<NasPlayerSnapshot>? _playerSubscription;
  final _systemSubscriptions = <StreamSubscription<dynamic>>[];
  AudioSession? _session;
  smtc.SmtcInternal? _windows;
  NasLinuxMediaControls? _linux;
  NasPlayerSnapshot? _previous;
  void Function(String)? _onError;
  String? errorCode;
  NasPlayerSnapshot? _pendingWindowsSnapshot;
  NasMediaItem? _windowsItem;
  bool _writingWindows = false;
  int _bindingEpoch = 0;

  NasAudioHandler();

  /// Call when the player provider is first needed. AudioService permits one
  /// initialization per process; later providers rebind this same handler.
  static Future<NasAudioHandler> attach(
    NasMediaPlayerService player, {
    void Function(String)? onError,
  }) async {
    final handler = _shared ??= NasAudioHandler();
    handler._onError = onError;
    await handler.bind(player);
    await (_initialization ??= handler._initialize());
    if (identical(handler._player, player)) {
      if (handler.errorCode != null) onError?.call(handler.errorCode!);
      handler._publish(player.state, force: true);
    }
    return handler;
  }

  Future<void> _initialize() async {
    try {
      if (Platform.isWindows) {
        await windows.SMTCWindows.initialize();
        final controls = _windows = smtc.smtcNew(enabled: false);
        await smtc.smtcUpdateConfig(
          internal: controls,
          config: const windows.SMTCConfig(
            playEnabled: true,
            pauseEnabled: true,
            stopEnabled: true,
            nextEnabled: true,
            prevEnabled: true,
            fastForwardEnabled: true,
            rewindEnabled: true,
          ),
        );
        _systemSubscriptions.addAll([
          smtc.smtcButtonPressEvent(internal: controls).listen((button) {
            switch (button) {
              case 'play':
                unawaited(play());
              case 'pause':
                unawaited(pause());
              case 'next':
                unawaited(skipToNext());
              case 'previous':
                unawaited(skipToPrevious());
              case 'stop':
                unawaited(stop());
              case 'fast_forward':
                unawaited(fastForward());
              case 'rewind':
                unawaited(rewind());
            }
          }, onError: _systemError),
          // WinRT TimeSpan is in 100 ns ticks, despite the plugin's variable name.
          smtc
              .smtcPositionChangeRequestEvent(internal: controls)
              .listen(
                (ticks) => unawaited(seek(Duration(microseconds: ticks ~/ 10))),
                onError: _systemError,
              ),
          smtc
              .smtcShuffleRequestEvent(internal: controls)
              .listen(
                (enabled) => unawaited(
                  setShuffleMode(
                    enabled
                        ? AudioServiceShuffleMode.all
                        : AudioServiceShuffleMode.none,
                  ),
                ),
                onError: _systemError,
              ),
          smtc
              .smtcRepeatModeRequestEvent(internal: controls)
              .listen(
                (mode) => unawaited(
                  setRepeatMode(
                    mode == 'track'
                        ? AudioServiceRepeatMode.one
                        : mode == 'list'
                        ? AudioServiceRepeatMode.all
                        : AudioServiceRepeatMode.none,
                  ),
                ),
                onError: _systemError,
              ),
        ]);
      } else if (Platform.isLinux) {
        _linux = await NasLinuxMediaControls.create(this);
      } else {
        _systemSubscriptions.add(AudioService.asyncError.listen(_systemError));
        await AudioService.init(
          builder: () => this,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.antigravity.valhalla.media',
            androidNotificationChannelName: 'Valhalla',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            preloadArtwork: false,
          ),
        );
      }
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        _session = await AudioSession.instance;
        await _session!.configure(const AudioSessionConfiguration.music());
        _systemSubscriptions.addAll([
          _session!.interruptionEventStream.listen((event) {
            if (event.begin) unawaited(pause());
          }, onError: _systemError),
          _session!.becomingNoisyEventStream.listen(
            (_) => unawaited(pause()),
            onError: _systemError,
          ),
        ]);
      }
    } catch (error) {
      _systemError(error);
    }
  }

  void _systemError(Object error) {
    errorCode = 'NAS_SYSTEM_MEDIA_CONTROLS_UNAVAILABLE';
    _onError?.call(errorCode!);
  }

  /// Public for deterministic command/state tests without initializing plugins.
  Future<void> bind(NasMediaPlayerService player) async {
    final epoch = ++_bindingEpoch;
    final previousSubscription = _playerSubscription;
    _playerSubscription = null;
    _player = player;
    await previousSubscription?.cancel();
    if (epoch != _bindingEpoch) return;
    _previous = null;
    _playerSubscription = player.changes.listen(
      _publish,
      onError: _systemError,
    );
    _publish(player.state, force: true);
  }

  Future<void> detach(NasMediaPlayerService player) async {
    if (!identical(_player, player)) return;
    final epoch = ++_bindingEpoch;
    final previousSubscription = _playerSubscription;
    _playerSubscription = null;
    _player = null;
    await previousSubscription?.cancel();
    if (epoch != _bindingEpoch) return;
    _publish(const NasPlayerSnapshot(), force: true);
    _onError = null;
  }

  static String _id(NasMediaItem item) => Uri(
    scheme: 'valhalla',
    host: 'nas',
    pathSegments: [
      item.serverId,
      item.path,
      if (item.playlistEntryId != null) item.playlistEntryId!,
    ],
  ).toString();

  static MediaItem _media(NasMediaItem item, {Duration? duration}) => MediaItem(
    id: _id(item),
    title: item.title?.isNotEmpty == true ? item.title! : item.name,
    artist: item.artist,
    album: item.album,
    duration: duration ?? item.duration,
    extras: {'sourceId': item.serverId, 'path': item.path},
  );

  void _publish(NasPlayerSnapshot snapshot, {bool force = false}) {
    final old = _previous;
    final current = snapshot.current;
    final queueChanged = !listEquals(old?.queue, snapshot.queue);
    final trackChanged =
        current?.serverId != old?.current?.serverId ||
        current?.path != old?.current?.path ||
        current?.playlistEntryId != old?.current?.playlistEntryId;
    final changed =
        force ||
        trackChanged ||
        queueChanged ||
        old?.playing != snapshot.playing ||
        old?.buffering != snapshot.buffering ||
        old?.error != snapshot.error ||
        old?.rate != snapshot.rate ||
        old?.shuffle != snapshot.shuffle ||
        old?.repeat != snapshot.repeat ||
        old?.duration != snapshot.duration ||
        old?.position.inSeconds != snapshot.position.inSeconds;
    if (!changed) return;
    _previous = snapshot;
    if (force || queueChanged) {
      queue.add(snapshot.queue.map(_media).toList(growable: false));
    }
    if (force ||
        trackChanged ||
        queueChanged ||
        old?.duration != snapshot.duration) {
      mediaItem.add(
        current == null
            ? null
            : _media(
                current,
                duration: snapshot.duration > Duration.zero
                    ? snapshot.duration
                    : null,
              ),
      );
    }
    playbackState.add(
      PlaybackState(
        controls: current == null
            ? const []
            : [
                MediaControl.skipToPrevious,
                snapshot.playing ? MediaControl.pause : MediaControl.play,
                MediaControl.skipToNext,
                MediaControl.stop,
              ],
        systemActions: current == null
            ? const {}
            : const {
                MediaAction.seek,
                MediaAction.seekForward,
                MediaAction.seekBackward,
              },
        androidCompactActionIndices: current == null
            ? const []
            : const [0, 1, 2],
        processingState: current == null
            ? AudioProcessingState.idle
            : snapshot.error != null
            ? AudioProcessingState.error
            : snapshot.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: current != null && snapshot.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.position,
        speed: snapshot.rate,
        queueIndex: current == null ? null : snapshot.index,
        errorCode: snapshot.error == null ? null : 1,
        errorMessage: snapshot.error,
        repeatMode: switch (snapshot.repeat) {
          NasRepeat.off => AudioServiceRepeatMode.none,
          NasRepeat.all => AudioServiceRepeatMode.all,
          NasRepeat.one => AudioServiceRepeatMode.one,
        },
        shuffleMode: snapshot.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
    if (_session != null && (force || old?.playing != snapshot.playing)) {
      unawaited(_syncFocus(snapshot.playing));
    }
    if (_windows != null) _queueWindows(snapshot);
    if (_linux != null) {
      unawaited(_linux!.publish(snapshot).catchError(_systemError));
    }
  }

  Future<void> _syncFocus(bool playing) async {
    try {
      final granted = await _session!.setActive(playing);
      if (playing && !granted) {
        await pause();
        _systemError(StateError('NAS_AUDIO_FOCUS_DENIED'));
      }
    } catch (error) {
      _systemError(error);
    }
  }

  // Keep only the newest position while an OS call is pending.
  void _queueWindows(NasPlayerSnapshot snapshot) {
    _pendingWindowsSnapshot = snapshot;
    if (_writingWindows) return;
    _writingWindows = true;
    unawaited(() async {
      try {
        while (_pendingWindowsSnapshot != null) {
          final next = _pendingWindowsSnapshot!;
          _pendingWindowsSnapshot = null;
          await _publishWindows(
            next,
            metadataChanged: _windowsItem != next.current,
          );
          _windowsItem = next.current;
        }
      } catch (error) {
        _systemError(error);
      } finally {
        _writingWindows = false;
      }
    }());
  }

  Future<void> _publishWindows(
    NasPlayerSnapshot snapshot, {
    required bool metadataChanged,
  }) async {
    final controls = _windows!;
    final current = snapshot.current;
    if (current == null) {
      await smtc.smtcUpdatePlaybackStatus(
        internal: controls,
        status: windows.PlaybackStatus.stopped,
      );
      await smtc.smtcDisableSmtc(internal: controls);
      await smtc.smtcClearMetadata(internal: controls);
      return;
    }
    if (metadataChanged) {
      await smtc.smtcUpdateMetadata(
        internal: controls,
        metadata: windows.MusicMetadata(
          title: current.title ?? current.name,
          artist: current.artist ?? '',
          album: current.album ?? '',
        ),
      );
    }
    await smtc.smtcEnableSmtc(internal: controls);
    await smtc.smtcUpdatePlaybackStatus(
      internal: controls,
      status: snapshot.playing
          ? windows.PlaybackStatus.playing
          : windows.PlaybackStatus.paused,
    );
    final end = snapshot.duration.inMilliseconds;
    await smtc.smtcUpdateTimeline(
      internal: controls,
      timeline: windows.PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: end,
        minSeekTimeMs: 0,
        maxSeekTimeMs: end,
        positionMs: snapshot.position.inMilliseconds.clamp(0, end),
      ),
    );
    await smtc.smtcUpdateShuffle(internal: controls, shuffle: snapshot.shuffle);
    await smtc.smtcUpdateRepeatMode(
      internal: controls,
      repeatMode: switch (snapshot.repeat) {
        NasRepeat.off => 'none',
        NasRepeat.one => 'track',
        NasRepeat.all => 'list',
      },
    );
  }

  Future<void> _command(
    Future<void> Function(NasMediaPlayerService) action,
  ) async {
    final player = _player;
    if (player == null) return;
    try {
      await action(player);
    } catch (error) {
      _onError?.call('NAS_PLAYBACK_COMMAND_FAILED');
    }
  }

  @override
  Future<void> play() => _command((player) => player.play());
  @override
  Future<void> pause() => _command((player) => player.pause());
  @override
  Future<void> stop() => _command((player) => player.stop());
  @override
  Future<void> skipToNext() => _command((player) => player.next());
  @override
  Future<void> skipToPrevious() => _command((player) => player.previous());
  @override
  Future<void> skipToQueueItem(int index) =>
      _command((player) => player.jumpTo(index));
  @override
  Future<void> seek(Duration position) => _command(
    (player) => player.seek(
      position < Duration.zero
          ? Duration.zero
          : player.state.duration > Duration.zero &&
                position > player.state.duration
          ? player.state.duration
          : position,
    ),
  );
  @override
  Future<void> fastForward() => seek(
    (_player?.state.position ?? Duration.zero) + const Duration(seconds: 15),
  );
  @override
  Future<void> rewind() => seek(
    (_player?.state.position ?? Duration.zero) - const Duration(seconds: 15),
  );
  @override
  Future<void> setSpeed(double speed) =>
      _command((player) => player.setRate(speed));
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async =>
      _player?.setRepeat(
        repeatMode == AudioServiceRepeatMode.one
            ? NasRepeat.one
            : repeatMode == AudioServiceRepeatMode.none
            ? NasRepeat.off
            : NasRepeat.all,
      );
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      _player?.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
}
