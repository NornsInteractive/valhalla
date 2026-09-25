import 'dart:convert';

import '../../core/errors/app_exceptions.dart';
import '../ssh/ssh_client_manager.dart';
import '../terminal/terminal_session_bridge.dart';
import 'package:xterm/xterm.dart';

enum DockerContainerState {
  running,
  exited,
  paused,
  restarting,
  created,
  unknown,
}

enum DockerTerminalShell { bash, sh }

class DockerContainer {
  final String id;
  final String name;
  final String image;
  final String status;
  final DockerContainerState state;
  final String ports;
  final DateTime? createdAt;

  const DockerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    required this.ports,
    this.createdAt,
  });

  factory DockerContainer.fromJson(Map<String, dynamic> json) {
    final rawState = (json['state'] as String? ?? '').toLowerCase();
    final state = DockerContainerState.values.firstWhere(
      (value) => value.name == rawState,
      orElse: () => DockerContainerState.unknown,
    );
    return DockerContainer(
      id: json['id'] as String? ?? '',
      name: json['names'] as String? ?? json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
      status: json['status'] as String? ?? '',
      state: state,
      ports: json['ports'] as String? ?? '',
      createdAt: _parseCreated(json['created'] as String?),
    );
  }

  static DockerContainer fromJsonLine(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Docker container line must be a JSON object',
      );
    }
    return DockerContainer.fromJson(decoded);
  }

  static List<DockerContainer> parseLines(Iterable<String> lines) {
    final result = <DockerContainer>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        result.add(fromJsonLine(line));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return result;
  }

  static DateTime? _parseCreated(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' UTC', 'Z'));
  }
}

class DockerContainerUser {
  final String name;
  final int uid;
  final int gid;
  const DockerContainerUser({
    required this.name,
    required this.uid,
    required this.gid,
  });

  String get executionValue => name;
}

class DockerCliService {
  final SshCommandExecutor _sshManager;

  DockerCliService(this._sshManager);

  Future<({TerminalSessionBridge bridge, DockerTerminalShell shell})>
  openTerminal(
    String serverId,
    DockerContainer container,
    String serverName, {
    DockerTerminalShell preferredShell = DockerTerminalShell.bash,
  }) async {
    if (container.state != DockerContainerState.running) {
      throw StateError('DOCKER_CONTAINER_NOT_RUNNING');
    }
    final client = _sshManager.getClient(serverId);
    if (client == null || client.isClosed) {
      throw const SSHConnectionException('Server is not connected');
    }
    Future<SSHExecutionResult> probe(DockerTerminalShell shell) =>
        _sshManager.executeWithLoginShell(
          serverId,
          'docker exec ${_quote(container.id)} ${shell.name} -c :',
          timeout: const Duration(seconds: 8),
        );
    var shell = preferredShell;
    var result = await probe(shell);
    if (!result.isSuccess && shell == DockerTerminalShell.bash) {
      shell = DockerTerminalShell.sh;
      result = await probe(shell);
    }
    if (!result.isSuccess) {
      throw DockerExecutionException(
        result.stderr.trim().isEmpty
            ? 'Container shell unavailable'
            : result.stderr.trim(),
        exitCode: result.exitCode,
      );
    }
    final bridge = TerminalSessionBridge(
      terminal: Terminal(maxLines: 1500),
      sshClient: client,
      serverName: serverName,
      serverId: serverId,
      remoteExecCommand:
          'docker exec -it ${_quote(container.id)} ${shell.name}',
    );
    return (bridge: bridge, shell: shell);
  }

  Future<List<DockerContainer>> listContainers(String serverId) async {
    final result = await _sshManager.executeWithLoginShell(
      serverId,
      r'''docker ps -a --no-trunc --format '{"id":"{{.ID}}","names":"{{.Names}}","image":"{{.Image}}","status":"{{.Status}}","state":"{{.State}}","ports":"{{.Ports}}","created":"{{.CreatedAt}}"}' ''',
    );
    if (!result.isSuccess) {
      throw DockerExecutionException(
        result.stderr.trim().isEmpty
            ? 'Docker query failed'
            : result.stderr.trim(),
        exitCode: result.exitCode,
      );
    }
    return DockerContainer.parseLines(result.stdout.split('\n'));
  }

  /// Lists passwd entries in a running container. The caller may still enter
  /// an arbitrary Docker `--user` value when a minimal image has no passwd.
  Future<List<DockerContainerUser>> listContainerUsers(
    String serverId,
    String containerReference,
  ) async {
    final result = await _sshManager.executeWithLoginShell(
      serverId,
      'docker exec -i ${_quote(containerReference)} cat /etc/passwd',
    );
    if (!result.isSuccess) {
      throw DockerExecutionException(
        result.stderr.trim().isEmpty
            ? 'Container user query failed'
            : result.stderr.trim(),
        exitCode: result.exitCode,
      );
    }
    return result.stdout
        .split('\n')
        .map((line) {
          final fields = line.split(':');
          if (fields.length < 4) return null;
          final uid = int.tryParse(fields[2]);
          final gid = int.tryParse(fields[3]);
          if (fields[0].isEmpty || uid == null || gid == null) return null;
          return DockerContainerUser(name: fields[0], uid: uid, gid: gid);
        })
        .whereType<DockerContainerUser>()
        .toList();
  }

  Future<SSHExecutionResult> lifecycle(
    String serverId,
    String action,
    String containerId,
  ) {
    const allowed = {'start', 'stop', 'restart', 'pause', 'unpause', 'rm'};
    if (!allowed.contains(action)) {
      throw ArgumentError.value(
        action,
        'action',
        'Unsupported Docker lifecycle action',
      );
    }
    return _sshManager.executeWithLoginShell(
      serverId,
      'docker $action ${_quote(containerId)}',
    );
  }

  Future<Map<String, dynamic>> inspect(
    String serverId,
    String containerId,
  ) async {
    final result = await _sshManager.executeWithLoginShell(
      serverId,
      'docker inspect ${_quote(containerId)}',
    );
    if (!result.isSuccess) {
      throw DockerExecutionException(
        result.stderr.trim().isEmpty
            ? 'Docker inspect failed'
            : result.stderr.trim(),
        exitCode: result.exitCode,
      );
    }
    final decoded = jsonDecode(result.stdout);
    if (decoded is! List ||
        decoded.isEmpty ||
        decoded.first is! Map<String, dynamic>) {
      throw const FormatException(
        'Docker inspect returned an unexpected payload',
      );
    }
    return Map<String, dynamic>.from(decoded.first as Map);
  }

  Future<SSHExecutionResult> rename(
    String serverId,
    String containerId,
    String newName,
  ) {
    return _sshManager.executeWithLoginShell(
      serverId,
      'docker rename ${_quote(containerId)} ${_quote(newName)}',
    );
  }

  Stream<String> streamLogs(
    String serverId,
    String containerId, {
    int tail = 100,
  }) {
    // Reuse SSH's stdout/stderr draining and cancellation/channel cleanup.
    // ponytail: a log viewer lasts at most one day; reopen for longer sessions.
    return _sshManager
        .executeStreaming(
          serverId,
          'docker logs -f --tail=${tail.clamp(0, 10000)} ${_quote(containerId)}',
          timeout: const Duration(days: 1),
        )
        .map((chunk) {
          if (chunk.exitCode != null && chunk.exitCode != 0) {
            throw DockerExecutionException(
              'Docker log stream exited unsuccessfully',
              exitCode: chunk.exitCode!,
            );
          }
          return chunk.text;
        })
        .where((text) => text.isNotEmpty);
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}
