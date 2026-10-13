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

class _LocalExecutor extends _Executor {
  final bool portable;
  _LocalExecutor({this.portable = false});
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    if (portable && command.contains('-printf')) {
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

class _FallbackExecutor extends _LocalExecutor {
  _FallbackExecutor() : super(portable: true);
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
    expect(normalized.includePaths, ['/media', '/media/photos']);
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

  for (final portable in [false, true]) {
    final mode = portable ? 'portable' : 'GNU';
    test(
      '$mode explicit roots partition ordinary and symlink subtrees',
      () async {
        final fixture = await Directory.systemTemp.createTemp(
          'valhalla-scan-roots-',
        );
        addTearDown(() => fixture.delete(recursive: true));
        final parent = await Directory('${fixture.path}/parent').create();
        final child = await Directory("${parent.path}/child[*?]'\\").create();
        final grandchild = await Directory('${child.path}/grandchild').create();
        final external = await Directory('${fixture.path}/external').create();
        final ignored = await Directory('${fixture.path}/ignored').create();
        final rootFile = await File(
          '${parent.path}/root.jpg',
        ).writeAsString('root');
        final childFile = await File(
          '${child.path}/child.jpg',
        ).writeAsString('child');
        final grandFile = await File(
          '${grandchild.path}/grand.jpg',
        ).writeAsString('grand');
        await File('${external.path}/external.jpg').writeAsString('external');
        await File('${ignored.path}/sentinel.jpg').writeAsString('ignored');
        final link = await Link(
          '${parent.path}/chosen-link',
        ).create(external.path);
        await Link('${external.path}/internal-link').create(ignored.path);
        await Link('${parent.path}/unselected-link').create(ignored.path);
        final service = NasScanService(_LocalExecutor(portable: portable));
        final items = await service.scan(
          'fixture',
          NasScanConfig(
            includePaths: [
              parent.path,
              child.path,
              grandchild.path,
              link.path,
              link.path,
            ],
          ),
        );
        expect(
          items.map((item) => item.path),
          unorderedEquals([
            rootFile.path,
            childFile.path,
            grandFile.path,
            '${link.path}/external.jpg',
          ]),
        );
        expect(
          await File('${ignored.path}/sentinel.jpg').readAsString(),
          'ignored',
        );
      },
      skip: Platform.isWindows,
    );

    test(
      '$mode literal excludes do not match glob neighbours',
      () async {
        final fixture = await Directory.systemTemp.createTemp(
          'valhalla-scan-glob-',
        );
        addTearDown(() => fixture.delete(recursive: true));
        final excluded = <String>[];
        final kept = <String>[];
        for (final name in [
          'star*',
          'question?',
          'bracket[ab]',
          r'back\slash',
          "quote'",
        ]) {
          final directory = await Directory('${fixture.path}/$name').create();
          await File('${directory.path}/hidden.jpg').writeAsString('skip');
          excluded.add(directory.path);
        }
        for (final name in [
          'star-other',
          'questionx',
          'bracketa',
          'backslash',
          'normal',
        ]) {
          final directory = await Directory('${fixture.path}/$name').create();
          kept.add(
            (await File(
              '${directory.path}/kept.jpg',
            ).writeAsString('keep')).path,
          );
        }
        final items = await NasScanService(_LocalExecutor(portable: portable))
            .scan(
              'fixture',
              NasScanConfig(
                includePaths: [fixture.path],
                excludePaths: excluded,
              ),
            );
        expect(items.map((item) => item.path), unorderedEquals(kept));
      },
      skip: Platform.isWindows,
    );

    test(
      '$mode ancestor and root exclusions produce successful empty scans',
      () async {
        final fixture = await Directory.systemTemp.createTemp(
          'valhalla-scan-exclude-',
        );
        addTearDown(() => fixture.delete(recursive: true));
        final child = await Directory('${fixture.path}/child').create();
        await File('${child.path}/hidden.jpg').writeAsString('skip');
        final service = NasScanService(_LocalExecutor(portable: portable));
        for (final excluded in [fixture.path, child.path, '/']) {
          final config = NasScanConfig(
            includePaths: [child.path],
            excludePaths: [excluded],
          );
          expect(service.normalize(config).excludePaths, [excluded]);
          expect(await service.scan('fixture', config), isEmpty);
        }
        expect(
          await service.scan(
            'fixture',
            NasScanConfig(
              includePaths: [fixture.path, child.path],
              excludePaths: [fixture.path],
            ),
          ),
          isEmpty,
        );
      },
      skip: Platform.isWindows,
    );

    test(
      '$mode missing later root cannot report partial scan success',
      () async {
        final fixture = await Directory.systemTemp.createTemp(
          'valhalla-scan-failure-',
        );
        addTearDown(() => fixture.delete(recursive: true));
        final first = await Directory('${fixture.path}/a-valid').create();
        await File('${first.path}/first.jpg').writeAsString('first');
        await expectLater(
          NasScanService(_LocalExecutor(portable: portable)).scan(
            'fixture',
            NasScanConfig(
              includePaths: [first.path, '${fixture.path}/z-missing'],
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'code',
              startsWith('NAS_SCAN_FAILED:'),
            ),
          ),
        );
      },
      skip: Platform.isWindows,
    );
  }
}
