# Shared browser and app data — final verification contract

Run only when root explicitly signals UI/core freeze. OpenCode owns verification,
generation, formatting, build and ADB, using the explicitly free MiMo model unless
the user grants a new round-specific fallback. Preserve all dirty edits. No push,
release, version change, production writes, uninstall, data clear, or key changes.

## Source gate

1. Reread approved implementation, both browser/protocol handoffs and UI review
   findings. Validate that every old remote picker caller migrated, while local
   upload/export remains the OS picker and the main file page uses the extracted
   display rather than leaving a new independent picker UI.
2. Complete the three focused core test groups and new widget tests. Generate all
   localization outputs once ARBs stop changing; verify all17 keys/placeholders.
   Formatting may touch only task-owned changed Dart files; report product errors
   to root/AgY, do not make UI or business patches yourself.
3. Widget coverage: uninstall defaults and parent/child selection; name/main-service
   validation plus legacy preservation; each host/agent/NAS picker caller; permission
   versus missing-directory fallback; cancellation/disposal/target changes; directory
   mode never selects a regular file; media libraries use IDs and all only in include.
   Preview tests assert <=2MiB/item, <=24 cached items, <=8MiB total, bounded parallel
   requests and no stale-source image. Verify cancel leaves page/draft state intact.
4. At320/360/390/430dp show two genuinely distinct x positions in grid, horizontal
   rows in list. At2x/RTL keep controls usable without overflow. Cover 640dp viewport
   with560dp content, long source/version/status strings,10k lazy items and stable
   item-key anchors across view changes and stale callbacks after filters change.
5. Run analyzer and full test suite with live/destructive opt-ins unset. Capture
   real exit codes (`pipefail` or redirected command status), counts and environment
   skips; never count skip-only remote tests as real protocol acceptance.

## Isolated integration

Only the existing disposable NAS acceptance VM may be mutated. Pin machine-id
`3579bace85be432fa7cde6da46ad839b` and host key
`SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM`; verify before any writes.
Existing fixture SSH port22023 and retained private fixture credentials are
documented by prior VM tests; do not print credentials, change their identity, or
use production servers such as racknerd/krm. If identity cannot be confirmed, stop
that gate and report it; never guess a target.

Use a new isolated application instance and validated test data path. Check real
Docker ps Go-template inventory (including stopped conflicts), exact main/sidecar
names, and unchanged project/labels/aliases. Exercise child-only cleanup retaining
an unmounted sentinel, then whole-dataRoot cleanup removing only selected test
data; named volumes and genuinely shared/protected paths must remain protected.
Only remove material created by this isolated test; inventory/log targets first.

## Artifact and ADB

Build fresh release-mode Android x86_64 for the existing emulator with the original
compatible test certificate, not a replacement production certificate. Prior
certificate SHA256 was
`2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
Keep pubspec1.0.4+5, packagecom.antigravity.valhalla.valhalla. Read actual build/signing
scripts before use; isolate signing overrides to the subprocess, never print keys.
Preserve historical artifacts and record new file hash/size/time/ABI/signature.

Read-only ADB discovery first. Prior target127.0.0.1:14251 is an emulator, not proof
of physical-phone behavior. If another app/AI is active, report to root and wait
for exclusive testing before install/launch/tap. Verify installed signature before
`adb install -r`; mismatches must stop, never uninstall/clear to work around them.
After install, pull the actual base.apk, compare SHA256, record update time and
unchanged first-install time. Use foreground package guards before every scripted
tap; stop on interference rather than operating another application.

On the pinned fixture, capture screenshots and actual navigation for distinct file
and store views, directory picker paths/search/hidden/link entry, Docker agent cwd
when an isolated fixture is available, NAS source/library/include/exclude picking,
the first-entry Docker deployment route and existing-native informational state.
Exercise retained-data install/preview/uninstall UI on a disposable app only after
target checks. Inspect current app-PID logs for errors/ANR/overflow. Report exact
passes, failures and missing fixture cases; do not equate widget tests with ADB
or emulator rendering with physical-phone performance.

No gate in this document has been executed merely because this contract exists.
