import 'dart:convert';
import 'dart:typed_data';
import '../../data/models/host_key_entry.dart';
import '../../data/storage/local_storage_service.dart';
import '../../core/errors/app_exceptions.dart';

class SSHHostKeyVerifier {
  final LocalStorageService _storage;

  SSHHostKeyVerifier(this._storage);

  /// 校验从远端获取的 Host Key 指纹
  Future<bool> verifyHostKey({
    required String host,
    required int port,
    required String keyType,
    required Uint8List fingerprint,
    Future<bool> Function(
      String host,
      String keyType,
      String fingerprintSha256,
    )?
    onConfirmFirstTime,
  }) async {
    final hostPort = '$host:$port';
    final legacyFingerprint =
        'SHA256:${base64.encode(fingerprint).replaceAll('=', '')}';
    // dartssh2 4.x supplies the OpenSSH string as UTF-8, not digest bytes.
    final encoded = utf8.decode(fingerprint, allowMalformed: true);
    final fingerprintSha256 =
        RegExp(r'^SHA256:[A-Za-z0-9+/]{43}=?$').hasMatch(encoded)
        ? encoded.replaceAll('=', '')
        : legacyFingerprint;
    final knownKeys = _storage.getHostKeys();

    if (knownKeys.containsKey(hostPort)) {
      final known = knownKeys[hostPort]!;
      if (known.fingerprintSha256 == fingerprintSha256 ||
          known.fingerprintSha256 == legacyFingerprint) {
        if (known.fingerprintSha256 != fingerprintSha256) {
          // Upgrade only an exact old encoding of this same key; never re-trust a changed key.
          await _storage.saveHostKey(
            HostKeyEntry(
              hostPort: known.hostPort,
              keyType: known.keyType,
              fingerprintSha256: fingerprintSha256,
              trustedAt: known.trustedAt,
            ),
          );
        }
        return true;
      } else {
        // 指纹改变，疑似中间人攻击，阻断连接
        throw HostKeyMismatchException(
          host: hostPort,
          expectedFingerprint: known.fingerprintSha256,
          actualFingerprint: fingerprintSha256,
        );
      }
    }

    // 首次连接该主机
    var approved = false;
    if (onConfirmFirstTime != null) {
      approved = await onConfirmFirstTime(hostPort, keyType, fingerprintSha256);
    }

    if (approved) {
      await _storage.saveHostKey(
        HostKeyEntry(
          hostPort: hostPort,
          keyType: keyType,
          fingerprintSha256: fingerprintSha256,
          trustedAt: DateTime.now(),
        ),
      );
      return true;
    }

    return false;
  }
}
