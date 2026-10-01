import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// Runs one prompt turn against the fake agent and returns every event until
/// [ACPCompleteEvent] (or timeout).
Future<List<ACPEvent>> _runTurn(
  ACPClientAdapter adapter,
  String prompt, {
  List<AcpPromptAttachment> attachments = const [],
  Duration timeout = const Duration(seconds: 3),
}) async {
  final events = <ACPEvent>[];
  final done = Completer<void>();
  final sub = adapter.eventStream.listen((event) {
    events.add(event);
    if (event is ACPCompleteEvent && !done.isCompleted) done.complete();
  });
  adapter.sendPrompt(prompt, attachments: attachments);
  try {
    await done.future.timeout(timeout);
  } finally {
    await sub.cancel();
  }
  return events;
}

bool _sentMethod(FakeAcpPair pair, String method) =>
    pair.sentToAgent.any((line) => line.contains('"method":"$method"'));

Map<String, Object?> _requestFrame(FakeAcpPair pair, String method) => pair
    .sentToAgent
    .map((line) => jsonDecode(line) as Map<String, Object?>)
    .firstWhere((frame) => frame['method'] == method);

ACPClientAdapter _adapterFor(
  FakeAcpPair pair, {
  String? resumeSessionId,
  bool captureReplay = false,
}) {
  final adapter = ACPClientAdapter(
    profile: testAgentProfile(),
    transport: pair.client,
    workingDirectory: '/root',
    resumeSessionId: resumeSessionId,
    captureReplay: captureReplay,
  );
  addTearDown(adapter.dispose);
  return adapter;
}

void main() {
  group('ACP capability negotiation', () {
    test(
      'session/list is answered with a page and never creates a session',
      () async {
        final bare = FakeAcpPair();
        addTearDown(bare.close);
        final bareAdapter = _adapterFor(bare);

        await expectLater(
          bareAdapter.listRemoteSessions(const ListSessionsRequest()),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'ACP_REMOTE_HISTORY_UNSUPPORTED',
            ),
          ),
        );
        expect(_sentMethod(bare, 'session/list'), isFalse);
        expect(_sentMethod(bare, 'session/new'), isFalse);

        final pair = FakeAcpPair();
        addTearDown(pair.close);
        pair.agentCapabilities = {
          'sessionCapabilities': {'list': <String, Object?>{}},
        };
        pair.remoteSessions = [
          {'sessionId': 'remote-1', 'cwd': '/root', 'title': 'first'},
          {'sessionId': 'remote-2', 'cwd': '/srv'},
        ];
        pair.listNextCursor = 'page-2';
        final adapter = _adapterFor(pair);

        final page = await adapter.listRemoteSessions(
          const ListSessionsRequest(cursor: 'page-1'),
        );

        expect(pair.listCursors, ['page-1']);
        expect(page.sessions.map((session) => session.sessionId), [
          'remote-1',
          'remote-2',
        ]);
        expect(page.sessions.first.cwd, '/root');
        expect(page.sessions.first.title, 'first');
        expect(page.nextCursor, 'page-2');
        expect(pair.newSessionCount, 0, reason: '列举远端会话不能顺带建会话');
        expect(adapter.sessionId, isNull);
        expect(adapter.restoredExistingSession, isFalse);
      },
    );

    test(
      'attachments send the negotiated ContentBlocks and no prompt otherwise',
      () async {
        final supported = FakeAcpPair();
        addTearDown(supported.close);
        supported.agentCapabilities = {
          'promptCapabilities': {'image': true, 'embeddedContext': true},
        };
        final adapter = _adapterFor(supported);

        final image = Uint8List.fromList([137, 80, 78, 71]);
        final note = utf8.encode('hello attachment');
        final events = await _runTurn(
          adapter,
          'look at this',
          attachments: [
            AcpPromptAttachment(
              name: 'shot.png',
              mimeType: 'image/png',
              bytes: image,
            ),
            AcpPromptAttachment(
              name: 'note.txt',
              mimeType: 'text/plain',
              bytes: Uint8List.fromList(note),
            ),
          ],
        );

        expect(events.whereType<ACPErrorEvent>(), isEmpty);
        final prompt =
            (_requestFrame(supported, 'session/prompt')['params']
                    as Map<String, Object?>)['prompt']
                as List<Object?>;
        expect(prompt, hasLength(3));
        expect(prompt[0], {'type': 'text', 'text': 'look at this'});
        final block = prompt[1] as Map<String, Object?>;
        expect(block['type'], 'image');
        expect(block['mimeType'], 'image/png');
        expect(block['data'], base64Encode(image));
        final embedded = prompt[2] as Map<String, Object?>;
        expect(embedded['type'], 'resource');
        final resource = embedded['resource'] as Map<String, Object?>;
        expect(resource['text'], 'hello attachment');
        expect(resource['mimeType'], 'text/plain');
        expect(resource['uri'], 'file:///attachments/note.txt');

        // Agent never advertised image support: no prompt may go out.
        final unsupported = FakeAcpPair();
        addTearDown(unsupported.close);
        final blocked = _adapterFor(unsupported);
        final blockedEvents = await _runTurn(
          blocked,
          'hi',
          attachments: [
            AcpPromptAttachment(
              name: 'shot.png',
              mimeType: 'image/png',
              bytes: image,
            ),
          ],
        );
        expect(
          blockedEvents.whereType<ACPErrorEvent>().single.error,
          contains('ACP_ATTACHMENT_UNSUPPORTED'),
        );
        expect(_sentMethod(unsupported, 'session/prompt'), isFalse);

        // Over the text budget: rejected before anything hits the wire.
        final oversized = FakeAcpPair();
        addTearDown(oversized.close);
        oversized.agentCapabilities = {
          'promptCapabilities': {'image': true, 'embeddedContext': true},
        };
        final tooBig = _adapterFor(oversized);
        final tooBigEvents = await _runTurn(
          tooBig,
          'hi',
          attachments: [
            AcpPromptAttachment(
              name: 'huge.txt',
              mimeType: 'text/plain',
              bytes: Uint8List(AcpPromptAttachment.maxTextBytes + 1),
            ),
          ],
        );
        expect(
          tooBigEvents.whereType<ACPErrorEvent>().single.error,
          contains('ACP_ATTACHMENT_TOO_LARGE'),
        );
        expect(_sentMethod(oversized, 'session/prompt'), isFalse);
      },
    );

    test(
      'available_commands and usage keep remote values instead of 0/USD',
      () async {
        final pair = FakeAcpPair();
        addTearDown(pair.close);
        pair.promptUpdates = [
          {
            'sessionUpdate': 'available_commands_update',
            'availableCommands': [
              {
                'name': 'fix',
                'description': '修复失败的测试',
                'input': {'hint': 'focus'},
              },
              {'name': 'ship', 'description': 'Ship the build'},
            ],
          },
          {'sessionUpdate': 'usage_update', 'used': 4212, 'size': 200000},
          {
            'sessionUpdate': 'usage_update',
            'used': 5000,
            'cost': {'amount': 0.37, 'currency': 'EUR'},
          },
        ];
        final adapter = _adapterFor(pair);

        final events = await _runTurn(adapter, 'hi');

        final commands = events
            .whereType<ACPCommandsChangedEvent>()
            .single
            .commands;
        expect(commands.map((command) => command.name), ['fix', 'ship']);
        expect(commands.first.description, '修复失败的测试');
        expect(commands.first.hint, 'focus');
        expect(adapter.commands.map((command) => command.name), [
          'fix',
          'ship',
        ]);

        final usage = events
            .whereType<ACPUsageEvent>()
            .map((event) => event.usage)
            .toList();
        expect(usage, hasLength(2));
        expect(usage.first.used, 4212, reason: '远端 used 不能被改写成 0');
        expect(usage.first.size, 200000);
        expect(usage.first.cost, isNull, reason: '远端没给 cost 就不该编造');
        expect(usage.first.currency, isNull, reason: '远端没给货币不该补 USD');

        expect(usage.last.used, 5000);
        expect(usage.last.size, 200000, reason: '局部更新要保留已有字段');
        expect(usage.last.cost, 0.37);
        expect(usage.last.currency, 'EUR');
        expect(adapter.usage?.used, 5000);
        expect(adapter.usage?.size, 200000);
        expect(adapter.usage?.cost, 0.37);
        expect(adapter.usage?.currency, 'EUR');
      },
    );

    test(
      'captureReplay replays history on session/load only, plain restore is silent',
      () async {
        final replayUpdates = [
          {
            'sessionUpdate': 'user_message_chunk',
            'content': {'type': 'text', 'text': '历史提问'},
          },
          {
            'sessionUpdate': 'agent_message_chunk',
            'content': {'type': 'text', 'text': '历史回答'},
          },
        ];

        final pair = FakeAcpPair(sessionId: 'hist-1');
        addTearDown(pair.close);
        pair.agentCapabilities = {'loadSession': true};
        pair.loadReplayUpdates = replayUpdates;
        final replaying = _adapterFor(
          pair,
          resumeSessionId: 'hist-1',
          captureReplay: true,
        );
        final replayed = <ACPEvent>[];
        final replaySub = replaying.eventStream.listen(replayed.add);

        await replaying.prepareSession();

        expect(pair.loadRequests, ['hist-1']);
        expect(pair.newSessionCount, 0);
        expect(
          replayed.whereType<ACPUserContentChunkEvent>().map(
            (event) => event.chunk,
          ),
          ['历史提问'],
        );
        expect(
          replayed.whereType<ACPContentChunkEvent>().map(
            (event) => event.chunk,
          ),
          ['历史回答'],
        );

        // A later turn must not replay the history a second time.
        await _runTurn(replaying, 'next');
        await replaySub.cancel();
        expect(replayed.whereType<ACPUserContentChunkEvent>(), hasLength(1));
        expect(replayed.whereType<ACPContentChunkEvent>(), hasLength(1));

        final plainPair = FakeAcpPair(sessionId: 'hist-1');
        addTearDown(plainPair.close);
        plainPair.loadReplayUpdates = replayUpdates;
        final plain = _adapterFor(plainPair, resumeSessionId: 'hist-1');
        final restored = <ACPEvent>[];
        final plainSub = plain.eventStream.listen(restored.add);

        await plain.prepareSession();
        await _runTurn(plain, 'continue');
        await plainSub.cancel();

        expect(plainPair.loadRequests, ['hist-1'], reason: '确实走了 load 恢复');
        expect(
          restored.whereType<ACPUserContentChunkEvent>(),
          isEmpty,
          reason: '本地已有历史，普通恢复不能重复输出',
        );
        expect(restored.whereType<ACPContentChunkEvent>(), isEmpty);
      },
    );
  });
}
