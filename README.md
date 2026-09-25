# Valhalla

2026-09-19 增量：独立 CLI 原生会话、安全重启、容器逐项操作反馈与终端 resize 优化；后台历史隔离仅设计，真机性能待验收。[实现与限制](docs/handoffs/2026-09-19-cli-reboot-performance.md)。

Valhalla 是基于 Flutter 的 AI-Native 远程服务器与 Agent 管理客户端，优先支持 Android 和 Windows Native。

## 能力

- SSH/SFTP 服务器配置、Host Key 校验和安全凭证存储
- xterm SSH PTY、多终端会话和移动端辅助按键
- ACP Agent 会话、流式响应、Tool Call 和权限审批
- SFTP 文件浏览、编辑与传输
- Docker CLI 远程管理、日志和容器终端
- 快捷命令、危险操作拦截、进程与 systemd 服务管理
- CPU、内存、磁盘、Load 和 Uptime 监控
- 独立 NAS 媒体库：SFTP、WebDAV / HTTP(S)、SMB、Jellyfin / Emby，图片预览、音视频流播放、收藏与播放列表

## NAS 媒体库

NAS 媒体源独立管理，使用 SQLite 分批索引、游标分页和后台音乐标签探测；音视频复用 `media_kit`，支持 Range / HLS、续播及系统媒体控制。提供 DLNA 投屏、下载后系统打开，以及需要预览确认的可选 Jellyfin / Emby / rclone WebDAV 部署向导和 SSH HTTP 隧道。

当前最终索引结构的百万条合成数据测试：首页 / 95% 深页查询 P95 为 2.352 / 1.662 ms。真实 Jellyfin / Emby API、签名 SMB2 及 Android `sdk_gphone64_x86_64` 模拟器上的 NAS 集成测试已通过，界面与系统媒体控制仍在验收；真实 DLNA 电视、Apple / Windows 原生构建尚未验证。集成测试仅可在无用户数据的专用测试模拟器运行，正常安装使用 `adb install -r`。能力边界、基准环境和重放说明见 [NAS 架构](docs/02-architecture/04-nas-streaming-architecture.md) 与 [实施状态](docs/03-development/04-implementation-status.md)。

## 技术栈

Flutter 3.44 / Dart 3.10、Material 3、Riverpod、dartssh2、acpd、xterm、flutter_markdown_plus、syntax_highlight、flutter_secure_storage、file_picker。

## 开发检查

```bash
flutter pub get
flutter analyze
flutter test
```

产品需求、架构、协议、开发规则和测试矩阵位于 [`docs/`](docs/README.md)。
