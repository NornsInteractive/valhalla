# Valhalla

2026-09-26 增量：**Norse Steel 全量 UI 重设计**（打包 Inter / JetBrains Mono 字体、语义状态色、骨架屏、交错入场与指标动效，尊重系统"减少动态效果"）、**Mosh 终端支持**（UDP/SSP 漫游连接，掉线与 IP 切换不断线）、切标签闪烁修复。变更全记录与接手须知见[接手文档](docs/handoffs/2026-09-26-durandal-norse-steel-redesign-and-mosh.md)，设计系统规则见 [REDESIGN-2026-09](docs/design/REDESIGN-2026-09.md)。

Valhalla 是基于 Flutter 的 AI-Native 远程服务器与 Agent 管理客户端，优先支持 Android 和 Windows Native。

## 下载

Windows x64 应用包见 [Releases](https://github.com/NornsInteractive/valhalla/releases)。
下载 Assets 中的应用 ZIP，完整解压后运行 `valhalla.exe`；不要只复制 EXE，
也不要将 Source code ZIP 当作安装包。需要 Windows 10/11 x64 和 Visual C++
x64 运行库，当前应用未签名，Windows 实际功能仍需独立验收。
自动打包与版本发布方法见 [Windows 发布指南](docs/04-testing-and-deployment/03-windows-github-actions.md)。

## 能力

- SSH/SFTP 服务器配置、Host Key 校验和安全凭证存储
- xterm SSH PTY、多终端会话和移动端辅助按键
- **Mosh 终端会话**：SSH 引导 mosh-server，UDP/SSP 长连接漫游（基于 dart_mosh，AES-OCB 加密）
- ACP Agent 会话、流式响应、Tool Call 和权限审批
- 独立 CLI 原生会话：Codex（app-server JSON-RPC）、OpenCode（SSH 隧道 HTTP/SSE）、Claude（真实终端审批 + 官方 SDK 历史）
- SFTP 文件浏览、编辑与传输
- Docker CLI 远程管理、日志和容器终端
- 快捷命令、危险操作拦截、进程与 systemd 服务管理
- CPU、内存、磁盘、Load 和 Uptime 监控（数字滚动与动画进度）
- 独立 NAS 媒体库：SFTP、WebDAV / HTTP(S)、SMB、Jellyfin / Emby，图片预览、音视频流播放、收藏与播放列表

## NAS 媒体库

NAS 媒体源独立管理，使用 SQLite 分批索引、游标分页和后台音乐标签探测；音视频复用 `media_kit`，支持 Range / HLS、续播及系统媒体控制。提供 DLNA 投屏、下载后系统打开，以及需要预览确认的可选 Jellyfin / Emby / rclone WebDAV 部署向导和 SSH HTTP 隧道。

当前最终索引结构的百万条合成数据测试：首页 / 95% 深页查询 P95 为 2.352 / 1.662 ms。真实 Jellyfin / Emby API、签名 SMB2 及 Android 模拟器上的 NAS 集成测试已通过。集成测试仅可在无用户数据的专用测试模拟器运行，正常安装使用 `adb install -r`。能力边界、基准环境和重放说明见 [NAS 架构](docs/02-architecture/04-nas-streaming-architecture.md) 与 [实施状态](docs/03-development/04-implementation-status.md)。

## 技术栈

Flutter 3.47.5 / Dart 3.10、Material 3、Riverpod、dartssh2、acpd、xterm、dart_mosh、flutter_markdown_plus、syntax_highlight、flutter_secure_storage、file_picker；打包字体 Inter + JetBrains Mono。

界面语言：Norse Steel 设计系统 —— 钢灰表面阶梯 + 单一种子色强调、统一圆角体系（卡片 16 / 弹窗 20 / 输入 12）、语义状态色不随主题色漂移、数字与主机信息等宽字体。自定义令牌与动效组件位于 [`lib/core/design/`](lib/core/design/)，使用规则见 [设计规范](docs/design/REDESIGN-2026-09.md)。

## 开发检查

```bash
flutter pub get
flutter analyze
flutter test
```

基线：analyze 零告警，测试 1153 通过 / 18 跳过（2026-09-26）。新增循环动画必须走 `_loopingAnimationsSuspended` 测试闸门（见 `lib/core/design/motion_widgets.dart`），否则 `pumpAndSettle` 测试会失败。

产品需求、架构、协议、开发规则和测试矩阵位于 [`docs/`](docs/README.md)；重大决策记录见 [`docs/design/`](docs/design/)（ADR / SPEC）。

## 分支

- `main` — 当前开发主线
- `OldBranch` — 2026-09 Norse Steel 重设计前的代码快照（存档，不再更新）
