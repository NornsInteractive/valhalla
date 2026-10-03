import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/server_profile.dart';
import '../utils/reconnect_backoff.dart';
import 'agent_registry_provider.dart';
import 'reconnect_provider.dart';
import 'storage_providers.dart';

enum ConnectionStateEnum { disconnected, connecting, connected, error }

class ServerConnectionState {
  final ConnectionStateEnum status;
  final String? errorMessage;
  final String? activeServerId;

  const ServerConnectionState({
    this.status = ConnectionStateEnum.disconnected,
    this.errorMessage,
    this.activeServerId,
  });

  bool get isConnected => status == ConnectionStateEnum.connected;
  bool get isConnecting => status == ConnectionStateEnum.connecting;

  ServerConnectionState copyWith({
    ConnectionStateEnum? status,
    String? errorMessage,
    String? activeServerId,
    bool clearError = false,
  }) {
    return ServerConnectionState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeServerId: activeServerId ?? this.activeServerId,
    );
  }
}

class ServerListNotifier extends Notifier<List<ServerProfile>> {
  final Set<String> _deleting = {};
  @override
  List<ServerProfile> build() {
    final repo = ref.watch(serverRepositoryProvider);
    return repo.getAllServers();
  }

  Future<void> addOrUpdate(
    ServerProfile server, {
    String? password,
    String? privateKey,
  }) async {
    final repo = ref.read(serverRepositoryProvider);
    await repo.addOrUpdateServer(
      server,
      password: password,
      privateKey: privateKey,
    );
    await repo.setActiveServerId(server.id);
    state = repo.getAllServers();
    ref.invalidate(activeServerProvider);
  }

  Future<void> deleteServer(String id) async {
    if (!_deleting.add(id)) return;
    try {
      final repo = ref.read(serverRepositoryProvider);
      if (!repo.getAllServers().any((server) => server.id == id)) return;
      final isCurrent = ref.read(activeServerProvider)?.id == id;
      await repo.deleteServer(id);
      if (!ref.mounted) return;
      if (isCurrent) {
        ref.read(serverConnectionProvider.notifier).disconnect();
      }
      state = repo.getAllServers();
      ref.invalidate(agentRegistryProvider);
    } finally {
      _deleting.remove(id);
    }
  }
}

final serverListProvider =
    NotifierProvider<ServerListNotifier, List<ServerProfile>>(() {
      return ServerListNotifier();
    });

class ActiveServerNotifier extends Notifier<ServerProfile?> {
  Future<void> _selectionTail = Future<void>.value();
  // ServerProfile equality is ID-only; edits must still update observers.
  @override
  bool updateShouldNotify(ServerProfile? previous, ServerProfile? next) =>
      !identical(previous, next);

  @override
  ServerProfile? build() {
    final servers = ref.watch(serverListProvider);
    final repo = ref.watch(serverRepositoryProvider);
    final activeId = repo.getActiveServerId();

    if (servers.isEmpty) return null;
    if (activeId == null) return servers.first;

    return servers.firstWhere(
      (s) => s.id == activeId,
      orElse: () => servers.first,
    );
  }

  Future<void> selectServer(String id) {
    final selection = _selectionTail.then((_) async {
      if (!ref.mounted) return;
      final repo = ref.read(serverRepositoryProvider);
      final target = repo
          .getAllServers()
          .where((server) => server.id == id)
          .firstOrNull;
      if (target == null) throw StateError('SERVER_NOT_FOUND');
      if (state?.id == id && repo.getActiveServerId() == id) return;
      await repo.setActiveServerId(id);
      if (!ref.mounted) return;
      ref.read(serverConnectionProvider.notifier).disconnect();
      state = repo
          .getAllServers()
          .where((server) => server.id == id)
          .firstOrNull;
    });
    _selectionTail = selection.catchError((Object _) {});
    return selection;
  }
}

final activeServerProvider =
    NotifierProvider<ActiveServerNotifier, ServerProfile?>(() {
      return ActiveServerNotifier();
    });

class ServerConnectionNotifier extends Notifier<ServerConnectionState> {
  int _connectionEpoch = 0;
  @override
  ServerConnectionState build() {
    ref.onDispose(() => _connectionEpoch++);
    final ssh = ref.watch(sshClientManagerProvider);
    final reconnect = ref.watch(reconnectControllerProvider);

    final deathSub = ssh.transportDied.listen((serverId) {
      if (!ref.mounted) return;
      if (state.activeServerId != serverId) return;
      // 重连控制器自己也在听；这里只避免 UI 继续显示「已连接」。
      if (state.status == ConnectionStateEnum.connected) {
        state = state.copyWith(status: ConnectionStateEnum.connecting);
      }
    });
    ref.onDispose(deathSub.cancel);

    if (reconnect != null) {
      final unsub = reconnect.addStateListener((next) {
        if (!ref.mounted) return;
        _applyReconnectState(next, reconnect);
      });
      ref.onDispose(unsub);
    }

    ref.listen<ServerProfile?>(activeServerProvider, (prev, next) {
      if (prev == null && next == null) return;
      if (prev != null &&
          next != null &&
          prev.hasSameConnectionSettings(next)) {
        return;
      }
      disconnect();
      state = ServerConnectionState(activeServerId: next?.id);
    });

    // 不得 watch activeServer 后 return 全新 disconnected：
    // 服务器列表刷新会把还活着的 SSH 在 UI 上打成已断开。
    return stateOrNull ??
        ServerConnectionState(
          activeServerId: ref.read(activeServerProvider)?.id,
        );
  }

  void _applyReconnectState(
    ReconnectState next,
    ReconnectController controller,
  ) {
    if (controller.serverId != state.activeServerId) return;
    switch (next.status) {
      case ReconnectStatus.connected:
        state = state.copyWith(
          status: ConnectionStateEnum.connected,
          clearError: true,
        );
        _scheduleAgentDetection();
      case ReconnectStatus.connecting:
      case ReconnectStatus.reconnecting:
        state = state.copyWith(
          status: ConnectionStateEnum.connecting,
          clearError: true,
        );
      case ReconnectStatus.failed:
        state = state.copyWith(
          status: ConnectionStateEnum.error,
          errorMessage: next.errorMessage,
        );
      case ReconnectStatus.idle:
        if (controller.hasEverStarted && !controller.userIntent) {
          state = state.copyWith(
            status: ConnectionStateEnum.disconnected,
            clearError: true,
          );
        }
    }
  }

  void _scheduleAgentDetection() {
    final epoch = _connectionEpoch;
    Future.microtask(() {
      if (ref.mounted && epoch == _connectionEpoch && state.isConnected) {
        // Imperative bootstrap, not a connection provider dependency: the
        // registry itself listens to this connection provider. Ref.read here
        // creates a circular dependency when the registry first mounts.
        // Existing listeners handle transitions; newly mounted registries
        // detect the already-connected initial state themselves.
        ref.container.read(agentRegistryProvider);
      }
    });
  }

  Future<bool> connect({
    String? password,
    String? privateKey,
    Future<bool> Function(
      String host,
      String keyType,
      String fingerprintSha256,
    )?
    onConfirmHostKey,
  }) async {
    final server = ref.read(activeServerProvider);
    if (server == null) {
      state = state.copyWith(
        status: ConnectionStateEnum.error,
        errorMessage: 'No server selected',
      );
      return false;
    }

    final epoch = ++_connectionEpoch;
    bool isCurrent() =>
        ref.mounted &&
        epoch == _connectionEpoch &&
        (ref.read(activeServerProvider)?.hasSameConnectionSettings(server) ??
            false);

    state = state.copyWith(
      status: ConnectionStateEnum.connecting,
      activeServerId: server.id,
      clearError: true,
    );

    final serverRepo = ref.read(serverRepositoryProvider);
    final sshManager = ref.read(sshClientManagerProvider);

    try {
      final pwd = password ?? await serverRepo.getPassword(server.id);
      if (!isCurrent()) return false;
      final pkey = privateKey ?? await serverRepo.getPrivateKey(server.id);
      if (!isCurrent()) return false;
      await sshManager.getOrCreateClient(
        server,
        password: pwd,
        privateKey: pkey,
        onConfirmHostKey: onConfirmHostKey,
      );

      if (!isCurrent()) return false;

      // 只有真正连上才记：失败也记的话，「记住最后一次连接」会在下次启动
      // 去自动连一个已知连不上的服务器，启动即报错。
      await serverRepo.setLastConnectedServerId(server.id);
      if (!isCurrent()) return false;
      armConnectionSession(
        reconnect: ref.read(reconnectControllerProvider),
        keepAlive: ref.read(keepAliveCoordinatorProvider),
        server: server,
      );

      state = state.copyWith(
        status: ConnectionStateEnum.connected,
        clearError: true,
      );
      _scheduleAgentDetection();
      return true;
    } catch (e) {
      if (!isCurrent()) return false;
      state = state.copyWith(
        status: ConnectionStateEnum.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void disconnect() {
    _connectionEpoch++;
    final serverId = state.activeServerId;
    if (serverId != null) {
      disarmConnectionSession(
        reconnect: ref.read(reconnectControllerProvider),
        keepAlive: ref.read(keepAliveCoordinatorProvider),
        serverId: serverId,
      );
      ref.read(sshClientManagerProvider).disconnect(serverId);
    }
    state = state.copyWith(
      status: ConnectionStateEnum.disconnected,
      clearError: true,
    );
  }
}

final serverConnectionProvider =
    NotifierProvider<ServerConnectionNotifier, ServerConnectionState>(() {
      return ServerConnectionNotifier();
    });
