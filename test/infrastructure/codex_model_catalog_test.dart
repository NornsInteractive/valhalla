import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/codex_native_client.dart';

import '../support/fake_acp_transport.dart';

/// `model/list` is the only discovery channel in this slice. These checks pin
/// the read-only RPC surface and the paging/filtering contract of the
/// independent query, without touching any thread.
void main() {
  /// Answers `model/list` from [pages] keyed by request cursor (null = page 1).
  void serveModelList(
    FakeAcpPair pair,
    Map<String?, Map<String, Object?>> pages,
  ) {
    pair.agent.onReceive = (wire) {
      for (final message in TransportFrame.decode(wire).messages) {
        if (message is! RpcRequest) continue;
        final params = message.params;
        final cursor = params is Map ? params['cursor'] as String? : null;
        final page = pages[cursor];
        pair.agent.send(
          TransportFrame.single(
            page == null
                ? RpcResponse(
                    id: message.id,
                    error: RpcError(
                      code: -32601,
                      message: 'unexpected model/list cursor $cursor',
                    ),
                  )
                : RpcResponse(id: message.id, result: page),
          ),
        );
      }
    };
  }

  List<Map<String, Object?>> requestsOf(FakeAcpPair pair, String method) => pair
      .sentToAgent
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .where((frame) => frame['method'] == method)
      .toList();

  /// Every request method the client issued, in order.
  List<String> sentMethods(FakeAcpPair pair) => pair.sentToAgent
      .map((line) => (jsonDecode(line) as Map<String, Object?>)['method'])
      .whereType<String>()
      .toList();

  group('Codex model/list 独立查询', () {
    test('翻完所有游标页，且只发只读 RPC', () async {
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex', 'displayName': 'GPT-5 Codex'},
            {'id': 'gpt-5-codex-mini'},
          ],
          'nextCursor': 'page-2',
        },
        'page-2': {
          'data': [
            {'id': 'gpt-5-codex-mini', 'displayName': '重复项'},
            {'model': 'gpt-4.1', 'name': 'GPT-4.1'},
          ],
          'nextCursor': 'page-3',
        },
        'page-3': {
          'data': [
            {'slug': 'o3'},
            {'id': 'hidden-model', 'hidden': true},
            'not-an-object',
            {'name': 'missing id'},
            {'id': ''},
          ],
        },
      });
      addTearDown(pair.close);

      final client = CodexNativeClient(Connection(pair.client));
      final capabilities = await client.capabilities();

      expect(
        capabilities.models.map((option) => option.id),
        ['gpt-5-codex', 'gpt-5-codex-mini', 'gpt-4.1', 'o3'],
        reason: '必须跨页去重，并跳过 hidden/缺 id/非对象行',
      );
      expect(capabilities.models.first.label, 'GPT-5 Codex');
      expect(capabilities.models[1].label, 'gpt-5-codex-mini');
      expect(capabilities.supportsStructuredSettings, isTrue);

      expect(sentMethods(pair), ['model/list', 'model/list', 'model/list']);
      final calls = requestsOf(pair, 'model/list');
      expect(calls.first['params'], {'limit': 100, 'includeHidden': false});
      expect(calls[1]['params'], {
        'limit': 100,
        'includeHidden': false,
        'cursor': 'page-2',
      });
      expect(calls.last['params'], {
        'limit': 100,
        'includeHidden': false,
        'cursor': 'page-3',
      });
      expect(
        sentMethods(pair).where(
          (method) =>
              method.startsWith('thread/') ||
              method.startsWith('turn/') ||
              method.startsWith('skills/'),
        ),
        isEmpty,
        reason: '独立模型查询绝不建线程、不读历史、不发指令',
      );
      await client.close();
    });

    test('推理等级来自 model/list，不冒充 thought_level', () async {
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {
              'id': 'gpt-5-codex',
              'supportedReasoningEfforts': [
                'low',
                {'reasoningEffort': 'high'},
                {'effort': 'high'},
                '',
              ],
            },
          ],
        },
      });
      addTearDown(pair.close);

      final client = CodexNativeClient(Connection(pair.client));
      final capabilities = await client.capabilities();

      expect(
        capabilities.reasoningLevels.map((option) => option.id),
        ['low', 'high'],
        reason: '推理等级按值去重，空值丢弃',
      );
      expect(capabilities.modes, isEmpty);
      await client.close();
    });

    test('data 不是数组时报协议格式错误', () async {
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': {'id': 'gpt-5-codex'},
        },
      });
      addTearDown(pair.close);

      final client = CodexNativeClient(Connection(pair.client));

      await expectLater(
        client.capabilities(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'MODEL_LIST_INVALID_RESPONSE',
          ),
        ),
      );
      await client.close();
    });

    test('重复游标立即中止，避免把同一页读成死循环', () async {
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
          'nextCursor': 'page-2',
        },
        'page-2': {
          'data': [
            {'id': 'gpt-4.1'},
          ],
          'nextCursor': 'page-2',
        },
      });
      addTearDown(pair.close);

      final client = CodexNativeClient(Connection(pair.client));

      await expectLater(
        client.capabilities(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'MODEL_LIST_CURSOR_REPEATED',
          ),
        ),
      );
      expect(requestsOf(pair, 'model/list'), hasLength(2));
      await client.close();
    });

    test('握手与查询都不创建线程，握手之后只有 model/list', () async {
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);

      final client = CodexNativeClient(Connection(pair.client));
      await client.initialize();
      await client.capabilities();

      expect(sentMethods(pair), ['initialize', 'initialized', 'model/list']);
      final initialize = requestsOf(pair, 'initialize').single;
      expect(initialize['params'], {
        'clientInfo': {
          'name': 'valhalla',
          'title': 'Valhalla',
          'version': '1.0.0',
        },
      });
      await client.close();
    });
  });

  group('queryCapabilities：短生命周期官方 app-server', () {
    AgentProfile hostProfile() => AgentProfile(
      id: 'builtin-codex',
      serverId: 'srv-1',
      name: 'codex',
      description: 'codex',
      cliCommand: '/usr/local/bin/codex',
    );

    test('走同一执行目标与用户，查询完必定关闭进程', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);
      // CodexSshTransport 需要真实 SSH 会话，这里把记忆对接到它的 stdin/stdout。
      session.attach(pair);

      final capabilities = await CodexNativeClient.queryCapabilities(
        client,
        hostProfile(),
      );

      final command = client.commands.single;
      expect(
        command,
        startsWith('bash -l -c '),
        reason: 'host 目标必须与 ACP 通道同一执行位置与登录 shell',
      );
      expect(command, contains("'/usr/local/bin/codex'"));
      expect(command, contains('app-server'));
      expect(command, isNot(contains('session')), reason: '不得附带会话参数');
      expect(capabilities.models.map((option) => option.id), ['gpt-5-codex']);
      expect(session.requestMethods, [
        'initialize',
        'initialized',
        'model/list',
      ], reason: '只读查询不得触碰 thread/* 与 turn/*');
      expect(session.closeCount, 1, reason: '查询结束必须关闭短生命周期进程');
    });

    test('容器目标使用同一容器、用户与绑定方式', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);
      session.attach(pair);

      await CodexNativeClient.queryCapabilities(
        client,
        AgentProfile(
          id: 'builtin-codex',
          serverId: 'srv-1',
          name: 'codex',
          description: 'codex',
          cliCommand: 'codex',
          executionTarget: 'docker',
          containerBinding: 'name',
          containerReference: 'val-codex',
          containerUser: 'codex',
        ),
      );

      final command = client.commands.single;
      expect(
        command,
        startsWith(
          'docker exec -i --user \'codex\' \'val-codex\' /bin/sh -lc ',
        ),
        reason: '容器目标必须沿用同一容器引用与执行用户',
      );
      expect(command, contains('app-server'));
      expect(command, contains('codex'));
      expect(command, contains('/bin/bash'), reason: '优先使用 bash 以保留 PATH');
      expect(session.closeCount, 1);
    });

    testWidgets('SSH 通道迟到时被关闭，且保留原始 TimeoutException', (tester) async {
      // The binding owns a fake clock, so the production 15s execute timeout is
      // elapsed instantly and no real process is involved.
      final late = _FakeSshSession();
      final channel = Completer<SSHSession>();
      final client = _RecordingSshClient(late)..completer = channel;

      Object? captured;
      bool succeeded = false;
      CodexNativeClient.queryCapabilities(client, hostProfile()).then<void>(
        (_) => succeeded = true,
        // Swallow so the assertion below is the single failure site.
        onError: (Object error) => captured = error,
      );
      await tester.pump();
      expect(succeeded, isFalse, reason: '超时前不得成功');
      expect(client.commands, hasLength(1), reason: '命令必须已发出');
      expect(captured, isNull, reason: '超时前不得失败');

      // Elapse past the production 15s execute timeout.
      await tester.pump(const Duration(seconds: 16));
      expect(captured, isA<TimeoutException>());
      expect(late.closeCount, 0, reason: '通道还没到，不能凭空关闭');

      // The channel finally arrives and must be dropped, never initialized.
      channel.complete(late);
      await tester.pump();
      expect(late.closeCount, 1, reason: '迟到的通道必须被关闭，不能泄漏进程');
      expect(late.stdinLines, isEmpty, reason: '迟到通道绝不能被 initialize');
      expect(late.requestMethods, isEmpty);
      expect(late.stdoutLines, isEmpty);
    });

    test('查询失败也必须关闭进程，且不吞掉错误', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      pair.agent.onReceive = (wire) {
        for (final message in TransportFrame.decode(wire).messages) {
          if (message is! RpcRequest) continue;
          pair.agent.send(
            TransportFrame.single(
              RpcResponse(
                id: message.id,
                error: RpcError(
                  code: -32000,
                  message: 'model list unavailable',
                ),
              ),
            ),
          );
        }
      };
      addTearDown(pair.close);
      session.attach(pair);

      await expectLater(
        CodexNativeClient.queryCapabilities(client, hostProfile()),
        throwsA(
          isA<RpcError>().having(
            (error) => error.message,
            'message',
            'model list unavailable',
          ),
        ),
      );
      expect(session.closeCount, 1, reason: '失败路径同样必须关闭进程');
    });
  });

  /// The DEFAULT `agentModelQueryProvider` (never overridden) must be the CLI
  /// app-server path. These checks read the real provider out of a bare
  /// container so a regression to HTTP/OAuth discovery cannot hide behind an
  /// `overrideWithValue`.
  group('默认 agentModelQueryProvider：只走 CLI app-server', () {
    AgentProfile host() => AgentProfile(
      id: 'builtin-codex',
      serverId: 'srv-1',
      name: 'codex',
      description: 'codex',
      cliCommand: '/usr/local/bin/codex',
    );

    AgentProfile docker() => AgentProfile(
      id: 'builtin-codex',
      serverId: 'srv-1',
      name: 'codex',
      description: 'codex',
      cliCommand: 'codex',
      executionTarget: 'docker',
      containerBinding: 'name',
      containerReference: 'val-codex',
      containerUser: 'codex',
    );

    AgentProfile agy() => AgentProfile(
      id: 'builtin-agy',
      serverId: 'srv-1',
      name: 'agy',
      description: 'agy',
      cliCommand: 'agy',
      acpCommand: 'agy-acp --stdio',
    );

    /// Reads the shipped default: no `agentModelQueryProvider` override.
    ///
    /// The container only exists to resolve the provider value, which captures
    /// nothing from it, so it is disposed before the query runs.
    AgentModelQuery defaultQuery() {
      final container = ProviderContainer();
      try {
        return container.read(agentModelQueryProvider);
      } finally {
        container.dispose();
      }
    }

    test('Codex 目标真的发起 CLI initialize/initialized/model/list', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);
      session.attach(pair);

      final capabilities = await defaultQuery()(host(), client);

      expect(capabilities, isNotNull, reason: '默认实现不得把 Codex 判成不支持');
      expect(capabilities!.models.map((option) => option.id), ['gpt-5-codex']);
      expect(client.commands, hasLength(1), reason: '一次查询只开一个短生命周期进程');
      final command = client.commands.single;
      expect(command, startsWith('bash -l -c '), reason: 'host 目标用登录 shell');
      expect(command, contains("'/usr/local/bin/codex'"));
      expect(command, contains('app-server'));
      expect(session.requestMethods, [
        'initialize',
        'initialized',
        'model/list',
      ], reason: '默认路径只允许这三条只读 RPC');
      expect(session.closeCount, 1, reason: '查询完必须关闭进程');
    });

    test('绝不走 HTTP/OAuth/历史/指令', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);
      session.attach(pair);

      await defaultQuery()(host(), client);

      final command = client.commands.single.toLowerCase();
      for (final marker in [
        'curl',
        'wget',
        'https://',
        'http://',
        'api.openai.com',
        'oauth',
        'authorize',
        'authorization',
        'token',
        'model_authorization',
        'open_browser',
      ]) {
        expect(
          command,
          isNot(contains(marker)),
          reason: '默认目录查询不得派生 HTTP/OAuth 授权通道：$marker',
        );
      }
      final methods = session.requestMethods;
      expect(methods, isNot(contains('session/prompt')), reason: '绝不发指令');
      for (final prefix in [
        'thread/',
        'turn/',
        'session/',
        'composer',
        'skills/',
      ]) {
        expect(
          methods.where((method) => method.startsWith(prefix)),
          isEmpty,
          reason: '绝不读历史、建会话或发指令：$prefix',
        );
      }
      expect(
        methods.where((method) => method.startsWith('response/')),
        isEmpty,
        reason: '绝不做浏览器回环 OAuth 之类的 response 收取',
      );
    });

    test('容器目标沿用同一容器与执行用户', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
          ],
        },
      });
      addTearDown(pair.close);
      session.attach(pair);

      final capabilities = await defaultQuery()(docker(), client);

      expect(capabilities!.models.single.id, 'gpt-5-codex');
      final command = client.commands.single;
      expect(
        command,
        startsWith("docker exec -i --user 'codex' 'val-codex' /bin/sh -lc "),
        reason: '容器目标必须沿用同一容器引用与执行用户',
      );
      expect(command, contains('app-server'));
      expect(session.closeCount, 1);
    });

    test('非 Codex CLI 在触碰 SSH 前直接返回 null', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);

      expect(await defaultQuery()(agy(), client), isNull);
      expect(client.commands, isEmpty, reason: '不得为不支持的 CLI 开通道');
      expect(session.requestMethods, isEmpty);
      expect(session.closeCount, 0);
    });

    test('翻完游标页后关闭进程', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      serveModelList(pair, {
        null: {
          'data': [
            {'id': 'gpt-5-codex'},
            {'id': 'gpt-5-codex-mini'},
          ],
          'nextCursor': 'page-2',
        },
        'page-2': {
          'data': [
            {'id': 'gpt-5-codex-mini', 'displayName': '重复项'},
            {'id': 'o3'},
          ],
        },
      });
      addTearDown(pair.close);
      session.attach(pair);

      final capabilities = await defaultQuery()(host(), client);

      expect(capabilities!.models.map((option) => option.id), [
        'gpt-5-codex',
        'gpt-5-codex-mini',
        'o3',
      ]);
      expect(session.requestMethods, [
        'initialize',
        'initialized',
        'model/list',
        'model/list',
      ]);
      expect(
        session.requestParams[2]['cursor'],
        isNull,
        reason: '第一页不带 cursor',
      );
      expect(
        session.requestParams[3]['cursor'],
        'page-2',
        reason: '默认 provider 必须把上一页的 nextCursor 传下去',
      );
      expect(session.closeCount, 1, reason: '翻页结束必须关闭进程');
    });

    test('查询失败仍关闭进程且不吞掉错误', () async {
      final session = _FakeSshSession();
      final client = _RecordingSshClient(session);
      final pair = FakeAcpPair();
      pair.agent.onReceive = (wire) {
        for (final message in TransportFrame.decode(wire).messages) {
          if (message is! RpcRequest) continue;
          pair.agent.send(
            TransportFrame.single(
              RpcResponse(
                id: message.id,
                error: RpcError(
                  code: -32000,
                  message: 'model list unavailable',
                ),
              ),
            ),
          );
        }
      };
      addTearDown(pair.close);
      session.attach(pair);

      await expectLater(
        defaultQuery()(host(), client),
        throwsA(isA<RpcError>()),
      );
      expect(session.closeCount, 1, reason: '失败路径同样必须关闭进程');
    });
  });
}

/// A stand-in for the SSH exec channel the Codex app-server runs in.
///
/// Only the members [CodexSshTransport] touches are implemented; everything
/// else is intentionally unsupported so a test cannot silently depend on it.
class _FakeSshSession implements SSHSession {
  // Broadcast so a listener can be installed after the process is created, and
  // so close() never waits on a controller nobody subscribed to.
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = StreamController<Uint8List>.broadcast();
  int closeCount = 0;

  /// Raw JSON lines the process wrote to stdout, in order.
  final List<String> stdoutLines = [];

  /// Every line the client wrote to stdin, in order (framing-free).
  final List<String> stdinLines = [];

  /// Request methods the client wrote to stdin, in order.
  final List<String> requestMethods = [];

  /// `params` of each recorded line, in the same order (notifications are `{}`).
  final List<Map<String, Object?>> requestParams = [];

  _FakeSshSession() {
    _stdin.stream.listen((bytes) {
      final line = utf8.decode(bytes).trim();
      if (line.isEmpty) return;
      stdinLines.add(line);
      final decoded = jsonDecode(line);
      if (decoded is Map && decoded['method'] is String) {
        requestMethods.add(decoded['method'] as String);
        final params = decoded['params'];
        requestParams.add(
          params is Map ? Map<String, Object?>.from(params) : const {},
        );
      }
    });
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  int? get exitCode => null;

  /// Connects this fake channel to an in-memory ACP pair.
  void attach(FakeAcpPair pair) {
    // Agent answers travel back through the transport's stdout, not through the
    // memory pair's own stream, so the Codex framing path stays honest.
    final bridge = FakeMemoryTransport()
      ..onReceive = _pushStdout
      ..peer = pair.agent;
    pair.agent.peer = bridge;
    _stdin.stream.listen((bytes) {
      final line = utf8.decode(bytes).trim();
      if (line.isEmpty) return;
      // Codex omits the version header; decode through its own codec so the
      // agent side sees a well-formed frame.
      pair.agent.deliver(CodexSshTransport.decode(line).toWire());
    });
  }

  void _pushStdout(String wire) {
    stdoutLines.add(wire);
    if (_stdout.isClosed) return;
    _stdout.add(Uint8List.fromList(utf8.encode('$wire\n')));
  }

  @override
  Future<void> close() async {
    closeCount++;
    if (!_stdout.isClosed) await _stdout.close();
    if (!_stderr.isClosed) await _stderr.close();
    if (!_stdin.isClosed) await _stdin.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// SSH client stub that records the command it was asked to execute.
///
/// Assigning [completer] defers channel delivery so a fake clock can expire the
/// query timeout first.
class _RecordingSshClient implements SSHClient {
  _RecordingSshClient(this.session);

  final SSHSession session;
  final List<String> commands = [];
  Completer<SSHSession>? completer;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    final pending = completer;
    if (pending != null) return pending.future;
    return Future<SSHSession>.value(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
