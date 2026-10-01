# ChatRepository 存储验证报告

- 维护者: OpenCode `opencode/mimo-v2.6-flash-free`
- 日期: 2026-09-30
- 唯一维护文件: `test/data/chat_repository_test.dart`（本报告除外）
- 未修改: 业务层 `lib/**`、UI、其他测试文件（本轮）

## 结论

- `test/data/chat_repository_test.dart` 当前 **18/18 全部通过**（非 17 项）。
  用例数核对：第 1 轮 11 项 + 守卫 3 项 + chat_tools 长输出 4 项 = 18 项；
  需求口径的 17 项与实际不符，实际为 18 项，`grep -c "^  test("` 与测试输出 `+18` 一致。
- 本轮 4 项（长输出分离存储）全部通过：emoji 分段拼接、4096 预览、预览重存、导出全文、
  删除级联、页参数拒绝。
- `dart format --output=none --set-exit-if-changed` 通过；`flutter analyze test/data/chat_repository_test.dart`
  无 issue。**本轮无失败，无需上报 root 修复项。**

## 命令与证据

| # | 命令 | 结果 |
|---|---|---|
| 1 | `flutter test test/data/chat_repository_test.dart -r expanded` | exit=0，`+18 All tests passed!` |
| 2 | `flutter test test/data/chat_repository_test.dart`（复跑） | exit=0，`+18 All tests passed!` 00:02 |
| 3 | `flutter test test/data/{chat,agent,server,nas_index}_repository_test.dart -r expanded` | exit=0，`+48 All tests passed!` |
| 4 | `dart format --output=none --set-exit-if-changed test/data/chat_repository_test.dart` | exit=0，0 changed |
| 5 | `flutter analyze test/data/chat_repository_test.dart` | exit=0，No issues found! (0.6s) |

耗时记录（`Stopwatch`，仅记录不设毫秒阈值）:
`migrate500Sessions=102ms save10000Messages=106ms list30=1ms listOffset470=1ms loadLatest50of10000=1ms`

## 用例清单（18）

chat_tools 长输出分离存储（本轮新增 4 项，对应 `chat_repository.dart:42,209-245,185-194,197-207`）:
1. `large tool output pages behind a 4096 preview and reassembles exactly`
   — 消息页工具 `output` 仅 4096 字符（等于原文末 4096，不含 `head`），`hasMoreOutput=true`、
   `outputLength=30013`；默认页 `nextOffset=16384`；按 4096 分页循环拼接结果与原文
   `head😀🙂 + x*30000 + 🚀end` 完全相等且含 emoji，页数 > 1。
2. `re-saving the preview keeps the stored full output and both exports carry it`
   — 取回预览快照后再次 `saveSession`：消息页仍是 4096 预览，`loadToolOutput(limit:65536)`
   仍返回完整原文；`exportSession` 与 `exportAll` 的 `toolExecutions.output` 均为完整原文。
3. `deleting a session cascades to chat_tools rows` — 删除前 `chat_tools` 1 行
   (`m0/t1`)，`deleteSession` 后 `chat_tools`=0、`chat_messages`=0、`loadSession` 为 null。
4. `loadToolOutput rejects invalid page parameters` — `offset:-1`、`limit:0`、`limit:65537`
   均抛 `ArgumentError('CHAT_OUTPUT_PAGE_INVALID')`；参数合法但工具不存在时抛
   `StateError('CHAT_TOOL_OUTPUT_NOT_FOUND')`（两者不混淆）。

安全守卫（第 2 轮 3 项）:
5. `saveSession never moves an existing session to another server or agent`
6. `saveSession rolls back instead of overwriting an occupied seq`
7. `a stale snapshot queued behind renameSession cannot restore the title`

核心存储行为（第 1 轮 11 项）:
8. `legacy JSON migration is idempotent and never rewrites rawChatSessions`
9. `migration keeps message ids and counts while loadSession pages backwards`
10. `listSessions isolates records by server and agent`
11. `listSessions returns a 30-row summary page with hasMore`
12. `saving the last page keeps every earlier message`
13. `corrupt legacy JSON never reads as an empty database`
14. `an unreadable database falls back to raw session records`
15. `reopening the database marks streaming messages interrupted`
16. `deleteSession removes only the targeted session`
17. `rename and exports reflect the stored history`
18. `10000-message session and 500-session listing record their timings`

## 失败历史（均已修复，当前无未决失败）

- F1 `chat_repository_test.dart:270`：回溯分页按“新页→旧页”收集却断言全局升序 → 改为
  `pages.reversed.expand` 展平。
- F2 `chat_repository_test.dart:631`：用 `copyWith(serverId: null)` 清空归属无效
  （`ChatSession.copyWith` 为 `serverId ?? this.serverId`），改为直接构造 `ChatSession(serverId: null, agentId: null)`。
- 第 3 轮（chat_tools）：0 失败。

## 范围与未执行

- 未跑全量测试套件、未 `flutter build`、未打包、未 ADB、未改动业务/UI/其他测试。
- 每个用例使用 `Directory.systemTemp.createTemp('valhalla-chat-repository-')` 并注入
  `databasePath`，不读写生产 `valhalla_chat.sqlite3`；`tearDown` 递归清理（含 `-wal/-shm`）。
- 参考：对 `lib/data/models/chat_session.dart` 与本测试文件的针对性 analyze 无 issue；
  `lib/core/providers/ai_chat_provider.dart`(31) 与 `lib/data/repositories/chat_repository.dart`(1,
  `unnecessary_underscores` at line 76) 存在既有 info 级 lint，属 root 代码风格，未代改。
