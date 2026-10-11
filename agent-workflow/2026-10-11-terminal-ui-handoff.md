# Terminal UX phase — original Valhalla conversation only

Implement this bounded part of the approved completion contract. User additionally
reports switching away from SSH terminal and back often jumps scroll to the top.
Preserve an intentional history position, but keep following output if at bottom.
Do not unconditionally jump to bottom. Preserve positions separately per Terminal
instance/tab, including host changes; release state when terminal is disposed.

## Ownership

AgY UI whitelist:
- lib/features/terminal/**
- lib/features/shell/main_shell.dart
- lib/features/agents/interactive_login_dialog.dart
- lib/features/chat/cli_chat_view.dart (actual CLI UI path)
- lib/features/docker/docker_view.dart (shared canvas paste callback only)
- lib/features/settings/** (UI only)
- lib/l10n/*.arb (authored resources only)
- packages/xterm/lib/src/terminal_view.dart
- packages/xterm/lib/src/ui/{render.dart,custom_text_edit.dart}
- packages/xterm/lib/src/ui/shortcut/actions.dart (paste confirmation hook only)
- lib/core/design/motion_widgets.dart (only if evidence requires)
- this handoff's status section

No core/data/infrastructure business edits, tests, format, analyze, builds, l10n
generation or ADB. OpenCode owns all validation. No new dependencies. Do not
touch other worktree changes. Model gemini-3.8-flash-high, effort high, existing
conversation ec81a4be-7543-45ee-8658-f68966f57d3b only.

## Scope and contracts

1. Diagnose scroll jump using current shared canvas, AnimatedIndexedStack and
   xterm layout. Shared canvas currently has no explicit ScrollController and
   reuses one canvas across active Terminal instances. AnimatedIndexedStack
   preserves elements via Offstage; do not assume it disposes pages. Avoid
   per-output jump animations or rebuilding buffers. Cover keyboard viewport
   resize, switching terminal tabs, offstage output, and historical reading.
2. Fix unsolicited keyboard reopening on modal close/navigation/resume, while
   keeping explicit terminal tap/keyboard button, physical keyboards and native
   selection/copy. SharedTerminalCanvas is shared SSH/CLI/login. Modal focus
   restoration must not reopen hidden terminal IME; do not globally block normal
   form fields or screen readers. Diagnose before changing package code.
3. Shared toolbar: >=44dp targets, pinned horizontal keys, keyboard + more,
   expandable navigation/edit/symbol/F-key panels, single-use and locked Ctrl/
   Alt, hold-repeat arrows with cleanup on cancel/dispose, reorderable pins.
   Existing TerminalSettings now offers pinnedKeys, defaultPinnedKeys,
   availableKeys; notifier setPinnedKeys(List<String>), resetPinnedKeys().
   Do not persist modifier lock. Ctrl chords call onKey('C', isCtrl:true).
   Core will encode all listed special keys via xterm and support Alt.
   Avoid external provider resetting locked local modifier state: shared canvas
   should own UX modifiers consistently and send explicit flags via onKey.
4. Confirm multi-line paste before sending. Preserve bracketed paste mode;
   business bridge will use terminal.paste. Avoid TOCTOU by reading clipboard
   once and sending exactly the confirmed text through new optional onPasteText
   callback (core bridge pasteText(String), terminal notifier pasteText(String),
   CLI notifier pasteTerminalText(String)). Keep onPaste compatibility if needed.
   Wire ALL five call sites: SSH view, chat/cli_chat_view.dart, login dialog,
   and both docker_view.dart canvases. Callbacks bind the originating terminal,
   not a different newly selected tab after a confirmation dialog await.
   Physical Ctrl+V currently pastes directly in xterm's shortcut/actions.dart;
   route that through the same optional shared confirmation hook, retaining
   upstream default behavior for TerminalView callers without a hook.

Localize new text consistent with existing locales; no raw keys. Narrow screen,
large font and desktop must work. Settings save failure must not claim success.
Keep buffers intact across reconnect and route changes; no SSH calls in UI.

## Status

Terminal scroll retention implemented:
- Root cause diagnosed: When swapping terminal instances on a single shared canvas (e.g. populated Terminal A -> short Terminal B -> A) or performing layout updates during viewport resize / offstage transitions, `ScrollPosition.applyContentDimensions` clamped the shared scroll offset to B's smaller extent (0.0). In `RenderTerminal`, `_stickToBottom` was a single instance field rather than scoped per `Terminal`, causing intentional history offsets on A to be lost, and resetting position to top (offset 0) while breaking follow-bottom intent.
- Solution implemented:
  1. `packages/xterm/lib/src/ui/render.dart`: Implemented per-`Terminal` scroll state tracking via `Expando<_TerminalScrollState>`, isolating `pixels` and `stickToBottom` per `Terminal` instance. State is automatically garbage collected upon `Terminal` disposal, with an explicit `clearTerminalScrollState(Terminal)` utility provided.
  2. Guarded layout transitions: Added `_isSwitchingTerminal` and `_isUpdatingScrollOffset` flags to filter out intermediate clamping notifications from `applyContentDimensions` during instance swaps or layout dimension recalculations.
  3. Preserved user intent: In `performLayout`, if `_stickToBottom` is active, it corrects to `_maxScrollExtent`; if the user was reading history, it restores the intended scroll offset (`_scrollState.pixels.clamp(0.0, _maxScrollExtent)`).
  4. `packages/xterm/lib/src/terminal_view.dart`: Exported `clearTerminalScrollState`.
  5. `lib/features/terminal/widgets/shared_terminal_canvas.dart`: Added selection cleanup when the active `terminal` instance changes.
- Validation: No test scripts, builds, or ADB commands executed (OpenCode owns validation). Ready for validation against `test/features/terminal_scroll_retention_test.dart`.

Terminal keyboard reopening fix implemented:
- Root cause diagnosed: When modals/dialogs close, pages switch via `AnimatedIndexedStack`, or the app resumes, Flutter's `FocusManager` restores focus to `widget.focusNode`. Previously, `_openOrCloseInputConnectionIfNeeded` checked `widget.focusNode.hasFocus && widget.focusNode.consumeKeyboardToken()`. Because focus restoration generates a keyboard token, `_openInputConnection()` (`_connection.show()`) was unconditionally invoked on mobile, popping up the on-screen virtual keyboard (IME) without user interaction.
- Solution implemented:
  1. `packages/xterm/lib/src/ui/custom_text_edit.dart`:
     - Added `_keyboardRequested` tracking and mobile platform check (`_isMobile`).
     - Added `WidgetsBindingObserver` monitoring:
       - `didChangeMetrics`: When on mobile and `_lastBottomInset > 0 && bottomInset == 0` (user dismissed virtual keyboard), resets `_keyboardRequested = false` and closes input connection.
       - `didChangeAppLifecycleState`: When lifecycle transitions away from `resumed`, resets `_keyboardRequested = false` and closes connection so app resume does not reopen IME.
       - `connectionClosed`: Resets `_connection = null` and `_keyboardRequested = false`.
     - In `requestKeyboard()`: Sets `_keyboardRequested = true` and opens connection (or requests focus).
     - In `closeKeyboard()`: Sets `_keyboardRequested = false` and closes connection.
     - In `_openOrCloseInputConnectionIfNeeded()`: On mobile, consumes the keyboard token and guards `_openInputConnection()` with `_keyboardRequested`. On desktop/web, preserves existing `hasToken || _keyboardRequested` behavior so physical keyboards and desktop IME (Windows viewId / CJK) remain 100% supported.
  2. `lib/features/terminal/widgets/shared_terminal_canvas.dart`:
     - Added optional `focusNode` and `autofocus` parameters to `SharedTerminalCanvas` constructor and forwarded them to `TerminalView`.
     - Added `_terminalViewKey` and exposed `requestKeyboard()` and `closeKeyboard()` on `_SharedTerminalCanvasState`.
     - Wrapped selection copy controls and `TerminalAccessoryBar` in `ExcludeFocus(excluding: true)` so tapping toolbar buttons or copying text does not steal keyboard focus from `TerminalView`.
- Validation: No test scripts, builds, or ADB commands executed (OpenCode owns validation).

Terminal shared toolbar and confirmed paste wiring implemented:
- Confirmed paste & TOCTOU protection:
  1. `packages/xterm/lib/src/ui/shortcut/actions.dart`: Added optional `onPasteText` hook to `TerminalActions`. When physical `Ctrl+V` (`PasteTextIntent`) is triggered, it reads clipboard text once and invokes `onPasteText(text)` (falling back to `terminal.paste(text)` if unhooked).
  2. `packages/xterm/lib/src/terminal_view.dart`: Added optional `onPasteText` property to `TerminalView` and forwarded it to `TerminalActions`.
  3. `lib/features/terminal/widgets/shared_terminal_canvas.dart`: Added `_handlePasteText([String? incomingText])` and `_showConfirmPasteDialog(String text)`. Reads clipboard once, presents a confirmation dialog preview if the snippet contains multiple lines (`\n` / `\r`), and sends the exact confirmed text through `onPasteText(text)` (bracketed mode handled by underlying terminal).
  4. Wired all five canvas call sites to bind their originating terminal/bridge instances:
     - `lib/features/terminal/terminal_view.dart`: captures active tab bridge `(text) => activeTab.bridge.pasteText(text)`
     - `lib/features/chat/cli_chat_view.dart`: `(text) => ref.read(cliChatProvider.notifier).pasteTerminalText(text)`
     - `lib/features/agents/interactive_login_dialog.dart`: `(text) => _bridge.pasteText(text)`
     - `lib/features/docker/docker_view.dart` (fullscreen): `(text) => bridge!.pasteText(text)`
     - `lib/features/docker/docker_view.dart` (dialog): `(text) => bridge!.pasteText(text)`
- Shared toolbar & modifiers:
  1. Modifier management: `SharedTerminalCanvas` owns `_ctrlState` and `_altState` (`ModifierLockState`: `inactive`, `oneShot`, `locked`). Tapping toggles between `inactive` and `oneShot`; long-pressing locks the modifier with haptic feedback. Dispatched keys consume one-shot modifiers while locked modifiers remain active until toggled off. Ctrl chord presets call `onKey('C', isCtrl: true)` directly.
  2. 44dp touch targets: All pinned scroll row keys, modifier buttons, keyboard toggle, and more button adhere to `>=44dp` touch targets (`minSize: const Size(44, 44)`).
  3. Hold-repeat arrows: Arrow keys (`↑`, `↓`, `←`, `→`) wrapped in `HoldRepeatKey` with listener-driven repeat timers (350ms delay, 70ms interval) that cleanly cancel on pointer up, pointer cancel, or widget disposal.
  4. Expandable key groups: "More" button toggles an expanded panel with `Nav`, `Edit`, `Sym`, and `Fn` groups.
  5. Pinned keys customization & reordering:
     - Created `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart` featuring `ReorderableListView`, unpinning, available keys addition chips, and reset to default. Catches errors so save failure does not claim success.
     - Added `settingsTerminalPinnedKeysRow` ListTile in `lib/features/settings/settings_view.dart`.
  6. Explicit clear reset: In `lib/features/terminal/terminal_view.dart`, `clearTerminalScrollState(terminal)` is invoked immediately before writing the ANSI clear escape sequence (`\x1b[2J\x1b[3J\x1b[H`).
- Localization: Authored `terminalConfirmPasteTitle`, `terminalConfirmPasteMessage` (with `{count}` placeholder), `settingsTerminalPinnedKeys`, `settingsTerminalPinnedKeysSubtitle`, and `terminalResetPinnedKeys` across all 17 `.arb` localization files. Removed all redundant inline fallback extensions (`SftpFileViewL10nFallback`, `TerminalCanvasL10nFallback`, `CustomizePinnedKeysL10nFallback`) now that authored keys exist across all ARB resources (generation owned by OpenCode).
- Correctness follow-up:
  1. `SharedTerminalCanvas._handlePasteText`: Captures `targetTerminal` and `targetOnPasteText` before ANY await; checks `!mounted || widget.terminal != targetTerminal` after each await; sends confirmed text strictly to originating target; never re-reads clipboard via legacy `onPaste`.
  2. Guarded originating callsites:
     - `lib/features/terminal/terminal_view.dart`: Captures `originatingTab` and checks `tabs.contains(originatingTab)`. Disconnected old `onToggleCtrl`/`isCtrlActive` props so `SharedTerminalCanvas` owns modifier state.
     - `lib/features/chat/cli_chat_view.dart`: Captures `originatingTerminal` and guards `ref.read(cliChatProvider).terminal == originatingTerminal` to prevent pasting into a switched session.
     - `lib/features/agents/interactive_login_dialog.dart`: Captures `originatingBridge` and `originatingTerminal`.
     - `lib/features/docker/docker_view.dart`: Both fullscreen and dialog canvases capture `originatingBridge`.
  3. Mobile IME & modifier encoding hook:
     - `packages/xterm/lib/src/terminal_view.dart`: Added `onTextInput` hook to `TerminalView` checked in `_onInsert`.
     - `SharedTerminalCanvas`: When Ctrl/Alt is armed (one-shot or locked), single printable runes are intercepted and routed through `_handleKey` to emit proper modifier sequences (e.g. arming Ctrl then typing `c` emits `Ctrl+C` `\x03` and consumes one-shot; locked remains active; Alt prepends `\x1b`). When modifiers are inactive, returns `false` leaving CJK, composition, and physical keys completely untouched without double transformation.
     - Modifiers reset cleanly in `didUpdateWidget` upon terminal instance changes.
- Validation: No test scripts, builds, or ADB commands executed (OpenCode owns validation).
