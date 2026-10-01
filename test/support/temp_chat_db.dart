import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';

/// 每个用例独立的 SQLite 会话库，禁止测试读写真实应用目录。
///
/// `ChatRepository` 默认路径来自 path_provider，单元测试没有平台绑定，
/// 会在首次读写时抛 `Binding has not yet been initialized`。本辅助函数
/// 为每个用例注入临时文件，必须在测试体内调用（需要注册目录清理）。
Override tempChatRepositoryOverride() {
  final dir = Directory.systemTemp.createTempSync('valhalla_chat_test_');
  addTearDown(() async {
    // A provider may still be finishing one unawaited write while we delete, so
    // SQLite can recreate a file mid-walk and the recursive delete fails with
    // ENOTEMPTY. Retry that single case: every attempt is a real async syscall,
    // so the event loop turns in between and the writer can retire. No timers
    // here on purpose - `testWidgets` runs in a FakeAsync zone where no clock is
    // advanced during teardown, so a `Future.delayed` would hang the suite.
    // Every other IO error, and an ENOTEMPTY that survives the last attempt, is
    // rethrown, so a real leak stays visible.
    if (!dir.existsSync()) return;
    for (var attempt = 0; ; attempt++) {
      try {
        await dir.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 39 || attempt >= 4) rethrow;
      }
    }
  });
  return chatRepositoryProvider.overrideWith(
    (ref) => ChatRepository(
      ref.read(localStorageServiceProvider),
      databasePath: '${dir.path}/chat.sqlite3',
    ),
  );
}
