import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/models/app_update.dart';
import '../utils/app_runtime_identity.dart' as runtime;
import '../utils/file_integrity.dart';
import 'app_diagnostics.dart';

enum AppUpdateDownloadPhase { resolving, transferring, verifying }

class _TransientUpdateDownload extends HttpException {
  const _TransientUpdateDownload(super.message);
}

class AppUpdateCheck {
  final AppUpdateRelease? release;
  final String? etag;
  final Map<String, dynamic>? response;
  const AppUpdateCheck({required this.release, this.etag, this.response});
}

class AppUpdateService {
  static final latestEndpoint = Uri.parse(
    '$valhallaDistributionUrl/api/v1/app/latest',
  );
  static const cacheSource = 'yggdrasil-v2';
  final HttpClient Function() clientFactory;
  HttpClient? _downloadClient;
  bool _canceled = false;
  Timer? _retryTimer;
  Completer<void>? _retryWaiter;
  AppUpdateService({HttpClient Function()? clientFactory})
    : clientFactory = clientFactory ?? HttpClient.new;

  static bool _allowedDownload(Uri uri, {required bool download}) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (uri.port == 443) &&
      !uri.hasFragment &&
      (uri.host == latestEndpoint.host &&
              (download
                  ? _distributionDownload(uri)
                  : uri.path == latestEndpoint.path &&
                        uri.queryParametersAll['app_id']?.singleOrNull ==
                            valhallaDistributionAppId) ||
          download &&
              (uri.host == 'github.com' ||
                  uri.host == 'api.github.com' ||
                  uri.host.endsWith('.githubusercontent.com')));

  static String distributionArchitecture(
    String platform,
    String architecture,
  ) => runtime.distributionArchitecture(platform, architecture);

  static bool isCurrentCache(Map<String, dynamic>? cache) =>
      cache?['source'] == cacheSource;

  Future<HttpClientResponse> _get(
    HttpClient client,
    Uri uri, {
    Map<String, String> headers = const {},
    bool download = false,
  }) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (!_allowedDownload(uri, download: download)) {
        throw const FormatException('UPDATE_URL_INVALID');
      }
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Valhalla-App-Updater');
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const FormatException('UPDATE_REDIRECT_INVALID');
        }
        uri = uri.resolve(location);
        await response.drain<void>().timeout(const Duration(seconds: 30));
        continue;
      }
      return response;
    }
    throw const FormatException('UPDATE_REDIRECT_LIMIT');
  }

  Future<String> _body(HttpClientResponse response, int maxBytes) async {
    var size = 0;
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      size += chunk.length;
      if (size > maxBytes) {
        throw const FormatException('UPDATE_RESPONSE_TOO_LARGE');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<AppUpdateCheck> check({
    String? etag,
    Map<String, dynamic>? cached,
    int currentVersionCode = 0,
    String channel = 'default',
    String platform = 'android',
    String architecture = 'arm64-v8a',
  }) async {
    final arch = distributionArchitecture(platform, architecture);
    if (currentVersionCode < 0 ||
        !_validChannel(channel) ||
        !_validChannel(platform) ||
        !_validChannel(arch)) {
      throw const FormatException('UPDATE_RELEASE_INVALID');
    }
    final endpoint = latestEndpoint.replace(
      queryParameters: {
        'app_id': valhallaDistributionAppId,
        'version_code': '$currentVersionCode',
        'channel': channel,
        'platform': platform,
        'arch': arch,
      },
    );
    final reusable =
        cached?['_source'] == cacheSource &&
        cached?['_channel'] == channel &&
        cached?['_platform'] == platform &&
        cached?['_arch'] == arch &&
        cached?['_version_code'] == currentVersionCode;
    final client = clientFactory();
    final elapsed = Stopwatch()..start();
    var outcome = 'failed';
    try {
      final response = await _get(
        client,
        endpoint,
        headers: {
          'Accept': 'application/json',
          if (etag != null && reusable) 'If-None-Match': etag,
        },
      );
      if (response.statusCode == 404) {
        outcome = 'no_release';
        return const AppUpdateCheck(release: null);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('UPDATE_CHECK_AUTH_FAILED: ${response.statusCode}');
      }
      if (response.statusCode == 429) {
        throw StateError('UPDATE_RATE_LIMITED');
      }
      final Map<String, dynamic> release;
      if (response.statusCode == 304 && reusable) {
        release = cached!;
      } else if (response.statusCode == 200) {
        final body = jsonDecode(await _body(response, 2 * 1024 * 1024));
        if (body is! Map<String, dynamic>) {
          throw const FormatException('UPDATE_RELEASE_INVALID');
        }
        release = body;
      } else {
        throw HttpException('UPDATE_CHECK_FAILED: ${response.statusCode}');
      }
      final parsed = parseRelease(release);
      final data = release['data'] as Map<String, dynamic>;
      if (data['channel'] != channel && data['channel'] != 'default' ||
          currentVersionCode > 0 &&
              data['current_version_code'] != currentVersionCode) {
        throw const FormatException('UPDATE_RELEASE_INVALID');
      }
      outcome = 'completed';
      return AppUpdateCheck(
        release: parsed,
        etag:
            response.headers.value(HttpHeaders.etagHeader) ??
            (reusable && response.statusCode == 304 ? etag : null),
        response: {
          ...release,
          '_source': cacheSource,
          '_channel': channel,
          '_version_code': currentVersionCode,
          '_platform': platform,
          '_arch': arch,
        },
      );
    } finally {
      client.close(force: true);
      unawaited(
        AppDiagnostics.instance.recordTiming(
          'updates.check',
          elapsed,
          outcome: outcome,
        ),
      );
    }
  }

  static bool _validChannel(String channel) =>
      RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(channel);

  static bool _distributionDownload(Uri uri) {
    final query = uri.queryParametersAll;
    final code = query['version_code']?.singleOrNull;
    return uri.scheme == 'https' &&
        uri.host == latestEndpoint.host &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        uri.path == '/api/v1/app/download' &&
        query.keys.every(
          {
            'app_id',
            'version_code',
            'channel',
            'platform',
            'arch',
            'package_id',
          }.contains,
        ) &&
        query.values.every((values) => values.length == 1) &&
        query['app_id']?.singleOrNull == valhallaDistributionAppId &&
        RegExp(r'^[1-9]\d*$').hasMatch(code ?? '') &&
        _validChannel(query['channel']?.singleOrNull ?? '') &&
        ['platform', 'arch', 'package_id'].every(
          (key) => !query.containsKey(key) || _validChannel(query[key]!.single),
        );
  }

  static AppUpdateRelease parseRelease(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['code'] != 0 ||
        data is! Map<String, dynamic> ||
        data['app_id'] != valhallaDistributionAppId ||
        data['latest_version_code'] is! int ||
        (data['latest_version_code'] as int) <= 0 ||
        data['latest_version_name'] is! String ||
        data['download_url'] is! String ||
        data['file_name'] is! String ||
        data['changelog'] != null && data['changelog'] is! String ||
        data['has_update'] is! bool ||
        data['is_force'] is! bool ||
        data['channel'] is! String ||
        !_validChannel(data['channel'] as String)) {
      throw const FormatException('UPDATE_RELEASE_INVALID');
    }
    final versionName = data['latest_version_name'] as String;
    final identity = RegExp(
      r'^v?(\d+\.\d+\.\d+)(?:\+(\d+))?$',
    ).firstMatch(versionName);
    if (identity == null) throw const FormatException('UPDATE_VERSION_INVALID');
    final version = identity[1]!;
    int? build = identity[2] == null ? null : int.tryParse(identity[2]!);
    if (identity[2] != null && build == null) {
      throw const FormatException('UPDATE_VERSION_INVALID');
    }
    final code = data['latest_version_code'] as int;
    final channel = data['channel'] as String;
    final notes = data['changelog'] as String? ?? '';
    final packages = data['packages'];
    if (packages != null && (packages is! List || packages.length > 64)) {
      throw const FormatException('UPDATE_RELEASE_INVALID');
    }
    final entries = packages is List && packages.isNotEmpty ? packages : [data];
    final artifacts = <AppUpdateArtifact>[];
    final ids = <String>{};
    final targets = <String>{};
    if (entries.length > 1 && build == null) {
      throw const FormatException('UPDATE_VERSION_INVALID');
    }
    for (final entry in entries) {
      if (entry is! Map<String, dynamic> ||
          entry['app_id'] != null &&
              entry['app_id'] != valhallaDistributionAppId) {
        throw const FormatException('UPDATE_RELEASE_INVALID');
      }
      final id = entry['id'];
      final legacy =
          identical(entry, data) || id is String && id.startsWith('pkg_def_');
      if (legacy && entries.length != 1) {
        throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
      }
      if (!legacy && (id is! String || !_validChannel(id) || !ids.add(id))) {
        throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
      }
      final uri = Uri.tryParse(
        entry['download_url'] is String ? entry['download_url'] as String : '',
      );
      if (uri == null ||
          !_distributionDownload(uri) ||
          uri.queryParameters['version_code'] != '$code' ||
          uri.queryParameters['channel'] != channel ||
          !legacy && uri.queryParameters['package_id'] != id) {
        throw const FormatException('UPDATE_ASSET_URL_INVALID');
      }
      final name = entry['file_name'] is String
          ? entry['file_name'] as String
          : '';
      if (name.isEmpty ||
          name.length > 255 ||
          name.contains('/') ||
          name.contains('\\') ||
          name.contains('..') ||
          name.runes.any((r) => r < 32 || r == 127)) {
        throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
      }
      final apk = RegExp(
        r'^valhalla-v?(\d+\.\d+\.\d+)-android-(armeabi-v7a|arm64-v8a|x86_64)(?:-signed-(\d+))?\.apk$',
        caseSensitive: false,
      ).firstMatch(name);
      final desktop = RegExp(
        r'^valhalla-v?(\d+\.\d+\.\d+)-(windows|linux|macos)-(x64|arm64|universal)\.(zip|tar\.gz)$',
        caseSensitive: false,
      ).firstMatch(name);
      if (apk != null || desktop != null) {
        final platform = apk != null ? 'android' : desktop![2]!.toLowerCase();
        final arch = (apk?[2] ?? desktop![3]!).toLowerCase();
        if (!targets.add('$platform/$arch')) {
          throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
        }
        if (!legacy &&
                (entry['platform'] != platform ||
                    entry['arch'] !=
                        distributionArchitecture(platform, arch)) ||
            uri.queryParameters['platform'] != null &&
                uri.queryParameters['platform'] != platform ||
            uri.queryParameters['arch'] != null &&
                uri.queryParameters['arch'] !=
                    distributionArchitecture(platform, arch)) {
          throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
        }
        if (AppUpdateRelease.compareVersions(
                  apk?[1] ?? desktop![1]!,
                  version,
                ) !=
                0 ||
            platform == 'linux' && desktop![4] != 'tar.gz' ||
            {'windows', 'macos'}.contains(platform) && desktop![4] != 'zip' ||
            arch == 'universal' && platform != 'macos') {
          throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
        }
        build ??= apk != null ? code % 1000 : code;
        if (apk != null &&
            (build <= 0 ||
                build >= 1000 ||
                apk[3] != null && int.tryParse(apk[3]!) != build ||
                legacy &&
                    code !=
                        const {
                                  'armeabi-v7a': 1,
                                  'arm64-v8a': 2,
                                  'x86_64': 4,
                                }[arch]! *
                                1000 +
                            build)) {
          throw const FormatException('UPDATE_ANDROID_IDENTITY_INVALID');
        }
        final size = entry['file_size'];
        if (size is! int || size <= 0 || size > 4 * 1024 * 1024 * 1024) {
          throw const FormatException('UPDATE_ASSET_SIZE_INVALID');
        }
        final hashNotes = legacy ? notes : '';
        final markers = RegExp(r'\bSHA256:').allMatches(hashNotes).length;
        final matches = RegExp(
          r'\bSHA256:\s*([0-9a-fA-F]{64})(?![0-9a-zA-Z])',
        ).allMatches(hashNotes).toList();
        final hashes = matches.map((m) => m[1]!.toLowerCase()).toSet();
        final structured = entry['file_sha256'];
        // shortcut: legacy MCP records put SHA256 in changelog; remove when all publishers supply the structured field.
        final hash = structured ?? (hashes.length == 1 ? hashes.single : null);
        if (hash is! String ||
            !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash) ||
            markers != matches.length ||
            hashes.length > 1 ||
            hashes.isNotEmpty && !hashes.contains(hash.toLowerCase())) {
          throw const FormatException('UPDATE_MANIFEST_INVALID');
        }
        artifacts.add(
          AppUpdateArtifact(
            name: name,
            platform: platform,
            architecture: arch,
            size: size,
            sha256: hash.toLowerCase(),
            url: uri.replace(
              queryParameters: {
                ...uri.queryParameters,
                'platform': platform,
                'arch': distributionArchitecture(platform, arch),
              },
            ),
            androidVersionCode: apk != null
                ? const {'armeabi-v7a': 1, 'arm64-v8a': 2, 'x86_64': 4}[arch]! *
                          1000 +
                      build
                : null,
            androidCertificateSha256: apk != null
                ? valhallaReleaseCertificateSha256
                : null,
          ),
        );
      }
    }
    return AppUpdateRelease(
      version: version,
      buildNumber: build,
      notes: _boundedNotes(notes),
      page: Uri.parse(valhallaReleasesUrl),
      artifacts: List.unmodifiable(artifacts),
    );
  }

  // Bound selectable-text layout for platform-provided release notes.
  static String _boundedNotes(String notes) => notes.length <= 16 * 1024
      ? notes
      : '${String.fromCharCodes(notes.runes.take(16 * 1024))}\n…';

  Future<void> download(
    AppUpdateArtifact artifact,
    String destination, {
    required void Function(int) onProgress,
    void Function(AppUpdateDownloadPhase)? onPhase,
  }) async {
    if (!_distributionDownload(artifact.url)) {
      throw const FormatException('UPDATE_ASSET_URL_INVALID');
    }
    if (_downloadClient != null) {
      throw StateError('UPDATE_DOWNLOAD_IN_PROGRESS');
    }
    _canceled = false;
    final client = clientFactory();
    _downloadClient = client;
    final elapsed = Stopwatch()..start();
    var outcome = 'failed';
    var received = 0;
    final partial = File('$destination.part');
    final metadata = File('$destination.part.json');
    IOSink? sink;
    try {
      final identity = jsonEncode({
        'url': artifact.url.toString(),
        'size': artifact.size,
        'sha256': artifact.sha256,
      });
      if (await partial.exists() &&
          (!await metadata.exists() ||
              await metadata.readAsString() != identity ||
              await partial.length() > artifact.size)) {
        await partial.delete();
      }
      var offset = await partial.exists() ? await partial.length() : 0;
      received = offset;
      await metadata.writeAsString(identity, flush: true);
      var retries = 0;
      while (offset < artifact.size) {
        try {
          if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
          onPhase?.call(AppUpdateDownloadPhase.resolving);
          final response = await _get(
            client,
            artifact.url,
            headers: {if (offset > 0) 'Range': 'bytes=$offset-'},
            download: true,
          );
          if ({408, 429, 500, 502, 503, 504}.contains(response.statusCode)) {
            await response.drain<void>().timeout(const Duration(seconds: 30));
            throw _TransientUpdateDownload(
              'UPDATE_DOWNLOAD_FAILED: ${response.statusCode}',
            );
          }
          if (response.statusCode == 200) {
            offset = 0;
          } else if (response.statusCode != 206 ||
              offset == 0 ||
              response.headers.value('content-range') !=
                  'bytes $offset-${artifact.size - 1}/${artifact.size}') {
            throw HttpException(
              'UPDATE_DOWNLOAD_FAILED: ${response.statusCode}',
            );
          }
          sink = partial.openWrite(
            mode: offset > 0 ? FileMode.append : FileMode.write,
          );
          onPhase?.call(AppUpdateDownloadPhase.transferring);
          onProgress(offset);
          var unflushed = 0;
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
            offset += chunk.length;
            received = offset;
            if (offset > artifact.size) {
              throw StateError('UPDATE_DOWNLOAD_SIZE_MISMATCH');
            }
            sink.add(chunk);
            unflushed += chunk.length;
            if (unflushed >= 2 * 1024 * 1024) {
              await sink.flush();
              unflushed = 0;
            }
            onProgress(offset);
          }
          await sink.close();
          sink = null;
          if (offset != artifact.size) {
            throw const _TransientUpdateDownload('UPDATE_DOWNLOAD_INCOMPLETE');
          }
        } catch (error) {
          await sink?.close();
          sink = null;
          if (_canceled ||
              retries >= 2 ||
              !(error is SocketException ||
                  error is TimeoutException ||
                  error is _TransientUpdateDownload)) {
            rethrow;
          }
          offset = await partial.exists() ? await partial.length() : 0;
          received = offset;
          final waiter = _retryWaiter = Completer<void>();
          _retryTimer = Timer(Duration(seconds: ++retries), waiter.complete);
          try {
            await waiter.future;
          } finally {
            _retryTimer?.cancel();
            _retryTimer = null;
            _retryWaiter = null;
          }
        }
      }
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      onPhase?.call(AppUpdateDownloadPhase.verifying);
      if (await partial.length() != artifact.size ||
          await fileSha256(partial.path) != artifact.sha256) {
        await partial.delete();
        throw StateError('UPDATE_DOWNLOAD_INTEGRITY_FAILED');
      }
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      if (await File(destination).exists()) {
        throw StateError('UPDATE_DESTINATION_EXISTS');
      }
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      await partial.rename(destination);
      outcome = 'completed';
      try {
        await metadata.delete();
      } on FileSystemException {
        /* Completed file is already verified. */
      }
    } finally {
      await sink?.close();
      client.close(force: true);
      _downloadClient = null;
      unawaited(
        AppDiagnostics.instance.recordTiming(
          'updates.download',
          elapsed,
          outcome: _canceled ? 'cancelled' : outcome,
          count: received,
        ),
      );
    }
  }

  void cancelDownload() {
    _canceled = true;
    final waiter = _retryWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _downloadClient?.close(force: true);
  }

  void dispose() => cancelDownload();
}
