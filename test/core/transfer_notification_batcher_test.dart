import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/main.dart';

void main() {
  test('单次完成在窗口结束后发出一，计数为 1', () async {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(milliseconds: 20),
    );
    batcher.add();
    expect(sent, isEmpty, reason: '窗口没到之前不该发');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sent, [1]);
  });

  test('窗口内多次完成合并成一条通知', () async {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(milliseconds: 40),
    );
    batcher.add();
    batcher.add();
    batcher.add();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent, [3], reason: '三次完成应合并成一条「3 个传输已完成」');
  });

  test('窗口结束后的新完成重新从 1 开始', () async {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(milliseconds: 20),
    );
    batcher.add();
    batcher.add();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    batcher.add();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sent, [2, 1]);
  });

  test('flushNow 立刻发出待发计数', () async {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(seconds: 30),
    );
    batcher.add();
    batcher.add();
    batcher.flushNow();
    expect(sent, [2], reason: '退出时必须立刻发，否则最后几条会丢');
  });

  test('没有待发计数时 flushNow 不发空通知', () {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(seconds: 30),
    );
    batcher.flushNow();
    expect(sent, isEmpty);
  });

  test('dispose 后待发计数不再发出', () async {
    final sent = <int>[];
    final batcher = TransferNotificationBatcher(
      send: sent.add,
      window: const Duration(milliseconds: 20),
    );
    batcher.add();
    batcher.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(sent, isEmpty);
  });
}
