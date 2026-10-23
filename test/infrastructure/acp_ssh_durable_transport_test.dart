import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acpd/acpd.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

class _Session implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = StreamController<Uint8List>.broadcast();
  bool closed = false;
  int? exitCodeValue;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;
  @override
  Stream<Uint8List> get stderr => _stderr.stream;
  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;
  @override
  int? get exitCode => exitCodeValue;

  void emitStdout(String text) => _stdout.add(utf8.encode(text));

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
  setUp(() {
    session = _Session();
  });
  tearDown(() async {
    session.close();
  });

  test(
    'raw legacy framing still passes for non-persistent transport',
    () async {
      final transport = AcpSshTransport(session);
      final frames = <TransportFrame>[];
      final sub = transport.incoming.listen(frames.add);
      session.emitStdout('{"jsonrpc":"2.0","id":1,"result":{}}\n');
      await pumpEventQueue();
      expect(frames, hasLength(1));
      await sub.cancel();
      await transport.close();
    },
  );

  test(
    'enveloped frame preserves turn id and seq when buffered before listener',
    () async {
      final transport = AcpSshTransport(
        session,
        runtimeKey: 'rk',
        afterSequence: 0,
      );
      final line = jsonEncode({
        'type': 'frame',
        'turnId': 'turn-1',
        'seq': 7,
        'frame': {'jsonrpc': '2.0', 'method': 'session/update', 'params': {}},
      });
      // Emit before any listener subscribes.
      session.emitStdout('$line\n');
      await pumpEventQueue();
      // Cursor must not be acknowledged until a listener receives the frame.
      expect(transport.lastSequence, 0);
      final frames = <TransportFrame>[];
      final sub = transport.incoming.listen(frames.add);
      await pumpEventQueue();
      expect(frames, hasLength(1));
      expect(transport.currentTurnId, 'turn-1');
      expect(transport.lastSequence, 7);
      await sub.cancel();
      await transport.close();
    },
  );

  test('cursor not acknowledged before delivering frame', () async {
    final transport = AcpSshTransport(
      session,
      runtimeKey: 'rk',
      afterSequence: 2,
    );
    final line = jsonEncode({
      'type': 'frame',
      'turnId': 'turn-2',
      'seq': 3,
      'frame': {'jsonrpc': '2.0', 'id': 1, 'result': {}},
    });
    session.emitStdout('$line\n');
    await pumpEventQueue();
    expect(transport.lastSequence, 2, reason: 'no listener yet');
    final done = Completer<void>();
    final sub = transport.incoming.listen((_) => done.complete());
    await done.future;
    expect(transport.lastSequence, 3);
    await sub.cancel();
    await transport.close();
  });
}
