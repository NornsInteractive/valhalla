import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/agent_update.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/services/configuration_backup_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _cachePrefix = 'valhalla_agent_update_v1';

final String _targetKey = 'a' * 64;

AgentProfile _profile({
  String cliCommand = 'claude',
  String executionTarget = 'host',
  String? containerReference,
  String? containerUser,
}) => AgentProfile(
  id: 'agent-1',
  serverId: 'srv-1',
  name: 'Claude Code',
  description: '',
  cliCommand: cliCommand,
  executionTarget: executionTarget,
  containerReference: containerReference,
  containerUser: containerUser,
);

const ServerProfile _server = ServerProfile(
  id: 'srv-1',
  name: 'prod',
  host: 'a.example.test',
  username: 'root',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Agent 更新缓存键', () {
    test('只有 64 位小写十六进制键可读写', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      await storage.saveAgentUpdateRecord(_targetKey, {'status': 'available'});
      expect(
        prefs.getString('$_cachePrefix::$_targetKey'),
        '{"status":"available"}',
      );
      expect(storage.getAgentUpdateRecord(_targetKey), {'status': 'available'});

      for (final bad in <String>[
        '',
        'a' * 63,
        'a' * 65,
        'A' * 64,
        'z' * 64,
        '$_targetKey::extra',
        '$_targetKey ',
      ]) {
        expect(
          storage.getAgentUpdateRecord(bad),
          isNull,
          reason: '非法键 $bad 必须读不到缓存',
        );
        await expectLater(
          storage.saveAgentUpdateRecord(bad, const {}),
          throwsA(isA<ArgumentError>()),
          reason: '非法键 $bad 必须写不进去',
        );
      }
      expect(
        prefs.getString('$_cachePrefix::$_targetKey'),
        '{"status":"available"}',
      );
    });

    test('agentUpdateTargetKey 稳定且随身份/容器/用户/二进制变化', () {
      final base = agentUpdateTargetKey(_server, _profile());
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(base), isTrue);
      expect(agentUpdateTargetKey(_server, _profile()), base);
      expect(
        agentUpdateTargetKey(
          _server.copyWith(host: 'b.example.test'),
          _profile(),
        ),
        isNot(base),
        reason: '连接目标变化必须换键',
      );
      expect(
        agentUpdateTargetKey(_server, _profile(cliCommand: 'claude-code')),
        isNot(base),
        reason: '安装的二进制变化必须换键',
      );
      expect(
        agentUpdateTargetKey(
          _server,
          _profile(executionTarget: 'docker', containerUser: 'root'),
        ),
        isNot(base),
        reason: '容器与用户变化必须换键',
      );
      expect(
        agentUpdateTargetKey(
          _server,
          _profile(executionTarget: 'docker', containerReference: 'abc123'),
        ),
        isNot(base),
      );
    });
  });

  group('Agent 更新缓存大小', () {
    test('超过 64KB 的记录被拒绝且不落盘，限额内可读回', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final huge = {'blob': 'x' * (64 * 1024)};
      await expectLater(
        storage.saveAgentUpdateRecord(_targetKey, huge),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'AGENT_UPDATE_RECORD_TOO_LARGE',
          ),
        ),
      );
      expect(prefs.containsKey('$_cachePrefix::$_targetKey'), isFalse);

      final ok = {'blob': 'x' * 1024};
      await storage.saveAgentUpdateRecord(_targetKey, ok);
      expect(storage.getAgentUpdateRecord(_targetKey)?['blob'], 'x' * 1024);
    });

    test('存储里超过 64KB 的原始值读作 null', () async {
      final oversized = '{"blob":"${'x' * (64 * 1024)}"}';
      expect(utf8.encode(oversized).length, greaterThan(64 * 1024));
      SharedPreferences.setMockInitialValues({
        '$_cachePrefix::$_targetKey': oversized,
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      expect(storage.getAgentUpdateRecord(_targetKey), isNull);
    });
  });

  group('Agent 更新缓存坏数据', () {
    test('坏 JSON 与非对象 JSON 一律读作 null 而不抛错', () async {
      SharedPreferences.setMockInitialValues({
        '$_cachePrefix::${'b' * 64}': '{"broken":',
        '$_cachePrefix::${'c' * 64}': '[1,2,3]',
        '$_cachePrefix::${'d' * 64}': '"plain string"',
        '$_cachePrefix::${'e' * 64}': '12',
        '$_cachePrefix::${'f' * 64}': '',
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      for (final key in ['b' * 64, 'c' * 64, 'd' * 64, 'e' * 64, 'f' * 64]) {
        expect(
          storage.getAgentUpdateRecord(key),
          isNull,
          reason: '键 $key 的缓存必须被安全丢弃',
        );
      }
      // 同一份存储里合法记录仍可读，证明失败没有殃及全局。
      await storage.saveAgentUpdateRecord('9' * 64, const {
        'status': 'current',
      });
      expect(storage.getAgentUpdateRecord('9' * 64), {'status': 'current'});
    });
  });

  group('Agent 更新缓存不进配置备份', () {
    test('allowlist 不含缓存键，导出文本与导入结果都没有它', () async {
      SharedPreferences.setMockInitialValues({
        '$_cachePrefix::$_targetKey': '{"status":"available"}',
        'valhalla_theme_mode_v1': 'dark',
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );

      expect(
        LocalStorageService.configurationPreferenceTypes.keys,
        isNot(anyElement(startsWith(_cachePrefix))),
        reason: '更新缓存是运行时状态，绝不能进偏好白名单',
      );
      expect(
        storage.exportConfigurationPreferences().keys,
        isNot(anyElement(startsWith(_cachePrefix))),
      );

      final text = ConfigurationBackupService(
        storage,
      ).exportConfiguration().encode();
      expect(text, isNot(contains(_cachePrefix)));
      expect(text, contains('valhalla_theme_mode_v1'));

      SharedPreferences.setMockInitialValues({});
      final target = LocalStorageService(await SharedPreferences.getInstance());
      await ConfigurationBackupService(target).importConfiguration(
        ConfigurationBackupService.decode(text),
        applyPreferences: true,
      );
      expect(target.getAgentUpdateRecord(_targetKey), isNull);
    });
  });
}
