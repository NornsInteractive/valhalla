import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_dialog.dart';
import 'package:valhalla/widgets/remote_browser_view.dart';

const _confirmKey = Key('remote_browser_confirm_button');
const _file = RemoteBrowserEntry(
  id: '/notes.txt',
  name: 'notes.txt',
  isDirectory: false,
);
const _folder = RemoteBrowserEntry(
  id: '/documents',
  name: 'documents',
  isDirectory: true,
);
const _movies = RemoteBrowserEntry(
  id: 'library-movies',
  name: 'Movies',
  isDirectory: true,
  canEnter: false,
);
const _music = RemoteBrowserEntry(
  id: 'library-music',
  name: 'Music',
  isDirectory: true,
  canEnter: false,
);
const _photo = RemoteBrowserEntry(
  id: '/photo.png',
  name: 'photo.png',
  isDirectory: false,
  mimeType: 'image/png',
);

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

RemoteBrowserSource _source({
  String key = 'test-source',
  bool flat = false,
  Stream<List<RemoteBrowserEntry>> Function(String)? list,
  Future<Uint8List?> Function(RemoteBrowserEntry, int)? preview,
}) {
  final source = RemoteBrowserSource(
    targetKey: key,
    label: key,
    rootPath: '/',
    initialPath: '/',
    flat: flat,
    isCurrent: () => true,
    list: (path, cancelled) => list?.call(path) ?? Stream.value(const []),
    preview: preview,
  );
  addTearDown(source.dispose);
  return source;
}

Future<void> _frames(WidgetTester tester) async {
  // StreamSubscription.cancel may use Dart's shared completed future, whose
  // completion is scheduled outside Flutter's fake-async zone.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

class _DialogResult {
  RemoteBrowserSelection? selection;
  bool completed = false;
}

Future<_DialogResult> _open(
  WidgetTester tester,
  RemoteBrowserSource source, {
  RemoteBrowserMode mode = RemoteBrowserMode.directory,
  Set<String> selected = const {},
  Set<String> allowedExtensions = const {},
  bool Function(RemoteBrowserEntry)? canSelectEntry,
  double scale = 1,
}) async {
  final result = _DialogResult();
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.selection = await RemoteBrowserDialog.show(
                context,
                source: source,
                mode: mode,
                initialSelectedIds: selected,
                allowedExtensions: allowedExtensions,
                canSelectEntry: canSelectEntry,
              );
              result.completed = true;
            },
            child: const Text('Open browser'),
          ),
        ),
      ),
      scale: scale,
    ),
  );
  await tester.tap(find.text('Open browser'));
  await _frames(tester);
  return result;
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_confirmKey));

/// A public source implementation whose subscription cleanup can stall. This
/// exercises the view's await boundary, without reaching into widget state.
class _DelayedCancelSource extends RemoteBrowserSource {
  final cancelGate = Completer<void>();
  final paths = <String>[];
  late final StreamController<List<RemoteBrowserEntry>> root;

  _DelayedCancelSource()
    : super(
        targetKey: 'delayed-source',
        label: 'delayed-source',
        rootPath: '/',
        initialPath: '/',
        isCurrent: () => true,
        list: (_, cancelled) => const Stream.empty(),
      ) {
    root = StreamController<List<RemoteBrowserEntry>>(
      onCancel: () => cancelGate.future,
    );
    addTearDown(() async {
      if (!cancelGate.isCompleted) cancelGate.complete();
      unawaited(root.close());
      await dispose();
    });
  }

  @override
  Stream<List<RemoteBrowserEntry>> list(String path) {
    paths.add(path);
    return path == '/' ? root.stream : Stream.value(const []);
  }
}

void main() {
  _presentationTests();
  testWidgets('a loaded empty directory can be confirmed', (tester) async {
    final source = _source();
    final result = await _open(tester, source);

    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(_confirmKey));
    await _frames(tester);

    expect(result.completed, isTrue);
    expect(result.selection?.targetKey, source.targetKey);
    expect(result.selection?.entries.single.id, '/');
    expect(result.selection?.entries.single.isDirectory, isTrue);
  });

  testWidgets('directory confirmation never returns a regular file', (
    tester,
  ) async {
    final source = _source(list: (_) => Stream.value([_file]));
    final result = await _open(tester, source);

    expect(find.text(_file.name), findsNothing);
    expect(find.byKey(const Key('remote_browser_file_format')), findsNothing);
    if (_confirm(tester).onPressed != null) {
      await tester.tap(find.byKey(_confirmKey));
      await _frames(tester);
    }

    expect(
      result.selection?.entries.any((entry) => !entry.isDirectory) ?? false,
      isFalse,
      reason: 'pickDirectory must not return /notes.txt as an install root',
    );
  });

  testWidgets('directory confirmation is disabled until listing completes', (
    tester,
  ) async {
    final controller = StreamController<List<RemoteBrowserEntry>>();
    addTearDown(() => unawaited(controller.close()));
    final source = _source(list: (_) => controller.stream);
    await _open(tester, source);

    expect(_confirm(tester).onPressed, isNull);
    controller.add(const []);
    await tester.pump();
    expect(_confirm(tester).onPressed, isNull);
    await controller.close();
    await _frames(tester);
    expect(_confirm(tester).onPressed, isNotNull);
  });

  for (final failListing in [false, true]) {
    testWidgets(
      'file selection is disabled during ${failListing ? 'partial listing failure' : 'loading'}',
      (tester) async {
        final controller = StreamController<List<RemoteBrowserEntry>>();
        addTearDown(() => unawaited(controller.close()));
        await _open(
          tester,
          _source(list: (_) => controller.stream),
          mode: RemoteBrowserMode.file,
        );
        controller.add(const [_file]);
        await _frames(tester);
        await tester.tap(find.text(_file.name));
        await _frames(tester);
        if (failListing) {
          controller.addError(
            SftpStatusError(SftpStatusCode.permissionDenied, 'Partial list'),
          );
          await _frames(tester);
        }
        expect(_confirm(tester).onPressed, isNull);
        if (!failListing) {
          await controller.close();
          await _frames(tester);
          expect(_confirm(tester).onPressed, isNotNull);
        }
      },
    );
  }

  testWidgets('permission failure cannot confirm the unverified directory', (
    tester,
  ) async {
    final paths = <String>[];
    final source = _source(
      list: (path) {
        paths.add(path);
        return Stream.error(
          SftpStatusError(SftpStatusCode.permissionDenied, 'Denied'),
        );
      },
    );
    await _open(tester, source);

    expect(paths, ['/']);
    expect(_confirm(tester).onPressed, isNull);
  });

  testWidgets(
    'double tapping a file confirms that file, not the previous selection',
    (tester) async {
      const second = RemoteBrowserEntry(
        id: '/second.txt',
        name: 'second.txt',
        isDirectory: false,
      );
      final result = await _open(
        tester,
        _source(list: (_) => Stream.value([_file, second])),
        mode: RemoteBrowserMode.file,
      );
      await tester.tap(find.text(_file.name));
      await _frames(tester);
      await tester.tap(find.text(second.name));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text(second.name));
      await _frames(tester);
      expect(result.selection?.entries.single.id, second.id);
    },
  );

  testWidgets(
    'file picker enters directories on a single tap without double-tap delay',
    (tester) async {
      final paths = <String>[];
      await _open(
        tester,
        _source(
          list: (path) {
            paths.add(path);
            return Stream.value(path == '/' ? [_folder] : [_file]);
          },
        ),
        mode: RemoteBrowserMode.file,
      );
      await tester.tap(find.text(_folder.name));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(paths, ['/', _folder.id]);
    },
  );

  testWidgets('library preselection spans batches and reaches dialog payload', (
    tester,
  ) async {
    final controller = StreamController<List<RemoteBrowserEntry>>();
    addTearDown(() => unawaited(controller.close()));
    final source = _source(flat: true, list: (_) => controller.stream);
    final result = await _open(
      tester,
      source,
      mode: RemoteBrowserMode.multipleLibraries,
      selected: {_movies.id, _music.id},
    );

    controller.add([_movies]);
    await _frames(tester);
    controller.add([_music]);
    await controller.close();
    await _frames(tester);

    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(_confirmKey));
    await _frames(tester);
    expect(
      result.selection?.entries.map((entry) => entry.id),
      unorderedEquals([_movies.id, _music.id]),
    );
  });

  testWidgets('user deselected libraries stay deselected after public reload', (
    tester,
  ) async {
    final key = GlobalKey<RemoteBrowserViewState>();
    final snapshots = <List<String>>[];
    var listCalls = 0;
    final controllers = <StreamController<List<RemoteBrowserEntry>>>[];
    addTearDown(() {
      for (final controller in controllers) {
        unawaited(controller.close());
      }
    });
    final source = _source(
      flat: true,
      list: (_) {
        listCalls++;
        late final StreamController<List<RemoteBrowserEntry>> controller;
        controller = StreamController<List<RemoteBrowserEntry>>(
          onListen: () => controller.add([_movies, _music]),
        );
        controllers.add(controller);
        return controller.stream;
      },
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          appBar: AppBar(
            actions: [
              TextButton(
                onPressed: () => key.currentState?.reload(),
                child: const Text('Reload browser'),
              ),
            ],
          ),
          body: RemoteBrowserView(
            key: key,
            source: source,
            mode: RemoteBrowserMode.multipleLibraries,
            initialSelectedIds: {_movies.id, _music.id},
            onSelectionChanged: (entries) =>
                snapshots.add(entries.map((entry) => entry.id).toList()),
          ),
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(find.text(_movies.name));
    await tester.tap(find.text(_music.name));
    await _frames(tester);
    expect(snapshots.last, isEmpty);
    await tester.tap(find.text('Reload browser'));
    await _frames(tester);
    expect(listCalls, 2);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(snapshots.last, isEmpty);
  });

  testWidgets('source replacement clears the dialog selection snapshot', (
    tester,
  ) async {
    final sourceA = _source(
      key: 'source-A',
      list: (_) => Stream.value([_file]),
    );
    final sourceB = _source(key: 'source-B');
    final selectedSource = ValueNotifier(sourceA);
    addTearDown(selectedSource.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<RemoteBrowserSource>(
          valueListenable: selectedSource,
          builder: (_, source, child) =>
              RemoteBrowserDialog(source: source, mode: RemoteBrowserMode.file),
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(find.text(_file.name));
    await _frames(tester);
    expect(_confirm(tester).onPressed, isNotNull);

    selectedSource.value = sourceB;
    await _frames(tester);

    expect(find.text('source-B'), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull);
  });

  testWidgets('late thumbnail from an old source cannot enter the new source', (
    tester,
  ) async {
    final oldPreview = Completer<Uint8List?>();
    final newPreview = Completer<Uint8List?>();
    var oldRequests = 0;
    var newRequests = 0;
    final sourceA = _source(
      key: 'photos-A',
      list: (_) => Stream.value([_photo]),
      preview: (_, maxBytes) {
        oldRequests++;
        return oldPreview.future;
      },
    );
    final sourceB = _source(
      key: 'photos-B',
      list: (_) => Stream.value([_photo]),
      preview: (_, maxBytes) {
        newRequests++;
        return newPreview.future;
      },
    );
    final selectedSource = ValueNotifier(sourceA);
    addTearDown(selectedSource.dispose);
    addTearDown(() {
      if (!oldPreview.isCompleted) oldPreview.complete(null);
      if (!newPreview.isCompleted) newPreview.complete(null);
    });
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ValueListenableBuilder<RemoteBrowserSource>(
            valueListenable: selectedSource,
            builder: (_, source, child) =>
                RemoteBrowserView(source: source, mode: RemoteBrowserMode.file),
          ),
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(find.byIcon(Icons.image));
    await _frames(tester);
    expect(oldRequests, 1);

    selectedSource.value = sourceB;
    await _frames(tester);
    // A valid 1x1 PNG belongs exclusively to source A. B has not returned bytes.
    oldPreview.complete(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jP1sAAAAASUVORK5CYII=',
      ),
    );
    await _frames(tester);

    expect(
      find.byType(Image),
      findsNothing,
      reason: 'A late /photo.png preview must never render inside photos-B',
    );
    expect(
      newRequests,
      1,
      reason: 'B must make its own request for the same ID',
    );
  });

  testWidgets('closing during directory cancellation does not setState later', (
    tester,
  ) async {
    final source = _DelayedCancelSource();
    final result = await _open(tester, source);
    source.root.add([_folder]);
    await _frames(tester);
    await tester.tap(find.text(_folder.name));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await _frames(tester);
    expect(result.completed, isTrue);

    source.cancelGate.complete();
    await _frames(tester);

    expect(tester.takeException(), isNull);
    expect(source.paths, ['/'], reason: 'disposed navigation must not start');
  });

  testWidgets('source swap during navigation does not reuse the old path', (
    tester,
  ) async {
    final sourceA = _DelayedCancelSource();
    final newPaths = <String>[];
    final sourceB = _source(
      key: 'source-B',
      list: (path) {
        newPaths.add(path);
        return Stream.value(const []);
      },
    );
    final selectedSource = ValueNotifier<RemoteBrowserSource>(sourceA);
    addTearDown(selectedSource.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ValueListenableBuilder<RemoteBrowserSource>(
            valueListenable: selectedSource,
            builder: (_, source, child) => RemoteBrowserView(source: source),
          ),
        ),
      ),
    );
    await _frames(tester);
    sourceA.root.add([_folder]);
    await _frames(tester);
    await tester.tap(find.text(_folder.name));
    await tester.pump();
    selectedSource.value = sourceB;
    await tester.pump();

    sourceA.cancelGate.complete();
    await _frames(tester);

    expect(newPaths, ['/']);
    expect(tester.takeException(), isNull);
  });
}

void _presentationTests() {
  for (final keyboard in [false, true]) {
    testWidgets(
      'popup confirmation remains reachable with ${keyboard ? 'keyboard' : 'doubled text'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        if (keyboard) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await _open(tester, _source(), scale: keyboard ? 1 : 2);
        await tester.ensureVisible(find.byKey(_confirmKey));
        await _frames(tester);
        await tester.tap(find.byKey(_confirmKey));
        await _frames(tester);
        expect(find.byType(RemoteBrowserDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [
    const Size(360, 760),
    const Size(320, 640),
    const Size(760, 360),
  ]) {
    testWidgets('picker stays a bounded popup at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, _source(list: (_) => Stream.value([_file, _folder])));
      final rect = tester.getRect(
        find.byKey(const Key('remote_browser_dialog_surface')),
      );
      expect(rect.width, lessThan(size.width));
      expect(rect.height, lessThan(size.height));
      expect(rect.left, greaterThanOrEqualTo(12));
      expect(find.text(_file.name), findsNothing);
      await tester.ensureVisible(find.byKey(_confirmKey));
      await tester.tap(find.byKey(_confirmKey));
      await _frames(tester);
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'file format filter keeps folders and clears a hidden selection',
    (tester) async {
      await _open(
        tester,
        _source(list: (_) => Stream.value([_file, _photo, _folder])),
        mode: RemoteBrowserMode.multipleFiles,
      );
      await tester.tap(find.text(_file.name));
      await _frames(tester);
      expect(_confirm(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('remote_browser_file_format')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Images'),
      );
      await _frames(tester);
      expect(find.text(_file.name), findsNothing);
      expect(find.text(_photo.name), findsOneWidget);
      expect(find.text(_folder.name), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);
      await tester.tap(find.text(_photo.name));
      await _frames(tester);
      expect(_confirm(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('remote_browser_file_format')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, '.txt'),
      );
      await _frames(tester);
      expect(find.text(_file.name), findsOneWidget);
      expect(find.text(_photo.name), findsNothing);
      expect(_confirm(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'caller extensions and capability restrictions cannot be bypassed by filters',
    (tester) async {
      const denied = RemoteBrowserEntry(
        id: '/denied.png',
        name: 'denied.png',
        isDirectory: false,
      );
      await _open(
        tester,
        _source(list: (_) => Stream.value([_file, _photo, denied, _folder])),
        mode: RemoteBrowserMode.file,
        allowedExtensions: {'*.PNG'},
        canSelectEntry: (entry) => entry.id != denied.id,
      );
      expect(find.text(_file.name), findsNothing);
      expect(find.text(denied.name), findsNothing);
      expect(find.text(_photo.name), findsOneWidget);
      expect(find.text(_folder.name), findsOneWidget);
      await tester.tap(find.text(_photo.name));
      await _frames(tester);
      expect(_confirm(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing a picker does not restore the underlying keyboard', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            pageContext = context;
            return Scaffold(body: TextField(focusNode: focus));
          },
        ),
      ),
    );
    focus.requestFocus();
    await _frames(tester);
    expect(focus.hasFocus, isTrue);
    unawaited(RemoteBrowserDialog.show(pageContext, source: _source()));
    await _frames(tester);
    expect(focus.hasFocus, isFalse);
    await tester.tap(find.byIcon(Icons.close));
    await _frames(tester);
    expect(focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('mobile browser offers three views and a separate search row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _source(list: (_) => Stream.value(const [_file, _folder]));
    await _open(tester, source);
    expect(
      tester.getRect(find.byKey(const Key('remote_browser_search'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('remote_browser_hidden'))).top,
      ),
    );
    await tester.tap(find.byIcon(Icons.grid_view));
    await _frames(tester);
    final cards = tester.widget<GridView>(find.byType(GridView));
    expect(
      (cards.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    await tester.tap(find.byIcon(Icons.image));
    await _frames(tester);
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list));
    await _frames(tester);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact grid paints icon and title on the same row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _source(list: (_) => Stream.value(const [_file, _folder]));
    await _open(tester, source, mode: RemoteBrowserMode.file);
    await tester.tap(find.byIcon(Icons.grid_view));
    await _frames(tester);
    final title = find.text('notes.txt');
    final icon = find.byIcon(Icons.insert_drive_file);
    expect(title, findsWidgets);
    expect(icon, findsWidgets);
    expect(
      tester.getTopLeft(title.first).dy,
      closeTo(tester.getTopLeft(icon.first).dy, 6),
      reason: 'icon and title must share a row in the compact grid',
    );
    expect(
      tester.getTopLeft(title.first).dx,
      greaterThan(tester.getTopLeft(icon.first).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact grid does not download unseen image previews', (
    tester,
  ) async {
    var previews = 0;
    final source = _source(
      list: (_) => Stream.value(const [_photo, _folder]),
      preview: (_, _) async {
        previews++;
        return null;
      },
    );
    await _open(tester, source, mode: RemoteBrowserMode.file);
    await tester.tap(find.byIcon(Icons.grid_view));
    await _frames(tester);
    expect(previews, 0);
    await tester.tap(find.byIcon(Icons.image));
    await _frames(tester);
    expect(previews, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact grid keeps two columns at 320-430dp and one at 2x text',
    (tester) async {
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = _source(
          list: (_) => Stream.value(const [_file, _folder]),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _open(tester, source, mode: RemoteBrowserMode.file);
        await tester.tap(find.byIcon(Icons.grid_view));
        await _frames(tester);
        final cards = tester.widget<GridView>(find.byType(GridView));
        expect(
          (cards.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          2,
        );
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rtlSource = _source(
        list: (_) => Stream.value(const [_file, _folder]),
      );
      // Drop the previous Navigator's still-open dialog before the RTL host.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          Directionality(
            textDirection: TextDirection.rtl,
            child: RemoteBrowserDialog(
              source: rtlSource,
              mode: RemoteBrowserMode.file,
            ),
          ),
          scale: 2,
        ),
      );
      await _frames(tester);
      await tester.tap(find.byIcon(Icons.grid_view));
      await _frames(tester);
      final rtlTitle = find.text('notes.txt');
      final rtlIcon = find.byIcon(Icons.insert_drive_file);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        1,
      );
      final titleBounds = tester.getRect(rtlTitle.first);
      final iconBounds = tester.getRect(rtlIcon.first);
      expect(titleBounds.top, lessThan(iconBounds.bottom));
      expect(titleBounds.bottom, greaterThan(iconBounds.top));
      expect(
        tester.getTopLeft(rtlTitle.first).dx,
        lessThan(tester.getTopLeft(rtlIcon.first).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text uses one vertical card without footer overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _source(list: (_) => Stream.value(const [_file, _folder]));
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: RemoteBrowserDialog(source: source),
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(find.byIcon(Icons.grid_view));
    await _frames(tester);
    final cards = tester.widget<GridView>(find.byType(GridView));
    expect(
      (cards.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden rows dim labels but preserve selection and action visibility',
    (tester) async {
      const hidden = RemoteBrowserEntry(
        id: '/.env',
        name: '.env',
        isDirectory: false,
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: RemoteBrowserEntryTile(
              entry: hidden,
              selected: true,
              viewMode: RemoteBrowserViewMode.list,
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('.env'));
      final context = tester.element(find.text('.env'));
      expect(
        label.style?.color,
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.more_vert),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shared display preserves item anchor and per-directory position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final mode = ValueNotifier(RemoteBrowserViewMode.list);
      final location = ValueNotifier('/a');
      addTearDown(mode.dispose);
      addTearDown(location.dispose);
      final entries = List.generate(
        100,
        (i) => RemoteBrowserEntry(
          id: '/file-$i',
          name: 'file-$i',
          isDirectory: false,
        ),
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ValueListenableBuilder(
              valueListenable: location,
              builder: (context, path, child) => ValueListenableBuilder(
                valueListenable: mode,
                builder: (context, view, child) => RemoteBrowserEntriesView(
                  entries: entries,
                  viewMode: view,
                  locationKey: path,
                  controller: controller,
                  itemBuilder: (context, entry) =>
                      RemoteBrowserEntryTile(entry: entry, viewMode: view),
                ),
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(1000);
      await tester.pump();
      mode.value = RemoteBrowserViewMode.grid;
      await _frames(tester);
      expect(tester.getRect(find.text('file-14')).bottom, greaterThan(0));
      expect(tester.getRect(find.text('file-14')).top, lessThan(844));
      final saved = controller.offset;
      location.value = '/b';
      await _frames(tester);
      expect(controller.offset, 0);
      controller.jumpTo(300);
      await tester.pump();
      location.value = '/a';
      await _frames(tester);
      expect(controller.offset, closeTo(saved, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
