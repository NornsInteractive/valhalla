import 'dart:async';
import 'dart:convert';
import 'package:acpd/acpd.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../data/models/native_cli_session.dart';
import '../../data/models/chat_run_settings.dart';
import '../../data/models/agent_composer_item.dart';
import '../../data/models/agent_profile.dart';
import '../../core/utils/shell_quote.dart';
import 'agent_execution_target.dart';

/// Codex omits the JSON-RPC version header. Correlation remains owned by acpd.
class CodexSshTransport implements LineTransport {
  final SSHSession session;
  final _incoming = StreamController<TransportFrame>();
  late final StreamSubscription<String> _stdout;
  late final StreamSubscription<String> _stderr;
  String _stderrTail = '';
  bool _closed = false;
  CodexSshTransport(this.session) {
    _stderr = session.stderr.cast<List<int>>().transform(utf8.decoder).listen((
      text,
    ) {
      _stderrTail = '$_stderrTail$text';
      if (_stderrTail.length > 4096) {
        _stderrTail = _stderrTail.substring(_stderrTail.length - 4096);
      }
    });
    _stdout = session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty || _closed) return;
            try {
              final frame = decodeLine(line);
              if (frame != null) _incoming.add(frame);
            } catch (error, trace) {
              _incoming.addError(error, trace);
            }
          },
          onError: _incoming.addError,
          onDone: () {
            if (!_closed) {
              final detail = _stderrTail.trim().replaceAll(
                RegExp(r'[\r\n]+'),
                ' ',
              );
              _incoming.addError(
                StateError(
                  'CLI_PROCESS_EXITED:${session.exitCode ?? 'unknown'}'
                  '${detail.isEmpty ? '' : ':$detail'}',
                ),
              );
            }
            _incoming.close();
          },
        );
  }

  /// Interactive container shells may print a banner before app-server starts.
  /// Only JSON objects belong to Codex's stdout protocol; other lines are noise.
  static TransportFrame? decodeLine(String line) {
    final value = line.trimLeft();
    if (!value.startsWith('{')) return null;
    return decode(value);
  }

  static TransportFrame decode(String line) {
    final data = jsonDecode(line) as Map<String, dynamic>;
    return TransportFrame.decode(jsonEncode({...data, 'jsonrpc': '2.0'}));
  }

  static String encode(TransportFrame frame) {
    final data = jsonDecode(frame.toWire()) as Map<String, dynamic>;
    data.remove('jsonrpc');
    return '${jsonEncode(data)}\n';
  }

  @override
  Stream<TransportFrame> get incoming => _incoming.stream;
  @override
  void send(TransportFrame frame) {
    if (_closed) throw StateError('CLI_DISCONNECTED');
    session.stdin.add(utf8.encode(encode(frame)));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _stdout.cancel();
    await _stderr.cancel();
    session.close();
    await _incoming.close();
  }
}

class CodexNativeClient {
  final Connection connection;
  CodexNativeClient(this.connection);

  /// Query the official API without starting, reading or resuming any thread.
  /// The process uses the selected agent's host/container and execution user.
  /// A CLI-provided catalog can be cached; this does not verify entitlement.
  static Future<AgentRuntimeCapabilities> queryCapabilities(
    SSHClient ssh,
    AgentProfile profile,
  ) => _query(ssh, profile, (client) => client.capabilities());

  static Future<AgentComposerCatalog> queryComposerCatalog(
    SSHClient ssh,
    AgentProfile profile, {
    String? cwd,
  }) => _query(ssh, profile, (client) => client.composerCatalog(cwd: cwd));

  static Future<T> _query<T>(
    SSHClient ssh,
    AgentProfile profile,
    Future<T> Function(CodexNativeClient) read,
  ) async {
    final script = 'exec ${cliShellQuote(profile.cliCommand)} app-server';
    var openingExpired = false;
    final opening = ssh
        .execute(
          agentTargetCommand(
            profile,
            profile.executionTarget == 'docker'
                ? script
                : 'bash -l -c ${cliShellQuote(script)}',
          ),
        )
        .then((session) {
          // A timed-out SSH channel can still arrive later; do not orphan it.
          if (openingExpired) {
            session.close();
          }
          return session;
        });
    final SSHSession process;
    try {
      process = await opening.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      openingExpired = true;
      rethrow;
    }
    final client = CodexNativeClient(Connection(CodexSshTransport(process)));
    try {
      await client.initialize();
      return await read(client).timeout(const Duration(seconds: 30));
    } finally {
      await client.close();
    }
  }

  Future<Map<String, dynamic>> request(
    String method, [
    Map<String, dynamic>? params,
  ]) => connection.sendRequest(
    method,
    params: params,
    timeout: const Duration(seconds: 30),
    mapResult: (result) => Map<String, dynamic>.from(result as Map),
  );
  Future<void> initialize() async {
    await request('initialize', {
      'clientInfo': {
        'name': 'valhalla',
        'title': 'Valhalla',
        'version': '1.0.0',
      },
    });
    connection.notify('initialized');
  }

  Future<AgentRuntimeCapabilities> capabilities() async {
    final models = <ChatSettingOption>[];
    final efforts = <String, ChatSettingOption>{};
    String? cursor;
    final seenCursors = <String>{};
    final seenModels = <String>{};
    do {
      final response = await request('model/list', {
        'limit': 100,
        'includeHidden': false,
        'cursor': ?cursor,
      });
      if (response['data'] is! List) {
        throw const FormatException('MODEL_LIST_INVALID_RESPONSE');
      }
      for (final raw in response['data'] as List) {
        if (raw is! Map) continue;
        final id = (raw['id'] ?? raw['model'] ?? raw['slug'])?.toString();
        if (id == null ||
            id.isEmpty ||
            raw['hidden'] == true ||
            !seenModels.add(id)) {
          continue;
        }
        models.add(
          ChatSettingOption(
            id,
            (raw['displayName'] ?? raw['name'] ?? id).toString(),
            description: raw['description']?.toString(),
          ),
        );
        final supported =
            raw['supportedReasoningEfforts'] ??
            raw['supported_reasoning_efforts'];
        if (supported is List) {
          for (final effort in supported) {
            final value = effort is Map
                ? (effort['reasoningEffort'] ??
                          effort['effort'] ??
                          effort['id'])
                      ?.toString()
                : effort.toString();
            if (value != null && value.isNotEmpty) {
              efforts[value] = ChatSettingOption(value, value);
            }
          }
        }
      }
      cursor = response['nextCursor'] as String?;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw StateError('MODEL_LIST_CURSOR_REPEATED');
      }
      if (cursor != null && seenCursors.length >= 100) {
        throw StateError('MODEL_LIST_PAGE_LIMIT');
      }
    } while (cursor != null);
    return AgentRuntimeCapabilities(
      models: models,
      reasoningLevels: efforts.values.toList(),
      supportsStructuredSettings: true,
    );
  }

  /// Codex app-server exposes real skill inventory through `skills/list`.
  /// TUI slash commands are deliberately excluded: they are not app-server
  /// requests and inserting them into a turn would be misleading.
  Future<AgentComposerCatalog> composerCatalog({String? cwd}) async {
    final response = await request('skills/list', {
      if (cwd != null && cwd.isNotEmpty) 'cwds': [cwd],
      'forceReload': true,
    });
    final skills = <AgentComposerItem>[];
    final seen = <String>{};
    if (response['data'] is! List) {
      throw const FormatException('AGENT_SKILLS_INVALID_RESPONSE');
    }
    for (final value in response['data'] as List? ?? const []) {
      if (value is! Map) continue;
      final entries = value['skills'] is List
          ? value['skills'] as List
          : [value];
      for (final entry in entries) {
        if (entry is! Map || entry['enabled'] == false) continue;
        final raw = Map<String, dynamic>.from(entry);
        final id = (raw['name'] ?? raw['id'] ?? raw['skill'] ?? '').toString();
        if (id.isEmpty || !seen.add(id)) continue;
        final interface = raw['interface'];
        skills.add(
          AgentComposerItem(
            kind: AgentComposerItemKind.skill,
            id: id,
            label: interface is Map && interface['displayName'] is String
                ? interface['displayName'] as String
                : id,
            insertion: r'$' + id,
            description: raw['description']?.toString(),
          ),
        );
      }
    }
    return AgentComposerCatalog(skills: skills);
  }

  Future<NativeCliPage> list({String? cursor, String? cwd}) async {
    final response = await request('thread/list', {
      'limit': 15,
      'sortKey': 'updated_at',
      'sourceKinds': ['cli', 'vscode', 'exec', 'appServer'],
      'cursor': ?cursor,
      if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    });
    return NativeCliPage(
      (response['data'] as List)
          .map((raw) => session(Map<String, dynamic>.from(raw as Map)))
          .toList(),
      cursor: response['nextCursor'] as String?,
    );
  }

  static NativeCliSession session(Map<String, dynamic> raw) => NativeCliSession(
    id: raw['id'] as String,
    resumeId: raw['sessionId'] as String?,
    title: (raw['name'] ?? raw['preview'] ?? raw['id']).toString(),
    cwd: raw['cwd'] as String?,
    updatedAt: raw['updatedAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (raw['updatedAt'] as num).toInt() * 1000,
          )
        : null,
  );
  Future<NativeCliMessagePage> readPage(
    String id, {
    String? cursor,
    required int limit,
  }) async {
    var nextCursor = cursor;
    var previousCursor = '';
    final visible = <NativeCliMessage>[];
    do {
      Map<String, dynamic> result;
      try {
        result = await request('thread/items/list', {
          'threadId': id,
          'sortDirection': 'desc',
          'limit': limit,
          'cursor': ?nextCursor,
        });
      } catch (error) {
        if (error.toString().contains('-32601')) {
          throw StateError('CLI_VERSION_UNSUPPORTED');
        }
        rethrow;
      }
      final entries = (result['data'] as List? ?? []).reversed;
      final items = entries.map((entry) => (entry as Map)['item']).toList();
      visible.insertAll(
        0,
        messages({
          'turns': [
            {'items': items},
          ],
        }),
      );
      previousCursor = nextCursor ?? '';
      nextCursor = result['nextCursor'] as String?;
    } while (visible.length < limit &&
        nextCursor != null &&
        nextCursor != previousCursor);
    return NativeCliMessagePage(visible, olderCursor: nextCursor);
  }

  static List<NativeCliMessage> messages(Map<String, dynamic> thread) {
    final result = <NativeCliMessage>[];
    for (final turn in thread['turns'] as List? ?? []) {
      for (final item in turn['items'] as List? ?? []) {
        final type = item['type'];
        if (type == 'agentMessage') {
          result.add(
            NativeCliMessage(
              id: item['id'].toString(),
              role: 'assistant',
              text: item['text']?.toString() ?? '',
            ),
          );
        } else if (type == 'userMessage') {
          final text = (item['content'] as List? ?? [])
              .where((p) => p['type'] == 'text')
              .map((p) => p['text'])
              .join('\n');
          result.add(
            NativeCliMessage(
              id: item['id'].toString(),
              role: 'user',
              text: text,
            ),
          );
        }
      }
    }
    return result;
  }

  Future<NativeCliSession> start({String? cwd}) async {
    final result = await request('thread/start', {
      if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    });
    return session(Map<String, dynamic>.from(result['thread'] as Map));
  }

  Future<void> resume(String id) async {
    await request('thread/resume', {'threadId': id});
  }

  Future<String> send(
    String id,
    String text, {
    ChatRunSettings settings = const ChatRunSettings(),
  }) async {
    final result = await request('turn/start', {
      'threadId': id,
      if (settings.modelId != null) 'model': settings.modelId,
      if (settings.reasoningId != null) 'effort': settings.reasoningId,
      'approvalPolicy': switch (settings.permissionPolicy) {
        OperationPermissionPolicy.askEveryTime => 'untrusted',
        OperationPermissionPolicy.autoAllowSafe => 'on-request',
        OperationPermissionPolicy.autoAllowAll => 'never',
      },
      'sandboxPolicy':
          settings.permissionPolicy == OperationPermissionPolicy.autoAllowAll
          ? {'type': 'dangerFullAccess'}
          : {'type': 'readOnly'},
      'input': [
        {'type': 'text', 'text': text},
      ],
    });
    return (result['turn'] as Map)['id'] as String;
  }

  Future<void> interrupt(String id, String turnId) async {
    await request('turn/interrupt', {'threadId': id, 'turnId': turnId});
  }

  Future<void> close() => connection.close();
}
