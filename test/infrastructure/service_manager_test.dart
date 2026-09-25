import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';

void main() {
  test('parses systemctl service rows', () {
    final services = SystemdServiceInfo.parseLines([
      'docker.service|Docker Application Container Engine|running|enabled',
      'nginx.service|A high performance web server|failed|disabled',
    ]);

    expect(services, hasLength(2));
    expect(services.first.isRunning, isTrue);
    expect(services.last.isFailed, isTrue);
    expect(services.last.isEnabled, isFalse);
  });
}
