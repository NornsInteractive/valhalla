import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/widgets/remote_file_toolbar_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _preferenceKey = 'valhalla_remote_file_toolbar_actions_v1';

class _ToolbarStorage extends LocalStorageService {
  _ToolbarStorage(super.prefs);

  bool fail = false;
  int writes = 0;
  Completer<void>? gate;

  @override
  Future<void> setRemoteFileToolbarActions(List<String> actions) async {
    writes++;
    await gate?.future;
    if (fail) throw StateError('fixture persistence failure');
    await super.setRemoteFileToolbarActions(actions);
  }
}

Future<
  ({
    ProviderContainer container,
    _ToolbarStorage storage,
    SharedPreferences prefs,
  })
>
_pumpDialogHost(
  WidgetTester tester, {
  List<String>? initial,
  Locale locale = const Locale('en'),
  double textScale = 1,
  FocusNode? focusNode,
}) async {
  SharedPreferences.setMockInitialValues({_preferenceKey: ?initial});
  final prefs = await SharedPreferences.getInstance();
  final storage = _ToolbarStorage(prefs);
  final container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(
                  key: const Key('toolbar_host_search'),
                  focusNode: focusNode,
                ),
                TextButton(
                  key: const Key('open_toolbar_dialog'),
                  onPressed: () => RemoteFileToolbarDialog.show(context),
                  child: const Text('Configure toolbar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, storage: storage, prefs: prefs);
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_toolbar_dialog')));
  await tester.pumpAndSettle();
}

Future<void> _toggle(
  WidgetTester tester,
  RemoteFileToolbarAction action,
) async {
  final finder = find.byKey(Key('toolbar_action_${action.name}'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<RemoteFileToolbarAction> _checked(WidgetTester tester) => [
  for (final action in RemoteFileToolbarAction.values)
    if (tester
            .widget<CheckboxListTile>(
              find.byKey(Key('toolbar_action_${action.name}')),
            )
            .value ==
        true)
      action,
];

void main() {
  testWidgets('Cancel discards local draft without writing preferences', (
    tester,
  ) async {
    final fixture = await _pumpDialogHost(tester);
    await _openDialog(tester);
    expect(_checked(tester), defaultRemoteFileToolbarActions);
    await _toggle(tester, RemoteFileToolbarAction.upload);
    expect(
      fixture.container.read(settingsProvider).remoteFileToolbarActions,
      defaultRemoteFileToolbarActions,
    );
    await tester.tap(find.byKey(const Key('toolbar_dialog_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteFileToolbarDialog), findsNothing);
    expect(fixture.storage.writes, 0);
    expect(fixture.prefs.containsKey(_preferenceKey), isFalse);
    await _openDialog(tester);
    expect(_checked(tester), defaultRemoteFileToolbarActions);
  });

  testWidgets(
    'Save accepts zero pinned actions and persists exact empty choice',
    (tester) async {
      final fixture = await _pumpDialogHost(tester);
      await _openDialog(tester);
      for (final action in defaultRemoteFileToolbarActions) {
        await _toggle(tester, action);
      }
      expect(_checked(tester), isEmpty);
      await tester.tap(find.byKey(const Key('toolbar_dialog_save')));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteFileToolbarDialog), findsNothing);
      expect(fixture.storage.writes, 1);
      expect(fixture.prefs.getStringList(_preferenceKey), isEmpty);
      expect(
        fixture.container.read(settingsProvider).remoteFileToolbarActions,
        isEmpty,
      );
      await _openDialog(tester);
      expect(_checked(tester), isEmpty);
    },
  );

  testWidgets('Restore default changes draft only until Save', (tester) async {
    final fixture = await _pumpDialogHost(tester, initial: ['refresh']);
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('toolbar_dialog_reset')));
    await tester.pumpAndSettle();
    expect(_checked(tester), defaultRemoteFileToolbarActions);
    expect(fixture.prefs.getStringList(_preferenceKey), ['refresh']);
    expect(fixture.container.read(settingsProvider).remoteFileToolbarActions, [
      RemoteFileToolbarAction.refresh,
    ]);
    await tester.tap(find.byKey(const Key('toolbar_dialog_save')));
    await tester.pumpAndSettle();
    expect(fixture.prefs.getStringList(_preferenceKey), [
      'upload',
      'create',
      'view',
      'transfers',
      'sort',
    ]);
  });

  testWidgets('failed write keeps dialog and draft, permits successful retry', (
    tester,
  ) async {
    final fixture = await _pumpDialogHost(tester, initial: ['upload']);
    fixture.storage.fail = true;
    await _openDialog(tester);
    await _toggle(tester, RemoteFileToolbarAction.refresh);
    await tester.tap(find.byKey(const Key('toolbar_dialog_save')));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteFileToolbarDialog), findsOneWidget);
    expect(_checked(tester), [
      RemoteFileToolbarAction.upload,
      RemoteFileToolbarAction.refresh,
    ]);
    expect(fixture.container.read(settingsProvider).remoteFileToolbarActions, [
      RemoteFileToolbarAction.upload,
    ]);
    expect(fixture.prefs.getStringList(_preferenceKey), ['upload']);
    expect(find.text('Failed to save toolbar preference'), findsOneWidget);
    fixture.storage.fail = false;
    await tester.tap(find.byKey(const Key('toolbar_dialog_save')));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteFileToolbarDialog), findsNothing);
    expect(fixture.prefs.getStringList(_preferenceKey), ['upload', 'refresh']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending save prevents duplicate writes or checkbox changes', (
    tester,
  ) async {
    final fixture = await _pumpDialogHost(tester);
    fixture.storage.gate = Completer<void>();
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('toolbar_dialog_save')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('toolbar_dialog_save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('toolbar_dialog_cancel')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('toolbar_dialog_reset')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('toolbar_action_upload')),
          )
          .onChanged,
      isNull,
    );
    expect(fixture.storage.writes, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(RemoteFileToolbarDialog), findsOneWidget);
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.byType(RemoteFileToolbarDialog), findsOneWidget);
    fixture.storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RemoteFileToolbarDialog), findsNothing);
  });

  for (final locale in [const Locale('de'), const Locale('ar')]) {
    testWidgets(
      '320dp 2x $locale dialog actions and final checkbox stay reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpDialogHost(tester, locale: locale, textScale: 2);
        await _openDialog(tester);
        expect(tester.takeException(), isNull);
        await _toggle(tester, RemoteFileToolbarAction.refresh);
        expect(_checked(tester), contains(RemoteFileToolbarAction.refresh));
        expect(
          find.byKey(const Key('toolbar_dialog_save')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('toolbar_dialog_cancel')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'opening and closing configuration never restores mobile search keyboard',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pumpDialogHost(tester, focusNode: focus);
      await tester.tap(find.byKey(const Key('toolbar_host_search')));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await _openDialog(tester);
      expect(focus.hasFocus, isFalse);
      await tester.tap(find.byKey(const Key('toolbar_dialog_cancel')));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
