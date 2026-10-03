import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';

/// Phone-side loopback mirror contract: bind the challenge's own port, forward
/// only a callback that matches this attempt's target/state, answer with an
/// deliberately empty body, and release the port on close. Everything here is
/// local fake HTTP — no real OAuth, no external network.
const _marker = 'Open the following link to authenticate the ACP server: ';

String _authLine(int port, String state) =>
    '$_marker'
    'https://accounts.google.com/o/oauth2/v2/auth'
    '?response_type=code&client_id=cid.apps.googleusercontent.com'
    '&redirect_uri=${Uri.encodeComponent('http://127.0.0.1:$port/cb')}'
    '&state=$state';

AcpOAuthRequest _request(int port, String state) {
  final request = AcpOAuthRequest.fromLine(_authLine(port, state));
  expect(request, isNotNull, reason: 'fixture must be a valid challenge');
  return request!;
}

Future<int> _freePort() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

/// Minimal raw HTTP client so the test can forge method/host/key cardinality.
Future<String> _raw(int port, String payload, {Duration? timeout}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  socket.add(utf8.encode(payload));
  await socket.flush();
  final chunks = <int>[];
  final done = Completer<void>();
  socket.listen(chunks.addAll, onDone: done.complete, onError: (_) {});
  try {
    await done.future.timeout(
      timeout ?? const Duration(seconds: 2),
      onTimeout: () {},
    );
  } finally {
    await socket.close();
  }
  return utf8.decode(chunks, allowMalformed: true);
}

String _statusLine(String response) => response.split('\r\n').first;

void main() {
  group('AcpOAuthLoopback', () {
    late List<AcpOAuthLoopback> bound;
    late List<HttpServer> probes;

    setUp(() {
      bound = [];
      probes = [];
    });

    tearDown(() async {
      for (final server in probes) {
        await server.close(force: true);
      }
      for (final loopback in bound) {
        await loopback.close();
      }
    });

    Future<AcpOAuthLoopback> bind(
      AcpOAuthRequest request,
      Future<void> Function(String callback) deliver,
    ) async {
      final loopback = await AcpOAuthLoopback.bind(request, deliver);
      bound.add(loopback);
      return loopback;
    }

    test(
      'binds the challenge port and delivers a state-matched callback',
      () async {
        final port = await _freePort();
        final request = _request(port, 'loopback-state-1');
        final delivered = <String>[];
        await bind(request, (callback) async => delivered.add(callback));

        final response = await HttpClient()
            .getUrl(
              Uri.parse(
                'http://127.0.0.1:$port/cb?code=fake&state=loopback-state-1',
              ),
            )
            .then((r) => r.close());

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.value('Cache-Control'), 'no-store');
        expect(
          await utf8.decodeStream(response),
          isEmpty,
          reason: 'infrastructure answers with an empty body, no instructions',
        );
        expect(delivered, hasLength(1));
        final parsed = Uri.parse(delivered.single);
        expect(parsed.port, port, reason: 'callback keeps the original target');
        expect(parsed.path, '/cb');
        expect(parsed.queryParametersAll['code'], hasLength(1));
        expect(parsed.queryParametersAll['state'], ['loopback-state-1']);
      },
    );

    test('rejects a mismatched state and never delivers', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      final delivered = <String>[];
      await bind(request, (callback) async => delivered.add(callback));

      final response = await HttpClient()
          .getUrl(Uri.parse('http://127.0.0.1:$port/cb?code=fake&state=other'))
          .then((r) => r.close());

      expect(response.statusCode, HttpStatus.badRequest);
      await response.drain<void>();
      expect(delivered, isEmpty);
    });

    test('rejects duplicate query keys and never delivers', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      final delivered = <String>[];
      await bind(request, (callback) async => delivered.add(callback));

      for (final target in [
        '/cb?code=a&code=b&state=loopback-state-1',
        '/cb?code=fake&state=loopback-state-1&state=loopback-state-1',
      ]) {
        final response = await HttpClient()
            .getUrl(Uri.parse('http://127.0.0.1:$port$target'))
            .then((r) => r.close());
        expect(response.statusCode, HttpStatus.badRequest, reason: target);
        await response.drain<void>();
      }
      expect(delivered, isEmpty);
    });

    test(
      'rejects a mixed code-and-error callback and never delivers',
      () async {
        final port = await _freePort();
        final request = _request(port, 'loopback-state-1');
        final delivered = <String>[];
        await bind(request, (callback) async => delivered.add(callback));

        final response = await HttpClient()
            .getUrl(
              Uri.parse(
                'http://127.0.0.1:$port/cb?code=fake&error=denied'
                '&state=loopback-state-1',
              ),
            )
            .then((r) => r.close());

        expect(response.statusCode, HttpStatus.badRequest);
        await response.drain<void>();
        expect(delivered, isEmpty);
      },
    );

    test('rejects a foreign Host header and never delivers', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      final delivered = <String>[];
      await bind(request, (callback) async => delivered.add(callback));

      final response = await _raw(
        port,
        'GET /cb?code=fake&state=loopback-state-1 HTTP/1.1\r\n'
        'Host: 127.0.0.1:1\r\n'
        'Connection: close\r\n\r\n',
      );

      expect(_statusLine(response), contains('400'), reason: response);
      expect(delivered, isEmpty);
    });

    test('rejects a non-GET request and never delivers', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      final delivered = <String>[];
      await bind(request, (callback) async => delivered.add(callback));

      final response = await _raw(
        port,
        'POST /cb?code=fake&state=loopback-state-1 HTTP/1.1\r\n'
        'Host: 127.0.0.1:$port\r\n'
        'Content-Length: 0\r\n'
        'Connection: close\r\n\r\n',
      );

      expect(_statusLine(response), contains('400'), reason: response);
      expect(delivered, isEmpty);
    });

    test('close() releases the mirrored port', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      final loopback = await AcpOAuthLoopback.bind(request, (_) async {});

      await loopback.close();

      final rebind = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      probes.add(rebind);
      expect(rebind.port, port, reason: 'close must free the challenge port');
    });

    test('a busy redirect port fails the bind instead of listening', () async {
      // Occupy the challenge port first; bind must surface the failure so the
      // caller can report ACP_AUTH_CALLBACK_LISTENER_FAILED before a browser
      // is ever opened.
      final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      probes.add(occupied);
      final request = _request(occupied.port, 'loopback-state-1');

      await expectLater(
        AcpOAuthLoopback.bind(request, (_) async {}),
        throwsA(isA<SocketException>()),
      );

      // No loopback was mirrored: the challenge port is still held by the foreign
      // occupier, so a second bind of the same port must fail too.
      await expectLater(
        HttpServer.bind(InternetAddress.loopbackIPv4, occupied.port),
        throwsA(isA<SocketException>()),
      );

      // Once released the same challenge port binds normally again.
      await occupied.close(force: true);
      probes.remove(occupied);
      final loopback = await bind(request, (_) async {});
      await loopback.close();
    });

    test('the callback body never leaks back to the browser', () async {
      final port = await _freePort();
      final request = _request(port, 'loopback-state-1');
      await bind(request, (_) async {});

      final response = await HttpClient()
          .getUrl(
            Uri.parse(
              'http://127.0.0.1:$port/cb?code=fake&state=loopback-state-1',
            ),
          )
          .then((r) => r.close());
      final body = await utf8.decodeStream(response);

      expect(response.statusCode, HttpStatus.ok);
      expect(body, isEmpty);
      expect(body, isNot(contains('code')));
      expect(body, isNot(contains('loopback-state-1')));
    });
  });
}
