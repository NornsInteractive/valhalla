import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _saved = NasSource(
  id: 'source',
  name: 'Saved',
  type: NasSourceType.webdav,
  endpoint: 'http://127.0.0.1:9/dav',
  username: 'owner',
);
const _oldCredentials = NasCredentials(
  password: 'fixture-old',
  token: 'fixture-token',
);
const _newCredentials = NasCredentials(
  password: 'fixture-new',
  token: 'fixture-new-token',
);
const _server = ServerProfile(
  id: 'host',
  name: 'Host',
  host: '127.0.0.1',
  username: 'fixture',
);

Matcher _code(String value) =>
    isA<StateError>().having((error) => error.message, 'code', value);

class _Storage extends Fake implements LocalStorageService {
  List<NasSource> sources;
  String? selected;
  int metadataWrites = 0;
  int selectionWrites = 0;
  bool failMetadata = false;
  bool failSelection = false;
  _Storage(NasSource source) : sources = [source], selected = source.id;
  @override
  List<NasSource> getNasSources() => List.of(sources);
  @override
  String? getNasSelectedSourceId() => selected;
  @override
  Future<void> saveNasSources(List<NasSource> value) async {
    metadataWrites++;
    if (failMetadata) throw StateError('FIXTURE_METADATA_FAILED');
    sources = List.of(value);
  }

  @override
  Future<void> saveNasSelectedSourceId(String id) async {
    selectionWrites++;
    if (failSelection) throw StateError('FIXTURE_SELECTION_FAILED');
    selected = id;
  }
}

class _Secrets extends SecureStorageService {
  final values = <String, NasCredentials>{};
  int reads = 0;
  int writes = 0;
  bool failWrite = false;
  Completer<NasCredentials>? pendingRead;
  @override
  Future<NasCredentials> getNasCredentials(String id) {
    reads++;
    final pending = pendingRead;
    pendingRead = null;
    return pending?.future ??
        Future.value(values[id] ?? const NasCredentials());
  }

  @override
  Future<void> saveNasCredentials(String id, NasCredentials value) async {
    writes++;
    if (failWrite) throw StateError('FIXTURE_SECURE_FAILED');
    values[id] = value;
  }

  @override
  Future<void> deleteNasCredentials(String id) async => values.remove(id);
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [_server];
  void replace(List<ServerProfile> value) => state = value;
}

class _Client extends Fake implements SSHClient {
  bool closed = false;
  int closes = 0;
  @override
  bool get isClosed => closed;
  @override
  Future<void> close() async {
    closes++;
    closed = true;
  }
}

class _Executor extends Fake implements SshCommandExecutor {
  final clients = <String, _Client>{'host': _Client()};
  final lookedUp = <String>[];
  @override
  SSHClient? getClient(String id) {
    lookedUp.add(id);
    return clients[id];
  }
}

class _Fixture {
  final _Storage storage;
  final _Secrets secrets;
  final _Executor executor;
  final ProviderContainer container;
  _Fixture(this.storage, this.secrets, this.executor, this.container);
  NasSourcesNotifier get notifier =>
      container.read(nasSourcesProvider.notifier);
  _Servers get servers =>
      container.read(serverListProvider.notifier) as _Servers;
}

_Fixture _fixture({
  NasSource source = _saved,
  NasCredentials credentials = _oldCredentials,
}) {
  final storage = _Storage(source);
  final secrets = _Secrets()..values[source.id] = credentials;
  final executor = _Executor();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      secureStorageServiceProvider.overrideWithValue(secrets),
      sshCommandExecutorProvider.overrideWithValue(executor),
      serverListProvider.overrideWith(_Servers.new),
    ],
  );
  container.read(nasSourcesProvider);
  addTearDown(container.dispose);
  return _Fixture(storage, secrets, executor, container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'draft browser neither saves nor selects a source or reads blank credentials',
    () async {
      final fixture = _fixture();
      final browser = await fixture.notifier.openBrowser(
        const NasSource(
          id: 'draft',
          name: 'Draft',
          type: NasSourceType.webdav,
          endpoint: 'http://127.0.0.1:9/other',
          rootPath: '/photos',
        ),
        const NasCredentials(password: 'draft-secret'),
      );
      expect(browser.rootPath, '/');
      expect(browser.initialPath, '/');
      expect(fixture.container.read(nasSourcesProvider).selectedId, 'source');
      expect(fixture.container.read(nasSourcesProvider).sources, [_saved]);
      expect(fixture.storage.metadataWrites, 0);
      expect(fixture.storage.selectionWrites, 0);
      expect(fixture.secrets.reads, 0);
      expect(fixture.secrets.writes, 0);
      await browser.dispose();
    },
  );

  test(
    'draft revision change rejects subsequent reads and selections',
    () async {
      final fixture = _fixture();
      var current = true;
      final browser = await fixture.notifier.openBrowser(
        _saved,
        _oldCredentials,
        isCurrent: () => current,
      );
      current = false;
      await expectLater(
        browser.list('/').toList(),
        throwsA(_code('REMOTE_BROWSER_TARGET_CHANGED')),
      );
      expect(
        () => browser.selection([]),
        throwsA(_code('REMOTE_BROWSER_TARGET_CHANGED')),
      );
      await browser.dispose();
    },
  );

  test(
    'unchanged source keeps empty password/token while saved browse is non-mutating',
    () async {
      final fixture = _fixture();
      final browser = await fixture.notifier.openSavedBrowser(_saved);
      expect(fixture.secrets.reads, 1);
      expect(fixture.secrets.writes, 0);
      await fixture.notifier.save(
        _saved,
        const NasCredentials(),
        probe: false,
        keepEmptySecrets: true,
      );
      expect(
        fixture.secrets.values[_saved.id]!.password,
        _oldCredentials.password,
      );
      expect(fixture.secrets.values[_saved.id]!.token, _oldCredentials.token);
      expect(browser.isCurrent, isFalse);
      await browser.dispose();
    },
  );

  final changedTargets = <String, NasSource>{
    'endpoint': const NasSource(
      id: 'source',
      name: 'Edited',
      type: NasSourceType.webdav,
      endpoint: 'http://127.0.0.2:9/dav',
      username: 'owner',
    ),
    'type': const NasSource(
      id: 'source',
      name: 'Edited',
      type: NasSourceType.jellyfin,
      endpoint: 'http://127.0.0.1:9/dav',
      username: 'owner',
    ),
    'username': const NasSource(
      id: 'source',
      name: 'Edited',
      type: NasSourceType.webdav,
      endpoint: 'http://127.0.0.1:9/dav',
      username: 'other',
    ),
    'userId': const NasSource(
      id: 'source',
      name: 'Edited',
      type: NasSourceType.webdav,
      endpoint: 'http://127.0.0.1:9/dav',
      username: 'owner',
      userId: 'other-user',
    ),
    'tunnel': const NasSource(
      id: 'source',
      name: 'Edited',
      type: NasSourceType.webdav,
      endpoint: 'http://127.0.0.1:9/dav',
      username: 'owner',
      sshServerId: 'host',
    ),
  };
  for (final entry in changedTargets.entries) {
    test('changed ${entry.key} never merges the old saved secrets', () async {
      final fixture = _fixture();
      await fixture.notifier.save(
        entry.value,
        const NasCredentials(),
        probe: false,
        keepEmptySecrets: true,
      );
      expect(fixture.secrets.reads, 0);
      expect(fixture.secrets.values['source']!.password, isEmpty);
      expect(fixture.secrets.values['source']!.token, isEmpty);
    });
  }

  test(
    'SMB domain prefill is preserved and explicit clear does not reuse domain credentials',
    () async {
      const source = NasSource(
        id: 'smb',
        name: 'SMB',
        type: NasSourceType.smb,
        endpoint: 'smb://fixture/share/sub',
        username: 'owner',
        rootPath: 'albums',
      );
      final fixture = _fixture(
        source: source,
        credentials: const NasCredentials(
          password: 'domain-password',
          domain: 'ACME',
        ),
      );
      expect(await fixture.notifier.savedDomain(source), 'ACME');
      final browser = await fixture.notifier.openSavedBrowser(source);
      expect(browser.initialPath, '/albums');
      expect(browser.rootPath, '/');
      await fixture.notifier.save(
        source,
        const NasCredentials(domain: 'ACME'),
        probe: false,
        keepEmptySecrets: true,
      );
      expect(fixture.secrets.values['smb']!.password, 'domain-password');
      await fixture.notifier.save(
        source,
        const NasCredentials(),
        probe: false,
        keepEmptySecrets: true,
      );
      expect(fixture.secrets.values['smb']!.domain, isEmpty);
      expect(fixture.secrets.values['smb']!.password, isEmpty);
      await browser.dispose();
    },
  );

  test(
    'credential-only save invalidates an in-flight saved credential read',
    () async {
      final fixture = _fixture();
      final read = Completer<NasCredentials>();
      fixture.secrets.pendingRead = read;
      final pending = fixture.notifier.openSavedBrowser(_saved);
      final assertion = expectLater(
        pending,
        throwsA(_code('NAS_SOURCE_CHANGED')),
      );
      await fixture.notifier.save(_saved, _newCredentials, probe: false);
      read.complete(_oldCredentials);
      await assertion;
    },
  );

  test('credential-only save invalidates late domain prefill', () async {
    const source = NasSource(
      id: 'smb',
      name: 'SMB',
      type: NasSourceType.smb,
      endpoint: 'smb://fixture/share',
      username: 'owner',
    );
    final fixture = _fixture(source: source);
    final read = Completer<NasCredentials>();
    fixture.secrets.pendingRead = read;
    final pending = fixture.notifier.savedDomain(source);
    final assertion = expectLater(
      pending,
      throwsA(_code('NAS_SOURCE_CHANGED')),
    );
    await fixture.notifier.save(
      source,
      const NasCredentials(password: 'new', domain: 'NEW'),
      probe: false,
    );
    read.complete(const NasCredentials(password: 'old', domain: 'OLD'));
    await assertion;
  });

  for (final stage in ['metadata', 'selection']) {
    test(
      '$stage failure after secure write blocks old/new leases until explicit resave',
      () async {
        final fixture = _fixture();
        final browser = await fixture.notifier.openSavedBrowser(_saved);
        final snapshot = fixture.container
            .read(nasSourcesProvider)
            .sources
            .single;
        fixture.storage.failMetadata = stage == 'metadata';
        fixture.storage.failSelection = stage == 'selection';
        await expectLater(
          fixture.notifier.save(_saved, _newCredentials, probe: false),
          throwsStateError,
        );
        expect(fixture.secrets.values['source'], same(_newCredentials));
        expect(
          fixture.container.read(nasSourcesProvider).sources.single,
          same(snapshot),
        );
        expect(
          browser.isCurrent,
          isFalse,
          reason: 'generation advances before metadata succeeds',
        );
        await expectLater(
          fixture.notifier.openSavedBrowser(_saved),
          throwsA(_code('NAS_SOURCE_SAVE_INCOMPLETE')),
        );
        await expectLater(
          fixture.notifier.openBrowser(_saved, _newCredentials),
          throwsA(_code('NAS_SOURCE_SAVE_INCOMPLETE')),
        );
        fixture.storage.failMetadata = false;
        fixture.storage.failSelection = false;
        await fixture.notifier.save(_saved, _newCredentials, probe: false);
        final recovered = await fixture.notifier.openSavedBrowser(_saved);
        expect(recovered.isCurrent, isTrue);
        expect(browser.isCurrent, isFalse);
        await browser.dispose();
        await recovered.dispose();
      },
    );
  }

  test(
    'failed secure write preserves the current browser and prior credentials',
    () async {
      final fixture = _fixture();
      final browser = await fixture.notifier.openSavedBrowser(_saved);
      fixture.secrets.failWrite = true;
      await expectLater(
        fixture.notifier.save(_saved, _newCredentials, probe: false),
        throwsStateError,
      );
      expect(browser.isCurrent, isTrue);
      expect(fixture.secrets.values['source'], same(_oldCredentials));
      expect(fixture.storage.metadataWrites, 0);
      await browser.dispose();
    },
  );

  test(
    'legacy SFTP captures source.id client and rejects replacement/removal',
    () async {
      const source = NasSource(
        id: 'host',
        name: 'Legacy',
        type: NasSourceType.sftp,
        rootPath: '/media',
      );
      final fixture = _fixture(source: source);
      final originalClient = fixture.executor.clients['host']!;
      final browser = await fixture.notifier.openSavedBrowser(source);
      expect(fixture.executor.lookedUp, contains('host'));
      expect(browser.initialPath, '/media');
      expect(browser.rootPath, '/');
      fixture.executor.clients['host'] = _Client();
      expect(browser.isCurrent, isFalse);
      final second = await fixture.notifier.openSavedBrowser(source);
      fixture.servers.replace([]);
      expect(second.isCurrent, isFalse);
      await expectLater(
        fixture.notifier.openSavedBrowser(source),
        throwsA(_code('NAS_SSH_SERVER_NOT_FOUND')),
      );
      await browser.dispose();
      await second.dispose();
      expect(originalClient.closes, 0);
      expect(fixture.executor.clients['host']!.closes, 0);
    },
  );

  test('missing SSH profile refuses a retained live SSH client', () async {
    const source = NasSource(
      id: 'sftp',
      name: 'SFTP',
      type: NasSourceType.sftp,
      sshServerId: 'host',
    );
    final fixture = _fixture(source: source);
    fixture.servers.replace([]);
    expect(fixture.executor.clients['host']!.isClosed, isFalse);
    await expectLater(
      fixture.notifier.openBrowser(source, const NasCredentials()),
      throwsA(_code('NAS_SSH_SERVER_NOT_FOUND')),
    );
  });

  test(
    'source metadata copy and display name retain saved-source compatibility',
    () async {
      final fixture = _fixture();
      final copy = NasSource.fromJson({
        ..._saved.toJson(),
        'name': 'Display alias',
      });
      final browser = await fixture.notifier.openSavedBrowser(copy);
      expect(browser.isCurrent, isTrue);
      await browser.dispose();
    },
  );

  test(
    'real probe changes diagnostics but does not invalidate an existing browser',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 207;
        await request.response.close();
      });
      final source = NasSource(
        id: 'probe',
        name: 'Probe',
        type: NasSourceType.webdav,
        endpoint: 'http://127.0.0.1:${server.port}/dav',
      );
      final fixture = _fixture(source: source);
      final browser = await fixture.notifier.openSavedBrowser(source);
      await fixture.notifier.probe(source, const NasCredentials());
      expect(browser.isCurrent, isTrue);
      expect(fixture.secrets.writes, 0);
      expect(fixture.storage.metadataWrites, 0);
      expect(
        fixture.container.read(nasSourcesProvider).diagnosticFor(source)!.stage,
        NasConnectionStage.ready,
      );
      await browser.dispose();
    },
  );

  test(
    'NAS list cancellation aborts an HTTP request waiting for headers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final started = Completer<void>();
      final released = Completer<void>();
      final disconnected = Completer<void>();
      server.listen((request) async {
        await request.drain<void>();
        request.response.done.then(
          (_) {
            if (!disconnected.isCompleted) disconnected.complete();
          },
          onError: (Object _) {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
        started.complete();
        await released.future;
        try {
          await request.response.close();
        } catch (_) {}
      });
      addTearDown(() {
        if (!released.isCompleted) released.complete();
      });
      final source = NasSource(
        id: 'stalled',
        name: 'Stalled',
        type: NasSourceType.webdav,
        endpoint: 'http://127.0.0.1:${server.port}/dav',
      );
      final fixture = _fixture(source: source);
      final browser = await fixture.notifier.openSavedBrowser(source);
      final errors = <Object>[];
      final sub = browser.list('/').listen((_) {}, onError: errors.add);
      await started.future.timeout(const Duration(seconds: 2));
      await sub.cancel().timeout(const Duration(milliseconds: 500));
      expect(browser.isCurrent, isTrue);
      await browser.dispose().timeout(const Duration(milliseconds: 500));
      released.complete();
      await disconnected.future.timeout(const Duration(seconds: 2));
      expect(errors, isEmpty);
    },
  );
}
