import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/remote_workspace_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

const _server = ServerProfile(
  id: 'srv-lifecycle',
  name: 'Lifecycle',
  host: 'lifecycle.example',
  username: 'dev',
);

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  await storage.saveServers(const [_server]);
  await storage.setActiveServerId(_server.id);
  return storage;
}

ProviderContainer _container(LocalStorageService storage) {
  // A real manager with no connected client keeps activation offline without
  // opening a socket; the workspace provider itself is the real one.
  final manager = SSHClientManager(SSHHostKeyVerifier(storage));
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      sshClientManagerProvider.overrideWithValue(manager),
    ],
  );
}

bool _isCircular(Object error) =>
    error.toString().contains('CircularDependencyError');

void main() {
  group('remote workspace provider lifecycle', () {
    test(
      'activating the real provider notifies without a circular dependency',
      () async {
        final storage = await _storage();
        final container = _container(storage);
        final errors = <Object>[];

        await runZonedGuarded(() async {
          // Reading the notifier builds the real service provider and wires
          // the service -> notifier notification callback.
          final notifier = container.read(remoteWorkspaceProvider.notifier);
          expect(container.read(remoteWorkspaceProvider).serverId, isNull);

          // The notifier defers activation to a microtask so the callback
          // cannot be invoked while its own provider is still building.
          await pumpEventQueue();
          expect(container.read(remoteWorkspaceProvider).serverId, _server.id);

          // Drive a real service notification through the wired callback.
          await notifier.discover();
          await pumpEventQueue();

          final state = container.read(remoteWorkspaceProvider);
          expect(state.serverId, _server.id);
          expect(state.isBusy, isFalse);
          expect(
            errors.where(_isCircular),
            isEmpty,
            reason: 'service notifications must never read the notifier '
                'provider from inside its own build',
          );
        }, (error, _) => errors.add(error));

        expect(errors, isEmpty);
        container.dispose();
      },
    );

    test('disposing the notifier releases the service callback safely', () async {
      final storage = await _storage();
      final container = _container(storage);

      container.read(remoteWorkspaceProvider.notifier);
      await pumpEventQueue();

      final service = container.read(remoteWorkspaceServiceProvider);
      final owned = service.onChanged;
      container.dispose();

      // Disposal must neutralize the callback before the service is disposed,
      // so a late service event cannot write into a disposed notifier.
      expect(identical(service.onChanged, owned), isFalse);
      expect(() => service.onChanged(const RemoteWorkspaceState()), returnsNormally);
      expect(storage.workspaceGateway, isNull);
    });
  });
}
