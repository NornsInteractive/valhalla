import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';

AgentProfile _profile({bool docker = false, String cli = 'codex'}) =>
    AgentProfile(
      id: 'fixture-codex',
      serverId: 'fixture-server',
      name: 'Fixture Codex',
      description: '',
      cliCommand: cli,
      acpCommand: 'codex-acp --stdio',
      executionTarget: docker ? 'docker' : 'host',
      containerBinding: 'name',
      containerReference: docker ? 'fixture-box' : null,
    );

/// Every executable named codex, codex-acp or docker lives in this fixture.
/// The bash shim sources only this temporary HOME, never real startup files.
class _ShellFixture {
  _ShellFixture(this.root);

  final Directory root;
  String get home => '${root.path}/home';
  String get tools => '${root.path}/tools';
  String get runtime => '${root.path}/runtime';
  String get login => '${root.path}/login';
  File get capture => File('${root.path}/captured.json');

  static Future<_ShellFixture> create() async {
    final fixture = _ShellFixture(
      await Directory.systemTemp.createTemp('valhalla-codex-runtime-'),
    );
    for (final directory in [
      fixture.home,
      fixture.tools,
      fixture.runtime,
      fixture.login,
    ]) {
      await Directory(directory).create();
    }
    final lookup = await Process.run('/bin/sh', ['-c', 'command -v node']);
    expect(
      lookup.exitCode,
      0,
      reason: 'Node is required for the real merge JS',
    );
    await Link(
      '${fixture.runtime}/node',
    ).create(lookup.stdout.toString().trim());
    await fixture.executable('${fixture.tools}/bash', r'''#!/bin/sh
if [ "$1" = '-l' ] && [ "$2" = '-c' ]; then
  exec /bin/bash --noprofile --norc -c '. "$HOME/.bash_profile"; eval "$1"' fixture "$3"
fi
if [ "$1" = '-ic' ]; then
  exec /bin/bash --noprofile --rcfile "$HOME/.bashrc" -ic "$2"
fi
exit 90
''');
    await fixture.executable('${fixture.tools}/docker', r'''#!/bin/sh
[ "$1" = exec ] && [ "$2" = -i ] && [ "$3" = fixture-box ] || exit 91
shift 3
exec "$@"
''');
    await File('${fixture.home}/.bash_profile').writeAsString(r'''
printf '%s\n' FIXTURE_LOGIN_BANNER
export PATH="$FIXTURE_LOGIN:$PATH"
''');
    await File('${fixture.home}/.bashrc').writeAsString(r'''
printf '%s\n' FIXTURE_INTERACTIVE_BANNER
export PATH="$FIXTURE_RUNTIME:$PATH"
export HISTFILE="$HOME/history-must-not-exist"
set -o history
codex() { printf function-must-not-run; }
alias codex='printf alias-must-not-run'
''');
    await fixture.executable('${fixture.login}/codex', '''#!/bin/sh
printf '%s\\n' wrong-login-codex >&2
exit 92
''');
    await fixture.executable('${fixture.runtime}/codex', r'''#!/bin/sh
if [ "$1" = --version ]; then printf '%s\n' 'codex fixture-runtime'; exit 0; fi
printf '%s\n' unexpected-real-cli-operation >&2
exit 93
''');
    await File('${fixture.root.path}/capture.js').writeAsString(r'''
const fs = require('node:fs');
fs.writeFileSync(process.env.FIXTURE_CAPTURE, JSON.stringify({
  config: process.env.CODEX_CONFIG,
  codex: process.env.CODEX_PATH,
  args: process.argv.slice(2)
}));
process.stdout.write('{"fixture":"acp"}\n');
''');
    await fixture.executable('${fixture.runtime}/codex-acp', r'''#!/bin/sh
if [ "$1" = --version ]; then
  printf '%s\n' "${FIXTURE_ACP_VERSION:-@agentclientprotocol/codex-acp 2.0.0}"
  exit 0
fi
exec node "$FIXTURE_CAPTURE_SCRIPT" "$@"
''');
    return fixture;
  }

  Future<void> executable(String path, String script) async {
    await File(path).writeAsString(script);
    final result = await Process.run('/bin/chmod', ['700', path]);
    expect(result.exitCode, 0);
  }

  Future<ProcessResult> run(
    String command, {
    Map<String, String> environment = const {},
  }) => Process.run(
    '/bin/sh',
    ['-c', command],
    includeParentEnvironment: false,
    environment: {
      'HOME': home,
      'PATH': '$tools:/usr/bin:/bin',
      'TERM': 'dumb',
      'FIXTURE_LOGIN': login,
      'FIXTURE_RUNTIME': runtime,
      'FIXTURE_CAPTURE': capture.path,
      'FIXTURE_CAPTURE_SCRIPT': '${root.path}/capture.js',
      ...environment,
    },
  ).timeout(const Duration(seconds: 10));
}

void main() {
  late _ShellFixture fixture;

  setUp(() async {
    fixture = await _ShellFixture.create();
  });
  tearDown(() async {
    await fixture.root.delete(recursive: true);
  });

  for (final docker in [false, true]) {
    final target = docker ? 'Docker' : 'host';
    test(
      '$target executes multiline shell without stdout startup noise',
      () async {
        const script = r'''printf '%s\n' 'first
second'\''quote $(printf unintended)'
printf '%s\n' "${HISTFILE-unset}"
if set -o | /bin/grep '^history[[:space:]]*on$' >/dev/null; then exit 95; fi
''';
        final result = await fixture.run(
          agentCodexTargetCommand(_profile(docker: docker), script),
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          "first\nsecond'quote \$(printf unintended)\nunset\n",
        );
        expect(result.stderr, contains('FIXTURE_INTERACTIVE_BANNER'));
        if (!docker) expect(result.stderr, contains('FIXTURE_LOGIN_BANNER'));
        expect(
          await File('${fixture.home}/history-must-not-exist').exists(),
          isFalse,
        );
      },
    );

    test(
      '$target executes merge JS, preserves config and does not log secrets',
      () async {
        const secret = "fixture-secret-'\n\$(do-not-execute)";
        final inherited = {
          'model': 'stale-model',
          'model_provider': 'fixture-provider',
          'permissions': {'token': secret, 'allow': false},
        };
        final result = await fixture.run(
          agentAcpLaunchCommand(
            _profile(docker: docker),
            initialModelId: 'model-B',
          ),
          environment: {'CODEX_CONFIG': jsonEncode(inherited)},
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout, '{"fixture":"acp"}\n');
        final captured =
            jsonDecode(await fixture.capture.readAsString()) as Map;
        expect(jsonDecode(captured['config'] as String), {
          ...inherited,
          'model': 'model-B',
        });
        expect(captured['codex'], '${fixture.runtime}/codex');
        expect(captured['args'], ['--stdio']);
        expect(result.stderr, contains('codex fixture-runtime'));
        expect(result.stderr, contains('initial model override applied'));
        expect(result.stderr, isNot(contains('fixture-secret')));
        expect(result.stdout, isNot(contains('fixture-secret')));
        expect(result.stderr, isNot(contains('wrong-login-codex')));
        expect(result.stderr, isNot(contains('alias-must-not-run')));
        expect(result.stderr, isNot(contains('function-must-not-run')));
      },
    );
  }

  test(
    'invalid inherited config fails before ACP launch without leaking value',
    () async {
      for (final value in [
        '{fixture-secret',
        'null',
        '[]',
        '42',
        '"fixture-secret"',
      ]) {
        final result = await fixture.run(
          agentAcpLaunchCommand(_profile(), initialModelId: 'model-B'),
          environment: {'CODEX_CONFIG': value},
        );
        expect(result.exitCode, 78, reason: '$value: ${result.stderr}');
        expect(result.stderr, contains('ACP_CODEX_CONFIG_INVALID'));
        expect(result.stderr, isNot(contains('fixture-secret')));
        expect(result.stdout, isEmpty);
        expect(await fixture.capture.exists(), isFalse);
      }
    },
  );

  test(
    'missing config merges model; unknown adapter keeps inherited bytes',
    () async {
      final missing = await fixture.run(
        agentAcpLaunchCommand(_profile(), initialModelId: 'model-B'),
      );
      expect(missing.exitCode, 0, reason: missing.stderr.toString());
      var captured = jsonDecode(await fixture.capture.readAsString()) as Map;
      expect(jsonDecode(captured['config'] as String), {'model': 'model-B'});

      const inherited = '{ "model": "keep", "secret": "fixture-secret" }';
      final unknown = await fixture.run(
        agentAcpLaunchCommand(_profile(), initialModelId: 'model-B'),
        environment: {
          'CODEX_CONFIG': inherited,
          'FIXTURE_ACP_VERSION': 'unknown-adapter 99',
        },
      );
      expect(unknown.exitCode, 0, reason: unknown.stderr.toString());
      captured = jsonDecode(await fixture.capture.readAsString()) as Map;
      expect(captured['config'], inherited);
      expect(unknown.stderr, contains('override unsupported'));
      expect(unknown.stderr, isNot(contains('fixture-secret')));
    },
  );

  test(
    'restored runtime with no initial model does not rewrite config',
    () async {
      const inherited = '{ "model": "restore-original", "keep": true }';
      final result = await fixture.run(
        agentAcpLaunchCommand(_profile()),
        environment: {'CODEX_CONFIG': inherited},
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final captured = jsonDecode(await fixture.capture.readAsString()) as Map;
      expect(captured['config'], inherited);
      expect(result.stderr, isNot(contains('initial model override')));
    },
  );

  test(
    'script NUL fails and data arguments keep strict newline validation',
    () {
      for (final docker in [false, true]) {
        expect(
          () => agentCodexTargetCommand(
            _profile(docker: docker),
            'printf x\u0000',
          ),
          throwsArgumentError,
        );
      }
      expect(() => cliShellQuote('line\nbreak'), throwsArgumentError);
      expect(
        () => agentCodexExecutableScript(_profile(cli: '/tmp/codex\nevil')),
        throwsArgumentError,
      );
      expect(
        () => agentAcpLaunchCommand(_profile(), initialModelId: 'model\nbad'),
        throwsStateError,
      );
    },
  );
}
