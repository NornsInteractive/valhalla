import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dartssh2/dartssh2.dart';

import '../../core/errors/app_exceptions.dart';
import '../ssh/ssh_transfer_connection.dart';
import 'sftp_client_service.dart';

typedef SftpWorkerConnector =
    Future<SSHClient> Function(SshTransferConnection connection);

/// Browsing keeps its existing client; bulk data never enters the UI isolate.
class IsolatedSftpClientService extends SftpClientService {
  final SshTransferConnection? Function() _connectionFor;
  final SftpWorkerConnector? _workerConnector;
  final _transfers = <_WorkerTransfer>{};
  bool _closed = false;

  IsolatedSftpClientService(
    super.sshClient, {
    required SshTransferConnection? Function() connectionFor,
    SftpWorkerConnector? workerConnector,
  }) : _connectionFor = connectionFor,
       _workerConnector = workerConnector;

  @override
  Future<SftpTransferHandle> startDownload(
    String remotePath,
    String localPath, {
    void Function(int)? onProgress,
  }) => _start(remotePath, localPath, onProgress: onProgress);

  @override
  Future<SftpTransferHandle> startResumableDownload(
    String remotePath,
    String localPath, {
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
    SftpPhaseCallback? onPhase,
  }) => _start(
    remotePath,
    localPath,
    expectedSource: expectedSource,
    onSource: onSource,
    onProgress: onProgress,
    onPhase: onPhase,
  );

  @override
  Future<SftpTransferHandle> startUpload(
    String localPath,
    String remotePath, {
    void Function(int)? onProgress,
  }) => _start(remotePath, localPath, upload: true, onProgress: onProgress);

  @override
  Future<SftpTransferHandle> startResumableUpload(
    String localPath,
    String remotePath, {
    required String transferId,
    Map<String, dynamic>? expectedSource,
    required void Function(Map<String, dynamic>) onSource,
    void Function(int)? onProgress,
    SftpPhaseCallback? onPhase,
  }) => _start(
    remotePath,
    localPath,
    upload: true,
    transferId: transferId,
    expectedSource: expectedSource,
    onSource: onSource,
    onProgress: onProgress,
    onPhase: onPhase,
  );

  Future<SftpTransferHandle> _start(
    String remotePath,
    String localPath, {
    bool upload = false,
    String? transferId,
    Map<String, dynamic>? expectedSource,
    void Function(Map<String, dynamic>)? onSource,
    void Function(int)? onProgress,
    SftpPhaseCallback? onPhase,
  }) async {
    final connection = _connectionFor();
    if (_closed || !isRealConnected || connection == null) {
      throw const SSHConnectionException('SSH_DISCONNECTED');
    }
    bool current() =>
        !_closed && isRealConnected && identical(connection, _connectionFor());
    final transfer = _WorkerTransfer(
      onSource: (source) {
        if (current()) onSource?.call(source);
      },
      onProgress: (bytes) {
        if (current()) onProgress?.call(bytes);
      },
      onPhase: (phase, processed, total) {
        if (current()) onPhase?.call(phase, processed, total);
      },
    );
    _transfers.add(transfer);
    unawaited(
      transfer.done.then<void>(
        (_) {
          _transfers.remove(transfer);
        },
        onError: (Object _, StackTrace _) {
          _transfers.remove(transfer);
        },
      ),
    );
    // Return the control handle before authentication/prefix checks so cancel
    // also stops a transfer which has not started writing yet.
    unawaited(
      transfer
          .start((
            connection: connection,
            remotePath: remotePath,
            localPath: localPath,
            upload: upload,
            transferId: transferId,
            resumable: onSource != null,
            expectedSource: expectedSource,
            connector: _workerConnector,
          ))
          .then<void>(
            (_) async {
              if (!current()) await transfer.abort();
            },
            onError: (Object _, StackTrace _) {
              // The handle's done future owns startup errors too.
            },
          ),
    );
    return transfer;
  }

  @override
  void dispose() {
    _closed = true;
    for (final transfer in _transfers.toList()) {
      unawaited(transfer.abort());
    }
    super.dispose();
  }
}

typedef _TransferRequest = ({
  SshTransferConnection connection,
  String remotePath,
  String localPath,
  bool upload,
  String? transferId,
  bool resumable,
  Map<String, dynamic>? expectedSource,
  SftpWorkerConnector? connector,
});

class _WorkerTransfer implements SftpTransferHandle, SftpCommittingTransfer {
  _WorkerTransfer({this.onSource, this.onProgress, this.onPhase}) {
    unawaited(
      _ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _events.listen(_onEvent);
  }

  final void Function(Map<String, dynamic>)? onSource;
  final void Function(int)? onProgress;
  final SftpPhaseCallback? onPhase;
  final _events = ReceivePort();
  final _ready = Completer<void>();
  final _done = Completer<void>();
  final _commandsReady = Completer<SendPort>();
  final _pendingCommands = <int, Completer<void>>{};
  Isolate? _isolate;
  var _nextCommand = 0;
  var _upload = false;
  var _resumable = false;
  var _aborted = false;

  @override
  int totalBytes = 0;
  @override
  int transferredBytes = 0;
  @override
  bool isCommitting = false;
  @override
  Future<void> get done => _done.future;

  Future<void> start(_TransferRequest request) async {
    _upload = request.upload;
    _resumable = request.resumable;
    try {
      _isolate = await Isolate.spawn(
        _runTransferWorker,
        (request, _events.sendPort),
        onError: _events.sendPort,
        onExit: _events.sendPort,
        debugName: 'sftp-transfer',
      );
      if (_done.isCompleted) _isolate!.kill(priority: Isolate.immediate);
      // Resuming may verify a large prefix before the handle is ready.
      await _ready.future;
    } catch (error, stack) {
      _fail(error, stack);
      rethrow;
    }
  }

  void _onEvent(dynamic event) {
    if (_done.isCompleted) return;
    try {
      if (event == null || event is! List || event.isEmpty) {
        throw const SSHConnectionException('SFTP_TRANSFER_WORKER_STOPPED');
      }
      switch (event[0]) {
        case 'control':
          _commandsReady.complete(event[1] as SendPort);
        case 'source':
          onSource?.call((event[1] as Map).cast<String, dynamic>());
        case 'phase':
          final phase = event[1] as SftpTransferPhase;
          isCommitting =
              _upload && _resumable && phase == SftpTransferPhase.verifying;
          onPhase?.call(phase, event[2] as int, event[3] as int);
        case 'ready':
          totalBytes = event[1] as int;
          transferredBytes = event[2] as int;
          _ready.complete();
        case 'progress':
          transferredBytes = event[1] as int;
          onProgress?.call(transferredBytes);
        case 'ack':
          _pendingCommands.remove(event[1])?.complete();
        case 'committing':
          isCommitting = true;
          _pendingCommands.remove(event[1])?.complete();
        case 'complete':
          transferredBytes = event[1] as int;
          _done.complete();
          _cleanup();
        case 'failure':
          _fail(event[1] as Object, StackTrace.fromString(event[2] as String));
        default:
          throw const SSHConnectionException('SFTP_TRANSFER_WORKER_FAILED');
      }
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_done.isCompleted) return;
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    _done.completeError(error, stack);
    _cleanup();
  }

  void _cleanup() {
    _events.close();
    _isolate?.kill(priority: Isolate.immediate);
    if (!_commandsReady.isCompleted) {
      // A canceled start must release control requests waiting for the port.
      final port = ReceivePort();
      _commandsReady.complete(port.sendPort);
      port.close();
    }
    for (final command in _pendingCommands.values) {
      command.complete();
    }
    _pendingCommands.clear();
  }

  Future<void> _command(
    String action, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_done.isCompleted) return;
    final port = await _commandsReady.future;
    if (_done.isCompleted) return;
    final id = ++_nextCommand;
    final completion = Completer<void>();
    _pendingCommands[id] = completion;
    port.send([action, id]);
    await completion.future.timeout(timeout);
  }

  @override
  Future<void> pause() => _command('pause');
  @override
  Future<void> resume() => _command('resume');
  @override
  Future<void> abort() async {
    if (_done.isCompleted || _aborted) return;
    if (isCommitting) {
      await done;
      return;
    }
    _aborted = true;
    try {
      await _command('abort', timeout: const Duration(seconds: 65));
      if (isCommitting) await done;
    } on TimeoutException {
      if (isCommitting) rethrow;
      // Killing this worker cannot close the browsing/terminal connection.
    } finally {
      if (!isCommitting) {
        _fail(const SftpTransferAborted(), StackTrace.current);
      }
    }
  }
}

Future<SSHClient> _connectWorker(SshTransferConnection connection) async {
  final socket = await SSHSocket.connect(
    connection.host,
    connection.port,
    timeout: const Duration(seconds: 30),
  );
  SSHClient? client;
  try {
    client = SSHClient(
      socket,
      username: connection.username,
      identities: connection.privateKey == null
          ? null
          : SSHKeyPair.fromPem(connection.privateKey!),
      onPasswordRequest: () => connection.password ?? '',
      onVerifyHostKey: connection.matchesHostKey,
    );
    await client.authenticated.timeout(const Duration(seconds: 30));
    return client;
  } catch (_) {
    try {
      await client?.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    socket.destroy();
    rethrow;
  }
}

Future<void> _runTransferWorker((_TransferRequest, SendPort) message) async {
  final (request, events) = message;
  final commands = ReceivePort();
  events.send(['control', commands.sendPort]);
  SSHClient? client;
  SftpClientService? service;
  SftpTransferHandle? handle;
  var aborted = false;
  var paused = false;
  var reportedBytes = 0;
  var reportedPhase = SftpTransferPhase.preparing;
  final progressClock = Stopwatch()..start();
  final phaseClock = Stopwatch()..start();
  Object? failure;
  StackTrace? failureStack;

  commands.listen((dynamic command) async {
    try {
      switch (command[0]) {
        case 'pause':
          paused = true;
          await handle?.pause();
        case 'resume':
          paused = false;
          await handle?.resume();
        case 'abort':
          if (handle is SftpCommittingTransfer &&
              (handle as SftpCommittingTransfer).isCommitting) {
            events.send(['committing', command[1]]);
            return;
          }
          aborted = true;
          await handle?.abort();
          await client?.close().timeout(const Duration(seconds: 2));
      }
      events.send(['ack', command[1]]);
    } catch (error, stack) {
      events.send([
        'failure',
        aborted ? const SftpTransferAborted() : _sendableFailure(error),
        stack.toString(),
      ]);
    }
  });

  void progress(int bytes) {
    reportedBytes = bytes;
    if (progressClock.elapsedMilliseconds < 150) return;
    progressClock.reset();
    events.send(['progress', bytes]);
  }

  void phase(SftpTransferPhase next, int processed, int total) {
    if (next == reportedPhase &&
        processed < total &&
        phaseClock.elapsedMilliseconds < 150) {
      return;
    }
    reportedPhase = next;
    phaseClock.reset();
    events.send(['phase', next, processed, total]);
  }

  void source(Map<String, dynamic> identity) =>
      events.send(['source', identity]);

  try {
    client = await (request.connector ?? _connectWorker)(request.connection);
    if (aborted) throw const SftpTransferAborted();
    service = SftpClientService(client);
    if (request.upload) {
      handle = request.resumable
          ? await service.startResumableUpload(
              request.localPath,
              request.remotePath,
              transferId: request.transferId!,
              expectedSource: request.expectedSource,
              onSource: source,
              onProgress: progress,
              onPhase: phase,
            )
          : await service.startUpload(
              request.localPath,
              request.remotePath,
              onProgress: progress,
            );
    } else {
      handle = request.resumable
          ? await service.startResumableDownload(
              request.remotePath,
              request.localPath,
              expectedSource: request.expectedSource,
              onSource: source,
              onProgress: progress,
              onPhase: phase,
            )
          : await service.startDownload(
              request.remotePath,
              request.localPath,
              onProgress: progress,
            );
    }
    // Observe done before cancellation can synchronously complete it with error.
    unawaited(
      handle.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    if (aborted) {
      await handle.abort();
      throw const SftpTransferAborted();
    }
    if (paused) await handle.pause();
    events.send(['ready', handle.totalBytes, handle.transferredBytes]);
    await handle.done;
    if (aborted) throw const SftpTransferAborted();
    reportedBytes = handle.transferredBytes;
  } catch (error, stack) {
    failure = aborted ? const SftpTransferAborted() : _sendableFailure(error);
    failureStack = stack;
  } finally {
    service?.dispose();
    try {
      await client?.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Cleanup errors must not replace the transfer outcome.
    } finally {
      client?.socket.destroy();
    }
    commands.close();
  }
  if (failure == null) {
    events.send(['complete', reportedBytes]);
  } else {
    events.send(['failure', failure, failureStack.toString()]);
  }
}

Object _sendableFailure(Object error) => switch (error) {
  SftpTransferAborted() => const SftpTransferAborted(),
  SftpStatusError() => SftpStatusError(error.code, error.message),
  SFTPException() => SFTPException(error.message),
  TimeoutException() => TimeoutException('SFTP transfer timed out'),
  FileSystemException() => FileSystemException(
    'SFTP local file operation failed',
    '',
    OSError('', error.osError?.errorCode ?? 0),
  ),
  SSHAuthFailError() => const SSHAuthException('SSH_AUTH_FAILED'),
  SSHError() ||
  SftpAbortError() ||
  SocketException() ||
  SSHConnectionException() => const SSHConnectionException('SSH_DISCONNECTED'),
  _ => const SFTPException('SFTP_TRANSFER_WORKER_FAILED'),
};
