# v1.0.4 Public Release Verification

- **Date (UTC):** 2026-10-11
- **Release:** https://github.com/NornsInteractive/valhalla/releases/latest
- **Mode:** read-only verification; no release, repo, or build mutations

## Result

`actual_exit=0` — 24/24 assertions PASS.

## Release Facts

| Check | Value |
| --- | --- |
| `releases/latest` tag | `v1.0.4` |
| `draft` | `false` (published) |
| `published_at` | `2026-10-11T04:12:39Z` |
| Assets | 17, all `state=uploaded` |
| Source `target_commitish` | `b397ec62255fa9cc0575941450a4b2cdadfa4608` |
| Actions run count on source | `0` |

## 17 Asset SHA256 (registry == local `/tmp/opencode/valhalla-v104-release-WweZbH`)

| Asset | sha256 | size |
| --- | --- | --- |
| `SHA256SUMS.txt` | `0f7a7952d5a01655b9e1f0778d429667d863a1066f6d0e9da1848c399cc62c25` | 828 |
| `update.json` | `6bfceb82dee5c9554a03ba693dc18330c127d4bc5f2e112693bcb9b0632d99cc` | 1526 |
| `update.json.sha256` | `afd1c5c804734fa0e8c70b5946ae3057b7a4f32fe94337dc7f244a6dfb05cbdb` | 78 |
| `valhalla-v1.0.4-android-BUILD-INFO.txt` | `51731e7979fd47b42e2ced685a01560e64ef8d216a21ea84df29757ab74abda9` | 6854 |
| `valhalla-v1.0.4-android-BUILD-INFO.txt.sha256` | `17cd4a137f79a8b2ddd2e31817c46904479c4fbe9ba613918a304bc87b0eacc1` | 105 |
| `valhalla-v1.0.4-android-arm64-v8a-signed-5.apk` | `103aada456e4ae78d20a172d2ca6cd61de62437e239e0168d6a092c87ccd0de4` | 45160332 |
| `valhalla-v1.0.4-android-arm64-v8a-signed-5.apk.sha256` | `ca00137400a14a6ca438c1c2f53f658913bddf88de55996020906e1dc9336efe` | 113 |
| `valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk` | `bc3774f79816330e43c19e458eb4e91a7b4a2cdfb9b850fc9df09c67bafb4b1c` | 43088688 |
| `valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk.sha256` | `4070d660e50c2e72dc8aed2ad57a78d8807ea2ad8db88cc3fd84ee4ba796f2bd` | 115 |
| `valhalla-v1.0.4-android-signed.aab` | `a7228b416b9ad90ae258bc0b81df4bb5556db339b77f1b4c4349e2019367d20f` | 78935388 |
| `valhalla-v1.0.4-android-signed.aab.sha256` | `6feaed6b14d849d2a4da91298b6a77dd3637271ec90b7fa5040d7d9f40109b1f` | 101 |
| `valhalla-v1.0.4-android-x86_64-signed-5.apk` | `15a0653266945e40ff0023fc6a4e7ed90945e1079461f110b5f3dabf476645f0` | 50115316 |
| `valhalla-v1.0.4-android-x86_64-signed-5.apk.sha256` | `102dee8548ab0a5699e9a8ac6fc9bdc73f34c1dcd667b40cd9233b1e2de9303e` | 110 |
| `valhalla-v1.0.4-linux-x64-BUILD-INFO.txt` | `01df16456bb173a72b1d9c3bf0c2f55209cf7338540143dce5e731bf8096bd29` | 5478 |
| `valhalla-v1.0.4-linux-x64-BUILD-INFO.txt.sha256` | `51fb812016185173ae438365bec79b8b6c4d9241591eaf4bb3bbaaf53d5e1ef2` | 107 |
| `valhalla-v1.0.4-linux-x64.tar.gz` | `cc9b51c6f2a3418e72c3bbecb50d223a7c9fc356994e7ff4638b7adeb7cc1730` | 23087580 |
| `valhalla-v1.0.4-linux-x64.tar.gz.sha256` | `050dfeb114d7110387e21874604d68b77bce780303e04a5db9d814642ac55843` | 99 |

Every asset: registry `size` == local byte size **and** registry-agnostic local sha256 computed once (streamed, 1 MiB chunks) — both matched for all 17, no full-binary download required.

## Public Download URL HEAD (bounded retry, no body fetched)

| Asset | status |
| --- | --- |
| `valhalla-v1.0.4-android-arm64-v8a-signed-5.apk` | `200` |
| `valhalla-v1.0.4-linux-x64.tar.gz` | `200` |

`HEAD <browser_download_url>` attempts up to 5 with exponential backoff (2,4,8,16 s) and 30 s timeout; both returned 200 first try.

## Method

Single Python standard-library script (`hashlib`, `json`, `os`, `subprocess`, `sys`, `time`, `urllib.request`) driving `gh api` for release metadata and local `hashlib` digests. No full-binary download, no device/orientation work, no `gh auth status`, no environment dump, no release or repo writes.

## Conclusion

Root release `v1.0.4` is published, non-draft, dated 2026-10-11T04:12:39Z, sourced from commit `b397ec62255fa9cc0575941450a4b2cdadfa4608`, with 17 fully-uploaded assets whose sizes and SHA-256 digests match the local staging set exactly, and public download endpoints returning 200.
