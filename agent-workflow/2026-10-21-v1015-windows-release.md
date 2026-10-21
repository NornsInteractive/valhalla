# Valhalla 1.0.15 Windows x64 补充发布

v1.0.15 已于当日完成 Android 三架构与 Linux 发布。本轮按用户要求为既有
GitHub Release `v1.0.15` 补充 Windows x64 三件套，并在分发平台登记 Windows
ZIP 外链。应用版本保持 `1.0.15+16`，未改 pubspec、未移动标签、未新建版本，
未删除或覆盖任何原有附件与分发包。

## 来源与构建

打包工作区提交 `e6ff7e31ac849224a3cd92ab7bd5ea6fe6111e94`（构建前已同步 origin/main，
工作树干净），生产编译源码与标签 `v1.0.15` / `dcb0c3a9b1080035720955a57f4487a6b08e38a3`
逐字节一致：两提交间仅 `README.md`、4 份文档与 3 个 Windows 打包脚本
（`tool/windows_installer.iss`、`tool/package_windows_exe.ps1`、
`tool/package_windows_msix.ps1`）不同，`lib/`、`windows/`、`test/`、`pubspec.yaml` 零差异。

工具链：Flutter 3.38.1 / Dart 3.10.0、MSVC 19.44.35229、Windows SDK 10.0.26100.0、
CMake 3.31.8、Ninja 1.12.1、Rust 1.99.0；`flutter pub get --enforce-lockfile`、
`flutter analyze --no-pub: No issues found.`。

## 测试与验证

- 全量 `flutter test`：`+3913 ~59 -131`，日志 `build/windows-artifacts/flutter-test.log`。
  131 项失败全部落在 9 个依赖宿主 POSIX/Python/node 的测试文件，逐条错误均为缺失
  外部命令，不是产品断言失败：
  `application_cleanup_helper_test`（Python not found）、`application_worker_test`
  （`/bin/bash` 无法解析 Windows 临时路径，exit 127）、`application_worker_stream_test`
  （`id -u` 不存在）、`nas_native_install_service_test`（`/usr/bin/python3` 不存在）、
  `agent_execution_target_test`（真实隔离 shell）、`antigravity_acp_install_test`
  （`chmod` 不存在）、`antigravity_login_check_command_test`（`/bin/bash` 不存在）、
  `codex_agent_execution_test`（`/bin/sh -c "command -v node"`）、
  `codex_model_authorization_node_exec_test`（`/usr/bin/node` 不存在）。
  `ai_chat_provider`、`auto_connect_boot`、`background_recovery_chat_state` 三个文件
  的 `[E]` 行为并发交错输出，其内容均指向 `application_cleanup_helper_test 49:5 _runPy`，
  这三个文件自身用例通过。
- 确定性子集：剔除上述 9 个环境依赖文件后运行其余 301 个测试文件，分 4 批
  `+3875 ~59 -0`（1438/1121/1095/221 通过，`All tests passed!`，0 个 `[E]` 标记），
  证据 `build/windows-artifacts/v1015-subset/summary.txt` 与各批日志。
- 便携 ZIP：80 个条目、无重复、无绝对路径与路径穿越、12 项必需 DLL/data 全部在位，
  包内 `BUILD-INFO.txt` 为 `version: 1.0.15+16`、`source_commit: e6ff7e31...`。
- EXE 安装器：`/VERYSILENT` 安装到临时目录退出码 0，75 个安装文件与生产 bundle
  逐文件 SHA-256 比对 0 差异，包内 BUILD-INFO 版本正确，静默卸载退出码 0 且目录清除。
- MSIX：Identity `Norns.Valhalla-` / `CN=257586C2-E7B0-47F3-BAED-A744A66748A1` /
  `1.0.15.0`，PublisherDisplayName `Norns`，DisplayName `Valhalla-服务器运维管理工具`，
  含 AppxBlockMap.xml 与 17 种语言资源。
- 签名状态：EXE 与 MSIX 均为 `NotSigned`（MSIX 无 AppxSignature.p7x），仅供上传
  Partner Center；未运行 Windows App Certification Kit，商店认证由微软执行。
  证据：`build/windows-artifacts/v1015-payload.verification.json`、
  `v1015-msix-identity.verification.json`、`v1015-installer-test.log`。

## 发布产物

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `valhalla-v1.0.15-windows-x64.zip` | 41592742 | `46274b5a9679f1879d6bb91b5c2c5fed21e5b75f6dc032b3ff7d6d8970eb2aad` |
| `valhalla-1.0.15-windows-x64-setup.exe` | 31151057 | `d336fe46d0b842a0dec93ce77ca6917e66312f09ce8e29b13da7bc4642a4aeb2` |
| `valhalla-1.0.15.0-windows-x64-store.msix` | 42824032 | `3a7b6d0a970cf7e5876174e5497edf5dc888bf996469ea0f6e20c4e7e0da85cb` |
| `valhalla-v1.0.15-windows-BUILD-INFO.txt` | 1480 | `0795ba68fe0326d584899308915781ac7e8fdb1ee36931a6c16b5b76e868742f` |

四个文件各带 `.sha256` 边车。`update.json` 在原 4 条 Android/Linux 记录之上追加
Windows ZIP 记录（含 `sourceCommit`）并新增 `platformSourceCommits`，
`update.json.sha256` 与 `SHA256SUMS.txt` 同步重算。

## GitHub 发布回执

[GitHub v1.0.15](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.15)
保持公开、非预发布，标签仍指向 `dcb0c3a9b1080035720955a57f4487a6b08e38a3`。
附件由 17 个增至 25 个：本轮 11 个上传文件（3 个产物 + 4 个 BUILD-INFO/边车 +
3 个清单文件）服务端大小与 SHA-256 与本地逐一一致；14 个非本轮替换的原附件
ID、大小、digest 全部不变；3 个清单文件用 `--clobber` 替换，替换前副本保存在
`build/windows-artifacts/v1015-publish/previous-release/`。公开下载的
`update.json`、`update.json.sha256`、`SHA256SUMS.txt` 与本地逐字节一致。
证据：`v1015-publish/github-upload.verification.json`、`v1015-public-github.verification.json`。

## 分发平台登记与回读

[分发项目](https://ygg.norns.cc.cd/d/com.norns.valhalla)的
`ver_mvi2c5qiy1t2` / `1.0.15+16` / code 2016 / default / published 新增
`pkg_mvi9o4i7uay8` / windows / x86_64：`file_key` 为空，`use_proxy=1`
（沿用 1.0.8 起每包代理策略），外链为 GitHub Release ZIP 直链，
`file_size=41592742`、`file_sha256=46274b5a...`。回读字段逐项一致，
原 4 个 Android/Linux 包的全部字段（除 `download_count`）保持不变，本版本共 5 个目标。

公开 `latest` 按 `platform=windows&arch=x86_64` 正确选中该 ZIP；分发 API
`Range: bytes=0-1048575` 返回 206、`Content-Range` 与总长一致，整包 GET 返回 200、
41592742 字节、SHA-256 与本地一致，全程停留在 `ygg.norns.cc.cd`，没有 302 到 GitHub。
证据：`v1015-ygg-registration.verification.json`、`v1015-ygg-download.verification.json`、
`v1015-ygg-public-latest-windows.json`，完整下载副本在 `build/windows-artifacts/v1015-public-download/`。

## 未完成与边界

- 未运行 Windows App Certification Kit；未把 MSIX 上传 Partner Center，也未做商店提交。
- EXE 与 MSIX 均未代码签名，安装时可能触发 SmartScreen 警告。
- 本轮只做了静默安装载荷比对与卸载，未做 GUI 启动、单实例、最小化恢复等交互回归，
  未用临时开发身份注册并启动 MSIX；这些在 v1.0.5 轮次做过，本轮未复跑。
- 9 个环境依赖测试文件在本机无法执行（缺 python3/node/POSIX shell），未计入通过。
