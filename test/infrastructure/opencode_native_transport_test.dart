import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/native_cli_session.dart';
import 'package:valhalla/infrastructure/cli/opencode_native_client.dart';

class _Process implements SSHSession {
  final input = StreamController<Uint8List>();
  final output = StreamController<Uint8List>();
  final errors = StreamController<Uint8List>();
  bool terminated = false;
  @override
  StreamSink<Uint8List> get stdin => input.sink;
  @override
  Stream<Uint8List> get stdout => output.stream;
  @override
  Stream<Uint8List> get stderr => errors.stream;
  @override
  void kill(SSHSignal signal) {
    terminated = signal == SSHSignal.TERM;
  }

  @override
  void close() {
    unawaited(input.close());
    unawaited(output.close());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Forward implements SSHForwardChannel {
  final Socket socket;
  _Forward(this.socket);
  @override
  Stream<Uint8List> get stream => socket;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  void destroy() => socket.destroy();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Ssh implements SSHClient {
  final int port;
  final process = _Process();
  String? command;
  _Ssh(this.port);
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    this.command = command;
    process.output.add(
      utf8.encode('opencode server listening on http://127.0.0.1:$port\n'),
    );
    return process;
  }

  @override
  Future<SSHForwardChannel> forwardLocal(
    String host,
    int port, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async {
    expect(host, '127.0.0.1');
    expect(port, this.port);
    return _Forward(await Socket.connect(host, port));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'official OpenCode HTTP/SSE is authenticated, paginated, forwards over SSH and deletes via API',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final calls = <(String, String)>[];
      final bodies = <Object?>[];
      server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          startsWith('Basic '),
        );
        calls.add((request.method, request.uri.path));
        final text = await utf8.decoder.bind(request).join();
        if (text.isNotEmpty) bodies.add(jsonDecode(text));
        request.response.headers.contentType = ContentType.json;
        switch (request.uri.path) {
          case '/doc':
            request.response.write(
              jsonEncode({
                'paths': {
                  '/session': {},
                  '/experimental/session': {},
                  '/global/event': {},
                  '/permission/{requestID}/reply': {},
                },
              }),
            );
          case '/experimental/session':
            expect(request.uri.queryParameters['limit'], '15');
            request.response.headers.set('x-next-cursor', '1234');
            request.response.write(
              jsonEncode([
                {
                  'id': 'ses-1',
                  'title': 'Native',
                  'directory': '/p',
                  'time': {'updated': 1234},
                },
              ]),
            );
          case '/global/event':
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.write(
              'data: ${jsonEncode({
                'directory': '/p',
                'payload': {
                  'type': 'session.idle',
                  'properties': {'sessionID': 'ses-1'},
                },
              })}\n\n',
            );
          case '/session/status':
            request.response.write('{}');
          case '/session/ses-1/message':
            expect(request.uri.queryParameters['limit'], '10');
            final before = request.uri.queryParameters['before'];
            final end = before == null ? 15 : int.parse(before.split('-').last);
            final start = (end - 10).clamp(0, end);
            request.response.write(
              jsonEncode([
                for (var index = start; index < end; index++)
                  {
                    'info': {'id': 'msg-$index', 'role': 'user'},
                    'parts': [
                      {'type': 'text', 'text': 'message $index'},
                    ],
                  },
              ]),
            );
          default:
            request.response.write('true');
        }
        await request.response.close();
      });
      final ssh = _Ssh(server.port);
      final client = await OpenCodeNativeClient.connect(ssh);
      addTearDown(client.close);
      final page = await client.list();
      expect(page.sessions.single.id, 'ses-1');
      expect(page.cursor, '1234');
      final recent = await client.readPage('ses-1', cwd: '/p', limit: 10);
      expect(recent.messages.first.id, 'msg-5');
      expect(recent.olderCursor, 'msg-5');
      final older = await client.readPage(
        'ses-1',
        cwd: '/p',
        limit: 10,
        cursor: recent.olderCursor,
      );
      expect(older.messages.first.id, 'msg-0');
      expect(older.olderCursor, isNull);
      final event = await client.events().first;
      expect(event['type'], 'session.idle');
      await client.send('ses-1', 'Hello', cwd: '/p');
      await client.approve(
        const NativeCliApproval(
          id: 'permission-1',
          method: 'permission.asked',
          details: {'sessionID': 'ses-1'},
        ),
        true,
        cwd: '/p',
      );
      await client.delete('ses-1', cwd: '/p');
      expect(calls, contains(('POST', '/session/ses-1/prompt_async')));
      expect(calls, contains(('DELETE', '/session/ses-1')));
      expect(bodies.last, {'reply': 'once'});
      expect(ssh.command, contains('--hostname 127.0.0.1 --port 0'));
      expect(ssh.command, isNot(contains('skip-permission')));
      await client.close();
      expect(ssh.process.terminated, isTrue);
    },
  );
}
