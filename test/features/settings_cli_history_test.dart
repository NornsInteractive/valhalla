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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsView CLI History Page Size', () {
    testWidgets(
      'displays tile with default value 10 and opens dialog with values 5..100 step 5',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 2500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = await _freshStorage();
        final container = ProviderContainer(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check tile exists
        final tileFinder = find.byKey(
          const Key('settings_cli_history_page_size_tile'),
        );
        expect(tileFinder, findsOneWidget);
        expect(container.read(settingsProvider).cliHistoryPageSize, 10);

        // Open dialog
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Verify all 20 options from 5 to 100 in steps of 5 exist
        for (var size = 5; size <= 100; size += 5) {
          expect(
            find.byKey(Key('settings_cli_history_page_size_radio_$size')),
            findsOneWidget,
          );
        }

        // Cancel button dismisses
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(container.read(settingsProvider).cliHistoryPageSize, 10);
      },
    );

    testWidgets(
      'selecting a new page size calls setCliHistoryPageSize and updates state',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 2500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final storage = await _freshStorage();
        final container = ProviderContainer(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SettingsView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.byKey(
          const Key('settings_cli_history_page_size_tile'),
        );
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        // Select 25
        final option25 = find.byKey(
          const Key('settings_cli_history_page_size_radio_25'),
        );
        await tester.tap(option25);
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);
        expect(container.read(settingsProvider).cliHistoryPageSize, 25);
        expect(storage.getCliHistoryPageSize(), 25);
      },
    );
  });
}
