import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/chat_failure_presentation.dart';

/// 分类表：只认已知原因，未知内容留在 details，绝不建议帮不上忙的登录／重连。
void main() {
  group('classifyChatFailure 分类表', () {
    const cases = <(String, ChatFailureKind, ChatFailureAction)>[
      ('ACP_AUTH_REQUIRED', ChatFailureKind.auth, ChatFailureAction.login),
      ('RpcError(-32000)', ChatFailureKind.auth, ChatFailureAction.login),
      (
        'authentication required',
        ChatFailureKind.auth,
        ChatFailureAction.login,
      ),
      ('invalid_api_key', ChatFailureKind.auth, ChatFailureAction.login),
      (
        'AGENT_MODEL_ACCOUNT_MISMATCH',
        ChatFailureKind.auth,
        ChatFailureAction.login,
      ),
      (
        'AGENT_MODEL_AUTH_UNSUPPORTED',
        ChatFailureKind.auth,
        ChatFailureAction.details,
      ),
      (
        'AGENT_MODEL_AUTH_STORAGE_UNSAFE',
        ChatFailureKind.auth,
        ChatFailureAction.details,
      ),
      (
        'ACP_AUTH_CONNECTION_EXPIRED',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'SSH_DISCONNECTED',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'ACP_DISCONNECTED',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'ACP_IDLE_TIMEOUT',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'transport unavailable',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'ACP_TRANSPORT_FAILURE: SocketException: connection reset',
        ChatFailureKind.connection,
        ChatFailureAction.reconnect,
      ),
      (
        'ACP_SETTING_UNAVAILABLE: model',
        ChatFailureKind.modelUnavailable,
        ChatFailureAction.runSettings,
      ),
      (
        'ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER',
        ChatFailureKind.modelUnavailable,
        ChatFailureAction.runSettings,
      ),
      (
        'model_not_found',
        ChatFailureKind.modelUnavailable,
        ChatFailureAction.runSettings,
      ),
      (
        'model gpt-5-codex is not supported',
        ChatFailureKind.modelUnavailable,
        ChatFailureAction.runSettings,
      ),
      (
        'CHAT_HISTORY_LOAD_FAILED',
        ChatFailureKind.history,
        ChatFailureAction.reloadHistory,
      ),
      (
        'CHAT_MESSAGES_LOAD_FAILED',
        ChatFailureKind.history,
        ChatFailureAction.reloadHistory,
      ),
      (
        'ACP_HISTORY_LOAD_FAILED',
        ChatFailureKind.history,
        ChatFailureAction.reloadHistory,
      ),
      (
        'ACP_REMOTE_HISTORY_UNSUPPORTED',
        ChatFailureKind.history,
        ChatFailureAction.details,
      ),
      (
        'ACP_HISTORY_REPLAY_AMBIGUOUS',
        ChatFailureKind.history,
        ChatFailureAction.details,
      ),
      // 包装内部 RPC 错误不是断线：重连帮不上忙，只给可复制详情。
      (
        'ACP_TRANSPORT_FAILURE: RpcError(-32603)',
        ChatFailureKind.other,
        ChatFailureAction.details,
      ),
      (
        'ACP_TRANSPORT_FAILURE: RpcError(-32700)',
        ChatFailureKind.other,
        ChatFailureAction.details,
      ),
      ('403 forbidden', ChatFailureKind.other, ChatFailureAction.details),
      ('permission denied', ChatFailureKind.other, ChatFailureAction.details),
      (
        'CHAT_SAVE_FAILED: disk full',
        ChatFailureKind.other,
        ChatFailureAction.details,
      ),
      (
        'CHAT_SESSION_IDENTITY_MISMATCH',
        ChatFailureKind.other,
        ChatFailureAction.details,
      ),
      (
        'SOMETHING_NOBODY_SEES',
        ChatFailureKind.other,
        ChatFailureAction.details,
      ),
    ];

    for (final entry in cases) {
      final (code, kind, action) = entry;
      test('$code → ${kind.name}/${action.name}', () {
        final result = classifyChatFailure(code);
        expect(result, isNotNull, reason: '已知原因必须给出动作');
        final presentation = result!;
        expect(presentation.kind, kind);
        expect(presentation.suggestedAction, action);
      });
    }
  });

  test('null 与空白没有失败，返回 null', () {
    expect(classifyChatFailure(null), isNull);
    expect(classifyChatFailure(''), isNull);
    expect(classifyChatFailure('   \n  '), isNull);
  });

  test('authenticationRequired 在没有错误码时也引导登录', () {
    final fromNull = classifyChatFailure(null, authenticationRequired: true);
    expect(fromNull?.kind, ChatFailureKind.auth);
    expect(fromNull?.suggestedAction, ChatFailureAction.login);

    final fromBlank = classifyChatFailure('  ', authenticationRequired: true);
    expect(fromBlank?.kind, ChatFailureKind.auth);
    expect(fromBlank?.suggestedAction, ChatFailureAction.login);
  });

  test('认证标记不覆盖连接过期的恢复动作', () {
    final result = classifyChatFailure(
      'ACP_AUTH_CONNECTION_EXPIRED',
      authenticationRequired: true,
    );
    expect(result?.kind, ChatFailureKind.connection);
    expect(result?.suggestedAction, ChatFailureAction.reconnect);
  });

  test('同一分类返回同一个常量对象', () {
    expect(
      identical(
        classifyChatFailure('ACP_DISCONNECTED'),
        classifyChatFailure('ACP_DISCONNECTED'),
      ),
      isTrue,
    );
    expect(
      identical(
        classifyChatFailure('ACP_AUTH_REQUIRED'),
        classifyChatFailure('authentication required'),
      ),
      isTrue,
      reason: '同一分类必须共享同一对象，才适合 Riverpod select',
    );
    expect(
      identical(
        classifyChatFailure('whatever one'),
        classifyChatFailure('whatever two'),
      ),
      isTrue,
      reason: '未知内容共用同一个 other/details 对象',
    );
  });
}
