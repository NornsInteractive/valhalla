import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/workspace/workspace_journal.dart';

Future<String> _db() async {
  final d = await Directory.systemTemp.createTemp('wj');
  return '${d.path}/j.sqlite3';
}

void main() {
  group('WorkspaceJournal', () {
    test(
      'queue stores pending with baseVersion from observed local snapshot',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 3,
        });
        await j.rememberLocal('s', [
          {'kind': 'config', 'id': 'a', 'value': 1, 'version': 3},
        ]);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        final p = await j.pending('s');
        expect(p, hasLength(1));
        expect(p.first['baseVersion'], 3);
      },
    );

    test('unobserved remote cache does not become queue baseVersion', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 1,
        'version': 3,
      });
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 2},
      ]);
      final p = await j.pending('s');
      expect(p, hasLength(1));
      expect(p.first['baseVersion'], 0);
    });

    test(
      'receive with matching operationId acknowledges and removes pending',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        final op = (await j.pending('s')).first['operationId'] as String;
        final applied = await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 2,
          'version': 4,
        }, operationId: op);
        expect(applied, isTrue);
        expect(await j.pending('s'), isEmpty);
        expect((await j.cached('s', 'config', 'a'))!['version'], 4);
      },
    );

    test(
      'receive without operationId and version mismatch marks conflict, keeps pending',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 9,
          'version': 5,
        });
        expect(await j.pending('s', conflicts: false), isEmpty);
        expect(await j.pending('s', conflicts: true), hasLength(1));
      },
    );

    test(
      'receive remote version matching base leaves pending unconflicted? conflict path',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        // remote version equals baseVersion (0 initially) -> condition false, no conflict update, pending remains
        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 7,
          'version': 0,
        });
        expect(await j.pending('s', conflicts: false), hasLength(1));
      },
    );

    test('clear removes only target server', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.queue('s1', [
        {'kind': 'config', 'id': 'a', 'value': 1},
      ]);
      await j.queue('s2', [
        {'kind': 'config', 'id': 'a', 'value': 1},
      ]);
      await j.clear('s1');
      expect(await j.pending('s1'), isEmpty);
      expect(await j.pending('s2'), hasLength(1));
    });

    test('resolve keepLocal resets conflict and bumps base', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 2},
      ]);
      await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 9,
        'version': 5,
      });
      await j.resolve('s', 'config', 'a', keepLocal: true);
      final p = await j.pending('s', conflicts: false);
      expect(p, hasLength(1));
      expect(p.first['baseVersion'], 5);
    });

    test('resolve keepLocal false deletes pending', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 2},
      ]);
      await j.resolve('s', 'config', 'a', keepLocal: false);
      expect(await j.pending('s'), isEmpty);
    });

    test('retained deletes tombstone preserved across sync batches', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 1, 'deleted': true},
      ]);
      final p = await j.pending('s');
      expect(p.first['deleted'], true);
    });

    test(
      'same-value remote record auto-acknowledges instead of conflicting',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {
            'kind': 'config',
            'id': 'a',
            'value': {'v': 1},
          },
        ]);
        final applied = await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': {'v': 1},
          'version': 5,
        });
        expect(applied, isTrue);
        expect(await j.pending('s'), isEmpty);
        expect(await j.pending('s', conflicts: true), isEmpty);
        expect((await j.cached('s', 'config', 'a'))!['version'], 5);
      },
    );

    test(
      'an older duplicate ACK cannot delete a newer pending write',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 1},
        ]);
        final first = (await j.pending('s')).first['operationId'] as String;
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        final second = (await j.pending('s')).first['operationId'] as String;
        expect(second, isNot(first));

        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 4,
        }, operationId: first);
        final stillPending = await j.pending('s');
        expect(stillPending, hasLength(1));
        expect(stillPending.first['value'], 2);

        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 2,
          'version': 5,
        }, operationId: second);
        expect(await j.pending('s'), isEmpty);
      },
    );

    test(
      'clear with pending changes is atomic and leaves data intact',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.rememberLocal('s', [
          {'kind': 'config', 'id': 'a', 'value': 1, 'version': 2},
        ]);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        await expectLater(
          j.clear('s', requireNoPending: true),
          throwsA(isA<StateError>()),
        );
        expect(await j.pending('s'), hasLength(1));
        expect((await j.localSnapshot('s'))['config\x00a']!['value'], 1);
      },
    );

    test('first migration can force base version zero', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.rememberLocal('s', [
        {'kind': 'config', 'id': 'a', 'value': 1, 'version': 7},
      ]);
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 2},
      ], forceBaseZero: true);
      final pending = await j.pending('s');
      expect(pending.first['baseVersion'], 0);
    });

    test('already applied version is not re-applied', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 1,
        'version': 3,
      });
      final applied = await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 1,
        'version': 3,
      });
      expect(applied, isFalse);
    });

    test(
      'own old ACK original opId after newer local edit keeps newer pending and rebases baseVersion',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 1},
        ]);
        final first = (await j.pending('s')).first['operationId'] as String;
        // A newer local edit supersedes the original queued operation.
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        final second = (await j.pending('s')).first['operationId'] as String;
        expect(second, isNot(first));
        // The original (now stale) ACK arrives for an older, superseded edit.
        final applied = await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 4,
        }, operationId: first);
        expect(applied, isFalse);
        final stillPending = await j.pending('s');
        expect(stillPending, hasLength(1));
        // The newer local edit is preserved...
        expect(stillPending.first['value'], 2);
        // ...and its CAS base is rebased to the acknowledged version.
        expect(stillPending.first['baseVersion'], 4);
        expect(second, (await j.pending('s')).first['operationId']);
      },
    );

    test(
      'older ACK must not overwrite a newer cached remote version',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        // Establish a newer cached remote version.
        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 10,
        });
        expect((await j.cached('s', 'config', 'a'))!['version'], 10);
        // A stale older ACK (lower version) must not downgrade the cache.
        final applied = await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 5,
        }, operationId: 'stale-op');
        expect(applied, isFalse);
        expect((await j.cached('s', 'config', 'a'))!['version'], 10);
      },
    );

    test('matching duplicate ACK is idempotent', () async {
      final db = await _db();
      final j = WorkspaceJournal(databasePath: db);
      await j.queue('s', [
        {'kind': 'config', 'id': 'a', 'value': 2},
      ]);
      final op = (await j.pending('s')).first['operationId'] as String;
      // First ACK acknowledges and clears the pending.
      final applied = await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 2,
        'version': 4,
      }, operationId: op);
      expect(applied, isTrue);
      expect(await j.pending('s'), isEmpty);
      expect((await j.cached('s', 'config', 'a'))!['version'], 4);
      // A duplicate ACK for the same operation idempotently does nothing.
      final again = await j.receive('s', {
        'kind': 'config',
        'id': 'a',
        'value': 2,
        'version': 4,
      }, operationId: op);
      expect(again, isFalse);
      expect(await j.pending('s'), isEmpty);
      expect((await j.cached('s', 'config', 'a'))!['version'], 4);
    });

    test(
      'own matching-content conflict ACK cannot clear a newer edit',
      () async {
        final db = await _db();
        final j = WorkspaceJournal(databasePath: db);
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 1},
        ]);
        final first = (await j.pending('s')).first['operationId'] as String;
        // Newer local edit supersedes the original operation.
        await j.queue('s', [
          {'kind': 'config', 'id': 'a', 'value': 2},
        ]);
        // A conflicting remote write arrives, flagging the pending edit.
        await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 9,
          'version': 5,
        });
        expect(await j.pending('s', conflicts: true), hasLength(1));
        // An own ACK for the stale original op (matching its old content)
        // must not clear the newer local edit.
        final applied = await j.receive('s', {
          'kind': 'config',
          'id': 'a',
          'value': 1,
          'version': 4,
        }, operationId: first);
        expect(applied, isFalse);
        final stillPending = await j.pending('s', conflicts: true);
        expect(stillPending, hasLength(1));
        expect(stillPending.first['value'], 2);
      },
    );
  });
}
