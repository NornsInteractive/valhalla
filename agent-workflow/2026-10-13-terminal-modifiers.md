# Terminal modifier completion

**Follow-up correction:** the original button-state device check below missed
Gboard preedit. The input path is now fixed and the normal app reinstalled at
22:35:16+08; see [real Gboard verification](2026-10-13-terminal-gboard-modifiers.md).
The earlier 22:14 APK and its hash are historical, not the final device package.

Scope: add Shift and actual press/hold chords to the shared terminal accessory
bar (SSH, CLI terminal, container terminal and interactive login). No version,
build, install, push or publication requested in this task.

Ownership: original AgY Valhalla conversation
`ec81a4be-7543-45ee-8658-f68966f57d3b`, `gemini-3.8-flash-high`, effort `high`
owns UI/caller changes. Core encoder/bridge/provider changes belong to root.
Tests/format/analyze belong to OpenCode verified-free model (MiMo first).
Previous round's direct UI/build delegation exception is not assumed here.

## Behavior contract

- Ctrl/Shift/Alt/Fn are visible/selectable modifiers: tap arms the next key,
  tap again clears, long press without a chord locks until tapped again.
- Pointer-down activates immediately: another toolbar/IME/hardware key while
  held uses the modifier. Release after a chord must not arm it again. Pointer
  cancel, target terminal replacement and disposal cannot leave held state.
- Multiple modifiers combine; a successful key consumes only one-shot state,
  not locked or physically held modifiers. Modifier-only events are not keys.
- Shift+Tab emits reverse-tab; Ctrl+a emits SOH, Ctrl+Shift+letter retains normal
  control encoding. Shift printable characters use ASCII/US symbol mapping.
- Fn is a local mapping, not an SSH protocol bit: 1..9 -> F1..F9, 0 -> F10,
  minus -> F11, equals -> F12; arrows -> Home/End/PageUp/PageDown;
  Backspace -> Delete. Other keys pass through.
- Toolbar and single-character IME/hardware input share the state. Preserve CJK
  composition, multi-character commits, safe paste/copy shortcuts, selection,
  explicit keyboard button, focus suppression and scroll retention.
- Default pinned list adds SHIFT/FN. Preserve all explicit custom pinned lists;
  expanded panel exposes missing modifiers. Each modifier appears only once
  across pinned and expanded rows, avoiding conflicting simultaneous holds.

## Layer contract

Core adds optional `bool isShift = false` throughout `sendKey`,
`sendTerminalKey`, `sendTerminalAccessoryKey`, and exports
`String terminalFnKey(String key)` in core/utils/terminal_keys.dart.
AgY updates SharedTerminalCanvas, TerminalAccessoryBar and UI callers in SSH,
CLI, Docker and interactive login to forward `isShift`. Use existing xterm
onKeyEvent hook for physical keys, no vendor changes unless a proven gap is
reported first. Route only when local modifiers require it; preserve ordinary
hardware shortcuts and IME composition. Key names come from existing encoder.

Confirmed input-hook gap: root patches vendored TerminalView's software-keyboard
delete/done callbacks to offer `onTextInput('\b')` / `onTextInput('\r')` before
unchanged fallback. Canvas must normalize `\b` -> BACKSPACE, `\r`/`\n` -> ENTER,
`\t` -> TAB when modifiers are active. Only intercept printable ASCII otherwise:
non-ASCII/multi-character CJK commits must pass unchanged, without consuming the
latch. Existing Ctrl path silently dropped single CJK characters. Include
Fn+software delete, Alt+software done and Ctrl+single CJK commit regressions.
Root also preserves scroll-to-input for custom handled hardware key-down/repeat
events. Do not add another ScrollController. Use explicit logical-key mappings
for special keys, printable ASCII event.character/keyLabel fallback, ignore pure
modifiers/KeyUp, and preserve actual hardware paste/copy/Meta shortcuts. Fn uses
unshifted numeric keyLabel first even if physical Shift supplied punctuation.
Encoder review found a newly exposed Shift-arrow defect in the existing xterm
keytab: Up/Down hard-coded Ctrl's modifier value and Shift Left/Right only worked
in the alternate screen. Root fixes six keytab rows to carry the true modifier
value and allow Shift arrows in either ANSI buffer. Include byte assertions for
Shift/Ctrl+Shift/Alt+Shift arrows in both buffers; plain/Ctrl arrow regressions
must remain unchanged. No general keytab-parser rewrite.

## Acceptance

Byte-level encoder tests plus shared-canvas widget tests: tap Shift+Tab,
tap Ctrl then IME a, simultaneous hold Ctrl+a before long-press threshold,
locked repeats, combined modifiers, Fn+digit/navigation, physical letter with
toolbar Ctrl, pointer cancel/target switch, preserved CJK and paste behavior.
Run nearest terminal/caller/settings tests and flutter analyze. No live commands
to a real SSH server or the active Codex session during validation.

## Delivery and verification

Implementation is complete in the shared canvas, accessory bar, key encoder,
SSH/Mosh/CLI providers and all caller signatures. No dependency or stored
settings migration was introduced. Existing custom lists remain unchanged.
The focused read-only review found no remaining P1 in pointer release, target
replacement, focus ownership or paste-target validation.

OpenCode's confirmed-free `opencode/mimo-v2.6-flash-free` authored the tests and
ran validation. Final post-format gates:

- `dart format`: 23 changed/new Dart files only; `git diff --check`: exit 0.
- `flutter analyze --no-pub`: exit 0, no issues.
- `flutter test --no-pub --reporter expanded`: 11 focused files, **148 passed,
  0 failures**, exit 0. Covers encoder/settings/shared canvas, IME intent,
  scroll retention, toolbar actions, login, Docker, CLI, drawer focus and
  12 new modifier interaction tests. Earlier overlapping runs are not added.
- Logs: `/tmp/opencode/terminal-final-formatted-analyze.log` and
  `/tmp/opencode/terminal-final-formatted-tests.log` (local evidence, not
  committed artifacts). OpenCode session `ses_eca97bfd8ffeoQREW2cd4AyE98`.

The new tests assert Shift+Tab, one-shot Ctrl+A, held input before/after the
long-press threshold, lock/unlock, combined modifiers, Fn mapping, preserved
CJK, hardware Ctrl+A/C/V, drag/cancel, terminal replacement and focus loss.
IME assertions use the widget's input hook; they are not native-device IME
validation. Existing safe-paste and keyboard/scroll regressions also pass.

No APK/build, ADB install, physical keyboard/IME device validation, live SSH
commands, version change, commit, push or release was performed for this task.
The published v1.0.5 packages do not contain these uncommitted source changes.
Fn is a local terminal mapping, and Shift punctuation uses the ASCII/US key
layout; this does not implement a device's proprietary hardware Fn protocol.

## Follow-up: requested ADB package/install

The user subsequently requested a build and ADB installation. This supersedes
the original task's no-build/no-install boundary only; no version change,
Git push, release, uninstall or data clearing is authorized. OpenCode verified
free MiMo owns execution. The existing 148 passing tests and clean analyzer
are reused while product sources remain unchanged.

Current preflight sees `127.0.0.1:14251`, Android x86_64 emulator (not a physical
phone). Build uses the existing local debug-compatible signing path, only if
the installed APK certificate matches. Preserve the formal signing credentials
and release artifacts. Installation uses `adb install -r`; verify the installed
APK SHA256 against the freshly built candidate, version, update time and launch.
### Installation completed

MiMo and Big Pickle returned actual upstream rate-limit errors; confirmed-free
`opencode/step-5-preview-free` completed the build with exit 0 (52.9 seconds).
The user then explicitly asked root to complete the work and confirmed the
device was available for foreground checks. Root completed signature validation,
installation, readback and UI inspection; no product-source changes this turn.

- Evidence directory: `/tmp/valhalla-terminal-adb.upLSBl`.
- Artifact: `valhalla-1.0.5-terminal-x86_64-test.apk`, release mode with the
  existing debug-compatible test signer, **52,800,200 bytes**.
- Built: **2026-10-13 22:13:15+08**; version **1.0.5 / native 4006**, x86_64.
- SHA256: `a201593dfa3b9a6ef034d3c1bc9b9874876567d35046fd9e9793029c59d00992`.
- Signer SHA256 (matches installed old package):
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
- `adb -s 127.0.0.1:14251 install -r ...`: **Success**. Device update time
  **2026-10-13 22:14:01+08**, first install still **2026-09-23 03:26:04**.
- Pulled installed `base.apk` as `installed-after.apk`: SHA256 exactly matches
  the new candidate, not the old v1.0.4 APK or the published v1.0.5 package.
- Cold start: `am start -W .../.MainActivity` returned **Status: ok**, 763 ms.
  Existing server/menu configuration was visible; no clear/uninstall performed.
- Actual device UI: SSH shortcut row contains CTRL/SHIFT/ALT/FN, long-press Ctrl
  shows lock icon and `Ctrl (Locked)`, tap removes the lock. Input method remains
  `mInputShown=false` during navigation and modifier interaction.
- Process 14058 logs through the final inspection had no matches for Flutter
  errors, unhandled exceptions, RenderFlex, AndroidRuntime/FATAL or ANR markers.
- Screenshots: `launch.png`, `terminal.png`, `ctrl-locked.png`, `ctrl-cleared.png`;
  corresponding XML and `final-process.log` retained locally. `pubspec.lock`
  is unchanged; `git diff --check` passes.

The app's normal SSH page connection was allowed to restore its shell, but no
test command, character chord, Enter or interruption was sent to that production
terminal. Byte correctness remains covered by the prior 148 local tests, not
claimed as live SSH validation. No physical-phone or multi-finger gesture
acceptance was performed. No Git push or publication; this device test-signed
APK must not replace formal release assets.
