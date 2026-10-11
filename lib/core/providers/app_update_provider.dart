import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';
import '../../data/models/app_update.dart';
import '../services/app_update_service.dart';
import '../services/download_platform_service.dart';
import '../services/app_diagnostics.dart';
import 'app_visibility_provider.dart';
import 'storage_providers.dart';

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
  const AppUpdateState({this.automaticCheck = true, this.checking = false,
    this.updateAvailable = false, this.release, this.artifact, this.checkedAt,
    this.error, this.downloadStatus = AppUpdateDownloadStatus.idle,
    this.downloadedBytes = 0, this.localPath});

  AppUpdateState copyWith({bool? automaticCheck, bool? checking,
    bool? updateAvailable, AppUpdateRelease? release, AppUpdateArtifact? artifact,
    DateTime? checkedAt, String? error, bool clearError = false,
    AppUpdateDownloadStatus? downloadStatus, int? downloadedBytes, String? localPath}) =>
    AppUpdateState(automaticCheck: automaticCheck ?? this.automaticCheck,
      checking: checking ?? this.checking, updateAvailable: updateAvailable ?? this.updateAvailable,
      release: release ?? this.release, artifact: artifact ?? this.artifact,
      checkedAt: checkedAt ?? this.checkedAt, error: clearError ? null : error ?? this.error,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes, localPath: localPath ?? this.localPath);
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.dispose);
  return service;
});
final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);
/// Production opts in at the root; isolated widgets never perform HTTP checks.
final automaticUpdateChecksEnabledProvider = Provider<bool>((ref) => false);

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  static const platformChannel = MethodChannel('valhalla/updates');
  final _files = DownloadPlatformService();
  Map<String, dynamic>? _cache;
  Map<String, dynamic>? _runtime;
  Future<void>? _check;
  Future<void>? _downloadTask;
  int _downloadEpoch = 0;
  int _releaseEpoch = 0;

  void _reportDownload(String status, AppUpdateArtifact artifact, {int? bytes}) {
    unawaited(_files.report({'id': 'valhalla-app-update', 'target': 'update',
      'name': artifact.name, 'bytes': bytes ?? state.downloadedBytes,
      'total': artifact.size, 'status': status}));
  }

  @override
  AppUpdateState build() {
    final storage = ref.read(localStorageServiceProvider);
    try { _cache = storage.getUpdateCheckCache(); }
    catch (error, stack) { unawaited(AppDiagnostics.instance.record('updates.cache', error, stack)); }
    ref.listen(appVisibilityProvider, (_, visible) {
      if (visible) unawaited(checkIfDue());
    });
    ref.onDispose(() => _downloadEpoch++);
    Future.microtask(() {
      if (ref.mounted) unawaited(_restore());
    });
    return AppUpdateState(automaticCheck: storage.getAutomaticUpdateCheck(),
      checkedAt: DateTime.tryParse(_cache?['checkedAt'] as String? ?? ''));
  }

  Future<void> _restore() async {
    try {
      final cached = _cache?['release'] as Map<String, dynamic>?;
      if (cached != null) {
        await _applyRelease(AppUpdateService.parseRelease(cached,
          cached['_valhalla_manifest'] as Map<String, dynamic>?), state.checkedAt);
      }
    } catch (error, stack) {
      unawaited(AppDiagnostics.instance.record('updates.restore', error, stack));
    }
    if (ref.mounted) await checkIfDue();
  }

  Future<void> _applyRelease(AppUpdateRelease? release, DateTime? checked) async {
    final epoch = ++_releaseEpoch;
    final info = await PackageInfo.fromPlatform();
    if (Platform.isAndroid) {
      _runtime = await platformChannel.invokeMapMethod<String, dynamic>('runtimeInfo');
    } else if (Platform.isWindows) {
      _runtime = await DownloadPlatformService.channel.invokeMapMethod<String, dynamic>('runtimeInfo');
    }
    if (!ref.mounted || epoch != _releaseEpoch) return;
    final arch = Platform.isAndroid
      ? (_runtime?['abis'] as List? ?? []).cast<String>()
      : [if (Platform.version.toLowerCase().contains('arm64')) 'arm64' else 'x64', 'universal'];
    final artifact = release?.artifactFor(Platform.operatingSystem, arch);
    final baseBuild = (_runtime?['baseBuildNumber'] as int?) ?? int.tryParse(info.buildNumber) ?? 0;
    final record = ref.read(localStorageServiceProvider).getUpdateDownloadRecord();
    var status = AppUpdateDownloadStatus.idle;
    String? path;
    var bytes = 0;
    if (artifact != null && record?['sha256'] == artifact.sha256 &&
        record?['url'] == artifact.url.toString()) {
      path = record?['path'] as String?;
      if (path != null) {
        if (await File(path).exists() && await File(path).length() == artifact.size) {
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
      state = state.copyWith(checking: false, checkedAt: checked, clearError: true);
      return;
    }
    state = AppUpdateState(automaticCheck: state.automaticCheck, checkedAt: checked,
      release: release, artifact: artifact,
      updateAvailable: release?.isNewerThan(info.version, baseBuild) ?? false,
      downloadStatus: status, downloadedBytes: bytes, localPath: path);
  }

  Future<void> setAutomaticCheck(bool value) async {
    await ref.read(localStorageServiceProvider).setAutomaticUpdateCheck(value);
    if (ref.mounted) state = state.copyWith(automaticCheck: value);
    if (value) await checkIfDue();
  }

  Future<void> checkIfDue() async {
    if (!ref.read(automaticUpdateChecksEnabledProvider) ||
        !state.automaticCheck || !ref.read(appVisibilityProvider)) {
      return;
    }
    final last = state.checkedAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) {
      return;
    }
    await check();
  }

  Future<void> check() => _check ??= _performCheck().whenComplete(() => _check = null);

  Future<void> _performCheck() async {
    state = state.copyWith(checking: true, clearError: true);
    try {
      final result = await ref.read(appUpdateServiceProvider).check(
        etag: _cache?['etag'] as String?, cached: _cache?['release'] as Map<String, dynamic>?);
      final checked = DateTime.now().toUtc();
      _cache = {'checkedAt': checked.toIso8601String(), 'etag': result.etag,
        if (result.response != null) 'release': result.response};
      await ref.read(localStorageServiceProvider).saveUpdateCheckCache(_cache!);
      if (!ref.mounted) return;
      await _applyRelease(result.release, checked);
    } catch (error) {
      if (ref.mounted) state = state.copyWith(checking: false, error: error.toString());
    }
  }

  Future<void> download() async {
    final artifact = state.artifact;
    if (!state.updateAvailable || artifact == null || state.downloadStatus == AppUpdateDownloadStatus.downloading) return;
    if (_runtime?['storeInstall'] == true || Platform.isIOS) {
      await openRelease();
      return;
    }
    final epoch = ++_downloadEpoch;
    // Pin the selected artifact before path allocation yields to a release check.
    state = state.copyWith(downloadStatus: AppUpdateDownloadStatus.downloading,
      clearError: true);
    try {
      // A paused writer must close before the same .part file is reopened.
      final previous = _downloadTask;
      if (previous != null) {
        try { await previous; } catch (_) { /* The old attempt owns its error. */ }
      }
      if (!ref.mounted || epoch != _downloadEpoch) return;
      final path = state.localPath ?? await _files.reservePath(artifact.name);
      if (!ref.mounted || epoch != _downloadEpoch) return;
      await ref.read(localStorageServiceProvider).saveUpdateDownloadRecord({
        'path': path, 'url': artifact.url.toString(), 'sha256': artifact.sha256});
      if (!ref.mounted || epoch != _downloadEpoch) return;
      state = state.copyWith(downloadStatus: AppUpdateDownloadStatus.downloading,
        localPath: path, clearError: true);
      var lastPublished = DateTime.fromMillisecondsSinceEpoch(0);
      var lastReported = DateTime.fromMillisecondsSinceEpoch(0);
      final task = ref.read(appUpdateServiceProvider).download(artifact, path, onProgress: (bytes) {
        if (!ref.mounted || epoch != _downloadEpoch) return;
        final now = DateTime.now();
        if (now.difference(lastReported).inSeconds >= 1) {
          lastReported = now;
          _reportDownload('running', artifact, bytes: bytes);
        }
        if (bytes != artifact.size && now.difference(lastPublished).inMilliseconds < 150) return;
        lastPublished = now;
        state = state.copyWith(downloadedBytes: bytes);
      });
      _downloadTask = task;
      try {
        await task;
      } finally {
        if (identical(_downloadTask, task)) _downloadTask = null;
      }
      if (ref.mounted && epoch == _downloadEpoch) {
        state = state.copyWith(downloadStatus: AppUpdateDownloadStatus.completed,
          downloadedBytes: artifact.size);
        _reportDownload('completed', artifact);
      }
    } catch (error) {
      if (ref.mounted && epoch == _downloadEpoch) {
        state = state.copyWith(downloadStatus: AppUpdateDownloadStatus.failed, error: error.toString());
        _reportDownload('failed', artifact);
      }
    }
  }

  void pauseDownload() {
    if (state.downloadStatus != AppUpdateDownloadStatus.downloading) return;
    _downloadEpoch++;
    ref.read(appUpdateServiceProvider).cancelDownload();
    state = state.copyWith(downloadStatus: AppUpdateDownloadStatus.paused);
    final artifact = state.artifact;
    if (artifact != null) _reportDownload('paused', artifact);
  }

  Future<void> openDownloaded() async {
    if (state.downloadStatus != AppUpdateDownloadStatus.completed || state.localPath == null) return;
    final artifact = state.artifact;
    final path = state.localPath!;
    final version = state.release?.version;
    if (artifact == null || !await File(path).exists() ||
        await File(path).length() != artifact.size ||
        (await sha256.bind(File(path).openRead()).first).toString() != artifact.sha256) {
      throw StateError('UPDATE_DOWNLOAD_INTEGRITY_FAILED');
    }
    if (Platform.isAndroid) {
      await platformChannel.invokeMethod<void>('install', {'path': path,
        'versionCode': artifact.androidVersionCode,
        'certificateSha256': artifact.androidCertificateSha256,
        'versionName': version});
    } else if (Platform.isWindows) {
      await _files.revealFile(path);
    } else {
      if (!await launchUrl(Uri.file(File(path).parent.path))) {
        throw StateError('UPDATE_OPEN_FAILED');
      }
    }
  }

  Future<void> openRelease() async {
    final url = _runtime?['storeInstall'] == true
        ? Uri.parse(Platform.isWindows ? 'ms-windows-store://downloadsandupdates'
          : 'https://play.google.com/store/apps/details?id=com.antigravity.valhalla.valhalla')
        : state.release?.page ?? Uri.parse(valhallaReleasesUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('UPDATE_OPEN_FAILED');
    }
  }
}
