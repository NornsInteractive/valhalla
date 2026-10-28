import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/workspace/workspace_gateway.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

/// Workspace config records that mirror the bookmark and recent lists.
bool _isBookmarkMetadataRecord(Map<String, dynamic> record) {
  final id = record['id'];
  return record['kind'] == 'config' &&
      id is String &&
      (id.startsWith('valhalla_file_bookmarks::') ||
          id.startsWith('valhalla_recent_directories::'));
}

bool _samePaths(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final fileRecentDirectoriesProvider =
    NotifierProvider<FileRecentDirectoriesNotifier, List<String>>(
      FileRecentDirectoriesNotifier.new,
    );

class FileRecentDirectoriesNotifier extends Notifier<List<String>> {
  StreamSubscription<WorkspaceChange>? _workspaceChanges;
  Future<void> _writes = Future.value();
  @override
  List<String> build() {
    final id = ref.watch(activeServerProvider.select((s) => s?.id));
    unawaited(_workspaceChanges?.cancel());
    _workspaceChanges = ref
        .read(localStorageServiceProvider)
        .workspaceGateway
        ?.changes
        .listen((change) {
          if (!change.records.any(_isBookmarkMetadataRecord)) return;
          if (!ref.mounted || change.serverId != id) return;
          unawaited(_refreshFromWorkspace(change.serverId));
        });
    ref.onDispose(() => unawaited(_workspaceChanges?.cancel()));
    return id == null
        ? []
        : ref.read(localStorageServiceProvider).getRecentDirectories(id);
  }

  Future<void> _refreshFromWorkspace(String serverId) async {
    // A local record() may still be queued; read the mirror only after it.
    await _writes;
    if (!ref.mounted || ref.read(activeServerProvider)?.id != serverId) return;
    final next = ref
        .read(localStorageServiceProvider)
        .getRecentDirectories(serverId);
    // The gateway also emits empty polls; never rebuild for identical data.
    if (_samePaths(state, next)) return;
    state = next;
  }

  Future<void> record(String serverId, String directory) {
    if (!p.posix.isAbsolute(directory) || directory.contains('\x00')) {
      throw const FormatException('FILE_PATH_INVALID');
    }
    directory = p.posix.normalize(directory);
    final storage = ref.read(localStorageServiceProvider);
    final next = _writes.then((_) async {
      final entries = [
        directory,
        ...storage.getRecentDirectories(serverId).where((d) => d != directory),
      ].take(20).toList();
      await storage.saveRecentDirectories(serverId, entries);
      if (ref.mounted && ref.read(activeServerProvider)?.id == serverId) {
        state = entries;
      }
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}

final fileBookmarksProvider =
    NotifierProvider<FileBookmarksNotifier, List<String>>(
      FileBookmarksNotifier.new,
    );

class FileBookmarksNotifier extends Notifier<List<String>> {
  StreamSubscription<WorkspaceChange>? _workspaceChanges;
  @override
  List<String> build() {
    final server = ref.watch(activeServerProvider);
    unawaited(_workspaceChanges?.cancel());
    _workspaceChanges = ref
        .read(localStorageServiceProvider)
        .workspaceGateway
        ?.changes
        .listen((change) {
          if (!change.records.any(_isBookmarkMetadataRecord)) return;
          if (!ref.mounted || server == null) return;
          if (change.serverId != server.id) return;
          if (ref.read(activeServerProvider)?.id != server.id) return;
          _refreshFromWorkspace(server.id);
        });
    ref.onDispose(() => unawaited(_workspaceChanges?.cancel()));
    return server == null
        ? []
        : ref.read(localStorageServiceProvider).getFileBookmarks(server.id);
  }

  void _refreshFromWorkspace(String serverId) {
    final next = ref
        .read(localStorageServiceProvider)
        .getFileBookmarks(serverId);
    // The gateway also emits empty polls; never rebuild for identical data.
    if (_samePaths(state, next)) return;
    state = next;
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
