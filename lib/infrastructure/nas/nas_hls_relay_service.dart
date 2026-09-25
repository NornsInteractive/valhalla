import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../data/models/nas_source.dart';
import 'nas_http_client.dart';

/// Authenticated HLS stays behind a scoped HTTP endpoint. Every child URL is
/// authenticated AND encrypted, so server query tokens are not exposed to a TV.
/// The session key authenticates child addresses without an ever-growing map.
class NasHlsRelayService {
  final _random = Random.secure();
  final _servers = <String, Future<HttpServer>>{};
  final _sessions = <String, _HlsSession>{};
  Timer? _expiry;
  int _active = 0;
  bool _disposed = false;

  Future<Uri> expose(NasResource resource, {InternetAddress? address}) async {
    if (_disposed) throw StateError('NAS_HLS_CLOSED');
    final origin = resource.uri;
    if (origin == null) throw ArgumentError('NAS_HLS_URI_REQUIRED');
    nasHttpEndpoint(origin.toString());
    final bind = address ?? InternetAddress.loopbackIPv4;
    if (bind.type != InternetAddressType.IPv4 ||
        bind.isMulticast ||
        bind.address == '0.0.0.0') {
      throw ArgumentError('NAS_INVALID_RELAY_ADDRESS');
    }
    _expire();
    if (_sessions.length >= 16) throw StateError('NAS_TOO_MANY_HLS_SESSIONS');
    final pending = _servers.putIfAbsent(bind.address, () async {
      final server = await HttpServer.bind(bind, 0, shared: false);
      server.listen((request) => unawaited(_handle(request, bind.address)));
      return server;
    });
    final HttpServer server;
    try {
      server = await pending;
    } catch (_) {
      _servers.remove(bind.address);
      rethrow;
    }
    if (_disposed) {
      await server.close(force: true);
      throw StateError('NAS_HLS_CLOSED');
    }
    if (_sessions.length >= 16) throw StateError('NAS_TOO_MANY_HLS_SESSIONS');
    final token = _bytes(
      32,
    ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final session = _HlsSession(
      token,
      bind.address,
      server.port,
      _bytes(32),
      origin,
      resource.headers,
    );
    _sessions[token] = session;
    _expiry ??= Timer.periodic(const Duration(minutes: 1), (_) => _expire());
    try {
      return _url(session, origin, playlist: true);
    } catch (_) {
      revoke(Uri(pathSegments: ['hls', token]));
      rethrow;
    }
  }

  Uint8List _bytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
  Uri _url(_HlsSession session, Uri target, {required bool playlist}) {
    if (!nasSameOrigin(session.origin, target) ||
        target.userInfo.isNotEmpty ||
        target.hasFragment ||
        target.toString().length > 4096 ||
        target.toString().contains(r'{$')) {
      throw const NasHttpException('NAS_HLS_CROSS_ORIGIN');
    }
    final nonce = _bytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(session.key),
          128,
          nonce,
          Uint8List.fromList(utf8.encode(session.token)),
        ),
      );
    final payload = cipher.process(
      Uint8List.fromList(
        utf8.encode(jsonEncode({'u': target.toString(), 'p': playlist})),
      ),
    );
    final opaque = base64Url.encode([...nonce, ...payload]).replaceAll('=', '');
    return Uri(
      scheme: 'http',
      host: session.address,
      port: session.port,
      pathSegments: [
        'hls',
        session.token,
        opaque,
        playlist ? 'index.m3u8' : 'media',
      ],
    );
  }

  ({Uri uri, bool playlist}) _target(_HlsSession session, String opaque) {
    if (opaque.length > 8192) {
      throw const NasHttpException('NAS_HLS_INVALID_TOKEN');
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(opaque));
      if (bytes.length < 29) throw const FormatException();
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(session.key),
            128,
            Uint8List.sublistView(bytes, 0, 12),
            Uint8List.fromList(utf8.encode(session.token)),
          ),
        );
      final payload =
          jsonDecode(
                utf8.decode(cipher.process(Uint8List.sublistView(bytes, 12))),
              )
              as Map;
      final target = Uri.parse(payload['u'] as String);
      if (!nasSameOrigin(session.origin, target) ||
          target.userInfo.isNotEmpty) {
        throw const FormatException();
      }
      return (uri: target, playlist: payload['p'] == true);
    } catch (_) {
      throw const NasHttpException('NAS_HLS_INVALID_TOKEN');
    }
  }

  void retain(Uri uri) {
    final parts = uri.pathSegments;
    if (parts.length < 2) return;
    final session = _sessions[parts[1]];
    if (session != null) {
      session.expires = DateTime.now().add(const Duration(hours: 4));
    }
  }

  void revoke(Uri uri) {
    final parts = uri.pathSegments;
    if (parts.length < 2) return;
    final session = _sessions.remove(parts[1]);
    if (session == null) return;
    session.close();
    if (!_sessions.values.any((other) => other.address == session.address)) {
      final server = _servers.remove(session.address);
      if (server != null) {
        unawaited(server.then((value) => value.close(force: true)));
      }
    }
    if (_sessions.isEmpty) {
      _expiry?.cancel();
      _expiry = null;
    }
  }

  void _expire() {
    for (final session in _sessions.values.toList()) {
      if (session.expires.isBefore(DateTime.now())) {
        revoke(Uri(pathSegments: ['hls', session.token]));
      }
    }
  }

  Future<void> _handle(HttpRequest request, String address) async {
    final response = request.response;
    NasHttpResponse? upstream;
    final cancellation = NasCancellation();
    var counted = false;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set('Allow', 'GET, HEAD');
        return;
      }
      final parts = request.uri.pathSegments;
      final session = parts.length == 4 && parts.first == 'hls'
          ? _sessions[parts[1]]
          : null;
      if (session == null ||
          session.address != address ||
          session.expires.isBefore(DateTime.now())) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (_active >= 8) {
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      final target = _target(session, parts[2]);
      _active++;
      counted = true;
      retain(request.uri);
      unawaited(
        response.done.then(
          (_) => cancellation.cancel(),
          onError: (Object _) => cancellation.cancel(),
        ),
      );
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null && !RegExp(r'^bytes=\d*-\d*$').hasMatch(range)) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return;
      }
      upstream = await session.http.open(
        request.method,
        target.uri,
        headers: {if (range != null && !target.playlist) 'Range': range},
        cancellation: cancellation,
      );
      final encoding = upstream.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      if (encoding != null && encoding != 'identity') {
        throw const NasHttpException('NAS_UNSUPPORTED_CONTENT_ENCODING');
      }
      final mime = upstream.headers.contentType?.mimeType.toLowerCase() ?? '';
      final playlist =
          target.playlist ||
          target.uri.path.toLowerCase().endsWith('.m3u8') ||
          mime.contains('mpegurl');
      response.headers.set(HttpHeaders.cacheControlHeader, 'private, no-store');
      if (playlist) {
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
          charset: 'utf-8',
        );
        // HEAD omits Content-Length because a rewritten manifest has a different
        // size. Its body never needs to be downloaded to answer HEAD.
        if (request.method == 'HEAD') return;
        final bytes = <int>[];
        await for (final chunk in upstream.bytes) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const NasHttpException('NAS_HLS_MANIFEST_TOO_LARGE');
          }
          bytes.addAll(chunk);
        }
        final manifest = _rewrite(session, upstream.uri, utf8.decode(bytes));
        final encoded = utf8.encode(manifest);
        response.contentLength = encoded.length;
        response.add(encoded);
      } else {
        if (range != null) _validateRange(range, upstream);
        response.statusCode = upstream.status;
        for (final header in [
          HttpHeaders.contentTypeHeader,
          HttpHeaders.contentLengthHeader,
          HttpHeaders.contentRangeHeader,
          HttpHeaders.acceptRangesHeader,
          HttpHeaders.lastModifiedHeader,
          HttpHeaders.etagHeader,
        ]) {
          final value = upstream.headers.value(header);
          if (value != null) response.headers.set(header, value);
        }
        if (request.method == 'GET') await response.addStream(upstream.bytes);
      }
    } catch (error) {
      try {
        response.statusCode =
            error is NasHttpException && error.code == 'NAS_HLS_INVALID_TOKEN'
            ? HttpStatus.notFound
            : error is NasHttpException && error.status == 416
            ? HttpStatus.requestedRangeNotSatisfiable
            : HttpStatus.badGateway;
      } catch (_) {}
    } finally {
      upstream?.close();
      cancellation.cancel();
      if (counted) _active--;
      try {
        await response.close();
      } catch (_) {}
    }
  }

  String _rewrite(_HlsSession session, Uri base, String body) {
    if (!body.trimLeft().startsWith('#EXTM3U')) {
      throw const NasHttpException('NAS_INVALID_HLS');
    }
    final output = StringBuffer();
    var nextPlaylist = false;
    for (final line in const LineSplitter().convert(body)) {
      final value = line.trim();
      if (value.startsWith('#EXT-X-CONTENT-STEERING:') ||
          value.startsWith('#EXT-X-DEFINE:')) {
        throw const NasHttpException('NAS_HLS_EXTENSION_UNSUPPORTED');
      }
      if (value.startsWith('#')) {
        if (RegExp(r'\bURI=(?!")').hasMatch(line)) {
          throw const NasHttpException('NAS_INVALID_HLS');
        }
        final isPlaylist =
            value.startsWith('#EXT-X-MEDIA:') ||
            value.startsWith('#EXT-X-I-FRAME-STREAM-INF:') ||
            value.startsWith('#EXT-X-RENDITION-REPORT:');
        output.writeln(
          line.replaceAllMapped(
            RegExp(r'\bURI="([^"]*)"'),
            (match) =>
                'URI="${_url(session, base.resolve(match[1]!), playlist: isPlaylist)}"',
          ),
        );
        if (value.startsWith('#EXT-X-STREAM-INF:')) nextPlaylist = true;
      } else if (value.isNotEmpty) {
        output.writeln(
          _url(session, base.resolve(value), playlist: nextPlaylist),
        );
        nextPlaylist = false;
      } else {
        output.writeln();
      }
    }
    return output.toString();
  }

  void _validateRange(String requested, NasHttpResponse upstream) {
    final range = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(requested);
    final actual = RegExp(
      r'^bytes (\d+)-(\d+)/(\d+|\*)$',
    ).firstMatch(upstream.headers.value(HttpHeaders.contentRangeHeader) ?? '');
    if (upstream.status != 206 || range == null || actual == null) {
      throw const NasHttpException('NAS_RANGE_UNSUPPORTED');
    }
    final start = int.parse(actual[1]!), end = int.parse(actual[2]!);
    final total = int.tryParse(actual[3]!);
    if (end < start || (total != null && end >= total)) {
      throw const NasHttpException('NAS_INVALID_RANGE_RESPONSE');
    }
    if (range[1]!.isNotEmpty) {
      final requestedEnd = int.tryParse(range[2]!);
      if (start != int.parse(range[1]!) ||
          (requestedEnd != null && end > requestedEnd)) {
        throw const NasHttpException('NAS_INVALID_RANGE_RESPONSE');
      }
    } else {
      final suffix = int.tryParse(range[2]!);
      if (suffix == null ||
          suffix <= 0 ||
          total == null ||
          end != total - 1 ||
          start != max(0, total - suffix)) {
        throw const NasHttpException('NAS_INVALID_RANGE_RESPONSE');
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _expiry?.cancel();
    for (final session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
    for (final server in _servers.values.toList()) {
      await (await server).close(force: true);
    }
    _servers.clear();
  }
}

class _HlsSession {
  final String token, address;
  final int port;
  final Uint8List key;
  final Uri origin;
  final NasHttpClient http;
  DateTime expires = DateTime.now().add(const Duration(hours: 4));
  _HlsSession(
    this.token,
    this.address,
    this.port,
    this.key,
    this.origin,
    Map<String, String> headers,
  ) : http = NasHttpClient(origin, headers: headers);
  void close() {
    http.close();
    key.fillRange(0, key.length, 0);
  }
}
