import 'dart:ffi';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

String distributionArchitecture(String platform, String architecture) =>
    platform == 'android' && architecture == 'arm'
    ? 'armeabi-v7a'
    : architecture == 'x64'
    ? 'x86_64'
    : architecture == 'arm64'
    ? (platform == 'macos' ? 'apple-silicon' : 'arm64-v8a')
    : architecture;

/// Uses the running application's ABI, not the device's supported ABI list.
List<String> applicationArchitectures() {
  final architecture = Abi.current().toString().split('_').last;
  return [
    Platform.isAndroid
        ? distributionArchitecture('android', architecture)
        : architecture,
    if (Platform.isMacOS) 'universal',
  ];
}

Map<String, String> appRuntimeIdentity(PackageInfo info) => {
  'applicationId': info.packageName,
  'version': info.version,
  'buildNumber': info.buildNumber,
  'platform': Platform.operatingSystem,
  'architecture': applicationArchitectures().first,
};
