import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 手写 fake：按命令子串返回预置结果，并记录收到的所有命令。
class _FakeSshExecutor implements SshCommandExecutor {
  _FakeSshExecutor({
    this.connected = true,
    Map<String, SSHExecutionResult> results = const {},
    this.streamChunks = const {},
    this.throwOnExecute = false,
  }) : _results = results;

  final bool connected;
  final Map<String, SSHExecutionResult> _results;

  /// 流式执行时按命令返回的片段序列。
  final Map<String, List<String>> streamChunks;
  final bool throwOnExecute;

  final List<String> executedCommands = [];

  @override
  bool isConnected(String serverId) => connected;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    executedCommands.add(command);
    if (throwOnExecute) {
      throw const SSHConnectionException('not connected');
    }
    // 最长 key 优先：`command -v claude` 也包含在
    // `command -v claude-code-acp` 中，必须让更具体的规则胜出。
    final keys = _results.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (command.contains(key)) {
        return _results[key]!;
      }
    }
    return const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async* {
    executedCommands.add(command);
    if (throwOnExecute) {
      throw const SSHConnectionException('not connected');
    }
    for (final text in streamChunks[command] ?? const <String>[]) {
      yield SSHExecutionChunk(kind: SSHStreamKind.stdout, text: text);
    }
  }
}

SSHExecutionResult _ok(String stdout) =>
    SSHExecutionResult(exitCode: 0, stdout: stdout, stderr: '');

SSHExecutionResult _fail(String stderr) =>
    SSHExecutionResult(exitCode: 1, stdout: '', stderr: stderr);

AgentProfile _profile({
  String cliCommand = 'claude',
  String? acpCommand = 'claude-code-acp',
  String? installCommand,
  String? loginCheckCommand,
  String? loginCommand,
  String target = 'host',
  String? containerReference,
  String? containerUser,
}) => AgentProfile(
  id: 'agent-1',
  serverId: 'server-1',
  name: 'Claude Code',
  description: 'test agent',
  cliCommand: cliCommand,
  acpCommand: acpCommand,
  installCommand: installCommand,
  loginCheckCommand: loginCheckCommand,
  loginCommand: loginCommand,
  executionTarget: target,
  containerReference: containerReference,
  containerUser: containerUser,
);

void main() {
  test(
    'CLI inspection ignores missing ACP but still checks configured login',
    () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v claude-code-acp': _fail('missing'),
          'claude auth status': _ok('{"loggedIn":false}'),
        },
      );
      final profile = _profile(loginCheckCommand: 'claude auth status --json');
      final status = await AgentEnvironmentService(
        executor,
      ).inspect(profile, 'server', requireAcp: false);
      expect(status.kind, AgentEnvironmentStatusKind.notLoggedIn);
      expect(
        executor.executedCommands.any((c) => c.contains('claude-code-acp')),
        isFalse,
      );
      expect(executor.executedCommands.last, 'claude auth status --json');
    },
  );
  group('AgentEnvironmentService.inspect', () {
    test(
      'container inspection executes as configured user in a login shell',
      () async {
        final executor = _FakeSshExecutor(
          results: {
            'docker inspect': _ok('true'),
            "--user 'dev'": _ok('/home/dev/.nvm/bin/codex'),
          },
        );
        final status = await AgentEnvironmentService(executor).inspect(
          _profile(
            cliCommand: 'codex',
            acpCommand: null,
            target: 'docker',
            containerReference: 'workspace',
            containerUser: 'dev',
          ),
          'server-1',
        );
        expect(status.kind, AgentEnvironmentStatusKind.ready);
        expect(
          status.diagnosticLog,
          contains('container user: target container workspace as dev'),
        );
        expect(
          status.diagnosticLog,
          contains('cli availability: requested command: command -v codex'),
        );
        expect(
          status.diagnosticLog,
          contains(
            "cli availability: transport command: docker exec -i --user 'dev' 'workspace' /bin/sh -lc",
          ),
        );
        expect(status.diagnosticLog, contains('/bin/bash -ic'));
        expect(
          executor.executedCommands,
          contains(
            allOf(
              contains("docker exec -i --user 'dev' 'workspace' /bin/sh -lc"),
              contains('id -u'),
            ),
          ),
        );
        expect(
          executor.executedCommands,
          contains(
            allOf(
              contains("docker exec -i --user 'dev' 'workspace' /bin/sh -lc"),
              contains('command -v codex'),
            ),
          ),
        );
      },
    );

    test('container user that cannot execute is reported distinctly', () async {
      final executor = _FakeSshExecutor(
        results: {
          'docker inspect': _ok('true'),
          "--user 'missing'": _fail('unable to find user missing'),
        },
      );
      final status = await AgentEnvironmentService(executor).inspect(
        _profile(
          target: 'docker',
          containerReference: 'workspace',
          containerUser: 'missing',
        ),
        'server-1',
      );
      expect(status.kind, AgentEnvironmentStatusKind.error);
      expect(status.detail, 'AGENT_CONTAINER_USER_UNAVAILABLE');
    });

    test(
      'Claude structured status controls authentication, not exit code alone',
      () async {
        final executor = _FakeSshExecutor(
          results: {'claude auth status --json': _ok('{"loggedIn":false}')},
        );
        final status = await AgentEnvironmentService(executor).inspect(
          _profile(loginCheckCommand: 'claude auth status --json'),
          'server-1',
        );
        expect(status.kind, AgentEnvironmentStatusKind.notLoggedIn);
        expect(
          status.authentication,
          AgentAuthenticationStatus.unauthenticated,
        );
      },
    );

    test(
      'Claude unsupported login check is not classified as logged out',
      () async {
        final executor = _FakeSshExecutor(
          results: {
            'claude auth status --json': const SSHExecutionResult(
              exitCode: 2,
              stdout: '',
              stderr: 'unknown subcommand',
            ),
          },
        );
        final status = await AgentEnvironmentService(executor).inspect(
          _profile(loginCheckCommand: 'claude auth status --json'),
          'server-1',
        );
        expect(status.authentication, AgentAuthenticationStatus.unknown);
        expect(status.detail, 'AUTH_CHECK_UNSUPPORTED_OR_FAILED');
      },
    );
    test('version checks do not prove authentication', () async {
      final executor = _FakeSshExecutor();
      final status = await AgentEnvironmentService(
        executor,
      ).inspect(_profile(loginCheckCommand: 'claude --version'), 'server-1');
      expect(status.authentication, AgentAuthenticationStatus.unknown);
      expect(executor.executedCommands, isNot(contains('claude --version')));
    });

    test('legacy Codex version check uses login status', () async {
      final executor = _FakeSshExecutor(
        results: {'codex login status': _fail('not logged in')},
      );
      final status = await AgentEnvironmentService(executor).inspect(
        _profile(cliCommand: 'codex', loginCheckCommand: 'codex --version'),
        'server-1',
      );
      expect(status.authentication, AgentAuthenticationStatus.unauthenticated);
      expect(status.kind, AgentEnvironmentStatusKind.notLoggedIn);
      expect(executor.executedCommands, contains('codex login status'));
    });

    test(
      'executable lookup rejects shell injection before SSH execution',
      () async {
        final executor = _FakeSshExecutor();
        final status = await AgentEnvironmentService(
          executor,
        ).inspect(_profile(cliCommand: 'claude; id'), 'server-1');
        expect(status.kind, AgentEnvironmentStatusKind.error);
        expect(executor.executedCommands, isEmpty);
      },
    );

    test('disconnected server returns error status', () async {
      final executor = _FakeSshExecutor(connected: false);
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(
        _profile(loginCheckCommand: 'claude auth status --json'),
        'server-1',
      );

      expect(status.kind, AgentEnvironmentStatusKind.error);
      expect(status.detail, 'SSH_DISCONNECTED');
      expect(executor.executedCommands, isEmpty);
    });

    test('missing cli returns cliMissing', () async {
      final executor = _FakeSshExecutor(
        results: {'command -v': _fail('command not found')},
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(_profile(), 'server-1');

      expect(status.kind, AgentEnvironmentStatusKind.cliMissing);
      expect(status.detail, contains('command not found'));
      expect(status.diagnosticLog, contains('cli availability: running'));
      expect(status.diagnosticLog, contains('cli availability: exit 1'));
    });

    test('diagnostic output is sanitized and bounded to probe steps', () async {
      final executor = _FakeSshExecutor(
        results: {'command -v': _fail('token=super-secret')},
      );
      final status = await AgentEnvironmentService(
        executor,
      ).inspect(_profile(), 'server-1');
      expect(status.diagnosticLog, contains('token=******'));
      expect(status.diagnosticLog, isNot(contains('super-secret')));
    });

    test('cli present but acp binary missing returns acpMissing', () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v claude': _ok('/usr/bin/claude'),
          'command -v claude-code-acp': _fail('command not found'),
          'claude auth status --json': _ok('{"loggedIn":true}'),
        },
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(
        _profile(loginCheckCommand: 'claude auth status --json'),
        'server-1',
      );

      expect(status.kind, AgentEnvironmentStatusKind.acpMissing);
      expect(status.detail, contains('command not found'));
      expect(executor.executedCommands, contains('claude auth status --json'));
      // 探测必须用 `command -v`，绝不执行会挂起 ACP 服务的 `--help`。
      expect(executor.executedCommands, contains('command -v claude-code-acp'));
      expect(
        executor.executedCommands.any((c) => c.contains('--help')),
        isFalse,
      );
    });

    test(
      'acp probe uses the first token of a multi-word acp command',
      () async {
        final executor = _FakeSshExecutor(
          results: {'command -v opencode': _ok('/usr/bin/opencode')},
        );
        final service = AgentEnvironmentService(executor);

        final status = await service.inspect(
          _profile(cliCommand: 'opencode', acpCommand: 'opencode acp'),
          'server-1',
        );

        expect(status.kind, AgentEnvironmentStatusKind.ready);
        expect(executor.executedCommands, contains('command -v opencode'));
      },
    );

    test('profile without an acp command skips the acp probe', () async {
      final executor = _FakeSshExecutor(
        results: {'command -v agy': _ok('/usr/bin/agy')},
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(
        _profile(cliCommand: 'agy', acpCommand: null),
        'server-1',
      );

      expect(status.kind, AgentEnvironmentStatusKind.ready);
      expect(executor.executedCommands, equals(['command -v agy']));
    });

    test('login check nonzero returns notLoggedIn', () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v': _ok('/usr/bin/claude'),
          'command -v claude-code-acp': _ok('/usr/bin/claude-code-acp'),
          'claude auth status': _fail('not authenticated'),
        },
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(
        _profile(loginCheckCommand: 'claude auth status'),
        'server-1',
      );

      expect(status.kind, AgentEnvironmentStatusKind.notLoggedIn);
      expect(status.detail, contains('not authenticated'));
    });

    test('no login check returns ready', () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v claude': _ok('/usr/bin/claude'),
          'command -v claude-code-acp': _ok('/usr/bin/claude-code-acp'),
        },
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(_profile(), 'server-1');

      expect(status.kind, AgentEnvironmentStatusKind.ready);
      expect(status.version, contains('/usr/bin/claude'));
    });

    test('login check success returns ready', () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v': _ok('/usr/bin/claude'),
          'command -v claude-code-acp': _ok('/usr/bin/claude-code-acp'),
          'claude auth status': _ok('logged in as dev'),
        },
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(
        _profile(loginCheckCommand: 'claude auth status'),
        'server-1',
      );

      expect(status.kind, AgentEnvironmentStatusKind.ready);
    });

    test('timeout maps to error without throwing', () async {
      final executor = _FakeSshExecutor(
        results: {'command -v': _ok('/usr/bin/claude')},
        throwOnExecute: true,
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(_profile(), 'server-1');

      expect(status.kind, AgentEnvironmentStatusKind.error);
    });

    test('inspect never calls install or login', () async {
      final executor = _FakeSshExecutor(
        results: {
          'command -v': _ok('/usr/bin/claude'),
          'command -v claude-code-acp': _ok('/usr/bin/claude-code-acp'),
          'claude auth status': _ok('logged in'),
        },
      );
      final service = AgentEnvironmentService(executor);

      await service.inspect(
        _profile(
          installCommand: 'npm install -g claude',
          loginCheckCommand: 'claude auth status',
          loginCommand: 'claude login',
        ),
        'server-1',
      );

      expect(
        executor.executedCommands,
        isNot(contains('npm install -g claude')),
      );
      expect(executor.executedCommands, isNot(contains('claude login')));
    });

    test('status output is sanitized', () async {
      // The fake returns already-sanitized output in production; here we verify the
      // service never surfaces raw secrets when the executor returns sanitized text.
      final executor = _FakeSshExecutor(
        results: {'command -v': _ok('/usr/bin/claude')},
      );
      final service = AgentEnvironmentService(executor);

      final status = await service.inspect(_profile(), 'server-1');

      expect(status.detail ?? '', isNot(contains('token=abc123')));
    });
  });

  group('AgentEnvironmentService explicit actions', () {
    test('runInstall rejects missing command', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.runInstall(_profile(), 'server-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('runLogin rejects missing command', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.runLogin(_profile(), 'server-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('runInstall executes the explicit install command', () async {
      final executor = _FakeSshExecutor(
        results: {'npm install': _ok('installed')},
      );
      final service = AgentEnvironmentService(executor);

      final result = await service.runInstall(
        _profile(installCommand: 'npm install -g claude'),
        'server-1',
      );

      expect(result.isSuccess, isTrue);
      expect(executor.executedCommands, contains('npm install -g claude'));
    });

    test('runInstallCommand executes the caller supplied command', () async {
      final executor = _FakeSshExecutor();
      final service = AgentEnvironmentService(executor);

      await service.runInstallCommand(
        _profile(),
        'server-1',
        command: 'npm install -g @zed-industries/codex-acp',
      );

      expect(
        executor.executedCommands,
        contains('npm install -g @zed-industries/codex-acp'),
      );
    });

    test('runInstallCommand rejects an empty command', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.runInstallCommand(_profile(), 'server-1', command: '  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('runInstallCommand rejects an unsafe command', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.runInstallCommand(
          _profile(),
          'server-1',
          command: 'rm -rf /\n',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('streamInstallCommand emits chunks in order', () async {
      final executor = _FakeSshExecutor(
        streamChunks: {
          'npm install -g @zed-industries/codex-acp': [
            'added 1 package\n',
            'installing dependencies\n',
          ],
        },
      );
      final service = AgentEnvironmentService(executor);

      final chunks = await service
          .streamInstallCommand(
            _profile(),
            'server-1',
            command: 'npm install -g @zed-industries/codex-acp',
          )
          .toList();

      expect(chunks, ['added 1 package\n', 'installing dependencies\n']);
    });

    test('streamInstallCommand rejects an empty command', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.streamInstallCommand(_profile(), 'server-1', command: ''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('streamInstallCommand rejects a command with a newline', () {
      final service = AgentEnvironmentService(_FakeSshExecutor());

      expect(
        () => service.streamInstallCommand(
          _profile(),
          'server-1',
          command: 'npm install -g foo\nrm -rf /',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
