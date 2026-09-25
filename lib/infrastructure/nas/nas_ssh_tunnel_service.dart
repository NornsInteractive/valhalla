import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../../data/models/nas_source.dart';
import '../ssh/ssh_client_manager.dart';

/// Per-source HTTP forwards. TLS endpoints retain certificate verification by
/// using a direct connection; changing a TLS URL to 127.0.0.1 is not safe.
class NasSshTunnelService {
  final SshCommandExecutor _ssh;
  final Map<String, _NasTunnel> _tunnels = {};
  Future<void> _queue = Future.value();
  bool _disposed = false;
  NasSshTunnelService(this._ssh);

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Uri> forward(NasSource source) => _serial(() async {
    if (_disposed) throw StateError('NAS_TUNNEL_DISPOSED');
    final remote = Uri.parse(source.endpoint);
    if (remote.scheme == 'https') {
      throw StateError('NAS_TUNNEL_HTTPS_UNSUPPORTED');
    }
    if (remote.scheme != 'http' ||
        remote.host.isEmpty ||
        remote.userInfo.isNotEmpty ||
        remote.hasFragment ||
        remote.port < 1 ||
        remote.port > 65535 ||
        source.sshServerId == null ||
        source.type == NasSourceType.sftp ||
        source.type == NasSourceType.smb) {
      throw ArgumentError('NAS_TUNNEL_INVALID_SOURCE');
    }
    final client = _ssh.getClient(source.sshServerId!);
    if (client == null || client.isClosed) {
      throw StateError('NAS_SSH_NOT_CONNECTED');
    }
    final previous = _tunnels[source.id];
    if (previous != null &&
        identical(previous.client, client) &&
        previous.remote == remote &&
        !previous.closed) {
      return remote.replace(host: '127.0.0.1', port: previous.server.port);
    }
    await _close(source.id);
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    if (_disposed || client.isClosed) {
      await server.close();
      throw StateError('NAS_SSH_NOT_CONNECTED');
    }
    final tunnel = _NasTunnel(server, client, remote);
    _tunnels[source.id] = tunnel;
    server.listen(
      (socket) {
        if (tunnel.closed || tunnel.connections.length >= 32) {
          socket.destroy();
          return;
        }
        tunnel.connections[socket] = null;
        unawaited(_relay(tunnel, socket));
      },
      onError: (Object _) {
        unawaited(_drop(source.id, tunnel));
      },
    );
    unawaited(
      client.done.then(
        (_) => _drop(source.id, tunnel),
        onError: (Object _, StackTrace _) => _drop(source.id, tunnel),
      ),
    );
    return remote.replace(host: '127.0.0.1', port: server.port);
  });

  Future<void> _relay(_NasTunnel tunnel, Socket socket) async {
    SSHForwardChannel? channel;
    try {
      channel = await tunnel.client
          .forwardLocal(
            tunnel.remote.host,
            tunnel.remote.port,
            localHost: socket.remoteAddress.address,
            localPort: socket.remotePort,
          )
          .then((value) {
            // A timed-out/disposed opener may finish later. Never leak its channel.
            if (tunnel.closed || !tunnel.connections.containsKey(socket)) {
              value.destroy();
              throw StateError('NAS_TUNNEL_CLOSED');
            }
            return value;
          })
          .timeout(const Duration(seconds: 15));
      tunnel.connections[socket] = channel;
      // addStream/pipe propagate pause/resume to sockets and SSH receive windows;
      // there is no media buffer or full-response accumulation in this bridge.
      await Future.wait([
        socket.cast<List<int>>().pipe(channel.sink),
        socket.addStream(channel.stream).then((_) => socket.close()),
      ], eagerError: true);
    } catch (_) {
      // HTTP clients observe connection failure and own their retry policy.
    } finally {
      tunnel.connections.remove(socket);
      socket.destroy();
      channel?.destroy();
    }
  }

  Future<void> _drop(String sourceId, _NasTunnel tunnel) => _serial(() async {
    if (identical(_tunnels[sourceId], tunnel)) await _close(sourceId);
  });

  Future<void> closeSource(String sourceId) => _serial(() => _close(sourceId));

  Future<void> _close(String sourceId) async {
    final tunnel = _tunnels.remove(sourceId);
    if (tunnel == null) return;
    tunnel.closed = true;
    for (final entry in tunnel.connections.entries.toList()) {
      entry.key.destroy();
      entry.value?.destroy();
    }
    tunnel.connections.clear();
    await tunnel.server.close();
  }

  Future<void> dispose() {
    _disposed = true;
    return _serial(() async {
      for (final id in _tunnels.keys.toList()) {
        await _close(id);
      }
    });
  }
}

class _NasTunnel {
  final ServerSocket server;
  final SSHClient client;
  final Uri remote;
  final Map<Socket, SSHForwardChannel?> connections = {};
  bool closed = false;
  _NasTunnel(this.server, this.client, this.remote);
}
