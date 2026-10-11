import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/services/nas_image_cache_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/features/nas/widgets/nas_thumbnail_image.dart';

class _FakeNasImageCacheService extends NasImageCacheService {
  final events = <String>[];
  final thumbnailCalls = <(NasMediaItem, Object?)>[];
  final releaseCalls = <(NasMediaItem, Object)>[];

  _FakeNasImageCacheService()
    : super((_) => throw UnimplementedError(), () => 0);

  @override
  Future<String?> thumbnail(NasMediaItem item, {Object? owner}) {
    thumbnailCalls.add((item, owner));
    events.add('thumbnail:${item.modifiedEpoch}:${item.sizeBytes}');
    return Future.value(null);
  }

  @override
  void releaseThumbnail(NasMediaItem item, Object owner) {
    releaseCalls.add((item, owner));
    events.add('release:${item.modifiedEpoch}:${item.sizeBytes}');
  }
}

NasMediaItem _item({
  String serverId = 'nas-1',
  String path = '/photos/a.jpg',
  int sizeBytes = 1000,
  int modifiedEpoch = 100,
}) => NasMediaItem(
  serverId: serverId,
  path: path,
  kind: NasMediaKind.image,
  sizeBytes: sizeBytes,
  modifiedEpoch: modifiedEpoch,
);

Widget _host(ProviderContainer container, Widget body) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: body)),
    );

void main() {
  testWidgets('unrelated rebuild does not start another thumbnail fetch', (
    tester,
  ) async {
    final fake = _FakeNasImageCacheService();
    final container = ProviderContainer(
      overrides: [nasImageCacheProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final item = _item();
    var tick = 0;

    Future<void> pumpHost() => tester.pumpWidget(
      _host(
        container,
        Column(
          children: [
            Text('tick ${tick++}'),
            NasThumbnailImage(item: item),
          ],
        ),
      ),
    );

    await pumpHost();
    await tester.pump();
    expect(fake.thumbnailCalls, hasLength(1));

    await pumpHost();
    await pumpHost();
    await tester.pump();

    expect(fake.thumbnailCalls, hasLength(1));
    expect(fake.releaseCalls, isEmpty);
  });

  testWidgets(
    'changed modifiedEpoch or sizeBytes releases the old item and requests the new',
    (tester) async {
      final fake = _FakeNasImageCacheService();
      final container = ProviderContainer(
        overrides: [nasImageCacheProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      Future<void> pumpItem(NasMediaItem item) =>
          tester.pumpWidget(_host(container, NasThumbnailImage(item: item)));

      await pumpItem(_item(modifiedEpoch: 100, sizeBytes: 1000));
      final firstOwner = fake.thumbnailCalls.single.$2;

      await pumpItem(_item(modifiedEpoch: 200, sizeBytes: 1000));
      expect(fake.thumbnailCalls, hasLength(2));
      expect(fake.thumbnailCalls.last.$1.modifiedEpoch, 200);
      expect(fake.thumbnailCalls.last.$1.path, '/photos/a.jpg');
      expect(fake.releaseCalls, hasLength(1));
      expect(fake.releaseCalls.single.$1.modifiedEpoch, 100);
      expect(fake.releaseCalls.single.$1.sizeBytes, 1000);
      expect(fake.releaseCalls.single.$2, same(firstOwner));

      await pumpItem(_item(modifiedEpoch: 200, sizeBytes: 2000));
      expect(fake.thumbnailCalls, hasLength(3));
      expect(fake.thumbnailCalls.last.$1.sizeBytes, 2000);
      expect(fake.releaseCalls, hasLength(2));
      expect(fake.releaseCalls.last.$1.modifiedEpoch, 200);
      expect(fake.releaseCalls.last.$1.sizeBytes, 1000);
      expect(fake.releaseCalls.last.$2, same(fake.thumbnailCalls[1].$2));

      expect(fake.events, [
        'thumbnail:100:1000',
        'release:100:1000',
        'thumbnail:200:1000',
        'release:200:1000',
        'thumbnail:200:2000',
      ]);
    },
  );

  testWidgets(
    'removing the widget releases the captured service without a disposed-ref exception',
    (tester) async {
      final fake = _FakeNasImageCacheService();
      final container = ProviderContainer(
        overrides: [nasImageCacheProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      Future<void> pumpBody(Widget body) =>
          tester.pumpWidget(_host(container, body));

      await pumpBody(NasThumbnailImage(item: _item()));
      final owner = fake.thumbnailCalls.single.$2;
      expect(fake.releaseCalls, isEmpty);

      await pumpBody(const SizedBox.expand());
      await tester.pump();

      expect(fake.releaseCalls, hasLength(1));
      expect(fake.releaseCalls.single.$1.modifiedEpoch, 100);
      expect(fake.releaseCalls.single.$1.sizeBytes, 1000);
      expect(fake.releaseCalls.single.$2, same(owner));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing the service override releases the OLD service once and adopts the NEW',
    (tester) async {
      final oldService = _FakeNasImageCacheService();
      var current = oldService;
      final container = ProviderContainer(
        overrides: [nasImageCacheProvider.overrideWith((ref) => current)],
      );
      addTearDown(container.dispose);

      Future<void> pumpItem(NasMediaItem item) =>
          tester.pumpWidget(_host(container, NasThumbnailImage(item: item)));

      await pumpItem(_item(modifiedEpoch: 100));
      expect(oldService.thumbnailCalls, hasLength(1));

      final newService = _FakeNasImageCacheService();
      current = newService;
      container.invalidate(nasImageCacheProvider);

      await pumpItem(_item(modifiedEpoch: 200));
      await tester.pump();

      expect(oldService.thumbnailCalls, hasLength(1));
      expect(oldService.releaseCalls, hasLength(1));
      expect(oldService.releaseCalls.single.$1.modifiedEpoch, 100);
      expect(newService.thumbnailCalls, hasLength(1));
      expect(newService.thumbnailCalls.single.$1.modifiedEpoch, 200);
      expect(newService.releaseCalls, isEmpty);
    },
  );
}
