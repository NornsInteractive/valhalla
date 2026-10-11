# v1.0.4 GitHub Release Draft — READ-ONLY Verification (handoff)

- Date (UTC): 2026-10-11
- Actor: OpenCode free main model `opencode/step-5-preview-free` (zero cost) — sole
  verifier. The release draft upload, and the separate private local audit, were
  **not** executed or re-run by this pass.
- Repo: `NornsInteractive/valhalla` · tag `v1.0.4` · release id **409398862**
- Status: **PASS — script exit `0`, 25/25 checks.**
- Verified by: `/tmp/opencode/verify_v104_release.py` (stdlib + `gh api` only),
  release JSON `/tmp/opencode/release-v104.json`, run log
  `/tmp/opencode/v104-verify-out.txt`.

## Boundary (read-only)

- **No** GitHub writes: no release create/edit/publish/asset delete, no tag
  create/move, no workflow dispatch. Only `GET` / GraphQL read calls.
- **No** git mutations, **no** builds, **no** ADB/device action, **no** secrets
  output (no token printed; only `gh auth status` subject `Naruto9Kurama` seen).
- Assets read: **exactly two** (`update.json`, `SHA256SUMS.txt`), downloaded into
  a fresh `mkdtemp` temp dir owned by `dev`; no other asset content was fetched.
- Not performed: no dry-run/publish simulation, no release-notes diffing, no
  ownership/uploader authorisation change, no workflow re-run.

## Facts

| Check | Result |
|---|---|
| `gh api releases/tags/v1.0.4` exit | **1** — `{"message":"Not Found","status":404}` |
| Draft served by tag endpoint? | **No** — a draft is not returned by `/releases/tags/{tag}`; it was fetched by id `409398862` (resolved from `releases/…/releases`), the standard read path |
| `draft` | **`true`** |
| `tag_name` | `v1.0.4` |
| `prerelease` | `false` |
| `target_commitish` | `b397ec62255fa9cc0575941450a4b2cdadfa4608` (== source) |
| Annotated tag deref | tag object `359689749927f6bc2e54a824dd77397cca89d8ac` (`__typename: Tag`, tagger `Valhalla Dev`) → commit **`b397ec62255fa9cc0575941450a4b2cdadfa4608`** (40 hex, == source) |
| Actions runs with `head_sha` = source | **0** (`actions/runs?head_sha=…` → `total_count: 0`; repo total is 14, none at that sha) |
| Remote asset count | **17** |
| Local staged count (`/tmp/opencode/valhalla-v104-release-WweZbH`) | **17** |
| Filename set remote vs local | **exact match** — `only_remote=[]`, `only_local=[]` |
| Per-asset `size` vs local byte size | **17/17 match** |
| Per-asset `digest` field (all `sha256:`) vs locally computed sha256 | **17/17 match** |
| `update.json` + `SHA256SUMS.txt` asset download | byte-identical to local (1526 B / 828 B); temp contained exactly those 2 files |
| Manifest `version` / `sourceCommit` | `1.0.4` / `b397ec62255fa9cc0575941450a4b2cdadfa4608` (== source) |
| Manifest `artifacts` entries | **4**, all matching the actual remote asset `size` + `digest`, and local size |

## Remote 17 — proof (name · bytes · sha256 digest)

| # | Name | Bytes | sha256 (from `digest`) |
|---|---|---|---|
| 1 | valhalla-v1.0.4-android-arm64-v8a-signed-5.apk | 45,160,332 | `103aada456e4ae78d20a172d2ca6cd61de62437e239e0168d6a092c87ccd0de4` |
| 2 | valhalla-v1.0.4-android-arm64-v8a-signed-5.apk.sha256 | 113 | `ca00137400a14a6ca438c1c2f53f658913bddf88de55996020906e1dc9336efe` |
| 3 | valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk | 43,088,688 | `bc3774f79816330e43c19e458eb4e91a7b4a2cdfb9b850fc9df09c67bafb4b1c` |
| 4 | valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk.sha256 | 115 | `4070d660e50c2e72dc8aed2ad57a78d8807ea2ad8db88cc3fd84ee4ba796f2bd` |
| 5 | valhalla-v1.0.4-android-x86_64-signed-5.apk | 50,115,316 | `15a0653266945e40ff0023fc6a4e7ed90945e1079461f110b5f3dabf476645f0` |
| 6 | valhalla-v1.0.4-android-x86_64-signed-5.apk.sha256 | 110 | `102dee8548ab0a5699e9a8ac6fc9bdc73f34c1dcd667b40cd9233b1e2de9303e` |
| 7 | valhalla-v1.0.4-android-signed.aab | 78,935,388 | `a7228b416b9ad90ae258bc0b81df4bb5556db339b77f1b4c4349e2019367d20f` |
| 8 | valhalla-v1.0.4-android-signed.aab.sha256 | 101 | `6feaed6b14d849d2a4da91298b6a77dd3637271ec90b7fa5040d7d9f40109b1f` |
| 9 | valhalla-v1.0.4-android-BUILD-INFO.txt | 6,854 | `51731e7979fd47b42e2ced685a01560e64ef8d216a21ea84df29757ab74abda9` |
| 10 | valhalla-v1.0.4-android-BUILD-INFO.txt.sha256 | 105 | `17cd4a137f79a8b2ddd2e31817c46904479c4fbe9ba613918a304bc87b0eacc1` |
| 11 | valhalla-v1.0.4-linux-x64.tar.gz | 23,087,580 | `cc9b51c6f2a3418e72c3bbecb50d223a7c9fc356994e7ff4638b7adeb7cc1730` |
| 12 | valhalla-v1.0.4-linux-x64.tar.gz.sha256 | 99 | `050dfeb114d7110387e21874604d68b77bce780303e04a5db9d814642ac55843` |
| 13 | valhalla-v1.0.4-linux-x64-BUILD-INFO.txt | 5,478 | `01df16456bb173a72b1d9c3bf0c2f55209cf7338540143dce5e731bf8096bd29` |
| 14 | valhalla-v1.0.4-linux-x64-BUILD-INFO.txt.sha256 | 107 | `51fb812016185173ae438365bec79b8b6c4d9241591eaf4bb3bbaaf53d5e1ef2` |
| 15 | update.json | 1,526 | `6bfceb82dee5c9554a03ba693dc18330c127d4bc5f2e112693bcb9b0632d99cc` |
| 16 | update.json.sha256 | 78 | `afd1c5c804734fa0e8c70b5946ae3057b7a4f32fe94337dc7f244a6dfb05cbdb` |
| 17 | SHA256SUMS.txt | 828 | `0f7a7952d5a01655b9e1f0778d429667d863a1066f6d0e9da1848c399cc62c25` |

All 17 `digest` values above were recomputed locally from the staged files and
matched; state for every asset is `uploaded`.

## Downloads (asset API, fresh temp owned by `dev`)

`gh api -H "Accept: application/octet-stream" repos/NornsInteractive/valhalla/releases/assets/{id}`
for exactly two assets: `update.json` (id 629735936) and `SHA256SUMS.txt`
(id 629736299). Temp `mkdtemp` prefix `v104-verify-` (e.g.
`/tmp/v104-verify-5fmmg0nh`) contained **only** those two files. `cmp`-equivalent
Python byte compare: both byte-identical to the staged copies.

Manifest read from the **downloaded** copy: `schemaVersion 1`, `version 1.0.4`,
`buildNumber 5`, `sourceCommit` = source, `artifacts` = **4** entries
(arm64-v8a APK 2005, armeabi-v7a APK 1005, x86_64 APK 4005, linux tar) — every
entry's `size`/`sha256` matched the corresponding remote asset and local file.
Downloaded `SHA256SUMS.txt` lists all 7 payload primaries.

## Disclosed non-fatal events

1. One asset download attempt hit a transient GitHub socket timeout
   (`dial tcp 20.205.243.168:443: i/o timeout`, exit 1). No state changed; the
   read was retried and succeeded. No retry was silently treated as success —
   the check records the retry and the verified size/digest.
2. `releases/tags/v1.0.4` returning 404 is expected for a **draft** and is
   reported as fact, not worked around by guessing a URL; the release id came
   from the repository's own releases list.

## Not performed / not claimed

- No release publish, edit, asset delete or tag move; publishing stays with the
  upstream owner. No workflow re-run, tag re-point or rollback.
- No app execution, no runtime/update-feed acceptance test, no signature or
  installability assertion in this read-only pass.
- The separate private local audit is complete and was intentionally not
  re-run.
