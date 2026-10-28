import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

AgentProfile testAgentProfile({String serverId = 'srv-1'}) => AgentProfile(
  id: 'agent-1',
  serverId: serverId,
  name: 'agent',
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

class _FakeStdin implements StreamSink<Uint8List> {
  final writes = <Uint8List>[];
  final _controller = StreamController<Uint8List>.broadcast();

  @override
  void add(Uint8List event) {
    writes.add(event);
    _controller.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Uint8List> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close() => _controller.close();

  @override
  Future<void> get done => _controller.done;
}

class _FakeSession implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = _FakeStdin();

  void emit(String line) => _stdout.add(utf8.encode('$line\n'));

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin;

  @override
  int? get exitCode => 0;

  @override
  void close() {
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    unawaited(_stdin.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _status({
  String sessionId = 'remote-1',
  String workspaceSessionId = 'local-1',
}) => jsonEncode({
  'type': 'status',
  'runtimeKey': 'runtime-1',
  'state': 'running',
  'sessionId': sessionId,
  'workspaceSessionId': workspaceSessionId,
  'turnId': 'turn-1',
});

String _frame(Map<String, dynamic> frame, {int seq = 1}) => jsonEncode({
  'type': 'frame',
  'turnId': 'turn-1',
  'seq': seq,
  'frame': frame,
});

void main() {
  group('AcpSshTransport read-only observer', () {
    test('rejects every outbound frame without touching stdin', () async {
      final session = _FakeSession();
      final transport = AcpSshTransport(
        session,
        runtimeKey: 'runtime-1',
        workspaceReadOnly: true,
      );
      addTearDown(transport.close);
      session.emit(_status());
      await transport.attached;

      expect(
        () => transport.send(
          TransportFrame.decode(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'WORKSPACE_CONTROL_REQUIRED',
          ),
        ),
      );
      expect(session._stdin.writes, isEmpty);
    });

    test('close and detach never send a cancel', () async {
      final session = _FakeSession();
      final transport = AcpSshTransport(
        session,
        runtimeKey: 'runtime-1',
        workspaceReadOnly: true,
      );
      session.emit(_status());
      await transport.attached;
      transport.detachWrites();
      transport.send(
        TransportFrame.decode(
          '{"jsonrpc":"2.0","id":2,"method":"session/cancel","params":{}}',
        ),
      );
      await transport.close();
      expect(session._stdin.writes, isEmpty);
    });
  });

  group('ACPClientAdapter read-only observer', () {
    test(
      'connects without initialize/load/resume and still displays events',
      () async {
        final session = _FakeSession();
        final transport = AcpSshTransport(
          session,
          runtimeKey: 'runtime-1',
          workspaceReadOnly: true,
        );
        session.emit(_status());
        await transport.attached;
        final adapter = ACPClientAdapter(
          profile: testAgentProfile(serverId: 'srv-1'),
          transport: transport,
          workingDirectory: '/work',
        );
        addTearDown(adapter.dispose);
        final events = <ACPEvent>[];
        final subscription = adapter.eventStream.listen(events.add);
        addTearDown(subscription.cancel);

        await adapter.prepareSession();
        expect(adapter.sessionId, 'remote-1');
        expect(adapter.restoredExistingSession, isTrue);
        expect(adapter.isPersistent, isTrue);
        // Only the attach status was emitted; the client wrote nothing at all.
        expect(session._stdin.writes, isEmpty);

        session.emit(
          _frame({
            'jsonrpc': '2.0',
            'method': 'session/update',
            'params': {
              'sessionId': 'remote-1',
              'update': {
                'sessionUpdate': 'agent_message_chunk',
                'messageId': 'a1',
                'content': {'type': 'text', 'text': 'streamed'},
              },
            },
          }),
        );
        await pumpEventQueue();
        final chunk = events.whereType<ACPContentChunkEvent>().single;
        expect(chunk.chunk, 'streamed');
        expect(chunk.messageId, 'a1');

        session.emit(
          _frame({
            'jsonrpc': '2.0',
            'id': 77,
            'method': 'session/request_permission',
            'params': {
              'sessionId': 'remote-1',
              'toolCall': {
                'toolCallId': 'tc-1',
                'title': 'write file',
                'kind': 'execute',
              },
              'options': [
                {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
                {'optionId': 'reject', 'name': 'Reject', 'kind': 'reject_once'},
              ],
            },
          }, seq: 2),
        );
        await pumpEventQueue();
        final permission = events.whereType<ACPPermissionRequestEvent>().single;
        expect(permission.request.id, 'tc-1');
        expect(permission.request.options.map((o) => o.id), [
          'allow',
          'reject',
        ]);
        expect(permission.responseCompleter.isCompleted, isFalse);

        // Disposing an observer resolves pending permissions without a write.
        adapter.dispose();
        await pumpEventQueue();
        expect(session._stdin.writes, isEmpty);
      },
    );
  });
}
