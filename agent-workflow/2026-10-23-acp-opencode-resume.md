# OpenCode 最终验证回执

2026-10-23，使用已核验免费的 OpenCode Nemotron 模型执行；主代理核对原始命令回执。

- `flutter gen-l10n`：成功。
- `flutter analyze --no-pub`：No issues found，15.8 秒。
- `python3 test/infrastructure/acp_broker_test.py`：12 项通过，9.857 秒。
- 12 个相关 Flutter 测试文件：180 项通过，0 失败；含新增授权弹窗 5 项。
- ADB Android 模拟器：同原正式签名覆盖安装，保留已有配置和历史；退出前 5 个输出事件，强制关闭后增长至 10 个，第二个 App 进程继续恢复到 30 条有序输出；请求数为 1。
- 已重新构建并安装正常 `lib/main.dart` 入口，版本 1.0.16 / code 4017；启动截图与日志确认不是测试入口，无 FATAL EXCEPTION。

实际命令、完整输出和退出码见忽略目录 `build/acp-device-validation/final-gates/`，
设备机器回执为 `build/acp-device-validation/device-result.json`，
截图为 `build/acp-device-validation/normal-app.png`。不采用此前报告中推算的分文件数量或“约 80+”计数。

验证范围：真实 Android 进程/SSH/服务端代理与隔离模拟 Agent；未向真实 Codex、AgY 等生产会话发送消息。
未执行 Docker 实际 Agent、Windows/Apple 原生验收或物理手机测试。已有配置中的 SFTP 性能测试服务器离线，正常 App 的启动截图显示其离线缓存，不代表该服务器联网验收通过。

正式发布仍需按发布脚本完成新版本构建、签名/归档审计、GitHub 与分发平台代理校验。
