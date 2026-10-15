# ACP UI 最终源码审查与回归闭环

范围：单个活动聊天的 50ms 流式更新、共享 Agent 会话及 50 条历史分页。
下列前两节保留 Batch 4 时的原始审查／红测，不代表当前仍未修复；全部已由
AgY 后续批次及最后的窄化 core 修复闭环，证据见末节。根监听没有逐 token
setState；普通消息直接
select 原 ChatMessage；输入／权限／认证 helper 已接收局部 WidgetRef；失败动作
没有调用 sendMessage，连接动作已接入 reconnectCurrentAgent，这些边界已落地。

## 历史发现（Batch 4，现已解决）

1. **分页前插会丢消息子树状态** — `ai_chat_view.dart:1650` 附近的
   ListView.builder 仍无 findChildIndexCallback。旧消息向后移动时，只有子项 key
   不能让 Sliver 找回原索引；已展开 thinking／工具／错误详情可能重建折叠。
   最小修复：按外层 KeyedSubtree 的稳定 key 返回新 index，并计入加载更早头行。
   根代理的 prepend 状态回归应覆盖这一点。

2. **真实本地历史失败没有重试入口** — `ai_chat_view.dart:4749` 的重试 handler
   只挂在消息 failureCode 卡；但 core 的 CHAT_HISTORY_LOAD_FAILED 和
   CHAT_MESSAGES_LOAD_FAILED 只写 lastErrorCode。`_ChatErrorBanner`（5290 起）
   除 Agent 管理外只有详情，因此初次空消息读取／会话列表读取失败无法点击
   对应重试；消息 handler 中 messages.isEmpty 的分支也不可能从消息卡到达。
   最小修复：为全局错误区域接入同一按来源路由的显式动作：列表
   searchSessions(currentQuery)、空消息 selectSession(sameId)、有 offset 的
   loadOlderMessages；无目标／unsupported／ambiguous 才仅详情。

3. **未知消息 Agent 被当成当前 Agent** — `ai_chat_view.dart:5090` 的
   matchesAgent，以及 4675 起各 handler，都放行 message.agentId == null。
   旧版 assistant 可无 agentId；core 显式认证重试 copyWith 会保留 null，同时
   新失败写入 failureCode。共享会话从 A 切 B 后，该失败动作会登录／设置／
   重连 B。最小修复：无法明确证明来源的旧消息只给详情，或使用已存在且唯一
   可验证的会话归属；不能把 null 解释为任意当前 Agent。异步 SSH 重连还应
   固定点击时 server connectionKey／Agent／session，而不只比较结束时字段。

4. **认证发现卡遗漏自身状态订阅** — awaiting-auth 的局部 Consumer（2260 起）
   只选择 isConfirmed／hasChallenge／showDiscovery 三个布尔值；
   `_buildAwaitingAuthDiscoveryAction`（3538）从一次性 state 读取 isLoadingSettings、
   isGenerating、isAuthenticating、authError，却只 watch SSH。
   在同一旧 awaiting 消息上重新发现认证时，loading 或 authError 单独变化不会
   刷新按钮／错误文字。另 `_buildAuthChallengeCard` 观察 authInfo 而不观察
   authChallenge 本身，challenge.methods 单独变化会保留旧选项。
   最小修复：在各局部 Consumer 中直接 select 这些实际读取字段和 challenge；
   不恢复根完整 watch。

5. **已有身份不匹配说明丢失，不应放宽旧测试** — `_ChatErrorBanner`（5290 起）
   先分类所有非空代码；CHAT_SESSION_IDENTITY_MISMATCH 因此只显示泛化的
   other 标题，而不再显示已有的中英文「切换到匹配服务器／Agent」说明。
   AGENT_NOT_READY 的专用标题分支也因 presentation 必定非 null 而不可达。
   最小修复：在通用分类标题之前保留这些稳定代码的已有本地化摘要；原始代码
   仍只在展开详情出现。`ai_chat_session_isolation_test.dart` 的 EN/ZH 原断言
   正确，保持不变，不把预期改成泛化错误。

6. **新错误卡触控区不足** — `_MessageFailureCard` 的动作minimumSize为44×32、
   详情IconButton强制28×28、复制24×24；`_ChatErrorBanner`详情／复制同样缩小。
   本轮约定至少44dp点击区，不能为紧凑布局牺牲无障碍。保留小图标本身，放大
   触控盒，窄屏／2倍字号动作可换行；不要改小系统字体来容纳一行。

## 早期红测（保留历史记录）

根代理负责 stream／prepend 测试。另按 root 要求新增专用失败动作 widget 回归，
覆盖全局列表／初次消息历史重试与 legacy-null Agent 详情降级；应保留当前红测
交给 AgY，不为通过测试绕开缺失入口。未进行真实 ACP／SSH 操作。

`flutter test --no-pub test/features/acp_failure_actions_test.dart --reporter expanded`
已执行：0 通过／4 失败（exit 1）。三个全局历史来源均缺 Retry Load；legacy-null
Agent 失败消息的动作实际调用当前 Agent 的 reconnect spy 1 次（预期 0）。
这是独立测试 Agent 的内存替身，没有 SSH／真实 ACP。测试只新增于该文件。
另单独运行既有 session-isolation 的 friendly-message 用例，exit 1：英文身份
不匹配提示未找到，尚未走到中文断言；测试文件未改动。

## Batch 6 后窄化复查（历史记录，现已解决）

前述 1、3、4、5 已在源码中修正：消息列表有 key → 新 index 映射；共享会话
legacy-null Agent 降级详情；认证 loading／error／challenge.methods 有局部订阅；
已知身份错误保留本地化说明。SSH 重连在 await connect 前固定 connectionKey、
Agent ID、session ID，并在 await 后校验；随后 core 再执行 busy／身份守卫。
未发现新的自动发送路径。44dp 实测仍为 40dp 的问题由 root 交下一批处理。

**当时仍需修复：全局历史动作未按可服务的来源／当前目标降级。**
`ai_chat_view.dart:676` 总是传 onReloadHistory；5482 附近仅按分类展示按钮，
但 656 的 handler 只处理两个 CHAT_* 本地来源。真实
ACP_HISTORY_IMPORT_FAILED／ACP_HISTORY_IMPORT_INCOMPLETE 会得到无操作按钮；
CHAT_MESSAGES_LOAD_FAILED 在已有消息且 messageOffset == 0 时同样无操作。
错误 Consumer 只观察 errorCode，当前加载／目标／分页条件变化也不会更新入口。
最小修复：只为可确认且可执行的本地列表／空消息／前页路由提供 callback，
观察它所需的稳定身份、busy、消息数和 offset，并在点击时复核；其他仅详情。
callback 固定渲染时 server.connectionKey／Agent ID／session ID／errorCode，
点击时与当前值逐项核对；不能只闭包保存 errorCode 再读取任意新目标。同码仍留在
全局状态时，切到另一会话不应让旧 callback 重试新会话的前页；身份变化应刷新
动作资格，无法确定错误归属时只显示详情。
本地 repository 历史读取不依赖 SSH，不能以离线一概禁用；远端失败不能冒充本地
分页重试。不要清除旧诊断或新增自动发送。

按 root 要求追加两项负向 widget 回归（远端两个代码合为一项、offset-zero 一项），
原八项保留；尚未运行，等待 AgY batch 7 完成。此次复查没有修改 UI／core。

## 最终状态与实际证据

上述历史发现已解决，未留下本次审查确认的未修复 blocker：

- 消息列表使用稳定 key 与 findChildIndexCallback，前插时保留子树状态；根层
  不恢复整份状态 watch。根代理的 stream／prepend 两项通过。
- 全局历史区按来源提供 searchSessions(currentQuery)、同 id 空消息读取或
  offset > 0 前页读取。远端导入失败／不完整及 offset-zero 只提供详情；局部
  订阅身份、busy、消息数、offset，并在点击时检查 errorCode 和捕获目标。
  本地读取没有增加 SSH 在线要求。
- 共享会话 legacy-null 消息不再操作另一 Agent；SSH 重连跨 await 校验
  connectionKey／Agent／session，随后由 core 再守卫；没有新增自动发送。
- 认证 loading／authError／challenge.methods-only 变化能刷新原消息上的卡；
  既有中英文身份不匹配说明保留；错误卡在 320dp／2倍字体下无溢出，动作、
  详情和复制触控盒至少 44dp（已消除 compact density 导致的实际 40dp）。
- 最后发现的 A→B 旧全局错误重新绑定问题在 core 窄化修复：
  `selectSession` 仅在实际改变 activeSessionId 时设置 clearError。
  同会话选择保留原错误和重试语义；A 的持久化 failureCode、原消息对象与草稿
  不清除。这避免为 UI 新增错误归属框架，也不允许旧 A 错误继续生成 B 的按钮。

根代理已报告联合目标 **18／18 通过**：失败动作 10 项、session isolation 6 项、
stream／prepend 2 项；此结果在最后一行 selectSession core 修复之前获得。
最后一行修复另有 provider 回归先红后绿，并执行
`flutter test --no-pub test/core/ai_chat_provider_test.dart --reporter expanded`，
**50／50 通过，exit 0**。新回归直接证明 A 全局历史失败 → 选择已有消息且
offset > 0 的 B 后旧全局错误消失、不读取 B 的历史；同 id 不清错，A 消息失败
原因和草稿仍保留。UI 原断言未被放宽。

最终根代理报告：全量测试 **3685 通过／30 跳过**，静态分析 **0 问题**；正式
universal APK 已构建并通过 `adb install -r` 覆盖安装，安装包 SHA 校验一致。
详细 ADB 验收仍在进行，不能把安装成功当作全部设备场景通过。未测试真实 ACP／
SSH 会话或远端消息，widget 动作全部使用隔离替身；不外推到所有设备／RTL／
主题组合。本次仅更新本文审计记录，未修改源码、测试或主计划／状态文档。
