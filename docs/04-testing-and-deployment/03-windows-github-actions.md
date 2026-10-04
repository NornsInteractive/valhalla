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

1. `on` 指定何时触发：手动 `workflow_dispatch` 或推送到 `main`。
2. `jobs.build.runs-on: windows-2022` 指定真正的 Windows 编译环境。
3. `steps` 顺序检出源码、安装 Flutter、按锁文件解析依赖、生成多语言、
   静态分析、执行 `flutter build windows --release --no-pub`。
4. 构建成功后压缩整个 `build/windows/x64/runner/Release/`，生成 SHA256
   校验文件，并以 Actions Artifact 上传。

第三方 Actions 固定到提交 SHA；工作流只需要 `contents: read`，不需要
新增 SSH 密钥、服务器登录信息或发布 Token。不要把账号凭据写进 YAML。

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

Artifact 保留 14 天，过期需重新运行。当前不自动创建 GitHub Release，
也不自动发布到商店；需要长期发布或安装器时另行明确签名与发布策略。

## 排错与证据

- 无 `Run workflow`：确认工作流已合并到默认分支且 Actions 已启用。
- 依赖锁文件不兼容：更新应由 OpenCode 在明确 SDK 下执行并审查，不在 CI
  静默升级依赖。
- 静态分析或原生编译失败：查看失败 step，修复具体错误后重新推送；
  不跳过门禁或上传上一次的产物。
- 排队/额度/计费受限：由仓库所有者检查 Actions 配额，不擅自提高付费限额。
- 包构建成功但运行失败：先确认完整解压和 VC++ 运行库，再记录 Windows
  版本及启动日志；编译成功不能代替桌面功能验收。

首次运行的提交、运行链接、验证结果与产物校验值在实际完成后补录。
