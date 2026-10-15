# AgY 后续：Agent 更新完整交互与实际页面进入触发

仍只原Valhalla会话/Gemini3.8Flash high。先完成前批恢复浮层/文件工具栏，再做
本批；不自行改core。读 `2026-10-15-agent-updates-toolbar.md` 与更新API最新源码/
同事将提供的 `2026-10-15-agent-updates-api.md`，不能猜属性。

## 白名单

lib/features/agents/agent_management_view.dart，必要新增agents/widgets更新弹窗；
lib/features/chat/ai_chat_view.dart、cli_chat_view.dart，lib/features/shell/main_shell.dart
与widgets/connection_status_banner.dart，必要新增统一notice widget，17个ARB。
仅 UI/交互/文案；不改生产core/data/infrastructure/tests/平台/依赖，不跑格式/
生成/测试/构建/ADB，不提交推送。17种语言齐全，不以英文填充其他语言。

## 已有核心API

`agentUpdatesProvider` -> AgentUpdatesState(serverId,agents,generation,lastUpdatedAgentId,
availableCount,isChecking,isUpdating)，agents[id]是AgentUpdateEntry(report,isChecking,
isUpdating,interrupted,errorCode,log,lastAttemptAt,lastSuccessfulCheckAt)。
report.components各有component(cli/acp)、status(current/available/unsupported/missing/error)、
installedVersion/latestVersion/source/reasonCode，canUpdate来自当前探测command。
缓存report不存command，因此UI不能只依赖canUpdate隐藏升级：status available后
先调用prepareUpdate重新验证生成精确计划。
notifier.onChatEntered()、checkAll({force=true})、checkAgent(id,{force=true})、
prepareUpdate(id,{Set<AgentUpdateComponent>? components}) -> AgentUpdatePlan、
applyConfirmedUpdate(plan)。计划含server/profile/resolvedContainerId/runtimeIdentity/
components/commandPreview；固定目标，UI确认后原对象交回，不重新生成替代。
noticeCount/dismissUpdateNotice()已提供日内提示去重，按最终API为准。

## 交互

- 17个ARB中`agentClaudeCode`仍是旧`Claude CodeX`，统一修为`Claude Code`；
  core新预设已经正确，不要改已有用户自定义名称。
- 前批复核：Dashboard标题Wrap里条件出现的`dashboardStaleDataIndicator`
  文本仍能换行撑高正文，不符合不位移；改为常驻固定尺寸状态icon/tooltip，
  缓存详细时间放统一顶部详情，不在正文动态插入长Text或SizedBox。
- 新工具栏配置弹窗打开前清焦点，关闭后不能自动召回此前搜索框输入法；保存
  进行中禁止barrier/back关闭，防止关闭后仍意外提交的交互歧义。
- 新复核：terminal_view.dart正文Column仍插入恢复失败error/notice，尤其
  TERMINAL_RESTORE_FAILED、TERMINAL_PLAIN_INTERRUPTED，自动rebind失败时
  也会挤动PTY。仅这些恢复类错误改到现有terminal Stack/Positioned浮层，
  历史删除/改名/安装等非恢复错误保留原安全交互；不改provider重连算法。
  本小修允许terminal_view.dart白名单。More transfers只有onTransfers非空
  才可点击，不能只有transferAction widget却假装回调可用。
- 管理页上方手动检查全部；各卡片展开后检查更新/CLI和ACP当前→最新版本、
  来源、检查时间及独立状态。未检查/未知不说最新，检查失败不改登录/可用标识。
- 选择要更新的组件，再prepareUpdate，弹确认窗展示服务器、容器/用户、版本、
  命令、旧Claude适配器迁移说明。OpenCode同程序只一项。默认稳定渠道不降级。
  AgY 原生 CLI 使用官方更新器：提示其按执行时稳定渠道更新，可能安装比确认
  快照更新的稳定版本；核心执行前会再核对目录，变化时要求重新确认。
  确认按钮防重复，取消零远端修改。未知来源只显示手动处理与诊断，不执行猜命令。
- 执行时流式log有界显示并可复制、进度/失败原因可见，不把流结束当成功。
  升级中不能再次检查或编辑/删除/登录该服务器Agent（core有server-wide锁），
  现有消息/草稿仍可阅读。断线说明需核对结果，不自动重试更新。
- 顶部发现更新提示不占正文位置；复用现有浮层位置，重连提示优先、不堆两个
  提示；点击打开更新列表并确认后才升级，手动检查入口持续可达。
- 每日检查触发必须在真实进入ACP/CLI页面时，不是IndexedStack两个页面的
  initState（所有页面可能预挂载）。MainShell统一实际index变更/启动页、服务器
  切换时，在postFrame调用onChatEntered，避免build内同步修改provider及逐帧触发。
  未连线时core记住entered，连上后会检查；两个页面共享去重。禁用CLI实验功能
  不应为了检查将其启用或自动导航。

## 登录/运行锁接线（避免更新与登录并发）

AgentRegistryNotifier新增 beginInteractiveLogin(agentId)->Object?；null=未取得
登录资格（锁/离线/忙），不要打开终端。成功取得token后在try/finally调用
endInteractiveLogin(agentId,token)，包括用户关闭/切服务器/失败。管理页及ACP
fallback CLI登录的interactiveLoginLauncher两入口都必须接。需要在确认之后、
真正打开终端之前取token，不能在用户看确认弹窗时占用登录状态。
AGENT_UPDATE_IN_PROGRESS/AGENT_UPDATE_BUSY等错误映射准确本地化，不露生key。
ai/cli核心发送/切模型/认证有锁；UIdisabled+说明不能只做视觉不走core。

窄屏320dp/2倍字号/RTL/安全区，确认信息可滚动且按钮可达；弹窗关闭不弹键盘。
完成只报告实际落盘与未验收项。测试与生成由OpenCode负责。
