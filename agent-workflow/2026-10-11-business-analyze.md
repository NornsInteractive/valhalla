# Business Analyze — 2026-10-11

Command: `flutter analyze --no-pub` (first action, run before any test work)
Result: **0 errors, 0 warnings, 5 info-level lints.** Analysis completed in 7.5s.

Scope guard: no production files were edited for this analyze/report step.
Production edits remain owned by Codex (source) and AgY (UI).

## Issue list with exact source locations

Counts by rule:

| Rule | Count | Level |
| --- | --- | --- |
| `curly_braces_in_flow_control_structures` | 4 | info |
| `use_null_aware_elements` | 1 | info |

Total: 5 issues.

### 1. `use_null_aware_elements` — null check that can use the null-aware element marker

- File: `lib/core/services/app_update_service.dart`
- Location: `lib/core/services/app_update_service.dart:94:32`
- Column 32 on line 94.
- Offending pattern is a conditional `if (x != null)` used to add an element to a collection literal, which the `use_null_aware_elements` lint rewrites to the `?element` marker.
- Layout sanity check: line 94 sits inside `app_update_service.dart` between `:144:14` and `:185:41`, i.e. before the two curly-brace hits, consistent with a decode/parse helper earlier in the file.

### 2–4. `curly_braces_in_flow_control_structures` — single statement `if` needs a block

- `lib/core/services/app_update_service.dart:144:14` — column 14 of line 144.
- `lib/core/services/app_update_service.dart:185:41` — column 41 of line 185.
- `lib/features/dashboard/dashboard_provider.dart:140:29` — column 29 of line 140.
- `lib/features/docker/docker_provider.dart:124:27` — column 27 of line 124.

Each hit is an `if` (or `else if`) whose body is one unbraced statement. The lint is purely stylistic; behavior is unchanged. Owners should brace the statement when they next touch those files (app_update_service.dart is Codex source; the two provider files are feature/UI-adjacent, AgY/Codex).

## Files touched by analyze hits

- `lib/core/services/app_update_service.dart` — 3 hits (1 x `use_null_aware_elements`, 2 x `curly_braces_in_flow_control_structures`)
- `lib/features/dashboard/dashboard_provider.dart` — 1 hit
- `lib/features/docker/docker_provider.dart` — 1 hit

## Interpretation for the follow-up test work

None of the 5 lints are blocking, and none are in the areas targeted by this task's tests
(`app_update_service` model parsing is adjacent to the update service file, but the lints are
style-only and do not affect parsing semantics).

Related areas to keep in scope for targeted tests (per task):

- `app_update_service` model parsing: version, build, platform identity, hash
- `app_update_service` fake HTTP boundaries (mocked official interface, no real network)
- terminal_keys: ctrl / alt handling, normal vs application cursor mode
- LocalStorage: bounded page cache, target separation, pinned persistence

No ADB, no full test suite, and no builds were run as part of this step.
