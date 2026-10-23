# ACP Android 强制关闭与恢复验收 — 2026-10-23

## 最终结果

OpenCode 通过 `python3 tool/acp_device_validate.py` 执行真实 ADB 进程测试，exit 0。
机器回执 `build/acp-device-validation/device-result.json` 为 `passed=true`、`restored=true`、错误为空。

1. 正式签名验证包保留数据覆盖安装，版本 1.0.16 / code 4017。
2. 第一个 App 进程（PID 1416）收到并保存 5 条输出后强制关闭。
3. App 进程已消失，服务端仍继续执行，5 秒内事件从 5 增长为 10，状态仍为 running。
4. 新 App 进程（PID 1664）补传并接收实时输出，最终 30 条唯一且有序，状态 completed；服务端 prompt 计数为 1。
5. 已重新编译正常 `lib/main.dart` 入口、同签名安装并启动，无 FATAL EXCEPTION，设备未留在测试入口。
6. 仅清理 fixture 自有进程 268318、268317、256285，保留所有日志、数据库和截图；ADB reverse 已移除。

证据：`before-stop.logcat`、`after-restart.logcat`、`normal-app.logcat`、`normal-app.png`、
`device-result.json`、`cleanup.json` 均在忽略目录 `build/acp-device-validation/`。
测试采用隔离模拟 Agent，不代表真实账号、Docker Agent 或物理手机均已验收。

## 前期模拟服务准备（历史记录）

## Scope
Single device-setup step: fix + test `tool/acp_device_ssh_fixture.py` only.
No Dart build, no ADB, no production server/Agent, no UI/source edits.

## Fix applied (`tool/acp_device_ssh_fixture.py`)
In `process_factory`, after `await proc.wait()`:
- Cancel **only** the stdin pump task (client may keep stdin open).
- Await stdout/stderr pump drain (bounded 5s via `asyncio.wait`) **before**
  `process.exit(...)`. Previously all pump tasks were cancelled immediately,
  truncating the last small response (e.g. final bytes of a `cat` roundtrip).
- Close `process.stdin` after drain, then exit.

## Environment
- venv: `/tmp/valhalla-acp-device-venv` (asyncssh 2.24.1)
- isolated HOME: `/tmp/vacp-device`
- bind: `127.0.0.1:54323` (loopback only, fixture-only creds)
- fixture PID: **256285** (started, ready-file confirmed, TCP connect ok)
- encoding: `None` on server `create_server` and client
  `asyncssh.connect(..., encoding=None)` + `create_process(encoding=None)`.

## Commands
```
HOME=/tmp/vacp-device /tmp/valhalla-acp-device-venv/bin/python \
  tool/acp_device_ssh_fixture.py --bind 127.0.0.1 --port 54323 \
  --ready-file /tmp/vacp-device/ready

cd /tmp/vacp-device && /tmp/valhalla-acp-device-venv/bin/python test_client.py
```

## Results (bounded 10s per command)
| Test | Command | Result |
|------|---------|--------|
| echo small | `echo small` | **PASS** (`stdout=b'small\n'`, exit 0) |
| cat stdin roundtrip | `cat` (binary payload incl. `\x00\x01\xff`) | **PASS** (23 bytes exact roundtrip) |

**Overall: PASS**

## State artifacts
- `build/acp-device-validation/fixture-state.json`
- `build/acp-device-validation/fixture.pid` (256285)
- `build/acp-device-validation/test_client.py`
- `build/acp-device-validation/fixture.log`

## Notes
- Port 54323 was free at start; no arbitrary process kill.
- Fixture left running for reuse; stop only via recorded PID 256285 when done.
