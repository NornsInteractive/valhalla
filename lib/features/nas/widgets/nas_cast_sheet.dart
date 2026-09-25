import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/providers/nas_cast_provider.dart';
import '../../../data/models/nas_media.dart';
import 'nas_localizations.dart';

class NasCastSheet extends ConsumerStatefulWidget {
  final NasMediaItem? item;

  const NasCastSheet({super.key, this.item});

  static Future<void> show(BuildContext context, {NasMediaItem? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
      ),
      builder: (_) => NasCastSheet(item: item),
    );
  }

  @override
  ConsumerState<NasCastSheet> createState() => _NasCastSheetState();
}

class _NasCastSheetState extends ConsumerState<NasCastSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(nasCastServiceProvider).discover();
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final castService = ref.watch(nasCastServiceProvider);
    final castStateAsync = ref.watch(nasCastStateProvider);
    final castState = castStateAsync.asData?.value ?? castService.state;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cast, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        context.nasCast,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (castState.discovering)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          key: const Key('nas_cast_refresh_button'),
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: context.nasCastRetry,
                          onPressed: () => castService.discover(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),

              // Error banner
              if (castState.error != null) ...[
                Container(
                  key: const Key('nas_cast_error_banner'),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          castState.error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => castService.discover(),
                        child: Text(context.nasCastRetry),
                      ),
                    ],
                  ),
                ),
              ],

              // Active Cast Session
              if (castState.activeDevice != null) ...[
                Card(
                  key: const Key('nas_cast_active_card'),
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cast_connected,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    castState.activeDevice!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    castState.item?.name ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.outline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              key: const Key('nas_cast_stop_button'),
                              icon: const Icon(Icons.stop, size: 18),
                              tooltip: context.nasCastStop,
                              onPressed: () => castService.stop(),
                            ),
                          ],
                        ),

                        if (castState.isRelaying) ...[
                          const SizedBox(height: 8),
                          Container(
                            key: const Key('nas_cast_relay_notice'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    context.nasCastRelayingNotice,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Playback Controls
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              key: const Key('nas_cast_play_pause_button'),
                              icon: Icon(
                                castState.playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 32,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                if (castState.playing) {
                                  castService.pause();
                                } else {
                                  castService.play();
                                }
                              },
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Slider(
                                    value: castState.position.inSeconds
                                        .toDouble()
                                        .clamp(
                                          0.0,
                                          castState.duration?.inSeconds
                                                  .toDouble() ??
                                              0.0,
                                        ),
                                    max:
                                        (castState.duration?.inSeconds ?? 0) > 0
                                        ? castState.duration!.inSeconds
                                              .toDouble()
                                        : 1.0,
                                    onChanged: (val) {
                                      castService.seek(
                                        Duration(seconds: val.round()),
                                      );
                                    },
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(castState.position),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(
                                          castState.duration ?? Duration.zero,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Volume Control
                        Row(
                          children: [
                            const Icon(Icons.volume_down, size: 16),
                            Expanded(
                              child: Slider(
                                value: castState.volume.clamp(0.0, 1.0),
                                onChanged: (val) => castService.setVolume(val),
                              ),
                            ),
                            const Icon(Icons.volume_up, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Devices List Section
              Text(
                context.nasCastDevices,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (castState.discovering && castState.devices.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          context.nasCastDiscovering,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (castState.devices.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tv_off,
                          size: 40,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.nasCastUnavailable,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('nas_cast_empty_retry_button'),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(context.nasCastRetry),
                          onPressed: () => castService.discover(),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...castState.devices.map((dev) {
                  final isCurrentActive = dev.id == castState.activeDevice?.id;
                  return ListTile(
                    key: Key('nas_cast_device_${dev.id}'),
                    leading: Icon(
                      Icons.tv,
                      color: isCurrentActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    title: Text(
                      dev.name,
                      style: TextStyle(
                        fontWeight: isCurrentActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      dev.location.host,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    trailing: isCurrentActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.cast),
                            tooltip: context.nasCast,
                            onPressed: () {
                              final target = widget.item ?? castState.item;
                              if (target != null) {
                                castService.start(dev, target);
                              }
                            },
                          ),
                    onTap: () {
                      final target = widget.item ?? castState.item;
                      if (target != null) {
                        castService.start(dev, target);
                      }
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
