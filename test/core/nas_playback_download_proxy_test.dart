import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';
import 'package:valhalla/infrastructure/nas/nas_media_proxy_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Ssh implements SshCommandExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Streams implements PlayerStream {
  _Streams({this.log = const Stream.empty()});
  @override
  final Stream<PlayerLog> log;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  Stream<double> get rate => const Stream.empty();
  @override
  Stream<String> get error => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements Player {
  _Player({PlayerStream? stream}) : stream = stream ?? _Streams();
  @override
  PlatformPlayer? platform;
  @override
  PlayerState state = const PlayerState(duration: Duration(minutes: 10));
  @override
  final PlayerStream stream;
  final opened = <String>[];
  final starts = <Duration?>[];
  final headers = <Map<String, String>?>[];
  Future<void> Function(Duration)? onSeek;
  Future<void> Function()? onOpen;
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final media = playable as Media;
    starts.add(media.start);
    await onOpen?.call();
    opened.add(media.uri);
    headers.add(media.httpHeaders);
    state = state.copyWith(
      position: media.start ?? Duration.zero,
      playing: play,
    );
  }

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    await onSeek?.call(position);
    state = state.copyWith(position: position);
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Adapter extends NasSourceAdapter {
  @override
  final NasSource source;
  _Adapter([NasSource? source])
    : source =
          source ??
          const NasSource(
            id: 'source-a',
            name: 'A',
            type: NasSourceType.webdav,
          );
  Future<NasResource> Function(NasMediaItem)? onResolve;
  Future<void> Function(NasMediaItem, String)? onReport;
  final resolved = <String>[];
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
  }) async {
    resolved.add(item.path);
    return onResolve != null
        ? onResolve!(item)
        : NasResource(uri: Uri.parse('http://media.invalid/${item.path}'));
  }

  @override
  Future<void> reportPlayback(
    NasMediaItem item,
    Duration position, {
    required String event,
    bool paused = false,
    String? playSessionId,
  }) async {
    await onReport?.call(item, event);
  }
}

class _Repository extends NasIndexRepository {
  _Repository(super.databasePath);
  Future<void> Function()? onSave;
  @override
  Future<NasPlaybackState?> playbackFor(String serverId, String remotePath) =>
      NasIndexRepository(databasePath).playbackFor(serverId, remotePath);
  @override
  Future<void> savePlayback(NasPlaybackState state) async {
    await onSave?.call();
    await super.savePlayback(state);
  }
}

class _Metadata implements NativePlayer {
  @override
  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async =>
      const {
        'metadata/list/count': '4',
        'metadata/list/0/key': 'artist',
        'metadata/list/0/value': 'Known Artist',
        'metadata/list/1/key': 'ALBUM',
        'metadata/list/1/value': 'Known Album',
        'metadata/list/2/key': 'title',
        'metadata/list/2/value': 'Tagged Song',
        'metadata/list/3/key': 'TRACK',
        'metadata/list/3/value': '7/12',
      }[property] ??
      '';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NasMediaItem _item(String name, {int size = 10}) => NasMediaItem(
  serverId: 'source-a',
  path: name,
  kind: NasMediaKind.audio,
  sizeBytes: size,
  modifiedEpoch: 1,
);

void main() {
  test(
    'native video output failure becomes an explicit playback error',
    () async {
      final logs = StreamController<PlayerLog>.broadcast(sync: true);
      final proxy = NasMediaProxyService(_Ssh());
      final service = NasMediaPlayerService(
        proxy,
        NasIndexRepository(':memory:'),
        player: _Player(stream: _Streams(log: logs.stream)),
      );
      logs.add(
        const PlayerLog(prefix: 'vo/gpu', level: 'warn', text: 'warning'),
      );
      expect(service.state.error, isNull);
      logs.add(
        const PlayerLog(
          prefix: 'cplayer',
          level: 'fatal',
          text: 'Error opening/initializing the selected video_out device.',
        ),
      );
      expect(service.state.error, 'NAS_PLAYBACK_FAILED');
      await service.dispose();
      await proxy.dispose();
      await logs.close();
    },
  );

  test(
    'resume is supplied at load using item or saved duration, never old player duration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-load-resume',
      );
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      for (final entry in [('long.mp3', 700), ('ended.mp3', 599)]) {
        await repository.savePlayback(
          NasPlaybackState(
            serverId: 'source-a',
            path: entry.$1,
            position: Duration(seconds: entry.$2),
            duration: const Duration(minutes: 20),
            updatedAt: DateTime.now(),
          ),
        );
      }
      final native = _Player(),
          proxy = NasMediaProxyService(_Ssh()),
          adapter = _Adapter();
      native.state = const PlayerState(duration: Duration(seconds: 1));
      native.onSeek = (_) async =>
          fail('Resume must use Media.start before load');
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      try {
        await service.open(_item('long.mp3'));
        expect(native.state.position, const Duration(seconds: 700));
        service.applyFavorite('source-a', 'long.mp3', true);
        expect(service.current!.isFavorite, true);
        service.applyFavorite('other-source', 'long.mp3', false);
        expect(service.current!.isFavorite, true);
        service.applyFavorite('source-a', 'long.mp3', false);
        expect(service.current!.isFavorite, false);
        expect(native.opened, hasLength(1));
        expect(native.state.position, const Duration(seconds: 700));
        await service.open(_item('ended.mp3').copyWith(durationMillis: 600000));
        expect(native.state.position, Duration.zero);
        expect(native.starts, [const Duration(seconds: 700), Duration.zero]);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'pagewise shuffle visits duplicate entries and repeat restarts the logical queue',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-shuffle-pages',
      );
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final native = _Player(),
          proxy = NasMediaProxyService(_Ssh()),
          adapter = _Adapter();
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      final firstPage = [
        _item('same.mp3').copyWith(playlistEntryId: 'entry-1'),
        _item('same.mp3').copyWith(playlistEntryId: 'entry-2'),
      ];
      final secondPage = [
        _item('third.mp3').copyWith(playlistEntryId: 'entry-3'),
        _item('fourth.mp3').copyWith(playlistEntryId: 'entry-4'),
      ];
      var page = 0, restarted = 0, closed = 0;
      try {
        await service.open(
          firstPage.last,
          queue: firstPage,
          loadMore: () async => page++ == 0 ? secondPage : [],
          restartQueue: () async {
            restarted++;
            page = 0;
            return firstPage;
          },
          disposeQueue: () => closed++,
        );
        expect(service.state.index, 1);
        service.setShuffle(true);
        service.setRepeat(NasRepeat.all);
        final visited = <String>{service.current!.playlistEntryId!};
        for (var i = 0; i < 3; i++) {
          await service.next();
          expect(visited.add(service.current!.playlistEntryId!), isTrue);
        }
        expect(visited, {'entry-1', 'entry-2', 'entry-3', 'entry-4'});
        await service.next();
        expect(restarted, 1);
        expect(service.current!.playlistEntryId, isIn(['entry-1', 'entry-2']));
        expect(closed, 0);
        final repeated = <String>{service.current!.playlistEntryId!};
        for (var i = 0; i < 3; i++) {
          await service.next();
          expect(repeated.add(service.current!.playlistEntryId!), isTrue);
        }
        expect(repeated, visited);
        await service.stop();
        expect(closed, 1);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'near-end resume resets; quality and jump preserve queue ownership',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-quality-race',
      );
      final repository = _Repository('${directory.path}/index.sqlite');
      await repository.initialize();
      await repository.savePlayback(
        NasPlaybackState(
          serverId: 'source-a',
          path: 'first.mp3',
          position: const Duration(seconds: 599),
          duration: const Duration(minutes: 10),
          updatedAt: DateTime.now(),
        ),
      );
      final native = _Player(),
          proxy = NasMediaProxyService(_Ssh()),
          adapter = _Adapter();
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      var closed = 0;
      try {
        final queue = [_item('first.mp3'), _item('second.mp3')];
        await service.open(
          queue.first,
          queue: queue,
          disposeQueue: () => closed++,
        );
        expect(native.state.position, Duration.zero);
        await service.seek(const Duration(seconds: 42));
        await service.setQuality(NasPlaybackQuality.mbps4);
        expect(service.state.quality, NasPlaybackQuality.mbps4);
        expect(native.state.position, const Duration(seconds: 42));
        await service.jumpTo(1);
        expect(service.current?.path, 'second.mp3');
        expect(closed, 0);

        final entered = Completer<void>(), release = Completer<void>();
        var saves = 0;
        repository.onSave = () async {
          if (++saves == 1) {
            entered.complete();
            await release.future;
          }
        };
        final quality = service.setQuality(NasPlaybackQuality.mbps10);
        await entered.future;
        final replacement = service.open(_item('replacement.mp3'));
        release.complete();
        await Future.wait([quality, replacement]);
        expect(service.current?.path, 'replacement.mp3');
        expect(service.state.quality, NasPlaybackQuality.mbps4);
        expect(native.opened, hasLength(4));
        expect(closed, 1);
        await service.stop();
        expect(closed, 1);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('stop during a delayed save cannot resurrect the queued item', () async {
    final directory = await Directory.systemTemp.createTemp('nas-save-race');
    final repository = _Repository('${directory.path}/index.sqlite');
    await repository.initialize();
    final native = _Player(),
        proxy = NasMediaProxyService(_Ssh()),
        adapter = _Adapter();
    final service = NasMediaPlayerService(
      proxy,
      repository,
      player: native,
      adapterFor: (_) async => adapter,
    );
    try {
      await service.open(_item('first.mp3'));
      final entered = Completer<void>(), release = Completer<void>();
      var calls = 0;
      repository.onSave = () async {
        if (++calls == 1) {
          entered.complete();
          await release.future;
        }
      };
      final opening = service.open(_item('second.mp3'));
      await entered.future;
      await service.stop();
      release.complete();
      await opening;
      expect(service.current, isNull);
      expect(native.opened, hasLength(1));
      expect(native.state.playing, isFalse);
    } finally {
      await service.dispose();
      await proxy.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('stop during delayed native open wins over resumed playback', () async {
    final directory = await Directory.systemTemp.createTemp('nas-open-race');
    final repository = NasIndexRepository('${directory.path}/index.sqlite');
    await repository.initialize();
    await repository.savePlayback(
      NasPlaybackState(
        serverId: 'source-a',
        path: 'resume.mp3',
        position: const Duration(seconds: 20),
        updatedAt: DateTime.now(),
      ),
    );
    final native = _Player(),
        proxy = NasMediaProxyService(_Ssh()),
        adapter = _Adapter();
    final entered = Completer<void>(), release = Completer<void>();
    native.onOpen = () async {
      entered.complete();
      await release.future;
    };
    final service = NasMediaPlayerService(
      proxy,
      repository,
      player: native,
      adapterFor: (_) async => adapter,
    );
    try {
      final opening = service.open(_item('resume.mp3'));
      await entered.future;
      expect(native.starts, [const Duration(seconds: 20)]);
      final stopping = service.stop();
      release.complete();
      await Future.wait([opening, stopping]);
      expect(service.current, isNull);
      expect(native.state.playing, isFalse);
    } finally {
      await service.dispose();
      await proxy.dispose();
      await directory.delete(recursive: true);
    }
  });

  test(
    'next coalesces and discards a stale page after queue replacement',
    () async {
      final directory = await Directory.systemTemp.createTemp('nas-queue-race');
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final native = _Player(),
          proxy = NasMediaProxyService(_Ssh()),
          adapter = _Adapter();
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      final page = Completer<List<NasMediaItem>>();
      var fetched = 0, closed = 0;
      try {
        await service.open(
          _item('first.mp3'),
          loadMore: () {
            fetched++;
            return page.future;
          },
          disposeQueue: () {
            closed++;
          },
        );
        final next = service.next(), duplicate = service.next();
        expect(identical(next, duplicate), isTrue);
        expect(fetched, 1);
        await service.open(_item('replacement.mp3'));
        page.complete([_item('stale.mp3')]);
        await Future.wait([next, duplicate]);
        expect(service.current?.path, 'replacement.mp3');
        expect(service.state.queue.map((item) => item.path), [
          'replacement.mp3',
        ]);
        expect(closed, 1);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'server sync retains source identity and failure does not block playback',
    () async {
      final directory = await Directory.systemTemp.createTemp('nas-sync-race');
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final native = _Player(), proxy = NasMediaProxyService(_Ssh());
      final first = _Adapter(
        const NasSource(
          id: 'source-a',
          name: 'A',
          type: NasSourceType.jellyfin,
        ),
      );
      final second = _Adapter(
        const NasSource(id: 'source-b', name: 'B', type: NasSourceType.emby),
      );
      final blocked = Completer<void>(), entered = Completer<void>();
      final reported = <String>[];
      first.onReport = (item, event) async {
        reported.add('A:${item.serverId}:$event');
        if (event == 'progress') {
          entered.complete();
          await blocked.future;
          throw StateError('offline');
        }
      };
      second.onReport = (item, event) async {
        reported.add('B:${item.serverId}:$event');
      };
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (id) async => id == 'source-a' ? first : second,
      );
      try {
        await service.open(_item('first.mp3'));
        await service.seek(const Duration(seconds: 12));
        await entered.future;
        const other = NasMediaItem(
          serverId: 'source-b',
          path: 'other.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: 10,
          modifiedEpoch: 0,
        );
        await service.open(other).timeout(const Duration(seconds: 2));
        expect(service.current, other);
        expect(native.state.playing, isTrue);
        final error = service.changes.firstWhere(
          (state) => state.error == 'NAS_PLAYBACK_SYNC_FAILED',
        );
        blocked.complete();
        await error;
        expect(
          reported.where(
            (event) =>
                event.startsWith('A:source-b') ||
                event.startsWith('B:source-a'),
          ),
          isEmpty,
        );
        expect(service.current, other);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'authenticated and HLS media use relay; metadata comes from libmpv',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-metadata-relay',
      );
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final native = _Player()..platform = _Metadata();
      final proxy = NasMediaProxyService(_Ssh()), adapter = _Adapter();
      final item = _item('tagged.mp3');
      await repository.replaceServerItems('source-a', [item]);
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      try {
        adapter.onResolve = (_) async => NasResource(
          uri: Uri.parse('https://media.invalid/music.mp3'),
          headers: {'Authorization': 'Bearer secret'},
        );
        final tagged = service.changes.firstWhere(
          (state) => state.current?.artist == 'Known Artist',
        );
        await service.open(item);
        await tagged;
        expect(Uri.parse(native.opened.last).host, '127.0.0.1');
        expect(native.headers.last, isEmpty);
        expect(service.current?.album, 'Known Album');
        expect(service.current?.trackNumber, 7);
        expect(
          (await repository.query('source-a')).single.title,
          'Tagged Song',
        );
        adapter.onResolve = (_) async => NasResource(
          uri: Uri.parse('https://media.invalid/master.m3u8'),
          mimeType: 'application/vnd.apple.mpegurl',
          headers: {'Authorization': 'Bearer secret'},
        );
        await service.open(item);
        expect(Uri.parse(native.opened.last).pathSegments.first, 'hls');
        expect(native.headers.last, isEmpty);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'selected queue item resolves lazily and progress follows current item',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'nas-player-test',
      );
      final repository = NasIndexRepository('${directory.path}/index.sqlite');
      await repository.initialize();
      final proxy = NasMediaProxyService(_Ssh()),
          native = _Player(),
          adapter = _Adapter();
      final service = NasMediaPlayerService(
        proxy,
        repository,
        player: native,
        adapterFor: (_) async => adapter,
      );
      try {
        final queue = [_item('one.mp3'), _item('two.mp3'), _item('three.mp3')];
        await service.open(queue[1], queue: queue);
        expect(adapter.resolved, ['two.mp3']);
        expect(native.opened.single, endsWith('/two.mp3'));
        await service.seek(const Duration(seconds: 17));
        await service.next();
        expect(service.current?.path, 'three.mp3');
        expect(adapter.resolved, ['two.mp3', 'three.mp3']);
        expect(
          (await repository.playbackFor('source-a', 'two.mp3'))?.position,
          const Duration(seconds: 17),
        );
        await service.stop();
        expect(service.state.current, isNull);
        expect(service.state.queue, isEmpty);
      } finally {
        await service.dispose();
        await proxy.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('stop invalidates an unresolved open', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nas-player-cancel',
    );
    final repository = NasIndexRepository('${directory.path}/index.sqlite');
    await repository.initialize();
    final pending = Completer<NasResource>(), entered = Completer<void>();
    final adapter = _Adapter()
      ..onResolve = (_) {
        entered.complete();
        return pending.future;
      };
    final native = _Player(), proxy = NasMediaProxyService(_Ssh());
    final service = NasMediaPlayerService(
      proxy,
      repository,
      player: native,
      adapterFor: (_) async => adapter,
    );
    try {
      final opening = service.open(_item('pending.mp3'));
      await entered.future;
      await service.stop();
      pending.complete(
        NasResource(uri: Uri.parse('http://media.invalid/pending')),
      );
      await opening;
      expect(native.opened, isEmpty);
      expect(service.current, isNull);
    } finally {
      await service.dispose();
      await proxy.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('Range suffix, empty HEAD, revocation and stream bounds', () async {
    final proxy = NasMediaProxyService(_Ssh()), client = HttpClient();
    final reads = <(int, int?)>[];
    try {
      final uri = await proxy.exposeResource(
        _item('bytes.mp3'),
        NasResource(
          sizeBytes: 10,
          read: (start, end, cancel) async* {
            reads.add((start, end));
            yield List.generate((end ?? 10) - start, (i) => start + i);
          },
        ),
      );
      final request = await client.getUrl(uri);
      request.headers.set('Range', 'bytes=-4');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(response.headers.value('content-range'), 'bytes 6-9/10');
      expect(await response.expand((bytes) => bytes).toList(), [6, 7, 8, 9]);
      expect(reads, [(6, 10)]);
      final empty = await proxy.exposeResource(
        _item('empty.mp3', size: 0),
        NasResource(
          sizeBytes: 0,
          read: (_, _, _) => throw StateError('empty HEAD must not read'),
        ),
      );
      final head = await (await client.headUrl(empty)).close();
      expect(head.contentLength, 0);
      expect(head.statusCode, 200);
      await head.drain<void>();
      proxy.revoke(uri);
      final revoked = await (await client.getUrl(uri)).close();
      expect(revoked.statusCode, 404);
      await revoked.drain<void>();
      expect(NasMediaProxyService.parseRange('bytes=-0', 10), isNull);
      expect(NasMediaProxyService.parseRange('bytes=10-', 10), isNull);
      expect(NasMediaProxyService.parseRange('bytes=0-0', 0), isNull);
      expect(NasMediaProxyService.parseRange('bytes=1-99', 10), (1, 9));
    } finally {
      client.close(force: true);
      await proxy.dispose();
    }
  });

  test(
    'download failure removes partial; retry atomically completes captured source',
    () async {
      final directory = await Directory.systemTemp.createTemp('nas-download');
      var attempts = 0;
      final adapter = _Adapter()
        ..onResolve = (_) async {
          attempts++;
          return NasResource(
            sizeBytes: 10,
            read: (_, _, cancellation) async* {
              yield [0, 1, 2, 3, 4];
              if (attempts == 1) throw const SocketException('disconnected');
              yield [5, 6, 7, 8, 9];
            },
          );
        };
      final ids = <String>[];
      final service = NasDownloadService(
        (id) async {
          ids.add(id);
          return adapter;
        },
        platform: DownloadPlatformService(
          directoryProvider: () async => directory,
        ),
      );
      try {
        final failed = service.changes.firstWhere(
          (tasks) => tasks.any((e) => e.status == NasDownloadStatus.failed),
        );
        final id = service.download(_item('original.mp3'));
        await failed;
        expect(
          await directory
              .list()
              .where((file) => file.path.endsWith('.part'))
              .length,
          0,
        );
        final completed = service.changes.firstWhere(
          (tasks) => tasks.any((e) => e.status == NasDownloadStatus.completed),
        );
        service.retry(id);
        final task = (await completed).single;
        expect(ids, ['source-a', 'source-a']);
        expect(
          await File(task.localPath!).readAsBytes(),
          List.generate(10, (i) => i),
        );
      } finally {
        await service.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
