import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_config_codec.dart';

Future<LocalStorageService> _storage(Map<String, Object> raw) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(raw));
  return LocalStorageService(await SharedPreferences.getInstance());
}

const _server = ServerProfile(
  id: 'srv',
  name: 'Prod',
  host: 'a.example',
  username: 'root',
);
const _other = ServerProfile(
  id: 'other',
  name: 'Other',
  host: 'b.example',
  username: 'root',
);

void main() {
  group('WorkspaceConfigCodec', () {
    test('excludes window/cache/transfer/ssh keys', () async {
      final storage = await _storage({'valhalla_window_origin_x_v1': 10});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      expect(codec.export(), isEmpty);
    });

    test('only own-server agents exported', () async {
      final storage = await _storage({
        'valhalla_agents_v1': jsonEncode([
          {'id': 'a1', 'serverId': _server.id, 'name': 'A'},
          {'id': 'a2', 'serverId': _other.id, 'name': 'B'},
        ]),
      });
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final recs = codec.export().values.toList();
      expect(recs, hasLength(1));
      final item = recs.first['value']['item'] as Map;
      expect(item['serverId'], '@server');
    });

    test(
      'arbitrary text containing id is not transformed when not scoped',
      () async {
        final storage = await _storage({
          'unrelated_text': 'contains srv and @server',
        });
        final codec = WorkspaceConfigCodec(
          storage,
          _server,
          'dev',
          'desktop',
          includePreferences: true,
        );
        expect(codec.export(), isEmpty);
      },
    );

    test('hashed terminal/application keys export scoped record', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final key =
          'valhalla_file_bookmarks::${_server.id}::${codec.terminalKey}::${codec.applicationKey}';
      await storage.workspacePreferences.setString(key, jsonEncode({'b': 1}));
      final codec2 = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final recs = codec2.export();
      expect(recs, isNotEmpty);
    });

    test('apply invalid storageKey throws FormatException', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final rec = {
        'kind': 'config',
        'id': 'x',
        'value': {'storageKey': 'nope', 'item': {}},
        'deleted': false,
      };
      expect(codec.apply(rec), throwsA(isA<FormatException>()));
    });

    test('apply damaged array input throws', () async {
      final storage = await _storage({'valhalla_agents_v1': '{bad json'});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final rec = {
        'kind': 'config',
        'id': 'agent/a1',
        'value': {
          'storageKey': 'valhalla_agents_v1',
          'item': {'id': 'a1', 'serverId': '@server'},
        },
        'deleted': false,
      };
      expect(codec.apply(rec), throwsA(anything));
    });

    test(
      'global commands are owned by the first workspace and never leak',
      () async {
        final storage = await _storage({
          'valhalla_quick_commands_v1': jsonEncode([
            {'id': 'shared', 'title': 'Shared', 'command': 'echo hi'},
          ]),
        });
        final a = WorkspaceConfigCodec(
          storage,
          _server,
          'dev',
          'desktop',
          includePreferences: true,
          claimUnowned: true,
        );
        await a.claimOwnership();
        final b = WorkspaceConfigCodec(
          storage,
          _other,
          'dev',
          'desktop',
          includePreferences: true,
          claimUnowned: true,
        );
        expect(a.export().keys, contains('config\x00command/shared'));
        expect(b.export(), isEmpty);
      },
    );

    test('global non-SSH NAS sources are owned and do not leak', () async {
      final storage = await _storage({
        'valhalla_nas_sources_v1': jsonEncode([
          {
            'id': 'global-nas',
            'name': 'NAS',
            'type': 'smb',
            'sshServerId': null,
          },
        ]),
      });
      final a = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
        claimUnowned: true,
      );
      await a.claimOwnership();
      final b = WorkspaceConfigCodec(
        storage,
        _other,
        'dev',
        'desktop',
        includePreferences: true,
        claimUnowned: true,
      );
      expect(a.export().keys, contains('config\x00nas_source/global-nas'));
      expect(b.export(), isEmpty);
    });

    test('incoming storageKey must agree with record kind and id', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final wrongArray = {
        'kind': 'config',
        'id': 'command/c1',
        'value': {
          'storageKey': 'valhalla_agents_v1',
          'item': {'id': 'c1', 'serverId': '@server'},
        },
        'deleted': false,
      };
      expect(() => codec.validate(wrongArray), throwsA(isA<FormatException>()));
      expect(codec.apply(wrongArray), throwsA(isA<FormatException>()));

      final wrongMap = {
        'kind': 'config',
        'id': 'valhalla_chat_run_defaults_v1/other',
        'value': {
          'storageKey': 'valhalla_chat_run_defaults_v1',
          'entryKey': 'mine',
          'item': {'x': 1},
        },
        'deleted': false,
      };
      expect(() => codec.validate(wrongMap), throwsA(isA<FormatException>()));
    });

    test('preference id and value key must agree', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final record = {
        'kind': 'preference',
        'id': 'desktop/valhalla_theme_mode_v1',
        'value': {'key': 'valhalla_locale_v1', 'value': 'en'},
        'deleted': false,
      };
      expect(() => codec.validate(record), throwsA(isA<FormatException>()));
      expect(codec.apply(record), throwsA(isA<FormatException>()));
    });

    test('draft id and value device/key must agree', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      final record = {
        'kind': 'draft',
        'id': 'dev/valhalla_chat_draft_v1::srv',
        'value': {
          'key': 'valhalla_chat_draft_v1::srv',
          'deviceId': 'other',
          'value': {'string': 'x'},
        },
        'deleted': false,
      };
      expect(codec.handles(record), isFalse);
      expect(
        () => codec.validate(record, restoreDraft: true),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'secrets, trust, keys, hostnames and window state never export',
      () async {
        final storage = await _storage({
          'valhalla_servers_v1': jsonEncode([
            {'id': 'srv', 'host': 'a.example', 'username': 'root'},
          ]),
          'valhalla_private_key_v1::srv': 'PRIVATE',
          'valhalla_host_key_trust_v1::srv': 'trusted',
          'valhalla_known_hosts_v1': 'fingerprint',
          'valhalla_window_width_v1': 1200,
          'valhalla_window_origin_x_v1': 10,
          'valhalla_transfer_queue_v1': '[]',
          'valhalla_nas_credentials_v1::global-nas': '{"password":"x"}',
        });
        final codec = WorkspaceConfigCodec(
          storage,
          _server,
          'dev',
          'desktop',
          includePreferences: true,
          claimUnowned: true,
        );
        expect(codec.export(), isEmpty);
      },
    );

    test('other device class preference is not handled', () async {
      final storage = await _storage({});
      final codec = WorkspaceConfigCodec(
        storage,
        _server,
        'dev',
        'desktop',
        includePreferences: true,
      );
      expect(
        codec.handles({
          'kind': 'preference',
          'id': 'tablet/valhalla_theme_mode_v1',
          'value': {'key': 'valhalla_theme_mode_v1', 'value': 'dark'},
        }),
        isFalse,
      );
    });

    test(
      'long path/JSON scope ids round trip without mutation of inner text',
      () async {
        final longId = 'x' * 200;
        final storage = await _storage({});
        final codec = WorkspaceConfigCodec(
          storage,
          _server,
          'dev',
          'desktop',
          includePreferences: true,
        );
        final key =
            'valhalla_file_bookmarks::${_server.id}::${codec.terminalKey}::$longId';
        await storage.workspacePreferences.setString(
          key,
          jsonEncode({'note': 'srv literal'}),
        );
        final recs = WorkspaceConfigCodec(
          storage,
          _server,
          'dev',
          'desktop',
          includePreferences: true,
        ).export();
        expect(recs, isNotEmpty);
        final rec = recs.values.first;
        // inner literal text preserved in value
        final decoded = jsonEncode(rec);
        expect(decoded.contains('srv literal'), isTrue);
      },
    );
  });
}
