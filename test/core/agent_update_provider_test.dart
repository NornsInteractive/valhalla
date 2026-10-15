import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/agent_update_lock_provider.dart';
import 'package:valhalla/core/providers/agent_update_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/agents/agent_update_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _FakeSsh implements SshCommandExecutor {
  bool connected = true;
  @override
  bool isConnected(String serverId) => connected;
  @override
  SSHClient? getClient(String serverId) => null;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 25),
    String? sudoPassword,
  }) => throw StateError('Provider fixture must never run SSH commands');
  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 25),
    String? sudoPassword,
  }) => throw StateError(
    'Provider fixture must never mutate remote installations',
  );
}

class _FakeService extends AgentUpdateService {
  _FakeService(super.ssh, this.clock);
  final DateTime Function() clock;
  int checkCalls = 0;
  int prepareCalls = 0;
  int applyCalls = 0;
  int maxConcurrent = 0;
  int concurrent = 0;
  String latestVersion = '2.0.0';
  bool componentError = false;
  AgentUpdateException? checkError;
  AgentUpdateException? applyError;
  Completer<void>? checkGate;
  Completer<void>? applyGate;
  Completer<void>? applyEntered;
  void Function()? onCheck;
  final checkedTargets = <(String, String)>[];

  AgentUpdateReport _report(AgentProfile profile, ServerProfile server) =>
      AgentUpdateReport(
        agentId: profile.id,
        targetKey: agentUpdateTargetKey(server, profile),
        checkedAt: clock(),
        components: [
          AgentComponentUpdate(
            component: AgentUpdateComponent.cli,
            status: componentError
                ? AgentUpdateStatus.error
                : AgentUpdateStatus.available,
            installedVersion: '1.0.0',
            latestVersion: latestVersion,
            command: componentError ? null : 'fixture-only-update',
            reasonCode: componentError ? 'AGENT_UPDATE_CATALOG_FAILED' : null,
          ),
        ],
      );

  @override
  Future<AgentUpdateReport> check(
    ServerProfile server,
    AgentProfile profile, {
    bool force = false,
  }) async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    checkCalls++;
    checkedTargets.add((server.id, profile.id));
    final response = _report(profile, server);
    final error = checkError;
    final gate = checkGate;
    onCheck?.call();
    try {
      if (gate != null) await gate.future;
      if (error != null) throw error;
      return response;
    } finally {
      concurrent--;
    }
  }

  @override
  Future<AgentUpdatePlan> prepare(
    ServerProfile server,
    AgentProfile profile, {
    Set<AgentUpdateComponent>? components,
  }) async {
    prepareCalls++;
    return AgentUpdatePlan(
      server: server,
      profile: profile,
      targetKey: agentUpdateTargetKey(server, profile),
      preparedAt: clock(),
      runtimeIdentity: 'fixture-identity',
      components: _report(profile, server).components,
    );
  }

  @override
  Future<AgentProfile> apply(
    AgentUpdatePlan plan, {
    required bool Function() isCurrent,
    required void Function(String) onLog,
  }) async {
    applyCalls++;
    applyEntered?.complete();
    if (applyGate != null) await applyGate!.future;
    if (applyError != null) throw applyError!;
    return plan.profile;
  }
}

ServerProfile _server(String id) =>
    ServerProfile(id: id, name: id, host: '$id.invalid', username: 'dev');
AgentProfile _agent(String id, [String serverId = 's1']) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
  description: '',
  cliCommand: 'fixture-cli',
  acpCommand: 'fixture-acp',
);

class _Connection extends ServerConnectionNotifier {
  _Connection(this.connected);
  bool connected;
  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: ref.read(activeServerProvider)?.id,
  );
  void go(bool value) {
    connected = value;
    state = ServerConnectionState(
      status: value
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
      activeServerId: ref.read(activeServerProvider)?.id,
    );
  }

  @override
  void disconnect() => go(false);
}

/// No eager environment probe, timers, network or real runtime providers.
class _Registry extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() {
    final server = ref.watch(activeServerProvider);
    return AgentRegistryState(
      serverId: server?.id,
      agents: [
        if (server != null)
          for (final profile
              in ref.read(agentRepositoryProvider).getAll(server.id))
            AgentRuntimeState(
              profile: profile,
              status: AgentEnvironmentStatus.unknown(),
            ),
      ],
    );
  }

  void synchronize() => state = build();
  void busy({bool installing = false, bool loggingIn = false}) {
    state = state.copyWith(
      agents: [
        for (final entry in state.agents)
          entry.copyWith(isInstalling: installing, isLoggingIn: loggingIn),
      ],
    );
  }

  @override
  Future<void> refreshAgent(String agentId) async {}
}

/// Mount only immutable chat state; never start history, SSH, timers or agents.
class _StateOnlyAiChat extends AiChatNotifier {
  _StateOnlyAiChat(this.initial);
  final AiChatState initial;

  @override
  AiChatState build() => initial;

  void show(AiChatState next) => state = next;
}

class _StateOnlyCliChat extends CliChatNotifier {
  _StateOnlyCliChat(this.initial);
  final CliChatState initial;

  @override
  CliChatState build() => initial;

  void show(CliChatState next) => state = next;
}

Future<LocalStorageService> _storage([List<AgentProfile>? agents]) async {
  SharedPreferences.setMockInitialValues({
    'valhalla_servers_v1': jsonEncode(
      [_server('s1'), _server('s2')].map((s) => s.toJson()).toList(),
    ),
    'valhalla_active_server_id_v1': 's1',
    'valhalla_agents_v1': jsonEncode(
      (agents ?? [_agent('a1')]).map((a) => a.toJson()).toList(),
    ),
  });
  return LocalStorageService(await SharedPreferences.getInstance());
}

ProviderContainer _container(
  LocalStorageService storage,
  _FakeSsh ssh,
  _FakeService service, {
  _Connection? connection,
  _StateOnlyAiChat? acp,
  _StateOnlyCliChat? cli,
}) => ProviderContainer(
  overrides: [
    localStorageServiceProvider.overrideWithValue(storage),
    serverConnectionProvider.overrideWith(
      () => connection ?? _Connection(ssh.connected),
    ),
    agentRegistryProvider.overrideWith(_Registry.new),
    sshCommandExecutorProvider.overrideWithValue(ssh),
    agentUpdateServiceProvider.overrideWithValue(service),
    agentUpdateClockProvider.overrideWithValue(service.clock),
    if (acp != null) aiChatProvider.overrideWith(() => acp),
    if (cli != null) cliChatProvider.overrideWith(() => cli),
  ],
);

Matcher _error(String code) =>
    isA<AgentUpdateException>().having((error) => error.code, 'code', code);

void main() {
  final day = DateTime(2026, 10, 15, 10);

  test(
    'mount is inert; first entry checks all and only current-server added agents',
    () async {
      final storage = await _storage([
        _agent('a1'),
        _agent('a2'),
        _agent('foreign', 's2'),
      ]);
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => day);
      final container = _container(storage, ssh, service);
      addTearDown(container.dispose);
      expect(container.read(agentUpdatesProvider).noticeCount, 0);
      expect(service.checkCalls, 0);
      await container.read(agentUpdatesProvider.notifier).onChatEntered();
      expect(
        service.checkedTargets,
        unorderedEquals([('s1', 'a1'), ('s1', 'a2')]),
      );
      expect(service.applyCalls, 0);
    },
  );

  test('daily success survives restart; a new day checks again', () async {
    var now = day;
    final storage = await _storage();
    final ssh = _FakeSsh();
    final service = _FakeService(ssh, () => now);
    final first = _container(storage, ssh, service);
    await first.read(agentUpdatesProvider.notifier).onChatEntered();
    await first.read(agentUpdatesProvider.notifier).onChatEntered();
    expect(service.checkCalls, 1);
    first.dispose();
    final restarted = _container(storage, ssh, service);
    addTearDown(restarted.dispose);
    await restarted.read(agentUpdatesProvider.notifier).onChatEntered();
    expect(service.checkCalls, 1);
    now = now.add(const Duration(days: 1));
    await restarted.read(agentUpdatesProvider.notifier).checkIfDue();
    expect(service.checkCalls, 2);
  });

  test(
    'failed probe waits 15 minutes; manual force bypasses backoff',
    () async {
      var now = day;
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => now)
        ..checkError = const AgentUpdateException('PROBE_FAILURE');
      final container = _container(storage, ssh, service);
      addTearDown(container.dispose);
      final notifier = container.read(agentUpdatesProvider.notifier);
      await notifier.onChatEntered();
      now = day.add(const Duration(minutes: 14, seconds: 59));
      await notifier.checkIfDue();
      expect(service.checkCalls, 1);
      now = day.add(const Duration(minutes: 15));
      await notifier.checkIfDue();
      expect(service.checkCalls, 2);
      await notifier.checkAgent('a1', force: true);
      expect(service.checkCalls, 3);
      expect(
        container.read(agentUpdatesProvider).agents['a1']!.errorCode,
        'PROBE_FAILURE',
      );
    },
  );

  test('offline entry consumes no day and reconnect triggers check', () async {
    final storage = await _storage();
    final ssh = _FakeSsh()..connected = false;
    final service = _FakeService(ssh, () => day);
    final connection = _Connection(false);
    final container = _container(storage, ssh, service, connection: connection);
    addTearDown(container.dispose);
    await container.read(agentUpdatesProvider.notifier).onChatEntered();
    expect(service.checkCalls, 0);
    final entered = Completer<void>();
    service.onCheck = () => entered.complete();
    ssh.connected = true;
    connection.go(true);
    await entered.future;
    await container.read(agentUpdatesProvider.notifier).checkAgent('a1');
    expect(service.checkCalls, 1);
  });

  test(
    'notice acknowledgement survives restart, but new version/day can alert',
    () async {
      var now = day;
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => now);
      final first = _container(storage, ssh, service);
      final notifier = first.read(agentUpdatesProvider.notifier);
      await notifier.onChatEntered();
      expect(first.read(agentUpdatesProvider).noticeCount, 1);
      await notifier.dismissUpdateNotice();
      expect(first.read(agentUpdatesProvider).noticeCount, 0);
      final key = agentUpdateTargetKey(_server('s1'), _agent('a1'));
      expect(
        storage.getAgentUpdateRecord(key)!['noticeAcknowledgedVersions'],
        'cli:2.0.0',
      );
      first.dispose();
      final restarted = _container(storage, ssh, service);
      addTearDown(restarted.dispose);
      expect(restarted.read(agentUpdatesProvider).noticeCount, 0);
      final next = restarted.read(agentUpdatesProvider.notifier);
      await next.onChatEntered();
      expect(service.checkCalls, 1);
      expect(restarted.read(agentUpdatesProvider).noticeCount, 0);
      service.latestVersion = '2.1.0';
      await next.checkAgent('a1');
      expect(restarted.read(agentUpdatesProvider).noticeCount, 1);
      await next.dismissUpdateNotice();
      now = now.add(const Duration(days: 1));
      await next.checkIfDue();
      expect(restarted.read(agentUpdatesProvider).noticeCount, 1);
    },
  );

  test(
    'explicit plan is one-use; aliases on same server share mutation lock',
    () async {
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => day);
      final container = _container(storage, ssh, service);
      addTearDown(container.dispose);
      final notifier = container.read(agentUpdatesProvider.notifier);
      final plan = await notifier.prepareUpdate('a1');
      expect(service.applyCalls, 0);
      final locks = container.read(agentUpdateLockProvider.notifier);
      expect(locks.acquire(_agent('different-card')), isTrue);
      await expectLater(
        notifier.applyConfirmedUpdate(plan),
        throwsA(_error('AGENT_UPDATE_BUSY')),
      );
      expect(service.applyCalls, 0);
      locks.release(_agent('different-card'));
      await notifier.applyConfirmedUpdate(plan);
      expect(service.applyCalls, 1);
      expect(container.read(agentUpdateLockProvider), isEmpty);
      await expectLater(
        notifier.applyConfirmedUpdate(plan),
        throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
      );
      expect(service.applyCalls, 1);
    },
  );

  test(
    'registry install/login blocks plan preparation and confirmed application',
    () async {
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => day);
      final container = _container(storage, ssh, service);
      addTearDown(container.dispose);
      final notifier = container.read(agentUpdatesProvider.notifier);
      final registry =
          container.read(agentRegistryProvider.notifier) as _Registry;
      registry.busy(installing: true);
      await expectLater(
        notifier.prepareUpdate('a1'),
        throwsA(_error('AGENT_UPDATE_BUSY')),
      );
      registry.busy();
      final plan = await notifier.prepareUpdate('a1');
      registry.busy(loggingIn: true);
      await expectLater(
        notifier.applyConfirmedUpdate(plan),
        throwsA(_error('AGENT_UPDATE_BUSY')),
      );
      expect(service.applyCalls, 0);
      expect(container.read(agentUpdateLockProvider), isEmpty);
    },
  );

  final alias = _agent('same-server-alias');
  final busyCases = <({String name, AiChatState? acp, CliChatState? cli})>[
    (
      name: 'ACP generating',
      acp: AiChatState(activeAgentProfile: alias, isGenerating: true),
      cli: null,
    ),
    (
      name: 'ACP awaiting permission',
      acp: AiChatState(
        activeAgentProfile: alias,
        pendingPermission: const PermissionRequest(
          id: 'fixture-approval',
          toolName: 'fixture-tool',
          command: 'not-executed',
          description: 'Waiting for a user decision',
        ),
      ),
      cli: null,
    ),
    (
      name: 'CLI sending',
      acp: null,
      cli: CliChatState(serverId: 's1', activeAgent: alias, isSending: true),
    ),
    (
      name: 'CLI interactive terminal',
      acp: null,
      cli: CliChatState(
        serverId: 's1',
        activeAgent: alias,
        terminal: Terminal(maxLines: 10),
      ),
    ),
  ];
  for (final busy in busyCases) {
    test(
      '${busy.name} on a server alias blocks prepare and apply without mutation',
      () async {
        final storage = await _storage([_agent('a1'), alias]);
        final ssh = _FakeSsh();
        final service = _FakeService(ssh, () => day);
        final acp = busy.acp == null
            ? null
            : _StateOnlyAiChat(AiChatState(activeAgentProfile: alias));
        final cli = busy.cli == null
            ? null
            : _StateOnlyCliChat(
                CliChatState(serverId: 's1', activeAgent: alias),
              );
        final container = _container(storage, ssh, service, acp: acp, cli: cli);
        addTearDown(container.dispose);
        if (acp != null) container.read(aiChatProvider);
        if (cli != null) container.read(cliChatProvider);
        final notifier = container.read(agentUpdatesProvider.notifier);
        // User prepared this plan while idle, but a different card sharing the
        // same server started work before they confirmed it.
        final plan = await notifier.prepareUpdate('a1');
        expect(service.prepareCalls, 1);
        acp?.show(busy.acp!);
        cli?.show(busy.cli!);

        await expectLater(
          notifier.prepareUpdate('a1'),
          throwsA(_error('AGENT_UPDATE_BUSY')),
        );
        expect(
          service.prepareCalls,
          1,
          reason: 'Busy preflight cannot probe or prepare an update',
        );
        await expectLater(
          notifier.applyConfirmedUpdate(plan),
          throwsA(_error('AGENT_UPDATE_BUSY')),
        );
        expect(
          service.applyCalls,
          0,
          reason: 'No update command may run during active work',
        );
        expect(container.read(agentUpdateLockProvider), isEmpty);
        if (acp != null) expect(container.read(aiChatProvider), same(busy.acp));
        if (cli != null) {
          expect(container.read(cliChatProvider), same(busy.cli));
        }
      },
    );
  }

  for (final componentFailure in [false, true]) {
    test(
      'interrupted recovery preserves marker and restart backoff: component=$componentFailure',
      () async {
        var now = day;
        final storage = await _storage();
        final profile = _agent('a1');
        final key = agentUpdateTargetKey(_server('s1'), profile);
        await storage.saveAgentUpdateRecord(key, {
          'schema': 1,
          'interrupted': true,
          'lastAttemptAt': day.toIso8601String(),
          'errorCode': null,
          'components': [],
        });
        final ssh = _FakeSsh();
        final service = _FakeService(ssh, () => now)
          ..componentError = componentFailure
          ..checkError = componentFailure
              ? null
              : const AgentUpdateException('PROBE_FAILURE');
        final first = _container(storage, ssh, service);
        await first.read(agentUpdatesProvider.notifier).onChatEntered();
        expect(
          service.checkCalls,
          1,
          reason: 'Interrupted marker gets an immediate first recovery probe',
        );
        expect(
          first.read(agentUpdatesProvider).agents['a1']!.interrupted,
          isTrue,
        );
        expect(storage.getAgentUpdateRecord(key)!['interrupted'], isTrue);
        expect(
          storage.getAgentUpdateRecord(key)!['errorCode'],
          componentFailure ? 'AGENT_UPDATE_CHECK_FAILED' : 'PROBE_FAILURE',
        );
        first.dispose();
        final restarted = _container(storage, ssh, service);
        addTearDown(restarted.dispose);
        now = day.add(const Duration(minutes: 14));
        await restarted.read(agentUpdatesProvider.notifier).onChatEntered();
        expect(service.checkCalls, 1);
        expect(
          restarted.read(agentUpdatesProvider).agents['a1']!.interrupted,
          isTrue,
        );
        now = day.add(const Duration(minutes: 15));
        service.checkError = null;
        service.componentError = false;
        await restarted.read(agentUpdatesProvider.notifier).checkIfDue();
        expect(service.checkCalls, 2);
        expect(
          restarted.read(agentUpdatesProvider).agents['a1']!.interrupted,
          isFalse,
        );
        expect(storage.getAgentUpdateRecord(key)!['interrupted'], isFalse);
        expect(
          service.applyCalls,
          0,
          reason: 'Recovery must never replay an update',
        );
      },
    );
  }

  test('two probe slots and same-agent in-flight coalescing', () async {
    final storage = await _storage([_agent('a1'), _agent('a2'), _agent('a3')]);
    final ssh = _FakeSsh();
    final gate = Completer<void>();
    final entered = Completer<void>();
    final service = _FakeService(ssh, () => day)..checkGate = gate;
    service.onCheck = () {
      if (service.checkCalls == 2) entered.complete();
    };
    final container = _container(storage, ssh, service);
    addTearDown(container.dispose);
    final notifier = container.read(agentUpdatesProvider.notifier);
    final all = notifier.onChatEntered();
    final duplicate = notifier.checkAgent('a1');
    await entered.future;
    expect(service.concurrent, 2);
    expect(service.checkCalls, 2);
    gate.complete();
    await Future.wait([all, duplicate]);
    expect(service.maxConcurrent, 2);
    expect(service.checkCalls, 3);
  });

  for (final returnDuringUpdate in [false, true]) {
    test(
      'old probe cannot overwrite update state: returns during=$returnDuringUpdate',
      () async {
        final storage = await _storage();
        final ssh = _FakeSsh();
        final oldGate = Completer<void>();
        final probeEntered = Completer<void>();
        final service = _FakeService(ssh, () => day)
          ..checkGate = oldGate
          ..onCheck = () => probeEntered.complete();
        final container = _container(storage, ssh, service);
        addTearDown(container.dispose);
        final notifier = container.read(agentUpdatesProvider.notifier);
        final oldCheck = notifier.checkAgent('a1');
        await probeEntered.future;
        service.onCheck = null;
        service.checkGate = null;
        service.latestVersion = '3.0.0';
        service.applyGate = Completer<void>();
        service.applyEntered = Completer<void>();
        final plan = await notifier.prepareUpdate('a1');
        final apply = notifier.applyConfirmedUpdate(plan);
        await service.applyEntered!.future;
        if (returnDuringUpdate) {
          oldGate.complete();
          await oldCheck;
          expect(
            container.read(agentUpdatesProvider).agents['a1']!.isUpdating,
            isTrue,
          );
          expect(
            storage.getAgentUpdateRecord(plan.targetKey)!['interrupted'],
            isTrue,
          );
        }
        service.applyGate!.complete();
        await apply;
        if (!returnDuringUpdate) {
          oldGate.complete();
          await oldCheck;
        }
        final entry = container.read(agentUpdatesProvider).agents['a1']!;
        expect(entry.isUpdating, isFalse);
        expect(entry.interrupted, isFalse);
        expect(entry.report!.components.single.latestVersion, '3.0.0');
        expect(
          storage.getAgentUpdateRecord(plan.targetKey)!['interrupted'],
          isFalse,
        );
      },
    );
  }

  test(
    'edited target has independent daily cache and invalidates old confirmation',
    () async {
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => day);
      final container = _container(storage, ssh, service);
      addTearDown(container.dispose);
      final notifier = container.read(agentUpdatesProvider.notifier);
      await notifier.onChatEntered();
      final plan = await notifier.prepareUpdate('a1');
      final edited = _agent('a1').copyWith(
        executionTarget: 'docker',
        containerReference: 'new-container',
      );
      await container.read(agentRepositoryProvider).save(edited);
      (container.read(agentRegistryProvider.notifier) as _Registry)
          .synchronize();
      await notifier.checkIfDue();
      expect(service.checkCalls, 2);
      expect(
        container.read(agentUpdatesProvider).agents['a1']!.targetKey,
        agentUpdateTargetKey(_server('s1'), edited),
      );
      await expectLater(
        notifier.applyConfirmedUpdate(plan),
        throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
      );
      expect(service.applyCalls, 0);
    },
  );

  test(
    'disposing updater while apply is pending releases still-alive parent lease',
    () async {
      final storage = await _storage();
      final ssh = _FakeSsh();
      final service = _FakeService(ssh, () => day)
        ..applyGate = Completer<void>()
        ..applyEntered = Completer<void>();
      final parent = _container(storage, ssh, service);
      addTearDown(parent.dispose);
      // The lock belongs to parent and survives the child's destruction.
      final parentLocks = parent.read(agentUpdateLockProvider.notifier);
      final child = ProviderContainer(
        parent: parent,
        overrides: [
          agentUpdatesProvider.overrideWith(AgentUpdatesNotifier.new),
        ],
      );
      final notifier = child.read(agentUpdatesProvider.notifier);
      expect(
        identical(parentLocks, child.read(agentUpdateLockProvider.notifier)),
        isTrue,
      );
      final plan = await notifier.prepareUpdate('a1');
      final pending = notifier.applyConfirmedUpdate(plan);
      final observed = expectLater(
        pending,
        throwsA(_error('AGENT_UPDATE_TARGET_CHANGED')),
      );
      await service.applyEntered!.future;
      expect(parent.read(agentUpdateLockProvider), {'server:s1'});
      expect(
        storage.getAgentUpdateRecord(plan.targetKey)!['interrupted'],
        isTrue,
      );
      child.dispose();
      expect(parent.read(agentUpdateLockProvider), {'server:s1'});
      service.applyGate!.complete();
      await observed;
      expect(parent.read(agentUpdateLockProvider), isEmpty);
      expect(
        parentLocks.acquire(plan.profile),
        isTrue,
        reason: 'Shared lease must remain reusable',
      );
      parentLocks.release(plan.profile);
      expect(
        storage.getAgentUpdateRecord(plan.targetKey)!['interrupted'],
        isTrue,
      );
      expect(service.applyCalls, 1);
    },
  );

  test('failed update retains interrupted marker and releases lock', () async {
    final storage = await _storage();
    final ssh = _FakeSsh();
    final service = _FakeService(ssh, () => day)
      ..applyError = const AgentUpdateException('FIXTURE_EXECUTION_FAILURE');
    final container = _container(storage, ssh, service);
    addTearDown(container.dispose);
    final notifier = container.read(agentUpdatesProvider.notifier);
    final plan = await notifier.prepareUpdate('a1');
    await expectLater(
      notifier.applyConfirmedUpdate(plan),
      throwsA(_error('FIXTURE_EXECUTION_FAILURE')),
    );
    expect(service.applyCalls, 1);
    expect(
      container.read(agentUpdatesProvider).agents['a1']!.interrupted,
      isTrue,
    );
    expect(
      storage.getAgentUpdateRecord(plan.targetKey)!['interrupted'],
      isTrue,
    );
    expect(container.read(agentUpdateLockProvider), isEmpty);
  });
}
