# Windows 构建机说明

记录用于验证 `windows/` 目标的 Windows x64 构建机。本文只做描述，不改变构建、
签名或发布行为。文中结论均来自 `build/windows-builder/setup-report.md` 与
`build/windows-builder/atl-observation.md` 记录的实际结果。

## 状态（2026-10-29）

| 项目 | 状态 |
|---|---|
| 主机 | Windows Server 2025 Standard Evaluation，x64（`10.0.26100`），主机名 `WIN-BUILDER` |
| SSH 端点 | `builder@127.0.0.1:14320`，在当前环境中可连通 |
| Flutter | 3.38.1 stable（Dart 3.10.0，framework `b45fa18946`），归档 SHA-256 已校验，安装在 `C:\valhalla-build\flutter` |
| Git | 2.56.0.windows.4，安装在 `C:\Program Files\Git` |
| Visual Studio 2022 Build Tools | 17.14.37824.6，含 **Desktop development with C++**（VCTools）工作负载，安装在 `C:\valhalla-build\VSBuildTools` |
| MSVC | 14.44.35207（`cl.exe` 可用） |
| Windows SDK | 10.0.26100.0 |
| ATL | 已安装（`Microsoft.VisualStudio.Component.VC.ATL`，`atlstr.h` 存在） |
| Rust | 已安装，`cargo`/`rustc` 在 PATH 上（`CARGO_HOME`/`RUSTUP_HOME` 位于 `C:\valhalla-build`） |
| 本机 `flutter build windows --release` | **已实际执行成功，退出码 0** |
| 产物/哈希校验 | **已执行**：完整 Release 目录打包并核对 SHA-256 |

安装器与构建都走一次性计划任务，验证完成后**这些一次性任务已删除**（包括旧的
`\ValhallaBuild` 与本次唯一的 `\ValhallaBuildCB20261029T0326`）；查询 `Valhalla*`
任务已无残留。当前没有安装器或构建进程在运行，也没有待完成的安装。

## 已验证的构建结果

- 源码：`C:\valhalla-build\work`，HEAD = `0c6f1b836475f3fed3cadb9bbb02a13f91b3a973`，
  分支 `main`，与待验证提交完全一致。
- 命令：`flutter build windows --release`，记录退出码 **0**（写入 exit 文件并核对任务
  Last Result 均为 0；此前 0 字节的 `build.exit` 是 `echo %RC%> file` 的重定向写法
  缺陷，不是构建失败）。
- 产物目录 `build\windows\x64\runner\Release`：**65 个文件，100,100,528 字节**，
  四个必需项 `valhalla.exe`、`flutter_windows.dll`、`data\icudtl.dat`、
  `data\flutter_assets\` 均存在。`data\flutter_assets` 在构建时刻被重写，
  `data\app.so` 存在，说明 Dart AOT 载荷确实重建。
- 打包：整个 Release 目录压缩为 `valhalla-windows-release-20261029T0326.zip`，
  **41,773,133 字节**，SHA-256
  `16cd442506bbda0cd8a8b2193a3589997396a9d09dc304674408c8c03c503bb6`，
  远端与拉回本地后计算的哈希一致，zip 完整性测试通过。
- 唯一告警是 `valhalla_smb/vendor/libsmb2/CMakeLists.txt` 的 CMake
  `cmake_minimum_required` 版本弃用提示，无错误。

该构建仍是**未签名**的；能编译并通过产物校验，不等于 Windows GUI 交互、真实
SSH/Agent 服务端或端到端功能已经验收——这些尚未测试。

## 访问方式

`127.0.0.1:14320` 是当前环境可用的**回环地址**。它可能是某种端口转发或 SSH
隧道，但转发机制尚未确认；因此不要据此推断构建机的真实地址或网络拓扑，也不要
把它当成构建机的实际监听地址来记录。

- 首次连接前，通过**独立渠道**核对构建机主机密钥（云厂商控制台、预置元数据，
  或已有的固定 `known_hosts`）。不要只依赖从这个回环端点学到的密钥。
- 固定主机密钥，使用 `StrictHostKeyChecking=yes` 并显式指定
  `UserKnownHostsFile`。禁止使用 `StrictHostKeyChecking=no`、
  `UserKnownHostsFile=/dev/null` 或 `-o GlobalKnownHostsFile=/dev/null`。
- 用 SSH agent/密钥或交互式输入完成认证。私钥、口令、passphrase、token 或任何
  密钥材料都不得出现在本文、命令行、示例、日志或仓库中。优先用
  `ssh-agent` / `SSH_AUTH_SOCK`，避免把秘密写进脚本。
- 固定的 `known_hosts` 内容不要纳入版本控制（例如放在被忽略的
  `build/windows-builder/` 临时目录）。

示例（仅示意形态：agent 认证、固定密钥、命令行不含任何秘密）：

```powershell
ssh -p 14320 `
  -o StrictHostKeyChecking=yes `
  -o UserKnownHostsFile="$env:USERPROFILE\.ssh\valhalla-builder_known_hosts" `
  builder@127.0.0.1
```

## 委派要求

在构建机上安装工具、运行构建、运行测试、操作设备，都必须**委派给
CodeBuddy/OpenCode** 执行，不能由根助手直接操作。根助手只能读取结果和文档，
不得自行安装、构建、执行 ADB/设备操作或改动环境。耗时任务应放到独立会话中运行，
再从磁盘读回结果，避免客户端断线后留下状态不明的半成品。

## 工具链与 PATH

Flutter 3.38.1 与 `.github/workflows/windows-build.yml` 以及 `pubspec.lock`
中锁定的 SDK 版本保持一致。Rust 工具链位于构建机专用目录，不在系统默认 PATH
上，需要显式加入。

```powershell
# 让本 shell 找到已安装的工具（含 Rust 专用目录）。
$env:CARGO_HOME  = 'C:\valhalla-build\.cargo'
$env:RUSTUP_HOME = 'C:\valhalla-build\.rustup'
$env:Path = 'C:\valhalla-build\.cargo\bin;C:\valhalla-build\flutter\bin;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;' + $env:Path
```

`flutter build windows --release` 需要 VS C++ 工具链。若 MSVC 不在 PATH 上，用
已安装 Build Tools 的 Developer PowerShell / `vcvars64.bat`，或让 Flutter 通过
`vswhere` 自行定位；不要手改生成的 CMake 文件来绕过缺失的工具链。

Windows 构建要求干净的检出：不要在含未提交或未跟踪改动的树上构建，也不要让依赖
解析悄悄改写 `pubspec.yaml`/`pubspec.lock`。注意 Flutter 构建会重写
`windows/flutter/generated_plugin_registrant.*` 等生成文件，这些差异属于生成器
输出，发布前应确认没有源码改动混入。

## 构建步骤

在**固定到待验证源码提交**的干净检出上执行。替换成真实 commit SHA；记录来源时
不要用会移动的分支尖端。

```powershell
# 让本 shell 找到已安装的工具（见上节）。
$env:Path = 'C:\valhalla-build\.cargo\bin;C:\valhalla-build\flutter\bin;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;' + $env:Path

# 干净且固定版本的检出（示例）。
git clone <repo-url> C:\valhalla-build\work\valhalla
Set-Location C:\valhalla-build\work\valhalla
git checkout --detach <source-commit-sha>
if (git status --porcelain) { throw 'Working tree is not clean' }

# 复现 CI：锁定依赖、生成本地化、静态分析、release 构建。
flutter --version
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze --no-pub
flutter build windows --release

# 构建若改写了锁定输入则失败。
git diff --exit-code -- pubspec.yaml pubspec.lock
```

构建必须由委派会话在可追踪的包装脚本里执行，并把退出码写到独立文件（重定向写在
命令前，如 `> "file" echo %RC%`），避免 `echo %RC%> file` 在 `RC=0` 时产生 0 字节
记录。判定成功前先确认退出码文件内容与任务 Last Result 都为 0。

### 期望的产物目录

输出目录：`build\windows\x64\runner\Release`。

CI 至少要求存在：

- `valhalla.exe`
- `flutter_windows.dll`
- `data\icudtl.dat`
- `data\flutter_assets\`

打包脚本 `tool/package_windows_exe.ps1` 还要求 `data\app.so`、许可与声明文件
（含 `LICENSE`、`NOTICE`、`data\flutter_assets\LICENSE`、
`data\flutter_assets\NOTICE`、隐私声明文件）、
`licenses\libsmb2\LICENCE-LGPL-2.1.txt`，以及 VC 运行时 DLL
（`vcruntime140.dll`、`msvcp140.dll`）和 `zlib.dll`。在判定构建合格前先校验目录
完整：

```powershell
$bundle = 'build\windows\x64\runner\Release'
foreach ($required in @('valhalla.exe','flutter_windows.dll','data\icudtl.dat','data\flutter_assets')) {
  if (-not (Test-Path (Join-Path $bundle $required))) { throw "Missing: $required" }
}
Get-ChildItem $bundle | Select-Object Name, Length
```

### 打包与哈希

要打包**整个** `Release` 目录；只有 exe 而没有 DLL 和 `data` 树是跑不起来的。
生成 `BUILD-INFO.txt` 记录源码提交、版本、UTC 构建时间和 Flutter 版本，压缩整个
目录，并把 SHA-256 与压缩包放在一起：

```powershell
$zip = 'build\windows-artifacts\valhalla-windows-x64.zip'
New-Item -ItemType Directory -Force build\windows-artifacts | Out-Null
Compress-Archive -Path "$bundle\*" -DestinationPath $zip -CompressionLevel Optimal
(Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() |
  ForEach-Object { "$_  $(Split-Path -Leaf $zip)" } |
  Set-Content "$zip.sha256" -Encoding ascii
```

`Compress-Archive` 生成的 zip 使用 Windows `\` 分隔符，Windows 解压正常。

只有产物校验通过、归档哈希已记录、且记录的提交与检出一致时，构建才算"已验证"。
能编译不等于真实服务端/Agent 或桌面功能可用；设备与端到端验收是另外的事。

## 产物取回：SFTP/scp 截断问题（未修复）

在该 SSH 服务上实际观察到：默认走 SFTP 的 `scp` 会把每个文件**静默截断到
204,800 字节**，即使命令报告成功（用 1 MiB 测试文件复现）。这是该传输服务的
行为，不是构建问题，**目前没有修复**，不要声称已解决。

- 用传统协议 `scp -O` 传输可以完整取回文件；本次 zip 就是这样拉回本地的。
- 无论用哪种方式，都必须**在本地与远端分别计算 SHA-256 并比对**，一致后才可
  认为产物完整；不要只看命令退出码或文件大小。
- 大文件传输后若大小恰好是 204,800 字节的整数倍或明显偏小，按截断处理并重传。

## 与发布自动化的关系

`tool/release.py` 目前只发布 **Android 与 Linux**，并且不使用这台 Windows 机器；
本文不改变它的发布范围。这台 Windows 构建机**尚未接入**任何自动发布流程，
本机产物也没有被发布。

独立的 `.github/workflows/windows-build.yml` 包含一个在 `windows-2022` 上运行的
Windows x64 构建 job，产出**未签名**的 zip 与 `.sha256`，并作为 workflow
artifact 上传（保留 14 天）。该工作流在 push `v[0-9]*` 标签时还带一个发布 job：
其条件是事件为 push 且 ref 为 `refs/tags/v`，且依赖 Windows 构建 job 与 native
矩阵 job 都成功；满足条件时会把包括 Windows 包在内的产物发布到 GitHub Release。
此外 preflight 会要求标签与 `pubspec.yaml` 中的版本一致。触发还受 workflow 的
分支/标签与路径过滤条件约束。

这台构建机上**没有配置 Windows 签名证书**，CI 的 Windows 产物同样是未签名的。
不要声称当前 CI 已经执行过，也不要把本机产物说成已发布的 release。

## 边界

- 文档、示例与日志中不得出现任何凭据、密钥、token 或带秘密值的主机标识。
- 不要假设已启动的安装或构建已完成；报告成功前先确认退出状态与磁盘上的产物。
- 本文只记录环境，不修改 `tool/release.py`、CI、签名或任何其他文件。
