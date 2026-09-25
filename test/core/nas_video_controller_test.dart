import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_media_player_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.alexmercerind/media_kit_video');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Android emulator uses the native codec surface without EGL', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'Utils.IsEmulator');
      return Future.value(true);
    });
    final configuration = await nasVideoConfiguration();
    expect(configuration.vo, 'mediacodec_embed');
    expect(configuration.hwdec, 'mediacodec');
  });

  test(
    'physical Android retains the default GPU and codec selection',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      final configuration = await nasVideoConfiguration();
      expect(configuration.vo, isNull);
      expect(configuration.hwdec, isNull);
    },
  );

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('$platform never invokes the Android detector', () async {
      debugDefaultTargetPlatformOverride = platform;
      var calls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        calls++;
        return true;
      });
      final configuration = await nasVideoConfiguration();
      expect(configuration.vo, isNull);
      expect(configuration.hwdec, isNull);
      expect(calls, 0);
    });
  }

  for (final unavailable in [true, false]) {
    test(
      'detector ${unavailable ? 'missing' : 'failure'} keeps defaults',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          _,
        ) async {
          if (unavailable) throw MissingPluginException();
          throw PlatformException(code: 'unavailable');
        });
        final configuration = await nasVideoConfiguration();
        expect(configuration.vo, isNull);
        expect(configuration.hwdec, isNull);
      },
    );
  }
}
