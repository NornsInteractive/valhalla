# Valhalla 前端实施交接：资源占用看板、容器终端、默认 Agent 与表单重构

- **日期**：2026-09-19
- **责任范围**：前端展示层（Flutter widgets、响应式布局、交互设计、l10n ARB、Widget 测试、技术交接文档）
- **工程约束**：只读取并遵循后端 providers/services/storage 既有契约，不侵入后端业务逻辑；零硬编码用户文案；严格通过 `flutter analyze`、`dart format`、`git diff --check`。

---

## 1. 交付项清单与实现架构

### 1.1 DockerView 运行中容器“进入容器”终端
- **入口**：在容器卡片操作行新增终端按钮（`Key('docker_terminal_button_${container.id}')`），仅当容器处于 `DockerContainerState.running` 且非忙碌状态时启用；非运行状态禁用。
- **调用链路**：
  ```text
  User Tap -> ref.read(dockerCliServiceProvider).openTerminal(serverId, container, serverName)
           -> TerminalSessionBridge
           -> await bridge.start()
           -> showDialog (Mobile: Dialog.fullscreen / Desktop: 900x600 Dialog)
           -> SharedTerminalCanvas (terminal: bridge.terminal, onKey: bridge.sendKey, onPaste: bridge.pasteClipboard)
           -> finally: bridge.dispose() (仅关闭通道，不触发 container.stop)
  ```
- **异常保护**：使用 `try ... catch (e) ... finally { bridge?.dispose(); }` 保证不论启动异常、用户手动关闭还是组件卸载，PTY 桥接均被安全释放。异常时通过 SnackBar 呈现清晰本地化提示。

### 1.2 CLI 与 ACP 智能会话 Agent 选择器“设为默认”
- **CLI Chat**：
  - 在 Agent 下拉框右侧新增星星按钮（`Key('cli_set_default_agent_button')`），未设置默认时为 `Icons.star_outline_rounded`，设为默认后变为 `Icons.star_rounded`。
  - 下拉框选项文本后附带 `· 默认` 徽标。
  - 点击按钮调用 `cliChatProvider.notifier.setDefaultAgent(isDefault ? null : activeAgent.id)`，通过 `localStorageServiceProvider.getDefaultAgentId(serverId, cli: true)` 判断状态，**不自动切换当前用户会话与选择的 Agent**。
- **ACP AI Chat**：
  - 在“切换智能体”底栏弹出卡片列表项中，为每个 Agent 提供设为默认按钮（`Key('ai_set_default_agent_${profile.id}')`）。
  - 点击后调用 `aiChatProvider.notifier.setDefaultAgent(isDefault ? null : profile.id)`，使用 `StatefulBuilder` 局部刷新星星状态，**不自动关闭选择器弹窗，不强制切换当前活动 Agent**。

### 1.3 AgentFormDialog 表单重构
- **响应式布局**：
  - 移动端（宽度 < 600dp）：采用全屏对话框 `Dialog.fullscreen` + `Scaffold`，包含顶部 AppBar 及底部吸底操作栏（Cancel / Save & Detect）。
  - 桌面端（宽度 >= 600dp）：采用居中模态框 `Dialog`，限制 `maxWidth: 680, maxHeight: 750`，包含标题栏、带滚动条的主体内容区和固定底部操作行。
- **4 个业务信息分组**：
  1. **预设模板**（Preset Templates）：ChoiceChip 单选卡片（Claude Code、OpenAI Codex、OpenCode、agy、自定义）。
  2. **基础信息**（Basic Info）：名称（必填）、描述（选填）。
  3. **命令配置**（Commands）：CLI 命令（必填，`minLines: 1, maxLines: 4`，JetBrains Mono 等宽字体）、ACP 启动命令（选填，`minLines: 1, maxLines: 4`，JetBrains Mono）。
  4. **安装与登录**（Auth & Installation）：CLI 安装命令、ACP 安装命令、登录检查命令、登录命令（均支持 `minLines: 1, maxLines: 3`，JetBrains Mono）。
- **交互规范**：点击预设即时填充对应命令，点击“自定义”清空字段；表单检验必填项，防止空提交。

### 1.4 Dashboard“当前资源占用”弹窗（替换旧趋势折线图）
- **架构变更**：将 `metric_trend_dialog.dart` 中原有的折线图与历史点绘制逻辑完全替换为实时资源占用分析看板（`MetricTrendSheet`），关闭弹窗时随 Riverpod `autoDispose` 自动卸载，不常驻后台轮询。
- **三大资源视图**：
  - **CPU 视图**：
    - 顶部概览卡片：使用率 %、空闲率 %、1分钟 / 5分钟平均负载、色彩进度条。
    - 实时进程列表：基于 `resourceProcessesProvider`（StreamProvider.autoDispose，3秒轮询），按 `cpuPercent` 降序排列，展示 PID、进程命令、运行状态（STAT）、CPU 占用率。
  - **内存视图**：
    - 顶部概览卡片：已用率 %、空闲率 %、总量 100%、色彩进度条。
    - 实时进程列表：按 `rssKiB` 降序排列（次要按 `memoryPercent` 降序），展示 PID、进程命令、格式化 RSS KiB/MB、内存占用百分比。
  - **根磁盘视图**：
    - 顶部概览卡片：已用、可用、总量（KiB/MB/GB 智能格式化）、色彩进度条。
    - 扫描状态横幅：当 `RootDiskUsage.partial == true` 时展示黄色警告横幅 `resourceDiskScanPartial`。
    - 一级目录列表：按 `usedKiB` 降序排列，展示一级子目录路径、占用量及相对使用率进度条。
    - 刷新动作：右上角提供刷新按钮（`Key('disk_refresh_button')`），点击触发 `ref.invalidate(rootDiskUsageProvider)`。
- **断线感知**：SSH 未连接时，顶部展示明显的红色已断开提示条（`Icons.cloud_off_rounded`）。

### 1.5 Settings 底栏导航拖拽排序与独立勾选
- **9 大模块自由配置**：保持全部 9 个 `AppSection` 独立 CheckboxListTile。
- **拖拽排序列表**：下方为已勾选的模块展示 `ReorderableListView.builder`，提供拖拽手柄图标与触觉反馈；勾选未选模块时自动追加到列表末尾，取消勾选时从列表中剔除并保留其余模块原有顺序。
- **动态应用**：移动端底部导航栏依照 `settings.bottomNavigationSections` 存储的顺序精准呈现。

### 1.6 语言设置“跟随系统”（System Default）
- **数据层**：`SettingsState.locale` 缺省为 `Locale('system')`，`LocalStorageService.getLocale` 默认返回 `system`。
- **App 根层**：`lib/main.dart` 中 `MaterialApp` 配置 `locale: settings.locale.languageCode == 'system' ? null : settings.locale`，当用户选择跟随系统时，Flutter 自动采用宿主操作系统的默认语言与回退策略。
- **设置页**：`SettingsView` 的语言选择卡片加入“跟随系统”单选卡片。

---

## 2. 自动化测试套件与覆盖

| 测试文件 | 用例数 | 覆盖验证内容 |
| :--- | :---: | :--- |
| `test/features/dashboard_metric_trends_test.dart` | 6 | CPU 资源面板（统计、排序进程）、内存资源面板（统计、RSS 排序）、磁盘资源面板（用量、一级目录、刷新）、部分扫描警告条、断线状态横幅、Uptime 卡片不可点击 |
| `test/features/docker_terminal_button_test.dart` | 4 | 运行中容器进入终端并启动 bridge、桌面与移动端自适应弹窗、关闭弹窗安全 dispose、停止容器禁用终端按钮、bridge 启动异常友好报错 |
| `test/features/agent_default_selection_test.dart` | 2 | CLI Agent 选择器星标切换默认与防误切校验、ACP 切换弹窗星标设置默认与弹窗/会话保持 |
| `test/features/agent_form_dialog_redesign_test.dart` | 4 | 桌面居中模态与约束、移动端全屏 Scaffold、预设切换与自定义清空校验、保存成功回调与弹窗关闭 |
| `test/core/l10n_key_parity_test.dart` | 2 | 中英文 ARB 全量 key 对齐、占位符完整匹配 |
| `test/features/settings_navigation_test.dart` | 5 | 导航设置勾选、启动页选取、全不选保存、底栏拖拽重排与顺序持久化 |

---

## 3. 代码质量与验证记录
- `flutter analyze`：零 issues / 零 warnings。
- `dart format --set-exit-if-changed lib test`：全工程格式化合规。
- `git diff --check`：无多余空白字符、无行尾空行漂移。
- `test/core/l10n_key_parity_test.dart`：严格通过。
