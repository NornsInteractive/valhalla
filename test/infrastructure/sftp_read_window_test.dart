import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
// Exercise the actual vendored protocol reader, not a replacement read() API.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/sftp/sftp_packet.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedChannel implements SSHChannel {
  _DelayedChannel(this.bytes);
  final Uint8List bytes;
  final _incoming = StreamController<SSHChannelData>();
  final _timers = <Timer>[];
  int reads = 0;
  int pending = 0;
  int peak = 0;
  bool closed = false;
  @override
  Stream<SSHChannelData> get stream => _incoming.stream;

  void reply(SftpPacket packet) {
    if (closed) return;
    final encoded = packet.encode();
    final framed = Uint8List(4 + encoded.length);
    ByteData.sublistView(framed).setUint32(0, encoded.length);
    framed.setRange(4, framed.length, encoded);
    _incoming.add(SSHChannelData(framed));
  }

  @override
  void addData(Uint8List data, {int? type}) {
    final packet = Uint8List.sublistView(data, 4);
    switch (packet.first) {
      case SftpInitPacket.packetType:
        reply(SftpVersionPacket(3));
      case SftpClosePacket.packetType:
        reply(
          SftpStatusPacket(
            requestId: SftpClosePacket.decode(packet).requestId,
            code: 0,
            message: '',
          ),
        );
      case SftpReadPacket.packetType:
        final request = SftpReadPacket.decode(packet);
        reads++;
        pending++;
        peak = math.max(peak, pending);
        // Deliberately reorder adjacent offsets, with a bounded simulated RTT.
        _timers.add(
          Timer(Duration(milliseconds: 6 + (request.offset ~/ 16384) % 3), () {
            pending--;
            reply(
              SftpDataPacket(
                request.requestId,
                Uint8List.sublistView(
                  bytes,
                  request.offset,
                  math.min(bytes.length, request.offset + request.length),
                ),
              ),
            );
          }),
        );
      default:
        throw StateError('Unexpected test packet ${packet.first}');
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    await _incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'continuous read grows a bounded window and orders delayed protocol replies',
    () async {
      final expected = Uint8List.fromList(
        List.generate(2 * 1024 * 1024, (i) => i % 251),
      );
      Future<(int, int, int)> measure(bool continuous) async {
        final channel = _DelayedChannel(expected);
        final client = SftpClient(channel);
        await client.handshake;
        final file = SftpFile(client, Uint8List.fromList([1]));
        final output = BytesBuilder(copy: false);
        final clock = Stopwatch()..start();
        try {
          if (continuous) {
            await for (final chunk in file.read(
              length: expected.length,
              chunkSize: 64 * 1024,
              maxPendingRequests: 32,
            )) {
              output.add(chunk);
            }
          } else {
            for (
              var offset = 0;
              offset < expected.length;
              offset += 64 * 1024
            ) {
              output.add(
                await file.readBytes(length: 64 * 1024, offset: offset),
              );
            }
          }
          clock.stop();
          expect(output.takeBytes(), expected);
          return (clock.elapsedMicroseconds, channel.reads, channel.peak);
        } finally {
          await file.close();
          await client.close();
        }
      }

      final old = await measure(false);
      final current = await measure(true);
      expect(old.$2, 128);
      expect(current.$2, 32);
      expect(current.$3, greaterThan(1));
      expect(current.$3, lessThanOrEqualTo(32));
      // Timing is diagnostic only; correctness never depends on host load.
      // ignore: avoid_print
      print(
        'SIMULATED 2MiB/6–8ms RTT: batches=${old.$1}us/${old.$2}requests/peak${old.$3}; continuous=${current.$1}us/${current.$2}requests/peak${current.$3}',
      );
    },
  );
}
