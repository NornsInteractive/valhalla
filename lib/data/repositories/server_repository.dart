import '../models/server_profile.dart';
import '../storage/local_storage_service.dart';
import '../storage/secure_storage_service.dart';

class ServerRepository {
  final LocalStorageService _localStorage;
  final SecureStorageService _secureStorage;

  ServerRepository(this._localStorage, this._secureStorage);

  List<ServerProfile> getAllServers() => _localStorage.getServers();

  Future<void> addOrUpdateServer(
    ServerProfile server, {
    String? password,
    String? privateKey,
  }) async {
    final list = _localStorage.getServers().toList();
    final index = list.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      list[index] = server;
    } else {
      list.add(server);
    }
    await _localStorage.saveServers(list);

    if (password != null && password.isNotEmpty) {
      await _secureStorage.savePassword(server.id, password);
    }
    if (privateKey != null && privateKey.isNotEmpty) {
      await _secureStorage.savePrivateKey(server.id, privateKey);
    }
  }

  Future<void> deleteServer(String serverId) async {
    final original = _localStorage.getServers();
    final activeId = _localStorage.getActiveServerId();
    final lastId = _localStorage.getLastConnectedServerId();
    final defaultId = _localStorage.getAutoConnectServerId();
    final list = original.where((s) => s.id != serverId).toList();
    try {
      await _localStorage.saveServers(list);
      if (lastId == serverId) {
        await _localStorage.setLastConnectedServerId(null);
      }
      if (defaultId == serverId) {
        await _localStorage.setAutoConnectServerId(null);
      }
      if (activeId == serverId) {
        await _localStorage.setActiveServerId(list.firstOrNull?.id);
      }
    } catch (_) {
      // Keep the configuration retryable if a dependent preference write fails.
      await _localStorage.saveServers(original);
      await _localStorage.setActiveServerId(activeId);
      await _localStorage.setLastConnectedServerId(lastId);
      await _localStorage.setAutoConnectServerId(defaultId);
      rethrow;
    }
    await _secureStorage.deleteCredentials(serverId);
    await _localStorage.clearServerPageCache(serverId);
    await _localStorage.clearServerTransferRecords(serverId);
  }

  String? getActiveServerId() => _localStorage.getActiveServerId();

  Future<void> setActiveServerId(String? id) =>
      _localStorage.setActiveServerId(id);

  Future<String?> getPassword(String serverId) =>
      _secureStorage.getPassword(serverId);

  Future<String?> getPrivateKey(String serverId) =>
      _secureStorage.getPrivateKey(serverId);

  Future<void> saveSudoPassword(String serverId, String password) =>
      _secureStorage.saveSudoPassword(serverId, password);

  Future<String?> getSudoPassword(String serverId) =>
      _secureStorage.getSudoPassword(serverId);

  /// 最近一次成功连接的配置 id；null 表示还没有成功连接过。
  String? getLastConnectedServerId() =>
      _localStorage.getLastConnectedServerId();

  Future<void> setLastConnectedServerId(String serverId) =>
      _localStorage.setLastConnectedServerId(serverId);
}
