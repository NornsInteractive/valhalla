import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/file_bookmarks_provider.dart';
import 'package:valhalla/core/providers/security_settings_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/host_key_entry.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/agent_repository.dart';
import 'package:valhalla/data/services/configuration_backup_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/docker/widgets/docker_project_confirm_dialog.dart';
import 'package:valhalla/features/files/widgets/file_bookmarks_dialog.dart';
import 'package:valhalla/features/settings/widgets/clear_credentials_dialog.dart';
import 'package:valhalla/features/settings/widgets/configuration_migration_dialog.dart';
import 'package:valhalla/features/settings/widgets/default_agent_dialog.dart';
import 'package:valhalla/features/settings/widgets/trusted_hosts_dialog.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeTrustedHostsNotifier extends TrustedHostsNotifier {
  _FakeTrustedHostsNotifier(this._entries);

  final List<HostKeyEntry> _entries;
  final revokeCalls = <String>[];
  Object? revokeError;
  Completer<void>? revokeGate;

  @override
  List<HostKeyEntry> build() => _entries;

  @override
  Future<void> revoke(String hostPort) async {
    revokeCalls.add(hostPort);
    final gate = revokeGate;
    if (gate != null) await gate.future;
    final error = revokeError;
    if (error != null) throw error;
  }
}

class _FakeBookmarksNotifier extends FileBookmarksNotifier {
  _FakeBookmarksNotifier(this._initial);

  final List<String> _initial;
  final toggleCalls = <String>[];
  Object? toggleError;
  Completer<void>? toggleGate;

  @override
  List<String> build() => _initial;

  @override
  Future<void> toggle(String path) async {
    toggleCalls.add(path);
    final gate = toggleGate;
    if (gate != null) await gate.future;
    final error = toggleError;
    if (error != null) throw error;
  }
}

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  _FakeActiveServerNotifier(this._server);

  final ServerProfile? _server;

  @override
  ServerProfile? build() => _server;

  void switchTo(ServerProfile? server) {
    state = server;
  }
}

class _FakeAgentStorage extends LocalStorageService {
  _FakeAgentStorage(super.prefs, this._agents);

  final List<AgentProfile> _agents;

  @override
  List<AgentProfile> getAgents() => _agents;
}

class _FakeServerListNotifier extends ServerListNotifier {
  _FakeServerListNotifier(this._servers);

  final List<ServerProfile> _servers;

  @override
  List<ServerProfile> build() => _servers;
}

Widget _dialogHost({
  required List<Override> overrides,
  required void Function(BuildContext context) open,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_dialog'),
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

HostKeyEntry _hostKeyEntry() => HostKeyEntry(
  hostPort:
      'bastion-prod-edge-cluster-node-07.internal.corp.example-region.test:22222',
  keyType: 'ssh-ed25519',
  fingerprintSha256:
      'SHA256:qZ9Xk8vT2mR4nB7cD1fG5hJ9lP3sW6yA0uE4iO7pQ8rT2vX5zA1bC3dE6fG8hI9jK0lM2nO4pQ5rS6tU7vW8xY9zA0b1c2',
  trustedAt: DateTime(2026, 10, 9, 15, 58, 7),
);

List<DockerContainer> _dockerContainers() => [
  DockerContainer(
    id: 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
    name: 'web-frontend-long-name-01',
    image: 'registry.internal.example.com/team/web-frontend:release-2026.10.09',
    status: 'Up 3 hours',
    state: DockerContainerState.running,
    ports: '0.0.0.0:8080->80/tcp',
    composeProject: 'observability-stack-edge-01',
    composeService: 'web-frontend-service-with-a-very-long-name',
  ),
  DockerContainer(
    id: 'ff00ee11dd22cc33bb44aa5566778899',
    name: 'worker-queue-consumer-02',
    image: 'registry.internal.example.com/team/worker:latest',
    status: 'Exited (0) 2 minutes ago',
    state: DockerContainerState.exited,
    ports: '',
    composeProject: 'observability-stack-edge-01',
    composeService: 'queue-worker-service-with-a-very-long-name',
  ),
];

ConfigurationBackup _backupWithSecretCommand() {
  return ConfigurationBackup(
    servers: [
      const ServerProfile(
        id: 'srv-1',
        name: 'prod-edge-01',
        host: 'bastion.internal.example.corp',
        port: 2222,
        username: 'deploy',
        authType: AuthType.password,
      ),
    ],
    agents: [
      AgentProfile(
        id: 'agent-1',
        serverId: 'srv-1',
        name: 'ops agent',
        description: '',
        cliCommand: 'ops-agent',
        acpCommand: 'acp-agent --stdio',
        loginCommand: 'ssh-add SUPERSECRET-LOGIN-TOKEN',
      ),
    ],
    commands: [
      const QuickCommand(
        id: 'cmd-1',
        title: 'Rotate registry token',
        command: 'vault kv put secret/registry token=SUPERSECRET-TOKEN-VALUE',
        category: 'ops',
        description: '',
        requiresSudo: true,
      ),
    ],
    bookmarks: {
      'srv-1': ['/var/www/prod-edge-01'],
    },
    defaultAgents: {},
    preferences: {},
  );
}

ServerProfile _longNameServer() => const ServerProfile(
  id: 'srv-1',
  name: 'production-edge-bastion-cluster-node-01',
  host: 'bastion-prod-edge-cluster-node-01.internal.corp.example-region.test',
  port: 22222,
  username: 'platform-engineering-deploy-user',
  authType: AuthType.password,
);

List<ServerProfile> _longNameServers() => [
  _longNameServer(),
  const ServerProfile(
    id: 'srv-2',
    name: 'staging-readonly-replica-cluster-node-02',
    host: 'staging-replica-cluster-node-02.internal.corp.example.test',
    port: 22022,
    username: 'staging-deploy-user',
    authType: AuthType.password,
  ),
];

List<AgentProfile> _longNameAgents() => [
  AgentProfile(
    id: 'agent-default-1',
    serverId: 'srv-1',
    name: 'claude-code-advanced-coder-agent-with-extremely-long-name-v1',
    description: '',
    cliCommand:
        'claude --dangerously-skip-permissions --model extended-reasoning-2026',
    acpCommand: 'claude-agent-acp --stdio --extended-reasoning-mode',
  ),
  AgentProfile(
    id: 'agent-default-2',
    serverId: 'srv-1',
    name: 'codex-refactoring-specialist-agent-separate-very-long-name',
    description: '',
    cliCommand: 'codex exec --full-auto --model o6-reasoning',
    acpCommand: 'codex-acp --stdio',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setSurface(WidgetTester tester, Size size, double dpr) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_dialog')));
    await tester.pumpAndSettle();
  }

  Future<void> settleFrames(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('trusted hosts dialog', () {
    testWidgets('long address/fingerprint fit at 320dp with 2x text', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      final entry = _hostKeyEntry();
      await tester.pumpWidget(
        _dialogHost(
          overrides: [
            trustedHostsProvider.overrideWith(
              () => _FakeTrustedHostsNotifier([entry]),
            ),
          ],
          textScale: 2.0,
          open: TrustedHostsDialog.show,
        ),
      );
      await openDialog(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TrustedHostsDialog), findsOneWidget);
      expect(find.text(entry.hostPort), findsOneWidget);
      expect(find.text(entry.fingerprintSha256), findsOneWidget);
      expect(find.text(entry.keyType), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TrustedHostsDialog)),
      );
      expect(find.text(l10n.cmdClose), findsOneWidget);
      expect(find.byKey(Key('revoke_host_${entry.hostPort}')), findsOneWidget);
    });

    testWidgets('revoke confirmation lists hostPort and revokes once', (
      tester,
    ) async {
      setSurface(tester, const Size(1080, 2400), 3);
      final entry = _hostKeyEntry();
      final notifier = _FakeTrustedHostsNotifier([entry]);
      await tester.pumpWidget(
        _dialogHost(
          overrides: [trustedHostsProvider.overrideWith(() => notifier)],
          open: TrustedHostsDialog.show,
        ),
      );
      await openDialog(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TrustedHostsDialog)),
      );

      await tester.tap(find.byKey(Key('revoke_host_${entry.hostPort}')));
      await tester.pumpAndSettle();

      final confirmDialog = find.ancestor(
        of: find.text(l10n.settingsHostKeyRevokeConfirmTitle),
        matching: find.byType(AlertDialog),
      );
      expect(confirmDialog, findsOneWidget);
      expect(
        find.descendant(
          of: confirmDialog,
          matching: find.textContaining(entry.hostPort),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.cancel), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: confirmDialog,
          matching: find.widgetWithText(
            FilledButton,
            l10n.settingsHostKeyRevoke,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.revokeCalls, [entry.hostPort]);
      expect(find.text(l10n.settingsHostKeyRevoked), findsOneWidget);
    });

    testWidgets('revoke is busy-guarded and errors keep the dialog alive', (
      tester,
    ) async {
      setSurface(tester, const Size(1080, 2400), 3);
      final entry = _hostKeyEntry();
      final notifier = _FakeTrustedHostsNotifier([entry]);
      notifier.revokeGate = Completer<void>();
      notifier.revokeError = StateError('REVOKE_BOOM');
      await tester.pumpWidget(
        _dialogHost(
          overrides: [trustedHostsProvider.overrideWith(() => notifier)],
          open: TrustedHostsDialog.show,
        ),
      );
      await openDialog(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TrustedHostsDialog)),
      );

      await tester.tap(find.byKey(Key('revoke_host_${entry.hostPort}')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.settingsHostKeyRevoke),
      );
      await settleFrames(tester);

      expect(notifier.revokeCalls, [entry.hostPort]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(Key('revoke_host_${entry.hostPort}')));
      await tester.pump();
      expect(notifier.revokeCalls, [entry.hostPort]);

      notifier.revokeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Bad state: REVOKE_BOOM'), findsOneWidget);
      expect(find.byType(TrustedHostsDialog), findsOneWidget);
      await tester.tap(find.text(l10n.cmdClose));
      await tester.pumpAndSettle();
      expect(find.byType(TrustedHostsDialog), findsNothing);
    });
  });

  group('docker project confirmation dialog', () {
    testWidgets('exact list at 320dp 2x, cancel/confirm, desktop width', (
      tester,
    ) async {
      final containers = _dockerContainers();
      setSurface(tester, const Size(960, 2400), 3);
      bool? result;
      await tester.pumpWidget(
        _dialogHost(
          overrides: const [],
          textScale: 2.0,
          open: (context) async {
            result = await DockerProjectConfirmDialog.show(
              context,
              project: 'observability-stack-edge-01',
              action: 'stop',
              containers: containers,
            );
          },
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DockerProjectConfirmDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.dockerProjectConfirmStopTitle), findsOneWidget);
      expect(
        find.text(
          l10n.dockerProjectConfirmMessage(
            'stop',
            'observability-stack-edge-01',
            2,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('web-frontend-service-with-a-very-long-name'),
        findsOneWidget,
      );
      expect(
        find.text('queue-worker-service-with-a-very-long-name'),
        findsOneWidget,
      );
      expect(find.text('(web-frontend-long-name-01)'), findsOneWidget);
      expect(find.text('(worker-queue-consumer-02)'), findsOneWidget);
      expect(find.textContaining('a1b2c3d4e5f6'), findsOneWidget);
      expect(find.textContaining('ff00ee11dd22'), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(result, false);

      setSurface(tester, const Size(2560, 1600), 2);
      await openDialog(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('web-frontend-service-with-a-very-long-name'),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();
      expect(result, true);
    });
  });

  group('configuration export preview dialog', () {
    testWidgets('secret warning and full command text before save', (
      tester,
    ) async {
      setSurface(tester, const Size(1080, 2400), 3);
      final backup = _backupWithSecretCommand();
      bool? confirmed;
      await tester.pumpWidget(
        _dialogHost(
          overrides: const [],
          open: (context) async {
            confirmed = await ConfigExportPreviewDialog.show(
              context,
              backup: backup,
            );
          },
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConfigExportPreviewDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.configImportSecretWarning), findsOneWidget);
      expect(find.text(l10n.configExportSubtitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportServersCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportAgentsCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportCommandsCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportBookmarksCount(1)),
        ),
        findsOneWidget,
      );

      Future<void> expandTile(Finder titleFinder) async {
        final tile = find.ancestor(
          of: titleFinder,
          matching: find.byType(ExpansionTile),
        );
        await tester.ensureVisible(tile.first);
        await tester.pumpAndSettle();
        await tester.tap(titleFinder);
        await tester.pumpAndSettle();
      }

      await expandTile(find.text(l10n.selectServerTitle));
      expect(
        find.textContaining('bastion.internal.example.corp:2222'),
        findsOneWidget,
      );

      await expandTile(find.text(l10n.settingsAgentManagement));
      expect(find.textContaining('SUPERSECRET-LOGIN-TOKEN'), findsOneWidget);

      await expandTile(find.text(l10n.navCommands));
      expect(
        find.text('vault kv put secret/registry token=SUPERSECRET-TOKEN-VALUE'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsWidgets);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(confirmed, false);
      expect(find.byType(ConfigExportPreviewDialog), findsNothing);
    });
  });

  group('configuration import preview dialog', () {
    testWidgets('secret warning and command preview on desktop size', (
      tester,
    ) async {
      setSurface(tester, const Size(2560, 1600), 2);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final backup = _backupWithSecretCommand();
      bool? imported;
      await tester.pumpWidget(
        _dialogHost(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          open: (context) async {
            imported = await ConfigImportPreviewDialog.show(
              context,
              backup: backup,
            );
          },
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConfigImportPreviewDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(storage.getServers(), isEmpty);
      expect(find.text(l10n.configImportSecretWarning), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportServersCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportAgentsCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportCommandsCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportBookmarksCount(1)),
        ),
        findsOneWidget,
      );

      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('config_import_global_prefs_checkbox')),
            )
            .value,
        false,
      );

      await tester.tap(
        find.byKey(const Key('config_import_commands_expansion')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotate registry token'), findsOneWidget);
      expect(
        find.text('vault kv put secret/registry token=SUPERSECRET-TOKEN-VALUE'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsWidgets);

      await tester.tap(find.byKey(const Key('config_import_confirm_button')));
      await tester.pumpAndSettle();
      expect(imported, true);
      expect(find.byType(ConfigImportPreviewDialog), findsNothing);
      final servers = storage.getServers();
      expect(servers.length, 1);
      expect(servers.single.id, isNot('srv-1'));
      expect(servers.single.host, 'bastion.internal.example.corp');
      expect(storage.getFileBookmarks(servers.single.id), [
        '/var/www/prod-edge-01',
      ]);
    });

    testWidgets('failed import keeps dialog with visible error', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final broken = ConfigurationBackup(
        servers: [
          const ServerProfile(
            id: 'srv-1',
            name: 'prod-edge-01',
            host: 'bastion.internal.example.corp',
            port: 2222,
            username: 'deploy',
            authType: AuthType.password,
          ),
        ],
        agents: [
          AgentProfile(
            id: 'agent-orphan',
            serverId: 'ghost-server',
            name: 'orphan agent',
            description: '',
            cliCommand: 'ops-agent',
          ),
        ],
        commands: const [],
        bookmarks: {},
        defaultAgents: {},
        preferences: {},
      );

      await tester.pumpWidget(
        _dialogHost(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          open: (context) async {
            await ConfigImportPreviewDialog.show(context, backup: broken);
          },
        ),
      );
      await openDialog(tester);

      await tester.tap(find.byKey(const Key('config_import_confirm_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('CONFIG_AGENT_INVALID'), findsOneWidget);
      expect(find.byType(ConfigImportPreviewDialog), findsOneWidget);
      expect(
        find.byKey(const Key('config_import_confirm_button')),
        findsOneWidget,
      );
      expect(storage.getServers(), isEmpty);
    });
  });

  group('file bookmarks dialog', () {
    testWidgets('concurrent toggle ignored, failure keeps dialog', (
      tester,
    ) async {
      setSurface(tester, const Size(1080, 2400), 3);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final notifier = _FakeBookmarksNotifier(['/var/www/alpha']);
      notifier.toggleGate = Completer<void>();
      final active = _FakeActiveServerNotifier(
        const ServerProfile(
          id: 'srv-1',
          name: 'alpha host',
          host: 'alpha.example',
          username: 'u',
        ),
      );
      await tester.pumpWidget(
        _dialogHost(
          overrides: [
            fileBookmarksProvider.overrideWith(() => notifier),
            activeServerProvider.overrideWith(() => active),
            localStorageServiceProvider.overrideWithValue(storage),
          ],
          open: (context) => FileBookmarksDialog.show(
            context,
            currentPath: '/var/www/very/current/directory/name',
            onSelectPath: (_) {},
          ),
        ),
      );
      await openDialog(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FileBookmarksDialog)),
      );
      expect(find.text(l10n.sftpCurrentDirectory), findsOneWidget);
      expect(find.text('/var/www/alpha'), findsOneWidget);

      await tester.tap(find.text(l10n.sftpAddBookmark));
      await tester.pump();
      expect(notifier.toggleCalls, ['/var/www/very/current/directory/name']);

      await tester.tap(find.text(l10n.sftpAddBookmark));
      await tester.pump();
      expect(notifier.toggleCalls.length, 1);

      notifier.toggleGate!.complete();
      await tester.pumpAndSettle();

      notifier.toggleError = StateError('BOOKMARK_BOOM');
      await tester.tap(find.text(l10n.sftpAddBookmark));
      await tester.pumpAndSettle();
      expect(notifier.toggleCalls.length, 2);
      expect(find.text('Bad state: BOOKMARK_BOOM'), findsOneWidget);
      expect(find.byType(FileBookmarksDialog), findsOneWidget);
    });

    testWidgets('stale server target closes dialog and blocks save', (
      tester,
    ) async {
      setSurface(tester, const Size(1080, 2400), 3);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final notifier = _FakeBookmarksNotifier(['/var/www/alpha']);
      final active = _FakeActiveServerNotifier(
        const ServerProfile(
          id: 'srv-1',
          name: 'alpha host',
          host: 'alpha.example',
          username: 'u',
        ),
      );
      final selected = <String>[];
      var currentPath = '/var/www/alpha';
      await tester.pumpWidget(
        _dialogHost(
          overrides: [
            fileBookmarksProvider.overrideWith(() => notifier),
            activeServerProvider.overrideWith(() => active),
            localStorageServiceProvider.overrideWithValue(storage),
          ],
          open: (context) => FileBookmarksDialog.show(
            context,
            currentPath: currentPath,
            onSelectPath: selected.add,
          ),
        ),
      );
      await openDialog(tester);

      active.switchTo(
        const ServerProfile(
          id: 'srv-2',
          name: 'beta host',
          host: 'beta.example',
          username: 'u',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FileBookmarksDialog), findsNothing);
      expect(notifier.toggleCalls, isEmpty);
      expect(selected, isEmpty);

      currentPath = '/var/www/beta';
      await openDialog(tester);
      expect(find.byType(FileBookmarksDialog), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FileBookmarksDialog)),
      );
      await tester.tap(find.text(l10n.sftpAddBookmark));
      await tester.pumpAndSettle();
      expect(notifier.toggleCalls, ['/var/www/beta']);
      expect(find.byType(FileBookmarksDialog), findsOneWidget);
    });
  });

  group('320dp 2x narrow previews', () {
    testWidgets('default agent dialog: long agent names, cancel works', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeAgentStorage(prefs, _longNameAgents());
      final server = _longNameServer();
      await tester.pumpWidget(
        _dialogHost(
          overrides: [
            activeServerProvider.overrideWith(
              () => _FakeActiveServerNotifier(server),
            ),
            localStorageServiceProvider.overrideWithValue(storage),
            agentRepositoryProvider.overrideWithValue(AgentRepository(storage)),
          ],
          textScale: 2.0,
          open: (context) =>
              DefaultAgentDialog.show(context, server: server, isCli: false),
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DefaultAgentDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settingsDefaultAgentAutomatic), findsOneWidget);
      expect(
        find.text(
          'claude-code-advanced-coder-agent-with-extremely-long-name-v1',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(server.name), findsOneWidget);
      expect(
        find.byKey(const Key('default_agent_agent-default-1')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('default_agent_agent-default-2')),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('codex-refactoring-specialist-agent-separate-very-long-name'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('default_agent_agent-default-2')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(DefaultAgentDialog), findsNothing);
    });

    testWidgets('clear credentials dialog: long servers render, cancel only', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      await tester.pumpWidget(
        _dialogHost(
          overrides: [
            serverListProvider.overrideWith(
              () => _FakeServerListNotifier(_longNameServers()),
            ),
          ],
          textScale: 2.0,
          open: ClearCredentialsDialog.show,
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ClearCredentialsDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settingsClearStorageDesc), findsOneWidget);
      expect(
        find.text('production-edge-bastion-cluster-node-01'),
        findsOneWidget,
      );
      expect(
        find.text('staging-readonly-replica-cluster-node-02'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'platform-engineering-deploy-user@bastion-prod-edge-cluster-node-01.internal.corp.example-region.test:22222',
        ),
        findsOneWidget,
      );
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text(l10n.settingsClearStorageSelectAll), findsOneWidget);
      expect(find.byKey(const Key('server_credential_srv-1')), findsOneWidget);
      expect(find.byKey(const Key('server_credential_srv-2')), findsOneWidget);

      await tester.ensureVisible(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(ClearCredentialsDialog), findsNothing);
    });

    testWidgets('export preview: full commands at 320dp 2x, cancel only', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      final backup = _backupWithSecretCommand();
      bool? confirmed;
      await tester.pumpWidget(
        _dialogHost(
          overrides: const [],
          textScale: 2.0,
          open: (context) async {
            confirmed = await ConfigExportPreviewDialog.show(
              context,
              backup: backup,
            );
          },
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConfigExportPreviewDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.configImportSecretWarning), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportServersCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportCommandsCount(1)),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.navCommands));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.navCommands));
      await tester.pumpAndSettle();
      expect(find.text('Rotate registry token'), findsOneWidget);
      expect(
        find.text('vault kv put secret/registry token=SUPERSECRET-TOKEN-VALUE'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.settingsAgentManagement));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsAgentManagement));
      await tester.pumpAndSettle();
      expect(find.textContaining('SUPERSECRET-LOGIN-TOKEN'), findsOneWidget);

      expect(
        find.byWidgetPredicate((widget) => widget is FilledButton),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(confirmed, false);
      expect(find.byType(ConfigExportPreviewDialog), findsNothing);
    });

    testWidgets('import preview: full commands at 320dp 2x, cancel only', (
      tester,
    ) async {
      setSurface(tester, const Size(960, 2400), 3);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final backup = _backupWithSecretCommand();
      bool? imported;
      await tester.pumpWidget(
        _dialogHost(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          textScale: 2.0,
          open: (context) async {
            imported = await ConfigImportPreviewDialog.show(
              context,
              backup: backup,
            );
          },
        ),
      );
      await openDialog(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConfigImportPreviewDialog)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.configImportSecretWarning), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportServersCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Chip),
          matching: find.text(l10n.configImportBookmarksCount(1)),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('config_import_global_prefs_checkbox')),
            )
            .value,
        false,
      );

      await tester.ensureVisible(
        find.byKey(const Key('config_import_commands_expansion')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('config_import_commands_expansion')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotate registry token'), findsOneWidget);
      expect(
        find.text('vault kv put secret/registry token=SUPERSECRET-TOKEN-VALUE'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(imported, false);
      expect(find.byType(ConfigImportPreviewDialog), findsNothing);
      expect(storage.getServers(), isEmpty);
    });
  });
}
