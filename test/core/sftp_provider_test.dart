import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_transfer_handle.dart';

SftpFileItem _item(
  String name, {
  bool isDirectory = false,
  int size = 12,
  String? path,
}) => SftpFileItem(
  name: name,
  path: path ?? '/root/$name',
  isDirectory: isDirectory,
  sizeBytes: size,
  formattedSize: '$size B',
  permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
  modified: '2026-09-16',
);

/// 记录调用并按需抛错的远端操作替身。
///
/// `files` / `throwing` 都在构造后按需赋值，故不做构造参数（避免未使用参数告警）。
class _FakeOps implements SftpOperations {
  List<SftpFileItem> files = const [];
  final listGates = <String, Completer<List<SftpFileItem>>>{};
  final readGates = <String, Completer<String>>{};
  Completer<void>? writeGate;

  /// 非空时所有读写操作直接抛出它，用来测失败分支。
  Object? throwing;

  final List<String> listedPaths = [];
  final List<(String, String)> uploads = [];
  final List<(String, String)> downloads = [];
  final List<String> readPaths = [];

  /// 上传时回调的进度值，用来断言进度确实写进了 state。
  List<int> uploadProgress = const [];
  int uploadBytes = 0;

  /// 非空时 [uploadFile] 会等它完成，用来制造稳定的「传输进行中」窗口。
  Completer<void>? uploadGate;

  T _guard<T>(T Function() body) {
    if (throwing != null) throw throwing!;
    return body();
  }

  @override
  Future<List<SftpFileItem>> listFiles(String path) async {
    listedPaths.add(path);
    if (listGates[path] case final gate?) return gate.future;
    return _guard(() => files);
  }

  @override
  Future<String> readFileContent(String path) async {
    readPaths.add(path);
    if (readGates[path] case final gate?) return gate.future;
    return _guard(() => 'content of $path');
  }

  @override
  Future<void> writeFileContent(String path, String content) async {
    await writeGate?.future;
    _guard(() => null);
  }

  @override
  Future<void> createDirectory(String path) async {
    _guard(() => null);
  }

  @override
  Future<void> deleteFile(String path) async {
    _guard(() => null);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    _guard(() => null);
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {
    _guard(() => null);
  }

  /// 最近一次 startUpload / startDownload 返回的句柄，测试用它推进进度。
  FakeTransferHandle? lastHandle;

  /// 每次 startUpload 生成的句柄，用来观察「第二个任务有没有被跑起来」。
  final List<FakeTransferHandle> uploadHandles = [];

  /// 每次 startDownload 生成的句柄。
  final List<FakeTransferHandle> downloadHandles = [];

  /// 让替身生成的句柄立刻抛错，用来测失败分支。
  Object? handleFailure;

  /// `startUpload` 是否同步抛出 [throwing]。
  ///
  /// 真实实现在建连/开文件阶段就会失败，这时**连句柄都没有**，
  /// 与「句柄拿到手之后传输中途失败」是两条不同的路径。
  /// 两种都要能测：否则「建连失败」分支会被漏掉。
  bool throwOnStart = false;

  /// 上传句柄一被返回就立刻完成（或立刻失败）。
  ///
  /// 真实实现里 0 字节文件、极小文件都会在 `startUpload` 返回后
  /// 几乎马上完成，这时暂停请求是在任务已经结束之后才到的，
  /// 队列必须能正确处理这种竞态。
  bool autoCompleteUpload = true;

  /// 同上，下载方向。
  bool autoCompleteDownload = true;

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    if (throwOnStart) _guard(() => null);
    uploads.add((localPath, remotePath));
    final handle = FakeTransferHandle(
      totalBytes: uploadBytes,
      onProgress: onProgress,
    );
    lastHandle = handle;
    uploadHandles.add(handle);
    // 真实实现会在句柄构造后尽快回调一次进度；替身也照做，
    // 让「进度确实写进了 state」这类断言有东西可断。
    for (final b in uploadProgress) {
      handle.emitProgress(b);
    }
    if (uploadGate != null) {
      // 队列测试需要「传着传着停住」的窗口：等闸门放行后再完成。
      unawaited(uploadGate!.future.then((_) => handle.finish()));
    } else if (autoCompleteUpload) {
      unawaited(
        Future.microtask(() {
          final error = handleFailure;
          if (error != null) {
            handle.fail(error);
          } else {
            handle.finish();
          }
        }),
      );
    }
    return handle;
  }

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    if (throwOnStart) _guard(() => null);
    downloads.add((remotePath, localPath));
    final handle = FakeTransferHandle(
      totalBytes: downloadBytes,
      onProgress: onProgress,
    );
    lastHandle = handle;
    downloadHandles.add(handle);
    for (final b in downloadProgress) {
      handle.emitProgress(b);
    }
    if (downloadGate != null) {
      unawaited(downloadGate!.future.then((_) => handle.finish()));
    } else if (autoCompleteDownload) {
      unawaited(
        Future.microtask(() {
          final error = handleFailure;
          if (error != null) {
            handle.fail(error);
          } else {
            handle.finish();
          }
        }),
      );
    }
    return handle;
  }

  /// 下载时报告的总字节数。
  int downloadBytes = 0;

  /// 下载时要回调的进度序列。
  List<int> downloadProgress = const [];

  /// 非空时下载会等它完成，用来制造稳定的「传输进行中」窗口。
  Completer<void>? downloadGate;

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    final handle = await startUpload(
      localPath,
      remotePath,
      onProgress: onProgress,
    );
    await handle.done;
    return uploadBytes;
  }

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    final handle = await startDownload(
      remotePath,
      localPath,
      onProgress: onProgress,
    );
    await handle.done;
    return handle.transferredBytes;
  }
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingDownloads extends DownloadPlatformService {
  _RecordingDownloads(Directory directory)
    : super(directoryProvider: () async => directory);
  final opened = <String>[];
  final reports = <Map<String, Object?>>[];

  @override
  Future<void> openFile(String path) async => opened.add(path);

  @override
  Future<bool> report(Map<String, Object?> transfer) async {
    reports.add(transfer);
    return true;
  }
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

class _ConnectedNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _StubActiveServer extends ActiveServerNotifier {
  void switchServer() => state = state!.copyWith(id: 'srv-2');
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

Future<ProviderContainer> _container(
  _FakeOps ops, {
  DownloadPlatformService? downloads,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      sftpOperationsProvider.overrideWithValue(ops),
      if (downloads != null)
        downloadPlatformServiceProvider.overrideWithValue(downloads),
    ],
  );
}

/// 同上，但换掉完成通知回调，用来断言「通知发了几次、发的是什么」。
Future<ProviderContainer> _containerWithNotify(
  _FakeOps ops,
  void Function(SftpTransfer) notify,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      sftpOperationsProvider.overrideWithValue(ops),
      transferNotificationCallbackProvider.overrideWithValue(notify),
    ],
  );
}

/// 等到某个任务进入终态为止。
///
/// 队列是「入队即返回」的异步调度，用固定次数的 `pumpEventQueue()` 去撞
/// 时序很脆（多一次少一次都可能让断言落在中间态上）。这里轮询状态，
/// 最多 100 轮——足够跑完所有 microtask 而不会真的卡住测试。
Future<SftpTransfer> _awaitStatus(
  ProviderContainer container,
  String id,
  SftpTransferStatus status,
) async {
  for (var i = 0; i < 100; i++) {
    final task = container.read(sftpProvider).transferById(id);
    if (task != null && task.status == status) return task;
    if (i > 0) {
      // 每次都 `pumpEventQueue()`：一来推进 microtask，二来让
      // provider 里未捕获的异常浮出来。不能用 `runZonedGuarded` 之类
      // 把它吞掉——那会把「队列在后台崩了」变成一条静默的 fail 超时。
      await pumpEventQueue();
    }
  }
  fail(
    '任务 $id 没有在预期内变成 $status，当前是 '
    '${container.read(sftpProvider).transferById(id)?.status}',
  );
}

void main() {
  test(
    'managed download opens only after part file becomes completed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-queue-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final platform = _RecordingDownloads(directory);
      final ops = _FakeOps()..autoCompleteDownload = false;
      final container = await _container(ops, downloads: platform);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      final id = (await notifier.downloadFile(_item('report.txt')))!;
      await pumpEventQueue();
      final task = container.read(sftpProvider).transferById(id)!;
      expect(ops.downloads.single.$2, '${task.localPath}.part');
      await notifier.openCompletedTransfer(id);
      expect(platform.opened, isEmpty);
      await File('${task.localPath}.part').writeAsString('downloaded');
      ops.downloadHandles.single.finish();
      await _awaitStatus(container, id, SftpTransferStatus.completed);
      expect(await File(task.localPath).readAsString(), 'downloaded');
      expect(await File('${task.localPath}.part').exists(), isFalse);
      await notifier.openCompletedTransfer(id);
      expect(platform.opened, [task.localPath]);
      expect(platform.reports.last['status'], 'completed');
    },
  );

  test('late directory response cannot replace a newer path', () async {
    final ops = _FakeOps();
    final container = await _container(ops);
    addTearDown(container.dispose);
    final notifier = container.read(sftpProvider.notifier);
    await pumpEventQueue();
    final old = ops.listGates['/old'] = Completer<List<SftpFileItem>>();
    final newer = ops.listGates['/new'] = Completer<List<SftpFileItem>>();
    final first = notifier.loadDirectory('/old');
    final second = notifier.loadDirectory('/new');
    newer.complete([_item('new.txt')]);
    expect(await second, isTrue);
    old.complete([_item('old.txt')]);
    expect(await first, isFalse);
    expect(container.read(sftpProvider).currentPath, '/new');
    expect(container.read(sftpProvider).files.single.name, 'new.txt');
  });

  test(
    'source switch ignores an old directory error and pending editor',
    () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      final listing = ops.listGates['/old'] = Completer<List<SftpFileItem>>();
      final reading = ops.readGates['/root/old.txt'] = Completer<String>();
      final list = notifier.loadDirectory('/old');
      final read = notifier.openFileForEditing(_item('old.txt'));
      (container.read(activeServerProvider.notifier) as _StubActiveServer)
          .switchServer();
      container.read(sftpProvider);
      await pumpEventQueue();
      listing.completeError(StateError('old source failed'));
      reading.complete('old private contents');
      expect(await list, isFalse);
      await read;
      final state = container.read(sftpProvider);
      expect(state.currentPath, '/');
      expect(state.errorMessage, isNull);
      expect(state.editingFileContent, isNull);
    },
  );

  test(
    'closing editor while reading prevents reopening on late completion',
    () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      final reading = ops.readGates['/root/old.txt'] = Completer<String>();
      final read = notifier.openFileForEditing(_item('old.txt'));
      notifier.closeFileEditor();
      reading.complete('contents');
      await read;
      expect(container.read(sftpProvider).editingFileContent, isNull);
      expect(container.read(sftpProvider).isLoading, isFalse);
    },
  );

  test(
    'known and growing large previews expose download guidance reason',
    () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.openFileForEditing(
        _item('huge.txt', size: 1024 * 1024 + 1),
      );
      expect(ops.readPaths, isEmpty);
      expect(
        container.read(sftpProvider).errorMessage,
        SftpNotifier.previewTooLargeCode,
      );
      ops.throwing = const SFTPException(SftpNotifier.previewTooLargeCode);
      await notifier.openFileForEditing(_item('grew.txt', size: 0));
      expect(
        container.read(sftpProvider).errorMessage,
        SftpNotifier.previewTooLargeCode,
      );
    },
  );

  test(
    'write completing after a source switch does not refresh the new server',
    () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      ops.writeGate = Completer<void>();
      final saving = notifier.saveFileContent('/old.txt', 'contents');
      (container.read(activeServerProvider.notifier) as _StubActiveServer)
          .switchServer();
      container.read(sftpProvider);
      await pumpEventQueue();
      ops.listedPaths.clear();
      ops.writeGate!.complete();
      await saving;
      expect(ops.listedPaths, isEmpty);
    },
  );

  group('SftpNotifier directory navigation', () {
    test('normalizes dot-dot paths and clears search after success', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      ops.listedPaths.clear();

      await notifier.navigateTo('/var/www');
      notifier.setSearchQuery('nginx');
      await notifier.navigateTo('/var/www/..');

      expect(ops.listedPaths, ['/var/www', '/var']);
      expect(container.read(sftpProvider).currentPath, '/var');
      expect(container.read(sftpProvider).searchQuery, isEmpty);
    });

    test('failed directory change preserves the active search', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      notifier.setSearchQuery('keep-me');
      ops.throwing = StateError('denied');

      await notifier.navigateTo('/private');

      expect(container.read(sftpProvider).searchQuery, 'keep-me');
    });
  });

  group('SftpNotifier.canPreview', () {
    test('text file is previewable', () async {
      final container = await _container(_FakeOps());
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      // build() 里排队了首次 loadDirectory；不排空的话容器 dispose 后
      // 那个 microtask 仍会跑，触发 "Ref ... after it has been disposed"。
      await pumpEventQueue();

      expect(notifier.canPreview(_item('nginx.conf')), isTrue);
      expect(notifier.canPreview(_item('app.dart')), isTrue);
    });

    test('binary file is not previewable', () async {
      final container = await _container(_FakeOps());
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      // build() 里排队了首次 loadDirectory；不排空的话容器 dispose 后
      // 那个 microtask 仍会跑，触发 "Ref ... after it has been disposed"。
      await pumpEventQueue();

      expect(notifier.canPreview(_item('photo.png')), isFalse);
      expect(notifier.canPreview(_item('app.apk')), isFalse);
    });

    test('directories are never previewable', () async {
      final container = await _container(_FakeOps());
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      // build() 里排队了首次 loadDirectory；不排空的话容器 dispose 后
      // 那个 microtask 仍会跑，触发 "Ref ... after it has been disposed"。
      await pumpEventQueue();

      // 名字看起来像文本也不行——目录不是文件。
      expect(
        notifier.canPreview(_item('notes.txt', isDirectory: true)),
        isFalse,
      );
    });
  });

  group('SftpNotifier.openFileForEditing', () {
    test('refuses unsupported types without reading the remote file', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(_item('archive.zip'));

      expect(
        container.read(sftpProvider).errorMessage,
        SftpNotifier.previewUnsupportedCode,
      );
      // 关键：不能为了「预览失败」而先把整个二进制读进来。
      expect(ops.readPaths, isEmpty);
      expect(container.read(sftpProvider).editingFilePath, isNull);
    });

    test('loads supported types into the editor', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(_item('main.py'));

      final state = container.read(sftpProvider);
      expect(state.editingFilePath, '/root/main.py');
      expect(state.editingFileContent, contains('main.py'));
      expect(state.errorMessage, isNull);
    });

    test('reports a reason code when reading fails', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.throwing = const SFTPException('permission denied');
      await notifier.openFileForEditing(_item('main.py'));

      final state = container.read(sftpProvider);
      // 必须是稳定 code 而不是把异常文本拼进 errorMessage：UI 靠它选 ARB 文案。
      expect(state.errorMessage, SftpNotifier.readFailedCode);
      expect(state.editingFilePath, isNull);
      // 读失败不能留下转圈状态。
      expect(state.isLoading, isFalse);
    });
  });

  group('SftpNotifier.uploadFrom', () {
    test('uploads into the current directory and refreshes', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      // build() 里的首次加载是 microtask，先等它跑完。
      await pumpEventQueue();
      ops.listedPaths.clear();

      await notifier.uploadFrom('/local/report.pdf');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      expect(ops.uploads, [('/local/report.pdf', '/report.pdf')]);
      expect(ops.listedPaths, contains('/'), reason: '上传成功后应刷新当前目录让新文件可见');
      final state = container.read(sftpProvider);
      // 任务条目保留在列表里（终态），但不该再有 running 的任务。
      expect(state.activeTransfer, isNull);
    });

    test('honours an explicit remote name', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/tmp123', remoteName: 'deploy.sh');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      expect(ops.uploads, [('/local/tmp123', '/deploy.sh')]);
    });

    test('reports a reason code on failure without throwing', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.throwing = const SFTPException('permission denied');
      // 建连阶段就失败：这时连句柄都没有，是另一条失败路径。
      ops.throwOnStart = true;
      await notifier.uploadFrom('/local/report.pdf');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.failed);

      final state = container.read(sftpProvider);
      expect(state.errorMessage, SftpNotifier.uploadFailedCode);
      // 失败后不能留下一个永远转圈的进度条。
      expect(state.activeTransfer, isNull);
      // 但要在列表里留下一条可读的失败记录：用户需要看到「哪个文件失败了」。
      final failed = state.transfers.single;
      expect(failed.errorMessage, SftpNotifier.uploadFailedCode);
      expect(failed.fileName, 'report.pdf');
    });

    test('传输中途失败（句柄已拿到）也要记成 failed', () async {
      // 与上一条的区别：失败发生在 startUpload 成功返回之后。
      // 这是更常见的一类失败（网络中断、远端磁盘写满），
      // 上层必须把 done 的异常翻译成 reason code，而不是让它漏出去。
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.handleFailure = const SFTPException('connection reset');
      await notifier.uploadFrom('/local/report.pdf');
      final id = container.read(sftpProvider).transfers.single.id;
      final task = await _awaitStatus(container, id, SftpTransferStatus.failed);

      expect(task.errorMessage, SftpNotifier.uploadFailedCode);
      expect(container.read(sftpProvider).errorMessage, isNotNull);
      expect(container.read(sftpProvider).activeTransfer, isNull);
    });

    test('exposes progress while the upload runs', () async {
      final ops = _FakeOps()
        ..uploadProgress = [256]
        ..uploadBytes = 1024
        // 卡住上传，制造一个「传输进行中」的稳定窗口。
        ..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/big.bin');
      await pumpEventQueue();

      // 传输进行中：状态里必须有 transfer，且进度已按 onProgress 写入。
      final during = container.read(sftpProvider).activeTransfer;
      expect(during, isNotNull, reason: '传输期间应暴露 transfer');
      expect(during!.kind, SftpTransferKind.upload);
      expect(during.localPath, '/local/big.bin');
      expect(during.remotePath, '/big.bin');
      expect(during.transferredBytes, 256);
      expect(during.totalBytes, 1024);
      expect(during.status, SftpTransferStatus.running);

      ops.uploadGate!.complete();
      await _awaitStatus(container, during.id, SftpTransferStatus.completed);

      // 结束后必须清掉，否则 UI 会一直显示进度条。
      expect(container.read(sftpProvider).activeTransfer, isNull);
    });

    test('queues a second upload instead of dropping it', () async {
      final ops = _FakeOps()..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/a.txt');
      await pumpEventQueue();
      final firstId = container.read(sftpProvider).transfers[0].id;
      await _awaitStatus(container, firstId, SftpTransferStatus.running);

      // 第一个还没结束时就发起第二个：它必须排队，而不是被丢掉。
      await notifier.uploadFrom('/local/b.txt');
      await pumpEventQueue();

      var state = container.read(sftpProvider);
      expect(ops.uploads.map((u) => u.$1), [
        '/local/a.txt',
      ], reason: '串行队列：第二个必须等第一个结束，不能并发');
      expect(state.transfers.length, 2, reason: '第二个任务要排队而不是被丢弃');
      expect(state.transfers[1].status, SftpTransferStatus.queued);
      expect(state.transfers[1].localPath, '/local/b.txt');
      expect(state.pendingTransferCount, 2);

      // 放行第一个，第二个应自动接着跑。
      ops.uploadGate!.complete();
      final secondId = state.transfers[1].id;
      await _awaitStatus(container, secondId, SftpTransferStatus.completed);

      state = container.read(sftpProvider);
      expect(ops.uploads.map((u) => u.$1), ['/local/a.txt', '/local/b.txt']);
      expect(state.transfers.map((t) => t.status), [
        SftpTransferStatus.completed,
        SftpTransferStatus.completed,
      ]);
      expect(state.activeTransfer, isNull);
    });
  });

  group('SftpNotifier.downloadTo', () {
    test('downloads a remote file to the given local path', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.downloadTo(_item('nginx.conf'), '/tmp/nginx.conf');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      expect(ops.downloads, [('/root/nginx.conf', '/tmp/nginx.conf')]);
      final state = container.read(sftpProvider);
      expect(state.activeTransfer, isNull);
      // 下载用远端条目的 sizeBytes 作为总大小，进度条才有分母。
      expect(state.transfers.single.totalBytes, 12);
    });

    test('reports a reason code on failure without throwing', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.throwing = const SFTPException('no space left on device');
      ops.throwOnStart = true;
      await notifier.downloadTo(_item('big.iso'), '/tmp/big.iso');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.failed);

      final state = container.read(sftpProvider);
      expect(state.errorMessage, SftpNotifier.downloadFailedCode);
      expect(state.activeTransfer, isNull);
      expect(
        state.transfers.single.errorMessage,
        SftpNotifier.downloadFailedCode,
      );
    });

    test('传输中途失败（句柄已拿到）也要记成 failed', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.handleFailure = const SFTPException('connection reset');
      await notifier.downloadTo(_item('big.iso'), '/tmp/big.iso');
      final id = container.read(sftpProvider).transfers.single.id;
      final task = await _awaitStatus(container, id, SftpTransferStatus.failed);

      expect(task.errorMessage, SftpNotifier.downloadFailedCode);
    });
  });

  group('SftpNotifier 下载重试门', () {
    /// 只有 TIMEOUT / DISCONNECTED 会被重试，且**每个任务只重试一次**。
    /// 其余分类（权限、缺失、磁盘、截断）都是永久失败，立刻定案。
    Future<SftpTransfer> failedAfterRetry(Object failure, _FakeOps ops) async {
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.handleFailure = failure;
      await notifier.downloadTo(_item('big.iso'), '/tmp/big.iso');
      final id = container.read(sftpProvider).transfers.single.id;
      final task = await _awaitStatus(container, id, SftpTransferStatus.failed);
      expect(
        container.read(sftpProvider).activeTransfer,
        isNull,
        reason: '重试结束后不能留下悬挂的活动任务',
      );
      return task;
    }

    test('超时重试一次，两次都超时后才记成 TIMEOUT', () async {
      final ops = _FakeOps();
      final task = await failedAfterRetry(
        TimeoutException('read', const Duration(seconds: 1)),
        ops,
      );

      expect(task.errorMessage, 'SFTP_DOWNLOAD_TIMEOUT');
      expect(ops.downloads, hasLength(2), reason: '只允许一次重试');
    });

    test('断线重试一次，两次都断线后记成 DISCONNECTED', () async {
      final ops = _FakeOps();
      final task = await failedAfterRetry(
        const SSHConnectionException('SSH_DISCONNECTED'),
        ops,
      );

      expect(task.errorMessage, 'SFTP_DOWNLOAD_DISCONNECTED');
      expect(ops.downloads, hasLength(2), reason: '只允许一次重试');
    });

    test('权限不足是永久失败，不消耗重试', () async {
      final ops = _FakeOps();
      final task = await failedAfterRetry(
        SftpStatusError(SftpStatusCode.permissionDenied, 'denied'),
        ops,
      );

      expect(task.errorMessage, 'SFTP_DOWNLOAD_PERMISSION_DENIED');
      expect(ops.downloads, hasLength(1), reason: '重试不可能改变结果');
    });

    test('截断（early EOF）是永久失败，不消耗重试', () async {
      final ops = _FakeOps();
      final task = await failedAfterRetry(
        const SFTPException('SFTP_DOWNLOAD_INCOMPLETE'),
        ops,
      );

      expect(task.errorMessage, 'SFTP_DOWNLOAD_INCOMPLETE');
      expect(ops.downloads, hasLength(1));
    });

    test('磁盘写满是永久失败，不消耗重试', () async {
      final ops = _FakeOps();
      final task = await failedAfterRetry(
        const FileSystemException(
          'write',
          '/tmp/big.iso',
          OSError('No space left on device', 28),
        ),
        ops,
      );

      expect(task.errorMessage, 'SFTP_DOWNLOAD_LOCAL_SPACE');
      expect(ops.downloads, hasLength(1));
    });

    test('重试用的是同一个任务 id，不会把自己算成第二个任务', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.handleFailure = TimeoutException('read', const Duration(seconds: 1));
      await notifier.downloadTo(_item('big.iso'), '/tmp/big.iso');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.failed);

      final state = container.read(sftpProvider);
      expect(state.transfers.map((t) => t.id), [id], reason: '没有新任务');
      expect(ops.downloads, hasLength(2));
    });

    test('上一个任务耗尽重试后，新任务仍然有自己的重试额度', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      ops.handleFailure = TimeoutException('read', const Duration(seconds: 1));
      await notifier.downloadTo(_item('first.iso'), '/tmp/first.iso');
      final firstId = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, firstId, SftpTransferStatus.failed);
      expect(ops.downloads, hasLength(2));

      await notifier.downloadTo(_item('second.iso'), '/tmp/second.iso');
      final secondId = container.read(sftpProvider).transfers.last.id;
      expect(secondId, isNot(firstId));
      final second = await _awaitStatus(
        container,
        secondId,
        SftpTransferStatus.failed,
      );

      expect(second.errorMessage, 'SFTP_DOWNLOAD_TIMEOUT');
      expect(ops.downloads, hasLength(4), reason: '新任务也有一次重试额度');
      expect(
        container.read(sftpProvider).transferById(firstId)!.errorMessage,
        'SFTP_DOWNLOAD_TIMEOUT',
        reason: '已完成的失败记录不得被后来的任务改写',
      );
    });
  });

  group('SftpNotifier 传输队列', () {
    /// 建一个「第一个任务卡在闸门上」的容器，方便测队列的中间态。
    Future<(ProviderContainer, SftpNotifier, _FakeOps)> busyContainer() async {
      final ops = _FakeOps()..uploadGate = Completer<void>();
      final container = await _container(ops);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');
      await _awaitStatus(
        container,
        container.read(sftpProvider).transfers.single.id,
        SftpTransferStatus.running,
      );
      return (container, notifier, ops);
    }

    test('暂停 running 任务后它让位，后面的任务开始跑', () async {
      final (container, notifier, ops) = await busyContainer();
      addTearDown(container.dispose);
      await notifier.uploadFrom('/local/b.txt');
      await pumpEventQueue();

      final firstId = container.read(sftpProvider).transfers[0].id;
      await notifier.pauseTransfer(firstId);
      await pumpEventQueue();

      final state = container.read(sftpProvider);
      expect(state.transferById(firstId)!.status, SftpTransferStatus.paused);
      // 关键：暂停一个 running 任务必须重新调度，否则队列永久卡住。
      expect(ops.uploads.map((u) => u.$1), [
        '/local/a.txt',
        '/local/b.txt',
      ], reason: '暂停后必须重新调度队列，让排队的任务开始跑');
      expect(
        state.transfers[1].status,
        SftpTransferStatus.running,
        reason: '排在后面的任务应该接过执行权',
      );
      expect(ops.uploadHandles.first.pauseCount, 1, reason: '暂停要真的传到句柄上');
    });

    test('暂停后进度不再推进，继续后恢复推进', () async {
      final ops = _FakeOps()
        ..uploadProgress = [256]
        ..uploadBytes = 1024
        ..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');

      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.running);
      final handle = ops.lastHandle!;
      expect(
        container.read(sftpProvider).transferById(id)!.transferredBytes,
        256,
      );

      await notifier.pauseTransfer(id);
      handle.emitProgress(512);
      await pumpEventQueue();

      // 句柄在暂停时不该产生新进度；即便产生了，状态也不该被改写。
      expect(
        container.read(sftpProvider).transferById(id)!.transferredBytes,
        256,
        reason: '暂停期间进度不能继续涨',
      );

      await notifier.resumeTransfer(id);
      handle.emitProgress(768);
      await pumpEventQueue();

      final state = container.read(sftpProvider);
      expect(state.transferById(id)!.status, SftpTransferStatus.running);
      expect(state.transferById(id)!.transferredBytes, 768);
      expect(handle.resumeCount, 1, reason: '继续要真的传到句柄上');
      // 暂停/继续不该重新排队，否则会把文件从头再传一遍。
      expect(ops.uploads.length, 1);
    });

    test('取消 running 任务会中止句柄并留下 canceled 记录', () async {
      final (container, notifier, ops) = await busyContainer();
      addTearDown(container.dispose);
      final id = container.read(sftpProvider).transfers.single.id;

      await notifier.cancelTransfer(id);
      await _awaitStatus(container, id, SftpTransferStatus.canceled);

      final state = container.read(sftpProvider);
      final task = state.transferById(id)!;
      expect(ops.lastHandle!.abortCount, 1, reason: '取消必须真的中止句柄');
      // 主动取消不是错误，不能弹错误提示（用户知道自己在干什么）。
      expect(task.errorMessage, isNull);
      expect(state.errorMessage, isNull);
      expect(state.activeTransfer, isNull);
    });

    test('取消一个已经结束的任务是空操作', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      await notifier.cancelTransfer(id);

      final task = container.read(sftpProvider).transferById(id)!;
      expect(
        task.status,
        SftpTransferStatus.completed,
        reason: '已完成的任务不能被「取消」翻回 canceled',
      );
      expect(ops.lastHandle!.abortCount, 0);
    });

    test('句柄中止后正常完成 done 也不能被当成成功', () async {
      // dartssh2 的 SftpFileWriter.abort() 会让 done 正常完成。
      // 上层若只看 done 是否抛异常，取消就会被记成 completed。
      final (container, notifier, ops) = await busyContainer();
      addTearDown(container.dispose);
      final id = container.read(sftpProvider).transfers.single.id;

      ops.lastHandle!.abortCompletesNormally = true;
      await notifier.cancelTransfer(id);
      await _awaitStatus(container, id, SftpTransferStatus.canceled);

      expect(
        container.read(sftpProvider).transferById(id)!.status,
        SftpTransferStatus.canceled,
        reason: '中止标志必须由上层自己记，不能依赖 done 抛异常',
      );
    });

    test('删除未完成的任务会先中止它，再移除记录', () async {
      final (container, notifier, ops) = await busyContainer();
      addTearDown(container.dispose);
      final id = container.read(sftpProvider).transfers.single.id;

      await notifier.removeTransfer(id);
      await pumpEventQueue();

      expect(ops.lastHandle!.abortCount, 1, reason: '删掉一个还在跑的任务必须先中止它');
      final state = container.read(sftpProvider);
      expect(state.transfers, isEmpty, reason: '删除要把记录一并去掉');
      expect(state.activeTransfer, isNull);
    });

    test('删除已结束的任务不碰句柄', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      await notifier.removeTransfer(id);

      expect(container.read(sftpProvider).transfers, isEmpty);
      expect(ops.lastHandle!.abortCount, 0, reason: '已结束的任务没有可中止的传输');
    });

    test('clearFinishedTransfers 只清掉已结束的', () async {
      final ops = _FakeOps()..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');
      await notifier.uploadFrom('/local/b.txt');
      await pumpEventQueue();

      var state = container.read(sftpProvider);
      expect(state.hasFinishedTransfers, isFalse, reason: '两个任务都还没结束');
      expect(state.pendingTransferCount, 2);

      ops.uploadGate!.complete();
      final secondId = state.transfers[1].id;
      await _awaitStatus(container, secondId, SftpTransferStatus.completed);
      state = container.read(sftpProvider);
      expect(state.hasFinishedTransfers, isTrue);

      notifier.clearFinishedTransfers();

      final cleared = container.read(sftpProvider);
      expect(cleared.transfers, isEmpty);
      expect(cleared.pendingTransferCount, 0);
    });

    test('暂停一个还没轮到的任务，它不会被执行', () async {
      final ops = _FakeOps()..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();
      await notifier.uploadFrom('/local/a.txt');
      await notifier.uploadFrom('/local/b.txt');
      await pumpEventQueue();

      final secondId = container.read(sftpProvider).transfers[1].id;
      await notifier.pauseTransfer(secondId);
      expect(
        container.read(sftpProvider).transferById(secondId)!.status,
        SftpTransferStatus.paused,
      );

      ops.uploadGate!.complete();
      await _awaitStatus(
        container,
        container.read(sftpProvider).transfers[0].id,
        SftpTransferStatus.completed,
      );
      await pumpEventQueue();

      expect(ops.uploads.map((u) => u.$1), [
        '/local/a.txt',
      ], reason: '排队时就暂停的任务不该被调度起来');
      expect(
        container.read(sftpProvider).transferById(secondId)!.status,
        SftpTransferStatus.paused,
      );

      // 继续后它应该回到队列并被调度。
      await notifier.resumeTransfer(secondId);
      await _awaitStatus(container, secondId, SftpTransferStatus.completed);

      expect(ops.uploads.map((u) => u.$1), ['/local/a.txt', '/local/b.txt']);
    });

    test('一次只跑一个：三个任务按顺序串行完成', () async {
      final ops = _FakeOps()..uploadGate = Completer<void>();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/a.txt');
      await notifier.uploadFrom('/local/b.txt');
      await notifier.uploadFrom('/local/c.txt');
      await pumpEventQueue();

      // 任何时刻最多只有一个 running。
      expect(
        container
            .read(sftpProvider)
            .transfers
            .where((t) => t.status == SftpTransferStatus.running)
            .length,
        1,
      );
      expect(container.read(sftpProvider).transfers.map((t) => t.status), [
        SftpTransferStatus.running,
        SftpTransferStatus.queued,
        SftpTransferStatus.queued,
      ]);

      ops.uploadGate!.complete();
      final lastId = container.read(sftpProvider).transfers[2].id;
      await _awaitStatus(container, lastId, SftpTransferStatus.completed);

      expect(ops.uploads.map((u) => u.$1), [
        '/local/a.txt',
        '/local/b.txt',
        '/local/c.txt',
      ]);
      expect(
        container
            .read(sftpProvider)
            .transfers
            .every((t) => t.status == SftpTransferStatus.completed),
        isTrue,
      );
    });

    test('任务几乎立刻结束时，紧接着的暂停请求不会把它卡住', () async {
      // 0 字节/极小文件在真实环境里就是「句柄刚返回就完成」，
      // 用户此时点暂停，请求落在任务已经结束之后。
      // 这时任务必须已经被调度走了，不能被留在 running 上永远转圈。
      final ops = _FakeOps(); // 无闸门 → 下一个 microtask 就完成
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/a.txt');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.running);
      // 此刻句柄已经拿到手，但下一次 microtask 就会完成。
      await notifier.pauseTransfer(id);

      final task = await _awaitStatus(
        container,
        id,
        SftpTransferStatus.completed,
      );
      expect(task.status, SftpTransferStatus.completed);
    });
  });

  group('SftpNotifier 传输完成回调', () {
    test('上传完成后回调一次，且只在完成时回调', () async {
      final seen = <SftpTransfer>[];
      final ops = _FakeOps();
      final container = await _containerWithNotify(ops, seen.add);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/local/a.txt');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.completed);

      expect(seen.length, 1);
      expect(seen.single.kind, SftpTransferKind.upload);
      expect(seen.single.fileName, 'a.txt');
      expect(seen.single.status, SftpTransferStatus.completed);
      expect(
        container.read(sftpProvider).transferById(id)!.status,
        SftpTransferStatus.completed,
      );
    });

    test('失败与取消都不回调', () async {
      final seen = <SftpTransfer>[];
      final ops = _FakeOps();
      final container = await _containerWithNotify(ops, seen.add);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      // 第一个：句柄拿到手之后传输失败。
      ops.handleFailure = const SFTPException('boom');
      await notifier.uploadFrom('/local/a.txt');
      final failedId = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, failedId, SftpTransferStatus.failed);

      ops.handleFailure = null;
      // 第二个：跑起来之后取消。
      ops.uploadGate = Completer<void>();
      await notifier.uploadFrom('/local/b.txt');
      final canceledId = container.read(sftpProvider).transfers[1].id;
      await _awaitStatus(container, canceledId, SftpTransferStatus.running);
      await notifier.cancelTransfer(canceledId);
      await _awaitStatus(container, canceledId, SftpTransferStatus.canceled);
      ops.uploadGate!.complete();
      await pumpEventQueue();

      expect(seen, isEmpty, reason: '失败/取消不该发「传输完成」通知');
    });

    test('默认回调为 null，测试环境不该碰通知通道', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(transferNotificationCallbackProvider), isNull);
    });
  });

  group('SftpNotifier.clearError', () {
    test('drops the error but keeps unrelated fields', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(_item('main.py'));
      ops.handleFailure = const SFTPException('boom');
      await notifier.uploadFrom('/local/x');
      final id = container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(container, id, SftpTransferStatus.failed);

      expect(container.read(sftpProvider).errorMessage, isNotNull);
      notifier.clearError();

      final state = container.read(sftpProvider);
      expect(state.errorMessage, isNull);
      // 正在编辑的文件不能被顺手清掉。
      expect(state.editingFilePath, '/root/main.py');
      // 传输记录同理：清错误提示不该把用户的队列一起清空。
      expect(state.transfers.single.status, SftpTransferStatus.failed);
    });
  });
}
