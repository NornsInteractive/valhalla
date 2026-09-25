import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/server_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';

ServerProfile _server(String id, String name) =>
    ServerProfile(id: id, name: name, host: '10.0.0.1', username: 'root');

Future<ServerRepository> _repository({List<ServerProfile>? servers}) async {
  SharedPreferences.setMockInitialValues({
    if (servers != null)
      'valhalla_servers_v1': jsonEncode(
        servers.map((s) => s.toJson()).toList(),
      ),
  });
  final prefs = await SharedPreferences.getInstance();
  return ServerRepository(LocalStorageService(prefs), SecureStorageService());
}

void main() {
  test(
    'starts with an empty server list instead of injecting a demo server',
    () async {
      final repository = await _repository();

      expect(repository.getAllServers(), isEmpty);
    },
  );

  test('deleting the last server leaves the list empty', () async {
    final repository = await _repository(
      servers: [_server('server-1', 'Server 1')],
    );

    await repository.deleteServer('server-1');

    expect(repository.getAllServers(), isEmpty);
  });
}
