import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/extensions/context_extensions.dart';
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
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(prefs);
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
            // 显式开启实验特性：本用例断言全部 10 个条目可见。
            enabledExperimentalFeatures: {
              ExperimentalFeature.cliChat,
              ExperimentalFeature.nas,
            },
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

    testWidgets('desktop rail respects configured selection and order', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1200, 900),
        settingsState: const SettingsState(
          // 与保存顺序一致的三项，实验特性保持默认关闭。
          bottomNavigationSections: [
            AppSection.files,
            AppSection.terminal,
            AppSection.dashboard,
          ],
        ),
      );

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);

      final rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.destinations.length, 3);

      final l10n = tester.element(find.byType(MainShell)).l10n;
      final labels = rail.destinations
          .map((d) => (d.label as Text).data)
          .toList(growable: false);
      expect(labels, [l10n.navFiles, l10n.navTerminal, l10n.navDashboard]);

      final icons = rail.destinations
          .map((d) => (d.icon as Icon).icon)
          .toList(growable: false);
      expect(icons, [
        Icons.folder_outlined,
        Icons.terminal_outlined,
        Icons.dashboard_outlined,
      ]);

      // Tap the first rail entry (files) -> stable view index 3.
      final filesIcon = find.descendant(
        of: railFinder,
        matching: find.byIcon(Icons.folder_outlined),
      );
      expect(filesIcon, findsOneWidget);
      await tester.tap(filesIcon);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack).first,
      );
      expect(stack.index, 3);
    });

    testWidgets('medium rail respects configured order with stable index', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(800, 900),
        settingsState: const SettingsState(
          bottomNavigationSections: [
            AppSection.terminal,
            AppSection.files,
            AppSection.dashboard,
          ],
        ),
      );

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);

      final rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.destinations.length, 3);

      final l10n = tester.element(find.byType(MainShell)).l10n;
      expect(rail.destinations.map((d) => (d.label as Text).data).toList(), [
        l10n.navTerminal,
        l10n.navFiles,
        l10n.navDashboard,
      ]);

      final terminalIcon = find.descendant(
        of: railFinder,
        matching: find.byIcon(Icons.terminal_outlined),
      );
      await tester.tap(terminalIcon);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<AnimatedIndexedStack>(
              find.byType(AnimatedIndexedStack).first,
            )
            .index,
        2,
      );
    });

    testWidgets(
      'desktop empty selection hides rail and divider, drawer reaches Settings',
      (tester) async {
        await _pumpShell(
          tester,
          size: const Size(1200, 900),
          settingsState: const SettingsState(bottomNavigationSections: []),
        );

        expect(find.byType(NavigationRail), findsNothing);
        expect(
          find.descendant(
            of: find.byType(MainShell),
            matching: find.byType(VerticalDivider),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        // The top menu button keeps Settings reachable without a rail.
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);

        final settingsTile = find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.settings_outlined),
        );
        expect(settingsTile, findsOneWidget);
        await tester.tap(settingsTile);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          7,
        );
      },
    );

    testWidgets(
      'medium empty selection hides rail and divider, drawer reaches Settings',
      (tester) async {
        await _pumpShell(
          tester,
          size: const Size(800, 900),
          settingsState: const SettingsState(bottomNavigationSections: []),
        );

        expect(find.byType(NavigationRail), findsNothing);
        expect(
          find.descendant(
            of: find.byType(MainShell),
            matching: find.byType(VerticalDivider),
          ),
          findsNothing,
        );

        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();

        final settingsTile = find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.settings_outlined),
        );
        expect(settingsTile, findsOneWidget);
        await tester.tap(settingsTile);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          7,
        );
      },
    );

    testWidgets('single pinned section renders one selected destination', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1200, 900),
        settingsState: const SettingsState(
          startupSection: AppSection.terminal,
          bottomNavigationSections: [AppSection.terminal],
        ),
      );

      final railFinder = find.byType(NavigationRail);
      final rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.destinations.length, 1);
      expect(rail.selectedIndex, 0);

      await tester.tap(
        find.descendant(of: railFinder, matching: find.byIcon(Icons.terminal)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rail.selectedIndex, 0);
      expect(
        tester
            .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
            .index,
        2,
      );
    });

    testWidgets('active unpinned page leaves rail selection empty', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1200, 900),
        settingsState: const SettingsState(
          startupSection: AppSection.settings,
          bottomNavigationSections: [AppSection.files],
        ),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations.length, 1);
      expect(rail.selectedIndex, isNull);
      expect(
        tester
            .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
            .index,
        7,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'all sections pinned in short desktop window scroll without overflow',
      (tester) async {
        await _pumpShell(
          tester,
          size: const Size(1200, 400),
          settingsState: const SettingsState(
            bottomNavigationSections: AppSection.values,
            enabledExperimentalFeatures: {
              ExperimentalFeature.cliChat,
              ExperimentalFeature.nas,
            },
          ),
        );

        final railFinder = find.byType(NavigationRail);
        final rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.destinations.length, 10);
        expect(rail.scrollable, isTrue);
        expect(tester.takeException(), isNull);

        // Disconnect stays reachable in the trailing area.
        expect(
          find.descendant(
            of: railFinder,
            matching: find.byIcon(Icons.power_settings_new),
          ),
          findsOneWidget,
        );

        // The last pinned entry needs scrolling, not overflow.
        final lastIcon = find.descendant(
          of: railFinder,
          matching: find.byIcon(Icons.perm_media_outlined),
        );
        await tester.scrollUntilVisible(
          lastIcon,
          40,
          scrollable: find.descendant(
            of: railFinder,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(lastIcon, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'runtime experiment toggles filter rail without losing saved order',
      (tester) async {
        final container = await _pumpShell(
          tester,
          size: const Size(1200, 900),
          prefs: const {
            'valhalla_bottom_navigation_v1': <String>[
              'dashboard',
              'nas',
              'files',
              'cliChat',
            ],
            'valhalla_navigation_acp_v2': true,
          },
        );

        List<String> labels() {
          final rail = tester.widget<NavigationRail>(
            find.byType(NavigationRail),
          );
          return rail.destinations
              .map((d) => (d.label as Text).data!)
              .toList(growable: false);
        }

        final l10n = tester.element(find.byType(MainShell)).l10n;

        // NAS/CLI pinned in storage but not enabled yet: filtered out.
        expect(labels(), [l10n.navDashboard, l10n.navFiles]);

        final notifier = container.read(settingsProvider.notifier);
        await notifier.setExperimentalFeature(ExperimentalFeature.nas, true);
        await tester.pumpAndSettle();
        expect(labels(), [l10n.navDashboard, l10n.navNas, l10n.navFiles]);

        // Active experimental page returns to dashboard when the switch closes.
        final nasIcon = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.perm_media_outlined),
        );
        await tester.tap(nasIcon);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          9,
        );

        await notifier.setExperimentalFeature(ExperimentalFeature.nas, false);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          0,
        );
        expect(labels(), [l10n.navDashboard, l10n.navFiles]);

        await notifier.setExperimentalFeature(
          ExperimentalFeature.cliChat,
          true,
        );
        await tester.pumpAndSettle();
        expect(labels(), [l10n.navDashboard, l10n.navFiles, l10n.navCliChat]);

        // Saved positions survive enable/disable cycles.
        expect(
          container
              .read(settingsProvider)
              .bottomNavigationSections
              .map((s) => s.name),
          ['dashboard', 'nas', 'files', 'cliChat'],
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
