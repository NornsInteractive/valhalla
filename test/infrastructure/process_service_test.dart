import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/system/process_service.dart';

void main() {
  test('parses ps output with command names containing spaces', () {
    final processes = ProcessInfo.parseLines([
      'PID|CPU|MEM|RSS|STAT|COMMAND',
      '42|12.5|3.2|4096|S|flutter tool daemon',
    ]);

    expect(processes.single.pid, 42);
    expect(processes.single.cpuPercent, 12.5);
    expect(processes.single.rssKiB, 4096);
    expect(processes.single.command, 'flutter tool daemon');
  });
}
