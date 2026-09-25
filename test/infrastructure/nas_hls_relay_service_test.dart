import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_hls_relay_service.dart';

Future<(int, HttpHeaders, List<int>)> fetch(
  Uri uri, {
  String method = 'GET',
  String? range,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    if (range != null) request.headers.set('Range', range);
    final response = await request.close();
    final body = await response.expand((chunk) => chunk).toList();
    return (response.statusCode, response.headers, body);
  } finally {
    client.close(force: true);
  }
}

void main() {
  test(
    'rewrites master, alternate audio, key, map, segments and subtitles behind opaque revocable URLs',
    () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => origin.close(force: true));
      final seen = <String>[];
      origin.listen((request) async {
        expect(request.headers.value('Authorization'), 'Bearer secret-header');
        seen.add(request.uri.path);
        if (request.uri.path.endsWith('.m3u8')) {
          request.response.headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          );
          request.response.write(
            request.uri.path == '/master.m3u8'
                ? '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Main",URI="audio.m3u8?api_key=secret-query"\n'
                      '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",URI="subs.m3u8?api_key=secret-query"\n'
                      '#EXT-X-STREAM-INF:BANDWIDTH=4000000,AUDIO="audio"\nvideo.m3u8?api_key=secret-query\n'
                : '#EXTM3U\n#EXT-X-TARGETDURATION:3\n#EXT-X-KEY:METHOD=AES-128,URI="key?api_key=secret-query"\n'
                      '#EXT-X-MAP:URI="init.mp4?api_key=secret-query"\n#EXTINF:3,\nsegment.ts?api_key=secret-query\n#EXT-X-ENDLIST\n',
          );
        } else {
          final bytes = List.generate(10, (index) => index);
          final range = request.headers.value('Range');
          if (range != null) {
            expect(range, 'bytes=2-4');
            request.response.statusCode = 206;
            request.response.headers.set('Content-Range', 'bytes 2-4/10');
            request.response.contentLength = 3;
            request.response.add(bytes.sublist(2, 5));
          } else {
            request.response.contentLength = bytes.length;
            if (request.method == 'GET') request.response.add(bytes);
          }
        }
        await request.response.close();
      });
      final relay = NasHlsRelayService();
      addTearDown(relay.dispose);
      final root = await relay.expose(
        NasResource(
          uri: Uri.parse('http://127.0.0.1:${origin.port}/master.m3u8'),
          headers: {'Authorization': 'Bearer secret-header'},
          mimeType: 'application/vnd.apple.mpegurl',
        ),
      );
      final master = utf8.decode((await fetch(root)).$3);
      expect(master, isNot(contains('secret-')));
      expect(master, isNot(contains(':${origin.port}')));
      final attrs = RegExp(
        r'URI="([^"]+)"',
      ).allMatches(master).map((m) => Uri.parse(m[1]!)).toList();
      expect(attrs.length, 2);
      final variant = Uri.parse(
        const LineSplitter()
            .convert(master)
            .firstWhere((line) => line.startsWith('http')),
      );
      for (final uri in [...attrs, variant]) {
        final manifest = utf8.decode((await fetch(uri)).$3);
        expect(manifest, isNot(contains('secret-')));
        final keysAndMaps = RegExp(
          r'URI="([^"]+)"',
        ).allMatches(manifest).map((m) => Uri.parse(m[1]!));
        for (final entry in keysAndMaps) {
          expect((await fetch(entry)).$3, List.generate(10, (i) => i));
        }
        final segment = Uri.parse(
          const LineSplitter()
              .convert(manifest)
              .firstWhere((line) => line.startsWith('http')),
        );
        final partial = await fetch(segment, range: 'bytes=2-4');
        expect(partial.$1, 206);
        expect(partial.$2.value('Content-Range'), 'bytes 2-4/10');
        expect(partial.$3, [2, 3, 4]);
        final head = await fetch(segment, method: 'HEAD');
        expect(head.$1, 200);
        expect(head.$3, isEmpty);
        expect(head.$2.contentLength, 10);
      }
      expect(
        seen,
        containsAll([
          '/audio.m3u8',
          '/subs.m3u8',
          '/video.m3u8',
          '/key',
          '/init.mp4',
          '/segment.ts',
        ]),
      );
      // Keep listener alive with another session to observe revoked-token 404.
      await relay.expose(
        NasResource(
          uri: Uri.parse('http://127.0.0.1:${origin.port}/master.m3u8'),
        ),
      );
      relay.retain(root);
      relay.revoke(root);
      expect((await fetch(variant)).$1, 404);
    },
  );

  test(
    'cross-origin children, redirects, tampered tokens and unbounded manifests fail closed',
    () async {
      var leaked = false;
      final destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      destination.listen((request) async {
        leaked = true;
        await request.response.close();
      });
      addTearDown(() => destination.close(force: true));
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => origin.close(force: true));
      origin.listen((request) async {
        if (request.uri.path == '/redirect.m3u8') {
          request.response.statusCode = 302;
          request.response.headers.set(
            'Location',
            'http://127.0.0.1:${destination.port}/evil.m3u8',
          );
        } else if (request.uri.path == '/large.m3u8') {
          request.response.write('#EXTM3U\n${'a' * (1024 * 1024)}');
        } else {
          request.response.write(
            '#EXTM3U\n#EXTINF:1,\nhttp://127.0.0.1:${destination.port}/segment.ts\n',
          );
        }
        try {
          await request.response.close();
        } catch (_) {}
      });
      final relay = NasHlsRelayService();
      addTearDown(relay.dispose);
      for (final name in ['redirect', 'child', 'large']) {
        final root = await relay.expose(
          NasResource(
            uri: Uri.parse('http://127.0.0.1:${origin.port}/$name.m3u8'),
            headers: {'Authorization': 'secret'},
          ),
        );
        expect((await fetch(root)).$1, 502);
        final pieces = root.pathSegments.toList();
        pieces[2] =
            '${pieces[2].startsWith('A') ? 'B' : 'A'}${pieces[2].substring(1)}';
        expect((await fetch(root.replace(pathSegments: pieces))).$1, 404);
      }
      expect(leaked, false);
    },
  );
}
