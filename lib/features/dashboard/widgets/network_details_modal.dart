import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/system/system_metrics_sampler.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/valhalla_card.dart';
import '../dashboard_provider.dart';

String formatNetworkRate(double bytesPerSec) {
  if (bytesPerSec <= 0) return '0 B/s';
  if (bytesPerSec < 1024) {
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  } else if (bytesPerSec < 1024 * 1024) {
    return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
  } else if (bytesPerSec < 1024 * 1024 * 1024) {
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  } else {
    return '${(bytesPerSec / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }
}

String formatNetworkBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

void showNetworkDetailsModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(
      maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
    ),
    builder: (_) => const NetworkDetailsModal(),
  );
}

class NetworkDetailsModal extends ConsumerWidget {
  const NetworkDetailsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(systemMetricsStreamProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.settings_ethernet_rounded,
                      color: context.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.networkModalTitle,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            metricsAsync.when(
              data: (snapshot) => _buildInterfacesList(context, snapshot),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: LoadingStateView(),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorStateView(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(systemMetricsStreamProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfacesList(
    BuildContext context,
    SystemMetricsSnapshot snapshot,
  ) {
    final interfaces = snapshot.networkCounters.keys.toList();
    if (interfaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.l10n.networkRatesEmpty,
            style: TextStyle(color: context.colorScheme.outline),
          ),
        ),
      );
    }

    // Sort: primary interface first, then non-lo, then lo
    interfaces.sort((a, b) {
      if (a == snapshot.primaryNetworkInterface) return -1;
      if (b == snapshot.primaryNetworkInterface) return 1;
      if (a == 'lo') return 1;
      if (b == 'lo') return -1;
      return a.compareTo(b);
    });

    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: interfaces.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final iface = interfaces[index];
          final isPrimary = iface == snapshot.primaryNetworkInterface;
          final rate = snapshot.networkRates[iface];
          final counters = snapshot.networkCounters[iface];

          final rxRate = rate?.rxBytesPerSecond ?? 0.0;
          final txRate = rate?.txBytesPerSecond ?? 0.0;
          final rxBytes = counters?.$1 ?? 0;
          final txBytes = counters?.$2 ?? 0;

          return ValhallaCard(
            key: Key('network_interface_card_$iface'),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPrimary
                              ? Icons.wifi_tethering_rounded
                              : Icons.alt_route_rounded,
                          size: 16,
                          color: isPrimary
                              ? context.colorScheme.primary
                              : context.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          iface,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isPrimary)
                      StatusBadge(
                        label: context.l10n.networkPrimary,
                        type: StatusType.online,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: context.vSuccess,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.networkDownloadRate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rate != null
                                ? formatNetworkRate(rxRate)
                                : context.l10n.networkWaitingSecondSample,
                            style: TextStyle(
                              fontFamily: rate != null
                                  ? 'JetBrains Mono'
                                  : null,
                              fontSize: rate != null ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: rate == null
                                  ? context.colorScheme.outline
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.networkTotalRx}: ${formatNetworkBytes(rxBytes)}',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: context.vInfo,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.networkUploadRate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rate != null
                                ? formatNetworkRate(txRate)
                                : context.l10n.networkWaitingSecondSample,
                            style: TextStyle(
                              fontFamily: rate != null
                                  ? 'JetBrains Mono'
                                  : null,
                              fontSize: rate != null ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: rate == null
                                  ? context.colorScheme.outline
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.l10n.networkTotalTx}: ${formatNetworkBytes(txBytes)}',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
