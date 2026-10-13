import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/features/app_center/widgets/app_operation_wizard_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/application_center_fakes.dart';

class _Connected extends CenterConnection {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _Center extends ApplicationCenterNotifier {
  final ApplicationTemplate template;
  ApplicationConfiguration? prepared;
  _Center(this.template);

  @override
  ApplicationCenterState build() =>
      ApplicationCenterState(environment: centerEnvironment());

  @override
  Future<ApplicationEnvironment> inspectEnvironment({
    String? sudoPassword,
  }) async => centerEnvironment();

  @override
  Future<ApplicationTemplate> loadTemplate(CatalogApplication app) async =>
      template;

  @override
  Future<ApplicationOperationPlan> prepare(
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    // Preserve the real naming validation, but never launch a remote operation.
    if (configuration!.instanceContainerNames) {
      ApplicationComposeService.containerNames(template!, configuration);
    }
    prepared = configuration;
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

ApplicationTemplate _template({bool multiple = false, String? main}) =>
    ApplicationTemplate(
      application: centerApp,
      compose: {
        'services': {
          'web': {'image': 'nginx:alpine'},
          if (multiple) 'db': {'image': 'postgres:alpine'},
        },
        if (main != null) 'x-casaos': {'main': main},
      },
      metadata: const {},
    );

void main() {
  Future<_Center> host(
    WidgetTester tester,
    ApplicationTemplate template, {
    ApplicationConfiguration? config,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final center = _Center(template);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeServerProvider.overrideWith(CenterActiveServer.new),
          serverConnectionProvider.overrideWith(_Connected.new),
          applicationCenterProvider.overrideWith(() => center),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppOperationWizardDialog(
            operation: config == null
                ? ApplicationOperation.install
                : ApplicationOperation.configure,
            catalogApp: centerApp,
            initialTemplate: template,
            initialConfiguration: config,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (config == null) {
      final access = find.byType(ChoiceChip).first;
      await tester.ensureVisible(access);
      await tester.tap(access);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('app-config-name')));
    }
    return center;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('new single-service name is exactly the entered instance', (
    tester,
  ) async {
    final center = await host(tester, _template());
    await tester.enterText(
      find.byKey(const ValueKey('app-config-name')),
      'my-proxy',
    );
    await tester.pump();
    expect(find.text('web: my-proxy'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-config-main-service')), findsNothing);
    await next(tester);
    expect(center.prepared!.instanceContainerNames, isTrue);
    expect(center.prepared!.name, 'my-proxy');
    expect(
      ApplicationComposeService.containerNames(
        center.template,
        center.prepared!,
      ),
      {'web': 'my-proxy'},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid new instance name cannot reach operation review', (
    tester,
  ) async {
    final center = await host(tester, _template());
    await tester.enterText(
      find.byKey(const ValueKey('app-config-name')),
      'two words',
    );
    await tester.pump();
    await next(tester);
    expect(center.prepared, isNull);
    expect(find.text('Execute Plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous main service stays unselected until explicit choice', (
    tester,
  ) async {
    final center = await host(tester, _template(multiple: true));
    final field = find.byKey(const ValueKey('app-config-main-service'));
    expect(field, findsOneWidget);
    final dropdown = find.descendant(
      of: field,
      matching: find.byType(DropdownButton<String>),
    );
    expect(tester.widget<DropdownButton<String>>(dropdown).value, isNull);
    await next(tester);
    expect(center.prepared, isNull);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('db').last);
    await tester.pumpAndSettle();
    await next(tester);
    expect(center.prepared!.mainService, 'db');
    expect(
      ApplicationComposeService.containerNames(
        center.template,
        center.prepared!,
      ),
      {'web': 'fixture-web', 'db': 'fixture'},
    );
  });

  testWidgets(
    'template main service is preselected consistently with preview',
    (tester) async {
      final center = await host(tester, _template(multiple: true, main: 'db'));
      expect(find.text('db: fixture'), findsOneWidget);
      expect(find.text('web: fixture-web'), findsOneWidget);
      await next(tester);
      expect(center.prepared!.mainService, 'db');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy display name is not silently converted to container naming',
    (tester) async {
      final center = await host(
        tester,
        _template(multiple: true),
        config: const ApplicationConfiguration(
          name: 'Legacy readable name',
          dataRoot: '/home/dev/legacy',
        ),
      );
      expect(
        find.byKey(const ValueKey('app-config-main-service')),
        findsNothing,
      );
      await next(tester);
      expect(center.prepared!.instanceContainerNames, isFalse);
      expect(center.prepared!.name, 'Legacy readable name');
      expect(tester.takeException(), isNull);
    },
  );
}
