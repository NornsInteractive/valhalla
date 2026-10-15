import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_update.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/agents/agent_update_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'srv-1',
  name: 'fixture',
  host: 'fixture.invalid',
  username: 'dev',
);

AgentProfile _profile({String cli = 'codex', String? acp}) => AgentProfile(
  id: 'agent-1',
  serverId: _server.id,
  name: 'Fixture',
  description: '',
  cliCommand: cli,
  acpCommand: acp,
);

Map<String, String> _npmProbe({
  String cli = 'codex',
  String package = '@openai/codex',
}) => {
  'uid': '1000',
  'home': '/home/dev',
  'os': 'Linux',
  'arch': 'x86_64',
  'cliPath': '/home/dev/.nvm/bin/$cli',
  'cliCanonical': '/home/dev/.nvm/lib/node_modules/$package/bin/$cli',
  'acpPath': '',
  'cliVersion': '$cli 1.0.0',
  'npmPath': '/home/dev/.nvm/bin/npm',
  'npmRoot': '/home/dev/.nvm/lib/node_modules',
  'npmPrefix': '/home/dev/.nvm',
  'cliPackage': package,
  'cliPackageVersion': '1.0.0',
  'nodeVersion': '22.0.0',
};

class _FakeSsh implements SshCommandExecutor {
  Map<String, String> values = _npmProbe();
  Map<String, String>? afterValues;
  int? exitCode = 0;
  bool connected = true;
  String containerId = 'a' * 64;
  final commands = <String>[];
  final streamed = <String>[];

  @override
  bool isConnected(String serverId) => connected && serverId == _server.id;
  @override
  SSHClient? getClient(String serverId) => null;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 25),
    String? sudoPassword,
  }) async {
    commands.add(command);
    if (command.startsWith('docker inspect ')) {
      return SSHExecutionResult(
        exitCode: 0,
        stdout: '$containerId true',
        stderr: '',
      );
    }
    final probe = streamed.isNotEmpty ? afterValues ?? values : values;
    return SSHExecutionResult(
      exitCode: 0,
      stdout:
          'ignored rc banner\n${probe.entries.map((entry) => '__VALHALLA_AGENT_UPDATE_V1__${entry.key}\t${entry.value}').join('\n')}',
      stderr: '',
    );
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(minutes: 10),
    String? sudoPassword,
  }) async* {
    streamed.add(command);
    yield const SSHExecutionChunk(
      kind: SSHStreamKind.stdout,
      text: 'fixture progress\n',
    );
    if (exitCode != null) {
      yield SSHExecutionChunk(
        kind: SSHStreamKind.stdout,
        text: '',
        exitCode: exitCode,
      );
    }
  }
}

Matcher _error(String code) =>
    isA<AgentUpdateException>().having((error) => error.code, 'code', code);

AgentUpdateService _service(
  _FakeSsh ssh, {
  DateTime Function()? now,
  AgentUpdateJsonLoader? load,
}) => AgentUpdateService(
  ssh,
  now: now,
  loadJson:
      load ??
      (uri) async => {
        'name': uri.path.replaceFirst('/', '').replaceFirst('/latest', ''),
        'version': '2.0.0',
      },
);

void main() {
  test(
    'npm probe resolves current target and prepares exact version without mutation',
    () async {
      final ssh = _FakeSsh();
      final service = _service(ssh);
      final report = await service.check(_server, _profile());
      final cli = report.components.single;
      expect(cli.status, AgentUpdateStatus.available);
      expect(cli.installedVersion, '1.0.0');
      expect(cli.latestVersion, '2.0.0');
      expect(cli.source, '@openai/codex');
      expect(cli.command, contains("'@openai/codex@2.0.0'"));
      expect(cli.command, contains("--prefix '/home/dev/.nvm'"));
      expect(cli.command, contains('npm_config_engine_strict=true'));
      final plan = await service.prepare(_server, _profile());
      expect(plan.components.single.command, cli.command);
      expect(ssh.streamed, isEmpty);
      expect(
        ssh.commands.every((command) => command.contains('unset HISTFILE')),
        isTrue,
      );
      expect(
        ssh.commands.every((command) => !command.contains('codex-acp --help')),
        isTrue,
      );
    },
  );

  test(
    'unknown executable and unrecognized install origin remain manual-only',
    () async {
      final ssh = _FakeSsh();
      final unknown = await _service(
        ssh,
      ).check(_server, _profile(cli: 'custom-wrapper'));
      expect(unknown.components.single.status, AgentUpdateStatus.unsupported);
      expect(
        unknown.components.single.reasonCode,
        'AGENT_UPDATE_CUSTOM_COMMAND',
      );
      ssh.values['cliPackage'] = 'other-owner';
      final other = await _service(ssh).check(_server, _profile());
      expect(other.components.single.status, AgentUpdateStatus.unsupported);
      expect(
        other.components.single.reasonCode,
        'AGENT_UPDATE_INSTALL_SOURCE_UNKNOWN',
      );
      expect(ssh.streamed, isEmpty);
    },
  );

  test(
    'catalog validation and Node requirement fail before an update plan',
    () async {
      final ssh = _FakeSsh();
      final wrongName = await _service(
        ssh,
        load: (_) async => {'name': 'untrusted-package', 'version': '2.0.0'},
      ).check(_server, _profile());
      expect(
        wrongName.components.single.reasonCode,
        'AGENT_UPDATE_CATALOG_INVALID',
      );
      final badVersion = await _service(
        ssh,
        load: (_) async => {
          'name': '@openai/codex',
          'version': '2.0.0; whoami',
        },
      ).check(_server, _profile());
      expect(badVersion.components.single.status, AgentUpdateStatus.error);
      ssh.values['nodeVersion'] = '20.1.0';
      final oldNode = await _service(
        ssh,
        load: (_) async => {
          'name': '@openai/codex',
          'version': '2.0.0',
          'engines': {'node': '>=22'},
        },
      ).check(_server, _profile());
      expect(oldNode.components.single.status, AgentUpdateStatus.unsupported);
      expect(
        oldNode.components.single.reasonCode,
        'AGENT_UPDATE_NODE_UNSUPPORTED',
      );
      expect(oldNode.components.single.command, isNull);
      expect(ssh.streamed, isEmpty);
    },
  );

  test(
    'preview install cannot be replaced and newer installs are not downgraded',
    () async {
      final ssh = _FakeSsh();
      ssh.values['cliVersion'] = 'codex 2.0.0-preview';
      final preview = await _service(ssh).check(_server, _profile());
      expect(
        preview.components.single.reasonCode,
        'AGENT_UPDATE_VERSION_UNKNOWN',
      );
      ssh.values['cliVersion'] = 'codex 3.0.0';
      final newer = await _service(ssh).check(_server, _profile());
      expect(newer.components.single.status, AgentUpdateStatus.current);
      expect(newer.components.single.command, isNull);
    },
  );

  test(
    'catalog cache coalesces reads but manual force fetches latest again',
    () async {
      final ssh = _FakeSsh();
      var requests = 0;
      final gate = Completer<Map<String, dynamic>>();
      final service = _service(
        ssh,
        load: (_) {
          requests++;
          return gate.future;
        },
      );
      final first = service.check(_server, _profile());
      final second = service.check(_server, _profile());
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      gate.complete({'name': '@openai/codex', 'version': '2.0.0'});
      await Future.wait([first, second]);
      await service.check(_server, _profile());
      expect(requests, 1);
      await service.check(_server, _profile(), force: true);
      expect(requests, 2);
    },
  );

  for (final changed in [
    {'uid': '999'},
    {'home': '/other'},
    {'cliPath': '/other/codex'},
    {'npmPrefix': '/other'},
    {'cliVersion': 'codex 1.1.0'},
  ]) {
    test(
      'confirmation rejects changed runtime ${changed.keys.single}',
      () async {
        final ssh = _FakeSsh();
        final service = _service(ssh);
        final plan = await service.prepare(_server, _profile());
        ssh.values.addAll(changed);
        await expectLater(
          service.apply(plan, isCurrent: () => true, onLog: (_) {}),
          throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
        );
        expect(ssh.streamed, isEmpty);
      },
    );
  }

  test(
    'Docker name replacement invalidates plan and probes pinned user/ID',
    () async {
      final ssh = _FakeSsh();
      final profile = _profile().copyWith(
        executionTarget: 'docker',
        containerBinding: 'name',
        containerReference: 'workspace',
        containerUser: 'dev',
      );
      final service = _service(ssh);
      final plan = await service.prepare(_server, profile);
      expect(plan.resolvedContainerId, 'a' * 64);
      expect(ssh.commands.last, contains('--user'));
      expect(ssh.commands.last, contains('dev'));
      expect(ssh.commands.last, contains('a' * 64));
      ssh.containerId = 'b' * 64;
      await expectLater(
        service.apply(plan, isCurrent: () => true, onLog: (_) {}),
        throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
      );
      expect(ssh.streamed, isEmpty);
    },
  );

  test('expired plan fails before any apply probe or command', () async {
    var now = DateTime(2026, 10, 15);
    final ssh = _FakeSsh();
    final service = _service(ssh, now: () => now);
    final plan = await service.prepare(_server, _profile());
    final probes = ssh.commands.length;
    now = now.add(const Duration(minutes: 16));
    await expectLater(
      service.apply(plan, isCurrent: () => true, onLog: (_) {}),
      throwsA(_error('AGENT_UPDATE_PLAN_EXPIRED')),
    );
    expect(ssh.commands.length, probes);
    expect(ssh.streamed, isEmpty);
  });

  test(
    'zero exit plus verified version is successful and streams progress',
    () async {
      final ssh = _FakeSsh();
      ssh.afterValues = {
        ...ssh.values,
        'cliVersion': 'codex 2.0.0',
        'cliPackageVersion': '2.0.0',
      };
      final service = _service(ssh);
      final profile = _profile();
      final plan = await service.prepare(_server, profile);
      final logs = <String>[];
      expect(
        await service.apply(plan, isCurrent: () => true, onLog: logs.add),
        profile,
      );
      expect(ssh.streamed, hasLength(1));
      expect(logs.join(), contains('fixture progress'));
      expect(logs.join(), contains('cli: verified 2.0.0'));
      expect(ssh.streamed.single, contains('AGENT_UPDATE_TARGET_CHANGED'));
    },
  );

  for (final exit in <int?>[7, -1, null]) {
    test('nonzero or missing terminal exit fails: $exit', () async {
      final ssh = _FakeSsh()..exitCode = exit;
      final service = _service(ssh);
      final plan = await service.prepare(_server, _profile());
      await expectLater(
        service.apply(plan, isCurrent: () => true, onLog: (_) {}),
        throwsA(_error('AGENT_UPDATE_EXECUTION_FAILED')),
      );
      expect(ssh.streamed, hasLength(1));
      expect(
        ssh.commands,
        hasLength(2),
        reason: 'No post-version success probe after failed execution',
      );
    });
  }

  test(
    'zero exit is insufficient when installed version is unchanged',
    () async {
      final ssh = _FakeSsh();
      final service = _service(ssh);
      final plan = await service.prepare(_server, _profile());
      await expectLater(
        service.apply(plan, isCurrent: () => true, onLog: (_) {}),
        throwsA(_error('AGENT_UPDATE_VERSION_UNCHANGED')),
      );
      expect(ssh.streamed, hasLength(1));
      expect(ssh.commands, hasLength(3));
    },
  );

  test(
    'OpenCode shared CLI/ACP produces one component and standard Codex ACP accepts --stdio',
    () async {
      final openSsh = _FakeSsh()
        ..values = _npmProbe(cli: 'opencode', package: 'opencode-ai');
      final open = await _service(
        openSsh,
      ).check(_server, _profile(cli: 'opencode', acp: 'opencode acp'));
      expect(open.components, hasLength(1));
      final codex = _FakeSsh();
      codex.values.addAll({
        'acpPath': '/home/dev/.nvm/bin/codex-acp',
        'acpPackage': '@agentclientprotocol/codex-acp',
        'acpPackageVersion': '1.0.0',
      });
      final report = await _service(
        codex,
      ).check(_server, _profile(acp: 'codex-acp --stdio'));
      expect(report.components.last.status, AgentUpdateStatus.available);
      expect(report.components.last.source, '@agentclientprotocol/codex-acp');
    },
  );

  test(
    'Claude migration changes profile only after verifying new adapter',
    () async {
      final ssh = _FakeSsh()
        ..values = _npmProbe(
          cli: 'claude',
          package: '@anthropic-ai/claude-code',
        );
      ssh.values.addAll({
        'acpPath': '/home/dev/.nvm/bin/claude-code-acp',
        'acpPackage': '@zed-industries/claude-code-acp',
        'acpPackageVersion': '1.0.0',
      });
      ssh.afterValues = {
        ...ssh.values,
        'acpPath': '/home/dev/.nvm/bin/claude-agent-acp',
        'acpPackage': '@agentclientprotocol/claude-agent-acp',
        'acpPackageVersion': '2.0.0',
      };
      final profile = _profile(cli: 'claude', acp: 'claude-code-acp').copyWith(
        acpInstallCommand: 'npm install -g @zed-industries/claude-code-acp',
      );
      final service = _service(ssh);
      final plan = await service.prepare(
        _server,
        profile,
        components: {AgentUpdateComponent.acp},
      );
      expect(plan.components.single.migratesClaudeAdapter, isTrue);
      final updated = await service.apply(
        plan,
        isCurrent: () => true,
        onLog: (_) {},
      );
      expect(updated.acpCommand, 'claude-agent-acp');
      expect(
        updated.acpInstallCommand,
        'npm install -g @agentclientprotocol/claude-agent-acp',
      );
      expect(profile.acpCommand, 'claude-code-acp');
      expect(ssh.streamed.single, isNot(contains('uninstall')));
    },
  );

  test(
    'AgY official updater rechecks manifest identity before execution',
    () async {
      final ssh = _FakeSsh();
      ssh.values = {
        'uid': '1000',
        'home': '/home/dev',
        'os': 'Linux',
        'arch': 'x86_64',
        'libc': 'musl',
        'cliPath': '/home/dev/.local/bin/agy',
        'cliCanonical': '/home/dev/.local/bin/agy',
        'cliVersion': 'agy 1.0.0',
        'acpPath': '',
      };
      var latest = '2.0.0';
      final requests = <Uri>[];
      final service = _service(
        ssh,
        load: (uri) async {
          requests.add(uri);
          return {
            'version': latest,
            'url':
                'https://storage.googleapis.com/antigravity-public/antigravity-cli/$latest-123/linux-x64/archive.tar.gz',
            'sha512': 'a' * 128,
          };
        },
      );
      final plan = await service.prepare(_server, _profile(cli: 'agy'));
      expect(plan.commandPreview, "'/home/dev/.local/bin/agy' update");
      expect(requests.single.path, endsWith('/linux_amd64_musl.json'));
      latest = '2.1.0';
      await expectLater(
        service.apply(plan, isCurrent: () => true, onLog: (_) {}),
        throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
      );
      expect(requests, hasLength(2));
      expect(ssh.streamed, isEmpty);
    },
  );

  test(
    'managed AgY ACP plan bounds archive extraction and refuses existing destination',
    () async {
      final ssh = _FakeSsh();
      ssh.values.addAll({
        'acpPath': '/home/dev/.local/bin/agy_acp_server.par',
        'agyAcpVersion': '1.0.0',
        'python3': 'yes',
        'curl': 'yes',
      });
      final service = _service(
        ssh,
        load: (uri) async => uri.host == 'registry.npmjs.org'
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
        _profile(acp: 'agy_acp_server.par'),
      );
      final command = plan.components.single.command!;
      expect(command, contains('AGENT_UPDATE_VERSION_DIRECTORY_EXISTS'));
      expect(command, contains('--max-filesize 4294967296'));
      expect(command, contains('8589934592'));
      expect(command, contains('len(members)>20000'));
      expect(command, contains("'..' in path.parts"));
      expect(command, contains('stat.S_IFREG,stat.S_IFDIR'));
      expect(command, contains('item.flag_bits&1'));
      expect(command, contains('item.compress_size*500'));
      expect(
        command.indexOf('archive.extractall'),
        lessThan(command.indexOf(r'mv "$valhalla_tmp/launcher"')),
      );
      expect(
        ssh.streamed,
        isEmpty,
        reason:
            'Fixture inspects plan only; no archive is downloaded or executed',
      );
    },
  );
}
