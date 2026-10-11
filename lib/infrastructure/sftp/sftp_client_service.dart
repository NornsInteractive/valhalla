import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path_util;
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/app_diagnostics.dart';
import '../../core/utils/shell_quote.dart';

class SftpFileItem {
  final String name;
  final String path;

  /// For a resolved symlink this describes its target; [path] remains the alias.
  final bool isDirectory;
  final bool isSymbolicLink;
  final String? linkTargetErrorCode;
  static const linkTargetUnavailableCode = 'SFTP_LINK_TARGET_UNAVAILABLE';
  static const linkTargetPermissionDeniedCode =
      'SFTP_LINK_TARGET_PERMISSION_DENIED';
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
    this.isSymbolicLink = false,
    this.linkTargetErrorCode,
  });

  Map<String, dynamic> toJson() => {'name': name, 'path': path,
    'isDirectory': isDirectory, 'isSymbolicLink': isSymbolicLink,
    'linkTargetErrorCode': linkTargetErrorCode, 'sizeBytes': sizeBytes,
    'formattedSize': formattedSize, 'permissions': permissions,
    'modified': modified, 'modifiedEpoch': modifiedEpoch};

  factory SftpFileItem.fromJson(Map<String, dynamic> json) => SftpFileItem(
    name: json['name'] as String, path: json['path'] as String,
    isDirectory: json['isDirectory'] as bool,
    isSymbolicLink: json['isSymbolicLink'] as bool? ?? false,
    linkTargetErrorCode: json['linkTargetErrorCode'] as String?,
    sizeBytes: json['sizeBytes'] as int, formattedSize: json['formattedSize'] as String,
    permissions: json['permissions'] as String, modified: json['modified'] as String,
    modifiedEpoch: json['modifiedEpoch'] as int? ?? 0);

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

/// Atomic upload publication cannot truthfully be canceled once it has started.
abstract interface class SftpCommittingTransfer {
  bool get isCommitting;
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

  /// 新建文本文件；已有同名入口时拒绝覆盖。
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

class SftpTextSnapshot {
  final String path;
  final String targetPath;
  final String content;
  final String digest;
  final SftpFileAttrs attributes;

  const SftpTextSnapshot({required this.path, required this.targetPath,
    required this.content, required this.digest, required this.attributes});
}

abstract interface class SftpEditorOperations {
  Future<SftpTextSnapshot> readTextSnapshot(String path);
  Future<void> saveTextSnapshot(SftpTextSnapshot original, String content);
}

abstract interface class SftpResumableOperations {
  Future<void> discardUploadPartial(String remotePath, String transferId);
  Future<SftpTransferHandle> startResumableDownload(String remotePath, String localPath, {
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  });
  Future<SftpTransferHandle> startResumableUpload(String localPath, String remotePath, {
    required String transferId,
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  });
}

class SftpClientService implements SftpOperations, SftpEditorOperations, SftpResumableOperations {
  static const maxPreviewBytes = 1024 * 1024;
  static const previewTooLargeCode = 'SFTP_PREVIEW_TOO_LARGE';
  final SSHClient? _sshClient;
  SftpClient? _sftp;
  Future<SftpClient>? _openingSftp;
  final Set<SftpClient> _downloadClients = {};
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
    for (final client in _downloadClients) {
      _closeClient(client);
    }
    _downloadClients.clear();
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
    final items = List<SftpFileItem?>.filled(names.length, null);
    var nextIndex = 0;

    Future<void> resolveEntries() async {
      while (nextIndex < names.length) {
        if (!identical(_sftp, sftp) || !isRealConnected) {
          throw const SFTPException('SFTP session expired');
        }
        final index = nextIndex++;
        final entry = names[index];
        final itemPath = normalizedPath == '/'
            ? '/${entry.filename}'
            : '$normalizedPath/${entry.filename}';
        final isLink = entry.attr.isSymbolicLink;
        var attrs = entry.attr;
        String? linkError;
        if (isLink) {
          try {
            attrs = await sftp.stat(itemPath);
            if (attrs.isSymbolicLink ||
                attrs.mode == null ||
                attrs.type == SftpFileType.unknown) {
              linkError = SftpFileItem.linkTargetUnavailableCode;
            }
          } on SftpStatusError catch (error) {
            if (error.code == SftpStatusCode.noConnection ||
                error.code == SftpStatusCode.connectionLost ||
                error.code == SftpStatusCode.badMessage) {
              if (identical(_sftp, sftp)) _discardSession(_sessionEpoch);
              throw const SFTPException('SFTP connection or protocol failure');
            }
            linkError = error.code == SftpStatusCode.permissionDenied
                ? SftpFileItem.linkTargetPermissionDeniedCode
                : SftpFileItem.linkTargetUnavailableCode;
          }
        }
        final isDir = linkError == null && attrs.isDirectory;
        final size = attrs.size ?? 0;
        // 保留原始 epoch 秒：下面的 modStr 是给人看的，排序要用数值。
        final modEpochSeconds = entry.attr.modifyTime ?? 0;
        final modEpoch = modEpochSeconds * 1000;
        final modDate = DateTime.fromMillisecondsSinceEpoch(modEpoch);
        final modStr =
            '${modDate.year}-${modDate.month.toString().padLeft(2, '0')}-${modDate.day.toString().padLeft(2, '0')} ${modDate.hour.toString().padLeft(2, '0')}:${modDate.minute.toString().padLeft(2, '0')}';

        items[index] = SftpFileItem(
          name: entry.filename,
          path: itemPath,
          isDirectory: isDir,
          isSymbolicLink: isLink,
          linkTargetErrorCode: linkError,
          sizeBytes: size,
          formattedSize: isDir ? '-' : SftpFileItem.formatBytes(size),
          permissions: _formatPermissions(
            entry.attr.mode,
            entry.attr.isDirectory,
          ),
          modified: modEpoch > 0 ? modStr : '-',
          modifiedEpoch: modEpochSeconds,
        );
      }
    }

    await Future.wait(
      List.generate(
        names.length < 4 ? names.length : 4,
        (_) => resolveEntries(),
      ),
    );
    return items.cast<SftpFileItem>();
  });

  static String _formatPermissions(SftpFileMode? mode, bool isDirectory) {
    if (mode == null) return isDirectory ? 'd?????????' : '-?????????';
    final type = mode.type == SftpFileType.symbolicLink
        ? 'l'
        : (isDirectory ? 'd' : '-');
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
        // New-file creation must never truncate a colliding existing entry.
        final file = await sftp.open(
          path,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.exclusive,
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

  Future<SftpTextSnapshot> _snapshot(SftpClient sftp, String path) async {
    final target = await sftp.absolute(path);
    final before = await sftp.stat(target);
    if (!before.isFile || before.size == null || before.size! > maxPreviewBytes) {
      throw const SFTPException(previewTooLargeCode);
    }
    final file = await sftp.open(target);
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in file.read(length: maxPreviewBytes + 1)) {
        if (bytes.length + chunk.length > maxPreviewBytes) {
          throw const SFTPException(previewTooLargeCode);
        }
        bytes.add(chunk);
      }
    } finally {
      await file.close().timeout(_cleanupTimeout);
    }
    final after = await sftp.stat(target);
    if (before.size != after.size || before.modifyTime != after.modifyTime ||
        bytes.length != after.size || target != await sftp.absolute(path)) {
      throw const SFTPException('SFTP_EDIT_CONFLICT');
    }
    final data = bytes.takeBytes();
    // Editing invalid UTF-8 would silently replace original bytes on save.
    final content = utf8.decode(data);
    return SftpTextSnapshot(path: path, targetPath: target, content: content,
      digest: sha256.convert(data).toString(), attributes: after);
  }

  @override
  Future<SftpTextSnapshot> readTextSnapshot(String path) => _bounded(() async {
    return _snapshot(await _getRealSftp(), path);
  });

  @override
  Future<void> saveTextSnapshot(SftpTextSnapshot original, String content) =>
      _bounded(() async {
    final sftp = await _getRealSftp();
    if ((await sftp.handshake).extensions['posix-rename@openssh.com'] != '1') {
      throw const SFTPException('SFTP_ATOMIC_SAVE_UNSUPPORTED');
    }
    final data = Uint8List.fromList(utf8.encode(content));
    if (data.length > maxPreviewBytes) {
      throw const SFTPException(previewTooLargeCode);
    }
    final temporary = path_util.posix.join(
      path_util.posix.dirname(original.targetPath),
      '.valhalla-edit-${const Uuid().v4()}.part',
    );
    var created = false;
    var committed = false;
    try {
      final file = await sftp.open(temporary, mode: SftpFileOpenMode.write |
        SftpFileOpenMode.create | SftpFileOpenMode.exclusive);
      created = true;
      try {
        await file.writeBytes(data);
        await file.setStat(SftpFileAttrs(mode: original.attributes.mode,
          userID: original.attributes.userID, groupID: original.attributes.groupID));
      } finally {
        await file.close().timeout(_cleanupTimeout);
      }
      final current = await _snapshot(sftp, original.path);
      if (current.targetPath != original.targetPath ||
          current.digest != original.digest ||
          current.attributes.modifyTime != original.attributes.modifyTime ||
          current.attributes.mode?.value != original.attributes.mode?.value ||
          current.attributes.userID != original.attributes.userID ||
          current.attributes.groupID != original.attributes.groupID) {
        throw const SFTPException('SFTP_EDIT_CONFLICT');
      }
      if (!identical(sftp, _sftp) || !isRealConnected) {
        throw const SFTPException('SFTP session expired');
      }
      // shortcut: SFTP has no compare-and-swap rename; concurrent writers in
      // the final check/rename window require server-side locking to exclude.
      await sftp.rename(temporary, original.targetPath);
      committed = true;
    } finally {
      if (created && !committed) {
        try {
          await sftp.remove(temporary).timeout(_cleanupTimeout);
        } catch (error, stack) {
          unawaited(AppDiagnostics.instance.record('sftp.edit.cleanup', error, stack));
        }
      }
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
    return _startDownload(remotePath, localPath, onProgress: onProgress);
  }

  @override
  Future<SftpTransferHandle> startResumableDownload(String remotePath, String localPath, {
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  }) => _startDownload(remotePath, localPath, expectedSource: expectedSource,
    onSource: onSource, onProgress: onProgress);

  Future<SftpTransferHandle> _startDownload(String remotePath, String localPath, {
    Map<String, dynamic>? expectedSource,
    void Function(Map<String, dynamic>)? onSource,
    void Function(int)? onProgress,
  }) async {
    if (!isRealConnected) {
      throw const SSHConnectionException('SSH_DISCONNECTED');
    }
    // Browsing timeouts discard their channel; they must not abort downloads.
    var openingExpired = false;
    final SftpClient sftp;
    try {
      sftp = await _sshClient!
          .sftp()
          .then((client) {
            if (openingExpired || _disposed) {
              _closeClient(client);
              throw const SSHConnectionException('SSH_DISCONNECTED');
            }
            return client;
          })
          .timeout(operationTimeout);
    } finally {
      openingExpired = true;
    }
    _downloadClients.add(sftp);
    void closeChannel() {
      _downloadClients.remove(sftp);
      _closeClient(sftp);
    }

    try {
      final attrs = await sftp.stat(remotePath).timeout(operationTimeout);
      final total = attrs.size ?? 0;
      final identity = {'target': await sftp.absolute(remotePath).timeout(operationTimeout),
        'size': attrs.size, 'modified': attrs.modifyTime};
      if (expectedSource != null && !_sameSource(identity, expectedSource)) {
        throw const SFTPException('SFTP_TRANSFER_SOURCE_CHANGED');
      }
      final remote = await sftp
          .open(remotePath, mode: SftpFileOpenMode.read)
          .timeout(operationTimeout);
      final RandomAccessFile local;
      var offset = 0;
      try {
        if (onSource != null && await File(localPath).exists()) {
          offset = await File(localPath).length();
          if (expectedSource == null && offset > 0 || offset > total ||
              offset > 0 && attrs.size == null) {
            throw const SFTPException('SFTP_TRANSFER_PARTIAL_INVALID');
          }
          await _verifyPartial(remote, File(localPath), offset);
        }
        onSource?.call(identity);
        local = await File(localPath).open(mode: offset == 0 ? FileMode.write : FileMode.append);
      } catch (_) {
        await remote.close().timeout(_cleanupTimeout).catchError((Object _) {});
        rethrow;
      }
      final handle = _DownloadHandle(
        remote: remote,
        local: local,
        totalBytes: total,
        onProgress: onProgress,
        onClose: closeChannel,
        initialOffset: offset,
        validateComplete: onSource == null ? null : () async {
          final after = await sftp.stat(remotePath).timeout(operationTimeout);
          if (after.size != attrs.size || after.modifyTime != attrs.modifyTime ||
              await sftp.absolute(remotePath).timeout(operationTimeout) != identity['target']) {
            throw const SFTPException('SFTP_TRANSFER_SOURCE_CHANGED');
          }
        },
      );
      handle.start();
      return handle;
    } catch (_) {
      closeChannel();
      rethrow;
    }
  }

  Future<void> _verifyPartial(SftpFile remote, File local, int length) async {
    if (length == 0) return;
    final reader = await local.open();
    try {
      var offset = 0;
      while (offset < length) {
        final count = (length - offset).clamp(0, 64 * 1024);
        final left = await reader.read(count);
        final right = await remote.readBytes(offset: offset, length: count).timeout(operationTimeout);
        if (left.length != right.length || !_sameBytes(left, right)) {
          throw const SFTPException('SFTP_TRANSFER_PARTIAL_INVALID');
        }
        offset += count;
      }
    } finally { await reader.close(); }
  }

  bool _sameBytes(List<int> left, List<int> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameSource(Map<String, dynamic> actual, Map<String, dynamic> expected) =>
      actual.length == expected.length &&
      actual.entries.every((entry) => expected.containsKey(entry.key) &&
          expected[entry.key] == entry.value);

  @override
  Future<SftpTransferHandle> startResumableUpload(String localPath, String remotePath, {
    required String transferId,
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(transferId)) {
      throw ArgumentError.value(transferId, 'transferId');
    }
    final sftp = await _getRealSftp();
    final local = File(localPath);
    final attrs = await local.stat();
    if (attrs.type != FileSystemEntityType.file) throw const SFTPException('SFTP_UPLOAD_SOURCE_INVALID');
    final identity = {'size': attrs.size, 'modified': attrs.modified.microsecondsSinceEpoch,
      'digest': (await sha256.bind(local.openRead()).first).toString()};
    if (expectedSource != null && !_sameSource(identity, expectedSource)) {
      throw const SFTPException('SFTP_TRANSFER_SOURCE_CHANGED');
    }
    try {
      await sftp.stat(remotePath, followLink: false);
      throw const SFTPException('SFTP_UPLOAD_TARGET_EXISTS');
    } on SftpStatusError catch (error) {
      if (error.code != SftpStatusCode.noSuchFile) rethrow;
    }
    final temporary = path_util.posix.join(path_util.posix.dirname(remotePath),
      '.valhalla-upload-$transferId.part');
    var offset = 0;
    var partialExists = false;
    try {
      final partial = await sftp.stat(temporary, followLink: false);
      partialExists = true;
      if (expectedSource == null || partial.mode?.type != SftpFileType.regularFile ||
          partial.size == null || partial.size! > attrs.size) {
        throw const SFTPException('SFTP_TRANSFER_PARTIAL_INVALID');
      }
      offset = partial.size!;
      final reader = await sftp.open(temporary, mode: SftpFileOpenMode.read);
      try { await _verifyPartial(reader, local, offset); }
      finally { await reader.close(); }
    } on SftpStatusError catch (error) {
      if (error.code != SftpStatusCode.noSuchFile) rethrow;
    }
    onSource(identity);
    final remote = await sftp.open(temporary, mode: !partialExists
      ? SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.exclusive
      : SftpFileOpenMode.write);
    return _UploadHandle(remote: remote, source: local.openRead(offset).map(Uint8List.fromList),
      totalBytes: attrs.size, initialOffset: offset, onProgress: onProgress,
      commit: () async {
        final after = await local.stat();
        if (after.size != attrs.size || after.modified != attrs.modified ||
            (await sha256.bind(local.openRead()).first).toString() != identity['digest']) {
          throw const SFTPException('SFTP_TRANSFER_SOURCE_CHANGED');
        }
        // shortcut: this client exposes only replacing rename; safe upload
        // commit requires POSIX ln on the host, otherwise retain the partial.
        final session = await _sshClient!.execute(
          'LC_ALL=C ln -- ${cliShellQuote(temporary)} ${cliShellQuote(remotePath)}');
        try {
          await Future.wait([session.stdout.drain<void>(), session.stderr.drain<void>(),
            session.done]).timeout(operationTimeout);
          if (session.exitCode != 0) throw const SFTPException('SFTP_UPLOAD_COMMIT_FAILED');
        } finally { session.close(); }
        try { await sftp.remove(temporary).timeout(_cleanupTimeout); }
        catch (error, stack) {
          unawaited(AppDiagnostics.instance.record('sftp.upload.cleanup', error, stack));
        }
      });
  }

  @override
  Future<void> discardUploadPartial(String remotePath, String transferId) => _bounded(() async {
    if (!RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(transferId)) {
      throw ArgumentError.value(transferId, 'transferId');
    }
    final sftp = await _getRealSftp();
    final temporary = path_util.posix.join(path_util.posix.dirname(remotePath),
      '.valhalla-upload-$transferId.part');
    try {
      final attrs = await sftp.stat(temporary, followLink: false);
      if (attrs.mode?.type != SftpFileType.regularFile) {
        throw const SFTPException('SFTP_TRANSFER_PARTIAL_INVALID');
      }
      await sftp.remove(temporary);
    } on SftpStatusError catch (error) {
      if (error.code != SftpStatusCode.noSuchFile) rethrow;
    }
  });

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
  final void Function()? _onClose;
  final Future<void> Function()? _validateComplete;

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
    void Function()? onClose,
    int initialOffset = 0,
    Future<void> Function()? validateComplete,
  }) : _remote = remote,
       _local = local,
       _onClose = onClose,
       _transferred = initialOffset,
       _validateComplete = validateComplete,
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
      var remaining = totalBytes > 0 ? totalBytes - _transferred : -1;
      while (remaining != 0) {
        await _waitIfPaused();
        if (_aborted) return;

        final want = remaining < 0
            ? _chunkSize
            : (remaining < _chunkSize ? remaining : _chunkSize);
        final chunk = await _remote
            .readBytes(offset: _transferred, length: want)
            .timeout(const Duration(seconds: 30));
        if (chunk.isEmpty) {
          if (remaining > 0) {
            throw const SFTPException('SFTP_DOWNLOAD_INCOMPLETE');
          }
          break;
        }

        await _local.writeFrom(chunk);
        _transferred += chunk.length;
        _onProgress?.call(_transferred);
        if (remaining > 0) remaining -= chunk.length;
      }
      await _local.flush();
      await _validateComplete?.call();
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
      await _remote.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _onClose?.call();
  }
}

/// 上传句柄：把 dartssh2 的 [SftpFileWriter] 包一层。
///
/// 上传方向不需要手写循环——`SftpFileWriter` 本身就带
/// `pause()` / `resume()` / `abort()`，只是以前 `SftpClientService`
/// 只 `await writer.done` 把句柄丢掉了。这里把它接出来。
class _UploadHandle implements SftpTransferHandle, SftpCommittingTransfer {
  final SftpFile _remote;
  final SftpFileWriter _writer;
  final int _initialOffset;
  final Future<void> Function()? _commit;

  @override
  final int totalBytes;

  final _done = Completer<void>();
  var _aborted = false;
  var _closed = false;
  var _committing = false;

  @override
  bool get isCommitting => _committing && !_done.isCompleted;

  _UploadHandle({
    required SftpFile remote,
    required Stream<Uint8List> source,
    required this.totalBytes,
    void Function(int bytesWritten)? onProgress,
    int initialOffset = 0,
    Future<void> Function()? commit,
  }) : _remote = remote,
       _initialOffset = initialOffset,
       _commit = commit,
       _writer = remote.write(
         source,
         offset: initialOffset,
         chunkSize: 64 * 1024,
         onProgress: onProgress == null ? null : (bytes) => onProgress(bytes + initialOffset),
       ) {
    unawaited(_finish());
  }

  @override
  int get transferredBytes => _writer.progress + _initialOffset;

  @override
  Future<void> get done => _done.future;

  Future<void> _finish() async {
    try {
      await _writer.done;
      // writer.abort() 会让 done 正常完成，所以要靠自己的标志区分
      // 「传完了」和「被中止了」——否则取消会被上层当成成功。
      if (_aborted) return;
      await _close();
      if (_aborted) return;
      _committing = true;
      await _commit?.call();
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
    if (isCommitting) {
      await done;
      return;
    }
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
