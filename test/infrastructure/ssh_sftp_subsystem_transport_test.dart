// Deterministic regression for the SFTP subsystem transport contract.
//
// dartssh2 4.1.0's SSHClient.sftp() (ssh_client.dart, the `sftp()` body) sends
// `subsystem sftp` through SSHChannelController.sendSubsystem() without
// awaiting the Future that call returns. Every failure of that request then
// completes a Future nobody observes, so the error reaches the zone instead of
// the caller. The local proof
// /tmp/valhalla-app-center.ShesTL/ssh_unhandled_probe.dart reproduces it on the
// shared pub-cache copy with no network server at all:
//
//   ping: unhandled=0
//   sftp-subsystem-pending: unhandled=1
//   SSHStateError(SSH connection closed)
//
// These tests pin the contract the owning layer needs: every public operation
// is awaited by its caller and fails loudly, and nothing escapes into the zone
// unobserved. They are expected RED against the shared pub-cache copy until
// Root vendors/fixes the dependency. Do not relax the assertions and do not
// edit the shared pub cache to make them green.
//
// The two send-failure tests deliberately do not close the fake socket's write
// side. This fixture client never completes key exchange, so
// `SSHTransport.sendPacket` parks every application packet in its rekey buffer
// (`_kexInProgress`/`_rekeyPendingPackets`) and never reaches the sink, which
// makes a faulted sink unreachable and the operation simply pend forever.
// Instead `_SendFault` uses the [SSHClient.printTrace] hook: `_sendMessage`
// calls it before it hands the packet to the transport, so a throw there lands
// inside the very `try` that guards the CHANNEL_OPEN send
// (`SSHClient._openChannel`) and the subsystem request send
// (`SSHChannelController._sendRequest`) - the same reserved-reply failure
// branches a real socket write failure takes - with no handshake and no
// mirrored library code.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// SSH_Message_* protocol records are not exported by the package's public API;
// dartssh2's own tests import the implementation library the same way.
// ignore: implementation_imports
import 'package:dartssh2/src/message/msg_channel.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/message/msg_userauth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Longest one public operation may stay pending before the test reports it
/// instead of waiting for the framework's own 30s timeout.
const _opTimeout = Duration(seconds: 3);

/// Longest the guarded body may run. A hang inside the error zone must fail
/// with a message of its own rather than dying silently at the framework
/// limit.
const _bodyTimeout = Duration(seconds: 20);

void main() {
  group('SSHClient.sftp subsystem transport contract', () {
    test('accepted subsystem resolves, in-flight stat fails on transport death '
        'and close settles', () async {
      final socket = _FakeSshSocket();
      final client = _authenticatedClient(socket);
      addTearDown(socket.destroy);

      final outcome = await _guarded(() async {
        // The listener must be on the public operation before the fault is
        // injected: a Future that fails with nobody listening is reported to
        // the zone as unhandled, which would condemn the test harness
        // instead of the library.
        final openOp = _settle(client.sftp());
        await _pump();
        _confirmChannel(client);
        await _pump();
        _acceptSubsystem(client);
        await _pump();

        final open = await openOp;
        _Op? stat;
        _Op? closing;
        if (open.value is SftpClient) {
          final sftp = open.value! as SftpClient;
          final pendingStat = _settle(sftp.stat('/media'));
          await _pump();
          socket.destroy();
          await _pump();
          stat = await pendingStat;
          closing = await _settle(sftp.close());
        }
        return (open: open, stat: stat, closing: closing);
      });

      await _letLateErrorsLand();

      const what = 'accepted subsystem';
      final problems = _zoneProblems(outcome, what);
      final result = outcome.value;
      if (result == null) {
        problems.add('$what: the guarded body produced no outcome');
      } else {
        final open = result.open;
        if (open.timedOut) {
          problems.add(
            '$what: SSHClient.sftp() never settled within $_opTimeout',
          );
        } else if (open.error != null) {
          problems.add(
            '$what: SSHClient.sftp() failed although the subsystem was '
            'accepted: ${open.error.runtimeType}: ${open.error}',
          );
        }

        final stat = result.stat;
        if (stat == null) {
          problems.add(
            '$what: no in-flight operation ran because sftp() did not '
            'resolve',
          );
        } else if (stat.timedOut) {
          problems.add(
            '$what: the in-flight SftpClient.stat() never failed after the '
            'transport died',
          );
        } else if (stat.error == null) {
          problems.add(
            '$what: the in-flight SftpClient.stat() resolved even though no '
            'SFTP version reply was ever sent',
          );
        } else if (stat.error is! SftpAbortError) {
          problems.add(
            '$what: the in-flight SftpClient.stat() must fail with '
            'SftpAbortError but was ${stat.error.runtimeType}: ${stat.error}',
          );
        }

        final closing = result.closing;
        if (closing == null) {
          problems.add(
            '$what: SftpClient.close() never ran because sftp() did not '
            'resolve',
          );
        } else if (closing.timedOut) {
          problems.add(
            '$what: SftpClient.close() never settled within $_opTimeout',
          );
        } else if (closing.error != null) {
          problems.add(
            '$what: SftpClient.close() must settle cleanly but threw '
            '${closing.error.runtimeType}: ${closing.error}',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n---\n'));
    });

    test('subsystem request still pending when the transport closes fails the '
        'public call instead of leaking a Future', () async {
      final socket = _FakeSshSocket();
      final client = _authenticatedClient(socket);
      addTearDown(socket.destroy);

      final outcome = await _guarded(() async {
        final openOp = _settle(client.sftp());
        await _pump();
        _confirmChannel(client);
        await _pump();
        socket.destroy();
        await _pump();
        return openOp;
      });

      await _letLateErrorsLand();

      const what = 'pending subsystem then transport close';
      final problems = _zoneProblems(outcome, what);
      final open = outcome.value;
      if (open == null) {
        problems.add('$what: the guarded body produced no outcome');
      } else if (open.timedOut) {
        problems.add(
          '$what: SSHClient.sftp() never settled within $_opTimeout',
        );
      } else if (open.error == null) {
        problems.add(
          '$what: SSHClient.sftp() resolved with '
          '${open.value.runtimeType} while the subsystem request was still '
          'pending; the caller must be told the connection is gone',
        );
      } else if (open.error is! SSHStateError) {
        problems.add(
          '$what: SSHClient.sftp() must fail with SSHStateError but was '
          '${open.error.runtimeType}: ${open.error}',
        );
      } else if ((open.error! as SSHStateError).message !=
          'SSH connection closed') {
        problems.add(
          '$what: SSHClient.sftp() must fail with "SSH connection closed" '
          'but was "${(open.error! as SSHStateError).message}"',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n---\n'));
    });

    test(
      'subsystem refusal fails the public call instead of resolving a client '
      'that can never talk SFTP',
      () async {
        final socket = _FakeSshSocket();
        final client = _authenticatedClient(socket);
        addTearDown(socket.destroy);

        final outcome = await _guarded(() async {
          final openOp = _settle(client.sftp());
          await _pump();
          _confirmChannel(client);
          await _pump();
          _rejectSubsystem(client);
          await _pump();
          return openOp;
        });

        await _letLateErrorsLand();

        const what = 'subsystem refusal';
        final problems = _zoneProblems(outcome, what);
        final open = outcome.value;
        if (open == null) {
          problems.add('$what: the guarded body produced no outcome');
        } else if (open.timedOut) {
          problems.add(
            '$what: SSHClient.sftp() never settled within $_opTimeout',
          );
        } else if (open.error == null) {
          problems.add(
            '$what: SSHClient.sftp() resolved with '
            '${open.value.runtimeType} after the peer refused '
            'subsystem sftp; the caller must get an SSHError',
          );
        } else if (open.error is! SSHError) {
          problems.add(
            '$what: SSHClient.sftp() must fail with an SSHError but was '
            '${open.error.runtimeType}: ${open.error}',
          );
        }
        expect(problems, isEmpty, reason: problems.join('\n---\n'));
      },
    );

    test('transport dying during CHANNEL_OPEN fails the public call and leaves '
        'nothing unobserved', () async {
      final socket = _FakeSshSocket();
      final client = _authenticatedClient(socket);
      addTearDown(socket.destroy);

      final outcome = await _guarded(() async {
        final openOp = _settle(client.sftp());
        await _pump();
        socket.destroy();
        await _pump();
        return openOp;
      });

      await _letLateErrorsLand();

      const what = 'transport failure during channel open';
      final problems = _zoneProblems(outcome, what);
      final open = outcome.value;
      if (open == null) {
        problems.add('$what: the guarded body produced no outcome');
      } else if (open.timedOut) {
        problems.add(
          '$what: SSHClient.sftp() never settled within $_opTimeout',
        );
      } else if (open.error == null) {
        problems.add(
          '$what: SSHClient.sftp() resolved with '
          '${open.value.runtimeType} although the CHANNEL_OPEN was never '
          'answered',
        );
      } else if (open.error is! SSHStateError) {
        problems.add(
          '$what: SSHClient.sftp() must fail with SSHStateError but was '
          '${open.error.runtimeType}: ${open.error}',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n---\n'));
    });

    test('peer CHANNEL_OPEN failure surfaces as SSHChannelOpenError on the '
        'public call', () async {
      final socket = _FakeSshSocket();
      final client = _authenticatedClient(socket);
      addTearDown(socket.destroy);

      final outcome = await _guarded(() async {
        final openOp = _settle(client.sftp());
        await _pump();
        _refuseChannelOpen(client);
        await _pump();
        return openOp;
      });

      await _letLateErrorsLand();

      const what = 'channel open refused by the peer';
      final problems = _zoneProblems(outcome, what);
      final open = outcome.value;
      if (open == null) {
        problems.add('$what: the guarded body produced no outcome');
      } else if (open.timedOut) {
        problems.add(
          '$what: SSHClient.sftp() never settled within $_opTimeout',
        );
      } else if (open.error == null) {
        problems.add(
          '$what: SSHClient.sftp() resolved with '
          '${open.value.runtimeType} although the peer refused the channel',
        );
      } else if (open.error is! SSHChannelOpenError) {
        problems.add(
          '$what: SSHClient.sftp() must fail with SSHChannelOpenError but '
          'was ${open.error.runtimeType}: ${open.error}',
        );
      } else if ((open.error! as SSHChannelOpenError).description !=
          'administratively prohibited') {
        problems.add(
          '$what: the refusal description must reach the caller but was '
          '"${(open.error! as SSHChannelOpenError).description}"',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n---\n'));
    });

    test(
      'subsystem request send failure surfaces on the public call and leaves '
      'nothing unobserved',
      () async {
        final socket = _FakeSshSocket();
        final fault = _SendFault('requestType: subsystem');
        final client = _authenticatedClient(socket, printTrace: fault.trace);
        addTearDown(socket.destroy);

        final outcome = await _guarded(() async {
          final openOp = _settle(client.sftp());
          await _pump();
          _confirmChannel(client);
          // The CHANNEL_OPEN is already out; `subsystem sftp` is the next
          // packet this process emits, so arm the fault for it only.
          fault.arm();
          await _pump();
          return openOp;
        });

        await _letLateErrorsLand();

        const what = 'subsystem request send failure';
        final problems = _zoneProblems(outcome, what);
        final open = outcome.value;
        if (open == null) {
          problems.add('$what: the guarded body produced no outcome');
        } else if (open.timedOut) {
          problems.add(
            '$what: SSHClient.sftp() never settled within $_opTimeout',
          );
        } else if (open.error == null) {
          problems.add(
            '$what: SSHClient.sftp() resolved with '
            '${open.value.runtimeType} although its subsystem request could '
            'not be sent',
          );
        } else if (open.error is! StateError) {
          problems.add(
            '$what: SSHClient.sftp() must fail with the injected send error '
            'but was ${open.error.runtimeType}: ${open.error}',
          );
        }
        expect(problems, isEmpty, reason: problems.join('\n---\n'));
      },
    );

    test('CHANNEL_OPEN request send failure surfaces on the public call and '
        'leaves nothing unobserved', () async {
      final socket = _FakeSshSocket();
      final fault = _SendFault('SSH_Message_Channel_Open(channelType: session');
      final client = _authenticatedClient(socket, printTrace: fault.trace);
      addTearDown(socket.destroy);

      final outcome = await _guarded(() async {
        final openOp = _settle(client.sftp());
        // CHANNEL_OPEN is the first packet this client emits; break its
        // send before a microtask can hand it to the transport.
        fault.arm();
        await _pump();
        return openOp;
      });

      await _letLateErrorsLand();

      const what = 'channel open request send failure';
      final problems = _zoneProblems(outcome, what);
      final open = outcome.value;
      if (open == null) {
        problems.add('$what: the guarded body produced no outcome');
      } else if (open.timedOut) {
        problems.add(
          '$what: SSHClient.sftp() never settled within $_opTimeout',
        );
      } else if (open.error == null) {
        problems.add(
          '$what: SSHClient.sftp() resolved with '
          '${open.value.runtimeType} although its CHANNEL_OPEN request '
          'could not be sent',
        );
      } else if (open.error is! StateError) {
        problems.add(
          '$what: SSHClient.sftp() must fail with the injected send error '
          'but was ${open.error.runtimeType}: ${open.error}',
        );
      }
      expect(problems, isEmpty, reason: problems.join('\n---\n'));
    });
  });
}

/// Result of awaiting one public operation, including the case where it never
/// settled at all.
class _Op {
  const _Op.resolved(this.value) : error = null, timedOut = false;

  const _Op.failed(this.error) : value = null, timedOut = false;

  const _Op.timeout() : value = null, error = null, timedOut = true;

  final Object? value;
  final Object? error;
  final bool timedOut;
}

/// What the guarded body returned plus everything the guarded zone saw that
/// nobody observed.
class _ZoneOutcome<T> {
  const _ZoneOutcome(this.value, this.thrown, this.uncaught);

  final T? value;
  final Object? thrown;
  final List<String> uncaught;
}

Future<_Op> _settle(Future<Object?> future) async {
  try {
    return _Op.resolved(await future.timeout(_opTimeout));
  } on TimeoutException {
    return const _Op.timeout();
  } catch (error) {
    return _Op.failed(error);
  }
}

/// Runs [body] in a guarded zone so an error nobody observes is captured for
/// an assertion instead of being swallowed silently or blowing up the test
/// framework from outside. The body's own result and its exceptions are
/// carried out through an outer [Completer] completed from inside the zone.
Future<_ZoneOutcome<T>> _guarded<T>(Future<T> Function() body) async {
  final uncaught = <String>[];
  final completer = Completer<_ZoneOutcome<T>>();
  T? value;
  Object? thrown;
  runZonedGuarded<Future<void>>(
    () async {
      try {
        value = await body();
      } catch (error) {
        thrown = error;
      }
      // Drain the queue so a leak that is already in flight is reported to
      // this zone before the outcome leaves it.
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      if (!completer.isCompleted) {
        completer.complete(_ZoneOutcome<T>(value, thrown, uncaught));
      }
    },
    (Object error, StackTrace stack) {
      uncaught.add('$error\n$stack');
    },
  );
  try {
    return await completer.future.timeout(_bodyTimeout);
  } on TimeoutException {
    return _ZoneOutcome<T>(
      value,
      thrown,
      uncaught
        ..add('TIMEOUT: guarded body did not finish within $_bodyTimeout'),
    );
  }
}

List<String> _zoneProblems<T>(_ZoneOutcome<T> outcome, String what) {
  return <String>[
    if (outcome.thrown != null)
      '$what: the guarded body threw: ${outcome.thrown}',
    for (final entry in outcome.uncaught) '$what: uncaught zone error:\n$entry',
  ];
}

/// Lets a leak that is still travelling through the microtask queue reach the
/// guard before the assertions read it.
Future<void> _letLateErrorsLand() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

Future<void> _pump([int turns = 6]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Turns the client's [SSHClient.printTrace] hook into a one-shot synchronous
/// send failure for one outgoing message.
///
/// [trace] only throws while armed, and only for an outgoing trace line
/// (`SSHClient._sendMessage` prints `-> ...: $message` before it encodes) whose
/// message matches [match]; every other packet keeps flowing untouched. The
/// throw therefore happens exactly where a failing socket write would, inside
/// the `try` that guards the send, and the fault disarms itself so the error
/// path's own CHANNEL_CLOSE cannot re-trigger it.
class _SendFault {
  _SendFault(this.match);

  /// Substring identifying the outgoing message this fault waits for.
  final String match;

  bool _armed = false;

  /// Waits for the next outgoing message matching [match] to fail.
  void arm() => _armed = true;

  void trace(String? line) {
    if (!_armed) return;
    if (line == null || !line.startsWith('-> ') || !line.contains(match)) {
      return;
    }
    _armed = false;
    throw StateError('injected send failure for $match');
  }
}

SSHClient _authenticatedClient(
  _FakeSshSocket socket, {
  SSHPrintHandler? printTrace,
}) {
  final client = SSHClient(
    socket,
    username: 'dev',
    keepAliveInterval: null,
    printTrace: printTrace,
  );
  client.handlePacket(SSH_Message_Userauth_Success().encode());
  return client;
}

void _confirmChannel(SSHClient client) {
  client.handlePacket(
    SSH_Message_Channel_Confirmation(
      recipientChannel: 0,
      senderChannel: 1,
      initialWindowSize: 1024 * 1024,
      maximumPacketSize: 32768,
      data: Uint8List(0),
    ).encode(),
  );
}

void _refuseChannelOpen(SSHClient client) {
  client.handlePacket(
    SSH_Message_Channel_Open_Failure(
      recipientChannel: 0,
      reasonCode:
          SSH_Message_Channel_Open_Failure.codeAdministrativelyProhibited,
      description: 'administratively prohibited',
    ).encode(),
  );
}

void _acceptSubsystem(SSHClient client) {
  client.handlePacket(
    SSH_Message_Channel_Success(recipientChannel: 0).encode(),
  );
}

void _rejectSubsystem(SSHClient client) {
  client.handlePacket(
    SSH_Message_Channel_Failure(recipientChannel: 0).encode(),
  );
}

/// Injected socket: no network, full control over when the transport dies.
class _FakeSshSocket implements SSHSocket {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<List<int>> _outgoing =
      StreamController<List<int>>.broadcast();
  final Completer<void> _done = Completer<void>();

  bool destroyed = false;

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
    destroyed = true;
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) unawaited(_incoming.close());
    if (!_outgoing.isClosed) unawaited(_outgoing.close());
  }

  @override
  Future<void> flush() async {}
}
