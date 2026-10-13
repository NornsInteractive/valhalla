# OpenCode — NAS and remote-browser regression authoring

Model opencode/mimo-v2.6-flash-free only, no paid models/subagents. Read complete
2026-10-13-browser-core-api.md and 2026-10-13-nas-browser-protocol-handoff.md, then
actual code. Allowed tests: test/infrastructure/acp_workspace_files_test.dart,
nas_network_adapters_test.dart, nas_scan_service_test.dart;
test/core/nas_source_integration_review_test.dart, nas_source_connection_provider_test.dart,
nas_saved_probe_test.dart; new test/core/remote_browser_test.dart and
nas_browser_provider_test.dart; packages/valhalla_smb/test/smb_client_test.dart.
No other tests, no product/core/UI/ARB edits, no format/generation/build/ADB/full
suite/production commands. Other OpenCode sessions own application tests.

Use apply_patch. Extend regression fixtures using actual new requests/responses,
not just assertion strings. Important cases in the two handoffs are mandatory:
single layer and batch cancel; no draft persistence/selection; literal glob names;
true library exclusion/no requests to excluded library; old IDs/path compatibility;
auth failures fail closed; domain preserved/explicit clear; changed target drops
late results; SFTP legacy source with sshServerId absent still binds source.id
SSH identity and requires existing profile. Browser close must not close sharedSSH.
NAS owner is finished, source provider owner making last target-guard fix: if a
compile error appears report it to root, do not patch product.

Run focused changed tests --concurrency=2. Test native SMB unit normalization or
existing fixture-only smoke if available but do not launch remote destructive VM
tests yet. No network credentials printed or live production source calls.
Write exact results/failures/missing tests to
agent-workflow/2026-10-13-nas-browser-test-results.md. Return actual test counts.

## Stable core followup (reread before the final focused gate)

Core is now frozen pending demonstrated test defects. Reread both linked handoffs:
RemoteBrowserSource constructor backend `list` now takes `(path, cancelledFuture)`;
public `source.list(path)` is unchanged. Cover cancellation before the first result,
late backend error/open disposal and shared SSH ownership. Successful secret writes
invalidate pending browser leases even if metadata/selection persistence then fails;
incomplete saves reject browser opening with NAS_SOURCE_SAVE_INCOMPLETE in-process.

Scan normalization now retains every explicit include root (only exact dedup).
Each root prunes other explicit child roots, which are scanned separately, including
directory symlinks; GNU and fallback share this behavior without duplicate ordinary
parent/child enumeration. Test ancestor exclusion, literal glob paths, selected-root
symlink with internal symlink cycle ignored, and failure on a later root.
SFTP unknown fresh stat size must stream to actual EOF, never use indexed size as
version/truncation; no trustworthy version means no resumed download. Include this
regression in the allowed network adapters test file.
