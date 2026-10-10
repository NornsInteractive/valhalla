import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/providers/server_provider.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/docker/docker_cli_service.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';

class DockerState {
  final List<DockerContainer> containers;
  final bool isLoading;
  final String? errorMessage;
  final int? exitCode;
  final String searchQuery;
  final DockerContainerState? filterState;
  final DockerContainer? selectedContainer;
  final Map<String, dynamic>? inspectData;
  final Map<String, String> pendingActions;

  const DockerState({
    this.containers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.exitCode,
    this.searchQuery = '',
    this.filterState,
    this.selectedContainer,
    this.inspectData,
    this.pendingActions = const {},
  });

  List<DockerContainer> get filteredContainers {
    var result = containers;
    if (filterState != null) {
      result = result.where((c) => c.state == filterState).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.image.toLowerCase().contains(q) ||
            c.id.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  Map<String, List<DockerContainer>> get composeProjects {
    final projects = <String, List<DockerContainer>>{};
    for (final container in filteredContainers) {
      final project = container.composeProject;
      if (project != null) {
        projects.putIfAbsent(project, () => []).add(container);
      }
    }
    return projects;
  }

  DockerState copyWith({
    List<DockerContainer>? containers,
    bool? isLoading,
    String? errorMessage,
    int? exitCode,
    String? searchQuery,
    DockerContainerState? filterState,
    bool clearFilterState = false,
    DockerContainer? selectedContainer,
    bool clearSelectedContainer = false,
    Map<String, dynamic>? inspectData,
    bool clearInspectData = false,
    Map<String, String>? pendingActions,
  }) {
    return DockerState(
      containers: containers ?? this.containers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      exitCode: exitCode,
      searchQuery: searchQuery ?? this.searchQuery,
      filterState: clearFilterState ? null : (filterState ?? this.filterState),
      selectedContainer: clearSelectedContainer
          ? null
          : (selectedContainer ?? this.selectedContainer),
      inspectData: clearInspectData ? null : (inspectData ?? this.inspectData),
      pendingActions: pendingActions ?? this.pendingActions,
    );
  }
}

class DockerNotifier extends Notifier<DockerState> {
  int _epoch = 0;
  int _refreshSequence = 0;
  @override
  DockerState build() {
    _epoch++;
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);
    final epoch = _epoch;
    ref.listen(serverConnectionProvider, (previous, next) {
      if (next.isConnected && previous?.isConnected != true) {
        unawaited(refresh(quiet: true));
      } else if (!next.isConnected) {
        _refreshSequence++;
        state = state.copyWith(isLoading: false);
      }
    });

    if (activeServer != null && connState.isConnected) {
      Future.microtask(() {
        if (ref.mounted && epoch == _epoch) unawaited(refresh());
      });
    }

    return const DockerState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterState(DockerContainerState? filterState) {
    if (filterState == null) {
      state = state.copyWith(clearFilterState: true);
    } else {
      state = state.copyWith(filterState: filterState);
    }
  }

  Future<void> refresh({bool quiet = false}) async {
    final sequence = ++_refreshSequence;
    final epoch = _epoch;
    final activeServer = ref.read(activeServerProvider);
    final connState = ref.read(serverConnectionProvider);

    if (activeServer == null || !connState.isConnected) {
      state = state.copyWith(isLoading: false, errorMessage: null);
      return;
    }

    state = state.copyWith(
      isLoading: !quiet,
      errorMessage: null,
      exitCode: null,
    );

    try {
      final dockerService = ref.read(dockerCliServiceProvider);
      final list = await dockerService.listContainers(activeServer.id);
      if (!ref.mounted || epoch != _epoch || sequence != _refreshSequence) {
        return;
      }
      state = state.copyWith(
        containers: list,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      if (!ref.mounted || epoch != _epoch || sequence != _refreshSequence) {
        return;
      }
      int? code;
      if (e is DockerExecutionException) {
        code = e.exitCode;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(serverConnectionProvider).isConnected
            ? e.toString()
            : null,
        exitCode: code,
      );
    }
  }

  Future<SSHExecutionResult> performLifecycle(
    String action,
    String containerId,
  ) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) {
      throw const SSHConnectionException('No active server selected');
    }
    if (!ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('Server is not connected');
    }

    if (state.pendingActions.containsKey(containerId)) {
      throw StateError('DOCKER_ACTION_PENDING');
    }
    final epoch = _epoch;
    state = state.copyWith(
      pendingActions: {...state.pendingActions, containerId: action},
    );
    try {
      final result = await ref
          .read(dockerCliServiceProvider)
          .lifecycle(activeServer.id, action, containerId);
      if (ref.mounted && epoch == _epoch) await refresh();
      return result;
    } finally {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          pendingActions: {...state.pendingActions}..remove(containerId),
          errorMessage: state.errorMessage,
          exitCode: state.exitCode,
        );
      }
    }
  }

  Future<Map<String, dynamic>> inspectContainer(String containerId) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) {
      throw const SSHConnectionException('No active server selected');
    }

    if (state.pendingActions.containsKey(containerId)) {
      throw StateError('DOCKER_ACTION_PENDING');
    }
    final epoch = _epoch;
    state = state.copyWith(
      pendingActions: {...state.pendingActions, containerId: 'inspect'},
    );
    try {
      final data = await ref
          .read(dockerCliServiceProvider)
          .inspect(activeServer.id, containerId);
      if (ref.mounted &&
          epoch == _epoch &&
          state.selectedContainer?.id == containerId) {
        state = state.copyWith(inspectData: data);
      }
      return data;
    } finally {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          pendingActions: {...state.pendingActions}..remove(containerId),
          errorMessage: state.errorMessage,
          exitCode: state.exitCode,
        );
      }
    }
  }

  /// Execute only the exact existing containers shown in the confirmation.
  Future<List<DockerActionResult>> performProjectLifecycle(
    String project,
    String action,
    List<String> containerIds, {
    ServerProfile? expectedServer,
  }) async {
    if (!{'start', 'stop', 'restart'}.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    final server = ref.read(activeServerProvider);
    if (expectedServer != null &&
        !(server?.hasSameConnectionSettings(expectedServer) ?? false)) {
      throw StateError('DOCKER_PROJECT_TARGET_CHANGED');
    }
    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('Server is not connected');
    }
    final ids = containerIds.toSet();
    final containers = state.containers
        .where((c) => ids.contains(c.id))
        .toList();
    if (ids.isEmpty ||
        containers.length != ids.length ||
        containers.any((c) => c.composeProject != project)) {
      throw StateError('DOCKER_PROJECT_TARGET_CHANGED');
    }
    if (ids.any(state.pendingActions.containsKey)) {
      throw StateError('DOCKER_ACTION_PENDING');
    }
    final epoch = _epoch;
    final service = ref.read(dockerCliServiceProvider);
    final results = <DockerActionResult>[];
    state = state.copyWith(
      pendingActions: {
        ...state.pendingActions,
        for (final id in ids) id: action,
      },
    );
    try {
      for (final container in containers) {
        if (!ref.mounted ||
            epoch != _epoch ||
            !(ref
                    .read(activeServerProvider)
                    ?.hasSameConnectionSettings(server) ??
                false) ||
            !ref.read(serverConnectionProvider).isConnected) {
          results.add(
            DockerActionResult(
              containerId: container.id,
              containerName: container.name,
              success: false,
              error: 'DOCKER_OPERATION_INTERRUPTED',
            ),
          );
          continue;
        }
        try {
          final result = await service.lifecycle(
            server.id,
            action,
            container.id,
          );
          results.add(
            DockerActionResult(
              containerId: container.id,
              containerName: container.name,
              success: result.isSuccess,
              error: result.isSuccess
                  ? null
                  : 'exit ${result.exitCode}: ${result.stderr.trim()}',
            ),
          );
        } catch (error) {
          results.add(
            DockerActionResult(
              containerId: container.id,
              containerName: container.name,
              success: false,
              error: error.toString(),
            ),
          );
        } finally {
          if (ref.mounted && epoch == _epoch) {
            state = state.copyWith(
              pendingActions: {...state.pendingActions}..remove(container.id),
            );
          }
        }
      }
    } finally {
      if (ref.mounted && epoch == _epoch) {
        state = state.copyWith(
          pendingActions: {...state.pendingActions}
            ..removeWhere((id, _) => ids.contains(id)),
        );
        await refresh(quiet: true);
      }
    }
    return results;
  }

  void selectContainer(DockerContainer? container) {
    if (container == null) {
      state = state.copyWith(
        clearSelectedContainer: true,
        clearInspectData: true,
      );
    } else {
      state = state.copyWith(selectedContainer: container);
      final epoch = _epoch;
      unawaited(
        inspectContainer(container.id).catchError((Object error) {
          if (ref.mounted &&
              epoch == _epoch &&
              state.selectedContainer?.id == container.id) {
            state = state.copyWith(errorMessage: error.toString());
          }
          return <String, dynamic>{};
        }),
      );
    }
  }

  Stream<String> streamLogs(String containerId) {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) {
      throw const SSHConnectionException('No active server selected');
    }
    final dockerService = ref.read(dockerCliServiceProvider);
    return dockerService.streamLogs(activeServer.id, containerId);
  }
}

final dockerProvider = NotifierProvider<DockerNotifier, DockerState>(
  () => DockerNotifier(),
);
