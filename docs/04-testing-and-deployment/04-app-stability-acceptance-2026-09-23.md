# App 稳定性验收（2026-09-23）

本轮重点是 NAS 部署媒体服务时的无反馈、等待不结束，以及共享 SSH/SFTP/Docker 生命周期。既有服务器配置只做只读检查；所有远端写入使用[一次性 VM](03-isolated-app-test-environment.md)。

**当前状态：本轮稳定性修复与已列范围验收完成。最新源码全量测试 1111 项通过、17 项隔离环境测试默认跳过；静态分析无问题，277 个文件格式检查无改动。最新 release APK（`4d28eab…222da3`）已覆盖安装并保留数据，NAS 冷启动、断线/重连扫描和图片复测通过；最终 soak 完成 25 轮、250 次入口检查、30 分 17 秒，PID 22840 未变，日志复核未发现新增崩溃、未处理异常或 ANR。Emby 正式 VM 复跑 1/1 通过，其他后端与各历史 APK 的设备证据按版本保留。旧包 4 轮/308 秒 soak 为主动中断，不计最终通过。下文列明未实现功能及外部未验范围，本结论不等于全部功能发布就绪。**

## 自动检查与交付产物

| 检查 | 当前结果 | 证据 |
| --- | --- | --- |
| 设备补测前全量 Flutter 测试 | **1089 passed / 15 skipped**；作为之前版本的基线保留 | [full-tests-final.txt](../../build/app-stability-validation/full-tests-final.txt) |
| 中间版本全量 Flutter 测试 | **1101 passed / 16 skipped**；不是最终冻结源码/最终 APK 的验收结论，跳过项需要显式启用隔离环境 | [test-device-final.log](../../build/app-stability-validation/test-device-final.log) |
| NAS UI 最后修复 | 端口错误固定可见、成功阶段不再显示回滚清理文案、镜像验证错误提示修正；**12 项针对测试通过**，针对分析无问题；`946aa467…` 包的端口错误、成功任务展示与取消核验已复测，见下文 | [agy-nas-visible-error-final.jsonl](../../build/app-stability-validation/agy-nas-visible-error-final.jsonl) |
| 快捷命令 UI 修复 | 双流输出、异常 loading 收尾及防重复执行；**15 项 widget + 4 项指纹/本地化测试通过**；`946aa467…` 包的断线错误和退出码 7 双流结果已复测 | [agy-command-error-fix.jsonl](../../build/app-stability-validation/agy-command-error-fix.jsonl) |
| WebDAV 压缩元数据修复 | **25 项针对测试通过**；真实同源 SSH 隧道扫描 3 项、3 项媒体各读取 Range 32 字节通过；`946aa467…` 包扫描 3 项及图片预览已复测 | [针对测试](../../build/app-stability-validation/webdav-gzip-unit-after.log)、[同源实际复跑](../../build/app-stability-validation/webdav-adapter-device-after.log) |
| NAS 冷启动/重连缓存回归 | **4 项新增回归通过，与关联用例合计 13 项通过**；覆盖冷启动错误失效、源自身 SSH 断线/重连、无关连接变化和同 ID 客户端替换；针对分析无问题 | [修复前失败](../../build/app-stability-validation/nas-source-reconnect-before.log)、[修复后 13 项](../../build/app-stability-validation/nas-source-reconnect-after.log)、[针对分析](../../build/app-stability-validation/nas-source-reconnect-analyze.log) |
| `946aa467…` 包源码检查 | **1106 passed / 17 skipped**；分析无问题，276 个文件格式零改动；作为该历史版本的检查保留 | [全量测试](../../build/app-stability-validation/test-webdav-device-final.log)、[分析](../../build/app-stability-validation/analyze-device-final.log)、[格式](../../build/app-stability-validation/format-device-final.log) |
| 最新源码全量 Flutter 测试 | **1111 passed / 17 skipped**；包含 Emby API 就绪及 NAS 缓存修复，opt-in 隔离环境用例另列下文；不替代设备验收 | [test-nas-lifecycle-final.log](../../build/app-stability-validation/test-nas-lifecycle-final.log) |
| 最新源码静态分析 | `flutter analyze` 无问题 | [analyze-nas-lifecycle-final.log](../../build/app-stability-validation/analyze-nas-lifecycle-final.log) |
| 最新源码 Dart 格式 | 检查 277 个文件，0 改动 | [format-nas-lifecycle-final.log](../../build/app-stability-validation/format-nas-lifecycle-final.log) |
| Debug APK | 构建成功，`adb install -r` 成功 | [build-debug-final.txt](../../build/app-stability-validation/build-debug-final.txt) |
| 前一版手工设备测试的 Release APK | 构建与覆盖安装成功，作为最初问题复现和手工操作版本保留 | [build-release-regenerated.txt](../../build/app-stability-validation/build-release-regenerated.txt)、[apk-release.json](../../build/app-stability-validation/apk-release.json) |
| `946aa467…` 历史 Release APK | 构建、签名及覆盖安装通过，保留数据；PID 15905，关键修复设备复测见下文；此后又修复 Emby 就绪和 NAS 冷启动缓存 | [APK 元数据](../../build/app-stability-validation/apk-release-device-final.json)、[覆盖安装](../../build/app-stability-validation/device/install-release-device-final.log)、[启动](../../build/app-stability-validation/device/final-release-start.json) |
| 最新 Release APK | **构建成功、签名验证通过、覆盖安装 Success，保留应用数据**；与 debug 签名一致，PID 22840；冷启动扫描/图片及断线错误已验，重连扫描通过；最终 soak 完成 25 轮/1817 秒，日志复核通过 | [构建](../../build/app-stability-validation/build-release-nas-lifecycle-final.log)、[APK 元数据](../../build/app-stability-validation/apk-release-nas-lifecycle-final.json)、[覆盖安装](../../build/app-stability-validation/device/install-release-nas-lifecycle-final.log)、[启动](../../build/app-stability-validation/device/nas-lifecycle-final-release-start.json) |

最新 APK 路径为 `build/app/outputs/flutter-apk/app-release.apk`，**120,047,520 字节**，SHA-256 为 **`4d28eab39248ef1a3e5248709f19ab0fd5103878509422d0d17163c1a1222da3`**。已于 08:59:24 UTC 记录进程 PID 22840 开始设备复测；冷启动与断线结果见下文，重连直接扫描也已通过。

下文关键修复设备证据对应的前版 APK 为 120,047,520 字节，SHA-256 `946aa4672e71a2c8b54f1d48338791981728d5f0fc215e202acc73856e86014a`，08:24:58 UTC 启动 PID 15905。之后包含 Emby API 就绪修复的中间包 SHA-256 为 `4a310f537310dd90b325a439bd75985fce828d6669c14e333bb350935cd86dd5`，见 [中间包元数据](../../build/app-stability-validation/apk-release-emby-final.json)；该包冷启动选中 WebDAV 时暴露 NAS 适配器缓存错误，不能作为该问题修复后的通过证据。

前一版手工测试 APK 为 119,883,680 字节，SHA-256 `fc8dbf950729133ee2202dc76b3254b409cc022535a3792dca5e17795a47d890`；其证据和 PID 4772 的手工运行记录不冒充最终 APK soak。早先 `build-release-final.txt` 中的构建失败属于历史尝试，不能仅凭文件名中的 `final` 判断交付状态。

## 已确认的问题与修复

| 问题 | 修复与证明 |
| --- | --- |
| SSH 命令通道打开不受超时约束；认证可能无限等待 | 总时限覆盖通道打开和认证；主机密钥人工确认时间另算；传输与真实 VM 回归 |
| SSH `close()` 只发送 EOF，长命令取消仍等待 | 取消请求 TERM 并释放通道；真实 VM 验证取消后同一 SSH 连接仍可执行命令 |
| 同 ID 编辑服务器地址或旧连接迟到覆盖新状态 | 固定连接身份、请求代次检查；名称修改保留连接；地址/账户变化失效旧连接 |
| 已安装 dartssh2 返回格式化指纹却被再次 Base64 | 与 OpenSSH `ssh-keygen` 核对；兼容迁移旧格式，真正密钥变化仍拒绝 |
| 普通终端关闭后前台长命令仍存活 | 真实 VM 先复现失败，再验证 dispose 释放该命令且共享 SSH 可继续使用；tmux 分离后状态仍保留 |
| PTY 的中文 UTF-8 字节跨数据包时损坏 | 使用跨包解码状态；真实 PTY 的中文、ANSI、resize 和有界长输出通过 |
| systemd 服务状态读取了错误列 | 区分 ACTIVE 与 SUB；真实测试单元的启动、重启、停止及失败状态通过 |
| NAS 窗口拥有任务生命周期，关闭后丢失进度 | 服务保留单一任务、目标、阶段、耗时、最多 256 KiB 日志；关闭仅隐藏 |
| NAS 拉取全量缓冲、健康轮询无总时限、取消结果不明确 | 流式输出、阶段总时限、取消和安全回滚；不确定状态要求只读核验 |
| 进程结束后无法辨认未完成部署 | 保存无密码/token 的摘要；恢复不自动安装/删除，先核验远端身份和归属 |
| WebDAV 预览后复核出现 `NAS_INSTALL_PLAN_STALE` | Docker 29 实测 `tag@平台 digest` 校验失败，而同一 digest 的 `repository@digest` 成功；仅修正 WebDAV 引用生成，18 项安装器回归及真实部署通过 |
| SFTP 文本预览可无限读大文件且未关闭句柄 | 读取过程中执行 1 MiB 上限；读写 finally 关闭；异步结果检查来源和请求代次 |
| Docker 日志不消费 stderr，关闭后命令可能仍运行 | 复用可取消的 SSH 双流命令；错误退出明确提示；界面限量保留日志 |
| 缺少跨页面/异步错误记录 | 本地脱敏日志 3 × 1 MiB、写入队列上限、查看/导出；Android 退出原因独立记录 |
| 快捷命令凭据读取/SSH 异常直接抛出；等待凭据时目标可变化 | provider 返回退出码 -1 和脱敏错误，并在派发前核对目标及 SSH 客户端身份；8 项新回归与关联用例合计 19 项通过。`946aa467…` 包断线执行立即展示可关闭的 -1 错误，重连后 stdout/stderr 和退出码 7 同时可见；特殊凭据故障仍由自动回归覆盖 |
| WebDAV 连接成功但扫描立即 `NAS_SCAN_FAILED` | 元数据响应为 gzip 压缩 XML，原实现直接 UTF-8 解码；probe 不读取正文，因而能成功。新增 `NasHttpResponse.decodedBytes` 仅供 XML/JSON 解析，媒体 Range 原始字节处理保持不变；`946aa467…` 包已扫描 3 项并打开真实图片，音视频链路不据此扩展为通过 |
| 已保存 SSH 隧道源冷启动后连接正常但扫描仍失败；重连后可复用旧隧道 | 元数据服务先于自动 SSH 连接读取适配器，缓存首次 `NAS_SSH_NOT_CONNECTED`；适配器未随源 SSH 客户端变化失效。现在按源自身 `sshServerId` 的客户端身份监听连接变化，重建适配器并释放旧隧道；源不必等于全局活动服务器。4 项新增回归及关联测试通过，最新 APK 冷启动直接扫描和图片已通过，断线扫描有明确错误，重连直接扫描也已通过 |
| Emby 首页可跳转时媒体 API 仍未就绪，安装提前成功 | 实际 `/` 在健康阶段约 20.344 秒返回 302，但 `/System/Info/Public` 在 20.926 秒仍为 503；安装与恢复核验改为适配器同用的公共信息 API，2 分钟健康预算不变。修复后正式真实 VM 用例 1/1 通过 |

## 真实隔离 VM 验证

环境为 Debian 12、QEMU TCG、Docker Engine/CLI 29.8.1，使用真实 SSH、SFTP、Docker 和 HTTP；不把这些结果等同于 Android 界面验收。测试只操作带本轮标识的目录、容器、systemd 单元及 tmux 会话。

| 范围 | 实际结果与边界 | 证据 |
| --- | --- | --- |
| SSH/SFTP 综合用例 | 通过；主机指纹与 `ssh-keygen` 一致；人工确认等待 11 秒不占用 10 秒认证预算；stdout/stderr、非零退出、分包日志脱敏、流取消后复用连接、错误认证和同 ID 地址变更均验证。SFTP 验证中文内容、目录/文件创建、读写、改名、列举、删除和超过 1 MiB 的预览拒绝 | [ssh-sftp-real-vm.log](../../build/app-stability-validation/ssh-sftp-real-vm.log)、[修复后综合复跑](../../build/app-stability-validation/terminal-dispose-after.log) |
| 普通终端 dispose | 修复前真实前台 `sleep` 未释放；修复后同一用例通过，tmux 分离/重连专项通过 | [失败证明](../../build/app-stability-validation/terminal-dispose-before.log)、[修复后](../../build/app-stability-validation/terminal-dispose-after.log)、[tmux 复验](../../build/app-stability-validation/terminal-dispose-tmux.log) |
| Docker/系统/终端操作 | **7/7 通过**：Docker 列表/详情、stdout/stderr/日志取消、暂停/恢复/重启/停止/启动/改名、容器终端缺 bash 回退 sh；只终止自有进程；systemd 实际状态；PTY ANSI/resize/分包中文/有界输出；tmux 保留远端状态 | [operations-vm-final.log](../../build/app-stability-validation/operations-vm-final.log) |
| 系统重启 | **1/1 通过**：经 `ServerPowerService.reboot` 仅派发一次，重连后以 boot ID 改变验证重启完成；耗时 57 秒，VM 保持运行。未执行关机验收 | [power-vm-actual.log](../../build/app-stability-validation/power-vm-actual.log) |
| WebDAV 设备扫描失败的同源重现与修复 | 修复前在实际部署源和 SSH 隧道上重现 gzip XML 解码失败；修复后扫描 3 项、3 项媒体的 Range 32 字节读取通过。该测试调用真实适配器和服务；Android 页面结果按各包另列下文 | [失败重现](../../build/app-stability-validation/webdav-adapter-device-real-before.log)、[响应编码](../../build/app-stability-validation/webdav-adapter-device-encoding.log)、[修复后复跑](../../build/app-stability-validation/webdav-adapter-device-after.log) |

### NAS 安装器：六项分轮通过，新增只读核验通过

以下汇总原五项通过结果、Emby 后续正式复跑与新增只读核验；不是同一轮全量重跑。成功路径使用新生成的计划和真实预检，未绕过镜像校验或延长产品健康检查时限。

| 用例 | 结果 | 实际证明 |
| --- | --- | --- |
| 已有安装目录保护 | 通过 | 拒绝覆盖已有目录，哨兵文件内容保持不变 |
| Jellyfin 10.11.11 部署与恢复 | 通过 | 真实拉取/创建、HTTP 健康、媒体只读挂载、已保存健康阶段恢复后只读核验同一容器 |
| 拉取中取消 | 通过 | 出现真实远端 `Pulling` 输出后取消；任务有明确终态，不确定结果可只读核验；无服务容器遗留，媒体文件保留 |
| 确认后出现外部同名容器 | 通过 | 启动失败显示 `NAS_INSTALL_START_FAILED` 和 `needsInspection`；不把清理标为完成，不删除该外部容器 |
| WebDAV / rclone 1.75.0 部署与恢复 | 通过 | 修正 canonical `repository@digest` 后真实部署成功；未认证健康请求返回预期 401，认证读取图片返回 200；媒体只读挂载、持久摘要恢复及只读核验通过 |
| Emby 4.10.0.40 冷启动与恢复 | **正式复跑 1/1 通过**，08:52 UTC 完成，耗时 4 分 37 秒 | 在修正隔离 VM 模拟 CPU 条件及产品 API 就绪检查后，正式用例完成预检、拉取、启动、公共信息 API 健康及持久健康阶段恢复核验；产品健康预算仍为 2 分钟。最初 `NAS_INSTALL_HEALTH_TIMEOUT` 与安全回滚结果保留为历史证据 |
| 中断拉取后的只读核验 | 通过 | 仍有自有文件、路径不可访问或长参数任务进程存活时，拒绝误报清理完成；确认干净状态后才标记 cancelled/cleanupComplete |

最初 Emby 在 2 分钟内无 HTTP 响应并安全回滚；后续原生对照发现隔离 VM 内核 page fault/Oops，主线程退出，不能将其简单记为初始化缓慢。一次性 VM 保留磁盘并改用 `max,smap=off` 后继续 Docker 对照，另确认“首页 302 但媒体 API 503”的产品就绪判断缺口。修复 API 检查后的正式 VM 用例已通过，见 [正式复跑日志](../../build/app-stability-validation/emby-health-api-vm-final.log)；环境与 API 时序证据见 [原生环境诊断](../../build/app-stability-validation/emby-native-diagnosis.md)、[Docker API 时序](../../build/app-stability-validation/emby-docker-smap-off-summary.json)。这不等于 Emby Android 完整媒体源流程或所有宿主环境均通过。

NAS 证据：[各用例最新结果汇总](../../build/app-stability-validation/nas-vm-final-summary.json) 收录跨多次运行的原六项通过结果及新增只读核验，不代表单次七项重跑或 Android 全流程通过；[原六项历史汇总](../../build/app-stability-validation/nas-vm-summary.json) 保留当时失败。另见 [首轮真实测试](../../build/app-stability-validation/nas-install-vm-test.log)、[修复后取消/冲突/WebDAV 三项通过](../../build/app-stability-validation/nas-install-vm-after-canonical-fix.log)、[只读核验复跑](../../build/app-stability-validation/nas-reconcile-vm-final.log)、[Emby 启动日志](../../build/app-stability-validation/emby-cold-start-log.txt)、[Docker 镜像引用对照](../../build/app-stability-validation/rclone-reference-comparison.md)。

09:03:31 UTC 的 [VM 最终只读状态](../../build/app-stability-validation/vm-final-readonly-state.json) 确认三个测试媒体的 SHA-256 未变、同一 WebDAV 容器仍运行、boot ID 与调整环境后记录一致；另外仅保留两个 fixture BusyBox 测试容器。该检查不执行清理或修改，不能据此声称测试环境已完全移除。

环境曾出现 registry DNS 返回不可用地址及 TLS 握手失败；修正仅限一次性 VM 的解析配置，保留 TLS 校验，不修改产品镜像预检。环境修复、资源归属及清理方法见[隔离环境文档](03-isolated-app-test-environment.md)。

## Android 设备证据与限制

- ADB 目标：`192.168.1.145:14251`；设备 Android 14、`sdk_gphone64_x86_64`。
- 保留应用数据，未卸载或清空。未运行会卸载包的 Flutter integration runner。
- 初始设备记录有一次 `OTHER KILLS BY SYSTEM / TOO MANY EMPTY PROCS`；当时 crash buffer 为空且无历史 ANR。这不能排除未捕获的闪退。
- 原 APK SHA256：`a8a7ddd3d7d00b34c6b38fdb08834db799a49a83417aa38e51f5e04ea57b0c19`。
- ADB 在基线检查过程中曾变为 offline；当时 ADB 与模拟器控制台端口在握手前关闭连接，noVNC 画面空白。**2026-09-23 07:07:31 UTC 已恢复在线**，Android `boot_completed=1`，见 [adb-restored.txt](../../build/app-stability-validation/adb-restored.txt)。
- 恢复后依次使用 `adb install -r` 覆盖安装 debug 和 release，均返回 Success，既有配置保留。当前在 release 中连接隔离 VM 并执行功能验收，设备交互记录保存在 `build/app-stability-validation/device/`。
- 前一版 release 连接隔离 VM 后执行 Jellyfin 拉取、关闭重开和取消，发现清理状态问题；`946aa467…` 包已重新走真实拉取/取消/只读核验链，结果见后面的对应包复测表。历史失败证据：[拉取进度](../../build/app-stability-validation/device/nas-jellyfin-progress.xml)、[重开窗口](../../build/app-stability-validation/device/nas-jellyfin-reopened.xml)、[取消结果](../../build/app-stability-validation/device/nas-cancel-result.xml)。
- SFTP 媒体源已保存并扫描到 3 个测试媒体；PNG 预览、收藏、下载完成。见 [扫描](../../build/app-stability-validation/device/fixture-media-scan.xml)、[图片预览](../../build/app-stability-validation/device/photo-open.png)、[下载队列](../../build/app-stability-validation/device/download-queue.xml)。这不等于 SFTP 文件管理页全部操作已通过。
- MP3 前台和切后台后均为 `PLAYING`，媒体会话位置从 10 秒推进到 22 秒；MP4 已显示约 14 秒处的真实视频帧，随后追加单个 SFTP 视频样本的暂停、定位、恢复操作，结果见下表。见 [前台媒体会话](../../build/app-stability-validation/device/music-media-session.txt)、[后台媒体会话](../../build/app-stability-validation/device/music-background-session.txt)、[视频画面](../../build/app-stability-validation/device/video-playing-later.png)。音乐的其他控制、队列、通知控制及播放失败恢复仍未完整覆盖；系统媒体会话记录包含其他应用，判读仅限本应用会话。
- 不以 debug 模拟器帧率推断实体手机性能。

以下为 `fc8dbf95…` 包的手工设备操作及问题复现；后续包复测另列下表。远端写入均只涉及隔离 VM 的测试文件和容器。

| 范围 | 实际操作与结果 | 证据 |
| --- | --- | --- |
| SFTP 大文本与保存失败恢复 | 超过 1 MiB 的文本显示预览限制提示。将测试 `small.txt` 权限设为 400 后，UI 保存失败但保留 `UI_SAVE_REGRESSION_20260923`；恢复为 600 后再次 UI 保存成功，另经 SSH 读取确认内容 | [大文本提示](../../build/app-stability-validation/device/sftp-large-preview.xml)、[保存失败保留内容](../../build/app-stability-validation/device/sftp-save-permission-error.xml)、[重试保存](../../build/app-stability-validation/device/sftp-save-retried.xml) |
| SFTP 目录及文件操作 | 新建 `ui-acceptance` 目录；Android 原生选择器上传 32 字节测试文件，设备与 VM 的 SHA-256 均为 `68782599b46b75dc88e725c6cbf17e85fdbcf12ccf57d60c752abcd71e38163c`；改名为 `ui-renamed.txt`、下载完成；删除出现确认，确认后列表清空 | [上传选择器](../../build/app-stability-validation/device/sftp-upload-picker.xml)、[上传结果](../../build/app-stability-validation/device/sftp-upload-result.xml)、[下载完成](../../build/app-stability-validation/device/sftp-transfer-list.xml)、[删除确认](../../build/app-stability-validation/device/sftp-delete-confirm.xml)、[删除后列表](../../build/app-stability-validation/device/sftp-deleted.xml) |
| Docker 日志与终端 | UI 启动测试日志容器；日志显示 stdout、stderr 和中文，关闭后远端进程检查无本次 `docker logs` 遗留；容器终端执行 echo/pwd 有输出，关闭后无本次 `docker exec` 遗留 | [日志](../../build/app-stability-validation/device/docker-logs-loaded.xml)、[关闭日志](../../build/app-stability-validation/device/docker-after-log-close.xml)、[终端输出](../../build/app-stability-validation/device/docker-terminal-output.png)、[关闭终端](../../build/app-stability-validation/device/docker-terminal-closed.xml) |
| 普通 SSH 终端与系统页 | 普通终端执行 echo，截图中出现测试标记；系统页实际打开服务列表。未据此宣称设备侧 tmux、全部终端控制或系统写操作通过 | [终端命令](../../build/app-stability-validation/device/ssh-terminal-command.png)、[服务列表](../../build/app-stability-validation/device/system-services.xml) |
| 电源确认取消 | 旧版设备包分别打开重启、关机确认，目标明确为隔离测试服务器；随后取消，未实际派发重启或关机。此前后端实际重启测试单独记录，不能与本次确认取消混同 | [重启确认](../../build/app-stability-validation/device/server-reboot-confirmation.xml)、[关机确认](../../build/app-stability-validation/device/server-shutdown-confirmation.xml)、[取消后界面](../../build/app-stability-validation/device/server-power-cancelled.xml) |
| 设置与诊断 | 主题切暗色后恢复系统；语言切英文后恢复中文。诊断导出成功，文件 3256 字节，检查 `fixture_password_present=false`；仅证明测试密码未出现，不等于任意敏感信息均已排除 | [暗色主题](../../build/app-stability-validation/device/settings-dark.png)、[英文界面](../../build/app-stability-validation/device/settings-english.xml)、[导出成功](../../build/app-stability-validation/device/diagnostics-export-success.xml)、[导出检查](../../build/app-stability-validation/device/diagnostics-export-check.json) |
| Agent 缺失组件提示 | 新增测试 Codex Agent，准确检测为未安装；打开检测日志和安装确认，随后取消，未执行安装。没有进行真实账号登录或模型调用 | [检测](../../build/app-stability-validation/device/agent-codex-probing.xml)、[检测日志](../../build/app-stability-validation/device/agent-diagnostic-log.xml)、[安装确认](../../build/app-stability-validation/device/agent-install-confirm.xml) |
| 快捷命令问题复现 | 新增测试命令并后台执行，实际返回退出码 7；发现 stdout 遮蔽 stderr，以及异常路径 loading 未收尾的缺口。修复后的设备结果见下一表 | [退出码 7 结果](../../build/app-stability-validation/device/command-exit7-result.xml)、[core 修复前回归](../../build/app-stability-validation/commands-provider-before.log)、[core 修复后 19 项通过](../../build/app-stability-validation/commands-provider-after.log) |
| NAS 表单与 WebDAV 预检 | 输入端口 0 后错误位于长表单下方，修复后复测见下一表。WebDAV 首次预检提示镜像不可用；独立 VM 镜像检查 41.91 秒后在配置 blob 下载时 TCP 超时，未改环境的重试 17.73 秒成功、amd64 摘要匹配；设备随后预检重试及真实部署成功。不能据首次失败归因为 DNS 错误 | [端口错误位置](../../build/app-stability-validation/device/nas-invalid-port.xml)、[表单顶部](../../build/app-stability-validation/device/nas-invalid-port-top.xml)、[WebDAV 预检诊断](../../build/app-stability-validation/device/webdav-preflight-diagnosis.txt)、[设备部署成功](../../build/app-stability-validation/device/webdav-progress-before-navigation.xml) |
| WebDAV 媒体源 | 设备添加 SSH 隧道媒体源并测试连接成功，旧版扫描立即显示 `NAS_SCAN_FAILED`；gzip XML 解码根因已修复，真实适配器和 `946aa467…` 包的扫描复测分别记录 | [隧道源连接成功](../../build/app-stability-validation/device/webdav-probe-result.xml)、[旧版扫描失败](../../build/app-stability-validation/device/webdav-scanned.xml)、[适配器修复后复跑](../../build/app-stability-validation/webdav-adapter-device-after.log) |
| 单个 SFTP 视频控制 | 在约 21 秒暂停；定位到 5 秒，截图的视频内嵌时间为 5.917 秒；恢复播放约 4 秒后再次暂停，显示约 10 秒。仅该 SFTP MP4 样本的正常暂停/定位/恢复已验，不外推至其他源、全部格式或失败恢复 | [21 秒暂停状态](../../build/app-stability-validation/device/video-paused-fresh.xml)、[暂停画面](../../build/app-stability-validation/device/video-paused-check.png)、[定位状态](../../build/app-stability-validation/device/video-seek-paused-new.xml)、[5.917 秒真实帧](../../build/app-stability-validation/device/video-seek-paused-new.png)、[恢复再暂停状态](../../build/app-stability-validation/device/video-resume-paused-again.xml)、[约 10 秒画面](../../build/app-stability-validation/device/video-resume-paused-again.png) |

手工混合操作期间，PID 4772 从 07:12:43 持续至 08:18:21（UTC），约 65 分钟；末次 PSS 为 168927 KiB，此前一次采样为 153559 KiB。本段记录未发现新增 FATAL、Unhandled 或 ANR，退出记录无新的崩溃，系统 ANR 记录为空。见 [手工结束时间与 PID](../../build/app-stability-validation/device/manual-end.json)、[末次 logcat](../../build/app-stability-validation/device/manual-end-logcat.txt)、[末次退出记录](../../build/app-stability-validation/device/manual-end-exit-info.txt)、[末次 ANR](../../build/app-stability-validation/device/manual-end-last-anr.txt)、[末次内存](../../build/app-stability-validation/device/manual-end-meminfo.txt)、[之前内存](../../build/app-stability-validation/device/manual-meminfo.txt)。这是该段手工观察，不能替代最终 APK 的 20 轮导航及 30 分钟自动 soak，也不能据两次内存采样断言没有泄漏。

历史 APK（SHA-256 `946aa467…86014a`、PID 15905）的修复后设备复测如下：

| 范围 | 实际结果 | 证据 |
| --- | --- | --- |
| 快捷命令断线错误与双流 | SSH 断线时执行立即展示退出码 -1 错误，可关闭；重连后测试命令的 `UI_OUT`、`UI_ERR` 和退出码 7 同时显示 | [断线错误 XML](../../build/app-stability-validation/device/final-command-disconnected.xml)、[错误截图](../../build/app-stability-validation/device/final-command-disconnected.png)、[双流 XML](../../build/app-stability-validation/device/final-command-exit7.xml)、[双流截图](../../build/app-stability-validation/device/final-command-exit7.png) |
| WebDAV 扫描与图片 | 已有 SSH 隧道源扫描出 3 项；打开真实图片成功。不据此推断该源音视频播放或全部媒体控制通过 | [扫描 3 项](../../build/app-stability-validation/device/final-webdav-scanned.xml)、[图片预览](../../build/app-stability-validation/device/final-webdav-photo.png) |
| NAS 成功任务与表单错误 | 恢复已有成功任务，未再误显示回滚清理状态；端口 0 的错误固定可见，无需滚到长表单底部 | [恢复成功任务](../../build/app-stability-validation/device/final-nas-restored-success.xml)、[端口错误 XML](../../build/app-stability-validation/device/final-nas-port-error-visible.xml)、[错误可见截图](../../build/app-stability-validation/device/final-nas-port-error-visible.png) |
| Jellyfin 拉取取消与核验 | 新建任务出现真实拉取日志，关闭重开保留进度；取消后独立远端检查无本次进程/容器，仅保留 cache/config，既有 WebDAV 仍运行。UI 先显示 needsInspection，经只读核验后正确显示 cancelled、cleanupComplete | [重开后的拉取](../../build/app-stability-validation/device/final-nas-reopened-pull.png)、[远端检查](../../build/app-stability-validation/device/final-nas-cancel-remote.json)、[核验后 XML](../../build/app-stability-validation/device/final-nas-cancel-reconciled.xml)、[核验后截图](../../build/app-stability-validation/device/final-nas-cancel-reconciled.png) |
| 新建源默认目标 | 新建媒体源默认选择当前有效的隔离测试服务器，未再出现显示首项但内部 ID 未初始化的旧行为；本次覆盖当前服务器存在的默认选择场景 | [默认目标](../../build/app-stability-validation/device/final-new-source-default.xml) |

`946aa467…` 包的自动 soak 在发现 Emby API 就绪问题后被主动 SIGINT 中断，共记录 **4 轮/308 秒**，不是崩溃，也不计最终通过；`result.json` 的最后状态为 running，须结合 [主动中断说明](../../build/app-stability-validation/soak-before-emby-readiness-fix/interruption.json) 和 [旧 soak 记录](../../build/app-stability-validation/soak-before-emby-readiness-fix/result.json) 判读。

最新 APK（SHA-256 `4d28eab…222da3`、PID 22840）的 NAS 生命周期复测如下；未编辑或重新保存媒体源：

| 范围 | 实际结果 | 证据 |
| --- | --- | --- |
| 冷启动缓存修复 | 已保存 WebDAV 为当前源，冷启动后仪表盘自动连接；直接扫描 3 项，打开真实彩条 PNG，未借助重新保存源恢复缓存 | [自动连接](../../build/app-stability-validation/device/nas-lifecycle-final-cold-dashboard.xml)、[直接扫描](../../build/app-stability-validation/device/nas-lifecycle-final-cold-scan.xml)、[图片](../../build/app-stability-validation/device/nas-lifecycle-final-cold-photo.png) |
| 断线错误与重连 | 主动断开 SSH 后扫描立即显示 `NAS_SCAN_FAILED`，有界结束；重连后不编辑/保存源，直接扫描到 3 项 | [已断线](../../build/app-stability-validation/device/nas-lifecycle-final-disconnected.xml)、[离线扫描错误](../../build/app-stability-validation/device/nas-lifecycle-final-offline-scan.xml)、[已重连](../../build/app-stability-validation/device/nas-lifecycle-final-reconnected.xml)、[重连后扫描](../../build/app-stability-validation/device/nas-lifecycle-final-reconnect-scan.xml) |
| Soak 后再次扫描 | 25 轮 soak 结束后重新扫描 3 项成功，页面显示新的扫描时间；应用 PID 仍为 22840 | [再次扫描 XML](../../build/app-stability-validation/device/nas-lifecycle-final-after-soak-scan.xml)、[扫描截图](../../build/app-stability-validation/device/nas-lifecycle-final-after-soak-scan.png) |

冷启动缓存问题在中间 `4a310f…` 包上有独立设备证据：[探测成功](../../build/app-stability-validation/device/webdav-cached-error-probe-success.xml)、[随后扫描失败](../../build/app-stability-validation/device/webdav-cached-scan-failure-after-successful-probe.xml)。

最新 `4d28eab…` APK 的最终自动 soak 于 **09:01:34 UTC** 启动，完成 **25 轮、10 个路由入口共 250 次检查、1817 秒（30 分 17 秒）**，同时满足至少 20 轮与至少 30 分钟。导航及 Home/恢复期间 PID **22840 始终未变**；crash buffer 为空，系统记录自本次开机无 ANR，退出记录与测试前一致，最后一条仍为旧 PID 22098 因 `PACKAGE UPDATED` 退出；实时日志无 FATAL 或 Unhandled 匹配。日志复核结论为 **`passed_observed_scope`**。原始 `result.json` 保留 `navigation_completed_requires_log_review`，应与复核摘要一起判读，不修改原始运行状态冒充已复核。

25 次 PSS 采样范围为 **128101–140244 KiB（约 125.1–137.0 MiB）**，末次 **132282 KiB（约 129.2 MiB）**；本观察窗口内波动但未见持续增长，不能据此证明不存在长期泄漏。证据：[复核摘要](../../build/app-stability-validation/soak-final/reviewed-summary.json)、[原始结果](../../build/app-stability-validation/soak-final/result.json)、[250 次入口检查时间线](../../build/app-stability-validation/soak-final/timeline.jsonl)、[退出记录](../../build/app-stability-validation/soak-final/final-exit-info.txt)、[ANR 记录](../../build/app-stability-validation/soak-final/final-last-anr.txt)、[空 crash buffer](../../build/app-stability-validation/soak-final/final-crash-buffer.txt)、[末次内存](../../build/app-stability-validation/soak-final/final-meminfo.txt)、[实时日志](../../build/app-stability-validation/device/nas-lifecycle-final-release-live-logcat.txt)、[启动记录](../../build/app-stability-validation/soak-final-runner.json)。本次通过限于已列功能与模拟器导航/生命周期观察，不涵盖全部错误路径或实体手机性能。

09:33:24 UTC 完成末次扫描与日志检查后，仅停止本轮自有 ADB 日志采集进程，应用 PID 22840 继续运行；截至此时实时日志仍无 FATAL/Unhandled。见 [设备验收结束记录](../../build/app-stability-validation/device/nas-lifecycle-final-release-end.json)。

## 验收矩阵

| 范围 | 自动/隔离验证 | 本轮 Android 实际交互 |
| --- | --- | --- |
| 服务器、认证、指纹、断线/取消/切换 | 回归 + 真实 VM SSH 通过 | `946aa467…` 包已断线、显示命令错误并重连成功；认证错误、连接取消及配置切换未完整设备验收 |
| 仪表盘、系统进程/服务、电源确认 | 实际进程/systemd 操作通过；实际 VM 重启 1 次通过，关机未测 | 已打开系统服务列表；重启/关机确认显示准确测试目标，取消未派发电源动作；设备侧实际电源执行及进程/服务写操作未完整验收 |
| 终端、tmux、ANSI、输入 | 真实 PTY、中文分包、resize、dispose 和 tmux 保留状态通过 | 普通 SSH echo 标记有截图；设备侧 tmux、ANSI、全部输入控制未完整验收 |
| SFTP 目录/编辑/CRUD/传输 | 真实 VM UTF-8 CRUD、大小边界通过 | 大文本限制、保存失败保留编辑与重试、建目录、原生选择器上传、校验哈希、改名、下载、确认删除通过；传输取消/重试未验 |
| Docker 生命周期/日志/终端 | 7 项操作套件中的真实 Docker 用例通过 | 测试容器启动、双流/中文日志、终端 echo/pwd 已验，关闭后对应远端进程无遗留；不扩展为全部生命周期操作通过 |
| NAS 三产品部署/失败/取消/恢复 | 原六项分轮通过；Emby 正式复跑 **1/1 通过**，新增只读核验通过 | WebDAV 实际部署成功；`946aa467…` 包的成功任务恢复、端口错误、Jellyfin 拉取关闭重开/取消/只读核验通过；三产品完整设备部署仍未验 |
| NAS 媒体源、扫描、视频/音乐/图片、下载、收藏 | WebDAV gzip XML 修复后 25 项针对测试及真实同源隧道扫描 3 项/Range 通过 | 前版 SFTP 扫描 3 项、PNG 预览/收藏/下载、MP3 前后台播放及单 MP4 暂停/定位/恢复通过；`946aa467…` 包 WebDAV 扫描 3 项与图片通过、默认源目标已验；最新 `4d28eab…` 包冷启动直接扫描/图片与断线错误已验，重连直接扫描也已通过。其他源/媒体控制未完整覆盖 |
| ACP/CLI Agent 会话、审批/停止/隔离 | 现有协议和状态回归；VM 无登录的真实 Agent 账户 | 测试 Codex 未安装提示、检测日志、安装确认取消已验；真实模型调用、会话与审批未验 |
| 快捷命令 | core 与关联测试 19 项、UI widget 15 项及指纹/本地化 4 项通过 | `946aa467…` 包断线 -1 错误立即可见可关闭；重连后 stdout/stderr/退出码 7 同时显示；凭据异常等特定路径仍由自动回归覆盖 |
| 设置、主题、语言、导航、诊断导出 | 设备补测前的全量现有测试 + UI 回归通过 | 暗色后恢复系统、英文后恢复中文、诊断导出及测试密码检查已验；其他设置/导航未完整验收 |
| 20 轮导航/窗口与 30 分钟混合运行 | 最新 `4d28eab…` 包最终 soak **25 轮/1817 秒，已复核通过**；旧包 4 轮/308 秒主动中断不计通过 | 10 路由共 250 次入口检查、Home/恢复；PID 22840 未变，无新增崩溃/Unhandled/ANR，PSS 本窗口无持续增长；不扩展为所有功能或长期泄漏证明 |

## 证据和复跑

证据在 `build/app-stability-validation/`：基线 logcat、退出原因、ANR、内存、窗口、构建、测试日志及设备截图。这些是当前环境的构建产物，不是永久仓库附件。私有测试凭据仅在 `/tmp/valhalla-test-vm/credentials.json`，不提交，不复制进报告。VM 保持可用，操作套件已清理其自有临时资源，后续 Android 验收继续使用该隔离环境。

```sh
flutter test --no-pub
flutter analyze
dart format --output=none --set-exit-if-changed lib test
VALHALLA_NAS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
  flutter test --no-pub test/infrastructure/ssh_sftp_vm_test.dart --reporter expanded
VALHALLA_OPERATIONS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
  flutter test --no-pub test/infrastructure/app_operations_vm_test.dart --reporter expanded --timeout 3m
VALHALLA_NAS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
  flutter test --no-pub test/infrastructure/nas_install_vm_test.dart --reporter expanded
flutter build apk --debug --target-platform android-x64 --no-pub
flutter build apk --release
adb -s 192.168.1.145:14251 install -r build/app/outputs/flutter-apk/app-release.apk
```

实际重启测试另需同时设置 `VALHALLA_VM_POWER_TEST=1` 与 `VALHALLA_OPERATIONS_VM_CREDENTIALS`，入口为 `test/infrastructure/server_power_vm_test.dart`；仅用于身份校验通过的一次性 VM，并与其他 VM 操作串行执行。

设备 soak 复跑前，先在应用内选择隔离服务器 `Valhalla-Test-VM`，保留应用数据；不要运行可能卸载应用的 Flutter integration runner。以下脚本验证导航与生命周期，需同时达到 20 轮与 30 分钟，不替代各项功能操作验收：

```sh
python3 tool/adb_stability_soak.py --serial 192.168.1.145:14251 \
  --expected-server Valhalla-Test-VM --minutes 30 --cycles 20 \
  --output build/app-stability-validation/soak-rerun
```

本轮稳定性修复与已列范围验收完成：最新源码检查、`4d28eab…` 包构建/覆盖安装、NAS 冷启动及断线/重连扫描、Emby 正式 VM 复跑和 25 轮/30 分 17 秒自动 soak 均有对应证据。历史包结果保留版本归属；Agent 模型调用、实体手机性能和外部设备等仍未验，下列未实现入口也仍需补充，不能据此宣称全功能发布就绪。

## 后续补充与未验范围

以下将源码确认的功能缺口、尚未复现的风险和外部条件限制分开记录；不能把代码风险写成已确认的闪退或卡死。

### 源码确认的功能缺口与操作前置

- 设置页的“默认 AI 运维引擎”、Known Hosts 管理和“清除安全存储”均仍为空点击回调；Known Hosts 数量硬编码为 2。不能记为已实现或通过，也不能由此推断实际信任记录数量。见 [settings_view.dart](../../lib/features/settings/settings_view.dart)。
- 新增默认 SFTP 媒体源的显示选项与保存 ID 不一致问题，源码已修正为优先选择当前有效服务器，再回退到首个服务器；`946aa467…` 包已验证当前服务器存在时的默认选择，见对应包复测表。历史状态不一致不等于已确认设备崩溃。
- 手机 NAS 页隐藏 SSH 连接入口，需先在其他页面连接目标服务器；部署窗口选择目标不会自行建立连接。非 Jellyfin/Emby 源需配置扫描包含路径；部署成功也不会自动添加媒体源或初始化 Jellyfin/Emby 管理员和媒体库。这些前置应在完整点击验收中明确。
- 当前媒体源表单支持 SFTP、WebDAV、SMB、Jellyfin、Emby，没有独立 HTTP 媒体源类型。HTTP 流播放能力不能等同于已提供 HTTP 源配置入口。

### 尚待设备复现的风险

- 媒体源测试连接期间仍可修改类型/字段并保存，需验证旧探测或认证结果会否对应到新输入；未证明已经发生错误保存或崩溃。见 [nas_source_dialog.dart](../../lib/features/nas/widgets/nas_source_dialog.dart)。
- 部分播放器暂停、定位及停止回调使用空 `catch`，需针对播放中断验证是否出现无提示失败；单个 SFTP 样本的正常暂停/定位/恢复已成功，但不覆盖这些错误路径。见 [nas_media_view.dart](../../lib/features/nas/nas_media_view.dart)。
- SFTP 编辑失败保留内容、大文本拒绝，Docker 日志关闭/终端退出，部分设置及诊断导出已有设备证据；取消部署核验、端口错误可见性、快捷命令双流/断线错误已在 `946aa467…` 包复测。SFTP 传输取消/重试及其余未覆盖控制仍未验，任务按钮可点击或页面能打开不等于操作成功。

### 受环境限制的未验范围

- 隔离环境没有登录的真实 Agent 账户。可验 CLI/ACP/登录状态区分、缺失组件或未登录提示、诊断查看及安装/登录确认取消；真实模型流式响应、工具审批往返、真实会话历史恢复/删除及账号登录成功仍未验。协议替身测试不能代替真实 Agent 调用。
- SFTP 的媒体扫描与音视频样本已有设备证据；`946aa467…` 和 `4d28eab…` 包的 WebDAV 扫描和图片已通过，但该源音视频及全部控制未验。SMB、Jellyfin、Emby 的完整 Android 源认证、浏览、扫描与播放仍未验，NAS 后端部署成功不能替代这些交互。
- 未连接真实 DLNA 接收设备；只能验发现空结果、错误提示及取消，不能记为投屏成功。外部播放器缺失/启动失败、下载打开失败和通知控制也须按实际证据分别记录。
- 当前 Android 设备是模拟器。实体手机性能、长时间后台存活、系统节电策略、实体音视频输出及外部设备兼容性未被覆盖。

报告不复制测试密码、token、私钥或既有服务器配置。设备原始记录仅保留在本地构建证据目录，对外分享前需检查并脱敏。
