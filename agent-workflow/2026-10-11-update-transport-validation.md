# Update transport & manifest-generator validation

Date: 2026-10-11
Scope: isolated tests only. No production, UI, or platform code was modified.

## Files added

- `test/core/app_update_http_test.dart` (new, separate from `test/core/app_update_service_test.dart`)
- `tool/test_generate_update_manifest.py` (new)

`test/core/app_update_service_test.dart` belongs to another verifier and was
neither read for reuse nor modified.

## Results

| Suite | Command | Count |
| --- | --- | --- |
| Dart transport | `flutter test test/core/app_update_http_test.dart` | 42/42 passed |
| Python manifest | `python3 -m unittest tool.test_generate_update_manifest` | 27/27 passed |

Total 69 tests, 0 failures. Run twice; results stable.

## Fake HTTP design

`_FakeResponse extends Stream<List<int>> implements HttpClientResponse` and
overrides **only `listen`**. Everything else (`timeout`, `drain`, `await-for`)
is inherited from `Stream`, so the production 20s/30s timeouts are genuinely
exercised rather than stubbed.

Two Dart 3.10 constraints shaped this and are worth recording:

- `HttpHeaders` is now `abstract interface class` with no public constructor,
  so a minimal map-backed `_FakeHeaders` implements `set`/`value` and defers the
  rest to `noSuchMethod`.
- A `noSuchMethod`-backed fake is a runtime subtype of `HttpClientResponse` but
  the analyzer rejects it in **function-typed return position** (implicit
  downcast applies to plain returns only). The exchange typedef therefore
  returns `_FakeResponse` rather than `HttpClientResponse`. This was the prior
  "fake interface dead end"; the fix is the typedef, not the fake shape.

## Coverage

### check()
- 200 parses release, artifacts, page URL, ETag; asserts `Accept`,
  `X-GitHub-Api-Version`, `User-Agent`, no `If-None-Match` on cold check; client closed.
- 304 with cache reuses cache, re-emits new ETag, sends `If-None-Match`.
- 304 without cache fails rather than silently succeeding.
- 404 → null release, no throw. 403 and 429 → `UPDATE_RATE_LIMITED`. Client closed in both.
- Draft and prerelease rejected.
- 2 MiB release body limit and 256 KiB manifest limit, plus a just-under-limit
  body that must succeed (guards the limit off-by-one, not only the failure).

### Redirects
- non-https target blocked, untrusted https host blocked, missing `Location`
  blocked, redirect loop hits `UPDATE_REDIRECT_LIMIT` after exactly 6 requests,
  `*.githubusercontent.com` followed successfully end-to-end.

### update.json
- valid manifest populates build number, commit and artifact identity
  (including Android version code and certificate).
- non-200 manifest → `UPDATE_MANIFEST_FAILED`.
- schema version, version-vs-tag drift, build number 0 / non-int, short commit,
  missing commit → `UPDATE_MANIFEST_INVALID`.
- Android entry missing version code or certificate → `UPDATE_ANDROID_IDENTITY_INVALID`.
- Manifest size disagreeing with the release asset → `UPDATE_ASSET_SIZE_INVALID`.
- Manifest digest disagreeing with the release `digest` → `UPDATE_ASSET_DIGEST_MISMATCH`.

Note: manifest entries that name no released asset are silently skipped by
`parseRelease`, so every binding fixture had to include the matching asset. A
manifest-only test would have passed vacuously.

### download()
- fresh download verifies hash, renames, clears `.part`/`.part.json`, progress 0→size.
- resume sends `Range: bytes=N-`, requires matching `Content-Range`, completes.
- 206 with wrong `Content-Range` fails and **keeps** the partial.
- 206 with no prior offset refused.
- 200 response to a Range request restarts from byte zero (stale bytes truncated).
- stale sidecar identity and oversized partial both discard and restart clean.
- stream interruption mid-body retains the partial, leaves no completed file,
  and a subsequent call resumes from the retained offset and completes.
- cancel leaves no completed file; a later download on the same service still works.
- short body, oversized body, and hash mismatch all leave no completed file;
  size/hash failures also delete the partial.
- existing destination is never overwritten (contents unchanged).
- untrusted download host and untrusted redirect target refused before any
  file is written.

All filesystem assertions use test-created temp dirs (`Directory.systemTemp`),
removed in `tearDown`. No network, no server, no history writes.

### generate_update_manifest.py
- `platform_for` accepts all six supported artifacts and rejects unknown
  names, unsigned/mismatched variants, unsupported archs and suffixes.
- digests and sizes verified against independently computed `hashlib.sha256`
  of the real bytes on disk; empty artifact rejected; envelope shape checked.
- artifacts sorted by file name; Android tools are **not** invoked for
  non-Android builds.
- duplicate platform/arch rejected (signed variant of the same arch), symlinked
  artifact rejected, distinct architectures all accepted.
- Android: package, versionName and build-number drift rejected; ambiguous and
  missing signer digests rejected; unreadable badging output rejected.
- source/build validation: prerelease versions, out-of-range builds (0, -1,
  1000, 5000), malformed commits, and uppercase-hex commits rejected.
- CLI writes `update.json` and a `update.json.sha256` whose digest matches the
  written file; prerelease pubspec version exits non-zero and writes nothing.
- `android_tool` PATH preference, build-tools directory fallback, and
  missing-SDK error.

All Android tool output is mocked and all artifacts are temp files. Hashes are
real (computed over real bytes by the production code and independently in the
test).

## Uncovered / not verified

No Android or Windows OS behavior was exercised. Explicitly **not** claimed:

- Actual APK install on a device/emulator. `androidVersionCode` and
  `androidCertificateSha256` were only checked as *parsed* fields against mocked
  `aapt`/`apksigner` output; no real APK was signed, verified, or installed, and
  no device-side upgrade-path check was run.
- Real `aapt dump badging` / `apksigner verify` invocation, and real SDK
  `build-tools` discovery.
- Windows installer (MSIX/Installer/InnoSetup) upgrade, downgrade and
  rollback behavior; nothing in `windows/` or `tool/windows_installer.iss` was run.
- macOS and Linux installer paths end-to-end.
- Real network behavior: no DNS, TLS, proxy, gzip/content-encoding, chunked
  transfer, or `HttpClient` connection-reuse behavior. Redirects, status codes
  and streaming were exercised only through the fake.
- The 20s/30s production timeouts are inherited from `Stream` and therefore
  real code paths, but no test actually waits on them.
- `UPDATE_DOWNLOAD_IN_PROGRESS` reentrancy guard.
- Race between `cancelDownload()` and stream teardown under real socket close.

## Constraints honored

No UI or source edits, no full-suite run, no builds, no ADB/SDK access, no broad
SDK reading. No git history writes; nothing committed.