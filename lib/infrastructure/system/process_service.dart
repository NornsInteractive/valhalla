import '../ssh/ssh_client_manager.dart';

class ProcessInfo {
  final int pid;
  final double cpuPercent;
  final double memoryPercent;
  final int rssKiB;
  final String state;
  final String command;

  const ProcessInfo({
    required this.pid,
    required this.cpuPercent,
    required this.memoryPercent,
    this.rssKiB = 0,
    required this.state,
    required this.command,
  });

  static List<ProcessInfo> parseLines(Iterable<String> lines) {
    final result = <ProcessInfo>[];
    for (final line in lines.skip(1)) {
      final parts = line.split('|');
      if (parts.length < 5) continue;
      final pid = int.tryParse(parts[0].trim());
      if (pid == null) continue;
      final hasRss = parts.length >= 6;
      result.add(
        ProcessInfo(
          pid: pid,
          cpuPercent: double.tryParse(parts[1].trim()) ?? 0,
          memoryPercent: double.tryParse(parts[2].trim()) ?? 0,
          rssKiB: hasRss ? int.tryParse(parts[3].trim()) ?? 0 : 0,
          state: parts[hasRss ? 4 : 3].trim(),
          command: parts.sublist(hasRss ? 5 : 4).join('|').trim(),
        ),
      );
    }
    return result;
  }
}

class ProcessService {
  final SSHClientManager _sshManager;

  ProcessService(this._sshManager);

  Future<List<ProcessInfo>> list(String serverId) async {
    final result = await _sshManager.executeWithLoginShell(
      serverId,
      r'''ps -eo pid=,pcpu=,pmem=,rss=,stat=,comm= --sort=-pcpu | awk 'BEGIN { print "PID|CPU|MEM|RSS|STAT|COMMAND" } { gsub(/^ +| +$/, "", $0); print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 }' ''',
    );
    if (!result.isSuccess) throw StateError('PROCESS_QUERY_FAILED');
    return ProcessInfo.parseLines(result.stdout.split('\n'));
  }

  Future<SSHExecutionResult> terminate(
    String serverId,
    int pid, {
    bool force = false,
  }) {
    if (pid <= 1) {
      throw ArgumentError.value(
        pid,
        'pid',
        'Refusing to terminate system init',
      );
    }
    return _sshManager.executeWithLoginShell(
      serverId,
      'kill ${force ? '-9' : '-15'} $pid',
    );
  }
}
