import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_image_cache_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';

/// Ownership and deduplication edges of the thumbnail scheduler that the
/// existing scheduler suite does not reach: repeated requests from the same
/// owner, a read after an owner released a pending tile, and releasing one
/// owner while another still waits. Everything is observed through the
/// adapter call list, the returned futures and on-disk cache files: no
/// timers, no dart:ui decoding, no NAS, no server.
class _StubAdapter extends NasSourceAdapter {
  @override
  NasSource get source =>
      const NasSource(id: 'nas-1', name: 'nas-1', type: NasSourceType.smb);

  final calls = <String>[];
  final entered = Completer<void>();
  Completer<void>? gate;

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
  }) => throw StateError('not used: thumbnails always resolve to null');

  @override
  Future<NasResource?> thumbnail(NasMediaItem item) async {
    calls.add(item.path);
    if (!entered.isCompleted) entered.complete();
    final wait = gate;
    if (wait == null) return null;
    await wait.future;
    return null;
  }
}

NasMediaItem _item(
  String path, {
  String serverId = 'nas-1',
  NasMediaKind kind = NasMediaKind.video,
  int sizeBytes = 100,
  int modifiedEpoch = 1700000000,
}) => NasMediaItem(
  serverId: serverId,
  path: path,
  kind: kind,
  sizeBytes: sizeBytes,
  modifiedEpoch: modifiedEpoch,
);

/// Same construction as [NasImageCacheService]: sha256 over the four key
/// parts joined by NUL, spelled with `String.fromCharCode` so this source file
/// stays free of literal control characters.
String _cacheKey(NasMediaItem item) {
  final separator = String.fromCharCode(0);
  return sha256
      .convert(
        utf8.encode(
          '${item.serverId}$separator${item.path}$separator'
          '${item.modifiedEpoch}$separator${item.sizeBytes}',
        ),
      )
      .toString();
}

void main() {
  late Directory supportDir;
  late _StubAdapter adapter;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    supportDir = await Directory.systemTemp.createTemp(
      'nas-thumb-ownership-test',
    );
    adapter = _StubAdapter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => switch (call.method) {
            'getApplicationSupportDirectory' => supportDir.path,
            'getTemporaryDirectory' => supportDir.path,
            'getApplicationDocumentsDirectory' => supportDir.path,
            'getApplicationCacheDirectory' => supportDir.path,
            'getLibraryDirectory' => supportDir.path,
            _ => null,
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (supportDir.existsSync()) await supportDir.delete(recursive: true);
  });

  NasImageCacheService service() =>
      NasImageCacheService((_) async => adapter, () => 8 * 1024 * 1024);

  test(
    'the same owner requesting a queued tile twice shares a single fetch',
    () async {
      final cache = service();
      adapter.gate = Completer<void>();
      final blocker = _item('/media/blocker.mkv');
      final queued = _item('/media/queued.mkv');

      // The blocker occupies the pump, so the next tile stays queued.
      cache.thumbnail(blocker, owner: 'grid-1');
      await adapter.entered.future;
      expect(adapter.calls, ['/media/blocker.mkv']);

      final first = cache.thumbnail(queued, owner: 'grid-1');
      final second = cache.thumbnail(queued, owner: 'grid-1');
      expect(
        identical(first, second),
        isTrue,
        reason: 'repeated same-owner reads must share one result',
      );

      adapter.gate!.complete();
      await Future.wait([first, second]);
      await pumpEventQueue();

      expect(
        adapter.calls,
        ['/media/blocker.mkv', '/media/queued.mkv'],
        reason: 'two reads of one queued tile must fetch it exactly once',
      );
      expect(await first, isNull);
      expect(await second, isNull);
      expect(
        adapter.calls.where((path) => path == '/media/queued.mkv'),
        hasLength(1),
      );
    },
  );

  test(
    'releasing one owner keeps the shared fetch alive for the remaining owner',
    () async {
      final cache = service();
      adapter.gate = Completer<void>();
      final item = _item('/media/shared.mkv');

      final first = cache.thumbnail(item, owner: 'grid-1');
      cache.thumbnail(item, owner: 'grid-2');
      await adapter.entered.future;
      expect(adapter.calls, ['/media/shared.mkv']);

      var settled = false;
      first.then((_) => settled = true);
      cache.releaseThumbnail(item, 'grid-1');
      await pumpEventQueue();
      expect(
        settled,
        isFalse,
        reason: 'an owner is still waiting, so the fetch must survive',
      );

      cache.releaseThumbnail(item, 'grid-2');
      expect(await first, isNull, reason: 'the last release settles it');
      await pumpEventQueue();
      expect(settled, isTrue);

      adapter.gate!.complete();
      await pumpEventQueue();
      expect(adapter.calls, [
        '/media/shared.mkv',
      ], reason: 'released work must not run a second time');
    },
  );

  test(
    'a warm tile reads without the adapter after an owner released a pending tile',
    () async {
      final cache = service();
      adapter.gate = Completer<void>();
      final pending = _item('/media/pending.mkv');
      final warm = _item('/media/warm.mkv', kind: NasMediaKind.image);
      final root = Directory('${supportDir.path}/nas-thumbnails-v2');
      await root.create(recursive: true);
      final target = File('${root.path}/${_cacheKey(warm)}.png');
      await target.writeAsBytes([1, 2, 3]);

      final blocked = cache.thumbnail(pending, owner: 'grid-1');
      await pumpEventQueue();
      expect(adapter.calls, ['/media/pending.mkv']);

      cache.releaseThumbnail(pending, 'grid-1');
      expect(await blocked, isNull, reason: 'the release cancels the work');

      adapter.gate!.complete();
      await pumpEventQueue();
      expect(adapter.calls, [
        '/media/pending.mkv',
      ], reason: 'released work must not run a second time');

      expect(
        await cache.thumbnail(warm, owner: 'grid-1'),
        target.path,
        reason: 'the warm tile still resolves straight from the cache',
      );
      expect(
        adapter.calls,
        ['/media/pending.mkv'],
        reason: 'a warm read after a release must never reach the adapter',
      );
    },
  );
}
