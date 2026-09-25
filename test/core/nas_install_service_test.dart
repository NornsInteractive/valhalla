import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_install_service.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Executor extends Fake implements SshCommandExecutor {
  final commands = <String>[];
  final files = <String, String>{};
  String machineId = 'host-one';
  String failureText = 'fixture error';
  bool dockerAvailable = true,
      occupied = false,
      failStart = false,
      started = false;
  bool changedOwnership = false;
  bool inspectMissing = false,
      reconciliationFilesRemain = false,
      reconciliationProbeFails = false,
      reconciliationBusy = false,
      namedContainerExists = false;
  String? stallCommand;
  Completer<SSHSession>? pendingWrite;
  final writeOpened = Completer<void>();
  bool streamCancelled = false, omitExitStatus = false;
  List<String> pullOutput = [];
  int embyHealthStatus = 200;
  Completer<void>? embyHealthRequested;
  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) {
    late StreamController<SSHExecutionChunk> controller;
    controller = StreamController<SSHExecutionChunk>(
      onListen: () async {
        if (stallCommand != null && command.contains(stallCommand!)) {
          commands.add(command);
          return;
        }
        final result = await executeWithLoginShell(
          serverId,
          command,
          timeout: timeout,
        );
        controller.add(
          SSHExecutionChunk(kind: SSHStreamKind.stdout, text: result.stdout),
        );
        controller.add(
          SSHExecutionChunk(kind: SSHStreamKind.stderr, text: result.stderr),
        );
        if (command.endsWith(' pull')) {
          for (final text in pullOutput) {
            controller.add(
              SSHExecutionChunk(kind: SSHStreamKind.stdout, text: text),
            );
          }
        }
        if (!omitExitStatus) {
          controller.add(
            SSHExecutionChunk(
              kind: SSHStreamKind.stdout,
              text: '',
              exitCode: result.exitCode,
            ),
          );
        }
        await controller.close();
      },
      onCancel: () {
        streamCancelled = true;
      },
    );
    return controller.stream;
  }

  @override
  bool isConnected(String serverId) => serverId == 'ssh-one';
  late SSHClient client = _Client(this);
  @override
  SSHClient? getClient(String serverId) => client;
  Map<String, dynamic> get compose =>
      (jsonDecode(
                files.entries
                    .firstWhere((entry) => entry.key.contains('compose.json'))
                    .value,
              )
              as Map)['services']['nas']
          as Map<String, dynamic>;
  String get installId =>
      (compose['labels'] as Map)['com.valhalla.nas.install'] as String;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    String output = '';
    var code = 0;
    if (command == 'uname -s') {
      output = 'Linux';
    } else if (command == 'uname -m') {
      output = 'x86_64';
    } else if (command.startsWith('docker info')) {
      output = 'daemon-one';
      code = dockerAvailable ? 0 : 127;
    } else if (command == 'cat /etc/machine-id') {
      output = machineId;
    } else if (command == 'id -u' || command == 'id -g') {
      output = '1000';
    } else if (command.contains('docker context inspect')) {
      output = 'unix:///var/run/docker.sock';
    } else if (command.startsWith('test -d')) {
      output = command.contains("'/media'") ? '/media' : '/srv';
    } else if (command.startsWith('test ! -e')) {
      code = occupied ? 1 : 0;
    } else if (command.startsWith('docker manifest inspect')) {
      // Docker 29 rejects tag + platform digest: the tag resolves the index.
      if (command.contains('rclone/rclone:1.75.0@sha256:')) code = 1;
      output = jsonEncode({
        'manifests': [
          {
            'platform': {'os': 'linux', 'architecture': 'amd64'},
            'digest': 'sha256:${'a' * 64}',
          },
        ],
      });
    } else if (command.startsWith('docker compose') &&
        command.contains('up --detach')) {
      started = true;
      code = failStart ? 1 : 0;
    } else if (command.startsWith('docker inspect')) {
      if (inspectMissing) {
        return const SSHExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'No such object',
        );
      }
      output = jsonEncode([
        {
          'Id': 'new-id',
          'Config': {
            'Labels': {
              'com.valhalla.nas.install': changedOwnership
                  ? 'someone-else'
                  : installId,
            },
          },
          'State': {'Running': true},
        },
      ]);
    } else if (command.startsWith('docker ps -a --no-trunc')) {
      output = [
        jsonEncode({
          'id': 'existing-id',
          'names': 'other-service',
          'state': 'running',
        }),
        if (started)
          jsonEncode({
            'id': 'new-id',
            'names': compose['container_name'],
            'state': 'running',
          }),
      ].join('\n');
    } else if (command.startsWith('docker ps -a --filter')) {
      output = namedContainerExists ? 'foreign-container' : '';
    } else if (command.startsWith('test ! -L') &&
        command.contains('test ! -e')) {
      code = reconciliationFilesRemain ? 1 : 0;
    } else if (command.startsWith('set -o pipefail;')) {
      code = reconciliationProbeFails ? 1 : 0;
      output = reconciliationBusy ? 'BUSY' : 'IDLE';
    } else if (command.startsWith('curl')) {
      output = compose['entrypoint'] == null ? '200' : '401';
      if ((compose['image'] as String).startsWith('emby/embyserver')) {
        output = command.contains('/System/Info/Public')
            ? '$embyHealthStatus'
            : '302';
        if (embyHealthRequested?.isCompleted == false) {
          embyHealthRequested!.complete();
        }
      }
    }
    return SSHExecutionResult(
      exitCode: code,
      stdout: output,
      stderr: code == 0 ? '' : failureText,
    );
  }
}

class _Client extends Fake implements SSHClient {
  final _Executor executor;
  _Client(this.executor);
  @override
  bool get isClosed => false;
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    executor.commands.add(command);
    if (!executor.writeOpened.isCompleted) executor.writeOpened.complete();
    if (executor.pendingWrite != null) return executor.pendingWrite!.future;
    return _Session((value) {
      executor.files[command] = value;
    });
  }
}

class _Session extends Fake implements SSHSession {
  final input = StreamController<Uint8List>();
  final completion = Completer<void>();
  bool closed = false, terminated = false;
  _Session(void Function(String) receive) {
    final bytes = <int>[];
    input.stream.listen(
      bytes.addAll,
      onDone: () {
        receive(utf8.decode(bytes));
        completion.complete();
      },
    );
  }
  @override
  StreamSink<Uint8List> get stdin => input.sink;
  @override
  Stream<Uint8List> get stdout => const Stream.empty();
  @override
  Stream<Uint8List> get stderr => const Stream.empty();
  @override
  Future<void> get done => completion.future;
  @override
  int get exitCode => 0;
  @override
  void close() {
    closed = true;
  }

  @override
  void kill(SSHSignal signal) {
    terminated = true;
  }

  @override
  SSHChannel get channel => _SessionChannel(this);
}

class _SessionChannel extends Fake implements SSHChannel {
  final _Session session;
  _SessionChannel(this.session);
  @override
  void destroy([Object? error, StackTrace? stackTrace]) {
    session.closed = true;
  }
}

NasInstallRequest _request({
  NasInstallProduct product = NasInstallProduct.jellyfin,
  String mediaPath = '/media',
  String dataRoot = '/srv/new-nas',
}) => NasInstallRequest(
  serverId: 'ssh-one',
  serverName: 'Home NAS',
  product: product,
  mediaPath: mediaPath,
  dataRoot: dataRoot,
);

void main() {
  test(
    'Emby install and recovery wait for its public API instead of the root redirect',
    () async {
      final executor = _Executor()
        ..embyHealthStatus = 503
        ..embyHealthRequested = Completer<void>();
      Map<String, dynamic>? healthSummary;
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (summary) async {
          if (summary['stage'] == 'health') healthSummary = Map.of(summary);
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(
        _request(product: NasInstallProduct.emby),
      );
      final installing = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      await executor.embyHealthRequested!.future;
      await Future<void>.delayed(Duration.zero);
      expect(service.state!.stage, NasInstallStage.health);
      executor
        ..embyHealthStatus = 302
        ..embyHealthRequested = Completer<void>();
      await executor.embyHealthRequested!.future;
      await Future<void>.delayed(Duration.zero);
      expect(service.state!.stage, NasInstallStage.health);
      executor.embyHealthStatus = 200;
      expect((await installing).healthy, isTrue);
      expect(service.state!.stage, NasInstallStage.succeeded);
      final recovered = NasInstallService(
        executor,
        DockerCliService(executor),
        recoveredTask: healthSummary!,
      );
      addTearDown(recovered.dispose);
      for (final status in [503, 302]) {
        executor.embyHealthStatus = status;
        await recovered.reconcile();
        expect(recovered.state!.stage, NasInstallStage.needsInspection);
        expect(executor.commands.last, contains('/System/Info/Public'));
      }
      executor.embyHealthStatus = 200;
      await recovered.reconcile();
      expect(recovered.state!.stage, NasInstallStage.succeeded);
      expect(
        executor.commands.where((command) => command.startsWith('curl')),
        everyElement(contains('/System/Info/Public')),
      );
    },
  );

  test('preview is read-only and missing prerequisites cannot install', () async {
    final executor = _Executor()
      ..dockerAvailable = false
      ..failureText =
          'fixture error token=probe-secret https://user:probe-secret@registry.test/';
    final service = NasInstallService(executor, DockerCliService(executor));
    final plan = await service.prepare(_request());
    expect(plan.canInstall, false);
    expect(plan.blockers, contains('NAS_INSTALL_DOCKER_REQUIRED'));
    expect(
      service.state!.logTail,
      contains('NAS_INSTALL_DOCKER_REQUIRED: fixture error'),
    );
    expect(service.state!.logTail, isNot(contains('host-one')));
    expect(service.state!.logTail, isNot(contains('probe-secret')));
    expect(executor.files, isEmpty);
    expect(
      executor.commands.any(
        (cmd) =>
            cmd.contains('mkdir') ||
            cmd.contains(' pull') ||
            cmd.contains('up --detach'),
      ),
      false,
    );
    await expectLater(
      service.install(plan, confirmationToken: plan.confirmationToken),
      throwsA(isA<NasInstallException>()),
    );
  });

  test(
    'approved immutable plan installs once with read-only media and isolated data',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      final plan = await service.prepare(_request());
      expect(plan.canInstall, true);
      expect(plan.pinnedImage, contains('@sha256:'));
      final preview =
          (jsonDecode(plan.composePreview) as Map)['services']['nas'] as Map;
      expect((preview['volumes'] as List).first['read_only'], true);
      expect((preview['ports'] as List).single['host_ip'], '127.0.0.1');
      await expectLater(
        service.install(plan, confirmationToken: 'wrong'),
        throwsA(isA<NasInstallException>()),
      );
      expect(executor.files, isEmpty);
      final result = await service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      expect(result.healthy, true);
      expect(result.containerId, 'new-id');
      expect(result.endpoint.toString(), 'http://127.0.0.1:8096/');
      await expectLater(
        service.install(plan, confirmationToken: plan.confirmationToken),
        throwsA(isA<NasInstallException>()),
      );
      expect(
        executor.commands.where((cmd) => cmd.contains('up --detach')).length,
        1,
      );
    },
  );

  test(
    'identity changes and directory races invalidate approval before writes',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      final plan = await service.prepare(_request());
      executor.machineId = 'different-host';
      await expectLater(
        service.install(plan, confirmationToken: plan.confirmationToken),
        throwsA(
          predicate((error) => error.toString() == 'NAS_INSTALL_PLAN_STALE'),
        ),
      );
      expect(executor.files, isEmpty);
      final second = await service.prepare(_request());
      executor.occupied = true;
      await expectLater(
        service.install(second, confirmationToken: second.confirmationToken),
        throwsA(isA<NasInstallException>()),
      );
      expect(executor.files, isEmpty);
    },
  );

  test(
    'rollback only removes owned container and wizard files, never service data',
    () async {
      final executor = _Executor()..failStart = true;
      final service = NasInstallService(executor, DockerCliService(executor));
      final plan = await service.prepare(_request());
      await expectLater(
        service.install(plan, confirmationToken: plan.confirmationToken),
        throwsA(
          predicate(
            (error) => error is NasInstallException && error.cleanupComplete,
          ),
        ),
      );
      expect(executor.commands, contains("docker stop 'new-id'"));
      expect(executor.commands, contains("docker rm 'new-id'"));
      expect(
        executor.commands.any(
          (cmd) =>
              cmd.contains("stop 'existing-id'") ||
              cmd.contains("rm 'existing-id'"),
        ),
        false,
      );
      final remove = executor.commands.singleWhere(
        (cmd) => cmd.contains('rm -f'),
      );
      expect(remove, contains('.valhalla-owner'));
      expect(remove, isNot(contains('/config')));
      expect(remove, isNot(contains('rm -rf')));
      expect(
        executor.commands.any(
          (cmd) =>
              cmd.contains('prune') ||
              cmd.contains(' down') ||
              cmd.contains('sudo'),
        ),
        false,
      );
    },
  );

  test('rollback refuses replacement container ownership', () async {
    final executor = _Executor()
      ..failStart = true
      ..changedOwnership = true;
    final service = NasInstallService(executor, DockerCliService(executor));
    final plan = await service.prepare(_request());
    await expectLater(
      service.install(plan, confirmationToken: plan.confirmationToken),
      throwsA(
        predicate(
          (error) => error is NasInstallException && !error.cleanupComplete,
        ),
      ),
    );
    expect(
      executor.commands.any(
        (cmd) =>
            cmd.startsWith('docker rm') ||
            cmd.startsWith('docker stop') ||
            cmd.contains('rm -f'),
      ),
      false,
    );
  });

  test(
    'WebDAV secrets use SSH stdin and resolved architecture digest is reviewed',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      const password = r'supersecret $test `date` quotation"';
      final plan = await service.prepare(
        _request(product: NasInstallProduct.webdav),
        webdavPassword: password,
      );
      expect(plan.pinnedImage, endsWith('@sha256:${'a' * 64}'));
      expect(plan.composePreview, isNot(contains(password)));
      expect(
        (await service.install(
          plan,
          confirmationToken: plan.confirmationToken,
        )).healthy,
        true,
      );
      expect(executor.files.values, contains(password));
      expect(executor.commands.any((cmd) => cmd.contains(password)), false);
      expect(plan.composePreview, contains('--read-only'));
    },
  );

  test(
    'rejects relative paths, controls and data inside shared media',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      await expectLater(
        service.prepare(_request(mediaPath: 'relative')),
        throwsA(isA<NasInstallException>()),
      );
      await expectLater(
        service.prepare(_request(dataRoot: '/media/private')),
        throwsA(isA<NasInstallException>()),
      );
      await expectLater(
        service.prepare(_request(dataRoot: '/srv/new\nbad')),
        throwsArgumentError,
      );
      expect(executor.commands, isEmpty);
    },
  );
  test(
    'one retained task refuses duplicate starts and preflight cancellation releases channel',
    () async {
      final executor = _Executor()..stallCommand = 'uname -s';
      final service = NasInstallService(executor, DockerCliService(executor));
      addTearDown(service.dispose);
      final first = service.prepare(_request());
      final failure = expectLater(
        first,
        throwsA(
          predicate(
            (e) =>
                e is NasInstallException && e.code == 'NAS_INSTALL_CANCELLED',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.state!.stage, NasInstallStage.preflight);
      expect(service.state!.request.serverId, 'ssh-one');
      await expectLater(
        service.prepare(_request()),
        throwsA(
          predicate(
            (e) => e is NasInstallException && e.code == 'NAS_INSTALL_BUSY',
          ),
        ),
      );
      await service.cancel();
      await failure;
      expect(service.state!.stage, NasInstallStage.cancelled);
      expect(service.state!.cleanupComplete, true);
      expect(executor.streamCancelled, true);
      expect(executor.files, isEmpty);
    },
  );

  test(
    'cancel during pull stops later steps and reports uncertain remote work honestly',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      executor.stallCommand = ' pull';
      final pulling = service.states.firstWhere(
        (state) => state?.stage == NasInstallStage.pulling,
      );
      final running = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      final failure = expectLater(
        running,
        throwsA(
          predicate(
            (e) =>
                e is NasInstallException &&
                e.code == 'NAS_INSTALL_CANCELLED' &&
                !e.cleanupComplete,
          ),
        ),
      );
      await pulling;
      await Future<void>.delayed(Duration.zero);
      await service.cancel();
      await failure;
      expect(service.state!.stage, NasInstallStage.needsInspection);
      expect(service.state!.requiresReconciliation, true);
      expect(
        executor.commands.any((command) => command.contains('up --detach')),
        false,
      );
      expect(
        executor.commands.any((command) => command.contains('rm -f')),
        true,
      );
      expect(executor.streamCancelled, true);
    },
  );

  test(
    'streamed log is bounded and secrets split over packets are redacted',
    () async {
      const secret = 'twelve-character-secret';
      final executor = _Executor()
        ..pullOutput = [
          ('汉字 abc\n' * 50000),
          'token=spl',
          'it-token\n',
          'twelve-character-',
          'secret\n',
        ];
      final service = NasInstallService(executor, DockerCliService(executor));
      addTearDown(service.dispose);
      final snapshots = <NasInstallTask?>[];
      final sub = service.states.listen(snapshots.add);
      final plan = await service.prepare(
        _request(product: NasInstallProduct.webdav),
        webdavPassword: secret,
      );
      await service.install(plan, confirmationToken: plan.confirmationToken);
      expect(
        utf8.encode(service.state!.logTail).length,
        lessThanOrEqualTo(NasInstallService.maxLogBytes),
      );
      expect(service.state!.logTail, contains('token=******'));
      expect(
        snapshots.any(
          (state) =>
              state!.logTail.contains(secret) ||
              state.logTail.contains('split-token'),
        ),
        false,
      );
      await sub.cancel();
    },
  );

  test(
    'persisted interruption restores no credentials and recovery performs reads only',
    () async {
      final executor = _Executor();
      Map<String, dynamic>? summary;
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (value) async {
          summary = Map.of(value);
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(
        _request(product: NasInstallProduct.webdav),
        webdavPassword: 'test-private-password',
      );
      await service.install(plan, confirmationToken: plan.confirmationToken);
      expect(jsonEncode(summary), isNot(contains('test-private-password')));
      expect(jsonEncode(summary), isNot(contains(plan.confirmationToken)));
      summary!['stage'] = 'starting';
      final restored = NasInstallService(
        executor,
        DockerCliService(executor),
        recoveredTask: summary,
      );
      addTearDown(restored.dispose);
      expect(restored.state!.requiresReconciliation, true);
      expect(restored.state!.plan, isNull);
      await expectLater(
        restored.prepare(_request()),
        throwsA(isA<NasInstallException>()),
      );
      executor.commands.clear();
      await restored.reconcile();
      expect(restored.state!.stage, NasInstallStage.succeeded);
      expect(
        executor.commands.every(
          (c) =>
              c == 'cat /etc/machine-id' ||
              c.startsWith('docker info ') ||
              c.startsWith('docker inspect ') ||
              c.startsWith('curl '),
        ),
        true,
      );
    },
  );

  test('missing exit status never reports successful mutation', () async {
    final executor = _Executor();
    final service = NasInstallService(executor, DockerCliService(executor));
    addTearDown(service.dispose);
    final plan = await service.prepare(_request());
    final waiting = service.states.firstWhere(
      (state) => state?.stage == NasInstallStage.writing,
    );
    final install = service.install(
      plan,
      confirmationToken: plan.confirmationToken,
    );
    final failure = expectLater(install, throwsA(isA<NasInstallException>()));
    await waiting;
    executor.omitExitStatus = true;
    await failure;
    expect(service.state!.stage, NasInstallStage.needsInspection);
    expect(service.state!.cleanupComplete, false);
  });
  test(
    'cancellation during private-file channel opening closes a late channel',
    () async {
      final executor = _Executor()..pendingWrite = Completer<SSHSession>();
      final service = NasInstallService(executor, DockerCliService(executor));
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      final running = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      final failure = expectLater(
        running,
        throwsA(
          predicate(
            (e) =>
                e is NasInstallException &&
                e.code == 'NAS_INSTALL_CANCELLED' &&
                !e.cleanupComplete,
          ),
        ),
      );
      await executor.writeOpened.future;
      await service.cancel();
      await failure;
      final late = _Session(
        (_) => fail('A late session must not receive credentials'),
      );
      executor.pendingWrite!.complete(late);
      await Future<void>.delayed(Duration.zero);
      expect(late.closed, true);
      expect(late.terminated, true);
      expect(executor.files, isEmpty);
      expect(service.state!.stage, NasInstallStage.needsInspection);
    },
  );
  test(
    'successful history does not require reconciliation after process restart',
    () async {
      final executor = _Executor();
      Map<String, dynamic>? summary;
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (value) async {
          summary = Map.of(value);
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      await service.install(plan, confirmationToken: plan.confirmationToken);
      final restored = NasInstallService(
        executor,
        DockerCliService(executor),
        recoveredTask: summary,
      );
      addTearDown(restored.dispose);
      expect(restored.state!.stage, NasInstallStage.succeeded);
      expect(restored.state!.requiresReconciliation, false);
      expect(restored.state!.result!.containerId, 'new-id');
      expect((await restored.prepare(_request())).canInstall, true);
    },
  );

  test(
    'persistence failure stops mutations but cannot suppress owned cleanup',
    () async {
      final executor = _Executor();
      var failWrites = false;
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (value) async {
          if (value['stage'] == 'pulling') failWrites = true;
          if (failWrites) throw StateError('disk full');
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      await expectLater(
        service.install(plan, confirmationToken: plan.confirmationToken),
        throwsA(
          predicate(
            (e) =>
                e is NasInstallException &&
                e.code == 'NAS_INSTALL_STATE_SAVE_FAILED' &&
                e.cleanupComplete,
          ),
        ),
      );
      expect(executor.commands.any((c) => c.endsWith(' pull')), false);
      expect(executor.commands.any((c) => c.contains('rm -f')), true);
      expect(service.state!.stage, NasInstallStage.failed);
      expect(service.state!.isBusy, false);
      expect(service.state!.errorCode, 'NAS_INSTALL_STATE_SAVE_FAILED');
    },
  );
  test(
    'terminal persistence cannot race a new task and erase its secrets',
    () async {
      final executor = _Executor();
      final saved = Completer<void>();
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (value) async {
          if (value['stage'] == 'succeeded') await saved.future;
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      final finished = service.states.firstWhere(
        (s) => s?.stage == NasInstallStage.succeeded,
      );
      final running = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      await finished;
      await expectLater(
        service.prepare(_request()),
        throwsA(
          predicate(
            (e) => e is NasInstallException && e.code == 'NAS_INSTALL_BUSY',
          ),
        ),
      );
      saved.complete();
      await running;
      expect((await service.prepare(_request())).canInstall, true);
    },
  );
  test(
    'replacing an SSH connection cannot redirect writes or cleanup to another host',
    () async {
      final executor = _Executor();
      final service = NasInstallService(executor, DockerCliService(executor));
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      final pulling = service.states.firstWhere(
        (s) => s?.stage == NasInstallStage.pulling,
      );
      executor.stallCommand = ' pull';
      final running = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      final failure = expectLater(running, throwsA(isA<NasInstallException>()));
      await pulling;
      await Future<void>.delayed(Duration.zero);
      executor.client = _Client(executor);
      await service.cancel();
      await failure;
      expect(
        executor.commands.any(
          (c) => c.contains('up --detach') || c.contains('rm -f'),
        ),
        false,
      );
      expect(service.state!.cleanupComplete, false);
      expect(service.state!.requiresReconciliation, true);
    },
  );
  test('WebDAV platform digest remains verifiable on Docker 29', () async {
    final executor = _Executor();
    final service = NasInstallService(executor, DockerCliService(executor));
    addTearDown(service.dispose);
    final plan = await service.prepare(
      _request(product: NasInstallProduct.webdav),
      webdavPassword: 'fixture-private-password',
    );
    expect(
      (await service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      )).healthy,
      true,
    );
    expect(plan.pinnedImage, 'rclone/rclone@sha256:${'a' * 64}');
    expect(
      executor.commands.any(
        (command) => command.contains('rclone/rclone:1.75.0@sha256:'),
      ),
      false,
    );
    expect(executor.compose['image'], plan.pinnedImage);
  });
  test(
    'read-only reconciliation confirms cleaned cancellation and refuses incomplete evidence',
    () async {
      final executor = _Executor();
      Map<String, dynamic>? summary;
      final service = NasInstallService(
        executor,
        DockerCliService(executor),
        persistTask: (value) async {
          summary = Map.of(value);
        },
      );
      addTearDown(service.dispose);
      final plan = await service.prepare(_request());
      executor.stallCommand = ' pull';
      final pulling = service.states.firstWhere(
        (s) => s?.stage == NasInstallStage.pulling,
      );
      final running = service.install(
        plan,
        confirmationToken: plan.confirmationToken,
      );
      final failed = expectLater(running, throwsA(isA<NasInstallException>()));
      await pulling;
      await Future<void>.delayed(Duration.zero);
      await service.cancel();
      await failed;
      expect(service.state!.stage, NasInstallStage.needsInspection);
      expect(summary!['interruptedStage'], 'pulling');
      expect(summary!['interruptionCode'], 'NAS_INSTALL_CANCELLED');
      executor.inspectMissing = true;
      for (final scenario in [
        'clean',
        'files',
        'process',
        'probe-failed',
        'foreign',
        'writing',
        'starting',
        'legacy',
        'parent-changed',
        'legacy-path',
      ]) {
        executor.reconciliationFilesRemain = scenario == 'files';
        executor.reconciliationBusy = scenario == 'process';
        executor.reconciliationProbeFails = scenario == 'probe-failed';
        executor.namedContainerExists = scenario == 'foreign';
        final saved = Map<String, dynamic>.of(summary!);
        if (scenario == 'writing') saved['interruptedStage'] = 'writing';
        if (scenario == 'starting') saved['interruptedStage'] = 'starting';
        if (scenario == 'legacy') saved.remove('interruptedStage');
        if (scenario == 'parent-changed') {
          saved['canonicalDataRoot'] = '/elsewhere/changed';
        }
        if (scenario == 'legacy-path') saved.remove('canonicalDataRoot');
        final restored = NasInstallService(
          executor,
          DockerCliService(executor),
          recoveredTask: saved,
        );
        addTearDown(restored.dispose);
        executor.commands.clear();
        await restored.reconcile();
        expect(
          restored.state!.stage,
          scenario == 'clean'
              ? NasInstallStage.cancelled
              : NasInstallStage.needsInspection,
          reason: scenario,
        );
        expect(
          restored.state!.cleanupComplete,
          scenario == 'clean',
          reason: scenario,
        );
        expect(
          executor.commands.any(
            (command) =>
                command.contains('rm ') ||
                command.contains('mkdir') ||
                command.contains('docker stop') ||
                command.contains('up --detach'),
          ),
          false,
          reason: scenario,
        );
      }
    },
  );
}
