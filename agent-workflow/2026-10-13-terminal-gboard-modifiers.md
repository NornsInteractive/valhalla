# Gboard terminal modifier correction

## Evidence and cause

User reported that tapping Ctrl/Shift followed by Gboard `c` still displayed
literal `c`. The prior device check verified only modifier UI state, not Gboard
output; prior widget tests called the text hook directly. Six new 360px Android
tests using actual `TestTextInput` committed values also passed, ruling out a
normal single-character commit or narrow-row double-toggle as the cause.

With the user's explicit exclusive-device approval, a temporary local-only
`tool/terminal_ime_probe.dart` entrypoint reused the real shared canvas and
encoder. It creates no SSH, storage or network providers. On the actual emulator
Gboard, Ctrl remained one-shot active, but tapping `c` delivered text `[99]`
with composing range `0..1`, no `onKey` and no terminal output bytes. xterm drew
the preedit, so the user saw a literal `c` without Ctrl+C being executed.

OpenCode Step's upstream endpoint failed during reproduction. The main agent
completed this same terminal correction's regression/build/device work under
the user's preceding direct-completion authorization. Product UI/ARB files
were not edited; the fix is entirely in the vendored input plumbing.

## Minimal correction

`CustomTextEdit` offers only an entire fresh, printable single-ASCII preedit to
an optional handling callback. `TerminalView` routes this through its existing
text handler, which consumes it only when a local modifier is active. After
consumption, clear the preedit and reset both local and platform editing state
using the existing helper. No composition-wide conversion, timers, suppression
cache, keyboard switching or retroactive rewriting of existing text.

Preserve normal Latin/CJK composition, multi-character values, absent/declined
callbacks, pre-existing prefixes and delete-detection sentinels. Existing
multi-character commit behavior remains unchanged. No settings migration or
version bump; no production terminal commands used for testing.

## Verification

- Red tests: Ctrl/Shift/Alt immediate Gboard preedit all failed with no output
  before the correction (`/tmp/terminal-gboard-preedit-red.log`).
- Final focused suite: **163 passed, 0 failed**, including 11 real mobile input
  cases and 4 boundary cases, plus all 148 previous tests.
- Analyzer: **no issues** after removing two unused test imports.
- Logs: `/tmp/terminal-gboard-final-tests.log`,
  `/tmp/terminal-gboard-final-analyze.log`; lockfile unchanged, diff check clean.
- Real Gboard local probe after correction: Ctrl+C -> `[3]`, Shift+C -> `[67]`,
  Alt+C -> `[27,99]`, locked Ctrl then two presses -> `[3]` twice; after unlock,
  ordinary `c` remains preedit and commits with space as `[99,32]`, once.
- Device evidence: `/tmp/valhalla-ime-proof.2jonIK`, especially `ctrl-tapped.xml`,
  `ctrl-c.png` (before), `fixed-ctrl-shift-c.png`, `fixed-all.png`,
  `fixed-gboard.log` (after). Device is Android 14 x86_64 emulator, Gboard;
  no physical-phone multi-finger acceptance or live remote command asserted.

## Normal application hand-back

The probe temporarily used the same package/test signature with native4006 to
preserve data. It **has been replaced** with the normal `lib/main.dart`
release-mode, original test-signed APK:

- Build: `flutter build apk --release --target lib/main.dart --split-per-abi
  --target-platform android-x64 --build-number 6`, existing Gradle cache and
  unset formal signing environment. Exit 0, 53.7 seconds.
- Candidate: `/tmp/valhalla-ime-proof.2jonIK/valhalla-1.0.5-gboard-x86_64-test.apk`;
  52,800,200 bytes; built **2026-10-13 22:34:22+08**.
- Version **1.0.5/native4006**, x86_64; original test signer SHA256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
- `adb install -r`: Success; update **2026-10-13 22:35:16+08**, first install
  remains **2026-09-23 03:26:04**. No uninstall or data clearing.
- Installed `base.apk` was pulled as `normal-installed.apk`. Both candidate and
  device SHA256 are `c8e4bfe60432dd0882766b489838d376cdec607c1a316efb4aa723cea8bf3780`.
- Normal app cold start: Status ok, 613 ms; existing dashboard/server restored,
  `mInputShown=false`, no probe screen. Process14236 log has no Flutter/FATAL/
  unhandled/RenderFlex/AndroidRuntime or `IME_PROBE` markers. Screenshots/XML and
  `normal-process.log` are in the same evidence directory.

No push or publication. This is a debug-compatible device-test certificate,
not a replacement for formal release assets. Gboard byte validation was done
with the exact shared component in a local-only debug probe; the normal
release-mode app was rebuilt, installed and startup-checked, without injecting
interrupt keys into production SSH sessions. Other mobile IMEs remain untested.
