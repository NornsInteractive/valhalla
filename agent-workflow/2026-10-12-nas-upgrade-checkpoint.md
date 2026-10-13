# NAS / selective uninstall implementation checkpoint

Follow-up: user subsequently explicitly requested a current-tree APK and ADB
acceptance. That candidate was built and retained-data installed; see
`2026-10-12-nas-device-acceptance.md` for current device evidence and limits.
The implementation gaps and widget failures below are not thereby resolved.

Incomplete iteration. No version bump, push, release, new APK or ADB install.
Root has NOT edited UI or run/authored tests. Production SSH targets, media and
application data were not changed. Original dirty workspace preserved.

## Implemented, pending full acceptance

- Selective uninstall preview/identity validation, protected/shared targets,
  explicit selection+acknowledgement, per-target results and confirmed cleanup-only
  retry. Independent review found and fixed renamed-descendant checks, overly
  broad ENOENT success, physical bind-alias protection, interrupted-worker retry,
  total operation budgets and bounded subprocess output. Not yet proven by
  actual helper fixtures or remote deletion tests.
- Official Jellyfin explicit software profile retains original template/identity,
  supports long/short bind syntax, removes only reviewed hardware mappings and
  enforces read-only Media. Existing generic privilege blockers still apply.
- Jellyfin-only native signed APT preview/install/reconcile with durable target
  identity, exact package versions, startup guards, loopback listener checks and
  failure containment. No actual native installation has been attempted.
- Album identity/metadata, date/group queries, bounded600-item bidirectional
  gallery, batch progress/Home queries, scan stages, source-scoped thumbnail
  ownership and configuration-bound connection diagnostics.
- Requirements, frontend design, architecture, roadmap and rules updated.

## Actual OpenCode evidence

Scratch: `/tmp/valhalla-nas-upgrade.X1GzDi1J`.
MiMo and Big Pickle rate-limited. Verified-zero-cost Nemotron3 Ultra and LongCat2.5
were used, with auxiliary small_model also fixed to a free model. Nemotron also
returned intermittent upstream503. Do not mistake a CLI exit/status for test success.

Three executed Flutter test batches:

1. `nas_offline_provider_test.dart`, `nas_organization_test.dart`,
   `application_center_ui_test.dart`, `application_path_flow_test.dart`:
   **58 passed /2 failed**. Includes existing100k migration and source/ordering
   regressions. Remaining failures are store320dp2xRTL13px overflow and Healthy
   app missing after a source refresh (not safe to dismiss as unrelated).
2. `nas_media_view_test.dart`, `ui_enhancements_round_test.dart`:
   **60 passed /0 failed**. AgY's batch-wrap/Home-selection fix is now covered.
3. `application_compose_test.dart`: **44 passed /0 failed** after fixing the
   short-bind software profile and test matcher/preview-blocker assertions.
   Raw direct output: `compose-profile-test-final2.log`.

First two actual runner outputs are inside `opencode-fake-compat.jsonl` tool
results. Its model-generated174-total/per-file summary is wrong; do not reuse it.
Actual combined result across these three non-full-suite batches is162 passed,
2 failed. This is not a full suite, security acceptance or device acceptance.

Analyzer fake override errors were fixed by OpenCode. Core style warnings were
fixed by the owning core agents/root. Final full analyze reports0 errors and
1 warning: AgY-only unused isTargetValid. Evidence `analyze-checkpoint-final.log`;
analysis is not clean until AgY fixes that warning.

OpenCode also syntax-compiled the actual embedded cleanup and native-install
Python scripts: both passed (`python-syntax-checkpoint.log`). This did NOT execute
either helper and does not replace safety fixtures or VM integration acceptance.

## UI blocker and remaining work

AgY original Valhalla completed baseline edits, then the NEXT redesign request
returned current429 RESOURCE_EXHAUSTED, reset24h40m40s. No account rotation or UI
handoff to another author. New classification redraw, uninstall selection,
Docker/native deployment and onboarding, diagnostics/cache UI are not implemented.
Resume exact tasks in `2026-10-12-nas-upgrade-ui-resume.md` after service recovery.

OpenCode's large cleanup fixture authoring request did not produce a test file
before being stopped after prolonged no-progress; not passed. Its log is
`opencode-cleanup-safety.jsonl`. Remaining checks: helper adversarial fixtures,
native task/unit/VM lifecycle, selected-directory sentinels, new gallery/reverse
edge cases, cache/source-diagnostic race tests, actual deployment→setup→source→
playback for both paths, complete suite, profile performance and retained-data ADB.
No user-facing build until product UI and safety/functional gates are closed.
