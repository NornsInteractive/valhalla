import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/agent_update.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/agents/agent_update_service.dart';
import '../logging/sanitizer.dart';
import 'agent_registry_provider.dart';
import 'agent_update_lock_provider.dart';
import 'ai_chat_provider.dart';
import 'app_visibility_provider.dart';
import 'cli_chat_provider.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

export '../../data/models/agent_update.dart';

class AgentUpdateEntry {
  final String? targetKey;
  final AgentUpdateReport? report;
  final bool isChecking;
  final bool isUpdating;
  final bool interrupted;
  final String? errorCode;
  final String log;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessfulCheckAt;
  final String? noticeAcknowledgedDay;
  final String? noticeAcknowledgedVersions;

  const AgentUpdateEntry({
    this.targetKey,
    this.report,
    this.isChecking = false,
    this.isUpdating = false,
    this.interrupted = false,
    this.errorCode,
    this.log = '',
    this.lastAttemptAt,
    this.lastSuccessfulCheckAt,
    this.noticeAcknowledgedDay,
    this.noticeAcknowledgedVersions,
  });

  String get availableVersions =>
      report?.components
          .where((item) => item.status == AgentUpdateStatus.available)
          .map((item) => '${item.component.name}:${item.latestVersion}')
          .join('|') ??
      '';

  AgentUpdateEntry copyWith({
    String? targetKey,
    AgentUpdateReport? report,
    bool? isChecking,
    bool? isUpdating,
    bool? interrupted,
    String? errorCode,
    bool clearError = false,
    String? log,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessfulCheckAt,
    String? noticeAcknowledgedDay,
    String? noticeAcknowledgedVersions,
  }) => AgentUpdateEntry(
    targetKey: targetKey ?? this.targetKey,
    report: report ?? this.report,
    isChecking: isChecking ?? this.isChecking,
    isUpdating: isUpdating ?? this.isUpdating,
    interrupted: interrupted ?? this.interrupted,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    log: log ?? this.log,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    lastSuccessfulCheckAt: lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
    noticeAcknowledgedDay: noticeAcknowledgedDay ?? this.noticeAcknowledgedDay,
    noticeAcknowledgedVersions:
        noticeAcknowledgedVersions ?? this.noticeAcknowledgedVersions,
  );
}

class AgentUpdatesState {
  final String? serverId;
  final Map<String, AgentUpdateEntry> agents;
  final int generation;
  final String? lastUpdatedAgentId;
  final bool showUpdateNotices;
  final String noticeDay;
  const AgentUpdatesState({
    this.serverId,
    this.agents = const {},
    this.generation = 0,
    this.lastUpdatedAgentId,
    this.showUpdateNotices = false,
    this.noticeDay = '',
  });
  int get availableCount =>
      agents.values.where((entry) => entry.report?.hasUpdates == true).length;
  bool get isChecking => agents.values.any((entry) => entry.isChecking);
  bool get isUpdating => agents.values.any((entry) => entry.isUpdating);
  int get noticeCount => !showUpdateNotices
      ? 0
      : agents.values
            .where(
              (entry) =>
                  entry.availableVersions.isNotEmpty &&
                  (entry.noticeAcknowledgedDay != noticeDay ||
                      entry.noticeAcknowledgedVersions !=
                          entry.availableVersions),
            )
            .length;
}

final agentUpdateServiceProvider = Provider<AgentUpdateService>(
  (ref) => AgentUpdateService(ref.watch(sshCommandExecutorProvider)),
);
final agentUpdateClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final agentUpdatesProvider =
    NotifierProvider<AgentUpdatesNotifier, AgentUpdatesState>(
      AgentUpdatesNotifier.new,
    );

class AgentUpdatesNotifier extends Notifier<AgentUpdatesState> {
  int _epoch = 0;
  int _checkRevision = 0;
  bool _chatEntered = false;
  final Map<(int, int, String), Future<void>> _checks = {};
  final List<Completer<void>> _waiting = [];
  int _activeChecks = 0;
  Timer? _logTimer;
  final Map<String, String> _pendingLogs = {};
  final Set<AgentUpdatePlan> _consumedPlans = Set.identity();

  @override
  AgentUpdatesState build() {
    _epoch++;
    _chatEntered = false;
    final server = ref.watch(
      activeServerProvider.select((value) => value?.connectionKey),
    );
    final active = ref.read(activeServerProvider);
    ref.listen(serverConnectionProvider, (previous, next) {
      if (next.isConnected && previous?.isConnected != true && _chatEntered) {
        unawaited(checkIfDue());
      }
    });
    ref.listen(agentRegistryProvider, (_, next) {
      if (active == null || next.serverId != active.id || !ref.mounted) return;
      final entries = <String, AgentUpdateEntry>{};
      for (final agent in next.agents) {
        final key = agentUpdateTargetKey(active, agent.profile);
        final previous = state.agents[agent.profile.id];
        entries[agent.profile.id] = previous?.targetKey == key
            ? previous!
            : previous?.isUpdating == true &&
                  isAgentUpdateLocked(ref, agent.profile)
            ? previous!.copyWith(targetKey: key)
            : _restore(active, agent.profile);
      }
      if (entries.length != state.agents.length ||
          entries.entries.any(
            (entry) => !identical(entry.value, state.agents[entry.key]),
          )) {
        state = AgentUpdatesState(
          serverId: state.serverId,
          agents: entries,
          generation: state.generation,
          lastUpdatedAgentId: state.lastUpdatedAgentId,
          showUpdateNotices: state.showUpdateNotices,
          noticeDay: state.noticeDay,
        );
      }
    });
    ref.onDispose(() {
      _epoch++;
      _logTimer?.cancel();
      _pendingLogs.clear();
    });
    if (server == null || active == null) return const AgentUpdatesState();
    final profiles = ref.read(agentRepositoryProvider).getAll(active.id);
    return AgentUpdatesState(
      serverId: active.id,
      agents: {
        for (final profile in profiles) profile.id: _restore(active, profile),
      },
    );
  }

  DateTime get _now => ref.read(agentUpdateClockProvider)();

  AgentUpdateEntry _restore(ServerProfile server, AgentProfile profile) {
    try {
      final key = agentUpdateTargetKey(server, profile);
      final record = ref
          .read(localStorageServiceProvider)
          .getAgentUpdateRecord(key);
      if (record == null || record['schema'] != 1) {
        return AgentUpdateEntry(targetKey: key);
      }
      final checked = DateTime.tryParse(record['checkedAt'] as String? ?? '');
      final attempt = DateTime.tryParse(
        record['lastAttemptAt'] as String? ?? '',
      );
      final raw = record['components'];
      final components = raw is List && raw.length <= 2
          ? raw
                .map(
                  (item) => AgentComponentUpdate.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : <AgentComponentUpdate>[];
      return AgentUpdateEntry(
        targetKey: key,
        report: checked == null
            ? null
            : AgentUpdateReport(
                agentId: profile.id,
                targetKey: key,
                checkedAt: checked,
                components: components,
              ),
        lastAttemptAt: attempt,
        lastSuccessfulCheckAt: checked,
        interrupted: record['interrupted'] == true,
        errorCode:
            record['errorCode'] as String? ??
            (record['interrupted'] == true
                ? 'AGENT_UPDATE_INTERRUPTED_RECHECK'
                : null),
        noticeAcknowledgedDay: record['noticeAcknowledgedDay'] as String?,
        noticeAcknowledgedVersions:
            record['noticeAcknowledgedVersions'] as String?,
      );
    } catch (_) {
      return AgentUpdateEntry(targetKey: agentUpdateTargetKey(server, profile));
    }
  }

  Future<void> _persist(
    ServerProfile server,
    AgentProfile profile,
    AgentUpdateEntry entry,
  ) => ref.read(localStorageServiceProvider).saveAgentUpdateRecord(
    agentUpdateTargetKey(server, profile),
    {
      'schema': 1,
      'checkedAt': entry.lastSuccessfulCheckAt?.toIso8601String(),
      'lastAttemptAt': entry.lastAttemptAt?.toIso8601String(),
      'interrupted': entry.interrupted || entry.isUpdating,
      'errorCode': entry.errorCode,
      'components':
          entry.report?.components.map((item) => item.toJson()).toList() ?? [],
      'noticeAcknowledgedDay': entry.noticeAcknowledgedDay,
      'noticeAcknowledgedVersions': entry.noticeAcknowledgedVersions,
    },
  );

  /// Called by either chat page on actual entry; mounting the provider is inert.
  Future<void> onChatEntered() {
    _chatEntered = true;
    state = AgentUpdatesState(
      serverId: state.serverId,
      agents: state.agents,
      generation: state.generation,
      lastUpdatedAgentId: state.lastUpdatedAgentId,
      showUpdateNotices: true,
      noticeDay: _day(_now),
    );
    return checkIfDue();
  }

  Future<void> dismissUpdateNotice() async {
    final server = ref.read(activeServerProvider);
    if (server == null) return;
    final epoch = _epoch;
    final profiles = ref.read(agentRepositoryProvider).getAll(server.id);
    for (final profile in profiles) {
      if (!_current(epoch, server, profile)) return;
      final entry = state.agents[profile.id];
      if (entry == null || entry.availableVersions.isEmpty) continue;
      final acknowledged = entry.copyWith(
        noticeAcknowledgedDay: _day(_now),
        noticeAcknowledgedVersions: entry.availableVersions,
      );
      _put(profile.id, acknowledged);
      try {
        await _persist(server, profile, acknowledged);
      } catch (_) {
        /* Keep dismissal for this process if storage is unavailable. */
      }
    }
  }

  Future<void> checkIfDue() async {
    if (!_chatEntered || !ref.read(appVisibilityProvider)) return;
    await checkAll(force: false);
  }

  Future<void> checkAll({bool force = true}) async {
    final server = ref.read(activeServerProvider);
    if (server == null ||
        !ref.read(sshCommandExecutorProvider).isConnected(server.id)) {
      return;
    }
    final profiles = ref.read(agentRepositoryProvider).getAll(server.id);
    await Future.wait([
      for (final profile in profiles) checkAgent(profile.id, force: force),
    ]);
  }

  bool _due(AgentUpdateEntry entry) {
    if (entry.interrupted &&
        (entry.errorCode == null ||
            entry.errorCode == 'AGENT_UPDATE_INTERRUPTED_RECHECK')) {
      return true;
    }
    final success = entry.lastSuccessfulCheckAt?.toLocal();
    final now = _now.toLocal();
    if (entry.errorCode == null &&
        success != null &&
        success.year == now.year &&
        success.month == now.month &&
        success.day == now.day) {
      return false;
    }
    final attempt = entry.lastAttemptAt;
    return attempt == null ||
        now.difference(attempt) >= const Duration(minutes: 15) ||
        attempt.isAfter(now);
  }

  Future<void> checkAgent(String agentId, {bool force = true}) {
    final key = (_epoch, _checkRevision, agentId);
    final pending = _checks[key];
    if (pending != null) return pending;
    late final Future<void> future;
    future = _checkAgent(agentId, force: force).whenComplete(() {
      if (identical(_checks[key], future)) _checks.remove(key);
    });
    return _checks[key] = future;
  }

  Future<void> _slot() async {
    if (_activeChecks >= 2) {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    } else {
      _activeChecks++;
    }
  }

  void _releaseSlot() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _activeChecks--;
    }
  }

  bool _current(int epoch, ServerProfile server, AgentProfile profile) {
    if (!ref.mounted ||
        epoch != _epoch ||
        ref.read(activeServerProvider)?.connectionKey != server.connectionKey) {
      return false;
    }
    final current = ref
        .read(agentRepositoryProvider)
        .find(server.id, profile.id);
    return current != null &&
        agentUpdateTargetKey(server, current) ==
            agentUpdateTargetKey(server, profile);
  }

  Future<void> _checkAgent(String agentId, {required bool force}) async {
    final server = ref.read(activeServerProvider);
    if (server == null ||
        !ref.read(sshCommandExecutorProvider).isConnected(server.id)) {
      return;
    }
    final profile = ref.read(agentRepositoryProvider).find(server.id, agentId);
    if (profile == null || isAgentUpdateLocked(ref, profile)) return;
    final epoch = _epoch;
    final revision = _checkRevision;
    final cached = state.agents[agentId];
    var entry = cached?.targetKey == agentUpdateTargetKey(server, profile)
        ? cached!
        : _restore(server, profile);
    if (!force && !_due(entry)) return;
    entry = entry.copyWith(
      isChecking: true,
      lastAttemptAt: _now,
      clearError: true,
    );
    _put(agentId, entry);
    await _slot();
    try {
      if (!_current(epoch, server, profile) ||
          revision != _checkRevision ||
          isAgentUpdateLocked(ref, profile)) {
        return;
      }
      await _persist(server, profile, entry);
      final report = await ref
          .read(agentUpdateServiceProvider)
          .check(server, profile, force: force);
      if (!_current(epoch, server, profile) ||
          revision != _checkRevision ||
          isAgentUpdateLocked(ref, profile)) {
        return;
      }
      final updated = (state.agents[agentId] ?? entry).copyWith(
        report: report,
        isChecking: false,
        interrupted: report.hasErrors ? null : false,
        lastSuccessfulCheckAt: report.hasErrors ? null : _now,
        errorCode: report.hasErrors ? 'AGENT_UPDATE_CHECK_FAILED' : null,
        clearError: !report.hasErrors,
      );
      _put(agentId, updated);
      await _persist(server, profile, updated);
    } catch (error) {
      if (!_current(epoch, server, profile) ||
          revision != _checkRevision ||
          isAgentUpdateLocked(ref, profile)) {
        return;
      }
      final failed = (state.agents[agentId] ?? entry).copyWith(
        isChecking: false,
        errorCode: _errorCode(error),
      );
      _put(agentId, failed);
      try {
        await _persist(server, profile, failed);
      } catch (_) {
        /* The visible failure remains retryable. */
      }
    } finally {
      _releaseSlot();
      if (_current(epoch, server, profile) &&
          revision == _checkRevision &&
          !isAgentUpdateLocked(ref, profile) &&
          state.agents[agentId]?.isChecking == true) {
        _put(agentId, state.agents[agentId]!.copyWith(isChecking: false));
      }
    }
  }

  bool _busy(String serverId) {
    final registry = ref.read(agentRegistryProvider);
    if (registry.serverId == serverId &&
        registry.agents.any((item) => item.isInstalling || item.isLoggingIn)) {
      return true;
    }
    if (ref.exists(aiChatProvider)) {
      final chat = ref.read(aiChatProvider);
      if (chat.activeAgentProfile?.serverId == serverId &&
          (chat.isGenerating ||
              chat.isLoadingSettings ||
              chat.isApplyingSettings ||
              chat.isLoadingMessages ||
              chat.isLoadingSessions ||
              chat.pendingPermission != null ||
              chat.isAuthenticating ||
              chat.authChallenge != null ||
              chat.authRequest != null ||
              ref.read(aiChatProvider.notifier).isRuntimeBusy)) {
        return true;
      }
    }
    if (ref.exists(cliChatProvider)) {
      final chat = ref.read(cliChatProvider);
      if (chat.serverId == serverId &&
          (chat.isSending ||
              chat.isLoading ||
              chat.isLoadingOlderMessages ||
              chat.terminal != null ||
              chat.approvals.isNotEmpty ||
              ref.read(cliChatProvider.notifier).isRuntimeBusy)) {
        return true;
      }
    }
    return false;
  }

  Future<AgentUpdatePlan> prepareUpdate(
    String agentId, {
    Set<AgentUpdateComponent>? components,
  }) async {
    final server = ref.read(activeServerProvider);
    if (server == null) throw const AgentUpdateException('SSH_DISCONNECTED');
    final profile = ref.read(agentRepositoryProvider).find(server.id, agentId);
    if (profile == null) {
      throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
    }
    if (_busy(server.id) || isAgentUpdateLocked(ref, profile)) {
      throw const AgentUpdateException('AGENT_UPDATE_BUSY');
    }
    final epoch = _epoch;
    final plan = await ref
        .read(agentUpdateServiceProvider)
        .prepare(server, profile, components: components);
    if (!_current(epoch, server, profile)) {
      throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
    }
    return plan;
  }

  /// Only invoke with the exact plan displayed in an explicit confirmation.
  Future<void> applyConfirmedUpdate(AgentUpdatePlan plan) async {
    final epoch = _epoch;
    if (!_current(epoch, plan.server, plan.profile) ||
        _consumedPlans.contains(plan)) {
      throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
    }
    if (_busy(plan.server.id)) {
      throw const AgentUpdateException('AGENT_UPDATE_BUSY');
    }
    final locks = ref.read(agentUpdateLockProvider.notifier);
    final acpRuntime = ref.exists(aiChatProvider)
        ? ref.read(aiChatProvider.notifier)
        : null;
    final cliRuntime = ref.exists(cliChatProvider)
        ? ref.read(cliChatProvider.notifier)
        : null;
    if (!locks.acquire(plan.profile)) {
      throw const AgentUpdateException('AGENT_UPDATE_BUSY');
    }
    _checkRevision++;
    for (final entry in state.agents.entries.toList()) {
      if (entry.value.isChecking) {
        _put(entry.key, entry.value.copyWith(isChecking: false));
      }
    }
    _consumedPlans.add(plan);
    var succeeded = false;
    var remoteStarted = false;
    AgentProfile updatedProfile = plan.profile;
    try {
      if (_busy(plan.server.id)) {
        throw const AgentUpdateException('AGENT_UPDATE_BUSY');
      }
      final entry = (state.agents[plan.profile.id] ?? const AgentUpdateEntry())
          .copyWith(
            targetKey: plan.targetKey,
            isUpdating: true,
            isChecking: false,
            interrupted: true,
            clearError: true,
            log: '',
            lastAttemptAt: _now,
          );
      _put(plan.profile.id, entry);
      // A restart must recheck an interrupted task, never replay its command.
      await _persist(plan.server, plan.profile, entry);
      remoteStarted = true;
      updatedProfile = await ref
          .read(agentUpdateServiceProvider)
          .apply(
            plan,
            isCurrent: () =>
                _current(epoch, plan.server, plan.profile) &&
                !_busy(plan.server.id),
            onLog: (text) {
              if (_current(epoch, plan.server, plan.profile)) {
                _appendLog(plan.profile.id, text);
              }
            },
          );
      if (!_current(epoch, plan.server, plan.profile)) {
        throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
      }
      if (updatedProfile.acpCommand != plan.profile.acpCommand) {
        await ref
            .read(agentRegistryProvider.notifier)
            .commitVerifiedAdapterMigration(plan.profile, updatedProfile);
      }
      final done = (state.agents[plan.profile.id] ?? entry).copyWith(
        targetKey: agentUpdateTargetKey(plan.server, updatedProfile),
        isUpdating: false,
        interrupted: false,
        clearError: true,
      );
      _put(plan.profile.id, done);
      await _persist(plan.server, updatedProfile, done);
      succeeded = true;
      if (ref.mounted && epoch == _epoch) {
        state = AgentUpdatesState(
          serverId: state.serverId,
          agents: state.agents,
          generation: state.generation + 1,
          lastUpdatedAgentId: plan.profile.id,
          showUpdateNotices: state.showUpdateNotices,
          noticeDay: state.noticeDay,
        );
      }
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        final failed =
            (state.agents[plan.profile.id] ?? const AgentUpdateEntry())
                .copyWith(
                  isUpdating: false,
                  interrupted: true,
                  errorCode: _errorCode(error),
                );
        _put(plan.profile.id, failed);
        try {
          await _persist(plan.server, plan.profile, failed);
        } catch (_) {
          /* Keep the interrupted marker written before execution. */
        }
      }
      rethrow;
    } finally {
      _flushLogs();
      if (remoteStarted) {
        if (acpRuntime != null) {
          try {
            await acpRuntime.refreshRuntimeAfterUpdate(
              updatedProfile,
              refresh: false,
            );
          } catch (_) {
            /* The runtime may already have been disposed. */
          }
        }
        if (cliRuntime != null) {
          try {
            await cliRuntime.invalidateRuntimeAfterUpdate(
              updatedProfile,
              refresh: false,
            );
          } catch (_) {
            /* Preserve package result independently of transport cleanup. */
          }
        }
      }
      try {
        locks.release(plan.profile);
      } catch (_) {
        /* The entire ProviderContainer may have been disposed. */
      }
    }
    if (succeeded && ref.mounted && epoch == _epoch) {
      // Runtime refresh failures must not relabel a verified package upgrade.
      if (ref.exists(aiChatProvider)) {
        try {
          await ref
              .read(aiChatProvider.notifier)
              .refreshRuntimeAfterUpdate(updatedProfile);
        } catch (_) {}
      }
      if (ref.exists(cliChatProvider)) {
        try {
          await ref
              .read(cliChatProvider.notifier)
              .invalidateRuntimeAfterUpdate(updatedProfile);
        } catch (_) {}
      }
      await ref
          .read(agentRegistryProvider.notifier)
          .refreshAgent(updatedProfile.id);
      await checkAll();
    }
  }

  void _put(String agentId, AgentUpdateEntry entry) {
    if (!ref.mounted) return;
    state = AgentUpdatesState(
      serverId: state.serverId,
      agents: {...state.agents, agentId: entry},
      generation: state.generation,
      lastUpdatedAgentId: state.lastUpdatedAgentId,
      showUpdateNotices: state.showUpdateNotices,
      noticeDay: _day(_now),
    );
  }

  void _appendLog(String agentId, String text) {
    final joined =
        '${_pendingLogs[agentId] ?? ''}${LogSanitizer.sanitize(text)}';
    _pendingLogs[agentId] = joined.length > 65536
        ? joined.substring(joined.length - 65536)
        : joined;
    _logTimer ??= Timer(const Duration(milliseconds: 100), _flushLogs);
  }

  void _flushLogs() {
    _logTimer?.cancel();
    _logTimer = null;
    if (!ref.mounted) {
      _pendingLogs.clear();
      return;
    }
    for (final pending in _pendingLogs.entries) {
      final entry = state.agents[pending.key];
      if (entry == null) continue;
      final joined = '${entry.log}${pending.value}';
      _put(
        pending.key,
        entry.copyWith(
          log: joined.length > 65536
              ? joined.substring(joined.length - 65536)
              : joined,
        ),
      );
    }
    _pendingLogs.clear();
  }

  static String _errorCode(Object error) =>
      error is AgentUpdateException ? error.code : 'AGENT_UPDATE_FAILED';
  static String _day(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
