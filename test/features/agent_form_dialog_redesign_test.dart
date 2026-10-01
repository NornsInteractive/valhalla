import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/features/agents/agent_form_dialog.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _NoopExecutor implements SshCommandExecutor {
  @override
  SSHClient? getClient(String serverId) => null;
  @override
  bool isConnected(String serverId) => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDockerCliService extends DockerCliService {
  List<DockerContainer> containers = [];
  List<DockerContainerUser> containerUsers = [];
  bool shouldThrow = false;
  bool shouldThrowUsers = false;
  Future<List<DockerContainerUser>>? pendingUsers;
  int listContainersCalls = 0;
  int listContainerUsersCalls = 0;
  String? lastContainerReferenceQueried;

  _FakeDockerCliService() : super(_NoopExecutor());

  @override
  Future<List<DockerContainer>> listContainers(String serverId) async {
    listContainersCalls++;
    if (shouldThrow) {
      throw Exception('Docker daemon unavailable');
    }
    return containers;
  }

  @override
  Future<List<DockerContainerUser>> listContainerUsers(
    String serverId,
    String containerReference,
  ) async {
    listContainerUsersCalls++;
    lastContainerReferenceQueried = containerReference;
    final pending = pendingUsers;
    if (pending != null) {
      return pending;
    }
    if (shouldThrowUsers) {
      throw Exception('Failed to read /etc/passwd');
    }
    return containerUsers;
  }
}

class _FakeAgentRegistryNotifier extends AgentRegistryNotifier {
  final List<AgentProfile> addedAgents = [];
  final List<AgentProfile> updatedAgents = [];

  @override
  AgentRegistryState build() =>
      const AgentRegistryState(agents: [], isLoading: false);

  @override
  Future<void> addAgent(AgentProfile agent) async {
    addedAgents.add(agent);
  }

  @override
  Future<void> updateAgent(AgentProfile agent) async {
    updatedAgents.add(agent);
  }
}

Widget _buildTestApp({
  required Widget child,
  required _FakeAgentRegistryNotifier notifier,
  DockerCliService? dockerCliService,
  AgentProfile? initialProfile,
  Size size = const Size(1024, 768),
}) {
  return ProviderScope(
    overrides: [
      agentRegistryProvider.overrideWith(() => notifier),
      if (dockerCliService != null)
        dockerCliServiceProvider.overrideWithValue(dockerCliService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => AgentFormDialog(
                    serverId: 'srv-test',
                    initialProfile: initialProfile,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AgentFormDialog Redesign', () {
    testWidgets(
      'desktop view renders modal with 4 groups and monospace commands',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            size: const Size(1024, 768),
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Dialog is open and constrained
        expect(find.byType(AgentFormDialog), findsOneWidget);

        // Verify 4 section headers exist
        expect(
          find.byIcon(Icons.auto_awesome_outlined),
          findsOneWidget,
        ); // Preset
        expect(find.byIcon(Icons.badge_outlined), findsWidgets); // Basic info
        expect(
          find.byIcon(Icons.terminal_outlined),
          findsOneWidget,
        ); // Commands
        expect(
          find.byIcon(Icons.verified_user_outlined),
          findsOneWidget,
        ); // Auth/Install

        // Verify default preset Claude Code is selected
        final claudeChip = find.widgetWithText(ChoiceChip, 'Claude Code');
        expect(claudeChip, findsOneWidget);
        final chipWidget = tester.widget<ChoiceChip>(claudeChip);
        expect(chipWidget.selected, isTrue);

        // Verify Cancel and Save buttons exist
        expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Save & Detect'),
          findsOneWidget,
        );
      },
    );

    testWidgets('compact mobile view renders fullscreen dialog', (
      tester,
    ) async {
      final fakeNotifier = _FakeAgentRegistryNotifier();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildTestApp(
          child: const SizedBox.shrink(),
          notifier: fakeNotifier,
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Fullscreen scaffold on mobile
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AgentFormDialog), findsOneWidget);

      // Close fullscreen dialog via leading close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(AgentFormDialog), findsNothing);
    });

    testWidgets('switching presets populates and custom clears fields', (
      tester,
    ) async {
      final fakeNotifier = _FakeAgentRegistryNotifier();

      await tester.pumpWidget(
        _buildTestApp(child: const SizedBox.shrink(), notifier: fakeNotifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap OpenAI Codex preset
      await tester.tap(find.text('OpenAI Codex'));
      await tester.pumpAndSettle();

      expect(find.text('OpenAI Codex'), findsWidgets);

      // Tap Custom preset to clear
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Attempting to save with empty fields triggers validation error
      await tester.tap(find.widgetWithText(FilledButton, 'Save & Detect'));
      await tester.pumpAndSettle();

      // Form validation failed, addAgent was not called
      expect(fakeNotifier.addedAgents, isEmpty);
      expect(find.byType(AgentFormDialog), findsOneWidget);
    });

    testWidgets(
      'saving valid agent invokes notifier.addAgent and pops dialog',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();

        await tester.pumpWidget(
          _buildTestApp(child: const SizedBox.shrink(), notifier: fakeNotifier),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Claude Code preset is active by default with valid fields
        await tester.tap(find.widgetWithText(FilledButton, 'Save & Detect'));
        await tester.pumpAndSettle();

        // addAgent should have been called
        expect(fakeNotifier.addedAgents, hasLength(1));
        expect(fakeNotifier.addedAgents.first.serverId, 'srv-test');
        expect(fakeNotifier.addedAgents.first.name, contains('Claude'));

        // Dialog is closed
        expect(find.byType(AgentFormDialog), findsNothing);
      },
    );

    testWidgets(
      'edit mode prefills initialProfile, keeps original ID/serverId/createdAt, and invokes updateAgent on save',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final createdDate = DateTime(2025, 3, 15, 10, 0);
        final initial = AgentProfile(
          id: 'agent-custom-1',
          serverId: 'srv-test',
          name: 'My Custom Agent',
          description: 'Specialized DevOps Agent',
          cliCommand: 'devops-cli --run',
          acpCommand: 'devops-acp',
          createdAt: createdDate,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            initialProfile: initial,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Title should be Edit Agent
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.editAgent), findsOneWidget);

        // Fields are prefilled
        expect(find.text('My Custom Agent'), findsOneWidget);
        expect(find.text('devops-cli --run'), findsOneWidget);

        // Update name
        final nameField = find.widgetWithText(TextFormField, 'My Custom Agent');
        await tester.enterText(nameField, 'Renamed DevOps Agent');
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.widgetWithText(FilledButton, 'Save & Detect'));
        await tester.pumpAndSettle();

        // updateAgent was invoked, NOT addAgent
        expect(fakeNotifier.addedAgents, isEmpty);
        expect(fakeNotifier.updatedAgents, hasLength(1));

        final saved = fakeNotifier.updatedAgents.first;
        expect(saved.id, 'agent-custom-1');
        expect(saved.serverId, 'srv-test');
        expect(saved.createdAt, createdDate);
        expect(saved.name, 'Renamed DevOps Agent');
        expect(saved.cliCommand, 'devops-cli --run');
        expect(find.byType(AgentFormDialog), findsNothing);
      },
    );

    testWidgets(
      'execution target switching between host and docker, validation requires container reference when docker',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();

        await tester.pumpWidget(
          _buildTestApp(child: const SizedBox.shrink(), notifier: fakeNotifier),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Default is host
        final hostBtn = find.byKey(const Key('agent_target_host'));
        expect(hostBtn, findsOneWidget);

        // Switch to Docker
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        // Switch to binding by name
        final bindingNameBtn = find.byKey(const Key('agent_binding_name'));
        expect(bindingNameBtn, findsOneWidget);
        await tester.ensureVisible(bindingNameBtn);
        await tester.tap(bindingNameBtn);
        await tester.pumpAndSettle();

        // Attempting to save with empty container reference triggers validation
        await tester.tap(find.widgetWithText(FilledButton, 'Save & Detect'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.agentContainerRequired), findsOneWidget);
        expect(fakeNotifier.addedAgents, isEmpty);

        // Enter container reference
        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'nginx-prod');
        await tester.pumpAndSettle();

        // Now save succeeds
        await tester.tap(find.widgetWithText(FilledButton, 'Save & Detect'));
        await tester.pumpAndSettle();

        expect(fakeNotifier.addedAgents, hasLength(1));
        final added = fakeNotifier.addedAgents.first;
        expect(added.executionTarget, 'docker');
        expect(added.containerBinding, 'name');
        expect(added.containerReference, 'nginx-prod');
      },
    );

    testWidgets(
      'docker execution queries containers list, renders dropdown, and handles error with retry',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.containers = [
          const DockerContainer(
            id: 'c-web-1234567890ab',
            name: 'web-nginx',
            image: 'nginx:alpine',
            status: 'Up 2 hours',
            state: DockerContainerState.running,
            ports: '80:80',
          ),
        ];

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Docker target
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        // listContainers was called
        expect(fakeDocker.listContainersCalls, 1);

        // Dropdown is present with container options
        final dropdown = find.byKey(const Key('agent_container_dropdown'));
        expect(dropdown, findsOneWidget);
        await tester.ensureVisible(dropdown);

        // Open dropdown and select container
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        expect(find.textContaining('web-nginx'), findsWidgets);
        await tester.tap(find.textContaining('web-nginx').last);
        await tester.pumpAndSettle();

        // container reference text field is populated with container name
        final refField = tester.widget<TextFormField>(
          find.byKey(const Key('agent_container_reference_field')),
        );
        expect(refField.controller?.text, 'web-nginx');

        // Test error handling
        fakeDocker.shouldThrow = true;
        final refreshBtn = find.byKey(
          const Key('agent_containers_refresh_button'),
        );
        await tester.ensureVisible(refreshBtn);
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Docker daemon unavailable'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'docker execution containerUser field pre-fills on edit, saves non-empty string, and clearing it saves null',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final now = DateTime.now();
        final initialProfile = AgentProfile(
          id: 'custom-docker-agent',
          serverId: 'srv-test',
          name: 'Dockerized Agent',
          description: 'Runs inside container',
          cliCommand: 'codex',
          executionTarget: 'docker',
          containerBinding: 'name',
          containerReference: 'codex-box',
          containerUser: '1000:1000',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            initialProfile: initialProfile,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Check container user field is visible and prefilled
        final userFieldFinder = find.byKey(
          const Key('agent_container_user_field'),
        );
        expect(userFieldFinder, findsOneWidget);
        await tester.ensureVisible(userFieldFinder);

        final userField = tester.widget<TextFormField>(userFieldFinder);
        expect(userField.controller?.text, '1000:1000');

        // Check helper text is present
        expect(
          find.textContaining('Leave empty to use image default user'),
          findsOneWidget,
        );

        // Clear field to test saving null
        await tester.enterText(userFieldFinder, '   ');
        await tester.pumpAndSettle();

        // Save
        final saveBtn = find.widgetWithText(FilledButton, 'Save & Detect');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(fakeNotifier.updatedAgents, hasLength(1));
        expect(fakeNotifier.updatedAgents.first.containerUser, isNull);
      },
    );

    testWidgets(
      'docker execution containerUser input on creation saves non-empty string when provided and null when blank',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();

        await tester.pumpWidget(
          _buildTestApp(child: const SizedBox.shrink(), notifier: fakeNotifier),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Docker target
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'custom-container');

        final userField = find.byKey(const Key('agent_container_user_field'));
        await tester.ensureVisible(userField);
        await tester.enterText(userField, 'dev');

        final saveBtn = find.widgetWithText(FilledButton, 'Save & Detect');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(fakeNotifier.addedAgents, hasLength(1));
        expect(fakeNotifier.addedAgents.first.executionTarget, 'docker');
        expect(fakeNotifier.addedAgents.first.containerUser, 'dev');
      },
    );

    testWidgets(
      'Docker composite user row queries users when valid containerReference exists, displays in dropdown, selecting populates manual field, and manual edit clears selection',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.containerUsers = const [
          DockerContainerUser(name: 'root', uid: 0, gid: 0),
          DockerContainerUser(name: 'dev', uid: 1000, gid: 1000),
          DockerContainerUser(name: 'app', uid: 1001, gid: 1001),
        ];

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Docker target
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        // Before containerReference is set, listContainerUsers is not called
        expect(fakeDocker.listContainerUsersCalls, 0);

        // Enter container reference
        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'custom-box');
        await tester.pumpAndSettle();

        expect(fakeDocker.listContainerUsersCalls, 1);
        expect(fakeDocker.lastContainerReferenceQueried, 'custom-box');

        // Dropdown is present
        final userDropdown = find.byKey(
          const Key('agent_container_user_dropdown'),
        );
        expect(userDropdown, findsOneWidget);
        await tester.ensureVisible(userDropdown);

        // Open dropdown
        await tester.tap(userDropdown);
        await tester.pumpAndSettle();

        // Verify users format: name · UID x · GID y
        expect(find.textContaining('root · UID 0 · GID 0'), findsWidgets);
        expect(find.textContaining('dev · UID 1000 · GID 1000'), findsWidgets);
        expect(find.textContaining('app · UID 1001 · GID 1001'), findsWidgets);

        // Select 'dev'
        await tester.tap(find.textContaining('dev · UID 1000 · GID 1000').last);
        await tester.pumpAndSettle();

        // Manual text field is auto-populated with 'dev'
        final manualField = tester.widget<TextFormField>(
          find.byKey(const Key('agent_container_user_field')),
        );
        expect(manualField.controller?.text, 'dev');

        // Verify dropdown shows selected value 'dev'
        final dropdownWidget = tester.widget<DropdownButton<String>>(
          userDropdown,
        );
        expect(dropdownWidget.value, 'dev');

        // Manually editing the right field clears dropdown selection
        final manualFieldFinder = find.byKey(
          const Key('agent_container_user_field'),
        );
        await tester.enterText(manualFieldFinder, 'dev:mygroup');
        await tester.pumpAndSettle();

        final updatedDropdown = tester.widget<DropdownButton<String>>(
          userDropdown,
        );
        expect(updatedDropdown.value, isNull);
        expect(manualField.controller?.text, 'dev:mygroup');
      },
    );

    testWidgets(
      'switching container reference or binding resets users and automatically re-queries, manual refresh button is removed',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.containers = [
          const DockerContainer(
            id: 'c-web-111111111111',
            name: 'web-prod',
            image: 'nginx',
            status: 'Up',
            state: DockerContainerState.running,
            ports: '',
          ),
          const DockerContainer(
            id: 'c-db-222222222222',
            name: 'db-prod',
            image: 'postgres',
            status: 'Up',
            state: DockerContainerState.running,
            ports: '',
          ),
        ];
        fakeDocker.containerUsers = const [
          DockerContainerUser(name: 'postgres', uid: 999, gid: 999),
        ];

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Docker target
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        // Manual refresh button is removed entirely
        expect(
          find.byKey(const Key('agent_container_users_refresh_button')),
          findsNothing,
        );

        // Select container from dropdown
        final containerDropdown = find.byKey(
          const Key('agent_container_dropdown'),
        );
        await tester.ensureVisible(containerDropdown);
        await tester.tap(containerDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('web-prod').last);
        await tester.pumpAndSettle();

        expect(fakeDocker.listContainerUsersCalls, 1);
        expect(fakeDocker.lastContainerReferenceQueried, 'web-prod');

        // Switch binding to 'id'
        final bindingIdBtn = find.byKey(const Key('agent_binding_id'));
        await tester.ensureVisible(bindingIdBtn);
        await tester.tap(bindingIdBtn);
        await tester.pumpAndSettle();

        expect(fakeDocker.listContainerUsersCalls, 2);
        expect(fakeDocker.lastContainerReferenceQueried, 'c-web-111111111111');

        // Switch binding back to 'name'
        final bindingNameBtn = find.byKey(const Key('agent_binding_name'));
        await tester.ensureVisible(bindingNameBtn);
        await tester.tap(bindingNameBtn);
        await tester.pumpAndSettle();

        expect(fakeDocker.listContainerUsersCalls, 3);
        expect(fakeDocker.lastContainerReferenceQueried, 'web-prod');
      },
    );

    testWidgets(
      'automatically refreshes container user list on initial load for existing docker profile with valid reference',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.containerUsers = const [
          DockerContainerUser(name: 'service', uid: 1002, gid: 1002),
        ];
        final now = DateTime.now();
        final initialProfile = AgentProfile(
          id: 'existing-docker-agent',
          serverId: 'srv-test',
          name: 'Existing Docker Agent',
          description: 'Docker agent',
          cliCommand: 'codex',
          executionTarget: 'docker',
          containerBinding: 'name',
          containerReference: 'service-box',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
            initialProfile: initialProfile,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // On initial load with valid existing reference, user list is fetched automatically
        expect(fakeDocker.listContainerUsersCalls, 1);
        expect(fakeDocker.lastContainerReferenceQueried, 'service-box');

        final userDropdown = find.byKey(
          const Key('agent_container_user_dropdown'),
        );
        expect(userDropdown, findsOneWidget);
      },
    );

    testWidgets(
      'debounces manually typed container reference around 350ms, avoids empty values',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);

        // Type rapidly
        await tester.enterText(refField, 'app-1');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(refField, 'app-12');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(refField, 'app-123');

        // Before 350ms elapses, no fetch has occurred
        await tester.pump(const Duration(milliseconds: 200));
        expect(fakeDocker.listContainerUsersCalls, 0);

        // After 350ms elapses, fetch is triggered once with latest reference
        await tester.pump(const Duration(milliseconds: 200));
        expect(fakeDocker.listContainerUsersCalls, 1);
        expect(fakeDocker.lastContainerReferenceQueried, 'app-123');

        // Clearing reference to empty avoids querying
        await tester.enterText(refField, '');
        await tester.pump(const Duration(milliseconds: 500));
        expect(fakeDocker.listContainerUsersCalls, 1); // No new call made
      },
    );

    testWidgets(
      'container user selector is responsive: wide layout uses balanced Row, narrow layout stacks full-width Column',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();

        // 1. Test Wide Viewport (1024 width)
        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
            size: const Size(1024, 768),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('agent_container_user_layout_wide')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('agent_container_user_layout_narrow')),
          findsNothing,
        );

        // Close dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 2. Test Narrow Viewport (360 width)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
            size: const Size(360, 640),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dockerBtnNarrow = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtnNarrow);
        await tester.tap(dockerBtnNarrow);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('agent_container_user_layout_narrow')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('agent_container_user_layout_wide')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when container user fetch fails or is empty, manual input remains fully functional and authoritative on save',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.shouldThrowUsers = true;

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Docker target
        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'failing-box');
        await tester.pumpAndSettle();

        // Error occurred in user fetch, but manual input is still usable
        final manualFieldFinder = find.byKey(
          const Key('agent_container_user_field'),
        );
        await tester.ensureVisible(manualFieldFinder);
        await tester.enterText(manualFieldFinder, 'custom-fallback-user');
        await tester.pumpAndSettle();

        final saveBtn = find.widgetWithText(FilledButton, 'Save & Detect');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(fakeNotifier.addedAgents, hasLength(1));
        expect(
          fakeNotifier.addedAgents.first.containerUser,
          'custom-fallback-user',
        );
      },
    );

    testWidgets(
      'binding toggle keeps empty and unknown references, converts unique short hex id to its container name',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        fakeDocker.containers = [
          const DockerContainer(
            id: '0a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef',
            name: 'alpha-box',
            image: 'nginx',
            status: 'Up',
            state: DockerContainerState.running,
            ports: '',
          ),
          const DockerContainer(
            id: 'ff00112233445566778899aabbccddeeff00112233445566778899aabbccdd',
            name: 'beta-box',
            image: 'postgres',
            status: 'Up',
            state: DockerContainerState.running,
            ports: '',
          ),
        ];

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        expect(fakeDocker.listContainersCalls, 1);

        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        final bindingId = find.byKey(const Key('agent_binding_id'));
        final bindingName = find.byKey(const Key('agent_binding_name'));
        String refText() =>
            tester.widget<TextFormField>(refField).controller?.text ?? '';

        // Empty reference stays empty in both directions
        await tester.ensureVisible(bindingId);
        await tester.tap(bindingId);
        await tester.pumpAndSettle();
        expect(refText(), '');

        await tester.ensureVisible(bindingName);
        await tester.tap(bindingName);
        await tester.pumpAndSettle();
        expect(refText(), '');

        // Unknown reference is left untouched
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'missing-box');
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(bindingId);
        await tester.tap(bindingId);
        await tester.pumpAndSettle();
        expect(refText(), 'missing-box');

        // Unique short hex id resolves to the second container's name
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'ff0011');
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(bindingName);
        await tester.tap(bindingName);
        await tester.pumpAndSettle();

        expect(refText(), 'beta-box');
        expect(refText(), isNot('alpha-box'));
      },
    );

    testWidgets(
      'stale container user query resolving after reference is cleared leaves dropdown empty, disabled, and error-free',
      (tester) async {
        final fakeNotifier = _FakeAgentRegistryNotifier();
        final fakeDocker = _FakeDockerCliService();
        final pendingQuery = Completer<List<DockerContainerUser>>();
        fakeDocker.pendingUsers = pendingQuery.future;

        await tester.pumpWidget(
          _buildTestApp(
            child: const SizedBox.shrink(),
            notifier: fakeNotifier,
            dockerCliService: fakeDocker,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dockerBtn = find.byKey(const Key('agent_target_docker'));
        await tester.ensureVisible(dockerBtn);
        await tester.tap(dockerBtn);
        await tester.pumpAndSettle();

        final refField = find.byKey(
          const Key('agent_container_reference_field'),
        );
        await tester.ensureVisible(refField);
        await tester.enterText(refField, 'stale-box');

        // Debounce elapses, user query starts and stays pending
        await tester.pump(const Duration(milliseconds: 400));
        expect(fakeDocker.listContainerUsersCalls, 1);

        final userDropdown = find.byKey(
          const Key('agent_container_user_dropdown'),
        );
        expect(userDropdown, findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.widget<DropdownButton<String>>(userDropdown).onChanged,
          isNull,
        );

        // Clear the reference while loading (pump, never pumpAndSettle here)
        await tester.enterText(refField, '');
        await tester.pump();
        expect(fakeDocker.listContainerUsersCalls, 1);

        // Old future resolves after invalidation
        pendingQuery.complete(const [
          DockerContainerUser(name: 'ghost', uid: 4242, gid: 4242),
        ]);
        await tester.pumpAndSettle();

        final dropdown = tester.widget<DropdownButton<String>>(userDropdown);
        expect(dropdown.items ?? const <DropdownMenuItem<String>>[], isEmpty);
        expect(dropdown.onChanged, isNull);
        expect(find.textContaining('ghost'), findsNothing);
        expect(
          find.textContaining('Failed to load container users'),
          findsNothing,
        );
        expect(find.byIcon(Icons.error_outline), findsNothing);
        expect(fakeDocker.listContainerUsersCalls, 1);
      },
    );
  });
}
