# 恢复核心接口与验证交接

状态：核心源码已实现；未运行测试、格式、分析、生成或构建，交 OpenCode。
UI 仍由原 AgY 会话接入；本文件不代表 UI 已完成或通过验收。

## 纯投影 API

文件：`lib/core/utils/session_recovery_summary.dart`。

```dart
enum SessionRecoveryMode { acp, cli }

typedef SessionRecoveryEntry = ({
  SessionRecoveryMode mode,
  SessionRecoveryStatus status,
});

List<SessionRecoveryEntry> sessionRecoveryEntries({
  required SessionRecoveryStatus acp,
  required SessionRecoveryStatus cli,
  SessionRecoveryMode? preferredMode,
});
```

`SessionRecoveryStatus` 沿用 `lib/data/models/session_recovery_status.dart`，
ACP／CLI provider 也已导出此类型。函数无 Flutter／Riverpod 依赖，不读取
路由、连接管理器、服务器或会话，不执行重连、消息、审批、终端命令或持久化。

返回全部非 idle 对象，规则如下：

1. `preferredMode` 对应当前可见 ACP／CLI 页面；该模式非 idle 时排第一。
   其他页面传 `null`；不要拿后台保存的聊天模式代替当前路由。
2. 其余按 failed、incomplete、正在恢复排序；reconnecting 与 syncing 同级。
3. 同优先级固定 ACP 在前、CLI 在后；只有一个非 idle 时只返回该项；全 idle
   时返回空列表。不会把 idle 的当前页面制造成恢复对象。

顶部既有 SSH 状态仍由 UI 优先处理。SSH 无须显示时，使用返回列表首项；
详情对整个列表分别显示阶段及重试。`entry.mode` 是重试路由身份：ACP 使用
`aiChatProvider.notifier.recoverConnection()`，CLI 使用
`cliChatProvider.notifier.recoverConnection()`。不要使用 `else if` 合并不同对象。
UI 应在 failed／incomplete 时提供已有显式重试，syncing／reconnecting 保留
进度状态；任一显式重试都不能调用发送或审批接口。

## 目标身份与显示

服务器／会话名称及标识直接使用既有 provider 当前快照，投影不复制聊天状态：

- ACP：`activeAgentProfile?.serverId`、`activeAgentProfile?.id`、
  `activeSessionId`；显示 `activeSession?.title`。
- CLI：`serverId`、`activeAgent?.id`、`activeSession?.id`；显示
  `activeSession?.title`。
- 服务器名称：现有 active server profile 的名称，仅在其 ID 与该对象匹配时使用。

详情若保存打开时的行快照，点击重试前比较当前 server／agent／session 标识；
目标改变则刷新详情，不能让旧会话名称的按钮操作新目标。若详情实时订阅当前
目标，重试沿用当前行对应 notifier。该边界无需新增连接管理器或会话仓库。

## 生命周期修复

`ConnectionLifecycleCoordinator.onResumed()` 过去只要 `_resuming != null`
就复用旧 Future。A 的探活尚未结束时切换 B，再来一次 resumed，会返回 A 的
Future；A 的结果虽然被已有目标校验丢弃，B 却没有独立验证。

现在只在 `ServerProfile.connectionKey` 相同时合并；目标变化启动新一代恢复，
旧 Future 的完成仍不能清掉新的 `_resuming`。同 ID 的 host／port／username／
认证模式变化也会分开，显示名称变化仍合并。沿用已有 SSH 探活和重连机制。

已只读检查 `ReconnectController` 的 `_attemptEpoch`／timer 合并、生命周期
epoch 校验和 ACP／CLI 的 `_recovering` Future 合并；未发现需要本轮重写的
共同机制，因此没有修改 reconnect、ACP、CLI provider。现有缓存、草稿、
滚动和选择不由本投影处理；它不会清除或替换任何状态。

## OpenCode 必须补充和执行的验证

- 新建纯投影回归：遍历 5×5 个状态组合及 preferredMode 为 null／ACP／CLI，
  断言非 idle 无遗漏、无重复；首选非 idle 必须第一；其余状态优先级正确。
  显式覆盖 ACP syncing + CLI failed 在其他页面时 CLI 第一，在 ACP 页面时
  ACP 第一；ACP incomplete + CLI failed；idle 首选不遮蔽另一对象；同级顺序稳定。
- `test/core/background_recovery_lifecycle_test.dart`：保留同目标两次 resumed
  返回同一 Future／只探活一次；新增 A 的 probe pending 时切到 B，并在 A 完成
  前 resumed，断言两个 Future 不同且 B 已独立探活。先结束 A，再 resumed B，
  应仍复用 B 的 pending Future，证明旧完成不能清除新请求。
- 同 ID 更换 host 应新建恢复；同连接配置只改名称应合并。旧目标失败不能将新
  目标标为 reconnecting；暂停／dispose 后旧探测结果不能触发新恢复。
- 继续运行既有 lifecycle／reconnect／background recovery 专项，特别是合并
  探活、重复前后台通知、快照与草稿保留、重连不自动发 prompt／审批／终端输入。
- AgY 接入后补 UI：同时存在 ACP 与 CLI 恢复时详情有两项，各重试只调用对应
  notifier；当前可见路由优先及 SSH 状态优先；打开详情后切换目标不会错误重试。

验证仅独立测试目标；不能向当前真实 Codex 会话或生产终端发送消息、审批或输入。
