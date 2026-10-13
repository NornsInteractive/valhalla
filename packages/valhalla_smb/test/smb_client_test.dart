import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla_smb/valhalla_smb.dart';

void main() {
  test('share-relative paths reject traversal and embedded terminators', () {
    expect(SmbClient.normalizePath('/照片//./holiday.mp4'), '照片/holiday.mp4');
    expect(SmbClient.normalizePath('/'), '');
    for (final path in ['/../secret', 'a/../../secret', 'a\\b', 'a\x00b']) {
      expect(() => SmbClient.normalizePath(path), throwsA(isA<SmbException>()));
    }
  });

  test('invalid ranges fail before attempting native IO', () async {
    const client = SmbClient(
      SmbConnection(host: 'unused', share: 'media', username: '', password: ''),
    );
    await expectLater(
      client.read('/file.mp4', start: -1),
      emitsError(isA<SmbException>()),
    );
    await expectLater(
      client.read('/file.mp4', start: 9, end: 8),
      emitsError(isA<SmbException>()),
    );
    expect(await client.read('/file.mp4', start: 8, end: 8).toList(), isEmpty);
  });

  test(
    'single-layer list validates paths before native library loading',
    () async {
      const client = SmbClient(
        SmbConnection(
          host: 'unused',
          share: 'media',
          username: '',
          password: '',
        ),
        libraryPath: '/not-a-native-library',
      );
      for (final path in [
        '/../secret',
        'base/../../secret',
        r'base\secret',
        'base\x00secret',
      ]) {
        await expectLater(
          client.list(path).drain<void>(),
          throwsA(
            isA<SmbException>().having(
              (error) => error.message,
              'code',
              'SMB_INVALID_PATH',
            ),
          ),
        );
      }
    },
  );

  test(
    'native list is bounded and nonrecursive, cancellation releases connection',
    () async {
      final client = SmbClient(
        const SmbConnection(
          host: '127.0.0.1:14455',
          share: 'media',
          username: 'valhalla',
          password: 'test-password',
        ),
        libraryPath: Platform.environment['VALHALLA_SMB_TEST_LIBRARY'],
      );
      final pages = await client.list('/').toList();
      final entries = pages.expand((page) => page).toList();
      expect(entries, hasLength(2503));
      expect(pages.length, greaterThanOrEqualTo(4));
      expect(pages.every((page) => page.length <= 819), isTrue);
      expect(
        entries.any((entry) => entry.path == 'excluded' && entry.isDirectory),
        isTrue,
      );
      expect(entries.any((entry) => entry.path.contains('/')), isFalse);
      expect(entries.any((entry) => entry.path == '照片.jpg'), isTrue);
      expect(
        (await client.list('/excluded').toList())
            .expand((page) => page)
            .single
            .path,
        'excluded/skip.mp3',
      );
      final walked = (await client.walk(roots: ['/excluded']).toList()).expand(
        (page) => page,
      );
      expect(walked.single.path, 'excluded/skip.mp3');

      final iterator = StreamIterator(client.list('/'));
      expect(await iterator.moveNext(), isTrue);
      await iterator.cancel().timeout(const Duration(seconds: 5));
      await client.probe().timeout(const Duration(seconds: 5));

      final cancellation = Completer<void>();
      final cancelled = StreamIterator(
        client.list('/', cancelled: cancellation.future),
      );
      expect(await cancelled.moveNext(), isTrue);
      cancellation.complete();
      await expectLater(cancelled.moveNext(), throwsA(isA<SmbException>()));
      await cancelled.cancel();
      await client.probe().timeout(const Duration(seconds: 5));
    },
    skip: Platform.environment['VALHALLA_SMB_TEST_LIBRARY'] == null
        ? 'Requires local tool/test_server.py and VALHALLA_SMB_TEST_LIBRARY'
        : false,
  );
}
