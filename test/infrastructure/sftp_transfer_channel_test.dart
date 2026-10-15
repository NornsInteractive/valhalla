import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

class _Writer implements SftpFileWriter {
  _Writer(Stream<Uint8List> source, void Function(int)? onProgress) {
    done = () async {
      await for (final chunk in source) {
        progress += chunk.length;
        onProgress?.call(progress);
      }
      await gate.future;
    }();
  }
  final gate = Completer<void>();
  @override
  int progress = 0;
  @override
  late final Future<void> done;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _File implements SftpFile {
  final reading = StreamController<Uint8List>();
  _Writer? writer;
  int closes = 0;
  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 16384,
    int maxPendingRequests = 64,
  }) => reading.stream;
  @override
  SftpFileWriter write(
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 16384,
    int maxPendingRequests = 64,
  }) => writer = _Writer(data, onProgress);
  @override
  Future<void> close() async => closes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements SftpClient {
  final file = _File();
  int closes = 0;
  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => file;
  @override
  Future<void> close() async {
    closes++;
    unawaited(file.reading.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ssh implements SSHClient {
  final channels = <_Channel>[];
  @override
  bool get isClosed => false;
  @override
  Future<SftpClient> sftp() async {
    final channel = _Channel();
    channels.add(channel);
    return channel;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('browsing timeout cannot close an ongoing upload channel', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla_channel_test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final local = File('${directory.path}/data');
    await local.writeAsString('uploaded');
    final ssh = _Ssh();
    final service = SftpClientService(
      ssh,
      operationTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(service.dispose);
    final upload = await service.startUpload(local.path, '/fixture');
    final uploading = ssh.channels.single;
    await expectLater(
      service.readFileContent('/stalled'),
      throwsA(isA<SFTPException>()),
    );
    expect(ssh.channels, hasLength(2));
    expect(ssh.channels.last.closes, 1);
    expect(uploading.closes, 0);
    uploading.file.writer!.gate.complete();
    await upload.done;
    await Future<void>.delayed(Duration.zero);
    expect(upload.transferredBytes, 8);
    expect(uploading.closes, 1);
    expect(uploading.file.closes, 1);
  });
}
