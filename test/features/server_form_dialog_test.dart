import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/servers/server_form_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _initial;
  bool shouldThrowOnSave = false;

  _FakeServerListNotifier(this._initial);

  @override
  List<ServerProfile> build() => _initial;

  @override
  Future<void> addOrUpdate(
    ServerProfile server, {
    String? password,
    String? privateKey,
  }) async {
    if (shouldThrowOnSave) {
      throw Exception('Database disk write failure');
    }
    state = [...state.where((s) => s.id != server.id), server];
  }
}

Widget _buildTestApp({
  ServerProfile? serverToEdit,
  _FakeServerListNotifier? listNotifier,
  LocalStorageService? localStorage,
  Size size = const Size(1024, 768),
}) {
  return ProviderScope(
    overrides: [
      if (listNotifier != null)
        serverListProvider.overrideWith(() => listNotifier),
      if (localStorage != null)
        localStorageServiceProvider.overrideWithValue(localStorage),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ServerFormDialog(serverToEdit: serverToEdit),
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late LocalStorageService testStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    testStorage = LocalStorageService(prefs);
  });

  group('ServerFormDialog UI and Features', () {
    testWidgets(
      'shows validation errors when saving with empty required fields',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(localStorage: testStorage));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Clear default username to trigger required error on all fields
        final usernameField = find.widgetWithText(
          TextFormField,
          l10n.serverUsername,
        );
        await tester.enterText(usernameField, '');
        await tester.pump();

        // Tap Save button
        final saveBtn = find.text(l10n.serverSave);
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Required validation messages should be displayed
        expect(find.text(l10n.serverFieldRequired), findsWidgets);
      },
    );

    testWidgets('validates invalid port range correctly', (tester) async {
      await tester.pumpWidget(_buildTestApp(localStorage: testStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Enter invalid port: 70000
      final portField = find.widgetWithText(TextFormField, l10n.serverPort);
      await tester.enterText(portField, '70000');
      await tester.pump();

      await tester.tap(find.text(l10n.serverSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.serverPortInvalid), findsOneWidget);
    });

    testWidgets(
      'toggles private key expansion and allows viewing monospace key content',
      (tester) async {
        const testKey =
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest-key\n-----END OPENSSH PRIVATE KEY-----';
        await tester.pumpWidget(_buildTestApp(localStorage: testStorage));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Switch to Private Key segment
        final privateKeySegment = find.text(l10n.serverPrivateKey);
        await tester.tap(privateKeySegment);
        await tester.pumpAndSettle();

        // Check private key text field is visible with monospace styling
        final keyFieldFinder = find.byWidgetPredicate(
          (w) => w is TextField && w.style?.fontFamily == 'JetBrains Mono',
        );
        expect(keyFieldFinder, findsOneWidget);

        // Enter key
        await tester.enterText(keyFieldFinder, testKey);
        await tester.pump();

        // Toggle expand
        final expandButton = find.text(l10n.serverViewPrivateKey);
        expect(expandButton, findsOneWidget);
        await tester.ensureVisible(expandButton);
        await tester.pumpAndSettle();
        await tester.tap(expandButton);
        await tester.pumpAndSettle();

        // Label should now be Hide Private Key
        expect(find.text(l10n.serverHidePrivateKey), findsOneWidget);
      },
    );

    testWidgets(
      'displays save failure error banner and snackbar upon exception',
      (tester) async {
        final listNotifier = _FakeServerListNotifier([])
          ..shouldThrowOnSave = true;

        await tester.pumpWidget(
          _buildTestApp(listNotifier: listNotifier, localStorage: testStorage),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Fill in valid fields
        await tester.enterText(
          find.widgetWithText(TextFormField, l10n.serverName),
          'production-1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, l10n.serverHost),
          '10.0.0.1',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, l10n.serverPort),
          '22',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, l10n.serverUsername),
          'root',
        );
        await tester.pump();

        // Tap Save
        await tester.tap(find.text(l10n.serverSave));
        await tester.pumpAndSettle();

        // Verify dialog remains open and save failure banner is visible
        expect(find.byType(ServerFormDialog), findsOneWidget);
        expect(find.text(l10n.serverSaveFailedGeneric), findsWidgets);
        expect(
          find.textContaining('Database disk write failure'),
          findsNothing,
        );
      },
    );
  });
}
