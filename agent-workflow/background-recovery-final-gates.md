# Background Recovery - Final Gates

Status: **GREEN** (final handoff gate)
Worker: protocol/data/widget test owner, space-bunny-free (free tier)
Workspace: /workspace/projects/valhalla
Device: 127.0.0.1:14251

This document **supersedes** the "six untracked Dart files failed the formatter"
section previously reported by the frozen gate worker. That finding is closed:
the six files were formatted and the formatter gate is now clean across every
changed and untracked Dart file in the tree.

Supersedes / complements:
- `agent-workflow/background-recovery-compile.md` (rounds 1-4: analyzer history,
  regression suites, defect reports)
- `agent-workflow/background-recovery-release.md` (artifact, signature, install
  and runtime evidence; its "Current" labels now point at the artifact recorded
  below)

## 1. Formatter round (the only code change this round)

Exactly these six previously-**untracked** Dart files were formatted:

```
lib/features/chat/widgets/remote_workspace_browser_dialog.dart
lib/features/chat/widgets/session_recovery_banner.dart
test/data/chat_recovery_merge_test.dart
test/features/background_recovery_cli_test.dart
test/features/background_recovery_ui_test.dart
test/infrastructure/acp_background_idle_test.dart
```

```
$ dart format <the 6 files>
Formatted 6 files (6 changed) in 0.10 seconds.
FORMAT_EXIT=0            # log: /tmp/opencode/final_format_six.log
```

Whitespace-only changes. No behaviour, no production logic, no test logic, no
test added/removed/skipped.

## 2. Formatter gate over every changed + untracked Dart file

```
$ dart format --output=none --set-exit-if-changed <86 changed+untracked .dart files>
Formatted 86 files (0 changed) in 1.28 seconds.
FORMAT_GATE_EXIT=0       # log: /tmp/opencode/final_format_gate.log
```

The set was built from `git status --short` covering both ` M` (tracked,
modified) and `??` (untracked) entries, which is exactly what the earlier
tracked-only pass missed.

## 3. Gate matrix (true exit codes, `set -o pipefail`, full logs in /tmp)

| Gate | Command | Result | Exit | Log |
|---|---|---|---|---|
| l10n generation | `flutter gen-l10n` | l10n.yaml-driven | **0** | `/tmp/opencode/genl10n_release.log` |
| formatter (6 untracked) | `dart format <6 files>` | 6 changed | **0** | `/tmp/opencode/final_format_six.log` |
| formatter gate (all 86) | `dart format --output=none --set-exit-if-changed` | 0 changed | **0** | `/tmp/opencode/final_format_gate.log` |
| analyzer | `flutter analyze --no-pub` | **No issues found!** | **0** | `/tmp/opencode/final_gates_analyze.log` |
| full test suite | `flutter test --reporter expanded` | **+1421 pass, ~17 skip, 0 fail** | **0** | `/tmp/opencode/final_gates_full_test.log` |
| release build | `flutter build apk --release` | `app-release.apk` | **0** | `/tmp/opencode/final_build_release.log` |
| install (update) | `adb install -r` | `Success` | **0** | `/tmp/opencode/final_install.log` |
| signature match | `apksigner verify --print-certs` (new + installed) | identical | match | `/tmp/opencode/final_apk_cert.log`, `/tmp/opencode/final_cert_installed.log` |

No pipeline was allowed to mask an exit code, and no partial/hung run was
accepted as a pass.

## 4. Current release artifact

| Field | Value |
|---|---|
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| Bytes | 123108211 |
| SHA-256 | `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3` |
| mtime | **2026-09-30 16:12:14.182475863 +0000** (`TZ=UTC stat`, no mislabeled offset) |
| Build | Gradle `assembleRelease` 71.4s |
| Signature | `C=US, O=Android, CN=Android Debug`, SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` |
| versionName / versionCode | 1.0.0 / 1 |
| Install | `install -r` at 2026-09-30T16:12:25Z, `Success` |
| lastUpdateTime | 2026-09-30T16:11:57Z (device stamp `2026-10-01 00:11:57 +0800`) |
| firstInstallTime | 2026-09-23 03:26:04 - unchanged, i.e. never uninstalled |
| dataDir | `/data/user/0/com.antigravity.valhalla.valhalla` - unchanged |

Superseded artifact (traceability only): SHA-256 `9bcfc7f2…4edb`, mtime
2026-09-30 16:02:04 UTC, installed 2026-09-30T16:03:47Z. Same size and same
signer; it predates the six-file formatting.

## 5. Device lifecycle checks (no remote prompts or manual history edits)

| Check | UTC | Observation |
|---|---|---|
| Launch | 2026-09-30T16:12:39Z | `MainActivity` top-resumed, pid **19075** |
| Home | 2026-09-30T16:12:47Z | launcher resumed |
| Resume | 2026-09-30T16:12:50Z | pid **19075** unchanged |
| Lock | 2026-09-30T16:12:56Z | `mWakefulness=Asleep` |
| Wake + unlock | 2026-09-30T16:13:00Z | `mWakefulness=Awake`, `MainActivity` resumed, pid **19075** |

`SAME_PID=yes (19075)`. No `FATAL EXCEPTION`, no `ANR`, no forced finish.
`dumpsys deviceidle` remains `mState=ACTIVE` (no Doze forcing). No ACP/CLI prompt
was sent, no chat history touched, no remote/server operation performed, no
force-stop, no git commit or push.

## 6. Correction to an earlier claim

Earlier drafts of the release report listed, under "reported to others, not
touched", a `test/core/connection_lifecycle_test.dart` item about a detached
healthy SSH connection being expected to reconnect. **That item is closed**: the
core worker fixed it, and the full suite in section 3 is the proof
(+1421 pass / 0 fail, exit 0) - the file is part of that run. Nothing in it was
modified by this worker.

Likewise the mid-round analyzer output that showed 13 lint findings (12 brace
infos plus one `dashboard_view.dart` unused optional `key`) is obsolete: it was
cleared upstream before section 3 was run.

## 7. Scope statement

Code changes this round: formatter-only, restricted to the six files named in
section 1. Everything else is documentation (`background-recovery-release.md`
updated, this file added). No production logic change, no test logic change, no
skipped or deleted test, no build-flag change.

**No remaining blocker. Gate is green.**
