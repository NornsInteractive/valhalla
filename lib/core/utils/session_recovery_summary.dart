import '../../data/models/session_recovery_status.dart';

enum SessionRecoveryMode { acp, cli }

typedef SessionRecoveryEntry = ({
  SessionRecoveryMode mode,
  SessionRecoveryStatus status,
});

/// Orders active recovery targets without reading or changing their sessions.
List<SessionRecoveryEntry> sessionRecoveryEntries({
  required SessionRecoveryStatus acp,
  required SessionRecoveryStatus cli,
  SessionRecoveryMode? preferredMode,
}) {
  final entries = <SessionRecoveryEntry>[
    if (acp != SessionRecoveryStatus.idle)
      (mode: SessionRecoveryMode.acp, status: acp),
    if (cli != SessionRecoveryStatus.idle)
      (mode: SessionRecoveryMode.cli, status: cli),
  ];

  int priority(SessionRecoveryEntry entry) {
    if (entry.mode == preferredMode) return 0;
    return switch (entry.status) {
      SessionRecoveryStatus.failed => 1,
      SessionRecoveryStatus.incomplete => 2,
      SessionRecoveryStatus.reconnecting || SessionRecoveryStatus.syncing => 3,
      SessionRecoveryStatus.idle => 4,
    };
  }

  entries.sort((a, b) {
    final byPriority = priority(a).compareTo(priority(b));
    return byPriority != 0 ? byPriority : a.mode.index.compareTo(b.mode.index);
  });
  return entries;
}
