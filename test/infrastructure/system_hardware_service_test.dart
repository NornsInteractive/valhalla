import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/system/system_hardware_service.dart';

void main() {
  test('parses hardware fields and leaves missing fields unknown', () {
    final info = SystemHardwareInfo.parse('''CPU_MODEL=AMD EPYC 7B13
CPU_CORES=8
MEMORY_KIB=16384000
ROOT_KIB=104857600
DISTRIBUTION="Ubuntu 24.04 LTS"
KERNEL=6.8.0-generic
''');
    expect(info.cpuModel, 'AMD EPYC 7B13');
    expect(info.cpuCores, 8);
    expect(info.memoryTotalKiB, 16384000);
    expect(info.rootDiskTotalKiB, 104857600);
    expect(info.distribution, 'Ubuntu 24.04 LTS');
    expect(info.kernel, '6.8.0-generic');
    final missing = SystemHardwareInfo.parse(
      'CPU_MODEL=\nCPU_CORES=not-a-number',
    );
    expect(missing.cpuModel, isNull);
    expect(missing.cpuCores, isNull);
  });
}
