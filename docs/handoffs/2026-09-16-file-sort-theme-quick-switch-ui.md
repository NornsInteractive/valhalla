# Valhalla UI Handoff — 文件排序按钮 + 顶栏主题快切（第二批 · 批次 1 of 2）

> 这是用户第二批需求里**依赖最少**的两项，先做这两项。
> 传输列表（取消/暂停/继续/删除）+ 后台完成通知是**批次 2**，
> 后端改造还没做完，**本轮不要碰**，brief 之后单独给。

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
```

## Allowed files（严格）

- `lib/features/files/sftp_file_view.dart` — 只加排序入口
- `lib/features/shell/main_shell.dart` — 只加主题按钮与弹窗
- `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb` — 少量新键
- `test/features/` — 新增/调整用例

**不要动** `lib/core/`、`lib/data/`、`lib/infrastructure/`、
`lib/features/settings/`。

---

## 1. 后端契约（已实现、已变异验证，直接用）

### 1.1 文件排序

```dart
enum SftpSortKey { name, size, date }   // lib/core/providers/sftp_provider.dart

// SftpState 上新增两个字段（默认 name / true）：
final SftpSortKey sortKey;
final bool sortAscending;
```

**关键：排序后的列表就是既有的 `SftpState.filteredFiles`。**
不要自己再排一次——那个 getter 已经同时处理了：搜索过滤、排序、
**目录优先**、以及同值时的名字兜底。直接渲染它。

改排序的唯一入口（会落盘，重启和重连都保留）：

```dart
Future<void> setSort({required SftpSortKey key, required bool ascending});
```

`setSort` 的语义是「一次性设置字段与方向」，所以「点同一个字段就反向」
这个交互要由 UI 判断后把最终的 `ascending` 传进来。另外也有单独的
`setSortKey(key)` 和 `toggleSortDirection()`，但**推荐统一用 `setSort`**，
一次 state 变更 + 一次落盘，不会出现中间态。

`SftpFileItem.modifiedEpoch`（Unix 秒，int）已补上供按时间排序。
**不要拿 `item.modified` 那个字符串排序**——它在服务器没给时间时会退化成
`'-'`，按字符串比较会得出错误顺序（这条有变异测试守着）。

### 1.2 主题 / 主题色（含一个前置 bug 修复）

`SettingsNotifier` **之前完全没有持久化**（`build()` 返回 `const SettingsState()`，
setter 只改内存），所以主题一直是「重启即失效」的。后端已经修好：

```dart
// lib/core/providers/settings_provider.dart
class SettingsState {
  final AppThemeMode themeMode;      // 默认 dark
  final AppAccentColor accentColor;  // 默认 cyberEmerald
  final Locale locale;               // 默认 zh
}

Future<void> setThemeMode(AppThemeMode mode);
Future<void> setAccentColor(AppAccentColor color);
```

枚举（`lib/app/theme.dart`，已被 `settings_provider.dart` re-export）：

```dart
enum AppThemeMode { system, light, dark, amoled }
enum AppAccentColor { cyberEmerald, techBlue, electricViolet, crimsonRed, amberOrange }
```

数值无法识别时 `build()` 会回落到默认值而不是抛异常，你不需要处理这种情况。

**注意**：这三个 setter 的签名从 `void` 变成了 `Future<void>`。
在 `onChanged` 里直接调用不 `await` 是没问题的。

---

## 2. 需求一：文件列表排序

在 `sftp_file_view.dart` 的 `_buildActionBar`（约 `:458-512`，就是那个
「搜索框 + 一排 IconButton」的行）里加一个排序入口。

要求：

1. 用 `Icons.sort` 的 `IconButton`，tooltip 用新键 `sftpSort`。
2. 点击弹一个菜单，三项：名称 / 大小 / 时间（`sftpSortName` /
   `sftpSortSize` / `sftpSortDate`）。
3. **当前排序字段要有可见反馈**（例如菜单项打勾，或用 `checked` 状态）。
   只让用户点、看不出当前按什么排是不合格的。
4. 再给一个切换升降序的入口（`sftpSortAscending` / `sftpSortDescending`）。
   可以是菜单里单独一项，也可以是「点已选中的字段就反向」——
   **二选一即可，但必须在界面上让用户看得出当前是升序还是降序。**
5. 目录恒排在文件前面，这一层**不受升降序影响**，行为已在
   `filteredFiles` 里实现，你不要再动。

## 3. 需求二：顶栏主题切换按钮

用户要求：**放在右上角「切换服务器」按钮的左边**，点击弹窗选择。

两个位置都要加（响应式布局有两套外壳）：

| 外壳 | 函数 | 插入位置 |
|---|---|---|
| 桌面/平板 | `_buildTopBar`（约 `:555-692`） | 在 `showInspectorToggle` 那个 `IconButton` 之后、`Flexible`（服务器切换器，约 `:608`）**之前** |
| 移动端 | `_buildCompactMobileShell`（约 `:690-830`）的 `AppBar.actions` | 作为 `actions` 的**第一个元素**，在服务器切换 `InkWell`（约 `:734`）之前 |

按钮用 `Icons.palette_outlined`（或你觉得更合适的图标），
tooltip 用新键 `themeQuickSwitch`。

弹窗内容（**外观模式 + 主题色，不含语言**）：

- 外观模式：4 个 `RadioListTile<AppThemeMode>`——
  跟随系统 / 浅色 / 深色 / AMOLED。
  复用既有键 `themeSystem` / `themeLight` / `themeDark` / `themeAmoled`。
  这个 `RadioListTile` 的写法可以参考设置页 Language 卡片
  （`settings_view.dart` 里那几个，注意该文件顶部有
  `// ignore_for_file: deprecated_member_use`，说明用的是旧的
  `groupValue` + `onChanged` API——**你也用同一套 API**，
  否则新老 API 混用会让 analyzer 报警）。
- 主题色：5 个色块（`AppAccentColor.values`，每个的 `.color` 给颜色），
  水平 `Wrap` 排开，当前选中的要有可见选中框（例如外圈描边或打勾）。
  复用既有键 `settingsAccentColor` 作为这一组的小标题。

弹窗要能实时预览：`onChanged` 里直接调 `setThemeMode` / `setAccentColor`，
不需要「确定/取消」按钮——切换立刻生效是用户要的效果。

**读 provider 时用 `ref.read` 取 notifier、`ref.watch` 取当前值**，
注意 `main_shell.dart` 里的是 `ConsumerState`，弹窗里如果要用
`ref` 需要包一个 `Consumer`（参考 `_showServerSelector` 的写法）。

## 4. ARB 新键（en/zh **必须成对**，不要 `git checkout` 任一个 arb 文件）

排序用：

| key | en | zh |
|---|---|---|
| `sftpSort` | Sort | 排序 |
| `sftpSortName` | Name | 名称 |
| `sftpSortSize` | Size | 大小 |
| `sftpSortDate` | Date modified | 修改时间 |
| `sftpSortAscending` | Ascending | 升序 |
| `sftpSortDescending` | Descending | 降序 |

主题用：

| key | en | zh |
|---|---|---|
| `themeQuickSwitch` | Theme | 主题 |

主题模式与主题色的名字**都已存在**（`themeSystem` / `themeLight` /
`themeDark` / `themeAmoled` / `settingsAccentColor` / `accent*`），
**不要重复添加**。

## 5. 硬性要求

1. **先写定义再写引用**，每改完一处 `flutter analyze` 确认 0 issue。
   历史教训：切片 B 曾只写 widget 引用不写类定义，导致全项目编译失败。
2. 完成后必须跑并**贴出真实输出**：
   - `dart format --set-exit-if-changed .`
   - `flutter analyze`（必须 0 issue）
   - `flutter test -j 1`（**全量**，不只跑新文件）
   基线（开工前实测）：**535 个测试全绿**，`flutter analyze` 有 6 条
   `state.transfer` 的 deprecation info（`sftp_file_view.dart` 里，
   批次 2 会清掉）。你**不要**让测试变红、也不要新增任何 analyze issue。
3. ARB 改完自己核对 en/zh 键数相等（**当前 362/362**，加上本轮 7 个新键后
   两侧必须都等于 369）。两个文件都要核，别只改一个。
4. **测试要有牙**：写完跑一遍变异——例如把排序菜单的 `setSort` 调用删掉，
   确认测试真的会红，再改回来。
5. `sftp_file_view.dart` 的既有用例在 `test/features/sftp_file_view_test.dart`，
   里面有一个 `_TestSftpNotifier` 替身；如果你用到 `setSort`，
   记得在替身里也要实现它（或者改用真实 notifier + 替身 service）。

---

## 验收记录（2026-09-17）

### 改动的文件

| 文件 | 归属 | 说明 |
|---|---|---|
| `lib/core/providers/sftp_provider.dart` | 我 | `SftpSortKey` + `filteredFiles` 排序/搜索派生 |
| `lib/data/storage/local_storage_service.dart` | 我 | 5 个持久化 key（排序字段/方向 + 主题模式/主题色/locale） |
| `lib/core/providers/settings_provider.dart` | 我 | 修掉「setter 只改内存不落盘」的真实持久化 bug |
| `lib/features/files/sftp_file_view.dart` | agy | 排序入口 `PopupMenuButton`，`:504-521` |
| `lib/features/shell/main_shell.dart` | agy | 主题按钮 ×2 + `_showThemeQuickSwitch` 弹窗，`:169-293` |
| `lib/l10n/app_{en,zh}.arb` | agy | +7 键，362 → **369/369** |
| `test/core/sftp_sort_test.dart`（新，11 个） | 我 | 排序纯逻辑 |
| `test/core/settings_persistence_test.dart`（新，10 个） | 我 | 主题/排序落盘 |
| `test/features/sftp_file_view_test.dart` | agy | 排序交互用例 |
| `test/features/main_shell_top_layout_test.dart` | agy | Group 6 主题弹窗 + 位置 |

**lanes 干净**：`lib/core/` 无 `lib/features/` 反向依赖。

### 磁盘核对（不采信自述，逐条 grep）

- `sftp_file_view.dart`：`setSort` ×3、`Icons.sort` ×1、`state.transfer` 残留读取 **0**
  （批次 2 的 deprecation info 已清零）。
- `main_shell.dart`：`themeQuickSwitch` ×3、`setThemeMode` ×4、`setAccentColor` ×1、
  `Icons.palette_outlined` ×2（宽屏 + 紧凑）。
- 位置（用户唯一硬性要求）：宽屏 `:736-742` 主题按钮在
  `[inspectorIcon, SizedBox(4), themeIcon, SizedBox(4), Flexible(serverSwitcher)]`；
  紧凑 `:867-872` 在 `AppBar.actions` 首位、服务器切换器 `InkWell` 之前。
  两处都**在「切换服务器」左边**。

### 变异测试（我自己重跑，7 条，最终 6 抓 0 存活）

| # | 变异 | 结果 |
|---|---|---|
| 1 | 删掉 `notifier.setSort(...)`（`SftpSortKey` 分支） | 抓（`+9 -1`） |
| 2 | `ascending: isSameKey ? !state.sortAscending : ...` → `ascending: state.sortAscending` | **首轮存活**，补测试后抓（`+9 -1`） |
| 3 | 删掉 RadioListTile 的 `setThemeMode` 调用 | 抓（`main_shell_top_layout_test.dart:412`） |
| 4 | 删掉主题色 `InkWell` 的 `setAccentColor` 调用 | 抓（`:391`） |
| 5 | 宽屏主题按钮移到 inspector 左侧（顺序变、不溢出） | **首轮存活**，补测试后抓（`+14 -1`） |
| 6 | 紧凑主题按钮移到服务器切换器之后 | **首轮存活**，补测试后抓（`+14 -1`） |
| 7 | 删掉 4 处 `_pumpQueue()` 之外的队列逻辑 | 见批次 2 记录 |

**变异 2 / 5 / 6 首轮全部存活**，是这轮最重要的发现：

- 变异 2 说明「点同一个排序字段 ⇒ 反向」这条分支没有测试守着
  （原测试只走了「选不同字段」和显式的 asc/desc 菜单项）。
  补测后断言 `setSortCalls` 依次收到
  `{name,false} → {name,true} → {name,false}`，把这个交互最容易写错的地方守住了。
- 变异 5 / 6 说明 Group 6 原来**只断言按钮存在 + 能开弹窗**，
  完全没有断言它被放在了用户指定的位置。补测后断言
  `getCenter(palette).dx < getCenter(server).dx`、
  `getRect(palette).right <= getRect(server).left`，以及
  `gap ∈ [0,5]`（两者之间只允许一个 `SizedBox(width:4)`）。
  agy 另外补了「中屏模式（800×600）无 inspector 但仍紧邻」这条用例。

**变异 5 / 6 的变异形式很关键**：我第一版反例往 `actions` 里插了 400px 占位，
导致 RenderFlex overflow，测试红了 `-11` —— 那是**布局崩溃**不是位置断言起作用，
属于假抓。位置变异必须保持元素都存在、都能点、不溢出，只改相对顺序。

**我自己的预判也错过一次**：我原以为「删掉 `setThemeMode` 调用」会全绿
（理由是测试只 `container.read(settingsProvider)`），实际它会红 ——
agy 原本就断到了 provider 的最终值。我基于错误预判派了一条不必补的活，
agy 照做后我复核才发现。教训：派「补测试」brief 前先自己把变异跑一遍。

### 门禁输出

```text
dart format --set-exit-if-changed .  →  Formatted 136 files (0 changed)
flutter analyze                      →  No issues found! (ran in 1.2s)
flutter test -j 1                    →  00:37 +539: All tests passed!
ARB                                  →  en=369 zh=369，双向差集均为空
```

基线 535（批次 1 开工时）→ **539**，无回归。release APK 见批次 2 记录。
