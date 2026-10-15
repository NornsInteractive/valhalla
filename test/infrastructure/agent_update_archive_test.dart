import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/agents/agent_update_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'archive-fixture',
  name: 'archive fixture',
  host: 'fixture.invalid',
  username: 'fixture',
);

/// Supplies probe results only. Neither SSH nor the update executor is used.
class _ArchiveProbe implements SshCommandExecutor {
  _ArchiveProbe(this.home);

  final String home;

  @override
  bool isConnected(String serverId) => serverId == _server.id;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 25),
    String? sudoPassword,
  }) async {
    final values = {
      'uid': '1000',
      'home': home,
      'os': 'Linux',
      'arch': 'x86_64',
      'cliPath': '$home/.nvm/bin/codex',
      'cliCanonical': '$home/.nvm/lib/node_modules/@openai/codex/bin/codex',
      'cliVersion': 'codex 1.0.0',
      'npmPath': '$home/.nvm/bin/npm',
      'npmRoot': '$home/.nvm/lib/node_modules',
      'npmPrefix': '$home/.nvm',
      'cliPackage': '@openai/codex',
      'cliPackageVersion': '1.0.0',
      'nodeVersion': '22.0.0',
      'acpPath': '$home/.local/bin/agy_acp_server.par',
      'agyAcpVersion': '1.0.0',
      'python3': 'yes',
      'curl': 'yes',
    };
    return SSHExecutionResult(
      exitCode: 0,
      stdout: values.entries
          .map(
            (entry) =>
                '__VALHALLA_AGENT_UPDATE_V1__${entry.key}\t${entry.value}',
          )
          .join('\n'),
      stderr: '',
    );
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(minutes: 10),
    String? sudoPassword,
  }) => throw StateError('Real update execution is forbidden in this fixture');
}

// Only tiny local fixtures are generated. The zip-bomb case expands to 2 MiB,
// which exceeds the production ratio threshold but cannot consume large disk.
const _makeArchive = r'''
import pathlib,stat,struct,sys,zipfile
target=pathlib.Path(sys.argv[1]); kind=sys.argv[2]
with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_STORED) as archive:
 archive.writestr('agy_acp_server.par', b'AGENT-PAYLOAD-fixture-v2\n')
 archive.writestr('localharness_external', b'HARNESS-PAYLOAD-fixture-v2\n')
 if kind == 'traversal': archive.writestr('../escape.txt', b'escape')
 if kind == 'absolute': archive.writestr('/escape.txt', b'escape')
 if kind == 'backslash': archive.writestr('sub\escape.txt', b'escape')
 if kind in ('symlink', 'special'):
  info=zipfile.ZipInfo('unsafe-entry'); info.create_system=3
  info.external_attr=((stat.S_IFLNK if kind == 'symlink' else stat.S_IFIFO)|0o777)<<16
  archive.writestr(info, b'../outside')
 if kind == 'zipbomb': archive.writestr('bomb', b'0'*(2*1024*1024), compress_type=zipfile.ZIP_DEFLATED)
if kind in ('encrypted', 'crc'):
 data=bytearray(target.read_bytes()); local=data.index(b'PK\x03\x04'); central=data.index(b'PK\x01\x02')
 if kind == 'encrypted':
  for offset in (local+6,central+8): struct.pack_into('<H',data,offset,struct.unpack_from('<H',data,offset)[0]|1)
 else:
  name,extra=struct.unpack_from('<HH',data,local+26); data[local+30+name+extra]^=1
 target.write_bytes(data)
''';

void main() {
  group(
    'Linux isolated archive execution',
    () {
      late Directory task;
      late String home;
      late File launcher;
      late File previousRuntime;
      late String command;

      setUp(() async {
        task = await Directory.systemTemp.createTemp('valhalla-agent-archive-');
        home = '${task.path}/home';
        launcher = File('$home/.local/bin/agy_acp_server.par');
        previousRuntime = File(
          '$home/.local/share/valhalla/antigravity-acp/1.0.0/agy_acp_server.par',
        );
        await launcher.parent.create(recursive: true);
        await previousRuntime.parent.create(recursive: true);
        await launcher.writeAsString('OLD-LAUNCHER-DO-NOT-EXECUTE\n');
        await previousRuntime.writeAsString('OLD-RUNTIME-DO-NOT-EXECUTE\n');
        final bin = await Directory('${task.path}/bin').create();
        final curl = File('${bin.path}/curl');
        await curl.writeAsString(r'''#!/bin/sh
set -eu
destination=
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then destination="$2"; shift 2; else shift; fi
done
test -n "$destination"
exec /bin/cp -- "$FIXTURE_ARCHIVE" "$destination"
''');
        final mode = await Process.run('/bin/chmod', ['700', curl.path]);
        expect(mode.exitCode, 0);
        final service = AgentUpdateService(
          _ArchiveProbe(home),
          loadJson: (uri) async => uri.host == 'registry.npmjs.org'
              ? {'name': '@openai/codex', 'version': '1.0.0'}
              : {
                  'id': 'antigravity-acp',
                  'version': '2.0.0',
                  'distribution': {
                    'binary': {
                      'linux-x86_64': {
                        'archive':
                            'https://dl.google.com/agy-extensions/releases/linux/agy-acp-server-2.0.0-linux-x86_64.zip',
                      },
                    },
                  },
                },
        );
        final plan = await service.prepare(
          _server,
          AgentProfile(
            id: 'archive-agent',
            serverId: _server.id,
            name: 'archive fixture',
            description: '',
            cliCommand: 'codex',
            acpCommand: 'agy_acp_server.par',
          ),
        );
        command = plan.components.single.command!;
      });

      tearDown(() async {
        await task.delete(recursive: true);
      });

      Future<ProcessResult> execute(String kind) async {
        final archive = '${task.path}/fixture.zip';
        final generated = await Process.run(
          '/usr/bin/python3',
          ['-c', _makeArchive, archive, kind],
          includeParentEnvironment: false,
          environment: {'HOME': home, 'PATH': '/usr/bin:/bin'},
        ).timeout(const Duration(seconds: 10));
        expect(generated.exitCode, 0, reason: generated.stderr.toString());
        return Process.run(
          '/bin/sh',
          ['-c', command],
          includeParentEnvironment: false,
          environment: {
            'HOME': home,
            'PATH': '${task.path}/bin:/usr/bin:/bin',
            'FIXTURE_ARCHIVE': archive,
          },
        ).timeout(const Duration(seconds: 10));
      }

      test(
        'valid generated install script extracts, records hashes and switches only fixture launcher',
        () async {
          final result = await execute('valid');
          expect(result.exitCode, 0, reason: result.stderr.toString());
          final runtime = '$home/.local/share/valhalla/antigravity-acp/2.0.0';
          final manifest =
              jsonDecode(
                    await File('$runtime/valhalla-install.json').readAsString(),
                  )
                  as Map;
          expect(manifest['version'], '2.0.0');
          for (final name in ['agy_acp_server.par', 'localharness_external']) {
            final contents = await File('$runtime/$name').readAsBytes();
            expect((manifest['files'] as Map)[name], {
              'size': contents.length,
              'sha256': sha256.convert(contents).toString(),
            });
          }
          expect(
            await launcher.readAsString(),
            contains('/antigravity-acp/2.0.0/agy_acp_server.par'),
          );
          expect(
            await previousRuntime.readAsString(),
            'OLD-RUNTIME-DO-NOT-EXECUTE\n',
          );
          expect(
            result.stdout,
            isEmpty,
            reason: 'The fake agent must never be executed',
          );
        },
      );

      for (final (kind, error) in [
        ('traversal', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('absolute', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('backslash', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('symlink', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('special', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('encrypted', 'AGENT_UPDATE_ARCHIVE_INVALID'),
        ('crc', 'Bad CRC-32'),
        ('zipbomb', 'AGENT_UPDATE_ARCHIVE_TOO_LARGE'),
      ]) {
        test(
          '$kind archive is rejected without replacing old launcher/runtime',
          () async {
            final result = await execute(kind);
            expect(result.exitCode, isNot(0), reason: result.stderr.toString());
            expect(result.stderr, contains(error));
            expect(
              await launcher.readAsString(),
              'OLD-LAUNCHER-DO-NOT-EXECUTE\n',
            );
            expect(
              await previousRuntime.readAsString(),
              'OLD-RUNTIME-DO-NOT-EXECUTE\n',
            );
            expect(
              await Directory(
                '$home/.local/share/valhalla/antigravity-acp/2.0.0',
              ).exists(),
              isFalse,
            );
            expect(
              await task
                  .list(recursive: true)
                  .where((entry) => entry.path.endsWith('/escape.txt'))
                  .isEmpty,
              isTrue,
            );
          },
        );
      }
    },
    skip: Platform.isLinux
        ? false
        : 'Requires Linux /bin/sh and /usr/bin/python3 fixtures',
  );
}
