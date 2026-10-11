# v1.0.4 Pre-Upload Audit — 2026-10-11

- **Audit script:** `/tmp/opencode/v104-preupload-audit.py` (Python 3.11 stdlib only)
- **Log:** `/tmp/opencode/v104-preupload-audit.log`
- **Staged set:** `/tmp/opencode/valhalla-v104-release-WweZbH` (exactly 17 files)
- **Source of truth:** `b397ec62255fa9cc0575941450a4b2cdadfa4608`
- **Actual exit code: `0` → `AUDIT RESULT: PASS`, 0 failures.**

## Method

Signing material was resolved by **filename inspection only** inside
`/home/dev/.local/share/valhalla-signing/` (the requested `.\password` does not
exist; the actual password file is `android-release.password`, and
`android-release.p12` is present). Both the password file and the entire 3452-byte
PKCS#12 bundle were read into memory and used **only** as in-memory `bytes.count()`
needles. No secret value appears in argv, the script, the log, this report, or
stdout (verified by an explicit self-check: clean).

Scanning covered **2088 byte surfaces**: all 17 raw staged files, **all 2015**
decompressed APK/AAB zip members (CRC-verified with `zipfile.testzip`), and all
**56** decompressed Linux tar regular members. Binary members were read as raw
bytes (no `grep -I`). Secret-looking names were matched case-insensitively on
`*.p12/*.pfx/*.jks/*.keystore/*.pem/*.key/*.p8` plus `*password*`,
`*passphrase*`, `*secret*`, `*token*`, `*credential*`.

## Results — secret leakage (all zero)

| Check | Result |
|---|---|
| Store password (exact + newline-trimmed needles) | **0** occurrences / 2088 surfaces |
| Entire PKCS#12 byte string | **0** occurrences |
| PKCS#12 PFX OID + JKS magic | **0** occurrences |
| Real PEM **private-key** payloads (`BEGIN…PRIVATE KEY` + valid base64 + consistent DER SEQUENCE) | **0** |
| Secret-looking filenames (staged / zip / tar) | **0** |

`PRIVATE KEY` substring occurrences were confined to **23 documented compiled
members** only — all pass a final basename allowlist
(`libapp.so`, `libflutter.so`, `libflutter_linux_gtk.so`, `libmpv.so`, `*.sym`).
These are the already-documented sanitizer/`-----BEGIN…-----END` compiled string
tables in the app, Flutter engine and libmpv, mirrored into the AAB
`debugsymbols/*.sym`. **9 further compiled non-key PEM blocks (e.g. `DH
PARAMETERS` in `libmpv.so`) were explicitly excluded from the private-key count**
and are likewise inside allowlisted compiled binaries.

## Results — integrity

- **8 primary sums** in `SHA256SUMS.txt` == staged actual bytes (all 8 present,
  referencing existing files, no extra/missing).
- **8 `.sha256` sidecars** present (one per primary) and all verify against
  staged actual bytes.
- **17/17 staged files** carry a verified hash or sidecar. Frozen digests match:
  `SHA256SUMS.txt` `0f7a7952…62c25`, Linux tar `cc9b51c6…1730` (23,087,580 bytes),
  Android BUILD-INFO `51731e79…abda9`, Linux BUILD-INFO `01df1645…96bd29`,
  `update.json` `6bfceb82…99cc`.
- **4 manifest entries** in `update.json` == staged actual bytes: names/sizes/sha256
  all match, artifact set = 3 APK + 1 Linux tar, `androidVersionCode` 2005/1005/4005,
  `version` `1.0.4`, `buildNumber` `5`, `sourceCommit` `b397ec6…4608`.
- Both BUILD-INFO files carry the source commit, `1.0.4+5`
  (`com.antigravity.valhalla.valhalla`, Norns Interactive) and this staging dir.
- **Linux bundle equality:** in-tar `valhalla` executable is byte-equal to the fresh
  source bundle executable (48,856 bytes, exec bit present); **47** in-tar bundle
  files byte-equal to the source bundle, **0** differ; embedded
  `valhalla/BUILD-INFO.txt` is byte-identical to the sidecar (5,478 bytes).
- Source identity: worktree `/tmp/opencode/valhalla-v104-src-69MZyb` HEAD ==
  `b397ec6…4608`, `git status --porcelain` 0 lines; repo HEAD the same commit.
- Immutability: all 17 staged mtimes predate this audit run.

## Limitations / notes

1. The requested password filename `.password` does not exist; `android-release.password`
   was resolved by filename inspection. No secret was echoed anywhere.
2. `apksigner`/`aapt` version and signature verification was **not re-run** here; it
   was already verified in `agent-workflow/2026-10-11-v104-packages.md` and is carried
   as-is. This pass performed no bespoke binary-XML/protobuf parsing.
3. The 4 archive files were re-staged at 11:59 UTC when ROOT corrected the package
   metadata (Linux tar, both BUILD-INFO sidecars, `update.json`, `SHA256SUMS.txt`).
   The earlier `SHA256SUMS.txt` digest discrepancy is retired — the staged digest now
   equals the frozen value `0f7a7952…62c25`.
4. No runtime acceptance: the Linux executable was never launched, and the AAB
   remains a Play-only artifact (its `jarsigner` warnings are recorded in the
   packaging report, not re-litigated here).
5. The modified `README.md` in the repo is ROOT's own v1.0.3→v1.0.4 download-link
   edit, not part of this audit; this audit changed no artifact, performed no build,
   no git mutation, no network call and no ADB operation.

**Verdict: upload-blocking secret and integrity gates all clear, exit 0.**
