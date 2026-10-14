import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_view.dart';

Widget _app(RemoteBrowserSource source) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: RemoteBrowserView(
      source: source,
      mode: RemoteBrowserMode.multipleFiles,
    ),
  ),
);

Future<void> _host(WidgetTester tester, RemoteBrowserSource source) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(source));
  await tester.pumpAndSettle();
  // Only gallery renders thumbnails; the compact grid intentionally does not.
  await tester.tap(find.byIcon(Icons.image));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'navigation releases old preview permits and starts the new directory',
    (tester) async {
      final pending = <Completer<Uint8List?>>[];
      final paths = <String>[];
      final source = RemoteBrowserSource(
        targetKey: 'folders',
        label: 'Folders',
        rootPath: '/',
        initialPath: '/',
        isCurrent: () => true,
        list: (path, cancelled) => Stream.value([
          if (path == '/')
            const RemoteBrowserEntry(
              id: '/next',
              name: 'next',
              isDirectory: true,
            ),
          for (var i = 0; i < 8; i++)
            RemoteBrowserEntry(
              id: '${path == '/' ? '' : path}/$i.png',
              name: '$i.png',
              isDirectory: false,
              mimeType: 'image/png',
            ),
        ]),
        preview: (entry, maxBytes) {
          paths.add(entry.id);
          final done = Completer<Uint8List?>();
          pending.add(done);
          return done.future;
        },
      );
      addTearDown(source.dispose);
      await _host(tester, source);
      expect(pending.length, 2);
      await tester.tap(find.text('next'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      for (final task in pending.take(2).toList()) {
        task.complete(null);
      }
      await tester.pump();
      await tester.pump();
      expect(
        paths.any((path) => path.startsWith('/next/')),
        isTrue,
        reason:
            'Discarded old results must not permanently consume the preview permits',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (final task in pending) {
        if (!task.isCompleted) task.complete(null);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old-source preview failures cannot release new-source permits', (
    tester,
  ) async {
    final firstPending = <Completer<Uint8List?>>[];
    final secondPending = <Completer<Uint8List?>>[];
    var secondActive = 0;
    var secondPeak = 0;
    RemoteBrowserSource source(String id, List<Completer<Uint8List?>> tasks) {
      final result = RemoteBrowserSource(
        targetKey: id,
        label: id,
        rootPath: '/',
        initialPath: '/',
        isCurrent: () => true,
        list: (_, cancelled) => Stream.value(
          List.generate(
            20,
            (i) => RemoteBrowserEntry(
              id: '/$i.png',
              name: '$i.png',
              isDirectory: false,
              mimeType: 'image/png',
            ),
          ),
        ),
        preview: (_, maxBytes) async {
          final pending = Completer<Uint8List?>();
          tasks.add(pending);
          if (id == 'second') {
            secondActive++;
            if (secondActive > secondPeak) secondPeak = secondActive;
          }
          try {
            return await pending.future;
          } finally {
            if (id == 'second') secondActive--;
          }
        },
      );
      addTearDown(result.dispose);
      return result;
    }

    await _host(tester, source('first', firstPending));
    expect(firstPending.length, 2);
    await tester.pumpWidget(_app(source('second', secondPending)));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(secondPending.length, lessThanOrEqualTo(2));
    firstPending.first.completeError(StateError('Old source disconnected'));
    await tester.pump();
    expect(secondPeak, lessThanOrEqualTo(2));
    firstPending.last.complete(null);
    await tester.pump();
    expect(
      secondPending,
      isNotEmpty,
      reason: 'The new source must make progress',
    );
    expect(secondPeak, lessThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox.shrink());
    for (final pending in [...firstPending, ...secondPending]) {
      if (!pending.isCompleted) pending.complete(null);
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten thousand photos stay lazy and start at most two previews', (
    tester,
  ) async {
    final pending = <Completer<Uint8List?>>[];
    var active = 0;
    var peak = 0;
    final source = RemoteBrowserSource(
      targetKey: 'large-library',
      label: 'Photos',
      rootPath: '/',
      initialPath: '/',
      isCurrent: () => true,
      list: (_, cancelled) => Stream.value(
        List.generate(
          10000,
          (i) => RemoteBrowserEntry(
            id: '/image-${i.toString().padLeft(5, '0')}.png',
            name: 'image-${i.toString().padLeft(5, '0')}.png',
            isDirectory: false,
            mimeType: 'image/png',
          ),
        ),
      ),
      preview: (entry, maxBytes) async {
        expect(maxBytes, lessThanOrEqualTo(2 * 1024 * 1024));
        final done = Completer<Uint8List?>();
        pending.add(done);
        active++;
        if (active > peak) peak = active;
        try {
          return await done.future;
        } finally {
          active--;
        }
      },
    );
    addTearDown(source.dispose);
    await _host(tester, source);
    expect(pending, isNotEmpty);
    expect(peak, lessThanOrEqualTo(2));
    expect(find.text('image-09999.png'), findsNothing);
    expect(find.byType(InkWell).evaluate().length, lessThan(100));
    final started = pending.length;
    await tester.pumpWidget(const SizedBox.shrink());
    for (final task in pending) {
      task.complete(null);
    }
    await tester.pump();
    expect(
      pending.length,
      started,
      reason: 'Closing must not drain queued previews',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('thumbnail decoding is bounded, not full original resolution', (
    tester,
  ) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6ds8AAAAASUVORK5CYII=',
    );
    final source = RemoteBrowserSource(
      targetKey: 'photo',
      label: 'Photos',
      rootPath: '/',
      initialPath: '/',
      isCurrent: () => true,
      list: (_, cancelled) => Stream.value(const [
        RemoteBrowserEntry(
          id: '/photo.png',
          name: 'photo.png',
          isDirectory: false,
          mimeType: 'image/png',
        ),
      ]),
      preview: (_, maxBytes) async => png,
    );
    addTearDown(source.dispose);
    await _host(tester, source);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<ResizeImage>());
    final resize = image.image as ResizeImage;
    expect(resize.width ?? resize.height, isNotNull);
    expect(resize.width ?? resize.height!, lessThanOrEqualTo(512));
    expect(tester.takeException(), isNull);
  });
}
