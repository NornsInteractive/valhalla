import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/fake_acp_transport.dart';

/// 契约 5：`-32603` 的诊断必须区分 session/new|resume|load 与
/// set_config_option 的 configId；非 -32603 与认证错误保留原类型/语义。
void main() {
  late FakeAcpPair pair;
  late ACPClientAdapter adapter;

  tearDown(() {
    adapter.dispose();
    pair.close();
  });

  ACPClientAdapter build({String? resumeSessionId}) {
    pair = FakeAcpPair(sessionId: 'diag-1');
    adapter = ACPClientAdapter(
      profile: testAgentProfile(),
      transport: pair.client,
      workingDirectory: '/root',
      resumeSessionId: resumeSessionId,
    );
    return adapter;
  }

  group('session prepare 的 -32603 指向实际失败的操作', () {
    test('session/new 失败时诊断写出 session/new', () async {
      build();
      pair.failSessionNew = true;
      pair.sessionNewErrorCode = -32603;

      await expectLater(
        adapter.prepareSession(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            matches(
              RegExp(r'^ACP_SESSION_PREPARE_FAILED: session/new: .*-32603'),
            ),
          ),
        ),
      );
      expect(pair.newSessionCwds, hasLength(1));
    });

    test('session/load 失败时诊断写出 session/load，且绝不退回新建', () async {
      build(resumeSessionId: 'old-1');
      pair.failSessionLoad = true;
      pair.sessionLoadErrorCode = -32603;

      await expectLater(
        adapter.prepareSession(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            matches(
              RegExp(r'^ACP_SESSION_PREPARE_FAILED: session/load: .*-32603'),
            ),
          ),
        ),
      );
      expect(pair.loadRequests, ['old-1']);
      expect(pair.newSessionCwds, isEmpty, reason: '恢复失败不得静默新建会话');
      expect(adapter.sessionId, isNull);
    });

    test('session/resume 失败时诊断写出 session/resume，且绝不退回新建', () async {
      build(resumeSessionId: 'old-2');
      pair.failSessionLoad = true; // -32601：load 不支持，降级到 resume
      pair.failSessionResume = true;
      pair.sessionResumeErrorCode = -32603;

      await expectLater(
        adapter.prepareSession(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            matches(
              RegExp(r'^ACP_SESSION_PREPARE_FAILED: session/resume: .*-32603'),
            ),
          ),
        ),
      );
      expect(pair.resumeRequests, ['old-2']);
      expect(pair.newSessionCwds, isEmpty, reason: '恢复失败不得静默新建会话');
      expect(adapter.sessionId, isNull);
    });
  });

  group('set_config_option 的 -32603 指向实际 configId', () {
    test('配置失败的诊断写出 ACP_SETTING_APPLY_FAILED 与 configId', () async {
      build();
      await adapter.prepareSession();
      pair.failSetConfigOption = true;
      pair.setConfigOptionErrorCode = -32603;

      await expectLater(
        adapter.setConfigOption(
          SetValueIdConfigOption(
            sessionId: adapter.sessionId!,
            configId: 'model',
            value: 'gpt-5-codex',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            matches(RegExp(r'^ACP_SETTING_APPLY_FAILED: model: .*-32603')),
          ),
        ),
      );
      expect(
        pair.setConfigOptionRequests.single.configId,
        'model',
        reason: '诊断必须落到具体的 configId',
      );
    });

    test('非 -32603 的配置错误保留原始 RpcError 类型与错误码', () async {
      build();
      await adapter.prepareSession();
      pair.failSetConfigOption = true;
      pair.setConfigOptionErrorCode = -32001;

      await expectLater(
        adapter.setConfigOption(
          SetValueIdConfigOption(
            sessionId: adapter.sessionId!,
            configId: 'model',
            value: 'gpt-5-codex',
          ),
        ),
        throwsA(isA<RpcError>().having((error) => error.code, 'code', -32001)),
        reason: '非 -32603 不得折叠成 ACP_SETTING_APPLY_FAILED',
      );
    });
  });

  group('认证错误保留原语义', () {
    test('session/new 认证失败透出认证事件而不是 prepare 诊断', () async {
      build();
      pair.authMethods = [
        {'id': 'chat-gpt', 'name': 'ChatGPT'},
      ];
      pair.failSessionNew = true; // 默认 -32000 = authRequired

      final events = <ACPEvent>[];
      final sub = adapter.eventStream.listen(events.add);

      await expectLater(
        adapter.prepareSession(),
        throwsA(isA<RpcError>().having((error) => error.code, 'code', -32000)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(events.whereType<ACPAuthRequiredEvent>(), hasLength(1));
      expect(events.whereType<ACPSettingsChangedEvent>(), isEmpty);
      expect(pair.newSessionCwds, hasLength(1), reason: '认证失败不等于会话建立失败');
    });
  });
}
