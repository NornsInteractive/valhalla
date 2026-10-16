import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

Future<SSHClient> connectSshWorker(SshTransferConnection connection) async {
  final socket = await SSHSocket.connect(
    connection.host,
    connection.port,
    timeout: const Duration(seconds: 30),
  );
  SSHClient? client;
  try {
    client = SSHClient(
      socket,
      username: connection.username,
      identities: connection.privateKey == null
          ? null
          : SSHKeyPair.fromPem(connection.privateKey!),
      onPasswordRequest: () => connection.password ?? '',
      onVerifyHostKey: connection.matchesHostKey,
    );
    await client.authenticated.timeout(const Duration(seconds: 30));
    return client;
  } catch (_) {
    try {
      await client?.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    socket.destroy();
    rethrow;
  }
}

/// In-memory authentication snapshot of an already verified SSH connection.
/// Never persisted or included in diagnostics.
class SshTransferConnection {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String hostKeyType;
  final Uint8List hostKeyFingerprint;

  SshTransferConnection({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.privateKey,
    required this.hostKeyType,
    required Uint8List hostKeyFingerprint,
  }) : hostKeyFingerprint = Uint8List.fromList(
         hostKeyFingerprint,
       ).asUnmodifiableView();

  bool matchesHostKey(String type, Uint8List fingerprint) {
    if (type != hostKeyType ||
        fingerprint.length != hostKeyFingerprint.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < fingerprint.length; i++) {
      difference |= fingerprint[i] ^ hostKeyFingerprint[i];
    }
    return difference == 0;
  }
}
