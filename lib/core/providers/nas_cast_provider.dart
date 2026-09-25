import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nas_cast_service.dart';
import 'infrastructure_providers.dart';
import 'nas_sources_provider.dart';

final nasCastServiceProvider = Provider<NasCastService>((ref) {
  final service = NasCastService(
    adapterFor: (id) => ref.read(nasSourceAdapterProvider(id).future),
    proxy: ref.watch(nasMediaProxyServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final nasCastStateProvider = StreamProvider<NasCastState>((ref) async* {
  final service = ref.watch(nasCastServiceProvider);
  yield service.state;
  yield* service.changes;
});
