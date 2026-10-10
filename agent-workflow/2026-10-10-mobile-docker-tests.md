# Mobile Docker regression tests — 2026-10-10

Scope: Docker regression tests only, in three files:
`test/infrastructure/docker_cli_service_test.dart`,
`test/features/docker_project_lifecycle_test.dart`,
`test/features/docker_view_test.dart`. **No production file was edited.** No build,
no ADB/live-server command, no container lifecycle operation, no terminal task
cancellation, no dependency change. UI / keyboard / terminal / icon / breadcrumb
tests belong to the other verifier and were not touched. No full suite yet
(UI tests are still being edited elsewhere).

Models: main and small both `opencode/step-5-preview-free`
(cost `{"input":0,"output":0,"cache_read":0}` per the local catalog
`/home/dev/.cache/opencode/models.json`) — confirmed free; no global tool config
changed.

## Commands and exact exits

| Command | Exit |
|---------|------|
| `flutter test test/infrastructure/docker_cli_service_test.dart test/features/docker_project_lifecycle_test.dart test/features/docker_view_test.dart --reporter expanded` | `0` — `00:04 +48: All tests passed!` |
| `flutter analyze test/infrastructure/docker_cli_service_test.dart test/features/docker_project_lifecycle_test.dart test/features/docker_view_test.dart` | `0` — `No issues found!` |
| `dart format test/features/docker_view_test.dart test/features/docker_project_lifecycle_test.dart test/infrastructure/docker_cli_service_test.dart` | `0` — 3 files formatted |

Transcripts: `/tmp/opencode/mobile-docker-tests.log`,
`/tmp/opencode/docker-analyze.log`.

Intermediate exits (kept for the record):
- `flutter test test/infrastructure/docker_cli_service_test.dart` → first run `1`
  (my `createdAt isNotNull` assertion; created-at parsing is out of scope, so that
  single assertion was removed and nothing else changed), then `0`.
- `flutter test test/features/docker_view_test.dart` → `1` while the production
  selector was still overflowing off-screen (see below); after AgY's fix + my test
  fixes → `0`.

## Service + provider tests (Docker container listing)

`test/infrastructure/docker_cli_service_test.dart` (+13):

- `docker ps template round trip`
  - `the sent template renders one closed JSON object per container` — captures the
    executor command, asserts it starts with `docker ps -a --no-trunc --format `,
    extracts the Go template, asserts it **ends with `}}}`** (v1.0.3 ended with
    `)"}}`), expands `{{json .Field}}` / `{{json (.Label "k")}}` with `jsonEncode`
    fixtures, `jsonDecode`s the resulting line and feeds the same line to
    `DockerContainer.parseLines`.
  - `containers without compose labels render empty label fields` —
    `{{json (.Label ...)}}` yields `""` and the container ends up with
    `composeProject`/`composeService` null.
  - `a login-shell banner in front of the records is tolerated` — `bash -l -c` MOTD
    lines must not hide real containers.
  - `a template that forgets the closing brace is rejected` — takes the real
    template, drops the final `}` (the v1.0.3 shape) and requires `parseLines` to
    throw. Direct guard against re-introducing the bug.
- `docker ps response validation`
  - `an unparsable record rejects the listing instead of empty success` — a
    truncated record (exactly what v1.0.3 emitted) must surface
    `Invalid Docker container record at line 1`, not an empty success.
  - `all-garbage output is reported as a failure`.
  - `a partially invalid listing rejects instead of returning a subset`.
  - `records missing an id or with wrong field types reject` — missing id, empty id,
    numeric id, object `names`, JSON array row.
  - `an empty remote listing still succeeds` — `''`, `'\n'`, `'\n\n  \n'`.
  - `a non-zero docker exit keeps the daemon message and exit code`.
- `_Executor` gained `psOutput` / `psExitCode` / `psStderr` replay knobs; the
  existing `ignores malformed docker lines when parsing streams` (non-`{` banner
  rows) is unchanged.

`test/features/docker_project_lifecycle_test.dart` (+3, group `刷新失败与加载状态`):

- `刷新失败保留缓存容器，错误不会被搜索或过滤清掉` — after a failed refresh the
  cached containers survive, `errorMessage`/`exitCode` are retained, and
  `setFilterState` / `setSearchQuery` must not clear them.
- `刷新成功后错误被清除`.
- `quiet 刷新有缓存时不显示加载，无缓存时仍显示加载` — gated executor to observe
  the in-flight window.
- `_FakeDockerExecutor` gained `psExitCode` / `psStderr` / `psGate` only.

## UI tests (`test/features/docker_view_test.dart`, +5)

Group `DockerView filter row, cached error and empty states`, mobile viewport
390×844, using the file's existing `_FakeDockerNotifier` / `_buildTestApp` /
`_container1` / `_container2` fixtures:

- `mobile puts the status filter row below the Container/Compose selector` —
  both selector segments (`Containers`, `Compose Projects`) are found **inside the
  selector**, asserted fully inside the 390px viewport (`getRect` left/right/top/
  bottom), tappable (tap switches `selected` and back), all four filter chips
  including the retained `Paused` filter are present, and the filter chip row's top
  is strictly below the selector's bottom.
- `a failed refresh keeps the cached list and shows the retry error` — cached cards
  stay visible, the daemon error text is shown, the `Retry` button is found, enabled
  and triggers `refresh()`.
- `the error stays visible when a filter narrows the cache to empty` — a paused
  filter with no paused containers yields `No items found` while the retry error
  stays on screen (filtered-empty ≠ error-free empty).
- `a connected host with no containers is distinct from a disconnected one` —
  `No containers found on server` in Containers mode vs
  `No Docker Compose projects found` in Compose mode, and never `Disconnected`.
- `disconnected is reported in both modes instead of a true empty` — `Disconnected`
  + offline description in **both** modes, and never the true-empty messages.

Two problems were found while writing these; both are recorded honestly:

1. **Test bug (mine):** the `Retry` assertion used
   `find.widgetWithText(TextButton, 'Retry')` / `find.byType(TextButton)`.
   `TextButton.icon` instantiates a *private subclass* of `TextButton`, and Flutter
   finders match the exact runtime type, so nothing was found. Fixed with
   `find.byWidgetPredicate((widget) => widget is TextButton)`; visibility and
   enabled assertions were kept (enabled + actually calls `refresh()`).
2. **Real UI bug (production, fixed by AgY, not by me):** the Container/Compose
   `SegmentedButton` was wider than a 390px phone and its second segment sat at
   x≈442, outside the viewport — untappable, and my earlier mode-switch assertions
   failed for that reason. AgY bounded it to full width
   (`lib/features/docker/docker_view.dart`). Per instruction I added **no** scroll
   workaround and no `warnIfMissed: false`; the tests now assert both segments are
   inside 390px and hit-testable, which is exactly the regression guard for it.
   Note the finder had to stay scoped to the selector
   (`find.descendant(of: find.byType(SegmentedButton<bool>), ...)`) because the
   Compose mode standalone-group header reuses the same `dockerViewGroupContainers`
   label.

## Status of the five regressions

Only item 4 (Docker) is covered by this report. Items 1 (breadcrumbs), 2 (SSH
toolbar), 3 (icon) and 5 (drawer/keyboard) are owned by the other verifier and
have **no** tests from me; nothing here claims they pass. Live-daemon behaviour
remains **unverified** — no ADB or server command was run in this task, so this is
recorded as unverified rather than successful.
