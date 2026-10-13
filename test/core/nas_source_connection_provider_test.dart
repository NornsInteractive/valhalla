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
import 'package:valhalla/data/models/server_profile.dart';
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

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [
    ServerProfile(
      id: 'source-server',
      name: 'Source server',
      host: 'source-before.invalid',
      username: 'fixture',
    ),
    ServerProfile(
      id: 'other-server',
      name: 'Other server',
      host: 'unrelated.invalid',
      username: 'fixture',
    ),
  ];

  void changeSourceTarget() {
    state = [
      for (final server in state)
        if (server.id == 'source-server')
          server.copyWith(host: 'source-after.invalid', username: 'replacement')
        else
          server,
    ];
  }
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
  late NasSource otherSource;
  late _Executor executor;
  late _Connection connection;
  Completer<void>? requestStarted;
  Completer<void>? releaseResponse;

  setUp(() async {
    requestStarted = null;
    releaseResponse = null;
    remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    remote.listen((request) async {
      await request.drain<void>();
      final started = requestStarted;
      final release = releaseResponse;
      if (started != null && !started.isCompleted) started.complete();
      if (release != null) await release.future;
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
    otherSource = NasSource(
      id: 'other-source',
      name: 'Other source',
      type: NasSourceType.webdav,
      sshServerId: 'other-server',
      endpoint: 'http://127.0.0.1:${remote.port}/library/',
    );
    SharedPreferences.setMockInitialValues({
      'valhalla_nas_sources_v1': jsonEncode([
        source.toJson(),
        otherSource.toJson(),
      ]),
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
        serverListProvider.overrideWith(_Servers.new),
      ],
    );
    connection =
        container.read(serverConnectionProvider.notifier) as _Connection;
  });
  tearDown(() async {
    final release = releaseResponse;
    if (release != null && !release.isCompleted) release.complete();
    container.dispose();
    for (final client in executor.clients.values) {
      client.end();
    }
    await remote.close(force: true);
  });

  test(
    'editing the same SSH ID invalidates only that target diagnostic',
    () async {
      executor.clients['source-server'] = _Client();
      executor.clients['other-server'] = _Client();
      final notifier = container.read(nasSourcesProvider.notifier);
      await notifier.probeSaved(source);
      await notifier.probe(otherSource, const NasCredentials());
      final before = container.read(nasSourcesProvider);
      expect(before.diagnosticFor(source)?.stage, NasConnectionStage.ready);
      final unrelated = before.diagnosticFor(otherSource);
      expect(unrelated?.stage, NasConnectionStage.ready);
      final originalTarget = container
          .read(serverListProvider)
          .first
          .connectionKey;

      (container.read(serverListProvider.notifier) as _Servers)
          .changeSourceTarget();
      await container.pump();

      expect(
        container.read(serverListProvider).first.connectionKey,
        isNot(originalTarget),
      );
      final after = container.read(nasSourcesProvider);
      expect(after.diagnosticFor(source), isNull);
      expect(after.diagnosticFor(otherSource), same(unrelated));
      expect(
        after.sources.map((value) => value.toJson()).toList(),
        before.sources.map((value) => value.toJson()).toList(),
      );
      expect(after.selectedId, before.selectedId);
    },
  );

  test(
    'a pending probe cannot publish success after its SSH target changes',
    () async {
      executor.clients['source-server'] = _Client();
      requestStarted = Completer<void>();
      releaseResponse = Completer<void>();
      final notifier = container.read(nasSourcesProvider.notifier);
      final probe = notifier.probeSaved(source);
      await requestStarted!.future.timeout(const Duration(seconds: 5));
      expect(
        container.read(nasSourcesProvider).diagnosticFor(source)?.stage,
        NasConnectionStage.checking,
      );
      final publishedAfterChange = <NasConnectionStage>[];
      final subscription = container.listen(nasSourcesProvider, (_, next) {
        final diagnostic = next.diagnosticFor(source);
        if (diagnostic != null) publishedAfterChange.add(diagnostic.stage);
      });
      addTearDown(subscription.close);

      (container.read(serverListProvider.notifier) as _Servers)
          .changeSourceTarget();
      await container.pump();
      releaseResponse!.complete();
      await probe.timeout(const Duration(seconds: 5));
      await container.pump();

      expect(publishedAfterChange, isNot(contains(NasConnectionStage.ready)));
      expect(container.read(nasSourcesProvider).diagnosticFor(source), isNull);
      expect(container.read(nasSourcesProvider).selectedId, source.id);
      expect(container.read(nasSourcesProvider).sources, hasLength(2));
    },
  );

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
