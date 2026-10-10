import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

SftpFileItem _item(
  String name, {
  bool isDirectory = false,
  bool isSymbolicLink = false,
  String? linkTargetErrorCode,
  int size = 12,
  String? path,
}) => SftpFileItem(
  name: name,
  path: path ?? '/var/www/my-project/$name',
  isDirectory: isDirectory,
  isSymbolicLink: isSymbolicLink,
  linkTargetErrorCode: linkTargetErrorCode,
  sizeBytes: size,
  formattedSize: '$size B',
  permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
  modified: '2026-10-05',
);

class _FakeOps implements SftpOperations {
  List<SftpFileItem> files = const [];
  final listGates = <String, Completer<List<SftpFileItem>>>{};
  final listedPaths = <String>[];
  final deletedFiles = <String>[];
  final deletedDirs = <String>[];
  final renames = <(String, String)>[];
  int listFilesCalls = 0;
  Object? throwing;

  @override
  Future<List<SftpFileItem>> listFiles(String path) async {
    listedPaths.add(path);
    listFilesCalls++;
    if (listGates[path] case final gate?) return gate.future;
    final thrown = throwing;
    if (thrown != null) {
      throw thrown;
    }
    return files;
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
  Future<void> deleteFile(String path) async => deletedFiles.add(path);

  @override
  Future<void> deleteDirectory(String path) async => deletedDirs.add(path);

  @override
  Future<void> rename(String oldPath, String newPath) async =>
      renames.add((oldPath, newPath));

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => throw UnimplementedError();

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

class _FakeSshClient implements SSHClient {
  _FakeSshClient(this._sftp);
  final SftpClient _sftp;

  @override
  bool get isClosed => false;

  @override
  Future<SftpClient> sftp() => Future.value(_sftp);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSftpClient implements SftpClient {
  final List<SftpName> listing;
  final Future<SftpFileAttrs> Function(String path) statBehavior;
  final statPaths = <String>[];
  final followLinkValues = <bool>[];
  final removeCalls = <String>[];
  final rmdirCalls = <String>[];
  final renameCalls = <(String, String)>[];
  var inFlight = 0;
  var maxInFlight = 0;
  Object? throwing;
  Object? listdirThrowing;

  _StubSftpClient(this.listing, this.statBehavior);

  @override
  Future<List<SftpName>> listdir(String path) async {
    final thrown = listdirThrowing;
    if (thrown != null) throw thrown;
    return listing;
  }

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    statPaths.add(path);
    followLinkValues.add(followLink);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      return await statBehavior(path);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> remove(String path) async => removeCalls.add(path);

  @override
  Future<void> rmdir(String path) async => rmdirCalls.add(path);

  @override
  Future<void> rename(String oldPath, String newPath) async =>
      renameCalls.add((oldPath, newPath));

  @override
  SSHPrintHandler? get printDebug => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  SSHClient? sshClient;

  @override
  SSHClient? getClient(String serverId) => sshClient;
}

class _ConnectedNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _DisconnectedNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.disconnected);
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

class _FakeSharedPreferences implements SharedPreferences {
  _FakeSharedPreferences(this.native) {
    cache.addAll(native);
  }

  final Map<String, Object> native;
  final Map<String, Object> cache = {};
  bool failSetTrueBool = false;

  @override
  bool? getBool(String key) => cache[key] as bool?;

  @override
  String? getString(String key) => cache[key] as String?;

  @override
  Future<bool> setBool(String key, bool value) async {
    // optimistic cache write first, then platform persistence may fail
    cache[key] = value;
    return !(failSetTrueBool && value);
  }

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(native);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingHiddenPrefs extends LocalStorageService {
  _ThrowingHiddenPrefs(super.prefs);

  @override
  Future<void> setFileShowHidden(bool value) async {
    throw StateError('persist failed');
  }
}

Future<ProviderContainer> _container(
  _FakeOps ops, {
  SSHClientManager? sshManager,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(
        sshManager ?? _FakeSshManager(storage),
      ),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      sftpOperationsProvider.overrideWithValue(ops),
    ],
  );
}

Future<List<SftpName>> _serviceListing() async {
  const dirMode = SftpFileMode.value((1 << 14) | 0x1ED);
  const linkMode = SftpFileMode.value((1 << 15) + (1 << 13) | 0x1FF);
  return [
    SftpName(
      filename: 'file.txt',
      longname: '',
      attr: SftpFileAttrs(
        size: 10,
        mode: SftpFileMode.value((1 << 15) | 0x1B6),
      ),
    ),
    SftpName(
      filename: 'subdir',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: dirMode),
    ),
    SftpName(
      filename: 'link',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: linkMode),
    ),
    SftpName(
      filename: 'linkdir',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: linkMode),
    ),
    SftpName(
      filename: 'broken',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: linkMode),
    ),
    SftpName(
      filename: 'denied',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: linkMode),
    ),
    SftpName(
      filename: 'cyclic',
      longname: '',
      attr: SftpFileAttrs(size: 0, mode: linkMode),
    ),
  ];
}

Future<SftpFileAttrs> _serviceStat(String path) async {
  const dirMode = SftpFileMode.value((1 << 14) | 0x1ED);
  const linkMode = SftpFileMode.value((1 << 15) + (1 << 13) | 0x1FF);
  final name = path.split('/').last;
  switch (name) {
    case 'link':
      return SftpFileAttrs(
        size: 24,
        mode: SftpFileMode.value((1 << 15) | 0x1A4),
      );
    case 'linkdir':
      return SftpFileAttrs(size: 0, mode: dirMode);
    case 'broken':
      throw SftpStatusError(SftpStatusCode.failure, 'no such file');
    case 'denied':
      throw SftpStatusError(SftpStatusCode.permissionDenied, 'denied');
    case 'cyclic':
      return SftpFileAttrs(size: 0, mode: linkMode);
  }
  throw StateError('unexpected stat $path');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SftpState 可见性默认与 copyWith', () {
    test('showHiddenFiles 默认关闭', () {
      expect(const SftpState().showHiddenFiles, isFalse);
    });

    test('copyWith 保持 showHiddenFiles/search/sort/transfers', () {
      final state = SftpState(
        currentPath: '/etc',
        searchQuery: 'conf',
        showHiddenFiles: true,
        transfers: [
          SftpTransfer(
            id: 't1',
            kind: SftpTransferKind.download,
            remotePath: '/a',
            localPath: '/b',
          ),
        ],
      );
      final next = state.copyWith();
      expect(next.showHiddenFiles, true);
      expect(next.searchQuery, 'conf');
      expect(next.transfers, state.transfers);
      final flipped = state.copyWith(showHiddenFiles: false);
      expect(flipped.showHiddenFiles, false);
      expect(flipped.transfers, state.transfers);
      expect(flipped.searchQuery, state.searchQuery);
    });

    test('SftpFileItem 默认非符号链接且路径保持原始别名', () {
      final item = SftpFileItem(
        name: 'README.md',
        path: '/tmp/alias/README.md',
        isDirectory: false,
        sizeBytes: 5,
        formattedSize: '5 B',
        permissions: '-rw-r--r--',
        modified: '2026-10-05',
      );
      expect(item.isSymbolicLink, false);
      expect(item.linkTargetErrorCode, isNull);
      expect(item.path, '/tmp/alias/README.md');
    });
  });

  group('filteredFiles 规则', () {
    late List<SftpFileItem> roots;
    setUp(() {
      roots = [
        _item('folder', isDirectory: true),
        _item('task'),
        _item('..', isDirectory: true),
        _item('.', isDirectory: true),
        _item('.secret'),
      ];
    });

    test('根目录默认过滤 hidden 与特殊名称', () {
      final state = SftpState(currentPath: '/', files: roots);
      expect(state.filteredFiles.map((item) => item.name).toList(), [
        'folder',
        'task',
      ]);
    });

    test('根目录开启 hidden 后只过滤 .，不复刻 ../..', () {
      final state = SftpState(
        currentPath: '/',
        files: roots,
        showHiddenFiles: true,
      );
      expect(state.filteredFiles.map((item) => item.name).toList(), [
        'folder',
        '.secret',
        'task',
      ]);
    });

    test('非根目录 .. 始终可见，hidden 只受开关过滤', () {
      final state = SftpState(currentPath: '/var', files: roots);
      expect(state.filteredFiles.map((item) => item.name).toList(), [
        '..',
        'folder',
        'task',
      ]);
      final opened = state.copyWith(showHiddenFiles: true);
      expect(opened.filteredFiles.map((item) => item.name).toList(), [
        '..',
        'folder',
        '.secret',
        'task',
      ]);
    });
  });

  group('setShowHiddenFiles', () {
    test('持久化成功后才更新状态并复用缓存数据不过远端', () async {
      final ops = _FakeOps()..files = [_item('.secret'), _item('task')];
      final container = await _container(ops);
      addTearDown(container.dispose);

      final notifier = container.read(sftpProvider.notifier);
      await notifier.loadDirectory('/var/www/my-project');
      expect(ops.listFilesCalls, 1);

      await notifier.setShowHiddenFiles(true);
      final next = container.read(sftpProvider);
      expect(next.showHiddenFiles, true);
      expect(next.errorMessage, isNull);
      expect(ops.listFilesCalls, 1, reason: '过滤应来自缓存，不应重新拉目录');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('valhalla_file_show_hidden_v1'), true);
      expect(next.filteredFiles.map((item) => item.name).toList(), [
        '.secret',
        'task',
      ]);
    });

    test('隐藏搜索/排序在切换 showHiddenFiles 时保留', () async {
      final ops = _FakeOps()..files = [_item('.secret'), _item('task')];
      final container = await _container(ops);
      addTearDown(container.dispose);

      final notifier = container.read(sftpProvider.notifier);
      await notifier.loadDirectory('/var/www/my-project');
      notifier.setSearchQuery('secret');
      await notifier.setShowHiddenFiles(true);

      final state = container.read(sftpProvider);
      expect(state.searchQuery, 'secret');
      expect(state.showHiddenFiles, true);
      expect(state.filteredFiles.map((item) => item.name).toList(), [
        '.secret',
      ]);
    });

    test('存储失败时状态保持原值并暴露 reason code', () async {
      final ops = _FakeOps()..files = [_item('task')];
      final storage = _ThrowingHiddenPrefs(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sftpProvider.notifier).loadDirectory('/var');
      expect(container.read(sftpProvider).showHiddenFiles, false);

      await container.read(sftpProvider.notifier).setShowHiddenFiles(true);
      final state = container.read(sftpProvider);
      expect(state.showHiddenFiles, false, reason: '落盘失败时不能声称可见');
      expect(state.errorMessage, SftpNotifier.hiddenPreferenceSaveFailedCode);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('valhalla_file_show_hidden_v1'), isNull);
    });
  });

  group('provider 对 unresolved 链接的保护', () {
    test('canPreview 对目录与 unresolved links 都返回 false', () async {
      final unresolved = _item(
        'broken.txt',
        isSymbolicLink: true,
        linkTargetErrorCode: SftpFileItem.linkTargetUnavailableCode,
      );
      final directory = _item('subdir', isDirectory: true);
      final regular = _item('README.md');

      final container = await _container(_FakeOps());
      addTearDown(container.dispose);

      final notifier = container.read(sftpProvider.notifier);
      expect(notifier.canPreview(regular), true);
      expect(notifier.canPreview(directory), false);
      expect(notifier.canPreview(unresolved), false);
    });

    test(
      'downloadTo / openFileForEditing 对 unresolved links 只 set 错误提示',
      () async {
        final broken = _item(
          'broken.txt',
          isSymbolicLink: true,
          linkTargetErrorCode: SftpFileItem.linkTargetPermissionDeniedCode,
        );
        final ops = _FakeOps();
        final container = await _container(ops);
        addTearDown(container.dispose);

        final notifier = container.read(sftpProvider.notifier);
        await notifier.downloadTo(broken, '/tmp/local');
        expect(
          container.read(sftpProvider).errorMessage,
          SftpFileItem.linkTargetPermissionDeniedCode,
        );

        await notifier.openFileForEditing(broken);
        expect(
          container.read(sftpProvider).errorMessage,
          SftpFileItem.linkTargetPermissionDeniedCode,
        );
      },
    );
  });

  group('service 分类与并发', () {
    test('普通文件不 stat；最大四并发 stat；alias 路径保留；l 前缀', () async {
      final listing = await _serviceListing();
      // Deterministic barrier: the 4th in-flight stat releases the rest,
      // so maxInFlight is exactly 4 without timing-dependent delays.
      var started = 0;
      final barrier = Completer<void>();
      Future<SftpFileAttrs> barredStat(String path) {
        started++;
        if (started == 4) barrier.complete();
        return barrier.future.then((_) => _serviceStat(path));
      }

      final fakeSftp = _StubSftpClient(listing, barredStat);
      final service = SftpClientService(
        _FakeSshClient(fakeSftp),
        operationTimeout: const Duration(seconds: 5),
      );
      final files = await service.listFiles('/var/www/my-project');
      expect(
        fakeSftp.statPaths,
        isNot(contains('/var/www/my-project/file.txt')),
      );
      expect(fakeSftp.maxInFlight, 4, reason: '符号链接 stat 并发不得超过四条');
      expect(
        fakeSftp.followLinkValues,
        everyElement(isTrue),
        reason: '符号链接必须用 followLink=true 的原生 stat',
      );
      final names = files.map((f) => f.name).toList();
      expect(names, containsAll(['file.txt', 'subdir', 'link', 'linkdir']));

      final link = files.firstWhere((f) => f.name == 'link');
      expect(link.path, '/var/www/my-project/link');
      expect(link.isSymbolicLink, true);
      expect(link.isDirectory, false);
      expect(link.permissions, startsWith('l'));

      final linkdir = files.firstWhere((f) => f.name == 'linkdir');
      expect(linkdir.isSymbolicLink, true);
      expect(linkdir.isDirectory, true);

      final broken = files.firstWhere((f) => f.name == 'broken');
      expect(
        broken.linkTargetErrorCode,
        SftpFileItem.linkTargetUnavailableCode,
      );
      expect(broken.isDirectory, false);
      expect(broken.path, '/var/www/my-project/broken');

      final denied = files.firstWhere((f) => f.name == 'denied');
      expect(
        denied.linkTargetErrorCode,
        SftpFileItem.linkTargetPermissionDeniedCode,
      );

      final cyclic = files.firstWhere((f) => f.name == 'cyclic');
      expect(
        cyclic.linkTargetErrorCode,
        SftpFileItem.linkTargetUnavailableCode,
      );

      expect(
        files.firstWhere((f) => f.name == 'file.txt').permissions,
        startsWith('-'),
      );
      expect(
        files.firstWhere((f) => f.name == 'link').permissions,
        startsWith('l'),
      );
    });
  });

  group('alias-only 删除 / 重命名', () {
    test('目录符号链接走 deleteFile(remove)，删除的是别名而非 rmdir', () async {
      final ops = _FakeOps()..files = [];
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await notifier.loadDirectory('/var/www');

      final dirLink = _item(
        'linkdir',
        isDirectory: true,
        isSymbolicLink: true,
        path: '/var/www/linkdir',
      );
      await notifier.deleteItem(dirLink);
      expect(ops.deletedFiles, ['/var/www/linkdir']);
      expect(ops.deletedDirs, isEmpty, reason: '目录符号链接必须走 remove');
    });

    test('真实目录仍走 deleteDirectory；目标条目不受影响', () async {
      final ops = _FakeOps()..files = [_item('realdir', isDirectory: true)];
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await notifier.loadDirectory('/var/www');

      await notifier.deleteItem(_item('realdir', isDirectory: true));
      expect(ops.deletedDirs, ['/var/www/my-project/realdir']);
      expect(ops.deletedFiles, isEmpty);
    });

    test('服务层 remove/rmdir 使用别名路径，不触碰目标', () async {
      final stub = _StubSftpClient(const [], _serviceStat);
      final tracked = SftpClientService(
        _FakeSshClient(stub),
        operationTimeout: const Duration(seconds: 5),
      );
      await tracked.deleteFile('/var/www/my-project/linkdir');
      expect(stub.removeCalls, ['/var/www/my-project/linkdir']);
      expect(stub.rmdirCalls, isEmpty);
      await tracked.deleteDirectory('/var/www/my-project/realdir');
      expect(stub.rmdirCalls, ['/var/www/my-project/realdir']);
      expect(stub.statPaths, isEmpty, reason: '删除不得额外 stat 目标条目');
    });

    test('rename 收到的是别名路径', () async {
      final ops = _FakeOps()
        ..files = [_item('link', isSymbolicLink: true, path: '/var/www/link')];
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await notifier.loadDirectory('/var/www');

      await notifier.renameItem(
        _item('link', isSymbolicLink: true, path: '/var/www/link'),
        'link2',
      );
      expect(ops.renames, [('/var/www/link', '/var/www/link2')]);
    });
  });

  group('hidden 偏好持久化', () {
    test('新 provider / 重连后仍保持（走同一 SharedPreferences）', () async {
      final ops = _FakeOps()..files = [_item('.secret')];
      final container1 = await _container(ops);
      await container1.read(sftpProvider.notifier).setShowHiddenFiles(true);
      container1.dispose();

      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final container2 = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(container2.dispose);
      expect(container2.read(sftpProvider).showHiddenFiles, true);
    });

    test('关闭连接时也可切换并持久化', () async {
      final ops = _FakeOps()..files = [_item('.secret')];
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_DisconnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sftpProvider.notifier).setShowHiddenFiles(true);
      expect(container.read(sftpProvider).showHiddenFiles, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('valhalla_file_show_hidden_v1'), true);
    });

    test('后端写入 false 时保留旧偏好并报 reason code（SharedPreferences 假后端）', () async {
      final fakePrefs = _FakeSharedPreferences({})..failSetTrueBool = true;
      final storage = LocalStorageService(fakePrefs);
      final ops = _FakeOps()..files = [_item('.secret')];
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sftpProvider.notifier).setShowHiddenFiles(true);
      expect(container.read(sftpProvider).showHiddenFiles, false);
      expect(
        container.read(sftpProvider).errorMessage,
        SftpNotifier.hiddenPreferenceSaveFailedCode,
      );
      // optimistic legacy cache must have been discarded by prefs.reload()
      expect(fakePrefs.getBool('valhalla_file_show_hidden_v1'), isNull);

      fakePrefs.failSetTrueBool = false;
      final freshStorage = LocalStorageService(fakePrefs);
      final fresh = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(freshStorage),
          sshClientManagerProvider.overrideWithValue(
            _FakeSshManager(freshStorage),
          ),
          activeServerProvider.overrideWith(_StubActiveServer.new),
          serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
          sftpOperationsProvider.overrideWithValue(ops),
        ],
      );
      addTearDown(fresh.dispose);
      expect(fresh.read(sftpProvider).showHiddenFiles, false);
      expect(freshStorage.getFileShowHidden(), false);
    });

    test('实际写入 false 而非仅覆盖抛错', () async {
      final ops = _FakeOps()..files = [_item('.secret')];
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      await notifier.setShowHiddenFiles(true);
      await notifier.setShowHiddenFiles(false);
      expect(container.read(sftpProvider).showHiddenFiles, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('valhalla_file_show_hidden_v1'), false);
    });
  });

  group('download entrypoints 阻断 unresolved links', () {
    test('downloadTo / downloadFile / downloadAndOpen 全部拒绝', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);
      final notifier = container.read(sftpProvider.notifier);
      final broken = _item(
        'broken.txt',
        linkTargetErrorCode: SftpFileItem.linkTargetUnavailableCode,
      );

      await notifier.downloadTo(broken, '/tmp/local');
      expect(
        container.read(sftpProvider).errorMessage,
        SftpFileItem.linkTargetUnavailableCode,
      );
      expect(container.read(sftpProvider).transfers, isEmpty);

      expect(await notifier.downloadFile(broken), isNull);
      expect(
        container.read(sftpProvider).errorMessage,
        SftpFileItem.linkTargetUnavailableCode,
      );
      expect(await notifier.downloadAndOpen(broken), isNull);
      expect(
        container.read(sftpProvider).errorMessage,
        SftpFileItem.linkTargetUnavailableCode,
      );
      expect(container.read(sftpProvider).transfers, isEmpty);
    });
  });

  group('stat 超时与传输失败', () {
    test('stat 超时阻止新请求并以 reject 结束 listing', () async {
      final listing = await _serviceListing();
      final fakeSftp = _StubSftpClient(
        listing,
        (path) => Completer<SftpFileAttrs>().future,
      );
      final service = SftpClientService(
        _FakeSshClient(fakeSftp),
        operationTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        service.listFiles('/var/www/my-project'),
        throwsA(isA<SFTPException>()),
      );
      expect(fakeSftp.statPaths.length, 4, reason: '超时后不应再为其它链接发起新 stat');
    });

    test('目录列举传输失败直接 reject，不伪装成 broken link', () async {
      final fakeSftp = _StubSftpClient(
        const [],
        _serviceStat,
      )..listdirThrowing = SftpStatusError(SftpStatusCode.noConnection, 'gone');
      final service = SftpClientService(
        _FakeSshClient(fakeSftp),
        operationTimeout: const Duration(seconds: 5),
      );
      await expectLater(
        service.listFiles('/var/www'),
        throwsA(isA<SftpStatusError>()),
      );
      expect(fakeSftp.statPaths, isEmpty);
    });

    test('stat 的 noConnection/connectionLost 包出 SFTPException', () async {
      final listing = <SftpName>[
        SftpName(
          filename: 'link',
          longname: '',
          attr: SftpFileAttrs(
            size: 0,
            mode: SftpFileMode.value((1 << 15) + (1 << 13) | 0x1FF),
          ),
        ),
      ];
      final noConnection = _StubSftpClient(
        listing,
        (path) async =>
            throw SftpStatusError(SftpStatusCode.noConnection, 'lost'),
      );
      final service = SftpClientService(
        _FakeSshClient(noConnection),
        operationTimeout: const Duration(seconds: 5),
      );
      await expectLater(
        service.listFiles('/var/www'),
        throwsA(isA<SFTPException>()),
      );

      final connectionLost = _StubSftpClient(
        listing,
        (path) async =>
            throw SftpStatusError(SftpStatusCode.connectionLost, 'gone'),
      );
      final service2 = SftpClientService(
        _FakeSshClient(connectionLost),
        operationTimeout: const Duration(seconds: 5),
      );
      await expectLater(
        service2.listFiles('/var/www'),
        throwsA(isA<SFTPException>()),
      );
    });
  });

  group('source epoch', () {
    test('后发起的 refresh 不被前一个慢返回覆盖 currentPath/files', () async {
      final ops = _FakeOps();
      final container = await _container(ops);
      addTearDown(container.dispose);

      final notifier = container.read(sftpProvider.notifier);
      final staleDone = Completer<List<SftpFileItem>>();
      final freshDone = Completer<List<SftpFileItem>>();
      ops.listGates['/tmp/a'] = staleDone;
      final staleFuture = notifier.loadDirectory('/tmp/a');
      ops.listGates['/tmp/b'] = freshDone;
      final freshFuture = notifier.loadDirectory('/tmp/b');

      // 先返回旧数据，必须被丢弃；然后正确路径才更新状态。
      staleDone.complete([_item('stale.txt', path: '/tmp/a/stale.txt')]);
      freshDone.complete([_item('fresh.txt', path: '/tmp/b/fresh.txt')]);
      await staleFuture;
      await freshFuture;

      final state = container.read(sftpProvider);
      expect(state.currentPath, '/tmp/b');
      expect(state.files.map((f) => f.name).toList(), ['fresh.txt']);
    });
  });
}
