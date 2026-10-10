import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'server_provider.dart';
import 'storage_providers.dart';

final fileBookmarksProvider =
    NotifierProvider<FileBookmarksNotifier, List<String>>(
      FileBookmarksNotifier.new,
    );

class FileBookmarksNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final server = ref.watch(activeServerProvider);
    return server == null
        ? []
        : ref.read(localStorageServiceProvider).getFileBookmarks(server.id);
  }

  Future<void> toggle(String path) async {
    final serverId = ref.read(activeServerProvider)?.id;
    if (serverId == null) throw StateError('SERVER_NOT_FOUND');
    if (!p.posix.isAbsolute(path) || path.contains('\x00')) {
      throw const FormatException('FILE_PATH_INVALID');
    }
    path = p.posix.normalize(path);
    final updated = [...state];
    if (!updated.remove(path)) updated.add(path);
    await ref
        .read(localStorageServiceProvider)
        .saveFileBookmarks(serverId, updated);
    if (ref.mounted && ref.read(activeServerProvider)?.id == serverId) {
      state = updated;
    }
  }
}
