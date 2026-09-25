import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStorageService.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ACP session id 持久化', () {
    test('初始没有存储任何会话 id', () async {
      final storage = await _storage();
      expect(storage.getAcpSessionId('s1', 'a1'), isNull);
    });

    test('保存后可读回', () async {
      final storage = await _storage();
      await storage.saveAcpSessionId('s1', 'a1', 'session-abc');

      expect(storage.getAcpSessionId('s1', 'a1'), 'session-abc');
    });

    test('不同服务器之间互相隔离', () async {
      final storage = await _storage();
      await storage.saveAcpSessionId('s1', 'a1', 'sess-1');
      await storage.saveAcpSessionId('s2', 'a1', 'sess-2');

      expect(storage.getAcpSessionId('s1', 'a1'), 'sess-1');
      expect(storage.getAcpSessionId('s2', 'a1'), 'sess-2');
    });

    test('同一服务器下不同 Agent 互相隔离', () async {
      final storage = await _storage();
      await storage.saveAcpSessionId('s1', 'a1', 'codex-sess');
      await storage.saveAcpSessionId('s1', 'a2', 'claude-sess');

      expect(storage.getAcpSessionId('s1', 'a1'), 'codex-sess');
      expect(storage.getAcpSessionId('s1', 'a2'), 'claude-sess');
    });

    test('覆盖同一键会更新而不是追加', () async {
      final storage = await _storage();
      await storage.saveAcpSessionId('s1', 'a1', 'old');
      await storage.saveAcpSessionId('s1', 'a1', 'new');

      expect(storage.getAcpSessionId('s1', 'a1'), 'new');
    });

    test('清除后读回 null，且不影响其他条目', () async {
      final storage = await _storage();
      await storage.saveAcpSessionId('s1', 'a1', 'sess-1');
      await storage.saveAcpSessionId('s2', 'a1', 'sess-2');

      await storage.clearAcpSessionId('s1', 'a1');

      expect(storage.getAcpSessionId('s1', 'a1'), isNull);
      expect(storage.getAcpSessionId('s2', 'a1'), 'sess-2');
    });

    test('清除不存在的键是无害的', () async {
      final storage = await _storage();
      await expectLater(storage.clearAcpSessionId('nope', 'nope'), completes);
    });

    test('跨 LocalStorageService 实例仍然可读（真的落盘了）', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await LocalStorageService.init();
      await first.saveAcpSessionId('s1', 'a1', 'durable');

      final second = await LocalStorageService.init();
      expect(
        second.getAcpSessionId('s1', 'a1'),
        'durable',
        reason: '会话 id 必须跨 App 重启存活，否则重连无法恢复上下文',
      );
    });

    test('存储内容损坏时安全退化为 null 而不是抛错', () async {
      SharedPreferences.setMockInitialValues({
        'valhalla_acp_sessions_v1': 'not json at all',
      });
      final storage = await LocalStorageService.init();

      expect(storage.getAcpSessionId('s1', 'a1'), isNull);
    });

    test('acpSessionKey 组合出稳定且不冲突的键', () {
      expect(LocalStorageService.acpSessionKey('s1', 'a1'), 's1::a1');
      expect(
        LocalStorageService.acpSessionKey('s1', 'a1'),
        isNot(LocalStorageService.acpSessionKey('s1::a', '1')),
      );
    });
  });
}
