import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_audio_handler.dart';
import 'package:valhalla/core/services/nas_linux_media_controls.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';

import 'nas_audio_handler_test.dart' show TestPlayer, first;

void main() {
  test(
    'real D-Bus MPRIS transport forwards commands and source-safe metadata',
    () async {
      final daemon = await Process.start('dbus-daemon', [
        '--session',
        '--nofork',
        '--print-address=1',
      ]);
      addTearDown(() async {
        daemon.kill();
        await daemon.exitCode;
      });
      final address = await daemon.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      final handler = NasAudioHandler(), player = TestPlayer();
      await handler.bind(player);
      final controls = await NasLinuxMediaControls.create(
        handler,
        address: DBusAddress(address),
      );
      final client = DBusClient(DBusAddress(address));
      final remote = DBusRemoteObject(
        client,
        name: controls.busName,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );
      const interface = NasLinuxMediaControls.playerInterface;
      try {
        final tagged = first.copyWith(playlistEntryId: 'entry-2');
        final snapshot = NasPlayerSnapshot(
          current: tagged,
          queue: [tagged],
          index: 0,
          playing: true,
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 2),
          repeat: NasRepeat.all,
          shuffle: true,
          rate: 1.5,
        );
        player.publish(snapshot);
        await controls.publish(snapshot);
        final values = await remote.getAllProperties(interface);
        expect(values['PlaybackStatus']?.asString(), 'Playing');
        expect(values['CanSeek']?.asBoolean(), isTrue);
        expect(values['LoopStatus']?.asString(), 'Playlist');
        expect(values['Shuffle']?.asBoolean(), isTrue);
        expect(values['Rate']?.asDouble(), 1.5);
        final metadata = values['Metadata']!.asStringVariantDict();
        expect(metadata['xesam:title']?.asString(), 'First');
        final trackId = metadata['mpris:trackid']!.asObjectPath();
        for (final name in ['Play', 'Pause', 'Next', 'Previous']) {
          await remote.callMethod(interface, name, []);
        }
        await remote.callMethod(interface, 'Seek', [const DBusInt64(-5000000)]);
        await remote.callMethod(interface, 'SetPosition', [
          trackId,
          const DBusInt64(40000000),
        ]);
        await remote.callMethod(interface, 'SetPosition', [
          DBusObjectPath('/old_track'),
          const DBusInt64(70000000),
        ]);
        await remote.setProperty(
          interface,
          'LoopStatus',
          const DBusString('Track'),
        );
        await remote.setProperty(
          interface,
          'Shuffle',
          const DBusBoolean(false),
        );
        await remote.setProperty(interface, 'Rate', const DBusDouble(2));
        await remote.callMethod(interface, 'Stop', []);
        expect(player.commands, [
          'play',
          'pause',
          'next',
          'previous',
          'seek:25',
          'seek:40',
          'repeat:one',
          'shuffle:false',
          'speed:2.0',
          'stop',
        ]);
        await controls.publish(player.state);
        expect(
          (await remote.getProperty(interface, 'PlaybackStatus')).asString(),
          'Stopped',
        );
        expect(
          (await remote.getProperty(interface, 'CanControl')).asBoolean(),
          isFalse,
        );
      } finally {
        await client.close();
        await controls.close();
        await handler.detach(player);
        await player.events.close();
      }
    },
    skip: !Platform.isLinux,
  );
}
