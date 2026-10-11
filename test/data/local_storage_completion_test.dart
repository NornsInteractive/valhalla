import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _server = ServerProfile(
    id: 'srv', name: 'Prod', host: 'a.example', username: 'root');

/// The same profile id with a different connection identity.
const _otherHost =
    ServerProfile(id: 'srv', name: 'Prod', host: 'b.example', username: 'root');

Future<LocalStorageService> _storage({Map<String, Object> raw = const {}}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(raw));
  return LocalStorageService(await SharedPreferences.getInstance());
}

/// Writes a page cache record with an explicit timestamp, bypassing the writer.
Future<void> _seedPageCache(
    LocalStorageService storage, ServerProfile server, String page,
    {required DateTime savedAt, required Map<String, dynamic> payload}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = prefs.getKeys().firstWhere(
      (k) => k.startsWith('valhalla_page_cache_v1::${server.id}::') && k.endsWith('::$page'));
  await prefs.setString(key, jsonEncode({'savedAt': savedAt.toIso8601String(), 'payload': payload}));
}

void main() {
  group('page cache size ceiling', () {
    test('a record at or below 256 KiB round trips its payload', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'rows': ['a', 'b'], 'cursor': 7});
      final cached = storage.getPageCache(_server, 'files');
      expect(cached?['payload'],
          {'rows': ['a', 'b'], 'cursor': 7});
    });

    test('a payload past 256 KiB is dropped instead of stored', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'blob': 'x' * (256 * 1024)});
      expect(storage.getPageCache(_server, 'files'), isNull);
    });

    test('a payload just under the ceiling is still stored', () async {
      final storage = await _storage();
      // The envelope adds savedAt and the payload wrapper; leave headroom.
      await storage.savePageCache(_server, 'files', {'blob': 'x' * (256 * 1024 - 128)});
      expect(storage.getPageCache(_server, 'files'), isNotNull);
    });

    test('only the twelve most recent pages are retained', () async {
      final storage = await _storage();
      for (var i = 0; i < 14; i++) {
        await storage.savePageCache(_server, 'page$i', {'index': i});
      }
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.contains('page')).length;
      expect(keys, 12);
      expect(storage.getPageCache(_server, 'page13'), isNotNull);
      expect(storage.getPageCache(_server, 'page0'), isNull);
    });

    test('clearing a server drops only that server cache', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      await storage.savePageCache(_otherHost, 'files', {'index': 2});
      await storage.clearServerPageCache('srv');
      expect(storage.getPageCache(_server, 'files'), isNull);
      expect(storage.getPageCache(_otherHost, 'files'), isNull);
    });
  });

  group('page cache expiry', () {
    test('a record older than seven days is treated as absent', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      await _seedPageCache(storage, _server, 'files',
          savedAt: DateTime.now().subtract(const Duration(days: 7, seconds: 1)),
          payload: {'index': 1});
      expect(storage.getPageCache(_server, 'files'), isNull);
    });

    test('a record inside the seven day window is served', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      await _seedPageCache(storage, _server, 'files',
          savedAt: DateTime.now().subtract(const Duration(days: 6, hours: 23)),
          payload: {'index': 2});
      expect(storage.getPageCache(_server, 'files')?['payload'], {'index': 2});
    });

    test('an unparseable timestamp is treated as absent', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().firstWhere((k) => k.contains('valhalla_page_cache_v1'));
      await prefs.setString(key, jsonEncode({'savedAt': 'not-a-date', 'payload': {'index': 1}}));
      expect(storage.getPageCache(_server, 'files'), isNull);
    });

    test('pages are cached per page name', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      expect(storage.getPageCache(_server, 'docker'), isNull);
    });
  });

  group('connection identity separation', () {
    test('a changed host starts a separate page cache', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      expect(storage.getPageCache(_otherHost, 'files'), isNull);
      await storage.savePageCache(_otherHost, 'files', {'index': 2});
      expect(storage.getPageCache(_server, 'files')?['payload'], {'index': 1});
      expect(storage.getPageCache(_otherHost, 'files')?['payload'], {'index': 2});
    });

    test('a changed port or auth type starts a separate page cache', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      const otherPort = ServerProfile(
          id: 'srv', name: 'Prod', host: 'a.example', port: 2222, username: 'root');
      const otherAuth = ServerProfile(
          id: 'srv', name: 'Prod', host: 'a.example', username: 'root', authType: AuthType.privateKey);
      expect(storage.getPageCache(otherPort, 'files'), isNull);
      expect(storage.getPageCache(otherAuth, 'files'), isNull);
    });

    test('a display-name only change keeps the same cache', () async {
      final storage = await _storage();
      await storage.savePageCache(_server, 'files', {'index': 1});
      const renamed = ServerProfile(
          id: 'srv', name: 'Renamed', host: 'a.example', username: 'root');
      expect(storage.getPageCache(renamed, 'files')?['payload'], {'index': 1});
    });

    test('transfer records are separated the same way', () async {
      final storage = await _storage();
      await storage.saveTransferRecords(_server, [
        {'id': 'a', 'name': 'first.zip'}
      ]);
      await storage.saveTransferRecords(_otherHost, [
        {'id': 'b', 'name': 'second.zip'}
      ]);
      expect(storage.getTransferRecords(_server).map((r) => r['id']), ['a']);
      expect(storage.getTransferRecords(_otherHost).map((r) => r['id']), ['b']);
      await storage.clearServerTransferRecords('srv');
      expect(storage.getTransferRecords(_server), isEmpty);
      expect(storage.getTransferRecords(_otherHost), isEmpty);
    });

    test('at most one hundred transfer records are kept', () async {
      final storage = await _storage();
      await storage.saveTransferRecords(
          _server, [for (var i = 0; i < 120; i++) {'id': '$i'}]);
      expect(storage.getTransferRecords(_server), hasLength(100));
    });

    test('a transfer payload past 256 KiB is rejected', () async {
      final storage = await _storage();
      expect(
          () => storage.saveTransferRecords(_server, [
                {'blob': 'x' * (256 * 1024)}
              ]),
          throwsA(isA<Object>()));
    });
  });

  group('terminal pinned keys', () {
    test('unset pinned keys read as null rather than an empty list', () async {
      expect((await _storage()).getTerminalPinnedKeys(), isNull);
    });

    test('pinned keys survive a round trip including an empty selection', () async {
      final storage = await _storage();
      await storage.setTerminalPinnedKeys(['TAB', 'ESC', 'CTRL']);
      expect(storage.getTerminalPinnedKeys(), ['TAB', 'ESC', 'CTRL']);
      await storage.setTerminalPinnedKeys([]);
      expect(storage.getTerminalPinnedKeys(), isEmpty);
    });

    test('pinned keys are independent of the server they were typed on', () async {
      final storage = await _storage();
      await storage.setTerminalPinnedKeys(['CTRL']);
      await storage.savePageCache(_otherHost, 'files', {'index': 1});
      expect(storage.getTerminalPinnedKeys(), ['CTRL']);
    });

    test('pinned keys travel through a configuration export and import', () async {
      final source = await _storage();
      await source.setTerminalPinnedKeys(['ESC', 'TAB']);
      final target = await _storage();
      await target.appendConfiguration(
          servers: const [], agents: const [], commands: const [],
          bookmarks: const {}, defaultAgents: const {},
          preferences: source.exportConfigurationPreferences());
      expect(target.getTerminalPinnedKeys(), ['ESC', 'TAB']);
    });
  });

  group('file view mode', () {
    test('unset view mode reads as null', () async {
      expect((await _storage()).getFileViewMode(), isNull);
    });

    test('list and grid persist across reads', () async {
      final storage = await _storage();
      await storage.setFileViewMode('list');
      expect(storage.getFileViewMode(), 'list');
      await storage.setFileViewMode('grid');
      expect(storage.getFileViewMode(), 'grid');
    });

    test('an unknown mode is refused and leaves the stored value intact', () async {
      final storage = await _storage();
      await storage.setFileViewMode('grid');
      expect(() => storage.setFileViewMode('mosaic'), throwsArgumentError);
      expect(storage.getFileViewMode(), 'grid');
    });

    test('an unrecognized stored value reads as null', () async {
      final storage =
          await _storage(raw: const {'valhalla_file_view_mode_v1': 'mosaic'});
      expect(storage.getFileViewMode(), isNull);
    });

    test('the view mode round trips through a configuration export', () async {
      final source = await _storage();
      await source.setFileViewMode('list');
      final target = await _storage();
      await target.appendConfiguration(
          servers: const [], agents: const [], commands: const [],
          bookmarks: const {}, defaultAgents: const {},
          preferences: source.exportConfigurationPreferences());
      expect(target.getFileViewMode(), 'list');
    });
  });

  group('unknown configuration values', () {
    Future<void> import(Map<String, Object> preferences) async {
      final storage = await _storage();
      await storage.appendConfiguration(
          servers: const [], agents: const [], commands: const [],
          bookmarks: const {}, defaultAgents: const {},
          preferences: preferences);
    }

    test('a preference key outside the known set is refused', () async {
      expect(() => import({'valhalla_not_a_preference_v1': 'x'}),
          throwsFormatException);
    });

    test('a known key with the wrong value type is refused', () async {
      for (final value in <Object>[1, true, <String>['a'], <int>[1]]) {
        expect(() => import({'valhalla_file_view_mode_v1': value}),
            throwsFormatException, reason: '$value');
      }
      expect(() => import({'valhalla_terminal_font_size_v1': 'large'}),
          throwsFormatException);
    });

    test('a rejected preference leaves the configuration untouched', () async {
      final storage = await _storage();
      expect(
          () => storage.appendConfiguration(
              servers: const [], agents: const [], commands: const [],
              bookmarks: const {}, defaultAgents: const {},
              preferences: {'valhalla_not_a_preference_v1': 'x'}),
          throwsFormatException);
      expect(storage.getServers(), isEmpty);
    });

    test('a list value that is not a list of strings is refused', () async {
      expect(() => import({'valhalla_terminal_pinned_keys_v1': [1, 2]}),
          throwsFormatException);
    });
  });

  group('import rollback', () {
    test('a failure part way through an import restores the previous data',
        () async {
      final storage = await _storage();
      await storage.saveServers([_server]);
      expect(
          () => storage.appendConfiguration(
              servers: const [
                ServerProfile(id: 's2', name: 'B', host: 'c.example', username: 'u')
              ],
              agents: const [], commands: const [],
              bookmarks: const {}, defaultAgents: const {},
              preferences: const {'valhalla_not_a_preference_v1': 'x'}),
          throwsFormatException);
      expect(storage.getServers().map((s) => s.id), ['srv']);
    });

    test('a valid import merges instead of replacing', () async {
      final storage = await _storage();
      await storage.appendConfiguration(
          servers: [_server],
          agents: const [],
          commands: const [
            QuickCommand(
                id: 'll', title: 'Long list', command: 'ls -l', category: 'files',
                description: 'List files')
          ],
          bookmarks: const {}, defaultAgents: const {});
      expect(storage.getServers().map((s) => s.id), ['srv']);
      expect(storage.getQuickCommands().map((c) => c.id), ['ll']);
      expect(storage.getAgents(), everyElement(isA<AgentProfile>()));
    });
  });
}