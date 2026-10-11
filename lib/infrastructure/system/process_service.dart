import '../ssh/ssh_client_manager.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/shell_quote.dart';

class ProcessInfo {
  final int pid;
  final double cpuPercent;
  final double memoryPercent;
  final int rssKiB;
  final String state;
  final String command;
  final String? startedAt;

  const ProcessInfo({
    required this.pid,
    required this.cpuPercent,
    required this.memoryPercent,
    this.rssKiB = 0,
    required this.state,
    required this.command,
    this.startedAt,
  });

  static List<ProcessInfo> parseLines(Iterable<String> lines) {
    final rows = lines.toList();
    if (rows.isEmpty) return const [];
    final header = rows.first.split('|');
    final hasRss = header.contains('RSS');
    final hasStarted = header.contains('STARTED');
    final result = <ProcessInfo>[];
    for (final line in rows.skip(1)) {
      final parts = line.split('|');
      final commandIndex = hasStarted ? 6 : hasRss ? 5 : 4;
      if (parts.length <= commandIndex) continue;
      final pid = int.tryParse(parts[0].trim());
      if (pid == null) continue;
      result.add(
        ProcessInfo(
          pid: pid,
          cpuPercent: double.tryParse(parts[1].trim()) ?? 0,
          memoryPercent: double.tryParse(parts[2].trim()) ?? 0,
          rssKiB: hasRss ? int.tryParse(parts[3].trim()) ?? 0 : 0,
          state: parts[hasRss ? 4 : 3].trim(),
          startedAt: hasStarted ? parts[5].trim() : null,
          command: parts.sublist(commandIndex).join('|').trim(),
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
      r'''rows=$(LC_ALL=C ps -eo pid=,pcpu=,pmem=,rss=,stat=,lstart=,comm= --sort=-pcpu) || exit $?; printf '%s\n' "$rows" | awk 'BEGIN { print "PID|CPU|MEM|RSS|STAT|STARTED|COMMAND" } { print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 " " $7 " " $8 " " $9 " " $10 "|" $11 }' ''',
    );
    if (!result.isSuccess) throw StateError('PROCESS_QUERY_FAILED');
    return ProcessInfo.parseLines(result.stdout.split('\n'));
  }

  Future<SSHExecutionResult> terminate(
    String serverId,
    int pid, {
    bool force = false,
    String? expectedStartedAt,
  }) {
    if (pid <= 1) {
      throw ArgumentError.value(
        pid,
        'pid',
        'Refusing to terminate system init',
      );
    }
    if (expectedStartedAt == null || expectedStartedAt.trim().isEmpty) {
      throw const ValidationException('PROCESS_IDENTITY_UNAVAILABLE');
    }
    // shortcut: ps/kill retains a small PID-reuse window; strict exclusion
    // requires a server-side pidfd helper rather than portable shell commands.
    return _sshManager.executeWithLoginShell(
      serverId,
      'started=\$(LC_ALL=C ps -p $pid -o lstart=) || exit 1; '
      'started=\$(printf "%s" "\$started" | awk \'{\$1=\$1;print}\'); '
      '[ "\$started" = ${cliShellQuote(expectedStartedAt)} ] || '
      '{ printf "%s\\n" PROCESS_IDENTITY_CHANGED >&2; exit 75; }; '
      'kill ${force ? '-9' : '-15'} -- $pid',
    );
  }
}
