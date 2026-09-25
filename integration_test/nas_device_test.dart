// Run only on a dedicated, disposable test emulator with no user app data.
// Flutter's integration runner can uninstall this application's package during
// cleanup, including its stored sources and credentials. Never run this test on
// a device that contains user data. For a normal install, build the app target
// and use `adb install -r`; do not use the integration runner as an installer.
// Replay instructions: docs/02-architecture/04-nas-streaming-architecture.md.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:valhalla/core/providers/nas_metadata_provider.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/main.dart' as app;

/// Requires tool/nas_e2e_fixture.py on the Docker host. No user server is changed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real device streams, seeks, resumes, decodes, downloads and keeps source identity',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.ValhallaApp)),
      );
      const source = NasSource(
        id: 'nas-device-validation',
        name: 'NAS device validation',
        type: NasSourceType.webdav,
        username: 'nas',
        endpoint: String.fromEnvironment(
          'NAS_FIXTURE_URL',
          defaultValue: 'http://192.168.1.145:18086',
        ),
      );
      final sources = container.read(nasSourcesProvider.notifier);
      await sources.save(
        source,
        const NasCredentials(password: 'nas-fixture-only'),
      );
      await tester.pump();
      final library = container.read(nasProvider.notifier);
      await library.scan();
      final state = container.read(nasProvider);
      expect(state.errorCode, isNull);
      expect(state.totals.images, greaterThanOrEqualTo(1));
      expect(state.totals.videos, greaterThanOrEqualTo(1));
      expect(state.totals.audio, greaterThanOrEqualTo(1));
      final photo = state.items.firstWhere(
        (item) => item.kind == NasMediaKind.image,
      );
      final video = state.items.firstWhere(
        (item) => item.kind == NasMediaKind.video,
      );
      final audio = state.items.firstWhere(
        (item) => item.kind == NasMediaKind.audio,
      );
      final thumbnail = await library.thumbnailPath(photo);
      expect(thumbnail, isNotNull);
      expect(await File(thumbnail!).length(), greaterThan(0));
      final thumbnailCodec = await ui.instantiateImageCodec(
        await File(thumbnail).readAsBytes(),
      );
      final thumbnailFrame = await thumbnailCodec.getNextFrame();
      expect(thumbnailFrame.image.width, lessThanOrEqualTo(512));
      expect(thumbnailFrame.image.height, lessThanOrEqualTo(512));
      thumbnailFrame.image.dispose();
      thumbnailCodec.dispose();
      final imageUri = await library.imageUrl(photo);
      final client = HttpClient();
      final imageResponse = await (await client.getUrl(imageUri)).close();
      expect(imageResponse.statusCode, 200);
      expect(
        await imageResponse.fold<int>(0, (size, chunk) => size + chunk.length),
        photo.sizeBytes,
      );
      client.close(force: true);
      library.releaseImageUrl(imageUri);

      final player = await container.read(nasMediaPlayerProvider.future);
      await library.openInApp(video);
      await player.player.stream.position
          .firstWhere((position) => position.inMilliseconds > 800)
          .timeout(const Duration(seconds: 25));
      expect(player.state.playing, true);
      await player.seek(const Duration(seconds: 10));
      await player.setRate(1.5);
      await player.pause();
      expect(player.player.state.position.inSeconds, greaterThanOrEqualTo(9));
      await player.stop();
      await library.openInApp(video);
      if (player.player.state.position.inMilliseconds < 200) {
        await player.player.stream.position
            .firstWhere((position) => position.inMilliseconds >= 200)
            .timeout(const Duration(seconds: 15));
      }
      expect(player.player.state.position.inSeconds, greaterThanOrEqualTo(9));
      await player.stop();
      await library.openInApp(audio);
      await player.player.stream.position
          .firstWhere((position) => position.inMilliseconds > 800)
          .timeout(const Duration(seconds: 25));
      final repository = await container.read(
        nasIndexRepositoryProvider.future,
      );
      final metadata = await container.read(nasMetadataServiceProvider.future);
      await metadata.start(source.id);
      final enriched = (await repository.query(
        source.id,
        kind: NasMediaKind.audio,
      )).first;
      expect(enriched.artist, 'Valhalla');
      expect(enriched.album, 'Fixture');
      await library.setFavorite(audio, true);
      expect((await repository.totals(source.id)).favorites, 1);
      await library.createPlaylist('Device validation');
      final playlist = container
          .read(nasProvider)
          .playlists
          .firstWhere((p) => p.name == 'Device validation');
      await library.addToPlaylist(playlistId: playlist.id, item: audio);
      expect(
        (await repository.playlistMediaPage(
          source.id,
          playlist.id,
        )).items.single.path,
        audio.path,
      );
      await library.renamePlaylist(playlist.id, 'Device validation renamed');
      await library.removeFromPlaylist(playlist.id, audio);
      await library.deletePlaylist(playlist.id);

      const other = NasSource(
        id: 'nas-device-validation-other',
        name: 'Second source',
        type: NasSourceType.webdav,
        username: 'nas',
        endpoint: String.fromEnvironment(
          'NAS_FIXTURE_URL',
          defaultValue: 'http://192.168.1.145:18086',
        ),
      );
      await sources.save(
        other,
        const NasCredentials(password: 'nas-fixture-only'),
      );
      expect(player.current?.serverId, source.id);
      expect(player.state.playing, true);
      final downloads = container.read(nasDownloadServiceProvider);
      final finished = downloads.changes.firstWhere(
        (tasks) => tasks.any(
          (task) =>
              task.item.path == video.path &&
              {
                NasDownloadStatus.completed,
                NasDownloadStatus.failed,
              }.contains(task.status),
        ),
      );
      final id = downloads.download(video);
      final task = (await finished.timeout(
        const Duration(seconds: 30),
      )).firstWhere((task) => task.id == id);
      expect(task.status, NasDownloadStatus.completed);
      expect(await File(task.localPath!).length(), video.sizeBytes);
      await player.stop();
      await sources.remove(other.id);
      await sources.select(source.id);
      // Leave the isolated validation source available for manual UI checks.
      debugPrint(
        'NAS_DEVICE_PASS: photo thumbnail/original, video stream/seek/resume/rate, music tags, favorites/playlists, download, source isolation',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
