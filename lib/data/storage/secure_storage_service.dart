import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/nas_source.dart';

/// 加密凭据存储服务，基于系统 KeyStore/KeyChain，带有内存回退容灾
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};

  Future<void> saveNasCredentials(String sourceId, NasCredentials value) async {
    // NAS secrets must not silently disappear into an in-memory fallback.
    await _storage.write(
      key: 'valhalla_nas_${sourceId}_credentials',
      value: jsonEncode(value.toJson()),
    );
  }

  Future<NasCredentials> getNasCredentials(String sourceId) async {
    final raw = await _storage.read(
      key: 'valhalla_nas_${sourceId}_credentials',
    );
    return raw == null
        ? const NasCredentials()
        : NasCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> deleteNasCredentials(String sourceId) =>
      _storage.delete(key: 'valhalla_nas_${sourceId}_credentials');

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
          );

  Future<void> savePassword(String serverId, String password) async {
    final key = 'valhalla_server_${serverId}_password';
    try {
      await _storage.write(key: key, value: password);
    } catch (_) {
      _memoryFallback[key] = password;
    }
  }

  Future<String?> getPassword(String serverId) async {
    final key = 'valhalla_server_${serverId}_password';
    try {
      final val = await _storage.read(key: key);
      return val ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> savePrivateKey(String serverId, String keyContent) async {
    final key = 'valhalla_server_${serverId}_private_key';
    try {
      await _storage.write(key: key, value: keyContent);
    } catch (_) {
      _memoryFallback[key] = keyContent;
    }
  }

  Future<String?> getPrivateKey(String serverId) async {
    final key = 'valhalla_server_${serverId}_private_key';
    try {
      final val = await _storage.read(key: key);
      return val ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> deleteCredentials(String serverId) async {
    final pwdKey = 'valhalla_server_${serverId}_password';
    final pKey = 'valhalla_server_${serverId}_private_key';
    try {
      await _storage.delete(key: pwdKey);
      await _storage.delete(key: pKey);
    } catch (_) {}
    _memoryFallback.remove(pwdKey);
    _memoryFallback.remove(pKey);
  }

  Future<void> saveSudoPassword(String serverId, String password) async {
    final key = 'valhalla_server_${serverId}_sudo_password';
    try {
      await _storage.write(key: key, value: password);
    } catch (_) {
      _memoryFallback[key] = password;
    }
  }

  Future<String?> getSudoPassword(String serverId) async {
    final key = 'valhalla_server_${serverId}_sudo_password';
    try {
      return await _storage.read(key: key) ?? _memoryFallback[key];
    } catch (_) {
      return _memoryFallback[key];
    }
  }
}
