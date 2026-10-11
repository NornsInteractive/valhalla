import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/data/models/app_update.dart';

const _hex64 =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
const _otherHex64 =
    '0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0';
const _commit = '0123456789abcdef0123456789abcdef01234567';

/// Well-formed release payload for [tag], with assets named and linked for it.
Map<String, dynamic> _release({
  String tag = 'v1.2.3',
  String? htmlUrl,
  Object? body = 'notes',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>>? assets,
}) {
  return {
    'tag_name': tag,
    'html_url':
        htmlUrl ??
        'https://github.com/NornsInteractive/valhalla/releases/tag/$tag',
    'body': ?body,
    'draft': draft,
    'prerelease': prerelease,
    'assets': assets ?? _assets(tag),
  };
}

/// Canonical asset list for [tag]: one per supported platform.
List<Map<String, dynamic>> _assets([String tag = 'v1.2.3']) => [
  {
    'name': 'Valhalla-$tag-android-arm64-v8a.apk',
    'size': 4096,
    'digest': 'sha256:$_hex64',
    'browser_download_url':
        'https://github.com/NornsInteractive/valhalla/releases/download/$tag/Valhalla-$tag-android-arm64-v8a.apk',
  },
  {
    'name': 'Valhalla-$tag-windows-x64.zip',
    'size': 4096,
    'digest': 'sha256:$_otherHex64',
    'browser_download_url':
        'https://github.com/NornsInteractive/valhalla/releases/download/$tag/Valhalla-$tag-windows-x64.zip',
  },
];

Map<String, dynamic> _manifest({
  Object? schemaVersion = 1,
  Object? version = '1.2.3',
  Object? buildNumber = 42,
  Object? sourceCommit = _commit,
  List<Map<String, dynamic>>? artifacts,
}) {
  return {
    'schemaVersion': schemaVersion,
    'version': version,
    'buildNumber': buildNumber,
    'sourceCommit': sourceCommit,
    'artifacts': ?artifacts,
  };
}

AppUpdateRelease _parse(
  Map<String, dynamic> release, [
  Map<String, dynamic>? metadata,
]) => AppUpdateService.parseRelease(release, metadata);

void main() {
  group('version identity', () {
    test('a leading v on the tag is not part of the version', () {
      expect(_parse(_release(tag: 'v1.2.3')).version, '1.2.3');
      expect(_parse(_release(tag: '1.2.3')).version, '1.2.3');
    });

    test('three-part versions of any magnitude are accepted', () {
      expect(_parse(_release(tag: 'v0.0.0')).version, '0.0.0');
      expect(_parse(_release(tag: 'v10.200.30')).version, '10.200.30');
    });

    test('malformed tags are rejected', () {
      for (final tag in ['v1.2', '1.2.3.4', 'vabc', '', 'v1.2.3-rc1']) {
        expect(
          () => _parse(_release(tag: tag)),
          throwsFormatException,
          reason: 'tag $tag must be rejected',
        );
      }
    });

    test('html_url must point at this repository release', () {
      expect(
        () => _parse(
          _release(htmlUrl: 'https://evil.example/releases/tag/v1.2.3'),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(
          _release(
            htmlUrl:
                'https://github.com/SomeoneElse/valhalla/releases/tag/v1.2.3',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(
          _release(
            htmlUrl:
                'https://github.com/NornsInteractive/valhalla/releases/edit/v1.2.3',
          ),
        ),
        throwsFormatException,
      );
      expect(
        _parse(_release()).page.toString(),
        'https://github.com/NornsInteractive/valhalla/releases/tag/v1.2.3',
      );
    });

    test('release page escapes the tag it links to', () {
      final release = _parse(
        _release(
          tag: 'v1.2.3',
          htmlUrl:
              'https://github.com/NornsInteractive/valhalla/releases/tag/${Uri.encodeComponent('v1.2.3')}',
        ),
      );
      expect(
        release.page.toString(),
        'https://github.com/NornsInteractive/valhalla/releases/tag/v1.2.3',
      );
    });
  });

  group('build identity', () {
    test('build number and source commit come from the manifest', () {
      final release = _parse(
        _release(),
        _manifest(buildNumber: 42, sourceCommit: _commit),
      );
      expect(release.buildNumber, 42);
      expect(release.sourceCommit, _commit);
    });

    test('both are null when there is no manifest', () {
      final release = _parse(_release(), null);
      expect(release.buildNumber, isNull);
      expect(release.sourceCommit, isNull);
    });

    test('a wrong schema version voids the manifest data', () {
      expect(
        () => _parse(_release(), _manifest(schemaVersion: 2)),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(schemaVersion: '1')),
        throwsFormatException,
      );
    });

    test('a manifest version disagreeing with the tag is rejected', () {
      expect(
        () => _parse(_release(), _manifest(version: '1.2.4')),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(version: 'v1.2.3')),
        throwsFormatException,
      );
    });

    test('build number must be a positive int', () {
      expect(
        () => _parse(_release(), _manifest(buildNumber: 0)),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(buildNumber: -1)),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(buildNumber: '42')),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(buildNumber: 4.2)),
        throwsFormatException,
      );
    });

    test('source commit must be 40 lowercase hex characters', () {
      expect(
        () => _parse(
          _release(),
          _manifest(sourceCommit: _commit.substring(0, 39)),
        ),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(sourceCommit: '${_commit}00')),
        throwsFormatException,
      );
      expect(
        () =>
            _parse(_release(), _manifest(sourceCommit: _commit.toUpperCase())),
        throwsFormatException,
      );
      expect(
        () => _parse(_release(), _manifest(sourceCommit: null)),
        throwsFormatException,
      );
    });

    test('notes fall back to an empty string when the body is absent', () {
      expect(_parse(_release(body: null)).notes, '');
      expect(_parse(_release(body: 'hello')).notes, 'hello');
    });
  });

  group('platform identity from asset names', () {
    test('android apks expose the ABI encoded in the file name', () {
      for (final arch in ['armeabi-v7a', 'arm64-v8a', 'x86_64']) {
        final release = _parse(
          _release(
            assets: [
              {
                'name': 'Valhalla-v1.2.3-android-$arch.apk',
                'size': 4096,
                'digest': 'sha256:$_hex64',
                'browser_download_url':
                    'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-android-$arch.apk',
              },
            ],
          ),
        );
        final artifact = release.artifacts.single;
        expect(artifact.platform, 'android', reason: arch);
        expect(artifact.architecture, arch);
      }
    });

    test('desktop platforms are recognized by their name suffix', () {
      for (final entry in [
        ('Valhalla-v1.2.3-windows-x64.zip', 'windows', 'x64'),
        ('Valhalla-v1.2.3-linux-x64.tar.gz', 'linux', 'x64'),
        ('Valhalla-v1.2.3-macos-universal.zip', 'macos', 'universal'),
      ]) {
        final (name, platform, arch) = entry;
        final release = _parse(
          _release(
            assets: [
              {
                'name': name,
                'size': 4096,
                'digest': 'sha256:$_hex64',
                'browser_download_url':
                    'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/$name',
              },
            ],
          ),
        );
        expect(release.artifacts.single.platform, platform);
        expect(release.artifacts.single.architecture, arch);
      }
    });

    test('assets that name no known platform are skipped', () {
      final release = _parse(
        _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
              'size': 4096,
              'digest': 'sha256:$_hex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-android-arm64-v8a.apk',
            },
            {
              'name': 'source-code.tar.gz',
              'size': 4096,
              'digest': 'sha256:$_otherHex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/source-code.tar.gz',
            },
            {
              'name': 'Valhalla-v1.2.3-android-unknown.so',
              'size': 4096,
              'digest': 'sha256:$_otherHex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-android-unknown.so',
            },
          ],
        ),
      );
      expect(release.artifacts.map((a) => a.name), [
        'Valhalla-v1.2.3-android-arm64-v8a.apk',
      ]);
    });

    test('a version mismatch between name and tag is not auto-detected', () {
      final release = _parse(
        _release(
          assets: [
            {
              'name': 'Valhalla-v9.9.9-windows-x64.zip',
              'size': 4096,
              'digest': 'sha256:$_hex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v9.9.9-windows-x64.zip',
            },
          ],
        ),
      );
      expect(release.artifacts.single.platform, 'windows');
    });
  });

  group('platform identity from the manifest', () {
    List<Map<String, dynamic>> manifestArtifacts() => [
      {
        'name': 'Valhalla-1.2.3-android-arm32.apk',
        'platform': 'android',
        'architecture': 'armeabi-v7a',
        'sha256': _hex64,
        'size': 4096,
        'androidVersionCode': 42,
        'androidCertificateSha256': _otherHex64,
      },
      {
        'name': 'Valhalla-1.2.3-mac-arm.zip',
        'platform': 'macos',
        'architecture': 'arm64',
        'sha256': _otherHex64,
        'size': 8192,
      },
    ];

    List<Map<String, dynamic>> manifestAssets() => [
      {
        'name': 'Valhalla-1.2.3-android-arm32.apk',
        'size': 4096,
        'digest': 'sha256:$_hex64',
        'browser_download_url':
            'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-1.2.3-android-arm32.apk',
      },
      {
        'name': 'Valhalla-1.2.3-mac-arm.zip',
        'size': 8192,
        'digest': 'sha256:$_otherHex64',
        'browser_download_url':
            'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-1.2.3-mac-arm.zip',
      },
    ];

    test('manifest entries win over name-derived platform and arch', () {
      final release = _parse(
        _release(assets: manifestAssets()),
        _manifest(artifacts: manifestArtifacts()),
      );
      expect(release.artifacts.map((a) => '${a.platform}/${a.architecture}'), [
        'android/armeabi-v7a',
        'macos/arm64',
      ]);
    });

    test('assets absent from the manifest are dropped', () {
      final release = _parse(
        _release(assets: [...manifestAssets(), ..._assets()]),
        _manifest(artifacts: manifestArtifacts()),
      );
      expect(release.artifacts, hasLength(2));
    });

    test('android metadata travels with the artifact', () {
      final release = _parse(
        _release(assets: manifestAssets()),
        _manifest(artifacts: manifestArtifacts()),
      );
      final android = release.artifacts.first;
      expect(android.androidVersionCode, 42);
      expect(android.androidCertificateSha256, _otherHex64);
      expect(release.artifacts[1].androidVersionCode, isNull);
      expect(release.artifacts[1].androidCertificateSha256, isNull);
    });

    test('manifest and asset disagreeing on size voids the release', () {
      final artifacts = manifestArtifacts();
      artifacts[0]['size'] = 999;
      expect(
        () => _parse(
          _release(assets: manifestAssets()),
          _manifest(artifacts: artifacts),
        ),
        throwsFormatException,
      );
    });
  });

  group('hash identity', () {
    test('sha256 comes from the asset digest with its prefix stripped', () {
      final release = _parse(_release());
      expect(release.artifacts.map((a) => a.sha256), [_hex64, _otherHex64]);
    });

    List<Map<String, dynamic>> manifestArtifacts() => [
      {
        'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
        'platform': 'android',
        'architecture': 'arm64-v8a',
        'sha256': _hex64,
        'size': 4096,
        'androidVersionCode': 42,
        'androidCertificateSha256': _otherHex64,
      },
    ];

    List<Map<String, dynamic>> manifestAssets({String? digest}) => [
      {
        'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
        'size': 4096,
        'digest': ?digest,
        'browser_download_url':
            'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-android-arm64-v8a.apk',
      },
    ];

    test(
      'a manifest sha256 supplies the hash when the asset has no digest',
      () {
        final release = _parse(
          _release(assets: manifestAssets()),
          _manifest(artifacts: manifestArtifacts()),
        );
        expect(release.artifacts.single.sha256, _hex64);
      },
    );

    test(
      'a manifest sha256 contradicting the asset digest voids the release',
      () {
        final artifacts = manifestArtifacts();
        artifacts[0]['sha256'] = _otherHex64;
        expect(
          () => _parse(
            _release(assets: manifestAssets(digest: 'sha256:$_hex64')),
            _manifest(artifacts: artifacts),
          ),
          throwsFormatException,
        );
      },
    );

    test('a matching manifest and asset digest is accepted', () {
      final release = _parse(
        _release(assets: manifestAssets(digest: 'sha256:$_hex64')),
        _manifest(artifacts: manifestArtifacts()),
      );
      expect(release.artifacts.single.sha256, _hex64);
    });

    test(
      'an android artifact must declare its version code and certificate',
      () {
        for (final mutate in <void Function(Map<String, dynamic>)>[
          (e) => e.remove('androidVersionCode'),
          (e) => e['androidVersionCode'] = 0,
          (e) => e['androidVersionCode'] = '42',
          (e) => e.remove('androidCertificateSha256'),
          (e) => e['androidCertificateSha256'] = 'abc',
          (e) => e['androidCertificateSha256'] = _otherHex64.toUpperCase(),
        ]) {
          final artifacts = manifestArtifacts();
          mutate(artifacts[0]);
          expect(
            () => _parse(
              _release(assets: manifestAssets()),
              _manifest(artifacts: artifacts),
            ),
            throwsFormatException,
          );
        }
      },
    );

    test('an asset without a usable digest is skipped rather than fatal', () {
      final release = _parse(
        _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-android-arm64-v8a.apk',
              'size': 4096,
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-android-arm64-v8a.apk',
            },
            {
              'name': 'Valhalla-v1.2.3-windows-x64.zip',
              'size': 4096,
              'digest': 'sha1:$_hex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
            },
            {
              'name': 'Valhalla-v1.2.3-linux-x64.tar.gz',
              'size': 4096,
              'digest': 'sha256:nothex',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-linux-x64.tar.gz',
            },
          ],
        ),
      );
      expect(release.artifacts, isEmpty);
    });

    test('an uppercase digest hex is not accepted', () {
      final release = _parse(
        _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-windows-x64.zip',
              'size': 4096,
              'digest': 'sha256:${_hex64.toUpperCase()}',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
            },
          ],
        ),
      );
      expect(release.artifacts, isEmpty);
    });

    test('a manifest hash that is not 64 hex characters is ignored', () {
      final release = _parse(
        _release(),
        _manifest(
          artifacts: [
            {
              'name': 'Valhilla-v1.2.3-windows-x64.zip'.replaceFirst(
                'Valhilla-',
                'Valhilla-',
              ),
              'platform': 'windows',
              'architecture': 'x64',
              'sha256': 'abc',
              'size': 4096,
            },
          ],
        ),
      );
      expect(release.artifacts, isEmpty);
    });
  });

  group('artifact download url', () {
    test('the canonical repository download url is accepted', () {
      final release = _parse(_release());
      expect(
        release.artifacts.first.url.toString(),
        'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/'
        'Valhalla-v1.2.3-android-arm64-v8a.apk',
      );
    });

    test('urls outside the allowed hosts are rejected', () {
      for (final host in [
        'objects.githubusercontent.com',
        'evil.example',
        'raw.githubusercontent.com',
      ]) {
        final name = 'Valhalla-v1.2.3-windows-x64.zip';
        final release = _release(
          assets: [
            {
              'name': name,
              'size': 4096,
              'digest': 'sha256:$_hex64',
              'browser_download_url':
                  'https://$host/NornsInteractive/valhalla/releases/download/v1.2.3/$name',
            },
          ],
        );
        expect(() => _parse(release), throwsFormatException, reason: host);
      }
    });

    test('a url whose tag or file name was rewritten is rejected', () {
      for (final url in [
        'https://github.com/NornsInteractive/valhalla/releases/download/v9.9.9/Valhalla-v1.2.3-windows-x64.zip',
        'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/other.zip',
        'https://github.com/NornsInteractive/valhalla/releases/tag/v1.2.3',
        'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/a/b/Valhalla-v1.2.3-windows-x64.zip',
        'http://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
        'https://user:pass@github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
        'https://github.com:8443/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
        'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip?token=x',
      ]) {
        final release = _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-windows-x64.zip',
              'size': 4096,
              'digest': 'sha256:$_hex64',
              'browser_download_url': url,
            },
          ],
        );
        expect(() => _parse(release), throwsFormatException, reason: url);
      }
    });
  });

  group('artifact size', () {
    test('non-positive and oversized artifacts void the release', () {
      for (final size in [0, -1, 4 * 1024 * 1024 * 1024 + 1]) {
        final release = _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-windows-x64.zip',
              'size': size,
              'digest': 'sha256:$_hex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
            },
          ],
        );
        expect(() => _parse(release), throwsFormatException, reason: '$size');
      }
    });

    test('the maximum supported size is accepted', () {
      final release = _parse(
        _release(
          assets: [
            {
              'name': 'Valhalla-v1.2.3-windows-x64.zip',
              'size': 4 * 1024 * 1024 * 1024,
              'digest': 'sha256:$_hex64',
              'browser_download_url':
                  'https://github.com/NornsInteractive/valhalla/releases/download/v1.2.3/Valhalla-v1.2.3-windows-x64.zip',
            },
          ],
        ),
      );
      expect(release.artifacts.single.size, 4 * 1024 * 1024 * 1024);
    });
  });

  group('release level guards', () {
    test(
      'draft and prerelease payloads are gated by the network check, not the parser',
      () {
        expect(_parse(_release(draft: true)).version, '1.2.3');
        expect(_parse(_release(prerelease: true)).version, '1.2.3');
      },
    );

    test('a missing assets list is fatal', () {
      final release = _release();
      release.remove('assets');
      expect(() => _parse(release), throwsA(isA<TypeError>()));
    });

    test('artifacts are exposed as an unmodifiable list', () {
      final release = _parse(_release());
      expect(
        () => release.artifacts.add(
          AppUpdateArtifact(
            name: 'x',
            platform: 'p',
            architecture: 'a',
            size: 1,
            sha256: _hex64,
            url: Uri.parse('https://github.com/x'),
          ),
        ),
        throwsUnsupportedError,
      );
    });
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
