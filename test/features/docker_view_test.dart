import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/features/docker/docker_view.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/danger_confirm_dialog.dart';

ServerProfile _testServer() => const ServerProfile(
  id: 'srv-1',
  name: 'Docker Host',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
);

const _container1 = DockerContainer(
  id: 'c1-id-long-sha256-hash',
  name: 'web-nginx',
  image: 'nginx:alpine',
  status: 'Up 3 hours',
  state: DockerContainerState.running,
  ports: '80:80',
);

const _container2 = DockerContainer(
  id: 'c2-id-long-sha256-hash',
  name: 'redis-cache',
  image: 'redis:7',
  status: 'Exited (0) 10 minutes ago',
  state: DockerContainerState.exited,
  ports: '6379:6379',
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  ServerProfile? _initial;
  _FakeActiveServerNotifier(this._initial);
  @override
  ServerProfile? build() => _initial;
  void updateServer(ServerProfile? s) {
    _initial = s;
    state = s;
  }
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _initial;
  _FakeConnectionNotifier(this._initial);
  @override
  ServerConnectionState build() => _initial;
}

class _FakeDockerNotifier extends DockerNotifier {
  DockerState _testState;
  final List<(String, String)> lifecycleCalls = [];
  final List<String> inspectCalls = [];
  Future<SSHExecutionResult> Function(String action, String containerId)?
  onLifecycle;

  _FakeDockerNotifier(this._testState);

  @override
  DockerState build() => _testState;

  void setTestState(DockerState newState) {
    _testState = newState;
    state = newState;
  }

  @override
  Future<SSHExecutionResult> performLifecycle(
    String action,
    String containerId,
  ) async {
    lifecycleCalls.add((action, containerId));
    if (onLifecycle != null) {
      return onLifecycle!(action, containerId);
    }
    return const SSHExecutionResult(exitCode: 0, stdout: 'ok', stderr: '');
  }

  @override
  Future<Map<String, dynamic>> inspectContainer(String containerId) async {
    inspectCalls.add(containerId);
    return {
      'Id': containerId,
      'Name': '/$containerId',
      'State': {'Status': 'running'},
    };
  }

  @override
  Stream<String> streamLogs(String containerId) {
    return Stream.value('sample container log text');
  }

  @override
  Future<void> refresh() async {}
}

late LocalStorageService _testLocalStorage;

Widget _buildTestApp({
  required _FakeDockerNotifier dockerNotifier,
  ServerProfile? server,
  ServerConnectionState connState = const ServerConnectionState(
    status: ConnectionStateEnum.connected,
  ),
  LocalStorageService? localStorage,
}) {
  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(server ?? _testServer()),
      ),
      serverConnectionProvider.overrideWith(
        () => _FakeConnectionNotifier(connState),
      ),
      dockerProvider.overrideWith(() => dockerNotifier),
      localStorageServiceProvider.overrideWithValue(
        localStorage ?? _testLocalStorage,
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DockerView(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _testLocalStorage = await LocalStorageService.init();
  });

  group('DockerView pendingActions & UI interactions', () {
    testWidgets(
      'shows CircularProgressIndicator on in-flight button and disables conflicting buttons on same container',
      (tester) async {
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(
            containers: [_container1],
            pendingActions: {'c1-id-long-sha256-hash': 'stop'},
          ),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pump();

        // c1 is running and pending 'stop'
        // Should show CircularProgressIndicator for stop button
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Find all IconButtons on the card
        final iconButtons = tester.widgetList<IconButton>(
          find.byType(IconButton),
        );

        // The action buttons for logs, inspect, restart, rm should have onPressed == null
        final disabledActionButtons = iconButtons
            .where((btn) => btn.onPressed == null)
            .toList();

        // Multiple buttons on this container must be disabled
        expect(disabledActionButtons.length, greaterThanOrEqualTo(3));
      },
    );

    testWidgets(
      'conflicting buttons are disabled on busy container while other containers remain interactive',
      (tester) async {
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(
            containers: [_container1, _container2],
            pendingActions: {'c1-id-long-sha256-hash': 'restart'},
          ),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pump();

        // c1 has pending action 'restart' -> progress indicator is shown on c1
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Find c2's start button (c2 is exited, so it has play_arrow_rounded)
        final playIcons = find.byIcon(Icons.play_arrow_rounded);
        expect(playIcons, findsOneWidget);

        final startButton = tester.widget<IconButton>(
          find.ancestor(of: playIcons, matching: find.byType(IconButton)),
        );

        // c2 Start button must NOT be disabled
        expect(startButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'shows CircularProgressIndicator on inspect button when inspect is pending',
      (tester) async {
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(
            containers: [_container1],
            pendingActions: {'c1-id-long-sha256-hash': 'inspect'},
          ),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pump();

        // Inspect button shows CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'confirms action via DangerConfirmDialog before invoking performLifecycle',
      (tester) async {
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(containers: [_container1]),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pumpAndSettle();

        // Tap Stop button on c1
        final stopButton = find.byIcon(Icons.stop_rounded);
        expect(stopButton, findsOneWidget);

        await tester.tap(stopButton);
        await tester.pumpAndSettle();

        // Danger confirm dialog should appear
        expect(find.byType(DangerConfirmDialog), findsOneWidget);
        expect(find.textContaining('docker stop'), findsOneWidget);

        // Cancel the dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // No lifecycle calls made
        expect(dockerNotifier.lifecycleCalls, isEmpty);

        // Tap Stop button again
        await tester.tap(stopButton);
        await tester.pumpAndSettle();

        // Confirm the dialog
        await tester.tap(find.text('Confirm & Proceed'));
        await tester.pumpAndSettle();

        // performLifecycle should be called
        expect(dockerNotifier.lifecycleCalls, hasLength(1));
        expect(dockerNotifier.lifecycleCalls.first.$1, 'stop');
        expect(
          dockerNotifier.lifecycleCalls.first.$2,
          'c1-id-long-sha256-hash',
        );
      },
    );

    testWidgets('shows localized success message when lifecycle succeeds', (
      tester,
    ) async {
      final dockerNotifier = _FakeDockerNotifier(
        const DockerState(containers: [_container1]),
      );

      dockerNotifier.onLifecycle = (action, containerId) async {
        return const SSHExecutionResult(exitCode: 0, stdout: 'ok', stderr: '');
      };

      await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm & Proceed'));
      await tester.pumpAndSettle();

      // Localized success message in SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('web-nginx'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('succeeded'), findsOneWidget);
    });

    testWidgets('shows localized error message when lifecycle fails', (
      tester,
    ) async {
      final dockerNotifier = _FakeDockerNotifier(
        const DockerState(containers: [_container1]),
      );

      dockerNotifier.onLifecycle = (action, containerId) async {
        return const SSHExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'permission denied while accessing socket',
        );
      };

      await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm & Proceed'));
      await tester.pumpAndSettle();

      // Localized failure message in SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Action failed'), findsOneWidget);
      expect(
        find.textContaining('permission denied while accessing socket'),
        findsOneWidget,
      );
    });

    testWidgets(
      'lifecycle feedback is suppressed if activeServer changed while action was in flight',
      (tester) async {
        final serverNotifier = _FakeActiveServerNotifier(_testServer());
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(containers: [_container1]),
        );

        dockerNotifier.onLifecycle = (action, containerId) async {
          // Switch server while action is running!
          serverNotifier.updateServer(
            const ServerProfile(
              id: 'srv-2-other',
              name: 'Other Host',
              host: '10.0.0.2',
              port: 22,
              username: 'root',
            ),
          );
          return const SSHExecutionResult(
            exitCode: 0,
            stdout: 'ok',
            stderr: '',
          );
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(() => serverNotifier),
              serverConnectionProvider.overrideWith(
                () => _FakeConnectionNotifier(
                  const ServerConnectionState(
                    status: ConnectionStateEnum.connected,
                  ),
                ),
              ),
              dockerProvider.overrideWith(() => dockerNotifier),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DockerView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm & Proceed'));
        await tester.pumpAndSettle();

        // SnackBar must NOT be shown for the other server!
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });
}
