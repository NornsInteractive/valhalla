# Valhalla UI Handoff — 连接状态与 tmux 安装询问

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

You must author every user-visible string yourself in both `app_en.arb` and `app_zh.arb`. Do not leave English-only or Chinese-only keys. Do not hardcode UI text in Dart.

## Backend contracts (do not change signatures)

### 1. tmux 安装询问 — `lib/core/providers/terminal_provider.dart`

```dart
class TmuxInstallOffer {
  final String? installCommand; // null = no known package manager
  final bool isInstalling;
  final String? errorCode;      // stable code, map in UI
}

class SshTerminalState {
  final TmuxInstallOffer? tmuxInstallOffer;
}

TerminalNotifier.skipTmuxInstall()
TerminalNotifier.confirmTmuxInstall()
```

- `tmuxInstallOffer != null` means the remote has no tmux and the PTY has **not** been opened yet. You must ask the user whether to install.
- Confirm → `confirmTmuxInstall()`. Skip → `skipTmuxInstall()` (plain SSH, no tmux).
- Never install without confirmation. Never invent a command; show `installCommand` when non-null.
- `errorCode` values: `TMUX_INSTALL_UNSUPPORTED`, `TMUX_INSTALL_FAILED`, `SSH_DISCONNECTED`.
- `bridge.awaitingTmuxDecision` / `bridge.mode == tmuxUnavailable` while the offer is present: do **not** treat this as the old “dismissible missing tmux notice while a shell is already open”. The old notice is only valid after the user already skipped and you still want a non-blocking hint — prefer the confirm dialog for the pending offer.
- After skip, `tmuxInstallOffer` becomes null and mode is `plain`.

### 2. 连接状态（已有，补齐未接线的展示）

- `reconnectControllerProvider` / `ReconnectState` — banner in `MainShell` already exists; keep it.
- Settings: explain the persistent notification using existing keys `sshKeepAliveNotificationTitle` / `sshKeepAliveNotificationBody`, and show `keepAliveCoordinatorProvider.activeCount` when `hasActiveSessions`.
- Chat: `AiChatState.acpSessionRestored` / `acpSessionRestartDetected` + `acknowledgeAcpSessionRestart()`. Use existing keys `acpSessionRestored` / `acpSessionRestartNotice`. Restart notice must require explicit dismiss. Do not silently hide context loss.

### 3. Frozen existing keys (reuse, do not rename)

`sshStatusReconnecting`, `sshStatusReconnected`, `sshStatusDisconnectedRetrying`, `sshStatusDisconnectedManual`, `sshStatusHostKeyChanged`, `sshKeepAliveNotificationTitle`, `sshKeepAliveNotificationBody`, `terminalTmuxMissingNotice`, `terminalTmuxSessionRestored`, `acpSessionRestored`, `acpSessionRestartNotice`.

New copy for the install dialog needs **new** ARB keys that you create.

## Constraints

1. Material 3 only. Compact `<600` NavigationBar, medium `600–1024` collapsed rail, expanded `>1024` rail + inspector.
2. No fake remote data. No edits outside allowed files.
3. Widget tests: install offer shown when `tmuxInstallOffer` is set; confirm calls `confirmTmuxInstall`; skip calls `skipTmuxInstall`; ACP restart notice requires confirm; reconnect banner still degrades when provider is null.
4. Run `dart format`, `flutter analyze`, and the UI tests you add.

## After you finish

List modified files. Do not touch core/data/infrastructure.
