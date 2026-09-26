import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

void main() {
  group('ServerProfile mosh fields', () {
    test('JSON roundtrip keeps mosh configuration', () {
      final server = ServerProfile(
        id: 'srv-mosh',
        name: 'roaming-box',
        host: '203.0.113.7',
        username: 'root',
        moshEnabled: true,
        moshServerPath: '/usr/local/bin/mosh-server',
        moshPortRange: '61000:62000',
      );

      final parsed = ServerProfile.fromJson(server.toJson());

      expect(parsed.moshEnabled, isTrue);
      expect(parsed.moshServerPath, '/usr/local/bin/mosh-server');
      expect(parsed.moshPortRange, '61000:62000');
    });

    test('defaults apply when mosh fields are omitted', () {
      final server = ServerProfile(
        id: 'srv-plain',
        name: 'plain',
        host: '10.0.0.1',
        username: 'root',
      );

      expect(server.moshEnabled, isFalse);
      expect(server.moshServerPath, isNull);
      expect(server.moshPortRange, isNull);

      final parsed = ServerProfile.fromJson(server.toJson());
      expect(parsed.moshEnabled, isFalse);
    });

    test('copyWith carries and overrides mosh fields', () {
      final base = ServerProfile(
        id: 'srv-1',
        name: 'a',
        host: '10.0.0.1',
        username: 'root',
      );

      final enabled = base.copyWith(moshEnabled: true);
      expect(enabled.moshEnabled, isTrue);
      expect(enabled.moshServerPath, isNull);

      final customized = enabled.copyWith(
        moshServerPath: '/opt/mosh/bin/mosh-server',
        moshPortRange: '60001',
      );
      expect(customized.moshServerPath, '/opt/mosh/bin/mosh-server');
      expect(customized.moshPortRange, '60001');
    });

    test('legacy storage JSON without mosh keys loads with defaults', () async {
      SharedPreferences.setMockInitialValues({
        'valhalla_servers_v1': jsonEncode([
          {
            'id': 'srv-legacy',
            'name': 'old-server',
            'host': '192.168.1.10',
            'port': 22,
            'username': 'root',
            'authType': 'password',
            'tags': ['Linux'],
            'lastConnectedAt': '2026-01-02T03:04:05.000',
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final loaded = storage.getServers().single;

      expect(loaded.id, 'srv-legacy');
      expect(loaded.name, 'old-server');
      expect(loaded.lastConnectedAt, DateTime(2026, 1, 2, 3, 4, 5));
      expect(loaded.moshEnabled, isFalse);
      expect(loaded.moshServerPath, isNull);
      expect(loaded.moshPortRange, isNull);
    });

    test(
      'storage round-trips mosh fields through saveServers/getServers',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);

        const server = ServerProfile(
          id: 'srv-mosh',
          name: 'roaming-box',
          host: '203.0.113.7',
          username: 'root',
          moshEnabled: true,
          moshServerPath: '/usr/local/bin/mosh-server',
          moshPortRange: '61000:62000',
        );
        await storage.saveServers([server]);

        final loaded = storage.getServers().single;

        expect(loaded.moshEnabled, isTrue);
        expect(loaded.moshServerPath, '/usr/local/bin/mosh-server');
        expect(loaded.moshPortRange, '61000:62000');
      },
    );
  });
}
