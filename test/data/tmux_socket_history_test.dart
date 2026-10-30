import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/models/terminal_history.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _server = ServerProfile(
  id: 'srv-1',
  name: 'Prod',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
);

final _targetKey = TerminalHistoryRecord.targetFor(_server);

final _createdAt = DateTime.utc(2026, 3, 1, 12, 0, 0);
final _lastUsedAt = DateTime.utc(2026, 3, 5, 8, 30, 0);

const _namedSocket = 'shared';
const _socketPath = '/tmp/tmux-1000/shared';

TmuxSessionIdentity _identity({
  String sessionId = r'$4',
  int createdSeconds = 1772000000,
  int serverPid = 4211,
  String socketPath = _socketPath,
}) => TmuxSessionIdentity(
  sessionId: sessionId,
  createdSeconds: createdSeconds,
  serverPid: serverPid,
  socketPath: socketPath,
);

Map<String, dynamic> _identityJson({
  String sessionId = r'$4',
  int createdSeconds = 1772000000,
  int serverPid = 4211,
  String socketPath = _socketPath,
}) => {
  'sessionId': sessionId,
  'createdSeconds': createdSeconds,
  'serverPid': serverPid,
  'socketPath': socketPath,
};

TerminalHistoryRecord _record({
  required String id,
  String name = 'valhalla_work',
  String title = 'Work session',
  TmuxSocketSource socket = TmuxSocketSource.app,
  TmuxSessionIdentity? identity,
  bool isExternal = false,
}) => TerminalHistoryRecord(
  id: id,
  serverId: _server.id,
  targetKey: _targetKey,
  remoteSessionName: name,
  title: title,
  createdAt: _createdAt,
  lastUsedAt: _lastUsedAt,
  socket: socket,
  identity: identity,
  isExternal: isExternal,
);

Map<String, dynamic> _snapshotJson(TerminalHistorySnapshot snapshot) =>
    Map<String, dynamic>.from(snapshot.toJson());

Map<String, dynamic> _recordJson(TerminalHistoryRecord record) =>
    Map<String, dynamic>.from(record.toJson());

/// Downgrades a v2 payload to v1 by dropping the v2-only record fields and
/// the v2 snapshot fields, keeping the v1 record/default contract intact.
Map<String, dynamic> _asV1(Map<String, dynamic> v2) {
  final records = (v2['records'] as List).map((item) {
    final record = Map<String, dynamic>.from(item as Map);
    record.remove('socket');
    record.remove('identity');
    record.remove('isExternal');
    return record;
  }).toList();
  return {
    'version': 1,
    'records': records,
    'defaultRecordId': v2['defaultRecordId'],
  };
}

Future<LocalStorageService> _storage({
  Map<String, Object> raw = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(raw));
  return LocalStorageService(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tmux socket source', () {
    test('named sources reject malformed names and alias the built-ins', () {
      expect(TmuxSocketSource.named('valhalla'), same(TmuxSocketSource.app));
      expect(
        TmuxSocketSource.named('default'),
        same(TmuxSocketSource.standard),
      );

      final named = TmuxSocketSource.named('team-1_A');
      expect(named.kind, TmuxSocketKind.named);
      expect(named.value, 'team-1_A');
      expect(named.isBuiltin, isFalse);

      // Dots are permitted in named sockets (e.g. FQDN-style team identifiers).
      final dotted = TmuxSocketSource.named('team.1');
      expect(dotted.kind, TmuxSocketKind.named);
      expect(dotted.value, 'team.1');
      expect(dotted.isBuiltin, isFalse);

      final invalid = [
        '',
        ' ',
        'team 1',
        'team/1',
        'a' * 65,
        'тест',
        'team\n1',
      ];
      for (final name in invalid) {
        expect(
          () => TmuxSocketSource.named(name),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'TMUX_INVALID_SOCKET',
            ),
          ),
          reason: 'named source "$name" must be rejected',
        );
      }
    });

    test('path sources reject relative paths, traversal and control chars', () {
      final path = TmuxSocketSource.path('/tmp/tmux-1000/shared');
      expect(path.kind, TmuxSocketKind.path);
      expect(path.value, '/tmp/tmux-1000/shared');

      final invalid = [
        '',
        'tmp/tmux-1000/shared',
        '/tmp/../etc/socket',
        '/tmp/\u0000socket',
        '/tmp/\u001fsocket',
        '/tmp/\u007fsocket',
        '/${'a' * 1024}',
      ];
      for (final value in invalid) {
        expect(
          () => TmuxSocketSource.path(value),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'TMUX_INVALID_SOCKET',
            ),
          ),
          reason: 'path source "$value" must be rejected',
        );
      }

      expect(TmuxSocketSource.path('/${'a' * 1023}').value.length, 1024);
    });

    test('socket ids are kind prefixed and survive a JSON round trip', () {
      expect(TmuxSocketSource.app.id, 'app:valhalla');
      expect(TmuxSocketSource.standard.id, 'standard:default');
      expect(TmuxSocketSource.named('team-1').id, 'named:team-1');
      expect(
        TmuxSocketSource.path('/tmp/tmux-1000/shared').id,
        'path:/tmp/tmux-1000/shared',
      );
      expect(TmuxSocketSource.app.isBuiltin, isTrue);
      expect(TmuxSocketSource.standard.isBuiltin, isTrue);

      final sources = [
        TmuxSocketSource.app,
        TmuxSocketSource.standard,
        TmuxSocketSource.named('team-1'),
        TmuxSocketSource.path('/tmp/tmux-1000/shared'),
      ];
      for (final source in sources) {
        final restored = TmuxSocketSource.fromJson(
          Map<String, dynamic>.from(source.toJson()),
        );
        expect(restored.kind, source.kind);
        expect(restored.value, source.value);
        expect(restored.id, source.id);
      }
    });

    test('fromJson rejects unknown kinds and kind/value mismatches', () {
      expect(
        () => TmuxSocketSource.fromJson({'kind': 'bogus', 'value': 'team-1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSocketSource.fromJson({'kind': 'app', 'value': 'other'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSocketSource.fromJson({'kind': 'standard', 'value': 'other'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSocketSource.fromJson({'kind': 'named', 'value': 'bad name'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_SOCKET',
          ),
        ),
      );
    });
  });

  group('tmux session identity', () {
    test('validation rejects malformed ids, timestamps, pids and paths', () {
      expect(
        () => TmuxSessionIdentity.fromJson(_identityJson(sessionId: '4')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_IDENTITY',
          ),
        ),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(_identityJson(sessionId: r'$abc')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(_identityJson(createdSeconds: -1)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(
          _identityJson(createdSeconds: 8640000000001),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(_identityJson(serverPid: 0)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(_identityJson(serverPid: -7)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(
          _identityJson(socketPath: 'tmp/tmux-1000/shared'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TmuxSessionIdentity.fromJson(
          _identityJson(socketPath: '/tmp/\u0001socket'),
        ),
        throwsA(isA<FormatException>()),
      );

      final valid = TmuxSessionIdentity.fromJson(
        _identityJson(createdSeconds: 8640000000000),
      );
      expect(valid.sessionId, r'$4');
      expect(valid.createdSeconds, 8640000000000);
    });

    test('the key is a stable sha256 that distinguishes every field', () {
      final identity = _identity();
      expect(identity.key, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(identity.key, _identity().key);
      expect(
        identity.key,
        sha256.convert(utf8.encode(jsonEncode(identity.toJson()))).toString(),
      );

      expect(identity.key, isNot(_identity(sessionId: r'$5').key));
      expect(identity.key, isNot(_identity(createdSeconds: 1772000001).key));
      expect(identity.key, isNot(_identity(serverPid: 4212).key));
      expect(
        identity.key,
        isNot(_identity(socketPath: '/tmp/tmux-1000/other').key),
      );
    });
  });

  group('terminal history records', () {
    test(
      'v1 payloads load with the app socket and keep the default record',
      () {
        final v2 = _snapshotJson(
          TerminalHistorySnapshot(
            records: [_record(id: 'rec-a')],
            defaultRecordId: 'rec-a',
          ),
        );
        final v1 = _asV1(v2);
        expect(v1['version'], 1);
        expect((v1['records'] as List).single, isNot(contains('socket')));

        final restored = TerminalHistorySnapshot.fromJson(v1);
        final record = restored.records.single;
        expect(record.id, 'rec-a');
        expect(record.remoteSessionName, 'valhalla_work');
        expect(record.socket.id, TmuxSocketSource.app.id);
        expect(record.identity, isNull);
        expect(record.isExternal, isFalse);
        expect(record.targetKey, _targetKey);
        expect(record.createdAt, _createdAt);
        expect(record.lastUsedAt, _lastUsedAt);
        expect(restored.defaultRecordId, 'rec-a');
      },
    );

    test(
      'v1 payloads are still readable from the legacy storage key',
      () async {
        final v1 = _asV1(
          _snapshotJson(
            TerminalHistorySnapshot(
              records: [_record(id: 'rec-a')],
              defaultRecordId: 'rec-a',
            ),
          ),
        );
        final storage = await _storage(
          raw: {
            'valhalla_terminal_history_v1::${_server.id}::$_targetKey':
                jsonEncode(v1),
          },
        );

        final snapshot = storage.getTerminalHistory(_server.id, _targetKey);
        expect(snapshot.records.single.id, 'rec-a');
        expect(snapshot.records.single.socket.id, TmuxSocketSource.app.id);
        expect(snapshot.records.single.identity, isNull);
        expect(snapshot.defaultRecordId, 'rec-a');
      },
    );

    test(
      'v2 external records keep arbitrary unicode names with an identity',
      () {
        const name = 'проект 🚀 日本語';
        final record = _record(
          id: 'rec-ext',
          name: name,
          title: 'Внешняя сессия',
          socket: TmuxSocketSource.named(_namedSocket),
          identity: _identity(),
          isExternal: true,
        );

        final restored = TerminalHistoryRecord.fromJson(_recordJson(record));
        expect(restored.remoteSessionName, name);
        expect(restored.title, 'Внешняя сессия');
        expect(restored.isExternal, isTrue);
        expect(restored.socket.id, 'named:$_namedSocket');
        expect(restored.identity?.key, record.identity?.key);

        final snapshot = TerminalHistorySnapshot.fromJson(
          _snapshotJson(TerminalHistorySnapshot(records: [record])),
        );
        expect(snapshot.records.single.remoteSessionName, name);
        expect(snapshot.records.single.identity?.key, record.identity?.key);
      },
    );

    test('v2 validation still rejects names and sockets it never allowed', () {
      final unicodeWithoutIdentity = _record(id: 'rec-a', name: 'проект 🚀');
      expect(
        () =>
            TerminalHistoryRecord.fromJson(_recordJson(unicodeWithoutIdentity)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'TERMINAL_HISTORY_INVALID',
          ),
        ),
      );

      final controlCharWithIdentity = _record(
        id: 'rec-b',
        name: 'bad\nname',
        socket: TmuxSocketSource.named(_namedSocket),
        identity: _identity(),
      );
      expect(
        () => TerminalHistoryRecord.fromJson(
          _recordJson(controlCharWithIdentity),
        ),
        throwsA(isA<FormatException>()),
      );

      final nonAppSocketWithoutIdentity = _record(
        id: 'rec-c',
        socket: TmuxSocketSource.named(_namedSocket),
      );
      expect(
        () => TerminalHistoryRecord.fromJson(
          _recordJson(nonAppSocketWithoutIdentity),
        ),
        throwsA(isA<FormatException>()),
      );

      final badTargetKey = TerminalHistoryRecord(
        id: 'rec-d',
        serverId: _server.id,
        targetKey: 'not-a-sha256',
        remoteSessionName: 'valhalla_work',
        title: 'Work session',
        createdAt: _createdAt,
        lastUsedAt: _lastUsedAt,
      );
      expect(
        () => TerminalHistoryRecord.fromJson(_recordJson(badTargetKey)),
        throwsA(isA<FormatException>()),
      );
    });

    test('the same session name is accepted on different sockets', () {
      final appRecord = _record(id: 'rec-app', name: 'valhalla_work');
      final sharedRecord = _record(
        id: 'rec-shared',
        name: 'valhalla_work',
        socket: TmuxSocketSource.named(_namedSocket),
        identity: _identity(),
      );

      final snapshot = TerminalHistorySnapshot.fromJson(
        _snapshotJson(
          TerminalHistorySnapshot(records: [appRecord, sharedRecord]),
        ),
      );
      expect(snapshot.records.length, 2);
      expect(snapshot.records.map((r) => r.remoteSessionName).toSet(), {
        'valhalla_work',
      });
      expect(snapshot.records.map((r) => r.socket.id).toSet(), {
        TmuxSocketSource.app.id,
        'named:$_namedSocket',
      });
    });

    test(
      'duplicate identities on one socket and duplicate ids are rejected',
      () {
        final first = _record(
          id: 'rec-1',
          name: 'valhalla_one',
          socket: TmuxSocketSource.named(_namedSocket),
          identity: _identity(),
        );
        final sameIdentity = _record(
          id: 'rec-2',
          name: 'valhalla_two',
          socket: TmuxSocketSource.named(_namedSocket),
          identity: _identity(),
        );
        expect(
          () => TerminalHistorySnapshot.fromJson(
            _snapshotJson(
              TerminalHistorySnapshot(records: [first, sameIdentity]),
            ),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'TERMINAL_HISTORY_INVALID',
            ),
          ),
        );

        final sameId = _record(
          id: 'rec-1',
          name: 'valhalla_three',
          socket: TmuxSocketSource.named(_namedSocket),
          identity: _identity(sessionId: r'$9'),
        );
        expect(
          () => TerminalHistorySnapshot.fromJson(
            _snapshotJson(TerminalHistorySnapshot(records: [first, sameId])),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('terminal history storage', () {
    test(
      'hidden ids and custom socket sources round trip through storage',
      () async {
        final snapshot = TerminalHistorySnapshot(
          records: [_record(id: 'rec-1')],
          defaultRecordId: 'rec-1',
          hiddenRecordIds: const ['rec-9', 'rec-8'],
          socketSources: [
            TmuxSocketSource.named(_namedSocket),
            TmuxSocketSource.path('/tmp/tmux-1000/custom'),
          ],
        );

        final restored = TerminalHistorySnapshot.fromJson(
          _snapshotJson(snapshot),
        );
        expect(restored.hiddenRecordIds, ['rec-9', 'rec-8']);
        expect(restored.socketSources.map((s) => s.id), [
          'named:$_namedSocket',
          'path:/tmp/tmux-1000/custom',
        ]);

        final storage = await _storage();
        await storage.saveTerminalHistory(_server.id, _targetKey, snapshot);
        final stored = storage.getTerminalHistory(_server.id, _targetKey);
        expect(stored.hiddenRecordIds, ['rec-9', 'rec-8']);
        expect(stored.socketSources.map((s) => s.id), [
          'named:$_namedSocket',
          'path:/tmp/tmux-1000/custom',
        ]);
        expect(stored.records.single.id, 'rec-1');
        expect(stored.defaultRecordId, 'rec-1');
        expect(stored.records.single.targetKey, _targetKey);
      },
    );

    test(
      'loading v1 then saving v2 keeps the v1 payload byte identical',
      () async {
        final v1 = _asV1(
          _snapshotJson(
            TerminalHistorySnapshot(
              records: [_record(id: 'rec-a', title: 'Legacy title')],
              defaultRecordId: 'rec-a',
            ),
          ),
        );
        final raw = jsonEncode(v1);
        final v1Key =
            'valhalla_terminal_history_v1::${_server.id}::$_targetKey';
        final storage = await _storage(raw: {v1Key: raw});

        final loaded = storage.getTerminalHistory(_server.id, _targetKey);
        expect(loaded.records.single.id, 'rec-a');
        expect(loaded.records.single.title, 'Legacy title');
        expect(loaded.records.single.socket.id, TmuxSocketSource.app.id);
        expect(loaded.defaultRecordId, 'rec-a');

        final v2 = TerminalHistorySnapshot(
          records: [
            _record(
              id: 'rec-b',
              title: 'New title',
              socket: TmuxSocketSource.named(_namedSocket),
              identity: _identity(),
              isExternal: true,
            ),
          ],
          defaultRecordId: 'rec-b',
        );
        await storage.saveTerminalHistory(_server.id, _targetKey, v2);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(v1Key), raw);
        expect(
          prefs.getString(
            'valhalla_terminal_history_v2::${_server.id}::$_targetKey',
          ),
          isNotNull,
        );

        final stored = storage.getTerminalHistory(_server.id, _targetKey);
        expect(stored.records.single.id, 'rec-b');
        expect(stored.records.single.title, 'New title');
        expect(stored.records.single.socket.id, 'named:$_namedSocket');
        expect(stored.records.single.identity?.key, isNotNull);
        expect(stored.records.single.isExternal, isTrue);
        expect(stored.defaultRecordId, 'rec-b');
      },
    );

    test(
      'storage refuses records that do not match the requested target',
      () async {
        final storage = await _storage();
        final snapshot = TerminalHistorySnapshot(
          records: [_record(id: 'rec-1')],
        );

        expect(
          storage.saveTerminalHistory('other-server', _targetKey, snapshot),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'TERMINAL_HISTORY_INVALID',
            ),
          ),
        );
        expect(
          storage.saveTerminalHistory(_server.id, 'f' * 64, snapshot),
          throwsA(isA<FormatException>()),
        );

        final tampered = _snapshotJson(snapshot);
        final record = Map<String, dynamic>.from(
          (tampered['records'] as List).single as Map,
        );
        record['targetKey'] = 'f' * 64;
        tampered['records'] = [record];
        final tamperedStorage = await _storage(
          raw: {
            'valhalla_terminal_history_v2::${_server.id}::$_targetKey':
                jsonEncode(tampered),
          },
        );
        expect(
          () => tamperedStorage.getTerminalHistory(_server.id, _targetKey),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
