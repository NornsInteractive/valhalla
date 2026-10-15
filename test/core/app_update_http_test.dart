// Isolated HTTP exchanges: no real network, UI or platform channels.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/data/models/app_update.dart';
import 'fixtures/app_update_payload.dart';

const _repo = 'NornsInteractive/valhalla';

// --- Fakes -----------------------------------------------------------------

/// Scripted HTTP exchange: given the request URI + headers, produce a response.
typedef _Exchange = _FakeResponse Function(Uri uri, HttpHeaders headers);

class _RequestRecord {
  _RequestRecord(this.uri, this.headers);
  final Uri uri;
  final HttpHeaders headers;
  String? header(String name) => headers.value(name);
}

/// Minimal HttpHeaders: Dart 3.10 exposes HttpHeaders as an interface with no
/// public constructor, so the two members the service actually uses are
/// implemented here and the rest is inherited via noSuchMethod.
class _FakeHeaders implements HttpHeaders {
  _FakeHeaders([Map<String, String> initial = const {}]) {
    initial.forEach(set);
  }

  final Map<String, List<String>> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values.putIfAbsent(name.toLowerCase(), () => []).add('$value');

  @override
  String? value(String name) {
    final stored = _values[name.toLowerCase()];
    return (stored == null || stored.isEmpty) ? null : stored.last;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeHttpHeaders.${invocation.memberName}');
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(
    this.statusCode,
    this._source, {
    Map<String, String> headers = const {},
  }) : headers = _FakeHeaders(headers);

  @override
  final int statusCode;
  @override
  final HttpHeaders headers;

  final Stream<List<int>> _source;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _source.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeHttpClientResponse.${invocation.memberName}');
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.client, this.uri);
  final _FakeClient client;
  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  bool followRedirects = true;

  @override
  Future<HttpClientResponse> close() async {
    client.requests.add(_RequestRecord(uri, headers));
    return client.nextResponse(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeHttpClientRequest.${invocation.memberName}');
}

class _FakeClient implements HttpClient {
  _FakeClient(this._script);
  final List<_Exchange> _script;
  final List<_RequestRecord> requests = [];
  int _cursor = 0;
  bool closed = false;

  _FakeResponse nextResponse(_FakeRequest request) {
    if (_cursor >= _script.length) {
      throw StateError(
        'FakeHttpClient: no scripted response for ${request.uri}',
      );
    }
    return _script[_cursor++](request.uri, request.headers);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(this, url);

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('FakeHttpClient.${invocation.memberName}');
}

_FakeResponse _jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) => _FakeResponse(
  statusCode,
  Stream.value(utf8.encode(jsonEncode(body))),
  headers: headers,
);

_FakeResponse _bytesResponse(
  List<int> body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) => _FakeResponse(statusCode, Stream.value(body), headers: headers);

String _identity(AppUpdateArtifact artifact) => jsonEncode({
  'url': artifact.url.toString(),
  'size': artifact.size,
  'sha256': artifact.sha256,
});

void main() {
  AppUpdateService serviceWith(List<_Exchange> script) =>
      AppUpdateService(clientFactory: () => _FakeClient(script));
  late Directory temp;
  setUp(
    () => temp = Directory.systemTemp.createTempSync('valhalla_update_http'),
  );
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'check sends installed platform/ABI/version without authorization',
    () async {
      final client = _FakeClient([
        (_, _) => _jsonResponse(
          updatePayload(currentCode: 4005),
          headers: {'etag': '"catalog-etag"'},
        ),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final check = await service.check(
        currentVersionCode: 4005,
        platform: 'android',
        architecture: 'x64',
      );
      final request = client.requests.single;
      expect(request.uri.queryParameters, {
        'app_id': valhallaDistributionAppId,
        'version_code': '4005',
        'channel': 'default',
        'platform': 'android',
        'arch': 'x86_64',
      });
      expect(request.header('authorization'), isNull);
      expect(request.header('accept'), 'application/json');
      expect(request.header('user-agent'), 'Valhalla-App-Updater');
      expect(request.header('if-none-match'), isNull);
      expect(check.release!.version, '1.2.3');
      expect(check.etag, '"catalog-etag"');
      expect(check.response!['_platform'], 'android');
      expect(check.response!['_arch'], 'x86_64');
      expect(client.closed, isTrue);
    },
  );

  Map<String, dynamic> cachedPayload() => {
    ...updatePayload(currentCode: 7),
    '_source': AppUpdateService.cacheSource,
    '_channel': 'default',
    '_platform': 'linux',
    '_arch': 'x86_64',
    '_version_code': 7,
  };

  test(
    '304 reuses only exact platform/arch/channel/version source context',
    () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(
          304,
          const Stream.empty(),
          headers: {'etag': '"new"'},
        ),
        (_, _) => _FakeResponse(304, const Stream.empty()),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final check = await service.check(
        etag: '"old"',
        cached: cachedPayload(),
        currentVersionCode: 7,
        platform: 'linux',
        architecture: 'x64',
      );
      expect(client.requests.single.header('if-none-match'), '"old"');
      expect(check.etag, '"new"');
      expect(check.release!.artifacts.single.platform, 'linux');
      final again = await service.check(
        etag: check.etag,
        cached: check.response,
        currentVersionCode: 7,
        platform: 'linux',
        architecture: 'x64',
      );
      expect(again.etag, '"new"');
    },
  );

  for (final field in [
    '_source',
    '_channel',
    '_platform',
    '_arch',
    '_version_code',
  ]) {
    test('stale $field cache cannot send ETag or accept bare 304', () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(304, const Stream.empty()),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      await expectLater(
        service.check(
          etag: '"old"',
          cached: cachedPayload()..[field] = 'wrong',
          currentVersionCode: 7,
          platform: 'linux',
          architecture: 'x64',
        ),
        throwsA(isA<HttpException>()),
      );
      expect(client.requests.single.header('if-none-match'), isNull);
      expect(client.closed, isTrue);
    });
  }

  for (final status in [401, 403, 429, 500]) {
    test('check failure $status is reported and closes client', () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(status, const Stream.empty()),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      await expectLater(
        service.check(),
        status == 500
            ? throwsA(isA<HttpException>())
            : throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains(
                    status == 429
                        ? 'UPDATE_RATE_LIMITED'
                        : 'UPDATE_CHECK_AUTH_FAILED',
                  ),
                ),
              ),
      );
      expect(client.closed, isTrue);
    });
  }

  test(
    '404 has no release; errors never attempt old GitHub check fallback',
    () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(404, const Stream.empty()),
      ]);
      final result = await AppUpdateService(
        clientFactory: () => client,
      ).check();
      expect(result.release, isNull);
      expect(client.requests, hasLength(1));
    },
  );

  test('reject response belonging to another current version', () async {
    final client = _FakeClient([
      (_, _) => _jsonResponse(updatePayload(currentCode: 9)),
    ]);
    await expectLater(
      AppUpdateService(
        clientFactory: () => client,
      ).check(currentVersionCode: 8),
      throwsFormatException,
    );
  });

  test('malformed and oversized response fail boundedly', () async {
    for (final body in [
      [],
      {'code': 1},
      updatePayload(notes: 'x' * (2 * 1024 * 1024)),
    ]) {
      final client = _FakeClient([(_, _) => _jsonResponse(body)]);
      await expectLater(
        AppUpdateService(clientFactory: () => client).check(),
        throwsFormatException,
      );
      expect(client.closed, isTrue);
    }
  });

  for (final location in [
    'http://ygg.norns.cc.cd/api/v1/app/latest?app_id=com.norns.valhalla',
    'https://evil.example/latest',
    'https://github.com/NornsInteractive/valhalla/releases/latest',
    'https://ygg.norns.cc.cd/api/v1/app/latest?app_id=wrong.app',
  ]) {
    test(
      'metadata redirect outside exact source is rejected: $location',
      () async {
        final client = _FakeClient([
          (_, _) => _FakeResponse(
            302,
            const Stream.empty(),
            headers: {'location': location},
          ),
        ]);
        await expectLater(
          AppUpdateService(clientFactory: () => client).check(),
          throwsFormatException,
        );
        expect(client.requests, hasLength(1));
      },
    );
  }

  test('missing redirect location and redirect loop are rejected', () async {
    for (final headers in [
      <String, String>{},
      {
        'location': AppUpdateService.latestEndpoint
            .replace(queryParameters: {'app_id': valhallaDistributionAppId})
            .toString(),
      },
    ]) {
      final client = _FakeClient(
        List.generate(
          6,
          (_) =>
              (_, _) =>
                  _FakeResponse(302, const Stream.empty(), headers: headers),
        ),
      );
      await expectLater(
        AppUpdateService(clientFactory: () => client).check(),
        throwsFormatException,
      );
      expect(client.requests.length, headers.isEmpty ? 1 : 6);
    }
  });

  test(
    'download follows approved GitHub upstream with explicit initial target',
    () async {
      final payload = [1, 2, 3];
      final package = updatePackage(
        size: payload.length,
        hash: sha256.convert(payload).toString(),
      );
      final artifact = AppUpdateService.parseRelease(
        updatePayload(packages: [package]),
      ).artifacts.single;
      final client = _FakeClient([
        (_, _) => _FakeResponse(
          302,
          const Stream.empty(),
          headers: {
            'location':
                'https://github.com/$_repo/releases/download/v1.2.3/test.tar.gz',
          },
        ),
        (_, _) => _FakeResponse(
          302,
          const Stream.empty(),
          headers: {
            'location':
                'https://release-assets.githubusercontent.com/test.tar.gz',
          },
        ),
        (_, _) => _bytesResponse(payload),
      ]);
      final destination = '${temp.path}/upstream.bin';
      await AppUpdateService(
        clientFactory: () => client,
      ).download(artifact, destination, onProgress: (_) {});
      expect(client.requests.first.uri.queryParameters['platform'], 'linux');
      expect(client.requests.first.uri.queryParameters['arch'], 'x86_64');
      expect(
        client.requests.first.uri.queryParameters['package_id'],
        package['id'],
      );
      expect(
        client.requests.every((r) => r.header('authorization') == null),
        isTrue,
      );
      expect(await File(destination).readAsBytes(), payload);
    },
  );

  group('download: resume and integrity', () {
    const size = 10;
    final payload = List<int>.generate(size, (i) => 65 + i);
    final digest = sha256.convert(payload).toString();
    late AppUpdateArtifact artifact;

    setUp(
      () => artifact = AppUpdateArtifact(
        name: 'Valhalla-v1.2.3-linux-x64.tar.gz',
        platform: 'linux',
        architecture: 'x64',
        size: size,
        sha256: digest,
        url: updateDownloadUrl().replace(
          queryParameters: {
            ...updateDownloadUrl().queryParameters,
            'platform': 'linux',
            'arch': 'x86_64',
          },
        ),
      ),
    );

    String destPath([String name = 'artifact.bin']) =>
        '${temp.path}${Platform.pathSeparator}$name';

    /// Pre-seed a partial download of [bytes] plus matching sidecar metadata.
    Future<void> seedPartial(String destination, List<int> bytes) async {
      await File('$destination.part').writeAsBytes(bytes, flush: true);
      await File(
        '$destination.part.json',
      ).writeAsString(_identity(artifact), flush: true);
    }

    test(
      'fresh download renames the verified file and clears sidecars',
      () async {
        final client = _FakeClient([(_, _) => _bytesResponse(payload)]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();
        final progress = <int>[];

        await service.download(artifact, destination, onProgress: progress.add);

        expect(await File(destination).readAsBytes(), payload);
        expect(File('$destination.part').existsSync(), isFalse);
        expect(File('$destination.part.json').existsSync(), isFalse);
        expect(progress, [0, size]);
        expect(client.requests.single.header('range'), isNull);
      },
    );

    test(
      'partial file resumes with a Range request and a matching Content-Range',
      () async {
        final seed = payload.sublist(0, 4);
        final client = _FakeClient([
          (uri, headers) => _bytesResponse(
            payload.sublist(4),
            statusCode: 206,
            headers: {'content-range': 'bytes 4-9/10'},
          ),
        ]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();
        await seedPartial(destination, seed);
        final progress = <int>[];

        await service.download(artifact, destination, onProgress: progress.add);

        expect(client.requests.single.header('range'), 'bytes=4-');
        expect(await File(destination).readAsBytes(), payload);
        expect(
          progress.first,
          4,
          reason: 'progress resumes from the partial size',
        );
        expect(progress.last, size);
        expect(File('$destination.part').existsSync(), isFalse);
      },
    );

    test(
      '206 without the expected Content-Range fails and keeps the partial',
      () async {
        final client = _FakeClient([
          (_, _) => _bytesResponse(
            payload.sublist(4),
            statusCode: 206,
            headers: {'content-range': 'bytes 0-5/10'},
          ),
        ]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();
        await seedPartial(destination, payload.sublist(0, 4));

        await expectLater(
          service.download(artifact, destination, onProgress: (_) {}),
          throwsA(
            isA<HttpException>().having(
              (e) => e.message,
              'message',
              contains('UPDATE_DOWNLOAD_FAILED'),
            ),
          ),
        );
        expect(File(destination).existsSync(), isFalse);
        expect(
          await File('$destination.part').readAsBytes(),
          payload.sublist(0, 4),
        );
      },
    );

    test('206 answered without a resume offset is refused', () async {
      final client = _FakeClient([
        (_, _) => _bytesResponse(
          payload,
          statusCode: 206,
          headers: {'content-range': 'bytes 0-9/10'},
        ),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(isA<HttpException>()),
      );
      expect(File(destination).existsSync(), isFalse);
    });

    test('server ignoring Range with 200 restarts from byte zero', () async {
      final client = _FakeClient([
        (_, _) => _bytesResponse(payload, statusCode: 200),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();
      await seedPartial(destination, payload.sublist(0, 4));
      final progress = <int>[];

      await service.download(artifact, destination, onProgress: progress.add);

      expect(client.requests.single.header('range'), 'bytes=4-');
      expect(
        await File(destination).readAsBytes(),
        payload,
        reason: 'a 200 response must truncate the stale partial file',
      );
      expect(progress, contains(0));
    });

    test(
      'stale sidecar identity discards the partial and restarts clean',
      () async {
        final client = _FakeClient([(_, _) => _bytesResponse(payload)]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();
        await File(
          '$destination.part',
        ).writeAsBytes(payload.sublist(0, 4), flush: true);
        await File(
          '$destination.part.json',
        ).writeAsString('{"url":"other"}', flush: true);

        await service.download(artifact, destination, onProgress: (_) {});

        expect(client.requests.single.header('range'), isNull);
        expect(await File(destination).readAsBytes(), payload);
      },
    );

    test('oversized partial is discarded instead of resumed', () async {
      final client = _FakeClient([(_, _) => _bytesResponse(payload)]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();
      await seedPartial(destination, List<int>.filled(size + 5, 7));

      await service.download(artifact, destination, onProgress: (_) {});

      expect(client.requests.single.header('range'), isNull);
      expect(await File(destination).readAsBytes(), payload);
    });

    test(
      'stream interruption retains the partial and allows a later resume',
      () async {
        final controller = StreamController<List<int>>();
        final client = _FakeClient([
          (uri, headers) {
            final resume = headers.value('range');
            expect(resume, isNull, reason: 'first attempt starts from scratch');
            return _FakeResponse(200, controller.stream);
          },
          (_, headers) {
            expect(headers.value('range'), 'bytes=3-');
            return _bytesResponse(
              payload.sublist(3),
              statusCode: 206,
              headers: {'content-range': 'bytes 3-9/10'},
            );
          },
        ]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();

        final attempt = service.download(
          artifact,
          destination,
          onProgress: (_) {},
        );
        controller.add(payload.sublist(0, 3));
        await pumpEventQueue();
        controller.addError(
          HttpException('connection reset', uri: Uri.parse('https://x')),
        );
        await controller.close();

        await expectLater(attempt, throwsA(isA<HttpException>()));
        expect(File(destination).existsSync(), isFalse);
        expect(
          await File('$destination.part').readAsBytes(),
          payload.sublist(0, 3),
          reason: 'verified-but-incomplete bytes must survive for resume',
        );

        await service.download(artifact, destination, onProgress: (_) {});
        expect(await File(destination).readAsBytes(), payload);
        expect(File('$destination.part').existsSync(), isFalse);
      },
    );

    test('cancel stops the transfer and leaves no completed file', () async {
      final client = _FakeClient([(_, _) => _bytesResponse(payload)]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(
          artifact,
          destination,
          onProgress: (received) {
            if (received > 0) service.cancelDownload();
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'UPDATE_DOWNLOAD_CANCELED',
          ),
        ),
      );
      expect(File(destination).existsSync(), isFalse);
    });

    test(
      'cancel before completion is not clobbered by a later download',
      () async {
        final client = _FakeClient([
          (_, _) => _bytesResponse(payload),
          (_, _) => _bytesResponse(payload),
        ]);
        final service = AppUpdateService(clientFactory: () => client);
        final first = destPath('first.bin');

        await expectLater(
          service.download(
            artifact,
            first,
            onProgress: (received) {
              if (received > 0) service.cancelDownload();
            },
          ),
          throwsA(isA<StateError>()),
        );
        expect(File(first).existsSync(), isFalse);

        final second = destPath('second.bin');
        await service.download(artifact, second, onProgress: (_) {});
        expect(await File(second).readAsBytes(), payload);
        expect(client.requests, hasLength(2));
      },
    );

    test('short body leaves no completed file', () async {
      final client = _FakeClient([
        (_, _) => _bytesResponse(payload.sublist(0, 6)),
        (_, _) => _bytesResponse(
          [],
          statusCode: 206,
          headers: {'content-range': 'bytes 6-9/10'},
        ),
        (_, _) => _bytesResponse(
          [],
          statusCode: 206,
          headers: {'content-range': 'bytes 6-9/10'},
        ),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            'UPDATE_DOWNLOAD_INCOMPLETE',
          ),
        ),
      );
      expect(File(destination).existsSync(), isFalse);
      expect(
        File('$destination.part').existsSync(),
        isTrue,
        reason: 'short streams preserve bytes for a later Range retry',
      );
      expect(
        await File('$destination.part').readAsBytes(),
        payload.sublist(0, 6),
      );
      expect(client.requests, hasLength(3));
    });

    test(
      'short stream resumes through both redirects and verifies full hash',
      () async {
        final github =
            'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/archive.tar.gz';
        final assets =
            'https://release-assets.githubusercontent.com/archive.tar.gz';
        final client = _FakeClient([
          (_, _) => _bytesResponse(payload.sublist(0, 6)),
          (_, _) => _bytesResponse(
            [],
            statusCode: 302,
            headers: {'location': github},
          ),
          (_, _) => _bytesResponse(
            [],
            statusCode: 302,
            headers: {'location': assets},
          ),
          (_, _) => _bytesResponse(
            payload.sublist(6),
            statusCode: 206,
            headers: {'content-range': 'bytes 6-9/10'},
          ),
        ]);
        final phases = <AppUpdateDownloadPhase>[];
        final destination = destPath();
        await AppUpdateService(clientFactory: () => client).download(
          artifact,
          destination,
          onProgress: (_) {},
          onPhase: phases.add,
        );
        expect(await File(destination).readAsBytes(), payload);
        expect(
          client.requests.skip(1).map((r) => r.header('range')),
          everyElement('bytes=6-'),
        );
        expect(phases.last, AppUpdateDownloadPhase.verifying);
        expect(File('$destination.part').existsSync(), isFalse);
      },
    );

    test(
      'cancel during retry backoff wakes promptly without another request',
      () async {
        final first = Completer<void>();
        final client = _FakeClient([
          (_, _) {
            first.complete();
            return _bytesResponse([], statusCode: 503);
          },
        ]);
        final service = AppUpdateService(clientFactory: () => client);
        final destination = destPath();
        final failure = expectLater(
          service.download(artifact, destination, onProgress: (_) {}),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'reason',
              'UPDATE_DOWNLOAD_CANCELED',
            ),
          ),
        );
        await first.future;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        service.cancelDownload();
        await failure.timeout(const Duration(milliseconds: 500));
        expect(client.requests, hasLength(1));
        expect(File(destination).existsSync(), isFalse);
      },
    );

    test('oversized body is refused mid-stream', () async {
      final client = _FakeClient([
        (_, _) => _bytesResponse(List<int>.filled(size + 1, 9)),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'UPDATE_DOWNLOAD_SIZE_MISMATCH',
          ),
        ),
      );
      expect(File(destination).existsSync(), isFalse);
    });

    test('hash mismatch leaves no completed file', () async {
      final tampered = List<int>.from(payload)..[5] = 0;
      final client = _FakeClient([(_, _) => _bytesResponse(tampered)]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'UPDATE_DOWNLOAD_INTEGRITY_FAILED',
          ),
        ),
      );
      expect(File(destination).existsSync(), isFalse);
      expect(File('$destination.part').existsSync(), isFalse);
    });

    test('existing destination is never overwritten', () async {
      final client = _FakeClient([(_, _) => _bytesResponse(payload)]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();
      await File(destination).writeAsString('previous', flush: true);

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'UPDATE_DESTINATION_EXISTS',
          ),
        ),
      );
      expect(await File(destination).readAsString(), 'previous');
    });

    test(
      'untrusted download host is refused before any file is written',
      () async {
        final hostile = AppUpdateArtifact(
          name: artifact.name,
          platform: artifact.platform,
          architecture: artifact.architecture,
          size: artifact.size,
          sha256: artifact.sha256,
          url: Uri.parse(
            'http://github.com/$_repo/releases/download/v1.2.3/x.tar.gz',
          ),
        );
        final service = serviceWith([(_, _) => _bytesResponse(payload)]);
        final destination = destPath();

        await expectLater(
          service.download(hostile, destination, onProgress: (_) {}),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_ASSET_URL_INVALID',
            ),
          ),
        );
        expect(File(destination).existsSync(), isFalse);
        expect(File('$destination.part').existsSync(), isFalse);
      },
    );

    test('redirected download to an untrusted host is refused', () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(
          302,
          const Stream<List<int>>.empty(),
          headers: {'location': 'https://cdn.evil.example.com/payload'},
        ),
      ]);
      final service = AppUpdateService(clientFactory: () => client);
      final destination = destPath();

      await expectLater(
        service.download(artifact, destination, onProgress: (_) {}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_URL_INVALID',
          ),
        ),
      );
      expect(File(destination).existsSync(), isFalse);
    });
  });
}
