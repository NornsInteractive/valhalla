# Mobile Device Smoke - 2026-10-10

Device: `127.0.0.1:14251` (sdk_gphone64_x86_64) | App: com.antigravity.valhalla.valhalla v1.0.3 (versionCode 4004, TEST-debug-signed, data preserved from prior install)

## Observed

- Launcher: app icon found in app drawer (content-desc "valhalla", bounds [334,2268][592,2740]); tapped to launch (`01_home_launcher.png`, `02_app_drawer.png`, `06_app_relaunch.png`).
- Dashboard: hamburger (更多功能, [0,96][224,320]); racknerd shown **connected** (已连接, green); live metrics: uptime 14d 2h, CPU 3.2%, RAM ~73%, disk 84.0%, network sampling. No reboot/shutdown/disconnect tapped. (`03_app_main.png`)
- Nav drawer XML-verified entries: 远程文件 [48,1028][1168,1252], 容器管理 [48,1252][1168,1476] (`smoke_navdrawer*.xml`).
- Files (远程文件): root `/` directory listed live (bin, boot, dev, etc, home, lib …) with sizes/permissions/dates — read-only list verified. (`07_files.png`, `smoke_files.xml`)
- Files search field: bounds [48,572][1392,716], placeholder "搜索文件或目录名...". IME sequence (dumpsys input_method):
  - tap search → `mInputShown=true` (focus stays app, PID 29875)
  - open drawer via menu → `mInputShown=false` (keyboard dismissed, **no IME rebound**)
  - tap backdrop (1350,1200) → `mInputShown=false`, focus returned to app window
  - tap search again → `mInputShown=true`
  - Back key → `mInputShown=false`
  - after reopen, search EditText text empty — **no persistent query text** (`smoke_files_after.xml`, `08_search_focused.png`)
- Docker (容器管理): container list selector active; the visible viewport shows three RUNNING cards — dev-coturn (coturn), xianyu-assistant (12400/tcp), open-webui. This is not a count of all server containers. (`09_docker.png`, `smoke_docker.xml`)
- Docker Compose selector (容器列表 / Compose 项目): tapped Compose 项目 (bounds [720,580][1376,708]) → selector switched; Compose projects shown: coturn (1/1 运行中), opencode2api (1/1 运行中). No lifecycle icons (start/stop/restart/delete) tapped. (`10_docker_compose.png`, `smoke_docker_compose.xml`)

## Not exercised (deliberately out of scope)

- Terminal, agent chat, system ops, add server, system settings, any server edit/login/password interaction, remote file modifications, container lifecycle actions.
- Compose project detail navigation, sub-directory navigation in Files, breadcrumb beyond Files root "/" selector.
- Early mis-tap (600,905) briefly opened Terminal screen (`05_files_screen.png`); no terminal typing/clearing/interaction occurred, exited via system Back.

## Integrity notes

- No credentials exposed in captured dumps/logs; only on-screen rendered server label/hostname visible in screenshots as the app displays them.
- No builds, code edits, or full test runs in this smoke session (owner-reported: full suite 2195 passed, analyze 0).
- Artifacts: screenshots + uiautomator dumps under `/tmp/opencode/mobile-device-smoke/`.
