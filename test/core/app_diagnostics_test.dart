import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/app_diagnostics.dart';

void main() {
  test(
    'rotates three bounded files and redacts persisted and exported text',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'diagnostics-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = AppDiagnostics(
        directoryProvider: () async => directory,
        maxFileBytes: 512,
      );
      await service.initialize();
      for (var n = 0; n < 15; n++) {
        await service.record(
          'test',
          'event=$n password=do-not-save https://user:do-not-save@example.org ${'文' * 400}',
        );
      }
      final files = await directory
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      expect(files, hasLength(3));
      for (final file in files) {
        expect(await file.length(), lessThanOrEqualTo(512));
        expect(await file.readAsString(), isNot(contains('do-not-save')));
      }
      final all = await service.read(maxBytes: 1536);
      expect(all, contains('event=14'));
      expect(all, isNot(contains('event=0 ')));
      expect(await service.read(maxBytes: 64), isNotEmpty);
    },
  );

  test(
    'error storm is bounded and disk errors do not recurse into global handler',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'diagnostics-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = AppDiagnostics(
        directoryProvider: () async => directory,
        maxFileBytes: 4096,
      );
      await service.initialize();
      await Future.wait(
        List.generate(1000, (i) => service.record('storm', 'event=$i')),
      );
      expect(await service.read(), contains('entries dropped'));
      await directory.delete(recursive: true);
      await service.record('disk-failed', StateError('test'));
      expect(service.storageError, isNotNull);
      await directory.create();
    },
  );
}
