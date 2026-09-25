import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

class _File implements SftpFile {
  Iterable<Uint8List> chunks = const [];
  bool failWrite = false;
  int closes = 0;
  int? requestedLength;
  Uint8List? written;
  StreamController<Uint8List>? reading;
  Completer<void>? writing;
  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 32768,
    int maxPendingRequests = 64,
  }) {
    requestedLength = length;
    return reading?.stream ?? Stream.fromIterable(chunks);
  }

  @override
  Future<void> writeBytes(
    Uint8List data, {
    int offset = 0,
    int chunkSize = 32768,
    int maxPendingRequests = 64,
  }) async {
    if (failWrite) throw StateError('disk full');
    await writing?.future;
    written = data;
  }

  @override
  Future<void> close() async => closes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sftp implements SftpClient {
  _Sftp(this.file);
  final _File file;
  Completer<SftpFile>? opening;
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
    if (file.reading != null) unawaited(file.reading!.close());
    if (file.writing != null && !file.writing!.isCompleted) {
      file.writing!.completeError(StateError('session closed'));
    }
  }

  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => opening?.future ?? file;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ssh implements SSHClient {
  _Ssh(_File file) : sftpClient = _Sftp(file);
  final _Sftp sftpClient;
  Completer<SftpClient>? opening;
  @override
  bool get isClosed => false;
  @override
  Future<SftpClient> sftp() async => opening?.future ?? sftpClient;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'stalled sftpClient returns timeout and closes its late result',
    () async {
      final ssh = _Ssh(_File())..opening = Completer<SftpClient>();
      final service = SftpClientService(
        ssh,
        operationTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        service.readFileContent('/file.txt'),
        throwsA(isA<SFTPException>()),
      );
      ssh.opening!.complete(ssh.sftpClient);
      await Future<void>.delayed(Duration.zero);
      expect(ssh.sftpClient.closes, 1);
    },
  );
  test(
    'stalled open returns timeout and closes its late file without reading',
    () async {
      final file = _File();
      final ssh = _Ssh(file);
      ssh.sftpClient.opening = Completer<SftpFile>();
      final service = SftpClientService(
        ssh,
        operationTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        service.readFileContent('/file.txt'),
        throwsA(isA<SFTPException>()),
      );
      expect(ssh.sftpClient.closes, 1);
      ssh.sftpClient.opening!.complete(file);
      await Future<void>.delayed(Duration.zero);
      expect(file.requestedLength, isNull);
      expect(file.closes, 1);
    },
  );
  test(
    'stalled read or write discards only the SFTP sftpClient within budget',
    () async {
      for (final writing in [false, true]) {
        final file = _File();
        if (writing) {
          file.writing = Completer<void>();
        } else {
          file.reading = StreamController<Uint8List>();
        }
        final ssh = _Ssh(file);
        final service = SftpClientService(
          ssh,
          operationTimeout: const Duration(milliseconds: 30),
        );
        await expectLater(
          writing
              ? service.writeFileContent('/file.txt', 'data')
              : service.readFileContent('/file.txt'),
          throwsA(isA<SFTPException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(ssh.sftpClient.closes, 1);
        expect(file.closes, 1);
        expect(ssh.isClosed, isFalse);
      }
    },
  );

  test(
    'preview enforces byte limit while reading even without trusted metadata',
    () async {
      final file = _File()
        ..chunks = [Uint8List(SftpClientService.maxPreviewBytes), Uint8List(1)];
      final service = SftpClientService(_Ssh(file));
      await expectLater(
        service.readFileContent('/unknown-size.txt'),
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'reason',
            SftpClientService.previewTooLargeCode,
          ),
        ),
      );
      expect(file.requestedLength, SftpClientService.maxPreviewBytes + 1);
      expect(file.closes, 1);
    },
  );
  test('small UTF-8 preview closes its remote handle', () async {
    final file = _File()..chunks = [utf8.encode('中文内容')];
    expect(
      await SftpClientService(_Ssh(file)).readFileContent('/notes.txt'),
      '中文内容',
    );
    expect(file.closes, 1);
  });
  test('write closes its handle after success and remote failure', () async {
    final file = _File();
    final service = SftpClientService(_Ssh(file));
    await service.writeFileContent('/notes.txt', '内容');
    expect(utf8.decode(file.written!), '内容');
    file.failWrite = true;
    await expectLater(
      service.writeFileContent('/notes.txt', 'more'),
      throwsStateError,
    );
    expect(file.closes, 2);
  });
}
