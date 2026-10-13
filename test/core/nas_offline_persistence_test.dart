import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';

/// Deterministic in-memory source. [resolve] returns a fresh validator and a
/// reader that yields exactly the requested byte range.
class _FakeAdapter extends NasSourceAdapter {
  _FakeAdapter(this.source, {required this.payload, this.gate});
  @override
  final NasSource source;
  final List<int> payload;
  Future<void>? gate;
  String? version = 'etag:"v1"';
  int resolveCalls = 0;

  @override
  Future<void> probe() async {}

  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) => const Stream.empty();

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async {
    resolveCalls++;
    return NasResource(
      sizeBytes: payload.length,
      mimeType: 'application/octet-stream',
      version: version,
      read: (start, end, cancellation) async* {
        cancellation.check();
        final stop = end == null || end > payload.length ? payload.length : end;
        final held = gate;
        if (held != null && start == 0) {
          final half = payload.length ~/ 2;
          yield payload.sublist(0, half);
          await held;
          cancellation.check();
          if (half >= stop) return;
          yield payload.sublist(half, stop);
          return;
        }
        if (start >= stop) return;
        yield payload.sublist(start, stop);
      },
    );
  }
}

/// Repository whose restore always fails, so the service never reaches its
/// loaded state. Save calls are counted to prove dispose does not clobber data.
class _LoadFailingRepository extends NasIndexRepository {
  _LoadFailingRepository(super.databasePath);
  int saveCalls = 0;

  @override
  Future<List<NasDownloadTask>> loadDownloads() async =>
      throw StateError('NAS_DOWNLOAD_LOAD_FAILED');

  @override
  Future<void> saveDownloads(List<NasDownloadTask> tasks) async {
    saveCalls++;
    return super.saveDownloads(tasks);
  }
}

NasDownloadService _service(
  Directory directory,
  NasIndexRepository repository,
  Future<NasSourceAdapter> Function(String) adapterFor,
) => NasDownloadService(
  adapterFor,
  platform: DownloadPlatformService(directoryProvider: () async => directory),
  repository: () async => repository,
);

/// Resolves once the broadcast [stream] emits a snapshot matching [matches].
Future<T> _scan<T>(Stream<T> stream, bool Function(T) matches) {
  final completer = Completer<T>();
  late final StreamSubscription<T> subscription;
  subscription = stream.listen((event) {
    if (!completer.isCompleted && matches(event)) {
      completer.complete(event);
      unawaited(subscription.cancel());
    }
  });
  return completer.future;
}

Future<NasDownloadTask> _awaitTask(
  Stream<List<NasDownloadTask>> changes,
  String id,
  NasDownloadStatus status,
) async {
  final tasks = await _scan(
    changes,
    (snapshot) => snapshot.any((t) => t.id == id && t.status == status),
  ).timeout(const Duration(seconds: 15));
  return tasks.singleWhere((t) => t.id == id);
}

/// Runs one real download, persists it, disposes the service and returns it.
Future<(String, NasDownloadTask)> _completeDownload(
  Directory directory,
  NasIndexRepository repository,
  NasSourceAdapter adapter,
  NasMediaItem item,
) async {
  final service = _service(directory, repository, (_) async => adapter);
  await service.ready;
  final pending = _scan(
    service.changes,
    (tasks) => tasks.any((t) => t.status == NasDownloadStatus.completed),
  );
  final id = service.download(item);
  final task = (await pending.timeout(
    const Duration(seconds: 15),
  )).singleWhere((t) => t.id == id);
  await service.dispose();
  return (id, task);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  test(
    'completed download persists and resolves offline without an adapter',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-nas-offline-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/index.sqlite3';
      final repository = NasIndexRepository(databasePath);
      await repository.initialize();

      const source = NasSource(
        id: 'src-offline',
        name: 'Fixture',
        type: NasSourceType.sftp,
      );
      final payload = List<int>.generate(24, (i) => i);
      final adapter = _FakeAdapter(source, payload: payload);
      final service = _service(directory, repository, (_) async => adapter);
      addTearDown(service.dispose);
      await service.ready;

      const item = NasMediaItem(
        serverId: 'src-offline',
        path: '/persist.mp3',
        kind: NasMediaKind.audio,
        sizeBytes: 24,
        modifiedEpoch: 1,
      );
      final pending = _scan(
        service.changes,
        (tasks) => tasks.any((t) => t.status == NasDownloadStatus.completed),
      );
      final id = service.download(item);
      final task = (await pending.timeout(
        const Duration(seconds: 15),
      )).singleWhere((t) => t.id == id);

      expect(task.status, NasDownloadStatus.completed);
      expect(task.sourceIdentity, isNotNull);
      expect(task.resourceVersion, 'etag:"v1"');
      expect(task.sha256, isNotNull);
      expect(task.total, 24);
      expect(task.received, 24);
      final bytes = await File(task.localPath!).readAsBytes();
      expect(bytes, payload);
      expect(sha256.convert(bytes).toString(), task.sha256);

      await service.dispose();

      final restored = _service(
        directory,
        NasIndexRepository(databasePath),
        (_) async => throw StateError('NAS_ADAPTER_NOT_REQUIRED'),
      );
      addTearDown(restored.dispose);
      await restored.ready;

      final persisted = restored.tasks.singleWhere((t) => t.id == id);
      expect(persisted.status, NasDownloadStatus.completed);
      expect(persisted.localPath, task.localPath);
      expect(persisted.sourceIdentity, task.sourceIdentity);
      expect(persisted.resourceVersion, task.resourceVersion);
      expect(persisted.sha256, task.sha256);
      expect(persisted.received, 24);
      expect(await restored.localFile(id), task.localPath);
      expect(await restored.localPathFor(item), task.localPath);
    },
  );

  test('resume continues from the persisted paused offset', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-nas-resume-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final repository = NasIndexRepository(databasePath);
    await repository.initialize();

    const source = NasSource(
      id: 'src-resume',
      name: 'Fixture',
      type: NasSourceType.sftp,
    );
    final payload = List<int>.generate(20, (i) => i);
    final adapter = _FakeAdapter(source, payload: payload);
    const item = NasMediaItem(
      serverId: 'src-resume',
      path: '/resume.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: 20,
      modifiedEpoch: 1,
    );
    final (id, completed) = await _completeDownload(
      directory,
      repository,
      adapter,
      item,
    );
    final localPath = completed.localPath!;

    await repository.saveDownloads([
      NasDownloadTask(
        id: id,
        item: item,
        status: NasDownloadStatus.paused,
        received: 8,
        total: 20,
        localPath: localPath,
        sourceIdentity: completed.sourceIdentity,
        resourceVersion: completed.resourceVersion,
      ),
    ]);
    await File(localPath).delete();
    await File('$localPath.part').writeAsBytes(payload.sublist(0, 8));

    final restored = _service(
      directory,
      NasIndexRepository(databasePath),
      (_) async => adapter,
    );
    addTearDown(restored.dispose);
    await restored.ready;
    final paused = restored.tasks.singleWhere((t) => t.id == id);
    expect(paused.status, NasDownloadStatus.paused);
    expect(paused.received, 8);

    final resumed = _awaitTask(
      restored.changes,
      id,
      NasDownloadStatus.completed,
    );
    await restored.resume(id);
    final done = await resumed;
    expect(done.status, NasDownloadStatus.completed);
    expect(done.received, 20);
    expect(await File(localPath).readAsBytes(), payload);
    expect(await File('$localPath.part').exists(), isFalse);
  });

  test('a changed validator refuses to resume and keeps the partial', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-nas-mutation-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final repository = NasIndexRepository(databasePath);
    await repository.initialize();

    const source = NasSource(
      id: 'src-mutation',
      name: 'Fixture',
      type: NasSourceType.sftp,
    );
    final payload = List<int>.generate(12, (i) => i);
    final adapter = _FakeAdapter(source, payload: payload);
    const item = NasMediaItem(
      serverId: 'src-mutation',
      path: '/mutation.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: 12,
      modifiedEpoch: 1,
    );
    final (id, completed) = await _completeDownload(
      directory,
      repository,
      adapter,
      item,
    );
    final localPath = completed.localPath!;

    await repository.saveDownloads([
      NasDownloadTask(
        id: id,
        item: item,
        status: NasDownloadStatus.paused,
        received: 6,
        total: 12,
        localPath: localPath,
        sourceIdentity: completed.sourceIdentity,
        resourceVersion: completed.resourceVersion,
      ),
    ]);
    await File(localPath).delete();
    await File('$localPath.part').writeAsBytes(payload.sublist(0, 6));

    adapter.version = 'etag:"v2"';

    final restored = _service(
      directory,
      NasIndexRepository(databasePath),
      (_) async => adapter,
    );
    addTearDown(restored.dispose);
    await restored.ready;

    final failed = _awaitTask(restored.changes, id, NasDownloadStatus.failed);
    await restored.resume(id);
    final task = await failed;
    expect(task.status, NasDownloadStatus.failed);
    expect(task.error, 'NAS_DOWNLOAD_SOURCE_CHANGED');
    expect(await File(localPath).exists(), isFalse);
    expect(await File('$localPath.part').exists(), isTrue);
  });

  test('restart discards the partial and reads from the beginning', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-nas-restart-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final repository = NasIndexRepository(databasePath);
    await repository.initialize();

    const source = NasSource(
      id: 'src-restart',
      name: 'Fixture',
      type: NasSourceType.sftp,
    );
    final payload = List<int>.generate(16, (i) => i);
    final adapter = _FakeAdapter(source, payload: payload);
    const item = NasMediaItem(
      serverId: 'src-restart',
      path: '/restart.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: 16,
      modifiedEpoch: 1,
    );
    final (id, completed) = await _completeDownload(
      directory,
      repository,
      adapter,
      item,
    );
    final localPath = completed.localPath!;

    await repository.saveDownloads([
      NasDownloadTask(
        id: id,
        item: item,
        status: NasDownloadStatus.paused,
        received: 4,
        total: 16,
        localPath: localPath,
        sourceIdentity: completed.sourceIdentity,
        resourceVersion: completed.resourceVersion,
      ),
    ]);
    await File(localPath).delete();
    await File('$localPath.part').writeAsBytes(payload.sublist(0, 4));

    final restored = _service(
      directory,
      NasIndexRepository(databasePath),
      (_) async => adapter,
    );
    addTearDown(restored.dispose);
    await restored.ready;

    final completedAgain = _awaitTask(
      restored.changes,
      id,
      NasDownloadStatus.completed,
    );
    await restored.restart(id);
    final task = await completedAgain;
    expect(task.status, NasDownloadStatus.completed);
    expect(task.received, 16);
    expect(await File(task.localPath!).readAsBytes(), payload);
    expect(await File('$localPath.part').exists(), isFalse);
  });

  test(
    'a failed restore never overwrites persisted records on dispose',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-nas-init-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/index.sqlite3';
      final repository = NasIndexRepository(databasePath);
      await repository.initialize();

      const item = NasMediaItem(
        serverId: 'src-failure',
        path: '/saved.bin',
        kind: NasMediaKind.audio,
        sizeBytes: 3,
        modifiedEpoch: 0,
      );
      await repository.saveDownloads([
        const NasDownloadTask(
          id: 'saved',
          item: item,
          status: NasDownloadStatus.completed,
          received: 3,
          total: 3,
          localPath: '/tmp/saved.bin',
          sha256: 'digest',
          sourceIdentity: 'identity',
          resourceVersion: 'etag:"v1"',
        ),
      ]);

      final failing = _LoadFailingRepository(databasePath);
      final service = _service(
        directory,
        failing,
        (_) async => throw StateError('NAS_ADAPTER_NOT_REQUIRED'),
      );
      addTearDown(service.dispose);
      await expectLater(service.ready, throwsA(isA<StateError>()));
      await service.dispose();

      expect(failing.saveCalls, 0);
      expect(service.tasks, isEmpty);

      final saved = await NasIndexRepository(databasePath).loadDownloads();
      expect(saved.single.id, 'saved');
    },
  );

  test(
    'localFile rejects a completed record with a bad or missing file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-nas-checksum-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/index.sqlite3';
      final repository = NasIndexRepository(databasePath);
      await repository.initialize();

      const source = NasSource(
        id: 'src-checksum',
        name: 'Fixture',
        type: NasSourceType.sftp,
      );
      final adapter = _FakeAdapter(source, payload: [1, 2, 3, 4, 5]);
      const item = NasMediaItem(
        serverId: 'src-checksum',
        path: '/checksum.mp3',
        kind: NasMediaKind.audio,
        sizeBytes: 5,
        modifiedEpoch: 1,
      );
      final (id, completed) = await _completeDownload(
        directory,
        repository,
        adapter,
        item,
      );
      final target = File(completed.localPath!);

      final restored = _service(
        directory,
        NasIndexRepository(databasePath),
        (_) async => throw StateError('NAS_ADAPTER_NOT_REQUIRED'),
      );
      addTearDown(restored.dispose);
      await restored.ready;
      expect(
        restored.tasks.singleWhere((t) => t.id == id).status,
        NasDownloadStatus.completed,
      );

      await target.writeAsBytes([9, 9, 9, 9, 9]);
      await expectLater(
        restored.localFile(id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_OFFLINE_FILE_INVALID',
          ),
        ),
      );

      await target.delete();
      await expectLater(
        restored.localFile(id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_OFFLINE_FILE_INVALID',
          ),
        ),
      );
    },
  );

  test('an active download pauses at the written offset and resumes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-nas-pause-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final repository = NasIndexRepository(databasePath);
    await repository.initialize();

    const source = NasSource(
      id: 'src-pause',
      name: 'Fixture',
      type: NasSourceType.sftp,
    );
    final payload = List<int>.generate(20, (i) => i);
    final gate = Completer<void>();
    final adapter = _FakeAdapter(source, payload: payload, gate: gate.future);
    const item = NasMediaItem(
      serverId: 'src-pause',
      path: '/pause.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: 20,
      modifiedEpoch: 1,
    );

    final service = _service(directory, repository, (_) async => adapter);
    addTearDown(service.dispose);
    await service.ready;

    final halfWritten = _scan(
      service.changes,
      (tasks) => tasks.any(
        (t) => t.status == NasDownloadStatus.downloading && t.received >= 10,
      ),
    );
    final id = service.download(item);
    await halfWritten.timeout(const Duration(seconds: 15));

    final pausedSeen = _scan(
      service.changes,
      (tasks) =>
          tasks.any((t) => t.id == id && t.status == NasDownloadStatus.paused),
    );
    final pausing = service.pause(id);
    await pausedSeen.timeout(const Duration(seconds: 15));
    gate.complete();
    await pausing.timeout(const Duration(seconds: 15));

    final paused = service.tasks.singleWhere((t) => t.id == id);
    expect(paused.status, NasDownloadStatus.paused);
    expect(paused.received, 10);
    expect(paused.total, 20);
    expect(paused.localPath, isNotNull);
    expect(
      await File('${paused.localPath}.part').readAsBytes(),
      payload.sublist(0, 10),
    );
    expect(adapter.resolveCalls, 1);

    final resumed = _awaitTask(
      service.changes,
      id,
      NasDownloadStatus.completed,
    );
    await service.resume(id);
    final done = await resumed;
    expect(done.status, NasDownloadStatus.completed);
    expect(done.received, 20);
    expect(
      adapter.resolveCalls,
      3,
      reason: 'resume re-resolves and re-checks the source version',
    );
    expect(await File(done.localPath!).readAsBytes(), payload);
    expect(await File('${done.localPath}.part').exists(), isFalse);
  });

  test('a symlinked target or partial is refused and never written', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-nas-symlink-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final outside = await Directory.systemTemp.createTemp(
      'valhalla-nas-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final databasePath = '${directory.path}/index.sqlite3';
    final repository = NasIndexRepository(databasePath);
    await repository.initialize();

    const source = NasSource(
      id: 'src-symlink',
      name: 'Fixture',
      type: NasSourceType.sftp,
    );
    final payload = List<int>.generate(12, (i) => i);
    final adapter = _FakeAdapter(source, payload: payload);
    const item = NasMediaItem(
      serverId: 'src-symlink',
      path: '/escape.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: 12,
      modifiedEpoch: 1,
    );
    final (id, completed) = await _completeDownload(
      directory,
      repository,
      adapter,
      item,
    );
    final localPath = completed.localPath!;
    expect(localPath.startsWith('${directory.path}/'), isTrue);

    final outsideFile = File('${outside.path}/escape.mp3');
    await outsideFile.writeAsBytes([42, 42, 42]);

    await repository.saveDownloads([
      NasDownloadTask(
        id: id,
        item: item,
        status: NasDownloadStatus.paused,
        received: 0,
        total: 12,
        localPath: localPath,
        sourceIdentity: completed.sourceIdentity,
        resourceVersion: completed.resourceVersion,
      ),
    ]);
    await File(localPath).delete();
    final partLink = Link('$localPath.part');
    await partLink.create(outsideFile.path);

    final service = _service(
      directory,
      NasIndexRepository(databasePath),
      (_) async => adapter,
    );
    addTearDown(service.dispose);
    await service.ready;

    final refusedPartial = _awaitTask(
      service.changes,
      id,
      NasDownloadStatus.failed,
    );
    await service.resume(id);
    final afterPartial = await refusedPartial;
    expect(afterPartial.error, 'NAS_DOWNLOAD_PATH_INVALID');
    expect(
      await FileSystemEntity.type('$localPath.part', followLinks: false),
      FileSystemEntityType.link,
    );
    expect(await outsideFile.readAsBytes(), [42, 42, 42]);

    await partLink.delete();
    final targetLink = Link(localPath);
    await targetLink.create(outsideFile.path);

    final refusedTarget = _awaitTask(
      service.changes,
      id,
      NasDownloadStatus.failed,
    );
    await service.resume(id);
    final afterTarget = await refusedTarget;
    expect(afterTarget.error, 'NAS_DOWNLOAD_PATH_INVALID');
    expect(
      await FileSystemEntity.type(localPath, followLinks: false),
      FileSystemEntityType.link,
    );
    expect(await outsideFile.readAsBytes(), [42, 42, 42]);
  });
}
