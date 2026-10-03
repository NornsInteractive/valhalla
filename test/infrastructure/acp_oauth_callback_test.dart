import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';

/// Pasted/looped-back callback contract: duplicate query params, path/port/
/// scheme/host mismatches, wrong state, CRLF injection and the length cap.
const _marker = 'Open the following link to authenticate the ACP server: ';
const _challenge =
    '$_marker'
    'https://accounts.google.com/o/oauth2/v2/auth?client_id=abc'
    '&response_type=code'
    '&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcb'
    '&state=state-1';

AcpOAuthRequest _request() {
  final request = AcpOAuthRequest.fromLine(_challenge);
  expect(request, isNotNull, reason: 'fixture challenge must be accepted');
  return request!;
}

String _cb(String query) => 'http://127.0.0.1:8765/cb?$query';

/// Asserts the callback is rejected with the stable reason code.
void _reject(String callback) {
  expect(
    () => _request().validateCallback(callback),
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        'ACP_AUTH_CALLBACK_INVALID',
      ),
    ),
  );
}

void main() {
  group('validateCallback acceptance', () {
    test('accepts a code callback and returns the parsed URI', () {
      final uri = _request().validateCallback(_cb('code=code-9&state=state-1'));
      expect(uri.queryParameters['code'], 'code-9');
      expect(uri.queryParameters['state'], 'state-1');
    });

    test('accepts an error callback', () {
      final uri = _request().validateCallback(
        _cb('error=access_denied&state=state-1'),
      );
      expect(uri.queryParameters['error'], 'access_denied');
    });

    test('trims surrounding spaces from a pasted callback', () {
      final uri = _request().validateCallback(
        '  ${_cb('code=code-9&state=state-1')}  ',
      );
      expect(uri.queryParameters['code'], 'code-9');
    });
  });

  group('validateCallback requires exactly one of code and error', () {
    test('rejects both code and error', () {
      _reject(_cb('code=a&error=b&state=state-1'));
    });

    test('rejects neither code nor error', () {
      _reject(_cb('state=state-1'));
    });

    test('rejects an empty code or an empty error', () {
      _reject(_cb('code=&state=state-1'));
      _reject(_cb('error=&state=state-1'));
    });
  });

  group('validateCallback duplicate query parameters', () {
    test('rejects duplicated state values', () {
      _reject(_cb('code=a&state=state-1&state=state-1'));
      _reject(_cb('code=a&state=state-1&state=other'));
    });

    test('rejects duplicated code and error values', () {
      _reject(_cb('code=a&code=b&state=state-1'));
      _reject(_cb('error=e&error=f&state=state-1'));
    });
  });

  group('validateCallback target binding', () {
    test('rejects a state that is not this attempt', () {
      _reject(_cb('code=a&state=other-attempt'));
      _reject(_cb('code=a'));
    });

    test('rejects another port or a missing port', () {
      _reject('http://127.0.0.1:8766/cb?code=a&state=state-1');
      _reject('http://127.0.0.1/cb?code=a&state=state-1');
    });

    test('rejects another path, host or scheme', () {
      _reject(_cb('code=a&state=state-1').replaceFirst('/cb?', '/cb2?'));
      _reject('http://example.com:8765/cb?code=a&state=s1');
      _reject('https://127.0.0.1:8765/cb?code=a&state=s1');
    });
  });

  group('validateCallback injection and length guards', () {
    test('rejects userinfo and fragments', () {
      _reject('http://user@127.0.0.1:8765/cb?code=a&state=s1');
      _reject('${_cb('code=a&state=state-1')}#frag');
    });

    test('rejects CR and LF before any parsing happens', () {
      _reject('${_cb('code=a&state=state-1')}\r\nX: 1');
      _reject('${_cb('code=a&state=state-1')}\n');
    });

    test('rejects a callback beyond the 16384 cap', () {
      _reject(_cb('code=${'a' * 16400}&state=state-1'));
    });

    test('rejects unparsable callbacks', () {
      _reject('not a url');
      _reject('');
    });
  });
}
