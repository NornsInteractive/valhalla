# Shared remote browser core — 2026-10-13

This is the current implementation contract for AgY UI integration. No widget should execute SSH commands, instantiate ACP transports, or close a shared SSH/SFTP connection.

## Models and rendering

Import `data/models/remote_browser.dart` and `core/services/remote_browser_service.dart`.

- `RemoteBrowserEntry`: `id`, `name`, `isDirectory`, `canEnter`, nullable `sizeBytes`/`modifiedEpoch`/`mimeType`, `isSymbolicLink`, `linkTargetErrorCode`; getters `isHidden` and `selectable`.
- Filesystem `id` is the adapter-local absolute path. Media library `id` is opaque, `isDirectory=true`, `canEnter=false`. Never append opaque IDs to breadcrumbs or let the directory row navigate solely on `isDirectory`.
- `RemoteBrowserSource`: `targetKey`, `label`, `rootPath`, `initialPath`, `flat`, `isCurrent`, `supportsPreview`.
- `source.list(path)` returns `Stream<List<RemoteBrowserEntry>>` of **incremental batches**, not cumulative lists. Clear once per navigation, append each batch; reject late navigation batches with a widget-local generation counter.
- Cancel the previous list subscription immediately before navigating. Each list has its own cancellation token; canceling one directory read does not invalidate the browser lease or close preview/transfer channels. Source disposal cancels all outstanding list requests.
- `source.parentOf(path)` returns null at the true boundary. `normalizeLocation(path)` validates the boundary. Never display translated labels such as `默认(/)` as the navigation path.
- `source.preview(entry, maxBytes: ...)` returns bounded image bytes or null; default 1 MiB, hard cap 8 MiB. Only request visible thumbnails with a bounded queue/cache; NAS directory/library pickers do not preview media.
- `source.selection(entries)` validates availability/current target and returns `RemoteBrowserSelection(targetKey, entries)` with immutable entries. Caller checks `source.isCurrent` and its draft identity before applying the returned value.
- Directory-mode “select this directory” constructs an entry with current path/name/isDirectory=true; **flat library mode must not select `/` as a library ID**. The all-libraries option is the caller's existing `/` root setting.
- `remoteBrowserDirectoryMissing(error)` returns true only for not-found errors. Only this failure allows walking to the nearest existing parent; do not fallback on permission/network/protocol errors.
- Always `await source.dispose()` in `finally` after the modal returns. Disposing invalidates late results and releases only owned resources. Do not test `isCurrent` after disposal to apply an already returned result: check before disposing.

## Host directory/file selection

```dart
final source = ref.read(remoteBrowserFactoryProvider).host(
  initialPath: currentPath,
  isCurrent: () => mounted && draftStillUnchanged(),
);
try {
  final result = await showSharedBrowser(source);
  if (mounted && source.isCurrent && result != null) apply(result.entries);
} finally {
  await source.dispose();
}
```

The factory captures active server connection settings, SSH client identity and SFTP operations. Production requests each own a `SftpClientService` using the captured SSH client; list cancellation closes only that request's SFTP channel. It uses read-only `SftpOperations.listFiles`, never the main file page's mutable navigation provider. Connection/server changes invalidate the lease.

## Agent working directory / ACP attachment selection

```dart
final snapshot = ref.read(cliChatProvider).activeAgent!;
final source = await ref.read(remoteBrowserFactoryProvider).agent(
  profile: snapshot,
  initialPath: draftWorkingDirectory, // Null/non-absolute resolves target's pwd.
  isCurrent: () => mounted && ref.read(cliChatProvider).activeAgent == snapshot,
);
```

For ACP use `aiChatProvider.activeAgentProfile` plus its draft/session identity in `isCurrent`. The core executes read-only file operations via the captured host/container/user binding; it does not create an ACP session. Preserve existing attachment type/count/size validation when importing selected entries.

## NAS saved source vs draft

```dart
// Scan/include/exclude selection from a saved source; preserves full credentials.
final source = await ref.read(nasSourcesProvider.notifier).openSavedBrowser(
  savedSource,
  isCurrent: () => mounted && currentSourceId == savedSource.id,
);

// Unsaved source form root/library selection; does not save/select/probe/scan.
final revision = formRevision;
final source = await ref.read(nasSourcesProvider.notifier).openBrowser(
  draftSource,
  draftCredentials,
  keepEmptySecrets: isEditing && passwordField.isEmpty,
  isCurrent: () => mounted && formRevision == revision,
);
```

`formRevision` must change on type, endpoint, SSH tunnel/server, username, user ID, password/token or domain changes. Token/user ID from a completed authentication must be cleared if their target identity changes; suppress late authentication results using the same revision guard. Never reuse a transient login token simply because the form retains the same source ID.

NAS browse roots/initial locations:

| Source | True root | Initial location | Returned selection |
| --- | --- | --- | --- |
| SFTP | `/` | configured `rootPath` | server absolute path |
| WebDAV | `/` inside configured endpoint/root | `/` | source-relative path |
| SMB | `/` inside share/endpoint subdirectory | configured `rootPath` | endpoint-relative path |
| Jellyfin/Emby | flat library list | `/` | library ID |

Saved-source changes, SSH target changes and reconnect client replacement invalidate outstanding results. Credential-only saves also invalidate existing leases: saves publish a fresh immutable source object, and browsing captures that object identity rather than relying solely on the metadata hash. Browsing a draft owns its adapter/tunnel/cancellation; canceling it never closes a shared SSH client.

Secure credential save/delete also advances a per-source generation immediately after the secure write succeeds, before ordinary metadata persistence. If subsequent persistence fails, browsing that source in this process is blocked with `NAS_SOURCE_SAVE_INCOMPLETE`; a successful resave with explicitly supplied credentials clears the guard. Mere probes and failed secure writes do not invalidate credentials. This guards current-process browser leases only: the existing separate secure/metadata stores are not transactional, and cross-store inconsistency after restarting from a failed save is not fixed by this change. The cached playback adapter is also outside this browser guard.

Legacy SFTP sources without `sshServerId` bind to `source.id`, matching the adapter. A referenced SSH server must exist in `serverListProvider` even if a stale client remains in the SSH manager. Removing its profile invalidates the lease immediately, before the client closes.

### SMB domain editing

```dart
final initialDomain = await ref.read(nasSourcesProvider.notifier).savedDomain(savedSource);
if (mounted && !domainWasEdited && formIdentityStillMatches()) {
  domainController.text = initialDomain;
}
```

Disable save/probe/browse until this initial domain read finishes, or retain its pending Future and await before building credentials. A user-typed/cleared domain must not be overwritten by the late read. Submit `NasCredentials(domain: domainController.text.trim(), ...)`: leaving the prefilled value preserves it; explicitly clearing submits `''`. A changed SMB domain is a changed credential identity and blank password does **not** reuse the old domain's password.

There is no `domainChanged` parameter; existing `save` and `probe` signatures remain unchanged. Provider credential merge now reuses blank secrets only for the same saved source type/endpoint/user/user ID/tunnel and same SMB domain. `openSavedBrowser` loads complete saved credentials without exposing them to the widget.

## Verification handoff

### Backend factory / cancellation contract

`RemoteBrowserSource`'s constructor now requires `list: (String path, Future<void> cancelled) => Stream<List<RemoteBrowserEntry>>`. Update test fake constructors accordingly; **the public UI call remains `source.list(path)`**. The cancelled future completes on request cancellation, lease disposal, failure, or normal completion, and must release only this operation's resources. Do not use it to dispose the shared NAS adapter or shared SSH manager.

The source uses a controller `onCancel` so cancellation is signaled before waiting for backend stream cleanup. Late errors/results are handled and discarded. NAS translates this signal to a new `NasCancellation` for each directory read; HTTP closes its request client and SMB signals its native worker. Host and Agent directory requests have their own SFTP/file-operation owners; Agent image previews keep a separate lease owner.

Protocol limit: dartssh2 does not expose cancellation of an already-requested SSH channel/subsystem before its open handshake returns. Browser cancellation returns promptly and closes any late-created channel, but cannot force the server to acknowledge an outstanding channel open without closing shared SSH (which this code never does). The low-level `sftpRemoteBrowser` helper, when intentionally given only borrowed `operations` and no `createRequestOperations`, can discard a canceled result but cannot cancel that borrowed operation. Production `remoteBrowserFactoryProvider.host` supplies the per-request factory.

Core has not run tests/analyzer/build (verification remains delegated). Add focused regressions for late target/draft response rejection; disposal not closing shared SSH; directory parent fallback only on absence; SFTP and Docker directory symlinks; bounded preview; transient source not saved/selected/scanned; changed endpoint/type/user/tunnel/domain never receiving saved secrets; prefilled-domain preservation versus explicit clear; saved-source credentials unchanged.

Also cover legacy SFTP `sshServerId == null` with client replacement/server removal; missing server profile despite a live manager client; credential-only source saves during credential load and during directory listing; stale domain-load completion after a credential-only save. These must reject the previous lease/result without deleting or exposing saved credentials.

Cancellation regressions: stalled backend before first item; immediate `subscription.cancel()` completion and cancellation signal; late backend error after cancel produces no uncaught exception; canceling one list while another list/preview/transfer remains active; `dispose` cancels all lists without awaiting delayed channel-open cleanup. Persistence regressions: secure write succeeds then metadata/selection write fails → prior lease invalid and new browser rejected; failed secure write/probe-only → prior lease remains valid; successful explicit resave → browsing recovers.

Docker workspace `find` still emits four NUL-delimited fields, but the type field is now `%y%Y`: `dd`/`ff` normal entries, `ld` directory links, `lf` file links, `lN` broken links. Older one-character fixture types continue to parse. The directory command uses `find -H` so an entered symlink directory can be traversed without recursively following its children.
