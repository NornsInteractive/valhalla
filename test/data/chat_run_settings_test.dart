import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/models/chat_session.dart';

void main() {
  test('run settings round-trip and old sessions stay safe by default', () {
    const settings = ChatRunSettings(
      modelId: 'gpt-test',
      reasoningId: 'high',
      permissionPolicy: OperationPermissionPolicy.autoAllowSafe,
    );
    expect(ChatRunSettings.fromJson(settings.toJson()).modelId, 'gpt-test');

    final session = ChatSession.fromJson({
      'id': 'session',
      'title': 'old',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'messages': <Object>[],
    });
    expect(session.agentRunSettings, isEmpty);
    expect(
      const ChatRunSettings().permissionPolicy,
      OperationPermissionPolicy.askEveryTime,
    );
  });
}
