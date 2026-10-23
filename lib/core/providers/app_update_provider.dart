import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/app_update.dart';
import '../services/app_update_service.dart';
import '../services/download_platform_service.dart';
import '../services/app_diagnostics.dart';
import 'app_visibility_provider.dart';
import 'storage_providers.dart';
import '../utils/file_integrity.dart';
import '../utils/app_runtime_identity.dart';
import '../utils/transfer_progress.dart';

export '../services/app_update_service.dart' show AppUpdateDownloadPhase;

enum AppUpdateDownloadStatus { idle, downloading, paused, completed, failed }

class AppUpdateState {
  final bool automaticCheck;
  final bool checking;
  final bool updateAvailable;
  final AppUpdateRelease? release;
  final AppUpdateArtifact? artifact;
  final DateTime? checkedAt;
  final String? error;
  final AppUpdateDownloadStatus downloadStatus;
  final int downloadedBytes;
  final String? localPath;
  final AppUpdateDownloadPhase downloadPhase;
  final double bytesPerSecond;
  final bool opening;
  final bool pendingAutomaticPrompt;
  const AppUpdateState({
    this.automaticCheck = true,
    this.checking = false,
    this.updateAvailable = false,
    this.release,
    this.artifact,
    this.checkedAt,
    this.error,
    this.downloadStatus = AppUpdateDownloadStatus.idle,
    this.downloadedBytes = 0,
    this.localPath,
    this.downloadPhase = AppUpdateDownloadPhase.transferring,
    this.bytesPerSecond = 0,
    this.opening = false,
    this.pendingAutomaticPrompt = false,
  });

  int? get remainingSeconds =>
      downloadStatus == AppUpdateDownloadStatus.downloading &&
          downloadPhase == AppUpdateDownloadPhase.transferring &&
          artifact != null &&
          artifact!.size > downloadedBytes &&
          bytesPerSecond > 0
      ? ((artifact!.size - downloadedBytes) / bytesPerSecond).ceil()
      : null;

  AppUpdateState copyWith({
    bool? automaticCheck,
    bool? checking,
    bool? updateAvailable,
    AppUpdateRelease? release,
    AppUpdateArtifact? artifact,
    DateTime? checkedAt,
    String? error,
    bool clearError = false,
    AppUpdateDownloadStatus? downloadStatus,
    int? downloadedBytes,
    String? localPath,
    AppUpdateDownloadPhase? downloadPhase,
    double? bytesPerSecond,
    bool? opening,
    bool? pendingAutomaticPrompt,
  }) => AppUpdateState(
    automaticCheck: automaticCheck ?? this.automaticCheck,
    checking: checking ?? this.checking,
    updateAvailable: updateAvailable ?? this.updateAvailable,
    release: release ?? this.release,
    artifact: artifact ?? this.artifact,
    checkedAt: checkedAt ?? this.checkedAt,
    error: clearError ? null : error ?? this.error,
    downloadStatus: downloadStatus ?? this.downloadStatus,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    localPath: localPath ?? this.localPath,
    downloadPhase: downloadPhase ?? this.downloadPhase,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    opening: opening ?? this.opening,
    pendingAutomaticPrompt:
        pendingAutomaticPrompt ?? this.pendingAutomaticPrompt,
  );
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.dispose);
  return service;
});
final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);

/// Production opts in at the root; isolated widgets never perform HTTP checks.
final automaticUpdateChecksEnabledProvider = Provider<bool>((ref) => false);
final appUpdateNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  static const platformChannel = MethodChannel('valhalla/updates');
  final _files = DownloadPlatformService();
  Map<String, dynamic>? _cache;
  Map<String, dynamic>? _runtime;
  Future<void>? _check;
  Future<void>? _downloadTask;
  Future<void>? _openTask;
  int _downloadEpoch = 0;
  int _releaseEpoch = 0;
  Future<void>? _dailyCheck;
  bool _claimingAutomaticPrompt = false;
  String? _claimedPromptDate;

  String _localDate(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  void _reportDownload(
    String status,
    AppUpdateArtifact artifact, {
    int? bytes,
  }) {
    unawaited(
      _files.report({
        'id': 'valhalla-app-update',
        'target': 'update',
        'name': artifact.name,
        'bytes': bytes ?? state.downloadedBytes,
        'total': artifact.size,
        'status': status,
      }),
    );
  }

  @override
  AppUpdateState build() {
    final storage = ref.read(localStorageServiceProvider);
    try {
      _cache = storage.getUpdateCheckCache();
      // Keep legacy preferences on disk for rollback, but never act on GitHub cache.
      if (!AppUpdateService.isCurrentCache(_cache)) _cache = null;
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('updates.cache', error, stack));
    }
    ref.listen(appVisibilityProvider, (_, visible) {
      if (visible) unawaited(checkIfDue());
    });
    ref.onDispose(() => _downloadEpoch++);
    Future.microtask(() {
      if (ref.mounted) unawaited(_restore());
    });
    return AppUpdateState(
      automaticCheck: storage.getAutomaticUpdateCheck(),
      checkedAt: DateTime.tryParse(_cache?['checkedAt'] as String? ?? ''),
    );
  }

  Future<void> _restore() async {
    try {
      final cached = _cache?['release'] as Map<String, dynamic>?;
      if (cached != null) {
        await _applyRelease(
          AppUpdateService.parseRelease(cached),
          state.checkedAt,
        );
      }
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.instance.record('updates.restore', error, stack),
      );
    }
    if (ref.mounted) await checkIfDue();
  }

  Future<void> _applyRelease(
    AppUpdateRelease? release,
    DateTime? checked,
  ) async {
    final epoch = ++_releaseEpoch;
    final info = await PackageInfo.fromPlatform();
    if (!ref.mounted || epoch != _releaseEpoch) return;
    final runtime = await _loadRuntime();
    if (!ref.mounted || epoch != _releaseEpoch) return;
    _runtime = runtime;
    final arch = _architectures();
    final artifact = release?.artifactFor(Platform.operatingSystem, arch);
    final baseBuild =
        (_runtime?['baseBuildNumber'] as int?) ??
        int.tryParse(info.buildNumber) ??
        0;
    final record = ref
        .read(localStorageServiceProvider)
        .getUpdateDownloadRecord();
    var status = AppUpdateDownloadStatus.idle;
    String? path;
    var bytes = 0;
    if (artifact != null &&
        record?['sha256'] == artifact.sha256 &&
        record?['url'] == artifact.url.toString()) {
      path = record?['path'] as String?;
      if (path != null) {
        if (await File(path).exists() &&
            await File(path).length() == artifact.size) {
          status = AppUpdateDownloadStatus.completed;
          bytes = artifact.size;
        } else if (await File('$path.part').exists()) {
          bytes = await File('$path.part').length();
          status = AppUpdateDownloadStatus.paused;
        }
      }
    }
    if (!ref.mounted || epoch != _releaseEpoch) return;
    if (state.downloadStatus == AppUpdateDownloadStatus.downloading) {
      state = state.copyWith(
        checking: false,
        checkedAt: checked,
        clearError: true,
      );
      return;
    }
    state = AppUpdateState(
      automaticCheck: state.automaticCheck,
      checkedAt: checked,
      release: release,
      artifact: artifact,
      updateAvailable: release?.isNewerThan(info.version, baseBuild) ?? false,
      downloadStatus: status,
      downloadedBytes: bytes,
      localPath: path,
    );
  }

  Future<void> setAutomaticCheck(bool value) async {
    await ref.read(localStorageServiceProvider).setAutomaticUpdateCheck(value);
    if (ref.mounted) {
      state = state.copyWith(
        automaticCheck: value,
        pendingAutomaticPrompt: value ? null : false,
      );
    }
    if (value) await checkIfDue();
  }

  Future<void> checkIfDue() =>
      _dailyCheck ??= _checkDaily().whenComplete(() => _dailyCheck = null);

  Future<void> _checkDaily() async {
    if (!ref.read(automaticUpdateChecksEnabledProvider) ||
        !state.automaticCheck ||
        !ref.read(appVisibilityProvider)) {
      return;
    }
    try {
      final storage = ref.read(localStorageServiceProvider);
      final now = ref.read(appUpdateNowProvider)();
      final today = _localDate(now);
      final record = storage.getUpdatePromptRecord();
      final lastAttempt = DateTime.tryParse(
        record['lastAttemptAt'] as String? ?? '',
      );
      if (record['lastSuccessDate'] == today) {
        // A verified daily result may have been saved before a modal/app exit
        // prevented presentation. Restore that unclaimed notice, not old caches.
        state = state.copyWith(
          pendingAutomaticPrompt:
              state.automaticCheck &&
              state.updateAvailable &&
              state.release != null &&
              record['lastPromptDate'] != today,
        );
        return;
      }
      if (lastAttempt != null &&
          !now.isBefore(lastAttempt) &&
          now.difference(lastAttempt) < const Duration(minutes: 15)) {
        return;
      }
      await storage.saveUpdatePromptRecord({
        ...record,
        'lastAttemptAt': now.toUtc().toIso8601String(),
      });
      if (!ref.mounted) return;
      await check();
      if (!ref.mounted || state.error != null || state.checkedAt == null) {
        return;
      }
      final latest = storage.getUpdatePromptRecord();
      final completedDate = _localDate(ref.read(appUpdateNowProvider)());
      await storage.saveUpdatePromptRecord({
        ...latest,
        'lastSuccessDate': completedDate,
      });
      if (!ref.mounted) return;
      state = state.copyWith(
        pendingAutomaticPrompt:
            state.automaticCheck &&
            state.updateAvailable &&
            state.release != null &&
            latest['lastPromptDate'] != completedDate,
      );
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('updates.daily', error, stack));
    }
  }

  Future<bool> claimAutomaticPrompt() async {
    if (_claimingAutomaticPrompt ||
        !state.pendingAutomaticPrompt ||
        !state.automaticCheck ||
        !state.updateAvailable ||
        state.release == null ||
        !ref.read(appVisibilityProvider)) {
      return false;
    }
    _claimingAutomaticPrompt = true;
    state = state.copyWith(pendingAutomaticPrompt: false);
    try {
      final storage = ref.read(localStorageServiceProvider);
      final record = storage.getUpdatePromptRecord();
      final today = _localDate(ref.read(appUpdateNowProvider)());
      if (record['lastPromptDate'] == today) return false;
      await storage.saveUpdatePromptRecord({
        ...record,
        'lastPromptDate': today,
      });
      _claimedPromptDate = today;
      if (!ref.mounted) return false;
      if (!ref.read(appVisibilityProvider) || !state.updateAvailable) {
        await deferAutomaticPrompt();
        return false;
      }
      return true;
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('updates.prompt', error, stack));
      return false;
    } finally {
      _claimingAutomaticPrompt = false;
    }
  }

  Future<void> deferAutomaticPrompt() async {
    final date = _claimedPromptDate;
    if (date == null) return;
    _claimedPromptDate = null;
    try {
      final storage = ref.read(localStorageServiceProvider);
      final record = storage.getUpdatePromptRecord();
      if (record['lastPromptDate'] == date) {
        await storage.saveUpdatePromptRecord(
          {...record}..remove('lastPromptDate'),
        );
      }
      if (ref.mounted) {
        state = state.copyWith(
          pendingAutomaticPrompt: state.automaticCheck && state.updateAvailable,
        );
      }
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.instance.record('updates.prompt.defer', error, stack),
      );
    }
  }

  Future<void> check() =>
      _check ??= _performCheck().whenComplete(() => _check = null);

  Future<Map<String, dynamic>?> _loadRuntime() async {
    if (Platform.isAndroid) {
      return platformChannel.invokeMapMethod<String, dynamic>('runtimeInfo');
    }
    if (Platform.isWindows) {
      return DownloadPlatformService.channel.invokeMapMethod<String, dynamic>(
        'runtimeInfo',
      );
    }
    return _runtime;
  }

  List<String> _architectures() => applicationArchitectures();

  Future<void> _performCheck() async {
    state = state.copyWith(checking: true, clearError: true);
    try {
      final info = await PackageInfo.fromPlatform();
      if (!ref.mounted) return;
      final versionCode = int.tryParse(info.buildNumber) ?? 0;
      final architecture = _architectures().first;
      final result = await ref
          .read(appUpdateServiceProvider)
          .check(
            etag: _cache?['etag'] as String?,
            cached: _cache?['release'] as Map<String, dynamic>?,
            currentVersionCode: versionCode,
            platform: Platform.operatingSystem,
            architecture: architecture,
          );
      if (!ref.mounted) return;
      final checked = ref.read(appUpdateNowProvider)().toUtc();
      _cache = {
        'source': AppUpdateService.cacheSource,
        'checkedAt': checked.toIso8601String(),
        'etag': result.etag,
        if (result.response != null) 'release': result.response,
      };
      await ref.read(localStorageServiceProvider).saveUpdateCheckCache(_cache!);
      if (!ref.mounted) return;
      await _applyRelease(result.release, checked);
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(checking: false, error: error.toString());
      }
    }
  }

  Future<void> download() async {
    final artifact = state.artifact;
    if (!state.updateAvailable ||
        artifact == null ||
        state.downloadStatus == AppUpdateDownloadStatus.downloading) {
      return;
    }
    if (_runtime?['storeInstall'] == true || Platform.isIOS) {
      await openRelease();
      return;
    }
    final epoch = ++_downloadEpoch;
    // Pin the selected artifact before path allocation yields to a release check.
    state = state.copyWith(
      downloadStatus: AppUpdateDownloadStatus.downloading,
      downloadPhase: AppUpdateDownloadPhase.resolving,
      bytesPerSecond: 0,
      clearError: true,
    );
    try {
      // A paused writer must close before the same .part file is reopened.
      final previous = _downloadTask;
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* The old attempt owns its error. */
        }
      }
      if (!ref.mounted || epoch != _downloadEpoch) return;
      final path = state.localPath ?? await _files.reservePath(artifact.name);
      if (!ref.mounted || epoch != _downloadEpoch) return;
      await ref.read(localStorageServiceProvider).saveUpdateDownloadRecord({
        'path': path,
        'url': artifact.url.toString(),
        'sha256': artifact.sha256,
      });
      if (!ref.mounted || epoch != _downloadEpoch) return;
      state = state.copyWith(
        downloadStatus: AppUpdateDownloadStatus.downloading,
        localPath: path,
        clearError: true,
      );
      var meter = TransferProgressMeter(initialBytes: state.downloadedBytes);
      var lastReported = DateTime.fromMillisecondsSinceEpoch(0);
      final task = ref
          .read(appUpdateServiceProvider)
          .download(
            artifact,
            path,
            onPhase: (phase) {
              if (!ref.mounted || epoch != _downloadEpoch) return;
              meter = TransferProgressMeter(
                initialBytes: state.downloadedBytes,
              );
              state = state.copyWith(downloadPhase: phase, bytesPerSecond: 0);
            },
            onProgress: (bytes) {
              if (!ref.mounted || epoch != _downloadEpoch) return;
              final now = DateTime.now();
              if (now.difference(lastReported).inSeconds >= 1) {
                lastReported = now;
                _reportDownload('running', artifact, bytes: bytes);
              }
              if (!meter.sample(bytes, force: bytes == artifact.size)) return;
              state = state.copyWith(
                downloadedBytes: bytes,
                bytesPerSecond: meter.bytesPerSecond,
              );
            },
          );
      _downloadTask = task;
      try {
        await task;
      } finally {
        if (identical(_downloadTask, task)) _downloadTask = null;
      }
      if (ref.mounted && epoch == _downloadEpoch) {
        state = state.copyWith(
          downloadStatus: AppUpdateDownloadStatus.completed,
          downloadedBytes: artifact.size,
          bytesPerSecond: 0,
        );
        _reportDownload('completed', artifact);
      }
    } catch (error) {
      if (ref.mounted && epoch == _downloadEpoch) {
        state = state.copyWith(
          downloadStatus: AppUpdateDownloadStatus.failed,
          error: error.toString(),
          bytesPerSecond: 0,
        );
        _reportDownload('failed', artifact);
      }
    }
  }

  void pauseDownload() {
    if (state.downloadStatus != AppUpdateDownloadStatus.downloading) return;
    _downloadEpoch++;
    ref.read(appUpdateServiceProvider).cancelDownload();
    state = state.copyWith(
      downloadStatus: AppUpdateDownloadStatus.paused,
      bytesPerSecond: 0,
    );
    final artifact = state.artifact;
    if (artifact != null) _reportDownload('paused', artifact);
  }

  Future<void> openDownloaded() =>
      _openTask ??= _openDownloaded().whenComplete(() => _openTask = null);

  Future<void> _openDownloaded() async {
    if (state.downloadStatus != AppUpdateDownloadStatus.completed ||
        state.localPath == null) {
      return;
    }
    final artifact = state.artifact;
    final path = state.localPath!;
    final version = state.release?.version;
    final releaseEpoch = _releaseEpoch;
    final downloadEpoch = _downloadEpoch;
    state = state.copyWith(opening: true);
    try {
      if (artifact == null ||
          !await File(path).exists() ||
          await File(path).length() != artifact.size ||
          await fileSha256(path) != artifact.sha256) {
        throw StateError('UPDATE_DOWNLOAD_INTEGRITY_FAILED');
      }
      // File verification yields; a newer release/disposal must invalidate this open.
      if (!ref.mounted ||
          releaseEpoch != _releaseEpoch ||
          downloadEpoch != _downloadEpoch ||
          state.downloadStatus != AppUpdateDownloadStatus.completed ||
          state.localPath != path ||
          state.artifact?.sha256 != artifact.sha256) {
        return;
      }
      if (Platform.isAndroid) {
        await platformChannel.invokeMethod<void>('install', {
          'path': path,
          'versionCode': artifact.androidVersionCode,
          'certificateSha256': artifact.androidCertificateSha256,
          'versionName': version,
        });
      } else if (Platform.isWindows) {
        await _files.revealFile(path);
      } else {
        if (!await launchUrl(Uri.file(File(path).parent.path))) {
          throw StateError('UPDATE_OPEN_FAILED');
        }
      }
    } finally {
      if (ref.mounted) state = state.copyWith(opening: false);
    }
  }

  Future<void> openRelease() async {
    final url = _runtime?['storeInstall'] == true
        ? Uri.parse(
            Platform.isWindows
                ? 'ms-windows-store://downloadsandupdates'
                : 'https://play.google.com/store/apps/details?id=com.norns.valhalla',
          )
        : state.release?.page ?? Uri.parse(valhallaReleasesUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('UPDATE_OPEN_FAILED');
    }
  }
}
