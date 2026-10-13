# Gallery correction after real first-pass edits

UI only, original Valhalla / gemini-3.8-flash-high / high. No tests, analysis,
format, generation, builds, ADB, credentials or core edits. The previous request
completed at step34814; the final aggregate quota message is historical.
Keep native Flutter layout, existing theme and previous playback/album fixes.

Current disposition after35087 (read-only review, not runtime acceptance):
0 fixed; 1 gallery state-based errors fixed; 4 source/page callback guards and
date bounds fixed; 8 navigation generation separated and source invalidation
added; 9 clicked-image source/path index fixed. Missing imports and invalid
localized getters from the first analyzer run were also corrected by AgY.
Remaining:2 edge action safety;3 exact latest anchor capture;5 actual header
measurement;6 unconditional key pruning;7 full viewer query/source/return flow.
Ordinary non-gallery page failure must not jump to0 (post-error check still
missing there). Do not treat the numbered historical findings below as proof
their already-fixed lines still need replacing.

After35198, independent review confirmed2 (edge-gated controls including retry
and load entry),6 (unconditional pruning and source/query layout reset). Item5
is partially implemented but NOT done: measured root TextSpan lacks resolved
DefaultTextStyle/locale/textHeightBehavior, while actual Text.rich inherits them;
the whitespace span is unstyled. Share complete resolved layout inputs rather
than merely using similar children. Latest analyzer is0issues/exit0, not a
320dp/2x/RTL widget pass. Items3 and7 remain unfinished.

Delivery continuation after35253/35333: shared header span/explicit RichText
paragraph inputs and both ordinary-pagination error checks are now statically
confirmed. Anchor capture now happens at old-items replacement, selects the
topmost truly intersecting tile, and uses correct two-frame restoration formulas.
Two anchor corrections remain before acceptance:

- Do not use raw offset difference as user-input detection: viewport layout can
  clamp offsets on eviction without user input. Invalidate using actual scroll
  activity/notification sequence, suppress programmatic corrections.
- Each items replacement needs an anchor revision and captured target items
  identity. Same-query refresh/favorite replacements must invalidate older
  callbacks even when pagingGeneration is unchanged.

The original-session viewer batch is active in agy-delivery-viewer.jsonl; do not
start a concurrent AgY invocation or treat its partial files as reviewed yet.

Read only relevant methods, then fix these concrete contract violations:

0. `_GalleryLayout`, `_GalleryRow`, `_GalleryHeaderRow`, `_GalleryItemRow` are
   referenced but NOT defined anywhere in `lib/features/nas`. Add the minimal
   private types that the actual implemented layout needs, or simplify to existing
   data structures. The current patch cannot compile. Check required imports too.
1. `NasNotifier._loadGallery` catches failures into `state.errorCode`; it does
   NOT throw. UI try/catch therefore falsely clears the edge error, permits
   repeated requests and restores after a failed request. Inspect the current
   state after the awaited call, with captured generation/source/query guards.
   Core now clears stale error on an accepted pagination attempt. On a failure
   retain items/position, show existing localized load-failure/retry labels and
   wait for explicit retry. Do not display fake scan errors with LOAD_NEXT codes.
2. The fixed always-enabled `_buildPaginationFooter` remains on photos. It can
   evict the currently visible top while loading next, or vice versa. Put each
   gallery edge action at its corresponding edge (or gate it to that edge).
   Preserve public previous/next keys and make explicit retry accessible.
3. Anchor math: request-start capture + post-frame userScrollDelta and the
   refinement currently use opposite signs. More importantly clamping after
   window eviction can contaminate that delta and the user may have moved to a
   different item. Capture the LATEST actual visible source/path + pixel offset
   from the OLD rendered layout at the state.items replacement boundary, before
   the new layout builds. Use this one anchor for exact new row-offset restore;
   guard both frames and user movement between them. Avoid stale request-start
   deltas and scroll-ratio estimates. Preserve rapid A->B->A invalidation.
4. Source listener post-frame jump around line1330 has no mounted/source/epoch
   checks. Normal pagination jumps after await without any stale-result guard.
   Query epoch tuple omits modifiedFromEpoch/modifiedBeforeEpoch. Guard these
   and all new continuation points; reset transient state on true query changes.
5. Header measurement uses a hard-coded sample and no width constraint while
   the rendered header is an unbounded Row of date/count. It overflows at
   320dp/2x. Render and measure the SAME actual label, font/textScaler/direction,
   wrapping width and padding. Include any edge-control extent in row offsets.
6. `_pruneTileKeys` early return is incorrect when equal-size source/query windows
   change. Remove entries not in the active window unconditionally; keep at most
   600. Drop obsolete layout/anchor metadata on source/query change.
7. `NasImageViewerDialog._next/_previous` still select first/last after pagination.
   In a retained append/prepend window these are OLD unrelated items. Locate the
   previous current source/path in the returned window and move exactly one
   neighbor; honor state errors and full source/query identity after await.
   Viewer must not mutate a newly selected source. Gallery blocks auto-loading
   while viewer is open but also needs return restoration. Keep old visible
   anchor when it survives; if viewer paging evicts it, restore the viewer's
   current source/path (not an unrelated first image), via a small optional
   callback/result using existing APIs. Check all viewer callers when changing
   signatures; local offline viewer must remain local.

Do not report these fixed without reading your actual edited methods. No broad
redesign or new dependency. OpenCode owns syntax/static/widget verification.

## Additional independent review (after correction request started)

8. `_selectTab` captures `_pagingGeneration` before its own selectCategory call,
   but the query listener increments the SAME generation for the intended query
   change. From sorted/scoped Videos or Music into first Photos, its own guard
   aborts before enableGalleryWindow(true). Separate navigation identity from
   query/paging invalidation, while still guarding a genuinely superseding source
   or tab action. Apply to library navigation/init as relevant.
9. Gallery rows regroup images by date. `row.startIndex` therefore is NOT the
   index in the original provider-ordered list passed to the viewer, e.g. name
   sort with interleaved dates. Locate the clicked image by BOTH source and path
   in that exact viewer list; otherwise tapping one image opens another.
