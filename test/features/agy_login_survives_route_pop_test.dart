import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// Scope note: this keeps the whole `ProviderContainer` alive and pops *only*
/// the management route, unlike the container-disposal test. The in-flight
/// official AgY discovery must survive the pop and still publish the methods it
/// declared — and it must never escalate into a session or a prompt.
void main() {
  final testServer = ServerProfile(
    id: 'srv-1',
    name: 'racknerd',
    host: 'example.test',
    port: 22,
    username: 'root',
    authType: AuthType.password,
  );

  final agy = AgentProfile(
    id: 'builtin-agy',
    serverId: 'srv-1',
    name: 'Antigravity',
    description: 'official ACP agent',
    cliCommand: 'agy',
    acpCommand: 'agy_acp_server.par',
    loginCommand: 'agy',
    loginCheckCommand: kAntigravityLoginCheckCommand,
  );

  const declaredMethods = [
    {'id': 'oauth-personal', 'name': 'Sign in with Google'},
  ];

  late FakeAcpPair pair;
  late _BridgeSession session;
  late Completer<void> initializeGate;
  late List<String> agentSawMethods;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    agentSawMethods = [];
    initializeGate = Completer<void>();
    pair = FakeAcpPair()..authMethods = declaredMethods;
    // Hold `initialize` on the wire until the test releases it.
    final handle = pair.agent.onReceive!;
    pair.agent.onReceive = (wire) {
      final decoded = jsonDecode(wire);
      if (decoded is Map && decoded['method'] is String) {
        agentSawMethods.add(decoded['method'] as String);
      }
      if (decoded is Map && decoded['method'] == 'initialize') {
        initializeGate.future.then((_) => handle(wire));
        return;
      }
      handle(wire);
    };
    session = _BridgeSession(pair);
  });

  testWidgets(
    'official AgY: popping only the management route keeps the in-flight '
    'initialize alive and still declares its auth methods',
    (tester) async {
      final storage = await LocalStorageService.init();
      addTearDown(session.close);

      // Own the container so it outlives the management route. This is the
      // whole point: only the route is popped, the provider must live.
      final container = ProviderContainer(
        overrides: [
          tempChatRepositoryOverride(),
          localStorageServiceProvider.overrideWithValue(storage),
          activeServerProvider.overrideWith(() => _FixedServer(testServer)),
          serverConnectionProvider.overrideWith(
            () => _FixedConnection(testServer.id),
          ),
          agentRegistryProvider.overrideWith(() => _ReadyRegistry(agy)),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          acpTransportFactoryProvider.overrideWithValue(
            (_, _) async => AcpSshTransport(session),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => AgentManagementView(
                onNavigateToChat: () {
                  // Pop only the management route; the container stays alive.
                  final navigator = Navigator.of(context);
                  navigator.pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('chat host')),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(
        const Key('agent_acp_callout_login_builtin-agy'),
      );
      expect(button, findsOneWidget);

      // The login handler no-ops while the chat provider is still loading, so
      // wait for it to settle before tapping (same as a real user would).
      final settleDeadline = DateTime.now().add(const Duration(seconds: 15));
      while (true) {
        final s = container.read(aiChatProvider);
        if (!s.isLoadingSettings &&
            !s.isLoadingSessions &&
            !s.isLoadingMessages) {
          break;
        }
        if (DateTime.now().isAfter(settleDeadline)) {
          fail(
            'chat provider never settled: settings=${s.isLoadingSettings} '
            'sessions=${s.isLoadingSessions} messages=${s.isLoadingMessages}',
          );
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        container.read(aiChatProvider).activeAgentProfile?.id,
        'builtin-agy',
      );

      await tester.tap(button);
      await tester.pump();

      // Discovery is async and the real temp ChatRepository uses a worker
      // isolate, so the fake clock alone does not give its IO wall time.
      // Yield real time in bounded steps and pump to flush the fake zone.
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!agentSawMethods.contains('initialize')) {
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'official AgY never sent initialize; saw $agentSawMethods '
            '(authError=${container.read(aiChatProvider).authError})',
          );
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(
        agentSawMethods,
        contains('initialize'),
        reason: '官方 profile 走真实 ACP initialize，不是 no-op',
      );
      expect(
        find.text('chat host'),
        findsOneWidget,
        reason: '管理路由已被替换（模拟只弹栈不销毁 provider）',
      );

      // Let the route transition finish so the management subtree is really
      // gone while the initialize reply is still being held back.
      final leaveDeadline = DateTime.now().add(const Duration(seconds: 15));
      while (find.byType(AgentManagementView).evaluate().isNotEmpty) {
        if (DateTime.now().isAfter(leaveDeadline)) {
          fail('the management route was never removed');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AgentManagementView), findsNothing);

      // Initialize is still unanswered; the in-flight request must survive.
      initializeGate.complete();
      final challengeDeadline = DateTime.now().add(const Duration(seconds: 15));
      while (container.read(aiChatProvider).authChallenge == null) {
        if (DateTime.now().isAfter(challengeDeadline)) {
          fail(
            'methods never landed after the route pop; '
            'authError=${container.read(aiChatProvider).authError} '
            'saw=$agentSawMethods',
          );
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pump();

      final challenge = container.read(aiChatProvider).authChallenge;
      expect(challenge, isNotNull, reason: '方法发现必须在弹栈后仍然落地');
      expect(challenge!.agentId, 'builtin-agy');
      expect(challenge.methods.map((m) => m.id), ['oauth-personal']);
      expect(
        agentSawMethods,
        contains('initialize'),
        reason: '声明的认证方式来自 initialize 公布的 authMethods',
      );
      expect(
        agentSawMethods,
        isNot(contains('authenticate')),
        reason: '方法发现阶段不得真的发起认证',
      );
      expect(
        agentSawMethods,
        isNot(contains('session/new')),
        reason: '只做方法发现，不得建会话',
      );
      expect(agentSawMethods, isNot(contains('session/prompt')));
      expect(find.text('chat host'), findsOneWidget, reason: '聊天页仍然在场');
      expect(tester.takeException(), isNull);
    },
  );
}

class _BridgeSession implements SSHSession {
  _BridgeSession(this.pair) {
    _stdin.stream.listen((bytes) {
      final wire = utf8.decode(bytes, allowMalformed: true).trim();
      if (wire.isNotEmpty) pair.agent.deliver(wire);
    });
    pair.client.onReceive = (wire) {
      if (!_stdout.isClosed) _stdout.add(utf8.encode('$wire\n'));
    };
  }

  final FakeAcpPair pair;
  final StreamController<Uint8List> _stdout = StreamController<Uint8List>();
  final StreamController<Uint8List> _stderr =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _stdin = StreamController<Uint8List>();

  @override
  void close() {
    if (!_stdin.isClosed) _stdin.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_stdout.isClosed) _stdout.close();
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  int? get exitCode => null;

  @override
  Future<void> get done => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

class _FakeSshClient implements SSHClient {
  static final Uint8List _root = Uint8List.fromList(utf8.encode('/root/work'));

  @override
  Future<SSHRunResult> runWithResult(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) async => SSHRunResult(
    output: _root,
    stdout: _root,
    stderr: Uint8List(0),
    exitCode: 0,
    exitSignal: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadyRegistry extends AgentRegistryNotifier {
  _ReadyRegistry(this.profile);

  final AgentProfile profile;

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          detail: 'AGY_ACP_SIGN_IN_REQUIRED',
          authentication: AgentAuthenticationStatus.unauthenticated,
          checkedAt: DateTime.utc(2026),
        ),
      ),
    ],
  );
}

class _FixedServer extends ActiveServerNotifier {
  _FixedServer(this._server);
  final ServerProfile _server;

  @override
  ServerProfile? build() => _server;
}

class _FixedConnection extends ServerConnectionNotifier {
  _FixedConnection(this._serverId);
  final String _serverId;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: _serverId,
  );
}
