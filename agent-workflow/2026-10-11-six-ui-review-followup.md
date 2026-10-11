# AgY review follow-up (same original conversation only)

Review observed the first Phase A diff; main does not edit UI. Address these
before final acceptance alongside Phase B. This file is a review request, not a
claim of completed fixes.

- Restored same-revision drafts are unsaved too. Core now exposes nullable
  `notifier.editorOriginalContent` (snapshot content, not restored content).
  Initial dirty compares editor text with this baseline (fallback loaded content
  for mocks/unsupported implementations). Recompute on changes, including undo,
  and actually rebuild the dirty indicator. A conflict is never silently clean.
- Discard/reload must not swallow draft-deletion errors then pop/reopen and
  accidentally restore the undeleted draft. Keep the text and provide the error
  with copy/retry. Prevent concurrent exit dialogs, reload/save/flush overlaps.
- Reload and all async paths recheck both captured token and captured
  connectionKey; an old dialog must not reopen a file on a changed target.
  Close route safely after await; do not access disposed controllers/context.
  Dispose TextEditingController when the editor route completes, not earlier.
- Log dialog refresh and load-older cannot overlap; on errors recheck target and
  localize SERVICE_PERMISSION_DENIED / UNSUPPORTED / QUERY_FAILED / TARGET_CHANGED.
  Existing logs stay visible on failure, with a visible non-blocking error/retry.
  No hard-coded '(Cap: 1000 logs retained)' English; add all 17 authored locales.
  Avoid repeated no-op older fetch when fewer than a full page/end reached.
- Service status/startup/action row, logs timestamp/message row and editor
  conflict actions must fit 320dp at 2x text without overflow, RTL included.
- Nonzero process/service results also use localized code mappings where
  available (PID reuse returns PROCESS_IDENTITY_CHANGED in stderr). General
  exit errors can retain sanitized diagnostics; don't pretend every error throws.

Additional core follow-up: beginning a new file read clears the old snapshot,
draft identity and editing content. A failed reread of the same path must not
re-expose old content under the new token or allow saving via an old snapshot.
Valid draft text after an over-limit edit clears that size error, so retry works;
failed old writes cannot show a banner in a new editor even on the same path.

NAS owner lifecycle: capture the releasing notifier/service when requesting;
do not read an already-disposed WidgetRef in dispose, and don't release an old
item using a newly selected source's notifier. Stable Future must refresh for
source/item/revision changes, not for unrelated rebuilds. Clipboard SnackBar
actions capture text, not a disposed TextEditingController or unmounted context.

Current editor extraction review: widget capturedConnectionKey is declared as
`(String, int, String)`, but ServerProfile.connectionKey is a SIX-field record.
Use `Object` (same provider contract) or the exact actual record type, not a
guessed three-field type. Acquire an exit/confirmation guard BEFORE showing
dialogs (not just after a choice); release it on cancel, without preventing the
selected Save from running. Retain inline copy access if storage cleanup fails.

OpenCode adds regression tests for core draft retry/expired async writes and
restored-draft exits; main may fix business code only. AgY must not run checks,
format, generation, build, ADB or modify tests/core/providers.

Review of new NasThumbnailImage: it currently reads WidgetRef from dispose,
which Riverpod forbids after deactivation. Capture NasImageCacheService via
nasImageCacheProvider when requesting and release through that captured service
without any ref read in dispose. Watch service identity and rebind when it
changes; compare modifiedEpoch and sizeBytes too, not only serverId/path.
Same path with a new revision must refresh its stable Future. Release using the
old captured service before adopting a new one. Reuse the service directly;
do not add a provider or core abstraction. Inspect the image viewer's retained
notifier too: source changes must not leave it resolving through disposed Ref.

At final review also verify dashboard cached/partial notice and transfer detailed
status consumers; no Phase B completion claim while either is missing. This note
was appended at 06:38 UTC while locale authoring was in progress.

Additional concrete review before retry:
- Service logs `_fetchLogs` still admits refresh during another refresh because
  of `(_isLoading && !refresh)`. Start `_isLoading=false`, then guard either busy
  flag for EVERY entry including initial request. During refresh keep existing
  log rows rendered rather than replace them with the full loading spinner.
  At the retained 1000-row cap disable further older requests (otherwise the
  same retained last cursor is requested repeatedly and newly fetched rows are
  discarded). Keep localized cap notice. No new pagination abstraction.
- NAS library cache budget/clear handlers currently allow unhandled async
  errors; catch and display sanitized/localized failure, preserve prior budget
  on failed save, avoid concurrent budget changes and clear. Guard mounted
  before any post-await ref read or _loadCacheUsage; closed settings must not
  continue using disposed WidgetRef. Do not silently show 0 usage on failure.

Post-save check correction: real SftpNotifier.saveFileContent closes its editor
and increments editorToken before returning. `_handleSave` must not require the
original token unchanged after success: that currently discards the successful
save notification. Bind success to same connection, closed expected editor
(token advanced by one / no editing path), and this dialog's route still current.
Mocks should represent that real lifecycle. Never `Navigator.pop(context)` on
a stale operation if another route is current; it can pop the new dialog. Apply
route-current guards to async save/discard/Keep/reload completions and failures.
