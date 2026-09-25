import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/dashboard/dashboard_provider.dart';
import 'package:valhalla/features/dashboard/dashboard_view.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/features/settings/widgets/theme_accent_color_dialog.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/l10n/app_localizations.dart';

Future<LocalStorageService> _freshStorage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

Widget _buildSettingsApp({
  required LocalStorageService storage,
  void Function(ProviderContainer container)? onContainer,
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    child: Consumer(
      builder: (context, ref, _) {
        if (onContainer != null) {
          onContainer(ProviderScope.containerOf(context));
        }
        return MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsView()),
        );
      },
    ),
  );
}

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _FakeActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _initial;
  _FakeConnectionNotifier(this._initial);
  @override
  ServerConnectionState build() => _initial;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Settings Theme Mode and Custom Accent Colors', () {
    testWidgets('single-select theme mode dialog updates themeMode', (
      tester,
    ) async {
      final storage = await _freshStorage();
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildSettingsApp(storage: storage, onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('settings_theme_mode_tile'));
      expect(tile, findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Dialog opens with 4 theme mode radios
      expect(find.byKey(const Key('settings_theme_mode_dark')), findsOneWidget);
      expect(
        find.byKey(const Key('settings_theme_mode_amoled')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings_theme_mode_dark')));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).themeMode, AppThemeMode.dark);
    });

    testWidgets(
      'accent color tile opens dialog and independently configures Light, Dark, AMOLED colors',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final storage = await _freshStorage();
        late ProviderContainer container;

        await tester.pumpWidget(
          _buildSettingsApp(
            storage: storage,
            onContainer: (c) => container = c,
          ),
        );
        await tester.pumpAndSettle();

        final accentTile = find.byKey(const Key('settings_accent_color_tile'));
        expect(accentTile, findsOneWidget);

        await tester.tap(accentTile);
        await tester.pumpAndSettle();

        // ThemeAccentColorDialog is displayed
        expect(find.byType(ThemeAccentColorDialog), findsOneWidget);

        // Enter hex code for light mode
        final hexInput = find.byKey(const Key('accent_hex_input'));
        expect(hexInput, findsOneWidget);

        await tester.enterText(hexInput, '3B82F6');
        await tester.pumpAndSettle();

        // Switch to Dark mode tab
        await tester.tap(find.byKey(const Key('accent_color_tab_dark')));
        await tester.pumpAndSettle();

        await tester.enterText(hexInput, 'EF4444');
        await tester.pumpAndSettle();

        // Switch to AMOLED mode tab
        await tester.tap(find.byKey(const Key('accent_color_tab_amoled')));
        await tester.pumpAndSettle();

        await tester.enterText(hexInput, '8B5CF6');
        await tester.pumpAndSettle();

        // Confirm
        await tester.tap(find.byKey(const Key('accent_color_confirm_button')));
        await tester.pumpAndSettle();

        final state = container.read(settingsProvider);
        expect(state.lightAccentColor.toARGB32() & 0xFFFFFF, 0x3B82F6);
        expect(state.darkAccentColor.toARGB32() & 0xFFFFFF, 0xEF4444);
        expect(state.amoledAccentColor.toARGB32() & 0xFFFFFF, 0x8B5CF6);
      },
    );

    testWidgets('cancelling accent color dialog discards changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = await _freshStorage();
      late ProviderContainer container;

      await tester.pumpWidget(
        _buildSettingsApp(storage: storage, onContainer: (c) => container = c),
      );
      await tester.pumpAndSettle();

      final initialLight = container.read(settingsProvider).lightAccentColor;

      await tester.tap(find.byKey(const Key('settings_accent_color_tile')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('accent_hex_input')),
        'FF0000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        container.read(settingsProvider).lightAccentColor,
        equals(initialLight),
      );
    });

    testWidgets(
      'invalid or incomplete hex disables confirm button and displays error',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final storage = await _freshStorage();
        await tester.pumpWidget(_buildSettingsApp(storage: storage));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_accent_color_tile')));
        await tester.pumpAndSettle();

        final hexInput = find.byKey(const Key('accent_hex_input'));
        final confirmButton = find.byKey(
          const Key('accent_color_confirm_button'),
        );

        // Initially enabled with existing valid color
        expect(tester.widget<FilledButton>(confirmButton).enabled, isTrue);

        // Enter incomplete hex (3 chars)
        await tester.enterText(hexInput, '123');
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(confirmButton).enabled, isFalse);

        // Enter invalid hex (6 non-hex chars)
        await tester.enterText(hexInput, 'ZZZZZZ');
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(confirmButton).enabled, isFalse);

        // Enter valid 6-char hex
        await tester.enterText(hexInput, '10B981');
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(confirmButton).enabled, isTrue);
      },
    );

    testWidgets(
      'system mode dialog defaults to current system brightness slot',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final storage = await _freshStorage();
        // Default themeMode is system
        await tester.pumpWidget(
          _buildSettingsApp(storage: storage, brightness: Brightness.dark),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_accent_color_tile')));
        await tester.pumpAndSettle();

        // Under dark system brightness, segment dark should be active
        final segmentedButton = tester.widget<SegmentedButton<AppThemeMode>>(
          find.byType(SegmentedButton<AppThemeMode>),
        );
        expect(segmentedButton.selected, contains(AppThemeMode.dark));
      },
    );

    testWidgets(
      'compact mobile screen renders fullscreen dialog with fixed bottom bar and dismisses on close',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final storage = await _freshStorage();
        await tester.pumpWidget(_buildSettingsApp(storage: storage));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings_accent_color_tile')));
        await tester.pumpAndSettle();

        expect(find.byType(ThemeAccentColorDialog), findsOneWidget);
        expect(
          find.byKey(const Key('accent_color_confirm_button')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.close), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byType(ThemeAccentColorDialog), findsNothing);
      },
    );
  });

  group('Dashboard quick actions visibility', () {
    testWidgets(
      'empty dashboardQuickSections completely hides quick actions section',
      (tester) async {
        final storage = await _freshStorage();
        await storage.setDashboardQuickSections([]);

        const server = ServerProfile(
          id: 'srv-1',
          name: 'Test Server',
          host: '1.2.3.4',
          port: 22,
          username: 'root',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(storage),
              activeServerProvider.overrideWith(
                () => _FakeActiveServerNotifier(server),
              ),
              serverConnectionProvider.overrideWith(
                () => _FakeConnectionNotifier(
                  const ServerConnectionState(
                    status: ConnectionStateEnum.connected,
                  ),
                ),
              ),
              systemMetricsStreamProvider.overrideWith(
                (ref) => Stream.value(
                  const SystemMetricsSnapshot(
                    cpuUsedRatio: 0.1,
                    memoryUsedRatio: 0.2,
                    rootDiskUsedPercent: 30,
                    uptimeSeconds: 100,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Quick actions title should not be rendered
        expect(find.text('Quick Navigation'), findsNothing);
      },
    );
  });
}
