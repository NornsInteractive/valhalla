import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';

void main() {
  AgentProfile profile() => AgentProfile(
    id: 'agent-1',
    serverId: 'srv-1',
    name: 'agent',
    description: 'test agent',
    cliCommand: 'cli',
  );

  test('generation 0 key equals legacy sha256 algorithm', () {
    const identity = 'identity-value';
    const sessionId = 'session-1';
    final p = profile();
    final expected = sha256
        .convert(utf8.encode('$identity\n${p.id}\n$sessionId'))
        .toString();
    final actual = AcpRuntimeService.sessionKey(
      identity,
      p,
      sessionId,
      generation: 0,
    );
    expect(actual, expected);
  });

  test('generation 1 key differs from generation 0', () {
    const identity = 'identity-value';
    const sessionId = 'session-1';
    final p = profile();
    final gen0 = AcpRuntimeService.sessionKey(
      identity,
      p,
      sessionId,
      generation: 0,
    );
    final gen1 = AcpRuntimeService.sessionKey(
      identity,
      p,
      sessionId,
      generation: 1,
    );
    expect(gen1, isNot(gen0));
    final expectedGen1 = sha256
        .convert(utf8.encode('$identity\n${p.id}\n$sessionId\n1'))
        .toString();
    expect(gen1, expectedGen1);
  });

  test(
    'old AgentChatContext JSON defaults numeric fields to 0 and bool to false',
    () {
      final context = AgentChatContext.fromJson(<String, dynamic>{
        'remoteSessionId': 'remote-1',
        'syncedMessageCount': 2,
      });
      expect(context.remoteSessionId, 'remote-1');
      expect(context.syncedMessageCount, 2);
      expect(context.persistentRuntimeKey, isNull);
      expect(context.runtimeCursor, 0);
      expect(context.runtimeGeneration, 0);
      expect(context.runtimeRestartPending, isFalse);
    },
  );

  test(
    'clearPersistentRuntime clears key and cursor but retains remoteSessionId',
    () {
      const context = AgentChatContext(
        remoteSessionId: 'remote-native',
        syncedMessageCount: 3,
        persistentRuntimeKey: 'runtime-key',
        runtimeCursor: 7,
        runtimeGeneration: 2,
        runtimeRestartPending: true,
      );
      final cleared = context.copyWith(clearPersistentRuntime: true);
      expect(cleared.persistentRuntimeKey, isNull);
      expect(cleared.runtimeCursor, 0);
      expect(cleared.remoteSessionId, 'remote-native');
    },
  );

  test('new AgentChatContext fields roundtrip through JSON', () {
    const context = AgentChatContext(
      remoteSessionId: 'remote-1',
      syncedMessageCount: 5,
      persistentRuntimeKey: 'runtime-key',
      runtimeCursor: 9,
      runtimeGeneration: 3,
      runtimeRestartPending: true,
    );
    final restored = AgentChatContext.fromJson(context.toJson());
    expect(restored.remoteSessionId, context.remoteSessionId);
    expect(restored.syncedMessageCount, context.syncedMessageCount);
    expect(restored.persistentRuntimeKey, context.persistentRuntimeKey);
    expect(restored.runtimeCursor, context.runtimeCursor);
    expect(restored.runtimeGeneration, context.runtimeGeneration);
    expect(restored.runtimeRestartPending, context.runtimeRestartPending);
  });
}
