import 'dart:async';
import 'dart:isolate';
import 'package:dartssh2/dartssh2.dart';
import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../ssh/ssh_transfer_connection.dart';

NasResource isolatedNasImageResource(
  SshTransferConnection connection,
  NasMediaItem item,
) => NasResource(
  sizeBytes: item.sizeBytes,
  mimeType: item.mimeType ?? 'application/octet-stream',
  read: (start, end, cancellation) =>
      _read(connection, item, start, end ?? item.sizeBytes, cancellation),
);

Stream<List<int>> _read(
  SshTransferConnection connection,
  NasMediaItem item,
  int start,
  int end,
  NasCancellation cancellation,
) async* {
  if (start < 0 ||
      end < start ||
      end > item.sizeBytes ||
      end - start > 16 * 1024 * 1024) {
    throw StateError('NAS_IMAGE_TOO_LARGE');
  }
  final events = ReceivePort();
  Isolate? worker;
  final unregister = cancellation.onCancel(() {
    events.sendPort.send(['cancel']);
    worker?.kill(priority: Isolate.immediate);
  });
  try {
    cancellation.check();
    worker = await Isolate.spawn(
      _worker,
      (connection, item, start, end, events.sendPort),
      onError: events.sendPort,
      onExit: events.sendPort,
    );
    SendPort? control;
    await for (final event in events) {
      cancellation.check();
      if (event == null) throw StateError('NAS_PREVIEW_WORKER_EXITED');
      final data = event as List;
      switch (data.first) {
        case 'control':
          control = data[1] as SendPort;
        case 'bytes':
          yield (data[1] as TransferableTypedData).materialize().asUint8List();
          cancellation.check();
          control!.send(true);
        case 'done':
          return;
        default:
          throw StateError('NAS_PREVIEW_READ_FAILED');
      }
    }
  } finally {
    unregister();
    worker?.kill(priority: Isolate.immediate);
    events.close();
  }
}

Future<void> _worker(
  (SshTransferConnection, NasMediaItem, int, int, SendPort) input,
) async {
  final (connection, item, start, end, events) = input;
  final commands = ReceivePort();
  final acknowledgements = StreamIterator(commands);
  events.send(['control', commands.sendPort]);
  final client = await connectSshWorker(connection);
  try {
    final sftp = await client.sftp();
    final file = await sftp.open(item.path, mode: SftpFileOpenMode.read);
    try {
      final attrs = await file.stat();
      if (attrs.size != item.sizeBytes ||
          attrs.modifyTime != item.modifiedEpoch) {
        throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
      }
      await for (final chunk in file.read(
        offset: start,
        length: end - start,
        chunkSize: 64 * 1024,
        maxPendingRequests: 1,
      )) {
        events.send([
          'bytes',
          TransferableTypedData.fromList([chunk]),
        ]);
        if (!await acknowledgements.moveNext()) return;
      }
      events.send(['done']);
    } finally {
      await file.close();
      await sftp.close();
    }
  } finally {
    client.close();
    await acknowledgements.cancel();
    commands.close();
  }
}
