import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/system/system_provider.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/system/process_service.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';

/// 目标绑定用例：全部走替身，一条真实 SSH 都不发。
///
/// 断言集中在「确认时捕获的目标（connectionKey / 进程启动身份）在 await
/// 之后是否仍然成立」，以及「迟到的结果能不能刷新到新目标上」。

const _srv1 = ServerProfile(
  id: 'srv-1',
  name: 'server one',
  host: 'one.test',
  username: 'root',
);

/// 只改了 id：`connectionKey` 因此不同，必须被当成换目标。
const _srv2 = ServerProfile(
  id: 'srv-2',
  name: 'server two',
  host: 'two.test',
  username: 'root',
);

const _startedAt = 'Sun Oct 11 10:00:00 2026';

Matcher _targetChanged() => isA<ValidationException>().having(
  (e) => e.message,
  'message',
  'SERVICE_TARGET_CHANGED',
);

Matcher _identityUnavailable() => isA<ValidationException>().having(
  (e) => e.message,
  'message',
  'PROCESS_IDENTITY_UNAVAILABLE',
);

Matcher _busy() => isA<ValidationException>().having(
  (e) => e.message,
  'message',
  'SERVICE_ACTION_IN_PROGRESS',
);

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

/// 记录调用并按需停住的 [ProcessService] 替身：不碰 SSH，只做记账。
class _RecordingProcessService extends ProcessService {
  _RecordingProcessService(super.manager);

  final listCalls = <String>[];
  final terminateCalls =
      <({String serverId, int pid, bool force, String? expectedStartedAt})>[];

  /// 非空时 [terminate] 停在这里，用来造「结果比目标活得久」的窗口。
  Completer<void>? terminateGate;

  @override
  Future<List<ProcessInfo>> list(String serverId) async {
    listCalls.add(serverId);
    return const [];
  }

  @override
  Future<SSHExecutionResult> terminate(
    String serverId,
    int pid, {
    bool force = false,
    String? expectedStartedAt,
  }) async {
    terminateCalls.add((
      serverId: serverId,
      pid: pid,
      force: force,
      expectedStartedAt: expectedStartedAt,
    ));
    if (terminateGate != null) await terminateGate!.future;
    return const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }
}

/// 同上，服务侧。
class _RecordingServiceManager extends ServiceManager {
  _RecordingServiceManager(super.manager);

  final listCalls = <String>[];
  final actionCalls = <(String serverId, String service, String action)>[];
  final logCalls = <(String serverId, String service, String? beforeCursor)>[];

  Completer<void>? actionGate;
  Completer<void>? logsGate;

  @override
  Future<List<SystemdServiceInfo>> list(String serverId) async {
    listCalls.add(serverId);
    return const [];
  }

  @override
  Future<SSHExecutionResult> action(
    String serverId,
    String service,
    String action,
  ) async {
    actionCalls.add((serverId, service, action));
    if (actionGate != null) await actionGate!.future;
    return const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<List<Map<String, dynamic>>> logs(
    String serverId,
    String service, {
    String? beforeCursor,
  }) async {
    logCalls.add((serverId, service, beforeCursor));
    if (logsGate != null) await logsGate!.future;
    return const [];
  }
}

class _ConnectedNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _StubActiveServer extends ActiveServerNotifier {
  _StubActiveServer(this._initial);
  final ServerProfile _initial;

  @override
  ServerProfile? build() => _initial;

  void switchServer(ServerProfile server) => state = server;
}

typedef _Harness = ({
  ProviderContainer container,
  _StubActiveServer active,
  _RecordingProcessService processes,
  _RecordingServiceManager services,
  SystemNotifier notifier,
});

Future<_Harness> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final manager = _FakeSshManager(storage);
  final processes = _RecordingProcessService(manager);
  final services = _RecordingServiceManager(manager);
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(manager),
      activeServerProvider.overrideWith(() => _StubActiveServer(_srv1)),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      processServiceProvider.overrideWithValue(processes),
      serviceManagerProvider.overrideWithValue(services),
    ],
  );
  final active =
      container.read(activeServerProvider.notifier) as _StubActiveServer;
  final notifier = container.read(systemProvider.notifier);
  await pumpEventQueue();
  return (
    container: container,
    active: active,
    processes: processes,
    services: services,
    notifier: notifier,
  );
}

/// 换目标并强制 SystemNotifier 重新 build（它 watch 了 connectionKey）。
Future<void> _switchTarget(_Harness harness) async {
  harness.active.switchServer(_srv2);
  harness.container.read(systemProvider);
  await pumpEventQueue();
}

void main() {
  group('terminateProcess target binding', () {
    test('a changed connection key is refused before any ssh work', () async {
      final h = await _harness();
      addTearDown(h.container.dispose);
      final captured = h.container.read(activeServerProvider)!.connectionKey;
      expect(captured, isNot(_srv2.connectionKey));

      await _switchTarget(h);

      await expectLater(
        h.notifier.terminateProcess(
          4321,
          expectedStartedAt: _startedAt,
          expectedConnectionKey: captured,
        ),
        throwsA(_targetChanged()),
      );
      expect(h.processes.terminateCalls, isEmpty, reason: '目标变了必须在发 SSH 之前就拒绝');
    });

    test(
      'the captured key and start identity reach the process service',
      () async {
        final h = await _harness();
        addTearDown(h.container.dispose);
        final captured = h.container.read(activeServerProvider)!.connectionKey;

        await h.notifier.terminateProcess(
          4321,
          force: true,
          expectedStartedAt: _startedAt,
          expectedConnectionKey: captured,
        );

        expect(h.processes.terminateCalls, hasLength(1));
        final call = h.processes.terminateCalls.single;
        expect(call.serverId, 'srv-1');
        expect(call.pid, 4321);
        expect(call.force, isTrue);
        expect(
          call.expectedStartedAt,
          _startedAt,
          reason: '进程启动身份必须原样转发，kill 才不会打到复用的 pid',
        );
        expect(h.container.read(systemProvider).processes, isEmpty);
      },
    );

    test('a missing start identity is refused before any ssh work', () async {
      final h = await _harness();
      addTearDown(h.container.dispose);
      final captured = h.container.read(activeServerProvider)!.connectionKey;

      await expectLater(
        h.notifier.terminateProcess(
          4321,
          expectedStartedAt: null,
          expectedConnectionKey: captured,
        ),
        throwsA(_identityUnavailable()),
      );
      await expectLater(
        h.notifier.terminateProcess(
          4321,
          expectedStartedAt: '',
          expectedConnectionKey: captured,
        ),
        throwsA(_identityUnavailable()),
      );
      for (final blank in [' ', '   ', '\t', '\n', ' \t\n ']) {
        await expectLater(
          h.notifier.terminateProcess(
            4321,
            expectedStartedAt: blank,
            expectedConnectionKey: captured,
          ),
          throwsA(_identityUnavailable()),
          reason: '纯空白不能充当进程启动身份',
        );
      }
      expect(h.processes.terminateCalls, isEmpty);
    });

    test('a late terminate result cannot refresh the new target', () async {
      final h = await _harness();
      addTearDown(h.container.dispose);
      final captured = h.container.read(activeServerProvider)!.connectionKey;
      h.processes.terminateGate = Completer<void>();

      final pending = h.notifier.terminateProcess(
        4321,
        expectedStartedAt: _startedAt,
        expectedConnectionKey: captured,
      );
      await pumpEventQueue();
      expect(h.processes.terminateCalls, hasLength(1));

      await _switchTarget(h);
      h.processes.listCalls.clear();

      h.processes.terminateGate!.complete();
      await expectLater(pending, throwsA(_targetChanged()));
      expect(
        h.processes.listCalls,
        isEmpty,
        reason: '迟到的 terminate 结果不许再为新目标刷新进程列表',
      );
    });
  });

  group('service action target binding', () {
    test('a changed connection key is refused before any ssh work', () async {
      final h = await _harness();
      addTearDown(h.container.dispose);
      final captured = h.container.read(activeServerProvider)!.connectionKey;

      await _switchTarget(h);

      await expectLater(
        h.notifier.performServiceAction(
          'nginx.service',
          'restart',
          expectedConnectionKey: captured,
        ),
        throwsA(_targetChanged()),
      );
      await expectLater(
        h.notifier.serviceLogs(
          'nginx.service',
          expectedConnectionKey: captured,
        ),
        throwsA(_targetChanged()),
      );
      expect(h.services.actionCalls, isEmpty);
      expect(h.services.logCalls, isEmpty, reason: 'action 和日志都必须先校验目标再碰 SSH');
    });

    test(
      'the captured key reaches the service manager with its cursor',
      () async {
        final h = await _harness();
        addTearDown(h.container.dispose);
        final captured = h.container.read(activeServerProvider)!.connectionKey;

        await h.notifier.performServiceAction(
          'nginx.service',
          'restart',
          expectedConnectionKey: captured,
        );
        await h.notifier.serviceLogs(
          'nginx.service',
          beforeCursor: 's=3',
          expectedConnectionKey: captured,
        );

        expect(h.services.actionCalls.single, (
          'srv-1',
          'nginx.service',
          'restart',
        ));
        expect(h.services.logCalls.single, ('srv-1', 'nginx.service', 's=3'));
        expect(
          h.container.read(systemProvider).pendingActions,
          isEmpty,
          reason: '动作结束后 pending 必须清干净',
        );
      },
    );

    test(
      'a duplicate action on the same unit is refused while it is pending',
      () async {
        final h = await _harness();
        addTearDown(h.container.dispose);
        h.services.actionGate = Completer<void>();
        final captured = h.container.read(activeServerProvider)!.connectionKey;

        final first = h.notifier.performServiceAction(
          'nginx.service',
          'restart',
          expectedConnectionKey: captured,
        );
        await pumpEventQueue();
        expect(h.container.read(systemProvider).pendingActions, {
          'nginx.service': 'restart',
        });

        await expectLater(
          h.notifier.performServiceAction(
            'nginx.service',
            'restart',
            expectedConnectionKey: captured,
          ),
          throwsA(_busy()),
        );
        expect(
          h.services.actionCalls,
          hasLength(1),
          reason: 'busy 状态下不许再发第二条 SSH',
        );

        // 另一个单元不受影响，可以并行排队。
        final other = h.notifier.performServiceAction(
          'sshd.service',
          'reload',
          expectedConnectionKey: captured,
        );
        await pumpEventQueue();
        expect(h.services.actionCalls, hasLength(2));

        h.services.actionGate!.complete();
        await Future.wait([first, other]);
        expect(h.container.read(systemProvider).pendingActions, isEmpty);
      },
    );

    test(
      'a late service action result cannot refresh the new target',
      () async {
        final h = await _harness();
        addTearDown(h.container.dispose);
        h.services.actionGate = Completer<void>();
        final captured = h.container.read(activeServerProvider)!.connectionKey;

        final pending = h.notifier.performServiceAction(
          'nginx.service',
          'restart',
          expectedConnectionKey: captured,
        );
        await pumpEventQueue();
        expect(h.services.actionCalls, hasLength(1));

        await _switchTarget(h);
        h.services.listCalls.clear();

        h.services.actionGate!.complete();
        await expectLater(pending, throwsA(_targetChanged()));
        expect(
          h.services.listCalls,
          isEmpty,
          reason: '迟到的 action 结果不许再为新目标刷新服务列表',
        );
        expect(h.container.read(systemProvider).pendingActions, isEmpty);
      },
    );

    test('a late logs result cannot refresh the new target', () async {
      final h = await _harness();
      addTearDown(h.container.dispose);
      h.services.logsGate = Completer<void>();
      final captured = h.container.read(activeServerProvider)!.connectionKey;

      final pending = h.notifier.serviceLogs(
        'nginx.service',
        expectedConnectionKey: captured,
      );
      await pumpEventQueue();
      expect(h.services.logCalls, hasLength(1));

      await _switchTarget(h);
      h.services.logCalls.clear();

      h.services.logsGate!.complete();
      await expectLater(pending, throwsA(_targetChanged()));
      expect(h.services.logCalls, isEmpty);
    });
  });
}
