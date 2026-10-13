import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';

const _item = NasMediaItem(
  serverId: 'source',
  path: '/song.mp3',
  kind: NasMediaKind.audio,
  sizeBytes: 4,
  modifiedEpoch: 1,
);

class _Notifier extends NasNotifier {
  _Notifier(this.initial);
  final NasState initial;
  @override
  NasState build() => initial;
}

class _Sources extends NasSourcesNotifier {
  _Sources(this.initial);
  final NasSourcesState initial;
  @override
  NasSourcesState build() => initial;
  void removeSource() => state = const NasSourcesState();
}

class _Repository implements NasIndexRepository {
  int pages = 0;
  @override
  Future<NasIndexPage> queryPage(
    String serverId, {
    NasMediaKind? kind,
    String search = '',
    bool favoritesOnly = false,
    String? folder,
    String? artist,
    String? album,
    String? albumKey,
    int? modifiedFromEpoch,
    int? modifiedBeforeEpoch,
    NasIndexCursor? cursor,
    bool before = false,
    bool inclusive = false,
    NasSortKey sortKey = NasSortKey.modified,
    bool sortAscending = false,
    int limit = 200,
  }) async {
    pages++;
    return const NasIndexPage([_item], null, false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player implements NasMediaPlayerService {
  NasMediaItem? opened;
  Future<List<NasMediaItem>> Function()? nextPage;
  @override
  Future<void> open(
    NasMediaItem item, {
    List<NasMediaItem>? queue,
    Future<List<NasMediaItem>> Function()? loadMore,
    Future<List<NasMediaItem>> Function()? restartQueue,
    NasPlaybackQuality? quality,
    void Function()? disposeQueue,
  }) async {
    opened = item;
    nextPage = loadMore;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final remotePlaylist in [false, true]) {
    test(
      remotePlaylist
          ? 'remote playlist connects lazily and refuses changed source'
          : 'real notifier opens offline and pages local index without an adapter',
      () async {
        final sources = _Sources(
          NasSourcesState(
            sources: [
              NasSource(
                id: 'source',
                name: 'NAS',
                endpoint: 'https://nas.invalid',
                type: remotePlaylist
                    ? NasSourceType.jellyfin
                    : NasSourceType.webdav,
              ),
            ],
          ),
        );
        final player = _Player();
        final repository = _Repository();
        var adapterCalls = 0;
        final container = ProviderContainer(
          overrides: [
            nasProvider.overrideWith(
              () => _Notifier(
                NasState(
                  serverId: 'source',
                  items: const [_item],
                  hasMore: true,
                  playlistId: remotePlaylist ? 'playlist' : null,
                ),
              ),
            ),
            nasSourcesProvider.overrideWith(() => sources),
            nasIndexRepositoryProvider.overrideWith((ref) async => repository),
            nasMediaPlayerProvider.overrideWith((ref) async => player),
            nasSourceAdapterProvider.overrideWith((ref, id) async {
              adapterCalls++;
              throw StateError('Remote connection forbidden');
            }),
          ],
        );
        addTearDown(container.dispose);
        await container.read(nasProvider.notifier).openInApp(_item);
        expect(player.opened, same(_item));
        expect(adapterCalls, 0);
        if (remotePlaylist) {
          sources.removeSource();
          await expectLater(player.nextPage!(), throwsA(isA<NasCancelled>()));
          expect(repository.pages, 0);
        } else {
          expect(await player.nextPage!(), [_item]);
          expect(repository.pages, 1);
        }
        expect(adapterCalls, 0);
      },
    );
  }
}
