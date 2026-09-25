import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/security/command_safety.dart';

void main() {
  test('classifies dangerous command patterns', () {
    expect(
      CommandSafety.classify('docker system prune -a').isDangerous,
      isTrue,
    );
    expect(
      CommandSafety.classify('sudo systemctl restart nginx').isDangerous,
      isFalse,
    );
    expect(
      CommandSafety.classify('rm -rf /tmp/cache').level,
      CommandRiskLevel.danger,
    );
  });

  test('requires explicit confirmation for warning and danger commands', () {
    expect(CommandSafety.requiresConfirmation('reboot'), isTrue);
    expect(CommandSafety.requiresConfirmation('docker ps'), isFalse);
  });
}
