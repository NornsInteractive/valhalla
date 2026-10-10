# v1.0.3 Draft GitHub Verification

**Date:** 2026-10-10 | **Agent:** opencode/step-5-preview-free | **Mode:** READ-ONLY
**Source:** https://github.com/NornsInteractive/valhalla | **Release ID:** 408606647 | **Tag:** v1.0.3

## Verdict: PASS

Single bounded metadata check. One Node script (`/tmp/opencode/v103-verify.cjs`) computed local sizes/SHA-256 for all 15 files, then made read-only `gh api` GETs (release-by-ID, tag ref, tag object, actions runs). No asset downloads (GitHub `digest` field returned non-null for all, so no download was required or performed). No build/test/analyze/ADB/remote agents/upload/cleanup, no repo or tool exploration, no env/token/home/logins, no git mutations. Draft get-by-tag returning 404 was avoided by using `/repos/NornsInteractive/valhalla/releases/408606647` as specified.

## Runtime limits

- Exactly one metadata check invocation; read-only `gh api` GETs only.
- Max 10 API calls: 1 release + 1 tag ref + 1 tag object + 1 actions query.
- No credentials printed.
- File reads: local dir stat + sha256 of 15 files (~246 MB total).

## Assertions (checker exit 0)

**Local vs expected set** — `/tmp/opencode/valhalla-v1.0.3-release` contains exactly 15 regular files, name set equals expected (7 primaries + 7 `.sha256` sidecars + `SHA256SUMS.txt`). PASS.

**GitHub release metadata:**
- `id` = 408606647 PASS
- `tag_name` = v1.0.3 PASS
- `draft` = true PASS
- `prerelease` = false PASS
- 15 assets, 15 unique names, set equals expected local set PASS

**Per-asset service state/size/digest (all 15 PASS):** every asset `state=uploaded`, `size` equals local `stat` size, `digest` equals `sha256:` + locally computed SHA-256 (Node `crypto` SHA-256 read of each file). All digests non-null, so no size-mismatch download blob was needed. No failures. Primary computed digests (also committed inside the public sidecars/manifest):

```
valhalla-android-armeabi-v7a-v1.0.3-signed.apk   faa8d77661663af4fd590ddeeefc4f53dde1a2a6d6fdf0c95d9e0a522dbc69b2
valhalla-android-arm64-v8a-v1.0.3-signed.apk     32b62cd0526a5834ca671e9754a88e4295406051ae97a52a2d2f2fda2db9818c
valhalla-android-x86_64-v1.0.3-signed.apk        73890c1645972c3fa11e3f5a663e767f68defcc5ba204c12236610964ac7c6b9
valhalla-android-v1.0.3-signed.aab               d02f97e31396511ce1a08f2a57394fd8becce0075b0581c0063c4ecb01a91c59
valhalla-linux-x64-v1.0.3.tar.gz                 c9afd6cd683a453de6166aebf0089461aae44343acbef02220d2011c9a6329b8
valhalla-android-v1.0.3-BUILD-INFO.txt           f3b2427d27d292824cc9516303cc071d319bc43579ec70a8fef0dd6fb9ce6ab6
valhalla-linux-x64-v1.0.3-BUILD-INFO.txt         e6b450be0db62391c11fa23f6276ad9792506636b7f051cb4ad819654dbcb99a
```

Independent cross-check: `sha256sum` on the armeabi-v7a APK returned `faa8d77661663af4fd590ddeeefc4f53dde1a2a6d6fdf0c95d9e0a522dbc69b2`, matching the Node-computed value.

**Sidecars & manifest:** all 7 `.sha256` sidecar entries (hex + referenced filename) match actual computed primary hashes; `SHA256SUMS.txt` parsed to exactly 7 lines, each naming a distinct primary with the computed hash, no self-coverage, no missing/duplicate/extra entries. PASS.

**Tag chain:** `/git/ref/tags/v1.0.3` is an annotated tag -> tag object `bd4023377dd6059421f83dff827c8032dbe8271c` -> commit `0dc0a3dbef6c3b7ec26b1cf994863e5c6fa2d2ec`, exactly the release-source commit, not the later documentation commit. PASS.

**Actions:** `runs?head_sha=0dc0a3dbef6c3b7ec26b1cf994863e5c6fa2d2ec&per_page=10` returned `total_count=0`. PASS.

## Console evidence summary

```
LOCAL_COUNT 15 | GH_ASSET_COUNT 15 UNIQUE 15 | MANIFEST_LINES 7 | ACTIONS_TOTAL_COUNT 0
REF_TYPE tag | CHECKER_EXIT 0 | REAL_EXIT=0
```

Zero failures across all assertion groups. Draft v1.0.3 release 408606647 is fully consistent with local artifacts — main may publish.

---

# FINAL PUBLIC RECEIPT — v1.0.3 (published)

Release **408606647** was published by main at **2026-10-10T03:45:43Z** and re-verified read-only (`gh api` GETs only, 30s timeout per call, final successful checker exit 0):

- **Public:** `draft=false`, `prerelease=false`, `tag_name=v1.0.3`, `html_url=https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.3`, `published_at=2026-10-10T03:45:43Z`.
- **Assets:** exact 15 unique, all `state=uploaded`, sizes equal local stat, digests equal `sha256:` + locally computed hashes (no downloads required).
- **Latest:** `/releases/latest` → `id=408606647`, `tag_name=v1.0.3`.
- **Hash/source integrity:** tag `v1.0.3` still peels annotated tag `bd4023377dd6059421f83dff827c8032dbe8271c` → commit `0dc0a3dbef6c3b7ec26b1cf994863e5c6fa2d2ec`; actions runs for that SHA: `total_count=0`. No future docs SHA substituted.
- **Doc gates (real exits):** `git diff --cached --check` 0, `git diff --check` 0; staged set exactly the 8 docs (README.md, docs/README.md, 08-v1.0.3-release.md, five agent-workflow v1.0.3 documents); porcelain showed only those 8 staged entries before this receipt append. README v1.0.3 download links name actual asset filenames (no Windows v1.0.3 links); Windows v1.0.2 links retained. Text checked locally. Post-append `git diff --check` exit 0.

Earlier receipt-checker runs exited 1 for a JavaScript syntax slip and incorrect
status/link assumptions (staged M is valid; the docs index need not contain
download URLs). Those are not passes or app defects; after correcting the
temporary checker, all assertions passed with actual exit 0. No production code
was changed. The draft checker later removed only its own generated temporary
script; no project data, signing file or shared cache was removed.

Draft-phase evidence above preserved unchanged. Ready for main commit/push of the 8 docs [skipci].
