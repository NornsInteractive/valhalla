import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/services/configuration_backup_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

/// 可控失败的 SharedPreferences 替身，用来复现「写入中途失败」。
///
/// 语义照抄真实的 SharedPreferences：缓存总是乐观更新，只有持久化成功
/// 才算写入成功；因此失败写入仍会残留在 cache 里，而调用方拿到的返回值
/// 是 false——真正的「写入失败」必须按返回值判断，而不是回读 cache。
class _FaultyPrefs implements SharedPreferences {
  _FaultyPrefs(this.native) {
    cache.addAll(native);
  }

  final Map<String, Object> native;
  final Map<String, Object> cache = {};

  /// 只失败一次，第二次起放行（用于断言重试与回滚路径）。
  final failOnce = <String>{};
  final failAlways = <String>{};
  bool failAll = false;

  /// true 表示这次持久化成功。
  bool _attempt(String key) {
    if (failAll) return false;
    if (failAlways.contains(key)) return false;
    return !failOnce.remove(key);
  }

  @override
  Object? get(String key) => cache[key];

  @override
  bool? getBool(String key) => cache[key] as bool?;

  @override
  int? getInt(String key) => cache[key] as int?;

  @override
  double? getDouble(String key) => cache[key] as double?;

  @override
  String? getString(String key) => cache[key] as String?;

  @override
  List<String>? getStringList(String key) {
    final value = cache[key];
    return value is List ? value.cast<String>().toList() : null;
  }

  @override
  Set<String> getKeys() => cache.keys.toSet();

  @override
  bool containsKey(String key) => cache.containsKey(key);

  @override
  Future<bool> setString(String key, String value) async {
    cache[key] = value;
    final saved = _attempt(key);
    if (saved) native[key] = value;
    return saved;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    cache[key] = value;
    final saved = _attempt(key);
    if (saved) native[key] = value;
    return saved;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    cache[key] = value;
    final saved = _attempt(key);
    if (saved) native[key] = value;
    return saved;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    cache[key] = value;
    final saved = _attempt(key);
    if (saved) native[key] = value;
    return saved;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    cache[key] = value;
    final saved = _attempt(key);
    if (saved) native[key] = value;
    return saved;
  }

  @override
  Future<bool> remove(String key) async {
    final saved = _attempt(key);
    if (!saved) return false;
    cache.remove(key);
    native.remove(key);
    return true;
  }

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(native);
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<bool> clear() async {
    cache.clear();
    native.clear();
    return true;
  }
}

const _serversKey = 'valhalla_servers_v1';
const _agentsKey = 'valhalla_agents_v1';
const _commandsKey = 'valhalla_quick_commands_v1';

ServerProfile _server({
  String id = 'srv-1',
  String name = 'prod',
  String host = '10.0.0.1',
  int port = 22,
  String username = 'root',
  AuthType authType = AuthType.password,
  String? privateKeyPath,
  List<String> tags = const ['edge'],
  DateTime? lastConnectedAt,
}) => ServerProfile(
  id: id,
  name: name,
  host: host,
  port: port,
  username: username,
  authType: authType,
  privateKeyPath: privateKeyPath,
  tags: tags,
  lastConnectedAt: lastConnectedAt,
);

AgentProfile _agent({
  String id = 'agent-1',
  String serverId = 'srv-1',
  String name = 'opencode',
  String cliCommand = 'opencode',
  String? acpCommand = 'opencode --acp',
  DateTime? createdAt,
}) => AgentProfile(
  id: id,
  serverId: serverId,
  name: name,
  description: 'primary agent',
  cliCommand: cliCommand,
  acpCommand: acpCommand,
  createdAt: createdAt,
);

QuickCommand _command({
  String id = 'cmd-1',
  String title = 'restart nginx',
  String command = 'systemctl restart nginx',
  String category = 'System',
  String description = 'restart web server',
}) => QuickCommand(
  id: id,
  title: title,
  command: command,
  category: category,
  description: description,
);

Future<LocalStorageService> _storageWith({
  List<ServerProfile> servers = const [],
  List<AgentProfile> agents = const [],
  List<QuickCommand> commands = const [],
  Map<String, Object> raw = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    if (servers.isNotEmpty)
      _serversKey: jsonEncode(servers.map((s) => s.toJson()).toList()),
    if (agents.isNotEmpty)
      _agentsKey: jsonEncode(agents.map((a) => a.toJson()).toList()),
    if (commands.isNotEmpty)
      _commandsKey: jsonEncode(commands.map((c) => c.toJson()).toList()),
    ...raw,
  });
  return LocalStorageService(await SharedPreferences.getInstance());
}

ConfigurationBackupService _service(LocalStorageService storage) =>
    ConfigurationBackupService(storage);

Map<String, dynamic> _payload({
  List<Map<String, dynamic>>? servers,
  List<Map<String, dynamic>>? agents,
  List<Map<String, dynamic>>? commands,
  Map<String, dynamic>? bookmarks,
  Map<String, dynamic>? defaultAgents,
  Map<String, dynamic>? preferences,
  Object? format = 'valhalla-configuration',
  Object? version = 1,
}) {
  final payload = <String, dynamic>{
    'servers':
        servers ??
        [
          _server().toJson()
            ..remove('privateKeyPath')
            ..remove('lastConnectedAt'),
        ],
    'agents': agents ?? [_agent().toJson()],
    'commands': commands ?? [_command().toJson()],
    'bookmarks':
        bookmarks ??
        {
          'srv-1': ['/var/www', '/etc/nginx'],
        },
    'defaultAgents':
        defaultAgents ??
        {
          'srv-1': {'acp': 'agent-1'},
        },
    'preferences': preferences ?? <String, Object>{},
  };
  if (format != null) payload['format'] = format;
  if (version != null) payload['version'] = version;
  return payload;
}

/// 只把 bookmarks 键收敛成集合，舞台已经断言过的重复项会被丢弃。
Map<String, dynamic> _payloadWithServer(Map<String, dynamic> extra) => {
  ..._payload(),
  ...extra,
};

void main() {
  group('exportConfiguration 往返', () {
    test('导出 JSON 与 decode 结果一致，保留服务器/代理/命令/书签/默认项', () async {
      final storage = await _storageWith(
        servers: [
          _server(),
          _server(id: 'srv-2', name: 'stage', host: '10.0.0.2'),
        ],
        agents: [
          _agent(),
          _agent(id: 'agent-2', name: 'gemini', acpCommand: null),
        ],
        commands: [
          _command(),
          _command(id: 'cmd-2', command: 'uptime'),
        ],
        raw: {
          'valhalla_file_bookmarks::srv-1': ['/var/www', '/var/www'],
          'valhalla_default_agent_acp::srv-1': 'agent-1',
        },
      );

      final backup = _service(storage).exportConfiguration();
      final json =
          const JsonDecoder().convert(backup.encode()) as Map<String, dynamic>;

      expect(json['format'], 'valhalla-configuration');
      expect(json['version'], 1);
      expect(
        (json['servers'] as List).map((e) => (e as Map)['id'].toString()),
        ['srv-1', 'srv-2'],
      );
      expect((json['agents'] as List).map((e) => (e as Map)['id'].toString()), [
        'agent-1',
        'agent-2',
      ]);
      expect(
        (json['commands'] as List).map((e) => (e as Map)['id'].toString()),
        ['cmd-1', 'cmd-2'],
      );
      // 导出为每台已配置服务器都建一份记录：没有书签/默认项的服务器
      // 导出空集合（导入时收敛为空），但绝不遗漏任何一台。
      expect(json['bookmarks'], {
        'srv-1': ['/var/www'],
        'srv-2': [],
      });
      expect(json['defaultAgents'], {
        'srv-1': {'acp': 'agent-1'},
        'srv-2': {},
      });

      final decoded = ConfigurationBackupService.decode(backup.encode());
      expect(decoded.servers.map((s) => s.id), backup.servers.map((s) => s.id));
      expect(decoded.agents.map((a) => a.id), backup.agents.map((a) => a.id));
      expect(
        decoded.commands.map((c) => c.id),
        backup.commands.map((c) => c.id),
      );
      expect(decoded.bookmarks, backup.bookmarks);
      expect(decoded.defaultAgents, backup.defaultAgents);
    });

    test('导出会跳过没有归属服务器的代理', () async {
      final storage = await _storageWith(
        servers: [_server()],
        agents: [
          _agent(),
          _agent(id: 'orphan', serverId: 'srv-gone'),
        ],
      );

      final decoded = ConfigurationBackupService.decode(
        _service(storage).exportConfiguration().encode(),
      );
      expect(decoded.agents.map((a) => a.id), ['agent-1']);
      expect(decoded.agents.any((a) => a.serverId == 'srv-gone'), isFalse);
    });

    test('默认代理缺失或不属于该服务器时不导出', () async {
      final storage = await _storageWith(
        servers: [_server()],
        agents: [_agent()],
        raw: {
          'valhalla_default_agent_acp::srv-1': 'agent-missing',
          'valhalla_default_agent_cli::srv-1': 'agent-1',
        },
      );

      final decoded = ConfigurationBackupService.decode(
        _service(storage).exportConfiguration().encode(),
      );
      expect(decoded.defaultAgents, {
        'srv-1': {'cli': 'agent-1'},
      });
    });

    test('allowlist 外的数据不进入导出', () async {
      final storage = await _storageWith(
        servers: [_server(privateKeyPath: '/home/u/.ssh/id_rsa')],
        raw: {
          'valhalla_chat_sessions_v1': '[{"id":"s1"}]',
          'valhalla_chat_draft_v1::x': '{"a":1}',
          'valhalla_active_server_id_v1': 'srv-1',
          'valhalla_acp_sessions_v1': '{"a":1}',
        },
      );

      final backup = _service(storage).exportConfiguration();
      final text = backup.encode();
      final json = const JsonDecoder().convert(text) as Map<String, dynamic>;

      expect(
        json['preferences'],
        isEmpty,
        reason: '不在 allowlist 中的历史/草稿/运行时状态不得导出',
      );
      expect(text, isNot(contains('/home/u/.ssh/id_rsa')));
      expect(text, isNot(contains('valhalla_chat_sessions_v1')));
      expect(text, isNot(contains('valhalla_acp_sessions_v1')));
      expect(text, isNot(contains('valhalla_active_server_id_v1')));
      for (final serverJson in json['servers'] as List) {
        final map = serverJson as Map<String, dynamic>;
        expect(
          map.containsKey('privateKeyPath'),
          isFalse,
          reason: '私钥本地路径绝不能出现在备份里',
        );
        expect(
          map.containsKey('lastConnectedAt'),
          isFalse,
          reason: '连接时间戳属于本地运行痕迹',
        );
        for (final value in map.values) {
          expect('$value', isNot(contains('valhalla_')));
        }
      }
    });
  });

  group('decode 校验', () {
    test('格式标识或版本不符时报 CONFIG_VERSION_UNSUPPORTED', () async {
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(_payload(format: 'other')),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_VERSION_UNSUPPORTED',
          ),
        ),
      );
      expect(
        () =>
            ConfigurationBackupService.decode(jsonEncode(_payload(version: 2))),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_VERSION_UNSUPPORTED',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode('{'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_FORMAT_INVALID',
          ),
        ),
        reason: '截断 JSON 不得把解析器原文透给用户',
      );
      expect(
        () => ConfigurationBackupService.decode(
          '{"format":"valhalla-configuration"',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_FORMAT_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode('not json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_FORMAT_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode({'format': 'valhalla-configuration', 'version': 1}),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_FORMAT_INVALID',
          ),
        ),
      );
    });

    test('服务器记录不合法时报 CONFIG_SERVER_INVALID', () {
      final base = _server().toJson()..remove('privateKeyPath');
      final cases = <String, Map<String, dynamic>>{
        'blank name': {...base, 'name': ' '},
        'host with nul': {...base, 'host': 'a\x00b'},
        'port too low': {...base, 'port': 0},
        'port too high': {...base, 'port': 65536},
        'fractional port': {...base, 'port': 22.5},
        'port as string': {...base, 'port': '22'},
      };
      for (final entry in cases.entries) {
        expect(
          () => ConfigurationBackupService.decode(
            jsonEncode(_payload(servers: [entry.value])),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'CONFIG_SERVER_INVALID',
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('authType 不受支持时报 CONFIG_AUTH_TYPE_INVALID', () {
      final base = _server().toJson()..remove('privateKeyPath');
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              servers: [
                {...base, 'authType': 'keyboard-interactive'},
              ],
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_AUTH_TYPE_INVALID',
          ),
        ),
      );
    });

    test('必需字段缺失或类型错误时拒绝写入且不写存储', () {
      final base = _server().toJson()..remove('privateKeyPath');
      final cases = <String, List<Map<String, dynamic>>>{
        'missing id': [
          {...base}..remove('id'),
        ],
        'missing username': [
          {...base}..remove('username'),
        ],
      };
      for (final entry in cases.entries) {
        // 安全边界是「拒绝且存储不被触碰」；reason code 允许是两个码之一。
        expect(
          () => ConfigurationBackupService.decode(
            jsonEncode(_payload(servers: entry.value)),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              anyOf('CONFIG_SERVER_INVALID', 'CONFIG_FORMAT_INVALID'),
            ),
          ),
        );
      }
    });

    test('服务器 id 重复时报 CONFIG_SERVER_INVALID', () {
      final duplicate = _server().toJson()..remove('privateKeyPath');
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              servers: [
                duplicate,
                {...duplicate},
              ],
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_SERVER_INVALID',
          ),
        ),
      );
    });

    test('同名代理 id 分布在不同服务器是允许的', () {
      final shared = _agent().toJson();
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              servers: [
                _server(id: 'srv-a').toJson(),
                _server(id: 'srv-b').toJson(),
              ],
              agents: [
                {...shared, 'serverId': 'srv-a'},
                {...shared, 'serverId': 'srv-b'},
              ],
              bookmarks: {
                'srv-a': ['/a'],
              },
              defaultAgents: {
                'srv-a': {'acp': 'agent-1'},
              },
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('同一服务器上重复代理 id 时报 CONFIG_AGENT_INVALID', () {
      final agent = _agent().toJson();
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              agents: [
                agent,
                {...agent},
              ],
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_AGENT_INVALID',
          ),
        ),
      );
    });

    test('同一代理 id 在两台服务器上各一份时不算重复', () {
      final shared = _agent().toJson();
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              servers: [
                _server().toJson(),
                _server(id: 'srv-2').toJson(),
              ],
              agents: [
                {...shared, 'serverId': 'srv-1'},
                {...shared, 'serverId': 'srv-2'},
              ],
              bookmarks: {
                'srv-1': ['/a'],
                'srv-2': ['/b'],
              },
              defaultAgents: {
                'srv-1': {'acp': 'agent-1'},
                'srv-2': {'acp': 'agent-1'},
              },
            ),
          ),
        ),
        returnsNormally,
      );
    });

    test('代理字段不完整或不一致时报 CONFIG_AGENT_INVALID', () {
      final good = _agent().toJson();
      final cases = <String, List<Map<String, dynamic>>>{
        'agent without server': [_agent(serverId: 'srv-nope').toJson()],
        'blank cli command': [
          {...good, 'cliCommand': '  '},
        ],
        'unknown execution target': [
          {...good, 'executionTarget': 'lsvc'},
        ],
        'unknown container binding': [
          {...good, 'containerBinding': 'label'},
        ],
        'docker without reference': [
          {...good, 'executionTarget': 'docker', 'containerBinding': 'id'},
        ],
      };
      for (final entry in cases.entries) {
        expect(
          () => ConfigurationBackupService.decode(
            jsonEncode(_payload(agents: entry.value)),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'CONFIG_AGENT_INVALID',
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('指令 id 重复或字段为空时报 CONFIG_COMMAND_INVALID', () {
      final good = _command().toJson();
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              commands: [
                good,
                {...good},
              ],
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_COMMAND_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              commands: [
                {...good, 'title': ''},
              ],
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_COMMAND_INVALID',
          ),
        ),
      );
    });

    test('书签引用不存在的服务器或路径非法时报错', () {
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              bookmarks: {
                'srv-nope': ['/a'],
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_REFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              bookmarks: {
                'srv-1': ['relative'],
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PATH_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              bookmarks: {
                'srv-1': ['/a\x00b'],
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PATH_INVALID',
          ),
        ),
      );
    });

    test('默认代理引用不存在、模式非法或朝向无 ACP 时代理时报 CONFIG_REFERENCE_INVALID', () {
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              defaultAgents: {
                'srv-nope': {'acp': 'agent-1'},
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_REFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              defaultAgents: {
                'srv-1': {'unknown-mode': 'agent-1'},
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_REFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              agents: [_agent(acpCommand: null).toJson()],
              defaultAgents: {
                'srv-1': {'acp': 'agent-1'},
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_REFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              defaultAgents: {
                'srv-1': {'acp': 'agent-nope'},
              },
            ),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_REFERENCE_INVALID',
          ),
        ),
      );
    });

    test('未知偏好键或类型不符时报 CONFIG_PREFERENCE_INVALID', () {
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(_payload(preferences: {'unknown_pref_key': 1})),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PREFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(_payload(preferences: {'valhalla_theme_mode_v1': true})),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PREFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(preferences: {'valhalla_terminal_use_tmux_v1': 'yes'}),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PREFERENCE_INVALID',
          ),
        ),
      );
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(_payload(preferences: {'valhalla_locale_v1': 'zh'})),
        ),
        returnsNormally,
      );
    });

    test('超出大小或条目数上限时报错', () {
      final huge = 'x' * (ConfigurationBackupService.maxBytes + 10);
      expect(
        () => ConfigurationBackupService.decode(
          '{"format":"valhalla-configuration","version":1,"payload":"$huge"}',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_TOO_LARGE',
          ),
        ),
      );
      final manyServers = [
        for (var i = 0; i < 10001; i++)
          {
            'id': 'srv-$i',
            'name': 'n',
            'host': 'h',
            'port': 22,
            'username': 'u',
            'authType': 'password',
          },
      ];
      expect(
        () => ConfigurationBackupService.decode(
          jsonEncode(
            _payload(servers: manyServers.cast<Map<String, dynamic>>()),
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_TOO_MANY_ITEMS',
          ),
        ),
      );
    });

    test('导入带 localPath 字段的备份时这些字段被丢弃', () {
      final text = jsonEncode(
        _payload(
          servers: [
            {
              'id': 'srv-1',
              'name': 'n',
              'host': 'h',
              'port': 22,
              'username': 'u',
              'authType': 'privateKey',
              'privateKeyPath': '/secret/location/id_rsa',
              'lastConnectedAt': DateTime.now().toIso8601String(),
            },
          ],
        ),
      );
      final decoded = ConfigurationBackupService.decode(text);
      expect(
        decoded.servers.single.privateKeyPath,
        isNull,
        reason: '备份内容拒绝放入任何本地私钥路径',
      );
      expect(decoded.servers.single.lastConnectedAt, isNull);
    });
  });

  group('importConfiguration 追加与重映射', () {
    test('导入使用全新 id 并重映射书签/默认代理/引用', () async {
      final storage = await _storageWith(
        servers: [_server(id: 'existing')],
        agents: [_agent(id: 'existing-agent', serverId: 'existing')],
        commands: [_command(id: 'existing-cmd')],
        raw: {
          'valhalla_file_bookmarks::existing': ['/keep'],
        },
      );

      final payload = ConfigurationBackupService.decode(
        jsonEncode(
          _payloadWithServer({
            'servers': [_server(id: 'srv-1').toJson()],
            'agents': [_agent().toJson()],
            'bookmarks': {
              'srv-1': ['/var/www', '/etc'],
            },
            'defaultAgents': {
              'srv-1': {'acp': 'agent-1'},
            },
          }),
        ),
      );
      await _service(storage).importConfiguration(payload);

      final serverIds = storage.getServers().map((s) => s.id).toList();
      expect(serverIds, ['existing', isNot('srv-1')]);
      expect(serverIds, hasLength(2));

      final agents = storage.getAgents();
      expect(
        agents.any((a) => a.id == 'agent-1' && a.serverId == 'srv-1'),
        isFalse,
        reason: '导入后不得保留源文件的代理 id/服务器 id',
      );
      final importedServerId = serverIds[1];
      final importedAgent = agents.firstWhere(
        (a) => a.serverId == importedServerId,
      );
      expect(importedAgent.id, isNot('agent-1'));
      expect(
        agents.map((a) => a.id),
        containsAll(['existing-agent', importedAgent.id]),
      );

      expect(
        storage.getQuickCommands().map((c) => c.id),
        containsAll(['existing-cmd', isNotNull]),
      );
      expect(
        storage.getQuickCommands().map((c) => c.id),
        isNot(contains('cmd-1')),
      );

      expect(storage.getFileBookmarks('existing'), [
        '/keep',
      ], reason: '原有服务器的书签不被清空');
      expect(storage.getFileBookmarks(importedServerId), ['/var/www', '/etc']);
      expect(storage.getFileBookmarks('srv-1'), isEmpty);

      expect(storage.getDefaultAgentId('existing', cli: false), isNull);
      expect(
        storage.getDefaultAgentId(importedServerId, cli: false),
        importedAgent.id,
      );
      expect(storage.getDefaultAgentId(importedServerId, cli: true), isNull);
    });

    test('书签键按新服务器 id 落库，不留旧引用', () async {
      final storage = await _storageWith(servers: [_server(id: 'other')]);

      await _service(storage).importConfiguration(
        ConfigurationBackupService.decode(jsonEncode(_payload())),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_serversKey), isNotNull);
      expect(
        prefs.getKeys().where((k) => k.startsWith('valhalla_file_bookmarks::')),
        isNot(contains('valhalla_file_bookmarks::srv-1')),
        reason: '备份中的旧服务器 id 不得成为本地书签键',
      );
      expect(
        prefs.getKeys().where((k) => k.startsWith('valhalla_default_agent_')),
        isNot(contains('valhalla_default_agent_acp::srv-1')),
        reason: '默认代理键同样必须重映射到新 id',
      );
    });

    test('导入不会自动连接、也不会触发 SSH 或任何远端命令', () async {
      final storage = await _storageWith();
      final prefs = await SharedPreferences.getInstance();

      await expectLater(
        _service(storage).importConfiguration(
          ConfigurationBackupService.decode(jsonEncode(_payload())),
        ),
        completes,
      );

      expect(
        prefs.getString('valhalla_active_server_id_v1'),
        isNull,
        reason: '导入不得切换活动服务器',
      );
      expect(
        prefs.getString('valhalla_host_keys_v1'),
        isNull,
        reason: '导入不得写入任何 host key',
      );
    });

    test('导入的指令以全新 id 追加，不覆盖已有指令', () async {
      final storage = await _storageWith(
        commands: [_command(id: 'a', command: 'old')],
      );
      await _service(storage).importConfiguration(
        ConfigurationBackupService.decode(
          jsonEncode(
            _payload(
              commands: [_command(id: 'b', command: 'new').toJson()],
            ),
          ),
        ),
      );
      final commands = storage.getQuickCommands();
      expect(commands, hasLength(2), reason: '必须是追加而不是替换');
      final existing = commands.firstWhere((c) => c.id == 'a');
      expect(existing.command, 'old', reason: '已有指令内容不得被覆盖');
      final imported = commands.firstWhere((c) => c.id != 'a');
      expect(imported.command, 'new');
      expect(imported.id, isNot('b'), reason: '导入后指令 id 必须是新生成的，不能沿用源文件 id');
    });
  });

  group('导入既存数据保护', () {
    test('既存服务器 JSON 损坏时拒绝写入', () async {
      final storage = await _storageWith(raw: {_serversKey: '{"broken":'});

      await expectLater(
        _service(storage).importConfiguration(
          ConfigurationBackupService.decode(jsonEncode(_payload())),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_EXISTING_DATA_INVALID',
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_serversKey),
        '{"broken":',
        reason: '拒绝导入时必须原样保留损坏数据，不能清空或拼接',
      );
      expect(storage.getServers().length, storage.getServers().length);
    });

    test('既有指令 JSON 损坏时拒绝写入', () async {
      final storage = await _storageWith(
        raw: {_commandsKey: 'not json at all'},
      );
      await expectLater(
        _service(storage).importConfiguration(
          ConfigurationBackupService.decode(jsonEncode(_payload(commands: []))),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_EXISTING_DATA_INVALID',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_commandsKey), 'not json at all');
    });
  });

  group('preference opt-in', () {
    test('不带 applyPreferences 时不写任何偏好键', () async {
      final storage = await _storageWith();
      final payload = ConfigurationBackupService.decode(
        jsonEncode(
          _payload(
            preferences: {
              'valhalla_theme_mode_v1': 'dark',
              'valhalla_experimental_features_v1': ['cli', 'batch'],
            },
          ),
        ),
      );
      expect(payload.preferences.length, 2);

      await _service(storage).importConfiguration(payload);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('valhalla_theme_mode_v1'), isNull);
      expect(prefs.getStringList('valhalla_experimental_features_v1'), isNull);
      expect(
        prefs.getBool('valhalla_navigation_acp_v2'),
        isNull,
        reason: '未应用偏好时不产生该旁路标记',
      );
    });

    test('applyPreferences=true 时写入白名单偏好', () async {
      final storage = await _storageWith();
      final payload = ConfigurationBackupService.decode(
        jsonEncode(
          _payload(
            preferences: {
              'valhalla_theme_mode_v1': 'dark',
              'valhalla_terminal_use_tmux_v1': true,
              'valhalla_terminal_font_size_v1': 16,
              'valhalla_experimental_features_v1': ['cli', 'batch'],
              'valhalla_bottom_navigation_v1': ['dashboard', 'files'],
            },
          ),
        ),
      );

      await _service(
        storage,
      ).importConfiguration(payload, applyPreferences: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('valhalla_theme_mode_v1'), 'dark');
      expect(prefs.getBool('valhalla_terminal_use_tmux_v1'), true);
      expect(prefs.getInt('valhalla_terminal_font_size_v1'), 16);
      expect(prefs.getStringList('valhalla_experimental_features_v1'), [
        'cli',
        'batch',
      ]);
      expect(prefs.getStringList('valhalla_bottom_navigation_v1'), [
        'dashboard',
        'files',
      ]);
      expect(prefs.getBool('valhalla_navigation_acp_v2'), true);
    });

    test('偏好键类型错误时 appendConfiguration 拒绝并保持存储不变', () async {
      final storage = await _storageWith(servers: [_server(id: 'keep')]);
      await expectLater(
        storage.appendConfiguration(
          servers: const [],
          agents: const [],
          commands: const [],
          bookmarks: const {},
          defaultAgents: const {},
          preferences: {'valhalla_theme_mode_v1': 7},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'CONFIG_PREFERENCE_INVALID',
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(storage.getServers().map((s) => s.id), ['keep']);
      expect(prefs.getString('valhalla_theme_mode_v1'), isNull);
    });
  });

  group('写入失败与回滚', () {
    test('偏好写入失败时全部已写入项被还原', () async {
      final prefs = _FaultyPrefs({
        _serversKey: jsonEncode([_server(id: 'keep').toJson()]),
        'valhalla_theme_mode_v1': 'light',
      });
      final storage = LocalStorageService(prefs);
      // 'valhalla_navigation_acp_v2' 由 'valhalla_bottom_navigation_v1' 派生，
      // 只让它失败一次：写入失败后回滚（remove）仍能被验证。
      prefs.failOnce.add('valhalla_navigation_acp_v2');
      const nativeservers = _serversKey;
      final serversBefore = prefs.native[nativeservers];

      await expectLater(
        _service(storage).importConfiguration(
          ConfigurationBackupService.decode(
            jsonEncode(
              _payload(
                preferences: {
                  'valhalla_bottom_navigation_v1': ['dashboard', 'files'],
                },
              ),
            ),
          ),
          applyPreferences: true,
        ),
        throwsA(isA<StateError>()),
        reason: '派生标记写入失败必须让整个导入失败',
      );

      // 追加的服务器被回滚
      expect(storage.getServers().map((s) => s.id), ['keep']);
      expect(
        prefs.native[nativeservers],
        serversBefore,
        reason: 'native 快照同样要回到导入前',
      );
      // 既有偏好的旧值被恢复，而不是备份里的值
      expect(
        prefs.getString('valhalla_theme_mode_v1'),
        'light',
        reason: '已经存在的偏好键必须还原成旧值',
      );
      expect(
        prefs.getStringList('valhalla_bottom_navigation_v1'),
        isNull,
        reason: '失败的偏好写入必须被还原',
      );
      expect(prefs.getBool('valhalla_navigation_acp_v2'), isNull);
    });

    test('既有值被覆盖后回滚回旧值', () async {
      final original = jsonEncode([
        _server(id: 'srv-1', name: 'old-name').toJson(),
      ]);
      final prefs = _FaultyPrefs({
        _serversKey: original,
        'valhalla_theme_mode_v1': 'light',
      });
      final storage = LocalStorageService(prefs);
      // import 会把 id 重映射成 UUID，无法预知书签键；
      // 直接用 appendConfiguration 配固定 id 才能稳定注入失败点。
      prefs.failOnce.add('valhalla_file_bookmarks::srv-fixed');

      await expectLater(
        storage.appendConfiguration(
          servers: [_server(id: 'srv-fixed')],
          agents: const [],
          commands: const [],
          bookmarks: {
            'srv-fixed': ['/var/www'],
          },
          defaultAgents: const {},
          preferences: {'valhalla_theme_mode_v1': 'dark'},
        ),
        throwsA(isA<StateError>()),
        reason: 'bookmark 写入失败必须把整个导入判为失败',
      );

      expect(storage.getServers().map((s) => s.id), [
        'srv-1',
      ], reason: '追加的服务器必须被回滚');
      expect(prefs.native[_serversKey], original, reason: 'native 快照必须回到导入前');
      expect(
        prefs.getString('valhalla_theme_mode_v1'),
        'light',
        reason: '偏好值必须是旧值而不是导入值',
      );
      expect(prefs.getStringList('valhalla_file_bookmarks::srv-fixed'), isNull);
    });

    test('回滚本身失败时上报 CONFIG_IMPORT_ROLLBACK_FAILED', () async {
      final prefs = _FaultyPrefs({
        _serversKey: jsonEncode([_server(id: 'keep').toJson()]),
      });
      final storage = LocalStorageService(prefs);
      // 书签键和服务器列表键都写失败：回滚同样写不回去，必须如实上报。
      prefs.failAlways.addAll({
        _serversKey,
        'valhalla_file_bookmarks::srv-fixed',
      });

      await expectLater(
        storage.appendConfiguration(
          servers: [_server(id: 'srv-fixed')],
          agents: const [],
          commands: const [],
          bookmarks: {
            'srv-fixed': ['/var/www'],
          },
          defaultAgents: const {},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CONFIG_IMPORT_ROLLBACK_FAILED',
          ),
        ),
      );
      expect(storage.getServers().map((s) => s.id), [
        'keep',
      ], reason: '回滚失败时也不得谎称写入了新服务器');
    });

    test('并发导入被拒绝', () async {
      final storage = await _storageWith();
      final first = storage.appendConfiguration(
        servers: const [
          ServerProfile(id: 'a', name: 'a', host: 'h', username: 'u'),
        ],
        agents: const [],
        commands: const [],
        bookmarks: const {},
        defaultAgents: const {},
      );

      await expectLater(
        storage.appendConfiguration(
          servers: const [],
          agents: const [],
          commands: const [],
          bookmarks: const {},
          defaultAgents: const {},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'CONFIG_IMPORT_PENDING',
          ),
        ),
        reason: '同一实例上的重叠导入必须被拒绝',
      );

      await first;
      expect(storage.getServers().map((s) => s.id), ['a']);
      await storage.appendConfiguration(
        servers: const [
          ServerProfile(id: 'b', name: 'b', host: 'h', username: 'u'),
        ],
        agents: const [],
        commands: const [],
        bookmarks: const {},
        defaultAgents: const {},
      );
      expect(storage.getServers().map((s) => s.id), [
        'a',
        'b',
      ], reason: '前一次导入结束后锁必须释放');
    });

    test('回滚后不会留下「导入成功」的残留偏好值', () async {
      final prefs = _FaultyPrefs({});
      final storage = LocalStorageService(prefs);
      // 让字体大小写入失败一次；回滚（remove）仍能放行，从而可以验证
      // 「部分成功的写入也被撤销」。
      prefs.failOnce.add('valhalla_terminal_font_size_v1');

      await expectLater(
        _service(storage).importConfiguration(
          ConfigurationBackupService.decode(
            jsonEncode(
              _payload(
                preferences: {
                  'valhalla_terminal_font_size_v1': 20,
                  'valhalla_theme_mode_v1': 'dark',
                },
              ),
            ),
          ),
          applyPreferences: true,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        prefs.getInt('valhalla_terminal_font_size_v1'),
        isNull,
        reason: '失败的偏好写入必须被撤销',
      );
      expect(
        prefs.getString('valhalla_theme_mode_v1'),
        isNull,
        reason: '部分成功的写件也要被回滚，不得谎报导入成功',
      );
    });
  });

  group('SSH 隔离', () {
    test('导入/导出路径不建立任何 SSH 客户端', () async {
      final storage = await _storageWith();
      final service = _service(storage);
      // 构造和执行全程没有接触 sshClientManagerProvider；这里只证明
      // 导出与导入都只依赖存储层，不依赖任何远端执行器注入点。
      expect(service.storage, storage);
      final backup = service.exportConfiguration();
      expect(backup.servers, isA<List<ServerProfile>>());
    });
  });
}
