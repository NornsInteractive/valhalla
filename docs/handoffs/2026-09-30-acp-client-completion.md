# ACP 客户端补全（逻辑验收与安装完成，真实对话由用户验证）

## 范围与协作

用户确认三阶段计划：协议/执行正确性；历史性能与恢复；日常客户端能力。
Codex 只修改非展示代码与文档。UI/ARB 只由 AgY 历史 Valhalla 会话
`ec81a4be-7543-45ee-8658-f68966f57d3b`、`gemini-3.8-flash-high`、high 修改。
测试维护、格式/分析、构建、产物核验和 ADB 仅由 OpenCode
`opencode/mimo-v2.6-flash-free` 执行。保留工作区已有修改，不提交、不推送。

## 第一阶段接口契约

- PermissionRequest 增加 `options: List<ChatPermissionOption>`，每项 id/name/kind。
- 审批结果为原始 optionId 或 null（取消）；`respondPermission` 支持原始 ID，旧 bool 入口仅匹配 once，绝不升级为 always。UI 按远端 options 渲染按钮，并提供取消。
- `prepareRunSettings({bool refresh = false})`：普通打开复用连接，用户点击刷新才重建。
- 草稿目录通过 `setDraftWorkingDirectory(String path)`；状态增加 draftWorkingDirectory。Docker 目录必须在容器用户环境校验，不使用主机 SFTP 结果。
- Docker 登录弹窗须传 `remoteExecCommand: agentTargetCommand(profile, loginCommand, interactive: true)`，复用管理页实现；确认后再次核对服务器/Agent，不能将命令发送给切换后的目标。
- 工具增量由适配器合并。权限 wire 必须遵循官方 v1 的 `result: {outcome: {outcome: selected, optionId: ...}}`，取消同样嵌套。旧测试断言扁平格式是错误契约，须纠正。
- `model_config` 不作为 thought_level 兜底；模型更新后联动采用远端确认值。

## 后续阶段与验收

### 展示接口（第二/三阶段）

当前接口已实现：state.isLoadingSessions/isLoadingMessages/hasMoreSessions；
`searchSessions(String)`、`loadMoreSessions()`、`loadOlderMessages()`；
activeSession.messageOffset > 0 表示有更早消息，totalMessageCount 是完整计数。
`selectSession` 现为 Future<void>。首屏50条、顶部加载50条，需保持锚点；
切换会话先重置滚动身份并定位最新消息，不要在用户翻历史时滚到底。
`renameSession(id,title)`、`exportSession(id)` 返回 Markdown 字符串；
导出使用现有 file_picker 保存能力，删除明确仅本地。
state.commands 为 name/description/hint，state.usage 为 used/size/cost/currency；
state.diagnostics 是可复制脱敏诊断。命令未上报时不硬编码一组命令。
工作目录展示 state.draftWorkingDirectory 或 activeSession.workingDirectory；
`setDraftWorkingDirectory(path)` 仅草稿可用。
已提供 `listWorkspaceDirectories(path): Future<List<String>>`（返回目标中的绝对目录）；
不要直接用主机 SFTP 浏览容器，也不要在 Widget 写 SSH 命令。
UI还须显示工具status，输出采用折叠+SelectableText，避免展开渲染全部长输出。

附件接口已经落地：state.attachments / supportsImages / supportsTextAttachments。
`addAttachment(AcpPromptAttachment(name,mimeType,bytes,uri?))`、`removeAttachment(index)`；
`attachRemoteTextFile(absolutePath)` 在当前执行目标读取普通文本文件，1MiB上限。
本地文件用既有file_picker，先检查文件大小再取bytes；图片总量20MiB，文本总量1MiB。
不支持时禁用入口；可先调用prepareRunSettings探测，但不能自动发消息。
本地大文件安全入口：`attachLocalFile(path,name,mimeType)` 已提供，先检查大小，
再限长读取。Android选择文件使用默认`withData=false`（12.3已弃用显式参数），用返回path调用该方法；
禁止withData:true在检查大小前先把整个大文件读入内存。
file_picker 12.3.0真实API：`FilePicker.pickFiles()`返回`List<PlatformFile>`，
不是带files属性的旧Result；取消为空列表。`FilePicker.saveFile`必传fileName与
Uint8List bytes，可设mimeType，返回Uri?（null为取消）；参考现有远程文件页静态调用。
输入框`onChanged`调用updateDraftText(text)；切换目标时同步state.draftText到controller。
后台load期间禁用发送（state.isLoadingSessions/isLoadingMessages），不能清空未发送文本。
ChatMessage.status = streaming/completed/interrupted/failed；ToolExecution.locations 为路径列表。
导出与诊断必须处理错误，不把复制诊断等同于成功发送对话。

远端历史接口：`listRemoteSessions({String? cursor}) -> Future<AcpRemoteSessionPage>`，
page.sessions 为 AcpRemoteSession(id/title/workingDirectory/serverId/agentId/launchKey)，
page.nextCursor 非空时可继续取下一页；`openRemoteSession(entry)` 在本地导入并选择。
列表不创建远端会话；打开是session/load完整回放，需显示正在导入，不宣称远端消息分页。
不支持时显示错误，不能自动新建；禁止调用任何远端删除命令。
导入是按用户选择建立的本地快照；同一远端ID已有映射时复用本地记录，
不自动合并其他客户端后续新增的历史（不属于本轮跨客户端同步范围）。
本地列表功能 searchSessions/loadMoreSessions/renameSession/exportSession 已就绪。
本地删除文案须说明仅移除App记录，不删除Agent原生历史。

长工具输出已拆到chat_tools：历史ToolExecution.hasMoreOutput=true时output只含尾部4096字符预览，
outputLength为原长度。展开完整输出调用notifier.loadToolOutput(message.id,tool.id,{offset:0})，
返回ChatToolOutputPage(text,nextOffset)，每次最多16384字符；nextOffset非空显示加载下一段。
只能按用户动作读取，不要展开时自动循环读完；切换会话丢弃旧结果。实时工具尚未分页时也应限制首屏输出长度。

## 测试衔接注意

ChatRepository 现使用后台SQLite，测试须为每个用例注入临时文件的
`chatRepositoryProvider.overrideWith((ref) => ChatRepository(ref.read(localStorageServiceProvider), databasePath: tempPath))`。
不要测试读写实际应用目录，也不要让单元测试依赖path_provider插件。
历史断言改读repo.loadSession/exportAll，不再断言旧preferences随新会话改变（它是保留的迁移源）。
首次provider启动/切换Agent/共享开关须等待isLoadingSessions/isLoadingMessages结束，不能固定pumpEventQueue假定磁盘已完成。
服务层目录探测现在读取runWithResult.stdout及exitCode，避免Docker bash警告污染路径。
代码修改仍在进行，最终门禁应在明确冻结后执行；禁止为适配旧测试恢复错误协议或同步全量历史。


独立 SQLite 聊天存储、后台操作、摘要30/消息50分页；保留旧JSON并验证迁移。
流式检查点、明确中断状态、有限脱敏日志；目录/附件/命令/远端历史/搜索重命名导出/工具详情/用量/隔离草稿。
非目标：多Agent并行、客户端代执行文件/终端RPC、MCP配置、自动升级远端。
真实当前Codex会话仅允许读取列表，不能发消息/修改/删除；验证用独立测试会话与临时目录。
完成依据为针对性和全量测试、分析、性能样本、release产物哈希及保留数据ADB覆盖安装；真实远端未测必须标注。

用户后续明确：当前没有独立ACP测试目标，本轮由OpenCode完成逻辑测试与ADB安装，
真实ACP对话及界面体验由用户自行测试。不得为验收擅自创建/发送当前运行中的Codex会话。

## 过程记录（最终状态见末节）

- 已确认指定 AgY/OpenCode 模型并实际调用；尚未完成本轮最终门禁或构建。
- OpenCode第一阶段9项协议/设置核心回归通过。SQLite专项原11项及新增归属/序号/重命名保护3项（共14项）通过；新增长工具输出用例正在验收。
- 异步存储fixture维护后，现有会话provider专项33项通过；新增附件、命令、回放及界面回归仍在进行，不能用局部通过替代全量门禁。
- 历史性能样本（开发环境，非手机）：500会话/10000消息，迁移约93ms、写入约101ms、摘要30条约1ms、末50条不足1ms。取自OpenCode存储测试，不能据此宣称真机无卡顿。
- 原始验证日志位于`/tmp/valhalla-acp-verification/`及`/tmp/valhalla-acp-repository-test-summary.txt`；这些是当前环境产物，非永久仓库附件。
- 长工具输出验收追加完成：聊天存储18项、关联存储48项通过。仓库内报告见`agent-workflow/acp-repository-verification.md`。业务接口已冻结，后续仅处理门禁发现的问题；UI最终静态检查与全量回归尚未完成。

### 最后门禁记录（2026-09-30 09:46 UTC）

- OpenCode批次A：业务5文件格式/lint完成，provider33、adapter20、repository18、SSH framing3均通过。误写的`acp_ssh_transport_test.dart`不存在，实际回归文件为`acp_ssh_framing_test.dart`；没有将缺失文件错误计作产品缺陷。报告`agent-workflow/acp-gate-a.md`。
- 批次B：列表无new、附件协商/限额、commands/usage、回放隔离4项通过；adapter/resume/features组合33项通过。报告`agent-workflow/acp-gate-b.md`。
- 批次C：首轮全量1188通过、17既有环境跳过、0失败；在B新增4项之前运行，因此不是最终冻结版全量。报告`agent-workflow/acp-gate-c.md`；skip文件归属已由源码校正。
- 当前`flutter analyze --no-pub`为0 error/0 warning/14 info，全部在`lib/features/chat/ai_chat_view.dart`：导出/远端附件弹窗的异步context存活检查11项、withData弃用2项、匿名参数1项。仍未达到零问题发布门禁。
- 指定AgY会话连续出现`subscriber fell behind updates`和EOF；需同时检查文件，因为部分调用虽返回ERROR却确实落盘。dart:convert与中英文rename/refresh/sessionTitle已补齐、unused show已移除；上述14项尚未修好。
- 用户明确选择“仍全部交给AgY，等待连接恢复”；根代理继续不得编辑UI，包括非展示逻辑。重命名异步存储失败的错误反馈也已交给AgY，但尚未落盘。
- **没有新APK、没有本轮ADB安装**。后续必须在UI收尾后由OpenCode最终复验、构建release并`adb install -r`，不得卸载/清数据。不得测试当前正在运行的真实Codex会话。

### AgY重启与续接

用户告知已更换AgY账号并要求重启。已完整退出AgY进程后重新启动；
控制台显示的账号已由用户明确确认可继续使用，未清理或覆盖任何认证文件。
普通交互启动`agy --conversation ec81a4be-7543-45ee-8658-f68966f57d3b --model gemini-3.8-flash-high --effort high --mode accept-edits`
退出时回显同一conversation ID，可用于后续交互续接。
不要使用`--prompt-interactive`续接：本次它的退出提示给出不同ID，已停止该调用；仅有只读定位操作，没有接受它编辑UI。
非交互print报告订阅失败并不可靠地表示远端任务已停止，普通交互重新打开时可能仍看到此前任务进行中；避免同时派发多个任务。

### 恢复后的收尾

普通交互控制台曾报告账号头像请求超时导致Eligibility Check失败；容器只读网络探测确认域名可达后，完整退出并重新启动AgY，再在原会话输入任务，已恢复执行。
AgY已完成剩余context.mounted保护、重命名失败反馈、弃用参数及匿名参数修复；退出回显仍为`ec81a4be-7543-45ee-8658-f68966f57d3b`，控制台模型为Gemini 3.8 Flash / high。
源码现已冻结，最终格式/分析/全量测试、release构建和保留数据ADB安装已交给OpenCode指定模型执行；结果以`agent-workflow/acp-final-release.md`为准，尚未得到成功报告前不得宣称已安装。

### 最终结果（替代上述过程中“尚未发布/安装”的状态）

- AgY在原Valhalla会话完成所有展示修改；用户确认的账号、Gemini 3.8 Flash / high。根代理没有取得或使用UI编辑例外。
- OpenCode `opencode/mimo-v2.6-flash-free`：最终全量1192通过、17既有环境跳过、0失败；静态检查零问题，格式复验与diff-check通过。
- release APK：`build/app/outputs/flutter-apk/app-release.apk`，122288727字节，2026-09-30 10:01:13 UTC；SHA-256 `4e4c4adc294e740cc85f0dee67e38d3e0aa599f25e1e596c15accb328fc342e9`。1.0.0+1，沿用Android Debug证书，不宣称商店签名。
- `adb -s 127.0.0.1:14251 install -r`成功，保留原应用数据；安装更新时间为2026-09-30 18:01:26 +0800。冷启动10秒后PID11636仍存活，启动窗口无AndroidRuntime fatal；模拟器环境警告见原始日志。
- 真实ACP对话、服务器环境和界面操作按用户选择留给用户验证；未触碰当前运行的Codex会话。
- 详细报告：`agent-workflow/acp-final-release.md`；日志：`agent-workflow/acp-final-*.log`（当前环境文件，非永久跨机器附件）。后续不再扩展本轮范围，不提交或推送。
