import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 可按 agentId 预置检测结果的环境服务替身。
class _FakeEnvService implements AgentEnvironmentService {
  _FakeEnvService({
    this.connected = true,
    Map<String, AgentEnvironmentStatus>? results,
  }) : _results = results ?? {};

  final bool connected;
  final Map<String, AgentEnvironmentStatus> _results;
  final List<String> inspectedAgentIds = [];
  final List<String> installedAgentIds = [];
  final List<String> loggedInAgentIds = [];

  /// 记录 `runInstallCommand` 实际收到的命令，用于断言命令选择逻辑。
  final List<String> executedInstallCommands = [];

  /// 流式安装时按序产出的片段。
  final List<String> installChunks = [];

  /// 只读凭据探针在替身里不可用：registry 不得把它当成检测的一部分。
  @override
  Future<AgentAuthenticationStatus> Function(AgentProfile, String)?
  get validateSavedAuth => null;

  @override
  Future<AgentEnvironmentStatus> inspect(
    AgentProfile profile,
    String serverId, {
    bool requireAcp = true,
  }) async {
    inspectedAgentIds.add(profile.id);
    return _results[profile.id] ?? _ready();
  }

  @override
  Future<SSHExecutionResult> runInstall(
    AgentProfile profile,
    String serverId,
  ) async {
    if (profile.installCommand == null) {
      throw const ValidationException('missing install', 'CMD_MISSING');
    }
    installedAgentIds.add(profile.id);
    return SSHExecutionResult(
      exitCode: 0,
      stdout: 'installed ${profile.id}',
      stderr: '',
    );
  }

  @override
  Future<SSHExecutionResult> runInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) async {
    if (command.trim().isEmpty) {
      throw const ValidationException('missing install', 'CMD_MISSING');
    }
    executedInstallCommands.add(command);
    installedAgentIds.add(profile.id);
    return SSHExecutionResult(
      exitCode: 0,
      stdout: 'installed ${profile.id}',
      stderr: '',
    );
  }

  @override
  Stream<String> streamInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) async* {
    if (command.trim().isEmpty) {
      throw const ValidationException('missing install', 'CMD_MISSING');
    }
    executedInstallCommands.add(command);
    installedAgentIds.add(profile.id);
    for (final chunk in installChunks) {
      yield chunk;
    }
  }

  @override
  Future<SSHExecutionResult> runLogin(
    AgentProfile profile,
    String serverId,
  ) async {
    if (profile.loginCommand == null) {
      throw const ValidationException('missing login', 'CMD_MISSING');
    }
    loggedInAgentIds.add(profile.id);
    return const SSHExecutionResult(exitCode: 0, stdout: 'ok', stderr: '');
  }

  AgentEnvironmentStatus _ready() => AgentEnvironmentStatus(
    kind: AgentEnvironmentStatusKind.ready,
    checkedAt: DateTime.now(),
  );
}

AgentEnvironmentStatus _kind(AgentEnvironmentStatusKind kind) =>
    AgentEnvironmentStatus(kind: kind, checkedAt: DateTime.now());

AgentProfile _agent(
  String id,
  String serverId, {
  String? install,
  String? acpInstall,
  String? login,
}) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
  description: 'desc',
  cliCommand: 'cli-$id',
  acpCommand: 'acp-$id --stdio',
  installCommand: install,
  acpInstallCommand: acpInstall,
  loginCommand: login,
);

/// 强制连接状态的替身，使 registry 不因默认断连而短路。
/// 不 watch `activeServerProvider`，避免与 registry 形成循环依赖。
class _ConnectedNotifier extends ServerConnectionNotifier {
  _ConnectedNotifier(this._connected);

  final bool _connected;

  @override
  ServerConnectionState build() {
    return ServerConnectionState(
      status: _connected
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
      // 生产里 connect() 一定会写 activeServerId；registry 的
      // `_isConnected` 也用它区分「连上的是不是当前这台」。
      activeServerId: ref.read(activeServerProvider)?.id,
    );
  }
}

/// 可在测试中切换连接状态的替身，用来驱动 `ref.listen` 的「变为已连接」分支。
class _SwitchableConnection extends ServerConnectionNotifier {
  _SwitchableConnection(this._status);

  ConnectionStateEnum _status;
  String? _serverId;

  @override
  ServerConnectionState build() {
    _serverId = ref.read(activeServerProvider)?.id;
    return ServerConnectionState(status: _status, activeServerId: _serverId);
  }

  void go(ConnectionStateEnum next) {
    _status = next;
    state = ServerConnectionState(status: next, activeServerId: _serverId);
  }
}

Future<ProviderContainer> _container({
  required Map<String, Object> prefs,
  AgentEnvironmentService? envService,
  bool connected = true,
  ServerConnectionNotifier Function()? connectionFactory,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final localStorage = LocalStorageService(
    await SharedPreferences.getInstance(),
  );
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(localStorage),
      serverConnectionProvider.overrideWith(
        connectionFactory ?? () => _ConnectedNotifier(connected),
      ),
      if (envService != null)
        agentEnvironmentServiceProvider.overrideWithValue(envService),
    ],
  );
}

String _agentsPrefs(List<AgentProfile> agents) =>
    jsonEncode(agents.map((a) => a.toJson()).toList());

String _serversPrefs(List<ServerProfile> servers) =>
    jsonEncode(servers.map((s) => s.toJson()).toList());

ServerProfile _server(String id) =>
    ServerProfile(id: id, name: id, host: '10.0.0.1', username: 'root');

void main() {
  group('AgentRegistryNotifier', () {
    test('isolates agents by server', () async {
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1'),
            _agent('a2', 's2'),
          ]),
        },
        envService: _FakeEnvService(),
      );
      addTearDown(container.dispose);

      final state = container.read(agentRegistryProvider);

      expect(state.serverId, 's1');
      expect(state.agents.map((a) => a.profile.id), ['a1']);
    });

    test('switching server refreshes and does not reuse stale state', () async {
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1'), _server('s2')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1'),
            _agent('a2', 's2'),
          ]),
        },
        envService: _FakeEnvService(),
      );
      addTearDown(container.dispose);
      expect(container.read(agentRegistryProvider).serverId, 's1');

      await container.read(activeServerProvider.notifier).selectServer('s2');

      final state = container.read(agentRegistryProvider);
      expect(state.serverId, 's2');
      expect(state.agents.map((a) => a.profile.id), ['a2']);
    });

    test('add agent saves then inspects', () async {
      final env = _FakeEnvService();
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
        },
        envService: env,
      );
      addTearDown(container.dispose);

      await container
          .read(agentRegistryProvider.notifier)
          .addAgent(_agent('a1', 's1'));

      expect(env.inspectedAgentIds, contains('a1'));
      expect(
        container.read(agentRegistryProvider).agents.map((a) => a.profile.id),
        ['a1'],
      );
    });

    test('readyAgents excludes every non-ready kind', () async {
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('ready', 's1'),
            _agent('cli', 's1'),
            _agent('acp', 's1'),
            _agent('login', 's1'),
            _agent('err', 's1'),
            _agent('unk', 's1'),
          ]),
        },
        envService: _FakeEnvService(
          results: {
            'ready': _kind(AgentEnvironmentStatusKind.ready),
            'cli': _kind(AgentEnvironmentStatusKind.cliMissing),
            'acp': _kind(AgentEnvironmentStatusKind.acpMissing),
            'login': _kind(AgentEnvironmentStatusKind.notLoggedIn),
            'err': _kind(AgentEnvironmentStatusKind.error),
            'unk': _kind(AgentEnvironmentStatusKind.unknown),
          },
        ),
      );
      addTearDown(container.dispose);

      await container.read(agentRegistryProvider.notifier).refresh();

      final ready = container.read(agentRegistryProvider).readyAgents;
      expect(ready.map((a) => a.id), ['ready']);
    });

    test('delete last agent yields empty state', () async {
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
        },
        envService: _FakeEnvService(),
      );
      addTearDown(container.dispose);

      await container.read(agentRegistryProvider.notifier).deleteAgent('a1');

      expect(container.read(agentRegistryProvider).agents, isEmpty);
    });

    test(
      'disconnected ssh blocks refresh but keeps the last snapshot',
      () async {
        final env = _FakeEnvService();
        late _SwitchableConnection connection;
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
          },
          envService: env,
          connectionFactory: () =>
              connection = _SwitchableConnection(ConnectionStateEnum.connected),
        );
        addTearDown(container.dispose);

        await container.read(agentRegistryProvider.notifier).refresh();
        expect(env.inspectedAgentIds, ['a1']);
        expect(
          container.read(agentRegistryProvider).findRuntime('a1')?.isReady,
          isTrue,
          reason: '前提：连着的时候拿到过一次真实检测结果',
        );

        connection.go(ConnectionStateEnum.disconnected);
        await pumpEventQueue();
        await container.read(agentRegistryProvider.notifier).refresh();

        final runtime = container.read(agentRegistryProvider).findRuntime('a1');
        expect(env.inspectedAgentIds, [
          'a1',
        ], reason: '断连时 refresh 必须被挡住，不得发起远端检测');
        expect(runtime?.isReady, isTrue, reason: '断连保留最后一次检测快照，界面不该被清空');
        expect(
          runtime?.errorMessage,
          isNull,
          reason: '断连不是 agent 出错，不得给缓存盖上错误码',
        );
        expect(container.read(agentRegistryProvider).isLoading, isFalse);
      },
    );

    test('disconnected ssh blocks install and login', () async {
      final env = _FakeEnvService(connected: false);
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', install: 'install-a1', login: 'login-a1'),
          ]),
        },
        envService: env,
        connected: false,
      );
      addTearDown(container.dispose);

      await container.read(agentRegistryProvider.notifier).installAgent('a1');
      await container.read(agentRegistryProvider.notifier).loginAgent('a1');

      expect(env.installedAgentIds, isEmpty);
      expect(env.loggedInAgentIds, isEmpty);
    });

    test('install sets isInstalling then reinspects', () async {
      final env = _FakeEnvService(
        results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
      );
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', install: 'install-a1'),
          ]),
        },
        envService: env,
      );
      addTearDown(container.dispose);
      await container.read(agentRegistryProvider.notifier).refresh();

      await container.read(agentRegistryProvider.notifier).installAgent('a1');

      expect(env.installedAgentIds, contains('a1'));
      expect(env.inspectedAgentIds, contains('a1'));
      final runtime = container.read(agentRegistryProvider).findRuntime('a1');
      expect(runtime?.isInstalling, isFalse);
    });

    test('login re-probes without executing any command', () async {
      final env = _FakeEnvService();
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', login: 'login-a1'),
          ]),
        },
        envService: env,
      );
      addTearDown(container.dispose);

      await container.read(agentRegistryProvider.notifier).loginAgent('a1');

      // The login command runs in the interactive terminal dialog, driven by
      // the user. The provider must only re-check the environment afterwards.
      expect(env.loggedInAgentIds, isEmpty);
      expect(env.inspectedAgentIds, contains('a1'));
      final runtime = container.read(agentRegistryProvider).findRuntime('a1');
      expect(runtime?.isLoggingIn, isFalse);
    });

    test('failed install keeps sanitized error and no fake success', () async {
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', install: 'install-a1'),
          ]),
        },
        envService: _FailingInstallEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
        ),
      );
      addTearDown(container.dispose);
      await container.read(agentRegistryProvider.notifier).refresh();

      await container.read(agentRegistryProvider.notifier).installAgent('a1');

      final runtime = container.read(agentRegistryProvider).findRuntime('a1');
      expect(runtime?.isReady, isFalse);
      expect(runtime?.errorMessage, isNotNull);
    });

    test(
      'installForCurrentStatus runs the CLI command when cli is missing',
      () async {
        final env = _FakeEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([
              _agent(
                'a1',
                's1',
                install: 'install-cli',
                acpInstall: 'install-acp',
              ),
            ]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        expect(env.executedInstallCommands, ['install-cli']);
      },
    );

    test(
      'installForCurrentStatus runs the ACP command when acp is missing',
      () async {
        final env = _FakeEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.acpMissing)},
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([
              _agent(
                'a1',
                's1',
                install: 'install-cli',
                acpInstall: 'install-acp',
              ),
            ]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        expect(env.executedInstallCommands, ['install-acp']);
      },
    );

    test(
      'installForCurrentStatus falls back to CLI command for missing acp',
      () async {
        final env = _FakeEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.acpMissing)},
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([
              _agent('a1', 's1', install: 'install-cli'),
            ]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        expect(env.executedInstallCommands, ['install-cli']);
      },
    );

    test(
      'installForCurrentStatus is a no-op when the agent is ready',
      () async {
        final env = _FakeEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.ready)},
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([
              _agent('a1', 's1', install: 'install-cli'),
            ]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        expect(env.executedInstallCommands, isEmpty);
      },
    );

    test(
      'installForCurrentStatus reports a reason code when no command exists',
      () async {
        final env = _FakeEnvService(
          results: {'a1': _kind(AgentEnvironmentStatusKind.acpMissing)},
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        expect(env.executedInstallCommands, isEmpty);
        final runtime = container.read(agentRegistryProvider).findRuntime('a1');
        expect(runtime?.errorMessage, 'CMD_MISSING:installCommand');
      },
    );

    test(
      'install log captures streamed output for the installing agent',
      () async {
        final env =
            _FakeEnvService(
                results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
              )
              ..installChunks.addAll([
                'added 12 packages\n',
                'downloading @openai/codex\n',
                'done\n',
              ]);
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([
              _agent('a1', 's1', install: 'install-cli'),
            ]),
          },
          envService: env,
        );
        addTearDown(container.dispose);
        await container.read(agentRegistryProvider.notifier).refresh();

        await container
            .read(agentRegistryProvider.notifier)
            .installForCurrentStatus('a1');

        final log = container.read(installLogProvider);
        expect(log.agentId, 'a1');
        expect(log.lines, [
          'added 12 packages',
          'downloading @openai/codex',
          'done',
        ]);
        expect(log.truncated, isFalse);
      },
    );

    test('install log reassembles lines split across chunks', () async {
      final env = _FakeEnvService(
        results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
      )..installChunks.addAll(['partial', ' line\nnext\n']);
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', install: 'install-cli'),
          ]),
        },
        envService: env,
      );
      addTearDown(container.dispose);
      await container.read(agentRegistryProvider.notifier).refresh();

      await container
          .read(agentRegistryProvider.notifier)
          .installForCurrentStatus('a1');

      expect(container.read(installLogProvider).lines, [
        'partial line',
        'next',
      ]);
    });

    test('installForCurrentStatus resets the log for each install', () async {
      final env = _FakeEnvService(
        results: {'a1': _kind(AgentEnvironmentStatusKind.cliMissing)},
      )..installChunks.add('first run\n');
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 's1', install: 'install-cli'),
          ]),
        },
        envService: env,
      );
      addTearDown(container.dispose);
      await container.read(agentRegistryProvider.notifier).refresh();

      final notifier = container.read(agentRegistryProvider.notifier);
      await notifier.installForCurrentStatus('a1');
      expect(container.read(installLogProvider).lines, ['first run']);

      env.installChunks
        ..clear()
        ..add('second run\n');
      await notifier.installForCurrentStatus('a1');

      final log = container.read(installLogProvider);
      expect(log.lines, ['second run']);
      expect(log.truncated, isFalse);
    });

    test('InstallLogNotifier caps output and flags truncation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(installLogProvider.notifier);

      notifier.start('a1');
      final overflow = InstallLogNotifier.maxLines + 10;
      for (var i = 0; i < overflow; i++) {
        notifier.append('line $i\n');
      }

      final log = container.read(installLogProvider);
      expect(log.lines.length, InstallLogNotifier.maxLines);
      expect(log.truncated, isTrue);
      // 保留的是最新的行。
      expect(log.lines.last, 'line ${overflow - 1}');
    });

    test('detects agents automatically when SSH becomes connected', () async {
      final env = _FakeEnvService();
      late _SwitchableConnection connection;
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
        },
        envService: env,
        connectionFactory: () => connection = _SwitchableConnection(
          ConnectionStateEnum.disconnected,
        ),
      );
      addTearDown(container.dispose);

      // 先读一次，让 registry 的 build() 完成注册（此时仍是断连）。
      container.read(agentRegistryProvider);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, isEmpty, reason: '断连时不该发起检测');

      connection.go(ConnectionStateEnum.connected);
      await pumpEventQueue();

      // 关键：全程没有手动调用 refresh()，检测必须由监听自动触发。
      expect(env.inspectedAgentIds, ['a1']);
    });

    test(
      're-detects on reconnect (connected -> connecting -> connected)',
      () async {
        final env = _FakeEnvService();
        late _SwitchableConnection connection;
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('s1')]),
            'valhalla_active_server_id_v1': 's1',
            'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
          },
          envService: env,
          connectionFactory: () => connection = _SwitchableConnection(
            ConnectionStateEnum.disconnected,
          ),
        );
        addTearDown(container.dispose);

        container.read(agentRegistryProvider);
        await pumpEventQueue();

        connection.go(ConnectionStateEnum.connected);
        await pumpEventQueue();
        expect(env.inspectedAgentIds, ['a1']);

        // 传输断开：重连控制器会把状态压回 connecting。
        connection.go(ConnectionStateEnum.connecting);
        await pumpEventQueue();

        // 重连成功：应当再检测一次，拿到的是新会话的环境状态。
        connection.go(ConnectionStateEnum.connected);
        await pumpEventQueue();

        expect(env.inspectedAgentIds, ['a1', 'a1']);
      },
    );
    test('retains runtime status when the connection drops', () async {
      final env = _FakeEnvService();
      late _SwitchableConnection connection;
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
        },
        envService: env,
        connectionFactory: () => connection = _SwitchableConnection(
          ConnectionStateEnum.disconnected,
        ),
      );
      addTearDown(container.dispose);

      container.read(agentRegistryProvider);
      await pumpEventQueue();
      connection.go(ConnectionStateEnum.connected);
      await pumpEventQueue();
      expect(
        container.read(agentRegistryProvider).findRuntime('a1')?.isReady,
        isTrue,
        reason: '连上后应已完成一次检测',
      );

      connection.go(ConnectionStateEnum.disconnected);
      await pumpEventQueue();
      await container.read(agentRegistryProvider.notifier).refresh();

      // 断连不是 agent 出错：缓存快照必须留着，也不许被盖上错误码。
      final runtime = container.read(agentRegistryProvider).findRuntime('a1');
      expect(runtime?.isReady, isTrue, reason: '断连保留最后一次检测快照');
      expect(
        runtime?.errorMessage,
        isNull,
        reason: '断连不得给缓存盖上 SSH_DISCONNECTED',
      );
      expect(env.inspectedAgentIds, ['a1'], reason: '断连后不得再发起检测');
      expect(container.read(agentRegistryProvider).isLoading, isFalse);

      // 快照不等于在线证明：真正要动远端的操作仍然单独校验连接。
      await container.read(agentRegistryProvider.notifier).installAgent('a1');
      await container.read(agentRegistryProvider.notifier).loginAgent('a1');
      expect(env.installedAgentIds, isEmpty, reason: '断连时不得执行安装');
      expect(env.loggedInAgentIds, isEmpty, reason: '断连时不得触发登录');
      expect(
        container.read(agentRegistryProvider).findRuntime('a1')?.errorMessage,
        AgentRegistryNotifier.disconnectedCode,
        reason: '用户主动发起的操作仍要给出可映射文案的 reason code',
      );
    });

    test('running refresh does not trigger a second detection', () async {
      final env = _FakeEnvService();
      late _SwitchableConnection connection;
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
        },
        envService: env,
        connectionFactory: () => connection = _SwitchableConnection(
          ConnectionStateEnum.disconnected,
        ),
      );
      addTearDown(container.dispose);

      container.read(agentRegistryProvider);
      await pumpEventQueue();

      connection.go(ConnectionStateEnum.connected);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, ['a1']);

      // refresh() 会把 isLoading 之类状态写回本 provider，这本身不是连接变化，
      // 不能再触发一轮检测（否则每次检测都会自激成无限循环）。
      await container.read(agentRegistryProvider.notifier).refresh();
      await pumpEventQueue();

      expect(env.inspectedAgentIds, ['a1', 'a1']);
    });

    test('does not re-detect while already connected', () async {
      final env = _FakeEnvService();
      late _SwitchableConnection connection;
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('s1')]),
          'valhalla_active_server_id_v1': 's1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 's1')]),
        },
        envService: env,
        connectionFactory: () => connection = _SwitchableConnection(
          ConnectionStateEnum.disconnected,
        ),
      );
      addTearDown(container.dispose);
      container.read(agentRegistryProvider);
      await pumpEventQueue();
      connection.go(ConnectionStateEnum.connected);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, ['a1']);

      // 已处于 connected 时再派发一次同值状态（列表刷新等会让上游重新发射），
      // 不应重复发起检测——否则每次无关键状态抖动都会多跑一轮全量检测。
      connection.go(ConnectionStateEnum.connected);
      await pumpEventQueue();

      expect(env.inspectedAgentIds, ['a1']);
    });

    test(
      'builds while already connected and inspects without any event',
      () async {
        final env = _FakeEnvService();
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('srv-1')]),
            'valhalla_active_server_id_v1': 'srv-1',
            'valhalla_agents_v1': _agentsPrefs([_agent('a1', 'srv-1')]),
          },
          envService: env,
          connected: true,
        );
        addTearDown(container.dispose);

        // Provider constructed late, long after the SSH link came up: there is
        // no connection *change* left to listen to, so the build-time
        // microtask is the only thing that can kick off detection.
        container.read(agentRegistryProvider);
        await pumpEventQueue();

        expect(env.inspectedAgentIds, ['a1']);
        expect(
          container.read(agentRegistryProvider).findRuntime('a1')?.isReady,
          isTrue,
        );

        // A plain re-read must not schedule a second round.
        container.read(agentRegistryProvider);
        await pumpEventQueue();
        expect(env.inspectedAgentIds, ['a1']);
      },
    );

    test('concurrent refresh() calls share one in-flight round', () async {
      final env = _FakeEnvService();
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('srv-1')]),
          'valhalla_active_server_id_v1': 'srv-1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 'srv-1'),
            _agent('a2', 'srv-1'),
          ]),
        },
        envService: env,
        connected: true,
      );
      addTearDown(container.dispose);
      final notifier = container.read(agentRegistryProvider.notifier);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, hasLength(2), reason: 'initial round');

      final first = notifier.refresh();
      final second = notifier.refresh();
      final third = notifier.refresh();
      expect(identical(first, second), isTrue, reason: 'shared future');
      expect(identical(second, third), isTrue, reason: 'shared future');

      await first;
      await pumpEventQueue();
      expect(
        env.inspectedAgentIds,
        hasLength(4),
        reason: 'one extra round for three concurrent calls',
      );

      // The gate is per-round: once it settles the next refresh runs again.
      await notifier.refresh();
      await pumpEventQueue();
      expect(env.inspectedAgentIds, hasLength(6));
    });

    test('concurrent refreshAgent() calls share one probe per agent', () async {
      final env = _FakeEnvService();
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('srv-1')]),
          'valhalla_active_server_id_v1': 'srv-1',
          'valhalla_agents_v1': _agentsPrefs([_agent('a1', 'srv-1')]),
        },
        envService: env,
        connected: true,
      );
      addTearDown(container.dispose);
      final notifier = container.read(agentRegistryProvider.notifier);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, ['a1']);

      final a = notifier.refreshAgent('a1');
      final b = notifier.refreshAgent('a1');
      expect(identical(a, b), isTrue, reason: 'the probe future is reused');
      await a;
      await pumpEventQueue();
      expect(env.inspectedAgentIds, ['a1', 'a1']);

      await notifier.refreshAgent('a1');
      await pumpEventQueue();
      expect(env.inspectedAgentIds, ['a1', 'a1', 'a1']);
    });

    test('updating one agent never rewrites or re-probes another', () async {
      final env = _FakeEnvService();
      final container = await _container(
        prefs: {
          'valhalla_servers_v1': _serversPrefs([_server('srv-1')]),
          'valhalla_active_server_id_v1': 'srv-1',
          'valhalla_agents_v1': _agentsPrefs([
            _agent('a1', 'srv-1'),
            _agent('a2', 'srv-1'),
          ]),
        },
        envService: env,
        connected: true,
      );
      addTearDown(container.dispose);
      final notifier = container.read(agentRegistryProvider.notifier);
      await pumpEventQueue();
      expect(env.inspectedAgentIds, hasLength(2));

      final beforeA2 = container.read(agentRegistryProvider).findRuntime('a2');
      expect(beforeA2!.profile.executionTarget, 'host');

      await notifier.updateAgent(
        _agent('a1', 'srv-1').copyWith(
          executionTarget: 'docker',
          containerBinding: 'name',
          containerReference: 'web.api',
        ),
      );
      await pumpEventQueue();

      final state = container.read(agentRegistryProvider);
      expect(
        state.findRuntime('a1')!.profile.executionTarget,
        'docker',
        reason: 'the edited target is what got saved',
      );
      expect(state.findRuntime('a2')!.profile.executionTarget, 'host');
      expect(
        identical(state.findRuntime('a2'), beforeA2),
        isTrue,
        reason: 'the untouched runtime object must be replaced by nothing',
      );
      expect(
        env.inspectedAgentIds.where((id) => id == 'a1'),
        hasLength(2),
        reason: 'once on the initial round, once after the edit',
      );
      expect(
        env.inspectedAgentIds.where((id) => id == 'a2'),
        hasLength(1),
        reason: 'the untouched agent is never re-probed',
      );
    });

    group('confirmAuthentication 成功后只清 AgY 认证类陈旧 detail', () {
      Future<(ProviderContainer, AgentRegistryNotifier, String, AgentProfile)>
      scenarioFor(String detail) async {
        final env = _FakeEnvService(
          results: {
            'a1': AgentEnvironmentStatus(
              kind: AgentEnvironmentStatusKind.ready,
              detail: detail,
              authentication: AgentAuthenticationStatus.unauthenticated,
              checkedAt: DateTime.utc(2026),
            ),
          },
        );
        final container = await _container(
          prefs: {
            'valhalla_servers_v1': _serversPrefs([_server('srv-1')]),
            'valhalla_active_server_id_v1': 'srv-1',
            'valhalla_agents_v1': _agentsPrefs([_agent('a1', 'srv-1')]),
          },
          envService: env,
          connected: true,
        );
        addTearDown(container.dispose);
        final notifier = container.read(agentRegistryProvider.notifier);
        await pumpEventQueue();
        final profile = container
            .read(agentRegistryProvider)
            .findRuntime('a1')!
            .profile;
        return (container, notifier, detail, profile);
      }

      for (final detail in const [
        'AGY_ACP_SIGN_IN_REQUIRED',
        'AGY_ACP_CREDENTIALS_NOT_VALIDATED',
        'AGY_AUTH_CHECK_UNAVAILABLE',
      ]) {
        test('认证成功后 $detail 被清除', () async {
          final (container, notifier, _, profile) = await scenarioFor(detail);

          await notifier.confirmAuthentication(profile);
          await pumpEventQueue();

          final runtime = container
              .read(agentRegistryProvider)
              .findRuntime('a1')!;
          expect(
            runtime.status.detail,
            isNull,
            reason: '官方 RPC 成功后不得再显示需要登录/未验证',
          );
          expect(
            runtime.status.authentication,
            AgentAuthenticationStatus.authenticated,
          );
        });
      }

      test('非认证类 detail 保留（不得顺手抹掉安装/连接失败）', () async {
        final (container, notifier, _, profile) = await scenarioFor(
          'AGY_AUTH_CHECK_INVALID',
        );

        await notifier.confirmAuthentication(profile);
        await pumpEventQueue();

        final runtime = container
            .read(agentRegistryProvider)
            .findRuntime('a1')!;
        expect(
          runtime.status.detail,
          'AGY_AUTH_CHECK_INVALID',
          reason: '只清理三类陈旧认证 detail，其余原样保留',
        );
        expect(
          runtime.status.authentication,
          AgentAuthenticationStatus.authenticated,
        );
      });
    });
  });
}

class _FailingInstallEnvService extends _FakeEnvService {
  _FailingInstallEnvService({super.results}) : super();

  @override
  Future<SSHExecutionResult> runInstall(
    AgentProfile profile,
    String serverId,
  ) async {
    installedAgentIds.add(profile.id);
    return const SSHExecutionResult(
      exitCode: 1,
      stdout: '',
      stderr: 'boom token=abc123',
    );
  }

  @override
  Future<SSHExecutionResult> runInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) async {
    installedAgentIds.add(profile.id);
    return const SSHExecutionResult(
      exitCode: 1,
      stdout: '',
      stderr: 'boom token=abc123',
    );
  }

  @override
  Stream<String> streamInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) async* {
    installedAgentIds.add(profile.id);
    yield 'boom token=abc123\n';
  }

  @override
  Future<AgentEnvironmentStatus> inspect(
    AgentProfile profile,
    String serverId, {
    bool requireAcp = true,
  }) async {
    inspectedAgentIds.add(profile.id);
    return _kind(AgentEnvironmentStatusKind.error);
  }
}
