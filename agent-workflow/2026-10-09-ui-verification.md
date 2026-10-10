# UI verification — gen-l10n + analyze (step 1, verification only)

Date: 2026-10-09 (UTC). Scope: verification ONLY. No UI/ARB/business/test/business
edits, no build, no device, no git, no subagents. Full raw output:
`agent-workflow/2026-10-09-ui-analyze.log`.

## Commands and real exit statuses

| Command | Exit status | Notes |
|---|---|---|
| `flutter gen-l10n` | **0** (success) | Used l10n.yaml options. Localizations generated; ARBs are structurally valid. |
| `flutter analyze` (whole project) | **1** (failure) | 43 issues: 11 errors, 8 warnings, 24 info. |

gen-l10n regenerating successfully means an absent `l10n.close` is a genuinely missing
ARB key, not a generation problem.

## Issue classification

### A. UI/authored-file errors (AgY scope, in-progress — 10 errors in lib/)

All errors are in UI files from this round; none are in core providers/services except
one info lint (see B). Symptom map:

- **`VRadius.badge` undefined getter (5 errors)**
  `lib/features/docker/widgets/docker_mounts_summary.dart:38,90,111`,
  `lib/features/docker/widgets/docker_project_card.dart:80`,
  `lib/features/files/widgets/remote_file_batch_results_dialog.dart:123`.
  `VRadius` (`lib/core/design/tokens.dart:13`) only has `input`, `button`, `card`,
  `cardLarge`, `dialog`, `sheet`, `pill` — no `badge`. Callers need an existing token
  (or an owner decision to add one); nothing was changed.
- **`PlatformFile.files` undefined (2 errors)** `configuration_migration_dialog.dart:79,81`,
  alongside deprecated `withData` (:75) and a spurious null comparison (:79). Matches the
  open checklist item to move to `withData:false`/`withReadStream:true` with bounded reads
  — the partial edit currently references a `files` getter on `List<PlatformFile>` that does
  not exist.
- **Connection-key record vs String (1 error + 3 infos)**
  `sftp_directory_picker_dialog.dart:60` assigns `(String,String,int,String,AuthType,String?)?`
  to `String?`; unrelated-type equality checks at :67,:84,:105. Matches the open checklist
  item: capture a `ServerProfile` and compare `hasSameConnectionSettings`. The
  `server_profile.dart` import at :10 is currently unused (warning), consistent with a fix
  in progress.
- **`build` invalid override (1 error)** `trusted_hosts_dialog.dart:92` — `build(BuildContext, WidgetRef)`
  in non-Consumer `State`.
- **`l10n.close` undefined (1 error)** `trusted_hosts_dialog.dart:278` — no `close` key exists in
  any `lib/l10n/*.arb`. Needs a new key in all locales (or reuse of an existing key).

### B. Core production lint (Codex-owned file, info only — not fixed)

- `prefer_interpolation_to_compose_strings` `lib/infrastructure/sftp/remote_file_actions.dart:61`.

### C. UI warnings (AgY scope — 6)

- 4x `unnecessary_null_comparison` (always true): `docker_view.dart:75,105,150,176`.
- 1x `unnecessary_null_comparison` (always false): `configuration_migration_dialog.dart:79`.
- 1x unused import `data/models/server_profile.dart`: `sftp_directory_picker_dialog.dart:10`.

### D. Test/tool issues (other OpenCode sessions own core tests — in-progress, NOT fixed)

- **1 error** `test/core/security_settings_regression_test.dart:38`: fake
  `FlutterSecureStorage` misses 15 abstract members (`checkUpgradeStatus`,
  `isCupertinoProtectedDataAvailable`, `registerListener`, `unregisterAllListeners`, ...)
  — consistent with `flutter_secure_storage` 11.1.1 API surface.
- 2 warnings: `override_on_non_overriding_member` (security_settings_regression_test.dart:115),
  `unused_element_parameter` (test/infrastructure/remote_file_actions_test.dart:10).
- 2 test infos (`annotate_overrides`): remote_file_batch_contract_test.dart:237,
  docker_project_lifecycle_test.dart:124.
- 2 tool infos (`avoid_print`): `tool/probe_sanitize.dart:28,29`.
- 19 UI-file infos: 11x `unnecessary_underscores` (newer wildcard-parameter style),
  3x `unrelated_type_equality_checks` (sftp_directory_picker, see A), 1x deprecated `withData`
  (configuration_migration), 4x deprecated RadioListTile `groupValue`/`onChanged`
  (`default_agent_dialog.dart:134,135,179,180`).

Totals: A=10 errors; B=1 info; C=6 warnings; D=1 error + 4 warnings + 6 info.
11 + 8 + 24 = 43 issues, matching analyzer summary.

## Checklist status (analyze evidence only)

Still failing compile (owner action required): trusted-host dialog (`build` override,
missing `close` l10n key); Files picker connection-key record handling; migration dialog
picker/size-check rewrite; `VRadius.badge` token (5 sites); docker_view null comparisons.
Not provable from analyze (needs runtime/test evidence): `defaultAgentSettingsProvider`
watch/label refresh, revoke busy-guard/mounted checks, bookmark toggle error handling,
queued-vs-completed download wording, delete/move/copy failure label vs
`nasDownloadFailed`, 320dp/2x layout, export secret-warning preview, PopScope guards,
no-new-lint-ignore compliance. No compile error suggests `nasDownloadFailed` misuse or
blanket new ignores exist, but analyze cannot verify wording/behavior.

## Notes

- Generated localization output may have changed; that was the only file-gen effect of
  these commands. No other file was modified.
- Whole test suite NOT started (per instruction; awaits main follow-up).
- Test-session failures are reported separately above; they do not block AgY's UI fixes
  and are owned by the core-test session.
