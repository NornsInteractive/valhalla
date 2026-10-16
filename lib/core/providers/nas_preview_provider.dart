import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/nas_media.dart';

String nasPreviewKey(NasMediaItem item) =>
    '${item.serverId}\u0000${item.path}\u0000${item.modifiedEpoch}\u0000${item.sizeBytes}';

class NasPreviewRequest {
  final NasMediaItem item;
  final bool visible;
  const NasPreviewRequest(this.item, {required this.visible});
}

final nasPreviewRequestsProvider =
    NotifierProvider<NasPreviewRequests, Map<String, NasPreviewRequest>>(
      NasPreviewRequests.new,
    );

class NasPreviewRequests extends Notifier<Map<String, NasPreviewRequest>> {
  final _owners = <Object, (List<NasMediaItem>, List<NasMediaItem>)>{};
  @override
  Map<String, NasPreviewRequest> build() => const {};

  void update(
    Object owner, {
    required List<NasMediaItem> visible,
    List<NasMediaItem> prefetch = const [],
  }) {
    _owners[owner] = (visible, prefetch);
    _publish();
  }

  void release(Object owner) {
    if (_owners.remove(owner) != null) _publish();
  }

  void _publish() {
    final next = <String, NasPreviewRequest>{};
    for (final value in _owners.values) {
      for (final item in value.$1) {
        final key = nasPreviewKey(item);
        next[key] = state[key]?.visible == true
            ? state[key]!
            : NasPreviewRequest(item, visible: true);
      }
    }
    var count = 0;
    for (final value in _owners.values) {
      for (final item in value.$2) {
        final key = nasPreviewKey(item);
        if (next.containsKey(key) || count >= 24) continue;
        next[key] = state[key]?.visible == false
            ? state[key]!
            : NasPreviewRequest(item, visible: false);
        count++;
      }
    }
    if (next.length != state.length ||
        next.entries.any((e) => !identical(e.value, state[e.key]))) {
      state = Map.unmodifiable(next);
    }
  }
}
