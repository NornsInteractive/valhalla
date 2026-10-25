import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'package:valhalla/data/repositories/chat_repository.dart';
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
  _MutableRegistry(this._profiles, {Set<String>? readyIds})
    : _readyIds = readyIds ?? {_agentId};

  final List<AgentProfile> _profiles;
  final Set<String> _readyIds;

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

class _DelayingChatRepository extends ChatRepository {
  _DelayingChatRepository(super.storage, {required super.databasePath});

  Completer<void>? saveGate;
  bool armed = false;

  @override
  Future<void> saveSession(ChatSession session) async {
    if (armed && saveGate != null && !saveGate!.isCompleted) {
      await saveGate!.future;
    }
    return super.saveSession(session);
  }
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

Future<FakeAcpPair> awaitNextPromptedPair(
  List<FakeAcpPair> pairs,
  int previousCount,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (pairs.length <= previousCount) {
    if (DateTime.now().isAfter(deadline)) {
      fail('adapter never created the next transport');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final pair = pairs[previousCount];
  await pair.promptReceived.timeout(const Duration(seconds: 5));
  return pair;
}

Future<ProviderContainer> makeContainer({
  bool persistent = false,
  bool managedSsh = false,
  bool consent = false,
  bool autoOpen = true,
  AiChatState? initialState,
  List<String> readyAgents = const [_agentId],
  List<FakeAcpPair>? pairSink,
  void Function(FakeAcpPair pair)? configurePair,
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
  Future<AcpRuntimeStatus> Function(SSHClient, {required String runtimeKey})?
  inspectorOverride,
  Future<List<AcpRuntimeStatus>> Function(SSHClient, String)?
  serverRunsOverride,
  Future<void> Function(
    SSHClient, {
    required String runtimeKey,
    required String action,
    bool stopRunning,
  })?
  managerOverride,
  ChatRepository Function(LocalStorageService storage, String databasePath)?
  repositoryFactory,
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
  ], readyIds: readyAgents.toSet());
  pairs = [];
  final overrides = [
    localStorageServiceProvider.overrideWithValue(storage),
    if (repositoryFactory != null) ...[
      (() {
        final dir = Directory.systemTemp.createTempSync('valhalla_chat_test_');
        addTearDown(() async {
          if (!dir.existsSync()) return;
          for (var attempt = 0; ; attempt++) {
            try {
              await dir.delete(recursive: true);
              return;
            } on FileSystemException catch (error) {
              final code = error.osError?.errorCode;
              if (code != 39 || attempt >= 4) rethrow;
            }
          }
        });
        return chatRepositoryProvider.overrideWithValue(
          repositoryFactory(storage, '${dir.path}/chat.sqlite3'),
        );
      })(),
    ] else
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
      configurePair?.call(pair);
      pairs.add(pair);
      pairSink?.add(pair);
      return pair.client;
    }),
  ];
  if (initialState != null) {
    overrides.add(
      aiChatProvider.overrideWith(() => _StateOnlyAiChat(initialState)),
    );
  }
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
  if (inspectorOverride != null) {
    overrides.add(
      acpRuntimeInspectorProvider.overrideWithValue(inspectorOverride),
    );
  }
  if (serverRunsOverride != null) {
    overrides.add(acpServerRunsProvider.overrideWithValue(serverRunsOverride));
  }
  if (managerOverride != null) {
    overrides.add(acpRuntimeManagerProvider.overrideWithValue(managerOverride));
  }
  final created = ProviderContainer(overrides: overrides);
  addTearDown(created.dispose);
  addTearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });
  await settle(created);
  if (autoOpen) {
    await created
        .read(aiChatProvider.notifier)
        .openRemoteSession(remote(_remoteId));
    await settle(created);
  }
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

void _autoReplyLoadedSession(
  _PersistentSession session,
  List<String> methods,
  List<String> prompts,
  List<String> resumedSessionIds,
) {
  session._stdin.controller.stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        try {
          final outer = jsonDecode(line) as Map<String, dynamic>;
          final inner = outer['frame'] as Map<String, dynamic>;
          final method = inner['method'] as String?;
          if (method == null) return;
          methods.add(method);
          if (method == 'session/load' || method == 'session/resume') {
            final params = inner['params'];
            if (params is Map && params['sessionId'] is String) {
              resumedSessionIds.add(params['sessionId'] as String);
            }
          }
          if (method == 'session/prompt') {
            final params = inner['params'];
            if (params is Map) {
              final prompt = params['prompt'];
              if (prompt is List) {
                for (final block in prompt) {
                  if (block is Map &&
                      block['type'] == 'text' &&
                      block['text'] is String) {
                    prompts.add(block['text'] as String);
                  }
                }
              }
            }
          }
          final Map<String, Object?> result = switch (method) {
            'initialize' => {
              'protocolVersion': 1,
              'agentCapabilities': {
                'loadSession': true,
                'sessionCapabilities': {'resume': <String, Object?>{}},
              },
              'authMethods': <dynamic>[],
            },
            'session/load' || 'session/resume' => {
              'sessionId': _remoteId,
              'modes': null,
              'configOptions': <dynamic>[],
            },
            'session/prompt' => {'stopReason': 'end_turn'},
            _ => <String, Object?>{},
          };
          session.emitStdout(
            '${jsonEncode({
              'type': 'frame',
              'frame': {'jsonrpc': '2.0', 'id': inner['id'], 'result': result},
            })}\n',
          );
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
      addTearDown(container.dispose);
      addTearDown(() async {
        await notifier.stopGeneration();
      });
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
      addTearDown(container.dispose);
      addTearDown(() async {
        await notifier.stopGeneration();
      });
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

  group('ACP session isolation behavior', () {
    test('hidden run output is persisted after switching agent', () async {
      final pairs = <FakeAcpPair>[];
      final container = await makeContainer(
        readyAgents: const [_agentId, 'builtin-claude-code'],
        pairSink: pairs,
        configurePair: (pair) => pair.holdPrompt = true,
      );
      final notifier = container.read(aiChatProvider.notifier);
      final sessionId = container.read(aiChatProvider).activeSessionId!;
      final previousCount = pairs.length;
      final turn = notifier.sendMessage('hidden request');
      final pair = await awaitNextPromptedPair(pairs, previousCount);

      await notifier.switchAgent('builtin-claude-code');
      final hidden = container.read(aiChatProvider);
      expect(hidden.activeAgentProfile!.id, 'builtin-claude-code');
      expect(hidden.isGenerating, isFalse);
      expect(hidden.serverRun?.isBusy, isTrue);
      expect(
        hidden.sessions.any((session) => session.id == sessionId),
        isFalse,
      );

      pair.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'session/update',
          'params': {
            'sessionId': _remoteId,
            'update': {
              'sessionUpdate': 'agent_message_chunk',
              'messageId': 'hidden-answer',
              'content': {'type': 'text', 'text': 'hidden answer'},
            },
          },
        }),
      );
      pair.finishHeldPrompt();
      await turn.timeout(const Duration(seconds: 5));

      final repo = container.read(chatRepositoryProvider);
      ChatSession? saved;
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        saved = await repo.loadSession(sessionId);
        if (saved?.messages.any(
              (message) => message.content.contains('hidden answer'),
            ) ==
            true) {
          break;
        }
      }
      expect(saved, isNotNull);
      expect(
        saved!.messages.any(
          (message) => message.content.contains('hidden answer'),
        ),
        isTrue,
        reason: 'background output must reach the repository even while hidden',
      );
    });

    test(
      'same-server send is blocked before any draft or session is created',
      () async {
        final pairs = <FakeAcpPair>[];
        final container = await makeContainer(
          readyAgents: const [_agentId, 'builtin-claude-code'],
          pairSink: pairs,
          configurePair: (pair) => pair.holdPrompt = true,
        );
        final notifier = container.read(aiChatProvider.notifier);
        final repo = container.read(chatRepositoryProvider);
        final sessionId = container.read(aiChatProvider).activeSessionId!;
        final previousCount = pairs.length;
        final turn = notifier.sendMessage('first server turn');
        final pair = await awaitNextPromptedPair(pairs, previousCount);
        await notifier.switchAgent('builtin-claude-code');

        final before = container.read(aiChatProvider);
        expect(before.serverRun?.isBusy, isTrue);
        final storedBefore = jsonDecode(await repo.exportAll()) as List;
        final pairCount = pairs.length;

        await notifier.sendMessage('must-not-be-sent');

        final after = container.read(aiChatProvider);
        final storedAfter = jsonDecode(await repo.exportAll()) as List;
        expect(after.lastErrorCode, 'ACP_RUNTIME_SERVER_BUSY');
        expect(after.activeSessionId, before.activeSessionId);
        expect(after.draftText, before.draftText);
        expect(
          after.sessions.map((session) => session.id),
          before.sessions.map((session) => session.id),
        );
        expect(storedAfter, hasLength(storedBefore.length));
        for (final candidate in pairs) {
          expect(
            candidate.sentToAgent.join(),
            isNot(contains('must-not-be-sent')),
          );
        }
        expect(pairs, hasLength(pairCount));

        pair.finishHeldPrompt();
        await turn.timeout(const Duration(seconds: 5));
        expect(await repo.loadSession(sessionId), isNotNull);
      },
    );

    test('failed remote purge retains local history', () async {
      final profile = _profile(_agentId);
      final session = ChatSession(
        id: 'purge-local',
        title: 'Purge local',
        serverId: 'srv-1',
        agentId: _agentId,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        agentContexts: {
          _agentId: const AgentChatContext(
            remoteSessionId: _remoteId,
            persistentRuntimeKey: 'rk-purge',
            runtimeCursor: 4,
          ),
        },
      );
      final calls = <({String runtimeKey, String action, bool stopRunning})>[];
      final container = await makeContainer(
        autoOpen: false,
        initialState: AiChatState(
          sessions: [session],
          activeSessionId: session.id,
          activeAgentProfile: profile,
          readyAgents: [profile],
        ),
        managerOverride:
            (
              ssh, {
              required runtimeKey,
              required action,
              bool stopRunning = false,
            }) async {
              calls.add((
                runtimeKey: runtimeKey,
                action: action,
                stopRunning: stopRunning,
              ));
              if (action == 'purge') {
                throw StateError('ACP_RUNTIME_MANAGEMENT_FAILED');
              }
            },
      );
      final repo = container.read(chatRepositoryProvider);
      await repo.saveSession(session);
      final notifier = container.read(aiChatProvider.notifier);

      await expectLater(
        notifier.deleteSession(session.id, stopAndClearRemote: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_RUNTIME_MANAGEMENT_FAILED',
          ),
        ),
      );

      expect(calls, [
        (runtimeKey: 'rk-purge', action: 'purge', stopRunning: true),
      ]);
      expect(
        container.read(aiChatProvider).sessions.map((item) => item.id),
        contains(session.id),
      );
      expect((await repo.loadSession(session.id))?.id, session.id);
    });

    test(
      'local delete cancels nothing and cannot resurrect late output',
      () async {
        final pairs = <FakeAcpPair>[];
        final container = await makeContainer(
          readyAgents: const [_agentId, 'builtin-claude-code'],
          pairSink: pairs,
          configurePair: (pair) => pair.holdPrompt = true,
        );
        final notifier = container.read(aiChatProvider.notifier);
        final repo = container.read(chatRepositoryProvider);
        final sessionId = container.read(aiChatProvider).activeSessionId!;
        await notifier.setShareAgentSessions(true);
        final previousCount = pairs.length;
        final turn = notifier.sendMessage('delete while hidden');
        final pair = await awaitNextPromptedPair(pairs, previousCount);
        await notifier.switchAgent('builtin-claude-code');
        expect(
          container
              .read(aiChatProvider)
              .sessions
              .any((session) => session.id == sessionId),
          isTrue,
        );

        await notifier.deleteSession(sessionId);

        expect(await repo.loadSession(sessionId), isNull);
        expect(
          container
              .read(aiChatProvider)
              .sessions
              .any((session) => session.id == sessionId),
          isFalse,
        );
        expect(pair.sentToAgent.join(), isNot(contains('session/cancel')));

        pair.finishHeldPrompt();
        await turn
            .timeout(const Duration(seconds: 5))
            .catchError((Object _) {});
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(
          await repo.loadSession(sessionId),
          isNull,
          reason:
              'a late adapter event must not restore a locally deleted chat',
        );
        expect(
          container
              .read(aiChatProvider)
              .sessions
              .any((session) => session.id == sessionId),
          isFalse,
        );
      },
    );

    test(
      'expired runtime rotates generation and loads the same remote session',
      () async {
        const server = ServerProfile(
          id: 'srv-1',
          name: 'test server',
          host: 'example.test',
          username: 'root',
        );
        final profile = _profile(_agentId);
        const localId = 'expired-local';
        final identity = AcpRuntimeService.identity(
          server.connectionKey.toString(),
        );
        final oldKey = AcpRuntimeService.sessionKey(identity, profile, localId);
        final newKey = AcpRuntimeService.sessionKey(
          identity,
          profile,
          localId,
          generation: 1,
        );
        final session = ChatSession(
          id: localId,
          title: 'Expired runtime',
          serverId: 'srv-1',
          agentId: _agentId,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          messages: [
            ChatMessage(
              id: 'old-user',
              role: MessageRole.user,
              content: 'old question',
              createdAt: DateTime.utc(2026),
            ),
            ChatMessage(
              id: 'old-assistant',
              role: MessageRole.assistant,
              content: 'old answer',
              createdAt: DateTime.utc(2026),
            ),
          ],
          agentContexts: {
            _agentId: AgentChatContext(
              remoteSessionId: _remoteId,
              persistentRuntimeKey: oldKey,
              runtimeCursor: 9,
              runtimeGeneration: 0,
            ),
          },
        );
        final openerCalls =
            <
              ({String runtimeKey, String? remoteSessionId, int afterSequence})
            >[];
        final managerCalls =
            <({String runtimeKey, String action, bool stopRunning})>[];
        final methods = <String>[];
        final prompts = <String>[];
        final resumedSessionIds = <String>[];
        _PersistentSession? resumed;
        var attempts = 0;
        final container = await makeContainer(
          persistent: true,
          managedSsh: true,
          consent: true,
          autoOpen: false,
          serverRunsOverride: (_, _) async => const [],
          initialState: AiChatState(
            sessions: [session],
            activeSessionId: localId,
            activeAgentProfile: profile,
            readyAgents: [profile],
          ),
          openerOverride:
              (
                ssh,
                target, {
                required runtimeKey,
                required afterSequence,
                String? remoteSessionId,
                String? initialModelId,
              }) async {
                openerCalls.add((
                  runtimeKey: runtimeKey,
                  remoteSessionId: remoteSessionId,
                  afterSequence: afterSequence,
                ));
                if (attempts++ == 0) {
                  throw AcpRuntimeUnavailableException(
                    AcpRuntimeStatus(
                      runtimeKey: runtimeKey,
                      state: 'expired',
                      remoteSessionId: _remoteId,
                    ),
                  );
                }
                final session = _PersistentSession();
                resumed = session;
                _autoReplyLoadedSession(
                  session,
                  methods,
                  prompts,
                  resumedSessionIds,
                );
                final transport = AcpSshTransport(
                  session,
                  runtimeKey: runtimeKey,
                  afterSequence: afterSequence,
                );
                session.emitStdout(
                  '${jsonEncode({'type': 'status', 'state': 'running', 'turnId': 'turn1', 'seq': afterSequence})}\n',
                );
                await transport.attached.timeout(const Duration(seconds: 5));
                return transport;
              },
          managerOverride:
              (
                ssh, {
                required runtimeKey,
                required action,
                bool stopRunning = false,
              }) async {
                managerCalls.add((
                  runtimeKey: runtimeKey,
                  action: action,
                  stopRunning: stopRunning,
                ));
              },
        );
        final repo = container.read(chatRepositoryProvider);
        await repo.saveSession(session);
        final notifier = container.read(aiChatProvider.notifier);

        await notifier.sendMessage('after expiry');
        await notifier.checkpoint();

        expect(openerCalls, [
          (runtimeKey: oldKey, remoteSessionId: _remoteId, afterSequence: 9),
          (runtimeKey: newKey, remoteSessionId: _remoteId, afterSequence: 0),
        ]);
        expect(managerCalls, [
          (runtimeKey: oldKey, action: 'retire', stopRunning: false),
        ]);
        expect(resumed, isNotNull);
        expect(
          methods.where(
            (method) => method == 'session/load' || method == 'session/resume',
          ),
          hasLength(1),
        );
        expect(resumedSessionIds, [_remoteId]);
        expect(methods, isNot(contains('session/new')));
        expect(prompts, hasLength(1));
        expect(prompts.single, endsWith('after expiry'));

        final saved = await repo.loadSession(localId);
        expect(saved, isNotNull);
        final context = saved!.agentContexts[_agentId]!;
        expect(context.remoteSessionId, _remoteId);
        expect(context.runtimeGeneration, 1);
        expect(context.persistentRuntimeKey, newKey);
        expect(context.runtimeCursor, 0);
        expect(context.runtimeRestartPending, isFalse);
      },
    );

    test(
      'stale permission completer or server target cannot respond',
      () async {
        const pending = PermissionRequest(
          id: 'perm-1',
          toolName: 'bash',
          command: 'rm -rf build',
          description: 'run command',
          options: [
            ChatPermissionOption(
              id: 'allow-once',
              name: 'Allow once',
              kind: 'allow_once',
            ),
          ],
        );
        final active = Completer<String?>();
        final profile = _profile(_agentId);
        final container = await makeContainer(
          autoOpen: false,
          initialState: AiChatState(
            pendingPermission: pending,
            permissionCompleter: active,
            activeAgentProfile: profile,
            readyAgents: [profile],
          ),
        );
        final notifier =
            container.read(aiChatProvider.notifier) as _StateOnlyAiChat;
        final target = container
            .read(activeServerProvider)!
            .connectionKey
            .toString();

        expect(
          notifier.respondToPermission(
            'allow-once',
            expectedCompleter: active,
            expectedServerKey: target,
          ),
          isTrue,
        );
        expect(await active.future, 'allow-once');

        final current = Completer<String?>();
        notifier.show(
          AiChatState(
            pendingPermission: pending,
            permissionCompleter: current,
            activeAgentProfile: profile,
            readyAgents: [profile],
          ),
        );
        expect(
          notifier.respondToPermission(
            'allow-once',
            expectedCompleter: current,
            expectedServerKey: 'stale-target',
          ),
          isFalse,
        );
        expect(current.isCompleted, isFalse);
        expect(
          container.read(aiChatProvider).pendingPermission?.id,
          pending.id,
        );

        final stale = Completer<String?>();
        expect(
          notifier.respondToPermission(
            'allow-once',
            expectedCompleter: stale,
            expectedServerKey: target,
          ),
          isFalse,
        );
        expect(current.isCompleted, isFalse);

        final already = Completer<String?>()..complete('already');
        notifier.show(
          AiChatState(
            pendingPermission: pending,
            permissionCompleter: already,
            activeAgentProfile: profile,
            readyAgents: [profile],
          ),
        );
        expect(
          notifier.respondToPermission(
            'allow-once',
            expectedCompleter: already,
            expectedServerKey: target,
          ),
          isFalse,
        );
      },
    );

    test(
      'changing target during adopt await never sends clicked text to new target',
      () async {
        final pairs = <FakeAcpPair>[];
        final gate = Completer<void>();
        final container = await makeContainer(
          readyAgents: const [_agentId, 'builtin-claude-code'],
          pairSink: pairs,
          configurePair: (pair) => pair.holdPrompt = true,
          repositoryFactory: (storage, path) =>
              _DelayingChatRepository(storage, databasePath: path),
        );
        final notifier = container.read(aiChatProvider.notifier);
        await notifier.setShareAgentSessions(true);
        await settle(container);

        final originalSessionId = container
            .read(aiChatProvider)
            .activeSessionId!;

        // Start one hidden durable run that later finishes.
        final previousCount = pairs.length;
        final firstTurn = notifier.sendMessage('old context');
        final pair = await awaitNextPromptedPair(pairs, previousCount);
        await notifier.switchAgent('builtin-claude-code');
        pair.finishHeldPrompt();
        await firstTurn.timeout(const Duration(seconds: 5));
        await settle(container);

        // Arm the repository save gate immediately before the second send so the
        // finished run's adopt await cannot complete before the target changes.
        final repository =
            container.read(chatRepositoryProvider) as _DelayingChatRepository;
        repository.saveGate = gate;
        repository.armed = true;

        // Re-enter the old context so the click originates there.
        await notifier.switchAgent(_agentId);
        if (container.read(aiChatProvider).activeSessionId !=
            originalSessionId) {
          await notifier.selectSession(originalSessionId);
        }
        await settle(container);
        expect(
          container.read(aiChatProvider).activeSessionId,
          originalSessionId,
        );

        final promptsBefore = pairs.fold<int>(
          0,
          (count, candidate) =>
              count +
              candidate.sentToAgent
                  .where((line) => line.contains('session/prompt'))
                  .length,
        );

        final sendFuture = notifier.sendMessage('clicked text');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await pumpEventQueue();

        // Change agent/session/target while adopt is still awaited.
        await notifier.switchAgent('builtin-claude-code');
        await pumpEventQueue();

        gate.complete();
        await sendFuture.timeout(const Duration(seconds: 5)).catchError((_) {});
        await settle(container);

        final allSent = pairs
            .expand((candidate) => candidate.sentToAgent)
            .join();
        final promptsAfter = pairs.fold<int>(
          0,
          (count, candidate) =>
              count +
              candidate.sentToAgent
                  .where((line) => line.contains('session/prompt'))
                  .length,
        );

        expect(
          allSent,
          isNot(contains('clicked text')),
          reason: 'clicked text must not reach any agent transport',
        );
        expect(
          promptsAfter,
          promptsBefore,
          reason: 'no prompt may be issued after the target changed',
        );
        expect(
          (await repository.exportAll()),
          isNot(contains('clicked text')),
          reason: 'no chat record may be created for the clicked text',
        );
        expect(
          container.read(aiChatProvider).activeAgentProfile?.id,
          'builtin-claude-code',
        );
      },
    );
  });
}
