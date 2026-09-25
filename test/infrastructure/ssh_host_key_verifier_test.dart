import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/models/host_key_entry.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStorageService storage;
  late SSHHostKeyVerifier verifier;
  final fingerprint =
      'SHA256:${base64.encode(Uint8List(32)).replaceAll('=', '')}';
  final bytes = Uint8List.fromList(utf8.encode(fingerprint));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    verifier = SSHHostKeyVerifier(storage);
  });
  test(
    'new trust displays and stores the actual OpenSSH SHA256 fingerprint',
    () async {
      expect(
        await verifier.verifyHostKey(
          host: 'fixture',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: bytes,
          onConfirmFirstTime: (_, _, actual) async => actual == fingerprint,
        ),
        isTrue,
      );
      expect(
        storage.getHostKeys()['fixture:22']!.fingerprintSha256,
        fingerprint,
      );
    },
  );
  test(
    'old double-encoded trust upgrades only the identical key and keeps trust date',
    () async {
      final trustedAt = DateTime.utc(2025);
      await storage.saveHostKey(
        HostKeyEntry(
          hostPort: 'fixture:22',
          keyType: 'ssh-ed25519',
          fingerprintSha256:
              'SHA256:${base64.encode(bytes).replaceAll('=', '')}',
          trustedAt: trustedAt,
        ),
      );
      expect(
        await verifier.verifyHostKey(
          host: 'fixture',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: bytes,
          onConfirmFirstTime: (_, _, _) async =>
              fail('existing trust must not prompt'),
        ),
        isTrue,
      );
      final saved = storage.getHostKeys()['fixture:22']!;
      expect(saved.fingerprintSha256, fingerprint);
      expect(saved.trustedAt, trustedAt);
      await expectLater(
        verifier.verifyHostKey(
          host: 'fixture',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: Uint8List.fromList(
            utf8.encode(fingerprint.replaceFirst('A', 'B', 7)),
          ),
        ),
        throwsA(isA<HostKeyMismatchException>()),
      );
      expect(
        storage.getHostKeys()['fixture:22']!.fingerprintSha256,
        fingerprint,
      );
    },
  );
  test('raw SHA256 digest input remains compatible', () async {
    expect(
      await verifier.verifyHostKey(
        host: 'fixture',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: Uint8List(32),
        onConfirmFirstTime: (_, _, actual) async => actual == fingerprint,
      ),
      isTrue,
    );
  });
}
