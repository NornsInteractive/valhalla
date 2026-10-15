import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

/// Early EOF on a download must fail loudly as `SFTP_DOWNLOAD_INCOMPLETE`
/// instead of silently reporting a truncated file as a success.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sftp_download_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String localPath(String name) => '${tempDir.path}/$name';

  test(
    'multi-megabyte download keeps a single bounded continuous read',
    () async {
      final bytes = Uint8List.fromList(
        List.generate(3 * 1024 * 1024, (i) => i % 251),
      );
      final remote = _RemoteFile(size: bytes.length, replies: [], data: bytes);
      final handle = await SftpClientService(
        _Ssh(remote),
      ).startDownload('/large', localPath('large'));
      await handle.done;
      expect(remote.streamCalls, 1);
      expect(remote.streamChunkSize, 64 * 1024);
      expect(remote.streamWindow, 32);
      expect(await File(localPath('large')).readAsBytes(), bytes);
    },
  );

  test(
    'pause stops disk progress and resume completes the same stream',
    () async {
      final bytes = Uint8List(4 * 64 * 1024);
      final remote = _RemoteFile(size: bytes.length, replies: [], data: bytes);
      final paused = Completer<void>();
      late SftpTransferHandle handle;
      handle = await SftpClientService(_Ssh(remote)).startDownload(
        '/paused',
        localPath('paused'),
        onProgress: (n) {
          if (!paused.isCompleted) {
            unawaited(handle.pause());
            paused.complete();
          }
        },
      );
      await paused.future;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(handle.transferredBytes, 64 * 1024);
      expect(await File(localPath('paused')).length(), 64 * 1024);
      await handle.resume();
      await handle.done;
      expect(remote.streamCalls, 1);
      expect(handle.transferredBytes, bytes.length);
    },
  );

  test(
    'abort while paused closes channel once and prevents late writes',
    () async {
      final remote = _RemoteFile(
        size: 4 * 64 * 1024,
        replies: [],
        data: Uint8List(4 * 64 * 1024),
      );
      final ssh = _Ssh(remote);
      final paused = Completer<void>();
      late SftpTransferHandle handle;
      handle = await SftpClientService(ssh).startDownload(
        '/cancel',
        localPath('cancel'),
        onProgress: (_) {
          if (!paused.isCompleted) {
            unawaited(handle.pause());
            paused.complete();
          }
        },
      );
      final failure = expectLater(
        handle.done,
        throwsA(isA<SftpTransferAborted>()),
      );
      await paused.future;
      await handle.abort();
      await failure;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await File(localPath('cancel')).length(), 64 * 1024);
      expect(remote.closes, 1);
      expect(ssh.sftpClient.closes, 1);
    },
  );

  for (final corrupt in [false, true]) {
    test(
      'full resume prefix ${corrupt ? 'rejects a middle-byte mismatch' : 'is verified before append'}',
      () async {
        final bytes = Uint8List.fromList(
          List.generate(4 * 64 * 1024, (i) => i % 251),
        );
        final prefix = bytes.sublist(0, 2 * 64 * 1024);
        if (corrupt) prefix[70001] ^= 1;
        await File(localPath('resume')).writeAsBytes(prefix);
        final remote = _RemoteFile(
          size: bytes.length,
          replies: [],
          data: bytes,
        );
        final phases = <SftpTransferPhase>[];
        final request = SftpClientService(_Ssh(remote)).startResumableDownload(
          '/resume',
          localPath('resume'),
          expectedSource: {
            'target': '/resume',
            'size': bytes.length,
            'modified': null,
          },
          onSource: (_) {},
          onPhase: (phase, _, _) => phases.add(phase),
        );
        if (corrupt) {
          await expectLater(
            request,
            throwsA(
              isA<SFTPException>().having(
                (e) => e.message,
                'reason',
                'SFTP_TRANSFER_PARTIAL_INVALID',
              ),
            ),
          );
          expect(await File(localPath('resume')).readAsBytes(), prefix);
        } else {
          final handle = await request;
          await handle.done;
          expect(await File(localPath('resume')).readAsBytes(), bytes);
          expect(remote.streamCalls, 2);
          expect(
            phases,
            containsAllInOrder([
              SftpTransferPhase.verifyingPartial,
              SftpTransferPhase.transferring,
              SftpTransferPhase.verifying,
            ]),
          );
        }
      },
    );
  }

  test(
    'server ends the stream before the advertised size fails as incomplete',
    () async {
      final remote = _RemoteFile(
        size: 100,
        replies: [Uint8List(40), Uint8List(0)],
      );
      final service = SftpClientService(_Ssh(remote));

      final handle = await service.startDownload(
        '/big.bin',
        localPath('big.bin'),
      );

      await expectLater(
        handle.done,
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'reason',
            'SFTP_DOWNLOAD_INCOMPLETE',
          ),
        ),
      );
      expect(remote.readCalls, 2, reason: 'stop after the first empty reply');
      expect(remote.closes, 1, reason: 'the remote handle must be released');
      expect(
        SftpNotifier.downloadErrorCode(
          const SFTPException('SFTP_DOWNLOAD_INCOMPLETE'),
        ),
        'SFTP_DOWNLOAD_INCOMPLETE',
        reason: 'the UI can then map it to the truncated-file message',
      );
    },
  );

  test(
    'a truncated payload keeps the partial bytes it already wrote',
    () async {
      final remote = _RemoteFile(
        size: 100,
        replies: [Uint8List.fromList(List<int>.filled(40, 7)), Uint8List(0)],
      );
      final service = SftpClientService(_Ssh(remote));

      final handle = await service.startDownload(
        '/big.bin',
        localPath('big.bin'),
      );
      await expectLater(handle.done, throwsA(isA<SFTPException>()));

      final written = File(localPath('big.bin')).readAsBytesSync();
      expect(written.length, 40, reason: 'progress is preserved for retry');
      expect(handle.transferredBytes, 40);
    },
  );

  test('a complete reply finishes without a trailing read', () async {
    final remote = _RemoteFile(size: 100, replies: [Uint8List(100)]);
    final service = SftpClientService(_Ssh(remote));

    final handle = await service.startDownload(
      '/small.bin',
      localPath('small.bin'),
    );
    await handle.done;

    expect(handle.transferredBytes, 100);
    expect(remote.readCalls, 1, reason: 'no needless read after the last byte');
    expect(remote.closes, 1);
    expect(File(localPath('small.bin')).readAsBytesSync(), hasLength(100));
  });

  test('a zero/unknown size reads until the server reports EOF', () async {
    final remote = _RemoteFile(
      size: null,
      replies: [Uint8List.fromList(List<int>.filled(10, 1)), Uint8List(0)],
    );
    final service = SftpClientService(_Ssh(remote));

    final handle = await service.startDownload(
      '/proc/uptime',
      localPath('uptime'),
    );
    await handle.done;

    expect(handle.transferredBytes, 10);
    expect(remote.closes, 1);
  });

  test(
    'a failed transfer releases both handles instead of leaking them',
    () async {
      final remote = _RemoteFile(size: 100, replies: [Uint8List(0)]);
      final service = SftpClientService(_Ssh(remote));

      final handle = await service.startDownload(
        '/big.bin',
        localPath('big.bin'),
      );
      await expectLater(handle.done, throwsA(isA<SFTPException>()));

      expect(remote.closes, 1);
      // Re-opening the same path must still work: the local handle is free.
      final second = await service.startDownload(
        '/big.bin',
        localPath('big.bin'),
      );
      await expectLater(second.done, throwsA(isA<SFTPException>()));
      expect(remote.closes, 2);
    },
  );
}

class _RemoteFile implements SftpFile {
  _RemoteFile({required this.size, required this.replies, this.data});

  /// Advertised size; null models a file whose size cannot be trusted.
  final int? size;
  final List<Uint8List> replies;
  final Uint8List? data;

  int readCalls = 0;
  int closes = 0;
  int streamCalls = 0;
  int? streamChunkSize;
  int? streamWindow;
  final List<int?> requestedLengths = [];

  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 16384,
    int maxPendingRequests = 64,
  }) async* {
    streamCalls++;
    streamChunkSize = chunkSize;
    streamWindow = maxPendingRequests;
    if (data case final content?) {
      final end = length == null ? content.length : offset + length;
      for (var start = offset; start < end; start += chunkSize) {
        final next = start + chunkSize < end ? start + chunkSize : end;
        yield Uint8List.sublistView(content, start, next);
      }
      return;
    }
    var processed = 0;
    while (length == null || processed < length) {
      final bytes = await readBytes(length: length, offset: offset + processed);
      if (bytes.isEmpty) break;
      processed += bytes.length;
      yield bytes;
    }
  }

  @override
  Future<Uint8List> readBytes({int? length, int offset = 0}) async {
    readCalls++;
    requestedLengths.add(length);
    if (readCalls <= replies.length) return replies[readCalls - 1];
    return Uint8List(0);
  }

  @override
  Future<void> close() async => closes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sftp implements SftpClient {
  _Sftp(this.file);
  final _RemoteFile file;
  int closes = 0;

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async =>
      SftpFileAttrs(size: file.size);

  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => file;

  @override
  Future<String> absolute(String path) async => path;

  @override
  Future<void> close() async => closes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ssh implements SSHClient {
  _Ssh(this.remote) : sftpClient = _Sftp(remote);
  final _RemoteFile remote;
  final _Sftp sftpClient;

  @override
  bool get isClosed => false;

  @override
  Future<SftpClient> sftp() async => sftpClient;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
