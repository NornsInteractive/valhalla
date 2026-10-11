import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../core/services/app_diagnostics.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../../infrastructure/system/process_service.dart';
import '../../infrastructure/system/service_manager.dart';

class SystemState {
  final List<ProcessInfo> processes;
  final bool isProcessesLoading;
  final String? processError;
  final String processSearchQuery;

  final List<SystemdServiceInfo> services;
  final bool isServicesLoading;
  final String? serviceError;
  final String serviceSearchQuery;
  final String? serviceFilterState;
  final Map<String, String> pendingActions;
  final DateTime? cachedAt;

  const SystemState({
    this.processes = const [],
    this.isProcessesLoading = false,
    this.processError,
    this.processSearchQuery = '',
    this.services = const [],
    this.isServicesLoading = false,
    this.serviceError,
    this.serviceSearchQuery = '',
    this.serviceFilterState,
    this.pendingActions = const {},
    this.cachedAt,
  });

  List<ProcessInfo> get filteredProcesses {
    if (processSearchQuery.trim().isEmpty) return processes;
    final q = processSearchQuery.toLowerCase();
    return processes.where((p) {
      return p.command.toLowerCase().contains(q) ||
          p.pid.toString().contains(q);
    }).toList();
  }

  List<SystemdServiceInfo> get filteredServices {
    var result = services;
    if (serviceFilterState != null && serviceFilterState!.isNotEmpty) {
      result = result
          .where(
            (s) => s.state.toLowerCase() == serviceFilterState!.toLowerCase(),
          )
          .toList();
    }
    if (serviceSearchQuery.trim().isNotEmpty) {
      final q = serviceSearchQuery.toLowerCase();
      result = result.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  SystemState copyWith({
    List<ProcessInfo>? processes,
    bool? isProcessesLoading,
    String? processError,
    String? processSearchQuery,
    List<SystemdServiceInfo>? services,
    bool? isServicesLoading,
    String? serviceError,
    String? serviceSearchQuery,
    String? serviceFilterState,
    bool clearServiceFilter = false,
    bool clearProcessError = false,
    bool clearServiceError = false,
    Map<String, String>? pendingActions,
    DateTime? cachedAt,
    bool clearCachedAt = false,
  }) {
    return SystemState(
      processes: processes ?? this.processes,
      isProcessesLoading: isProcessesLoading ?? this.isProcessesLoading,
      processError: clearProcessError ? null : (processError ?? this.processError),
      processSearchQuery: processSearchQuery ?? this.processSearchQuery,
      services: services ?? this.services,
      isServicesLoading: isServicesLoading ?? this.isServicesLoading,
      serviceError: clearServiceError ? null : (serviceError ?? this.serviceError),
      pendingActions: pendingActions ?? this.pendingActions,
      cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
      serviceSearchQuery: serviceSearchQuery ?? this.serviceSearchQuery,
      serviceFilterState: clearServiceFilter
          ? null
          : (serviceFilterState ?? this.serviceFilterState),
    );
  }
}

class SystemNotifier extends Notifier<SystemState> {
  int _epoch = 0;
  int _processSequence = 0;
  int _serviceSequence = 0;
  @override
  SystemState build() {
    final epoch = ++_epoch;
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);
    ref.listen(serverConnectionProvider, (previous, next) {
      if (next.isConnected && previous?.isConnected != true) {
        unawaited(refreshAll(quiet: true));
      } else if (!next.isConnected) {
        _processSequence++;
        _serviceSequence++;
        state = state.copyWith(
          isProcessesLoading: false,
          isServicesLoading: false,
        );
      }
    });

    if (activeServer != null && connState.isConnected) {
      Future.microtask(() {
        if (ref.mounted && epoch == _epoch) unawaited(refreshAll());
      });
    }

    if (activeServer != null) {
      try {
        final cached = ref.read(localStorageServiceProvider).getPageCache(activeServer, 'services');
        final rows = cached?['payload']?['services'] as List?;
        if (rows != null) {
          return SystemState(services: rows.cast<Map<String, dynamic>>().map((s) =>
            SystemdServiceInfo(name: s['name'] as String, description: s['description'] as String,
              state: s['state'] as String, startup: s['startup'] as String)).toList(),
            cachedAt: DateTime.tryParse(cached?['savedAt'] as String? ?? ''));
        }
      } catch (error, stack) {
        unawaited(AppDiagnostics.instance.record('system.cache', error, stack));
      }
    }
    return const SystemState();
  }

  void setProcessSearch(String q) {
    state = state.copyWith(processSearchQuery: q);
  }

  void setServiceSearch(String q) {
    state = state.copyWith(serviceSearchQuery: q);
  }

  void setServiceFilter(String? filter) {
    if (filter == null) {
      state = state.copyWith(clearServiceFilter: true);
    } else {
      state = state.copyWith(serviceFilterState: filter);
    }
  }

  Future<void> refreshAll({bool quiet = false}) async {
    await Future.wait([
      refreshProcesses(quiet: quiet),
      refreshServices(quiet: quiet),
    ]);
  }

  Future<void> refreshProcesses({bool quiet = false}) async {
    final epoch = _epoch;
    final sequence = ++_processSequence;
    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);

    if (activeServer == null || !connState.isConnected) {
      state = state.copyWith(isProcessesLoading: false);
      return;
    }

    state = state.copyWith(isProcessesLoading: !quiet, clearProcessError: true);

    try {
      final procService = ref.read(processServiceProvider);
      final list = await procService.list(activeServer.id);
      if (!ref.mounted || epoch != _epoch || sequence != _processSequence) {
        return;
      }
      state = state.copyWith(
        processes: list,
        isProcessesLoading: false,
        clearProcessError: true,
      );
    } catch (e) {
      if (!ref.mounted || epoch != _epoch || sequence != _processSequence) {
        return;
      }
      state = state.copyWith(
        isProcessesLoading: false,
        processError: ref.read(serverConnectionProvider).isConnected
            ? e.toString()
            : null,
      );
    }
  }

  Future<void> refreshServices({bool quiet = false}) async {
    final epoch = _epoch;
    final sequence = ++_serviceSequence;
    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);

    if (activeServer == null || !connState.isConnected) {
      state = state.copyWith(isServicesLoading: false);
      return;
    }

    state = state.copyWith(isServicesLoading: !quiet, clearServiceError: true);

    try {
      final svcManager = ref.read(serviceManagerProvider);
      final list = await svcManager.list(activeServer.id);
      if (!ref.mounted || epoch != _epoch || sequence != _serviceSequence) {
        return;
      }
      state = state.copyWith(
        services: list,
        clearCachedAt: true,
        isServicesLoading: false,
        clearServiceError: true,
      );
      unawaited(ref.read(localStorageServiceProvider).savePageCache(activeServer, 'services', {
        'services': list.take(200).map((s) => {'name': s.name, 'description': s.description,
          'state': s.state, 'startup': s.startup}).toList(),
      }).catchError((Object error, StackTrace stack) {
        unawaited(AppDiagnostics.instance.record('system.cache', error, stack));
      }));
    } catch (e) {
      if (!ref.mounted || epoch != _epoch || sequence != _serviceSequence) {
        return;
      }
      state = state.copyWith(
        isServicesLoading: false,
        serviceError: ref.read(serverConnectionProvider).isConnected
            ? e.toString()
            : null,
      );
    }
  }

  Future<SSHExecutionResult> terminateProcess(
    int pid, {
    bool force = false,
    String? expectedStartedAt,
  }) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null || !ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('No active server selected');
    }

    final procService = ref.read(processServiceProvider);
    if (expectedStartedAt == null || expectedStartedAt.isEmpty) {
      throw const ValidationException('PROCESS_IDENTITY_UNAVAILABLE');
    }
    final result = await procService.terminate(
      activeServer.id,
      pid,
      force: force,
      expectedStartedAt: expectedStartedAt,
    );
    await refreshProcesses();
    return result;
  }

  Future<SSHExecutionResult> performServiceAction(
    String service,
    String action,
  ) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null || !ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('No active server selected');
    }

    final svcManager = ref.read(serviceManagerProvider);
    if (state.pendingActions.containsKey(service)) {
      throw const ValidationException('SERVICE_ACTION_IN_PROGRESS');
    }
    final epoch = _epoch;
    state = state.copyWith(pendingActions: {...state.pendingActions, service: action});
    try {
      final result = await svcManager.action(activeServer.id, service, action);
      if (ref.mounted && epoch == _epoch) await refreshServices(quiet: true);
      return result;
    } finally {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(pendingActions: Map.from(state.pendingActions)..remove(service));
      }
    }
  }
  Future<List<Map<String, dynamic>>> serviceLogs(String service, {String? beforeCursor}) async {
    final server = ref.read(activeServerProvider);
    final epoch = _epoch;
    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('SSH_DISCONNECTED');
    }
    final records = await ref.read(serviceManagerProvider).logs(server.id, service,
      beforeCursor: beforeCursor);
    if (!ref.mounted || epoch != _epoch) throw const ValidationException('SERVICE_TARGET_CHANGED');
    return records;
  }
}

final systemProvider = NotifierProvider<SystemNotifier, SystemState>(
  () => SystemNotifier(),
);
