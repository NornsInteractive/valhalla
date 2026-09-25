import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/tool_availability_provider.dart';
import 'package:valhalla/core/utils/tool_probe.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 只实现探测用到的那一个方法；其余抛 UnimplementedError 以免掩盖误用。
class _FakeExecutor implements SshCommandExecutor {
  _FakeExecutor({this.result, this.throwing});

  SSHExecutionResult? result;

  /// 非空时 [executeWithLoginShell] 直接抛出它，模拟超时/传输错误。
  Object? throwing;

  final List<String> executedCommands = [];

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    executedCommands.add(command);
    if (throwing != null) throw throwing!;
    return result ??
        const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  bool isConnected(String serverId) => true;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream.empty();
}

/// 可切换连接状态的替身，用来驱动 `ref.listen` 的「变为已连接」分支。
class _SwitchableConnection extends ServerConnectionNotifier {
  _SwitchableConnection(this._state);

  ServerConnectionState _state;

  @override
  ServerConnectionState build() => _state;

  void setState(ServerConnectionState next) {
    _state = next;
    // 直接改内部 state 而不触发外部 provider 重建，模拟真实的状态流转。
    state = next;
  }
}

class _FixedActiveServer extends ActiveServerNotifier {
  _FixedActiveServer(this._server);

  final ServerProfile? _server;

  @override
  ServerProfile? build() => _server;
}

const _probeOutput = '''
TOOL:bash:OK:/usr/bin/bash
TOOL:docker:MISSING:
TOOL:systemctl:MISSING:
TOOL:ps:OK:/usr/bin/ps
TOOL:tmux:OK:/usr/bin/tmux
''';

Future<ProviderContainer> _container({
  required _FakeExecutor executor,
  required _SwitchableConnection connection,
  ServerProfile? server,
}) async {
  SharedPreferences.setMockInitialValues({});
  final localStorage = LocalStorageService(
    await SharedPreferences.getInstance(),
  );
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(localStorage),
      sshCommandExecutorProvider.overrideWithValue(executor),
      serverConnectionProvider.overrideWith(() => connection),
      activeServerProvider.overrideWith(() => _FixedActiveServer(server)),
    ],
  );
}

ServerProfile _server() => const ServerProfile(
  id: 's1',
  name: 'srv',
  host: '10.0.0.1',
  username: 'root',
);

void main() {
  group('ToolAvailabilityNotifier', () {
    test('未连接时不探测，也不编造「缺失」', () async {
      final executor = _FakeExecutor();
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.disconnected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      expect(executor.executedCommands, isEmpty);
      final state = container.read(toolAvailabilityProvider);
      expect(state.isProbing, isFalse);
      expect(state.missing, isEmpty);
      expect(state.probeFailed, isFalse);
    });

    test('没有选中服务器时不探测', () async {
      final executor = _FakeExecutor();
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: null,
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      expect(executor.executedCommands, isEmpty);
    });

    test('正常探测：可用与缺失分别落到 available / missing', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 0,
          stdout: _probeOutput,
          stderr: '',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      final state = container.read(toolAvailabilityProvider);
      expect(state.probeFailed, isFalse);
      expect(state.isProbing, isFalse);
      expect(state.isAvailable(RemoteTool.bash), isTrue);
      expect(state.available[RemoteTool.docker], isNull);
      expect(state.isMissing(RemoteTool.docker), isTrue);
      expect(state.isMissing(RemoteTool.systemctl), isTrue);
      expect(state.isAvailable(RemoteTool.ps), isTrue);
      expect(state.isAvailable(RemoteTool.tmux), isTrue);
      // 走的是合并后的单条命令。
      expect(executor.executedCommands, hasLength(1));
      expect(executor.executedCommands.single, ToolProbe.command);
    });

    test('连接成功后自动探测一次（无需手动触发）', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 0,
          stdout: _probeOutput,
          stderr: '',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connecting),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      // 先读一次把 notifier 建起来，注册上 ref.listen。
      container.read(toolAvailabilityProvider);
      expect(executor.executedCommands, isEmpty, reason: 'connecting 时不该探测');

      connection.setState(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      // 让自动触发的 probeNow() 跑完。**不**再手动调用 probeNow()，
      // 否则测的就不是「自动」而是「手动」了。
      await pumpEventQueue();

      expect(
        executor.executedCommands,
        isNotEmpty,
        reason: '变为 connected 后必须自动探测',
      );
      expect(container.read(toolAvailabilityProvider).isProbing, isFalse);
    });

    test('重连（disconnected → connected）也会再探测一次', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 0,
          stdout: _probeOutput,
          stderr: '',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.disconnected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      container.read(toolAvailabilityProvider);
      connection.setState(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      await pumpEventQueue();
      final afterFirst = executor.executedCommands.length;

      connection.setState(
        const ServerConnectionState(status: ConnectionStateEnum.disconnected),
      );
      await pumpEventQueue();
      connection.setState(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      await pumpEventQueue();

      expect(
        executor.executedCommands.length,
        greaterThan(afterFirst),
        reason: '重连后应再次探测',
      );
    });

    test('命令退出码非 0 → probeFailed，而不是「全部缺失」', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'bash: command not found',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      final state = container.read(toolAvailabilityProvider);
      expect(state.probeFailed, isTrue);
      expect(state.missing, isEmpty, reason: '失败不能被当成「工具都不存在」');
      expect(state.available, isEmpty);
    });

    test('抛异常（超时/传输错误）→ probeFailed 且不留残缺结论', () async {
      final executor = _FakeExecutor(throwing: Exception('timeout'));
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      final state = container.read(toolAvailabilityProvider);
      expect(state.probeFailed, isTrue);
      expect(state.isProbing, isFalse);
      expect(state.available, isEmpty);
      expect(state.missing, isEmpty);
    });

    test('输出全是噪声 → probeFailed，不产生「全部缺失」', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 0,
          stdout: 'Welcome to Ubuntu\nLast login: now\n',
          stderr: '',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      await container.read(toolAvailabilityProvider.notifier).probeNow();

      final state = container.read(toolAvailabilityProvider);
      expect(state.probeFailed, isTrue);
      expect(state.missing, isEmpty);
    });

    test('探测期间 isProbing 为 true', () async {
      final executor = _FakeExecutor(
        result: const SSHExecutionResult(
          exitCode: 0,
          stdout: _probeOutput,
          stderr: '',
        ),
      );
      final connection = _SwitchableConnection(
        const ServerConnectionState(status: ConnectionStateEnum.connected),
      );
      final container = await _container(
        executor: executor,
        connection: connection,
        server: _server(),
      );
      addTearDown(container.dispose);

      final future = container
          .read(toolAvailabilityProvider.notifier)
          .probeNow();
      expect(container.read(toolAvailabilityProvider).isProbing, isTrue);
      await future;
      expect(container.read(toolAvailabilityProvider).isProbing, isFalse);
    });
  });
}
