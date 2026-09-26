import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_media_player_service.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';
import 'nas_cast_sheet.dart';
import 'nas_localizations.dart';
import 'nas_queue_sheet.dart';

class NasFullPlayerDialog extends ConsumerStatefulWidget {
  final NasMediaItem item;
  final bool isPlaying;
  final double progress;
  final ValueChanged<bool> onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onOpenExternal;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final Player? player;

  const NasFullPlayerDialog({
    super.key,
    required this.item,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.onSeek,
    required this.onOpenExternal,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.player,
  });

  static Future<void> show(
    BuildContext context, {
    required NasMediaItem item,
    required bool isPlaying,
    required double progress,
    required ValueChanged<bool> onPlayPause,
    required ValueChanged<double> onSeek,
    required VoidCallback onOpenExternal,
    required bool isFavorite,
    required VoidCallback onToggleFavorite,
    Player? player,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NasFullPlayerDialog(
        item: item,
        isPlaying: isPlaying,
        progress: progress,
        onPlayPause: onPlayPause,
        onSeek: onSeek,
        onOpenExternal: onOpenExternal,
        isFavorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
        player: player,
      ),
    );
  }

  @override
  ConsumerState<NasFullPlayerDialog> createState() =>
      _NasFullPlayerDialogState();
}

class _NasFullPlayerDialogState extends ConsumerState<NasFullPlayerDialog> {
  bool _commandInProgress = false;
  bool _favoriteInProgress = false;

  Future<void> _executePlayerAction(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(NasMediaItem currentItem, bool isFav) async {
    if (_favoriteInProgress) return;
    setState(() => _favoriteInProgress = true);
    try {
      await ref.read(nasProvider.notifier).setFavorite(currentItem, !isFav);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _favoriteInProgress = false);
      }
    }
  }

  Future<void> _playOrPause(
    NasMediaPlayerService? playerService,
    bool isPlaying,
  ) async {
    if (_commandInProgress) return;
    _commandInProgress = true;
    try {
      if (playerService != null) {
        await playerService.playOrPause();
      } else {
        widget.onPlayPause(!isPlaying);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _commandInProgress = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  void _showTracksSheet(
    BuildContext context,
    Player player,
    NasMediaPlayerService service,
  ) {
    final tracks = player.state.tracks;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.nasAudioTrack,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final track in tracks.audio)
                ListTile(
                  dense: true,
                  title: Text(track.title ?? track.language ?? track.id),
                  selected: track == player.state.track.audio,
                  onTap: () {
                    Navigator.pop(ctx);
                    _executePlayerAction(
                      () async => service.setAudioTrack(track),
                    );
                  },
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.nasSubtitleTrack,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ListTile(
                dense: true,
                title: Text(context.nasSubtitleNone),
                selected: player.state.track.subtitle == SubtitleTrack.no(),
                onTap: () {
                  Navigator.pop(ctx);
                  _executePlayerAction(
                    () async => service.setSubtitleTrack(SubtitleTrack.no()),
                  );
                },
              ),
              for (final track in tracks.subtitle)
                ListTile(
                  dense: true,
                  title: Text(track.title ?? track.language ?? track.id),
                  selected: track == player.state.track.subtitle,
                  onTap: () {
                    Navigator.pop(ctx);
                    _executePlayerAction(
                      () async => service.setSubtitleTrack(track),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedDialog(
    BuildContext context,
    NasMediaPlayerService service,
    double currentRate,
  ) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.nasSpeed),
        children: speeds.map((speed) {
          final isSelected = (currentRate - speed).abs() < 0.05;
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _executePlayerAction(() async => service.setRate(speed));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${speed}x'),
                if (isSelected) const Icon(Icons.check, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showQualityDialog(
    BuildContext context,
    NasMediaPlayerService service,
    NasPlaybackQuality currentQuality,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.nasQuality),
        children: NasPlaybackQuality.values.map((quality) {
          final isSelected = quality == currentQuality;
          final name = switch (quality) {
            NasPlaybackQuality.original => ctx.nasQualityOriginal,
            NasPlaybackQuality.auto => ctx.nasQualityAuto,
            NasPlaybackQuality.mbps4 => ctx.nasQuality4Mbps,
            NasPlaybackQuality.mbps10 => ctx.nasQuality10Mbps,
            NasPlaybackQuality.mbps20 => ctx.nasQuality20Mbps,
          };
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _executePlayerAction(() async => service.setQuality(quality));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name),
                if (isSelected) const Icon(Icons.check, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playbackAsync = ref.watch(nasPlaybackProvider);
    final snapshot =
        playbackAsync.asData?.value ??
        ref.watch(nasMediaPlayerProvider).asData?.value.state ??
        NasPlayerSnapshot(
          current: widget.item,
          playing: widget.isPlaying,
          duration: widget.item.duration ?? Duration.zero,
        );

    final currentItem = snapshot.current ?? widget.item;
    final isVideo = currentItem.kind == NasMediaKind.video;
    final isPlaying = snapshot.playing;
    final position = snapshot.position;
    final duration = snapshot.duration > Duration.zero
        ? snapshot.duration
        : (currentItem.duration ?? Duration.zero);
    final isFav = currentItem.isFavorite;

    final playerService = ref.watch(nasMediaPlayerProvider).asData?.value;
    final effectivePlayer = playerService?.player ?? widget.player;

    final videoControllerAsync = isVideo
        ? ref.watch(nasVideoControllerProvider)
        : null;
    final videoController = videoControllerAsync?.asData?.value;

    final double progressRatio = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : widget.progress.clamp(0.0, 1.0);

    return Container(
      key: const Key('nas_full_player'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VRadius.sheet),
        ),
        boxShadow: vElevation(theme.brightness, strength: 1.6),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(VRadius.pill),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header: Type & Action Buttons
            Builder(
              builder: (context) {
                final isNarrow = MediaQuery.sizeOf(context).width < 500;
                final favoriteBtn = IconButton(
                  key: const Key('nas_full_player_favorite_button'),
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isFav ? context.vDanger : theme.colorScheme.outline,
                  ),
                  tooltip: context.l10n.nasTabFavorites,
                  onPressed: _favoriteInProgress
                      ? null
                      : () => _toggleFavorite(currentItem, isFav),
                );

                final actionButtons = <Widget>[
                  if (isVideo &&
                      effectivePlayer != null &&
                      playerService != null)
                    IconButton(
                      key: const Key('nas_full_player_tracks_button'),
                      icon: const Icon(Icons.subtitles_outlined, size: 20),
                      tooltip: context.nasSubtitleTrack,
                      onPressed: () => _showTracksSheet(
                        context,
                        effectivePlayer,
                        playerService,
                      ),
                    ),
                  if (isVideo && playerService != null)
                    IconButton(
                      key: const Key('nas_full_player_quality_button'),
                      icon: const Icon(Icons.high_quality_outlined, size: 20),
                      tooltip: context.nasQuality,
                      onPressed: () => _showQualityDialog(
                        context,
                        playerService,
                        snapshot.quality,
                      ),
                    ),
                  IconButton(
                    key: const Key('nas_full_player_download_button'),
                    icon: const Icon(Icons.download_outlined, size: 20),
                    tooltip: context.nasTabDownloads,
                    onPressed: () {
                      ref.read(nasProvider.notifier).download(currentItem);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.nasDownloading(currentItem.name),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    key: const Key('nas_full_player_cast_button'),
                    icon: const Icon(Icons.cast, size: 20),
                    tooltip: context.nasCast,
                    onPressed: () =>
                        NasCastSheet.show(context, item: currentItem),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 20),
                    tooltip: context.l10n.nasOpenPolicyExternal,
                    onPressed: widget.onOpenExternal,
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('nas_full_player_minimize'),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 24,
                            ),
                            tooltip: context.l10n.nasMiniPlayer,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.nasNowPlaying,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  currentItem.name,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          favoriteBtn,
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actionButtons,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    IconButton(
                      key: const Key('nas_full_player_minimize'),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 24),
                      tooltip: context.l10n.nasMiniPlayer,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.nasNowPlaying,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            currentItem.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ...actionButtons,
                    favoriteBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Video Player or Album Art Display
            if (isVideo)
              Container(
                key: const Key('nas_video_container'),
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
                clipBehavior: Clip.antiAlias,
                child: videoController != null
                    ? Video(controller: videoController)
                    : (videoControllerAsync?.hasError == true
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  context.nasSanitizedError(
                                    videoControllerAsync!.error!,
                                  ),
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator())),
              )
            else
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  isVideo ? Icons.movie : Icons.music_note_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 16),

            // Track / Video Title and Subtitle Info
            Text(
              currentItem.title ?? currentItem.name,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              currentItem.artist ?? currentItem.folder,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Progress Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: const Key('nas_full_player_slider'),
                value: progressRatio,
                onChanged: (val) {
                  _executePlayerAction(() async {
                    if (playerService != null && duration > Duration.zero) {
                      await playerService.seek(duration * val);
                    } else {
                      widget.onSeek(val);
                    }
                  });
                },
              ),
            ),

            // Time Display Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Playback Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle toggle
                IconButton(
                  key: const Key('nas_full_player_shuffle'),
                  icon: Icon(
                    snapshot.shuffle
                        ? Icons.shuffle_on_rounded
                        : Icons.shuffle_rounded,
                    color: snapshot.shuffle
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    size: 22,
                  ),
                  tooltip: context.nasShuffle,
                  onPressed: () {
                    _executePlayerAction(() {
                      playerService?.setShuffle(!snapshot.shuffle);
                    });
                  },
                ),
                const SizedBox(width: 8),

                // Previous track
                IconButton(
                  key: const Key('nas_full_player_prev'),
                  icon: const Icon(Icons.skip_previous_rounded, size: 30),
                  onPressed: () {
                    _executePlayerAction(() async {
                      if (playerService != null) {
                        await playerService.previous();
                      } else {
                        widget.onSeek(0);
                      }
                    });
                  },
                ),
                const SizedBox(width: 12),

                // Play / Pause main button
                IconButton.filled(
                  key: const Key('nas_full_player_play_pause'),
                  iconSize: 40,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: () => _playOrPause(playerService, isPlaying),
                ),
                const SizedBox(width: 12),

                // Next track
                IconButton(
                  key: const Key('nas_full_player_next'),
                  icon: const Icon(Icons.skip_next_rounded, size: 30),
                  onPressed: () {
                    _executePlayerAction(() async {
                      await playerService?.next();
                    });
                  },
                ),
                const SizedBox(width: 8),

                // Repeat mode toggle
                IconButton(
                  key: const Key('nas_full_player_repeat'),
                  icon: Icon(
                    snapshot.repeat == NasRepeat.one
                        ? Icons.repeat_one_rounded
                        : (snapshot.repeat == NasRepeat.all
                              ? Icons.repeat_on_rounded
                              : Icons.repeat_rounded),
                    color: snapshot.repeat != NasRepeat.off
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    size: 22,
                  ),
                  tooltip: switch (snapshot.repeat) {
                    NasRepeat.off => context.nasRepeatOff,
                    NasRepeat.all => context.nasRepeatAll,
                    NasRepeat.one => context.nasRepeatOne,
                  },
                  onPressed: () {
                    final next = switch (snapshot.repeat) {
                      NasRepeat.off => NasRepeat.all,
                      NasRepeat.all => NasRepeat.one,
                      NasRepeat.one => NasRepeat.off,
                    };
                    _executePlayerAction(() {
                      playerService?.setRepeat(next);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Secondary controls: Speed & Queue Sheet
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (playerService != null)
                  TextButton.icon(
                    key: const Key('nas_full_player_speed_button'),
                    icon: const Icon(Icons.speed, size: 16),
                    label: Text(
                      '${snapshot.rate}x',
                      style: monoTextStyle(fontSize: 12),
                    ),
                    onPressed: () =>
                        _showSpeedDialog(context, playerService, snapshot.rate),
                  ),
                TextButton.icon(
                  key: const Key('nas_full_player_queue_button'),
                  icon: const Icon(Icons.queue_music, size: 16),
                  label: Text('${context.nasQueue} (${snapshot.queue.length})'),
                  onPressed: () => NasQueueSheet.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
