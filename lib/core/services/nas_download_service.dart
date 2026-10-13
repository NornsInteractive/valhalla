import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../data/models/nas_download.dart';
import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/repositories/nas_index_repository.dart';
import '../../infrastructure/nas/nas_http_client.dart';
import 'download_platform_service.dart';
import 'app_diagnostics.dart';

export '../../data/models/nas_download.dart';

class NasDownloadService {
  final Future<NasSourceAdapter> Function(String) adapterFor;
  final Future<NasIndexRepository> Function()? repository;
  final String Function(String)? sourceIdentityFor;
  final DownloadPlatformService platform;
  final _changes = StreamController<List<NasDownloadTask>>.broadcast();
  final _tasks = <String, NasDownloadTask>{};
  final _cancellations = <String, NasCancellation>{};
  final _active = <String, Completer<void>>{};
  final _openWhenDone = <String>{};
  Future<void> _writes = Future.value();
  late final Future<void> ready;
  bool _disposed = false, _loaded = false;
  int _sequence = 0;

  NasDownloadService(
    this.adapterFor, {
    DownloadPlatformService? platform,
    this.repository,
    this.sourceIdentityFor,
  }) : platform = platform ?? DownloadPlatformService() {
    ready = _restore();
    ready.ignore();
  }

  List<NasDownloadTask> get tasks =>
      List.unmodifiable(_tasks.values.toList().reversed);
  Stream<List<NasDownloadTask>> get changes => _changes.stream;

  Future<void> _restore() async {
    final saved = repository == null
        ? <NasDownloadTask>[]
        : await (await repository!()).loadDownloads();
    if (_disposed) return;
    for (var task in saved) {
      if (task.status == NasDownloadStatus.downloading ||
          task.status == NasDownloadStatus.queued) {
        task = task.copyWith(status: NasDownloadStatus.paused);
        try {
          if (task.sha256 != null && await _validFile(task)) {
            task = task.copyWith(status: NasDownloadStatus.completed);
          }
        } catch (_) {
          task = task.copyWith(
            status: NasDownloadStatus.failed,
            error: 'NAS_OFFLINE_FILE_INVALID',
          );
        }
      }
      _tasks.putIfAbsent(task.id, () => task);
    }
    if (_disposed) return;
    await _persist();
    _loaded = true;
    _emit();
    _pump();
  }

  Future<void> _persist() {
    if (repository == null) return Future.value();
    final snapshot = _tasks.values.toList(growable: false);
    final next = _writes.then(
      (_) async => (await repository!()).saveDownloads(snapshot),
    );
    _writes = next.catchError((Object _) {});
    return next;
  }

  void _emit() {
    if (!_disposed) _changes.add(tasks);
  }

  Future<void> _notify(String id) async {
    final task = _tasks[id];
    if (task == null) return;
    try {
      await platform.report({
        'id': task.id,
        'name': task.item.name,
        'path': task.status == NasDownloadStatus.completed
            ? task.localPath
            : null,
        'bytes': task.received,
        'total': task.total ?? 0,
        'target': 'nas',
        'status': switch (task.status) {
          NasDownloadStatus.downloading => 'running',
          NasDownloadStatus.cancelled => 'canceled',
          _ => task.status.name,
        },
      });
    } catch (error, stack) {
      await AppDiagnostics.instance.record(
        'nas.download.notification',
        error,
        stack,
      );
    }
  }

  String download(NasMediaItem item, {bool openWhenDone = false}) {
    if (_disposed) throw StateError('NAS_DOWNLOAD_SERVICE_CLOSED');
    if (_tasks.length >= 1000) throw StateError('NAS_DOWNLOAD_QUEUE_FULL');
    final id = 'nas-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    _tasks[id] = NasDownloadTask(id: id, item: item);
    if (openWhenDone) _openWhenDone.add(id);
    _emit();
    _pump();
    return id;
  }

  Future<void> pause(String id) async {
    await ready;
    final task = _tasks[id];
    if (task == null ||
        !{
          NasDownloadStatus.queued,
          NasDownloadStatus.downloading,
        }.contains(task.status)) {
      return;
    }
    _tasks[id] = task.copyWith(status: NasDownloadStatus.paused);
    _cancellations[id]?.cancel();
    _emit();
    await _active[id]?.future;
    await _persist();
  }

  void cancel(String id) {
    unawaited(
      _cancel(
        id,
      ).catchError((Object _) => _fail(id, 'NAS_DOWNLOAD_STORAGE_FAILED')),
    );
  }

  Future<void> _cancel(String id) async {
    await pause(id);
    await _active[id]?.future;
    final task = _tasks[id];
    if (task == null || task.status == NasDownloadStatus.completed) return;
    _tasks[id] = task.copyWith(status: NasDownloadStatus.cancelled);
    _openWhenDone.remove(id);
    await _deletePartial(task);
    await _persist();
    await _notify(id);
    _emit();
  }

  Future<void> resume(String id) async {
    await ready;
    await _active[id]?.future;
    final task = _tasks[id];
    if (task == null ||
        !{
          NasDownloadStatus.paused,
          NasDownloadStatus.failed,
        }.contains(task.status)) {
      return;
    }
    _tasks[id] = task.copyWith(
      status: NasDownloadStatus.queued,
      clearError: true,
    );
    await _persist();
    _emit();
    _pump();
  }

  void retry(String id) {
    unawaited(
      restart(
        id,
      ).catchError((Object _) => _fail(id, 'NAS_DOWNLOAD_STORAGE_FAILED')),
    );
  }

  Future<void> restart(String id) async {
    await pause(id);
    await _active[id]?.future;
    final task = _tasks[id];
    if (task == null || task.status == NasDownloadStatus.completed) return;
    await _deletePartial(task);
    _tasks[id] = NasDownloadTask(id: id, item: task.item);
    await _persist();
    _emit();
    _pump();
  }

  Future<void> _deletePartial(NasDownloadTask task) async {
    final path = task.localPath;
    if (path != null && await platform.ownsPath('$path.part')) {
      final file = File('$path.part');
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> remove(String id) async {
    await pause(id);
    await _active[id]?.future;
    final task = _tasks[id];
    if (task == null) return;
    await _deletePartial(task);
    if (task.status == NasDownloadStatus.completed && task.localPath != null) {
      if (!await platform.ownsPath(task.localPath!)) {
        throw StateError('NAS_DOWNLOAD_PATH_INVALID');
      }
      final file = File(task.localPath!);
      if (await file.exists()) await file.delete();
    }
    _tasks[id] = task.copyWith(status: NasDownloadStatus.cancelled);
    await _notify(id);
    _tasks.remove(id);
    _openWhenDone.remove(id);
    await _persist();
    _emit();
  }

  Future<bool> _validFile(NasDownloadTask task) async {
    final path = task.localPath;
    if (path == null || task.sha256 == null || !await platform.ownsPath(path)) {
      return false;
    }
    final file = File(path);
    if (!await file.exists() || await file.length() != task.received) {
      return false;
    }
    return (await sha256.bind(file.openRead()).first).toString() == task.sha256;
  }

  Future<String> localFile(String id) async {
    await ready;
    final task = _tasks[id];
    if (task == null || task.status != NasDownloadStatus.completed) {
      throw StateError('NAS_DOWNLOAD_NOT_COMPLETE');
    }
    if (!await _validFile(task)) throw StateError('NAS_OFFLINE_FILE_INVALID');
    return task.localPath!;
  }

  Future<String?> localPathFor(NasMediaItem item) async {
    await ready;
    final task = tasks
        .where(
          (t) =>
              t.status == NasDownloadStatus.completed &&
              t.item.serverId == item.serverId &&
              t.item.path == item.path &&
              t.item.modifiedEpoch == item.modifiedEpoch &&
              t.item.sizeBytes == item.sizeBytes,
        )
        .firstOrNull;
    return task == null ? null : localFile(task.id);
  }

  Future<void> open(String id) async {
    await platform.openFile(await localFile(id));
    final task = _tasks[id];
    if (task != null && task.error != null) {
      _tasks[id] = task.copyWith(clearError: true);
      await _persist();
      _emit();
    }
  }

  Future<void> reveal(String id) async =>
      platform.revealFile(await localFile(id));

  void _pump() {
    if (!_loaded || _disposed) return;
    while (_active.length < 2) {
      final task = _tasks.values
          .where(
            (t) =>
                t.status == NasDownloadStatus.queued &&
                !_active.containsKey(t.id),
          )
          .firstOrNull;
      if (task == null) break;
      final cancellation = NasCancellation();
      _cancellations[task.id] = cancellation;
      _active[task.id] = Completer<void>();
      _tasks[task.id] = task.copyWith(status: NasDownloadStatus.downloading);
      unawaited(_run(task.id, cancellation));
    }
  }

  void _fail(String id, String code) {
    final task = _tasks[id];
    if (task != null) {
      _tasks[id] = task.copyWith(
        status: task.status == NasDownloadStatus.completed
            ? task.status
            : NasDownloadStatus.failed,
        error: code,
      );
    }
    _emit();
  }

  Future<void> _run(String id, NasCancellation cancellation) async {
    IOSink? sink;
    try {
      await _persist();
      var task = _tasks[id]!;
      final configuredIdentity = sourceIdentityFor?.call(task.item.serverId);
      final adapter = await adapterFor(task.item.serverId);
      final identity =
          configuredIdentity ??
          sha256
              .convert(
                utf8.encode(
                  jsonEncode(adapter.source.toJson()..remove('name')),
                ),
              )
              .toString();
      final resource = await adapter.resolveForDownload(task.item);
      cancellation.check();
      if (configuredIdentity != null &&
          sourceIdentityFor!(task.item.serverId) != configuredIdentity) {
        throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
      }
      if (resource.mimeType.contains('mpegurl') ||
          resource.uri?.path.endsWith('.m3u8') == true) {
        throw StateError('NAS_OFFLINE_HLS_UNSUPPORTED');
      }
      final target =
          task.localPath ?? await platform.reservePath(task.item.name);
      if (!await platform.ownsPath(target) ||
          !await platform.ownsPath('$target.part')) {
        throw StateError('NAS_DOWNLOAD_PATH_INVALID');
      }
      final partial = File('$target.part');
      var received = await partial.exists() ? await partial.length() : 0;
      if (received > 0 &&
          (task.sourceIdentity != identity ||
              task.resourceVersion == null ||
              task.resourceVersion != resource.version ||
              resource.sizeBytes == null ||
              task.total != resource.sizeBytes ||
              received > resource.sizeBytes!)) {
        throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
      }
      task = task.copyWith(
        localPath: target,
        sourceIdentity: identity,
        resourceVersion: resource.version,
        received: received,
        total: resource.sizeBytes,
      );
      _tasks[id] = task;
      await _persist();
      cancellation.check();
      sink = partial.openWrite(mode: FileMode.append);
      var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      var lastSave = lastUpdate;
      if (received != resource.sizeBytes) {
        await for (final chunk in readNasResource(
          resource,
          received,
          resource.sizeBytes,
          cancellation,
        )) {
          cancellation.check();
          sink.add(chunk);
          await sink.flush();
          received += chunk.length;
          _tasks[id] = _tasks[id]!.copyWith(received: received);
          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds >= 250) {
            lastUpdate = now;
            _emit();
          }
          if (now.difference(lastSave).inSeconds >= 1) {
            lastSave = now;
            await _persist();
            await _notify(id);
          }
        }
      }
      await sink.close();
      sink = null;
      cancellation.check();
      if (resource.sizeBytes != null && received != resource.sizeBytes) {
        throw StateError('NAS_INCOMPLETE_DOWNLOAD');
      }
      if (resource.version != null &&
          (await adapter.resolveForDownload(task.item)).version !=
              resource.version) {
        throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
      }
      if (configuredIdentity != null &&
          sourceIdentityFor!(task.item.serverId) != configuredIdentity) {
        throw StateError('NAS_DOWNLOAD_SOURCE_CHANGED');
      }
      final digest = (await sha256.bind(partial.openRead()).first).toString();
      cancellation.check();
      _tasks[id] = _tasks[id]!.copyWith(
        received: received,
        total: received,
        sha256: digest,
      );
      // Persist before rename so a process exit cannot orphan a finished file.
      await _persist();
      cancellation.check();
      if (await File(target).exists()) {
        throw StateError('NAS_DOWNLOAD_TARGET_EXISTS');
      }
      await partial.rename(target);
      _tasks[id] = _tasks[id]!.copyWith(
        status: NasDownloadStatus.completed,
        clearError: true,
      );
      await _persist();
      _emit();
      if (_openWhenDone.remove(id)) await platform.openFile(target);
    } catch (error) {
      if (!cancellation.isCancelled) {
        final code = error is NasHttpException && error.status == 412
            ? 'NAS_DOWNLOAD_SOURCE_CHANGED'
            : error is StateError && error.message.toString().startsWith('NAS_')
            ? error.message.toString()
            : 'NAS_DOWNLOAD_FAILED';
        _fail(
          id,
          _tasks[id]?.status == NasDownloadStatus.completed
              ? 'NAS_EXTERNAL_OPEN_FAILED'
              : code,
        );
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        await _persist();
      } catch (_) {
        _fail(id, 'NAS_DOWNLOAD_STORAGE_FAILED');
      }
      await _notify(id);
      _cancellations.remove(id);
      _active.remove(id)?.complete();
      _emit();
      _pump();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final entry in _cancellations.entries) {
      final task = _tasks[entry.key];
      if (task != null && task.status == NasDownloadStatus.downloading) {
        _tasks[entry.key] = task.copyWith(status: NasDownloadStatus.paused);
      }
      entry.value.cancel();
    }
    await Future.wait(_active.values.map((c) => c.future));
    try {
      if (_loaded) await _persist();
    } catch (error, stack) {
      await AppDiagnostics.instance.record(
        'nas.download.dispose',
        error,
        stack,
      );
    } finally {
      await _changes.close();
    }
  }
}
