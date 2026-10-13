import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import '../support/application_center_fakes.dart';
import '../support/application_paths_fixture.dart';

void main() {
  final id = 'a' * 32;
  final env = centerEnvironment();
  ApplicationConfiguration defaults() =>
      ApplicationComposeService.defaults(nginxProxyTemplate, env, id);
  Map<String, dynamic> build(
    ApplicationConfiguration config, [
    ApplicationTemplate? template,
  ]) =>
      jsonDecode(
            ApplicationComposeService.build(
              template ?? nginxProxyTemplate,
              config,
              id,
              'fixture',
            ),
          )
          as Map<String, dynamic>;
  Matcher error(String code, [String? field]) => throwsA(
    isA<ApplicationCenterException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.detail, 'field', field),
  );

  for (final suffix in ['', '/']) {
    test(
      'Nginx defaults -> variable change -> build with suffix "$suffix"',
      () {
        final initial = defaults();
        final current = initial.copyWith(
          dataRoot: '${initial.dataRoot}$suffix',
          mounts: [
            for (final m in initial.mounts)
              ApplicationMount(
                service: m.service,
                source: '${m.source}$suffix',
                target: m.target,
                readOnly: m.readOnly,
              ),
          ],
        );
        final updated = ApplicationComposeService.changeVariables(
          nginxProxyTemplate,
          env,
          id,
          current,
          {...current.variables, 'TZ': 'Asia/Shanghai', 'PUID': '1001'},
        );
        final service =
            (build(updated)['services'] as Map)['nginxproxymanager'] as Map;
        final mounts = service['volumes'] as List;
        expect(mounts.map((m) => m['source']), [
          '${initial.dataRoot}/data',
          '${initial.dataRoot}/etc/letsencrypt',
        ]);
        expect(mounts.map((m) => m['target']), ['/data', '/etc/letsencrypt']);
        expect(mounts.map((m) => m['read_only']), [false, false]);
        expect(updated.variables['TZ'], 'Asia/Shanghai');
        expect(updated.variables['AppID'], id);
        expect(current.dataRoot, '${initial.dataRoot}$suffix');
      },
    );
  }

  test('ADB Nginx form paths preserve manual mounts and accept /data/temp/', () {
    final base = defaults();
    final original = base.copyWith(
      dataRoot: '/data/temp/',
      mounts: [
        ApplicationMount(
          service: base.mounts.first.service,
          source: '/data/temp/data/temp',
          target: '/data',
        ),
        ApplicationMount(
          service: base.mounts.last.service,
          source: '/data/temp/data/temp/test',
          target: '/etc/letsencrypt',
        ),
      ],
    );
    // The old build passed this exact field to the strict validator unchanged.
    expect(
      () => ApplicationComposeService.validatePath(original.dataRoot),
      error('APP_CENTER_PATH_INVALID'),
    );
    final changed = ApplicationComposeService.changeVariables(
      nginxProxyTemplate,
      env,
      id,
      original,
      {...original.variables, 'TZ': 'Asia/Shanghai'},
    );
    final mounts =
        build(changed)['services']['nginxproxymanager']['volumes'] as List;
    expect(mounts.map((m) => m['source']), [
      '/data/temp/data/temp',
      '/data/temp/data/temp/test',
    ]);
    expect(mounts.map((m) => m['target']), ['/data', '/etc/letsencrypt']);
    expect(original.dataRoot, '/data/temp/');
    expect(
      ApplicationComposeService.canonicalDirectoryPaths(changed).dataRoot,
      '/data/temp',
    );
  });

  for (final longForm in [false, true]) {
    test('template source and target trailing slash, long=$longForm', () {
      final template = ApplicationTemplate(
        application: centerApp,
        metadata: const {},
        variables: const {'AppID'},
        compose: {
          'services': {
            'web': {
              'image': 'nginx:alpine',
              'volumes': [
                longForm
                    ? {
                        'type': 'bind',
                        'source': r'/DATA/AppData/$AppID/config/',
                        'target': '/config/',
                        'read_only': true,
                      }
                    : r'/DATA/AppData/$AppID/config/:/config/:ro',
              ],
            },
          },
        },
      );
      final config = ApplicationComposeService.defaults(template, env, id);
      final volume =
          ((build(config, template)['services'] as Map)['web']['volumes']
                  as List)
              .single;
      expect(volume['source'], '${config.dataRoot}/config');
      expect(volume['target'], '/config');
      expect(volume['read_only'], true);
    });
  }

  for (final invalid in [
    '/',
    '////',
    'relative',
    '/safe/../escape/',
    '/safe/./data/',
    '/safe//data',
    '/data\x00bad',
    '/data\nbad',
    '/data\rbad',
  ]) {
    test(
      'canonicalization does not legalize invalid path ${jsonEncode(invalid)}',
      () {
        expect(
          () => build(defaults().copyWith(dataRoot: invalid)),
          error('APP_CENTER_PATH_INVALID', 'dataRoot'),
        );
      },
    );
  }

  test(
    'manual mount keeps read-only flag; unsafe source still rejected after trim',
    () {
      final config = defaults();
      ApplicationConfiguration source(String path) => config.copyWith(
        mounts: [
          ApplicationMount(
            service: config.mounts.first.service,
            source: path,
            target: '/data',
            readOnly: true,
          ),
          config.mounts.last,
        ],
      );
      final volume =
          (build(source('/srv/media/'))['services']
              as Map)['nginxproxymanager']['volumes'][0];
      expect(volume['source'], '/srv/media');
      expect(volume['read_only'], true);
      for (final path in ['/etc/', '/root/.ssh/', '/proc/', '/sys/', '/dev/']) {
        expect(() => build(source(path)), error('APP_CENTER_MOUNT_FORBIDDEN'));
      }
      expect(
        () => build(source('/srv/../etc/')),
        error('APP_CENTER_PATH_INVALID', 'mountSource'),
      );
    },
  );
}
