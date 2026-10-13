import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';

import '../support/application_center_fakes.dart';

void main() {
  group('ApplicationPort', () {
    test('fromJson parses optional bindAddress when present', () {
      final json = {
        'service': 'web',
        'target': 80,
        'published': 8080,
        'protocol': 'tcp',
        'bindAddress': '192.168.1.100',
      };
      final port = ApplicationPort.fromJson(json);
      expect(port.service, 'web');
      expect(port.target, 80);
      expect(port.published, 8080);
      expect(port.protocol, 'tcp');
      expect(port.bindAddress, '192.168.1.100');
    });

    test('fromJson handles missing bindAddress (old JSON compatibility)', () {
      final json = {
        'service': 'web',
        'target': 80,
        'published': 8080,
        'protocol': 'tcp',
      };
      final port = ApplicationPort.fromJson(json);
      expect(port.bindAddress, isNull);
    });

    test('fromJson defaults protocol to tcp when missing', () {
      final json = {'service': 'web', 'target': 80, 'published': 8080};
      final port = ApplicationPort.fromJson(json);
      expect(port.protocol, 'tcp');
    });

    test('toJson includes bindAddress when set', () {
      final port = ApplicationPort(
        service: 'web',
        target: 80,
        published: 8080,
        bindAddress: '192.168.1.100',
      );
      final json = port.toJson();
      expect(json['bindAddress'], '192.168.1.100');
    });

    test('toJson omits bindAddress when null', () {
      final port = ApplicationPort(service: 'web', target: 80, published: 8080);
      final json = port.toJson();
      expect(json.containsKey('bindAddress'), isFalse);
    });

    test(
      'effectiveBindAddress uses port bindAddress over application bindAddress',
      () {
        final port = ApplicationPort(
          service: 'web',
          target: 80,
          published: 8080,
          bindAddress: '10.0.0.1',
        );
        expect(port.effectiveBindAddress('127.0.0.1'), '10.0.0.1');
      },
    );

    test(
      'effectiveBindAddress falls back to application bindAddress when null',
      () {
        final port = ApplicationPort(
          service: 'web',
          target: 80,
          published: 8080,
        );
        expect(port.effectiveBindAddress('127.0.0.1'), '127.0.0.1');
      },
    );

    test('roundtrip preserves all fields including bindAddress', () {
      final original = ApplicationPort(
        service: 'ssh',
        target: 22,
        published: 2222,
        protocol: 'tcp',
        bindAddress: '0.0.0.0',
      );
      final json = original.toJson();
      final restored = ApplicationPort.fromJson(json);
      expect(restored.service, original.service);
      expect(restored.target, original.target);
      expect(restored.published, original.published);
      expect(restored.protocol, original.protocol);
      expect(restored.bindAddress, original.bindAddress);
    });

    test('mixed external 80/443 + SSH-only 81 ports', () {
      final ports = [
        ApplicationPort(service: 'web', target: 80, published: 8080),
        ApplicationPort(
          service: 'web',
          target: 443,
          published: 8443,
          protocol: 'tcp',
        ),
        ApplicationPort(
          service: 'ssh',
          target: 22,
          published: 2222,
          bindAddress: '127.0.0.1',
        ),
      ];
      expect(ports.length, 3);
      expect(ports.where((p) => p.service == 'web').length, 2);
      expect(ports.where((p) => p.service == 'ssh').length, 1);
      expect(
        ports.singleWhere((p) => p.service == 'ssh').bindAddress,
        '127.0.0.1',
      );
    });

    test('bad bindAddress values are rejected in fromJson', () {
      final json = {
        'service': 'web',
        'target': 80,
        'published': 8080,
        'bindAddress': 123,
      };
      expect(() => ApplicationPort.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('bad target/published values are rejected in fromJson', () {
      final json = {
        'service': 'web',
        'target': 'not-an-int',
        'published': 8080,
      };
      expect(() => ApplicationPort.fromJson(json), throwsA(isA<TypeError>()));
    });

    test(
      'ApplicationConfiguration.fromJson preserves ports with bindAddress',
      () {
        final json = {
          'name': 'test',
          'dataRoot': '/data',
          'bindAddress': '127.0.0.1',
          'ports': [
            {
              'service': 'web',
              'target': 80,
              'published': 8080,
              'bindAddress': '0.0.0.0',
            },
            {
              'service': 'ssh',
              'target': 22,
              'published': 2222,
              'protocol': 'tcp',
            },
          ],
          'mounts': [],
          'variables': {},
          'environment': {},
        };
        final config = ApplicationConfiguration.fromJson(json);
        expect(config.ports.length, 2);
        expect(config.ports.first.bindAddress, '0.0.0.0');
        expect(config.ports.last.bindAddress, isNull);
      },
    );
  });

  group('ApplicationComposeService.webPort', () {
    ApplicationTemplate makeTemplate({String main = 'web', int? portMap}) {
      final compose = {
        'services': {
          'web': {
            'image': 'nginx',
            'ports': ['80'],
          },
          'ssh': {
            'image': 'ssh',
            'ports': ['22'],
          },
        },
        'x-casaos': {'main': main},
      };
      if (portMap != null) {
        (compose['x-casaos'] as Map)['port_map'] = portMap.toString();
      }
      return ApplicationTemplate(
        application: CatalogApplication(
          sourceId: 'test',
          id: 'app',
          title: 'App',
          composeUrl: '',
          metadataUrl: '',
          contentHash: '',
        ),
        compose: compose,
        metadata: {},
      );
    }

    ApplicationConfiguration makeConfig({
      List<ApplicationPort>? ports,
      String bindAddress = '127.0.0.1',
    }) {
      return ApplicationConfiguration(
        name: 'test',
        dataRoot: '/data',
        bindAddress: bindAddress,
        ports:
            ports ??
            [
              ApplicationPort(service: 'web', target: 80, published: 8080),
              ApplicationPort(service: 'ssh', target: 22, published: 2222),
            ],
        mounts: [],
        variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
        environment: {},
      );
    }

    test('prioritizes target matching port_map over published', () {
      final template = makeTemplate(portMap: 81);
      final config = makeConfig(
        ports: [
          ApplicationPort(service: 'web', target: 80, published: 81),
          ApplicationPort(service: 'web', target: 81, published: 8181),
        ],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNotNull);
      expect(port!.target, 81);
      expect(port.published, 8181);
    });

    test('falls back to published matching port_map when no target match', () {
      final template = makeTemplate(portMap: 8080);
      final config = makeConfig(
        ports: [
          ApplicationPort(service: 'web', target: 80, published: 8080),
          ApplicationPort(service: 'web', target: 81, published: 8181),
        ],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNotNull);
      expect(port!.target, 80);
      expect(port.published, 8080);
    });

    test('falls back to first port when no port_map match', () {
      final template = makeTemplate();
      final config = makeConfig(
        ports: [
          ApplicationPort(service: 'web', target: 80, published: 8080),
          ApplicationPort(service: 'web', target: 81, published: 8181),
        ],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNotNull);
      expect(port!.target, 80);
      expect(port.published, 8080);
    });

    test('filters by service name from x-casaos.main', () {
      final template = makeTemplate(main: 'ssh');
      final config = makeConfig(
        ports: [
          ApplicationPort(service: 'web', target: 80, published: 8080),
          ApplicationPort(service: 'ssh', target: 22, published: 2222),
        ],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNotNull);
      expect(port!.service, 'ssh');
      expect(port.target, 22);
    });

    test('returns null when no matching service ports', () {
      final template = makeTemplate(main: 'api');
      final config = makeConfig(
        ports: [ApplicationPort(service: 'web', target: 80, published: 8080)],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNull);
    });

    test('ignores non-tcp protocols', () {
      final template = makeTemplate();
      final config = makeConfig(
        ports: [
          ApplicationPort(
            service: 'web',
            target: 80,
            published: 8080,
            protocol: 'udp',
          ),
          ApplicationPort(
            service: 'web',
            target: 80,
            published: 8081,
            protocol: 'tcp',
          ),
        ],
      );
      final port = ApplicationComposeService.webPort(template, config);
      expect(port, isNotNull);
      expect(port!.protocol, 'tcp');
      expect(port.published, 8081);
    });
  });

  group('ApplicationComposeService.mergeDefaults', () {
    ApplicationTemplate makeTemplate() {
      return ApplicationTemplate(
        application: CatalogApplication(
          sourceId: 'test',
          id: 'app',
          title: 'App',
          composeUrl: '',
          metadataUrl: '',
          contentHash: '',
        ),
        compose: {
          'services': {
            'web': {
              'image': 'nginx',
              'ports': ['80'],
              'environment': {'TOKEN': '\${PASSWORD}'},
            },
          },
        },
        metadata: {},
        variables: {'PASSWORD'},
      );
    }

    ApplicationEnvironment makeEnvironment() => ApplicationEnvironment(
      serverId: 's',
      serverKey: 'k',
      home: '/home',
      os: 'linux',
      osVersion: '1',
      architecture: 'arm64',
      targetIdentity: 'id',
      uid: 1000,
      gid: 1000,
      dockerAvailable: true,
      composeAvailable: true,
      useSudo: false,
      canBootstrap: true,
    );

    test('mergeDefaults retains explicit bindAddress override', () {
      final current = ApplicationConfiguration(
        name: 'test',
        dataRoot: '/data',
        bindAddress: '192.168.1.100',
        ports: [
          ApplicationPort(
            service: 'web',
            target: 80,
            published: 8080,
            bindAddress: '10.0.0.1',
          ),
        ],
        mounts: [],
        variables: {'PASSWORD': 'secret'},
        environment: {},
      );
      final merged = ApplicationComposeService.mergeDefaults(
        makeTemplate(),
        makeEnvironment(),
        'inst',
        current,
      );
      expect(merged.bindAddress, '192.168.1.100');
      expect(merged.ports.first.bindAddress, '10.0.0.1');
    });

    test(
      'mergeDefaults retains explicit port bindAddress when config has none',
      () {
        final current = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          ports: [
            ApplicationPort(
              service: 'web',
              target: 80,
              published: 8080,
              bindAddress: '10.0.0.1',
            ),
          ],
          mounts: [],
          variables: {'PASSWORD': 'secret'},
          environment: {},
        );
        final merged = ApplicationComposeService.mergeDefaults(
          makeTemplate(),
          makeEnvironment(),
          'inst',
          current,
        );
        expect(merged.ports.first.bindAddress, '10.0.0.1');
      },
    );
  });

  group('ApplicationComposeService.changeVariables', () {
    ApplicationTemplate makeTemplate() {
      return ApplicationTemplate(
        application: CatalogApplication(
          sourceId: 'test',
          id: 'app',
          title: 'App',
          composeUrl: '',
          metadataUrl: '',
          contentHash: '',
        ),
        compose: {
          'services': {
            'web': {
              'image': 'nginx',
              'ports': ['80'],
              'environment': {
                'AUTO_VAR': '\${PASSWORD}',
                'EXPLICIT_VAR': 'explicit-value',
              },
            },
          },
        },
        metadata: {},
        variables: {'PASSWORD'},
      );
    }

    ApplicationEnvironment makeEnvironment() => ApplicationEnvironment(
      serverId: 's',
      serverKey: 'k',
      home: '/home',
      os: 'linux',
      osVersion: '1',
      architecture: 'arm64',
      targetIdentity: 'id',
      uid: 1000,
      gid: 1000,
      dockerAvailable: true,
      composeAvailable: true,
      useSudo: false,
      canBootstrap: true,
    );

    test(
      'changeVariables updates automatic env while preserving explicit override and bindAddress',
      () {
        final current = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          ports: [
            ApplicationPort(
              service: 'web',
              target: 80,
              published: 8080,
              bindAddress: '10.0.0.1',
            ),
          ],
          variables: {'PASSWORD': 'oldPASSWORD'},
          environment: {
            'web': {
              'AUTO_VAR': 'oldPASSWORD',
              'EXPLICIT_VAR': 'user-overridden',
            },
          },
        );
        final updated = ApplicationComposeService.changeVariables(
          makeTemplate(),
          makeEnvironment(),
          'inst',
          current,
          {'PASSWORD': 'newPASSWORD'},
        );
        expect(updated.variables['PASSWORD'], 'newPASSWORD');
        expect(updated.environment['web']!['AUTO_VAR'], 'newPASSWORD');
        expect(updated.environment['web']!['EXPLICIT_VAR'], 'user-overridden');
        expect(updated.ports.first.bindAddress, '10.0.0.1');
      },
    );
  });

  group('rendered port access boundaries', () {
    final template = ApplicationTemplate(
      application: centerApp,
      compose: {
        'services': {
          'web': {
            'image': 'nginx',
            'ports': ['80:80', '443:443', '81:81'],
          },
        },
        'x-casaos': {'main': 'web', 'port_map': 81},
      },
      metadata: const {},
    );
    ApplicationConfiguration configuration(String? adminAddress) =>
        ApplicationConfiguration(
          name: 'Nginx',
          dataRoot: '/data/app/',
          bindAddress: '0.0.0.0',
          ports: [
            const ApplicationPort(service: 'web', target: 80, published: 18080),
            const ApplicationPort(
              service: 'web',
              target: 443,
              published: 18443,
            ),
            ApplicationPort(
              service: 'web',
              target: 81,
              published: 18081,
              bindAddress: adminAddress,
            ),
          ],
        );

    test(
      'renders public proxy ports with explicitly loopback admin, preserves SSH URL',
      () {
        final config = configuration('127.0.0.1');
        final compose =
            jsonDecode(
                  ApplicationComposeService.build(
                    template,
                    config,
                    'app',
                    'project',
                  ),
                )
                as Map;
        final ports = compose['services']['web']['ports'] as List;
        expect(ports.map((p) => p['host_ip']), [
          '0.0.0.0',
          '0.0.0.0',
          '127.0.0.1',
        ]);
        expect(ports.map((p) => p['published']), ['18080', '18443', '18081']);
        expect(
          ApplicationComposeService.endpoint(template, config).toString(),
          'http://127.0.0.1:18081/',
        );
        expect(
          ApplicationComposeService.canonicalDirectoryPaths(
            config,
          ).ports.last.bindAddress,
          '127.0.0.1',
        );
      },
    );

    test(
      'inherited null override follows application scope without becoming explicit',
      () {
        final config = configuration(null);
        final compose =
            jsonDecode(
                  ApplicationComposeService.build(
                    template,
                    config,
                    'app',
                    'project',
                  ),
                )
                as Map;
        expect(compose['services']['web']['ports'][2]['host_ip'], '0.0.0.0');
        expect(config.ports.last.toJson().containsKey('bindAddress'), false);
      },
    );

    for (final invalid in ['', '::', 'localhost', '192.0.2.1']) {
      test(
        'rejects unsupported explicit bindAddress "$invalid" at rendering boundary',
        () {
          expect(
            () => ApplicationComposeService.build(
              template,
              configuration(invalid),
              'app',
              'project',
            ),
            throwsA(
              isA<ApplicationCenterException>().having(
                (e) => e.code,
                'code',
                'APP_CENTER_PORT_INVALID',
              ),
            ),
          );
        },
      );
    }

    test(
      'variable-derived published port change preserves explicit admin binding',
      () {
        final variableTemplate = ApplicationTemplate(
          application: centerApp,
          compose: {
            'services': {
              'web': {
                'image': 'nginx',
                'ports': [r'${WEB_PORT}:81'],
              },
            },
          },
          metadata: const {},
          variables: const {'WEB_PORT'},
        );
        final before =
            ApplicationComposeService.defaults(
              variableTemplate,
              centerEnvironment(),
              'app',
              variables: {'WEB_PORT': '18081'},
            ).copyWith(
              ports: const [
                ApplicationPort(
                  service: 'web',
                  target: 81,
                  published: 18081,
                  bindAddress: '0.0.0.0',
                ),
              ],
            );
        final after = ApplicationComposeService.changeVariables(
          variableTemplate,
          centerEnvironment(),
          'app',
          before,
          {...before.variables, 'WEB_PORT': '28081'},
        );
        expect(after.ports.single.published, 28081);
        expect(after.ports.single.bindAddress, '0.0.0.0');
        final compose =
            jsonDecode(
                  ApplicationComposeService.build(
                    variableTemplate,
                    after,
                    'app',
                    'project',
                  ),
                )
                as Map;
        expect(compose['services']['web']['ports'][0]['host_ip'], '0.0.0.0');
      },
    );
  });
}
