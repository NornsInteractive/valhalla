import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import '../services/app_diagnostics.dart';

/// Bounded scan measurements; no media paths or connection details are recorded.
class NasScanPerformance {
  final _frames = <FrameTiming>[];
  final _elapsed = Stopwatch()..start();
  final int _rssBefore = ProcessInfo.currentRss;
  SchedulerBinding? _binding;

  NasScanPerformance() {
    try {
      _binding = SchedulerBinding.instance;
      _binding!.addTimingsCallback(_collect);
    } catch (_) {
      // Pure repository/provider tests can run without a rendering binding.
    }
  }

  void _collect(List<FrameTiming> frames) {
    _frames.addAll(frames);
    if (_frames.length > 1024) _frames.removeRange(0, _frames.length - 1024);
  }

  Future<void> finish({required int count, required bool cancelled}) async {
    _binding?.removeTimingsCallback(_collect);
    _elapsed.stop();
    double p95(Duration Function(FrameTiming) value) {
      if (_frames.isEmpty) return 0;
      final samples = _frames.map((f) => value(f).inMicroseconds).toList()
        ..sort();
      return samples[((samples.length * .95).ceil() - 1).clamp(
            0,
            samples.length - 1,
          )] /
          1000;
    }

    final summary =
        'count=$count durationMs=${_elapsed.elapsedMilliseconds} cancelled=$cancelled samples=${_frames.length} '
        'buildP95Ms=${p95((f) => f.buildDuration).toStringAsFixed(2)} rasterP95Ms=${p95((f) => f.rasterDuration).toStringAsFixed(2)} '
        'totalP95Ms=${p95((f) => f.totalSpan).toStringAsFixed(2)} rssBefore=$_rssBefore rssAfter=${ProcessInfo.currentRss}';
    debugPrint('VALHALLA_NAS_SCAN_PERFORMANCE $summary');
    await AppDiagnostics.instance.record('nas.scan.performance', summary);
  }
}
