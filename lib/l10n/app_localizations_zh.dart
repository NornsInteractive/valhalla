// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI 原生远程服务器与 Agent 运维中心';

  @override
  String get navAiChat => '智能会话';

  @override
  String get navTerminal => 'SSH终端';

  @override
  String get navFiles => '远程文件';

  @override
  String get navCommands => '快捷运维';

  @override
  String get navSettings => '系统设置';

  @override
  String get serverConnected => '已连接';

  @override
  String get serverOnline => '在线';

  @override
  String get serverOffline => '离线';

  @override
  String get latencyMs => '毫秒';

  @override
  String get reconnect => '重新连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get quickDisconnect => '快速断开';

  @override
  String get newSession => '新建会话';

  @override
  String get historySessions => '历史会话';

  @override
  String get switchAgent => '切换运维 Agent';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => '当前生效 Agent';

  @override
  String get inputPromptHint => '让 Agent 诊断系统、调用工具或编写脚本... (Enter 发送)';

  @override
  String get thinking => '思考逻辑链';

  @override
  String get executionPlan => '执行计划步骤';

  @override
  String get toolCall => '工具调用';

  @override
  String get toolStatusPending => '排队中';

  @override
  String get toolStatusRunning => '正在执行...';

  @override
  String get toolStatusCompleted => '已完成';

  @override
  String get toolStatusFailed => '执行失败';

  @override
  String get permissionRequired => '需要操作审批';

  @override
  String get permissionDescription => 'Agent 请求在目标服务器上执行以下指令：';

  @override
  String get permissionReject => '拒绝执行';

  @override
  String get permissionAllowOnce => '允许执行一次';

  @override
  String get permissionAllowAlways => '始终信任允许';

  @override
  String get quickTroubleshootCpu => '排查 CPU 占用异常';

  @override
  String get quickDockerHealth => 'Docker 容器健康诊断';

  @override
  String get quickCleanCache => '清理系统无用缓存';

  @override
  String get quickNginxLogs => '排查 Nginx 错误日志';

  @override
  String get terminalNewTab => '新标签页';

  @override
  String get terminalCloseTab => '关闭标签';

  @override
  String get terminalClear => '清屏';

  @override
  String get terminalQuickCmds => '常用命令库';

  @override
  String get terminalPaste => '粘贴';

  @override
  String get sftpCurrentPath => '当前工作路径';

  @override
  String get sftpUpload => '上传文件';

  @override
  String get sftpNewFolder => '新建目录';

  @override
  String get sftpNewFile => '新建文件';

  @override
  String get sftpRefresh => '刷新列表';

  @override
  String get sftpSearchHint => '搜索文件或目录名...';

  @override
  String get sftpEmpty => '当前目录暂无文件';

  @override
  String get sftpFileName => '文件名';

  @override
  String get sftpFileSize => '大小';

  @override
  String get sftpFilePerm => '权限';

  @override
  String get sftpFileModified => '最后修改时间';

  @override
  String get cmdCategoryDocker => 'DOCKER CONTAINER STACK · 容器生态';

  @override
  String get cmdCategorySystem => 'SYSTEM MAINTENANCE · 宿主机维保';

  @override
  String get cmdCategoryNetwork => 'NETWORK & PORTS · 网络与端口';

  @override
  String get cmdExecute => '执行';

  @override
  String get cmdDangerous => '高危危险指令';

  @override
  String get cmdDangerousWarning => '此操作不可逆且可能引发服务中断，您确定要强制执行吗？';

  @override
  String get cmdParamRequired => '需要提供动态参数';

  @override
  String get cmdConfirm => '确认并执行';

  @override
  String get cmdCancel => '取消';

  @override
  String get settingsAppearance => '外观与个性化';

  @override
  String get settingsThemeMode => '显示主题模式';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeSystemDesc => '自动适应系统外观';

  @override
  String get themeLight => '明亮浅色';

  @override
  String get themeLightDesc => '高对比清爽白底';

  @override
  String get themeDark => '极客暗黑';

  @override
  String get themeDarkDesc => '经典沉浸炭黑';

  @override
  String get themeAmoled => '高对比纯黑';

  @override
  String get themeAmoledDesc => 'OLED 0x000000 极致省电';

  @override
  String get settingsAccentColor => '主题强调色';

  @override
  String get accentCyberEmerald => '极客翠绿 (Cyber Emerald)';

  @override
  String get accentTechBlue => '科技深蓝 (Tech Blue)';

  @override
  String get accentElectricViolet => '电光紫 (Electric Violet)';

  @override
  String get accentCrimsonRed => '活力绯红 (Crimson Red)';

  @override
  String get accentAmberOrange => '温暖明橙 (Amber Orange)';

  @override
  String get settingsLanguage => '语言与字符编码';

  @override
  String get langZh => '简体中文 (Simplified Chinese)';

  @override
  String get langEn => 'English (US)';

  @override
  String get settingsAiOps => 'AI 运维助手与引擎 (Agent Ops)';

  @override
  String get settingsSecurity => '连接与系统安全';

  @override
  String get settingsKnownHosts => '已知主机公钥指纹 (Known Hosts)';

  @override
  String get settingsClearStorage => '清除凭据缓存';

  @override
  String get settingsResetDefault => '重置所有设置';

  @override
  String get settingsTerminalUseTmux => '会话保活 (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle => '在远端服务器上用 tmux 承载终端会话';

  @override
  String get settingsTerminalUseTmuxDescription =>
      '断线后仍保留终端输出，需要远端已安装 tmux。更改仅对新打开的终端标签页生效。';

  @override
  String get settingsTerminalFontSize => '终端字体大小';

  @override
  String get settingsTerminalFontSizeSubtitle => '调整 SSH 与 CLI 终端的字号';

  @override
  String get version => '版本';

  @override
  String get addServer => '添加服务器';

  @override
  String get editServer => '编辑服务器';

  @override
  String get serverName => '服务器名称';

  @override
  String get serverHost => '主机地址 / IP';

  @override
  String get serverPort => '端口';

  @override
  String get serverUsername => '用户名';

  @override
  String get serverAuthType => '认证方式';

  @override
  String get serverPassword => '登录密码';

  @override
  String get serverPrivateKey => '私钥内容';

  @override
  String get serverSave => '保存服务器';

  @override
  String get serverDelete => '删除服务器';

  @override
  String get fileEditor => '文件编辑器';

  @override
  String get fileEditorSave => '保存修改';

  @override
  String get fileSavedSuccess => '文件已成功保存回写';

  @override
  String get addCommand => '新建指令';

  @override
  String get commandTitle => '指令标题';

  @override
  String get commandContent => '执行脚本';

  @override
  String get commandCategory => '分类';

  @override
  String get commandDescription => '指令描述';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get cmdExecutionChannel => '选择执行通道';

  @override
  String get cmdChannelTerminal => '直通当前 SSH 终端';

  @override
  String get cmdChannelTerminalDesc => '指令将键入至活跃终端并执行，适合交互式查看实时输出';

  @override
  String get cmdChannelBackground => '后台独立通道运行';

  @override
  String get cmdChannelBackgroundDesc =>
      '通过 SSH 独立会话以 Login Shell 方式执行，并弹窗捕获输出';

  @override
  String get cmdInjectedToTerminal => '指令已注入活跃终端';

  @override
  String get cmdExecutionCompleted => '指令执行完成';

  @override
  String get cmdExecutionFailed => '指令执行失败';

  @override
  String get cmdExecutingRemote => '正在通过远端 SSH 执行指令...';

  @override
  String get cmdClose => '关闭';

  @override
  String get navDashboard => '仪表盘';

  @override
  String get navDocker => '容器管理';

  @override
  String get navSystem => '系统运维';

  @override
  String get navMore => '更多功能';

  @override
  String get dashboardTitle => '服务器仪表盘';

  @override
  String get metricsCpu => 'CPU 使用率';

  @override
  String get metricsMemory => '内存占用率';

  @override
  String get metricsLoadAvg => '系统平均负载';

  @override
  String get metricsUptime => '系统持续运行';

  @override
  String get metricsRootDisk => '根分区存储';

  @override
  String get quickActions => '常用快捷入口';

  @override
  String get activeServerStatus => '目标服务器状态';

  @override
  String get noServerSelected => '当前未连接到任何服务器，请先选择并连接服务器。';

  @override
  String get serverDisconnected => '未连接';

  @override
  String get serverConnecting => '正在连接...';

  @override
  String get connectNow => '立即连接';

  @override
  String get serverSpecs => '服务器规格与信息';

  @override
  String get dockerTitle => 'Docker 容器';

  @override
  String get dockerSearchHint => '搜索容器名称或镜像...';

  @override
  String get dockerFilterAll => '全部';

  @override
  String get dockerFilterRunning => '运行中';

  @override
  String get dockerFilterExited => '已退出';

  @override
  String get dockerFilterPaused => '已暂停';

  @override
  String get dockerActionStart => '启动';

  @override
  String get dockerActionStop => '停止';

  @override
  String get dockerActionRestart => '重启';

  @override
  String get dockerActionPause => '暂停';

  @override
  String get dockerActionUnpause => '恢复';

  @override
  String get dockerActionRm => '删除容器';

  @override
  String get dockerActionLogs => '日志';

  @override
  String get dockerActionInspect => '详细元数据';

  @override
  String get dockerLogsTitle => '容器标准输出日志';

  @override
  String get dockerInspectTitle => '容器 Inspect 详情';

  @override
  String get dockerNoContainers => '服务器上未找到 Docker 容器';

  @override
  String get dockerEmptyRunning => '暂无运行中的容器';

  @override
  String get dockerPorts => '端口映射';

  @override
  String get dockerCreated => '创建时间';

  @override
  String get dockerImage => '镜像';

  @override
  String get systemTitle => '进程与系统服务';

  @override
  String get tabProcesses => '系统进程';

  @override
  String get tabServices => 'Systemd 服务';

  @override
  String get processSearchHint => '按进程名或 PID 检索...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => '内存 %';

  @override
  String get processStat => '状态';

  @override
  String get processCommand => '命令/进程';

  @override
  String get processTerminate => '终止 (SIGTERM)';

  @override
  String get processForceKill => '强制杀死 (SIGKILL)';

  @override
  String get processKillForbidden => '拒绝终止系统根进程 (PID <= 1)';

  @override
  String get serviceSearchHint => '搜索系统服务名称...';

  @override
  String get serviceName => '服务单元';

  @override
  String get serviceDescription => '描述';

  @override
  String get serviceStatus => '运行状态';

  @override
  String get serviceStartup => '自启状态';

  @override
  String get serviceActionStart => '启动服务';

  @override
  String get serviceActionStop => '停止服务';

  @override
  String get serviceActionRestart => '重启服务';

  @override
  String get serviceActionReload => '重载配置';

  @override
  String get serviceActionEnable => '启用自启';

  @override
  String get serviceActionDisable => '禁用自启';

  @override
  String get serviceNoServices => '未找到相关 systemd 服务';

  @override
  String get riskDangerTitle => '高危操作风险确认';

  @override
  String get riskWarningTitle => '操作确认警示';

  @override
  String get riskSafeTitle => '确认执行操作';

  @override
  String get riskIrreversibleWarning => '该操作被识别为【高危风险】，执行后不可逆，可能引发系统瘫痪或严重数据损坏！';

  @override
  String get riskWarningDescription => '该操作可能中断正在运行的线上业务或重启系统服务，请确认后操作。';

  @override
  String get riskCommandPreview => '待执行指令预览';

  @override
  String get riskConfirmButton => '确认继续执行';

  @override
  String get riskCancelButton => '取消放弃';

  @override
  String get stateLoading => '正在获取远端数据...';

  @override
  String get stateOffline => '服务器离线未连接';

  @override
  String get stateOfflineDesc => '请先连接目标服务器，随后即可实时查看指标与管理资源。';

  @override
  String get stateError => '执行操作时发生错误';

  @override
  String get stateRetry => '重试刷新';

  @override
  String get stateEmpty => '暂无匹配数据';

  @override
  String get inspectorTitle => '检查器';

  @override
  String get inspectorClose => '收起检查器';

  @override
  String get inspectorDetails => '检查器详细信息';

  @override
  String get selectServerTitle => '选择目标服务器';

  @override
  String get sshDisconnectedSuccess => '已断开 SSH 连接';

  @override
  String get trustHostFingerprintTitle => '信任主机公钥指纹？';

  @override
  String get trustAndConnect => '信任并连接';

  @override
  String get reject => '拒绝';

  @override
  String get confirmDeleteServerTitle => '删除服务器';

  @override
  String get noServersFound => '暂无已配置的服务器';

  @override
  String get agentNotReadyError => '选中的 Agent 尚未就绪，请先检查其运行环境与配置。';

  @override
  String get sshDisconnectedError => 'SSH 连接已断开，请先连接服务器后再使用 AI 运维功能。';

  @override
  String get noAgentAvailable => '无可用 Agent';

  @override
  String get noAgentAvailablePrompt => '当前无可用 Agent，请先配置或就绪 Agent。';

  @override
  String get noAgentAvailableHint => '请先选择或配置可用 Agent 才能发送消息...';

  @override
  String get manageAgents => '管理 Agent';

  @override
  String get noReadyAgentsTitle => '暂无就绪的 Agent';

  @override
  String get noReadyAgentsDesc => '当前服务器上尚无通过环境检测的 Agent。';

  @override
  String get agentStatusReady => '已就绪';

  @override
  String get agentStatusChecking => '检测中...';

  @override
  String get agentStatusCliMissing => '未检测到安装';

  @override
  String get agentStatusAcpMissing => '未检测到 ACP 组件';

  @override
  String get agentStatusNotLoggedIn => '未登录';

  @override
  String get agentStatusError => '异常';

  @override
  String get agentStatusUnknown => '未检测';

  @override
  String get agentActionInstall => '安装';

  @override
  String get agentActionLogin => '登录';

  @override
  String get agentActionRefresh => '检测状态';

  @override
  String get noConfiguredAgents => '当前服务器未配置任何 Agent';

  @override
  String get agentManagementTitle => 'Agent 管理';

  @override
  String get settingsAgentManagement => 'Agent 管理';

  @override
  String get settingsAgentManagementSubtitle => '配置、检测与管理当前服务器的 ACP Agent 环境';

  @override
  String get addAgentButton => '添加 Agent';

  @override
  String get noServerSelectedForAgents => '未选择服务器，请先在主界面选择目标服务器。';

  @override
  String get sshDisconnectedAgentWarning =>
      '当前未连接 SSH，无法执行探测、安装或登录操作。请先建立 SSH 连接。';

  @override
  String get noAgentsConfiguredTitle => '当前服务器暂未添加任何 Agent';

  @override
  String get noAgentsConfiguredDesc =>
      '您可以添加 Claude Code、Codex、OpenCode、AGY 或自定义 ACP Agent，在当前服务器检测通过后即可在 AI 运维中使用。';

  @override
  String get agentPresetLabel => '配置预设';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => '自定义';

  @override
  String get agentNameLabel => 'Agent 名称';

  @override
  String get agentNameHint => '例如：生产环境 Codex';

  @override
  String get agentDescriptionLabel => '说明';

  @override
  String get agentDescriptionHint => '简要说明此 Agent 的用途或模型';

  @override
  String get agentCliCommandLabel => 'CLI 探测命令';

  @override
  String get agentCliCommandHint => '例如：claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP 启动命令';

  @override
  String get agentAcpCommandHint => '例如：codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => '安装命令 (选填)';

  @override
  String get agentInstallCommandHint => '例如：npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => '登录检查命令 (选填)';

  @override
  String get agentLoginCheckCommandHint => '例如：codex --version';

  @override
  String get agentLoginCommandLabel => '登录命令 (选填)';

  @override
  String get agentLoginCommandHint => '例如：codex login';

  @override
  String get agentSaveButton => '保存并检测';

  @override
  String get agentCliRequired => 'CLI 探测命令不能为空';

  @override
  String get agentAcpRequired => 'ACP 启动命令不能为空';

  @override
  String get agentNameRequired => 'Agent 名称不能为空';

  @override
  String get confirmInstallAgentTitle => '确认执行安装命令';

  @override
  String get confirmLoginAgentTitle => '确认执行登录命令';

  @override
  String get agentCommandRiskWarning =>
      '此命令将在远程服务器上以当前登录用户权限直接执行，可能修改系统环境或安装软件包。请确认命令安全后再继续。';

  @override
  String get targetServerLabel => '目标服务器';

  @override
  String get commandPreviewLabel => '命令预览';

  @override
  String get executeButton => '执行';

  @override
  String get deleteAgentTitle => '删除 Agent';

  @override
  String get deleteAgentConfirm => '删除';

  @override
  String get agentStatusCheckingDesc => '正在远程服务器探测环境...';

  @override
  String get agentStatusInstalling => '正在远程服务器安装依赖...';

  @override
  String get agentStatusLoggingIn => '正在远程服务器执行登录...';

  @override
  String get agentNoLoginCheckProvided => '未配置登录检查命令';

  @override
  String get agentInstallPrompt => '未检测到安装，是否自动安装？';

  @override
  String get agentActionAutoInstall => '自动安装';

  @override
  String get agentLoginPrompt => '未登录，是否立即执行登录？';

  @override
  String get agentActionExecuteLogin => '立即登录';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      '当前服务器上的 Agent 尚未安装或未就绪，请前往管理并完成环境安装。';

  @override
  String get agentNeedsInstallOrReadyHint => '请先安装并就绪 Agent 后开始对话...';

  @override
  String get agentAcpInstallPrompt => '未检测到 ACP 组件，是否自动安装？';

  @override
  String get agentInstallCommandAcpLabel => 'ACP 安装命令（选填）';

  @override
  String get agentInstallCommandAcpHint =>
      '例如：npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand => '该 Agent 未配置安装命令，请手动编辑';

  @override
  String get agentInstallLogTitle => '安装输出';

  @override
  String get agentInstallLogEmpty => '等待安装输出…';

  @override
  String get agentInstallLogTruncated => '输出过长，仅显示最近部分';

  @override
  String get agentAcpOptional => '选填；留空表示仅使用 CLI';

  @override
  String get acpStreaming => 'ACP 流式输出中...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI 运维 Agent';

  @override
  String get aiOpsEmptySubtitle => '通过 SSH 通道上的 ACP stdio 连接';

  @override
  String get agentAuthRequiredTitle => '需要登录认证';

  @override
  String get agentAuthRequiredDesc => '该 Agent 需要先完成认证才能处理你的请求。';

  @override
  String get agentAuthMethodLabel => '认证方式';

  @override
  String get agentAuthNoMethodsNotice => 'Agent 未提供登录方式，请在服务器上检查其配置。';

  @override
  String get agentAuthProceedButton => '去登录';

  @override
  String get agentAuthCancelButton => '取消';

  @override
  String get agentAuthRetryHint => '完成登录后，请重新发送消息。';

  @override
  String get agentAuthRequiredError => '需要登录认证，请先完成登录。';

  @override
  String get agentLoginTerminalTitle => '交互式登录终端';

  @override
  String get agentLoginTerminalSubtitle => '请在下方终端中完成登录，按提示打开链接或输入验证码。';

  @override
  String get agentLoginTerminalRunning => '登录命令正在终端中运行...';

  @override
  String get agentLoginTerminalDisconnected => 'SSH 连接已断开，登录会话被中断。';

  @override
  String get agentLoginTerminalRetry => '重连终端';

  @override
  String get agentLoginTerminalFinish => '完成并检测';

  @override
  String get agentLoginTerminalClose => '关闭';

  @override
  String get agentLoginTerminalNoTtyHint => '若需要粘贴验证码，可长按终端粘贴，或使用 PASTE 按键。';

  @override
  String get agentLoginTerminalUrlLabel => '检测到登录链接';

  @override
  String get agentLoginTerminalUrlCopy => '复制链接';

  @override
  String get agentLoginTerminalUrlCopied => '登录链接已复制到剪贴板';

  @override
  String get agentLoginTerminalCopyAll => '复制全部输出';

  @override
  String get agentLoginTerminalCopiedAll => '终端输出已复制到剪贴板';

  @override
  String get sshStatusReconnected => '连接已恢复';

  @override
  String get sshStatusDisconnectedRetrying => '连接已断开，正在重试';

  @override
  String get sshStatusDisconnectedManual => '已断开';

  @override
  String get sshStatusHostKeyChanged => '主机密钥已变更 — 已拒绝连接';

  @override
  String get sshKeepAliveNotificationTitle => 'Valhalla 正在保持会话连接';

  @override
  String get terminalTmuxMissingNotice => '未检测到 tmux — 断线后会话无法保留';

  @override
  String get terminalTmuxSessionRestored => '终端会话已恢复';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable => '启用 Mosh — 支持断线漫游、切换网络不掉线的终端会话';

  @override
  String get moshServerPathLabel => 'mosh-server 路径';

  @override
  String get moshPortRangeLabel => 'UDP 端口范围';

  @override
  String get moshNewSession => '新建 Mosh 会话';

  @override
  String get moshNotInstalled =>
      '远端未找到 mosh-server。请先安装：sudo apt install mosh（Debian/Ubuntu）或 sudo dnf install mosh（Fedora/RHEL）。';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh 会话启动失败：$detail';
  }

  @override
  String get moshUdpTimeout => 'Mosh 连接超时 — 请检查 UDP 流量是否被防火墙拦截。';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Agent 会话已恢复';

  @override
  String get acpSessionRestartNotice => 'Agent 会话已重启 — 之前的上下文不可用';

  @override
  String get terminalTmuxInstallDialogTitle => '在远端服务器安装 tmux？';

  @override
  String get terminalTmuxInstallDialogMessage =>
      '远端服务器未检测到 tmux。安装 tmux 可在网络断线后继续保留终端会话并支持重连恢复。是否现在安装？';

  @override
  String get terminalTmuxInstallCommandLabel => '执行安装命令：';

  @override
  String get terminalTmuxInstallUnsupported =>
      '远端服务器未检测到受支持的包管理器，无法自动安装，请手动安装 tmux。';

  @override
  String get terminalTmuxInstallFailed => 'tmux 安装失败，请检查服务器执行权限及网络环境。';

  @override
  String get terminalTmuxInstallDisconnected => 'SSH 连接已断开，请重新连接服务器后再安装 tmux。';

  @override
  String get terminalTmuxInstallInstalling => '正在安装 tmux...';

  @override
  String get terminalTmuxInstallConfirm => '确认安装';

  @override
  String get terminalTmuxInstallSkip => '跳过（仅普通会话）';

  @override
  String get sftpDownload => '下载';

  @override
  String get sftpOpen => '打开';

  @override
  String get sftpUploadFailed => '上传失败，请检查权限后重试。';

  @override
  String get sftpDownloadFailed => '下载失败，请检查权限或本地空间。';

  @override
  String get sftpOpenUnsupported => '暂不支持打开该格式';

  @override
  String get sftpReadFailed => '读取文件失败，请检查权限后重试。';

  @override
  String get sftpTransferFailed => '文件操作失败，请重试。';

  @override
  String get sftpDownloadSuccess => '文件下载成功';

  @override
  String get sftpUploading => '正在上传...';

  @override
  String get sftpDownloading => '正在下载...';

  @override
  String get settingsAutoConnect => '启动时自动连接';

  @override
  String get settingsAutoConnectFixed => '固定默认SSH';

  @override
  String get settingsAutoConnectFixedDesc => '每次启动自动连接下方指定的服务器';

  @override
  String get settingsAutoConnectLast => '记住最后一次连接';

  @override
  String get settingsAutoConnectLastDesc => '启动时自动连接最近一次成功连接的服务器';

  @override
  String get settingsAutoConnectPickServer => '指定服务器';

  @override
  String get settingsAutoConnectNoServer => '尚未指定服务器';

  @override
  String get sftpSort => '排序';

  @override
  String get sftpSortName => '名称';

  @override
  String get sftpSortSize => '大小';

  @override
  String get sftpSortDate => '修改时间';

  @override
  String get sftpSortAscending => '升序';

  @override
  String get sftpSortDescending => '降序';

  @override
  String get themeQuickSwitch => '主题';

  @override
  String get transferList => '传输列表';

  @override
  String get transferEmpty => '暂无传输任务';

  @override
  String get transferUpload => '上传';

  @override
  String get transferDownload => '下载';

  @override
  String get transferStatusQueued => '排队中';

  @override
  String get transferStatusRunning => '传输中';

  @override
  String get transferStatusPaused => '已暂停';

  @override
  String get transferStatusCompleted => '已完成';

  @override
  String get transferStatusFailed => '失败';

  @override
  String get transferStatusCanceled => '已取消';

  @override
  String get transferPause => '暂停';

  @override
  String get transferResume => '继续';

  @override
  String get transferCancel => '取消';

  @override
  String get transferRemove => '删除';

  @override
  String get transferClearFinished => '清除已完成';

  @override
  String get transferSizeUnknown => '大小未知';

  @override
  String get transferFailedUpload => '上传失败';

  @override
  String get transferFailedDownload => '下载失败';

  @override
  String get stopGeneration => '停止';

  @override
  String get chatServerBindingRequired => '当前会话未绑定服务器，请绑定到当前服务器后继续。';

  @override
  String get chatSessionUnboundNotice => '当前会话尚未绑定到任何服务器。';

  @override
  String get bindServerAction => '绑定服务器';

  @override
  String get bindServerDialogTitle => '绑定会话到服务器';

  @override
  String get bindServerConfirmAction => '确认绑定';

  @override
  String get chatSessionIdentityMismatch =>
      '当前服务器或 Agent 与此会话绑定的身份不匹配，请切换到匹配的服务器和 Agent 后继续。';

  @override
  String get deleteSessionTitle => '删除会话';

  @override
  String get deleteSessionConfirmAction => '删除';

  @override
  String get shareAgentSessionsTitle => '共享 Agent 会话';

  @override
  String get shareAgentSessionsSubtitle => '在当前服务器的不同 Agent 间共享会话';

  @override
  String get shareAgentSessionsEnabled => '已开启 Agent 会话共享';

  @override
  String get shareAgentSessionsDisabled => '已关闭 Agent 会话共享';

  @override
  String get agentCliStatusInstalled => 'CLI: 已安装';

  @override
  String get agentCliStatusMissing => 'CLI: 未安装';

  @override
  String get agentCliStatusChecking => 'CLI: 检测中...';

  @override
  String get agentCliStatusUnknown => 'CLI: 未知';

  @override
  String get agentCliStatusError => 'CLI: 异常';

  @override
  String get agentAcpStatusReady => 'ACP: 已就绪';

  @override
  String get agentAcpStatusMissing => 'ACP: 未安装';

  @override
  String get agentAcpStatusChecking => 'ACP: 检测中...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: 待CLI安装';

  @override
  String get agentAcpStatusUnknown => 'ACP: 未知';

  @override
  String get agentAcpStatusError => 'ACP: 异常';

  @override
  String get agentAcpStatusNa => 'ACP: 不适用';

  @override
  String get agentAuthStatusAuthenticated => 'Auth: 已登录';

  @override
  String get agentAuthStatusUnauthenticated => 'Auth: 未登录';

  @override
  String get agentAuthStatusUnknown => 'Auth: 未检测';

  @override
  String get downloadNotificationsUnavailable => '系统下载通知未开启或不可用，下载仍在后台继续。';

  @override
  String get downloadOpenFailed => '无法打开已下载的文件。';

  @override
  String get dockerActionPending => '当前容器已有正在执行的操作';

  @override
  String get dockerNoLogs => '（无日志）';

  @override
  String get serverReboot => '重启';

  @override
  String get serverRebootDialogTitle => '确认重启服务器';

  @override
  String get serverRebootDialogMessage => '确定要重启此服务器吗？所有活跃连接及后台服务都将被终止。';

  @override
  String get serverRebootConfirmButton => '立即重启';

  @override
  String get serverRebootPasswordTitle => '需要 Sudo 密码';

  @override
  String get serverRebootPasswordMessage =>
      '重启服务器需要 Root 权限。请输入 Sudo 密码（仅本次使用，不保存）：';

  @override
  String get serverRebootPasswordHint => 'Sudo 密码';

  @override
  String get serverRebootSubmitting => '正在发送重启命令...';

  @override
  String get serverRebootAccepted => '命令已受理，尚未验证服务器完成重启。请待服务器恢复后重新连接。';

  @override
  String get serverRebootVerified => '服务器重启已验证完成，系统已恢复在线。';

  @override
  String get serverRebootUnknown => '重启结果未知。命令已发送但未确认是否成功完成，请手动检查连接。';

  @override
  String get serverRebootReconnect => '重新连接';

  @override
  String get serverRebootServerChanged => '目标服务器已变更，重启已取消';

  @override
  String get navCliChat => 'CLI 智能会话';

  @override
  String get cliChatTitle => 'CLI 智能会话';

  @override
  String get cliChatSubtitle => '远端服务器原生 CLI Agent 智能会话';

  @override
  String get cliSelectAgent => '选择 Agent';

  @override
  String get cliNoAgentsConfigured => '当前服务器未添加任何 Agent';

  @override
  String get cliAgentNeedsSetup => 'Agent 未安装或未登录';

  @override
  String get cliManageAgentsGuide => '前往 Agent 管理配置';

  @override
  String get cliNewDraft => '新建草稿';

  @override
  String get cliNewDraftTooltip => '创建空白草稿（首次发送时建立远程会话）';

  @override
  String get cliDeleteSessionTitle => '删除远端 CLI 原生会话历史';

  @override
  String get cliDeleteSessionMessage => '此操作将从远端永久删除该 CLI 会话记录，不可恢复。是否确认？';

  @override
  String get cliDeleteConfirmButton => '确认删除';

  @override
  String get cliCannotDeleteTooltip => '当前不可删除远端会话';

  @override
  String get cliSessionsHeader => '会话列表';

  @override
  String get cliNoSessions => '暂无 CLI 会话记录';

  @override
  String get cliFilterCwdHint => '按工作目录过滤...';

  @override
  String get cliFilterCwdAction => '过滤';

  @override
  String get cliClearCwdAction => '清空';

  @override
  String get cliLoadMoreSessions => '加载更多会话';

  @override
  String get cliRefreshSessions => '刷新';

  @override
  String get cliClaudeReadOnlyNotice => 'Claude 历史记录只读，可在真实终端中继续会话。';

  @override
  String get cliContinueInTerminal => '在终端中继续';

  @override
  String get cliOpenTerminal => '打开终端';

  @override
  String get cliCloseTerminal => '关闭终端';

  @override
  String get cliTerminalRunning => '交互式 CLI 终端';

  @override
  String get cliAgyTerminalOnlyNotice =>
      '此 Agent 暂不支持结构化历史同步，请使用 CLI 原生终端进行交互与会话选择。';

  @override
  String get cliInstallSdkTitle => '安装官方 Claude History SDK';

  @override
  String get cliInstallSdkMessage =>
      '远端服务器未检测到官方 Claude Code History SDK。是否确认现在安装？';

  @override
  String get cliInstallSdkAction => '确认安装官方 SDK';

  @override
  String get cliApprovalsTitle => '待处理原生审批';

  @override
  String get cliApprovalDetails => '详细参数';

  @override
  String get cliApprovalAllow => '允许';

  @override
  String get cliApprovalDecline => '拒绝';

  @override
  String get cliInputHint => '向 CLI Agent 发送指令或消息...';

  @override
  String get cliSend => '发送';

  @override
  String get cliStop => '停止';

  @override
  String get cliBusy => '操作正在进行中，请稍候...';

  @override
  String get cliDisconnected => 'SSH 未连接或已断开';

  @override
  String get cliServerChanged => '目标服务器已变更';

  @override
  String get cliTurnFailed => 'CLI 会话轮次执行失败';

  @override
  String get cliUseTerminal => '需要交互式输入，请打开终端继续';

  @override
  String get cliDeleteFailed => '删除远端会话失败';

  @override
  String get cliDeleteUnsupported => '当前 CLI 不支持删除远端会话';

  @override
  String get cliOperationFailed => 'CLI 操作执行失败';

  @override
  String get cliHistorySdkMissing => '远端服务器缺少官方历史记录 SDK';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude 历史解析需要服务器具备 Node.js/npm 环境。请手动安装 Node.js；您仍可使用终端运行真实 CLI。';

  @override
  String get cliLoginRequired => 'Agent 未登录，请前往 Agent 管理完成登录。';

  @override
  String get cliNotInstalled => 'Agent CLI 未安装，请前往 Agent 管理进行安装。';

  @override
  String get cliVersionUnsupported => '当前 Agent CLI 版本不受支持，请前往 Agent 管理升级或重装。';

  @override
  String get settingsNavigation => '导航设置';

  @override
  String get settingsNavigationDesc => '配置默认启动页与底部导航栏';

  @override
  String get settingsStartupPage => '默认启动页';

  @override
  String get settingsStartupPageDesc => '应用打开时默认展示的页面';

  @override
  String get settingsBottomNav => '底部导航栏';

  @override
  String get settingsBottomNavDesc => '选择在移动端底部导航栏展示的页面（支持 0 到 9 项）';

  @override
  String get settingsResetSuccess => '所有设置已恢复为默认值';

  @override
  String get metricsTrendSubtitle => '最近约 3 分钟（最多 60 个采样点）';

  @override
  String get metricsCurrent => '当前值';

  @override
  String get metricsPeak => '峰值';

  @override
  String get metricsValley => '谷值';

  @override
  String get metricsTrendWaiting => '正在收集采样数据...';

  @override
  String get metricsTrendStopped => '采样已停止（SSH 未连接）';

  @override
  String get dockerActionTerminal => '进入容器';

  @override
  String get dockerTerminalTitle => '容器终端';

  @override
  String get dockerTerminalNotRunning => '容器未运行，无法进入终端';

  @override
  String get setDefaultAgent => '设为默认';

  @override
  String get defaultBadge => '默认';

  @override
  String get isDefaultAgent => '默认 Agent';

  @override
  String get setAsDefaultAgent => '设为当前服务器默认 Agent';

  @override
  String get agentGroupBasic => '基本信息';

  @override
  String get agentGroupCommands => '执行命令';

  @override
  String get agentGroupAuth => '安装与登录';

  @override
  String get agentPresetTitle => '预设模板';

  @override
  String get resourceProcessList => '进程资源占用';

  @override
  String get resourceDiskScanning => '正在扫描磁盘顶层目录，可能需要几秒钟...';

  @override
  String get resourceDiskScanPartial => '部分目录因权限或超时未完全统计';

  @override
  String get resourceDiskDirectories => '顶层目录占用';

  @override
  String get resourceSortCpu => '按 CPU 排序';

  @override
  String get resourceSortMemory => '按内存排序';

  @override
  String get resourceRss => '物理常驻内存 (RSS)';

  @override
  String get resourceUsed => '已用';

  @override
  String get resourceAvailable => '可用';

  @override
  String get resourceTotal => '总量';

  @override
  String get settingsBottomNavOrderTitle => '已选项目排序（可拖动调整顺序）';

  @override
  String get langSystem => '跟随系统';

  @override
  String get serverFieldRequired => '此项必填';

  @override
  String get serverPortInvalid => '端口必须在 1 到 65535 之间';

  @override
  String get serverTestReachability => '测试连通性';

  @override
  String get serverSaveFailedGeneric => '保存服务器失败，请检查配置后重试。';

  @override
  String get serverViewPrivateKey => '查看私钥';

  @override
  String get serverHidePrivateKey => '隐藏私钥';

  @override
  String get dockerBashFallbackNotice => '容器内 Bash 不可用，已自动回退至 Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => '工作目录';

  @override
  String get cliDefaultWorkingDir => '默认 (/)';

  @override
  String get cliPickWorkingDirTitle => '选择远端工作目录';

  @override
  String get cliClearWorkingDir => '重置为默认';

  @override
  String get cliBrowseWorkingDir => '浏览';

  @override
  String get cliSelectCurrentDir => '选择当前目录';

  @override
  String get cliNavigateUp => '上一级';

  @override
  String get chatSessionsTooltip => '会话列表';

  @override
  String get hardwareSpecsTitle => '硬件与系统配置';

  @override
  String get hardwareCpu => '处理器';

  @override
  String get hardwareMemory => '物理内存';

  @override
  String get hardwareDisk => '根分区容量';

  @override
  String get hardwareDistribution => '操作系统';

  @override
  String get hardwareKernel => '内核版本';

  @override
  String get hardwareLoading => '正在加载硬件信息...';

  @override
  String get hardwareUnavailable => '硬件信息不可用';

  @override
  String get hardwareUnknown => '未知';

  @override
  String get systemInfoTitle => '系统信息';

  @override
  String get systemInfoTapHint => '点击查看字符画';

  @override
  String get systemInfoHost => '主机';

  @override
  String get serverShutdown => '关机';

  @override
  String get serverShutdownDialogTitle => '确认关闭服务器';

  @override
  String get serverShutdownDialogMessage =>
      '确定要关闭该服务器吗？服务器将彻底断电关机，在人工物理开机前将无法通过网络远程访问。';

  @override
  String get serverShutdownConfirmButton => '立即关机';

  @override
  String get serverShutdownSubmitting => '正在发送关机指令...';

  @override
  String get serverShutdownAccepted => '关机命令已受理，尚未验证关机完成。';

  @override
  String get serverShutdownUnknown => '关机结果未知：命令可能已发送但无法确认，请手动检查；不会自动重试';

  @override
  String get serverShutdownPasswordTitle => '关机需要 Sudo 密码';

  @override
  String get serverShutdownPasswordMessage =>
      '关闭服务器需要 Root 权限。请输入 Sudo 密码（仅本次使用，不保存）：';

  @override
  String get serverShutdownPasswordHint => 'Sudo 密码';

  @override
  String get serverShutdownServerChanged => '目标服务器已切换，关机已取消';

  @override
  String get metricsNetwork => '网络速率';

  @override
  String get networkModalTitle => '全网卡速率详情';

  @override
  String get networkDownloadRate => '下行速率';

  @override
  String get networkUploadRate => '上行速率';

  @override
  String get networkTotalRx => '累计接收';

  @override
  String get networkTotalTx => '累计发送';

  @override
  String get networkPrimary => '默认路由';

  @override
  String get networkRatesEmpty => '未检测到活跃的网络接口';

  @override
  String get networkWaitingSecondSample => '等待第二次采样';

  @override
  String get networkUnavailable => '不可用';

  @override
  String get networkNoDefaultInterface => '未检测到默认路由';

  @override
  String get selectThemeModeTitle => '选择外观模式';

  @override
  String get selectLanguageTitle => '选择界面语言';

  @override
  String get selectStartupPageTitle => '选择默认启动页';

  @override
  String get selectAutoConnectModeTitle => '选择自动连接模式';

  @override
  String get accentColorDialogTitle => '自定义强调色';

  @override
  String get accentColorLightMode => '浅色模式';

  @override
  String get accentColorDarkMode => '深色模式';

  @override
  String get accentColorAmoledMode => 'AMOLED (极客黑)';

  @override
  String get accentColorPresets => '预设色块';

  @override
  String get accentColorHsvPicker => '调色盘';

  @override
  String get accentColorHexCode => '十六进制色值';

  @override
  String get accentColorPreview => '实时预览';

  @override
  String get accentColorSampleButton => '按钮样例';

  @override
  String get accentColorInvalidHex => '无效的十六进制格式（如 #10B981）';

  @override
  String get settingsDashboardQuickActions => '仪表盘快捷入口';

  @override
  String get settingsDashboardQuickActionsDesc =>
      '配置在仪表盘上展示的快捷入口与顺序。清空后将完全隐藏快捷入口区。';

  @override
  String get settingsDashboardQuickActionsEmpty => '快捷入口已隐藏（未选择任何入口）';

  @override
  String get settingsDashboardQuickActionsOrderTitle => '拖拽调整快捷入口顺序';

  @override
  String get settingsDashboardQuickActionsCandidates => '勾选启用的快捷入口';

  @override
  String get terminalCopySelection => '复制';

  @override
  String get terminalSelectionCopied => '选区已复制到剪贴板';

  @override
  String get editAgent => '编辑 Agent';

  @override
  String get agentExecutionTarget => '执行位置';

  @override
  String get agentExecutionHost => '宿主机';

  @override
  String get agentExecutionDocker => 'Docker 容器';

  @override
  String get agentContainerBinding => '容器绑定方式';

  @override
  String get agentContainerBindingId => '按 ID 绑定';

  @override
  String get agentContainerBindingName => '按名称绑定';

  @override
  String get agentContainerReference => '目标容器';

  @override
  String get agentContainerReferenceHint => '选择或输入容器 ID 或名称';

  @override
  String get agentContainerRequired => 'Docker 容器执行位置必须指定目标容器';

  @override
  String get agentLoadingContainers => '正在查询服务器容器列表...';

  @override
  String get agentNoContainersFound => '当前服务器未检测到容器';

  @override
  String get agentContainerUser => '容器执行用户（可选）';

  @override
  String get agentContainerUserHint => '例如 dev';

  @override
  String get agentContainerUserHelper =>
      '留空使用镜像默认用户；例如 dev；支持 user、UID、user:group、UID:GID';

  @override
  String get agentContainerUserSelect => '选择容器用户';

  @override
  String get agentContainerUsersLoading => '正在获取容器用户...';

  @override
  String get agentContainerUsersEmpty => '无 passwd 用户';

  @override
  String get agentViewDiagnosticLog => '查看检测日志';

  @override
  String get agentDiagnosticLogCopied => '检测日志已复制到剪贴板';

  @override
  String get agentDiagnosticLogCopy => '复制';

  @override
  String get agentDiagnosticLogClose => '关闭';

  @override
  String get settingsCliHistoryPageSize => 'CLI 历史加载条数';

  @override
  String get settingsCliHistoryPageSizeDesc => '向上滑动加载更早历史消息的单页条数（5-100）';

  @override
  String get settingsCliHistoryPageSizeTitle => '选择 CLI 历史加载条数';

  @override
  String get cliLoadingOlderMessages => '正在加载更早历史消息...';

  @override
  String get chatLoadOlderMessages => '加载更早消息';

  @override
  String get chatCommandsTooltip => '命令菜单';

  @override
  String get chatAttachTooltip => '添加附件';

  @override
  String get chatAttachImage => '添加本地图片';

  @override
  String get chatAttachLocalText => '添加本地文本文件';

  @override
  String get chatAttachRemoteText => '引入远端文本文件';

  @override
  String get chatAttachRemotePathTitle => '引入远端文本文件';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => '文件超出大小上限';

  @override
  String get chatUsageAndDiagnostics => '用量与诊断';

  @override
  String get chatWorkingDirTooltip => '草稿工作目录';

  @override
  String get chatAttachFailed => '添加附件失败';

  @override
  String get chatInvalidRemotePath => '无效的远端文件路径（必须以 / 开头）';

  @override
  String get chatRemoteReadFailed => '读取远端文件失败';

  @override
  String get chatInvalidDirPath => '无效的目录路径（必须以 / 开头）';

  @override
  String get chatNoSubdirectories => '无子目录';

  @override
  String get chatUsageTitle => 'Token 与费用用量';

  @override
  String get chatUsageUsed => '已消耗 Token';

  @override
  String get chatUsageSize => '上下文容量';

  @override
  String get chatUsageCost => '费用';

  @override
  String get chatDiagnosticsTitle => '诊断脱敏日志';

  @override
  String get chatNoDiagnostics => '暂无诊断日志';

  @override
  String get deleteSessionLocalOnlyNotice =>
      '此操作仅从 Valhalla 本地移除会话记录，不会删除服务器上的 Agent 原生历史。';

  @override
  String get chatSearchSessionsHint => '搜索会话...';

  @override
  String get chatLoadMoreSessions => '加载更多会话';

  @override
  String get chatLoadingMoreSessions => '正在加载更多会话...';

  @override
  String get chatExportSession => '导出 Markdown';

  @override
  String get chatExportSuccess => '会话导出成功';

  @override
  String get chatExportFailed => '导出会话失败';

  @override
  String get chatRemoteSessions => '远端历史';

  @override
  String get chatRemoteSessionsTitle => '远端 Agent 会话';

  @override
  String get chatRemoteSessionsDesc => '查看并导入服务器上 Agent 的原生历史会话';

  @override
  String get chatRemoteSessionsEmpty => '未找到远端会话';

  @override
  String get chatRemoteImporting => '正在导入远端会话完整历史...';

  @override
  String get chatRemoteImportFailed => '导入远端会话失败';

  @override
  String get chatStatusInterrupted => '已中断';

  @override
  String get chatStatusFailed => '生成失败';

  @override
  String get chatShowFullOutput => '查看完整输出';

  @override
  String get chatShowLessOutput => '收起长输出';

  @override
  String get chatToolLocations => '关联路径';

  @override
  String cmdParamPlaceholder(String param) {
    return '请输入参数 $param 的值';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return '已向进程 $pid 发送终止信号';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return '服务 $service 执行 $action 成功';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return '触发风险规则: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return '远端退出码: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return '已成功建立与 $server 的真实 SSH 连接！';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH 连接失败: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return '首次连接到 $host ($type)\n\nSHA-256 指纹:\n$fingerprint\n\n是否信任该指纹并继续连接？';
  }

  @override
  String enterPasswordTitle(Object server) {
    return '输入 $server 登录密码';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return '确定要删除服务器 \'$name\' 吗？此操作不可撤销。';
  }

  @override
  String deleteAgentMessage(Object name) {
    return '确定要删除 Agent \'$name\' 吗？这将移除该 Agent 在当前服务器的配置和检测状态，但不会影响历史会话记录或 SSH 凭据。';
  }

  @override
  String agentLastChecked(Object time) {
    return '最近检测：$time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return '选择登录 $agent 的方式';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return '正在重连…（第 $n 次）';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n 个活跃会话';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return '确认将此会话绑定到服务器「$serverName」吗？绑定后此会话将与该服务器关联。';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return '确认删除会话「$title」吗？删除后将无法恢复。';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return '容器 $name 执行 $action 成功';
  }

  @override
  String dockerActionFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return '目标服务器：$name（$address）';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return '终端会话：$count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Agent 会话：$count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return '文件传输：$count';
  }

  @override
  String serverRebootFailed(Object error) {
    return '重启失败：$error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return '删除远端会话失败：$detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric 实时趋势';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return '预警: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return '危险: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count 个采样点';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric 当前资源占用';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP 端口 $port 可连通';
  }

  @override
  String serverConnectionFailed(Object error) {
    return '连接失败：$error';
  }

  @override
  String serverSaveFailed(Object error) {
    return '保存服务器失败：$error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores 核';
  }

  @override
  String serverShutdownFailed(Object error) {
    return '关机失败：$error';
  }

  @override
  String networkInterface(Object name) {
    return '网卡接口：$name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return '获取容器列表失败：$error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return '获取容器用户失败：$error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return '检测日志 - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Docker/容器环境检测失败';

  @override
  String get chatCopiedAllMessages => '已复制全部消息';

  @override
  String get chatCopyAllMessages => '复制全部消息';

  @override
  String get cliModelAtCapacity => '当前模型容量已满，请尝试其他模型。';

  @override
  String get chatLaunchBlankDraft => '空白草稿';

  @override
  String get chatLaunchFixedSession => '固定会话';

  @override
  String get chatLaunchRememberLast => '记住上次会话';

  @override
  String get chatPermissionAskEveryTime => '每次询问';

  @override
  String get chatPermissionAutoAllowAll => '自动允许全部操作';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Agent 将不再询问并直接执行所有操作，是否继续？';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => '确认自动允许全部操作？';

  @override
  String get chatPermissionAutoAllowSafe => '自动允许安全操作';

  @override
  String get chatRunSettingsDefault => '默认';

  @override
  String get chatRunSettingsInteractiveCli => '由交互式 CLI 管理';

  @override
  String get chatRunSettingsModel => '模型';

  @override
  String get chatRunSettingsPermissions => '操作权限';

  @override
  String get chatRunSettingsReasoning => '推理等级';

  @override
  String get chatRunSettingsTitle => '运行设置';

  @override
  String get cliActionInsertCommand => '插入命令';

  @override
  String get cliActionInsertFile => '插入文件';

  @override
  String get cliActionInsertWorkdir => '插入工作目录';

  @override
  String get cliComposerInsertAction => '插入';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI 操作执行失败：$detail';
  }

  @override
  String get cliSelectCommandTitle => '选择命令';

  @override
  String get defaultAgentTitle => '默认 Agent';

  @override
  String get insertSkills => '插入 Skills';

  @override
  String get isDefaultSession => '默认会话';

  @override
  String get sessionLaunchMode => '会话启动方式';

  @override
  String get setAsDefaultSession => '设为默认会话';

  @override
  String get navNas => 'NAS 媒体库';

  @override
  String get nasAddExcludePath => '添加排除路径';

  @override
  String get nasAddIncludePath => '添加扫描路径';

  @override
  String get nasCancelScan => '取消扫描';

  @override
  String get nasClearSearch => '清除搜索';

  @override
  String get nasConfigDialogTitle => '媒体库设置';

  @override
  String get nasConfigure => '配置';

  @override
  String get nasConfigureScanDirs => '配置扫描文件夹';

  @override
  String get nasCreatePlaylist => '新建播放列表';

  @override
  String get nasEmptyConfigDesc => '请至少添加一个文件夹以开始构建媒体库。';

  @override
  String get nasEmptyConfigTitle => '未配置扫描目录';

  @override
  String get nasExcludePaths => '排除文件夹';

  @override
  String get nasExcludedBadge => '已排除';

  @override
  String get nasFilterImages => '图片';

  @override
  String get nasFilterVideos => '视频';

  @override
  String get nasIncludePaths => '扫描文件夹';

  @override
  String nasItemCount(Object value) {
    return '$value 项';
  }

  @override
  String nasLastScan(Object value) {
    return '上次扫描：$value';
  }

  @override
  String get nasLibrarySettings => '媒体库设置';

  @override
  String nasMediaOpening(Object value) {
    return '正在打开 $value…';
  }

  @override
  String get nasMiniPlayer => '迷你播放器';

  @override
  String get nasNoExcludePaths => '没有排除文件夹';

  @override
  String get nasNoFavorites => '暂无收藏';

  @override
  String get nasNoIncludePaths => '没有扫描文件夹';

  @override
  String get nasNoIndexDesc => '请配置文件夹并执行扫描以建立媒体索引。';

  @override
  String get nasNoIndexTitle => '媒体库暂无索引';

  @override
  String get nasNoPlaylists => '暂无播放列表';

  @override
  String get nasNoSearchResults => '没有匹配的媒体';

  @override
  String get nasNotScanned => '尚未扫描';

  @override
  String get nasNowPlaying => '正在播放';

  @override
  String get nasOpenMethodPrompt => '请选择打开此文件的方式';

  @override
  String get nasOpenPolicyAsk => '每次询问';

  @override
  String get nasOpenPolicyExternal => '使用其他应用打开';

  @override
  String get nasOpenPolicyInApp => '在应用内打开';

  @override
  String get nasOpeningPolicy => '默认打开方式';

  @override
  String get nasPlaylistName => '播放列表名称';

  @override
  String get nasQuickStats => '媒体库概览';

  @override
  String get nasScan => '立即扫描';

  @override
  String get nasScanCancelled => '扫描已取消';

  @override
  String nasScanFailed(Object value) {
    return '扫描失败：$value';
  }

  @override
  String get nasScanning => '正在扫描…';

  @override
  String get nasScopeBadge => '扫描范围';

  @override
  String get nasSearchHint => '搜索媒体';

  @override
  String get nasStatMusic => '音频数';

  @override
  String get nasStatPhotos => '照片数';

  @override
  String get nasStatTotal => '总计';

  @override
  String get nasStatVideos => '视频数';

  @override
  String get nasTabFavorites => '收藏';

  @override
  String get nasTabFolders => '文件夹';

  @override
  String get nasTabHome => '首页';

  @override
  String get nasTabMusic => '音乐';

  @override
  String get nasTabPhotos => '图片';

  @override
  String get nasTabPlaylists => '播放列表';

  @override
  String get nasTabVideos => '视频';

  @override
  String get nasSources => '媒体源';

  @override
  String get nasAddSource => '添加媒体源';

  @override
  String get nasEditSource => '编辑媒体源';

  @override
  String get nasRemoveSource => '移除媒体源';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return '确定要移除媒体源“$name”吗？此操作不会删除远端文件。';
  }

  @override
  String get nasNoSources => '未配置媒体源';

  @override
  String get nasNoSourcesDesc =>
      '添加 SFTP、SMB、WebDAV、Jellyfin 或 Emby 媒体源开始浏览媒体库。';

  @override
  String get nasSourceType => '源类型';

  @override
  String get nasSourceName => '源名称';

  @override
  String get nasProbe => '测试连接';

  @override
  String get nasProbeSuccess => '连接成功';

  @override
  String get nasProbeFailed => '连接测试失败';

  @override
  String get nasEndpoint => '服务地址 / URL';

  @override
  String get nasRootPath => '根路径';

  @override
  String get nasUsername => '用户名';

  @override
  String get nasPassword => '密码';

  @override
  String get nasDomain => '域名（可选）';

  @override
  String get nasAuthenticate => '登录认证';

  @override
  String get nasAuthSuccess => '认证成功';

  @override
  String get nasAuthFailed => '认证失败';

  @override
  String get nasTabDownloads => '下载';

  @override
  String get nasNoDownloads => '暂无下载任务';

  @override
  String get nasDownloadQueued => '排队中';

  @override
  String get nasDownloadDownloading => '下载中';

  @override
  String get nasDownloadCompleted => '已完成';

  @override
  String get nasDownloadCancelled => '已取消';

  @override
  String get nasDownloadFailed => '下载失败';

  @override
  String get nasRetryDownload => '重试';

  @override
  String get nasCancelDownload => '取消';

  @override
  String get nasOpenDownloadedFile => '打开文件';

  @override
  String get nasQueue => '播放队列';

  @override
  String get nasNoQueue => '播放队列为空';

  @override
  String get nasSpeed => '倍速';

  @override
  String get nasQuality => '画质';

  @override
  String get nasAudioTrack => '音轨';

  @override
  String get nasSubtitleTrack => '字幕';

  @override
  String get nasRepeatOff => '不循环';

  @override
  String get nasRepeatAll => '列表循环';

  @override
  String get nasRepeatOne => '单曲循环';

  @override
  String get nasShuffle => '随机播放';

  @override
  String get nasCast => '投屏';

  @override
  String get nasCastUnavailable => '未发现可投屏设备';

  @override
  String get nasSlideshow => '幻灯片';

  @override
  String get nasByFolder => '文件夹';

  @override
  String get nasByArtist => '艺术家';

  @override
  String get nasByAlbum => '专辑';

  @override
  String get nasAllTracks => '全部曲目';

  @override
  String get nasPlayAll => '播放全部';

  @override
  String get nasPreviousPage => '上一页';

  @override
  String get nasNextPage => '下一页';

  @override
  String get nasClearScope => '返回全部';

  @override
  String get nasRenamePlaylist => '重命名播放列表';

  @override
  String get nasRemoveFromPlaylist => '从播放列表中移除';

  @override
  String get nasMoveUp => '上移';

  @override
  String get nasMoveDown => '下移';

  @override
  String get nasSshServer => 'SSH 服务器';

  @override
  String get nasSelectSshServer => '选择已保存的 SSH 服务器';

  @override
  String get nasQualityOriginal => '原画';

  @override
  String get nasQualityAuto => '自动';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => '可用 DLNA 设备';

  @override
  String get nasCastDiscovering => '正在搜索 DLNA 设备...';

  @override
  String get nasCastRelayingNotice => '正在通过前台应用中继流媒体，请保持应用处于前台。';

  @override
  String get nasCastStop => '停止投屏';

  @override
  String get nasCastVolume => '音量';

  @override
  String get nasCastRetry => '重试搜索';

  @override
  String get nasInstallTitle => '部署 NAS 媒体服务';

  @override
  String get nasInstallProduct => '服务产品';

  @override
  String get nasInstallMediaPath => '媒体目录（只读挂载）';

  @override
  String get nasInstallDataRoot => '数据与配置目录';

  @override
  String get nasInstallPort => '端口';

  @override
  String get nasInstallBindAddress => '绑定监听地址';

  @override
  String get nasInstallWebdavUser => 'WebDAV 用户名';

  @override
  String get nasInstallWebdavPassword => 'WebDAV 密码（至少12位）';

  @override
  String get nasInstallPreparePlan => '生成并审核部署方案';

  @override
  String get nasInstallPlanTitle => '技术方案审核与确认';

  @override
  String get nasInstallBlockersTitle => '阻碍部署的问题';

  @override
  String get nasInstallConfirmDeploy => '确认并开始部署';

  @override
  String get nasInstallDeploying => '正在部署容器...';

  @override
  String get nasInstallSuccess => '部署成功';

  @override
  String get nasInstallSuccessDesc =>
      '服务已成功启动运行。在将其添加为媒体源之前，请先在浏览器中完成初始向导与账号创建。';

  @override
  String get nasInstallContainerId => '容器 ID';

  @override
  String get nasInstallEndpoint => '访问地址';

  @override
  String get nasUseSshTunnel => '使用 SSH 隧道';

  @override
  String get nasUseSshTunnelDesc =>
      '通过已保存的 SSH 服务器转发内网服务（如 http://127.0.0.1:8096）';

  @override
  String get nasSshTunnelHint => '地址需为 SSH 服务器侧可访问地址，如 http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword => '留空则保留现有密码或 Token';

  @override
  String get nasSourceNameRequired => '请输入源名称';

  @override
  String get nasInvalidEndpoint => '无效的端点地址或协议';

  @override
  String get nasSourceUnreachable => '无法连接媒体源';

  @override
  String get nasSshTunnelFailed => 'SSH 隧道连接失败';

  @override
  String get nasOperationFailed => '操作失败';

  @override
  String get nasInstallStepCreateDir => '创建私有隔离目录';

  @override
  String get nasInstallStepWriteCompose => '生成 docker-compose.json 配置';

  @override
  String get nasInstallStepWriteCreds => '安全写入私有认证凭据';

  @override
  String get nasInstallStepPullImage => '拉取校验的指定容器镜像';

  @override
  String get nasInstallStepStartService => '启动 Compose 容器服务';

  @override
  String get nasInstallStepCheckHttp => '验证服务 HTTP 健康状态';

  @override
  String get nasInstallBlockerDocker => '目标服务器需安装 Docker Engine';

  @override
  String get nasInstallBlockerCompose => '目标服务器需安装 Docker Compose 插件';

  @override
  String get nasInstallBlockerIdentity => '无法验证目标服务器机器身份';

  @override
  String get nasInstallBlockerTools => '目标服务器缺少必要工具 (curl, ss, realpath)';

  @override
  String get nasInstallBlockerMedia => '媒体目录不存在或无读取权限';

  @override
  String get nasInstallBlockerParent => '数据根目录的父目录无写入权限';

  @override
  String get nasInstallBlockerOverlap => '媒体目录与数据目录不能重叠';

  @override
  String get nasInstallBlockerCollision => '目标数据目录已存在或为软链接';

  @override
  String get nasInstallBlockerPort => '指定端口已被目标服务器上的服务占用';

  @override
  String get nasInstallBlockerContainer => '同名容器项目已存在';

  @override
  String get nasInstallBlockerImage => '镜像验证失败，请检查镜像名称、网络连接和服务器架构后重试。';

  @override
  String get nasInstallGuidanceTunnel => '绑定 127.0.0.1 需通过 SSH 隧道访问';

  @override
  String get nasInstallGuidanceTls => '公开网络绑定建议前置 TLS 反向代理';

  @override
  String get nasInstallGuidanceSetup => '初次启动请在浏览器中完成管理员账号初始化';

  @override
  String get nasInstallGuidanceReadOnly => '媒体目录以只读方式挂载，确保数据安全';

  @override
  String get nasInstallGuidancePreserved => '部署失败将保留数据目录以便排查';

  @override
  String get nasDownloadCompletedWithOpenError => '已下载（外部应用打开失败）';

  @override
  String get nasRetryOpen => '重试打开';

  @override
  String get nasExternalOpenFailed => '无法在外部应用中打开文件';

  @override
  String get nasTitle => 'NAS 媒体中心';

  @override
  String get nasLoadMoreGroups => '加载更多分组';

  @override
  String get nasMetadataEnriching => '正在解析音乐标签...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return '正在解析音乐标签（已处理 $count 首）...';
  }

  @override
  String nasDownloading(String value) {
    return '正在下载 $value…';
  }

  @override
  String get nasSubtitleNone => '无';

  @override
  String get nasLibraryId => '媒体库 ID';

  @override
  String get nasLibraryIdHint => '默认全库（/），或输入指定库 ID';

  @override
  String nasScanPathRelativeHint(String value) {
    return '相对于源根目录（$value）';
  }

  @override
  String get nasSourceChangedError => '源已切换，已取消保存';

  @override
  String get nasInvalidLibraryId => '媒体库 ID 无效';

  @override
  String get startupFailed => '应用启动失败';

  @override
  String get startupFailedDesc => '启动过程中发生异常。您可以重试启动或导出诊断日志。';

  @override
  String get retryStartup => '重试启动';

  @override
  String get viewDiagnostics => '查看诊断日志';

  @override
  String get exportDiagnostics => '导出诊断日志';

  @override
  String diagnosticsExportSuccess(String path) {
    return '诊断日志已导出至 $path';
  }

  @override
  String get diagnosticsExportFailed => '导出诊断日志失败';

  @override
  String get diagnosticsTitle => '应用诊断';

  @override
  String get settingsDiagnostics => '诊断与日志';

  @override
  String get settingsDiagnosticsDesc => '查看并导出本地脱敏应用日志';

  @override
  String get diagnosticsEmpty => '暂无诊断记录';

  @override
  String diagnosticsStorageError(String error) {
    return '诊断日志存储异常：$error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return '系统已记录异常事件：$category';
  }

  @override
  String get diagnosticsRefresh => '刷新日志';

  @override
  String get nasInstallTaskTitle => '部署任务';

  @override
  String get nasInstallStagePreflight => '前置检查';

  @override
  String get nasInstallStageReview => '方案审查';

  @override
  String get nasInstallStageWriting => '写入配置';

  @override
  String get nasInstallStagePulling => '拉取镜像';

  @override
  String get nasInstallStageStarting => '启动容器';

  @override
  String get nasInstallStageHealth => '健康检查';

  @override
  String get nasInstallStageCleanup => '清理残留';

  @override
  String get nasInstallStageSucceeded => '部署成功';

  @override
  String get nasInstallStageFailed => '部署失败';

  @override
  String get nasInstallStageCancelled => '部署已取消';

  @override
  String get nasInstallStageNeedsInspection => '需要人工复检';

  @override
  String get nasInstallStageReconciling => '对齐状态中';

  @override
  String get nasInstallCancel => '取消部署';

  @override
  String get nasInstallReconcile => '复检对齐状态';

  @override
  String get nasInstallServerNotFound => '选中的服务器不存在';

  @override
  String get nasInstallPortRangeError => '端口范围必须为 1 至 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return '已耗时：$time';
  }

  @override
  String get nasInstallLogTail => '最近日志';

  @override
  String get nasInstallCleanupCompleted => '回滚清理已完成';

  @override
  String get nasInstallCleanupIncomplete => '回滚清理未完全完成';

  @override
  String get nasInstallNewDeployment => '新建部署';

  @override
  String get nasInstallBackEdit => '返回 / 修改配置';

  @override
  String get nasInstallClose => '关闭';

  @override
  String get nasInstallMediaPathHint => '主机上只读挂载路径（例如 /mnt/media）';

  @override
  String get nasInstallDataRootHint => '私有数据与配置目录（不能已存在）';

  @override
  String get nasInstallBindAddressHint => '127.0.0.1 配合隧道，0.0.0.0 用于局域网';

  @override
  String get nasInstallWebdavPasswordHint => '至少需要 12 个字符';

  @override
  String get nasInstallTargetServer => '目标服务器';

  @override
  String get nasInstallTargetImage => '目标镜像';

  @override
  String get nasInstallContainerName => '容器名称';

  @override
  String get nasInstallBindAndPort => '绑定地址与端口';

  @override
  String get nasInstallComposePreview => 'docker-compose.json 预览';

  @override
  String get nasInstallPlannedSteps => '计划执行步骤';

  @override
  String get nasInstallGuidanceNotes => '部署说明与建议';

  @override
  String get nasInstallNoLogsYet => '暂无日志';

  @override
  String get sftpPreviewTooLarge => '文件大小超过 1 MiB 预览上限，请下载后使用外部应用打开。';

  @override
  String get sftpSaveFailed => '保存文件失败，请检查写入权限或网络连接。';

  @override
  String get sftpSaving => '正在保存...';

  @override
  String get nasInstallBlockerConnectionChanged => '目标服务器连接配置已变更，继续前请检查远端状态';

  @override
  String get nasInstallBlockerCancelled => '部署已由用户取消。请检查配置并在需要时重试。';

  @override
  String get nasInstallBlockerInspectFailed => '核验远程容器失败。请检查服务器网络连接或手动排查。';

  @override
  String get nasInstallBlockerDeadlineExceeded => '部署步骤超时。请检查服务器负载或网络连接后重试。';

  @override
  String get nasInstallBlockerInterrupted => '部署已中断；继续前请检查远程状态。';

  @override
  String get nasInstallBlockerHealthTimeout =>
      '服务已启动但 HTTP 健康检查超时。请查看服务日志或确认端口可用性。';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      '状态对账失败。请手动检查远程容器状态或重新部署。';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      '远程容器状态不明确。需要手动检查并执行状态对账。';

  @override
  String get nasInstallBlockerServiceExited => '容器进程意外退出。请查看日志排查配置或权限问题。';

  @override
  String get nasInstallBlockerWriteFailed => '在目标服务器写入部署文件失败。请检查磁盘空间与目录权限。';

  @override
  String get nasInstallBlockerPlanStale => '部署方案已过期。请重新执行预检。';

  @override
  String get nasInstallBlockerOwnershipChanged => '现有容器非本应用创建。请手动检查以防止覆盖其他服务。';

  @override
  String get nasInstallBlockerSshRequired => '需要先建立与目标服务器的 SSH 连接。';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      '远程状态与本地不一致。请先执行状态对账后再继续。';

  @override
  String get nasInstallBlockerFailed => '部署过程中发生错误。请查看日志并重试。';

  @override
  String get nasInstallBlockerBusy => '已有安装任务正在运行，请查看当前任务进度。';

  @override
  String get nasInstallBlockerStateSaveFailed => '保存部署状态失败，请检查本机存储空间与文件读写权限。';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      '远端执行结果未知，请进行只读核验，切勿直接重试安装。';

  @override
  String get nasInstallBlockerPreflightFailed => '部署前环境预检失败，请先排除阻断项后再继续。';

  @override
  String serverDeleteFailed(String error) {
    return '删除服务器失败：$error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Agent 模式';

  @override
  String get chatRunSettingsApprovalPolicy => '本地审批策略';

  @override
  String get chatRunSettingsExtraSettings => '附加设置';

  @override
  String get chatPermissionAutoAllowSafeDesc => '自动放行已知安全操作；无法确定操作安全性时仍会提示确认。';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return '应用运行配置失败：$error';
  }

  @override
  String get chatMessageCopied => '消息已复制到剪贴板';

  @override
  String get copy => '复制';

  @override
  String get rename => '重命名';

  @override
  String get refresh => '刷新';

  @override
  String get sessionTitle => '会话标题';

  @override
  String get chatSettingsStale => '已过期';

  @override
  String get chatSettingsAvailableAfterFirstMessage => '首次发送后可用';

  @override
  String get chatReimportAsCopy => '重新导入为副本';

  @override
  String get chatSearchCommandsHint => '搜索命令或技能...';

  @override
  String get chatCommandsTab => '命令';

  @override
  String get chatSkillsTab => '技能';

  @override
  String get chatAccountAndQuotaTitle => '账号与额度';

  @override
  String get chatAccountSectionTitle => '账号信息';

  @override
  String get chatAccountNotProvided => '未上报账号详情';

  @override
  String get chatAccountKind => '类型';

  @override
  String get chatAccountLabel => '标识';

  @override
  String get chatAccountPlan => '订阅计划';

  @override
  String get chatAccountEmail => '邮箱';

  @override
  String get chatAccountUpdatedAt => '更新时间';

  @override
  String get chatQuotaSectionTitle => '额度与状态';

  @override
  String get chatStatusSourceNote => 'Agent /status 原文';

  @override
  String get chatStatusNotQueried => '尚未查询 /status 状态';

  @override
  String get chatQueryStatusAction => '查询状态 (/status)';

  @override
  String get chatQueryStatusUnavailable => '当前会话无法查询状态';

  @override
  String get chatAttachmentMissing => '附件文件缺失或无法读取';

  @override
  String get chatViewModeList => '列表';

  @override
  String get chatViewModeCards => '卡片';

  @override
  String get chatViewModeGrid => '图库';

  @override
  String get chatRemoteBrowserTitle => '远端工作区';

  @override
  String get chatSelectDirectory => '选择目录';

  @override
  String chatAttachSelectedFiles(int count) {
    return '添加所选 ($count)';
  }

  @override
  String get chatNoFilesFound => '未找到文件';

  @override
  String get chatRootDirectory => '根目录';

  @override
  String get chatSelectThisDirectory => '使用此目录';

  @override
  String get chatAgentVersion => 'Agent 版本';

  @override
  String get chatParentDirectory => '上一级目录';

  @override
  String get chatSearchFilesHint => '搜索文件...';

  @override
  String get chatCommandsEmpty => '当前 Agent 未提供斜杠命令';

  @override
  String get chatSkillsEmpty => '当前 Agent 未提供技能';

  @override
  String get chatFileUnsupported => '不支持此类型文件作为附件';

  @override
  String get chatStatusNotProvided => '当前 Agent 未提供状态查询';

  @override
  String get sessionRecoveryReconnecting => '重连中...';

  @override
  String get sessionRecoverySyncing => '同步输出...';

  @override
  String get sessionRecoveryIncomplete => '部分输出无法恢复';

  @override
  String get sessionRecoveryFailed => '恢复失败';

  @override
  String get sessionRecoveryRetry => '重试';

  @override
  String get dashboardUpdatesPaused => '数据暂停更新';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      '当前 CLI 模型目录不可用。模型可能受缓存或 CLI 版本限制，您也可以选择手动输入模型名称。';

  @override
  String get chatSettingsModelCatalogNote =>
      '模型列表通过现有 CLI 登录向 app-server 查询，可能存在缓存或受版本限制；您可以手动刷新或切换至手动输入。';

  @override
  String get chatModelCatalogError403 =>
      'CLI模型查询被拒绝(403)。请检查CLI登录和服务连通性，或手动输入模型名。';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return '模型目录异常：$error';
  }

  @override
  String get chatModelAuthorizeButton => '授权独立模型目录';

  @override
  String get chatModelAuthorizeConfirmTitle => '确认独立模型授权';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      '将在目标主机/容器上发起模型目录的浏览器授权流程。您既有的 Codex 登录和终端会话将保持完全不变。是否继续？';

  @override
  String get chatModelAuthorizing => '正在通过浏览器授权...';

  @override
  String get chatModelAuthorizeCancel => '取消授权';

  @override
  String get chatCommandsFirstTurnNote =>
      '斜杠命令将在会话初始化后由 Agent 运行时发布，无需先完成普通对话；草稿不会自动创建会话。';

  @override
  String get chatCommandsClientActionRunSettings => '运行设置';

  @override
  String get chatCommandsClientActionWorkingDirectory => '工作目录';

  @override
  String get chatCommandsClientActionsSection => '本地快捷操作';

  @override
  String get chatRunSettingsModelSourceCatalog => '模型列表';

  @override
  String get chatRunSettingsModelSourceCustom => '手动输入';

  @override
  String get chatRunSettingsCustomModelHint => '输入模型ID';

  @override
  String get chatRunSettingsCustomModelNotice =>
      '手动输入的模型名称未经验证，将直接传给 Agent 运行时，若不受支持可能会被拒绝。';

  @override
  String get chatRunSettingsCustomModelEmptyError => '模型名称不能为空';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      '模型名称不能包含空格或控制字符，且长度不能超过 256 字符';

  @override
  String get chatCommandsDraftPreviewNotice =>
      '当前适配器版本验证的兼容命令预览。选择仅将命令插入输入框，发送时将按需初始化会话并直接执行。';

  @override
  String get chatCommandsDiscoveryFailed => '获取命令与技能失败';
}
