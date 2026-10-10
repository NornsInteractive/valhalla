# Completion dialogs verification — 2026-10-10

- **Agent:** OpenCode verifier session (user-authorized test work only)
- **Scope:** widget regression tests for the five-module completion dialogs
- **Authored file (owned):** `test/features/completion_dialogs_test.dart`
- **Report (owned):** `agent-workflow/2026-10-10-dialog-verification.md`
- No production/UI/ARB/generated files, no existing tests, no global config, no
  build/git/ADB/remote commands were touched.

## Commands and results

```
flutter test test/features/completion_dialogs_test.dart --reporter expanded
  → EXIT_CODE=0   (9/9 passed)   log: first green run after UI fixes landed
flutter test test/features/completion_dialogs_test.dart
  → EXIT_CODE=0   (9/9 passed)   confirmation re-run
```

L10n generation, formatting, project-wide analyze and the full suite were NOT
run — deferred until main declares the UI ready (AgY still editing UI/ARB).

## Cases (9)

Trusted hosts dialog (`lib/features/settings/widgets/trusted_hosts_dialog.dart`):
1. Long `hostPort` + 139-char SHA-256 fingerprint at 320dp with 2x text:
   renders, no exception, copy/revoke/close actions preserved.
2. Revoke confirmation: dialog lists the exact `hostPort`, cancel/confirm
   actions, single `revoke(hostPort)` call, revoked snackbar.
3. Revoke busy/error: confirmation during pending revoke shows indeterminate
   progress and ignores a second tap (revoke called once); a thrown revoke
   error surfaces as a snackbar, the dialog stays mounted and retryable.

Docker project confirmation
(`lib/features/docker/widgets/docker_project_confirm_dialog.dart`):
4. Exact list at 320dp/2x: title, count message, both long Compose service
   names, `(container name)`, short IDs; cancel returns false; then desktop
   surface (1280x800 @2x) re-renders without overflow and confirm returns true.

Configuration export preview
(`lib/features/settings/widgets/configuration_migration_dialog.dart`):
5. `ConfigExportPreviewDialog` (new): secret warning callout before save,
   count chips scoped inside `Chip`, expandable endpoints/agents/quick-commands
   previews with FULL command text in `SelectableText` (agent login script and
   `vault kv put ... token=SUPERSECRET-TOKEN-VALUE`), cancel returns false and
   nothing is saved implicitly.

Configuration import preview (same file):
6. Desktop size: secret warning, count chips, global-preferences checkbox OFF
   by default, expandable command preview with full selectable text, confirm
   appends with fresh IDs (bookmarks remapped to the new server ID).
7. Failure path: orphan agent reference makes import throw
   `FormatException: CONFIG_AGENT_INVALID`; error stays visible inside the
   dialog, confirm button remains, storage stays empty (dialog not dismissed).

File bookmarks dialog (`lib/features/files/widgets/file_bookmarks_dialog.dart`):
8. Busy/error guard: gated toggle keeps the add/remove buttons disabled and a
   second tap is ignored (toggle called once); a thrown toggle error surfaces
   as a snackbar and the dialog stays mounted.
9. Stale target: after the active server switches while the dialog is open,
   the dialog closes automatically with zero toggle/navigation calls; a freshly
   opened dialog bound to the new server's current path toggles normally
   (`/var/www/beta` saved) — no stale `currentPath` reuse.

## Harness (mirrors `remote_files_ui_contract_test.dart`)

- `AppLocalizations.localizationsDelegates` + `supportedLocales`, `locale: en`,
  global `TextScaler` override via the `MaterialApp` builder.
- Riverpod `overrideWith/overrideWithValue` fakes: `TrustedHostsNotifier`,
  `FileBookmarksNotifier`, `ActiveServerNotifier`, real `LocalStorageService`
  over mocked `SharedPreferences` for migration submit assertions.
- Sizing: `tester.view.physicalSize`/`devicePixelRatio` (320dp: 960x2400@3x,
  360dp: 1080x2400@3x, desktop: 2560x1600@2x), reset via `addTearDown`.
- Deterministic busy windows use `Completer` gates; bounded
  `pump(Duration)` helpers are used while indeterminate `CircularProgressIndicator`
  animates (`pumpAndSettle` would time out).

## Fixture issues found in my own draft (fixed, not suppressed)

- Revoke busy case: initial draft used `pumpAndSettle` while the indeterminate
  spinner animated → timeout. Replaced with bounded frame pumping.
- Bookmarks tests: missing `activeServerProvider`/`localStorageServiceProvider`
  overrides made the dialog fall through to the real storage provider
  (`UnimplementedError: LocalStorageService must be initialized`) and destroyed
  the element. Added the captured fake active-server notifier plus a real
  storage instance over mock prefs.
- Count assertions: `Servers (1)` etc. text is duplicated in `Chip` labels and
  the `ExpansionTile` subtitles; assertions are now scoped `find.descendant(of:
  find.byType(Chip), ...)`.
- Exact text mismatches in my draft: endpoint subtitle is
  `user@host:port (authType)`, agent login line is `ssh-add <TOKEN>` inside
  `SelectableText`; switched to `textContaining`.
- Off-screen `ExpansionTile` titles needed `ensureVisible` before tapping.
- Removed my own speculative "dialog outer width <= 640" assertion — not a
  requirement from the contract and measured against `AlertDialog` intrinsic
  sizing; real modal-width behavior of the inner content was not weakened.

## Genuine UI findings (real failures, not suppressed)

Observed during the first green-iteration runs and confirmed fixed by AgY:
- `DockerProjectConfirmDialog` overflowed vertically (213px) at 320dp with 2x
  text; `file_bookmarks_dialog.dart` current-path row overflowed horizontally
  at 360dp. Both were caught by these tests (layout `takeException` + framework
  exceptions) while AgY was mid-edit; AgY's updated dialogs
  (`docker_project_confirm_dialog.dart` 01:18, `file_bookmarks_dialog.dart`
  01:18) now lay out cleanly and the full file is green. No assertion was
  weakened to hide either.

## Residual coverage notes (honest blockers)

- Export/import *file* flows (`FilePicker.saveFile`/`pickFile`) are not executed
  in widget tests (platform channels unmocked); only the preview/confirmation
  dialogs are covered here.
- Import submit double-tap disable and `PopScope` guard during submit are
  visible in the production code but asserted only indirectly (dialog retained
  on failure); not separately pinned.
- 320dp/2x coverage for the export/import preview dialogs is limited to their
  desktop/360dp renderings; the two overflow-fix dialogs are pinned at 320dp/2x.
- Full-suite, analyze and l10n regeneration remain deferred per main's gate.

## 320dp/2x narrow rerun — 2026-10-10 (13 cases)

```
flutter test test/features/completion_dialogs_test.dart --reporter expanded
  → EXIT_CODE=1   (12/13 passed)   log: /tmp/opencode/dialog_narrow_final3.log
```

Fixture-only patches applied to the owned test file (dart format after):
- Narrow default-agent test: added `tester.scrollUntilVisible` on
  `find.byKey(Key('default_agent_agent-default-2'))`, delta 150,
  `scrollable: find.byType(Scrollable).last` immediately before the second
  agent text/key assertions — the lazy `ListView` must build the row; it is a
  build issue, not a UI bug.
- Narrow export test: `find.byType(FilledButton)` →
  `find.byWidgetPredicate((widget) => widget is FilledButton)` because the
  restored `FilledButton.icon` button is a private `_FilledButtonWithIcon`
  subclass that `byType` does not match.
- Deleted two `debugPrint('DEBUG ...')` snippets; nothing else changed.

Exact residual failure (1 of 13):

- `320dp 2x narrow previews > default agent dialog: long agent names, cancel
  works` fails at `expect(find.textContaining(server.name), findsOneWidget)`
  (test file line 862): `Actual: _TextContainingWidgetFinder: Found 0 widgets
  with text containing production-edge-bastion-cluster-node-01`. Cause is in
  the dialog source (`default_agent_dialog.dart:119-141`): the server name is
  the subtitle of the FIRST `RadioListTile` ("Automatic") inside the lazy
  `ListView(shrinkWrap: true)`; after scrolling to
  `default_agent_agent-default-2` that first tile falls outside the cache
  extent and is unmounted. Not a UI overflow and not suppressed. Fix options
  for main/AgY: assert the server name before scrolling (test-side, not yet
  authorized in this patch) or hoist the server name out of the scrolling row
  (UI-side). All other 12 narrow/desktop cases pass, including the previously
  failing clear-credentials and export narrow cases.

## Final fix (2026-10-10): narrowDefaultAgent assertions moved before scroll

- File: test/features/completion_dialogs_test.dart (only file touched).
- Cause: server.name is the subtitle of the Automatic tile (first ListView
  item) and the default_agent_agent-default-1 tile is the second item; both
  unmount once scrollUntilVisible brings default_agent_agent-default-2 into
  view, so the post-scroll finders matched nothing.
- Fix (move only, no assertions deleted or weakened): expect(find.textContaining(server.name), findsOneWidget) and
  expect(find.byKey(Key('default_agent_agent-default-1')), findsOneWidget)
  now run before scrollUntilVisible; the codex agent text and
  default_agent_agent-default-2 key remain asserted after scrolling; cancel
  tap and no-overflow expectations unchanged.
- Verification: dart format test/features/completion_dialogs_test.dart
  (0 changed); flutter test test/features/completion_dialogs_test.dart
  --reporter expanded > /tmp/opencode/dialog_narrow_final4.log
  -> "All tests passed!" 13 tests, ACTUAL exit code 0.
