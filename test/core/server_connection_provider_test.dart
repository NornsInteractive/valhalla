import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/server_repository.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'a',
  name: 'isolated a',
  host: 'a.invalid',
  username: 'dev',
);

class _Active extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
  void select(ServerProfile? server) => state = server;
}

class _Repository implements ServerRepository {
  Object? credentialError;
  final remembered = <String>[];
  @override
  Future<String?> getPassword(String id) async {
    if (credentialError != null) throw credentialError!;
    return null;
  }

  @override
  Future<String?> getPrivateKey(String id) async => null;
  @override
  Future<void> setLastConnectedServerId(String id) async => remembered.add(id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Manager implements SSHClientManager {
  final pending = Completer<SSHClient>();
  final deaths = StreamController<String>.broadcast();
  final disconnected = <String>[];
  @override
  Stream<String> get transportDied => deaths.stream;
  @override
  Future<SSHClient> getOrCreateClient(
    ServerProfile server, {
    String? password,
    String? privateKey,
    Future<bool> Function(String, String, String)? onConfirmHostKey,
  }) => pending.future;
  @override
  void disconnect(String id, {bool notifyDeath = false}) =>
      disconnected.add(id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late _Repository repository;
  late _Manager manager;

  setUp(() {
    repository = _Repository();
    manager = _Manager();
    container = ProviderContainer(
      overrides: [
        serverRepositoryProvider.overrideWithValue(repository),
        sshClientManagerProvider.overrideWithValue(manager),
        activeServerProvider.overrideWith(_Active.new),
        keepAliveServiceProvider.overrideWithValue(
          const DesktopKeepAliveService(),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await manager.deaths.close();
  });

  test(
    'disconnect during authentication cannot be undone by late success',
    () async {
      final notifier = container.read(serverConnectionProvider.notifier);
      final connecting = notifier.connect();
      await Future<void>.delayed(Duration.zero);
      notifier.disconnect();
      manager.pending.complete(_Client());
      expect(await connecting, isFalse);
      expect(
        container.read(serverConnectionProvider).status,
        ConnectionStateEnum.disconnected,
      );
      expect(container.read(keepAliveCoordinatorProvider).activeCount, 0);
      expect(repository.remembered, isEmpty);
    },
  );

  test('source switch cancels old target and ignores its late error', () async {
    final connecting = container
        .read(serverConnectionProvider.notifier)
        .connect();
    await Future<void>.delayed(Duration.zero);
    (container.read(activeServerProvider.notifier) as _Active).select(
      _server.copyWith(id: 'b', host: 'b.invalid'),
    );
    manager.pending.completeError(StateError('old target failure'));
    expect(await connecting, isFalse);
    final state = container.read(serverConnectionProvider);
    expect(state.activeServerId, 'b');
    expect(state.status, ConnectionStateEnum.disconnected);
    expect(state.errorMessage, isNull);
    expect(manager.disconnected, contains('a'));
  });

  test(
    'secure storage failure becomes connection error rather than uncaught future',
    () async {
      repository.credentialError = StateError('credential read failed');
      expect(
        await container.read(serverConnectionProvider.notifier).connect(),
        isFalse,
      );
      final state = container.read(serverConnectionProvider);
      expect(state.status, ConnectionStateEnum.error);
      expect(state.errorMessage, contains('credential read failed'));
    },
  );

  test('only current successful attempt arms its connection session', () async {
    final notifier = container.read(serverConnectionProvider.notifier);
    final first = notifier.connect();
    final second = notifier.connect();
    await Future<void>.delayed(Duration.zero);
    manager.pending.complete(_Client());
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(container.read(serverConnectionProvider).isConnected, isTrue);
    expect(container.read(keepAliveCoordinatorProvider).activeCount, 1);
    expect(repository.remembered, ['a']);
  });

  test(
    'same ID endpoint edit disconnects, while name-only edit preserves connection',
    () async {
      final connecting = container
          .read(serverConnectionProvider.notifier)
          .connect();
      await Future<void>.delayed(Duration.zero);
      manager.pending.complete(_Client());
      expect(await connecting, isTrue);
      final active = container.read(activeServerProvider.notifier) as _Active;
      active.select(_server.copyWith(name: 'renamed'));
      expect(container.read(serverConnectionProvider).isConnected, isTrue);
      expect(manager.disconnected, isEmpty);
      active.select(_server.copyWith(host: 'changed.invalid'));
      expect(
        container.read(serverConnectionProvider).status,
        ConnectionStateEnum.disconnected,
      );
      expect(manager.disconnected, ['a']);
    },
  );

  test('removed active server clears identity and connection', () {
    container.read(serverConnectionProvider);
    (container.read(activeServerProvider.notifier) as _Active).select(null);
    final state = container.read(serverConnectionProvider);
    expect(state.activeServerId, isNull);
    expect(state.status, ConnectionStateEnum.disconnected);
  });

  test('provider disposal during authentication ignores completion', () async {
    final connecting = container
        .read(serverConnectionProvider.notifier)
        .connect();
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    manager.pending.complete(_Client());
    expect(await connecting, isFalse);
    expect(repository.remembered, isEmpty);
  });
}
