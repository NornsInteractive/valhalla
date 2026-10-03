import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/acp/agy_saved_auth_probe.dart';

import '../support/fake_acp_transport.dart';

/// The saved-credential probe must be read-only and must never take over the
/// login flow: it may only confirm that stored official credentials still work
/// (initialize + authenticate) and otherwise report unknown/unauthenticated.
const _marker = 'Open the following link to authenticate the ACP server: ';

AgentProfile _agy() => AgentProfile(
  id: 'builtin-agy',
  serverId: 'srv-1',
  name: 'Antigravity',
  description: 'official ACP agent',
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

/// Exec channel bridging the ACP wire to the in-memory fake agent, with an
/// observable stderr so a new authorization challenge can be delivered.
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

  /// Every JSON-RPC method the probe sent towards the agent, in order.
  final List<String> agentSawMethods = [];

  void emitStderr(String text) {
    if (!_stderr.isClosed) _stderr.add(utf8.encode(text));
  }

  /// Kills the channel mid-flight to model a dropped connection.
  void dropChannel() {
    if (!_stdout.isClosed) _stdout.close();
  }

  /// True once either side closed the channel (the probe releases it).
  bool get closed => _stdout.isClosed || _stdin.isClosed;

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

void main() {
  const oauthMethods = [
    {'id': 'oauth', 'name': 'OAuth'},
  ];

  late FakeAcpPair pair;
  late _BridgeSession session;

  AcpSshTransport openTransport() {
    pair = FakeAcpPair()..authMethods = oauthMethods;
    session = _BridgeSession(pair);
    // Observe every request the probe actually puts on the wire.
    final handle = pair.agent.onReceive!;
    pair.agent.onReceive = (wire) {
      final decoded = jsonDecode(wire);
      if (decoded is Map && decoded['method'] is String) {
        session.agentSawMethods.add(decoded['method'] as String);
      }
      handle(wire);
    };
    return AcpSshTransport(session);
  }

  test('authenticate RPC success confirms the saved credentials', () async {
    final transport = openTransport();
    addTearDown(transport.close);

    final status = await probeAgySavedAuth(
      _agy(),
      'oauth',
      () async => transport,
    );

    expect(status, AgentAuthenticationStatus.authenticated);
    expect(pair.authenticateCallCount, 1);
    expect(pair.lastAuthenticateMethodId, 'oauth');
    expect(pair.newSessionCount, 0, reason: '只允许 initialize/authenticate');
    expect(
      session.agentSawMethods,
      containsAllInOrder(['initialize', 'authenticate']),
      reason: '探针只用 initialize/authenticate 判定已保存凭据',
    );
    expect(
      session.agentSawMethods,
      isNot(contains('session/prompt')),
      reason: '只读探针绝不发提示词',
    );
    expect(session.agentSawMethods, isNot(contains('session/new')));
  });

  test('auth-required error reports unauthenticated, not unknown', () async {
    final transport = openTransport();
    addTearDown(transport.close);
    pair.failAuthenticate = true; // answers with -32000 authRequired

    final status = await probeAgySavedAuth(
      _agy(),
      'oauth',
      () async => transport,
    );

    expect(status, AgentAuthenticationStatus.unauthenticated);
    expect(pair.newSessionCount, 0);
    expect(session.agentSawMethods, isNot(contains('session/new')));
    expect(session.agentSawMethods, isNot(contains('session/prompt')));
  });

  test(
    'a dropped connection stays unknown instead of unauthenticated',
    () async {
      final transport = openTransport();
      addTearDown(transport.close);
      // Keep authenticate open, then kill the channel so the probe is waiting
      // on a reply that can never arrive.
      pair.holdAuthenticate = true;

      final pending = probeAgySavedAuth(_agy(), 'oauth', () async => transport);
      // Let initialize/authenticate reach the agent, then drop the channel.
      await pumpEventQueue();
      expect(pair.authenticateCallCount, 1);
      session.dropChannel();

      final status = await pending;

      expect(
        status,
        AgentAuthenticationStatus.unknown,
        reason: '连不上网不能被误判成未登录',
      );
      expect(pair.newSessionCount, 0);
    },
  );

  test(
    'a new authorization challenge cancels the probe without a browser',
    () async {
      final transport = openTransport();
      addTearDown(transport.close);
      // Hold authenticate open so the probe is genuinely mid-flight when the
      // agent decides it needs interactive re-auth.
      pair.holdAuthenticate = true;

      final pending = probeAgySavedAuth(_agy(), 'oauth', () async => transport);
      // Let initialize/authenticate reach the agent, then feed one challenge.
      await pumpEventQueue();
      final port = await _freePort();
      session.emitStderr('${_authLine(port, 'probe-state')}\n');
      await pumpEventQueue();

      final status = await pending;

      expect(status, AgentAuthenticationStatus.unauthenticated);
      expect(pair.authenticateCallCount, 1);
      expect(pair.newSessionCount, 0, reason: 'challenge 不建会话');
      expect(
        session.agentSawMethods,
        isNot(contains('session/prompt')),
        reason: 'challenge 不发提示词',
      );
      expect(session.agentSawMethods, isNot(contains('session/new')));
      expect(session.closed, isTrue, reason: '取消后必须释放远端通道');
    },
  );

  test(
    'a transport that opens after the timeout is closed, not leaked',
    () async {
      final gate = Completer<void>();
      late AcpSshTransport lateTransport;

      final status = await probeAgySavedAuth(_agy(), 'oauth', () async {
        await gate.future; // arrives only after the probe gave up
        lateTransport = openTransport();
        return lateTransport;
      }).timeout(const Duration(seconds: 40));

      expect(status, AgentAuthenticationStatus.unknown);

      gate.complete();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(lateTransport, isNotNull, reason: 'transport 迟到打开了');
      expect(session.closed, isTrue, reason: '超时的探针仍必须关掉迟到的 transport');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
