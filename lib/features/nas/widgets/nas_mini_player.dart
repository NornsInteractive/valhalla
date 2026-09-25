import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../data/models/nas_media.dart';
import 'nas_cast_sheet.dart';
import 'nas_localizations.dart';

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

    return Container(
      key: const Key('nas_mini_player'),
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.path,
                        style: TextStyle(
                          fontSize: 10,
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
                        key: const Key('nas_mini_player_play_pause'),
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
                  onPressed: () => NasCastSheet.show(context, item: item),
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
      ),
    );
  }
}
