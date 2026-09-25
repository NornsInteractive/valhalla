import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';

void main() {
  group('SecureStorageService Tests', () {
    late SecureStorageService service;

    setUp(() {
      service = SecureStorageService();
    });

    test('should save and retrieve password using memory fallback', () async {
      await service.savePassword('server-1', 'SuperSecretPass123!');
      final pass = await service.getPassword('server-1');
      expect(pass, equals('SuperSecretPass123!'));
    });

    test('should save and retrieve private key', () async {
      const keyPem =
          '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAA...\n-----END OPENSSH PRIVATE KEY-----';
      await service.savePrivateKey('server-1', keyPem);
      final key = await service.getPrivateKey('server-1');
      expect(key, equals(keyPem));
    });

    test('should delete credentials', () async {
      await service.savePassword('server-2', 'pwd');
      await service.savePrivateKey('server-2', 'key');

      await service.deleteCredentials('server-2');
      expect(await service.getPassword('server-2'), isNull);
      expect(await service.getPrivateKey('server-2'), isNull);
    });

    test('should save and retrieve sudo password separately', () async {
      await service.saveSudoPassword('server-3', 'sudo-secret');
      expect(await service.getSudoPassword('server-3'), 'sudo-secret');
      expect(await service.getPassword('server-3'), isNull);
    });
  });
}
