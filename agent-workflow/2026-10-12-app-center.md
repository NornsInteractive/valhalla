# Experimental Docker application center

## Accepted outcome

Opt-in application center, initially disabled, installing applications on the
currently selected SSH server. CasaOS/ZimaOS v2 catalog and custom HTTPS sources;
confirmed Docker/Compose bootstrap; default loopback binding and SSH browser
access; open/start/stop/restart/logs/edit/manual-update/uninstall preserving data.
Mobile full-screen configuration, desktop bounded dialog, Store/Installed/Tasks.
Use root-owned business contracts below; UI only original AgY Valhalla,
ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high, effort high.
Tests/build/ADB only OpenCode explicit opencode/mimo-v2.6-flash-free initially;
previously authorized verified-free alternatives on upstream unavailability.
Prior direct-validation exception was task-specific, not reused here.

## Scope and current evidence

Existing uncommitted core-stability changes are preserved. Public version stays
1.0.4+5, no Git push/release/Actions. Docker installation limited to supported
Debian12/13 and Ubuntu22.04/24.04/26.04 amd64/arm64; other hosts with working
Docker Compose can deploy compatible images. Official v2 source at
https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages currently serves
store.json/index.json (version2, 178 entries). Paths beginning /apps refer to the
store prefix, not necessarily the HTTP host root. content_hash is an incremental
change marker, not a cryptographic integrity guarantee.

No arbitrary host scripts, build contexts, special-device/privileged apps, legacy
ZIP stores or native fnOS packages in v1. No automatic app upgrades or data erase.
Data recovery is not inferred from restoring Compose/image configuration.

## Implementation sequence

1. Catalog/cache, declarative Compose adaptation and configuration contracts.
2. Remote environment, persistent detached task and ownership/reconciliation.
3. Current-server provider, access forwarding, experimental navigation contract.
4. AgY UI integration and localized controls.
5. OpenCode regression, analyzer/full gate, isolated deployment if available,
   compatible-signature ADB install preserving existing configured data.

## Current checkpoint

Core source and original AgY's initial UI/17 ARBs are present. Private deployment
metadata now lives outside container-writable data directories. Previous image
IDs are pinned before updates; bootstrap refuses package removals. Workers have
bounded logs and PID/start/boot identity checks. Catalog/template/image caches,
server-epoch guards, task intent persistence and safe-cancel stages implemented.

Original AgY follow-up first hit Google avatar network timeout, then reconnected
successfully with requested model/effort and is applying root review findings.
OpenCode MiMo retry was rate-limited; verified-zero-cost Nemotron 3 Ultra Free
is responding under prior free-fallback permission, no root direct-validation
exception used. Pub get/gen-l10n completed; initial analyze found 23 issues,
core three lint findings fixed and authored UI findings returned to AgY. New
regressions, final gate, actual VM deploy and APK/ADB not completed yet.

No user server or real agent history mutated, no version bump/Git push/Release.
Existing isolated VM assets were located read-only; no daemon currently runs.
Validator may resume only that documented disposable fixture, not production.
Details: [UI review](2026-10-12-app-center-ui.md),
[verification contract](2026-10-12-app-center-validation.md).

Later checkpoint: Nemotron 3.5 Lightning free completed 14 actual catalog tests.
Its Compose test draft remains incomplete and has weak assertions; not accepted
as coverage. Ultra encountered upstream 504/503 while authoring; MiniMax M3 and
Qwen 3.6 free returned CLI server errors before executing. A commands-only Ultra
run successfully regenerated latest ARBs, formatted changed files and analyzed:
no authored library/UI errors, 127 core flow-control lint infos and remaining
test-draft errors (156 total). No overall clean gate claimed. Automated lint /
test-import repair delegated back to Ultra. Original AgY completed second
correctness follow-up (variables/environment, directories, stages, image guards)
within UI whitelist, still unverified on device. Workers, persistence/races,
cache network behavior and real deploy/ADB remain required work.

Latest checkpoint: OpenCode repaired the draft assertions against the actual
public API. Catalog/Compose/worker suites now have 49 passing cases, including
real `bash -n` for all nine operations and both bootstrap paths. A prior source
snapshot analyzed clean; the latest installed-template/network-alias/expanded
YAML bounds changes still require final analysis and full regression.

Configuration reads the private installed template, not the current store
version; configure/start pin existing container image IDs and use `--pull never`.
Only explicit install/update pulls. Restore retains template/configuration/image
snapshots, but never claims to restore databases or container data. Original
AgY completed stable wizard controller keys and the installed-template caller;
authored UI remains unverified until current OpenCode widget/device gates.
Cache/persistence/provider/UI tests and a pinned disposable-VM deployment run
are in progress. No current APK build or ADB install claimed.

Final checkpoint for this turn: the latest three core suites actually passed
62 cases. A genuine network-alias Map<String,Null> mutation failure was repaired
with an explicitly typed map. Original AgY added pre-confirmation validation so
clearing a port cannot silently reuse the previous valid value. Worker verifies
host/daemon identity after its server lock and again after pulling; default
interpolation dollars stay literal, non-boolean privilege requests are blocked.
Open uses freshly reconciled endpoint metadata after configuration/restore.

Remaining validation is interrupted, not completed: three OpenCode runs returned
certificate-verification errors. New cache/provider/widget/VM test drafts still
need compiler/assertion repair and cannot be claimed as coverage. No TLS bypass,
root test/build execution, APK/ADB, release or push. The original isolated VM was
resumed by OpenCode and left online with all existing data preserved. Resume
OpenCode or obtain this turn's explicit validation-ownership exception before
the final full gate and compatible-signature installation. Evidence in the
verification contract takes precedence over earlier in-progress checkpoints.

## Completed direct-validation continuation

User authorized root testing/packaging for this continuation. Root replaced the
unfinished test drafts (backups preserved), fixed image-cache Future self-wait,
and validated **2582 passed / 19 environment skips / 0 failures**, analyzer clean.
Pinned VM lifecycle and checked HTTP/data-preservation acceptance passed twice,
latest3m03s. Original AgY alone fixed mobile footer overflow and mount-label
translations; real Inter-font mobile tests pass4, core application-center74.

Three fixed-release-certificate Android APKs actually built and were frozen,
signature/version/hash verified at `build/app-center-validation/`. Local build
first hit global Gradle init policy then stale dev plugin registration; task-only
Gradle home plus official Flutter generation solved both without global/SDK edits.
Version remains1.0.4+5, no release/push/Actions/other-platform builds.

Separate original-debug-certificate x86_64 Release-mode test APK built successfully.
`adb install -r` was issued but device Shell/crash-log reads each timed out20s;
after4min only the three specifically verified task-owned ADB client processes
were terminated (install/launch/package query), not the server or other projects.
Installation/launch outcome is **unknown**, not automatically resubmitted. No
uninstall, data clear or downgrade. Once device responds, inspect update time,
certificate and process before deciding whether installation needs retry.
Detailed evidence and signatures remain in the validation document.

ADB recovery completed: after user restored the device, exact installed APK hash
showed the old attempt had not committed. Signature/version-compatible `install -r`
returned Success; new installed hash equals the frozen device-test APK. Cold launch
reported ok (988ms), process remains live and existing saved-server dashboard is
visible without clearing data. No experimental switch/server mutation, rebuild,
push or release. Only installation/startup smoke is claimed, not physical-device
performance or exhaustive on-device application-center workflows. Latest validation
document supersedes the earlier unknown installation status.
