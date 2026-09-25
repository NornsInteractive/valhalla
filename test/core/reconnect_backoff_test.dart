import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';

/// 固定随机源，让抖动可预测。
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

void main() {
  group('ReconnectBackoff 退避序列', () {
    test('关掉抖动后是干净的 2 倍增长', () {
      const backoff = ReconnectBackoff(jitterRatio: 0);
      expect(backoff.delayFor(1), const Duration(seconds: 1));
      expect(backoff.delayFor(2), const Duration(seconds: 2));
      expect(backoff.delayFor(3), const Duration(seconds: 4));
      expect(backoff.delayFor(4), const Duration(seconds: 8));
      expect(backoff.delayFor(5), const Duration(seconds: 16));
    });

    test('封顶在 maxDelay，不会无限增长', () {
      const backoff = ReconnectBackoff(jitterRatio: 0);
      expect(backoff.delayFor(6), const Duration(seconds: 30));
      expect(backoff.delayFor(7), const Duration(seconds: 30));
      // 远超上限也依然封顶（用户要求无限重试，间隔必须收敛）。
      expect(backoff.delayFor(1000), const Duration(seconds: 30));
    });

    test('抖动落在 ±20% 区间内', () {
      // nextDouble() == 0 → factor = 1 - 0.2 = 0.8（下界）
      // nextDouble() == 1 → factor = 1 + 0.2 = 1.2（上界）
      final low = ReconnectBackoff(
        jitterRatio: 0.2,
        random: _FixedRandom(0),
      ).delayFor(1);
      final high = ReconnectBackoff(
        jitterRatio: 0.2,
        random: _FixedRandom(1),
      ).delayFor(1);

      expect(low.inMilliseconds, 800);
      expect(high.inMilliseconds, 1200);
    });

    test('抖动不会突破 maxDelay 上限', () {
      // 基准已封顶 30s，抖动上界 1.2 倍必须被夹回 30s，
      // 否则用户在长时间断线后会看到比承诺更长的等待。
      final jittered = ReconnectBackoff(
        jitterRatio: 0.5,
        random: _FixedRandom(1),
      ).delayFor(50);

      expect(jittered, const Duration(seconds: 30));
    });

    test('抖动从不为负', () {
      final lowest = ReconnectBackoff(
        jitterRatio: 0.99,
        random: _FixedRandom(0),
      ).delayFor(1);

      expect(lowest.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('真实随机源下抖动始终在区间内', () {
      final backoff = ReconnectBackoff();
      for (var attempt = 1; attempt <= 10; attempt++) {
        final delay = backoff.delayFor(attempt);
        expect(delay.inMilliseconds, greaterThan(0));
        expect(
          delay.inMilliseconds,
          lessThanOrEqualTo(30000),
          reason: '第 $attempt 次重试超过上限',
        );
      }
    });

    test('自定义初始间隔与倍数生效', () {
      const backoff = ReconnectBackoff(
        initialDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 2),
        multiplier: 3,
        jitterRatio: 0,
      );
      expect(backoff.delayFor(1), const Duration(milliseconds: 500));
      expect(backoff.delayFor(2), const Duration(milliseconds: 1500));
      expect(backoff.delayFor(3), const Duration(seconds: 2));
    });
  });

  group('重试可行性分类', () {
    test('主机密钥变更不可重试', () {
      final error = HostKeyMismatchException(
        host: 'example.com:22',
        expectedFingerprint: 'SHA256:aaa',
        actualFingerprint: 'SHA256:bbb',
      );

      expect(isHostKeyMismatch(error), isTrue);
      expect(isRetryableConnectFailure(error), isFalse);
    });

    test('网络/认证类错误可重试', () {
      expect(isRetryableConnectFailure(SSHConnectionException('boom')), isTrue);
      expect(isRetryableConnectFailure(SSHAuthException('bad pw')), isTrue);
      expect(isRetryableConnectFailure(Exception('timeout')), isTrue);
      expect(isRetryableConnectFailure('not even an exception'), isTrue);
    });
  });

  group('ReconnectState', () {
    test('默认是 idle', () {
      const state = ReconnectState();
      expect(state.status, ReconnectStatus.idle);
      expect(state.isConnected, isFalse);
      expect(state.isBusy, isFalse);
      expect(state.attempt, 0);
    });

    test('copyWith 可清空 delay 与 error', () {
      const state = ReconnectState(
        status: ReconnectStatus.reconnecting,
        attempt: 3,
        nextDelay: Duration(seconds: 4),
        errorMessage: 'boom',
      );

      final cleared = state.copyWith(clearDelay: true, clearError: true);
      expect(cleared.nextDelay, isNull);
      expect(cleared.errorMessage, isNull);
      expect(cleared.attempt, 3, reason: '未指定的字段应保留');
      expect(cleared.status, ReconnectStatus.reconnecting);
    });

    test('connecting 与 reconnecting 都算 busy', () {
      expect(
        const ReconnectState(status: ReconnectStatus.connecting).isBusy,
        isTrue,
      );
      expect(
        const ReconnectState(status: ReconnectStatus.reconnecting).isBusy,
        isTrue,
      );
      expect(
        const ReconnectState(status: ReconnectStatus.connected).isBusy,
        isFalse,
      );
    });
  });
}
