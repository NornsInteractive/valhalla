import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/file_integrity.dart';
import 'package:valhalla/core/utils/transfer_progress.dart';

void main() {
  test(
    'file SHA runs on disk contents and propagates missing-file errors',
    () async {
      final dir = await Directory.systemTemp.createTemp('valhalla_hash_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/sample');
      await file.writeAsString('abc');
      expect(
        await fileSha256(file.path),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      await file.delete();
      await expectLater(
        fileSha256(file.path),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('progress bursts are throttled but forced final bytes publish', () {
    final meter = TransferProgressMeter();
    expect(meter.sample(1), isTrue);
    for (var i = 2; i < 1000; i++) {
      expect(meter.sample(i), isFalse);
    }
    expect(meter.sample(1000, force: true), isTrue);
    expect(meter.bytesPerSecond, isNonNegative);
    expect(meter.sample(0, force: true), isTrue);
    expect(meter.bytesPerSecond, 0);
  });
}
