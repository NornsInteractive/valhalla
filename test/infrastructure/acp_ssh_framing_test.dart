import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

class _Session implements SSHSession {
  final input = StreamController<Uint8List>();
  final output = StreamController<Uint8List>();
  final errors = StreamController<Uint8List>();
  @override
  StreamSink<Uint8List> get stdin => input.sink;
  @override
  Stream<Uint8List> get stdout => output.stream;
  @override
  Stream<Uint8List> get stderr => errors.stream;
  @override
  void close() {
    unawaited(input.close());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'UTF-8 characters split at every byte remain valid RPC frames',
    () async {
      final session = _Session();
      final transport = AcpSshTransport(session);
      final frames = transport.incoming.toList();
      final raw = '{"jsonrpc":"2.0","id":"审批","result":{"text":"允许中文"}}\r\n';
      for (final byte in utf8.encode(raw)) {
        session.output.add(Uint8List.fromList([byte]));
      }
      await session.output.close();
      final received = await frames;
      expect(received, hasLength(1));
      expect(received.single, isA<SingleTransportFrame>());
      expect(received.single.toWire(), contains('允许中文'));
      await transport.close();
    },
  );

  test(
    'multiple lines, final unterminated line, and stderr stay separate',
    () async {
      final session = _Session();
      final transport = AcpSshTransport(session);
      final frames = transport.incoming.toList();
      session.errors.add(utf8.encode('ordinary CLI log\n'));
      session.output.add(
        utf8.encode(
          '\n{"jsonrpc":"2.0","id":1,"result":{}}\n{"jsonrpc":"2.0","id":2,"result":{}}',
        ),
      );
      await session.output.close();
      expect(await frames, hasLength(2));
      await transport.close();
    },
  );

  test('malformed JSON is reported rather than silently discarded', () async {
    final session = _Session();
    final transport = AcpSshTransport(session);
    final frames = transport.incoming.toList();
    session.output.add(utf8.encode('invalid JSON\n'));
    await session.output.close();
    expect((await frames).single, isA<MalformedTransportFrame>());
    await transport.close();
  });
}
