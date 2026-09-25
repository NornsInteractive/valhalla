import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:upnp_client/didl.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:xml/xml.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../infrastructure/nas/nas_media_proxy_service.dart';
import '../../infrastructure/nas/nas_hls_relay_service.dart';

class NasCastDevice {
  final MediaRenderer renderer;
  NasCastDevice(this.renderer);
  String get id => renderer.description?.uuid ?? renderer.url ?? '';
  String get name => renderer.description?.friendlyName ?? location.host;
  Uri get location => Uri.parse(renderer.url ?? renderer.urlBase ?? '');
}

class NasCastState {
  final List<NasCastDevice> devices;
  final bool discovering;
  final NasCastDevice? activeDevice;
  final NasMediaItem? item;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final double volume;
  final String? error;
  final bool isRelaying;
  const NasCastState({
    this.devices = const [],
    this.discovering = false,
    this.activeDevice,
    this.item,
    this.position = Duration.zero,
    this.duration,
    this.playing = false,
    this.volume = 1,
    this.error,
    this.isRelaying = false,
  });
  NasCastState copyWith({
    List<NasCastDevice>? devices,
    bool? discovering,
    NasCastDevice? activeDevice,
    NasMediaItem? item,
    Duration? position,
    Duration? duration,
    bool? playing,
    double? volume,
    String? error,
    bool? isRelaying,
    bool clearSession = false,
  }) => NasCastState(
    devices: devices ?? this.devices,
    discovering: discovering ?? this.discovering,
    activeDevice: clearSession ? null : activeDevice ?? this.activeDevice,
    item: clearSession ? null : item ?? this.item,
    position: clearSession ? Duration.zero : position ?? this.position,
    duration: clearSession ? null : duration ?? this.duration,
    playing: clearSession ? false : playing ?? this.playing,
    volume: volume ?? this.volume,
    error: error,
    isRelaying: clearSession ? false : isRelaying ?? this.isRelaying,
  );
}

/// A foreground DLNA controller. UPnP SOAP and SSDP are handled by upnp_client.
/// Mobile OS suspension can interrupt relays; it is not a background server.
class NasCastService {
  final Future<NasSourceAdapter> Function(String) adapterFor;
  final NasMediaProxyService proxy;
  final NasHlsRelayService _hls;
  final bool _ownsHls;
  final DeviceDiscoverer Function() _discovererFactory;
  final Future<InternetAddress> Function(Uri) _addressFor;
  final Duration pollInterval;
  static const _network = MethodChannel('valhalla/nas_network');
  final _changes = StreamController<NasCastState>.broadcast();
  NasCastState _state = const NasCastState();
  NasCastState get state => _state;
  Stream<NasCastState> get changes => _changes.stream;
  DeviceDiscoverer? _discoverer;
  Uri? _relay;
  bool _relayHls = false;
  Timer? _poll;
  bool _polling = false;
  bool _disposed = false;
  int _epoch = 0;
  int _pollFailures = 0;
  Future<void> _operations = Future.value();
  NasSourceAdapter? _adapter;
  String? _playSessionId;
  DateTime? _lastReported;

  NasCastService({
    required this.adapterFor,
    required this.proxy,
    NasHlsRelayService? hlsRelay,
    DeviceDiscoverer Function()? discovererFactory,
    Future<InternetAddress> Function(Uri)? addressFor,
    this.pollInterval = const Duration(seconds: 2),
  }) : _hls = hlsRelay ?? NasHlsRelayService(),
       _ownsHls = hlsRelay == null,
       _discovererFactory = discovererFactory ?? DeviceDiscoverer.new,
       _addressFor = addressFor ?? routeAddressFor;

  void _set(NasCastState state) {
    if (_disposed) return;
    _state = state;
    _changes.add(state);
  }

  void _failure(Object error) {
    final code = error is UPnPException
        ? 'NAS_CAST_UPNP_${error.errorCode}'
        : error is StateError &&
              error.message.toString().startsWith('NAS_CAST_')
        ? error.message.toString()
        : 'NAS_CAST_CONNECTION_FAILED';
    _set(_state.copyWith(error: code));
  }

  Future<void> discover() async {
    if (_disposed || _state.discovering) return;
    _set(_state.copyWith(discovering: true));
    final discoverer = _discovererFactory();
    _discoverer = discoverer;
    StreamSubscription<Never>? errors;
    try {
      if (Platform.isAndroid) {
        await _network.invokeMethod<void>('acquireMulticast');
      }
      // Malformed individual announcements must not fail the entire search.
      errors = discoverer.errors.listen(null, onError: (Object _) {});
      await discoverer.start(addressTypes: [InternetAddressType.IPv4]);
      final devices = await discoverer.getDevices(
        searchTarget: UpnpDeviceType.mediaRenderer.urn(),
        timeout: const Duration(seconds: 5),
      );
      final renderers = <String, NasCastDevice>{};
      for (final renderer in devices.whereType<MediaRenderer>()) {
        final device = NasCastDevice(renderer);
        if (renderer.avTransport != null &&
            device.id.isNotEmpty &&
            {'http', 'https'}.contains(device.location.scheme) &&
            device.location.host.isNotEmpty) {
          renderers[device.id] = device;
        }
      }
      _set(
        _state.copyWith(
          devices: renderers.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        ),
      );
    } catch (error) {
      _failure(error);
    } finally {
      await errors?.cancel();
      discoverer.dispose();
      if (identical(_discoverer, discoverer)) _discoverer = null;
      if (Platform.isAndroid) {
        try {
          await _network.invokeMethod<void>('releaseMulticast');
        } catch (_) {}
      }
      _set(_state.copyWith(discovering: false, error: _state.error));
    }
  }

  Future<void> start(
    NasCastDevice device,
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) {
    if (_disposed) return Future.value();
    final epoch = ++_epoch;
    return _enqueue(() => _start(device, item, quality, epoch));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final pending = _operations.then((_) => operation());
    _operations = pending.catchError((Object error) {
      _failure(error);
    });
    return _operations;
  }

  Future<void> _start(
    NasCastDevice device,
    NasMediaItem item,
    NasPlaybackQuality quality,
    int epoch,
  ) async {
    if (_disposed || epoch != _epoch) return;
    await _stopSession();
    if (_disposed || epoch != _epoch) return;
    Uri? createdRelay;
    var createdHls = false;
    void revokeCreated() {
      if (createdRelay case final uri?) {
        if (createdHls) {
          _hls.revoke(uri);
        } else {
          proxy.revoke(uri);
        }
      }
    }

    try {
      final transport = device.renderer.avTransport;
      if (transport == null) throw StateError('NAS_CAST_TRANSPORT_UNAVAILABLE');
      final adapter = await adapterFor(item.serverId);
      final resource = await adapter.resolve(item, quality: quality);
      if (_disposed || epoch != _epoch) return;
      final mime = _mime(item, resource);
      if (device.renderer.connectionManager case final manager?) {
        final formats = await manager.getProtocolInfo();
        if (formats.sink.isNotEmpty &&
            !formats.sink.any(
              (info) =>
                  (info.protocol == 'http-get' || info.protocol == '*') &&
                  (info.contentFormat == '*' ||
                      info.contentFormat.toLowerCase() == mime.toLowerCase()),
            )) {
          throw StateError('NAS_CAST_FORMAT_UNSUPPORTED');
        }
      }
      Uri uri;
      if (resource.uri != null &&
          resource.headers.isEmpty &&
          await _publicMediaUri(resource.uri!)) {
        uri = resource.uri!;
      } else {
        final address = await _addressFor(device.location);
        if (address.isLoopback ||
            address.isMulticast ||
            address.address == '0.0.0.0') {
          throw StateError('NAS_CAST_NO_LAN_INTERFACE');
        }
        createdHls =
            mime.contains('mpegurl') ||
            resource.uri?.path.endsWith('.m3u8') == true;
        uri = createdHls
            ? await _hls.expose(resource, address: address)
            : await proxy.exposeResource(
                item,
                NasResource(
                  uri: resource.uri,
                  headers: resource.headers,
                  read: resource.read,
                  sizeBytes: resource.sizeBytes,
                  mimeType: mime,
                  playSessionId: resource.playSessionId,
                  seekable: resource.seekable,
                ),
                address: address,
              );
        createdRelay = uri;
      }
      if (_disposed || epoch != _epoch) {
        revokeCreated();
        return;
      }
      await transport.setAVTransportURI(
        uri.toString(),
        metadata: _metadata(item, uri, mime),
      );
      if (_disposed || epoch != _epoch) {
        revokeCreated();
        return;
      }
      await transport.play();
      if (_disposed || epoch != _epoch) {
        // Starts/stops are serialized, so no newer session can own this
        // renderer yet. Undo a Play that completed after a stop request.
        try {
          await transport.stop();
        } catch (_) {}
        revokeCreated();
        return;
      }
      _relay = createdRelay;
      _relayHls = createdHls;
      _adapter = adapter;
      _playSessionId = resource.playSessionId;
      _pollFailures = 0;
      _set(
        _state.copyWith(
          activeDevice: device,
          item: item,
          duration: item.duration,
          position: Duration.zero,
          playing: true,
          isRelaying: createdRelay != null,
        ),
      );
      _poll = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
      await _report('start');
      await refresh();
    } catch (error) {
      revokeCreated();
      if (epoch == _epoch) _failure(error);
    }
  }

  Future<void> play() =>
      _enqueue(() => _command((transport) => transport.play(), playing: true));
  Future<void> pause() => _enqueue(
    () => _command((transport) => transport.pause(), playing: false),
  );
  Future<void> seek(Duration position) => _enqueue(
    () => _command((transport) {
      if (position.isNegative) throw StateError('NAS_CAST_INVALID_POSITION');
      return transport.seek(SeekMode.relTime, _time(position));
    }, position: position),
  );
  Future<void> _command(
    Future<void> Function(AvTransportService) operation, {
    bool? playing,
    Duration? position,
  }) async {
    final transport = _state.activeDevice?.renderer.avTransport;
    if (_disposed || transport == null) return;
    final epoch = _epoch;
    try {
      await operation(transport);
      if (epoch == _epoch) {
        _set(_state.copyWith(playing: playing, position: position));
        await _report('progress');
      }
    } catch (error) {
      if (epoch == _epoch) _failure(error);
    }
  }

  Future<void> setVolume(double volume) async {
    final control = _state.activeDevice?.renderer.renderingControl;
    if (_disposed) return;
    final epoch = _epoch;
    try {
      if (control == null) throw StateError('NAS_CAST_VOLUME_UNAVAILABLE');
      if (!volume.isFinite || volume < 0 || volume > 1) {
        throw StateError('NAS_CAST_INVALID_VOLUME');
      }
      await control.setVolume(volume: (volume * 100).round());
      if (epoch == _epoch) _set(_state.copyWith(volume: volume));
    } catch (error) {
      if (epoch == _epoch) _failure(error);
    }
  }

  Future<void> refresh() async {
    final device = _state.activeDevice;
    if (_disposed || _polling || device == null) return;
    final epoch = _epoch;
    _polling = true;
    try {
      if (_relay case final uri?) {
        if (_relayHls) {
          _hls.retain(uri);
        } else {
          proxy.retain(uri);
        }
      }
      final transport = await device.renderer.avTransport!.getTransportInfo();
      final position = await device.renderer.avTransport!.getPositionInfo();
      if (epoch != _epoch || _disposed) return;
      if (transport.currentTransportStatus == TransportStatus.errorOccurred) {
        throw StateError('NAS_CAST_PLAYBACK_FAILED');
      }
      _pollFailures = 0;
      final stopped =
          transport.currentTransportState == TransportState.stopped ||
          transport.currentTransportState == TransportState.noMediaPresent;
      _set(
        _state.copyWith(
          playing: transport.currentTransportState == TransportState.playing,
          position: _duration(position.relTime),
          duration: _duration(position.trackDuration),
        ),
      );
      if (stopped && _state.item?.kind != NasMediaKind.image) {
        await _report('stop');
        _adapter = null;
        _releaseRelay();
        _poll?.cancel();
        _set(_state.copyWith(clearSession: true, error: _state.error));
        return;
      }
      if (_lastReported == null ||
          DateTime.now().difference(_lastReported!) >=
              const Duration(seconds: 15)) {
        await _report('progress');
      }
      if (device.renderer.renderingControl case final control?) {
        try {
          final volume = await control.getVolume();
          if (epoch == _epoch && volume >= 0 && volume <= 100) {
            _set(_state.copyWith(volume: volume / 100));
          }
        } catch (_) {
          /* Volume is optional on some renderers. */
        }
      }
    } catch (error) {
      if (epoch == _epoch) {
        _failure(error);
        if (++_pollFailures >= 3) {
          await _report('stop');
          _adapter = null;
          _releaseRelay();
          _poll?.cancel();
          _set(_state.copyWith(clearSession: true, error: _state.error));
        }
      }
    } finally {
      _polling = false;
    }
  }

  void _releaseRelay() {
    if (_relay case final uri?) {
      if (_relayHls) {
        _hls.revoke(uri);
      } else {
        proxy.revoke(uri);
      }
    }
    _relay = null;
    _relayHls = false;
    if (_state.isRelaying) {
      _set(_state.copyWith(isRelaying: false, error: _state.error));
    }
  }

  Future<void> _report(String event) async {
    final adapter = _adapter, item = _state.item;
    if (adapter == null || item == null) return;
    final epoch = _epoch;
    _lastReported = DateTime.now();
    try {
      await adapter.reportPlayback(
        item,
        _state.position,
        event: event,
        paused: !_state.playing,
        playSessionId: _playSessionId,
      );
    } catch (_) {
      if (epoch == _epoch) {
        _set(_state.copyWith(error: 'NAS_CAST_HISTORY_SYNC_FAILED'));
      }
    }
  }

  Future<void> stop() {
    ++_epoch;
    _poll?.cancel();
    return _enqueue(_stopSession);
  }

  Future<void> _stopSession() async {
    final device = _state.activeDevice;
    _poll?.cancel();
    _poll = null;
    await _report('stop');
    _adapter = null;
    _playSessionId = null;
    _lastReported = null;
    _releaseRelay();
    _set(_state.copyWith(clearSession: true));
    if (device != null) {
      try {
        await device.renderer.avTransport?.stop();
      } catch (error) {
        _failure(error);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _discoverer?.stop();
    if (_ownsHls) await _hls.dispose();
    await _changes.close();
  }

  static Future<bool> _publicMediaUri(Uri uri) async {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty) {
      return false;
    }
    if (uri.queryParameters.keys.any(
      (key) => {
        'api_key',
        'access_token',
        'token',
        'password',
      }.contains(key.toLowerCase()),
    )) {
      return false;
    }
    final addresses = await InternetAddress.lookup(
      uri.host,
      type: InternetAddressType.IPv4,
    );
    return addresses.isNotEmpty &&
        addresses.every(
          (address) =>
              !address.isLoopback &&
              !address.isMulticast &&
              address.address != '0.0.0.0',
        );
  }

  /// Bind candidate LAN addresses and connect to the receiver to verify the
  /// route. This avoids mistaking Socket.address (remote) for a local address.
  static Future<InternetAddress> routeAddressFor(Uri receiver) async {
    if (!{'http', 'https'}.contains(receiver.scheme) || receiver.host.isEmpty) {
      throw StateError('NAS_CAST_INVALID_DEVICE');
    }
    final targets = await InternetAddress.lookup(
      receiver.host,
      type: InternetAddressType.IPv4,
    );
    if (targets.isEmpty ||
        targets.any(
          (a) => a.isLoopback || a.isMulticast || a.address == '0.0.0.0',
        )) {
      throw StateError('NAS_CAST_NO_LAN_INTERFACE');
    }
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final candidates = interfaces
        .expand((i) => i.addresses)
        .where((a) => !a.isLoopback && !a.isMulticast && a.address != '0.0.0.0')
        .toList();
    int score(InternetAddress address) {
      var shared = 0;
      for (var i = 0; i < 4; i++) {
        if (address.rawAddress[i] != targets.first.rawAddress[i]) break;
        shared++;
      }
      return shared;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    for (final candidate in candidates) {
      try {
        final socket = await Socket.connect(
          targets.first,
          receiver.port,
          sourceAddress: candidate,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        return candidate;
      } on SocketException {
        continue;
      }
    }
    throw StateError('NAS_CAST_NO_LAN_INTERFACE');
  }

  static String _mime(NasMediaItem item, NasResource resource) {
    if (resource.mimeType != 'application/octet-stream') {
      return resource.mimeType;
    }
    final extension = (item.sourcePath ?? item.path)
        .split('.')
        .last
        .toLowerCase();
    return const {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'gif': 'image/gif',
          'webp': 'image/webp',
          'mp4': 'video/mp4',
          'm4v': 'video/mp4',
          'mkv': 'video/x-matroska',
          'mov': 'video/quicktime',
          'ts': 'video/mp2t',
          'mp3': 'audio/mpeg',
          'm4a': 'audio/mp4',
          'aac': 'audio/aac',
          'flac': 'audio/flac',
          'wav': 'audio/wav',
          'ogg': 'audio/ogg',
        }[extension] ??
        'application/octet-stream';
  }

  static String _time(Duration value) =>
      '${value.inHours.toString().padLeft(2, '0')}:'
      '${(value.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  static Duration? _duration(String? value) {
    final match = RegExp(
      r'^(\d+):(\d{2}):(\d{2})(?:\.(\d+))?$',
    ).firstMatch(value ?? '');
    if (match == null) return null;
    final minutes = int.parse(match[2]!), seconds = int.parse(match[3]!);
    if (minutes >= 60 || seconds >= 60) return null;
    return Duration(
      hours: int.parse(match[1]!),
      minutes: minutes,
      seconds: seconds,
    );
  }

  static String _metadata(NasMediaItem item, Uri uri, String mime) {
    if (item.kind == NasMediaKind.audio) {
      return MusicTrack(
        id: item.path,
        uri: uri.toString(),
        title: item.title ?? item.name,
        artist: item.artist,
        album: item.album ?? '',
        duration: item.duration ?? Duration.zero,
        artUri: null,
        protocolInfo: 'http-get:*:$mime:*',
      ).toXml();
    }
    final builder = XmlBuilder();
    builder.element(
      'DIDL-Lite',
      attributes: {
        'xmlns': 'urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/',
        'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
        'xmlns:upnp': 'urn:schemas-upnp-org:metadata-1-0/upnp/',
      },
      nest: () {
        builder.element(
          'item',
          attributes: {'id': item.path, 'parentID': '0', 'restricted': '1'},
          nest: () {
            builder.element('dc:title', nest: item.title ?? item.name);
            builder.element(
              'upnp:class',
              nest: item.kind == NasMediaKind.image
                  ? 'object.item.imageItem.photo'
                  : 'object.item.videoItem',
            );
            builder.element(
              'res',
              attributes: {
                'protocolInfo': 'http-get:*:$mime:*',
                if (item.duration != null) 'duration': _time(item.duration!),
              },
              nest: uri.toString(),
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }
}
