import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';

void main() {
  late Directory home;
  late String bin;

  Future<void> script(String path, String content) async {
    await File(path).writeAsString(content);
    final result = await Process.run('chmod', ['u+x', path]);
    expect(result.exitCode, 0);
  }

  Future<ProcessResult> run(
    String command, {
    Map<String, String> environment = const {},
  }) => Process.run(
    'bash',
    ['-c', command],
    environment: {
      'HOME': home.path,
      'PATH': '$bin:/usr/bin:/bin',
      'TEST_OS': 'Linux',
      'TEST_ARCH': 'x86_64',
      ...environment,
    },
  );

  setUp(() async {
    home = await Directory.systemTemp.createTemp('valhalla agy acp ');
    bin = '${home.path}/bin';
    await Directory(bin).create();
    await File(
      '${home.path}/.bash_profile',
    ).writeAsString('export PATH="$bin:/usr/bin:/bin"\n');
    await script('$bin/uname', r'''#!/bin/sh
if [ "$1" = -s ]; then echo "$TEST_OS"; else echo "$TEST_ARCH"; fi
''');
    await script('$bin/curl', r'''#!/bin/sh
if [ "${FAIL_DOWNLOAD:-0}" = 1 ]; then exit 22; fi
while [ "$#" -gt 0 ]; do
  case "$1" in
    https:*) printf "%s" "$1" > "$HOME/download-url" ;;
    -o) shift; touch "$1" ;;
  esac
  shift
done
''');
    await script('$bin/unzip', r'''#!/bin/sh
mkdir -p "$4"
printf '%s\n' '#!/bin/sh' 'printf "ACP_ARG=%s\n" "$@"' > "$4/agy_acp_server.par"
if [ "${INVALID_ARCHIVE:-0}" != 1 ]; then touch "$4/localharness_external"; fi
''');
  });

  tearDown(() async => home.delete(recursive: true));

  for (final entry in [
    ('Linux', 'x86_64', 'linux', 'linux-x86_64'),
    ('Linux', 'aarch64', 'linux', 'linux-arm64'),
    ('Darwin', 'arm64', 'macos', 'darwin-arm64'),
    ('Darwin', 'x86_64', 'macos', 'darwin-x86_64'),
  ]) {
    test(
      'installs and launches the official ${entry.$4} distribution offline',
      () async {
        final environment = {'TEST_OS': entry.$1, 'TEST_ARCH': entry.$2};
        final install = await run(
          kAntigravityAcpInstallCommand,
          environment: environment,
        );
        expect(install.exitCode, 0, reason: '${install.stderr}');
        expect(
          await File('${home.path}/download-url').readAsString(),
          'https://dl.google.com/agy-extensions/releases/${entry.$3}/agy-acp-server-1.2.1-${entry.$4}.zip',
        );
        expect(
          File(
            '${home.path}/.local/share/valhalla/antigravity-acp/1.2.1/localharness_external',
          ).existsSync(),
          isTrue,
        );
        final profile = AgentProfile(
          id: 'builtin-agy',
          serverId: 's',
          name: 'AGY',
          description: '',
          cliCommand: 'agy',
          acpCommand: 'agy_acp_server.par',
        );
        final launch = await run(
          agentAcpLaunchCommand(profile),
          environment: environment,
        );
        expect(launch.exitCode, 0, reason: '${launch.stderr}');
        expect(
          launch.stdout,
          entry.$1 == 'Linux' ? 'ACP_ARG=--uid=\n' : 'ACP_ARG=\n',
        );
        final lookup = await run(
          antigravityAcpLookupCommand,
          environment: environment,
        );
        expect(lookup.exitCode, 0);
        expect(lookup.stdout, '${home.path}/.local/bin/agy_acp_server.par\n');
        await File('${home.path}/download-url').delete();
        final repeat = await run(
          kAntigravityAcpInstallCommand,
          environment: {...environment, 'FAIL_DOWNLOAD': '1'},
        );
        expect(repeat.exitCode, 0, reason: '${repeat.stderr}');
        expect(File('${home.path}/download-url').existsSync(), isFalse);
      },
    );
  }

  test(
    'failed download or incomplete archive preserves an existing launcher',
    () async {
      final launcher = File('${home.path}/.local/bin/agy_acp_server.par');
      await launcher.parent.create(recursive: true);
      await launcher.writeAsString('previous launcher');
      for (final environment in [
        {'FAIL_DOWNLOAD': '1'},
        {'INVALID_ARCHIVE': '1'},
      ]) {
        final result = await run(
          kAntigravityAcpInstallCommand,
          environment: environment,
        );
        expect(result.exitCode, isNot(0));
        expect(await launcher.readAsString(), 'previous launcher');
        expect(
          Directory(
            '${home.path}/.local/share/valhalla/antigravity-acp/1.2.1',
          ).existsSync(),
          isFalse,
        );
        expect(
          await Directory(
            '${home.path}/.local/share/valhalla/antigravity-acp',
          ).list().toList(),
          isEmpty,
        );
      }
    },
  );

  test(
    'unsupported targets fail before downloading or writing a launcher',
    () async {
      for (final environment in [
        {'TEST_OS': 'Windows'},
        {'TEST_ARCH': 'riscv64'},
      ]) {
        final result = await run(
          kAntigravityAcpInstallCommand,
          environment: environment,
        );
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('ACP_INSTALL_'));
        expect(File('${home.path}/download-url').existsSync(), isFalse);
        expect(
          File('${home.path}/.local/bin/agy_acp_server.par').existsSync(),
          isFalse,
        );
      }
    },
  );
}
