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
完整性与工作流检查由原 OpenCode 会话完成。MiMo Free 持续限流后，按用户
此前授权改用 `opencode/space-bunny-free`，主/辅助模型均固定该免费模型；
本机 input/output/cache 计价为 0，官方 Zen 目录亦确认免费。

actionlint 通过，本地发布签名的三架构 APK 和 AAB 编译均 exit 0；APK 的
apksigner 验证通过，三份 APK 和 AAB 的证书指纹均与生成的私钥库/公开证书
匹配：

```text
73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d
```

公开证书 SHA256 指纹不是私钥，可用于以后核验应用签名。保留原 universal
debug-key Release APK 及 `.bak-*`；未执行 ADB 替换安装。
实际 CI [`37184283762`](https://github.com/NornsInteractive/valhalla/actions/runs/37184283762)
对应 `e165d4eef05d5febdf807ea26388d7cae8947258`：五平台编译成功，但 Android
证书解析门禁失败。CI 新 build-tools 输出 `V2 Signer: certificate SHA-256
digest: ...`，本地版本输出 `Signer #1 certificate SHA-256 digest: ...`；两者
实际指纹一致，原脚本仅匹配旧前缀导致误判。已改为提取严格 64 位证书 SHA256，
兼容前缀、CRLF、重复签名方案输出，去重后仍严格比较期望指纹；不跳过签名
验证，不接受多份不同证书或无法提取的输出。不以此前未签名 CI 成功作为
新签名流水线证明；修复后的实际验证结果如下。

OpenCode / Space Bunny Free 对修复执行 actionlint（exit 0）、9 个解析回归场景
（旧/新前缀、CRLF 大写、重复同证书通过；空输出、63 位、错证书、不同双证书、
仅 public-key 指纹拒绝），并对真实 CI 日志和本地三份签名 APK 验证新解析器，
均符合预期。未改依赖与锁文件，新增私钥库扩展名 gitignore 防止误提交。

### 正式签名流水线与下载包验收

2026-10-04 实际运行
[`37185136227`](https://github.com/NornsInteractive/valhalla/actions/runs/37185136227)
（运行编号 8，源码 `174884275a8467ff7efc21a9329916540b685af4`）已完成并成功。
Windows、Linux、macOS、iOS、Android 五个平台均完成编译、打包、校验和上传。
普通 main 推送不发布 Release，发布任务按设计跳过；没有修改已有 v1.0.0。

OpenCode 原会话使用已获授权的免费模型 `opencode/space-bunny-free`，下载
Android Artifact `valhalla-android-signed-8`（ID `11296722973`，135903756 字节）
到 `/tmp/opencode/android-signed-CI37185136227` 后完成独立验收：

- armv7、arm64、x86_64 三份 APK：apksigner 验证和 ZIP 完整性均 exit 0；
  全部证书 SHA256 与上面的固定发布证书一致。
- AAB：jarsigner 验证、ZIP 完整性均 exit 0；从归档签名证书提取的 SHA256
  与固定证书一致。它不是直接可安装的 APK。
- 三份 APK、AAB、BUILD-INFO 的五份 SHA256 sidecar：严格校验全部通过。
- BUILD-INFO：版本 `1.0.0+1`、完整源码提交、运行编号、公开证书指纹均匹配；
  构建时间为 `2026-10-04T07:25:00Z`。
- 产物不含私钥库或密码文件；未执行 ADB 安装、卸载或清除应用数据。

可在该运行页面下载 Artifact（保留 14 天），或执行：

```bash
gh run download 37185136227 --repo NornsInteractive/valhalla \
  --name valhalla-android-signed-8 --dir ./android-signed-8
```

该记录证明固定 Android 签名与自动构建可用，不表示 Apple / Windows 已获得
正式发布者签名，也不代表所有跨平台业务或真机迁移已完成验收。

参考：[Android 官方签名说明](https://developer.android.com/studio/publish/app-signing)、
[Flutter Android 发布指南](https://docs.flutter.dev/deployment/android)。
