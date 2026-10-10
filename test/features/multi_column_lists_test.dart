import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/commands_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/features/commands/quick_commands_view.dart';
import 'package:valhalla/features/dashboard/dashboard_provider.dart';
import 'package:valhalla/features/dashboard/dashboard_view.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/features/docker/docker_view.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/settings/settings_view.dart';
import 'package:valhalla/features/settings/widgets/theme_accent_color_dialog.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/l10n/app_localizations.dart';

// --- Test doubles ---

class _TestFakeOperations implements SftpOperations {
  List<SftpFileItem> files;
  final List<String> directoriesCreated = [];
  final List<(String, String)> filesWritten = [];

  _TestFakeOperations(this.files);

  @override
  Future<List<SftpFileItem>> listFiles(String path) async => files;

  @override
  Future<String> readFileContent(String path) async => 'file content of $path';

  @override
  Future<void> writeFileContent(String path, String content) async {
    filesWritten.add((path, content));
  }

  @override
  Future<void> createDirectory(String path) async {
    directoriesCreated.add(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async => 100;

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async => 100;
}

class _TestSftpNotifier extends SftpNotifier {
  final SftpState _initial;
  _TestSftpNotifier(this._initial);

  @override
  SftpState build() => _initial;
}

class _TestDockerNotifier extends DockerNotifier {
  final DockerState _state;
  _TestDockerNotifier(this._state);
  @override
  DockerState build() => _state;
}

class _TestCommandsNotifier extends CommandsNotifier {
  final CommandsState _state;
  final Future<SSHExecutionResult> Function(
    QuickCommand cmd,
    Map<String, String> params,
  )?
  onExecuteBackground;

  _TestCommandsNotifier(this._state, {this.onExecuteBackground});

  @override
  CommandsState build() => _state;

  @override
  Future<SSHExecutionResult> executeBackground(
    QuickCommand cmd,
    Map<String, String> params,
  ) async {
    if (onExecuteBackground != null) {
      return await onExecuteBackground!(cmd, params);
    }
    return super.executeBackground(cmd, params);
  }
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _state;
  _TestServerConnectionNotifier(this._state);
  @override
  ServerConnectionState build() => _state;
}

class _TestAgentRegistryNotifier extends AgentRegistryNotifier {
  final AgentRegistryState _state;
  _TestAgentRegistryNotifier(this._state);
  @override
  AgentRegistryState build() => _state;
}

Widget _wrapWithApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final testServer = ServerProfile(
    id: 'test-srv-1',
    name: 'Test Server',
    host: '10.0.0.1',
    port: 22,
    username: 'root',
    authType: AuthType.password,
  );

  final testFiles = List.generate(
    8,
    (i) => SftpFileItem(
      name: i.isEven ? 'folder_$i' : 'file_$i.txt',
      path: i.isEven ? '/folder_$i' : '/file_$i.txt',
      isDirectory: i.isEven,
      sizeBytes: 1024 * (i + 1),
      formattedSize: '${i + 1} KB',
      modified: '2026-09-01 10:0$i',
      permissions: 'rwxr-xr-x',
    ),
  );

  final testContainers = List.generate(
    6,
    (i) => DockerContainer(
      id: 'container_id_$i',
      name: 'web-server-$i',
      image: 'nginx:alpine',
      state: i.isEven
          ? DockerContainerState.running
          : DockerContainerState.exited,
      status: i.isEven ? 'Up 2 hours' : 'Exited (0)',
      ports: '0.0.0.0:${8080 + i}->80/tcp',
    ),
  );

  final testCommands = List.generate(
    6,
    (i) => QuickCommand(
      id: 'cmd-$i',
      title: 'Command $i',
      command: 'echo test $i',
      description: 'Test description $i',
      category: 'General',
      isDangerous: i == 1,
    ),
  );

  final testAgents = List.generate(
    4,
    (i) => AgentRuntimeState(
      profile: AgentProfile(
        id: 'agent-$i',
        serverId: 'test-srv-1',
        name: 'Agent $i',
        description: 'Agent description $i',
        cliCommand: 'agent-cli-$i',
        acpCommand: 'agent-acp-$i',
      ),
      status: AgentEnvironmentStatus(
        kind: AgentEnvironmentStatusKind.ready,
        checkedAt: DateTime(2026, 9, 1),
        version: '1.0.$i',
      ),
    ),
  );

  group('Multi-column Layout & Zero Regression (Task B)', () {
    // 1. SFTP File List
    testWidgets('SFTP File List: 1 column on compact (<600)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeOps = _TestFakeOperations(testFiles);
      final sftpState = SftpState(files: testFiles, currentPath: '/');

      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        _wrapWithApp(
          child: const SftpFileView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            sftpOperationsProvider.overrideWithValue(fakeOps),
            sftpProvider.overrideWith(() => _TestSftpNotifier(sftpState)),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final fileNames = ['folder_0', 'file_1.txt', 'folder_2', 'file_3.txt'];
      final dxSet = <double>{};
      for (final name in fileNames) {
        dxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        dxSet.length,
        equals(1),
        reason:
            'All file items on compact screen must share the exact same dx (single-column)',
      );
    });

    testWidgets('SFTP File List: multi-column on wide (>=600)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeOps = _TestFakeOperations(testFiles);
      final sftpState = SftpState(files: testFiles, currentPath: '/');

      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        _wrapWithApp(
          child: const SftpFileView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            sftpOperationsProvider.overrideWithValue(fakeOps),
            sftpProvider.overrideWith(() => _TestSftpNotifier(sftpState)),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final fileNames = ['folder_0', 'folder_2', 'folder_4', 'folder_6'];
      final dxSet = <double>{};
      for (final name in fileNames) {
        dxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        dxSet.length,
        greaterThanOrEqualTo(3),
        reason:
            '1200px wide layout should scale to 3+ columns with maxCrossAxisExtent: 380',
      );
    });

    testWidgets(
      'SFTP File View: all action bar, breadcrumb, search, sort, and transfer list interactions are preserved',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeOps = _TestFakeOperations(testFiles);
        final sftpState = SftpState(files: testFiles, currentPath: '/');

        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        await tester.pumpWidget(
          _wrapWithApp(
            child: const SftpFileView(),
            overrides: [
              localStorageServiceProvider.overrideWithValue(local),
              sftpOperationsProvider.overrideWithValue(fakeOps),
              sftpProvider.overrideWith(() => _TestSftpNotifier(sftpState)),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                () => _TestServerConnectionNotifier(
                  const ServerConnectionState(
                    status: ConnectionStateEnum.connected,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 1. Action bar buttons: Upload, New Folder, New File
        expect(find.byIcon(Icons.upload_file), findsOneWidget);
        expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
        expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);

        // 2. Breadcrumbs & Refresh button
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.text('/'), findsWidgets);

        // 3. Search filter bar
        expect(find.byType(TextField), findsOneWidget);

        // 4. Sort menu button
        expect(find.byIcon(Icons.sort), findsOneWidget);

        // 5. Transfer list button
        expect(find.byKey(const Key('sftpTransferListButton')), findsOneWidget);

        // 6. Context menu item interaction: tap more_vert on a file to verify download action
        final fileTile = find.ancestor(
          of: find.text('file_1.txt'),
          matching: find.byType(ListTile),
        );
        final moreBtn = find.descendant(
          of: fileTile,
          matching: find.byIcon(Icons.more_vert),
        );
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.download), findsOneWidget);
        // Close popup menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 6. Test interaction: tap directory item
        await tester.tap(find.text('folder_0'));
        await tester.pumpAndSettle();

        // 7. Test search filter
        await tester.enterText(find.byType(TextField), 'file_1');
        await tester.pumpAndSettle();
        expect(find.text('file_1.txt'), findsOneWidget);
      },
    );

    // 2. Dashboard Metrics
    testWidgets(
      'Dashboard Metrics: 4 columns on 1400px wide screen via maxCrossAxisExtent: 280',
      (tester) async {
        const snap = SystemMetricsSnapshot(
          cpuUsedRatio: 0.45,
          memoryUsedRatio: 0.60,
          rootDiskUsedPercent: 55.0,
          load1: 1.2,
          load5: 1.0,
          load15: 0.8,
          uptimeSeconds: 3600,
        );

        tester.view.physicalSize = const Size(1400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            child: const DashboardView(),
            overrides: [
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                () => _TestServerConnectionNotifier(
                  const ServerConnectionState(
                    status: ConnectionStateEnum.connected,
                  ),
                ),
              ),
              systemMetricsStreamProvider.overrideWith(
                (ref) => Stream.value(snap),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final metricIcons = [
          Icons.speed_rounded,
          Icons.memory_rounded,
          Icons.storage_rounded,
          Icons.timer_outlined,
        ];
        final wideDxSet = <double>{};
        for (final icon in metricIcons) {
          final f = find.byIcon(icon);
          if (f.evaluate().isNotEmpty) {
            wideDxSet.add(tester.getTopLeft(f).dx);
          }
        }
        expect(
          wideDxSet.length,
          equals(4),
          reason:
              'On 1400px wide screen, 4 metric cards should be in 4 distinct columns',
        );
      },
    );

    // 3. Settings Theme Cards
    testWidgets(
      'Settings Theme Cards: compact (<500) shows single-select tile and dialog',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            child: const SettingsView(),
            overrides: [localStorageServiceProvider.overrideWithValue(local)],
          ),
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const Key('settings_theme_mode_tile'));
        expect(tile, findsOneWidget);

        await tester.tap(tile);
        await tester.pumpAndSettle();

        final darkTile = find.byKey(const Key('settings_theme_mode_dark'));
        final amoledTile = find.byKey(const Key('settings_theme_mode_amoled'));
        expect(darkTile, findsOneWidget);
        expect(amoledTile, findsOneWidget);
        expect(
          tester.getTopLeft(darkTile).dx,
          equals(tester.getTopLeft(amoledTile).dx),
          reason:
              'Compact theme options in dialog stack vertically in 1 column',
        );
      },
    );

    testWidgets(
      'Settings Theme Cards: wide screen (>500) opens accent color dialog',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(
            child: const SettingsView(),
            overrides: [localStorageServiceProvider.overrideWithValue(local)],
          ),
        );
        await tester.pumpAndSettle();

        final accentTile = find.byKey(const Key('settings_accent_color_tile'));
        expect(accentTile, findsOneWidget);

        await tester.tap(accentTile);
        await tester.pumpAndSettle();

        expect(find.byType(ThemeAccentColorDialog), findsOneWidget);
      },
    );

    // 4. Docker Containers
    testWidgets('Docker Containers: 1 column on compact (<600)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();
      final dockerState = DockerState(containers: testContainers);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const DockerView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            dockerProvider.overrideWith(() => _TestDockerNotifier(dockerState)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final cardNames = ['web-server-0', 'web-server-1', 'web-server-2'];
      final compactDxSet = <double>{};
      for (final name in cardNames) {
        compactDxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        compactDxSet.length,
        equals(1),
        reason: 'Docker containers must be single-column on compact screens',
      );
    });

    testWidgets('Docker Containers: multi-column on wide (>=600)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();
      final dockerState = DockerState(containers: testContainers);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const DockerView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            dockerProvider.overrideWith(() => _TestDockerNotifier(dockerState)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final cardNames = ['web-server-0', 'web-server-1', 'web-server-2'];
      final wideDxSet = <double>{};
      for (final name in cardNames) {
        wideDxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        wideDxSet.length,
        greaterThanOrEqualTo(2),
        reason:
            'Docker containers must scale to multiple columns on wide screens',
      );
    });

    // 5. Quick Commands
    testWidgets('Quick Commands: 1 column on compact (<600)', (tester) async {
      final cmdState = CommandsState(allCommands: testCommands);

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const QuickCommandsView(),
          overrides: [
            commandsProvider.overrideWith(
              () => _TestCommandsNotifier(cmdState),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final cmdNames = ['Command 0', 'Command 1', 'Command 2'];
      final compactDxSet = <double>{};
      for (final name in cmdNames) {
        compactDxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        compactDxSet.length,
        equals(1),
        reason: 'Commands must be single-column on compact screens',
      );
    });

    testWidgets('Quick Commands: multi-column on wide (>=600)', (tester) async {
      final cmdState = CommandsState(allCommands: testCommands);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const QuickCommandsView(),
          overrides: [
            commandsProvider.overrideWith(
              () => _TestCommandsNotifier(cmdState),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final cmdNames = ['Command 0', 'Command 1', 'Command 2'];
      final wideDxSet = <double>{};
      for (final name in cmdNames) {
        wideDxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        wideDxSet.length,
        greaterThanOrEqualTo(2),
        reason: 'Commands must scale to multiple columns on wide screens',
      );
    });

    // 6. Agent Management
    testWidgets('Agent Management: 1 column on compact (<600)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final registryState = AgentRegistryState(
        serverId: 'test-srv-1',
        agents: testAgents,
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier(registryState),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final agentNames = ['Agent 0', 'Agent 1'];
      final compactDxSet = <double>{};
      for (final name in agentNames) {
        final finder = find.text(name);
        expect(finder, findsOneWidget);
        compactDxSet.add(tester.getTopLeft(finder).dx);
      }
      expect(
        compactDxSet.length,
        equals(1),
        reason: 'Agent cards must be single-column on compact screens',
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('Agent Management: multi-column on wide (>=600)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final registryState = AgentRegistryState(
        serverId: 'test-srv-1',
        agents: testAgents,
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _TestServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier(registryState),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final agentNames = ['Agent 0', 'Agent 1', 'Agent 2'];
      final wideDxSet = <double>{};
      for (final name in agentNames) {
        wideDxSet.add(tester.getTopLeft(find.text(name)).dx);
      }
      expect(
        wideDxSet.length,
        greaterThanOrEqualTo(2),
        reason: 'Agent cards must scale to multiple columns on wide screens',
      );
    });

    final dualCmd = const QuickCommand(
      id: 'cmd-dual',
      title: 'Dual Stream Command',
      command: 'printf UI_OUT; printf UI_ERR >&2; exit 7',
      category: 'Custom',
      description: 'Tests dual output stream',
      isDangerous: false,
    );

    testWidgets(
      'QuickCommandsView background execution displays both stdout and stderr on exit 7',
      (tester) async {
        final cmdState = CommandsState(allCommands: [dualCmd]);

        await tester.pumpWidget(
          _wrapWithApp(
            child: const QuickCommandsView(),
            overrides: [
              commandsProvider.overrideWith(
                () => _TestCommandsNotifier(
                  cmdState,
                  onExecuteBackground: (cmd, params) async {
                    return const SSHExecutionResult(
                      exitCode: 7,
                      stdout: 'UI_OUT',
                      stderr: 'UI_ERR',
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap on command card to trigger execution sheet
        await tester.tap(find.text('Dual Stream Command'));
        await tester.pumpAndSettle();

        // Select background execution channel
        final backgroundChannel = find.byIcon(Icons.play_circle_outline);
        expect(backgroundChannel, findsOneWidget);
        await tester.tap(backgroundChannel);
        await tester.pumpAndSettle();

        // Loading dialog must be gone and result dialog must be visible
        expect(find.byKey(const Key('cmd_loading_dialog')), findsNothing);
        expect(find.byKey(const Key('cmd_result_dialog')), findsOneWidget);

        // Verify exitCode 7 is displayed
        expect(
          find.descendant(
            of: find.byKey(const Key('cmd_result_dialog')),
            matching: find.textContaining('7'),
          ),
          findsOneWidget,
        );

        // Verify BOTH stdout and stderr are simultaneously displayed without dropping stderr!
        expect(find.text('UI_OUT'), findsOneWidget);
        expect(find.text('UI_ERR'), findsOneWidget);

        // Close the result dialog
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('cmd_result_dialog')),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cmd_result_dialog')), findsNothing);
      },
    );

    testWidgets(
      'QuickCommandsView background execution dismisses loading and shows sanitized error on throw',
      (tester) async {
        final cmdState = CommandsState(allCommands: [dualCmd]);

        await tester.pumpWidget(
          _wrapWithApp(
            child: const QuickCommandsView(),
            overrides: [
              commandsProvider.overrideWith(
                () => _TestCommandsNotifier(
                  cmdState,
                  onExecuteBackground: (cmd, params) async {
                    throw Exception(
                      'Connection error: password=secret_token_12345 host unreachable',
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dual Stream Command'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_circle_outline));
        await tester.pumpAndSettle();

        // Loading must disappear after exception!
        expect(find.byKey(const Key('cmd_loading_dialog')), findsNothing);
        // Error result dialog must be visible
        expect(find.byKey(const Key('cmd_result_dialog')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('cmd_result_dialog')),
            matching: find.textContaining('-1'),
          ),
          findsOneWidget,
        );

        // Secret token must be sanitized, never leaked in raw form
        expect(find.textContaining('secret_token_12345'), findsNothing);
        expect(find.textContaining('password=***'), findsOneWidget);

        // Close error dialog
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('cmd_result_dialog')),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cmd_result_dialog')), findsNothing);
      },
    );

    testWidgets(
      'QuickCommandsView background execution handles premature loading dismissal gracefully',
      (tester) async {
        final cmdState = CommandsState(allCommands: [dualCmd]);
        final completer = Completer<SSHExecutionResult>();

        await tester.pumpWidget(
          _wrapWithApp(
            child: const QuickCommandsView(),
            overrides: [
              commandsProvider.overrideWith(
                () => _TestCommandsNotifier(
                  cmdState,
                  onExecuteBackground: (cmd, params) => completer.future,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Dual Stream Command'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_circle_outline));
        await tester.pump(); // Starts execution, loading dialog opens

        expect(find.byKey(const Key('cmd_loading_dialog')), findsOneWidget);

        // User backs out / dismisses loading dialog prematurely
        Navigator.of(
          tester.element(find.byKey(const Key('cmd_loading_dialog'))),
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cmd_loading_dialog')), findsNothing);

        // Background execution completes after dialog was already closed
        completer.complete(
          const SSHExecutionResult(
            exitCode: 0,
            stdout: 'LATE_COMPLETED',
            stderr: '',
          ),
        );
        await tester.pumpAndSettle();

        // QuickCommandsView remains mounted, result dialog shows
        expect(find.byType(QuickCommandsView), findsOneWidget);
        expect(find.byKey(const Key('cmd_result_dialog')), findsOneWidget);
        expect(find.text('LATE_COMPLETED'), findsOneWidget);
      },
    );
  });
}
