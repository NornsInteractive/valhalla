// Isolated transport-level checks for AppUpdateService.
//
// Scope: HTTP behavior only (status handling, redirect policy, response
// limits, manifest validation, resumable download integrity). No UI, no
// widgets, no real network, no platform channels -- every response is served
// by an in-test fake.
//
// The fake response extends Stream<List<int>> and implements
// HttpClientResponse, overriding only listen(). Everything else
// (timeout, drain, await-for) is inherited from Stream, so the production
// timeouts are exercised for real instead of being stubbed out.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/data/models/app_update.dart';

const _repo = 'NornsInteractive/valhalla';
const _commitA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _digestE =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _digestB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

String _assetUrl(String tag, String name) =>
    'https://github.com/$_repo/releases/download/$tag/$name';

Map<String, dynamic> _releaseJson({
  String tag = 'v1.2.3',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>> assets = const [],
  String? body = 'notes',
}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/$_repo/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'body': body,
  'assets': assets,
};

Map<String, dynamic> _asset(
  String tag,
  String name, {
  required int size,
  String? digest,
}) => {
  'name': name,
  'size': size,
  'digest': digest,
  'browser_download_url': _assetUrl(tag, name),
};

Map<String, dynamic> _manifestJson({
  String version = '1.2.3',
  int buildNumber = 42,
  String sourceCommit = _commitA,
  int schemaVersion = 1,
  List<Map<String, dynamic>> artifacts = const [],
}) => {
  'schemaVersion': schemaVersion,
  'version': version,
  'buildNumber': buildNumber,
  'sourceCommit': sourceCommit,
  'artifacts': artifacts,
};

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
  late Directory temp;

  setUp(
    () => temp = Directory.systemTemp.createTempSync('valhalla_update_http'),
  );
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  AppUpdateService serviceWith(List<_Exchange> script) =>
      AppUpdateService(clientFactory: () => _FakeClient(script));

  group('check: GitHub 200 and 304 with ETag', () {
    test(
      '200 parses release, exposes ETag and sends auth-less GitHub headers',
      () async {
        final client = _FakeClient([
          (_, _) => _jsonResponse(
            _releaseJson(
              assets: [
                _asset(
                  'v1.2.3',
                  'Valhalla-v1.2.3-windows-x64.zip',
                  size: 1024,
                  digest: 'sha256:$_digestB',
                ),
              ],
            ),
            headers: {'etag': '"release-etag"'},
          ),
        ]);
        final service = AppUpdateService(clientFactory: () => client);

        final check = await service.check();

        expect(check.release!.version, '1.2.3');
        expect(check.release!.notes, 'notes');
        expect(
          check.release!.page.toString(),
          'https://github.com/$_repo/releases/tag/v1.2.3',
        );
        expect(check.release!.artifacts, hasLength(1));
        expect(check.release!.artifacts.single.platform, 'windows');
        expect(check.release!.artifacts.single.architecture, 'x64');
        expect(check.release!.artifacts.single.size, 1024);
        expect(
          check.release!.artifacts.single.url.toString(),
          _assetUrl('v1.2.3', 'Valhalla-v1.2.3-windows-x64.zip'),
        );
        expect(check.etag, '"release-etag"');
        expect(check.response!['tag_name'], 'v1.2.3');

        final request = client.requests.single;
        expect(request.uri, AppUpdateService.latestEndpoint);
        expect(
          request.header(HttpHeaders.acceptHeader),
          'application/vnd.github+json',
        );
        expect(request.header('x-github-api-version'), '2026-03-10');
        expect(
          request.header(HttpHeaders.userAgentHeader),
          'Valhalla-App-Updater',
        );
        expect(request.header('if-none-match'), isNull);
        expect(
          client.closed,
          isTrue,
          reason: 'client must be closed after check',
        );
      },
    );

    test(
      '304 with a cached release reuses the cache and re-emits the ETag',
      () async {
        final cached = _releaseJson(
          assets: [
            _asset(
              'v1.2.3',
              'Valhalla-v1.2.3-linux-x64.tar.gz',
              size: 2048,
              digest: 'sha256:${'c' * 64}',
            ),
          ],
        );
        final client = _FakeClient([
          (_, _) => _FakeResponse(
            304,
            const Stream<List<int>>.empty(),
            headers: {'etag': '"new-etag"'},
          ),
        ]);
        final service = AppUpdateService(clientFactory: () => client);

        final check = await service.check(etag: '"old-etag"', cached: cached);

        expect(client.requests.single.header('if-none-match'), '"old-etag"');
        expect(check.release!.version, '1.2.3');
        expect(check.release!.artifacts.single.platform, 'linux');
        expect(check.etag, '"new-etag"');
        expect(client.closed, isTrue);
      },
    );

    test(
      '304 without a cache is a check failure, not a silent success',
      () async {
        final service = serviceWith([
          (_, _) => _FakeResponse(304, const Stream<List<int>>.empty()),
        ]);

        await expectLater(
          service.check(),
          throwsA(
            isA<HttpException>().having(
              (e) => e.message,
              'message',
              contains('304'),
            ),
          ),
        );
      },
    );
  });

  group('check: GitHub error statuses', () {
    test('404 yields no release without throwing', () async {
      final client = _FakeClient([
        (_, _) => _FakeResponse(404, const Stream<List<int>>.empty()),
      ]);
      final service = AppUpdateService(clientFactory: () => client);

      final check = await service.check();

      expect(check.release, isNull);
      expect(check.etag, isNull);
      expect(client.closed, isTrue);
    });

    for (final status in [403, 429]) {
      test('$status is reported as UPDATE_RATE_LIMITED', () async {
        final client = _FakeClient([
          (_, _) => _FakeResponse(status, const Stream<List<int>>.empty()),
        ]);
        final service = AppUpdateService(clientFactory: () => client);

        await expectLater(
          service.check(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'UPDATE_RATE_LIMITED',
            ),
          ),
        );
        expect(client.closed, isTrue);
      });
    }

    test('draft or prerelease releases are rejected', () async {
      for (final release in [
        _releaseJson(draft: true),
        _releaseJson(prerelease: true),
      ]) {
        final service = serviceWith([(_, _) => _jsonResponse(release)]);
        await expectLater(
          service.check(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_RELEASE_INVALID',
            ),
          ),
        );
      }
    });
  });

  group('check: response size limits', () {
    test('release body beyond 2 MiB is refused mid-stream', () async {
      final filler = 'x' * (64 * 1024);
      final service = serviceWith([
        (_, _) => _FakeResponse(
          200,
          Stream.fromIterable(
            List.generate(40, (i) => utf8.encode('{"pad":"$filler","i":$i}')),
          ),
        ),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_RESPONSE_TOO_LARGE',
          ),
        ),
      );
    });

    test('release body just under the limit is accepted', () async {
      final filler = 'x' * (1024 * 1024);
      final service = serviceWith([
        (_, _) => _jsonResponse(_releaseJson(assets: [], body: filler)),
      ]);

      expect((await service.check()).release!.version, '1.2.3');
    });

    test('manifest body beyond 256 KiB is refused', () async {
      final service = serviceWith([
        (_, _) => _jsonResponse(
          _releaseJson(assets: [_asset('v1.2.3', 'update.json', size: 512)]),
        ),
        (_, _) => _FakeResponse(
          200,
          Stream.value(
            utf8.encode(
              _manifestJson()['sourceCommit'].toString().padRight(
                300 * 1024,
                'a',
              ),
            ),
          ),
        ),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_RESPONSE_TOO_LARGE',
          ),
        ),
      );
    });
  });

  group('redirects: only trusted https hosts', () {
    test('non-https redirect target is blocked', () async {
      final service = serviceWith([
        (_, _) => _FakeResponse(
          302,
          const Stream<List<int>>.empty(),
          headers: {'location': 'http://evil.example.com/update.json'},
        ),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_URL_INVALID',
          ),
        ),
      );
    });

    test('untrusted https host redirect is blocked', () async {
      final service = serviceWith([
        (_, _) => _FakeResponse(
          302,
          const Stream<List<int>>.empty(),
          headers: {'location': 'https://evil.example.com/update.json'},
        ),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_URL_INVALID',
          ),
        ),
      );
    });

    test('githubusercontent redirect is followed', () async {
      final client = _FakeClient([
        (_, _) => _jsonResponse(
          _releaseJson(
            assets: [
              _asset('v1.2.3', 'update.json', size: 256),
              _asset(
                'v1.2.3',
                'Valhalla-v1.2.3-linux-x64.tar.gz',
                size: 8,
                digest: 'sha256:${'d' * 64}',
              ),
            ],
          ),
        ),
        (_, _) => _FakeResponse(
          302,
          const Stream<List<int>>.empty(),
          headers: {
            'location':
                'https://objects.githubusercontent.com/github-production-release-asset/update.json',
          },
        ),
        (_, _) => _jsonResponse(
          _manifestJson(
            artifacts: [
              {
                'name': 'Valhalla-v1.2.3-linux-x64.tar.gz',
                'platform': 'linux',
                'architecture': 'x64',
                'size': 8,
                'sha256': 'd' * 64,
              },
            ],
          ),
        ),
      ]);
      final service = AppUpdateService(clientFactory: () => client);

      final check = await service.check();

      expect(client.requests.last.uri.host, 'objects.githubusercontent.com');
      expect(check.release!.buildNumber, 42);
      expect(check.release!.sourceCommit, 'a' * 40);
      expect(check.release!.artifacts.single.platform, 'linux');
    });

    test('redirect without a location header is refused', () async {
      final service = serviceWith([
        (_, _) => _FakeResponse(301, const Stream<List<int>>.empty()),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_REDIRECT_INVALID',
          ),
        ),
      );
    });

    test('redirect loops past the limit are refused', () async {
      _Exchange hop() {
        final response = _FakeResponse(
          302,
          const Stream<List<int>>.empty(),
          headers: {
            'location': 'https://api.github.com/repos/$_repo/releases/latest',
          },
        );
        _FakeResponse exchange(Uri uri, HttpHeaders headers) => response;
        return exchange;
      }

      final client = _FakeClient(List<_Exchange>.generate(8, (_) => hop()));
      final service = AppUpdateService(clientFactory: () => client);

      await expectLater(
        service.check(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'UPDATE_REDIRECT_LIMIT',
          ),
        ),
      );
      expect(client.requests, hasLength(6));
    });
  });

  group('update.json validation', () {
    /// Serves a release carrying both update.json and an Android asset, so
    /// manifest entries actually bind to a released artifact (unmatched entries
    /// are silently skipped by parseRelease).
    Future<void> checkWithManifest(
      Map<String, dynamic> manifest, {
      int assetSize = 10,
      String assetDigest = 'sha256:$_digestE',
    }) async {
      final service = serviceWith([
        (_, _) => _jsonResponse(
          _releaseJson(
            assets: [
              _asset('v1.2.3', 'update.json', size: 256),
              _asset(
                'v1.2.3',
                'Valhalla-v1.2.3-android-arm64-v8a.apk',
                size: assetSize,
                digest: assetDigest,
              ),
            ],
          ),
        ),
        (_, _) => _jsonResponse(manifest),
      ]);
      await service.check();
    }

    test(
      'valid manifest populates build number, commit and artifacts',
      () async {
        final service = serviceWith([
          (_, _) => _jsonResponse(
            _releaseJson(
              assets: [
                _asset('v1.2.3', 'update.json', size: 256),
                _asset(
                  'v1.2.3',
                  'Valhalla-v1.2.3-android-arm64-v8a.apk',
                  size: 10,
                  digest: 'sha256:$_digestE',
                ),
              ],
            ),
          ),
          (_, _) => _jsonResponse(
            _manifestJson(
              artifacts: [
                {
                  'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
                  'platform': 'android',
                  'architecture': 'arm64-v8a',
                  'size': 10,
                  'sha256': 'e' * 64,
                  'androidVersionCode': 42042,
                  'androidCertificateSha256': 'f' * 64,
                },
              ],
            ),
          ),
        ]);

        final check = await service.check();

        expect(check.release!.version, '1.2.3');
        expect(check.release!.buildNumber, 42);
        expect(check.release!.sourceCommit, _commitA);
        expect(check.release!.artifacts, hasLength(1));
        final artifact = check.release!.artifacts.single;
        expect(artifact.platform, 'android');
        expect(artifact.architecture, 'arm64-v8a');
        expect(artifact.size, 10);
        expect(artifact.sha256, 'e' * 64);
        expect(artifact.androidVersionCode, 42042);
        expect(artifact.androidCertificateSha256, 'f' * 64);
        expect(
          check.response!['_valhalla_manifest'],
          isA<Map<String, dynamic>>(),
        );
      },
    );

    test(
      'manifest entry size disagreeing with the release asset is rejected',
      () async {
        await expectLater(
          checkWithManifest(
            _manifestJson(
              artifacts: [
                {
                  'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
                  'platform': 'android',
                  'architecture': 'arm64-v8a',
                  'size': 11,
                  'sha256': 'e' * 64,
                  'androidVersionCode': 42042,
                  'androidCertificateSha256': 'f' * 64,
                },
              ],
            ),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_ASSET_SIZE_INVALID',
            ),
          ),
        );
      },
    );

    test(
      'manifest digest disagreeing with the release asset digest is rejected',
      () async {
        await expectLater(
          checkWithManifest(
            _manifestJson(
              artifacts: [
                {
                  'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
                  'platform': 'android',
                  'architecture': 'arm64-v8a',
                  'size': 10,
                  'sha256': 'a' * 64,
                  'androidVersionCode': 42042,
                  'androidCertificateSha256': 'f' * 64,
                },
              ],
            ),
            assetDigest: 'sha256:_digestB',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_ASSET_DIGEST_MISMATCH',
            ),
          ),
        );
      },
    );

    test('manifest http failure is surfaced', () async {
      final service = serviceWith([
        (_, _) => _jsonResponse(
          _releaseJson(assets: [_asset('v1.2.3', 'update.json', size: 256)]),
        ),
        (_, _) => _FakeResponse(500, const Stream<List<int>>.empty()),
      ]);

      await expectLater(
        service.check(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'UPDATE_MANIFEST_FAILED',
          ),
        ),
      );
    });

    for (final entry in <String, Map<String, dynamic> Function()>{
      'wrong schema version': () => _manifestJson(schemaVersion: 2),
      'version drift vs tag': () => _manifestJson(version: '9.9.9'),
      'missing build number': () => _manifestJson(buildNumber: 0),
      'non-int build number': () => {'buildNumber': '42'},
      'short commit': () => _manifestJson(sourceCommit: 'abc123'),
      'missing commit': () => {'sourceCommit': null},
    }.entries) {
      test('${entry.key} is rejected', () async {
        await expectLater(
          checkWithManifest(entry.value()),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_MANIFEST_INVALID',
            ),
          ),
        );
      });
    }

    test(
      'android entry without version code or certificate is rejected',
      () async {
        final manifest = _manifestJson(
          artifacts: [
            {
              'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
              'platform': 'android',
              'architecture': 'arm64-v8a',
              'size': 10,
              'sha256': 'e' * 64,
            },
          ],
        );

        await expectLater(
          checkWithManifest(manifest),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'UPDATE_ANDROID_IDENTITY_INVALID',
            ),
          ),
        );
      },
    );
  });

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
        url: Uri.parse(_assetUrl('v1.2.3', 'Valhalla-v1.2.3-linux-x64.tar.gz')),
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
      ]);
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
      expect(
        File('$destination.part').existsSync(),
        isFalse,
        reason: 'a size mismatch must not leave a resumable file behind',
      );
    });

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
              'UPDATE_URL_INVALID',
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
