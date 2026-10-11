import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/app_visibility_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../core/services/app_diagnostics.dart';
import 'dart:async';
import '../../infrastructure/system/system_metrics_sampler.dart';
import '../../infrastructure/system/process_service.dart';
import '../../infrastructure/system/disk_usage_service.dart';
import '../../infrastructure/system/system_hardware_service.dart';

// One cache per currently selected endpoint, never shared across servers.
final _dashboardSnapshotsProvider = Provider<Map<String, Object>>((ref) {
  ref.watch(activeServerProvider.select((server) => server?.connectionKey));
  return {};
});

final systemHardwareProvider = FutureProvider.autoDispose<SystemHardwareInfo>((
  ref,
) async {
  final serverId = ref
      .watch(activeServerProvider.select((s) => s?.connectionKey))
      ?.$1;
  final connected = ref.watch(
    serverConnectionProvider.select((s) => s.isConnected),
  );
  final cache = ref.watch(_dashboardSnapshotsProvider);
  final previous = cache['hardware'] as SystemHardwareInfo?;
  if (serverId == null || !connected) {
    if (previous != null) return previous;
    throw StateError('SSH_DISCONNECTED');
  }
  final service = ref.watch(systemHardwareServiceProvider);
  try {
    final data = await service.read(serverId);
    if (ref.mounted) cache['hardware'] = data;
    return data;
  } catch (_) {
    if (previous != null) return previous;
    rethrow;
  }
});

final resourceProcessesProvider = StreamProvider.autoDispose<List<ProcessInfo>>(
  (ref) async* {
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    final server = ref.read(activeServerProvider);
    final connected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final cache = ref.watch(_dashboardSnapshotsProvider);
    final previous = cache['processes'] as List<ProcessInfo>?;
    if (previous != null) yield previous;
    if (server == null || !connected) return;
    final service = ref.watch(processServiceProvider);
    while (ref.mounted) {
      if (ref.read(appVisibilityProvider) &&
          ref.read(serverConnectionProvider).isConnected) {
        try {
          final data = await service.list(server.id);
          if (!ref.mounted) return;
          cache['processes'] = data;
          yield data;
        } catch (error) {
          // Keep the last known process allocation during transient failures.
          if (ref.mounted) {
            debugPrint(LogSanitizer.sanitize('Process refresh failed: $error'));
          }
        }
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  },
);

final rootDiskUsageProvider = FutureProvider.autoDispose<RootDiskUsage>((
  ref,
) async {
  ref.watch(activeServerProvider.select((server) => server?.connectionKey));
  final server = ref.read(activeServerProvider);
  final connected = ref.watch(
    serverConnectionProvider.select((s) => s.isConnected),
  );
  final cache = ref.watch(_dashboardSnapshotsProvider);
  final previous = cache['disk'] as RootDiskUsage?;
  if (server == null || !connected) {
    if (previous != null) return previous;
    throw StateError('SSH_DISCONNECTED');
  }
  final service = ref.watch(diskUsageServiceProvider);
  try {
    final data = await service.root(server.id);
    if (ref.mounted) cache['disk'] = data;
    return data;
  } catch (_) {
    if (previous != null) return previous;
    rethrow;
  }
});

final systemMetricsStreamProvider =
    StreamProvider.autoDispose<SystemMetricsSnapshot>((ref) {
      ref.watch(activeServerProvider.select((server) => server?.connectionKey));
      final activeServer = ref.read(activeServerProvider);
      final connected = ref.watch(
        serverConnectionProvider.select((state) => state.isConnected),
      );

      if (activeServer == null || !connected) {
        return const Stream.empty();
      }

      final sampler = ref.watch(systemMetricsSamplerProvider);
      return sampler.watch(
        activeServer.id,
        isActive: () => ref.mounted && ref.read(appVisibilityProvider),
      );
    });

const systemMetricsHistoryLimit = 60;

/// 当前服务器最近约三分钟的指标，仅保存在内存中。
class SystemMetricsHistoryNotifier
    extends Notifier<List<SystemMetricsSnapshot>> {
  @override
  List<SystemMetricsSnapshot> build() {
    _lastSaved = null;
    // 服务器变化时重建并清空，避免把不同主机的数据画在同一条曲线上。
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    ref.listen(systemMetricsStreamProvider, (_, next) {
      next.whenData(_append);
    });
    final server = ref.read(activeServerProvider);
    if (server != null) {
      try {
        final record = ref.read(localStorageServiceProvider).getPageCache(server, 'metrics');
        if (record != null) {
          return [SystemMetricsSnapshot.fromJson(record['payload'] as Map<String, dynamic>)];
        }
      } catch (error, stack) {
        unawaited(AppDiagnostics.instance.record('dashboard.cache', error, stack));
      }
    }
    return const [];
  }

  DateTime? _lastSaved;

  void _append(SystemMetricsSnapshot snapshot) {
    if (!ref.mounted || (state.isNotEmpty && identical(state.last, snapshot))) {
      return;
    }
    final next = [...state, snapshot];
    state = next.length <= systemMetricsHistoryLimit
        ? next
        : next.sublist(next.length - systemMetricsHistoryLimit);
    final server = ref.read(activeServerProvider);
    if (server != null && (_lastSaved == null ||
        DateTime.now().difference(_lastSaved!) >= const Duration(seconds: 30))) {
      _lastSaved = DateTime.now();
      unawaited(ref.read(localStorageServiceProvider).savePageCache(server, 'metrics',
        snapshot.toJson()).catchError((Object error, StackTrace stack) {
          unawaited(AppDiagnostics.instance.record('dashboard.cache', error, stack));
        }));
    }
  }
}

final systemMetricsHistoryProvider =
    NotifierProvider<SystemMetricsHistoryNotifier, List<SystemMetricsSnapshot>>(
      SystemMetricsHistoryNotifier.new,
    );

class MetricsFormatters {
  static String formatUptime(int seconds) {
    if (seconds <= 0) return '0m';
    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  static String formatPercentage(double ratio) {
    final pct = (ratio * 100).clamp(0, 100);
    return '${pct.toStringAsFixed(1)}%';
  }
}
