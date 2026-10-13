# NAS experience, Jellyfin deployment, and selective application cleanup

User approved implementation after the design decisions below. Preserve the dirty
workspace and earlier unfinished reliability work. No push, release, version bump,
production server mutation, uninstall of the mobile app, or clearing user data.

## Ownership and gates

- Root/core helpers: business logic, safety checks, storage compatibility, docs.
- All product UI, interaction, visible copy and ARB: original AgY Valhalla
  ec81a4be-7543-45ee-8658-f68966f57d3b; gemini-3.8-flash-high, effort high.
- AgY must read the complete taste skill at
  /home/dev/.codex/skills/design-taste-frontend/SKILL.md. Native Flutter is outside
  that skill's web stack scope: preserve Material/design tokens, apply relevant
  redesign/motion/a11y principles, no React/CSS packages or decorative fake media.
- Test authoring, generation, formatting, analysis, builds and retained-data ADB
  verification: OpenCode explicitly free models, MiMo first. Previous iteration's
  root exception does not grant this iteration the same authority.
- Real mutation tests use only an independently identified disposable VM. Current
  production SSH servers and the agent's own Codex session are not test targets.
- Do not rotate authentication files to work around provider quotas. Provider
  failure is reported; product UI is not silently reassigned to root.

## Confirmed product choices

1. Uninstall lists bind mounts individually, all unchecked. User-selected safe
   directories are permanently deleted after a second confirmation by app name.
   No recycle bin. User can select exclusively used external/legacy/media paths
   after explicit risk acknowledgement; these are not automatically claimed.
2. Shared paths, system/home/control/runtime directories, symlinks, mountpoints,
   nested mounts, file binds and Docker volumes remain protected. Unknown/incomplete
   ownership inspection blocks deletion, not ordinary data-preserving uninstall.
3. Jellyfin supports app-center Docker deployment and native host installation.
   Docker first release uses an explicitly reviewed software-decoding profile;
   GPU passthrough is out of scope.
4. All three follow-ups are included: deployment-to-source onboarding, scan and
   connection diagnostics, source-scoped cache and offline-space management.

## First close existing regressions

Use 2026-10-12-apps-nas-ui-final-check.md and its existing real regressions:
NAS batch toolbar at320dp/2x, Home selecting a photo must not open its viewer;
app-store deep-scroll list/grid anchor, per-source retry(sourceId), target-changed
explanation in access diagnostics. Do not weaken passing behavior or test limits.

## Selective uninstall

- Preview derives mount keys and canonical paths from trusted current config,
  compose and actual container inspection, not arbitrary UI-supplied paths.
- Show complete source/target, service references, read-only property and risk;
  deduplicate paths. Size estimation is optional/bounded and cannot block safety.
- Check all containers including stopped ones plus other managed app records for
  same/ancestor/descendant paths. A selected ancestor cannot include a protected
  or explicitly retained descendant. Control/task files are never cleanup targets.
- Plan binds host/daemon identity, config fingerprint, real paths and device/inode.
  Recheck under worker lock and after successful compose down, before cleanup.
- Use validated directory-handle/no-symlink deletion with target identity checks;
  if those capabilities are unavailable, refuse cleanup. Never down -v or prune.
- Persist per-target removed/already absent/retained/failed outcomes. Show partial
  completion accurately; manual retry creates a new preview and confirmation.
  Connection recovery reconciles prior task instead of replaying deletion.

## NAS UI and core

Preserve main navigation and Norse Steel theme tokens. Design read: native media
library, content-first and touch-friendly, restrained fluid motion. Suggested
dials DESIGN_VARIANCE5/MOTION_INTENSITY4/VISUAL_DENSITY6; native accessibility wins
over web defaults. Reuse global mini player, queue, viewer and offline infrastructure.

- Home: recently added, continue watching/listening, favorites, compact source and
  scan status. No invented media or placeholder usage statistics.
- Photos: gallery grid, honest modification-date grouping, folder albums,
  long-press selection, viewer return anchor. No EXIF claim this release.
- Music: songs/albums/artists/playlists, album cover+track view, play/shuffle.
  Stable remote album identity where present; local source+album artist+album,
  folder fallback when tags are missing; nullable disc/track metadata for ordering.
- Video: real thumbnails, per-item persisted progress and continue watching.
  File sources stay videos, not invented film/series metadata or covers.
- Library: folders/favorites/playlists/downloads, consistent selection and actions.
- Group queries accept media kind and scope, bounded date ranges; batch playback
  lookup, no per-tile database calls. Bidirectional keyset gallery window max600
  items with max200 per page and stable anchor when evicting pages.
- Preserve source/category/search/sort/position; stale work cannot change a new
  source. Existing same-ID source edits invalidate identity-bound results.
- Motion150-250ms only for state changes, honors disableAnimations; no unbounded
  tile animation controllers or full-resolution media fetches for previews.

## Jellyfin deployment and onboarding

Docker shortcut resolves source zimaos-official + app org.icewhale.jellyfin and
opens existing app-center details for the currently connected explicit server.
If experimental app center is disabled, ask to enable; never change menu order.
Official catalog unavailable: keep cache and offer retry, no title-based substitution.

The current upstream template includes devices and /opt/vc/lib. Software profile
must show an explicit diff removing hardware-only mappings and re-run the unchanged
generic validator. Bind media read-only, app config writable. Preserve original
template identity plus chosen profile for configure/update; no global policy bypass.

Native service is Jellyfin-only prepare/execute/reconcile, separate from Docker's
compose-bound result type. Support Debian/Ubuntu amd64/arm64 with systemd and an
available official signed APT repository/package; require root or noninteractive
sudo. Preflight OS/version/architecture, package locks, disk, ports, paths and
existing installs. Existing Jellyfin offers check/connect, not overwrite/upgrade.
Pin previewed package version. For a new service, prevent automatic startup until
loopback binding is configured, then start and verify actual listener. Do not
change firewalls, recursively chmod media, or overwrite pre-existing service/masks.
Cancellation uses safe checkpoints; interrupted package work is reconciled, not
killed/replayed. Persist server-bound tasks with bounded sanitized command/log data.

After either deployment offer official setup and Add Source. New-source form gets
an explicit initial draft distinct from its existing-record editing parameter.
Save remote endpoint+SSH binding, not an ephemeral local forwarded address. User
initializes Jellyfin, authenticates, probes, then explicitly saves. Credentials
stay in existing secure storage. Preserve old NAS Docker task reconciliation.

## Diagnostics and storage

Expose real connection/scan stage, discovered count, last success, actionable
failure and sanitized copyable logs. Unknown total uses indeterminate progress.
Keep old media while refresh/reconnect proceeds; retries do not replay mutations.

Source-scoped thumbnail/download usage and clearing reuse existing services.
Track cache ownership for new entries; unidentifiable existing entries are an
explicit legacy bucket, never falsely assigned or silently deleted. Clearing
cache cannot delete offline media; removing downloads has its own confirmation.

## Acceptance and delivery

Regression: default zero deletion, exact selected targets, external explicit
confirmation, protected/shared paths, path replacement, switched server, failed
down, failed cleanup, disconnect/reconcile, old installation records. VM markers
outside selected paths must survive. Both Jellyfin deployment paths must complete
setup/login/source browse/playback on isolated targets before claiming acceptance.

100k-item sorting/grouping/migration, bounded600-item window, metadata fallbacks,
progress batch queries, preserved playlists/downloads/progress; source-switch and
offline invariants. UI320dp/2x/RTL/desktop/light/dark/reduced-motion plus measured
profile-mode performance. OpenCode full gates before a compatible-signature APK
and install-r on the selected ADB device. Installation alone is not acceptance.

Update requirements, frontend design, architecture, implementation status and
test evidence as work lands. This document records approved scope only, not
completion. EXIF, scraping, GPU passthrough, recycling and native auto-upgrades
are excluded. External-directory exclusive use still requires human confirmation.
