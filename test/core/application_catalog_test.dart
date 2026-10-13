import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_catalog_service.dart';
import 'package:valhalla/data/models/application_center.dart';

void main() {
  final source = ApplicationSource.official;

  group('v2 envelope parsing', () {
    test('valid v2 catalog parses apps correctly', () {
      final text = jsonEncode({
        'version': 2,
        'apps': [
          {
            'id': 'myapp',
            'title': 'My App',
            'compose_url': 'https://example.com/compose',
            'tagline': 'A great app',
            'category': 'Tools',
            'version': '1.0.0',
            'content_hash': 'abc123',
            'icon': 'https://example.com/icon.png',
            'thumbnail': 'https://example.com/thumb.png',
            'meta_url': 'https://example.com/meta.json',
            'architectures': ['arm64', 'x86_64'],
          },
        ],
      });
      final result = ApplicationCatalogService.parseIndex(text, source);
      expect(result.length, 1);
      expect(result.first.id, 'myapp');
      expect(result.first.title, 'My App');
      expect(result.first.architectures, ['arm64', 'x86_64']);
    });

    test('v1 version throws APP_CENTER_SOURCE_UNSUPPORTED', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({'version': 1, 'apps': []}),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_UNSUPPORTED',
          ),
        ),
      );
    });

    test('non-list apps throws APP_CENTER_SOURCE_UNSUPPORTED', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({'version': 2, 'apps': 'not a list'}),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_UNSUPPORTED',
          ),
        ),
      );
    });
  });

  group('required ID and duplicate errors', () {
    test('invalid ID format throws APP_CENTER_CATALOG_INVALID', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({
            'version': 2,
            'apps': [
              {
                'id': 'invalid id!',
                'title': 'My App',
                'compose_url': 'https://example.com/compose',
                'tagline': 'A great app',
              },
            ],
          }),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_CATALOG_INVALID',
          ),
        ),
      );
    });

    test('duplicate IDs throw APP_CENTER_CATALOG_INVALID', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({
            'version': 2,
            'apps': [
              {
                'id': 'myapp',
                'title': 'My App',
                'compose_url': 'https://example.com/compose',
                'tagline': 'A great app',
              },
              {
                'id': 'myapp',
                'title': 'My App 2',
                'compose_url': 'https://example.com/compose2',
                'tagline': 'Another app',
              },
            ],
          }),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_CATALOG_INVALID',
          ),
        ),
      );
    });
  });

  group('HTTPS and no userinfo', () {
    test('sourceUri rejects non-https', () {
      expect(
        () => ApplicationCatalogService.sourceUri('http://example.com/store'),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_INVALID',
          ),
        ),
      );
    });

    test('sourceUri rejects userInfo', () {
      expect(
        () => ApplicationCatalogService.sourceUri(
          'https://user:pass@example.com/store',
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_INVALID',
          ),
        ),
      );
    });

    test('resourceUri rejects userInfo', () {
      final base = Uri.https('cdn.example.com', '');
      expect(
        () => ApplicationCatalogService.resourceUri(
          base,
          'https://user:pass@other.com/path',
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_INVALID',
          ),
        ),
      );
    });
  });

  group('store prefix /apps path resolution', () {
    test('resourceUri resolves /apps prefix relative to base', () {
      final base = Uri.https('cdn.example.com', '');
      expect(
        ApplicationCatalogService.resourceUri(base, '/apps/icon.png'),
        Uri.https('cdn.example.com', 'apps/icon.png'),
      );
    });

    test('resourceUri preserves absolute URL without /apps prefix', () {
      final base = Uri.https('cdn.example.com', '');
      expect(
        ApplicationCatalogService.resourceUri(
          base,
          'https://other.com/image.png',
        ),
        Uri.https('other.com', 'image.png'),
      );
    });
  });

  group('architectures and empty catalog', () {
    test('empty apps list returns empty result', () {
      final result = ApplicationCatalogService.parseIndex(
        jsonEncode({'version': 2, 'apps': []}),
        source,
      );
      expect(result, isEmpty);
    });

    test('architectures defaults to empty list when missing', () {
      final result = ApplicationCatalogService.parseIndex(
        jsonEncode({
          'version': 2,
          'apps': [
            {
              'id': 'myapp',
              'title': 'My App',
              'compose_url': 'https://example.com/compose',
              'tagline': 'A great app',
            },
          ],
        }),
        source,
      );
      expect(result.first.architectures, isEmpty);
    });
  });

  group('invalid v1/list catalog', () {
    test('v1 catalog throws APP_CENTER_SOURCE_UNSUPPORTED', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({'version': 1, 'store_id': 'x', 'apps': []}),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_UNSUPPORTED',
          ),
        ),
      );
    });

    test('missing version throws APP_CENTER_SOURCE_UNSUPPORTED', () {
      expect(
        () => ApplicationCatalogService.parseIndex(
          jsonEncode({'apps': []}),
          source,
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_SOURCE_UNSUPPORTED',
          ),
        ),
      );
    });
  });
}
