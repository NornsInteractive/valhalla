# 构建环境速查

## Android（本地 Linux）

- 历史发布记录中的 Flutter CLI 版本为 3.44.2，framework revision `b45fa18946` 对应 3.38.1 tag；Dart 3.10.0。Android SDK/build-tools 为 36.0.0，JDK 为 OpenJDK 17.0.20；Linux 使用 clang 14.0.6、CMake 3.25.1、Ninja 1.11.1。
- 正式签名库：`/home/dev/.local/share/valhalla-signing/android-release.p12`
- 密码文件：同目录 `android-release.password`；别名：`valhalla`
- 之前构建/验收会话使用的 ADB 设备目标：`127.0.0.1:14251`（wireless ADB transport）。ADB 服务端默认端口 `5037` 不是该设备目标。
- 文件在仓库外，勿复制、提交或打印密码。正式构建使用 `tool/release.py`，它会读取既有签名配置并校验签名；不要重新生成证书。
- GitHub Actions 使用仓库 Secrets：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。这里只记录名称，不记录值。

## Windows x64 构建机

- SSH：`builder@127.0.0.1`，端口 `14320`。历史记录确认它是回环转发地址，但没有记录转发源主机名。
- 使用 SSH 密钥/agent 或交互式输入密码认证；连接前核对主机指纹，并启用严格校验。不要把密码、私钥或口令写入命令、脚本或仓库。
- 当前临时 `known_hosts` 文件位于被忽略的 `build/windows-builder/known_hosts`。连接示例：

  ```bash
  ssh -p 14320 -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile=build/windows-builder/known_hosts \
    builder@127.0.0.1
  ```

- 最近一次 Windows 构建记录使用 `C:\valhalla-build\windows-1038-build\src`，依次执行锁定依赖解析、多语言生成和 `flutter build windows --release`，Release 输出在 `build\windows\x64\runner\Release`。工具链详情与较早构建证据见 [`windows-builder.md`](../windows-builder.md)。当前没有受信任的 Windows 代码签名证书，EXE/MSIX 按未签名包构建。

测试、构建和设备操作按项目流程交给 OpenCode 或 CodeBuddy；发布使用 [`tool/RELEASE.md`](../../tool/RELEASE.md)。

## Norns MCP 登记

- Linux Android/Linux：`7d6d322d-73f6-4d0d-89cc-376a02094c5d`（version 14）
- Windows x64 SSH：`79b89ddf-cd4d-4aae-8c4b-43f9cb2b9f54`（version 3）；SSH 密码保存在 MCP 加密凭据字段中。
- Android ADB 设备目标为历史会话使用的 `127.0.0.1:14251`；5037 是 ADB 服务端端口。Android 签名密码从构建主机受限文件读取，没有上传到 MCP。
- 当前记录仅覆盖历史上有实际构建证据的 Android、Linux 和 Windows 环境；没有可登记的 macOS/iOS 构建主机记录。
