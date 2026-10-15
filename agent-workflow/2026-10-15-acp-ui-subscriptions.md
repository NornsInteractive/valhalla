# ACP 界面订阅拆分：AgY 实施边界

基于本轮修改前的 `lib/features/chat/ai_chat_view.dart`，行号仅用于定位方法。
本文件是源码审查后的实现指导，不是性能验收结论。保留现有 builder、控制器、
事件处理方法和布局；不新增聊天状态副本、消息仓库或 core provider。

## 先拆真正的订阅归属

根 `build` 第 868 行的 `ref.watch(aiChatProvider)` 必须移除。根层保留稳定
Scaffold／区域容器，在头栏、历史、列表框架、输入及控制卡各自的 Consumer 中
选择下表字段；只有投影改变才读取一次当前 AiChatState，传给原 builder 渲染。
读取整份当前状态不等于订阅或保存整份状态，不能把它缓存成第二套状态。

仅在原方法外包 Consumer 不够：实例方法中的 `ref` 仍是父 State.ref。
给需要 watch 的 helper 传入该 Consumer 的 WidgetRef，或让 helper 的局部
Consumer 自己完成 select；事件里的原 `ref.read` 可以保留。特别排查：

- 第 1903 行普通 Builder 里的完整 watch（user 认证徽标）。
- 第 1946 行 `_buildAssistantBubble` 的完整 watch 回退；普通结束消息不需要它。
- 第 3465 行 `_buildAuthChallengeCard` 的完整 watch。
- `_buildSessionsDrawer`、空列表、输入、权限卡、认证发现卡里的 registry／
  serverConnection watch 也必须属于各自区域，不能意外重新挂到根组件。

## 最小字段表

| 区域／现有方法 | 必须观察的值 | 刻意不观察 |
| --- | --- | --- |
| 头栏 `_buildHeaderBar`（917） | activeAgentProfile 的存在、id、name；shareAgentSessions；isGenerating | sessions、正文、usage、diagnostics |
| 历史 `_buildSessionsDrawer`（1008） | activeSessionId；activeAgentProfile 的 id/name；shareAgentSessions；isGenerating；hasMoreSessions；isLoadingSessions；会话**有序 id/title**；当前 server id；默认 Agent 与启动偏好 | 每个 session 对象本身、messages、updatedAt（每批 token 会改，但这里根本不显示时间） |
| 消息列表框架 `_buildMessageList`（1453） | activeSessionId、当前 messageOffset、messages.length、isGenerating、isLoadingMessages；空态所需的 activeAgentProfile 是否存在、recoveryStatus | 整个 activeSession、messages 列表引用、最后一条正文／thinking |
| 消息项（1622 起） | 以固定 sessionId/messageId 查找并 select **原 ChatMessage 对象**；不存在则安全返回空 | 整个 AiChatState／session，不 copyWith／序列化消息 |
| 输入 `_buildInputArea`（3897） | activeAgentProfile 的存在/id；activeSessionId、当前 session 是否存在及 workingDirectory、draftWorkingDirectory；isGenerating、isAuthenticating、isLoadingSettings、isApplyingSettings、isLoadingSessions、isLoadingMessages、recoveryStatus；runSettings、capabilities；supportsImages、supportsTextAttachments；attachments | 正文、sessions、usage 数值、诊断文字、account 对象；draftText 由保留的 controller／切换监听同步 |
| 权限卡 `_buildPermissionCard`（2249） | pendingPermission、recoveryStatus、SSH isConnected | 消息列表、token、完整连接状态 |
| 认证区域／认证消息尾部 | authChallenge、authRequest、isAuthenticating、authenticationConfirmed、authError、isLoadingSettings、isGenerating、recoveryStatus、当前 profile 身份；最新 awaitingAuthentication assistant 的 **id**；SSH isConnected、相关 registry profile | 完整 messages／全状态、正文 |
| 错误区域 | lastErrorCode、authChallenge/authError 是否存在、当前相关消息的 status/failureCode、是否已有消息内错误的布尔结果 | 直接订阅最后一条完整正文；历史失败原因仍属于各自消息 |

输入区另有三个外部依赖：SSH 只取 isConnected；registry 用于无可用 Agent 的
安装提示／唯一安装候选，放在输入 Consumer；诊断按钮是否显示只取
“有 Agent 或 usage 非空或 diagnostics 非空或 account 非空”这个布尔值。
不要把 usage／diagnostics 内容放入输入投影，真实额度变化不该重建输入框。
runSettings 和 capabilities 引用在普通 token 更新时保持不变，保留引用即可。
当前 `_InputAreaProjection.capabilities` 的实际类型应为
`AgentRuntimeCapabilities`（来自 chat_run_settings.dart），不是不存在的
`AcpCapabilities`；UI 投影必须与 `AiChatState.capabilities` 同型。

历史有序 id/title 投影必须按内容判等：每次新建 List 放进 Dart record 并不会
得到列表内容相等。可用一个小型 UI 值投影配合 Flutter 的 listEquals；这里只
复制极小的展示元数据，不复制 ChatSession 或正文。不要用全文 JSON／哈希签名
绕开相等问题。投影必须同时覆盖重命名、同数量的搜索结果替换及顺序变化。

默认 Agent 直接订阅现有 `defaultAgentSettingsProvider` 的 `acp` 值（位于
security_settings_provider.dart），不能只 watch 不会换对象的 storage service。
启动偏好保存后原 notifier 会刷新会话，isLoadingSessions 的变化让历史区域
重新读取当前偏好。搜索框 controller 和清除按钮行为保留。

## 消息列表与认证边界

列表框架渲染时读取当前消息，只把 ID／角色用于构建消息项。每个消息项在自己
的 Consumer 中查当前原对象，因此列表闭包不会一直把旧正文传下去。核心保证
普通 token 仅替换变化消息引用，分页保留既有消息对象，回放保持本地消息 ID。
当前追加／分页都由 length 或 messageOffset 触发框架更新；不要把 length 方案
误用于会话历史列表，那里同长度的搜索结果确实会换 ID。

key 保留既有兼容标识，并纳入 sessionId；不能以索引作为消息身份。
prepend 会移动索引，ListView 的 key 到 index 查找需考虑“加载更早”头行偏移，
避免思考折叠、工具输出展开或文本选择随分页丢失；不需要持久化额外索引仓库。
KeyedSubtree 自身只保身份，无法阻止 Markdown 随父 builder 重建。

普通完成消息只需要原消息对象。awaitingAuthentication 的徽标／卡片另有小型
认证订阅，认证完成而 ChatMessage 没变化时也必须刷新。最新等待认证消息 ID
的选择复用现有 `_isAuthChallengeTargetMessage`／`_isLatestAwaitingAuthMessage`
语义，认证卡只能出现在正确的消息或底部兜底区域，不能两处重复。
可让现有 bubble helper 读取当前状态，但认证相关字段必须有对应局部订阅，
不能靠其他 token 碰巧触发刷新。

错误接入沿用 `2026-10-15-acp-core-api.md`：每条消息 failureCode 显示本地化
摘要／动作，原诊断仅详情；当前消息已承载同一错误时抑制重复顶栏。旧内嵌
`**Error:**` 的兼容判断选择布尔结果即可，不把整个 content 放进错误区域订阅。

## 保留现有副作用，别引入逐 token setState

第 703–865 行根 `ref.listen` 没有 token 驱动的 setState，可以原样保留为一个
副作用监听；listen 本身不会重建根组件。不要把它复制到各消息 Consumer。
_followBottomIfNeeded（118）仍在消息项布局后 post-frame 跟随，必须保留
near-bottom 检查和服务器 connectionKey／Agent／会话校验。

保留首次进入定位、切会话定位（724）、首批历史补齐定位（745）以及前插分页
的高度差补偿（764）。分页分支提前 return，防止随后自动滚底覆盖锚点。
不要把滚底改成每个消息项独立执行；工具／附件变化同样可能增加高度。

现有根 setState 仅用于发送开始／结束（435/462）、搜索（1244/1259）、命令
目录加载（2568/2574）、认证启动结果／方式选择，不是每批 token；本轮无需
为了拆订阅迁移这些状态。认证请求变化时 listener 会直接清 _authLaunchError，
所以认证区域一定要观察 authRequest。保留统一浏览器 claim 与登录成功提示，
不增加登录后的自动发送。已使用局部 Consumer 的独立对话框不是根订阅问题，
无需在此任务顺便重写。

## OpenCode 验证重点

持续 50ms 流式更新时，根布局、历史行、输入和已结束 Markdown 的构建计数
不随 token 增长，只有目标消息变化；发送开始／结束等离散状态允许正常刷新。
另覆盖同数量搜索替换、重命名／默认偏好、分页前插及工具展开、切服务器／
Agent／会话后的旧 post-frame 回调、用户向上阅读不被拖到底、仅工具／附件
事件增高、认证成功但消息对象未变化、错误卡不重复、草稿和输入选择保持。
本指导未执行测试、应用或真实 ACP。

## Batch 3 错误动作审查：必须调用真实可用的操作

以下基于当前 `_handleMessageFailure*` 和 core 实现逐层核对。动作不满足
前置条件时显示详情，不能保留点击后直接 return 的「重连／重新加载」按钮。

### 目标身份与忙碌状态

当前 handler 只检查 `activeSessionId == sessionId`，不足以隔离共享会话中的
Agent：同一会话里 Agent A 的旧失败，在已选中 Agent B 时会给 B 登录、打开
B 的设置或恢复 B。绑定消息的 `agentId`（旧消息可无此值）、当前 server id、
session id；只在明确匹配当前目标时提供可执行动作，否则保留详情。点击时
再检查一次身份及忙碌状态；异步后继续操作也须重新检查。不要自动切 Agent，
不重发消息。正在生成／认证／加载／应用设置或有待决权限时不可开启冲突操作。

### 现有 reconnect API 的真实边界

- SSH 已断开：现有 `serverConnectionProvider.notifier.connect()` 是连接入口。
  它只重新连接 SSH，不保证一个 `failed` 消息的 ACP 会自动恢复；不能把返回
  成功解释为旧失败消息已成功重试。保留原消息失败详情。
- `aiChatProvider.notifier.recoverConnection()` 是未完成会话的恢复入口。
  `_recoverConnection` 在 `recoveryStatus == idle` 且消息只有 `failed`（没有
  interrupted／unknown／streaming）时直接返回；无 remoteSessionId 也返回。
  所以当前「SSH 已连接 → recoverConnection」无法修复普通 transport failure。
- `prepareRunSettings(refresh: true)` 也不是强制重连：`_adapterFor` 复用同目标
  未 disposed 的 adapter，`initializeOnly()` 在已 initialized 时直接返回。
  generic `ACP_TRANSPORT_FAILURE` 的 adapter 不一定已 disposed。该调用清全局
  lastErrorCode，但不会清 `ChatMessage.failureCode`，也不会重放／发送 prompt。
- 不要拼 `stopGeneration()` 来强制重连：它即使当前没有生成，也会调用
  adapter.cancelPrompt()，后者只检查 disposed/sessionId，会向远端发 cancel。
- 本轮已新增 `Future<bool> reconnectCurrentAgent()`，SSH 已连接时用它替换上述
  假重连路径。它显式丢弃缓存 adapter 后只 initialize，不创建／加载会话或发
  prompt；busy／目标失效返回 false。具体 guards 和状态保持见 core-api 文档。
  SSH 离线先 connect，await 后重新校验 server connectionKey／Agent／session
  再调用。成功也不清历史消息错误、不声称旧消息已重试。不能服务的目标显示
  details；不把无反馈的 return 包成成功按钮。

### history 必须按失败来源路由

| 当前可确认的失败来源／状态 | 现有可用入口 | 限制 |
| --- | --- | --- |
| `CHAT_HISTORY_LOAD_FAILED` 会话列表读取失败 | `searchSessions(_sessionSearchController.text)` | 保留当前搜索；不是 `loadOlderMessages()` |
| `CHAT_MESSAGES_LOAD_FAILED` 且当前 messages 为空 | `selectSession(currentSessionId)` | 同 id 没有早退，会进入 `_loadSelectedMessages()`；已有消息则非 older 加载会早退 |
| `CHAT_MESSAGES_LOAD_FAILED` 且 messages 非空、messageOffset > 0 | `loadOlderMessages()` | 只重试前页；offset == 0 必定早退 |
| 远端历史列表／导入失败 | 重新打开既有远端会话选择 UI，或 details | 不用本地分页冒充远端重载；`openRemoteSession(..., reimport: true)` 会新建本地会话，不能盲目调用 |
| 来源不明、已无重载目标、unsupported／ambiguous | details | 不猜测目标，不自动新建会话／重放 |

`_loadSelectedMessages` 与成功的 `_refreshVisibleSessions` 目前不会可靠清除旧
lastErrorCode（copyWith 的 null 保留旧值）；这是现有 core 边界，不应由 UI
伪造已消失的错误或清除历史消息 failureCode。若本轮需要成功后清顶栏，先由
root 明确批准窄化的 core 行为，再交 OpenCode 验证。

验证应覆盖：共享会话 A 失败后切 B；SSH 在线但 adapter 已坏且消息 failed；
初次空历史加载失败；已有消息的分页失败；列表搜索失败；无 remoteSessionId；
点动作后马上切 server／Agent／session；任何路径均无自动 prompt／重发。
