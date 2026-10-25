# SSH + ACP UI 实施状态报告 (2026-10-24)

## 一、范围与所有权约束遵循

- **UI 范围**：仅修改 [`lib/features/terminal/terminal_view.dart`](file:///workspace/projects/valhalla/lib/features/terminal/terminal_view.dart)、[`lib/features/chat/ai_chat_view.dart`](file:///workspace/projects/valhalla/lib/features/chat/ai_chat_view.dart)、17 国语言 ARB 文件（`lib/l10n/*.arb`）及本文档。
- **只读约束**：未修改任何 Provider、Model、Runtime、Test 文件；未执行测试、格式化、代码生成、构建、ADB 或 Git 操作。
- **保留既有成果**：完整保留已上线的会话初次加载触底逻辑（`_hasClampedToBottom`、多帧 Clamp）以及外层 `KeyedSubtree` 的 key 绑定与现有终端快捷栏布局，未作误修。
- **强类型接线规范**：已全面移除所有 `dynamic`、`NoSuchMethodError` 拦截及假回退接线；会话删除绝不发生失败后降级本地删除；所有状态与方法均以强类型接入。

---

## 二、本次交付功能详情

### 1. SSH 终端（已完整接线 Root 接口）
- **页签状态小标记**：
  - 在每个 Tab 的 `InputChip.avatar` 中，使用 `ValueListenableBuilder<TerminalConnectionState>` 单独订阅 `tab.bridge.stateListenable`。
  - 状态变化时仅局部重画该页签头像右下角 5px 微型状态圆点（绿色已连接、蓝色连接中、橙色离线、红色错误），完全不引起 TabBar 重构，不重画底部快捷按键栏动画。
- **重新打开/重连终端菜单**：
  - 在每个 Tab 长按/右键菜单（`_showTabOptions`）中新增「重新连接终端」项。
  - 在终端右上角更多菜单（`terminal_more_button`）新增「重新连接终端」项。
  - 均捕获当前目标 `TerminalHistoryRecord.targetFor(activeServer)`，并强类型调用 `notifier.reconnectTab(tab.id, expectedTargetKey: targetKey)`。
- **Tab 关闭防护与目标校验**：
  - 强制至少保留一个页签：当 `tabs.length <= 1` 时不显示关闭选项或执行拦截。
  - 弹窗时捕获目标 `targetKey`；用户确认关闭后，再次校验当前服务器未发生漂移，才强类型调用 `notifier.closeTabById(tab.id, expectedTargetKey: capturedTargetKey)`。
  - **普通终端与 tmux 差异化弹窗文案**：
    - 普通终端（Plain/Mosh）：明确警告将断开连接，正在前台运行的程序可能会被终止（确认按钮为「结束并关闭」，标红高亮）。
    - tmux 终端：明确提示仅从当前视图分离（detach），远端会话和后台任务继续保留运行（确认按钮为「分离并关闭」）。
  - **Context-After-Async Lint 修复**：关闭确认弹窗及重连后均加入 `context.mounted` 防护，彻底解决异步间隔后使用 `context` 的潜在告警。

### 2. ACP 智能会话 UI（已全量强类型接入）
- **运行中指示 Banner（Stack Overlay 布局与全宽保障）**：
  - 不在主体 `Column` 中插入新行，杜绝推移或抖动消息列表区；
  - 放置于 `Expanded(child: Stack(fit: StackFit.expand, children: [Positioned.fill(child: _buildMessageList()), Consumer(...)]))` 的 `Positioned(top: 0, left: 0, right: 0)` 浮层内；
  - 显式声明 `fit: StackFit.expand`，彻底解决无 banner 时 `Consumer` 返回 `SizedBox.shrink()` 导致 `Stack` 收缩为 0 宽度的渲染几何缺陷，保证消息列表在有无 banner 状态下均严格保持 100% 满视口宽度；
  - 严格且仅在 `serverRun != null && !isViewingRun && serverRun.isBusy == true` 时展示，强类型消费 `AcpActiveRun`；
  - 点击「返回正在运行的会话」强类型调用 `ref.read(aiChatProvider.notifier).returnToRunningSession()`。
- **删除会话弹窗（`inspectSessionRuntimes`、防误关与 `RadioGroup`）**：
  - 打开弹窗时异步调用 `ref.read(aiChatProvider.notifier).inspectSessionRuntimes(sessionId)`；
  - 列表中直观展示受影响的本 App 托管运行实例及其状态（`runtimeKey` 与 `state`，如 `running` / `waiting_permission` / `completed`）；
  - 离线（无连接）时依然支持本地记录删除；
  - 若该会话没有托管的运行实例（`managedKeys.isEmpty`），远端清理选项自动置灰禁用并标注说明；
  - 使用现代 `RadioGroup<bool>` 封装单选，彻底消除 `RadioListTile` 弃用的 `groupValue` / `onChanged`；`onChanged` 满足 `ValueChanged<bool?>` 类型契约；
  - 设置 `barrierDismissible: false` 并外包 `PopScope(canPop: !isDeleting)`，彻底杜绝正在删除时因误触外部阴影或系统返回键导致弹窗意外关闭；
  - 远端清理失败时保留弹窗与用户的模式选择，错误在弹窗内直接显示，严禁静默回退或降级为仅本地删除；
  - 传参 `expectedServerKey` 严格传 `connectionKey.toString()`（移除多余的空安全调用）。
- **审批卡片收紧与详情弹窗（防溢出 + 命令置顶直达 + 软键盘与小视口自适应）**：
  - **主卡收紧**：标题 Row 增加 `Flexible` 防护，在 320dp 宽度及 2倍字体下绝不发生溢出；摘要收紧为最多 2 行（`maxLines: 2, overflow: TextOverflow.ellipsis`）；主卡不再展示长命令，仅保留「查看详情」入口与快速放行/取消动作；
  - **命令区置顶与响应式 Wrap**：详情弹窗内将命令及「复制命令」按钮置于长描述之前；原固定 `Row` 重构为自适应 `Wrap(alignment: WrapAlignment.spaceBetween, ...)`，彻底解决 320dp 宽度 + 2 倍字体下 225px 的 RenderFlex 横向溢出，复制按钮始终保持在视口可见与可点击区域（`copyRect.right <= 320, copyRect.bottom <= 640`）；
  - **详情弹窗视口约束**：高度严格扣除安全区及软键盘 `viewInsets` 后取 80%，上限严格封顶在实际可用高度内（不再使用过大的固定 240 下限强制撑大视口导致键盘弹出时遮挡操作按钮），操作按钮固定置底并始终可用；
  - **强类型安全审批接线**：打开详情时捕获 `state.permissionCompleter` 与 `activeServer.connectionKey.toString()`，所有审批按钮直接调用 `respondToPermission(optionId, expectedCompleter: expectedCompleter, expectedServerKey: expectedServerKey)`，彻底杜绝过期弹窗误同意新审批请求；
  - 彻底修正多余代码闭合导致的类层级与语法错误。
- **停止生成按钮定向保护**：
  - 停止按钮捕获当前 `expectedServerKey: connectionKey.toString()` 与 `expectedSessionId: sessionId`，调用 `stopViewingRun`，防止误停新切换的会话；清理多余 `connectionKey?.toString()` 语法。
- **草稿保护（BUSY / PREPARING）**：
  - 在 `_handleSend` 中捕获异常或状态码，当被 `ACP_RUNTIME_SERVER_BUSY` 或 `PREPARING` 拒绝时，即使 `afterState.isGenerating == true`，依然精准保留未发送的输入文本于 `_promptController` 及 draft 状态中，绝不丢失用户输入。
- **运行中会话与 Agent 自由浏览**：
  - 会话列表、新建会话与 Agent 切换在生成期间不作全盘禁用，允许选择查看；
  - 当同服务器正在执行其他会话任务时（`state.isServerBusy && !state.isViewingRun`），发送入口置灰禁用并悬浮展示 `acpServerBusySendDisabled`，并在 `_handleSend` 中拦截并发提交，严格禁止同服务器并发发送。
- **回到最新按钮与未读计数（绝对末尾索引定位）**：
  - 未读消息计数摒弃易受历史分页干扰的列表长度（`messages.length`），改为严格跟踪绝对末尾索引 `_lastSeenEndIndex = messageOffset + messages.length` 及末尾消息 ID `_lastSeenTailMessageId`；
  - 当向前加载历史消息时（`messageOffset` 变小但末尾不变），绝对末尾索引与末尾 ID 恒定，完全杜绝将翻阅的历史消息误计为未读；仅当末尾追加新消息时才递增未读数；
  - 当用户在聊天界面向上滚动（`!_userNearBottom`）时，右下角浮现「回到最新」按钮并以 `Badge.count` 展示未读消息增量；
  - 点击按钮或手动滑至底部时平滑滚动（`_scrollToBottom()`），并同步重置未读数与更新已读末尾标记。

### 3. 多语言本地化（17 种语言全量补齐）
在 `lib/l10n/app_*.arb` 中全部增补了 23 个新键（涵盖 en, zh, zh_Hant, ja, ko, de, fr, es, pt, it, ru, ar, hi, id, th, tr, vi），所有 ARB 文件已校验均为严格合法 JSON：
- `terminalReconnectTab`
- `terminalCloseTabConfirmTitle`
- `terminalClosePlainConfirmMessage`
- `terminalCloseTmuxConfirmMessage`
- `terminalCloseActionTerminate`
- `terminalCloseActionDetach`
- `acpRunningSessionIndicator` (含 `{agentName}` 占位符)
- `acpReturnToRunningSession`
- `acpServerBusySendDisabled`
- `deleteSessionLocalOnlyOption`
- `deleteSessionStopAndPurgeOption`
- `deleteSessionPurgeRemoteWarning`
- `deleteSessionNoManagedRuntimes`
- `deleteSessionAffectedRuntimes`
- `deleteSessionInspectingRuntimes`
- `deleteSessionOfflineNotice`
- `permissionViewDetails`
- `permissionDetailsTitle`
- `permissionToolLabel`
- `permissionCommandLabel`
- `permissionCopyCommand`
- `permissionCommandCopied`
- `chatScrollToLatest`

---

## 三、接线完成状态核查

| UI 消费点 | 强类型签名 | 状态 |
| :--- | :--- | :--- |
| **终端 Tab 重新连接** | `TerminalNotifier.reconnectTab(String id, {required String expectedTargetKey})` | 已强类型接线 |
| **终端 Tab 按 ID 关闭** | `TerminalNotifier.closeTabById(String id, {required String expectedTargetKey})` | 已强类型接线，带目标校验与 context.mounted 防护 |
| **运行态浮层 Banner** | `Positioned(top: 0, ...)` 位于 `Stack` 浮层，`serverRun.isBusy == true` | 已完成，不挤压推移消息列表 |
| **返回运行中会话** | `AiChatNotifier.returnToRunningSession()` | 已强类型接线 |
| **会话运行时检查** | `AiChatNotifier.inspectSessionRuntimes(String id)` | 已强类型接线，弹窗展示实例状态列表 |
| **会话删除与远端清理** | `AiChatNotifier.deleteSession(String id, {bool stopAndClearRemote, String? expectedServerKey})` | 已强类型接线（弹窗错误内显，保留选择，无降级回退） |
| **删除中防意外关闭** | `barrierDismissible: false` + `PopScope(canPop: !isDeleting)` | 已完成，防止删除中误触阴影或系统返回键关闭 |
| **定向停止生成** | `AiChatNotifier.stopViewingRun({required String expectedServerKey, required String expectedSessionId})` | 已强类型接线，防止误停新会话 |
| **安全审批响应** | `AiChatNotifier.respondToPermission(Object? selection, {required Completer<String?> expectedCompleter, required String expectedServerKey}) -> bool` | 已强类型接线，捕获 Completer 与 ServerKey |
| **审批主卡与详情弹窗** | 主卡最多 2 行摘要 + Flexible 标题防溢出；详情高度自适应键盘（不设超标下限），固定操作栏防键盘遮挡 | 已完成，语法结构严格闭合 |
| **草稿保护** | `_handleSend` 遇 `SERVER_BUSY` / `PREPARING` 即使 `isGenerating` 仍保留草稿 | 已完成，防止用户输入丢失 |
| **并发会话与 Agent 切换** | 允许浏览与切换，同服务器忙碌时禁用发送 | 已完成 |
