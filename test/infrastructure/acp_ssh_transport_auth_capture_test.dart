import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

/// Transport stderr contract: the challenge line is captured RAW from stderr
/// (even split across chunks) so the callback can be validated, while the
/// diagnostic tail that reaches logs stays redacted and bounded.
const _line =
    'Open the following link to authenticate the ACP server: '
    'https://accounts.google.com/o/oauth2/v2/auth?client_id=abc'
    '&response_type=code'
    '&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcb'
    '&state=state-1';

class _Session implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = StreamController<Uint8List>.broadcast();
  bool closed = false;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;
  @override
  Stream<Uint8List> get stderr => _stderr.stream;
  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;
  @override
  int? get exitCode => null;
  @override
  Future<void> get done => Future<void>.value();

  void emitStderr(String text) => _stderr.add(utf8.encode(text));

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_stdin.isClosed) _stdin.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Session session;
  late AcpSshTransport transport;
  late List<AcpOAuthRequest> captured;

  setUp(() {
    session = _Session();
    transport = AcpSshTransport(session);
    captured = <AcpOAuthRequest>[];
  });

  tearDown(() async {
    await transport.close();
    session.close();
  });

  test('captures a challenge line split across stderr chunks', () async {
    final sub = transport.authorizationRequests.listen(captured.add);
    addTearDown(sub.cancel);

    session.emitStderr(_line.substring(0, 40));
    await pumpEventQueue();
    session.emitStderr('${_line.substring(40)}\n');
    await pumpEventQueue();

    expect(captured, hasLength(1));
    expect(captured.single.state, 'state-1');
    expect(captured.single.redirectUri.toString(), 'http://127.0.0.1:8765/cb');
  });

  test('captures every challenge line in one stderr burst', () async {
    final sub = transport.authorizationRequests.listen(captured.add);
    addTearDown(sub.cancel);

    session.emitStderr('ignorable preamble\n$_line\n$_line\n');
    await pumpEventQueue();

    expect(captured, hasLength(2));
    expect(captured.map((r) => r.state), ['state-1', 'state-1']);
  });

  test('drops an over-cap line without poisoning later lines', () async {
    final sub = transport.authorizationRequests.listen(captured.add);
    addTearDown(sub.cancel);

    session.emitStderr('$_line&pad=${'a' * 16400}\n');
    await pumpEventQueue();
    expect(captured, isEmpty, reason: 'an oversized line is never forwarded');

    session.emitStderr('$_line\n');
    await pumpEventQueue();
    expect(captured, hasLength(1));
  });

  test('closing the transport cancels the authorization stream', () async {
    final events = <Object>[];
    final done = Completer<void>();
    transport.authorizationRequests.listen(events.add, onDone: done.complete);

    await transport.close();
    await done.future;

    expect(events, isEmpty);
    expect(session.closed, isTrue);
  });

  test(
    'keeps the raw challenge for callbacks while diagnostics are redacted',
    () async {
      final sub = transport.authorizationRequests.listen(captured.add);
      addTearDown(sub.cancel);

      session.emitStderr('token=super-secret-value\n');
      session.emitStderr('$_line\n');
      await pumpEventQueue();

      expect(captured, hasLength(1));
      expect(
        captured.single.state,
        'state-1',
        reason: 'callback validation needs the real state value',
      );
      final tail = transport.diagnosticTail;
      expect(tail, isNot(contains('super-secret-value')));
      expect(tail, contains('token=******'));
      expect(tail, contains('state=[REDACTED]'));
      expect(tail, isNot(contains('state-1')));
      expect(
        tail,
        isNot(contains('code-')),
        reason: 'authorization codes must never reach logs',
      );
    },
  );

  test('redacts private key blocks in the diagnostic tail', () async {
    session.emitStderr(
      '-----BEGIN PRIVATE KEY-----\n'
      'super-secret-key-material\n'
      '-----END PRIVATE KEY-----\n',
    );
    await pumpEventQueue();

    expect(transport.diagnosticTail, contains('[REDACTED_PRIVATE_KEY]'));
    expect(
      transport.diagnosticTail,
      isNot(contains('super-secret-key-material')),
    );
  });

  test('keeps the diagnostic tail bounded to 8192 bytes', () async {
    for (var i = 0; i < 8; i++) {
      session.emitStderr('${'a' * 4000}\n');
    }
    await pumpEventQueue();

    expect(transport.diagnosticTail, isNotEmpty);
    expect(transport.diagnosticTail.length, lessThanOrEqualTo(8192));
  });
}
