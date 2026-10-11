# v1.0.4 existing-release refresh

User now requests local compilation, packaging and GitHub publication without a
new version. This supersedes the six-workstream implementation's no-publication
boundary only for this release operation.

## Contract

- Keep `1.0.4+5`, application ID and existing public Android certificate
  `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
- Reuse the confirmed Android/Linux local scope: three signed ABI APKs, signed
  AAB, complete Linux x64 archive, BUILD-INFO, checksums and `update.json`.
  No Actions, Windows/macOS/iOS/Web, ADB install or server operation.
- Build the newly committed six-workstream source, not the old v1.0.4 tag or
  the debug-signed x86_64 test APK. Preserve old published/staged packages.
- Push source normally with `[skip ci]`; never force push or move the original
  annotated `v1.0.4` tag (`b397ec62255fa9cc0575941450a4b2cdadfa4608`).
  BUILD-INFO, manifest and refreshed release notes identify the actual new
  source commit explicitly; GitHub's tag-based source archive remains original.
- Replace only the existing 17 Android/Linux/update assets after local signature,
  version, archive, provenance and secret-exclusion gates. Resolve and back up
  current assets first; retain unrelated releases/assets. Upload packages and
  checksums before the update manifest; verify remote size/digest and public
  download. No delete-and-recreate release or invented release version.
- OpenCode owns all validation/build/packaging. MiMo free is attempted first;
  user-authorized confirmed-free Step 5 Preview Free fallback is permitted on
  failure/deadline, with both main/small explicitly configured. No UI edits.
- Build commands must omit `--no-pub`: this toolchain otherwise leaves the
  dev-only integration-test registrant in release builds. Let normal Flutter
  regenerate tooling; do not patch generated files/SDK, upgrade dependencies,
  delete shared caches or change signing. Source and lock must remain unchanged.

## Acceptance

Reuse the completed 2495-pass/18-explicit-skip/0-failure suite and zero-analysis
result only if runtime/test sources still match the settled gated state. Capture
new local build commands, own exits, original output UTC timestamps, ABI/version,
certificate, complete archive contents, checksums and private-material exclusion.
Match every remote asset to the verified staging directory and check no Actions
were triggered. Compilation does not prove real ACP/OAuth/NAS or Linux desktop
runtime acceptance.

Same semantic version/build is deliberate: existing clients may not offer an
automatic update; manual installation requires the same public signing identity.
The public APK cannot cover a debug-signed test installation. Do not uninstall or
clear data to bypass that mismatch.

## Preflight evidence

MiMo's console deadline exited 124 without results. Authorized Step 5 Free then
verified an exact byte match with the settled runtime manifest
`f5ce0efea731f476583d3fc0cf344cd97e89f34dd49b4c270c2194721c6e01cc`,
no test file newer than the final whole-suite log, 2495/18/0 summary and zero
analysis, current `git diff --check` exit 0, and no real private keys or vendor
tokens in the owned changes. Evidence is `/tmp/opencode/preflight-step5/`.
An initial parallel token scan raced its file-list creation and was rerun;
only the completed rerun is accepted. The enclosing Step 5 console deadline
also exited 124 before completing the certificate check; individual completed
checks are recorded, not a claim that the entire preflight job succeeded.
Formal certificate validation remains mandatory in the build phase.

## Completed publication: 2026-10-11 11:22 UTC

Status: complete. Source `83d3c90c8e7dc8c734091ea330571a5f59aed09f`
was pushed normally with `[skip ci]`; the existing public
[v1.0.4 Release](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.4)
(ID `409398862`) now contains all 17 refreshed assets. Version remains `1.0.4+5`.
The original annotated tag object `359689749927f6bc2e54a824dd77397cca89d8ac`
and dereferenced original commit `b397ec62255fa9cc0575941450a4b2cdadfa4608`
are unchanged. The release remains public, not prerelease; its original published
timestamp is retained. Tag-based GitHub source archives still contain original
source; BUILD-INFO, `update.json` and notes identify the new package source.

### Actual builders and exception

OpenCode, explicitly using `opencode/step-5-preview-free` for both main and small
models, completed all three builds with each command's own exit **0**:

| Local command | Start → end UTC, 2026-10-11 |
| --- | --- |
| `flutter build apk --release --split-per-abi` | 10:41:36 → 10:42:46 |
| `flutter build appbundle --release` | 10:43:15 → 10:43:59 |
| `flutter build linux --release` | 10:44:32 → 10:45:17 |

Original APK output timestamps are 10:42:45 UTC; AAB is 10:43:59 UTC and the
new Dart AOT `libapp.so` is 10:45:16 UTC. The unchanged Linux native runner is
legitimately cached from October 4; its timestamp is not represented as a fresh
native compilation. Logs are `/tmp/opencode/v104-refresh-build.AYgp0X`.
All **622 tracked runtime/platform/asset/pubspec inputs** were byte-identical
before and after builds and final packaging, including the dependency lock.
Their recorded manifest digest is
`424d981c1a4f21fc46bbc06e1a6570fa3729f398fbf72b15e57342cbfdf8f377`.
The settled 2495/18/0 suite and zero-analysis result were reused only after that
source matching proof; not claimed as a newly repeated full suite.

After successful builds, Step 5 packaging stalled; those two console attempts
were interrupted with exit 130. Big Pickle and Space Bunny free then returned
rate limits and were likewise stopped, without packaging writes or accepted
verification results. User explicitly authorized the main agent to complete
**only this remaining packaging, verification and upload**, with no UI change,
version change or Actions. Future OpenCode delegation rules are unchanged.

### Package and verification evidence

All three APKs directly passed `apksigner verify`, with the original certificate,
package ID, version `1.0.4`, ABI codes 2005/1005/4005, minSdk 24 and targetSdk 36.
AAB `jarsigner -verify` exited 0 and its certificate matches; self-signed/no
timestamp and JarInputStream consistency warnings are retained, not explained
away as APK v2 signatures. All four ZIP archives passed CRC and unique-member
checks. The tool's cached Flutter version says 3.44.2 but actual SDK git version
is 3.38.1 (`b45fa18946`); no SDK patch or official 3.44.2-framework claim.

Linux packaging includes the complete **48-file release runtime**, eight license
notice files and embedded BUILD-INFO. An old debug `kernel_blob.bin` (97,210,208
bytes, September 23) left in the reusable build output was moved **only from the
owned staging copy**, not deleted from the original build/cache. It and the
initial raw tar are recoverable in `/tmp/opencode/v104-refresh-package.00HjOV`.
Every remaining runtime file is byte-equal to the successful build output;
ELF x64, executable mode, safe single-root tar paths and BUILD-INFO equality
passed. `ldd` found no missing runner dependencies in this container, not a GUI
runtime test. Old shared caches and signing material were not removed or changed.

Existing update-manifest generator produced the four APK/Linux entries; its
**27 tests passed**. Eight primary checksums and eight sidecars all matched.
The read-only pre-upload audit scanned **2089 byte surfaces** (17 raw files,
2015 ZIP members, 57 tar files), finding zero signing-password, PKCS#12/JKS or
real PEM private-key payload leaks. Compiled public PEM marker strings are
explicitly distinguished from actual private keys. Audit exited 0, failures 0.
No product/UI files were edited during packaging.

Verified final primary binary SHA256 values:

```text
889b5b9248431c36d11abbfcc599c2bdccf641ff7b5f533046cdfc6065083df3  valhalla-v1.0.4-android-arm64-v8a-signed-5.apk
35d299d1a8b9bba739a282994c4185175b6b6b9a5750ee34a4e978973a0409d6  valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk
618c78c024673c11b81f734dca3dfd26427e583924577278f98866d839298945  valhalla-v1.0.4-android-x86_64-signed-5.apk
7ce1a0c117547c213f19aa827f06e68c63319854f30a5b6b3c843a0d4c91efcb  valhalla-v1.0.4-android-signed.aab
d747918771e054cd90a3644320ea90d284b411080aa148e67ea1aa4b6306adfa  valhalla-v1.0.4-linux-x64.tar.gz
```

### Remote publication proof

Before replacing assets, all 17 original remote names/sizes/digests were matched
to the retained backup `/tmp/opencode/valhalla-v104-release-WweZbH`; release body
and asset IDs were saved as `remote-before.json`. Only those same 17 names were
clobbered; packages/checksums uploaded before the update manifest. Both upload
commands and release-notes update exited 0. No release recreation, tag move,
unrelated asset deletion, paid fallback, Actions or ADB operation occurred.

Final API verification checked **actual remote `digest` fields**, uploaded state,
size, replacement IDs and exact 17-name inventory against frozen local bytes.
Public `update.json` and `SHA256SUMS.txt` downloads are byte-identical to staging;
ARM64/Linux public download HEAD requests return HTTP **200**. The original
annotated tag is unchanged and source-commit Actions run count is **0**.
Remote proof exited 0 with `REMOTE RELEASE RESULT: PASS` at 11:22 UTC.
Local/final remote evidence is `/tmp/opencode/v104-refresh-package.00HjOV`;
final artifacts are `/tmp/opencode/valhalla-v104-refresh-release.9yCB3h`.

No fresh physical-phone, Linux GUI or real ACP/OAuth/NAS end-to-end acceptance is
claimed. No ADB deployment was requested or performed here. Same-version clients
may need manual download; public APKs cannot cover debug-signed installations.
