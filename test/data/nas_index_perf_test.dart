import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';

/// Isolated 10,000-media index performance fixture.
///
/// The database lives in a temporary directory owned by this test and is the
/// only thing the teardown removes. Nothing here opens a socket, touches a
/// real NAS, or reads the application support directory. Timings are recorded
/// and printed; correctness is asserted, wall-clock budgets are not.
const _server = 'perf-server';
const _total = 10000;
const _pageSize = 200;
const _warmRuns = 40;
const _searchTerm = 'album00';
const _searchMatches = 500;

NasMediaItem _media(int index) {
  const kinds = [NasMediaKind.image, NasMediaKind.video, NasMediaKind.audio];
  const extensions = ['jpg', 'mkv', 'mp3'];
  return NasMediaItem(
    serverId: _server,
    path:
        '/Media/Album${(index % 200).toString().padLeft(3, '0')}'
        '/track${index.toString().padLeft(5, '0')}.${extensions[index % 3]}',
    kind: kinds[index % 3],
    sizeBytes: 1024 + index,
    modifiedEpoch: 1700000000 + (index % 7777),
    title: 'Track $index',
    artist: 'Artist ${index % 50}',
    album: 'Album ${index % 200}',
  );
}

int _percentile(List<int> sortedMicros, double p) {
  if (sortedMicros.isEmpty) return 0;
  final index = (p * (sortedMicros.length - 1)).round();
  return sortedMicros[index];
}

String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

void _expectSorted(NasMediaItem? previous, NasMediaItem current) {
  if (previous == null) return;
  final ordered =
      current.modifiedEpoch < previous.modifiedEpoch ||
      (current.modifiedEpoch == previous.modifiedEpoch &&
          current.path.compareTo(previous.path) > 0);
  expect(
    ordered,
    isTrue,
    reason:
        'keyset pages must stay ordered by (-modifiedEpoch, path): '
        '${previous.path} -> ${current.path}',
  );
}

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  test(
    '10000 media records: seed, cold and warm200-row page and search timings '
    'with RSS delta and bounded sorted navigation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'valhalla-nas-perf-',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final repository = NasIndexRepository('${directory.path}/index.sqlite3');
      await repository.initialize();

      final rssBaseline = ProcessInfo.currentRss;
      var rssPeak = rssBaseline;
      void sampleRss() {
        final rss = ProcessInfo.currentRss;
        if (rss > rssPeak) rssPeak = rss;
      }

      final seed = Stopwatch()..start();
      await repository.replaceServerItems(_server, [
        for (var index = 0; index < _total; index++) _media(index),
      ]);
      seed.stop();
      sampleRss();
      expect(await repository.count(_server), _total);
      expect((await repository.totals(_server)).total, _total);

      // Cold = the first read of the freshly seeded library.
      final coldPage = Stopwatch()..start();
      final firstPage = await repository.queryPage(_server, limit: _pageSize);
      coldPage.stop();
      sampleRss();
      expect(firstPage.items.length, _pageSize);
      expect(firstPage.hasMore, isTrue);

      final warmPage = <int>[];
      for (var run = 0; run < _warmRuns; run++) {
        final watch = Stopwatch()..start();
        final page = await repository.queryPage(_server, limit: _pageSize);
        watch.stop();
        warmPage.add(watch.elapsedMicroseconds);
        expect(page.items.length, _pageSize);
        expect(page.items.first.path, firstPage.items.first.path);
        sampleRss();
      }

      final coldSearch = Stopwatch()..start();
      final firstSearch = await repository.queryPage(
        _server,
        search: _searchTerm,
        limit: _pageSize,
      );
      coldSearch.stop();
      sampleRss();
      expect(firstSearch.items.length, _pageSize);
      expect(firstSearch.hasMore, isTrue);
      expect(
        await repository.count(_server, search: _searchTerm),
        _searchMatches,
      );

      final warmSearch = <int>[];
      for (var run = 0; run < _warmRuns; run++) {
        final watch = Stopwatch()..start();
        final page = await repository.queryPage(
          _server,
          search: _searchTerm,
          limit: _pageSize,
        );
        watch.stop();
        warmSearch.add(watch.elapsedMicroseconds);
        expect(page.items.length, _pageSize);
        expect(page.items.first.path, firstSearch.items.first.path);
        sampleRss();
      }

      // Every page stays at or below the requested size, stays ordered and
      // never repeats a row, and the walk terminates within a bounded number
      // of pages. No wall-clock budget is imposed.
      final navigate = Stopwatch()..start();
      final seen = <String>[];
      NasIndexCursor? cursor;
      NasMediaItem? previous;
      var pages = 0;
      var more = true;
      while (more && pages < 100) {
        final page = await repository.queryPage(
          _server,
          cursor: cursor,
          limit: _pageSize,
        );
        pages++;
        expect(
          page.items.length,
          lessThanOrEqualTo(_pageSize),
          reason: 'a page must never exceed the requested row count',
        );
        expect(page.items, isNotEmpty);
        for (final item in page.items) {
          _expectSorted(previous, item);
          previous = item;
        }
        seen.addAll(page.items.map((item) => item.path));
        more = page.hasMore;
        if (more) cursor = page.nextCursor;
        sampleRss();
      }
      navigate.stop();
      expect(more, isFalse, reason: 'navigation must terminate');
      expect(pages, _total ~/ _pageSize);
      expect(seen.length, _total);
      expect(seen.toSet().length, _total, reason: 'pages must not repeat rows');

      final searchPages = Stopwatch()..start();
      final searchSeen = <String>[];
      NasIndexCursor? searchCursor;
      NasMediaItem? searchPrevious;
      var searchPageCount = 0;
      var searchMore = true;
      while (searchMore && searchPageCount < 100) {
        final page = await repository.queryPage(
          _server,
          search: _searchTerm,
          cursor: searchCursor,
          limit: _pageSize,
        );
        searchPageCount++;
        expect(page.items.length, lessThanOrEqualTo(_pageSize));
        expect(page.items, isNotEmpty);
        for (final item in page.items) {
          _expectSorted(searchPrevious, item);
          searchPrevious = item;
        }
        searchSeen.addAll(page.items.map((item) => item.path));
        searchMore = page.hasMore;
        if (searchMore) searchCursor = page.nextCursor;
        sampleRss();
      }
      searchPages.stop();
      expect(searchMore, isFalse, reason: 'search navigation must terminate');
      expect(searchPageCount, (_searchMatches / _pageSize).ceil());
      expect(searchSeen.length, _searchMatches);
      expect(searchSeen.toSet().length, _searchMatches);

      final warmPageSorted = [...warmPage]..sort();
      final warmSearchSorted = [...warmSearch]..sort();
      expect(rssPeak, greaterThanOrEqualTo(rssBaseline));

      // ignore: avoid_print
      print(
        'nas_index_perf(records=$_total): '
        'seed=${seed.elapsedMilliseconds}ms '
        'coldPage200=${coldPage.elapsedMilliseconds}ms '
        'warmPage200x$_warmRuns: p50=${_percentile(warmPageSorted, 0.5)}us '
        'p95=${_percentile(warmPageSorted, 0.95)}us '
        'coldSearch200=${coldSearch.elapsedMilliseconds}ms '
        'warmSearch200x$_warmRuns: p50=${_percentile(warmSearchSorted, 0.5)}us '
        'p95=${_percentile(warmSearchSorted, 0.95)}us '
        'navigate${pages}pages=${navigate.elapsedMilliseconds}ms '
        'search${searchPageCount}pages=${searchPages.elapsedMilliseconds}ms '
        'rssBaseline=${_mib(rssBaseline)}MiB rssPeak=${_mib(rssPeak)}MiB '
        'rssDelta=${_mib(rssPeak - rssBaseline)}MiB',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
