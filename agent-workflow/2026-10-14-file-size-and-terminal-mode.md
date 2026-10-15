# 文件名后显示大小与终端模式入口迁移

## 用户请求与范围

- 远程文件列表：文件大小移到文件名同一行之后，留约 12dp 间距。
  保持整行对齐、单行时间、更多按钮位置；不修改网格或图库。
- SSH 终端：普通 SSH／tmux 的新建模式设置从设置页移到终端页。
  默认普通 SSH，沿用原持久化键及 notifier，只影响之后新建的终端。
  不重建、关闭或修改已有会话，不改变恢复历史的行为。
- 用户随后要求缩短图标与名称间距：仅主文件列表 leadingGap 从默认 16dp
  改为 8dp，仍保留外边距与图标位置，不改变右侧 trailingGap 4dp 或
  名称与大小的 12dp 间距；共享目录选择器沿用默认。
- 普通 SSH 网络重连后自动建立新 shell，保留本地 Terminal 和旧输出，
  不再产生普通 shell 的无法恢复提示。旧进程不宣称恢复；tmux 精确附着
  与丢失会话检查不变。含 launchCommand／remoteExecCommand 的 CLI／登录
  终端仍禁止自动重放命令，防止网络恢复触发重复操作。
- 展示仍由原 AgY Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`
  使用 Gemini 3.8 Flash／high 修改；验证交 OpenCode。
- 本次没有新增打包、安装、推送或发布授权。上一条交付的正式 APK 不包含
  本文后续修改，不能将其作为本次新 UI 的实机证据。

## 实施边界

文件列表仅增加共享 tile 的可选 `titleSuffix`，仅 list 分支使用，默认 null。
主文件列表只对非目录／非特殊导航项提供大小，使用次要色 mono11；文件
副标题移除重复大小，目录保留原字段。长名可省略，保持大小与名称同排。
大字号无法容纳完整时间时，仍仅副标题横向滚动。

终端入口迁移仅涉及 `terminal_view.dart` 和 `settings_view.dart`。已有模式
弹窗搬迁，保留保存中的禁用、失败提示、取消、mounted／route 存活检查，
沿用 `terminalSettingsProvider.notifier.setUseTmux`，不改 provider 或存储。
打开设置前收起输入焦点，避免关闭弹窗时自动弹出键盘。

## 验证状态

文件列表 UI 与终端入口迁移已由 AgY 修改，主代理已只读复核改动范围。
图标间距追加调整已写入，AgY 已完成四个 UI 文件格式收尾。普通 SSH 重连守卫已在
`terminal_session_bridge.dart` 收窄；服务器连接原有恢复回调接回同一 tab，
不另建 tab、不清回滚缓冲、不回放用户命令。
OpenCode MiMo 免费模型成本已从本机目录核验为 0，受限任务只允许读取相关
源码／测试、修改对应测试和执行指定格式／测试／分析，不可读取登录或签名
凭据，不可修改 UI、打包、安装或上传。MiMo 180s 与 Big Pickle 120s
均无输出，退出 124；免费 Nemotron 已实际执行分析，零问题、退出 0。
其随后编写核心重连回归时读完文件后挂起，240s 退出 124，未写入回归；
早期新行为对应旧的“不得重建普通 shell”测试未更新，不能以那些尝试宣称通过。

## 最终验证（用户授权本轮主代理直接完成）

用户明确回复“允许本轮你直接完成验证”。主代理停止本轮自己的 OpenCode
验证进程，没有操作其他项目进程；补齐模式入口迁移、普通重连与文件布局测试。
没有修改 AgY 的 UI 实现，没有沿用以前轮次的直接验证例外。

最终执行：

```sh
flutter test --no-pub \
  test/features/sftp_file_view_test.dart \
  test/features/remote_browser_dialog_test.dart \
  test/features/settings_terminal_tmux_test.dart \
  test/features/terminal_toolbar_actions_test.dart \
  test/features/terminal_ime_intent_test.dart \
  test/infrastructure/terminal_rebind_resilience_test.dart \
  test/infrastructure/terminal_tmux_test.dart \
  test/core/terminal_settings_provider_test.dart \
  test/core/terminal_history_provider_test.dart --reporter expanded
flutter analyze --no-pub
git diff --check
```

- 相关回归 **228 通过／0 失败**，命令退出 0；不是全项目全量或 ADB 验收。
- 最终静态分析 **No issues found**，退出 0；补充测试的格式与差异检查通过。
- 主文件列表 320／390dp、1.0／1.3／2.0 字号，短名及长名：文件大小只显示
  一次，与名称同排且相隔 12dp；标题相对行左边距为 56dp，比前一方案靠近
  图标 8dp。隐藏文件大小维持淡色，目录及共享选择器既有行为保留。
- 原完整分钟字形／单行断言保留；只有极大字号实际存在副标题横向滚动时，
  先滚动再检查分钟字形可达。不删除断言或将正常字号改成需要滚动。
- 设置页不再出现模式入口；SSH 页入口的中英文、取消、保存失败及真实偏好
  写入通过；更改模式保持当前 tab／Terminal／输出，不触发键盘误弹。
- 普通 SSH 建立新 shell，保留旧输出，同客户端不重复分配；旧输入／resize
  回调不能影响旧／新会话。tmux 精确恢复、关闭客户端、超时资源释放的原
  测试仍通过；CLI launch 的启动命令不在重连时重复执行。

最终日志：`root-final-regression.log`、`root-final-analyze.log`，均位于下方
证据目录。早期 OpenCode 的语法错误／未执行命令不是最终通过证据。
以上验证结束时未打包、安装、推送、发布；没有实体网络断开或 Gboard 的 ADB 验收。

证据目录：`/tmp/valhalla-filename-size.jPJ8B2`；不能用上一轮的分析／编译结果
代替本轮验证。

## 用户追加正式打包，不推送（已完成）

用户随后明确要求主代理直接打正式包。仅生成 Android 通用正式签名 APK，
版本保持 `1.0.6+7`、包名 `com.norns.valhalla`，沿用原证书；不生成其他平台
或 AAB，不安装、不提交、推送、上传 GitHub Release／分发平台或启动 Actions。
独立产物目录保留之前已交付的 APK，不用旧包代替新编译结果。

- 命令：`flutter build apk --release --target lib/main.dart`，通过未入库的本地受控
  构建脚本读取本地签名配置，密码不进入工具输出；发布注册器正常重生成。
- 时间：2026-10-14 12:52:55–12:54:08 UTC，编译退出码 0。
- APK：`build/local-packages/release-1.0.6.uTep4X/Valhalla-1.0.6+7-android-universal-signed.apk`。
- 大小：141935500 字节；包含 armeabi-v7a、arm64-v8a、x86_64。
- SHA-256：`0e860d2d84e1b45744eb183ad2cb3f2592346c48783c09f559bc904ae2ae2015`。
- 原正式证书 SHA-256：`73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`。
- 签名、包名／版本、ZIP 完整性、构建前源码哈希核对均通过。
- APK 内 ARM64 `libapp.so` SHA-256 为
  `002755aa95d849a8f320780e972df83dafbb52efe0b33160cc9b88e1cd8f24f3`，与之前
  正式包的 `73f6deebb73105ab36ed6183d81e4329b81134ea4adf96d10d4b5c45cf150b9a`
  不同，确认应用编译内容已改变，不只是重复签名旧包。

构建日志、时间、退出码、SHA256SUMS、证书及源码检查记录位于上述产物目录，
目录由 git 忽略。包含本轮文件布局、终端模式入口及普通 SSH 重连改动；
未做新 APK 的实机验收，新包名也不自动承接旧包名的私有数据。
