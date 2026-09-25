import 'dart:async';
import 'dart:io';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../infrastructure/nas/nas_http_client.dart';
import 'download_platform_service.dart';

enum NasDownloadStatus { queued, downloading, completed, cancelled, failed }

class NasDownloadTask {
  final String id;
  final NasMediaItem item;
  final NasDownloadStatus status;
  final int received;
  final int? total;
  final String? localPath, error;
  const NasDownloadTask({
    required this.id,
    required this.item,
    this.status = NasDownloadStatus.queued,
    this.received = 0,
    this.total,
    this.localPath,
    this.error,
  });
}

class NasDownloadService {
  final Future<NasSourceAdapter> Function(String) adapterFor;
  final DownloadPlatformService platform;
  final _changes = StreamController<List<NasDownloadTask>>.broadcast();
  final _tasks = <String, NasDownloadTask>{};
  final _cancellations = <String, NasCancellation>{};
  final _openWhenDone = <String>{};
  bool _disposed = false;
  int _running = 0, _sequence = 0;
  NasDownloadService(this.adapterFor, {DownloadPlatformService? platform})
    : platform = platform ?? DownloadPlatformService();
  List<NasDownloadTask> get tasks =>
      List.unmodifiable(_tasks.values.toList().reversed);
  Stream<List<NasDownloadTask>> get changes => _changes.stream;

  String download(NasMediaItem item, {bool openWhenDone = false}) {
    if (_disposed) throw StateError('NAS_DOWNLOAD_SERVICE_CLOSED');
    if (_tasks.length >= 100) {
      final old = _tasks.values
          .where(
            (e) =>
                e.status == NasDownloadStatus.completed ||
                e.status == NasDownloadStatus.cancelled,
          )
          .firstOrNull;
      if (old == null) throw StateError('NAS_DOWNLOAD_QUEUE_FULL');
      _tasks.remove(old.id);
    }
    final id = 'nas-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    _tasks[id] = NasDownloadTask(id: id, item: item);
    if (openWhenDone) _openWhenDone.add(id);
    _emit();
    _pump();
    return id;
  }

  void cancel(String id) {
    final task = _tasks[id];
    if (task == null || task.status == NasDownloadStatus.completed) return;
    _cancellations[id]?.cancel();
    _tasks[id] = NasDownloadTask(
      id: id,
      item: task.item,
      status: NasDownloadStatus.cancelled,
      received: task.received,
      total: task.total,
    );
    _openWhenDone.remove(id);
    _emit();
  }

  void retry(String id) {
    final task = _tasks[id];
    if (task == null ||
        _cancellations.containsKey(id) ||
        (task.status != NasDownloadStatus.failed &&
            task.status != NasDownloadStatus.cancelled)) {
      return;
    }
    _tasks[id] = NasDownloadTask(id: id, item: task.item);
    _emit();
    _pump();
  }

  Future<void> open(String id) async {
    final task = _tasks[id];
    final path = task?.localPath;
    if (path == null) throw StateError('NAS_DOWNLOAD_NOT_COMPLETE');
    await platform.openFile(path);
    if (task!.error != null) {
      _tasks[id] = NasDownloadTask(
        id: id,
        item: task.item,
        status: task.status,
        received: task.received,
        total: task.total,
        localPath: path,
      );
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) _changes.add(tasks);
  }

  void _pump() {
    if (_disposed) return;
    while (_running < 2) {
      final task = _tasks.values
          .where((e) => e.status == NasDownloadStatus.queued)
          .firstOrNull;
      if (task == null) break;
      _running++;
      final cancellation = NasCancellation();
      _cancellations[task.id] = cancellation;
      _tasks[task.id] = NasDownloadTask(
        id: task.id,
        item: task.item,
        status: NasDownloadStatus.downloading,
      );
      unawaited(_run(task, cancellation));
    }
  }

  Future<void> _run(NasDownloadTask task, NasCancellation cancellation) async {
    File? partial;
    IOSink? sink;
    try {
      final adapter = await adapterFor(task.item.serverId);
      cancellation.check();
      final resource = await adapter.resolve(task.item);
      cancellation.check();
      final target = await platform.reservePath(task.item.name);
      partial = File('$target.part');
      sink = partial.openWrite();
      var received = 0;
      var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in readNasResource(
        resource,
        0,
        resource.sizeBytes,
        cancellation,
      )) {
        cancellation.check();
        sink.add(chunk);
        received += chunk.length;
        // Backpressure bounds the file sink and avoids retaining a large download.
        await sink.flush();
        if (DateTime.now().difference(lastUpdate).inMilliseconds >= 250) {
          lastUpdate = DateTime.now();
          _tasks[task.id] = NasDownloadTask(
            id: task.id,
            item: task.item,
            status: NasDownloadStatus.downloading,
            received: received,
            total: resource.sizeBytes,
          );
          _emit();
        }
      }
      await sink.close();
      sink = null;
      cancellation.check();
      if (resource.sizeBytes != null && resource.sizeBytes != received) {
        throw StateError('NAS_INCOMPLETE_DOWNLOAD');
      }
      if (await File(target).exists()) {
        throw StateError('NAS_DOWNLOAD_TARGET_EXISTS');
      }
      await partial.rename(target);
      partial = null;
      _tasks[task.id] = NasDownloadTask(
        id: task.id,
        item: task.item,
        status: NasDownloadStatus.completed,
        received: received,
        total: received,
        localPath: target,
      );
      _emit();
      if (_openWhenDone.remove(task.id)) await platform.openFile(target);
    } catch (_) {
      final complete = _tasks[task.id]?.status == NasDownloadStatus.completed;
      if (!complete) {
        _tasks[task.id] = NasDownloadTask(
          id: task.id,
          item: task.item,
          status: cancellation.isCancelled
              ? NasDownloadStatus.cancelled
              : NasDownloadStatus.failed,
          error: cancellation.isCancelled ? null : 'NAS_DOWNLOAD_FAILED',
        );
      } else {
        final completed = _tasks[task.id]!;
        _tasks[task.id] = NasDownloadTask(
          id: task.id,
          item: task.item,
          status: NasDownloadStatus.completed,
          received: completed.received,
          total: completed.total,
          localPath: completed.localPath,
          error: 'NAS_EXTERNAL_OPEN_FAILED',
        );
      }
    } finally {
      try {
        try {
          await sink?.close();
        } catch (_) {}
        try {
          if (partial != null && await partial.exists()) await partial.delete();
        } catch (_) {}
      } finally {
        _cancellations.remove(task.id);
        _running--;
        _emit();
        _pump();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
    await _changes.close();
  }
}
