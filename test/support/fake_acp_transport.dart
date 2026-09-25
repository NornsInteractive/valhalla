import 'dart:async';

import 'package:acpd/acpd.dart';
import 'package:valhalla/data/models/agent_profile.dart';

/// A hand-written in-memory [Transport] pair used to drive the adapter in tests.
///
/// The [client] side is handed to production code under test; the [agent] side
/// is driven by the test to emulate a remote ACP agent without any real SSH or
/// process. Frames are decoded with acpd's own codec so framing stays honest.
class FakeAcpPair {
  FakeAcpPair({this.sessionId = 'session-1'}) {
    client.peer = agent;
    agent.peer = client;
    agent.onReceive = _handleAgentRequest;
  }

  final String sessionId;

  final FakeMemoryTransport client = FakeMemoryTransport();
  final FakeMemoryTransport agent = FakeMemoryTransport();

  /// Updates the fake agent streams before answering `session/prompt`.
  List<Map<String, Object?>> promptUpdates = const [];

  /// Auth methods the fake agent declares in its `initialize` response.
  List<Map<String, Object?>> authMethods = const [];

  /// When true, the fake agent answers `session/prompt` with a JSON-RPC error.
  bool failPrompt = false;

  /// JSON-RPC error code used when [failPrompt] (or [failSessionNew]) is set.
  /// Defaults to -32000 (`authRequired`) to mimic an unauthenticated agent.
  int promptErrorCode = -32000;

  /// When true, the fake agent answers `session/new` with an error instead.
  bool failSessionNew = false;

  /// When true, the fake agent answers `session/load` with an error.
  ///
  /// Used to exercise the load → resume → create fallback chain.
  bool failSessionLoad = false;

  /// When true, the fake agent answers `session/resume` with an error.
  bool failSessionResume = false;

  /// Every `sessionId` the client asked to load, in order.
  final List<String> loadRequests = [];

  /// Every `sessionId` the client asked to resume, in order.
  final List<String> resumeRequests = [];

  /// Every `cwd` sent with `session/new`, in order.
  final List<String> newSessionCwds = [];

  /// When true, the fake agent answers `authenticate` with an error.
  bool failAuthenticate = false;

  /// How many `authenticate` requests the fake agent received.
  int authenticateCallCount = 0;

  /// The `methodId` of the most recent `authenticate` request.
  String? lastAuthenticateMethodId;

  /// When true, the fake agent streams [promptUpdates] but does not answer
  /// `session/prompt`, leaving the turn open for the test to drive (e.g. to
  /// issue a mid-turn permission request).
  bool holdPrompt = false;

  /// Completes once the fake agent has received a `session/prompt` request.
  Future<void> get promptReceived => _promptReceived.future;
  Completer<void> _promptReceived = Completer<void>();

  /// Re-arms [promptReceived] so a later turn can be awaited again.
  void resetPromptReceived() {
    if (_promptReceived.isCompleted) {
      _promptReceived = Completer<void>();
    }
  }

  /// Every raw wire line the client sent to the agent, in order.
  List<String> get sentToAgent => client.outbound;

  /// Delivers a raw frame straight to the client.
  void deliverToClient(String wire) => client.deliver(wire);

  /// Answers a held `session/prompt` request with `end_turn`.
  void finishHeldPrompt() {
    _respondOk(_promptId, const {'stopReason': 'end_turn'});
  }

  Object? _promptId;

  void _handleAgentRequest(String wire) {
    final frame = TransportFrame.decode(wire);
    for (final message in frame.messages) {
      if (message is! RpcRequest) continue;
      switch (message.method) {
        case 'initialize':
          _respondOk(message.id, {
            'protocolVersion': 1,
            'agentCapabilities': <String, Object?>{},
            'authMethods': authMethods,
          });
        case 'authenticate':
          authenticateCallCount++;
          lastAuthenticateMethodId = _methodIdOf(message.params);
          if (failAuthenticate) {
            _respondError(message.id, -32000, 'authentication failed');
          } else {
            _respondOk(message.id, const <String, Object?>{});
          }
        case 'session/new':
          newSessionCwds.add(_cwdOf(message.params) ?? '');
          if (failSessionNew) {
            _respondError(
              message.id,
              promptErrorCode,
              'authentication required',
            );
          } else {
            _respondOk(message.id, {'sessionId': sessionId});
          }
        case 'session/load':
          final requested = _sessionIdOf(message.params) ?? '';
          loadRequests.add(requested);
          if (failSessionLoad) {
            _respondError(message.id, -32601, 'session/load not supported');
          } else {
            _respondOk(message.id, {
              'sessionId': requested.isEmpty ? sessionId : requested,
              'modes': null,
            });
          }
        case 'session/resume':
          final requested = _sessionIdOf(message.params) ?? '';
          resumeRequests.add(requested);
          if (failSessionResume) {
            _respondError(message.id, -32601, 'session/resume not supported');
          } else {
            _respondOk(message.id, {
              'sessionId': requested.isEmpty ? sessionId : requested,
              'modes': null,
            });
          }
        case 'session/prompt':
          _promptId = message.id;
          for (final update in promptUpdates) {
            _notifyUpdate(update);
          }
          if (!_promptReceived.isCompleted) _promptReceived.complete();
          if (holdPrompt) break;
          if (failPrompt) {
            _respondError(
              message.id,
              promptErrorCode,
              'authentication required',
            );
          } else {
            _respondOk(message.id, const {'stopReason': 'end_turn'});
          }
      }
    }
  }

  void _respondOk(Object? id, Object? result) {
    deliverToClient(
      '{"jsonrpc":"2.0","id":${_literal(id)},"result":${_value(result)}}',
    );
  }

  void _respondError(Object? id, int code, String message) {
    deliverToClient(
      '{"jsonrpc":"2.0","id":${_literal(id)},"error":{'
      '"code":$code,"message":${_literal(message)}}}',
    );
  }

  void _notifyUpdate(Map<String, Object?> update) {
    deliverToClient(
      '{"jsonrpc":"2.0","method":"session/update","params":{'
      '"sessionId":${_literal(sessionId)},'
      '"update":${_value(update)}}}',
    );
  }

  /// Extracts `methodId` from an `authenticate` request's params.
  String? _methodIdOf(Object? params) {
    if (params is Map) {
      final value = params['methodId'];
      if (value is String) return value;
    }
    return null;
  }

  /// Extracts `sessionId` from a session request's params.
  String? _sessionIdOf(Object? params) {
    if (params is Map) {
      final value = params['sessionId'];
      if (value is String) return value;
    }
    return null;
  }

  /// Extracts `cwd` from a session request's params.
  String? _cwdOf(Object? params) {
    if (params is Map) {
      final value = params['cwd'];
      if (value is String) return value;
    }
    return null;
  }

  void close() {
    client.close();
    agent.close();
  }
}

String _literal(Object? value) {
  if (value is String) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
    return '"$escaped"';
  }
  if (value is num || value is bool) return '$value';
  if (value == null) return 'null';
  return _value(value);
}

String _value(Object? value) {
  if (value is String || value is num || value is bool || value == null) {
    return _literal(value);
  }
  if (value is List) {
    return '[${value.map(_value).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries.map(
      (e) => '${_literal(e.key.toString())}:${_value(e.value)}',
    );
    return '{${entries.join(',')}}';
  }
  throw ArgumentError.value(value, 'value', 'Unsupported JSON value');
}

class FakeMemoryTransport implements Transport {
  final StreamController<TransportFrame> _incoming =
      StreamController<TransportFrame>.broadcast();

  late FakeMemoryTransport peer;
  void Function(String wire)? onReceive;

  /// Raw wire strings this side has sent out.
  final List<String> outbound = [];

  bool _closed = false;

  @override
  Stream<TransportFrame> get incoming => _incoming.stream;

  @override
  void send(TransportFrame frame) {
    if (_closed) return;
    final wire = frame.toWire();
    outbound.add(wire);
    final target = peer;
    if (target._closed) return;
    scheduleMicrotask(() {
      if (target._closed) return;
      target.onReceive?.call(wire);
      target._incoming.add(TransportFrame.decode(wire));
    });
  }

  void deliver(String wire) {
    if (_closed) return;
    onReceive?.call(wire);
    _incoming.add(TransportFrame.decode(wire));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _incoming.close();
  }
}

/// Convenience builder for the adapter's required [AgentProfile].
AgentProfile testAgentProfile({
  String id = 'builtin-claude-code',
  String serverId = 'srv-1',
  String acpCommand = 'claude-code-acp --stdio',
  String cliCommand = 'claude',
  String? installCommand,
  String? loginCheckCommand,
  String? loginCommand,
}) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
  description: 'test agent',
  cliCommand: cliCommand,
  acpCommand: acpCommand,
  installCommand: installCommand,
  loginCheckCommand: loginCheckCommand,
  loginCommand: loginCommand,
);
