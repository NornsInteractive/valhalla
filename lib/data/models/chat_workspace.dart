import 'dart:convert';
import 'package:path/path.dart' as p;
import 'agent_profile.dart';
import 'chat_session.dart';

/// Execution identity excludes CLI commands so upgrades do not move projects.
String chatExecutionKey(AgentProfile profile) => jsonEncode([
  profile.executionTarget,
  if (profile.executionTarget == 'docker') ...[
    profile.containerBinding,
    profile.containerReference,
    profile.containerUser,
  ],
]);

class ChatWorkspace {
  final String key, serverId, executionKey, directory;
  final List<ChatSession> sessions;
  const ChatWorkspace({
    required this.key,
    required this.serverId,
    required this.executionKey,
    required this.directory,
    required this.sessions,
  });

  static List<ChatWorkspace> group(List<ChatSession> sessions) {
    final groups = <String, List<ChatSession>>{};
    for (final session in sessions) {
      if (session.serverId == null) continue;
      final directory = p.posix.isAbsolute(session.workingDirectory)
          ? p.posix.normalize(session.workingDirectory)
          : '.';
      // Legacy history has no execution snapshot; do not infer from an edited profile.
      final execution =
          session.executionKey ?? 'legacy:${session.agentId ?? "unknown"}';
      final key = jsonEncode([session.serverId, execution, directory]);
      groups.putIfAbsent(key, () => []).add(session);
    }
    return groups.entries.map((entry) {
      final parts = jsonDecode(entry.key) as List;
      return ChatWorkspace(
        key: entry.key,
        serverId: parts[0] as String,
        executionKey: parts[1] as String,
        directory: parts[2] as String,
        sessions: List.unmodifiable(entry.value),
      );
    }).toList();
  }
}
