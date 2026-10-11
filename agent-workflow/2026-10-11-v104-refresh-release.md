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

Status: source checks complete; no new build, source push or asset replacement yet.
