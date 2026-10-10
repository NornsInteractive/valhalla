import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/security_settings_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/host_key_entry.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

const _alpha = ServerProfile(
  id: 'alpha',
  name: 'alpha',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

const _bravo = ServerProfile(
  id: 'bravo',
  name: 'bravo',
  host: '10.0.0.2',
  port: 2222,
  username: 'dev',
);

const _charlie = ServerProfile(
  id: 'charlie',
  name: 'charlie',
  host: '10.0.0.3',
  port: 22,
  username: 'dev',
);

/// 记录 disconnect 顺序，且可对指定 server 抛错以模拟失败删除。
class _RecordingSshManager extends SSHClientManager {
  _RecordingSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  final List<String> disconnected = <String>[];
  final List<String> connected = <String>[];

  @override
  void disconnect(String serverId, {bool notifyDeath = false}) {
    disconnected.add(serverId);
    super.disconnect(serverId, notifyDeath: notifyDeath);
  }
}

/// 固定服务器列表，避免测试依赖真实仓库存储。
class _StaticServerList extends ServerListNotifier {
  _StaticServerList(this.servers);
  final List<ServerProfile> servers;

  @override
  List<ServerProfile> build() => servers;
}

class _StaticConnection extends ServerConnectionNotifier {
  _StaticConnection(this.initial);
  final ServerConnectionState initial;
  int disconnects = 0;

  @override
  ServerConnectionState build() => initial;

  @override
  void disconnect() {
    disconnects++;
    state = const ServerConnectionState(
      status: ConnectionStateEnum.disconnected,
    );
  }
}

/// 可控的凭据存储：记录删除调用，并按 server 注入删除失败。
class _FakeSecureStorage implements SecureStorageService {
  final Map<String, String> values = <String, String>{};
  final Set<String> failDeletes = <String>{};
  final List<String> cleared = <String>[];

  String _key(String serverId, String suffix) =>
      'valhalla_server_${serverId}_$suffix';

  @override
  Future<void> clearCredentialsStrict(String serverId) async {
    cleared.add(serverId);
    var failed = false;
    for (final suffix in ['password', 'private_key', 'sudo_password']) {
      if (failDeletes.contains('${serverId}_$suffix')) {
        failed = true;
        continue;
      }
      values.remove(_key(serverId, suffix));
    }
    if (failed) throw StateError('SERVER_CREDENTIALS_CLEAR_FAILED');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  required LocalStorageService storage,
  required SecureStorageService secure,
  required SSHClientManager ssh,
  List<ServerProfile> servers = const [_alpha, _bravo, _charlie],
  ServerConnectionState connection = const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'alpha',
  ),
}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(secure),
      sshClientManagerProvider.overrideWithValue(ssh),
      serverListProvider.overrideWith(() => _StaticServerList(servers)),
      serverConnectionProvider.overrideWith(
        () => _StaticConnection(connection),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

HostKeyEntry _entry(String hostPort) => HostKeyEntry(
  hostPort: hostPort,
  keyType: 'ssh-ed25519',
  fingerprintSha256: 'SHA256:${hostPort.hashCode.toRadixString(16)}',
  trustedAt: DateTime.utc(2026, 1, 1),
);

Future<LocalStorageService> _storageWithTrust(
  List<String> hostPorts, {
  List<ServerProfile> servers = const [_alpha, _bravo, _charlie],
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  await storage.saveServers(servers);
  for (final hostPort in hostPorts) {
    await storage.saveHostKey(_entry(hostPort));
  }
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('trustedHostsProvider 读取可信主机', () {
    test('空状态：没有任何可信主机时返回空列表而不是报错', () async {
      final storage = await _storageWithTrust(const []);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: _RecordingSshManager(storage),
      );
      expect(container.read(trustedHostsProvider), isEmpty);
    });

    test('按 hostPort 排序返回全部条目，字段完整', () async {
      final storage = await _storageWithTrust(const [
        '10.0.0.3:22',
        '10.0.0.1:22',
        '10.0.0.2:2222',
      ]);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: _RecordingSshManager(storage),
      );
      final entries = container.read(trustedHostsProvider);
      expect(entries.map((e) => e.hostPort), [
        '10.0.0.1:22',
        '10.0.0.2:2222',
        '10.0.0.3:22',
      ]);
      for (final entry in entries) {
        expect(entry.keyType, 'ssh-ed25519');
        expect(entry.fingerprintSha256, isNotEmpty);
        expect(entry.trustedAt, DateTime.utc(2026, 1, 1));
      }
    });
  });

  group('trustedHostsProvider.revoke 撤销可信主机', () {
    test('撤销活跃端点：断开匹配的活动连接并删除该主机信任', () async {
      final storage = await _storageWithTrust(const ['10.0.0.1:22']);
      final ssh = _RecordingSshManager(storage);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: ssh,
      );

      await container.read(trustedHostsProvider.notifier).revoke('10.0.0.1:22');

      expect(ssh.disconnected, contains('alpha'));
      expect(storage.getHostKeys().containsKey('10.0.0.1:22'), isFalse);
      expect(
        container.read(trustedHostsProvider).map((e) => e.hostPort),
        isNot(contains('10.0.0.1:22')),
      );
    });

    test('非活跃端点也必须断开对应的 SSH 客户端', () async {
      final storage = await _storageWithTrust(const ['10.0.0.2:2222']);
      final ssh = _RecordingSshManager(storage);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: ssh,
      );
      await container
          .read(trustedHostsProvider.notifier)
          .revoke('10.0.0.2:2222');
      expect(ssh.disconnected, contains('bravo'));
      expect(storage.getHostKeys().containsKey('10.0.0.2:2222'), isFalse);
    });

    test('同 hostPort 的多个服务器配置全部断开', () async {
      const dup = ServerProfile(
        id: 'alpha-2',
        name: 'alpha mirror',
        host: '10.0.0.1',
        port: 22,
        username: 'ops',
      );
      final storage = await _storageWithTrust(
        const ['10.0.0.1:22'],
        servers: const [_alpha, dup, _bravo],
      );
      final ssh = _RecordingSshManager(storage);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: ssh,
        servers: const [_alpha, dup, _bravo],
      );
      await container.read(trustedHostsProvider.notifier).revoke('10.0.0.1:22');
      expect(ssh.disconnected, containsAll(<String>['alpha', 'alpha-2']));
    });

    test('撤销未知 hostPort 不抛错也不影响其他信任', () async {
      final storage = await _storageWithTrust(const ['10.0.0.1:22']);
      final container = _container(
        storage: storage,
        secure: _FakeSecureStorage(),
        ssh: _RecordingSshManager(storage),
      );
      await container
          .read(trustedHostsProvider.notifier)
          .revoke('203.0.113.9:22');
      expect(storage.getHostKeys().containsKey('10.0.0.1:22'), isTrue);
    });

    test('撤销后同一主机再次连接必须重新确认指纹', () async {
      final storage = await _storageWithTrust(const ['10.0.0.1:22']);
      final verifier = SSHHostKeyVerifier(storage);
      final fingerprint = Uint8List.fromList(utf8.encode('SHA256:${'A' * 43}'));
      await container0(
        storage,
      ).read(trustedHostsProvider.notifier).revoke('10.0.0.1:22');

      var prompted = 0;
      final approved = await verifier.verifyHostKey(
        host: '10.0.0.1',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: fingerprint,
        onConfirmFirstTime: (_, _, _) async {
          prompted++;
          return true;
        },
      );
      expect(approved, isTrue);
      expect(prompted, 1, reason: '撤销后必须重新走确认回调');
    });
  });

  group('securitySettingsProvider.clearServerCredentials 严格删除凭据', () {
    test('删除选中服务器的全部本地凭据并断开其连接', () async {
      final storage = await _storageWithTrust(const []);
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p'
        ..values['valhalla_server_alpha_private_key'] = 'k'
        ..values['valhalla_server_alpha_sudo_password'] = 's'
        ..values['valhalla_server_bravo_password'] = 'p2';
      final ssh = _RecordingSshManager(storage);
      final container = _container(storage: storage, secure: secure, ssh: ssh);

      await container.read(securitySettingsProvider).clearServerCredentials([
        'alpha',
      ]);

      expect(
        secure.values.containsKey('valhalla_server_alpha_password'),
        isFalse,
      );
      expect(
        secure.values.containsKey('valhalla_server_alpha_private_key'),
        isFalse,
      );
      expect(
        secure.values.containsKey('valhalla_server_alpha_sudo_password'),
        isFalse,
      );
      expect(
        secure.values['valhalla_server_bravo_password'],
        'p2',
        reason: '未选中的服务器凭据必须保留',
      );
      expect(ssh.disconnected, contains('alpha'));
    });

    test('删除失败必须抛出可识别错误而不是静默成功', () async {
      final storage = await _storageWithTrust(const []);
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p'
        ..failDeletes.add('alpha_password');
      final container = _container(
        storage: storage,
        secure: secure,
        ssh: _RecordingSshManager(storage),
      );

      await expectLater(
        container.read(securitySettingsProvider).clearServerCredentials([
          'alpha',
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'SERVER_CREDENTIALS_CLEAR_FAILED',
          ),
        ),
      );
    });

    test('部分失败时其余服务器仍然完成删除，错误保持可见', () async {
      final storage = await _storageWithTrust(const []);
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p'
        ..values['valhalla_server_bravo_password'] = 'p2'
        ..failDeletes.add('alpha_password');
      final container = _container(
        storage: storage,
        secure: secure,
        ssh: _RecordingSshManager(storage),
      );

      await expectLater(
        container.read(securitySettingsProvider).clearServerCredentials([
          'alpha',
          'bravo',
        ]),
        throwsA(isA<StateError>()),
      );
      expect(secure.cleared, ['alpha', 'bravo']);
      expect(
        secure.values.containsKey('valhalla_server_bravo_password'),
        isFalse,
        reason: '一个失败不能阻止其他选中项完成删除',
      );
    });

    test('未知 serverId 必须在删除任何凭据之前整体拒绝', () async {
      final storage = await _storageWithTrust(const []);
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p';
      final container = _container(
        storage: storage,
        secure: secure,
        ssh: _RecordingSshManager(storage),
      );

      await expectLater(
        container.read(securitySettingsProvider).clearServerCredentials([
          'alpha',
          'ghost',
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'SERVER_NOT_FOUND',
          ),
        ),
      );
      expect(secure.cleared, isEmpty);
      expect(
        secure.values['valhalla_server_alpha_password'],
        'p',
        reason: '校验失败不得留下部分删除',
      );
    });

    test('删除凭据不得触碰服务器配置、活动选择与可信主机', () async {
      final storage = await _storageWithTrust(const ['10.0.0.1:22']);
      await storage.setActiveServerId('alpha');
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p';
      final container = _container(
        storage: storage,
        secure: secure,
        ssh: _RecordingSshManager(storage),
      );

      await container.read(securitySettingsProvider).clearServerCredentials([
        'alpha',
      ]);

      expect(storage.getServers().map((s) => s.id), [
        'alpha',
        'bravo',
        'charlie',
      ], reason: '凭据删除不得删除服务器配置');
      expect(storage.getActiveServerId(), 'alpha');
      expect(storage.getHostKeys().containsKey('10.0.0.1:22'), isTrue);
    });

    test('删除活跃服务器凭据会先断开连接，即使删除随后失败', () async {
      final storage = await _storageWithTrust(const []);
      final secure = _FakeSecureStorage()
        ..values['valhalla_server_alpha_password'] = 'p'
        ..failDeletes.add('alpha_password');
      final ssh = _RecordingSshManager(storage);
      final container = _container(
        storage: storage,
        secure: secure,
        ssh: ssh,
        connection: const ServerConnectionState(
          status: ConnectionStateEnum.connected,
          activeServerId: 'alpha',
        ),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(securitySettingsProvider).clearServerCredentials([
          'alpha',
        ]),
        throwsA(isA<StateError>()),
      );
      expect(ssh.disconnected, isNotEmpty);
    });
  });
}

/// 撤销用例只需要一个最小容器：可信主机读取 + SSH 断开。
ProviderContainer container0(LocalStorageService storage) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(_FakeSecureStorage()),
      sshClientManagerProvider.overrideWithValue(_RecordingSshManager(storage)),
      serverListProvider.overrideWith(
        () => _StaticServerList(const [_alpha, _bravo, _charlie]),
      ),
      serverConnectionProvider.overrideWith(
        () => _StaticConnection(
          const ServerConnectionState(
            status: ConnectionStateEnum.connected,
            activeServerId: 'alpha',
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
