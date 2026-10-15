import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/ssh/ssh_transfer_connection.dart';

void main() {
  SshTransferConnection connection(Uint8List fingerprint) =>
      SshTransferConnection(
        host: 'fixture',
        port: 22,
        username: 'fixture',
        password: null,
        privateKey: null,
        hostKeyType: 'ssh-ed25519',
        hostKeyFingerprint: fingerprint,
      );

  test('verified fingerprint is copied and immutable', () {
    final input = Uint8List.fromList([1, 2, 3]);
    final pin = connection(input);
    input[0] = 9;
    expect(
      pin.matchesHostKey('ssh-ed25519', Uint8List.fromList([1, 2, 3])),
      isTrue,
    );
    expect(() => pin.hostKeyFingerprint[0] = 9, throwsUnsupportedError);
  });

  test('different host key type, bytes or length are rejected', () {
    final pin = connection(Uint8List.fromList([1, 2, 3]));
    expect(
      pin.matchesHostKey('ssh-rsa', Uint8List.fromList([1, 2, 3])),
      isFalse,
    );
    expect(
      pin.matchesHostKey('ssh-ed25519', Uint8List.fromList([1, 9, 3])),
      isFalse,
    );
    expect(
      pin.matchesHostKey('ssh-ed25519', Uint8List.fromList([1, 2])),
      isFalse,
    );
    expect(
      pin.matchesHostKey('ssh-ed25519', Uint8List.fromList([1, 2, 3, 4])),
      isFalse,
    );
  });
}
