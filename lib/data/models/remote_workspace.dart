enum WorkspacePhase {
  local,
  discovering,
  available,
  syncing,
  ready,
  offline,
  error,
}

class WorkspaceConflict {
  final String kind, id;
  final Object? localValue, remoteValue;
  const WorkspaceConflict({
    required this.kind,
    required this.id,
    this.localValue,
    this.remoteValue,
  });
}

class WorkspaceDraft {
  final String id, deviceId, title;
  final Map<String, dynamic> value;
  const WorkspaceDraft({
    required this.id,
    required this.deviceId,
    required this.title,
    required this.value,
  });
}

class RemoteWorkspaceState {
  final String? serverId, workspaceId, user, error;
  final WorkspacePhase phase;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final List<WorkspaceConflict> conflicts;
  final List<WorkspaceDraft> devicesDrafts;
  final bool isPreferenceSource, enabled, migrationPending, draftsHaveMore;
  const RemoteWorkspaceState({
    this.serverId,
    this.workspaceId,
    this.user,
    this.error,
    this.phase = WorkspacePhase.local,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.conflicts = const [],
    this.devicesDrafts = const [],
    this.isPreferenceSource = false,
    this.enabled = false,
    this.migrationPending = false,
    this.draftsHaveMore = false,
  });
  bool get isBusy =>
      phase == WorkspacePhase.discovering || phase == WorkspacePhase.syncing;
}
