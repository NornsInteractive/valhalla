import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/auto_connect_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _modeKey = 'valhalla_auto_connect_mode_v1';
const _fixedKey = 'valhalla_auto_connect_server_id_v1';
const _lastKey = 'valhalla_last_connected_server_id_v1';

Future<ProviderContainer> _container() async {
  final localStorage = LocalStorageService(
    await SharedPreferences.getInstance(),
  );
  return ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(localStorage)],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('默认「记住最后一次连接」', () async {
    final container = await _container();
    addTearDown(container.dispose);

    expect(
      container.read(autoConnectSettingsProvider).mode,
      AutoConnectMode.lastConnected,
      reason:
          '缺键默认必须是 lastConnected：fixed 未指定时等于不连接，'
          '对新用户来说等于静默失效',
    );
  });

  test('显式存过 fixed 时读回 fixed', () async {
    SharedPreferences.setMockInitialValues({
      _modeKey: 'fixed',
      _fixedKey: 'srv-9',
    });
    final container = await _container();
    addTearDown(container.dispose);

    final settings = container.read(autoConnectSettingsProvider);
    expect(settings.mode, AutoConnectMode.fixed);
    expect(settings.fixedServerId, 'srv-9');
  });

  test('未知模式值回落到 lastConnected 而不是崩或取枚举首位', () async {
    SharedPreferences.setMockInitialValues({_modeKey: 'something_else'});
    final container = await _container();
    addTearDown(container.dispose);

    expect(
      container.read(autoConnectSettingsProvider).mode,
      AutoConnectMode.lastConnected,
    );
  });

  test('setMode 立即生效并落盘', () async {
    final container = await _container();
    addTearDown(container.dispose);

    await container
        .read(autoConnectSettingsProvider.notifier)
        .setMode(AutoConnectMode.fixed);

    expect(
      container.read(autoConnectSettingsProvider).mode,
      AutoConnectMode.fixed,
    );
    final prefs = await SharedPreferences.getInstance();
    // 落盘的必须是枚举名字面量，否则重启后解析不回来。
    expect(prefs.getString(_modeKey), 'fixed');
  });

  test('setFixedServerId 落盘，传 null 时删键', () async {
    final container = await _container();
    addTearDown(container.dispose);
    final notifier = container.read(autoConnectSettingsProvider.notifier);

    await notifier.setFixedServerId('srv-3');
    expect(container.read(autoConnectSettingsProvider).fixedServerId, 'srv-3');
    expect(
      (await SharedPreferences.getInstance()).getString(_fixedKey),
      'srv-3',
    );

    await notifier.setFixedServerId(null);
    expect(container.read(autoConnectSettingsProvider).fixedServerId, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString(_fixedKey),
      isNull,
      reason: 'null 必须删键；留一个空串会让「未指定」和「指定了空 id」混淆',
    );
  });

  test('切到 lastConnected 不会丢掉已选的固定服务器', () async {
    SharedPreferences.setMockInitialValues({
      _modeKey: 'fixed',
      _fixedKey: 'srv-9',
    });
    final container = await _container();
    addTearDown(container.dispose);

    await container
        .read(autoConnectSettingsProvider.notifier)
        .setMode(AutoConnectMode.lastConnected);

    // 来回拨开关是常见操作，不该因此要重选一次服务器。
    expect(container.read(autoConnectSettingsProvider).fixedServerId, 'srv-9');
  });

  test('跨重启保留', () async {
    final first = await _container();
    await first
        .read(autoConnectSettingsProvider.notifier)
        .setMode(AutoConnectMode.fixed);
    await first
        .read(autoConnectSettingsProvider.notifier)
        .setFixedServerId('srv-7');
    first.dispose();

    final second = await _container();
    addTearDown(second.dispose);

    final settings = second.read(autoConnectSettingsProvider);
    expect(settings.mode, AutoConnectMode.fixed);
    expect(settings.fixedServerId, 'srv-7');
  });

  test('LocalStorageService：缺键时 mode 回落 lastConnected', () async {
    final storage = LocalStorageService(await SharedPreferences.getInstance());

    expect(storage.getAutoConnectMode(), 'lastConnected');
  });

  test('LocalStorageService：lastConnected 缺键返回 null', () async {
    final storage = LocalStorageService(await SharedPreferences.getInstance());

    expect(storage.getLastConnectedServerId(), isNull);
  });

  test('LocalStorageService：setLastConnectedServerId 落盘', () async {
    final storage = LocalStorageService(await SharedPreferences.getInstance());

    await storage.setLastConnectedServerId('srv-1');

    expect(storage.getLastConnectedServerId(), 'srv-1');
    expect(
      (await SharedPreferences.getInstance()).getString(_lastKey),
      'srv-1',
    );
  });
}
