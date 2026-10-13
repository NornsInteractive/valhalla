# Valhalla - 敏捷路线图、里程碑与详细任务清单 (Tasklist)

## 当前新迭代：选择性卸载、NAS 分类与双路径部署

- [x] 用户确认永久选择性清理、软件解码和三项 NAS 后续完善范围；记录安全契约。
- [x] 核心首版及 AgY API 文档落盘：清理、分类分页、原生安装、缓存、诊断。
- [x] AgY 保存上轮五项遗留 UI 修复；新重绘请求明确429，尚未实现新 UI。
- [ ] 独立安全复核问题闭合，OpenCode 回归／分析与旧功能门禁。
- [ ] AgY NAS 分类重绘、卸载及部署／建源／诊断／缓存界面接线。
- [ ] 独立 VM 的两种 Jellyfin 部署到播放、选择性清理哨兵验证。
- [ ] 完整测试与性能／无障碍验证、本地构建、保留数据 ADB 安装。

不升版本、不推送或发布。下列旧迭代结果不是本轮新增功能的验收证据。

## 当前迭代：应用中心操作闭环

- [x] 商店缓存失败保留、源地址失效和前台只读核对，核心92项通过。
- [x] 隔离 VM 完整真实生命周期及卸载保留数据。
- [x] AgY 完成 UI 回修，安装导航／重复提交／大字体等14项测试通过。
- [x] 最新完整测试2664通过／20环境项跳过，零告警分析；官方源真实联网补测。
- [x] 本地构建、签名核对和保留数据 ADB 安装；不发布。

详见[本轮验收](../../agent-workflow/2026-10-12-app-center-polish-validation.md)。

## 上一迭代：SSH 稳定性、NAS 完整改版与离线、文件及应用中心

- [x] 明确 NAS 综合首页与本轮补齐离线范围，分配 AgY UI / OpenCode 验证。
- [x] SSH 实际协议断线回归和依赖补丁门禁。
- [x] NAS 五入口、首页独立限量查询、下载持久化与离线播放 UI/逻辑自动化联验。
- [x] 最近目录、失败项单独重试及源变化保护。
- [x] 应用健康、磁盘预检、手动更新比较及响应式确认。
- [x] 完整分析／测试后构建，保留数据 ADB 安装，不升版本或发布。

详见[本轮台账](../../agent-workflow/2026-10-12-nas-refresh.md)。

本轮最新自动化：分析零问题，完整测试 2647 通过／19 环境项跳过／0 失败。
Android 三架构正式签名包及独立兼容签名测试包已构建，ADB 覆盖安装及短时
导航／后台返回冒烟完成。物理手机、长期弱网与真实媒体源尚未完成验收；见
[最终验证记录](../../agent-workflow/2026-10-12-nas-refresh-final-verification.md)。

## 上一迭代：实验性 Docker 应用中心

- [x] 用户确认商店兼容、缺失环境确认安装、SSH 打开与完整管理范围。
- [x] 初版目录／Compose／远端 worker／当前服务器 Provider 与持久化契约。
- [x] 原 AgY 生成导航、三页签、向导与 17 种语言初版。
- [x] AgY 完成初版审查修复；上轮用户特许主代理测试和构建。
- [x] 上轮分析零问题、2582 通过／19 跳过；仅属于上轮结果。
- [x] 隔离 Debian VM 部署／启停／更新／保留数据卸载验收。
- [x] 原调试签名包保留数据 ADB 覆盖安装并启动冒烟。

详见[当前台账](../../agent-workflow/2026-10-12-app-center.md)。

## 上一迭代：核心稳定性与高频操作优化

用户确认五项范围，见[本轮任务台账](../../agent-workflow/2026-10-11-core-stability.md)。
实现以 `f71d906` 为基线，本轮不升版本、不推送或发布。

- [x] 生命周期竞态及状态保持模拟回归，受控 10 秒／5 分钟／30 分钟用例。
- [x] ACP 万条历史分页、流式／工具协议、滚动意图及恢复自动回归。
- [x] 千／万条目录投影复用、导航隔离及列表／网格刷新滚动保持。
- [x] 更新下载完整性、模拟安装入口、重复打开和异步过期结果回归。
- [x] 本地有界耗时诊断、现行文档与最终自动化门禁结果。
- [ ] 物理手机锁屏／网络／帧率、真实 ACP／OAuth、Windows 原生安装验收。

最终门禁 2504 通过／18 环境依赖跳过／0 失败，分析零问题。UI 仅由重启后的
原 AgY 实现；OpenCode 限流后，用户允许主代理仅本轮执行验证。当前源码未
构建或 ADB 安装，不把模拟门禁视为实机验收；详情见本轮台账。

NAS 离线下载暂缓；旧轮次的勾选及通过数字不代表本轮通过。

## 历史交付：v1.0.4 后六组完善

用户确认六组全部实施，随后追加保留数据的 ADB 安装。范围与归属以
[六组契约](../../agent-workflow/2026-10-11-six-workstreams.md)为准；不推送、
不发布、不触发 Actions。v1.0.4 的 2441 通过是历史基线，不是本轮验收。

- [x] 进程身份／确认目标绑定、服务忙碌与日志消费者。
- [x] 编辑身份强制传递、可等待草稿、退出与冲突交互、传输回归。
- [x] 冷启动缓存提示与同目标恢复、Agent／ACP 模拟协议回归。
- [x] 更新 Provider 竞态与安全打开回归。
- [x] NAS 可见缩略图、缓存控制、显式播放恢复与万条索引性能记录。
- [x] 多语言／窄屏／大字体／桌面输入模拟检查、全量门禁及兼容签名 ADB 安装。

最终测试2495通过／18环境依赖项跳过／0失败，全项目分析零问题；本地
Android原调试签名测试包1.0.4/4005已`install -r`成功，哈希及签名复核一致。
物理手机帧率、真实ACP/OAuth/NAS和Windows原生行为尚未验收，见
[最终记录](../../agent-workflow/2026-10-11-six-final-verification.md)。

以下旧轮次记录按时间保留，旧诊断与未勾选项不覆盖新的实测结果。

## 历史阶段：2026-10-11 九项完整性完善

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
