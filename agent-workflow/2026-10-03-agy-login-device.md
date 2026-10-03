# AgY login — initial READ-ONLY device evidence (2026-10-03)

Task: `agent-workflow/2026-10-03-agy-login-flow.md` → "Initial device evidence task (read-only)".
Operator: OpenCode main + small, model `opencode/mimo-v2.6-flash-free` for both.

## 0. Scope and compliance

| Constraint | Status |
|---|---|
| Read-only inspection of existing ADB device | **done** |
| No product / test / doc edits (other than this report) | **honoured** — no `lib/`, `test/`, ARB or config file touched |
| No builds / APK / install | **honoured** |
| No install, sign-in, sign-out, logout | **honoured** — `立即登录`, `去登录`, `保存并检测`, `删除` never tapped |
| No inference / message send | **honoured** — send button never tapped |
| No existing-session deletion or modification | **honoured** — session `回复我ok` / `Antigravity AGY` untouched |
| No credential / token / raw DB / shell-env exposure | **honoured** — nothing read from storage or env; report redacted |
| Do not touch running Codex conversations | **honoured** — only the AgY chat was viewed; no CLI/Codex session opened |
| Default agent/server not changed persistently | **honoured** — stayed on `racknerd` + `Antigravity AGY`; server sheet opened read-only and closed without selecting anything else |
| Safe refresh agent check | **performed once** (explicitly allowed) |
| Model | `opencode/mimo-v2.6-flash-free` only |

**Redaction policy applied in this file:** server host and SSH port are replaced with
`<redacted-host>` / `<redacted-port>`. No account identifier, token, API key, password
or environment variable appears anywhere below. Public installer URLs and command
strings are reproduced verbatim because they are not secrets.

> **Warning for anyone handling the raw evidence files:** the screenshots and
> `uiautomator` XML dumps are *unredacted* (the server row renders as
> `root@<host>:<port>`). Keep `agent-workflow/evidence/2026-10-03-agy-login/` internal.

## 1. Device and session context

| Item | Value |
|---|---|
| adb serial | `127.0.0.1:14251` |
| `adb devices -l` | `device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:1` |
| Created by this run? | **No** — pre-existing; `adb connect` reported `already connected to 127.0.0.1:14251` (attempt count: 1) |
| Package | `com.antigravity.valhalla.valhalla` |
| Activity | `com.antigravity.valhalla.valhalla/.MainActivity` (topResumed throughout) |
| PID | `5960` (unchanged from before the task) |
| Physical size | `1440x3040` |
| Observation window | 2026-10-03 **12:05 → 12:14** local |
| Crash/ANR during run | `logcat -b crash` = 0 lines; `am_crash`/`am_anr` = 0 |
| App data / sessions mutated | none observed |

## 2. Evidence index

Base: `agent-workflow/evidence/2026-10-03-agy-login/`

| File | Captured at | What it shows |
|---|---|---|
| `01-current.png` / `01-current.xml` | 12:05 | Initial chat state: `racknerd`, `Antigravity AGY`, full ACP auth-challenge card with 3 methods |
| `02-drawer.png` / `.xml` | 12:06 | Navigation drawer ("更多功能") entries |
| `03-settings.png` / `.xml` | 12:06 | System settings incl. `Agent 管理` entry, default engine |
| `04-agentmgmt.png` / `.xml` | 12:07 | Agent card: CLI/ACP/Auth chips, probe path, "no login-check command" |
| `05-detectlog.png` / `.xml` | 12:07 | Detection log (before re-check) |
| `06-after-close.xml` | 12:08 | Log closed, back on agent list |
| `07-edit.png` / `.xml` | 12:08 | Edit Agent form, top (name, execution location, CLI/ACP commands) |
| `08-edit-scroll.png` / `.xml` | 12:09 | Edit form, middle (install commands) |
| `09-edit-scroll2.png` / `.xml` | 12:09 | Edit form, bottom (**登录检查命令 empty**, 登录命令 `agy`) |
| `10-after-cancel.xml` | 12:09 | Form cancelled — no save |
| `11-recheck.png` / `.xml` | 12:09 | After the one allowed refresh agent check |
| `12-detectlog-after.png` / `.xml` | 12:10 | Detection log (after re-check) |
| `13-back.xml` | 12:10 | Returned to System settings |
| `14-server-switch.png` / `.xml` | 12:10 | Server switcher: `racknerd` row **selected**, unredacted SSH target |
| `15-chat-after.png` / `.xml` | 12:11–12:12 | Chat after navigation: banner + `回复我ok` + `等待 ACP 认证` chip, **method card absent** |
| `16-chat-settled.png` / `.xml` | 12:12 | Same state, stable after 6 s wait |
| `17-account.png` / `.xml` | 12:13 | 账号与额度 dialog: no account details, no status query |
| `18-diaglog.png` / `.xml` | 12:13 | 诊断脱敏日志 → `暂无诊断日志` |
| `19-closing.xml` | 12:14 | Dialogs closed, original chat restored |
| `20-final-chat.png` | 12:14 | Closing screenshot, app healthy |

All captures produced with exit code 0 (`screencap`, `uiautomator dump`, `pull`).

## 3. Server identity

| Field | Value |
|---|---|
| Server name (selected) | `racknerd` — green/connected indicator in the app bar |
| SSH target | `root@<redacted-host>:<redacted-port>` |
| Appears in | app-bar switcher, `Agent 管理` subtitle (`racknerd (<redacted-host>:<redacted-port>)`), server switcher row |
| Selected state | server switcher shows a green check on `racknerd`; **no other server selected** |
| Other configured server | one additional entry exists (name redacted as irrelevant) — **untouched** |
| Working directory in chat | `/root` |

## 4. Agent management — AgY configuration

Path: 系统设置 → `Agent 管理`（"配置、检测与管理当前服务器的 ACP Agent 环境"）

### 4.1 Card (`04-agentmgmt`)

| Field | Value |
|---|---|
| Name | `Antigravity AGY` |
| Id | `builtin-agy` |
| Description | `Google Antigravity · Official ACP server & CLI` |
| Overall state | `已就绪` |
| CLI chip | `CLI: 已安装` |
| ACP chip | `ACP: 已就绪` |
| **Auth chip** | **`Auth: 未检测`** |
| CLI command | `agy` |
| ACP command | `agy_acp_server.par` |
| Probe path | `/root/.local/bin/agy` |
| Login-check hint | **`未配置登录检查命令`** |
| Last detection | `2026-10-03 12:02:21` → `2026-10-03 12:09:43` after the allowed re-check |
| Actions present | `查看检测日志`, `立即登录`, `编辑 Agent`, `检测状态`, `删除` |

### 4.2 Edit form (`07`–`09`) — read, then **cancelled without saving**

| Section / field | Value |
|---|---|
| Agent 名称 * | `Antigravity AGY` |
| 说明 | `Google Antigravity · Official ACP server & CLI` |
| **执行位置** | **`宿主机` selected** (green check); `Docker 容器` **not** selected |
| **执行用户** | `root` — derived from Probe `/root/.local/bin/agy`, chat cwd `/root`, and SSH target `root@…`. No separate per-agent user field exists in the form. |
| CLI 探测命令 * | `agy` |
| ACP 启动命令 | `agy_acp_server.par` (hint: `选填；留空表示仅使用 CLI`) |
| 安装命令 (选填) | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` |
| ACP 安装命令 (选填) | long pinned script — **verified still pinned to 1.2.1** (see 4.3) |
| **登录检查命令 (选填)** | **EMPTY** (placeholder only) |
| **登录命令 (选填)** | `agy` |
| Footer | `取消` / `保存并检测` — **`取消` tapped; `保存并检测` never tapped** |

### 4.3 Pinned ACP installer — 1.2.1 confirmed live on device

The `ACP 安装命令` field on-device contains exactly the pinned script:

- downloads `…/agy-extensions/releases/<os>/agy-acp-server-1.2.1-<target>-<arch>.zip`
- installs to `$HOME/.local/share/valhalla/antigravity-acp/1.2.1`
- writes launcher `$HOME/.local/bin/agy_acp_server.par`
- ends with `echo "Antigravity ACP 1.2.1 installed; authentication is separate from agy CLI."`

**No bump to registry 1.3.0 present. Pin held.**

## 5. Detection log (verbatim)

Identical before and after the allowed re-check (`05-detectlog.xml`, `12-detectlog-after.xml`):

```
cli availability: target remote host
cli availability: requested command: command -v agy
cli availability: transport command: command -v agy
cli availability: running
cli availability: exit 0 — /root/.local/bin/agy
acp availability: target remote host
acp availability: requested command: command -v agy_acp_server.par
acp availability: transport command: command -v agy_acp_server.par || { test -x "$HOME/.local/bin/agy_acp_server.par" && printf "%s\n" "$HOME/.local/bin/agy_acp_server.par"; }
acp availability: running
acp availability: exit 0 — /root/.local/bin/agy_acp_server.par
authentication: not configured
```

- `target remote host` — confirms host execution (matches 执行位置 = 宿主机).
- Both binary probes exit 0.
- **`authentication: not configured`** — the authentication probe was never run,
  because no login-check command is configured. This is the single line that explains
  `Auth: 未检测`.

## 6. Current ACP auth challenge

### 6.1 At 12:05 (initial capture, `01-current`)

- Banner: `需要登录认证，请先完成登录。`
- In-turn challenge card:
  - heading `等待 ACP 认证` / `需要登录认证`
  - agent `Antigravity AGY`
  - body `该 Agent 需要先完成认证才能处理你的请求。认证方式`
  - methods (radio list):
    1. `Log in with Gemini Enterprise` — `Log in with your Gemini Enterprise account`
    2. `Gemini API key` — `Use an API key with Gemini Developer API`
    3. `Gemini Enterprise Agent Platform` — `Use Gemini Enterprise Agent Platform (formerly Vertex AI) with Application Default Credentials or an API key`
  - buttons `取消` and `去登录`
- User turn present: `回复我ok`
- **None of `取消` / `去登录` / any method radio was tapped.**

### 6.2 At 12:11–12:14 (`15`, `16`, `20`) — after navigation + one re-check

| Element | State |
|---|---|
| Banner `需要登录认证，请先完成登录。` | **still present** |
| User turn `回复我ok` | present, unchanged |
| Assistant turn status chip `等待 ACP 认证` (lock icon) | **present** |
| Method-selection card (3 methods + `取消` / `去登录`) | **NO LONGER RENDERED** |
| Session / agent / server | unchanged |

Between the two captures a transient banner **`正在重连…（第 1 次）`** was observed
(12:10, immediately after closing the server switcher). The card disappearance is
reported as an observed fact; no auth, login, cancel or send action was performed by
this run to cause it.

## 7. Account / quota / diagnostics

From `账号与额度` (`17-account`, `18-diaglog`):

| Section | Value |
|---|---|
| 账号信息 | `未上报账号详情` |
| 额度与状态 | `当前 Agent 未提供状态查询` |
| 诊断脱敏日志 | opens → **`暂无诊断日志`** |

So the app currently reports **no** CLI/ACP account details, **no** status query, and
**no** captured diagnostics for this agent in this session.

## 8. Surrounding settings (context only)

| Setting | Value |
|---|---|
| 默认 AI 运维引擎 | `Claude CodeX (Anthropic ACP)` |
| ACP 协议管道标准 | `Agent Client Protocol v1.0 (stdio over SSH)` |
| 语言 | `简体中文 (Simplified Chinese)` |
| 主题 | `跟随系统`, accent `#10B981` |

## 9. Findings for root

1. **Auth status is structurally unreachable.** `登录检查命令` is empty → detection
   emits `authentication: not configured` → card shows `Auth: 未检测`. This exactly
   matches the reported symptom "Agent management has no login-check command".
2. **`登录命令` is populated (`agy`) but is only a launcher**, not a status probe —
   it cannot by itself produce an authentication state.
3. **ACP asks for auth while the CLI side reports nothing.** The challenge lists three
   Gemini methods, yet 账号与额度 says `未上报账号详情` and `当前 Agent 未提供状态查询`,
   so there is no independent signal to compare against `auth_required`.
4. **The challenge card vanished while the banner + `等待 ACP 认证` chip survived.**
   Whether this is a legitimate reconnect-driven reset or a state-consistency bug is
   worth a look before any fix lands.
5. **No diagnostics exist to inspect** (`暂无诊断日志`), so ACP stderr/diagnostics
   evidence will have to be re-captured during a live attempt — which this run
   deliberately did not perform.
6. **Environment is healthy for the next step:** CLI `/root/.local/bin/agy` and ACP
   `/root/.local/bin/agy_acp_server.par` both resolve (exit 0), installer pinned at
   1.2.1, host execution, no crash/ANR.

## 10. Exact non-secret commands used

```sh
adb devices -l
adb connect 127.0.0.1:14251                       # reported "already connected"
adb -s 127.0.0.1:14251 shell pidof com.antigravity.valhalla.valhalla
adb -s 127.0.0.1:14251 shell wm size
adb -s 127.0.0.1:14251 shell dumpsys activity activities | grep topResumedActivity
adb -s 127.0.0.1:14251 exec-out screencap -p > <evidence>.png
adb -s 127.0.0.1:14251 shell uiautomator dump /sdcard/ui.xml
adb -s 127.0.0.1:14251 pull /sdcard/ui.xml <evidence>.xml
adb -s 127.0.0.1:14251 shell input tap <x> <y>     # navigation only
adb -s 127.0.0.1:14251 shell input swipe 720 2400 720 900 400   # scroll the edit form
adb -s 127.0.0.1:14251 logcat -d -b crash | wc -l
adb -s 127.0.0.1:14251 logcat -d -b events | grep -c 'am_crash\|am_anr'
```

UI taps performed (all navigation/inspection): drawer (112,208) → 系统设置 (608,1992)
→ Agent 管理 (720,1968) → 查看检测日志 (372,1264) → 关闭 (1072,2604) → 编辑 Agent
(840,1508) → 取消 (776,2880) → **检测状态 (1032,1508) [the one allowed refresh]** →
查看检测日志 → 关闭 → 返回 (112,208) → server switcher (988,208) → 关闭 (720,2292) →
bottom nav 智能会话 (540,2898) → 账号与额度 (1280,416) → 诊断脱敏日志 (720,1782) → 关闭.
`立即登录`, `去登录`, `保存并检测`, `删除`, `发送` were **never** touched.

## 11. Not performed

Install · sign-in · sign-out · logout · session delete/edit · message send ·
inference · credential entry · default-agent or default-server change ·
`pm clear` · uninstall · new emulator · code/test/ARB edits · builds · git mutation.

## 12. Stop point

Read-only device evidence complete and saved. Returning to root for the exact
login/ACP target before any flow change, test, or build.

---

## 13. Final-gates round — replacement APK installed (contract item 5–6)

§11 above describes the read-only evidence phase. The final-gates contract explicitly
supersedes the earlier no-build instructions and **requires** a new release build and an
`install -r`; that authorized install is recorded here.

### 13.1 Certificate compare (before install)

| | sha256 / digest |
|---|---|
| Installed `base.apk` (pulled from device) | `3e748162ab1dc2a29649073d581d73b91d529f6e614251dc078bb64f304b424a` (= the 13:40 stage APK, **without** the dialog fix) |
| Installed signer SHA-256 | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` |
| New build signer SHA-256 | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` — **identical**, upgrade is signature-compatible |
| New build sha256 | `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e` (≠ stage) |

### 13.2 Install, start, finite observation

| Step | Command | Result | Exit |
|---|---|---|---:|
| install | `adb -s 127.0.0.1:14251 install -r …/app-release.apk` | `Performing Streamed Install` / `Success` | **0** |
| verify device now runs new build | re-pull `base.apk` → sha256 | `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e`, size 123736478; `lastUpdateTime=2026-10-03 14:45:52` | **0** |
| start | `adb … shell am start -n com.antigravity.valhalla.valhalla/.MainActivity` | `Starting: Intent { cmp=…/.MainActivity }` | **0** |
| finite log | `timeout 45 adb … logcat -v time` | 265 lines captured, then bounded cutoff (exit 124 = expected) | 124 (expected) |

### 13.3 Observation outcome

- `FATAL` / `AndroidRuntime` / `has died` / `Force finishing` / `ANR in` occurrences: **0**
- error-level lines: **3**, all benign (release build "Not starting debugger since process
  cannot load the jdwp agent", a compositor surface notice, a `TaskPersister` system notice)
- process `2276` alive after the 45 s window; `topResumedActivity=…/.MainActivity`
- **No OAuth or account action was performed**: no authorize page opened, no account added,
  no callback delivered, no `pm clear`, no uninstall, no `adb root`.
