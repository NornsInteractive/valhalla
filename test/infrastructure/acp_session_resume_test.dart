import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// 等待 adapter 的异步建会话流程走完。
Future<List<ACPEvent>> _drain(ACPClientAdapter adapter, String prompt) async {
  final events = <ACPEvent>[];
  final sub = adapter.eventStream.listen(events.add);
  await adapter.sendPrompt(prompt);

  // 事件通过广播流异步投递，等一轮微任务再取消订阅。
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await sub.cancel();
  return events;
}

void main() {
  group('ACP 会话恢复链', () {
    test('无历史 sessionId 时走 session/new', () async {
      final pair = FakeAcpPair(sessionId: 'fresh-1');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
      );

      final events = await _drain(adapter, 'hello');

      expect(pair.newSessionCwds, hasLength(1), reason: '应新建会话');
      expect(pair.loadRequests, isEmpty);
      expect(pair.resumeRequests, isEmpty);
      expect(adapter.sessionId, 'fresh-1');
      expect(adapter.restoredExistingSession, isFalse);
      expect(events.whereType<ACPCompleteEvent>(), isNotEmpty);
    });

    test('有历史 sessionId 时优先 session/load 并复用该 id', () async {
      final pair = FakeAcpPair(sessionId: 'old-1');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: 'old-1',
      );

      await _drain(adapter, 'continue');

      expect(pair.loadRequests, ['old-1']);
      expect(pair.resumeRequests, isEmpty, reason: 'load 成功就不该再退到 resume');
      expect(pair.newSessionCwds, isEmpty, reason: '不该新建会话');
      expect(adapter.sessionId, 'old-1');
      expect(adapter.restoredExistingSession, isTrue);
    });

    test('load 失败时降级到 session/resume', () async {
      final pair = FakeAcpPair(sessionId: 'old-2')..failSessionLoad = true;
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: 'old-2',
      );

      await _drain(adapter, 'continue');

      expect(pair.loadRequests, ['old-2']);
      expect(pair.resumeRequests, ['old-2']);
      expect(pair.newSessionCwds, isEmpty);
      expect(adapter.sessionId, 'old-2');
      expect(adapter.restoredExistingSession, isTrue);
    });

    test('load 与 resume 都失败时不静默创建新会话', () async {
      final pair = FakeAcpPair(sessionId: 'recreated')
        ..failSessionLoad = true
        ..failSessionResume = true;
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: 'gone-1',
      );

      await _drain(adapter, 'start over');

      expect(pair.loadRequests, ['gone-1']);
      expect(pair.resumeRequests, ['gone-1']);
      expect(pair.newSessionCwds, isEmpty);
      expect(adapter.sessionId, isNull);
      expect(
        adapter.restoredExistingSession,
        isFalse,
        reason: '新建意味着上下文已丢失，上层据此提示用户',
      );
    });

    test('空字符串 sessionId 不会被当作可恢复会话', () async {
      final pair = FakeAcpPair(sessionId: 'new-1');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: '',
      );

      await _drain(adapter, 'hi');

      expect(pair.loadRequests, isEmpty);
      expect(pair.resumeRequests, isEmpty);
      expect(pair.newSessionCwds, hasLength(1));
    });

    test('onSessionEstablished 在建会话后拿到 id', () async {
      final pair = FakeAcpPair(sessionId: 'persist-me');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
      );
      final captured = <String>[];
      adapter.onSessionEstablished = captured.add;

      await _drain(adapter, 'hi');

      expect(captured, ['persist-me']);
    });

    test('恢复已有会话时也会回调 onSessionEstablished', () async {
      // 回调在 load 路径上同样触发，否则存储里的 id 会一直是旧值
      // 而无法反映 agent 可能的重新分配。
      final pair = FakeAcpPair(sessionId: 'restored-1');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: 'restored-1',
      );
      final captured = <String>[];
      adapter.onSessionEstablished = captured.add;

      await _drain(adapter, 'hi');

      expect(captured, ['restored-1']);
    });

    test('同一 adapter 的第二次 sendPrompt 不会重新建会话', () async {
      final pair = FakeAcpPair(sessionId: 'once-1');
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
      );

      await _drain(adapter, 'first');
      pair.resetPromptReceived();
      await _drain(adapter, 'second');

      expect(
        pair.newSessionCwds,
        hasLength(1),
        reason: '第二次发送应复用已有会话，这正是上下文不丢的前提',
      );
    });

    test('会话恢复失败不会把错误当成认证要求', () async {
      final pair = FakeAcpPair(sessionId: 'recreated')
        ..failSessionLoad = true
        ..failSessionResume = true;
      addTearDown(pair.close);

      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        resumeSessionId: 'gone',
      );

      final events = await _drain(adapter, 'hi');

      expect(events.whereType<ACPAuthRequiredEvent>(), isEmpty);
      expect(events.whereType<ACPCompleteEvent>(), isNotEmpty);
    });
  });
}
