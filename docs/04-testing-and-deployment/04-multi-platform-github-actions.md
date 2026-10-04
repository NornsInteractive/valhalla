# 多平台自动构建与 Releases

更新：用户随后要求生成签名，Android 已接入固定发布密钥与 GitHub Secrets，
新工作流产物改为 `android-signed`。Apple 仍无正式发布签名，其他平台边界
不变。详见 [Android 签名指南](05-android-release-signing.md)；下方未签名方案
和前两轮验证记录是本次改动之前的历史依据，不代表新的 Android 包未签名。

## 范围与产物

复用现有 [`windows-build.yml`](../../.github/workflows/windows-build.yml)，显示名称
**Multi-platform Build**，不新增另一套重复流水线。Flutter 固定官方 `3.38.1`
stable / Dart `3.10`，严格使用 `pubspec.lock`，不自动升级依赖。
UI、ARB 与业务行为不在本次改动范围；测试、构建和产物核验全部交给 OpenCode。
用户确认先做未签名自动构建，之后再接入正式签名。

先执行 `flutter pub get --enforce-lockfile`，Release 构建保留 Flutter 默认的
插件注册生成步骤，构建后检查 pubspec 与 lockfile 未改变。不能对 Android
Release 盲目加 `--no-pub`：它会跳过平台注册代码重建，把 dev-only 的
`integration_test` 留在 Java registrant 中，但 Gradle Release 不包含该插件，
因此编译失败。不手改生成代码、不把集成测试插件移到生产依赖。

| 平台 | Runner | 产物 | 安装与运行边界 |
| --- | --- | --- | --- |
| Android | ubuntu-24.04 / Java 17 | armv7、arm64、x86_64 发布签名 APK；签名 AAB | APK 可安装但不能更新 debug 签名包；AAB 发布仍需 Play 配置 |
| Windows | windows-2022 | x64 完整便携 ZIP | 完整解压；需要 Visual C++ x64 运行库；未做发布者签名 |
| Linux | ubuntu-24.04 | x64 完整 bundle tar.gz | 保留 lib/data 和可执行权限；目标系统需要 GTK 3、libsecret、libmpv；不保证兼容所有发行版 |
| macOS | macos-15-intel | x64 + arm64 universal 未签名 .app ZIP | 无 Developer ID 签名或公证；不能当作已经可安全分发的正式包 |
| iOS | macos-15-intel | arm64 未签名 Runner.app ZIP | 最低 iOS 14；编译产物，不是可安装 IPA；仍需证书、描述文件与导出签名 |

目前没有 Web 工程，SSH、FFI 和文件能力大量依赖原生 I/O，所以本工作流不宣称
支持 Web。新增 Web 是独立的平台适配任务，不是加一条构建命令。

每个产物有 SHA256；各平台的 BUILD-INFO 记录版本、源码提交、运行编号、UTC
时间、Flutter 版本和签名边界。Apple 用 `ditto` 打包完整 app，Linux 用 tar
保留权限与链接，Windows 保留所有 DLL 和 data，而不是仅上传可执行文件。

## 自动触发与下载

推送到 `main`，改动涉及 `lib/`、五个平台工程、`packages/`、`assets/`、锁文件、
构建配置或此工作流时，自动编译全部平台。仅改文档不触发。
也可以在 [Actions 页面](https://github.com/NornsInteractive/valhalla/actions/workflows/windows-build.yml)
选择 **Multi-platform Build → Run workflow → main**。

```bash
gh workflow run windows-build.yml --repo NornsInteractive/valhalla --ref main
gh run list --repo NornsInteractive/valhalla --workflow windows-build.yml --limit 5
gh run watch <运行ID> --repo NornsInteractive/valhalla --exit-status
gh run download <运行ID> --repo NornsInteractive/valhalla --dir ./packages
```

普通分支/手动构建只生成 **Artifacts**，保留 14 天。应用包位于 Artifact 内；
不要将 GitHub 的 Source code ZIP 当作应用包。私有仓库需要访问权限，Actions
使用仓库现有额度；额度不足不自动开启付费或提高预算。

## 自动发布到 Releases

1. 确定新版本并修改 `pubspec.yaml`，例如 `1.0.1+2`（示例，不自动修改版本）。
2. 经 OpenCode 验证后提交源码到 `main`。
3. 给该提交创建与版本一致的**新标签**，版本比较忽略 `+构建号`：

   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. 所有平台构建、静态分析、逻辑测试和打包校验成功后，发布任务下载同次运行
   的五个平台产物，再复验 SHA256，创建 [Release](https://github.com/NornsInteractive/valhalla/releases)。
   有任一平台失败就不发布不完整版本；其他平台仍继续构建供诊断下载。

版本标签不匹配源码版本会在前置检查失败。普通分支新构建取消旧构建，标签构建
不自动中断。预发布版本标记 prerelease；发布只给 Release job `contents: write`，
其他任务只读，Actions 固定提交 SHA。不需要长期发布 Token。
不覆盖、删除已有版本或资产，修复后应验证并使用新版本。

已有 `v1.0.0` 保持原验证提交与 Windows 资产，不将不同提交的新平台包塞入旧版本。
工作流完成并不代表已经发布新的多平台版本；以对应运行和 Releases Assets 为准。

## 初始未签名实现（Android 已由后续签名方案取代）

Android 仅在 CI 设置 `VALHALLA_CI_UNSIGNED=true`，让 release 的 signingConfig
为空；本地未设置时继续原有 debug-key 构建方式，不更换现有 ADB 应用密钥。
CI 验证 APK 未通过 apksigner 签名校验，AAB 无签名条目；发布描述明确标注未签名。
macOS 使用 `flutter build macos`，通过 Flutter 支持的 `FLUTTER_XCODE_*` 环境
变量向 Xcode 传递禁用签名、双架构与 `ONLY_ACTIVE_ARCH=NO`，
打包前验证两个架构；iOS 使用 `--no-codesign` 并验证 arm64。Apple 构建在 macOS
Runner 上由 Flutter 配置 CocoaPods；不在 Linux 上伪造 Apple 验证。
Apple linker 可能给 arm64 二进制附加 ad-hoc 完整性签名，这不等于 Apple
发布者签名或签名分发。打包门禁拒绝 Authority / TeamIdentifier，允许没有
发布身份的 ad-hoc 签名，并记录签名诊断；不将 codesign 校验能通过等同于
有证书、可安装或已经公证。

正式 Android 签名需固定 keystore、alias 和密码，通过 GitHub Secrets 注入临时
文件并配置 Gradle，不提交私钥，不用每次随机产生的 CI debug key 分发更新。
Apple 正式签名需证书、描述文件和相应 Apple 账号权限；macOS 分发还需要公证。
相关凭据不要贴到聊天或仓库，后续经用户确认单独接入。

## 验证记录

OpenCode（原会话，`opencode/mimo-v2.6-flash-free`）已通过 actionlint、静态分析
与本地逻辑测试（1881 通过 / 18 跳过）。首轮五平台运行
[`37182300368`](https://github.com/NornsInteractive/valhalla/actions/runs/37182300368)
对应提交 `cf7454d`；iOS 因现有 `file_picker_darwin` 要求至少 iOS 14 而工程仍是
iOS 13 失败。已将 Xcode 目标和 AppFrameworkInfo 的最低版本对齐为 14，不降级
依赖、不跳过编译错误。

第二轮 [`37182694881`](https://github.com/NornsInteractive/valhalla/actions/runs/37182694881)
对应 `4ce178d`：Windows、Linux 编译/打包/上传成功；iOS 编译成功（Xcode 266s），
macOS 编译成功（115.6MB app），两者在 `lipo -verify_arch` 校验阶段因参数顺序
失败。已按实际工具 usage 修正为 `lipo <input_file> -verify_arch <arch...>`，
保留架构校验，不绕过门禁。Android 此轮 APK/AAB 亦编译、校验、上传成功，
之后在收尾阶段被新提交取消；整个运行不能标记为成功。
本地 Android 三架构 APK、AAB 均编译成功，apksigner 校验/签名条目检查确认
没有签名，归档完整性通过；本地 Linux 干净构建亦成功。清理了 Linux Release
旧的生成缓存（错误安装前缀 `/usr/local`，可重新生成），未改源码安装路径。

第三轮 [`37183446978`](https://github.com/NornsInteractive/valhalla/actions/runs/37183446978)
对应 `4b3a2f678014162a1bc9e7597468b24612fed329`，五个平台的完整构建、归档
与上传任务均成功，普通 main 推送的 Release job 按设计跳过。它证明原未签名
流水线可用；新 Android 发布签名提交仍须另行验证，不能复用此运行当签名证明。

首个 Windows 成功记录仍见
[Windows 指南](03-windows-github-actions.md)。不将未运行平台标记为通过。
跨平台业务功能、真实服务器、NAS 播放与移动设备行为另行验收。
