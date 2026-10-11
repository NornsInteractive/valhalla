import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/fake_transfer_handle.dart';

const _alpha = ServerProfile(
  id: 'alpha',
  name: 'alpha',
  host: '10.0.0.1',
  username: 'root',
);

/// 只改了 host：`connectionKey` 因此不同，草稿与传输记录都必须分开存。
const _beta = ServerProfile(
  id: 'alpha',
  name: 'beta',
  host: '10.0.0.9',
  username: 'root',
);

/// 内存版 [SecureStorageService]：草稿走的是加密 KeyChain，
/// 单测里不碰系统 KeyChain/KeyStore，改成一张普通 Map。
class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage() : super(storage: const FlutterSecureStorage());

  final drafts = <String, Map<String, dynamic>?>{};
  final deleted = <String>[];

  /// 每次成功写入的 key，用来区分「写了一次」和「去抖又写了一次」。
  final saves = <String>[];

  /// 非空时 [saveFileEditorDraft] 先等它：用来造「加密写还没落定」的窗口。
  Completer<void>? draftSaveGate;

  /// 非空时 [saveFileEditorDraft] 抛出它：用来造加密存储写失败。
  Object? draftSaveFailure;

  /// 非空时 [deleteFileEditorDraft] 先等它：用来造「删除还在进行」的窗口。
  Completer<void>? deleteGate;

  /// 进入 [deleteFileEditorDraft] 时完成它：确认「删除已经排到门后」。
  Completer<void>? deleteEntered;

  /// 非空时 [deleteFileEditorDraft] 抛出它：用来造删除失败。
  Object? deleteFailure;

  /// 已成功提交的草稿写/删的有序轨迹，用来断言删除与随后的写之间的先后。
  final events = <String>[];

  @override
  Future<Map<String, dynamic>?> getFileEditorDraft(String key) async =>
      drafts[key];

  @override
  Future<void> saveFileEditorDraft(
    String key,
    Map<String, dynamic> value,
  ) async {
    if (draftSaveGate != null) await draftSaveGate!.future;
    if (draftSaveFailure != null) throw draftSaveFailure!;
    saves.add(key);
    drafts[key] = value;
    events.add('save:${value['content']}');
  }

  @override
  Future<void> deleteFileEditorDraft(String key) async {
    deleteEntered?.complete();
    if (deleteGate != null) await deleteGate!.future;
    if (deleteFailure != null) throw deleteFailure!;
    deleted.add(key);
    drafts.remove(key);
    events.add('delete');
  }
}

/// 能实现 [SftpEditorOperations] / [SftpResumableOperations] 的远端替身。
///
/// 这里刻意**不**碰任何真实通道：所有能力都由字段驱动，测试要哪个分支
/// 就设哪个字段。`SftpOperations` 的其余方法只做记账。
class _FakeService
    implements SftpOperations, SftpEditorOperations, SftpResumableOperations {
  final saves = <(String, String, String)>[];
  final snapshotReads = <String>[];

  /// 非空时 [readTextSnapshot] 抛出它。
  Object? readFailure;

  /// 非空时 [saveTextSnapshot] 抛出它。
  Object? saveFailure;

  /// 快照内容表；缺省时用 path 生成稳定内容。
  final contents = <String, String>{};
  String contentFor(String path) => contents[path] ?? 'body of $path';

  @override
  Future<SftpTextSnapshot> readTextSnapshot(String path) async {
    snapshotReads.add(path);
    if (readFailure != null) throw readFailure!;
    final content = contentFor(path);
    return SftpTextSnapshot(
      path: path,
      targetPath: path,
      content: content,
      digest: sha256.convert(utf8.encode(content)).toString(),
      attributes: SftpFileAttrs(size: 8),
    );
  }

  @override
  Future<void> saveTextSnapshot(
    SftpTextSnapshot original,
    String content,
  ) async {
    if (saveFailure != null) throw saveFailure!;
    saves.add((original.path, original.digest, content));
    contents[original.path] = content;
  }

  // --- 传输记账 ---------------------------------------------------------

  final resumableUploads = <(String, String, String, Map<String, dynamic>?)>[];
  final resumableDownloads = <(String, String, Map<String, dynamic>?)>[];
  final discardedPartials = <(String, String)>[];

  /// 传给 `onSource` 的身份；测试改它就能造出「源变了」。
  Map<String, dynamic> uploadSource = {'size': 8, 'digest': 'd1'};
  Map<String, dynamic> downloadSource = {'target': '/srv/a.bin', 'size': 8};

  /// 非空时 [startResumableUpload] 直接抛出它。
  Object? uploadFailure;

  /// 非空时 [startResumableDownload] 直接抛出它。
  Object? downloadFailure;

  bool uploadAutoFinish = true;
  FakeTransferHandle? lastUploadHandle;
  FakeTransferHandle? lastDownloadHandle;

  /// 非空时 [discardUploadPartial] 抛它，用来造出「清理失败」。
  Object? discardFailure;

  /// 非空时上传句柄是提交阶段的句柄：取消/删除都必须被拒绝。
  bool uploadInCommitStage = false;

  @override
  Future<SftpTransferHandle> startResumableUpload(
    String localPath,
    String remotePath, {
    required String transferId,
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  }) async {
    resumableUploads.add((localPath, remotePath, transferId, expectedSource));
    if (uploadFailure != null) throw uploadFailure!;
    onSource(uploadSource);
    final handle = uploadInCommitStage
        ? _CommittingHandle(totalBytes: 8, onProgress: onProgress)
        : FakeTransferHandle(totalBytes: 8, onProgress: onProgress);
    lastUploadHandle = handle;
    if (uploadAutoFinish && !uploadInCommitStage) {
      unawaited(
        Future<void>.microtask(() {
          if (uploadFailure != null) {
            handle.fail(uploadFailure!);
          } else {
            handle.finish();
          }
        }),
      );
    }
    return handle;
  }

  @override
  Future<SftpTransferHandle> startResumableDownload(
    String remotePath,
    String localPath, {
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  }) async {
    resumableDownloads.add((remotePath, localPath, expectedSource));
    if (downloadFailure != null) throw downloadFailure!;
    onSource(downloadSource);
    final handle = FakeTransferHandle(totalBytes: 8, onProgress: onProgress);
    lastDownloadHandle = handle;
    if (uploadAutoFinish) {
      unawaited(Future<void>.microtask(handle.finish));
    }
    return handle;
  }

  @override
  Future<void> discardUploadPartial(
    String remotePath,
    String transferId,
  ) async {
    if (discardFailure != null) throw discardFailure!;
    discardedPartials.add((remotePath, transferId));
  }

  // --- 目录与其它纯记账方法 ----------------------------------------------

  List<SftpFileItem> files = const [];
  final listedPaths = <String>[];

  @override
  Future<List<SftpFileItem>> listFiles(String path) async {
    listedPaths.add(path);
    return files;
  }

  @override
  Future<String> readFileContent(String path) async => contentFor(path);

  @override
  Future<void> writeFileContent(String path, String content) async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> deleteDirectory(String path) async {}

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) => throw StateError('resumable path must be taken');

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) => throw StateError('resumable path must be taken');

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => 8;

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => 8;
}

/// 受管下载要向系统申请一个落地路径；这里固定发到临时目录，
/// 不碰真实下载目录、不弹任何系统 UI。
class _StubDownloads extends DownloadPlatformService {
  _StubDownloads(this.directory)
    : super(directoryProvider: () async => directory);
  final Directory directory;

  /// 记录真正交给系统的打开/定位动作：完整性校验失败的用例要断言
  /// 这里**一次都没有**被调用。
  final opened = <String>[];
  final revealed = <String>[];

  /// 非空时 [revealFile] 抛出它，用来造原生 reveal 失败。
  Object? revealThrows;

  @override
  Future<String> reservePath(String name) async => '${directory.path}/$name';

  @override
  Future<void> openFile(String path) async => opened.add(path);

  @override
  Future<void> revealFile(String path) async {
    if (revealThrows != null) throw revealThrows!;
    revealed.add(path);
  }

  /// 覆盖掉真实实现：它会打系统通知通道，单测里没有绑定。
  @override
  Future<bool> report(Map<String, Object?> transfer) async => true;
}

/// 提交阶段的上传句柄：发布一旦开始就不能再被取消/删除。
class _CommittingHandle extends FakeTransferHandle
    implements SftpCommittingTransfer {
  _CommittingHandle({super.totalBytes, super.onProgress});

  @override
  bool get isCommitting => true;
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    activeServerId: 'alpha',
  );
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _alpha;
}

Future<(ProviderContainer, LocalStorageService, _MemorySecureStorage)>
_container(
  _FakeService ops, {
  ServerProfile? seededRecordsFor,
  Map<String, List<Map<String, dynamic>>>? records,
  DownloadPlatformService? downloads,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  if (records != null && seededRecordsFor != null) {
    await storage.saveTransferRecords(
      seededRecordsFor,
      records[seededRecordsFor.id]!,
    );
  }
  final secure = _MemorySecureStorage();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(secure),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      sftpOperationsProvider.overrideWithValue(ops),
      if (downloads != null)
        downloadPlatformServiceProvider.overrideWithValue(downloads),
    ],
  );
  return (container, storage, secure);
}

Future<SftpTransfer> _awaitStatus(
  ProviderContainer container,
  String id,
  SftpTransferStatus status,
) async {
  for (var i = 0; i < 100; i++) {
    final task = container.read(sftpProvider).transferById(id);
    if (task != null && task.status == status) return task;
    await pumpEventQueue();
  }
  return container.read(sftpProvider).transferById(id)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('transfer record persistence', () {
    test(
      'records the resumable source identity before the transfer finishes',
      () async {
        final ops = _FakeService();
        ops.uploadAutoFinish = false;
        final (container, storage, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.uploadFrom('/tmp/a.bin');
        final id = container.read(sftpProvider).transfers.single.id;
        await pumpEventQueue();

        // onSource 已经在句柄建好前回调，身份必须落到 state 并持久化。
        expect(
          container.read(sftpProvider).transferById(id)!.sourceIdentity,
          ops.uploadSource,
        );
        await pumpEventQueue();
        final persisted = storage.getTransferRecords(_alpha);
        expect(persisted.single['sourceIdentity'], ops.uploadSource);
        expect(persisted.single['id'], id);
      },
    );

    test('a second transfer does not inherit the first identity', () async {
      final ops = _FakeService();
      final (container, storage, _) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/tmp/a.bin', remoteName: 'a.bin');
      await pumpEventQueue();
      await notifier.uploadFrom('/tmp/b.bin', remoteName: 'b.bin');
      await pumpEventQueue();

      final persisted = storage.getTransferRecords(_alpha);
      expect(persisted.map((r) => r['remotePath']).toList(), [
        '/a.bin',
        '/b.bin',
      ]);
      expect(ops.resumableUploads.map((u) => u.$2), ['/a.bin', '/b.bin']);
    });
  });

  group('restoring records', () {
    test(
      'restored running and queued records come back paused, never running',
      () async {
        final ops = _FakeService();
        final (container, _, _) = await _container(
          ops,
          seededRecordsFor: _alpha,
          records: {
            'alpha': [
              SftpTransfer(
                id: 'was-running',
                kind: SftpTransferKind.upload,
                remotePath: '/a.bin',
                localPath: '/tmp/a.bin',
                status: SftpTransferStatus.running,
                sourceIdentity: const {'size': 8, 'digest': 'd1'},
              ).toJson(),
              SftpTransfer(
                id: 'was-queued',
                kind: SftpTransferKind.download,
                remotePath: '/b.bin',
                localPath: '/tmp/b.bin',
                status: SftpTransferStatus.queued,
              ).toJson(),
              SftpTransfer(
                id: 'was-failed',
                kind: SftpTransferKind.upload,
                remotePath: '/c.bin',
                localPath: '/tmp/c.bin',
                status: SftpTransferStatus.failed,
                errorMessage: 'SFTP_UPLOAD_FAILED',
              ).toJson(),
            ],
          },
        );
        addTearDown(container.dispose);

        final restored = container.read(sftpProvider).transfers;
        // 连接是「已连上」的状态，所以 build 走的是恢复分支：running/queued
        // 已经被 fromJson 降级成 paused，重连时不得被自动重新排队。
        expect(restored.map((t) => t.id), [
          'was-running',
          'was-queued',
          'was-failed',
        ]);
        expect(restored[0].status, SftpTransferStatus.paused);
        expect(restored[1].status, SftpTransferStatus.paused);
        expect(
          restored[2].status,
          SftpTransferStatus.failed,
          reason: '一个终态失败不能被恢复成待办',
        );
        expect(restored[2].errorMessage, 'SFTP_UPLOAD_FAILED');
        expect(restored[0].sourceIdentity, {'size': 8, 'digest': 'd1'});
        await pumpEventQueue();
        expect(ops.resumableUploads, isEmpty);
        expect(ops.resumableDownloads, isEmpty);
      },
    );

    test('restored records stay on their own server target', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      await storage.saveTransferRecords(_alpha, [
        SftpTransfer(
          id: 'alpha-task',
          kind: SftpTransferKind.upload,
          remotePath: '/a.bin',
          localPath: '/tmp/a.bin',
          sourceIdentity: const {'size': 8, 'digest': 'alpha'},
        ).toJson(),
      ]);
      await storage.saveTransferRecords(_beta, [
        SftpTransfer(
          id: 'beta-task',
          kind: SftpTransferKind.upload,
          remotePath: '/b.bin',
          localPath: '/tmp/b.bin',
          sourceIdentity: const {'size': 8, 'digest': 'beta'},
        ).toJson(),
      ]);

      // 同 id 不同 host：两个目标必须各自读回自己那一份，不能串。
      expect(storage.getTransferRecords(_alpha).single['id'], 'alpha-task');
      expect(storage.getTransferRecords(_beta).single['id'], 'beta-task');

      final ops = _FakeService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(sftpProvider);
      expect(state.transfers.single.id, 'alpha-task');
      expect(state.transfers.single.sourceIdentity, {
        'size': 8,
        'digest': 'alpha',
      });
    });

    test(
      'resume is explicit: a restored paused record waits for the caller',
      () async {
        final ops = _FakeService();
        final (container, _, _) = await _container(
          ops,
          seededRecordsFor: _alpha,
          records: {
            'alpha': [
              SftpTransfer(
                id: 'paused-upload',
                kind: SftpTransferKind.upload,
                remotePath: '/a.bin',
                localPath: '/tmp/a.bin',
                status: SftpTransferStatus.paused,
                sourceIdentity: const {'size': 8, 'digest': 'd1'},
              ).toJson(),
            ],
          },
        );
        addTearDown(container.dispose);
        await pumpEventQueue();

        // 只是恢复出来，不会自己跑起来。
        expect(ops.resumableUploads, isEmpty);

        await container
            .read(sftpProvider.notifier)
            .resumeTransfer('paused-upload');
        final task = await _awaitStatus(
          container,
          'paused-upload',
          SftpTransferStatus.completed,
        );

        expect(ops.resumableUploads.single.$2, '/a.bin');
        expect(task.sourceIdentity, ops.uploadSource);
      },
    );

    test(
      'a resumed record carries its persisted identity into expectedSource',
      () async {
        final ops = _FakeService();
        ops.uploadAutoFinish = false;
        const persistedIdentity = {'size': 8, 'digest': 'd1'};
        final (container, _, _) = await _container(
          ops,
          seededRecordsFor: _alpha,
          records: {
            'alpha': [
              SftpTransfer(
                id: 'paused-upload',
                kind: SftpTransferKind.upload,
                remotePath: '/a.bin',
                localPath: '/tmp/a.bin',
                status: SftpTransferStatus.paused,
                sourceIdentity: persistedIdentity,
              ).toJson(),
            ],
          },
        );
        addTearDown(container.dispose);
        await pumpEventQueue();

        await container
            .read(sftpProvider.notifier)
            .resumeTransfer('paused-upload');
        await pumpEventQueue();

        expect(
          ops.resumableUploads.single.$4,
          persistedIdentity,
          reason: '续传必须带上前一次记下的身份，服务端据此判源是否变了',
        );
      },
    );

    test(
      'a source that changed since the record fails the resumed upload',
      () async {
        final ops = _FakeService();
        ops.uploadFailure = const SFTPException('SFTP_TRANSFER_SOURCE_CHANGED');
        final (container, _, _) = await _container(
          ops,
          seededRecordsFor: _alpha,
          records: {
            'alpha': [
              SftpTransfer(
                id: 'paused-upload',
                kind: SftpTransferKind.upload,
                remotePath: '/a.bin',
                localPath: '/tmp/a.bin',
                status: SftpTransferStatus.paused,
                sourceIdentity: const {'size': 8, 'digest': 'old'},
              ).toJson(),
            ],
          },
        );
        addTearDown(container.dispose);
        await pumpEventQueue();

        await container
            .read(sftpProvider.notifier)
            .resumeTransfer('paused-upload');
        final task = await _awaitStatus(
          container,
          'paused-upload',
          SftpTransferStatus.failed,
        );

        // 「源变了」是一个具体原因，不是笼统的失败：UI 要区分
        // 「重新选文件」和「网络断了重试」，因此必须落到细分码。
        expect(task.errorMessage, 'SFTP_TRANSFER_SOURCE_CHANGED');
        expect(
          container.read(sftpProvider).errorMessage,
          'SFTP_TRANSFER_SOURCE_CHANGED',
        );
      },
    );
  });

  group('partial cleanup', () {
    test(
      'cancelling an upload discards its remote partial under its task id',
      () async {
        final ops = _FakeService();
        ops.uploadAutoFinish = false;
        final (container, _, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.uploadFrom('/tmp/a.bin');
        final id = container.read(sftpProvider).transfers.single.id;
        await pumpEventQueue();
        await notifier.cancelTransfer(id);
        await pumpEventQueue();

        expect(ops.discardedPartials.single, ('/a.bin', id));
        expect(
          container.read(sftpProvider).transferById(id)!.status,
          SftpTransferStatus.canceled,
        );
      },
    );

    test('cancelling a managed download removes its local part file', () async {
      // 受管下载（downloadFile / downloadAndOpen）先写 `${localPath}.part`，
      // 成功后才改名。取消必须把这个 part 删掉，且**不能**去动远端。
      final dir = await Directory.systemTemp.createTemp('sftp-records-test');
      addTearDown(() => dir.delete(recursive: true));
      final ops = _FakeService()..uploadAutoFinish = false;
      final (container, _, _) = await _container(
        ops,
        downloads: _StubDownloads(dir),
      );
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final part = File('${dir.path}/payload.bin.part');
      await part.writeAsBytes([1, 2, 3]);

      final item = SftpFileItem(
        name: 'payload.bin',
        path: '/srv/payload.bin',
        isDirectory: false,
        sizeBytes: 3,
        formattedSize: '3 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      final id = await notifier.downloadFile(item);
      expect(id, isNotNull);
      await pumpEventQueue();
      expect(
        ops.resumableDownloads.single.$2,
        '${dir.path}/payload.bin.part',
        reason: '受管下载必须落到 .part 上，成功前不能污染真实路径',
      );
      // 取消前必须是仍在跑的任务：句柄没结束、也没被中止过。
      expect(
        container.read(sftpProvider).transferById(id!)!.status,
        SftpTransferStatus.running,
        reason: '取消必须发生在一个还在进行的下载上，否则这条用例没有意义',
      );
      expect(ops.lastDownloadHandle, isNotNull);
      expect(ops.lastDownloadHandle!.isAborted, isFalse);
      expect(ops.lastDownloadHandle!.abortCount, 0);

      await notifier.cancelTransfer(id);
      await pumpEventQueue();

      expect(
        ops.discardedPartials,
        isEmpty,
        reason: '下载不占远端 partial，清单不能凭空多出一次上传清理',
      );
      expect(
        container.read(sftpProvider).transferById(id)!.status,
        SftpTransferStatus.canceled,
      );
      expect(ops.lastDownloadHandle!.abortCount, 1);
      expect(part.existsSync(), isFalse);
    });
  });

  group('commit stage is not cancellable', () {
    test(
      'cancelling a committing upload keeps it running and refuses',
      () async {
        final ops = _FakeService()
          ..uploadAutoFinish = false
          ..uploadInCommitStage = true;
        final (container, _, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.uploadFrom('/tmp/a.bin');
        final id = container.read(sftpProvider).transfers.single.id;
        await pumpEventQueue();

        await notifier.cancelTransfer(id);
        await pumpEventQueue();

        final task = container.read(sftpProvider).transferById(id)!;
        expect(
          task.status,
          SftpTransferStatus.running,
          reason: '提交阶段的远端发布无法回滚，谎报 canceled 就是说假话',
        );
        expect(
          container.read(sftpProvider).errorMessage,
          'SFTP_TRANSFER_COMMITTING',
        );
        expect(
          ops.discardedPartials,
          isEmpty,
          reason: '清理远端 partial 会把正在提交的文件删掉',
        );
      },
    );

    test('removing a committing upload keeps the record', () async {
      final ops = _FakeService()
        ..uploadAutoFinish = false
        ..uploadInCommitStage = true;
      final (container, _, _) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.uploadFrom('/tmp/a.bin');
      final id = container.read(sftpProvider).transfers.single.id;
      await pumpEventQueue();

      await notifier.removeTransfer(id);
      await pumpEventQueue();

      expect(
        container.read(sftpProvider).transferById(id),
        isNotNull,
        reason: '删除会中止传输，提交阶段必须拒绝而不是假装删掉了',
      );
      expect(
        container.read(sftpProvider).errorMessage,
        'SFTP_TRANSFER_COMMITTING',
      );
    });
  });

  group('failed partial cleanup', () {
    test(
      'a failed cleanup keeps the record flagged, and clearing hides it',
      () async {
        final ops = _FakeService()
          ..uploadAutoFinish = false
          ..discardFailure = StateError('remote partial is busy');
        final (container, storage, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.uploadFrom('/tmp/a.bin');
        final id = container.read(sftpProvider).transfers.single.id;
        await pumpEventQueue();

        await notifier.cancelTransfer(id);
        await pumpEventQueue();

        final task = container.read(sftpProvider).transferById(id)!;
        expect(task.status, SftpTransferStatus.canceled);
        expect(task.errorMessage, 'SFTP_TRANSFER_CLEANUP_FAILED');
        // 清理失败 ≠ 干净：记录必须留着，用户才能看见远端还留着半个文件。
        notifier.clearFinishedTransfers();
        expect(
          container.read(sftpProvider).transferById(id),
          isNotNull,
          reason: '清理失败的任务是终态，但 clearFinished 不能把它抹掉',
        );
        expect(
          storage.getTransferRecords(_alpha).single['errorMessage'],
          'SFTP_TRANSFER_CLEANUP_FAILED',
        );
      },
    );

    test(
      'removing a transfer whose cleanup fails does not drop the record',
      () async {
        final ops = _FakeService()
          ..uploadAutoFinish = false
          ..discardFailure = StateError('remote partial is busy');
        final (container, _, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.uploadFrom('/tmp/a.bin');
        final id = container.read(sftpProvider).transfers.single.id;
        await pumpEventQueue();

        await notifier.removeTransfer(id);
        await pumpEventQueue();

        expect(
          container.read(sftpProvider).transferById(id)!.errorMessage,
          'SFTP_TRANSFER_CLEANUP_FAILED',
        );
      },
    );
  });

  group('completed download integrity', () {
    /// 造一条已完成下载记录：真实的临时文件 + 真实的 sha256。
    Future<(List<Map<String, dynamic>>, String, _StubDownloads)> seed(
      List<int> bytes, {
      int? sizeOverride,
    }) async {
      final dir = await Directory.systemTemp.createTemp('sftp-integrity');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/payload.bin');
      await file.writeAsBytes(bytes);
      final downloads = _StubDownloads(dir);
      final records = [
        SftpTransfer(
          id: 'done',
          kind: SftpTransferKind.download,
          remotePath: '/srv/payload.bin',
          localPath: file.path,
          status: SftpTransferStatus.completed,
          transferredBytes: sizeOverride ?? bytes.length,
          localSha256: sha256.convert(bytes).toString(),
        ).toJson(),
      ];
      return (records, file.path, downloads);
    }

    test('a completed download with a matching size and hash opens', () async {
      final (records, path, downloads) = await seed([1, 2, 3, 4]);
      final (container, _, _) = await _container(
        _FakeService(),
        seededRecordsFor: _alpha,
        records: {'alpha': records},
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(sftpProvider.notifier).openCompletedTransfer('done');

      expect(downloads.opened, [path]);
      expect(container.read(sftpProvider).errorMessage, isNull);
    });

    test('a tampered size refuses to open', () async {
      // 文件被换成更长的一份，但记录里的字节数没变。
      final (records, _, downloads) = await seed([
        1,
        2,
        3,
        4,
        5,
      ], sizeOverride: 4);
      final (container, _, _) = await _container(
        _FakeService(),
        seededRecordsFor: _alpha,
        records: {'alpha': records},
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(sftpProvider.notifier).openCompletedTransfer('done');

      expect(downloads.opened, isEmpty, reason: '长度对不上就不能打开：这不是我们下载完的那份文件');
      expect(container.read(sftpProvider).errorMessage, 'DOWNLOAD_OPEN_FAILED');
    });

    test('a tampered hash of the same length refuses to open', () async {
      final (records, path, downloads) = await seed([1, 2, 3, 4]);
      await File(path).writeAsBytes([9, 9, 9, 9]);
      final (container, _, _) = await _container(
        _FakeService(),
        seededRecordsFor: _alpha,
        records: {'alpha': records},
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container
          .read(sftpProvider.notifier)
          .revealCompletedTransfer('done');

      expect(downloads.revealed, isEmpty);
      expect(
        container.read(sftpProvider).errorMessage,
        'DOWNLOAD_OPEN_FAILED',
        reason: '校验失败必须如实报出，不能静默吞掉',
      );
    });

    test('a native reveal failure refuses to open', () async {
      final (records, _, downloads) = await seed([1, 2, 3, 4]);
      downloads.revealThrows = StateError('native reveal failed');
      final (container, _, _) = await _container(
        _FakeService(),
        seededRecordsFor: _alpha,
        records: {'alpha': records},
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container
          .read(sftpProvider.notifier)
          .revealCompletedTransfer('done');

      expect(downloads.revealed, isEmpty);
      expect(
        container.read(sftpProvider).errorMessage,
        'DOWNLOAD_OPEN_FAILED',
        reason: '原生 reveal 失败也不能让错误逃出去',
      );
    });

    test('a legacy record without a hash refuses to open', () async {
      // 升级前写下的记录没有 localSha256：无法证明文件没被换过，
      // 必须拒绝打开而不是猜。
      final (_, path, downloads) = await seed([1, 2, 3, 4]);
      final legacy = [
        SftpTransfer(
          id: 'done',
          kind: SftpTransferKind.download,
          remotePath: '/srv/payload.bin',
          localPath: path,
          status: SftpTransferStatus.completed,
          transferredBytes: 4,
        ).toJson(),
      ];
      final (container, _, _) = await _container(
        _FakeService(),
        seededRecordsFor: _alpha,
        records: {'alpha': legacy},
        downloads: downloads,
      );
      addTearDown(container.dispose);
      await pumpEventQueue();

      await container.read(sftpProvider.notifier).openCompletedTransfer('done');

      expect(downloads.opened, isEmpty);
      expect(container.read(sftpProvider).errorMessage, 'DOWNLOAD_OPEN_FAILED');
    });

    test('a completed download persists its hash at completion', () async {
      // 完成时把 localSha256 落到记录上，是「以后能打开」的前提。
      final dir = await Directory.systemTemp.createTemp('sftp-complete');
      addTearDown(() => dir.delete(recursive: true));
      final payload = File('${dir.path}/payload.bin');
      final ops = _FakeService()..uploadAutoFinish = false;
      final (container, storage, _) = await _container(
        ops,
        downloads: _StubDownloads(dir),
      );
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'payload.bin',
        path: '/srv/payload.bin',
        isDirectory: false,
        sizeBytes: 3,
        formattedSize: '3 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      final id = await notifier.downloadFile(item);
      await pumpEventQueue();
      // 受管下载先写 .part：替身不写真实文件，手动补上。
      await File('${dir.path}/payload.bin.part').writeAsBytes([7, 7, 7]);
      expect(payload.existsSync(), isFalse, reason: '完成前 .part 不能改名成本体');
      ops.lastDownloadHandle?.finish();
      final task = await _awaitStatus(
        container,
        id!,
        SftpTransferStatus.completed,
      );

      expect(payload.existsSync(), isTrue, reason: '完成后 .part 必须改名成本体');
      expect(await payload.readAsBytes(), [7, 7, 7]);
      expect(task.localSha256, sha256.convert([7, 7, 7]).toString());
      expect(task.transferredBytes, 3);
      expect(
        storage.getTransferRecords(_alpha).single['localSha256'],
        sha256.convert([7, 7, 7]).toString(),
      );
    });
  });

  group('safe editor lifecycle', () {
    test('a save goes through the revision-checked snapshot path', () async {
      final ops = _FakeService();
      final (container, _, _) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'a.txt',
        path: '/root/a.txt',
        isDirectory: false,
        sizeBytes: 16,
        formattedSize: '16 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      await notifier.openFileForEditing(item);
      expect(ops.snapshotReads, ['/root/a.txt']);
      expect(
        container.read(sftpProvider).editingFileContent,
        'body of /root/a.txt',
      );

      await notifier.saveFileContent(
        '/root/a.txt',
        'new body',
        editorToken: notifier.editorToken,
      );

      expect(ops.saves.single.$1, '/root/a.txt');
      expect(ops.saves.single.$3, 'new body');
      expect(
        ops.saves.single.$2,
        isNotEmpty,
        reason: '快照自带 digest，生产实现据此判远端是否被改过',
      );
      expect(container.read(sftpProvider).editingFilePath, isNull);
    });

    test('a service without SftpEditorOperations fails closed', () async {
      // 只实现 SftpOperations 的旧路径必须拒绝保存，而不是退回
      // writeFileContent 那种不保证原子的写法。
      final legacy = _LegacyService();
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(legacy),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'a.txt',
        path: '/root/a.txt',
        isDirectory: false,
        sizeBytes: 16,
        formattedSize: '16 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      await notifier.openFileForEditing(item);

      await expectLater(
        notifier.saveFileContent(
          '/root/a.txt',
          'new body',
          editorToken: notifier.editorToken,
        ),
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'message',
            'SFTP_ATOMIC_SAVE_UNSUPPORTED',
          ),
        ),
      );
      expect(legacy.writes, isEmpty, reason: 'fail-closed：一次字节都不能写');
      expect(
        container.read(sftpProvider).editingFilePath,
        '/root/a.txt',
        reason: '保存失败后编辑器必须仍然开着，用户内容不丢',
      );
    });

    test('a save against a different target path is refused', () async {
      final ops = _FakeService();
      final (container, _, _) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'a.txt',
        path: '/root/a.txt',
        isDirectory: false,
        sizeBytes: 16,
        formattedSize: '16 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      await notifier.openFileForEditing(item);

      await expectLater(
        notifier.saveFileContent(
          '/root/b.txt',
          'new body',
          editorToken: notifier.editorToken,
        ),
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'message',
            'SFTP_EDITOR_EXPIRED',
          ),
        ),
      );
      expect(ops.saves, isEmpty);
    });

    test('a save after the editor closed is refused', () async {
      final ops = _FakeService();
      final (container, _, _) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'a.txt',
        path: '/root/a.txt',
        isDirectory: false,
        sizeBytes: 16,
        formattedSize: '16 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      await notifier.openFileForEditing(item);
      final token = notifier.editorToken;
      notifier.closeFileEditor();

      await expectLater(
        notifier.saveFileContent('/root/a.txt', 'new body', editorToken: token),
        throwsA(
          isA<SFTPException>().having(
            (e) => e.message,
            'message',
            'SFTP_EDITOR_EXPIRED',
          ),
        ),
      );
      expect(ops.saves, isEmpty);
    });

    test(
      'a failed save leaves the editor open and the draft in place',
      () async {
        final ops = _FakeService();
        ops.saveFailure = const SFTPException('SFTP_EDIT_CONFLICT');
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        final item = SftpFileItem(
          name: 'a.txt',
          path: '/root/a.txt',
          isDirectory: false,
          sizeBytes: 16,
          formattedSize: '16 B',
          permissions: '-rw-r--r--',
          modified: '2026-09-16',
        );
        await notifier.openFileForEditing(item);
        notifier.updateEditorDraft('work in progress');
        // 草稿写入是 500ms 去抖，必须真的等它落盘。
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await pumpEventQueue();

        await expectLater(
          notifier.saveFileContent(
            '/root/a.txt',
            'new body',
            editorToken: notifier.editorToken,
          ),
          throwsA(isA<SFTPException>()),
        );
        expect(
          container.read(sftpProvider).editingFilePath,
          '/root/a.txt',
          reason: '保存失败后编辑器必须仍然开着',
        );
        // 草稿只落在加密存储里；state.editingFileContent 由 UI 持有，
        // 这里刻意不去断言它，免得把「谁负责回显」这条分工写进测试。
        expect(secure.drafts.values.single!['content'], 'work in progress');
        expect(
          secure.drafts.values.single!['digest'],
          isNotEmpty,
          reason: '草稿要带上快照 digest，下次打开才能判出冲突',
        );
      },
    );

    test('a successful save clears the draft and closes the editor', () async {
      final ops = _FakeService();
      final (container, _, secure) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      final item = SftpFileItem(
        name: 'a.txt',
        path: '/root/a.txt',
        isDirectory: false,
        sizeBytes: 16,
        formattedSize: '16 B',
        permissions: '-rw-r--r--',
        modified: '2026-09-16',
      );
      await notifier.openFileForEditing(item);
      notifier.updateEditorDraft('saved body');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await pumpEventQueue();

      final draftKey = secure.drafts.keys.single;
      expect(secure.drafts[draftKey], isNotNull);

      await notifier.saveFileContent(
        '/root/a.txt',
        'saved body',
        editorToken: notifier.editorToken,
      );

      expect(
        secure.deleted,
        contains(draftKey),
        reason: '保存成功后草稿必须清掉，否则下次打开会误报冲突',
      );
      expect(secure.drafts[draftKey], isNull);
      expect(container.read(sftpProvider).editingFilePath, isNull);
    });

    test(
      'a draft over the preview cap is rejected without being written',
      () async {
        final ops = _FakeService();
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        final item = SftpFileItem(
          name: 'a.txt',
          path: '/root/a.txt',
          isDirectory: false,
          sizeBytes: 16,
          formattedSize: '16 B',
          permissions: '-rw-r--r--',
          modified: '2026-09-16',
        );
        await notifier.openFileForEditing(item);

        notifier.updateEditorDraft(
          'x' * (SftpClientService.maxPreviewBytes + 1),
        );

        expect(
          container.read(sftpProvider).errorMessage,
          SftpClientService.previewTooLargeCode,
        );
        expect(secure.drafts, isEmpty);
      },
    );
  });

  group('SftpNotifier.flushEditorDraft', () {
    SftpFileItem file(String name) => SftpFileItem(
      name: name,
      path: '/root/$name',
      isDirectory: false,
      sizeBytes: 16,
      formattedSize: '16 B',
      permissions: '-rw-r--r--',
      modified: '2026-09-16',
    );

    /// SFTP_DRAFT_SAVE_FAILED 是 flush 的对外契约，替身抛什么错都会被
    /// 生产代码归到这个码上；断言统一盯这个码，免得把替身实现写进用例。
    Matcher draftSaveFailed() => isA<SFTPException>().having(
      (e) => e.message,
      'message',
      'SFTP_DRAFT_SAVE_FAILED',
    );

    Matcher editorExpired() => isA<SFTPException>().having(
      (e) => e.message,
      'message',
      'SFTP_EDITOR_EXPIRED',
    );

    Future<SftpNotifier> openEditor(
      ProviderContainer container,
      String name,
    ) async {
      final notifier = container.read(sftpProvider.notifier);
      await notifier.openFileForEditing(file(name));
      return notifier;
    }

    test(
      'an immediate flush waits for the secure write instead of the debounce',
      () async {
        final (container, _, secure) = await _container(_FakeService());
        addTearDown(container.dispose);
        await pumpEventQueue();
        final notifier = await openEditor(container, 'a.txt');
        final token = notifier.editorToken;

        final gate = Completer<void>();
        secure.draftSaveGate = gate;
        notifier.updateEditorDraft('flush before close', editorToken: token);

        var settled = false;
        final flushing = notifier
            .flushEditorDraft(editorToken: token)
            .then((_) => settled = true);
        await pumpEventQueue();
        expect(settled, isFalse, reason: '加密写还没落定，flush 不允许先返回');
        expect(secure.drafts, isEmpty);

        gate.complete();
        await flushing;
        expect(secure.drafts.values.single!['content'], 'flush before close');
        expect(
          container.read(sftpProvider).editingFilePath,
          '/root/a.txt',
          reason: 'flush 只落草稿，不关编辑器',
        );

        await Future<void>.delayed(const Duration(milliseconds: 700));
        await pumpEventQueue();
        expect(
          secure.saves,
          hasLength(1),
          reason: 'flush 必须取消去抖定时器，否则同一条草稿会再写一次',
        );
      },
    );

    test(
      'a failed secure write makes flush throw and keeps the editor open',
      () async {
        final (container, _, secure) = await _container(_FakeService());
        addTearDown(container.dispose);
        await pumpEventQueue();
        final notifier = await openEditor(container, 'a.txt');
        final token = notifier.editorToken;

        secure.draftSaveFailure = StateError('keystore unavailable');
        notifier.updateEditorDraft('unsaved', editorToken: token);

        await expectLater(
          notifier.flushEditorDraft(editorToken: token),
          throwsA(draftSaveFailed()),
        );
        expect(
          container.read(sftpProvider).editingFilePath,
          '/root/a.txt',
          reason: '抛错时编辑器必须还开着，用户内容才不会丢',
        );
        expect(
          container.read(sftpProvider).errorMessage,
          'SFTP_DRAFT_SAVE_FAILED',
        );
        expect(secure.drafts, isEmpty);
      },
    );

    test('a successful retry clears the earlier draft failure', () async {
      final (container, _, secure) = await _container(_FakeService());
      addTearDown(container.dispose);
      await pumpEventQueue();
      final notifier = await openEditor(container, 'a.txt');
      final token = notifier.editorToken;

      secure.draftSaveFailure = StateError('keystore unavailable');
      notifier.updateEditorDraft('first try', editorToken: token);
      await expectLater(
        notifier.flushEditorDraft(editorToken: token),
        throwsA(draftSaveFailed()),
      );

      secure.draftSaveFailure = null;
      notifier.updateEditorDraft('second try', editorToken: token);
      await notifier.flushEditorDraft(editorToken: token);

      expect(secure.drafts.values.single!['content'], 'second try');
      expect(secure.saves, hasLength(1), reason: '失败的那次没有写进去，成功后只应落一次');
      expect(container.read(sftpProvider).editingFilePath, '/root/a.txt');
    });

    test(
      'an expired editor token is rejected before touching storage',
      () async {
        final (container, _, secure) = await _container(_FakeService());
        addTearDown(container.dispose);
        await pumpEventQueue();
        final notifier = await openEditor(container, 'a.txt');
        final stale = notifier.editorToken;
        notifier.closeFileEditor(editorToken: stale);

        await expectLater(
          notifier.flushEditorDraft(editorToken: stale),
          throwsA(editorExpired()),
        );

        await notifier.openFileForEditing(file('b.txt'));
        expect(
          notifier.editorToken,
          isNot(stale),
          reason: '重新打开会换掉 token，旧 token 不能拿来 flush',
        );
        await expectLater(
          notifier.flushEditorDraft(editorToken: stale),
          throwsA(editorExpired()),
        );

        await notifier.flushEditorDraft(editorToken: notifier.editorToken);
        expect(secure.saves, isEmpty, reason: '被拒绝的 flush 一次存储写入都不许发起');
      },
    );

    test('a failed write on one file does not poison a later editor', () async {
      final (container, _, secure) = await _container(_FakeService());
      addTearDown(container.dispose);
      await pumpEventQueue();
      final notifier = container.read(sftpProvider.notifier);

      secure.draftSaveFailure = StateError('keystore unavailable');
      await notifier.openFileForEditing(file('a.txt'));
      final stale = notifier.editorToken;
      notifier.updateEditorDraft('old body', editorToken: stale);
      await expectLater(
        notifier.flushEditorDraft(editorToken: stale),
        throwsA(draftSaveFailed()),
      );
      notifier.closeFileEditor(editorToken: stale);

      secure.draftSaveFailure = null;
      await notifier.openFileForEditing(file('b.txt'));
      final fresh = notifier.editorToken;

      await expectLater(
        notifier.flushEditorDraft(editorToken: fresh),
        completes,
        reason: '另一个文件的失败不许波及这个编辑器',
      );
      notifier.updateEditorDraft('new body', editorToken: fresh);
      await notifier.flushEditorDraft(editorToken: fresh);

      expect(secure.drafts.values.single!['content'], 'new body');
      expect(container.read(sftpProvider).editingFilePath, '/root/b.txt');
    });
  });

  group('SFTP draft races', () {
    SftpFileItem file(String name) => SftpFileItem(
      name: name,
      path: '/root/$name',
      isDirectory: false,
      sizeBytes: 16,
      formattedSize: '16 B',
      permissions: '-rw-r--r--',
      modified: '2026-09-16',
    );

    test(
      'a failed same-path reread clears the old snapshot and refuses to save',
      () async {
        final ops = _FakeService();
        final (container, _, _) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.openFileForEditing(file('a.txt'));
        expect(
          notifier.editorOriginalContent,
          'body of /root/a.txt',
          reason: 'the first open establishes the remote baseline',
        );
        final staleToken = notifier.editorToken;

        ops.readFailure = const SFTPException('SFTP_EDIT_CONFLICT');
        await notifier.openFileForEditing(file('a.txt'));
        final freshToken = notifier.editorToken;

        expect(
          freshToken,
          isNot(staleToken),
          reason: 'a reread begins a new editor epoch',
        );
        expect(
          notifier.editorOriginalContent,
          isNull,
          reason:
              'a failed same-path reread must clear the old snapshot content',
        );
        expect(
          container.read(sftpProvider).editingFilePath,
          isNull,
          reason: 'the failed reread leaves no editable path',
        );
        expect(container.read(sftpProvider).errorMessage, isNotNull);

        await expectLater(
          notifier.saveFileContent(
            '/root/a.txt',
            'anything',
            editorToken: freshToken,
          ),
          throwsA(isA<SFTPException>()),
        );
        expect(
          ops.saves,
          isEmpty,
          reason: 'a failed reread dropped the snapshot; no remote save occurs',
        );
      },
    );

    test('over-limit draft text then valid text can flush and clears the size '
        'error', () async {
      final ops = _FakeService();
      final (container, _, secure) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(file('a.txt'));
      final token = notifier.editorToken;

      notifier.updateEditorDraft(
        'x' * (SftpClientService.maxPreviewBytes + 1),
        editorToken: token,
      );
      expect(
        container.read(sftpProvider).errorMessage,
        SftpClientService.previewTooLargeCode,
      );

      notifier.updateEditorDraft('valid body', editorToken: token);
      expect(
        container.read(sftpProvider).errorMessage,
        isNull,
        reason: 'valid text clears the earlier over-limit error',
      );
      expect(secure.drafts, isEmpty, reason: 'the write is still debounced');

      await notifier.flushEditorDraft(editorToken: token);
      expect(secure.drafts.values.single!['content'], 'valid body');
      expect(
        container.read(sftpProvider).editingFilePath,
        '/root/a.txt',
        reason: 'a flush only persists the draft, it does not close the editor',
      );
    });

    test(
      'an async failed old same-path secure write cannot publish a banner on '
      'a newly opened editor',
      () async {
        final ops = _FakeService();
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.openFileForEditing(file('a.txt'));
        final staleToken = notifier.editorToken;

        final gate = Completer<void>();
        secure.draftSaveGate = gate;
        secure.draftSaveFailure = StateError('keystore unavailable');
        notifier.updateEditorDraft('old work', editorToken: staleToken);
        final oldFlush = notifier
            .flushEditorDraft(editorToken: staleToken)
            .then((_) {}, onError: (_) {});
        await pumpEventQueue();
        expect(secure.saves, isEmpty, reason: 'the old secure write is gated');

        await notifier.openFileForEditing(file('a.txt'));
        final freshToken = notifier.editorToken;
        expect(
          freshToken,
          isNot(staleToken),
          reason: 'reopening starts a fresh editor epoch',
        );
        expect(container.read(sftpProvider).errorMessage, isNull);

        gate.complete();
        await oldFlush;
        await pumpEventQueue();

        expect(
          secure.saves,
          isEmpty,
          reason: 'the gated write failed, so it never persisted',
        );
        expect(
          container.read(sftpProvider).errorMessage,
          isNull,
          reason:
              'a failed OLD same-path async write must not banner the NEW '
              'editor',
        );
      },
    );

    test(
      'a gated same-path deletion is serialized before a reopened draft write',
      () async {
        final ops = _FakeService();
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.openFileForEditing(file('a.txt'));
        final staleToken = notifier.editorToken;

        final deleteGate = Completer<void>();
        secure.deleteGate = deleteGate;
        final deletion = notifier.discardEditorDraft(editorToken: staleToken);
        await pumpEventQueue();
        expect(secure.events, isEmpty, reason: 'the old deletion is gated');

        await notifier.openFileForEditing(file('a.txt'));
        final freshToken = notifier.editorToken;
        expect(
          freshToken,
          isNot(staleToken),
          reason: 'reopening starts a fresh epoch on the same draft key',
        );
        notifier.updateEditorDraft('current work', editorToken: freshToken);

        deleteGate.complete();
        await deletion;
        await pumpEventQueue();
        await notifier.flushEditorDraft(editorToken: freshToken);
        await pumpEventQueue();

        expect(
          secure.events,
          ['delete', 'save:current work'],
          reason: 'the reopened write must be ordered after the old deletion',
        );
        expect(
          secure.drafts.values.single!['content'],
          'current work',
          reason: 'the queued current draft survives the older deletion',
        );
      },
    );

    test(
      'a failing secure-delete surfaces but does not poison a later write',
      () async {
        final ops = _FakeService();
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.openFileForEditing(file('a.txt'));
        final token = notifier.editorToken;

        secure.deleteFailure = StateError('keystore unavailable');
        await expectLater(
          notifier.discardEditorDraft(editorToken: token),
          throwsA(isA<StateError>()),
        );
        expect(secure.events, isEmpty, reason: 'a failed delete wrote nothing');

        secure.deleteFailure = null;
        notifier.updateEditorDraft('recovered work', editorToken: token);
        await notifier.flushEditorDraft(editorToken: token);

        expect(
          secure.events,
          ['save:recovered work'],
          reason: 'the serialized chain recovers after a failed delete',
        );
        expect(secure.drafts.values.single!['content'], 'recovered work');
      },
    );

    test(
      'a same-revision restored draft keeps the remote baseline; a mismatched '
      'revision retains the draft and refuses overwrite',
      () async {
        final ops = _FakeService();
        final (container, _, secure) = await _container(ops);
        addTearDown(container.dispose);
        final notifier = container.read(sftpProvider.notifier);
        await pumpEventQueue();

        await notifier.openFileForEditing(file('a.txt'));
        final baseline = notifier.editorOriginalContent!;
        final first = notifier.editorToken;
        notifier.updateEditorDraft('my draft', editorToken: first);
        await notifier.flushEditorDraft(editorToken: first);
        notifier.closeFileEditor(editorToken: first);
        final draftKey = secure.drafts.keys.single;
        expect(secure.drafts[draftKey]!['content'], 'my draft');

        // Remote unchanged: the stored draft still matches the snapshot digest.
        await notifier.openFileForEditing(file('a.txt'));
        expect(
          notifier.editorOriginalContent,
          baseline,
          reason: 'the remote baseline survives a same-revision restore',
        );
        expect(
          container.read(sftpProvider).editingFileContent,
          'my draft',
          reason: 'the editor shows the restored draft, not the baseline',
        );
        expect(
          container.read(sftpProvider).errorMessage,
          isNull,
          reason: 'a same-revision draft is not a conflict',
        );

        // Someone edits the file on the server: the stored draft's revision no
        // longer matches the fresh snapshot.
        ops.contents['/root/a.txt'] = 'someone else edited this';
        await notifier.openFileForEditing(file('a.txt'));

        expect(
          container.read(sftpProvider).editingFileContent,
          'my draft',
          reason: 'a mismatched revision still retains the local draft',
        );
        expect(
          notifier.editorOriginalContent,
          'someone else edited this',
          reason: 'the baseline reflects the new remote content',
        );
        expect(
          container.read(sftpProvider).errorMessage,
          'SFTP_EDIT_DRAFT_CONFLICT',
        );

        await expectLater(
          notifier.saveFileContent(
            '/root/a.txt',
            'my draft',
            editorToken: notifier.editorToken,
          ),
          throwsA(
            isA<SFTPException>().having(
              (e) => e.message,
              'message',
              'SFTP_EDIT_DRAFT_CONFLICT',
            ),
          ),
        );
        expect(
          ops.saves,
          isEmpty,
          reason: 'a mismatched-revision conflict refuses any overwrite',
        );
      },
    );

    test('an old save whose secure-delete is pending throws EXPIRED and cannot '
        'close or refresh a newly opened editor', () async {
      final ops = _FakeService();
      final (container, _, secure) = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await pumpEventQueue();

      await notifier.openFileForEditing(file('a.txt'));
      final staleToken = notifier.editorToken;

      final gate = Completer<void>();
      final entered = Completer<void>();
      secure.deleteGate = gate;
      secure.deleteEntered = entered;
      Object? saveError;
      final save = notifier
          .saveFileContent(
            '/root/a.txt',
            'committed body',
            editorToken: staleToken,
          )
          .then(
            (_) {},
            onError: (Object e) {
              saveError = e;
            },
          );
      await entered.future;
      expect(
        ops.saves,
        hasLength(1),
        reason: 'the remote atomic save completed before cleanup',
      );

      // Open a different file while the secure-delete is still awaiting.
      await notifier.openFileForEditing(file('b.txt'));
      expect(
        notifier.editorToken,
        isNot(staleToken),
        reason: 'opening another file starts a fresh editor epoch',
      );
      await pumpEventQueue();
      final listedBefore = ops.listedPaths.length;

      gate.complete();
      await save;
      await pumpEventQueue();

      expect(
        saveError,
        isA<SFTPException>().having(
          (e) => e.message,
          'message',
          'SFTP_EDITOR_EXPIRED',
        ),
        reason: 'the stale save must fail once the editor moved on',
      );
      expect(
        container.read(sftpProvider).editingFilePath,
        '/root/b.txt',
        reason: 'the stale save must not close the new editor',
      );
      expect(
        container.read(sftpProvider).editingFileContent,
        'body of /root/b.txt',
        reason: 'the new editor keeps its own content',
      );
      expect(
        ops.listedPaths.length,
        listedBefore,
        reason: 'the stale save must not trigger a directory refresh',
      );
    });
  });
}

/// 只实现 [SftpOperations] 的旧服务：用来证明保存路径会 fail-closed。
class _LegacyService implements SftpOperations {
  final writes = <(String, String)>[];

  @override
  Future<void> writeFileContent(String path, String content) async {
    writes.add((path, content));
  }

  @override
  Future<List<SftpFileItem>> listFiles(String path) async => const [];

  @override
  Future<String> readFileContent(String path) async => 'legacy body';

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> deleteDirectory(String path) async {}

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) => throw StateError('unused');

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) => throw StateError('unused');

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => 0;

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => 0;
}
