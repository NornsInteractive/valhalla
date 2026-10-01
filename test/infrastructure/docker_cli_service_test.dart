import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _OpenSshClient implements SSHClient {
  @override
  bool get isClosed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Executor implements SshCommandExecutor {
  final List<String> commands = [];
  bool bashAvailable = true;
  bool shAvailable = true;
  String? passwdOutput;
  @override
  SSHClient? getClient(String serverId) => _OpenSshClient();
  @override
  bool isConnected(String serverId) => true;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    if (command.contains('cat /etc/passwd') && passwdOutput != null) {
      return SSHExecutionResult(exitCode: 0, stdout: passwdOutput!, stderr: '');
    }
    return SSHExecutionResult(
      exitCode:
          (command.contains(' bash ') && !bashAvailable) ||
              (command.contains(' sh ') && !shAvailable)
          ? 1
          : 0,
      stdout: '',
      stderr: 'shell unavailable',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LogExecutor extends _Executor {
  final Stream<SSHExecutionChunk> output;
  _LogExecutor(this.output);

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration? timeout,
    String? sudoPassword,
  }) {
    commands.add(command);
    return output;
  }
}

void main() {
  test(
    'logs preserve stdout and stderr and cancel the SSH stream on close',
    () async {
      var cancelled = false;
      final stream = StreamController<SSHExecutionChunk>(
        onCancel: () => cancelled = true,
      );
      final executor = _LogExecutor(stream.stream);
      final reader = StreamIterator(
        DockerCliService(executor).streamLogs('s1', "container'quoted"),
      );
      final first = reader.moveNext();
      stream.add(
        const SSHExecutionChunk(
          kind: SSHStreamKind.stderr,
          text: 'failure detail\n',
        ),
      );
      expect(await first, isTrue);
      expect(reader.current, 'failure detail\n');
      final second = reader.moveNext();
      stream.add(
        const SSHExecutionChunk(kind: SSHStreamKind.stdout, text: 'normal\n'),
      );
      expect(await second, isTrue);
      expect(reader.current, 'normal\n');
      await reader.cancel();
      expect(cancelled, isTrue);
      await stream.close();
      expect(executor.commands.single, contains("'container'\\''quoted'"));
    },
  );

  test(
    'logs report unsuccessful or missing command exit instead of silent success',
    () async {
      for (final exitCode in [1, -1]) {
        final executor = _LogExecutor(
          Stream.value(
            SSHExecutionChunk(
              kind: SSHStreamKind.stderr,
              text: '',
              exitCode: exitCode,
            ),
          ),
        );
        await expectLater(
          DockerCliService(executor).streamLogs('s1', 'container').toList(),
          throwsA(isA<DockerExecutionException>()),
        );
      }
    },
  );
  test('parses structured docker container output', () {
    const line =
        '{"id":"abc123","names":"web","image":"nginx:alpine","status":"Up 2 hours","state":"running","ports":"0.0.0.0:80->80/tcp","created":"2026-09-14 10:00:00 +0000 UTC"}';

    final container = DockerContainer.fromJsonLine(line);

    expect(container.id, 'abc123');
    expect(container.name, 'web');
    expect(container.state, DockerContainerState.running);
    expect(container.ports, contains('80->80'));
  });

  test(
    'explicit sh does not probe bash; both unavailable reports failure',
    () async {
      final container = DockerContainer.fromJson({
        'id': 'abc123',
        'state': 'running',
        'names': 'web',
      });
      final executor = _Executor();
      final service = DockerCliService(executor);
      final chosen = await service.openTerminal(
        's1',
        container,
        'server',
        preferredShell: DockerTerminalShell.sh,
      );
      addTearDown(chosen.bridge.dispose);
      expect(executor.commands, ["docker exec 'abc123' sh -c :"]);
      executor.bashAvailable = false;
      executor.shAvailable = false;
      await expectLater(
        service.openTerminal('s1', container, 'server'),
        throwsA(isA<DockerExecutionException>()),
      );
    },
  );

  test('ignores malformed docker lines when parsing streams', () {
    final containers = DockerContainer.parseLines([
      'not-json',
      '{"id":"1","names":"db","image":"postgres","status":"Exited","state":"exited","ports":"","created":""}',
    ]);

    expect(containers, hasLength(1));
    expect(containers.single.name, 'db');
  });

  test('lists every valid passwd entry for a container', () async {
    final executor = _Executor()
      ..passwdOutput =
          'root:x:0:0:root:/root:/bin/bash\n'
          'dev:x:1000:1000:Developer:/home/dev:/bin/sh\n'
          'invalid:x:nope:1000::/tmp:/bin/sh\n';
    final users = await DockerCliService(
      executor,
    ).listContainerUsers('s1', 'workspace');

    expect(
      executor.commands.single,
      "docker exec -i 'workspace' cat /etc/passwd",
    );
    expect(users.map((user) => (user.name, user.uid, user.gid)), [
      ('root', 0, 0),
      ('dev', 1000, 1000),
    ]);
  });

  test('lists users for a full hexadecimal container id', () async {
    const id =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0';
    final executor = _Executor()
      ..passwdOutput =
          'root:x:0:0:root:/root:/bin/bash\n'
          'dev:x:1000:1000:Developer:/home/dev:/bin/sh\n';
    final users = await DockerCliService(executor).listContainerUsers('s1', id);

    expect(executor.commands.single, "docker exec -i '$id' cat /etc/passwd");
    expect(users.map((user) => (user.name, user.uid, user.gid)), [
      ('root', 0, 0),
      ('dev', 1000, 1000),
    ]);
  });

  test('running container prefers bash and falls back to sh', () async {
    final container = DockerContainer.fromJson({
      'id': 'abc123',
      'state': 'running',
      'names': 'web',
    });
    final executor = _Executor();
    final service = DockerCliService(executor);
    final first = await service.openTerminal('s1', container, 'server');
    addTearDown(first.bridge.dispose);
    expect(first.shell, DockerTerminalShell.bash);
    expect(first.bridge.remoteExecCommand, "docker exec -it 'abc123' bash");
    executor.bashAvailable = false;
    final fallback = await service.openTerminal('s1', container, 'server');
    addTearDown(fallback.bridge.dispose);
    expect(fallback.shell, DockerTerminalShell.sh);
    expect(fallback.bridge.remoteExecCommand, "docker exec -it 'abc123' sh");
    expect(fallback.bridge.preferTmux, isFalse);
  });

  test('stopped container cannot open terminal', () async {
    final container = DockerContainer.fromJson({
      'id': 'abc123',
      'state': 'exited',
      'names': 'web',
    });
    await expectLater(
      DockerCliService(_Executor()).openTerminal('s1', container, 'server'),
      throwsStateError,
    );
  });
}
