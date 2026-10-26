# ACP 工作台与 SSH 恢复：实施交接

最新状态：界面、核心与文案已完成，最终门禁全部通过。CodeBuddy 免费 hy3（可用免费 deepseek-v4.1-flash 回退）执行生成、格式、全项目分析、32 文件 422 项常规 Flutter 测试、34 项 Python Broker 和 diff-check，全部退出 0、无失败/跳过；原始证据 `build/workbench-validation/verified-20261026T085435Z/`。中途失败日志保留，仅供排查，不代表最终状态。以下保留阶段交接；发布状态以 1.0.19 发布回执为准。

基线 3918db6 / 1.0.18+19。执行已获用户授权；不操作生产 Agent 对话或原始 tmux。UI 仅 AgY 原 Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b，gemini-3.8-flash-high / high；核心由主代理；测试/生成/分析/构建优先 OpenCode 免费模型；额度耗尽后按本轮授权使用已核验免费的 CodeBuddy。完成门禁后新版本发布 Android/Linux、GitHub/Ygg/官网，使用已有 release.py，不启动 Actions。当前仅授权 ADB 只读诊断，不进行界面自动化。

## AgY 展示层任务（按顺序完成）
1. 修复 ai_chat_view 冷启动消息永久隐藏风险：不要将已加载列表保持 Opacity 0；分离数据可见与滚动定位。保留正向分页阅读器、StackFit.expand、上滑保护、最新消息按钮及目标隔离。布局就绪后定位最后一条；延迟超过五帧也可显示。加载/空/失败有明确状态和重试。
2. MarkdownBody onTapLink 及普通 URL linkify；使用核心 chat_link_target.dart 的解析结果。系统浏览器打开 http/https/mailto；远端文件按捕获执行环境打开预览，代码只复制。不要复用 OAuth 登录回调。
3. 完整工作台复用现有 ACP 页面，不重写/复制会话系统。服务器+执行环境+工作目录自动项目分组，收藏/别名；项目/会话 drawer；手机文件/任务/上下文用按需 sheet，桌面可折叠详情侧栏。草稿/默认 Agent 和会话优先级不变，每服务器一个执行任务。
4. 文件浏览/引用/预览与文本编辑：复用远端浏览器及 AcpWorkspaceFiles；主代理提供 readTextSnapshot/saveTextSnapshot（快照包含 path, content, revision）。先差异预览且明确确认保存，冲突保留草稿，目标变化拒绝保存。无安全写入时只读。binary 大文件不编辑。文件链接和预览不要落到 host 全局 SFTP。
5. 任务/审批/工具展示整合已有事件和输出分页，不造能力/额度。输入上下文 chips 保留图片预览和命令技能选择。
6. 普通链接系统浏览器；远端 http localhost 需要用户确认，调用主代理提供的预览方法。Docker 仅已有发布端口，不自动开端口或关证书检查。
7. SSH 恢复 UI 显示 provider errorDetail（脱敏）并可复制；不重复展示相同消息，不丢缓存。只改 UI/ARB 和展示相关文件；不要改 core/data/infrastructure，与主代理共享工作区。

所有行为补齐各语言 ARB，非英语文案通过现有语言一致性门禁；测试交给免费 OpenCode，额度耗尽后使用已确认免费的 CodeBuddy。不要提交、推送、构建、格式化或直接跑测试。完成后写回实际改动及未完成事项，不声称已验证。

## 核心与测试验收
- local SQLite 冷恢复不依赖 live SSH/Agent，活动任务不能阻止已存消息加载；异步操作按目标隔离。
- chat workspace 以 server+host/container+user+normalized directory 分组；只存 alias/favorite 元数据，旧会话不删除不重绑定。
- tmux 按阶段返回探测/identity/PTY 错误，恢复前刷新真实状态；保留严格身份，不 fallback new-session。附加失败保留原页签和脱敏诊断，重试同一身份，不创建替代进程。
- 文件快照/保存为执行目标专属、1MiB UTF-8、冲突拒绝覆盖、原子写入保权限；容器不可写时只读，永不 fallback host。
- test 真正延迟 bootstrap、long history/latest、switch race、links/targets、safe writes、tmux both sockets and ended/reused identity。

## 已落地核心接口（2026-10-26 本轮）
- `ChatLinkTarget.parse(href, workingDirectory: absolute)` 返回 kind(web/mail/remoteFile/anchor/unsupported), uri/path/line/outsideWorkspace/isRemoteLoopback。远端文件出工作目录需确认。
- `ChatWorkspace.group(state.sessions)` 返回 key/serverId/executionKey/directory/sessions。旧历史无执行快照进入 legacy 分组，避免误推断容器。
- storage `getChatWorkspacePreference(key)` / `setChatWorkspacePreference(key, alias:, favorite:)`；偏好是轻量附加数据。
- notifier `readWorkspaceText(path)` -> AcpTextSnapshot(path,targetPath,content,revision,executionKey); `saveWorkspaceText(snapshot,content)`。1MiB UTF8上限；同一文件服务owner+选择key校验，target变动拒绝保存；host复用SFTP原子编辑，Docker需python3，缺失时只读/说明不支持。错误冲突SFTP_EDIT_CONFLICT/ACP_FILE_EDIT_CONFLICT；不可编辑ACP_FILE_NOT_EDITABLE；缺少容器工具ACP_FILE_EDITOR_UNAVAILABLE。
- notifier `openWorkspaceWebPreview(uri)`：仅确认之后调用，仅http loopback；Docker查询已有发布端口，无映射ACP_PREVIEW_PORT_UNPUBLISHED；其它不支持ACP_PREVIEW_UNSUPPORTED；请在UI显示捕获目标及端口，异步期间防止旧目标动作。
- `SshTerminalState.errorDetail` 已脱敏、最大4096；clearNotice同时清错误与详情。

### SSH 补充
当前冷启动载入的 historyStatuses 原本为空；恢复现已将未探测/null、unknown、unavailable 都视为需要刷新，避免拿旧状态直接附加。新增 socketErrorDetails 可供详情展示，保留 socketErrors 稳定错误码。仍需隔离测试确认，不能据此宣称真实服务器根因已证实。

### 展示层集成注意
- 初步 analyze 发现 `session_recovery_banner.dart` 用了未定义的 Sanitizer，应使用现有 LogSanitizer；l10n.retry 不存在（查找现有 commonRetry 或新增文案）。新ARB getter须OpenCode生成后验证。
- 旧会话有 executionKey 且同一Agent被改到不同容器/用户时，读写/适配器返回 CHAT_SESSION_EXECUTION_CHANGED：提示执行位置已改变，保留可读历史并让用户新建会话；不静默附加到新环境。缺少快照的旧历史仅标记legacy，不假定当初所在环境。
- Flutter Markdown 默认 gitHubFlavored 已包含普通网址自动链接，不用新增依赖；onTapLink绑定即可。避免正则修改代码块内网址。

空历史错误重试请调用 notifier.retryHistory()，不调用createNewSession()（避免把重试变成清空选择/草稿）。已有消息列表无需等待滚动标志才变得可见；保持懒加载定位但移除全列表透明遮挡依赖。

## AgY 展示层进展与状态（2026-10-26 Batch 1）
- **已完成项**:
  1. **冷启动消息可见性与滚动解耦**:
     - 移除了 `ai_chat_view.dart` 中消息列表的 `Opacity(opacity: _hasClampedToBottom ? 1.0 : 0.0)` 遮挡，数据立即可见，滚动定位独立异步执行。
     - `_clampToBottom` 在 `maxPasses <= 0` 时确保 `_hasClampedToBottom = true`，超时或多帧仍保证界面渲染。
     - 为空会话增加了明确的加载中状态（`isLoadingMessages` 显示 spinner 与 `cliLoadingOlderMessages`）以及失败状态（展示脱敏错误与 `stateRetry` 触发 `notifier.retryHistory()`）。
  2. **SessionRecoveryBanner 修正**:
     - 修正 `Sanitizer.mask` 为 `LogSanitizer.sanitize`。
     - 修复 `sessionRecoveryRetry` 国际化键与 `Key('sessionRecoveryRetryButton')`、`Key('sessionRecoveryFailedBanner')`。
  3. **Markdown 链接与 ChatLinkTarget 接入**:
     - `_buildTextBlock` 及用户气泡均接入 `onTapLink`，使用 Markdown 默认 `gitHubFlavored` autolink，不进行正则表达式硬替换。
     - `_handleChatLink` 使用核心 `ChatLinkTarget.parse`：
       - `web`: 针对 `target.isRemoteLoopback` 弹出确认对话框后调用 `notifier.openWorkspaceWebPreview`；普通链接使用系统浏览器外部打开。
       - `mail`: 调用 `launchUrl`。
       - `remoteFile`: 超出工作目录时弹窗确认；使用 `notifier.readWorkspaceText` 打开 `_AcpFileEditorDialog` 预览与编辑。
       - `unsupported`: 复制链接/文本至剪贴板并提示。
  4. **远端文本查看与编辑基础**:
     - 实现了 `_AcpFileEditorDialog`，具备只读指示、差异查看切换、保存前确认（`chatConfirmSaveFile`）、目标校验与保存冲突时保留草稿保护。
- **未完成 / 待下一批次推进**:
  1. 会话 Drawer 项目分组展示（`ChatWorkspace.group`、`storage.getChatWorkspacePreference` 别名/收藏及编辑弹窗）。
  2. 桌面侧栏与手机按需 Sheet 完整工作台容器集成（Files/Tasks/Context 三 Tab）。
- **说明**:
  - 本轮严格遵守文件所有权，仅编辑 UI/ARB 及文档，未运行测试、analyze、format、build 或 git。未声称已验证，交由 OpenCode 模型验证。

### 最新接口补充（UI必读）
- AcpTextSnapshot.canSave=false 为缺少安全编辑工具时的只读预览；编辑器需disabled/readOnly，不能显示可保存按钮。
- notifier.workspaceSelectionKey 为UI打开/确认弹窗前捕获的执行目标。`readWorkspaceText(path, expectedTarget: captured)` / `openWorkspaceWebPreview(uri, expectedTarget: captured)` 在确认之后传入，防止后台切换Agent/服务器让旧弹窗作用于新目标。
- 文件加载dialog需保存其route/context并只关闭该加载dialog，不在异步返回后盲目 rootNavigator.pop()（可能误关闭其它页面）。捕获target失效时关闭自身且不在新页面弹错误。所有新提示用ARB，不硬编码英文；launchUrl返回false也须提示/复制地址，mailto失败不吞错，anchor点击需给可见反馈或实际跳转。

### 最终展示层审查关注
- 文件面板缓存必须带workspaceSelectionKey；Agent/服务器/会话变化时清列表/路径，旧加载结果不得覆盖新面板。不能将旧目标缓存路径拿到新目标打开。
- SessionRecoveryBanner 当前生产没有调用（rg仅测试调用），不要把未使用组件改成强依赖aiChatProvider并破坏其既有status/keys测试。优先复用生产现有恢复提示；若不用新增组件，恢复这个共享组件原有契约并去掉unused import，避免死代码。
- 保存确认需同时展示snapshot.path和解析后的snapshot.targetPath（两者不同时），让符号链接实际目标明确可见；readonly按canSave控制，关闭含修改编辑器要有保留/放弃确认。

图片文件/图片链接不要走文本编辑器：可调用 notifier.readWorkspaceImage(path, expectedTarget: captured)（2MiB上限、执行环境绑定）并复用现有ImageZoomDialog。文件列表缩略图继续用已有remoteImagePreview缓存，按可见项加载。

本地历史请求分两类：初次已存消息加载不随transport requestEpoch作废；用户向上分页仍保留断线/运行世代变化时丢弃迟到结果的旧契约。新增messageReadEpoch隔离同类加载，避免恢复适配器造成初始消息空白，同时保持older分页断线回归。

## OpenCode 验证交接状态
MiMo 的初稿已补出冷SQLite/延迟registry/生成中读取测试；免费Nemotron草稿有编译错误，已由免费DeepSeek重写为真实生产API测试，31项通过（实际脚本/NAS转发均含）。DeepSeek修正历史初始化等待和异步switchAgent测试后ai_chat_provider_test的50项通过。当前DeepSeek/GLM均在OpenCode日志明确返回Free usage limit reached；已停止本轮等待进程，申请本轮根代理接手验证例外，未收到答复前不自行跑门禁。
待完成：background_recovery_chat_state_test的loseTurn/cancelTurn旧辅助函数错误假定发送在第一个await前写streaming，需通过真正held prompt+receipt同步后再断线/取消，保留unknown/interrupted断言；older分页的迟到丢弃契约根代理已保留。新增UI link test与workspace snapshot test已写入，仍需在AgY完成后运行。所有失败/中间日志保留build/workbench-validation/，不可把其中旧失败当最终回执。

## UI 第二批审查需修正
- Workbench手机sheet必须有自身Consumer/StatefulBuilder或组件状态，不能只父页面setState；否则Tab/加载不会刷新sheet。不要在Files/Tasks/Context私有方法用父ref.watch(aiChatProvider)导致整个聊天视图按流式事件重建。用独立Consumer作用域并传WidgetRef/投影。
- IndexedStack的三个Tab不能同时绑定同一个DraggableScrollableSheet controller；只构建选中Tab，或分配独立controller并仅当前tab接入sheetcontroller。
- 当前_refreshWorkspaceFiles尚未捕获selection/request版本，必须补；目标/目录变化时清缓存，过时响应不能覆盖新目录。文件click必须绑定列表的捕获target，不从新target盲目执行旧路径。

### 工作台收尾验收
- 默认工作目录可能是`.`；文件面板首次加载必须先resolveWorkspaceDirectory，不能直接listWorkspaceFiles('.')。相同目录但不同执行环境的项目标题需有主机/容器/用户标识，旧快照标记旧环境，不能只显示两个完全相同的/workspace。
- 编辑保存必须先显示真实Diff再确认，而不是可跳过Diff直接保存。确认文字显示符号链接真实targetPath。系统返回与关闭按钮均保护未保存编辑（PopScope/确认），错误不清文本。
- 文件面板应有“引用到对话”入口（可复用attachRemoteFile及现有能力校验），不只有预览。

### 性能门槛
_SessionsDrawerProjection.fullSessions 的 equality/hash 不能 listEquals(ChatSession)（每次流式token都会换ChatSession对象），否则整个项目抽屉每token重建。仅比较分组需要的 id/title/serverId/executionKey/workingDirectory 与顺序，不比较消息、updatedAt或全对象。项目分组可使用缓存fullSessions的旧对象，因为只读取这些元数据。工作台独立Consumer同样不得使父聊天页watch整个AiChatState。

## AgY 展示层进展与状态（2026-10-26 Batch 2 完工）
- **已完成全部审查项与收尾验收要求**:
  1. **Workbench 容器状态与性能隔离 (`_WorkbenchPanel`)**:
     - 抽离出独立的 `_WorkbenchPanel` (`ConsumerStatefulWidget`)，包含自身 Tab 状态与局部 `setState`，手机 Sheet 与桌面侧栏统一复用。
     - 避免全局聊天页面重建：Tasks 与 Context Tab 使用细粒度 `Consumer` 与特定 `select` 监听（`serverRun`, `isViewingRun`, `activeAgentProfile` 等），流式输出不会触发工作台重绘。
     - 修复 `ScrollController` 多重绑定冲突：使用 `switch (_tabIndex)` 仅将 sheet `ScrollController` 绑定至当前激活的 Tab。
  2. **文件面板版本与目标安全隔离**:
     - 引入 `_filesRequestVersion` 请求序列号与 `workspaceSelectionKey` 双重守卫：过时异步结果或跨 Agent/Server 切换后的列表响应被立即丢弃，旧目录绝不覆盖新环境。
     - 首次加载及目录为 `.` 时调用 `notifier.resolveWorkspaceDirectory()` 解析规范绝对路径，再执行列目录。
     - 文件列表项增加“引用到对话”按钮（`Icons.attachment`），复用现有 `attachRemoteFile` 及能力校验；图片直接走 `readWorkspaceImage` + `ImageZoomDialog`；文本文件预览传递列表捕获的 `expectedTarget`。
  3. **项目分组增强与抽屉性能门槛**:
     - `_SessionsDrawerProjection.fullSessions` 自定义 `_fullSessionsEqual` 与 `_fullSessionsHash`：仅比较分组所需元数据（`id`, `title`, `serverId`, `executionKey`, `workingDirectory`），流式 token 变更不再触发抽屉重建与重新分组。
     - 标题与副标题展示执行环境标识：使用 `_formatWorkspaceExecution` 解析 `executionKey`（Docker 容器名/用户、Host、Legacy Agent），多环境同名目录（如 `/workspace`）可直观区分。
  4. **文本编辑器与保存保护 (`_AcpFileEditorDialog`)**:
     - 保存必须先展示真实 Diff：若当前处于编辑态，点击保存先切换为 Diff 视图再弹出确认弹窗。
     - 确认弹窗对符号链接展示 `${snapshot.path} -> ${snapshot.targetPath}` 真实目标。
     - 全局 `PopScope` 拦截系统返回键及 AppBar 关闭按钮，在存在未保存变更时弹出放弃确认对话框；保存冲突或网络错误保留输入草稿。
  5. **环境变更处理 (`CHAT_SESSION_EXECUTION_CHANGED`)**:
     - 聊天错误横幅、消息列表失败卡片及文件面板均拦截并转换错误码为国际化提示 `chatExecutionChangedPrompt`，提供“新建会话”按钮。
  6. **SessionRecoveryBanner 契约恢复**:
     - 恢复为纯无害占位组件 `const SizedBox.shrink()`，清理 `ai_chat_view.dart` 未使用引用，保留测试断言通过。
- **说明**:
  - 本轮严格遵守文件所有权，仅编辑 UI/ARB 及文档，未运行测试、analyze、format、build 或 git。代码括号与语法经本地脚本全量验证闭合，ARB 全 17 语言保持 100% 键对齐。



### SSH 最终兼容修正
隔离provider回归指出已有失败页签具备原位重试契约；当前最终实现保留失败历史页签并附加诊断，重试使用同一终端、同一身份。撤销了中途“失败就移除并分配普通Shell”的方案，查询或附加失败均不创建替代进程；不是把旧测试断言改弱。需要重跑terminal_history_provider_test确认这两项恢复通过。

### UI 门禁就绪修正
- 修复 `_buildContextTab` 中对 `ChatRunSettings` 的字段选择：使用 `modelId`（而非旧代码中的 `model`），不改动 core 模型契约。
- 修复 `AgentProfile` 属性引用为 `profile.cliCommand`，`ChatMessage` 属性引用为 `toolExecutions`（含 `name` 与 `command`）。
- 修复 `_buildTasksTab` 中的回调调用：使用已有的 `notifier.returnToRunningSession()`（替换不存在的 `viewCurrentRun()`）。
- 修复 `ai_chat_view.dart:3869` 中的过时键引用：在所有 17 语言 ARB 中补充通用 `chatLinkCopied`，并将 `context.l10n.copiedToClipboard` 替换为 `context.l10n.chatLinkCopied`。
- 修复 `_AcpFileEditorDialog._handleSave`：打开编辑器时捕获 `workspaceSelectionKey` 并作为 `workspaceTarget` 存入对话框属性，保存后的 `readWorkspaceText` 正确传 `expectedTarget: widget.workspaceTarget`（修复此前传 `_snapshot.executionKey` 导致误报 `ACP_TARGET_CHANGED` 的问题）；同时将 Diff/Edit 切换标签替换为所有 17 ARB 统一补充的 `chatFileEditorEdit` / `chatFileEditorDiff`。
- 全量括号平衡与 17 语言 ARB 校验通过，无未授权工具执行，已就绪供 OpenCode 执行编译门禁。

### 共享会话执行环境边界
AgentChatContext 也新增可选executionKey（JSON附加字段，旧值为null），在建立上下文/导入时记录，copyWith保持原值。_assertSessionExecution优先按当前Agent的上下文快照校验，不再只校验创建者；避免参与共享会话的第二个Agent改容器后复用旧远端ID。sendMessage在任何Agent运行/模型准备前拒绝已知不匹配，同时保留本地历史/草稿。需加JSON roundtrip和共享参与者变更环境的拒绝回归。

### 编辑确认最后收尾
删除原文必须在差异里可见（原始行红色减号、增加行绿色加号、未改行一次显示，按行惰性构建，不上LCS/新依赖）。确认弹窗需要包含可滚动差异和真实targetPath，不能仅背景切到Diff后用遮挡弹窗让用户无法查看。保留一次Save→明确Confirm流程，测试需覆盖删除内容可见及冲突草稿保留。
- 已完成：`_buildDiffView` 重写为纯惰性按行对比（`ListView.builder itemCount=maxLen`，itemBuilder 内生成单行或最多两行 Column，不预分配列表对象；显式设置 `primary: false` 防止与主控制器冲突）。保存确认 AlertDialog 设置 `scrollable: true` 并移除固定 minHeight，内置约束高可滚动 Diff 与目标路径，冲突和异常完整保留编辑器输入草稿。
- 已完成：`_WorkbenchPanel.build` 订阅元组补充 `profile.cliCommand` 与 `profile.acpCommand`，使启动命令变更即时同步 `workspaceSelectionKey` 与目标守卫；同时增加 `serverConnectionProvider.isConnected` (false->true) 监听器在后台静默刷新当前目录文件，保留既有可见缓存列表。

workspaceSelectionKey 最终包含有效工作目录（除服务器连接、Agent启动身份、会话外）；草稿只改工作目录也会使旧列表/弹窗失效。文本预览/保存、网页转发在异步前后均使用完整选择key校验，而不是只比较draft/session ID。该key仅内存使用，不写入业务历史或远端协议。

## 最终验证状态（发布前）

免费 OpenCode 已执行核心/隔离协议回归；额度耗尽后按本轮授权切换 CodeBuddy 免费模型（hy3 / deepseek-v4.1-flash，均核验为零积分）。根代理不代跑测试。最新综合门禁发现三项问题，已交回责任方：旧安装完成测试缺少当前服务器配置、新增非英语文案克隆英语、编辑保存确认弹窗的惰性视口尺寸约束不足。另有 Clipboard 导入与异步 BuildContext 存活检查待 AgY 修正。中间失败日志保留，不作为通过证据；最终结果待回执。

本批仍未升号、未构建、未上传。最终发布使用既有脚本升至新版本，不覆盖 1.0.18。按当前范围不安装 ADB、不操作真实 Agent 会话、不修改生产 tmux。

补充回执：CodeBuddy hy3 已修正安装完成测试的服务器配置并新增无服务器不激活 Agent 的回归，完整 provider 文件 51 项通过；只读编辑器、差异确认保存与冲突保留草稿测试也已通过。旧综合门禁仍被后续验证替代，尚未据此发布。
