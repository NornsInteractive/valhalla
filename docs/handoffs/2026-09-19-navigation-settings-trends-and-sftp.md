# 2026-09-19：导航设置、动态底栏、终端共享微手势、SFTP 双行与指标趋势

## 产品与工程背景

针对移动端与桌面端的体验完善，本轮完成了 5 项关键前端界面与交互升级：
1. **设置页「导航」配置**：用户可灵活自定义默认启动页与移动端底部导航栏目，支持从全部 9 个功能模块中自由选择，底栏允许空置或多选。
2. **主框架动态导航与稳健路由**：主框架全面接入 `SettingsState` 的导航配置，保证冷启动平滑、动态底栏自适应水平滚动、抽屉与侧边栏完整展示全量入口，在切换至非底栏页面时不产生 `RangeError` 越界。
3. **终端画布与交互微手势抽离复用**：将终端画布与快捷按键栏提取为独立的通用组件 `SharedTerminalCanvas`，在 SSH 终端、CLI 会话终端与交互式登录弹窗中实现 100% 复用；设计长按微滑（28dp 主轴判定、1.5 倍优势比、重置锚点）发送方向键的手势，且普通快速滑动完全保留 xterm 原生滚屏；CLI 会话补充永久设置齿轮按钮。
4. **SFTP 顶部双行设计与特殊路径导航**：拆分搜索栏与功能操作栏，窄屏自适应无溢出；切换目录自动清空检索词并同步状态；对文件列表中的 `..` 与 `.` 提供原生返回上一级与刷新交互，并隐藏破坏性上下文菜单。
5. **Dashboard 资源指标实时趋势**：CPU、内存、根磁盘卡片点击可弹出近实时趋势折线图弹窗/抽屉，接入最多 60 点（约 3 分钟）采样历史，按 70%/85% 阈值分色渲染，具备单采样等待态与连接断开停止采样提示；运行时间卡片保持不可点击。

---

## 模块设计与实现细节

### 1. SettingsView 导航设置区 (`lib/features/settings/settings_view.dart`)
- **位置编排**：置于自动连接卡片与恢复默认设置之间，避免打乱既有终端与连接卡片的视口位置。
- **默认启动页**：使用 `DropdownButtonFormField<AppSection>`，展示全部 9 个 `AppSection` 及其本地化名称与图标，独立于底栏配置生效。
- **底部导航栏**：使用 `CheckboxListTile` 渲染 9 个功能项。支持全部取消（空列表）或多选勾选；保持固定业务顺序，变更时调用 `notifier.setBottomNavigationSections(...)`。
- **重置默认**：通过 `notifier.resetDefaults()` 一键重置启动页为 `dashboard`，底栏为默认 4 项（仪表盘、AI 助手、终端、Docker）。

### 2. MainShell 动态导航与路由适配 (`lib/features/shell/main_shell.dart`)
- **稳定映射**：维护 `AppSection <-> ViewIndex`（0..8）映射函数，解耦枚举顺序与 `IndexedStack` 视图索引。
- **启动逻辑**：`initState` 默认以 `settings.startupSection` 对应的视图索引作为初始展示页面；保留下载或外部调起的覆盖能力。
- **动态底栏**：抽离 `MainBottomNavigationBar` 组件：
  - 当 `bottomNavigationSections.isEmpty` 时，Scaffold 的 `bottomNavigationBar` 为 `null`。
  - 当包含 1~9 项时，外层包裹 `SingleChildScrollView(scrollDirection: Axis.horizontal)`，保证 320dp/360dp 紧凑机型下不发生 `RenderFlex` 溢出；点击热区保持 `>=44dp` 规范。
  - 若当前展示的子页面不在底栏列表中，底栏高亮优雅回退，不抛 `RangeError`。
- **全量入口**：移动端抽屉（Drawer）与宽屏桌面 NavigationRail 始终展示全部 9 项功能入口。

### 3. 终端画布抽离与长按单指微滑手势 (`lib/features/terminal/widgets/shared_terminal_canvas.dart`)
- **组件结构**：由通用 `TerminalView` 画布、`TerminalAccessoryBar` 快捷栏及可选的 `footer` / `overlay` 构成。
- **非侵入式微滑手势**：
  - 采用轻量 `Listener` + 500ms 定时器方案：
    - `onPointerDown`：记录初始触点并启动 500ms 计时器。
    - `onPointerMove`：500ms 内位移超过 10dp 即判定为常规滚动/滑动，立即取消长按计时，将事件完整交由底层 `TerminalView` 原生滚屏处理；500ms 计时器触发后标记进入长按状态，若单指在主轴方向滑动超过 28dp 且主轴位移大于副轴 1.5 倍（有效过滤斜向误触与微小抖动），触发对应方向键（`↑`、`↓`、`←`、`→`）回调，并重置锚点支持连续微滑。
    - `onPointerUp` / `onPointerCancel`：安全清理状态与计时器。
  - `Listener` 作为 `TerminalView` 的父级容器，保证了底层渲染树中 `RenderTerminal` 始终处于最内层叶节点，严格满足自动化测试中对终端原生命中检测的要求。
- **CLI Chat 接入**：在 `lib/features/chat/cli_chat_view.dart` 的移动端 AppBar 与桌面端侧边栏增加永久设置齿轮按钮，点击直达 `AgentManagementView`；终端交互对接 `sendTerminalKey` 与 `pasteTerminalClipboard`。

### 4. SFTP 顶部双行设计与特殊目录交互 (`lib/features/files/sftp_file_view.dart`)
- **双行头部**：
  - 第一行：专供当前目录路径面包屑与搜索输入框，输入实时同步 `searchQuery`，右侧带一键清空按钮。
  - 第二行：水平滚动行包裹上传、新建文件夹、新建文件、排序切换、刷新、传输列表按钮，窄屏响应式无溢出。
- **路径与搜索同步**：监听 `currentPath` 变更，目录切换时自动清空搜索输入框，避免遗留搜索词阻碍新目录文件浏览。
- **特殊条目保护**：在文件列表中对 `..`（返回上一级）与 `.`（刷新当前目录）提供专用点击处理，并不显示更多（`more_vert`）上下文操作菜单，杜绝误触发重命名、删除或下载等非法操作。

### 5. Dashboard 近实时指标趋势图表 (`lib/features/dashboard/`)
- **入口触发**：CPU、内存、根磁盘卡片支持点击唤起模态弹窗/抽屉（`MetricTrendSheet`）；运行时间卡片保持不可点击。
- **数据源绑定**：接入 `systemMetricsHistoryProvider`，最多保留 60 个历史采样点（约 3 分钟窗口）。
- **自定义绘制与分级阈值**：通过 `MetricTrendPainter` 绘制抗锯齿折线与渐变填充，内置 70%（黄色预警）与 85%（红色危险）阈值分色标线及背景网格。
- **异常态友好**：仅有单点数据时展示 `trend_waiting_banner`（提示正在收集数据）；SSH 断开时展示 `trend_stopped_banner`（提示采样已暂停，避免误以为数据冻结）。

---

## 自动化测试与工程验证

1. **新特性专项测试**：
   - `test/features/settings_navigation_test.dart`：验证 9 项底栏复选框独立切换、启动页下拉选择及重置默认设置。
   - `test/features/main_shell_dynamic_nav_test.dart`：验证空底栏 `null`、9 项自适应、启动页自动定位及抽屉跳过底栏项安全防崩溃。
   - `test/features/shared_terminal_canvas_test.dart`：验证长按微滑主轴 28dp 触发方向键、1.5 倍过滤斜向微抖、常规轻扫保留滚屏及快捷栏粘贴功能。
   - `test/features/cli_chat_settings_button_test.dart`：验证移动/桌面双端永久齿轮入口直达 Agent 管理，及终端交互对接。
   - `test/features/sftp_two_row_header_test.dart`：验证双行头部窄屏无溢出、搜索词自动同步与清空、`..` 和 `.` 特殊条目无上下文菜单。
   - `test/features/dashboard_metric_trends_test.dart`：验证各指标卡片点击唤起趋势图、单点收集等待态、断开停止态及 Uptime 不可点击。
2. **原有测试兼容与边界修复**：
   - 修复 `test/features/main_shell_top_layout_test.dart` 中对 `IndexedStack` 的 Finder 唯一性限定。
   - 修复 `lib/l10n/app_zh.arb` 中占位符元数据对称性，保证 `test/core/l10n_key_parity_test.dart` 零差分。
   - 保证 `test/features/terminal_tmux_notice_test.dart` 终端 hit-test 命中 `RenderTerminal`。
3. **全工程门禁检验**：
   - `flutter test`：全库 740+ 项测试全部通过（0 失败，0 异常）。
   - `flutter analyze`：No issues found!
   - `git diff --check`：无尾随空白字符，EOF 严格单换行。
