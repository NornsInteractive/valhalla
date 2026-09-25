import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/logging/sanitizer.dart';

void main() {
  test(
    'stream masks split secrets, CR progress and multi-line private keys',
    () async {
      final output = await LogSanitizer.stream(
        Stream.fromIterable([
          'progress 1\rpass',
          'word=sec',
          'ret\n',
          '-----BEGIN OPENSSH PRI',
          'VATE KEY-----\n',
          'body-one\nbody-two\n',
          '-----END OPENSSH PRIVATE KEY-----\n',
          'safe EOF',
        ]),
      ).join();
      expect(output, startsWith('progress 1\rpassword=******\n'));
      expect(output, isNot(contains('secret')));
      expect(output, isNot(contains('body-one')));
      expect(output, isNot(contains('body-two')));
      expect(output, endsWith('safe EOF'));
    },
  );

  test(
    'oversized streaming line is bounded and cannot expose following key content',
    () async {
      final output = await LogSanitizer.stream(
        Stream.fromIterable([
          'x' * (16 * 1024 + 1),
          '\nsecret-after-oversized-line\n',
        ]),
      ).join();
      expect(output, contains('oversized log line'));
      expect(output, isNot(contains('secret-after')));
      expect(output.length, lessThan(100));
    },
  );

  test('redacts URL credentials and incomplete private key blocks', () {
    final output = LogSanitizer.sanitize(
      'https://name:credential@example.org\n-----BEGIN OPENSSH PRIVATE KEY-----\nsecret-key-body',
    );
    expect(output, isNot(contains('credential')));
    expect(output, isNot(contains('secret-key-body')));
  });
  test('redacts structured, bearer, and flag credentials', () {
    final output = LogSanitizer.sanitize(
      'password=one Authorization: Bearer two {"token":"three"} --api-key=four',
    );
    expect(output, isNot(contains('one')));
    expect(output, isNot(contains('two')));
    expect(output, isNot(contains('three')));
    expect(output, isNot(contains('four')));
    expect(output, contains('password=******'));
    expect(output, contains('Authorization=******'));
    expect(output, contains('"token":"******"'));
    expect(output, contains('--api-key=******'));
  });
}
