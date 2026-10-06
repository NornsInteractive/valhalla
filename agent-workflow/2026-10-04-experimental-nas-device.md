# Experimental NAS — Device Deployment Evidence (2026-10-04)

## Authorization / Scope

- ADB install authorized; supersedes earlier no-ADB restriction ONLY for this
  deployment. No rebuild/tests/format/source/ARB/deps/git/keys. Data-preserving
  `install -r` only; no uninstall/pm clear/adb root. Main+small model remains
  `opencode/fledge-alpha-free` (confirmed-free fallback); no paid/subagents.
- OpenCode session `ses_efa045a6bffeBnDODUfPKr6YLw`; legacy
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved.

## Device

- Endpoint serial `127.0.0.1:14251` (sdk_gphone64_x86_64, `sys.boot_completed=1`);
  appeared in `adb devices -l` (no reconnect needed; no server reset). Explicit
  `-s 127.0.0.1:14251` on every operation. Device clock matches host at
  `2026-10-04T10:13:29Z`.

## Artifact preflight

- `build/app/outputs/flutter-apk/app-release.apk`: SHA-256
  `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`, 123,916,922 bytes,
  UTC mtime `2026-10-04T09:59:30Z` — matches expectations exactly.
- Metadata: `com.antigravity.valhalla.valhalla`, versionName 1.0.0, versionCode 1,
  MainActivity `com.antigravity.valhalla.valhalla.MainActivity`, targetSdk 36.
- Prior installed base pulled to `/tmp/opencode/valhalla-nas-adb-LUJxef/installed-base.apk`:
  SHA-256 `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96` (previous CLI build),
  Signer #1 cert SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` — matches
  build → signature compatible, `-r` allowed. Data preserved.

## Install / Installed verification

- `adb -s 127.0.0.1:14251 install -r build/app/outputs/flutter-apk/app-release.apk`
  → `Performing Streamed Install`, **`Success`**.
- `dumpsys package`: versionName 1.0.0, versionCode 1, targetSdk 36,
  `lastUpdateTime=2026-10-04 18:13:34` (+0800 = `2026-10-04T10:13:34Z`).
- Installed base pulled from new path
  `/data/app/~~X74z4h8MUrY_O2l1ezh2Gg==/.../base.apk` → SHA-256
  `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438` — EXACT match with artifact.

## Bounded startup (after successful installation)

- `am start -n com.antigravity.valhalla.valhalla/.MainActivity` → `Starting: Intent { cmp=... }`.
- At T+12s: `pidof` = `19870`; `topResumedActivity=...valhalla/.MainActivity u0 ... t149`.
- Time-filtered logcat (`logcat -d -T '10-04 10:13:30.000'`), followed by PID
  filtering of error lines (not native `--pid` capture): 0 `FATAL EXCEPTION`,
  0 `ANR in com.antigravity.valhalla...`; 0 AndroidRuntime/Exception/Error lines for pid 19870.
- The first log-check command had a shell quoting error; the subsequent corrected
  scan returned the counts above. The capture used the pre-install UTC timestamp;
  logcat local timezone was not independently checked, so an exact startup-only
  time window is not claimed. No logcat clear or unfiltered log output. No manual preference
  / experiment toggles, chats sent, histories accessed, agent installs, consent
  flows, or remote commands. Expected automatic-reconnect startup untouched.

## Limitations

- No UI screenshot/foreground validation of NAS/CLI toggles inside Settings (out of
  bounded scope): proof is install success + hash equality + clean PID startup only.
- x86_64 emulator endpoint; ARM ABI coverage not applicable.
  Data-preserving installation used `install -r`; no uninstall/clear operation
  occurred. No post-install firstInstallTime or individual preference audit.
