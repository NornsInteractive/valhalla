import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';
import 'package:valhalla/infrastructure/nas/nas_media_server_adapter.dart';
import 'package:valhalla/infrastructure/nas/nas_smb_adapter.dart';
import 'package:valhalla/infrastructure/nas/nas_webdav_adapter.dart';
import 'package:valhalla_smb/valhalla_smb.dart';

import 'nas_network_adapters_test.dart' as fixture;

String _davEntry(String href, {bool directory = false}) =>
    '<D:response><D:href>${const HtmlEscape().convert(href)}</D:href><D:propstat><D:prop>'
    '<D:resourcetype>${directory ? '<D:collection/>' : ''}</D:resourcetype>'
    '<D:getcontentlength>12</D:getcontentlength>'
    '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>';

const _libraries = [
  {'Id': 'lib-a', 'Name': 'Same name', 'IsFolder': true},
  {'Id': 'lib-b', 'Name': 'Same name', 'IsFolder': true},
];

void main() {
  test(
    'native SMB endpoint base is bound once and configured root is only a default',
    () async {
      final adapter = NasSmbAdapter(
        source: const NasSource(
          id: 'smb',
          name: 'SMB',
          type: NasSourceType.smb,
          endpoint: 'smb://127.0.0.1:14455/media/excluded',
          username: 'valhalla',
          rootPath: '/not-appended',
        ),
        credentials: const NasCredentials(password: 'test-password'),
      );
      addTearDown(adapter.dispose);
      final entries = (await adapter.browse('/', NasCancellation()).toList())
          .expand((page) => page)
          .toList();
      expect(entries.single.id, '/skip.mp3');
      final scanned =
          (await adapter
                  .scan(
                    const NasScanConfig(includePaths: ['/']),
                    NasCancellation(),
                  )
                  .toList())
              .expand((page) => page)
              .toList();
      expect(scanned.single.path, '/skip.mp3');
      for (final invalid in ['/../secret', r'/bad\path']) {
        await expectLater(
          adapter.browse(invalid, NasCancellation()).drain<void>(),
          throwsA(isA<SmbException>().having(
            (error) => error.message,
            'code',
            'SMB_INVALID_PATH',
          )),
        );
      }
      expect(
        (await adapter.browse('/', NasCancellation()).toList())
            .single
            .single
            .id,
        '/skip.mp3',
      );
    },
    skip: Platform.environment['VALHALLA_SMB_TEST_LIBRARY'] == null
        ? 'Requires local SMB fixture and native library search path'
        : false,
  );

  test(
    'WebDAV browse is single layer, bounded and rejects escaped neighbours',
    () async {
      final requests = <Uri>[];
      final server = await fixture.serve((request) {
        requests.add(request.uri);
        expect(request.method, 'PROPFIND');
        expect(request.headers.value('Depth'), '1');
        request.response.statusCode = 207;
        request.response.write(
          '<D:multistatus xmlns:D="DAV:">'
          '${_davEntry(request.uri.path, directory: true)}'
          '${_davEntry("folder/", directory: true)}'
          '${List.generate(130, (i) => _davEntry("photo-$i.jpg")).join()}'
          '${_davEntry("../outside.jpg")}'
          '${_davEntry("nested/descendant.jpg")}'
          '${_davEntry("https://invalid.example/secret.jpg")}'
          '${_davEntry("bad%2Fslash.jpg")}'
          '${_davEntry("bad%00name.jpg")}'
          '${_davEntry("%2e%2e/")}'
          '</D:multistatus>',
        );
      });
      final adapter = NasWebDavAdapter(
        NasSource(
          id: 'dav',
          name: 'DAV',
          type: NasSourceType.webdav,
          endpoint: fixture.endpoint(server, '/base').toString(),
          rootPath: '/configured',
        ),
        const NasCredentials(),
      );
      addTearDown(adapter.dispose);
      final pages = await adapter.browse('/', NasCancellation()).toList();
      expect(requests.map((uri) => uri.path), ['/base/configured/']);
      expect(pages.map((page) => page.length), [128, 3]);
      expect(pages.first.first.id, '/folder');
      expect(pages.first.first.canEnter, isTrue);
      expect(
        pages
            .expand((page) => page)
            .any((entry) => entry.name.contains('outside')),
        isFalse,
      );
    },
  );

  test(
    'WebDAV literal percent, unicode and special directory names round trip',
    () async {
      final requests = <Uri>[];
      const names = ['照片 空格', '100%', '%2e%2e', 'star[*?]', r'back\slash'];
      final server = await fixture.serve((request) {
        requests.add(request.uri);
        request.response.statusCode = 207;
        final children = requests.length == 1
            ? names
                  .map(
                    (name) => _davEntry(
                      '${Uri.encodeComponent(name)}/',
                      directory: true,
                    ),
                  )
                  .join()
            : _davEntry('inside.jpg');
        request.response.write(
          '<D:multistatus xmlns:D="DAV:">$children</D:multistatus>',
        );
      });
      final adapter = NasWebDavAdapter(
        NasSource(
          id: 'dav',
          name: 'DAV',
          type: NasSourceType.webdav,
          endpoint: fixture.endpoint(server, '/base').toString(),
          rootPath: '/100%/资料',
        ),
        const NasCredentials(),
      );
      addTearDown(adapter.dispose);
      final entries = (await adapter.browse('/', NasCancellation()).toList())
          .expand((page) => page)
          .toList();
      expect(entries.map((entry) => entry.name), names);
      for (final entry in entries) {
        final items = await adapter
            .browse(entry.id, NasCancellation())
            .toList();
        expect(items.single.single.id, '${entry.id}/inside.jpg');
        expect(requests.last.pathSegments, [
          'base',
          '100%',
          '资料',
          entry.name,
          '',
        ]);
      }
    },
  );

  test(
    'WebDAV cancellation aborts browse while waiting for response headers',
    () async {
      final arrived = Completer<void>();
      final finish = Completer<void>();
      addTearDown(() {
        if (!finish.isCompleted) finish.complete();
      });
      final server = await fixture.serve((request) async {
        arrived.complete();
        await finish.future;
      });
      final adapter = NasWebDavAdapter(
        fixture.source(server),
        const NasCredentials(),
      );
      addTearDown(adapter.dispose);
      final cancellation = NasCancellation();
      final done = expectLater(
        adapter.browse('/', cancellation).drain<void>(),
        throwsA(isA<NasCancelled>()),
      );
      await arrived.future;
      cancellation.cancel();
      await done.timeout(const Duration(seconds: 3));
    },
  );

  for (final type in [NasSourceType.jellyfin, NasSourceType.emby]) {
    test(
      '${type.name} browse returns flat library IDs, not names as paths',
      () async {
        final requests = <Uri>[];
        final server = await fixture.serve((request) {
          requests.add(request.uri);
          fixture.jsonResponse(request, {
            'Items': _libraries,
            'TotalRecordCount': 2,
          });
        });
        final adapter = NasMediaServerAdapter(
          fixture.source(server, type: type),
          const NasCredentials(token: 'fixture'),
        );
        addTearDown(adapter.dispose);
        final entries = (await adapter.browse('/', NasCancellation()).toList())
            .expand((page) => page)
            .toList();
        expect(entries.map((entry) => entry.id), ['lib-a', 'lib-b']);
        expect(
          entries.every(
            (entry) =>
                entry.name == 'Same name' &&
                entry.isDirectory &&
                !entry.canEnter,
          ),
          isTrue,
        );
        expect(requests.single.path, '/Users/user/Views');
        expect(
          requests.single.queryParameters['IncludeExternalContent'],
          'false',
        );
        await expectLater(
          adapter.browse('/lib-a', NasCancellation()).drain<void>(),
          throwsA(
            isA<NasHttpException>().having(
              (error) => error.code,
              'code',
              'NAS_INVALID_PATH',
            ),
          ),
        );
        expect(requests, hasLength(1));
      },
    );

    for (final excluded in [
      const ['lib-a'],
      const ['lib-a', 'lib-b'],
    ]) {
      test(
        '${type.name} excluded libraries $excluded are never queried',
        () async {
          final parents = <String?>[];
          final server = await fixture.serve((request) {
            if (request.uri.path.endsWith('/Views')) {
              fixture.jsonResponse(request, {'Items': _libraries});
            } else {
              parents.add(request.uri.queryParameters['ParentId']);
              fixture.jsonResponse(request, {
                'Items': [fixture.media(1)],
                'TotalRecordCount': 1,
              });
            }
          });
          final adapter = NasMediaServerAdapter(
            fixture.source(server, type: type),
            const NasCredentials(token: 'fixture'),
          );
          addTearDown(adapter.dispose);
          final items =
              (await adapter
                      .scan(
                        NasScanConfig(excludePaths: excluded),
                        NasCancellation(),
                      )
                      .toList())
                  .expand((page) => page)
                  .toList();
          expect(parents, excluded.length == 1 ? ['lib-b'] : isEmpty);
          expect(items.length, excluded.length == 1 ? 1 : 0);
        },
      );
    }

    test(
      '${type.name} legacy folder, item ID and physical subtree exclusions remain literal',
      () async {
        final server = await fixture.serve((request) {
          if (request.uri.path.endsWith('/Views')) {
            fixture.jsonResponse(request, {'Items': _libraries});
          } else if (request.uri.path.endsWith('/Items/old-folder')) {
            fixture.jsonResponse(request, {
              'Id': 'old-folder',
              'IsFolder': true,
              'Path': '/music/private[1]',
            });
          } else if (request.uri.path.endsWith('/Items/item4')) {
            fixture.jsonResponse(request, {
              ...fixture.media(4),
              'IsFolder': false,
            });
          } else {
            fixture.jsonResponse(request, {
              'Items': [
                {...fixture.media(1), 'Path': '/music/private[1]/secret.mp3'},
                {...fixture.media(2), 'Path': '/music/private1/keep.mp3'},
                {...fixture.media(3), 'Path': '/music/hidden/secret.mp3'},
                fixture.media(4),
              ],
              'TotalRecordCount': 4,
            });
          }
        });
        final adapter = NasMediaServerAdapter(
          fixture.source(server, type: type),
          const NasCredentials(token: 'fixture'),
        );
        addTearDown(adapter.dispose);
        final items =
            (await adapter
                    .scan(
                      const NasScanConfig(
                        includePaths: ['lib-a'],
                        excludePaths: ['old-folder', 'item4', '/music/hidden'],
                      ),
                      NasCancellation(),
                    )
                    .toList())
                .expand((page) => page)
                .toList();
        expect(items.map((item) => item.path), ['item2']);
      },
    );

    test(
      '${type.name} physical includes filter by subtree, not glob or prefix sibling',
      () async {
        final server = await fixture.serve((request) {
          if (request.uri.path.endsWith('/Views')) {
            fixture.jsonResponse(request, {
              'Items': [_libraries.first],
            });
          } else {
            fixture.jsonResponse(request, {
              'Items': [
                {...fixture.media(1), 'Path': '/music[1]/yes.mp3'},
                {...fixture.media(2), 'Path': '/music1/no.mp3'},
                {...fixture.media(3), 'Path': '/music[1]-other/no.mp3'},
              ],
              'TotalRecordCount': 3,
            });
          }
        });
        final adapter = NasMediaServerAdapter(
          fixture.source(server, type: type),
          const NasCredentials(),
        );
        addTearDown(adapter.dispose);
        final items =
            (await adapter
                    .scan(
                      const NasScanConfig(includePaths: ['/music[1]']),
                      NasCancellation(),
                    )
                    .toList())
                .expand((page) => page);
        expect(items.map((item) => item.path), ['item1']);
      },
    );

    test(
      '${type.name} nested legacy include cannot bypass excluded parent library',
      () async {
        final requestedItems = <String>[];
        final server = await fixture.serve((request) {
          if (request.uri.path.endsWith('/Views')) {
            fixture.jsonResponse(request, {'Items': _libraries});
          } else if (request.uri.path.endsWith('/Items/old-folder')) {
            fixture.jsonResponse(request, {
              'Id': 'old-folder',
              'IsFolder': true,
              'ParentId': 'lib-a',
            });
          } else {
            requestedItems.add(request.uri.path);
            fixture.jsonResponse(request, {
              'Items': [fixture.media(1)],
              'TotalRecordCount': 1,
            });
          }
        });
        final adapter = NasMediaServerAdapter(
          fixture.source(server, type: type),
          const NasCredentials(),
        );
        addTearDown(adapter.dispose);
        expect(
          await adapter
              .scan(
                const NasScanConfig(
                  includePaths: ['old-folder'],
                  excludePaths: ['lib-a'],
                ),
                NasCancellation(),
              )
              .toList(),
          isEmpty,
        );
        expect(requestedItems, isEmpty);
      },
    );

    for (final missing in ['folder path', 'item path']) {
      test('${type.name} unresolved $missing fails closed', () async {
        final server = await fixture.serve((request) {
          if (request.uri.path.endsWith('/Views')) {
            fixture.jsonResponse(request, {'Items': _libraries});
          } else if (request.uri.path.endsWith('/Items/old-folder')) {
            fixture.jsonResponse(request, {
              'Id': 'old-folder',
              'IsFolder': true,
            });
          } else {
            final item = fixture.media(1)..remove('Path');
            fixture.jsonResponse(request, {
              'Items': [item],
              'TotalRecordCount': 1,
            });
          }
        });
        final adapter = NasMediaServerAdapter(
          fixture.source(server, type: type),
          const NasCredentials(),
        );
        addTearDown(adapter.dispose);
        final config = NasScanConfig(
          excludePaths: [missing == 'folder path' ? 'old-folder' : '/private'],
        );
        await expectLater(
          adapter.scan(config, NasCancellation()).drain<void>(),
          throwsA(
            isA<NasHttpException>().having(
              (error) => error.code,
              'code',
              'NAS_SCAN_FILTER_UNRESOLVED',
            ),
          ),
        );
      });
    }

    for (final response in ['empty', 'malformed', 'unauthorized']) {
      test(
        '${type.name} $response library response never broadens a filtered scan',
        () async {
          final requests = <String>[];
          final server = await fixture.serve((request) {
            requests.add(request.uri.path);
            if (response == 'unauthorized') {
              request.response.statusCode = 401;
            } else {
              fixture.jsonResponse(request, {
                'Items': response == 'empty'
                    ? []
                    : [
                        {'Name': 'missing id'},
                      ],
              });
            }
          });
          final adapter = NasMediaServerAdapter(
            fixture.source(server, type: type),
            const NasCredentials(),
          );
          addTearDown(adapter.dispose);
          final scan = adapter
              .scan(
                const NasScanConfig(includePaths: ['/music']),
                NasCancellation(),
              )
              .toList();
          if (response == 'empty') {
            expect(await scan, isEmpty);
          } else {
            await expectLater(scan, throwsA(isA<NasHttpException>()));
          }
          expect(requests, ['/Users/user/Views']);
        },
      );
    }
  }
}
