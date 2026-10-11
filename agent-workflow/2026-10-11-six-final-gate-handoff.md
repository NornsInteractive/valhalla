# Final gate and data-preserving ADB handoff

Requested, NOT executed. Do not reuse v1.0.4 release or historical2441 baseline.

Start only after AgY finishes its latest six-ui-review-followup corrections and
all test writers settle. Original Valhalla only, model/effort fixed. Production
UI/ARB belongs AgY; business fixes belong Codex. OpenCode owns checks/format,
generation/build/ADB, with explicitly confirmed-free main AND small models.

1. Generate localizations using supported `flutter gen-l10n` arguments (the
   earlier `--no-pub` attempt was invalid). Check authored17-locale key/placeholder
   parity, generated zh_Hant output too; no empty keys or English cloning.
2. Format only task-owned changed Dart files. Analyze whole project, zero issues.
3. Execute focused new tests and full foreground suite with unfiltered logs and
   shell pipefail, capture actual exit. Wait natural completion; counts/skips
   and reasons must be recorded. No expectations deleted to get green.
4. One unexplained29-test NAS combined failure remains in six-nas-acp-validation.
   Preserve its uncertain attribution and lost original assertion. No repeat
   loops claiming a fix. If current checks fail, retain unfiltered evidence and
   diagnose the exact assertion. Prefer adapter/completer events over unbounded
   timing guesses for async IO fixtures; never change production to suit a fake.
5. Verify new editor restored-draft/Keep flush/failure/duplicate-exit checks,
   service log mutual exclusion/error retention/narrow RTL, thumbnail revision,
   captured owner-release on dispose and service switch, cache operation failure
   and explicit player retry. Existing protocol tests do not prove real agents.
6. Build locally from the EXACT settled workspace; preserve1.0.4+5. Inspect
   connected127.0.0.1:14251 ABI, installed version/certificate/firstInstallTime.
   Existing release signing must not change. If installed original debug cert,
   use separately staged original-debug-certificate release-mode test APK as
   already authorized, not the public release keystore. Keep signing material
   outside source; never print passwords/private keys. Verify final APK hash,
   source fingerprint, version, cert, build timestamp and toolchain.
   Fingerprint source only: tracked runtime/native/assets/pubspec files plus
   task-owned new source (e.g. nas_thumbnail_image.dart). Exclude .gradle/build/
   .dart_tool/local.properties, signing material and test/report logs. A plain
   recursive hash of android/ would include generated caches and is not proof
   of settled source; use git source selection plus owned untracked files.
   Current installed split x86_64 APK is code4004. Preserve pubspec1.0.4+5 and
   build the x86_64 split variant (`--target-platform android-x64
   --split-per-abi`), expected code4005. A universal code5 APK is a downgrade;
   do not use adb downgrade flags, change source version or uninstall to bypass
   that. Inspect actual badging before install, don't infer ABI-offset code.
   Tooling note from actual build: this Flutter version skips release plugin
   registrant regeneration with `--no-pub`; a test-generated integration_test
   entry can then fail native javac. Use the normal release build without that
   flag and verify pinned lock/source fingerprints unchanged. Do not hand-edit
   generated registrants, remove the test dependency or clear shared caches.
7. `install -r` only on exact inspected adb transport (`127.0.0.1:14251` in
   current preflight, not hardware property `EMULATOR37X1X11X0`); recheck online
   state and certificate before installing. No uninstall or data clear.
   Verify installed APK hash/cert/version and unchanged firstInstallTime, launch
   read-only smoke. Menu navigation/dialog cancel/input focus, cached data,
   experimental default-off/previous preferences, 320dp/2x/RTL if feasible.
   No production process/service/container/power changes, agent prompts/history
   writes or automated Google consent. Preserve configured Racknerd target.

No git commit/push/Release/Actions/cloud build authorized. No shared-cache
cleanup. Final report must distinguish source checks, mocks, emulator and real
device/server results; unverified real ACP/OAuth/NAS/platform paths stay explicit.
