import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/localization/app_locales.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _localeKey = 'valhalla_locale_v1';

String _canonicalLocaleName(Locale locale) {
  final tag = locale.toLanguageTag();
  final parts = tag.split('-');
  for (var i = 0; i < parts.length; i++) {
    if (i == 0) {
      parts[i] = parts[i].toLowerCase();
    } else if (parts[i].length == 4) {
      parts[i] =
          parts[i][0].toUpperCase() + parts[i].substring(1).toLowerCase();
    } else if (i == 1) {
      parts[i] = parts[i].toUpperCase();
    }
  }
  return parts.join('_');
}

/// Simulates storage failure on locale writes: state must not claim success.
class _ThrowingLocaleStorage extends LocalStorageService {
  _ThrowingLocaleStorage(super.prefs);

  @override
  Future<void> setLocale(String languageTag) async {
    throw StateError('Could not persist language preference');
  }
}

Future<ProviderContainer> _pumpSettings(
  WidgetTester tester, {
  LocalStorageService? overrideStorage,
}) async {
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final local =
      overrideStorage ??
      LocalStorageService(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(local)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          // Real provider drives the MaterialApp: without ref.watch() here the
          // locale would never refresh when the user selects a language.
          final settings = ref.watch(settingsProvider);
          return MaterialApp(
            locale: settings.locale.languageCode == 'system'
                ? null
                : settings.locale,
            localeListResolutionCallback: resolveAppLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // DialogRoute lives above the home's MediaQuery subtree; the
            // inherited 2x text scale must wrap the whole child so the
            // in-dialog radios also get 2x fonts at a 320dp-equivalent width.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(body: SettingsView()),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openLanguageDialog(WidgetTester tester) async {
  final tile = find.byKey(const Key('settings_language_tile'));
  final scrollable = find.byType(Scrollable).first;
  var attempts = 0;
  while (tile.evaluate().isEmpty && attempts < 40) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    attempts++;
  }
  await tester.pumpAndSettle();
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _scrollLanguageDialogUntilVisible(
  WidgetTester tester,
  String keySuffix, {
  int maxAttempts = 3,
}) async {
  final target = find.byKey(Key('settings_lang_$keySuffix'));
  Object? lastError;
  for (var i = 0; i < maxAttempts; i++) {
    try {
      final element = tester.element(target);
      await Scrollable.ensureVisible(element, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(
        target.hitTestable(),
        findsOneWidget,
        reason: 'tag $keySuffix must be hit-testable after ensureVisible',
      );
      return;
    } catch (e) {
      lastError = e;
      final dialogScrollable = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(dialogScrollable, const Offset(0, -220));
      await tester.pump();
    }
  }
  await tester.pumpAndSettle();
  throw StateError('unreachable tag $keySuffix: $lastError');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Settings 语言选择', () {
    test('AppLocalizations.supportedLocales match appLanguageLocales', () {
      expect(
        AppLocalizations.supportedLocales.map((e) => e.toLanguageTag()).toSet(),
        appLanguageLocales.map((e) => e.toLanguageTag()).toSet(),
      );
    });

    testWidgets('all 17 language choices plus System reachable at 320dpi', (
      tester,
    ) async {
      await _pumpSettings(tester);
      await _openLanguageDialog(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('settings_lang_system')), findsOneWidget);
      expect(find.byKey(const Key('settings_lang_en')), findsOneWidget);

      await _scrollLanguageDialogUntilVisible(tester, 'th');
      // Prove Thai actually reached the viewport (2x font sized), not just that
      // the eagerly-built tile exists somewhere offstage.
      final thaiRect = tester.getRect(
        find.byKey(const Key('settings_lang_th')),
      );
      expect(thaiRect.top >= 0 && thaiRect.bottom <= 568, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('语言切换即时生效、持久化 canonical tag，重开可见选中态', (tester) async {
      final container = await _pumpSettings(tester);
      await _openLanguageDialog(tester);

      await _scrollLanguageDialogUntilVisible(tester, 'ja');
      await tester.tap(find.byKey(const Key('settings_lang_ja')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(settingsProvider).locale, const Locale('ja'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_localeKey), 'ja');

      await _openLanguageDialog(tester);
      final jaRadio = tester.widget<RadioListTile<String>>(
        find.byKey(const Key('settings_lang_ja')),
      );
      // ignore: deprecated_member_use
      expect(jaRadio.groupValue, 'ja');
      expect(jaRadio.value, 'ja');

      await tester.tap(find.byKey(const Key('settings_lang_system')));
      await tester.pumpAndSettle();
      expect(prefs.getString(_localeKey), 'system');
      expect(container.read(settingsProvider).locale, const Locale('system'));
    });

    testWidgets('Arabic 切换后 Directionality 为 RTL；zh-Hant 持久化 zh-Hant', (
      tester,
    ) async {
      final container = await _pumpSettings(tester);
      await _openLanguageDialog(tester);

      await _scrollLanguageDialogUntilVisible(tester, 'ar');
      await tester.tap(find.byKey(const Key('settings_lang_ar')));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(SettingsView))),
        TextDirection.rtl,
      );
      expect(container.read(settingsProvider).locale.languageCode, 'ar');

      await _openLanguageDialog(tester);
      await _scrollLanguageDialogUntilVisible(tester, 'zh-Hant');
      await tester.tap(find.byKey(const Key('settings_lang_zh-Hant')));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).locale.scriptCode, 'Hant');
      expect(container.read(settingsProvider).locale.languageCode, 'zh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_localeKey), 'zh-Hant');

      await _openLanguageDialog(tester);
      await _scrollLanguageDialogUntilVisible(tester, 'zh');
      await tester.tap(find.byKey(const Key('settings_lang_zh')));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).locale.languageCode, 'zh');
      expect(container.read(settingsProvider).locale.scriptCode, null);
      expect(container.read(settingsProvider).locale.toLanguageTag(), 'zh');
      final prefs2 = await SharedPreferences.getInstance();
      expect(prefs2.getString(_localeKey), 'zh');
    });

    testWidgets('持久化失败时保留原选中态、不关弹窗、提示可见', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = await _pumpSettings(
        tester,
        overrideStorage: _ThrowingLocaleStorage(prefs),
      );
      expect(container.read(settingsProvider).locale, const Locale('system'));

      await _openLanguageDialog(tester);
      await _scrollLanguageDialogUntilVisible(tester, 'ja');
      await tester.tap(find.byKey(const Key('settings_lang_ja')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(container.read(settingsProvider).locale, const Locale('system'));
      expect(prefs.getString(_localeKey), isNull);
      final failureText = find.text('Failed to update language settings');
      expect(failureText, findsOneWidget);
      expect(
        failureText.hitTestable(),
        findsOneWidget,
        reason: 'failure text must be hit-testable, not obscured',
      );
    });

    test(
      'AppLocalizations.delegate.load resolves runtime IDs for all 17',
      () async {
        for (final locale in appLanguageLocales) {
          final l10n = await AppLocalizations.delegate.load(locale);
          expect(
            l10n.localeName,
            _canonicalLocaleName(locale),
            reason: 'delegate.load($locale) runtime canonical tag mismatch',
          );
          expect(l10n.navSettings, isNotEmpty);
          expect(l10n.settingsLanguage, isNotEmpty);
          expect(l10n.cmdDangerousWarning, isNotEmpty);
        }
      },
    );

    testWidgets(
      'fresh ProviderContainer over same prefs stays ja (restart-style)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'valhalla_locale_v1': 'ja'});
        final first = await _pumpSettings(tester);
        first.dispose();

        final second = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              LocalStorageService(await SharedPreferences.getInstance()),
            ),
          ],
        );
        addTearDown(second.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: second,
            child: Consumer(
              builder: (context, ref, _) {
                final settings = ref.watch(settingsProvider);
                return MaterialApp(
                  locale: settings.locale.languageCode == 'system'
                      ? null
                      : settings.locale,
                  localeListResolutionCallback: resolveAppLocale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const Scaffold(body: SettingsView()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(second.read(settingsProvider).locale, const Locale('ja'));
        expect(
          Localizations.localeOf(tester.element(find.byType(SettingsView))),
          const Locale('ja'),
        );

        await _openLanguageDialog(tester);
        final jaRadio = tester.widget<RadioListTile<String>>(
          find.byKey(const Key('settings_lang_ja')),
        );
        // ignore: deprecated_member_use
        expect(jaRadio.groupValue, 'ja');
      },
    );

    testWidgets(
      'system-follow resolves real platform locale; explicit ja wins; unsupported falls back to EN',
      (tester) async {
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];

        await _pumpSettings(tester);
        expect(
          Localizations.localeOf(tester.element(find.byType(SettingsView))),
          const Locale('fr'),
          reason: 'solveAppLocale intentionally returns the supported FR base',
        );

        await tester.pumpWidget(const SizedBox());
        final existingPrefs = await SharedPreferences.getInstance();
        await existingPrefs.setString('valhalla_locale_v1', 'ja');
        tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
        await _pumpSettings(tester);
        expect(
          Localizations.localeOf(tester.element(find.byType(SettingsView))),
          const Locale('ja'),
        );

        await tester.pumpWidget(const SizedBox());
        await existingPrefs.remove('valhalla_locale_v1');
        tester.platformDispatcher.localesTestValue = const [Locale('xx')];
        await _pumpSettings(tester);
        expect(
          Localizations.localeOf(tester.element(find.byType(SettingsView))),
          const Locale('en'),
        );
      },
    );
  });
}
