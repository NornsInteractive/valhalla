// Run: dart run tool/nas_index_benchmark.dart [row-count]
// Temporary synthetic library; never opens application data.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/repositories/nas_index_repository.dart';

Future<void> main(List<String> arguments) async {
  final rows = arguments.isEmpty ? 1000000 : int.parse(arguments.single);
  if (rows < 1000) throw ArgumentError('Use at least 1000 rows');
  final directory = await Directory.systemTemp.createTemp(
    'valhalla-nas-bench-',
  );
  final repository = NasIndexRepository('${directory.path}/index.sqlite3');
  var peakRss = ProcessInfo.currentRss;
  final seedTime = Stopwatch()..start();
  try {
    await repository.initialize();
    final generation = await repository.beginScan('benchmark');
    for (var start = 0; start < rows; start += 5000) {
      final items = List.generate(min(5000, rows - start), (offset) {
        final index = start + offset;
        return NasMediaItem(
          serverId: 'benchmark',
          path:
              '/media/folder${index ~/ 1000}/song${index.toString().padLeft(8, '0')}.mp3',
          kind: NasMediaKind.audio,
          sizeBytes: 8000000,
          modifiedEpoch: index,
          title: 'Song $index',
          artist: 'Artist ${index % 300}',
          album: 'Album ${index ~/ 20}',
          isFavorite: index % 10 == 0,
        );
      });
      await repository.upsertBatch('benchmark', items, generation);
      peakRss = max(peakRss, ProcessInfo.currentRss);
      if ((start + items.length) % 100000 == 0) {
        stderr.writeln('Seeded ${start + items.length} / $rows');
      }
    }
    await repository.finishScan('benchmark', generation);
    seedTime.stop();
    final deepIndex = rows ~/ 20;
    final deepCursor = NasIndexCursor(
      deepIndex,
      '/media/folder${deepIndex ~/ 1000}/song${deepIndex.toString().padLeft(8, '0')}.mp3',
    );
    final measurements = <String, Object>{};
    for (final entry in <String, Future<Object> Function()>{
      'first_page': () => repository.queryPage('benchmark'),
      'deep_page_95_percent': () =>
          repository.queryPage('benchmark', cursor: deepCursor),
      'search_rare_prefix': () =>
          repository.queryPage('benchmark', search: 'song000000'),
      'search_common_prefix': () =>
          repository.queryPage('benchmark', search: 'Song'),
      'totals': () => repository.totals('benchmark'),
    }.entries) {
      final times = <double>[];
      for (var run = 0; run < 20; run++) {
        final watch = Stopwatch()..start();
        await entry.value();
        times.add(watch.elapsedMicroseconds / 1000);
        peakRss = max(peakRss, ProcessInfo.currentRss);
      }
      times.sort();
      measurements[entry.key] = {
        'p50_ms': times[9],
        'p95_ms': times[18],
        'max_ms': times.last,
      };
    }
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'rows': rows,
        'dart': Platform.version,
        'os': Platform.operatingSystem,
        'processors': Platform.numberOfProcessors,
        'batch_rows': 5000,
        'seed_seconds': seedTime.elapsedMilliseconds / 1000,
        'database_bytes': await File(repository.databasePath).length(),
        'sampled_peak_process_rss_bytes': peakRss,
        'queries': measurements,
      }),
    );
  } finally {
    await directory.delete(recursive: true);
  }
}
