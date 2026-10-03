import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/state_views.dart';

/// Background recovery coverage for the native CLI chat surface.
///
/// Two layers, because they answer different questions:
///
/// * **Real notifier** ([CliChatNotifier]) against a fake SSH executor that
///   reports "not connected": proves the recovery path never reaches the
///   remote, never fabricates a session and never sends a prompt on its own.
/// * **Real view** ([CliChatView]) over a state the test owns: proves what the
///   user keeps seeing while recovering (transcript, selected session, draft)
///   and that sending is disabled during recovery.
///
/// Nothing here opens an SSH connection or starts a process: the executor has no
/// client to hand out, so `_connect` cannot reach a transport.

const _serverId = 'srv-cli-1';

const _server = ServerProfile(
  id: _serverId,
  name: 'CLI Harness Server',
  host: '127.0.0.1',
  port: 22,
  username: 'tester',
);

final _codexAgent = AgentProfile(
  id: 'agent-cli-codex',
  serverId: _serverId,
  name: 'Codex CLI',
  description: 'native CLI agent used by the recovery regression',
  cliCommand: 'codex',
);

/// Records every remote command the notifier could have issued.
class FakeSshExecutor implements SshCommandExecutor {
  int loginShellCalls = 0;
  int streamingCalls = 0;

  List<String> get remoteCommands =>
      List.unmodifiable([...List.filled(loginShellCalls, 'login-shell')]);

  @override
  bool isConnected(String serverId) => false;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    loginShellCalls++;
    throw StateError('CLI_FAKE_EXECUTOR_MUST_NOT_RUN');
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) {
    streamingCalls++;
    throw StateError('CLI_FAKE_EXECUTOR_MUST_NOT_RUN');
  }
}

class DrivenConnectionNotifier extends ServerConnectionNotifier {
  DrivenConnectionNotifier(this._status);

  ConnectionStateEnum _status;

  @override
  ServerConnectionState build() => ServerConnectionState(status: _status);

  void set(ConnectionStateEnum status) {
    _status = status;
    state = ServerConnectionState(status: status);
  }
}

class FixedActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
}

class FixedAgentRegistryNotifier extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: _serverId,
    agents: [
      AgentRuntimeState(
        profile: _codexAgent,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.utc(2026, 9, 30),
        ),
      ),
    ],
  );
}

/// Real `CliChatNotifier` with the SSH layer replaced by a dead executor.
Future<(ProviderContainer, FakeSshExecutor, DrivenConnectionNotifier)>
pumpRealNotifier({
  ConnectionStateEnum initial = ConnectionStateEnum.disconnected,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  final executor = FakeSshExecutor();
  final connection = DrivenConnectionNotifier(initial);
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      activeServerProvider.overrideWith(FixedActiveServerNotifier.new),
      serverConnectionProvider.overrideWith(() => connection),
      agentRegistryProvider.overrideWith(FixedAgentRegistryNotifier.new),
      sshCommandExecutorProvider.overrideWithValue(executor),
    ],
  );
  addTearDown(container.dispose);
  return (container, executor, connection);
}

/// Lets queued microtasks and the notifier's unawaited recovery settle.
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A recovery banner shows a `CircularProgressIndicator`, which never settles.
Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// View-level double: only supplies state, every guard under test is the real
/// one inside [CliChatView].
class ViewNotifier extends CliChatNotifier {
  ViewNotifier(this._initial);

  final CliChatState _initial;
  int sendCalls = 0;

  @override
  CliChatState build() => _initial;

  void emit(CliChatState next) => state = next;

  @override
  Future<void> sendMessage(String text) async {
    sendCalls++;
  }

  @override
  Future<void> selectAgent(String id) async {}

  @override
  Future<void> selectSession(String id) async {}

  @override
  Future<void> refreshSessions({bool loadMore = false, String? cwd}) async {}

  @override
  Future<void> stop() async {}

  @override
  void createDraft() {}
}

void main() {
  group('CliChatNotifier - recovery never invents remote work', () {
    test(
      'a disconnected chat refuses to send and touches no remote command',
      () async {
        final (container, executor, connection) = await pumpRealNotifier();
        final notifier = container.read(cliChatProvider.notifier);
        await settle();

        // Select the agent while the transport is dead: selection must be
        // possible offline, the failure is only about the transport.
        await notifier.selectAgent(_codexAgent.id).catchError((Object _) {});
        expect(container.read(cliChatProvider).activeAgent?.id, _codexAgent.id);

        await notifier.sendMessage('deploy the nightly build');
        await settle();

        final state = container.read(cliChatProvider);
        expect(state.messages, isEmpty, reason: 'nothing was appended locally');
        expect(state.sessions, isEmpty, reason: 'no session was fabricated');
        expect(state.isSending, isFalse);
        expect(executor.loginShellCalls, 0);
        expect(executor.streamingCalls, 0);
        expect(
          container.read(serverConnectionProvider).status,
          ConnectionStateEnum.disconnected,
        );
      },
    );

    test(
      'going offline marks recovery without dropping the selection',
      () async {
        final (container, executor, connection) = await pumpRealNotifier();
        final notifier = container.read(cliChatProvider.notifier);
        await settle();
        await notifier.selectAgent(_codexAgent.id).catchError((Object _) {});

        connection.set(ConnectionStateEnum.connected);
        await settle();
        connection.set(ConnectionStateEnum.disconnected);
        await settle();

        final state = container.read(cliChatProvider);
        expect(
          state.recoveryStatus,
          SessionRecoveryStatus.reconnecting,
          reason: 'a lost transport is a recoverable state, not a failure',
        );
        expect(state.isSending, isFalse);
        expect(
          state.activeAgent?.id,
          _codexAgent.id,
          reason: 'the chosen agent survives the disconnect',
        );
        expect(state.sessions, isEmpty);
        expect(executor.loginShellCalls, 0);
      },
    );

    test(
      'reconnecting reports the failure and sends nothing by itself',
      () async {
        final (container, executor, connection) = await pumpRealNotifier();
        final notifier = container.read(cliChatProvider.notifier);
        await settle();
        await notifier.selectAgent(_codexAgent.id).catchError((Object _) {});
        expect(executor.loginShellCalls, 0);

        final history = <String>[];
        container.listen<CliChatState>(
          cliChatProvider,
          (_, next) => history.add(
            '${next.recoveryStatus.name}/${next.errorCode ?? '-'}/'
            '${next.sessions.length}/${next.messages.length}',
          ),
        );
        connection.set(ConnectionStateEnum.connected);
        await settle();
        connection.set(ConnectionStateEnum.disconnected);
        await settle();
        connection.set(ConnectionStateEnum.connected);
        await settle();

        final state = container.read(cliChatProvider);
        final dump = 'transitions=$history';
        expect(
          state.recoveryStatus,
          SessionRecoveryStatus.failed,
          reason: dump,
        );
        expect(state.errorCode, 'CLI_DISCONNECTED', reason: dump);
        expect(state.sessions, isEmpty, reason: 'no session was invented');
        expect(state.messages, isEmpty, reason: 'no prompt was ever sent');
        expect(state.activeAgent?.id, _codexAgent.id, reason: dump);
        expect(
          executor.loginShellCalls,
          0,
          reason: 'a dead transport must not be probed with remote commands',
        );
        expect(executor.streamingCalls, 0);

        await notifier.sendMessage('are you there?');
        await settle();
        expect(container.read(cliChatProvider).messages, isEmpty);
        expect(executor.loginShellCalls, 0);
      },
    );
  });

  group('CliChatView - what stays usable while recovering', () {
    final session = NativeCliSession(
      id: 'cli-sess-1',
      title: 'Nightly run',
      cwd: '/srv/nightly',
    );

    CliChatState state(SessionRecoveryStatus recovery) => CliChatState(
      recoveryStatus: recovery,
      serverId: _serverId,
      agents: [_codexAgent],
      activeAgent: _codexAgent,
      sessions: [session],
      activeSession: session,
      messages: const [
        NativeCliMessage(id: 'cli-msg-1', role: 'user', text: 'run the tests'),
        NativeCliMessage(
          id: 'cli-msg-2',
          role: 'assistant',
          text: 'all green on the runner',
        ),
      ],
    );

    /// View-level double: only supplies state, every guard under test is the
    /// real one in [CliChatView].
    Future<(ViewNotifier, DrivenConnectionNotifier)> pumpView(
      WidgetTester tester, {
      required SessionRecoveryStatus recovery,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final notifier = ViewNotifier(state(recovery));
      final connection = DrivenConnectionNotifier(
        ConnectionStateEnum.connected,
      );
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storage),
            activeServerProvider.overrideWith(FixedActiveServerNotifier.new),
            serverConnectionProvider.overrideWith(() => connection),
            agentRegistryProvider.overrideWith(FixedAgentRegistryNotifier.new),
            cliChatProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CliChatView(),
          ),
        ),
      );
      await pumpFrames(tester);
      return (notifier, connection);
    }

    testWidgets('reconnecting keeps transcript and session, disables sending', (
      tester,
    ) async {
      final (notifier, _) = await pumpView(
        tester,
        recovery: SessionRecoveryStatus.reconnecting,
      );

      expect(find.byKey(const ValueKey('cli-msg-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('cli-msg-2')), findsOneWidget);
      expect(find.text('all green on the runner'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Nightly run'))
            .selected,
        isTrue,
        reason: 'the selected session survives the recovery',
      );
      expect(
        find.byKey(const Key('cliChatSessionRecoveryBannerDesktop')),
        findsNothing,
        reason: '恢复横幅已收拢到 shell 顶栏，会话内不再重复',
      );
      expect(find.byType(OfflineStateView), findsNothing);

      final input = find.byKey(const Key('cli_chat_input_field'));
      final editable = tester.widget<EditableText>(
        find.descendant(of: input, matching: find.byType(EditableText)),
      );
      expect(
        editable.readOnly,
        isFalse,
        reason: 'the composer stays usable while recovering',
      );
      await tester.enterText(input, 'and the deploy?');
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('cli_send_button')))
            .onPressed,
        isNull,
        reason: 'sending is what recovery blocks',
      );
      expect(notifier.sendCalls, 0);

      notifier.emit(state(SessionRecoveryStatus.syncing));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('cli_send_button')))
            .onPressed,
        isNull,
        reason: 'syncing blocks sending too',
      );
      expect(notifier.sendCalls, 0);
      expect(
        find.byKey(const Key('cliChatSessionRecoveryBannerDesktop')),
        findsNothing,
        reason: 'syncing 同样不在会话内重复出横幅',
      );
    });

    testWidgets('the draft typed before a disconnect is still there after it', (
      tester,
    ) async {
      final (notifier, connection) = await pumpView(
        tester,
        recovery: SessionRecoveryStatus.idle,
      );

      await tester.enterText(
        find.byKey(const Key('cli_chat_input_field')),
        'half typed question',
      );
      await tester.pump();

      connection.set(ConnectionStateEnum.disconnected);
      await tester.pump();
      expect(
        find.byType(OfflineStateView),
        findsNothing,
        reason: '断线不再整页接管：缓存的转写与草稿必须留在原地',
      );
      expect(find.byKey(const ValueKey('cli-msg-2')), findsOneWidget);
      expect(find.byKey(const Key('cli_chat_input_field')), findsOneWidget);

      connection.set(ConnectionStateEnum.connected);
      notifier.emit(state(SessionRecoveryStatus.reconnecting));
      await pumpFrames(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('cli_chat_input_field')))
            .controller
            ?.text,
        'half typed question',
        reason: 'a dropped connection must not discard what was typed',
      );
      expect(find.byKey(const ValueKey('cli-msg-2')), findsOneWidget);
      expect(notifier.sendCalls, 0);
    });
  });
}
