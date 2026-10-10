# v1.0.3 Refresh — GitHub Release Verification

- Date: 2026-10-10
- Scope: bounded read-only release verification (no builds, no tests run, no downloads, no git writes, no credential output)
- Local artifact dir: `/tmp/opencode/valhalla-v103-refresh-release-9UjF5U`
- Method: Node stdlib (crypto/fs/path) + `gh api` GET only; 6 API calls, each wrapped in `timeout 30`
- Checker: `verify.cjs` (34 assertions)

## Result

**PASS — checker exit 0.**

## Assertions satisfied

### Release identity

| Check | Value |
|---|---|
| Release id | `408606647` — matches |
| Tag | `v1.0.3` — matches |
| draft | `false` — matches |
| prerelease | `false` — matches |
| latest | id `408606647`, tag `v1.0.3` — same id — matches |

### Assets vs local (exact set)

- Remote assets: **15**, all names unique. Local files: **15**. No remote-only, no local-only.
- All 15 assets `state=uploaded`.
- All 15 sizes equal local byte counts.
- All 15 digests non-null — no downloads performed; every digest (`sha256:…` → hex) recomputed locally and equal.

### Sidecars and SHA256SUMS vs 7 primaries

7 primaries: arm64-v8a apk, armeabi-v7a apk, x86_64 apk, signed aab, linux x64 tar.gz, android BUILD-INFO, linux BUILD-INFO.

- `SHA256SUMS.txt`: exactly 7 entries, covering exactly those 7 primaries; all listed digests equal locally computed SHA256.
- Each `<primary>.sha256` sidecar: 7 present, all parse to the primary's own name and match the locally computed digest.
- Full remote set = 7 primaries + 7 sidecars + `SHA256SUMS.txt` = 15.

### Tag chain and commit pins

- `git/ref/tags/v1.0.3` → object type `tag`, sha `eb6c1507aa9d4bdca65f092b4b09a76ea71032b9` (new annotated object, `eb6c150` prefix) — matches.
- Annotated tag object `eb6c150…` → `tag: v1.0.3`, peels to commit `a885e97b89840d7126f83756730ca412021f6b84` — matches expected build commit.
- `git/ref/heads/main` → commit `a885e97b89840d7126f83756730ca412021f6b84` — currently the same source commit (a later docs-only commit may follow; not observed).

### Release body

- Contains source commit `a885e97b89840d7126f83756730ca412021f6b84` (under 验证与构建来源).
- Contains fixes: 本次修复 fix list (SSH 终端清屏, 输入法, Docker 列表解析, Android 自适应图标), plus the 本版同时包含 feature rollup line and Docker 解析错误 wording.

### Actions

- `actions/runs?head_sha=a885e97b…&per_page=10` → `total_count: 0`, `workflow_runs: []` — matches.

## API calls used (6 of 7 max)

1. `GET repos/NornsInteractive/valhalla/releases/408606647`
2. `GET repos/NornsInteractive/valhalla/releases/latest`
3. `GET repos/NornsInteractive/valhalla/git/ref/tags/v1.0.3`
4. `GET repos/NornsInteractive/valhalla/git/tags/eb6c1507aa9d4bdca65f092b4b09a76ea71032b9`
5. `GET repos/NornsInteractive/valhalla/git/ref/heads/main`
6. `GET repos/NornsInteractive/valhalla/actions/runs?head_sha=a885e97b…&per_page=10`

Note: `gh api` in this environment has no `--timeout` flag; timeouts were applied with the `timeout 30` wrapper instead. No call timed out.

## Mismatches

None.
