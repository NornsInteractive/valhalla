import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/file_bookmarks_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

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

class _SwitchableActiveServer extends ActiveServerNotifier {
  ServerProfile? _server = const ServerProfile(
    id: 'srv-1',
    name: 'first server',
    host: 'a.example.test',
    username: 'root',
  );

  @override
  ServerProfile? build() => _server;

  void switchServer() {
    _server = const ServerProfile(
      id: 'srv-2',
      name: 'second server',
      host: 'b.example.test',
      username: 'root',
    );
    state = _server;
  }

  void clearServer() {
    _server = null;
    state = null;
  }
}

class _ConnectedNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _BookmarkEnv {
  _BookmarkEnv({required this.container, required this.storage});

  final ProviderContainer container;
  final LocalStorageService storage;

  FileBookmarksNotifier get notifier =>
      container.read(fileBookmarksProvider.notifier);

  List<String> get bookmarks => container.read(fileBookmarksProvider);
}

Future<_BookmarkEnv> _env() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
      activeServerProvider.overrideWith(_SwitchableActiveServer.new),
      serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return _BookmarkEnv(container: container, storage: storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('没有活动服务器时书签为空且不允许切换', () async {
    final env = await _env();
    (env.container.read(activeServerProvider.notifier)
            as _SwitchableActiveServer)
        .clearServer();
    env.container.read(fileBookmarksProvider);

    expect(env.bookmarks, isEmpty);
    await expectLater(
      env.notifier.toggle('/var/www'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'SERVER_NOT_FOUND',
        ),
      ),
    );
  });

  test('首次切换写入存储并出现在状态里，再次切换即移除', () async {
    final env = await _env();
    expect(env.bookmarks, isEmpty);

    await env.notifier.toggle('/var/www/my-project');
    expect(env.bookmarks, ['/var/www/my-project']);
    expect(env.storage.getFileBookmarks('srv-1'), ['/var/www/my-project']);

    await env.notifier.toggle('/etc/nginx');
    expect(env.bookmarks, ['/var/www/my-project', '/etc/nginx']);

    await env.notifier.toggle('/var/www/my-project');
    expect(env.bookmarks, ['/etc/nginx']);
    expect(env.storage.getFileBookmarks('srv-1'), ['/etc/nginx']);
  });

  test('路径先归一化再比较，同一书签的别名写法会取消收藏', () async {
    final env = await _env();

    await env.notifier.toggle('/var/www/my-project');
    await env.notifier.toggle('/var/www/./my-project');

    expect(env.bookmarks, isEmpty, reason: '归一化后视为同一个书签，再次切换应当取消而不是追加第二条');
    expect(env.storage.getFileBookmarks('srv-1'), isEmpty);
  });

  test('相对路径与空字节被拒绝，且不写入存储', () async {
    final env = await _env();

    for (final invalid in ['var/www', '', '/var/\x00www']) {
      await expectLater(
        env.notifier.toggle(invalid),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'FILE_PATH_INVALID',
          ),
        ),
        reason: '书签路径 $invalid 必须被拒绝',
      );
    }
    expect(env.bookmarks, isEmpty);
    expect(env.storage.getFileBookmarks('srv-1'), isEmpty);
  });

  test('书签按服务器隔离，切换服务器读到各自的列表', () async {
    final env = await _env();
    await env.notifier.toggle('/var/www/my-project');

    final server =
        env.container.read(activeServerProvider.notifier)
            as _SwitchableActiveServer;
    server.switchServer();
    expect(env.bookmarks, isEmpty, reason: '新服务器不应看到别人的书签');

    await env.notifier.toggle('/srv/app');
    expect(env.bookmarks, ['/srv/app']);
    expect(env.storage.getFileBookmarks('srv-1'), ['/var/www/my-project']);
    expect(env.storage.getFileBookmarks('srv-2'), ['/srv/app']);
  });

  test('持久化失败时状态保持原样', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final failing = _FailingBookmarkStorage(prefs);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(failing),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        activeServerProvider.overrideWith(_SwitchableActiveServer.new),
        serverConnectionProvider.overrideWith(_ConnectedNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(fileBookmarksProvider.notifier).toggle('/var/www'),
      throwsA(isA<StateError>()),
    );
    expect(
      container.read(fileBookmarksProvider),
      isEmpty,
      reason: '落盘失败时不得声称已经收藏',
    );
  });

  test('切换到没有书签的服务器后仍可写入', () async {
    final env = await _env();
    final server =
        env.container.read(activeServerProvider.notifier)
            as _SwitchableActiveServer;
    server.switchServer();
    expect(env.bookmarks, isEmpty);

    await env.notifier.toggle('/opt/data');
    expect(env.bookmarks, ['/opt/data']);
    expect(env.storage.getFileBookmarks('srv-2'), ['/opt/data']);
  });
}

/// 保存书签时必定失败的存储替身。
class _FailingBookmarkStorage extends LocalStorageService {
  _FailingBookmarkStorage(super.prefs);

  @override
  Future<void> saveFileBookmarks(String serverId, List<String> paths) async {
    throw StateError('FILE_BOOKMARK_SAVE_FAILED');
  }
}
