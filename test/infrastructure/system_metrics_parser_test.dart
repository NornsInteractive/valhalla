import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';

void main() {
  test('parses procfs metrics snapshot', () {
    const raw = '''
cpu  100 20 30 850 0 0 0 0 0 0
MemTotal:       8000000 kB
MemAvailable:   2000000 kB
LoadAvg: 1.00 0.50 0.25
Uptime: 12345.0
Disk: 45%
''';

    final metrics = SystemMetricsSnapshot.parse(raw);

    expect(metrics.memoryUsedRatio, closeTo(0.75, 0.001));
    expect(metrics.memoryTotalBytes, 8000000 * 1024);
    expect(metrics.memoryUsedBytes, 6000000 * 1024);
    expect(metrics.load1, 1.0);
    expect(metrics.uptimeSeconds, 12345);
    expect(metrics.rootDiskUsedPercent, 45);
  });

  test('CPU occupancy uses tick delta rather than lifetime average', () {
    final previous = SystemMetricsSnapshot.parse(
      'cpu  100 0 0 900 0 0 0 0 0 0',
    );
    final current = SystemMetricsSnapshot.parse('cpu  160 0 0 940 0 0 0 0 0 0');
    final delta = current.withCpuUsageSince(previous);
    expect(delta.cpuUsedRatio, closeTo(0.6, 0.001));
    expect(delta.memoryTotalBytes, current.memoryTotalBytes);
  });

  test('default route network rate uses counter deltas and elapsed time', () {
    final before = SystemMetricsSnapshot.parse('''
NetworkDefault: eth0
Network: lo 1000 1000
Network: eth0 100 300
Network: docker0 500 600
''');
    final after = SystemMetricsSnapshot.parse('''
NetworkDefault: eth0
Network: lo 1500 1500
Network: eth0 2100 1300
Network: docker0 900 900
''').withCpuUsageSince(before, elapsed: const Duration(seconds: 2));
    expect(after.primaryNetworkInterface, 'eth0');
    expect(after.networkRates['eth0']!.rxBytesPerSecond, 1000);
    expect(after.networkRates['eth0']!.txBytesPerSecond, 500);
    expect(after.networkRates['docker0']!.rxBytesPerSecond, 200);
  });

  test('network fallback, initial sample, and reset avoid invented speed', () {
    final before = SystemMetricsSnapshot.parse('Network: eth1 1000 2000');
    expect(before.primaryNetworkInterface, 'eth1');
    expect(before.networkRates, isEmpty);
    final after = SystemMetricsSnapshot.parse(
      'Network: eth1 20 30',
    ).withCpuUsageSince(before, elapsed: const Duration(seconds: 3));
    expect(after.networkRates, isEmpty);
    expect(
      SystemMetricsSnapshot.parse('Network: lo 20 30').primaryNetworkInterface,
      isNull,
    );
  });
}
