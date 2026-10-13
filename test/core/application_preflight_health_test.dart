import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

import '../support/application_center_fakes.dart';

final _hostId = 'a' * 32;
final _daemonId = 'fixture-daemon';

/// 按命令子串应答的脚本化执行器；未命中即抛错，把遗漏的命令暴露为缺口。
class _ScriptedSsh implements SshCommandExecutor {
  _ScriptedSsh({this.client});

  SSHClient? client;
  final commands = <String>[];
  final timeouts = <Duration>[];
  void Function(String command)? onCommand;
  final _replies = <String, SSHExecutionResult>{};

  void stub(String needle, String stdout, {int exitCode = 0}) =>
      _replies[needle] = SSHExecutionResult(
        exitCode: exitCode,
        stdout: stdout,
        stderr: '',
      );

  @override
  bool isConnected(String serverId) => client != null;

  @override
  SSHClient? getClient(String serverId) => client;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    timeouts.add(timeout);
    onCommand?.call(command);
    for (final entry in _replies.entries) {
      if (command.contains(entry.key)) return entry.value;
    }
    throw StateError('unexpected command: $command');
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream.empty();
}

class _Session extends Fake implements SSHSession {
  _Session(this.output);

  final String output;

  @override
  int get exitCode => 0;

  @override
  Stream<Uint8List> get stdout =>
      Stream.value(Uint8List.fromList(utf8.encode(output)));

  @override
  Stream<Uint8List> get stderr => const Stream.empty();

  @override
  Future<void> get done async {}

  @override
  void close() {}
}

class _WriteSession extends _Session {
  final _input = StreamController<Uint8List>();
  _WriteSession(void Function(String) saved) : super('') {
    final bytes = <int>[];
    _input.stream.listen(bytes.addAll, onDone: () => saved(utf8.decode(bytes)));
  }
  @override
  StreamSink<Uint8List> get stdin => _input.sink;
}

/// 给 `_readPrivateJson`(client.execute) 提供私有配置/编排文件内容。
class _Client extends Fake implements SSHClient {
  _Client({this.composeJson = '', this.configurationJson, this.templateJson});

  final String composeJson;
  final String? configurationJson;
  final String? templateJson;
  final sessions = <String>[];
  final writes = <String, String>{};

  @override
  bool get isClosed => false;

  @override
  Future<SSHSession> execute(
    String command, {
    Map<String, String>? environment,
    SSHPtyConfig? pty,
    SSHX11Config? x11,
  }) async {
    sessions.add(command);
    if (command.contains('cat >')) {
      return _WriteSession((content) => writes[command] = content);
    }
    if (command.contains('compose.json')) return _Session(composeJson);
    if (command.contains('configuration.json')) {
      return _Session(configurationJson ?? '{}');
    }
    if (command.contains('template.json')) {
      return _Session(templateJson ?? '{}');
    }
    throw StateError('unexpected client.execute: $command');
  }
}

ApplicationConfiguration _config() => ApplicationConfiguration(
  name: 'Fixture',
  dataRoot: '/home/dev/data',
  ports: const [ApplicationPort(service: 'web', target: 80, published: 18080)],
  variables: {'AppID': 'a' * 32, 'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
);

String _previousConfigurationJson() => jsonEncode({
  'name': 'Fixture',
  'dataRoot': '/home/dev/data',
  'bindAddress': '127.0.0.1',
  'ports': <Object>[
    {'service': 'web', 'target': 80, 'published': 18080, 'protocol': 'tcp'},
  ],
  'mounts': <Object>[],
  'variables': {'AppID': 'b' * 32},
  'environment': <String, dynamic>{},
});

/// 上一版 compose：environment 的值与即将写入的版本不同，但键集相同。
String _previousComposeJson({
  String token = 'cached-secret',
  String? extraKey,
}) {
  return jsonEncode({
    'name': 'valhalla-app-${'b' * 32}',
    'services': {
      'web': {
        'image': 'nginx:alpine',
        'ports': ['8080:80'],
        'environment': {'TOKEN': token, ?extraKey: token},
      },
    },
  });
}

/// update 需要的全部只读应答（含私有配置/编排文件与 docker ps/inspect）。
_ScriptedSsh _updateSsh({String token = 'cached-secret', bool named = false}) {
  final previousConfig =
      jsonDecode(_previousConfigurationJson()) as Map<String, dynamic>;
  final previousCompose =
      jsonDecode(_previousComposeJson(token: token)) as Map<String, dynamic>;
  if (named) {
    previousConfig.addAll({
      'instanceContainerNames': true,
      'mainService': 'web',
    });
    previousCompose['services']['web']['container_name'] = 'Fixture';
  }
  final client = _Client(
    composeJson: jsonEncode(previousCompose),
    configurationJson: jsonEncode(previousConfig),
    templateJson: jsonEncode({
      'application': centerApp.toJson(),
      'compose': centerTemplate.compose,
      'metadata': centerTemplate.metadata,
    }),
  );
  final ssh = _ScriptedSsh(client: client);
  ssh.stub('cat /etc/machine-id', _hostId);
  ssh.stub('docker info --format', _daemonId);
  ssh.stub('.valhalla-app-owner', centerDeployment().id);
  ssh.stub('ss -H', '');
  ssh.stub('docker ps -aq --filter', 'c' * 64);
  ssh.stub('docker ps -aq --no-trunc', 'c' * 64);
  ssh.stub('docker ps -a --no-trunc --format', '');
  ssh.stub('"image"', '{"service":"web","image":"sha256:${'d' * 64}"}');
  ssh.stub('.NetworkSettings.Ports', _bindingRecord());
  ssh.stub(
    'df -Pk',
    'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
        '/dev/sda1 1048576 262144 786432 75% /home/dev/data',
  );
  return ssh;
}

const _dfHeader = 'Filesystem 1024-blocks Used Available Capacity Mounted on';
const _dfRow = '/dev/sda1 1048576 262144 786432 75% /home/dev/data';

String _bindingRecord({
  String state = 'running',
  String? instance,
  Map<String, dynamic>? ports,
}) => jsonEncode({
  'service': 'web',
  'instance': instance ?? centerDeployment().id,
  'project': centerDeployment().project,
  'state': state,
  'health': 'healthy',
  'ports':
      ports ??
      {
        '80/tcp': [
          {'HostIp': '127.0.0.1', 'HostPort': '18080'},
        ],
      },
});

Matcher _centerError(String code) => throwsA(
  isA<ApplicationCenterException>().having((error) => error.code, 'code', code),
);

String _nameRecord({
  String name = 'Fixture',
  String? instance,
  String? project,
  String service = 'web',
}) => jsonEncode({
  'name': name,
  'instance': instance ?? centerDeployment().id,
  'project': project ?? centerDeployment().project,
  'service': service,
});

void main() {
  test('unsafe remote Docker context cannot offer engine bootstrap', () async {
    for (final endpoint in [
      'unix:///var/run/docker.sock',
      'tcp://remote.invalid:2376',
    ]) {
      final ssh = _ScriptedSsh()
        ..stub('uname -s', 'Linux\n0\n0\n/root\nx86_64\n$_hostId\ndebian\n12')
        ..stub('docker info', _daemonId)
        ..stub('docker compose version', '2.40.0')
        ..stub('cat /proc/1/comm', '')
        ..stub('docker context inspect', endpoint)
        ..stub('DOCKER_HOST-', '')
        ..stub('command -v bash', '/bin/bash');
      final env = await ApplicationDeploymentService(ssh).inspect(centerServer);
      expect(env.dockerAvailable, true);
      expect(env.canBootstrap, endpoint.startsWith('unix:///'));
      expect(
        env.blockers,
        endpoint.startsWith('unix:///')
            ? isEmpty
            : contains('APP_CENTER_LOCAL_DOCKER_REQUIRED'),
      );
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reconcile 容器健康', () {
    String psIds(int count) => List.generate(count, (_) => 'c' * 12).join('\n');

    test('running+healthy 且 health=none 均算健康，服务在部署 JSON 里往返', () async {
      final ssh = _ScriptedSsh();
      final service = ApplicationDeploymentService(ssh);
      final app = centerDeployment();
      final env = centerEnvironment();
      ssh.stub('.valhalla-app-owner', app.id);
      ssh.stub(
        'deployment.json',
        jsonEncode(
          app
              .copyWith(
                services: const [
                  ApplicationServiceHealth(
                    name: 'web-1',
                    state: 'running',
                    health: 'healthy',
                  ),
                  ApplicationServiceHealth(name: 'web-2', state: 'running'),
                ],
              )
              .toJson(),
        ),
      );
      ssh.stub('docker ps -aq --no-trunc', '${'c' * 12}\n${'d' * 64}');
      ssh.stub(
        '{{json .Name}}',
        '"/web-1"|"running"|"healthy"\n"/web-2"|"running"|"none"',
      );

      final result = (await service.reconcile(app, env))!;
      expect(result.status, 'running');
      expect(result.services.map((s) => s.name), ['web-1', 'web-2']);
      expect(result.services.map((s) => s.health), ['healthy', 'none']);

      final roundtrip = ApplicationDeployment.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(roundtrip.status, 'running');
      expect(
        roundtrip.services.map((s) => '${s.name}/${s.state}/${s.health}'),
        ['web-1/running/healthy', 'web-2/running/none'],
      );
    });

    test('starting 或 unhealthy => partial', () async {
      for (final health in ['starting', 'unhealthy']) {
        final ssh = _ScriptedSsh();
        final service = ApplicationDeploymentService(ssh);
        final app = centerDeployment();
        ssh.stub('.valhalla-app-owner', app.id);
        ssh.stub('deployment.json', jsonEncode(app.toJson()));
        ssh.stub('docker ps -aq --no-trunc', 'c' * 12);
        ssh.stub('{{json .Name}}', '"/web-1"|"running"|"$health"');

        final result = (await service.reconcile(app, centerEnvironment()))!;
        expect(result.status, 'partial', reason: 'health=$health');
      }
    });

    test('全部 exited/created => stopped', () async {
      final ssh = _ScriptedSsh();
      final service = ApplicationDeploymentService(ssh);
      final app = centerDeployment();
      ssh.stub('.valhalla-app-owner', app.id);
      ssh.stub('deployment.json', jsonEncode(app.toJson()));
      ssh.stub('docker ps -aq --no-trunc', '${'c' * 12}\n${'d' * 12}');
      ssh.stub(
        '{{json .Name}}',
        '"/web"|"exited"|"none"\n"/web-2"|"created"|"none"',
      );

      expect(
        (await service.reconcile(app, centerEnvironment()))!.status,
        'stopped',
      );
    });

    test('没有容器 => missing，且不调用 docker inspect', () async {
      final ssh = _ScriptedSsh();
      final service = ApplicationDeploymentService(ssh);
      final app = centerDeployment();
      ssh.stub('.valhalla-app-owner', app.id);
      ssh.stub('deployment.json', jsonEncode(app.toJson()));
      ssh.stub('docker ps -aq --no-trunc', '');

      final result = (await service.reconcile(app, centerEnvironment()))!;
      expect(result.status, 'missing');
      expect(result.services, isEmpty);
      expect(ssh.commands.where((c) => c.contains('docker inspect')), isEmpty);
    });

    test('畸形或超量的容器 id => APP_CENTER_HEALTH_INVALID', () async {
      for (final ids in ['Z' * 64, psIds(101)]) {
        final ssh = _ScriptedSsh();
        final service = ApplicationDeploymentService(ssh);
        final app = centerDeployment();
        ssh.stub('.valhalla-app-owner', app.id);
        ssh.stub('deployment.json', jsonEncode(app.toJson()));
        ssh.stub('docker ps -aq --no-trunc', ids);

        await expectLater(
          service.reconcile(app, centerEnvironment()),
          throwsA(
            isA<ApplicationCenterException>().having(
              (e) => e.code,
              'code',
              'APP_CENTER_HEALTH_INVALID',
            ),
          ),
        );
      }
    });

    test('inspect 行数不一致或字段数异常 => APP_CENTER_HEALTH_INVALID', () async {
      final mismatched = _ScriptedSsh();
      final mismatchService = ApplicationDeploymentService(mismatched);
      final app = centerDeployment();
      mismatched.stub('.valhalla-app-owner', app.id);
      mismatched.stub('deployment.json', jsonEncode(app.toJson()));
      mismatched.stub('docker ps -aq --no-trunc', '${'c' * 12}\n${'d' * 12}');
      mismatched.stub('{{json .Name}}', '"/web-1"|"running"|"healthy"');
      await expectLater(
        mismatchService.reconcile(app, centerEnvironment()),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_HEALTH_INVALID',
          ),
        ),
      );

      final malformed = _ScriptedSsh();
      final malformedService = ApplicationDeploymentService(malformed);
      malformed.stub('.valhalla-app-owner', app.id);
      malformed.stub('deployment.json', jsonEncode(app.toJson()));
      malformed.stub('docker ps -aq --no-trunc', 'c' * 12);
      malformed.stub('{{json .Name}}', '"only"|"two"');
      await expectLater(
        malformedService.reconcile(app, centerEnvironment()),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_HEALTH_INVALID',
          ),
        ),
      );
    });

    test('deployment.json 为空 => reconcile 返回 null', () async {
      final ssh = _ScriptedSsh();
      final service = ApplicationDeploymentService(ssh);
      final app = centerDeployment();
      ssh.stub('.valhalla-app-owner', app.id);
      ssh.stub('deployment.json', '');

      expect(await service.reconcile(app, centerEnvironment()), isNull);
      expect(
        ssh.commands.any((c) => c.contains('docker ps')),
        isFalse,
        reason: '无部署元数据就不必查容器',
      );
    });

    test('所有权标记或部署元数据不匹配 => APP_CENTER_OWNERSHIP_CHANGED', () async {
      final marker = _ScriptedSsh();
      final markerService = ApplicationDeploymentService(marker);
      final app = centerDeployment();
      marker.stub('.valhalla-app-owner', 'f' * 32);
      marker.stub('deployment.json', jsonEncode(app.toJson()));
      await expectLater(
        markerService.reconcile(app, centerEnvironment()),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_OWNERSHIP_CHANGED',
          ),
        ),
      );

      final tampered = _ScriptedSsh();
      final tamperedService = ApplicationDeploymentService(tampered);
      tampered.stub('.valhalla-app-owner', app.id);
      tampered.stub(
        'deployment.json',
        jsonEncode(app.toJson()..['id'] = 'f' * 32),
      );
      await expectLater(
        tamperedService.reconcile(app, centerEnvironment()),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_OWNERSHIP_CHANGED',
          ),
        ),
      );
    });

    test('目标服务器/密钥不匹配 => APP_CENTER_TARGET_CHANGED，不执行命令', () async {
      final ssh = _ScriptedSsh();
      final service = ApplicationDeploymentService(ssh);
      final other = centerServer.copyWith(id: 'other', host: 'other.invalid');
      final app = centerDeployment(other);

      await expectLater(
        service.reconcile(app, centerEnvironment()),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_TARGET_CHANGED',
          ),
        ),
      );
      expect(ssh.commands, isEmpty);
    });
  });

  group('prepare 只读预检', () {
    Future<ApplicationDeploymentService> installService(
      _ScriptedSsh ssh,
    ) async {
      ssh.stub('cat /etc/machine-id', _hostId);
      ssh.stub('docker info --format', _daemonId);
      ssh.stub('docker ps -a --no-trunc --format', '');
      ssh.stub('ss -H', '');
      return ApplicationDeploymentService(ssh);
    }

    test(
      'new install refuses any occupied name, including stopped containers',
      () async {
        final ssh = _ScriptedSsh(client: _Client());
        final service = await installService(ssh);
        ssh.stub('docker ps -a --no-trunc --format', _nameRecord());
        await expectLater(
          service.prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.install,
            template: centerTemplate,
            configuration: _config(),
          ),
          _centerError('APP_CENTER_CONTAINER_NAME_CONFLICT'),
        );
        final inventory = ssh.commands.singleWhere(
          (value) => value.contains('docker ps -a --no-trunc --format'),
        );
        expect(inventory, isNot(contains('--filter')));
        expect(inventory, contains('json .Names'));
        expect(inventory, contains('com.docker.compose.service'));
        expect(
          ssh.commands.any(
            (value) => value.contains('mkdir') || value.contains('setsid'),
          ),
          false,
        );
      },
    );

    for (final row in [
      'not JSON',
      '[]',
      '{"name":"Fixture"}',
      '{"name":4,"instance":"","project":"","service":""}',
    ]) {
      test('malformed container inventory fails closed: $row', () async {
        final ssh = _ScriptedSsh(client: _Client());
        final service = await installService(ssh);
        ssh.stub('docker ps -a --no-trunc --format', row);
        await expectLater(
          service.prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.install,
            template: centerTemplate,
            configuration: _config(),
          ),
          _centerError('APP_CENTER_CONTAINER_NAME_CHECK_FAILED'),
        );
        expect(ssh.commands.any((value) => value.contains('mkdir')), false);
      });
    }

    for (final op in [
      ApplicationOperation.update,
      ApplicationOperation.configure,
    ]) {
      test('$op retains legacy names despite a new-mode caller', () async {
        final ssh = _updateSsh();
        final plan = await ApplicationDeploymentService(ssh).prepare(
          centerServer,
          centerEnvironment(),
          op,
          template: centerTemplate,
          configuration: _config().copyWith(instanceContainerNames: true),
          deployment: centerDeployment(),
        );
        expect(plan.configuration!.instanceContainerNames, false);
        expect(
          jsonDecode(plan.composeJson)['services']['web']['container_name'],
          isNull,
        );
        expect(
          ssh.commands.any(
            (value) => value.contains('docker ps -a --no-trunc --format'),
          ),
          false,
        );
      });

      test(
        '$op preserves saved new mode and permits its own matching container',
        () async {
          final ssh = _updateSsh(named: true);
          ssh.stub('docker ps -a --no-trunc --format', _nameRecord());
          final plan = await ApplicationDeploymentService(ssh).prepare(
            centerServer,
            centerEnvironment(),
            op,
            template: centerTemplate,
            configuration: _config(),
            deployment: centerDeployment(),
          );
          expect(plan.configuration!.instanceContainerNames, true);
          expect(plan.configuration!.mainService, 'web');
          expect(
            jsonDecode(plan.composeJson)['services']['web']['container_name'],
            'Fixture',
          );
        },
      );
    }

    for (final conflict in [
      _nameRecord(instance: 'f' * 32),
      _nameRecord(project: 'other-project'),
      _nameRecord(service: 'another-service'),
    ]) {
      test(
        'owned deployment cannot take over foreign name labels $conflict',
        () async {
          final ssh = _updateSsh(named: true);
          ssh.stub('docker ps -a --no-trunc --format', conflict);
          await expectLater(
            ApplicationDeploymentService(ssh).prepare(
              centerServer,
              centerEnvironment(),
              ApplicationOperation.configure,
              template: centerTemplate,
              configuration: _config(),
              deployment: centerDeployment(),
            ),
            _centerError('APP_CENTER_CONTAINER_NAME_CONFLICT'),
          );
        },
      );
    }

    test(
      'new-mode rename is explicit in preview while previous compose keeps original name',
      () async {
        final ssh = _updateSsh(named: true);
        ssh.stub('docker ps -a --no-trunc --format', _nameRecord());
        final plan = await ApplicationDeploymentService(ssh).prepare(
          centerServer,
          centerEnvironment(),
          ApplicationOperation.configure,
          template: centerTemplate,
          configuration: _config().copyWith(name: 'renamed-instance'),
          deployment: centerDeployment(),
        );
        expect(plan.changedSections, contains('container_name'));
        expect(plan.preview, contains('renamed-instance'));
        expect(
          jsonDecode(
            plan.previousComposeJson,
          )['services']['web']['container_name'],
          'Fixture',
        );
        expect(plan.deployment.id, centerDeployment().id);
        expect(plan.deployment.project, centerDeployment().project);
      },
    );

    test(
      'execute rechecks name inventory before writes or persistence',
      () async {
        final client = _Client();
        final ssh = _ScriptedSsh(client: client);
        final service = await installService(ssh);
        ssh.stub('df -Pk', '$_dfHeader\n$_dfRow');
        final plan = await service.prepare(
          centerServer,
          centerEnvironment(),
          ApplicationOperation.install,
          template: centerTemplate,
          configuration: _config(),
        );
        ssh.stub('docker ps -a --no-trunc --format', _nameRecord());
        var persisted = false;
        await expectLater(
          service.execute(
            plan,
            persistBeforeLaunch: (_) async => persisted = true,
          ),
          _centerError('APP_CENTER_CONTAINER_NAME_CONFLICT'),
        );
        expect(
          ssh.commands.where(
            (value) => value.contains('docker ps -a --no-trunc --format'),
          ),
          hasLength(2),
        );
        expect(persisted, false);
        expect(client.writes, isEmpty);
        expect(
          ssh.commands.any(
            (value) => value.contains('mkdir') || value.contains('setsid'),
          ),
          false,
        );
      },
    );

    test(
      'approved new install writes names and persists intent before launching',
      () async {
        final client = _Client();
        final ssh = _ScriptedSsh(client: client);
        final service = await installService(ssh);
        ssh.stub('df -Pk', '$_dfHeader\n$_dfRow');
        ssh.stub('mkdir -p', '');
        ssh.stub('setsid -f bash', '');
        final plan = await service.prepare(
          centerServer,
          centerEnvironment(),
          ApplicationOperation.install,
          template: centerTemplate,
          configuration: _config(),
        );
        var persisted = false;
        ssh.onCommand = (command) {
          if (command.contains('setsid -f bash')) expect(persisted, true);
        };
        final task = await service.execute(
          plan,
          persistBeforeLaunch: (_) async => persisted = true,
        );
        expect(task.stage, ApplicationTaskStage.queued);
        expect(persisted, true);
        expect(
          ssh.commands.where(
            (value) => value.contains('docker ps -a --no-trunc --format'),
          ),
          hasLength(2),
        );
        final compose = client.writes.entries
            .singleWhere((entry) => entry.key.contains('/compose.next.json'))
            .value;
        expect(
          jsonDecode(compose)['services']['web']['container_name'],
          'Fixture',
        );
        final config = client.writes.entries
            .singleWhere(
              (entry) => entry.key.contains('/configuration.next.json'),
            )
            .value;
        expect(jsonDecode(config)['instanceContainerNames'], true);
        expect(
          ssh.commands.where((value) => value.contains('setsid -f bash')),
          hasLength(1),
        );
      },
    );

    test('df -Pk 数据行提供可用字节，且不调用任何安装/部署写命令', () async {
      final client = _Client();
      final ssh = _ScriptedSsh(client: client);
      final service = await installService(ssh);
      ssh.stub('df -Pk', '$_dfHeader\n$_dfRow');

      final plan = await service.prepare(
        centerServer,
        centerEnvironment(),
        ApplicationOperation.install,
        template: centerTemplate,
        configuration: _config(),
      );

      expect(plan.availableBytes, 786432 * 1024);
      expect(plan.changedSections, isEmpty);
      expect(plan.preview, contains('••••••'));
      expect(
        ssh.commands.any(
          (c) =>
              c.contains('compose up') ||
              c.contains('mkdir') ||
              c.contains('worker.sh') ||
              c.contains('cat >') ||
              c.contains('docker run'),
        ),
        isFalse,
        reason: 'prepare 只做只读预检，不得发起安装/部署写命令',
      );
      expect(client.sessions, isEmpty);
    });

    test('df 可用字节为 0 => APP_CENTER_DISK_FULL', () async {
      final ssh = _ScriptedSsh(client: _Client());
      final service = await installService(ssh);
      ssh.stub(
        'df -Pk',
        '$_dfHeader\n/dev/sda1 1048576 1048576 0 100% /home/dev/data',
      );

      await expectLater(
        service.prepare(
          centerServer,
          centerEnvironment(),
          ApplicationOperation.install,
          template: centerTemplate,
          configuration: _config(),
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_DISK_FULL',
          ),
        ),
      );
    });

    test('df 输出缺失数据行或负数 => APP_CENTER_DISK_CHECK_FAILED', () async {
      for (final df in [
        _dfHeader,
        '$_dfHeader\n/dev/sda1 1048576 1048576 -1 100% /home',
      ]) {
        final ssh = _ScriptedSsh(client: _Client());
        final service = await installService(ssh);
        ssh.stub('df -Pk', df);

        await expectLater(
          service.prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.install,
            template: centerTemplate,
            configuration: _config(),
          ),
          throwsA(
            isA<ApplicationCenterException>().having(
              (e) => e.code,
              'code',
              'APP_CENTER_DISK_CHECK_FAILED',
            ),
          ),
        );
      }
    });

    for (final socket in [
      (row: 'udp UNCONN 0 0 0.0.0.0:18080 0.0.0.0:*', conflict: false),
      (row: 'tcp LISTEN 0 4096 192.0.2.2:18080 0.0.0.0:*', conflict: false),
      (row: 'tcp LISTEN 0 4096 127.0.0.1:18080 0.0.0.0:*', conflict: true),
      (row: 'tcp LISTEN 0 4096 0.0.0.0:18080 0.0.0.0:*', conflict: true),
      (row: 'tcp LISTEN 0 4096 [::]:18080 [::]:*', conflict: true),
    ]) {
      test(
        'new loopback port checks protocol and interface: ${socket.row}',
        () async {
          final ssh = _ScriptedSsh(client: _Client());
          final service = await installService(ssh);
          ssh.stub('ss -H', socket.row);
          ssh.stub('df -Pk', '$_dfHeader\n$_dfRow');
          final preparing = service.prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.install,
            template: centerTemplate,
            configuration: _config(),
          );
          if (socket.conflict) {
            await expectLater(
              preparing,
              _centerError('APP_CENTER_PORT_IN_USE'),
            );
          } else {
            expect(
              (await preparing).configuration!.ports.single.published,
              18080,
            );
          }
          expect(ssh.commands, contains('ss -H -ltun'));
        },
      );
    }

    test(
      'port override wildcard catches a foreign interface during configure',
      () async {
        final ssh = _updateSsh();
        ssh.stub(
          'ss -H',
          'tcp LISTEN 0 4096 127.0.0.1:18080 0.0.0.0:*\n'
              'tcp LISTEN 0 4096 192.0.2.2:18080 0.0.0.0:*',
        );
        await expectLater(
          ApplicationDeploymentService(ssh).prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.configure,
            deployment: centerDeployment(),
            template: centerTemplate,
            configuration: _config().copyWith(
              ports: const [
                ApplicationPort(
                  service: 'web',
                  target: 80,
                  published: 18080,
                  bindAddress: '0.0.0.0',
                ),
              ],
            ),
          ),
          _centerError('APP_CENTER_PORT_IN_USE'),
        );
      },
    );

    test(
      'running owned loopback port permits explicit wildcard expansion',
      () async {
        final ssh = _updateSsh();
        ssh.stub('ss -H', 'tcp LISTEN 0 4096 127.0.0.1:18080 0.0.0.0:*');
        final plan = await ApplicationDeploymentService(ssh).prepare(
          centerServer,
          centerEnvironment(),
          ApplicationOperation.configure,
          deployment: centerDeployment(),
          template: centerTemplate,
          configuration: _config().copyWith(bindAddress: '0.0.0.0'),
        );
        final rendered = jsonDecode(plan.composeJson) as Map;
        expect(rendered['services']['web']['ports'][0]['host_ip'], '0.0.0.0');
        expect(
          ssh.commands.any((command) => command.contains('docker compose up')),
          false,
        );
      },
    );

    test(
      'stopped container cannot claim a socket reused by another process',
      () async {
        final ssh = _updateSsh();
        ssh.stub('.NetworkSettings.Ports', _bindingRecord(state: 'exited'));
        ssh.stub('ss -H', 'tcp LISTEN 0 4096 127.0.0.1:18080 0.0.0.0:*');
        await expectLater(
          ApplicationDeploymentService(ssh).prepare(
            centerServer,
            centerEnvironment(),
            ApplicationOperation.configure,
            deployment: centerDeployment(),
            template: centerTemplate,
            configuration: _config(),
          ),
          _centerError('APP_CENTER_PORT_IN_USE'),
        );
      },
    );

    test('update 时仅 secret 值变化会标记 environment 类别，且预览不泄露密钥', () async {
      final ssh = _updateSsh();
      final service = ApplicationDeploymentService(ssh);
      final config = _config().copyWith(
        environment: {
          'web': {'TOKEN': 'new-secret'},
        },
      );

      final plan = await service.prepare(
        centerServer,
        centerEnvironment(),
        ApplicationOperation.update,
        template: centerTemplate,
        configuration: config,
        deployment: centerDeployment(),
      );

      expect(plan.changedSections, contains('image'));
      expect(
        plan.changedSections,
        contains('environment'),
        reason: '密钥换新属于 environment 变更类别',
      );
      expect(plan.preview, isNot(contains('new-secret')));
      expect(plan.preview, isNot(contains('cached-secret')));
      expect(
        ssh.commands.any(
          (c) => c.contains('compose up') || c.contains('mkdir'),
        ),
        isFalse,
        reason: 'update 预检不得发起部署写命令',
      );
    });

    test('update 时 environment 键集发生变化仍会标记 environment 类别', () async {
      final ssh = _updateSsh();
      final service = ApplicationDeploymentService(ssh);
      final config = _config().copyWith(
        environment: {
          'web': {'EXTRA_KEY': 'new-secret'},
        },
      );

      final plan = await service.prepare(
        centerServer,
        centerEnvironment(),
        ApplicationOperation.update,
        template: centerTemplate,
        configuration: config,
        deployment: centerDeployment(),
      );

      expect(plan.changedSections, contains('environment'));
    });
  });

  group('read-only access diagnostics', () {
    _ScriptedSsh fixture({String state = 'running'}) {
      final config = _config().copyWith(
        ports: const [
          ApplicationPort(
            service: 'web',
            target: 80,
            published: 81,
            bindAddress: '0.0.0.0',
          ),
          ApplicationPort(service: 'web', target: 81, published: 18081),
        ],
      );
      final template = {
        'application': centerApp.toJson(),
        'compose': {
          'services': {
            'web': {
              'image': 'nginx',
              'ports': ['81:80', '18081:81'],
            },
          },
          'x-casaos': {
            'main': 'web',
            'port_map': 81,
            'index': '/admin?next=https://other.invalid',
          },
        },
        'metadata': <String, dynamic>{},
      };
      return _ScriptedSsh(
          client: _Client(
            configurationJson: jsonEncode(config.toJson()),
            templateJson: jsonEncode(template),
          ),
        )
        ..stub('.valhalla-app-owner', centerDeployment().id)
        ..stub('cat /etc/machine-id', _hostId)
        ..stub('docker info --format', _daemonId)
        ..stub('docker ps -aq --no-trunc', 'c' * 64)
        ..stub(
          '.NetworkSettings.Ports',
          _bindingRecord(
            state: state,
            ports: {
              '80/tcp': [
                {'HostIp': '0.0.0.0', 'HostPort': '81'},
              ],
              '81/tcp': [
                {'HostIp': '127.0.0.1', 'HostPort': '18081'},
              ],
            },
          ),
        )
        ..stub('command -v curl', '200');
    }

    test(
      'actual mixed bindings select admin target and probe only loopback root',
      () async {
        final ssh = fixture();
        final started = DateTime.now();
        final info = await ApplicationDeploymentService(
          ssh,
        ).accessInfo(centerDeployment(), centerEnvironment());
        expect(
          info.ports.map((p) => '${p.target}/${p.published}/${p.bindAddress}'),
          ['80/81/0.0.0.0', '81/18081/127.0.0.1'],
        );
        expect(info.managementPort!.target, 81);
        expect(info.services.single.state, 'running');
        expect(
          info.sshEndpoint.toString(),
          'http://127.0.0.1:18081/admin?next=https://other.invalid',
        );
        expect(info.probeStatus, ApplicationAccessProbeStatus.reachable);
        expect(info.httpStatus, 200);
        expect(info.checkedAt.isBefore(started), false);
        final probeIndex = ssh.commands.indexWhere(
          (command) => command.contains('command -v curl'),
        );
        final probe = ssh.commands[probeIndex];
        expect(probe, contains("curl -q --noproxy '*'"));
        expect(probe, contains("'http://127.0.0.1:18081/'"));
        expect(probe, contains('--connect-timeout 3 --max-time 8'));
        expect(probe, isNot(contains('/admin')));
        expect(probe, isNot(contains('other.invalid')));
        expect(probe, isNot(contains('--location')));
        expect(probe, isNot(contains('--insecure')));
        expect(ssh.timeouts[probeIndex], const Duration(seconds: 12));
        for (final forbidden in [
          'docker run',
          'compose up',
          'mkdir',
          'ufw ',
          'iptables ',
          'firewall-cmd',
        ]) {
          expect(
            ssh.commands.any((command) => command.contains(forbidden)),
            false,
            reason: forbidden,
          );
        }
      },
    );

    test(
      'curl missing is unavailable, not an application access failure',
      () async {
        final ssh = fixture()..stub('command -v curl', 'unavailable');
        final info = await ApplicationDeploymentService(
          ssh,
        ).accessInfo(centerDeployment(), centerEnvironment());
        expect(info.probeStatus, ApplicationAccessProbeStatus.unavailable);
        expect(info.httpStatus, isNull);
        expect(info.probeExitCode, isNull);
        expect(info.ports, hasLength(2));
      },
    );

    test(
      'HTTP error response remains reachable; connection failure keeps diagnostics',
      () async {
        for (final response in [
          (
            text: '503',
            exitCode: 0,
            status: ApplicationAccessProbeStatus.reachable,
          ),
          (
            text: '000',
            exitCode: 7,
            status: ApplicationAccessProbeStatus.failed,
          ),
        ]) {
          final ssh = fixture()
            ..stub(
              'command -v curl',
              response.text,
              exitCode: response.exitCode,
            );
          final info = await ApplicationDeploymentService(
            ssh,
          ).accessInfo(centerDeployment(), centerEnvironment());
          expect(info.probeStatus, response.status);
          expect(info.httpStatus, response.exitCode == 0 ? 503 : null);
          expect(info.probeExitCode, response.exitCode);
          expect(info.ports, hasLength(2));
        }
      },
    );

    test(
      'stopped container ignores stale bindings and does not probe',
      () async {
        final ssh = fixture(state: 'exited');
        final info = await ApplicationDeploymentService(
          ssh,
        ).accessInfo(centerDeployment(), centerEnvironment());
        expect(info.services.single.state, 'exited');
        expect(info.ports, isEmpty);
        expect(info.managementPort, isNull);
        expect(info.probeStatus, ApplicationAccessProbeStatus.notApplicable);
        expect(ssh.commands.any((command) => command.contains('curl')), false);
      },
    );

    test('wrong target is rejected before any remote command', () async {
      final ssh = fixture();
      await expectLater(
        ApplicationDeploymentService(ssh).accessInfo(
          centerDeployment(centerServer.copyWith(id: 'other')),
          centerEnvironment(),
        ),
        _centerError('APP_CENTER_TARGET_CHANGED'),
      );
      expect(ssh.commands, isEmpty);
    });

    test(
      'unexpected inspected ownership cannot produce access links',
      () async {
        final ssh = fixture()
          ..stub('.NetworkSettings.Ports', _bindingRecord(instance: 'f' * 32));
        await expectLater(
          ApplicationDeploymentService(
            ssh,
          ).accessInfo(centerDeployment(), centerEnvironment()),
          _centerError('APP_CENTER_HEALTH_INVALID'),
        );
        expect(ssh.commands.any((command) => command.contains('curl')), false);
      },
    );

    test(
      'connection replacement during probe discards old-target result',
      () async {
        final ssh = fixture();
        ssh.onCommand = (command) {
          if (command.contains('command -v curl')) ssh.client = _Client();
        };
        await expectLater(
          ApplicationDeploymentService(
            ssh,
          ).accessInfo(centerDeployment(), centerEnvironment()),
          _centerError('APP_CENTER_TARGET_CHANGED'),
        );
      },
    );
  });
}
