import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/core/design/motion_widgets.dart';

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _TestServerListNotifier extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [];
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

class _CustomSettingsNotifier extends SettingsNotifier {
  final SettingsState _customState;
  _CustomSettingsNotifier(this._customState);

  @override
  SettingsState build() => _customState;
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(500, 900),
  SettingsState? settingsState,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      serverListProvider.overrideWith(_TestServerListNotifier.new),
      activeServerProvider.overrideWith(_TestActiveServerNotifier.new),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
      if (settingsState != null)
        settingsProvider.overrideWith(
          () => _CustomSettingsNotifier(settingsState),
        ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('MainShell Dynamic Bottom Navigation & Startup', () {
    testWidgets('starts with startupSection from settings', (tester) async {
      await _pumpShell(
        tester,
        settingsState: const SettingsState(startupSection: AppSection.terminal),
      );

      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack).first,
      );
      expect(stack.index, 2); // Terminal is index 2
    });

    testWidgets('when bottomNavigationSections is empty, bottom bar is null', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        settingsState: const SettingsState(bottomNavigationSections: []),
      );

      expect(find.byType(MainBottomNavigationBar), findsNothing);
    });

    testWidgets(
      'renders all 10 sections in bottom navigation without overflow and allows tapping',
      (tester) async {
        await _pumpShell(
          tester,
          settingsState: const SettingsState(
            bottomNavigationSections: AppSection.values,
          ),
        );

        final navBarFinder = find.byType(MainBottomNavigationBar);
        expect(navBarFinder, findsOneWidget);

        final navBar = tester.widget<MainBottomNavigationBar>(navBarFinder);
        expect(navBar.sections.length, 10);
        expect(tester.takeException(), isNull);

        // Scroll until settings icon is visible and tap
        final settingsIcon = find.descendant(
          of: navBarFinder,
          matching: find.byIcon(Icons.settings_outlined),
        );
        expect(settingsIcon, findsOneWidget);
        await tester.scrollUntilVisible(
          settingsIcon,
          50,
          scrollable: find.descendant(
            of: navBarFinder,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();

        final stack = tester.widget<AnimatedIndexedStack>(
          find.byType(AnimatedIndexedStack).first,
        );
        expect(stack.index, 7); // Settings is index 7
      },
    );

    testWidgets(
      'navigating to section not in bottom bar from drawer does not crash',
      (tester) async {
        await _pumpShell(
          tester,
          settingsState: const SettingsState(
            bottomNavigationSections: [
              AppSection.dashboard,
              AppSection.terminal,
            ],
          ),
        );

        // Open drawer
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsOneWidget);

        // Tap files in drawer (index 3, not in bottom bar)
        final filesDrawerItem = find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.folder_outlined),
        );
        expect(filesDrawerItem, findsOneWidget);
        await tester.tap(filesDrawerItem);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final stack = tester.widget<AnimatedIndexedStack>(
          find.byType(AnimatedIndexedStack).first,
        );
        expect(stack.index, 3); // Files is index 3
      },
    );

    testWidgets('desktop NavigationRail always displays all 10 sections', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1200, 900),
        settingsState: const SettingsState(
          bottomNavigationSections: [AppSection.dashboard],
        ),
      );

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);

      final rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.destinations.length, 10);
    });
  });
}
