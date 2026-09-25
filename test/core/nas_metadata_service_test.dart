import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:valhalla/core/services/nas_metadata_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/infrastructure/nas/nas_media_proxy_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Ssh extends Fake implements SshCommandExecutor {}

class _Native extends Fake implements NativePlayer {
  final properties = <String, String>{};
  final tags = {
    'title': 'Unplayed song',
    'ARTIST': 'Test artist',
    'album': 'Test album',
    'TRACK': '3/12',
  };
  bool loaded = false;
  @override
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties[property] = value;
  }

  @override
  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async {
    if (property == 'track-list/count') return loaded ? '1' : '0';
    if (property == 'metadata/list/count') return tags.length.toString();
    final parts = property.split('/');
    final entry = tags.entries.elementAt(int.parse(parts[2]));
    return parts[3] == 'key' ? entry.key : entry.value;
  }
}

class _Player extends Fake implements Player {
  final _Native native = _Native();
  HttpClient? client;
  bool disposed = false, fail = false;
  int opened = 0;
  final playValues = <bool>[];
  @override
  PlatformPlayer? get platform => native;
  @override
  PlayerState get state => const PlayerState(duration: Duration(minutes: 3));
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened++;
    playValues.add(play);
    if (fail) throw StateError('Unreadable fixture');
    client = HttpClient();
    final request = await client!.getUrl(Uri.parse((playable as Media).uri));
    request.headers.set('Range', 'bytes=0-31');
    final response = await request.close();
    await response.drain<void>();
    native.loaded = true;
  }

  @override
  Future<void> stop() async {
    native.loaded = false;
    client?.close(force: true);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

class _Adapter extends NasSourceAdapter {
  @override
  final NasSource source;
  NasByteReader? reader;
  Future<void> Function()? probeAction;
  int reserved = 0, largestRange = 0;
  _Adapter({NasSourceType type = NasSourceType.webdav})
    : source = NasSource(id: 'source', name: 'Test', type: type);
  @override
  Future<void> probe() async => probeAction?.call();
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
    sizeBytes: item.sizeBytes,
    mimeType: 'audio/mpeg',
    read:
        reader ??
        (start, end, cancellation) async* {
          cancellation.check();
          final length = end! - start;
          reserved += length;
          if (length > largestRange) largestRange = length;
          yield Uint8List(length);
        },
  );
}

NasMediaItem _item(int index, {int size = 8 * 1024 * 1024, int modified = 1}) =>
    NasMediaItem(
      serverId: 'source',
      path: '/music/$index.mp3',
      kind: NasMediaKind.audio,
      sizeBytes: size,
      modifiedEpoch: modified,
    );

Future<NasIndexRepository> _repository() async {
  final directory = await Directory.systemTemp.createTemp('nas-metadata-');
  addTearDown(() => directory.delete(recursive: true));
  final repo = NasIndexRepository('${directory.path}/index.sqlite3');
  await repo.initialize();
  return repo;
}

void main() {
  test(
    'indexes unplayed music beyond one database page using a paused decoder',
    () async {
      final repo = await _repository();
      await repo.replaceServerItems('source', List.generate(67, _item));
      expect((await repo.pendingMetadata('source')).length, 32);
      final proxy = NasMediaProxyService(_Ssh()),
          player = _Player(),
          adapter = _Adapter();
      final service = NasMetadataService(
        repo,
        proxy,
        (_) async => adapter,
        playerFactory: () => player,
      );
      addTearDown(() async {
        await service.dispose();
        await proxy.dispose();
      });
      await service.start('source');
      expect(service.state.processed, 67);
      expect(service.state.failed, 0);
      expect(player.opened, 67);
      expect(player.playValues.every((play) => !play), true);
      expect(player.native.properties['access-references'], 'no');
      expect(player.native.properties['demuxer-lavf-format'], 'mp3');
      expect(player.disposed, true);
      expect(await repo.pendingMetadata('source'), isEmpty);
      expect(
        (await repo.groups('source', NasIndexGroup.byArtist)).single.count,
        67,
      );
      expect(
        (await repo.groups('source', NasIndexGroup.byAlbum)).single.name,
        'Test album',
      );
      expect((await repo.query('source')).first.trackNumber, 3);
      expect(adapter.reserved, 67 * 32);
    },
  );

  test(
    'concurrent head and tail readers share a strict upstream byte budget',
    () async {
      final adapter = _Adapter();
      final original = await adapter.resolve(_item(0));
      final cancellation = NasCancellation();
      final budget = NasMetadataReadBudget(
        original,
        cancellation,
        fallbackSize: _item(0).sizeBytes,
      );
      final results = await Future.wait([
        for (final range in [
          (0, _item(0).sizeBytes),
          (_item(0).sizeBytes - 64 * 1024, _item(0).sizeBytes),
        ])
          budget.resource.read!(range.$1, range.$2, NasCancellation())
              .drain<void>()
              .then<Object?>((_) => null, onError: (Object error) => error),
      ]);
      expect(results.any((result) => result is StateError), true);
      expect(budget.reservedBytes, NasMetadataReadBudget.maxBytes);
      expect(
        adapter.reserved,
        lessThanOrEqualTo(NasMetadataReadBudget.maxBytes),
      );
      expect(adapter.largestRange, lessThanOrEqualTo(64 * 1024));
    },
  );

  test(
    'failed attempts do not hot-loop and explicit rescan retries them',
    () async {
      final repo = await _repository();
      await repo.replaceServerItems('source', [_item(0)]);
      final proxy = NasMediaProxyService(_Ssh()), adapter = _Adapter();
      final players = <_Player>[];
      final service = NasMetadataService(
        repo,
        proxy,
        (_) async => adapter,
        playerFactory: () {
          final player = _Player()..fail = true;
          players.add(player);
          return player;
        },
      );
      addTearDown(() async {
        await service.dispose();
        await proxy.dispose();
      });
      await service.start('source');
      expect(service.state.failed, 1);
      await service.start('source');
      expect(players.length, 1);
      await repo.replaceServerItems('source', [_item(0)]);
      expect((await repo.pendingMetadata('source')).length, 1);
      await service.start('source');
      expect(players.length, 2);
    },
  );

  test(
    'disconnected source preserves the pending queue before and during a run',
    () async {
      final repo = await _repository();
      await repo.replaceServerItems('source', List.generate(67, _item));
      final proxy = NasMediaProxyService(_Ssh()), adapter = _Adapter();
      var created = 0, probes = 0;
      final service = NasMetadataService(
        repo,
        proxy,
        (_) async => adapter,
        playerFactory: () {
          created++;
          return _Player()..fail = true;
        },
      );
      addTearDown(() async {
        await service.dispose();
        await proxy.dispose();
      });
      adapter.probeAction = () async => throw StateError('Disconnected');
      await service.start('source');
      expect(created, 0);
      expect(service.state.errorCode, 'NAS_METADATA_UNAVAILABLE');
      adapter.probeAction = () async {
        if (probes++ > 0) throw StateError('Connection lost');
      };
      await service.start('source');
      expect(created, 1);
      expect(service.state.processed, 0);
      expect(service.state.failed, 0);
      expect(service.state.errorCode, 'NAS_METADATA_UNAVAILABLE');
      expect((await repo.pendingMetadata('source')).length, 32);
    },
  );

  test(
    'cancelling releases active reader and leaves unfinished metadata pending',
    () async {
      final repo = await _repository();
      await repo.replaceServerItems('source', [_item(0)]);
      final proxy = NasMediaProxyService(_Ssh()),
          player = _Player(),
          adapter = _Adapter();
      final reading = Completer<void>(), canceled = Completer<void>();
      adapter.reader = (start, end, cancellation) async* {
        final remove = cancellation.onCancel(() {
          if (!canceled.isCompleted) canceled.complete();
        });
        try {
          reading.complete();
          await cancellation.whenCancelled;
          cancellation.check();
        } finally {
          remove();
        }
      };
      final service = NasMetadataService(
        repo,
        proxy,
        (_) async => adapter,
        playerFactory: () => player,
      );
      addTearDown(() async {
        await service.dispose();
        await proxy.dispose();
      });
      final work = service.start('source');
      await reading.future;
      await service.cancel().timeout(const Duration(seconds: 2));
      await work;
      expect(canceled.isCompleted, true);
      expect(player.disposed, true);
      expect((await repo.pendingMetadata('source')).length, 1);
      expect(service.state.running, false);
    },
  );

  test(
    'media servers keep their own tags without starting a decoder',
    () async {
      final repo = await _repository();
      await repo.replaceServerItems('source', [_item(0)]);
      final proxy = NasMediaProxyService(_Ssh());
      final service = NasMetadataService(
        repo,
        proxy,
        (_) async => _Adapter(type: NasSourceType.jellyfin),
        playerFactory: () => throw StateError('Must not create player'),
      );
      addTearDown(() async {
        await service.dispose();
        await proxy.dispose();
      });
      await service.start('source');
      expect(service.state.errorCode, isNull);
      expect(service.state.processed, 0);
    },
  );

  test(
    'probe completion is fingerprint guarded and preserves favorites on rescan',
    () async {
      final repo = await _repository();
      final old = _item(0);
      await repo.replaceServerItems('source', [old]);
      await repo.setFavorite('source', old.path, true);
      await repo.completeMetadataProbe(
        old,
        metadata: old.copyWith(artist: 'Old artist', album: 'Old album'),
      );
      expect(await repo.pendingMetadata('source'), isEmpty);
      final updated = _item(0, modified: 2);
      await repo.replaceServerItems('source', [updated]);
      await repo.completeMetadataProbe(
        old,
        metadata: old.copyWith(artist: 'Stale artist'),
      );
      expect((await repo.pendingMetadata('source')).single.modifiedEpoch, 2);
      await repo.completeMetadataProbe(updated, metadata: updated);
      final stored = (await repo.query('source')).single;
      expect(stored.artist, isNull);
      expect(stored.album, isNull);
      expect(stored.isFavorite, true);
    },
  );
}
