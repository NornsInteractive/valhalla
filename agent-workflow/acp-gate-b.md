# ACP 验收批次 B — 4 项小回归报告

- 模型：`opencode/mimo-v2.6-flash-free`
- 日期：2026-09-30
- 唯一新增文件：`test/infrastructure/acp_client_features_test.dart`（本报告除外）
- 未修改：`lib/**` 业务与 UI、`test/support/fake_acp_transport.dart`（复用现成能力，本轮未改桩）、其他测试文件

## 结论

4 项回归 **全部通过（4/4）**，**无实现错误，无需上报 root 修复项**。

| # | 用例 | 断言要点 | 结果 |
|---|---|---|---|
| 1 | `session/list is answered with a page and never creates a session` | 能力未声明时抛 `StateError('ACP_REMOTE_HISTORY_UNSUPPORTED')` 且不发 `session/list`；声明 `sessionCapabilities.list` 后 `cursor:'page-1'` 被记录、返回 2 条 session（含 `title`）与 `nextCursor:'page-2'`，`newSessionCount==0`、`adapter.sessionId==null` | PASS |
| 2 | `attachments send the negotiated ContentBlocks and no prompt otherwise` | `image+embeddedContext` 协商成功时 `session/prompt` 恰含 3 个块：`text`、`image`（`mimeType` + `base64Encode(bytes)`）、`resource`（`text`/`mimeType`/`uri=file:///attachments/note.txt`）；未声明能力时错误含 `ACP_ATTACHMENT_UNSUPPORTED` 且线上无 `session/prompt`；文本附件 `maxTextBytes+1` 超限时错误含 `ACP_ATTACHMENT_TOO_LARGE` 且同样不发 `session/prompt` | PASS |
| 3 | `available_commands and usage keep remote values instead of 0/USD` | `available_commands_update` 产出 2 条 `ACPCommandsChangedEvent`（name/description/input.hint 原样保留，`adapter.commands` 同步）；首轮 usage（仅 used/size）`used=4212`、`size=200000`、`cost/currency == null`（**不编造 0/USD**）；局部更新后 `used=5000` 且 `size=200000` 保留、`cost=0.37`、`currency='EUR'` | PASS |
| 4 | `captureReplay replays history on session/load only, plain restore is silent` | `captureReplay+resumeSessionId` 走 `session/load`（`loadRequests==['hist-1']`、`newSessionCount==0`）回放出 `ACPUserContentChunkEvent('历史提问')` 与 `ACPContentChunkEvent('历史回答')` 各 1 次；随后普通回合不再重复回放（仍各 1 条）；普通恢复（`captureReplay=false`）同样 `loadRequests==['hist-1']` 但两类事件均为空，回合后仍为空 | PASS |

## 执行命令与证据

| 步骤 | 命令 | 退出码 / 结果 |
|---|---|---|
| 1 | `flutter test test/infrastructure/acp_client_features_test.dart -r expanded` | 0，`+4 All tests passed!` |
| 2 | `dart format --output=none --set-exit-if-changed test/infrastructure/acp_client_features_test.dart` | 0，`Formatted 1 file (0 changed)`（首跑曾改 1 个文件，已 `dart format` 落盘后复跑） |
| 3 | `dart analyze test/infrastructure/acp_client_features_test.dart` | 0，`No issues found!` |
| 4 | `flutter test test/infrastructure/acp_client_features_test.dart test/infrastructure/acp_adapter_test.dart test/infrastructure/acp_session_resume_test.dart` | 0，`+33 All tests passed!`（4 新 + 20 adapter + 9 resume，既有用例无回归） |

## 覆盖实现点（只读核对，未改动）

- `lib/infrastructure/acp/acp_client_adapter.dart:499` `listRemoteSessions`：先 `_ensureConnection()` 后判 `sessionCapabilities?.list`，只建连接不建会话。
- `lib/infrastructure/acp/acp_client_adapter.dart:405-446`：先校验体积（`maxImageBytes`/`maxTextBytes`）再校验 `promptCapabilities.image/embeddedContext`，随后才把 `ImageContent`/`EmbeddedResource`/`TextContentBlock` 送入 `session/prompt`。
- `lib/infrastructure/acp/acp_client_adapter.dart:636-655`：`available_commands_update` 与 `usage_update` 直接采用远端字段，缺字段沿用旧值（`?? usage?.x`），不补默认值。
- `lib/infrastructure/acp/acp_client_adapter.dart:667-681`：`!_acceptContent && !captureReplay` 时提前返回；`UserMessageChunk` 仅在 `captureReplay` 下输出。

## 边界遵守

- 先写最小测试再跑；**未改任何 `lib/`、UI 代码，未查其他模块，未构建，未跑全量**。
- `test/support/fake_acp_transport.dart` 现有桩（`agentCapabilities`、`remoteSessions`、`listNextCursor`、`promptUpdates`、`loadReplayUpdates`、`newSessionCount`）已足够，本轮零改动。
- 未新增 `skip`、未删除断言；4 项完成后立即结束，未扩范围。
