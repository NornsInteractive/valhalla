import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_scan_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Executor implements SshCommandExecutor {
  SSHClient? client;
  String? command;
  SSHExecutionResult result = const SSHExecutionResult(
    exitCode: 0,
    stdout:
        '/media/a.jpg\u0000123\u00001700000000.5\u0000'
        '/media/b.MP3\u0000456\u00001700000001\u0000',
    stderr: '',
  );

  @override
  SSHClient? getClient(String serverId) => client;

  @override
  bool isConnected(String serverId) => true;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    this.command = command;
    return result;
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream.empty();
}

class _Client extends Fake implements SSHClient {
  final _Session session;
  _Client(this.session);
  @override
  bool get isClosed => false;
  @override
  Future<SSHSession> execute(
    String command, {
    Map<String, String>? environment,
    SSHPtyConfig? pty,
    SSHX11Config? x11,
  }) async => session;
}

class _Session extends Fake implements SSHSession {
  bool closed = false;
  @override
  final int exitCode;
  _Session({this.exitCode = 0});
  @override
  Stream<Uint8List> get stdout => Stream.value(
    Uint8List.fromList(
      utf8.encode('/a.jpg\u00001\u00002\u0000/b.jpg\u00001\u00002\u0000'),
    ),
  );
  @override
  Stream<Uint8List> get stderr => const Stream.empty();
  @override
  Future<void> get done async {}
  @override
  void close() {
    closed = true;
  }
}

class _FallbackExecutor extends _Executor {
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    if (command.contains('-printf')) {
      return const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'find: unknown primary -printf',
      );
    }
    final result = await Process.run('sh', ['-c', command]);
    return SSHExecutionResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}

void main() {
  test('normalizes roots, applies excludes, and parses nul records', () async {
    final executor = _Executor();
    final service = NasScanService(executor);
    final normalized = service.normalize(
      const NasScanConfig(
        includePaths: ['/media/photos', '/media', '/media'],
        excludePaths: ['/media/private', '/outside'],
      ),
    );
    expect(normalized.includePaths, ['/media']);
    expect(normalized.excludePaths, ['/media/private']);

    final items = await service.scan('server', normalized);
    expect(items.map((item) => item.kind), [
      NasMediaKind.image,
      NasMediaKind.audio,
    ]);
    expect(items.first.sizeBytes, 123);
    expect(executor.command, contains("'/media/private'"));
    expect(executor.command, contains('-printf'));
  });

  test(
    'raw scanner decodes split UTF8 and NUL records in bounded batches',
    () async {
      final bytes = utf8.encode(
        '/照片/旅行.jpg\u0000123\u00001700000000.5\u0000'
        '/music/line\nbreak.mp3\u0000456\u00001700000001\u0000',
      );
      final batches = await NasScanService.decodeRecords(
        'one',
        Stream.fromIterable(bytes.map((byte) => [byte])),
        NasCancellation(),
        batchSize: 1,
      ).toList();
      expect(batches.map((batch) => batch.length), [1, 1]);
      expect(batches.first.single.path, '/照片/旅行.jpg');
      expect(batches.last.single.path, '/music/line\nbreak.mp3');
      expect(batches.first.single.modifiedEpoch, 1700000000);
    },
  );

  test(
    'raw scanner rejects truncated input and stops promptly on cancellation',
    () async {
      await expectLater(
        NasScanService.decodeRecords(
          'one',
          Stream.value(utf8.encode('/photo.jpg\u0000123')),
          NasCancellation(),
        ).drain<void>(),
        throwsFormatException,
      );
      final cancellation = NasCancellation();
      final iterator = StreamIterator(
        NasScanService.decodeRecords(
          'one',
          Stream.value(
            utf8.encode('/a.jpg\u00001\u00002\u0000/b.jpg\u00001\u00002\u0000'),
          ),
          cancellation,
          batchSize: 1,
        ),
      );
      expect(await iterator.moveNext(), true);
      cancellation.cancel();
      await expectLater(iterator.moveNext(), throwsA(isA<NasCancelled>()));
      await iterator.cancel();
    },
  );

  test('rejects relative paths before executing remotely', () {
    final service = NasScanService(_Executor());
    expect(
      () => service.normalize(const NasScanConfig(includePaths: ['media'])),
      throwsArgumentError,
    );
  });

  test(
    'cancellation closes the SSH channel and nonzero exit cannot complete a scan',
    () async {
      final executor = _Executor();
      final session = _Session();
      executor.client = _Client(session);
      final cancel = NasCancellation();
      final iterator = StreamIterator(
        NasScanService(executor).scanBatches(
          'one',
          const NasScanConfig(includePaths: ['/media']),
          cancel,
          batchSize: 1,
        ),
      );
      expect(await iterator.moveNext(), true);
      cancel.cancel();
      expect(session.closed, true);
      await expectLater(iterator.moveNext(), throwsA(isA<NasCancelled>()));
      await iterator.cancel();
      final failedSession = _Session(exitCode: 1);
      executor.client = _Client(failedSession);
      await expectLater(
        NasScanService(executor)
            .scanBatches(
              'one',
              const NasScanConfig(includePaths: ['/media']),
              NasCancellation(),
            )
            .drain<void>(),
        throwsStateError,
      );
      expect(failedSession.closed, true);
    },
  );

  test(
    'portable fallback emits actual NUL bytes and preserves quoted filenames',
    () async {
      if (Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp('valhalla-scan-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File("${directory.path}/照片'line\nbreak.jpg");
      await file.writeAsBytes([1, 2, 3]);
      final result = await NasScanService(
        _FallbackExecutor(),
      ).scan('one', NasScanConfig(includePaths: [directory.path]));
      expect(result.single.path, file.path);
      expect(result.single.sizeBytes, 3);
    },
  );
}
