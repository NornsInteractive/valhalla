import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_mpris/mpris.dart';
import 'package:dbus/dbus.dart';

import 'nas_media_player_service.dart';

/// Reuses the package's generated MPRIS interface and D-Bus transport, filling
/// its missing Stop, relative Seek, Shuffle, repeat/rate and track identity.
class NasLinuxMediaControls extends OrgMprisMediaPlayer2 {
  static const playerInterface = 'org.mpris.MediaPlayer2.Player';
  final AudioHandler handler;
  final DBusClient _client;
  NasPlayerSnapshot _snapshot = const NasPlayerSnapshot();
  final String busName;

  NasLinuxMediaControls._(this.handler, this._client, this.busName)
    : super(
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
        identity: 'Valhalla',
      );

  static Future<NasLinuxMediaControls> create(
    AudioHandler handler, {
    DBusAddress? address,
  }) async {
    final client = address == null ? DBusClient.session() : DBusClient(address);
    final controls = NasLinuxMediaControls._(
      handler,
      client,
      'org.mpris.MediaPlayer2.valhalla.instance$pid',
    );
    try {
      await client.registerObject(controls);
      final reply = await client.requestName(
        controls.busName,
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply != DBusRequestNameReply.primaryOwner) {
        throw StateError('NAS_MPRIS_NAME_UNAVAILABLE');
      }
      return controls;
    } catch (_) {
      await client.close();
      rethrow;
    }
  }

  Future<void> close() => _client.close();

  String get _trackId {
    final item = _snapshot.current;
    if (item == null) return '/org/mpris/MediaPlayer2/TrackList/NoTrack';
    final bytes = utf8.encode(
      jsonEncode([item.serverId, item.path, item.playlistEntryId]),
    );
    return '/org/mpris/MediaPlayer2/track_${bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<void> publish(NasPlayerSnapshot snapshot) async {
    final previous = _snapshot;
    _snapshot = snapshot;
    position = snapshot.position;
    playbackState = snapshot.current == null
        ? 'Stopped'
        : snapshot.playing
        ? 'Playing'
        : 'Paused';
    await emitPropertiesChanged(
      playerInterface,
      changedProperties: {
        if (!identical(previous.current, snapshot.current) ||
            previous.duration != snapshot.duration)
          'Metadata': getMetadata(),
        'LoopStatus': getLoopStatus(),
        'Shuffle': DBusBoolean(snapshot.shuffle),
        'Rate': getRate(),
        'CanControl': getCanControl(),
        'CanPlay': getCanPlay(),
        'CanPause': getCanPause(),
        'CanSeek': getCanSeek(),
        'CanGoNext': getCanGoNext(),
        'CanGoPrevious': getCanGoPrevious(),
      },
    );
  }

  Future<DBusMethodResponse> _command(Future<void> Function() action) async {
    try {
      await action();
      return DBusMethodSuccessResponse([]);
    } catch (_) {
      return DBusMethodErrorResponse('org.mpris.MediaPlayer2.Error.Failed');
    }
  }

  @override
  Future<DBusMethodResponse> doPlay() => _command(handler.play);
  @override
  Future<DBusMethodResponse> doPause() => _command(handler.pause);
  @override
  Future<DBusMethodResponse> doStop() => _command(handler.stop);
  @override
  Future<DBusMethodResponse> doNext() => _command(handler.skipToNext);
  @override
  Future<DBusMethodResponse> doPrevious() => _command(handler.skipToPrevious);
  @override
  Future<DBusMethodResponse> doPlayPause() =>
      _snapshot.playing ? doPause() : doPlay();
  @override
  Future<DBusMethodResponse> doSeek(int offset) => _command(() async {
    final target = _clamp(position + Duration(microseconds: offset));
    await handler.seek(target);
    await emitSeeked(target);
  });
  @override
  Future<DBusMethodResponse> doSetPosition(String trackId, int position) =>
      _command(() async {
        if (trackId != _trackId || position < 0) return;
        final target = Duration(microseconds: position);
        if (_snapshot.duration > Duration.zero && target > _snapshot.duration) {
          return;
        }
        await handler.seek(target);
        await emitSeeked(target);
      });

  Duration _clamp(Duration value) => value < Duration.zero
      ? Duration.zero
      : _snapshot.duration > Duration.zero && value > _snapshot.duration
      ? _snapshot.duration
      : value;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) {
    // Upstream calls ObjectPath.toString(), which yields a debug wrapper.
    if (methodCall.interface == playerInterface &&
        methodCall.name == 'SetPosition') {
      if (methodCall.signature != DBusSignature('ox')) {
        return Future.value(DBusMethodErrorResponse.invalidArgs());
      }
      return doSetPosition(
        methodCall.values[0].asObjectPath().value,
        methodCall.values[1].asInt64(),
      );
    }
    return super.handleMethodCall(methodCall);
  }

  @override
  Future<DBusMethodResponse> doOpenUri(String uri) async =>
      DBusMethodErrorResponse.notSupported();
  @override
  DBusBoolean getCanControl() => DBusBoolean(_snapshot.current != null);
  @override
  DBusBoolean getCanPlay() => getCanControl();
  @override
  DBusBoolean getCanPause() => getCanControl();
  @override
  DBusBoolean getCanSeek() => getCanControl();
  @override
  DBusBoolean getCanGoNext() => getCanControl();
  @override
  DBusBoolean getCanGoPrevious() => getCanControl();
  @override
  DBusDouble getMinimumRate() => const DBusDouble(0.25);
  @override
  DBusDouble getMaximumRate() => const DBusDouble(4);
  @override
  DBusDouble getRate() => DBusDouble(_snapshot.rate);
  @override
  Future<DBusMethodResponse> setRate(double value) =>
      value.isFinite && value >= 0.25 && value <= 4
      ? _command(() => handler.setSpeed(value))
      : Future.value(DBusMethodErrorResponse.invalidArgs());
  @override
  DBusString getLoopStatus() => DBusString(switch (_snapshot.repeat) {
    NasRepeat.off => 'None',
    NasRepeat.one => 'Track',
    NasRepeat.all => 'Playlist',
  });
  @override
  Future<DBusMethodResponse> setLoopStatus(String value) =>
      const ['None', 'Track', 'Playlist'].contains(value)
      ? _command(
          () => handler.setRepeatMode(switch (value) {
            'Track' => AudioServiceRepeatMode.one,
            'Playlist' => AudioServiceRepeatMode.all,
            _ => AudioServiceRepeatMode.none,
          }),
        )
      : Future.value(DBusMethodErrorResponse.invalidArgs());
  @override
  Future<DBusMethodResponse> setVolume(double value) async =>
      DBusMethodErrorResponse.notSupported();

  @override
  DBusValue getMetadata() {
    final item = _snapshot.current;
    return DBusDict.stringVariant({
      'mpris:trackid': DBusObjectPath(_trackId),
      if (item != null) ...{
        'xesam:title': DBusString(item.title ?? item.name),
        if (item.artist != null)
          'xesam:artist': DBusArray.string([item.artist!]),
        if (item.album != null) 'xesam:album': DBusString(item.album!),
        if (item.trackNumber != null)
          'xesam:trackNumber': DBusInt32(item.trackNumber!),
        'mpris:length': DBusInt64(
          (_snapshot.duration > Duration.zero
                  ? _snapshot.duration
                  : item.duration ?? Duration.zero)
              .inMicroseconds,
        ),
      },
    });
  }

  @override
  List<DBusIntrospectInterface> introspect() => super
      .introspect()
      .map(
        (entry) => entry.name != playerInterface
            ? entry
            : DBusIntrospectInterface(
                entry.name,
                methods: entry.methods,
                signals: entry.signals,
                properties: [
                  ...entry.properties,
                  DBusIntrospectProperty(
                    'Shuffle',
                    DBusSignature('b'),
                    access: DBusPropertyAccess.readwrite,
                  ),
                ],
              ),
      )
      .toList();
  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async =>
      interface == playerInterface && name == 'Shuffle'
      ? DBusMethodSuccessResponse([DBusVariant(DBusBoolean(_snapshot.shuffle))])
      : super.getProperty(interface, name);
  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final response = await super.getAllProperties(interface);
    if (interface != playerInterface) return response;
    return DBusMethodSuccessResponse([
      DBusDict.stringVariant({
        ...response.returnValues.single.asStringVariantDict(),
        'Shuffle': DBusBoolean(_snapshot.shuffle),
      }),
    ]);
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) => interface == playerInterface && name == 'Shuffle'
      ? value is DBusBoolean
            ? _command(
                () => handler.setShuffleMode(
                  value.value
                      ? AudioServiceShuffleMode.all
                      : AudioServiceShuffleMode.none,
                ),
              )
            : Future.value(DBusMethodErrorResponse.invalidArgs())
      : super.setProperty(interface, name, value);
}
