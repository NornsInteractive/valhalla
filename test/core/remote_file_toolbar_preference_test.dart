import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/services/configuration_backup_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _toolbarKey = 'valhalla_remote_file_toolbar_actions_v1';
const _themeModeKey = 'valhalla_theme_mode_v1';
const _cliHistoryPageSizeKey = 'valhalla_cli_history_page_size_v1';

ProviderContainer _container(LocalStorageService storage) => ProviderContainer(
  overrides: [localStorageServiceProvider.overrideWithValue(storage)],
);

/// 模拟平台写入失败的 SharedPreferences：缓存乐观更新，只有平台接受写入
/// 才提交到 native；失败/抛错后调用方靠 `reload()` 回滚缓存。
class _FaultyToolbarPrefs implements SharedPreferences {
  _FaultyToolbarPrefs([Map<String, Object>? seed]) {
    if (seed != null) {
      native.addAll(seed);
      cache.addAll(seed);
    }
  }

  final Map<String, Object> native = <String, Object>{};
  final Map<String, Object> cache = <String, Object>{};

  /// 平台返回 false（写入被拒绝）。
  bool failListWrite = false;

  /// 平台抛出异常。
  bool throwListWrite = false;

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
    native[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    cache[key] = value;
    native[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    cache[key] = value;
    native[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    cache[key] = value;
    native[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    cache[key] = value;
    if (throwListWrite) throw StateError('fixture platform error');
    if (failListWrite) return false;
    native[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    cache.remove(key);
    native.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    cache.clear();
    native.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(native);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('remoteFileToolbarActionsFromStorage', () {
    test('缺键返回五个默认动作，且结果不可修改', () {
      final parsed = remoteFileToolbarActionsFromStorage(null);

      expect(parsed, defaultRemoteFileToolbarActions);
      expect(parsed, [
        RemoteFileToolbarAction.upload,
        RemoteFileToolbarAction.create,
        RemoteFileToolbarAction.view,
        RemoteFileToolbarAction.transfers,
        RemoteFileToolbarAction.sort,
      ]);
      expect(defaultRemoteFileToolbarActions, hasLength(5));
      expect(
        () => parsed.add(RemoteFileToolbarAction.refresh),
        throwsUnsupportedError,
        reason: '默认列表被多处共享，必须不可变',
      );
    });

    test('未知名与重复项被剔除，逆序输入归一为枚举顺序', () {
      final parsed = remoteFileToolbarActionsFromStorage(const [
        'refresh',
        'ghost',
        'upload',
        'refresh',
        'sort',
        'upload',
        'bogus',
        'selection',
      ]);

      expect(parsed, [
        RemoteFileToolbarAction.upload,
        RemoteFileToolbarAction.sort,
        RemoteFileToolbarAction.selection,
        RemoteFileToolbarAction.refresh,
      ]);
      expect(
        () => parsed.removeAt(0),
        throwsUnsupportedError,
        reason: '解析结果必须不可变',
      );
    });

    test('显式空集合保持全空，而不是回落默认', () {
      expect(remoteFileToolbarActionsFromStorage(const []), isEmpty);
    });

    test('九项全给时按枚举（显示）顺序返回', () {
      expect(
        remoteFileToolbarActionsFromStorage(
          RemoteFileToolbarAction.values.map((action) => action.name).toList(),
        ),
        RemoteFileToolbarAction.values,
      );
      expect(RemoteFileToolbarAction.values, hasLength(9));
    });
  });

  group('SettingsNotifier 工具栏偏好', () {
    test('磁盘缺键时 provider 给出五个默认动作且不写键', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = _container(LocalStorageService(prefs));
      addTearDown(container.dispose);

      expect(
        container.read(settingsProvider).remoteFileToolbarActions,
        defaultRemoteFileToolbarActions,
      );
      expect(prefs.containsKey(_toolbarKey), isFalse);
    });

    test('显式空集合落盘、跨 provider 重建仍为空', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = _container(LocalStorageService(prefs));
      addTearDown(first.dispose);

      await first
          .read(settingsProvider.notifier)
          .setRemoteFileToolbarActions(const []);

      expect(first.read(settingsProvider).remoteFileToolbarActions, isEmpty);
      expect(prefs.getStringList(_toolbarKey), isEmpty);

      final second = _container(LocalStorageService(prefs));
      addTearDown(second.dispose);
      expect(
        second.read(settingsProvider).remoteFileToolbarActions,
        isEmpty,
        reason: '显式空集合必须原样读回，不能被当成缺键回落成默认四件',
      );
    });

    test('保存只改工具栏字段，存稳定名字并跨重启读回', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = _container(LocalStorageService(prefs));
      addTearDown(first.dispose);
      final notifier = first.read(settingsProvider.notifier);

      await notifier.setThemeMode(AppThemeMode.amoled);
      await notifier.setCliHistoryPageSize(25);
      await notifier.setRemoteFileToolbarActions(
        RemoteFileToolbarAction.values.reversed,
      );

      final saved = first.read(settingsProvider);
      expect(saved.remoteFileToolbarActions, RemoteFileToolbarAction.values);
      expect(saved.themeMode, AppThemeMode.amoled);
      expect(saved.cliHistoryPageSize, 25);
      expect(
        prefs.getStringList(_toolbarKey),
        RemoteFileToolbarAction.values.map((action) => action.name).toList(),
        reason: '必须存枚举名而不是下标，且逆序输入要归一为枚举顺序',
      );
      expect(prefs.getStringList(_toolbarKey)!.first, 'upload');

      final second = _container(LocalStorageService(prefs));
      addTearDown(second.dispose);
      final restored = second.read(settingsProvider);
      expect(restored.remoteFileToolbarActions, RemoteFileToolbarAction.values);
      expect(restored.themeMode, AppThemeMode.amoled);
      expect(restored.cliHistoryPageSize, 25);
    });

    test('平台返回 false：抛保存失败、状态不变、缓存回滚', () async {
      final prefs = _FaultyToolbarPrefs({
        _toolbarKey: ['upload', 'create'],
        _themeModeKey: 'amoled',
      });
      prefs.failListWrite = true;
      final container = _container(LocalStorageService(prefs));
      addTearDown(container.dispose);
      final notifier = container.read(settingsProvider.notifier);

      expect(container.read(settingsProvider).remoteFileToolbarActions, [
        RemoteFileToolbarAction.upload,
        RemoteFileToolbarAction.create,
      ]);

      await expectLater(
        notifier.setRemoteFileToolbarActions(const [
          RemoteFileToolbarAction.refresh,
        ]),
        throwsA(
          isA<StorageException>().having(
            (error) => error.message,
            'message',
            'SFTP_TOOLBAR_PREFERENCE_SAVE_FAILED',
          ),
        ),
      );

      expect(
        container.read(settingsProvider).remoteFileToolbarActions,
        [RemoteFileToolbarAction.upload, RemoteFileToolbarAction.create],
        reason: '保存失败必须先抛错、再谈状态，内存不得先行改动',
      );
      expect(prefs.getStringList(_toolbarKey), [
        'upload',
        'create',
      ], reason: '乐观缓存必须被 reload 回滚');
      expect(container.read(settingsProvider).themeMode, AppThemeMode.amoled);

      final restarted = _container(LocalStorageService(prefs));
      addTearDown(restarted.dispose);
      expect(
        restarted.read(settingsProvider).remoteFileToolbarActions,
        [RemoteFileToolbarAction.upload, RemoteFileToolbarAction.create],
        reason: '重启不得读到未提交的值',
      );
    });

    test('平台抛错：原样上抛、状态与缓存保持旧值', () async {
      final prefs = _FaultyToolbarPrefs({
        _toolbarKey: ['upload', 'create'],
      });
      prefs.throwListWrite = true;
      final container = _container(LocalStorageService(prefs));
      addTearDown(container.dispose);

      await expectLater(
        container.read(settingsProvider.notifier).setRemoteFileToolbarActions(
          const [RemoteFileToolbarAction.refresh],
        ),
        throwsA(isA<StateError>()),
      );

      expect(container.read(settingsProvider).remoteFileToolbarActions, [
        RemoteFileToolbarAction.upload,
        RemoteFileToolbarAction.create,
      ]);
      expect(prefs.getStringList(_toolbarKey), ['upload', 'create']);
    });

    test('resetDefaults 把工具栏写回四个默认动作', () async {
      SharedPreferences.setMockInitialValues({
        _toolbarKey: ['refresh', 'selection'],
        _themeModeKey: 'amoled',
        _cliHistoryPageSizeKey: 25,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = _container(LocalStorageService(prefs));
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).resetDefaults();

      final reset = container.read(settingsProvider);
      expect(reset.remoteFileToolbarActions, defaultRemoteFileToolbarActions);
      expect(reset.themeMode, AppThemeMode.system);
      expect(reset.cliHistoryPageSize, defaultCliHistoryPageSize);
      expect(prefs.getStringList(_toolbarKey), [
        'upload',
        'create',
        'view',
        'transfers',
        'sort',
      ]);
      expect(prefs.getString(_themeModeKey), 'system');
      expect(prefs.getInt(_cliHistoryPageSizeKey), defaultCliHistoryPageSize);
    });

    test('工具栏重置写入失败时整体状态保持不变', () async {
      final prefs = _FaultyToolbarPrefs({
        _toolbarKey: ['refresh', 'selection'],
        _themeModeKey: 'amoled',
      });
      prefs.failListWrite = true;
      final container = _container(LocalStorageService(prefs));
      addTearDown(container.dispose);

      await expectLater(
        container.read(settingsProvider.notifier).resetDefaults(),
        throwsA(isA<StorageException>()),
      );

      final kept = container.read(settingsProvider);
      expect(kept.remoteFileToolbarActions, [
        RemoteFileToolbarAction.selection,
        RemoteFileToolbarAction.refresh,
      ], reason: '读取时按枚举顺序归一，失败后必须停在这个值上');
      expect(
        kept.themeMode,
        AppThemeMode.amoled,
        reason: '工具栏写失败必须在改动内存状态之前中断整个重置',
      );
      expect(prefs.getStringList(_toolbarKey), ['refresh', 'selection']);
      expect(prefs.getString(_themeModeKey), 'amoled');
    });
  });

  group('工具栏偏好配置备份往返', () {
    test('导出→导入后原样落盘，并被 provider 归一为枚举顺序', () async {
      SharedPreferences.setMockInitialValues({
        _toolbarKey: ['refresh', 'sort', 'upload'],
      });
      final source = LocalStorageService(await SharedPreferences.getInstance());
      final encoded = ConfigurationBackupService(source).exportConfiguration();
      final json =
          const JsonDecoder().convert(encoded.encode()) as Map<String, dynamic>;

      expect((json['preferences'] as Map)[_toolbarKey], [
        'refresh',
        'sort',
        'upload',
      ]);

      SharedPreferences.setMockInitialValues({});
      final target = LocalStorageService(await SharedPreferences.getInstance());
      await ConfigurationBackupService(target).importConfiguration(
        ConfigurationBackupService.decode(encoded.encode()),
        applyPreferences: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_toolbarKey), ['refresh', 'sort', 'upload']);

      final container = _container(target);
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).remoteFileToolbarActions, [
        RemoteFileToolbarAction.upload,
        RemoteFileToolbarAction.sort,
        RemoteFileToolbarAction.refresh,
      ]);
    });

    test('显式空集合往返后仍是空，不回落默认', () async {
      SharedPreferences.setMockInitialValues({_toolbarKey: <String>[]});
      final source = LocalStorageService(await SharedPreferences.getInstance());
      final encoded = ConfigurationBackupService(source).exportConfiguration();
      final json =
          const JsonDecoder().convert(encoded.encode()) as Map<String, dynamic>;

      expect((json['preferences'] as Map)[_toolbarKey], isEmpty);

      SharedPreferences.setMockInitialValues({});
      final target = LocalStorageService(await SharedPreferences.getInstance());
      await ConfigurationBackupService(target).importConfiguration(
        ConfigurationBackupService.decode(encoded.encode()),
        applyPreferences: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_toolbarKey), isEmpty);

      final container = _container(target);
      addTearDown(container.dispose);
      expect(
        container.read(settingsProvider).remoteFileToolbarActions,
        isEmpty,
        reason: '空集合是合法偏好，往返导入不得被默认值覆盖',
      );
    });
  });
}
