import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/remote_workspace.dart';
import '../../data/storage/local_storage_service.dart';
import '../../data/workspace/workspace_gateway.dart';
import '../../data/workspace/workspace_file_drafts.dart';
import '../../data/workspace/workspace_nas_sync.dart';
import '../services/remote_workspace_service.dart';
import 'agent_registry_provider.dart';
import 'app_visibility_provider.dart';
import 'nas_sources_provider.dart';
import 'nas_provider.dart';
import 'server_provider.dart';
import 'settings_provider.dart';
import 'storage_providers.dart';
import 'terminal_settings_provider.dart';

export '../../data/models/remote_workspace.dart';

final workspaceDeviceClassProvider = Provider<String>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) return 'desktop';
  final view = PlatformDispatcher.instance.views.firstOrNull;
  if (view == null) return 'phone';
  return view.physicalSize.shortestSide / view.devicePixelRatio >= 600
      ? 'tablet'
      : 'phone';
});

const _terminalSettingKeys = {
  'valhalla_terminal_use_tmux_v1',
  'valhalla_terminal_font_size_v1',
  'valhalla_terminal_pinned_keys_v1',
  'valhalla_terminal_accessory_v2',
  'valhalla_terminal_grid_v1',
  'valhalla_terminal_grid_v2',
};

String? _recordKey(Map<String, dynamic> record) {
  final value = record['value'];
  if (value is Map) {
    if (value['storageKey'] case final String key) return key;
    if (value['key'] case final String key) return key;
  }
  final id = record['id'];
  return id is String ? id : null;
}

/// Refreshes only the domains that actually changed. Own commit ACKs are not
/// reported as hydrated, so a 10-second sync no longer restarts every agent
/// probe or resets unrelated settings/views.
void _hydrateDomains(Ref ref, WorkspaceChange change) {
  var settings = false;
  var terminal = false;
  var agents = false;
  var nas = false;
  for (final record in change.records) {
    if (record['kind'] == 'draft') continue;
    final key = _recordKey(record);
    if (key == null) continue;
    if (key == 'valhalla_agents_v1' ||
        key.startsWith('valhalla_default_agent_')) {
      agents = true;
      continue;
    }
    if (key == 'valhalla_quick_commands_v1') {
      continue;
    }
    if (key == 'valhalla_nas_sources_v1' ||
        key == 'valhalla_nas_scan_configs_v1' ||
        key.startsWith('valhalla_nas_')) {
      nas = true;
      continue;
    }
    if (_terminalSettingKeys.contains(key)) {
      terminal = true;
      settings = true;
      continue;
    }
    if (LocalStorageService.configurationPreferenceTypes.containsKey(key) ||
        key == 'valhalla_app_store_view_mode_v1') {
      settings = true;
    }
  }
  if (settings) ref.invalidate(settingsProvider);
  if (terminal) ref.invalidate(terminalSettingsProvider);
  if (nas) {
    unawaited(ref.read(nasSourcesProvider.notifier).refreshFromWorkspace());
  }
  if (agents) {
    unawaited(ref.read(agentRegistryProvider.notifier).refresh());
  }
}

final remoteWorkspaceServiceProvider = Provider<RemoteWorkspaceService>((ref) {
  final service = RemoteWorkspaceService(
    storage: ref.watch(localStorageServiceProvider),
    manager: ref.watch(sshClientManagerProvider),
    deviceClass: ref.watch(workspaceDeviceClassProvider),
    onChanged: (_) {},
    migrateLegacyBatch: (serverId) async {
      final storage = ref.read(localStorageServiceProvider);
      final raw = storage.workspacePreferences.raw;
      final key = 'valhalla_workspace_migration_v1::$serverId';
      final progress = Map<String, dynamic>.from(
        jsonDecode(raw.getString(key) ?? '{}') as Map,
      );
      if (progress['chatDone'] != true) {
        final result = await ref
            .read(chatRepositoryProvider)
            .migrateWorkspace(serverId, messageBudget: 50, sessionBudget: 5);
        progress['chatDone'] = result.done;
      }
      final owners =
          jsonDecode(raw.getString('valhalla_workspace_ownership_v1') ?? '{}')
              as Map;
      final sources = storage
          .getNasSources()
          .where(
            (source) =>
                (source.sshServerId ?? owners['nas_source/${source.id}']) ==
                serverId,
          )
          .toList();
      final completed = (progress['nasDone'] as List? ?? const [])
          .cast<String>()
          .toSet();
      final source = sources
          .where((source) => !completed.contains(source.id))
          .firstOrNull;
      if (source != null) {
        final repository = await ref.read(nasIndexRepositoryProvider.future);
        final remote = repository.remoteIndex;
        if (remote is WorkspaceNasSync &&
            await remote.migrateSource(source.id, maxBatches: 1)) {
          completed.add(source.id);
        }
      }
      progress['nasDone'] = completed.toList();
      if (!await raw.setString(key, jsonEncode(progress))) {
        throw StateError('WORKSPACE_LOCAL_SAVE_FAILED');
      }
      return progress['chatDone'] == true &&
          sources.every((source) => completed.contains(source.id));
    },
    restoreFileDraft: (server, draft) async {
      final gateway = ref.read(localStorageServiceProvider).workspaceGateway;
      if (gateway == null) throw StateError('WORKSPACE_NOT_ENABLED');
      if (ref.read(activeServerProvider)?.connectionKey !=
          server.connectionKey) {
        throw StateError('WORKSPACE_SELECTION_CHANGED');
      }
      final helper = WorkspaceFileDrafts(
        gateway: gateway,
        secureStorage: ref.read(secureStorageServiceProvider),
      );
      try {
        await helper.restore(server, draft);
      } finally {
        helper.dispose();
      }
    },
    onHydrated: (change) {
      if (!ref.mounted) return;
      _hydrateDomains(ref, change);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

class RemoteWorkspaceNotifier extends Notifier<RemoteWorkspaceState> {
  RemoteWorkspaceService get _service =>
      ref.read(remoteWorkspaceServiceProvider);
  @override
  RemoteWorkspaceState build() {
    final service = ref.watch(remoteWorkspaceServiceProvider);
    void receive(RemoteWorkspaceState value) {
      if (ref.mounted) state = value;
    }

    service.onChanged = receive;
    ref.onDispose(() {
      if (identical(service.onChanged, receive)) service.onChanged = (_) {};
    });
    void update() => service.activate(
      ref.read(activeServerProvider),
      foreground: ref.read(appVisibilityProvider),
    );
    ref.listen(activeServerProvider, (_, _) => update());
    ref.listen(serverConnectionProvider, (_, next) {
      if (next.isConnected) unawaited(service.discover());
    });
    ref.listen(appVisibilityProvider, (_, _) => update());
    Future.microtask(() {
      if (ref.mounted) update();
    });
    return service.state;
  }

  void receive(RemoteWorkspaceState value) {
    state = value;
  }

  Future<void> discover() => _service.discover();
  Future<void> enable() => _service.enable();
  Future<void> syncNow() => _service.syncNow();
  Future<void> disable() => _service.disable();
  Future<void> useAsPreferenceSource() => _service.useAsPreferenceSource();
  Future<Map<String, int>> migrationPreview() => _service.migrationPreview();
  Future<void> resolveConflict(
    WorkspaceConflict conflict, {
    required bool keepLocal,
  }) => _service.resolveConflict(conflict, keepLocal: keepLocal);
  Future<void> loadDeviceDrafts({bool append = false}) =>
      _service.loadDeviceDrafts(append: append);
  Future<void> restoreDraft(WorkspaceDraft draft) =>
      _service.restoreDraft(draft);
  Future<void> clearLocalCache() => _service.clearLocalCache();
}

final remoteWorkspaceProvider =
    NotifierProvider<RemoteWorkspaceNotifier, RemoteWorkspaceState>(
      RemoteWorkspaceNotifier.new,
    );
