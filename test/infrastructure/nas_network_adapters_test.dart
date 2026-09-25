import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';
import 'package:valhalla/infrastructure/nas/nas_media_server_adapter.dart';
import 'package:valhalla/infrastructure/nas/nas_webdav_adapter.dart';

Future<HttpServer> serve(FutureOr<void> Function(HttpRequest) handler) async {
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

Uri endpoint(HttpServer server, [String path = '/']) =>
    Uri.parse('http://127.0.0.1:${server.port}$path');
NasSource source(
  HttpServer server, {
  NasSourceType type = NasSourceType.webdav,
  String path = '/',
}) => NasSource(
  id: 'source',
  name: 'NAS',
  type: type,
  endpoint: endpoint(server, path).toString(),
  username: 'alice',
  userId: 'user',
);
Map<String, dynamic> media(int index) => {
  'Id': 'item$index',
  'Name': 'Song $index',
  'MediaType': 'Audio',
  'Path': '/music/song$index.mp3',
  'RunTimeTicks': 25000000,
  'Artists': ['Artist'],
  'Album': 'Album',
  'UserData': {'IsFavorite': true},
  'PlaylistItemId': 'entry$index',
  'MediaSources': [
    {'Size': 12345},
  ],
};
void jsonResponse(HttpRequest request, Object data) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(data));
}

void main() {
  test(
    'gzip metadata after Basic auth supports DAV and JSON without weakening Range checks',
    () async {
      final server = await serve((request) {
        if (request.headers.value(HttpHeaders.authorizationHeader) == null) {
          request.response.statusCode = 401;
          request.response.headers.set(
            HttpHeaders.wwwAuthenticateHeader,
            'Basic realm="fixture"',
          );
          return;
        }
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        if (request.method == 'PROPFIND') {
          request.response.statusCode = 207;
          request.response.add(
            gzip.encode(
              utf8.encode(
                '<D:multistatus xmlns:D="DAV:"><D:response>'
                '<D:href>/dav/Music%2060s.mp3</D:href><D:propstat><D:prop>'
                '<D:getcontentlength>42</D:getcontentlength><D:resourcetype/>'
                '</D:prop><D:status>HTTP/1.1 200 OK</D:status>'
                '</D:propstat></D:response></D:multistatus>',
              ),
            ),
          );
        } else if (request.uri.path == '/metadata') {
          request.response.add(gzip.encode(utf8.encode('{"Name":"音乐"}')));
        } else {
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 2-4/10',
          );
          request.response.add(gzip.encode([2, 3, 4]));
        }
      });
      final adapter = NasWebDavAdapter(
        source(server, path: '/dav'),
        const NasCredentials(password: 'fixture-password'),
      );
      addTearDown(adapter.dispose);
      await adapter.probe();
      final batches = await adapter
          .scan(const NasScanConfig(), NasCancellation())
          .toList();
      expect(batches.single.single.name, 'Music 60s.mp3');
      final client = NasHttpClient(
        endpoint(server),
        username: 'alice',
        password: 'fixture-password',
      );
      addTearDown(client.close);
      expect(await client.json('GET', endpoint(server, '/metadata')), {
        'Name': '音乐',
      });
      await expectLater(
        client
            .readRange(endpoint(server, '/media'), 2, 5, NasCancellation())
            .drain<void>(),
        throwsA(
          isA<NasHttpException>().having(
            (error) => error.code,
            'code',
            'NAS_UNSUPPORTED_CONTENT_ENCODING',
          ),
        ),
      );
    },
  );

  test(
    'Emby direct playback has distinct resource sessions and reports DirectPlay',
    () async {
      final reports = <Map<String, dynamic>>[];
      final server = await serve((request) async {
        reports.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = 204;
      });
      final adapter = NasMediaServerAdapter(
        source(server, type: NasSourceType.emby),
        const NasCredentials(token: 'token'),
      );
      addTearDown(adapter.dispose);
      const item = NasMediaItem(
        serverId: 'source',
        path: 'item1',
        kind: NasMediaKind.audio,
        sizeBytes: 100,
        modifiedEpoch: 0,
      );
      final first = await adapter.resolve(item),
          second = await adapter.resolve(item);
      expect(first.playSessionId, isNotEmpty);
      expect(first.playSessionId, isNot(second.playSessionId));
      for (final event in ['start', 'progress', 'stop']) {
        await adapter.reportPlayback(
          item,
          const Duration(seconds: 3),
          event: event,
          playSessionId: first.playSessionId,
        );
      }
      expect(reports.map((body) => body['PlaySessionId']).toSet(), {
        first.playSessionId,
      });
      expect(reports.map((body) => body['PlayMethod']).toSet(), {'DirectPlay'});
      await adapter.reportPlayback(item, Duration.zero, event: 'start');
      await adapter.reportPlayback(
        item,
        const Duration(seconds: 1),
        event: 'stop',
      );
      expect(reports[3]['PlaySessionId'], isNotEmpty);
      expect(reports[3]['PlaySessionId'], reports[4]['PlaySessionId']);
      await adapter.reportPlayback(
        item,
        Duration.zero,
        event: 'start',
        playSessionId: 'server-session',
      );
      expect(reports.last['PlayMethod'], 'Transcode');
    },
  );
  test(
    'Jellyfin 12 duplicate media IDs never remove or reorder multiple entries silently',
    () async {
      var mutations = 0;
      final server = await serve((request) {
        if (request.method != 'GET') mutations++;
        jsonResponse(request, {
          'Items': [
            {...media(1), 'PlaylistItemId': 'item1'},
            {...media(1), 'PlaylistItemId': 'item1'},
          ],
          'TotalRecordCount': 2,
        });
      });
      final adapter = NasMediaServerAdapter(
        source(server, type: NasSourceType.jellyfin),
        const NasCredentials(token: 'token'),
      );
      addTearDown(adapter.dispose);
      final ambiguous = isA<NasHttpException>().having(
        (e) => e.code,
        'code',
        'NAS_PLAYLIST_AMBIGUOUS_ENTRY',
      );
      await expectLater(
        adapter.removeFromPlaylist('list', 'item1'),
        throwsA(ambiguous),
      );
      await expectLater(
        adapter.movePlaylistItem('list', 'item1', 0),
        throwsA(ambiguous),
      );
      expect(mutations, 0);
    },
  );
  test(
    'remote playlist playback can continue independently from a nonzero cursor',
    () async {
      final server = await serve((request) {
        expect(request.uri.path, '/Playlists/list/Items');
        expect(request.uri.queryParameters['StartIndex'], '200');
        jsonResponse(request, {
          'Items': [media(200)],
          'TotalRecordCount': 201,
        });
      });
      final adapter = NasMediaServerAdapter(
        source(server, type: NasSourceType.jellyfin),
        const NasCredentials(token: 'token'),
      );
      addTearDown(adapter.dispose);
      final pages = await adapter
          .playlistItems('list', NasCancellation(), startIndex: 200)
          .toList();
      expect(pages.single.single.path, 'item200');
    },
  );

  test(
    'unauthenticated HTTP original is directly castable and retains a bounded reader',
    () async {
      final server = await serve((request) {});
      final adapter = NasWebDavAdapter(
        NasSource(
          id: 'source',
          name: 'Public',
          type: NasSourceType.webdav,
          endpoint: endpoint(server, '/song.mp3').toString(),
        ),
        const NasCredentials(),
      );
      addTearDown(adapter.dispose);
      final resource = await adapter.resolve(
        const NasMediaItem(
          serverId: 'source',
          path: '/song.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: 10,
          modifiedEpoch: 0,
        ),
      );
      expect(resource.uri, endpoint(server, '/song.mp3'));
      expect(resource.read, isNotNull);
      expect(resource.headers, isEmpty);
    },
  );
  test(
    'JSON parse and permission errors never expose a server response token',
    () async {
      final server = await serve((request) {
        request.response.statusCode = request.uri.path == '/denied' ? 403 : 200;
        request.response.write('malformed secret-token');
      });
      final client = NasHttpClient(endpoint(server));
      addTearDown(client.close);
      await expectLater(
        client.json('GET', endpoint(server)),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.toString(),
            'safe message',
            'NAS_INVALID_RESPONSE',
          ),
        ),
      );
      await expectLater(
        client.json('POST', endpoint(server, '/denied')),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.toString(),
            'safe message',
            'NAS_HTTP_ERROR:403',
          ),
        ),
      );
    },
  );

  test('shared resource reader stops on a truncated range', () async {
    final server = await serve((request) {
      request.response.statusCode = 206;
      request.response.headers.set('Content-Range', 'bytes 4-5/10');
      request.response.add([4]);
    });
    await expectLater(
      readNasResource(
        NasResource(uri: endpoint(server)),
        4,
        6,
        NasCancellation(),
      ).drain<void>(),
      throwsA(
        isA<NasHttpException>().having(
          (e) => e.code,
          'code',
          'NAS_TRUNCATED_RESPONSE',
        ),
      ),
    );
  });

  test(
    'HTML login pages and DAV access-denied members fail scans instead of emptying an index',
    () async {
      var denied = false;
      final server = await serve((request) {
        request.response.write(
          denied
              ? '<D:multistatus xmlns:D="DAV:"><D:response><D:href>/private/</D:href><D:status>HTTP/1.1 403 Forbidden</D:status></D:response></D:multistatus>'
              : '<html><body>login</body></html>',
        );
      });
      final adapter = NasWebDavAdapter(source(server), const NasCredentials());
      addTearDown(adapter.dispose);
      await expectLater(
        adapter.scan(const NasScanConfig(), NasCancellation()).drain<void>(),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.code,
            'code',
            'NAS_INVALID_DAV_RESPONSE',
          ),
        ),
      );
      denied = true;
      await expectLater(
        adapter.scan(const NasScanConfig(), NasCancellation()).drain<void>(),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.code,
            'code',
            'NAS_DAV_PARTIAL_FAILURE',
          ),
        ),
      );
    },
  );

  test('deleting a playlist refuses an ordinary remote media item', () async {
    var deletes = 0;
    final server = await serve((request) {
      if (request.method == 'DELETE') deletes++;
      jsonResponse(request, {'Id': 'movie', 'Type': 'Movie'});
    });
    final adapter = NasMediaServerAdapter(
      source(server, type: NasSourceType.jellyfin),
      const NasCredentials(token: 'token'),
    );
    addTearDown(adapter.dispose);
    await expectLater(
      adapter.deletePlaylist('movie'),
      throwsA(isA<NasHttpException>()),
    );
    expect(deletes, 0);
  });
  test(
    'HTTP Basic auth and exact/suffix-independent Range reads use bounded stream',
    () async {
      final seen = <String?>[];
      final server = await serve((request) {
        seen.add(request.headers.value(HttpHeaders.authorizationHeader));
        if (seen.last == null) {
          request.response.statusCode = 401;
          request.response.headers.set(
            'WWW-Authenticate',
            'Basic realm="files"',
          );
          return;
        }
        expect(seen.last, 'Basic ${base64Encode(utf8.encode('alice:secret'))}');
        expect(request.headers.value('Range'), 'bytes=2-4');
        request.response.statusCode = 206;
        request.response.headers.set('Content-Range', 'bytes 2-4/10');
        request.response.add([2, 3, 4]);
      });
      final client = NasHttpClient(
        endpoint(server),
        username: 'alice',
        password: 'secret',
      );
      addTearDown(client.close);
      expect(
        await client
            .readRange(endpoint(server), 2, 5, NasCancellation())
            .expand((e) => e)
            .toList(),
        [2, 3, 4],
      );
      expect(seen.length, 2);
    },
  );

  test(
    'native HTTP Digest sends a challenge response without sending password',
    () async {
      final server = await serve((request) {
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (auth == null) {
          request.response.statusCode = 401;
          request.response.headers.set(
            'WWW-Authenticate',
            'Digest realm="files", nonce="abcdef", qop="auth", algorithm=MD5',
          );
        } else {
          expect(auth, startsWith('Digest '));
          expect(auth, contains('username="alice"'));
          expect(auth, isNot(contains('secret')));
          request.response.write('ok');
        }
      });
      final client = NasHttpClient(
        endpoint(server),
        username: 'alice',
        password: 'secret',
      );
      addTearDown(client.close);
      final response = await client.open('GET', endpoint(server));
      expect(await response.bytes.transform(utf8.decoder).join(), 'ok');
    },
  );

  test(
    'cross-origin redirect never sends a token to the destination',
    () async {
      var leaked = false;
      final destination = await serve((request) {
        leaked = true;
      });
      final server = await serve((request) {
        request.response.statusCode = 302;
        request.response.headers.set(
          'Location',
          endpoint(destination).toString(),
        );
      });
      final client = NasHttpClient(
        endpoint(server),
        headers: {'X-Emby-Token': 'secret'},
      );
      addTearDown(client.close);
      await expectLater(
        client.open('GET', endpoint(server)),
        throwsA(
          isA<NasHttpException>().having(
            (e) => e.code,
            'code',
            'NAS_CROSS_ORIGIN',
          ),
        ),
      );
      expect(leaked, false);
    },
  );

  test(
    'Range ignored by server fails instead of returning wrong bytes',
    () async {
      final server = await serve((request) {
        request.response.write('whole file');
      });
      final client = NasHttpClient(endpoint(server));
      addTearDown(client.close);
      await expectLater(
        client
            .readRange(endpoint(server), 2, 5, NasCancellation())
            .drain<void>(),
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
    'cancellation aborts an HTTP operation while waiting for headers',
    () async {
      final arrived = Completer<void>();
      final finish = Completer<void>();
      addTearDown(() {
        if (!finish.isCompleted) finish.complete();
      });
      final server = await serve((request) async {
        arrived.complete();
        await finish.future;
      });
      final client = NasHttpClient(endpoint(server));
      addTearDown(client.close);
      final cancel = NasCancellation();
      final operation = client.open(
        'GET',
        endpoint(server),
        cancellation: cancel,
      );
      final expected = expectLater(operation, throwsA(isA<NasCancelled>()));
      await arrived.future;
      cancel.cancel();
      await expected.timeout(const Duration(seconds: 2));
    },
  );

  test(
    'DAV incrementally traverses depth one, excludes folders and yields bounded batches',
    () async {
      final requests = <String>[];
      String entry(String href, {bool directory = false}) =>
          '<D:response><D:href>$href</D:href><D:propstat><D:prop>'
          '<D:resourcetype>${directory ? '<D:collection/>' : ''}</D:resourcetype>'
          '<D:getcontentlength>12</D:getcontentlength><D:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</D:getlastmodified>'
          '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>';
      final server = await serve((request) async {
        expect(request.method, 'PROPFIND');
        expect(request.headers.value('Depth'), '1');
        requests.add(request.uri.path);
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        final xml =
            '<D:multistatus xmlns:D="DAV:">${entry(request.uri.path, directory: true)}'
            '${request.uri.path == '/dav/' ? '${entry('/dav/music/', directory: true)}${entry('/dav/private/', directory: true)}'
                      '${List.generate(130, (i) => entry('/dav/照片$i.jpg')).join()}' : entry('/dav/music/song.mp3')}'
            '</D:multistatus>';
        final bytes = utf8.encode(xml);
        for (var i = 0; i < bytes.length; i += 127) {
          request.response.add(
            bytes.sublist(i, (i + 127).clamp(0, bytes.length)),
          );
        }
      });
      final adapter = NasWebDavAdapter(
        source(server, path: '/dav'),
        const NasCredentials(),
      );
      addTearDown(adapter.dispose);
      final batches = await adapter
          .scan(
            const NasScanConfig(excludePaths: ['/private']),
            NasCancellation(),
          )
          .toList();
      expect(batches.map((b) => b.length), [128, 3]);
      expect(
        batches
            .expand((b) => b)
            .where((i) => i.kind == NasMediaKind.audio)
            .length,
        1,
      );
      expect(batches.first.first.name, '照片0.jpg');
      expect(requests, ['/dav/', '/dav/music/']);
    },
  );

  for (final type in [NasSourceType.jellyfin, NasSourceType.emby]) {
    test(
      '${type.name} paged indexing and duplicate playlist entry identity',
      () async {
        final offsets = <int>[];
        final server = await serve((request) {
          final index = int.parse(request.uri.queryParameters['StartIndex']!);
          offsets.add(index);
          expect(
            request.uri.path,
            type == NasSourceType.jellyfin ? '/Items' : '/Users/user/Items',
          );
          expect(request.uri.queryParameters['Limit'], '200');
          if (type == NasSourceType.emby) {
            expect(request.headers.value('X-Emby-Token'), 'token');
          } else {
            expect(
              request.headers.value('Authorization'),
              contains('Token="token"'),
            );
          }
          jsonResponse(request, {
            'Items': List.generate(
              index == 0 ? 200 : 1,
              (i) => media(i + index),
            ),
            'TotalRecordCount': 201,
          });
        });
        final adapter = NasMediaServerAdapter(
          source(server, type: type),
          const NasCredentials(token: 'token'),
        );
        addTearDown(adapter.dispose);
        final pages = await adapter
            .scan(const NasScanConfig(), NasCancellation())
            .toList();
        expect(offsets, [0, 200]);
        expect(pages.map((p) => p.length), [200, 1]);
        expect(pages.last.single.playlistEntryId, 'entry200');
        expect(pages.first.first.sourcePath, '/music/song0.mp3');
        expect(pages.first.first.isFavorite, true);
        expect(pages.first.first.duration, const Duration(milliseconds: 2500));
      },
    );

    test(
      '${type.name} login, favorite, playlist writes and playback use immediate API acknowledgements',
      () async {
        final seen = <(String, String, Map<String, String>, Object?)>[];
        final server = await serve((request) async {
          final text = await utf8.decoder.bind(request).join();
          if (text.isNotEmpty) {
            // Real Emby 4.10 rejects chunked JSON, including authentication.
            expect(request.headers.contentLength, utf8.encode(text).length);
            expect(request.headers.chunkedTransferEncoding, isFalse);
          }
          final body = text.isEmpty ? null : jsonDecode(text);
          seen.add((
            request.method,
            request.uri.path,
            request.uri.queryParameters,
            body,
          ));
          if (request.uri.path.endsWith('AuthenticateByName')) {
            jsonResponse(request, {
              'AccessToken': 'access',
              'User': {'Id': 'user'},
            });
          } else if (request.uri.path == '/Playlists') {
            jsonResponse(request, {'Id': 'playlist'});
          } else if (request.method == 'GET' &&
              request.uri.path == '/Playlists/playlist/Items') {
            jsonResponse(request, {
              'Items': [
                {...media(1), 'PlaylistItemId': 'duplicate-entry'},
              ],
              'TotalRecordCount': 1,
            });
          } else if (request.uri.path == '/Users/user/Items/item1') {
            jsonResponse(request, {
              'UserData': {'PlaybackPositionTicks': 10000000},
            });
          } else {
            request.response.statusCode = 204;
          }
        });
        final src = source(server, type: type);
        final login = await NasMediaServerAdapter.authenticate(src, 'secret');
        expect(login.credentials.token, 'access');
        expect(login.userId, 'user');
        final adapter = NasMediaServerAdapter(src, login.credentials);
        addTearDown(adapter.dispose);
        const item = NasMediaItem(
          serverId: 'source',
          path: 'item1',
          kind: NasMediaKind.audio,
          sizeBytes: 2,
          modifiedEpoch: 0,
        );
        await adapter.setFavorite(item, true);
        expect(await adapter.createPlaylist('mix'), 'playlist');
        await adapter.addToPlaylist('playlist', item);
        await adapter.removeFromPlaylist('playlist', 'duplicate-entry');
        await adapter.movePlaylistItem('playlist', 'duplicate-entry', 2);
        expect(await adapter.resumePosition(item), const Duration(seconds: 1));
        await adapter.reportPlayback(
          item,
          const Duration(seconds: 3),
          event: 'stop',
        );
        expect(seen.first.$4, {'Username': 'alice', 'Pw': 'secret'});
        expect(
          seen.any(
            (s) => s.$1 == 'DELETE' && s.$3['EntryIds'] == 'duplicate-entry',
          ),
          true,
        );
        expect(
          seen.any(
            (s) => s.$2 == '/Playlists/playlist/Items/duplicate-entry/Move/2',
          ),
          true,
        );
        expect((seen.last.$4 as Map)['PositionTicks'], 30000000);
      },
    );
  }

  test('media server cancellation does not fetch the following page', () async {
    var count = 0;
    final server = await serve((request) {
      count++;
      jsonResponse(request, {
        'Items': List.generate(200, media),
        'TotalRecordCount': 1000000,
      });
    });
    final adapter = NasMediaServerAdapter(
      source(server, type: NasSourceType.jellyfin),
      const NasCredentials(token: 'token'),
    );
    addTearDown(adapter.dispose);
    final cancel = NasCancellation();
    await expectLater(
      adapter.scan(const NasScanConfig(), cancel).map((batch) {
        cancel.cancel();
        return batch;
      }).drain<void>(),
      throwsA(isA<NasCancelled>()),
    );
    expect(count, 1);
  });

  test(
    'transcoding negotiates a bitrate and keeps API token out of resource URI',
    () async {
      final server = await serve((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['MaxStreamingBitrate'], 4000000);
        expect(body['EnableDirectPlay'], false);
        jsonResponse(request, {
          'PlaySessionId': 'session',
          'MediaSources': [
            {
              'TranscodingUrl':
                  '/Videos/item/master.m3u8?api_key=secret&PlaySessionId=session',
            },
          ],
        });
      });
      final adapter = NasMediaServerAdapter(
        source(server, type: NasSourceType.jellyfin),
        const NasCredentials(token: 'secret'),
      );
      addTearDown(adapter.dispose);
      final resource = await adapter.resolve(
        const NasMediaItem(
          serverId: 'source',
          path: 'item',
          kind: NasMediaKind.video,
          sizeBytes: 100,
          modifiedEpoch: 0,
        ),
        quality: NasPlaybackQuality.mbps4,
      );
      expect(resource.uri.toString(), isNot(contains('secret')));
      expect(resource.headers['Authorization'], contains('secret'));
      expect(resource.playSessionId, 'session');
    },
  );
}
