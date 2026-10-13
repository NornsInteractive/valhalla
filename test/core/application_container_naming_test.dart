import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';

import '../support/application_center_fakes.dart';

void main() {
  final id = 'a' * 32;
  final project = 'valhalla-app-$id';
  ApplicationTemplate template({
    bool multi = false,
    String? main,
    Map<String, dynamic> web = const {},
  }) => ApplicationTemplate(
    application: centerApp,
    compose: {
      'services': {
        'web': {
          'image': 'nginx:alpine',
          'container_name': 'template-web',
          'ports': ['18080:80'],
          'labels': {'custom': 'preserved'},
          'networks': {
            'default': {
              'aliases': ['original-alias'],
            },
          },
          ...web,
        },
        if (multi)
          'db': {
            'image': 'postgres:alpine',
            'ports': ['15432:5432'],
          },
      },
      if (main != null) 'x-casaos': {'main': main, 'port_map': 80},
    },
    metadata: const {},
  );
  ApplicationConfiguration defaults(ApplicationTemplate value) =>
      ApplicationComposeService.defaults(value, centerEnvironment(), id);
  Map<String, dynamic> build(
    ApplicationTemplate value,
    ApplicationConfiguration config,
  ) =>
      jsonDecode(ApplicationComposeService.build(value, config, id, project))
          as Map<String, dynamic>;
  Matcher error(String code) => throwsA(
    isA<ApplicationCenterException>().having(
      (value) => value.code,
      'code',
      code,
    ),
  );

  test(
    'new defaults use legal catalog id and one exact main container name',
    () {
      final value = template();
      final config = defaults(value);
      expect(config.instanceContainerNames, true);
      expect(config.name, centerApp.id);
      expect(config.mainService, 'web');
      expect(ApplicationComposeService.serviceNames(value), ['web']);
      expect(ApplicationComposeService.suggestedMainService(value), 'web');
      expect(
        build(value, config)['services']['web']['container_name'],
        config.name,
      );
      expect(build(value, config)['name'], project);
    },
  );

  test(
    'multi main and sidecar names preserve project, labels, aliases and ports',
    () {
      final value = template(multi: true, main: 'web');
      final config = defaults(value).copyWith(name: 'Norns-Proxy_1.2');
      final rendered = build(value, config);
      final web = rendered['services']['web'] as Map;
      expect(ApplicationComposeService.containerNames(value, config), {
        'web': 'Norns-Proxy_1.2',
        'db': 'Norns-Proxy_1.2-db',
      });
      expect(
        rendered['services']['db']['container_name'],
        'Norns-Proxy_1.2-db',
      );
      expect(
        web['networks']['default']['aliases'],
        containsAll(['template-web', 'original-alias']),
      );
      expect(web['labels'], {
        'custom': 'preserved',
        'com.valhalla.app.instance': id,
      });
      expect(web['ports'].single['published'], '18080');
      expect(web['ports'].single['host_ip'], '127.0.0.1');
      expect(rendered['name'], project);
      expect(rendered.containsKey('x-casaos'), false);
    },
  );

  for (final declared in [null, 'missing-service']) {
    test(
      'multi without valid declared main $declared requires explicit selection',
      () {
        final value = template(multi: true, main: declared);
        final config = defaults(value);
        expect(config.mainService, isNull);
        expect(ApplicationComposeService.suggestedMainService(value), isNull);
        expect(
          () => build(value, config),
          error('APP_CENTER_MAIN_SERVICE_REQUIRED'),
        );
        final chosen = config.copyWith(mainService: 'db');
        expect(
          build(value, chosen)['services']['db']['container_name'],
          chosen.name,
        );
        expect(ApplicationComposeService.webPort(value, chosen)!.service, 'db');
        expect(ApplicationComposeService.webPort(value, chosen)!.target, 5432);
      },
    );
  }

  test(
    'new metadata survives JSON, path canonicalization and variable updates',
    () {
      final value = template(multi: true, main: 'web');
      final original = defaults(
        value,
      ).copyWith(mainService: 'db', name: 'explicit-instance');
      final restored = ApplicationConfiguration.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      final copied = ApplicationComposeService.canonicalDirectoryPaths(
        restored.copyWith(dataRoot: '${restored.dataRoot}/'),
      );
      final merged = ApplicationComposeService.mergeDefaults(
        value,
        centerEnvironment(),
        id,
        copied,
      );
      final updated = ApplicationComposeService.changeVariables(
        value,
        centerEnvironment(),
        id,
        merged,
        {'TZ': 'UTC'},
      );
      for (final config in [restored, copied, merged, updated]) {
        expect(config.instanceContainerNames, true);
        expect(config.mainService, 'db');
        expect(config.name, 'explicit-instance');
        expect(
          build(value, config)['services']['db']['container_name'],
          'explicit-instance',
        );
      }
    },
  );

  test(
    'old JSON remains legacy through defaults merge and permits old display names',
    () {
      final value = template(multi: true, main: 'web');
      final json = defaults(value).toJson()
        ..remove('instanceContainerNames')
        ..remove('mainService')
        ..['name'] = '旧实例 Display Name';
      final legacy = ApplicationConfiguration.fromJson(json);
      final merged = ApplicationComposeService.mergeDefaults(
        value,
        centerEnvironment(),
        id,
        legacy,
      );
      expect(legacy.instanceContainerNames, false);
      expect(legacy.mainService, isNull);
      expect(merged.instanceContainerNames, false);
      expect(ApplicationComposeService.containerNames(value, merged), isEmpty);
      final rendered = build(value, merged);
      for (final service in (rendered['services'] as Map).values) {
        expect((service as Map).containsKey('container_name'), false);
      }
      expect(ApplicationComposeService.webPort(value, merged)!.service, 'web');
      expect(merged.toJson().containsKey('instanceContainerNames'), false);
    },
  );

  for (final name in [
    'bad name',
    '中文',
    '_first',
    '.first',
    'bad\n',
    r'$(touch owned)',
    'x' * 121,
  ]) {
    test(
      'reject user instance name ${jsonEncode(name)} without sanitizing',
      () {
        final value = template();
        final config = defaults(value).copyWith(name: name);
        expect(ApplicationComposeService.isValidContainerName(name), false);
        expect(
          () => ApplicationComposeService.containerNames(value, config),
          error('APP_CENTER_CONTAINER_NAME_INVALID'),
        );
        expect(config.name, name);
      },
    );
  }

  for (final service in <Map<String, dynamic>>[
    {
      'deploy': {'replicas': 2},
    },
    {'scale': 3},
    {
      'deploy': {'mode': 'global'},
    },
  ]) {
    test('explicit container names reject scaling ${jsonEncode(service)}', () {
      final value = template(web: service);
      expect(
        () => build(value, defaults(value)),
        error('APP_CENTER_CONTAINER_REPLICAS_UNSUPPORTED'),
      );
    });
  }

  test(
    'single explicit replica and legacy replicated template stay supported',
    () {
      final single = template(
        web: {
          'deploy': {'mode': 'replicated', 'replicas': 1},
        },
      );
      expect(
        build(single, defaults(single))['services']['web']['container_name'],
        centerApp.id,
      );
      final scaled = template(
        web: {
          'deploy': {'replicas': 2},
        },
      );
      expect(
        build(
          scaled,
          defaults(scaled).copyWith(instanceContainerNames: false),
        )['services']['web'].containsKey('container_name'),
        false,
      );
    },
  );
}
