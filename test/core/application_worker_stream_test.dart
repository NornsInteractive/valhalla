import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/data/models/application_center.dart';

void main() {
  late Directory temp;
  late Directory task;
  late ApplicationEnvironment environment;
  late ApplicationOperationPlan plan;
  late String fakeDocker;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('valhalla-worker-stream-');
    task = await Directory('${temp.path}/task').create();
    await Directory('${temp.path}/root').create();
    await Directory('${temp.path}/bin').create();
    await File('${task.path}/log').writeAsString('');
    await File('${task.path}/state').writeAsString('');
    final uid = int.parse('${(await Process.run('id', ['-u'])).stdout}'.trim());
    final gid = int.parse('${(await Process.run('id', ['-g'])).stdout}'.trim());
    // The container need not expose a machine-id; keep target checks isolated.
    final machineReader = File('${temp.path}/bin/cat');
    await machineReader.writeAsString('''#!/bin/bash
if test "\$#" = 1 && test "\$1" = /etc/machine-id; then
  printf 'fixture-machine\\n'
else
  exec /bin/cat "\$@"
fi
''');
    expect(
      (await Process.run('chmod', ['700', machineReader.path])).exitCode,
      0,
    );
    environment = ApplicationEnvironment(
      serverId: 'fixture',
      serverKey: 'fixture',
      home: temp.path,
      os: 'debian',
      osVersion: '12',
      architecture: 'amd64',
      targetIdentity: 'fixture-machine|fixture-daemon',
      uid: uid,
      gid: gid,
      dockerAvailable: true,
      composeAvailable: true,
    );
    plan = ApplicationOperationPlan(
      token: 'fixture',
      operation: ApplicationOperation.stop,
      deployment: ApplicationDeployment(
        id: 'a' * 32,
        serverKey: 'fixture',
        serverId: 'fixture',
        sourceId: 'fixture',
        appId: 'fixture',
        name: 'Fixture',
        project: 'fixture-only',
        directory: '${temp.path}/application',
        targetIdentity: environment.targetIdentity,
      ),
      createdAt: DateTime.now(),
    );
    fakeDocker = '${temp.path}/bin/docker';
  });
  tearDown(() => temp.delete(recursive: true));

  Future<(Process, Future<String>)> launch(
    String output, {
    bool cancel = false,
  }) async {
    await File(fakeDocker).writeAsString('''#!/bin/bash
set -e
if test "\$1" = info; then printf 'fixture-daemon\\n'; exit 0; fi
if test "\$1" = context; then printf 'unix:///fixture.sock\\n'; exit 0; fi
if test "\$1" != compose; then exit 91; fi
$output
''');
    expect((await Process.run('chmod', ['700', fakeDocker])).exitCode, 0);
    if (cancel) await File('${task.path}/cancel').writeAsString('requested');
    final script = File('${temp.path}/worker.sh');
    await script.writeAsString(
      ApplicationDeploymentService.workerScript(
        plan,
        environment,
        task.path,
        '${temp.path}/root',
      ),
    );
    final process = await Process.start(
      'bash',
      [script.path],
      environment: {
        'PATH': '${temp.path}/bin:${Platform.environment['PATH']}',
        'VALHALLA_FIXTURE_GATE': '${temp.path}/gate',
      },
    );
    final errors = process.stderr.transform(utf8.decoder).join();
    unawaited(process.stdout.drain<void>());
    addTearDown(() {
      process.kill();
    });
    return (process, errors);
  }

  Future<String> waitForLog(String value) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      final text = await File('${task.path}/log').readAsString();
      if (text.contains(value)) return text;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('Worker did not emit $value while command remained active');
  }

  test(
    'running command emits now, final partial output drains before success',
    () async {
      final (process, errors) = await launch(r'''
printf 'FIRST\n'
while ! test -f "$VALHALLA_FIXTURE_GATE"; do sleep .05; done
printf 'progress\rLAST_WITHOUT_NEWLINE'
''');
      var exited = false;
      unawaited(
        process.exitCode.then((_) {
          exited = true;
        }),
      );
      final text = await waitForLog('FIRST');
      expect(exited, false);
      expect(text, contains('> docker compose'));
      expect(
        await File('${task.path}/state').readAsString(),
        startsWith('applying'),
      );
      expect(
        await File('${task.path}/current').readAsString(),
        contains('stop --timeout 20'),
      );
      await File('${temp.path}/gate').writeAsString('release');
      expect(
        await process.exitCode.timeout(const Duration(seconds: 10)),
        0,
        reason: await errors,
      );
      final finalLog = await File('${task.path}/log').readAsString();
      expect(finalLog, contains('progress\nLAST_WITHOUT_NEWLINE'));
      expect(finalLog, contains('[exit 0]'));
      expect(await File('${task.path}/state').readAsString(), 'succeeded\n0\n');
      expect(
        int.parse((await File('${task.path}/output-at').readAsString()).trim()),
        greaterThan(0),
      );
    },
  );

  test('failure retains final stderr and actual command exit status', () async {
    final (process, errors) = await launch("printf 'FAILURE_LAST' >&2; exit 7");
    expect(
      await process.exitCode.timeout(const Duration(seconds: 10)),
      7,
      reason: await errors,
    );
    expect(
      await File('${task.path}/log').readAsString(),
      contains('FAILURE_LAST'),
    );
    expect(await File('${task.path}/log').readAsString(), contains('[exit 7]'));
    expect(await File('${task.path}/state').readAsString(), 'failed\n7\n');
  });

  test('partial progress flushes before command finishes', () async {
    final (process, errors) = await launch(r'''
printf 'DOWNLOADING_WITHOUT_NEWLINE'
while ! test -f "$VALHALLA_FIXTURE_GATE"; do sleep .05; done
printf '\nFINISHED\n'
''');
    var exited = false;
    unawaited(
      process.exitCode.then((_) {
        exited = true;
      }),
    );
    await waitForLog('DOWNLOADING_WITHOUT_NEWLINE');
    expect(exited, false);
    await File('${temp.path}/gate').writeAsString('release');
    expect(
      await process.exitCode.timeout(const Duration(seconds: 10)),
      0,
      reason: await errors,
    );
    expect(await File('${task.path}/log').readAsString(), contains('FINISHED'));
  });

  test('oversized line is bounded without losing following output', () async {
    final (process, errors) = await launch(r'''
printf '%080000d\n' 1
printf 'AFTER_OVERSIZED_LINE\n'
''');
    expect(
      await process.exitCode.timeout(const Duration(seconds: 10)),
      0,
      reason: await errors,
    );
    final log = await File('${task.path}/log').readAsString();
    expect(log, contains('[oversized log line omitted]'));
    expect(log, contains('AFTER_OVERSIZED_LINE'));
    expect(log.length, lessThan(4096));
  });

  test(
    'rotation remains bounded and retains newest output after 512KiB',
    () async {
      final (process, errors) = await launch(r'''
for ((i=0; i<10000; i++)); do printf '%060d-%d\n' "$i" "$i"; done
printf 'NEWEST_MARKER\n'
''');
      expect(
        await process.exitCode.timeout(const Duration(seconds: 25)),
        0,
        reason: await errors,
      );
      final log = File('${task.path}/log');
      final previous = File('${task.path}/log.previous');
      expect(await log.length(), lessThanOrEqualTo(262144));
      expect(await previous.length(), lessThanOrEqualTo(262144));
      expect(await log.readAsString(), contains('NEWEST_MARKER'));
      expect(await File('${task.path}/state').readAsString(), 'succeeded\n0\n');
    },
  );

  test(
    'cancellation records terminal state without executing docker operation',
    () async {
      final (process, errors) = await launch(
        "printf 'MUST_NOT_RUN\\n'",
        cancel: true,
      );
      expect(
        await process.exitCode.timeout(const Duration(seconds: 10)),
        130,
        reason: await errors,
      );
      expect(
        await File('${task.path}/log').readAsString(),
        isNot(contains('MUST_NOT_RUN')),
      );
      expect(
        await File('${task.path}/state').readAsString(),
        'cancelled\n130\n',
      );
    },
  );

  test(
    'selected uninstall failed down never invokes cleanup or removes metadata',
    () async {
      final deploymentDir = Directory(plan.deployment.directory);
      await deploymentDir.create();
      final deploymentJson = File('${deploymentDir.path}/deployment.json');
      final deploymentContents = jsonEncode({
        'id': plan.deployment.id,
        'serverKey': plan.deployment.serverKey,
        'serverId': plan.deployment.serverId,
        'sourceId': plan.deployment.sourceId,
        'appId': plan.deployment.appId,
        'name': plan.deployment.name,
        'project': plan.deployment.project,
        'directory': plan.deployment.directory,
        'targetIdentity': plan.deployment.targetIdentity,
      });
      await deploymentJson.writeAsString(deploymentContents);
      final sentinel = File('${temp.path}/sentinel-sibling');
      const sentinelContents = 'sentinel-contents\n';
      await sentinel.writeAsString(sentinelContents);
      final invocations = File('${temp.path}/cleanup-invocations');
      await File('${task.path}/cleanup-request.json').writeAsString('{}');
      await File('${task.path}/cleanup.py').writeAsString('''
import sys
assert sys.argv[1] in ('validate', 'cleanup')
with open(${jsonEncode(invocations.path)}, 'a') as handle:
    handle.write(sys.argv[1] + '\\n')
''');
      plan = ApplicationOperationPlan(
        token: plan.token,
        operation: ApplicationOperation.uninstall,
        deployment: plan.deployment,
        createdAt: plan.createdAt,
        cleanupPlan: ApplicationCleanupPlan(
          requestJson: '{}',
          targets: const [],
        ),
      );
      final (process, errors) = await launch(r'''
printf 'DOWN_ATTEMPT\n'
exit 7
''');
      expect(
        await process.exitCode.timeout(const Duration(seconds: 10)),
        7,
        reason: await errors,
      );
      expect(
        await File('${task.path}/current').readAsString(),
        contains('down --timeout 20'),
      );
      expect(await File('${task.path}/state').readAsString(), 'failed\n7\n');
      expect(invocations.existsSync(), isTrue);
      expect(
        invocations
            .readAsStringSync()
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toList(),
        ['validate'],
      );
      expect(
        await File('${task.path}/log').readAsString(),
        contains('DOWN_ATTEMPT'),
      );
      expect(await deploymentJson.readAsString(), deploymentContents);
      expect(await sentinel.readAsString(), sentinelContents);
      expect(await File('${task.path}/uninstall-complete').exists(), isFalse);
    },
  );

  test(
    'cleanup-only retry validates and cleans without running compose down',
    () async {
      final deploymentDir = Directory(plan.deployment.directory);
      await deploymentDir.create();
      final uninstalledJson = File(
        '${deploymentDir.path}/deployment.uninstalled.json',
      );
      final uninstalledContents = jsonEncode({
        'id': plan.deployment.id,
        'serverKey': plan.deployment.serverKey,
        'serverId': plan.deployment.serverId,
        'sourceId': plan.deployment.sourceId,
        'appId': plan.deployment.appId,
        'name': plan.deployment.name,
        'project': plan.deployment.project,
        'directory': plan.deployment.directory,
        'targetIdentity': plan.deployment.targetIdentity,
      });
      await uninstalledJson.writeAsString(uninstalledContents);
      final sentinel = File('${deploymentDir.path}/sibling-sentinel');
      const sentinelContents = 'sentinel-contents\n';
      await sentinel.writeAsString(sentinelContents);
      final invocations = File('${temp.path}/cleanup-invocations');
      await File('${task.path}/cleanup-request.json').writeAsString('{}');
      await File('${task.path}/cleanup.py').writeAsString('''
import os
import sys

assert sys.argv[1] in ('validate', 'cleanup')
if sys.argv[1] == 'cleanup':
    assert os.path.exists(
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)), 'uninstall-complete'
        )
    )
with open(${jsonEncode(invocations.path)}, 'a') as handle:
    handle.write(sys.argv[1] + '\\n')
''');
      plan = ApplicationOperationPlan(
        token: plan.token,
        operation: ApplicationOperation.uninstall,
        deployment: plan.deployment,
        createdAt: plan.createdAt,
        cleanupPlan: ApplicationCleanupPlan(
          requestJson: '{}',
          targets: const [],
          cleanupOnly: true,
        ),
      );
      final (process, errors) = await launch(r'''
printf 'UNEXPECTED_COMPOSE\n'
exit 93
''');
      expect(
        await process.exitCode.timeout(const Duration(seconds: 10)),
        0,
        reason: await errors,
      );
      expect(await File('${task.path}/state').readAsString(), 'succeeded\n0\n');
      expect(
        invocations
            .readAsStringSync()
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toList(),
        ['validate', 'cleanup'],
      );
      expect(await File('${task.path}/uninstall-complete').readAsString(), '1');
      expect(
        File('${deploymentDir.path}/deployment.json').existsSync(),
        isFalse,
      );
      expect(await uninstalledJson.readAsString(), uninstalledContents);
      expect(await sentinel.readAsString(), sentinelContents);
      expect(
        await File('${task.path}/log').readAsString(),
        isNot(contains('UNEXPECTED_COMPOSE')),
      );
    },
  );
}
