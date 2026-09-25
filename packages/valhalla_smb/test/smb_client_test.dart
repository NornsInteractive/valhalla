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
}
