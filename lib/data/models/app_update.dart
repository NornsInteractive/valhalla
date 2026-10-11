const valhallaRepositoryUrl = 'https://github.com/NornsInteractive/valhalla';
const valhallaReleasesUrl = '$valhallaRepositoryUrl/releases';

class AppUpdateArtifact {
  final String name;
  final String platform;
  final String architecture;
  final int size;
  final String sha256;
  final Uri url;
  final int? androidVersionCode;
  final String? androidCertificateSha256;

  const AppUpdateArtifact({required this.name, required this.platform,
    required this.architecture, required this.size, required this.sha256,
    required this.url, this.androidVersionCode, this.androidCertificateSha256});
}

class AppUpdateRelease {
  final String version;
  final int? buildNumber;
  final String? sourceCommit;
  final String notes;
  final Uri page;
  final List<AppUpdateArtifact> artifacts;

  const AppUpdateRelease({required this.version, this.buildNumber,
    this.sourceCommit, required this.notes, required this.page,
    required this.artifacts});

  bool isNewerThan(String installedVersion, int installedBuild) {
    final order = compareVersions(version, installedVersion);
    return order > 0 || order == 0 && buildNumber != null && buildNumber! > installedBuild;
  }

  static int compareVersions(String left, String right) {
    List<int> parse(String value) {
      final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(value);
      if (match == null) throw const FormatException('UPDATE_VERSION_INVALID');
      return [int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!)];
    }
    final a = parse(left);
    final b = parse(right);
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  AppUpdateArtifact? artifactFor(String platform, List<String> architectures) {
    for (final arch in architectures) {
      for (final artifact in artifacts) {
        if (artifact.platform == platform && artifact.architecture == arch) return artifact;
      }
    }
    return null;
  }
}
