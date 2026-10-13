import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/file_bookmarks_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

/// fixture 里的活动服务器可在测试中切换，用来验证按服务器隔离。
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
    _server = _server?.id == 'srv-2'
        ? const ServerProfile(
            id: 'srv-1',
            name: 'first server',
            host: 'a.example.test',
            username: 'root',
          )
        : const ServerProfile(
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

class _RecentEnv {
  _RecentEnv({required this.container, required this.storage});

  final ProviderContainer container;
  final LocalStorageService storage;

  FileRecentDirectoriesNotifier get notifier =>
      container.read(fileRecentDirectoriesProvider.notifier);

  List<String> get recent => container.read(fileRecentDirectoriesProvider);

  _SwitchableActiveServer get server =>
      container.read(activeServerProvider.notifier) as _SwitchableActiveServer;
}

Future<_RecentEnv> _env() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      activeServerProvider.overrideWith(_SwitchableActiveServer.new),
    ],
  );
  addTearDown(container.dispose);
  return _RecentEnv(container: container, storage: storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('归一化后的绝对路径写入并在当前服务器可见', () async {
    final env = await _env();

    await env.notifier.record('srv-1', '/var/www/./project/../project');
    expect(env.recent, ['/var/www/project']);
    expect(env.storage.getRecentDirectories('srv-1'), ['/var/www/project']);
  });

  test('只保留最近 20 条，重复路径去重后前移', () async {
    final env = await _env();
    for (var i = 1; i <= 21; i++) {
      await env.notifier.record('srv-1', '/d/$i');
    }
    expect(env.recent, hasLength(20));
    expect(env.recent.first, '/d/21');
    expect(env.recent, isNot(contains('/d/1')), reason: '最旧的一条应被挤出');

    await env.notifier.record('srv-1', '/d/10');
    expect(env.recent, hasLength(20));
    expect(env.recent.first, '/d/10');
    expect(env.recent.where((d) => d == '/d/10'), hasLength(1));
    expect(env.storage.getRecentDirectories('srv-1'), env.recent);
  });

  test('按服务器隔离，切换服务器看不到彼此的记录', () async {
    final env = await _env();
    await env.notifier.record('srv-1', '/var/www/my-project');

    env.server.switchServer();
    expect(env.recent, isEmpty, reason: '新服务器不应看到别的服务器的记录');

    await env.notifier.record('srv-2', '/srv/app');
    expect(env.recent, ['/srv/app']);
    expect(env.storage.getRecentDirectories('srv-1'), ['/var/www/my-project']);
    expect(env.storage.getRecentDirectories('srv-2'), ['/srv/app']);
  });

  test('相对路径与空字节被拒绝，且不写入', () async {
    final env = await _env();
    for (final invalid in ['var/www', '', '/var/\x00www']) {
      expect(
        () => env.notifier.record('srv-1', invalid),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'FILE_PATH_INVALID',
          ),
        ),
        reason: '路径 $invalid 必须被拒绝',
      );
    }
    expect(env.recent, isEmpty);
    expect(env.storage.getRecentDirectories('srv-1'), isEmpty);
  });

  test('旧服务器的补录不得顶替当前服务器的可见列表', () async {
    final env = await _env();
    await env.notifier.record('srv-1', '/var/www/project');

    env.server.switchServer();
    env.container.read(fileRecentDirectoriesProvider);
    expect(env.recent, isEmpty);

    await env.notifier.record('srv-1', '/var/other');
    expect(
      env.recent,
      isEmpty,
      reason: '写 srv-1 时活动服务器已是 srv-2，不得把 srv-1 的列表写进当前状态',
    );
    expect(env.storage.getRecentDirectories('srv-2'), isEmpty);
    expect(env.storage.getRecentDirectories('srv-1'), [
      '/var/other',
      '/var/www/project',
    ]);

    env.server.switchServer();
    expect(env.recent, [
      '/var/other',
      '/var/www/project',
    ], reason: '切回 srv-1 后应能看到补录内容');
  });
}
