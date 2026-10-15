import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/agent_update_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/agents/widgets/agent_update_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _open = Key('open_fixture_update');
const _confirm = Key('agent_confirm_update_button');
const _cancel = Key('agent_update_dialog_cancel_button');
const _server = ServerProfile(
  id: 'server-1',
  name: 'Fixture Server',
  host: 'fixture.invalid',
  username: 'dev',
);

AgentProfile _profile({bool agy = false}) => AgentProfile(
  id: 'fixture-agent',
  serverId: _server.id,
  name: agy ? 'AgY' : 'Claude Code',
  description: '',
  cliCommand: agy ? 'agy' : 'claude',
  acpCommand: agy ? 'agy_acp_server.par' : 'claude-code-acp',
  executionTarget: 'docker',
  containerBinding: 'name',
  containerReference: 'developer-workspace',
  containerUser: 'dev',
);

AgentUpdatePlan _plan({
  AgentProfile? profile,
  String version = '2.0.0',
  bool migration = false,
  bool longSource = false,
  AgentUpdateComponent component = AgentUpdateComponent.acp,
}) => AgentUpdatePlan(
  server: _server,
  profile: profile ?? _profile(),
  targetKey: 'a' * 64,
  preparedAt: DateTime(2026, 10, 15),
  runtimeIdentity: '["1000","/home/dev","/home/dev/.local/bin/cli"]',
  resolvedContainerId: 'b' * 64,
  components: [
    AgentComponentUpdate(
      component: component,
      status: AgentUpdateStatus.available,
      installedVersion: '1.0.0',
      latestVersion: version,
      source: longSource ? '@agentclientprotocol/claude-agent-acp' : 'official',
      command: component == AgentUpdateComponent.cli
          ? "npm install -g '@anthropic-ai/claude-code@$version'"
          : "npm install -g '@agentclientprotocol/claude-agent-acp@$version'",
      migratesClaudeAdapter: migration,
    ),
  ],
);

class _DialogUpdates extends AgentUpdatesNotifier {
  _DialogUpdates(this.nextPlan);

  AgentUpdatePlan nextPlan;
  int prepareCalls = 0;
  int dismissCalls = 0;
  final applied = <AgentUpdatePlan>[];
  Set<AgentUpdateComponent>? requestedComponents;
  Completer<AgentUpdatePlan>? prepareGate;
  Completer<void>? applyGate;
  AgentUpdateException? prepareError;
  AgentUpdateException? applyError;

  @override
  AgentUpdatesState build() => const AgentUpdatesState(serverId: 'server-1');

  @override
  Future<void> dismissUpdateNotice() async {
    dismissCalls++;
  }

  @override
  Future<AgentUpdatePlan> prepareUpdate(
    String agentId, {
    Set<AgentUpdateComponent>? components,
  }) async {
    prepareCalls++;
    requestedComponents = components;
    if (prepareError != null) throw prepareError!;
    return prepareGate == null ? nextPlan : await prepareGate!.future;
  }

  void updating({bool active = true, String log = 'fixture output\n'}) {
    state = AgentUpdatesState(
      serverId: 'server-1',
      agents: {
        nextPlan.profile.id: AgentUpdateEntry(
          isUpdating: active,
          // Core persists this during execution so a crash can be recovered.
          interrupted: true,
          log: log,
        ),
      },
    );
  }

  @override
  Future<void> applyConfirmedUpdate(AgentUpdatePlan plan) async {
    applied.add(plan);
    if (applyGate != null) await applyGate!.future;
    if (applyError != null) throw applyError!;
  }
}

Future<void> _pumpHost(
  WidgetTester tester,
  _DialogUpdates updates, {
  AgentUpdatePlan? initialPlan,
  Set<AgentUpdateComponent>? components,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [agentUpdatesProvider.overrideWith(() => updates)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: _open,
              onPressed: () => AgentUpdateDialog.show(
                context,
                profile: updates.nextPlan.profile,
                initialPlan: initialPlan,
                selectedComponents: components,
              ),
              child: const Text('Open fixture update'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_open));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AgentUpdateDialog)));

void main() {
  for (final component in AgentUpdateComponent.values) {
    testWidgets(
      'single-component selection passes exact ${component.name} scope to prepare and apply',
      (tester) async {
        final plan = _plan(component: component);
        final updates = _DialogUpdates(plan);
        await _pumpHost(tester, updates, components: {component});
        await tester.pumpAndSettle();
        expect(updates.requestedComponents, {component});
        expect(updates.prepareCalls, 1);
        expect(updates.applied, isEmpty);
        expect(find.text(component.name.toUpperCase()), findsOneWidget);
        final other = component == AgentUpdateComponent.cli ? 'ACP' : 'CLI';
        expect(find.text(other), findsNothing);
        await tester.tap(find.byKey(_confirm));
        await tester.pumpAndSettle();
        expect(updates.applied, hasLength(1));
        expect(identical(updates.applied.single, plan), isTrue);
        expect(
          updates.applied.single.components.map((item) => item.component),
          [component],
        );
      },
    );
  }

  testWidgets('opening only prepares; cancellation performs no application', (
    tester,
  ) async {
    final plan = _plan();
    final updates = _DialogUpdates(plan)
      ..prepareGate = Completer<AgentUpdatePlan>();
    await _pumpHost(tester, updates, components: {AgentUpdateComponent.acp});
    expect(updates.dismissCalls, 1);
    expect(updates.prepareCalls, 1);
    expect(updates.requestedComponents, {AgentUpdateComponent.acp});
    expect(updates.applied, isEmpty);
    expect(tester.widget<FilledButton>(find.byKey(_confirm)).onPressed, isNull);
    updates.prepareGate!.complete(plan);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(_confirm)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(_cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AgentUpdateDialog), findsNothing);
    expect(updates.applied, isEmpty);
  });

  testWidgets(
    'initial plan is displayed unchanged and submitted exactly once',
    (tester) async {
      final displayed = _plan(migration: true);
      final updates = _DialogUpdates(_plan(version: '3.0.0'))
        ..applyGate = Completer<void>();
      await _pumpHost(tester, updates, initialPlan: displayed);
      final l10n = _l10n(tester);
      expect(updates.prepareCalls, 0);
      expect(
        find.textContaining('Fixture Server (fixture.invalid)'),
        findsOneWidget,
      );
      expect(find.textContaining('b' * 64), findsOneWidget);
      expect(find.textContaining('(dev)'), findsOneWidget);
      expect(find.textContaining(displayed.runtimeIdentity), findsOneWidget);
      expect(find.text('1.0.0 → 2.0.0'), findsOneWidget);
      expect(find.text(displayed.commandPreview), findsOneWidget);
      expect(find.text(l10n.agentUpdateClaudeMigrationNotice), findsOneWidget);
      await tester.tap(find.byKey(_confirm));
      await tester.pump();
      expect(updates.applied, hasLength(1));
      expect(identical(updates.applied.single, displayed), isTrue);
      expect(
        tester.widget<FilledButton>(find.byKey(_confirm)).onPressed,
        isNull,
      );
      expect(tester.widget<TextButton>(find.byKey(_cancel)).onPressed, isNull);
      await tester.tap(find.byKey(_confirm));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AgentUpdateDialog), findsOneWidget);
      expect(updates.applied, hasLength(1));
      expect(find.text(l10n.agentUpdateSuccess), findsNothing);
      updates.applyGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(l10n.agentUpdateSuccess), findsOneWidget);
      expect(find.byKey(_confirm), findsNothing);
      await tester.tap(find.byKey(_cancel));
      await tester.pumpAndSettle();
      expect(find.byType(AgentUpdateDialog), findsNothing);
    },
  );

  testWidgets(
    'persistent crash marker is not presented as interruption while updating',
    (tester) async {
      final plan = _plan();
      final updates = _DialogUpdates(plan)..applyGate = Completer<void>();
      await _pumpHost(tester, updates, initialPlan: plan);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(_confirm));
      updates.updating();
      await tester.pump();
      expect(find.text(l10n.agentUpdateInterrupted), findsNothing);
      expect(find.text('fixture output\n'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(_cancel)).onPressed, isNull);
      updates.updating(active: false);
      updates.applyGate!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed application cannot show success or replay consumed plan',
    (tester) async {
      final original = _plan();
      final replacement = _plan(version: '3.0.0');
      final updates = _DialogUpdates(replacement)
        ..applyError = const AgentUpdateException(
          'AGENT_UPDATE_EXECUTION_FAILED',
        );
      await _pumpHost(
        tester,
        updates,
        initialPlan: original,
        components: {AgentUpdateComponent.acp},
      );
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(updates.applied, hasLength(1));
      expect(find.text(l10n.agentUpdateSuccess), findsNothing);
      expect(find.text(l10n.agentUpdateFailed), findsWidgets);
      final confirm = find.byKey(_confirm);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.text(l10n.stateRetry), findsOneWidget);
      updates.applyError = null;
      await tester.ensureVisible(find.text(l10n.stateRetry));
      await tester.tap(find.text(l10n.stateRetry));
      await tester.pumpAndSettle();
      expect(updates.prepareCalls, 1);
      expect(updates.requestedComponents, {AgentUpdateComponent.acp});
      expect(
        updates.applied,
        hasLength(1),
        reason: 'Rechecking must not auto-apply',
      );
      expect(find.text('1.0.0 → 3.0.0'), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(updates.applied, hasLength(2));
      expect(
        updates.applied.where((item) => identical(item, original)),
        hasLength(1),
      );
      expect(identical(updates.applied.last, replacement), isTrue);
      expect(find.text(l10n.agentUpdateSuccess), findsOneWidget);
    },
  );

  testWidgets(
    'prepare failure has no executable confirmation and retry is read-only',
    (tester) async {
      final updates = _DialogUpdates(_plan())
        ..prepareError = const AgentUpdateException('AGENT_UPDATE_BUSY');
      await _pumpHost(tester, updates);
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      expect(find.text(l10n.agentUpdateBusy), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_confirm)).onPressed,
        isNull,
      );
      updates.prepareError = null;
      await tester.tap(find.text(l10n.stateRetry));
      await tester.pumpAndSettle();
      expect(updates.prepareCalls, 2);
      expect(updates.applied, isEmpty);
      expect(
        tester.widget<FilledButton>(find.byKey(_confirm)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('AgY confirmation explains official stable-channel behavior', (
    tester,
  ) async {
    final plan = _plan(profile: _profile(agy: true));
    final updates = _DialogUpdates(plan);
    await _pumpHost(tester, updates, initialPlan: plan);
    expect(find.text(_l10n(tester).agentUpdateAgyNotice), findsOneWidget);
    expect(updates.applied, isEmpty);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      '320dp / 2x confirmation and cancellation remain reachable: ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final plan = _plan(migration: true, longSource: true);
        final updates = _DialogUpdates(plan);
        await _pumpHost(
          tester,
          updates,
          initialPlan: plan,
          locale: locale,
          textScale: 2,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(AgentUpdateDialog))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.ensureVisible(find.text(plan.commandPreview));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(_confirm));
        expect(find.byKey(_confirm).hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byKey(_cancel));
        expect(find.byKey(_cancel).hitTestable(), findsOneWidget);
        await tester.tap(find.byKey(_cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AgentUpdateDialog), findsNothing);
        expect(updates.applied, isEmpty);
      },
    );
  }
}
