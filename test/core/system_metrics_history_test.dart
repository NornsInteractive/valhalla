import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/dashboard/dashboard_provider.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';

class _ActiveServerNotifier extends ActiveServerNotifier {
  ServerProfile _initial;

  _ActiveServerNotifier(this._initial);

  @override
  ServerProfile? build() => _initial;

  void replace(ServerProfile server) {
    _initial = server;
    state = server;
  }
}

const _serverA = ServerProfile(
  id: 'a',
  name: 'A',
  host: 'a.example',
  username: 'root',
);
const _serverB = ServerProfile(
  id: 'b',
  name: 'B',
  host: 'b.example',
  username: 'root',
);

void main() {
  test(
    'metrics history keeps 60 samples and resets when server changes',
    () async {
      final stream = StreamController<SystemMetricsSnapshot>.broadcast();
      addTearDown(stream.close);
      final active = _ActiveServerNotifier(_serverA);
      final container = ProviderContainer(
        overrides: [
          activeServerProvider.overrideWith(() => active),
          systemMetricsStreamProvider.overrideWith((ref) => stream.stream),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        systemMetricsHistoryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      for (var i = 0; i < 65; i++) {
        stream.add(SystemMetricsSnapshot(cpuUsedRatio: i / 100));
        await pumpEventQueue();
      }

      final history = container.read(systemMetricsHistoryProvider);
      expect(history, hasLength(systemMetricsHistoryLimit));
      expect(history.first.cpuUsedRatio, 0.05);
      expect(history.last.cpuUsedRatio, 0.64);

      active.replace(_serverB);
      await pumpEventQueue();
      expect(container.read(systemMetricsHistoryProvider), isEmpty);
    },
  );
}
