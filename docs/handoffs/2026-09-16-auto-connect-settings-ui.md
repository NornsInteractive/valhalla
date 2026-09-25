# Valhalla UI Handoff — 设置页「启动自动连接」二选一（切片 B of 3）

后端契约与业务逻辑**已经实现并测试完毕**。本切片只包含**界面层**工作。
**不要改 `lib/core/`**。

> 本轮共三个切片，本文件是 **B**：
> - A 远程文件页：下载入口 + 打开前格式判断 → `2026-09-16-sftp-file-open-download-ui.md`
> - **B（本文件）** 设置页「启动自动连接」二选一
> - C 顶部布局重排 → `2026-09-16-top-layout-drawer-ui.md`
>
> **只做 B**。A / C 由别人负责。

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

## Allowed files

- `lib/features/settings/settings_view.dart`（主要）
- `lib/widgets/**`、`lib/app/**`
- `lib/l10n/**`（只需新增本文件第 4 节列出的 key）
- `test/features/**`

**不要修改** `lib/core/`、`lib/data/`、`lib/infrastructure/`、`pubspec.yaml`，
**也不要动 `lib/features/files/` 和 `lib/features/shell/`**（那是 A / C 的范围）。

所有用户可见字符串必须同时写入 `app_en.arb` 与 `app_zh.arb`。
**绝不要 `git checkout` 这两个文件**（`app_zh.arb` 有大量未提交译文），只做增量编辑。
改完立刻跑 `flutter test -j 1 test/core/l10n_key_parity_test.dart`
（当前 en/zh 都是 345 个 key，你新增多少就要两边各加多少）。

---

## 1. 功能语义（用户要什么）

启动 App 时自动连接一个 SSH 配置。**两个选项二选一**：

| 选项 | 语义 |
|---|---|
| `fixed`（固定默认SSH） | 用户在设置里**指定**一个配置，每次启动都连它 |
| `lastConnected`（记住最后一次连接） | 自动记录最近一次**成功**连接的配置，启动时连它 |

**默认选中 `lastConnected`**，后端已经是这个默认值，你不需要初始化。

---

## 2. 后端已就绪（直接用，别重写）

```dart
// lib/core/providers/auto_connect_provider.dart

enum AutoConnectMode { fixed, lastConnected }

class AutoConnectSettings {
  final AutoConnectMode mode;        // 默认 lastConnected
  final String? fixedServerId;       // 仅 fixed 模式有意义
}

final autoConnectSettingsProvider =
    NotifierProvider<AutoConnectSettingsNotifier, AutoConnectSettings>(...);

// notifier 上的两个 setter：
Future<void> setMode(AutoConnectMode mode);
Future<void> setFixedServerId(String? id);   // 传 null = 取消指定
```

> **读取用 `ref.read`，不要 `ref.watch`。**
> 理由与同文件的 `terminalSettingsProvider` 一致：写设置会重建 notifier，
> watch 者会跟着重建。设置页只需要「读一次当前值 + 调 setter」。

服务器列表：

```dart
// lib/core/providers/server_provider.dart
final serverListProvider = ...;   // List<ServerProfile>
// ServerProfile 有 id / name / host
```

### 2.1 后端行为（说明用，**别在 UI 里重复实现**）

- 启动时若 `mode == fixed` 且没指定 id → **不连接**（静默，无提示）。
- 启动时若目标服务器已被删除 → **不连接**（静默）。
- 自动连接失败 → **静默失败**，只由既有的
  `lib/features/shell/widgets/connection_status_banner.dart` 展示状态，
  **不要弹对话框**。

也就是说：设置页**不需要**写任何「校验服务器还在不在」的逻辑。

---

## 3. 界面要求

> ⚠️ **上一次派发这个切片时，文件被改到一半就中断了**：ARB key 已加好，
> 但 `_AutoConnectCard` 只留下一个引用、**类没有定义**，导致全项目编译失败。
> 这一次请**先把类写完再改引用**，不要在文件里留下悬空引用。
> 当前 `settings_view.dart` 里离你最近的一处已标了 `TODO(agy 切片 B)`，
> 请把那段 `SizedBox(height: 32)` 换成你的卡片。
>
> `auto_connect_provider.dart` / `server_provider.dart` / `server_profile.dart`
> 三个 import 我已经预置好（带 `unused_import` 抑制注释），
> 你**把抑制注释删掉**即可，不要重复添加 import。

- 加一张卡片，替换 `settings_view.dart` 里标了 `TODO(agy 切片 B)` 的那个位置
  （在 Security 卡片之后、Reset footer 之前），带分区标题 `settingsAutoConnect`。
  标题的写法照抄同文件其它分区（`_buildSectionTitle`，
  `Icons.power_settings_new` 或你选一个合适的图标）。
- 卡片类名建议 `_AutoConnectCard extends ConsumerWidget`，写在
  `settings_view.dart` 文件末尾（与文件其它私有 widget 的写法一致）。
- 用**两个 `RadioListTile`** 做二选一，直接照抄同文件 Language 卡片
  的写法——那份用的是较老的 `groupValue` + `onChanged` API，文件顶部已有
  `// ignore_for_file: deprecated_member_use`。**不要为此换 API 风格**，
  与邻座保持一致比追新更重要。
  - 选项一：`settingsAutoConnectFixed` / `settingsAutoConnectFixedDesc`
    → `setMode(AutoConnectMode.fixed)`
  - 选项二：`settingsAutoConnectLast` / `settingsAutoConnectLastDesc`
    → `setMode(AutoConnectMode.lastConnected)`
  - `groupValue` 取自 `ref.read(autoConnectSettingsProvider).mode`。
- **只有选中 `fixed` 时**，下方才展开一个服务器选择项（`settingsAutoConnectPickServer`）：
  - 一行 `ListTile` 显示当前 `fixedServerId` 对应的服务器名；
    **尚未指定时**显示 `settingsAutoConnectNoServer`。
  - 点击弹出**已有的**服务器列表让用户选，选中后调 `setFixedServerId(id)`。
    用 `ref.watch(serverListProvider)` 取列表。
  - **列表为空时**不展示这个选择项（没有可选的东西，
    显示一个空选择器只会让人困惑）。
  - 选中的 id 在列表里找不到时（服务器被删了），按「尚未指定」处理，
    **不要**回落到第一台。
- 不需要「取消指定」按钮；用户切回 `lastConnected` 即可。
  但要保证切回来再切回去时**之前选的 id 还在**——后端已经保证不清空
  （`AutoConnectSettings.copyWith` 只在传值时才覆盖），你只要别在 UI 里主动清它。

---

## 4. 需要你新增的 ARB key

**这些 key 上次已经加好了，不要再加一遍**（加了会重复、parity 测试会挂）。
你只需要在代码里用它们：

| key | en | zh |
|---|---|---|
| `settingsAutoConnect` | `Auto connect on launch` | `启动时自动连接` |
| `settingsAutoConnectFixed` | `Fixed default SSH` | `固定默认SSH` |
| `settingsAutoConnectFixedDesc` | `Always connect to the server you pick below` | `每次启动自动连接下方指定的服务器` |
| `settingsAutoConnectLast` | `Remember last connection` | `记住最后一次连接` |
| `settingsAutoConnectLastDesc` | `Connect to the server that was last connected successfully` | `启动时自动连接最近一次成功连接的服务器` |
| `settingsAutoConnectPickServer` | `Server` | `指定服务器` |
| `settingsAutoConnectNoServer` | `No server selected yet` | `尚未指定服务器` |

先用 `grep settingsAutoConnect lib/l10n/app_en.arb` 确认，再动代码。

**已存在、直接复用（不要改名、不要重复添加）**：`navSettings`, `cancel`,
`confirm`, `addServer`。设置页原有的其它 key 也都在。

---

## 5. Constraints

1. Material 3；风格与设置页其它卡片保持一致。
2. 不加新依赖；不改 `lib/core/`、`lib/features/files/`、`lib/features/shell/`。
3. 必须补/改的 widget 测试：
   - 默认选中 `lastConnected`；
   - 点 `fixed` 后 `setMode(AutoConnectMode.fixed)` 被调用，且服务器选择项出现；
   - 未指定时显示 `settingsAutoConnectNoServer`；
   - 选择一台服务器后显示它的名字，且 `setFixedServerId` 被调用；
   - 选 `lastConnected` 时服务器选择项**不**出现；
   - 服务器列表为空时不出现选择项。
4. 跑 `dart format`、`flutter analyze`、`flutter test -j 1`。
   本仓库的测试**必须**带 `-j 1`。
5. **断言要有牙**：写完后把被测逻辑临时改掉（比如把 `ref.read` 换成
   `ref.watch`、或把默认值改成 `fixed`），确认测试**真的会红**，再改回来。

## After you finish

列出改动过的文件。**只做 B**，不要顺手改 A / C 涉及的文件。
