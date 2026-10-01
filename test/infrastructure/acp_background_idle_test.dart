import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// Background recovery regression coverage for the ACP idle watchdog.
///
/// A locked screen or a suspended desktop window is not an idle agent: the app
/// going to background must suspend idle cancellation of an in-flight remote
/// turn, coming back must hand out a fresh timeout, and neither transition may
/// ever push a prompt to the agent on its own.

const _timeout = Duration(milliseconds: 300);

/// Counts how many times [method] appears in the wire log the client produced.
int _wireCalls(FakeAcpPair pair, String method) =>
    pair.sentToAgent.where((wire) => wire.contains('"$method"')).length;

List<String> _errorTexts(List<ACPEvent> events) =>
    events.whereType<ACPErrorEvent>().map((event) => event.error).toList();

void main() {
  /// A pair whose agent accepts the prompt and never answers it, so the turn
  /// stays open for as long as the test needs.
  (FakeAcpPair, ACPClientAdapter, List<ACPEvent>) openHeldTurn({
    Duration requestTimeout = _timeout,
    bool backgrounded = false,
  }) {
    final pair = FakeAcpPair(sessionId: 'bg-1')..holdPrompt = true;
    addTearDown(pair.close);
    final adapter = ACPClientAdapter(
      profile: testAgentProfile(),
      transport: pair.client,
      requestTimeout: requestTimeout,
    );
    addTearDown(adapter.dispose);
    if (backgrounded) adapter.setInBackground(true);
    final events = <ACPEvent>[];
    final subscription = adapter.eventStream.listen(events.add);
    addTearDown(subscription.cancel);
    return (pair, adapter, events);
  }

  test('a turn started in the background is never cancelled as idle', () async {
    final (pair, adapter, events) = openHeldTurn(backgrounded: true);

    unawaited(adapter.sendPrompt('first question'));
    await pair.promptReceived;

    // Several timeouts over: a suspended app must not lose the turn.
    await Future<void>.delayed(_timeout * 4);

    expect(_errorTexts(events), isEmpty);
    expect(events.whereType<ACPCompleteEvent>(), isEmpty);
    expect(adapter.isDisposed, isFalse);
    expect(
      _wireCalls(pair, 'session/cancel'),
      0,
      reason: 'background must not cancel the remote turn',
    );
    expect(_wireCalls(pair, 'session/prompt'), 1);
  });

  test(
    'an already armed idle timer is suspended by going to background',
    () async {
      final (pair, adapter, events) = openHeldTurn();

      unawaited(adapter.sendPrompt('second question'));
      await pair.promptReceived;
      // The foreground timer is armed here; backgrounding must suspend it.
      adapter.setInBackground(true);

      await Future<void>.delayed(_timeout * 3);

      expect(_errorTexts(events), isEmpty);
      expect(adapter.isDisposed, isFalse);
      expect(_wireCalls(pair, 'session/cancel'), 0);
      expect(_wireCalls(pair, 'session/prompt'), 1);
    },
  );

  test('returning to the foreground grants a fresh timeout', () async {
    final (pair, adapter, events) = openHeldTurn(backgrounded: true);
    final sent = adapter.sendPrompt('third question');
    await pair.promptReceived;

    await Future<void>.delayed(_timeout * 2);
    expect(_errorTexts(events), isEmpty, reason: 'still backgrounded');

    adapter.setInBackground(false);
    final promptsAfterResume = _wireCalls(pair, 'session/prompt');

    // The resumed budget is counted from the resume, not from the original
    // prompt, so it must expire even though the prompt is old.
    await Future<void>.delayed(_timeout * 2);
    await sent;

    expect(
      _errorTexts(events).where((e) => e.contains('ACP_IDLE_TIMEOUT')),
      isNotEmpty,
      reason: 'a foreground turn still times out when the agent goes quiet',
    );
    expect(_wireCalls(pair, 'session/cancel'), 1);
    expect(
      _wireCalls(pair, 'session/prompt'),
      promptsAfterResume,
      reason: 'resuming must never send a prompt on its own',
    );
  });

  test(
    'a foreground turn is cancelled as idle when the app stays awake',
    () async {
      final (pair, adapter, events) = openHeldTurn();
      final sent = adapter.sendPrompt('fourth question');
      await pair.promptReceived;

      await Future<void>.delayed(_timeout * 3);
      await sent;

      expect(
        _errorTexts(events).where((e) => e.contains('ACP_IDLE_TIMEOUT')),
        isNotEmpty,
        reason: 'control case: the watchdog must still fire in the foreground',
      );
      expect(_wireCalls(pair, 'session/cancel'), 1);
      expect(adapter.isDisposed, isTrue);
      expect(_wireCalls(pair, 'session/prompt'), 1);
    },
  );

  test('a background turn completes normally without any cancel', () async {
    final pair = FakeAcpPair(sessionId: 'bg-2');
    addTearDown(pair.close);
    final adapter = ACPClientAdapter(
      profile: testAgentProfile(),
      transport: pair.client,
      requestTimeout: _timeout,
    );
    addTearDown(adapter.dispose);
    adapter.setInBackground(true);
    final events = <ACPEvent>[];
    final subscription = adapter.eventStream.listen(events.add);
    addTearDown(subscription.cancel);

    pair.holdPrompt = false;
    pair.promptUpdates = [
      {
        'sessionUpdate': 'agent_message_chunk',
        'content': {'type': 'text', 'text': 'done'},
      },
    ];
    await adapter.sendPrompt('quick question');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(_errorTexts(events), isEmpty);
    expect(events.whereType<ACPCompleteEvent>(), isNotEmpty);
    expect(_wireCalls(pair, 'session/cancel'), 0);
    expect(adapter.isDisposed, isFalse);
    expect(_wireCalls(pair, 'session/prompt'), 1);
  });
}
