# 2026-09-19：CLI 原生会话、重启、操作反馈与性能

## 产品与工程决策

- ACP 保留，新增独立 CLI 页面；共用当前服务器的 Agent 配置，不共用本地 ChatSession 或 ACP 共享开关。
- 列表只显示当前服务器已添加 Agent。安装、登录、SDK 安装和删除需要显式确认，不自动升级。
- 切换、选择历史和新建按钮不创建远端会话；新建仅进入草稿，结构化模式首次发送时才创建。
- 历史来自当前 SSH 执行用户的官方接口，默认跨目录，支持目录过滤、刷新和支持的原生分页。无官方全局列表的 CLI 使用真实终端选择器，不伪造完整列表。
- 删除表示删除远端原生历史。必须确认，忙时阻止，失败保留；无已验证官方删除能力则禁用。
- 所有界面 / ARB / 展示测试由 agy 历史 Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b` 修改，模型 `gemini-3.8-flash-high`、effort high；后端开发者不改展示。

## CLI 技术接口

| Agent | 历史与交互 | 远端删除 |
| --- | --- | --- |
| Codex | 官方 app-server `thread/list/read/resume/start`、`turn/start/interrupt`、增量与命令 / 文件逐次审批 | 检测 `codex delete` 支持后调用，先检查线程状态 |
| OpenCode | 官方全局 `/experimental/session`、HTTP/SSE、prompt_async、一次权限审批、abort | 官方 DELETE，先检查忙碌状态 |
| Claude Code | 一次性官方 SDK `listSessions/getSessionMessages`；真实 PTY `claude --resume <id>` 交互与审批 | 未确认安全官方 API，禁用 |
| agy / 自定义 | 独立真实 PTY，使用 CLI 原生会话选择和审批；不声称完整结构化历史 | 无已验证官方 API，禁用 |

业务入口 `cliChatProvider`，服务 `lib/infrastructure/cli/`。隔离维度为服务器、Agent、SSH 执行身份和 native ID。本地仅保存运行期选择 / 草稿，不复制成 ACP 历史。页面切换不释放会话；服务器 / 身份变化或断线清理原生通道与视图。忙时阻止 Agent 切换 / 删除。

Codex 经 SSH stdio，薄适配仅增删 JSON-RPC 版本头，请求关联复用 `acpd.Connection`，不自研协议引擎。原生扩展问答 / 权限请求尚未完整可视化，失败关闭并提示停止后使用真实 CLI，不默认批准、不传跳过权限参数。

OpenCode 按需启动官方 `serve --hostname 127.0.0.1 --port 0`，复用 `dartssh2.forwardLocal` 与本地回环 Socket 接入标准 HttpClient。临时 Basic Auth 密码经 stdin 设置，不落配置 / 日志，不开放公网端口。读取运行时 OpenAPI 检查能力；旧版本缺全局接口时提示不支持并保留终端回退，不假装当前目录列表是全局。分页遵循官方 `x-next-cursor`。关闭时仅向本应用启动的 SSH 进程发送 TERM 并清理通道；SSH signal 不受支持的服务器仍需验证退出，不能承诺无残留。

Claude 历史 SDK 仅在用户确认后安装到 `$HOME/.local/share/valhalla/claude-history`。读取为短命 Node 进程，没有专有 Daemon，不访问私有历史数据库，也不调用 SDK 模型 API。完整交互 / 登录仍由原生 CLI 处理。

## 安全重启与后台执行

`serverPowerProvider` / `ServerPowerService` 状态：idle、submitting、accepted、unknown、failed、passwordRequired、verified。危险确认展示捕获的目标服务器及实际连接终端 / Agent / 待传输数量；确认后目标改变则取消。

先读取有效 Linux boot_id 与 UID。Root 直接调用；非 Root 使用 `sudo -n` 或已有安全存储 Sudo 密码。缺密码时询问仅本次密码，经 stdin 发送，不保存；拒绝换行 / NUL。只有 systemctl 不存在时才使用 shutdown，不因权限失败降级。accepted 仅表示命令已受理，不能称服务器完成重启；发送后异常 / 没有退出码为 unknown，不自动重试。accepted / unknown 阻止重复提交。重连只读复验 boot_id，变化后才 verified。

另修复同服务器并行后台 exec 共用退出码的问题：每次执行独立收集退出码，并等待 stdout/stderr 最终输出。没收到退出状态返回 -1，而非成功。Shell 包装、PATH、历史策略和 Sudo stdin 不变。

## 容器与性能

Docker 使用 `pendingActions[containerId]`，对应按钮动画，同容器冲突操作禁用，其他容器可并行；inspect 同样显示等待。finally 清理标记，代际 / 刷新序号阻止旧结果覆盖新状态，异常保留可见反馈。

PTY resize 保留最新尺寸、75ms 合并去重，关闭 / 重连取消旧请求，重连复用最后尺寸；dispose 后晚到的 PTY 分配会关闭，不向已释放状态发布结果。

卡顿反馈来自 debug APK。隐藏 IndexedStack 页面、xterm buffer resize 和 IME 约束传播是待测路径，不凭猜测重写导航，也不关闭 Android adjustResize。物理设备同服务器 / 字体 / 1500 行回滚 / 键盘，对比 debug 与 profile：终端、CLI、聊天、文件重命名、服务器表单各开关键盘 20 次，记录 UI/Raster p50/p95、超预算帧、resize 次数。trace 确认隐藏终端重复布局后才由 agy 做隐藏约束缓存 / TickerMode，必须保留焦点、光标避让、滚动、连接和历史。目前不宣称真机卡顿完全解决。

## 后台命令历史隔离（仅设计，未实施）

1. 手动 PTY 与用户明确选择“发送到终端”的快捷命令保留正常 Shell 历史。
2. Dashboard、Docker、系统管理、检测和后台快捷命令已使用独立非交互 SSH exec，包装 `bash -l -c`，不是注入手动终端。非交互 Bash 通常不启用 history，但 profile / 钩子可主动写入，先验证实际污染来源。
3. 候选中央子进程策略：禁用 history、独立空 HISTFILE，保留 Login Shell PATH、输出 / 退出码、流式和 Sudo stdin。不能依赖前导空格，不能清用户历史 / 改全局配置，也不承诺隐藏系统审计。
4. 在 Bash / Zsh / 自定义 profile 中比较后台查询前后历史文件，并确认手动输入与明确直通快捷命令仍正常记录。取证与兼容测试通过后才实施。本轮未改此执行策略。

## 验证与限制

- **自动化测试覆盖**：
  - 定向自动化：重启权限 / 未知结果 / 重复提交 / boot_id、resize / 释放、原生草稿 / 切换 / 服务器隔离、Codex 审批 / 删除失败保留、OpenCode HTTP/SSE 回环转发 / 原生 API、Docker 并行状态、SSH 并行退出码 / 最终输出。
  - UI 专项包括 CLI 会话、缺依赖 / ACP 不影响 CLI、远端删除与 SDK 确认、Dashboard 重启、Docker 动画、侧栏 / 抽屉导航与旧页面回归；均纳入完整项目门禁。
  - 最终全工程 `flutter test --no-pub --reporter expanded`：715 项全部通过。
- **静态分析与格式规范**：
  - `git diff --check`：无多余空白字符或 EOF 空行。
  - 全工程 `flutter analyze --no-pub`：0 issues。
  - `dart format --output=none --set-exit-if-changed lib test`：169 个文件，0 修改。
- **构建输出**：
  - `flutter build apk --profile`：成功生成 `build/app/outputs/flutter-apk/app-profile.apk`。
  - `flutter build apk --debug`：成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。均已在收尾重新构建，不是沿用上轮 APK。
  - 环境仅连接 Linux 桌面，没有 Android 物理设备；Windows / Linux 原生交付与远端行为不因 Android 构建通过而视作已验收。
- **已知限制与待真机验收项**：
  - 没有对真实服务器执行重启、安装、登录或删除。
  - 真实 CLI 版本组合、外部 CLI 并发、长历史量待指定远程环境联调。
  - 终端 IME 输入法切换与实际渲染帧率待在物理真机运行 Profile APK 进行采样验收，目前不声称已完全修复。

官方依据（2026-09-19 核实）：[Codex app-server](https://developers.openai.com/codex/app-server)、[OpenCode Server](https://dev.opencode.ai/docs/server/)、[OpenCode 官方接口类型](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/js/src/v2/gen/types.gen.ts)、[Claude SDK sessions](https://code.claude.com/docs/en/agent-sdk/sessions)、[Claude SDK TypeScript](https://code.claude.com/docs/en/agent-sdk/typescript)、[Flutter profile](https://docs.flutter.dev/perf/ui-performance)。
