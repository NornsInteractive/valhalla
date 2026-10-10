# Mobile baseline — Docker root cause evidence (2026-10-10)

Owner: OpenCode (tests/checks only). Base: clean `main` after v1.0.3 plus the
in-progress production fixes present in the working tree. No production file was
edited by this task; no device, server, container or terminal operation was
performed.

## Preflight

- Model catalog (local): `/home/dev/.cache/opencode/models.json`
  - main model = `opencode/step-5-preview-free` → cost `{"input":0,"output":0,"cache_read":0}`
  - small model = `opencode/step-5-preview-free` (same entry, `/tmp/valhalla-completion-opencode.json` sets both `model` and `small_model`)
  - Both confirmed **free** (zero cost per token), confirmed from the local catalog only. No global tool config changed.
- Disk (`df -h / /workspace`):

  ```
  文件系统        大小  已用  可用 已用% 挂载点
  overlay         458G  383G   52G  89% /
  /dev/nvme0n1p8  458G  383G   52G  89% /workspace
  ```
- ADB devices: `adb devices -l` was **empty** for the whole investigation window.
  Later, near the end, an emulator appeared:
  `127.0.0.1:14251  device  product:sdk_gphone64_x86_64  model:sdk_gphone64_x86_64  device:emu64xa  transport_id:1`.
  **No ADB command, install, screenshot or app run was executed** for this
  baseline; the device is reported as available-only and unverified.
- No cleanup was performed (temp harness kept under `/tmp/opencode/docker-tpl`).

## Root cause: `docker ps --format` never closes the JSON object

The shipped template (git `HEAD`, released in v1.0.3) is 298 bytes and ends with
`...)"}}`, i.e. the Go action `{{json (.Label "...")}}` closes but the outer
`{` of the record is never closed. The working tree adds exactly that one byte.

Byte-level comparison (template extracted from source, no execution):

```
$ git show HEAD:lib/infrastructure/docker/docker_cli_service.dart > /tmp/opencode/head_docker.dart
$ python3 - <<'EOF'   # prints tail + length of both --format strings
HEAD fmt: 'abel "com.docker.compose.service")}}'   298
WORK fmt: 'bel "com.docker.compose.service")}}}'  299
EOF
```

What the daemon therefore emits, rendered with the same substitution rules the
Docker CLI applies (`/tmp/opencode/docker-tpl/dartcheck`, standalone Dart string
demo — no production code involved):

```
--- head (298 byte template) ---
rendered: {"id":"c9f8...","names":"app-web",...,"composeProject":"shop","composeService":"web"
ends with "}"? false
jsonDecode: FormatException: Unexpected end of input
--- work (299 byte template) ---
rendered: {"id":"c9f8...","names":"app-web",...,"composeProject":"shop","composeService":"web"}
ends with "}"? true
jsonDecode: OK
```

Combined with `DockerContainer.parseLines` at `HEAD`
(docker_cli_service.dart:75 — `on FormatException { continue; }` on every row),
every record line was a nonempty but unparsable line, so every row was dropped
and `listContainers` returned an **empty list reported as success**. That is the
"malformed nonempty parsing must error, not empty success" bug.

Secondary factor: the same parser had no `startsWith('{')` guard, so login-shell
banner text mixed into stdout was silently dropped too. Current production keeps
banner tolerance (`not-json` lines are skipped) but rejects any line that *does*
start with `{` and fails, and rejects output that produced no valid records.

## Official Docker formatter source used

Downloaded to the local module cache for reading only
(`GOSUMDB=off go mod download github.com/docker/cli` with
`require github.com/docker/cli v28.0.1+incompatible`; no dependency of this
project changed, temp module lives in `/tmp/opencode/docker-tpl`):

- `templates/templates.go:15-27` — `basicFunctions["json"]` is `json.NewEncoder`
  with `SetEscapeHTML(false)` and `strings.TrimSpace`, so `{{json .ID}}` emits a
  **quoted** string and `{{json (.Label "k")}}` emits `""` when the label is absent.
- `cli/command/formatter/container.go:263` — `func (c *ContainerContext) Label(name string) string`
  returns `c.c.Labels[name]` (empty string when nil/absent). `.Label` is a valid
  template field, so the label actions themselves are not the failure.
- `cli/command/formatter/formatter.go:100-112` — `contextFormat` appends `"\n"`
  per record, and `Write` buffers: a template parse/execute error yields no
  stdout at all plus a `template parsing error: ...` message and a non-zero exit.

## Honest note about the temporary Go harness

Per instruction the harness was not debugged further. What actually happened:

1. First successful `go run .` — **did not demonstrate the bug**: both the
   "HEAD" and "working tree" template were hardcoded as identical constants in
   `main.go`, so both rendered and parsed as valid JSON. That run is not evidence.
2. Second run, after loading the real extracted templates — **panicked**:
   `panic: runtime error: slice bounds out of range [-6:]` at
   `main.render` `/tmp/opencode/docker-tpl/main.go:68` (a `format[len(format)-6:]`
   print on a shorter string). Not fixed, per instruction.
3. The standing evidence is therefore the byte-level source comparison above plus
   the standalone Dart render, and the in-repo regression tests
   (`test/infrastructure/docker_cli_service_test.dart`) that now pin the
   template's closing brace and reject the v1.0.3-shaped record.

## Not verified (no claim of success)

- No device/server smoke test, no real `docker ps` capture from the configured
  target: the app-side evidence above is from source, templates and the official
  formatter source, not from a live daemon. Recorded as unverified, not successful.
