import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';

/// Shell fixture shared with `main_shell_dynamic_nav_test.dart`: same provider
/// overrides, same mobile surface, so focus regressions are observed on the
/// real compact shell (drawer + bottom navigation + keep-alive page stack).
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

class _TerminalTestBridge extends TerminalSessionBridge {
  _TerminalTestBridge() : super(terminal: Terminal(), serverName: 'test');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

TerminalTab _terminalTab(String id) {
  final bridge = _TerminalTestBridge();
  return TerminalTab(
    id: id,
    title: id,
    terminal: bridge.terminal,
    bridge: bridge,
  );
}

class _TerminalTestNotifier extends TerminalNotifier {
  @override
  SshTerminalState build() =>
      SshTerminalState(tabs: [_terminalTab('first')], activeTabIndex: 0);
}

_TerminalTestNotifier? _terminalNotifier;

_TerminalTestNotifier _terminalFactory() {
  _terminalNotifier = _TerminalTestNotifier();
  return _terminalNotifier!;
}

/// xterm keeps a 300ms double-tap timer alive after a tap, so flush it before
/// the test ends and tear the bridges down like the toolbar tests do.
Future<void> _disposeTerminalSession(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpWidget(const SizedBox());
  for (final tab in _terminalNotifier!.state.tabs) {
    (tab.bridge as _TerminalTestBridge).dispose();
  }
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(500, 900),
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
      terminalProvider.overrideWith(_terminalFactory),
      terminalSettingsProvider.overrideWith(FixedTerminalSettingsNotifier.new),
      settingsProvider.overrideWith(
        () => _SectionSettingsNotifier(
          const SettingsState(
            bottomNavigationSections: [
              AppSection.dashboard,
              AppSection.terminal,
              AppSection.files,
            ],
          ),
        ),
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
        home: MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _SectionSettingsNotifier extends SettingsNotifier {
  _SectionSettingsNotifier(this._state);

  final SettingsState _state;

  @override
  SettingsState build() => _state;
}

/// The search field of the files page; `skipOffstage: false` keeps it
/// findable while the page is kept alive but hidden by the shell stack.
final Finder _searchField = find.byKey(
  const Key('sftp_search_field'),
  skipOffstage: false,
);

Finder _filesSection() => find.descendant(
  of: find.byKey(const Key('bottom_nav_item_files')),
  matching: find.byType(InkWell),
);

Finder _terminalSection() => find.descendant(
  of: find.byKey(const Key('bottom_nav_item_terminal')),
  matching: find.byType(InkWell),
);

/// Focus node of the files page search input. Both finders must opt out of
/// offstage skipping: the page stays mounted but hidden by the shell stack,
/// and the offstage `EditableText` is the node whose focus we are policing.
/// (`TextField.focusNode` is null when the widget never supplies one, so read
/// the `EditableText` instead.)
FocusNode _inputFocus(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: _searchField,
        matching: find.byType(EditableText, skipOffstage: false),
      ),
    )
    .focusNode;

bool _keyboardHidden(WidgetTester tester) {
  for (final call in tester.testTextInput.log.reversed) {
    if (call.method == 'TextInput.show') return false;
    if (call.method == 'TextInput.hide' ||
        call.method == 'TextInput.clearClient') {
      return true;
    }
  }
  return true;
}

void _expectNoKeyboard(WidgetTester tester) {
  expect(
    _inputFocus(tester).hasFocus,
    isFalse,
    reason: 'hidden page input must not keep focus',
  );
  expect(
    _keyboardHidden(tester),
    isTrue,
    reason: 'soft keyboard must stay dismissed',
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await tester.pumpAndSettle();
  expect(find.byType(Drawer), findsOneWidget);
}

/// Simulates the Android system back button (the `flutter/navigation`
/// channel speaks `JSONMethodCodec`).
Future<void> _systemBack(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    const MethodCall('popRoute'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening the drawer drops the keyboard and its focus', (
    tester,
  ) async {
    await _pumpShell(tester);
    await tester.tap(_filesSection());
    await tester.pumpAndSettle();

    await tester.tap(_searchField);
    await tester.pumpAndSettle();
    expect(_inputFocus(tester).hasFocus, isTrue);

    await _openDrawer(tester);

    _expectNoKeyboard(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drawer selection, backdrop tap and system back never restore the keyboard',
    (tester) async {
      await _pumpShell(tester);
      await tester.tap(_filesSection());
      await tester.pumpAndSettle();
      await tester.tap(_searchField);
      await tester.pumpAndSettle();

      // Backdrop tap closes the drawer.
      await _openDrawer(tester);
      await tester.tapAt(const Offset(450, 700));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      _expectNoKeyboard(tester);

      // Backdrop fling closes the drawer.
      await _openDrawer(tester);
      await tester.flingFrom(
        const Offset(450, 400),
        const Offset(-200, 0),
        500,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      _expectNoKeyboard(tester);

      // System back closes the drawer.
      await _openDrawer(tester);
      await _systemBack(tester);
      expect(find.byType(Drawer), findsNothing);
      _expectNoKeyboard(tester);

      // Selecting another section closes the drawer and switches page.
      await _openDrawer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byIcon(Icons.dashboard_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      _expectNoKeyboard(tester);
      // The page title confirms the selection landed on the dashboard.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('main_shell_page_title')))
            .data,
        'Dashboard',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a hidden page cannot take focus', (tester) async {
    await _pumpShell(tester);
    await tester.tap(_filesSection());
    await tester.pumpAndSettle();
    await tester.tap(_searchField);
    await tester.pumpAndSettle();
    expect(_inputFocus(tester).hasFocus, isTrue);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.dashboard_outlined),
      ),
    );
    await tester.pumpAndSettle();
    _expectNoKeyboard(tester);

    // The files page stays mounted but must refuse focus while hidden.
    final focus = _inputFocus(tester);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(
      FocusManager.instance.primaryFocus,
      isNot(same(focus)),
      reason: 'hidden page must not become the primary focus',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching pages keeps the search draft and page state', (
    tester,
  ) async {
    await _pumpShell(tester);
    await tester.tap(_filesSection());
    await tester.pumpAndSettle();

    await tester.tap(_searchField);
    await tester.pumpAndSettle();
    await tester.enterText(_searchField, 'draft-keep');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_searchField).controller!.text,
      'draft-keep',
    );

    final filesStateBefore = tester.state(
      find.byType(SftpFileView, skipOffstage: false).first,
    );

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.dashboard_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_filesSection());
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_searchField).controller!.text,
      'draft-keep',
      reason: 'page switch must not clear the search draft',
    );
    expect(
      tester.state(find.byType(SftpFileView, skipOffstage: false).first),
      same(filesStateBefore),
      reason: 'page must stay mounted, not be rebuilt from scratch',
    );
    _expectNoKeyboard(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the terminal reopens the keyboard after the drawer '
      'dismissed it', (tester) async {
    await _pumpShell(tester);
    await tester.tap(_terminalSection());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TerminalView).first);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    expect(
      tester.testTextInput.log.any(
        (call) => call.method == 'TextInput.setClient',
      ),
      isTrue,
    );
    final logLengthAfterFirstTap = tester.testTextInput.log.length;

    await _openDrawer(tester);
    await tester.tapAt(const Offset(450, 700));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    expect(_keyboardHidden(tester), isTrue);

    // The user taps the terminal again: the keyboard must come back.
    await tester.tap(find.byType(TerminalView).first);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    expect(
      tester.testTextInput.log
          .skip(logLengthAfterFirstTap)
          .any((call) => call.method == 'TextInput.setClient'),
      isTrue,
      reason: 'tapping the terminal must attach a new text input client',
    );
    expect(tester.takeException(), isNull);
    await _disposeTerminalSession(tester);
  });
}
