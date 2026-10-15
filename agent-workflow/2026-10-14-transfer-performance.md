# 文件传输与更新下载性能优化

状态：源码实施与本地验证完成；仅编译调试 APK 验证，未安装、推送或发布。
本轮保持 1.0.6+7。

## 范围和责任

主代理负责传输服务、状态、原生后台逻辑及文档；展示只由原 AgY Valhalla
`ec81a4be-7543-45ee-8658-f68966f57d3b`、`gemini-3.8-flash-high`／high 修改。
验证先交给 OpenCode，主模型为已核验免费的 `opencode/mimo-v2.6-flash-free`；
挂起后本轮用户明确授权主代理接管验证（见下文），过去单轮例外不自动沿用。
本轮不自动推送、发布、部署分发服务或操作生产服务器，不清用户文件和凭据。

## 已定位的机制

- 下载每 64KiB 重建 `readBytes`，底层读窗口反复从 1 开始，无法持续预读。
- 续传完整前缀逐 64KiB 回读，校验阶段无反馈；完整性保证必须保留。
- SFTP 每块刷新整个状态；上传与浏览共用 SFTP 通道，浏览超时可能中断上传。
- 更新下载每 256KiB 等待 IOSink 缓冲清空，哈希和安装前再验未移到 isolate。
- 当前公开包 `use_proxy=false`，分发接口 302 到 GitHub；现有代理仅流式转发，
  没有可据代码确认的边缘缓存。历史四文件并行测速不能当作用户单文件基线。

## 最小实施

保持所有现有句柄、队列及源身份检查；已知长度 SFTP 下载使用一次持续
`read(offset,length,chunkSize:64KiB,maxPendingRequests:32)`，按序落盘并背压；
未知长度保留顺序读取。暂停停在落盘边界、暂停期间不继续落盘，取消关闭本任务
通道及文件；超时只计算等远端输出，不把用户暂停时间计入。提前 EOF 仍失败。
续传前缀使用同一连续读取方式完整比对，不抽样；上传独立开 SFTP 通道，复用
既有 SSH 连接，正常／异常／取消均清理。上传的原子提交和安全目标检查保留。

新增共享文件 SHA256 isolate 工具，下载收尾、上传前后与安装前仍完整校验；
不将整文件传入 isolate，不删除必要的第二次安装校验。状态刷新约 150ms，
内部字节计数精确，暂停／完成／错误立即更新；通知及存储现有节流保留。
更新写盘采用 2MiB 有界缓冲；瞬态断线／超时／不完整响应可有限续传（最多两次，
1s／2s 退避），200 回退与 Range 身份验证保留，短文件不冒充成功。

## 界面接口（由主代理实现，AgY 不编辑核心）

- `SftpTransferPhase`：`preparing`、`verifyingPartial`、`transferring`、`verifying`；
  `SftpTransfer.phase`、`phaseProcessedBytes`、`phaseTotalBytes`、`bytesPerSecond`，
  `remainingSeconds` 为可空 getter。旧 status 不增枚举，运行状态仍为 running。
- `AppUpdateDownloadPhase`：`resolving`、`transferring`、`verifying`；
  `AppUpdateState.downloadPhase`、`bytesPerSecond`、`opening`、可空 `remainingSeconds`。
- `SftpResumableOperations` 增加可选 `SftpPhaseCallback onPhase`；更新服务 download
  增加可选 `void Function(AppUpdateDownloadPhase) onPhase`，旧调用保持可用。
- 进度／速度／ETA 只根据实际字节及单调计时生成。等待网络、准备与校验不显示
  虚构速度；未知长度用不定进度，校验前缀按实际校验字节显示。
- AgY 只修改 `lib/features/files/sftp_file_view.dart`、
  `lib/features/settings/widgets/app_update_dialog.dart`、必要 `lib/l10n/*.arb`。
  沿用现有 Material 主题与布局：就近显示准备／校验／传输、速度与 ETA；下载
  100% 后显示校验，安装准备有忙状态。17 种语言完整，不硬编码展示字符串。
  取消／暂停可用性跟随核心真实能力；不增加全屏弹窗或大幅重绘。

## 用户追加：紧凑文件信息与历史删除

用户精确澄清：文件列表保持此前原有结构、信息顺序、行高与时间所在位置；
原问题是时间过早省略，但时间与“更多”按钮之间仍有空位。只缩短该段预留间距
和不必要的时间宽度约束，让完整 `yyyy-MM-dd HH:mm` 在原位置单行显示；
不增加单独时间行，不换行，不为此重新排列其他信息。无障碍标签保持完整。
用户随后澄清：不是移除“目录”字样，而是每个网格太高；保留
目录类别信息，压缩正常字号卡片行高、间距及空白，保持手机双列、图标／名称
同排、完整信息可读和足够操作触控区域。大字号允许适当增高，不硬裁内容。
这部分由 AgY 修改共享 `lib/widgets/remote_browser_view.dart`，不改浏览能力。

历史抽屉更多菜单新增“删除”。弹窗显示会话标题和当前服务器，默认只删除本地
历史；可勾选“同时终止服务器终端”，仅连接到记录所属目标且远端会话可定位时
可选。终止再明确确认一次，提示会结束该终端正在运行的任务。删除默认历史时
启动默认恢复为新终端。仅删除历史不关闭当前标签或终止进程，并防止刷新／重连
立即把同一远端会话重新加入历史。终止成功后关闭对应标签；远端失败保留历史
并反馈，未知执行结果不自动重试。全程固定目标、精确 tmux 名称、不杀其他会话。
主代理接口：`TerminalNotifier.deleteHistory(String id, {bool terminateRemote = false,
String? expectedTargetKey})`；UI 必须传记录的 targetKey，防止确认弹窗期间切换目标。
失败使用 `TERMINAL_HISTORY_DELETE_FAILED`／`TERMINAL_HISTORY_TERMINATE_FAILED`。
AgY 新增白名单 `lib/features/terminal/widgets/terminal_history_drawer.dart` 和所需
17 种 ARB 文案；只负责确认／危险选项／局部反馈，核心与存储由主代理实现。
新增测试覆盖保留进程、精确终止、失败／切换目标不误删、默认清理与刷新不复活。

## 用户追加：Android 应用身份

用户已明确选择 Android、iOS、macOS、Linux 一起统一：Android applicationId／
namespace／Kotlin 包与源目录、Apple 主／测试 Bundle ID、Linux GTK application-id
均改为 `com.norns.valhalla`（Apple 测试后缀 `.RunnerTests`）。同步 Play 链接、
媒体通知技术标识、APK 身份生成器与 ADB 工具，沿用原正式签名；Windows 商店
登记值不变。已发布的 1.0.6 APK 仍是旧身份，不覆写历史证据或公开包。
Android 包名改变后新旧应用并存，不能以 adb install -r 迁移旧应用私有数据。
保留旧安装，现有配置导出／导入只迁移允许的配置，不承诺自动迁移凭据、
会话、终端历史、下载与 NAS 索引。新旧版本升级／迁移说明须随未来发布提供。

## 本轮验证接管

MiMo 初始任务只完成探索，长时间停止输出，未执行测试；精简 MiMo 预检也无
返回，两项均已停止。Big Pickle 的免费计价由本机目录和官方说明确认，但调用
仍无返回。用户明确允许仅本轮由主代理补齐测试、静态检查与 Android 编译验证；
UI 仍仅 AgY，不安装或发布，不将本例外扩展到未来轮次。初始 RED／baseline
未执行，不能记为通过；先前发布门禁仅作为旧基线，本轮结果另行记录。

## 验收与下载源（性能）

由本轮获授权的主代理补充真实读取接口回归，覆盖持续窗口、多块与乱序结果按序写入、
暂停不落盘、取消无迟到写入、已知长度提前 EOF、未知长度、完整前缀不匹配、
浏览通道超时不影响上传，以及高频回调节流与终态精确。更新测试覆盖 Range
穿过两次重定向、短流保留后恢复、200 重启、损坏拒绝、取消退避与独占写入。
性能使用隔离本地协议替身与人工延迟比较旧 64KiB 批次和持续窗口，记录吞吐、
读请求、内存边界及计时；不把模拟结果写成用户真实网络倍速。

保持公开检查／下载接口及平台架构路由。下载源先只读确认现有配置与代理能力；
若测试代理需要改变公开包记录，不在未验证时切换全部架构。R2／自定义域名／
缓存规则需明确当前可用入口与授权后实施，不能开放无关桶或猜测管理员凭据。
当前 GitHub 签名包及历史版本保持原样，后续构建／装机／发布另按用户要求进行。

## 新终端首次输出

用户追加：新建 SSH 终端不打开输入法时空白。真实渲染层 RED 已复现：
`terminal_output_repaint_test.dart` 中同尺寸输出通知后 `debugNeedsPaint=false`，
因为 repaint boundary 的 `_onTerminalChange` 只标记布局而未标记绘制。
AgY 白名单扩展到 `packages/xterm/lib/src/ui/render.dart` 做窄层绘制失效修复，
以及 `terminal_view.dart` 仅映射历史删除错误文案；不通过强制焦点／键盘绕过。
主代理检查初次 PTY 尺寸同步并补测试。账号切换仅重启本项目 AgY 进程，
当前终端确认切换后的账号已生效，原 Valhalla 会话与 high 模型不变。

## 新建终端默认模式

用户追加：默认新建普通 SSH 终端，可选择 tmux；普通不进入可恢复历史。
复用已有 `TerminalSettings.useTmux` 和 `valhalla_terminal_use_tmux_v1`，缺键
默认 false，不引入第二套设置或静默覆盖已保存选择。当前新建核心已按此值创建，
历史只登记实际 tmux 会话。AgY 设置页白名单扩展 `settings_view.dart`，将原
“会话保活”开关明确为“新建终端默认模式”，弹窗选择普通／tmux；仅影响之后
新建标签，不关闭已有终端。已明确选过启动历史时仍优先恢复该历史；未选择时
新建按模式设置执行。已有服务器 tmux 不自动清理，可通过本轮历史删除显式终止。
普通 PTY 关闭标签／释放连接时销毁 SSH channel，但不能承诺强制终止用户手动
nohup/disown 等脱离终端的后台进程。补缺键普通、不进历史、切换不丢已有输出测试。

## 最终验证（2026-10-14 09:03 UTC）

- `flutter test --no-pub --reporter expanded`：**3451 通过／29 环境相关跳过／0 失败**，
  退出码 0。包括普通模式缺键默认、切换仅影响新建、保存失败保持原模式、
  历史取消／本地删除／精确终止／失败保留／确认期间切服、首次 PTY 布局同步、
  新输出绘制、滚动与键盘意图、SFTP 完整续传与暂停取消、上传通道隔离、
  HTTP 短流穿过两次重定向续传、取消退避及完整性校验。
- `flutter analyze --no-pub`：零问题，退出码 0。多语言生成完成，17 ARB 均有
  新阶段、历史删除和模式选择文案，模式保存错误不暴露未翻译的内部代码。
- 更新清单工具 `python3 -m unittest discover -s tool -p test_generate_update_manifest.py`：
  27 项通过，退出码 0。新身份严格检查保留。
- 终端绘制真实 RED：修复前同尺寸输出 `debugNeedsPaint=false` 失败；AgY 修复
  repaint boundary 后该测试及全量门禁通过。早期另两批门禁中的夹具编译错误、
  网格溢出与设置 API 类型错误均已修复，不计为通过结果。
- vendored dartssh2 真实协议读取／本地延迟通道测试：2MiB、模拟每响应 6–8ms，
  旧 64KiB 批次 **750724µs／128 请求／峰值 2**，持续流 **45158µs／32 请求／
  峰值 16（上限 32）**。乱序响应字节内容一致，计时只记录、不作为脆弱断言；
  不代表真实公网速度或设备内存测量。1000 次进度回调节流和最终字节数已验证。
- 最终 `GRADLE_USER_HOME=/tmp/valhalla-gradle.dhCKKO flutter build apk --debug
  --no-pub --target-platform android-arm64 --target lib/main.dart` 成功，退出码 0；
  Gradle 编译约 36.3s。本机 debug 产物实际包含三种 ABI，不冒称正式单架构包。
  APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`，191243004 字节，
  SHA256 `f4bb726f53c88d550093cf8f21b8c5a0a712dfc4699510875a716f1c0494e643`。
  aapt 核对 `com.norns.valhalla`／1.0.6／native code 7，Activity、保活 Service
  与 FileProvider 均为新标识。apksigner 验证调试证书
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`；
  正式证书及已发布正式包未替换。构建前后所有源码文件 SHA256 一致。

原始日志保存在 `/tmp/valhalla-transfer-perf.eO45Nu`；本节已将结果写入仓库，
不把临时日志当作长期唯一证据。未连接／操作生产 SSH，不执行远端 kill、删除
或上传；无 ADB 安装、提交、推送、Release 或分发配置更改。真实网络吞吐、
实体手机、Apple 构建与 Linux GUI 未验；原分发链路仍跳转 GitHub，R2/CDN
缓存源没有配置，本轮不能宣称解决源站限速。新应用标识的用户配置迁移见
[发布手册](../docs/04-testing-and-deployment/11-local-release-and-distribution-runbook.md)。
