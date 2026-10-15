import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/agent_update_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _server = ServerProfile(
  id: 'compact-fixture',
  name: 'Long isolated development server',
  host: '192.0.2.10',
  username: 'fixture',
);

class _Active extends ActiveServerNotifier {
  @override
  ServerProfile build() => _server;
}

class _Connection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    activeServerId: 'compact-fixture',
    status: ConnectionStateEnum.connected,
  );
}

class _Registry extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: _server.id,
    agents: [
      AgentRuntimeState(
        profile: AgentProfile(
          id: 'builtin-agy',
          serverId: _server.id,
          name: 'A long independent Agent fixture',
          description: '',
          cliCommand: 'agy',
          acpCommand: 'agy_acp_server.par',
          executionTarget: 'docker',
          containerReference: 'isolated-development-container',
        ),
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.utc(2026, 10, 15),
          diagnosticLog: 'fixture diagnostic output',
        ),
      ),
    ],
  );
}

class _Updates extends AgentUpdatesNotifier {
  @override
  AgentUpdatesState build() =>
      const AgentUpdatesState(serverId: 'compact-fixture');
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(_Active.new),
        serverConnectionProvider.overrideWith(_Connection.new),
        agentRegistryProvider.overrideWith(_Registry.new),
        agentUpdatesProvider.overrideWith(_Updates.new),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const AgentManagementView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 400.0, 412.0]) {
    testWidgets(
      'mobile $width dp keeps the Agent header readable and actions reachable',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester);
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Agent Management'),
        );
        expect(tester.getSize(title).width, greaterThanOrEqualTo(100));
        for (final label in ['Check Updates', 'Check Status', 'Add Agent']) {
          final action = find.descendant(
            of: find.byType(AppBar),
            matching: find.byTooltip(label),
          );
          expect(action.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('desktop Agent header retains the labelled add action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester);
    expect(
      find
          .descendant(of: find.byType(AppBar), matching: find.text('Add Agent'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Agent preserves actions and reduced-motion details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester);
    for (final key in [
      'agent_bottom_login_builtin-agy',
      'agent_acp_login_builtin-agy',
      'agent_edit_button_builtin-agy',
      'agent_toggle_details_builtin-agy',
    ]) {
      final action = find.byKey(Key(key));
      expect(tester.widget<IconButton>(action).onPressed, isNotNull);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    }
    expect(find.text('Docker: isolated-development-container'), findsWidgets);
    for (final animation in tester.widgetList<AnimatedCrossFade>(
      find.byType(AnimatedCrossFade),
    )) {
      expect(animation.duration, Duration.zero);
    }
    await tester.tap(find.byKey(const Key('agent_toggle_details_builtin-agy')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final diagnostics = find.byKey(
      const Key('agent_diagnostic_log_button_builtin-agy'),
    );
    await tester.ensureVisible(diagnostics);
    expect(tester.widget<OutlinedButton>(diagnostics).onPressed, isNotNull);
    await tester.tap(diagnostics);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('agent_diagnostic_log_content')),
      findsOneWidget,
    );
    expect(find.text('fixture diagnostic output'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('320dp 2x ${locale.languageCode} Agent card has no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, locale: locale, scale: 2);
      expect(tester.takeException(), isNull);
      final expand = find.byKey(const Key('agent_toggle_details_builtin-agy'));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
