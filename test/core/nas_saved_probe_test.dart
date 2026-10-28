import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';

const source = NasSource(
  id: 'saved',
  name: 'Saved fixture',
  type: NasSourceType.smb,
  endpoint: 'smb://fixture/share',
  sshServerId: 'host',
);

class _Secrets extends SecureStorageService {
  final result = Completer<NasCredentials>();
  int reads = 0;
  @override
  Future<NasCredentials> getNasCredentials(String id) {
    expect(id, source.id);
    reads++;
    return result.future;
  }
}

class _Sources extends NasSourcesNotifier {
  int probes = 0;
  NasCredentials? used;
  @override
  NasSourcesState build() =>
      const NasSourcesState(sources: [source], selectedId: 'saved');
  void replace(NasSource value) =>
      state = NasSourcesState(sources: [value], selectedId: value.id);
  @override
  Future<void> probe(
    NasSource value,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
  }) async {
    expect(keepEmptySecrets, isFalse);
    probes++;
    used = credentials;
  }
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [
    ServerProfile(
      id: 'host',
      name: 'Fixture',
      host: '127.0.0.1',
      port: 22,
      username: 'fixture',
      authType: AuthType.password,
    ),
  ];
  void changeHost() => state = [
    ServerProfile(
      id: 'host',
      name: 'Fixture',
      host: '127.0.0.2',
      port: 22,
      username: 'fixture',
      authType: AuthType.password,
    ),
  ];
  void removeHost() => state = [];
}

void main() {
  late _Secrets secrets;
  late _Sources sources;
  late _Servers servers;
  late LocalStorageService storage;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      nasCredentialBindingKey(source.id): nasCredentialTarget(source),
    });
    storage = LocalStorageService(await SharedPreferences.getInstance());
    secrets = _Secrets();
    sources = _Sources();
    servers = _Servers();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(secrets),
        nasSourcesProvider.overrideWith(() => sources),
        serverListProvider.overrideWith(() => servers),
      ],
    );
    container.read(nasSourcesProvider);
    container.read(serverListProvider);
  });
  tearDown(() => container.dispose());

  test(
    'saved probe retains SMB domain along with password and token',
    () async {
      final pending = sources.probeSaved(source);
      const credentials = NasCredentials(
        password: 'fixture-secret',
        token: 'fixture-token',
        domain: 'FIXTURE',
      );
      secrets.result.complete(credentials);
      await pending;
      expect(sources.probes, 1);
      expect(sources.used, same(credentials));
      expect(secrets.reads, 1);
    },
  );

  test(
    'same-ID source replacement while secrets load cannot launch an old probe',
    () async {
      final pending = sources.probeSaved(source);
      sources.replace(
        const NasSource(
          id: 'saved',
          name: 'Other',
          type: NasSourceType.smb,
          endpoint: 'smb://other/share',
          sshServerId: 'host',
        ),
      );
      secrets.result.complete(const NasCredentials());
      await expectLater(
        pending,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'NAS_SOURCE_CHANGED',
          ),
        ),
      );
      expect(sources.probes, 0);
    },
  );

  test(
    'same-ID SSH target replacement while secrets load cannot launch probe',
    () async {
      final pending = sources.probeSaved(source);
      servers.changeHost();
      secrets.result.complete(const NasCredentials());
      await expectLater(pending, throwsA(isA<StateError>()));
      expect(sources.probes, 0);
    },
  );

  test('unknown saved source is refused before credentials are read', () async {
    await expectLater(
      sources.probeSaved(
        const NasSource(
          id: 'missing',
          name: 'Missing',
          type: NasSourceType.smb,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(secrets.reads, 0);
    expect(sources.probes, 0);
  });

  test('deleted SSH binding is refused before reading credentials', () async {
    servers.removeHost();
    await expectLater(
      sources.probeSaved(source),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'NAS_SSH_SERVER_NOT_FOUND',
        ),
      ),
    );
    expect(secrets.reads, 0);
    expect(sources.probes, 0);
  });

  test('disposed provider does not resume a pending saved probe', () async {
    final pending = sources.probeSaved(source);
    container.dispose();
    secrets.result.complete(const NasCredentials());
    await expectLater(pending, throwsA(isA<StateError>()));
    expect(sources.probes, 0);
  });
}
