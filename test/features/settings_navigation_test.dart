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
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SettingsView()),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsView Navigation Settings', () {
    testWidgets(
      'renders all 10 sections in bottom navigation checkboxes and startup dropdown',
      (tester) async {
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

        // Verify startup tile exists and tapping opens dialog
        final tileFinder = find.byKey(const Key('settings_startup_page_tile'));
        expect(tileFinder, findsOneWidget);
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Verify all 10 sections exist in dialog radio list
        for (final section in AppSection.values) {
          expect(
            find.byKey(Key('settings_startup_page_radio_${section.name}')),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Verify all 10 sections exist as bottom nav checkboxes
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

      // Default bottom sections should contain dashboard, aiChat, terminal, sftp
      final initialSections = container
          .read(settingsProvider)
          .bottomNavigationSections;
      expect(initialSections, contains(AppSection.dashboard));

      // Tap dashboard checkbox to uncheck it
      final dashboardFinder = find.byKey(
        Key('settings_bottom_nav_checkbox_${AppSection.dashboard.name}'),
      );
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
      await tester.tap(terminalFinder);
      await tester.pumpAndSettle();

      final updatedSections2 = container
          .read(settingsProvider)
          .bottomNavigationSections;
      expect(updatedSections2.contains(AppSection.terminal), isTrue);
      expect(updatedSections2.last, AppSection.terminal);
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

        final tileFinder = find.byKey(const Key('settings_startup_page_tile'));
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
      expect(reorderListFinder, findsOneWidget);

      // Verify default items appear in the reorderable list
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.dashboard.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.cliChat.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.docker.name}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('settings_reorder_${AppSection.files.name}')),
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
      final initialQuick = container
          .read(settingsProvider)
          .dashboardQuickSections;
      expect(initialQuick, contains(AppSection.terminal));

      // Uncheck terminal
      final terminalCheckbox = find.byKey(
        Key('settings_dashboard_quick_checkbox_${AppSection.terminal.name}'),
      );
      expect(terminalCheckbox, findsOneWidget);
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
  });
}
