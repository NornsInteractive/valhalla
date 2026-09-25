# Valhalla UI Handoff — 连接稳定性状态提示

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
workspace: /workspace/projects/valhalla
```

## Allowed files

- `lib/features/**`
- `lib/widgets/**`
- `lib/app/**`
- UI-specific tests

Do not modify `core/`, `data/`, `infrastructure/`, `pubspec.yaml` or non-UI tests.

## 背景

后端已完成 SSH / ACP 断线稳定性改造。用户的原始诉求是：

> 现在 ssh 连接一点都不稳定，很容易就断开了，需要保证 app 没有退出时，ssh 和 acp 都要稳定连接。

后端现在会：保持前台服务常驻、心跳探测半开连接、掉线后按 1s→30s 退避自动重连、用 tmux 承载终端会话、用 `session/load` / `session/resume` 恢复 ACP 会话。

**后端已经把这些状态全部暴露出来了，但界面上目前完全没有呈现。** 因此用户会看到「连接悄悄断了又悄悄好了」，或者「终端卡死不响应」却不知道原因。本次 handoff 只做状态呈现，不改任何后端契约。

## 你必须使用的现成 API

这些都已经存在并且有测试覆盖，**不要修改它们的签名**。

### 1. 重连状态（`lib/core/providers/reconnect_provider.dart`）

```dart
final reconnectControllerProvider = Provider<ReconnectController?>;
// 返回 null 表示自动重连未启用（测试 / 未初始化环境）。
// 生产环境由 main.dart 覆盖 reconnectEnabledProvider 后非 null。

final reconnectEnabledProvider = Provider<bool>;   // 默认 false
```

`ReconnectController` 的公开成员：

```dart
ReconnectState get state;      // 当前状态
String? get serverId;          // 当前受管的服务器，null 表示无
bool get userIntent;           // 用户是否主动想连接（区分「用户点了断开」）
bool get isPending;            // 是否已排定下一次重试
```

`ReconnectState`（`lib/core/utils/reconnect_backoff.dart`）：

```dart
final ReconnectStatus status;   // idle | connecting | connected | reconnecting | failed
final int attempt;              // 已重试次数
final Duration? nextDelay;      // 下一次重试倒计时
final String? errorMessage;     // 最近一次失败原因（原始文本，仅用于诊断展示）
final bool retryable;           // false = 不会再重试

bool get isConnected;           // status == connected
bool get isReconnecting;        // status == reconnecting
bool get isBusy;                // connecting || reconnecting
```

### 2. 前台服务（`lib/core/providers/reconnect_provider.dart`）

```dart
final keepAliveCoordinatorProvider = Provider<KeepAliveCoordinator>;

class KeepAliveCoordinator {
  int get activeCount;            // 活跃连接数
  bool get hasActiveSessions;
}
```

### 3. 终端会话模式（`lib/infrastructure/terminal/terminal_session_bridge.dart`）

```dart
enum TerminalSessionMode { plain, tmux, tmuxUnavailable }

class TerminalSessionBridge {
  TerminalSessionMode get mode;
}
```

- `tmux`：会话由 tmux 承载，断线重连后能恢复。
- `tmuxUnavailable`：用户想要 tmux 但远端没装 → **必须提示，但绝不自动安装**。
- `plain`：用户主动关掉了 tmux，**不要提示**。

### 4. ACP 会话恢复（`lib/infrastructure/acp/acp_client_adapter.dart`）

```dart
String? get sessionId;                  // 当前会话 id
bool get restoredExistingSession;       // true = 复用了历史会话
```

`restoredExistingSession == false` 且此前存在过会话 id 时，代表远端进程是新建的，**之前的上下文已经丢失**，界面必须如实说明，不能假装无事发生。

### 5. 已冻结的 l10n key（`lib/l10n/app_en.arb` / `app_zh.arb`，均已生成）

**这些 key 已经加好并跑了 `flutter gen-l10n`，直接用 `AppLocalizations.of(context)!.xxx` 即可，不要新增、改名或删除。**

| key | 说明 | 占位符 |
| --- | --- | --- |
| `sshStatusReconnecting` | 重连中 | `{n}` int — 第几次尝试 |
| `sshStatusReconnected` | 重连成功 | — |
| `sshStatusDisconnectedRetrying` | 掉线后自动重试中 | — |
| `sshStatusDisconnectedManual` | 用户主动断开 | — |
| `sshStatusHostKeyChanged` | 主机密钥变更导致拒连 | — |
| `sshKeepAliveNotificationTitle` | 通知标题 | — |
| `sshKeepAliveNotificationBody` | 通知正文 | `{n}` int — 活跃会话数 |
| `terminalTmuxMissingNotice` | 远端缺少 tmux | — |
| `terminalTmuxSessionRestored` | 终端会话已恢复 | — |
| `acpSessionRestored` | Agent 会话已恢复 | — |
| `acpSessionRestartNotice` | Agent 会话已重启，上下文丢失 | — |

> 通知栏文案（`sshKeepAliveNotificationTitle` / `sshKeepAliveNotificationBody`）由 Android 原生侧渲染，原生侧已自带 `res/values` 与 `res/values-zh` 的字符串。**这两个 key 在 Dart 侧无需用于通知本身**，仅用于界面上解释「为什么有一个常驻通知」的说明文案。

## 需要你实现的 UI

### 1. 连接状态横幅（主要工作）

在 `MainShell`（`lib/features/shell/main_shell.dart`）里加一条横幅，位置在内容区顶部、导航之下。各状态映射：

| `ReconnectState` | 展示 |
| --- | --- |
| `idle` / `connected` 且刚恢复 | 不显示；若刚从 `reconnecting` 转为 `connected`，短暂显示 `sshStatusReconnected`（约 2 秒后自动消失） |
| `connecting` | 不显示横幅（属于正常首次连接，进度由各页面自己表达） |
| `reconnecting` | `sshStatusReconnecting(n: attempt)`，并显示 `nextDelay` 倒计时 |
| `failed && !retryable` | `sshStatusHostKeyChanged`，**常驻不可消失**，并提供「重新校验主机密钥」入口 |
| 用户主动断开 | `sshStatusDisconnectedManual`，**常驻**，不自动消失 |
| 掉线但处于重试间隙 | `sshStatusDisconnectedRetrying` |

要求：

- 横幅是**非模态**的，不能挡住终端输入，不能抢焦点。
- 不同状态用不同的语义色（重连中 = 警告色，恢复 = 成功色，密钥变更 / 主动断开 = 中性或错误色），并给出对应的语义图标。不要只靠颜色区分。
- 重连倒计时要走秒，不要每 100ms 重建整棵子树 — 把倒计时隔离到独立的小 widget 里。
- `reconnectControllerProvider` 返回 `null` 时必须整体退化为「不显示任何横幅」，而不是抛异常。这是测试环境的常态路径。

### 2. 常驻通知的说明入口

在设置页（`lib/features/settings/settings_view.dart`）增加一项：说明「为保证后台连接稳定，应用会显示一条常驻通知」，并在 `keepAliveCoordinator.hasActiveSessions` 为真时显示当前活跃连接数。文案复用 `sshKeepAliveNotificationTitle` 与 `sshKeepAliveNotificationBody`。

同时给用户一个「自动重连」开关（读写 `reconnectEnabledProvider` 的覆盖值）。**默认必须是开启**，因为用户的诉求就是「app 没退出就要一直连着」。

### 3. 终端 tmux 提示

在 `lib/features/terminal/terminal_view.dart`：

- `bridge.mode == TerminalSessionMode.tmuxUnavailable` 时，显示一条**不阻塞输入**的提示条：`terminalTmuxMissingNotice`。文案要传达「可以继续用，但断线后会话保不住」，并提供一个可关闭按钮（关闭后本次会话内不再提示）。
- `bridge.mode == TerminalSessionMode.tmux` 且连接刚刚重连成功时，显示 `terminalTmuxSessionRestored`。
- `mode == plain` 时**不显示任何 tmux 相关提示**。

### 4. ACP 会话提示

在 `lib/features/chat/ai_chat_view.dart`：

- `adapter.restoredExistingSession == true` 时显示 `acpSessionRestored`。
- 连接重建后 `restoredExistingSession == false` 时，显示 `acpSessionRestartNotice`，**必须显式告知上下文丢失**，不要静默。这条提示需要用户手动确认后消失。

## 硬性约束

1. **所有面向用户的字符串必须走 `AppLocalizations`**，en/zh 必须都覆盖。`test/core/l10n_key_parity_test.dart` 会强制校验 key 对齐。
2. 本次 **不新增任何 ARB key**。上表 11 个 key 已冻结，若你认为确实缺少某个文案，先停下来反馈，不要自行添加。
3. 不得在 `lib/core/` 里 import `lib/features/`（分层约束），反向亦然 — 你只消费 provider，不修改它们。
4. 不得为了让界面好看而伪造后端状态（例如本地假造一个「已连接」）。所有状态必须来自上述 provider。
5. 保持既有 Stitch 视觉语言与响应式断点：compact `<600dp` 用 `NavigationBar`，medium `600–1024dp` 折叠 `NavigationRail`，expanded `>1024dp` 用 `NavigationRail` + inspector。
6. 为以下路径补 Widget test：重连横幅的四种渲染、`provider == null` 时的降级、tmux 缺失提示可关闭、ACP 重启提示需确认。

## 完成后

告知我你改了哪些文件，我会跑 `dart format`、`flutter analyze`、`flutter test -j 1` 与 `flutter build apk --release` 做验收。
