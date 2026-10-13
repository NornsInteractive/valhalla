# NAS browser protocol handoff

Implementation handoff. The subsequent user-authorized direct-team protocol verification is recorded in [nas-browser-test-results.md](nas-browser-test-results.md); the original OpenCode ownership notes below describe the initial handoff, not the current execution status. Build and device verification remain with the parent.

## Contract

`NasSourceAdapter.browse(path, cancellation)` yields batches of `RemoteBrowserEntry` from one directory. It never saves a source, changes the active source, starts indexing, or closes a shared SSH connection. Old adapters/fakes inherit an explicit unsupported error.

| Source | Browser IDs | Initial location | Boundary |
| --- | --- | --- | --- |
| SFTP | Absolute server paths | Source root | Server `/`; configured root is only a default |
| WebDAV | Paths relative to configured source root | `/` | Endpoint plus configured root |
| SMB | Paths relative to endpoint share/base | Source root | Endpoint share/base; root is not appended twice |
| Jellyfin/Emby | Opaque accessible library IDs | `/` | Flat library chooser; entries cannot be entered |

SFTP uses paged `readdir` in its own SFTP subsystem. WebDAV uses streaming Depth-1 PROPFIND, 128-entry batches, and literal URI path segments. SMB adds `SmbClient.list` by reusing the existing cancellable pull-based worker without recursive traversal or C ABI changes. Media servers use `Users/{userId}/Views` and keep library names separate from IDs.

Scan filters retain existing serialized string fields. Library IDs are removed from planned parent queries; legacy item/folder IDs are resolved through user-scoped item metadata. A legacy folder without a usable physical path, or an include whose membership in an excluded library cannot be resolved, fails closed. Physical path filters are literal subtree comparisons. SFTP `find -path` now escapes glob characters independently of shell quoting.

SFTP scans use `find -H`: an explicitly selected symlink start directory is followed, but links discovered inside that tree are not traversed. The portable stat fallback also dereferences an explicit start-file link. Exclusion normalization keeps ancestors, equals and descendants of included roots; excluding `/media` (or `/`) when including `/media/photos` remains an effective empty scan, never an unfiltered scan.

All distinct explicit include roots are retained after normalization, including an explicit symlink below a selected parent. Each root's find command prunes other explicit descendant roots; those are scanned independently. Native and portable paths use the same root partition and stop on the first failed command, with no additional SSH preflight round trip. Existing normalization tests must now expect both `/media` and `/media/photos`, while real enumeration must still return ordinary nested files once.

SFTP resolution retains fresh nullable stat size instead of substituting indexed size. A strong version is available only with both fresh size and mtime; unknown-size resources cannot resume old partial downloads. Unknown-size full reads use bounded 256KiB sequential requests until EOF because the installed dartssh2 implementation cannot accept a null read length without stat.size. Known-size reads keep the existing pipelined path.

New error codes: `NAS_BROWSE_UNAVAILABLE`, `NAS_INVALID_DIRECTORY_ENTRY`, `NAS_INVALID_LIBRARY_RESPONSE`, `NAS_SCAN_FILTER_UNRESOLVED`. Existing permission, HTTP, SMB and cancellation errors are preserved.

## Required regression proof

- SFTP: absolute navigation outside configured default; omit dot entries; resolve directory symlinks; blocked/broken link state; cancellation closes only the owned subsystem; literal `*`, `?`, `[`, `]`, backslash and apostrophe exclusion paths do not prune neighboring directories.
- Scanner contract additions: an explicit symlink root contains a normal media file and an internal symlink to a separate sentinel tree; only the direct media file is indexed. Run the same fixture with native printf and forced portable fallback. Include `/media/photos` with excludes `/media` or `/` must normalize retaining the exclude and index nothing successfully; equal/descendant exclusions still work, unrelated exclusions remain ignored. OpenCode owns these regression edits/execution.
- Overlapping explicit roots: select a parent plus an ordinary child, grandchild and symlink child. Exact duplicate roots collapse, normal files appear once, explicit link content is indexed, links encountered below a root are not followed. Excluded parents still suppress every separately enumerated child. Include glob characters in a selected child path to prove partition pruning is literal. Exercise GNU and portable paths and fail a later root to prove the scan does not report success.
- SFTP stat-size regression: initial stat.size absent with a stale nonzero indexed size, followed by file.stat.size absent, must not report SOURCE_CHANGED; resource size/version stay null and reads proceed to real EOF past the stale index length. Cover short files, exact 256KiB multiples, empty files, cancellation and explicit end ranges. Fresh known size/mtime changes must still fail before reading. OpenCode owns mock SFTP regression edits/execution.
- WebDAV: root `/`, nonempty endpoint/base and configured root; relative hrefs; spaces, Unicode, percent signs and literal `%2e%2e`; reject cross-origin/out-of-parent/encoded slash entries; only Depth-1 requests; batches stay at most 128; cancellation does not keep a live request.
- SMB: list returns only immediate children, walk remains recursive; share/base and default root are not duplicated; invalid traversal fails before native IO; cancel/pause release or bound native work. Native smoke test needs the existing isolated SMB fixture/library, not a production share.
- Media servers: same-name/different-ID libraries; empty library list; malformed/401/403 responses; excluded library never queried; all libraries excluded means no item request; legacy folder, item and physical-path filters; unresolved folder or missing item Path fails instead of indexing unfiltered data; default scan still pages 200 + 1 without a library request.
- Integration: source-editor drafts browse without saving, scanner uses the returned IDs verbatim, switching server/source drops late results, and library selection never creates filesystem paths.

Protocol references: [Emby browsing guide](https://dev.emby.media/doc/restapi/Browsing-the-Library.html), [Emby user views](https://dev.emby.media/reference/RestAPI/UserViewsService/getUsersByUseridViews.html), [Jellyfin user-view controller](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/UserViewsController.cs).
