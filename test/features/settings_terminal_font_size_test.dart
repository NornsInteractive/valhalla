import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _fontSizeStorageKey = 'valhalla_terminal_font_size_v1';
const _rowKey = Key('settingsTerminalFontSizeRow');
const _valueKey = Key('settingsTerminalFontSizeValue');
const _sliderKey = Key('settingsTerminalFontSizeSlider');

class _SpyTerminalSettingsNotifier extends TerminalSettingsNotifier {
  final int initialFontSize;
  final List<int> setFontSizeCalls = [];

  _SpyTerminalSettingsNotifier({this.initialFontSize = 13});

  @override
  TerminalSettings build() {
    return TerminalSettings(useTmux: false, fontSize: initialFontSize);
  }

  @override
  Future<void> setFontSize(int value) async {
    setFontSizeCalls.add(value);
    state = state.copyWith(
      fontSize: value.clamp(
        TerminalSettingsNotifier.minFontSize,
        TerminalSettingsNotifier.maxFontSize,
      ),
    );
  }
}

/// 设置页还读 `autoConnectSettingsProvider` -> `localStorageServiceProvider`；
/// 后者默认是抛 `UnimplementedError` 的占位，不注入会让整页构建失败。
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

  group('SettingsView terminal font size', () {
    testWidgets(
      'renders font size row with title, subtitle and current value (default 13)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_rowKey), findsOneWidget);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.settingsTerminalFontSize), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalFontSizeSubtitle),
          findsOneWidget,
        );

        final valueText = tester.widget<Text>(find.byKey(_valueKey));
        expect(valueText.data, '13');
      },
    );

    testWidgets(
      'shows the persisted font size in Chinese locale (storage -> UI)',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({_fontSizeStorageKey: 20});

        await tester.pumpWidget(
          _buildSettingsApp(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                await _freshStorage(),
              ),
            ],
            locale: const Locale('zh'),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
        expect(find.text(l10n.settingsTerminalFontSize), findsOneWidget);
        expect(
          find.text(l10n.settingsTerminalFontSizeSubtitle),
          findsOneWidget,
        );
        expect(tester.widget<Text>(find.byKey(_valueKey)).data, '20');
      },
    );

    testWidgets(
      'slider interaction updates provider state, trailing value and storage',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              LocalStorageService(prefs),
            ),
          ],
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

        expect(container.read(terminalSettingsProvider).fontSize, 13);

        // Open the dialog.
        await tester.tap(find.byKey(_rowKey));
        await tester.pumpAndSettle();

        final sliderFinder = find.byKey(_sliderKey);
        expect(sliderFinder, findsOneWidget);
        // Live mono preview line rendered inside the dialog.
        expect(find.text('Aa  \$ ls -la ~/valhalla'), findsOneWidget);

        // Tap division 7 of 15 -> value 9 + 7 = 16.
        final sliderRect = tester.getRect(sliderFinder);
        await tester.tapAt(
          Offset(
            sliderRect.left + sliderRect.width * 7 / 15,
            sliderRect.center.dy,
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(terminalSettingsProvider).fontSize, 16);
        expect(prefs.getInt(_fontSizeStorageKey), 16);
        // Trailing value behind the dialog follows the provider.
        expect(tester.widget<Text>(find.byKey(_valueKey)).data, '16');

        // Close the dialog; state survives.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(container.read(terminalSettingsProvider).fontSize, 16);
      },
    );

    testWidgets('slider interaction invokes setFontSize on the notifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final spy = _SpyTerminalSettingsNotifier(initialFontSize: 13);
      final spyContainer = ProviderContainer(
        overrides: [
          terminalSettingsProvider.overrideWith(() => spy),
          localStorageServiceProvider.overrideWithValue(await _freshStorage()),
        ],
      );
      addTearDown(spyContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: spyContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SettingsView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_rowKey));
      await tester.pumpAndSettle();

      // Tap the far-right end of the slider -> max 24.
      final sliderRect = tester.getRect(find.byKey(_sliderKey));
      await tester.tapAt(
        Offset(sliderRect.left + sliderRect.width - 1, sliderRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(spy.setFontSizeCalls, contains(24));
      expect(spy.setFontSizeCalls.last, lessThanOrEqualTo(24));
      expect(spyContainer.read(terminalSettingsProvider).fontSize, 24);
    });
  });
}
