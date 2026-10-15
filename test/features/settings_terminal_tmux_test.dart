import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import '../support/seeded_terminal_notifier.dart';

const _tmuxStorageKey = 'valhalla_terminal_use_tmux_v1';

class _SpyTerminalSettingsNotifier extends TerminalSettingsNotifier {
  final bool initialUseTmux;
  final List<bool> setUseTmuxCalls = [];
  bool failSave = false;

  _SpyTerminalSettingsNotifier({this.initialUseTmux = false});

  @override
  TerminalSettings build() {
    return TerminalSettings(useTmux: initialUseTmux);
  }

  @override
  Future<void> setUseTmux(bool enabled) async {
    setUseTmuxCalls.add(enabled);
    if (failSave) throw StateError('fixture mode save failure');
    state = state.copyWith(useTmux: enabled);
  }
}

Future<LocalStorageService> _freshStorage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

Widget _buildSettingsApp({
  required List<dynamic> overrides,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      ...terminalWorkspaceOverrides().skip(1), // Callers provide real storage.
      terminalProvider.overrideWith(
        () => SeededTerminalNotifier(SshTerminalState(tabs: const [])),
      ),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SshTerminalView(active: false)),
    ),
  );
}

Future<void> _selectMode(WidgetTester tester, bool tmux) async {
  await tester.tap(find.byKey(const Key('terminalDefaultModeButton')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(
      Key(tmux ? 'terminalModeTmuxRadio' : 'terminalModeStandardRadio'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SSH terminal default mode', () {
    testWidgets('mode entry is no longer in SettingsView', (tester) async {
      final storage = await _freshStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SettingsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final security = find.byKey(const Key('settings_security_tile'));
      await tester.ensureVisible(security);
      await tester.pumpAndSettle();
      await tester.tap(security);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settingsTerminalFontSizeRow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settingsTerminalUseTmuxSwitch')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('cancelling mode selection changes nothing', (tester) async {
      tester.view.physicalSize = const Size(1024, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final spy = _SpyTerminalSettingsNotifier();
      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [
            terminalSettingsProvider.overrideWith(() => spy),
            localStorageServiceProvider.overrideWithValue(
              await _freshStorage(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('terminalDefaultModeButton')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(spy.setUseTmuxCalls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'mode save failure stays in dialog without changing the effective mode',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final spy = _SpyTerminalSettingsNotifier()..failSave = true;
        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              terminalSettingsProvider.overrideWith(() => spy),
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _selectMode(tester, true);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(spy.setUseTmuxCalls, [true]);
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(SshTerminalView)),
        );
        expect(scope.read(terminalSettingsProvider).useTmux, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'renders tmux toggle with title, subtitle, description in English (default off)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyTerminalSettingsNotifier(initialUseTmux: false);

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              terminalSettingsProvider.overrideWith(() => spy),
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('terminalDefaultModeButton')));
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.settingsTerminalUseTmux), findsOneWidget);
        expect(find.text(l10n.terminalModeStandard), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalUseTmuxDescription),
          findsOneWidget,
        );

        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('terminalDefaultModeButton')),
              )
              .onPressed,
          isNotNull,
        );
        expect(spy.setUseTmuxCalls, isEmpty);
      },
    );

    testWidgets(
      'renders tmux toggle with title, subtitle, description in Chinese',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spy = _SpyTerminalSettingsNotifier(initialUseTmux: true);

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              terminalSettingsProvider.overrideWith(() => spy),
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
            locale: const Locale('zh'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('terminalDefaultModeButton')));
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
        expect(find.text(l10n.settingsTerminalUseTmux), findsOneWidget);
        expect(find.text(l10n.terminalModeTmux), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalUseTmuxDescription),
          findsOneWidget,
        );

        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('terminalDefaultModeButton')),
              )
              .onPressed,
          isNotNull,
        );
        expect(spy.setUseTmuxCalls, isEmpty);
      },
    );

    testWidgets('tapping toggle invokes setUseTmux with new value', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _SpyTerminalSettingsNotifier(initialUseTmux: false);

      await tester.pumpWidget(
        _buildSettingsApp(
          overrides: [
            terminalSettingsProvider.overrideWith(() => spy),
            localStorageServiceProvider.overrideWithValue(
              await _freshStorage(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the switch to turn it on
      await _selectMode(tester, true);

      expect(spy.setUseTmuxCalls, [true]);
      expect(spy.state.useTmux, isTrue);

      // Tap the switch to turn it off
      await _selectMode(tester, false);

      expect(spy.setUseTmuxCalls, [true, false]);
      expect(spy.state.useTmux, isFalse);
    });

    testWidgets(
      'end-to-end integration with LocalStorageService and SharedPreferences',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final localStorage = LocalStorageService(prefs);

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(localStorage),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SshTerminalView)),
        );
        expect(container.read(terminalSettingsProvider).useTmux, isFalse);
        expect(prefs.getBool(_tmuxStorageKey), isNull);

        // Toggle on
        await _selectMode(tester, true);

        expect(container.read(terminalSettingsProvider).useTmux, isTrue);
        expect(prefs.getBool(_tmuxStorageKey), isTrue);

        // Toggle off
        await _selectMode(tester, false);

        expect(container.read(terminalSettingsProvider).useTmux, isFalse);
        expect(prefs.getBool(_tmuxStorageKey), isFalse);
      },
    );
  });
}
