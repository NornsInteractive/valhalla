import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

class _RuntimeSession implements SSHSession {
  _RuntimeSession(this.status) {
    _stdout = StreamController<Uint8List>(
      onListen: () {
        if (!_stdout.isClosed) {
          _stdout.add(utf8.encode('${jsonEncode(status)}\n'));
        }
      },
    );
  }

  final Map<String, dynamic> status;
  late final StreamController<Uint8List> _stdout;
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  int? get exitCode => null;

  @override
  void close() {
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_stdin.isClosed) _stdin.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RuntimeSsh implements SSHClient {
  _RuntimeSsh(this.status);

  final Map<String, dynamic> status;
  int attachCount = 0;
  String? attachCommand;

  @override
  Future<SSHRunResult> runWithResult(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) async {
    final body = command.contains('/tmp/broker.py')
        ? jsonEncode(status)
        : jsonEncode({
            'script': '/tmp/broker.py',
            'python': 'python3',
            'version': 2,
          });
    final bytes = Uint8List.fromList(utf8.encode(body));
    return SSHRunResult(
      output: bytes,
      stdout: bytes,
      stderr: Uint8List(0),
      exitCode: 0,
      exitSignal: null,
    );
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    attachCount++;
    attachCommand = command;
    return _RuntimeSession({
      'type': 'status',
      'runtimeKey': 'runtime-1',
      'state': 'running',
      'alive': true,
      'sessionId': 'remote-1',
      'workspaceSessionId': 'local-1',
      'seq': 3,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AgentProfile _profile() => AgentProfile(
  id: 'agent-1',
  serverId: 'srv-1',
  name: 'agent',
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

Map<String, dynamic> _status({
  required bool alive,
  required int workspaceProtocol,
}) => {
  'runtimeKey': 'runtime-1',
  'state': alive ? 'running' : 'exited',
  'alive': alive,
  'childAlive': alive,
  'protocolVersion': 1,
  'workspaceProtocol': workspaceProtocol,
  'sessionId': 'remote-1',
};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AcpRuntimeService shared open', () {
    test(
      'a read-only view of a dead runtime never creates a process',
      () async {
        final ssh = _RuntimeSsh(_status(alive: false, workspaceProtocol: 0));
        await expectLater(
          AcpRuntimeService.openShared(
            ssh,
            _profile(),
            runtimeKey: 'runtime-1',
            afterSequence: 0,
            workspace: {
              'workspaceId': 'ws-1',
              'workspaceSessionId': 'local-1',
              'workspaceDeviceId': 'dev-1',
            },
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'WORKSPACE_RUNTIME_NOT_RUNNING',
            ),
          ),
        );
        expect(ssh.attachCount, 0);
      },
    );

    test('a read-only observer may attach to a live legacy runtime', () async {
      final ssh = _RuntimeSsh(_status(alive: true, workspaceProtocol: 0));
      final transport = await AcpRuntimeService.openShared(
        ssh,
        _profile(),
        runtimeKey: 'runtime-1',
        afterSequence: 0,
        workspace: {
          'workspaceId': 'ws-1',
          'workspaceSessionId': 'local-1',
          'workspaceDeviceId': 'dev-1',
        },
      );
      addTearDown(transport.close);
      expect(transport, isA<AcpSshTransport>());
      expect(transport.workspaceReadOnly, isTrue);
      expect(ssh.attachCount, 1);
      expect(ssh.attachCommand, isNotNull);
    });

    test('a writer refuses a legacy runtime without killing it', () async {
      final ssh = _RuntimeSsh(_status(alive: true, workspaceProtocol: 0));
      await expectLater(
        AcpRuntimeService.openShared(
          ssh,
          _profile(),
          runtimeKey: 'runtime-1',
          afterSequence: 0,
          workspace: {
            'workspaceId': 'ws-1',
            'workspaceSessionId': 'local-1',
            'workspaceDeviceId': 'dev-1',
            'controlToken': 'token-1',
            'controlGeneration': 1,
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'WORKSPACE_RUNTIME_UPGRADE_REQUIRED',
          ),
        ),
      );
      expect(ssh.attachCount, 0);
    });

    test('a writer attaches to a workspace-protocol runtime', () async {
      final ssh = _RuntimeSsh(_status(alive: true, workspaceProtocol: 1));
      final transport = await AcpRuntimeService.openShared(
        ssh,
        _profile(),
        runtimeKey: 'runtime-1',
        afterSequence: 0,
        workspace: {
          'workspaceId': 'ws-1',
          'workspaceSessionId': 'local-1',
          'workspaceDeviceId': 'dev-1',
          'controlToken': 'token-1',
          'controlGeneration': 1,
        },
      );
      addTearDown(transport.close);
      expect(transport.workspaceReadOnly, isFalse);
      expect(ssh.attachCount, 1);
    });
  });
}
