# Root static review of test draft — not accepted

Nemotron correction remained invalid (invented List.fromRange, missing imports,
incorrect implements, misspelled workspace). Stopped only that task process.
Replacement author: OpenCode opencode/big-pickle, catalog input/output/cache all0,
explicit user-authorized free fallback. Same two-file scope; standalone `dart analyze`
on owned files allowed now, no Flutter/pub-get/build commands. Main verifier MiMo
retains dependency, generation and test execution ownership.

The first offline test draft is NOT valid Dart or a faithful fixture yet. Do not
mark tests complete/passing or weaken production behavior to satisfy it.

- Dart does not permit a class declaration inside main(); helper classes top-level.
- Missing dart:async, dart:typed_data and crypto imports; unused imports present.
- NasSourceAdapter.resolve override must retain optional named quality parameter.
- Fake read unconditionally awaits cancellation, then yields count*count bytes.
  This deadlocks normal completion and violates resource size. Yield exactly
  bytes.sublist(start,end), and use a separate controlled stream/Completer for pause.
- Fake never sets resource.version yet assertions require one.
- `adapter.resolve(resumed = false)` and resolveCallCount are invented/undefined.
- resume() only enqueues/pumps, not awaits complete; observe a bounded completion
  Future before asserting completed. Register listeners before transitions.
- Do not mutate .part externally while the service is actively writing it.
  Prefer a persisted paused task + actual fixed partial file to test reconstruction,
  or a stream checkpoint flushed by service then pause() before inspecting.
- App id/source id/path must match fixture source; dispose service in tearDown even
  on failed assertions. Shared temp directories removed only after services settle.
- Drop repeated boilerplate and speculative cases; a small set of correct fixtures
  covering persistence/resume/mutation/restart/local verification is better than an
  800-line invalid draft. Keep remaining HTTP tests in the other owned file.

The main OpenCode verifier will run commands after authoring finishes. Root has
not run tests or edited the tests. Follow existing authoring whitelist.

Add narrow regression if feasible: repository.loadDownloads throws, service.ready
fails, then dispose must NOT call saveDownloads with empty tasks and overwrite
saved records. Root fixed _loaded guard in dispose, plus disposed guards in restore.

## Authoring status (opencode/big-pickle) — ready for main verifier

Rewrote both owned drafts from scratch. No invented APIs, duplicates or
class-in-main remain; helper classes are top-level and fakes `extend`
`NasSourceAdapter` with the optional named `quality` parameter intact.

- test/core/nas_offline_persistence_test.dart — 6 focused tests, real temp
  directory and sqlite3 FFI override, fake fixed payload plus versioned
  byte reader:
  - completed download persists; restores offline with a throwing
    `adapterFor`; `localFile`/`localPathFor` resolve without network.
  - resume continues from a persisted paused task with a fixed `.part`
    offset, appends remainder, renames, verifies full bytes.
  - changed validator on resume fails NAS_DOWNLOAD_SOURCE_CHANGED and keeps
    the partial.
  - restart discards the partial and re-reads from zero.
  - `_LoadFailingRepository` (loadDownloads throws): `ready` errors and
    dispose makes zero `saveDownloads` calls; pre-existing record survives.
  - `localFile` rejects a completed record with a checksum mismatch and,
    after deletion, a missing file (NAS_OFFLINE_FILE_INVALID).
- test/infrastructure/nas_download_validators_test.dart — loopback server:
  HEAD strong ETag version/size, If-Match + exact Range 206, 412 mutation
  surfaced on the conditional read, missing validators full 200, HEAD
  405/501 fallback with no resume metadata, ignored Range without
  validators -> NAS_RANGE_UNSUPPORTED, and a start-zero exact-length 200
  accepted as a whole-file range.

`dart analyze` on the two owned files: no issues (exit 0). No product, UI,
dependency, pubspec or other test files were edited. Tests were not run —
main verifier retains command execution.
