import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

import '../support/application_center_fakes.dart';

class _TaskReader extends Fake implements SshCommandExecutor {
  String host = 'a' * 32;
  String output = '';
  int hostExit = 0, taskExit = 0;
  final commands = <String>[];
  final serverIds = <String>[];

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    serverIds.add(serverId);
    expect(sudoPassword, isNull);
    if (command == 'cat /etc/machine-id') {
      return SSHExecutionResult(exitCode: hostExit, stdout: host, stderr: '');
    }
    if (!command.contains('---VALHALLA-LOG---')) {
      throw StateError('Unexpected non-read command');
    }
    return SSHExecutionResult(exitCode: taskExit, stdout: output, stderr: '');
  }
}

String _response({
  String state = 'pulling',
  String code = '',
  String? live = 'active',
  bool metadata = true,
  String started = '1791763200',
  String command = 'docker compose pull',
  String lastOutput = '1791763201',
  String log = 'Layer download progressing\n',
  Map<String, dynamic>? cleanup,
}) =>
    '$state\n$code\n'
    '${live == null ? '' : '\n---VALHALLA-LIVE---\n$live\n'}'
    '${metadata ? '\n---VALHALLA-META---\n$started\n$command\n\n---VALHALLA-OUTPUT---\n$lastOutput\n' : ''}'
    '${cleanup == null ? '' : '\n---VALHALLA-CLEANUP---\n${jsonEncode(cleanup)}'}'
    '\n---VALHALLA-LOG---\n$log';

void main() {
  late _TaskReader ssh;
  late ApplicationDeploymentService service;
  late ApplicationTask task;
  setUp(() {
    ssh = _TaskReader();
    service = ApplicationDeploymentService(ssh);
    task = centerTask(centerDeployment());
  });

  Matcher centerError(String code) => throwsA(
    isA<ApplicationCenterException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );

  test(
    'new protocol reads metadata and output while clearing prior sync error',
    () async {
      ssh.output = _response();
      final before = DateTime.now();
      final current = await service.readTask(
        task.copyWith(syncError: 'offline'),
      );
      expect(current.id, task.id);
      expect(current.stage, ApplicationTaskStage.pulling);
      expect(current.isBusy, isTrue);
      expect(current.currentCommand, 'docker compose pull');
      expect(
        current.commandStartedAt,
        DateTime.fromMillisecondsSinceEpoch(1791763200000, isUtc: true),
      );
      expect(
        current.lastOutputAt,
        DateTime.fromMillisecondsSinceEpoch(1791763201000, isUtc: true),
      );
      expect(current.lastSyncedAt!.isBefore(before), isFalse);
      expect(current.syncError, isNull);
      expect(current.logTail, 'Layer download progressing\n');
      expect(ssh.commands.length, 2);
      expect(ssh.serverIds, [task.serverId, task.serverId]);
    },
  );

  test(
    'legacy response without command metadata still reads stage and log',
    () async {
      ssh.output = _response(metadata: false, log: 'Legacy task output');
      final current = await service.readTask(task);
      expect(current.stage, ApplicationTaskStage.pulling);
      expect(current.currentCommand, isEmpty);
      expect(current.commandStartedAt, isNull);
      expect(current.lastOutputAt, isNull);
      expect(current.logTail, 'Legacy task output');
    },
  );

  test(
    'busy task with inactive identity fails with explicit worker exit marker',
    () async {
      ssh.output = _response(live: 'inactive');
      final current = await service.readTask(task);
      expect(current.stage, ApplicationTaskStage.failed);
      expect(current.exitCode, 125);
      expect(current.logTail, 'Layer download progressing\n');
    },
  );

  for (final live in <String?>['unknown', null]) {
    test(
      'busy task with $live liveness needs inspection rather than false failure',
      () async {
        ssh.output = _response(live: live);
        final current = await service.readTask(task);
        expect(current.stage, ApplicationTaskStage.needsInspection);
        expect(current.exitCode, isNull);
        expect(current.logTail, 'Layer download progressing\n');
      },
    );
  }

  for (final terminal in [
    ('succeeded', '0', ApplicationTaskStage.succeeded),
    ('failed', '42', ApplicationTaskStage.failed),
    ('cancelled', '130', ApplicationTaskStage.cancelled),
  ]) {
    test(
      '${terminal.$1} remains terminal when worker already exited',
      () async {
        ssh.output = _response(
          state: terminal.$1,
          code: terminal.$2,
          live: 'inactive',
        );
        final current = await service.readTask(task);
        expect(current.stage, terminal.$3);
        expect(current.exitCode, int.parse(terminal.$2));
      },
    );
  }

  test(
    'liveness is checked before reading state so completed worker is not marked failed',
    () async {
      ssh.output = _response(state: 'succeeded', code: '0', live: 'inactive');
      final current = await service.readTask(task);
      final script = ssh.commands.last;
      final liveCheck = script.indexOf('live=unknown');
      final stateRead = script.indexOf('head -c 512 --');
      expect(liveCheck, greaterThanOrEqualTo(0));
      expect(script.indexOf('live=active;'), lessThan(stateRead));
      expect(liveCheck, lessThan(stateRead));
      expect(current.stage, ApplicationTaskStage.succeeded);
      expect(current.exitCode, 0);
    },
  );

  test(
    'command and log are sanitized including credential URLs and private keys',
    () async {
      ssh.output = _response(
        command: 'docker --password=command-secret --token token-secret pull',
        log:
            'password=log-secret\n'
            'https://dev:url-secret@registry.invalid\n'
            'Authorization: Bearer header-secret\n'
            '-----BEGIN PRIVATE KEY-----\nprivate-key-secret\n-----END PRIVATE KEY-----\n',
      );
      final current = await service.readTask(task);
      for (final secret in [
        'command-secret',
        'token-secret',
        'log-secret',
        'url-secret',
        'header-secret',
        'private-key-secret',
      ]) {
        expect(
          '${current.currentCommand}\n${current.logTail}',
          isNot(contains(secret)),
        );
      }
      expect(current.currentCommand, contains('******'));
      expect(current.logTail, contains('[REDACTED_PRIVATE_KEY]'));
      expect(current.logTail, contains('registry.invalid'));
    },
  );

  test('log protocol-looking delimiters remain plain log text', () async {
    const log =
        'first\n---VALHALLA-LOG---\nsecond\n---VALHALLA-META---\nnot metadata';
    ssh.output = _response(log: log);
    final current = await service.readTask(task);
    expect(current.logTail, log);
    expect(current.currentCommand, 'docker compose pull');
  });

  for (final invalid in [
    '',
    'not-a-number',
    '-1',
    '8640000000001',
    '999999999999999999999999999999',
  ]) {
    test('invalid timestamp "$invalid" is ignored without throwing', () async {
      ssh.output = _response(started: invalid, lastOutput: invalid);
      final current = await service.readTask(task);
      expect(current.commandStartedAt, isNull);
      expect(current.lastOutputAt, isNull);
      expect(current.stage, ApplicationTaskStage.pulling);
      expect(current.logTail, 'Layer download progressing\n');
    });
  }

  test('maximum supported timestamp is accepted without overflow', () async {
    ssh.output = _response(
      started: '8640000000000',
      lastOutput: '8640000000000',
    );
    final current = await service.readTask(task);
    expect(current.commandStartedAt!.millisecondsSinceEpoch, 8640000000000000);
    expect(current.lastOutputAt, current.commandStartedAt);
  });

  test(
    'invalid state or truncated state is unresolved instead of manufactured success',
    () async {
      for (final state in ['', 'unexpected-stage']) {
        ssh.output = _response(state: state);
        expect(
          (await service.readTask(task)).stage,
          ApplicationTaskStage.needsInspection,
        );
      }
    },
  );

  test(
    'invalid IDs and mismatched task suffixes perform no SSH calls',
    () async {
      for (final change in [
        {'id': '../../etc/passwd'},
        {'id': 'not-hex'},
        {'id': 'A' * 32},
        {'directory': '/home/dev/tasks/other-id'},
      ]) {
        final invalid = ApplicationTask.fromJson({...task.toJson(), ...change});
        await expectLater(
          service.readTask(invalid),
          centerError('APP_CENTER_TASK_INVALID'),
        );
      }
      expect(ssh.commands, isEmpty);
    },
  );

  test(
    'relative, traversing and control-character directories perform no SSH calls',
    () async {
      for (final prefix in [
        'relative',
        '/home/dev/..',
        '/home//dev',
        '/home/\ndev',
      ]) {
        final invalid = ApplicationTask.fromJson({
          ...task.toJson(),
          'directory': '$prefix/tasks/${task.id}',
        });
        await expectLater(
          service.readTask(invalid),
          centerError('APP_CENTER_PATH_INVALID'),
        );
      }
      expect(ssh.commands, isEmpty);
    },
  );

  test('mismatched or missing host identity never reads task files', () async {
    ssh.host = 'd' * 32;
    await expectLater(
      service.readTask(task),
      centerError('APP_CENTER_TARGET_CHANGED'),
    );
    expect(ssh.commands, ['cat /etc/machine-id']);
    ssh.commands.clear();
    ssh.host = 'a' * 32;
    final missing = ApplicationTask.fromJson({
      ...task.toJson(),
      'targetIdentity': '',
    });
    await expectLater(
      service.readTask(missing),
      centerError('APP_CENTER_TARGET_CHANGED'),
    );
    expect(ssh.commands, ['cat /etc/machine-id']);
  });

  test('host inspection failure never proceeds to task file reads', () async {
    ssh.hostExit = 1;
    await expectLater(
      service.readTask(task),
      centerError('APP_CENTER_REMOTE_FAILED'),
    );
    expect(ssh.commands, ['cat /etc/machine-id']);
  });

  test(
    'read failure is surfaced instead of replacing retained task information',
    () async {
      ssh.taskExit = 1;
      await expectLater(
        service.readTask(task),
        centerError('APP_CENTER_TASK_UNAVAILABLE'),
      );
      expect(ssh.commands.length, 2);
    },
  );

  test(
    'all task data and rotated log files have symlink guards before file reads',
    () async {
      ssh.output = _response();
      await service.readTask(task);
      final script = ssh.commands.last;
      expect(
        script,
        startsWith(
          'test "\$(realpath -- ${cliShellQuote(task.directory)})" = ${cliShellQuote(task.directory)}',
        ),
      );
      final firstRead = script.indexOf('head -c 512 --');
      for (final name in [
        'state',
        'log',
        'log.previous',
        'current',
        'output-at',
        'identity',
      ]) {
        final guard = 'test ! -L ${cliShellQuote('${task.directory}/$name')}';
        expect(script, contains(guard));
        expect(script.indexOf(guard), lessThan(firstRead));
      }
      expect(script, contains('head -c 8192 --'));
      expect(script, contains('head -c 32 --'));
      expect(script, contains('tail -c 65536 --'));
      expect(script, contains('} | tail -c 65536;'));
      expect(script, isNot(contains('sudo ')));
      expect(script, isNot(contains('mkdir ')));
    },
  );

  ApplicationTask selectedTask() => ApplicationTask.fromJson({
    ...task.toJson(),
    'operation': 'uninstall',
    'cleanupResults': [
      {'key': 'A', 'source': '/fixture/data', 'outcome': 'pending'},
    ],
  });

  Map<String, dynamic> target(String outcome) => {
    'key': 'A',
    'source': '/fixture/data',
    'outcome': outcome,
  };

  final invalidCleanupTerminal = <String, Map<String, dynamic>?>{
    'missing cleanup block': null,
    'completed without results': {'uninstallCompleted': true},
    'completed with empty results': {'uninstallCompleted': true, 'results': []},
    'completed with pending target': {
      'uninstallCompleted': true,
      'results': [target('pending')],
    },
    'completed with retained target': {
      'uninstallCompleted': true,
      'results': [target('retained')],
    },
    'completed with failed target': {
      'uninstallCompleted': true,
      'results': [target('failed')],
    },
    'incomplete with removed target': {
      'uninstallCompleted': false,
      'results': [target('removed')],
    },
  };

  for (final entry in invalidCleanupTerminal.entries) {
    test('succeeded uninstall rejects cleanup ${entry.key}', () async {
      ssh.output = _response(
        state: 'succeeded',
        code: '0',
        live: 'inactive',
        cleanup: entry.value,
      );
      await expectLater(
        service.readTask(selectedTask()),
        centerError('APP_CENTER_CLEANUP_RESULT_INVALID'),
      );
    });
  }

  for (final outcome in ['removed', 'alreadyAbsent']) {
    test('succeeded uninstall accepts cleanup $outcome target', () async {
      ssh.output = _response(
        state: 'succeeded',
        code: '0',
        live: 'inactive',
        cleanup: {
          'uninstallCompleted': true,
          'results': [target(outcome)],
        },
      );
      final current = await service.readTask(selectedTask());
      expect(current.stage, ApplicationTaskStage.succeeded);
      expect(current.exitCode, 0);
      expect(current.uninstallCompleted, isTrue);
      expect(current.cleanupResults, hasLength(1));
      expect(current.cleanupResults.single.key, 'A');
      expect(current.cleanupResults.single.source, '/fixture/data');
      expect(current.cleanupResults.single.outcome.name, outcome);
    });
  }

  test('busy uninstall marker keeps pending cleanup target', () async {
    ssh.output = _response(
      state: 'applying',
      live: 'active',
      cleanup: {'uninstallCompleted': true, 'results': []},
    );
    final current = await service.readTask(selectedTask());
    expect(current.stage, ApplicationTaskStage.applying);
    expect(current.uninstallCompleted, isTrue);
    expect(current.cleanupResults, hasLength(1));
    expect(current.cleanupResults.single.key, 'A');
    expect(current.cleanupResults.single.source, '/fixture/data');
    expect(
      current.cleanupResults.single.outcome,
      ApplicationCleanupOutcome.pending,
    );
  });
}
