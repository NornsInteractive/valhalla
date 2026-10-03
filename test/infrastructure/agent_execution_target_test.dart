import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';

AgentProfile _profile({
  String target = 'host',
  String binding = 'id',
  String? reference,
  String? user,
}) => AgentProfile(
  id: 'agent',
  serverId: 'server',
  name: 'Agent',
  description: '',
  cliCommand: 'codex',
  executionTarget: target,
  containerBinding: binding,
  containerReference: reference,
  containerUser: user,
);

AgentProfile _acpProfile({
  String target = 'host',
  String binding = 'id',
  String? reference,
  String? user,
  String cliCommand = 'codex',
  String acpCommand = 'codex-acp --stdio',
}) => AgentProfile(
  id: 'agent',
  serverId: 'server',
  name: 'Agent',
  description: '',
  cliCommand: cliCommand,
  acpCommand: acpCommand,
  executionTarget: target,
  containerBinding: binding,
  containerReference: reference,
  containerUser: user,
);

void main() {
  test('host target leaves the validated command unchanged', () {
    expect(
      agentTargetCommand(_profile(), 'codex app-server'),
      'codex app-server',
    );
  });

  test('docker target quotes the reference and uses no PTY by default', () {
    final command = agentTargetCommand(
      _profile(target: 'docker', reference: 'web.api'),
      'codex app-server',
    );
    expect(command, contains("docker exec -i 'web.api' /bin/sh -lc"));
    expect(command, contains('/bin/bash -ic'));
    expect(command, contains('/bin/sh -lc'));
  });

  test('interactive docker target requests a PTY', () {
    expect(
      agentTargetCommand(
        _profile(target: 'docker', reference: 'web'),
        'codex',
        interactive: true,
      ),
      contains("docker exec -it 'web' /bin/sh -lc"),
    );
  });

  test('docker target rejects absent or unsafe container references', () {
    expect(
      () => agentTargetCommand(_profile(target: 'docker'), 'codex'),
      throwsStateError,
    );
    expect(
      () => agentTargetCommand(
        _profile(target: 'docker', reference: 'web;rm'),
        'codex',
      ),
      throwsStateError,
    );
  });

  test('docker target uses an explicit user and rejects unsafe values', () {
    final command = agentTargetCommand(
      _profile(target: 'docker', reference: 'web', user: 'dev:1000'),
      'codex',
    );
    expect(
      command,
      contains("docker exec -i --user 'dev:1000' 'web' /bin/sh -lc"),
    );
    expect(
      () => agentTargetCommand(
        _profile(target: 'docker', reference: 'web', user: 'dev;id'),
        'codex',
      ),
      throwsStateError,
    );
  });

  group('ACP 启动命令：结构', () {
    test('official AGY preserves custom arguments and adds no CLI login', () {
      final profile = _acpProfile(
        cliCommand: 'agy',
        acpCommand: '/opt/agy/agy_acp_server.par --uid=1000 --debug',
      );
      expect(usesAntigravityAcp(profile), isTrue);
      expect(
        agentAcpLaunchCommand(profile),
        "bash -l -c '/opt/agy/agy_acp_server.par --uid=1000 --debug'",
      );
      expect(
        usesAntigravityAcp(
          _acpProfile(cliCommand: 'agy', acpCommand: 'my-agy-wrapper'),
        ),
        isFalse,
      );
    });

    test(
      'official AGY routes through the configured Docker user without PTY',
      () {
        final command = agentAcpLaunchCommand(
          _acpProfile(
            cliCommand: 'agy',
            acpCommand: 'agy_acp_server.par --uid=',
            target: 'docker',
            binding: 'name',
            reference: 'workspace',
            user: '1000:1000',
          ),
        );
        expect(
          command,
          startsWith(
            "docker exec -i --user '1000:1000' 'workspace' /bin/sh -lc ",
          ),
        );
        expect(command, contains('valhalla_agy_acp_path'));
        expect(command, contains('--uid='));
        expect(command, isNot(contains('CODEX_PATH')));
        expect(command, isNot(contains('docker exec -it')));
      },
    );

    test('host 目标把 codex-acp 解析与启动塞进同一个登录 shell', () {
      final command = agentAcpLaunchCommand(_acpProfile());

      expect(command, startsWith("bash -l -c "));
      expect(command, contains('type -P'));
      expect(command, contains('command -v'));
      expect(command, contains('ACP_CODEX_EXECUTABLE_UNAVAILABLE'));
      expect(command, contains('export CODEX_PATH='));
      expect(command, contains('exec codex-acp --stdio'));
    });

    test('绝对路径的 codex-acp 同样走解析并原样启动', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(acpCommand: '/opt/codex/bin/codex-acp --stdio'),
      );

      expect(command, startsWith("bash -l -c "));
      expect(command, contains('type -P'));
      expect(command, contains('exec /opt/codex/bin/codex-acp --stdio'));
    });

    test('codex-acp 之外的参数不改写', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(acpCommand: 'codex-acp --stdio --extra'),
      );

      expect(command, "bash -l -c 'codex-acp --stdio --extra'");
      expect(command, isNot(contains('type -P')));
    });

    test('显式自定义启动脚本保持原样', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(acpCommand: 'node /opt/acp/server.js --stdio'),
      );

      expect(command, "bash -l -c 'node /opt/acp/server.js --stdio'");
      expect(command, isNot(contains('type -P')));
      expect(command, isNot(contains('CODEX_PATH')));
    });

    test('非 Codex CLI 即使命令叫 codex-acp 也不改写', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(cliCommand: 'agy', acpCommand: 'codex-acp --stdio'),
      );

      expect(command, "bash -l -c 'codex-acp --stdio'");
      expect(command, isNot(contains('type -P')));
    });

    test('缺少 ACP 命令时显式失败', () {
      expect(
        () => agentAcpLaunchCommand(
          AgentProfile(
            id: 'agent',
            serverId: 'server',
            name: 'Agent',
            description: '',
            cliCommand: 'codex',
            executionTarget: 'host',
            containerBinding: 'id',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_ACP_COMMAND_MISSING',
          ),
        ),
      );
    });

    test('docker 目标直接在容器 shell 里解析，不再套登录 shell', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(
          target: 'docker',
          binding: 'name',
          reference: 'codex-box',
          user: '1000:1000',
        ),
      );

      expect(
        command,
        startsWith(
          "docker exec -i --user '1000:1000' 'codex-box' /bin/sh -lc ",
        ),
      );
      expect(command, contains('/bin/bash -ic'));
      expect(command, contains('type -P'));
      expect(command, contains('exec codex-acp --stdio'));
      expect(command, isNot(contains('bash -l -c ')));
    });

    test('docker 目标不带 user 时不注入 --user', () {
      final command = agentAcpLaunchCommand(
        _acpProfile(target: 'docker', binding: 'name', reference: 'codex-box'),
      );

      expect(command, startsWith("docker exec -i 'codex-box' /bin/sh -lc "));
      expect(command, isNot(contains('--user')));
    });
  });

  group('ACP 启动命令：真实隔离 shell 验证', () {
    late Directory fixture;
    late String bin;
    late String stubBin;
    late String homeAlias;
    late String homeMissing;
    late String homeDocker;
    late String imageHome;

    Future<ProcessResult> run(
      String command, {
      required String home,
      Map<String, String> environment = const {},
    }) => Process.run(
      '/bin/bash',
      ['-c', command],
      environment: {'HOME': home, 'PATH': '$bin:/usr/bin:/bin', ...environment},
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    String read(String path) => File(path).readAsStringSync();

    setUp(() async {
      fixture = await Directory.systemTemp.createTemp('valhalla-acp-launch-');
      bin = '${fixture.path}/bin';
      stubBin = '${fixture.path}/stub-bin';
      homeAlias = '${fixture.path}/home-alias';
      homeMissing = '${fixture.path}/home-missing';
      homeDocker = '${fixture.path}/home-docker';
      imageHome = '${fixture.path}/image-home';
      for (final dir in [
        bin,
        '$bin/abs',
        stubBin,
        homeAlias,
        homeMissing,
        homeDocker,
        imageHome,
        '${fixture.path}/empty-bin',
      ]) {
        await Directory(dir).create(recursive: true);
      }

      Future<void> script(String path, String body) async {
        final file = File(path);
        await file.writeAsString(body);
        await Process.run('chmod', ['+x', path]);
      }

      await script(
        '$bin/codex',
        '#!/bin/sh\necho "codex mock version 9.9.9-mock"\n',
      );
      await script(
        '$bin/codex-acp',
        '#!/bin/sh\n'
            'echo "ACP_MOCK_STDOUT CODEX_PATH=\${CODEX_PATH:-unset} '
            'HOME=\${HOME:-unset}"\n'
            'echo "ACP_MOCK_ARGS \$*" >&2\n',
      );
      await script(
        '$bin/abs/codex-acp',
        '#!/bin/sh\n'
            'echo "ACP_ABS_STDOUT CODEX_PATH=\${CODEX_PATH:-unset}"\n'
            'echo "ACP_ABS_ARGS \$*" >&2\n',
      );
      await script(
        '$bin/docker',
        '#!/bin/bash\n'
            'printf \'%s\\n\' "\$@" > "\$DOCKER_ARGS_FILE"\n'
            'while [ \$# -gt 0 ] && [ "\$1" != "/bin/sh" ]; do shift; done\n'
            '# \$1=/bin/sh \$2=flag \$3=payload. Run the ORIGINAL shell and flag so\n'
            '# the login path is untouched, and constrain PATH to the fixture so\n'
            '# a real Codex or a real user rc can never be reached.\n'
            'shell="\$1"; flag="\$2"; payload="\$3"\n'
            'exec "\$shell" "\$flag" "PATH=\\\$FIXTURE_CONTAINER_PATH:/usr/bin:/bin; '
            'export PATH; \$payload"\n',
      );
      // The fake docker runs the payload on the host, so the selected-user
      // HOME lookup must be answered by container doubles instead of the
      // host's id/awk and /etc/passwd. Both doubles stay inside the fixture
      // and never read a real passwd file or a real user's rc.
      await script(
        '$stubBin/id',
        '#!/bin/sh\n'
            '# Test double: report the uid the container would run as.\n'
            'printf \'%s\\n\' "\${FIXTURE_CONTAINER_UID:-1000}"\n',
      );
      await script(
        '$stubBin/awk',
        '#!/bin/sh\n'
            '# Test double for `awk -F: -v uid=<n> \'...\' /etc/passwd`.\n'
            '# Only that lookup form is supported; the host passwd is never read.\n'
            'uid=\n'
            'for arg in "\$@"; do\n'
            '  case "\$arg" in\n'
            '    uid=*) uid="\${arg#uid=}" ;;\n'
            '  esac\n'
            'done\n'
            'if [ "\$uid" = "\${FIXTURE_CONTAINER_UID:-1000}" ] && '
            '[ -n "\${FIXTURE_CONTAINER_HOME:-}" ]; then\n'
            '  printf \'%s\\n\' "\${FIXTURE_CONTAINER_HOME}"\n'
            '  exit 0\n'
            'fi\n'
            'exit 1\n',
      );
      // Aliases are interactive conveniences: the proof file records that an
      // alias really existed in the shell that resolved the executable.
      await File('$homeAlias/.bash_profile').writeAsString(
        'export PATH="$bin:\$PATH"\n'
        'shopt -s expand_aliases\n'
        'alias codex=\'${fixture.path}/aliased-codex\'\n'
        'type codex > "\$HOME/alias-proof.txt" 2>&1 || true\n',
      );
      // Login shells reset PATH in /etc/profile: isolate the missing case so
      // the assertion never depends on whatever happens to be installed here.
      await File(
        '$homeMissing/.bash_profile',
      ).writeAsString('export PATH="${fixture.path}/empty-bin"\n');
      await File(
        '$homeDocker/.bashrc',
      ).writeAsString('export PATH="$bin:\$PATH"\n');
    });

    tearDown(() async {
      if (await fixture.exists()) {
        await fixture.delete(recursive: true);
      }
    });

    test('host：别名存在也解析真实路径，CODEX_PATH 导出并直接启动 acp', () async {
      final command = agentAcpLaunchCommand(_acpProfile());

      final result = await run(command, home: homeAlias);

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stderr,
        contains('Valhalla ACP Codex executable: $bin/codex'),
      );
      // The configured CLI's own --version output stays on stderr.
      expect(result.stderr, contains('codex mock version 9.9.9-mock'));
      expect(result.stderr, contains('ACP_MOCK_ARGS --stdio'));
      expect(result.stdout, contains('ACP_MOCK_STDOUT CODEX_PATH=$bin/codex'));
      expect(
        read('$homeAlias/alias-proof.txt'),
        contains('aliased-codex'),
        reason: '该 shell 里确实存在 codex 别名',
      );
      expect(result.stdout, isNot(contains('aliased-codex')));
      expect(
        result.stderr,
        isNot(contains('ACP_CODEX_EXECUTABLE_UNAVAILABLE')),
      );
    });

    test('host：绝对路径 acpCommand 被真正执行', () async {
      final command = agentAcpLaunchCommand(
        _acpProfile(acpCommand: '$bin/abs/codex-acp --stdio'),
      );

      final result = await run(command, home: homeAlias);

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout, contains('ACP_ABS_STDOUT'));
      expect(result.stdout, contains('CODEX_PATH=$bin/codex'));
      expect(result.stderr, contains('ACP_ABS_ARGS --stdio'));
    });

    test('host：目标 shell 里找不到 CLI 时失败退出且不降级', () async {
      final command = agentAcpLaunchCommand(_acpProfile());

      final result = await run(command, home: homeMissing);

      expect(result.exitCode, 127);
      expect(result.stderr, contains('ACP_CODEX_EXECUTABLE_UNAVAILABLE'));
      expect(result.stdout, isEmpty);
    });

    test('docker：user/容器路由生效且容器内仍解析并启动 acp', () async {
      final command = agentAcpLaunchCommand(
        _acpProfile(
          target: 'docker',
          binding: 'name',
          reference: 'codex-box',
          user: '1000:1000',
        ),
      );
      final argsFile = '${fixture.path}/docker-args.txt';

      final result = await run(
        command,
        // The image starts with its OWN home; only the fake container passwd
        // can map uid 1000 onto homeDocker. If the production HOME mapping
        // regressed, the mock would resolve the CLI from imageHome and fail.
        home: imageHome,
        environment: {
          'DOCKER_ARGS_FILE': argsFile,
          // Stub PATH is prepended inside the payload, after login startup.
          'FIXTURE_CONTAINER_PATH': '$stubBin:$bin',
          'FIXTURE_CONTAINER_UID': '1000',
          'FIXTURE_CONTAINER_HOME': homeDocker,
        },
      );

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      final args = read(argsFile).split('\n')..removeWhere((l) => l.isEmpty);
      expect(args.take(7), [
        'exec',
        '-i',
        '--user',
        '1000:1000',
        'codex-box',
        '/bin/sh',
        '-lc',
      ]);
      expect(args.last, contains('type -P'));
      expect(args.last, contains('exec codex-acp --stdio'));
      expect(
        result.stdout,
        contains('ACP_MOCK_STDOUT CODEX_PATH=$bin/codex'),
        reason:
            'stdout=${result.stdout}\nstderr=${result.stderr}\n'
            'args=${args.join(' ')}',
      );
      expect(
        result.stdout,
        contains('HOME=$homeDocker'),
        reason:
            'the selected user must run with the passwd-mapped home, '
            'not the image home ${result.stdout}',
      );
      expect(
        result.stderr,
        contains('Valhalla ACP Codex executable: $bin/codex'),
      );
    });
  });
}
