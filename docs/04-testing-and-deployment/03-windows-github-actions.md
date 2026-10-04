# Windows GitHub Actions 自动打包

## 工作流与范围

工作流：[`windows-build.yml`](../../.github/workflows/windows-build.yml)。
构建页面：[Valhalla / Windows Build](https://github.com/NornsInteractive/valhalla/actions/workflows/windows-build.yml)。

使用 GitHub 的 `windows-2022` 运行器、Flutter `3.38.1` stable 和仓库中的
`pubspec.lock`，生成 Windows x64 Release 便携包。复用现有 Windows 工程，
不更改 UI，不引入安装器、代码签名或新的服务端组件。构建验证与产物核验
由 OpenCode 执行；CI 成功不代表 Windows 上的 SSH、ACP、媒体播放等业务
已通过真实环境验收。

SDK 选择依据：本机 SDK 元数据虽然显示 `3.44.2`，实际框架提交是
`b45fa18946ecc2d9b4009952c636ba7e2ffbb787`，官方发布清单对应 Flutter
`3.38.1` / Dart `3.10.0`。首次使用官方 `3.44.2` 的 CI 在严格锁文件检查
时失败，要求修改 7 个 SDK 依赖。工作流因此固定到实际兼容的官方版本，
保留现有锁文件与 Android 构建环境，不在本次打包中进行 SDK/依赖升级。

## 如何建立工作流

GitHub Actions 的工作流是提交在 `.github/workflows/` 目录中的 YAML 文件。
本仓库已提供，无需重新在网页创建：

1. `on` 指定何时触发：手动 `workflow_dispatch`、推送到 `main` 或版本标签。
2. `jobs.build.runs-on: windows-2022` 指定真正的 Windows 编译环境。
3. `steps` 顺序检出源码、安装 Flutter、按锁文件解析依赖、生成多语言、
   静态分析、执行 `flutter build windows --release --no-pub`。
4. 构建成功后压缩整个 `build/windows/x64/runner/Release/`，生成 SHA256
   校验文件，并以 Actions Artifact 上传。

第三方 Actions 固定到提交 SHA；构建 job 只需要 `contents: read`，仅标签
发布 job 使用 `contents: write` 和 GitHub 自动提供的 `GITHUB_TOKEN`。
不需要新增 SSH 密钥、服务器登录信息或长期发布 Token，不把账号凭据写进 YAML。

## 手动构建

1. 打开仓库 **Actions**，左侧选择 **Windows Build**。
2. 点击 **Run workflow**，分支选择 `main`，再次点击 **Run workflow**。
3. 打开新运行，逐步查看日志。全部绿色后，在运行页面下方 **Artifacts**
   下载 `valhalla-windows-x64-<运行编号>`。

也可以在已登录的 GitHub CLI 中运行：

```bash
gh workflow run windows-build.yml --repo NornsInteractive/valhalla --ref main
gh run list --repo NornsInteractive/valhalla --workflow windows-build.yml --limit 5
gh run watch <运行ID> --repo NornsInteractive/valhalla --exit-status
gh run download <运行ID> --repo NornsInteractive/valhalla --dir ./windows-package
```

手动入口要求工作流先存在于默认分支。私有仓库的查看者必须有相应权限。

## 自动构建

将代码提交并推送到 `main` 后，若更改涉及以下路径，GitHub 自动排队构建：

- `lib/`、`windows/`、`packages/`、`assets/`
- `pubspec.yaml`、`pubspec.lock`、`l10n.yaml`、`analysis_options.yaml`
- 本工作流文件

仅修改文档不自动消耗 Windows 构建额度，可按需手动触发。同分支的新运行
会取消仍在进行的旧运行，保留最新源码的构建。不要为了排队或额度错误
自动启用付费支出；需由仓库所有者确认 Actions 额度与计费设置。

## 下载与运行

Artifact 下载包包含一个应用 ZIP 和同名 `.sha256`。先解压 Artifact，再将
应用 ZIP **完整解压**到同一目录，运行 `valhalla.exe`；不可单独复制 EXE，
必须保留 `flutter_windows.dll`、插件 DLL、`data/` 等完整内容。
`BUILD-INFO.txt` 记录源码提交、版本、构建时间与 Flutter 版本。

目标机器需要 Windows 10/11 x64 及
[Microsoft Visual C++ x64 运行库](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)。
本轮不做代码签名；Windows 可能出现未知发布者/SmartScreen 提示，确认
来源及 SHA256 后再操作，不要全局关闭系统安全功能。

PowerShell 校验示例：

```powershell
Get-FileHash .\valhalla-windows-x64-<运行编号>.zip -Algorithm SHA256
```

Artifact 保留 14 天，过期需重新运行。版本发布使用下方 Releases，
不受 Artifact 的 14 天期限影响。本轮不发布到商店、不引入安装器或代码签名。

## Releases 版本发布

应用下载入口：[仓库 Releases](https://github.com/NornsInteractive/valhalla/releases)。
普通 `main` 推送和手动分支构建只生成 Artifact，不创建版本发布。
推送 `v<版本号>` 标签才自动创建 Release：先验证标签与 `pubspec.yaml` 中
版本号（不含 `+构建号`）一致，完整构建成功后下载同次运行的 Artifact，
复验 SHA256，再上传 ZIP 和 `.sha256`。发布 job 无权使用服务器凭证，
不覆盖已有 Release 或资产；预发布版本（版本号含 `-`）标记为 prerelease。

后续发布示例（版本号只是示例，不要直接给旧源码打新版本）：

1. 将 `pubspec.yaml` 的版本改为 `1.0.1+2`，经 OpenCode 验证后提交并推送。
2. 确认待发布提交已经包含发布工作流，创建并推送**新的**标签：

   ```bash
   git tag v1.0.1 <待发布提交SHA>
   git push origin v1.0.1
   ```

3. 在 Actions 查看标签运行；构建及 `Publish GitHub Release` 成功后，
   仓库首页右侧 Releases 和 Releases 页面可下载该版本。

用户已授权本次发布。首个 `v1.0.0` 使用上一轮已验证的构建 #2 原始 ZIP，
标签绑定其真实源码 `b8839ab21835391c861d2730cea10219588676b8`，不重新打包
或改写 `BUILD-INFO.txt`。该旧提交没有自动发布步骤，首发通过 GitHub CLI
上传既有产物；后续新标签才使用新增的自动发布 job。该 job 的语法与本地
校验逻辑由 OpenCode 验证，首发不能冒充新增标签流水线的实际运行证明。

仓库当前为私有仓库，Releases 下载仍需要仓库读取权限；不会为发布更改
仓库可见性。若首页没有显示 Releases，可在仓库 About 设置中开启 Releases
侧栏展示。下载 ZIP 后完整解压，不要下载 GitHub 自动生成的 Source code
ZIP 来代替应用包。

## 排错与证据

- 无 `Run workflow`：确认工作流已合并到默认分支且 Actions 已启用。
- 依赖锁文件不兼容：更新应由 OpenCode 在明确 SDK 下执行并审查，不在 CI
  静默升级依赖。
- 静态分析或原生编译失败：查看失败 step，修复具体错误后重新推送；
  不跳过门禁或上传上一次的产物。
- 排队/额度/计费受限：由仓库所有者检查 Actions 配额，不擅自提高付费限额。
- 包构建成功但运行失败：先确认完整解压和 VC++ 运行库，再记录 Windows
  版本及启动日志；编译成功不能代替桌面功能验收。

## 首次交付证据（2026-10-04）

- 源码提交：`b8839ab21835391c861d2730cea10219588676b8`，应用版本
  `1.0.0+1`。后续仅补充文档的提交不改变本包来源。
- [Windows 构建 #2](https://github.com/NornsInteractive/valhalla/actions/runs/37179693736)：
  严格锁文件解析、多语言生成、静态分析、Windows Release 编译、完整打包与
  上传步骤及 SDK 缓存收尾全部通过，运行最终状态为 `completed / success`。
- [下载产物 valhalla-windows-x64-2](https://github.com/NornsInteractive/valhalla/actions/runs/37179693736/artifacts/11294957476)：
  Artifact ID `11294957476`，产物保留至 `2026-10-18`。
- 应用 ZIP：`valhalla-windows-x64-2.zip`，38,847,608 字节，构建时间
  `2026-10-04T05:28:38.3731497Z`。
- SHA256：`39275c19735e4b58d5a585f91fd8aa193d51ec3e63083baf35457166e1c5b631`。

OpenCode 使用 `opencode/mimo-v2.6-flash-free` 完成以下验证：

- `actionlint` v1.7.12：退出 0；修正前、后的工作流均无语法发现。
- 本地 `flutter pub get --enforce-lockfile`、`flutter gen-l10n`、
  `flutter analyze --no-pub`：退出 0；没有更改依赖锁文件或多语言源码。
- 通过 GitHub CLI 读取 CI 结果、下载产物：退出 0。
- ZIP SHA256 与上传校验文件相符；`unzip -t` 退出 0，完整解压得到 52 个文件。
- 读取 PE 文件头确认 EXE、Flutter/SMB/SQLite/SMTC/libmpv DLL 为 x86-64。
  确认 `data/app.so`、`data/icudtl.dat`、29 个 Flutter 资源文件及插件 DLL
  存在，`BUILD-INFO.txt` 的版本与源码提交匹配。

产物下载及核验目录：`/tmp/opencode/windows-run-37179693736/`。此处是临时
验证副本，正式下载入口仍为上方 GitHub Artifact。
当前未在真实 Windows 桌面启动应用或连接服务器，不将结构/编译检查作为
SSH、ACP、NAS 播放等功能的验收证明。
