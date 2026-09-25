import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/nas/nas_webdav_adapter.dart';

class _SecureStorage extends SecureStorageService {
  final deleted = <String>[];
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
    deleted.add(sourceId);
    credentials.remove(sourceId);
  }
}

class _DownloadAdapter extends NasSourceAdapter {
  @override
  final source = const NasSource(
    id: 'download',
    name: 'Download',
    type: NasSourceType.webdav,
  );
  @override
  Future<void> probe() async {}
  @override
  Stream<List<NasMediaItem>> scan(
    NasScanConfig config,
    NasCancellation cancellation,
  ) => const Stream.empty();
  @override
  Future<NasResource> resolve(
    NasMediaItem item, {
    NasPlaybackQuality quality = NasPlaybackQuality.original,
  }) async => NasResource(
    sizeBytes: 3,
    read: (_, _, cancellation) async* {
      cancellation.check();
      yield [1, 2, 3];
    },
  );
}

class _NoExternalApp extends DownloadPlatformService {
  _NoExternalApp(Directory directory)
    : super(directoryProvider: () async => directory);
  @override
  Future<void> openFile(String path) async => throw StateError('no handler');
}

Future<LocalStorageService> _storage(List<NasSource> sources) async {
  SharedPreferences.setMockInitialValues({
    'valhalla_nas_sources_v1': jsonEncode(
      sources.map((source) => source.toJson()).toList(),
    ),
  });
  return LocalStorageService.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'external launch failure preserves the completed original download',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-open-review-',
      );
      final service = NasDownloadService(
        (_) async => _DownloadAdapter(),
        platform: _NoExternalApp(directory),
      );
      try {
        final reported = service.changes.firstWhere(
          (tasks) =>
              tasks.any((task) => task.error == 'NAS_EXTERNAL_OPEN_FAILED'),
        );
        service.download(
          const NasMediaItem(
            serverId: 'download',
            path: '/original.mp3',
            kind: NasMediaKind.audio,
            sizeBytes: 3,
            modifiedEpoch: 0,
          ),
          openWhenDone: true,
        );
        final task = (await reported.timeout(
          const Duration(seconds: 5),
        )).single;
        expect(task.status, NasDownloadStatus.completed);
        expect(await File(task.localPath!).readAsBytes(), [1, 2, 3]);
        expect(
          await directory
              .list()
              .where((file) => file.path.endsWith('.part'))
              .isEmpty,
          isTrue,
        );
        await expectLater(service.open(task.id), throwsStateError);
        expect(service.tasks.single.status, NasDownloadStatus.completed);
      } finally {
        await service.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'concurrent profile removals cannot resurrect a deleted source',
    () async {
      final storage = await _storage(const [
        NasSource(id: 'a', name: 'A', type: NasSourceType.sftp),
        NasSource(id: 'b', name: 'B', type: NasSourceType.sftp),
      ]);
      final secure = _SecureStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(secure),
        ],
      );
      try {
        final notifier = container.read(nasSourcesProvider.notifier);
        await Future.wait([notifier.remove('a'), notifier.remove('b')]);
        expect(secure.deleted, containsAll(['a', 'b']));
        expect(container.read(nasSourcesProvider).sources, isEmpty);
        expect(container.read(nasSourcesProvider).selected, isNull);
        expect(storage.getNasSources(), isEmpty);
      } finally {
        container.dispose();
      }
    },
  );

  test(
    'editing credentials and removing an active adapter has no provider cycle',
    () async {
      const source = NasSource(
        id: 'active',
        name: 'Active',
        type: NasSourceType.webdav,
        endpoint: 'http://127.0.0.1:18086',
      );
      final storage = await _storage([source]);
      final secure = _SecureStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(secure),
        ],
      );
      try {
        final notifier = container.read(nasSourcesProvider.notifier);
        final original = await container.read(
          nasSourceAdapterProvider(source.id).future,
        );
        final currentSource = container.read(nasSourcesProvider).selected!;
        await notifier.save(
          currentSource,
          const NasCredentials(password: 'updated'),
          probe: false,
        );
        final refreshed = await container.read(
          nasSourceAdapterProvider(source.id).future,
        );
        expect(identical(original, refreshed), false);
        expect(secure.credentials[source.id]?.password, 'updated');
        await notifier.remove(source.id);
        expect(container.read(nasSourcesProvider).sources, isEmpty);
        await expectLater(
          container.read(nasSourceAdapterProvider(source.id).future),
          throwsStateError,
        );
      } finally {
        container.dispose();
      }
    },
  );

  test('DAV source root is applied once by the initial library scan', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      if (request.method == 'PROPFIND' && request.uri.path == '/dav/media/') {
        request.response.statusCode = 207;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
        );
        request.response.write('''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:response>
<d:href>/dav/media/Music%20one.mp3</d:href><d:propstat><d:prop>
<d:resourcetype/><d:getcontentlength>42</d:getcontentlength>
<d:getcontenttype>audio/mpeg</d:getcontenttype>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response></d:multistatus>''');
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final source = NasSource(
      id: 'dav',
      name: 'DAV',
      type: NasSourceType.webdav,
      endpoint: 'http://127.0.0.1:${server.port}/dav',
      rootPath: '/media',
    );
    final storage = await _storage([source]);
    final directory = await Directory.systemTemp.createTemp('nas-root-review-');
    final repository = NasIndexRepository('${directory.path}/index.sqlite');
    await repository.initialize();
    final adapter = NasWebDavAdapter(source, const NasCredentials());
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        nasIndexRepositoryProvider.overrideWith((ref) async => repository),
        nasSourceAdapterProvider(
          source.id,
        ).overrideWith((ref) async => adapter),
      ],
    );
    try {
      final notifier = container.read(nasProvider.notifier);
      await notifier.refresh();
      await notifier.scan();
      expect(paths, ['/dav/media/']);
      expect(container.read(nasProvider).errorCode, isNull);
      final items = await repository.query(source.id);
      expect(items.single.path, '/dav/media/Music%20one.mp3');
      expect(items.single.name, 'Music one.mp3');
      expect(items.single.folder, '/dav/media');
    } finally {
      container.dispose();
      await adapter.dispose();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
