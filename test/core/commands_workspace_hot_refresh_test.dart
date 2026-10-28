import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/commands_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';

class _FakeGateway implements WorkspaceGateway {
  final controller = StreamController<WorkspaceChange>.broadcast();

  @override
  String get deviceId => 'test-device';

  @override
  bool isEnabled(String serverId) => true;

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async => const {};

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {}

  @override
  Stream<WorkspaceChange> get changes => controller.stream;

  Future<void> emit(String serverId, List<Map<String, dynamic>> records) async {
    controller.add(WorkspaceChange(serverId, records));
    await _settle();
  }

  Future<void> close() => controller.close();
}

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _server = ServerProfile(
  id: 'srv-1',
  name: 'first server',
  host: 'a.example.test',
  username: 'root',
);

const _second = ServerProfile(
  id: 'srv-2',
  name: 'second server',
  host: 'b.example.test',
  username: 'root',
);

class _Active extends ActiveServerNotifier {
  _Active([this.initial = _server]);
  final ServerProfile? initial;
  @override
  ServerProfile? build() => initial;
  void select(ServerProfile? next) => state = next;
}

const _command = QuickCommand(
  id: 'cmd-1',
  title: 'test command',
  command: 'echo hi',
  category: 'Tools',
  description: '',
);

Future<
  ({
    ProviderContainer container,
    LocalStorageService storage,
    _FakeGateway gateway,
  })
>
_env({bool withGateway = true}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final gateway = _FakeGateway();
  if (withGateway) {
    storage.workspaceGateway = gateway;
  }
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      activeServerProvider.overrideWith(_Active.new),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(gateway.close);
  container.read(commandsProvider);
  return (container: container, storage: storage, gateway: gateway);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'relevant workspace config update reloads commands and preserves category/search',
    () async {
      final env = await _env();
      await env.storage.saveQuickCommands([_command]);
      env.container.read(commandsProvider.notifier).setCategory('Tools');
      env.container.read(commandsProvider.notifier).setSearchQuery('needle');
      final before = env.container.read(commandsProvider);

      final updated = _command.copyWith(title: 'updated command');
      await env.storage.saveQuickCommands([updated]);
      await env.gateway.emit(_server.id, [
        {'kind': 'config', 'id': 'command/cmd-1'},
      ]);

      final state = env.container.read(commandsProvider);
      expect(state.allCommands.single.title, 'updated command');
      expect(state.selectedCategory, 'Tools');
      expect(state.searchQuery, 'needle');
      expect(identical(state, before), isFalse);
    },
  );

  test('events for another server do not rebuild command state', () async {
    final env = await _env();
    await env.storage.saveQuickCommands([_command]);
    await env.gateway.emit(_server.id, [
      {'kind': 'config', 'id': 'command/cmd-1'},
    ]);
    final before = env.container.read(commandsProvider);

    await env.storage.saveQuickCommands([_command.copyWith(title: 'changed')]);
    await env.gateway.emit(_second.id, [
      {'kind': 'config', 'id': 'command/cmd-1'},
    ]);

    expect(identical(env.container.read(commandsProvider), before), isTrue);
  });

  test(
    'empty polls and unrelated records do not rebuild command state',
    () async {
      final env = await _env();
      await env.storage.saveQuickCommands([_command]);
      final before = env.container.read(commandsProvider);

      await env.gateway.emit(_server.id, const []);
      await env.gateway.emit(_server.id, [
        {'kind': 'config', 'id': 'valhalla_agents_v1/x'},
      ]);

      expect(identical(env.container.read(commandsProvider), before), isTrue);
    },
  );

  test('provider builds when workspace gateway is absent', () async {
    final env = await _env(withGateway: false);
    await env.storage.saveQuickCommands([_command]);
    final state = env.container.read(commandsProvider);
    expect(state.allCommands, isNotEmpty);
  });
}
