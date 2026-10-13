import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/app_center/widgets/app_details_dialog.dart';
import 'package:valhalla/features/app_center/widgets/app_operation_wizard_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;
import '../support/application_center_fakes.dart';

final _jellyfinApp = CatalogApplication(
  sourceId: ApplicationSource.official.id,
  id: 'org.icewhale.jellyfin',
  title: 'Jellyfin',
  composeUrl:
      'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
);

ApplicationTemplate _template({
  bool privileged = false,
  bool retainedMounts = false,
}) {
  final compose = <String, dynamic>{
    'services': {
      'jellyfin': {
        'image': 'jellyfin/jellyfin',
        'ports': ['8096:8096'],
        'devices': ['/dev/dri:/dev/dri'],
        if (privileged) 'privileged': true,
        'volumes': [
          '/DATA/AppData/jellyfin:/config',
          '/opt/vc/lib:/opt/vc/lib',
          '/DATA/Media:/Media',
          if (retainedMounts) '/data/retained:/opt/vc/lib',
          if (retainedMounts)
            {'type': 'bind', 'source': '/data/other', 'target': '/opt/vc/lib'},
        ],
      },
    },
  };
  return ApplicationTemplate(
    application: _jellyfinApp,
    compose: compose,
    metadata: const {},
    blockers: ApplicationComposeService.blockers(compose),
  );
}

class _ProfileCenter extends ApplicationCenterNotifier {
  _ProfileCenter(this.template);
  final ApplicationTemplate template;
  ApplicationTemplate? preparedTemplate;
  ApplicationConfiguration? preparedConfiguration;

  @override
  ApplicationCenterState build() => ApplicationCenterState(
    environment: centerEnvironment(),
    catalog: [_jellyfinApp],
  );

  @override
  Future<ApplicationTemplate> loadTemplate(
    CatalogApplication application,
  ) async => template;

  @override
  Future<ApplicationEnvironment> inspectEnvironment({
    String? sudoPassword,
  }) async => centerEnvironment();

  @override
  void setObservedTask(String? taskId) {}

  @override
  void clearObservedTask(String taskId) {}

  @override
  Future<ApplicationOperationPlan> prepare(
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    preparedTemplate = template;
    preparedConfiguration = configuration;
    return CenterDeploymentService().prepare(
      centerServer,
      centerEnvironment(),
      operation,
      template: template,
      configuration: configuration,
      deployment: deployment,
    );
  }
}

void main() {
  Finder filledButtons() =>
      find.byWidgetPredicate((widget) => widget is FilledButton);

  Future<void> host(
    WidgetTester tester,
    _ProfileCenter notifier, {
    ApplicationConfiguration? configuration,
  }) async {
    await loadRealTextFonts();
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final connection = CenterConnection();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationCenterProvider.overrideWith(() => notifier),
          activeServerProvider.overrideWith(CenterActiveServer.new),
          serverConnectionProvider.overrideWith(() => connection),
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: Colors.green,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (configuration == null) {
                    AppDetailsDialog.show(context, application: _jellyfinApp);
                  } else {
                    AppOperationWizardDialog.show(
                      context,
                      operation: ApplicationOperation.configure,
                      catalogApp: _jellyfinApp,
                      deployment: centerDeployment(),
                      initialTemplate: notifier.template,
                      initialConfiguration: configuration,
                    );
                  }
                },
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(TextButton));
    ProviderScope.containerOf(context).read(serverConnectionProvider);
    connection.setConnected(true);
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
  }

  testWidgets('software profile is opt-in and passes the original template', (
    tester,
  ) async {
    final notifier = _ProfileCenter(_template());
    await host(tester, notifier);
    final profile = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(profile).value, false);
    expect(tester.widget<FilledButton>(filledButtons()).onPressed, isNull);
    await tester.ensureVisible(profile);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    final install = filledButtons();
    expect(tester.widget<FilledButton>(install).onPressed, isNotNull);
    await tester.ensureVisible(install);
    await tester.tap(install);
    await tester.pumpAndSettle();
    final wizard = tester.widget<AppOperationWizardDialog>(
      find.byType(AppOperationWizardDialog),
    );
    expect(wizard.initialTemplate, same(notifier.template));
    expect(wizard.initialJellyfinSoftwareMode, true);
    final access = find.byType(ChoiceChip).first;
    await tester.ensureVisible(access);
    await tester.tap(access);
    await tester.pumpAndSettle();
    await tester.tap(filledButtons());
    await tester.pumpAndSettle();
    expect(notifier.preparedTemplate, same(notifier.template));
    expect(notifier.preparedConfiguration?.jellyfinSoftwareMode, true);
    expect(
      notifier.preparedConfiguration!.mounts
          .singleWhere((mount) => mount.target == '/Media')
          .readOnly,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'software profile does not bypass an unrelated privilege blocker',
    (tester) async {
      await host(tester, _ProfileCenter(_template(privileged: true)));
      final profile = find.byType(Checkbox);
      await tester.ensureVisible(profile);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(filledButtons()).onPressed, isNull);
      expect(find.byType(AppOperationWizardDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile preview never labels preserved mounts as removed', (
    tester,
  ) async {
    await host(tester, _ProfileCenter(_template(retainedMounts: true)));
    final profile = find.byType(Checkbox);
    await tester.ensureVisible(profile);
    await tester.tap(profile);
    await tester.pumpAndSettle();
    expect(find.text('- volume: /opt/vc/lib:/opt/vc/lib'), findsOneWidget);
    expect(find.text('- volume: /data/retained:/opt/vc/lib'), findsNothing);
    expect(find.text('- volume: /data/other:/opt/vc/lib'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing configuration preserves the software profile on review',
    (tester) async {
      final notifier = _ProfileCenter(_template());
      final configuration = ApplicationComposeService.defaults(
        notifier.template,
        centerEnvironment(),
        centerDeployment().id,
        jellyfinSoftwareMode: true,
      );
      await host(tester, notifier, configuration: configuration);
      await tester.tap(filledButtons());
      await tester.pumpAndSettle();
      expect(notifier.preparedTemplate, same(notifier.template));
      expect(notifier.preparedConfiguration?.jellyfinSoftwareMode, true);
      expect(tester.takeException(), isNull);
    },
  );
}
