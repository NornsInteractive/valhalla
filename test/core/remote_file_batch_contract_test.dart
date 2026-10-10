import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
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
import 'package:valhalla/infrastructure/sftp/remote_file_actions.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_transfer_handle.dart';

SftpFileItem _item(
  String name, {
  bool isDirectory = false,
  bool isSymbolicLink = false,
  int size = 12,
  String? path,
}) => SftpFileItem(
  name: name,
  path: path ?? '/var/www/my-project/$name',
  isDirectory: isDirectory,
  isSymbolicLink: isSymbolicLink,
  sizeBytes: size,
  formattedSize: '$size B',
  permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
  modified: '2026-10-09',
);

class _FakeOps implements SftpOperations {
  List<SftpFileItem> files = const [];
  final listedPaths = <String>[];
  final deletedFiles = <String>[];
  final deletedDirs = <String>[];
  final startedDownloads = <String>[];

  /// 删除被卡住的闸门；用于稳定复现「批次执行中」的时间窗。
  Completer<void>? deleteGate;

  /// 这些路径删除时抛错，用来制造批内单项失败。
  final deleteFailingPaths = <String>{};

  /// 下载时先推进的字节序列。
  List<int> downloadProgress = const [];

  /// 下载句柄要抛出的错误；null 表示传输挂起不结束。
  Object? downloadFailure;

  /// 每条错误路径共用同一个错误对象。
  Object deleteFailure = StateError('permission denied');

  @override
  Future<List<SftpFileItem>> listFiles(String path) async {
    listedPaths.add(path);
    return files;
  }

  @override
  Future<void> deleteFile(String path) async {
    await _delete(path);
    deletedFiles.add(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    await _delete(path);
    deletedDirs.add(path);
  }

  Future<void> _delete(String path) async {
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (deleteFailingPaths.contains(path)) throw deleteFailure;
  }

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    startedDownloads.add(remotePath);
    final handle = FakeTransferHandle(onProgress: onProgress);
    for (final bytes in downloadProgress) {
      handle.emitProgress(bytes);
    }
    final failure = downloadFailure;
    if (failure != null) {
      unawaited(Future<void>.microtask(() => handle.fail(failure)));
    }
    return handle;
  }

  @override
  Future<String> readFileContent(String path) async =>
      throw UnimplementedError();

  @override
  Future<void> writeFileContent(String path, String content) async =>
      throw UnimplementedError();

  @override
  Future<void> createDirectory(String path) async => throw UnimplementedError();

  @override
  Future<void> rename(String oldPath, String newPath) async =>
      throw UnimplementedError();

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverExecutor implements SshCommandExecutor {
  const _NeverExecutor();

  @override
  bool isConnected(String serverId) => true;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => throw UnimplementedError();

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream<SSHExecutionChunk>.empty();
}

/// 记录批次交给远端动作层的参数，不执行任何真实命令。
class _RecordingRemoteActions extends RemoteFileActions {
  _RecordingRemoteActions([super.executor = const _NeverExecutor()]);

  final calls =
      <
        ({
          String serverId,
          RemoteFileAction action,
          String source,
          String directory,
        })
      >[];
  RemoteFileOutcome outcome = RemoteFileOutcome.completed;
  String? error;
  Object? throwing;

  @override
  Future<RemoteFileResult> execute(
    String serverId,
    RemoteFileAction action,
    String source,
    String directory,
  ) async {
    calls.add((
      serverId: serverId,
      action: action,
      source: source,
      directory: directory,
    ));
    final failure = throwing;
    if (failure != null) throw failure;
    return RemoteFileResult(source, outcome, error);
  }
}

class _FakeSshClient implements SSHClient {
  @override
  bool get isClosed => false;

  @override
  Future<SftpClient> sftp() => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

/// 可在测试中途切断连接的替身，用来覆盖「批次/重试期间的断线」。
class _SwitchableConnectionNotifier extends ServerConnectionNotifier {
  ServerConnectionState _current = const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );

  @override
  ServerConnectionState build() => _current;

  /// 只改初始值；必须在 notifier 挂到容器之前调用。
  void presetDisconnected() {
    _current = const ServerConnectionState(
      status: ConnectionStateEnum.disconnected,
    );
  }

  @override
  void disconnect() {
    presetDisconnected();
    state = _current;
  }
}

class _SwitchableActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'first server',
    host: 'a.example.test',
    username: 'root',
  );

  void switchServer() => state = const ServerProfile(
    id: 'srv-2',
    name: 'second server',
    host: 'b.example.test',
    username: 'root',
  );

  void clearServer() => state = null;
}

class _TempDownloads extends DownloadPlatformService {
  _TempDownloads(Directory directory)
    : super(directoryProvider: () async => directory);
}

class _BrokenDownloads extends DownloadPlatformService {
  @override
  Future<String> reservePath(String filename) async =>
      throw StateError('download directory unavailable');
}

class _BatchEnv {
  _BatchEnv({
    required this.container,
    required this.ops,
    required this.downloads,
    required this.actions,
    required this.storage,
    required this.connection,
  });

  final ProviderContainer container;
  final _FakeOps ops;
  final Directory downloads;
  final _RecordingRemoteActions actions;
  final LocalStorageService storage;
  final _SwitchableConnectionNotifier connection;

  _SwitchableActiveServer get server =>
      container.read(activeServerProvider.notifier) as _SwitchableActiveServer;

  SftpNotifier get notifier => container.read(sftpProvider.notifier);
}

Future<_BatchEnv> _env({
  bool connected = true,
  bool brokenDownloads = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final ops = _FakeOps();
  final downloads = Directory.systemTemp.createTempSync(
    'valhalla_batch_downloads_',
  );
  final actions = _RecordingRemoteActions();
  final connection = _SwitchableConnectionNotifier();
  if (!connected) connection.presetDisconnected();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_SwitchableActiveServer.new),
      serverConnectionProvider.overrideWith(() => connection),
      sftpOperationsProvider.overrideWithValue(ops),
      downloadPlatformServiceProvider.overrideWithValue(
        brokenDownloads ? _BrokenDownloads() : _TempDownloads(downloads),
      ),
      remoteFileActionsProvider.overrideWithValue(actions),
    ],
  );
  addTearDown(() {
    container.dispose();
    if (downloads.existsSync()) downloads.deleteSync(recursive: true);
  });
  return _BatchEnv(
    container: container,
    ops: ops,
    downloads: downloads,
    actions: actions,
    storage: storage,
    connection: connection,
  );
}

/// 轮询等待某个传输任务进入期望状态。
Future<SftpTransfer> _awaitStatus(
  ProviderContainer container,
  String id,
  SftpTransferStatus status,
) async {
  for (var i = 0; i < 100; i++) {
    final task = container.read(sftpProvider).transferById(id);
    if (task != null && task.status == status) return task;
    if (i > 0) await pumpEventQueue();
  }
  fail('任务 $id 未在预期内变为 $status');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('runBatch 删除批次', () {
    test('文件、目录、指向目录的符号链接各走对应删除并逐项上报进度', () async {
      final env = await _env();
      await env.notifier.loadDirectory('/var/www/my-project');
      final progress = <(int, int)>[];

      final results = await env.notifier.runBatch(
        RemoteFileAction.delete,
        [
          _item('app.log'),
          _item('build', isDirectory: true),
          _item('linkdir', isDirectory: true, isSymbolicLink: true),
        ],
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(
        results.map((r) => r.outcome),
        everyElement(RemoteFileOutcome.completed),
      );
      expect(env.ops.deletedFiles, [
        '/var/www/my-project/app.log',
        '/var/www/my-project/linkdir',
      ]);
      expect(env.ops.deletedDirs, ['/var/www/my-project/build']);
      expect(progress, [(1, 3), (2, 3), (3, 3)]);
      expect(
        env.ops.listedPaths,
        contains('/var/www/my-project'),
        reason: '非下载批次结束后应刷新当前目录',
      );
    });

    test('单项失败不影响其余项，批次整体不抛异常', () async {
      final env = await _env();
      env.ops.deleteFailingPaths.add('/var/www/my-project/denied.log');

      final results = await env.notifier.runBatch(RemoteFileAction.delete, [
        _item('first.log'),
        _item('denied.log'),
        _item('last.log'),
      ]);

      expect(results.map((r) => r.outcome), [
        RemoteFileOutcome.completed,
        RemoteFileOutcome.failed,
        RemoteFileOutcome.completed,
      ]);
      expect(results[1].error, contains('permission denied'));
      expect(env.ops.deletedFiles, [
        '/var/www/my-project/first.log',
        '/var/www/my-project/last.log',
      ]);
    });

    test('非法路径条目记为失败而不是终止批次', () async {
      final env = await _env();

      final results = await env.notifier.runBatch(RemoteFileAction.delete, [
        _item('good.log'),
        _item('..', isDirectory: true),
        _item('.', isDirectory: true),
        _item('relative.log', path: 'relative.log'),
        _item('root.log', path: '/'),
      ]);

      expect(results.first.outcome, RemoteFileOutcome.completed);
      expect(
        results.skip(1).map((r) => r.outcome),
        everyElement(RemoteFileOutcome.failed),
      );
      expect(
        results.skip(1).map((r) => r.error),
        everyElement(contains('FILE_PATH_INVALID')),
      );
      expect(env.ops.deletedFiles, ['/var/www/my-project/good.log']);
      expect(env.ops.deletedDirs, isEmpty);
    });

    test('重复路径只执行一次', () async {
      final env = await _env();

      final results = await env.notifier.runBatch(RemoteFileAction.delete, [
        _item('dup.log'),
        _item('dup.log'),
      ]);
      expect(results, hasLength(1));
      expect(env.ops.deletedFiles, ['/var/www/my-project/dup.log']);
    });
  });

  group('runBatch 下载批次', () {
    test('目录与符号链接跳过，普通文件记为 queued 而非 completed', () async {
      final env = await _env();

      final results = await env.notifier.runBatch(RemoteFileAction.download, [
        _item('folder', isDirectory: true),
        _item('link', isSymbolicLink: true),
        _item('app.log'),
      ]);

      expect(results[0].outcome, RemoteFileOutcome.skipped);
      expect(results[0].error, 'FILE_REGULAR_ONLY');
      expect(results[1].outcome, RemoteFileOutcome.skipped);
      expect(results[1].error, 'FILE_REGULAR_ONLY');
      expect(results[2].outcome, RemoteFileOutcome.queued, reason: '入队不等于下载完成');
      expect(results[2].error, isNull);

      final transfers = env.container.read(sftpProvider).transfers;
      expect(transfers, hasLength(1));
      expect(transfers.single.remotePath, '/var/www/my-project/app.log');
      expect(transfers.single.localPath, contains('app.log'));
      expect(
        env.ops.listedPaths,
        isNot(contains('/var/www/my-project')),
        reason: '下载批次不应刷新远端目录',
      );
    });

    test('入队失败记为 failed 且不产生任务', () async {
      final env = await _env(brokenDownloads: true);

      final results = await env.notifier.runBatch(RemoteFileAction.download, [
        _item('app.log'),
      ]);

      expect(results.single.outcome, RemoteFileOutcome.failed);
      expect(results.single.error, 'FILE_DOWNLOAD_QUEUE_FAILED');
      expect(env.container.read(sftpProvider).transfers, isEmpty);
      expect(env.ops.startedDownloads, isEmpty);
    });
  });

  group('runBatch copy / move', () {
    test('缺少目标目录时每项失败且不触碰远端动作层', () async {
      final env = await _env();

      final results = await env.notifier.runBatch(RemoteFileAction.copy, [
        _item('a.log'),
      ]);

      expect(results.single.outcome, RemoteFileOutcome.failed);
      expect(results.single.error, contains('FILE_TARGET_REQUIRED'));
      expect(env.actions.calls, isEmpty);
    });

    test('把当前服务器 id 与目标目录原样交给远端动作层', () async {
      final env = await _env();

      final results = await env.notifier.runBatch(RemoteFileAction.move, [
        _item('a.log'),
        _item('folder', isDirectory: true),
      ], targetDirectory: '/var/backups');

      expect(
        results.map((r) => r.outcome),
        everyElement(RemoteFileOutcome.completed),
      );
      expect(env.actions.calls, [
        (
          serverId: 'srv-1',
          action: RemoteFileAction.move,
          source: '/var/www/my-project/a.log',
          directory: '/var/backups',
        ),
        (
          serverId: 'srv-1',
          action: RemoteFileAction.move,
          source: '/var/www/my-project/folder',
          directory: '/var/backups',
        ),
      ]);
    });

    test('远端返回 skipped 时逐项保留该结果', () async {
      final env = await _env();
      env.actions.outcome = RemoteFileOutcome.skipped;
      env.actions.error = 'FILE_TARGET_EXISTS';

      final results = await env.notifier.runBatch(RemoteFileAction.copy, [
        _item('a.log'),
      ], targetDirectory: '/var/backups');
      expect(results.single.outcome, RemoteFileOutcome.skipped);
      expect(results.single.error, 'FILE_TARGET_EXISTS');
    });

    test('远端动作抛异常只让该项失败', () async {
      final env = await _env();
      env.actions.throwing = StateError('ssh channel closed');

      final results = await env.notifier.runBatch(RemoteFileAction.copy, [
        _item('a.log'),
        _item('b.log'),
      ], targetDirectory: '/var/backups');
      expect(
        results.map((r) => r.outcome),
        everyElement(RemoteFileOutcome.failed),
      );
      expect(env.actions.calls, hasLength(2));
    });
  });

  group('runBatch 并发与连接前置条件', () {
    test('重叠批次被拒绝，结束后锁释放', () async {
      final env = await _env();
      final gate = Completer<void>();
      env.ops.deleteGate = gate;

      final running = env.notifier.runBatch(RemoteFileAction.delete, [
        _item('a.log'),
      ]);
      await pumpEventQueue();
      expect(env.ops.deletedFiles, isEmpty, reason: '第一批应仍卡在闸门上');

      await expectLater(
        env.notifier.runBatch(RemoteFileAction.delete, [_item('b.log')]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'FILE_OPERATION_PENDING',
          ),
        ),
      );

      gate.complete();
      await running;

      final after = await env.notifier.runBatch(RemoteFileAction.delete, [
        _item('c.log'),
      ]);
      expect(after.single.outcome, RemoteFileOutcome.completed);
    });

    test('未连接时直接拒绝，不执行任何远端动作', () async {
      final env = await _env(connected: false);

      await expectLater(
        env.notifier.runBatch(RemoteFileAction.delete, [_item('a.log')]),
        throwsA(isA<SSHConnectionException>()),
      );
      expect(env.ops.deletedFiles, isEmpty);
      expect(env.actions.calls, isEmpty);
    });
  });

  group('runBatch 目标切换', () {
    test('切换服务器后剩余条目记为 interrupted 且不刷新新目录', () async {
      final env = await _env();
      final gate = Completer<void>();
      env.ops.deleteGate = gate;

      final running = env.notifier.runBatch(RemoteFileAction.delete, [
        _item('a.log'),
        _item('b.log'),
        _item('c.log'),
      ]);
      await pumpEventQueue();
      expect(env.ops.deletedFiles, isEmpty);

      env.server.switchServer();
      env.container.read(sftpProvider);
      await pumpEventQueue();
      final listedAfterSwitch = env.ops.listedPaths.length;

      gate.complete();
      final results = await running;

      expect(results, hasLength(3));
      expect(results[0].outcome, RemoteFileOutcome.completed);
      expect(
        results.skip(1).map((r) => r.outcome),
        everyElement(RemoteFileOutcome.failed),
      );
      expect(
        results.skip(1).map((r) => r.error),
        everyElement('FILE_OPERATION_INTERRUPTED'),
      );
      expect(env.ops.deletedFiles, [
        '/var/www/my-project/a.log',
      ], reason: '切换之后不得再对旧目标执行删除');
      expect(
        env.ops.listedPaths.length,
        listedAfterSwitch,
        reason: '旧批次的收尾刷新必须被丢弃，不能覆盖新目录状态',
      );
      expect(env.container.read(sftpProvider).currentPath, '/');
    });

    test('没有活动服务器时拒绝执行', () async {
      final env = await _env();
      final notifier = env.notifier;
      env.server.clearServer();
      env.container.read(sftpProvider);
      await pumpEventQueue();

      await expectLater(
        notifier.runBatch(RemoteFileAction.delete, [_item('a.log')]),
        throwsA(isA<SSHConnectionException>()),
      );
      expect(env.ops.deletedFiles, isEmpty);
    });

    test('确认后换了服务器，过期快照被整体拒绝执行', () async {
      final env = await _env();
      await env.notifier.loadDirectory('/var/www/my-project');
      await pumpEventQueue();
      // UI 在弹确认框时按下当前服务器状态。
      final snapshot = env.container.read(activeServerProvider);

      env.server.switchServer();
      env.container.read(sftpProvider);
      await pumpEventQueue();

      await expectLater(
        env.notifier.runBatch(RemoteFileAction.delete, [
          _item('a.log'),
          _item('b.log'),
        ], expectedServer: snapshot),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'FILE_TARGET_CHANGED',
          ),
        ),
        reason: '过期确认不得把删除落到另一台服务器上',
      );
      expect(env.ops.deletedFiles, isEmpty);
      expect(env.ops.deletedDirs, isEmpty);
    });

    test('expectedServer 与当前服务器一致时正常执行', () async {
      final env = await _env();
      final snapshot = env.container.read(activeServerProvider);

      final results = await env.notifier.runBatch(RemoteFileAction.delete, [
        _item('a.log'),
      ], expectedServer: snapshot);
      expect(results.single.outcome, RemoteFileOutcome.completed);
      expect(env.ops.deletedFiles, ['/var/www/my-project/a.log']);
    });
  });

  group('retryTransfer', () {
    test('只重试失败任务，并从零偏移重新开始', () async {
      final env = await _env();
      env.ops.downloadProgress = const [640];
      env.ops.downloadFailure = StateError('channel lost');

      await env.notifier.downloadTo(
        _item('app.log'),
        '${env.downloads.path}/app.log',
      );
      await pumpEventQueue();
      final id = env.container.read(sftpProvider).transfers.single.id;
      final failed = await _awaitStatus(
        env.container,
        id,
        SftpTransferStatus.failed,
      );
      expect(failed.transferredBytes, 640);
      expect(failed.errorMessage, isNotNull);

      env.ops.downloadFailure = null;
      env.ops.downloadProgress = const [];
      await env.notifier.retryTransfer(id);

      final retried = env.container.read(sftpProvider).transferById(id)!;
      expect(retried.transferredBytes, 0, reason: '重试必须从头开始，不能沿用失败时的部分偏移量');
      expect(retried.errorMessage, isNull);
      expect(
        retried.status,
        anyOf(SftpTransferStatus.queued, SftpTransferStatus.running),
      );
      expect(env.ops.startedDownloads, hasLength(2));
    });

    test('未知 id 与非失败任务都是空操作', () async {
      final env = await _env();
      await env.notifier.downloadTo(
        _item('app.log'),
        '${env.downloads.path}/app.log',
      );
      await pumpEventQueue();
      final id = env.container.read(sftpProvider).transfers.single.id;
      final startedBefore = env.ops.startedDownloads.length;

      await env.notifier.retryTransfer('does-not-exist');
      await env.notifier.retryTransfer(id);

      expect(env.ops.startedDownloads, hasLength(startedBefore));
      expect(env.container.read(sftpProvider).transferById(id), isNotNull);
    });

    test('未连接时拒绝重试', () async {
      final env = await _env();
      env.ops.downloadFailure = StateError('channel lost');
      await env.notifier.downloadTo(
        _item('app.log'),
        '${env.downloads.path}/app.log',
      );
      await pumpEventQueue();
      final id = env.container.read(sftpProvider).transfers.single.id;
      await _awaitStatus(env.container, id, SftpTransferStatus.failed);

      env.ops.downloadFailure = null;
      env.connection.disconnect();
      env.container.read(sftpProvider);
      await pumpEventQueue();

      await expectLater(
        env.notifier.retryTransfer(id),
        throwsA(isA<SSHConnectionException>()),
      );
      final task = env.container.read(sftpProvider).transferById(id)!;
      expect(
        task.status,
        SftpTransferStatus.failed,
        reason: '拒绝重试时不得把任务悄悄改成已排队',
      );
    });
  });
}
