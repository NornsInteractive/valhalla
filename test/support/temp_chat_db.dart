import 'dart:async';
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
    // ENOTEMPTY on Linux or a sharing violation on Windows. Retry only these
    // transient errors; unrelated failures and exhausted retries stay visible.
    // Linux retries use real async syscalls to let the writer retire. Windows
    // also allows a bounded wait for native handles to close (see below).
    if (!dir.existsSync()) return;
    for (var attempt = 0; ; attempt++) {
      try {
        await dir.delete(recursive: true);
        return;
      } on FileSystemException catch (error) {
        final code = error.osError?.errorCode;
        if (Platform.isWindows && (code == 32 || code == 145)) {
          if (attempt >= 20) rethrow;
          // SQLite isolates can still be releasing their Windows file handles.
          // Run the bounded delay outside testWidgets' FakeAsync zone, whose
          // clock is no longer pumped during teardown.
          await Zone.root.run(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        } else if (code != 39 || attempt >= 4) {
          rethrow;
        }
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
