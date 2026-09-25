import '../ssh/ssh_client_manager.dart';

class DirectoryUsage {
  final String path;
  final int usedKiB;
  const DirectoryUsage(this.path, this.usedKiB);
}

class RootDiskUsage {
  final int totalKiB;
  final int usedKiB;
  final int availableKiB;
  final List<DirectoryUsage> directories;
  final bool partial;

  const RootDiskUsage({
    required this.totalKiB,
    required this.usedKiB,
    required this.availableKiB,
    required this.directories,
    required this.partial,
  });
}

class DiskUsageService {
  final SshCommandExecutor ssh;
  const DiskUsageService(this.ssh);

  Future<RootDiskUsage> root(String serverId) async {
    final df = await ssh.executeWithLoginShell(serverId, 'df -kP /');
    if (!df.isSuccess) throw StateError('DISK_DF_FAILED');
    final line = df.stdout.trim().split('\n').skip(1).firstOrNull;
    final columns = line?.trim().split(RegExp(r'\s+')) ?? const <String>[];
    if (columns.length < 6) throw const FormatException('Invalid df output');
    final total = int.parse(columns[1]);
    final used = int.parse(columns[2]);
    final available = int.parse(columns[3]);

    try {
      final du = await ssh.executeWithLoginShell(
        serverId,
        'du -x -k -d1 / 2>/dev/null',
        timeout: const Duration(seconds: 30),
      );
      final directories = parseDirectories(du.stdout);
      return RootDiskUsage(
        totalKiB: total,
        usedKiB: used,
        availableKiB: available,
        directories: directories,
        partial: !du.isSuccess,
      );
    } catch (_) {
      return RootDiskUsage(
        totalKiB: total,
        usedKiB: used,
        availableKiB: available,
        directories: const [],
        partial: true,
      );
    }
  }

  static List<DirectoryUsage> parseDirectories(String output) {
    final result = <DirectoryUsage>[];
    for (final line in output.split('\n')) {
      final separator = line.indexOf('\t');
      if (separator < 0) continue;
      final size = int.tryParse(line.substring(0, separator));
      final path = line.substring(separator + 1).trim();
      if (size == null || path == '/' || !RegExp(r'^/[^/]+$').hasMatch(path)) {
        continue;
      }
      result.add(DirectoryUsage(path, size));
    }
    result.sort((a, b) => b.usedKiB.compareTo(a.usedKiB));
    return result;
  }
}
