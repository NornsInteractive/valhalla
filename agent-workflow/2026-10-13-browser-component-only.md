# Next AgY turn: ONLY the shared component

This short corrective batch supersedes the broad phase3 work order for THIS TURN.
Same original Valhalla conversation, model gemini-3.8-flash-high, effort high.
Root stopped the previous CLI gracefully to narrow scope, NOT because of auth or
quota. Preserve all previous edits. Native/wizard naming/AppStore first-slice gates
are now passing. DO NOT reread or edit their large files in this turn.

Only author these TWO files:
- lib/widgets/remote_browser_view.dart
- lib/widgets/remote_browser_dialog.dart
Use existing localized strings; if genuinely missing a key, record it for the next
localization-only batch. No new core, test, model changes or test/build commands.

Read the current public regressions in test/features/remote_browser_dialog_test.dart
and test/features/remote_browser_preview_test.dart, plus the relevant functions in
these two widget files. You already read core API and long phase documents: use
focused symbol/range inspection, do not repeat a full project scan.

Finish these concrete defects and return immediately:
1. Dialog confirmation disabled until successful read, including empty dirs;
   disabled on permission/missing/current-target errors; directory can never return
   ordinary file. Honor canSelectEntry, isPathRestricted, maxSelectCount.
2. Source changes immediately clear parent selection/readiness, without parent
   setState during build. All async factory/navigation/close guards in view. Initial
   missing path may fallback; normal navigation may not. Multi-batch initial IDs
   notify parent; manual deselection must not be restored on reload.
3. Preview scopes: cache writes currently use target-key prefix, grid still reads
   entry.id (no thumbnails). Old source errors decrement NEW counter and start its
   queue (new-source peak3 proven). Correct request ownership so stale completion
   cannot mutate new counters/keys/queue; navigation must still release its own old
   permits and make progress. Max2 concurrent, 24entries/8MiB encoded cache,
   2MiB per read; decode thumbnails bounded <=512px via cacheWidth/cacheHeight.
   Close stops queue; failed thumbnails don't spin. Partial-list errors visible.
4. Complete shared search-own-row, hidden-file dimming and stable entry-anchor
   view switch. Preserve existing ACP list/card/gallery choices (old UI had3).
   Cards/gallery both virtualized, mobile normal2columns, large text1 vertical.
   Gallery must not fetch/decode whole unseen directory. No management buttons.

No need to edit wrappers/main page/NAS yet; those remain required next, but stop
this turn after the two components so root can run the exact regression gate.
Report only changes and remaining caveats, do not claim validation.
