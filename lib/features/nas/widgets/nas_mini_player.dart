import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../data/models/nas_media.dart';
import 'nas_cast_sheet.dart';
import 'nas_localizations.dart';

/// 全局迷你播放条: 玻璃质感圆角条 + 底部实时进度线 + 上滑入场。
class NasMiniPlayer extends StatelessWidget {
  final NasMediaItem item;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;
  final VoidCallback onExpand;
  final Player? player;

  const NasMiniPlayer({
    super.key,
    required this.item,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onClose,
    required this.onExpand,
    this.player,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = item.kind == NasMediaKind.video;

    return Entrance(
      index: 0,
      offset: const Offset(0, 24),
      child: Container(
        key: const Key('nas_mini_player'),
        height: 62,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(VRadius.card),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: vElevation(theme.brightness, strength: 1.4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.card),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(VRadius.card),
                onTap: onExpand,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isVideo
                                    ? Icons.movie_outlined
                                    : Icons.music_note_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: theme.textTheme.titleSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.path,
                                    style: monoTextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      color: theme.colorScheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (player != null)
                              StreamBuilder<bool>(
                                stream: player!.stream.playing,
                                initialData: player!.state.playing,
                                builder: (context, snapshot) {
                                  final active = snapshot.data ?? isPlaying;
                                  return IconButton(
                                    key: const Key(
                                      'nas_mini_player_play_pause',
                                    ),
                                    icon: Icon(
                                      active
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      size: 28,
                                      color: theme.colorScheme.primary,
                                    ),
                                    onPressed: onPlayPause,
                                  );
                                },
                              )
                            else
                              IconButton(
                                key: const Key('nas_mini_player_play_pause'),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  size: 28,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: onPlayPause,
                              ),
                            IconButton(
                              key: const Key('nas_mini_player_cast_button'),
                              icon: const Icon(Icons.cast, size: 18),
                              tooltip: context.nasCast,
                              onPressed: () =>
                                  NasCastSheet.show(context, item: item),
                            ),
                            IconButton(
                              key: const Key('nas_mini_player_close'),
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: onClose,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _MiniPlayerProgressLine(player: player),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部 2px 实时进度线: 位置流驱动, 数值变化平滑追赶。
class _MiniPlayerProgressLine extends StatelessWidget {
  final Player? player;

  const _MiniPlayerProgressLine({this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (player == null) return const SizedBox(height: 2);

    return StreamBuilder<Duration>(
      stream: player!.stream.position,
      initialData: player!.state.position,
      builder: (context, positionSnapshot) {
        final duration = player!.state.duration;
        final ratio = duration.inMilliseconds > 0
            ? (positionSnapshot.data?.inMilliseconds ?? 0) /
                  duration.inMilliseconds
            : 0.0;
        return AnimatedProgressBar(
          value: ratio,
          height: 2,
          color: theme.colorScheme.primary,
          trackColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        );
      },
    );
  }
}
