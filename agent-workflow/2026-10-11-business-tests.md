# Business tests completion — 2026-10-11

## Scope

Tests only. No production (`lib/`, `packages/`, `android/`, `windows/`) edits.

## Files

- `test/core/terminal_keys_test.dart` — completed.
- `test/core/app_update_service_test.dart` — completed.
- `test/data/local_storage_completion_test.dart` — added (30 tests).
- `test/core/zz_scratch_probe_test.dart` — deleted (task-created scratch probe).

## What had to be corrected

### terminal_keys_test.dart

- The `Terminal.inputHandler` closures from the previous draft did not compile: the
  property is a `TerminalInputHandler?`, not a function. Replaced with a typed
  `_RecordingInputHandler implements TerminalInputHandler`, which records the events
  and returns null so nothing is written to the pty.
- Application cursor keys are entered with DECCKM (`ESC[?1h` / `ESC[?1l`), not
  `ESC=` / `ESC>` (keypad mode). Setup strings updated.
- Single-rune non-ASCII keys are typed verbatim by design: the former
  `expect(_send('Ω'), isEmpty)` was inverted to assert the rune reaches the pty.

### app_update_service_test.dart

- Compile errors fixed: undefined `_commit00`, `_manifest(schemaVersion:)` widened to
  `Object?`, non-existent `_release(parserArtifacts:)`, `artifactFor` group called on the
  raw map instead of the parsed release.
- Digest fixtures were 68 hex characters, not 64; every artifact was silently skipped by
  the sha256 check. Both fixtures corrected to exactly 64 characters.
- Asset names and download URLs are now derived from the tag, since `_assetUrl` requires
  the URL tag segment to equal `tag_name`.
- Name-derived platform matching accepts an optional `v`, so the "no known platform"
  fixture used an unknown ABI suffix instead of dropping the `v`.
- Manifest fixtures aligned with the current updater contract: android entries carry
  `androidVersionCode` + `androidCertificateSha256`, and the manifest `sha256` matches the
  asset `digest`. Digest disagreement now asserts `FormatException`; a manifest hash is
  only used to supply the value when the asset has no digest. All invalid-metadata
  assertions (schema version, version mismatch, build number, source commit, size,
  url, host, digest, android identity) were kept and extended, not relaxed.
- `parseRelease` does not inspect `draft`/`prerelease` (that gate lives in the network
  `check()` path, which is out of scope without HTTP). The test now states that boundary
  instead of asserting a throw the parser never performs.

### local_storage_completion_test.dart (new)

Covers the requested behaviour:

- page cache 256 KiB ceiling: round trip, oversized payload dropped, just-under stored,
  twelve-page retention, per-server clear.
- 7 day expiry: stale record, in-window record, unparseable timestamp, per-page keys.
- connection identity separation: host, port, auth type and transfer records separate;
  display-name-only change does not.
- terminal pinned keys: null default, round trip including empty list, export/import.
- file view mode: null default, list/grid persistence, unknown value refused on write and
  read as null when stored, export/import round trip.
- unknown configuration values: unknown key, wrong value type, non-string list rejected;
  a rejected preference leaves the stored data untouched; import rollback and merge.

## Results

`flutter test test/core/terminal_keys_test.dart test/core/app_update_service_test.dart test/data/local_storage_completion_test.dart`

- 94 passed, 0 failed.
  - terminal_keys_test.dart: 19
  - app_update_service_test.dart: 45
  - local_storage_completion_test.dart: 30

`dart analyze` on the three files: 3 pre-existing `use_null_aware_elements` infos in
app_update_service_test.dart, no warnings or errors.