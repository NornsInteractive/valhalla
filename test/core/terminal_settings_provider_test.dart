import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _tmuxKey = 'valhalla_terminal_use_tmux_v1';

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
    // tmux 是 opt-in：磁盘上没有这个键时必须落到「关闭」。
    SharedPreferences.setMockInitialValues({});
  });

  test('默认关闭：缺键即 false，走普通 SSH PTY', () async {
    final container = await _container();
    addTearDown(container.dispose);

    expect(container.read(terminalSettingsProvider).useTmux, isFalse);
  });

  test('显式存过 true 时读回 true', () async {
    SharedPreferences.setMockInitialValues({_tmuxKey: true});
    final container = await _container();
    addTearDown(container.dispose);

    expect(container.read(terminalSettingsProvider).useTmux, isTrue);
  });

  test('setUseTmux(true) 立即生效并落盘', () async {
    final container = await _container();
    addTearDown(container.dispose);

    await container.read(terminalSettingsProvider.notifier).setUseTmux(true);

    expect(container.read(terminalSettingsProvider).useTmux, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_tmuxKey), isTrue);
  });

  test('关闭后同样落盘，不会退回默认值', () async {
    SharedPreferences.setMockInitialValues({_tmuxKey: true});
    final container = await _container();
    addTearDown(container.dispose);

    await container.read(terminalSettingsProvider.notifier).setUseTmux(false);

    expect(container.read(terminalSettingsProvider).useTmux, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_tmuxKey), isFalse);
  });

  test('跨重启保留：新容器用同一份存储能读回上次的选择', () async {
    final first = await _container();
    await first.read(terminalSettingsProvider.notifier).setUseTmux(true);
    first.dispose();

    // 模拟 App 重启：重新构造容器，共享同一份 SharedPreferences。
    final second = await _container();
    addTearDown(second.dispose);

    expect(
      second.read(terminalSettingsProvider).useTmux,
      isTrue,
      reason: '开关必须持久化，否则每次开 App 都要重开一遍',
    );
  });

  test('LocalStorageService 缺键返回 false', () async {
    final storage = LocalStorageService(await SharedPreferences.getInstance());

    expect(storage.getUseTmuxForTerminal(), isFalse);
  });
}
