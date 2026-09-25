import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/terminal_url_extractor.dart';

void main() {
  group('TerminalUrlExtractor.extract', () {
    test('extracts a plain URL from a single line', () {
      final result = TerminalUrlExtractor.extract(
        'Open this link: https://auth.example.com/login?code=abc123 done',
      );

      expect(result, hasLength(1));
      expect(result.single.url, 'https://auth.example.com/login?code=abc123');
    });

    test('extracts a URL wrapped in ANSI SGR sequences', () {
      final result = TerminalUrlExtractor.extract(
        '\x1b[36mhttps://auth.example.com/device\x1b[0m',
      );

      expect(result, hasLength(1));
      expect(result.single.url, 'https://auth.example.com/device');
    });

    test('returns every URL in order of appearance', () {
      final result = TerminalUrlExtractor.extract(
        'first https://one.example.com/a then https://two.example.com/b',
      );

      expect(result.map((e) => e.url), [
        'https://one.example.com/a',
        'https://two.example.com/b',
      ]);
    });

    test('strips trailing sentence punctuation', () {
      final result = TerminalUrlExtractor.extract(
        'Visit https://auth.example.com/login.',
      );

      expect(result.single.url, 'https://auth.example.com/login');
    });

    test('strips a trailing closing paren that is not part of the URL', () {
      final result = TerminalUrlExtractor.extract(
        '(see https://auth.example.com/login)',
      );

      expect(result.single.url, 'https://auth.example.com/login');
    });

    test('keeps balanced parens inside the URL path', () {
      final result = TerminalUrlExtractor.extract(
        'https://en.example.com/wiki/Foo_(bar)',
      );

      expect(result.single.url, 'https://en.example.com/wiki/Foo_(bar)');
    });

    test('preserves query and fragment intact', () {
      const url =
          'https://auth.example.com/oauth2/callback?a=1&b=2&redirect=x#frag';
      final result = TerminalUrlExtractor.extract('go to $url now');

      expect(result.single.url, url);
    });

    test('preserves percent-encoded characters', () {
      const url = 'https://auth.example.com/cb?state=a%2Fb%3Dc&scope=openid';
      final result = TerminalUrlExtractor.extract(url);

      expect(result.single.url, url);
    });

    test('matches an uppercase scheme', () {
      final result = TerminalUrlExtractor.extract(
        'HTTP://AUTH.EXAMPLE.COM/LOGIN',
      );

      expect(result.single.url, 'HTTP://AUTH.EXAMPLE.COM/LOGIN');
    });

    test('preserves unicode path segments', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/登录/回调?状态=完成',
      );

      expect(result.single.url, 'https://auth.example.com/登录/回调?状态=完成');
    });

    test('returns empty for empty or whitespace-only text', () {
      expect(TerminalUrlExtractor.extract(''), isEmpty);
      expect(TerminalUrlExtractor.extract('   \n\r\n  '), isEmpty);
    });

    test('ignores bare scheme with no host', () {
      expect(TerminalUrlExtractor.extract('https://'), isEmpty);
    });

    test('does not pick up non-http schemes', () {
      expect(
        TerminalUrlExtractor.extract('ssh://user@host:22 and file:///tmp/x'),
        isEmpty,
      );
    });

    test('soft-wrapped text already rejoined by the buffer yields one URL', () {
      // `Buffer.getText()` rejoins PTY auto-wraps, so the url arrives intact.
      const rejoined =
          'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid+profile';
      final result = TerminalUrlExtractor.extract(rejoined);

      expect(result, hasLength(1));
      expect(result.single.url, rejoined);
    });

    test('rejoins a URL hard-wrapped at a query separator', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/oauth2/authorize?client_id=abc&\n'
        'scope=openid+profile&state=xyz',
      );

      expect(result, hasLength(1));
      expect(
        result.single.url,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid+profile&state=xyz',
      );
    });

    test('rejoins a URL hard-wrapped mid-path', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/oauth2/\n'
        'authorize/device?code=abc',
      );

      expect(result, hasLength(1));
      expect(
        result.single.url,
        'https://auth.example.com/oauth2/authorize/device?code=abc',
      );
    });

    test('rejoins a hard-wrapped URL that has a text prefix on the line', () {
      // 回归：行首有普通文案时（"open https://..."），拼接判定不能因为
      // URL 不位于行首就失效。
      final result = TerminalUrlExtractor.extract(
        'open https://auth.example.com/oauth2/authorize?client_id=abc&\n'
        'scope=openid&state=xyz',
      );

      expect(result, hasLength(1));
      expect(
        result.single.url,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid&state=xyz',
      );
    });

    test('rejoins a URL hard-wrapped across three lines', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/oauth2/\n'
        'authorize?client_id=abc&\n'
        'scope=openid',
      );

      expect(result, hasLength(1));
      expect(
        result.single.url,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid',
      );
    });

    test('does not glue an unrelated indented line onto a URL', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/login\n'
        '    Next step: paste the code',
      );

      expect(result, hasLength(1));
      expect(result.single.url, 'https://auth.example.com/login');
    });

    test('does not glue a following unrelated URL-free line', () {
      final result = TerminalUrlExtractor.extract(
        'https://auth.example.com/login\n'
        'Waiting for authentication...',
      );

      expect(result, hasLength(1));
      expect(result.single.url, 'https://auth.example.com/login');
    });

    test('keeps two separate hard-wrapped URLs distinct', () {
      final result = TerminalUrlExtractor.extract(
        'https://one.example.com/a?x=1\n'
        'https://two.example.com/b?y=2',
      );

      expect(result.map((e) => e.url), [
        'https://one.example.com/a?x=1',
        'https://two.example.com/b?y=2',
      ]);
    });
  });

  group('TerminalUrlExtractor.pickBest', () {
    test('returns null when there is no URL', () {
      expect(TerminalUrlExtractor.pickBest('nothing here'), isNull);
      expect(TerminalUrlExtractor.pickBest(''), isNull);
    });

    test('returns the last URL because the newest link is the valid one', () {
      final best = TerminalUrlExtractor.pickBest(
        'stale https://old.example.com/login\n'
        'fresh https://new.example.com/login?code=zzz',
      );

      expect(best!.url, 'https://new.example.com/login?code=zzz');
    });

    test('returns a fully normalized URL ready to copy verbatim', () {
      final best = TerminalUrlExtractor.pickBest(
        '\x1b[32m  https://auth.example.com/device?user_code=AB-12  \x1b[0m.',
      );

      expect(best!.url, 'https://auth.example.com/device?user_code=AB-12');
    });

    test('returns the single hard-wrapped URL rejoined for copying', () {
      final best = TerminalUrlExtractor.pickBest(
        'https://auth.example.com/oauth2/authorize?client_id=abc&\n'
        'scope=openid',
      );

      expect(
        best!.url,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid',
      );
    });
  });
}
