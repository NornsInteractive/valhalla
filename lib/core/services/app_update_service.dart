import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import '../../data/models/app_update.dart';

class AppUpdateCheck {
  final AppUpdateRelease? release;
  final String? etag;
  final Map<String, dynamic>? response;
  const AppUpdateCheck({required this.release, this.etag, this.response});
}

class AppUpdateService {
  static final latestEndpoint = Uri.parse(
    'https://api.github.com/repos/NornsInteractive/valhalla/releases/latest');
  final HttpClient Function() clientFactory;
  HttpClient? _downloadClient;
  bool _canceled = false;
  AppUpdateService({HttpClient Function()? clientFactory})
      : clientFactory = clientFactory ?? HttpClient.new;

  static bool _allowedDownload(Uri uri) => uri.scheme == 'https' &&
    uri.userInfo.isEmpty && (uri.port == 443) &&
    (uri.host == 'github.com' || uri.host == 'api.github.com' ||
      uri.host.endsWith('.githubusercontent.com'));

  Future<HttpClientResponse> _get(HttpClient client, Uri uri,
      {Map<String, String> headers = const {}}) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (!_allowedDownload(uri)) throw const FormatException('UPDATE_URL_INVALID');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Valhalla-App-Updater');
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(const Duration(seconds: 20));
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw const FormatException('UPDATE_REDIRECT_INVALID');
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
      if (size > maxBytes) throw const FormatException('UPDATE_RESPONSE_TOO_LARGE');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<AppUpdateCheck> check({String? etag, Map<String, dynamic>? cached}) async {
    final client = clientFactory();
    try {
      final response = await _get(client, latestEndpoint, headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2026-03-10',
        if (etag != null && cached != null) 'If-None-Match': etag,
      });
      if (response.statusCode == 404) return const AppUpdateCheck(release: null);
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw StateError('UPDATE_RATE_LIMITED');
      }
      final Map<String, dynamic> release;
      if (response.statusCode == 304 && cached != null) {
        release = cached;
      } else if (response.statusCode == 200) {
        release = jsonDecode(await _body(response, 2 * 1024 * 1024)) as Map<String, dynamic>;
      } else {
        throw HttpException('UPDATE_CHECK_FAILED: ${response.statusCode}');
      }
      if (release['draft'] != false || release['prerelease'] != false) {
        throw const FormatException('UPDATE_RELEASE_INVALID');
      }
      final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
      final manifest = assets.where((a) => a['name'] == 'update.json').firstOrNull;
      Map<String, dynamic>? metadata;
      if (manifest != null) {
        final result = await _get(client, _assetUrl(manifest, release['tag_name'] as String));
        if (result.statusCode != 200) throw StateError('UPDATE_MANIFEST_FAILED');
        metadata = jsonDecode(await _body(result, 256 * 1024)) as Map<String, dynamic>;
      }
      return AppUpdateCheck(release: parseRelease(release, metadata),
        etag: response.headers.value(HttpHeaders.etagHeader) ?? etag,
        response: {...release, '_valhalla_manifest': ?metadata});
    } finally {
      client.close(force: true);
    }
  }

  static Uri _assetUrl(Map<String, dynamic> asset, String tag) {
    final uri = Uri.parse(asset['browser_download_url'] as String);
    if (!_allowedDownload(uri) || uri.host != 'github.com' || uri.hasQuery ||
        uri.pathSegments.length != 6 ||
        uri.pathSegments.take(4).join('/') != 'NornsInteractive/valhalla/releases/download' ||
        uri.pathSegments[4] != tag || uri.pathSegments.last != asset['name']) {
      throw const FormatException('UPDATE_ASSET_URL_INVALID');
    }
    return uri;
  }

  static AppUpdateRelease parseRelease(Map<String, dynamic> release,
      Map<String, dynamic>? metadata) {
    final tag = release['tag_name'] as String;
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    AppUpdateRelease.compareVersions(version, version);
    final page = Uri.parse(release['html_url'] as String);
    if (page.toString() != '$valhallaRepositoryUrl/releases/tag/${Uri.encodeComponent(tag)}') {
      throw const FormatException('UPDATE_RELEASE_URL_INVALID');
    }
    if (metadata != null && (metadata['schemaVersion'] != 1 ||
        metadata['version'] != version || metadata['buildNumber'] is! int ||
        (metadata['buildNumber'] as int) <= 0 ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(metadata['sourceCommit'] as String? ?? ''))) {
      throw const FormatException('UPDATE_MANIFEST_INVALID');
    }
    final artifacts = <AppUpdateArtifact>[];
    final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
    final entries = metadata?['artifacts'] as List?;
    for (final asset in assets) {
      final name = asset['name'] as String;
      Map<String, dynamic>? entry;
      if (entries != null) {
        entry = entries.cast<Map<String, dynamic>>().where((e) => e['name'] == name).firstOrNull;
        if (entry == null) continue;
      }
      String? platform = entry?['platform'] as String?;
      String? arch = entry?['architecture'] as String?;
      if (entry == null) {
        final match = RegExp(r'^Valhalla-v?\d+\.\d+\.\d+-android-(armeabi-v7a|arm64-v8a|x86_64)\.apk$').firstMatch(name);
        if (match != null) { platform = 'android'; arch = match[1]; }
        else if (name.endsWith('-windows-x64.zip')) { platform = 'windows'; arch = 'x64'; }
        else if (name.endsWith('-linux-x64.tar.gz')) { platform = 'linux'; arch = 'x64'; }
        else if (name.endsWith('-macos-universal.zip')) { platform = 'macos'; arch = 'universal'; }
        else { continue; }
      }
      final hash = entry?['sha256'] as String? ??
        (asset['digest'] as String? ?? '').replaceFirst('sha256:', '');
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) continue;
      final size = asset['size'] as int;
      if (size <= 0 || size > 4 * 1024 * 1024 * 1024 ||
          entry != null && entry['size'] != size) {
        throw const FormatException('UPDATE_ASSET_SIZE_INVALID');
      }
      const supported = {'android': {'armeabi-v7a', 'arm64-v8a', 'x86_64'},
        'windows': {'x64', 'arm64'}, 'linux': {'x64', 'arm64'},
        'macos': {'universal', 'x64', 'arm64'}};
      if (supported[platform]?.contains(arch) != true ||
          artifacts.any((a) => a.platform == platform && a.architecture == arch)) {
        throw const FormatException('UPDATE_ASSET_IDENTITY_INVALID');
      }
      final assetDigest = asset['digest'] as String?;
      if (assetDigest != null && assetDigest != 'sha256:$hash') {
        throw const FormatException('UPDATE_ASSET_DIGEST_MISMATCH');
      }
      if (platform == 'android' && entry != null &&
          (entry['androidVersionCode'] is! int ||
          (entry['androidVersionCode'] as int) <= 0 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry['androidCertificateSha256'] as String? ?? ''))) {
        throw const FormatException('UPDATE_ANDROID_IDENTITY_INVALID');
      }
      artifacts.add(AppUpdateArtifact(name: name, platform: platform!,
        architecture: arch!, size: size, sha256: hash, url: _assetUrl(asset, tag),
        androidVersionCode: entry?['androidVersionCode'] as int?,
        androidCertificateSha256: entry?['androidCertificateSha256'] as String?));
    }
    return AppUpdateRelease(version: version, buildNumber: metadata?['buildNumber'] as int?,
      sourceCommit: metadata?['sourceCommit'] as String?,
      notes: _boundedNotes(release['body'] as String? ?? ''),
      page: page, artifacts: List.unmodifiable(artifacts));
  }

  // Full notes remain available on the release page; bound selectable-text layout.
  static String _boundedNotes(String notes) => notes.length <= 16 * 1024
      ? notes : '${String.fromCharCodes(notes.runes.take(16 * 1024))}\n…';

  Future<void> download(AppUpdateArtifact artifact, String destination,
      {required void Function(int) onProgress}) async {
    if (_downloadClient != null) throw StateError('UPDATE_DOWNLOAD_IN_PROGRESS');
    _canceled = false;
    final client = clientFactory();
    _downloadClient = client;
    final partial = File('$destination.part');
    final metadata = File('$destination.part.json');
    IOSink? sink;
    try {
      final identity = jsonEncode({'url': artifact.url.toString(), 'size': artifact.size,
        'sha256': artifact.sha256});
      if (await partial.exists() && (!await metadata.exists() ||
          await metadata.readAsString() != identity || await partial.length() > artifact.size)) {
        await partial.delete();
      }
      var offset = await partial.exists() ? await partial.length() : 0;
      await metadata.writeAsString(identity, flush: true);
      if (offset < artifact.size) {
        final response = await _get(client, artifact.url,
          headers: {if (offset > 0) 'Range': 'bytes=$offset-'});
        if (response.statusCode == 200) { offset = 0; }
        else if (response.statusCode != 206 || offset == 0 ||
            response.headers.value('content-range') != 'bytes $offset-${artifact.size - 1}/${artifact.size}') {
          throw HttpException('UPDATE_DOWNLOAD_FAILED: ${response.statusCode}');
        }
        sink = partial.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
        onProgress(offset);
        var unflushed = 0;
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
          offset += chunk.length;
          if (offset > artifact.size) throw StateError('UPDATE_DOWNLOAD_SIZE_MISMATCH');
          sink.add(chunk);
          unflushed += chunk.length;
          if (unflushed >= 256 * 1024) {
            await sink.flush();
            unflushed = 0;
          }
          onProgress(offset);
        }
        await sink.close();
        sink = null;
      }
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      if (await partial.length() != artifact.size ||
          (await sha256.bind(partial.openRead()).first).toString() != artifact.sha256) {
        await partial.delete();
        throw StateError('UPDATE_DOWNLOAD_INTEGRITY_FAILED');
      }
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      if (await File(destination).exists()) throw StateError('UPDATE_DESTINATION_EXISTS');
      if (_canceled) throw StateError('UPDATE_DOWNLOAD_CANCELED');
      await partial.rename(destination);
      try { await metadata.delete(); } on FileSystemException { /* Completed file is already verified. */ }
    } finally {
      await sink?.close();
      client.close(force: true);
      _downloadClient = null;
    }
  }

  void cancelDownload() { _canceled = true; _downloadClient?.close(force: true); }
  void dispose() => cancelDownload();
}
