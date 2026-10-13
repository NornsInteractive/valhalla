import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nas_native_install_service.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

/// Native installation state belongs to the exact active SSH target, not just
/// its editable display name or an arbitrary first server in the saved list.
final nasNativeInstallServiceProvider = FutureProvider<NasNativeInstallService>((
  ref,
) async {
  ref.watch(activeServerProvider.select((server) => server?.connectionKey));
  final server = ref.read(activeServerProvider);
  final key = server == null ? null : NasNativeInstallService.serverKey(server);
  final storage = ref.watch(localStorageServiceProvider);
  final service = NasNativeInstallService(
    ref.watch(sshCommandExecutorProvider),
    currentServerKey: () {
      final current = ref.read(activeServerProvider);
      return current == null ? null : NasNativeInstallService.serverKey(current);
    },
    recoveredTask: key == null ? null : storage.getNasNativeInstallTask(key),
    persistTask: key == null ? null : (summary) =>
        storage.saveNasNativeInstallTask(key, summary),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Dismissing a dialog neither owns nor cancels an accepted package operation.
final nasNativeInstallTaskProvider = StreamProvider<NasNativeInstallTask?>((ref) async* {
  final service = await ref.watch(nasNativeInstallServiceProvider.future);
  yield service.state;
  yield* service.states;
});
