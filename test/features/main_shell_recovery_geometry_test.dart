import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/design/motion_widgets.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_update_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_view.dart';

import '../support/acp_chat_widget_harness.dart';

class _GeometrySftp extends SftpNotifier {
  @override
  SftpState build() => SftpState(
    currentPath: '/',
    viewMode: SftpViewMode.list,
    files: List.generate(
      80,
      (index) => SftpFileItem(
        name: 'file-${index.toString().padLeft(3, '0')}.txt',
        path: '/file-$index.txt',
        isDirectory: false,
        sizeBytes: 100,
        formattedSize: '100 B',
        permissions: '-rw-r--r--',
        modified: '2026-10-15 12:30:45',
      ),
    ),
  );

  void cached(bool value) => state = state.copyWith(
    cachedAt: value ? DateTime.utc(2026, 10, 15, 12, 30) : null,
    clearCachedAt: !value,
  );
}

class _GeometrySettings extends SettingsNotifier {
  _GeometrySettings(this.initial);
  final SettingsState initial;
  @override
  SettingsState build() => initial;
}

class _NoGeometryServer extends ActiveServerNotifier {
  _NoGeometryServer(this.initial);
  final ServerProfile? initial;
  @override
  ServerProfile? build() => initial;
  void select(ServerProfile server) => state = server;
}

class _NoGeometryServers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [];
}

class _GeometryConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState();
}

class _GeometryAcp extends FakeAcpChatNotifier {
  _GeometryAcp() : super(const AiChatState());
  void recovery(SessionRecoveryStatus status) =>
      state = state.copyWith(recoveryStatus: status);
}

class _GeometryCli extends CliChatNotifier {
  @override
  CliChatState build() => const CliChatState();
}

class _GeometryUpdates extends AgentUpdatesNotifier {
  final List<String?> enteredTargets = [];
  int dismissCalls = 0;
  @override
  AgentUpdatesState build() => const AgentUpdatesState();

  @override
  Future<void> onChatEntered() async {
    enteredTargets.add(
      ref.read(activeServerProvider)?.connectionKey.toString(),
    );
  }

  @override
  Future<void> dismissUpdateNotice() async {
    dismissCalls++;
    state = const AgentUpdatesState();
  }

  void showNotice() => state = AgentUpdatesState(
    showUpdateNotices: true,
    noticeDay: '2026-10-15',
    agents: {
      'fixture': AgentUpdateEntry(
        report: AgentUpdateReport(
          agentId: 'fixture',
          targetKey: 'fixture-target',
          checkedAt: DateTime.utc(2026, 10, 15),
          components: const [
            AgentComponentUpdate(
              component: AgentUpdateComponent.cli,
              status: AgentUpdateStatus.available,
              installedVersion: '1.0.0',
              latestVersion: '1.1.0',
            ),
          ],
        ),
      ),
    },
  );
}

class _GeometryReconnect extends ReconnectController {
  _GeometryReconnect() : super(connectAttempt: (_) async {});
  ReconnectState value = const ReconnectState(
    status: ReconnectStatus.connected,
  );
  @override
  ReconnectState get state => value;
  @override
  bool get userIntent => true;
  @override
  bool get hasEverStarted => true;
  void change(ReconnectStatus status, {bool retryable = true}) {
    value = ReconnectState(status: status, attempt: 1, retryable: retryable);
    debugEmit(value);
  }
}

Future<
  ({
    ProviderContainer container,
    _GeometryReconnect reconnect,
    _GeometrySftp files,
    _GeometryAcp acp,
    _GeometryUpdates updates,
    _NoGeometryServer activeServer,
  })
>
_pumpShell(
  WidgetTester tester,
  Size size, {
  SettingsState settings = const SettingsState(
    startupSection: AppSection.files,
    bottomNavigationSections: [AppSection.files],
  ),
  ServerProfile? server,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();
  final reconnect = _GeometryReconnect();
  addTearDown(reconnect.dispose);
  final files = _GeometrySftp();
  final acp = _GeometryAcp();
  final updates = _GeometryUpdates();
  final activeServer = _NoGeometryServer(server);
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      settingsProvider.overrideWith(() => _GeometrySettings(settings)),
      activeServerProvider.overrideWith(() => activeServer),
      serverListProvider.overrideWith(_NoGeometryServers.new),
      serverConnectionProvider.overrideWith(_GeometryConnection.new),
      reconnectControllerProvider.overrideWithValue(reconnect),
      sftpProvider.overrideWith(() => files),
      aiChatProvider.overrideWith(() => acp),
      cliChatProvider.overrideWith(_GeometryCli.new),
      agentUpdatesProvider.overrideWith(() => updates),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    reconnect: reconnect,
    files: files,
    acp: acp,
    updates: updates,
    activeServer: activeServer,
  );
}

const _chatSettings = SettingsState(
  startupSection: AppSection.files,
  bottomNavigationSections: [
    AppSection.files,
    AppSection.aiChat,
    AppSection.cliChat,
  ],
  enabledExperimentalFeatures: {ExperimentalFeature.cliChat},
);

const _entryServer = ServerProfile(
  id: 'update-entry-server',
  name: 'Entry fixture',
  host: '192.0.2.10',
  port: 22,
  username: 'tester',
);

Finder _navigationItem(AppSection section) => find.descendant(
  of: find.byKey(Key('bottom_nav_item_${section.name}')),
  matching: find.byType(InkWell),
);

void main() {
  testWidgets(
    'pre-mounted ACP and CLI never schedule update checks from a non-chat page',
    (tester) async {
      final fixture = await _pumpShell(
        tester,
        const Size(500, 800),
        settings: _chatSettings,
        server: _entryServer,
      );
      expect(find.byType(AiChatView, skipOffstage: false), findsOneWidget);
      expect(find.byType(CliChatView, skipOffstage: false), findsOneWidget);
      expect(fixture.updates.enteredTargets, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(fixture.updates.enteredTargets, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final section in [AppSection.aiChat, AppSection.cliChat]) {
    testWidgets(
      'first visible ${section.name} navigation schedules exactly one update check',
      (tester) async {
        final fixture = await _pumpShell(
          tester,
          const Size(500, 800),
          settings: _chatSettings,
          server: _entryServer,
        );
        expect(fixture.updates.enteredTargets, isEmpty);
        await tester.tap(_navigationItem(section));
        await tester.pumpAndSettle();
        expect(fixture.updates.enteredTargets, [
          _entryServer.connectionKey.toString(),
        ]);
        await tester.tap(_navigationItem(section));
        await tester.pumpAndSettle();
        expect(fixture.updates.enteredTargets, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('visible ${section.name} notices same-ID SSH target change', (
      tester,
    ) async {
      final fixture = await _pumpShell(
        tester,
        const Size(500, 800),
        settings: _chatSettings,
        server: _entryServer,
      );
      await tester.tap(_navigationItem(section));
      await tester.pumpAndSettle();
      final changed = _entryServer.copyWith(host: '192.0.2.11');
      fixture.activeServer.select(changed);
      await tester.pumpAndSettle();
      expect(fixture.updates.enteredTargets, [
        _entryServer.connectionKey.toString(),
        changed.connectionKey.toString(),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'leaving ${section.name} before its post-frame callback cancels update entry',
      (tester) async {
        final fixture = await _pumpShell(
          tester,
          const Size(500, 800),
          settings: _chatSettings,
          server: _entryServer,
        );
        final nav = tester.widget<MainBottomNavigationBar>(
          find.byType(MainBottomNavigationBar),
        );
        // Both real navigation callbacks run before a new frame is rendered.
        nav.onDestinationSelected(appSectionToViewIndex(section));
        nav.onDestinationSelected(appSectionToViewIndex(AppSection.files));
        await tester.pumpAndSettle();
        expect(fixture.updates.enteredTargets, isEmpty);
        expect(
          find.byType(RemoteBrowserEntriesView).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 800.0, 1280.0]) {
    testWidgets(
      'real shell $width recovery never moves file viewport, scroll, or focus',
      (tester) async {
        final fixture = await _pumpShell(tester, Size(width, 800));
        final browser = find.byType(RemoteBrowserEntriesView);
        final scrollable = find.descendant(
          of: browser,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        final scroll = tester.state<ScrollableState>(scrollable);
        scroll.position.jumpTo(240);
        await tester.pump();
        final field = find.byKey(const Key('sftp_search_field'));
        await tester.tap(field);
        await tester.pump();
        final input = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(input.focusNode.hasFocus, isTrue);
        final shellRect = tester.getRect(find.byType(AnimatedIndexedStack));
        final fileRect = tester.getRect(browser);
        final searchRect = tester.getRect(field);
        final offset = scroll.position.pixels;

        void expectStable(String phase) {
          expect(
            tester.getRect(find.byType(AnimatedIndexedStack)),
            shellRect,
            reason: '$phase shell',
          );
          expect(
            tester.getRect(browser),
            fileRect,
            reason: '$phase file viewport',
          );
          expect(tester.getRect(field), searchRect, reason: '$phase search');
          expect(scroll.position.pixels, offset, reason: '$phase scroll');
          expect(input.focusNode.hasFocus, isTrue, reason: '$phase focus');
          expect(tester.takeException(), isNull, reason: phase);
        }

        fixture.files.cached(true);
        fixture.reconnect.change(ReconnectStatus.reconnecting);
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byKey(const Key('reconnectingBanner')), findsOneWidget);
        expectStable('SSH reconnecting + cached files');
        fixture.reconnect.change(ReconnectStatus.failed, retryable: false);
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byKey(const Key('hostKeyChangedBanner')), findsOneWidget);
        expectStable('host key failure');
        fixture.reconnect.change(ReconnectStatus.reconnecting);
        await tester.pump(const Duration(milliseconds: 450));
        fixture.reconnect.change(ReconnectStatus.connected);
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byKey(const Key('reconnectedBanner')), findsOneWidget);
        expectStable('restored transient');
        await tester.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('reconnectedBanner')), findsNothing);
        expectStable('restored hidden');
        for (final phase in [
          SessionRecoveryStatus.reconnecting,
          SessionRecoveryStatus.syncing,
          SessionRecoveryStatus.incomplete,
          SessionRecoveryStatus.failed,
          SessionRecoveryStatus.idle,
        ]) {
          fixture.acp.recovery(phase);
          await tester.pump(const Duration(milliseconds: 450));
          expectStable('ACP $phase');
        }
        fixture.files.cached(false);
        await tester.pump();
        expectStable('file data refresh finished');
        fixture.updates.showNotice();
        await tester.pump(const Duration(milliseconds: 450));
        expect(
          find.byKey(const Key('agentUpdateNoticeBanner')),
          findsOneWidget,
        );
        expectStable('agent update notice');
        await tester.tap(
          find.byKey(const Key('dismissAgentUpdateNoticeButton')),
        );
        await tester.pump(const Duration(milliseconds: 450));
        expect(fixture.updates.dismissCalls, 1);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        expect(tester.getRect(browser), fileRect);
        expect(tester.getRect(find.byType(AnimatedIndexedStack)), shellRect);
        expect(scroll.position.pixels, offset);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
