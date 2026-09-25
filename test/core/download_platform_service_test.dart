import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/download_platform_service.dart';

void main() {
  test(
    'concurrent reservations and existing files never overwrite names',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-download-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/report.txt').writeAsString('existing');
      final service = DownloadPlatformService(
        directoryProvider: () async => directory,
      );
      final paths = await Future.wait([
        service.reservePath('report.txt'),
        service.reservePath('report.txt'),
      ]);
      expect(paths.toSet(), hasLength(2));
      expect(paths, isNot(contains('${directory.path}/report.txt')));
      expect(
        await File('${directory.path}/report.txt').readAsString(),
        'existing',
      );
    },
  );

  test('filename cannot escape the selected directory', () async {
    final directory = await Directory.systemTemp.createTemp(
      'valhalla-download-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = DownloadPlatformService(
      directoryProvider: () async => directory,
    );
    final path = await service.reservePath('../evil/file.txt');
    expect(File(path).parent.path, directory.path);
    await expectLater(service.reservePath('..'), throwsFormatException);
  });
}
