import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../ssh/ssh_client_manager.dart';
import 'nas_http_client.dart';
import 'nas_sftp_adapter.dart';

/// Range relay. LAN listeners exist only for an explicitly started cast session.
class NasMediaProxyService {
  final SshCommandExecutor _ssh;
  final _servers = <String, Future<HttpServer>>{};
  final _entries = <String, _ProxyEntry>{};
  final _random = Random.secure();
  int _active = 0;
  bool _disposed = false;

  NasMediaProxyService(this._ssh, {int Function()? cacheBudgetBytes});

  Future<Uri> expose(NasMediaItem item) async => exposeResource(
    item,
    await NasSftpAdapter(
      NasSource(
        id: item.serverId,
        name: item.serverId,
        type: NasSourceType.sftp,
        sshServerId: item.serverId,
      ),
      _ssh,
    ).resolve(item),
  );

  Future<Uri> exposeResource(
    NasMediaItem item,
    NasResource resource, {
    InternetAddress? address,
  }) async {
    if (_disposed) throw StateError('NAS_PROXY_CLOSED');
    final bind = address ?? InternetAddress.loopbackIPv4;
    if (bind.type != InternetAddressType.IPv4 ||
        bind.isMulticast ||
        bind.address == '0.0.0.0') {
      throw ArgumentError('NAS_INVALID_RELAY_ADDRESS');
    }
    _expire();
    if (_entries.length >= 256) throw StateError('NAS_TOO_MANY_STREAMS');
    final server = await _servers.putIfAbsent(bind.address, () async {
      final server = await HttpServer.bind(bind, 0, shared: false);
      server.listen((request) => unawaited(_handle(request, bind.address)));
      return server;
    });
    if (_disposed) {
      await server.close(force: true);
      throw StateError('NAS_PROXY_CLOSED');
    }
    if (_entries.length >= 256) throw StateError('NAS_TOO_MANY_STREAMS');
    final token = List.generate(
      32,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _entries[token] = _ProxyEntry(resource, bind.address);
    return Uri(
      scheme: 'http',
      host: bind.address,
      port: server.port,
      pathSegments: ['media', token, item.name],
    );
  }

  void revoke(Uri uri) {
    if (uri.pathSegments.length < 2) return;
    final entry = _entries.remove(uri.pathSegments[1]);
    entry?.cancel();
    if (entry != null &&
        entry.address != InternetAddress.loopbackIPv4.address &&
        !_entries.values.any((other) => other.address == entry.address)) {
      final server = _servers.remove(entry.address);
      if (server != null) {
        unawaited(server.then((value) => value.close(force: true)));
      }
    }
  }

  void retain(Uri uri) {
    if (uri.pathSegments.length < 2) return;
    final entry = _entries[uri.pathSegments[1]];
    if (entry != null) {
      entry.expiresAt = DateTime.now().add(const Duration(hours: 4));
    }
  }

  void _expire() {
    final now = DateTime.now();
    _entries.removeWhere((_, entry) {
      if (entry.expiresAt.isAfter(now) || entry.requests.isNotEmpty) {
        return false;
      }
      entry.cancel();
      return true;
    });
  }

  Future<void> _handle(HttpRequest request, String address) async {
    final response = request.response;
    final parts = request.uri.pathSegments;
    final entry = parts.length == 3 && parts.first == 'media'
        ? _entries[parts[1]]
        : null;
    if (entry == null ||
        entry.address != address ||
        entry.expiresAt.isBefore(DateTime.now())) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set('Allow', 'GET, HEAD');
      await response.close();
      return;
    }
    if (_active >= 8) {
      response.statusCode = HttpStatus.serviceUnavailable;
      response.headers.set('Retry-After', '1');
      await response.close();
      return;
    }
    final cancellation = NasCancellation();
    entry.requests.add(cancellation);
    _active++;
    entry.expiresAt = DateTime.now().add(const Duration(hours: 4));
    unawaited(
      response.done.then(
        (_) => cancellation.cancel(),
        onError: (Object _) => cancellation.cancel(),
      ),
    );
    try {
      final resource = entry.resource;
      final length = resource.sizeBytes;
      final header = request.headers.value(HttpHeaders.rangeHeader);
      final range = length == null ? null : parseRange(header, length);
      if (header != null && (range == null || !resource.seekable)) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        if (length != null) {
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$length',
          );
        }
        await response.close();
        return;
      }
      final start = range?.$1 ?? 0;
      final end = range == null ? length : range.$2 + 1;
      response.headers.contentType = ContentType.parse(resource.mimeType);
      response.headers.set(HttpHeaders.cacheControlHeader, 'private, no-store');
      response.headers.set(
        HttpHeaders.acceptRangesHeader,
        length != null && resource.seekable ? 'bytes' : 'none',
      );
      if (range != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${end! - 1}/$length',
        );
      }
      if (end != null) response.contentLength = end - start;
      if (request.method != 'HEAD' && end != start) {
        await response.addStream(
          readNasResource(resource, start, end, cancellation),
        );
      }
      await response.close();
    } catch (_) {
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {}
    } finally {
      cancellation.cancel();
      entry.requests.remove(cancellation);
      _active--;
    }
  }

  /// Inclusive HTTP range. Empty files and multi-ranges are rejected.
  static (int, int)? parseRange(String? header, int length) {
    if (header == null || length <= 0) return null;
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final first = match[1]!, last = match[2]!;
    if (first.isEmpty) {
      final suffix = int.tryParse(last);
      return suffix == null || suffix <= 0
          ? null
          : (max(0, length - suffix), length - 1);
    }
    final start = int.tryParse(first);
    final end = last.isEmpty ? length - 1 : int.tryParse(last);
    if (start == null || end == null || start >= length || end < start) {
      return null;
    }
    return (start, min(end, length - 1));
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final entry in _entries.values) {
      entry.cancel();
    }
    _entries.clear();
    for (final pending in _servers.values) {
      await (await pending).close(force: true);
    }
    _servers.clear();
  }
}

class _ProxyEntry {
  final NasResource resource;
  final String address;
  DateTime expiresAt = DateTime.now().add(const Duration(hours: 4));
  final requests = <NasCancellation>{};
  _ProxyEntry(this.resource, this.address);
  void cancel() {
    for (final request in requests.toList()) {
      request.cancel();
    }
  }
}
