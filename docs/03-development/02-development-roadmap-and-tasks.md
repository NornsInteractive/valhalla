# Valhalla - 敏捷路线图、里程碑与详细任务清单 (Tasklist)

## 当前迭代：2026-10-11 九项完整性完善

本轮已获实现授权，范围和所有权以
[完成契约](../../agent-workflow/2026-10-11-completion.md)为准。包括重连与
冷启动缓存、全局键盘意图、共享终端快捷栏与滚动保持、ACP 回归、安全
文件编辑、持久化续传、系统服务与进程安全、NAS 性能／缓存／播放恢复、
GitHub 更新。追加隐藏文件视觉弱化及持久化文件视图切换。

- [x] 文件显示追加项由 AgY 实现，29 项文件界面测试通过。
- [x] 终端滚动保持和 IME 意图专项 14 项通过。
- [ ] 共享终端修饰键／粘贴身份收尾及桌面／大字体验收。
- [ ] 更新入口、编辑器退出／冲突、服务日志、NAS 缓存／播放器消费者 UI。
- [ ] 业务新增完整性与竞态保护专项回归、ACP／恢复检查及 NAS 性能实测。
- [ ] 完整生成／分析／全量测试、当前源码本地构建和保留数据 ADB 安装。
- [ ] 文档用本轮最终证据更新，不沿用旧版本通过数字。

本轮不包含推送、Release 覆盖或收费云端构建。以下 MVP 清单是早期规划，
不是当前完成度的实时来源。

| 文档版本 | 发布日期 | 迭代周期 | 目标里程碑 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 敏捷两周 Sprint 驱动 | MVP (第一阶段) 完整可用链路交付 |

---

## 1. 总体里程碑规划 (Roadmap)

```text
2026 Q3 (MVP 第一阶段)
├── M1: 工程基建与数据持久化 (Scaffolding & Storage)
├── M2: SSH 连接池与安全凭证 (SSH & Security)
├── M3: SSH Terminal 终端核心 (xterm & Accessory Bar)
├── M4: SFTP 文件系统与代码编辑 (Files & Editor)
├── M5: AI Agent 核心会话链路 (ACP Protocol & Chat UI)
├── M6: Docker 容器与快捷命令 (Docker & Commands)
└── M7: Dashboard 监控与响应式双端适配 (Dashboard & Release)

2026 Q4 (第二阶段)
└── Docker Compose, 进程/系统服务管理, Codex/OpenCode 深度集成

2027+ (第三/四阶段)
└── 多服务器集群编排, 端口转发隧道, Agent 插件市场, Web 支持
```

---

## 2. MVP (第一阶段) 详细任务清单与验收标准

### 里程碑 1：工程基建与持久化 (Sprint 1)
- [ ] **Task 1.1 项目脚手架搭建**
  - 执行 `flutter create --org com.antigravity.valhalla --platforms=android,windows,linux,macos,ios valhalla`
  - 配置 `.gitignore`, `analysis_options.yaml` (严格模式)。
  - *验收标准*：各端项目骨架无警告构建通过。
- [ ] **Task 1.2 核心依赖配置与验证**
  - 配置 `pubspec.yaml` 引入 Riverpod, go_router, dartssh2, acpd, xterm, drift, flutter_secure_storage 等包。
  - *验收标准*：`flutter pub get` 解析零冲突。
- [ ] **Task 1.3 本地 Drift SQLite 数据库搭建**
  - 编写 `ServerTable`, `KnownHostKeyTable`, `QuickCommandTable`, `SessionCacheTable`。
  - 配置 `drift_flutter` 并运行代码生成器 (`build_runner`)。
  - *验收标准*：数据库能执行插入、批量查询、外键级联删除。
- [ ] **Task 1.4 安全凭证存储封装**
  - 封装 `SecureStorageService`，实现密码与私钥加解密隔离存取。
- [ ] **Task 1.5 响应式路由与 Material 3 主题**
  - 使用 `go_router` 搭建基础骨架（含 `ShellRoute` 动态切换）；
  - 定义深色、浅色及 AMOLED 主题样式。

### 里程碑 2：SSH 连接管理与安全 (Sprint 2)
- [ ] **Task 2.1 服务器配置 CRUD 界面**
  - 服务器列表页、添加/编辑服务器表单（输入主机、端口、用户名、选择私钥文件）。
- [ ] **Task 2.2 SSHClient 连接器封装**
  - 封装 `SSHManager`：支持密码与私钥认证，集成 KeepAlive 心跳保活与超时控制。
- [ ] **Task 2.3 Host Key 验签与防中间人机制**
  - 首次连接弹出指纹 SHA256 确认弹窗；指纹存入 SQLite；变更时强制阻断连接。
- [ ] **Task 2.4 Login Shell 包装器与环境变量自适应**
  - 封装统一命令执行器：`bash -l -c "$cmd"`，并在初次连接时自动探测并注入用户的真实 PATH。

### 里程碑 3：SSH Terminal 终端核心 (Sprint 3)
- [ ] **Task 3.1 xterm.dart 终端集成**
  - 将 `TerminalView` 嵌入页面，配置终端配色方案、字体大小与滚动缓存。
- [ ] **Task 3.2 PTY Shell 双向字节流绑定**
  - 绑定 `dartssh2` 的 PTY Shell 与 `Terminal` 输入输出流，支持窗口 Resize 自适应。
- [ ] **Task 3.3 移动端辅助按键栏 (Accessory Keyboard Bar)**
  - 实现悬浮辅助工具条，包含 `Ctrl`, `Alt`, `Esc`, `Tab`, `↑`, `↓`, `←`, `→` 键及剪贴板粘贴功能。
- [ ] **Task 3.4 多 Terminal 会话 Tab 切换**
  - 支持在一个服务器下同时打开多个独立终端 Tab，支持关闭与新建。

### 里程碑 4：SFTP 文件系统与代码编辑 (Sprint 4)
- [ ] **Task 4.1 目录与文件列表浏览**
  - 基于 `dartssh2.sftp()` 浏览远端目录，支持进入子目录、返回上级、路径输入跳转。
- [ ] **Task 4.2 文件基础操作 (CRUD)**
  - 新建文件/文件夹、重命名、删除、权限查看。
- [ ] **Task 4.3 文件上传与下载进度流**
  - 集成 `file_picker`，实现分块流式上传与下载，实时展示进度条与取消操作。
- [ ] **Task 4.4 内置代码查看与编辑器**
  - 嵌入基于 `syntax_highlight` 的轻量文本编辑器，支持常见配置文件保存回写。

### 里程碑 5：AI Agent 核心会话链路 (Sprint 5 - 核心重点)
- [ ] **Task 5.1 ACP over SSH 管道桥接**
  - 封装 `ACPClientAdapter`，通过 SSH Channel 执行 `claude-code-acp` 并绑定标准 JSON-RPC 消息流。
- [ ] **Task 5.2 Session 全生命周期管理**
  - 接入 ACP 标准：`initialize`, `session/new`, `session/list`, `session/resume`, `session/close`。
- [ ] **Task 5.3 交互式聊天界面与 Markdown 流式渲染**
  - 接入 `flutter_markdown_plus`，实时渲染用户提问与 Agent 流式输出、Thinking 思考块、Plan 执行计划。
- [ ] **Task 5.4 Tool Call 卡片状态可视化**
  - 渲染工具调用过程卡片（Pending, Running, Completed, Failed），支持折叠/展开命令与输出。
- [ ] **Task 5.5 标准权限审批弹窗**
  - 捕获 Agent 抛出的 `permission/request` 请求，呈现参数细节，提供【拒绝】、【允许一次】、【始终允许】回调。

### 里程碑 6：Docker 基础管理与快捷命令 (Sprint 6)
- [ ] **Task 6.1 Docker 容器列表与状态控制**
  - 远程执行 `docker ps -a --format '{{json .}}'` 并解析渲染；
  - 提供容器启动、停止、重启、删除操作。
- [ ] **Task 6.2 容器日志流与终端直通**
  - 接入 `docker logs -f` 实时日志查看器；
  - 接入 `docker exec -it <id> sh` 终端交互。
- [ ] **Task 6.3 快捷命令管理与模版替换**
  - 快捷命令列表、分类、增删改查；
  - 解析 `{{param}}` 动态弹窗输入并拼接命令。
- [ ] **Task 6.4 危险命令拦截与 Sudo 支持**
  - 对高危指令实施红色二级警示确认；
  - 支持 `sudo -S` 安全密码输入与 PTY 交互提权。

### 里程碑 7：Dashboard 监控与双端响应式适配 (Sprint 7)
- [ ] **Task 7.1 系统硬件指标自适应流式采样**
  - 实现生命周期感知的轻量监控流（CPU/内存/磁盘），进入页面激活，离开页面即停。
- [ ] **Task 7.2 双端交互适配打磨**
  - 桌面端（NavigationRail + Inspector 侧边栏）与移动端（NavigationBar + BottomSheet）完整联调。
- [ ] **Task 7.3 端到端验收与第一阶段封版**
  - 全链路测试（测试用例 TC-01 ~ TC-25 全部通过），输出 MVP Release 安装包。
