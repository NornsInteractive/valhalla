import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/data/models/app_update.dart';
import 'fixtures/app_update_payload.dart';

Map<String, dynamic> _release() => updatePayload(
  packages: [
    updatePackage(platform: 'android', arch: 'arm64-v8a'),
    updatePackage(platform: 'windows', hash: updateHashB),
  ],
);
AppUpdateRelease _parse(Map<String, dynamic> value) =>
    AppUpdateService.parseRelease(value);

void main() {
  test('multi-platform hashes, native codes and explicit download target', () {
    final result = _parse(
      updatePayload(
        versionName: '1.0.4+5',
        code: 2005,
        packages: [
          for (final arch in ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
            updatePackage(
              platform: 'android',
              arch: arch,
              version: '1.0.4',
              build: 5,
              code: 2005,
              hash: arch == 'arm64-v8a' ? updateHashA : updateHashB,
            ),
          updatePackage(version: '1.0.4', build: 5, code: 2005),
        ],
      ),
    );
    expect(result.version, '1.0.4');
    expect(result.buildNumber, 5);
    expect(result.artifacts.map((a) => a.androidVersionCode), [
      2005,
      1005,
      4005,
      null,
    ]);
    expect(result.artifacts[1].sha256, updateHashB);
    expect(result.isNewerThan('1.0.4', 5), isFalse);
    expect(result.isNewerThan('1.0.4', 4), isTrue);
    for (final artifact in result.artifacts) {
      final query = artifact.url.queryParameters;
      expect(query['app_id'], valhallaDistributionAppId);
      expect(query['version_code'], '2005');
      expect(query['channel'], 'default');
      expect(query['platform'], artifact.platform);
      expect(
        query['arch'],
        AppUpdateService.distributionArchitecture(
          artifact.platform,
          artifact.architecture,
        ),
      );
      expect(query['package_id'], startsWith('pkg_'));
    }
    expect(result.artifactFor('windows', ['x64']), isNull);
    expect(
      result.artifactFor('android', ['armeabi-v7a'])?.androidVersionCode,
      1005,
    );
  });

  test('runtime ABI aliases preserve installed application architecture', () {
    expect(
      AppUpdateService.distributionArchitecture('android', 'arm'),
      'armeabi-v7a',
    );
    expect(
      AppUpdateService.distributionArchitecture('android', 'arm64'),
      'arm64-v8a',
    );
    expect(AppUpdateService.distributionArchitecture('linux', 'x64'), 'x86_64');
    expect(
      AppUpdateService.distributionArchitecture('windows', 'arm64'),
      'arm64-v8a',
    );
    expect(
      AppUpdateService.distributionArchitecture('macos', 'arm64'),
      'apple-silicon',
    );
    expect(
      AppUpdateService.distributionArchitecture('android', 'x86_64'),
      'x86_64',
    );
  });

  test('optional version prefix, legacy data and bounded unicode notes', () {
    final payload = updatePayload(
      versionName: 'v1.2.3+42',
      notes: 'prefix ${'𝐀' * 20000}',
    );
    final result = _parse(payload);
    expect(result.version, '1.2.3');
    expect(result.notes.runes.length, 16 * 1024 + 2);
    expect(result.notes.endsWith('\n…'), isTrue);
    expect(result.page.toString(), valhallaDistributionUrl);
    expect(result.sourceCommit, isNull);
    final data = payload['data'] as Map<String, dynamic>;
    data.remove('packages');
    expect(_parse(payload).artifacts.single.platform, 'linux');
    data['changelog'] = null;
    expect(_parse(payload).notes, '');
    data.remove('file_sha256');
    data['changelog'] = 'SHA256: $updateHashA';
    expect(_parse(payload).artifacts.single.sha256, updateHashA);
    data['changelog'] = 'SHA256: $updateHashA SHA256: $updateHashB';
    expect(() => _parse(payload), throwsFormatException);
  });

  final invalidData = <String, Object?>{
    'app_id': 'another.application',
    'latest_version_code': 0,
    'latest_version_name': '1.2.3-preview',
    'download_url': 7,
    'file_name': null,
    'has_update': 'true',
    'is_force': null,
    'changelog': [],
    'channel': 'default&admin=true',
    'packages': {},
  };
  for (final entry in invalidData.entries) {
    test('reject malformed catalog field ${entry.key}', () {
      final payload = updatePayload();
      (payload['data'] as Map<String, dynamic>)[entry.key] = entry.value;
      expect(() => _parse(payload), throwsFormatException);
    });
  }

  final invalidPackage = <String, Object?>{
    'id': 'other_id',
    'platform': 'android',
    'arch': 'arm64-v8a',
    'file_name': '../valhalla-v1.2.3-linux-x64.tar.gz',
    'file_size': 0,
    'file_sha256': 'MD5-not-SHA256',
    'app_id': 'wrong.application',
  };
  for (final entry in invalidPackage.entries) {
    test('reject malformed package field ${entry.key}', () {
      final package = updatePackage()..[entry.key] = entry.value;
      expect(
        () => _parse(updatePayload(packages: [package])),
        throwsFormatException,
      );
    });
  }

  for (final url in [
    'http://ygg.norns.cc.cd/api/v1/app/download?app_id=com.norns.valhalla&version_code=2042&channel=default',
    'https://evil.example/api/v1/app/download',
    'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/test.zip',
    updateDownloadUrl().replace(userInfo: 'user:pass').toString(),
    updateDownloadUrl().replace(port: 444).toString(),
    updateDownloadUrl().replace(fragment: 'extra').toString(),
    '${updateDownloadUrl()}&version_code=2005',
    '${updateDownloadUrl()}&token=secret',
    updateDownloadUrl(code: 2005).toString(),
    '${updateDownloadUrl()}&platform=android',
    '${updateDownloadUrl()}&arch=arm64-v8a',
  ]) {
    test('reject unbound or untrusted package URL $url', () {
      final package = updatePackage()..['download_url'] = url;
      expect(
        () => _parse(updatePayload(packages: [package])),
        throwsFormatException,
      );
    });
  }

  test('new packages never inherit parent hash', () {
    final package = updatePackage()..remove('file_sha256');
    expect(
      () => _parse(
        updatePayload(notes: 'SHA256: $updateHashA', packages: [package]),
      ),
      throwsFormatException,
    );
  });

  test(
    'duplicates, excessive packages, missing build and APK build mismatch',
    () {
      final package = updatePackage();
      expect(
        () => _parse(updatePayload(packages: [package, package])),
        throwsFormatException,
      );
      expect(
        () => _parse(
          updatePayload(
            packages: [
              package,
              {
                ...package,
                'id': 'pkg_other',
                'download_url': updateDownloadUrl(id: 'pkg_other').toString(),
              },
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(
          updatePayload(
            packages: List.generate(65, (i) => updatePackage(id: 'pkg_$i')),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(
          updatePayload(
            versionName: '1.2.3',
            packages: [
              package,
              updatePackage(platform: 'windows'),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(
          updatePayload(
            packages: [
              updatePackage(platform: 'android', arch: 'arm64-v8a', build: 5),
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test('immutable artifacts and current cache source only', () {
    expect(() => _parse(_release()).artifacts.clear(), throwsUnsupportedError);
    expect(
      AppUpdateService.isCurrentCache({'source': AppUpdateService.cacheSource}),
      isTrue,
    );
    expect(AppUpdateService.isCurrentCache({'source': 'github'}), isFalse);
    expect(AppUpdateService.isCurrentCache(null), isFalse);
  });

  group('artifactFor', () {
    test('returns the first artifact matching an architecture preference', () {
      final release = _parse(_release());
      expect(
        release.artifactFor('android', ['x86_64', 'arm64-v8a'])?.architecture,
        'arm64-v8a',
      );
      expect(release.artifactFor('android', ['armeabi-v7a']), isNull);
      expect(release.artifactFor('windows', ['x64'])?.platform, 'windows');
      expect(release.artifactFor('linux', ['x64']), isNull);
    });

    test('platform must also match', () {
      final release = _parse(_release());
      expect(release.artifactFor('android', ['x64']), isNull);
    });
  });

  group('isNewerThan', () {
    AppUpdateRelease releaseAt(String tag, int? build) => AppUpdateRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      buildNumber: build,
      sourceCommit: null,
      notes: '',
      page: Uri.parse('https://github.com/x'),
      artifacts: const [],
    );

    test('a greater version always wins', () {
      expect(releaseAt('1.3.0', 1).isNewerThan('1.2.9', 99), isTrue);
      expect(releaseAt('2.0.0', null).isNewerThan('1.9.9', 0), isTrue);
      expect(releaseAt('1.2.2', null).isNewerThan('1.2.3', 0), isFalse);
    });

    test('segments compare numerically, not lexically', () {
      expect(releaseAt('1.2.10', null).isNewerThan('1.2.9', 0), isTrue);
      expect(releaseAt('1.10.0', null).isNewerThan('1.9.0', 0), isTrue);
    });

    test('equal versions fall back to the build number', () {
      expect(releaseAt('1.2.3', 5).isNewerThan('1.2.3', 4), isTrue);
      expect(releaseAt('1.2.3', 4).isNewerThan('1.2.3', 4), isFalse);
      expect(releaseAt('1.2.3', null).isNewerThan('1.2.3', 4), isFalse);
    });

    test('an installed version the tag parser rejects fails loudly', () {
      expect(
        () => releaseAt('1.2.3', null).isNewerThan('abc', 1),
        throwsFormatException,
      );
    });
  });

  group('compareVersions', () {
    test('orders and compares plain versions', () {
      expect(AppUpdateRelease.compareVersions('1.2.3', '1.2.3'), 0);
      expect(AppUpdateRelease.compareVersions('1.2.3', '1.2.4'), lessThan(0));
      expect(
        AppUpdateRelease.compareVersions('2.0.0', '1.99.99'),
        greaterThan(0),
      );
      expect(
        AppUpdateRelease.compareVersions('0.0.1', '0.0.0'),
        greaterThan(0),
      );
    });

    test('an optional v prefix and build metadata are tolerated', () {
      expect(AppUpdateRelease.compareVersions('v1.2.3', '1.2.3'), 0);
      expect(AppUpdateRelease.compareVersions('1.2.3+4', '1.2.3'), 0);
      expect(AppUpdateRelease.compareVersions('1.2.3+4', '1.2.3+9'), 0);
    });

    test('anything else is rejected', () {
      for (final value in ['', '1.2', '1.2.3.4', 'v1.2.x', 'alpha']) {
        expect(
          () => AppUpdateRelease.compareVersions(value, '1.0.0'),
          throwsFormatException,
          reason: value,
        );
      }
    });
  });
}
