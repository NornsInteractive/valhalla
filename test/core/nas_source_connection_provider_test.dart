import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/infrastructure_providers.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

class _Connection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(activeServerId: 'other-server');
  void update(ConnectionStateEnum status) => state = ServerConnectionState(
    activeServerId: 'other-server',
    status: status,
  );
}

class _SecureStorage extends SecureStorageService {
  @override
  Future<NasCredentials> getNasCredentials(String id) async =>
      const NasCredentials();
}

class _Executor extends Fake implements SshCommandExecutor {
  final clients = <String, _Client>{};
  @override
  SSHClient? getClient(String serverId) => clients[serverId];
}

class _Client extends Fake implements SSHClient {
  final ended = Completer<void>();
  final channels = <_Channel>[];
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
    if (isClosed) throw StateError('closed fixture client');
    final channel = _Channel(await Socket.connect(host, port));
    channels.add(channel);
    return channel;
  }

  void end() {
    if (!ended.isCompleted) ended.complete();
    for (final channel in channels) {
      channel.destroy();
    }
  }
}

class _Channel extends Fake implements SSHForwardChannel {
  final Socket socket;
  _Channel(this.socket);
  @override
  Stream<Uint8List> get stream => socket;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  void destroy() => socket.destroy();
}

Future<List<NasMediaItem>> _scan(NasSourceAdapter adapter) => adapter
    .scan(const NasScanConfig(includePaths: ['/']), NasCancellation())
    .expand((items) => items)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer remote;
  late ProviderContainer container;
  late NasSource source;
  late _Executor executor;
  late _Connection connection;

  setUp(() async {
    remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    remote.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 207;
      request.response.headers.contentType = ContentType('application', 'xml');
      request.response.write('''<d:multistatus xmlns:d="DAV:"><d:response>
<d:href>/library/test.png</d:href><d:propstat><d:prop>
<d:resourcetype/><d:getcontentlength>3</d:getcontentlength>
<d:getcontenttype>image/png</d:getcontenttype>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response></d:multistatus>''');
      await request.response.close();
    });
    source = NasSource(
      id: 'saved-source',
      name: 'Saved source',
      type: NasSourceType.webdav,
      sshServerId: 'source-server',
      endpoint: 'http://127.0.0.1:${remote.port}/library/',
    );
    SharedPreferences.setMockInitialValues({
      'valhalla_nas_sources_v1': jsonEncode([source.toJson()]),
    });
    executor = _Executor();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          await LocalStorageService.init(),
        ),
        secureStorageServiceProvider.overrideWithValue(_SecureStorage()),
        sshCommandExecutorProvider.overrideWithValue(executor),
        serverConnectionProvider.overrideWith(_Connection.new),
      ],
    );
    connection =
        container.read(serverConnectionProvider.notifier) as _Connection;
  });
  tearDown(() async {
    container.dispose();
    for (final client in executor.clients.values) {
      client.end();
    }
    await remote.close(force: true);
  });

  test(
    'startup failure recovers after SSH connects without resaving source',
    () async {
      await expectLater(
        container.read(nasSourceAdapterProvider(source.id).future),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'NAS_SSH_NOT_CONNECTED',
          ),
        ),
      );
      executor.clients['source-server'] = _Client();
      connection.update(ConnectionStateEnum.connected);
      // Probe uses a temporary adapter, unlike scans/downloads using the cache.
      await container
          .read(nasSourcesProvider.notifier)
          .probe(source, const NasCredentials());
      final adapter = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      expect((await _scan(adapter)).single.name, 'test.png');
    },
  );

  test(
    'same source reconnect replaces its closed tunnel on a different active server',
    () async {
      final first = _Client();
      executor.clients['source-server'] = first;
      connection.update(ConnectionStateEnum.connected);
      final previous = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      expect((await _scan(previous)).length, 1);
      final oldEndpoint = Uri.parse(previous.source.endpoint);
      first.end();
      executor.clients.remove('source-server');
      connection.update(ConnectionStateEnum.disconnected);
      executor.clients['source-server'] = _Client();
      connection.update(ConnectionStateEnum.connected);
      final current = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      expect(current, isNot(same(previous)));
      expect((await _scan(current)).single.name, 'test.png');
      await expectLater(
        Socket.connect(oldEndpoint.host, oldEndpoint.port),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test(
    'unrelated connection updates preserve the source-captured tunnel',
    () async {
      final chosen = _Client();
      executor.clients['source-server'] = chosen;
      final original = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      executor.clients['other-server'] = _Client();
      connection.update(ConnectionStateEnum.connected);
      final current = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      expect(current, same(original));
      expect((await _scan(current)).single.name, 'test.png');
      expect(chosen.channels, isNotEmpty);
      expect(executor.clients['other-server']!.channels, isEmpty);
    },
  );

  test(
    'same-ID client replacement disposes the previous live tunnel',
    () async {
      final first = _Client();
      addTearDown(first.end);
      executor.clients['source-server'] = first;
      connection.update(ConnectionStateEnum.connected);
      final previous = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      final endpoint = Uri.parse(previous.source.endpoint);
      executor.clients['source-server'] = _Client();
      // The state may remain connected, but the transport identity has changed.
      connection.update(ConnectionStateEnum.connected);
      final current = await container.read(
        nasSourceAdapterProvider(source.id).future,
      );
      expect(current, isNot(same(previous)));
      expect((await _scan(current)).single.name, 'test.png');
      expect(first.isClosed, false);
      await expectLater(
        Socket.connect(endpoint.host, endpoint.port),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
