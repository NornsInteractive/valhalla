import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/chat_launch_preference.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

void main() {
  test(
    'chat launch preferences and last session remain isolated by mode',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      await storage.saveChatLaunchPreference(
        'server-a',
        'agent-a',
        const ChatLaunchPreference(
          mode: ChatLaunchMode.fixed,
          sessionId: 'cli-session',
        ),
        cli: true,
      );
      await storage.saveLastChatSessionId(
        'server-a',
        'agent-a',
        'acp-session',
        cli: false,
      );

      expect(
        storage
            .getChatLaunchPreference('server-a', 'agent-a', cli: true)
            .sessionId,
        'cli-session',
      );
      expect(
        storage.getChatLaunchPreference('server-a', 'agent-a', cli: false).mode,
        ChatLaunchMode.rememberLast,
      );
      expect(
        storage.getLastChatSessionId('server-a', 'agent-a', cli: false),
        'acp-session',
      );
    },
  );
}
