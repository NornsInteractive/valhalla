import 'dart:async';

import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

/// 可控的 [SftpTransferHandle] 替身。
///
/// 真实的句柄要连一台 SFTP 服务器才能造出来，而我们要测的恰恰是
/// 「暂停之后进度不再推进」「取消之后任务变成 canceled」这类边界，
/// 用手动推进的替身才能稳定复现。
///
/// 用法：`startXxx` 返回它，测试里调 [emitProgress] 推进进度、
/// [finish] 结束、[fail] 失败。传输由测试驱动，不依赖真实计时器。
class FakeTransferHandle implements SftpTransferHandle {
  FakeTransferHandle({this.totalBytes = 100, this.onProgress});

  @override
  final int totalBytes;

  /// 传输层的进度回调，语义与真实句柄的 `onProgress` 一致。
  ///
  /// 由句柄在**字节数真的前进之后**调用，而不是由调用方在 `startXxx`
  /// 里补一次。这个区别很关键：测试里手动 [emitProgress] 时也必须触发
  /// 回调，否则「暂停后继续，进度恢复上报」这条路径根本走不到，
  /// 而它恰恰是最容易写错的地方。
  final void Function(int bytes)? onProgress;

  final _done = Completer<void>();

  int _transferred = 0;

  /// 调用过 [pause] 的次数，用来断言 UI 真的把暂停传下去了。
  int pauseCount = 0;

  /// 调用过 [resume] 的次数。
  int resumeCount = 0;

  /// 调用过 [abort] 的次数。
  int abortCount = 0;

  bool _paused = false;
  bool get isPaused => _paused;

  /// 是否已被中止。
  bool get isAborted => abortCount > 0;

  /// 中止时是否让 [done] 正常完成（而不是抛 [SftpTransferAborted]）。
  ///
  /// dartssh2 的 `SftpFileWriter.abort()` 走的就是「正常完成」这条路，
  /// 生产实现因此必须自己记一个中止标志，不能靠 done 抛异常来判断。
  /// 默认 false 走抛异常那条；共享的 `_DownloadHandle` 则是正常完成。
  /// 两种语义都要能被测到，否则「中止后仍被当成成功」这个 bug 会漏网。
  bool abortCompletesNormally = false;

  @override
  int get transferredBytes => _transferred;

  @override
  Future<void> get done => _done.future;

  /// 推进一步进度。
  ///
  /// 暂停状态下**不推进、也不上报**——真实句柄在暂停时不会再发数据，
  /// 替身必须照这个语义来，否则「暂停后进度还在涨」这个 bug 测不出来。
  void emitProgress(int bytes) {
    if (isAborted) return;
    if (_paused) return;
    _transferred = bytes;
    // 先更新自己的字节数再回调上层：真实的 `onProgress` 到达时，
    // 句柄的 `transferredBytes` 已经是新值了。反过来的话，
    // 「拿句柄的进度来修正 state」这类实现会读到旧值。
    onProgress?.call(bytes);
  }

  /// 结束传输（成功）。
  ///
  /// 暂停中**拒绝完成**——这就是「暂停后队列卡住」的真实形态：排在前面的
  /// 任务被暂停，它既不结束也不让位，后面的任务永远等不到调度。
  /// 替身若不这样表现，删掉 `pauseTransfer` 末尾的 `_pumpQueue()` 也能过。
  void finish() {
    if (_done.isCompleted) return;
    // 中止过的句柄不会再「成功完成」。
    if (isAborted) return;
    if (_paused) return;
    _done.complete();
  }

  /// 结束传输（失败）。
  void fail(Object error) {
    if (_done.isCompleted) return;
    _done.completeError(error);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _paused = true;
  }

  @override
  Future<void> resume() async {
    resumeCount++;
    _paused = false;
  }

  @override
  Future<void> abort() async {
    abortCount++;
    _paused = false;
    if (_done.isCompleted) return;
    if (abortCompletesNormally) {
      _done.complete();
    } else {
      _done.completeError(const SftpTransferAborted());
    }
  }
}
