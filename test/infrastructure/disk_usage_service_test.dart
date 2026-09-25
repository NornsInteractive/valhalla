import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/system/disk_usage_service.dart';

void main() {
  test(
    'top-level directories sorted by actual usage, without root subtotal',
    () {
      final directories = DiskUsageService.parseDirectories(
        '2048\t/var\n1024\t/usr\n4096\t/\n9\t/var/log\nnoise\n',
      );
      expect(directories.map((d) => d.path), ['/var', '/usr']);
      expect(directories.first.usedKiB, 2048);
    },
  );
}
