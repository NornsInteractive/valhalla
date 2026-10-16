import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/in_memory_app_settings.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/core/services/remote_browser_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/app_center/widgets/app_operation_wizard_dialog.dart';
import 'package:valhalla/features/files/widgets/sftp_directory_picker_dialog.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_dialog.dart';
import '../support/application_center_fakes.dart';
import '../support/application_paths_fixture.dart';

Future<void> _settle(WidgetTester tester) async {
  // Source cancellation also completes futures owned by the real provider zone.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class _Files implements SftpOperations {
  final calls = <String>[];
  Object? openError;
  late Future<List<SftpFileItem>> Function(String) onList;
  int writes = 0;
  @override
  Future<List<SftpFileItem>> listFiles(String path) {
    calls.add(path);
    return onList(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    writes++;
    throw UnsupportedError('${invocation.memberName}');
  }
}

/// Keep the real source/list adapter while replacing only the live SSH lookup.
class _BrowserFactory extends RemoteBrowserFactory {
  final _Files files;
  final List<RemoteBrowserSource> sources;

  _BrowserFactory(super.ref, this.files, this.sources);

  @override
  RemoteBrowserSource host({
    required String initialPath,
    bool Function()? isCurrent,
  }) {
    if (files.openError case final error?) throw error;
    final server = ref.read(activeServerProvider)!;
    final source = sftpRemoteBrowser(
      operations: files,
      targetKey: '${server.connectionKey}',
      label: server.name,
      initialPath: initialPath,
      isCurrent: () =>
          ref.mounted &&
          (isCurrent?.call() ?? true) &&
          ref.read(activeServerProvider)?.connectionKey ==
              server.connectionKey &&
          ref.read(serverConnectionProvider).isConnected,
    );
    sources.add(source);
    return source;
  }
}

class _Connected extends CenterConnection {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _Center extends ApplicationCenterNotifier {
  Map<String, dynamic>? composed;
  ApplicationConfiguration? preparedConfiguration;
  int prepared = 0;
  @override
  ApplicationCenterState build() =>
      ApplicationCenterState(environment: centerEnvironment());
  @override
  Future<ApplicationEnvironment> inspectEnvironment({
    String? sudoPassword,
  }) async => state.environment!;
  @override
  Future<ApplicationTemplate> loadTemplate(
    CatalogApplication application,
  ) async => nginxProxyTemplate;
  @override
  Future<ApplicationOperationPlan> prepare(
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    // Do not stub away the path validation that failed in the actual wizard.
    preparedConfiguration = configuration;
    composed =
        jsonDecode(
              ApplicationComposeService.build(
                template!,
                configuration!,
                configuration.variables['AppID']!,
                'fixture',
              ),
            )
            as Map<String, dynamic>;
    prepared++;
    return CenterDeploymentService().prepare(
      centerServer,
      centerEnvironment(),
      operation,
      template: template,
      configuration: configuration,
      uninstallSelection: uninstallSelection,
    );
  }
}

void main() {
  late _Files files;
  late _Connected connection;
  late CenterActiveServer active;
  late _Center center;
  late List<RemoteBrowserSource> sources;
  String? result;
  setUp(() {
    files = _Files();
    connection = _Connected();
    active = CenterActiveServer();
    center = _Center();
    sources = [];
    result = 'not closed';
  });

  Future<void> host(
    WidgetTester tester, {
    bool wizard = false,
    String path = '/home/dev/missing/app',
    Set<String> restricted = const {},
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(InMemoryAppSettings.new),
          activeServerProvider.overrideWith(() => active),
          serverConnectionProvider.overrideWith(() => connection),
          remoteBrowserFactoryProvider.overrideWith(
            (ref) => _BrowserFactory(ref, files, sources),
          ),
          applicationCenterProvider.overrideWith(() => center),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  if (wizard) {
                    await AppOperationWizardDialog.show(
                      context,
                      operation: ApplicationOperation.install,
                      catalogApp: nginxProxyTemplate.application,
                    );
                  } else {
                    result = await SftpDirectoryPickerDialog.show(
                      context,
                      initialPath: path,
                      title: 'Browse',
                      restrictedPaths: restricted,
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
  }

  FilledButton select(WidgetTester tester) => tester.widget<FilledButton>(
    find.byKey(const Key('remote_browser_confirm_button')),
  );
  String input(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets(
    'failed host lease shows an error without opening a stale picker',
    (tester) async {
      files.openError = StateError('REMOTE_BROWSER_DISCONNECTED');
      await host(tester);
      await _settle(tester);
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      expect(find.text('An error occurred'), findsOneWidget);
      expect(result, isNull);
      expect(files.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mount in [false, true]) {
    testWidgets(
      'wizard ${mount ? 'mount' : 'data root'} lease failure preserves form',
      (tester) async {
        files.openError = StateError('REMOTE_BROWSER_DISCONNECTED');
        await host(tester, wizard: true);
        await _settle(tester);
        final root = input(tester, 'app-config-data-root');
        const mountKey = 'mount-nginxproxymanager:/data';
        final originalMount = input(tester, mountKey);
        final browse = find.byTooltip('Browse Directory').at(mount ? 1 : 0);
        await tester.ensureVisible(browse);
        await tester.tap(browse);
        await _settle(tester);
        expect(find.byType(RemoteBrowserDialog), findsNothing);
        expect(find.text('An error occurred'), findsOneWidget);
        expect(input(tester, 'app-config-data-root'), root);
        expect(input(tester, mountKey), originalMount);
        expect(center.prepared, 0);
        expect(files.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing initial path walks ancestors; selection returns existing directory',
    (tester) async {
      files.onList = (path) async {
        if (path == '/home/dev') return [];
        throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
      };
      await host(tester);
      await _settle(tester);
      expect(files.calls, [
        '/home/dev/missing/app',
        '/home/dev/missing',
        '/home/dev',
      ]);
      expect(find.text('/home/dev'), findsOneWidget);
      expect(select(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
      await _settle(tester);
      expect(result, '/home/dev');
      expect(files.writes, 0);
      expect(sources.single.isCurrent, isFalse);
    },
  );

  for (final code in [
    SftpStatusCode.permissionDenied,
    SftpStatusCode.connectionLost,
  ]) {
    testWidgets('SFTP error $code is not hidden by parent fallback', (
      tester,
    ) async {
      files.onList = (_) async => throw SftpStatusError(code, 'test');
      await host(tester);
      await _settle(tester);
      expect(files.calls, ['/home/dev/missing/app']);
      expect(select(tester).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(result, isNull);
      expect(files.writes, 0);
    });
  }

  testWidgets('unlisted pending directory cannot be confirmed', (tester) async {
    final pending = Completer<List<SftpFileItem>>();
    files.onList = (_) => pending.future;
    await host(tester, path: '/home/dev');
    await tester.pump(const Duration(milliseconds: 300));
    expect(select(tester).onPressed, isNull);
    pending.complete([]);
    await _settle(tester);
    expect(select(tester).onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(result, isNull);
    expect(sources.single.isCurrent, isFalse);
  });

  testWidgets(
    'normal navigation missing target does not silently choose parent',
    (tester) async {
      files.onList = (path) async {
        if (path == '/home/dev') {
          return [
            const SftpFileItem(
              name: 'gone',
              path: '/home/dev/gone',
              isDirectory: true,
              sizeBytes: 0,
              formattedSize: '-',
              permissions: '',
              modified: '',
            ),
          ];
        }
        throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
      };
      await host(tester, path: '/home/dev');
      await _settle(tester);
      await tester.tap(find.text('gone'));
      await _settle(tester);
      expect(files.calls, ['/home/dev', '/home/dev/gone']);
      expect(find.text('/home/dev/gone'), findsOneWidget);
      expect(select(tester).onPressed, isNull);
      expect(files.writes, 0);
    },
  );

  testWidgets('root missing terminates without enabling selection', (
    tester,
  ) async {
    files.onList = (_) async =>
        throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
    await host(tester, path: '/absent');
    await _settle(tester);
    expect(files.calls, ['/absent', '/']);
    expect(select(tester).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
  });

  for (final restricted in ['/home', '/home/dev', '/home/dev/']) {
    testWidgets('restricted ancestor $restricted cannot be chosen', (
      tester,
    ) async {
      files.onList = (_) async => [];
      await host(tester, path: '/home/dev', restricted: {restricted});
      await _settle(tester);
      expect(select(tester).onPressed, isNull);
    });
  }

  for (final changeServer in [true, false]) {
    testWidgets(
      'pending listing cannot apply after ${changeServer ? 'server switch' : 'disconnect'}',
      (tester) async {
        final pending = Completer<List<SftpFileItem>>();
        files.onList = (_) => pending.future;
        await host(tester);
        if (changeServer) {
          active.select(
            const ServerProfile(
              id: 'other',
              name: 'Other',
              host: 'other.invalid',
              username: 'dev',
            ),
          );
        } else {
          connection.setConnected(false);
        }
        await tester.pump();
        expect(select(tester).onPressed, isNull);
        pending.completeError(
          SftpStatusError(SftpStatusCode.noSuchFile, 'late'),
        );
        await _settle(tester);
        expect(find.byType(RemoteBrowserDialog), findsNothing);
        expect(files.calls, ['/home/dev/missing/app']);
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Nginx wizard cancel preserves paths, variable change and trailing root reach review',
    (tester) async {
      files.onList = (path) async {
        if (path == '/home/dev') return [];
        throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
      };
      await host(tester, wizard: true);
      await _settle(tester);
      final original = input(tester, 'app-config-data-root');
      final browse = find.byTooltip('Browse Directory').first;
      await tester.ensureVisible(browse);
      await tester.tap(browse);
      await _settle(tester);
      expect(find.text('/home/dev'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(RemoteBrowserDialog),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await _settle(tester);
      expect(input(tester, 'app-config-data-root'), original);
      await tester.tap(browse);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
      await _settle(tester);
      final selected = '/home/dev/${original.split('/').last}';
      expect(input(tester, 'app-config-data-root'), selected);
      final root = find.byKey(const ValueKey('app-config-data-root'));
      await tester.ensureVisible(root);
      await tester.enterText(root, '$selected/');
      final tz = find.byKey(const ValueKey('var-TZ'));
      await tester.ensureVisible(tz);
      await tester.enterText(tz, 'Asia/Shanghai');
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.tap(find.byType(ChoiceChip).first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await _settle(tester);
      expect(center.prepared, 1);
      expect(find.text('Execute Plan'), findsOneWidget);
      final mounts =
          center.composed!['services']['nginxproxymanager']['volumes'] as List;
      expect(mounts.map((m) => m['source']), [
        '$selected/data',
        '$selected/etc/letsencrypt',
      ]);
      expect(center.preparedConfiguration!.variables['TZ'], 'Asia/Shanghai');
      expect(sources, hasLength(2));
      expect(sources.every((source) => !source.isCurrent), isTrue);
      expect(files.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Nginx mount picker cancel preserves every form path', (
    tester,
  ) async {
    files.onList = (_) async => [];
    await host(tester, wizard: true);
    await _settle(tester);
    final originalRoot = input(tester, 'app-config-data-root');
    final firstKey = 'mount-nginxproxymanager:/data';
    final secondKey = 'mount-nginxproxymanager:/etc/letsencrypt';
    final originalFirst = input(tester, firstKey);
    final originalSecond = input(tester, secondKey);
    final browse = find.byTooltip('Browse Directory').at(1);
    await tester.ensureVisible(browse);
    await tester.tap(browse);
    await _settle(tester);
    expect(files.calls, [originalFirst]);
    await tester.tap(
      find.descendant(
        of: find.byType(RemoteBrowserDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await _settle(tester);
    expect(input(tester, 'app-config-data-root'), originalRoot);
    expect(input(tester, firstKey), originalFirst);
    expect(input(tester, secondKey), originalSecond);
    expect(sources.single.isCurrent, isFalse);
    expect(files.writes, 0);
    expect(center.prepared, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nginx mount selection changes only that mount', (tester) async {
    const chosen = '/srv/shared-data';
    files.onList = (path) async {
      if (path == chosen) return [];
      return [
        const SftpFileItem(
          name: 'shared-data',
          path: chosen,
          isDirectory: true,
          sizeBytes: 0,
          formattedSize: '-',
          permissions: '',
          modified: '',
        ),
      ];
    };
    await host(tester, wizard: true);
    await _settle(tester);
    final originalRoot = input(tester, 'app-config-data-root');
    final firstKey = 'mount-nginxproxymanager:/data';
    final secondKey = 'mount-nginxproxymanager:/etc/letsencrypt';
    final originalSecond = input(tester, secondKey);
    final browse = find.byTooltip('Browse Directory').at(1);
    await tester.ensureVisible(browse);
    await tester.tap(browse);
    await _settle(tester);
    await tester.tap(find.text('shared-data'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
    await _settle(tester);
    expect(input(tester, 'app-config-data-root'), originalRoot);
    expect(input(tester, firstKey), chosen);
    expect(input(tester, secondKey), originalSecond);
    expect(sources.single.isCurrent, isFalse);
    expect(files.writes, 0);
    expect(center.prepared, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nginx untouched default directories reach review', (
    tester,
  ) async {
    files.onList = (_) async =>
        throw StateError('Should not browse automatically');
    await host(tester, wizard: true);
    await _settle(tester);
    await tester.ensureVisible(find.byType(ChoiceChip).first);
    await tester.tap(find.byType(ChoiceChip).first);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await _settle(tester);
    expect(center.prepared, 1);
    expect(find.text('Execute Plan'), findsOneWidget);
    expect(files.calls, isEmpty);
    expect(files.writes, 0);
  });
}
