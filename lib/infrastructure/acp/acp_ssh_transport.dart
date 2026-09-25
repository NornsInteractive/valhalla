import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';

/// ACP transport backed by one SSH exec channel carrying newline-delimited JSON.
/// The protocol framing and request correlation remain owned by [acpd].
class AcpSshTransport implements LineTransport {
  final SSHSession session;
  final StreamController<TransportFrame> _incoming =
      StreamController<TransportFrame>();
  StreamSubscription<String>? _subscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  bool _closed = false;

  AcpSshTransport(this.session) {
    _stderrSubscription = session.stderr.listen((_) {});
    _subscription = session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (_closed) return;
            if (line.trim().isNotEmpty) {
              _incoming.add(TransportFrame.decode(line));
            }
          },
          onError: _incoming.addError,
          onDone: () {
            if (!_incoming.isClosed) _incoming.close();
          },
        );
  }

  @override
  Stream<TransportFrame> get incoming => _incoming.stream;

  @override
  void send(TransportFrame frame) {
    if (_closed) return;
    session.stdin.add(utf8.encode(frame.toLine()));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _stderrSubscription?.cancel();
    await _incoming.close();
    session.close();
  }
}
