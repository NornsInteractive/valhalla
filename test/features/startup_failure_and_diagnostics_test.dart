import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/diagnostics_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/app_diagnostics.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/settings/widgets/diagnostics_view.dart';
import 'package:valhalla/features/settings/widgets/startup_failure_app.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class FakeAppDiagnostics extends Fake implements AppDiagnostics {
  @override
  String? storageError;

  String logsToRead = '[2026-09-23T12:00:00Z] startup: Application initialized';
  String? exportPath = '/tmp/diagnostics-export.log';
  bool throwOnExport = false;
  int readCallCount = 0;
  int exportCallCount = 0;

  @override
  Stream<String> get incidents => const Stream.empty();

  @override
  Future<String> read({int maxBytes = 256 * 1024}) async {
    readCallCount++;
    return logsToRead;
  }

  @override
  Future<String?> export() async {
    exportCallCount++;
    if (throwOnExport) {
      throw Exception('Export failed');
    }
    return exportPath;
  }
}

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('StartupFailureApp Widget Tests', () {
    testWidgets('renders failure screen and triggers retry callback', (
      tester,
    ) async {
      var retryCalled = false;
      final fakeDiagnostics = FakeAppDiagnostics();

      await tester.pumpWidget(
        StartupFailureApp(
          retry: () async {
            retryCalled = true;
          },
          diagnostics: fakeDiagnostics,
        ),
      );
      await tester.pumpAndSettle();

      // Find retry button
      final retryFinder = find.byKey(const Key('startup_retry_button'));
      expect(retryFinder, findsOneWidget);

      await tester.tap(retryFinder);
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets(
      'retry error is sanitized and resets busy state so retry remains available',
      (tester) async {
        final fakeDiagnostics = FakeAppDiagnostics();
        var attempts = 0;

        await tester.pumpWidget(
          StartupFailureApp(
            retry: () async {
              attempts++;
              throw Exception(
                'Connection to secret-host failed with password=SuperSecretToken123',
              );
            },
            diagnostics: fakeDiagnostics,
          ),
        );
        await tester.pumpAndSettle();

        final retryFinder = find.byKey(const Key('startup_retry_button'));
        await tester.tap(retryFinder);
        await tester.pumpAndSettle();

        // Verifies password secret is redacted
        expect(find.textContaining('SuperSecretToken123'), findsNothing);
        expect(find.textContaining('password=******'), findsOneWidget);

        // Verifies retry button is NOT disabled and can be tapped again
        expect(tester.widget<FilledButton>(retryFinder).onPressed, isNotNull);
        await tester.tap(retryFinder);
        await tester.pumpAndSettle();
        expect(attempts, 2);
      },
    );

    testWidgets(
      'displays storage error banner when storage initialization failed',
      (tester) async {
        final fakeDiagnostics = FakeAppDiagnostics()
          ..storageError = 'SQLite database disk I/O error';

        await tester.pumpWidget(
          StartupFailureApp(retry: () async {}, diagnostics: fakeDiagnostics),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('SQLite database disk I/O error'),
          findsOneWidget,
        );
      },
    );

    testWidgets('opens diagnostics view dialog on view diagnostics click', (
      tester,
    ) async {
      final fakeDiagnostics = FakeAppDiagnostics();

      await tester.pumpWidget(
        StartupFailureApp(retry: () async {}, diagnostics: fakeDiagnostics),
      );
      await tester.pumpAndSettle();

      final viewBtn = find.byKey(const Key('startup_view_diagnostics_button'));
      expect(viewBtn, findsOneWidget);

      await tester.tap(viewBtn);
      await tester.pumpAndSettle();

      expect(find.byType(DiagnosticsView), findsOneWidget);
    });

    testWidgets('exports diagnostics and displays feedback snackbar', (
      tester,
    ) async {
      final fakeDiagnostics = FakeAppDiagnostics();

      await tester.pumpWidget(
        StartupFailureApp(retry: () async {}, diagnostics: fakeDiagnostics),
      );
      await tester.pumpAndSettle();

      final exportBtn = find.byKey(
        const Key('startup_export_diagnostics_button'),
      );
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(fakeDiagnostics.exportCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('/tmp/diagnostics-export.log'),
        findsOneWidget,
      );
    });

    testWidgets('360px logical width with large text does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeDiagnostics = FakeAppDiagnostics()
        ..storageError = 'Disk full on persistent storage path /data/app';

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: StartupFailureApp(
            retry: () async {},
            diagnostics: fakeDiagnostics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('DiagnosticsView Widget Tests', () {
    testWidgets('loads log content and triggers refresh', (tester) async {
      final fakeDiagnostics = FakeAppDiagnostics()
        ..logsToRead = 'Log entry line 1\nLog entry line 2';

      await tester.pumpWidget(
        _wrapWithL10n(
          Scaffold(body: DiagnosticsView(diagnostics: fakeDiagnostics)),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeDiagnostics.readCallCount, 1);
      expect(find.textContaining('Log entry line 1'), findsOneWidget);

      // Tap refresh
      fakeDiagnostics.logsToRead =
          'Log entry line 1\nLog entry line 2\nRefreshed line 3';
      final refreshBtn = find.byKey(const Key('diagnostics_refresh_button'));
      expect(refreshBtn, findsOneWidget);

      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(fakeDiagnostics.readCallCount, 2);
      expect(find.textContaining('Refreshed line 3'), findsOneWidget);
    });

    testWidgets('exports logs from DiagnosticsView', (tester) async {
      final fakeDiagnostics = FakeAppDiagnostics();

      await tester.pumpWidget(
        _wrapWithL10n(
          Scaffold(body: DiagnosticsView(diagnostics: fakeDiagnostics)),
        ),
      );
      await tester.pumpAndSettle();

      final exportBtn = find.byKey(const Key('diagnostics_export_button'));
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(fakeDiagnostics.exportCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('displays storage error banner if storage error exists', (
      tester,
    ) async {
      final fakeDiagnostics = FakeAppDiagnostics()
        ..storageError = 'Failed to open diagnostics storage';

      await tester.pumpWidget(
        _wrapWithL10n(
          Scaffold(body: DiagnosticsView(diagnostics: fakeDiagnostics)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Failed to open diagnostics storage'),
        findsOneWidget,
      );
    });
  });

  group('MainShell Diagnostics Incident Listener Tests', () {
    testWidgets(
      'replaces and coalesces repeated incidents without unbounded queueing',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final incidentController = StreamController<String>.broadcast();
        addTearDown(incidentController.close);

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(_NoActiveServerNotifier.new),
            sftpProvider.overrideWith(_FakeSftpNotifier.new),
            diagnosticsIncidentProvider.overrideWith(
              (ref) => incidentController.stream,
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MainShell(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Rapid burst of 4 incidents
        incidentController.add('storage');
        await tester.pump();
        incidentController.add('network');
        await tester.pump();
        incidentController.add('sftp');
        await tester.pump();
        incidentController.add('ssh');
        await tester.pump(const Duration(milliseconds: 300));

        // Exactly one SnackBar is visible, displaying the latest incident 'ssh'
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('ssh'), findsOneWidget);
        expect(find.textContaining('storage'), findsNothing);
      },
    );
  });
}

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _NoActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}
