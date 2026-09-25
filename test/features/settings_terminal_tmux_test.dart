import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _tmuxStorageKey = 'valhalla_terminal_use_tmux_v1';

class _SpyTerminalSettingsNotifier extends TerminalSettingsNotifier {
  final bool initialUseTmux;
  final List<bool> setUseTmuxCalls = [];

  _SpyTerminalSettingsNotifier({this.initialUseTmux = false});

  @override
  TerminalSettings build() {
    return TerminalSettings(useTmux: initialUseTmux);
  }

  @override
  Future<void> setUseTmux(bool enabled) async {
    setUseTmuxCalls.add(enabled);
    state = state.copyWith(useTmux: enabled);
  }
}

/// 一个什么都不预置的存储，供只想测 tmux 开关的用例使用。
///
/// 设置页现在还有自动连接卡片，它经 `autoConnectSettingsProvider` 读
/// `localStorageServiceProvider`；后者默认是抛 `UnimplementedError` 的占位，
/// 不注入会让整个设置页构建失败（不只是那张卡片）。
Future<LocalStorageService> _freshStorage() async =>
    LocalStorageService(await SharedPreferences.getInstance());

Widget _buildSettingsApp({
  required List<dynamic> overrides,
  Locale locale = const Locale('en'),
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

  group('SettingsView terminal tmux toggle', () {
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
              // 设置页现在还有自动连接卡片，它读 autoConnectSettingsProvider
              // -> localStorageServiceProvider；不注入会让整页构建失败。
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
            locale: const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(
          const Key('settingsTerminalUseTmuxSwitch'),
        );
        expect(switchFinder, findsOneWidget);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.settingsTerminalUseTmux), findsOneWidget);
        expect(find.text(l10n.settingsTerminalUseTmuxSubtitle), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalUseTmuxDescription),
          findsOneWidget,
        );

        final switchWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(switchWidget.value, isFalse);
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

        final switchFinder = find.byKey(
          const Key('settingsTerminalUseTmuxSwitch'),
        );
        expect(switchFinder, findsOneWidget);

        final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
        expect(find.text(l10n.settingsTerminalUseTmux), findsOneWidget);
        expect(find.text(l10n.settingsTerminalUseTmuxSubtitle), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalUseTmuxDescription),
          findsOneWidget,
        );

        final switchWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(switchWidget.value, isTrue);
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

      final switchFinder = find.byKey(
        const Key('settingsTerminalUseTmuxSwitch'),
      );
      expect(switchFinder, findsOneWidget);

      // Tap the switch to turn it on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(spy.setUseTmuxCalls, [true]);
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);

      // Tap the switch to turn it off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(spy.setUseTmuxCalls, [true, false]);
      final updatedSwitchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(updatedSwitchWidget.value, isFalse);
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

        final switchFinder = find.byKey(
          const Key('settingsTerminalUseTmuxSwitch'),
        );
        expect(switchFinder, findsOneWidget);

        // Initially false
        expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
        expect(prefs.getBool(_tmuxStorageKey), isNull);

        // Toggle on
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
        expect(prefs.getBool(_tmuxStorageKey), isTrue);

        // Toggle off
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
        expect(prefs.getBool(_tmuxStorageKey), isFalse);
      },
    );
  });
}
