# Valhalla - 实施状态与工程基线

## 2026-09-29 仓库同步、OpenCode 验证与模拟器安装

- 已快进同步 GitHub `main` 至 `916082f`。本轮验证由 OpenCode CLI 显式选用 `opencode/mimo-v2.6-flash-free` 执行，未把其他模型的结果计入本轮门禁。
- 本机 Flutter SDK 对 `intl` 固定为 `0.20.2`；上游的 `0.20.3` 导致 `flutter pub get` 无法解析，故将依赖与锁文件调整到本机 SDK 可用版本。
- `flutter test --no-pub`：1154 项通过、17 项隔离 VM/设备前置条件用例跳过；`flutter analyze --no-pub` 无问题；`flutter build apk --debug --no-pub` 成功。APK 为 `build/app/outputs/flutter-apk/app-debug.apk`，232201539 字节，SHA-256 `8b9655e65b95f4fb851787954460573d03ee8a92654c9ddc5ad1e0c07678b3ac`。
- OpenCode 对模拟器 `127.0.0.1:14251` 执行 `adb install -r` 返回 `Success`，触发应用启动后 `pidof com.antigravity.valhalla.valhalla` 返回 `23762`。前台截图显示容器管理的服务器离线状态已正常渲染，原有服务器记录仍在。覆盖安装保留原应用数据；这不代表 SSH/NAS/Agent 的端到端验收。
- 格式检查发现上游 31 个 Dart 文件不符合当前格式器输出；本轮没有批量格式化展示层文件。物理 Android 设备性能和真实服务器功能仍未验证。

## 2026-09-23 本轮稳定性修复与已列范围验收完成

本节记录本轮稳定性修复与已列范围的完成结果，保留未实现功能和外部未验边界，不代表全功能发布就绪。下文 NAS 媒体库及更早记录保留为历史证据，不能代替本轮验收。

- 已修复 SSH 超时/取消/连接身份与指纹兼容、SFTP 预览大小及句柄清理、Docker 日志取消、systemd 状态解析、终端分包中文与关闭后进程释放；NAS 部署增加持久任务、阶段时限、脱敏进度、取消/回滚和恢复核验。WebDAV 使用 canonical `repository@digest`，并修复 gzip 压缩 XML 扫描失败；快捷命令补齐凭据/SSH 异常、目标身份检查、双流输出和 loading 收尾。
- NAS 冷启动时元数据服务先于自动 SSH 连接初始化，适配器缓存首次连接错误，重连后也可能保留旧隧道；已改为按媒体源自身 `sshServerId` 的客户端身份失效重建。新增 4 项回归，与关联用例合计 13 项通过，覆盖源不等于活动服务器、断线/重连、同 ID 客户端替换与无关连接不重建。Emby 安装/恢复健康检查改用 `/System/Info/Public`，防止首页 302 时 API 仍为 503 就提前报告成功，2 分钟预算不变。
- 最新源码自动检查：**1111 项测试通过、17 项隔离环境测试默认跳过**；`flutter analyze` 无问题，277 个 Dart 文件格式检查零改动。最新 release APK 为 **120,047,520 字节**，SHA-256 `4d28eab39248ef1a3e5248709f19ab0fd5103878509422d0d17163c1a1222da3`，构建、签名及 `adb install -r` 覆盖安装通过，既有配置保留；08:59:24 UTC 启动 PID 22840。日志为 `test-nas-lifecycle-final.log`、`analyze-nas-lifecycle-final.log`、`format-nas-lifecycle-final.log`，APK 记录为 `apk-release-nas-lifecycle-final.json`。
- 真实一次性 VM：SSH/SFTP 综合回归通过，Docker/系统/PTY/tmux **7/7** 通过，普通终端 dispose 修复前后有对照；实际重启 **1/1** 通过，仅派发一次并验证 boot ID 改变。NAS 原五项通过结果保留；Emby 原健康超时经隔离 VM 内核/模拟 CPU 条件诊断、环境调整及产品 API 就绪修复后，正式 VM 用例 **1/1 通过**，08:52 UTC 完成、耗时 **4 分 37 秒**，日志 `emby-health-api-vm-final.log`。不把分轮结果说成一次六项全量重跑，也不替代 Emby Android 媒体源验收。
- [NAS 各用例最新汇总](../../build/app-stability-validation/nas-vm-final-summary.json) 包含跨多次运行的原六项通过及新增中断拉取只读核验，历史失败记录保留。[09:03:31 UTC 只读资源核验](../../build/app-stability-validation/vm-final-readonly-state.json) 确认三个测试媒体哈希未变、同一 WebDAV 容器运行、boot ID 未变，另保留两个 fixture BusyBox 容器；不等于环境已全部清理。
- 历史 `946aa467…86014a` APK 的设备回归已通过：NAS 真实拉取关闭重开/取消后只读核验正确归为 cancelled、端口错误固定可见、恢复成功任务无回滚误标；WebDAV 扫描 3 项并打开真实图片；快捷命令断线 -1 错误立即可关闭，重连后 stdout/stderr 与退出码 7 同时显示。这些证据不冒充最新包回归；原 `fc8dbf95…` 包手工运行约 65 分钟无新增 FATAL/Unhandled/ANR，也不替代新版自动 soak。
- 最新 `4d28eab…` 包已在 Android 14 x86_64 模拟器验证：已保存 WebDAV 源冷启动自动连接后，未经编辑/保存直接扫描 3 项并显示真实图片；主动断线扫描立即明确报错，重连后无需保存源直接重新扫描 3 项。最终自动 soak 于 **09:01:34 UTC** 启动，完成 **25 轮、10 个路由共 250 次入口检查、1817 秒（30 分 17 秒）**，PID 22840 始终未变；crash buffer 为空、实时日志无 FATAL/Unhandled、无新增退出或 ANR，已复核为 [passed_observed_scope](../../build/app-stability-validation/soak-final/reviewed-summary.json)。25 次 PSS 为 128101–140244 KiB，末次 132282 KiB，本窗口无持续增长，不等于证明无长期泄漏。旧 `946aa467…` 包 soak 的 **4 轮/308 秒** 是发现 Emby 就绪问题后的主动 SIGINT 中断，不能记为崩溃或最终通过。
- Soak 后再次扫描 WebDAV 3 项成功，PID 仍为 22840；09:33:24 UTC 仅停止自有 ADB 日志采集，应用保持运行，截止时无 FATAL/Unhandled。见 [末次扫描](../../build/app-stability-validation/device/nas-lifecycle-final-after-soak-scan.xml) 和 [结束记录](../../build/app-stability-validation/device/nas-lifecycle-final-release-end.json)。
- 真实 Agent 登录/模型调用、DLNA 实体接收和物理手机性能仍未验，设置空入口等功能缺口保留在验收报告中。仅在隔离 VM 写入，现有服务器配置只做只读检查。

结果、各版本 APK 哈希、实际日志、未验范围和复跑入口见 [App 稳定性验收（2026-09-23）](../04-testing-and-deployment/04-app-stability-acceptance-2026-09-23.md)。

## 2026-09-23 NAS 多来源媒体库（实现与阶段验证）

本节记录本轮 NAS 当前源码和已确认的验证结果，覆盖下文早期 NAS 设计中的待接入方案。非 NAS 历史记录保持原样；本轮尚未宣称整个应用发布就绪。

- 媒体源以独立 ID 管理，选择不依附仪表盘的活动 SSH 服务器。已接入 SFTP、WebDAV / HTTP(S) 原文件、成熟 `libsmb2` 原生封装、Jellyfin 和 Emby；密码 / token 存在安全存储，列表、收藏、播放和下载捕获各自来源。
- 本地 SQLite 索引采用后台 isolate、WAL 与串行事务写入。扫描按代次分批 upsert，只有成功结束才清理未见条目；取消不会误删旧库。浏览按修改时间 / 路径游标分页，分类 / 目录 / 歌手 / 专辑及总量从数据库查询，FTS5 使用 token 前缀搜索。本地与远程播放列表均展示真实成员并支持增删改排。
- 文件型媒体库的未播放音频由暂停、静音 libmpv 后台任务提取标签，每批最多 32 首、每文件最多 3 MiB 上游读取；失败记次、变更后重探测、断线保留待处理队列。生命周期进入后台时取消探测，已保存标签保留；Jellyfin / Emby 使用服务端元数据。
- 普通资源经受限 Range 代理播放，HLS master / variant / 分片通过同源安全中继；媒体凭据不放进交给播放器或电视的明文 URL。用户播放由一套 `media_kit` 播放器与有界队列管理，系统控制桥接同一队列；支持进度、重复、窗口内随机、倍速、音轨 / 字幕及服务端画质。
- DLNA 复用 `upnp_client`，显式投屏时才建立可撤销的局域网中继。下载复用统一来源读取器、两路并发和 `.part` 成功重命名，支持取消、重试与本地文件系统打开；当前不承诺跨进程断点续传。
- 可选部署向导提供固定镜像 / digest、路径 / 端口 / 挂载 / Compose 预览和一次性确认，默认远端 loopback、媒体只读挂载。缺 Docker / Compose 时提供指导，不自动装系统依赖、不改防火墙；失败只回滚向导创建并标识的资源。HTTP 来源可显式选用 SSH 转发；隧道不以禁用 TLS 校验来支持 HTTPS。

已确认的证据：

| 验证项 | 本轮结果与适用边界 |
| --- | --- |
| 最终分析与测试 | `flutter analyze --no-pub` 无问题；全量 **1009 项 Flutter 测试通过**，日志为 `/tmp/valhalla-nas-final-analyze.log`、`/tmp/valhalla-nas-final-tests.log` |
| Android 最终构建 / 安装 | 默认 `lib/main.dart` 的 debug APK 构建成功，`adb install -r` 返回 Success，来源与媒体索引保留；窄屏列表、应用内彩色视频和横屏全屏视频已目视复验，见下方截图链接 |
| Linux | 最后 UI / 许可证改动后的最终 debug 构建通过，产物 `build/linux/x64/debug/bundle/valhalla` 包含 SMB 原生库且 `ldd` 无缺失；此前 Xvfb + session D-Bus 启动和真实隔离 D-Bus 控制回归通过。容器没有 PipeWire 音频输出，未验证实际听音 |
| Android 后台系统控制 | 模拟器在应用后台响应系统 MediaSession 后退 / 播放 / 暂停 / 停止，位置与状态同步；曲目元数据为 `NAS test track / Valhalla / Fixture`，停止后 `active=false`、状态 `NONE`、位置归零。证据 [`android-media-controls.txt`](../../build/nas-validation/android-media-controls.txt)；不代表物理手机、耳机 / 音频焦点或进程被杀后的行为 |
| 模拟器视频黑屏 | 捆绑 libmpv 的 `EGL_CONTEXT_FLAGS_KHR=0` 在当前 Android 14 x86_64 模拟器 EGL 1.4 上返回 `0x3004`，NDK 对照探针去掉属性后成功；仅模拟器采用 `mediacodec_embed` / `mediacodec`，实机及其他平台维持默认配置。共享 controller / UI 整合后的最终 APK 已安装，应用内和横屏全屏彩色视频画面复验通过 |
| 最终许可证产物 | Android APK 与 Linux bundle 的 `NOTICES.Z` 均核验包含完整 `valhalla_smb/NOTICE`、libsmb2 `COPYING` 和 `LICENCE-LGPL-2.1.txt`；[Android 全文 / 哈希证明](../../build/nas-validation/android-lgpl-license-proof.json)、[Linux 全文 / 哈希证明](../../build/nas-validation/linux-lgpl-license-proof.json) 均记录三项 `complete_text_present: true` |
| 签名 SMB2 | Linux 实际 `libvalhalla_smb.so` 与 Android 14 `sdk_gphone64_x86_64` 模拟器通过 2502 文件 / 5 页、Unicode、超过 4 GiB 偏移、取消及重连；不代表真实 SMB3 NAS / 加密服务验收 |
| Jellyfin 12.1 | 真实服务认证、三类扫描、收藏、列表增删改排、12 秒续播、原始 Range、缩略图、4 Mbps PlaybackInfo、HLS master / variant 和实际 MPEG-TS 分片通过；Emby 兼容修复后再次回归通过。重复媒体项返回歧义成员 ID 时拒绝不确定删除 / 排序 |
| Emby 4.10.0.40 | 真实服务认证、三类扫描、收藏、重复列表项独立成员 ID 的移动 / 删除、列表改名 / 删除、12 秒续播、三类原始 Range、缩略图、4 Mbps PlaybackInfo 与 HLS / MPEG-TS 分片通过；实测修复 JSON 显式 Content-Length 和原始播放独立 PlaySessionId / DirectPlay 报告，相关 network / HLS / cast / source-review **30 项通过**，静态分析无问题 |
| 百万条合成索引 | 当前最终 schema（含元数据队列索引）重跑通过：Linux x64 / Dart 3.10.0 / 16 逻辑处理器，100 万条、每批 5000、各查询 20 次：首页 P95 **2.352 ms**，95% 深页 **1.662 ms**，稀有 / 常见 token 前缀 **111.497 / 143.518 ms**，总量 **107.055 ms**；写入 90.905 秒，数据库 1,345,769,472 字节，采样 RSS 峰值 278,683,648 字节。不代表真实 NAS 扫描、冷缓存或手机帧率 |
| 自动化边界 | 索引迁移 / 取消、元数据预算、代理 / HLS / 投屏 / 下载、SSH 隧道及安装预览 / 确认 / 冲突 / 回滚已有回归；向导未在用户目标服务器真实执行部署 |

Android 已连接的设备是宿主机端口 14251 对应的 **Android 模拟器，不是物理手机**。完整 NAS integration 测试已通过，日志 `/tmp/valhalla-nas-device-test.log` 包含 `NAS_DEVICE_PASS` 和 `All tests passed!`：覆盖原图 / 512 缩略图、视频跳转与 `Media.start` 续播、1.5 倍速、MP3 标签、收藏 / 播放列表 CRUD、切换媒体源后保留原播放身份及原文件下载大小。删除测试来源曾触发的 Riverpod `CircularDependencyError` 已修复，4 项专项回归及修复后完整设备流程均通过。后台系统控制实测范围见上表；最终 APK 另已取得 [窄屏列表](../../build/nas-validation/09-final-library.png)、[应用内彩色视频](../../build/nas-validation/10-final-video.png) 和 [横屏全屏视频](../../build/nas-validation/11-final-video-fullscreen.png) 的实际画面证明。上述结果不等于物理手机或所有平台验收。

最终 APK 人工复验已完成：原图实际显示；从媒体库设置进入并保存 WebDAV 扫描范围无需 SSH；歌手 Valhalla、专辑 Fixture 下钻显示对应曲目，目录下钻显示三类媒体；播放器全屏、收起后重新打开及从后台返回后均正常出画。截图 `12-final-video-resumed.png` 至 `17-final-folder.png` 保存在本轮 `build/nas-validation/`。最终应用进程日志未发现未处理异常、RenderFlex 溢出或 EGL / 视频输出初始化失败；不据此声称全部设备与编码兼容。

验收结束已从应用移除本轮 `NASFixture` 测试来源，停止临时媒体服务并清理已确认属于本轮的调试转发；正常 APK 保留安装。设备截图后仅对扫描服务执行纯格式整理，无行为改动；格式检查通过（261 文件零差异），Android / Linux 重新构建并再次覆盖安装成功。最终分析、1009 项测试、格式检查、双平台构建、安装、设备集成和百万条基准日志已复制到本环境 `build/nas-validation/`，这些构建产物不作为源码提交。

视频兼容实现位于 [`nasVideoConfiguration()`](../../lib/core/services/nas_media_player_service.dart) 与 [`nasVideoControllerProvider`](../../lib/core/providers/nas_provider.dart)：复用 `Utils.IsEmulator`，共享播放器生命周期内的同一视频 controller，fatal / 视频输出错误转为 `NAS_PLAYBACK_FAILED`。本轮 [EGL 探针](../../build/nas-validation/android-egl-flags-proof.txt)、[原生失败日志](../../build/nas-validation/android-video-black-screen-proof.txt) 与 [同 APK 彩色画面证明](../../build/nas-validation/video-native-output-proof.png) 支持上述模拟器处理；最后一项只证明输出路径，不代表最终布局。模拟器原生 codec 的格式支持有限，未改变实机默认配置，也未验证实机或 Apple / Windows 视频。上游同类现象可查 [media-kit issue #1343](https://github.com/media-kit/media-kit/issues/1343)，具体 EGL 属性根因来自本轮独立探针。`build/nas-validation` 证据是本地构建产物，不是永久附件。

Flutter integration runner 的 `kill()` 清理路径会卸载应用包，测试来源不会持久到随后正常安装的应用；本轮设备初始没有本应用，没有用户数据丢失。**只能在无用户数据的专用测试模拟器运行集成测试，禁止在有用户数据的设备执行 `flutter test integration_test/...`。** 正常安装应重新构建应用入口并用 `adb install -r`；可重放的 fixture、地址与命令见架构文档中的“Android 集成测试重放与数据边界”。

Apple / Windows 没有本机工具链，未做原生构建与实机验收；未连接真实 DLNA 电视，不能声称物理投屏兼容性已通过。

详细数据流、可复现基准入口和限制见 [NAS 媒体库与流播放架构](../02-architecture/04-nas-streaming-architecture.md)。本轮原始记录包括最终基准 `/tmp/valhalla-nas-index-benchmark-final.json` 及同名 `.log`、保留的旧报告 `/tmp/valhalla-nas-index-benchmark.json`、`/tmp/valhalla-nas-device-test.log`、最终分析 / 测试日志 `/tmp/valhalla-nas-final-analyze.log` 与 `/tmp/valhalla-nas-final-tests.log`、最终构建 / 安装日志 `/tmp/valhalla-nas-final-android-build.log`、`/tmp/valhalla-nas-final-install.log`、`/tmp/valhalla-nas-linux-build.log`，以及 `/tmp/valhalla-nas-media-servers` 中的真实媒体服务烟测脚本。最终 APK SHA-256 为 `a8a7ddd3d7d00b34c6b38fdb08834db799a49a83417aa38e51f5e04ea57b0c19`，与 Android 许可证产物证明一致；这些日志、证明及截图均为当前环境产物，不是可跨机器访问的永久仓库附件。

## 2026-09-22 全量审计与稳定性修复

- 修复 ACP `session/request_permission` 回包形状：`result` 直接包含
  `outcome` / `optionId`，不再错误嵌套为 `result.outcome.outcome`；Codex
  审批允许后的 JSON-RPC Parse error 已有 wire 回归测试覆盖。
- Docker Agent 执行目标统一通过容器内 `/bin/sh -lc` 启动，并在容器存在 Bash
  时优先使用 `/bin/bash -ic`，Bash 不存在时回退到 sh；诊断日志同时保留目标、
  脱敏后的 transport command、退出码和输出尾部。
- NAS repository 在 provider 与媒体播放器之间复用同一初始化入口，SQLite WAL
  写入继续串行化；新增服务器隔离的播放列表 CRUD、播放列表条目和播放进度节流。
- NAS 扫描在 GNU `find -printf` 不可用时尝试 GNU/BSD `stat` 格式，并返回稳定的
  `NAS_SCAN_UNSUPPORTED_FIND_FORMAT` 错误分类。
- 日志脱敏补充 JSON 字段、Bearer、cookie 和 `--token=value` 等常见凭据形式。
- 指定 Valhalla `agy` 会话完成 UI 文案恢复、仪表盘参数顺序修复、CLI/ACP 消息
  文本选择复制；相关 70 项 Widget 测试通过。
- 门禁结果：全量 Flutter 测试 0 errors，`flutter analyze --no-pub` 通过，格式与
  `git diff --check` 通过；release APK 已构建成功。真实 SSH/Codex/Docker/NAS
  设备验收仍需在目标服务器执行。

## 2026-09-21 会话启动偏好与 NAS 流媒体基础

- 会话启动偏好已新增为服务器、会话模式（ACP/CLI）及 Agent 三元组的持久化数据：支持记住最后会话、固定会话和空白草稿；会话失效或删除时安全回退到草稿，绝不为打开页面而创建远端会话。
- NAS 索引以兼容迁移扩展播放进度、收藏、媒体元数据与播放列表表；SFTP loopback 媒体代理只绑定 `127.0.0.1`、使用随机临时令牌并支持单 Range/HEAD，使播放器可拖动和在完整下载前开始读取远端文件。
- 引入统一的 `media_kit` 音视频播放基础和 Android/iOS 后台媒体平台声明；外部打开仍复用已有下载队列和系统 chooser。音乐通知/锁屏状态桥接以及真实设备兼容性仍需本迭代最终验证。
- Codex CLI Composer 使用官方 app-server `skills/list` 获取真实 Skill，不把仅能被 Codex TUI 解释的斜杠命令伪装为可执行项；Catalog 失败不得阻断聊天发送。

## 2026-09-20 CLI 会话长历史修复

- 历史消息从“全量传回后本地截取”改为远端分页：Codex 使用官方 items 游标，OpenCode 使用消息 limit/before，Claude Code 使用远端 SDK 窗口投影。旧版不支持分页时不回退全量读取；Claude Code 的远端扫描耗时仍需实测。
- 修复 Codex 原始 item 页被工具记录占据时只显示一条且无法触发滚动的问题：连续读取小页直到取得目标数量的可见消息。会话目录首屏从 30 条降到 15 条，并在切回 Agent 时复用已取得的目录缓存。
- 当前主机仅执行只读 `thread/list` 验证（未读取正文、未启动 / 发送 / 删除会话）：10 / 20 / 30 条首页约 1.4–3.1 秒且均有下一页，证明主要耗时来自 Codex 历史扫描。相关 14 项协议 / 状态测试与静态分析通过，debug 和 release APK 均重新构建成功。
- Agent 切换保持移动端会话抽屉打开；展示层由指定 Valhalla `agy` 会话负责。专项 49 项测试通过、相关静态分析无问题、`flutter build apk --debug --no-pub` 成功；Android 真机长历史流畅度仍待 profile 实测。全量测试另有 1 项与本功能无关的既有失败：`multi_column_lists_test.dart` 的紧凑 Agent 管理列表测试在未滚动时查找尚未构建的 `Agent 2`，单独复跑同样失败，本轮未扩展范围修改该测试。

## 2026-09-19 主题、终端与仪表盘体验完善

- 共享终端画布已移除长按方向键微滑，保留 xterm 原生长按及辅助键栏；设置页单选项改为弹窗，浅色/深色/极客黑暗各自保存预设或自选主题色。跟随系统使用系统明暗对应槽位，旧单色设置保留回退。
- 仪表盘运行时间已移入服务器信息卡，重启/关机/断开连接集中在服务器名称旁；关机复用捕获服务器与临时 sudo 密码的安全流程，但不伪装成重启验证。第四指标卡与明细弹窗展示默认路由网卡及各网卡当前收发速率，首采样、计数器回退和无网卡有明确状态。
- 快捷入口已支持独立勾选与拖动排序，空列表隐藏整个区域；升级用户缺键时保持旧六项。展示层、ARB 与 Widget 测试均由指定 Valhalla `agy` 历史会话以 `gemini-3.8-flash-high` / high 完成，后端与文档由 Codex 完成。
- 关机 `unknown` 与 `accepted` 分别显示非断言性文案；离线时 `unknown` 保留警告横幅，sudo 密码提示按关机/重启区分。最终门禁：`flutter test --no-pub --reporter expanded` 全量 **815 项通过**；`flutter analyze --no-pub` 无问题；`dart format --output=none --set-exit-if-changed lib test` 检查 191 个文件无改动；`git diff --check` 通过；`flutter build apk --debug --no-pub` 成功。未在真实服务器执行关机或验证 Android 实机颜色/终端手势，不能把自动化门禁等同于现场验收。
- 详细迁移键与失败状态见 [本轮交接](../handoffs/2026-09-19-theme-network-power-shortcuts.md)。

## 2026-09-19 本轮实施

独立 CLI 原生会话、安全重启、Docker 逐容器等待与切服守卫、真实连接数统计、安全确认、PTY resize 合并 / 生命周期清理与并行 SSH 退出码已完成实现。在此基础上，前端展示层完成以下 7 项关键能力交付：
1. **Docker 容器终端（进入容器）**：在运行中容器操作行提供“进入容器”按钮，通过 `dockerCliServiceProvider.openTerminal` 创建桥接并调用 `bridge.start()`，展示支持自适应（移动端全屏 / 桌面端 900x600 模态）的 `SharedTerminalCanvas`，接入按键直通与剪贴板粘贴；退出时通过 `finally { bridge?.dispose(); }` 安全释放终端 PTY 资源，且不停止容器；非运行容器严格禁用。
2. **CLI / ACP 设为默认 Agent**：在 CLI Agent 选择行与 ACP Agent 切换弹窗中增加“设为默认”星标切换按钮；读取 `localStorageServiceProvider.getDefaultAgentId(serverId, cli: true/false)` 标识默认状态，点击调用对应 `setDefaultAgent(id)`；切换默认不自动跳转或强制改变用户当前活动的 Agent 与会话。
3. **AgentFormDialog 响应式表单重构**：移动端采用全屏对话框 `Dialog.fullscreen` + `Scaffold` + 吸底操作栏；桌面端采用居中模态框（maxWidth: 680, maxHeight: 750）；清晰组织 4 大信息分区（预设模板 ChoiceChips、基本信息、等宽多行命令 1~4 行、等宽多行安装与登录命令 1~3 行），支持预设即时填入与自定义清空校验。
4. **Dashboard 当前资源占用看板**：将旧有趋势折线图全面替换为“当前资源占用”面板；CPU 面板呈现使用率/空闲率/负载与按 CPU 占用降序的实时进程列表；内存面板呈现使用率/空闲率/总量与按 RSS KiB 降序的实时进程列表；磁盘面板呈现已用/可用/总量、扫描未完成黄色警告横幅、一级子目录占用排行与刷新按钮；弹窗随 `autoDispose` 自动卸载，断线展示停止告警。
5. **Settings 底栏导航拖拽排序**：保留 9 个 AppSection 独立勾选能力，下方提供 `ReorderableListView` 拖拽手柄自由排序，勾选自动追加末尾，取消勾选剔除且保留其余顺序；移动端底栏严格依照配置顺序渲染。
6. **语言“跟随系统”（System Default）**：`SettingsState.locale` 缺省设为 `Locale('system')`，`main.dart` 中为 system 时向 `MaterialApp` 传递 `null`，无缝联动宿主系统语言。
7. **L10n 全量覆盖与自动化测试**：完善 `app_en.arb` 和 `app_zh.arb`，通过 `l10n_key_parity_test.dart`，针对 7 项能力编写高覆盖 Widget 测试套件（`dashboard_metric_trends_test.dart`、`docker_terminal_button_test.dart`、`agent_default_selection_test.dart`、`agent_form_dialog_redesign_test.dart`）。

全工程 `flutter analyze` 零告警、代码格式与 `git diff --check` 严格通过。详细设计与测试清单见 [前端交接记录](../handoffs/2026-09-19-resource-usage-and-docker-terminal.md)。

## 当前基线

本项目以 Android/Windows Native MVP 为第一交付目标，远端服务端零专有 Daemon 侵入。展示层由 Valhalla Antigravity 历史会话维护，业务实现遵循：

```text
Material 3 UI -> Riverpod State -> Service/Repository -> Infrastructure SDK -> SSH/SFTP/ACP/Docker
```

## 已实现能力

- `dartssh2` SSH 连接池、Host Key 校验、KeepAlive、Login Shell 执行。
- SFTP 目录浏览、文件读取/写入、创建、删除和重命名。
- `xterm` SSH PTY、多标签终端和移动端辅助按键。
- ACP 事件模型、流式消息、Tool Call、Plan 和权限请求基础链路。
- `acpd` 1.0.0 标准 JSON-RPC 核心及 SSH 行传输适配器。
- 快捷命令模板参数替换、终端直通和后台 SSH 执行。
- 中英文 ARB、本地主题模式和种子色设置。
- Docker CLI 结构化容器解析、容器生命周期命令和日志流基础服务。
- `ps` 进程解析、systemd 服务解析与受限操作接口。
- 命令风险识别（Safe/Warning/Danger）和系统指标快照解析。
- SSH 服务器管理修复：首次安装不再注入 `prod-cluster-us-east`，旧版
  `demo-debian-12` 数据会一次性迁移清理；服务器支持确认删除（含最后一项），
  切换时等待活动服务器持久化后再连接，新增服务器保存后自动设为活动项。

## 下一步必须完成

### 2026-09-18 接手核对与修复进度

接手基线静态分析通过，624 项自动化测试通过。当前工作树还包含其他协作者的未提交实现，不能用 Git 提交历史推断全部功能状态。

已存在的能力还包括服务器隔离 Agent 管理、CLI/ACP 安装向导、交互登录与 ACP 认证挑战、标准 ACP 流式会话与 load/resume、SSH 自动重连与应用生命周期复验、Android 前台保活、可选 tmux、SFTP 上传下载队列及暂停/继续/取消、文件预览排序，以及 Dashboard/Docker/系统展示层。下列旧任务清单中的部分内容已实现，不能重复从零开发。

本次后端修复：

- CLI-only 配置不进入 ACP 聊天可切换列表，列表同时核验服务器归属。
- 本地 ChatSession 保存 serverId、workingDirectory、remoteSessionId；旧会话归属方案已由本页下述七项修复更新为首次服务器一次性迁移，不再要求用户手动绑定。
- Adapter 按服务器、Agent、本地会话隔离；远端会话 ID 从对应本地会话读取，不把一个 Agent 的 ID 用于所有会话。
- 恢复仅在 JSON-RPC method-not-found 时尝试下一种恢复方式；全部不支持时返回 ACP_SESSION_RESTART_REQUIRED，不静默新建。
- 版本命令不作为登录状态检查；停止生成清理权限/认证等待并保存部分消息，过期请求不再更新状态。
- 认证状态已独立为 unknown/authenticated/unauthenticated；旧 Codex 版本检测使用 login status，其他版本检测不能证明认证。
- ACP 通道创建异常与 SSH 断线均退出生成状态并保存部分消息；生成期间不能新建会话或删除活跃会话，删除其他会话不改变当前选择。

仍未完成整套交付：其他 Agent 的真实登录探测、停止请求的完整协议验收、远端会话列表和动态配置、工作目录选择、Drift 迁移、传输重试/覆盖/临时文件策略，以及真实设备/服务器验收。数据库迁移前必须验证 SDK 依赖兼容，不能删掉原始 JSON 数据。后台服务不代表进程被系统杀死后 SSH 仍存活。

前端绑定确认、停止按钮和中英文身份错误提示已由指定 Antigravity 会话实现，5 项专项 UI 测试通过；全量 637 项测试通过，静态分析无问题，Android debug APK 构建和 diff 格式检查通过。整套功能尚不能标记为发布就绪；未交付功能见 [接手交接记录](../handoffs/2026-09-18-chat-identity-and-cancellation.md)。

1. 将 SharedPreferences JSON 持久化迁移到 Drift/SQLite，并提供一次性导入。
2. 将现有聊天 Provider 完整迁移到标准 `acpd` Session 生命周期。
3. 补充 SFTP 上传/下载、批量操作、权限修改和成熟代码高亮编辑器。
4. 接入 Docker、Dashboard、进程和 systemd 的展示层与 Provider 状态。
5. 完成 Agent Context 协同、断线恢复、统一危险确认和 Sudo PTY 回退。
6. 将所有展示文案迁移到 ARB，消除 UI 硬编码字符串。
7. 按测试矩阵补齐 SSH、ACP、Terminal、Docker、Command、Monitor 验收用例。

### 兼容性记录

在 Flutter 3.44.2 / Dart 3.10.0 环境下，当前可用的 `drift_dev`、`build_runner`、`drift_flutter` 版本组合与 Flutter SDK 固定的 `meta`/`test_api` 约束无法同时解析。Drift 迁移必须先完成依赖矩阵升级或锁定一组兼容版本，禁止提交会导致 `flutter pub get` 失败的临时依赖组合。

## Antigravity UI 协作约束

### 2026-09-18 七项修复（已实施，待实机与桌面原生验收）

完整契约见 [Agent 共享与下载交接](../handoffs/2026-09-18-agent-sharing-downloads.md)。本节覆盖之前手动绑定界面的方案，旧验收结果仅代表旧里程碑。

- 已修复 `acpd` 1.0.0 权限回包扁平序列化问题；标准回包为 `result.outcome = {outcome: selected, optionId: 原始选项ID}`。允许、拒绝、取消均有严格 JSON 回归检查。真实 Codex 远端复测尚未完成，不能据此声称其他 Agent 已通过验收。
- Agent 切换只切换选择；新建按钮进入未持久化草稿，首次发送才创建会话。
- 跨 Agent 会话共享默认关闭、按服务器持久化；共享仅传递历史文本，各 Agent 使用独立远端会话及同步游标，不共享审批或登录凭证。
- 未归属旧数据只迁移到首次确定的服务器，保留原始 JSON 备份；新增 Agent 必须属于当前服务器，异步检测结果不得跨服务器回写。
- Claude 使用结构化 `auth status --json` 判断登录，Codex 使用 `login status`，AGY 保持交互登录且不以版本命令证明已登录。
- 下载持久路径、重名避让、`.part` 成功后重命名、通知及系统打开的平台通道已接入；连续下载、动画及减少动态高亮、完成记录点击打开、Android FileProvider 和逐文件进度通知已由指定 AGY 会话实施。桌面使用系统 chooser 和通知接口，原生代码尚无本机构建/桌面会话验收。
- 删除确认和会话共享展示已由 AGY 修改；通知点击有页面接收及销毁清理，Windows 通知完成点击走系统 chooser，其余进入传输列表。Windows/Linux 原生行为仍待各自平台构建和验收。

最新 Flutter/Android 门禁：`flutter analyze` 无问题，`flutter test --reporter expanded` 全量 658 项通过，`flutter build apk --debug` 通过，`dart format --output=none --set-exit-if-changed lib test` 检查 152 个文件无变化。Linux 缺 GTK 开发库，实际构建停在 CMake；Windows 无本机构建环境；没有连接的 Android 真机，系统通知/应用选择器及真实 Codex 审批仍待实机验收。不据此宣称整套应用发布就绪。

展示层任务只能交给以下历史会话：

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

Codex 侧只提供稳定的 Model、Provider、Service 和 Repository 契约，不直接修改页面布局、组件、主题视觉或展示文案。

## 2026-09-19 当前迭代：容器终端、资源拆解与默认设置

- 运行中容器可通过独立 SSH PTY 执行 `docker exec -it <id> sh`；关闭终端只释放通道，不停止容器。非运行中容器与断开的 SSH 连接在启动前拒绝。
- CLI 与 ACP 分别保存每台服务器的默认 Agent ID；仅在没有有效当前选择时使用默认值，已保存的手动选择不被覆盖。旧设置没有默认 Agent 时回退到可用列表首项。
- 仪表盘资源拆解使用 `ps` 的 RSS 和 CPU 当前采样差值，根分区容量来自 `df -kP /`，一级目录占用来自只跨当前文件系统的 `du -x -k -d1 /`；目录扫描最多等待 30 秒，失败时容量仍可展示并标记部分结果。
- tmux 会话启动命令改为 SSH 独立 `exec` 通道发送，不再写入交互 Shell 的历史记录；已有历史记录不清理。普通交互终端及 CLI 命令保持原有语义。
- 新用户默认底栏顺序为仪表盘、CLI 智能会话、容器管理、远程文件；语言与主题默认跟随系统，旧用户持久化选择保留。
- 真实 Docker 容器、服务器进程、目录扫描耗时、SSH 历史行为及 Android/桌面交互仍需连接目标设备实测；自动化测试不代替真实远端验收。
- 本轮最终门禁：`flutter test --no-pub` 全量通过、`flutter analyze --no-pub` 无问题、`dart format --output=none --set-exit-if-changed lib test` 与 `git diff --check` 通过，Android debug APK 构建成功。

## 2026-09-19 后续六项体验改进

- 容器终端按服务器 ID 与容器名称保存 Bash/Sh 偏好，默认 Bash；Bash 预检失败时尝试 Sh，显式 Sh 不探测 Bash。两种 Shell 都失败时不启动交互终端，原有容器生命周期不受影响。
- SFTP 的可见条目在状态层过滤 `.`，根目录额外过滤 `..`；非根目录的 `..` 仍可返回上级。搜索和排序使用相同的过滤结果。
- CLI 草稿工作目录与历史会话目录筛选已分离；首次发送使用草稿目录，创建下一草稿重置为默认目录，已有会话保留其原工作目录。
- 服务器硬件快照通过当前 SSH 连接按需查询 CPU、内存、根分区、发行版和内核；缺失字段保持未知，连接或服务器变化时重新读取。
- 服务器表单、容器 Shell 选择、CLI 目录选择、会话图标与硬件卡片的展示层由指定 Antigravity Valhalla 历史会话维护。真实服务器 Shell 回退和硬件兼容性仍需远端验收。

## 2026-09-20 当前迭代：Agent 编辑、容器执行与终端操作

- Agent 配置可编辑，保持 ID、服务器归属和创建时间；保存后清空旧运行态并重新探测，启动命令或执行目标变化会在下次请求重建 CLI/ACP 传输，不删除历史会话。
- Agent 可运行在宿主机或 Docker 容器内，并允许用户选择容器 ID 固定或名称跟随，以及可选容器用户（例如 `dev`）。旧 JSON 自动保持宿主机执行、容器用户为空则遵循镜像默认用户；容器停止、消失、用户不可用或不可路由时显示错误，不自动换绑或改网络。
- Docker 容器内检测、安装、登录、ACP、CLI 交互终端、Codex 与 OpenCode 原生会话已经接入统一执行目标；OpenCode 仅在主机能路由容器地址时可用，真实 Docker 网络仍需端到端验收。
- Codex 删除原生会话使用明确的本地确认和远端 `--force`，失败不再折叠为泛化错误；终端选中内容提供复制操作。仪表盘卡片、强调色编辑器、容器 Shell 选择器的展示层均由指定 Valhalla `agy` 会话完成。
- 本轮门禁：全量 `flutter test --no-pub` 789 项通过，`flutter analyze --no-pub` 无问题，`dart format --output=none --set-exit-if-changed lib test` 与 `git diff --check` 通过，Android debug APK 构建成功。格式化仅在全量测试后改变代码排版，未改变行为。

## 2026-09-20 当前迭代：会话运行设置与 NAS 媒体库

- ACP 与 CLI 智能会话已增加模型、推理等级和三档操作权限设置；配置按会话、Agent、服务器隔离并记住新会话默认值。ACP 使用动态配置项，Codex/OpenCode 使用原生协议能力，普通交互 CLI 保持由其自身管理。
- 智能会话移动端会话列表已统一为 Material Drawer，桌面会话栏统一为 320dp；全部可见 UI、ARB 与 Widget 测试由指定 Valhalla AGY 历史会话完成。
- NAS 媒体库已接入可配置导航，支持扫描/排除目录、只读 SSH 扫描、本地 SQLite 索引、搜索分类、分页、图片缓存预览，以及复用下载队列后系统打开。
- 自动化已覆盖设置序列化、NAS 路径规范化与 NUL 记录解析、索引事务与服务器隔离、抽屉/设置弹窗、NAS 空状态、配置、筛选和导航。真实大目录性能、非 GNU find NAS、Android 系统打开及远端协议参数仍需设备验收。
- 最终门禁：`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 全量 884 项通过，Codex 运行参数线协议专项测试通过，`git diff --check` 通过；`app-release.apk` 构建成功。当前 Gradle release 仍使用 debug signing，仅适合安装验收，不作为应用商店正式签名包。

## 2026-09-22 NAS 流播放稳定性

- `NasMediaProxyService` 的单个 HTTP Range 请求现在复用一个 SFTP 文件句柄，并使用 dartssh2 流水线读取；视频不再按 1 MiB 分块写磁盘缓存。
- SFTP 子系统在响应结束时关闭，缓存写入使用临时文件替换，缓存清理延迟合并；HTTP 服务只启动一次并清理过期 token。
- MIME 回退改为具体扩展类型，避免 `media_kit` 因 `video/*` / `audio/*` 通配类型无法探测格式。
- 新增 [NAS 媒体流播放架构](../02-architecture/04-nas-streaming-architecture.md)：默认保持任意 SSH 服务器可用的 SFTP 回退，可选接入 Jellyfin/Emby/Caddy 的 SSH loopback 隧道；本轮未修改展示层。

## 质量门禁

每个里程碑必须通过：

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

不得提交敏感凭证明文、假造远端数据、空异常捕获或绕过高危操作确认的执行路径。
