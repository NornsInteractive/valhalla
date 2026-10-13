# Phase C: root review — fix before UI verification

Same AgY conversation/model/high and exact Phase B whitelist including narrowly
scoped notification routing. No tests/build/analysis/format/generation/product edits.

1. NasDownloadService.resume only queues; source/version/HTTP failures arrive later
   in tasks/changes. Catching resume to show SOURCE_CHANGED dialog cannot work.
   In failed task actions inspect task.error: SOURCE_CHANGED must offer explicit
   restart-from-zero confirmation (keep partial on dismiss). Other failed tasks
   should offer resume with validated partial, not always restart/discard. Cancelled
   entries can restart. Label destructive restart clearly and confirm as appropriate.
2. NasDownloadsSheet ignores AsyncError/loading and shows no-downloads for failed
   persistence restoration. Render localized loading and actionable error/retry;
   preserve usable task snapshots but never turn storage failure into empty success.
   Restoration retry can invalidate nasDownloadServiceProvider (not just the stream,
   whose service.ready is cached). Root now prevents disposal of an uninitialized
   service from persisting an empty list over existing saved tasks.
3. Completed task has 3/4 trailing IconButtons; review 320dp + 2x width budget and
   move secondary actions to overflow if needed, retaining semantics/test keys.
4. Notification route: MainActivity onNewIntent clears pending NAS flag before
   Dart has accepted delivery. Retain until MethodChannel success acknowledgement,
   or cold/pending consumer handles it. Preserve remote transfer routing behavior.
   Deduplicate repeated warm notifications so multiple download sheets don't stack.
5. Added getNasLaunchAction AND getLaunchAction do the same thing, MainShell calls
   both. Use one explicit NAS action getter; remove redundant invented fallback.
6. Final code review (not executing analyzer) for unknown l10n getter names, async
   mounted checks, generated files untouched, source-filtered home and offline
   image path bypassing network. Ensure paused/failed/source-change task controls
   match actual service behavior. Do not fabricate new provider signatures.

7. New DownloadChannel.currentActivity must not strongly retain a destroyed
   Activity in a process-global Kotlin object. Use WeakReference<Activity> (read
   .get() when dispatching) or explicit lifecycle cleanup scoped to that activity.

Report touched files and unresolved APIs, not unrun test passes.

OpenCode analysis is now available. Before reporting completion, read and fix
`agent-workflow/2026-10-12-nas-ui-analysis.md` and the lib/features entries in
`/tmp/valhalla-nas-refresh.OOGiIt/analyze.log`. These include invalid imports/model
fields and leftover bracket closings in forms. Core business files had no reported
errors; root owns the vendor informational cleanup. Do not run analysis yourself.
