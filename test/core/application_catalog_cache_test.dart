import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_catalog_service.dart';
import 'package:valhalla/data/models/application_center.dart';

class _Headers implements HttpHeaders {
  _Headers([Map<String, String> initial = const {}]) {
    initial.forEach(set);
  }
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name.toLowerCase()] = '$value';
  @override
  String? value(String name) => values[name.toLowerCase()];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(
    this.statusCode,
    String body, [
    Map<String, String> headers = const {},
  ]) : bytes = utf8.encode(body),
       headers = _Headers(headers);
  _Response.raw(this.statusCode, this.bytes) : headers = _Headers();
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  final List<int> bytes;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Request implements HttpClientRequest {
  _Request(this.client, this.uri);
  final _Client client;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  Future<HttpClientResponse> close() async {
    client.requests.add(this);
    if (client.offline) throw const SocketException('offline');
    return (client.responses[uri.toString()] ?? client.responses[uri.path])
            ?.call(this) ??
        _Response(404, '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Client implements HttpClient {
  final requests = <_Request>[];
  final responses = <String, _Response Function(_Request)>{};
  bool offline = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async => _Request(this, uri);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  const source = ApplicationSource(
    id: 'fixture',
    name: 'Fixture',
    url: 'https://fixture.invalid/store',
  );
  final index = jsonEncode({
    'version': 2,
    'apps': [
      {
        'id': 'app',
        'title': 'App',
        'compose_url': '/apps/app/docker-compose.yml',
      },
    ],
  });
  late Directory temp;
  late _Client client;
  late ApplicationCatalogService service;
  File cacheFile(ApplicationSource value, [String locale = 'en_US']) {
    final key = sha256.convert(
      utf8.encode(
        '${value.id}|${ApplicationCatalogService.sourceUri(value.url)}|$locale',
      ),
    );
    return File('${temp.path}/application_catalog/$key.json');
  }

  Matcher centerError(String code) => throwsA(
    isA<ApplicationCenterException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );

  const official = ApplicationSource.official;
  const primary =
      'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/';
  const secondary =
      'https://raw.githubusercontent.com/IceWhaleTech/CasaOS-AppStore/gh-pages/';
  void officialResponses() {
    client.responses['${primary}store.json'] = (_) =>
        _Response(200, '{"version":2,"store_id":"official"}');
    client.responses['${primary}index.en_US.json'] = (_) =>
        _Response(200, index, {'etag': 'primary-rev'});
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('center-cache-');
    client = _Client();
    service = ApplicationCatalogService(
      directoryProvider: () async => temp,
      clientFactory: () => client,
    );
    client.responses['/store/store.json'] = (_) =>
        _Response(200, '{"version":2,"store_id":"fixture"}');
    client.responses['/store/index.en_US.json'] = (_) =>
        _Response(200, index, {'etag': 'rev1'});
  });
  tearDown(() => temp.delete(recursive: true));
  test(
    'official-style translation fragments overlay canonical catalog safely',
    () async {
      client.responses['/store/index.zh_CN.json'] = (_) => _Response(
        200,
        jsonEncode({
          'apps': [
            {
              'id': 'app',
              'tagline': '中文说明',
              'compose_url': 'https://untrusted.invalid/wrong.yml',
            },
            {'id': 'unknown', 'title': 'Not a canonical app'},
          ],
        }),
        {'etag': 'translation-v1'},
      );
      client.responses['/store/index.json'] = (_) => _Response(200, index);
      final apps = await service.refresh(source, locale: 'zh_CN');
      expect(apps.single.title, 'App');
      expect(apps.single.summary, '中文说明');
      expect(
        apps.single.composeUrl,
        'https://fixture.invalid/store/apps/app/docker-compose.yml',
      );
      client.responses['/store/index.json'] = (_) => _Response(
        200,
        index.replaceFirst('"title":"App"', '"title":"Updated"'),
      );
      expect(
        (await service.refresh(source, locale: 'zh_CN')).single.title,
        'Updated',
      );
      expect(
        client.requests
            .where((r) => r.uri.path.endsWith('index.zh_CN.json'))
            .every((r) => r.headers.value('if-none-match') == null),
        true,
      );
      client.offline = true;
      expect(
        (await service.cached(source, locale: 'zh_CN')).single.summary,
        '中文说明',
      );
    },
  );
  test('translation overlay rejects invalid types and duplicate IDs', () {
    for (final apps in [
      [
        {'id': 'app', 'title': 3},
      ],
      [
        {'id': 'app'},
        {'id': 'app'},
      ],
    ]) {
      expect(
        () => ApplicationCatalogService.parseIndex(
          index,
          source,
          localization: jsonEncode({'apps': apps}),
        ),
        throwsA(isA<ApplicationCenterException>()),
      );
    }
  });
  test(
    'live official Chinese catalog and template are readable',
    () async {
      final live = ApplicationCatalogService(
        directoryProvider: () async => temp,
      );
      final apps = await live.refresh(
        ApplicationSource.official,
        locale: 'zh_CN',
      );
      expect(apps.length, greaterThan(100));
      final app = apps.firstWhere((app) => app.id == 'com.icewhale.bentopdf');
      expect(app.summary, contains('PDF'));
      expect((await live.template(app)).compose['services'], isA<Map>());
      expect(
        (await live.cached(ApplicationSource.official, locale: 'zh_CN')).length,
        apps.length,
      );
    },
    skip: Platform.environment['VALHALLA_APP_CATALOG_LIVE'] != 'true',
  );
  test(
    'cached catalog survives offline; 304 sends ETag and preserves records',
    () async {
      final first = await service.refresh(source);
      expect(
        first.single.composeUrl,
        'https://fixture.invalid/store/apps/app/docker-compose.yml',
      );
      client.responses['/store/index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), 'rev1');
        return _Response(304, '');
      };
      expect((await service.refresh(source)).single.id, 'app');
      client.offline = true;
      expect((await service.cached(source)).single.id, 'app');
      await expectLater(
        service.refresh(source),
        centerError('APP_CENTER_SOURCE_NETWORK'),
      );
      expect((await service.cached(source)).single.id, 'app');
    },
  );
  test(
    'corrupt and oversized exact cache entries cannot supply stale ETag',
    () async {
      await service.refresh(source);
      final key = sha256.convert(
        utf8.encode(
          '${source.id}|${ApplicationCatalogService.sourceUri(source.url)}|en_US',
        ),
      );
      final file = File('${temp.path}/application_catalog/$key.json');
      for (final damaged in ['not json', 'x' * (6 * 1024 * 1024 + 1)]) {
        await file.writeAsString(damaged);
        client.responses['/store/index.en_US.json'] = (request) {
          expect(request.headers.value('if-none-match'), isNull);
          return _Response(200, index);
        };
        expect((await service.refresh(source)).single.id, 'app');
      }
    },
  );
  test('images coalesce, cache, and reject oversized bodies', () async {
    client.responses['/icon.svg'] = (_) => _Response(200, '<svg/>');
    final first = service.image('https://fixture.invalid/icon.svg');
    expect(service.image('https://fixture.invalid/icon.svg'), same(first));
    expect(await (await first).readAsString(), '<svg/>');
    await service.image('https://fixture.invalid/icon.svg');
    expect(client.requests.length, 1);
    client.responses['/large.png'] = (_) =>
        _Response(200, 'x' * (2 * 1024 * 1024 + 1));
    await expectLater(
      service.image('https://fixture.invalid/large.png'),
      throwsA(isA<ApplicationCenterException>()),
    );
    client.responses['/large.png'] = (_) => _Response(200, 'recovered');
    expect(
      await (await service.image(
        'https://fixture.invalid/large.png',
      )).readAsString(),
      'recovered',
    );
  });
  test('fresh template cache avoids requests when offline', () async {
    final app = (await service.refresh(source)).single;
    client.responses['/store/apps/app/docker-compose.yml'] = (_) =>
        _Response(200, 'services:\n  web:\n    image: nginx:alpine\n');
    expect((await service.template(app)).canInstall, true);
    final count = client.requests.length;
    client.offline = true;
    expect(
      (await service.template(app)).compose['services']['web']['image'],
      'nginx:alpine',
    );
    expect(client.requests.length, count);
  });

  group('official source transport fallback', () {
    for (final failure in <(String, _Response Function(_Request))>[
      (
        'DNS',
        (_) => throw const SocketException('Failed host lookup: private'),
      ),
      ('socket', (_) => throw const SocketException('Connection reset')),
      ('timeout', (_) => throw TimeoutException('private host')),
      ('HTTP transport', (_) => throw const HttpException('Connection closed')),
      ('500', (_) => _Response(500, 'private server error')),
      ('503', (_) => _Response(503, 'private server error')),
    ]) {
      test('${failure.$1} retries exact official repository once', () async {
        officialResponses();
        client.responses['${primary}store.json'] = failure.$2;
        client.responses['${secondary}store.json'] = (_) =>
            _Response(200, '{"version":2,"store_id":"official"}');
        final apps = await service.refresh(official);
        expect(apps.single.sourceId, official.id);
        expect(apps.single.composeUrl, '${primary}apps/app/docker-compose.yml');
        expect(client.requests.map((request) => request.uri.toString()), [
          '${primary}store.json',
          '${secondary}store.json',
          '${primary}index.en_US.json',
        ]);
      });
    }

    test(
      'catalog, compose, metadata and images all retain original identity',
      () async {
        final content = jsonEncode({
          'version': 2,
          'apps': [
            {
              'id': 'app',
              'title': 'App',
              'compose_url': '/apps/app/docker-compose.yml',
              'meta_url': '/apps/app/meta.json',
              'icon': '/apps/app/icon.png',
              'content_hash': 'upstream-revision-marker',
            },
          ],
        });
        final bodies = <String, String>{
          'store.json': '{"version":2,"store_id":"official"}',
          'index.en_US.json': content,
          'apps/app/docker-compose.yml':
              'services:\n  web:\n    image: nginx:alpine\n',
          'apps/app/meta.json': '{"screenshot_link":["/apps/app/screen.png"]}',
          'apps/app/icon.png': 'icon bytes',
          'apps/app/screen.png': 'screen bytes',
        };
        for (final entry in bodies.entries) {
          client.responses['$primary${entry.key}'] = (_) =>
              throw const SocketException(
                'Failed host lookup: cdn.jsdelivr.net',
              );
          client.responses['$secondary${entry.key}'] = (_) =>
              _Response(200, entry.value);
        }
        final app = (await service.refresh(official)).single;
        final template = await service.template(app);
        expect(template.application, same(app));
        expect(template.application.contentHash, 'upstream-revision-marker');
        expect(template.compose['services']['web']['image'], 'nginx:alpine');
        expect(template.screenshots, ['${primary}apps/app/screen.png']);
        expect(
          await (await service.image(
            app.iconUrl,
            sourceId: app.sourceId,
          )).readAsString(),
          'icon bytes',
        );
        expect(
          await (await service.image(
            template.screenshots.single,
            sourceId: app.sourceId,
          )).readAsString(),
          'screen bytes',
        );
        expect(client.requests.map((request) => request.uri.toString()), [
          for (final key in bodies.keys) ...['$primary$key', '$secondary$key'],
        ]);
        final count = client.requests.length;
        client.offline = true;
        expect(
          (await service.cached(official)).single.contentHash,
          app.contentHash,
        );
        expect((await service.template(app)).compose, template.compose);
        await service.image(app.iconUrl, sourceId: app.sourceId);
        expect(client.requests.length, count);
      },
    );

    for (final failure in <(String, _Response Function(_Request), String)>[
      (
        'TLS',
        (_) => throw const HandshakeException('private certificate'),
        'APP_CENTER_SOURCE_TLS',
      ),
      (
        '401',
        (_) => _Response(401, 'private token'),
        'APP_CENTER_SOURCE_UNAVAILABLE',
      ),
      ('404', (_) => _Response(404, ''), 'APP_CENTER_SOURCE_UNAVAILABLE'),
      ('429', (_) => _Response(429, ''), 'APP_CENTER_SOURCE_UNAVAILABLE'),
      (
        'invalid JSON',
        (_) => _Response(200, '{secret'),
        'APP_CENTER_CATALOG_INVALID',
      ),
      (
        'invalid UTF8',
        (_) => _Response.raw(200, [0xff]),
        'APP_CENTER_CATALOG_INVALID',
      ),
      (
        'wrong schema',
        (_) => _Response(200, '{"version":1}'),
        'APP_CENTER_SOURCE_UNSUPPORTED',
      ),
      (
        'oversized',
        (_) => _Response(200, 'x' * (256 * 1024 + 1)),
        'APP_CENTER_CATALOG_TOO_LARGE',
      ),
    ]) {
      test('${failure.$1} never bypasses validation using secondary', () async {
        officialResponses();
        client.responses['${primary}store.json'] = failure.$2;
        await expectLater(service.refresh(official), centerError(failure.$3));
        expect(client.requests.map((request) => request.uri.toString()), [
          '${primary}store.json',
        ]);
      });
    }

    test('invalid template and metadata do not fall back', () async {
      officialResponses();
      final app = (await service.refresh(official)).single;
      client.responses[app.composeUrl] = (_) => _Response(200, '[]');
      await expectLater(
        service.template(app),
        centerError('APP_CENTER_TEMPLATE_INVALID'),
      );
      expect(client.requests.last.uri.toString(), app.composeUrl);
      final withMetadata = CatalogApplication(
        sourceId: app.sourceId,
        id: app.id,
        title: app.title,
        composeUrl: app.composeUrl,
        metadataUrl: '${primary}apps/app/meta.json',
      );
      client.responses[app.composeUrl] = (_) =>
          _Response(200, 'services:\n  web:\n    image: nginx:alpine\n');
      client.responses[withMetadata.metadataUrl] = (_) =>
          _Response(200, 'not json');
      await expectLater(
        service.template(withMetadata),
        centerError('APP_CENTER_CATALOG_INVALID'),
      );
      expect(
        client.requests.every(
          (request) => request.uri.host != 'raw.githubusercontent.com',
        ),
        isTrue,
      );
    });

    for (final custom in [
      ApplicationSource(id: 'custom', name: 'Custom', url: official.url),
      ApplicationSource(
        id: official.id,
        name: 'Changed source',
        url: 'https://custom.invalid/store',
      ),
    ]) {
      test(
        'custom source ${custom.url} cannot acquire official fallback',
        () async {
          client.responses['${ApplicationCatalogService.sourceUri(custom.url)}store.json'] =
              (_) => throw const SocketException('offline');
          await expectLater(
            service.refresh(custom),
            centerError('APP_CENTER_SOURCE_NETWORK'),
          );
          expect(client.requests.length, 1);
          final app = CatalogApplication(
            sourceId: custom.id,
            id: 'app',
            title: 'App',
            composeUrl: '${primary}apps/app/docker-compose.yml',
          );
          client.responses[app.composeUrl] = (_) =>
              throw const SocketException('offline');
          await expectLater(
            service.template(app),
            centerError('APP_CENTER_SOURCE_NETWORK'),
          );
          await expectLater(
            service.image(app.composeUrl, sourceId: app.sourceId),
            centerError('APP_CENTER_SOURCE_NETWORK'),
          );
          expect(
            client.requests.every(
              (request) => request.uri.host != 'raw.githubusercontent.com',
            ),
            isTrue,
          );
        },
      );
    }

    test(
      'unregistered image source and noncanonical resource URLs never fallback',
      () async {
        final urls = [
          '${primary}apps/icon.png',
          'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@other/apps/icon.png',
          'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages-lookalike/apps/icon.png',
          '${primary}apps/icon.png?version=1',
          'https://cdn.jsdelivr.net:444/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/apps/icon.png',
        ];
        for (var i = 0; i < urls.length; i++) {
          if (i == 1) await service.cached(official);
          client.responses[urls[i]] = (_) =>
              throw const SocketException('offline');
          await expectLater(
            service.image(urls[i], sourceId: official.id),
            centerError('APP_CENTER_SOURCE_NETWORK'),
          );
        }
        expect(client.requests.length, urls.length);
        expect(
          client.requests.every(
            (request) => request.uri.host != 'raw.githubusercontent.com',
          ),
          isTrue,
        );
      },
    );

    test(
      'all endpoints failing preserves known catalog and cached success time',
      () async {
        officialResponses();
        await service.refresh(official);
        final original = await cacheFile(official).readAsString();
        client.responses['${primary}store.json'] = (_) =>
            _Response(503, 'unavailable');
        client.responses['${secondary}store.json'] = (_) =>
            throw const SocketException('Failed host lookup: private host');
        await expectLater(
          service.refresh(official),
          centerError('APP_CENTER_SOURCE_DNS'),
        );
        expect(await cacheFile(official).readAsString(), original);
        expect((await service.cached(official)).single.id, 'app');
        expect(
          client.requests
              .where(
                (request) => request.uri.toString() == '${secondary}store.json',
              )
              .length,
          1,
        );
      },
    );
  });

  test(
    'network error codes do not include raw hostnames or transport messages',
    () async {
      for (final failure in <(Object, String)>[
        (
          const SocketException('Failed host lookup: private-host'),
          'APP_CENTER_SOURCE_DNS',
        ),
        (
          const SocketException('private connection error'),
          'APP_CENTER_SOURCE_NETWORK',
        ),
        (TimeoutException('private-host'), 'APP_CENTER_SOURCE_TIMEOUT'),
        (
          const HandshakeException('private certificate info'),
          'APP_CENTER_SOURCE_TLS',
        ),
      ]) {
        client.responses['/store/store.json'] = (_) => throw failure.$1;
        await expectLater(
          service.refresh(source),
          throwsA(
            isA<ApplicationCenterException>()
                .having(
                  (error) => error.toString(),
                  'sanitized exception',
                  failure.$2,
                )
                .having((error) => error.detail, 'detail', isNull),
          ),
        );
      }
    },
  );

  test(
    'validators remain isolated between primary, fallback and recovered primary',
    () async {
      officialResponses();
      await service.refresh(official);
      client.responses['${primary}index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), 'primary-rev');
        return _Response(503, '');
      };
      client.responses['${secondary}index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(200, index, {'etag': 'raw-rev'});
      };
      await service.refresh(official);
      client.responses['${primary}index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(503, '');
      };
      client.responses['${secondary}index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), 'raw-rev');
        return _Response(304, '');
      };
      expect((await service.refresh(official)).single.id, 'app');
      final rawRequests = client.requests
          .where((request) => request.uri.host == 'raw.githubusercontent.com')
          .length;
      client.responses['${primary}index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(200, index, {'etag': 'recovered-rev'});
      };
      await service.refresh(official);
      expect(
        client.requests
            .where((request) => request.uri.host == 'raw.githubusercontent.com')
            .length,
        rawRequests,
      );
      expect(
        jsonDecode(await cacheFile(official).readAsString())['etagUri'],
        '${primary}index.en_US.json',
      );
    },
  );

  test(
    'localized, canonical and other-locale validators are not interchangeable',
    () async {
      await service.refresh(source);
      client.responses['/store/index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), 'rev1');
        return _Response(404, '');
      };
      client.responses['/store/index.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(200, index, {'etag': 'canonical'});
      };
      await service.refresh(source);
      client.responses['/store/index.en_US.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(404, '');
      };
      client.responses['/store/index.json'] = (request) {
        expect(request.headers.value('if-none-match'), 'canonical');
        return _Response(304, '');
      };
      expect((await service.refresh(source)).single.id, 'app');
      client.responses['/store/index.fr_FR.json'] = (request) {
        expect(request.headers.value('if-none-match'), isNull);
        return _Response(200, index, {'etag': 'french'});
      };
      await service.refresh(source, locale: 'fr_FR');
    },
  );

  test('legacy cache validators lacking URL are discarded once', () async {
    await service.refresh(source);
    final file = cacheFile(source);
    final saved = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    saved.remove('etagUri');
    await file.writeAsString(jsonEncode(saved));
    client.responses['/store/index.en_US.json'] = (request) {
      expect(request.headers.value('if-none-match'), isNull);
      return _Response(200, index, {'etag': 'new-rev'});
    };
    await service.refresh(source);
    expect(
      jsonDecode(await file.readAsString())['etagUri'],
      'https://fixture.invalid/store/index.en_US.json',
    );
  });

  test(
    '304 updates last successful validation atomically without changing cache content',
    () async {
      expect(await service.cachedAt(source), isNull);
      await service.refresh(source);
      final file = cacheFile(source);
      final saved =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      saved['at'] = '2020-01-01T00:00:00.000Z';
      await file.writeAsString(jsonEncode(saved));
      expect(await service.cachedAt(source), DateTime.utc(2020));
      client.responses['/store/index.en_US.json'] = (_) => _Response(304, '');
      final before = DateTime.now().toUtc();
      await service.refresh(source);
      expect((await service.cachedAt(source))!.isBefore(before), isFalse);
      final updated =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect({...updated}..remove('at'), {...saved}..remove('at'));
      expect(
        await file.parent
            .list()
            .where((entity) => entity.path.endsWith('.tmp'))
            .isEmpty,
        isTrue,
      );
      const replaced = ApplicationSource(
        id: 'fixture',
        name: 'Changed',
        url: 'https://other.invalid/store',
      );
      expect(await service.cachedAt(replaced), isNull);
      expect(await service.cachedAt(source, locale: 'fr_FR'), isNull);
      for (final damaged in [
        'not json',
        'x' * (6 * 1024 * 1024 + 1),
        jsonEncode({
          ...saved,
          'apps': [
            {'sourceId': 'other'},
          ],
        }),
      ]) {
        await file.writeAsString(damaged);
        expect(await service.cachedAt(source), isNull);
      }
    },
  );
}
