import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/server_power_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'a',
  name: 'A',
  host: 'host-a',
  username: 'user',
);

class _Active extends ActiveServerNotifier {
  void touch() {
    state = state!.copyWith(lastConnectedAt: DateTime.now());
  }

  @override
  ServerProfile? build() => _server;
  void change(String id) {
    state = ServerProfile(id: id, name: id, host: 'host-$id', username: 'user');
  }
}

class _Connected extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'a',
  );
}

class _Agents extends AgentRegistryNotifier {
  void useServer(String server) {
    state = AgentRegistryState(
      serverId: server,
      agents: [runtime('codex', 'codex', server: server)],
    );
  }

  static AgentRuntimeState runtime(
    String id,
    String cli, {
    String server = 'a',
  }) => AgentRuntimeState(
    profile: AgentProfile(
      id: id,
      serverId: server,
      name: id,
      description: '',
      cliCommand: cli,
    ),
    status: AgentEnvironmentStatus.unknown(),
  );
  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'a',
    agents: [
      runtime('codex', 'codex'),
      runtime('agy', 'agy'),
      runtime('foreign', 'agy', server: 'b'),
    ],
  );
  void recheck() {
    state = state.copyWith(agents: [...state.agents]);
  }
}

class _Session implements SSHSession {
  final input = StreamController<Uint8List>();
  final output = StreamController<Uint8List>();
  final errors = StreamController<Uint8List>();
  final calls = <Map<String, dynamic>>[];
  bool closed = false;
  final int historyMessageCount;
  _Session({this.historyMessageCount = 0}) {
    input.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final request = jsonDecode(line) as Map<String, dynamic>;
          calls.add(request);
          if (!request.containsKey('id')) return;
          final method = request['method'];
          final result = switch (method) {
            'thread/list' => {
              'data': [
                {'id': 'native-old', 'preview': 'Original', 'cwd': '/project'},
              ],
              'nextCursor': 'next',
            },
            'thread/items/list' => () {
              final params = request['params'] as Map;
              final offset =
                  int.tryParse(params['cursor']?.toString() ?? '') ?? 0;
              final limit = params['limit'] as int;
              final indexes = List.generate(
                historyMessageCount,
                (index) => historyMessageCount - index - 1,
              ).skip(offset).take(limit).toList();
              return {
                'data': [
                  for (final index in indexes)
                    {
                      'turnId': 'turn-$index',
                      'item': {
                        'id': 'history-$index',
                        'type': index.isEven ? 'userMessage' : 'agentMessage',
                        if (index.isEven)
                          'content': [
                            {'type': 'text', 'text': 'message $index'},
                          ]
                        else
                          'text': 'message $index',
                      },
                    },
                ],
                'nextCursor': offset + indexes.length < historyMessageCount
                    ? '${offset + indexes.length}'
                    : null,
              };
            }(),
            'thread/read' => {
              'thread': {
                'id': 'native-old',
                'status': {'type': 'idle'},
                'turns': List.generate(
                  historyMessageCount,
                  (index) => {
                    'items': [
                      {
                        'id': 'history-$index',
                        'type': index.isEven ? 'userMessage' : 'agentMessage',
                        if (index.isEven)
                          'content': [
                            {'type': 'text', 'text': 'message $index'},
                          ]
                        else
                          'text': 'message $index',
                      },
                    ],
                  },
                ),
              },
            },
            'thread/start' => {
              'thread': {
                'id': 'native-new',
                'preview': 'New',
                'cwd': '/project',
              },
            },
            'turn/start' => {
              'turn': {'id': 'turn-1'},
            },
            _ => <String, dynamic>{},
          };
          output.add(
            utf8.encode(
              '${jsonEncode({'id': request['id'], 'result': result})}\n',
            ),
          );
        });
  }
  void approval() {
    output.add(
      utf8.encode(
        '${jsonEncode({
          'id': 'approve-1',
          'method': 'item/commandExecution/requestApproval',
          'params': {'threadId': 'native-new', 'itemId': 'tool-1', 'command': 'ls'},
        })}\n',
      ),
    );
  }

  void finish() {
    output.add(
      utf8.encode(
        '${jsonEncode({
          'method': 'turn/completed',
          'params': {
            'threadId': 'native-new',
            'turn': {'status': 'completed'},
          },
        })}\n',
      ),
    );
  }

  @override
  StreamSink<Uint8List> get stdin => input.sink;
  @override
  Stream<Uint8List> get stdout => output.stream;
  @override
  Stream<Uint8List> get stderr => errors.stream;
  @override
  void close() {
    if (closed) return;
    closed = true;
    unawaited(input.close());
    unawaited(output.close());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Ssh implements SSHClient {
  final sessions = <_Session>[];
  final int historyMessageCount;
  _Ssh({this.historyMessageCount = 0});
  @override
  bool get isClosed => false;
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    final session = _Session(historyMessageCount: historyMessageCount);
    sessions.add(session);
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Executor implements SshCommandExecutor {
  String bootId = '11111111-1111-4111-8111-111111111111';
  final _Ssh ssh;
  _Executor({int historyMessageCount = 0})
    : ssh = _Ssh(historyMessageCount: historyMessageCount);
  final commands = <String>[];
  final pending = <String, Completer<SSHExecutionResult>>{};
  bool deleteFails = false;
  @override
  bool isConnected(String id) => true;
  @override
  SSHClient? getClient(String id) => ssh;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String id,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add('$id:$command');
    if (command == 'id -u') {
      return const SSHExecutionResult(exitCode: 0, stdout: '0', stderr: '');
    }
    if (command.startsWith('cat /proc/')) {
      return SSHExecutionResult(exitCode: 0, stdout: bootId, stderr: '');
    }
    if (pending.containsKey(command)) return pending[command]!.future;
    if (command.contains('delete --help')) {
      return const SSHExecutionResult(
        exitCode: 0,
        stdout: 'Usage: codex delete [OPTIONS] <SESSION>\n      --force',
        stderr: '',
      );
    }
    return SSHExecutionResult(
      exitCode:
          deleteFails &&
              command.contains(' delete ') &&
              !command.contains('--help')
          ? 1
          : 0,
      stdout: command.contains('command -v')
          ? '/usr/bin/codex'
          : command.startsWith('docker inspect')
          ? '[{}]'
          : '',
      stderr: '',
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<ProviderContainer> _container(_Executor executor) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [
      activeServerProvider.overrideWith(_Active.new),
      serverConnectionProvider.overrideWith(_Connected.new),
      agentRegistryProvider.overrideWith(_Agents.new),
      sshCommandExecutorProvider.overrideWithValue(executor),
      localStorageServiceProvider.overrideWithValue(storage),
    ],
  );
}

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'reboot does not repeat accepted dispatch, survives reconnect metadata and verifies changed boot identity',
    () async {
      final executor = _Executor();
      final container = await _container(executor);
      addTearDown(container.dispose);
      final subscription = container.listen(serverPowerProvider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = container.read(serverPowerProvider.notifier);
      await notifier.reboot(expectedServerId: 'a', sudoPassword: 'temp');
      expect(
        container.read(serverPowerProvider).phase,
        ServerPowerPhase.accepted,
      );
      await notifier.reboot(expectedServerId: 'a', sudoPassword: 'temp');
      expect(
        executor.commands.where((c) => c.contains('systemctl reboot')),
        hasLength(1),
      );
      (container.read(activeServerProvider.notifier) as _Active).touch();
      await _drain();
      expect(
        container.read(serverPowerProvider).phase,
        ServerPowerPhase.accepted,
      );
      await notifier.verifyReboot();
      expect(
        container.read(serverPowerProvider).phase,
        ServerPowerPhase.accepted,
      );
      executor.bootId = '22222222-2222-4222-8222-222222222222';
      await notifier.verifyReboot();
      expect(
        container.read(serverPowerProvider).phase,
        ServerPowerPhase.verified,
      );
    },
  );
  test('shutdown is not reboot-verified and cannot dispatch twice', () async {
    final executor = _Executor();
    final container = await _container(executor);
    addTearDown(container.dispose);
    final subscription = container.listen(serverPowerProvider, (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(serverPowerProvider.notifier);
    await notifier.shutdown(expectedServerId: 'a', sudoPassword: 'temp');
    expect(
      container.read(serverPowerProvider).action,
      ServerPowerAction.shutdown,
    );
    expect(
      container.read(serverPowerProvider).phase,
      ServerPowerPhase.accepted,
    );
    await notifier.shutdown(expectedServerId: 'a', sudoPassword: 'temp');
    expect(
      executor.commands.where(
        (command) => command.contains('systemctl poweroff'),
      ),
      hasLength(1),
    );
    executor.bootId = '22222222-2222-4222-8222-222222222222';
    await notifier.verifyReboot();
    expect(
      container.read(serverPowerProvider).phase,
      ServerPowerPhase.accepted,
    );
  });
  test(
    'CLI selects native history without creating; first draft send creates exactly once; approval uses Codex payload',
    () async {
      final executor = _Executor();
      final container = await _container(executor);
      addTearDown(container.dispose);
      final notifier = container.read(cliChatProvider.notifier);
      expect(container.read(cliChatProvider).agents.map((a) => a.id), [
        'codex',
        'agy',
      ]);
      await notifier.selectAgent('codex');
      final process = executor.ssh.sessions.single;
      expect(process.calls.any((c) => c['method'] == 'thread/start'), isFalse);
      await notifier.selectSession('native-old');
      notifier.createDraft();
      expect(container.read(cliChatProvider).activeSession, isNull);
      expect(process.calls.any((c) => c['method'] == 'thread/start'), isFalse);
      await notifier.sendMessage('Hello');
      await notifier.sendMessage('duplicate');
      expect(
        process.calls.where((c) => c['method'] == 'thread/start'),
        hasLength(1),
      );
      expect(
        process.calls.where((c) => c['method'] == 'turn/start'),
        hasLength(1),
      );
      process.approval();
      await _drain();
      final approval = container.read(cliChatProvider).approvals.single;
      await notifier.respondApproval(approval.id, true);
      await _drain();
      expect(
        process.calls.where((c) => c['id'] == 'approve-1').single['result'],
        {'decision': 'accept'},
      );
      process.finish();
      await _drain();
      expect(container.read(cliChatProvider).isSending, isFalse);
      await notifier.selectAgent('agy');
      expect(container.read(cliChatProvider).hasHistory, isFalse);
      await notifier.selectAgent('codex');
      expect(container.read(cliChatProvider).activeSession?.id, 'native-new');
      expect(
        executor.ssh.sessions
            .expand((s) => s.calls)
            .where((c) => c['method'] == 'thread/start'),
        hasLength(1),
      );
      expect(
        executor.ssh.sessions
            .expand((s) => s.calls)
            .where((c) => c['method'] == 'thread/list'),
        hasLength(2),
      );
    },
  );
  test(
    'CLI history initially exposes the newest window then reveals older messages',
    () async {
      final executor = _Executor(historyMessageCount: 25);
      final container = await _container(executor);
      addTearDown(container.dispose);
      final notifier = container.read(cliChatProvider.notifier);

      await notifier.selectAgent('codex');
      await notifier.selectSession('native-old');

      var state = container.read(cliChatProvider);
      expect(state.messages.map((message) => message.id), [
        for (var index = 15; index < 25; index++) 'history-$index',
      ]);
      expect(state.hasOlderMessages, isTrue);
      expect(state.isLoadingOlderMessages, isFalse);
      final process = executor.ssh.sessions.single;
      expect(
        process.calls.where((call) => call['method'] == 'thread/read'),
        isEmpty,
      );
      expect((process.calls.last['params'] as Map)['limit'], 10);

      await notifier.loadOlderMessages();
      state = container.read(cliChatProvider);
      expect(state.messages, hasLength(20));
      expect(state.messages.first.id, 'history-5');
      expect(state.hasOlderMessages, isTrue);

      await notifier.loadOlderMessages();
      state = container.read(cliChatProvider);
      expect(state.messages, hasLength(25));
      expect(state.messages.first.id, 'history-0');
      expect(state.hasOlderMessages, isFalse);
      expect(
        process.calls.where((call) => call['method'] == 'thread/items/list'),
        hasLength(3),
      );
    },
  );
  test('CLI draft directory is separate from history filter', () async {
    final executor = _Executor();
    final container = await _container(executor);
    addTearDown(container.dispose);
    final notifier = container.read(cliChatProvider.notifier);
    await notifier.selectAgent('codex');
    await notifier.refreshSessions(cwd: '/history');
    notifier.createDraft();
    notifier.setDraftWorkingDirectory('/project');
    expect(container.read(cliChatProvider).cwd, '/history');
    expect(container.read(cliChatProvider).draftCwd, '/project');
    await notifier.sendMessage('hello');
    final start = executor.ssh.sessions.single.calls.firstWhere(
      (call) => call['method'] == 'thread/start',
    );
    expect((start['params'] as Map)['cwd'], '/project');
    executor.ssh.sessions.single.finish();
    await _drain();
    notifier.createDraft();
    expect(container.read(cliChatProvider).draftCwd, isNull);
  });
  test(
    'registry rechecks preserve CLI selection; server switch closes native transport and clears history',
    () async {
      final executor = _Executor();
      final container = await _container(executor);
      addTearDown(() async {
        container.dispose();
        await _drain();
        expect(executor.ssh.sessions.every((s) => s.closed), isTrue);
      });
      await container.read(cliChatProvider.notifier).selectAgent('codex');
      (container.read(agentRegistryProvider.notifier) as _Agents).recheck();
      await _drain();
      expect(container.read(cliChatProvider).activeAgent?.id, 'codex');
      expect(executor.ssh.sessions, hasLength(1));
      container
          .read(cliChatProvider.notifier)
          .setDraftWorkingDirectory('/tmp/project');
      (container.read(activeServerProvider.notifier) as _Active).change('b');
      await _drain();
      expect(container.read(cliChatProvider).sessions, isEmpty);
      expect(container.read(cliChatProvider).draftCwd, isNull);
      expect(container.read(cliChatProvider).agents.map((a) => a.id), [
        'foreign',
      ]);
      expect(executor.ssh.sessions.single.closed, isTrue);
      (container.read(agentRegistryProvider.notifier) as _Agents).useServer(
        'b',
      );
      await container.read(cliChatProvider.notifier).selectAgent('codex');
      expect(executor.ssh.sessions, hasLength(2));
    },
  );
  test(
    'remote deletion needs confirmation and retains native history on failure',
    () async {
      final executor = _Executor();
      final container = await _container(executor);
      addTearDown(container.dispose);
      final notifier = container.read(cliChatProvider.notifier);
      await notifier.selectAgent('codex');
      await notifier.deleteSession('native-old', confirmed: false);
      expect(
        executor.commands.where(
          (c) => c.contains('delete') && !c.contains('--help'),
        ),
        isEmpty,
      );
      executor.deleteFails = true;
      await notifier.deleteSession('native-old', confirmed: true);
      expect(container.read(cliChatProvider).sessions, hasLength(1));
      executor.deleteFails = false;
      await notifier.deleteSession('native-old', confirmed: true);
      expect(container.read(cliChatProvider).sessions, isEmpty);
    },
  );
  test(
    'Docker actions lock only one container and stale server completion cannot clear new state',
    () async {
      final executor = _Executor();
      final container = await _container(executor);
      addTearDown(container.dispose);
      final notifier = container.read(dockerProvider.notifier);
      final subscription = container.listen(dockerProvider, (_, _) {});
      addTearDown(subscription.close);
      await _drain();
      final firstGate = Completer<SSHExecutionResult>();
      final secondGate = Completer<SSHExecutionResult>();
      executor.pending["docker stop 'first'"] = firstGate;
      executor.pending["docker start 'second'"] = secondGate;
      final first = notifier.performLifecycle('stop', 'first');
      final second = notifier.performLifecycle('start', 'second');
      expect(container.read(dockerProvider).pendingActions, {
        'first': 'stop',
        'second': 'start',
      });
      await expectLater(
        notifier.performLifecycle('restart', 'first'),
        throwsStateError,
      );
      firstGate.complete(
        const SSHExecutionResult(exitCode: 1, stdout: '', stderr: 'failed'),
      );
      await first;
      expect(container.read(dockerProvider).pendingActions, {
        'second': 'start',
      });
      (container.read(activeServerProvider.notifier) as _Active).change('b');
      await _drain();
      secondGate.complete(
        const SSHExecutionResult(exitCode: 0, stdout: '', stderr: ''),
      );
      await second;
      expect(container.read(dockerProvider).pendingActions, isEmpty);
      expect(container.read(dockerProvider).isLoading, isFalse);
    },
  );
}
