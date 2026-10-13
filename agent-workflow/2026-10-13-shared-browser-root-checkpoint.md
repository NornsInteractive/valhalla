# Direct verification checkpoint — not package delivery

Historical checkpoint: user subsequently authorized root UI ownership. The
remaining UI has now been implemented directly; current verification/artifact
status is in [UI takeover results](2026-10-13-ui-takeover-results.md).
Do not treat the AgY-only block or11/5 result below as the current state.

User granted this round's root/internal-agent regression, verification, build and
retain-data ADB authority. All authored app UI/ARB changes remain AgY-owned.
OpenCode processes were stopped before test ownership handoff. No commit/push,
release/version/signing change, app data clear or production mutation occurred.

## Green evidence

- Application core6files:194passed. Real local Python cleanup and Bash rollback
  fixtures are included; old8inventory fake failures fixed without removing guards.
- Catalog provider:36passed, including initial automatic/explicit single-flight,
  per-source publication, actual OS-locale events and stale-locale rejection.
- Browser/provider6files:75passed; browser core subsequently23passed after adding
  completed-stream cancellation regressions. These overlap, not independent totals.
- NAS main protocol tests72passed plus package SMB4passed; loopback HTTP/native SMB
  and local scan fixtures, no production services. Locale parity9passed.
- Stable native-deployment/naming/AppStore/uninstall UI4files:68passed, including
  320–430dp true two-column grid, long-version overflow, content-vs-viewport width,
  explicit ambiguous main, legacy names, opt-in root/child selection and real
  ALREADY_INSTALLED plus other blocker fixture.
- Isolated pinned NAS acceptance VM:4passed/0skipped, real Docker lifecycle and
  root/child cleanup. See app-data-vm-results.md for exact targets, deletions and
  retained audit/test data/volumes. No production or old user data was deleted.
- Scoped core and core-test analysis clean after formatting/lint fixes.

## Current red evidence / remaining UI

Latest shared component2files: **11passed/5failed**, exit1. Tests are retained, not
skipped or weakened:
1. File selections can confirm while loading.
2. File selections can confirm after partial-directory error.
3. Directory navigation leaves old preview permits occupied; new images never start.
4. Thumbnail cache read key disagrees with writes, no rendered bounded image.
5. Replacing source causes duplicate same-ID preview request.

SFTP caller15cases and ACP caller17cases migrated to real browser adapters with
in-memory transport; ACP wrapper's leftover old body currently references undefined
serverConnectionProvider twice. NAS8caller cases are authored/analyzed but its new
action entrypoints are not implemented. Do not call these suites passing.

Full analysis remains red in AgY-owned files: two undefined identifiers above,
unused wizard/CLI imports and store anchor field, deprecated dropdown value,
async context guards, and anonymous parameter style. Root fixed all reported
test/core-only issues but did not edit app widgets. See final analysis log for
current exact count. Full test suite was not run against knowingly incomplete UI.

Shared components are still incomplete; main Remote Files page and NAS source,
scan/library/deployment callers are not migrated. Three-view compatibility,
preview bounds/anchoring and all caller guards need component/wrapper acceptance
before final delivery gates. Current-source secure/metadata-save guard does not
make pre-existing separate stores atomic across a restart; no such claim is made.

## External blocker and precise resume

AgY was freshly restarted and authenticated the currently authorized account in its
runtime log. Original conversation ec81a4be-7543-45ee-8658-f68966f57d3b, explicit
gemini-3.8-flash-high/high. The latest component turn ended at step37566 with NEW
RESOURCE_EXHAUSTED429, reset2h44m48s. No token files read/rotated/overwritten. User
was asked to restore a usable login or wait; this is not an inference from old logs.

Use the same conversation in small batches after login/quota recovery:
1. 2026-10-13-browser-component-only.md and the two current regression test files.
   Avoid reading the entire generated app_localizations.dart repeatedly; existing
   labels are available by targeted search of app_en.arb. Do not rescan whole UI.
2. 2026-10-13-browser-wrappers-only.md, then15+17caller cases.
3. 2026-10-13-shared-browser-ui-phase4.md, including main-page reuse and NAS8cases.
4. Generate locales, format only task files, full analyze/full suite; fix red gates.
5. Fresh compatible test-signed release-mode x86_64 APK, signature/hash check,
   retain-data ADB install and pinned-fixture UI checks. No publish/version bump.

Evidence directory: `/tmp/valhalla-browser-implementation.NXfb1raa`.
Key files: root-stable-first-slices.log, root-component-checkpoint.log,
root-catalog-tests.log, root-core-analyze2.log, root-test-analyze2.log,
root-final-checkpoint-analyze2.log, agy-component.log/jsonl.

## Build/ADB truth

No fresh APK was built or installed this iteration. Read-only discovery found
127.0.0.1:14251 Androidx86_64 emulator, foreground Valhalla, old version1.0.4/native
4005, last update2026-10-13 15:37:59, first install2026-09-23 03:26:04.
Existing debug test certificate fingerprint matches the prior compatible cert;
no keystore/signing configuration was changed. No install/launch/tap was executed.
Do not reuse historical APK hashes/screenshots as this iteration's acceptance.
