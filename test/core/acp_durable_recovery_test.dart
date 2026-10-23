import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

const _agentId = 'builtin-codex';
const _remoteId = 'remote-codex-1';

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

class _ToggleConnection extends ServerConnectionNotifier {
  bool connected = true;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: connected ? 'srv-1' : null,
  );

  void setConnected(bool value) {
    connected = value;
    state = ServerConnectionState(
      status: value
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
      activeServerId: value ? 'srv-1' : null,
    );
  }
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

class _MutableRegistry extends AgentRegistryNotifier {
  _MutableRegistry(this._profiles);

  final List<AgentProfile> _profiles;
  final Set<String> _readyIds = {_agentId};

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      for (final profile in _profiles)
        AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: _readyIds.contains(profile.id)
                ? AgentEnvironmentStatusKind.ready
                : AgentEnvironmentStatusKind.cliMissing,
            checkedAt: DateTime.utc(2026),
          ),
        ),
    ],
  );
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stdin implements StreamSink<Uint8List> {
  final controller = StreamController<Uint8List>.broadcast();
  final writes = <Uint8List>[];
  @override
  void add(Uint8List event) {
    writes.add(event);
    controller.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      controller.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<Uint8List> stream) =>
      controller.addStream(stream);
  @override
  Future<void> close() => controller.close();
  @override
  Future<void> get done => controller.done;
}

class _PersistentSession implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = _Stdin();
  bool closed = false;
  int? exitCodeValue;

  _PersistentSession();

  void emitStdout(String text) => _stdout.add(utf8.encode(text));

  @override
  Stream<Uint8List> get stdout => _stdout.stream;
  @override
  Stream<Uint8List> get stderr => _stderr.stream;
  @override
  StreamSink<Uint8List> get stdin => _stdin;
  @override
  int? get exitCode => exitCodeValue;

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    unawaited(_stdin.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PersistentSshClient implements SSHClient {
  final _session = _PersistentSession();

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async => _session;

  @override
  Future<SSHRunResult> runWithResult(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) async {
    final bytes = utf8.encode('/tmp\n');
    return SSHRunResult(
      output: Uint8List.fromList(bytes),
      stdout: Uint8List.fromList(bytes),
      stderr: Uint8List(0),
      exitCode: 0,
      exitSignal: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PersistentSshManager extends SSHClientManager {
  _PersistentSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _PersistentSshClient();
}

class _StateOnlyAiChat extends AiChatNotifier {
  _StateOnlyAiChat(this.initial);
  final AiChatState initial;

  @override
  AiChatState build() => initial;

  void show(AiChatState next) => state = next;
}

const _launchKey = 'host|name|null|null|acp --stdio|cli';
const capabilities = {
  'loadSession': true,
  'sessionCapabilities': {'list': true, 'resume': <String, Object?>{}},
};

AcpRemoteSession remote(String id) => AcpRemoteSession(
  id: id,
  title: 'remote $id',
  workingDirectory: '/root',
  serverId: 'srv-1',
  agentId: _agentId,
  launchKey: _launchKey,
);

Future<void> settle(ProviderContainer target) async {
  await pumpEventQueue();
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (target.read(aiChatProvider).isLoadingSessions ||
      target.read(aiChatProvider).isLoadingMessages) {
    if (DateTime.now().isAfter(deadline)) {
      fail('history loading never settled');
    }
    await pumpEventQueue();
  }
}

Future<ProviderContainer> makeContainer({
  bool persistent = false,
  bool managedSsh = false,
  bool consent = false,
  Future<Map<String, dynamic>> Function(SSHClient)? installerOverride,
  Future<AcpSshTransport> Function(
    SSHClient,
    AgentProfile, {
    required String runtimeKey,
    required int afterSequence,
    String? remoteSessionId,
    String? initialModelId,
  })?
  openerOverride,
}) async {
  SharedPreferences.setMockInitialValues({});
  if (consent) {
    final server = const ServerProfile(
      id: 'srv-1',
      name: 'test server',
      host: 'example.test',
      username: 'root',
    );
    final identity = AcpRuntimeService.identity(
      server.connectionKey.toString(),
    );
    SharedPreferences.setMockInitialValues({
      'valhalla_acp_runtime_consent_v1_$identity': true,
    });
  }
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  late List<FakeAcpPair> pairs;
  final connection = _ToggleConnection();
  final registry = _MutableRegistry([
    _profile(_agentId),
    _profile('builtin-claude-code'),
  ]);
  pairs = [];
  final overrides = [
    localStorageServiceProvider.overrideWithValue(storage),
    tempChatRepositoryOverride(),
    agentRegistryProvider.overrideWith(() => registry),
    serverConnectionProvider.overrideWith(() => connection),
    activeServerProvider.overrideWith(_StubActiveServer.new),
    sshClientManagerProvider.overrideWithValue(
      managedSsh ? _PersistentSshManager(storage) : _FakeSshManager(storage),
    ),
    acpTransportFactoryProvider.overrideWithValue((
      profile,
      ssh, {
      String? initialModelId,
    }) async {
      final pair = FakeAcpPair(sessionId: _remoteId)
        ..agentCapabilities = capabilities
        ..loadReplayUpdates = const [
          {
            'sessionUpdate': 'user_message_chunk',
            'messageId': 'u1',
            'content': {'type': 'text', 'text': 'old question'},
          },
          {
            'sessionUpdate': 'agent_message_chunk',
            'messageId': 'a1',
            'content': {'type': 'text', 'text': 'old answer'},
          },
        ];
      pairs.add(pair);
      return pair.client;
    }),
  ];
  if (persistent) {
    overrides.add(persistentAcpRuntimeEnabledProvider.overrideWithValue(true));
  }
  if (installerOverride != null) {
    overrides.add(
      persistentAcpRuntimeInstallerProvider.overrideWithValue(
        installerOverride,
      ),
    );
  }
  if (openerOverride != null) {
    overrides.add(
      persistentAcpRuntimeOpenerProvider.overrideWithValue(openerOverride),
    );
  }
  final created = ProviderContainer(overrides: overrides);
  addTearDown(created.dispose);
  addTearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });
  await settle(created);
  await created
      .read(aiChatProvider.notifier)
      .openRemoteSession(remote(_remoteId));
  await settle(created);
  return created;
}

void _autoReplyPersistent(_PersistentSession session, String caughtUpState) {
  session._stdin.controller.stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        try {
          final outer = jsonDecode(line) as Map<String, dynamic>;
          final inner = outer['frame'] as Map<String, dynamic>;
          final method = inner['method'] as String?;
          final id = inner['id'];
          if (method == 'initialize') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {
                  'jsonrpc': '2.0',
                  'id': id,
                  'result': {
                    'protocolVersion': 1,
                    'agentCapabilities': {
                      'loadSession': true,
                      'sessionCapabilities': {'resume': <String, Object?>{}},
                    },
                    'authMethods': <dynamic>[],
                  },
                },
              })}\n',
            );
          } else if (method == 'session/resume' || method == 'session/load') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {
                  'jsonrpc': '2.0',
                  'id': id,
                  'result': {'configOptions': <dynamic>[], 'modes': null},
                },
              })}\n',
            );
            Future<void>.delayed(const Duration(milliseconds: 20), () {
              session.emitStdout(
                '${jsonEncode({
                  'type': 'frame',
                  'turnId': 'turn1',
                  'seq': 6,
                  'frame': {
                    'jsonrpc': '2.0',
                    'method': 'session/update',
                    'params': {
                      'sessionId': 'remote-codex-1',
                      'update': {
                        'sessionUpdate': 'agent_message_chunk',
                        'messageId': 'a1',
                        'content': {'type': 'text', 'text': 'missed'},
                      },
                    },
                  },
                })}\n',
              );
              session.emitStdout(
                '${jsonEncode({'type': 'caught_up', 'state': caughtUpState, 'turnId': 'turn1', 'seq': 6})}\n',
              );
            });
          } else if (method == 'session/cancel') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {'jsonrpc': '2.0', 'id': id, 'result': <String, dynamic>{}},
              })}\n',
            );
          }
        } catch (_) {}
      });
}

void main() {
  group('acp durable recovery provider', () {
    test(
      'production flag consent send holds draft and inserts no messages',
      () async {
        final container = await makeContainer(persistent: true, consent: false);
        final notifier = container.read(aiChatProvider.notifier);
        notifier.updateDraftText('half typed');
        final before = container
            .read(aiChatProvider)
            .activeSession!
            .messages
            .map((m) => m.content)
            .toList();
        await notifier.sendMessage('hello');
        await settle(container);
        final after = container.read(aiChatProvider);
        expect(after.persistentRuntimeSetupRequired, isTrue);
        expect(after.draftText, 'half typed');
        expect(
          after.activeSession!.messages.map((m) => m.content).toList(),
          before,
        );
      },
    );

    test('approval installer override called once preserving draft', () async {
      var installerCalls = 0;
      final container = await makeContainer(
        persistent: true,
        consent: false,
        installerOverride: (ssh) async {
          installerCalls++;
          return {'script': '/tmp/broker.py', 'python': 'python3'};
        },
      );
      final notifier = container.read(aiChatProvider.notifier);
      notifier.updateDraftText('kept draft');
      final result = await notifier.approvePersistentRuntime();
      expect(result, isTrue);
      expect(installerCalls, 1);
      expect(container.read(aiChatProvider).draftText, 'kept draft');
    });

    test('dismissRecoveryNotice retains status/diagnostics', () {
      final initial = AiChatState(
        recoveryStatus: SessionRecoveryStatus.failed,
        diagnostics: 'boom',
        recoveryNoticeDismissed: false,
      );
      final notifier = _StateOnlyAiChat(initial);
      final container = ProviderContainer(
        overrides: [aiChatProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      notifier.show(initial);
      notifier.dismissRecoveryNotice();
      final after = container.read(aiChatProvider);
      expect(after.recoveryStatus, SessionRecoveryStatus.failed);
      expect(after.diagnostics, 'boom');
      expect(after.recoveryNoticeDismissed, isTrue);
    });

    test('AgentChatContext runtimeKey/cursor roundtrip', () {
      const ctx = AgentChatContext(
        persistentRuntimeKey: 'rk',
        runtimeCursor: 7,
      );
      final restored = AgentChatContext.fromJson(ctx.toJson());
      expect(restored.persistentRuntimeKey, 'rk');
      expect(restored.runtimeCursor, 7);
    });

    test('ChatMessage runtimeTurnId roundtrip', () {
      final msg = ChatMessage(
        id: 'm1',
        role: MessageRole.assistant,
        content: 'hi',
        createdAt: DateTime.utc(2026),
        runtimeTurnId: 'turn-1',
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.runtimeTurnId, 'turn-1');
    });

    test('managed recovery regression', () async {
      SharedPreferences.setMockInitialValues({});
      const server = ServerProfile(
        id: 'srv-1',
        name: 'test server',
        host: 'example.test',
        username: 'root',
      );
      final identity = AcpRuntimeService.identity(
        server.connectionKey.toString(),
      );
      SharedPreferences.setMockInitialValues({
        'valhalla_acp_runtime_consent_v1_$identity': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final profile = _profile(_agentId);
      final initialSession = ChatSession(
        id: 'local',
        title: 'local',
        serverId: 'srv-1',
        agentId: _agentId,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        messages: [
          ChatMessage(
            id: 'turn1',
            role: MessageRole.assistant,
            content: 'before',
            createdAt: DateTime.utc(2026),
            runtimeTurnId: 'turn1',
            status: ChatTurnStatus.unknown,
          ),
        ],
        agentContexts: {
          _agentId: AgentChatContext(
            remoteSessionId: 'remote-codex-1',
            persistentRuntimeKey: 'rk',
            runtimeCursor: 5,
          ),
        },
      );
      final initial = AiChatState(
        sessions: [initialSession],
        activeSessionId: 'local',
        activeAgentProfile: profile,
      );
      final registry = _MutableRegistry([
        profile,
        _profile('builtin-claude-code'),
      ]);
      final connection = _ToggleConnection();
      final sshManager = _PersistentSshManager(storage);
      _PersistentSession? capturedSession;
      Future<AcpSshTransport> opener(
        SSHClient ssh,
        AgentProfile p, {
        required String runtimeKey,
        required int afterSequence,
        String? remoteSessionId,
        String? initialModelId,
      }) async {
        final session = _PersistentSession();
        capturedSession = session;
        _autoReplyPersistent(session, 'running');
        final transport = AcpSshTransport(
          session,
          runtimeKey: runtimeKey,
          afterSequence: afterSequence,
        );
        session.emitStdout(
          '${jsonEncode({'type': 'status', 'state': 'running', 'turnId': 'turn1', 'seq': 5})}\n',
        );
        await transport.attached.timeout(const Duration(seconds: 5));
        return transport;
      }

      final notifier = _StateOnlyAiChat(initial);
      final overrides = [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(() => registry),
        serverConnectionProvider.overrideWith(() => connection),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(sshManager),
        persistentAcpRuntimeEnabledProvider.overrideWithValue(true),
        persistentAcpRuntimeOpenerProvider.overrideWithValue(opener),
        aiChatProvider.overrideWith(() => notifier),
      ];
      final container = ProviderContainer(overrides: overrides);
      addTearDown(() async {
        await notifier.stopGeneration();
      });
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      final repo = container.read(chatRepositoryProvider);
      await repo.saveSession(initialSession);

      await notifier.recoverConnection();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue();

      final state1 = container.read(aiChatProvider);
      expect(state1.isGenerating, isTrue);
      expect(state1.activeSession!.messages.single.content, 'beforemissed');

      capturedSession!.emitStdout(
        '${jsonEncode({
          'type': 'frame',
          'turnId': 'turn1',
          'seq': 7,
          'frame': {
            'jsonrpc': '2.0',
            'method': 'session/update',
            'params': {
              'sessionId': 'remote-codex-1',
              'update': {
                'sessionUpdate': 'agent_message_chunk',
                'messageId': 'a1',
                'content': {'type': 'text', 'text': 'live'},
              },
            },
          },
        })}\n',
      );
      await pumpEventQueue();
      capturedSession!.emitStdout(
        '${jsonEncode({'type': 'turn', 'state': 'completed', 'turnId': 'turn1', 'seq': 8})}\n',
      );
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();
      await notifier.checkpoint();
      await pumpEventQueue();

      final state2 = container.read(aiChatProvider);
      expect(state2.activeSession!.messages.single.content, 'beforemissedlive');
      expect(
        state2.activeSession!.messages.single.status,
        ChatTurnStatus.completed,
      );
      expect(state2.activeSession!.agentContexts[_agentId]!.runtimeCursor, 8);

      final writes = capturedSession!._stdin.writes;
      final joined = utf8.decode(writes.expand((e) => e).toList());
      expect(joined, isNot(contains('session/new')));
      expect(joined, isNot(contains('session/prompt')));

      final saved = await repo.loadSession('local');
      expect(saved!.agentContexts[_agentId]!.runtimeCursor, 8);
    });

    test('initial completed status is not terminal before backlog', () async {
      SharedPreferences.setMockInitialValues({});
      const server = ServerProfile(
        id: 'srv-1',
        name: 'test server',
        host: 'example.test',
        username: 'root',
      );
      final identity = AcpRuntimeService.identity(
        server.connectionKey.toString(),
      );
      SharedPreferences.setMockInitialValues({
        'valhalla_acp_runtime_consent_v1_$identity': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final profile = _profile(_agentId);
      final initialSession = ChatSession(
        id: 'local',
        title: 'local',
        serverId: 'srv-1',
        agentId: _agentId,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        messages: [
          ChatMessage(
            id: 'turn1',
            role: MessageRole.assistant,
            content: 'before',
            createdAt: DateTime.utc(2026),
            runtimeTurnId: 'turn1',
            status: ChatTurnStatus.unknown,
          ),
        ],
        agentContexts: {
          _agentId: AgentChatContext(
            remoteSessionId: 'remote-codex-1',
            persistentRuntimeKey: 'rk',
            runtimeCursor: 5,
          ),
        },
      );
      final initial = AiChatState(
        sessions: [initialSession],
        activeSessionId: 'local',
        activeAgentProfile: profile,
      );
      final registry = _MutableRegistry([
        profile,
        _profile('builtin-claude-code'),
      ]);
      final connection = _ToggleConnection();
      final sshManager = _PersistentSshManager(storage);
      _PersistentSession? capturedSession;
      Future<AcpSshTransport> opener(
        SSHClient ssh,
        AgentProfile p, {
        required String runtimeKey,
        required int afterSequence,
        String? remoteSessionId,
        String? initialModelId,
      }) async {
        final session = _PersistentSession();
        capturedSession = session;
        _autoReplyPersistent(session, 'completed');
        final transport = AcpSshTransport(
          session,
          runtimeKey: runtimeKey,
          afterSequence: afterSequence,
        );
        session.emitStdout(
          '${jsonEncode({'type': 'status', 'state': 'completed', 'turnId': 'turn1', 'seq': 5})}\n',
        );
        await transport.attached.timeout(const Duration(seconds: 5));
        return transport;
      }

      final notifier = _StateOnlyAiChat(initial);
      final overrides = [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(() => registry),
        serverConnectionProvider.overrideWith(() => connection),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(sshManager),
        persistentAcpRuntimeEnabledProvider.overrideWithValue(true),
        persistentAcpRuntimeOpenerProvider.overrideWithValue(opener),
        aiChatProvider.overrideWith(() => notifier),
      ];
      final container = ProviderContainer(overrides: overrides);
      addTearDown(() async {
        await notifier.stopGeneration();
      });
      addTearDown(container.dispose);
      container.read(aiChatProvider);
      final repo = container.read(chatRepositoryProvider);
      await repo.saveSession(initialSession);

      await notifier.recoverConnection();
      capturedSession!.emitStdout(
        '${jsonEncode({'type': 'status', 'state': 'completed', 'turnId': 'turn1', 'seq': 5})}\n',
      );
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await pumpEventQueue();
      final mid = container.read(aiChatProvider);
      expect(mid.activeSession!.messages.single.status, ChatTurnStatus.unknown);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue();
      final after = container.read(aiChatProvider);
      expect(
        after.activeSession!.messages.single.status,
        ChatTurnStatus.completed,
      );
    });
  });
}
