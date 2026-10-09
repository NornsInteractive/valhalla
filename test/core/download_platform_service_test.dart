import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:valhalla/core/services/download_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows reveal preserves special paths, missing-file fallback and errors',
    () async {
      if (!Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-reveal-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/中文 space & quote.txt');
      await file.writeAsString('download');
      final calls = <MethodCall>[];
      bool fail = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DownloadPlatformService.channel, (
            call,
          ) async {
            calls.add(call);
            if (fail) throw PlatformException(code: 'REVEAL_FAILED');
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DownloadPlatformService.channel, null),
      );
      final service = DownloadPlatformService();
      await service.revealFile(file.path);
      expect(calls.single.method, 'revealFile');
      expect(calls.single.arguments, {'path': file.path});
      await file.delete();
      await service.revealFile(file.path);
      expect(calls, hasLength(2));
      fail = true;
      await expectLater(
        service.revealFile(file.path),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        service.revealFile('${directory.path}/gone/file.txt'),
        throwsA(isA<FileSystemException>()),
      );
      expect(calls, hasLength(3));
    },
  );
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
