// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/auto_connect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _SpyAutoConnectNotifier extends AutoConnectSettingsNotifier {
  final AutoConnectSettings initial;
  final List<AutoConnectMode> setModeCalls = [];
  final List<String?> setFixedServerIdCalls = [];

  _SpyAutoConnectNotifier({this.initial = const AutoConnectSettings()});

  @override
  AutoConnectSettings build() => initial;

  @override
  Future<void> setMode(AutoConnectMode mode) async {
    setModeCalls.add(mode);
    state = state.copyWith(mode: mode);
  }

  @override
  Future<void> setFixedServerId(String? id) async {
    setFixedServerIdCalls.add(id);
    state = AutoConnectSettings(mode: state.mode, fixedServerId: id);
  }

  void updateStateExternally(AutoConnectSettings newSettings) {
    state = newSettings;
  }
}

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier([this._servers = const []]);

  @override
  List<ServerProfile> build() => _servers;
}

ServerProfile _makeServer({
  required String id,
  required String name,
  String host = '192.168.1.100',
  int port = 22,
  String username = 'root',
}) {
  return ServerProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
  );
}

LocalStorageService? _testStorage;

Widget _buildSettingsApp({
  required List<dynamic> overrides,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      if (_testStorage != null)
        localStorageServiceProvider.overrideWithValue(_testStorage!),
      ...overrides,
    ].cast(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SettingsView()),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _testStorage = LocalStorageService(await SharedPreferences.getInstance());
  });

  group('SettingsView auto connect card', () {
    testWidgets('1. defaults to lastConnected option selected', (tester) async {
      tester.view.physicalSize = const Size(1024, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _SpyAutoConnectNotifier(
        initial: const AutoConnectSettings(mode: AutoConnectMode.lastConnected),
      );

      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [
            autoConnectSettingsProvider.overrideWith(() => spy),
            serverListProvider.overrideWith(
              () => _TestServerListNotifier([
                _makeServer(id: 's1', name: 'Server 1'),
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap mode tile to open dialog
      await tester.tap(
        find.byKey(const Key('settings_auto_connect_mode_tile')),
      );
      await tester.pumpAndSettle();

      final lastRadioFinder = find.byKey(
        const Key('settingsAutoConnectLastRadio'),
      );
      final fixedRadioFinder = find.byKey(
        const Key('settingsAutoConnectFixedRadio'),
      );

      expect(lastRadioFinder, findsOneWidget);
      expect(fixedRadioFinder, findsOneWidget);

      final lastRadio = tester.widget<RadioListTile<AutoConnectMode>>(
        lastRadioFinder,
      );
      final fixedRadio = tester.widget<RadioListTile<AutoConnectMode>>(
        fixedRadioFinder,
      );

      expect(lastRadio.groupValue, equals(AutoConnectMode.lastConnected));
      expect(lastRadio.checked, isTrue);
      expect(fixedRadio.checked, isFalse);
    });

    testWidgets(
      '2. tapping fixed invokes setMode(fixed) and server picker appears',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyAutoConnectNotifier(
          initial: const AutoConnectSettings(
            mode: AutoConnectMode.lastConnected,
          ),
        );

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              autoConnectSettingsProvider.overrideWith(() => spy),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([
                  _makeServer(id: 's1', name: 'Server Alpha'),
                ]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settingsAutoConnectServerTile')),
          findsNothing,
        );

        // Tap mode tile to open dialog
        await tester.tap(
          find.byKey(const Key('settings_auto_connect_mode_tile')),
        );
        await tester.pumpAndSettle();

        // Tap fixed radio
        await tester.tap(
          find.byKey(const Key('settingsAutoConnectFixedRadio')),
        );
        await tester.pumpAndSettle();

        expect(spy.setModeCalls, contains(AutoConnectMode.fixed));
        expect(
          find.byKey(const Key('settingsAutoConnectServerTile')),
          findsOneWidget,
        );
      },
    );

    testWidgets('3. shows settingsAutoConnectNoServer when none specified', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _SpyAutoConnectNotifier(
        initial: const AutoConnectSettings(
          mode: AutoConnectMode.fixed,
          fixedServerId: null,
        ),
      );

      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [
            autoConnectSettingsProvider.overrideWith(() => spy),
            serverListProvider.overrideWith(
              () => _TestServerListNotifier([
                _makeServer(id: 's1', name: 'Server Alpha'),
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        find.byKey(const Key('settingsAutoConnectServerTile')),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsAutoConnectNoServer), findsOneWidget);
    });

    testWidgets(
      '4. picking a server displays name and invokes setFixedServerId',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyAutoConnectNotifier(
          initial: const AutoConnectSettings(
            mode: AutoConnectMode.fixed,
            fixedServerId: null,
          ),
        );

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              autoConnectSettingsProvider.overrideWith(() => spy),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([
                  _makeServer(id: 's1', name: 'Server Alpha'),
                  _makeServer(id: 's2', name: 'Server Beta'),
                ]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap server picker tile
        await tester.tap(
          find.byKey(const Key('settingsAutoConnectServerTile')),
        );
        await tester.pumpAndSettle();

        // Dialog opens with server list
        expect(find.text('Server Beta'), findsOneWidget);

        // Select Server Beta
        await tester.tap(find.text('Server Beta'));
        await tester.pumpAndSettle();

        expect(spy.setFixedServerIdCalls, contains('s2'));
        expect(find.text('Server Beta'), findsOneWidget);
      },
    );

    testWidgets(
      '5. server picker does not appear when lastConnected is selected',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyAutoConnectNotifier(
          initial: const AutoConnectSettings(
            mode: AutoConnectMode.fixed,
            fixedServerId: 's1',
          ),
        );

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              autoConnectSettingsProvider.overrideWith(() => spy),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([
                  _makeServer(id: 's1', name: 'Server Alpha'),
                ]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Initially visible under fixed mode
        expect(
          find.byKey(const Key('settingsAutoConnectServerTile')),
          findsOneWidget,
        );

        // Tap mode tile to open dialog
        await tester.tap(
          find.byKey(const Key('settings_auto_connect_mode_tile')),
        );
        await tester.pumpAndSettle();

        // Tap lastConnected
        await tester.tap(find.byKey(const Key('settingsAutoConnectLastRadio')));
        await tester.pumpAndSettle();

        expect(spy.setModeCalls, contains(AutoConnectMode.lastConnected));
        expect(
          find.byKey(const Key('settingsAutoConnectServerTile')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '6. server picker does not appear when server list is empty even if fixed is selected',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyAutoConnectNotifier(
          initial: const AutoConnectSettings(
            mode: AutoConnectMode.fixed,
            fixedServerId: 's1',
          ),
        );

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              autoConnectSettingsProvider.overrideWith(() => spy),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier(const []),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settingsAutoConnectServerTile')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'reads autoConnectSettingsProvider via ref.read (external provider update does not trigger rebuild)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyAutoConnectNotifier(
          initial: const AutoConnectSettings(
            mode: AutoConnectMode.lastConnected,
          ),
        );

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              autoConnectSettingsProvider.overrideWith(() => spy),
              serverListProvider.overrideWith(
                () => _TestServerListNotifier([
                  _makeServer(id: 's1', name: 'Server 1'),
                ]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog to check initial radio
        await tester.tap(
          find.byKey(const Key('settings_auto_connect_mode_tile')),
        );
        await tester.pumpAndSettle();

        final lastRadioFinder = find.byKey(
          const Key('settingsAutoConnectLastRadio'),
        );
        expect(
          tester
              .widget<RadioListTile<AutoConnectMode>>(lastRadioFinder)
              .checked,
          isTrue,
        );

        // Dismiss dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Update provider state externally
        spy.updateStateExternally(
          const AutoConnectSettings(mode: AutoConnectMode.fixed),
        );
        await tester.pump();

        // Since ref.read was used without watching in the card, the tile subtitle was built with ref.read and does not rebuild
        expect(
          find.descendant(
            of: find.byKey(const Key('settings_auto_connect_mode_tile')),
            matching: find.textContaining('Server 1'),
          ),
          findsNothing,
        );
      },
    );
  });
}
