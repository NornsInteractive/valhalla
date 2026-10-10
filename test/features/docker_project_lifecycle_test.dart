import 'dart:async';
import 'dart:convert';

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
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// 假的远端命令执行器：只按固定脚本回放 `docker ps` / `docker <action>`。
class _FakeDockerExecutor implements SshCommandExecutor {
  String psOutput = '';
  int psExitCode = 0;
  String psStderr = '';

  /// 非空时 `docker ps` 在这里挂起，用来观测「加载中」窗口。
  Completer<void>? psGate;

  final lifecycleCalls =
      <({String serverId, String action, String containerId})>{};
  final otherCommands = <String>[];

  /// 按容器 id 指定生命周期命令的返回；未列出的默认成功。
  final lifecycleResults = <String, SSHExecutionResult>{};

  /// 非空时生命周期命令抛异常。
  Object? lifecycleThrowing;

  /// 非空时生命周期命令在这里挂起，制造稳定的「执行中」窗口。
  Completer<void>? lifecycleGate;

  @override
  bool isConnected(String serverId) => true;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    if (command.startsWith('docker ps')) {
      final gate = psGate;
      if (gate != null) await gate.future;
      return SSHExecutionResult(
        exitCode: psExitCode,
        stdout: psOutput,
        stderr: psStderr,
      );
    }
    final match = RegExp(r"^docker (\S+) '(.*)'$").firstMatch(command.trim());
    if (match != null &&
        {'start', 'stop', 'restart'}.contains(match.group(1))) {
      final containerId = match.group(2)!;
      lifecycleCalls.add((
        serverId: serverId,
        action: match.group(1)!,
        containerId: containerId,
      ));
      final gate = lifecycleGate;
      if (gate != null) await gate.future;
      final failure = lifecycleThrowing;
      if (failure != null) throw failure;
      return lifecycleResults[containerId] ??
          const SSHExecutionResult(exitCode: 0, stdout: 'name\n', stderr: '');
    }
    otherCommands.add(command);
    throw UnsupportedError('unexpected remote command: $command');
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream<SSHExecutionChunk>.empty();
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => null;
}

class _SwitchableActiveServer extends ActiveServerNotifier {
  ServerProfile? _server = const ServerProfile(
    id: 'srv-1',
    name: 'first docker host',
    host: 'a.example.test',
    username: 'root',
  );

  @override
  ServerProfile? build() => _server;

  void switchServer() {
    _server = const ServerProfile(
      id: 'srv-2',
      name: 'second docker host',
      host: 'b.example.test',
      username: 'root',
    );
    state = _server;
  }
}

class _SwitchableConnectionNotifier extends ServerConnectionNotifier {
  ServerConnectionState _current = const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );

  @override
  ServerConnectionState build() => _current;

  void presetDisconnected() {
    _current = const ServerConnectionState(
      status: ConnectionStateEnum.disconnected,
    );
  }

  @override
  void disconnect() {
    presetDisconnected();
    state = _current;
  }
}

class _DockerEnv {
  _DockerEnv({required this.container, required this.executor});

  final ProviderContainer container;
  final _FakeDockerExecutor executor;

  _SwitchableActiveServer get server =>
      container.read(activeServerProvider.notifier) as _SwitchableActiveServer;

  DockerNotifier get notifier => container.read(dockerProvider.notifier);
}

String _psLine({
  required String id,
  required String name,
  required String image,
  required String state,
  String? project,
  String? service,
  String ports = '',
}) {
  return jsonEncode({
    'id': id,
    'names': name,
    'image': image,
    'status': 'Up 2 hours',
    'state': state,
    'ports': ports,
    'created': '2026-10-09 10:00:00 UTC',
    'composeProject': project,
    'composeService': service,
  });
}

Future<_DockerEnv> _env({bool connected = true, String psOutput = ''}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final executor = _FakeDockerExecutor()..psOutput = psOutput;
  final connection = _SwitchableConnectionNotifier();
  if (!connected) connection.presetDisconnected();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_SwitchableActiveServer.new),
      serverConnectionProvider.overrideWith(() => connection),
      sshCommandExecutorProvider.overrideWithValue(executor),
    ],
  );
  addTearDown(container.dispose);
  // build() 只在 microtask 里拉取容器列表，这里先把首屏加载跑完，
  // 后续断言针对的都是真实的容器状态而不是空壳。
  container.read(dockerProvider);
  await pumpEventQueue();
  return _DockerEnv(container: container, executor: executor);
}

const _appPs =
    ''
    '{"id":"c-web","names":"app-web","image":"nginx:alpine",'
    '"status":"Up","state":"running","ports":"80:80",'
    '"created":"2026-10-09 10:00:00 UTC",'
    '"composeProject":"shop","composeService":"web"}\n'
    '{"id":"c-db","names":"app-db","image":"postgres:16",'
    '"status":"Up","state":"running","ports":"5432:5432",'
    '"created":"2026-10-09 10:00:00 UTC",'
    '"composeProject":"shop","composeService":"db"}\n'
    '{"id":"c-cache","names":"app-cache","image":"redis:7",'
    '"status":"Exited (0)","state":"exited","ports":"",'
    '"created":"2026-10-09 10:00:00 UTC",'
    '"composeProject":"shop","composeService":"cache"}\n'
    '{"id":"c-solo","names":"loose-container","image":"busybox",'
    '"status":"Up","state":"running","ports":"",'
    '"created":"2026-10-09 10:00:00 UTC"}\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DockerState.composeProjects 分组', () {
    test('按 compose 项目分组，只包含带标签的容器并保留 service 信息', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      final projects = env.container.read(dockerProvider).composeProjects;
      expect(projects.keys, ['shop']);
      expect(projects['shop']!.map((c) => c.id), [
        'c-web',
        'c-db',
        'c-cache',
      ], reason: '没有 compose 标签的容器不进任何项目分组');
      expect(projects['shop']!.first.composeService, 'web');
      expect(projects['shop']!.first.composeProject, 'shop');
    });

    test('分组沿用当前过滤条件，不会把被筛掉的容器算进去', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      env.notifier.setFilterState(DockerContainerState.running);
      expect(
        env.container
            .read(dockerProvider)
            .composeProjects['shop']!
            .map((c) => c.id),
        ['c-web', 'c-db'],
      );

      // 过滤与搜索叠加：redis 实例是 exited，被 running 过滤挡在外面。
      env.notifier.setSearchQuery('redis');
      expect(
        env.container.read(dockerProvider).composeProjects,
        isEmpty,
        reason: '搜索命中的目标不在当前状态过滤范围内时不应分组',
      );

      env.notifier.setFilterState(null);
      expect(
        env.container
            .read(dockerProvider)
            .composeProjects['shop']!
            .map((c) => c.id),
        ['c-cache'],
      );
      env.notifier.setSearchQuery('nothing-matches');
      expect(env.container.read(dockerProvider).composeProjects, isEmpty);
    });

    test('标签为空字符串时视为没有项目', () async {
      final env = await _env(
        psOutput:
            '${_psLine(id: 'c1', name: 'blank', image: 'nginx', state: 'running', project: '', service: '')}\n',
      );
      await pumpEventQueue();

      expect(env.container.read(dockerProvider).composeProjects, isEmpty);
    });
  });

  group('performProjectLifecycle 目标集合', () {
    test('只执行确认时给出的 id，不扩大到同项目的其它容器', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      final results = await env.notifier.performProjectLifecycle(
        'shop',
        'stop',
        ['c-web', 'c-cache'],
      );

      expect(results.map((r) => r.containerId), ['c-web', 'c-cache']);
      expect(env.executor.lifecycleCalls, [
        (serverId: 'srv-1', action: 'stop', containerId: 'c-web'),
        (serverId: 'srv-1', action: 'stop', containerId: 'c-cache'),
      ]);
      expect(
        env.executor.lifecycleCalls.map((c) => c.containerId),
        isNot(contains('c-db')),
        reason: '确认清单之外的目标不得被顺带操作',
      );
    });

    test('重复 id 只执行一次', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      final results = await env.notifier.performProjectLifecycle(
        'shop',
        'start',
        ['c-web', 'c-web'],
      );
      expect(results, hasLength(1));
      expect(env.executor.lifecycleCalls, hasLength(1));
    });

    test('目标已不存在、跨项目或为空时整体拒绝', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      for (final ids in <List<String>>[
        ['c-gone'],
        ['c-solo'],
        [],
        ['c-web', 'c-gone'],
      ]) {
        await expectLater(
          env.notifier.performProjectLifecycle('shop', 'stop', ids),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'DOCKER_PROJECT_TARGET_CHANGED',
            ),
          ),
          reason: '目标集合 $ids 与确认时的状态不一致，必须拒绝',
        );
      }
      expect(env.executor.lifecycleCalls, isEmpty);
    });

    test('只允许 start / stop / restart', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      for (final action in ['rm', 'pause', 'kill', 'restart ']) {
        await expectLater(
          env.notifier.performProjectLifecycle('shop', action, ['c-web']),
          throwsA(isA<ArgumentError>()),
          reason: '$action 不属于项目级生命周期动作',
        );
      }
      expect(env.executor.lifecycleCalls, isEmpty);
    });

    test('未连接时不执行任何远端命令', () async {
      final env = await _env(psOutput: _appPs, connected: false);
      await pumpEventQueue();

      await expectLater(
        env.notifier.performProjectLifecycle('shop', 'start', ['c-web']),
        throwsA(isA<SSHConnectionException>()),
      );
      expect(env.executor.lifecycleCalls, isEmpty);
    });

    test('确认后换了服务器，过期快照被整体拒绝执行', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      // UI 在弹确认框时按下当前服务器状态。
      final snapshot = env.server.state;

      env.server.switchServer();
      env.container.read(dockerProvider);
      await pumpEventQueue();

      await expectLater(
        env.notifier.performProjectLifecycle('shop', 'stop', [
          'c-web',
          'c-db',
        ], expectedServer: snapshot),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'DOCKER_PROJECT_TARGET_CHANGED',
          ),
        ),
        reason: '过期确认不允许把动作落到另一台服务器上',
      );
      expect(env.executor.lifecycleCalls, isEmpty);
    });

    test('expectedServer 与当前服务器一致时正常执行', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      final snapshot = env.container.read(activeServerProvider);

      final results = await env.notifier.performProjectLifecycle(
        'shop',
        'stop',
        ['c-web'],
        expectedServer: snapshot,
      );
      expect(results.single.success, isTrue);
      expect(env.executor.lifecycleCalls, hasLength(1));
    });
  });

  group('performProjectLifecycle 结果与进度', () {
    test('部分失败只标记失败项，其余照常成功', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      env.executor.lifecycleResults['c-db'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'permission denied',
      );

      final results = await env.notifier.performProjectLifecycle(
        'shop',
        'stop',
        ['c-web', 'c-db', 'c-cache'],
      );

      expect(results.map((r) => r.success), [true, false, true]);
      expect(results[0].containerName, 'app-web');
      expect(results[1].containerName, 'app-db');
      expect(results[1].error, contains('exit 1'));
      expect(results[1].error, contains('permission denied'));
      expect(results[2].error, isNull);
    });

    test('执行器抛异常时该项记为失败而不影响后续目标', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      env.executor.lifecycleThrowing = StateError('channel closed');

      final results = await env.notifier.performProjectLifecycle(
        'shop',
        'restart',
        ['c-web', 'c-db'],
      );
      expect(results.map((r) => r.success), [false, false]);
      expect(results.first.error, contains('channel closed'));
      expect(results[1].containerId, 'c-db');
    });

    test('执行期间 pendingActions 覆盖全部冻结目标，结束后清空', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      final gate = Completer<void>();
      env.executor.lifecycleGate = gate;

      final running = env.notifier.performProjectLifecycle('shop', 'stop', [
        'c-web',
        'c-db',
      ]);
      await pumpEventQueue();

      final pending = env.container.read(dockerProvider).pendingActions;
      expect(pending.keys.toSet(), {'c-web', 'c-db'});
      expect(pending.values.toSet(), {'stop'});

      await expectLater(
        env.notifier.performProjectLifecycle('shop', 'stop', ['c-web']),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'DOCKER_ACTION_PENDING',
          ),
        ),
        reason: '正在执行的目标不得被第二个批次重复操作',
      );

      gate.complete();
      await running;
      await pumpEventQueue();
      expect(env.container.read(dockerProvider).pendingActions, isEmpty);
    });

    test('切换服务器后剩余目标记为 interrupted 且不落到新服务器上', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      final gate = Completer<void>();
      env.executor.lifecycleGate = gate;

      final running = env.notifier.performProjectLifecycle('shop', 'stop', [
        'c-web',
        'c-db',
        'c-cache',
      ]);
      await pumpEventQueue();
      expect(env.executor.lifecycleCalls, hasLength(1));

      env.server.switchServer();
      env.container.read(dockerProvider);
      await pumpEventQueue();
      gate.complete();
      final results = await running;

      expect(results.first.success, isTrue);
      expect(results.skip(1).map((r) => r.success), everyElement(isFalse));
      expect(
        results.skip(1).map((r) => r.error),
        everyElement('DOCKER_OPERATION_INTERRUPTED'),
      );
      expect(
        env.executor.lifecycleCalls.every((call) => call.serverId == 'srv-1'),
        isTrue,
        reason: '切换之后不得对新服务器执行确认过的动作',
      );
      expect(env.executor.lifecycleCalls, hasLength(1));
    });
  });

  group('刷新失败与加载状态', () {
    test('刷新失败保留缓存容器，错误不会被搜索或过滤清掉', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();
      expect(env.container.read(dockerProvider).containers, hasLength(4));

      env.executor.psExitCode = 1;
      env.executor.psStderr =
          'Cannot connect to the Docker daemon at unix:///var/run/docker.sock';
      await env.notifier.refresh();
      await pumpEventQueue();

      final failed = env.container.read(dockerProvider);
      expect(failed.isLoading, isFalse);
      expect(
        failed.errorMessage,
        contains('Cannot connect to the Docker daemon'),
        reason: '远端 docker ps 失败必须原样暴露，不能伪装成空列表成功',
      );
      expect(failed.exitCode, 1);
      expect(failed.containers, hasLength(4), reason: '刷新失败必须保留上一次成功的容器缓存');

      // 过滤/搜索只作用于缓存，不得顺手把错误一起清掉。
      env.notifier.setFilterState(DockerContainerState.running);
      expect(
        env.container.read(dockerProvider).errorMessage,
        contains('Cannot connect to the Docker daemon'),
      );
      expect(
        env.container.read(dockerProvider).filteredContainers,
        hasLength(3),
      );

      env.notifier.setSearchQuery('redis');
      expect(
        env.container.read(dockerProvider).errorMessage,
        contains('Cannot connect to the Docker daemon'),
      );
      expect(
        env.container.read(dockerProvider).filteredContainers,
        isEmpty,
        reason: '搜索+过滤后为空只是「筛选结果为空」，错误仍然要显示',
      );
      expect(env.container.read(dockerProvider).containers, hasLength(4));
    });

    test('刷新成功后错误被清除', () async {
      final env = await _env(psOutput: _appPs);
      await pumpEventQueue();

      env.executor.psExitCode = 1;
      env.executor.psStderr = 'docker daemon unavailable';
      await env.notifier.refresh();
      await pumpEventQueue();
      expect(env.container.read(dockerProvider).errorMessage, isNotNull);

      env.executor.psExitCode = 0;
      env.executor.psStderr = '';
      await env.notifier.refresh();
      await pumpEventQueue();

      final recovered = env.container.read(dockerProvider);
      expect(recovered.errorMessage, isNull);
      expect(recovered.exitCode, isNull);
      expect(recovered.isLoading, isFalse);
      expect(recovered.containers, hasLength(4));
    });

    test('quiet 刷新有缓存时不显示加载，无缓存时仍显示加载', () async {
      final cached = await _env(psOutput: _appPs);
      await pumpEventQueue();
      final cacheGate = Completer<void>();
      cached.executor.psGate = cacheGate;
      final cachedRefresh = cached.notifier.refresh(quiet: true);
      await pumpEventQueue();
      expect(
        cached.container.read(dockerProvider).isLoading,
        isFalse,
        reason: '已有缓存的后台刷新不应闪烁加载态',
      );

      final uncached = await _env(psOutput: '');
      await pumpEventQueue();
      expect(uncached.container.read(dockerProvider).containers, isEmpty);
      final emptyGate = Completer<void>();
      uncached.executor.psGate = emptyGate;
      final emptyRefresh = uncached.notifier.refresh(quiet: true);
      await pumpEventQueue();
      expect(
        uncached.container.read(dockerProvider).isLoading,
        isTrue,
        reason: '没有任何缓存时后台刷新也必须让用户看到加载中',
      );

      cacheGate.complete();
      emptyGate.complete();
      await Future.wait([cachedRefresh, emptyRefresh]);
      await pumpEventQueue();

      expect(cached.container.read(dockerProvider).isLoading, isFalse);
      expect(cached.container.read(dockerProvider).containers, hasLength(4));
      expect(uncached.container.read(dockerProvider).isLoading, isFalse);
      expect(uncached.container.read(dockerProvider).containers, isEmpty);
    });
  });
}
