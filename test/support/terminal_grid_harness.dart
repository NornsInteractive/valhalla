import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/l10n/app_localizations.dart';

Future<void> loadTerminalGridFonts() async {
  final mono = FontLoader('JetBrains Mono')
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-400.ttf'))
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-600.ttf'));
  await mono.load();
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-400.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-600.ttf'));
  await inter.load();
}

Future<void> pumpTerminalGrid(
  WidgetTester tester, {
  TerminalAccessoryLayout? layout,
  double width = 360,
  double height = 760,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  List<String>? sent,
  ValueNotifier<bool>? tickers,
  LocalStorageService Function(SharedPreferences)? storageFactory,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'valhalla_terminal_grid_v2': jsonEncode(
      (layout ?? TerminalAccessoryLayout.defaultLayout()).toJson(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  final storage = storageFactory?.call(prefs) ?? LocalStorageService(prefs);
  final bar = TerminalAccessoryBar(
    onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
        sent?.add(key),
    onToggleCtrl: () {},
    onToggleAlt: () {},
    onPaste: () {},
    onToggleKeyboard: () {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp(
        locale: locale,
        theme:
            theme ??
            AppTheme.buildTheme(
              brightness: Brightness.light,
              seedColor: const Color(0xff10b981),
            ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  if (tickers == null)
                    bar
                  else
                    ValueListenableBuilder<bool>(
                      valueListenable: tickers,
                      child: bar,
                      builder: (context, enabled, child) =>
                          TickerMode(enabled: enabled, child: child!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder terminalGridKey(String key) =>
    find.byKey(Key('terminal_accessory_key_$key'));

Finder terminalGridArrowSlot(String key) => find
    .ancestor(of: terminalGridKey(key), matching: find.byType(HoldRepeatKey))
    .first;

Future<void> enterTerminalGridEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.tune));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('terminal_grid_save_button')), findsOneWidget);
}
