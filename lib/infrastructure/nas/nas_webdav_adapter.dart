import 'dart:convert';
import 'dart:io';

import 'package:xml/xml_events.dart';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import 'nas_http_client.dart';

class NasWebDavAdapter extends NasSourceAdapter {
  @override
  final NasSource source;
  final NasHttpClient _http;
  final Uri _endpoint;
  final bool _publicOriginal;
  NasWebDavAdapter(this.source, NasCredentials credentials)
    : _publicOriginal =
          source.username.isEmpty &&
          credentials.password.isEmpty &&
          credentials.token.isEmpty,
      _endpoint = nasHttpEndpoint(source.endpoint),
      _http = NasHttpClient(
        nasHttpEndpoint(source.endpoint),
        username: source.username,
        password: credentials.password,
        headers: {
          if (source.forwardedHost != null) 'Host': source.forwardedHost!,
        },
      );

  Uri get _root => _endpoint.replace(
    path:
        '${_endpoint.path.replaceFirst(RegExp(r'/$'), '')}'
        '${source.rootPath == '/' ? '/' : '/${source.rootPath.replaceFirst(RegExp(r'^/'), '')}'}',
  );
  Uri _path(String value) {
    if (value.contains('\u0000') || value.split('/').contains('..')) {
      throw const NasHttpException('NAS_INVALID_PATH');
    }
    final root = _root.path.replaceFirst(RegExp(r'/$'), '');
    return _root.replace(
      path: '$root/${value.replaceFirst(RegExp(r'^/'), '')}',
    );
  }

  bool _excluded(Uri uri, NasScanConfig config) =>
      config.excludePaths.any((path) {
        final excluded = _path(path).path.replaceFirst(RegExp(r'/$'), '');
        return uri.path == excluded || uri.path.startsWith('$excluded/');
      });

  @override
  Future<void> probe() async {
    final response = await _http.open(
      NasMediaKind.fromPath(_endpoint.path) == null ? 'PROPFIND' : 'HEAD',
      NasMediaKind.fromPath(_endpoint.path) == null ? _root : _endpoint,
      headers: const {'Depth': '0'},
    );
    response.close();
  }

  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) async* {
    cancellation.check();
    if (NasMediaKind.fromPath(_endpoint.path) case final kind?) {
      final response = await _http.open(
        'HEAD',
        _endpoint,
        cancellation: cancellation,
      );
      try {
        yield [
          NasMediaItem(
            serverId: source.id,
            path: _endpoint.path,
            sourcePath: Uri.decodeComponent(_endpoint.path),
            kind: kind,
            sizeBytes: response.response.contentLength < 0
                ? 0
                : response.response.contentLength,
            modifiedEpoch: _modified(
              response.headers.value(HttpHeaders.lastModifiedHeader),
            ),
            mimeType: response.headers.contentType?.mimeType,
          ),
        ];
      } finally {
        response.close();
      }
      return;
    }
    // The traversal frontier lives on disk, including a directory containing a
    // million child directories. Only one DAV response and 128 media are in RAM.
    final temp = await Directory.systemTemp.createTemp('valhalla-dav-scan-');
    final file = File('${temp.path}/pending');
    final writer = await file.open(mode: FileMode.write);
    RandomAccessFile? reader;
    try {
      final roots = (config.includePaths.isEmpty ? ['/'] : config.includePaths)
          .map(_path)
          .where((uri) => !_excluded(uri, config))
          .toSet()
          .toList();
      for (final root in roots) {
        if (roots.any(
          (other) =>
              other != root &&
              root.path.startsWith(
                '${other.path.replaceFirst(RegExp(r'/$'), '')}/',
              ),
        )) {
          continue;
        }
        await writer.writeString('${root.toString()}\n');
      }
      reader = await file.open();
      var pending = '';
      var batch = <NasMediaItem>[];
      while (true) {
        cancellation.check();
        while (!pending.contains('\n')) {
          final bytes = await reader.read(8192);
          if (bytes.isEmpty) break;
          // URI.toString is ASCII percent-encoded, so chunk boundaries are safe.
          pending += ascii.decode(bytes);
        }
        if (pending.isEmpty) break;
        final newline = pending.indexOf('\n');
        if (newline < 0) throw const NasHttpException('NAS_INVALID_SCAN_QUEUE');
        final directory = Uri.parse(pending.substring(0, newline));
        pending = pending.substring(newline + 1);
        final response = await _http.open(
          'PROPFIND',
          directory,
          headers: const {'Depth': '1'},
          cancellation: cancellation,
        );
        try {
          await for (final entry in _davEntries(response.decodedBytes)) {
            cancellation.check();
            final uri = directory.resolve(entry.href);
            if (!nasSameOrigin(_endpoint, uri) || uri.userInfo.isNotEmpty) {
              continue;
            }
            final parent = directory.path.replaceFirst(RegExp(r'/$'), '');
            final child = uri.path.replaceFirst(RegExp(r'/$'), '');
            if (!child.startsWith('$parent/') ||
                child.substring(parent.length + 1).contains('/') ||
                _excluded(uri, config)) {
              continue;
            }
            if (entry.directory) {
              await writer.writeString('${uri.replace(path: '$child/')}\n');
            } else if (NasMediaKind.fromPath(uri.path) case final kind?) {
              batch.add(
                NasMediaItem(
                  serverId: source.id,
                  path: uri.path,
                  sourcePath: Uri.decodeComponent(uri.path),
                  kind: kind,
                  sizeBytes: entry.size,
                  modifiedEpoch: entry.modified,
                  mimeType: entry.mime,
                ),
              );
              if (batch.length == 128) {
                yield batch;
                batch = [];
              }
            }
          }
        } finally {
          response.close();
        }
      }
      if (batch.isNotEmpty) yield batch;
    } finally {
      await reader?.close();
      await writer.close();
      await temp.delete(recursive: true);
    }
  }

  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async {
    if (item.serverId != source.id || !item.path.startsWith('/')) {
      throw const NasHttpException('NAS_SOURCE_MISMATCH');
    }
    final uri = _endpoint.replace(path: item.path);
    return NasResource(
      uri: _publicOriginal ? uri : null,
      headers: {
        if (source.forwardedHost != null) 'Host': source.forwardedHost!,
      },
      read: (start, end, cancel) => _http.readRange(uri, start, end, cancel),
      sizeBytes: item.sizeBytes > 0 ? item.sizeBytes : null,
      mimeType: item.mimeType ?? 'application/octet-stream',
    );
  }

  @override
  Future<void> dispose() async => _http.close();
}

int _modified(String? value) {
  if (value == null) return 0;
  try {
    return HttpDate.parse(value).millisecondsSinceEpoch ~/ 1000;
  } on FormatException {
    return 0;
  }
}

class _DavEntry {
  final String href;
  final bool directory;
  final int size;
  final int modified;
  final String? mime;
  _DavEntry(this.href, this.directory, this.size, this.modified, this.mime);
}

/// Incremental XML events preserve split UTF-8 characters and never retain a
/// multistatus document. Only successful propstat blocks contribute metadata.
Stream<_DavEntry> _davEntries(Stream<List<int>> bytes) async* {
  var active = false;
  var inPropstat = false;
  var collection = false;
  var propCollection = false;
  var fields = <String, String>{};
  var props = <String, String>{};
  final stack = <String>[];
  var recordBytes = 0;
  var validProperties = false;
  var deniedProperties = false;
  var hasRoot = false;
  await for (final events
      in _boundedXml(bytes)
          .transform(utf8.decoder)
          .toXmlEvents(validateNesting: true, validateDocument: true)) {
    for (final event in events) {
      if (event is XmlDoctypeEvent) {
        throw const NasHttpException('NAS_INVALID_XML');
      }
      if (event is XmlStartElementEvent) {
        final name = event.localName;
        if (!hasRoot) {
          if (name != 'multistatus') {
            throw const NasHttpException('NAS_INVALID_DAV_RESPONSE');
          }
          hasRoot = true;
        }
        if (name == 'response') {
          active = true;
          fields = {};
          recordBytes = 0;
          collection = false;
          validProperties = false;
          deniedProperties = false;
        }
        if (active && name == 'propstat') {
          inPropstat = true;
          props = {};
          propCollection = false;
        }
        if (active && name == 'collection') propCollection = true;
        if (!event.isSelfClosing) stack.add(name);
        if (stack.length > 64) throw const NasHttpException('NAS_INVALID_XML');
      } else if (event is XmlTextEvent || event is XmlCDATAEvent) {
        if (!active || stack.isEmpty) continue;
        final text = event is XmlTextEvent
            ? event.value
            : (event as XmlCDATAEvent).value;
        recordBytes += text.length;
        if (recordBytes > 256 * 1024) {
          throw const NasHttpException('NAS_RESPONSE_TOO_LARGE');
        }
        final target = inPropstat ? props : fields;
        final key = stack.last;
        if ({
          'href',
          'status',
          'getcontentlength',
          'getlastmodified',
          'getcontenttype',
        }.contains(key)) {
          target[key] = '${target[key] ?? ''}$text';
        }
      } else if (event is XmlEndElementEvent) {
        final name = event.localName;
        if (name == 'propstat') {
          if (RegExp(r'\s200(?:\s|$)').hasMatch(props['status'] ?? '')) {
            validProperties = true;
            fields.addAll({...props}..remove('status'));
            collection = collection || propCollection;
          } else if (!RegExp(
            r'\s404(?:\s|$)',
          ).hasMatch(props['status'] ?? '')) {
            deniedProperties = true;
          }
          inPropstat = false;
        }
        if (name == 'response') {
          if (!validProperties && deniedProperties) {
            throw const NasHttpException('NAS_DAV_PARTIAL_FAILURE');
          }
          final href = fields['href']?.trim();
          final status = fields['status'];
          if (status != null &&
              !RegExp(r'\s(?:200|404)(?:\s|$)').hasMatch(status)) {
            throw const NasHttpException('NAS_DAV_PARTIAL_FAILURE');
          }
          if (href != null &&
              href.isNotEmpty &&
              validProperties &&
              (fields['status'] == null ||
                  RegExp(r'\s200(?:\s|$)').hasMatch(fields['status']!))) {
            yield _DavEntry(
              href,
              collection,
              int.tryParse(fields['getcontentlength'] ?? '') ?? 0,
              _modified(fields['getlastmodified']?.trim()),
              fields['getcontenttype']?.trim(),
            );
          }
          active = false;
        }
        if (stack.isNotEmpty) stack.removeLast();
      }
    }
  }
  if (!hasRoot) throw const NasHttpException('NAS_INVALID_DAV_RESPONSE');
}

// Bound even an unfinished XML token before the event parser buffers it.
Stream<List<int>> _boundedXml(Stream<List<int>> input) async* {
  var tokenBytes = 0;
  await for (final chunk in input) {
    for (final byte in chunk) {
      if (byte == 62) {
        tokenBytes = 0;
      } else if (++tokenBytes > 256 * 1024) {
        throw const NasHttpException('NAS_RESPONSE_TOO_LARGE');
      }
    }
    yield chunk;
  }
}
