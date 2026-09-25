import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/nas_metadata_service.dart';
import 'infrastructure_providers.dart';
import 'nas_provider.dart';
import 'nas_sources_provider.dart';

final nasMetadataServiceProvider = FutureProvider<NasMetadataService>((
  ref,
) async {
  final repository = await ref.watch(nasIndexRepositoryProvider.future);
  final service = NasMetadataService(
    repository,
    ref.watch(nasMediaProxyServiceProvider),
    (id) => ref.read(nasSourceAdapterProvider(id).future),
  );
  var foreground =
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void start() {
    if (!ref.mounted || !foreground) return;
    final source = ref.read(nasSourcesProvider).selected;
    if (source != null && !source.isMediaServer) {
      unawaited(service.start(source.id).catchError((Object _) {}));
    } else {
      unawaited(service.cancel());
    }
  }

  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      foreground = state == AppLifecycleState.resumed;
      if (foreground) {
        start();
      } else {
        unawaited(service.cancel());
      }
    },
  );
  ref.listen(nasSourcesProvider.select((s) => s.selectedId), (_, _) => start());
  ref.listen(
    nasProvider.select((s) => (s.scannedCount, s.isScanning)),
    (_, _) => start(),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    service.dispose();
  });
  start();
  return service;
});

final nasMetadataProgressProvider = StreamProvider<NasMetadataProgress>((
  ref,
) async* {
  final service = await ref.watch(nasMetadataServiceProvider.future);
  yield service.state;
  yield* service.changes;
});
