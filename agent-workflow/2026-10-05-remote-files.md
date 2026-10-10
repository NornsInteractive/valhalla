# Remote files navigation, visibility and symlink contract

## Final delivery

Implemented and verified by assigned owners. OpenCode final gates: core 25,
UI 9, locale 21; full 1972 passed / 18 existing skips; analyze and diff check
exit 0, no new ignores or dependencies. Latest APK: 128717610 bytes,
UTC 2026-10-05T02:50:29Z, SHA256
0733639f1784bec7162c4e07bb425a1f05daade5dd5e96f5cee2b51a96d744c9.
Existing Android Debug/development certificate, no ADB or user-host validation.
See final-verification report's authoritative summary and project handoff.

Preserve the dirty worktree, existing language and experimental-feature work.
Root owns service/provider/storage only. UI and all ARB changes belong exclusively
to original AgY Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high, effort high. All test authorship, formatting, codegen,
analysis and APK builds belong to OpenCode (opencode/fledge-alpha-free fallback
explicitly authorized after MiMo rate limiting; both main/small model explicit).
Do not install via ADB in this task, reset data, touch release keys or write Git.

## Core contract (implemented; verified)

- SftpState.showHiddenFiles defaults false; copyWith preserves it.
- SftpNotifier.setShowHiddenFiles(bool) persists before updating state, filters
  cached data without remote requests, and preserves search/sort/transfers.
  Storage failure leaves selection unchanged and exposes
  SFTP_HIDDEN_PREFERENCE_SAVE_FAILED. Globally persisted across servers/restart.
- filteredFiles removes '.' everywhere and '..' at root; hidden dot entries are
  excluded unless enabled, but '..' remains available outside root.
- SftpFileItem adds isSymbolicLink=false and String? linkTargetErrorCode.
  SFTP_LINK_TARGET_UNAVAILABLE and SFTP_LINK_TARGET_PERMISSION_DENIED indicate
  unresolved targets; isDirectory is the followed target type for resolved links.
  Path always remains the original alias, never realpath.
- Only symlinks are stat'ed with native SFTP, max four concurrent, within existing
  browse timeout. Errors are per-entry; no shell, new dependency or recursive walk.
  Broken/cyclic links stay visible, do not open as files. Permission prefix is l.
- Rename/delete operate on alias. Directory symlink deletion calls remove, never
  rmdir. Failed targets cannot preview/download. NAS recursive scanner unchanged.

## AgY UI work

Only edit lib/features/files/sftp_file_view.dart and lib/l10n/*.arb (not generated
files). Retain Norse Steel palette/typography and the separate search/action rows.
Replace bulky breadcrumb chips with compact text links/separators, keep up/root,
horizontal scrolling, tail-visible once after navigation (not each refresh).
Constrain very long segments, tooltip full name, adequate touch targets and large
text support. POSIX path is LTR even with Arabic UI; dispose scroll controller.
Add local hidden-file icon toggle in existing action row, enabled offline;
await setter with mounted checks, show selected visibility state, localize tooltip.
Render symlink badge; directory links enter as folders, unresolved links show
localized target-specific error without navigation; disable preview/download for
unresolved links, keep rename/delete. Translate added error/tooltip/label keys into
all 17 existing catalogs with exact placeholder parity; do not clone English.
Map new provider error codes through existing localized error presentation.
Record actual changes and unresolved issues in a separate UI status document.

## OpenCode verification

Read this contract and existing rules; do not alter display/ARB. Author focused
tests for hidden filtering/persistence/failure/copyWith and no directory fetch,
service target classification and max-four stat workers, ordinary-file no-stat,
relative/absolute/chain/broken/denied links, alias-only deletion, stale-source
protection, UI compact breadcrumb on 320/360dp/large font/RTL and tail navigation,
visibility toggle and preserved two-row header. Reuse mock/disposable fixtures;
no operations on user SSH hosts/history/credentials. Run relevant regressions,
all locale parity tests, then full suite and flutter analyze. Mechanical format
and flutter gen-l10n are OpenCode-only. Preserve previous APK under a distinct
backup before fresh development-signed release build; never use formal key.
Record exact commands, counts/skips, warnings, APK UTC timestamp/size/SHA-256,
development certificate and package identity. No device install authorization.

For the build, explicitly unset VALHALLA_ANDROID_KEYSTORE,
VALHALLA_ANDROID_STORE_PASSWORD, VALHALLA_ANDROID_KEY_ALIAS,
VALHALLA_ANDROID_KEY_PASSWORD and VALHALLA_CI_UNSIGNED for that subprocess only;
then use flutter build apk --release (existing debug certificate fallback).
Never print their values or access formal signing files. The previous language
APK is 128684666 bytes, SHA256
4f42ac9e3c4ea38365d0b844d8528ebbceffccc0479fd112fbd317fa13c3432d,
UTC mtime 2026-10-04T14:59:50Z; preserve under a distinct dated backup before build.

## Verification stage 2 — source frozen

Phase 1 core tests passed; AgY review corrections are complete. Complete
missing regression proof (reuse test/core/remote_files_contract_test.dart):
alias-only directory-link delete with recorded remove/rmdir calls and untouched
target entry; rename receives alias path; hidden preference survives fresh
provider/server/reconnect and can toggle offline; actual SharedPreferences false
write (not only overridden throw); all download entrypoints block unresolved
links; native stat followLink true, stat timeout stops new requests and browse
transport status failures reject listing instead of masquerading as broken link.
Use deterministic completers for concurrency, not timing-dependent delays.
The previous phase test fixture stat counter decrements before statBehavior
completes, so strengthen it to count the entire in-flight operation in finally.

Author focused Widget tests in a bounded separate test file, reusing existing
SFTP view harness: at 320/360dp and 2x text scale no overflow, typical breadcrumb
links fit more than two in viewport, navigation reveals final segment, refresh
doesn't force-scroll and RTL path stays LTR; hidden toggle works offline and
can't double-submit while pending; links navigate alias, broken links show
localized errors and no preview/download options. Preserve two-row search and
all existing test anchors. Check newly added ARB keys have exactly one source
occurrence per catalog (JSON parsing alone silently ignores duplicates).
For toggle deduplication, also invoke the same captured onPressed twice before
a rebuild while storage is gated: disabling a button only on the next frame
must not allow two saves. If it fails, report to root; never patch UI yourself.
Important: test `实际写入 false 而非仅覆盖抛错` currently toggles the preference
VALUE to false successfully; that does NOT test a failed backend write. Add a
platform mock whose setValue/setBool returns false when asked to save true,
assert reason code + old selection and getFileShowHidden after provider rebuild.
Installed shared_preferences legacy _setValue mutates its memory cache BEFORE
awaiting platform persistence; report any failure-cache inconsistency to root.
Root hardened setFileShowHidden with native prefs.reload on failed/throwing writes
to discard optimistic legacy cache values before reporting failure; test that
backend false returns retain the old preference across rebuild (no custom cache).
For this test a SharedPreferences interface fake is sufficient: setBool must
optimistically update its cache then return false, reload restores an unchanged
native map. Exercise real LocalStorageService (not an overridden storage setter).
No new dependency or transitive-package import/lint suppression is needed.
Installed SDK sources are under /home/dev/.pub-cache/hosted/pub.dev; don't search
the entire filesystem. Generate l10n now that the source-frozen marker is present.

Do not format/compile UI, generate l10n or build until root changes this heading
to `Verification stage 2 — source frozen`. Core tests and mechanical core/test
formatting are allowed now. After the marker is present, execute complete gates
and development-only build above. Never edit production logic, display or ARB;
report defects to root/AgY. Prefer native edit/apply_patch tools over shell writes.

AgY completed initial and bounded correction passes with process exit 0 on the
original conversation/model/high. Its cumulative result envelope retains an old
503 error; actual source/status changes and current process exit, not historical
envelope state, are used for handoff. OpenCode final verification uses a fresh
bounded context ses_ef623b072ffeCDyW0w7JY5E126, same confirmed-free model/config;
previous verification sessions and evidence remain intact.

OpenCode reproduced real UI failure: captured hidden-toggle onPressed invoked
twice before a frame results in 2 saves (expected 1). Root delegated the narrow
entry guard to original AgY. Don't build until this heading is source frozen
again; continue other core/test-only checks. Refresh test initially matched two
horizontal scroll views (test harness ambiguity, not a production defect).
AgY's one-line callback guard is now present and its process exited 0. All UI
source is frozen again for final gates. Do not add pubspec dependencies or ignore
analyzer findings: replace transitive platform-interface test mock with the
SharedPreferences interface fake described above if depend_on_referenced_packages
fires. Keep backend-false regression and assert SFTPException for timeout/
explicit transport-status tests instead of throwsA(anything).
