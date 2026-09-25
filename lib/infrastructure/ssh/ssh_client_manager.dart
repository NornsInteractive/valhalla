import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/logging/sanitizer.dart';
import '../../data/models/server_profile.dart';
import 'ssh_host_key_verifier.dart';

class SSHExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const SSHExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
}

/// 输出流来源，用于区分标准输出与标准错误。
enum SSHStreamKind { stdout, stderr }

/// 一条实时远端输出片段（已脱敏）。
class SSHExecutionChunk {
  final SSHStreamKind kind;
  final String text;

  /// Present only on the final, empty chunk after a normally closed command.
  /// -1 means the transport closed without a remote exit status.
  final int? exitCode;

  const SSHExecutionChunk({
    required this.kind,
    required this.text,
    this.exitCode,
  });
}

/// SSH 命令执行能力抽象，供基础设施服务依赖与测试替身实现。
///
/// 仅覆盖被服务层使用的方法；连接建立/断开等生命周期方法保留在具体类上，
/// 由 provider 层管理。
abstract interface class SshCommandExecutor {
  bool isConnected(String serverId);

  SSHClient? getClient(String serverId);

  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout,
    String? sudoPassword,
  });

  /// 以 Login Shell 执行命令并**实时**推送输出片段。
  ///
  /// 供安装/登录等长时间命令展示进度；[executeWithLoginShell] 是它的
  /// 有界缓冲版本。超时以 [SSHConnectionException] 形式经流抛出；
  /// 取消订阅会关闭命令通道，正常结束的最后一块携带 exitCode。
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout,
    String? sudoPassword,
  });
}

/// 底层 socket 连接器。
///
/// 抽成 typedef 是为了给测试留接缝：[SSHSocket] 是 `abstract class`，
/// 测试可以提供一个假的 socket 而无需真实网络。
typedef SshSocketConnector =
    Future<SSHSocket> Function(String host, int port, Duration timeout);

Future<SSHSocket> _defaultSocketConnector(
  String host,
  int port,
  Duration timeout,
) => SSHSocket.connect(host, port, timeout: timeout);

class SSHClientManager implements SshCommandExecutor {
  final SSHHostKeyVerifier _hostKeyVerifier;
  final SshSocketConnector _socketConnector;
  final Map<String, SSHClient> _activeClients = {};
  final Map<String, ServerProfile> _clientTargets = {};
  final Map<String, _PendingConnection> _pendingConnections = {};
  final Map<String, Timer> _keepAliveTimers = {};

  /// 传输层掉线广播。值为对应的 serverId。
  ///
  /// 每有一个新的客户端建立就复用一个 controller（懒创建），
  /// 避免监听者拿到已关闭的流。
  StreamController<String>? _transportDiedController;

  /// 传输层心跳间隔，测试可注入以缩短等待。
  final Duration transportKeepAliveInterval;

  /// 主动探活超时，测试可注入以缩短等待。
  final Duration verifyAliveTimeout;

  /// Network handshake/authentication budget, excluding host-key approval time.
  final Duration authenticationTimeout;

  SSHClientManager(
    this._hostKeyVerifier, {
    SshSocketConnector? socketConnector,
    this.transportKeepAliveInterval = const Duration(
      seconds: AppConstants.sshTransportKeepAliveSeconds,
    ),
    this.authenticationTimeout = const Duration(seconds: 30),
    this.verifyAliveTimeout = const Duration(
      seconds: AppConstants.sshVerifyAliveTimeoutSeconds,
    ),
  }) : _socketConnector = socketConnector ?? _defaultSocketConnector;

  /// 传输层掉线事件流（广播）。
  ///
  /// 与 keepalive 轮询不同，[SSHClient.done] 会在连接真正结束时立即完成，
  /// 因此这是「多快发现掉线」的主要来源；keepalive 只是兜底。
  Stream<String> get transportDied {
    return (_transportDiedController ??= StreamController<String>.broadcast())
        .stream;
  }

  @override
  bool isConnected(String serverId) {
    final client = _activeClients[serverId];
    return client != null && !client.isClosed;
  }

  @override
  SSHClient? getClient(String serverId) => _activeClients[serverId];

  Future<SSHClient> getOrCreateClient(
    ServerProfile server, {
    String? password,
    String? privateKey,
    Future<bool> Function(
      String host,
      String keyType,
      String fingerprintSha256,
    )?
    onConfirmHostKey,
  }) {
    final existing = _activeClients[server.id];
    if (existing != null &&
        !existing.isClosed &&
        (_clientTargets[server.id]?.hasSameConnectionSettings(server) ??
            false)) {
      return Future.value(existing);
    }
    final pending = _pendingConnections[server.id];
    if (pending != null && pending.server.hasSameConnectionSettings(server)) {
      return pending.result.future;
    }
    if (existing != null || pending != null) disconnect(server.id);

    final attempt = _PendingConnection(server);
    _pendingConnections[server.id] = attempt;
    unawaited(
      _connect(server, attempt, password, privateKey, onConfirmHostKey),
    );
    return attempt.result.future;
  }

  Future<void> _connect(
    ServerProfile server,
    _PendingConnection attempt,
    String? password,
    String? privateKey,
    Future<bool> Function(String, String, String)? onConfirmHostKey,
  ) async {
    Timer? deadline;
    final elapsed = Stopwatch();
    var remaining = authenticationTimeout;
    void startDeadline() {
      if (attempt.result.isCompleted) return;
      elapsed.start();
      deadline = Timer(remaining, () {
        attempt.fail(SSHConnectionException('SSH authentication timed out'));
      });
    }

    try {
      final identities =
          server.authType == AuthType.privateKey &&
              privateKey != null &&
              privateKey.isNotEmpty
          ? SSHKeyPair.fromPem(privateKey)
          : null;
      const socketTimeout = Duration(
        seconds: AppConstants.connectTimeoutSeconds,
      );
      final socketFuture = _socketConnector(
        server.host,
        server.port,
        socketTimeout,
      );
      // A connector may complete after cancellation/timeout. Never retain its socket.
      unawaited(
        socketFuture.then((socket) {
          if (attempt.result.isCompleted) socket.destroy();
        }, onError: (Object _) {}),
      );
      final socket = await socketFuture.timeout(socketTimeout);
      attempt.socket = socket;
      if (attempt.result.isCompleted) {
        socket.destroy();
        return;
      }
      final client = SSHClient(
        socket,
        username: server.username,
        onPasswordRequest: () => password ?? '',
        identities: identities,
        keepAliveInterval: transportKeepAliveInterval,
        onVerifyHostKey: (keyType, fingerprint) async {
          return _hostKeyVerifier.verifyHostKey(
            host: server.host,
            port: server.port,
            keyType: keyType,
            fingerprint: Uint8List.fromList(fingerprint),
            onConfirmFirstTime: onConfirmHostKey == null
                ? null
                : (host, key, hash) async {
                    deadline?.cancel();
                    elapsed.stop();
                    remaining -= elapsed.elapsed;
                    elapsed.reset();
                    try {
                      final approved = await onConfirmHostKey(host, key, hash);
                      return approved && !attempt.result.isCompleted;
                    } finally {
                      startDeadline();
                    }
                  },
          );
        },
      );
      attempt.client = client;
      startDeadline();
      await Future.any<void>([
        client.authenticated,
        attempt.result.future.then((_) {}),
      ]);
      if (attempt.result.isCompleted) return;
      _activeClients[server.id] = client;
      _clientTargets[server.id] = server;
      _startKeepAlive(server.id, client);
      _watchTransportDeath(server.id, client);
      attempt.result.complete(client);
    } catch (e, st) {
      final error = switch (e) {
        SSHAuthFailError() => SSHAuthException(
          'SSH Authentication failed: ${e.message}',
        ),
        HostKeyMismatchException() => e,
        SSHConnectionException() => e,
        _ => SSHConnectionException(
          'Failed to connect to ${server.host}:${server.port}',
          e,
        ),
      };
      attempt.fail(error, st);
    } finally {
      deadline?.cancel();
      if (identical(_pendingConnections[server.id], attempt)) {
        _pendingConnections.remove(server.id);
      }
    }
  }

  /// 监听客户端的传输层结束事件并广播掉线。
  ///
  /// 代际守卫（[identical]）是必需的：客户端被替换后，旧客户端的
  /// `done` 仍会完成一次，若不加判断就会把已经重连成功的新连接误判为掉线。
  void _watchTransportDeath(String serverId, SSHClient client) {
    unawaited(
      client.done.then(
        (_) {
          if (!identical(_activeClients[serverId], client)) return;
          _transportDiedController?.add(serverId);
        },
        onError: (_) {
          if (!identical(_activeClients[serverId], client)) return;
          _transportDiedController?.add(serverId);
        },
      ),
    );
  }

  /// 主动探活：真的发一次全局请求，而不是只看 `isClosed`。
  ///
  /// 返回 `false` 时已把该服务器清理掉（keepalive 定时器 + 客户端），
  /// 调用方只需负责重连。
  ///
  /// 必须带超时：半开连接上 `ping()` 会一直挂着，既不返回也不抛错。
  Future<bool> verifyAlive(String serverId) async {
    final client = _activeClients[serverId];
    if (client == null || client.isClosed) {
      disconnect(serverId, notifyDeath: client != null);
      return false;
    }
    try {
      await client.ping().timeout(verifyAliveTimeout);
      return isConnected(serverId);
    } catch (_) {
      if (identical(_activeClients[serverId], client)) {
        disconnect(serverId, notifyDeath: true);
      }
      return isConnected(serverId);
    }
  }

  void _startKeepAlive(String serverId, SSHClient client) {
    _keepAliveTimers[serverId]?.cancel();
    _keepAliveTimers[serverId] = Timer.periodic(
      const Duration(seconds: AppConstants.keepAliveIntervalSeconds),
      (_) async {
        if (!identical(_activeClients[serverId], client)) return;
        if (client.isClosed) {
          disconnect(serverId, notifyDeath: true);
          return;
        }
        try {
          // 与 verifyAlive 同理：没有超时的话半开连接会让这个定时器
          // 永远卡在 await 上，连 `isClosed` 都不再检查。
          await client.ping().timeout(verifyAliveTimeout);
        } catch (_) {
          if (identical(_activeClients[serverId], client)) {
            disconnect(serverId, notifyDeath: true);
          }
        }
      },
    );
  }

  /// 以 Login Shell 方式执行命令，确保加载用户完整的 PATH 与环境变量
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    var exitCode = -1;
    var bufferedBytes = 0;

    await for (final chunk in _executeStreaming(
      serverId,
      command,
      timeout: timeout,
      sudoPassword: sudoPassword,
    )) {
      if (chunk.exitCode != null) exitCode = chunk.exitCode!;
      bufferedBytes += utf8.encode(chunk.text).length;
      if (bufferedBytes > 8 * 1024 * 1024) {
        throw SSHConnectionException(
          'Command output exceeds 8 MiB; use streaming',
        );
      }
      if (chunk.kind == SSHStreamKind.stdout) {
        stdoutBuffer.write(chunk.text);
      } else {
        stderrBuffer.write(chunk.text);
      }
    }

    return SSHExecutionResult(
      exitCode: exitCode,
      stdout: LogSanitizer.sanitize(stdoutBuffer.toString()),
      stderr: LogSanitizer.sanitize(stderrBuffer.toString()),
    );
  }

  /// 以 Login Shell 实时执行命令，逐块推送脱敏后的输出。
  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => _executeStreaming(
    serverId,
    command,
    timeout: timeout,
    sudoPassword: sudoPassword,
    sanitizeStreaming: true,
  );

  Stream<SSHExecutionChunk> _executeStreaming(
    String serverId,
    String command, {
    required Duration timeout,
    String? sudoPassword,
    bool sanitizeStreaming = false,
  }) {
    final client = _activeClients[serverId];
    if (client == null || client.isClosed) {
      return Stream.error(
        SSHConnectionException('Server $serverId is not connected'),
      );
    }

    // 针对命令转义，包装为 bash -l -c '...'
    final effectiveCommand = sudoPassword == null
        ? command
        : 'sudo -S -- $command';
    final effectiveEscaped = effectiveCommand.replaceAll("'", "'\\''");
    final loginShellCmd = "bash -l -c '$effectiveEscaped'";

    late StreamController<SSHExecutionChunk> controller;
    SSHSession? session;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    Timer? timeoutTimer;
    var finished = false;

    void closeSession(SSHSession active, {required bool terminate}) {
      if (terminate) {
        try {
          active.kill(SSHSignal.TERM);
        } finally {
          // SSHSession.close only sends EOF; a remote process may ignore it.
          active.channel.destroy();
        }
      } else {
        active.close();
      }
    }

    Future<void> finish({
      Object? error,
      StackTrace? stackTrace,
      bool completed = false,
    }) async {
      if (finished) return;
      finished = true;
      timeoutTimer?.cancel();
      final active = session;
      if (active != null) {
        if (completed && error == null) {
          controller.add(
            SSHExecutionChunk(
              kind: SSHStreamKind.stdout,
              text: '',
              exitCode: active.exitCode ?? -1,
            ),
          );
        }
        try {
          closeSession(active, terminate: !completed || error != null);
        } catch (_) {
          // 远端可能已结束会话，忽略关闭异常。
        }
      }
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      if (error != null) controller.addError(error, stackTrace);
      // onCancel must not await close(): close waits for cancellation itself.
      unawaited(controller.close());
    }

    controller = StreamController<SSHExecutionChunk>(
      onListen: () async {
        timeoutTimer = Timer(timeout, () {
          unawaited(
            finish(
              error: SSHConnectionException(
                'Command execution timed out after ${timeout.inSeconds}s',
              ),
            ),
          );
        });
        try {
          final active = await client.execute(loginShellCmd);
          if (finished) {
            closeSession(active, terminate: true);
            return;
          }
          session = active;
          final stdoutDone = Completer<void>();
          final stderrDone = Completer<void>();

          Stream<String> decode(Stream<Uint8List> bytes) {
            final text = const Utf8Decoder(allowMalformed: true).bind(bytes);
            return sanitizeStreaming ? LogSanitizer.stream(text) : text;
          }

          stdoutSub = decode(active.stdout).listen(
            (text) => controller.add(
              SSHExecutionChunk(kind: SSHStreamKind.stdout, text: text),
            ),
            onDone: stdoutDone.complete,
            onError: (Object e, StackTrace st) =>
                unawaited(finish(error: e, stackTrace: st)),
          );
          stderrSub = decode(active.stderr).listen(
            (text) => controller.add(
              SSHExecutionChunk(kind: SSHStreamKind.stderr, text: text),
            ),
            onDone: stderrDone.complete,
            onError: (Object e, StackTrace st) =>
                unawaited(finish(error: e, stackTrace: st)),
          );

          if (sudoPassword != null) {
            active.stdin.add(utf8.encode('$sudoPassword\n'));
          }

          unawaited(
            active.done.then(
              (_) async {
                await Future.wait([stdoutDone.future, stderrDone.future]);
                if (!finished) {
                  unawaited(finish(completed: true));
                }
              },
              onError: (Object e, StackTrace st) =>
                  unawaited(finish(error: e, stackTrace: st)),
            ),
          );
        } catch (e, st) {
          unawaited(finish(error: e, stackTrace: st));
        }
      },
      onCancel: () async {
        await finish();
      },
    );

    return controller.stream;
  }

  /// 注册一个已建立的客户端并开始监听它的传输层结束事件。
  ///
  /// 仅供测试使用：真实路径走 [getOrCreateClient]。抽出来是为了能在
  /// 不经过网络握手的前提下验证代际守卫（旧连接的 `done` 不得误报新连接掉线）。
  @visibleForTesting
  void debugRegisterClient(
    String serverId,
    SSHClient client, {
    bool watchTransport = true,
  }) {
    _activeClients[serverId] = client;
    if (watchTransport) {
      _watchTransportDeath(serverId, client);
    }
  }

  /// 用全新握手替换现有客户端。
  ///
  /// 重连路径必须走这里：半开连接的 [SSHClient.isClosed] 仍是 false，
  /// [getOrCreateClient] 会把僵尸客户端原样交回去。
  Future<SSHClient> reconnectClient(
    ServerProfile server, {
    String? password,
    String? privateKey,
    Future<bool> Function(
      String host,
      String keyType,
      String fingerprintSha256,
    )?
    onConfirmHostKey,
  }) async {
    disconnect(server.id);
    return getOrCreateClient(
      server,
      password: password,
      privateKey: privateKey,
      onConfirmHostKey: onConfirmHostKey,
    );
  }

  /// 断开指定服务器。
  ///
  /// [notifyDeath] 为 true 时先广播 [transportDied]，供重连编排器接手。
  /// 用户主动断开必须为 false，否则会把「我想断开」当成掉线又连回去。
  ///
  /// 必须先从 map 里摘掉再 close：[_watchTransportDeath] 的代际守卫看到
  /// map 里已经不是这个 client，就不会把用户断开或替换中的 close 再广播一次。
  void disconnect(String serverId, {bool notifyDeath = false}) {
    _pendingConnections
        .remove(serverId)
        ?.fail(SSHConnectionException('SSH connection cancelled'));
    _keepAliveTimers[serverId]?.cancel();
    _keepAliveTimers.remove(serverId);
    final client = _activeClients.remove(serverId);
    _clientTargets.remove(serverId);
    if (notifyDeath && client != null) {
      _transportDiedController?.add(serverId);
    }
    if (client != null && !client.isClosed) {
      client.close();
    }
  }

  void disconnectAll() {
    for (final serverId in {
      ..._activeClients.keys,
      ..._pendingConnections.keys,
    }) {
      disconnect(serverId);
    }
  }

  /// 释放资源。
  ///
  /// 会断开全部连接并关闭广播流；关闭后 [transportDied] 上的监听者
  /// 会收到 done，重连逻辑据此停止。
  void dispose() {
    disconnectAll();
    _transportDiedController?.close();
    _transportDiedController = null;
  }
}

class _PendingConnection {
  _PendingConnection(this.server);
  final ServerProfile server;
  final result = Completer<SSHClient>();
  SSHSocket? socket;
  SSHClient? client;

  void fail(Object error, [StackTrace? stackTrace]) {
    if (result.isCompleted) return;
    result.completeError(error, stackTrace);
    // Destroying the socket also interrupts an unfinished host-key/auth exchange.
    socket?.destroy();
    client?.close();
  }
}
