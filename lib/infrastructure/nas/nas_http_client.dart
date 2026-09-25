import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/models/nas_source.dart';

/// HTTP errors intentionally omit URLs, response bodies and credentials.
class NasHttpException implements Exception {
  final String code;
  final int? status;
  const NasHttpException(this.code, [this.status]);
  @override
  String toString() => status == null ? code : '$code:$status';
}

bool nasSameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

Uri nasHttpEndpoint(String value) {
  final uri = Uri.parse(value);
  if (!{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const NasHttpException('NAS_INVALID_ENDPOINT');
  }
  return uri;
}

Stream<List<int>> readNasResource(
  NasResource resource,
  int start,
  int? end,
  NasCancellation cancellation,
) async* {
  if (resource.read case final reader?) {
    yield* reader(start, end, cancellation);
    return;
  }
  final uri = resource.uri;
  if (uri == null) throw const NasHttpException('NAS_RESOURCE_UNAVAILABLE');
  final client = NasHttpClient(
    nasHttpEndpoint(uri.toString()),
    headers: resource.headers,
  );
  try {
    yield* client.readRange(uri, start, end, cancellation);
  } finally {
    client.close();
  }
}

class NasHttpResponse {
  final HttpClientResponse response;
  final Uri uri;
  final HttpClient client;
  final void Function() _unregister;
  final NasCancellation? cancellation;
  NasHttpResponse(
    this.response,
    this.uri,
    this.client,
    this._unregister,
    this.cancellation,
  );
  int get status => response.statusCode;
  HttpHeaders get headers => response.headers;
  Stream<List<int>> get bytes async* {
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 45))) {
        cancellation?.check();
        yield chunk;
      }
    } catch (_) {
      cancellation?.check();
      rethrow;
    } finally {
      close();
    }
  }

  /// XML/JSON metadata may be compressed even after requesting identity.
  /// Media ranges keep using raw bytes and verify Content-Encoding separately.
  Stream<List<int>> get decodedBytes async* {
    try {
      final encoding = headers
          .value(HttpHeaders.contentEncodingHeader)
          ?.trim()
          .toLowerCase();
      if (encoding == null || encoding.isEmpty || encoding == 'identity') {
        yield* bytes;
      } else if (encoding == 'gzip') {
        yield* bytes.transform(gzip.decoder);
      } else {
        throw const NasHttpException('NAS_UNSUPPORTED_CONTENT_ENCODING');
      }
    } finally {
      close();
    }
  }

  void close() {
    _unregister();
    client.close(force: true);
  }
}

/// One short-lived native client per request keeps Digest credentials scoped and
/// cancellation independent. Redirects never forward credentials to another host.
class NasHttpClient {
  final Uri endpoint;
  final String username;
  final String password;
  final Map<String, String> headers;
  final _clients = <HttpClient>{};
  bool _closed = false;
  NasHttpClient(
    this.endpoint, {
    this.username = '',
    this.password = '',
    this.headers = const {},
  });

  Future<NasHttpResponse> open(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Object? jsonBody,
    NasCancellation? cancellation,
  }) async {
    cancellation?.check();
    if (_closed) throw const NasHttpException('NAS_SOURCE_CLOSED');
    if (!nasSameOrigin(endpoint, uri) || uri.userInfo.isNotEmpty) {
      throw const NasHttpException('NAS_CROSS_ORIGIN');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..autoUncompress = false;
    _clients.add(client);
    final removeCancel = cancellation?.onCancel(
      () => client.close(force: true),
    );
    void cleanup() {
      removeCancel?.call();
      _clients.remove(client);
    }

    // Native Digest supports RFC 2617 MD5. Unsupported challenge algorithms fail
    // authentication instead of silently downgrading to Basic.
    final challenges = <String>{};
    if (username.isNotEmpty) {
      client.authenticate = (url, scheme, realm) async {
        final key = '$scheme:$realm';
        if (!nasSameOrigin(endpoint, url) || !challenges.add(key)) return false;
        final credentials = switch (scheme.toLowerCase()) {
          'basic' => HttpClientBasicCredentials(username, password),
          'digest' => HttpClientDigestCredentials(username, password),
          _ => null,
        };
        if (credentials == null) return false;
        client.addCredentials(url, realm ?? '', credentials);
        return true;
      };
    }
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        cancellation?.check();
        final request = await client.openUrl(method, uri);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        <String, String>{
          ...this.headers,
          ...headers,
        }.forEach(request.headers.set);
        if (jsonBody != null) {
          final bytes = utf8.encode(jsonEncode(jsonBody));
          request.headers.contentType = ContentType.json;
          // Emby requires a length-delimited JSON body for authentication and
          // other POSTs; its parser rejects otherwise valid chunked requests.
          request.contentLength = bytes.length;
          request.add(bytes);
        }
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.listen((_) {}).cancel();
          if (location == null ||
              redirects == 5 ||
              (!{'GET', 'HEAD', 'PROPFIND'}.contains(method))) {
            throw const NasHttpException('NAS_REDIRECT');
          }
          final target = uri.resolve(location);
          if (!nasSameOrigin(endpoint, target) || target.userInfo.isNotEmpty) {
            throw const NasHttpException('NAS_CROSS_ORIGIN');
          }
          uri = target;
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.listen((_) {}).cancel();
          throw NasHttpException('NAS_HTTP_ERROR', response.statusCode);
        }
        return NasHttpResponse(response, uri, client, cleanup, cancellation);
      }
      throw const NasHttpException('NAS_REDIRECT');
    } catch (_) {
      cleanup();
      client.close(force: true);
      cancellation?.check();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> json(
    String method,
    Uri uri, {
    Object? body,
    NasCancellation? cancellation,
  }) async {
    final response = await open(
      method,
      uri,
      jsonBody: body,
      cancellation: cancellation,
    );
    final data = <int>[];
    await for (final chunk in response.decodedBytes) {
      if (data.length + chunk.length > 8 * 1024 * 1024) {
        response.close();
        throw const NasHttpException('NAS_RESPONSE_TOO_LARGE');
      }
      data.addAll(chunk);
    }
    if (data.isEmpty) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(data));
    } on FormatException {
      // FormatException includes source text; login responses may contain tokens.
      throw const NasHttpException('NAS_INVALID_RESPONSE');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const NasHttpException('NAS_INVALID_RESPONSE');
    }
    return decoded;
  }

  Stream<List<int>> readRange(
    Uri uri,
    int start,
    int? end,
    NasCancellation cancellation,
  ) async* {
    if (start < 0 || (end != null && end < start)) {
      throw RangeError('NAS_INVALID_RANGE');
    }
    if (end == start) return;
    final ranged = start != 0 || end != null;
    final response = await open(
      'GET',
      uri,
      cancellation: cancellation,
      headers: {
        if (ranged) 'Range': 'bytes=$start-${end == null ? '' : end - 1}',
      },
    );
    try {
      final encoding = response.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      if (encoding != null && encoding != 'identity') {
        throw const NasHttpException('NAS_UNSUPPORTED_CONTENT_ENCODING');
      }
      int? expectedLength;
      if (ranged &&
          response.status == 200 &&
          start == 0 &&
          end != null &&
          response.response.contentLength == end) {
        // A server may ignore Range for an entire-file request. The exact
        // length proves these are still the requested bytes.
        expectedLength = end;
      } else if (ranged) {
        final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(
          response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
        );
        if (response.status != 206 ||
            match == null ||
            int.parse(match[1]!) != start ||
            int.parse(match[2]!) < start ||
            (end != null && int.parse(match[2]!) != end - 1)) {
          throw const NasHttpException('NAS_RANGE_UNSUPPORTED');
        }
        expectedLength = int.parse(match[2]!) - start + 1;
      } else if (response.status != 200) {
        throw const NasHttpException('NAS_INVALID_RANGE_RESPONSE');
      } else if (response.response.contentLength >= 0) {
        expectedLength = response.response.contentLength;
      }
      var length = 0;
      await for (final chunk in response.bytes) {
        length += chunk.length;
        if (expectedLength != null && length > expectedLength) {
          throw const NasHttpException('NAS_INVALID_RANGE_RESPONSE');
        }
        yield chunk;
      }
      if (expectedLength != null && length != expectedLength) {
        throw const NasHttpException('NAS_TRUNCATED_RESPONSE');
      }
    } finally {
      response.close();
    }
  }

  void close() {
    _closed = true;
    for (final client in _clients.toList()) {
      client.close(force: true);
    }
    _clients.clear();
  }
}
