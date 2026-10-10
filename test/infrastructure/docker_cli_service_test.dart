import 'dart:async';
import 'dart:convert';
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

  /// `docker ps` replay script used by `listContainers`.
  String psOutput = '';
  int psExitCode = 0;
  String psStderr = '';

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
    if (command.startsWith('docker ps')) {
      return SSHExecutionResult(
        exitCode: psExitCode,
        stdout: psOutput,
        stderr: psStderr,
      );
    }
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

/// Field values the real `docker ps --format` template expands, keyed by the
/// Go template field name (`{{json .ID}}`, `{{json .CreatedAt}}`, ...).
const _templateFields = <String, Object>{
  'ID': 'c9f8e7d6c5b4a39281706f5e4d3c2b1a0987654321abcdef0123456789abcdef',
  'Names': 'app-web',
  'Image': 'nginx:alpine',
  'Status': 'Up 2 hours',
  'State': 'running',
  'Ports': '0.0.0.0:8080->80/tcp',
  'CreatedAt': '2026-10-09 10:00:00 +0000 UTC',
};

const _templateLabels = <String, String>{
  'com.docker.compose.project': 'shop',
  'com.docker.compose.service': 'web',
};

final _formatTemplate = RegExp(r"--format '([^']*)'");

/// Extracts the Go template production hands to `docker ps --format '<tmpl>'`
/// (the SSH layer only adds `bash -l -c` quoting around it).
String _dockerPsFormat(String command) {
  final match = _formatTemplate.firstMatch(command);
  if (match == null) {
    fail('docker ps must send a quoted --format template, got: $command');
  }
  return match.group(1)!;
}

/// Expands `{{json .Field}}` and `{{json (.Label "k")}}` the way the Docker CLI
/// `json` template function does (encoding/json, HTML escaping disabled).
String _renderTemplate(
  String template, {
  Map<String, String> labels = _templateLabels,
}) {
  final withLabels = template.replaceAllMapped(
    RegExp(r'\{\{json \(\.Label "([^"]+)"\)\}\}'),
    (match) => jsonEncode(labels[match.group(1)] ?? ''),
  );
  return withLabels.replaceAllMapped(
    RegExp(r'\{\{json \.(\w+)\}\}'),
    (match) => jsonEncode(_templateFields[match.group(1)]),
  );
}

/// A record the way v1.0.3 actually emitted it: the outer JSON object was never
/// closed because the template ended with `...)"}}` instead of `...)"}}}`.
String _truncatedRecord() =>
    '{"id":"c1","names":"app-web","image":"nginx:alpine",'
    '"status":"Up 2 hours","state":"running","ports":"0.0.0.0:8080->80/tcp",'
    '"created":"2026-10-09 10:00:00 +0000 UTC",'
    '"composeProject":"shop","composeService":"web"';

String _validRecord(String id, String name) => jsonEncode({
  'id': id,
  'names': name,
  'image': 'nginx:alpine',
  'status': 'Up 2 hours',
  'state': 'running',
  'ports': '0.0.0.0:8080->80/tcp',
  'created': '2026-10-09 10:00:00 +0000 UTC',
  'composeProject': 'shop',
  'composeService': 'web',
});

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

  group('docker ps template round trip', () {
    test(
      'the sent template renders one closed JSON object per container',
      () async {
        final executor = _Executor();
        final listed = await DockerCliService(executor).listContainers('s1');

        final command = executor.commands.single;
        expect(command, startsWith('docker ps -a --no-trunc --format '));
        final format = _dockerPsFormat(command);
        expect(format, startsWith('{'));
        expect(
          format,
          endsWith('}}}'),
          reason:
              'the template must close the outer JSON object; v1.0.3 ended with '
              '...)"}} and emitted truncated, unparsable records',
        );

        final rendered = _renderTemplate(format);
        expect(rendered, startsWith('{'));
        expect(rendered, endsWith('}'));
        final decoded = jsonDecode(rendered) as Map<String, dynamic>;
        expect(decoded['id'], _templateFields['ID']);
        expect(decoded['names'], _templateFields['Names']);
        expect(decoded['image'], _templateFields['Image']);
        expect(decoded['state'], _templateFields['State']);
        expect(decoded['ports'], _templateFields['Ports']);
        expect(decoded['created'], _templateFields['CreatedAt']);
        expect(decoded['composeProject'], 'shop');
        expect(decoded['composeService'], 'web');

        // The very line the daemon emits must parse without help.
        final parsed = DockerContainer.parseLines([rendered]);
        expect(parsed, hasLength(1));
        expect(parsed.single.id, _templateFields['ID']);
        expect(parsed.single.name, 'app-web');
        expect(parsed.single.state, DockerContainerState.running);
        expect(parsed.single.composeProject, 'shop');
        expect(parsed.single.composeService, 'web');
        expect(listed, isEmpty);
      },
    );

    test(
      'containers without compose labels render empty label fields',
      () async {
        final executor = _Executor();
        await DockerCliService(executor).listContainers('s1');

        final rendered = _renderTemplate(
          _dockerPsFormat(executor.commands.single),
          labels: const {},
        );
        final decoded = jsonDecode(rendered) as Map<String, dynamic>;
        expect(decoded['composeProject'], isEmpty);
        expect(decoded['composeService'], isEmpty);

        final parsed = DockerContainer.parseLines([rendered]);
        expect(parsed.single.composeProject, isNull);
        expect(parsed.single.composeService, isNull);
        expect(parsed.single.id, _templateFields['ID']);
      },
    );

    test('a login-shell banner in front of the records is tolerated', () async {
      final executor = _Executor();
      await DockerCliService(executor).listContainers('s1');

      final banner = 'Last login: Fri Oct 10 09:00:00 2026 from 10.0.0.2\n';
      final containers = DockerContainer.parseLines([
        banner,
        _renderTemplate(_dockerPsFormat(executor.commands.single)),
      ]);
      expect(containers, hasLength(1));
      expect(containers.single.name, 'app-web');
    });

    test('a template that forgets the closing brace is rejected', () async {
      final executor = _Executor();
      await DockerCliService(executor).listContainers('s1');

      final format = _dockerPsFormat(executor.commands.single);
      expect(format, endsWith('}}}'));
      // Exactly the v1.0.3 shape: the outer object stays open.
      final unclosed = format.substring(0, format.length - 1);
      expect(_renderTemplate(unclosed), isNot(endsWith('}')));

      expect(
        () => DockerContainer.parseLines([_renderTemplate(unclosed)]),
        throwsA(isA<FormatException>()),
        reason: 'reintroducing the v1.0.3 template must be caught here',
      );
    });
  });

  group('docker ps response validation', () {
    test(
      'an unparsable record rejects the listing instead of empty success',
      () async {
        final executor = _Executor()..psOutput = '${_truncatedRecord()}\n';
        await expectLater(
          DockerCliService(executor).listContainers('s1'),
          throwsA(
            isA<DockerExecutionException>().having(
              (error) => error.message,
              'message',
              contains('Invalid Docker container record at line 1'),
            ),
          ),
          reason:
              'v1.0.3 silently turned this into an empty successful listing',
        );
      },
    );

    test('all-garbage output is reported as a failure', () async {
      final executor = _Executor()
        ..psOutput =
            'template parsing error: template: :1: function "json" not defined\n';
      await expectLater(
        DockerCliService(executor).listContainers('s1'),
        throwsA(
          isA<DockerExecutionException>().having(
            (error) => error.message,
            'message',
            contains('no valid container records'),
          ),
        ),
      );
    });

    test(
      'a partially invalid listing rejects instead of returning a subset',
      () async {
        final executor = _Executor()
          ..psOutput =
              '${_validRecord('c1', 'app-web')}\n'
              '${_truncatedRecord()}\n'
              '${_validRecord('c2', 'app-db')}\n';
        await expectLater(
          DockerCliService(executor).listContainers('s1'),
          throwsA(
            isA<DockerExecutionException>().having(
              (error) => error.message,
              'message',
              contains('Invalid Docker container record at line 2'),
            ),
          ),
          reason: 'a broken record must not drop the remaining valid records',
        );
      },
    );

    test('records missing an id or with wrong field types reject', () async {
      final broken = <String>[
        '{"names":"app-web","image":"nginx","state":"running"}',
        '{"id":"","names":"app-web","state":"running"}',
        '{"id":123,"names":"app-web","state":"running"}',
        '{"id":"c1","names":{"name":"app-web"},"state":"running"}',
        '[{"id":"c1","names":"app-web"}]',
      ];
      for (final line in broken) {
        final executor = _Executor()..psOutput = '$line\n';
        await expectLater(
          DockerCliService(executor).listContainers('s1'),
          throwsA(isA<DockerExecutionException>()),
          reason: 'record must be rejected: $line',
        );
      }
    });

    test('an empty remote listing still succeeds', () async {
      for (final stdout in ['', '\n', '\n\n  \n']) {
        final executor = _Executor()..psOutput = stdout;
        expect(
          await DockerCliService(executor).listContainers('s1'),
          isEmpty,
          reason: 'a host with no containers is a valid empty result: $stdout',
        );
      }
    });

    test('a non-zero docker exit keeps the daemon message and exit code', () async {
      final executor = _Executor()
        ..psExitCode = 1
        ..psStderr =
            'Cannot connect to the Docker daemon at unix:///var/run/docker.sock';
      await expectLater(
        DockerCliService(executor).listContainers('s1'),
        throwsA(
          isA<DockerExecutionException>()
              .having(
                (error) => error.message,
                'message',
                'Cannot connect to the Docker daemon at unix:///var/run/docker.sock',
              )
              .having((error) => error.exitCode, 'exitCode', 1),
        ),
      );
    });
  });
}
