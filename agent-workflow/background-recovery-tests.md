# 前后台连接与会话恢复：回归测试交付（2026-09-30）

范围：只新增/修改 `test/**`。未改生产代码、UI、ARB；未构建、未安装、未提交。
模型：主/辅助均 `opencode/space-bunny-free`（本地目录与 Zen 文档均为零定价）。

## 1. 交付的测试文件

| 文件 | 用例数 | 覆盖点 |
| --- | --- | --- |
| `test/core/background_recovery_probe_test.dart`（新） | 16 | `SSHClientManager` 探活单飞、心跳定时器与手动探测合并、后台跳过心跳、宽限期、后台旧代次隔离、`recentlyVerified` |
| `test/core/background_recovery_lifecycle_test.dart`（新） | 15 | 协调器 resumed 单飞、代次隔离、可见性上报、保活集合、`appVisibilityProvider` |
| `test/core/background_recovery_reconnect_test.dart`（新） | 11 | `ReconnectController` 单飞、断开/换服务器/后台的迟到结果、`maintains` |
| `test/core/background_recovery_credential_race_test.dart`（新） | 3 | provider 级凭据竞态：断开后过期凭据不得用于重连；每次重试重读凭据 |
| `test/core/background_recovery_chat_state_test.dart`（新） | 9 | ACP `recoveryStatus` 迁移、内容保留、单飞、后台不恢复、`checkpoint`、registry 就绪更新 |
| `test/data/chat_replay_merge_test.dart`（新） | 13 | `ChatRepository.mergeReplayBatch` 历史重放去重与 fail-closed |
| `test/core/connection_lifecycle_test.dart`（改） | 15 | 补齐新 API 假实现；重写 detached 两个用例 |
| `test/core/keep_alive_service_test.dart`（改） | 33 | 按新的前台服务契约（`isRunning() \|\| start()`）修正断言，并新增「被系统回收后重新 start」 |

合计 115 个用例，全部通过。

## 2. 运行结果（`--reporter expanded`，退出码为真实退出码）

命令形式：`flutter test test/<file> --reporter=expanded > agent-workflow/bg-<name>.log 2>&1; echo $?`

```
core/background_recovery_probe_test           EXIT=0  +16 All tests passed
core/background_recovery_lifecycle_test       EXIT=0  +15 All tests passed
core/background_recovery_reconnect_test       EXIT=0  +11 All tests passed
core/background_recovery_credential_race_test  EXIT=0  +3  All tests passed
core/background_recovery_chat_state_test      EXIT=0  +9  All tests passed
core/connection_lifecycle_test                 EXIT=0  +15 All tests passed
core/keep_alive_service_test                   EXIT=0  +33 All tests passed
data/chat_replay_merge_test                    EXIT=0  +13 All tests passed

dart analyze（仅上述 8 个文件）   EXIT=0  No issues found!
dart format --set-exit-if-changed（同上 8 个）  EXIT=0  0 changed
```

日志：`agent-workflow/bg-<文件名>.log`、`agent-workflow/bg-analyze.log`、`agent-workflow/bg-format.log`。

## 3. 关键断言（不可弱化的部分）

- 探活：并发 `verifyAlive` 返回同一个 future 且只发一次 `ping`；宽限期内迟到的回复保连接；两次超时才判死，且判死前不重复发 ping（实测 ≥2 个超时窗口）。
- 心跳定时器（用 `debugRegisterClient(startKeepAlive: true)` + 短间隔真实驱动 `Timer.periodic`）：后台期间定时器不发起任何探测，回前台恢复；心跳探测在飞时手动 `verifyAlive` 不新增 `ping` 并复用同一结果。其余用例保持 `startKeepAlive` 默认 `false`，不启动定时器。
- 旧代次：探测在飞时进入后台/回前台，旧截止时间不得 `disconnect`；旧代次结果不得改 `ReconnectState`、不得为已切换的服务器排重连。
- 凭据竞态：凭据读取期间用户 `userDisconnect` 后，读到的凭据不得触发 `reconnectClient`（断言 `ssh.calls` 为空）。
- ACP 保留：connected→disconnected 后 `activeSessionId` / 消息内容 / `draftText` / `activeAgentProfile` 全部不变，状态只翻成 `reconnecting`；重连中 `sendMessage` 被拒绝但草稿可编辑。
- 恢复成功：必须 `recoveryStatus == idle`、`acpSessionRestored == true`、load 增量 == 1、resume 增量 == 1、`session/new` 增量 == 0、prompt 数 == 0、消息不重复、本地会话仍只有 1 条。
- 无回放能力：必须恰好 `incomplete`（不是 `anyOf(idle)`），历史保留，不新建会话、不发 prompt。
- `checkpoint()`：远端 prompt 保持挂起时 `isGenerating` 仍为 true，新增报文里不含 `session/cancel`，会话已落盘；测试收尾显式 `finishHeldPrompt()` 并 await send future。
- 重放去重：同一批重放两次行数不变、本地 id/`createdAt` 不变；更短快照一律拒绝并整体回滚；共享会话缺远端身份时 fail-closed（`ACP_HISTORY_REPLAY_AMBIGUOUS`）；`CHAT_SESSION_NOT_FOUND` / `CHAT_SESSION_IDENTITY_MISMATCH` 均拒绝。

## 4. 过程中修掉的既有测试问题（原因在生产侧，不在断言）

1. `connection_lifecycle_test.dart` 的 `_FakeSshManager` 未实现新增的 `setAppInBackground` / `recentlyVerified`，整个文件 13 个用例在 `noSuchMethod` 抛 `UnimplementedError`。已补实现（仅新增成员，原断言不变）。
2. `KeepAliveCoordinator._sync` 改为串行链（`_syncTail`）后，`onPaused` 里的 `unawaited(addSession)` 需要多一个微任务才落到原生。原用例在断言前少了这一步，补 `await pumpEventQueue()`，`startCalls == [1]`、`updateCalls == [1, 1]` 等断言全部保留。
3. `paused` 现在幂等（重复后台回调不再重复同步），原「断开的服务器会被移出保活集合」用例靠第二次 `onPaused` 触发同步，已改为 `onPaused → 断开 → onResumed`，`activeCount == 0` 的原意图保留。
4. `_syncOnce` 改为 `isRunning() || start()` 后，「第二个连接」不再重复 `start`。已把用例改成显式断言新契约（`startCalls == [1]`、`updateCalls == [1, 2]`、无 `stop`），并新增「原生报告未运行时重新 start」覆盖回收场景。附带一处措辞小事：`_syncOnce` 的注释仍写「每次同步都尝试 start」，而实现是先问 `isRunning()` 再决定是否 start；请 Codex 顺手把注释对齐成实际语义，断言不受影响。

## 5. 需要业务方确认的一点（当前测试按实际行为断言，未当作缺陷）

1. **共享会话的重放只能按远端 id 更新，不能追加**：`mergeReplayBatch` 里 `if (shared || ordinal != count) throw` 只挡「按序号回退」和「追加」两条路；已有消息如果带可靠的每 agent `remoteMessageId`，仍然可以原地更新（`test/data/chat_replay_merge_test.dart` 的「共享会话可以按远端 id 补齐已有消息」）。真正被拒绝的是：共享会话里没有远端身份的消息，以及任何会让 `ordinal != count` 的追加。也就是说共享会话的真实断线恢复能补齐已识别的历史，但**新产生**的那部分无法补，会落到 `incomplete`。请确认这是有意的边界；若是，`incomplete` 的文案应说明「共享会话中新产生的输出无法补齐」。

## 6. 边界

- 未运行全量 `flutter test`、未 `flutter build`、未 ADB、未打包；上述退出码只覆盖本次负责的 8 个文件。全量门禁与打包由 WorkerB / release 负责。
- 未改动生产/UI/ARB（`debugRegisterClient(startKeepAlive: true)` 之类的接缝是 Codex 侧已存在的，本次直接使用）；`git status` 中生产文件的改动全部来自 Codex/AgY 并行进行。
- 剩余无阻塞项：本次范围内所有测试通过、`dart analyze` 干净、`dart format` 无改动。
