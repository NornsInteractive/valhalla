import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';

/// Challenge framing contract: the official Google host allowlist, the phone
/// loopback redirect rules, and the 16384-byte line cap.
const _marker = 'Open the following link to authenticate the ACP server: ';

/// Official-shaped challenge URL. Only fields a test varies are parameters.
String _url({
  String scheme = 'https',
  String userInfo = '',
  String host = 'accounts.google.com',
  String port = '',
  String path = '/o/oauth2/v2/auth',
  String? clientId = 'client-abc',
  String? responseType = 'code',
  String? redirect = 'http%3A%2F%2F127.0.0.1%3A8765%2Fcb',
  String? state = 'state-1',
  String extraQuery = '',
  String fragment = '',
}) {
  final query = <String>[
    if (clientId != null) 'client_id=$clientId',
    if (responseType != null) 'response_type=$responseType',
    if (redirect != null) 'redirect_uri=$redirect',
    if (state != null) 'state=$state',
    if (extraQuery.isNotEmpty) extraQuery,
  ].join('&');
  return '$scheme://${userInfo.isEmpty ? '' : '$userInfo@'}$host$port$path'
      '?$query${fragment.isEmpty ? '' : '#$fragment'}';
}

AcpOAuthRequest? _from(String url) => AcpOAuthRequest.fromLine('$_marker$url');

void main() {
  group('fromLine allowlist', () {
    test('accepts the official Google authorization endpoint', () {
      final request = _from(_url());
      expect(request, isNotNull, reason: 'fixture challenge must be accepted');
      expect(request!.authorizationUrl.host, 'accounts.google.com');
      expect(request.authorizationUrl.scheme, 'https');
      expect(request.authorizationUrl.port, 443);
      expect(request.authorizationUrl.path, '/o/oauth2/v2/auth');
      expect(request.redirectUri.toString(), 'http://127.0.0.1:8765/cb');
      expect(request.state, 'state-1');
    });

    test('rejects scheme, host, port and path off the allowlist', () {
      expect(_from(_url(scheme: 'http')), isNull);
      expect(_from(_url(host: 'evil.example.com')), isNull);
      expect(_from(_url(host: 'accounts.google.com.evil.test')), isNull);
      expect(_from(_url(port: ':8080')), isNull);
      expect(_from(_url(port: ':80')), isNull);
      expect(_from(_url(path: '/o/oauth2/auth')), isNull);
      expect(_from(_url(path: '/o/oauth2/v2/auth/extra')), isNull);
    });

    test('rejects credentials, fragments and non-code response types', () {
      expect(_from(_url(userInfo: 'user:pw@')), isNull);
      expect(_from(_url(fragment: 'frag')), isNull);
      expect(_from(_url(responseType: 'token')), isNull);
      expect(_from(_url(responseType: null)), isNull);
      expect(_from(_url(clientId: null)), isNull);
      expect(_from(_url(clientId: '')), isNull);
    });

    test('rejects duplicated challenge query parameters', () {
      expect(_from(_url(extraQuery: '&client_id=other')), isNull);
      expect(_from(_url(extraQuery: '&response_type=code')), isNull);
      expect(
        _from(
          _url(extraQuery: '&redirect_uri=http%3A%2F%2F127.0.0.1%3A9999%2Fcb'),
        ),
        isNull,
      );
      expect(_from(_url(extraQuery: '&state=state-1')), isNull);
    });
  });

  group('fromLine loopback redirect rules', () {
    test('rejects a non-loopback host or a missing port', () {
      expect(
        _from(_url(redirect: Uri.encodeFull('http://example.com:8765/cb'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('http://localhost:8765/cb'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('http://127.0.0.1/cb'))),
        isNull,
      );
    });

    test('rejects privileged ports and non-http schemes', () {
      expect(
        _from(_url(redirect: Uri.encodeFull('http://127.0.0.1:80/cb'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('http://127.0.0.1:443/cb'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('https://127.0.0.1:8765/cb'))),
        isNull,
      );
    });

    test('rejects redirect query, fragment, userinfo and missing state', () {
      expect(
        _from(_url(redirect: Uri.encodeFull('http://127.0.0.1:8765/cb?n=1'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('http://127.0.0.1:8765/cb#f'))),
        isNull,
      );
      expect(
        _from(_url(redirect: Uri.encodeFull('http://u@127.0.0.1:8765/cb'))),
        isNull,
      );
      expect(_from(_url(state: null)), isNull);
      expect(_from(_url(state: '')), isNull);
    });
  });

  group('fromLine framing', () {
    test('rejects a line without the official marker', () {
      expect(AcpOAuthRequest.fromLine(_url()), isNull);
      expect(AcpOAuthRequest.fromLine('Open the following link: x'), isNull);
    });

    test('rejects a line beyond the 16384 cap', () {
      final line = '$_marker${_url(extraQuery: '&pad=${'a' * 16400}')}';
      expect(AcpOAuthRequest.fromLine(line), isNull);
    });

    test('finds the marker anywhere in the line', () {
      expect(AcpOAuthRequest.fromLine('noise $_marker${_url()}'), isNotNull);
    });
  });
}
