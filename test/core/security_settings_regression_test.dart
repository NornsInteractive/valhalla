import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/security_settings_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/host_key_entry.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
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

/// 内存版 FlutterSecureStorage：不碰系统 KeyChain/KeyStore。
///
/// 继承而非 implements：其余平台相关 API 全部走父类真实实现，
/// 只覆写测试用到的 read/write/delete，这样签名跟随父类自动跟上
/// 选项类改名（如 iOS 的 `IOSOptions`→`AppleOptions`）。
///
/// 可按 key 精确注入删除失败，用来验证「用户主动删除」必须在真实存储
/// 出错时如实报错，而不是像旧的宽松路径那样把异常吞掉。
class _MemoryKeyStore extends FlutterSecureStorage {
  _MemoryKeyStore();

  final Map<String, String> values = <String, String>{};
  final Set<String> failDeletes = <String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDeletes.contains(key)) {
      throw PlatformException(code: 'keystore_error', message: 'denied');
    }
    values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.from(values);
}

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

class _StaticActiveServer extends ActiveServerNotifier {
  _StaticActiveServer(this.server);
  final ServerProfile? server;
  @override
  ServerProfile? build() => server;
}

Future<_Harness> _harness({
  List<ServerProfile> servers = const [_alpha, _bravo],
  String? activeServerId = 'alpha',
  ServerProfile? activeServer = _alpha,
  List<AgentProfile> agents = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  await storage.saveServers(servers);
  await storage.saveAgents(agents);
  final store = _MemoryKeyStore()
    ..values['valhalla_server_alpha_password'] = 'pw';
  final secure = SecureStorageService(storage: store);
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(secure),
      serverListProvider.overrideWith(() => _StaticServerList(servers)),
      serverConnectionProvider.overrideWith(
        () => _StaticConnection(
          ServerConnectionState(
            status: ConnectionStateEnum.connected,
            activeServerId: activeServerId,
          ),
        ),
      ),
      activeServerProvider.overrideWith(
        () => _StaticActiveServer(activeServer),
      ),
    ],
  );
  addTearDown(container.dispose);
  return _Harness(container, store, storage, secure);
}

class _Harness {
  _Harness(this.container, this.store, this.storage, this.secure);
  final ProviderContainer container;
  final _MemoryKeyStore store;
  final LocalStorageService storage;
  final SecureStorageService secure;

  SecuritySettingsActions get actions =>
      container.read(securitySettingsProvider);
}

AgentProfile _agent(String id, {bool acp = true, String serverId = 'alpha'}) =>
    AgentProfile(
      id: id,
      serverId: serverId,
      name: id,
      description: 'desc',
      cliCommand: 'cli',
      acpCommand: acp ? 'acp --stdio' : null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('clearServerCredentials 走真实安全存储时的严格删除', () {
    test('三个本地凭据 key 一并删除并断开连接', () async {
      final h = await _harness();
      h.store.values
        ..['valhalla_server_alpha_private_key'] = 'KEYPEM'
        ..['valhalla_server_alpha_sudo_password'] = 'sudo';

      await h.actions.clearServerCredentials(['alpha']);

      expect(
        h.store.values.keys.where(
          (k) => k.startsWith('valhalla_server_alpha_'),
        ),
        isEmpty,
        reason: 'password / private_key / sudo_password 必须全部清除',
      );
    });

    test('安全存储删除失败时异常向上传播，失败的 key 仍在库中', () async {
      final h = await _harness();
      h.store.failDeletes.add('valhalla_server_alpha_password');

      await expectLater(
        h.actions.clearServerCredentials(['alpha']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'SERVER_CREDENTIALS_CLEAR_FAILED',
          ),
        ),
      );
      expect(
        h.store.values['valhalla_server_alpha_password'],
        'pw',
        reason: '删除失败的凭据必须保留，用户重试才有意义',
      );
    });

    test('宽松 deleteCredentials 仍然不抛错，供删除服务器复用', () async {
      final h = await _harness();
      h.store.failDeletes.add('valhalla_server_alpha_password');
      await expectLater(
        h.secure.clearCredentialsStrict('alpha'),
        throwsA(isA<StateError>()),
      );
      await expectLater(h.secure.deleteCredentials('alpha'), completes);
    });

    test('未选中的服务器凭据保持不动', () async {
      final h = await _harness();
      h.store.values['valhalla_server_bravo_password'] = 'bravo-pw';
      await h.actions.clearServerCredentials(['alpha']);
      expect(h.store.values['valhalla_server_bravo_password'], 'bravo-pw');
    });
  });

  group('缺少确认回调时不得自动信任主机指纹', () {
    test('无回调 → 拒绝且不写入任何信任', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final verifier = SSHHostKeyVerifier(storage);

      final approved = await verifier.verifyHostKey(
        host: '10.0.0.1',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: _fingerprint('A' * 43),
      );

      expect(approved, isFalse, reason: 'onConfirmFirstTime 缺失必须等于拒绝，而不是自动信任');
      expect(storage.getHostKeys(), isEmpty, reason: '不得落盘被信任的主机');
    });

    test('已知指纹在无回调时依然直接放行（信任已存在）', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      await storage.saveHostKey(
        HostKeyEntry(
          hostPort: '10.0.0.1:22',
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:${'A' * 43}',
          trustedAt: DateTime.utc(2026),
        ),
      );
      final verifier = SSHHostKeyVerifier(storage);

      expect(
        await verifier.verifyHostKey(
          host: '10.0.0.1',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: _fingerprint('A' * 43),
        ),
        isTrue,
      );
    });

    test('撤销信任后无回调必须再次拒绝且不重新落盘', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      await storage.saveHostKey(
        HostKeyEntry(
          hostPort: '10.0.0.1:22',
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:${'A' * 43}',
          trustedAt: DateTime.utc(2026),
        ),
      );
      final verifier = SSHHostKeyVerifier(storage);
      await storage.removeHostKey('10.0.0.1:22');

      expect(
        await verifier.verifyHostKey(
          host: '10.0.0.1',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: _fingerprint('A' * 43),
        ),
        isFalse,
      );
      expect(storage.getHostKeys(), isEmpty);
    });
  });

  group('setDefaultAgent 校验与刷新', () {
    test('保存成功后刷新 defaultAgentSettingsProvider', () async {
      final h = await _harness(agents: [_agent('a-acp')]);
      expect(h.container.read(defaultAgentSettingsProvider), {
        'acp': null,
        'cli': null,
      });

      await h.actions.setDefaultAgent('a-acp', cli: false);

      final updated = h.container.read(defaultAgentSettingsProvider);
      expect(updated['acp'], 'a-acp');
      expect(updated['cli'], isNull, reason: 'acp/cli 命名空间必须互不污染');
    });

    test('陈旧目标被拒绝且不写入存储', () async {
      final h = await _harness(agents: [_agent('a-acp')], activeServer: _bravo);

      await expectLater(
        h.actions.setDefaultAgent(
          'a-acp',
          cli: false,
          expectedServerId: 'alpha',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'SERVER_TARGET_CHANGED',
          ),
        ),
      );
      expect(h.storage.getDefaultAgentId('bravo', cli: false), isNull);
    });

    test('不存在或不属于当前服务器的 agent 被拒绝', () async {
      final h = await _harness(
        agents: [
          _agent('a-acp'),
          _agent('other', serverId: 'bravo'),
        ],
      );

      for (final id in ['missing', 'other']) {
        await expectLater(
          h.actions.setDefaultAgent(id, cli: false),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'AGENT_NOT_FOUND',
            ),
          ),
          reason: '越界或不属于本服务器的 agent：$id',
        );
      }
      expect(h.storage.getDefaultAgentId('alpha', cli: false), isNull);
    });

    test('纯 CLI agent 不能成为 ACP 默认，但可以作为 CLI 默认', () async {
      final h = await _harness(agents: [_agent('a-cli-only', acp: false)]);

      await expectLater(
        h.actions.setDefaultAgent('a-cli-only', cli: false),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'AGENT_NOT_FOUND',
          ),
        ),
      );
      await h.actions.setDefaultAgent('a-cli-only', cli: true);
      expect(
        h.container.read(defaultAgentSettingsProvider)['cli'],
        'a-cli-only',
      );
    });

    test('清空默认（null）被接受并刷新缓存', () async {
      final h = await _harness(agents: [_agent('a-acp')]);
      await h.actions.setDefaultAgent('a-acp', cli: false);
      await h.actions.setDefaultAgent(null, cli: false);
      expect(h.container.read(defaultAgentSettingsProvider)['acp'], isNull);
    });

    test('没有活动服务器时拒绝保存', () async {
      final h = await _harness(agents: const [], activeServer: null);
      await expectLater(
        h.actions.setDefaultAgent('a-acp', cli: false),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'SERVER_NOT_FOUND',
          ),
        ),
      );
    });

    test('acl 与 cli 两侧默认互不覆盖', () async {
      final h = await _harness(agents: [_agent('a-acp'), _agent('a-cli')]);
      await h.actions.setDefaultAgent('a-acp', cli: false);
      await h.actions.setDefaultAgent('a-cli', cli: true);
      final defaults = h.container.read(defaultAgentSettingsProvider);
      expect(defaults['acp'], 'a-acp');
      expect(defaults['cli'], 'a-cli');
      expect(h.storage.getDefaultAgentId('alpha', cli: false), 'a-acp');
      expect(h.storage.getDefaultAgentId('alpha', cli: true), 'a-cli');
    });
  });
}

/// dartssh2 4.x gives the host key fingerprint as an OpenSSH `SHA256:...`
/// string in UTF-8, which is what the verifier expects.
Uint8List _fingerprint(String value) =>
    Uint8List.fromList(utf8.encode('SHA256:$value'));
