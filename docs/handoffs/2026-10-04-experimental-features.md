# 实验性功能：CLI 智能会话与 NAS 媒体库

## 需求与交互

设置页新增“实验性功能”入口，点击打开可滚动的勾选弹窗；目前只有
CLI 智能会话与 NAS 媒体库两项，全部默认未勾选；旧版本明确勾选的 CLI
开关保留，不因此自动开启 NAS。保存成功后即时生效并持久化，不需重启。
保存期间禁止重复操作；失败在弹窗内反馈，不把未成功写入的设置显示为开启。

未启用时，从侧边菜单、桌面/平板导航、底栏、仪表盘快捷入口以及导航配置
候选中隐藏未开启的实验性页面；不挂载隐藏 CLI/NAS 页面，不自动打开远端
历史、扫描媒体库或创建 NAS 播放器。已开始播放保留控制入口。ACP 智能
会话及默认底栏其他页面保持不变。

启用后可以从侧边菜单/桌面导航进入对应页面；底栏与默认启动页仍由用户配置，
不会强制新增或改写。关闭保留已有会话、Agent、凭据和菜单设置，重新启用
恢复原位置。旧默认启动页为 CLI/NAS 时，关闭状态实际进入仪表盘；正在对应页
时关闭会回退仪表盘，但不替用户停止、删除或重发任何远端任务。

## 开发契约

- `ExperimentalFeature.cliChat` / `ExperimentalFeature.nas`，SharedPreferences 键
  `valhalla_experimental_features_v1` 保存枚举名称列表，缺键/未知名称不启用。
- `SettingsState.enabledExperimentalFeatures` 与 `isSectionEnabled`、
  `availableSections`、`visibleBottomNavigationSections`、
  `visibleDashboardQuickSections`、`effectiveStartupSection` 统一控制可用性。
- `setExperimentalFeature` 先写入存储，成功才更新内存；`resetDefaults` 关闭。
- `setVisibleBottomNavigationSections` / `setVisibleDashboardQuickSections`
  合并可见列表编辑与隐藏配置，不删除旧条目。页面编号保持 CLI=8、NAS=9，
  桌面导航的可见位置与实际页面编号分别映射。
- UI / ARB 由原 AgY Valhalla 会话、Gemini 3.8 Flash / high 完成；root 未编辑
  展示代码。OpenCode 负责测试维护、生成、格式化、分析和 APK 构建。
- 未更换依赖、修改远端配置、删除用户数据或操作签名私钥。

## CLI 初次交付验证状态

AgY 已完成并退出原会话。OpenCode 首次 provider 测试暴露了测试替身在“重启”
步骤重置 mock 存储的问题，已修正辅助函数；同时修复新增测试的冗余 await、
重复/未使用变量和控件查找方式。五个旧导航用例增加显式启用配置，保留断言，
没有因默认隐藏 CLI 而修改产品行为或新增跳过。
MiMo Free 本次限流，按用户已有授权并核对本机和官方免费计价后，主/辅助模型
先尝试 `opencode/space-bunny-free`（请求长时间无返回），再尝试
`opencode/longcat-2.5-preview-free`（完成多语言生成后再次限流）、
`opencode/ling-3.1-flash-free`（有执行结果，后续端点不可用）。最终实际验证使用
`opencode/fledge-alpha-free`；每次主/辅助模型都显式配置为同一已确认免费模型。

原 OpenCode 上下文 `ses_f0405efacffePPqWyhHc3GGJY7` 的自动压缩被 MiMo
限流阻塞，历史保留；使用本次专用验证上下文
`ses_efa045a6bffeBnDODUfPKr6YLw` 完成收尾。这不是 AgY 换会话。

已完成：

- 多语言生成；静态分析零问题；全量测试 `1903` 通过、`18` 项既有跳过，
  `FULLTEST_EXIT=0`。
- 新增 19 项实验性设置逻辑测试与 3 项界面测试，覆盖默认关闭、重启持久化、
  写入失败、旧菜单顺序保留，以及真实弹窗勾选/取消勾选、默认隐藏 CLI 页面、
  NAS 导航仍为页面 9、当前 CLI 关闭后回退仪表盘。
- 弹窗测试使用英语、320dp、默认文字比例；设备像素比 2 不等于两倍系统字号，
  不声称已验证所有大字号/语言组合。
- 本地 Release APK 使用原开发测试签名，构建时间 `2026-10-04T08:27:01Z`，
  大小 `123916922` 字节，apksigner 校验通过；旧 APK 和其他架构包均保留。
- APK SHA256：
  `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96`。

- APK 编译内容的独立核验通过：三个架构的 `libapp.so` 均包含新的实验性设置
  存储键和英语标题，旧 APK 中均不存在；新旧 AOT 哈希不同，不是只改时间。

执行命令与原始结果见
[详细验证报告](../../agent-workflow/2026-10-04-experimental-cli-verification.md)。
初次构建阶段未授权设备安装；随后用户明确要求通过 ADB 部署。
OpenCode 于 `2026-10-04T09:08:07Z` 在原设备 `127.0.0.1:14251` 完成
`install -r` 覆盖安装，旧新签名一致，安装后回读 APK 的 SHA256 与本轮产物一致。
应用启动后进程存活且主 Activity 位于前台；未卸载、清空数据、修改用户设置或
操作远端会话。该设备为 x86_64 模拟器，不把启动检查称为全功能/真机界面验收。
详见 [设备部署记录](../../agent-workflow/2026-10-04-experimental-cli-device.md)。

## NAS 增量状态

共享可用性逻辑已扩展到 NAS；原 AgY 已完成设置弹窗和 Shell 展示修改，
未由 root 修改 UI。OpenCode 已完成增量回归：24 项设置逻辑测试、43 项关联
测试通过；全量 `1909` 通过、`18` 项既有跳过，`FULL_EXIT=0`，静态分析零问题。
本轮增加 5 项 NAS 逻辑用例及 1 项双开关界面用例，并扩展默认不挂载页面/
不初始化 NAS Provider 的断言。旧 NAS 正向导航/来源选择器用例改为显式开启
实验性 NAS，未削弱断言或增加跳过。设置弹窗验证仍为英语 320dp、默认字号。
新的 NAS 增量 APK 已构建，`BUILD_EXIT=0`：

- 路径：`build/app/outputs/flutter-apk/app-release.apk`。
- UTC 文件时间：`2026-10-04T09:59:30Z`，大小 `123916922` 字节。
- SHA256：`b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`。
- apksigner 校验通过，沿用开发测试签名
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`。
- 原仅 CLI 版备份为 `app-release.apk.bak-20261004-095809`，其余包保留。

初次构建阶段未执行 ADB 安装；随后用户明确要求部署。OpenCode 已在
`127.0.0.1:14251` 完成保留数据的 `install -r`，更新时间
`2026-10-04T10:13:34Z`；旧新签名兼容，安装后回读 APK 的 SHA256 与
NAS 增量新包一致。启动后 12 秒进程存活，MainActivity 位于前台。
未操作实验性开关、服务器或聊天历史，未卸载/清空数据；不声称已验收所有界面。
详见 [NAS 设备部署记录](../../agent-workflow/2026-10-04-experimental-nas-device.md)。完整构建结果见
[NAS 验证记录](../../agent-workflow/2026-10-04-experimental-nas-verification.md)。
契约见 [NAS 增量交接](../../agent-workflow/2026-10-04-experimental-nas.md)。
