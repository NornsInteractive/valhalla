import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../../data/models/agent_profile.dart';
import '../cli/agent_execution_target.dart';

/// An official ACP browser challenge. Kept in memory only, never in diagnostics.
class AcpOAuthRequest {
  final Uri authorizationUrl;
  final Uri redirectUri;
  final String state;

  const AcpOAuthRequest._(this.authorizationUrl, this.redirectUri, this.state);

  static AcpOAuthRequest? fromLine(String line) {
    const marker = 'Open the following link to authenticate the ACP server: ';
    final index = line.indexOf(marker);
    if (index < 0 || line.length > 16384) return null;
    try {
      final url = Uri.parse(line.substring(index + marker.length).trim());
      final query = url.queryParametersAll;
      if (url.scheme != 'https' ||
          url.host != 'accounts.google.com' ||
          url.port != 443 ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          url.path != '/o/oauth2/v2/auth' ||
          query['response_type']?.singleOrNull != 'code' ||
          query['client_id']?.singleOrNull?.isNotEmpty != true) {
        return null;
      }
      final redirect = Uri.parse(query['redirect_uri']?.singleOrNull ?? '');
      final state = query['state']?.singleOrNull;
      if (redirect.scheme != 'http' ||
          redirect.host != '127.0.0.1' ||
          !redirect.hasPort ||
          redirect.port < 1024 ||
          redirect.port > 65535 ||
          redirect.userInfo.isNotEmpty ||
          redirect.hasQuery ||
          redirect.hasFragment ||
          state == null ||
          state.isEmpty) {
        return null;
      }
      return AcpOAuthRequest._(url, redirect, state);
    } on FormatException {
      return null;
    }
  }

  Uri validateCallback(String value) {
    if (value.length > 16384 || value.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException('ACP_AUTH_CALLBACK_INVALID');
    }
    final Uri uri;
    try {
      uri = Uri.parse(value.trim());
    } on FormatException {
      throw const FormatException('ACP_AUTH_CALLBACK_INVALID');
    }
    final query = uri.queryParametersAll;
    final code = query['code'];
    final error = query['error'];
    final hasSingleResult =
        (code != null &&
            code.length == 1 &&
            code.single.isNotEmpty &&
            error == null) ||
        (error != null &&
            error.length == 1 &&
            error.single.isNotEmpty &&
            code == null);
    if (uri.scheme != redirectUri.scheme ||
        uri.host != redirectUri.host ||
        uri.port != redirectUri.port ||
        uri.path != redirectUri.path ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        query['state']?.singleOrNull != state ||
        !hasSingleResult) {
      throw const FormatException('ACP_AUTH_CALLBACK_INVALID');
    }
    return uri;
  }
}

/// Deliver the callback to the original host/container loopback, over SSH.
/// The authorization code goes only through stdin, not command arguments/logs.
Future<void> deliverAcpOAuthCallback(
  SSHClient client,
  AgentProfile profile,
  AcpOAuthRequest request,
  String callback,
) async {
  final uri = request.validateCallback(callback);
  final command = agentTargetCommand(
    profile,
    'curl -q --silent --show-error --max-time 15 --noproxy "*" '
    '--max-redirs 0 --output /dev/null --write-out "%{http_code}" --config -',
  );
  var openingExpired = false;
  final SSHSession session;
  try {
    session = await client
        .execute(command)
        .then((opened) {
          if (openingExpired) {
            opened.close();
            throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
          }
          return opened;
        })
        .timeout(const Duration(seconds: 20));
  } finally {
    openingExpired = true;
  }
  final stderrDone = Completer<void>();
  final stderr = session.stderr.listen(
    (_) {},
    onDone: () {
      if (!stderrDone.isCompleted) stderrDone.complete();
    },
    onError: (Object error, StackTrace stack) {
      if (!stderrDone.isCompleted) {
        stderrDone.completeError(error, stack);
      }
    },
  );
  try {
    // Observe both streams and channel completion before waiting on stdin:
    // a disconnect can reject any of them while the others are still pending.
    final outputFuture = session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .fold<String>('', (value, chunk) {
          if (value.length + chunk.length > 4096) {
            throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
          }
          return value + chunk;
        });
    final delivery = Future.wait<Object?>([
      outputFuture,
      stderrDone.future,
      session.done,
      Future<void>.sync(() async {
        session.stdin.add(utf8.encode('url = ${jsonEncode(uri.toString())}\n'));
        await session.stdin.close();
      }),
    ], eagerError: true).then((results) => results.first as String);
    final output = await delivery.timeout(const Duration(seconds: 20));
    final code = int.tryParse(output.trim());
    if (session.exitCode != 0 || code == null || code < 200 || code >= 400) {
      throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
    }
  } finally {
    try {
      session.close();
    } finally {
      await stderr.cancel();
    }
  }
}

/// Mirror the official loopback port on the phone so its browser can return.
/// A failed bind must be surfaced before opening the browser.
class AcpOAuthLoopback {
  final HttpServer _server;
  AcpOAuthLoopback._(this._server);

  static Future<AcpOAuthLoopback> bind(
    AcpOAuthRequest challenge,
    Future<void> Function(String callback) deliver, {
    String Function({required bool success})? renderPage,
  }) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      challenge.redirectUri.port,
      shared: false,
    );
    server.listen((request) async {
      var success = false;
      try {
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.headers.set('Referrer-Policy', 'no-referrer');
        request.response.headers.contentType = ContentType.html;
        if (request.method != 'GET' ||
            request.headers.value(HttpHeaders.hostHeader) !=
                challenge.redirectUri.authority) {
          request.response.statusCode = HttpStatus.badRequest;
          return;
        }
        final callback = challenge.redirectUri.resolveUri(request.uri);
        challenge.validateCallback(callback.toString());
        await deliver(callback.toString());
        success = !callback.queryParameters.containsKey('error');
      } catch (_) {
        // Never echo a callback URL/code or exception containing it.
        request.response.statusCode = HttpStatus.badRequest;
      } finally {
        try {
          if (renderPage != null) {
            request.response.write(renderPage(success: success));
          }
          await request.response.close();
        } catch (_) {
          // Browser cancellation must not become an uncaught app exception.
        }
      }
    }, onError: (Object _) {});
    return AcpOAuthLoopback._(server);
  }

  Future<void> close() async {
    await _server.close();
  }
}
