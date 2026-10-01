import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/app_visibility_provider.dart';
import '../../infrastructure/system/system_metrics_sampler.dart';
import '../../infrastructure/system/process_service.dart';
import '../../infrastructure/system/disk_usage_service.dart';
import '../../infrastructure/system/system_hardware_service.dart';

final systemHardwareProvider = FutureProvider.autoDispose<SystemHardwareInfo>((
  ref,
) async {
  final serverId = ref
      .watch(activeServerProvider.select((s) => s?.connectionKey))
      ?.$1;
  final connected = ref.watch(
    serverConnectionProvider.select((s) => s.isConnected),
  );
  if (serverId == null || !connected) throw StateError('SSH_DISCONNECTED');
  return ref.watch(systemHardwareServiceProvider).read(serverId);
});

final resourceProcessesProvider = StreamProvider.autoDispose<List<ProcessInfo>>(
  (ref) async* {
    final server = ref.watch(activeServerProvider);
    final connected = ref.watch(serverConnectionProvider).isConnected;
    if (server == null || !connected) return;
    final service = ref.watch(processServiceProvider);
    while (ref.mounted) {
      if (ref.read(appVisibilityProvider)) yield await service.list(server.id);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  },
);

final rootDiskUsageProvider = FutureProvider.autoDispose<RootDiskUsage>((
  ref,
) async {
  final server = ref.watch(activeServerProvider);
  final connected = ref.watch(serverConnectionProvider).isConnected;
  if (server == null || !connected) throw StateError('SSH_DISCONNECTED');
  return ref.watch(diskUsageServiceProvider).root(server.id);
});

final systemMetricsStreamProvider =
    StreamProvider.autoDispose<SystemMetricsSnapshot>((ref) {
      final activeServer = ref.watch(activeServerProvider);
      final connState = ref.watch(serverConnectionProvider);

      if (activeServer == null || !connState.isConnected) {
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
    // 服务器变化时重建并清空，避免把不同主机的数据画在同一条曲线上。
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    ref.listen(systemMetricsStreamProvider, (_, next) {
      next.whenData(_append);
    });
    return const [];
  }

  void _append(SystemMetricsSnapshot snapshot) {
    if (!ref.mounted || (state.isNotEmpty && identical(state.last, snapshot))) {
      return;
    }
    final next = [...state, snapshot];
    state = next.length <= systemMetricsHistoryLimit
        ? next
        : next.sublist(next.length - systemMetricsHistoryLimit);
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
