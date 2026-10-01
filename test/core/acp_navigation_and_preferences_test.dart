import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/chat_launch_preference.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _bottomNavigationKey = 'valhalla_bottom_navigation_v1';
const _migrationFlagKey = 'valhalla_navigation_acp_v2';

/// 本轮导航默认值的读时迁移 + ACP 会话偏好隔离。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LocalStorageService> storageWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  ProviderContainer containerWith(LocalStorageService storage) {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('默认导航由 CLI 迁移为 ACP', () {
    test('旧默认值被读时替换为 aiChat，且顺序不变', () async {
      final storage = await storageWith({
        _bottomNavigationKey: <String>[
          'dashboard',
          'cliChat',
          'docker',
          'files',
        ],
      });

      expect(storage.getBottomNavigationSections(), [
        'dashboard',
        'aiChat',
        'docker',
        'files',
      ]);
      expect(
        containerWith(storage).read(settingsProvider).bottomNavigationSections,
        [
          AppSection.dashboard,
          AppSection.aiChat,
          AppSection.docker,
          AppSection.files,
        ],
      );
    });

    test('用户显式选择的列表（含空列表）原样保留', () async {
      final custom = await storageWith({
        _bottomNavigationKey: <String>['files', 'dashboard', 'cliChat'],
      });
      expect(custom.getBottomNavigationSections(), [
        'files',
        'dashboard',
        'cliChat',
      ]);

      final empty = await storageWith({_bottomNavigationKey: <String>[]});
      expect(empty.getBottomNavigationSections(), isEmpty);
      expect(
        containerWith(empty).read(settingsProvider).bottomNavigationSections,
        isEmpty,
      );
    });

    test('用户主动保存过任意列表后不再触发读时迁移', () async {
      final storage = await storageWith({});
      await storage.setBottomNavigationSections([
        'dashboard',
        'cliChat',
        'docker',
        'files',
      ]);
      expect(storage.getBottomNavigationSections(), [
        'dashboard',
        'cliChat',
        'docker',
        'files',
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_migrationFlagKey), isTrue);
    });

    test('缺键返回 null，交给上层使用新默认值', () async {
      final storage = await storageWith({});
      expect(storage.getBottomNavigationSections(), isNull);
      expect(
        containerWith(storage).read(settingsProvider).bottomNavigationSections,
        defaultBottomNavigationSections,
      );
    });

    test('迁移是读时行为，不改写用户原始备份', () async {
      final storage = await storageWith({
        _bottomNavigationKey: <String>[
          'dashboard',
          'cliChat',
          'docker',
          'files',
        ],
      });
      storage.getBottomNavigationSections();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(_bottomNavigationKey), [
        'dashboard',
        'cliChat',
        'docker',
        'files',
      ]);
    });
  });

  group('ACP 会话启动偏好与上次会话', () {
    test('fixed / rememberLast / blankDraft 按服务器与模式隔离', () async {
      final storage = await storageWith({});
      await storage.saveChatLaunchPreference(
        'srv-1',
        'builtin-codex',
        const ChatLaunchPreference(
          mode: ChatLaunchMode.fixed,
          sessionId: 'session-7',
        ),
        cli: false,
      );
      await storage.saveChatLaunchPreference(
        'srv-2',
        'builtin-codex',
        const ChatLaunchPreference(mode: ChatLaunchMode.rememberLast),
        cli: false,
      );
      await storage.saveChatLaunchPreference(
        'srv-1',
        'builtin-codex',
        const ChatLaunchPreference(
          mode: ChatLaunchMode.fixed,
          sessionId: 'cli-1',
        ),
        cli: true,
      );

      expect(
        storage
            .getChatLaunchPreference('srv-1', 'builtin-codex', cli: false)
            .mode,
        ChatLaunchMode.fixed,
      );
      expect(
        storage
            .getChatLaunchPreference('srv-1', 'builtin-codex', cli: false)
            .sessionId,
        'session-7',
      );
      expect(
        storage
            .getChatLaunchPreference('srv-2', 'builtin-codex', cli: false)
            .mode,
        ChatLaunchMode.rememberLast,
      );
      expect(
        storage
            .getChatLaunchPreference('srv-1', 'builtin-codex', cli: true)
            .sessionId,
        'cli-1',
        reason: 'CLI 与 ACP 模式不得共用偏好',
      );
      expect(
        storage
            .getChatLaunchPreference('srv-9', 'builtin-codex', cli: false)
            .mode,
        ChatLaunchMode.rememberLast,
        reason: '未配置时默认为 rememberLast',
      );
    });

    test('上次会话 id 可写可清，且不串服务器', () async {
      final storage = await storageWith({});
      await storage.saveLastChatSessionId('srv-1', 'a', 'local-1', cli: false);
      await storage.saveLastChatSessionId('srv-2', 'a', 'local-2', cli: false);
      await storage.saveLastChatSessionId('srv-1', 'a', 'local-1', cli: true);
      expect(storage.getLastChatSessionId('srv-1', 'a', cli: false), 'local-1');
      expect(storage.getLastChatSessionId('srv-2', 'a', cli: false), 'local-2');
      expect(storage.getLastChatSessionId('srv-1', 'a', cli: true), 'local-1');

      await storage.saveLastChatSessionId('srv-1', 'a', null, cli: false);
      expect(storage.getLastChatSessionId('srv-1', 'a', cli: false), isNull);
      expect(
        storage.getLastChatSessionId('srv-2', 'a', cli: false),
        'local-2',
        reason: '清除一个键不得影响其他键',
      );
    });

    test('远端 ACP 会话 id 按服务器与 Agent 保存', () async {
      final storage = await storageWith({});
      await storage.saveAcpSessionId('srv-1', 'builtin-codex', 'remote-9');
      expect(storage.getAcpSessionId('srv-1', 'builtin-codex'), 'remote-9');
      expect(
        storage.getAcpSessionId('srv-1', 'builtin-agy'),
        isNull,
        reason: '不同 Agent 的远端会话必须隔离',
      );
      expect(storage.getAcpSessionId('srv-2', 'builtin-codex'), isNull);
    });
  });
}
