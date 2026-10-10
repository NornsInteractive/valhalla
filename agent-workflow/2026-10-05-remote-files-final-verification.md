# Remote files — Final verification (2026-10-05)

## Authoritative summary (supersedes sections below where they differ)

- Final gate state after bounded cleanup:
  `flutter test test/core/remote_files_contract_test.dart` EXIT=0 (25
  tests); `flutter test test/features/remote_files_ui_contract_test.dart`
  EXIT=0 (9 tests); `flutter test test/core/l10n_key_parity_test.dart
  test/core/app_locales_test.dart` EXIT=0 (21 tests); full
  `flutter test` EXIT=0, `+1972 ~18` (18 skips), `All tests passed!`;
  `flutter analyze` EXIT=0, "No issues found!"; `git diff --check`
  EXIT=0. Logs under `/tmp/opencode/rfiles-*.log`.
- Failed-write prefs regression now exercised through the REAL
  `LocalStorageService` over a SharedPreferences interface fake (cache
  mutated before setBool returns false, `reload()` restores native map).
  Removed the `// ignore: depend_on_referenced_packages` suppression and
  the transitive `shared_preferences_platform_interface` import; no
  pubspec changes. No generic `throwsA(anything)` remains: timeout/stat
  noConnection+connectionLost assert `isA<SFTPException>()`, raw
  listdir status failure asserts `isA<SftpStatusError>()`.
- Mechanical `dart format` applied to
  `lib/infrastructure/sftp/sftp_client_service.dart`,
  `lib/core/providers/sftp_provider.dart`,
  `lib/data/storage/local_storage_service.dart`,
  `lib/features/files/sftp_file_view.dart` plus both test files. No
  semantic production/UI/ARB edits.
- APK: pre-format backup of the `128717610`-byte /
  `f8ccfc98…744b73` APK at
  `build/app/outputs/flutter-apk/app-release.apk.bak-20261005-024928-preformat`
  (identical SHA-256). Fresh dev-signed universal build EXIT=0:
  size `128717610` bytes, SHA-256
  `0733639f1784bec7162c4e07bb425a1f05daade5dd5e96f5cee2b51a96d744c9`,
  mtime local `2026-10-05 10:50:29+08:00` = UTC `2026-10-05T02:50:29Z`
  (system `date -u` 2026-10-05T02:50:34Z), signer DN
  `C=US, O=Android, CN=Android Debug` (SHA-256
  `2faa583f…f37e9`), package `com.antigravity.valhalla.valhalla`
  versionCode 1/versionName 1.0.0, targetSdk 36, sdkVersion 24. Explicit
  binary paths `/opt/android-sdk/build-tools/35.0.0/apksigner` and
  `/opt/android-sdk/build-tools/35.0.0/aapt`. Five signing/unsigned env
  variables unset for the build subprocess only. No ADB/git-writes/keys.
- Time notation correction: the previous language APK's claimed UTC
  mtime was `2026-10-04T14:59:50Z`, which is exactly
  `2026-10-04T22:59:50+08:00` (the actual filesystem mtime recorded
  earlier as `2026-10-04 22:59:50+0800`) — not `14:59:50+08:00`.
- Link metadata correction: a symlink entry's modification time comes
  from the link's own entry attrs, never from the resolved target;
  `isDirectory` and size come from the resolved target; path, modification
  time and permissions remain the link entry's own metadata.

## Authorization / session / model

- Session: fresh bounded context `ses_ef623b072ffeCDyW0w7JY5E126`, previous
  sessions `2026-10-05` stage-1 context and legacy
  `ses_efa045a6bffeBnDODUfPKr6YLw` / `ses_f0405efacffePPqWyhHc3GGJY7` evidence
  preserved.
- Model: main and small both `opencode/fledge-alpha-free` (explicitly
  authorized fallback after MiMo rate limiting). No paid model, no ADB, no
  user-host/history/auth/key operations, no git writes, no dependency
  installs.

## Contract state

- Root flipped the heading to `Verification stage 2 — source frozen`; full
  gates executed below.
- Production logic/storage owned by root; UI + ARB edits belong to original
  AgY (`ec81a4be-7543-45ee-8658-f68966f57d3b`, gemini-3.8-flash-high,
  effort high). I authored tests, formats, codegen, runs builds only.

## Tests authored (OpenCode)

- `test/core/remote_files_contract_test.dart` extended (was 13, now 24
  tests):
  - alias-only directory-link delete: provider `deleteItem` routes
    `isDirectory && isSymbolicLink` through `deleteFile`/remove, never
    `deleteDirectory`/rmdir; real directories still rmdir; service-level
    `remove`/`rmdir` receive the alias path only and trigger no extra stat
    of the target entry.
  - `renameItem` passes the original alias path (provider and service).
  - hidden preference survives a fresh provider over the same
    SharedPreferences (server/restart simulation); offline toggle persists
    true; actual `false` boolean write verified; platform mock
    (`_FailingSetBoolStore`, setValue→false for true) proves a failed
    backend write keeps the old selection, exposes
    `SFTP_HIDDEN_PREFERENCE_SAVE_FAILED`, and `prefs.reload()` discards the
    optimistic legacy cache (`getBool` null after failure, fresh provider
    still false).
  - all download entrypoints (`downloadTo`, `downloadFile`,
    `downloadAndOpen`, `openFileForEditing`, `canPreview`) reject
    unresolved links without queueing transfers.
  - stat concurrency capped at 4 (deterministic barrier completer, no
    timing delays), counter moved into `finally` around the whole in-flight
    operation; every stat record shows `followLink=true`; ordinary files
    never stat'ed; stat timeout (100 ms completer that never completes)
    rejects the listing and starts no further stat requests beyond the four
    in flight; listdir transport failure (`SftpStatusError` noConnection)
    rejects the listing instead of masquerading as a broken link.
- `test/features/remote_files_ui_contract_test.dart` added (9 focused
  widget tests, reusing existing harness style): 320dp + 2x text scale no
  overflow; ≥2 breadcrumb segments visible in 360dp viewport; navigation
  reveals the final segment; refresh does not force-scroll the breadcrumb
  back to the tail; Arabic RTL keeps the POSIX path forced LTR; hidden
  toggle works offline and ignores a second tap while pending; the same
  captured `onPressed` invoked twice before a rebuild issues one save
  (this test now passes after root/AgY hardened the closure with an
  `_isTogglingHiddenFiles` re-entrancy guard — verified in
  `lib/features/files/sftp_file_view.dart:1050`); two-row search/action
  layout preserved with anchors `sftp_search_field` and
  `sftpToggleHiddenButton`; directory symlink navigates via alias path,
  broken link shows the localized unavailable message and its menu hides
  open/download.
- ARB parity: each newly added key (`sftpUpDirectory`,
  `sftpShowHiddenFiles`, `sftpHideHiddenFiles`,
  `sftpHiddenPreferenceSaveFailed`, `sftpSymlink`,
  `sftpLinkTargetUnavailable`, `sftpLinkTargetPermissionDenied`) appears
  exactly once per catalog for all 17 catalogs (grep count 1 per file).

## Commands run (real exit codes)

- `dart format test/core/remote_files_contract_test.dart test/features/remote_files_ui_contract_test.dart` → 2 files formatted.
- `flutter test test/core/remote_files_contract_test.dart` → All tests passed! (24).
- `flutter test test/features/remote_files_ui_contract_test.dart` → All tests passed! (9).
- `flutter gen-l10n` → regenerated all 17 catalogs; duplicate-source-key
  check done (above); `flutter analyze` reports no issues.
- `flutter test test/core/l10n_key_parity_test.dart test/core/app_locales_test.dart` → All tests passed! (21).
- `flutter test` (full suite) → `+1972 ~18` = **All tests passed!** (18 skips);
  log saved under `/tmp/opencode/rfiles-full.log`.
- `flutter analyze` → **No issues found!**

## APK build (development-signed, universal)

- Pre-build preservation: verified previous APK integrity first
  (SHA-256 `4f42ac9e3c4ea38365d0b844d8528ebbceffccc0479fd112fbd317fa13c3432d`,
  128684666 bytes, contract-stated UTC mtime
  2026-10-04T14:59:50Z, which equals filesystem local
  2026-10-04T22:59:50+08:00),
  then copied to
  `build/app/outputs/flutter-apk/app-release.apk.bak-20261005-024048-prebuild`
  (same SHA-256).
- Build: `env -u VALHALLA_ANDROID_KEYSTORE -u VALHALLA_ANDROID_STORE_PASSWORD -u VALHALLA_ANDROID_KEY_ALIAS -u VALHALLA_ANDROID_KEY_PASSWORD -u VALHALLA_CI_UNSIGNED flutter build apk --release`
  → ✓ Built `app-release.apk` (128.7MB), Gradle assembleRelease ~80s.
- Freshness: mtime 2026-10-05T02:42:16Z-equivalent local 10:42:16+08:00,
  `date -u` 2026-10-05T02:42:21Z confirms fresh production time.
- Size: 128717610 bytes.
- SHA-256: `f8ccfc98fd06ce4963ca94d5521f541448338908114892fdb3b789dc63444b73`.
- Certificate: `apksigner verify --print-certs` → Signer #1 DN
  `C=US, O=Android, CN=Android Debug`, SHA-256 digest
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
  (development signing, no formal key).
- Package identity: `aapt dump badging` →
  `package: name='com.antigravity.valhalla.valhalla' versionCode='1' versionName='1.0.0' ... sdkVersion 24, targetSdkVersion 36`.

## Defects / issues reported (no UI/logic patching by OpenCode)

- Hidden-toggle re-entrancy: my captured-`onPressed` contract test
  initially failed (2 saves on double invocation before a rebuild);
  root/AgY then hardened the closure (verified guard at
  `lib/features/files/sftp_file_view.dart:1050`), whereupon the test
  passes. No OpenCode patch to display logic was needed.
- Historical note from stage-1: contract's stat-counter flake and UI
  source-frozen lag were both resolved; legacy `503` envelope state
  irrelevant to final exit 0.
- No other blocking regressions across the full suite.
