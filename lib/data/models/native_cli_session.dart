enum NativeCliKind { codex, openCode, claude, terminal }

class NativeCliSession {
  final String id;
  final String resumeId;
  final String title;
  final String? cwd;
  final DateTime? updatedAt;

  /// Optional metadata used by launcher and UI-only session fixtures. Native
  /// protocols may omit these values, so they never participate in identity.
  final String? agentId;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  const NativeCliSession({
    required this.id,
    String? resumeId,
    required this.title,
    this.cwd,
    this.updatedAt,
    this.agentId,
    this.createdAt,
    this.lastActiveAt,
  }) : resumeId = resumeId ?? id;

  /// Readable alias for composer/UI consumers; keeps the transport field name
  /// (`cwd`) compatible with Codex and OpenCode payloads.
  String? get workingDirectory => cwd;
}

class NativeCliMessage {
  final String id;
  final String role;
  final String text;
  const NativeCliMessage({
    required this.id,
    required this.role,
    required this.text,
  });
}

class NativeCliApproval {
  final String id;
  final String method;
  final Map<String, dynamic> details;
  const NativeCliApproval({
    required this.id,
    required this.method,
    required this.details,
  });
}

class NativeCliPage {
  final List<NativeCliSession> sessions;
  final String? cursor;
  const NativeCliPage(this.sessions, {this.cursor});
}

class NativeCliMessagePage {
  final List<NativeCliMessage> messages;
  final String? olderCursor;
  const NativeCliMessagePage(this.messages, {this.olderCursor});
}

NativeCliKind nativeCliKind(String command) =>
    switch (command.trim().split('/').last) {
      'codex' => NativeCliKind.codex,
      'opencode' => NativeCliKind.openCode,
      'claude' => NativeCliKind.claude,
      _ => NativeCliKind.terminal,
    };
