# Valhalla UI Handoff — tmux 改为 opt-in（设置开关 + 缺 tmux 询问安装）

本 brief 取代 `2026-09-15-connection-tmux-install-ui.md` 里关于 tmux 的部分。
**上一版有一个已被后端修正的错误前提，务必读第 2 节。**

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

## Allowed files

- `lib/features/**`
- `lib/widgets/**`
- `lib/app/**`
- `lib/l10n/**`
- UI-specific tests under `test/features/**`

Do not modify `lib/core/`, `lib/data/`, `lib/infrastructure/`, `pubspec.yaml`, or non-UI tests.

You must author every user-visible string yourself in both `app_en.arb` and `app_zh.arb`.
Do not leave English-only or Chinese-only keys. Do not hardcode UI text in Dart.

> **ARB 是雷区**：`app_zh.arb` 里有大量未提交译文。**绝不要 `git checkout` 这两个文件**，
> 只做增量编辑。改完立刻跑 `flutter test -j 1 test/core/l10n_key_parity_test.dart`。

---

## 1. 要做的事

用户已拍板 tmux 的终态是 **opt-in**：

- 默认走**普通 SSH PTY**，终端立刻可用。
- 设置页有一个**开关**控制是否用 tmux 保活，**跨重启持久化**。
- 开关打开后连远端，**先检查**远端有没有 tmux；没有就**弹框询问是否安装**。
- 用户拒绝 → 继续用普通 PTY。

### 1.1 设置页开关（新）

数据源（我已在后端实现好，签名稳定）：

```dart
// lib/core/providers/terminal_settings_provider.dart
class TerminalSettings {
  final bool useTmux;   // 默认 false
}

final terminalSettingsProvider =
    NotifierProvider<TerminalSettingsNotifier, TerminalSettings>(...);

// 读
ref.watch(terminalSettingsProvider).useTmux
// 写
await ref.read(terminalSettingsProvider.notifier).setUseTmux(value);
```

- 位置自定，建议放在 `settings_view.dart` 的安全卡（`_buildSecurityCard`）里，
  或新起一个「终端」分组；用 `SwitchListTile` 即可。
- 需要**新写 3 个 ARB key**（我已加好，en/zh 都是 345 个 key，你只负责在 UI 上用）：

| key | en（已写入 ARB，zh 也已写入） |
|---|---|
| `settingsTerminalUseTmux` | `Persistent Sessions (tmux)` |
| `settingsTerminalUseTmuxSubtitle` | `Run terminal sessions inside tmux on the remote server` |
| `settingsTerminalUseTmuxDescription` | `Keeps your terminal output after a disconnect. Requires tmux on the remote server. Changes apply to newly opened terminal tabs.` |

> 这 3 个 key **已经由我在两个 ARB 里建好了**（含中文），你直接用 `context.l10n.xxx` 即可，
> 不要重复添加、不要改名。

- **开关只对之后新建的标签页生效**，已在运行的标签页不会被重建。
  这一点已经写在 `settingsTerminalUseTmuxDescription` 的文案里，UI 上不必再解释一遍。

### 1.2 缺 tmux 的询问框（语义已变，必须改）

后端已改：**缺 tmux 时不再停住等用户决定，而是先开好一个普通 PTY，再弹询问框。**

`lib/infrastructure/terminal/terminal_session_bridge.dart` 现在的状态机：

| 场景 | `mode` | `state` | `awaitingTmuxDecision` | PTY |
|---|---|---|---|---|
| 有 tmux + 开关开 | `tmux` | `connected` | false | 有 |
| 开关关 | `plain` | `connected` | false | 有 |
| **缺 tmux + 开关开** | `tmuxUnavailable` | **`connected`** | **true** | **有（普通）** |
| 探测抛异常 | `tmuxUnavailable` | `connected` | true | 有（普通） |
| 用户拒绝安装 | `tmuxUnavailable` | `connected` | false | 有（普通） |

**⚠️ 上一版 brief 说 `tmuxInstallOffer != null` 意味着「PTY 还没开」，这是错的。**
现在 `awaitingTmuxDecision == true` 表示「**终端已经连上、可以用**，只是在问你要不要装 tmux」。
所以：

- **文案不要写成「未连接」或「终端不可用」**，那会吓到用户。
- `terminal_view.dart` 目前把安装询问做成了**全屏 overlay 挡住整个终端**（`build()` 里的 `Stack`，
  `tmuxInstallOffer != null` 时铺满）。改成**非阻塞**呈现：终端要能看见、能操作，
  询问框以卡片 / 底部弹层 / 非模态面板的形式叠加即可。用户答完再收起。
- 询问仍只能由 **Skip / Install** 两个按钮结束，**不要加 barrier dismiss 或右上角关闭按钮** ——
  否则会留下「既没决定、也没提示」的中间态。
- 用户点 Skip 后 `awaitingTmuxDecision` 变 false、`tmuxInstallOffer` 变 null，
  此后可以显示已有的非阻塞提示条 `terminalTmuxMissingNotice`（显示条件不变）。

其余后端契约保持稳定：

```dart
class TmuxInstallOffer {
  final String? installCommand; // null = 认不出包管理器
  final bool isInstalling;
  final String? errorCode;      // TMUX_INSTALL_UNSUPPORTED | TMUX_INSTALL_FAILED | SSH_DISCONNECTED
}

class SshTerminalState {
  final TmuxInstallOffer? tmuxInstallOffer;
}

TerminalNotifier.skipTmuxInstall()
TerminalNotifier.confirmTmuxInstall()
```

- 绝不自动安装；`installCommand` 非空时原样展示给用户。
- 安装命令是**后台探测**的：弹框刚出现时 `installCommand` 可能还是 null（探测未回），
  稍后 bridge 会推一次状态更新。请让 UI 能响应这个「命令稍后到位」的变化，
  不要在 null 时就立刻断言「不支持」——只有 `errorCode == TMUX_INSTALL_UNSUPPORTED` 才是真不支持。

### 1.3 已有连接状态部分（保持不变）

`reconnectControllerProvider` 横幅、`sshKeepAliveNotificationTitle/Body` 说明、
ACP 会话恢复提示（`AiChatState.acpSessionRestored` / `acpSessionRestartDetected` +
`acknowledgeAcpSessionRestart()`，用 `acpSessionRestored` / `acpSessionRestartNotice`）都已完成，不要回退。

## 2. Frozen existing keys (reuse, do not rename)

`terminalTmuxMissingNotice`, `terminalTmuxSessionRestored`,
`terminalTmuxInstallDialogTitle`, `terminalTmuxInstallDialogMessage`,
`terminalTmuxInstallCommandLabel`, `terminalTmuxInstallUnsupported`,
`terminalTmuxInstallFailed`, `terminalTmuxInstallDisconnected`,
`terminalTmuxInstallInstalling`, `terminalTmuxInstallConfirm`, `terminalTmuxInstallSkip`,
`sshStatusReconnecting`, `sshStatusReconnected`, `sshStatusDisconnectedRetrying`,
`sshStatusDisconnectedManual`, `sshStatusHostKeyChanged`,
`sshKeepAliveNotificationTitle`, `sshKeepAliveNotificationBody`,
`acpSessionRestored`, `acpSessionRestartNotice`,
`settingsTerminalUseTmux`, `settingsTerminalUseTmuxSubtitle`, `settingsTerminalUseTmuxDescription`.

## 3. Constraints

1. Material 3 only. Compact `<600` NavigationBar, medium `600–1024` collapsed rail, expanded `>1024` rail + inspector.
2. No fake remote data. No edits outside allowed files.
3. Widget tests to add/update:
   - 设置开关渲染并把新值传给 `setUseTmux`；
   - 安装询问出现时**终端仍可见/可交互**（不再是全屏遮挡）；
   - Skip 调 `skipTmuxInstall`、Install 调 `confirmTmuxInstall`；
   - `awaitingTmuxDecision == true` 时文案里不出现「未连接 / disconnected」这类误导说法。
4. Run `dart format`, `flutter analyze`, and the UI tests you add. Tests must be run as `flutter test -j 1`.

## After you finish

List modified files. Do not touch core/data/infrastructure.
