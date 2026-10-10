import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/host_key_entry.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

final defaultAgentSettingsProvider = Provider<Map<String, String?>>((ref) {
  final server = ref.watch(activeServerProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return {
    'acp': server == null
        ? null
        : storage.getDefaultAgentId(server.id, cli: false),
    'cli': server == null
        ? null
        : storage.getDefaultAgentId(server.id, cli: true),
  };
});

final trustedHostsProvider =
    NotifierProvider<TrustedHostsNotifier, List<HostKeyEntry>>(
      TrustedHostsNotifier.new,
    );

class TrustedHostsNotifier extends Notifier<List<HostKeyEntry>> {
  @override
  List<HostKeyEntry> build() {
    ref.watch(serverConnectionProvider);
    return _load();
  }

  List<HostKeyEntry> _load() =>
      ref.read(localStorageServiceProvider).getHostKeys().values.toList()
        ..sort((a, b) => a.hostPort.compareTo(b.hostPort));

  Future<void> revoke(String hostPort) async {
    final servers = ref
        .read(serverListProvider)
        .where((server) => '${server.host}:${server.port}' == hostPort);
    final ids = servers.map((server) => server.id).toSet();
    final activeId = ref.read(serverConnectionProvider).activeServerId;
    if (ids.contains(activeId)) {
      ref.read(serverConnectionProvider.notifier).disconnect();
    }
    for (final id in ids) {
      ref.read(sshClientManagerProvider).disconnect(id);
    }
    await ref.read(localStorageServiceProvider).removeHostKey(hostPort);
    if (ref.mounted) state = _load();
  }
}

final securitySettingsProvider = Provider<SecuritySettingsActions>(
  SecuritySettingsActions.new,
);

class SecuritySettingsActions {
  SecuritySettingsActions(this.ref);
  final Ref ref;

  Future<void> setDefaultAgent(
    String? agentId, {
    required bool cli,
    String? expectedServerId,
  }) async {
    final server = ref.read(activeServerProvider);
    if (server == null) throw StateError('SERVER_NOT_FOUND');
    if (expectedServerId != null && server.id != expectedServerId) {
      throw StateError('SERVER_TARGET_CHANGED');
    }
    final storage = ref.read(localStorageServiceProvider);
    if (agentId != null &&
        !storage.getAgents().any(
          (agent) =>
              agent.id == agentId &&
              agent.serverId == server.id &&
              (cli || (agent.acpCommand?.trim().isNotEmpty ?? false)),
        )) {
      throw StateError('AGENT_NOT_FOUND');
    }
    await storage.setDefaultAgentId(server.id, agentId, cli: cli);
    if (ref.mounted) ref.invalidate(defaultAgentSettingsProvider);
  }

  Future<void> clearServerCredentials(List<String> serverIds) async {
    final ids = serverIds.toSet();
    final known = ref
        .read(serverListProvider)
        .map((server) => server.id)
        .toSet();
    if (!known.containsAll(ids)) throw StateError('SERVER_NOT_FOUND');
    final secure = ref.read(secureStorageServiceProvider);
    final ssh = ref.read(sshClientManagerProvider);
    void disconnectSelected() {
      if (!ref.mounted) return;
      if (ids.contains(ref.read(serverConnectionProvider).activeServerId)) {
        ref.read(serverConnectionProvider.notifier).disconnect();
      }
      for (final id in ids) {
        ssh.disconnect(id);
      }
    }

    disconnectSelected();
    var failed = false;
    try {
      for (final id in ids) {
        try {
          await secure.clearCredentialsStrict(id);
        } catch (_) {
          failed = true;
        }
      }
    } finally {
      disconnectSelected();
    }
    if (failed) throw StateError('SERVER_CREDENTIALS_CLEAR_FAILED');
  }
}
