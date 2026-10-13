# NAS browser protocol regression results

Completed under the user's one-round authorization for direct team verification after OpenCode stopped. No production server, UI, ARB, build or ADB operations were performed by this test task.

## Executed results

- Root focused suite: **72 passed, 0 skipped, 0 failed** with `--no-pub --concurrency=2` across `nas_scan_service_test.dart`, `nas_sftp_metadata_test.dart`, `nas_browser_protocol_test.dart` and the unchanged `nas_network_adapters_test.dart`.
- SMB package focused suite: **4 passed, 0 skipped, 0 failed**, including the new native one-layer and cancellation check.
- Targeted Dart analysis of the three changed/new root tests and five NAS implementation files: **No issues found**.
- The first SMB test compile failed because new Dart imports were placed after declarations; fixed and rerun successfully. One root-test brace lint was fixed and targeted analysis rerun clean. No production-code change was needed during this verification pass.

## Proof provided

- Real temporary-directory shell execution for both native printf and forced portable fallback: explicit parent/child/grandchild/symlink roots, no ordinary subtree duplicates, no traversal of unselected/internal symlinks, literal glob characters/backslashes/quotes, ancestor or `/` excludes yielding an empty successful scan, and a missing later root preventing partial success.
- SFTP mock client/subsystem/file seams: unknown stat size with stale indexed size reads 0, 17, 262144, 262151 and 524288 bytes to actual fixture EOF; explicit ranges, cancellation, known size/mtime mismatch, absent strong validator, independent channel closure, one-layer listing, broken symlink status and propagated connection loss.
- Real loopback HTTP for WebDAV: Depth-1 only, 128-entry batches, relative hrefs, configured root and endpoint base, Unicode/space/percent/literal `%2e%2e`/backslash paths, rejection of outside/cross-origin/encoded-slash/NUL entries, cancellation while waiting for headers.
- Real loopback HTTP fixtures for both Jellyfin and Emby route shapes: same-name distinct library IDs, excluded libraries never queried, every library excluded, legacy folder/item IDs and literal physical paths, nested legacy include under excluded library, missing metadata failing closed, empty/malformed/401 library responses never broadening filtered scans. Existing 200+1 pagination, playback, authentication and security tests also passed unchanged.
- Real native SMB worker and local Impacket server: 2503 immediate entries over at least four bounded pages, no recursive child leakage, Unicode name, subdirectory enumeration, existing recursive walk, explicit cancellation/subscription cancellation followed by a new successful connection. NAS adapter browse and scan verified endpoint `/media/excluded` is applied once while configured default `/not-appended` is not spuriously appended to explicit `/` selection.

## Reproduction

The native tests are optional in ordinary CI and are skipped unless the fixture variable is set. This run enabled both optional tests; neither was skipped.

Start the existing local-only fixture with the already installed test environment:

```sh
/tmp/valhalla-smb-testenv/bin/python3 packages/valhalla_smb/tool/test_server.py
```

Root focused suite:

```sh
VALHALLA_SMB_TEST_LIBRARY=/tmp/valhalla-ygg-release.5yW0qv/linux-stage/valhalla/lib/libvalhalla_smb.so LD_LIBRARY_PATH=/tmp/valhalla-ygg-release.5yW0qv/linux-stage/valhalla/lib /opt/flutter/bin/flutter test --no-pub --concurrency=2 --reporter expanded test/infrastructure/nas_scan_service_test.dart test/infrastructure/nas_sftp_metadata_test.dart test/infrastructure/nas_browser_protocol_test.dart test/infrastructure/nas_network_adapters_test.dart
```

From `packages/valhalla_smb`:

```sh
VALHALLA_SMB_TEST_LIBRARY=/tmp/valhalla-ygg-release.5yW0qv/linux-stage/valhalla/lib/libvalhalla_smb.so /opt/flutter/bin/flutter test --no-pub --concurrency=2 --reporter expanded test/smb_client_test.dart
```

The local fixture process was stopped with SIGINT after verification; its TemporaryDirectory context cleaned only its generated test files. No dependency was added to app/package manifests. The reused native library exercises the unchanged C ABI; the modified Dart worker comes from the current workspace.

## Explicit limits

This is not device UI acceptance or a release build. SFTP transport itself was mocked; Jellyfin/Emby were API fixtures rather than real deployed servers; SMB was a loopback Impacket fixture rather than a Windows/Samba appliance. Portable scanner logic ran on Linux with GNU tools, not an actual BSD/BusyBox host. NAS source draft/lease/provider behavior is covered by the separate browser-core owner, not claimed here. Native tests need the optional fixture setup when rerun; a default all-tests run alone will skip them.
