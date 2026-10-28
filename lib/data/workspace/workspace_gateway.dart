/// Workspace IO is attached after startup; local repositories remain usable offline.
abstract interface class WorkspaceGateway {
  String get deviceId;
  bool isEnabled(String serverId);
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  );
  Future<void> putRecords(String serverId, List<Map<String, dynamic>> records);
  Stream<WorkspaceChange> get changes;
}

class WorkspaceChange {
  final String serverId;
  final List<Map<String, dynamic>> records;
  const WorkspaceChange(this.serverId, this.records);
}
