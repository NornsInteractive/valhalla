# AgY OAuth last-mile verification

UPDATE after wt1.log: Original AgY fixed the genuine manual-dialog controller
lifecycle and constrained the draft auth card. Its status is FINAL READY in
2026-10-03-agy-login-dialog-fix-status.md; console exited0. Product lib is NOW
different from the 13:40 APK, so the earlier tests-only/no-rebuild clause below
is superseded. Need fresh gates then release rebuild/install-r, no new OAuth
account actions or inference. Root will reissue the final build task after the
current test investigation stops; do not claim installed APK contains this fix.
Remove any temporary framework probe from final suite after recording evidence;
retain strict actual app regressions. Fixture failures contaminated later tests,
so re-run each case cleanly. Never suppress Flutter exceptions in actual cases.

Continue existing OpenCode session ses_f0405efacffePPqWyhHc3GGJY7.
Main/small model: opencode/mimo-v2.6-flash-free. Phase 2 exited 0.
Product lib/ARB is stable; no product edits, no git mutation or further device
account authorization. All testing remains OpenCode-owned; UI defects go to
original AgY and infrastructure/provider defects to root. Use Edit/apply_patch
for files, no shell writes. Preserve unrelated work.

## Required missing proof

Add focused widget regressions using existing provider harness / fake platform
launcher, without changing product lib/ARB or adding a production abstraction:

- New validated auth request auto-opens once, repeated rebuild does not relaunch.
- False/throwing browser launch shows localized fallback; reopen works explicitly.
- Manual callback dialog masks input, rejects invalid/full mismatched callback,
  supports retry/cancel; never leaves controller contents or logs containing codes.
- Cancel pending auth does not show success snackbar; only confirmed RPC does.
- Auth controls / manual dialog at 320dp with 2x text scaling remain reachable,
  scrolling permitted, no layout exceptions. Use short synthetic dummy URLs only.

Run focused tests first then full analyze / full tests against final state. If
source defects appear report exact evidence; do not bypass guards or weaken
assertions. Tests-only changes do not require another unchanged APK build/ADB
install. Record whether the product source stayed identical to installed APK.

Run format CHECK ONLY (--output=none --set-exit-if-changed) on this round's
actual product paths: sanitizer.dart, ai_chat_provider.dart, builtin_agent_preset.dart,
agent_repository.dart, acp_oauth_request.dart, acp_ssh_transport.dart,
acp_client_adapter.dart, agent_environment_service.dart, ai_chat_view.dart,
agent_management_view.dart, and generated l10n. Report any failing paths to owners;
do not claim 13 tests + generated l10n proves all touched lib files formatted.
Do not format unrelated existing files. Format your new tests normally.

## Evidence corrections

Update 2026-10-03-agy-login-verification.md accurately via Edit:

- Scope format gate exactly; 34 whole-repo issues are not proof of *all* touched
  lib paths being clean, nor of their age. No invented baseline attribution.
- Restored chatCommandsDraftPreviewNotice key was upstream ARB restoration AND
  regeneration, not generation alone while the EN key had been deleted.
- Redact private SSH hostname/IP/port from this report and initial device report;
  refer to server racknerd only. Raw evidence remains private and must not be
  committed/published; do not edit screenshots/XML needlessly.
- SSHStateError observed at 05:42:32Z before explicit ACP login: stack indicates
  SSH close, not complete root-cause attribution or proof of no relation. Record
  as unresolved diagnostic finding; no generic reconnect changes in this task.
- Disclose temporary adb root for diagnostic log only, then unroot (already done),
  no credentials/databases read. Do not repeat root or any account/data mutations.
- Complete Google account authorization, real callback to remote and inference
  remain pending user; host browser opening was verified, Docker protocol routing
  was simulated, not device OAuth verified. No more device actions necessary.

Stop when these proofs are recorded, report gates/counts and actual gaps.

## Root testing dependency clarification

Root has now declared the ALREADY RESOLVED url_launcher_platform_interface 2.3.2
as a direct dev_dependency in pubspec.yaml so the official platform fake can be
imported without disabling any analyzer lint. Run flutter pub get and use a
test-only subclass of UrlLauncherPlatform, setting/restoring its instance in
setup/teardown. No need to reverse-engineer generated Pigeon channels or add a
product factory/launcher abstraction; public launchUrl override can return false,
throw, or succeed and record dummy URLs. No real browser launch in widget tests.
Runtime lib/ARB and selected production package versions are unchanged, although
pubspec's test-only metadata and lock dependency classification will change;
describe APK equivalence at that precise scope, not byte identity of pubspec.
