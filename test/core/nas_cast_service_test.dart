import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:upnp_client/upnp_client.dart';
import 'package:valhalla/core/services/nas_cast_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_media_proxy_service.dart';
import 'package:valhalla/infrastructure/nas/nas_hls_relay_service.dart';
import 'package:xml/xml.dart';

class _Adapter extends NasSourceAdapter {
  @override
  final source = const NasSource(
    id: 'source',
    name: 'Files',
    type: NasSourceType.sftp,
  );
  NasResource resource = NasResource(
    read: (_, _, _) => Stream.value([1, 2, 3]),
    sizeBytes: 3,
  );
  final events = <String>[];
  @override
  Future<void> reportPlayback(
    NasMediaItem item,
    Duration position, {
    required String event,
    bool paused = false,
    String? playSessionId,
  }) async {
    events.add(event);
  }

  @override
  Future<void> probe() async {}
  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async => resource;
  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) => const Stream.empty();
}

class _Proxy implements NasMediaProxyService {
  final entries = <Uri, NasResource>{};
  final revoked = <Uri>[];
  InternetAddress? bound;
  int retained = 0;
  @override
  Future<Uri> exposeResource(
    NasMediaItem item,
    NasResource resource, {
    InternetAddress? address,
  }) async {
    bound = address;
    final uri = Uri.parse(
      'http://${address!.address}:12345/media/secret/${item.name}',
    );
    entries[uri] = resource;
    return uri;
  }

  @override
  void revoke(Uri uri) {
    revoked.add(uri);
    entries.remove(uri);
  }

  @override
  void retain(Uri uri) {
    retained++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Discovery extends DeviceDiscoverer {
  final List<Device> fixture;
  bool disposed = false;
  String? target;
  _Discovery(this.fixture);
  @override
  Future<void> start({
    int port = 0,
    int multicastHops = 2,
    List<InternetAddressType> addressTypes = const [],
  }) async {}
  @override
  Future<List<Device>> getDevices({
    Duration timeout = const Duration(seconds: 5),
    String? searchTarget,
  }) async {
    target = searchTarget;
    return fixture;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _HlsProxy extends NasHlsRelayService {
  NasResource? resource;
  Uri? revoked;
  @override
  Future<Uri> expose(NasResource resource, {InternetAddress? address}) async {
    this.resource = resource;
    return Uri.parse('http://${address!.address}:54321/hls/opaque/index.m3u8');
  }

  @override
  void retain(Uri uri) {}
  @override
  void revoke(Uri uri) {
    revoked = uri;
  }
}

class _RendererFixture {
  late final HttpServer server;
  late final NasCastDevice device;
  final actions = <String>[];
  final arguments = <String, Map<String, String>>{};
  var sink =
      'http-get:*:audio/mpeg:*,http-get:*:image/jpeg:*,http-get:*:video/mp4:*';
  var playing = false;
  String? failAction;
  Future<void> open() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final services = ['AVTransport', 'RenderingControl', 'ConnectionManager']
        .map(
          (name) =>
              '<service><serviceType>urn:schemas-upnp-org:service:$name:1</serviceType>'
              '<serviceId>urn:upnp-org:serviceId:$name</serviceId><controlURL>/$name</controlURL>'
              '<SCPDURL>/$name.xml</SCPDURL><eventSubURL>/$name/event</eventSubURL></service>',
        )
        .join();
    final xml = XmlDocument.parse(
      '<device><deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>'
      '<friendlyName>Fixture TV</friendlyName><UDN>uuid:tv1</UDN><serviceList>$services</serviceList></device>',
    );
    device = NasCastDevice(
      Device.fromXmlTyped(
            xml.rootElement,
            'http://127.0.0.1:${server.port}/description.xml',
          )
          as MediaRenderer,
    );
    server.listen((request) async {
      final body = XmlDocument.parse(await utf8.decoder.bind(request).join());
      final action = body.descendants
          .whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'Body')
          .childElements
          .single;
      final name = action.name.local;
      actions.add(name);
      arguments[name] = {
        for (final arg in action.childElements) arg.name.local: arg.innerText,
      };
      if (name == failAction) {
        request.response.statusCode = 500;
        request.response.write(
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>'
          '<detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>714</errorCode><errorDescription>Illegal MIME-type</errorDescription>'
          '</UPnPError></detail></s:Fault></s:Body></s:Envelope>',
        );
      } else {
        if (name == 'Play') playing = true;
        if (name == 'Pause' || name == 'Stop') playing = false;
        final args = switch (name) {
          'GetProtocolInfo' => {'Sink': sink, 'Source': ''},
          'GetTransportInfo' => {
            'CurrentTransportState': playing ? 'PLAYING' : 'PAUSED_PLAYBACK',
            'CurrentTransportStatus': 'OK',
            'CurrentSpeed': '1',
          },
          'GetPositionInfo' => {
            'Track': '1',
            'TrackDuration': '00:05:00',
            'RelTime': '00:00:12',
            'AbsTime': '00:00:12',
            'RelCount': '0',
            'AbsCount': '0',
          },
          'GetVolume' => {'CurrentVolume': '35'},
          _ => <String, String>{},
        };
        final builder = XmlBuilder();
        builder.element(
          's:Envelope',
          attributes: {'xmlns:s': 'http://schemas.xmlsoap.org/soap/envelope/'},
          nest: () {
            builder.element(
              's:Body',
              nest: () {
                builder.element(
                  'u:${name}Response',
                  attributes: {'xmlns:u': action.namespaceUri!},
                  nest: () {
                    for (final arg in args.entries) {
                      builder.element(arg.key, nest: arg.value);
                    }
                  },
                );
              },
            );
          },
        );
        request.response.write(builder.buildDocument().toXmlString());
      }
      await request.response.close();
    });
  }

  Future<void> close() => server.close(force: true);
}

const _song = NasMediaItem(
  serverId: 'source',
  path: '/music/song.mp3',
  kind: NasMediaKind.audio,
  sizeBytes: 3,
  modifiedEpoch: 0,
  title: 'A & B',
  durationMillis: 300000,
);

void main() {
  late _RendererFixture tv;
  late _Adapter adapter;
  late _Proxy proxy;
  late NasCastService service;
  setUp(() async {
    tv = _RendererFixture();
    await tv.open();
    adapter = _Adapter();
    proxy = _Proxy();
    service = NasCastService(
      adapterFor: (_) async => adapter,
      proxy: proxy,
      addressFor: (_) async => InternetAddress('192.0.2.10'),
      pollInterval: const Duration(hours: 1),
    );
  });
  tearDown(() async {
    await service.dispose();
    await tv.close();
  });

  test(
    'SSDP renderer profiles are deduplicated and discovery resources released',
    () async {
      final discovery = _Discovery([tv.device.renderer, tv.device.renderer]);
      final cast = NasCastService(
        adapterFor: (_) async => adapter,
        proxy: proxy,
        discovererFactory: () => discovery,
      );
      addTearDown(cast.dispose);
      await cast.discover();
      expect(cast.state.devices.single.name, 'Fixture TV');
      expect(discovery.target, 'urn:schemas-upnp-org:device:MediaRenderer:1');
      expect(discovery.disposed, true);
      expect(cast.state.discovering, false);
    },
  );

  test(
    'authenticated source uses a scoped LAN relay and SOAP controls update state',
    () async {
      await service.start(tv.device, _song);
      expect(service.state.error, null);
      expect(service.state.playing, true);
      expect(service.state.isRelaying, true);
      expect(service.state.position, const Duration(seconds: 12));
      expect(service.state.duration, const Duration(minutes: 5));
      expect(service.state.volume, .35);
      expect(proxy.bound!.address, '192.0.2.10');
      expect(
        tv.arguments['SetAVTransportURI']!['CurrentURI'],
        startsWith('http://192.0.2.10:'),
      );
      final metadata =
          tv.arguments['SetAVTransportURI']!['CurrentURIMetaData']!;
      expect(
        XmlDocument.parse(metadata).descendants
            .whereType<XmlElement>()
            .firstWhere((e) => e.name.local == 'title')
            .innerText,
        'A & B',
      );
      await service.pause();
      expect(service.state.playing, false);
      await service.play();
      expect(service.state.playing, true);
      await service.seek(const Duration(seconds: 63));
      expect(tv.arguments['Seek']!['Unit'], 'REL_TIME');
      expect(tv.arguments['Seek']!['Target'], '00:01:03');
      await service.setVolume(.7);
      expect(tv.arguments['SetVolume']!['DesiredVolume'], '70');
      await service.stop();
      expect(proxy.entries, isEmpty);
      expect(proxy.revoked.length, 1);
      expect(service.state.activeDevice, null);
      expect(tv.actions.last, 'Stop');
      expect(adapter.events.first, 'start');
      expect(adapter.events.last, 'stop');
      expect(adapter.events, contains('progress'));
    },
  );

  test(
    'public direct URL avoids relay; images carry the photo DIDL class',
    () async {
      adapter.resource = NasResource(
        uri: Uri.parse('http://192.0.2.11/picture.jpg'),
        mimeType: 'image/jpeg',
      );
      await service.start(
        tv.device,
        const NasMediaItem(
          serverId: 'source',
          path: '/picture.jpg',
          kind: NasMediaKind.image,
          sizeBytes: 3,
          modifiedEpoch: 0,
        ),
      );
      expect(service.state.error, null);
      expect(proxy.entries, isEmpty);
      expect(
        tv.arguments['SetAVTransportURI']!['CurrentURI'],
        'http://192.0.2.11/picture.jpg',
      );
      expect(
        tv.arguments['SetAVTransportURI']!['CurrentURIMetaData'],
        contains('object.item.imageItem.photo'),
      );
    },
  );

  test(
    'positive codec mismatch and SOAP failure never claim playback',
    () async {
      tv.sink = 'http-get:*:image/png:*';
      await service.start(tv.device, _song);
      expect(service.state.error, 'NAS_CAST_FORMAT_UNSUPPORTED');
      expect(service.state.playing, false);
      expect(tv.actions, isNot(contains('SetAVTransportURI')));
      tv.sink = 'http-get:*:audio/mpeg:*';
      tv.failAction = 'Play';
      await service.start(tv.device, _song);
      expect(service.state.error, 'NAS_CAST_UPNP_714');
      expect(service.state.playing, false);
      expect(proxy.entries, isEmpty);
    },
  );

  test(
    'authenticated HLS uses a safe LAN playlist relay and loopback routes fail',
    () async {
      adapter.resource = NasResource(
        uri: Uri.parse('http://192.0.2.11/master.m3u8'),
        headers: {'Authorization': 'secret'},
        mimeType: 'application/vnd.apple.mpegurl',
      );
      tv.sink = '*:*:*:*';
      final hls = _HlsProxy();
      final cast = NasCastService(
        adapterFor: (_) async => adapter,
        proxy: proxy,
        hlsRelay: hls,
        addressFor: (_) async => InternetAddress('192.0.2.10'),
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cast.dispose);
      await cast.start(tv.device, _song);
      expect(cast.state.error, null);
      expect(cast.state.isRelaying, true);
      expect(hls.resource!.headers['Authorization'], 'secret');
      expect(
        tv.arguments['SetAVTransportURI']!['CurrentURI'],
        'http://192.0.2.10:54321/hls/opaque/index.m3u8',
      );
      await cast.stop();
      expect(hls.revoked, isNotNull);
      await expectLater(
        NasCastService.routeAddressFor(Uri.parse('http://127.0.0.1:8096')),
        throwsStateError,
      );
    },
  );
}
