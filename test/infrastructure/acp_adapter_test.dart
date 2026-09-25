import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// Runs one prompt turn against the fake agent and returns every event until
/// [ACPCompleteEvent] (or timeout).
Future<List<ACPEvent>> _runTurn(
  ACPClientAdapter adapter,
  String prompt, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final events = <ACPEvent>[];
  final done = Completer<void>();
  final sub = adapter.eventStream.listen((event) {
    events.add(event);
    if (event is ACPCompleteEvent && !done.isCompleted) done.complete();
  });
  adapter.sendPrompt(prompt);
  try {
    await done.future.timeout(timeout);
  } finally {
    await sub.cancel();
  }
  return events;
}

void main() {
  group('ACPClientAdapter profile startup', () {
    late FakeAcpPair pair;
    late ACPClientAdapter adapter;

    setUp(() {
      pair = FakeAcpPair();
      adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        workingDirectory: '/root',
      );
    });

    tearDown(() {
      adapter.dispose();
      pair.close();
    });

    test(
      'missing acpCommand emits a structured error and never writes wire',
      () async {
        final headless = ACPClientAdapter(
          profile: testAgentProfile(acpCommand: '   '),
          transport: pair.client,
        );
        addTearDown(headless.dispose);

        final events = <ACPEvent>[];
        final done = Completer<void>();
        final sub = headless.eventStream.listen((event) {
          events.add(event);
          if (event is ACPCompleteEvent && !done.isCompleted) done.complete();
        });
        addTearDown(sub.cancel);

        headless.sendPrompt('hello');
        await done.future.timeout(const Duration(seconds: 1));

        expect(events.whereType<ACPThinkingChunkEvent>(), isEmpty);
        expect(
          events.whereType<ACPErrorEvent>().single.error,
          contains('ACP_MISSING_ACP_COMMAND'),
        );
        expect(events.whereType<ACPCompleteEvent>().length, 1);
        expect(pair.sentToAgent, isEmpty);
      },
    );

    test('initializes and creates a session before prompting', () async {
      final events = await _runTurn(adapter, 'diagnose the host');

      final methods = pair.sentToAgent
          .where((line) => line.contains('"method"'))
          .toList();
      expect(methods.first, contains('"method":"initialize"'));
      expect(methods[1], contains('"method":"session/new"'));
      expect(methods.last, contains('"method":"session/prompt"'));
      expect(events.whereType<ACPErrorEvent>(), isEmpty);
    });

    test('emits content chunks from agent_message_chunk updates', () async {
      pair.promptUpdates = [
        {
          'sessionUpdate': 'agent_message_chunk',
          'content': {'type': 'text', 'text': 'hello from agent'},
        },
      ];

      final events = await _runTurn(adapter, 'hi');

      expect(
        events.whereType<ACPContentChunkEvent>().map((e) => e.chunk).join(),
        contains('hello from agent'),
      );
      expect(events.whereType<ACPCompleteEvent>().length, 1);
    });

    test('maps agent_thought_chunk to thinking events', () async {
      pair.promptUpdates = [
        {
          'sessionUpdate': 'agent_thought_chunk',
          'content': {'type': 'text', 'text': 'reasoning...'},
        },
      ];

      final events = await _runTurn(adapter, 'think');

      expect(
        events.whereType<ACPThinkingChunkEvent>().map((e) => e.chunk).join(),
        contains('reasoning...'),
      );
    });

    test('maps plan updates to plan steps', () async {
      pair.promptUpdates = [
        {
          'sessionUpdate': 'plan',
          'entries': [
            {
              'content': 'collect metrics',
              'priority': 'high',
              'status': 'in_progress',
            },
          ],
        },
      ];

      final events = await _runTurn(adapter, 'plan');

      final plan = events.whereType<ACPPlanUpdateEvent>().last;
      expect(plan.planSteps.single.title, 'collect metrics');
      expect(plan.planSteps.single.status, PlanStepStatus.inProgress);
    });

    test('maps tool_call updates to tool executions', () async {
      pair.promptUpdates = [
        {
          'sessionUpdate': 'tool_call',
          'toolCallId': 'tool-1',
          'title': 'free -m',
          'kind': 'execute',
          'status': 'completed',
          'content': [
            {
              'type': 'content',
              'content': {'type': 'text', 'text': 'Mem: 7912'},
            },
          ],
        },
      ];

      final events = await _runTurn(adapter, 'check memory');

      final tool = events.whereType<ACPToolExecutionEvent>().single;
      expect(tool.toolExecution.id, 'tool-1');
      expect(tool.toolExecution.name, 'free -m');
      expect(tool.toolExecution.status, ToolExecutionStatus.completed);
    });

    test('permission request is emitted and the reply is sent back', () async {
      pair.holdPrompt = true;
      pair.promptUpdates = [
        {
          'sessionUpdate': 'tool_call',
          'toolCallId': 'tool-1',
          'title': 'bash',
          'kind': 'execute',
          'status': 'pending',
          'content': [
            {
              'type': 'content',
              'content': {'type': 'text', 'text': 'rm -rf /tmp/x'},
            },
          ],
        },
      ];

      final events = <ACPEvent>[];
      final permissionDone = Completer<void>();
      final completeDone = Completer<void>();
      final sub = adapter.eventStream.listen((event) {
        events.add(event);
        if (event is ACPPermissionRequestEvent) {
          event.responseCompleter.complete(true);
          if (!permissionDone.isCompleted) permissionDone.complete();
        }
        if (event is ACPCompleteEvent && !completeDone.isCompleted) {
          completeDone.complete();
        }
      });
      addTearDown(sub.cancel);

      final turn = adapter.sendPrompt('run risky');
      await pair.promptReceived.timeout(const Duration(seconds: 1));

      // Fake agent asks for permission mid-turn while the prompt is held open.
      pair.deliverToClient(
        '{"jsonrpc":"2.0","id":"perm-1","method":"session/request_permission",'
        '"params":{"sessionId":"session-1","toolCall":{'
        '"toolCallId":"tool-1","title":"bash","kind":"execute",'
        '"status":"pending","content":[{"type":"content","content":'
        '{"type":"text","text":"rm -rf /tmp/x"}}]},'
        '"options":[{"optionId":"allow","name":"Allow",'
        '"kind":"allow_once"},{"optionId":"reject","name":"Reject",'
        '"kind":"reject_once"}]}}',
      );
      await permissionDone.future.timeout(const Duration(seconds: 1));

      final permission = events.whereType<ACPPermissionRequestEvent>().single;
      expect(permission.request.command, contains('rm -rf /tmp/x'));

      pair.finishHeldPrompt();
      await turn.timeout(const Duration(seconds: 1));
      await completeDone.future.timeout(const Duration(seconds: 1));

      expect(pair.sentToAgent.join(), contains('"outcome":"selected"'));
      final response = pair.sentToAgent
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .firstWhere((frame) => frame['id'] == 'perm-1');
      expect(response['result'], {'outcome': 'selected', 'optionId': 'allow'});
      expect(response.containsKey('error'), isFalse);
      expect(events.whereType<ACPErrorEvent>(), isEmpty);
    });

    for (final approved in [false, true]) {
      test(
        'permission response uses ACP outcome for approved=$approved',
        () async {
          pair.holdPrompt = true;
          final permission = Completer<void>();
          final sub = adapter.eventStream.listen((event) {
            if (event is ACPPermissionRequestEvent) {
              event.responseCompleter.complete(approved);
              permission.complete();
            }
          });
          addTearDown(sub.cancel);
          final turn = adapter.sendPrompt('permission');
          await pair.promptReceived;
          pair.deliverToClient(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 'approval-wire',
              'method': 'session/request_permission',
              'params': {
                'sessionId': 'session-1',
                'toolCall': {'toolCallId': 'tool-1'},
                'options': [
                  {
                    'optionId': 'original-allow',
                    'name': 'Allow',
                    'kind': 'allow_once',
                  },
                  {
                    'optionId': 'original-reject',
                    'name': 'Reject',
                    'kind': 'reject_once',
                  },
                ],
              },
            }),
          );
          await permission.future;
          await pumpEventQueue();
          final response = pair.sentToAgent
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .firstWhere((frame) => frame['id'] == 'approval-wire');
          expect(response['result'], {
            'outcome': 'selected',
            'optionId': approved ? 'original-allow' : 'original-reject',
          });
          pair.finishHeldPrompt();
          await turn;
        },
      );
    }

    test('cancelled permission uses cancelled ACP outcome', () async {
      pair.holdPrompt = true;
      final permission = Completer<void>();
      final sub = adapter.eventStream.listen((event) {
        if (event is ACPPermissionRequestEvent) permission.complete();
      });
      addTearDown(sub.cancel);
      final turn = adapter.sendPrompt('permission');
      await pair.promptReceived;
      pair.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 'cancelled-approval',
          'method': 'session/request_permission',
          'params': {
            'sessionId': 'session-1',
            'toolCall': {'toolCallId': 'tool-1'},
            'options': [
              {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
            ],
          },
        }),
      );
      await permission.future;
      pair.deliverToClient(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': r'$/cancel_request',
          'params': {'requestId': 'cancelled-approval'},
        }),
      );
      await pumpEventQueue();
      final response = pair.sentToAgent
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .firstWhere((frame) => frame['id'] == 'cancelled-approval');
      expect(response['result'], {'outcome': 'cancelled'});
      pair.finishHeldPrompt();
      await turn;
    });

    test('prompt failure surfaces a structured error and completes', () async {
      pair.failPrompt = true;
      pair.promptErrorCode = -32603; // internal error, not authRequired

      final events = await _runTurn(adapter, 'hi');

      expect(events.whereType<ACPErrorEvent>(), isNotEmpty);
      expect(events.whereType<ACPAuthRequiredEvent>(), isEmpty);
      expect(events.whereType<ACPCompleteEvent>().length, 1);
    });

    test('dispose closes the event stream', () async {
      final closed = Completer<void>();
      adapter.eventStream.listen((_) {}, onDone: () => closed.complete());
      adapter.dispose();
      await closed.future.timeout(const Duration(seconds: 1));
    });
  });

  group('ACPClientAdapter authentication', () {
    late FakeAcpPair pair;
    late ACPClientAdapter adapter;

    setUp(() {
      pair = FakeAcpPair();
      adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        workingDirectory: '/root',
      );
    });

    tearDown(() {
      adapter.dispose();
      pair.close();
    });

    test('surfaces declared authMethods when the agent requires auth', () async {
      pair.authMethods = [
        {
          'id': 'chat-gpt',
          'name': 'ChatGPT',
          'description': 'Sign in with a browser',
        },
        {'id': 'api-key', 'name': 'API Key'},
      ];
      pair.failPrompt = true;

      final events = await _runTurn(adapter, 'hi');

      final auth = events.whereType<ACPAuthRequiredEvent>().toList();
      expect(auth, hasLength(1));
      expect(auth.single.methods.map((m) => m.id), ['chat-gpt', 'api-key']);
      expect(auth.single.methods.first.name, 'ChatGPT');
      expect(auth.single.methods.first.description, 'Sign in with a browser');
      expect(auth.single.methods.last.description, isNull);
      // Auth is recoverable, so it must not be reported as a transport failure.
      expect(events.whereType<ACPErrorEvent>(), isEmpty);
      expect(events.whereType<ACPCompleteEvent>().length, 1);
    });

    test('emits an empty method list when the agent declares none', () async {
      pair.failPrompt = true;

      final events = await _runTurn(adapter, 'hi');

      final auth = events.whereType<ACPAuthRequiredEvent>().toList();
      expect(auth, hasLength(1));
      expect(auth.single.methods, isEmpty);
    });

    test('auth required on session/new is also surfaced', () async {
      pair.authMethods = [
        {'id': 'chat-gpt', 'name': 'ChatGPT'},
      ];
      pair.failSessionNew = true;

      final events = await _runTurn(adapter, 'hi');

      final auth = events.whereType<ACPAuthRequiredEvent>().toList();
      expect(auth, hasLength(1));
      expect(auth.single.methods.single.id, 'chat-gpt');
    });

    test('authenticate uses the chosen methodId before session/new', () async {
      pair.authMethods = [
        {'id': 'chat-gpt', 'name': 'ChatGPT'},
        {'id': 'api-key', 'name': 'API Key'},
      ];
      pair.failPrompt = true;

      await _runTurn(adapter, 'hi');
      await adapter.authenticate('api-key');

      // Retry after authenticating: the agent now accepts the turn.
      pair.failPrompt = false;
      pair.resetPromptReceived();
      await _runTurn(adapter, 'hi again');

      expect(pair.authenticateCallCount, 1);
      expect(pair.lastAuthenticateMethodId, 'api-key');

      // `authenticate` must precede the rebuilt session/new on the wire.
      final wire = pair.sentToAgent.join('\n');
      final authIndex = wire.lastIndexOf('"method":"authenticate"');
      final newSessionIndex = wire.lastIndexOf('"method":"session/new"');
      expect(authIndex, greaterThanOrEqualTo(0));
      expect(newSessionIndex, greaterThan(authIndex));
    });

    test('a failed authenticate re-surfaces the auth requirement', () async {
      pair.authMethods = [
        {'id': 'chat-gpt', 'name': 'ChatGPT'},
      ];
      pair.failPrompt = true;

      await _runTurn(adapter, 'hi');
      await adapter.authenticate('chat-gpt');

      pair.failAuthenticate = true;
      pair.resetPromptReceived();
      final events = await _runTurn(adapter, 'hi again');

      // authenticate itself failed with -32000, so the turn is still blocked on
      // auth rather than silently succeeding.
      expect(pair.authenticateCallCount, 1);
      expect(events.whereType<ACPAuthRequiredEvent>(), isNotEmpty);
      expect(events.whereType<ACPCompleteEvent>().length, 1);
    });
  });
}
