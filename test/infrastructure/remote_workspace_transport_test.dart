// Real-transport regression test for the Valhalla remote workspace store.
//
// Goal: exercise the *actual* shipped client (RemoteWorkspaceClient) over a
// *genuine* dartssh2 SSHClient against a *real* asyncssh loopback fixture
// (tool/acp_device_ssh_fixture.py), end to end. No mocks, no fakes.
//
// Ownership: this file (plus the isolated venv at build/workspace-sync/ssh-venv
// and transport-e2e-report.md) is the only thing owned by this task. It does NOT
// edit any core Python/Dart/NAS/file/controller source, does NOT build, push, or
// release, and never talks to a production server, Agent, or tmux.
//
// Isolation: every scenario spins up its own fixture process with a fresh,
// fixture-owned TEMP HOME (never the developer's real $HOME). Fixture-only
// credentials are hardcoded below and are NEVER logged. SSH secrets, host keys,
// and signing material are never printed.
//
// NOTE ON THE PRODUCT FIX (see transport-e2e-report.md):
// RemoteWorkspaceClient.discover/install previously passed a *multi-line* inline
// Python source through cliShellQuote(), which rejected newlines and threw
// ArgumentError('CLI_INVALID_ARGUMENT'). That defect has been fixed: discover
// now reports an absent store without creating one, and install() places both
// bundled runtime assets (store.py + workspace_nas.py) so bootstrap can run for
// real. Separately, RemoteWorkspaceClient now throws a WorkspaceException (with
// a `.code`) for any `ok:false` response instead of returning a false-map, so
// the CAS / control / conflict assertions below use expectLater(throwsA(...)).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:valhalla/infrastructure/workspace/remote_workspace_client.dart';

// Fixture-only credentials. Do not print these.
const _fxUser = 'fixture';
const _fxPassword = 'fixture-only';

// Minimal store.py that answers `discover` with a *future* schema (2) so the
// client's version guard (once reachable) rejects it before any overwrite.
const _fakeStoreSchema2 = r'''
import sys, json
line = ''
try:
    line = sys.stdin.readline()
    req = json.loads(line)
except Exception:
    req = {}
op = req.get('op')
if op == 'discover':
    print(json.dumps({"ok": True, "exists": True, "workspaceId": "ws-seeded",
                      "schema": 2, "component": 2, "revision": 0, "user": "dev"}))
else:
    print(json.dumps({"ok": False, "error": "WORKSPACE_OP_UNKNOWN"}))
''';

final RemoteWorkspaceClient client = RemoteWorkspaceClient();

String _pkgRoot() {
  final cwd = Directory.current.path;
  if (File('$cwd/pubspec.yaml').existsSync()) return cwd;
  var dir = File(Platform.script.toFilePath()).parent;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return cwd;
}

/// Loopback asyncssh fixture bound to 127.0.0.1 on an isolated TEMP HOME.
class Fixture {
  Fixture._(this.process, this.homeDir, this.port, this.readyFile);

  final Process process;
  final Directory homeDir;
  final int port;
  final File readyFile;

  static Future<int> _freePort() async {
    final s = await ServerSocket.bind('127.0.0.1', 0);
    final p = s.port;
    await s.close();
    return p;
  }

  /// [seed] runs after the HOME dir is created but before the server starts, so
  /// callers can pre-place a pre-existing remote store (future-schema / symlink
  /// scenarios) without any network traffic.
  static Future<Fixture> start({
    Future<void> Function(Directory home)? seed,
    Map<String, String>? extraEnv,
  }) async {
    final home = await Directory.systemTemp.createTemp('ws-fix-');
    if (seed != null) await seed(home);
    final ready = File('${home.path}/.ready');
    final port = await _freePort();
    final pkg = _pkgRoot();
    final fixtureScript = '$pkg/tool/acp_device_ssh_fixture.py';
    final venvPython =
        Platform.environment['WORKSPACE_SSH_PYTHON'] ??
        '$pkg/build/workspace-sync/ssh-venv/bin/python';
    final env = Map<String, String>.from(Platform.environment);
    env['HOME'] = home.path;
    if (extraEnv != null) env.addAll(extraEnv);

    final proc = await Process.start(venvPython, [
      fixtureScript,
      '--bind',
      '127.0.0.1',
      '--port',
      port.toString(),
      '--ready-file',
      ready.path,
    ], environment: env);
    // Drain fixture stdout/stderr so the pipe buffers don't fill up.
    proc.stdout.drain();
    proc.stderr.drain();

    final sw = Stopwatch()..start();
    while (sw.elapsed < const Duration(seconds: 25)) {
      if (await ready.exists()) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!await ready.exists()) {
      proc.kill(ProcessSignal.sigkill);
      try {
        await home.delete(recursive: true);
      } on FileSystemException {
        /* best effort */
      }
      throw StateError('fixture did not become ready on port $port');
    }
    return Fixture._(proc, home, port, ready);
  }

  Future<SSHClient> connect() async {
    final socket = await SSHSocket.connect(
      '127.0.0.1',
      port,
      timeout: const Duration(seconds: 15),
    );
    final c = SSHClient(
      socket,
      username: _fxUser,
      onPasswordRequest: () => _fxPassword,
      // Loopback fixture uses an ephemeral host key; accept it for the test.
      onVerifyHostKey: (_, _) => true,
    );
    await c.authenticated.timeout(const Duration(seconds: 15));
    return c;
  }

  /// Run a raw shell command on the remote (verification only). Stdin is closed
  /// so commands that read stdin (sha256sum, test) terminate.
  Future<String> shell(SSHClient ssh, String command) async {
    final session = await ssh.execute(command);
    await session.stdin.close();
    final out = await session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join();
    await session.stderr.drain();
    await session.done;
    return out;
  }

  Future<String> sha256Remote(SSHClient ssh, String path) async {
    final out = await shell(ssh, 'sha256sum "$path"');
    return out.trim().split(RegExp(r'\s+')).first;
  }

  Future<void> stop() async {
    // Kill the fixture's direct children first (the per-request python store
    // subprocesses are started in a new session, so they are still children of
    // the fixture pid and get cleaned here).
    try {
      await Process.run('pkill', ['-P', process.pid.toString()]);
    } on ProcessException {
      /* best effort */
    }
    process.kill(ProcessSignal.sigkill);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      /* best effort */
    }
    for (final d in [readyFile, homeDir]) {
      try {
        await d.delete(recursive: true);
      } on FileSystemException {
        /* best effort */
      }
    }
  }
}

/// Copy the real bundled runtime assets into the fixture HOME so the store can
/// be bootstrapped directly. Used by groups that test the store-side `request`
/// transport without going through the separate client.install() happy path
/// (which has its own dedicated test above).
Future<void> _seedStoreAssets(Directory home) async {
  final wsDir = Directory('${home.path}/.local/share/valhalla/workspace-v1');
  await wsDir.create(recursive: true);
  final pkg = _pkgRoot();
  final storeSrc = await File(
    '$pkg/assets/runtime/workspace_store.py',
  ).readAsString();
  final nasSrc = await File(
    '$pkg/assets/runtime/workspace_nas.py',
  ).readAsString();
  await File('${wsDir.path}/store.py').writeAsString(storeSrc);
  await File('${wsDir.path}/workspace_nas.py').writeAsString(nasSrc);
}

Future<void> _bootstrap(SSHClient ssh, String deviceId) async {
  final boot = await client.request(ssh, {
    'op': 'bootstrap',
    'deviceId': deviceId,
  });
  if (boot['ok'] != true) {
    throw StateError('bootstrap failed: ${jsonEncode(boot)}');
  }
}

void main() {
  // Initialize the Flutter binding so rootBundle (used by install()) resolves the
  // bundled runtime assets. Plain `test()` keeps real timers/async, which is
  // required for genuine dartssh2 socket I/O (FakeAsync would break it).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('client discover / install (real transport)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start();
      ssh = await fx.connect();
    });
    tearDown(() => fx.stop());

    test('discover reports an absent store and creates nothing', () async {
      final d = await client.discover(ssh);
      expect(d['ok'], isTrue);
      expect(d['exists'], isFalse);
      final ls = await fx.shell(
        ssh,
        r'test -f "$HOME/.local/share/valhalla/workspace-v1/store.sqlite3" '
        '&& echo EXISTS || echo ABSENT',
      );
      expect(ls, contains('ABSENT'));
    });

    test('install places both assets and bootstrap succeeds', () async {
      // Exercises the REAL client.install() path (no manual fixture seeding).
      await client.install(ssh);
      final store = await fx.shell(
        ssh,
        r'test -f "$HOME/.local/share/valhalla/workspace-v1/store.py" '
        '&& echo EXISTS || echo ABSENT',
      );
      expect(store, contains('EXISTS'));
      final nas = await fx.shell(
        ssh,
        r'test -f "$HOME/.local/share/valhalla/workspace-v1/workspace_nas.py" '
        '&& echo EXISTS || echo ABSENT',
      );
      expect(nas, contains('EXISTS'));
      // Bootstrap over the freshly installed store must succeed.
      await _bootstrap(ssh, 'device-A');
    });
  });

  group('store-side discover via request op (does not create)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
    });
    tearDown(() => fx.stop());

    test(
      'request(discover) reports absent store and creates nothing',
      () async {
        final d = await client.request(ssh, {'op': 'discover'});
        expect(d['ok'], isTrue);
        expect(d['exists'], isFalse);
        final ls = await fx.shell(
          ssh,
          r'test -f "$HOME/.local/share/valhalla/workspace-v1/store.sqlite3" '
          '&& echo EXISTS || echo ABSENT',
        );
        expect(ls, contains('ABSENT'));
      },
    );
  });

  group('bootstrap dirs owner/modes (store-enforced)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test(
      'workspace dir is 0700 and owned by the fixture user; db is 0600',
      () async {
        final st = await fx.shell(
          ssh,
          r'stat -c "%a %u" "$HOME/.local/share/valhalla/workspace-v1"',
        );
        final parts = st.trim().split(RegExp(r'\s+'));
        expect(parts.first, '700', reason: 'workspace dir must be mode 0700');
        final uid = (await fx.shell(ssh, 'id -u')).trim();
        expect(parts.last, uid, reason: 'workspace dir owned by fixture user');

        final dbst = await fx.shell(
          ssh,
          r'stat -c "%a" "$HOME/.local/share/valhalla/workspace-v1/store.sqlite3"',
        );
        expect(dbst.trim(), '600', reason: 'store db must be mode 0600');
      },
    );
  });

  group('put / changes / CAS conflict / idempotency', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test(
      'commit, observe via changes, reject stale base, idempotent op',
      () async {
        const id = 'agent/transport-test';
        final put = await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-A',
          'operationId': 'op-put-1',
          'records': [
            {
              'kind': 'agent',
              'id': id,
              'value': {'v': 1},
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
        expect(put['ok'], isTrue);
        final rev = put['revision'] as int;

        final ch = await client.request(ssh, {'op': 'changes', 'after': 0});
        expect(ch['ok'], isTrue);
        final found = (ch['records'] as List).any(
          (r) => r['id'] == id && r['value']['v'] == 1,
        );
        expect(found, isTrue);

        // CAS: same id with stale baseVersion -> conflict (no overwrite).
        // RemoteWorkspaceClient now throws (ok:false) instead of returning a
        // false-map, so assert the thrown WorkspaceException code.
        await expectLater(
          client.request(ssh, {
            'op': 'commit',
            'deviceId': 'device-A',
            'operationId': 'op-put-2',
            'records': [
              {
                'kind': 'agent',
                'id': id,
                'value': {'v': 2},
                'baseVersion': 0,
                'deleted': false,
              },
            ],
          }),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_CONFLICT',
            ),
          ),
        );

        // Idempotent: same operationId + same payload -> same revision.
        final again = await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-A',
          'operationId': 'op-put-1',
          'records': [
            {
              'kind': 'agent',
              'id': id,
              'value': {'v': 1},
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
        expect(again['ok'], isTrue);
        expect(again['revision'], rev);

        // Different payload under the same operationId -> operation conflict.
        // Same throws-on-ok:false behavior as the CAS path above.
        await expectLater(
          client.request(ssh, {
            'op': 'commit',
            'deviceId': 'device-A',
            'operationId': 'op-put-1',
            'records': [
              {
                'kind': 'agent',
                'id': id,
                'value': {'v': 99},
                'baseVersion': 0,
                'deleted': false,
              },
            ],
          }),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_OPERATION_CONFLICT',
            ),
          ),
        );
      },
    );
  });

  group('chat latest-message snapshot (descending / beforeId / exact id)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
      final msgs = [
        {'id': 'msg/1', 'text': 'one', 'updatedAt': '2024-01-01'},
        {'id': 'msg/2', 'text': 'two', 'updatedAt': '2024-01-02'},
        {'id': 'msg/3', 'text': 'three', 'updatedAt': '2024-01-03'},
      ];
      for (var i = 0; i < msgs.length; i++) {
        await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-A',
          'operationId': 'op-msg-${i + 1}',
          'records': [
            {
              'kind': 'chat_message',
              'id': msgs[i]['id'],
              'value': {
                'text': msgs[i]['text'],
                'updatedAt': msgs[i]['updatedAt'],
              },
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
      }
    });
    tearDown(() => fx.stop());

    List<String> ids(Map<String, dynamic> resp) =>
        (resp['records'] as List).map((r) => r['id'] as String).toList();

    test('descending, beforeId cursor, and exact id all resolve', () async {
      final desc = await client.request(ssh, {
        'op': 'snapshot',
        'kind': 'chat_message',
        'descending': true,
      });
      expect(desc['ok'], isTrue);
      expect(ids(desc), ['msg/3', 'msg/2', 'msg/1']);

      final before = await client.request(ssh, {
        'op': 'snapshot',
        'kind': 'chat_message',
        'descending': true,
        'beforeId': 'msg/3',
      });
      expect(ids(before), ['msg/2', 'msg/1']);

      final exact = await client.request(ssh, {
        'op': 'snapshot',
        'kind': 'chat_message',
        'id': 'msg/2',
      });
      expect(exact['ok'], isTrue);
      expect(ids(exact), ['msg/2']);
    });
  });

  group('blob upload / download hash round-trip', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test('put then get returns identical bytes; re-put is reused', () async {
      final content = utf8.encode(
        'valhalla-remote-workspace-blob-regression-payload',
      );
      final hash = sha256.convert(content).toString();
      final b64 = base64Encode(content);

      final put = await client.request(ssh, {
        'op': 'blob_put',
        'hash': hash,
        'chunkIndex': 0,
        'totalChunks': 1,
        'totalSize': content.length,
        'data': b64,
      });
      expect(put['ok'], isTrue);
      expect(put['complete'], isTrue);
      expect(put['size'], content.length);

      final get = await client.request(ssh, {'op': 'blob_get', 'hash': hash});
      expect(get['ok'], isTrue);
      expect(base64Decode(get['data'] as String), content);
      expect(get['eof'], isTrue);

      final has = await client.request(ssh, {'op': 'blob_has', 'hash': hash});
      expect(has['ok'], isTrue);
      expect(has['exists'], isTrue);

      final put2 = await client.request(ssh, {
        'op': 'blob_put',
        'hash': hash,
        'chunkIndex': 0,
        'totalChunks': 1,
        'totalSize': content.length,
        'data': b64,
      });
      expect(put2['reused'], isTrue);
    });
  });

  group('lease A/B: observer / takeover / stale writer / append', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test(
      'A acquires, B is held, B takes over, A is stale, append is independent',
      () async {
        final a1 = await client.request(ssh, {
          'op': 'lease',
          'sessionId': 'S1',
          'action': 'acquire',
          'deviceId': 'device-A',
        });
        expect(a1['ok'], isTrue);
        expect(a1['ownerDeviceId'], 'device-A');
        final tokenA = a1['token'] as String;
        final genA = a1['generation'] as int;

        // B cannot acquire while A holds the lease: the client throws
        // (ok:false) rather than returning a false-map.
        await expectLater(
          client.request(ssh, {
            'op': 'lease',
            'sessionId': 'S1',
            'action': 'acquire',
            'deviceId': 'device-B',
          }),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_CONTROL_HELD',
            ),
          ),
        );

        final b1 = await client.request(ssh, {
          'op': 'lease',
          'sessionId': 'S1',
          'action': 'takeover',
          'deviceId': 'device-B',
        });
        expect(b1['ok'], isTrue);
        expect(b1['ownerDeviceId'], 'device-B');
        final tokenB = b1['token'] as String;
        final genB = b1['generation'] as int;
        expect(genB, genA + 1);

        // A's stale token/generation can no longer renew: the client throws
        // (ok:false) rather than returning a false-map.
        await expectLater(
          client.request(ssh, {
            'op': 'lease',
            'sessionId': 'S1',
            'action': 'renew',
            'deviceId': 'device-A',
            'token': tokenA,
            'generation': genA,
          }),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_LEASE_INVALID',
            ),
          ),
        );

        // Observer: B writes a record, A sees it via changes.
        await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-B',
          'operationId': 'op-b-1',
          'records': [
            {
              'kind': 'agent',
              'id': 'agent/b-obs',
              'value': {'x': 1},
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
        final aCh = await client.request(ssh, {'op': 'changes', 'after': 0});
        final observed = (aCh['records'] as List).any(
          (r) => r['id'] == 'agent/b-obs',
        );
        expect(observed, isTrue);

        // Output-independent append: A (no live lease) can still commit a chat
        // message. Appending does not depend on the lease output/token.
        final aAppend = await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-A',
          'operationId': 'op-a-append',
          'records': [
            {
              'kind': 'chat_message',
              'id': 'msg/A1',
              'value': {'text': 'append independent of lease'},
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
        expect(aAppend['ok'], isTrue);

        final bRel = await client.request(ssh, {
          'op': 'lease',
          'sessionId': 'S1',
          'action': 'release',
          'deviceId': 'device-B',
          'token': tokenB,
          'generation': genB,
        });
        expect(bRel['ok'], isTrue);
        expect(bRel['released'], isTrue);
      },
    );
  });

  group('typed file draft (no codec hook required)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test(
      'commits a <device>/file/<sha256> draft without a bad codec call',
      () async {
        final h = sha256
            .convert(utf8.encode('device-A-file-draft-path-x'))
            .toString();
        final draftId = 'device-A/file/$h';
        final draftVal = {
          'type': 'file',
          'deviceId': 'device-A',
          'path': '/some/path.txt',
          'digest': h,
        };
        final r = await client.request(ssh, {
          'op': 'commit',
          'deviceId': 'device-A',
          'operationId': 'op-draft-1',
          'records': [
            {
              'kind': 'draft',
              'id': draftId,
              'value': draftVal,
              'baseVersion': 0,
              'deleted': false,
            },
          ],
        });
        expect(r['ok'], isTrue);

        final snap = await client.request(ssh, {
          'op': 'snapshot',
          'kind': 'draft',
        });
        final stored = (snap['records'] as List).any((x) => x['id'] == draftId);
        expect(stored, isTrue);
      },
    );
  });

  group('nas_* query (when wiring exists)', () {
    late Fixture fx;
    late SSHClient ssh;
    setUp(() async {
      fx = await Fixture.start(seed: _seedStoreAssets);
      ssh = await fx.connect();
      await _bootstrap(ssh, 'device-A');
    });
    tearDown(() => fx.stop());

    test('committed nas_media is queryable via nas_query', () async {
      final mediaVal = {
        'type': 'media',
        'sourceId': 'src1',
        'path': '/song.mp3',
        'title': 'Song',
      };
      final put = await client.request(ssh, {
        'op': 'commit',
        'deviceId': 'device-A',
        'operationId': 'op-nas-1',
        'records': [
          {
            'kind': 'nas_media',
            'id': 'media/src1/song.mp3',
            'value': mediaVal,
            'baseVersion': 0,
            'deleted': false,
          },
        ],
      });
      expect(put['ok'], isTrue);

      final q = await client.request(ssh, {
        'op': 'nas_query',
        'sourceId': 'src1',
      });
      // Genuine assertion: the derived index must reflect the committed media.
      expect(q['ok'], isTrue);
      expect(q['records'], isA<List>());
      expect(jsonEncode(q), contains('/song.mp3'));
    });
  });

  group('store-side refusal checks (reachable via request op)', () {
    test('future schema is reported by the store', () async {
      final fx = await Fixture.start(
        seed: (home) async {
          final wsDir = Directory(
            '${home.path}/.local/share/valhalla/workspace-v1',
          );
          await wsDir.create(recursive: true);
          await File('${wsDir.path}/store.py').writeAsString(_fakeStoreSchema2);
        },
      );
      addTearDown(() => fx.stop());
      final ssh = await fx.connect();
      // The store reports schema=2; the CLIENT-side refusal (WORKSPACE_SCHEMA_
      // UNSUPPORTED) is currently unreachable because client.discover is broken
      // by cliShellQuote. This pins the data the client should reject.
      final d = await client.request(ssh, {'op': 'discover'});
      expect(d['ok'], isTrue);
      expect(d['exists'], isTrue);
      expect(d['schema'], 2);
    });

    test(
      'unsafe symlinked path is refused with WORKSPACE_PATH_UNSAFE',
      () async {
        final fx = await Fixture.start(
          seed: (home) async {
            final real = Directory('${home.path}/.local-real');
            await real.create(recursive: true);
            await Link(
              '${home.path}/.local',
            ).create('${home.path}/.local-real');
            final wsDir = Directory('${real.path}/share/valhalla/workspace-v1');
            await wsDir.create(recursive: true);
            final asset = File(
              '${_pkgRoot()}/assets/runtime/workspace_store.py',
            );
            await File(
              '${wsDir.path}/store.py',
            ).writeAsString(await asset.readAsString());
          },
        );
        addTearDown(() => fx.stop());
        final ssh = await fx.connect();
        expect(
          () => client.request(ssh, {'op': 'discover'}),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_PATH_UNSAFE',
            ),
          ),
        );
      },
    );

    test('missing python is sanitized (no leaked secrets)', () async {
      final emptyBin = await Directory.systemTemp.createTemp('ws-emptybin-');
      addTearDown(() async {
        try {
          await emptyBin.delete(recursive: true);
        } on FileSystemException {
          /* best effort */
        }
      });
      final fx = await Fixture.start(
        seed: _seedStoreAssets,
        extraEnv: {'PATH': emptyBin.path},
      );
      addTearDown(() => fx.stop());
      final ssh = await fx.connect();
      WorkspaceException? caught;
      try {
        await client.request(ssh, {'op': 'discover'});
      } on WorkspaceException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.code, startsWith('WORKSPACE_'));
      // Sanity: fixture credentials must never appear in the error surface.
      expect(caught.toString(), isNot(contains(_fxPassword)));
      expect(caught.toString(), isNot(contains(_fxUser)));
    });
  });
}
