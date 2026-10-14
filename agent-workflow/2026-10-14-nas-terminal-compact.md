# NAS, terminal history and compact browsing — implementation contract

Status: implementation and source verification complete. No build, ADB install,
version bump, push or publication was performed in this round. Do not confuse
source verification with an installed/published APK.

## Final delivery — 2026-10-14

- Compact remote-file and store grids are implemented with horizontal icon/title
  layout, full file timestamps, adaptive text scaling and preserved view anchors.
- SSH new tabs use fresh identities; explicit history restore, per-target startup
  defaults and tab/history renaming are wired. Existing tmux opt-in remains off
  by default. Plain SSH/Mosh sessions are not falsely advertised as recoverable
  after app-process exit; closing a tmux tab only detaches it.
- NAS home/photos/video/music/library surfaces are redesigned using existing
  sources, players, bounded paging and caches. Audio queue append, typed favorites,
  real covers, downloads and management entrypoints are connected. Photo album
  return preserves page, position and original parent scope; stale source results
  cannot reopen old content. NAS remains experimental and off by default.
- All UI changes came from the original AgY Valhalla conversation using
  `gemini-3.8-flash-high` / `high`; root and collaborators handled core, regression
  tests and documentation under this round's direct-verification authorization.

Final gates, after the last favorites and album-return fixes:

| Gate | Result | Evidence |
| --- | --- | --- |
| Full repository tests | 3424 passed, 29 environment checks skipped, 0 failed; exit 0, 138s | `/tmp/valhalla-20261014-final-full-suite.log` |
| Whole-project analysis | No issues, exit 0 | `/tmp/valhalla-20261014-final-analyze.log` |
| NAS view/navigation | 91/91 passed, exit 0 | `/tmp/valhalla-nas-baseline-efH5zC/nas-ui-final-91.log` |
| Terminal UI including shell | 61/61 distinct checks passed | [Terminal recheck](2026-10-14-terminal-recheck.md) |
| Compact files/store/pickers | 147/147 passed | `/tmp/valhalla-20261014-compact-verified.log` |
| Localization generation / final UI formatting | Completed; final test-file format check changed 0 files | `/tmp/valhalla-20261014-final-gen-l10n.log`, `/tmp/valhalla-20261014-final-ui-format.log`, `/tmp/valhalla-20261014-final-test-format-check.log` |

The focused counts overlap the full suite and must not be added to its total.
`git diff --check` is clean. Full tests explicitly unset the existing live/VM
opt-in environment flags. No production server command, ADB action, account
rotation, destructive cleanup, build, commit, push or release was performed.
Real-device keyboard/gesture rendering, real SSH history restoration and live
NAS playback/network performance still require separately authorized acceptance.
The progress entries below retain historical red/green evidence; they do not
override this final verification summary.

## Ownership and boundaries

- UI: original AgY Valhalla conversation `ec81a4be-7543-45ee-8658-f68966f57d3b`,
  model `gemini-3.8-flash-high`, effort `high`. Use existing Flutter components,
  themes, localization and frontend-design skill. No new visual framework.
- Core: root/core collaborators. Tests, generation, format, analysis: OpenCode
  `opencode/mimo-v2.6-flash-free` first; report failure instead of assuming a
  previous round's direct-validation exemption. Previously user-approved free
  fallback models may be used only after confirming current free availability.
- No live SSH commands or media writes on user production servers, no current
  Codex interaction, no data removal, account/token rotation or shared cleanup.
- Preserve current tmux opt-in, NAS experimental state, navigation choices and
  all unrelated modifications. Do not silently install tmux or any media server.

## Phase A: compact files and application store (AgY can begin immediately)

Whitelist: `lib/widgets/remote_browser_view.dart`,
`lib/features/files/sftp_file_view.dart`,
`lib/features/app_center/widgets/app_store_tab.dart`, required `lib/l10n/*.arb`.
Do not edit tests, generated files, core/data/infrastructure or installed-app
business logic. Keep directory picker bounded; no transfer/management actions
in pickers. Main file-page actions and restrictions remain unchanged.

- Ordinary file grid: 22–24dp icon + filename SAME ROW; one-line ellipsis for
  name with complete accessible label. Compact metadata/action region below,
  full modification date/time on its own line. Typical regular-text target
  104–112dp, 8dp padding/gaps. Two columns at 320–599dp normal text; large text
  can use one column and taller rows. Permissions remain accessible in list
  view; do not add an unrelated file-properties feature.
- Selection should not consume all title width: arrange controls in action
  region in compact grids, preserving semantics and generous touch targets.
  Hidden-file fading and symlink/broken-link indicators unchanged.
- Shared ordinary picker grids receive same compact visual. Gallery mode is
  distinct and retains large image preview; do not shrink image gallery.
- Main file LIST: name first, permissions/size second, full `yyyy-MM-dd HH:mm`
  third. Current timestamp already contains minutes but Flexible/ellipsis clips
  them. At narrow widths/large fonts allow date/time to wrap without truncation.
  Keep existing timestamp source/timezone; do not fabricate missing values.
- Shared virtual list row geometry must account for these metadata lines;
  do not globally inflate simple picker rows. Optional explicit row geometry
  is permitted if needed, but virtualization/anchor math must use same geometry.
- Application STORE grid: 32dp icon with max-two-line title SAME ROW, one-line
  summary, compact source/status footer. Full version remains in details.
  10dp padding, 8dp grid gaps; normal-text target 112–128dp. Remove standalone
  large icon row, Expanded summary and unconditional empty badge slot.
  Existing TextPainter/TextScaler measurement must remain truthful for font
  scale/locale; never hard-clip text to hit target height.
- Keep installed-app adaptive cards and actions intact. Store view toggle must
  preserve visible item; update gridRowStride and all anchor/padding math along
  with actual layout. No persistence/preference reset.

## Phase B: SSH terminal identity and history

Current root cause: initial remote ID `0`, new ID `tabs.length + 1`, and tmux
`new-session -A` accidentally reattach old processes. Local Terminal is already
a fresh object. New means UUID + new model + create-only remote command; neither
defaults nor history may be applied to the plus button.

Core contract is delivered separately before UI wiring. UI whitelist then adds
`lib/features/terminal/terminal_view.dart`, `lib/features/shell/main_shell.dart`,
`lib/features/settings/settings_view.dart`, and local terminal widgets/ARB.

- Add history icon distinct from main menu; left drawer max 360dp / 85% viewport.
  Rows: title, last-used, recoverable/unknown/ended status, default marker and
  overflow actions. Scope to current server + host/port/user; no cross-target.
- Explicit history restore attaches ONLY an existing precise tmux name. Already
  open means select existing tab. Unknown/network failure is not 'ended'.
  Confirmed missing manual history remains ended; no silent replacement.
- Per-target startup choice: fresh (default) or selected recoverable history.
  Apply only first actual SSH-page activation after app cold start. Provider
  reads/hidden IndexedStack builds must not create a terminal. Returning from
  navigation/background/lock retains workspace, does not repeat startup policy.
- Missing default after authoritative check: clear expired default, report and
  create a fresh UUID. Network failure: retain default and allow retry.
- Current tmux switch is kept. It controls future new tabs, not destruction of
  old history; existing tmux restore remains explicit even with switch off.
  Plain SSH and current Mosh are not cross-process recoverable.
- Rename via tab long press/context menu + history overflow; title same field,
  1–64 visible characters, trim, reject controls/newlines. Duplicate names valid.
  Do not rename tmux identity or restart processes. Ordinary/Mosh live titles
  can be renamed, but do not become persistent recoverable history.
- Close tmux tab detaches, never kills remote processes. Keep final-tab closing
  policy unchanged. Network rebind preserves terminal model/scroll; lost plain
  process must be reported, never pretend cached output is a restored shell.
- History only stores metadata/default ID locally, not output/input/credentials;
  excluded from portable configuration export. Legacy app-owned sessions in
  `tmux -L valhalla` can be explicitly restored; no user-default socket scanning.
- Every async result checks target/generation; dispose old transports safely.
  Explicit keyboard button, Gboard modifiers, safe paste/copy and scroll anchors
  must not regress. Closing drawers/dialogs must not reopen IME.

## Phase C: NAS experience (AgY after phase A/B)

Whitelist: `lib/features/nas/**`, minimal NAS-related Shell placement if needed,
required `lib/l10n/*.arb`. Reuse providers, adapters, queue, download and cache
contracts; do not import SSH/network/storage into widgets. Report missing core
contracts rather than invent placeholders. Existing Inter/system fonts, Mono
metadata, user accent, light/dark/AMOLED surfaces and current tokens remain.

- Mobile one compact source/search/more row and Home/Photos/Videos/Music/Library
  navigation. Desktop narrow local category rail, responsive content. Global
  app title/navigation/mini-player remain in Shell, no duplicate bottom bar.
- Home actual continue watching/listening and recent media shelves; never show
  unplayed items as continue. Management buttons move into Library/more.
- Photos date-grouped square gallery, default4, selectable3/4/5 columns (narrow
  accessibility fallback), folder filter, sort, multiselect/favorite/download.
  Folder albums use real representative image(s)/counts, not fake smart albums.
  Date remains file modified/media-server date, not EXIF. Preserve 600-item
  bounded window and item+pixel anchor on layout/density/source/return changes.
- Viewer: zoom/swipe/slideshow/favorite/info/download/external/cast existing
  actions, state retained on return; no new unbounded original image loading.
- Videos real 16:9 mobile two-column grid and compact list toggle; title,
  available duration/progress only. Card plays, explicit info opens bounded
  detail sheet/desktop panel. Existing tracks/speed/quality/continue/external.
- Music songs compact rows, album cover grids, artist grouping, group details
  and existing play-all/add-to-queue behavior. Real covers or honest placeholder.
  Audio player cover-centered controls with queue and global mini-player;
  retain background controls. No fabricated lyrics/equalizer/sleep timer.
- Library groups folders/favorites/playlists/downloads and management links
  (sources, scan, cache/open behavior, diagnostics, deployment). Typed favorites;
  playlist create/rename/reorder/delete confirmation, explain references only.
- Folder media browsing remains read-only, reused browsing controls, not file
  CRUD; preserve filters/sort/search scope and reset child-directory search.
- Downloads tasks/available offline, progress/pause/resume/retry/open/delete
  local-copy confirmation. Cache purge never deletes offline downloads.
- Sources five existing protocols, separate server/source identity, bounded
  shared picker; scan include/exclude, real phases/counts, cancel keeps oldindex.
- Deployment Docker -> App Center Jellyfin; native existing Debian/Ubuntu/APT/
  systemd/amd64-arm64 constraints, preview/feedback and addsource after success.
  No auto firewall exposure. Diagnostics sanitized copy; existing DLNA only.
- Preserve paginated 200-item lists and photo bounds, per-source/category state,
  no fullscreen loader replacing cached content during reconnect. Lazy thumbnail
  cancellation and 150–250ms subtle transitions respecting reduced animation.
- No new backend, new dependencies, full library shuffle promise, EXIF/face/geo,
  movie scraping, cross-source aggregation or automatic photo backups.

## Verification / release gates

Follow-up authorization: after MiMo and Big Pickle returned rate limits, Cat Jam
Free began test authoring. User then explicitly answered “本轮你来” to allow root
to complete tests/format/generation/analyze this round. Root stops its two
OpenCode jobs and preserves their test edits before taking over. UI remains AgY;
no build/install/push/publication authority was added.

Root now owns new/updated tests and all running/format/generation/analyze.
Do not assert completion because an agent was invoked. Record actual commands,
exit status, pass counts, log paths and remaining runtime/device gaps here.

- Files/store: 320/360/390/430dp regular2col, largefont1col, RTL/dark/light;
  icon/title horizontal geometry and actual reduced card bounds; full minutes
  painted, not merely Text widget present; no badges/longtitle/status variants;
  shared picker filtering/directory-only, hidden/symlink/multiselect/actions.
  Deep-scroll view switching preserves visible item after new stride.
- Terminal: fresh after closed middle tab, fresh after cold start no default,
  valid/missing/offline default, concurrent opens, current target switch races,
  rename/save/reload, exact tmux targeting/legacy names/plain/Mosh limitations,
  provider-read no start, last tab policy, reconnect no silent recreate, cleanup.
  Existing toolbar, Gboard preedit/modifier, IME intent, paste/scroll regressions.
- NAS: all category layouts and bounded anchor/density, return/lifecycle/source
  preservation, play/continue/queue, downloads/offline/cache, deployment routes;
  test real capability boundaries, no fake data. Real servers/devices unverified
  unless a later separately authorized isolated target is actually exercised.

## Historical progress and regression evidence

- Baseline clean before edits; AgY model catalogue confirms required model.
- Core terminal create/restore/rebind63/63 pass; latest history/provider29/29
  pass, including queued default expiration, false/throw storage rollback,
  target/transport races and portable configuration exclusion.
- Terminal integrated UI57/57 pass; inputs/IME/copy/scroll77/77; Docker/login/
  quick-command callers56/56. See `2026-10-14-terminal-recheck.md`. These batches
  are not a claim of live SSH or device validation.
- Later boundary tests expanded history UI to14:12 pass,2 reproduce dialog
  save completing during dismiss animation and popping its underlying page.
  AgY subsequently added current-route guards for both rename/default; the
  latest stable six-file terminal cohort passes56/56, including history14/14.
  Main-shell five tests subsequently pass, giving61/61 distinct terminal UI
  checks. See the recheck document, the stable-six log and
  `/tmp/valhalla-20261014-main-shell-final.log`.
- Compact files/store/pickers147/147 pass in
  `/tmp/valhalla-20261014-compact-verified.log`. All date glyph-bound tests pass
  with production fonts, including list/grid320dp at1/1.3/2x. Preview tests now
  use gallery; compact grid explicitly asserts zero preview fetches. RTL host
  tears down previous Navigator so tests exercise the actual RTL surface.
- Phase A/B analyzer zero issues (`/tmp/valhalla-20261014-analyze-ab-final.log`).
  Earlier review documents preserve failed evidence; those issues were repaired
  by AgY, not by weakening production acceptance.
- NAS queue23/23 (8new), service21/21, existing UI/core baseline168 pass. Two
  newly added home tests reproduce unplayed-video false continue (expected red
  until Phase C).100k index page p95=2.90ms in local test, not remote latency.
- Phase C NAS redraw is in progress; root owns tests after user's explicit
  one-round authorization. No published/installed change yet.
- Work paused when the shared disk reached zero available bytes. The user
  expanded it; read-only `df -h` now reports131GB available. No cache, build,
  credential or backup was deleted. Existing changes were retained, and the
  original AgY conversation was resumed with the same model/high setting.
  Fresh analysis still reports incomplete Phase C syntax/wiring, so earlier
  Phase A/B zero-issue analysis is not a claim about the current whole tree.
- NAS first complete view/navigation run:56 pass/30 fail, mostly shared layout
  roots. Photo unbounded flex, scaled card/menu geometry and source UI/query
  synchronization are being repaired by AgY. The reviewer has since added the
 27th acceptance case and updated mobile-entry fixtures without relaxing tests.
- Mini-player adaptive height now passes all6 thumbnail/cover/lifecycle checks,
  including320dp/2x/RTL and real production fonts. Evidence:
  `/tmp/valhalla-20261014-player-cover-after-fix.log`.
- Fresh combined non-UI regression:191/191 pass across11 files (terminal
  history/planner/tmux/rebind/Mosh/storage, NAS playback/library/organization/
  source connection and localization parity). Log:
  `/tmp/valhalla-20261014-core-final-regressions.log`.100k local index p95=1.94ms,
 200items/page, about21.7MB RSS delta; no remote-performance claim.
- NAS view/navigation subsequently passes87/87, including all27 new acceptance
  cases; photo-only9/9. Full repository snapshot then passes3419 with29 external
  environment checks skipped, exit0, in196s. Explicitly unset live/VM opt-in
  variables for the run; no production hosts or ADB used. Log:
  `/tmp/valhalla-20261014-full-suite.log`.
- The final contract audit added an88th NAS UI regression AFTER that full run.
  It proves photo-album page2 survives drill-in/return, but folder scope leaks
  and album scroll resets700->0; scope breadcrumbs also overflow52px. Thus
  the green snapshot is not final acceptance of the newly checked behavior.
  Same AgY conversation is repairing this bounded gap; see the NAS review and
  `/tmp/valhalla-nas-baseline-efH5zC/photo-folder-return.log`.
- The focused AgY repair now passes both root and `/archive` album-return
  cases: original folder scope, page 2 and visible-album position are retained;
  the breadcrumb overflow is gone. Whole-project analysis remains clean in
  `/tmp/valhalla-20261014-analyze-photo-return.log`. These checks precede the
  final full-suite rerun, not an installed-app claim.
- A final typed-favorites check found filtering applied only to the loaded
  page. Repair is confined to the existing provider filter API and favorites
  chips, so favorite kinds use indexed/server pagination instead of hiding
  nonmatching rows locally. The core test uses a real SQLite index with more
  than 200 favorites; the UI regression proves a later-page image becomes visible
  after a type query. Both are now green, together with the root/parent return
  and gated same-ID source replacement cases, in the final gates above.
