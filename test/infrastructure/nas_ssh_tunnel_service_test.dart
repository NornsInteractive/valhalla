import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/infrastructure/nas/nas_ssh_tunnel_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Executor extends Fake implements SshCommandExecutor {
  final Map<String, _Client> clients;
  _Executor(this.clients);
  @override
  SSHClient? getClient(String serverId) => clients[serverId];
}

class _Client extends Fake implements SSHClient {
  final ended = Completer<void>();
  final List<(String, int)> targets = [];
  final List<_Channel> channels = [];
  @override
  bool get isClosed => ended.isCompleted;
  @override
  Future<void> get done => ended.future;
  @override
  Future<SSHForwardChannel> forwardLocal(
    String host,
    int port, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async {
    targets.add((host, port));
    final channel = _Channel(await Socket.connect(host, port));
    channels.add(channel);
    return channel;
  }
}

class _Channel extends Fake implements SSHForwardChannel {
  final Socket socket;
  bool destroyed = false;
  _Channel(this.socket);
  @override
  Stream<Uint8List> get stream => socket;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  void destroy() {
    destroyed = true;
    socket.destroy();
  }
}

NasSource _source(
  int port, {
  String id = 'source-one',
  String ssh = 'ssh-one',
  String scheme = 'http',
}) => NasSource(
  id: id,
  name: 'Test',
  type: NasSourceType.webdav,
  sshServerId: ssh,
  endpoint: '$scheme://127.0.0.1:$port/library/base/',
);

void main() {
  test(
    'forwards real HTTP bytes with source-captured SSH client, range and base path',
    () async {
      final remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => remote.close(force: true));
      final requested = Completer<HttpRequest>();
      remote.listen((request) async {
        requested.complete(request);
        request.response.statusCode = 206;
        request.response.headers.set('Content-Range', 'bytes 2-4/6');
        request.response.write('cde');
        await request.response.close();
      });
      final chosen = _Client();
      final other = _Client();
      final service = NasSshTunnelService(
        _Executor({'ssh-one': chosen, 'ssh-other': other}),
      );
      addTearDown(service.dispose);
      final source = _source(remote.port);
      final forwarded = await service.forward(source);
      expect(forwarded.path, '/library/base/');
      expect(forwarded.host, '127.0.0.1');
      expect(await service.forward(source), forwarded);
      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final request = await http.getUrl(forwarded.resolve('song.mp3'));
      request.headers.set('Range', 'bytes=2-4');
      final response = await request.close();
      expect(await response.transform(utf8.decoder).join(), 'cde');
      expect(response.statusCode, 206);
      expect((await requested.future).uri.path, '/library/base/song.mp3');
      expect(chosen.targets, [('127.0.0.1', remote.port)]);
      expect(other.targets, isEmpty);
      await service.closeSource(source.id);
      expect(chosen.channels.single.destroyed, true);
    },
  );

  test(
    'disconnect closes listeners, source changes replace them, HTTPS is rejected',
    () async {
      final client = _Client();
      final executor = _Executor({'ssh-one': client});
      final service = NasSshTunnelService(executor);
      addTearDown(service.dispose);
      final first = await service.forward(_source(8096));
      final second = await service.forward(_source(8097));
      expect(first.port, isNot(second.port));
      await expectLater(
        Socket.connect(first.host, first.port),
        throwsA(isA<SocketException>()),
      );
      await expectLater(
        service.forward(_source(8096, scheme: 'https')),
        throwsStateError,
      );
      client.ended.complete();
      // A queued close runs after the SSH done callback and gives it a join point.
      await Future<void>.delayed(Duration.zero);
      await service.closeSource('source-one');
      await expectLater(
        Socket.connect(second.host, second.port),
        throwsA(isA<SocketException>()),
      );
      await expectLater(service.forward(_source(8096)), throwsStateError);
    },
  );
}
