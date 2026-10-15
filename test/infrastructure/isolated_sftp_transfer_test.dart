import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/infrastructure/sftp/isolated_sftp_client_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_transfer_connection.dart';

const _length = 65536;
Uint8List _bytes() =>
    Uint8List.fromList(List.generate(_length, (i) => i % 251));

Future<SSHClient> _connect(SshTransferConnection connection) async {
  if (connection.host == 'slow-start' || connection.host == 'streaming') {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return _Client(connection.host, connection.username);
}

class _Sink implements StreamSink<List<int>> {
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stack]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
}

class _Socket implements SSHSocket {
  @override
  Stream<Uint8List> get stream => const Stream.empty();
  @override
  StreamSink<List<int>> get sink => _Sink();
  @override
  Future<void> get done async {}
  @override
  Future<void> close() async {}
  @override
  void destroy() {}
  @override
  Future<void> flush() async {}
}

class _Client implements SSHClient {
  _Client(this.mode, [this.output = '']);
  final String mode;
  final String output;
  bool closed = false;
  @override
  bool get isClosed => closed;
  @override
  SSHSocket get socket => _Socket();
  @override
  Future<SftpClient> sftp() async => _Sftp(mode, output);
  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _Session();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements SSHSession {
  @override
  Stream<Uint8List> get stdout => const Stream.empty();
  @override
  Stream<Uint8List> get stderr => const Stream.empty();
  @override
  Future<void> get done async {}
  @override
  int get exitCode => 0;
  @override
  void close() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sftp implements SftpClient {
  _Sftp(this.mode, this.output);
  final String mode;
  final String output;
  var stats = 0;
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    if (mode == 'permission') {
      throw SftpStatusError(SftpStatusCode.permissionDenied, 'fixture');
    }
    if (mode == 'upload' || mode == 'commit') {
      throw SftpStatusError(SftpStatusCode.noSuchFile, 'fixture');
    }
    stats++;
    return SftpFileAttrs(
      size: _length,
      modifyTime: mode == 'changed' && stats > 1 ? 2 : 1,
    );
  }

  @override
  Future<String> absolute(String path) async => path;
  @override
  Future<SftpFile> open(
    String path, {
    SftpFileOpenMode mode = SftpFileOpenMode.read,
  }) async => _File(this.mode, output);
  @override
  Future<void> remove(String path) async {}
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _File implements SftpFile {
  _File(this.mode, this.output);
  final String mode;
  final String output;
  bool closed = false;
  @override
  Stream<Uint8List> read({
    int? length,
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 16384,
    int maxPendingRequests = 64,
  }) {
    if (mode == 'cpu') {
      final clock = Stopwatch()..start();
      while (clock.elapsedMilliseconds < 200) {}
    }
    return _chunks(offset, length ?? _length - offset);
  }

  Stream<Uint8List> _chunks(int offset, int length) async* {
    final data = _bytes();
    final end = offset + length;
    final step = mode == 'streaming' ? 2048 : 32768;
    for (var position = offset; position < end && !closed; position += step) {
      if (mode == 'streaming') {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      if (closed) return;
      if (mode == 'truncated' && position > 0) return;
      yield Uint8List.sublistView(
        data,
        position,
        position + step > end ? end : position + step,
      );
    }
  }

  @override
  SftpFileWriter write(
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int)? onProgress,
    int chunkSize = 16384,
    int maxPendingRequests = 64,
  }) => _Writer(data, output, onProgress);
  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Writer implements SftpFileWriter {
  _Writer(
    Stream<Uint8List> data,
    String output,
    void Function(int)? onProgress,
  ) {
    done = () async {
      final sink = File(output).openWrite();
      try {
        await for (final chunk in data) {
          if (aborted) break;
          sink.add(chunk);
          progress += chunk.length;
          onProgress?.call(progress);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    }();
  }
  bool aborted = false;
  @override
  int progress = 0;
  @override
  late final Future<void> done;
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  Future<void> abort() async {
    aborted = true;
    await done;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Client mainClient;
  late IsolatedSftpClientService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('valhalla_worker_test_');
    mainClient = _Client('main');
  });
  tearDown(() async {
    service.dispose();
    await directory.delete(recursive: true);
  });
  void configure(String mode) {
    final connection = SshTransferConnection(
      host: mode,
      port: 0,
      username: '${directory.path}/remote',
      password: null,
      privateKey: null,
      hostKeyType: 'fixture',
      hostKeyFingerprint: Uint8List.fromList([1, 2, 3]),
    );
    service = IsolatedSftpClientService(
      mainClient,
      connectionFor: () => connection,
      workerConnector: _connect,
    );
  }

  String getLocal() => '${directory.path}/download';

  test(
    'real worker writes exact bytes without blocking main event queue',
    () async {
      configure('cpu');
      var measuring = false;
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        if (measuring) ticks++;
      });
      addTearDown(timer.cancel);
      Map<String, dynamic>? source;
      final handle = await service.startResumableDownload(
        '/fixture',
        getLocal(),
        onSource: (value) => source = value,
        onPhase: (phase, _, _) {
          if (phase == SftpTransferPhase.preparing) measuring = true;
          if (phase == SftpTransferPhase.transferring) measuring = false;
        },
      );
      await handle.done.timeout(const Duration(seconds: 5));
      expect(ticks, greaterThan(5));
      expect(await File(getLocal()).readAsBytes(), _bytes());
      expect(handle.totalBytes, _length);
      expect(handle.transferredBytes, _length);
      expect(source, {'target': '/fixture', 'size': _length, 'modified': 1});
      expect(mainClient.closed, isFalse);
    },
  );

  test(
    'pause during startup holds writes; resume keeps exact final bytes',
    () async {
      configure('streaming');
      final transferring = Completer<void>();
      final progress = <int>[];
      final handle = await service.startResumableDownload(
        '/fixture',
        getLocal(),
        onSource: (_) {},
        onProgress: progress.add,
        onPhase: (phase, _, _) {
          if (phase == SftpTransferPhase.transferring) transferring.complete();
        },
      );
      await handle.pause();
      await transferring.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(handle.transferredBytes, 0);
      expect(await File(getLocal()).length(), 0);
      await handle.resume();
      await handle.done.timeout(const Duration(seconds: 5));
      expect(await File(getLocal()).readAsBytes(), _bytes());
      expect(handle.transferredBytes, _length);
      expect(progress, isNotEmpty);
      expect(progress.length, lessThan(32));
    },
  );

  for (final disposing in [false, true]) {
    test(
      '${disposing ? 'dispose' : 'abort'} cancels pending authentication before any file write',
      () async {
        configure('slow-start');
        final handle = await service.startDownload('/fixture', getLocal());
        final failure = expectLater(
          handle.done,
          throwsA(isA<SftpTransferAborted>()),
        );
        if (disposing) {
          service.dispose();
        } else {
          await handle.abort();
        }
        await failure.timeout(const Duration(seconds: 3));
        expect(await File(getLocal()).exists(), isFalse);
        expect(mainClient.closed, isFalse);
      },
    );
  }

  test(
    'resumed download verifies whole prefix and appends remaining bytes',
    () async {
      configure('fixture');
      await File(getLocal()).writeAsBytes(_bytes().sublist(0, 16384));
      final handle = await service.startResumableDownload(
        '/fixture',
        getLocal(),
        expectedSource: {'target': '/fixture', 'size': _length, 'modified': 1},
        onSource: (_) {},
      );
      await handle.done.timeout(const Duration(seconds: 5));
      expect(await File(getLocal()).readAsBytes(), _bytes());
      expect(handle.transferredBytes, _length);
    },
  );

  test(
    'prefix mismatch is rejected without altering existing partial',
    () async {
      configure('fixture');
      await File(getLocal()).writeAsBytes([0, 0, 0]);
      final handle = await service.startResumableDownload(
        '/fixture',
        getLocal(),
        expectedSource: {'target': '/fixture', 'size': _length, 'modified': 1},
        onSource: (_) {},
      );
      await expectLater(
        handle.done,
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'reason',
            'SFTP_TRANSFER_PARTIAL_INVALID',
          ),
        ),
      );
      expect(await File(getLocal()).readAsBytes(), [0, 0, 0]);
    },
  );

  for (final mode in ['truncated', 'changed']) {
    test('$mode download remains a failure across isolate boundary', () async {
      configure(mode);
      final handle = await service.startResumableDownload(
        '/fixture',
        getLocal(),
        onSource: (_) {},
      );
      await expectLater(
        handle.done,
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'reason',
            mode == 'truncated'
                ? 'SFTP_DOWNLOAD_INCOMPLETE'
                : 'SFTP_TRANSFER_SOURCE_CHANGED',
          ),
        ),
      );
    });
  }

  test(
    'remote permission error preserves status code across isolate boundary',
    () async {
      configure('permission');
      final handle = await service.startDownload('/fixture', getLocal());
      await expectLater(
        handle.done,
        throwsA(
          isA<SftpStatusError>().having(
            (e) => e.code,
            'status',
            SftpStatusCode.permissionDenied,
          ),
        ),
      );
    },
  );

  test('upload reads real source and preserves remote bytes', () async {
    configure('upload');
    await File(getLocal()).writeAsBytes(_bytes());
    final handle = await service.startUpload(getLocal(), '/fixture');
    await handle.done.timeout(const Duration(seconds: 5));
    expect(await File('${directory.path}/remote').readAsBytes(), _bytes());
    expect(handle.transferredBytes, _length);
    expect(mainClient.closed, isFalse);
  });

  test(
    'abort during final upload commit waits for completion instead of killing worker',
    () async {
      configure('commit');
      await File(getLocal()).writeAsBytes(_bytes());
      final committing = Completer<void>();
      final handle = await service.startResumableUpload(
        getLocal(),
        '/fixture',
        transferId: 'fixture',
        onSource: (_) {},
        onPhase: (phase, _, _) {
          if (phase == SftpTransferPhase.verifying) committing.complete();
        },
      );
      await committing.future.timeout(const Duration(seconds: 5));
      expect((handle as SftpCommittingTransfer).isCommitting, isTrue);
      await handle.abort();
      await handle.done.timeout(const Duration(seconds: 5));
      expect(await File('${directory.path}/remote').readAsBytes(), _bytes());
      expect(handle.transferredBytes, _length);
      expect(mainClient.closed, isFalse);
    },
  );
}
