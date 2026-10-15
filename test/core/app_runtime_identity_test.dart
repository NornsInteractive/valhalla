// Runtime identity contract tests for applicationArchitectures /
// appRuntimeIdentity.
//
// Scope: the pure helper only. PackageInfo is mocked; no device ABI probe, no
// native channels beyond the package-info mock, no production code is touched.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/core/utils/app_runtime_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Valhalla',
      packageName: 'com.norns.valhalla',
      version: '1.0.6',
      buildNumber: '7',
      buildSignature: '',
    );
  });

  test('applicationArchitectures reuses the running application ABI only', () {
    final architectures = applicationArchitectures();
    final runningAbi = Abi.current().toString().split('_').last;

    expect(architectures, isNotEmpty);
    // First entry is the actual running ABI, never a device supported-ABI
    // list: exactly one ABI, plus universal only on macOS.
    expect(
      architectures.first,
      Platform.isAndroid
          ? AppUpdateService.distributionArchitecture('android', runningAbi)
          : runningAbi,
    );
    if (Platform.isMacOS) {
      expect(
        architectures,
        containsAllInOrder(<String>[runningAbi, 'universal']),
      );
      expect(architectures, hasLength(2));
    } else {
      expect(architectures, equals(<String>[architectures.first]));
      expect(architectures, isNot(contains('universal')));
    }
  });

  test(
    'appRuntimeIdentity maps PackageInfo to bounded install identity',
    () async {
      final info = await PackageInfo.fromPlatform();
      final identity = appRuntimeIdentity(info);

      expect(identity['applicationId'], 'com.norns.valhalla');
      expect(identity['version'], '1.0.6');
      expect(identity['buildNumber'], '7');
      expect(identity['platform'], Platform.operatingSystem);
      expect(identity['architecture'], applicationArchitectures().first);

      // Exactly these keys: no secrets, no device identifiers.
      expect(
        identity.keys,
        unorderedEquals(<String>[
          'applicationId',
          'version',
          'buildNumber',
          'platform',
          'architecture',
        ]),
      );
    },
  );
}
