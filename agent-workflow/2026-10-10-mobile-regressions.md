# Mobile regression repair — 2026-10-10

User approved the five-item plan. Base: clean main after v1.0.3 release.
No release, push, version change, shared-cache cleanup, dependency upgrade,
credential reset or user-data deletion authorized by this task.

## Ownership

- UI/ARB/native icon resources: original AgY Valhalla conversation
  `ec81a4be-7543-45ee-8658-f68966f57d3b`, `gemini-3.8-flash-high`, high.
  Do not use another conversation/model or change business/provider files.
- Core services/providers and this contract: Codex.
- All tests, verification, formatting, generation, local Android build and
  data-preserving ADB: OpenCode, confirmed-free main and small model only.
  Never operate on other running agents/projects or live Codex history.

## Required changes / acceptance

1. Compact mobile SFTP breadcrumbs: remove excessive short-segment spacing;
   retain useful touch height, readable full-path tooltips, horizontal overflow,
   root/up/bookmarks, exact navigation targets, RTL-safe path display.
2. SSH toolbar: reuse Windows local ANSI write clear on all platforms (screen,
   scrollback, immediate paint; no remote shell command). Use independent,
   accessible tab close callbacks on mobile too. Last tab remains with no close;
   disposing a tab must not dispose others or delete remote tmux sessions.
3. Android icon: reuse existing brand asset; adaptive full-bleed background and
   safe-zone foreground, eliminate legacy double-inset/background effect;
   support legacy Android too. No redesign or new runtime dependency. Original
   source includes a white rounded-square tile and transparent outer margin;
   do not mistake its white brand background for a removable symbol.
4. Docker: capture actual command/exit and sanitized output if accessible; do
   not claim root cause without evidence. Invalid nonempty response must not
   silently become empty success. Preserve cache on refresh error, show retry
   error even with cache, distinguish filtered-empty/disconnected/true-empty.
   Container/Compose selector occupies first row; status filters a separate row
   beneath it, retaining existing paused filter. No real lifecycle operations.
5. Drawer/keyboard: opening drawer clears old input focus; selection, backdrop,
   system-back and swipe dismissal must not restore keyboard. Hidden/outgoing
   pages cannot take focus. Do not unmount pages/reset connections/drafts.
   User tapping text fields/terminal must still open keyboard normally.

## Evidence before implementation

- sftp_file_view.dart breadcrumb segments enforce minWidth 44, extra chevrons.
- terminal_view.dart uses InputChip and repainting ANSI clear only on Windows;
  other platforms use ChoiceChip with a nested 14px close InkWell and direct
  eraseDisplay/setCursor without xterm notifyListeners.
- AnimatedIndexedStack keeps pages alive but has no focus exclusion; drawer
  opening/closing has no focus coordination.
- DockerContainer.parseLines ignores FormatException/TypeError on every row;
  listContainers returns that empty list as success. Underlying actual remote
  failure remains to be captured; do not invent a Docker daemon error.
- Existing toolbar action tests target Windows only.

## Validation

OpenCode adds focused Android + Windows widget regressions, real command/parser
fixtures, Docker cache/error/reconnect tests, drawer focus/draft tests, breadcrumb
width/navigation tests and launcher resource checks. Analyze + nearest/full
suite as resources allow; record exact exits and failures. Build locally with
existing fixed Android release certificate; never print secrets. Use exact ADB
serial, install -r without uninstall/data clear, stop on signature mismatch.
Device smoke: paths, tabs/clear, keyboard dismissal, icon and read-only Docker
listing using existing configured target only. No prompt, approval, login,
container mutation, terminal task termination or existing Codex history edits.
If device/target unavailable, report it as unverified, not successful.

## Status

Implementation complete. Final full suite: 2195 passed, 18 environment skips,
zero failures, exit 0; final analysis and diff check exit 0. Official split APKs
saved separately; original-debug-key test APK installed successfully with -r,
without uninstall/data clear. See final-gates/build reports for exact evidence;
device smoke is separately scoped and is not full remote-service acceptance.

## Docker root cause found (Codex source trace)

The `listContainers` format ends in `{{json (.Label "com.docker.compose.service")}}`
and immediately closes the shell quote. Those two braces close the Go template
action, NOT the surrounding JSON object. The initial literal `{` has no matching
literal `}`. This is deterministic invalid JSON for every container, not an SSH
or Docker daemon issue. OpenCode must reproduce this exact production format
with Go text/template (json helper + mock .Label), then assert json validity and
parse actual rendered output, not just hand-written successful fixtures.
Codex fixes the missing literal brace, strict structured-row parsing, refresh
loading/error retention. Record real-server validation separately.

Core patch is now present: missing final literal brace repaired; parseLines
ignores non-JSON shell banners only when valid records exist, rejects malformed
object records/invalid types/missing IDs and all-nonempty-garbage responses;
listContainers translates these into DockerExecutionException without raw
payload leakage. Empty stdout remains a legitimate empty list.
DockerState.copyWith now preserves errors unless clearError=true; refresh start,
success and disconnect explicitly clear errors. Search/filter changes must not
erase the diagnosis. Quiet refresh with no cache shows loading, not empty.

Verifier note: no need to download/build the Docker CLI or daemon. A tiny
standard Go text/template + encoding/json harness matching Docker's json helper
(Encode with SetEscapeHTML(false), TrimSpace result) is enough to reproduce the
literal missing-brace bug. Test HEAD vs working template. Avoid unrelated probes.
Signing/build follows the existing v1.0.3 fixed certificate; no version bump.
Use split-per-ABI code compatible with installed app, not a universal lower
versionCode. Disk/device preflight must happen before starting the build.

## Execution handoff

- AgY resumed the exact required conversation interactively; UI report is
  `2026-10-10-mobile-ui-status.md`. Source review requested tight 2px breadcrumb
  padding/24px minimum width/44px height, all inactive pages excluded from focus,
  pre-open focus release, and pre-v26 round-icon fallback.
- OpenCode Docker verifier: `ses_edb18c657ffeNi8Tj8IhAQv7s2`; initial broad
  investigation interrupted, resumed scoped to Docker tests only. The initial
  Go harness used identical hardcoded templates and is not regression evidence;
  its later extraction failed. The actual HEAD-versus-working-template Dart
  rendering and in-repo tests demonstrate the missing brace. Combined service
  and provider regression run: 36 passed, exit 0; targeted analysis also clean.
  See `2026-10-10-mobile-baseline.md` and `2026-10-10-mobile-docker-tests.md`.
- OpenCode UI verifier: `ses_edb0df568ffe3g312wo8cqt8cm`; owns terminal,
  breadcrumbs, shell focus and icon checks, no product edits.
- OpenCode preflight: `ses_edb1161edffeiJ3P7hcwwwGHtd`; 52 GiB free, signing
  files outside repository confirmed. User restarted emulator container; exact
  endpoint `127.0.0.1:14251` is now connected, x86_64, boot complete. Installed
  app is 1.0.0/code 1, signed with Android Debug certificate SHA256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
  Do not attempt official-release installation over that incompatible key or
  uninstall. User asked whether to permit a separately labelled test APK signed
  with the original debug key (only if the key matches) for data-preserving
  verification; official release certificate remains unchanged.
- All OpenCode sessions above explicitly use task-local main/small
  `opencode/step-5-preview-free`; no global model configuration changes.

## ADB test-signing approval

User approved a separate test APK using the original debug signing key to keep
device data. OpenCode confirmed the local debug certificate matches the installed
certificate above. After saving and verifying the official release artifacts,
build a separately labelled test APK, verify its certificate, then install with
`adb -s 127.0.0.1:14251 install -r`. Never uninstall or clear app data. The official
release certificate and published v1.0.3 artifacts remain unchanged.

## Verification-driven corrections

- Docker widget tests caught the unbounded view selector putting Compose outside
  a 390px viewport. AgY replaced its horizontal scroller with a bounded selector;
  the status-chip row remains independently scrollable below it.
- Breadcrumb geometry test caught that `Container.alignment` still expanded each
  short segment to the 120px maximum. Reducing minimum width/padding alone did not
  solve the user's issue. AgY changed it to shrink-wrapping centering. OpenCode's
  measured short segment is now 24px wide and 44px high, with 22.2px between
  adjacent text bounds. Navigation/focus suite completion remains pending.
- Isolated official builds succeeded, but are intermediate artifacts until the
  final verified source is synced. Never label those as installed/final proof.
- Docker service/provider/view combined gate: 48 passed, exit 0; three-file
  analysis clean. The Retry button test now recognizes TextButton subclasses;
  the stock TextButton.icon implementation is preserved.
- Terminal/files/drawer focused gate: 28 passed, exit 0. The same tests on
  pre-fix HEAD: 16 passed, 12 failed, exit 1. Full final suite: 2195 passed,
  18 skipped, zero failures. See `2026-10-10-mobile-ui-tests.md` and
  `2026-10-10-mobile-final-gates.md` (earlier failed harness runs retained).

## Installed-device observed scope

OpenCode ADB smoke on the existing racknerd connection showed real root-directory
files, real container cards and Compose project groups; selector and filters are
separate rows. `dumpsys input_method` recorded search tap=true, menu open=false,
backdrop dismissal=false, search re-tap=true, Back=false; no search text persisted.
Screenshots/XML: `/tmp/opencode/mobile-device-smoke`. Launcher adaptive icon also
captured. No lifecycle buttons, shell commands, credentials or Agent prompts were
used. Physical-phone/OEM behavior and live terminal tab operations remain outside
this device smoke; terminal operations are covered by fake-session widget tests.
