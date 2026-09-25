import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/state_views.dart';

class _FakeCliChatNotifier extends CliChatNotifier {
  CliChatState _state;
  _FakeCliChatNotifier(this._state);

  String? lastSelectedAgentId;
  String? lastSentMessage;
  bool stopped = false;
  String? approvedId;
  bool? approvedAllow;
  String? deletedSessionId;
  bool? deleteConfirmed;
  bool? installedSdkConfirmed;
  bool openedTerminal = false;
  bool closedTerminal = false;
  bool? lastLoadMore;
  String? lastCwd;
  bool drafted = false;
  String? lastDraftCwd;

  @override
  void setDraftWorkingDirectory(String? path) {
    lastDraftCwd = path;
    state = state.copyWith(draftCwd: path, clearDraftCwd: path == null);
  }

  @override
  CliChatState build() => _state;

  void updateState(CliChatState newState) {
    _state = newState;
    state = newState;
  }

  @override
  Future<void> selectAgent(String id) async {
    lastSelectedAgentId = id;
    final agent = state.agents.where((a) => a.id == id).firstOrNull;
    state = CliChatState(
      serverId: state.serverId,
      agents: state.agents,
      activeAgent: agent,
      sessions: state.sessions,
      activeSession: null,
      messages: [],
      approvals: [],
    );
  }

  String? lastSelectedSessionId;

  @override
  Future<void> selectSession(String id) async {
    lastSelectedSessionId = id;
    final session = state.sessions.where((s) => s.id == id).firstOrNull;
    state = state.copyWith(activeSession: session);
  }

  @override
  Future<void> refreshSessions({bool loadMore = false, String? cwd}) async {
    lastLoadMore = loadMore;
    lastCwd = cwd;
    state = state.copyWith(cwd: cwd);
  }

  @override
  void createDraft() {
    drafted = true;
    state = state.copyWith(clearSession: true, messages: [], approvals: []);
  }

  bool throwOnSend = false;
  String? failErrorCodeOnSend;

  @override
  Future<void> sendMessage(String text) async {
    lastSentMessage = text;
    if (throwOnSend) {
      throw Exception('Network error');
    }
    if (failErrorCodeOnSend != null) {
      state = state.copyWith(errorCode: failErrorCodeOnSend, isSending: false);
    }
  }

  @override
  Future<void> respondApproval(String id, bool allow) async {
    approvedId = id;
    approvedAllow = allow;
    state = state.copyWith(
      approvals: state.approvals.where((a) => a.id != id).toList(),
    );
  }

  @override
  Future<void> stop() async {
    stopped = true;
    state = state.copyWith(isSending: false);
  }

  String? failErrorCodeOnDelete;
  String? failErrorDetailOnDelete;

  @override
  Future<void> deleteSession(String id, {required bool confirmed}) async {
    deletedSessionId = id;
    deleteConfirmed = confirmed;
    if (failErrorCodeOnDelete != null) {
      state = state.copyWith(
        errorCode: failErrorCodeOnDelete,
        errorDetail: failErrorDetailOnDelete,
      );
    }
  }

  @override
  Future<void> installHistorySdk({required bool confirmed}) async {
    installedSdkConfirmed = confirmed;
  }

  @override
  Future<void> openTerminal() async {
    openedTerminal = true;
    state = state.copyWith(terminal: Terminal());
  }

  int loadOlderMessagesCalls = 0;

  @override
  Future<void> loadOlderMessages() async {
    loadOlderMessagesCalls++;
  }

  @override
  void closeTerminal() {
    closedTerminal = true;
    state = state.copyWith(clearTerminal: true);
  }
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  final bool _connected;
  _TestServerConnectionNotifier({bool connected = true})
    : _connected = connected;

  @override
  ServerConnectionState build() {
    return ServerConnectionState(
      status: _connected
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
    );
  }
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  ServerProfile? _server;
  _TestActiveServerNotifier([this._server]);

  @override
  ServerProfile? build() => _server;

  void selectServerId(String? id) {
    _server = id == null
        ? null
        : ServerProfile(
            id: id,
            name: 'Server $id',
            host: '10.0.0.1',
            port: 22,
            username: 'root',
          );
    state = _server;
  }
}

class _TestAgentRegistryNotifier extends AgentRegistryNotifier {
  final List<AgentRuntimeState> _runtimeAgents;
  _TestAgentRegistryNotifier([this._runtimeAgents = const []]);

  @override
  AgentRegistryState build() {
    return AgentRegistryState(agents: _runtimeAgents, isLoading: false);
  }
}

const _server = ServerProfile(
  id: 'srv-1',
  name: 'Production Cloud',
  host: '192.168.1.100',
  port: 22,
  username: 'admin',
);

final _agentCodex = AgentProfile(
  id: 'agent-codex',
  serverId: 'srv-1',
  name: 'Codex CLI',
  description: 'Codex Agent description',
  cliCommand: 'codex',
);

final _agentClaude = AgentProfile(
  id: 'agent-claude',
  serverId: 'srv-1',
  name: 'Claude Code',
  description: 'Claude Code description',
  cliCommand: 'claude',
);

final _agentAgy = AgentProfile(
  id: 'agent-agy',
  serverId: 'srv-1',
  name: 'Antigravity CLI',
  description: 'Antigravity CLI description',
  cliCommand: 'agy',
);

final _agentOpenCode = AgentProfile(
  id: 'agent-opencode',
  serverId: 'srv-1',
  name: 'OpenCode CLI',
  description: 'OpenCode Agent description',
  cliCommand: 'opencode',
);

class _FakeSftpOps implements SftpOperations {
  List<SftpFileItem> returnFiles = const [];
  String? lastListedPath;
  bool shouldThrow = false;

  @override
  Future<List<SftpFileItem>> listFiles(String path) async {
    lastListedPath = path;
    if (shouldThrow) throw Exception('Permission denied: $path');
    return returnFiles;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required _FakeCliChatNotifier cliNotifier,
  bool isConnected = true,
  List<AgentRuntimeState> runtimeAgents = const [],
  SftpOperations? sftpOps,
  _TestActiveServerNotifier? activeServerNotifier,
  Size size = const Size(1000, 800),
  bool settle = true,
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(
          () => activeServerNotifier ?? _TestActiveServerNotifier(_server),
        ),
        serverConnectionProvider.overrideWith(
          () => _TestServerConnectionNotifier(connected: isConnected),
        ),
        agentRegistryProvider.overrideWith(
          () => _TestAgentRegistryNotifier(runtimeAgents),
        ),
        cliChatProvider.overrideWith(() => cliNotifier),
        if (sftpOps != null) sftpOperationsProvider.overrideWithValue(sftpOps),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CliChatView(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('CliChatView Tests', () {
    testWidgets('shows offline view when disconnected', (tester) async {
      final cliNotifier = _FakeCliChatNotifier(const CliChatState());

      await _pumpTestApp(tester, cliNotifier: cliNotifier, isConnected: false);

      expect(find.byType(OfflineStateView), findsOneWidget);
    });

    testWidgets('shows no agents configured when agents list is empty', (
      tester,
    ) async {
      final cliNotifier = _FakeCliChatNotifier(
        const CliChatState(serverId: 'srv-1', agents: []),
      );

      await _pumpTestApp(tester, cliNotifier: cliNotifier);

      expect(find.text('No agents added for this server'), findsOneWidget);
      expect(find.text('Configure in Agent Management'), findsOneWidget);
    });

    testWidgets(
      'dropdown displays current server agents and shows missing environment guide without silent install',
      (tester) async {
        final runtimeAgents = [
          AgentRuntimeState(
            profile: _agentCodex,
            status: AgentEnvironmentStatus(
              kind: AgentEnvironmentStatusKind.cliMissing,
              detail: 'CLI not installed',
              checkedAt: DateTime.now(),
            ),
          ),
        ];

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex, _agentClaude],
            activeAgent: _agentCodex,
          ),
        );

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          runtimeAgents: runtimeAgents,
        );

        // Dropdown finds active agent
        expect(find.byKey(const Key('cli_agent_dropdown')), findsOneWidget);

        // Guide banner for cliMissing
        expect(
          find.text('Agent environment missing or not logged in'),
          findsOneWidget,
        );
        expect(find.text('Configure in Agent Management'), findsOneWidget);
      },
    );

    testWidgets(
      'acpMissing does not trigger agent environment guide banner for native CLI',
      (tester) async {
        final runtimeAgents = [
          AgentRuntimeState(
            profile: _agentCodex,
            status: AgentEnvironmentStatus(
              kind: AgentEnvironmentStatusKind.acpMissing,
              detail: 'ACP adapter not installed',
              checkedAt: DateTime.now(),
            ),
          ),
        ];

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
          ),
        );

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          runtimeAgents: runtimeAgents,
        );

        // Guide banner must NOT be shown for acpMissing
        expect(
          find.text('Agent environment missing or not logged in'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Mode A (Codex/OpenCode): structuredSend allows input, stop, and native approvals with full details',
      (tester) async {
        const approval = NativeCliApproval(
          id: 'item-1:0',
          method: 'item/commandExecution/requestApproval',
          details: {
            'command': 'npm run test',
            'reason': 'Run verification suite',
          },
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            approvals: const [approval],
            messages: const [
              NativeCliMessage(
                id: 'm1',
                role: 'assistant',
                text: 'Waiting for approval',
              ),
            ],
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        // Check approvals section and details
        expect(find.text('Pending Approvals'), findsOneWidget);
        expect(
          find.text('item/commandExecution/requestApproval'),
          findsOneWidget,
        );
        expect(find.textContaining('npm run test'), findsOneWidget);
        expect(find.textContaining('Run verification suite'), findsOneWidget);

        // Test approval Allow button
        final allowBtn = find.byKey(const Key('cli_approval_allow_item-1:0'));
        expect(allowBtn, findsOneWidget);
        await tester.tap(allowBtn);
        await tester.pump();

        expect(cliNotifier.approvedId, 'item-1:0');
        expect(cliNotifier.approvedAllow, true);

        // Test sending message
        final inputFinder = find.byKey(const Key('cli_chat_input_field'));
        expect(inputFinder, findsOneWidget);
        await tester.enterText(inputFinder, 'List directory contents');
        await tester.tap(find.byKey(const Key('cli_send_button')));
        await tester.pump();

        expect(cliNotifier.lastSentMessage, 'List directory contents');

        // Test stop button when sending
        cliNotifier.updateState(cliNotifier.state.copyWith(isSending: true));
        await tester.pump();

        final stopBtn = find.byKey(const Key('cli_stop_button'));
        expect(stopBtn, findsOneWidget);
        await tester.tap(stopBtn);
        await tester.pump();

        expect(cliNotifier.stopped, true);
      },
    );

    testWidgets(
      'Mode B (Claude): read-only history, continue in terminal button, and missing SDK prompt',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentClaude],
            activeAgent: _agentClaude,
            errorCode: 'CLI_HISTORY_SDK_MISSING',
            messages: const [
              NativeCliMessage(
                id: 'cm1',
                role: 'assistant',
                text: 'Historical session text',
              ),
            ],
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        // Claude read-only notice banner
        expect(
          find.text(
            'Claude history is read-only. Continue the conversation in real terminal.',
          ),
          findsOneWidget,
        );
        expect(find.text('Historical session text'), findsOneWidget);
        expect(find.byKey(const Key('cli_chat_input_field')), findsNothing);

        // Missing SDK prompt and confirmation dialog
        final installSdkBtn = find.byKey(const Key('cli_install_sdk_button'));
        expect(installSdkBtn, findsOneWidget);
        await tester.tap(installSdkBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Install Official Claude History SDK'),
          findsOneWidget,
        );
        final confirmInstallBtn = find.byKey(
          const Key('cli_confirm_install_sdk_button'),
        );
        expect(confirmInstallBtn, findsOneWidget);
        await tester.tap(confirmInstallBtn);
        await tester.pump();

        expect(cliNotifier.installedSdkConfirmed, true);

        // Continue in terminal button
        final continueTerminalBtn = find.byKey(
          const Key('cli_continue_in_terminal_button'),
        );
        expect(continueTerminalBtn, findsOneWidget);
        await tester.tap(continueTerminalBtn);
        await tester.pump();
        expect(cliNotifier.openedTerminal, true);
      },
    );

    testWidgets(
      'Mode C (agy/custom): hasHistory=false shows only terminal open button without claiming history',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentAgy],
            activeAgent: _agentAgy,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        expect(
          find.text(
            'This agent does not support structured history synchronization. Please use the native CLI terminal for interaction and session selection.',
          ),
          findsOneWidget,
        );

        final openTerminalBtn = find.byKey(
          const Key('cli_open_terminal_button'),
        );
        expect(openTerminalBtn, findsOneWidget);
        await tester.tap(openTerminalBtn);
        await tester.pump();

        expect(cliNotifier.openedTerminal, true);
      },
    );

    testWidgets(
      'Terminal active renders xterm TerminalView and allows closing',
      (tester) async {
        final terminal = Terminal();
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            terminal: terminal,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        expect(find.byType(TerminalView), findsOneWidget);
        expect(find.text('Interactive CLI Terminal'), findsOneWidget);

        final closeBtn = find.byKey(const Key('cli_close_terminal_button'));
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pump();

        expect(cliNotifier.closedTerminal, true);
      },
    );

    testWidgets(
      'Session management: draft creation, CWD filter, pagination cursor, and explicit deletion confirmation',
      (tester) async {
        const session1 = NativeCliSession(
          id: 'sess-1',
          title: 'Refactor database migration',
          cwd: '/var/www/app',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: const [session1],
            canDelete: true,
            cursor: 'cursor-token-page-2',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        // 1. New draft button
        final draftBtn = find.byKey(const Key('cli_new_draft_button'));
        expect(draftBtn, findsOneWidget);
        await tester.tap(draftBtn);
        expect(cliNotifier.drafted, true);

        // 2. CWD Filter field
        final cwdField = find.byKey(const Key('cli_cwd_filter_field'));
        expect(cwdField, findsOneWidget);
        await tester.enterText(cwdField, '/var/www');
        await tester.tap(find.byKey(const Key('cli_apply_cwd_button')));
        expect(cliNotifier.lastCwd, '/var/www');

        // Clear CWD button
        await tester.tap(find.byKey(const Key('cli_clear_cwd_button')));
        expect(cliNotifier.lastCwd, '');

        // 3. Load more button with cursor
        final loadMoreBtn = find.byKey(const Key('cli_load_more_button'));
        expect(loadMoreBtn, findsOneWidget);
        await tester.tap(loadMoreBtn);
        expect(cliNotifier.lastLoadMore, true);

        // 4. Delete session confirmation
        final deleteBtn = find.byKey(const Key('cli_delete_session_sess-1'));
        expect(deleteBtn, findsOneWidget);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog must display "Delete Remote CLI Session History"
        expect(find.text('Delete Remote CLI Session History'), findsOneWidget);
        final confirmDeleteBtn = find.byKey(
          const Key('cli_confirm_delete_button'),
        );
        expect(confirmDeleteBtn, findsOneWidget);
        await tester.tap(confirmDeleteBtn);
        await tester.pump();

        expect(cliNotifier.deletedSessionId, 'sess-1');
        expect(cliNotifier.deleteConfirmed, true);
      },
    );

    testWidgets('canDelete=false disables the delete button', (tester) async {
      const session1 = NativeCliSession(id: 'sess-1', title: 'Task session');

      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [_agentCodex],
          activeAgent: _agentCodex,
          sessions: const [session1],
          canDelete: false, // Deletion disabled
        ),
      );

      await _pumpTestApp(tester, cliNotifier: cliNotifier);

      final deleteBtn = tester.widget<IconButton>(
        find.byKey(const Key('cli_delete_session_sess-1')),
      );
      expect(deleteBtn.onPressed, isNull);
    });

    testWidgets('localizes CLI error code and displays SnackBar', (
      tester,
    ) async {
      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [_agentCodex],
          activeAgent: _agentCodex,
          errorCode: 'CLI_BUSY',
        ),
      );

      await _pumpTestApp(tester, cliNotifier: cliNotifier);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Operation is in progress, please wait...'),
        findsOneWidget,
      );
    });

    testWidgets(
      'CLI_LOGIN_REQUIRED shows localized SnackBar and action button navigates to AgentManagementView',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_LOGIN_REQUIRED',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Agent login required. Please log in via Agent Management.',
          ),
          findsOneWidget,
        );

        final action = find.widgetWithText(SnackBarAction, 'Manage Agents');
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(AgentManagementView), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_NOT_INSTALLED shows localized SnackBar and action button navigates to AgentManagementView',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_NOT_INSTALLED',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Agent CLI not installed. Please install it via Agent Management.',
          ),
          findsOneWidget,
        );

        final action = find.widgetWithText(SnackBarAction, 'Manage Agents');
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(AgentManagementView), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_VERSION_UNSUPPORTED shows localized SnackBar and action button navigates to AgentManagementView',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_VERSION_UNSUPPORTED',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Agent CLI version is unsupported. Please upgrade or reinstall via Agent Management.',
          ),
          findsOneWidget,
        );

        final action = find.widgetWithText(SnackBarAction, 'Manage Agents');
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(AgentManagementView), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_HISTORY_RUNTIME_MISSING shows localized SnackBar informing user to install Node.js manually',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentClaude],
            activeAgent: _agentClaude,
            errorCode: 'CLI_HISTORY_RUNTIME_MISSING',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Claude history requires Node.js/npm on the server. Please install Node.js manually; you can still use the real CLI in terminal.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CLI_DELETE_FAILED shows base localized SnackBar when errorDetail is null or whitespace',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_DELETE_FAILED',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Failed to delete remote session'), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_DELETE_FAILED with errorDetail shows localized SnackBar including sanitized error detail',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_DELETE_FAILED',
            errorDetail: 'permission denied: session locked',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Failed to delete remote session: permission denied: session locked',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED shows base localized SnackBar when errorDetail is null or whitespace',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('CLI operation failed'), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED in zh locale shows base localized SnackBar',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
            errorDetail: '   ',
          ),
        );

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          locale: const Locale('zh'),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('CLI 操作执行失败'), findsOneWidget);
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED with errorDetail shows localized SnackBar including sanitized error detail',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
            errorDetail: 'process exited with code 127',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('CLI operation failed: process exited with code 127'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED with errorDetail in zh locale shows localized SnackBar',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
            errorDetail: '连接被重置 (connection reset)',
          ),
        );

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          locale: const Locale('zh'),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('CLI 操作执行失败：连接被重置 (connection reset)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED with sensitive errorDetail sanitizes secrets in SnackBar',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
            errorDetail:
                'Auth failed with password: superSecretPassword123 and token=my-secret-token',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('superSecretPassword123'), findsNothing);
        expect(find.textContaining('my-secret-token'), findsNothing);
        expect(
          find.text(
            'CLI operation failed: Auth failed with password=****** and token=******',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CLI_OPERATION_FAILED SnackBar text is constrained for readability and does not overflow',
      (tester) async {
        final massiveMultilineDetail = List.generate(
          50,
          (i) =>
              'Line $i: unexpected fatal traceback at /var/log/cli-runner.log',
        ).join('\n');

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_OPERATION_FAILED',
            errorDetail: massiveMultilineDetail,
          ),
        );

        // Test on compact screen
        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          size: const Size(360, 640),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);

        // Verify the Text widget inside SnackBar has maxLines: 4 and overflow: TextOverflow.ellipsis
        final snackBarFinder = find.byType(SnackBar);
        final textFinder = find.descendant(
          of: snackBarFinder,
          matching: find.byType(Text),
        );
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.maxLines, 4);
        expect(textWidget.overflow, TextOverflow.ellipsis);

        // Pumping and settling completes without RenderFlex overflow or exceptions
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'non-CLI_DELETE_FAILED error does not include errorDetail in SnackBar',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            errorCode: 'CLI_BUSY',
            errorDetail: 'internal backend queue detail',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Operation is in progress, please wait...'),
          findsOneWidget,
        );
        expect(
          find.textContaining('internal backend queue detail'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'deleteSession failure in UI displays localized SnackBar with error detail',
      (tester) async {
        const session1 = NativeCliSession(id: 'sess-1', title: 'Task session');
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: const [session1],
            canDelete: true,
          ),
        );
        cliNotifier.failErrorCodeOnDelete = 'CLI_DELETE_FAILED';
        cliNotifier.failErrorDetailOnDelete =
            'thread sess-1 is locked by process';

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        final deleteBtn = find.byKey(const Key('cli_delete_session_sess-1'));
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        final confirmDeleteBtn = find.byKey(
          const Key('cli_confirm_delete_button'),
        );
        await tester.tap(confirmDeleteBtn);
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Failed to delete remote session: thread sess-1 is locked by process',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '_handleSend restores prompt text if sending throws an exception',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
          ),
        );
        cliNotifier.throwOnSend = true;

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          runtimeAgents: [
            AgentRuntimeState(
              profile: _agentCodex,
              status: AgentEnvironmentStatus(
                kind: AgentEnvironmentStatusKind.ready,
                detail: 'Ready',
                checkedAt: DateTime.now(),
              ),
            ),
          ],
        );

        final input = find.byKey(const Key('cli_chat_input_field'));
        await tester.enterText(input, 'test prompt text');
        await tester.tap(find.byKey(const Key('cli_send_button')));
        await tester.pump();

        expect(find.text('test prompt text'), findsOneWidget);
      },
    );

    testWidgets(
      '_handleSend restores prompt text if sending fails with error code immediately',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
          ),
        );
        cliNotifier.failErrorCodeOnSend = 'CLI_TURN_FAILED';

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          runtimeAgents: [
            AgentRuntimeState(
              profile: _agentCodex,
              status: AgentEnvironmentStatus(
                kind: AgentEnvironmentStatusKind.ready,
                detail: 'Ready',
                checkedAt: DateTime.now(),
              ),
            ),
          ],
        );

        final input = find.byKey(const Key('cli_chat_input_field'));
        await tester.enterText(input, 'my important draft');
        await tester.tap(find.byKey(const Key('cli_send_button')));
        await tester.pump();

        expect(find.text('my important draft'), findsOneWidget);
      },
    );

    testWidgets(
      'deleteSession does not execute if server or agent changed before confirmation',
      (tester) async {
        const session1 = NativeCliSession(id: 'sess-1', title: 'Task session');
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex, _agentOpenCode],
            activeAgent: _agentCodex,
            sessions: const [session1],
            canDelete: true,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);

        final deleteBtn = find.byKey(const Key('cli_delete_session_sess-1'));
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Dialog is open. Switch agent before confirming:
        cliNotifier.updateState(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex, _agentOpenCode],
            activeAgent: _agentOpenCode,
            sessions: const [session1],
            canDelete: true,
          ),
        );

        final confirmDeleteBtn = find.byKey(
          const Key('cli_confirm_delete_button'),
        );
        await tester.tap(confirmDeleteBtn);
        await tester.pump();

        expect(cliNotifier.deletedSessionId, isNull);
      },
    );

    testWidgets(
      'installHistorySdk does not execute if server or agent changed before confirmation',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentClaude],
            activeAgent: _agentClaude,
            errorCode: 'CLI_HISTORY_SDK_MISSING',
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pump();

        final installSdkBtn = find.byKey(const Key('cli_install_sdk_button'));
        await tester.tap(installSdkBtn);
        await tester.pumpAndSettle();

        // Switch server before confirming
        cliNotifier.updateState(
          CliChatState(
            serverId: 'srv-other-99',
            agents: [_agentClaude],
            activeAgent: _agentClaude,
          ),
        );

        final confirmBtn = find.byKey(
          const Key('cli_confirm_install_sdk_button'),
        );
        await tester.tap(confirmBtn);
        await tester.pump();

        expect(cliNotifier.installedSdkConfirmed, isNull);
      },
    );

    testWidgets('OpenCode agent also supports cursor load more button', (
      tester,
    ) async {
      const session1 = NativeCliSession(
        id: 'opencode-sess-1',
        title: 'OpenCode Session 1',
      );
      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [_agentOpenCode],
          activeAgent: _agentOpenCode,
          sessions: const [session1],
          cursor: 'opencode-cursor-abc',
        ),
      );

      await _pumpTestApp(tester, cliNotifier: cliNotifier);

      final loadMoreBtn = find.byKey(const Key('cli_load_more_button'));
      expect(loadMoreBtn, findsOneWidget);
      await tester.tap(loadMoreBtn);
      expect(cliNotifier.lastLoadMore, true);
    });

    testWidgets(
      'mobile screen has view_sidebar_outlined leading button with chatSessionsTooltip',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
          ),
        );

        // Mobile compact screen < 600
        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          size: const Size(400, 800),
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final drawerButton = find.byKey(
          const Key('cli_mobile_session_drawer_button'),
        );
        expect(drawerButton, findsOneWidget);
        expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);

        final iconButton = tester.widget<IconButton>(drawerButton);
        expect(iconButton.tooltip, l10n.chatSessionsTooltip);
      },
    );

    testWidgets(
      'empty draft view shows working directory card and can browse and select directory',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            activeSession: null,
            messages: const [],
          ),
        );

        const subDir = SftpFileItem(
          name: 'project',
          path: '/home/user/project',
          isDirectory: true,
          sizeBytes: 4096,
          formattedSize: '4 KB',
          permissions: 'drwxr-xr-x',
          modified: '2026-09-19',
        );

        final sftpOps = _FakeSftpOps()..returnFiles = [subDir];

        await _pumpTestApp(tester, cliNotifier: cliNotifier, sftpOps: sftpOps);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Verify default working directory indicator
        expect(find.text(l10n.cliDraftWorkingDirLabel), findsOneWidget);
        expect(find.text(l10n.cliDefaultWorkingDir), findsOneWidget);

        // Tap browse button
        final browseBtn = find.byKey(const Key('cli_draft_cwd_browse_button'));
        expect(browseBtn, findsOneWidget);
        await tester.tap(browseBtn);
        await tester.pumpAndSettle();

        // Verify dialog opens and lists subdirectories
        expect(find.text(l10n.cliPickWorkingDirTitle), findsOneWidget);
        expect(find.text('project'), findsOneWidget);

        // Navigate into project directory
        await tester.tap(find.text('project'));
        await tester.pumpAndSettle();

        expect(sftpOps.lastListedPath, '/home/user/project');

        // Click Select This Directory
        final selectBtn = find.byKey(const Key('cli_dialog_select_dir_button'));
        await tester.tap(selectBtn);
        await tester.pumpAndSettle();

        // Verify draft working directory was updated
        expect(cliNotifier.lastDraftCwd, '/home/user/project');
        expect(find.text('/home/user/project'), findsOneWidget);

        // Clear button should be visible now
        final clearBtn = find.byKey(const Key('cli_draft_cwd_clear_button'));
        expect(clearBtn, findsOneWidget);
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        expect(cliNotifier.lastDraftCwd, isNull);
        expect(find.text(l10n.cliDefaultWorkingDir), findsOneWidget);
      },
    );

    testWidgets(
      'working directory picker surfaces error state and retry works',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            activeSession: null,
            messages: const [],
          ),
        );

        final sftpOps = _FakeSftpOps()..shouldThrow = true;

        await _pumpTestApp(tester, cliNotifier: cliNotifier, sftpOps: sftpOps);

        final browseBtn = find.byKey(const Key('cli_draft_cwd_browse_button'));
        await tester.tap(browseBtn);
        await tester.pumpAndSettle();

        // Error message should be displayed
        expect(find.textContaining('Permission denied'), findsOneWidget);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final retryBtn = find.widgetWithText(OutlinedButton, l10n.stateRetry);
        expect(retryBtn, findsOneWidget);

        // While in error state, select button should be disabled
        final selectBtn = find.byKey(const Key('cli_dialog_select_dir_button'));
        expect(tester.widget<FilledButton>(selectBtn).onPressed, isNull);

        // Turn off error and retry
        sftpOps.shouldThrow = false;
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Permission denied'), findsNothing);
        // After retry succeeds, select button should be enabled
        expect(tester.widget<FilledButton>(selectBtn).onPressed, isNotNull);

        // Up button tooltip should be localized
        final upBtnFinder = find.byTooltip(l10n.cliNavigateUp);
        expect(upBtnFinder, findsOneWidget);
      },
    );

    testWidgets(
      'working directory picker does not update draft if server changed while dialog was open',
      (tester) async {
        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            activeSession: null,
            messages: const [],
          ),
        );

        const subDir = SftpFileItem(
          name: 'project',
          path: '/home/user/project',
          isDirectory: true,
          sizeBytes: 4096,
          formattedSize: '4 KB',
          permissions: 'drwxr-xr-x',
          modified: '2026-09-19',
        );
        final sftpOps = _FakeSftpOps()..returnFiles = [subDir];
        final activeServerNotifier = _TestActiveServerNotifier(_server);

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          sftpOps: sftpOps,
          activeServerNotifier: activeServerNotifier,
        );

        final browseBtn = find.byKey(const Key('cli_draft_cwd_browse_button'));
        await tester.tap(browseBtn);
        await tester.pumpAndSettle();

        // Navigate to project directory
        await tester.tap(find.text('project'));
        await tester.pumpAndSettle();

        // Simulate server changed behind the dialog
        activeServerNotifier.selectServerId('srv-other');
        await tester.pump();

        // Tap select button
        await tester.tap(find.byKey(const Key('cli_dialog_select_dir_button')));
        await tester.pumpAndSettle();

        // Draft cwd should NOT have been set because server changed
        expect(cliNotifier.lastDraftCwd, isNull);
      },
    );

    testWidgets(
      'places list at bottom when newly selected history window appears',
      (tester) async {
        final messages = List.generate(
          30,
          (i) => NativeCliMessage(
            id: 'msg-$i',
            role: i.isEven ? 'user' : 'assistant',
            text:
                'Message $i: A long enough line of text to ensure scroll extent',
          ),
        );

        final session = const NativeCliSession(
          id: 'sess-1',
          title: 'Session 1',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: [session],
            activeSession: session,
            messages: messages,
            hasOlderMessages: true,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(
          find.byKey(const Key('cli_messages_list_view')),
        );
        final controller = listView.controller!;
        expect(controller.position.pixels, controller.position.maxScrollExtent);
        expect(controller.position.pixels, greaterThan(0));
      },
    );

    testWidgets(
      'scroll to top automatically calls loadOlderMessages when eligible',
      (tester) async {
        final messages = List.generate(
          30,
          (i) => NativeCliMessage(
            id: 'msg-$i',
            role: i.isEven ? 'user' : 'assistant',
            text: 'Message $i',
          ),
        );

        final session = const NativeCliSession(
          id: 'sess-1',
          title: 'Session 1',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: [session],
            activeSession: session,
            messages: messages,
            hasOlderMessages: true,
            isLoadingOlderMessages: false,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(
          find.byKey(const Key('cli_messages_list_view')),
        );
        final controller = listView.controller!;
        expect(cliNotifier.loadOlderMessagesCalls, 0);

        // Scroll to top
        controller.jumpTo(0);
        await tester.pump();

        expect(cliNotifier.loadOlderMessagesCalls, greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'scroll to top does not call loadOlderMessages when hasOlderMessages is false',
      (tester) async {
        final messages = List.generate(
          30,
          (i) => NativeCliMessage(
            id: 'msg-$i',
            role: i.isEven ? 'user' : 'assistant',
            text: 'Message $i',
          ),
        );

        final session = const NativeCliSession(
          id: 'sess-1',
          title: 'Session 1',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: [session],
            activeSession: session,
            messages: messages,
            hasOlderMessages: false,
            isLoadingOlderMessages: false,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier);
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(
          find.byKey(const Key('cli_messages_list_view')),
        );
        final controller = listView.controller!;

        controller.jumpTo(0);
        await tester.pump();

        expect(cliNotifier.loadOlderMessagesCalls, 0);
      },
    );

    testWidgets(
      'top compact progress indicator appears when isLoadingOlderMessages is true',
      (tester) async {
        final messages = List.generate(
          5,
          (i) => NativeCliMessage(
            id: 'msg-$i',
            role: i.isEven ? 'user' : 'assistant',
            text: 'Message $i',
          ),
        );

        final session = const NativeCliSession(
          id: 'sess-1',
          title: 'Session 1',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex],
            activeAgent: _agentCodex,
            sessions: [session],
            activeSession: session,
            messages: messages,
            hasOlderMessages: true,
            isLoadingOlderMessages: true,
          ),
        );

        await _pumpTestApp(tester, cliNotifier: cliNotifier, settle: false);
        await tester.pump();

        final indicatorFinder = find.byKey(
          const Key('cli_older_messages_loading_indicator'),
        );
        expect(indicatorFinder, findsOneWidget);
      },
    );

    testWidgets('preserves scroll anchor after prepending older messages', (
      tester,
    ) async {
      final initialMessages = List.generate(
        15,
        (i) => NativeCliMessage(
          id: 'msg-${i + 10}',
          role: i.isEven ? 'user' : 'assistant',
          text: 'Message ${i + 10}',
        ),
      );

      final session = const NativeCliSession(id: 'sess-1', title: 'Session 1');

      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [_agentCodex],
          activeAgent: _agentCodex,
          sessions: [session],
          activeSession: session,
          messages: initialMessages,
          hasOlderMessages: true,
          isLoadingOlderMessages: false,
        ),
      );

      await _pumpTestApp(tester, cliNotifier: cliNotifier);
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(
        find.byKey(const Key('cli_messages_list_view')),
      );
      final controller = listView.controller!;

      // Scroll to top so that Message 10 is visible at the top
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      // Find top position of Message 10 before prepend
      final initialTop = tester.getTopLeft(find.text('Message 10'));

      // Prepend 10 older messages
      final prependedMessages = [
        ...List.generate(
          10,
          (i) => NativeCliMessage(
            id: 'msg-$i',
            role: i.isEven ? 'user' : 'assistant',
            text: 'Message $i',
          ),
        ),
        ...initialMessages,
      ];

      cliNotifier.updateState(
        cliNotifier.state.copyWith(
          messages: prependedMessages,
          hasOlderMessages: false,
          isLoadingOlderMessages: false,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Top position of Message 10 should be preserved exactly
      final afterTop = tester.getTopLeft(find.text('Message 10'));
      expect(afterTop.dy, equals(initialTop.dy));
    });

    testWidgets(
      'mobile Drawer remains open after changing Agent, but closes after selecting a session',
      (tester) async {
        final session1 = const NativeCliSession(
          id: 'sess-1',
          title: 'Session 1',
        );
        final session2 = const NativeCliSession(
          id: 'sess-2',
          title: 'Session 2',
        );

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_agentCodex, _agentOpenCode],
            activeAgent: _agentCodex,
            sessions: [session1, session2],
            activeSession: session1,
          ),
        );

        await _pumpTestApp(
          tester,
          cliNotifier: cliNotifier,
          size: const Size(400, 800),
        );

        // Open mobile drawer
        final drawerButton = find.byKey(
          const Key('cli_mobile_session_drawer_button'),
        );
        await tester.tap(drawerButton);
        await tester.pumpAndSettle();

        // Drawer is open
        expect(find.byType(Drawer), findsOneWidget);

        // Switch agent to OpenCode in drawer
        final agentDropdown = find.byKey(const Key('cli_agent_dropdown'));
        expect(agentDropdown, findsOneWidget);
        await tester.tap(agentDropdown);
        await tester.pumpAndSettle();

        // Find OpenCode option and tap it
        await tester.tap(find.text('OpenCode CLI (opencode)').last);
        await tester.pumpAndSettle();

        expect(cliNotifier.lastSelectedAgentId, 'agent-opencode');

        // Drawer must remain open after changing Agent
        expect(find.byType(Drawer), findsOneWidget);

        // Now select a session in the drawer
        await tester.tap(find.text('Session 2'));
        await tester.pumpAndSettle();

        expect(cliNotifier.lastSelectedSessionId, 'sess-2');

        // Selecting a session should close the Drawer
        expect(find.byType(Drawer), findsNothing);
      },
    );
  });
}
