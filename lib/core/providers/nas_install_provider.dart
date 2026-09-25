import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nas_install_service.dart';
import 'infrastructure_providers.dart';
import 'storage_providers.dart';

final nasInstallServiceProvider = FutureProvider<NasInstallService>((
  ref,
) async {
  final storage = ref.watch(localStorageServiceProvider);
  final service = NasInstallService(
    ref.watch(sshCommandExecutorProvider),
    ref.watch(dockerCliServiceProvider),
    recoveredTask: storage.getNasInstallTask(),
    persistTask: storage.saveNasInstallTask,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Not auto-disposed: dismissing the dialog must not own the remote operation.
final nasInstallTaskProvider = StreamProvider<NasInstallTask?>((ref) async* {
  final service = await ref.watch(nasInstallServiceProvider.future);
  yield service.state;
  yield* service.states;
});
