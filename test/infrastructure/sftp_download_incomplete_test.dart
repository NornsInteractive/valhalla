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
  _RemoteFile({required this.size, required this.replies});

  /// Advertised size; null models a file whose size cannot be trusted.
  final int? size;
  final List<Uint8List> replies;

  int readCalls = 0;
  int closes = 0;
  final List<int?> requestedLengths = [];

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
