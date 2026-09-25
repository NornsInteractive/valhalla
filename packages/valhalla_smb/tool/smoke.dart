import 'dart:async';
import 'dart:io';

import 'package:valhalla_smb/valhalla_smb.dart';

// Run against tool/test_server.py. This checks real signed SMB2 requests,
// multiple bounded directory pages, unicode, a >4 GiB offset and cancellation.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Provide the built native library path');
  }
  final client = SmbClient(
    const SmbConnection(
      host: '127.0.0.1:14455',
      share: 'media',
      username: 'valhalla',
      password: 'test-password',
    ),
    libraryPath: args.single,
  );
  await client.probe();
  var count = 0;
  var pages = 0;
  var unicodeSeen = false;
  await for (final page in client.walk(roots: [''], excludes: ['excluded'])) {
    if (page.length > 819) throw StateError('Unbounded page: ${page.length}');
    pages++;
    for (final entry in page) {
      if (entry.path.startsWith('excluded/')) {
        throw StateError('Excluded file returned');
      }
      if (entry.path == '照片.jpg') unicodeSeen = true;
      if (!entry.isDirectory) count++;
    }
  }
  if (count != 2502 || pages < 4 || !unicodeSeen) {
    throw StateError(
      'Directory mismatch: count=$count pages=$pages unicode=$unicodeSeen',
    );
  }
  final bytes = await client
      .read('large.mp4', start: 0x100000000 + 17, end: 0x100000000 + 21)
      .expand((bytes) => bytes)
      .toList();
  if (String.fromCharCodes(bytes) != 'seek') {
    throw StateError('64-bit offset failed');
  }
  final cancellation = Completer<void>();
  var received = 0;
  try {
    await for (final chunk in client.read(
      'large.mp4',
      cancelled: cancellation.future,
    )) {
      received += chunk.length;
      cancellation.complete();
    }
    throw StateError('Cancellation did not fail');
  } on SmbException catch (error) {
    if (error.message != 'SMB_CANCELLED') rethrow;
  }
  if (received > 262144) throw StateError('Read ran ahead of consumer');
  // Cancellation through StreamSubscription.cancel also releases native handles.
  final iterator = StreamIterator(client.walk(roots: ['']));
  if (!await iterator.moveNext()) throw StateError('Expected directory page');
  await iterator.cancel();
  await client.probe();
  stdout.writeln(
    'PASS: signed SMB2, $count files / $pages pages, unicode, 64-bit range, cancel, reconnect',
  );
}
