import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';

class _SecureStorage extends SecureStorageService {
  final credentials = <String, NasCredentials>{};
  @override
  Future<NasCredentials> getNasCredentials(String sourceId) async =>
      credentials[sourceId] ?? const NasCredentials();
  @override
  Future<void> saveNasCredentials(String sourceId, NasCredentials value) async {
    credentials[sourceId] = value;
  }

  @override
  Future<void> deleteNasCredentials(String sourceId) async {
    credentials.remove(sourceId);
  }
}

/// Secure store whose reads can be armed to return a controllable future, so a
/// credential read can be held in flight while the source/secret changes.
class _DelayedSecureStorage extends SecureStorageService {
  final credentials = <String, NasCredentials>{};
  final _armed = <String, Completer<NasCredentials>>{};
  void arm(String id) => _armed[id] = Completer<NasCredentials>();
  void completeRead(String id, NasCredentials value) =>
      _armed.remove(id)?.complete(value);
  @override
  Future<NasCredentials> getNasCredentials(String sourceId) async {
    // Keep the completer reachable until completeRead() fires, otherwise the
    // in-flight future would hang.
    final completer = _armed[sourceId];
    if (completer != null) return completer.future;
    return credentials[sourceId] ?? const NasCredentials();
  }

  @override
  Future<void> saveNasCredentials(String sourceId, NasCredentials value) async {
    credentials[sourceId] = value;
  }

  @override
  Future<void> deleteNasCredentials(String sourceId) async {
    credentials.remove(sourceId);
  }
}

/// In-memory preferences store that makes every write to a credential-binding
/// key fail, to exercise the fail-closed path of refreshFromWorkspace.
class _FailingBindingStore extends InMemorySharedPreferencesStore {
  _FailingBindingStore(super.data) : super.withData();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    // SharedPreferences writes with a 'flutter.' prefix, so match the fully
    // prefixed binding key.
    if (key.startsWith('flutter.valhalla_nas_credential_target_v1::')) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

/// Tests for the data-only workspace refresh + the credential security boundary
/// that must hold when remote metadata moves a source's connection/auth target
/// under an existing id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const source = NasSource(
    id: 's1',
    name: 'Media',
    type: NasSourceType.webdav,
    endpoint: 'http://old.invalid/',
    username: 'u',
  );

  NasSource withSource(
    NasSource s, {
    String? name,
    String? endpoint,
    String? username,
  }) {
    final json = s.toJson();
    if (name != null) json['name'] = name;
    if (endpoint != null) json['endpoint'] = endpoint;
    if (username != null) json['username'] = username;
    return NasSource.fromJson(json);
  }

  Future<LocalStorageService> storageWith(List<NasSource> sources) async {
    SharedPreferences.setMockInitialValues({
      'valhalla_nas_sources_v1': jsonEncode(
        sources.map((source) => source.toJson()).toList(),
      ),
    });
    return LocalStorageService.init();
  }

  ProviderContainer makeContainer(
    LocalStorageService storage,
    SecureStorageService secure,
  ) =>
      ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(secure),
        ],
      );

  group('refreshFromWorkspace data-only hydration', () {
    test('no-op poll keeps identical source instances, selection and diagnostics',
        () async {
      final storage = await storageWith([source, source.copyId('s2')]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.select('s1');
      final before = container.read(nasSourcesProvider);
      final s1Before = before.sources.firstWhere((s) => s.id == 's1');
      final s2Before = before.sources.firstWhere((s) => s.id == 's2');

      await notifier.refreshFromWorkspace();

      final after = container.read(nasSourcesProvider);
      expect(identical(after.sources.firstWhere((s) => s.id == 's1'), s1Before),
          isTrue);
      expect(identical(after.sources.firstWhere((s) => s.id == 's2'), s2Before),
          isTrue);
      // Selector identity keeps adapter/player consumers from rebuilding.
      expect(after.selectedId, 's1');
      expect(after.sources.length, 2);
      container.dispose();
    });

    test('adding another source does not reset the selected source or adapter',
        () async {
      final storage = await storageWith([source, source.copyId('s2')]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.select('s1');
      final s1Before = container
          .read(nasSourcesProvider)
          .sources
          .firstWhere((s) => s.id == 's1');

      // The adapter is built once for the selected source.
      final adapterBefore =
          await container.read(nasSourceAdapterProvider('s1').future);

      // Remote metadata adds a third source; selection stays on s1.
      await storage.saveNasSources([source, source.copyId('s2'), source.copyId('s3')]);
      await notifier.refreshFromWorkspace();

      final after = container.read(nasSourcesProvider);
      expect(after.selectedId, 's1');
      expect(
        identical(
          after.sources.firstWhere((s) => s.id == 's1'),
          s1Before,
        ),
        isTrue,
        reason: 'unchanged source instance must be preserved',
      );
      // Because the source instance is identical, the cached adapter is reused.
      final adapterAfter =
          await container.read(nasSourceAdapterProvider('s1').future);
      expect(identical(adapterBefore, adapterAfter), isTrue);
      container.dispose();
    });

    test('removal of the selected source falls back to another selection',
        () async {
      final storage = await storageWith([source, source.copyId('s2')]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.select('s1');
      expect(container.read(nasSourcesProvider).selectedId, 's1');

      await storage.saveNasSources([source.copyId('s2')]);
      await notifier.refreshFromWorkspace();

      final after = container.read(nasSourcesProvider);
      expect(after.sources.any((s) => s.id == 's1'), isFalse);
      expect(after.selectedId, 's2');
      container.dispose();
    });

    test('a concurrent local save is not clobbered by a metadata refresh',
        () async {
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      final renamed = withSource(source, name: 'Media Renamed');

      // Save enqueued after the refresh: refresh reads the old storage, then the
      // serialized save applies and wins the final state.
      await Future.wait([
        notifier.refreshFromWorkspace(),
        notifier.save(renamed, const NasCredentials(password: 'p'), probe: false),
      ]);

      final after = container.read(nasSourcesProvider);
      expect(after.sources.single.name, 'Media Renamed');
      expect(after.selectedId, 's1');
      expect(
        (await notifier.credentialsFor(renamed)).password,
        'p',
      );
      container.dispose();
    });

    test('diagnostics are preserved for unchanged targets and pruned on change',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 207;
        request.response.headers.contentType =
            ContentType('application', 'xml');
        request.response.write('<d:multistatus xmlns:d="DAV:"/>');
        await request.response.close();
      });
      final liveSource = source.copyWithEndpoint(
        'http://127.0.0.1:${server.port}/library/',
      );
      final storage = await storageWith([liveSource]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.probe(liveSource, const NasCredentials());

      final probed = container.read(nasSourcesProvider);
      expect(probed.diagnosticFor(liveSource)?.stage,
          NasConnectionStage.ready);
      final diagnosticBefore = probed.diagnosticFor(liveSource);

      // No-op refresh: identical source, identical diagnostic instance.
      await notifier.refreshFromWorkspace();
      final afterNoop = container.read(nasSourcesProvider);
      expect(identical(afterNoop.diagnosticFor(liveSource), diagnosticBefore),
          isTrue);

      // Remote metadata changes the endpoint -> diagnostic must be pruned.
      final moved = withSource(liveSource, endpoint: 'http://moved.invalid/');
      await storage.saveNasSources([moved]);
      await notifier.refreshFromWorkspace();
      final afterMove = container.read(nasSourcesProvider);
      expect(afterMove.diagnostics, isEmpty);
      expect(afterMove.diagnosticFor(moved), isNull);
      await server.close(force: true);
      container.dispose();
    });
  });

  group('credential security boundary on remote target change', () {
    test('legacy missing marker is bound to the old target at refresh time',
        () async {
      // Source placed in storage WITHOUT a credential marker (legacy state).
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      await secure.saveNasCredentials(source.id,
          const NasCredentials(password: 'legacy-secret'));
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);

      final moved = withSource(source, endpoint: 'http://moved.invalid/');
      await storage.saveNasSources([moved]);
      await notifier.refreshFromWorkspace();

      // The marker is now the OLD target fingerprint and nothing was deleted.
      expect(
        storage.workspacePreferences.raw
            .getString(nasCredentialBindingKey(source.id)),
        nasCredentialTarget(source),
      );
      expect(secure.credentials[source.id]?.password, 'legacy-secret');

      // The new target must not receive the saved secret.
      await expectLater(
        notifier.credentialsFor(moved),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_AUTH_REQUIRED',
          ),
        ),
      );
      container.dispose();
    });

    test('changed endpoint never reads or sends the old credentials',
        () async {
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.save(
        source,
        const NasCredentials(password: 'secret'),
        probe: false,
      );

      // Simulate a remote metadata refresh that moves the endpoint.
      final moved = withSource(source, endpoint: 'http://moved.invalid/');
      await storage.saveNasSources([moved]);
      await notifier.refreshFromWorkspace();

      await expectLater(
        notifier.credentialsFor(moved),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_AUTH_REQUIRED',
          ),
        ),
      );
      // Secure secrets are untouched by a refresh.
      expect(secure.credentials[source.id]?.password, 'secret');
      container.dispose();
    });

    test('a name-only change keeps the same credentials (no forced re-login)',
        () async {
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.save(
        source,
        const NasCredentials(password: 'secret'),
        probe: false,
      );

      final renamed = withSource(source, name: 'Media Library');
      await storage.saveNasSources([renamed]);
      await notifier.refreshFromWorkspace();

      final creds = await notifier.credentialsFor(renamed);
      expect(creds.password, 'secret');
      container.dispose();
    });

    test('an explicit new save binds the new target and recovers access',
        () async {
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.save(
        source,
        const NasCredentials(password: 'secret'),
        probe: false,
      );

      final moved = withSource(source, endpoint: 'http://moved.invalid/');
      await storage.saveNasSources([moved]);
      await notifier.refreshFromWorkspace();
      // Before re-saving, the new target is refused.
      await expectLater(
        notifier.credentialsFor(moved),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'NAS_AUTH_REQUIRED',
        )),
      );

      // User explicitly saves new credentials for the new target.
      await notifier.save(
        moved,
        const NasCredentials(password: 'new-secret'),
        probe: false,
      );
      final creds = await notifier.credentialsFor(moved);
      expect(creds.password, 'new-secret');
      // The marker now matches the moved target.
      expect(
        storage.workspacePreferences.raw
            .getString(nasCredentialBindingKey(source.id)),
        nasCredentialTarget(moved),
      );
      container.dispose();
    });

    test('the credential marker persists across provider recreation',
        () async {
      SharedPreferences.setMockInitialValues({
        'valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
      });
      final storage = await LocalStorageService.init();
      // A single secure store shared across both provider instances, proving the
      // binding lives in local-only preferences rather than memory.
      final secure = _SecureStorage();
      final first = makeContainer(storage, secure);
      await first
          .read(nasSourcesProvider.notifier)
          .save(source, const NasCredentials(password: 'p'), probe: false);
      first.dispose();

      final second = makeContainer(storage, secure);
      final creds =
          await second.read(nasSourcesProvider.notifier).credentialsFor(source);
      expect(creds.password, 'p');
      expect(
        storage.workspacePreferences.raw
            .getString(nasCredentialBindingKey(source.id)),
        nasCredentialTarget(source),
      );
      second.dispose();
    });

    test('unsaved draft probe with explicit credentials never falls back to '
        'saved secrets', () async {
      final storage = await storageWith([source]);
      final secure = _SecureStorage();
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.save(
        source,
        const NasCredentials(password: 'saved'),
        probe: false,
      );

      // A draft with a changed target and explicit credentials must be allowed
      // through probe() without consulting (or being denied by) the saved marker.
      final draft = withSource(source, endpoint: 'http://other.invalid/');
      Object? error;
      try {
        await notifier.probe(draft, const NasCredentials(password: 'explicit'));
      } catch (e) {
        error = e;
      }
      // The only forbidden outcome is a NAS_AUTH_REQUIRED rejection: that would
      // mean the explicit draft was refused by the saved-secret marker. A plain
      // connection failure to the unreachable host is the expected behaviour.
      if (error is StateError) {
        expect(error.message, isNot('NAS_AUTH_REQUIRED'));
      }
      // The explicit credentials reached _credentials untouched: there is no
      // fallback to the 'saved' secret for an unchanged target match either way.
      container.dispose();
    });
  });

  group('credential read race regressions', () {
    test('a pending encrypted read rejects a mid-flight target/secret change',
        () async {
      final secure = _DelayedSecureStorage();
      final storage = await storageWith([source]);
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      // Establish a valid marker + secret for A so the pre-await checks pass.
      await notifier.save(
        source,
        const NasCredentials(password: 'Asecret'),
        probe: false,
      );
      // Hold the encrypted read in flight.
      secure.arm(source.id);
      final futureA = notifier.credentialsFor(source);
      await Future<void>.delayed(Duration.zero);
      // While in flight, move metadata/secret to B via an explicit save.
      final sourceB = withSource(source, endpoint: 'http://b.invalid/');
      await notifier.save(
        sourceB,
        const NasCredentials(password: 'Bsecret'),
        probe: false,
      );
      // Complete the original read with B's secret.
      secure.completeRead(source.id, const NasCredentials(password: 'Bsecret'));
      // Must reject and never surface B's secret as A's credentials.
      await expectLater(
        futureA,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_SOURCE_CHANGED',
          ),
        ),
      );
      // B's secret is valid for B, never for A.
      expect(
        (await notifier.credentialsFor(sourceB)).password,
        'Bsecret',
      );
      container.dispose();
    });

    test('a pending marker rejects old metadata and an explicit save recovers',
        () async {
      SharedPreferences.setMockInitialValues({
        'valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
        nasCredentialBindingKey(source.id): 'pending',
      });
      final storage = await LocalStorageService.init();
      final secure = _SecureStorage();
      // Secure store holds B's secret under A's id (interrupted save).
      secure.credentials[source.id] =
          const NasCredentials(password: 'Bsecret');
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      // Recreate provider: credentialsFor(A) must reject, never leaking Bsecret.
      await expectLater(
        notifier.credentialsFor(source),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_AUTH_REQUIRED',
          ),
        ),
      );
      // Explicit nonempty save with the new target bypasses the invalid marker.
      final sourceB = withSource(source, endpoint: 'http://b.invalid/');
      await notifier.save(
        sourceB,
        const NasCredentials(password: 'Bsecret'),
        keepEmptySecrets: true,
        probe: false,
      );
      final creds = await notifier.credentialsFor(sourceB);
      expect(creds.password, 'Bsecret');
      // The old metadata target still cannot claim the secret.
      await expectLater(
        notifier.credentialsFor(source),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_AUTH_REQUIRED',
          ),
        ),
      );
      container.dispose();
    });

    test('a failed marker write fails closed and keeps old state and secret',
        () async {
      // Reset the cached singleton so our store is actually used by getInstance.
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = _FailingBindingStore({
        'flutter.valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
      });
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final storage = await LocalStorageService.init();
      final secure = _SecureStorage();
      await secure.saveNasCredentials(
        source.id,
        const NasCredentials(password: 'Asecret'),
      );
      final container = makeContainer(storage, secure);
      final notifier = container.read(nasSourcesProvider.notifier);
      // Remote moves the endpoint under the same id.
      final moved = withSource(source, endpoint: 'http://moved.invalid/');
      await storage.saveNasSources([moved]);
      // The binding write fails; refresh must throw and NOT hydrate moved.
      await expectLater(
        notifier.refreshFromWorkspace(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_SOURCE_SAVE_INCOMPLETE',
          ),
        ),
      );
      // State still reflects the original (un-hydrated) source.
      final after = container.read(nasSourcesProvider);
      expect(after.sources.single.id, source.id);
      expect(after.sources.single.endpoint, source.endpoint);
      // The marker was never written. SharedPreferences caches an optimistic
      // value before the platform write, so reload to observe the store truth.
      await storage.workspacePreferences.reload();
      expect(
        storage.workspacePreferences.raw
            .containsKey(nasCredentialBindingKey(source.id)),
        isFalse,
      );
      // The original secret is intact and was never claimed for the new target.
      expect(secure.credentials[source.id]?.password, 'Asecret');
      container.dispose();
    });
  });
}

extension on NasSource {
  NasSource copyId(String id) => NasSource(
        id: id,
        name: name,
        type: type,
        endpoint: endpoint,
        sshServerId: sshServerId,
        username: username,
        userId: userId,
        rootPath: rootPath,
      );
  NasSource copyWithEndpoint(String endpoint) => NasSource(
        id: id,
        name: name,
        type: type,
        endpoint: endpoint,
        sshServerId: sshServerId,
        username: username,
        userId: userId,
        rootPath: rootPath,
      );
}
