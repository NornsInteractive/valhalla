import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/nas_preview_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/nas/nas_scan_service.dart';
import 'package:xterm/xterm.dart';

NasMediaItem item(int i) => NasMediaItem(
  serverId: 'source',
  path: '/$i.jpg',
  kind: NasMediaKind.image,
  sizeBytes: 10,
  modifiedEpoch: 1,
);

void main() {
  test(
    'page and picker path preferences persist independently, export and reset',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      ProviderContainer create() => ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      final first = create();
      expect(
        first.read(settingsProvider).filePathDisplayMode,
        RemotePathDisplayMode.scroll,
      );
      await first
          .read(settingsProvider.notifier)
          .setRemotePathDisplayMode(
            RemotePathDisplayMode.collapsed,
            picker: true,
          );
      expect(
        first.read(settingsProvider).filePathDisplayMode,
        RemotePathDisplayMode.scroll,
      );
      expect(
        storage
            .exportConfigurationPreferences()['valhalla_picker_path_display_mode_v1'],
        'collapsed',
      );
      first.dispose();
      final second = create();
      addTearDown(second.dispose);
      expect(
        second.read(settingsProvider).pickerPathDisplayMode,
        RemotePathDisplayMode.collapsed,
      );
      await second
          .read(settingsProvider.notifier)
          .setRemotePathDisplayMode(
            RemotePathDisplayMode.collapsed,
            picker: false,
          );
      await second.read(settingsProvider.notifier).resetDefaults();
      expect(storage.getRemotePathDisplayMode(picker: true), 'scroll');
      expect(storage.getRemotePathDisplayMode(picker: false), 'scroll');
    },
  );

  test(
    'preview requests prioritize visible, deduplicate and cap global prefetch at 24',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(nasPreviewRequestsProvider.notifier);
      final a = Object(), b = Object();
      notifier.update(
        a,
        visible: [item(0), item(1)],
        prefetch: List.generate(100, item),
      );
      final first = container.read(nasPreviewRequestsProvider);
      expect(first.values.where((r) => !r.visible), hasLength(24));
      expect(first[nasPreviewKey(item(0))]!.visible, isTrue);
      notifier.update(b, visible: [item(2)], prefetch: [item(99)]);
      final next = container.read(nasPreviewRequestsProvider);
      expect(next[nasPreviewKey(item(2))]!.visible, isTrue);
      expect(next.values.where((r) => !r.visible), hasLength(24));
      expect(
        identical(next[nasPreviewKey(item(0))], first[nasPreviewKey(item(0))]),
        isTrue,
      );
      notifier.release(a);
      expect(container.read(nasPreviewRequestsProvider).length, 2);
      notifier.release(b);
      expect(container.read(nasPreviewRequestsProvider), isEmpty);
    },
  );

  test(
    'Ctrl Enter remains distinguishable from plain Enter and supports combined modifiers',
    () {
      final output = <String>[];
      final terminal = Terminal()..onOutput = output.add;
      sendTerminalAccessoryKey(terminal, 'ENTER');
      expect(output.removeLast(), '\r');
      sendTerminalAccessoryKey(terminal, 'ENTER', isCtrl: true);
      expect(output.removeLast(), '\x1b[13;5u');
      terminal.keyInput(TerminalKey.enter, ctrl: true);
      expect(output.removeLast(), '\x1b[13;5u');
      sendTerminalAccessoryKey(terminal, 'ENTER', isCtrl: true, isShift: true);
      expect(output.removeLast(), '\x1b[13;6u');
      sendTerminalAccessoryKey(terminal, 'c', isCtrl: true);
      expect(output.removeLast(), '\x03');
      sendTerminalAccessoryKey(terminal, 'TAB', isShift: true);
      expect(output.removeLast(), '\x1b[Z');
    },
  );

  test(
    'ten thousand Unicode index records remain bounded by batch size',
    () async {
      final bytes = utf8.encode(
        List.generate(10000, (i) => '/照片/$i.jpg\u000010\u0000123\u0000').join(),
      );
      var count = 0, batches = 0;
      final stream = Stream<List<int>>.fromIterable([
        for (var i = 0; i < bytes.length; i += 257)
          bytes.sublist(i, (i + 257).clamp(0, bytes.length)),
      ]);
      await for (final batch in NasScanService.decodeRecords(
        'source',
        stream,
        NasCancellation(),
      )) {
        expect(batch.length, lessThanOrEqualTo(256));
        expect(batch.every((item) => item.path.startsWith('/照片/')), isTrue);
        count += batch.length;
        batches++;
      }
      expect(count, 10000);
      expect(batches, 40);
    },
  );
}
