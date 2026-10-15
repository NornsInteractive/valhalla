import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

Future<LocalStorageService> _freshStorage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

Widget _buildSettingsApp({
  required List<dynamic> overrides,
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const Scaffold(body: SettingsView()),
    ),
  );
}

/// 紧凑分组后，启动页 / 底部导航栏 / 仪表盘快捷操作都收进「导航」入口的
/// bottom sheet，需先点开 `settings_navigation_tile` 才能看到原来的导航设置。
Future<void> _openNavigationSheet(WidgetTester tester) async {
  final entry = find.byKey(const Key('settings_navigation_tile'));
  final scrollable = find.byType(Scrollable).first;
  var scrollAttempts = 0;
  while (entry.evaluate().isEmpty && scrollAttempts < 40) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    scrollAttempts++;
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsView Navigation Settings', () {
    for (final language in ['en', 'ar']) {
      testWidgets('compact groups fit 320dp 2x $language', (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = await _freshStorage();
        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            locale: Locale(language),
            textScaler: TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _openNavigationSheet(tester);
        expect(
          find.byKey(const Key('settings_startup_page_tile')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final close = find.byIcon(Icons.close).last;
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('settings_startup_page_tile')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('search exposes original settings and migration actions', (
      tester,
    ) async {
      final storage = await _freshStorage();
      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('settings_search_field'));
      for (final title in const [
        'Terminal Font Size',
        'Bottom Navigation Bar',
        'Export Configuration',
        'Import Configuration',
      ]) {
        await tester.enterText(input, title);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ListTile, title),
          findsOneWidget,
          reason: title,
        );
      }
      await tester.enterText(input, 'Terminal Font Size');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Terminal Font Size'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settingsTerminalFontSizeSlider')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders all enabled sections in bottom navigation checkboxes and startup dropdown',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = await _freshStorage();
        await storage.setExperimentalFeatures([
          ExperimentalFeature.cliChat.name,
          ExperimentalFeature.nas.name,
        ]);

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        await _openNavigationSheet(tester);

        // Verify startup tile exists and tapping opens dialog
        final tileFinder = find.byKey(const Key('settings_startup_page_tile'));
        expect(tileFinder, findsOneWidget);
        await tester.ensureVisible(tileFinder);
        await tester.pumpAndSettle();
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // All experiments are enabled, so every stable section is available.
        for (final section in AppSection.values) {
          expect(
            find.byKey(Key('settings_startup_page_radio_${section.name}')),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Every section also has a bottom-navigation checkbox.
        for (final section in AppSection.values) {
          expect(
            find.byKey(Key('settings_bottom_nav_checkbox_${section.name}')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('toggling bottom nav checkbox updates settings', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = await _freshStorage();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                locale: Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: SettingsView()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openNavigationSheet(tester);

      // Default bottom sections should contain dashboard, aiChat, terminal, sftp
      final initialSections = container
          .read(settingsProvider)
          .bottomNavigationSections;
      expect(initialSections, contains(AppSection.dashboard));

      // Tap dashboard checkbox to uncheck it
      final dashboardFinder = find.byKey(
        Key('settings_bottom_nav_checkbox_${AppSection.dashboard.name}'),
      );
      await tester.ensureVisible(dashboardFinder);
      await tester.pumpAndSettle();
      await tester.tap(dashboardFinder);
      await tester.pumpAndSettle();

      final updatedSections = container
          .read(settingsProvider)
          .bottomNavigationSections;
      expect(updatedSections.contains(AppSection.dashboard), isFalse);

      // Tap terminal checkbox to check it (terminal is not in defaultBottomNavigationSections)
      final terminalFinder = find.byKey(
        Key('settings_bottom_nav_checkbox_${AppSection.terminal.name}'),
      );
      await tester.ensureVisible(terminalFinder);
      await tester.pumpAndSettle();
      await tester.tap(terminalFinder);
      await tester.pumpAndSettle();

      final updatedSections2 = container
          .read(settingsProvider)
          .bottomNavigationSections;
      expect(updatedSections2.contains(AppSection.terminal), isTrue);
      expect(updatedSections2.last, AppSection.terminal);
      // 回归护栏：modal 必须读取最新 state。勾选 terminal 时若基于旧快照
      // 写回，dashboard 会复活；这里确认先前取消的 dashboard 保持取消。
      expect(
        updatedSections2.contains(AppSection.dashboard),
        isFalse,
        reason: '勾选 terminal 不得把先前取消的 dashboard 带回来',
      );
      expect(
        tester.widget<CheckboxListTile>(dashboardFinder).value,
        isFalse,
        reason: 'sheet 中的 dashboard 复选框应保持未勾选',
      );
    });

    testWidgets(
      'changing startup section updates settings independently of bottom nav',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = await _freshStorage();
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const MaterialApp(
                  locale: Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(body: SettingsView()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openNavigationSheet(tester);

        final tileFinder = find.byKey(const Key('settings_startup_page_tile'));
        await tester.ensureVisible(tileFinder);
        await tester.pumpAndSettle();
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Pick Settings section (index 7 or section name)
        final settingsItemFinder = find.text('Settings').last;
        await tester.tap(settingsItemFinder);
        await tester.pumpAndSettle();

        expect(
          container.read(settingsProvider).startupSection,
          AppSection.settings,
        );
      },
    );

    testWidgets('renders reorderable list of selected bottom nav items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = await _freshStorage();

      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      final reorderListFinder = find.byKey(
        const Key('settings_bottom_nav_reorder_list'),
      );
      await _openNavigationSheet(tester);
      expect(reorderListFinder, findsOneWidget);

      // Verify default items appear in the reorderable list.
      // 默认底栏已由 cliChat 迁移为 aiChat（见 local_storage_service.dart 的
      // 读时迁移与 defaultBottomNavigationSections）。
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.dashboard.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.aiChat.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.cliChat.name}')),
        findsNothing,
        reason: '默认底栏不得再包含 CLI 会话页',
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.docker.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.files.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.appCenter.name}')),
        findsOneWidget,
      );
    });

    testWidgets('language settings supports system default, zh and en', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = await _freshStorage();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                locale: Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: SettingsView()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap language tile to open dialog
      await tester.tap(find.byKey(const Key('settings_language_tile')));
      await tester.pumpAndSettle();

      // Tap English radio tile
      final enRadio = find.byKey(const Key('settings_lang_en'));
      expect(enRadio, findsOneWidget);
      await tester.tap(enRadio);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).locale, const Locale('en'));

      // Tap language tile again to open dialog
      await tester.tap(find.byKey(const Key('settings_language_tile')));
      await tester.pumpAndSettle();

      // Tap System default radio tile
      final systemRadio = find.byKey(const Key('settings_lang_system'));
      expect(systemRadio, findsOneWidget);
      await tester.tap(systemRadio);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).locale, const Locale('system'));
    });

    testWidgets('dashboard quick actions support toggling and reordering', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = await _freshStorage();
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                locale: Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: SettingsView()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial quick sections default to 6 items
      await _openNavigationSheet(tester);
      final initialQuick = container
          .read(settingsProvider)
          .dashboardQuickSections;
      expect(initialQuick, contains(AppSection.terminal));

      // Uncheck terminal
      final terminalCheckbox = find.byKey(
        Key('settings_dashboard_quick_checkbox_${AppSection.terminal.name}'),
      );
      expect(terminalCheckbox, findsOneWidget);
      await tester.ensureVisible(terminalCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(terminalCheckbox);
      await tester.pumpAndSettle();

      expect(
        container
            .read(settingsProvider)
            .dashboardQuickSections
            .contains(AppSection.terminal),
        isFalse,
      );

      // Re-check terminal
      await tester.tap(terminalCheckbox);
      await tester.pumpAndSettle();

      expect(
        container
            .read(settingsProvider)
            .dashboardQuickSections
            .contains(AppSection.terminal),
        isTrue,
      );
    });

    testWidgets('experimental features dialog toggles CLI chat and persists', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final storage = await _freshStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SettingsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('settings_experimental_features_tile'));
      final scrollable = find.byType(Scrollable).first;
      var scrollAttempts = 0;
      while (tile.evaluate().isEmpty && scrollAttempts < 40) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump();
        scrollAttempts++;
      }
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings_experimental_features_dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_experimental_app_center_tile')),
        findsNothing,
      );

      final cliTile = find.byKey(
        const Key('settings_experimental_cli_chat_tile'),
      );
      expect(tester.widget<CheckboxListTile>(cliTile).value, isFalse);

      await tester.tap(cliTile);
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(cliTile).value, isTrue);
      expect(storage.getExperimentalFeatures(), contains('cliChat'));

      await tester.tap(cliTile);
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(cliTile).value, isFalse);
      expect(storage.getExperimentalFeatures() ?? const <String>[], isEmpty);

      await tester.tap(
        find.byKey(const Key('settings_experimental_dialog_close_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings_experimental_features_dialog')),
        findsNothing,
      );
    });

    testWidgets(
      'experimental dialog keeps CLI and NAS checkboxes independent',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = await _freshStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(
          const Key('settings_experimental_features_tile'),
        );
        final scrollable = find.byType(Scrollable).first;
        var scrollAttempts = 0;
        while (tile.evaluate().isEmpty && scrollAttempts < 40) {
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pump();
          scrollAttempts++;
        }
        await tester.pumpAndSettle();
        expect(tile, findsOneWidget);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(tile, findsOneWidget);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        final cliTile = find.byKey(
          const Key('settings_experimental_cli_chat_tile'),
        );
        final nasTile = find.byKey(const Key('settings_experimental_nas_tile'));
        expect(tester.widget<CheckboxListTile>(cliTile).value, isFalse);
        expect(tester.widget<CheckboxListTile>(nasTile).value, isFalse);

        await tester.tap(nasTile);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(nasTile).value, isTrue);
        expect(tester.widget<CheckboxListTile>(cliTile).value, isFalse);
        expect(storage.getExperimentalFeatures(), ['nas']);

        await tester.tap(cliTile);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(cliTile).value, isTrue);
        expect(tester.widget<CheckboxListTile>(nasTile).value, isTrue);
        expect(
          storage.getExperimentalFeatures(),
          containsAll(['nas', 'cliChat']),
        );

        await tester.tap(nasTile);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(nasTile).value, isFalse);
        expect(tester.widget<CheckboxListTile>(cliTile).value, isTrue);
        expect(storage.getExperimentalFeatures(), ['cliChat']);
      },
    );
  });
}
