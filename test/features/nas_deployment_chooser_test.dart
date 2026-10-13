import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/nas_install_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/app_center/widgets/app_details_dialog.dart';
import 'package:valhalla/features/nas/widgets/jellyfin_source_actions.dart';
import 'package:valhalla/features/nas/widgets/nas_deployment_chooser.dart';
import 'package:valhalla/features/nas/widgets/nas_source_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;
import '../support/application_center_fakes.dart';

final _app = CatalogApplication(
  sourceId: ApplicationSource.official.id,
  id: 'org.icewhale.jellyfin',
  title: 'Jellyfin',
  composeUrl:
      '${ApplicationSource.official.url}/Apps/Jellyfin/docker-compose.yml',
);

class _Settings extends SettingsNotifier {
  int enables = 0;
  @override
  SettingsState build() => const SettingsState();
  @override
  Future<void> setExperimentalFeature(
    ExperimentalFeature feature,
    bool enabled,
  ) async {
    enables++;
    state = state.copyWith(enabledExperimentalFeatures: {feature});
  }
}

class _Center extends ApplicationCenterNotifier {
  _Center({this.cached = true, this.sourceEnabled = true});
  final bool cached, sourceEnabled;
  Completer<void>? refreshGate;
  bool failRefresh = false;
  int refreshes = 0, templates = 0;
  CatalogApplication? loaded;
  @override
  ApplicationCenterState build() => ApplicationCenterState(
    environment: centerEnvironment(),
    sources: [ApplicationSource.official.copyWith(enabled: sourceEnabled)],
    catalog: cached ? [_app] : [],
  );
  @override
  Future<void> refreshCatalog({String? sourceId}) async {
    expect(sourceId, ApplicationSource.official.id);
    refreshes++;
    if (refreshGate != null) await refreshGate!.future;
    state = state.copyWith(
      catalog: failRefresh ? [] : [_app],
      sourceErrors: failRefresh
          ? {ApplicationSource.official.id: 'FIXTURE_NETWORK'}
          : {},
    );
  }

  @override
  Future<ApplicationTemplate> loadTemplate(
    CatalogApplication application,
  ) async {
    templates++;
    loaded = application;
    return ApplicationTemplate(
      application: application,
      compose: const {
        'services': {
          'jellyfin': {'image': 'jellyfin/jellyfin'},
        },
      },
      metadata: const {},
    );
  }
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [centerServer];
}

class _Sources extends NasSourcesNotifier {
  @override
  NasSourcesState build() => const NasSourcesState();
  void saved(NasSource source) => state = NasSourcesState(sources: [source]);
}

void main() {
  Future<({CenterActiveServer active, CenterConnection connection})> host(
    WidgetTester tester,
    _Center center, {
    _Settings? settings,
    bool connected = true,
    double width = 400,
    double scale = 1,
    Widget? child,
    _Sources? sources,
  }) async {
    await loadRealTextFonts();
    final active = CenterActiveServer();
    final connection = CenterConnection();
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationCenterProvider.overrideWith(() => center),
          settingsProvider.overrideWith(() => settings ?? _Settings()),
          activeServerProvider.overrideWith(() => active),
          serverConnectionProvider.overrideWith(() => connection),
          serverListProvider.overrideWith(_Servers.new),
          nasInstallTaskProvider.overrideWith((ref) => Stream.value(null)),
          nasSourcesProvider.overrideWith(() => sources ?? _Sources()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: Colors.green,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body:
                  child ??
                  TextButton(
                    onPressed: () => NasDeploymentChooser.show(context),
                    child: const Text('Open fixture'),
                  ),
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(serverConnectionProvider);
    connection.setConnected(connected);
    if (child == null) await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
    return (active: active, connection: connection);
  }

  testWidgets(
    'Docker uses the exact cached official application without refresh',
    (tester) async {
      final center = _Center();
      await host(tester, center);
      await tester.tap(find.text('Docker application'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDetailsDialog), findsOneWidget);
      expect(center.loaded, same(_app));
      expect(center.refreshes, 0);
    },
  );

  testWidgets('Docker opens without an experimental feature prompt', (
    tester,
  ) async {
    final center = _Center();
    final settings = _Settings();
    await host(tester, center, settings: settings);
    await tester.tap(find.text('Docker application'));
    await tester.pumpAndSettle();
    expect(settings.enables, 0);
    expect(find.text('Enable'), findsNothing);
    expect(find.byType(AppDetailsDialog), findsOneWidget);
    expect(center.templates, 1);
  });

  testWidgets('disabled official source is not silently enabled or loaded', (
    tester,
  ) async {
    final center = _Center(sourceEnabled: false);
    await host(tester, center);
    await tester.tap(find.text('Docker application'));
    await tester.pumpAndSettle();
    expect(center.refreshes, 0);
    expect(center.templates, 0);
    expect(
      find.textContaining('official Jellyfin application is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('refresh errors stored in state are not treated as success', (
    tester,
  ) async {
    final center = _Center(cached: false)..failRefresh = true;
    await host(tester, center);
    await tester.tap(find.text('Docker application'));
    await tester.pumpAndSettle();
    expect(center.refreshes, 1);
    expect(center.templates, 0);
    expect(
      find.textContaining('official Jellyfin application is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets(
    'switching targets during catalog refresh never opens a new target',
    (tester) async {
      final gate = Completer<void>();
      final center = _Center(cached: false)..refreshGate = gate;
      final harness = await host(tester, center);
      await tester.tap(find.text('Docker application'));
      await tester.pump();
      harness.active.select(
        const ServerProfile(
          id: 'other',
          name: 'Other',
          host: 'other.invalid',
          username: 'dev',
        ),
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(center.templates, 0);
      expect(find.byType(AppDetailsDialog), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('disconnected target cannot start either deployment route', (
    tester,
  ) async {
    final center = _Center();
    await host(tester, center, connected: false);
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(center.templates, 0);
  });

  testWidgets('closing chooser while refreshing never opens a late route', (
    tester,
  ) async {
    final gate = Completer<void>();
    final center = _Center(cached: false)..refreshGate = gate;
    await host(tester, center);
    await tester.tap(find.text('Docker application'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(center.templates, 0);
    expect(find.byType(AppDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deployment chooser supports 320dp with doubled text', (
    tester,
  ) async {
    await host(tester, _Center(), width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Install Jellyfin (Native Package)'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source handoff is a stable new remote draft with blank credentials',
    (tester) async {
      await host(
        tester,
        _Center(),
        child: JellyfinSourceActions(
          server: centerServer,
          endpoint: Uri.parse('http://127.0.0.1:18096'),
          showSetup: false,
        ),
      );
      await tester.tap(find.text('Add media source'));
      await tester.pumpAndSettle();
      var dialog = tester.widget<NasSourceDialog>(find.byType(NasSourceDialog));
      final draftId = dialog.initialDraft!.id;
      expect(dialog.source, isNull);
      expect(dialog.initialDraft!.endpoint, 'http://127.0.0.1:18096');
      expect(dialog.initialDraft!.sshServerId, centerServer.id);
      expect(dialog.initialDraft!.username, isEmpty);
      expect(dialog.initialDraft!.userId, isNull);
      Navigator.of(tester.element(find.byType(NasSourceDialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add media source'));
      await tester.pumpAndSettle();
      dialog = tester.widget<NasSourceDialog>(find.byType(NasSourceDialog));
      expect(dialog.initialDraft!.id, draftId);
    },
  );

  testWidgets('a saved draft is never reused for a blank-credential add', (
    tester,
  ) async {
    final sources = _Sources();
    await host(
      tester,
      _Center(),
      sources: sources,
      child: JellyfinSourceActions(
        server: centerServer,
        endpoint: Uri.parse('http://127.0.0.1:18096'),
        showSetup: false,
      ),
    );
    await tester.tap(find.text('Add media source'));
    await tester.pumpAndSettle();
    final saved = tester
        .widget<NasSourceDialog>(find.byType(NasSourceDialog))
        .initialDraft!;
    sources.saved(saved);
    Navigator.of(tester.element(find.byType(NasSourceDialog))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add media source'));
    await tester.pumpAndSettle();
    final next = tester
        .widget<NasSourceDialog>(find.byType(NasSourceDialog))
        .initialDraft!;
    expect(next.id, isNot(saved.id));
    expect(next.endpoint, saved.endpoint);
    expect(next.sshServerId, saved.sshServerId);
  });

  test('Docker handoff never substitutes another same-app deployment', () {
    ApplicationDeployment deployment(String id, {String? serverKey}) =>
        ApplicationDeployment(
          id: id,
          serverKey: serverKey ?? centerEnvironment().serverKey,
          serverId: centerServer.id,
          sourceId: ApplicationSource.official.id,
          appId: _app.id,
          name: 'Jellyfin',
          project: id,
          directory: '/fixture/$id',
          targetIdentity: centerEnvironment().targetIdentity,
          status: 'running',
          endpoint: Uri.parse('http://127.0.0.1:18096'),
        );
    final exact = deployment('new');
    final task = centerTask(
      exact,
    ).copyWith(stage: ApplicationTaskStage.succeeded);
    expect(
      jellyfinDeploymentForTask(task, [deployment('old')], centerServer),
      isNull,
    );
    expect(
      jellyfinDeploymentForTask(task, [deployment('old'), exact], centerServer),
      same(exact),
    );
    expect(
      jellyfinDeploymentForTask(task, [
        deployment('new', serverKey: 'other'),
      ], centerServer),
      isNull,
    );
    expect(
      jellyfinDeploymentForTask(
        task.copyWith(stage: ApplicationTaskStage.checking),
        [exact],
        centerServer,
      ),
      isNull,
    );
  });
}
