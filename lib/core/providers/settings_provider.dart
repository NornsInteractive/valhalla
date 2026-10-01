import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import 'storage_providers.dart';

export '../../app/theme.dart' show AppThemeMode, AppAccentColor;

/// App 中可导航的稳定页面标识。持久化使用 [name]，不要存位置下标。
enum AppSection {
  dashboard,
  aiChat,
  terminal,
  files,
  docker,
  system,
  commands,
  settings,
  cliChat,
  nas,
}

const defaultBottomNavigationSections = <AppSection>[
  AppSection.dashboard,
  AppSection.aiChat,
  AppSection.docker,
  AppSection.files,
];

const defaultDashboardQuickSections = <AppSection>[
  AppSection.aiChat,
  AppSection.terminal,
  AppSection.files,
  AppSection.docker,
  AppSection.system,
  AppSection.commands,
];

AppSection? appSectionFromStorage(String raw) {
  for (final section in AppSection.values) {
    if (section.name == raw) return section;
  }
  return null;
}

List<AppSection> bottomNavigationFromStorage(List<String>? raw) {
  if (raw == null) return defaultBottomNavigationSections;
  final seen = <AppSection>{};
  return [
    for (final value in raw)
      if (appSectionFromStorage(value) case final section?)
        if (seen.add(section)) section,
  ];
}

List<AppSection> dashboardQuickSectionsFromStorage(List<String>? raw) {
  if (raw == null) return defaultDashboardQuickSections;
  final seen = <AppSection>{};
  return [
    for (final value in raw)
      if (appSectionFromStorage(value) case final section?)
        if (section != AppSection.dashboard && seen.add(section)) section,
  ];
}

Color themeAccentColorFromStorage(String? raw, {required Color fallback}) {
  if (raw == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw)) {
    return fallback;
  }
  return Color(0xFF000000 | int.parse(raw.substring(1), radix: 16));
}

String themeAccentColorToStorage(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const defaultCliHistoryPageSize = 10;

int cliHistoryPageSizeFromStorage(int value) =>
    value >= 5 && value <= 100 && value % 5 == 0
    ? value
    : defaultCliHistoryPageSize;

class SettingsState {
  final AppThemeMode themeMode;
  final AppAccentColor accentColor;
  final Color lightAccentColor;
  final Color darkAccentColor;
  final Color amoledAccentColor;
  final Locale locale;
  final List<AppSection> bottomNavigationSections;
  final List<AppSection> dashboardQuickSections;
  final AppSection startupSection;
  final int cliHistoryPageSize;

  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.accentColor = AppAccentColor.cyberEmerald,
    this.lightAccentColor = const Color(0xFF10B981),
    this.darkAccentColor = const Color(0xFF10B981),
    this.amoledAccentColor = const Color(0xFF10B981),
    this.locale = const Locale('system'),
    this.bottomNavigationSections = defaultBottomNavigationSections,
    this.dashboardQuickSections = defaultDashboardQuickSections,
    this.startupSection = AppSection.dashboard,
    this.cliHistoryPageSize = defaultCliHistoryPageSize,
  });

  SettingsState copyWith({
    AppThemeMode? themeMode,
    AppAccentColor? accentColor,
    Color? lightAccentColor,
    Color? darkAccentColor,
    Color? amoledAccentColor,
    Locale? locale,
    List<AppSection>? bottomNavigationSections,
    List<AppSection>? dashboardQuickSections,
    AppSection? startupSection,
    int? cliHistoryPageSize,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      lightAccentColor: lightAccentColor ?? this.lightAccentColor,
      darkAccentColor: darkAccentColor ?? this.darkAccentColor,
      amoledAccentColor: amoledAccentColor ?? this.amoledAccentColor,
      locale: locale ?? this.locale,
      bottomNavigationSections:
          bottomNavigationSections ?? this.bottomNavigationSections,
      dashboardQuickSections:
          dashboardQuickSections ?? this.dashboardQuickSections,
      startupSection: startupSection ?? this.startupSection,
      cliHistoryPageSize: cliHistoryPageSize ?? this.cliHistoryPageSize,
    );
  }

  Color colorForTheme(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => lightAccentColor,
    AppThemeMode.dark => darkAccentColor,
    AppThemeMode.amoled => amoledAccentColor,
    AppThemeMode.system => lightAccentColor,
  };
}

/// 把存储里的字符串还原成枚举。
///
/// 存的是 `enum.name` 而不是 `index`：index 会因为枚举里插了一项就整体错位，
/// 而 name 挪动位置也不会改变含义。无法识别的值一律回落到 [fallback]，
/// 这样即使降级安装（新版本写、旧版本读）也不会崩。
AppThemeMode themeModeFromStorage(
  String raw, {
  required AppThemeMode fallback,
}) {
  for (final mode in AppThemeMode.values) {
    if (mode.name == raw) return mode;
  }
  return fallback;
}

AppAccentColor accentColorFromStorage(
  String raw, {
  required AppAccentColor fallback,
}) {
  for (final color in AppAccentColor.values) {
    if (color.name == raw) return color;
  }
  return fallback;
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // 订阅存储 provider 而不是直接读单例：测试里注入替身存储后，
    // 这里必须跟着换，否则主题/语言的用例只能测到默认值。
    final storage = ref.watch(localStorageServiceProvider);
    final legacyAccent = accentColorFromStorage(
      storage.getAccentColor(),
      fallback: const SettingsState().accentColor,
    );
    return SettingsState(
      themeMode: themeModeFromStorage(
        storage.getThemeMode(),
        fallback: const SettingsState().themeMode,
      ),
      accentColor: legacyAccent,
      lightAccentColor: themeAccentColorFromStorage(
        storage.getThemeAccentColor('light'),
        fallback: legacyAccent.color,
      ),
      darkAccentColor: themeAccentColorFromStorage(
        storage.getThemeAccentColor('dark'),
        fallback: legacyAccent.color,
      ),
      amoledAccentColor: themeAccentColorFromStorage(
        storage.getThemeAccentColor('amoled'),
        fallback: legacyAccent.color,
      ),
      locale: Locale(storage.getLocale()),
      bottomNavigationSections: bottomNavigationFromStorage(
        storage.getBottomNavigationSections(),
      ),
      dashboardQuickSections: dashboardQuickSectionsFromStorage(
        storage.getDashboardQuickSections(),
      ),
      startupSection:
          appSectionFromStorage(storage.getStartupSection() ?? '') ??
          AppSection.dashboard,
      cliHistoryPageSize: cliHistoryPageSizeFromStorage(
        storage.getCliHistoryPageSize(),
      ),
    );
  }

  // 下面三个 setter 都是「先改内存再落盘」：外观切换必须立刻生效，
  // 写盘失败不该把 UI 卡在旧值上。

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(localStorageServiceProvider).setThemeMode(mode.name);
  }

  Future<void> setAccentColor(AppAccentColor color) async {
    state = state.copyWith(
      accentColor: color,
      lightAccentColor: color.color,
      darkAccentColor: color.color,
      amoledAccentColor: color.color,
    );
    final storage = ref.read(localStorageServiceProvider);
    await storage.setAccentColor(color.name);
    for (final mode in [
      AppThemeMode.light,
      AppThemeMode.dark,
      AppThemeMode.amoled,
    ]) {
      await storage.setThemeAccentColor(
        mode.name,
        themeAccentColorToStorage(color.color),
      );
    }
  }

  Future<void> setThemeAccentColor(AppThemeMode mode, Color color) async {
    if (mode == AppThemeMode.system) {
      throw ArgumentError.value(
        mode,
        'mode',
        'System uses light and dark colors',
      );
    }
    final opaque = Color(0xFF000000 | (color.toARGB32() & 0xFFFFFF));
    state = switch (mode) {
      AppThemeMode.light => state.copyWith(lightAccentColor: opaque),
      AppThemeMode.dark => state.copyWith(darkAccentColor: opaque),
      AppThemeMode.amoled => state.copyWith(amoledAccentColor: opaque),
      AppThemeMode.system => state,
    };
    await ref
        .read(localStorageServiceProvider)
        .setThemeAccentColor(mode.name, themeAccentColorToStorage(opaque));
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await ref.read(localStorageServiceProvider).setLocale(locale.languageCode);
  }

  Future<void> setBottomNavigationSections(
    Iterable<AppSection> sections,
  ) async {
    final next = <AppSection>[];
    final seen = <AppSection>{};
    for (final section in sections) {
      if (seen.add(section)) next.add(section);
    }
    state = state.copyWith(bottomNavigationSections: List.unmodifiable(next));
    await ref
        .read(localStorageServiceProvider)
        .setBottomNavigationSections(next.map((item) => item.name).toList());
  }

  Future<void> setDashboardQuickSections(Iterable<AppSection> sections) async {
    final next = <AppSection>[];
    final seen = <AppSection>{};
    for (final section in sections) {
      if (section != AppSection.dashboard && seen.add(section)) {
        next.add(section);
      }
    }
    state = state.copyWith(dashboardQuickSections: List.unmodifiable(next));
    await ref
        .read(localStorageServiceProvider)
        .setDashboardQuickSections(next.map((item) => item.name).toList());
  }

  Future<void> setStartupSection(AppSection section) async {
    state = state.copyWith(startupSection: section);
    await ref.read(localStorageServiceProvider).setStartupSection(section.name);
  }

  Future<void> setCliHistoryPageSize(int value) async {
    final valid = cliHistoryPageSizeFromStorage(value);
    if (valid != value) {
      throw ArgumentError.value(
        value,
        'value',
        'Expected 5..100 in steps of 5',
      );
    }
    state = state.copyWith(cliHistoryPageSize: value);
    await ref.read(localStorageServiceProvider).setCliHistoryPageSize(value);
  }

  Future<void> resetDefaults() async {
    const defaults = SettingsState();
    state = defaults;
    final storage = ref.read(localStorageServiceProvider);
    await storage.setThemeMode(defaults.themeMode.name);
    await storage.setAccentColor(defaults.accentColor.name);
    for (final mode in [
      AppThemeMode.light,
      AppThemeMode.dark,
      AppThemeMode.amoled,
    ]) {
      await storage.setThemeAccentColor(
        mode.name,
        themeAccentColorToStorage(defaults.colorForTheme(mode)),
      );
    }
    await storage.setLocale(defaults.locale.languageCode);
    await storage.setBottomNavigationSections(
      defaults.bottomNavigationSections.map((item) => item.name).toList(),
    );
    await storage.setDashboardQuickSections(
      defaults.dashboardQuickSections.map((item) => item.name).toList(),
    );
    await storage.setStartupSection(defaults.startupSection.name);
    await storage.setCliHistoryPageSize(defaults.cliHistoryPageSize);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
