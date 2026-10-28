import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/app_visibility_provider.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/workspace/remote_workspace_client.dart';

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

/// Minimal in-memory workspace gateway. It fails the test if the controller
/// ever asks for an unfiltered runtime catalog scan: a cold device must name the
/// exact runtime it is looking for instead of paging the top 100 entries.
class _FakeWorkspaceGateway implements WorkspaceGateway {
  _FakeWorkspaceGateway({
    this.runtimeCatalog = const [],
    this.sessions = const {},
    this.foreignLease = false,
  });

  @override
  final String deviceId = 'device-new';
  final Set<String> enabledServers = const {'srv-1'};
  final List<Map<String, dynamic>> runtimeCatalog;
  final Map<String, Map<String, dynamic>> sessions;
  final bool foreignLease;

  final List<Map<String, dynamic>> runtimeCatalogRequests = [];
  final List<Map<String, dynamic>> snapshotRequests = [];
  final List<Map<String, dynamic>> leaseRequests = [];
  final List<List<Map<String, dynamic>>> staged = [];
  final StreamController<WorkspaceChange> _changes =
      StreamController<WorkspaceChange>.broadcast();

  @override
  bool isEnabled(String serverId) => enabledServers.contains(serverId);

  @override
  Stream<WorkspaceChange> get changes => _changes.stream;

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {
    staged.add(records);
  }

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    switch (command['op']) {
      case 'runtime_catalog':
        runtimeCatalogRequests.add(Map<String, dynamic>.from(command));
        final key = command['runtimeKey'];
        if (key is! String || key.isEmpty) {
          fail('runtime_catalog must be filtered by an exact runtimeKey');
        }
        return {
          'ok': true,
          'runtimes': runtimeCatalog
              .where((entry) => entry['runtimeKey'] == key)
              .toList(),
        };
      case 'snapshot':
        snapshotRequests.add(Map<String, dynamic>.from(command));
        final kind = command['kind'];
        final limit = (command['limit'] as num?)?.toInt() ?? 100;
        if (kind == 'chat_session' && limit > 2) {
          fail('workspace metadata reads must stay bounded, got limit=$limit');
        }
        if (kind != 'chat_session') return {'ok': true, 'records': const []};
        final id = command['id'] as String?;
        final prefix = command['prefix'] as String?;
        final values = sessions.entries
            .where(
              (entry) =>
                  (id == null || entry.key == id) &&
                  (prefix == null || entry.key.startsWith(prefix)),
            )
            .map(
              (entry) => {
                'kind': 'chat_session',
                'id': entry.key,
                'version': 1,
                'value': entry.value,
              },
            )
            .toList();
        return {'ok': true, 'records': values, 'hasMore': false};
      case 'lease':
        leaseRequests.add(Map<String, dynamic>.from(command));
        if (foreignLease) {
          throw const WorkspaceException('WORKSPACE_CONTROL_HELD', {
            'ownerDeviceId': 'device-other',
          });
        }
        return {
          'ok': true,
          'ownerDeviceId': deviceId,
          'token': 'token-1',
          'generation': 1,
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        };
      default:
        return {'ok': false, 'error': 'WORKSPACE_OP_UNKNOWN'};
    }
  }
}

typedef _SharedOpen = ({
  String runtimeKey,
  int afterSequence,
  String? remoteSessionId,
  String? workingDirectory,
  String? title,
  Map<String, dynamic> workspace,
});

/// Opens a real [AcpSshTransport] against a simulated broker stream. The
/// read-only flag mirrors what `AcpRuntimeService.openShared` computes from a
/// missing control token, so the production adapter fast path is exercised.
class _SharedOpener {
  final List<_SharedOpen> calls = [];
  final List<_PersistentSession> sessions = [];
  final List<AcpSshTransport> transports = [];
  String turnId = 'turn1';

  Future<Transport> open(
    SSHClient ssh,
    AgentProfile profile, {
    required String runtimeKey,
    required int afterSequence,
    required Map<String, dynamic> workspace,
    String? remoteSessionId,
    String? initialModelId,
    String? workingDirectory,
    String? title,
  }) async {
    calls.add((
      runtimeKey: runtimeKey,
      afterSequence: afterSequence,
      remoteSessionId: remoteSessionId,
      workingDirectory: workingDirectory,
      title: title,
      workspace: Map<String, dynamic>.from(workspace),
    ));
    final session = _PersistentSession();
    sessions.add(session);
    final transport = AcpSshTransport(
      session,
      runtimeKey: runtimeKey,
      afterSequence: afterSequence,
      workspaceReadOnly: workspace['controlToken'] == null,
    );
    transports.add(transport);
    session.emitStdout(
      '${jsonEncode({'type': 'status', 'state': 'running', 'sessionId': remoteSessionId, 'turnId': turnId, 'seq': afterSequence})}\n',
    );
    await transport.attached.timeout(const Duration(seconds: 5));
    return transport;
  }
}

Future<void> _waitForServerRun(
  ProviderContainer container, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (container.read(aiChatProvider).serverRun == null) {
    if (DateTime.now().isAfter(deadline)) {
      fail('controller never discovered the running runtime');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await pumpEventQueue();
  }
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
  bool connected = true,
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
  WorkspaceGateway? workspaceGateway,
  String? workspaceId,
  SharedAcpRuntimeOpener? sharedOpenerOverride,
  List<ChatSession> seedSessions = const [],
}) async {
  final bindingId =
      workspaceId ?? (workspaceGateway == null ? null : 'ws-test');
  final initialPrefs = <String, Object>{
    if (workspaceGateway != null && bindingId != null)
      'valhalla_workspace_binding_v1::srv-1': jsonEncode({
        'workspaceId': bindingId,
      }),
  };
  if (consent) {
    final server = const ServerProfile(
      id: 'srv-1',
      name: 'test server',
      host: 'example.test',
      username: 'root',
    );
    // Shared workspace consent is keyed by the workspace id, exactly like
    // `_persistentConsentIdentity` does at runtime.
    final identity = AcpRuntimeService.identity(
      workspaceGateway != null && bindingId != null
          ? bindingId
          : server.connectionKey.toString(),
    );
    initialPrefs['valhalla_acp_runtime_consent_v1_$identity'] = true;
  }
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  storage.workspaceGateway = workspaceGateway;
  late List<FakeAcpPair> pairs;
  final connection = _ToggleConnection();
  connection.connected = connected;
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
  if (sharedOpenerOverride != null) {
    overrides.add(
      sharedAcpRuntimeOpenerProvider.overrideWithValue(sharedOpenerOverride),
    );
  }
  final created = ProviderContainer(overrides: overrides);
  addTearDown(created.dispose);
  addTearDown(() {
    for (final pair in pairs) {
      pair.close();
    }
  });
  if (seedSessions.isNotEmpty) {
    final repository = created.read(chatRepositoryProvider);
    for (final session in seedSessions) {
      // Seed local cache only: an observer must never stage remote checkpoints
      // just to open a session it does not control.
      await repository.persistLocalRuntimeSession(session);
    }
  }
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

  group('shared runtime discovery', () {
    const runtimeKey = 'runtime-shared-1';
    const chatSessionId = 'chat-shared-1';
    const acpRemoteId = 'acp-remote-1';
    const cwd = '/srv/project';
    const title = 'Shared Project';
    const workspaceId = 'ws-1';

    Map<String, dynamic> catalogEntry() => {
      'runtimeKey': runtimeKey,
      'agentId': _agentId,
      'sessionId': chatSessionId,
      'scope': 'srv-1',
      'meta': {
        'workingDirectory': cwd,
        'title': title,
        'remoteSessionId': acpRemoteId,
      },
    };

    Future<List<AcpRuntimeStatus>> busyRuns(SSHClient _, String _) async => [
      const AcpRuntimeStatus(
        runtimeKey: runtimeKey,
        state: 'running',
        alive: true,
        childAlive: true,
        workspaceProtocol: 1,
        remoteSessionId: acpRemoteId,
        turnId: 'turn1',
      ),
    ];

    test(
      'cold device hydrates the exact shared chat_session without a new runtime',
      () async {
        final gateway = _FakeWorkspaceGateway(
          runtimeCatalog: [catalogEntry()],
          sessions: {
            chatSessionId: {
              'title': title,
              'agentId': _agentId,
              'workingDirectory': cwd,
              'remoteSessionId': acpRemoteId,
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'updatedAt': DateTime.utc(2026).toIso8601String(),
              'agentContexts': {
                _agentId: {
                  'persistentRuntimeKey': runtimeKey,
                  'remoteSessionId': acpRemoteId,
                  'runtimeCursor': 3,
                },
              },
            },
          },
        );
        final opener = _SharedOpener();
        final container = await makeContainer(
          persistent: true,
          consent: true,
          autoOpen: false,
          workspaceGateway: gateway,
          workspaceId: workspaceId,
          serverRunsOverride: busyRuns,
          sharedOpenerOverride: opener.open,
        );

        await _waitForServerRun(container);

        expect(opener.calls, hasLength(1));
        final call = opener.calls.single;
        expect(call.runtimeKey, runtimeKey);
        expect(call.workingDirectory, cwd);
        expect(call.title, title);
        expect(call.remoteSessionId, acpRemoteId);
        expect(call.workspace['workspaceSessionId'], chatSessionId);
        expect(call.workspace['workspaceId'], workspaceId);

        // The controller asked the catalogue for exactly one runtime instead of
        // scanning the newest 100 entries and guessing.
        expect(gateway.runtimeCatalogRequests, isNotEmpty);
        for (final request in gateway.runtimeCatalogRequests) {
          expect(request['runtimeKey'], runtimeKey);
        }
        // Exact metadata hydration stays a bounded one-record lookup (the
        // subsequent session load may sync the same id again).
        final metadataRequests = gateway.snapshotRequests
            .where((request) => request['kind'] == 'chat_session')
            .toList();
        expect(metadataRequests, isNotEmpty);
        for (final request in metadataRequests) {
          expect(request['limit'], lessThanOrEqualTo(2));
          if (request['id'] != null) {
            expect(request['id'], chatSessionId);
          } else {
            expect(request['prefix'], startsWith(chatSessionId));
          }
        }

        final run = container.read(aiChatProvider).serverRun!;
        expect(run.sessionId, chatSessionId);
        expect(run.runtimeKey, runtimeKey);
        expect(run.agentId, _agentId);

        final repo = container.read(chatRepositoryProvider);
        final saved = await repo.loadSession(chatSessionId);
        expect(saved, isNotNull);
        expect(saved!.workingDirectory, cwd);
        final context = saved.agentContexts[_agentId]!;
        expect(context.persistentRuntimeKey, runtimeKey);
        expect(context.remoteSessionId, acpRemoteId);
        // No new runtime was created: the observer only attached to the one the
        // catalogue advertised, and the read-only transport never wrote.
        expect(opener.sessions.single._stdin.writes, isEmpty);
      },
    );

    test(
      'catalogue-only bootstrap reconstructs a stable session and reopens it',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'valhalla_reopen_test_',
        );
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
        final databasePath = '${dir.path}/chat.sqlite3';

        final firstGateway = _FakeWorkspaceGateway(
          runtimeCatalog: [catalogEntry()],
        );
        final firstOpener = _SharedOpener();
        final first = await makeContainer(
          persistent: true,
          consent: true,
          autoOpen: false,
          workspaceGateway: firstGateway,
          workspaceId: workspaceId,
          serverRunsOverride: busyRuns,
          sharedOpenerOverride: firstOpener.open,
          repositoryFactory: (storage, _) =>
              ChatRepository(storage, databasePath: databasePath),
        );

        await _waitForServerRun(first);

        expect(firstOpener.calls, hasLength(1));
        final firstCall = firstOpener.calls.single;
        expect(firstCall.runtimeKey, runtimeKey);
        expect(firstCall.workingDirectory, cwd);
        expect(firstCall.title, title);
        expect(firstCall.remoteSessionId, acpRemoteId);
        expect(firstCall.workspace['workspaceSessionId'], chatSessionId);
        expect(firstGateway.runtimeCatalogRequests, isNotEmpty);
        for (final request in firstGateway.runtimeCatalogRequests) {
          expect(request['runtimeKey'], runtimeKey);
        }
        // No chat_session checkpoint exists yet, so the exact lookup is bounded
        // and misses; the controller must fall back to bootstrap metadata.
        final firstMetadata = firstGateway.snapshotRequests
            .where((request) => request['kind'] == 'chat_session')
            .toList();
        expect(firstMetadata, isNotEmpty);
        for (final request in firstMetadata) {
          expect(request['limit'], lessThanOrEqualTo(2));
          if (request['id'] != null) {
            expect(request['id'], chatSessionId);
          } else {
            expect(request['prefix'], startsWith(chatSessionId));
          }
        }

        final firstRepo = first.read(chatRepositoryProvider);
        final reconstructed = await firstRepo.loadSession(chatSessionId);
        expect(reconstructed, isNotNull);
        expect(reconstructed!.workingDirectory, cwd);
        expect(reconstructed.title, title);
        expect(
          reconstructed.agentContexts[_agentId]!.persistentRuntimeKey,
          runtimeKey,
        );
        expect(
          reconstructed.agentContexts[_agentId]!.remoteSessionId,
          acpRemoteId,
        );
        // A synthetic fallback id would prove the identity is not stable.
        expect(await firstRepo.loadSession('runtime/$runtimeKey'), isNull);

        // Reopen in a fresh container against the same local store. The second
        // controller must find the reconstructed identity locally, without a
        // catalogue lookup or a second session.
        final secondGateway = _FakeWorkspaceGateway(
          runtimeCatalog: [catalogEntry()],
        );
        final secondOpener = _SharedOpener();
        final second = await makeContainer(
          persistent: true,
          consent: true,
          autoOpen: false,
          workspaceGateway: secondGateway,
          workspaceId: workspaceId,
          serverRunsOverride: busyRuns,
          sharedOpenerOverride: secondOpener.open,
          repositoryFactory: (storage, _) =>
              ChatRepository(storage, databasePath: databasePath),
        );

        await _waitForServerRun(second);

        expect(secondOpener.calls, hasLength(1));
        final secondCall = secondOpener.calls.single;
        expect(secondCall.runtimeKey, runtimeKey);
        expect(secondCall.workingDirectory, cwd);
        expect(secondCall.remoteSessionId, acpRemoteId);
        expect(secondCall.workspace['workspaceSessionId'], chatSessionId);
        expect(
          secondGateway.runtimeCatalogRequests,
          isEmpty,
          reason:
              'a known local runtime identity must not re-query the catalogue',
        );
        final secondRepo = second.read(chatRepositoryProvider);
        final reopened = await secondRepo.findRuntimeSession(
          'srv-1',
          runtimeKey,
        );
        expect(reopened?.id, chatSessionId);
        expect(reopened?.workingDirectory, cwd);
        expect(reopened?.agentContexts[_agentId]!.remoteSessionId, acpRemoteId);
      },
    );

    test(
      'foreign lease observer never writes initialize/load/prompt or stages chat',
      () async {
        var serverBusy = false;
        final gateway = _FakeWorkspaceGateway(
          runtimeCatalog: [catalogEntry()],
          foreignLease: true,
        );
        final opener = _SharedOpener();
        final session = ChatSession(
          id: 'observer-local',
          title: title,
          serverId: 'srv-1',
          agentId: _agentId,
          workingDirectory: cwd,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          messages: [
            ChatMessage(
              id: 'turn1',
              role: MessageRole.assistant,
              content: 'before',
              createdAt: DateTime.utc(2026),
              runtimeTurnId: 'turn1',
              status: ChatTurnStatus.streaming,
            ),
          ],
          agentContexts: {
            _agentId: const AgentChatContext(
              remoteSessionId: acpRemoteId,
              persistentRuntimeKey: runtimeKey,
              runtimeCursor: 5,
            ),
          },
        );
        final container = await makeContainer(
          persistent: true,
          consent: true,
          autoOpen: false,
          connected: false,
          readyAgents: const [_agentId, 'builtin-claude-code'],
          workspaceGateway: gateway,
          workspaceId: workspaceId,
          seedSessions: [session],
          serverRunsOverride: (client, serverId) async =>
              serverBusy ? await busyRuns(client, serverId) : const [],
          sharedOpenerOverride: opener.open,
        );

        // Simulate another device holding the lease before the observer attaches.
        final notifier = container.read(aiChatProvider.notifier);
        final seeded = await container
            .read(chatRepositoryProvider)
            .findRuntimeSession('srv-1', runtimeKey);
        expect(seeded?.id, session.id);
        expect(
          await notifier.acquireWorkspaceControl(
            serverId: 'srv-1',
            sessionId: session.id,
          ),
          isFalse,
        );
        expect(gateway.leaseRequests, isNotEmpty);

        serverBusy = true;
        // Connecting runs discovery exactly once, after the foreign lease is
        // already in place.
        final connection =
            container.read(serverConnectionProvider.notifier)
                as _ToggleConnection;
        connection.setConnected(true);
        await pumpEventQueue();
        await _waitForServerRun(container);

        expect(opener.calls, hasLength(1));
        final call = opener.calls.single;
        expect(call.runtimeKey, runtimeKey);
        expect(call.workingDirectory, cwd);
        expect(call.remoteSessionId, acpRemoteId);
        expect(call.workspace['workspaceSessionId'], session.id);
        expect(call.workspace.containsKey('controlToken'), isFalse);
        expect(opener.transports.single.workspaceReadOnly, isTrue);
        // A known local identity is enough; no catalogue or metadata scan.
        expect(gateway.runtimeCatalogRequests, isEmpty);
        // Session loads stay bounded: exact/prefix metadata lookups only, plus a
        // descending message tail. Never an unfiltered top-100 scan.
        final metadataRequests = gateway.snapshotRequests
            .where((request) => request['kind'] == 'chat_session')
            .toList();
        expect(metadataRequests, isNotEmpty);
        for (final request in metadataRequests) {
          expect(request['limit'], lessThanOrEqualTo(2));
          if (request['id'] != null) {
            expect(request['id'], session.id);
          } else {
            expect(request['prefix'], startsWith(session.id));
          }
        }
        for (final request in gateway.snapshotRequests.where(
          (request) => request['kind'] == 'chat_message',
        )) {
          expect(request['limit'], lessThanOrEqualTo(50));
          expect(request['descending'], isTrue);
          expect(request['prefix'], '${session.id}/');
        }

        // Replayed output arrives while attaching, then the app backgrounds and
        // the run checkpoints on its timer.
        opener.sessions.single.emitStdout(
          '${jsonEncode({
            'type': 'frame',
            'turnId': 'turn1',
            'seq': 6,
            'frame': {
              'jsonrpc': '2.0',
              'method': 'session/update',
              'params': {
                'sessionId': acpRemoteId,
                'update': {
                  'sessionUpdate': 'agent_message_chunk',
                  'messageId': 'a1',
                  'content': {'type': 'text', 'text': 'replayed'},
                },
              },
            },
          })}\n',
        );
        await pumpEventQueue();
        container.read(appVisibilityProvider.notifier).setForeground(false);
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        await pumpEventQueue();
        container.read(appVisibilityProvider.notifier).setForeground(true);
        await pumpEventQueue();

        // The real adapter's read-only fast path means the transport never
        // emitted initialize/session/new/session/load/session/prompt.
        expect(opener.sessions.single._stdin.writes, isEmpty);
        // Every checkpoint went to the local store only.
        expect(gateway.staged, isEmpty);

        final repo = container.read(chatRepositoryProvider);
        final local = await repo.loadSession(session.id);
        expect(local, isNotNull);
        expect(local!.messages.single.content, contains('replayed'));
        expect(local.agentContexts[_agentId]!.persistentRuntimeKey, runtimeKey);
      },
    );
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
