import 'dart:async';

import '../ssh/ssh_client_manager.dart';

class NetworkRate {
  final double rxBytesPerSecond;
  final double txBytesPerSecond;
  const NetworkRate({
    required this.rxBytesPerSecond,
    required this.txBytesPerSecond,
  });
}

class SystemMetricsSnapshot {
  final double cpuUsedRatio;
  final double memoryUsedRatio;
  final int memoryTotalBytes;
  final int memoryUsedBytes;
  final double load1;
  final double load5;
  final double load15;
  final int uptimeSeconds;
  final double rootDiskUsedPercent;
  final double cpuTotalTicks;
  final double cpuIdleTicks;
  final String? primaryNetworkInterface;
  final Map<String, (int, int)> networkCounters;
  final Map<String, NetworkRate> networkRates;

  const SystemMetricsSnapshot({
    this.cpuUsedRatio = 0,
    this.memoryUsedRatio = 0,
    this.memoryTotalBytes = 0,
    this.memoryUsedBytes = 0,
    this.load1 = 0,
    this.load5 = 0,
    this.load15 = 0,
    this.uptimeSeconds = 0,
    this.rootDiskUsedPercent = 0,
    this.cpuTotalTicks = 0,
    this.cpuIdleTicks = 0,
    this.primaryNetworkInterface,
    this.networkCounters = const {},
    this.networkRates = const {},
  });

  factory SystemMetricsSnapshot.parse(String raw) {
    var memoryTotal = 0.0;
    var memoryAvailable = 0.0;
    var load1 = 0.0;
    var load5 = 0.0;
    var load15 = 0.0;
    var uptime = 0;
    var disk = 0.0;
    double? cpuUsed;
    var cpuTotal = 0.0;
    var cpuIdle = 0.0;
    String? defaultInterface;
    final networkCounters = <String, (int, int)>{};

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('cpu ')) {
        final values = trimmed
            .split(RegExp(r'\s+'))
            .skip(1)
            .map(double.parse)
            .toList();
        if (values.length >= 4) {
          final idle = values[3] + (values.length > 4 ? values[4] : 0);
          final total = values.fold<double>(0, (sum, value) => sum + value);
          cpuIdle = idle;
          cpuTotal = total;
          cpuUsed = total == 0 ? 0 : (total - idle) / total;
        }
      } else if (trimmed.startsWith('MemTotal:')) {
        memoryTotal = _firstNumber(trimmed);
      } else if (trimmed.startsWith('MemAvailable:')) {
        memoryAvailable = _firstNumber(trimmed);
      } else if (trimmed.startsWith('LoadAvg:')) {
        final values = trimmed
            .split(RegExp(r'\s+'))
            .skip(1)
            .map(double.parse)
            .toList();
        if (values.length >= 3) {
          load1 = values[0];
          load5 = values[1];
          load15 = values[2];
        }
      } else if (trimmed.startsWith('Uptime:')) {
        uptime = _firstNumber(trimmed).round();
      } else if (trimmed.startsWith('Disk:')) {
        disk = _firstNumber(trimmed);
      } else if (trimmed.startsWith('NetworkDefault:')) {
        final fields = trimmed.split(RegExp(r'\s+'));
        if (fields.length >= 2) defaultInterface = fields[1];
      } else if (trimmed.startsWith('Network:')) {
        final fields = trimmed.split(RegExp(r'\s+'));
        if (fields.length >= 4) {
          final rx = int.tryParse(fields[2]);
          final tx = int.tryParse(fields[3]);
          if (rx != null && tx != null && rx >= 0 && tx >= 0) {
            networkCounters[fields[1]] = (rx, tx);
          }
        }
      }
    }

    final nonLoopback = networkCounters.keys.where((name) => name != 'lo');
    final primary =
        defaultInterface != null &&
            networkCounters.containsKey(defaultInterface) &&
            defaultInterface != 'lo'
        ? defaultInterface
        : (nonLoopback.isEmpty ? null : nonLoopback.first);

    return SystemMetricsSnapshot(
      cpuUsedRatio: cpuUsed ?? 0,
      memoryUsedRatio: memoryTotal <= 0
          ? 0
          : ((memoryTotal - memoryAvailable) / memoryTotal).clamp(0, 1),
      memoryTotalBytes: (memoryTotal * 1024).round(),
      memoryUsedBytes:
          ((memoryTotal - memoryAvailable).clamp(0, double.infinity) * 1024)
              .round(),
      load1: load1,
      load5: load5,
      load15: load15,
      uptimeSeconds: uptime,
      rootDiskUsedPercent: disk,
      cpuTotalTicks: cpuTotal,
      cpuIdleTicks: cpuIdle,
      primaryNetworkInterface: primary,
      networkCounters: Map.unmodifiable(networkCounters),
    );
  }

  SystemMetricsSnapshot withCpuUsageSince(
    SystemMetricsSnapshot previous, {
    Duration? elapsed,
  }) {
    final totalDelta = cpuTotalTicks - previous.cpuTotalTicks;
    final idleDelta = cpuIdleTicks - previous.cpuIdleTicks;
    final seconds = elapsed == null ? 0.0 : elapsed.inMicroseconds / 1000000;
    final rates = <String, NetworkRate>{};
    if (seconds > 0) {
      for (final entry in networkCounters.entries) {
        final before = previous.networkCounters[entry.key];
        if (before == null) continue;
        final rxDelta = entry.value.$1 - before.$1;
        final txDelta = entry.value.$2 - before.$2;
        if (rxDelta < 0 || txDelta < 0) continue;
        rates[entry.key] = NetworkRate(
          rxBytesPerSecond: rxDelta / seconds,
          txBytesPerSecond: txDelta / seconds,
        );
      }
    }
    return SystemMetricsSnapshot(
      cpuUsedRatio: totalDelta <= 0
          ? cpuUsedRatio
          : ((totalDelta - idleDelta) / totalDelta).clamp(0, 1),
      memoryUsedRatio: memoryUsedRatio,
      memoryTotalBytes: memoryTotalBytes,
      memoryUsedBytes: memoryUsedBytes,
      load1: load1,
      load5: load5,
      load15: load15,
      uptimeSeconds: uptimeSeconds,
      rootDiskUsedPercent: rootDiskUsedPercent,
      cpuTotalTicks: cpuTotalTicks,
      cpuIdleTicks: cpuIdleTicks,
      primaryNetworkInterface: primaryNetworkInterface,
      networkCounters: networkCounters,
      networkRates: Map.unmodifiable(rates),
    );
  }

  static double _firstNumber(String value) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(value);
    return match == null ? 0 : double.tryParse(match.group(0)!) ?? 0;
  }
}

class SystemMetricsSampler {
  final SSHClientManager _sshManager;
  final Duration interval;

  SystemMetricsSampler(
    this._sshManager, {
    this.interval = const Duration(seconds: 3),
  });

  Stream<SystemMetricsSnapshot> watch(String serverId) async* {
    SystemMetricsSnapshot? previous;
    final clock = Stopwatch()..start();
    int? previousMicros;
    while (_sshManager.isConnected(serverId)) {
      final result = await _sshManager.executeWithLoginShell(
        serverId,
        r'''printf 'cpu '; awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9,$10}' /proc/stat; awk '/^MemTotal:/ {print "MemTotal:", $2} /^MemAvailable:/ {print "MemAvailable:", $2}' /proc/meminfo; printf 'LoadAvg: '; cut -d' ' -f1-3 /proc/loadavg; printf 'Uptime: '; cut -d' ' -f1 /proc/uptime; printf 'Disk: '; df -P / | awk 'NR==2 {print $5}'; awk '$2=="00000000" {print "NetworkDefault:",$1; exit}' /proc/net/route; awk 'NR>2 {gsub(":","",$1); print "Network:",$1,$2,$10}' /proc/net/dev''',
      );
      if (!result.isSuccess) break;
      final snapshot = SystemMetricsSnapshot.parse(result.stdout);
      final nowMicros = clock.elapsedMicroseconds;
      yield previous == null
          ? snapshot
          : snapshot.withCpuUsageSince(
              previous,
              elapsed: Duration(microseconds: nowMicros - previousMicros!),
            );
      previous = snapshot;
      previousMicros = nowMicros;
      await Future<void>.delayed(interval);
    }
  }
}
