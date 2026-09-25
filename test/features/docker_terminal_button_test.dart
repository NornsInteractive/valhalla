import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/features/docker/docker_view.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:xterm/xterm.dart';

ServerProfile _testServer() => const ServerProfile(
  id: 'srv-1',
  name: 'Docker Host',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
);

const _runningContainer = DockerContainer(
  id: 'c-running-1234567890ab',
  name: 'web-nginx',
  image: 'nginx:alpine',
  status: 'Up 2 hours',
  state: DockerContainerState.running,
  ports: '80:80',
);

const _stoppedContainer = DockerContainer(
  id: 'c-stopped-1234567890ab',
  name: 'redis-cache',
  image: 'redis:7',
  status: 'Exited (0) 5 minutes ago',
  state: DockerContainerState.exited,
  ports: '6379:6379',
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _initial;
  _FakeActiveServerNotifier(this._initial);
  @override
  ServerProfile? build() => _initial;
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _initial;
  _FakeConnectionNotifier(this._initial);
  @override
  ServerConnectionState build() => _initial;
}

class _FakeDockerNotifier extends DockerNotifier {
  final DockerState _state;
  _FakeDockerNotifier(this._state);
  @override
  DockerState build() => _state;
}

class _OpenSshClient implements SSHClient {
  @override
  bool get isClosed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeExecutor implements SshCommandExecutor {
  @override
  SSHClient? getClient(String serverId) => _OpenSshClient();
  @override
  bool isConnected(String serverId) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridge extends TerminalSessionBridge {
  bool startCalled = false;
  bool disposeCalled = false;
  final List<String> sentKeys = [];
  bool shouldThrowOnStart = false;

  _FakeBridge()
    : super(
        terminal: Terminal(maxLines: 100),
        serverId: 'srv-1',
        serverName: 'Docker Host',
      );

  @override
  Future<void> start({int initialWidth = 80, int initialHeight = 24}) async {
    if (shouldThrowOnStart) {
      throw Exception('Failed to connect to docker exec');
    }
    startCalled = true;
  }

  @override
  void sendKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    sentKeys.add(key);
  }

  @override
  void dispose() {
    disposeCalled = true;
    super.dispose();
  }
}

class _FakeDockerCliService extends DockerCliService {
  final _FakeBridge bridge;
  bool openTerminalCalled = false;
  String? capturedServerId;
  DockerContainer? capturedContainer;
  String? capturedServerName;
  DockerTerminalShell? capturedPreferredShell;
  DockerTerminalShell returnShell = DockerTerminalShell.bash;

  _FakeDockerCliService(this.bridge) : super(_FakeExecutor());

  @override
  Future<({TerminalSessionBridge bridge, DockerTerminalShell shell})>
  openTerminal(
    String serverId,
    DockerContainer container,
    String serverName, {
    DockerTerminalShell preferredShell = DockerTerminalShell.bash,
  }) async {
    openTerminalCalled = true;
    capturedServerId = serverId;
    capturedContainer = container;
    capturedServerName = serverName;
    capturedPreferredShell = preferredShell;
    return (bridge: bridge, shell: returnShell);
  }
}

late LocalStorageService _testLocalStorage;

Widget _buildTestApp({
  required DockerState dockerState,
  required DockerCliService cliService,
  LocalStorageService? localStorage,
  Size size = const Size(1024, 768),
}) {
  final server = _testServer();
  final connState = const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );

  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(server),
      ),
      serverConnectionProvider.overrideWith(
        () => _FakeConnectionNotifier(connState),
      ),
      dockerProvider.overrideWith(() => _FakeDockerNotifier(dockerState)),
      dockerCliServiceProvider.overrideWithValue(cliService),
      localStorageServiceProvider.overrideWithValue(
        localStorage ?? _testLocalStorage,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const Scaffold(body: DockerView()),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    _testLocalStorage = LocalStorageService(prefs);
  });

  group('Docker Container Terminal Button', () {
    testWidgets(
      'running container shows terminal button and clicking it starts bridge and opens SharedTerminalCanvas',
      (tester) async {
        final bridge = _FakeBridge();
        final cliService = _FakeDockerCliService(bridge);
        final state = const DockerState(
          containers: [_runningContainer],
          isLoading: false,
        );

        await tester.pumpWidget(
          _buildTestApp(dockerState: state, cliService: cliService),
        );
        await tester.pumpAndSettle();

        final terminalBtn = find.byKey(
          const Key('docker_terminal_button_c-running-1234567890ab'),
        );
        expect(terminalBtn, findsOneWidget);

        // Click terminal button
        await tester.tap(terminalBtn);
        await tester.pumpAndSettle();

        // Verify openTerminal and bridge.start were invoked
        expect(cliService.openTerminalCalled, isTrue);
        expect(cliService.capturedServerId, 'srv-1');
        expect(cliService.capturedContainer?.id, _runningContainer.id);
        expect(bridge.startCalled, isTrue);

        // Verify SharedTerminalCanvas is displayed
        expect(find.byType(SharedTerminalCanvas), findsOneWidget);
        expect(find.textContaining('web-nginx'), findsWidgets);

        // Verify closing the dialog disposes the bridge
        final closeBtn = find.byIcon(Icons.close);
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.byType(SharedTerminalCanvas), findsNothing);
        expect(bridge.disposeCalled, isTrue);
      },
    );

    testWidgets('compact mobile screen opens fullscreen dialog for terminal', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      final cliService = _FakeDockerCliService(bridge);
      final state = const DockerState(
        containers: [_runningContainer],
        isLoading: false,
      );

      // Mobile screen width < 600
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          dockerState: state,
          cliService: cliService,
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      final terminalBtn = find.byKey(
        const Key('docker_terminal_button_c-running-1234567890ab'),
      );
      await tester.tap(terminalBtn);
      await tester.pumpAndSettle();

      // Fullscreen dialog on mobile
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(SharedTerminalCanvas), findsOneWidget);

      // Close fullscreen dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(bridge.disposeCalled, isTrue);
    });

    testWidgets('stopped container has disabled terminal button', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      final cliService = _FakeDockerCliService(bridge);
      final state = const DockerState(
        containers: [_stoppedContainer],
        isLoading: false,
      );

      await tester.pumpWidget(
        _buildTestApp(dockerState: state, cliService: cliService),
      );
      await tester.pumpAndSettle();

      final terminalBtn = find.byKey(
        const Key('docker_terminal_button_c-stopped-1234567890ab'),
      );
      expect(terminalBtn, findsOneWidget);

      final iconButton = tester.widget<IconButton>(terminalBtn);
      expect(iconButton.onPressed, isNull);

      // openTerminal should not be called
      expect(cliService.openTerminalCalled, isFalse);
    });

    testWidgets(
      'handles error during bridge start gracefully and shows snackbar',
      (tester) async {
        final bridge = _FakeBridge()..shouldThrowOnStart = true;
        final cliService = _FakeDockerCliService(bridge);
        final state = const DockerState(
          containers: [_runningContainer],
          isLoading: false,
        );

        await tester.pumpWidget(
          _buildTestApp(dockerState: state, cliService: cliService),
        );
        await tester.pumpAndSettle();

        final terminalBtn = find.byKey(
          const Key('docker_terminal_button_c-running-1234567890ab'),
        );
        await tester.tap(terminalBtn);
        await tester.pumpAndSettle();

        // Dialog should not remain open
        expect(find.byType(SharedTerminalCanvas), findsNothing);
        // SnackBar with error should be visible
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Failed to connect'), findsOneWidget);
        // Bridge should have been disposed
        expect(bridge.disposeCalled, isTrue);
      },
    );

    testWidgets('respects stored shell preference when opening terminal', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.setContainerShell('srv-1', _runningContainer.name, 'sh');

      final bridge = _FakeBridge();
      final cliService = _FakeDockerCliService(bridge)
        ..returnShell = DockerTerminalShell.sh;
      final state = const DockerState(
        containers: [_runningContainer],
        isLoading: false,
      );

      await tester.pumpWidget(
        _buildTestApp(
          dockerState: state,
          cliService: cliService,
          localStorage: storage,
        ),
      );
      await tester.pumpAndSettle();

      final terminalBtn = find.byKey(
        const Key('docker_terminal_button_c-running-1234567890ab'),
      );
      await tester.tap(terminalBtn);
      await tester.pumpAndSettle();

      expect(cliService.capturedPreferredShell, DockerTerminalShell.sh);
    });

    testWidgets(
      'displays fallback notice when bash is preferred but actual shell is sh',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        // Default is bash
        final bridge = _FakeBridge();
        final cliService = _FakeDockerCliService(bridge)
          ..returnShell = DockerTerminalShell.sh;
        final state = const DockerState(
          containers: [_runningContainer],
          isLoading: false,
        );

        await tester.pumpWidget(
          _buildTestApp(
            dockerState: state,
            cliService: cliService,
            localStorage: storage,
          ),
        );
        await tester.pumpAndSettle();

        final terminalBtn = find.byKey(
          const Key('docker_terminal_button_c-running-1234567890ab'),
        );
        await tester.tap(terminalBtn);
        await tester.pumpAndSettle();

        // Fallback snackbar should be displayed
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.dockerBashFallbackNotice), findsOneWidget);
      },
    );

    testWidgets(
      'shell selector changes container shell in storage and does not overflow on narrow screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);

        final bridge = _FakeBridge();
        final cliService = _FakeDockerCliService(bridge);
        final state = const DockerState(
          containers: [_runningContainer],
          isLoading: false,
        );

        // Narrow screen: 320px
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            dockerState: state,
            cliService: cliService,
            localStorage: storage,
            size: const Size(320, 640),
          ),
        );
        await tester.pumpAndSettle();

        final shellSelect = find.byKey(
          const Key('docker_shell_select_c-running-1234567890ab'),
        );
        expect(shellSelect, findsOneWidget);

        // Select Sh
        await tester.tap(shellSelect);
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final shItem = find.text(l10n.dockerShellSh);
        expect(shItem, findsOneWidget);
        await tester.tap(shItem);
        await tester.pumpAndSettle();

        expect(
          storage.getContainerShell('srv-1', _runningContainer.name),
          'sh',
        );
      },
    );
  });
}
