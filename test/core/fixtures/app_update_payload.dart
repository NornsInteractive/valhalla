import 'package:valhalla/data/models/app_update.dart';

const updateHashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const updateHashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Uri updateDownloadUrl({
  String id = 'pkg_linux',
  int code = 2042,
  String channel = 'default',
}) => Uri.parse('$valhallaDistributionUrl/api/v1/app/download').replace(
  queryParameters: {
    'app_id': valhallaDistributionAppId,
    'version_code': '$code',
    'channel': channel,
    'package_id': id,
  },
);

Map<String, dynamic> updatePackage({
  String platform = 'linux',
  String arch = 'x86_64',
  String version = '1.2.3',
  int build = 42,
  int code = 2042,
  String? id,
  String hash = updateHashA,
  int size = 4096,
}) {
  final packageId = id ?? 'pkg_${platform}_${arch.replaceAll('-', '_')}';
  final fileArch = arch == 'x86_64' && platform != 'android'
      ? 'x64'
      : arch == 'apple-silicon'
      ? 'arm64'
      : arch == 'arm64-v8a' && platform != 'android'
      ? 'arm64'
      : arch;
  final suffix = platform == 'android'
      ? '-signed-$build.apk'
      : platform == 'linux'
      ? '.tar.gz'
      : '.zip';
  return {
    'id': packageId,
    'platform': platform,
    'arch': arch,
    'file_name': 'valhalla-v$version-$platform-$fileArch$suffix',
    'file_size': size,
    'file_sha256': hash,
    'download_url': updateDownloadUrl(id: packageId, code: code).toString(),
  };
}

Map<String, dynamic> updatePayload({
  String versionName = '1.2.3+42',
  int code = 2042,
  int currentCode = 0,
  String? notes = 'notes',
  List<Map<String, dynamic>>? packages,
}) {
  final entries = packages ?? [updatePackage()];
  final first = entries.isEmpty ? updatePackage() : entries.first;
  return {
    'code': 0,
    'data': {
      'app_id': valhallaDistributionAppId,
      'latest_version_name': versionName,
      'latest_version_code': code,
      'current_version_code': currentCode,
      'channel': 'default',
      'has_update': true,
      'is_force': false,
      'changelog': notes,
      'file_name': first['file_name'],
      'download_url': first['download_url'],
      'file_size': first['file_size'],
      'file_sha256': first['file_sha256'],
      'packages': entries,
    },
  };
}
