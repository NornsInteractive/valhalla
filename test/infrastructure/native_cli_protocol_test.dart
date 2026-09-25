import 'dart:convert';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/native_cli_session.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/infrastructure/cli/codex_native_client.dart';
import 'package:valhalla/infrastructure/cli/opencode_native_client.dart';
import '../support/fake_acp_transport.dart';

void main() {
  test(
    'Codex wire has no version header and approval replies retain request identity',
    () {
      final frame = CodexSshTransport.decode(
        '{"id":"approval-4","method":"item/commandExecution/requestApproval","params":{"command":"echo 中文"}}',
      );
      final request = frame.messages.single as RpcRequest;
      expect(request.id, 'approval-4');
      final response = TransportFrame.single(
        RpcResponse(id: request.id, result: {'decision': 'accept'}),
      );
      expect(jsonDecode(CodexSshTransport.encode(response)), {
        'id': 'approval-4',
        'result': {'decision': 'accept'},
      });
    },
  );
  test('Codex transport ignores interactive shell startup noise', () {
    expect(
      CodexSshTransport.decodeLine('bash: no job control in this shell'),
      isNull,
    );
    expect(
      CodexSshTransport.decodeLine(
        '{"id":1,"result":{"ok":true}}',
      )!.messages.single,
      isA<RpcResponse>(),
    );
  });
  test('Codex turn settings use protocol-complete sandbox policies', () async {
    final pair = FakeAcpPair();
    pair.agent.onReceive = (wire) {
      for (final message in TransportFrame.decode(wire).messages) {
        if (message is RpcRequest) {
          pair.agent.send(
            TransportFrame.single(
              RpcResponse(
                id: message.id,
                result: {
                  'turn': {'id': 'turn-1'},
                },
              ),
            ),
          );
        }
      }
    };
    final client = CodexNativeClient(Connection(pair.client));
    await client.send(
      'thread',
      'test',
      settings: const ChatRunSettings(
        modelId: 'gpt-test',
        reasoningId: 'high',
        permissionPolicy: OperationPermissionPolicy.autoAllowSafe,
      ),
    );
    final safe = jsonDecode(pair.sentToAgent.single)['params'] as Map;
    expect(safe['model'], 'gpt-test');
    expect(safe['effort'], 'high');
    expect(safe['approvalPolicy'], 'on-request');
    expect(safe['sandboxPolicy'], {'type': 'readOnly'});
    await client.close();
    pair.close();
  });
  test(
    'official Codex handshake and history listing never create a thread',
    () async {
      final pair = FakeAcpPair();
      pair.agent.onReceive = (wire) {
        for (final message in TransportFrame.decode(wire).messages) {
          if (message is! RpcRequest) continue;
          final result = message.method == 'thread/list'
              ? {
                  'data': [
                    {
                      'id': 'thread-1',
                      'sessionId': 'cli-native-1',
                      'name': 'Native history',
                      'cwd': '/project',
                      'updatedAt': 1000,
                    },
                  ],
                  'nextCursor': 'page-2',
                }
              : <String, dynamic>{};
          pair.agent.send(
            TransportFrame.single(RpcResponse(id: message.id, result: result)),
          );
        }
      };
      final client = CodexNativeClient(Connection(pair.client));
      await client.initialize();
      final page = await client.list(cwd: '/project');
      expect(page.sessions.single.resumeId, 'cli-native-1');
      expect(page.cursor, 'page-2');
      final calls = pair.sentToAgent.map(jsonDecode).toList();
      expect(calls.map((m) => m['method']), [
        'initialize',
        'initialized',
        'thread/list',
      ]);
      expect(calls.last['params']['sourceKinds'], contains('appServer'));
      expect(calls.last['params']['cwd'], '/project');
      expect(calls.last['params']['limit'], 15);
      await client.close();
      pair.close();
    },
  );
  test('Codex history preserves native user/assistant messages', () {
    final messages = CodexNativeClient.messages({
      'turns': [
        {
          'items': [
            {
              'id': 'u',
              'type': 'userMessage',
              'content': [
                {'type': 'text', 'text': '你好'},
              ],
            },
            {'id': 'a', 'type': 'agentMessage', 'text': 'Hello'},
            {'id': 'tool', 'type': 'commandExecution', 'command': 'ls'},
          ],
        },
      ],
    });
    expect(messages.map((m) => m.role), ['user', 'assistant']);
    expect(messages.first.text, '你好');
  });
  test(
    'Codex history keeps paging past tool items to fill visible messages',
    () async {
      final pair = FakeAcpPair();
      var pageCalls = 0;
      pair.agent.onReceive = (wire) {
        for (final message in TransportFrame.decode(wire).messages) {
          if (message is! RpcRequest) continue;
          pageCalls++;
          final cursor = (message.params as Map?)?['cursor'];
          final data = cursor == null
              ? [
                  for (var index = 0; index < 9; index++)
                    {
                      'turnId': 'turn',
                      'item': {'id': 'tool-$index', 'type': 'commandExecution'},
                    },
                  {
                    'turnId': 'turn',
                    'item': {
                      'id': 'latest',
                      'type': 'agentMessage',
                      'text': 'latest',
                    },
                  },
                ]
              : [
                  for (var index = 0; index < 2; index++)
                    {
                      'turnId': 'older-$index',
                      'item': {
                        'id': 'older-$index',
                        'type': 'agentMessage',
                        'text': 'older $index',
                      },
                    },
                ];
          pair.agent.send(
            TransportFrame.single(
              RpcResponse(
                id: message.id,
                result: {
                  'data': data,
                  'nextCursor': cursor == null ? 'older-page' : null,
                },
              ),
            ),
          );
        }
      };
      final client = CodexNativeClient(Connection(pair.client));
      final page = await client.readPage('thread', limit: 3);
      expect(page.messages.map((message) => message.id), [
        'older-1',
        'older-0',
        'latest',
      ]);
      expect(page.olderCursor, isNull);
      expect(pageCalls, 2);
      await client.close();
      pair.close();
    },
  );
  test(
    'OpenCode official session metadata and shell arguments are preserved safely',
    () {
      final session = OpenCodeNativeClient.session({
        'id': 'ses-1',
        'directory': '/work',
        'title': 'History',
        'time': {'updated': 1234},
      });
      expect(session.resumeId, 'ses-1');
      expect(session.cwd, '/work');
      expect(session.updatedAt!.millisecondsSinceEpoch, 1234);
      expect(cliShellQuote("/work/a'b"), "'/work/a'\\''b'");
      expect(() => cliShellQuote('a\nrm x'), throwsArgumentError);
      expect(nativeCliKind('/usr/bin/codex'), NativeCliKind.codex);
      expect(nativeCliKind('agy'), NativeCliKind.terminal);
    },
  );
}
