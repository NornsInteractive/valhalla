import 'dart:async';
import 'dart:convert';

import 'package:dart_mosh/dart_mosh.dart';
import 'package:dartssh2/dartssh2.dart';

import '../../core/utils/shell_quote.dart';
import '../ssh/ssh_client_manager.dart';

/// bootstrap 失败的分类，供 UI 给出针对性提示（如安装引导）。
enum MoshBootstrapError {
  /// 远端没有 mosh-server（`command -v` 探测为空 / command not found）。
  notInstalled,

  /// mosh-server 有输出但没给出有效的 `MOSH CONNECT` 行。
  startFailed,

  /// 探测或启动超过预算仍未完成。
  timeout,

  /// SSH 通道异常（未连接 / 执行抛错 / 输出流出错）。
  sshFailed,
}

/// bootstrap 成功得到的 Mosh 服务器连接要素。
///
/// 刻意使用自有值类型而不是 dart_mosh 的 `MoshServerConfig`：
/// dart_mosh 的类型只允许出现在 lib/infrastructure/mosh/ 内部。
class MoshEndpoint {
  const MoshEndpoint({
    required this.host,
    required this.port,
    required this.key,
  });

  /// 服务器地址（原样透传，connect 时做 DNS 解析）。
  final String host;

  /// mosh-server 打印的 UDP 端口。
  final int port;

  /// mosh-server 打印的 22 字符 printable 会话密钥。
  final String key;
}

/// [MoshSessionService.bootstrap] 的结果。
sealed class MoshBootstrapResult {
  const MoshBootstrapResult();
}

/// bootstrap 成功。
class MoshBootstrapSuccess extends MoshBootstrapResult {
  const MoshBootstrapSuccess({required this.endpoint, required this.rawOutput});

  final MoshEndpoint endpoint;

  /// mosh-server 的完整输出，诊断用。
  final String rawOutput;
}

/// bootstrap 失败，[MoshBootstrapFailure.error] 给出分类。
class MoshBootstrapFailure extends MoshBootstrapResult {
  const MoshBootstrapFailure({required this.error, this.detail});

  final MoshBootstrapError error;

  /// 诊断细节（退出码 + 输出尾部等），不含展示文案。
  final String? detail;
}

/// 一次 Mosh bootstrap 的全部参数。
class MoshBootstrapRequest {
  const MoshBootstrapRequest({
    required this.serverId,
    required this.host,
    this.serverPath = 'mosh-server',
    this.portRange = '60000:61000',
    this.locale = 'en_US.UTF-8',
    this.term = 'xterm-256color',
    this.colors = 256,
  });

  /// 目标服务器 id，用于经 [SshCommandExecutor] 取当前 SSH client。
  final String serverId;

  /// 服务器地址，写入成功结果的 [MoshEndpoint.host]。
  final String host;

  /// 远端 mosh-server 可执行文件（名字或绝对路径）。
  final String serverPath;

  /// UDP 端口范围，`60000:61000` 或单端口 `60001`。
  final String portRange;

  /// 传给 mosh-server 的 locale（必须是 UTF-8 变体）。
  final String locale;

  /// 终端类型。
  final String term;

  /// 色彩数。
  final int colors;
}

/// Mosh 会话启动失败。
class MoshSessionException implements Exception {
  const MoshSessionException(this.message, [this.cause]);

  final String message;

  final Object? cause;

  @override
  String toString() => cause == null
      ? 'MoshSessionException: $message'
      : 'MoshSessionException: $message ($cause)';
}

/// Mosh 会话句柄：包装 dart_mosh 的会话对象，对桥/UI 层屏蔽具体实现。
abstract interface class MoshSessionHandle {
  /// 远端输出的字节流。
  Stream<List<int>> get stdout;

  /// 非致命错误流（socket/解析/解密抖动）。Mosh 自己会重传恢复。
  Stream<Object> get errors;

  /// 会话终态（server 进程退出或句柄被关闭）。
  Future<void> get done;

  /// 发送终端输入字节。
  void send(List<int> bytes);

  /// 同步终端尺寸。
  void resize(int columns, int rows);

  /// 关闭会话。
  Future<void> dispose();
}

/// 打开 dart_mosh 会话的函数接缝，测试可注入假实现。
typedef MoshSessionOpener =
    Future<MoshSession> Function({
      required MoshServerConfig server,
      required MoshCipher cipher,
      required int columns,
      required int rows,
    });

Future<MoshSession> _defaultOpenSession({
  required MoshServerConfig server,
  required MoshCipher cipher,
  required int columns,
  required int rows,
}) {
  return MoshSession.connect(
    server: server,
    cipher: cipher,
    columns: columns,
    rows: rows,
  );
}

/// Mosh 会话服务：bootstrap（借 SSH 执行 mosh-server）+ connect（UDP SSP）。
///
/// 本文件是全工程唯一允许 import dart_mosh 的地方；对外只暴露自有类型。
class MoshSessionService {
  MoshSessionService(
    this._executor, {
    MoshSessionOpener? openSession,
    Duration probeTimeout = const Duration(seconds: 10),
    Duration bootstrapTimeout = const Duration(seconds: 20),
    Duration connectTimeout = const Duration(seconds: 10),
    Duration drainGrace = const Duration(milliseconds: 500),
  }) : _openSession = openSession ?? _defaultOpenSession,
       _probeTimeout = probeTimeout,
       _bootstrapTimeout = bootstrapTimeout,
       _connectTimeout = connectTimeout,
       _drainGrace = drainGrace;

  final SshCommandExecutor _executor;
  final MoshSessionOpener _openSession;

  final Duration _probeTimeout;
  final Duration _bootstrapTimeout;
  final Duration _connectTimeout;
  final Duration _drainGrace;

  static final RegExp _connectLinePattern = RegExp(
    'MOSH CONNECT\\s+(\\d{1,5})\\s+([A-Za-z0-9+/]{$moshPrintableKeyLength})',
    multiLine: true,
  );

  static final RegExp _notFoundPattern = RegExp(
    'command not found',
    caseSensitive: false,
  );

  /// 通过 SSH 引导 mosh-server，成功返回 [MoshBootstrapSuccess]。
  ///
  /// 失败不抛异常，一律以 [MoshBootstrapFailure] 表达，分类见
  /// [MoshBootstrapError]。
  Future<MoshBootstrapResult> bootstrap(MoshBootstrapRequest request) async {
    final client = _executor.getClient(request.serverId);
    if (client == null || client.isClosed) {
      return MoshBootstrapFailure(
        error: MoshBootstrapError.sshFailed,
        detail: 'Server ${request.serverId} is not connected',
      );
    }

    final String serverCommand;
    try {
      final ports = _parsePortRange(request.portRange);
      serverCommand = MoshSshBootstrap(
        serverBinary: request.serverPath,
        locale: request.locale,
        term: request.term,
        colors: request.colors,
        serverPort: ports.$1,
        serverPortEnd: ports.$2,
      ).command();
    } on MoshException catch (e) {
      return MoshBootstrapFailure(
        error: MoshBootstrapError.startFailed,
        detail: e.message,
      );
    } on ArgumentError catch (e) {
      return MoshBootstrapFailure(
        error: MoshBootstrapError.startFailed,
        detail: '$e',
      );
    }

    try {
      // 1. 先探测：mosh-server 不在 PATH 时直接给出 notInstalled，
      //    而不是等启动命令莫名失败。
      final probe = await _runRemote(
        client,
        'bash -l -c ${cliShellQuote('command -v ${cliShellQuote(request.serverPath)}')}',
        timeout: _probeTimeout,
        stopAtConnectLine: false,
      );
      if (probe.exitCode == null) {
        // dartssh2 的通道 done 从不携带错误；无退出码即传输层挂了。
        return MoshBootstrapFailure(
          error: MoshBootstrapError.sshFailed,
          detail: 'SSH channel closed before the probe returned a status',
        );
      }
      if (probe.exitCode != 0 || probe.output.trim().isEmpty) {
        return const MoshBootstrapFailure(
          error: MoshBootstrapError.notInstalled,
        );
      }

      // 2. 启动 mosh-server 并等 MOSH CONNECT 行。包一层 bash -l 保证
      //    登录 PATH，与 SshCommandExecutor.executeWithLoginShell 的约定
      //    一致；注意这里不能用缓冲版 execute —— mosh-server 打印完
      //    CONNECT 行后会一直在前台运行，缓冲版会等到会话结束才返回。
      final run = await _runRemote(
        client,
        'bash -l -c ${cliShellQuote(serverCommand)}',
        timeout: _bootstrapTimeout,
        stopAtConnectLine: true,
      );
      final combined = run.output;
      String? parseError;
      try {
        final config = MoshServerConfig.parse(combined, host: request.host);
        return MoshBootstrapSuccess(
          endpoint: MoshEndpoint(
            host: config.host,
            port: config.port,
            key: config.key.printable,
          ),
          rawOutput: combined,
        );
      } on MoshException catch (e) {
        parseError = e.message;
      }
      if (run.exitCode == 127 || _notFoundPattern.hasMatch(combined)) {
        return MoshBootstrapFailure(
          error: MoshBootstrapError.notInstalled,
          detail: _summarize(run),
        );
      }
      if (run.exitCode == null && !run.stoppedEarly) {
        // dartssh2 的通道 done 从不携带错误；无退出码即传输层挂了。
        return MoshBootstrapFailure(
          error: MoshBootstrapError.sshFailed,
          detail:
              'SSH channel closed before mosh-server reported a status; '
              '${_summarize(run)}',
        );
      }
      return MoshBootstrapFailure(
        error: MoshBootstrapError.startFailed,
        // 走到这里必然是 CONNECT 行解析失败，parseError 一定已被赋值。
        detail: '$parseError; ${_summarize(run)}',
      );
    } on _RemoteTimeout {
      return const MoshBootstrapFailure(error: MoshBootstrapError.timeout);
    } catch (error) {
      return MoshBootstrapFailure(
        error: MoshBootstrapError.sshFailed,
        detail: '$error',
      );
    }
  }

  /// 连接 mosh-server 的 UDP 会话。
  ///
  /// 失败一律抛 [MoshSessionException]（含 DNS/绑定/超时等底层原因）。
  Future<MoshSessionHandle> connect(
    MoshEndpoint endpoint, {
    required int columns,
    required int rows,
  }) async {
    try {
      final key = MoshKey.parse(endpoint.key);
      final session = await _openSession(
        server: MoshServerConfig(
          host: endpoint.host,
          port: endpoint.port,
          key: key,
        ),
        cipher: MoshPacketCipher.aesOcb(key),
        columns: columns,
        rows: rows,
      ).timeout(_connectTimeout);
      return _MoshSessionHandle(session);
    } on TimeoutException catch (error) {
      throw MoshSessionException(
        'Mosh connect timed out to ${endpoint.host}:${endpoint.port}',
        error,
      );
    } catch (error) {
      throw MoshSessionException(
        'Failed to open Mosh session to ${endpoint.host}:${endpoint.port}',
        error,
      );
    }
  }

  static (int, int) _parsePortRange(String range) {
    final parts = range.split(':');
    final low = int.tryParse(parts.first.trim());
    if (low == null) {
      throw MoshException('Invalid Mosh UDP port range: $range.');
    }
    if (parts.length == 1) {
      return (low, low);
    }
    if (parts.length == 2) {
      final high = int.tryParse(parts[1].trim());
      if (high == null) {
        throw MoshException('Invalid Mosh UDP port range: $range.');
      }
      return (low, high);
    }
    throw MoshException('Invalid Mosh UDP port range: $range.');
  }

  static String _summarize(_RemoteRun run) {
    final code = run.exitCode?.toString() ?? 'unknown';
    final text = run.output.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return 'exit code $code';
    }
    final tail = text.length > 200 ? text.substring(text.length - 200) : text;
    return 'exit code $code: $tail';
  }

  /// 在一条 SSH exec 通道上跑命令，合并 stdout/stderr。
  ///
  /// [stopAtConnectLine] 为 true 时，输出里一旦出现 `MOSH CONNECT` 行就
  /// 立刻拆掉通道返回 —— mosh-server 对 SIGHUP 免疫，会继续在后台提供
  /// UDP 服务（真实 mosh 客户端同样是读完 CONNECT 行就甩掉 SSH 连接）。
  /// 超预算抛 [_RemoteTimeout]；通道/流异常原样抛出。
  Future<_RemoteRun> _runRemote(
    SSHClient client,
    String command, {
    required Duration timeout,
    required bool stopAtConnectLine,
  }) async {
    final buffer = StringBuffer();
    final connectSeen = Completer<void>();
    final deadline = Completer<void>();
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    final sessionDone = Completer<void>();
    final subs = <StreamSubscription<void>>[];
    final decode = const Utf8Decoder(allowMalformed: true);
    Object? streamError;
    SSHSession? session;
    Timer? timer;

    void completeOnce(Completer<void> completer) {
      if (!completer.isCompleted) completer.complete();
    }

    void onChunk(String chunk) {
      buffer.write(chunk);
      if (stopAtConnectLine &&
          !connectSeen.isCompleted &&
          _connectLinePattern.hasMatch(buffer.toString())) {
        connectSeen.complete();
      }
    }

    Future<void> cleanup() async {
      timer?.cancel();
      for (final sub in subs) {
        try {
          await sub.cancel();
        } catch (_) {
          // 通道可能已在关闭，取消失败无所谓。
        }
      }
    }

    try {
      session = await client.execute(command);
      // 立刻接管 session.done：传输层可能在任何时刻挂掉，一个还没有
      // 监听者的 Future 错误会直接变成未处理的异步错误。这里同步挂上
      // 转发监听，之后 Future.any 看的是这个必然有人监听的 completer。
      unawaited(
        session.done.then(
          (_) => completeOnce(sessionDone),
          onError: (Object error, StackTrace stackTrace) {
            if (!sessionDone.isCompleted) {
              sessionDone.completeError(error, stackTrace);
            }
          },
        ),
      );
      subs
        ..add(
          decode.bind(session.stdout).listen(
            onChunk,
            onDone: () => completeOnce(stdoutDone),
            onError: (Object error, StackTrace stackTrace) {
              streamError ??= error;
              completeOnce(stdoutDone);
            },
          ),
        )
        ..add(
          decode.bind(session.stderr).listen(
            onChunk,
            onDone: () => completeOnce(stderrDone),
            onError: (Object error, StackTrace stackTrace) {
              streamError ??= error;
              completeOnce(stderrDone);
            },
          ),
        );
      timer = Timer(timeout, () {
        if (!deadline.isCompleted) deadline.complete();
      });

      await Future.any<void>([
        if (stopAtConnectLine) connectSeen.future,
        sessionDone.future,
        deadline.future,
      ]);

      if (stopAtConnectLine && connectSeen.isCompleted) {
        _destroySession(session);
        await cleanup();
        return _RemoteRun(
          exitCode: null,
          output: buffer.toString(),
          stoppedEarly: true,
        );
      }

      if (deadline.isCompleted) {
        throw const _RemoteTimeout();
      }

      // 进程自己退出了（没等到 CONNECT 行）。等两条流收尾再分类，
      // 尽量把尾部输出也收进来。
      try {
        await Future.wait<void>([stdoutDone.future, stderrDone.future])
            .timeout(_drainGrace);
      } on TimeoutException {
        // 流迟迟不关闭也无所谓，分类只看已有输出。
      }
      if (streamError != null) {
        throw streamError!;
      }
      return _RemoteRun(
        exitCode: session.exitCode,
        output: buffer.toString(),
        stoppedEarly: false,
      );
    } catch (error) {
      if (session != null) {
        _destroySession(session);
      }
      await cleanup();
      rethrow;
    } finally {
      timer?.cancel();
    }
  }

  void _destroySession(SSHSession session) {
    try {
      // destroy 直接拆通道而不是只发 EOF，别让这条 exec 通道一直挂着。
      session.channel.destroy();
    } catch (_) {
      session.close();
    }
  }
}

class _RemoteRun {
  const _RemoteRun({
    required this.exitCode,
    required this.output,
    required this.stoppedEarly,
  });

  /// null 表示通道在拿到退出码前就关闭了（提前停止或传输层挂掉）。
  final int? exitCode;

  final String output;

  /// true 表示在 CONNECT 行到手后提前拆掉了通道。
  final bool stoppedEarly;
}

class _RemoteTimeout implements Exception {
  const _RemoteTimeout();
}

/// dart_mosh 会话的句柄实现：所有调用原样转发。
class _MoshSessionHandle implements MoshSessionHandle {
  _MoshSessionHandle(this._session);

  final MoshSession _session;

  @override
  Stream<List<int>> get stdout => _session.stdout;

  @override
  Stream<Object> get errors => _session.errors;

  @override
  Future<void> get done => _session.done;

  @override
  void send(List<int> bytes) => _session.send(bytes);

  @override
  void resize(int columns, int rows) => _session.resize(columns, rows);

  @override
  Future<void> dispose() => _session.close();
}
