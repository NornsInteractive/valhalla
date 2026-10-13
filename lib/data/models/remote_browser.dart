import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// [id] is a source-local path, or an opaque library ID for a flat source.
class RemoteBrowserEntry {
  final String id;
  final String name;
  final bool isDirectory;
  final bool canEnter;
  final int? sizeBytes;
  final int? modifiedEpoch;
  final bool isSymbolicLink;
  final String? linkTargetErrorCode;
  final String? mimeType;

  const RemoteBrowserEntry({
    required this.id,
    required this.name,
    required this.isDirectory,
    bool? canEnter,
    this.sizeBytes,
    this.modifiedEpoch,
    this.isSymbolicLink = false,
    this.linkTargetErrorCode,
    this.mimeType,
  }) : canEnter = canEnter ?? isDirectory;

  bool get isHidden => name.startsWith('.');
  bool get selectable => linkTargetErrorCode == null;
}

class RemoteBrowserSelection {
  final String targetKey;
  final List<RemoteBrowserEntry> entries;

  RemoteBrowserSelection({
    required this.targetKey,
    required List<RemoteBrowserEntry> entries,
  }) : entries = List.unmodifiable(entries);
}

/// One read-only browser lease. Disposing it must never close shared SSH clients.
class RemoteBrowserSource {
  final String targetKey;
  final String label;
  final String rootPath;
  final String initialPath;
  final bool flat;
  final bool Function() _isCurrent;
  final Stream<List<RemoteBrowserEntry>> Function(
    String path,
    Future<void> cancelled,
  )
  _list;
  final Future<Uint8List?> Function(RemoteBrowserEntry entry, int maxBytes)?
  _preview;
  final FutureOr<void> Function()? _dispose;
  bool _closed = false;
  Future<void>? _disposal;
  final Set<void Function()> _requests = {};

  RemoteBrowserSource({
    required this.targetKey,
    required this.label,
    required this.rootPath,
    required this.initialPath,
    this.flat = false,
    required bool Function() isCurrent,
    required Stream<List<RemoteBrowserEntry>> Function(
      String path,
      Future<void> cancelled,
    )
    list,
    Future<Uint8List?> Function(RemoteBrowserEntry entry, int maxBytes)?
    preview,
    FutureOr<void> Function()? dispose,
  }) : _isCurrent = isCurrent,
       _list = list,
       _preview = preview,
       _dispose = dispose {
    normalizeLocation(rootPath);
    normalizeLocation(initialPath);
  }

  bool get isCurrent => !_closed && _isCurrent();
  bool get supportsPreview => _preview != null;

  void ensureCurrent() {
    if (!isCurrent) throw StateError('REMOTE_BROWSER_TARGET_CHANGED');
  }

  String normalizeLocation(String value) {
    if (!value.startsWith('/') || value.contains('\u0000')) {
      throw ArgumentError('REMOTE_BROWSER_PATH_INVALID');
    }
    final path = p.posix.normalize(value);
    final root = p.posix.normalize(rootPath);
    if ((path != root && !p.posix.isWithin(root, path)) ||
        (flat && path != root)) {
      throw ArgumentError('REMOTE_BROWSER_PATH_OUTSIDE_ROOT');
    }
    return path;
  }

  String? parentOf(String value) {
    final path = normalizeLocation(value);
    return path == p.posix.normalize(rootPath) ? null : p.posix.dirname(path);
  }

  Stream<List<RemoteBrowserEntry>> list(String path) {
    final cancelled = Completer<void>();
    StreamSubscription<List<RemoteBrowserEntry>>? subscription;
    late final StreamController<List<RemoteBrowserEntry>> controller;
    var stopped = false;
    void stop() {
      if (stopped) return;
      stopped = true;
      _requests.remove(stop);
      cancelled.complete();
      // Cancel must not await a protocol channel still opening on a stalled peer.
      final closing = subscription?.cancel();
      if (closing != null) unawaited(closing.catchError((Object _) {}));
      unawaited(controller.close());
    }

    void fail(Object error, StackTrace stack) {
      if (stopped) return;
      controller.addError(error, stack);
      stop();
    }

    controller = StreamController<List<RemoteBrowserEntry>>(
      onListen: () {
        try {
          ensureCurrent();
          final location = normalizeLocation(path);
          _requests.add(stop);
          subscription = _list(location, cancelled.future).listen(
            (entries) {
              if (stopped) return;
              try {
                ensureCurrent();
                controller.add(List.unmodifiable(entries));
              } catch (error, stack) {
                fail(error, stack);
              }
            },
            onError: (Object error, StackTrace stack) => fail(error, stack),
            onDone: () {
              if (stopped) return;
              try {
                ensureCurrent();
                stop();
              } catch (error, stack) {
                fail(error, stack);
              }
            },
          );
          if (stopped) {
            unawaited(subscription!.cancel().catchError((Object _) {}));
          }
        } catch (error, stack) {
          fail(error, stack);
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: stop,
    );
    return controller.stream;
  }

  Future<Uint8List?> preview(
    RemoteBrowserEntry entry, {
    int maxBytes = 1024 * 1024,
  }) async {
    ensureCurrent();
    if (maxBytes < 1 || maxBytes > 8 * 1024 * 1024) {
      throw ArgumentError('REMOTE_BROWSER_PREVIEW_LIMIT_INVALID');
    }
    if (!entry.selectable ||
        entry.isDirectory ||
        !(entry.mimeType?.startsWith('image/') ?? false)) {
      return null;
    }
    if (!flat) normalizeLocation(entry.id);
    final bytes = await _preview?.call(entry, maxBytes);
    ensureCurrent();
    if (bytes != null && bytes.length > maxBytes) {
      throw StateError('REMOTE_BROWSER_PREVIEW_TOO_LARGE');
    }
    return bytes;
  }

  RemoteBrowserSelection selection(List<RemoteBrowserEntry> entries) {
    ensureCurrent();
    for (final entry in entries) {
      if (!entry.selectable) {
        throw StateError('REMOTE_BROWSER_ENTRY_UNAVAILABLE');
      }
      if (!flat) normalizeLocation(entry.id);
    }
    return RemoteBrowserSelection(targetKey: targetKey, entries: entries);
  }

  Future<void> dispose() {
    _closed = true;
    for (final cancel in _requests.toList()) {
      cancel();
    }
    return _disposal ??= Future<void>.sync(() => _dispose?.call());
  }
}
