import '../ssh/ssh_client_manager.dart';

class SystemdServiceInfo {
  final String name;
  final String description;
  final String state;
  final String startup;

  const SystemdServiceInfo({
    required this.name,
    required this.description,
    required this.state,
    required this.startup,
  });

  bool get isRunning => state == 'running';
  bool get isFailed => state == 'failed';
  bool get isEnabled => startup == 'enabled';

  static List<SystemdServiceInfo> parseLines(Iterable<String> lines) {
    final result = <SystemdServiceInfo>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 4 || parts[0].trim().isEmpty) continue;
      result.add(
        SystemdServiceInfo(
          name: parts[0].trim(),
          description: parts[1].trim(),
          state: parts[2].trim(),
          startup: parts[3].trim(),
        ),
      );
    }
    return result;
  }
}

class ServiceManager {
  final SSHClientManager _sshManager;

  ServiceManager(this._sshManager);

  Future<List<SystemdServiceInfo>> list(String serverId) async {
    final result = await _sshManager.executeWithLoginShell(
      serverId,
      r'''systemctl list-units --type=service --all --plain --no-legend --no-pager | awk '{unit=$1; sub(/\.service$/, "", unit); state=$4; print $1 "|" unit "|" state "|unknown"}' ''',
    );
    if (!result.isSuccess) return const [];
    return SystemdServiceInfo.parseLines(result.stdout.split('\n'));
  }

  Future<SSHExecutionResult> action(
    String serverId,
    String service,
    String action,
  ) {
    const allowed = {'start', 'stop', 'restart', 'reload', 'enable', 'disable'};
    if (!allowed.contains(action)) {
      throw ArgumentError.value(action, 'action', 'Unsupported systemd action');
    }
    final safeService = service.replaceAll(RegExp(r'[^a-zA-Z0-9_.@:-]'), '');
    if (safeService.isEmpty) throw ArgumentError.value(service, 'service');
    return _sshManager.executeWithLoginShell(
      serverId,
      'systemctl $action $safeService',
    );
  }
}
