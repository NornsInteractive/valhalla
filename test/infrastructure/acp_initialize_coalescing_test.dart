import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// 同一目标的打开会被合并：composer 与 settings 可能并发触发 initialize。
/// 目标切换/释放后到达的迟到打开必须被拒绝。
void main() {
  late FakeAcpPair pair;

  ACPClientAdapter buildAdapter() => ACPClientAdapter(
    profile: testAgentProfile(),
    transport: pair.client,
    workingDirectory: '/root/work',
  );

  setUp(() {
    pair = FakeAcpPair(sessionId: 'remote-1');
  });

  tearDown(() => pair.close());

  List<String> methods() => pair.sentToAgent
      .map((line) => (jsonDecode(line) as Map<String, Object?>)['method'])
      .whereType<String>()
      .toList();

  test('并发 initializeOnly 合并成一次 initialize，仍不建会话', () async {
    final adapter = buildAdapter();
    addTearDown(adapter.dispose);

    await Future.wait([adapter.initializeOnly(), adapter.initializeOnly()]);
    await pumpEventQueue();

    expect(
      pair.sentToAgent.where((line) => line.contains('"initialize"')),
      hasLength(1),
      reason: '同一目标的在飞打开必须合并，不能重复握手',
    );
    expect(pair.newSessionCount, 0);
    expect(pair.loadRequests, isEmpty);
    expect(pair.resumeRequests, isEmpty);
    expect(adapter.sessionId, isNull);
    expect(methods().join(), isNot(contains('session/prompt')));
  });

  test('顺序调用同样只握手一次', () async {
    final adapter = buildAdapter();
    addTearDown(adapter.dispose);

    await adapter.initializeOnly();
    await adapter.initializeOnly();
    await pumpEventQueue();

    expect(
      pair.sentToAgent.where((line) => line.contains('"initialize"')),
      hasLength(1),
    );
    expect(pair.newSessionCount, 0);
  });

  test('释放之后的迟到打开被拒绝，且永不建立会话', () async {
    final adapter = buildAdapter();
    final inFlight = adapter.initializeOnly();
    adapter.dispose();

    // 在飞的那一次允许任意结局，但不得留下未处理的异步错误。
    await inFlight.then<void>((_) {}, onError: (Object _) {});
    await pumpEventQueue();

    await expectLater(
      adapter.initializeOnly(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          ACPClientAdapter.disconnectedCode,
        ),
      ),
    );
    await expectLater(
      adapter.prepareSession(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          ACPClientAdapter.disconnectedCode,
        ),
      ),
    );
    expect(pair.newSessionCount, 0, reason: '释放后的打开绝不能补建远端会话');
    expect(adapter.isDisposed, isTrue);
  });
}
