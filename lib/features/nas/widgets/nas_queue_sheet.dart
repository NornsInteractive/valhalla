import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/nas_provider.dart';
import '../../../core/services/nas_media_player_service.dart';
import 'nas_localizations.dart';

class NasQueueSheet extends ConsumerWidget {
  const NasQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => const NasQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playbackAsync = ref.watch(nasPlaybackProvider);
    final snapshot =
        playbackAsync.asData?.value ??
        ref.watch(nasMediaPlayerProvider).asData?.value.state ??
        const NasPlayerSnapshot();
    final playerService = ref.watch(nasMediaPlayerProvider).asData?.value;

    final queue = snapshot.queue;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${context.nasQueue} (${queue.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('nas_queue_shuffle_button'),
                    icon: Icon(
                      snapshot.shuffle
                          ? Icons.shuffle_on_rounded
                          : Icons.shuffle_rounded,
                      color: snapshot.shuffle
                          ? theme.colorScheme.primary
                          : null,
                      size: 20,
                    ),
                    tooltip: context.nasShuffle,
                    onPressed: () =>
                        playerService?.setShuffle(!snapshot.shuffle),
                  ),
                  IconButton(
                    key: const Key('nas_queue_repeat_button'),
                    icon: Icon(
                      snapshot.repeat == NasRepeat.one
                          ? Icons.repeat_one_rounded
                          : (snapshot.repeat == NasRepeat.all
                                ? Icons.repeat_on_rounded
                                : Icons.repeat_rounded),
                      color: snapshot.repeat != NasRepeat.off
                          ? theme.colorScheme.primary
                          : null,
                      size: 20,
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
                      playerService?.setRepeat(next);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (queue.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    context.nasNoQueue,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  key: const Key('nas_queue_list'),
                  shrinkWrap: true,
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final isCurrent = index == snapshot.index;

                    return ListTile(
                      key: Key('nas_queue_item_$index'),
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      leading: Icon(
                        isCurrent
                            ? (snapshot.playing
                                  ? Icons.play_arrow
                                  : Icons.pause)
                            : Icons.music_note,
                        size: 20,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      title: Text(
                        item.title ?? item.name,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent ? theme.colorScheme.primary : null,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.artist ?? item.folder,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        playerService?.jumpTo(index);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
