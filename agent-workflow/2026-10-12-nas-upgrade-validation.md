# OpenCode validation handoff — NAS upgrade / safe uninstall

This is a new iteration. OpenCode owns test authoring, format/generation, analysis,
build and retained-data ADB verification. Do not change product UI or core code;
report production fixes to root/AgY. Preserve all existing work. No version bump,
push/release, real production server actions, application uninstall/data reset.

Use an explicitly zero-cost model. MiMo and Big Pickle are rate-limited this
round; Nemotron 3 Ultra Free returned READY with cost0. Auxiliary small_model
must also be free; no paid fallback.

## First batch: local core only

Read `2026-10-12-nas-experience-and-safe-uninstall.md` and
`2026-10-12-nas-core-ui-contract.md`. Write small focused regressions, adjust fake
override signatures only where new optional parameters require it; preserve old
assertions. Run targeted analyzer and tests, save full output under
`/tmp/valhalla-nas-upgrade.X1GzDi1J`. Flutter `/opt/flutter/bin/flutter`.

1. New album identity/metadata, same-name artist/source isolation, disc/track
   ordering, unknown date (UTC buckets), bounded keyset group counts and filters,
   batch playback lookup, gallery600-item window forward/back all sort modes,
   source switch/edited source stale result rejection, cancelled scan retention.
   Cover repository migration with100k synthetic rows; no real media needed.
2. `ApplicationConfiguration.jellyfinSoftwareMode`: old JSON defaults false;
   new config roundtrips. `ApplicationComposeService` explicit trusted official
   Jellyfin software profile drops only reviewed hardware mappings and defaults
   media read-only; keeps original template unchanged; configure/update retain
   profile; untrusted sources/unknown devices/privileges cannot bypass validator.
3. `NasImageCacheService` scoped stats/clear: owner sidecars; legacy bucket;
   cancelling an in-flight selected-source write must not leave unowned file;
   other-source cache/offline media survives. Existing global API still works.
4. `NasSourcesState.diagnostics` / `NasSourcesNotifier.probe`: real stages,
   typed failure code/status, no URL/password/token/body in diagnosticText,
   old probe cannot overwrite newer source/save/remove; last success retained
   across failed retry. No network production targets, use existing local fakes.

Native installation and uninstall agents are still completing code review. Do
NOT run real remote installation/deletion in this first batch. Their independent
UI/safety contracts will be handed over after completion. Do not build/ADB yet.

Report precise commands, counts, file edits, failures and evidence paths; never
call an unrun assertion passed. Finish the batch promptly rather than researching
unrelated features or reading the whole repository.
