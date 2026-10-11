import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path_util;
import 'package:uuid/uuid.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../../infrastructure/sftp/remote_file_actions.dart';
import '../utils/file_preview.dart';
import '../errors/app_exceptions.dart';
import '../services/download_platform_service.dart';
import '../services/app_diagnostics.dart';

import 'server_provider.dart';
import 'infrastructure_providers.dart';
import 'storage_providers.dart';
import '../../data/models/server_profile.dart';

final downloadPlatformServiceProvider = Provider<DownloadPlatformService>(
  (ref) => DownloadPlatformService(),
);

final remoteFileActionsProvider = Provider<RemoteFileActions>(
  (ref) => RemoteFileActions(ref.watch(sshCommandExecutorProvider)),
);

/// 传输成功后的通知回调。
///
/// 默认 null（不发通知）：真实的实现需要 Android 侧的方法通道，
/// 在测试环境里调用它会挂起或抛异常。生产环境在 `main.dart` 覆盖它，
/// 这样「发通知」这个副作用既不污染 provider 逻辑，又能在测试里断言。
///
/// 参数是刚完成的任务，实现方据此拼通知文案。
final transferNotificationCallbackProvider =
    Provider<void Function(SftpTransfer transfer)?>((ref) => null);

/// 当前连接对应的远端文件操作实现。
///
/// 单独抽成 provider 而不是在 `SftpNotifier.build()` 里直接 new，是为了让
/// 传输/预览的失败分支可以在测试里用替身稳定复现（真实服务器很难造出
/// 「权限不足」「磁盘写满」这些情况）。
final sftpOperationsProvider = Provider<SftpOperations>((ref) {
  ref.watch(activeServerProvider.select((server) => server?.connectionKey));
  final activeServer = ref.read(activeServerProvider);
  final connected = ref.watch(
    serverConnectionProvider.select((s) => s.isConnected),
  );
  final sshManager = ref.watch(sshClientManagerProvider);
  final sshClient = (activeServer != null && connected)
      ? sshManager.getClient(activeServer.id)
      : null;
  final service = SftpClientService(sshClient);
  ref.onDispose(service.dispose);
  return service;
});

/// 传输方向。
enum SftpTransferKind { upload, download }

/// 文件列表的排序字段。
enum SftpSortKey { name, size, date }

enum SftpViewMode { list, grid }

/// 把存储里的字符串还原成 [SftpSortKey]。
///
/// 无法识别的值回落到 [fallback]（默认按名称），这样降级安装
/// （新版本写、旧版本读）不会崩在解析上。
SftpSortKey sftpSortKeyFromStorage(
  String raw, {
  SftpSortKey fallback = SftpSortKey.name,
}) {
  for (final key in SftpSortKey.values) {
    if (key.name == raw) return key;
  }
  return fallback;
}

/// 一次进行中的上传/下载。
///
/// 传输任务的状态。
///
/// 只区分「还在队列里等」「正在跑」「用户暂停」「已结束」这几类；
/// 结束后是成功还是失败由 [SftpTransfer.status] 配合 [SftpTransfer.errorMessage]
/// 判断，不需要在枚举里再分一层。
enum SftpTransferStatus { queued, running, paused, completed, failed, canceled }

extension SftpTransferStatusX on SftpTransferStatus {
  /// 是否已经结束（不会再自行变化）。删除与「清除已完成」据此判断。
  bool get isTerminal =>
      this == SftpTransferStatus.completed ||
      this == SftpTransferStatus.failed ||
      this == SftpTransferStatus.canceled;
}

/// 一次上传/下载任务。
///
/// 进度回调来自 dartssh2 的 `onProgress`，频率较高，因此这里只保留必要字段，
/// 由 UI 自行决定如何展示（进度条、百分比、字节数）。
class SftpTransfer {
  /// 任务 id。队列里同时可能存在多个同名文件，所以不能用路径当标识——
  /// 暂停/取消/删除都必须能精确指向某一个任务。
  final String id;

  final SftpTransferKind kind;

  /// 远端路径（上传是目标、下载是来源）。
  final String remotePath;

  /// 本地路径。
  final String localPath;

  /// 已传输字节数。
  final int transferredBytes;

  /// 总字节数；未知时为 0。
  final int totalBytes;

  final SftpTransferStatus status;

  /// 失败时的 reason code（由 UI 映射 ARB 文案）。其余状态为 null。
  final String? errorMessage;
  final Map<String, dynamic>? sourceIdentity;
  final bool managedDownload;
  final String? localSha256;

  const SftpTransfer({
    required this.id,
    required this.kind,
    required this.remotePath,
    required this.localPath,
    this.transferredBytes = 0,
    this.totalBytes = 0,
    this.status = SftpTransferStatus.queued,
    this.errorMessage,
    this.sourceIdentity,
    this.managedDownload = false,
    this.localSha256,
  });

  /// 进度 0.0~1.0；总大小未知时返回 null，避免 UI 显示假进度。
  double? get progress {
    if (totalBytes <= 0) return null;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// 展示用的文件名：取路径最后一段。
  String get fileName {
    final path = kind == SftpTransferKind.download ? remotePath : localPath;
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// 复制并覆盖字段。
  ///
  /// [errorMessage] 可空，所以沿用 `clearXxx` 的显式清空约定，
  /// 否则从「失败」重试到「排队」时旧错误会残留。
  SftpTransfer copyWith({
    int? transferredBytes,
    int? totalBytes,
    SftpTransferStatus? status,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? sourceIdentity,
    String? localSha256,
  }) {
    return SftpTransfer(
      id: id,
      kind: kind,
      remotePath: remotePath,
      localPath: localPath,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sourceIdentity: sourceIdentity ?? this.sourceIdentity,
      managedDownload: managedDownload,
      localSha256: localSha256 ?? this.localSha256,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name,
    'remotePath': remotePath, 'localPath': localPath, 'transferredBytes': transferredBytes,
    'totalBytes': totalBytes, 'status': status.name, 'errorMessage': errorMessage,
    'sourceIdentity': sourceIdentity, 'managedDownload': managedDownload,
    'localSha256': localSha256};

  factory SftpTransfer.fromJson(Map<String, dynamic> json) {
    final status = SftpTransferStatus.values.byName(json['status'] as String);
    return SftpTransfer(id: json['id'] as String,
      kind: SftpTransferKind.values.byName(json['kind'] as String),
      remotePath: json['remotePath'] as String, localPath: json['localPath'] as String,
      transferredBytes: json['transferredBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      status: status == SftpTransferStatus.running || status == SftpTransferStatus.queued
        ? SftpTransferStatus.paused : status,
      errorMessage: json['errorMessage'] as String?,
      sourceIdentity: json['sourceIdentity'] as Map<String, dynamic>?,
      managedDownload: json['managedDownload'] as bool? ?? false,
      localSha256: json['localSha256'] as String?);
  }
}

class SftpState {
  final bool downloadNotificationsUnavailable;
  final String currentPath;
  final List<SftpFileItem> files;
  final bool isLoading;
  final String searchQuery;
  final String? errorMessage;
  final String? editingFilePath;
  final String? editingFileContent;

  /// 传输队列。列表顺序就是展示顺序，也是排队顺序。
  ///
  /// 之前这里是单个可空 `transfer`，但用户要的是「传输列表」——
  /// 能同时看到多个任务、能对每一个单独暂停/取消/删除。实际执行仍然是
  /// **串行**的（同一时刻只有一个 running），并发只发生在「排队」这一层。
  final List<SftpTransfer> transfers;

  /// 文件列表排序字段。
  final SftpSortKey sortKey;

  /// 文件列表是否升序。
  final bool sortAscending;
  final bool showHiddenFiles;
  /// Null retains the existing width-adaptive layout until explicitly selected.
  final SftpViewMode? viewMode;
  final DateTime? cachedAt;

  const SftpState({
    this.downloadNotificationsUnavailable = false,
    this.currentPath = '/var/www/my-project',
    this.files = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.errorMessage,
    this.editingFilePath,
    this.editingFileContent,
    this.transfers = const [],
    this.sortKey = SftpSortKey.name,
    this.sortAscending = true,
    this.showHiddenFiles = false,
    this.viewMode,
    this.cachedAt,
  });

  /// 是否已在根目录。作为「返回键是否退出 app」的唯一判据，避免多处内联
  /// 比较 `currentPath == '/'` 而出现定义漂移。
  bool get isAtRoot => currentPath == '/' || currentPath.isEmpty;

  List<String> get pathSegments {
    if (isAtRoot) return [];
    return currentPath.split('/').where((s) => s.isNotEmpty).toList();
  }

  /// 正在执行的那个传输；没有则为 null。
  ///
  /// 保留这个 getter 让既有 UI（「传输中禁用上传/下载按钮」）不必改成
  /// 遍历列表，语义与改造前的 `transfer` 一致。**新代码请用
  /// `activeTransfer` / `transfers`**，这个名字是为了兼容旧调用点保留的。
  SftpTransfer? get activeTransfer {
    for (final t in transfers) {
      if (t.status == SftpTransferStatus.running) return t;
    }
    return null;
  }

  /// 兼容旧调用点：等价于 [activeTransfer]。
  ///
  /// 改造前这里是单个可空字段；现在队列里可能有多个任务，
  /// 这个 getter 让「只看正在跑的那一个」的旧代码继续工作。
  @Deprecated('改用 activeTransfer（语义相同）或 transfers（看全部）')
  SftpTransfer? get transfer => activeTransfer;

  /// 是否有传输正在进行（含暂停）。
  ///
  /// 暂停中的任务也算「占用」：它握着远端句柄与本地文件句柄，
  /// 这时再开新传输会和它争同一个 SFTP 通道。
  bool get hasActiveTransfer => activeTransfer != null;

  /// 队列里还没有结束的任务数（含 running 与 paused）。
  int get pendingTransferCount =>
      transfers.where((t) => !t.status.isTerminal).length;

  /// 是否还有已结束、可以「清除」的任务。
  bool get hasFinishedTransfers => transfers.any((t) => t.status.isTerminal);

  /// 按 id 找任务；找不到返回 null。
  ///
  /// 队列是串行的，但 UI 的按钮回调可能在任务已经结束并被移除后
  /// 才触发（例如用户连点），所以调用方必须处理 null 而不是假设存在。
  SftpTransfer? transferById(String id) {
    for (final t in transfers) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 经过「搜索过滤 + 排序」之后真正要渲染的列表。
  ///
  /// 排序在这里做而不是在 `listFiles` 里做：SFTP 的 readdir 顺序由服务器决定，
  /// 保留原始顺序才能让「切换排序」是纯本地操作，不必重新拉一次目录。
  ///
  /// 目录恒排在文件前面，且不受升降序影响——反转整个列表会让人以为
  /// 目录跑到文件后面是 bug，而「目录优先」是文件管理器的通行约定。
  List<SftpFileItem> get filteredFiles {
    final q = searchQuery.trim().toLowerCase();
    final visible = files.where(
      (file) =>
          file.name != '.' &&
          !(isAtRoot && file.name == '..') &&
          (showHiddenFiles || file.name == '..' || !file.name.startsWith('.')),
    );
    final result = q.isEmpty
        ? visible.toList()
        : visible.where((f) => f.name.toLowerCase().contains(q)).toList();

    int compare(SftpFileItem a, SftpFileItem b) {
      // 目录优先，且这一层永远不参与反转。
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      final base = switch (sortKey) {
        SftpSortKey.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        SftpSortKey.size => a.sizeBytes.compareTo(b.sizeBytes),
        SftpSortKey.date => a.modifiedEpoch.compareTo(b.modifiedEpoch),
      };
      // 同值时按名字兜底：否则排序不稳定，两次刷新顺序会跳，
      // 列表看起来像在随机抖动。
      if (base == 0 && sortKey != SftpSortKey.name) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return sortAscending ? base : -base;
    }

    result.sort(compare);
    return result;
  }

  /// 复制并覆盖字段。
  ///
  /// 可空字段（[errorMessage]、[editingFilePath]、[editingFileContent]）
  /// 不能用「传 null 即清空」的语义，否则每次 copyWith 都会把没提到
  /// 的字段一起抹掉；要清空必须显式传对应的 `clearXxx: true`。
  SftpState copyWith({
    bool? downloadNotificationsUnavailable,
    String? currentPath,
    List<SftpFileItem>? files,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? editingFilePath,
    String? editingFileContent,
    bool clearEditor = false,
    List<SftpTransfer>? transfers,
    SftpSortKey? sortKey,
    bool? sortAscending,
    bool? showHiddenFiles,
    SftpViewMode? viewMode,
    DateTime? cachedAt,
    bool clearCachedAt = false,
  }) {
    return SftpState(
      downloadNotificationsUnavailable:
          downloadNotificationsUnavailable ??
          this.downloadNotificationsUnavailable,
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      editingFilePath: clearEditor
          ? null
          : (editingFilePath ?? this.editingFilePath),
      editingFileContent: clearEditor
          ? null
          : (editingFileContent ?? this.editingFileContent),
      transfers: transfers ?? this.transfers,
      sortKey: sortKey ?? this.sortKey,
      sortAscending: sortAscending ?? this.sortAscending,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      viewMode: viewMode ?? this.viewMode,
      cachedAt: clearCachedAt ? null : cachedAt ?? this.cachedAt,
    );
  }

  /// 替换队列里的某一个任务；id 不存在时原样返回。
  ///
  /// 进度回调与状态流转都走这里，避免每处调用自己 `map` 一遍
  /// 而漏掉「找不到就忽略」这个分支。
  SftpState withTransfer(SftpTransfer updated) {
    final index = transfers.indexWhere((t) => t.id == updated.id);
    if (index < 0) return this;
    final next = List<SftpTransfer>.of(transfers);
    next[index] = updated;
    return copyWith(transfers: next);
  }

  /// 移除某个任务；id 不存在时原样返回。
  SftpState withoutTransfer(String id) {
    final next = transfers.where((t) => t.id != id).toList();
    if (next.length == transfers.length) return this;
    return copyWith(transfers: next);
  }

  /// 追加一个任务。
  SftpState withAppendedTransfer(SftpTransfer transfer) =>
      copyWith(transfers: [...transfers, transfer]);
}

class SftpNotifier extends Notifier<SftpState> {
  /// 上传失败的稳定 reason code，由 UI 映射 ARB 文案。
  static const uploadFailedCode = 'SFTP_UPLOAD_FAILED';

  /// 下载失败的稳定 reason code，由 UI 映射 ARB 文案。
  static const downloadFailedCode = 'SFTP_DOWNLOAD_FAILED';

  /// 该类型不支持预览的稳定 reason code，由 UI 映射 ARB 文案。
  static const previewUnsupportedCode = 'SFTP_PREVIEW_UNSUPPORTED';

  /// 读取远端文件内容失败的稳定 reason code，由 UI 映射 ARB 文案。
  static const readFailedCode = 'SFTP_READ_FAILED';
  static const previewTooLargeCode = SftpClientService.previewTooLargeCode;
  static const hiddenPreferenceSaveFailedCode =
      'SFTP_HIDDEN_PREFERENCE_SAVE_FAILED';

  int _sourceEpoch = 0;
  int _loadEpoch = 0;
  int _editorEpoch = 0;
  ServerProfile? _boundServer;

  bool _currentSource(int epoch) => ref.mounted && epoch == _sourceEpoch;

  late SftpOperations _service;
  SftpTextSnapshot? _editorSnapshot;
  Timer? _editorDraftTimer;
  Future<void> Function()? _pendingEditorDraft;
  Future<void> _editorDraftWrites = Future<void>.value();
  String? _editorDraftKey;
  bool _editorDraftConflict = false;
  int get editorToken => _editorEpoch;

  String _fileDraftKey(ServerProfile server, String path) => sha256.convert(
    utf8.encode('${server.connectionKey}\u0000$path')).toString();

  /// 正在执行的传输句柄，按任务 id 索引。
  ///
  /// 只有 running 的任务会在这里；暂停时句柄**保留**（这正是「继续」
  /// 能原地恢复而不必重开远端连接的原因），任务结束时移除。
  ///
  /// 断开连接会重建 notifier，旧的句柄会随旧实例一起被丢弃。
  /// 这没问题：断开时底层的 SFTP 通道已经没了，句柄本就不可用。
  final Map<String, SftpTransferHandle> _handles = {};
  final Set<String> _finalizingTransfers = {};
  final Map<String, int> _downloadRetries = {};
  final Set<String> _connectionPaused = {};
  Future<void> _transferWrites = Future<void>.value();
  DateTime _lastTransferWrite = DateTime.fromMillisecondsSinceEpoch(0);

  void _persistTransfers({bool progress = false}) {
    final server = _boundServer;
    if (server == null) return;
    final now = DateTime.now();
    if (progress && now.difference(_lastTransferWrite).inMilliseconds < 1000) return;
    _lastTransferWrite = now;
    final records = state.transfers.map((transfer) => transfer.toJson()).toList();
    final storage = ref.read(localStorageServiceProvider);
    _transferWrites = _transferWrites.then((_) => storage.saveTransferRecords(server, records))
      .catchError((Object error, StackTrace stack) {
        unawaited(AppDiagnostics.instance.record('sftp.transfer.records', error, stack));
        if (ref.mounted && (_boundServer?.hasSameConnectionSettings(server) ?? false)) {
          state = state.copyWith(errorMessage: 'SFTP_TRANSFER_RECORD_SAVE_FAILED');
        }
      });
  }

  @override
  SftpState build() {
    final sourceEpoch = ++_sourceEpoch;
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    final activeServer = ref.read(activeServerProvider);
    final sameTarget = activeServer != null &&
        (_boundServer?.hasSameConnectionSettings(activeServer) ?? false);
    var previous = sameTarget ? stateOrNull : null;
    if (previous == null && activeServer != null) {
      try {
        final cached = ref.read(localStorageServiceProvider).getPageCache(activeServer, 'files');
        final data = cached?['payload'] as Map<String, dynamic>?;
        if (data != null) {
          previous = SftpState(currentPath: data['path'] as String,
            cachedAt: DateTime.tryParse(cached?['savedAt'] as String? ?? ''),
            files: (data['files'] as List).cast<Map<String, dynamic>>()
              .map(SftpFileItem.fromJson).toList());
        }
      } catch (error, stack) {
        unawaited(AppDiagnostics.instance.record('sftp.cache', error, stack));
      }
    }
    _boundServer = activeServer;
    if (!sameTarget) {
      _editorEpoch++;
      _editorSnapshot = null;
      _editorDraftKey = null;
      _editorDraftConflict = false;
      _managedDownloads.clear();
      _autoOpenDownloads.clear();
      _downloadRetries.clear();
      _connectionPaused.clear();
      if (activeServer != null) {
        try {
          final records = ref.read(localStorageServiceProvider).getTransferRecords(activeServer)
            .map(SftpTransfer.fromJson).toList();
          if (records.isNotEmpty) {
            previous = (previous ?? const SftpState(currentPath: '/')).copyWith(transfers: records);
          }
          _managedDownloads.addAll(records.where((task) => task.managedDownload).map((task) => task.id));
        } catch (error, stack) {
          unawaited(AppDiagnostics.instance.record('sftp.transfer.restore', error, stack));
        }
      }
    }
    final connected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final sshManager = ref.watch(sshClientManagerProvider);
    final sshClient = (activeServer != null && connected)
        ? sshManager.getClient(activeServer.id)
        : null;

    _service = ref.watch(sftpOperationsProvider);

    // 断开/切换服务器会让本 notifier 重建，必须连同句柄一起清掉，
    // 否则旧传输会继续跑在一个已经没人引用的通道上。
    // 用 ref.onDispose 而不是重写 dispose()：Notifier 没有可重写的 dispose。
    ref.onDispose(() {
      _sourceEpoch++;
      _editorDraftTimer?.cancel();
      final pending = _pendingEditorDraft;
      _pendingEditorDraft = null;
      if (pending != null) unawaited(pending());
      for (final handle in _handles.values) {
        unawaited(handle.abort().catchError((Object error, StackTrace stack) {
          unawaited(AppDiagnostics.instance.record('sftp.transfer.dispose', error, stack));
        }));
      }
      _handles.clear();
    });

    // 排序偏好要持久化：`build()` 会因为切换服务器、断线重连而重跑，
    // 不在这里读回来的话，每次重连排序都会被打回默认值。
    final storage = ref.watch(localStorageServiceProvider);
    final sortKey = sftpSortKeyFromStorage(storage.getFileSortKey());
    final sortAscending = storage.getFileSortAscending();
    final showHiddenFiles = storage.getFileShowHidden();
    final rawViewMode = storage.getFileViewMode();
    final viewMode = rawViewMode == null ? null :
        SftpViewMode.values.firstWhere((mode) => mode.name == rawViewMode);
    if (previous != null) {
      previous = previous.copyWith(viewMode: viewMode, sortKey: sortKey,
        sortAscending: sortAscending, showHiddenFiles: showHiddenFiles);
    }

    if (sshClient != null) {
      Future.microtask(() {
        if (_currentSource(sourceEpoch)) {
          _pumpQueue();
          unawaited(
            loadDirectory(
              previous?.currentPath ?? '/',
              quiet: previous != null,
            ),
          );
        }
      });
      if (previous != null) {
        return previous.copyWith(
          isLoading: false,
          clearError: true,
          transfers: previous.transfers.map((task) {
            if (!_connectionPaused.remove(task.id) ||
                task.status != SftpTransferStatus.paused) {
              return task;
            }
            _downloadRetries[task.id] = (_downloadRetries[task.id] ?? 0) + 1;
            return task.copyWith(
              status: SftpTransferStatus.queued,
              transferredBytes: 0,
              clearError: true,
            );
          }).toList(),
        );
      }
      return SftpState(
        isLoading: true,
        currentPath: '/',
        sortKey: sortKey,
        sortAscending: sortAscending,
        showHiddenFiles: showHiddenFiles,
        viewMode: viewMode,
      );
    } else {
      if (previous != null) {
        return previous.copyWith(
          isLoading: false,
          clearError: true,
          transfers: previous.transfers.map((task) {
            if (task.status != SftpTransferStatus.running &&
                task.status != SftpTransferStatus.queued) {
              return task;
            }
            if (task.kind == SftpTransferKind.download &&
                (_downloadRetries[task.id] ?? 0) < 1) {
              _connectionPaused.add(task.id);
              return task.copyWith(
                status: SftpTransferStatus.paused,
                errorMessage: 'SSH_DISCONNECTED',
              );
            }
            return task.copyWith(
              status: SftpTransferStatus.failed,
              errorMessage: 'SSH_DISCONNECTED',
            );
          }).toList(),
        );
      }
      return SftpState(
        isLoading: false,
        currentPath: '/',
        sortKey: sortKey,
        sortAscending: sortAscending,
        showHiddenFiles: showHiddenFiles,
        viewMode: viewMode,
      );
    }
  }

  Future<bool> loadDirectory(
    String path, {
    bool clearSearch = false,
    bool quiet = false,
  }) async {
    final sourceEpoch = _sourceEpoch;
    final loadEpoch = ++_loadEpoch;
    final normalized = _normalizeRemotePath(path);
    state = state.copyWith(isLoading: !quiet, clearError: true);
    try {
      final items = await _service.listFiles(normalized);
      if (!_currentSource(sourceEpoch) || loadEpoch != _loadEpoch) return false;
      state = state.copyWith(
        currentPath: normalized,
        files: items,
        clearCachedAt: true,
        isLoading: false,
        searchQuery: clearSearch ? '' : state.searchQuery,
      );
      final server = _boundServer;
      if (server != null) {
        unawaited(ref.read(localStorageServiceProvider).savePageCache(server, 'files', {
          'path': normalized, 'files': items.take(200).map((f) => f.toJson()).toList(),
        }).catchError((Object error, StackTrace stack) {
          unawaited(AppDiagnostics.instance.record('sftp.cache', error, stack));
        }));
      }
      return true;
    } catch (e) {
      if (!_currentSource(sourceEpoch) || loadEpoch != _loadEpoch) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: ref.read(serverConnectionProvider).isConnected
            ? 'Failed to load directory: $e'
            : null,
      );
      return false;
    }
  }

  Future<void> navigateTo(String path) async {
    await loadDirectory(path, clearSearch: true);
  }

  Future<void> navigateUp() async {
    if (state.isAtRoot) return;
    final lastSlash = state.currentPath.lastIndexOf('/');
    final parent = lastSlash <= 0
        ? '/'
        : state.currentPath.substring(0, lastSlash);
    await loadDirectory(parent, clearSearch: true);
  }

  String _normalizeRemotePath(String value) {
    final absolute = value.startsWith('/')
        ? value
        : path_util.posix.join(state.currentPath, value);
    final normalized = path_util.posix.normalize(absolute);
    return normalized == '.' ? '/' : normalized;
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  Future<void> setViewMode(SftpViewMode mode) async {
    try {
      await ref.read(localStorageServiceProvider).setFileViewMode(mode.name);
      if (ref.mounted) state = state.copyWith(viewMode: mode, clearError: true);
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('sftp.view-preference', error, stack));
      if (ref.mounted) {
        state = state.copyWith(errorMessage: 'SFTP_VIEW_PREFERENCE_SAVE_FAILED');
      }
    }
  }

  Future<void> setShowHiddenFiles(bool value) async {
    try {
      await ref.read(localStorageServiceProvider).setFileShowHidden(value);
      if (ref.mounted) {
        state = state.copyWith(showHiddenFiles: value, clearError: true);
      }
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.instance.record('sftp.hidden-preference', error, stack),
      );
      if (ref.mounted) {
        state = state.copyWith(errorMessage: hiddenPreferenceSaveFailedCode);
      }
    }
  }

  /// 切换排序字段。
  ///
  /// 允许外部传 null 之外的任意值；重复点同一个字段时由 UI 决定是否
  /// 另外调用 [toggleSortDirection]。
  Future<void> setSortKey(SftpSortKey key) async {
    state = state.copyWith(sortKey: key);
    await ref.read(localStorageServiceProvider).setFileSortKey(key.name);
  }

  /// 切换升降序。
  Future<void> toggleSortDirection() async {
    final next = !state.sortAscending;
    state = state.copyWith(sortAscending: next);
    await ref.read(localStorageServiceProvider).setFileSortAscending(next);
  }

  /// 一次性设置字段与方向，供 UI 的「点同一字段就反向」交互使用。
  Future<void> setSort({
    required SftpSortKey key,
    required bool ascending,
  }) async {
    state = state.copyWith(sortKey: key, sortAscending: ascending);
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFileSortKey(key.name);
    await storage.setFileSortAscending(ascending);
  }

  Future<void> refresh() async {
    await loadDirectory(state.currentPath);
  }

  /// 清除当前错误提示。
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 该条目能否在当前版本里预览。
  ///
  /// 目录一律不可预览；其余按扩展名白名单判断（见 [FilePreview]）。图片不在
  /// 本轮范围内，实现层不预留分支——「不支持」是明确结论而不是待办。
  bool canPreview(SftpFileItem item) {
    if (item.isDirectory || item.linkTargetErrorCode != null) return false;
    return FilePreview.isTextPreviewable(item.name);
  }

  /// 把本地文件加入上传队列，目标是当前目录。
  ///
  /// [remoteName] 默认取本地文件名。返回的 Future 在**入队后立刻完成**，
  /// 不代表传输结束——任务会在队列里排队，由 [_pumpQueue] 串行执行。
  /// 之所以仍返回 Future 而不是 void：既有的 UI 调用点是 `await` 它的，
  /// 保留签名能让那些调用点不用改（而且它们 await 到的东西本就不该是
  /// 「传输完成」）。
  Future<void> uploadFrom(String localPath, {String? remoteName}) async {
    final name = remoteName ?? _basename(localPath);
    _validateTransferName(name);
    _requireTransferCapacity();
    final remotePath = state.currentPath == '/'
        ? '/$name'
        : '${state.currentPath}/$name';

    state = state
        .withAppendedTransfer(
          SftpTransfer(
            id: _newTransferId(),
            kind: SftpTransferKind.upload,
            remotePath: remotePath,
            localPath: localPath,
          ),
        )
        .copyWith(clearError: true);
    _persistTransfers();
    _pumpQueue();
  }

  /// 把远端文件加入下载队列。
  ///
  /// 与 [uploadFrom] 相同：Future 完成只表示已入队。
  Future<void> downloadTo(SftpFileItem item, String localPath) async {
    _requireTransferCapacity();
    if (item.linkTargetErrorCode != null) {
      state = state.copyWith(errorMessage: item.linkTargetErrorCode);
      return;
    }
    state = state
        .withAppendedTransfer(
          SftpTransfer(
            id: _newTransferId(),
            kind: SftpTransferKind.download,
            remotePath: item.path,
            localPath: localPath,
            totalBytes: item.sizeBytes,
          ),
        )
        .copyWith(clearError: true);
    _persistTransfers();
    _pumpQueue();
  }

  Future<String?> downloadFile(SftpFileItem item) =>
      _downloadFile(item, openWhenComplete: false);

  Future<String?> downloadAndOpen(SftpFileItem item) =>
      _downloadFile(item, openWhenComplete: true);

  Future<String?> _downloadFile(
    SftpFileItem item, {
    required bool openWhenComplete,
  }) async {
    final sourceEpoch = _sourceEpoch;
    if (item.linkTargetErrorCode != null) {
      state = state.copyWith(errorMessage: item.linkTargetErrorCode);
      return null;
    }
    try {
      _requireTransferCapacity();
      final path = await ref
          .read(downloadPlatformServiceProvider)
          .reservePath(item.name);
      if (!_currentSource(sourceEpoch)) return null;
      final task = SftpTransfer(
        id: _newTransferId(),
        kind: SftpTransferKind.download,
        remotePath: item.path,
        localPath: path,
        totalBytes: item.sizeBytes,
        managedDownload: true,
      );
      _managedDownloads.add(task.id);
      if (openWhenComplete) _autoOpenDownloads.add(task.id);
      state = state.withAppendedTransfer(task).copyWith(clearError: true);
      _persistTransfers();
      _notifyDownload(task);
      _pumpQueue();
      return task.id;
    } catch (error, stack) {
      if (!_currentSource(sourceEpoch)) return null;
      unawaited(AppDiagnostics.instance.record('sftp.reserve', error, stack));
      state = state.copyWith(errorMessage: downloadErrorCode(error));
      return null;
    }
  }

  final Set<String> _managedDownloads = {};
  final Set<String> _autoOpenDownloads = {};
  final Map<String, DateTime> _lastDownloadNotification = {};
  void _notifyDownload(SftpTransfer task, {bool force = false}) {
    if (!_managedDownloads.contains(task.id)) return;
    final now = DateTime.now();
    final terminal =
        task.status == SftpTransferStatus.completed ||
        task.status == SftpTransferStatus.failed ||
        task.status == SftpTransferStatus.canceled;
    if (!force &&
        !terminal &&
        now.difference(_lastDownloadNotification[task.id] ?? DateTime(1970)) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastDownloadNotification[task.id] = now;
    unawaited(
      ref
          .read(downloadPlatformServiceProvider)
          .report({
            'id': task.id,
            'name': task.fileName,
            'path': task.localPath,
            'bytes': task.transferredBytes,
            'total': task.totalBytes,
            'status': task.status.name,
          })
          .then((available) {
            if (ref.mounted &&
                state.downloadNotificationsUnavailable == available) {
              state = state.copyWith(
                downloadNotificationsUnavailable: !available,
              );
            }
          }),
    );
  }

  Future<void> openCompletedTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null ||
        task.kind != SftpTransferKind.download ||
        task.status != SftpTransferStatus.completed) {
      return;
    }
    final epoch = _sourceEpoch;
    final platform = ref.read(downloadPlatformServiceProvider);
    try {
      await _verifyCompletedDownload(task);
      if (!_currentSource(epoch)) return;
      await platform.openFile(task.localPath);
    } catch (_) {
      if (_currentSource(epoch)) {
        state = state.copyWith(errorMessage: 'DOWNLOAD_OPEN_FAILED');
      }
    }
  }

  Future<void> revealCompletedTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null ||
        task.kind != SftpTransferKind.download ||
        task.status != SftpTransferStatus.completed) {
      return;
    }
    final epoch = _sourceEpoch;
    final platform = ref.read(downloadPlatformServiceProvider);
    try {
      await _verifyCompletedDownload(task);
      if (_currentSource(epoch)) await platform.revealFile(task.localPath);
    } catch (_) {
      if (_currentSource(epoch)) {
        state = state.copyWith(errorMessage: 'DOWNLOAD_OPEN_FAILED');
      }
    }
  }

  Future<void> _verifyCompletedDownload(SftpTransfer task) async {
    final file = File(task.localPath);
    if (task.localSha256 == null || !await file.exists() ||
        await file.length() != task.transferredBytes ||
        (await sha256.bind(file.openRead()).first).toString() != task.localSha256) {
      throw const FileSystemException('SFTP_TRANSFER_PARTIAL_INVALID');
    }
  }

  /// 队列调度：没有正在跑的任务时，取队首的 queued 任务开始执行。
  ///
  /// 这是**唯一**能把任务从 queued 推进到 running 的地方。任何时候
  /// 队列状态发生变化（入队、任务结束、暂停后恢复、删除）都要调它一次，
  /// 否则队列会卡住——例如暂停一个任务后它不再是 running，
  /// 但如果不重新调度，后面的任务永远不会开始。
  ///
  /// 正在跑的任务还没结束就再次调用是安全的：直接返回，不会并发执行。
  void _pumpQueue() {
    if (!ref.read(serverConnectionProvider).isConnected) return;
    if (!ref.mounted) return;
    if (state.activeTransfer != null) return;

    final next = state.transfers
        .where((t) => t.status == SftpTransferStatus.queued)
        .firstOrNull;
    if (next == null) return;

    state = state.withTransfer(
      next.copyWith(status: SftpTransferStatus.running, clearError: true),
    );
    _persistTransfers();
    // 不 await：调用方（UI 回调、状态变更）不该等整个传输跑完。
    unawaited(_runTransfer(next.id));
  }

  Future<void> _runTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null) return;

    /// provider 已被销毁（断开连接、切换服务器、容器 dispose）时，
    /// 后续任何一次 `state = ...` 都会抛「Ref ... after it has been
    /// disposed」。
    ///
    /// 这不是罕见路径：`build()` 里的 `ref.onDispose` 会 abort 所有句柄，
    /// 而 abort 让 `handle.done` 抛 [SftpTransferAborted] 或正常完成，
    /// 两条路都会把控制流带回下面的 await 之后——那个异常会逃到
    /// 无人 await 的 zone 里，把测试和日志都弄脏。
    bool disposed = false;
    ref.onDispose(() => disposed = true);

    SftpTransferHandle? handle;
    try {
      final service = _service;
      if (service is SftpResumableOperations) {
        void onSource(Map<String, dynamic> source) {
          if (disposed || !ref.mounted) return;
          final current = state.transferById(id);
          if (current == null) return;
          state = state.withTransfer(current.copyWith(sourceIdentity: source));
          _persistTransfers();
        }
        handle = task.kind == SftpTransferKind.download
          ? await (service as SftpResumableOperations).startResumableDownload(
            task.remotePath, _managedDownloads.contains(id) ? '${task.localPath}.part' : task.localPath,
            expectedSource: task.sourceIdentity, onSource: onSource,
            onProgress: (bytes) => _reportProgress(id, bytes))
          : await (service as SftpResumableOperations).startResumableUpload(
            task.localPath, task.remotePath, transferId: id,
            expectedSource: task.sourceIdentity, onSource: onSource,
            onProgress: (bytes) => _reportProgress(id, bytes));
      } else {
      switch (task.kind) {
        case SftpTransferKind.download:
          handle = await _service.startDownload(
            task.remotePath,
            _managedDownloads.contains(id)
                ? '${task.localPath}.part'
                : task.localPath,
            onProgress: (read) => _reportProgress(id, read),
          );
        case SftpTransferKind.upload:
          handle = await _service.startUpload(
            task.localPath,
            task.remotePath,
            onProgress: (written) => _reportProgress(id, written),
          );
      }
      }
      if (disposed) {
        // 建连期间就被销毁了：通道已经没了，只能尽力关掉刚拿到的句柄。
        await handle.abort();
        return;
      }

      // 句柄注册到 _handles，让 pause/resume/cancel 能拿到它。
      // 任务在 startXxx 返回前就被取消的话，这里会发现状态已变，
      // 必须立刻停掉刚建好的句柄，否则连接会泄漏。
      final current = state.transferById(id);
      if (current == null || current.status != SftpTransferStatus.running) {
        await handle.abort();
        return;
      }
      _handles[id] = handle;

      // 总字节数只有句柄才知道：上传方向入队时拿不到本地文件大小，
      // 下载方向服务器也可能报 0（/proc 这类虚拟文件）。
      // 而 `progress` 在 totalBytes <= 0 时返回 null，不补这一下的话
      // 进度条永远没有分母，UI 只能显示一个空的百分比。
      if (handle.totalBytes > 0 && handle.totalBytes != current.totalBytes) {
        state = state.withTransfer(
          current.copyWith(totalBytes: handle.totalBytes),
        );
      }

      await handle.done;
      if (identical(_handles[id], handle)) _handles.remove(id);
      if (disposed) return;
      // 句柄「正常完成」不代表用户没取消过：dartssh2 的
      // `SftpFileWriter.abort()` 就是让 done 正常结束的。
      // 状态已经被 cancelTransfer/removeTransfer 改掉的话，这里不能
      // 再把它翻成 completed，否则用户点了取消却看到「已完成」。
      final finished = state.transferById(id);
      if (finished == null || finished.status != SftpTransferStatus.running) {
        return;
      }
      _finalizingTransfers.add(id);
      if (_managedDownloads.contains(id)) {
        if (await File(task.localPath).exists()) {
          throw const FileSystemException('DOWNLOAD_TARGET_EXISTS');
        }
        await File('${task.localPath}.part').rename(task.localPath);
      }
      if (disposed) return;
      if (task.kind == SftpTransferKind.download && await File(task.localPath).exists()) {
        final file = File(task.localPath);
        final digest = (await sha256.bind(file.openRead()).first).toString();
        final length = await file.length();
        if (disposed) return;
        final latest = state.transferById(id);
        if (latest == null || latest.status != SftpTransferStatus.running) return;
        state = state.withTransfer(latest.copyWith(localSha256: digest,
          transferredBytes: length));
      }
      _completeTransfer(id, SftpTransferStatus.completed);
    } on SftpTransferAborted {
      // 用户主动取消：不是错误，不要写 errorMessage。
      if (identical(_handles[id], handle)) _handles.remove(id);
      if (disposed) return;
      _completeTransfer(id, SftpTransferStatus.canceled);
    } catch (error, stack) {
      if (identical(_handles[id], handle)) _handles.remove(id);
      if (disposed) return;
      unawaited(AppDiagnostics.instance.record('sftp.transfer', error, stack));
      _failTransfer(id, task.kind, error);
    } finally {
      _finalizingTransfers.remove(id);
    }
  }

  void _completeTransfer(String id, SftpTransferStatus status) {
    final task = state.transferById(id);
    if (task == null) return;
    // 被取消时句柄会抛异常，但任务可能已经被 removeTransfer 移走了，
    // 上面的 null 检查就是防这个。
    final finished = task.copyWith(status: status);
    state = state.withTransfer(finished);
    _persistTransfers();
    _notifyDownload(finished);
    if (status == SftpTransferStatus.completed) {
      // 传的是**终态**的任务，不是进来的那个快照。
      // 否则通知回调看到的还是 running，UI 会显示「传输中」而通知已经发了。
      _onTransferCompleted(finished);
      if (_autoOpenDownloads.remove(id)) {
        unawaited(
          openCompletedTransfer(id)
              .catchError((_) {
                if (ref.mounted) {
                  state = state.copyWith(errorMessage: 'DOWNLOAD_OPEN_FAILED');
                }
              }),
        );
      }
    }
    // 一个任务结束后立刻尝试跑下一个。
    _pumpQueue();
  }

  static String downloadErrorCode(Object error) {
    if (error is SFTPException && {
      'SFTP_TRANSFER_SOURCE_CHANGED', 'SFTP_TRANSFER_PARTIAL_INVALID',
    }.contains(error.message)) {
      return error.message;
    }
    if (error is TimeoutException ||
        error is SFTPException && error.message.contains('timed out')) {
      return 'SFTP_DOWNLOAD_TIMEOUT';
    }
    if (error is SftpAbortError ||
        error is SSHConnectionException ||
        error is SSHStateError ||
        error is SocketException) {
      return 'SFTP_DOWNLOAD_DISCONNECTED';
    }
    if (error is SftpStatusError) {
      if (error.code == SftpStatusCode.permissionDenied) {
        return 'SFTP_DOWNLOAD_PERMISSION_DENIED';
      }
      if (error.code == SftpStatusCode.noSuchFile) {
        return 'SFTP_DOWNLOAD_NOT_FOUND';
      }
      if (error.code == SftpStatusCode.connectionLost ||
          error.code == SftpStatusCode.noConnection) {
        return 'SFTP_DOWNLOAD_DISCONNECTED';
      }
    }
    if (error is FileSystemException) {
      if (error.osError?.errorCode == 28) {
        return 'SFTP_DOWNLOAD_LOCAL_SPACE';
      }
      return 'SFTP_DOWNLOAD_LOCAL_IO';
    }
    if (error is SFTPException && error.message == 'SFTP_DOWNLOAD_INCOMPLETE') {
      return 'SFTP_DOWNLOAD_INCOMPLETE';
    }
    return downloadFailedCode;
  }

  void _failTransfer(String id, SftpTransferKind kind, Object error) {
    final task = state.transferById(id);
    if (task == null || task.status.isTerminal) return;
    final detailed = error is SFTPException && {
      'SFTP_TRANSFER_SOURCE_CHANGED', 'SFTP_TRANSFER_PARTIAL_INVALID',
      'SFTP_UPLOAD_TARGET_EXISTS', 'SFTP_UPLOAD_COMMIT_FAILED',
      'SFTP_UPLOAD_SOURCE_INVALID',
    }.contains(error.message) ? error.message : null;
    final code = detailed ?? (kind == SftpTransferKind.upload
        ? uploadFailedCode
        : downloadErrorCode(error));
    if (kind == SftpTransferKind.download &&
        {
          'SFTP_DOWNLOAD_TIMEOUT',
          'SFTP_DOWNLOAD_DISCONNECTED',
        }.contains(code) &&
        (_downloadRetries[id] ?? 0) < 1 &&
        task.status == SftpTransferStatus.running) {
      final connected = ref.read(serverConnectionProvider).isConnected;
      if (connected) {
        _downloadRetries[id] = 1;
      } else {
        _connectionPaused.add(id);
      }
      state = state.withTransfer(
        task.copyWith(
          status: connected
              ? SftpTransferStatus.queued
              : SftpTransferStatus.paused,
          transferredBytes: 0,
          errorMessage: connected ? null : 'SSH_DISCONNECTED',
          clearError: connected,
        ),
      );
      _persistTransfers();
      _notifyDownload(state.transferById(id)!, force: true);
      _pumpQueue();
      return;
    }
    // 两处都要写：任务上的 errorMessage 让传输列表能逐条标出失败原因，
    // state 上的让文件页顶部的错误条立刻可见（改造前就是靠它提示的，
    // 只留在任务里会让既有提示消失）。清不走 clearError，否则下一条
    // 失败提示可能被旧的清空动作吃掉。
    state = state
        .withTransfer(
          task.copyWith(status: SftpTransferStatus.failed, errorMessage: code),
        )
        .copyWith(errorMessage: code);
    _persistTransfers();
    _notifyDownload(state.transferById(id)!);
    _pumpQueue();
  }

  /// 传输成功后的收尾。抽成方法是为了让「刷新目录」与「发通知」
  /// 两件事都能被子类/测试观察到。
  void _onTransferCompleted(SftpTransfer task) {
    if (_managedDownloads.contains(task.id)) return;
    // 上传完成后刷新，让新文件立刻出现在列表里；下载不影响远端目录。
    if (task.kind == SftpTransferKind.upload) {
      unawaited(refresh());
    }
    final notify = ref.read(transferNotificationCallbackProvider);
    notify?.call(task);
  }

  /// 暂停某个任务。
  ///
  /// 只有 running 的任务能暂停：queued 的直接改状态即可（它还没开始），
  /// 已结束的是空操作。
  Future<void> pauseTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null) return;
    if (_isPublishing(id)) {
      state = state.copyWith(errorMessage: 'SFTP_TRANSFER_COMMITTING');
      return;
    }

    if (task.status == SftpTransferStatus.queued) {
      state = state.withTransfer(
        task.copyWith(status: SftpTransferStatus.paused),
      );
      _persistTransfers();
      return;
    }
    if (task.status != SftpTransferStatus.running) return;

    state = state.withTransfer(
      task.copyWith(status: SftpTransferStatus.paused),
    );
    _persistTransfers();
    _notifyDownload(state.transferById(id)!, force: true);
    await _handles[id]?.pause();
    // 让出执行权，好让队列里排在后面的任务开始跑。
    // 暂停中的任务仍然占着句柄，所以它自己不会被重新调度；
    // 但若它是唯一的任务，这里不会有任何事发生。
    _pumpQueue();
  }

  /// 继续某个暂停的任务。
  Future<void> resumeTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null || task.status != SftpTransferStatus.paused) return;

    final handle = _handles[id];
    if (handle != null) {
      if (state.activeTransfer != null) {
        state = state.copyWith(errorMessage: 'SFTP_TRANSFER_BUSY');
        return;
      }
      // 句柄还在：原地恢复，不需要重新排队。这是暂停/继续的常见路径。
      state = state.withTransfer(
        task.copyWith(status: SftpTransferStatus.running),
      );
      _persistTransfers();
      _notifyDownload(state.transferById(id)!, force: true);
      await handle.resume();
      return;
    }
    // 句柄已经没了（例如任务还没轮到跑就被暂停）。放回队列。
    state = state.withTransfer(
      task.copyWith(
        status: SftpTransferStatus.queued,
        transferredBytes: 0,
        clearError: true,
      ),
    );
    _persistTransfers();
    _notifyDownload(state.transferById(id)!, force: true);
    _pumpQueue();
  }

  void _requireTransferCapacity() {
    if (state.pendingTransferCount >= 100) {
      throw const SFTPException('SFTP_TRANSFER_QUEUE_FULL');
    }
    if (state.transfers.length >= 100) {
      state = state.copyWith(transfers: [
        ...state.transfers.where((task) => !task.status.isTerminal),
        ...state.transfers.where((task) => task.status.isTerminal).toList().reversed.take(49),
      ]);
    }
  }

  void _validateTransferName(String name) {
    if (name.isEmpty || name == '.' || name == '..' ||
        name.contains(RegExp(r'[/\\\x00-\x1f]'))) {
      throw const ValidationException('SFTP_FILENAME_INVALID');
    }
  }

  bool _isPublishing(String id) {
    final handle = _handles[id];
    return _finalizingTransfers.contains(id) ||
      handle is SftpCommittingTransfer &&
        (handle as SftpCommittingTransfer).isCommitting;
  }

  /// 取消某个任务。
  ///
  /// 与 [removeTransfer] 的区别：取消会真的停掉传输并留下一条
  /// `canceled` 记录，删除只是把记录从列表里去掉。
  /// 对未开始的任务，取消等于直接标记，不涉及句柄。
  Future<void> cancelTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null || task.status.isTerminal) return;
    final sourceEpoch = _sourceEpoch;
    final service = _service;
    if (_isPublishing(id)) {
      state = state.copyWith(errorMessage: 'SFTP_TRANSFER_COMMITTING');
      return;
    }
    final handle = _handles.remove(id);
    state = state.withTransfer(
      task.copyWith(status: SftpTransferStatus.canceled),
    );
    _persistTransfers();
    _notifyDownload(state.transferById(id)!, force: true);
    if (handle != null) {
      await handle.abort();
    }
    await _discardTransferPartial(task, service);
    if (!_currentSource(sourceEpoch)) return;
    _pumpQueue();
  }

  Future<bool> _discardTransferPartial(SftpTransfer task, SftpOperations service) async {
    try {
      if (task.kind == SftpTransferKind.upload && service is SftpResumableOperations) {
        await (service as SftpResumableOperations).discardUploadPartial(task.remotePath, task.id);
      } else if (task.managedDownload) {
        final partial = File('${task.localPath}.part');
        if (await partial.exists()) await partial.delete();
      }
      return true;
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('sftp.partial.cleanup', error, stack));
      if (ref.mounted && state.transferById(task.id) != null) {
        state = state.withTransfer(task.copyWith(status: SftpTransferStatus.canceled,
          errorMessage: 'SFTP_TRANSFER_CLEANUP_FAILED'));
      }
      _persistTransfers();
      return false;
    }
  }

  /// 从列表里移除某个任务（不改变传输本身）。
  ///
  /// 对未结束的任务，先取消再移除——否则任务会在没有句柄登记的情况下
  /// 继续跑，取消不掉。
  Future<void> removeTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null) return;
    final sourceEpoch = _sourceEpoch;
    final service = _service;
    if (_isPublishing(id)) {
      state = state.copyWith(errorMessage: 'SFTP_TRANSFER_COMMITTING');
      return;
    }
    if (!task.status.isTerminal) {
      _notifyDownload(
        task.copyWith(status: SftpTransferStatus.canceled),
        force: true,
      );
      final handle = _handles.remove(id);
      if (handle != null) await handle.abort();
    }
    if (task.status != SftpTransferStatus.completed) {
      if (!await _discardTransferPartial(task, service)) return;
    }
    if (!_currentSource(sourceEpoch)) return;
    state = state.withoutTransfer(id);
    _persistTransfers();
    _pumpQueue();
  }

  /// 清除所有已结束的任务。
  void clearFinishedTransfers() {
    state = state.copyWith(
      transfers: state.transfers.where((t) => !t.status.isTerminal ||
        t.errorMessage == 'SFTP_TRANSFER_CLEANUP_FAILED').toList(),
    );
    _persistTransfers();
  }

  /// 进度回调只更新字节数，不触碰其它字段。
  ///
  /// 任务可能已经被取消或删除，这时回调仍会到达（传输层不知道上层
  /// 已经放弃了它），所以必须先确认任务还在、且仍在跑。
  void _reportProgress(String id, int transferred) {
    if (!ref.mounted) return;
    final task = state.transferById(id);
    if (task == null || task.status != SftpTransferStatus.running) return;
    state = state.withTransfer(task.copyWith(transferredBytes: transferred));
    _persistTransfers(progress: true);
    _notifyDownload(state.transferById(id)!);
  }

  static String _newTransferId() => const Uuid().v4();

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  Future<void> createDirectory(String name) async {
    final sourceEpoch = _sourceEpoch;
    final fullPath = state.currentPath == '/'
        ? '/$name'
        : '${state.currentPath}/$name';
    await _service.createDirectory(fullPath);
    if (_currentSource(sourceEpoch)) await refresh();
  }

  bool _batchBusy = false;

  Future<List<RemoteFileResult>> runBatch(
    RemoteFileAction action,
    List<SftpFileItem> items, {
    String? targetDirectory,
    ServerProfile? expectedServer,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (_batchBusy) throw StateError('FILE_OPERATION_PENDING');
    final server = ref.read(activeServerProvider);
    if (expectedServer != null &&
        !(server?.hasSameConnectionSettings(expectedServer) ?? false)) {
      throw StateError('FILE_TARGET_CHANGED');
    }
    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('Server is not connected');
    }
    final sourceEpoch = _sourceEpoch;
    final service = _service;
    final actions = ref.read(remoteFileActionsProvider);
    final selected = {
      for (final item in items) item.path: item,
    }.values.toList();
    final results = <RemoteFileResult>[];
    _batchBusy = true;
    try {
      for (final item in selected) {
        if (!_currentSource(sourceEpoch) ||
            !ref.read(serverConnectionProvider).isConnected) {
          results.add(
            RemoteFileResult(
              item.path,
              RemoteFileOutcome.failed,
              'FILE_OPERATION_INTERRUPTED',
            ),
          );
          continue;
        }
        try {
          if (!path_util.posix.isAbsolute(item.path) ||
              item.path.contains('\x00') ||
              path_util.posix.normalize(item.path) == '/' ||
              item.name == '.' ||
              item.name == '..') {
            throw const FormatException('FILE_PATH_INVALID');
          }
          switch (action) {
            case RemoteFileAction.download:
              if (item.isDirectory || item.isSymbolicLink) {
                results.add(
                  RemoteFileResult(
                    item.path,
                    RemoteFileOutcome.skipped,
                    'FILE_REGULAR_ONLY',
                  ),
                );
              } else {
                final id = await downloadFile(item);
                results.add(
                  RemoteFileResult(
                    item.path,
                    id == null
                        ? RemoteFileOutcome.failed
                        : RemoteFileOutcome.queued,
                    id == null ? 'FILE_DOWNLOAD_QUEUE_FAILED' : null,
                  ),
                );
              }
            case RemoteFileAction.delete:
              if (item.isDirectory && !item.isSymbolicLink) {
                await service.deleteDirectory(item.path);
              } else {
                await service.deleteFile(item.path);
              }
              results.add(
                RemoteFileResult(item.path, RemoteFileOutcome.completed),
              );
            case RemoteFileAction.copy:
            case RemoteFileAction.move:
              if (targetDirectory == null) {
                throw const FormatException('FILE_TARGET_REQUIRED');
              }
              results.add(
                await actions.execute(
                  server.id,
                  action,
                  item.path,
                  targetDirectory,
                ),
              );
          }
        } catch (error) {
          results.add(
            RemoteFileResult(
              item.path,
              RemoteFileOutcome.failed,
              error.toString(),
            ),
          );
        }
        if (_currentSource(sourceEpoch)) {
          onProgress?.call(results.length, selected.length);
        }
      }
    } finally {
      _batchBusy = false;
      if (_currentSource(sourceEpoch) && action != RemoteFileAction.download) {
        await refresh();
      }
    }
    return results;
  }

  Future<void> retryTransfer(String id) async {
    final task = state.transferById(id);
    if (task == null || task.status != SftpTransferStatus.failed) return;
    if (!ref.read(serverConnectionProvider).isConnected) {
      throw const SSHConnectionException('Server is not connected');
    }
    _downloadRetries.remove(id);
    _connectionPaused.remove(id);
    state = state
        .withTransfer(
          task.copyWith(
            status: SftpTransferStatus.queued,
            transferredBytes: 0,
            clearError: true,
          ),
        )
        .copyWith(clearError: state.errorMessage == task.errorMessage);
    _notifyDownload(state.transferById(id)!, force: true);
    _pumpQueue();
  }

  Future<void> createFile(String name, String content) async {
    final sourceEpoch = _sourceEpoch;
    final fullPath = state.currentPath == '/'
        ? '/$name'
        : '${state.currentPath}/$name';
    await _service.writeFileContent(fullPath, content);
    if (_currentSource(sourceEpoch)) await refresh();
  }

  Future<void> deleteItem(SftpFileItem item) async {
    final sourceEpoch = _sourceEpoch;
    if (item.isDirectory && !item.isSymbolicLink) {
      await _service.deleteDirectory(item.path);
    } else {
      await _service.deleteFile(item.path);
    }
    if (_currentSource(sourceEpoch)) await refresh();
  }

  Future<void> renameItem(SftpFileItem item, String newName) async {
    final sourceEpoch = _sourceEpoch;
    final parent = state.currentPath == '/' ? '' : state.currentPath;
    final newPath = '$parent/$newName';
    await _service.rename(item.path, newPath);
    if (_currentSource(sourceEpoch)) await refresh();
  }

  /// 打开文件进行文本预览/编辑。
  ///
  /// 不支持预览的类型直接拒绝并给出 reason code，不去读远端内容——把二进制
  /// 塞进文本控件既无意义，还可能因为体积过大而卡住界面。
  Future<void> openFileForEditing(SftpFileItem item) async {
    final sourceEpoch = _sourceEpoch;
    final editorEpoch = ++_editorEpoch;
    if (item.linkTargetErrorCode != null) {
      state = state.copyWith(errorMessage: item.linkTargetErrorCode);
      return;
    }
    if (item.sizeBytes > SftpClientService.maxPreviewBytes) {
      state = state.copyWith(
        errorMessage: previewTooLargeCode,
        isLoading: false,
      );
      return;
    }
    if (!canPreview(item)) {
      state = state.copyWith(errorMessage: previewUnsupportedCode);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final service = _service;
      final snapshot = service is SftpEditorOperations
          ? await (service as SftpEditorOperations).readTextSnapshot(item.path)
          : null;
      final content = snapshot?.content ?? await service.readFileContent(item.path);
      if (!_currentSource(sourceEpoch) || editorEpoch != _editorEpoch) return;
      final server = _boundServer;
      Map<String, dynamic>? draft;
      final draftKey = server == null ? null : _fileDraftKey(server, item.path);
      if (draftKey != null) {
        try {
          draft = await ref.read(secureStorageServiceProvider).getFileEditorDraft(draftKey);
        } catch (error, stack) {
          unawaited(AppDiagnostics.instance.record('sftp.draft.restore', error, stack));
        }
      }
      if (!_currentSource(sourceEpoch) || editorEpoch != _editorEpoch) return;
      _editorSnapshot = snapshot;
      _editorDraftKey = draftKey;
      _editorDraftConflict = draft != null && draft['digest'] != snapshot?.digest;
      state = state.copyWith(
        isLoading: false,
        editingFilePath: item.path,
        editingFileContent: draft?['content'] as String? ?? content,
        errorMessage: _editorDraftConflict ? 'SFTP_EDIT_DRAFT_CONFLICT' : null,
      );
    } catch (e) {
      if (!_currentSource(sourceEpoch) || editorEpoch != _editorEpoch) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e is SFTPException && e.message == previewTooLargeCode
            ? previewTooLargeCode
            : readFailedCode,
      );
    }
  }

  void closeFileEditor({int? editorToken}) {
    if (editorToken != null && editorToken != _editorEpoch) return;
    _editorDraftTimer?.cancel();
    final pending = _pendingEditorDraft;
    _pendingEditorDraft = null;
    if (pending != null) unawaited(pending());
    _editorEpoch++;
    _editorSnapshot = null;
    state = state.copyWith(
      clearEditor: true,
      clearError: true,
      isLoading: false,
    );
  }

  void updateEditorDraft(String content, {int? editorToken}) {
    if (editorToken != null && editorToken != _editorEpoch) return;
    final original = _editorSnapshot;
    final key = _editorDraftKey;
    if (original == null || key == null) return;
    if (utf8.encode(content).length > SftpClientService.maxPreviewBytes) {
      state = state.copyWith(errorMessage: 'SFTP_PREVIEW_TOO_LARGE');
      return;
    }
    final storage = ref.read(secureStorageServiceProvider);
    _editorDraftTimer?.cancel();
    _pendingEditorDraft = () => _editorDraftWrites = _editorDraftWrites.then((_) async {
      try {
        await storage.saveFileEditorDraft(key, {'content': content, 'digest': original.digest});
      } catch (error, stack) {
        unawaited(AppDiagnostics.instance.record('sftp.draft.save', error, stack));
        if (ref.mounted && key == _editorDraftKey) {
          state = state.copyWith(errorMessage: 'SFTP_DRAFT_SAVE_FAILED');
        }
      }
    });
    _editorDraftTimer = Timer(const Duration(milliseconds: 500), () {
      final pending = _pendingEditorDraft;
      _pendingEditorDraft = null;
      if (pending != null) unawaited(pending());
    });
  }

  Future<void> discardEditorDraft({String? draftKey, int? editorToken}) async {
    if (editorToken != null && editorToken != _editorEpoch) {
      throw const SFTPException('SFTP_EDITOR_EXPIRED');
    }
    final key = draftKey ?? _editorDraftKey;
    final storage = ref.read(secureStorageServiceProvider);
    if (key == _editorDraftKey) {
      _editorDraftTimer?.cancel();
      _pendingEditorDraft = null;
    }
    await _editorDraftWrites;
    if (key != null) await storage.deleteFileEditorDraft(key);
    if (key == _editorDraftKey) _editorDraftConflict = false;
  }

  Future<void> saveFileContent(String path, String content, {int? editorToken}) async {
    final sourceEpoch = _sourceEpoch;
    final editorEpoch = _editorEpoch;
    final service = _service;
    final snapshot = _editorSnapshot;
    final draftKey = _editorDraftKey;
    if (path != state.editingFilePath || editorToken != null && editorToken != _editorEpoch) {
      throw const SFTPException('SFTP_EDITOR_EXPIRED');
    }
    if (_editorDraftConflict) throw const SFTPException('SFTP_EDIT_DRAFT_CONFLICT');
    if (service is SftpEditorOperations && snapshot != null) {
      await (service as SftpEditorOperations).saveTextSnapshot(snapshot, content);
    } else {
      // Legacy implementations cannot provide revision-safe replacement.
      throw const SFTPException('SFTP_ATOMIC_SAVE_UNSUPPORTED');
    }
    if (!_currentSource(sourceEpoch)) {
      throw const SFTPException('SFTP_EDITOR_EXPIRED');
    }
    try {
      await discardEditorDraft(draftKey: draftKey);
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('sftp.draft.cleanup', error, stack));
    }
    if (editorEpoch == _editorEpoch) closeFileEditor();
    await refresh();
  }
}

final sftpProvider = NotifierProvider<SftpNotifier, SftpState>(() {
  return SftpNotifier();
});
