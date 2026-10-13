import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';

void main() {
  group('ApplicationComposeService', () {
    final validTemplate = _validTemplate();
    final validEnv = _validEnv();
    final validConfig = _validConfig();

    test('parse exceeds depth limit throws', () {
      final yaml = '''
services:
  svc:
    image: nginx
    level0:
      level1:
        level2:
          level3:
            level4:
              level5:
                level6:
                  level7:
                    level8:
                      level9:
                        level10:
                          level11:
                            level12:
                              level13:
                                level14:
                                  level15:
                                    level16:
                                      level17:
                                        level18:
                                          level19:
                                            level20:
                                              level21:
                                                level22:
                                                  level23:
                                                    level24:
                                                      level25:
                                                        level26:
                                                          level27:
                                                            level28:
                                                              level29: value
''';
      expect(
        () => ApplicationComposeService.parse(yaml),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_TEMPLATE_TOO_LARGE',
          ),
        ),
      );
    });

    test('blocker privileged produces unsupported', () {
      final compose = {
        'services': {
          'svc': {'image': 'nginx', 'privileged': true},
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(blockers, contains('APP_CENTER_TEMPLATE_UNSUPPORTED:privileged'));
    });

    test('blocker devices field produces unsupported', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'devices': ['/dev/fuse:/dev/fuse'],
          },
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(blockers, contains('APP_CENTER_TEMPLATE_UNSUPPORTED:devices'));
    });

    test('blocker host socket docker.sock', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'volumes': ['/var/run/docker.sock:/var/run/docker.sock'],
          },
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(blockers, contains('APP_CENTER_TEMPLATE_UNSUPPORTED:host_mount'));
    });

    test('blocker relative mount tilde', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'volumes': ['~/data:/data'],
          },
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(
        blockers,
        contains('APP_CENTER_TEMPLATE_UNSUPPORTED:relative_host_mount'),
      );
    });

    test('blocker external volume at top level', () {
      final compose = {
        'volumes': {
          'myvol': {'external': true, 'source': 'path'},
        },
        'services': {
          'svc': {'image': 'nginx'},
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(blockers, contains('APP_CENTER_TEMPLATE_UNSUPPORTED:volumes'));
    });

    test('parse expandedUTF8 alias budget1MiB throws on oversized strings', () {
      final largeValue = 'x' * (1024 * 1024 + 1);
      final yaml =
          '''
services:
  svc:
    image: nginx
    environment:
      VAR: "$largeValue"
''';
      expect(
        () => ApplicationComposeService.parse(yaml),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_TEMPLATE_TOO_LARGE',
          ),
        ),
      );
    });

    test('parse original template not mutated during parse', () {
      final yaml = '''
services:
  svc:
    image: nginx
    environment:
      VAR: value
''';
      final before = yaml;
      ApplicationComposeService.parse(yaml);
      expect(yaml, before);
    });

    test('variable resolution extracts variable name with :-', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'environment': {'VAR': '\${MYVAR:-default}'},
          },
        },
      };
      final variables = ApplicationComposeService.variables(compose);
      expect(variables, contains('MYVAR'));
    });

    test('literal dollar escape variables not extracted', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'environment': {'VAR': '\$\$'},
          },
        },
      };
      final variables = ApplicationComposeService.variables(compose);
      expect(variables, isNot(contains('VAR')));
    });

    test('port duplicate published invalid through build', () {
      final template = ApplicationTemplate(
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
            'svc1': {
              'image': 'nginx',
              'ports': ['8080:80'],
            },
            'svc2': {
              'image': 'app',
              'ports': ['8080:8080'],
            },
          },
        },
        metadata: {},
      );
      expect(
        () => ApplicationComposeService.build(
          template,
          validConfig,
          'inst',
          'proj',
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_PORT_INVALID',
          ),
        ),
      );
    });

    test('port invalid number out of range through build', () {
      final template = ApplicationTemplate(
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
            'svc': {
              'image': 'nginx',
              'ports': ['99999:80'],
            },
          },
        },
        metadata: {},
      );
      expect(
        () => ApplicationComposeService.build(
          template,
          validConfig,
          'inst',
          'proj',
        ),
        throwsA(
          isA<ApplicationCenterException>().having(
            (e) => e.code,
            'code',
            'APP_CENTER_PORT_INVALID',
          ),
        ),
      );
    });

    test('named volume not blocked as host mount', () {
      final compose = {
        'services': {
          'svc': {
            'image': 'nginx',
            'volumes': ['myvolume:/data'],
          },
        },
      };
      final blockers = ApplicationComposeService.blockers(compose);
      expect(
        blockers,
        isNot(contains('APP_CENTER_TEMPLATE_UNSUPPORTED:host_mount')),
      );
    });

    test(
      'blocker privileged true stringtrue interpolated blocked false allowed',
      () {
        final blockedCases = [
          {'privileged': true},
          {'privileged': 'true'},
          {'privileged': '\${SOME_VAR}'},
        ];
        for (final privilegedValue in blockedCases) {
          final compose = {
            'services': {
              'svc': {'image': 'nginx', ...privilegedValue},
            },
          };
          final blockers = ApplicationComposeService.blockers(compose);
          expect(
            blockers,
            contains('APP_CENTER_TEMPLATE_UNSUPPORTED:privileged'),
            reason: 'privileged=$privilegedValue should be blocked',
          );
        }
        final allowedCompose = {
          'services': {
            'svc': {'image': 'nginx', 'privileged': false},
          },
        };
        final allowedBlockers = ApplicationComposeService.blockers(
          allowedCompose,
        );
        expect(
          allowedBlockers,
          isNot(contains('APP_CENTER_TEMPLATE_UNSUPPORTED:privileged')),
          reason: 'privileged:false should be allowed',
        );
      },
    );

    test('literal dollars in default fallback not expanded by Compose', () {
      final template = ApplicationTemplate(
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
            'svc': {
              'image': 'nginx',
              'environment': {'PASSWORD': '\${SECRET:-literal\$dollar}'},
            },
          },
        },
        metadata: {},
        variables: {'SECRET'},
      );
      final env = _validEnv();
      final defaults = ApplicationComposeService.defaults(
        template,
        env,
        'inst-123',
      );
      final resolvedPassword = defaults.environment['svc']!['PASSWORD'];
      expect(resolvedPassword, 'literal\$dollar');
    });

    test('multi-service project labels merged correctly via build', () {
      final template = ApplicationTemplate(
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
            'svc1': {
              'image': 'nginx',
              'ports': ['80'],
              'labels': {'app': 'valhalla'},
            },
            'svc2': {
              'image': 'app',
              'ports': ['8080'],
              'labels': {'tier': 'frontend'},
            },
          },
        },
        metadata: {},
      );
      final config = ApplicationConfiguration(
        name: 'test',
        dataRoot: '/data',
        bindAddress: '127.0.0.1',
        ports: [
          ApplicationPort(service: 'svc1', target: 80, published: 8080),
          ApplicationPort(service: 'svc2', target: 8080, published: 8081),
        ],
        mounts: [
          ApplicationMount(
            service: 'svc1',
            target: '/data',
            source: '/data/svc1',
          ),
          ApplicationMount(
            service: 'svc2',
            target: '/data',
            source: '/data/svc2',
          ),
        ],
        variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
        environment: {},
      );
      final built = ApplicationComposeService.build(
        template,
        config,
        'inst-123',
        'proj',
      );
      expect(built, contains('com.valhalla.app.instance'));
      expect(built, contains('inst-123'));
      expect(built, contains('"app": "valhalla"'));
      expect(built, contains('"tier": "frontend"'));
    });

    test(
      'build multi-service container_name aliases preserves existing aliases and isolated bridge',
      () {
        final template = ApplicationTemplate(
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
              'svc1': {
                'image': 'nginx',
                'ports': ['80'],
                'container_name': 'my-custom-name',
                'networks': {
                  'default': {
                    'aliases': ['existing-alias'],
                  },
                  'isolated': {
                    'driver': 'bridge',
                    'aliases': ['isolated-alias'],
                  },
                },
              },
              'svc2': {
                'image': 'app',
                'ports': ['8080'],
              },
            },
          },
          metadata: {},
        );
        final config = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          ports: [
            ApplicationPort(service: 'svc1', target: 80, published: 8080),
            ApplicationPort(service: 'svc2', target: 8080, published: 8081),
          ],
          mounts: [],
          variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
          environment: {},
        );
        final built = ApplicationComposeService.build(
          template,
          config,
          'inst-123',
          'proj',
        );
        final decoded = jsonDecode(built) as Map<String, dynamic>;
        final svc1 = decoded['services']['svc1'] as Map<String, dynamic>;
        final networks = svc1['networks'] as Map<String, dynamic>;
        final defaultAliases = (networks['default']['aliases'] as List)
            .cast<String>();
        final isolatedAliases = (networks['isolated']['aliases'] as List)
            .cast<String>();
        expect(
          defaultAliases,
          containsAll(['existing-alias', 'my-custom-name']),
        );
        expect(
          isolatedAliases,
          containsAll(['isolated-alias', 'my-custom-name']),
        );
        expect(svc1['container_name'], isNull);
      },
    );

    test('build original template not mutated during build', () {
      final template = ApplicationTemplate(
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
            'svc': {
              'image': 'nginx',
              'ports': ['80'],
              'container_name': 'should-be-removed',
              'network_mode': 'bridge',
            },
          },
        },
        metadata: {},
      );
      final config = ApplicationConfiguration(
        name: 'test',
        dataRoot: '/data',
        bindAddress: '127.0.0.1',
        ports: [ApplicationPort(service: 'svc', target: 80, published: 8080)],
        mounts: [],
        variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
        environment: {},
      );
      final beforeCompose = jsonEncode(template.compose);
      ApplicationComposeService.build(template, config, 'inst-123', 'proj');
      expect(jsonEncode(template.compose), beforeCompose);
    });

    test('build removes network_mode bridge but preserves private mode', () {
      final template = ApplicationTemplate(
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
            'svc1': {
              'image': 'nginx',
              'ports': ['80'],
              'network_mode': 'bridge',
            },
            'svc2': {
              'image': 'app',
              'ports': ['8080'],
              'network_mode': 'private',
            },
          },
        },
        metadata: {},
      );
      final config = ApplicationConfiguration(
        name: 'test',
        dataRoot: '/data',
        bindAddress: '127.0.0.1',
        ports: [
          ApplicationPort(service: 'svc1', target: 80, published: 8080),
          ApplicationPort(service: 'svc2', target: 8080, published: 8081),
        ],
        mounts: [],
        variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
        environment: {},
      );
      final built = ApplicationComposeService.build(
        template,
        config,
        'inst-123',
        'proj',
      );
      final decoded = jsonDecode(built) as Map<String, dynamic>;
      expect(
        (decoded['services']['svc1'] as Map).containsKey('network_mode'),
        isFalse,
      );
      expect((decoded['services']['svc2'] as Map)['network_mode'], 'private');
    });

    test(
      'defaults outputs resolved compose with ports mounts variables environment',
      () {
        final defaults = ApplicationComposeService.defaults(
          validTemplate,
          validEnv,
          'inst-456',
        );
        expect(defaults.dataRoot, contains('inst-456'));
        expect(defaults.variables, containsPair('PUID', '1000'));
        expect(defaults.variables, containsPair('PGID', '1000'));
        expect(defaults.variables, containsPair('TZ', 'UTC'));
        expect(defaults.variables, containsPair('AppID', 'inst-456'));
        expect(defaults.ports, hasLength(1));
        expect(defaults.ports.first.service, 'svc');
        expect(defaults.ports.first.target, 80);
        expect(defaults.ports.first.published, 80);
        expect(defaults.mounts, hasLength(1));
        expect(defaults.mounts.first.service, 'svc');
        expect(defaults.environment['svc'], isNotNull);
      },
    );

    test('mergeDefaults preserves customized data directory and values', () {
      final current = ApplicationConfiguration(
        name: 'test',
        dataRoot: '/custom/path',
        variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'America/New_York'},
        bindAddress: '127.0.0.1',
      );
      final merged = ApplicationComposeService.mergeDefaults(
        validTemplate,
        validEnv,
        'inst',
        current,
      );
      expect(merged.dataRoot, '/custom/path');
      expect(merged.variables['PUID'], '1000');
      expect(merged.variables['PGID'], '1000');
      expect(merged.variables['TZ'], 'America/New_York');
    });

    test(
      'changeVariables updates automatic env while preserving explicit override',
      () {
        final template = ApplicationTemplate(
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
              'svc': {
                'image': 'nginx',
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
        final env = _validEnv();
        final current = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          variables: {'PASSWORD': 'oldPASSWORD'},
          environment: {
            'svc': {
              'AUTO_VAR': 'oldPASSWORD',
              'EXPLICIT_VAR': 'user-overridden',
            },
          },
        );
        final updated = ApplicationComposeService.changeVariables(
          template,
          env,
          'inst',
          current,
          {'PASSWORD': 'newPASSWORD'},
        );
        expect(updated.variables['PASSWORD'], 'newPASSWORD');
        expect(updated.environment['svc']!['AUTO_VAR'], 'newPASSWORD');
        expect(updated.environment['svc']!['EXPLICIT_VAR'], 'user-overridden');
      },
    );

    group('jellyfinSoftwareMode', () {
      test(
        'ApplicationConfiguration defaults jellyfinSoftwareMode to false',
        () {
          final config = ApplicationConfiguration(
            name: 'test',
            dataRoot: '/data',
          );
          expect(config.jellyfinSoftwareMode, false);
        },
      );

      test(
        'ApplicationConfiguration JSON without jellyfinSoftwareMode defaults to false',
        () {
          final json = {
            'name': 'test',
            'dataRoot': '/data',
            'bindAddress': '127.0.0.1',
            'ports': [],
            'mounts': [],
            'variables': {},
            'environment': {},
          };
          final config = ApplicationConfiguration.fromJson(json);
          expect(config.jellyfinSoftwareMode, false);
        },
      );

      test(
        'ApplicationConfiguration JSON with jellyfinSoftwareMode true roundtrips',
        () {
          final json = {
            'name': 'test',
            'dataRoot': '/data',
            'bindAddress': '127.0.0.1',
            'jellyfinSoftwareMode': true,
            'ports': [],
            'mounts': [],
            'variables': {},
            'environment': {},
          };
          final config = ApplicationConfiguration.fromJson(json);
          expect(config.jellyfinSoftwareMode, true);
          final encoded = config.toJson();
          expect(encoded['jellyfinSoftwareMode'], true);
        },
      );

      test(
        'ApplicationConfiguration JSON with jellyfinSoftwareMode false roundtrips',
        () {
          final json = {
            'name': 'test',
            'dataRoot': '/data',
            'bindAddress': '127.0.0.1',
            'jellyfinSoftwareMode': false,
            'ports': [],
            'mounts': [],
            'variables': {},
            'environment': {},
          };
          final config = ApplicationConfiguration.fromJson(json);
          expect(config.jellyfinSoftwareMode, false);
          final encoded = config.toJson();
          expect(encoded['jellyfinSoftwareMode'], false);
        },
      );

      test('copyWith preserves jellyfinSoftwareMode when not specified', () {
        final original = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          jellyfinSoftwareMode: true,
        );
        final copied = original.copyWith(name: 'updated');
        expect(copied.jellyfinSoftwareMode, true);
      });

      test('copyWith updates jellyfinSoftwareMode when specified', () {
        final original = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          jellyfinSoftwareMode: false,
        );
        final copied = original.copyWith(jellyfinSoftwareMode: true);
        expect(copied.jellyfinSoftwareMode, true);
      });
    });

    group('ApplicationComposeService jellyfinSoftwareMode profile', () {
      final jellyfinTemplate = _jelfinTemplate();
      final env = _validEnv();

      test(
        'supportsJellyfinSoftwareMode returns true for official Jellyfin template',
        () {
          expect(
            ApplicationComposeService.supportsJellyfinSoftwareMode(
              jellyfinTemplate,
            ),
            true,
          );
        },
      );

      test(
        'supportsJellyfinSoftwareMode returns false for non-official source',
        () {
          final template = ApplicationTemplate(
            application: CatalogApplication(
              sourceId: 'other-source',
              id: 'org.icewhale.jellyfin',
              title: 'Jellyfin',
              composeUrl: 'https://example.com/compose.yml',
              metadataUrl: '',
              contentHash: '',
            ),
            compose: jellyfinTemplate.compose,
            metadata: {},
          );
          expect(
            ApplicationComposeService.supportsJellyfinSoftwareMode(template),
            false,
          );
        },
      );

      test('supportsJellyfinSoftwareMode returns false for non-Jellyfin app', () {
        final template = ApplicationTemplate(
          application: CatalogApplication(
            sourceId: ApplicationSource.official.id,
            id: 'other-app',
            title: 'Other App',
            composeUrl:
                'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
            metadataUrl: '',
            contentHash: '',
          ),
          compose: jellyfinTemplate.compose,
          metadata: {},
        );
        expect(
          ApplicationComposeService.supportsJellyfinSoftwareMode(template),
          false,
        );
      });

      test('jellyfinSoftwareTemplate removes hardware devices', () {
        final result = ApplicationComposeService.jellyfinSoftwareTemplate(
          jellyfinTemplate,
        );
        for (final service in result.compose['services']!.values) {
          final svc = service as Map<String, dynamic>;
          expect(
            svc.containsKey('devices'),
            false,
            reason: 'hardware devices must be removed',
          );
        }
      });

      test('jellyfinSoftwareTemplate removes /opt/vc/lib volume', () {
        final result = ApplicationComposeService.jellyfinSoftwareTemplate(
          jellyfinTemplate,
        );
        for (final service in result.compose['services']!.values) {
          final svc = service as Map<String, dynamic>;
          final volumes = svc['volumes'] as List? ?? [];
          final hasVcLib = volumes.any(
            (v) =>
                v is Map &&
                v['source'] == '/opt/vc/lib' &&
                v['target'] == '/opt/vc/lib',
          );
          expect(hasVcLib, false, reason: '/opt/vc/lib must be removed');
        }
      });

      test('jellyfinSoftwareTemplate makes /Media read-only', () {
        final result = ApplicationComposeService.jellyfinSoftwareTemplate(
          jellyfinTemplate,
        );
        for (final service in result.compose['services']!.values) {
          final svc = service as Map<String, dynamic>;
          final volumes = svc['volumes'] as List? ?? [];
          for (final volume in volumes) {
            if (volume is Map && volume['target'] == '/Media') {
              expect(
                volume['read_only'],
                true,
                reason: '/Media must be read-only',
              );
            }
          }
        }
      });

      test('jellyfinSoftwareTemplate removes devices blocker', () {
        final result = ApplicationComposeService.jellyfinSoftwareTemplate(
          jellyfinTemplate,
        );
        expect(
          result.blockers,
          isNot(contains('APP_CENTER_TEMPLATE_UNSUPPORTED:devices')),
        );
      });

      test('defaults with jellyfinSoftwareMode applies profile', () {
        final config = ApplicationComposeService.defaults(
          jellyfinTemplate,
          env,
          'inst-123',
          jellyfinSoftwareMode: true,
        );
        expect(config.jellyfinSoftwareMode, true);
      });

      test(
        'build with jellyfinSoftwareMode applies profile and forces /Media read-only',
        () {
          final config = ApplicationConfiguration(
            name: 'test',
            dataRoot: '/data',
            bindAddress: '127.0.0.1',
            jellyfinSoftwareMode: true,
            ports: [
              ApplicationPort(
                service: 'jellyfin',
                target: 8096,
                published: 8096,
              ),
            ],
            mounts: [
              ApplicationMount(
                service: 'jellyfin',
                target: '/Media',
                source: '/media',
                readOnly: false,
              ),
              ApplicationMount(
                service: 'jellyfin',
                target: '/config',
                source: '/config',
              ),
            ],
            variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
            environment: {},
          );
          final built = ApplicationComposeService.build(
            jellyfinTemplate,
            config,
            'inst-123',
            'proj',
          );
          final decoded = jsonDecode(built) as Map<String, dynamic>;
          final svc = decoded['services']['jellyfin'] as Map<String, dynamic>;
          final volumes = svc['volumes'] as List;
          final mediaMount =
              volumes.firstWhere((v) => v is Map && v['target'] == '/Media')
                  as Map;
          expect(
            mediaMount['read_only'],
            true,
            reason: 'build must force /Media read-only',
          );
        },
      );

      test('mergeDefaults retains jellyfinSoftwareMode', () {
        final current = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/custom/path',
          jellyfinSoftwareMode: true,
          variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
          bindAddress: '127.0.0.1',
        );
        final merged = ApplicationComposeService.mergeDefaults(
          jellyfinTemplate,
          env,
          'inst',
          current,
        );
        expect(merged.jellyfinSoftwareMode, true);
        expect(merged.dataRoot, '/custom/path');
      });

      test('changeVariables retains jellyfinSoftwareMode', () {
        final current = ApplicationConfiguration(
          name: 'test',
          dataRoot: '/data',
          jellyfinSoftwareMode: true,
          variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
          bindAddress: '127.0.0.1',
        );
        final updated = ApplicationComposeService.changeVariables(
          jellyfinTemplate,
          env,
          'inst',
          current,
          {'CUSTOM_VAR': 'new-value'},
        );
        expect(updated.jellyfinSoftwareMode, true);
      });

      test('jellyfinSoftwareTemplate throws on unsupported template', () {
        final template = ApplicationTemplate(
          application: CatalogApplication(
            sourceId: ApplicationSource.official.id,
            id: 'org.icewhale.jellyfin',
            title: 'Jellyfin',
            composeUrl: 'https://example.com/other-compose.yml',
            metadataUrl: '',
            contentHash: '',
          ),
          compose: {
            'services': {
              'jellyfin': {'image': 'jellyfin'},
            },
          },
          metadata: {},
        );
        expect(
          () => ApplicationComposeService.jellyfinSoftwareTemplate(template),
          throwsA(
            isA<ApplicationCenterException>().having(
              (e) => e.code,
              'code',
              'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE',
            ),
          ),
        );
      });

      test('jellyfinSoftwareTemplate throws on non-standard devices', () {
        final compose =
            jsonDecode(jsonEncode(jellyfinTemplate.compose))
                as Map<String, dynamic>;
        final svc = compose['services']['jellyfin'] as Map<String, dynamic>;
        svc['devices'] = ['/dev/custom:/dev/custom'];
        final template = ApplicationTemplate(
          application: jellyfinTemplate.application,
          compose: compose,
          metadata: jellyfinTemplate.metadata,
          variables: jellyfinTemplate.variables,
          blockers: jellyfinTemplate.blockers,
        );
        expect(
          () => ApplicationComposeService.jellyfinSoftwareTemplate(template),
          throwsA(
            isA<ApplicationCenterException>().having(
              (e) => e.code,
              'code',
              'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE',
            ),
          ),
        );
      });

      test(
        'trusted official Jellyfin software profile removes only whitelisted devices and /opt/vc/lib, leaves original template unchanged and keeps /Media readonly even config readonly false',
        () {
          final originalCompose = jsonEncode(jellyfinTemplate.compose);
          final result = ApplicationComposeService.jellyfinSoftwareTemplate(
            jellyfinTemplate,
          );

          for (final service in result.compose['services']!.values) {
            final svc = service as Map<String, dynamic>;
            expect(
              svc.containsKey('devices'),
              false,
              reason: 'whitelisted hardware devices must be removed',
            );

            final volumes = svc['volumes'] as List? ?? [];
            final hasVcLib = volumes.any(
              (v) =>
                  (v is Map &&
                      v['source'] == '/opt/vc/lib' &&
                      v['target'] == '/opt/vc/lib') ||
                  (v is String && v.startsWith('/opt/vc/lib:/opt/vc/lib')),
            );
            expect(hasVcLib, false, reason: '/opt/vc/lib must be removed');

            for (final volume in volumes) {
              if (volume is Map && volume['target'] == '/Media') {
                expect(
                  volume['read_only'],
                  isTrue,
                  reason: '/Media must be read-only in profile',
                );
              }
              if (volume is String && volume.contains(':/Media')) {
                expect(
                  volume.endsWith(':ro') || volume.contains(':ro,'),
                  isTrue,
                  reason: 'short-form /Media must be read-only',
                );
              }
            }
          }

          expect(
            result.blockers,
            isNot(contains('APP_CENTER_TEMPLATE_UNSUPPORTED:devices')),
          );
          expect(
            jsonEncode(jellyfinTemplate.compose),
            originalCompose,
            reason: 'original template must not be mutated',
          );
        },
      );

      test(
        'untrusted unknown devices and other privilege blockers still rejected',
        () {
          final compose =
              jsonDecode(jsonEncode(jellyfinTemplate.compose))
                  as Map<String, dynamic>;
          final svc = compose['services']['jellyfin'] as Map<String, dynamic>;

          svc['devices'] = ['/dev/unknown:/dev/unknown'];
          var template = ApplicationTemplate(
            application: jellyfinTemplate.application,
            compose: compose,
            metadata: jellyfinTemplate.metadata,
            variables: jellyfinTemplate.variables,
            blockers: jellyfinTemplate.blockers,
          );
          expect(
            () => ApplicationComposeService.jellyfinSoftwareTemplate(template),
            throwsA(
              isA<ApplicationCenterException>().having(
                (e) => e.code,
                'code',
                'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE',
              ),
            ),
            reason: 'unknown device must be rejected',
          );

          compose['services']['jellyfin']!['devices'] = ['/dev/dri:/dev/dri'];
          svc['privileged'] = true;
          template = ApplicationTemplate(
            application: jellyfinTemplate.application,
            compose: compose,
            metadata: jellyfinTemplate.metadata,
            variables: jellyfinTemplate.variables,
            blockers: jellyfinTemplate.blockers,
          );
          final profiled = ApplicationComposeService.jellyfinSoftwareTemplate(
            template,
          );
          expect(
            profiled.blockers,
            contains('APP_CENTER_TEMPLATE_UNSUPPORTED:privileged'),
          );
          final buildConfig = ApplicationConfiguration(
            name: 'test',
            dataRoot: '/data',
            bindAddress: '127.0.0.1',
            jellyfinSoftwareMode: true,
            ports: [
              ApplicationPort(
                service: 'jellyfin',
                target: 8096,
                published: 8096,
              ),
            ],
            mounts: [
              ApplicationMount(
                service: 'jellyfin',
                target: '/Media',
                source: '/media',
              ),
              ApplicationMount(
                service: 'jellyfin',
                target: '/config',
                source: '/config',
              ),
            ],
            variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
            environment: {},
          );
          expect(
            () => ApplicationComposeService.build(
              template,
              buildConfig,
              'inst-123',
              'proj',
            ),
            throwsA(
              isA<ApplicationCenterException>().having(
                (e) => e.code,
                'code',
                'APP_CENTER_TEMPLATE_UNSUPPORTED',
              ),
            ),
            reason: 'privileged must be rejected by build',
          );

          compose['services']['jellyfin']!.remove('privileged');
          svc['cap_add'] = ['ALL'];
          template = ApplicationTemplate(
            application: jellyfinTemplate.application,
            compose: compose,
            metadata: jellyfinTemplate.metadata,
            variables: jellyfinTemplate.variables,
            blockers: jellyfinTemplate.blockers,
          );
          final profiledCapAdd =
              ApplicationComposeService.jellyfinSoftwareTemplate(template);
          expect(
            profiledCapAdd.blockers,
            contains('APP_CENTER_TEMPLATE_UNSUPPORTED:cap_add'),
          );
          expect(
            () => ApplicationComposeService.build(
              template,
              buildConfig,
              'inst-123',
              'proj',
            ),
            throwsA(
              isA<ApplicationCenterException>().having(
                (e) => e.code,
                'code',
                'APP_CENTER_TEMPLATE_UNSUPPORTED',
              ),
            ),
            reason: 'cap_add must be rejected by build',
          );
        },
      );

      test(
        'defaults mergeDefaults build preserves jellyfinSoftwareMode profile',
        () {
          final configDefaults = ApplicationComposeService.defaults(
            jellyfinTemplate,
            env,
            'inst-123',
            jellyfinSoftwareMode: true,
          );
          expect(configDefaults.jellyfinSoftwareMode, true);

          final current = ApplicationConfiguration(
            name: 'test',
            dataRoot: '/custom/path',
            jellyfinSoftwareMode: true,
            variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
            bindAddress: '127.0.0.1',
          );
          final merged = ApplicationComposeService.mergeDefaults(
            jellyfinTemplate,
            env,
            'inst',
            current,
          );
          expect(merged.jellyfinSoftwareMode, true);
          expect(merged.dataRoot, '/custom/path');

          final buildConfig = ApplicationConfiguration(
            name: 'test',
            dataRoot: '/data',
            bindAddress: '127.0.0.1',
            jellyfinSoftwareMode: true,
            ports: [
              ApplicationPort(
                service: 'jellyfin',
                target: 8096,
                published: 8096,
              ),
            ],
            mounts: [
              ApplicationMount(
                service: 'jellyfin',
                target: '/Media',
                source: '/media',
                readOnly: false,
              ),
              ApplicationMount(
                service: 'jellyfin',
                target: '/config',
                source: '/config',
              ),
            ],
            variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
            environment: {},
          );
          final built = ApplicationComposeService.build(
            jellyfinTemplate,
            buildConfig,
            'inst-123',
            'proj',
          );
          final decoded = jsonDecode(built) as Map<String, dynamic>;
          final svc = decoded['services']['jellyfin'] as Map<String, dynamic>;
          final volumes = svc['volumes'] as List;
          final mediaMount =
              volumes.firstWhere((v) => v is Map && v['target'] == '/Media')
                  as Map;
          expect(
            mediaMount['read_only'],
            true,
            reason: 'build must force /Media read-only',
          );
          expect(
            svc.containsKey('devices'),
            false,
            reason: 'build must remove whitelisted devices',
          );
          final hasVcLib = volumes.any(
            (v) =>
                v is Map &&
                v['source'] == '/opt/vc/lib' &&
                v['target'] == '/opt/vc/lib',
          );
          expect(hasVcLib, false, reason: 'build must remove /opt/vc/lib');
        },
      );
    });
  });
}

ApplicationTemplate _validTemplate() {
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
        'svc': {
          'image': 'nginx',
          'ports': ['80'],
          'volumes': ['/data:/data'],
          'environment': {'VAR': '\${PUID}'},
        },
      },
    },
    metadata: {},
    variables: {'CUSTOM_VAR'},
  );
}

ApplicationEnvironment _validEnv() {
  return ApplicationEnvironment(
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
  );
}

ApplicationConfiguration _validConfig() {
  return ApplicationConfiguration(
    name: 'test',
    dataRoot: '/data',
    bindAddress: '127.0.0.1',
    ports: [ApplicationPort(service: 'svc', target: 80, published: 8080)],
    mounts: [
      ApplicationMount(service: 'svc', target: '/data', source: '/data'),
    ],
    variables: {'PUID': '1000', 'PGID': '1000', 'TZ': 'UTC'},
    environment: {},
  );
}

ApplicationTemplate _jelfinTemplate() {
  return ApplicationTemplate(
    application: CatalogApplication(
      sourceId: ApplicationSource.official.id,
      id: 'org.icewhale.jellyfin',
      title: 'Jellyfin',
      composeUrl:
          'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
      metadataUrl: '',
      contentHash: '',
    ),
    compose: {
      'services': {
        'jellyfin': {
          'image': 'jellyfin/jellyfin',
          'ports': ['8096:8096'],
          'devices': [
            '/dev/dri:/dev/dri',
            '/dev/vcsm:/dev/vcsm',
            '/dev/vchiq:/dev/vchiq',
            '/dev/video10:/dev/video10',
            '/dev/video11:/dev/video11',
            '/dev/video12:/dev/video12',
          ],
          'volumes': [
            '/DATA/AppData/jellyfin:/config',
            '/opt/vc/lib:/opt/vc/lib',
            '/DATA/Media:/Media',
          ],
          'environment': {
            'PUID': '\${PUID}',
            'PGID': '\${PGID}',
            'TZ': '\${TZ}',
          },
        },
      },
    },
    metadata: {},
    variables: {},
    blockers: ['APP_CENTER_TEMPLATE_UNSUPPORTED:devices'],
  );
}
