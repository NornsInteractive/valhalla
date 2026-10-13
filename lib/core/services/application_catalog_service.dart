import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/application_center.dart';
import 'application_compose_service.dart';

class ApplicationCatalogService {
  final Future<Directory> Function()? directoryProvider;
  final HttpClient Function() clientFactory;
  final _images = <String, Future<File>>{};
  // Resource records carry source IDs only; retain the configured URL for trust.
  final _sourceUrls = <String, Uri>{};
  ApplicationCatalogService({
    this.directoryProvider,
    HttpClient Function()? clientFactory,
  }) : clientFactory = clientFactory ?? HttpClient.new;

  static Uri sourceUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/');
  }

  /// Store /apps paths are relative to the published store prefix, not host root.
  static Uri resourceUri(Uri base, String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        value.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasFragment ||
        value.contains('\\')) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    final uri = parsed.hasScheme
        ? parsed
        : base.resolve(value.replaceFirst(RegExp(r'^/+'), ''));
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    return uri;
  }

  Future<File> _cache(ApplicationSource source, String locale) async {
    final root = directoryProvider == null
        ? await getApplicationSupportDirectory()
        : await directoryProvider!();
    final directory = Directory('${root.path}/application_catalog');
    await directory.create(recursive: true);
    final key = sha256.convert(
      utf8.encode('${source.id}|${sourceUri(source.url)}|$locale'),
    );
    return File('${directory.path}/$key.json');
  }

  Future<List<CatalogApplication>> cached(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async {
    try {
      _sourceUrls[source.id] = sourceUri(source.url);
      final file = await _cache(source, locale);
      if (!await file.exists() || await file.length() > 6 * 1024 * 1024) {
        return [];
      }
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (data['apps'] as List)
          .map(
            (j) => CatalogApplication.fromJson(
              Map<String, dynamic>.from(j as Map),
            ),
          )
          .where((app) => app.sourceId == source.id)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> cachedAt(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async {
    try {
      final file = await _cache(source, locale);
      if (!await file.exists() || await file.length() > 6 * 1024 * 1024) {
        return null;
      }
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final row in data['apps'] as List) {
        final app = CatalogApplication.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (app.sourceId != source.id) return null;
      }
      return DateTime.tryParse(data['at'] as String? ?? '')?.toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<({String text, String? etag, Uri uri, bool unchanged})> _get(
    Uri uri, {
    String? etag,
    Uri? etagUri,
    String? sourceId,
    int maxBytes = 4 * 1024 * 1024,
    bool allowMissing = false,
  }) async {
    final result = await _getBytes(
      uri,
      etag: etag,
      etagUri: etagUri,
      sourceId: sourceId,
      maxBytes: maxBytes,
      allowMissing: allowMissing,
    );
    try {
      return (
        text: utf8.decode(result.bytes),
        etag: result.etag,
        uri: result.uri,
        unchanged: result.unchanged,
      );
    } on FormatException {
      throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
    }
  }

  Uri? _fallbackUri(Uri uri, String? sourceId) {
    const prefix = '/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/';
    if (sourceId != ApplicationSource.official.id ||
        _sourceUrls[sourceId] != sourceUri(ApplicationSource.official.url) ||
        uri.scheme != 'https' ||
        uri.host != 'cdn.jsdelivr.net' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith(prefix) ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri.replace(
      host: 'raw.githubusercontent.com',
      path: '/IceWhaleTech/CasaOS-AppStore/gh-pages/'
          '${uri.path.substring(prefix.length)}',
    );
  }

  Future<({Uint8List bytes, String? etag, Uri uri, bool unchanged})> _getBytes(
    Uri uri, {
    String? etag,
    Uri? etagUri,
    String? sourceId,
    int maxBytes = 4 * 1024 * 1024,
    bool allowMissing = false,
  }) async {
    try {
      return await _requestBytes(
        uri,
        etag: etagUri == uri ? etag : null,
        maxBytes: maxBytes,
        allowMissing: allowMissing,
      );
    } on ApplicationCenterException catch (error) {
      final fallback = _fallbackUri(uri, sourceId);
      final status = int.tryParse(error.detail ?? '');
      final retryable = const {
            'APP_CENTER_SOURCE_DNS',
            'APP_CENTER_SOURCE_TIMEOUT',
            'APP_CENTER_SOURCE_NETWORK',
          }.contains(error.code) ||
          (error.code == 'APP_CENTER_SOURCE_UNAVAILABLE' &&
              status != null &&
              status >= 500 &&
              status < 600);
      if (fallback == null || !retryable) rethrow;
      return _requestBytes(
        fallback,
        etag: etagUri == fallback ? etag : null,
        maxBytes: maxBytes,
        allowMissing: allowMissing,
      );
    }
  }

  Future<({Uint8List bytes, String? etag, Uri uri, bool unchanged})>
  _requestBytes(
    Uri uri, {
    String? etag,
    int maxBytes = 4 * 1024 * 1024,
    bool allowMissing = false,
  }) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.host.isEmpty) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    final client = clientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var redirects = 0; redirects <= 4; redirects++) {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        if (etag != null) {
          request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
        }
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) break;
          final next = uri.resolve(location);
          if (next.scheme != 'https' ||
              next.userInfo.isNotEmpty ||
              next.host.isEmpty) {
            break;
          }
          uri = next;
          etag = null;
          continue;
        }
        if (response.statusCode == 304) {
          if (etag == null) {
            throw const ApplicationCenterException(
              'APP_CENTER_SOURCE_UNAVAILABLE',
              '304',
            );
          }
          return (bytes: Uint8List(0), etag: etag, uri: uri, unchanged: true);
        }
        if (response.statusCode == 404 && allowMissing) {
          return (bytes: Uint8List(0), etag: null, uri: uri, unchanged: false);
        }
        if (response.statusCode != 200) {
          throw ApplicationCenterException(
            'APP_CENTER_SOURCE_UNAVAILABLE',
            '${response.statusCode}',
          );
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 20),
        )) {
          bytes.add(chunk);
          if (bytes.length > maxBytes) {
            throw const ApplicationCenterException(
              'APP_CENTER_CATALOG_TOO_LARGE',
            );
          }
        }
        return (
          bytes: bytes.takeBytes(),
          etag: response.headers.value(HttpHeaders.etagHeader),
          uri: uri,
          unchanged: false,
        );
      }
      throw const ApplicationCenterException('APP_CENTER_SOURCE_UNAVAILABLE');
    } on TlsException {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_TLS');
    } on TimeoutException {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_TIMEOUT');
    } on SocketException catch (error) {
      final message = error.message.toLowerCase();
      final isDns = message.contains('host lookup') ||
          message.contains('name or service not known') ||
          message.contains('nodename nor servname') ||
          message.contains('name resolution');
      throw ApplicationCenterException(
        isDns ? 'APP_CENTER_SOURCE_DNS' : 'APP_CENTER_SOURCE_NETWORK',
      );
    } on HttpException {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_NETWORK');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<CatalogApplication>> refresh(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async {
    if (!RegExp(r'^[a-z]{2,3}_[A-Z]{2}$').hasMatch(locale)) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    final base = sourceUri(source.url);
    _sourceUrls[source.id] = base;
    final store = _decodeJson(
      (await _get(
        base.resolve('store.json'),
        sourceId: source.id,
        maxBytes: 256 * 1024,
      )).text,
    );
    if (store is! Map ||
        store['version'] != 2 ||
        store['store_id'] is! String) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_UNSUPPORTED');
    }
    final file = await _cache(source, locale);
    Map<String, dynamic>? old;
    try {
      if (await file.exists() && await file.length() < 6 * 1024 * 1024) {
        old = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final row in old['apps'] as List) {
          CatalogApplication.fromJson(Map<String, dynamic>.from(row as Map));
        }
      }
    } catch (_) {
      old = null;
    }
    var response = await _get(
      base.resolve('index.$locale.json'),
      etag: old?['etag'] as String?,
      etagUri: Uri.tryParse(old?['etagUri'] as String? ?? ''),
      sourceId: source.id,
      allowMissing: true,
    );
    if (response.text.isEmpty && !response.unchanged) {
      response = await _get(
        base.resolve('index.json'),
        etag: old?['etag'] as String?,
        etagUri: Uri.tryParse(old?['etagUri'] as String? ?? ''),
        sourceId: source.id,
      );
    }
    if (response.unchanged && old != null) {
      final temporary = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      await temporary.writeAsString(
        jsonEncode({...old, 'at': DateTime.now().toUtc().toIso8601String()}),
        flush: true,
      );
      await temporary.rename(file.path);
      return cached(source, locale: locale);
    }
    String? localization;
    final localizedText = response.text;
    final isFragment = await Isolate.run(() {
      final index = _decodeJson(localizedText);
      return index is Map &&
          !index.containsKey('version') &&
          index['apps'] is List;
    });
    if (isFragment) {
      localization = response.text;
      final canonical = await _get(
        base.resolve('index.json'),
        sourceId: source.id,
      );
      // A translation fragment's ETag cannot validate the canonical catalog.
      response = (
        text: canonical.text,
        etag: null,
        uri: canonical.uri,
        unchanged: false,
      );
    }
    final text = response.text;
    final apps = await Isolate.run(
      () => parseIndex(text, source, localization: localization),
    );
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString(
      jsonEncode({
        'etag': response.etag,
        'etagUri': response.uri.toString(),
        'at': DateTime.now().toUtc().toIso8601String(),
        'apps': apps.map((a) => a.toJson()).toList(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
    return apps;
  }

  static List<CatalogApplication> parseIndex(
    String text,
    ApplicationSource source, {
    String? localization,
  }) {
    final value = _decodeJson(text);
    if (value is! Map || value['version'] != 2 || value['apps'] is! List) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_UNSUPPORTED');
    }
    final rows = value['apps'] as List;
    if (rows.length > 10000) {
      throw const ApplicationCenterException('APP_CENTER_CATALOG_TOO_LARGE');
    }
    final base = sourceUri(source.url);
    final translations = <String, Map>{};
    if (localization != null) {
      final overlay = _decodeJson(localization);
      if (overlay is! Map ||
          overlay['apps'] is! List ||
          (overlay['apps'] as List).length > 10000) {
        throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
      }
      for (final row in overlay['apps'] as List) {
        if (row is! Map ||
            row['id'] is! String ||
            translations.containsKey(row['id']) ||
            [
              'title',
              'tagline',
            ].any((key) => row.containsKey(key) && row[key] is! String)) {
          throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
        }
        translations[row['id'] as String] = row;
      }
    }
    final seen = <String>{};
    final result = <CatalogApplication>[];
    for (final row in rows) {
      if (row is! Map) {
        throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
      }
      final id = row['id'];
      if (id is! String ||
          !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,159}$').hasMatch(id) ||
          !seen.add(id) ||
          row['title'] is! String ||
          row['compose_url'] is! String) {
        throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
      }
      String resource(String key) =>
          row[key] is String && (row[key] as String).isNotEmpty
          ? resourceUri(base, row[key] as String).toString()
          : '';
      String translated(String key, String fallback) {
        final value = translations[id]?[key] as String?;
        return value == null || value.trim().isEmpty ? fallback : value;
      }

      result.add(
        CatalogApplication(
          sourceId: source.id,
          id: id,
          title: translated('title', row['title'] as String),
          summary: translated('tagline', row['tagline'] as String? ?? ''),
          category: row['category'] as String? ?? 'Others',
          version: row['version'] as String? ?? '',
          contentHash: row['content_hash'] as String? ?? '',
          iconUrl: resource('icon'),
          thumbnailUrl: resource('thumbnail'),
          composeUrl: resource('compose_url'),
          metadataUrl: resource('meta_url'),
          architectures: (row['architectures'] as List? ?? [])
              .whereType<String>()
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<ApplicationTemplate> template(CatalogApplication app) async {
    final root = directoryProvider == null
        ? await getApplicationSupportDirectory()
        : await directoryProvider!();
    final key = sha256.convert(
      utf8.encode(
        '${app.key}|${app.composeUrl}|${app.metadataUrl}|${app.contentHash}',
      ),
    );
    final cache = File('${root.path}/application_catalog/$key.template');
    try {
      if (await cache.exists() &&
          await cache.length() <= 3 * 1024 * 1024 &&
          DateTime.now().difference((await cache.stat()).modified) <
              const Duration(days: 1)) {
        final saved =
            jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
        final compose = Map<String, dynamic>.from(saved['compose'] as Map);
        return ApplicationTemplate(
          application: app,
          compose: compose,
          metadata: Map<String, dynamic>.from(saved['metadata'] as Map),
          variables: ApplicationComposeService.variables(compose),
          blockers: ApplicationComposeService.blockers(compose),
        );
      }
    } catch (_) {
      /* Fetch again when a local cache is damaged. */
    }
    final content = await _get(
      Uri.parse(app.composeUrl),
      sourceId: app.sourceId,
      maxBytes: 1024 * 1024,
    );
    final compose = await Isolate.run(
      () => ApplicationComposeService.parse(content.text),
    );
    Map<String, dynamic> metadata = {};
    if (app.metadataUrl.isNotEmpty) {
      final decoded = _decodeJson(
        (await _get(
          Uri.parse(app.metadataUrl),
          sourceId: app.sourceId,
          maxBytes: 1024 * 1024,
        )).text,
      );
      if (decoded is! Map<String, dynamic>) {
        throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
      }
      metadata = decoded;
      final composeUri = Uri.parse(app.composeUrl);
      final prefix = composeUri.path.indexOf('/apps/');
      final base = prefix < 0
          ? composeUri.resolve('./')
          : composeUri.replace(
              path: composeUri.path.substring(0, prefix + 1),
              query: null,
              fragment: null,
            );
      final screenshots = (metadata['screenshot_link'] as List? ?? [])
          .whereType<String>()
          .map(
            (s) => resourceUri(
              s.startsWith('/') ? base : composeUri.resolve('./'),
              s,
            ).toString(),
          )
          .toList();
      metadata = {...metadata, 'screenshot_link': screenshots};
    }
    await cache.parent.create(recursive: true);
    await _prune(
      cache.parent,
      '.template',
      32 * 1024 * 1024,
      100,
      utf8
          .encode(jsonEncode({'compose': compose, 'metadata': metadata}))
          .length,
    );
    final temporary = File(
      '${cache.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString(
      jsonEncode({'compose': compose, 'metadata': metadata}),
      flush: true,
    );
    await temporary.rename(cache.path);
    return ApplicationTemplate(
      application: app,
      compose: compose,
      metadata: metadata,
      variables: ApplicationComposeService.variables(compose),
      blockers: ApplicationComposeService.blockers(compose),
    );
  }

  Future<File> image(
    String url, {
    String revision = '',
    String? sourceId,
  }) {
    final key = sha256.convert(utf8.encode('$url|$revision')).toString();
    return _images.putIfAbsent(
      '$sourceId|$key',
      () => _image(url, key, sourceId: sourceId).whenComplete(() {
        _images.remove('$sourceId|$key');
      }),
    );
  }

  Future<File> _image(String url, String key, {String? sourceId}) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    final root = directoryProvider == null
        ? await getApplicationSupportDirectory()
        : await directoryProvider!();
    final directory = Directory('${root.path}/application_catalog/images');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$key.asset');
    if (await file.exists() &&
        await file.length() <= 2 * 1024 * 1024 &&
        DateTime.now().difference((await file.stat()).modified) <
            const Duration(days: 7)) {
      return file;
    }
    final bytes = (await _getBytes(
      uri,
      sourceId: sourceId,
      maxBytes: 2 * 1024 * 1024,
    )).bytes;
    await _prune(directory, '.asset', 96 * 1024 * 1024, 300, bytes.length);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
    return file;
  }

  Future<void> _prune(
    Directory directory,
    String suffix,
    int maxBytes,
    int maxFiles,
    int incoming,
  ) async {
    final files = <(File, FileStat)>[];
    var size = incoming;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith(suffix)) {
        final stat = await entity.stat();
        files.add((entity, stat));
        size += stat.size;
      }
    }
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var count = files.length + 1;
    for (final old in files) {
      if (size <= maxBytes && count <= maxFiles) break;
      if (await old.$1.exists()) await old.$1.delete();
      size -= old.$2.size;
      count--;
    }
  }

  static dynamic _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const ApplicationCenterException('APP_CENTER_CATALOG_INVALID');
    }
  }
}
