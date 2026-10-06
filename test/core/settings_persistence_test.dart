import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/localization/app_locales.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _themeModeKey = 'valhalla_theme_mode_v1';
const _accentKey = 'valhalla_accent_color_v1';
const _localeKey = 'valhalla_locale_v1';
const _bottomNavigationKey = 'valhalla_bottom_navigation_v1';
const _startupSectionKey = 'valhalla_startup_section_v1';
const _cliHistoryPageSizeKey = 'valhalla_cli_history_page_size_v1';

Future<ProviderContainer> _container() async {
  final localStorage = LocalStorageService(
    await SharedPreferences.getInstance(),
  );
  return ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(localStorage)],
  );
}

/// 模拟落盘失败：写入抛错且不改动既有存储值。
class _FailingLocaleStorage extends LocalStorageService {
  _FailingLocaleStorage(super.prefs);

  @override
  Future<void> setLocale(String languageTag) async {
    throw StateError('Could not persist language preference');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsNotifier 默认值', () {
    test('容器 Shell 按服务器与名称持久化，默认 Bash', () async {
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      expect(storage.getContainerShell('server-a', 'web'), 'bash');
      await storage.setContainerShell('server-a', 'web', 'sh');
      expect(storage.getContainerShell('server-a', 'web'), 'sh');
      expect(storage.getContainerShell('server-b', 'web'), 'bash');
      expect(storage.getContainerShell('server-a', 'db'), 'bash');
      await expectLater(
        storage.setContainerShell('server-a', 'web', 'fish'),
        throwsArgumentError,
      );
    });
    test('磁盘为空时主题和语言跟随系统', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.accentColor, AppAccentColor.cyberEmerald);
      expect(settings.locale, const Locale('system'));
      expect(
        settings.bottomNavigationSections,
        defaultBottomNavigationSections,
      );
      expect(settings.startupSection, AppSection.dashboard);
      expect(settings.cliHistoryPageSize, defaultCliHistoryPageSize);
    });

    test('无法识别的存储值回落到默认，而不是抛异常', () async {
      SharedPreferences.setMockInitialValues({
        _themeModeKey: 'neon_disaster',
        _accentKey: 'ultraviolet',
      });
      final container = await _container();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.accentColor, AppAccentColor.cyberEmerald);
    });
  });

  group('SettingsNotifier 读取已存值', () {
    test('读回显式存过的外观模式', () async {
      SharedPreferences.setMockInitialValues({
        _themeModeKey: 'amoled',
        _accentKey: 'techBlue',
        _localeKey: 'en',
      });
      final container = await _container();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, AppThemeMode.amoled);
      expect(settings.accentColor, AppAccentColor.techBlue);
      expect(settings.locale, const Locale('en'));
    });
  });

  group('SettingsNotifier 写入', () {
    test('底栏允许保存空列表，且与默认启动页分别持久化', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setBottomNavigationSections(const []);
      await container
          .read(settingsProvider.notifier)
          .setStartupSection(AppSection.cliChat);

      final settings = container.read(settingsProvider);
      expect(settings.bottomNavigationSections, isEmpty);
      expect(settings.startupSection, AppSection.cliChat);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_bottomNavigationKey), isEmpty);
      expect(prefs.getString(_startupSectionKey), 'cliChat');
    });

    test('底栏过滤重复项且保留用户顺序', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setBottomNavigationSections(const [
            AppSection.files,
            AppSection.dashboard,
            AppSection.files,
          ]);

      expect(container.read(settingsProvider).bottomNavigationSections, [
        AppSection.files,
        AppSection.dashboard,
      ]);
    });

    test('setThemeMode 立即生效并落盘', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setThemeMode(AppThemeMode.light);

      expect(container.read(settingsProvider).themeMode, AppThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_themeModeKey), 'light');
    });

    test('CLI 历史加载条数校验、即时生效并持久化', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setCliHistoryPageSize(25);

      expect(container.read(settingsProvider).cliHistoryPageSize, 25);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_cliHistoryPageSizeKey), 25);
      await expectLater(
        container.read(settingsProvider.notifier).setCliHistoryPageSize(23),
        throwsArgumentError,
      );
    });

    test('setAccentColor 立即生效并落盘', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setAccentColor(AppAccentColor.crimsonRed);

      expect(
        container.read(settingsProvider).accentColor,
        AppAccentColor.crimsonRed,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_accentKey), 'crimsonRed');
    });

    test('setLocale 立即生效并只落盘语言代码', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('en'));

      expect(container.read(settingsProvider).locale, const Locale('en'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_localeKey), 'en');
    });

    test('应用语言选择 17 项逐个保存、重启后保持 canonical tag 完备且相等', () async {
      expect(appLanguageLocales.length, 17);
      final expectedTags = appLanguageLocales
          .map((locale) => appLocaleToStorage(locale))
          .toList();
      for (final tag in expectedTags) {
        final container = await _container();
        addTearDown(container.dispose);
        final locale = appLocaleFromStorage(tag);

        await container.read(settingsProvider.notifier).setLocale(locale);

        expect(
          container.read(settingsProvider).locale,
          appLocaleFromStorage(tag),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_localeKey), tag);

        // 重启：新容器共享同一份 SharedPreferences。
        final second = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              LocalStorageService(prefs),
            ),
          ],
        );
        addTearDown(second.dispose);
        expect(
          second.read(settingsProvider).locale,
          appLocaleFromStorage(tag),
          reason: 'tag=$tag must survive restart',
        );
      }
    });

    test('setLocale(system) 选择跟随系统并持久化 system', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('system'));

      expect(container.read(settingsProvider).locale, const Locale('system'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_localeKey), 'system');
    });

    test('setLocale 写入失败：抛错、状态不变、磁盘仍是旧值', () async {
      SharedPreferences.setMockInitialValues({_localeKey: 'en'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _FailingLocaleStorage(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).locale, const Locale('en'));

      await expectLater(
        container.read(settingsProvider.notifier).setLocale(const Locale('ja')),
        throwsStateError,
      );

      expect(
        container.read(settingsProvider).locale,
        const Locale('en'),
        reason: '失败必须不能把内存先改成已选语言',
      );
      expect(prefs.getString(_localeKey), 'en');
    });

    test('resetDefaults 把外观和导航都写回默认值', () async {
      SharedPreferences.setMockInitialValues({
        _themeModeKey: 'light',
        _accentKey: 'techBlue',
        _localeKey: 'en',
        _bottomNavigationKey: <String>[],
        _startupSectionKey: 'cliChat',
      });
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).resetDefaults();

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.accentColor, AppAccentColor.cyberEmerald);
      expect(settings.locale, const Locale('system'));
      expect(
        settings.bottomNavigationSections,
        defaultBottomNavigationSections,
      );
      expect(settings.startupSection, AppSection.dashboard);

      // 只改内存不改盘的话，重启后旧值会「复活」。
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_themeModeKey), 'system');
      expect(prefs.getString(_accentKey), 'cyberEmerald');
      expect(prefs.getString(_localeKey), 'system');
      expect(
        prefs.getStringList(_bottomNavigationKey),
        defaultBottomNavigationSections.map((item) => item.name).toList(),
      );
      expect(prefs.getString(_startupSectionKey), 'dashboard');
      expect(prefs.getInt(_cliHistoryPageSizeKey), defaultCliHistoryPageSize);
    });
  });

  test('跨重启保留：新容器用同一份存储能读回上次的主题', () async {
    final first = await _container();
    await first
        .read(settingsProvider.notifier)
        .setThemeMode(AppThemeMode.amoled);
    await first
        .read(settingsProvider.notifier)
        .setAccentColor(AppAccentColor.amberOrange);
    first.dispose();

    // 模拟 App 重启：重新构造容器，共享同一份 SharedPreferences。
    final second = await _container();
    addTearDown(second.dispose);

    final settings = second.read(settingsProvider);
    expect(
      settings.themeMode,
      AppThemeMode.amoled,
      reason: '主题必须持久化，否则每次启动都被打回默认值',
    );
    expect(settings.accentColor, AppAccentColor.amberOrange, reason: '主题色同理');
  });

  group('themeModeFromStorage / accentColorFromStorage', () {
    test('识别所有合法名字', () {
      for (final mode in AppThemeMode.values) {
        expect(
          themeModeFromStorage(mode.name, fallback: AppThemeMode.system),
          mode,
        );
      }
      for (final color in AppAccentColor.values) {
        expect(
          accentColorFromStorage(
            color.name,
            fallback: AppAccentColor.cyberEmerald,
          ),
          color,
        );
      }
    });

    test('无法识别的值返回传入的 fallback', () {
      expect(
        themeModeFromStorage('nope', fallback: AppThemeMode.light),
        AppThemeMode.light,
      );
      expect(
        accentColorFromStorage('nope', fallback: AppAccentColor.techBlue),
        AppAccentColor.techBlue,
      );
    });
  });

  test('存储中的未知页面被忽略，非法启动页回退到仪表盘', () async {
    SharedPreferences.setMockInitialValues({
      _bottomNavigationKey: ['files', 'removedPage', 'files', 'cliChat'],
      _startupSectionKey: 'removedPage',
    });
    final container = await _container();
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider);
    expect(settings.bottomNavigationSections, [
      AppSection.files,
      AppSection.cliChat,
    ]);
    expect(settings.startupSection, AppSection.dashboard);
  });

  test('旧主题色初始化三个独立槽，单槽修改不影响其他模式', () async {
    SharedPreferences.setMockInitialValues({_accentKey: 'techBlue'});
    final first = await _container();
    expect(
      first.read(settingsProvider).lightAccentColor,
      AppAccentColor.techBlue.color,
    );
    expect(
      first.read(settingsProvider).darkAccentColor,
      AppAccentColor.techBlue.color,
    );
    await first
        .read(settingsProvider.notifier)
        .setThemeAccentColor(AppThemeMode.amoled, const Color(0xFF123456));
    expect(
      first.read(settingsProvider).amoledAccentColor,
      const Color(0xFF123456),
    );
    expect(
      first.read(settingsProvider).darkAccentColor,
      AppAccentColor.techBlue.color,
    );
    first.dispose();
    final second = await _container();
    addTearDown(second.dispose);
    expect(
      second.read(settingsProvider).amoledAccentColor,
      const Color(0xFF123456),
    );
    expect(
      second.read(settingsProvider).lightAccentColor,
      AppAccentColor.techBlue.color,
    );
  });

  test('非法新主题色回退旧值，恢复默认会重置全部模式', () async {
    SharedPreferences.setMockInitialValues({
      _accentKey: 'techBlue',
      'valhalla_accent_color_v2::light': '#invalid',
      'valhalla_accent_color_v2::dark': '#112233',
    });
    final container = await _container();
    addTearDown(container.dispose);
    final settings = container.read(settingsProvider);
    expect(settings.lightAccentColor, AppAccentColor.techBlue.color);
    expect(settings.darkAccentColor, const Color(0xFF112233));
    await container.read(settingsProvider.notifier).resetDefaults();
    final reset = container.read(settingsProvider);
    expect(reset.lightAccentColor, AppAccentColor.cyberEmerald.color);
    expect(reset.darkAccentColor, AppAccentColor.cyberEmerald.color);
    expect(reset.amoledAccentColor, AppAccentColor.cyberEmerald.color);
  });

  test('快捷入口保留顺序、过滤重复及仪表盘，并允许空列表', () async {
    final container = await _container();
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setDashboardQuickSections([
      AppSection.cliChat,
      AppSection.files,
      AppSection.cliChat,
      AppSection.dashboard,
    ]);
    expect(container.read(settingsProvider).dashboardQuickSections, [
      AppSection.cliChat,
      AppSection.files,
    ]);
    await notifier.setDashboardQuickSections([]);
    expect(container.read(settingsProvider).dashboardQuickSections, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('valhalla_dashboard_quick_sections_v1'),
      isEmpty,
    );
  });

  test('默认 Agent 按服务器与 CLI/ACP 模式隔离并可清除', () async {
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    await storage.setDefaultAgentId('s1', 'codex', cli: true);
    await storage.setDefaultAgentId('s1', 'claude', cli: false);
    await storage.setDefaultAgentId('s2', 'agy', cli: true);
    expect(storage.getDefaultAgentId('s1', cli: true), 'codex');
    expect(storage.getDefaultAgentId('s1', cli: false), 'claude');
    expect(storage.getDefaultAgentId('s2', cli: true), 'agy');
    await storage.setDefaultAgentId('s1', null, cli: true);
    expect(storage.getDefaultAgentId('s1', cli: true), isNull);
    expect(storage.getDefaultAgentId('s1', cli: false), 'claude');
  });
}
