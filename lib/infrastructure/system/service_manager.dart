import 'dart:convert';
import '../../core/errors/app_exceptions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/utils/shell_quote.dart';
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
      'LC_ALL=C systemctl list-units --type=service --all --plain --no-legend --no-pager',
    );
    _requireSuccess(result);
    final files = await _sshManager.executeWithLoginShell(serverId,
      'LC_ALL=C systemctl list-unit-files --type=service --no-legend --no-pager');
    _requireSuccess(files);
    return parseCatalog(result.stdout, files.stdout);
  }

  static List<SystemdServiceInfo> parseCatalog(String units, String unitFiles) {
    final startup = <String, String>{};
    for (final row in unitFiles.split('\n')) {
      final fields = row.trim().split(RegExp(r'\s+'));
      if (fields.length >= 2 && fields.first.endsWith('.service')) {
        startup[fields.first] = fields[1];
      }
    }
    final catalog = <String, SystemdServiceInfo>{};
    for (final row in units.split('\n')) {
      final match = RegExp(r'^\s*(\S+\.service)\s+\S+\s+\S+\s+(\S+)\s*(.*)$')
          .firstMatch(row);
      if (match == null) continue;
      final name = match[1]!;
      catalog[name] = SystemdServiceInfo(name: name, description: match[3]!,
        state: match[2]!, startup: startup[name] ?? 'unknown');
    }
    for (final entry in startup.entries) {
      catalog.putIfAbsent(entry.key, () => SystemdServiceInfo(name: entry.key,
        description: entry.key, state: 'not-loaded', startup: entry.value));
    }
    return catalog.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  static void _requireSuccess(SSHExecutionResult result) {
    if (result.isSuccess) return;
    final detail = LogSanitizer.sanitize(result.stderr.trim());
    final code = result.exitCode == 127 ? 'SERVICE_UNSUPPORTED'
        : detail.toLowerCase().contains('permission') ||
          detail.toLowerCase().contains('access denied')
          ? 'SERVICE_PERMISSION_DENIED' : 'SERVICE_QUERY_FAILED';
    throw SystemExecutionException(code, exitCode: result.exitCode, details: detail);
  }

  static String validateService(String service) {
    if (service.length > 255 || !RegExp(r'^[a-zA-Z0-9_][a-zA-Z0-9_.@:\\-]*\.service$')
        .hasMatch(service)) {
      throw ArgumentError.value(service, 'service', 'Invalid exact unit name');
    }
    return service;
  }

  Future<List<Map<String, dynamic>>> logs(String serverId, String service,
      {String? beforeCursor}) async {
    validateService(service);
    if (beforeCursor != null && (beforeCursor.length > 1024 ||
        beforeCursor.contains(RegExp(r'[\x00-\x1f]')))) {
      throw ArgumentError.value(beforeCursor, 'beforeCursor');
    }
    final result = await _sshManager.executeWithLoginShell(serverId,
      'LC_ALL=C journalctl --unit=${cliShellQuote(service)} --no-pager '
      '--output=json --lines=200 --reverse${beforeCursor == null ? '' : ' --cursor=${cliShellQuote(beforeCursor)}'}');
    _requireSuccess(result);
    final rows = <Map<String, dynamic>>[];
    for (final line in result.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final record = jsonDecode(line) as Map<String, dynamic>;
      if (record['__CURSOR'] == beforeCursor) continue;
      rows.add(record);
    }
    return rows;
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
    validateService(service);
    return _sshManager.executeWithLoginShell(
      serverId,
      'systemctl $action -- ${cliShellQuote(service)}',
    );
  }
}
