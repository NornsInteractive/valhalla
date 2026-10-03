import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// Explicit sign-in contract: `authenticateNow` must authenticate immediately
/// and never open, load or prompt a chat session on the agent's behalf.
void main() {
  late FakeAcpPair pair;

  setUp(() {
    pair = FakeAcpPair(sessionId: 'auth-1');
    pair.authMethods = [
      {'id': 'oauth', 'name': 'OAuth'},
    ];
  });

  tearDown(() => pair.close());

  ACPClientAdapter build() {
    final adapter = ACPClientAdapter(
      profile: testAgentProfile(),
      transport: pair.client,
      workingDirectory: '/root',
    );
    addTearDown(adapter.dispose);
    return adapter;
  }

  int count(String needle) =>
      pair.sentToAgent.where((line) => line.contains(needle)).length;

  group('authenticateNow', () {
    test(
      'authenticates without creating, loading or prompting a session',
      () async {
        final adapter = build();

        await adapter.authenticateNow('oauth');
        await pumpEventQueue();

        expect(pair.authenticateCallCount, 1);
        expect(pair.lastAuthenticateMethodId, 'oauth');
        expect(pair.newSessionCount, 0);
        expect(pair.loadRequests, isEmpty);
        expect(pair.resumeRequests, isEmpty);
        expect(pair.listRequestCount, 0);
        expect(adapter.sessionId, isNull);
        expect(count('"initialize"'), 1);
        expect(count('session/new'), 0);
        expect(count('session/load'), 0);
        expect(count('session/prompt'), 0);
      },
    );

    test('rejects a method the agent never advertised', () async {
      final adapter = build();

      await expectLater(
        adapter.authenticateNow('not-advertised'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'ACP_AUTH_METHOD_UNAVAILABLE',
          ),
        ),
      );

      expect(pair.authenticateCallCount, 0);
      expect(pair.newSessionCount, 0);
      expect(count('session/prompt'), 0);
    });

    test('does not re-run initialize when it already happened', () async {
      final adapter = build();
      await adapter.initializeOnly();

      await adapter.authenticateNow('oauth');
      await pumpEventQueue();

      expect(count('"initialize"'), 1);
      expect(pair.authenticateCallCount, 1);
      expect(pair.newSessionCount, 0);
      expect(count('session/prompt'), 0);
    });

    test(
      'an agent advertising no methods fails before any session call',
      () async {
        pair.authMethods = const [];
        final adapter = build();

        await expectLater(
          adapter.authenticateNow('oauth'),
          throwsA(isA<StateError>()),
        );

        expect(pair.authenticateCallCount, 0);
        expect(pair.newSessionCount, 0);
        expect(count('session/prompt'), 0);
      },
    );
  });
}
