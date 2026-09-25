import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../core/utils/shell_quote.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../data/models/native_cli_session.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/chat_run_settings.dart';
import '../ssh/ssh_client_manager.dart';
import 'agent_execution_target.dart';

/// Official loopback server, reached only through dartssh2 TCP forwarding.
class OpenCodeNativeClient {
  final HttpClient _http = HttpClient();
  final SSHSession _process;
  final ServerSocket _listener;
  final String _authorization;
  final String _remoteHost;
  final Set<Socket> _sockets = {};
  final Set<SSHForwardChannel> _channels = {};
  final List<StreamSubscription<dynamic>> _subscriptions;
  bool _closed = false;
  bool get isClosed => _closed;
  Map<String, dynamic> _paths = {};
  OpenCodeNativeClient._(
    this._process,
    this._listener,
    String password,
    this._subscriptions,
    this._remoteHost,
  ) : _authorization =
          'Basic ${base64Encode(utf8.encode('opencode:$password'))}';

  static Future<OpenCodeNativeClient> connect(
    SSHClient ssh, {
    String command = 'opencode',
    AgentProfile? profile,
    SshCommandExecutor? executor,
    String? serverId,
  }) async {
    final random = Random.secure();
    final password = base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final container = profile?.executionTarget == 'docker';
    var remoteHost = '127.0.0.1';
    if (container) {
      if (executor == null || serverId == null) {
        throw StateError('CLI_CONTAINER_NETWORK_UNSUPPORTED');
      }
      final reference = cliShellQuote(profile!.containerReference!);
      final inspect = await executor.executeWithLoginShell(
        serverId,
        'docker inspect --format ${cliShellQuote('{{json .NetworkSettings}}')} $reference',
      );
      if (!inspect.isSuccess) throw StateError('AGENT_CONTAINER_NOT_FOUND');
      final settings =
          jsonDecode(inspect.stdout.trim()) as Map<String, dynamic>;
      final networks = settings['Networks'] as Map?;
      final addresses = networks?.values
          .whereType<Map>()
          .map((network) => network['IPAddress']?.toString() ?? '')
          .where((ip) => ip.isNotEmpty);
      if (addresses != null && addresses.isNotEmpty) {
        remoteHost = addresses.first;
      } else if (settings['IPAddress']?.toString().isNotEmpty == true) {
        remoteHost = settings['IPAddress'].toString();
      } else {
        // Host networking has no container IP; it shares host loopback.
        final mode = await executor.executeWithLoginShell(
          serverId,
          'docker inspect --format ${cliShellQuote('{{.HostConfig.NetworkMode}}')} $reference',
        );
        if (mode.stdout.trim() != 'host') {
          throw StateError('CLI_CONTAINER_NETWORK_UNSUPPORTED');
        }
      }
    }
    final script =
        'IFS= read -r OPENCODE_SERVER_PASSWORD; export OPENCODE_SERVER_PASSWORD; exec ${cliShellQuote(command)} serve --hostname ${container && remoteHost != '127.0.0.1' ? '0.0.0.0' : '127.0.0.1'} --port 0';
    final process = await ssh.execute(
      container
          ? agentTargetCommand(profile!, script)
          : 'bash -l -c ${cliShellQuote(script)}',
    );
    process.stdin.add(utf8.encode('$password\n'));
    final ready = Completer<int>();
    void line(String text) {
      final match = RegExp(r'http://127\.0\.0\.1:(\d+)').firstMatch(text);
      if (match != null && !ready.isCompleted) {
        ready.complete(int.parse(match[1]!));
      }
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      process.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            line,
            onError: (Object e) {
              if (!ready.isCompleted) ready.completeError(e);
            },
            onDone: () {
              if (!ready.isCompleted) {
                ready.completeError(StateError('CLI_SERVER_START_FAILED'));
              }
            },
          ),
      process.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            line,
            onError: (Object e) {
              if (!ready.isCompleted) ready.completeError(e);
            },
          ),
    ];
    ServerSocket? listener;
    OpenCodeNativeClient? client;
    try {
      final port = await ready.future.timeout(const Duration(seconds: 30));
      if (port <= 0 || port > 65535) throw StateError('CLI_INVALID_PORT');
      listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      client = OpenCodeNativeClient._(
        process,
        listener,
        password,
        subscriptions,
        remoteHost,
      );
      listener.listen((socket) => client!._forward(ssh, socket, port));
      final spec = await client.request('GET', '/doc') as Map;
      client._paths = Map<String, dynamic>.from(spec['paths'] as Map);
      if (!client._paths.containsKey('/session') ||
          !client._paths.containsKey('/global/event') ||
          !client._paths.containsKey('/experimental/session')) {
        throw StateError('CLI_VERSION_UNSUPPORTED');
      }
      return client;
    } catch (_) {
      if (client != null) {
        await client.close();
      } else {
        process.close();
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        await listener?.close();
      }
      rethrow;
    }
  }

  Future<void> _forward(SSHClient ssh, Socket socket, int port) async {
    _sockets.add(socket);
    SSHForwardChannel? channel;
    try {
      channel = await ssh.forwardLocal(_remoteHost, port);
      if (_closed) return;
      _channels.add(channel);
      await Future.wait([
        socket.cast<List<int>>().pipe(channel.sink),
        channel.stream.cast<List<int>>().pipe(socket),
      ]);
    } catch (_) {
      // Closing the socket exposes forwarding failure to HttpClient, not success.
      socket.destroy();
    } finally {
      socket.destroy();
      channel?.destroy();
      _sockets.remove(socket);
      _channels.remove(channel);
    }
  }

  Future<HttpClientResponse> _open(
    String method,
    String path, {
    Object? body,
    String? cwd,
    Map<String, String>? query,
  }) async {
    if (_closed) throw StateError('CLI_DISCONNECTED');
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _listener.port,
      path: path,
      queryParameters: {
        ...?query,
        if (cwd != null && cwd.isNotEmpty) 'directory': cwd,
      },
    );
    final request = await _http
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 30));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, _authorization);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw StateError('CLI_HTTP_${response.statusCode}');
    }
    return response;
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    String? cwd,
  }) async {
    final response = await _open(method, path, body: body, cwd: cwd);
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 30));
    return text.trim().isEmpty ? null : jsonDecode(text);
  }

  Stream<Map<String, dynamic>> events() async* {
    final response = await _open('GET', '/global/event');
    final lines = utf8.decoder.bind(response).transform(const LineSplitter());
    var data = <String>[];
    await for (final line in lines) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final envelope = jsonDecode(data.join('\n')) as Map;
          yield Map<String, dynamic>.from(
            (envelope['payload'] ?? envelope) as Map,
          );
          data = [];
        }
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
  }

  Future<NativeCliPage> list({String? cwd, String? cursor}) async {
    final response = await _open(
      'GET',
      '/experimental/session',
      cwd: cwd,
      query: {'limit': '15', 'cursor': ?cursor},
    );
    final next = response.headers.value('x-next-cursor');
    final raw =
        jsonDecode(
              await utf8.decoder
                  .bind(response)
                  .join()
                  .timeout(const Duration(seconds: 30)),
            )
            as List;
    final sessions = raw
        .map((item) => session(Map<String, dynamic>.from(item as Map)))
        .toList();
    sessions.sort(
      (a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return NativeCliPage(
      sessions
          .where((s) => cwd == null || cwd.isEmpty || s.cwd == cwd)
          .toList(),
      cursor: next,
    );
  }

  static NativeCliSession session(Map<String, dynamic> raw) => NativeCliSession(
    id: raw['id'] as String,
    title: (raw['title'] ?? raw['id']).toString(),
    cwd: raw['directory'] as String?,
    updatedAt: raw['time']?['updated'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (raw['time']['updated'] as num).toInt(),
          )
        : null,
  );
  Future<NativeCliMessagePage> readPage(
    String id, {
    String? cwd,
    String? cursor,
    required int limit,
  }) async {
    final response = await _open(
      'GET',
      '/session/${Uri.encodeComponent(id)}/message',
      cwd: cwd,
      query: {'limit': '$limit', 'before': ?cursor},
    );
    final raw =
        jsonDecode(
              await utf8.decoder
                  .bind(response)
                  .join()
                  .timeout(const Duration(seconds: 30)),
            )
            as List;
    if (raw.length > limit) throw StateError('CLI_VERSION_UNSUPPORTED');
    final messages = raw
        .map(
          (message) => NativeCliMessage(
            id: message['info']['id'].toString(),
            role: message['info']['role'].toString(),
            text: (message['parts'] as List)
                .where((p) => p['type'] == 'text')
                .map((p) => p['text'])
                .join('\n'),
          ),
        )
        .toList();
    return NativeCliMessagePage(
      messages,
      olderCursor: raw.length == limit && messages.isNotEmpty
          ? messages.first.id
          : null,
    );
  }

  Future<NativeCliSession> start({String? cwd}) async => session(
    Map<String, dynamic>.from(
      await request('POST', '/session', body: {}, cwd: cwd) as Map,
    ),
  );
  Future<AgentRuntimeCapabilities> capabilities() async {
    if (!_paths.containsKey('/provider')) {
      return const AgentRuntimeCapabilities(supportsStructuredSettings: true);
    }
    final raw = await request('GET', '/provider');
    final models = <ChatSettingOption>[];
    void collect(Object? value) {
      if (value is Map) {
        if ((value['id'] ?? value['modelID']) case final Object id
            when value.containsKey('name') || value.containsKey('modelID')) {
          final provider = value['providerID']?.toString();
          final model = id.toString();
          models.add(
            ChatSettingOption(
              provider == null ? model : '$provider/$model',
              (value['name'] ?? model).toString(),
            ),
          );
        }
        for (final child in value.values) {
          collect(child);
        }
      } else if (value is List) {
        for (final child in value) {
          collect(child);
        }
      }
    }

    collect(raw);
    final unique = <String, ChatSettingOption>{
      for (final model in models) model.id: model,
    };
    return AgentRuntimeCapabilities(
      models: unique.values.toList(),
      supportsStructuredSettings: true,
    );
  }

  Future<void> send(
    String id,
    String text, {
    String? cwd,
    ChatRunSettings settings = const ChatRunSettings(),
  }) async {
    final modelParts = settings.modelId?.split('/');
    await request(
      'POST',
      '/session/${Uri.encodeComponent(id)}/prompt_async',
      body: {
        if (modelParts != null && modelParts.length > 1)
          'model': {
            'providerID': modelParts.first,
            'modelID': modelParts.sublist(1).join('/'),
          },
        'parts': [
          {'type': 'text', 'text': text},
        ],
      },
      cwd: cwd,
    );
  }

  Future<void> interrupt(String id, {String? cwd}) async {
    await request(
      'POST',
      '/session/${Uri.encodeComponent(id)}/abort',
      cwd: cwd,
    );
  }

  Future<void> delete(String id, {String? cwd}) async {
    final status = await request('GET', '/session/status', cwd: cwd) as Map;
    if (status[id]?['type'] == 'busy' || status[id]?['type'] == 'retry') {
      throw StateError('CLI_BUSY');
    }
    final result = await request(
      'DELETE',
      '/session/${Uri.encodeComponent(id)}',
      cwd: cwd,
    );
    if (result != true) throw StateError('CLI_DELETE_FAILED');
  }

  Future<void> approve(
    NativeCliApproval approval,
    bool allow, {
    String? cwd,
  }) async {
    if (_paths.containsKey('/permission/{requestID}/reply')) {
      await request(
        'POST',
        '/permission/${Uri.encodeComponent(approval.id)}/reply',
        body: {'reply': allow ? 'once' : 'reject'},
        cwd: cwd,
      );
    } else {
      final id = approval.details['sessionID'] as String;
      await request(
        'POST',
        '/session/${Uri.encodeComponent(id)}/permissions/${Uri.encodeComponent(approval.id)}',
        body: {'response': allow ? 'once' : 'reject', 'remember': false},
        cwd: cwd,
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _http.close(force: true);
    await _listener.close();
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    for (final channel in _channels.toList()) {
      channel.destroy();
    }
    try {
      _process.kill(SSHSignal.TERM);
    } finally {
      _process.close();
      for (final sub in _subscriptions) {
        await sub.cancel();
      }
    }
  }
}
