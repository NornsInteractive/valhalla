import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';

import '../../core/logging/sanitizer.dart';
import 'acp_oauth_request.dart';

/// ACP transport backed by one SSH exec channel carrying newline-delimited JSON.
/// The protocol framing and request correlation remain owned by [acpd].
class AcpSshTransport implements LineTransport {
  final SSHSession session;
  final StreamController<TransportFrame> _incoming =
      StreamController<TransportFrame>(sync: true);
  final String? runtimeKey;
  bool get isPersistent => runtimeKey != null;
  int lastSequence = 0;
  String? currentTurnId;
  String? outgoingTurnId;
  String? runtimeState;
  String? runtimeSessionId;
  String? runtimeTurnId;
  bool backlogCaughtUp = false;
  final Completer<void> _attached = Completer<void>();
  Future<void> get attached => _attached.future;
  final _runtimeEvents = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final _frameMetadata = Queue<Map<String, dynamic>>();
  Stream<Map<String, dynamic>> get runtimeEvents => _runtimeEvents.stream;
  StreamSubscription<String>? _subscription;
  StreamSubscription<String>? _stderrSubscription;
  String _diagnosticTail = '';
  String get diagnosticTail => _diagnosticTail;
  int? get exitCode => session.exitCode;
  bool _closed = false;
  bool _detaching = false;
  void detachWrites() => _detaching = true;
  bool _paused = false;
  final _authorizationRequests = StreamController<AcpOAuthRequest>.broadcast();
  Stream<AcpOAuthRequest> get authorizationRequests =>
      _authorizationRequests.stream;
  String _authLine = '';
  bool _oversizedAuthLine = false;

  void _captureAuthorization(String text) {
    for (final part in text.split('\n').indexed) {
      if (part.$1 > 0) {
        if (!_oversizedAuthLine) {
          final request = AcpOAuthRequest.fromLine(_authLine);
          if (request != null && !_closed) _authorizationRequests.add(request);
        }
        _authLine = '';
        _oversizedAuthLine = false;
      }
      if (_authLine.length + part.$2.length > 16384) {
        _authLine = '';
        _oversizedAuthLine = true;
      } else if (!_oversizedAuthLine) {
        _authLine += part.$2;
      }
    }
  }

  AcpSshTransport(this.session, {this.runtimeKey, int afterSequence = 0}) {
    lastSequence = afterSequence;
    if (!isPersistent) _attached.complete();
    _stderrSubscription =
        LogSanitizer.stream(
          session.stderr
              .cast<List<int>>()
              .transform(const Utf8Decoder(allowMalformed: true))
              .map((text) {
                _captureAuthorization(text);
                return text;
              }),
        ).listen(
          (text) {
            _diagnosticTail += text;
            if (_diagnosticTail.length > 8192) {
              _diagnosticTail = _diagnosticTail.substring(
                _diagnosticTail.length - 8192,
              );
            }
          },
          onError: (Object error) {
            _diagnosticTail = LogSanitizer.sanitize(error.toString());
          },
        );
    _subscription = session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (_closed) return;
            if (line.trim().isNotEmpty) {
              try {
                if (isPersistent) {
                  final envelope = jsonDecode(line) as Map<String, dynamic>;
                  final type = envelope['type'];
                  if (type == 'status' || type == 'caught_up') {
                    runtimeTurnId = envelope['turnId'] as String?;
                  }
                  final frame = envelope['frame'];
                  if (type == 'frame' && frame is Map) {
                    final decoded = TransportFrame.decode(jsonEncode(frame));
                    _frameMetadata.add(envelope);
                    _incoming.add(decoded);
                  } else if (type == 'runtime_error') {
                    final error = StateError(
                      envelope['error'] as String? ?? 'ACP_RUNTIME_FAILED',
                    );
                    if (!_attached.isCompleted) _attached.completeError(error);
                    _incoming.addError(error);
                  } else {
                    if (envelope['state'] is String) {
                      runtimeState = envelope['state'] as String;
                    }
                    if (envelope['sessionId'] is String) {
                      runtimeSessionId = envelope['sessionId'] as String;
                    }
                    _frameMetadata.add(envelope);
                    _incoming.add(
                      TransportFrame.decode(
                        jsonEncode({
                          'jsonrpc': '2.0',
                          'method': '_valhalla/runtime',
                          'params': envelope,
                        }),
                      ),
                    );
                    if ((type == 'status' || type == 'caught_up') &&
                        !_attached.isCompleted) {
                      _attached.complete();
                    }
                  }
                } else {
                  _incoming.add(TransportFrame.decode(line));
                }
              } catch (error, stack) {
                // A malformed stdout frame is a transport failure, not an
                // uncaught callback exception which leaves prompt awaiting forever.
                _incoming.addError(error, stack);
              }
            }
          },
          onError: _incoming.addError,
          onDone: () {
            if (!_attached.isCompleted) {
              _attached.completeError(StateError('ACP_RUNTIME_ATTACH_FAILED'));
            }
            if (!_incoming.isClosed) _incoming.close();
          },
        );
  }

  @override
  Stream<TransportFrame> get incoming => _incoming.stream.map((frame) {
    if (isPersistent) {
      final metadata = _frameMetadata.removeFirst();
      currentTurnId = metadata['turnId'] as String?;
      if (metadata['seq'] is int && metadata['type'] != 'status') {
        final seq = metadata['seq'] as int;
        if (seq > lastSequence) lastSequence = seq;
      }
      if (metadata['type'] != 'frame') {
        if (metadata['type'] == 'caught_up') backlogCaughtUp = true;
        _runtimeEvents.add(metadata);
      }
    }
    return frame;
  });

  void pauseIncoming() {
    if (!_paused) {
      _paused = true;
      _subscription?.pause();
    }
  }

  void resumeIncoming() {
    if (_paused) {
      _paused = false;
      _subscription?.resume();
    }
  }

  @override
  void send(TransportFrame frame) {
    if (_closed || _detaching) return;
    final line = isPersistent
        ? '${jsonEncode({'frame': jsonDecode(frame.toLine()), 'turnId': outgoingTurnId})}\n'
        : frame.toLine();
    session.stdin.add(utf8.encode(line));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    unawaited(_runtimeEvents.close());
    _authLine = '';
    unawaited(_authorizationRequests.close());
    // End the SSH streams before awaiting cancellation of the async sanitizer.
    session.close();
    await _subscription?.cancel();
    await _stderrSubscription?.cancel();
    // A channel can fail cwd/runtime preparation before ACP subscribes. A
    // single-subscription controller's close future then waits for a listener
    // that will never arrive; do not block disposing that unopened connection.
    if (_incoming.hasListener) {
      await _incoming.close();
    } else {
      unawaited(_incoming.close());
    }
  }
}
