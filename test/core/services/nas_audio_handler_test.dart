import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_audio_handler.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';
import 'package:valhalla/data/models/nas_media.dart';

const first = NasMediaItem(
  serverId: 'one',
  path: '/track.mp3',
  kind: NasMediaKind.audio,
  sizeBytes: 12,
  modifiedEpoch: 0,
  title: 'First',
  artist: 'Artist',
);
const second = NasMediaItem(
  serverId: 'two',
  path: '/track.mp3',
  kind: NasMediaKind.audio,
  sizeBytes: 12,
  modifiedEpoch: 0,
  title: 'Second',
);

class TestPlayer implements NasMediaPlayerService {
  final events = StreamController<NasPlayerSnapshot>.broadcast(sync: true);
  @override
  NasPlayerSnapshot state = const NasPlayerSnapshot();
  @override
  Stream<NasPlayerSnapshot> get changes => events.stream;
  final commands = <String>[];
  void publish(NasPlayerSnapshot value) {
    state = value;
    events.add(value);
  }

  @override
  Future<void> play() async {
    commands.add('play');
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    publish(const NasPlayerSnapshot());
  }

  @override
  Future<void> next({bool completed = false}) async {
    commands.add('next');
  }

  @override
  Future<void> previous() async {
    commands.add('previous');
  }

  @override
  Future<void> jumpTo(int index) async {
    commands.add('jump:$index');
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inSeconds}');
  }

  @override
  Future<void> setRate(double value) async {
    commands.add('speed:$value');
  }

  @override
  void setRepeat(NasRepeat value) {
    commands.add('repeat:${value.name}');
  }

  @override
  void setShuffle(bool value) {
    commands.add('shuffle:$value');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a stale bind or detach cannot replace a newer player', () async {
    final oldPlayer = TestPlayer(), currentPlayer = TestPlayer();
    currentPlayer.state = const NasPlayerSnapshot(
      current: second,
      queue: [second],
      index: 0,
    );
    final handler = NasAudioHandler();
    await Future.wait([handler.bind(oldPlayer), handler.bind(currentPlayer)]);
    oldPlayer.publish(
      const NasPlayerSnapshot(current: first, queue: [first], index: 0),
    );
    expect(handler.mediaItem.value?.title, 'Second');
    await handler.detach(oldPlayer);
    expect(handler.mediaItem.value?.title, 'Second');
    await Future.wait([handler.detach(currentPlayer), handler.bind(oldPlayer)]);
    expect(handler.mediaItem.value?.title, 'First');
    await handler.detach(oldPlayer);
    await oldPlayer.events.close();
    await currentPlayer.events.close();
  });

  test(
    'system metadata, queue and playback state follow the current source item',
    () async {
      final player = TestPlayer();
      final handler = NasAudioHandler();
      await handler.bind(player);
      player.publish(
        const NasPlayerSnapshot(
          current: first,
          queue: [first, second],
          index: 0,
          playing: true,
          position: Duration(seconds: 5),
          duration: Duration(minutes: 2),
        ),
      );
      expect(handler.mediaItem.value?.title, 'First');
      expect(handler.mediaItem.value?.duration, const Duration(minutes: 2));
      expect(handler.queue.value[0].id, isNot(handler.queue.value[1].id));
      expect(handler.playbackState.value.playing, isTrue);
      final enriched = first.copyWith(
        title: 'Tagged title',
        album: 'Tagged album',
      );
      player.publish(
        NasPlayerSnapshot(
          current: enriched,
          queue: [enriched, second],
          index: 0,
          playing: true,
          position: const Duration(seconds: 5),
          duration: const Duration(minutes: 2),
        ),
      );
      expect(handler.mediaItem.value?.title, 'Tagged title');
      expect(handler.mediaItem.value?.album, 'Tagged album');
      player.publish(
        const NasPlayerSnapshot(
          current: second,
          queue: [first, second],
          index: 1,
          buffering: true,
          position: Duration.zero,
          duration: Duration(minutes: 3),
          repeat: NasRepeat.one,
        ),
      );
      expect(handler.mediaItem.value?.title, 'Second');
      expect(handler.playbackState.value.queueIndex, 1);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.buffering,
      );
      expect(
        handler.playbackState.value.repeatMode,
        AudioServiceRepeatMode.one,
      );
      await handler.detach(player);
      expect(handler.queue.value, isEmpty);
      expect(handler.mediaItem.value, isNull);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      player.publish(
        const NasPlayerSnapshot(
          current: first,
          queue: [first],
          index: 0,
          playing: true,
        ),
      );
      expect(handler.mediaItem.value, isNull);
      await player.events.close();
    },
  );

  test(
    'all system actions route exactly once to the authoritative player',
    () async {
      final player = TestPlayer();
      player.state = const NasPlayerSnapshot(
        current: first,
        queue: [first],
        index: 0,
        position: Duration(seconds: 5),
        duration: Duration(seconds: 60),
      );
      final handler = NasAudioHandler();
      await handler.bind(player);
      await handler.play();
      await handler.pause();
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.skipToQueueItem(0);
      await handler.seek(const Duration(seconds: 90));
      await handler.rewind();
      await handler.fastForward();
      await handler.setSpeed(1.5);
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.stop();
      expect(player.commands, [
        'play',
        'pause',
        'next',
        'previous',
        'jump:0',
        'seek:60',
        'seek:0',
        'seek:20',
        'speed:1.5',
        'repeat:one',
        'shuffle:true',
        'stop',
      ]);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      await handler.detach(player);
      await player.events.close();
    },
  );
}
