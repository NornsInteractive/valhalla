import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/remote_browser_service.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

/// Borrowed SFTP operations: recording only, never disposed by the lease.
class _BorrowedOps implements SftpOperations {
  int listCalls = 0;
  final requested = <String>[];
  List<SftpFileItem> items = const [];
  Completer<List<SftpFileItem>>? pending;
  @override
  Future<List<SftpFileItem>> listFiles(String path) {
    listCalls++;
    requested.add(path);
    return pending?.future ?? Future.value(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OpeningClient extends Fake implements SSHClient {
  final opening = Completer<SftpClient>();
  int sharedCloses = 0;
  @override
  bool get isClosed => false;
  @override
  Future<SftpClient> sftp() => opening.future;
  @override
  Future<void> close() async {
    sharedCloses++;
  }
}

class _LateSftp extends Fake implements SftpClient {
  int closes = 0;
  @override
  Future<void> close() async {
    closes++;
  }
}

SftpFileItem _item(String path, {bool directory = false, String? linkError}) =>
    SftpFileItem(
      name: path.split('/').last,
      path: path,
      isDirectory: directory,
      linkTargetErrorCode: linkError,
      sizeBytes: 3,
      formattedSize: '3 B',
      permissions: '',
      modified: '',
      modifiedEpoch: 7,
    );

const RemoteBrowserEntry _photo = RemoteBrowserEntry(
  id: '/albums/a.png',
  name: 'a.png',
  isDirectory: false,
  mimeType: 'image/png',
);

RemoteBrowserSource _source({
  required bool Function() isCurrent,
  required Stream<List<RemoteBrowserEntry>> Function(String, Future<void>) list,
  String rootPath = '/',
  String initialPath = '/',
  bool flat = false,
  FutureOr<void> Function()? dispose,
  Future<Uint8List?> Function(RemoteBrowserEntry, int)? preview,
}) => RemoteBrowserSource(
  targetKey: 'target-key',
  label: 'fixture',
  rootPath: rootPath,
  initialPath: initialPath,
  flat: flat,
  isCurrent: isCurrent,
  list: list,
  preview: preview,
  dispose: dispose,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

final _targetChanged = isA<StateError>().having(
  (error) => error.message,
  'code',
  'REMOTE_BROWSER_TARGET_CHANGED',
);

void main() {
  group('RemoteBrowserEntry', () {
    test('hidden and selectable derive from name and link error', () {
      const hidden = RemoteBrowserEntry(
        id: '/x/.env',
        name: '.env',
        isDirectory: false,
      );
      expect(hidden.isHidden, isTrue);
      expect(hidden.selectable, isTrue);
      const blocked = RemoteBrowserEntry(
        id: '/x/link',
        name: 'link',
        isDirectory: true,
        linkTargetErrorCode: 'SFTP_LINK_TARGET_UNAVAILABLE',
      );
      expect(blocked.selectable, isFalse);
      expect(
        RemoteBrowserEntry(
          id: '/x/dir',
          name: 'dir',
          isDirectory: true,
        ).canEnter,
        isTrue,
      );
      expect(
        const RemoteBrowserEntry(
          id: '/x/no',
          name: 'no',
          isDirectory: false,
          canEnter: true,
        ).canEnter,
        isTrue,
        reason: 'explicit canEnter overrides the directory default',
      );
    });
  });

  group('location normalization', () {
    RemoteBrowserSource lease({
      String rootPath = '/srv/media',
      bool flat = false,
    }) => _source(
      isCurrent: () => true,
      list: (_, _) => const Stream.empty(),
      rootPath: rootPath,
      initialPath: rootPath,
      flat: flat,
    );

    test('keeps navigation inside the true root', () {
      final source = lease();
      expect(source.normalizeLocation('/srv/media'), '/srv/media');
      expect(
        source.normalizeLocation('/srv/media/sub//x/'),
        '/srv/media/sub/x',
      );
      expect(source.normalizeLocation('/srv/media/sub/../x'), '/srv/media/x');
      expect(() => source.normalizeLocation('/srv'), throwsArgumentError);
      expect(
        () => source.normalizeLocation('/srv/media/../..'),
        throwsArgumentError,
      );
      expect(() => source.normalizeLocation('relative'), throwsArgumentError);
      expect(
        () => source.normalizeLocation('/srv/media/${String.fromCharCode(0)}'),
        throwsArgumentError,
      );
    });

    test('flat sources reject every non-root path', () {
      final source = lease(flat: true, rootPath: '/');
      expect(source.normalizeLocation('/'), '/');
      expect(
        () => source.normalizeLocation('/library-id'),
        throwsArgumentError,
      );
    });

    test('constructor rejects invalid roots before any request', () {
      expect(
        () => _source(
          isCurrent: () => true,
          list: (_, _) => const Stream.empty(),
          rootPath: 'relative',
          initialPath: 'relative',
        ),
        throwsArgumentError,
      );
    });

    test('parentOf returns null at the boundary', () {
      final source = lease();
      expect(source.parentOf('/srv/media/albums'), '/srv/media');
      expect(source.parentOf('/srv/media/albums/one'), '/srv/media/albums');
      expect(source.parentOf('/srv/media'), isNull);
    });
  });

  group('selection', () {
    RemoteBrowserSource lease({bool flat = false, bool current = true}) =>
        _source(
          isCurrent: () => current,
          list: (_, _) => const Stream.empty(),
          flat: flat,
          rootPath: flat ? '/' : '/albums',
          initialPath: flat ? '/' : '/albums',
        );

    test('validates availability, paths and immutable entries', () {
      final source = lease();
      final selection = source.selection(const [_photo]);
      expect(selection.targetKey, 'target-key');
      expect(selection.entries, hasLength(1));
      expect(() => selection.entries.removeAt(0), throwsUnsupportedError);
      expect(
        () => source.selection(const [
          RemoteBrowserEntry(
            id: '/broken',
            name: 'broken',
            isDirectory: false,
            linkTargetErrorCode: 'SFTP_LINK_TARGET_UNAVAILABLE',
          ),
        ]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'REMOTE_BROWSER_ENTRY_UNAVAILABLE',
          ),
        ),
      );
      expect(
        () => source.selection(const [
          RemoteBrowserEntry(
            id: '/outside-root',
            name: 'outside',
            isDirectory: false,
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('changed target drops late selections', () {
      final stale = lease(current: false);
      expect(() => stale.selection(const [_photo]), throwsStateError);
      expect(stale.isCurrent, isFalse);
    });

    test('dispose invalidates selection instead of testing isCurrent late', () {
      final source = lease();
      source.ensureCurrent();
      final disposed = source.dispose();
      expect(source.isCurrent, isFalse);
      expect(
        () => source.selection(const [_photo]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'REMOTE_BROWSER_TARGET_CHANGED',
          ),
        ),
      );
      expect(disposed, completes);
    });

    test('flat library selection keeps opaque IDs unvalidated', () {
      final source = lease(flat: true);
      final selection = source.selection(const [
        RemoteBrowserEntry(
          id: 'library-1',
          name: 'Films',
          isDirectory: true,
          canEnter: false,
        ),
      ]);
      expect(selection.entries.single.id, 'library-1');
      expect(selection.entries.single.canEnter, isFalse);
    });
  });

  group('listing and per-read cancellation', () {
    test(
      'cancel after a completed directory does not block the next list',
      () async {
        var lists = 0;
        final source = _source(
          isCurrent: () => true,
          list: (_, _) {
            lists++;
            return Stream.value(const [_photo]);
          },
        );
        addTearDown(source.dispose);
        final done = Completer<void>();
        final subscription = source
            .list('/')
            .listen((_) {}, onDone: done.complete);
        await done.future.timeout(const Duration(milliseconds: 300));
        await subscription.cancel().timeout(const Duration(milliseconds: 300));
        final next = await source.list('/').toList();
        expect(lists, 2);
        expect(next.single.single.id, _photo.id);
      },
    );

    testWidgets('completed subscription cancels in a widget event loop', (
      tester,
    ) async {
      final source = _source(
        isCurrent: () => true,
        list: (_, _) => Stream.value(const [_photo]),
      );
      addTearDown(source.dispose);
      var done = false;
      final subscription = source
          .list('/')
          .listen((_) {}, onDone: () => done = true);
      await tester.pump();
      expect(done, isTrue);
      var cancelled = false;
      subscription.cancel().then((_) => cancelled = true);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(cancelled, isTrue);
    });

    test(
      'batches are incremental, immutable, and late ones are rejected',
      () async {
        var current = true;
        final backend = StreamController<List<RemoteBrowserEntry>>();
        addTearDown(backend.close);
        final source = _source(
          isCurrent: () => current,
          list: (_, _) => backend.stream,
        );
        final batches = <List<RemoteBrowserEntry>>[];
        final errors = <Object>[];
        final done = Completer<void>();
        source
            .list('/')
            .listen(batches.add, onError: errors.add, onDone: done.complete);
        await _settle();
        backend.add(const [
          RemoteBrowserEntry(id: '/a', name: 'a', isDirectory: false),
        ]);
        await _settle();
        expect(batches, hasLength(1));
        expect(() => batches.first.removeAt(0), throwsUnsupportedError);
        current = false;
        backend.add(const [
          RemoteBrowserEntry(id: '/late', name: 'late', isDirectory: false),
        ]);
        await done.future.timeout(const Duration(seconds: 2));
        expect(batches, hasLength(1), reason: 'late navigation batch dropped');
        expect(errors.single, _targetChanged);
        expect(source.isCurrent, isFalse);
      },
    );

    test(
      'cancel before the first item signals cancellation without delivering rows',
      () async {
        final order = <String>[];
        late Future<void> signal;
        final backend = StreamController<List<RemoteBrowserEntry>>(
          onCancel: () => order.add('backend-cleanup'),
        );
        addTearDown(backend.close);
        final source = _source(
          isCurrent: () => true,
          list: (_, cancelled) {
            signal = cancelled;
            cancelled.then((_) => order.add('signal-observed'));
            return backend.stream;
          },
        );
        final items = <Object>[];
        final subscription = source.list('/').listen(items.add);
        await _settle();
        await subscription.cancel().timeout(const Duration(seconds: 2));
        await _settle();
        await signal.timeout(const Duration(seconds: 2));
        expect(order.first, 'backend-cleanup');
        expect(
          order.contains('signal-observed'),
          isTrue,
          reason: 'cancelled future completed and observers ran',
        );
        expect(items, isEmpty);
      },
    );

    test('a late backend error after cancel reaches no consumer', () async {
      late Future<void> signal;
      final backend = StreamController<List<RemoteBrowserEntry>>();
      addTearDown(backend.close);
      final source = _source(
        isCurrent: () => true,
        list: (_, cancelled) {
          signal = cancelled;
          return backend.stream;
        },
      );
      final errors = <Object>[];
      final items = <Object>[];
      final subscription = source
          .list('/')
          .listen(items.add, onError: errors.add, onDone: () {});
      await _settle();
      await subscription.cancel().timeout(const Duration(seconds: 2));
      backend.addError(StateError('late backend failure'));
      backend.addError(StateError('another late failure'));
      await _settle();
      await signal.timeout(const Duration(seconds: 2));
      expect(errors, isEmpty);
      expect(items, isEmpty);
    });

    test('cancel and dispose do not await blocked backend cleanup', () async {
      final released = Completer<void>();
      final signals = <Future<void>>[];
      final backends = <StreamController<List<RemoteBrowserEntry>>>[];
      var disposed = 0;
      final source = _source(
        isCurrent: () => true,
        list: (_, signal) {
          signals.add(signal);
          final backend = StreamController<List<RemoteBrowserEntry>>(
            onCancel: () => released.future,
          );
          backends.add(backend);
          return backend.stream;
        },
        dispose: () => disposed++,
      );
      final first = source.list('/a').listen((_) {});
      final second = source.list('/b').listen((_) {});
      await _settle();
      await first.cancel().timeout(const Duration(milliseconds: 300));
      await signals.first.timeout(const Duration(milliseconds: 300));
      expect(source.isCurrent, isTrue);
      await source.dispose().timeout(const Duration(milliseconds: 300));
      await signals.last.timeout(const Duration(milliseconds: 300));
      await source.dispose();
      expect(disposed, 1);
      released.complete();
      await second.cancel();
      for (final backend in backends) {
        await backend.close();
      }
    });

    test('cancelling one directory leaves the next directory active', () async {
      final signals = <String, Future<void>>{};
      final backends = <String, StreamController<List<RemoteBrowserEntry>>>{};
      final source = _source(
        isCurrent: () => true,
        list: (path, signal) {
          signals[path] = signal;
          return (backends[path] = StreamController<List<RemoteBrowserEntry>>())
              .stream;
        },
      );
      final first = source.list('/a').listen((_) {});
      final received = <List<RemoteBrowserEntry>>[];
      final second = source.list('/b').listen(received.add);
      await _settle();
      var secondCancelled = false;
      signals['/b']!.then((_) => secondCancelled = true);
      await first.cancel();
      await signals['/a'];
      backends['/b']!.add(const [_photo]);
      await _settle();
      expect(received.single.single.id, _photo.id);
      expect(secondCancelled, isFalse);
      await second.cancel();
      await source.dispose();
      for (final backend in backends.values) {
        await backend.close();
      }
    });

    test('late Future error after cancellation is handled', () async {
      final response = Completer<List<RemoteBrowserEntry>>();
      final cancelled = Completer<void>();
      final source = _source(
        isCurrent: () => true,
        list: (_, signal) async* {
          signal.then((_) => cancelled.complete());
          yield await response.future;
        },
      );
      final errors = <Object>[];
      final sub = source.list('/').listen((_) {}, onError: errors.add);
      await _settle();
      await sub.cancel().timeout(const Duration(milliseconds: 300));
      await cancelled.future;
      response.completeError(StateError('late protocol failure'));
      await _settle();
      expect(errors, isEmpty);
      await source.dispose();
    });
  });

  group('preview', () {
    test('enforces maximum bytes and does not read non-images', () async {
      var reads = 0;
      final source = _source(
        isCurrent: () => true,
        list: (_, _) => const Stream.empty(),
        preview: (_, limit) async {
          reads++;
          return Uint8List(limit + 1);
        },
      );
      expect(
        await source.preview(
          const RemoteBrowserEntry(
            id: '/a.txt',
            name: 'a.txt',
            isDirectory: false,
          ),
        ),
        isNull,
      );
      expect(reads, 0);
      await expectLater(
        source.preview(_photo, maxBytes: 9 * 1024 * 1024),
        throwsArgumentError,
      );
      expect(reads, 0);
      await expectLater(source.preview(_photo, maxBytes: 32), throwsStateError);
      expect(reads, 1);
      await source.dispose();
    });

    test(
      'late preview cannot cross a target change or disposed lease',
      () async {
        var current = true;
        final response = Completer<Uint8List>();
        final source = _source(
          isCurrent: () => current,
          list: (_, _) => const Stream.empty(),
          preview: (_, _) => response.future,
        );
        final pending = source.preview(_photo);
        current = false;
        response.complete(Uint8List(3));
        await expectLater(pending, throwsA(_targetChanged));
        await source.dispose();
        await expectLater(source.preview(_photo), throwsA(_targetChanged));
      },
    );
  });

  test(
    'borrowed SFTP operations retain aliases and ignore synthetic entries',
    () async {
      final operations = _BorrowedOps()
        ..items = [
          _item('/x/.', directory: true),
          _item('/x/..', directory: true),
          _item('/x/.hidden'),
          _item('/x/alias', directory: true),
          _item('/x/broken', linkError: SftpFileItem.linkTargetUnavailableCode),
        ];
      final source = sftpRemoteBrowser(
        operations: operations,
        targetKey: 'host',
        label: 'Host',
        initialPath: '/x',
        isCurrent: () => true,
      );
      final entries = (await source.list('/x').toList())
          .expand((batch) => batch)
          .toList();
      expect(entries.map((entry) => entry.id), [
        '/x/.hidden',
        '/x/alias',
        '/x/broken',
      ]);
      expect(entries[0].isHidden, isTrue);
      expect(entries[1].canEnter, isTrue);
      expect(entries[2].selectable, isFalse);
      await source.dispose();
      await operations.listFiles('/still-shared');
      expect(operations.requested.last, '/still-shared');
    },
  );

  test(
    'missing-path fallback never classifies permission or transport failure',
    () {
      expect(
        remoteBrowserDirectoryMissing(StateError('ACP_DIRECTORY_NOT_FOUND')),
        isTrue,
      );
      expect(
        remoteBrowserDirectoryMissing(
          StateError('ACP_DIRECTORY_PERMISSION_DENIED'),
        ),
        isFalse,
      );
      expect(
        remoteBrowserDirectoryMissing(StateError('ACP_FILE_READ_FAILED')),
        isFalse,
      );
      expect(
        remoteBrowserDirectoryMissing(TimeoutException('timeout')),
        isFalse,
      );
      expect(
        remoteBrowserDirectoryMissing(
          SftpStatusError(SftpStatusCode.noSuchFile, 'missing'),
        ),
        isTrue,
      );
      expect(
        remoteBrowserDirectoryMissing(
          SftpStatusError(SftpStatusCode.permissionDenied, 'denied'),
        ),
        isFalse,
      );
    },
  );

  for (final agent in [false, true]) {
    test(
      '${agent ? 'agent host' : 'host'} closes a late SFTP channel without closing shared SSH',
      () async {
        final client = _OpeningClient();
        final borrowed = _BorrowedOps();
        final source = agent
            ? await agentRemoteBrowser(
                client: client,
                profile: AgentProfile(
                  id: 'agent',
                  serverId: 'host',
                  name: 'Agent',
                  description: '',
                  cliCommand: 'codex',
                ),
                targetKey: 'host-agent',
                isCurrent: () => true,
                initialPath: '/',
              )
            : sftpRemoteBrowser(
                operations: borrowed,
                targetKey: 'host',
                label: 'Host',
                initialPath: '/',
                isCurrent: () => true,
                createRequestOperations: () => SftpClientService(client),
              );
        final errors = <Object>[];
        final sub = source.list('/').listen((_) {}, onError: errors.add);
        await _settle();
        await sub.cancel().timeout(const Duration(milliseconds: 300));
        final channel = _LateSftp();
        client.opening.complete(channel);
        await _settle();
        expect(channel.closes, greaterThanOrEqualTo(1));
        expect(client.sharedCloses, 0);
        expect(borrowed.listCalls, 0);
        expect(errors, isEmpty);
        await source.dispose();
      },
    );
  }
}
