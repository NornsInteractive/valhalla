import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_diagnostics.dart';

final diagnosticsServiceProvider = Provider<AppDiagnostics>(
  (ref) => AppDiagnostics.instance,
);
final diagnosticsTextProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(diagnosticsServiceProvider).read(),
);
final diagnosticsIncidentProvider = StreamProvider<String>(
  (ref) => ref.watch(diagnosticsServiceProvider).incidents,
);
