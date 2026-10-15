# ACP 核心接口与验收交接

所有权：本轮核心改动涉及 `ai_chat_provider.dart`、新增
`chat_failure_presentation.dart`、`ChatMessage` 和现有回放合并调用点。
UI/ARB 由 AgY 接入。初期由 OpenCode 验证；本轮用户随后明确授权 Codex
执行测试／验证／构建／ADB，最终检查由根代理统筹。本文末尾区分已通过的
定向证据和仍由根代理执行的最终检查；没有连接真实 ACP 或发送远端消息。

## 错误呈现

`lib/core/utils/chat_failure_presentation.dart` 提供：

```dart
enum ChatFailureKind { auth, modelUnavailable, connection, history, other }
enum ChatFailureAction { login, runSettings, reconnect, reloadHistory, details }

ChatFailurePresentation? classifyChatFailure(
  String? errorCode, {
  bool authenticationRequired = false,
});
```

返回对象字段是 `kind` 与 `suggestedAction`，使用常量对象，适合 Riverpod
`select`；无错误返回 null。没有本地化文字，也不执行动作。
`ai_chat_provider.dart` 重导出这些类型；`AiChatState.failure` 等于
`classifyChatFailure(lastErrorCode)`，只供没有消息承载的错误入口使用。
认证对话框可独立分类 `authError`，运行设置可独立分类 `modelCatalogError`。

分类先识别认证（包括 ACP 的 `RpcError(-32000)`）和明确的模型不可用原因，
再识别连接与历史错误；因此远端历史包装中的认证原因仍引导登录，普通 403、
JSON-RPC 内部错误、存储失败或身份不匹配不会武断地引导登录／重连。
`ACP_AUTH_CONNECTION_EXPIRED` 专门映射连接恢复。认证方式明确不支持或凭据
存储不安全只建议详情；历史协议明确不支持或回放歧义也只建议详情，不建议
反复重试。未知内容归 `other/details`。

| 分类 | 默认动作 | UI 接入 |
| --- | --- | --- |
| auth | login | 打开现有登录／Agent 管理。官方 AgY 可用 `requestAuthentication()`；其他 Agent 沿用现有认证选择。 |
| modelUnavailable | runSettings | 打开已有运行设置，显示当前所选模型与可用选项。 |
| connection | reconnect | 先确认 SSH 已连接，再显式调用 `reconnectCurrentAgent()`；只替换 ACP transport 并初始化，不重试消息。 |
| history | reloadHistory | 打开对应历史入口，重试失败的读取；保留查询与已显示消息。 |
| other | details | 打开可复制的脱敏诊断详情。 |

动作必须由用户点击触发，并且以当前服务器／会话／Agent 身份校验可用性。
旧消息里的动作不应悄悄作用于另一台服务器或另一个 Agent。
登录成功或重连后不调用 `sendMessage`，不自动批准权限，不执行终端命令。

历史动作没有新增一个无上下文的通用重载：会话列表沿用
`searchSessions(currentQuery)`，加载更早消息沿用 `loadOlderMessages()`，
首次读取失败且 messages 为空可再次 `selectSession(id)`；已有消息只能在
messageOffset > 0 时加载更早消息。远端导入沿用远端历史选择器，不能把本地
分页当作远端重载，也不盲目调用 `openRemoteSession(..., reimport: true)`，
后者会新建本地会话。不支持／歧义错误只展示详情。

全局错误区域只为上述可执行的本地路由提供动作；
`ACP_HISTORY_IMPORT_FAILED`／`ACP_HISTORY_IMPORT_INCOMPLETE` 和已有消息且
offset 为 0 的本地错误只显示详情，不显示点击无操作的重载按钮。可用性局部
订阅当前身份、busy、消息数和 offset；callback 固定 server connectionKey、
Agent／session／errorCode，并在点击时复核。本地 repository 读取不要求 SSH
在线。共享会话中无法识别 Agent 的 legacy-null 失败消息不操作当前其他 Agent。

## 全局错误的会话生命周期

`selectSession(id)` 在目标存在、且真正改变 activeSessionId 时，通过既有
`copyWith(clearError: true)` 清除上一会话的瞬时 `lastErrorCode`。否则，A 的
历史加载错误可能在切到已缓存的 B 后留下，让 UI 把旧错误的重载动作绑定给 B。
只清当前界面错误，不改 `ChatMessage.failureCode`、失败状态、正文或历史对象；
既有草稿保存／恢复流程保持不变。切回 A 后仍能看到 A 的消息级失败原因。

同 id 的 `selectSession` 不清全局错误、不重置 adapter，继续沿用已有读取逻辑：
空消息可重试初次读取；已有消息不会重新加载。生成中或目标 id 不存在时，
原有早退不变。`switchAgent`／新建草稿已有的清错行为不变。

## 显式 ACP 重连入口

`AiChatNotifier.reconnectCurrentAgent()` 返回 `Future<bool>`。只从用户明确点击
调用，未接入自动恢复／前后台监听。true 仅表示当前同目标 ACP 初始化成功，
不表示失败消息成功、历史已回放或认证已完成。false 表示忙碌、目标不可用、
操作被目标切换取代或初始化失败；UI 不得把 false 当成功，应保留详情。

前置条件：当前 profile、server 和 SSH client 存在、SSH 在线、应用前台。
拒绝发送准备／生成、认证 challenge/request/未完成 completer/回调、模型授权、
待决权限／权限队列、设置加载或应用、会话或消息加载、连接丢失处理、正在恢复、
checkpoint、adapter 建立及 composer 查询。`recoveryStatus` 为 reconnecting／
syncing 时拒绝；已 failed／incomplete 可初始化，但原恢复状态保持不变。

实现先用现有 `_resetAdapter(preserveDraftWorkingDirectory: true)` 同步使旧
adapter disposed 并取消旧订阅，再调用 `prepareRunSettings(refresh: true)`。
旧 adapter 的实际连接 close 仍按现有基础设施延迟执行（dispose 是 void，不是
可 await 的关闭接口）；没有扩展其生命周期 API。准备入口只 initialize 和
独立目录查询；不会调用 session/new、load/resume、prompt、cancelPrompt，
不批准权限。服务器启动过程中若发出授权通知，仍由既有认证处理展示，并非
此方法自动完成登录。

不清消息 failureCode／状态／正文、会话 ID、草稿正文、附件、运行偏好或已选
认证方式；保留 `_retryAfterAuth`，所以下一次用户显式认证重试仍复用消息。
草稿 cwd 在 reset 中保留；若初始化解析 cwd，完成时只在 request epoch、
server connectionKey/id、Agent id/launchKey、session id 均未变化时恢复原选择。
不会 await 后整体回写旧 state，因此不会覆盖期间的新正文或附件。认证确认、
catalog、commands、usage 等连接元数据沿用 reset 的失效规则；prepare 会清
全局 lastErrorCode，但历史消息诊断仍保留。

UI 仍需在点击时校验消息 Agent／server／session。SSH 离线可先调用现有 SSH
连接入口；await 后确认目标仍一致再请求此方法。旧 `recoverConnection()` 仅为
未完成会话的历史恢复，不应代替它：idle + failed-only 消息时旧方法会早退。
仅调用 `prepareRunSettings(refresh: true)` 也不会替换坏的缓存 adapter。

## 每条消息的持久化错误

`ChatMessage.failureCode` 为可选 `String?`。新 ACP 错误先经过
`LogSanitizer.sanitize`，保存到该字段及 `lastErrorCode`；模型拒绝、会话准备等
抛出异常的发送路径同样保存为失败消息。认证等待保存 `ACP_AUTH_REQUIRED`。
正文保留收到的内容，不再追加 `**Error:**` 原始诊断。

UI 在消息气泡里调用 `classifyChatFailure(message.failureCode)`，显示本地化摘要、
动作和折叠详情。复制入口只放详情；渲染／复制时仍调用 `LogSanitizer.sanitize`。
空正文的失败消息也要显示错误卡。只有当前显示的失败／认证等待消息带有与
`lastErrorCode` 相同的 `failureCode` 时才抑制重复顶栏错误；不能全局隐藏历史
加载、附件保存等独立错误，也不能隐藏此前消息自己的失败原因。

字段在 `toJson` 中非 null 才写入，旧 JSON 缺字段或字段非字符串时读成 null。
SQLite 已按 JSON 存消息，因此无数据库版本／schema 迁移。旧记录正文里的
`**Error:**` 内容不改写、不删除；AgY 保留旧版显示兼容处理。
现有回放合并保留本地 `failureCode` 及其终态，不把仅有内容的回放误判成成功。
具体依据：`openRemoteSession.finishMessage` 给回放消息使用默认 completed，
session/load 没有携带可归属到该消息的成功终态；正文变长也不是成功证据。
若传入回放本身有新 failureCode，优先采用该原因和状态。真实显式重发的 live
完成通过 `saveSession` 持久化清除错误后的新状态，不走 `mergeReplayBatch`，
因此该规则不会把成功重发重新覆盖成旧失败。
`copyWith` 默认保留错误；只有 `clearFailure: true` 明确清除。

认证后用户显式再次发送同一待发内容时，复用原消息 ID、清除该消息错误并立即
转为 streaming；认证选择本身不会重新发送。新建其他消息不清除旧失败消息。
`failureCode` 不参与 `_boundedPendingHistory` 的内容拼接，不会发送给模型。

## 局部订阅与对象身份

保留既有 50 条分页及 50ms token 合并。没有新增完整状态副本或消息仓库。
`_updateAssistantMessage` 只替换目标消息引用；其他 `ChatMessage` 对象与非目标
会话保持 `identical`。同一对象或目标已消失时不发布状态。无新增文字／思考／
内容块的 flush 不再生成新消息对象；重复的远端 message ID 也不复制消息。
状态、附件、计划和工具的真实变化仍发布，最终完成／失败仍立即发布。

AgY 拆头栏、历史、输入、消息四类订阅。消息项用稳定 `(sessionId,messageId)`
作为 key，并直接 `select` 原消息对象，例如：

```dart
final message = ref.watch(aiChatProvider.select((state) {
  final session = state.sessions
      .where((entry) => entry.id == sessionId)
      .firstOrNull;
  return session?.messages
      .where((entry) => entry.id == messageId)
      .firstOrNull;
}));
```

不要在 selector 中 `copyWith`／反序列化消息。消息列表框架只订阅当前会话 ID、
消息数量与分页信息，新增／分页时才更新 key；正文由各消息项自行订阅。
历史列表仅观察列表身份顺序、标题与所需稳定元数据；不要订阅整个活动会话或
把每个 token 更新的 `updatedAt` 当作历史行重建条件。仅监听 state.sessions
引用仍会每批 token 更新，不能当作完成了拆订阅。Markdown 已结束正文可以依靠
消息对象身份不变来跳过重建，不要复制整份聊天状态来达到这一点。

## 回归清单（保留初期交接范围，实际通过状态见末节）

1. 纯分类：null／空白返回 null；认证包装、`RpcError(-32000)`、
   `ACP_AUTH_CONNECTION_EXPIRED`；`ACP_SETTING_UNAVAILABLE: model`、
   `ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER`、`model_not_found`、远端
   `model <id> is not supported`；SSH／ACP 断线与 idle timeout；本地历史读取与
   远端导入错误；不支持／歧义仅详情；403、permission denied、内部错误、
   `CHAT_SAVE_FAILED`、身份不匹配保持 other；`ACP_TRANSPORT_FAILURE` 包装
   `RpcError(-32603)`／`RpcError(-32700)` 仍为 other/details，包装
   SocketException／connection reset 则为 connection；同一分类结果对象恒等。
2. 模型 JSON：新错误往返；旧 JSON 无字段兼容；copyWith 保留／clearFailure
   清除；导出、仓库保存加载与同一消息回放后错误原因仍在，失败不伪装完成；
   同 ID 更长的无终态回放不伪装成功；显式重发成功落盘后再次回放不复活旧错误。
3. 模拟 ACP 发送：先有部分正文再错误，正文无诊断追加、status=failed，消息
   failureCode 和 lastErrorCode 相同且 token／api_key 脱敏。下一轮成功后旧
   消息失败信息仍在，下一次 prompt 的上下文不含 failureCode。准备阶段抛错
   同样有消息级错误；失败后草稿保留。
4. 模拟认证：等待状态持久化；登录本身 prompt 次数不变；显式重发复用 ID，
   立即清掉失败字段且不重复插入 user 消息。
5. 流式身份：多条已完成消息 + 一条流式回复，跨 50ms 批次只有目标消息对象
   改变；重复远端 ID、无变化 checkpoint／最终额外 flush 不替换已完成消息；
   非目标会话对象稳定。用 selector 通知／widget 构建计数证明旧 Markdown、
   历史行和输入区不随 token 更新。
6. 工具更新、附件异步归属、thinking-only、多个远端 assistant ID 及切会话
   后旧事件守卫都保持既有行为；50 条分页、草稿、滚动和选择不回退。
7. UI 检查：本地化分类与准确动作；错误只在对应消息显示、不在顶栏重复；
   独立历史错误仍可见；详情可复制且脱敏；320dp、2倍字体、RTL、深浅主题。
8. 显式重连：注入坏的未 disposed adapter，确认重连替换它并 initialize，
   prompt／session/new／load／resume／cancel／权限允许次数不增长；即使没有
   remoteSessionId 也可初始化。验证空 draft 与已有会话的 cwd、正文、附件、
   sessions/messages/failureCode、认证重试复用和 failed/incomplete 恢复状态
   保留；忙碌 guards 不替换 adapter；快速双击只启动一次；在 transport 创建、
   initialize 或目录查询期间切 server／连接配置／Agent／session，不回写旧 cwd，
   返回 false。SSH 离线、无 profile、后台及初始化失败不得声称恢复成功。

建议补入现有 `test/core/ai_chat_provider_test.dart`、
`test/core/ai_chat_usability_test.dart`、
`test/core/background_recovery_chat_state_test.dart`、
`test/data/chat_message_contract_test.dart`、
`test/data/chat_replay_merge_test.dart`；分类可新增小型纯单元测试。

## 最终定向验证记录

- `flutter test --no-pub test/core/ai_chat_provider_test.dart --reporter expanded`：
  **50／50 通过，exit 0**，在最后一行 selectSession 修复之后执行。
  新回归先在旧实现失败（切 B 后仍为 A 的 CHAT_MESSAGES_LOAD_FAILED），再通过；
  证明同会话选择保留错误、切会话清瞬时错误、B 的缓存／offset 不触发额外加载、
  A 的原消息对象／failureCode 与未发送草稿保留。四项显式重连回归也在此文件内：
  替换 transport 且只 initialize、草稿／失败历史保持、生成／权限时拒绝、
  catalog 等待中目标变化不恢复旧 cwd。
- 根代理报告 UI 联合目标 **18／18 通过**：
  `acp_failure_actions_test.dart` 10 项、`ai_chat_session_isolation_test.dart`
  6 项、`acp_stream_rebuild_test.dart` 2 项。此联合结果在最后一行 core 修复前
  获得，不能写作该最终源码版本的全量验证；最后一行由上述 provider 50 项验证。
- UI 证据覆盖三类本地重载、两个远端导入错误／offset-zero 详情降级、
  legacy-null Agent 隔离、认证 loading／error／methods-only 订阅、
  320dp／2倍字体且动作／详情／复制至少 44dp、既有身份说明与流式／前插状态。
  不代表所有主题／RTL／真实设备／真实 SSH 条件均已检查。
- 本文更新时，根代理正在执行最终全量测试和构建，结果由根代理另行记录。
  上述 provider／widget 测试均为隔离 fixture 或内存 ACP transport；没有真实
  ACP／SSH 会话、远端 prompt 或自动权限批准验证。
