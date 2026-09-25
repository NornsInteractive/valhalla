# Valhalla UI Handoff — 顶部布局重排（切片 C of 3）✅ **已完成并验收**

> ✅ **已实现、已验收**。落地结果见文件末尾「验收记录」一节。
>
> 本轮共三个切片，本文件是 **C**：
> - A 远程文件页：下载入口 + 打开前格式判断 → `2026-09-16-sftp-file-open-download-ui.md`（已完成）
> - B 设置页「启动自动连接」二选一 → `2026-09-16-auto-connect-settings-ui.md`（已完成）
> - **C（本文件）** 顶部布局重排（已完成）

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

## 落地时的硬性要求

1. **先把每处改完再动下一处，不要留下悬空引用**。
   上一轮（切片 B）有过教训：只写了 widget 引用却忘了定义类，导致全项目编译失败。
   每改完一个文件就 `flutter analyze` 一次确认 0 issue。
2. **只改 `lib/features/shell/`、`lib/l10n/`（如需）、`test/features/`**。
   不要动 `lib/core/`、`lib/data/`、`lib/infrastructure/`、
   `lib/features/files/`、`lib/features/settings/`。
3. 完成后必须自己跑通并把**真实输出**贴出来：
   - `dart format --set-exit-if-changed .`
   - `flutter analyze`（必须 0 issue）
   - `flutter test -j 1`（必须全绿，**全量**，不只跑你新写的那个文件）
   注意：当前基线是 **480 个测试全绿**，你不应该让它变红。
4. ARB 只做增量编辑，**绝不要 `git checkout` 两个 arb 文件**；
   en/zh 必须成对，改完跑 `flutter test -j 1 test/core/l10n_key_parity_test.dart`
   （当前 362/362）。
5. 断言要有牙：写完后临时改掉被测逻辑（例如把 `_ => _lastBottomNavIndex`
   改回 `_ => 4`），确认测试**真的会红**，再改回来。

---

## 1. 目标形态（用户要求）

1. **移除右上角「添加SSH服务器」按钮**（`main_shell.dart` 里两个 `IconButton`，
   分别是宽屏 `_buildTopBar` 约 `:666-670` 和紧凑 AppBar 约 `:759-763`）。
2. **「切换SSH」下拉从左上移到右上**（现在是 `_buildTopBar` 里靠左的
   `InkWell`，约 `:571-627`；紧凑 AppBar 里它是 `title`）。
3. **左上角改为菜单栏按钮**：点击从左侧滑出抽屉，抽屉内容 =
   **原「更多功能」里的四个入口**（见第 2 节）。
4. **去掉底部「更多功能」**（compact `NavigationBar` 的第 5 个目的地
   `more_horiz`，约 `:786`，以及 `_showMoreNavigationModal`，约 `:298-358`）。

**添加服务器的入口不能丢**：移除右上角按钮后，它还需要在「切换SSH」那个
bottom sheet 的头部（`_showServerSelector`，约 `:166-296`，那里本来就有一个
添加按钮）以及**抽屉里**能被找到。请在方案里说明你把它放在哪、至少保证一处可达。

---

## 2. 抽屉的功能入口清单（跳转逻辑，这部分是固定的）

抽屉里就是这四个，跳转方式沿用现有代码：先关抽屉，再
`setState(() => _currentIndex = N)`。

| 顺序 | 图标 | 文案 key | `_currentIndex` |
|---|---|---|---|
| 1 | `Icons.folder_outlined` | `navFiles` | `_sftpTabIndex`（= 3） |
| 2 | `Icons.memory_outlined` | `navSystem` | 5 |
| 3 | `Icons.bolt_outlined` | `navCommands` | 6 |
| 4 | `Icons.settings_outlined` | `navSettings` | 7 |

抽屉标题用 `navMore`（沿用现有文案，不必新增 key）。
选中态（`selected:`）照现有 `_showMoreNavigationModal` 的写法。

---

## 3. ⚠️ 必须处理的陷阱：`mobileSelectedBottomIndex`

```dart
// main_shell.dart 约 :698-704，改之前
final mobileSelectedBottomIndex = switch (_currentIndex) {
  0 => 0, // Dashboard
  1 => 1, // AI
  2 => 2, // Terminal
  4 => 3, // Docker
  _ => 4, // More   ← 兜底把 Files(3)/System(5)/Commands(6)/Settings(7) 全映射到第 5 个
};
```

**底部去掉「更多」后 `NavigationBar` 只剩 4 个目的地（索引 0..3），
这个 `_ => 4` 会越界**，从抽屉跳到 Files / System / Commands / Settings 时
`NavigationBar` 会因 `selectedIndex` 超范围而报错。

请在方案里说明你打算怎么改这个映射（参考方向：把 `_ => 4` 改成一个合法索引，
让非底部入口落回某个可见的 tab）。

---

## 4. 自由度

本文件只固定「哪个入口对应哪个 `_currentIndex`」和「不能丢的入口」。
抽屉的视觉、动画、按钮位置、图标风格、是否用 `Scaffold.drawer` 还是别的方案，
都由你按 Material 3 决定 —— 但**已批准方案里已经定下的部分请照办**。

`_buildNavigationRail`（宽屏 rail，约 `:457-537`）**本轮不用改**——
它已经同时包含全部 8 个目的地。

三个断点的布局要求不变：紧凑 `<600` NavigationBar，中等 `600–1024` 折叠 rail，
宽屏 `>1024` rail + inspector。

---

## 5. Constraints

1. 不加新依赖；不改 `lib/core/`、`lib/data/`、`lib/infrastructure/`、
   `lib/features/files/`、`lib/features/settings/`。
2. ARB 只做增量编辑，**绝不要 `git checkout` 两个 arb 文件**；
   en/zh 必须成对（当前 362/362）。
3. 必须补的 widget 测试（已批准方案第 4 节列了 5 组，照它写）：
   - 右上角（紧凑 AppBar 与宽屏 TopBar）都不再有添加服务器按钮；
   - 左上角 `Icons.menu` 点击后出现 `Drawer`，内含 4 个入口；
   - 从抽屉点 4 个入口分别得到 `_currentIndex = 3 / 5 / 6 / 7`；
   - 底部 `NavigationBar` 只剩 4 个目的地、**不再有 `Icons.more_horiz`**，
     且在 `_currentIndex` 为 3/5/6/7 时 `pump()` **不抛 RangeError/断言失败**；
   - 添加服务器入口可达：切换弹窗头部能唤起添加对话框，抽屉内入口也能。
4. 跑 `dart format`、`flutter analyze`、`flutter test -j 1`（必须带 `-j 1`）。
5. 断言要有牙：写完后临时改掉被测逻辑，确认测试**真的会红**，再改回来。

## After you finish

列出改动过的文件，并贴出 `dart format --set-exit-if-changed .`、
`flutter analyze`、`flutter test -j 1` 三条命令的**真实输出**。

---

# 已批准方案（照此实现）

> 以下是上一轮你给出的方案，用户已批准。**按它实现，不要重新设计。**

## 1. 右上角「添加SSH服务器」按钮

**移除**紧凑 AppBar 与宽屏 TopBar 两处 `IconButton(Icons.add)`。
添加服务器的入口改为下面的双入口设计（第 6 小节）。

## 2. 左上角菜单按钮 + 抽屉

- 紧凑 AppBar 的左侧改为 `IconButton(Icons.menu)`，`onPressed` 调
  `Scaffold.of(context).openDrawer()`（或 `_scaffoldKey.currentState?.openDrawer()`）。
- 用 `Scaffold.drawer` 挂抽屉。宽屏/中等断点同样保留该菜单按钮
  （原来的服务器切换移到右上后，左上就留给菜单）。
- 抽屉内容 = 4 个入口（顺序、图标、文案 key、目标 `_currentIndex`）：

  | 顺序 | 图标 | key | `_currentIndex` |
  |---|---|---|---|
  | 1 | `Icons.folder_outlined` | `navFiles` | `_sftpTabIndex`（= 3） |
  | 2 | `Icons.memory_outlined` | `navSystem` | 5 |
  | 3 | `Icons.bolt_outlined` | `navCommands` | 6 |
  | 4 | `Icons.settings_outlined` | `navSettings` | 7 |

  抽屉标题用 `navMore`。点击后先关抽屉再
  `setState(() => _currentIndex = N)`。选中态照 `_showMoreNavigationModal` 的写法。

## 3. 底部「更多功能」移除

去掉 compact `NavigationBar` 的第 5 个目的地（`Icons.more_horiz`）与
`_showMoreNavigationModal`。底部只剩 4 个目的地（0..3）。

## 4. `mobileSelectedBottomIndex` 越界修复（**核心**）

新增状态 `int _lastBottomNavIndex = 0`（范围固定 0..3，在底栏被点击时更新），
映射改为：

```dart
final mobileSelectedBottomIndex = switch (_currentIndex) {
  0 => 0, // Dashboard
  1 => 1, // AI
  2 => 2, // Terminal
  4 => 3, // Docker
  _ => _lastBottomNavIndex, // 抽屉子页面（3/5/6/7）回落到最后停留的底栏项
};
```

这样严格保证 `0 <= selectedIndex < 4` 永不越界。

## 5. 已识别的其他风险（方案里提出，实现时要处理）

1. **紧凑 AppBar 宽度挤压**：左侧汉堡 + 右侧服务器名下拉 + 重连按钮，
   服务器名过长会 RenderFlex overflow。
   → 服务器名用 `Flexible` / `ConstrainedBox(maxWidth: 130)` +
   `TextOverflow.ellipsis`。
2. **既有测试的 `Icons.more_horiz` 断言**：入口移除后可能失效。
   → 先检查 `test/features/` 下所有 shell 相关用例并同步适配。

## 6. 添加服务器入口的位置（双入口）

1. **切换弹窗头部**：保留 `_showServerSelector` 里既有的
   `IconButton(Icons.add_circle_outline, tooltip: addServer)`。
2. **抽屉底部**：在 4 个入口下方加 `Divider` + 专用 `ListTile`
   （`Icons.add_circle_outline` + `context.l10n.addServer`，用主题色），
   `onTap` 先关抽屉再 `_openAddServerDialog(context)`。
   沿用既有 `addServer` key，**不需要新增 ARB key**。

---

## 验收记录（2026-09-16）

### 改动的文件（`find -newermt` 核对，实际只动了这 3 个）

| 文件 | 说明 |
|---|---|
| `lib/features/shell/main_shell.dart` | 唯一的产品代码改动 |
| `test/features/main_shell_top_layout_test.dart` | 新增，12 个测试 / 5 组 |
| `docs/handoffs/2026-09-16-top-layout-drawer-ui.md` | 本文件 |

**lanes 干净**：`lib/core/`、`lib/data/`、`lib/l10n/`、`lib/features/files/`、
`lib/features/settings/` 全部未被触碰。ARB 无新增 key，仍是 362/362 对等。

### 磁盘核对（不采信自述，逐条 grep）

消失：`Icons.more_horiz`、`_showMoreNavigationModal`、`_ => 4`、
紧凑 AppBar 与 `_buildTopBar` 的 `Icon(Icons.add,)`。
保留：`_showServerSelector` 头部的 `Icons.add_circle_outline`（有意保留的第 1 个入口）。

新增：
- `int _lastBottomNavIndex = 0;`（`:34`）
- `_ => _lastBottomNavIndex`（`:720`）
- 底栏 `onDestinationSelected` 首行 `_lastBottomNavIndex = navIndex;`（`:803`）
- `drawer: _buildDrawer(context)` 挂在 `_buildExpandedDesktopShell`(`:413`)、
  `_buildMediumRailShell`(`:452`)、`_buildCompactMobileShell`(`:724`) 三个 Scaffold 上
- 菜单按钮用 `Builder` + `Scaffold.of(ctx).openDrawer()`（`:588-593`、`:726-731`），
  两处都包了 `Builder` 以拿到抽屉所在 Scaffold 的 context
- 抽屉底部添加服务器入口（`:352-370`）

### 变异测试（我自己重跑，4/4 全被抓）

| # | 变异 | 结果 |
|---|---|---|
| 1 | `_ => _lastBottomNavIndex` 改回 `_ => 4` | 抓（5 红，`0 <= selectedIndex < destinations.length` 断言失败） |
| 2 | 删掉 `_lastBottomNavIndex = navIndex;` | 抓（1 红，回落值断言 `2` 失败） |
| 3 | 往紧凑 AppBar 塞回 `Icon(Icons.add,)` | 抓（Group 1 紧凑用例红） |
| 4 | 删掉抽屉里的添加服务器入口 | 抓（Group 5 抽屉用例红） |

变异 2 尤其关键：它证明 `main_shell_top_layout_test.dart:293` 断的是
**回落的具体值 2**，而不只是「没崩」——一个静默错误的索引也会被抓住。

### 门禁输出

```text
dart format --set-exit-if-changed .  →  Formatted 132 files (0 changed)
flutter analyze                      →  No issues found! (ran in 1.2s)
flutter test -j 1                    →  00:35 +492: All tests passed!
```

基线 480 → 492（+12），无回归。ARB 362/362。
