import '../ssh/ssh_client_manager.dart';

class SystemHardwareInfo {
  final String? cpuModel;
  final int? cpuCores;
  final int? memoryTotalKiB;
  final int? rootDiskTotalKiB;
  final String? distribution;
  final String? kernel;

  const SystemHardwareInfo({
    this.cpuModel,
    this.cpuCores,
    this.memoryTotalKiB,
    this.rootDiskTotalKiB,
    this.distribution,
    this.kernel,
  });

  static SystemHardwareInfo parse(String output) {
    final values = <String, String>{};
    for (final line in output.split('\n')) {
      final separator = line.indexOf('=');
      if (separator < 1) continue;
      values[line.substring(0, separator)] = line
          .substring(separator + 1)
          .trim()
          .replaceAll(RegExp(r'^"|"$'), '');
    }
    String? value(String key) {
      final result = values[key];
      return result == null || result.isEmpty ? null : result;
    }

    return SystemHardwareInfo(
      cpuModel: value('CPU_MODEL'),
      cpuCores: int.tryParse(value('CPU_CORES') ?? ''),
      memoryTotalKiB: int.tryParse(value('MEMORY_KIB') ?? ''),
      rootDiskTotalKiB: int.tryParse(value('ROOT_KIB') ?? ''),
      distribution: value('DISTRIBUTION'),
      kernel: value('KERNEL'),
    );
  }
}

class SystemHardwareService {
  final SshCommandExecutor ssh;
  const SystemHardwareService(this.ssh);

  Future<SystemHardwareInfo> read(String serverId) async {
    const command =
        r'''printf 'CPU_MODEL='; awk -F: '/^(model name|Hardware|Processor)[[:space:]]*:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo
printf 'CPU_CORES='; getconf _NPROCESSORS_ONLN 2>/dev/null || true
printf 'MEMORY_KIB='; awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo
printf 'ROOT_KIB='; df -kP / 2>/dev/null | awk 'NR==2 {print $2}'
printf 'DISTRIBUTION='; awk -F= '/^PRETTY_NAME=/ {print $2; exit}' /etc/os-release 2>/dev/null
printf 'KERNEL='; uname -r 2>/dev/null''';
    final result = await ssh.executeWithLoginShell(
      serverId,
      command,
      timeout: const Duration(seconds: 8),
    );
    if (!result.isSuccess && result.stdout.trim().isEmpty) {
      throw StateError('HARDWARE_QUERY_FAILED');
    }
    return SystemHardwareInfo.parse(result.stdout);
  }
}
