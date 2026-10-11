# Valhalla v1.0.4

Norns Interactive · `1.0.4+5`

- SSH 终端改为右下角按钮显式打开输入法，避免被动点击、弹窗关闭和页面切换自动弹出键盘；保留长按选择复制。
- 终端阅读位置保持、分组快捷键、自定义固定按键和粘贴确认保护。
- 远程文件隐藏项弱化显示，支持保存列表／卡片视图偏好。
- 纳入后台恢复、文件传输、GitHub 开源入口与更新检测／下载的已实现基础能力。

## 下载

本次仅本地构建 Android 和 Linux，不启动 GitHub Actions。

- Android：正式签名 ARM64、ARMv7、x86_64 APK，以及分发用 AAB。多数手机选 `arm64-v8a` APK；AAB 不能直接安装。
- Linux：x64 完整目录包，解压后保留 `lib`、`data`、许可说明等目录，需要图形会话和 GTK 3、libsecret、libmpv 等运行依赖。
- Windows／macOS／iOS 本次不构建；Windows 仍使用旧版下载，不将其标为 v1.0.4。

附件提供 `SHA256SUMS.txt`、单独校验文件、构建说明与应用更新清单 `update.json`。
Android 沿用原发布证书；不能直接覆盖调试签名版，请先备份数据，勿为绕过签名冲突盲目卸载。

## 验证与边界

OpenCode 本地全量测试：**2441 通过、18 项按环境条件跳过、0 失败**；整项目静态检查零告警，更新清单生成器 27 项测试通过。
未执行本次 ADB 安装、真实生产服务器验收或 Linux 桌面运行验收。编辑器、系统服务和 NAS 的后续消费者交互仍有待完善，不宣称全部规划功能已交付。

构建源码：[b397ec6](https://github.com/NornsInteractive/valhalla/tree/b397ec62255fa9cc0575941450a4b2cdadfa4608)。
详细范围见仓库中的 `docs/04-testing-and-deployment/09-v1.0.4-release.md`。
