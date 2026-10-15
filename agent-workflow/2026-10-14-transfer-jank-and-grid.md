# 小文件传输卡顿与网格信息优化

## 本轮范围

用户已批准实施计划；实际复现反馈是单个小文件传输也使整个应用卡顿。
不能仅以大文件吞吐或以往 APK 的验证结果作为本轮性能结论。
本轮源码修改、相关回归和静态检查；不升版本、不打包安装、不推送发布。
已有未提交修改与正式包均保留。

## 实施与归属

- 主代理及核心协作者：SSH 收发和缓冲区、Android 下载通知桥接、记录文档。
- 展示与界面状态订阅仅由原 AgY Valhalla 会话
  `ec81a4be-7543-45ee-8658-f68966f57d3b`，`gemini-3.8-flash-high`／high 实施。
- 测试编写、执行、格式和分析交 OpenCode，首先使用已核验免费的
  `opencode/mimo-v2.6-flash-free`；允许使用此前用户批准的其他确认免费模型。
  历史单轮主代理接管例外不自动沿用，不读取登录、签名或服务器凭据。

## 已确认机制与核心修复

主壳层只用 isAtRoot 却订阅整个 SftpState；文件页面同样整体订阅，小文件的
准备、源身份、进度、校验和完成状态均能引起重建。目录投影已有缓存，不能
把重复排序误写为本轮根因。隔离主壳层、目录列表、工具栏和进度的订阅。

SSH 收发与加解密仍在主 isolate；连续处理约 4ms 后在完整数据包、序号和窗口
更新完毕时让出事件队列，保证关闭、EOF、重协商和包顺序。ChunkBuffer 尾部
空间不足时用新数组承接仍存数据；已消费前缀至少半容量时原容量压缩，否则
扩容留出余量，避免近满缓冲每追加一字节都复制全量。容量受未完全排空期间
峰值有效数据的约四倍约束，排空释放；旧 view 不被后续写入改变。此项根据
独立复核修正初始“仅 needed 超过容量才扩容”方案，兼顾内存与复制次数。
保留现有 SFTP 并发窗口、校验与取消/暂停/切服保护。

Android reportProgress 的通知查询、构建和发送改为有序后台任务；权限申请
和 Activity 操作保留主线程。通知只依赖 applicationContext，同一缓存 Flutter
引擎重注册复用 FIFO 队列，不能因 Activity 销毁丢失后台完成/取消通知。
不缓存不可失效的权限结果，不改变 NAS/update 跳转或完成文件的 Dart 校验入口。

## AgY UI 白名单与确定行为

仅允许修改：

- `lib/features/shell/main_shell.dart`
- `lib/features/files/sftp_file_view.dart`
- `lib/features/app_center/widgets/app_store_tab.dart`

不修改核心、平台、测试、依赖、其他 UI、语言资源或版本；不执行测试、分析、
构建、生成、git 操作或服务器命令。保留本轮以前的列表对齐/时间/标题大小、
终端模式入口、输入法意图与图标修复。

1. MainShell 只 select 文件是否根目录，返回行为及导航不变。
2. 文件页面只监听目录/过滤/排序/布局、错误、缓存与必要可用性字段。
   传输字节/速度/阶段由独立 Consumer 更新进度；工具栏仅关心活跃标志和计数。
   目录内容不因任务进度重新构建。传输弹窗只因任务 ID 列表或自己的错误/按钮
   状态变更重建；每行按 ID select 本任务。必须使用值稳定的选择结果，不能
   每次构建全新 List 作为 select 结果。保留已有 SftpTransferListItem 参数接口。
3. 主文件网格仅文件夹 metadata 改为 item.permissions；普通文件仍显示大小，
   `..` 无元信息。隐藏颜色、链接、日期、菜单与选择功能不变，共享选择器不改。
4. 应用网格 padding 10→8dp，标题/简介间距 6→4dp、简介/来源间距 6→2dp。
   来源下面紧贴一行目录版本（原始版本字符串，缺失 `—`，长值 Tooltip）；右侧
   保留已安装/不兼容徽章。标题最多两行、简介一行。高度公式包含来源与版本，
   移除 116dp 的不必要固定下限并同步滚动锚点步长，正常窄屏两列/大字单列。
   不请求模板以补版本，不改应用列表样式，不伪造 latest。

## 验收范围与实机后续项

- 单文件 1KiB/64KiB 上传下载的准备/传输/校验/完成；批量小文件、大文件、
  暂停/取消/断线/切服与最终哈希。隔离替身和本地协议端点，不操作生产目标。
- 纯进度及阶段变化不重建主壳层和目录条目；任务行独立更新，通知终态有序。
- 缓冲区反复追加/部分消费仍有界、旧 view 不变；SSH 处理突发包时事件队列
  可执行，包顺序/字节/关闭/EOF/重协商及 ACP/终端共享连接回归保留。
- 网格 320–430dp、正常和大字号、长名/长版本/无版本、隐藏目录、符号链接与
  状态徽章；断言权限/版本实际可见，不只断言无溢出。
- 相关测试与静态检查由 OpenCode 执行。没有设备 profile 数据时必须明确
  标注尚未实机确认帧耗时/输入延迟/GC/吞吐，不宣称彻底解决用户环境卡顿。

## 当前结果

源码完成，相关回归 **223 通过／0 失败**（核心 78、界面 145），不是全量或
实机性能验收。最终 `flutter analyze --no-pub` 零问题，差异空白检查通过。
MiMo、Big Pickle 和 Cat Jam 超时后，实际完成测试、格式、分析
与 Kotlin 编译的是已核验免费的 `opencode/nemotron-3-ultra-free`；主代理没有
代写或执行测试。早期生成的错误测试已纠正，失败日志保留，不计入通过结果。

- 新增缓冲区 4 项：100 轮大前缀消费不增长、近满小增量留出余量、内容及旧
  view 保持、排空释放与范围检查。
- 新增 SSH 事件调度 5 项：真实协议类接收／发送在批次中让事件执行，完整
  保序、自然 EOF 与同步分段 EOF 排空、让步中销毁停止发送、窗口调整不丢失。
  测试仅在首包回调施加 5ms 工作量触发分支，不将它当作吞吐性能基准。
- 新增界面刷新隔离 3 项：主壳层终端 Widget 实例保持；1KiB／64KiB 任务进度
  更新不重建目录／文件条目而横幅进度更新；单任务进度不重建另一任务行，
  追加、删除、完成和清除已完成任务仍正常。
- 网格权限、普通文件大小、版本／空版本／长版本提示、来源与版本上下位置、
  窄屏和大字体已有可见内容及布局断言；原有下载打开、列表与导航回归通过。
- Android `:app:compileDebugKotlin` 编译成功；既有第三方插件和 UpdateChannel
  弃用警告不属于本轮变更。没有生成本轮 APK，也没有 ADB 安装。

主要验证命令：

```sh
flutter test --no-pub test/infrastructure/ssh_transfer_fairness_test.dart test/infrastructure/ssh_event_yield_test.dart test/infrastructure/ssh_sftp_subsystem_transport_test.dart test/infrastructure/sftp_read_window_test.dart test/infrastructure/sftp_transfer_channel_test.dart test/infrastructure/sftp_download_incomplete_test.dart test/infrastructure/acp_ssh_framing_test.dart test/infrastructure/terminal_rebind_resilience_test.dart test/core/sftp_transfer_records_test.dart test/core/transfer_helpers_test.dart --reporter expanded
flutter test --no-pub test/features/sftp_file_view_test.dart test/features/sftp_transfer_list_test.dart test/features/application_center_ui_test.dart test/features/main_shell_back_button_test.dart test/features/sftp_transfer_rebuild_test.dart --reporter expanded
flutter analyze --no-pub
GRADLE_USER_HOME=/tmp/valhalla-gradle.dhCKKO android/gradlew -p android :app:compileDebugKotlin --console=plain
```

本机原始证据：`/tmp/valhalla-transfer-jank.8HubRT` 内
`opencode-final-core.jsonl`、`opencode-final-closeout.jsonl`、
`opencode-final-analyzer-exact.jsonl`、`opencode-lint-cleanup.jsonl`、
`opencode-native-compile.jsonl`；
界面组合结果 `/tmp/valhalla-rebuild-opencode.w9jt33/final-ui.jsonl`。
临时日志用于本轮审计，不是仓库持续保存的测试报告。

尚未验证：真实手机单文件／批量传输的帧耗时、输入延迟、GC 和吞吐；Android
Activity 重建、通知权限变化与后台完成的实机行为；加密／NEWKEYS 重协商在
时间片边界的端到端场景。上述列为后续设备验收项，不能宣称用户环境已彻底
不卡顿。本轮未连接生产服务器、升版本、安装、提交、推送或发布。
