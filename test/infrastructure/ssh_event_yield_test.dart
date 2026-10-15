// Regression test for SSHTransport and SSHChannelController event yielding.
// Exercises real vendored code: SSHTransport._processPackets and channel upload loop
// yield the event queue after ~4ms of packet/window processing.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/message/msg_channel.dart';
import 'package:dartssh2/src/message/msg_debug.dart';
import 'package:dartssh2/src/ssh_packet.dart';
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maximum time a single test body may run before the framework kills it.
const _bodyTimeout = Duration(seconds: 2);

/// Fake SSH socket with synchronous inbound controller and draining outbound sink.
class _FakeSshSocket implements SSHSocket {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<List<int>> _outgoing =
      StreamController<List<int>>.broadcast(sync: true);
  final Completer<void> _done = Completer<void>();

  bool _destroyed = false;

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    destroy();
  }

  @override
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) unawaited(_incoming.close());
    if (!_outgoing.isClosed) unawaited(_outgoing.close());
  }

  @override
  Future<void> flush() async {}

  /// Push bytes into the transport's receive path.
  void push(Uint8List bytes) {
    if (!_destroyed) _incoming.add(bytes);
  }

  /// Close the inbound stream (EOF).
  void closeIncoming() {
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}

/// Builds a cleartext SSH packet (no encryption) with the given payload.
Uint8List _packClear(Uint8List payload) {
  return SSHPacket.pack(payload, align: SSHPacket.minAlign);
}

/// Builds an SSH_MSG_DEBUG packet with the given index as message.
Uint8List _debugPacket(int index) {
  final msg = SSH_Message_Debug(
    alwaysDisplay: false,
    message: Uint8List.fromList(utf8.encode(index.toString())),
    language: Uint8List(0),
  );
  return _packClear(msg.encode());
}

/// Burn ~5ms to deterministically trigger the 4ms yield branch.
void _burn5ms() {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < 5) {}
}

Future<T> _withTimeout<T>(Future<T> Function() body) async {
  try {
    return await body().timeout(_bodyTimeout);
  } on TimeoutException {
    throw StateError('Test body timed out after $_bodyTimeout');
  }
}

void main() {
  group('SSHTransport event yielding', () {
    test('receiver yields + preserves order + natural EOF', () async {
      await _withTimeout(() async {
        final socket = _FakeSshSocket();
        addTearDown(socket.destroy);
        final debugIndices = <int>[];
        var timerRecordedCount = 0;
        var timerFired = false;

        Timer? timer;
        final transport = SSHTransport(
          socket,
          isServer: true,
          version: 'regression',
          printDebug: (msg) {
            if (msg != null && msg.startsWith('Remote: ')) {
              final idx = int.parse(msg.substring('Remote: '.length));
              debugIndices.add(idx);
              if (!timerFired) {
                timerFired = true;
                timer = Timer(Duration.zero, () {
                  timerRecordedCount = debugIndices.length;
                });
                _burn5ms();
              }
            }
          },
        );
        addTearDown(() => timer?.cancel());

        final banner = utf8.encode('SSH-2.0-regression\r\n');
        final frames = <Uint8List>[];
        for (var i = 0; i < 6; i++) {
          frames.add(_debugPacket(i));
        }
        final combined = Uint8List.fromList([
          ...banner,
          ...frames.expand((f) => f),
        ]);
        socket.push(combined);
        socket.closeIncoming();

        await transport.done;

        expect(debugIndices, equals([0, 1, 2, 3, 4, 5]));
        expect(timerRecordedCount, greaterThan(0));
        expect(timerRecordedCount, lessThan(6));
      });
    });

    test('EOF rescheduling regression', () async {
      await _withTimeout(() async {
        final socket = _FakeSshSocket();
        addTearDown(socket.destroy);
        final debugIndices = <int>[];

        final transport = SSHTransport(
          socket,
          isServer: true,
          version: 'regression',
          printDebug: (msg) {
            if (msg != null && msg.startsWith('Remote: ')) {
              final idx = int.parse(msg.substring('Remote: '.length));
              debugIndices.add(idx);
            }
          },
        );

        final banner = utf8.encode('SSH-2.0-regression\r\n');
        socket.push(Uint8List.fromList(banner));

        final frames = <Uint8List>[];
        for (var i = 0; i < 6; i++) {
          frames.add(_debugPacket(i));
        }
        socket.push(Uint8List.fromList(frames.expand((f) => f).toList()));

        socket.closeIncoming();

        await transport.done;

        expect(debugIndices, equals([0, 1, 2, 3, 4, 5]));
      });
    });
  });

  group('SSHChannelController event yielding', () {
    test('upload yields + ordering', () async {
      await _withTimeout(() async {
        late final SSHChannelController controller;
        final sentBytes = <int>[];
        var timerRecordedCount = 0;
        var timerFired = false;
        final completer = Completer<void>();

        Timer? timer;
        controller = SSHChannelController(
          localId: 0,
          localMaximumPacketSize: 32768,
          localInitialWindowSize: 65536,
          remoteId: 1,
          remoteInitialWindowSize: 65536,
          remoteMaximumPacketSize: 1,
          sendMessage: (msg) {
            if (msg is SSH_Message_Channel_Data) {
              sentBytes.addAll(msg.data);
              if (!timerFired) {
                timerFired = true;
                timer = Timer(Duration.zero, () {
                  timerRecordedCount = sentBytes.length;
                });
                _burn5ms();
              }
              if (sentBytes.length == 6) {
                completer.complete();
              }
            }
          },
          printDebug: (msg) {},
        );
        addTearDown(controller.destroy);
        addTearDown(() => timer?.cancel());

        controller.channel.addData(Uint8List.fromList([0, 1, 2, 3, 4, 5]));

        await completer.future;

        expect(sentBytes, equals([0, 1, 2, 3, 4, 5]));
        expect(timerRecordedCount, greaterThan(0));
        expect(timerRecordedCount, lessThan(6));
      });
    });

    test('destroy during yield', () async {
      await _withTimeout(() async {
        late final SSHChannelController controller;
        final sentBytes = <int>[];
        var destroyScheduled = false;

        controller = SSHChannelController(
          localId: 0,
          localMaximumPacketSize: 32768,
          localInitialWindowSize: 65536,
          remoteId: 1,
          remoteInitialWindowSize: 65536,
          remoteMaximumPacketSize: 1,
          sendMessage: (msg) {
            if (msg is SSH_Message_Channel_Data) {
              sentBytes.addAll(msg.data);
              if (!destroyScheduled) {
                destroyScheduled = true;
                Timer.run(() {
                  controller.destroy();
                });
                _burn5ms();
              }
            }
          },
          printDebug: (msg) {},
        );
        addTearDown(controller.destroy);

        controller.channel.addData(Uint8List.fromList([0, 1, 2, 3, 4, 5]));

        await controller.channel.done;
        await Future<void>.delayed(Duration.zero);

        expect(sentBytes.length, equals(1));
        expect(sentBytes[0], equals(0));
      });
    });

    test('window adjust during yield', () async {
      await _withTimeout(() async {
        late final SSHChannelController controller;
        final sentBytes = <int>[];
        var adjustRecordedCount = 0;
        var adjustDone = false;
        final completer = Completer<void>();

        controller = SSHChannelController(
          localId: 0,
          localMaximumPacketSize: 32768,
          localInitialWindowSize: 65536,
          remoteId: 1,
          remoteInitialWindowSize: 2,
          remoteMaximumPacketSize: 1,
          sendMessage: (msg) {
            if (msg is SSH_Message_Channel_Data) {
              sentBytes.addAll(msg.data);
              if (!adjustDone) {
                adjustDone = true;
                Timer.run(() {
                  adjustRecordedCount = sentBytes.length;
                  controller.handleMessage(
                    SSH_Message_Channel_Window_Adjust(
                      recipientChannel: 0,
                      bytesToAdd: 3,
                    ),
                  );
                });
                _burn5ms();
              }
              if (sentBytes.length == 5) {
                completer.complete();
              }
            }
          },
          printDebug: (msg) {},
        );
        addTearDown(controller.destroy);

        controller.channel.addData(Uint8List.fromList([0, 1, 2, 3, 4]));

        await completer.future;

        expect(adjustRecordedCount, equals(1));
        expect(sentBytes, equals([0, 1, 2, 3, 4]));
      });
    });
  });
}
