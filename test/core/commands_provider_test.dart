import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/commands_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/command_repository.dart';
import 'package:valhalla/data/repositories/server_repository.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'fixture',
  name: 'isolated fixture',
  host: 'fixture.invalid',
  username: 'dev',
);
const _command = QuickCommand(
  id: 'command',
  title: 'test',
  command: 'printf {{message}}',
  category: 'test',
  description: '',
);

class _Active extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
  void select(ServerProfile? server) => state = server;
}

class _Commands implements CommandRepository {
  @override
  List<QuickCommand> getAllCommands() => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Servers implements ServerRepository {
  final sudo = Completer<String?>();
  Object? error;
  @override
  Future<String?> getSudoPassword(String id) async {
    if (error != null) throw error!;
    return sudo.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Manager implements SSHClientManager {
  SSHClient? client = _Client();
  Object? error;
  final calls = <(String, String, String?)>[];
  @override
  SSHClient? getClient(String serverId) => client;
  @override
  bool isConnected(String serverId) => client != null;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    calls.add((serverId, command, sudoPassword));
    if (error != null) throw error!;
    return const SSHExecutionResult(
      exitCode: 7,
      stdout: 'partial output',
      stderr: 'remote error',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late _Servers servers;
  late _Manager manager;

  setUp(() {
    servers = _Servers();
    manager = _Manager();
    container = ProviderContainer(
      overrides: [
        commandRepositoryProvider.overrideWithValue(_Commands()),
        serverRepositoryProvider.overrideWithValue(servers),
        sshClientManagerProvider.overrideWithValue(manager),
        activeServerProvider.overrideWith(_Active.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'credential failure returns a sanitized result without dispatch',
    () async {
      servers.error = StateError(
        'secure storage failed password=do-not-expose',
      );
      final result = await container
          .read(commandsProvider.notifier)
          .executeBackground(_command.copyWith(requiresSudo: true), {});
      expect(result.exitCode, -1);
      expect(result.stderr, contains('secure storage failed'));
      expect(result.stderr, isNot(contains('do-not-expose')));
      expect(manager.calls, isEmpty);
    },
  );

  test('SSH exception returns a sanitized failure result', () async {
    manager.error = StateError(
      'failed https://user:private-value@fixture.invalid',
    );
    final result = await container
        .read(commandsProvider.notifier)
        .executeBackground(_command, {});
    expect(result.exitCode, -1);
    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('failed'));
    expect(result.stderr, isNot(contains('private-value')));
  });

  for (final change in [
    'same-id endpoint',
    'source',
    'reconnect',
    'disconnect',
    'dispose',
  ]) {
    test('$change during credentials prevents command dispatch', () async {
      final active = container.read(activeServerProvider.notifier) as _Active;
      final pending = container
          .read(commandsProvider.notifier)
          .executeBackground(_command.copyWith(requiresSudo: true), {});
      switch (change) {
        case 'same-id endpoint':
          active.select(_server.copyWith(host: 'other.invalid'));
        case 'source':
          active.select(_server.copyWith(id: 'other'));
        case 'reconnect':
          manager.client = _Client();
        case 'disconnect':
          manager.client = null;
        case 'dispose':
          container.dispose();
      }
      servers.sudo.complete('test-secret');
      final result = await pending;
      expect(result.exitCode, -1);
      expect(result.stderr, isNotEmpty);
      expect(manager.calls, isEmpty);
    });
  }

  test(
    'name-only change preserves parameters, sudo and both result streams',
    () async {
      final pending = container
          .read(commandsProvider.notifier)
          .executeBackground(_command.copyWith(requiresSudo: true), {
            'message': 'hello',
          });
      (container.read(activeServerProvider.notifier) as _Active).select(
        _server.copyWith(name: 'renamed fixture'),
      );
      servers.sudo.complete('test-secret');
      final result = await pending;
      expect(result.exitCode, 7);
      expect(result.stdout, 'partial output');
      expect(result.stderr, 'remote error');
      expect(manager.calls, [('fixture', 'printf hello', 'test-secret')]);
    },
  );
}
