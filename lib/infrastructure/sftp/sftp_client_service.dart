import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/app_diagnostics.dart';

class SftpFileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final String formattedSize;
  final String permissions;
  final String modified;

  /// 修改时间的 Unix 秒；0 表示服务器没给（或给的是 0）。
  ///
  /// [modified] 只是给人看的预格式化字符串，排序时必须用这个数值字段——
  /// 那个字符串在缺失时会退化成 `'-'`，按字符串比较会得出错误顺序。
  /// 之所以可选并给默认值，是为了不打断各处已有的构造调用。
  final int modifiedEpoch;

  const SftpFileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
    required this.formattedSize,
    required this.permissions,
    required this.modified,
    this.modifiedEpoch = 0,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 一次进行中的传输的句柄。
///
/// 之所以要把句柄交出去而不是像以前那样 `await writer.done` 一了百了：
/// 分块循环执行期间，上层需要能暂停（挂起当前块）、恢复、以及中止
/// （立刻拆掉连接上的这个传输，而不是等它自然跑完）。
///
/// 暂停的语义是**挂起在块边界上**，不会回滚已经传完的字节；
/// [resume] 从挂起点继续，不需要重开远端句柄。
abstract interface class SftpTransferHandle {
  /// 当前已传输字节数。
  int get transferredBytes;

  /// 传输总字节数；0 表示未知（UI 应展示不确定进度条）。
  int get totalBytes;

  /// 传输完成 / 失败 / 被中止。正常完成时 `await` 它拿到的就是结果。
  Future<void> get done;

  /// 请求暂停。多次调用幂等。
  Future<void> pause();

  /// 从暂停处继续。未暂停时调用是空操作。
  Future<void> resume();

  /// 中止传输并清理远端/本地未完成的部分。
  ///
  /// 与 [pause] 的区别是它**不会**再继续：`done` 会抛出
  /// [SftpTransferAborted] 让上层把这次传输标记为已取消。
  Future<void> abort();
}

/// 传输被 [SftpTransferHandle.abort] 主动中止时抛出。
///
/// 单独成一个类型而不是复用 [SftpTransferAborted] 之外的异常，
/// 是因为上层要区分「用户取消」和「真的出错」——前者不该报错误提示。
class SftpTransferAborted implements Exception {
  const SftpTransferAborted();

  @override
  String toString() => 'SftpTransferAborted';
}

/// `SftpNotifier` 依赖的远端文件操作集合。
///
/// 抽出接口是为了让 provider 能在不建立真实 SSH/SFTP 连接的前提下被测试——
/// 传输与预览的失败分支（权限不足、目录不存在、磁盘写满）用真实服务器很难
/// 稳定复现，而它们恰恰是最容易写错的部分。
abstract interface class SftpOperations {
  /// 列出目录内容。
  Future<List<SftpFileItem>> listFiles(String path);

  /// 读取文本内容（UTF-8，允许非法字节以便仍能预览）。
  Future<String> readFileContent(String path);

  /// 覆盖写入文本内容。
  Future<void> writeFileContent(String path, String content);

  /// 新建目录。
  Future<void> createDirectory(String path);

  /// 删除文件。
  Future<void> deleteFile(String path);

  /// 删除目录。
  Future<void> deleteDirectory(String path);

  /// 重命名 / 移动。
  Future<void> rename(String oldPath, String newPath);

  /// 开始下载远端文件到本地路径，立刻返回可暂停/中止的句柄。
  ///
  /// 总字节数通过 `totalBytes` 暴露（取不到远端大小时为 0）。
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  });

  /// 开始上传本地文件到远端路径，立刻返回可暂停/中止的句柄。
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  });

  /// 下载远端文件到本地路径，返回传输字节数。
  ///
  /// 保留这个「一次性跑完」的便捷方法给不需要暂停的调用方
  /// （例如内部工具脚本路径），它内部基于 [startDownload]。
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  });

  /// 上传本地文件到远端路径，返回传输字节数。
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  });
}

class SftpClientService implements SftpOperations {
  static const maxPreviewBytes = 1024 * 1024;
  static const previewTooLargeCode = 'SFTP_PREVIEW_TOO_LARGE';
  final SSHClient? _sshClient;
  SftpClient? _sftp;
  Future<SftpClient>? _openingSftp;
  int _sessionEpoch = 0;
  bool _disposed = false;
  final Duration operationTimeout;
  static const _cleanupTimeout = Duration(seconds: 2);

  SftpClientService(
    this._sshClient, {
    this.operationTimeout = const Duration(seconds: 30),
  });

  void _closeClient(SftpClient client) {
    unawaited(
      Future<void>.sync(client.close).timeout(_cleanupTimeout).catchError((
        Object error,
        StackTrace stack,
      ) {
        unawaited(AppDiagnostics.instance.record('sftp.cleanup', error, stack));
      }),
    );
  }

  void _discardSession(int epoch) {
    if (epoch != _sessionEpoch) return;
    _sessionEpoch++;
    final client = _sftp;
    _sftp = null;
    _openingSftp = null;
    if (client != null) _closeClient(client);
  }

  Future<T> _bounded<T>(Future<T> Function() action) {
    final epoch = _sessionEpoch;
    return Future<T>.sync(
      action,
    ).timeout(operationTimeout).onError<TimeoutException>((error, stack) {
      _discardSession(epoch);
      throw const SFTPException('SFTP operation timed out');
    });
  }

  bool get isRealConnected =>
      !_disposed && _sshClient != null && !_sshClient.isClosed;

  void dispose() {
    _disposed = true;
    _discardSession(_sessionEpoch);
  }

  Future<SftpClient> _getRealSftp() async {
    if (!isRealConnected) {
      throw const SSHConnectionException(
        'SFTP operation failed: No active SSH connection to server.',
      );
    }
    if (_sftp != null) return _sftp!;
    final opening = _openingSftp;
    if (opening != null) return opening;
    final epoch = _sessionEpoch;
    final pending = _bounded(() async {
      final client = await _sshClient!.sftp();
      if (epoch != _sessionEpoch) {
        _closeClient(client);
        throw const SFTPException('SFTP session expired');
      }
      return _sftp = client;
    });
    _openingSftp = pending;
    try {
      return await pending;
    } finally {
      if (identical(_openingSftp, pending)) _openingSftp = null;
    }
  }

  @override
  Future<List<SftpFileItem>> listFiles(String path) => _bounded(() async {
    if (!isRealConnected) {
      throw const SSHConnectionException('No active SSH connection to server.');
    }

    final normalizedPath = path.isEmpty
        ? '/'
        : (path.endsWith('/') && path != '/'
              ? path.substring(0, path.length - 1)
              : path);
    final sftp = await _getRealSftp();
    final names = await sftp.listdir(normalizedPath);

    return names.map((entry) {
      final isDir = entry.attr.isDirectory;
      final size = entry.attr.size ?? 0;
      // 保留原始 epoch 秒：下面的 modStr 是给人看的，排序要用数值。
      final modEpochSeconds = entry.attr.modifyTime ?? 0;
      final modEpoch = modEpochSeconds * 1000;
      final modDate = DateTime.fromMillisecondsSinceEpoch(modEpoch);
      final modStr =
          '${modDate.year}-${modDate.month.toString().padLeft(2, '0')}-${modDate.day.toString().padLeft(2, '0')} ${modDate.hour.toString().padLeft(2, '0')}:${modDate.minute.toString().padLeft(2, '0')}';

      return SftpFileItem(
        name: entry.filename,
        path: normalizedPath == '/'
            ? '/${entry.filename}'
            : '$normalizedPath/${entry.filename}',
        isDirectory: isDir,
        sizeBytes: size,
        formattedSize: isDir ? '-' : SftpFileItem.formatBytes(size),
        permissions: _formatPermissions(entry.attr.mode, isDir),
        modified: modEpoch > 0 ? modStr : '-',
        modifiedEpoch: modEpochSeconds,
      );
    }).toList();
  });

  static String _formatPermissions(SftpFileMode? mode, bool isDirectory) {
    if (mode == null) return isDirectory ? 'd?????????' : '-?????????';
    final type = isDirectory ? 'd' : '-';
    String bit(bool value, String symbol) => value ? symbol : '-';
    return type +
        bit(mode.userRead, 'r') +
        bit(mode.userWrite, 'w') +
        bit(mode.userExecute, 'x') +
        bit(mode.groupRead, 'r') +
        bit(mode.groupWrite, 'w') +
        bit(mode.groupExecute, 'x') +
        bit(mode.otherRead, 'r') +
        bit(mode.otherWrite, 'w') +
        bit(mode.otherExecute, 'x');
  }

  @override
  Future<String> readFileContent(String path) => _bounded(() async {
    final sftp = await _getRealSftp();
    final file = await sftp.open(path, mode: SftpFileOpenMode.read);
    try {
      if (!identical(_sftp, sftp)) {
        throw const SFTPException('SFTP session expired');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.read(length: maxPreviewBytes + 1)) {
        if (bytes.length + chunk.length > maxPreviewBytes) {
          throw const SFTPException(previewTooLargeCode);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } finally {
      await file.close().timeout(_cleanupTimeout);
    }
  });

  @override
  Future<void> writeFileContent(String path, String content) =>
      _bounded(() async {
        final sftp = await _getRealSftp();
        final file = await sftp.open(
          path,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        try {
          if (!identical(_sftp, sftp)) {
            throw const SFTPException('SFTP session expired');
          }
          await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
        } finally {
          await file.close().timeout(_cleanupTimeout);
        }
      });

  @override
  Future<void> createDirectory(String path) => _bounded(() async {
    final sftp = await _getRealSftp();
    await sftp.mkdir(path);
  });

  @override
  Future<void> deleteFile(String path) => _bounded(() async {
    final sftp = await _getRealSftp();
    await sftp.remove(path);
  });

  @override
  Future<void> deleteDirectory(String path) => _bounded(() async {
    final sftp = await _getRealSftp();
    await sftp.rmdir(path);
  });

  @override
  Future<void> rename(String oldPath, String newPath) => _bounded(() async {
    final sftp = await _getRealSftp();
    await sftp.rename(oldPath, newPath);
  });

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    final sftp = await _getRealSftp();
    final attrs = await sftp.stat(remotePath);
    final total = attrs.size ?? 0;
    final remote = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    final local = File(localPath).openSync(mode: FileMode.write);
    final handle = _DownloadHandle(
      remote: remote,
      local: local,
      totalBytes: total,
      onProgress: onProgress,
    );
    handle.start();
    return handle;
  }

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    final sftp = await _getRealSftp();
    final local = File(localPath);
    final attrs = await local.stat();
    final remote = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    final handle = _UploadHandle(
      remote: remote,
      source: local.openRead().map(Uint8List.fromList),
      totalBytes: attrs.size,
      onProgress: onProgress,
    );
    return handle;
  }

  @override
  Future<int> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int bytesRead)? onProgress,
  }) async {
    final handle = await startDownload(
      remotePath,
      localPath,
      onProgress: onProgress,
    );
    await handle.done;
    return handle.transferredBytes;
  }

  @override
  Future<int> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int bytesWritten)? onProgress,
  }) async {
    final handle = await startUpload(
      localPath,
      remotePath,
      onProgress: onProgress,
    );
    await handle.done;
    return handle.totalBytes;
  }

  Future<void> move(String sourcePath, String destinationPath) =>
      rename(sourcePath, destinationPath);

  Future<void> chmod(String path, int mode) async {
    final sftp = await _getRealSftp();
    await sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));
  }
}

/// 下载句柄：分块读取远端文件、顺序写入本地。
///
/// 没有沿用 `sftp.download()` 便利函数，因为那个函数只返回总字节数、
/// 拿不到任何可以暂停或中止的抓手。这里手写循环，在**块边界**上检查
/// 暂停/中止标志：
///
/// - 暂停只是停在块与块之间，已写入本地的字节不回滚，继续时从当前位置接着写；
/// - 中止会关掉远端句柄与本地文件句柄，并让 [done] 抛 [SftpTransferAborted]。
///
/// 之所以是「块边界」而不是立刻中断：一次 SFTP 读请求一旦发出就无法
/// 单方面收回，只能等它回来。块的粒度是 [_chunkSize]，所以最坏情况下
/// 暂停会有一次读请求的延迟，换来的是不必重开连接。
class _DownloadHandle implements SftpTransferHandle {
  static const _chunkSize = 64 * 1024;

  final SftpFile _remote;
  final RandomAccessFile _local;
  final void Function(int bytesRead)? _onProgress;

  @override
  final int totalBytes;

  final _done = Completer<void>();
  var _transferred = 0;
  var _paused = false;
  var _aborted = false;
  var _closed = false;

  /// 每次从暂停切回运行时完成，循环在块边界上等它。
  Completer<void>? _resumeSignal;

  _DownloadHandle({
    required SftpFile remote,
    required RandomAccessFile local,
    required this.totalBytes,
    void Function(int bytesRead)? onProgress,
  }) : _remote = remote,
       _local = local,
       _onProgress = onProgress;

  @override
  int get transferredBytes => _transferred;

  @override
  Future<void> get done => _done.future;

  /// 启动循环。不 `await`，让调用方立刻拿到句柄去展示进度。
  void start() {
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      // 大小为 0 时按「未知」处理，一直读到服务器返回 EOF。
      // 这与 dartssh2 内部对 /proc 这类文件的处理一致：SFTP 用 EOF 状态码
      // 表示结束，而不是靠 stat 出来的大小。
      var remaining = totalBytes > 0 ? totalBytes : -1;
      while (remaining != 0) {
        await _waitIfPaused();
        if (_aborted) return;

        final want = remaining < 0
            ? _chunkSize
            : (remaining < _chunkSize ? remaining : _chunkSize);
        final chunk = await _remote.readBytes(
          offset: _transferred,
          length: want,
        );
        if (chunk.isEmpty) break; // EOF

        await _local.writeFrom(chunk);
        _transferred += chunk.length;
        _onProgress?.call(_transferred);
        if (remaining > 0) remaining -= chunk.length;
      }
      await _close();
      if (!_aborted) _done.complete();
    } catch (error, stackTrace) {
      await _close();
      if (!_done.isCompleted) _done.completeError(error, stackTrace);
    }
  }

  Future<void> _waitIfPaused() async {
    while (_paused && !_aborted) {
      _resumeSignal ??= Completer<void>();
      await _resumeSignal!.future;
    }
  }

  @override
  Future<void> pause() async {
    if (_aborted || _done.isCompleted) return;
    _paused = true;
  }

  @override
  Future<void> resume() async {
    if (_aborted || _done.isCompleted) return;
    _paused = false;
    final signal = _resumeSignal;
    _resumeSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  @override
  Future<void> abort() async {
    if (_aborted || _done.isCompleted) return;
    _aborted = true;
    // 先把循环从暂停里放出来，否则它会永远等在那个 Completer 上。
    final signal = _resumeSignal;
    _resumeSignal = null;
    if (signal != null && !signal.isCompleted) signal.complete();
    await _close();
    if (!_done.isCompleted) {
      _done.completeError(const SftpTransferAborted());
    }
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    // 任一侧关闭失败都不该盖住真正的传输结果，各自吞掉。
    try {
      await _local.close();
    } catch (_) {}
    try {
      await _remote.close();
    } catch (_) {}
  }
}

/// 上传句柄：把 dartssh2 的 [SftpFileWriter] 包一层。
///
/// 上传方向不需要手写循环——`SftpFileWriter` 本身就带
/// `pause()` / `resume()` / `abort()`，只是以前 `SftpClientService`
/// 只 `await writer.done` 把句柄丢掉了。这里把它接出来。
class _UploadHandle implements SftpTransferHandle {
  final SftpFile _remote;
  final SftpFileWriter _writer;

  @override
  final int totalBytes;

  final _done = Completer<void>();
  var _aborted = false;
  var _closed = false;

  _UploadHandle({
    required SftpFile remote,
    required Stream<Uint8List> source,
    required this.totalBytes,
    void Function(int bytesWritten)? onProgress,
  }) : _remote = remote,
       _writer = remote.write(
         source,
         chunkSize: 64 * 1024,
         onProgress: onProgress,
       ) {
    unawaited(_finish());
  }

  @override
  int get transferredBytes => _writer.progress;

  @override
  Future<void> get done => _done.future;

  Future<void> _finish() async {
    try {
      await _writer.done;
      // writer.abort() 会让 done 正常完成，所以要靠自己的标志区分
      // 「传完了」和「被中止了」——否则取消会被上层当成成功。
      if (_aborted) return;
      await _close();
      if (!_done.isCompleted) _done.complete();
    } catch (error, stackTrace) {
      await _close();
      if (!_done.isCompleted) _done.completeError(error, stackTrace);
    }
  }

  @override
  Future<void> pause() async {
    if (_aborted || _done.isCompleted) return;
    _writer.pause();
  }

  @override
  Future<void> resume() async {
    if (_aborted || _done.isCompleted) return;
    _writer.resume();
  }

  @override
  Future<void> abort() async {
    if (_aborted || _done.isCompleted) return;
    _aborted = true;
    await _writer.abort();
    await _close();
    if (!_done.isCompleted) {
      _done.completeError(const SftpTransferAborted());
    }
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _remote.close();
    } catch (_) {}
  }
}
