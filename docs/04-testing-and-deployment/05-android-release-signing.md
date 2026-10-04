# Android 固定发布签名

2026-10-04 用户要求生成签名。在仓库外生成 RSA 3072 / SHA256withRSA 的
PKCS12 发布密钥，alias `valhalla`，有效期 10000 天。它不是 debug keystore。
证书标识使用项目名与仓库组织名，不表示受信任 CA 认证。Android 允许自行
生成发布密钥；Windows 受信任代码签名、Apple 发布证书需单独接入，不能将
本密钥用于替代这些平台的正式证书。

## 备份位置（仅当前开发环境，绝不提交）

- `/home/dev/.local/share/valhalla-signing/android-release.p12`：加密私钥库。
- 同目录 `android-release.password`：随机生成的密码，只通过安全渠道备份。
- 同目录 `android-release-certificate.pem`：公开证书，可用于身份校验。

目录权限 0700，文件权限 0600。请把 keystore 和密码分别备份到受保护的持久
存储；当前环境是容器，不可将它作为唯一长期备份。GitHub Secrets 无法从
网页恢复私钥明文。不要将密码、私钥上传到 Releases、聊天、日志或源码。
后续复用现有密钥，不覆盖或重新随机生成；丢失私钥可能导致无法更新已经
分发的 APK。切换到 Play App Signing 时另行规划上传密钥和应用签名密钥。

## GitHub 自动构建

私有仓库 `NornsInteractive/valhalla` 配置四个 Secrets，值不写入文档：

- `ANDROID_KEYSTORE_BASE64`：PKCS12 内容的 Base64 编码（编码不是加密）。
- `ANDROID_KEYSTORE_PASSWORD`：私钥库密码。
- `ANDROID_KEY_ALIAS`：`valhalla`。
- `ANDROID_KEY_PASSWORD`：私钥密码。

Actions 仅 Android job 从 Secrets 解码到 `RUNNER_TEMP`，通过环境变量传给
Gradle。缺失凭据时失败，不悄悄退回 debug 签名。上传包只选应用和 BUILD-INFO，
不包含私钥；always cleanup 清理明确的临时密钥文件。
打包时 apksigner 校验所有 APK，jarsigner 校验 AAB，并分别比较证书 SHA256
是否与配置的私钥库公开证书一致。自签名证书不依赖系统 CA 信任链。

新产物名为 `valhalla-android-<ABI>-signed-<运行编号>.apk` 和
`valhalla-android-signed-<运行编号>.aab`，均有 SHA256，BUILD-INFO 记录公开
证书指纹。AAB 不是直接安装包，提交 Play 仍需开发者账号与 Play App Signing。

## 本地与兼容性

Gradle 接收 `VALHALLA_ANDROID_KEYSTORE`、`VALHALLA_ANDROID_STORE_PASSWORD`、
`VALHALLA_ANDROID_KEY_ALIAS`、`VALHALLA_ANDROID_KEY_PASSWORD`。若只提供部分
发布配置则失败。明确 `VALHALLA_CI_UNSIGNED=true` 可编译未签名包，但不能与
发布签名同时启用。没有设置这两类配置时，保持原先本地 debug-key Release
开发行为，避免意外更换 ADB 测试签名。

**新发布签名与已安装的 debug 包不兼容。** 不自动卸载或清除用户数据来安装。
请先设计/验证备份与迁移，再由用户决定如何从测试安装迁移；后续同一发布
密钥签名的包可持续更新。不要将 debug 密钥当作正式发布密钥。

## 验证状态

密钥生成和 Secrets 配置属于 root 的部署步骤。签名构建、证书身份、归档
完整性与工作流检查由原 OpenCode 会话、`opencode/mimo-v2.6-flash-free` 完成。
签名版构建尚待核验，不把未运行的签名包标记为通过；不执行 ADB 替换安装。

参考：[Android 官方签名说明](https://developer.android.com/studio/publish/app-signing)、
[Flutter Android 发布指南](https://docs.flutter.dev/deployment/android)。
