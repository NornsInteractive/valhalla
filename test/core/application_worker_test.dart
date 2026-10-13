import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/data/models/application_center.dart';

void main() {
  late Directory tempDir;
  late ApplicationEnvironment env;
  late ApplicationDeployment deployment;
  late ApplicationConfiguration config;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_worker_test_');
    final id32 = 'a' * 32;
    final id32b = 'b' * 32;
    env = ApplicationEnvironment(
      serverId: 'srv',
      serverKey: 'k',
      home: '/home/user',
      os: 'debian',
      osVersion: '12',
      architecture: 'amd64',
      targetIdentity: '$id32|docker-id',
      uid: 1000,
      gid: 1000,
      dockerAvailable: true,
      composeAvailable: true,
      useSudo: false,
      canBootstrap: true,
    );
    deployment = ApplicationDeployment(
      id: id32b,
      serverKey: 'k',
      serverId: 'srv',
      sourceId: 'src',
      appId: 'app',
      name: 'Test App',
      project: 'valhalla-app-$id32b',
      directory: '${tempDir.path}/deploy',
      targetIdentity: env.targetIdentity,
    );
    config = ApplicationConfiguration(
      name: 'Test',
      dataRoot: '${tempDir.path}/data',
      ports: [ApplicationPort(service: 'svc', target: 80, published: 8080)],
      mounts: [],
      variables: {
        'PUID': '1000',
        'PGID': '1000',
        'TZ': 'UTC',
        'AppID': deployment.id,
      },
    );
  });

  tearDown(
    () => tempDir.existsSync() ? tempDir.deleteSync(recursive: true) : null,
  );

  ApplicationOperationPlan plan(
    ApplicationOperation op, {
    String prev = '',
    String tpl = '',
  }) => ApplicationOperationPlan(
    token: 't' * 32,
    operation: op,
    deployment: deployment,
    configuration:
        {
          ApplicationOperation.install,
          ApplicationOperation.configure,
          ApplicationOperation.update,
        }.contains(op)
        ? config
        : null,
    composeJson:
        {
          ApplicationOperation.install,
          ApplicationOperation.configure,
          ApplicationOperation.update,
          ApplicationOperation.start,
          ApplicationOperation.restore,
        }.contains(op)
        ? '{"services":{"svc":{"image":"nginx"}}}'
        : '',
    previousComposeJson: prev,
    templateJson: tpl,
    useSudo: false,
    createdAt: DateTime.now(),
  );

  Future<void> checkScript(String script, String label) async {
    final file = File('${tempDir.path}/$label.sh');
    await file.writeAsString(script);
    final r = await Process.run('bash', ['-n', file.path]);
    expect(r.exitCode, 0, reason: '$label syntax error: ${r.stderr}');
  }

  group('workerScript syntax & assertions', () {
    for (final op in ApplicationOperation.values) {
      test('$op generates valid bash', () async {
        final p = plan(
          op,
          prev:
              op == ApplicationOperation.restore ||
                  op == ApplicationOperation.configure
              ? '{"services":{"svc":{"image":"sha256:old"}}}'
              : '',
          tpl: '{"application":{},"compose":{},"metadata":{}}',
        );
        await checkScript(
          ApplicationDeploymentService.workerScript(
            p,
            env,
            '${tempDir.path}/task',
            '${tempDir.path}/root',
          ),
          op.name,
        );
      });
    }

    test('install/update have pull then --pull never', () async {
      for (final op in [
        ApplicationOperation.install,
        ApplicationOperation.update,
      ]) {
        final s = ApplicationDeploymentService.workerScript(
          plan(op),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        expect(s, contains('stage pulling'));
        expect(s, contains('compose.next.json\' pull'));
        expect(s, contains('--pull never'));
      }
    });

    test('configure/start never pull newer images', () async {
      for (final op in [
        ApplicationOperation.configure,
        ApplicationOperation.start,
      ]) {
        final s = ApplicationDeploymentService.workerScript(
          plan(op),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        expect(s, isNot(contains('stage pulling')));
        expect(s, isNot(contains('compose.next.json\' pull')));
        expect(s, contains('--pull never'));
      }
    });

    test('uninstall has down but no -v/remove data', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.uninstall),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('down --timeout 20'));
      expect(s, isNot(contains('down -v')));
      expect(s, isNot(contains('remove')));
    });

    test(
      'restore copies previous compose/config/template and --pull never',
      () async {
        final s = ApplicationDeploymentService.workerScript(
          plan(
            ApplicationOperation.restore,
            prev: '{"services":{"svc":{"image":"sha256:old"}}}',
          ),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        expect(s, contains('compose.previous.json'));
        expect(s, contains('configuration.previous.json'));
        expect(s, contains('template.previous.json'));
        expect(s, contains('--pull never'));
      },
    );

    for (final explicitNames in [false, true]) {
      test(
        'actual restore worker keeps saved naming mode=$explicitNames',
        () async {
          final taskDir = Directory('${tempDir.path}/task')..createSync();
          final lockRoot = Directory('${tempDir.path}/root')..createSync();
          Directory(deployment.directory).createSync();
          final previousCompose = jsonEncode({
            'name': deployment.project,
            'services': {
              'svc': {
                'image': 'sha256:previous',
                if (explicitNames) 'container_name': 'previous-instance',
              },
            },
          });
          final previousConfig = jsonEncode({
            'name': 'previous-instance',
            'dataRoot': config.dataRoot,
            if (explicitNames) 'instanceContainerNames': true,
            if (explicitNames) 'mainService': 'svc',
          });
          final saved = {
            'compose': previousCompose,
            'configuration': previousConfig,
            'deployment': jsonEncode({'name': 'previous-instance'}),
            'template': jsonEncode({'revision': 'previous'}),
          };
          for (final entry in saved.entries) {
            File(
              '${deployment.directory}/${entry.key}.previous.json',
            ).writeAsStringSync(entry.value);
            File(
              '${deployment.directory}/${entry.key}.json',
            ).writeAsStringSync('{"changed":true}');
          }
          final worker = File('${tempDir.path}/restore-runtime.sh')
            ..writeAsStringSync(
              ApplicationDeploymentService.workerScript(
                plan(ApplicationOperation.restore),
                env,
                taskDir.path,
                lockRoot.path,
              ),
            );
          final result = await Process.run(
            'bash',
            [
              '-c',
              '''
cat() {
  if test "\$1" = /etc/machine-id; then printf '%s\\n' '${'a' * 32}';
  else command cat "\$@"; fi
}
docker() {
  case "\$1" in
    info) printf '%s\\n' 'docker-id' ;;
    context) printf '%s\\n' 'unix:///var/run/docker.sock' ;;
    compose)
      command cp -- "\$APP_CENTER_FIXTURE_DEPLOY/compose.json" "\$APP_CENTER_FIXTURE_OBSERVED"
      printf '%s\\n' "\$@" >"\$APP_CENTER_FIXTURE_ARGS"
      ;;
    *) return 97 ;;
  esac
}
source "\$1"
''',
              'restore-fixture',
              worker.path,
            ],
            environment: {
              'APP_CENTER_FIXTURE_DEPLOY': deployment.directory,
              'APP_CENTER_FIXTURE_OBSERVED': '${tempDir.path}/observed.json',
              'APP_CENTER_FIXTURE_ARGS': '${tempDir.path}/docker-args',
            },
          ).timeout(const Duration(seconds: 20));
          expect(
            result.exitCode,
            0,
            reason:
                '${result.stderr}\n${File('${taskDir.path}/log').readAsStringSync()}',
          );
          expect(File('${taskDir.path}/state').readAsLinesSync(), [
            'succeeded',
            '0',
          ]);
          expect(
            File('${tempDir.path}/observed.json').readAsStringSync(),
            previousCompose,
          );
          for (final entry in saved.entries) {
            expect(
              File(
                '${deployment.directory}/${entry.key}.json',
              ).readAsStringSync(),
              entry.value,
            );
          }
          final dockerArgs = File(
            '${tempDir.path}/docker-args',
          ).readAsLinesSync();
          expect(
            dockerArgs,
            containsAllInOrder(['--project-name', deployment.project]),
          );
          expect(
            dockerArgs,
            containsAllInOrder([
              'up',
              '--detach',
              '--no-build',
              '--pull',
              'never',
            ]),
          );
          expect(dockerArgs, isNot(contains('pull')));
        },
      );
    }

    test('bounded log 262144 uses byte counter and rotation', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('bytes=0'));
      expect(s, contains('\$((bytes + \${#line} + 1))'));
      expect(s, contains('-gt 262144'));
      expect(s, contains('mv -f -- "\$task/log" "\$task/log.previous"'));
      expect(s, contains(': > "\$task/log"'));
      expect(s, contains('[oversized log line omitted]'));
    });

    test('PID/start/boot identities written', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('\$task/pid'));
      expect(s, contains('/proc/sys/kernel/random/boot_id'));
      expect(s, contains('/proc/\$\$/stat'));
    });

    test('flock and cancellation checkpoints', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('flock -w 900 9'));
      expect(s, contains('check_cancel'));
    });

    test('templateJson and template.previous.json handled', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(
          ApplicationOperation.install,
          tpl: '{"application":{},"compose":{},"metadata":{}}',
        ),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('template.next.json'));
      expect(s, contains('template.json'));
      expect(s, contains('template.previous.json'));
    });

    test('no awk usage in log processing - uses bash read', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      final writeLogFn = s.substring(
        s.indexOf('write_log()'),
        s.indexOf('run()'),
      );
      expect(writeLogFn, isNot(contains('awk')));
      expect(writeLogFn, contains('IFS= read -r -t 1 -n 65536 line'));
    });

    test('CR handling converts carriage returns to newlines', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains(r'${line//'));
    });

    test('log rotation keeps last output at 256KiB boundary', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('\$task/log.previous'));
      expect(s, contains(': > "\$task/log"'));
      expect(s, contains('bytes=0'));
    });

    test('command and exit status metadata written to current file', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('\$task/current.tmp'));
      expect(s, contains('\$task/current'));
      expect(s, contains('date +%s'));
      expect(s, contains('printf \'\\n> %s\\n\''));
      expect(s, contains('printf \'[exit %s]\\n\''));
    });

    test('finish waits for logger flush before exit', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('logger_pid=\$!'));
      expect(s, contains('wait "\$logger_pid"'));
      expect(s, contains('exec 1>&3 2>&3'));
    });

    test('output-at updated per-second with timestamp', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, contains('\$task/output-at.tmp'));
      expect(s, contains('\$task/output-at'));
      expect(s, contains('date +%s'));
      expect(s, contains('SECONDS'));
    });

    test('no stop-first 256KiB truncation - uses bounded rotation', () async {
      final s = ApplicationDeploymentService.workerScript(
        plan(ApplicationOperation.install),
        env,
        '${tempDir.path}/task',
        '${tempDir.path}/root',
      );
      expect(s, isNot(contains('[log truncated at 256 KiB]')));
      expect(s, isNot(contains('remaining=262144')));
      expect(s, contains('[oversized log line omitted]'));
    });
  });

  group('workerScript check_target assertions', () {
    test(
      'check_target called after flock (first position) and before action (second position)',
      () async {
        final s = ApplicationDeploymentService.workerScript(
          plan(ApplicationOperation.install),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        final flockIndex = s.indexOf('flock -w 900 9');
        final firstCheckTarget = s.indexOf('check_target', flockIndex);
        final preparingIndex = s.indexOf('stage preparing', flockIndex);
        final actionCheckTarget = s.indexOf('check_target', preparingIndex);
        expect(flockIndex, greaterThan(-1));
        expect(firstCheckTarget, greaterThan(flockIndex));
        expect(firstCheckTarget, lessThan(preparingIndex));
        expect(actionCheckTarget, greaterThan(preparingIndex));
      },
    );

    test(
      'check_target function verifies machine-id and docker ID (daemon)',
      () async {
        final s = ApplicationDeploymentService.workerScript(
          plan(ApplicationOperation.install),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        final checkTargetFn = s.substring(
          s.indexOf('check_target()'),
          s.indexOf('finish()'),
        );
        final machineId = env.targetIdentity.split('|').first;
        final dockerId = env.targetIdentity.split('|').last;
        expect(checkTargetFn, contains('cat /etc/machine-id'));
        expect(checkTargetFn, contains(machineId));
        expect(checkTargetFn, contains('docker info --format'));
        expect(checkTargetFn, contains(dockerId));
        expect(checkTargetFn, contains('docker context inspect'));
      },
    );

    test(
      'check_target called inside action before compose up (second position)',
      () async {
        final s = ApplicationDeploymentService.workerScript(
          plan(ApplicationOperation.install),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        final actionStart = s.indexOf('stage pulling');
        final actionCheckTarget = s.indexOf('check_target', actionStart);
        final composeUp = s.indexOf('up --detach', actionStart);
        expect(actionStart, greaterThan(-1));
        expect(actionCheckTarget, greaterThan(actionStart));
        expect(actionCheckTarget, lessThan(composeUp));
      },
    );

    test(
      'bootstrap check_target only verifies machine-id (no docker)',
      () async {
        final s = ApplicationDeploymentService.workerScript(
          plan(ApplicationOperation.bootstrap),
          env,
          '${tempDir.path}/task',
          '${tempDir.path}/root',
        );
        final checkTargetFn = s.substring(
          s.indexOf('check_target()'),
          s.indexOf('finish()'),
        );
        final machineId = env.targetIdentity.split('|').first;
        expect(checkTargetFn, contains('cat /etc/machine-id'));
        expect(checkTargetFn, contains(machineId));
        expect(checkTargetFn, isNot(contains('docker info')));
        expect(checkTargetFn, isNot(contains('docker context')));
      },
    );
  });

  group('bootstrapScript', () {
    test(
      'generates valid bash for Debian 12',
      () async => checkScript(
        ApplicationDeploymentService.bootstrapScript(env),
        'bootstrap',
      ),
    );

    test('contains Docker repo setup and install (docker available)', () async {
      final s = ApplicationDeploymentService.bootstrapScript(env);
      expect(s, contains('download.docker.com'));
      expect(s, contains('apt-get install'));
      expect(s, contains('docker-compose-plugin'));
    });

    test('contains Docker engine install when docker unavailable', () async {
      final envNoDocker = ApplicationEnvironment(
        serverId: 'srv',
        serverKey: 'k',
        home: '/home/user',
        os: 'debian',
        osVersion: '12',
        architecture: 'amd64',
        targetIdentity: 'a' * 32 + '|docker-id',
        uid: 1000,
        gid: 1000,
        dockerAvailable: false,
        composeAvailable: false,
        useSudo: true,
        canBootstrap: true,
      );
      final s = ApplicationDeploymentService.bootstrapScript(envNoDocker);
      expect(s, contains('docker-ce'));
      expect(s, contains('docker-ce-cli'));
      expect(s, contains('containerd.io'));
      expect(s, contains('docker-buildx-plugin'));
      expect(s, contains('docker-compose-plugin'));
      expect(s, contains('systemctl enable --now docker'));
    });

    test(
      'bootstrap dockerAvailable=true generates valid bash',
      () async => checkScript(
        ApplicationDeploymentService.bootstrapScript(env),
        'bootstrap_docker_available',
      ),
    );

    test('bootstrap dockerAvailable=false generates valid bash', () async {
      final envNoDocker = ApplicationEnvironment(
        serverId: 'srv',
        serverKey: 'k',
        home: '/home/user',
        os: 'debian',
        osVersion: '12',
        architecture: 'amd64',
        targetIdentity: 'a' * 32 + '|docker-id',
        uid: 1000,
        gid: 1000,
        dockerAvailable: false,
        composeAvailable: false,
        useSudo: true,
        canBootstrap: true,
      );
      await checkScript(
        ApplicationDeploymentService.bootstrapScript(envNoDocker),
        'bootstrap_docker_unavailable',
      );
    });
  });
}
