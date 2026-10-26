# ACP 工作台与 SSH 历史恢复

本轮已交付 **1.0.19+20**。构建源码 `3fbe7da6e8a0a9d43ab95ed1e9622b5add27ec6b`；最终渠道、哈希和验收边界见 [发布回执](2026-10-26-v1019-release.md)。后续文档提交不改变二进制来源。

## 职责与范围

UI/ARB 全部由 AgY 原 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`、`gemini-3.8-flash-high` / high 修改。主代理负责 core/data/infrastructure、文档和发布登记。OpenCode 免费模型执行早期验证，额度耗尽后按用户授权切换已核验免费的 CodeBuddy `hy3` / `deepseek-v4.1-flash`；最终生成、格式、分析、测试、正式构建和既有发布脚本由 CodeBuddy 执行。没有主代理直接代跑应用测试或构建。

## 已完成行为

- 冷重进先选择当前服务器已配置 Agent 并加载本地历史，不等待 SSH 检测就绪。远端传输版本与本地消息读取版本分离；保留活动选择、消息分页与上滑阅读位置，不以不透明度隐藏已加载消息。
- Markdown 网址、邮件和远端文件点击有反馈。文件相对路径按捕获的工作目录解析，工作目录外路径需确认；不把远端路径当手机本地文件，不复用 OAuth 登录通道。
- 工作台复用现有 ACP 页面、默认 Agent/会话偏好与单服务器运行任务契约。按服务器、创建时的执行环境和规范化工作目录分组，支持别名、收藏及文件/任务/上下文面板；手机按需打开，桌面侧栏复用相同组件。
- 项目抽屉仅比较分组元数据，不因每个流式 token 重建。文件面板捕获选择身份，目标改变丢弃迟到结果；恢复连接时保留缓存并刷新。
- 文件支持有界预览、引用和文本编辑。真实差异先展示再确认保存；冲突、断网或环境改变保留输入草稿。保存确认中的差异按行惰性构建并明确约束视口尺寸。
- 用户确认后可打开远端 HTTP localhost 网页。仅本机 loopback 监听；Docker 只读取已有发布端口，不修改 Docker 网络，不绕过 HTTPS 校验。
- SSH 历史初始状态为空、unknown、unavailable 时先刷新；按 socket 与进程身份校验恢复。查询或附加失败保留原页签与脱敏诊断，重试同一身份，不创建替代 Shell 或重复页签。关闭错误通知同步更新缓存，避免切页后重现。

## 核心契约

- `ChatWorkspace.group`：server + execution snapshot + normalized directory 分组。`ChatSession.executionKey`、`AgentChatContext.executionKey` 为兼容性附加字段；旧值缺失保留 legacy 标记，不从被编辑的 Agent 配置推测原环境。
- 执行环境快照不随 CLI 升级改变；容器/用户变化后已知不匹配的旧上下文可读，但继续执行或文件访问会拒绝并提示新建会话。共享会话按各参与 Agent 的快照校验。
- `ChatLinkTarget.parse`：区分 web/mail/remoteFile/anchor/unsupported，解析路径行号与工作目录外标记；拒绝不支持的 URI scheme 和控制字符。
- `workspaceSelectionKey` 包含服务器连接身份、Agent 启动身份、会话/草稿和有效工作目录；只在内存使用。预览、保存和转发均校验捕获目标，不以 `executionKey` 替代它。
- `readWorkspaceText` / `saveWorkspaceText`：1 MiB、严格 UTF-8，校验快照 owner、路径/符号链接目标、摘要与元数据；同目录临时文件原子替换并保留权限。宿主机复用现有 SFTP 编辑，容器以配置用户运行 Python3，内容走 stdin。缺工具时只读，不回退宿主机。
- `readWorkspaceImage` 有界读取；`openWorkspaceWebPreview` 仅支持确认后的 HTTP loopback 转发，Docker 无发布端口时明确报不支持。
- `SshTerminalState.errorDetail` / `socketErrorDetails` 保存脱敏、截断详情，可查看复制；`clearNotice` 同时清当前状态和工作区缓存。

## 最终证明与边界

最终 `build/workbench-validation/verified-20261026T085435Z/`：生成、格式、全项目分析、32 文件 422 项常规 Flutter 测试、34 项 Python Broker、diff-check 均退出 0，分析零问题、无失败/跳过。发布脚本另有 537 项终端相关回归通过，与前述集合重叠，不相加。中途失败日志保留，最终测试未弱化保存、冲突或服务器隔离断言。

没有 ADB 安装或真实 SSH/Agent 对话验收；服务端恢复失败的具体根因尚未通过实服诊断证明。文本保存最终校验与重命名之间仍可能与不配合的外部写入者竞争，完全消除此窗口需要服务端协作锁。Windows/Apple 未构建，不启动 Actions，不修改正在运行的 Codex 会话或生产 tmux。
