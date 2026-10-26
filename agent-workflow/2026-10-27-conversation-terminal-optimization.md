# 智能会话与终端六项优化：实施契约

用户批准六项、分三阶段交付：阶段1恢复反馈与长内容性能；阶段2智能会话全文搜索与终端缓冲搜索；阶段3上下文/命令整理与保留布局的快捷栏优化。
基线1.0.19+20，76fbdb7。上轮未提交tmux诊断补丁和测试纳入阶段1，不宣称已解决实服INVALID_RESPONSE。UI/ARB只能原AgY会话 ec81a4be-7543-45ee-8658-f68966f57d3b，gemini-3.8-flash-high/high；主代理core/data/infrastructure/docs；免费OpenCode验证，耗尽/不可用时已核验免费CodeBuddy。

## 已确认选择
- 搜索App本地已保存历史，远端手动导入；当前会话默认，可切换当前服务器，沿用Agent共享过滤。
- 保留终端网格/位置/颜色/高度和用户配置，完善状态、触控、动画；不替换布局。
- 每阶段门禁通过后新增patch/build，既有release.py正式签名Android3APK/AAB+Linuxx64，GH/Ygg代理/官网。失败同批resume，无Actions/Apple/Windows构建，无ADB安装或真实Agent/生产tmux写入。

## 阶段1 AgY UI任务
1. 复用现有固定位置顶部浮层显示连接/同步状态；不插入消息/终端造成布局移动。区分SSH连接与Agent运行/历史同步，背景离线不误标已停止。普通成功提示4秒消失；错误可关闭/详情/重试，重试捕获原目标，不重发prompt/命令。不要重写已有恢复机制。终端历史每个来源/会话显示最近检查时间：主代理新增SshTerminalState.socketCheckedAt (Map<String,DateTime>，按socket.id)，无值显示未检查，已有状态标签保持。
2. 长内容：已完成的Markdown文本块独立可缓存组件，消息流只更新变化块；保留orderedContentBlocks顺序和稳定键。历史已完成代码块>30行默认12行，可展开/复制全部/独立可选中文字阅读器；普通正文完整显示，不破坏fence/表格/链接处理。展开状态按session/message/block持有且不随重连或完成改变，生成中的块不突然折叠。工具卡片默认摘要(状态/名称/耗时)，现有分页详情复用，展开状态刷新不丢。不要截断原始数据或拷贝内容。
3. 所有新文案翻译全部17个ARB，复用主题、减少动画、320/390dp与大字体。不得改core/data/infrastructure/test，不测试/格式/生成/构建/提交/发布。仅阶段1，阶段2/3等后续指令。

## 阶段2接口（准备中）
ChatRepository.searchMessages(serverId,{sessionId,agentId,query,cursor,limit=30}) 返回ChatSearchPage(hits,nextCursor)，ChatSearchHit含sessionId/messageId/sequence/title/role/source/toolId/excerpt。参数化字面、不区分大小写，本地SQLite/Isolate，默认无远端拉取。loadMessageWindow(sessionId,messageId,{radius=15})加载目标附近。UI300ms防抖/目标epoch隔离，关闭不清草稿，命中可返回搜索结果。终端查本地buffer，独立页签控制器，CtrlShiftF/MacCmdF进入，不发服务器命令。

## 阶段3接口（准备中）
复用现有commandsProvider和能力目录；Agent命令收藏/最近按server+execution+agent隔离，失效条目禁用；选择只填草稿。终端按原网格/主题提示单次/锁定，可清除全部修饰键；局部120-180ms反馈，后台停止，明确常用命令预览发送，多行仍确认。

## 验收
逐阶段记录实际测试、format/l10n/analyze/发布证据。阶段1延续冷历史/滚动/后台状态、乱序重放、长代码/工具输出、tmux隔离测试；阶段2中文/代码/工具/分页/跨Agent/过期查询/一万消息与buffer滚动；阶段3草稿附件隔离、能力失效、Gboard组合键、取消按压与后台重复停止。不得用模拟测试宣称实服tmux问题已解决。

阶段2定位实现约束：消息数据目前使用单一连续分页窗口。搜索命中打开独立只读定位阅读器，调用loadSearchWindow取得目标前后15条，突出匹配并支持返回搜索结果；不把不连续旧页与运行中的最新输出拼成同一个会话窗口，不更改草稿/远端任务/当前活动会话。另提供正常“打开会话”入口。这样保留原计划的定位阅读能力并防止运行消息/序号被搜索污染。
阶段1核心初步证明：CodeBuddy hy3已补3项socketCheckedAt回归，三文件原始machine日志done.success=true；117项常规测试通过（回执120含3个隐藏suite-loading），日志stage1-core.raw。UI最终门禁另跑，不把此次结果当作已打包。

阶段1 UI由原AgY完成：新增Markdown安全分块（复杂语法整体回退）、有状态代码预览/完整复制/阅读器、独立工具展开键、可关闭状态浮层与来源检查时间。首轮分析的文案getter和fixture覆盖告警已修正；首次UI回归暴露代码末尾LF计数与fixture取值/异步选择问题，已分别由AgY与CodeBuddy修正，正在重跑最终门禁。当前尚未升号或发布，后两阶段仍只有忽略目录中的核心草案，不能计为已交付。

阶段1最终门禁：CodeBuddy免费DeepSeek执行，证据stage1-gates-20261026T183917Z，生成/格式/全项目分析(零问题)/36文件458项常规测试/diff-check全部0，无失败跳过。代码阅读7项测试真实点击全部命中，收起仍严格断言12行、复制完整含LF；改正只涉及fixture滚动后布局等待，并未放宽断言。进入1.0.20+21既有脚本构建发布；阶段2/3尚未实施。

阶段1已完成正式1.0.20+21发布，回执见2026-10-27-v1020-release.md；官网revision109。阶段2已接入核心查询与只读缓冲搜索，AgY实现UI、CodeBuddy补回归中，尚未交付。

阶段2实现中：核心本地SQLite字面搜索/Unicode折叠/稳定游标/完整工具输出/只读窗口已接入；终端只读搜索支持软换行/CJK/Emoji、取消、最多1000命中及buffer身份验证。CodeBuddy核心三文件最终边界回归23项常规测试通过（machine回执28含隐藏加载），一万条消息本机约55ms、事件循环55次tick。UI首轮发现迟到highlights、范围行溢出、中心Sliver定位等，已交AgY修正；尚未升号、最终门禁或打包，不将局部通过算作交付。

阶段2补充诊断：新回收行UI用例出现同步循环。核心静态反例明确：满环回绕后replaceWith在旧_startIndex上adopt，最后才归零_startIndex，造成替换列表顺序和IndexedItem.index错位；trimStart没有detach移除行或增加_absoluteStartIndex。主代理已在纯数据层修正两处，并给搜索锚点加非负边界。未改渲染/UI；仍需实际回归验证，不能把静态证明当作测试通过。免费CodeBuddy此时多次TLS ECONNRESET/空响应，OpenCode已核验零成本GLM模型同样启动挂起；本轮直接验证例外请求已异步发出，尚未收到回复，主代理没有代跑应用测试或打包。

阶段2根因验证：CodeBuddy恢复后，仅写4项共享缓冲不变量回归，和原17项终端UI回归一并运行（stage2-buffer-final.raw/.exit=0），21项常规测试通过、done.success=true、约4.25秒。原maxLines100回收用例在核心修复前同步循环（已保留超时/中止日志），相同UI/fixture在修正环形原点和trimStart后通过，明确为共享索引不变量问题；最初容量猜测不能作为最终根因。主代理尚未自行运行应用测试，授权请求仍未收到回复；继续按原免费执行器流程。

阶段2最终门禁：stage2-gates-20261026T201940Z，42文件514项常规测试、生成/格式/分析零问题/diff-check全部0，无失败跳过。准备以1.0.21+22独立发布；阶段3仅忽略目录UI草稿，不含本版源码。
