import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

String _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonical).join(',')}]';
  }
  return jsonEncode(value);
}

/// Durable local outbox. Database/JSON work never runs on Flutter's UI isolate.
class WorkspaceJournal {
  final String? databasePath;
  Future<String>? _path;
  Future<void> _tail = Future.value();
  WorkspaceJournal({this.databasePath});
  Future<String> _file() async =>
      databasePath ??
      p.join(
        (await getApplicationSupportDirectory()).path,
        'valhalla_workspace.sqlite3',
      );
  Future<T> _run<T>(T Function(Database) action) async {
    final file = await (_path ??= _file());
    final next = _tail.then(
      (_) => Isolate.run(() {
        Database db;
        try {
          db = sqlite3.open(file);
        } on ArgumentError {
          if (!Platform.isLinux) rethrow;
          open.overrideFor(
            OperatingSystem.linux,
            () => DynamicLibrary.open('libsqlite3.so.0'),
          );
          db = sqlite3.open(file);
        }
        try {
          db.execute('PRAGMA busy_timeout=5000');
          db.execute('PRAGMA journal_mode=WAL');
          db.execute(
            'CREATE TABLE IF NOT EXISTS workspace_cache(server TEXT,kind TEXT,id TEXT,data TEXT,PRIMARY KEY(server,kind,id))',
          );
          db.execute(
            'CREATE TABLE IF NOT EXISTS workspace_local(server TEXT,kind TEXT,id TEXT,data TEXT,PRIMARY KEY(server,kind,id))',
          );
          db.execute(
            'CREATE TABLE IF NOT EXISTS workspace_pending(server TEXT,kind TEXT,id TEXT,data TEXT,operation TEXT,conflict INTEGER DEFAULT 0,PRIMARY KEY(server,kind,id))',
          );
          return action(db);
        } finally {
          db.dispose();
        }
      }),
    );
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<Map<String, Map<String, dynamic>>> localSnapshot(String server) =>
      _run(
        (db) => {
          for (final r in db.select(
            'SELECT kind,id,data FROM workspace_local WHERE server=?',
            [server],
          ))
            '${r['kind']}\x00${r['id']}': (Map<String, dynamic>.from(
              jsonDecode(r['data'] as String) as Map,
            )..remove('version')),
        },
      );
  Future<void> rememberLocal(
    String server,
    List<Map<String, dynamic>> records,
  ) => _run((db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final value in records) {
        final args = [server, value['kind'], value['id']];
        if (value['deleted'] == true) {
          db.execute(
            'DELETE FROM workspace_local WHERE server=? AND kind=? AND id=?',
            args,
          );
        } else {
          final old = db
              .select(
                'SELECT data FROM workspace_local WHERE server=? AND kind=? AND id=?',
                args,
              )
              .firstOrNull;
          final version =
              value['version'] ??
              (old == null
                  ? 0
                  : jsonDecode(old['data'] as String)['version'] ?? 0);
          final data = {
            'kind': value['kind'],
            'id': value['id'],
            'value': value['value'],
            'version': version,
          };
          db.execute(
            'INSERT OR REPLACE INTO workspace_local(server,kind,id,data) VALUES(?,?,?,?)',
            [...args, jsonEncode(data)],
          );
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });
  Future<void> queue(
    String server,
    List<Map<String, dynamic>> values, {
    bool forceBaseZero = false,
  }) {
    return _run((db) {
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final value in values) {
          final kind = value['kind'], id = value['id'];
          final old = db.select(
            'SELECT data FROM workspace_pending WHERE server=? AND kind=? AND id=?',
            [server, kind, id],
          ).firstOrNull;
          final cache = db.select(
            'SELECT data FROM workspace_cache WHERE server=? AND kind=? AND id=?',
            [server, kind, id],
          ).firstOrNull;
          final local = db.select(
            'SELECT data FROM workspace_local WHERE server=? AND kind=? AND id=?',
            [server, kind, id],
          ).firstOrNull;
          final isConfig =
              kind == 'config' ||
              kind == 'preference' ||
              kind == 'draft' && id is String && !id.contains('/file/');
          // A first migration must never inherit a remote CAS version: the
          // pending entry starts at 0 even if a stale local snapshot exists.
          final base = old != null
              ? jsonDecode(old['data'] as String)['baseVersion']
              : forceBaseZero
              ? 0
              : isConfig
              ? (local == null
                    ? 0
                    : jsonDecode(local['data'] as String)['version'] ?? 0)
              : (cache == null
                    ? 0
                    : (jsonDecode(cache['data'] as String)['version'] as int? ??
                          0));
          final data = {...value, 'baseVersion': base};
          db.execute(
            'INSERT OR REPLACE INTO workspace_pending(server,kind,id,data,operation,conflict) VALUES(?,?,?,?,?,0)',
            [server, kind, id, jsonEncode(data), const Uuid().v4()],
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  Future<List<Map<String, dynamic>>> pending(
    String server, {
    bool conflicts = false,
    int limit = 16,
  }) => _run(
    (db) => db
        .select(
          'SELECT data,operation FROM workspace_pending WHERE server=? AND conflict=? ORDER BY rowid LIMIT ?',
          [server, conflicts ? 1 : 0, limit],
        )
        .map(
          (r) => {
            ...Map<String, dynamic>.from(
              jsonDecode(r['data'] as String) as Map,
            ),
            'operationId': r['operation'],
          },
        )
        .toList(),
  );
  Future<int> pendingCount(String server) => _run(
    (db) =>
        db.select(
              'SELECT COUNT(*) AS n FROM workspace_pending WHERE server=?',
              [server],
            ).single['n']
            as int,
  );

  /// Drops a cache entry that was staged but not applied because a local write
  /// raced hydration. The next sync must retry the same page/record.
  Future<void> forgetCache(String server, String kind, String id) => _run(
    (db) => db.execute(
      'DELETE FROM workspace_cache WHERE server=? AND kind=? AND id=?',
      [server, kind, id],
    ),
  );
  Future<Map<String, dynamic>?> cached(String server, String kind, String id) =>
      _run((db) {
        final row = db.select(
          'SELECT data FROM workspace_cache WHERE server=? AND kind=? AND id=?',
          [server, kind, id],
        ).firstOrNull;
        return row == null
            ? null
            : Map<String, dynamic>.from(
                jsonDecode(row['data'] as String) as Map,
              );
      });
  Future<bool> receive(
    String server,
    Map<String, dynamic> value, {
    String? operationId,
  }) => _run((db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final args = [server, value['kind'], value['id']];
      final pending = db
          .select(
            'SELECT data,operation FROM workspace_pending WHERE server=? AND kind=? AND id=?',
            args,
          )
          .firstOrNull;
      final cached = db
          .select(
            'SELECT data FROM workspace_cache WHERE server=? AND kind=? AND id=?',
            args,
          )
          .firstOrNull;
      final alreadyApplied =
          cached != null &&
          (jsonDecode(cached['data'] as String)['version'] as int? ?? -1) >=
              (value['version'] as int? ?? -1);
      if (!alreadyApplied) {
        db.execute(
          'INSERT OR REPLACE INTO workspace_cache(server,kind,id,data) VALUES(?,?,?,?)',
          [...args, jsonEncode(value)],
        );
      }
      bool apply = pending == null && !alreadyApplied;
      if (pending != null) {
        final pendingData = Map<String, dynamic>.from(
          jsonDecode(pending['data'] as String) as Map,
        );
        final sameValue =
            operationId == null &&
            _canonical(pendingData['value']) == _canonical(value['value']) &&
            (pendingData['deleted'] == true) == (value['deleted'] == true);
        if (operationId != null && pending['operation'] == operationId) {
          // Only the acknowledgement for the currently queued operation may
          // clear it; an older duplicate ACK must not delete a newer write.
          db.execute(
            'DELETE FROM workspace_pending WHERE server=? AND kind=? AND id=? AND operation=?',
            [...args, operationId],
          );
          apply = true;
        } else if (operationId != null && !alreadyApplied) {
          // An ACK for our previous edit advances the newer edit's CAS base.
          pendingData['baseVersion'] = value['version'];
          db.execute(
            'UPDATE workspace_pending SET data=? WHERE server=? AND kind=? AND id=? AND operation=?',
            [jsonEncode(pendingData), ...args, pending['operation']],
          );
        } else if (sameValue) {
          // Migration of an identical value is not a conflict and needs no
          // duplicate resolution round trip.
          db.execute(
            'DELETE FROM workspace_pending WHERE server=? AND kind=? AND id=?',
            args,
          );
          apply = true;
        } else if (operationId == null &&
            value['version'] != pendingData['baseVersion']) {
          db.execute(
            'UPDATE workspace_pending SET conflict=1 WHERE server=? AND kind=? AND id=?',
            args,
          );
        }
      }
      db.execute('COMMIT');
      return apply;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });
  Future<void> resolve(
    String server,
    String kind,
    String id, {
    required bool keepLocal,
  }) => _run((db) {
    final args = [server, kind, id];
    if (!keepLocal) {
      db.execute(
        'DELETE FROM workspace_pending WHERE server=? AND kind=? AND id=?',
        args,
      );
      return;
    }
    final pending = db
        .select(
          'SELECT data FROM workspace_pending WHERE server=? AND kind=? AND id=?',
          args,
        )
        .firstOrNull;
    final cache = db
        .select(
          'SELECT data FROM workspace_cache WHERE server=? AND kind=? AND id=?',
          args,
        )
        .firstOrNull;
    if (pending == null) return;
    final data = Map<String, dynamic>.from(
      jsonDecode(pending['data'] as String) as Map,
    );
    data['baseVersion'] = cache == null
        ? 0
        : jsonDecode(cache['data'] as String)['version'];
    db.execute(
      'UPDATE workspace_pending SET data=?,operation=?,conflict=0 WHERE server=? AND kind=? AND id=?',
      [jsonEncode(data), const Uuid().v4(), ...args],
    );
  });
  Future<void> clear(String server, {bool requireNoPending = false}) => _run((
    db,
  ) {
    db.execute('BEGIN IMMEDIATE');
    try {
      if (requireNoPending &&
          (db.select(
                    'SELECT COUNT(*) AS n FROM workspace_pending WHERE server=?',
                    [server],
                  ).single['n']
                  as int) !=
              0) {
        throw StateError('WORKSPACE_PENDING_CHANGES');
      }
      for (final table in [
        'workspace_cache',
        'workspace_pending',
        'workspace_local',
      ]) {
        db.execute('DELETE FROM $table WHERE server=?', [server]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });
}
