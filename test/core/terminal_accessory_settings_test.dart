import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _v1Key = 'valhalla_terminal_pinned_keys_v1';
const _v2Key = 'valhalla_terminal_accessory_v2';
const _color = 0xFF112233;

/// 新记录只有一条，写失败必须整条不落盘：替身让写盘抛错。
class _FailingAccessoryStorage extends LocalStorageService {
  _FailingAccessoryStorage(super.prefs);

  @override
  Future<void> setTerminalAccessorySettings({
    required List<String> pinnedKeys,
    required String directionPadMode,
    required int? directionKeySeedColorValue,
  }) async {
    throw StateError('fixture failed save');
  }
}

Future<ProviderContainer> _container({LocalStorageService? storage}) async {
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(
        storage ?? LocalStorageService(await SharedPreferences.getInstance()),
      ),
    ],
  );
}

Future<LocalStorageService> _storage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

/// 种子数据后读一次初始状态，随即销毁容器（模拟刚启动时的一次读取）。
Future<TerminalSettings> _readSettingsWith(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final container = await _container();
  final settings = container.read(terminalSettingsProvider);
  container.dispose();
  return settings;
}

String _v2Record(
  List<String> pinnedKeys,
  String directionPadMode,
  Object? directionKeySeedColorValue,
) => jsonEncode({
  'pinnedKeys': pinnedKeys,
  'directionPadMode': directionPadMode,
  'directionKeySeedColorValue': directionKeySeedColorValue,
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('新安装（磁盘上没有任何终端记录）', () {
    test('方向区默认 fixed，颜色为空，默认列表不含脏状态', () async {
      final container = await _container();
      final settings = container.read(terminalSettingsProvider);

      expect(settings.pinnedKeys, TerminalSettings.defaultPinnedKeys);
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(_v2Key), isNull, reason: '首次读取不得凭空写出 v2 记录');
      container.dispose();
    });
  });

  group('只有旧 v1 记录时的自动推导', () {
    test('v1 含 ARROWS → fixed，列表与顺序原样', () async {
      final settings = await _readSettingsWith({
        _v1Key: ['ESC', 'ARROWS', 'HOME'],
      });

      expect(settings.pinnedKeys, ['ESC', 'ARROWS', 'HOME']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(_v2Key), isNull, reason: '读取旧配置不得写入新记录');
    });

    test('v1 不含 ARROWS → hidden，旧列表（含单个箭头）原样保留', () async {
      final settings = await _readSettingsWith({
        _v1Key: ['HOME', '↑', 'ESC', '↓'],
      });

      expect(settings.pinnedKeys, ['HOME', '↑', 'ESC', '↓']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.hidden);
      expect(settings.directionKeySeedColorValue, isNull);
    });

    test('v1 显式存过空列表 → hidden 且仍为空，不落回默认', () async {
      final settings = await _readSettingsWith({_v1Key: <String>[]});

      expect(settings.pinnedKeys, isEmpty);
      expect(settings.directionPadMode, TerminalDirectionPadMode.hidden);
    });
  });

  group('setAccessorySettings', () {
    test('fixed / flow / hidden 三种模式分别落盘并跨重启读回', () async {
      for (final mode in TerminalDirectionPadMode.values) {
        SharedPreferences.setMockInitialValues({});
        final first = await _container();
        await first
            .read(terminalSettingsProvider.notifier)
            .setAccessorySettings(
              pinnedKeys: ['ESC', 'ARROWS'],
              directionPadMode: mode,
              directionKeySeedColorValue: null,
            );
        expect(first.read(terminalSettingsProvider).directionPadMode, mode);
        first.dispose();

        final second = await _container();
        expect(
          second.read(terminalSettingsProvider).directionPadMode,
          mode,
          reason: '${mode.name} 必须跨重启保留',
        );
        second.dispose();

        final prefs = await SharedPreferences.getInstance();
        expect(
          (jsonDecode(prefs.getString(_v2Key)!)
              as Map<String, dynamic>)['directionPadMode'],
          mode.name,
        );
      }
    });

    test('设置颜色与清除颜色都跨重启保留', () async {
      final first = await _container();
      await first
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: ['ARROWS', 'ESC'],
            directionPadMode: TerminalDirectionPadMode.flow,
            directionKeySeedColorValue: _color,
          );
      expect(
        first.read(terminalSettingsProvider).directionKeySeedColorValue,
        _color,
      );
      first.dispose();

      final second = await _container();
      final restored = second.read(terminalSettingsProvider);
      expect(restored.directionKeySeedColorValue, _color);
      expect(restored.directionPadMode, TerminalDirectionPadMode.flow);

      await second
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: ['ARROWS', 'ESC'],
            directionPadMode: TerminalDirectionPadMode.flow,
            directionKeySeedColorValue: null,
          );
      expect(
        second.read(terminalSettingsProvider).directionKeySeedColorValue,
        isNull,
        reason: '传 null 必须清掉颜色，而不是保留旧值',
      );
      second.dispose();

      final third = await _container();
      final cleared = third.read(terminalSettingsProvider);
      expect(cleared.directionKeySeedColorValue, isNull);
      expect(cleared.directionPadMode, TerminalDirectionPadMode.flow);
      third.dispose();

      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(_v2Key)!)
            as Map<String, dynamic>)['directionKeySeedColorValue'],
        isNull,
      );
    });

    test('顺序与单个箭头跨重启原样保留', () async {
      const order = ['HOME', '↑', 'ESC', 'ARROWS', '↓', 'TAB'];

      final first = await _container();
      await first
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: order,
            directionPadMode: TerminalDirectionPadMode.fixed,
            directionKeySeedColorValue: _color,
          );
      expect(first.read(terminalSettingsProvider).pinnedKeys, order);
      first.dispose();

      final second = await _container();
      final settings = second.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, order, reason: '自定义顺序必须跨重启原样读回');
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, _color);
      second.dispose();
    });
  });

  group('setPinnedKeys 旧 API 兼容', () {
    test('移除 ARROWS 转 hidden，重新添加转 fixed，颜色全程保留', () async {
      final first = await _container();
      await first
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: ['ESC', 'ARROWS'],
            directionPadMode: TerminalDirectionPadMode.flow,
            directionKeySeedColorValue: _color,
          );

      await first.read(terminalSettingsProvider.notifier).setPinnedKeys([
        'ESC',
      ]);
      var settings = first.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, ['ESC']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.hidden);
      expect(settings.directionKeySeedColorValue, _color);
      first.dispose();

      final second = await _container();
      settings = second.read(terminalSettingsProvider);
      expect(settings.directionPadMode, TerminalDirectionPadMode.hidden);
      expect(settings.directionKeySeedColorValue, _color);

      await second.read(terminalSettingsProvider.notifier).setPinnedKeys([
        'ESC',
        'ARROWS',
      ]);
      settings = second.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, ['ESC', 'ARROWS']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, _color);
      second.dispose();

      final third = await _container();
      settings = third.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, ['ESC', 'ARROWS']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, _color);
      third.dispose();
    });

    test('已选 flow 时带着 ARROWS 重存不被扳回 fixed，颜色不清', () async {
      final container = await _container();
      await container
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: ['ESC', 'ARROWS'],
            directionPadMode: TerminalDirectionPadMode.flow,
            directionKeySeedColorValue: _color,
          );

      await container.read(terminalSettingsProvider.notifier).setPinnedKeys([
        'ARROWS',
        'ESC',
      ]);

      final settings = container.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, ['ARROWS', 'ESC']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.flow);
      expect(settings.directionKeySeedColorValue, _color);
      container.dispose();
    });
  });

  group('单记录写失败的原子性', () {
    test('setAccessorySettings 写盘失败时内存与磁盘都不变', () async {
      SharedPreferences.setMockInitialValues({
        _v1Key: ['ESC', 'ARROWS'],
        _v2Key: _v2Record(['ESC', 'ARROWS'], 'flow', _color),
      });
      final prefs = await SharedPreferences.getInstance();
      final rawBefore = prefs.getString(_v2Key);
      final container = await _container(
        storage: _FailingAccessoryStorage(prefs),
      );
      final before = container.read(terminalSettingsProvider);
      expect(before.directionPadMode, TerminalDirectionPadMode.flow);

      await expectLater(
        container
            .read(terminalSettingsProvider.notifier)
            .setAccessorySettings(
              pinnedKeys: ['TAB'],
              directionPadMode: TerminalDirectionPadMode.hidden,
              directionKeySeedColorValue: null,
            ),
        throwsStateError,
      );

      final after = container.read(terminalSettingsProvider);
      expect(after.pinnedKeys, before.pinnedKeys);
      expect(after.directionPadMode, TerminalDirectionPadMode.flow);
      expect(after.directionKeySeedColorValue, _color);
      expect(prefs.getString(_v2Key), rawBefore, reason: '失败的写不得留下半条记录');
      container.dispose();
    });

    test('setPinnedKeys 走同一道写盘闸门，失败同样不改内存', () async {
      SharedPreferences.setMockInitialValues({
        _v1Key: ['ESC', 'ARROWS'],
        _v2Key: _v2Record(['ESC', 'ARROWS'], 'fixed', null),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = await _container(
        storage: _FailingAccessoryStorage(prefs),
      );

      await expectLater(
        container.read(terminalSettingsProvider.notifier).setPinnedKeys([
          'TAB',
        ]),
        throwsStateError,
      );

      final after = container.read(terminalSettingsProvider);
      expect(after.pinnedKeys, ['ESC', 'ARROWS']);
      expect(after.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(after.directionKeySeedColorValue, isNull);
      container.dispose();
    });
  });

  group('v2 记录损坏时回退旧 v1 列表', () {
    test('坏 JSON 回退 v1，含 ARROWS 即 fixed', () async {
      final settings = await _readSettingsWith({
        _v2Key: '{not json',
        _v1Key: ['ESC', 'ARROWS', 'HOME'],
      });

      expect(settings.pinnedKeys, ['ESC', 'ARROWS', 'HOME']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(settings.directionKeySeedColorValue, isNull);
    });

    test('非法模式回退 v1', () async {
      final settings = await _readSettingsWith({
        _v2Key: _v2Record(['ESC'], 'upside-down', null),
        _v1Key: ['ESC', 'TAB'],
      });

      expect(settings.pinnedKeys, ['ESC', 'TAB']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.hidden);
      expect(settings.directionKeySeedColorValue, isNull);
    });

    test('非法颜色回退 v1（越界与类型错误都算非法）', () async {
      final outOfRange = await _readSettingsWith({
        _v2Key: _v2Record(['TAB'], 'fixed', 0x00FFFFFF),
        _v1Key: ['ESC', 'ARROWS'],
      });
      expect(outOfRange.pinnedKeys, ['ESC', 'ARROWS']);
      expect(outOfRange.directionPadMode, TerminalDirectionPadMode.fixed);
      expect(outOfRange.directionKeySeedColorValue, isNull);

      final wrongType = await _readSettingsWith({
        _v2Key: _v2Record(['TAB'], 'fixed', 'red'),
        _v1Key: ['ESC'],
      });
      expect(wrongType.pinnedKeys, ['ESC']);
      expect(wrongType.directionPadMode, TerminalDirectionPadMode.hidden);
      expect(wrongType.directionKeySeedColorValue, isNull);
    });

    test('pinnedKeys 非字符串列表或整体非对象时回退 v1', () async {
      final badKeys = await _readSettingsWith({
        _v2Key: jsonEncode({
          'pinnedKeys': [1, 2],
          'directionPadMode': 'fixed',
          'directionKeySeedColorValue': null,
        }),
        _v1Key: ['ESC'],
      });
      expect(badKeys.pinnedKeys, ['ESC']);
      expect(badKeys.directionPadMode, TerminalDirectionPadMode.hidden);

      final notAMap = await _readSettingsWith({
        _v2Key: '[1,2]',
        _v1Key: ['ESC', 'ARROWS'],
      });
      expect(notAMap.pinnedKeys, ['ESC', 'ARROWS']);
      expect(notAMap.directionPadMode, TerminalDirectionPadMode.fixed);
    });

    test('对照：完好的 v2 记录优先于 v1', () async {
      final settings = await _readSettingsWith({
        _v2Key: _v2Record(['TAB'], 'flow', _color),
        _v1Key: ['ESC', 'ARROWS'],
      });

      expect(settings.pinnedKeys, ['TAB']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.flow);
      expect(settings.directionKeySeedColorValue, _color);
    });
  });

  group('配置导出 / 导入 v2', () {
    test('导出包含 v2 记录且三字段完整', () async {
      final source = await _storage();
      await source.setTerminalAccessorySettings(
        pinnedKeys: ['ESC', 'ARROWS', 'HOME'],
        directionPadMode: 'flow',
        directionKeySeedColorValue: 0xFF223344,
      );

      final exported = source.exportConfigurationPreferences();
      expect(exported.containsKey(_v2Key), isTrue);
      final record =
          jsonDecode(exported[_v2Key]! as String) as Map<String, dynamic>;
      expect(record.keys.toSet(), {
        'pinnedKeys',
        'directionPadMode',
        'directionKeySeedColorValue',
      });
      expect(record['pinnedKeys'], ['ESC', 'ARROWS', 'HOME']);
      expect(record['directionPadMode'], 'flow');
      expect(record['directionKeySeedColorValue'], 0xFF223344);
    });

    test('导入到全新存储后三字段都能读出并被 provider 采用', () async {
      final source = await _storage();
      await source.setTerminalAccessorySettings(
        pinnedKeys: ['ESC', 'ARROWS', 'HOME'],
        directionPadMode: 'flow',
        directionKeySeedColorValue: 0xFF223344,
      );
      final exported = source.exportConfigurationPreferences();

      SharedPreferences.setMockInitialValues({});
      final target = LocalStorageService(await SharedPreferences.getInstance());
      await target.appendConfiguration(
        servers: const [],
        agents: const [],
        commands: const [],
        bookmarks: const {},
        defaultAgents: const {},
        preferences: exported,
      );

      expect(target.getTerminalPinnedKeys(), ['ESC', 'ARROWS', 'HOME']);
      expect(target.getTerminalDirectionPadMode(), 'flow');
      expect(target.getTerminalDirectionKeySeedColorValue(), 0xFF223344);

      final container = await _container(storage: target);
      final settings = container.read(terminalSettingsProvider);
      expect(settings.pinnedKeys, ['ESC', 'ARROWS', 'HOME']);
      expect(settings.directionPadMode, TerminalDirectionPadMode.flow);
      expect(settings.directionKeySeedColorValue, 0xFF223344);
      container.dispose();
    });
  });

  group('旧 v1 键不被新记录覆盖', () {
    test('setTerminalAccessorySettings 写盘前后 v1 原样', () async {
      const v1 = ['ESC', 'HOME', '↑'];
      SharedPreferences.setMockInitialValues({_v1Key: v1});
      final storage = await _storage();
      final prefs = await SharedPreferences.getInstance();

      await storage.setTerminalAccessorySettings(
        pinnedKeys: ['TAB'],
        directionPadMode: 'hidden',
        directionKeySeedColorValue: 0xFF00FF00,
      );

      expect(prefs.getStringList(_v1Key), v1, reason: 'v1 必须原样保留以便回退');
      expect(prefs.getString(_v2Key), isNotNull, reason: '新记录必须真的写下去');
    });

    test('setTerminalPinnedKeys（旧 API）写盘前后 v1 原样', () async {
      const v1 = ['ARROWS', 'ESC'];
      SharedPreferences.setMockInitialValues({_v1Key: v1});
      final storage = await _storage();
      final prefs = await SharedPreferences.getInstance();

      await storage.setTerminalPinnedKeys(['TAB']);

      expect(prefs.getStringList(_v1Key), v1);
      expect(storage.getTerminalPinnedKeys(), ['TAB'], reason: '读取以新记录为准');
    });

    test('v1 在导出里也保持原样', () async {
      const v1 = ['ESC', 'ARROWS'];
      SharedPreferences.setMockInitialValues({_v1Key: v1});
      final storage = await _storage();
      await storage.setTerminalAccessorySettings(
        pinnedKeys: ['TAB'],
        directionPadMode: 'hidden',
        directionKeySeedColorValue: null,
      );

      final exported = storage.exportConfigurationPreferences();
      expect(exported[_v1Key], v1);
      expect(
        (jsonDecode(exported[_v2Key]! as String)
            as Map<String, dynamic>)['pinnedKeys'],
        ['TAB'],
      );
    });
  });
}
