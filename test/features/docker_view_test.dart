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
  Future<void> refresh({bool quiet = false}) async {}
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

  group('DockerView filter row, cached error and empty states', () {
    const mobileError =
        'Cannot connect to the Docker daemon at unix:///var/run/docker.sock';
    const mobileWidth = 390.0;
    const mobileHeight = 844.0;

    void useMobileViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(mobileWidth, mobileHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Compose 模式下容器分组标题也复用 `dockerViewGroupContainers`，
    /// 因此必须把查找范围限制在选择器内。
    Finder selectorSegment(String label) => find.descendant(
      of: find.byType(SegmentedButton<bool>),
      matching: find.text(label),
    );

    /// 选择器分段必须在 390px 手机宽度内完整可见且可点击（不允许横向滚出去）。
    void expectSegmentVisible(WidgetTester tester, String label) {
      final finder = selectorSegment(label);
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$label 溢出左侧');
      expect(
        rect.right,
        lessThanOrEqualTo(mobileWidth),
        reason: '$label 溢出 390px 视口右侧',
      );
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(mobileHeight));
    }

    /// `TextButton.icon` 生成的是 TextButton 的私有子类型，
    /// `find.byType(TextButton)` 不会命中，运行时判定才可靠。
    Finder retryButton() => find.ancestor(
      of: find.text('Retry'),
      matching: find.byWidgetPredicate((widget) => widget is TextButton),
    );

    testWidgets(
      'mobile puts the status filter row below the Container/Compose selector',
      (tester) async {
        useMobileViewport(tester);
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(containers: [_container1, _container2]),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pumpAndSettle();

        final selector = find.byType(SegmentedButton<bool>);
        expect(selector, findsOneWidget);
        expect(selectorSegment('Containers'), findsOneWidget);
        expect(selectorSegment('Compose Projects'), findsOneWidget);

        // Both segments must stay on screen and tappable on a 390px phone.
        expectSegmentVisible(tester, 'Containers');
        expectSegmentVisible(tester, 'Compose Projects');
        await tester.tap(selectorSegment('Compose Projects'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<SegmentedButton<bool>>(selector).selected,
          <bool>{true},
          reason: 'Compose 分段必须真的可以点中',
        );
        await tester.tap(selectorSegment('Containers'));
        await tester.pumpAndSettle();

        // The paused filter must survive the mobile re-layout.
        for (final label in ['All', 'Running', 'Exited', 'Paused']) {
          expect(find.text(label), findsOneWidget);
        }

        final selectorBottom = tester.getBottomLeft(selector).dy;
        final filterRowTop = tester
            .getTopLeft(
              find
                  .ancestor(
                    of: find.byType(FilterChip).first,
                    matching: find.byType(Row),
                  )
                  .first,
            )
            .dy;
        expect(
          filterRowTop,
          greaterThan(selectorBottom),
          reason: '状态过滤行必须单独一行，位于容器/Compose 选择器下方',
        );
      },
    );

    testWidgets(
      'a failed refresh keeps the cached list and shows the retry error',
      (tester) async {
        useMobileViewport(tester);
        final dockerNotifier = _CountingDockerNotifier(
          const DockerState(
            containers: [_container1, _container2],
            errorMessage: mobileError,
            exitCode: 1,
          ),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pumpAndSettle();

        // Cached containers stay visible next to the retry error.
        expect(find.text('web-nginx'), findsOneWidget);
        expect(find.text('redis-cache'), findsOneWidget);
        expect(find.text(mobileError), findsOneWidget);

        final retry = retryButton();
        expect(retry, findsOneWidget);
        expect(
          tester.widgetList<TextButton>(retry).single.onPressed,
          isNotNull,
        );

        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(dockerNotifier.refreshCalls, 1);
      },
    );

    testWidgets(
      'the error stays visible when a filter narrows the cache to empty',
      (tester) async {
        useMobileViewport(tester);
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(
            containers: [_container1, _container2],
            errorMessage: mobileError,
            exitCode: 1,
            // Nothing is paused, so the filtered list is empty while the cache is not.
            filterState: DockerContainerState.paused,
          ),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pumpAndSettle();

        expect(find.text('web-nginx'), findsNothing);
        expect(find.text('redis-cache'), findsNothing);
        // Filtered-empty must not be mistaken for an error-free empty state.
        expect(find.text(mobileError), findsOneWidget);
        expect(retryButton(), findsOneWidget);
        expect(find.text('No items found'), findsOneWidget);
      },
    );

    testWidgets(
      'a connected host with no containers is distinct from a disconnected one',
      (tester) async {
        useMobileViewport(tester);
        final dockerNotifier = _FakeDockerNotifier(
          const DockerState(containers: []),
        );

        await tester.pumpWidget(_buildTestApp(dockerNotifier: dockerNotifier));
        await tester.pumpAndSettle();

        // Containers mode: true empty of a live host.
        expect(find.text('No containers found on server'), findsOneWidget);
        expect(find.text('Disconnected'), findsNothing);
        expect(find.text('Server is offline'), findsNothing);

        // Compose mode: true empty of a live host, different message.
        await tester.tap(selectorSegment('Compose Projects'));
        await tester.pumpAndSettle();
        expect(find.text('No Docker Compose projects found'), findsOneWidget);
        expect(find.text('No containers found on server'), findsNothing);
        expect(find.text('Disconnected'), findsNothing);
      },
    );

    testWidgets(
      'disconnected is reported in both modes instead of a true empty',
      (tester) async {
        useMobileViewport(tester);
        final dockerNotifier = _FakeDockerNotifier(const DockerState());

        for (final mode in ['Containers', 'Compose Projects']) {
          await tester.pumpWidget(
            _buildTestApp(
              dockerNotifier: dockerNotifier,
              connState: const ServerConnectionState(
                status: ConnectionStateEnum.disconnected,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (mode == 'Compose Projects') {
            await tester.tap(selectorSegment('Compose Projects'));
            await tester.pumpAndSettle();
          }

          expect(find.text('Disconnected'), findsOneWidget, reason: mode);
          expect(
            find.text(
              'Establish an active SSH connection to manage resources and stream metrics.',
            ),
            findsOneWidget,
            reason: mode,
          );
          expect(find.text('No containers found on server'), findsNothing);
          expect(find.text('No Docker Compose projects found'), findsNothing);
        }
      },
    );
  });
}

class _CountingDockerNotifier extends _FakeDockerNotifier {
  _CountingDockerNotifier(super.state);

  int refreshCalls = 0;

  @override
  Future<void> refresh({bool quiet = false}) async {
    refreshCalls++;
  }
}
