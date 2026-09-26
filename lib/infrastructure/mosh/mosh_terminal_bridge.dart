import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../terminal/terminal_session_bridge.dart' show TerminalConnectionState;
import 'mosh_session_service.dart';

/// Mosh 终端桥：对外形状与 SSH 的 `TerminalSessionBridge` 对齐，
/// terminal_view 可以用完全相同的方式消费（stateListenable +
/// connecting/connected/disconnected/error + start/dispose + [terminal]）。
///
/// 与 SSH 桥的差异：Mosh 自己负责丢包重传与网络漫游，因此传输层抖动
/// 不会把状态打成 error —— 只有 bootstrap 失败、会话对象进入终态
/// （server 进程退出）或用户主动 dispose 才改变状态。
class MoshTerminalBridge {
  MoshTerminalBridge({
    required this.terminal,
    required MoshSessionService sessionService,
    required this.request,
    required this.serverName,
  }) : _service = sessionService;

  /// 渲染目标，由 UI 持有并传入（与 SSH 桥一致）。
  final Terminal terminal;

  /// bootstrap 参数（serverId / host / serverPath / portRange ...）。
  final MoshBootstrapRequest request;

  final String serverName;

  final MoshSessionService _service;

  bool _disposed = false;
  int _sessionEpoch = 0;
  Timer? _resizeTimer;
  (int, int)? _sentSize;
  int _lastWidth = 80;
  int _lastHeight = 24;

  MoshSessionHandle? _handle;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<Object>? _errorSub;

  MoshBootstrapError? _bootstrapError;
  String? _bootstrapErrorDetail;

  TerminalConnectionState _state = TerminalConnectionState.disconnected;
  TerminalConnectionState get state => _state;

  /// 连接状态变更通知，供弹窗等短生命周期消费者响应断连。
  final ValueNotifier<TerminalConnectionState> stateListenable =
      ValueNotifier<TerminalConnectionState>(
        TerminalConnectionState.disconnected,
      );

  /// 最近一次 bootstrap 失败的分类；成功或未开始时为 null。
  /// UI 据此给出针对性提示（如 notInstalled 时的安装命令）。
  MoshBootstrapError? get bootstrapError => _bootstrapError;

  /// bootstrap 失败细节（诊断用，不含展示文案）。
  String? get bootstrapErrorDetail => _bootstrapErrorDetail;

  void _setState(TerminalConnectionState next) {
    if (_disposed) return;
    _state = next;
    if (stateListenable.value != next) stateListenable.value = next;
  }

  Future<void> start({int initialWidth = 80, int initialHeight = 24}) async {
    if (_disposed) return;
    final epoch = ++_sessionEpoch;
    bool current() => !_disposed && epoch == _sessionEpoch;
    _lastWidth = initialWidth > 0 ? initialWidth : 80;
    _lastHeight = initialHeight > 0 ? initialHeight : 24;
    _bootstrapError = null;
    _bootstrapErrorDetail = null;

    terminal.eraseDisplay();
    terminal.setCursor(0, 0);
    _setState(TerminalConnectionState.connecting);
    terminal.write(
      '\x1b[36m[Starting Mosh session to $serverName...]\x1b[0m\r\n',
    );

    final MoshBootstrapResult result;
    try {
      result = await _service.bootstrap(request);
    } catch (error) {
      if (!current()) return;
      _bootstrapError = MoshBootstrapError.sshFailed;
      _bootstrapErrorDetail = '$error';
      _setState(TerminalConnectionState.error);
      terminal.write('\r\n\x1b[31m[Mosh bootstrap failed: $error]\x1b[0m\r\n');
      return;
    }
    if (!current()) return;

    if (result is MoshBootstrapFailure) {
      _bootstrapError = result.error;
      _bootstrapErrorDetail = result.detail;
      _setState(TerminalConnectionState.error);
      final detail = result.detail == null ? '' : ': ${result.detail}';
      terminal.write(
        '\r\n\x1b[31m[Mosh bootstrap failed '
        '(${result.error.name})$detail]\x1b[0m\r\n',
      );
      return;
    }

    final endpoint = (result as MoshBootstrapSuccess).endpoint;
    final MoshSessionHandle handle;
    try {
      handle = await _service.connect(
        endpoint,
        columns: _lastWidth,
        rows: _lastHeight,
      );
    } catch (error) {
      if (!current()) return;
      _setState(TerminalConnectionState.error);
      terminal.write(
        '\r\n\x1b[31m[Failed to start Mosh session: $error]\x1b[0m\r\n',
      );
      return;
    }
    if (!current()) {
      // start 已被 dispose/重启作废：不能留着一个没人管的会话。
      unawaited(handle.dispose());
      return;
    }
    _bindSession(handle, endpoint.port, epoch);
  }

  void _bindSession(MoshSessionHandle handle, int port, int epoch) {
    _handle = handle;
    _setState(TerminalConnectionState.connected);
    terminal.write(
      '\x1b[32m[Mosh session established (udp/$port). '
      'The session roams across network changes.]\x1b[0m\r\n',
    );

    _stdoutSub = const Utf8Decoder(allowMalformed: true)
        .bind(handle.stdout)
        .listen(
          terminal.write,
          onError: (Object error) {
            if (_disposed || epoch != _sessionEpoch) return;
            _setState(TerminalConnectionState.error);
            terminal.write(
              '\r\n\x1b[31m[Mosh session error: $error]\x1b[0m\r\n',
            );
          },
          onDone: () => _onSessionEnded(epoch),
        );

    // Mosh 自己负责丢包重传与漫游；socket/解析层的偶发错误是可恢复的，
    // 静默吞掉，避免把瞬时抖动当成断线。
    _errorSub = handle.errors.listen((_) {});

    // 会话终态（server 退出 / 被关闭）→ disconnected。stdout 流关闭也
    // 会走到这里；_teardownSession 的代际递增保证只生效一次。
    unawaited(handle.done.whenComplete(() => _onSessionEnded(epoch)));

    terminal.onOutput = (String data) {
      _handle?.send(utf8.encode(data));
    };

    terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      if (width <= 0 || height <= 0) return;
      _lastWidth = width;
      _lastHeight = height;
      _resizeTimer?.cancel();
      final size = (width, height);
      if (size == _sentSize) return;
      _resizeTimer = Timer(const Duration(milliseconds: 75), () {
        if (_handle != null && size != _sentSize) {
          _handle!.resize(width, height);
          _sentSize = size;
        }
      });
    };
  }

  void _onSessionEnded(int epoch) {
    if (_disposed || epoch != _sessionEpoch) return;
    terminal.write('\r\n\x1b[33m[Mosh session ended]\x1b[0m\r\n');
    _setState(TerminalConnectionState.disconnected);
    _teardownSession();
  }

  /// 拆掉当前 Mosh 会话，但保留 [terminal] 与 [stateListenable]。
  ///
  /// 与 [dispose] 的区别是这里不释放对外暴露的资源。代际递增同时把
  /// 迟到的 done/输出回调全部作废。
  void _teardownSession() {
    _sessionEpoch++;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _sentSize = null;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    final handle = _handle;
    _handle = null;
    if (handle != null) unawaited(handle.dispose());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _teardownSession();
    stateListenable.dispose();
  }
}
