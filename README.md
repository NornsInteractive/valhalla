<p align="center">
  <img src="assets/icons/valhalla_icon.png" alt="Valhalla 应用图标" width="96">
</p>

# Valhalla

**服务器运维管理工具**

Valhalla 是基于 Flutter 开发的远程服务器管理客户端，主要面向 Windows 和 Android。通过 SSH 连接服务器，在一个应用中使用终端、管理文件与容器、查看系统状态，以及访问远端 AI Agent 和 NAS 媒体库。

[官网](https://norns.cc.cd) · [微软商店](https://apps.microsoft.com/store/detail/9MZ8ML12WH8R?cid=DevShareMCLPCS) · [GitHub 下载](https://github.com/NornsInteractive/valhalla/releases) · [项目文档](docs/README.md) · [问题反馈](https://github.com/NornsInteractive/valhalla/issues)

## 主要功能

| 功能 | 说明 |
| --- | --- |
| 服务器连接 | 管理 SSH 连接配置，校验主机密钥，使用安全存储保存凭据 |
| SSH 终端 | 多标签终端、移动端辅助按键、可选 tmux 会话与 Mosh 连接 |
| 远程文件 | SFTP 文件浏览、编辑、上传与下载，紧凑路径导航、隐藏文件开关与目录符号链接；Windows 支持定位已下载文件 |
| 系统运维 | 查看 CPU、内存、磁盘、负载和运行时间，管理进程、systemd 服务及快捷命令 |
| 容器管理 | 通过 Docker CLI 查看容器状态、日志及容器终端 |
| AI Agent | ACP 会话与工具调用、权限确认；独立 CLI 会话支持 Codex、OpenCode、Claude 等工具 |
| NAS 媒体库 | 接入 SFTP、WebDAV / HTTP(S)、SMB、Jellyfin 和 Emby，浏览图片、播放音视频、下载媒体及管理收藏与播放列表 |
| 外观与语言 | 跟随系统、明亮、深色及 AMOLED 主题，自定义主题色，支持 17 种界面语言 |

Windows 版支持单实例启动，重复打开时恢复现有窗口。顶部工具栏提供主题色、主题和语言快捷入口。

## 语言设置

在设置的语言选项中切换：英语、简体中文、繁体中文、日语、韩语、德语、法语、
西班牙语、葡萄牙语、俄语、阿拉伯语、印地语、印度尼西亚语、意大利语、
土耳其语、越南语、泰语。默认跟随系统，不支持的系统语言回退英语。
保存成功后即时切换，兼容旧语言偏好，不修改服务器、Agent 或会话内容。
本轮实现及最新验收进度见[语言切换交接](docs/handoffs/2026-10-04-global-languages.md)。

## 下载与安装

Windows 版可通过 [微软商店](https://apps.microsoft.com/store/detail/9MZ8ML12WH8R?cid=DevShareMCLPCS) 安装。v1.0.4 本地发布 Android 与 Linux 包，附件位于 [Release 的 Assets](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.4) 中；Windows 下载保留 v1.0.3，本次不更新。商店版本以 Microsoft Store 页面为准。

| 平台 | 安装方式 / 架构 | 下载 |
| --- | --- | --- |
| Windows | x64 商店版 | [微软商店下载](https://apps.microsoft.com/store/detail/9MZ8ML12WH8R?cid=DevShareMCLPCS) |
| Windows | x64 安装版，v1.0.3 | [EXE 安装程序](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.3/valhalla-1.0.3-windows-x64-setup.exe) |
| Windows | x64 便携版，v1.0.3 | [ZIP 压缩包](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.3/valhalla-1.0.3-windows-x64-portable.zip) |
| Android | ARM64，多数现代手机，v1.0.4 | [arm64-v8a APK](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.4/valhalla-v1.0.4-android-arm64-v8a-signed-5.apk) |
| Android | 32 位 ARM，v1.0.4 | [armeabi-v7a APK](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.4/valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk) |
| Android | x86_64 设备 / 模拟器，v1.0.4 | [x86_64 APK](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.4/valhalla-v1.0.4-android-x86_64-signed-5.apk) |
| Linux | x64 完整目录包，v1.0.4 | [tar.gz 压缩包](https://github.com/NornsInteractive/valhalla/releases/download/v1.0.4/valhalla-v1.0.4-linux-x64.tar.gz) |

### Windows

- 需要 Windows 10/11 x64，系统版本至少为 `10.0.19041.0`。
- **商店版**：通过 Microsoft Store 安装。
- **安装版**：运行 EXE，按向导完成安装。
- **便携版**：完整解压 ZIP，再运行 `valhalla.exe`；保留同目录下的 DLL 和 `data` 文件夹。
- Windows 包已附带所需的 Visual C++ 运行库 DLL。EXE 和 ZIP 各有对应的 `.sha256` 校验文件。
- 当前 EXE 安装程序尚未进行代码签名。
- Release 中的 MSIX 是供 Partner Center 上传的未签名商店包；直接安装请使用商店、EXE 或 ZIP。

GitHub 自动生成的 **Source code (zip/tar.gz)** 是源码归档，安装应用请使用上表中的文件。

### Android

下载与你的设备架构匹配的 APK 后安装。更新时使用相同发布签名的安装包；开发用 debug 签名安装与正式发布包不兼容。

AAB 是分发用文件，不能直接安装。本版 APK 沿用原正式证书；附件提供 SHA256 校验和构建说明。

### Linux

完整解压 tar.gz 后进入 `valhalla` 目录，运行 `./valhalla`，不要只复制可执行文件。保留同目录的 `lib`、`data`、许可声明和 BUILD-INFO。本版在 Debian 12 x64 构建，需要图形会话及 GTK 3、libsecret、`libmpv.so.2` 等系统依赖，并非通用静态包；尚未完成 Linux 桌面运行验收。

本次产物、签名和验收边界见 [v1.0.4 发布记录](docs/04-testing-and-deployment/09-v1.0.4-release.md)；旧 Windows 包见 [v1.0.3 发布记录](docs/04-testing-and-deployment/08-v1.0.3-release.md)。

其他平台的构建方式见 [多平台构建与发布指南](docs/04-testing-and-deployment/04-multi-platform-github-actions.md)，可下载产物以各版本的 Release 附件为准。

## 快速开始

1. 安装并启动 Valhalla。
2. 添加服务器，填写 SSH 地址、端口、用户名及认证信息。
3. 首次连接时核对服务器主机密钥。
4. 连接后使用仪表盘、SSH 终端、远程文件、容器或系统管理功能。
5. 按需配置远端 Agent 工具或独立的 NAS 媒体源。

服务器管理需要可访问的 SSH 服务及相应账号权限。Mosh、tmux、容器和 Agent 功能依赖远端安装并配置对应工具。

## 开发

项目使用 **Flutter 3.38.1 / Dart 3.10.0**，依赖版本记录在 [pubspec.lock](pubspec.lock)。开发前请配置目标平台的原生工具链。

```bash
git clone https://github.com/NornsInteractive/valhalla.git
cd valhalla
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter run
```

运行静态检查与测试：

```bash
flutter analyze --no-pub
flutter test --no-pub
```

主要技术栈：Flutter / Material 3、Riverpod、dartssh2、xterm、ACP、SQLite 和 media_kit。项目中的 [xterm 本地依赖](packages/xterm)包含 Windows 文本输入修复，并保留上游 MIT 许可证。

### 项目结构

```text
lib/
├── core/              # 配置、状态管理、服务与设计组件
├── data/              # 数据模型与存储
├── features/          # 服务器、终端、文件、Agent、NAS 等界面
├── infrastructure/    # SSH、终端、Mosh 等底层集成
└── l10n/              # 多语言资源
packages/              # 本地依赖与原生组件
test/                  # 单元与组件测试
integration_test/      # 集成测试
tool/                  # 打包与验证工具
docs/                  # 产品、架构、开发和发布文档
```

## 文档

- [文档索引](docs/README.md)
- [产品需求](docs/01-requirements/01-prd-product-requirements.md)
- [系统架构](docs/02-architecture/01-system-architecture.md)
- [NAS 媒体库架构](docs/02-architecture/04-nas-streaming-architecture.md)
- [界面设计规范](docs/design/REDESIGN-2026-09.md)
- [构建与环境指南](docs/04-testing-and-deployment/02-deployment-and-environment-guide.md)
- [Windows 商店打包说明](docs/windows-store-submission.md)
- [Android 发布签名](docs/04-testing-and-deployment/05-android-release-signing.md)

## 反馈与联系

遇到问题或提出功能建议，请提交 [GitHub Issue](https://github.com/NornsInteractive/valhalla/issues)。报告问题时请附上应用版本、操作系统及复现步骤，并隐去密码、私钥、令牌等敏感信息。

- 官网：[norns.cc.cd](https://norns.cc.cd)
- 联系邮箱：[norns.soft@gmail.com](mailto:norns.soft@gmail.com)
- 开发者：**Norns Interactive**

## 隐私与许可

隐私政策：[简体中文](PRIVACY.md) · [English](PRIVACY.en.md)。

本项目采用 **PolyForm Noncommercial License 1.0.0**，属于非商用源码许可。完整条款见 [LICENSE](LICENSE)，版权与第三方组件声明见 [NOTICE](NOTICE)，另有 [中英文许可说明](docs/licensing.md)。商业授权请联系 `norns.soft@gmail.com`。

第三方库、字体和其他组件保留各自的许可证。
