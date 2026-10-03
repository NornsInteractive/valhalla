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
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_acp_transport.dart';
import '../support/temp_chat_db.dart';

/// `claimAuthBrowserLaunch` is the shared synchronous claim that keeps the
/// retained shell view and a modal chat view from auto-opening two browser
/// tabs for one live authorization request. Exactly one claim per request,
/// no claim once the attempt is cancelled, and a fresh claim for a new attempt.
///
/// The harness bridges a real `AcpSshTransport` (so the adapter subscribes to
/// `authorizationRequests`) onto the in-memory fake agent; the "SSH" side only
/// ever sees newline-delimited JSON and a canned `pwd` probe.
const _marker = 'Open the following link to authenticate the ACP server: ';

AgentProfile _agy() => AgentProfile(
  id: 'builtin-agy',
  serverId: 'srv-1',
  name: 'Antigravity AGY',
  description: 'desc',
  cliCommand: 'agy',
  acpCommand: 'agy_acp_server.par',
  loginCommand: 'agy',
  loginCheckCommand: 'probe',
);

String _authLine(int port, String state) =>
    '$_marker'
    'https://accounts.google.com/o/oauth2/v2/auth'
    '?response_type=code&client_id=cid.apps.googleusercontent.com'
    '&redirect_uri=${Uri.encodeComponent('http://127.0.0.1:$port/cb')}'
    '&state=$state';

Future<int> _freePort() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

class _AllReadyRegistry extends AgentRegistryNotifier {
  _AllReadyRegistry(this.profile);

  final AgentProfile profile;

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.utc(2026),
        ),
      ),
    ],
  );
}

class _StaticConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
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

/// Redirects the transport's exec channel onto the fake agent's wire side.
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

  void emitStderr(String text) {
    if (!_stderr.isClosed) _stderr.add(utf8.encode(text));
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
  void close() {
    if (!_stdin.isClosed) _stdin.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_stdout.isClosed) _stdout.close();
  }

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

void main() {
  late FakeAcpPair pair;
  late _BridgeSession session;
  void Function(FakeAcpPair)? configurePair;

  const methods = [
    {'id': 'oauth', 'name': 'OAuth'},
  ];

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    return ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(() => _AllReadyRegistry(_agy())),
        serverConnectionProvider.overrideWith(() => _StaticConnection()),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        acpTransportFactoryProvider.overrideWithValue((_, _) async {
          pair = FakeAcpPair();
          configurePair?.call(pair);
          session = _BridgeSession(pair);
          return AcpSshTransport(session);
        }),
      ],
    );
  }

  Future<AiChatNotifier> ready(ProviderContainer c) async {
    final notifier = c.read(aiChatProvider.notifier);
    c.read(aiChatProvider);
    await pumpEventQueue();
    expect(c.read(aiChatProvider).activeAgentProfile?.id, 'builtin-agy');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (c.read(aiChatProvider).isLoadingSessions ||
        c.read(aiChatProvider).isLoadingMessages) {
      if (DateTime.now().isAfter(deadline)) {
        fail('history loading never settled');
      }
      await pumpEventQueue();
    }
    return notifier;
  }

  /// Drives initialize-only discovery, then feeds one challenge line so the
  /// adapter publishes a live authorization request to the provider.
  Future<AcpOAuthRequest> startAttempt(
    ProviderContainer c,
    AiChatNotifier notifier,
    String state,
  ) async {
    await notifier.requestAuthentication();
    await pumpEventQueue();
    expect(c.read(aiChatProvider).authChallenge, isNotNull);

    final port = await _freePort();
    session.emitStderr('${_authLine(port, state)}\n');
    await pumpEventQueue();

    final request = c.read(aiChatProvider).authRequest;
    expect(request, isNotNull, reason: 'the attempt must publish a request');
    expect(c.read(aiChatProvider).isAuthenticating, isTrue);
    return request!;
  }

  tearDown(() {
    configurePair = null;
  });

  test('only one view may auto-open the browser for a live request', () async {
    configurePair = (p) => p.authMethods = methods;
    final c = await container();
    addTearDown(c.dispose);
    final notifier = await ready(c);

    final request = await startAttempt(c, notifier, 'claim-state-1');

    expect(notifier.claimAuthBrowserLaunch(request), isTrue);
    expect(
      notifier.claimAuthBrowserLaunch(request),
      isFalse,
      reason: 'a second retained/modal view must not open a second tab',
    );

    final other = AcpOAuthRequest.fromLine(
      _authLine(request.redirectUri.port, 'claim-state-2'),
    );
    expect(other, isNotNull);
    expect(
      notifier.claimAuthBrowserLaunch(other!),
      isFalse,
      reason: 'a request that is not the live one is never claimable',
    );
  });

  test(
    'cancelling releases the claim so the next attempt can auto-open',
    () async {
      configurePair = (p) => p.authMethods = methods;
      final c = await container();
      addTearDown(c.dispose);
      final notifier = await ready(c);

      final first = await startAttempt(c, notifier, 'claim-state-1');
      expect(notifier.claimAuthBrowserLaunch(first), isTrue);

      await notifier.respondAuth(null);
      await pumpEventQueue();

      expect(c.read(aiChatProvider).isAuthenticating, isFalse);
      expect(
        notifier.claimAuthBrowserLaunch(first),
        isFalse,
        reason: 'a cancelled attempt can never be auto-opened again',
      );

      final second = await startAttempt(c, notifier, 'claim-state-3');
      expect(identical(second, first), isFalse);
      expect(
        notifier.claimAuthBrowserLaunch(second),
        isTrue,
        reason: 'the claim resets for a fresh attempt',
      );
    },
  );
}
