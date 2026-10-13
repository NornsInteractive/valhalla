import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';

Future<HttpServer> _serve(FutureOr<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } finally {
      await request.response.close();
    }
  });
  addTearDown(() => server.close(force: true));
  return server;
}

Uri _endpoint(HttpServer server) =>
    Uri.parse('http://127.0.0.1:${server.port}/file.bin');

Future<List<int>> _readAll(NasResource resource, int start, int? end) =>
    resource.read!(start, end, NasCancellation()).expand((c) => c).toList();

void main() {
  setUp(() => HttpOverrides.global = null);

  test('HEAD strong ETag supplies the version and size', () async {
    final payload = List<int>.generate(16, (i) => i);
    final server = await _serve((request) {
      request.response.headers.set(HttpHeaders.etagHeader, '"v1"');
      request.response.contentLength = payload.length;
    });
    final base = _endpoint(server);
    final client = NasHttpClient(base);
    addTearDown(client.close);

    final resource = await client.downloadResource(base, mimeType: 'video/mp4');
    expect(resource.version, 'etag:"v1"');
    expect(resource.sizeBytes, 16);
  });

  test('a ranged read sends If-Match and validates Content-Range', () async {
    final payload = List<int>.generate(16, (i) => i);
    final seen = <String>[];
    final server = await _serve((request) {
      if (request.method == 'HEAD') {
        request.response.headers.set(HttpHeaders.etagHeader, '"v1"');
        request.response.contentLength = payload.length;
        return;
      }
      seen.add(
        '${request.headers.value(HttpHeaders.ifMatchHeader)}|'
        '${request.headers.value(HttpHeaders.rangeHeader)}',
      );
      request.response.statusCode = 206;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes 4-7/16',
      );
      request.response.contentLength = 4;
      request.response.add(payload.sublist(4, 8));
    });
    final base = _endpoint(server);
    final client = NasHttpClient(base);
    addTearDown(client.close);

    final resource = await client.downloadResource(base, mimeType: 'video/mp4');
    expect(await _readAll(resource, 4, 8), [4, 5, 6, 7]);
    expect(seen, ['"v1"|bytes=4-7']);
  });

  test('a mutated source surfaces as a 412 on the conditional read', () async {
    final server = await _serve((request) {
      if (request.method == 'HEAD') {
        request.response.headers.set(HttpHeaders.etagHeader, '"v1"');
        request.response.contentLength = 8;
        return;
      }
      request.response.statusCode = 412;
    });
    final base = _endpoint(server);
    final client = NasHttpClient(base);
    addTearDown(client.close);

    final resource = await client.downloadResource(base, mimeType: 'video/mp4');
    await expectLater(
      _readAll(resource, 0, null),
      throwsA(isA<NasHttpException>().having((e) => e.status, 'status', 412)),
    );
  });

  test('missing validators yield no version and read as a full 200', () async {
    final payload = List<int>.generate(8, (i) => i);
    final server = await _serve((request) {
      if (request.method == 'HEAD') {
        request.response.contentLength = payload.length;
        return;
      }
      request.response.statusCode = 200;
      request.response.contentLength = payload.length;
      request.response.add(payload);
    });
    final base = _endpoint(server);
    final client = NasHttpClient(base);
    addTearDown(client.close);

    final resource = await client.downloadResource(base, mimeType: 'video/mp4');
    expect(resource.version, isNull);
    expect(resource.sizeBytes, 8);
    expect(await _readAll(resource, 0, null), payload);
  });

  for (final status in [405, 501]) {
    test('HEAD $status falls back to a full download with no resume', () async {
      final payload = List<int>.generate(8, (i) => i);
      final server = await _serve((request) {
        if (request.method == 'HEAD') {
          request.response.statusCode = status;
          return;
        }
        request.response.statusCode = 200;
        request.response.contentLength = payload.length;
        request.response.add(payload);
      });
      final base = _endpoint(server);
      final client = NasHttpClient(base);
      addTearDown(client.close);

      final resource = await client.downloadResource(
        base,
        mimeType: 'video/mp4',
      );
      expect(resource.version, isNull);
      expect(resource.sizeBytes, isNull);
      expect(await _readAll(resource, 0, null), payload);
    });
  }

  test(
    'an ignored Range without validators is NAS_RANGE_UNSUPPORTED',
    () async {
      final payload = List<int>.generate(8, (i) => i);
      final server = await _serve((request) {
        if (request.method == 'HEAD') {
          request.response.contentLength = payload.length;
          return;
        }
        request.response.statusCode = 200;
        request.response.contentLength = payload.length;
        request.response.add(payload);
      });
      final base = _endpoint(server);
      final client = NasHttpClient(base);
      addTearDown(client.close);

      final resource = await client.downloadResource(
        base,
        mimeType: 'video/mp4',
      );
      await expectLater(
        _readAll(resource, 2, 6),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.code,
            'code',
            'NAS_RANGE_UNSUPPORTED',
          ),
        ),
      );
    },
  );

  test(
    'a whole-file 200 of exact length satisfies a start-zero range',
    () async {
      final payload = [0, 1, 2, 3];
      final server = await _serve((request) {
        if (request.method == 'HEAD') {
          request.response.contentLength = payload.length;
          return;
        }
        request.response.statusCode = 200;
        request.response.contentLength = payload.length;
        request.response.add(payload);
      });
      final base = _endpoint(server);
      final client = NasHttpClient(base);
      addTearDown(client.close);

      final resource = await client.downloadResource(
        base,
        mimeType: 'video/mp4',
      );
      expect(await _readAll(resource, 0, 4), payload);
    },
  );
}
